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

    private enum Phase { case reading, responding, idle, closing }
    private var phase: Phase = .reading
    private var inputEnded = false
    private var idleTimeout: TimeInterval
    private var idleSince: DispatchTime?
    private var idleTimer: DispatchSourceTimer?
    private var timerGeneration: UInt64 = 0

    init(connection: NWConnection, server: HSHttpServer, queue: DispatchQueue,
         maxBodyBytes: Int, idleTimeout: TimeInterval) {
        self.connection = connection
        self.server = server
        self.queue = queue
        self.parser = HSHttpParser(maxBodyBytes: maxBodyBytes)
        self.idleTimeout = idleTimeout
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
        guard phase != .closing else { return }
        phase = .closing
        cancelIdleTimer()
        parser.reset()
        connection.cancel()
    }

    private func cleanup() {
        phase = .closing
        cancelIdleTimer()
        parser.reset()
        server?.connectionDidClose(self)
    }

    // All timer operations and state transitions run on the listener queue.
    func updateIdleTimeout(_ timeout: TimeInterval) {
        idleTimeout = timeout
        if phase == .idle { armIdleTimer() }
    }

    private func cancelIdleTimer() {
        timerGeneration &+= 1
        idleTimer?.cancel()
        idleTimer = nil
    }

    private func armIdleTimer() {
        cancelIdleTimer()
        guard phase == .idle, let idleSince else { return }
        let elapsed = Double(DispatchTime.now().uptimeNanoseconds - idleSince.uptimeNanoseconds) / 1_000_000_000
        let timer = DispatchSource.makeTimerSource(queue: queue)
        let generation = timerGeneration
        // Bound each scheduling interval to avoid overflowing DispatchTime for
        // very large finite timeouts. Recheck elapsed time when the timer fires.
        timer.schedule(deadline: .now() + min(max(0, idleTimeout - elapsed), 86_400))
        timer.setEventHandler { [weak self] in
            guard let self, self.phase == .idle, self.timerGeneration == generation else { return }
            let elapsed = Double(DispatchTime.now().uptimeNanoseconds - idleSince.uptimeNanoseconds) / 1_000_000_000
            if elapsed < self.idleTimeout {
                self.armIdleTimer()
                return
            }
            self.phase = .closing
            self.cancelIdleTimer()
            self.parser.reset()
            // A final message sends TCP FIN after all response bytes. Cancel
            // only after Network.framework has processed the graceful close.
            self.connection.send(content: nil, contentContext: .finalMessage, isComplete: true,
                                 completion: .contentProcessed { [weak self] _ in
                self?.connection.cancel()
            })
        }
        idleTimer = timer
        timer.resume()
    }

    // MARK: - Receive

    private func receiveLoop() {
        guard phase == .reading || phase == .idle else { return }
        connection.receive(minimumIncompleteLength: 1, maximumLength: 64 * 1024) { [weak self] data, _, isComplete, error in
            guard let self, self.phase != .closing else { return }
            if error != nil { self.close(); return }
            self.inputEnded = isComplete
            if let data, !data.isEmpty {
                self.cancelIdleTimer()
                self.idleSince = nil
                self.phase = .reading
                self.parser.append(data)
                self.drainParser()
            }
            guard self.phase == .reading || self.phase == .idle else { return }
            if isComplete { self.close(); return }
            self.receiveLoop()
        }
    }

    private func drainParser() {
        if case .error(let status, let message) = parser.state {
            sendErrorAndClose(status: status, message: message)
            return
        }
        guard let parsed = parser.takeIfComplete() else { return }
        phase = .responding

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
        guard phase == .responding else { return }
        connection.send(content: bytes, completion: .contentProcessed { [weak self] error in
            guard let self, self.phase == .responding else { return }
            if error != nil || !keepAlive { self.close(); return }

            if self.parser.hasBufferedBytes {
                // Pipelined bytes already belong to an active exchange. Do not
                // read or dispatch another request until this write completes.
                self.phase = .reading
                self.parser.append(Data())
                self.drainParser()
                guard self.phase == .reading else { return }
            } else {
                self.phase = .idle
                self.idleSince = .now()
                self.armIdleTimer()
            }
            if self.inputEnded { self.close(); return }
            self.receiveLoop()
        })
    }

    private func sendErrorAndClose(status: Int, message: String) {
        phase = .responding
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
