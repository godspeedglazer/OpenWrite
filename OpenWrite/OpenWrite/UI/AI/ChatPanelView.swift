import SwiftUI

struct ChatMessage: Identifiable, Hashable {
    enum Role: Hashable {
        case user
        case assistant
        case system
    }

    let id = UUID()
    let role: Role
    var text: String
    var sourceHits: [RetrievalHit]
    var isStreaming: Bool
}

@MainActor
final class ChatPanelModel: ObservableObject {
    @Published var messages: [ChatMessage] = []
    @Published var draft: String = ""
    @Published var isBusy = false
    @Published var statusLine: String?

    private var streamTask: Task<Void, Never>?

    func send(services: OpenWriteAIServices) {
        guard let query = AIInput.sanitizeQuery(draft) else { return }
        draft = ""
        streamTask?.cancel()

        messages.append(ChatMessage(role: .user, text: query, sourceHits: [], isStreaming: false))
        var assistantIndex = messages.count
        messages.append(ChatMessage(role: .assistant, text: "", sourceHits: [], isStreaming: true))
        isBusy = true
        statusLine = "Retrieving context…"

        streamTask = Task {
            do {
                let context = try await services.rag.buildContext(
                    query: query,
                    limit: AISafetyLimits.maxContextChunks
                )
                await MainActor.run {
                    if assistantIndex < messages.count {
                        messages[assistantIndex].sourceHits = context.hits
                    }
                    statusLine = context.hits.isEmpty
                        ? "No indexed matches"
                        : "\(context.hits.count) source\(context.hits.count == 1 ? "" : "s")"
                }

                for try await event in services.rag.streamAnswer(context: context) {
                    try Task.checkCancellation()
                    await MainActor.run {
                        guard assistantIndex < messages.count else { return }
                        switch event.kind {
                        case .token(let token):
                            messages[assistantIndex].text += token
                        case .citations:
                            break
                        case .completed:
                            messages[assistantIndex].isStreaming = false
                            isBusy = false
                            statusLine = nil
                        case .error(let message):
                            messages[assistantIndex].text = message
                            messages[assistantIndex].isStreaming = false
                            isBusy = false
                            statusLine = "Error"
                        }
                    }
                }
            } catch {
                await MainActor.run {
                    if assistantIndex < messages.count {
                        messages[assistantIndex].text = error.localizedDescription
                        messages[assistantIndex].isStreaming = false
                    }
                    isBusy = false
                    statusLine = "Error"
                }
            }
        }
    }

    func clear() {
        streamTask?.cancel()
        messages.removeAll()
        statusLine = nil
        isBusy = false
    }
}

struct ChatPanelView: View {
    @EnvironmentObject private var aiServices: OpenWriteAIServices
    @StateObject private var model = ChatPanelModel()

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            messageList
            Divider()
            composer
        }
        .frame(minWidth: 280)
    }

    private var header: some View {
        HStack {
            Text("Vault chat")
                .font(.headline)
            Spacer()
            if let statusLine = model.statusLine {
                Text(statusLine)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Button("Clear") { model.clear() }
                .disabled(model.messages.isEmpty)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    if model.messages.isEmpty {
                        ContentUnavailableView(
                            "Ask your vault",
                            systemImage: "sparkles",
                            description: Text("Answers cite indexed note chunks from this Mac.")
                        )
                        .frame(maxWidth: .infinity, minHeight: 200)
                    }
                    ForEach(model.messages) { message in
                        messageBubble(message)
                            .id(message.id)
                    }
                }
                .padding(12)
            }
            .onChange(of: model.messages.count) { _, _ in
                if let last = model.messages.last {
                    withAnimation(.easeOut(duration: 0.2)) {
                        proxy.scrollTo(last.id, anchor: .bottom)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func messageBubble(_ message: ChatMessage) -> some View {
        VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 6) {
            Text(message.text.isEmpty && message.isStreaming ? "…" : message.text)
                .textSelection(.enabled)
                .padding(10)
                .background(bubbleColor(for: message.role))
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .frame(maxWidth: .infinity, alignment: message.role == .user ? .trailing : .leading)

            if !message.sourceHits.isEmpty {
                sourcesView(message.sourceHits)
            }
        }
    }

    private func sourcesView(_ hits: [RetrievalHit]) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Sources")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            ForEach(hits.prefix(6)) { hit in
                VStack(alignment: .leading, spacing: 2) {
                    Text(hit.documentTitle)
                        .font(.caption.weight(.medium))
                    Text(hit.snippet)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                    Text("chunk:\(hit.id.uuidString.prefix(8))…")
                        .font(.caption2.monospaced())
                        .foregroundStyle(.tertiary)
                }
                .padding(6)
                .background(Color.secondary.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 6))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func bubbleColor(for role: ChatMessage.Role) -> Color {
        switch role {
        case .user:
            return Color.accentColor.opacity(0.18)
        case .assistant:
            return Color.secondary.opacity(0.12)
        case .system:
            return Color.orange.opacity(0.12)
        }
    }

    private var composer: some View {
        HStack(alignment: .bottom, spacing: 8) {
            TextField("Ask about your notes…", text: $model.draft, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(1 ... 4)
                .onSubmit { model.send(services: aiServices) }

            Button {
                model.send(services: aiServices)
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.title2)
            }
            .disabled(model.isBusy || AIInput.sanitizeQuery(model.draft) == nil)
            .keyboardShortcut(.return, modifiers: [.command])
        }
        .padding(12)
    }
}
