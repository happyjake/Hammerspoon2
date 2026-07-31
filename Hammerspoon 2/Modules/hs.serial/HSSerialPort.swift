//
//  HSSerialPort.swift
//  Hammerspoon 2
//

import Foundation
import JavaScriptCore
import Darwin

/// An open serial port. Do not construct directly — use hs.serial.open().
@objc protocol HSSerialPortAPI: HSTypeAPI, JSExport {
    /// The device path this port was opened on.
    /// - Example:
    /// ```js
    /// console.log(hs.serial.open('/dev/cu.usbmodem1').path)
    /// ```
    @objc var path: String { get }

    /// Whether the port is currently open.
    /// - Example:
    /// ```js
    /// const p = hs.serial.open('/dev/cu.usbmodem1'); console.log(p.isOpen)
    /// ```
    @objc var isOpen: Bool { get }

    /// Close the port.
    /// - Example:
    /// ```js
    /// const p = hs.serial.open('/dev/cu.usbmodem1'); p.close()
    /// ```
    @objc func close()

    /// Queue a string for ordered delivery to the port (caller includes any trailing "\n").
    /// Writes are nonblocking: bytes that do not fit in the device's output buffer
    /// immediately are retained and resumed when the descriptor becomes writable.
    /// - Parameter s: the bytes to write (UTF-8).
    /// - Returns: true if all bytes were accepted; false if closed, queue-full, or a fatal write error occurred.
    /// - Example:
    /// ```js
    /// hs.serial.open('/dev/cu.usbmodem1').write('{"text":"hi"}\n')
    /// ```
    @objc func write(_ s: String) -> Bool

    /// Register a callback invoked once per inbound line (newline/CR-delimited).
    /// - Parameter cb: a function called with each line string.
    /// - Returns: this port (chainable).
    /// - Example:
    /// ```js
    /// hs.serial.open('/dev/cu.usbmodem1').onLine(line => console.log(line))
    /// ```
    @objc func onLine(_ cb: JSValue) -> HSSerialPort

    /// Register a callback invoked when the port closes.
    /// - Parameter cb: a function called when the port closes.
    /// - Returns: this port (chainable).
    /// - Example:
    /// ```js
    /// hs.serial.open('/dev/cu.usbmodem1').onClose(() => console.log('closed'))
    /// ```
    @objc func onClose(_ cb: JSValue) -> HSSerialPort
}

@_documentation(visibility: private)
@objc class HSSerialPort: NSObject, HSSerialPortAPI {
    @objc var typeName = "HSSerialPort"
    @objc let path: String
    private var fd: Int32 = -1
    @objc var isOpen: Bool { fd >= 0 }
    var rawFD: Int32 { fd }        // for later tasks (read/write)

    private var readSource: DispatchSourceRead?
    private var writeSource: DispatchSourceWrite?
    private var buffer = [UInt8]()
    private var writeBuffer = [UInt8]()
    private var writeOffset = 0
    private var lineCb: JSValue?
    private var closeCb: JSValue?
    private var lastWriteWarningAt: UInt64 = 0
    private let writeWarningIntervalNs: UInt64 = 2_000_000_000
    private let maxPendingWriteBytes = 256 * 1024

    init?(path: String) {
        self.path = path
        super.init()
        let f = Darwin.open(path, O_RDWR | O_NOCTTY | O_NONBLOCK)
        guard f >= 0 else { return nil }
        fd = f
        configureRaw()
        startReadLoop()
    }

    private func configureRaw() {
        var t = termios()
        tcgetattr(fd, &t)
        cfmakeraw(&t)
        t.c_cflag |= tcflag_t(CLOCAL | CREAD)
        t.c_cflag &= ~tcflag_t(HUPCL)
        cfsetspeed(&t, speed_t(B115200))
        tcsetattr(fd, TCSANOW, &t)
    }

    private func startReadLoop() {
        // Read via a DispatchSource + raw read(): NSFileHandle.availableData raises an
        // uncatchable ObjC exception on EAGAIN/errors on a non-blocking fd. Run on the
        // MAIN queue — this class is main-actor-isolated (SWIFT_DEFAULT_ACTOR_ISOLATION
        // = MainActor) and serial volume is low, so staying on the main actor avoids a
        // cross-actor hop and data races on `buffer`/callbacks. A background queue here
        // would make the (main-actor) handler trap the executor-isolation assertion.
        let portFD = fd
        let src = DispatchSource.makeReadSource(fileDescriptor: portFD, queue: .main)
        src.setEventHandler { [weak self] in
            var tmp = [UInt8](repeating: 0, count: 4096)
            let n = Darwin.read(portFD, &tmp, tmp.count)
            let err = n < 0 ? errno : 0
            guard let self else { return }
            // Invoked on the main queue, so we are genuinely on the main actor here.
            MainActor.assumeIsolated {
                if n > 0 {
                    self.ingest(Data(tmp[0..<n]))
                } else if n == 0 {
                    self.close()                     // EOF: device/peer closed
                } else if err != EAGAIN && err != EWOULDBLOCK && err != EINTR {
                    self.close()                     // real error (e.g. unplugged)
                }
                // EAGAIN/EWOULDBLOCK/EINTR: transient — await the next readable event
            }
        }
        src.setCancelHandler { Darwin.close(portFD) }
        readSource = src
        src.resume()
    }

