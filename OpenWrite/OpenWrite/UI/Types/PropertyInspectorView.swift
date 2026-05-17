import SwiftUI

/// Edits typed properties for the current page type.
struct PropertyInspectorView: View {
    @EnvironmentObject private var vaultStore: VaultStore
    let documentID: UUID

    private var document: VaultDocument? {
        vaultStore.documents.first { $0.id == documentID }
    }

    var body: some View {
        Group {
            if let document {
                inspectorContent(document)
            } else {
                Text("Document not found")
                    .font(OWTypography.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private func inspectorContent(_ document: VaultDocument) -> some View {
        let schema = PageProperties.schema(for: document.pageType)

        VStack(alignment: .leading, spacing: DesignTokens.Spacing.spacing2) {
            Text("Properties")
                .font(OWTypography.captionEmphasis)

            ForEach(schema) { key in
                fieldRow(key: key, document: document)
            }

            if schema.isEmpty {
                Text("No properties for this type.")
                    .font(OWTypography.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private func fieldRow(key: PagePropertyKey, document: VaultDocument) -> some View {
        switch key {
        case .status where document.pageType == .task:
            pickerRow(
                key: key,
                options: TaskStatus.allCases.map(\.rawValue),
                labels: TaskStatus.allCases.map(\.displayName)
            )
        case .status where document.pageType == .project:
            pickerRow(
                key: key,
                options: ProjectStatus.allCases.map(\.rawValue),
                labels: ProjectStatus.allCases.map(\.displayName)
            )
        case .priority:
            pickerRow(
                key: key,
                options: Priority.allCases.map(\.rawValue),
                labels: Priority.allCases.map(\.displayName)
            )
        case .rating:
            ratingRow(key: key)
        case .dueDate, .startedAt, .completedAt, .publishedAt:
            dateRow(key: key)
        case .tags:
            tagsRow(key: key)
        case .url:
            urlRow(key: key)
        default:
            textRow(key: key)
        }
    }

    private func textRow(key: PagePropertyKey) -> some View {
        LabeledContent(key.displayName) {
            TextField(key.displayName, text: bindingText(key: key))
                .textFieldStyle(.roundedBorder)
        }
    }

    private func urlRow(key: PagePropertyKey) -> some View {
        LabeledContent(key.displayName) {
            TextField("https://…", text: bindingText(key: key))
                .textFieldStyle(.roundedBorder)
        }
    }

    private func tagsRow(key: PagePropertyKey) -> some View {
        LabeledContent(key.displayName) {
            TextField("comma, separated", text: bindingText(key: key))
                .textFieldStyle(.roundedBorder)
        }
    }

    private func dateRow(key: PagePropertyKey) -> some View {
        LabeledContent(key.displayName) {
            TextField("yyyy-MM-dd", text: bindingText(key: key))
                .textFieldStyle(.roundedBorder)
                .font(OWTypography.code)
        }
    }

    private func pickerRow(key: PagePropertyKey, options: [String], labels: [String]) -> some View {
        LabeledContent(key.displayName) {
            Picker(key.displayName, selection: bindingText(key: key)) {
                ForEach(Array(zip(options, labels)), id: \.0) { option, label in
                    Text(label).tag(option)
                }
            }
            .labelsHidden()
            .frame(maxWidth: 180)
        }
    }

    private func ratingRow(key: PagePropertyKey) -> some View {
        let ratingBinding = Binding(
            get: {
                guard let doc = document else { return 3 }
                if case .rating(let n) = doc.properties[key] { return n }
                return 3
            },
            set: { newValue in
                var props = document?.properties ?? PageProperties()
                props[key] = .rating(newValue)
                vaultStore.setProperties(props, for: documentID)
                vaultStore.syncPropertiesToNDL(for: documentID)
            }
        )

        return LabeledContent(key.displayName) {
            Stepper(value: ratingBinding, in: 1 ... 5) {
                HStack(spacing: 2) {
                    ForEach(1 ... 5, id: \.self) { star in
                        OWIconView(
                            icon: star <= ratingBinding.wrappedValue ? .starFilled : .star,
                            size: 12,
                            color: star <= ratingBinding.wrappedValue ? .yellow : .secondary
                        )
                    }
                }
            }
        }
    }

    private func bindingText(key: PagePropertyKey) -> Binding<String> {
        Binding(
            get: {
                document?.properties.string(for: key) ?? ""
            },
            set: { newValue in
                guard var doc = document else { return }
                var props = doc.properties
                props.setText(newValue, for: key)
                vaultStore.setProperties(props, for: documentID)
                vaultStore.syncPropertiesToNDL(for: documentID)
            }
        )
    }
}

#Preview {
    let store = VaultStore.preview
    let documentID = store.documents.first?.id ?? VaultDocument.welcomeSample.id
    PropertyInspectorView(documentID: documentID)
        .environmentObject(store)
        .padding()
        .frame(width: 360)
}
