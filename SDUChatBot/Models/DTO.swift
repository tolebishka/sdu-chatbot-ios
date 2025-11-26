import Foundation

struct LoginResponse: Codable {
    let accessToken: String
    let refreshToken: String?
}

struct ErrorResponse: Codable, Error {
    let error: String
    let message: String
    let timestamp: Int64
}

struct ChatResponse: Codable, Identifiable {
    let id: Int64
    let title: String
    let createdDate: String
}

struct MessageResponse: Codable, Identifiable {
    var id: Int64
    var content: String
    let sources: [String]
    let isUser: Bool
    let number: Int
    let version: Int
    let createdDate: String

    enum CodingKeys: String, CodingKey {
        case id, content, sources, number, version, createdDate
        case isUser = "user"
    }
}

struct SendMessageResponse: Codable {
    let chatId: Int64
    let title: String
    let messageResponse: MessageResponse
    let createdDate: String?
}

struct PaginatedResponse<T: Codable>: Codable {
    let items: [T]?
    let content: [T]?
    let page: Int?
    let size: Int?
    let total: Int?
    let totalElements: Int?
    let totalPages: Int?
    var data: [T] { items ?? content ?? [] }
}
