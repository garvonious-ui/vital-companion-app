import SwiftUI

struct ChatView: View {
    @Environment(APIService.self) var apiService
    @Environment(ChatHistoryManager.self) var chatHistory

    let existingConversation: ChatConversation?

    @State private var conversation: ChatConversation
    @State private var inputText: String = ""
    @State private var isStreaming = false
    @State private var streamTask: Task<Void, Never>?
    @State private var pendingAction: ChatAction?
    @State private var actionExecuting = false
    @State private var actionResult: String?

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

                            if let action = pendingAction {
                                actionCard(action)
                                    .id("action-card")
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
                // Parse action from response
                if let lastMessage = conversation.messages.last, lastMessage.role == .assistant {
                    let parsed = ChatAction.parse(from: lastMessage.content)
                    if let action = parsed.action {
                        pendingAction = action
                        // Strip action tag from displayed message
                        conversation.messages[conversation.messages.count - 1].content = parsed.cleanContent
                    }
                }
                // Auto-save after each response
                conversation.updateTitle()
                chatHistory.save(conversation)
            }
        }
    }

    // MARK: - Action Card

    private func actionCard(_ action: ChatAction) -> some View {
        VStack(spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: action.icon)
                    .font(.title3)
                    .foregroundColor(Brand.accent)
                    .frame(width: 36, height: 36)
                    .background(Brand.accent.opacity(0.15))
                    .cornerRadius(8)

                VStack(alignment: .leading, spacing: 2) {
                    Text(action.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(Brand.textPrimary)
                    Text(action.subtitle)
                        .font(.caption)
                        .foregroundColor(Brand.textSecondary)
                }

                Spacer()
            }

            if let result = actionResult {
                Text(result)
                    .font(.caption)
                    .foregroundColor(Brand.optimal)
            } else {
                HStack(spacing: 12) {
                    Button {
                        Task { await executeAction(action) }
                    } label: {
                        HStack {
                            if actionExecuting {
                                ProgressView().tint(Brand.bg).scaleEffect(0.8)
                            }
                            Text(actionExecuting ? "Adding..." : "Yes, add it")
                                .font(.subheadline.weight(.semibold))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Brand.accent)
                        .foregroundColor(Brand.bg)
                        .cornerRadius(10)
                    }
                    .disabled(actionExecuting)

                    Button {
                        withAnimation { pendingAction = nil }
                    } label: {
                        Text("No thanks")
                            .font(.subheadline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(Brand.elevated)
                            .foregroundColor(Brand.textSecondary)
                            .cornerRadius(10)
                    }
                    .disabled(actionExecuting)
                }
            }
        }
        .padding(14)
        .background(Brand.card)
        .cornerRadius(14)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Brand.accent.opacity(0.2), lineWidth: 1)
        )
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }

    private func executeAction(_ action: ChatAction) async {
        actionExecuting = true
        defer { actionExecuting = false }

        do {
            switch action.type {
            case .addSupplement:
                let jsonData = try JSONSerialization.data(withJSONObject: action.payload)
                let _: SuccessResponse = try await apiService.postRaw("/supplements", jsonData: jsonData)
                actionResult = "Added to your supplements"

            case .logWater:
                let oz = (action.payload["oz"] as? Double) ?? Double(action.payload["oz"] as? Int ?? 0)
                let dateStr = formatDate(Date())
                let body: [String: Any] = ["date": dateStr, "waterOz": oz]
                let jsonData = try JSONSerialization.data(withJSONObject: body)
                let _: SuccessResponse = try await apiService.patchRaw("/metrics", jsonData: jsonData)
                actionResult = "Logged \(oz)oz of water"

            case .logSleep:
                let hours = action.payload["hours"] as? Double ?? 0
                let dateStr = formatDate(Date())
                let body: [String: Any] = ["date": dateStr, "sleepHours": hours]
                let jsonData = try JSONSerialization.data(withJSONObject: body)
                let _: SuccessResponse = try await apiService.patchRaw("/metrics", jsonData: jsonData)
                actionResult = "Logged \(hours)h of sleep"
            }

            HapticManager.success()
        } catch {
            actionResult = "Failed: \(error.localizedDescription)"
        }
    }

    private func formatDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f.string(from: date)
    }
}

// MARK: - Chat Action Model

enum ChatActionType: String {
    case addSupplement = "add_supplement"
    case logWater = "log_water"
    case logSleep = "log_sleep"
}

struct ChatAction {
    let type: ChatActionType
    let payload: [String: Any]

    var icon: String {
        switch type {
        case .addSupplement: return "pill.fill"
        case .logWater: return "drop.fill"
        case .logSleep: return "moon.fill"
        }
    }

    var title: String {
        switch type {
        case .addSupplement: return "Add Supplement"
        case .logWater: return "Log Water"
        case .logSleep: return "Log Sleep"
        }
    }

    var subtitle: String {
        switch type {
        case .addSupplement:
            let name = payload["name"] as? String ?? "Unknown"
            let dosage = payload["dosage"] as? String ?? ""
            return "\(name) \(dosage)".trimmingCharacters(in: .whitespaces)
        case .logWater:
            let oz = (payload["oz"] as? Int) ?? Int(payload["oz"] as? Double ?? 0)
            return "\(oz)oz"
        case .logSleep:
            let hours = payload["hours"] as? Double ?? 0
            return "\(hours) hours"
        }
    }

    static func parse(from content: String) -> (action: ChatAction?, cleanContent: String) {
        let pattern = #"\[ACTION:(\w+)\s+(\{[^]]+\})\]"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: content, range: NSRange(content.startIndex..., in: content)),
              let typeRange = Range(match.range(at: 1), in: content),
              let jsonRange = Range(match.range(at: 2), in: content) else {
            return (nil, content)
        }

        let typeStr = String(content[typeRange])
        let jsonStr = String(content[jsonRange])

        guard let actionType = ChatActionType(rawValue: typeStr),
              let jsonData = jsonStr.data(using: .utf8),
              let payload = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else {
            return (nil, content)
        }

        // Remove action tag from content
        let fullMatchRange = Range(match.range, in: content)!
        var clean = content
        clean.removeSubrange(fullMatchRange)
        clean = clean.trimmingCharacters(in: .whitespacesAndNewlines)

        return (ChatAction(type: actionType, payload: payload), clean)
    }
}

// MARK: - SSE Token

private struct SSEToken: Decodable {
    let content: String
}
