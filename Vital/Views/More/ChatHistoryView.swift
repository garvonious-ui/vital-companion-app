import SwiftUI

struct ChatHistoryView: View {
    @Environment(APIService.self) var apiService
    @Environment(ChatHistoryManager.self) var chatHistory

    @State private var selectedConversation: ChatConversation?
    @State private var showNewChat = false

    var body: some View {
        ZStack {
            Brand.bg.ignoresSafeArea()

            if chatHistory.conversations.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "bubble.left.and.bubble.right.fill")
                        .font(.system(size: 40))
                        .foregroundColor(Brand.textMuted)
                    Text("No conversations yet")
                        .font(.subheadline)
                        .foregroundColor(Brand.textMuted)
                    Button("Start a Chat") {
                        showNewChat = true
                    }
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 24)
                    .padding(.vertical, 10)
                    .background(Brand.accent)
                    .foregroundColor(Brand.textPrimary)
                    .cornerRadius(10)
                }
            } else {
                List {
                    ForEach(chatHistory.conversations) { conversation in
                        Button {
                            selectedConversation = conversation
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(conversation.title)
                                    .font(.subheadline.weight(.medium))
                                    .foregroundColor(Brand.textPrimary)
                                    .lineLimit(1)

                                HStack {
                                    Text("\(conversation.messages.count) messages")
                                        .font(.caption)
                                        .foregroundColor(Brand.textMuted)
                                    Spacer()
                                    Text(formatDate(conversation.createdAt))
                                        .font(.caption)
                                        .foregroundColor(Brand.textMuted)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                        .listRowBackground(Brand.card)
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                chatHistory.delete(conversation)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                }
                .scrollContentBackground(.hidden)
                .listStyle(.plain)
            }
        }
        .navigationTitle("AI Insights")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showNewChat = true
                } label: {
                    Image(systemName: "square.and.pencil")
                        .foregroundColor(Brand.accent)
                }
            }
        }
        .navigationDestination(item: $selectedConversation) { conversation in
            ChatView(existingConversation: conversation)
        }
        .navigationDestination(isPresented: $showNewChat) {
            ChatView(existingConversation: nil)
        }
    }

    private func formatDate(_ date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            let formatter = DateFormatter()
            formatter.dateFormat = "h:mm a"
            return formatter.string(from: date)
        } else if calendar.isDateInYesterday(date) {
            return "Yesterday"
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "MMM d"
            return formatter.string(from: date)
        }
    }
}
