import Foundation

struct DockerEvent: Codable, Sendable {
    let type: String?
    let action: String?
    let actor: Actor?
    let time: Int?

    struct Actor: Codable, Sendable {
        let id: String?
        let attributes: [String: String]?

        enum CodingKeys: String, CodingKey {
            case id = "ID"
            case attributes = "Attributes"
        }
    }

    enum CodingKeys: String, CodingKey {
        case type = "Type"
        case action = "Action"
        case actor = "Actor"
        case time
    }
}
