import SwiftUI

/// Combined settings sheet: appearance themes and AI / LM Studio.
struct OpenWriteSettingsView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.spacing6) {
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

                Divider()

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
    }
}

#Preview {
    OpenWriteSettingsView()
        .environment(ThemeManager.shared)
        .environmentObject(OpenWriteAIServices())
        .environmentObject(VaultStore.preview)
        .frame(width: 520, height: 640)
}
