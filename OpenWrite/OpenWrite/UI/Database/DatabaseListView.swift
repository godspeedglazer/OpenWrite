import SwiftUI

/// Sidebar section listing universal databases with create affordance.
struct DatabaseListView: View {
    @EnvironmentObject private var vaultStore: VaultStore
    @ObservedObject var workbench: WorkbenchState
    @Binding var showCreateDatabaseSheet: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.spacing2) {
            HStack {
                OWNavigationRailSectionLabel(title: "Databases")
                Spacer()
                Button {
                    showCreateDatabaseSheet = true
                } label: {
                    OWUnicodeIconView(icon: .plus, size: 14, color: DesignTokens.Color.accent)
                }
                .buttonStyle(.plain)
                .help("New database")
            }

            if vaultStore.databases.isEmpty {
                OWRoundedRect(style: .sidebarCard, padding: DesignTokens.Spacing.spacing2) {
                    VStack(alignment: .leading, spacing: DesignTokens.Spacing.spacing2) {
                        Text("Create a structured collection — snippets, bookmarks, reading lists, or your own schema.")
                            .font(DesignTokens.Typography.caption)
                            .foregroundStyle(DesignTokens.Color.textTertiary)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        Button {
                            showCreateDatabaseSheet = true
                        } label: {
                            HStack(spacing: DesignTokens.Spacing.spacing2) {
                                OWUnicodeIconView(icon: .plus, size: 14, color: DesignTokens.Color.accent)
                                Text("New database")
                                    .font(DesignTokens.Typography.sidebarItem.weight(.medium))
                                    .foregroundStyle(DesignTokens.Color.accent)
                            }
                            .padding(.horizontal, DesignTokens.Spacing.spacing2)
                            .padding(.vertical, DesignTokens.Spacing.spacing1)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(
                                DesignTokens.Color.selectionPill.opacity(0.75),
                                in: RoundedRectangle(cornerRadius: DesignTokens.Radius.owRect, style: .continuous)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            } else {
                OWRoundedRect(style: .sidebarCard, padding: DesignTokens.Spacing.spacing2) {
                    VStack(spacing: DesignTokens.Spacing.spacing1) {
                        ForEach(vaultStore.databases) { database in
                            databaseRow(database)
                        }
                    }
                }
            }
        }
    }

    private func databaseRow(_ database: OWDatabase) -> some View {
        let entryCount = vaultStore.entries(for: database.id).count
        return OWSidebarRow(
            title: database.name,
            subtitle: entryCount == 1 ? "1 entry" : "\(entryCount) entries",
            customIcon: database.icon,
            iconTint: database.tint.color,
            isSelected: vaultStore.selectedDatabaseID == database.id
                && workbench.centerTab.databaseID == database.id
        ) {
            vaultStore.selectedDatabaseID = database.id
            vaultStore.selectedDocumentID = nil
            withAnimation(DesignTokens.Motion.animationStandard) {
                workbench.showDatabase(database)
            }
        }
    }

}

#Preview {
    DatabaseListView(
        workbench: WorkbenchState(),
        showCreateDatabaseSheet: .constant(false)
    )
    .environmentObject(VaultStore.preview)
    .padding()
    .frame(width: 260)
    .background(DesignTokens.Color.sidebarBackground)
}