    @MainActor private func ingest(_ data: Data) {
        buffer.append(contentsOf: data)
        while let idx = buffer.firstIndex(where: { $0 == 0x0A || $0 == 0x0D }) {
            let lineBytes = Array(buffer[0..<idx])
            buffer.removeSubrange(0...idx)
            if lineBytes.isEmpty { continue }
            _ = lineCb?.callSafely(withArguments: [String(decoding: lineBytes, as: UTF8.self)], context: "hs.serial")
        }
    }

    @objc func onLine(_ cb: JSValue) -> HSSerialPort { lineCb = cb; return self }

    @objc func onClose(_ cb: JSValue) -> HSSerialPort { closeCb = cb; return self }

    private func warnWrite(_ message: String) {
        let now = DispatchTime.now().uptimeNanoseconds
        if now >= lastWriteWarningAt + writeWarningIntervalNs || lastWriteWarningAt == 0 {
            lastWriteWarningAt = now
            AKWarning("hs.serial.write(\(path)): \(message)")
        }
    }

    private var pendingWriteBytes: Int { writeBuffer.count - writeOffset }

    private func compactWriteBuffer() {
        guard writeOffset > 0 else { return }
        if writeOffset == writeBuffer.count {
            writeBuffer.removeAll(keepingCapacity: true)
        } else {
            writeBuffer.removeFirst(writeOffset)
        }
        writeOffset = 0
    }

    private func armWriteSource() {
        guard writeSource == nil, fd >= 0 else { return }
        let portFD = fd
        let src = DispatchSource.makeWriteSource(fileDescriptor: portFD, queue: .main)
        src.setEventHandler { [weak self] in
            guard let self else { return }
            MainActor.assumeIsolated {
                _ = self.drainWriteBuffer()
            }
        }
        writeSource = src
        src.resume()
    }

    private func stopWriteSource() {
        guard let src = writeSource else { return }
        writeSource = nil
        src.cancel()
    }

    /// Drain as much of the userspace FIFO as the nonblocking descriptor accepts.
    /// EAGAIN leaves the suffix queued and arms a writable source; fatal errors close
    /// the port so callers do not continue appending to a dead descriptor.
    @discardableResult private func drainWriteBuffer() -> Bool {
        guard fd >= 0 else { return false }
        var interruptedRetries = 0

        while writeOffset < writeBuffer.count {
            let n = writeBuffer.withUnsafeBytes { raw -> Int in
                guard let base = raw.baseAddress else { return 0 }
                return Darwin.write(fd, base.advanced(by: writeOffset), writeBuffer.count - writeOffset)
            }
            let err = n < 0 ? errno : 0

            if n > 0 {
                writeOffset += n
                interruptedRetries = 0
                continue
            }
            if n < 0 && err == EINTR {
                interruptedRetries += 1
                if interruptedRetries <= 3 { continue }
                warnWrite("repeatedly interrupted with \(pendingWriteBytes) bytes pending")
            } else if n < 0 && (err == EAGAIN || err == EWOULDBLOCK) {
                armWriteSource()
                return true
            } else if n == 0 {
                warnWrite("became unwritable with \(pendingWriteBytes) bytes pending")
            } else {
                warnWrite(String(cString: strerror(err)))
            }

            close()
            return false
        }

        compactWriteBuffer()
        stopWriteSource()
        return true
    }

    @objc func write(_ s: String) -> Bool {
        guard fd >= 0 else { return false }
        let bytes = Array(s.utf8)
        guard !bytes.isEmpty else { return true }
        let pending = pendingWriteBytes
        guard bytes.count <= maxPendingWriteBytes - pending else {
            warnWrite("queue full (\(pending) pending + \(bytes.count) new bytes)")
            return false
        }

        // Discard an already-written prefix before appending so the bounded queue
        // measures only bytes that still need delivery.
        compactWriteBuffer()
        writeBuffer.append(contentsOf: bytes)
        return drainWriteBuffer()
    }

    @objc func close() {
        guard fd >= 0 else { return }
        let f = fd
        fd = -1                            // mark closed for write()/isOpen
        stopWriteSource()
        writeBuffer.removeAll(keepingCapacity: false)
        writeOffset = 0
        if let src = readSource {
            readSource = nil
            src.cancel()                   // cancel handler performs Darwin.close(f)
        } else {
            Darwin.close(f)                // defensive: no read source to cancel
        }
        _ = closeCb?.callSafely(withArguments: ["closed"], context: "hs.serial")
    }

    deinit {
        // Release the fd even if close() was never called. Cancel (don't just release)
        // the source so its cancel handler closes the fd; no JS callbacks from deinit.
        writeSource?.cancel()
        if let src = readSource {
            src.cancel()
        } else if fd >= 0 {
            Darwin.close(fd)
        }
    }
}
