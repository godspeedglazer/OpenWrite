import SwiftUI

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
    @ObservedObject var pastWrites: InMemoryPastWritesService
    var filterNoteID: UUID?
    @State private var window: PastWritesWindow = .twentyFourHours

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
            if entries.isEmpty {
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
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.spacing2) {
            Text("Past Writes")
                .font(OWTypography.panelTitle)
                .foregroundStyle(DesignTokens.Color.textPrimary)
            Text("Writing sessions from vault edits (optional rem+ import).")
                .font(OWTypography.caption)
                .foregroundStyle(DesignTokens.Color.textSecondary)
            OWThemedSegmentedControl(
                selection: $window,
                options: Array(PastWritesWindow.allCases),
                title: \.label
            )
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
    PastWritesTimelineView(pastWrites: .preview)
        .frame(width: 280, height: 400)
}
