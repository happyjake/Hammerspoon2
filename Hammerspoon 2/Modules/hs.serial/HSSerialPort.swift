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

    private var fileHandle: FileHandle?
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
        let fh = FileHandle(fileDescriptor: fd, closeOnDealloc: false)
        fileHandle = fh
        fh.readabilityHandler = { [weak self] handle in
            let data = handle.availableData          // Data is Sendable → hop to main actor
            if data.isEmpty { return }
            Task { @MainActor in self?.ingest(data) }
        }
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
        fileHandle?.readabilityHandler = nil
        fileHandle = nil
        Darwin.close(fd); fd = -1
        _ = closeCb?.callSafely(withArguments: ["closed"], context: "hs.serial")
    }
}
