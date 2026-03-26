import Foundation

struct DockerContainer: Codable, Identifiable, Sendable, Hashable {
    let id: String
    let names: [String]
    let image: String
    let imageID: String
    let command: String
    let created: Int
    let state: String
    let status: String
    let ports: [Port]
    let labels: [String: String]
    let mounts: [Mount]?
    let networkSettings: NetworkSettings?

    struct NetworkSettings: Codable, Sendable, Hashable {
        let networks: [String: NetworkEndpoint]?

        struct NetworkEndpoint: Codable, Sendable, Hashable {
            let networkID: String?

            enum CodingKeys: String, CodingKey {
                case networkID = "NetworkID"
            }
        }

        enum CodingKeys: String, CodingKey {
            case networks = "Networks"
        }
    }

    struct Port: Codable, Sendable, Hashable {
        let ip: String?
        let privatePort: Int
        let publicPort: Int?
        let type: String

        enum CodingKeys: String, CodingKey {
            case ip = "IP"
            case privatePort = "PrivatePort"
            case publicPort = "PublicPort"
            case type = "Type"
        }
    }

    struct Mount: Codable, Sendable, Hashable {
        let type: String?
        let name: String?
        let source: String?
        let destination: String?
        let mode: String?
        let rw: Bool?

        enum CodingKeys: String, CodingKey {
            case type = "Type"
            case name = "Name"
            case source = "Source"
            case destination = "Destination"
            case mode = "Mode"
            case rw = "RW"
        }
    }

    var displayName: String {
        names.first?.trimmingCharacters(in: CharacterSet(charactersIn: "/")) ?? String(id.prefix(12))
    }

    var shortId: String { String(id.prefix(12)) }
    var isRunning: Bool { state == "running" }
    var isPaused: Bool { state == "paused" }
    var composeProject: String? { labels["com.docker.compose.project"] }
    var composeService: String? { labels["com.docker.compose.service"] }

    var stateColor: String {
        switch state {
        case "running": return "green"
        case "paused": return "yellow"
        case "exited": return "red"
        default: return "gray"
        }
    }

    var portSummary: String {
        ports.compactMap { port in
            if let pub = port.publicPort, let ip = port.ip {
                return "\(ip):\(pub)->\(port.privatePort)/\(port.type)"
            }
            return nil
        }.joined(separator: ", ")
    }

    enum CodingKeys: String, CodingKey {
        case id = "Id"
        case names = "Names"
        case image = "Image"
        case imageID = "ImageID"
        case command = "Command"
        case created = "Created"
        case state = "State"
        case status = "Status"
        case ports = "Ports"
        case labels = "Labels"
        case mounts = "Mounts"
        case networkSettings = "NetworkSettings"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        names = try container.decode([String].self, forKey: .names)
        image = try container.decode(String.self, forKey: .image)
        imageID = try container.decode(String.self, forKey: .imageID)
        command = try container.decode(String.self, forKey: .command)
        created = try container.decode(Int.self, forKey: .created)
        state = try container.decode(String.self, forKey: .state)
        status = try container.decode(String.self, forKey: .status)
        ports = try container.decodeIfPresent([Port].self, forKey: .ports) ?? []
        labels = try container.decodeIfPresent([String: String].self, forKey: .labels) ?? [:]
        mounts = try container.decodeIfPresent([Mount].self, forKey: .mounts)
        networkSettings = try container.decodeIfPresent(NetworkSettings.self, forKey: .networkSettings)
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(state)
        hasher.combine(status)
    }

    static func == (lhs: DockerContainer, rhs: DockerContainer) -> Bool {
        lhs.id == rhs.id && lhs.state == rhs.state && lhs.status == rhs.status
    }
}
