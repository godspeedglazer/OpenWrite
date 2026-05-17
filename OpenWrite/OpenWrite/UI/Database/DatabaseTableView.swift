import SwiftUI

/// Spreadsheet-style table of entries for the selected database.
struct DatabaseTableView: View {
    @EnvironmentObject private var vaultStore: VaultStore
    let database: OWDatabase

    @State private var selectedEntryID: UUID?
    @State private var editingEntry: OWDatabaseEntry?

    private var entries: [OWDatabaseEntry] {
        vaultStore.entries(for: database.id)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            tableHeader
            Divider()
            if entries.isEmpty {
                emptyState
            } else {
                tableBody
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .sheet(item: $editingEntry) { entry in
            DatabaseEntryEditorSheet(
                database: database,
                entry: entry,
                onSave: { updated in
                    vaultStore.updateDatabaseEntry(updated)
                    editingEntry = nil
                },
                onDelete: {
                    vaultStore.deleteDatabaseEntry(id: entry.id)
                    editingEntry = nil
                },
                onCancel: { editingEntry = nil }
            )
        }
    }

    private var tableHeader: some View {
        HStack(spacing: DesignTokens.Spacing.spacing3) {
            HStack(spacing: DesignTokens.Spacing.spacing2) {
                OWIconView(icon: database.icon, size: 20, color: database.tint.color)
                VStack(alignment: .leading, spacing: 2) {
                    Text(database.name)
                        .font(DesignTokens.Typography.heading3)
                        .foregroundStyle(DesignTokens.Color.textPrimary)
                    Text("\(entries.count) entries · \(database.fields.count) fields")
                        .font(DesignTokens.Typography.caption)
                        .foregroundStyle(DesignTokens.Color.textTertiary)
                }
            }
            Spacer()
            Button {
                if let entry = vaultStore.addDatabaseEntry(to: database.id) {
                    editingEntry = entry
                }
            } label: {
                OWLabel(title: "Add entry", icon: .plus, iconSize: 14)
            }
            .buttonStyle(.borderedProminent)
            .tint(database.tint.color)
        }
        .padding(.horizontal, DesignTokens.Spacing.spacing5)
        .padding(.vertical, DesignTokens.Spacing.spacing2)
        .background(DesignTokens.Color.editorCanvas)
    }

    private var emptyState: some View {
        VStack {
            Spacer()
            Button {
                if let entry = vaultStore.addDatabaseEntry(to: database.id) {
                    editingEntry = entry
                }
            } label: {
                HStack(spacing: DesignTokens.Spacing.spacing2) {
                    OWIconView(icon: .plus, size: 16, color: database.tint.color)
                    Text("+ New row")
                        .font(DesignTokens.Typography.bodyEmphasis)
                        .foregroundStyle(DesignTokens.Color.textPrimary)
                }
                .padding(.horizontal, DesignTokens.Spacing.spacing4)
                .padding(.vertical, DesignTokens.Spacing.spacing2)
                .background(
                    database.tint.color.opacity(0.14),
                    in: RoundedRectangle(cornerRadius: DesignTokens.Radius.medium, style: .continuous)
                )
                .overlay {
                    RoundedRectangle(cornerRadius: DesignTokens.Radius.medium, style: .continuous)
                        .strokeBorder(database.tint.color.opacity(0.35), lineWidth: DesignTokens.Layout.borderWidth)
                }
            }
            .buttonStyle(.plain)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(DesignTokens.Color.editorCanvas)
    }

    private var tableBody: some View {
        ScrollView {
            VStack(spacing: 0) {
                columnHeaderRow
                Divider()
                ForEach(entries) { entry in
                    entryRow(entry)
                    Divider()
                }
            }
        }
        .background(DesignTokens.Color.editorCanvas)
    }

    private var columnHeaderRow: some View {
        HStack(spacing: DesignTokens.Spacing.spacing3) {
            ForEach(database.fields) { field in
                Text(field.label)
                    .font(DesignTokens.Typography.captionEmphasis)
                    .foregroundStyle(DesignTokens.Color.textTertiary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            Color.clear.frame(width: 28)
        }
        .padding(.horizontal, DesignTokens.Spacing.spacing5)
        .padding(.vertical, DesignTokens.Spacing.spacing2)
        .background(DesignTokens.Color.surface.opacity(0.5))
    }

    private func entryRow(_ entry: OWDatabaseEntry) -> some View {
        Button {
            editingEntry = entry
        } label: {
            HStack(spacing: DesignTokens.Spacing.spacing3) {
                ForEach(database.fields) { field in
                    cellText(entry: entry, field: field)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                OWIconView(icon: .chevronRight, size: 12, color: DesignTokens.Color.textTertiary)
                    .frame(width: 28)
            }
            .padding(.horizontal, DesignTokens.Spacing.spacing5)
            .padding(.vertical, DesignTokens.Spacing.spacing3)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(
            selectedEntryID == entry.id
                ? database.tint.color.opacity(0.08)
                : Color.clear
        )
        .onHover { hovering in
            selectedEntryID = hovering ? entry.id : nil
        }
    }

    @ViewBuilder
    private func cellText(entry: OWDatabaseEntry, field: OWDatabaseField) -> some View {
        let text = entry.value(for: field)?.displayString ?? "—"
        if field.kind == .code {
            Text(text)
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(DesignTokens.Color.textPrimary)
                .lineLimit(2)
        } else if field.kind == .url, let url = URL(string: text), !text.isEmpty {
            Link(text, destination: url)
                .font(DesignTokens.Typography.sidebarItem)
                .lineLimit(1)
        } else {
            Text(text.isEmpty ? "—" : text)
                .font(DesignTokens.Typography.sidebarItem)
                .foregroundStyle(
                    text.isEmpty ? DesignTokens.Color.textTertiary : DesignTokens.Color.textPrimary
                )
                .lineLimit(field.isPrimary ? 2 : 1)
        }
    }
}

// MARK: - Entry editor sheet

private struct DatabaseEntryEditorSheet: View {
    let database: OWDatabase
    @State var entry: OWDatabaseEntry
    let onSave: (OWDatabaseEntry) -> Void
    let onDelete: () -> Void
    let onCancel: () -> Void

    var body: some View {
        NavigationStack {
            Form {
                ForEach(database.fields) { field in
                    fieldEditor(field)
                }
            }
            .formStyle(.grouped)
            .navigationTitle(entry.displayTitle(in: database))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                }
                ToolbarItem(placement: .destructiveAction) {
                    Button("Delete", role: .destructive, action: onDelete)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { onSave(entry) }
                }
            }
        }
        .frame(minWidth: 480, minHeight: 420)
    }

    @ViewBuilder
    private func fieldEditor(_ field: OWDatabaseField) -> some View {
        let binding = Binding<OWDatabaseValue>(
            get: { entry.value(for: field) ?? .empty(for: field.kind) },
            set: { entry.setValue($0, for: field) }
        )

        switch field.kind {
        case .text:
            Section(field.label) {
                TextField(field.label, text: textBinding(binding))
            }
        case .code:
            Section(field.label) {
                TextEditor(text: textBinding(binding))
                    .font(.system(.body, design: .monospaced))
                    .frame(minHeight: 120)
            }
        case .tags:
            Section(field.label) {
                TextField("Comma-separated", text: tagsBinding(binding))
            }
        case .url:
            Section(field.label) {
                TextField("https://", text: textBinding(binding))
            }
        case .number:
            Section(field.label) {
                TextField(field.label, value: numberBinding(binding), format: .number)
            }
        case .date:
            Section(field.label) {
                DatePicker(
                    field.label,
                    selection: dateBinding(binding),
                    displayedComponents: [.date]
                )
            }
        }
    }

    private func textBinding(_ value: Binding<OWDatabaseValue>) -> Binding<String> {
        Binding(
            get: {
                if case .text(let s) = value.wrappedValue { return s }
                if case .code(let s) = value.wrappedValue { return s }
                if case .url(let s) = value.wrappedValue { return s }
                return ""
            },
            set: { newValue in
                switch value.wrappedValue {
                case .code: value.wrappedValue = .code(newValue)
                case .url: value.wrappedValue = .url(newValue)
                default: value.wrappedValue = .text(newValue)
                }
            }
        )
    }

    private func tagsBinding(_ value: Binding<OWDatabaseValue>) -> Binding<String> {
        Binding(
            get: {
                if case .tags(let tags) = value.wrappedValue {
                    return tags.joined(separator: ", ")
                }
                return ""
            },
            set: { newValue in
                let parts = newValue
                    .split(separator: ",")
                    .map { $0.trimmingCharacters(in: .whitespaces) }
                    .filter { !$0.isEmpty }
                value.wrappedValue = .tags(parts)
            }
        )
    }

    private func numberBinding(_ value: Binding<OWDatabaseValue>) -> Binding<Double> {
        Binding(
            get: {
                if case .number(let n) = value.wrappedValue { return n }
                return 0
            },
            set: { value.wrappedValue = .number($0) }
        )
    }

    private func dateBinding(_ value: Binding<OWDatabaseValue>) -> Binding<Date> {
        Binding(
            get: {
                if case .date(let d) = value.wrappedValue { return d }
                return .now
            },
            set: { value.wrappedValue = .date($0) }
        )
    }
}

#Preview {
    let store = VaultStore.preview
    return DatabaseTableView(database: store.databases[0])
        .environmentObject(store)
        .frame(width: 720, height: 480)
}
