import Foundation

struct VolumeListResponse: Codable, Sendable {
    let volumes: [DockerVolume]?

    enum CodingKeys: String, CodingKey {
        case volumes = "Volumes"
    }
}

struct DockerVolume: Codable, Identifiable, Sendable {
    let name: String
    let driver: String
    let mountpoint: String
    let labels: [String: String]?
    let scope: String
    let createdAt: String?

    var id: String { name }

    enum CodingKeys: String, CodingKey {
        case name = "Name"
        case driver = "Driver"
        case mountpoint = "Mountpoint"
        case labels = "Labels"
        case scope = "Scope"
        case createdAt = "CreatedAt"
    }
}
