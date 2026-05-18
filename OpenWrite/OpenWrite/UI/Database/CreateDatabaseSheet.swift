import SwiftUI

/// Pick a database preset or start from a blank schema.
struct CreateDatabaseSheet: View {
    @EnvironmentObject private var vaultStore: VaultStore
    @ObservedObject var workbench: WorkbenchState
    @Binding var isPresented: Bool

    @State private var name: String = ""
    @State private var selectedPreset: DatabasePreset = .codeSnippets

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.spacing5) {
                    Text("Create a database for any structured collection — not just code.")
                        .font(DesignTokens.Typography.body)
                        .foregroundStyle(DesignTokens.Color.textSecondary)

                    TextField("Name (optional)", text: $name)
                        .textFieldStyle(.roundedBorder)

                    Text("Preset")
                        .font(DesignTokens.Typography.captionEmphasis)
                        .foregroundStyle(DesignTokens.Color.textTertiary)

                    LazyVGrid(
                        columns: [GridItem(.adaptive(minimum: 160), spacing: DesignTokens.Spacing.spacing3)],
                        spacing: DesignTokens.Spacing.spacing3
                    ) {
                        ForEach(DatabasePreset.allCases) { preset in
                            presetCard(preset)
                        }
                    }

                    schemaPreview
                }
                .padding(DesignTokens.Spacing.spacing6)
            }
            .navigationTitle("New database")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { isPresented = false }
                        .openWriteFocusChrome(.themedKeyboard)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") { createDatabase() }
                        .keyboardShortcut(.defaultAction)
                        .openWriteFocusChrome(.themedKeyboard)
                }
            }
        }
        .frame(minWidth: 520, minHeight: 480)
    }

    private func presetCard(_ preset: DatabasePreset) -> some View {
        let isSelected = selectedPreset == preset
        return Button {
            selectedPreset = preset
        } label: {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.spacing2) {
                HStack(spacing: DesignTokens.Spacing.spacing2) {
                    OWUnicodeIconView(icon: preset.icon, size: 22, color: preset.themeTint.color)
                    Text(preset.displayName)
                        .font(DesignTokens.Typography.bodyEmphasis)
                        .foregroundStyle(DesignTokens.Color.textPrimary)
                }
                Text(preset.summary)
                    .font(DesignTokens.Typography.caption)
                    .foregroundStyle(DesignTokens.Color.textSecondary)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(DesignTokens.Spacing.spacing3)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                isSelected
                    ? preset.themeTint.color.opacity(0.12)
                    : DesignTokens.Color.surface.opacity(0.6),
                in: RoundedRectangle(cornerRadius: DesignTokens.Radius.medium, style: .continuous)
            )
            .overlay {
                if isSelected {
                    RoundedRectangle(cornerRadius: DesignTokens.Radius.medium, style: .continuous)
                        .strokeBorder(preset.themeTint.color.opacity(0.5), lineWidth: 1)
                }
            }
        }
        .buttonStyle(.plain)
        .openWriteFocusChrome()
        .accessibilityLabel(preset.displayName)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var schemaPreview: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.spacing2) {
            Text("Schema preview")
                .font(DesignTokens.Typography.captionEmphasis)
                .foregroundStyle(DesignTokens.Color.textTertiary)

            OWRoundedRect(style: .sidebarCard, padding: DesignTokens.Spacing.spacing3) {
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.spacing1) {
                    ForEach(selectedPreset.schemaFields()) { field in
                        HStack {
                            Text(field.label)
                                .font(DesignTokens.Typography.sidebarItem)
                            Spacer()
                            Text(field.kind.displayName)
                                .font(DesignTokens.Typography.caption)
                                .foregroundStyle(DesignTokens.Color.textTertiary)
                            if field.isPrimary {
                                Text("primary")
                                    .font(DesignTokens.Typography.caption)
                                    .foregroundStyle(selectedPreset.themeTint.color)
                            }
                        }
                    }
                }
            }
        }
    }

    private func createDatabase() {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedName = trimmed.isEmpty ? nil : trimmed
        let database = vaultStore.createDatabase(preset: selectedPreset, name: resolvedName)
        withAnimation(DesignTokens.Motion.animationStandard) {
            workbench.showDatabase(database)
        }
        isPresented = false
        name = ""
    }
}

#Preview {
    CreateDatabaseSheet(
        workbench: WorkbenchState(),
        isPresented: .constant(true)
    )
    .environmentObject(VaultStore.preview)
}
