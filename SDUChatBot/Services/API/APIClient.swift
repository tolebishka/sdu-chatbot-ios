import Foundation

private let tokenKey = "auth.accessToken"

final class APIClient {
    static let shared = APIClient()
    private init() {}

    private var accessToken: String? {
        get { Keychain.get(tokenKey).flatMap { String(data: $0, encoding: .utf8) } }
        set {
            if let s = newValue { Keychain.set(Data(s.utf8), for: tokenKey) }
            else { Keychain.delete(tokenKey) }
        }
    }

    func setToken(_ token: String?) { accessToken = token }
    func getToken() -> String? { accessToken }

    private func request(path: String,
                         method: String = "GET",
                         body: Encodable? = nil) throws -> URLRequest {
        var req = URLRequest(url: Env.baseURL.appendingPathComponent(path))
        req.httpMethod = method
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let t = accessToken { req.setValue("Bearer \(t)", forHTTPHeaderField: "Authorization") }
        if let body {
            req.httpBody = try JSONEncoder().encode(AnyEncodable(body))
        }
        return req
    }

    private func send<T: Decodable>(_ req: URLRequest) async throws -> T {
        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse else { throw URLError(.badServerResponse) }
        if 200..<300 ~= http.statusCode {
            return try JSONDecoder().decode(T.self, from: data)
        } else {
            if let e = try? JSONDecoder().decode(ErrorResponse.self, from: data) { throw e }
            throw URLError(.init(rawValue: http.statusCode))
        }
    }

    // MARK: Auth
    struct CodeDTO: Encodable { let code: String }

    func authGoogle(code: String) async throws -> LoginResponse {
        let req = try request(path: "auth/google", method: "POST", body: CodeDTO(code: code))
        let resp: LoginResponse = try await send(req)
        setToken(resp.accessToken)
        return resp
    }

    // MARK: Chats
    func getChats(page: Int = 0, size: Int = 20) async throws -> PaginatedResponse<ChatResponse> {
        var comps = URLComponents(url: Env.baseURL.appendingPathComponent("chats"), resolvingAgainstBaseURL: false)!
        comps.queryItems = [URLQueryItem(name: "page", value: "\(page)"),
                            URLQueryItem(name: "size", value: "\(size)")]
        var req = URLRequest(url: comps.url!)
        req.httpMethod = "GET"
        if let t = accessToken { req.setValue("Bearer \(t)", forHTTPHeaderField: "Authorization") }
        return try await send(req)
    }

    struct ChatCreateRequest: Encodable { let title: String }
    func createChat(title: String) async throws -> ChatResponse {
        let req = try request(path: "chats", method: "POST", body: ChatCreateRequest(title: title))
        return try await send(req)
    }

    func getChat(_ id: Int64) async throws -> ChatResponse {
        let req = try request(path: "chats/\(id)")
        return try await send(req)
    }

    func deleteChat(_ id: Int64) async throws {
        let req = try request(path: "chats/\(id)", method: "DELETE")
        let _: Empty = try await send(req)
    }

    // MARK: Messages
    struct MessageCreateRequest: Encodable { let content: String }

    func getMessages(chatId: Int64, page: Int = 0, size: Int = 30) async throws -> PaginatedResponse<MessageResponse> {
        var comps = URLComponents(url: Env.baseURL.appendingPathComponent("chats/\(chatId)/messages"), resolvingAgainstBaseURL: false)!
        comps.queryItems = [URLQueryItem(name: "page", value: "\(page)"),
                            URLQueryItem(name: "size", value: "\(size)")]
        var req = URLRequest(url: comps.url!)
        req.httpMethod = "GET"
        if let t = accessToken { req.setValue("Bearer \(t)", forHTTPHeaderField: "Authorization") }
        return try await send(req)
    }

    func sendMessage(chatId: Int64, content: String) async throws -> SendMessageResponse {
        let req = try request(path: "chats/\(chatId)/messages", method: "POST",
                              body: MessageCreateRequest(content: content))
        return try await send(req)
    }

    func createChatAndSend(content: String) async throws -> SendMessageResponse {
        let req = try request(path: "messages/first", method: "POST",
                              body: MessageCreateRequest(content: content))
        return try await send(req)
    }
    // === PUBLIC, no auth ===
    func sendMessagePublic(content: String) async throws -> SendMessageResponse {
        struct MessageCreateRequest: Encodable { let content: String }

        var req = URLRequest(url: Env.baseURL.appendingPathComponent("chats/send-message"))
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONEncoder().encode(MessageCreateRequest(content: content))

        NetLogger.req(req)

        do {
            if let b = Env.staticBearer, !b.isEmpty {
                req.setValue(b, forHTTPHeaderField: "Authorization")
            }

            let (data, resp) = try await URLSession.shared.data(for: req)
            NetLogger.resp(resp, data: data)

            do {
                return try JSONDecoder().decode(SendMessageResponse.self, from: data)
            } catch {
                struct WebBotResponse: Codable {
                    let content: String?
                    let answer: String?
                    let message: String?
                    let sources: [String]?
                }
                let w = try JSONDecoder().decode(WebBotResponse.self, from: data)
                let text = w.content ?? w.answer ?? w.message ?? "(пусто)"
                let msg = MessageResponse(
                    id: Int64(Date().timeIntervalSince1970),
                    content: text, sources: w.sources ?? [],
                    isUser: false, number: 0, version: 1,
                    createdDate: ISO8601DateFormatter().string(from: Date()))
                return SendMessageResponse(chatId: 0, title: "Web", messageResponse: msg, createdDate: msg.createdDate)
            }
        } catch {
            NetLogger.error(error)
            throw error
        }
    }
}

private struct Empty: Decodable {}
struct AnyEncodable: Encodable {
    private let _encode: (Encoder) throws -> Void
    init(_ encodable: Encodable) { _encode = encodable.encode }
    func encode(to encoder: Encoder) throws { try _encode(encoder) }
}
