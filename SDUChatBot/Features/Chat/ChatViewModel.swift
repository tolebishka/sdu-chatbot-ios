import SwiftUI
import Combine
@MainActor
final class ChatViewModel: ObservableObject {
    @Published var messages: [MessageResponse] = []
    @Published var input: String = ""
    @Published var isThinking = false
    
    @Published var currentChatId: Int64? = nil
    
    private var currentTask: Task<Void, Never>?

    let suggestions: [String] = [
        "Где посмотреть расписание?",
        "Стипендии и гранты",
        "Как постуить в СДУ?",
        "Контакты приемной комисси",
        "Стоимость обучения",
        "Студенческие клубы и события"
    ]
    
    func followUpSuggestions() -> [String] {
        guard let last = messages.last, !last.isUser else {
            return []
        }
        
        let text = last.content.lowercased()
        
        if text.contains("расписан") {
            return [
                "Как смотреть изменения в расписании?",
                "Что делать если расписание не отображается?",
                "Как зайти в PMS?"
            ]
        }
        if text.contains("стипенд") || text.contains("грант") {
            return [
                "Какие бывают стипендии?",
                "Как подать документы на грант?",
                "Какие условия для стипендии?"
            ]
        }
        if text.contains("поступить") {
            return [
                "Какие документы нужны при поступлении?",
                "Какие проходные баллы?",
                "Есть ли подготовительные курсы?"
            ]
        }

        return [
            "Расскажи про факультеты",
            "Сколько стоит обучение?",
            "Какая студенческая жизнь в СДУ?"
        ]
    }
    
    func applySuggestion(_ text: String) {
        input = text
    }
    
    private func makeUserMessage(_ text: String) -> MessageResponse {
        MessageResponse(
            id: Int64.random(in: 1...Int64.max),
            content: text,
            sources: [],
            isUser: true,
            number: (messages.last?.number ?? 0) + 1,
            version: 1,
            createdDate: ISO8601DateFormatter().string(from: Date())
        )
    }
    
    func animateBotMessage(fullText: String, at index: Int) async {
        var output = ""

        for char in fullText {
            if Task.isCancelled { break }
            try? await Task.sleep(nanoseconds: 12_000_000)
            output.append(char)
            
            if index < messages.count {
                var msg = messages[index]
                msg.content = output
                messages[index] = msg
            }

        }
    }

    func startSend() {
        let text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        guard currentTask == nil else { return }

        currentTask = Task { [weak self] in
            await self?.send()
        }
    }

    func cancelCurrentResponse() {
        currentTask?.cancel()
        currentTask = nil
        isThinking = false
    }

    
    func send() async {
        let text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else {
            currentTask = nil
            return
        }

        let userMessage = makeUserMessage(text)
        input = ""
        messages.append(userMessage)

        isThinking = true
        defer {
            isThinking = false
            currentTask = nil
        }

        do {
            let api = APIClient.shared
            let resp: SendMessageResponse

            if let chatId = currentChatId {
                resp = try await api.sendMessage(chatId: chatId, content: text)
            } else {
                resp = try await api.sendMessagePublic(content: text)

                if resp.chatId != 0 {
                    currentChatId = resp.chatId
                }
            }

            var bot = resp.messageResponse

            if bot.id == 0 {
                bot.id = Int64.random(in: 1...Int64.max)
            }

            let animatedBot = MessageResponse(
                id: bot.id,
                content: "",
                sources: bot.sources,
                isUser: bot.isUser,
                number: (messages.last?.number ?? 0) + 1,
                version: bot.version,
                createdDate: bot.createdDate
            )

            messages.append(animatedBot)
            let index = messages.count - 1

            await animateBotMessage(fullText: bot.content, at: index)

        } catch {
            if Task.isCancelled { return }

            NetLogger.error(error)
            messages.append(
                MessageResponse(
                    id: Int64.random(in: 1...Int64.max),
                    content: "Не удалось получить ответ. Проверь сеть и эндпоинт.",
                    sources: [],
                    isUser: false,
                    number: (messages.last?.number ?? 0) + 1,
                    version: 1,
                    createdDate: ISO8601DateFormatter().string(from: Date())
                )
            )
        }
    }
}
