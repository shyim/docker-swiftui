import Foundation
import Network

actor DockerSocket {
    struct HTTPResponse: Sendable {
        let statusCode: Int
        let headers: [String: String]
        let body: Data
    }

    enum SocketError: LocalizedError {
        case connectionFailed(String)
        case invalidResponse
        case headerParseFailed
        case timeout

        var errorDescription: String? {
            switch self {
            case .connectionFailed(let msg): return "Connection failed: \(msg)"
            case .invalidResponse: return "Invalid HTTP response"
            case .headerParseFailed: return "Failed to parse HTTP headers"
            case .timeout: return "Connection timed out"
            }
        }
    }

    private let socketPath: String
    private let queue = DispatchQueue(label: "docker.socket", qos: .userInitiated)

    init(socketPath: String = "/var/run/docker.sock") {
        self.socketPath = socketPath
    }

    func request(method: String, path: String, body: Data? = nil, headers: [String: String] = [:]) async throws -> HTTPResponse {
        let endpoint = NWEndpoint.unix(path: socketPath)
        let connection = NWConnection(to: endpoint, using: .tcp)

        defer { connection.cancel() }

        try await connect(connection)

        let httpRequest = buildRequest(method: method, path: path, body: body, headers: headers)
        try await send(connection, data: httpRequest)
        let responseData = try await receiveAll(connection)

        return try parseHTTPResponse(responseData)
    }

    func stream(method: String, path: String) -> AsyncThrowingStream<Data, Error> {
        AsyncThrowingStream { continuation in
            let endpoint = NWEndpoint.unix(path: socketPath)
            let connection = NWConnection(to: endpoint, using: .tcp)

            continuation.onTermination = { _ in
                connection.cancel()
            }

            connection.stateUpdateHandler = { state in
                switch state {
                case .failed(let error):
                    continuation.finish(throwing: error)
                case .cancelled:
                    continuation.finish()
                default:
                    break
                }
            }

            connection.start(queue: self.queue)

            let httpRequest = self.buildRequest(method: method, path: path, body: nil, headers: [:])

            connection.send(content: httpRequest, completion: .contentProcessed { error in
                if let error {
                    continuation.finish(throwing: error)
                    return
                }

                self.receiveStreamChunks(connection: connection, continuation: continuation, headersParsed: false, buffer: Data())
            })
        }
    }

    // MARK: - Private Helpers

    private func connect(_ connection: NWConnection) async throws {
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            nonisolated(unsafe) var resumed = false
            connection.stateUpdateHandler = { state in
                guard !resumed else { return }
                switch state {
                case .ready:
                    resumed = true
                    cont.resume()
                case .failed(let error):
                    resumed = true
                    cont.resume(throwing: error)
                case .cancelled:
                    resumed = true
                    cont.resume(throwing: SocketError.connectionFailed("cancelled"))
                default:
                    break
                }
            }
            connection.start(queue: self.queue)
        }
    }

    private func send(_ connection: NWConnection, data: Data) async throws {
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            connection.send(content: data, completion: .contentProcessed { error in
                if let error {
                    cont.resume(throwing: error)
                } else {
                    cont.resume()
                }
            })
        }
    }

    private func receiveAll(_ connection: NWConnection) async throws -> Data {
        var allData = Data()

        while true {
            let result: (Data?, Bool) = try await withCheckedThrowingContinuation { cont in
                connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { data, _, isComplete, error in
                    if let error {
                        cont.resume(throwing: error)
                    } else {
                        cont.resume(returning: (data, isComplete))
                    }
                }
            }

            if let chunk = result.0 {
                allData.append(chunk)
            }

            if result.1 {
                break
            }
        }

        return allData
    }

    private nonisolated func receiveStreamChunks(connection: NWConnection, continuation: AsyncThrowingStream<Data, Error>.Continuation, headersParsed: Bool, buffer: Data) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { data, _, isComplete, error in
            if let error {
                continuation.finish(throwing: error)
                return
            }

            var currentBuffer = buffer
            if let data {
                currentBuffer.append(data)
            }

            if !headersParsed {
                // Look for end of HTTP headers
                if let range = currentBuffer.range(of: Data("\r\n\r\n".utf8)) {
                    let bodyData = currentBuffer[range.upperBound...]
                    if !bodyData.isEmpty {
                        // Split on newlines for NDJSON (Docker events)
                        self.yieldLines(from: bodyData, continuation: continuation)
                    }
                    self.receiveStreamChunks(connection: connection, continuation: continuation, headersParsed: true, buffer: Data())
                } else {
                    self.receiveStreamChunks(connection: connection, continuation: continuation, headersParsed: false, buffer: currentBuffer)
                }
            } else {
                if !currentBuffer.isEmpty {
                    self.yieldLines(from: currentBuffer, continuation: continuation)
                }

                if isComplete {
                    continuation.finish()
                } else {
                    self.receiveStreamChunks(connection: connection, continuation: continuation, headersParsed: true, buffer: Data())
                }
            }
        }
    }

    private nonisolated func yieldLines(from data: Data, continuation: AsyncThrowingStream<Data, Error>.Continuation) {
        // For NDJSON streams, each line is a complete JSON object
        let bytes = [UInt8](data)
        var start = 0
        for i in 0 ..< bytes.count {
            if bytes[i] == UInt8(ascii: "\n") {
                if i > start {
                    let lineData = Data(bytes[start ..< i])
                    continuation.yield(lineData)
                }
                start = i + 1
            }
        }
        // If there's remaining data without a trailing newline, yield it too
        if start < bytes.count {
            let lineData = Data(bytes[start...])
            continuation.yield(lineData)
        }
    }

    private nonisolated func buildRequest(method: String, path: String, body: Data?, headers: [String: String]) -> Data {
        var request = "\(method) \(path) HTTP/1.1\r\n"
        request += "Host: localhost\r\n"

        for (key, value) in headers {
            request += "\(key): \(value)\r\n"
        }

        if let body, !body.isEmpty {
            request += "Content-Type: application/json\r\n"
            request += "Content-Length: \(body.count)\r\n"
        }

        request += "Connection: close\r\n"
        request += "\r\n"

        var data = Data(request.utf8)
        if let body {
            data.append(body)
        }
        return data
    }

    private nonisolated func parseHTTPResponse(_ data: Data) throws -> HTTPResponse {
        guard let headerEndRange = data.range(of: Data("\r\n\r\n".utf8)) else {
            throw SocketError.headerParseFailed
        }

        let headerData = data[data.startIndex ..< headerEndRange.lowerBound]
        let bodyData = data[headerEndRange.upperBound...]

        guard let headerString = String(data: headerData, encoding: .utf8) else {
            throw SocketError.headerParseFailed
        }

        let headerLines = headerString.components(separatedBy: "\r\n")
        guard let statusLine = headerLines.first else {
            throw SocketError.headerParseFailed
        }

        let statusCode = parseStatusCode(statusLine)

        var headers: [String: String] = [:]
        for line in headerLines.dropFirst() {
            let parts = line.split(separator: ":", maxSplits: 1)
            if parts.count == 2 {
                headers[String(parts[0]).trimmingCharacters(in: .whitespaces)] =
                    String(parts[1]).trimmingCharacters(in: .whitespaces)
            }
        }

        let body: Data
        if headers["Transfer-Encoding"]?.lowercased() == "chunked" {
            body = dechunk(Data(bodyData))
        } else {
            body = Data(bodyData)
        }

        return HTTPResponse(statusCode: statusCode, headers: headers, body: body)
    }

    private nonisolated func parseStatusCode(_ statusLine: String) -> Int {
        // "HTTP/1.1 200 OK" -> 200
        let parts = statusLine.split(separator: " ")
        guard parts.count >= 2, let code = Int(parts[1]) else { return 0 }
        return code
    }

    private nonisolated func dechunk(_ data: Data) -> Data {
        var result = Data()
        var remaining = data

        while !remaining.isEmpty {
            // Find the chunk size line ending with \r\n
            guard let lineEnd = remaining.range(of: Data("\r\n".utf8)) else { break }

            let sizeLine = remaining[remaining.startIndex ..< lineEnd.lowerBound]
            guard let sizeString = String(data: sizeLine, encoding: .utf8)?.trimmingCharacters(in: .whitespaces),
                  let chunkSize = UInt64(sizeString, radix: 16) else { break }

            if chunkSize == 0 { break }

            let chunkStart = lineEnd.upperBound
            let chunkEnd = remaining.index(chunkStart, offsetBy: Int(chunkSize))

            guard chunkEnd <= remaining.endIndex else { break }

            result.append(remaining[chunkStart ..< chunkEnd])

            // Skip past chunk data + trailing \r\n
            let nextStart = remaining.index(chunkEnd, offsetBy: 2, limitedBy: remaining.endIndex) ?? remaining.endIndex
            remaining = remaining[nextStart...]
        }

        return result
    }
}
