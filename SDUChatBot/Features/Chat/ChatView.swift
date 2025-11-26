import SwiftUI
import UIKit

struct ChatView: View {
    @StateObject var vm = ChatViewModel()
    @State private var scrollToBottomToken = UUID()
    

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [Color(.systemBackground), Color(.secondarySystemBackground)],
                    startPoint: .top, endPoint: .bottom
                )
                .ignoresSafeArea()

                VStack(spacing: 0) {
                    if vm.messages.isEmpty {
                        EmptyState(
                            suggestions: vm.suggestions,
                            onTap: { text in vm.input = text },
                            onLongPress: { text in
                                vm.input = text
                                Task { await vm.send() }
                            }
                        )
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    } else {
                        MessagesList(messages: vm.messages, scrollToken: scrollToBottomToken)
                            .environmentObject(vm)
                        let followUps = vm.followUpSuggestions()
                        if !followUps.isEmpty {
                            SuggestionsRow(suggestions: followUps) { text in
                                vm.applySuggestion(text)
                            }
                        }
                    }
                }

            }
            .safeAreaInset(edge: .bottom) {
                InputBar(
                    text: $vm.input,
                    isThinking: vm.isThinking,
                    onSend: {
                        Task { await vm.startSend() }
                        scrollToBottomToken = UUID()
                    },
                    onStop: {
                        vm.cancelCurrentResponse()
                    }
                )
                .background(.ultraThinMaterial)
                .overlay(Divider(), alignment: .top)
            }
            .navigationTitle("SDU Chat")
            .navigationBarTitleDisplayMode(.inline)
            .onChange(of: vm.messages.count) { _, _ in
                scrollToBottomToken = UUID()
            }
            .gesture(DragGesture().onChanged { _ in
                UIApplication.shared.endEditing()
            })
        }
    }
}

struct MessagesList: View {
    let messages: [MessageResponse]
    let scrollToken: UUID

    @EnvironmentObject var vm: ChatViewModel

    
    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    ForEach(Array(messages.enumerated()), id: \.offset) { index, m in
                        MessageRow(message: m)
                            .id(index)
                            .padding(.horizontal, 12)
                    }
                    if vm.isThinking {
                        HStack(alignment: .bottom) {
                            TypingIndicatorBubble()
                                .padding(.leading, 8)
                            Spacer()
                        }
                        .transition(.opacity.combined(with: .move(edge: .leading)))
                    }

                    Color.clear
                        .frame(height: 1)
                        .id("bottom-anchor")
                        .padding(.bottom, 4)
                }
                .padding(.top, 8)
            }
            .onChange(of: scrollToken) { _, _ in
                withAnimation(.easeOut(duration: 0.2)) {
                    proxy.scrollTo("bottom-anchor", anchor: .bottom)
                }
            }
            .onAppear {
                proxy.scrollTo("bottom-anchor", anchor: .bottom)
            }
        }
    }
}

struct MessageRow: View {
    let message: MessageResponse

    
    var body: some View {
        VStack(alignment: message.isUser ? .trailing : .leading, spacing: 4) {
            HStack {
                if message.isUser { Spacer(minLength: 40) }

                VStack(alignment: .leading, spacing: 6) {
                    Text(message.content)
                        .font(.body)
                        .foregroundStyle(message.isUser ? .white : .primary)
                    if !message.sources.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Источники")
                                .font(.caption).foregroundStyle(.secondary)
                            ForEach(message.sources, id: \.self) { s in
                                if let url = URL(string: s), s.lowercased().hasPrefix("http") || s.lowercased().hasPrefix("https") {
                                    Link(destination: url) {
                                        Text(s)
                                            .font(.caption2)
                                            .underline()
                                    }
                                } else {
                                    Text("• \(s)").font(.caption2)
                                }
                            }
                        }
                    }
                }
                .padding(.vertical, 10)
                .padding(.horizontal, 12)
                .background {
                    if message.isUser {
                        LinearGradient(
                            colors: [.sduPrimary, .sduPrimary.opacity(0.8)],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        )
                    } else {
                        Color(.secondarySystemBackground)
                    }
                }

                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(message.isUser ? Color.clear : Color.black.opacity(0.05))
                )
                .shadow(color: .black.opacity(message.isUser ? 0.08 : 0.04), radius: 8, y: 2)

