import SwiftUI

struct ChatView: View {
    @Environment(APIService.self) var apiService
    @Environment(ChatHistoryManager.self) var chatHistory

    let existingConversation: ChatConversation?

    @State private var conversation: ChatConversation
    @State private var inputText: String = ""
    @State private var isStreaming = false
    @State private var streamTask: Task<Void, Never>?

    init(existingConversation: ChatConversation?) {
        self.existingConversation = existingConversation
        self._conversation = State(initialValue: existingConversation ?? ChatConversation())
    }

    var body: some View {
        ZStack {
            Brand.bg.ignoresSafeArea()

            VStack(spacing: 0) {
                // Messages
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            if conversation.messages.isEmpty {
                                welcomeCard
                                    .padding(.top, 40)
                            }

                            ForEach(conversation.messages) { message in
                                messageBubble(message)
                                    .id(message.id)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                    }
                    .onChange(of: conversation.messages.count) { _, _ in
                        if let last = conversation.messages.last {
                            withAnimation {
                                proxy.scrollTo(last.id, anchor: .bottom)
                            }
                        }
                    }
                }

                // Input bar
                inputBar
            }
        }
        .navigationTitle("AI Health Chat")
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear {
            streamTask?.cancel()
            // Save conversation if it has messages
            if !conversation.messages.isEmpty {
                conversation.updateTitle()
                chatHistory.save(conversation)
            }
        }
    }

    // MARK: - Welcome

    private var welcomeCard: some View {
        VStack(spacing: 16) {
            Image(systemName: "bubble.left.and.bubble.right.fill")
                .font(.system(size: 40))
                .foregroundColor(Brand.secondary.opacity(0.6))

            Text("Health Assistant")
                .font(.headline)
                .foregroundColor(Brand.textPrimary)

            Text("Ask me anything about your health data, recovery, nutrition, or training. I have access to your metrics and history.")
                .font(.subheadline)
                .foregroundColor(Brand.textSecondary)
                .multilineTextAlignment(.center)
                .lineSpacing(4)

            // Suggestion chips
            VStack(spacing: 8) {
                suggestionChip("How's my recovery looking?")
                suggestionChip("Am I hitting my protein target?")
                suggestionChip("What should I focus on this week?")
            }
        }
        .padding(24)
    }

    private func suggestionChip(_ text: String) -> some View {
        Button {
            inputText = text
            sendMessage()
        } label: {
            Text(text)
                .font(.caption)
                .foregroundColor(Brand.accent)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(Brand.accent.opacity(0.1))
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Brand.accent.opacity(0.2), lineWidth: 1)
                )
        }
    }

    // MARK: - Message Bubble

    private func messageBubble(_ message: ChatMessage) -> some View {
        HStack {
            if message.role == .user { Spacer(minLength: 60) }

            VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 4) {
                Text(markdownAttributed(message.content))
                    .font(.subheadline)
                    .foregroundColor(Brand.textPrimary)
                    .lineSpacing(4)
                    .textSelection(.enabled)

                if message.role == .assistant && isStreaming && message.id == conversation.messages.last?.id {
                    HStack(spacing: 4) {
                        Circle().fill(Brand.secondary).frame(width: 4, height: 4)
                            .opacity(0.6)
                        Circle().fill(Brand.secondary).frame(width: 4, height: 4)
                            .opacity(0.4)
                        Circle().fill(Brand.secondary).frame(width: 4, height: 4)
                            .opacity(0.2)
                    }
                    .padding(.top, 2)
                }
            }
            .padding(12)
            .background(
                message.role == .user
                    ? Brand.accent.opacity(0.2)
                    : Brand.card
            )
            .cornerRadius(14)
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(
                        message.role == .user
                            ? Brand.accent.opacity(0.15)
                            : Color.white.opacity(0.06),
                        lineWidth: 1
                    )
            )

            if message.role == .assistant { Spacer(minLength: 60) }
        }
    }

    // MARK: - Input Bar

    private var inputBar: some View {
        HStack(spacing: 10) {
            TextField("Ask about your health...", text: $inputText, axis: .vertical)
                .lineLimit(1...4)
                .font(.subheadline)
                .foregroundColor(Brand.textPrimary)
                .padding(12)
                .background(Brand.card)
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.white.opacity(0.06), lineWidth: 1)
                )

            Button {
                sendMessage()
            } label: {
                Image(systemName: isStreaming ? "stop.fill" : "arrow.up.circle.fill")
                    .font(.title2)
                    .foregroundColor(
                        inputText.trimmingCharacters(in: .whitespaces).isEmpty && !isStreaming
                            ? Brand.textMuted
                            : Brand.accent
                    )
            }
            .disabled(inputText.trimmingCharacters(in: .whitespaces).isEmpty && !isStreaming)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Brand.bg)
    }

    // MARK: - Send & Stream

    private func markdownAttributed(_ string: String) -> AttributedString {
        (try? AttributedString(markdown: string, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace))) ?? AttributedString(string)
    }

    private func sendMessage() {
        if isStreaming {
            streamTask?.cancel()
            isStreaming = false
            return
        }

        let text = inputText.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return }

        inputText = ""
        conversation.messages.append(ChatMessage(role: .user, content: text))

        // Add placeholder for assistant
        let assistantMessage = ChatMessage(role: .assistant, content: "")
        conversation.messages.append(assistantMessage)
        let assistantIndex = conversation.messages.count - 1

        isStreaming = true

        streamTask = Task {
            do {
                let body = ChatRequest(message: text)
                let (bytes, response) = try await apiService.postStream("/ai/chat", body: body)

                guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
                    conversation.messages[assistantIndex].content = "Sorry, I couldn't get a response. Please try again."
                    isStreaming = false
                    return
                }

                // Parse SSE stream
                for try await line in bytes.lines {
                    if Task.isCancelled { break }

                    if line.hasPrefix("data: ") {
                        let data = String(line.dropFirst(6))

                        if data == "[DONE]" {
                            break
                        }

                        // Try to parse as JSON
                        if let jsonData = data.data(using: .utf8),
                           let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] {
                            let type = json["type"] as? String
                            // Only extract text from "text" type events
                            if type == "text", let text = json["text"] as? String {
                                await MainActor.run {
                                    conversation.messages[assistantIndex].content += text
                                }
                            } else if type == "content", let text = json["content"] as? String {
                                // Alternate format
                                await MainActor.run {
                                    conversation.messages[assistantIndex].content += text
                                }
                            }
                            // Skip conversation_id, remaining, and other control events
                        } else if !data.starts(with: "{") {
                            // Plain text token (not JSON)
                            await MainActor.run {
                                conversation.messages[assistantIndex].content += data
                            }
                        }
                    }
                }
            } catch {
                if !Task.isCancelled {
                    await MainActor.run {
                        if conversation.messages[assistantIndex].content.isEmpty {
                            conversation.messages[assistantIndex].content = "Connection error. Please try again."
                        }
                    }
                }
            }

            await MainActor.run {
                isStreaming = false
                // Auto-save after each response
                conversation.updateTitle()
                chatHistory.save(conversation)
            }
        }
    }
}

// MARK: - SSE Token

private struct SSEToken: Decodable {
    let content: String
}
