import Foundation

struct DockerImage: Codable, Identifiable, Sendable {
    let id: String
    let repoTags: [String]?
    let repoDigests: [String]?
    let created: Int
    let size: Int64
    let sharedSize: Int64?
    let containers: Int?
    let labels: [String: String]?

    var displayName: String {
        repoTags?.first ?? String(id.dropFirst(7).prefix(12))
    }

    var shortId: String {
        String(id.dropFirst(7).prefix(12))
    }

    var repository: String {
        guard let tag = repoTags?.first else { return "<none>" }
        let parts = tag.split(separator: ":", maxSplits: 1)
        return String(parts.first ?? "<none>")
    }

    var tag: String {
        guard let repoTag = repoTags?.first else { return "<none>" }
        let parts = repoTag.split(separator: ":", maxSplits: 1)
        return parts.count > 1 ? String(parts[1]) : "latest"
    }

    var createdDate: Date {
        Date(timeIntervalSince1970: TimeInterval(created))
    }

    enum CodingKeys: String, CodingKey {
        case id = "Id"
        case repoTags = "RepoTags"
        case repoDigests = "RepoDigests"
        case created = "Created"
        case size = "Size"
        case sharedSize = "SharedSize"
        case containers = "Containers"
        case labels = "Labels"
    }
}
