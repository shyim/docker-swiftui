import Foundation

enum DockerAPIError: LocalizedError {
    case httpError(statusCode: Int, message: String)
    case decodingError(String)
    case socketNotFound(String)

    var errorDescription: String? {
        switch self {
        case .httpError(let code, let msg): return "HTTP \(code): \(msg)"
        case .decodingError(let msg): return "Decoding error: \(msg)"
        case .socketNotFound(let path): return "Docker socket not found at \(path)"
        }
    }
}

final class DockerAPI: Sendable {
    private let socket: DockerSocket
    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        return d
    }()

    private let apiVersion = "/v1.47"

    init(socketPath: String = "/var/run/docker.sock") {
        self.socket = DockerSocket(socketPath: socketPath)
    }

    // MARK: - Containers

    func listContainers(all: Bool = true) async throws -> [DockerContainer] {
        let path = "\(apiVersion)/containers/json?all=\(all)"
        let response = try await socket.request(method: "GET", path: path)
        try checkStatus(response)
        return try decode([DockerContainer].self, from: response.body)
    }

    func startContainer(id: String) async throws {
        let path = "\(apiVersion)/containers/\(id)/start"
        let response = try await socket.request(method: "POST", path: path)
        // 204 = success, 304 = already started
        guard response.statusCode == 204 || response.statusCode == 304 else {
            throw DockerAPIError.httpError(statusCode: response.statusCode, message: "Failed to start container")
        }
    }

    func stopContainer(id: String) async throws {
        let path = "\(apiVersion)/containers/\(id)/stop?t=10"
        let response = try await socket.request(method: "POST", path: path)
        guard response.statusCode == 204 || response.statusCode == 304 else {
            throw DockerAPIError.httpError(statusCode: response.statusCode, message: "Failed to stop container")
        }
    }

    func restartContainer(id: String) async throws {
        let path = "\(apiVersion)/containers/\(id)/restart?t=10"
        let response = try await socket.request(method: "POST", path: path)
        guard response.statusCode == 204 else {
            throw DockerAPIError.httpError(statusCode: response.statusCode, message: "Failed to restart container")
        }
    }

    func removeContainer(id: String, force: Bool = false) async throws {
        let path = "\(apiVersion)/containers/\(id)?force=\(force)"
        let response = try await socket.request(method: "DELETE", path: path)
        guard response.statusCode == 204 else {
            throw DockerAPIError.httpError(statusCode: response.statusCode, message: "Failed to remove container")
        }
    }

    func containerLogs(id: String, tail: Int = 500) async throws -> String {
        let path = "\(apiVersion)/containers/\(id)/logs?stdout=true&stderr=true&tail=\(tail)&timestamps=false"
        let response = try await socket.request(method: "GET", path: path)
        guard response.statusCode == 200 else {
            throw DockerAPIError.httpError(statusCode: response.statusCode, message: "Failed to fetch logs")
        }
        return LogParser.parse(response.body)
    }

    func containerStats(id: String) async throws -> ContainerStats {
        let path = "\(apiVersion)/containers/\(id)/stats?stream=false&one-shot=true"
        let response = try await socket.request(method: "GET", path: path)
        try checkStatus(response)
        return try decode(ContainerStats.self, from: response.body)
    }

    // MARK: - Images

    func listImages() async throws -> [DockerImage] {
        let path = "\(apiVersion)/images/json"
        let response = try await socket.request(method: "GET", path: path)
        try checkStatus(response)
        return try decode([DockerImage].self, from: response.body)
    }

    func removeImage(id: String, force: Bool = false) async throws {
        let path = "\(apiVersion)/images/\(id)?force=\(force)"
        let response = try await socket.request(method: "DELETE", path: path)
        guard response.statusCode == 200 else {
            throw DockerAPIError.httpError(statusCode: response.statusCode, message: "Failed to remove image")
        }
    }

    // MARK: - Volumes

    func listVolumes() async throws -> [DockerVolume] {
        let path = "\(apiVersion)/volumes"
        let response = try await socket.request(method: "GET", path: path)
        try checkStatus(response)
        let volumeResponse = try decode(VolumeListResponse.self, from: response.body)
        return volumeResponse.volumes ?? []
    }

    func removeVolume(name: String) async throws {
        let path = "\(apiVersion)/volumes/\(name)"
        let response = try await socket.request(method: "DELETE", path: path)
        guard response.statusCode == 204 else {
            throw DockerAPIError.httpError(statusCode: response.statusCode, message: "Failed to remove volume")
        }
    }

    // MARK: - Networks

    func listNetworks() async throws -> [DockerNetwork] {
        let path = "\(apiVersion)/networks"
        let response = try await socket.request(method: "GET", path: path)
        try checkStatus(response)
        return try decode([DockerNetwork].self, from: response.body)
    }

    func removeNetwork(id: String) async throws {
        let path = "\(apiVersion)/networks/\(id)"
        let response = try await socket.request(method: "DELETE", path: path)
        guard response.statusCode == 204 else {
            throw DockerAPIError.httpError(statusCode: response.statusCode, message: "Failed to remove network")
        }
    }

    // MARK: - Event Stream

    func eventStream() async -> AsyncThrowingStream<DockerEvent, Error> {
        let rawStream = await socket.stream(method: "GET", path: "\(apiVersion)/events")
        return AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    for try await data in rawStream {
                        if let event = try? JSONDecoder().decode(DockerEvent.self, from: data) {
                            continuation.yield(event)
                        }
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }

    // MARK: - Helpers

    private func checkStatus(_ response: DockerSocket.HTTPResponse) throws {
        guard (200 ... 299).contains(response.statusCode) else {
            let message = String(data: response.body, encoding: .utf8) ?? "Unknown error"
            throw DockerAPIError.httpError(statusCode: response.statusCode, message: message)
        }
    }

    private func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        do {
            return try decoder.decode(type, from: data)
        } catch let error as DecodingError {
            throw DockerAPIError.decodingError("\(error)")
        }
    }
}
