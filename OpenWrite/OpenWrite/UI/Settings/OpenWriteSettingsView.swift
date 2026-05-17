import SwiftUI

/// Combined settings sheet: appearance themes and AI / LM Studio.
struct OpenWriteSettingsView: View {
    @EnvironmentObject private var vaultStore: VaultStore
    @State private var demoInstallMessage: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.spacing6) {
                vaultSection

                Divider()

                VStack(alignment: .leading, spacing: DesignTokens.Spacing.spacing3) {
                    Text("Appearance")
                        .font(DesignTokens.Typography.heading3)
                        .foregroundStyle(DesignTokens.Color.textPrimary)
                    Text("Sidebar, canvas, accents, and borders update instantly.")
                        .font(DesignTokens.Typography.caption)
                        .foregroundStyle(DesignTokens.Color.textSecondary)
                    ThemeQuickToggle()
                    ThemePickerView()
                }

                Rectangle()
                    .fill(DesignTokens.Color.separator)
                    .frame(height: DesignTokens.Layout.borderWidth)

                VStack(alignment: .leading, spacing: DesignTokens.Spacing.spacing2) {
                    Text("AI & LM Studio")
                        .font(DesignTokens.Typography.heading3)
                        .foregroundStyle(DesignTokens.Color.textPrimary)
                    AISettingsView()
                }
            }
            .padding(DesignTokens.Spacing.spacing4)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(DesignTokens.Color.background)
    }

    private var vaultSection: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.spacing3) {
            Text("Vault")
                .font(DesignTokens.Typography.heading3)
                .foregroundStyle(DesignTokens.Color.textPrimary)

            Text("Install the Links Demo vault for a pre-wired graph of sample pages. Your primary vault (including Welcome) is never modified.")
                .font(DesignTokens.Typography.caption)
                .foregroundStyle(DesignTokens.Color.textSecondary)

            HStack(spacing: DesignTokens.Spacing.spacing3) {
                Button("Install demo vault") {
                    let installed = vaultStore.installDemoVault(selectHub: true)
                    demoInstallMessage = installed
                        ? "Added \(DemoVaultSeeder.seededDocumentIDs.count) demo pages. Switched to Links Demo."
                        : "Demo vault is already installed."
                }
                .disabled(vaultStore.isDemoVaultInstalled)

                if vaultStore.isDemoVaultInstalled {
                    Text("Installed")
                        .font(DesignTokens.Typography.caption)
                        .foregroundStyle(DesignTokens.Color.success)
                }
            }

            if let demoInstallMessage {
                Text(demoInstallMessage)
                    .font(DesignTokens.Typography.caption)
                    .foregroundStyle(DesignTokens.Color.textSecondary)
            }
        }
    }
}

#Preview {
    OpenWriteSettingsView()
        .environment(ThemeManager.shared)
        .environmentObject(OpenWriteAIServices())
        .environmentObject(VaultStore.preview)
        .frame(width: 520, height: 640)
}
