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
    /// p.close()
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
}

@_documentation(visibility: private)
@objc class HSSerialPort: NSObject, HSSerialPortAPI {
    @objc var typeName = "HSSerialPort"
    @objc let path: String
    private var fd: Int32 = -1
    @objc var isOpen: Bool { fd >= 0 }
    var rawFD: Int32 { fd }        // for later tasks (read/write)

    init?(path: String) {
        self.path = path
        super.init()
        let f = Darwin.open(path, O_RDWR | O_NOCTTY | O_NONBLOCK)
        guard f >= 0 else { return nil }
        fd = f
        configureRaw()
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

    @objc func write(_ s: String) -> Bool {
        guard fd >= 0 else { return false }
        let bytes = Array(s.utf8)
        let n = bytes.withUnsafeBytes { Darwin.write(fd, $0.baseAddress, $0.count) }
        return n == bytes.count
    }

    @objc func close() {
        guard fd >= 0 else { return }
        Darwin.close(fd); fd = -1
    }
}
