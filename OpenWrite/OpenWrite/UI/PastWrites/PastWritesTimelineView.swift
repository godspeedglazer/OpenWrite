import SwiftUI

private enum PastTimelineMode: String, CaseIterable, Hashable {
    case edits = "Edits"
    case chats = "Chats"
}

/// Archived vault chat threads (saved when the user taps Clear).
struct PastChatSessionsView: View {
    @ObservedObject var workbench: WorkbenchState
    @State private var threads: [SavedChatThread] = []

    var body: some View {
        Group {
            if threads.isEmpty {
                OWEmptyState(
                    title: "No past chats yet",
                    icon: .chat,
                    description: Text("Tap Clear in Chat to archive a conversation here.")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: DesignTokens.Spacing.spacing2) {
                        ForEach(threads) { thread in
                            chatRow(thread)
                        }
                    }
                    .padding(.top, DesignTokens.Spacing.spacing1)
                }
            }
        }
        .onAppear { reload() }
    }

    private func reload() {
        threads = ChatSessionStore.loadRecent(limit: 40)
    }

    private func chatRow(_ thread: SavedChatThread) -> some View {
        Button {
            workbench.archivedChatThreadIDToOpen = thread.id
            workbench.aiAssistExpanded = true
            workbench.persistChromePreferences()
        } label: {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.spacing1) {
                HStack(alignment: .firstTextBaseline) {
                    Text(thread.contextSummary.map { String($0.prefix(72)) } ?? "Chat")
                        .font(OWTypography.subheadlineEmphasis)
                        .foregroundStyle(DesignTokens.Color.textPrimary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    Spacer(minLength: DesignTokens.Spacing.spacing2)
                    Text("\(thread.turns.count)")
                        .font(OWTypography.caption2.monospacedDigit())
                        .foregroundStyle(DesignTokens.Color.textTertiary)
                }
                Text(thread.savedAt, style: .relative)
                    .font(OWTypography.caption2)
                    .foregroundStyle(DesignTokens.Color.textTertiary)
                if let preview = thread.turns.last(where: { $0.role == "assistant" })?.text {
                    Text(preview)
                        .font(OWTypography.caption)
                        .foregroundStyle(DesignTokens.Color.textSecondary)
                        .lineLimit(2)
                }
            }
            .padding(.horizontal, DesignTokens.Spacing.spacing2)
            .padding(.vertical, DesignTokens.Spacing.spacing3)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                DesignTokens.Color.surfaceElevated,
                in: RoundedRectangle(cornerRadius: DesignTokens.Radius.medium, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: DesignTokens.Radius.medium, style: .continuous)
                    .strokeBorder(DesignTokens.Color.borderSubtle.opacity(0.65), lineWidth: DesignTokens.Layout.borderWidth)
            }
        }
        .buttonStyle(.plain)
    }
}

private enum PastWritesWindow: Double, CaseIterable, Hashable {
    case sixHours = 6
    case twentyFourHours = 24
    case sevenDays = 168

    var label: String {
        switch self {
        case .sixHours: return "6 h"
        case .twentyFourHours: return "24 h"
        case .sevenDays: return "7 d"
        }
    }
}

/// Minimal Past Writes timeline for the workbench inspector (vault edit sessions + future REM rows).
struct PastWritesTimelineView: View {
    @ObservedObject var workbench: WorkbenchState
    @ObservedObject var pastWrites: InMemoryPastWritesService
    var filterNoteID: UUID?
    @State private var mode: PastTimelineMode = .chats
    @State private var window: PastWritesWindow = .twentyFourHours
    @State private var chatsRefreshToken = 0

    private var entries: [WritingContextEntry] {
        let since = Date().addingTimeInterval(-window.rawValue * 3600)
        var list = pastWrites.recentContexts(since: since)
        if let filterNoteID {
            list = list.filter { $0.noteID == filterNoteID }
        }
        return list
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.spacing3) {
            header
            if mode == .chats {
                PastChatSessionsView(workbench: workbench)
                    .id(chatsRefreshToken)
            } else if entries.isEmpty {
                OWEmptyState(
                    title: "No past writes yet",
                    icon: .pastWrites,
                    description: Text("Edits in the vault are grouped into sessions here. Optional rem+ import is enabled when `db.sqlite3` is found.")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: DesignTokens.Spacing.spacing2) {
                        ForEach(entries) { entry in
                            timelineRow(entry)
                        }
                    }
                    .padding(.top, DesignTokens.Spacing.spacing1)
                }
            }
        }
        .padding(DesignTokens.Spacing.assistStripContentPadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(DesignTokens.Color.background)
        .onAppear {
            if mode == .chats { chatsRefreshToken += 1 }
        }
        .onChange(of: mode) { _, newMode in
            if newMode == .chats { chatsRefreshToken += 1 }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.spacing2) {
            Text("Past")
                .font(OWTypography.panelTitle)
                .foregroundStyle(DesignTokens.Color.textPrimary)
            Text(mode == .chats
                ? "Archived chat threads from Clear."
                : "Writing sessions from vault edits (optional rem+ import).")
                .font(OWTypography.caption)
                .foregroundStyle(DesignTokens.Color.textSecondary)
            OWThemedSegmentedControl(
                selection: $mode,
                options: Array(PastTimelineMode.allCases),
                title: \.rawValue
            )
            if mode == .edits {
                OWThemedSegmentedControl(
                    selection: $window,
                    options: Array(PastWritesWindow.allCases),
                    title: \.label
                )
            }
        }
    }

    private func timelineRow(_ entry: WritingContextEntry) -> some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.spacing1) {
            HStack(alignment: .firstTextBaseline) {
                Text(entry.noteTitle)
                    .font(OWTypography.subheadlineEmphasis)
                    .foregroundStyle(DesignTokens.Color.textPrimary)
                    .lineLimit(1)
                Spacer(minLength: DesignTokens.Spacing.spacing2)
                sourceBadge(entry.source)
            }
            Text(entry.intervalStart, style: .time)
                .font(OWTypography.caption2)
                .foregroundStyle(DesignTokens.Color.textTertiary)
            if !entry.summary.isEmpty {
                Text(entry.summary)
                    .font(OWTypography.caption)
                    .lineLimit(3)
                    .foregroundStyle(DesignTokens.Color.textSecondary)
            }
        }
        .padding(.horizontal, DesignTokens.Spacing.spacing2)
        .padding(.vertical, DesignTokens.Spacing.spacing3)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            DesignTokens.Color.surfaceElevated,
            in: RoundedRectangle(cornerRadius: DesignTokens.Radius.medium, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: DesignTokens.Radius.medium, style: .continuous)
                .strokeBorder(DesignTokens.Color.borderSubtle.opacity(0.65), lineWidth: DesignTokens.Layout.borderWidth)
        }
    }

    @ViewBuilder
    private func sourceBadge(_ source: WritingContextSource) -> some View {
        switch source {
        case .vaultEdits:
            Text("Vault")
                .font(OWTypography.caption2)
                .foregroundStyle(DesignTokens.Color.textSecondary)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(DesignTokens.Color.surfaceElevated, in: Capsule())
        case .remImport:
            Text("rem+")
                .font(OWTypography.caption2)
                .foregroundStyle(DesignTokens.Color.accent)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(DesignTokens.Color.accentMuted, in: Capsule())
        }
    }
}

#Preview {
    PastWritesTimelineView(workbench: WorkbenchState(), pastWrites: .preview)
        .frame(width: 280, height: 400)
}
