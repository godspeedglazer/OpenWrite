import SwiftUI

/// Create a new typed page or switch the current document's type.
struct TypePickerView: View {
    @EnvironmentObject private var vaultStore: VaultStore
    let documentID: UUID?
    var mode: Mode = .switchType
    var onCreated: ((UUID) -> Void)?

    enum Mode {
        case create
        case switchType
    }

    @State private var newTitle: String = ""
    @State private var applyTemplateOnSwitch = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(mode == .create ? "New page" : "Page type")
                .font(.headline)

            if mode == .create {
                TextField("Title", text: $newTitle)
                    .textFieldStyle(.roundedBorder)
            }

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 88), spacing: 10)], spacing: 10) {
                ForEach(vaultStore.typeRegistry.allSelectable) { pageType in
                    typeButton(pageType)
                }
            }

            if mode == .switchType, documentID != nil {
                Toggle("Apply default layout", isOn: $applyTemplateOnSwitch)
                    .font(.caption)
                    .toggleStyle(.checkbox)
            }
        }
        .padding(.vertical, 4)
    }

    private func typeButton(_ pageType: PageType) -> some View {
        let currentDoc = documentID.flatMap { id in vaultStore.documents.first { $0.id == id } }
        let isSelected = currentDoc?.pageType == pageType && mode == .switchType

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
            VStack(spacing: 6) {
                Image(systemName: pageType.systemImage)
                    .font(.title2)
                Text(pageType.displayName)
                    .font(.caption)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(isSelected ? Color.accentColor.opacity(0.15) : Color.secondary.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
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
