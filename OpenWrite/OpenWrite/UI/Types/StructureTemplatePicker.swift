import SwiftUI

/// Pick a structure preset when creating a new page (book, document, wiki site, collection).
struct StructureTemplatePicker: View {
    @EnvironmentObject private var vaultStore: VaultStore
    var onCreated: ((UUID) -> Void)?

    @State private var newTitle: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.spacing3) {
            Text("Structure template")
                .font(OWTypography.panelTitle)
                .foregroundStyle(DesignTokens.Color.textPrimary)

            OWThemedTextField(placeholder: "Title", text: $newTitle)

            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 148, maximum: 220), spacing: DesignTokens.Spacing.spacing2)],
                alignment: .leading,
                spacing: DesignTokens.Spacing.spacing2
            ) {
                ForEach(StructureTemplate.allCases) { structure in
                    structureButton(structure)
                }
            }
        }
    }

    private func structureButton(_ structure: StructureTemplate) -> some View {
        Button {
            let title = newTitle.isEmpty ? nil : newTitle
            let doc = vaultStore.createFromStructure(structure, title: title)
            onCreated?(doc.id)
            newTitle = ""
        } label: {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.spacing2) {
                HStack(spacing: DesignTokens.Spacing.spacing2) {
                    OWUnicodeIconView(
                        pageType: structure.pageType,
                        size: 24,
                        color: DesignTokens.ObjectType.accent(for: structure.pageType)
                    )
                    Text(structure.displayName)
                        .font(OWTypography.bodyEmphasis)
                        .foregroundStyle(DesignTokens.Color.textPrimary)
                }
                Text(structure.summary)
                    .font(OWTypography.caption)
                    .foregroundStyle(DesignTokens.Color.textSecondary)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(DesignTokens.Spacing.spacing3)
            .background(
                DesignTokens.Color.surface,
                in: RoundedRectangle(cornerRadius: DesignTokens.Radius.medium, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: DesignTokens.Radius.medium, style: .continuous)
                    .strokeBorder(DesignTokens.Color.borderSubtle, lineWidth: DesignTokens.Layout.borderWidth)
            }
        }
        .buttonStyle(.plain)
        .openWriteFocusChrome()
        .accessibilityLabel(structure.displayName)
        .accessibilityHint(structure.summary)
    }
}

#Preview {
    StructureTemplatePicker()
        .environmentObject(VaultStore.preview)
        .padding()
        .frame(width: 400)
}
