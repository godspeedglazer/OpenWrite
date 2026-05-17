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
    @Published var retrievalSummary: String?

    private var streamTask: Task<Void, Never>?

    var isBusy: Bool {
        streamTask != nil
    }

    func send(services: OpenWriteAIServices, agent: AgentConfig) {
        guard let query = AIInput.sanitizeQuery(draft) else { return }
        draft = ""
        streamTask?.cancel()

        messages.append(ChatMessage(role: .user, text: query, sourceHits: [], isStreaming: false))
        let assistantIndex = messages.count
        messages.append(ChatMessage(role: .assistant, text: "", sourceHits: [], isStreaming: true))
        retrievalSummary = nil
        services.setActivity(agent.toolFlags.useVaultRetrieval ? .retrieving : .connecting)

        streamTask = Task {
            do {
                let context = try await services.rag.buildContext(
                    query: query,
                    agent: agent
                )
                await MainActor.run {
                    if assistantIndex < messages.count {
                        messages[assistantIndex].sourceHits = context.hits
                    }
                    retrievalSummary = context.hits.isEmpty
                        ? "No indexed matches · \(agent.name)"
                        : "\(context.hits.count) source\(context.hits.count == 1 ? "" : "s") · \(agent.name)"
                }

                for try await event in services.rag.streamAnswer(context: context, agent: agent) {
                    try Task.checkCancellation()
                    await MainActor.run {
                        guard assistantIndex < messages.count else { return }
                        switch event.kind {
                        case .activity(let state):
                            services.setActivity(state)
                        case .token(let token):
                            if messages[assistantIndex].text.isEmpty {
                                services.setActivity(.streaming)
                            }
                            messages[assistantIndex].text += token
                        case .citations:
                            break
                        case .completed:
                            messages[assistantIndex].isStreaming = false
                            services.setActivity(.idle)
                            streamTask = nil
                        case .error(let message):
                            messages[assistantIndex].text = message
                            messages[assistantIndex].isStreaming = false
                            services.setActivity(.error(message))
                            streamTask = nil
                        }
                    }
                }
            } catch {
                let diagnosed = await services.diagnoseChatFailure(error)
                await MainActor.run {
                    if assistantIndex < messages.count {
                        messages[assistantIndex].text = diagnosed
                        messages[assistantIndex].isStreaming = false
                    }
                    streamTask = nil
                }
            }
        }
    }

    func clear(services: OpenWriteAIServices) {
        streamTask?.cancel()
        streamTask = nil
        messages.removeAll()
        retrievalSummary = nil
        services.setActivity(.idle)
        services.lastChatError = nil
    }
}

// MARK: - Activity indicator

struct AIActivityIndicator: View {
    let state: AIActivityState
    var retrievalSummary: String?

    @State private var pulse = false

    var body: some View {
        if state.isBusy || state.statusMessage != nil {
            HStack(alignment: .top, spacing: 10) {
                if state.isBusy {
                    ProgressView()
                        .controlSize(.small)
                        .scaleEffect(pulse ? 1.05 : 0.95)
                } else if case .error = state {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                }

                VStack(alignment: .leading, spacing: 4) {
                    if let message = state.statusMessage {
                        Text(message)
                            .font(.caption)
                            .foregroundStyle(stateLabelColor)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    if let retrievalSummary, state == .retrieving || state == .streaming {
                        Text(retrievalSummary)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    if state == .streaming {
                        StreamingDots()
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(activityBackground)
            .onAppear {
                withAnimation(.easeInOut(duration: 0.85).repeatForever(autoreverses: true)) {
                    pulse = true
                }
            }
        }
    }

    private var stateLabelColor: Color {
        if case .error = state { return .primary }
        return .secondary
    }

    private var activityBackground: Color {
        if case .error = state { return Color.orange.opacity(0.12) }
        return Color.secondary.opacity(0.08)
    }
}

private struct StreamingDots: View {
    @State private var phase = 0

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0 ..< 3, id: \.self) { index in
                Circle()
                    .fill(Color.accentColor.opacity(index == phase ? 1 : 0.35))
                    .frame(width: 5, height: 5)
            }
            Text("Receiving tokens")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .onAppear { startCycle() }
        .onDisappear { phase = 0 }
    }

    private func startCycle() {
        Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(320))
                phase = (phase + 1) % 3
            }
        }
    }
}

