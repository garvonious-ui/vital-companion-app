import SwiftUI

struct ChatView: View {
    @EnvironmentObject var apiService: APIService

    @State private var messages: [ChatMessage] = []
    @State private var inputText: String = ""
    @State private var isStreaming = false
    @State private var streamTask: Task<Void, Never>?

    var body: some View {
        ZStack {
            Color(hex: 0x0A0A0C).ignoresSafeArea()

            VStack(spacing: 0) {
                // Messages
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            if messages.isEmpty {
                                welcomeCard
                                    .padding(.top, 40)
                            }

                            ForEach(messages) { message in
                                messageBubble(message)
                                    .id(message.id)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                    }
                    .onChange(of: messages.count) { _, _ in
                        if let last = messages.last {
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
        }
    }

    // MARK: - Welcome

    private var welcomeCard: some View {
        VStack(spacing: 16) {
            Image(systemName: "bubble.left.and.bubble.right.fill")
                .font(.system(size: 40))
                .foregroundColor(Color(hex: 0x8B5CF6).opacity(0.6))

            Text("Health Assistant")
                .font(.headline)
                .foregroundColor(.white)

            Text("Ask me anything about your health data, recovery, nutrition, or training. I have access to your metrics and history.")
                .font(.subheadline)
                .foregroundColor(Color(hex: 0xA0A0B0))
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
                .foregroundColor(Color(hex: 0x00B4D8))
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(Color(hex: 0x00B4D8).opacity(0.1))
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color(hex: 0x00B4D8).opacity(0.2), lineWidth: 1)
                )
        }
    }

    // MARK: - Message Bubble

    private func messageBubble(_ message: ChatMessage) -> some View {
        HStack {
            if message.role == .user { Spacer(minLength: 60) }

            VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 4) {
                Text(message.content)
                    .font(.subheadline)
                    .foregroundColor(.white)
                    .lineSpacing(4)
                    .textSelection(.enabled)

                if message.role == .assistant && isStreaming && message.id == messages.last?.id {
                    HStack(spacing: 4) {
                        Circle().fill(Color(hex: 0x8B5CF6)).frame(width: 4, height: 4)
                            .opacity(0.6)
                        Circle().fill(Color(hex: 0x8B5CF6)).frame(width: 4, height: 4)
                            .opacity(0.4)
                        Circle().fill(Color(hex: 0x8B5CF6)).frame(width: 4, height: 4)
                            .opacity(0.2)
                    }
                    .padding(.top, 2)
                }
            }
            .padding(12)
            .background(
                message.role == .user
                    ? Color(hex: 0x00B4D8).opacity(0.2)
                    : Color(hex: 0x141418)
            )
            .cornerRadius(14)
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(
                        message.role == .user
                            ? Color(hex: 0x00B4D8).opacity(0.15)
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
                .foregroundColor(.white)
                .padding(12)
                .background(Color(hex: 0x141418))
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
                            ? Color(hex: 0x606070)
                            : Color(hex: 0x00B4D8)
                    )
            }
            .disabled(inputText.trimmingCharacters(in: .whitespaces).isEmpty && !isStreaming)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color(hex: 0x0A0A0C))
    }

    // MARK: - Send & Stream

    private func sendMessage() {
        if isStreaming {
            streamTask?.cancel()
            isStreaming = false
            return
        }

        let text = inputText.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return }

        inputText = ""
        messages.append(ChatMessage(role: .user, content: text))

        // Add placeholder for assistant
        let assistantMessage = ChatMessage(role: .assistant, content: "")
        messages.append(assistantMessage)
        let assistantIndex = messages.count - 1

        isStreaming = true

        streamTask = Task {
            do {
                let body = ChatRequest(message: text)
                let (bytes, response) = try await apiService.postStream("/ai/chat", body: body)

                guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
                    messages[assistantIndex].content = "Sorry, I couldn't get a response. Please try again."
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

                        // Try to parse as JSON token
                        if let jsonData = data.data(using: .utf8),
                           let token = try? JSONDecoder().decode(SSEToken.self, from: jsonData) {
                            await MainActor.run {
                                messages[assistantIndex].content += token.content
                            }
                        } else {
                            // Plain text token
                            await MainActor.run {
                                messages[assistantIndex].content += data
                            }
                        }
                    }
                }
            } catch {
                if !Task.isCancelled {
                    await MainActor.run {
                        if messages[assistantIndex].content.isEmpty {
                            messages[assistantIndex].content = "Connection error. Please try again."
                        }
                    }
                }
            }

            await MainActor.run {
                isStreaming = false
            }
        }
    }
}

// MARK: - SSE Token

private struct SSEToken: Decodable {
    let content: String
}
