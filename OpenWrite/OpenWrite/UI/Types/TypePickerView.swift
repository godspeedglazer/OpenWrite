import SwiftUI

/// Create a new typed page or switch the current document's type.
struct TypePickerView: View {
    @EnvironmentObject private var vaultStore: VaultStore
    let documentID: UUID?
    var mode: Mode = .switchType
    var layout: Layout = .standard
    var onCreated: ((UUID) -> Void)?

    enum Mode {
        case create
        case switchType
    }

    enum Layout {
        case standard
        case compact
    }

    @State private var newTitle: String = ""
    @State private var applyTemplateOnSwitch = false

    var body: some View {
        VStack(alignment: .leading, spacing: layout == .compact ? DesignTokens.Spacing.spacing1 : DesignTokens.Spacing.spacing2) {
            if layout == .standard {
                Text(mode == .create ? "Quick page type" : "Page type")
                    .font(.headline)
            }

            if mode == .create {
                TextField("Title", text: $newTitle)
                    .textFieldStyle(.roundedBorder)
            }

            typePickerRow

            if mode == .switchType, documentID != nil, layout == .standard {
                Toggle("Apply default layout", isOn: $applyTemplateOnSwitch)
                    .font(.caption)
                    .toggleStyle(.checkbox)
            }
        }
        .padding(.vertical, layout == .compact ? 0 : 4)
    }

    @ViewBuilder
    private var typePickerRow: some View {
        let types = vaultStore.typeRegistry.quickPickSelectable
        if layout == .compact {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: DesignTokens.Spacing.spacing1) {
                    ForEach(types) { pageType in
                        typeButton(pageType)
                    }
                }
            }
        } else {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: DesignTokens.Spacing.spacing2) {
                    ForEach(types) { pageType in
                        typeButton(pageType)
                    }
                }
            }
        }
    }

    private func typeButton(_ pageType: PageType) -> some View {
        let currentDoc = documentID.flatMap { id in vaultStore.documents.first { $0.id == id } }
        let isSelected = currentDoc?.pageType == pageType && mode == .switchType
        let compact = layout == .compact
        let iconSize: CGFloat = compact ? 16 : 20
        let verticalPad: CGFloat = compact ? 4 : 8
        let minWidth: CGFloat = compact ? 56 : 72

        return Button {
            switch mode {
            case .create:
                let title = newTitle.isEmpty ? nil : newTitle
                let doc = vaultStore.createDocument(pageType: pageType, title: title)
                onCreated?(doc.id)
                newTitle = ""
            case .switchType:
                guard let documentID else { return }
                vaultStore.setPageType(
                    pageType,
                    for: documentID,
                    applyTemplate: applyTemplateOnSwitch
                )
                vaultStore.syncPropertiesToNDL(for: documentID)
            }
        } label: {
            VStack(spacing: compact ? 2 : 4) {
                OWIconView(icon: pageType.owIcon, size: iconSize, color: DesignTokens.ObjectType.accent(for: pageType))
                Text(pageType.displayName)
                    .font(compact ? DesignTokens.Typography.caption : .caption)
                    .lineLimit(1)
            }
            .frame(minWidth: minWidth)
            .padding(.horizontal, compact ? 6 : 8)
            .padding(.vertical, verticalPad)
            .background(isSelected ? Color.accentColor.opacity(0.15) : Color.secondary.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.small, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: DesignTokens.Radius.small, style: .continuous)
                    .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(pageType.displayName)
    }
}

#Preview("Create") {
  TypePickerView(documentID: nil, mode: .create)
    .environmentObject(VaultStore.preview)
    .padding()
    .frame(width: 320)
}

#Preview("Switch") {
  TypePickerView(documentID: VaultStore.preview.documents.first?.id, mode: .switchType)
    .environmentObject(VaultStore.preview)
    .padding()
    .frame(width: 320)
}
