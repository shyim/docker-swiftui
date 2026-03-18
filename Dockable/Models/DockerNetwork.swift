import Foundation

struct DockerNetwork: Codable, Identifiable, Sendable {
    let id: String
    let name: String
    let driver: String
    let scope: String
    let ipam: IPAM?
    let labels: [String: String]?
    let isInternal: Bool?

    struct IPAM: Codable, Sendable {
        let driver: String?
        let config: [IPAMConfig]?

        struct IPAMConfig: Codable, Sendable {
            let subnet: String?
            let gateway: String?

            enum CodingKeys: String, CodingKey {
                case subnet = "Subnet"
                case gateway = "Gateway"
            }
        }

        enum CodingKeys: String, CodingKey {
            case driver = "Driver"
            case config = "Config"
        }
    }

    var shortId: String { String(id.prefix(12)) }

    var subnet: String? {
        ipam?.config?.first?.subnet
    }

    var isBuiltIn: Bool {
        ["bridge", "host", "none"].contains(name)
    }

    enum CodingKeys: String, CodingKey {
        case id = "Id"
        case name = "Name"
        case driver = "Driver"
        case scope = "Scope"
        case ipam = "IPAM"
        case labels = "Labels"
        case isInternal = "Internal"
    }
}