                if !message.isUser { Spacer(minLength: 40) }
            }

            if let date = parseISODate(message.createdDate) {
                Text(formatTime(date))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: message.isUser ? .trailing : .leading)
                    .padding(.horizontal, 12)
            }
        }
    }

    private func parseISODate(_ s: String) -> Date? {
        let fmt = ISO8601DateFormatter()
        fmt.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = fmt.date(from: s) { return d }
        fmt.formatOptions = [.withInternetDateTime]
        return fmt.date(from: s)
    }

    private func formatTime(_ d: Date) -> String {
        let f = DateFormatter()
        f.timeStyle = .short
        f.dateStyle = .none
        return f.string(from: d)
    }
}

struct InputBar: View {
    @Binding var text: String
    var isThinking: Bool
    var onSend: () -> Void
    var onStop: () -> Void
    
    var body: some View {
        HStack(spacing: 10) {

            HStack {
                TextField("Задайте вопрос о SDU…", text: $text, axis: .vertical)
                    .textFieldStyle(.plain)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 12)
            }
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color(.systemBackground).opacity(0.95))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(Color.gray.opacity(0.15), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.05), radius: 4, y: 2)

            Button {
                if isThinking {
                    onStop()
                } else {
                    onSend()
                }
            } label: {
                Group {
                    if isThinking {
                        Image(systemName: "stop.fill")
                            .font(.system(size: 16, weight: .bold))
                    } else {
                        Image("Frame")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 18, height: 18)
                    }
                }
                .padding(14)
                .background(
                    isThinking
                    ? Color.sduPrimary
                    : (text.trimmed().isEmpty ? Color.gray.opacity(0.25) : Color("sduPrimary"))
                )
                .foregroundColor(.white)
                .clipShape(Circle())
                .shadow(
                    color: Color.black.opacity(
                        (isThinking || !text.trimmed().isEmpty) ? 0.15 : 0
                    ),
                    radius: 4, y: 2
                )
            }
            .disabled(!isThinking && text.trimmed().isEmpty)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
    }

}



private extension String {
    func trimmed() -> String { trimmingCharacters(in: .whitespacesAndNewlines) }
}

private extension UIApplication {
    func endEditing() {
        sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}

struct EmptyState: View {
    let suggestions: [String]
    var onTap: (String) -> Void
    var onLongPress: (String) -> Void

    var body: some View {
        VStack(spacing: 24) {
            Spacer(minLength: 24)

            Image("sdu_logo")
                .resizable()
                .scaledToFit()
                .frame(width: 220, height: 150)
                .layoutPriority(1)
                .accessibilityHidden(true)

            Spacer()

            SuggestionChips(suggestions: suggestions, onTap: onTap, onLongPress: onLongPress)
                .padding(.bottom, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}


struct SuggestionChips: View {
    let suggestions: [String]
    var onTap: (String) -> Void
    var onLongPress: (String) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(suggestions, id: \.self) { s in
                    Button {
                        onTap(s)
                    } label: {
                        HStack(spacing: 8) {
                            Text(s)
                                .font(.system(size: 13))
                                .lineLimit(2)
                                .padding(.vertical, 10)
                                .padding(.horizontal, 14)
                        }
                        .background(.sduPrimary)
                        .foregroundColor(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                    .simultaneousGesture(
                        LongPressGesture(minimumDuration: 0.35).onEnded { _ in onLongPress(s) }
                    )
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 4)
        }
    }
}

struct TypingIndicatorBubble: View {
    @State private var animate = false

    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<3) { i in
                Circle()
                    .frame(width: 8, height: 8)
                    .scaleEffect(animate ? 1.0 : 0.5)
                    .opacity(animate ? 1.0 : 0.3)
                    .animation(
                        .easeInOut(duration: 0.6).repeatForever().delay(Double(i) * 0.18),
                        value: animate
                    )
            }
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 14)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color(.systemGray4), lineWidth: 0.5)
        )
        .onAppear { animate = true }
    }
}


struct SuggestionsRow: View {
    let suggestions: [String]
    let onTap: (String) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(suggestions, id: \.self) { suggestion in
                    Button {
                        onTap(suggestion)
                    } label: {
                        Text(suggestion)
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(Color("sduPrimary"))
                            .clipShape(Capsule())
                    }
                }
            }
            .padding(.horizontal, 16)
        }
        .padding(.vertical, 8)
    }
}

struct MarkdownText: View {
    let text: String

    var body: some View {
        if let attributed = try? AttributedString(
            markdown: text,
            options: AttributedString.MarkdownParsingOptions(
                allowsExtendedAttributes: true, interpretedSyntax: .full
            )
        ) {
            Text(attributed)
                .lineSpacing(4)
        } else {
            Text(text)
        }
    }
}
