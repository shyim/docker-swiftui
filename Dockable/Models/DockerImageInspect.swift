import Foundation

struct DockerImageInspect: Codable, Sendable {
    let id: String
    let repoTags: [String]?
    let repoDigests: [String]?
    let created: String?
    let size: Int64
    let os: String?
    let architecture: String?
    let author: String?
    let config: ImageConfig?
    let rootFS: RootFS?

    var shortId: String {
        String(id.dropFirst(7).prefix(12))
    }

    var platform: String {
        let osName = os ?? "unknown"
        let arch = architecture ?? "unknown"
        return "\(osName)/\(arch)"
    }

    var createdDate: Date? {
        guard let created else { return nil }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: created) {
            return date
        }
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: created)
    }

    enum CodingKeys: String, CodingKey {
        case id = "Id"
        case repoTags = "RepoTags"
        case repoDigests = "RepoDigests"
        case created = "Created"
        case size = "Size"
        case os = "Os"
        case architecture = "Architecture"
        case author = "Author"
        case config = "Config"
        case rootFS = "RootFS"
    }
}

struct ImageConfig: Codable, Sendable {
    let user: String?
    let cmd: [String]?
    let entrypoint: [String]?
    let env: [String]?
    let workingDir: String?
    let labels: [String: String]?
    let exposedPorts: [String: EmptyObject]?
    let stopSignal: String?

    enum CodingKeys: String, CodingKey {
        case user = "User"
        case cmd = "Cmd"
        case entrypoint = "Entrypoint"
        case env = "Env"
        case workingDir = "WorkingDir"
        case labels = "Labels"
        case exposedPorts = "ExposedPorts"
        case stopSignal = "StopSignal"
    }
}

struct EmptyObject: Codable, Sendable {}

struct RootFS: Codable, Sendable {
    let type: String?
    let layers: [String]?

    enum CodingKeys: String, CodingKey {
        case type = "Type"
        case layers = "Layers"
    }
}
