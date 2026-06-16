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

    /// Write a string to the port (caller includes any trailing "\n").
    /// - Parameter s: the bytes to write (UTF-8).
    /// - Returns: true if all bytes were written.
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
    private var buffer = [UInt8]()
    private var lineCb: JSValue?
    private var closeCb: JSValue?
    private var lastWriteWarningAt: UInt64 = 0
    private let writeWarningIntervalNs: UInt64 = 2_000_000_000

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

    @objc func write(_ s: String) -> Bool {
        guard fd >= 0 else { return false }
        let bytes = Array(s.utf8)
        guard !bytes.isEmpty else { return true }
        var offset = 0
        var interruptedRetries = 0

        while offset < bytes.count {
            let n = bytes.withUnsafeBytes { raw -> Int in
                guard let base = raw.baseAddress else { return 0 }
                return Darwin.write(fd, base.advanced(by: offset), bytes.count - offset)
            }

            if n > 0 {
                offset += n
                continue
            }
            if n == 0 {
                warnWrite("not writable after \(offset)/\(bytes.count) bytes")
                return false
            }
            if errno == EINTR {
                interruptedRetries += 1
                if interruptedRetries > 3 {
                    warnWrite("interrupted after \(offset)/\(bytes.count) bytes")
                    return false
                }
                continue
            }
            if errno == EAGAIN || errno == EWOULDBLOCK {
                warnWrite("not ready after \(offset)/\(bytes.count) bytes")
                return false
            }

            warnWrite(String(cString: strerror(errno)))
            return false
        }
        return true
    }

    @objc func close() {
        guard fd >= 0 else { return }
        let f = fd
        fd = -1                            // mark closed for write()/isOpen
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
        if let src = readSource {
            src.cancel()
        } else if fd >= 0 {
            Darwin.close(fd)
        }
    }
}
