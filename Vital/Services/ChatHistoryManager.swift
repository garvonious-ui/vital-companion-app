import Foundation

@Observable
@MainActor
final class ChatHistoryManager {
    private(set) var conversations: [ChatConversation] = []

    private static var fileURL: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return docs.appending(path: "chat_history.json")
    }

    init() {
        load()
    }

    func save(_ conversation: ChatConversation) {
        // Update existing or insert new
        if let index = conversations.firstIndex(where: { $0.id == conversation.id }) {
            conversations[index] = conversation
        } else {
            conversations.insert(conversation, at: 0)
        }
        // Keep last 50 conversations
        if conversations.count > 50 {
            conversations = Array(conversations.prefix(50))
        }
        persist()
    }

    func delete(_ conversation: ChatConversation) {
        conversations.removeAll { $0.id == conversation.id }
        persist()
    }

    private func load() {
        guard FileManager.default.fileExists(atPath: Self.fileURL.path) else { return }
        do {
            let data = try Data(contentsOf: Self.fileURL)
            conversations = try JSONDecoder().decode([ChatConversation].self, from: data)
        } catch {
            print("[ChatHistory] Failed to load: \(error)")
        }
    }

    private func persist() {
        do {
            let data = try JSONEncoder().encode(conversations)
            // Session 25 compliance fix: write with iOS Data Protection so
            // the chat history file (which contains health-context AI
            // responses) cannot be read by other apps or before the device
            // has been unlocked at least once since boot.
            //
            // `.completeFileProtectionUntilFirstUserAuthentication` is the
            // right class for this file — stricter than default, but
            // compatible with background sync (which needs to run before
            // the user has actively unlocked). For a chat history file
            // that's only written by foreground user action, this is safe.
            try data.write(
                to: Self.fileURL,
                options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication]
            )
        } catch {
            print("[ChatHistory] Failed to save: \(error)")
        }
    }
}
