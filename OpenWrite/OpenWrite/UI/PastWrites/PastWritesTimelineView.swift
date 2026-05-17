import SwiftUI

/// Minimal Past Writes timeline for the workbench inspector (vault edit sessions + future REM rows).
struct PastWritesTimelineView: View {
    @ObservedObject var pastWrites: InMemoryPastWritesService
    var filterNoteID: UUID?
    @State private var sinceHours: Double = 24

    private var entries: [WritingContextEntry] {
        let since = Date().addingTimeInterval(-sinceHours * 3600)
        var list = pastWrites.recentContexts(since: since)
        if let filterNoteID {
            list = list.filter { $0.noteID == filterNoteID }
        }
        return list
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            if entries.isEmpty {
                ContentUnavailableView(
                    "No past writes yet",
                    systemImage: "clock.arrow.circlepath",
                    description: Text("Edits in the vault are grouped into sessions here. Optional rem+ import is enabled when `db.sqlite3` is found.")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(entries) { entry in
                    timelineRow(entry)
                }
                .listStyle(.plain)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Past Writes")
                .font(.headline)
            Text("Writing sessions from vault edits (optional rem+ import).")
                .font(.caption)
                .foregroundStyle(.secondary)
            Picker("Window", selection: $sinceHours) {
                Text("6 h").tag(6.0)
                Text("24 h").tag(24.0)
                Text("7 d").tag(168.0)
            }
            .pickerStyle(.segmented)
        }
    }

    private func timelineRow(_ entry: WritingContextEntry) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(entry.noteTitle)
                    .font(.subheadline.weight(.semibold))
                Spacer()
                sourceBadge(entry.source)
            }
            Text(entry.intervalStart, style: .time)
                .font(.caption2)
                .foregroundStyle(.secondary)
            if !entry.summary.isEmpty {
                Text(entry.summary)
                    .font(.caption)
                    .lineLimit(3)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private func sourceBadge(_ source: WritingContextSource) -> some View {
        switch source {
        case .vaultEdits:
            Text("Vault")
                .font(.caption2)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.secondary.opacity(0.15))
                .clipShape(Capsule())
        case .remImport:
            Text("rem+")
                .font(.caption2)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.accentColor.opacity(0.15))
                .clipShape(Capsule())
        }
    }
}

#Preview {
    PastWritesTimelineView(pastWrites: .preview)
        .frame(width: 280, height: 400)
}
