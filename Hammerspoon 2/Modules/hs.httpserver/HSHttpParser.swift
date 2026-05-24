//
//  HSHttpParser.swift
//  Hammerspoon 2
//
//  Minimal HTTP/1.1 request parser. Streaming: feed bytes via `append(_:)`,
//  poll `state` to know what to do next. Handles Content-Length and chunked
//  Transfer-Encoding bodies; rejects folded headers (RFC 7230 §3.2.4).
//

import Foundation

@_documentation(visibility: private)
enum HSHttpParserState {
    case awaitingRequestLine
    case awaitingHeaders
    case awaitingBody(remaining: Int)        // Content-Length path: bytes left
    case awaitingChunkSize                   // chunked path
    case awaitingChunkData(remaining: Int)
    case awaitingChunkTrailerCRLF
    case awaitingChunkedTrailers
    case complete
    case error(status: Int, message: String)
}

@_documentation(visibility: private)
struct HSHttpParsedRequest {
    let method: String
    let target: String            // request-target (raw, may include ?query)
    let httpVersion: String       // "HTTP/1.1"
    let headers: [(name: String, value: String)]
    let body: Data
}

@_documentation(visibility: private)
nonisolated final class HSHttpParser {
    private var buffer = Data()
    private(set) var state: HSHttpParserState = .awaitingRequestLine

    // Captured during parsing
    private var method = ""
    private var target = ""
    private var httpVersion = ""
    private var headers: [(name: String, value: String)] = []
    private var bodyBuf = Data()

    // Limits (caller can tune via init args)
    let maxHeaderBytes: Int
    let maxBodyBytes: Int

    init(maxHeaderBytes: Int = 8 * 1024, maxBodyBytes: Int = 32 * 1024 * 1024) {
        self.maxHeaderBytes = maxHeaderBytes
        self.maxBodyBytes = maxBodyBytes
    }

    func reset() {
        buffer.removeAll(keepingCapacity: true)
        state = .awaitingRequestLine
        method = ""; target = ""; httpVersion = ""
        headers.removeAll(keepingCapacity: true)
        bodyBuf.removeAll(keepingCapacity: true)
    }

    /// Feed bytes. Drives the state machine forward as far as possible.
    func append(_ data: Data) {
        if case .error = state { return }
        if case .complete = state { return }
        buffer.append(data)
        run()
    }

    /// If state is `.complete`, return the parsed request and reset.
    /// Returns nil otherwise (incl. .error).
    func takeIfComplete() -> HSHttpParsedRequest? {
        if case .complete = state {
            let req = HSHttpParsedRequest(
                method: method, target: target, httpVersion: httpVersion,
                headers: headers, body: bodyBuf
            )
            reset()
            return req
        }
        return nil
    }

    private func run() {
        loop: while true {
            switch state {
            case .awaitingRequestLine:
                guard let line = takeLine() else { return }
                if line.isEmpty { continue }   // tolerate leading CRLF (RFC 7230 §3.5)
                guard parseRequestLine(line) else { return }
                state = .awaitingHeaders

            case .awaitingHeaders:
                guard let line = takeLine() else { return }
                if line.isEmpty {
                    // End of headers — decide body framing
                    if !decideBodyFraming() { return }
                    continue
                }
                if line.first == 0x20 || line.first == 0x09 {
                    state = .error(status: 400, message: "obsolete line folding")
                    return
                }
                guard parseHeaderLine(line) else { return }
                if headersByteCount() > maxHeaderBytes {
                    state = .error(status: 431, message: "headers too large")
                    return
                }

            case .awaitingBody(let remaining):
                let take = min(remaining, buffer.count)
                if take == 0 { return }
                bodyBuf.append(buffer.prefix(take))
                buffer.removeFirst(take)
                if bodyBuf.count > maxBodyBytes {
                    state = .error(status: 413, message: "body too large")
                    return
                }
                let left = remaining - take
                state = left == 0 ? .complete : .awaitingBody(remaining: left)
                if case .complete = state { break loop }

            case .awaitingChunkSize:
                guard let lineData = takeLine() else { return }
                guard let lineString = String(data: lineData, encoding: .ascii) else {
                    state = .error(status: 400, message: "non-ascii chunk size")
                    return
                }
                // Format: HEX [; chunk-ext] — we ignore extensions.
                let hex = lineString.split(separator: ";").first.map(String.init) ?? lineString
                guard let size = Int(hex.trimmingCharacters(in: .whitespaces), radix: 16) else {
                    state = .error(status: 400, message: "bad chunk size")
                    return
                }
                if size == 0 {
                    state = .awaitingChunkedTrailers
                } else {
                    if bodyBuf.count + size > maxBodyBytes {
                        state = .error(status: 413, message: "body too large")
                        return
                    }
                    state = .awaitingChunkData(remaining: size)
                }

            case .awaitingChunkData(let remaining):
                let take = min(remaining, buffer.count)
                if take == 0 { return }
                bodyBuf.append(buffer.prefix(take))
                buffer.removeFirst(take)
                let left = remaining - take
                state = left == 0 ? .awaitingChunkTrailerCRLF : .awaitingChunkData(remaining: left)

            case .awaitingChunkTrailerCRLF:
                guard let trailer = takeLine() else { return }
                if !trailer.isEmpty {
                    state = .error(status: 400, message: "expected CRLF after chunk data")
                    return
                }
                state = .awaitingChunkSize

            case .awaitingChunkedTrailers:
                guard let trailer = takeLine() else { return }
                if trailer.isEmpty {
                    state = .complete
                    break loop
                }
                // Ignore trailer header content.

            case .complete, .error:
                break loop
            }
        }
    }

    // MARK: - Helpers

    /// Consume one CRLF-terminated line from `buffer` if available.
    private func takeLine() -> Data? {
        // Find CRLF
        let bytes = buffer
        var i = 0
        while i + 1 < bytes.count {
            if bytes[bytes.startIndex + i] == 0x0D && bytes[bytes.startIndex + i + 1] == 0x0A {
                let line = bytes.prefix(i)
                buffer.removeFirst(i + 2)
                return Data(line)
            }
            i += 1
        }
        return nil
    }

    private func parseRequestLine(_ line: Data) -> Bool {
        guard let s = String(data: line, encoding: .utf8) else {
            state = .error(status: 400, message: "non-utf8 request line"); return false
        }
        let parts = s.split(separator: " ", maxSplits: 2, omittingEmptySubsequences: false)
        guard parts.count == 3 else {
            state = .error(status: 400, message: "malformed request line"); return false
        }
        method = String(parts[0])
        target = String(parts[1])
        httpVersion = String(parts[2])
        guard httpVersion == "HTTP/1.0" || httpVersion == "HTTP/1.1" else {
            state = .error(status: 505, message: "unsupported HTTP version"); return false
        }
        guard !method.isEmpty, !target.isEmpty else {
            state = .error(status: 400, message: "empty method/target"); return false
        }
        return true
    }

    private func parseHeaderLine(_ line: Data) -> Bool {
        guard let s = String(data: line, encoding: .utf8) else {
            state = .error(status: 400, message: "non-utf8 header"); return false
        }
        guard let colon = s.firstIndex(of: ":") else {
            state = .error(status: 400, message: "missing colon"); return false
        }
        let name = String(s[..<colon]).trimmingCharacters(in: .whitespaces)
        let value = String(s[s.index(after: colon)...]).trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else {
            state = .error(status: 400, message: "empty header name"); return false
        }
        headers.append((name, value))
        if headers.count > 100 {
            state = .error(status: 431, message: "too many headers")
            return false
        }
        return true
    }

    private func headersByteCount() -> Int {
        headers.reduce(0) { $0 + $1.name.utf8.count + $1.value.utf8.count + 4 }
    }

    private func decideBodyFraming() -> Bool {
        let cl = headers.first(where: { $0.name.lowercased() == "content-length" })?.value
        let te = headers.first(where: { $0.name.lowercased() == "transfer-encoding" })?.value
        if cl != nil, te != nil {
            state = .error(status: 400, message: "both content-length and transfer-encoding")
            return false
        }
        if let te = te?.lowercased(), te.contains("chunked") {
            state = .awaitingChunkSize
            return true
        }
        if let cl = cl, let n = Int(cl.trimmingCharacters(in: .whitespaces)), n >= 0 {
            if n > maxBodyBytes {
                state = .error(status: 413, message: "body too large")
                return false
            }
            state = n == 0 ? .complete : .awaitingBody(remaining: n)
            return true
        }
        // No framing → no body
        state = .complete
        return true
    }
}
