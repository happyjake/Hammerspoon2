//
//  HSHttpConnection.swift
//  Hammerspoon 2
//
//  One accepted TCP connection. Lives entirely on the server's listenerQueue.
//  Owns an NWConnection, drives an HSHttpParser per request, dispatches each
//  parsed request to the server's JS `fetch` handler, and writes the response
//  back. Supports HTTP/1.1 keep-alive.
//

import Foundation
import Network
import JavaScriptCore

@_documentation(visibility: private)
nonisolated final class HSHttpConnection: @unchecked Sendable {
    private let connection: NWConnection
    private let queue: DispatchQueue
    private let parser: HSHttpParser
    private weak var server: HSHttpServer?
    let remoteAddress: String

    private var closing = false

    init(connection: NWConnection, server: HSHttpServer, queue: DispatchQueue, maxBodyBytes: Int) {
        self.connection = connection
        self.server = server
        self.queue = queue
        self.parser = HSHttpParser(maxBodyBytes: maxBodyBytes)
        self.remoteAddress = HSHttpConnection.formatRemote(connection.endpoint)
    }

    func start() {
        connection.stateUpdateHandler = { [weak self] state in
            switch state {
            case .ready:           self?.receiveLoop()
            case .failed, .cancelled:
                self?.cleanup()
            default: break
            }
        }
        connection.start(queue: queue)
    }

    func close() {
        if closing { return }
        closing = true
        connection.cancel()
    }

    private func cleanup() {
        server?.connectionDidClose(self)
    }

    // MARK: - Receive

    private func receiveLoop() {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 64 * 1024) { [weak self] data, _, isComplete, error in
            guard let self else { return }
            if let data, !data.isEmpty {
                self.parser.append(data)
                self.drainParser()
            }
            switch self.parser.state {
            case .error, .complete:
                return
            default: break
            }
            if let _ = error {
                self.close()
                return
            }
            if isComplete {
                self.close()
                return
            }
            self.receiveLoop()
        }
    }

    private func drainParser() {
        if case .error(let status, let message) = parser.state {
            sendErrorAndClose(status: status, message: message)
            return
        }
        guard let parsed = parser.takeIfComplete() else { return }

        let keepAlive = HSHttpConnection.shouldKeepAlive(
            version: parsed.httpVersion,
            connectionHeader: parsed.headers.first(where: { $0.name.lowercased() == "connection" })?.value
        )

        server?.dispatch(parsed: parsed, remoteAddress: remoteAddress) { [weak self] responseBytes in
            self?.send(responseBytes, keepAlive: keepAlive)
        }
    }

    private static func shouldKeepAlive(version: String, connectionHeader: String?) -> Bool {
        let lower = connectionHeader?.lowercased() ?? ""
        if version == "HTTP/1.0" {
            return lower.contains("keep-alive")
        }
        return !lower.contains("close")
    }

    // MARK: - Send

    func send(_ bytes: Data, keepAlive: Bool) {
        connection.send(content: bytes, completion: .contentProcessed { [weak self] _ in
            guard let self else { return }
            if !keepAlive { self.close() }
        })
    }

    private func sendErrorAndClose(status: Int, message: String) {
        let bodyData = "\(status) \(message)".data(using: .utf8) ?? Data()
        var bytes = Data()
        let statusText = HSHttpConnection.statusTextFor(status)
        bytes.append("HTTP/1.1 \(status) \(statusText)\r\n".data(using: .utf8) ?? Data())
        bytes.append("Content-Type: text/plain;charset=UTF-8\r\n".data(using: .utf8) ?? Data())
        bytes.append("Content-Length: \(bodyData.count)\r\n".data(using: .utf8) ?? Data())
        bytes.append("Date: \(HSHttpConnection.httpDate())\r\n".data(using: .utf8) ?? Data())
        bytes.append("Connection: close\r\n\r\n".data(using: .utf8) ?? Data())
        bytes.append(bodyData)
        connection.send(content: bytes, completion: .contentProcessed { [weak self] _ in
            self?.close()
        })
    }

    // MARK: - Serialization

    @MainActor
    static func serialize(_ response: HSHttpResponse) -> Data {
        var out = Data()
        let statusLine = "HTTP/1.1 \(response.status) \(response.statusText)\r\n"
        out.append(statusLine.data(using: .utf8) ?? Data())

        let headers = response.headers
        if !headers.has("content-length") {
            headers.set("content-length", String(response.bodyBytes.count))
        }
        if !headers.has("date") {
            headers.set("date", HSHttpConnection.httpDate())
        }

        for name in headers.orderedNames {
            for value in headers.storage[name] ?? [] {
                let prettyName = HSHttpConnection.titleCaseHeaderName(name)
                out.append("\(prettyName): \(value)\r\n".data(using: .utf8) ?? Data())
            }
        }
        out.append("\r\n".data(using: .utf8) ?? Data())
        out.append(response.bodyBytes)
        return out
    }

    private static func titleCaseHeaderName(_ name: String) -> String {
        name.split(separator: "-").map { $0.prefix(1).uppercased() + $0.dropFirst() }.joined(separator: "-")
    }

    private static let httpDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(identifier: "GMT")
        f.dateFormat = "EEE, dd MMM yyyy HH:mm:ss 'GMT'"
        return f
    }()

    static func httpDate() -> String {
        httpDateFormatter.string(from: Date())
    }

    private static func statusTextFor(_ status: Int) -> String {
        switch status {
        case 400: return "Bad Request"
        case 413: return "Payload Too Large"
        case 431: return "Request Header Fields Too Large"
        case 500: return "Internal Server Error"
        case 505: return "HTTP Version Not Supported"
        default: return "Error"
        }
    }

    private static func formatRemote(_ ep: NWEndpoint) -> String {
        switch ep {
        case .hostPort(let host, _):
            switch host {
            case .ipv4(let v): return "\(v)"
            case .ipv6(let v): return "\(v)"
            case .name(let n, _): return n
            @unknown default: return "\(host)"
            }
        case .service(let name, _, _, _):
            return name
        default:
            return "\(ep)"
        }
    }
}
