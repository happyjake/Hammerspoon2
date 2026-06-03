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

    private static let readQueue = DispatchQueue(
        label: "net.tenshu.Hammerspoon-2.serial.read", qos: .utility, attributes: .concurrent)
    private var readSource: DispatchSourceRead?
    private var buffer = [UInt8]()
    private var lineCb: JSValue?
    private var closeCb: JSValue?

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
        // NSFileHandle.availableData raises an uncatchable ObjC exception on a read
        // error or EAGAIN — fatal on our non-blocking fd. Use a DispatchSource + raw
        // read() instead, so EAGAIN/EOF/errors can be handled explicitly.
        let portFD = fd
        let src = DispatchSource.makeReadSource(fileDescriptor: portFD, queue: HSSerialPort.readQueue)
        src.setEventHandler { [weak self] in
            var tmp = [UInt8](repeating: 0, count: 4096)
            let n = Darwin.read(portFD, &tmp, tmp.count)
            if n > 0 {
                let data = Data(tmp[0..<n])          // Data is Sendable → hop to main actor
                Task { @MainActor in self?.ingest(data) }
            } else if n == 0 {
                Task { @MainActor in self?.close() } // EOF: device/peer closed
            } else {
                switch errno {
                case EAGAIN, EWOULDBLOCK, EINTR:
                    break                            // transient: await the next readable event
                default:
                    Task { @MainActor in self?.close() } // real error (e.g. unplugged)
                }
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

    @objc func write(_ s: String) -> Bool {
        guard fd >= 0 else { return false }
        let bytes = Array(s.utf8)
        let n = bytes.withUnsafeBytes { Darwin.write(fd, $0.baseAddress, $0.count) }
        return n == bytes.count
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