// MARK: - Chat panel

struct ChatPanelView: View {
    @EnvironmentObject private var aiServices: OpenWriteAIServices
    @StateObject private var model = ChatPanelModel()

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            AIActivityIndicator(
                state: aiServices.activityState,
                retrievalSummary: model.retrievalSummary
            )
            if aiServices.activityState.isBusy || aiServices.activityState.statusMessage != nil {
                Divider()
            }
            messageList
            Divider()
            composer
        }
        .frame(minWidth: 280)
    }

    private var header: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Vault chat")
                    .font(.headline)
                HStack(spacing: 8) {
                    AgentPickerView(selectedAgentID: $aiServices.selectedAgentID)
                    Text(aiServices.lmConfig.chatModelDisplay)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            Spacer()
            if aiServices.activityState != .idle {
                Text(aiServices.activityState.shortLabel)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.secondary.opacity(0.12))
                    .clipShape(Capsule())
            }
            Button("Clear") { model.clear(services: aiServices) }
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
                            description: Text("Answers cite indexed note chunks from this Mac. Activity shows when LM Studio is connecting, searching, or streaming.")
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
                scrollToBottom(proxy: proxy)
            }
            .onChange(of: streamingTail) { _, _ in
                scrollToBottom(proxy: proxy)
            }
        }
    }

    private var streamingTail: String {
        model.messages.last(where: { $0.isStreaming })?.text ?? ""
    }

    private func scrollToBottom(proxy: ScrollViewProxy) {
        if let last = model.messages.last {
            withAnimation(.easeOut(duration: 0.2)) {
                proxy.scrollTo(last.id, anchor: .bottom)
            }
        }
    }

    @ViewBuilder
    private func messageBubble(_ message: ChatMessage) -> some View {
        VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 6) {
            Group {
                if message.isStreaming, message.text.isEmpty {
                    HStack(spacing: 6) {
                        ProgressView()
                            .controlSize(.small)
                        Text(aiServices.activityState.statusMessage ?? "Waiting for model…")
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Text(message.text)
                        .textSelection(.enabled)
                }
            }
            .padding(10)
            .background(bubbleColor(for: message.role))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .frame(maxWidth: .infinity, alignment: message.role == .user ? .trailing : .leading)

            if message.isStreaming, !message.text.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: "waveform")
                        .font(.caption2)
                        .symbolEffect(.variableColor.iterative, options: .repeating)
                    Text("Streaming")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }

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
        VStack(alignment: .leading, spacing: 8) {
            if let lastChatError = aiServices.lastChatError, case .error = aiServices.activityState {
                Text(lastChatError)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            HStack(alignment: .bottom, spacing: 8) {
                TextField("Ask about your notes…", text: $model.draft, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(1 ... 4)
                    .onSubmit { model.send(services: aiServices, agent: aiServices.selectedAgent) }

                Button {
                    aiServices.voiceInput.toggleListening(appendTo: &model.draft)
                } label: {
                    Image(systemName: aiServices.voiceInput.isListening ? "mic.fill" : "mic")
                        .font(.title3)
                        .foregroundStyle(aiServices.voiceInput.isListening ? Color.accentColor : .secondary)
                }
                .help(aiServices.voiceInput.statusMessage ?? "Dictate into the message field")

                Button {
                    model.send(services: aiServices, agent: aiServices.selectedAgent)
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.title2)
                }
                .disabled(model.isBusy || AIInput.sanitizeQuery(model.draft) == nil)
                .keyboardShortcut(.return, modifiers: [.command])
            }
        }
        .padding(12)
    }
}
