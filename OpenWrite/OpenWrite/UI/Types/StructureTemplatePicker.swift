import SwiftUI

/// Pick a structure preset when creating a new page (book, document, wiki site, collection).
struct StructureTemplatePicker: View {
    @EnvironmentObject private var vaultStore: VaultStore
    var onCreated: ((UUID) -> Void)?

    @State private var newTitle: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Structure template")
                .font(.headline)

            TextField("Title", text: $newTitle)
                .textFieldStyle(.roundedBorder)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: 10)], spacing: 10) {
                ForEach(StructureTemplate.allCases) { structure in
                    structureButton(structure)
                }
            }
        }
        .padding(.vertical, 4)
    }

    private func structureButton(_ structure: StructureTemplate) -> some View {
        Button {
            let title = newTitle.isEmpty ? nil : newTitle
            let doc = vaultStore.createFromStructure(structure, title: title)
            onCreated?(doc.id)
            newTitle = ""
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Image(systemName: structure.systemImage)
                        .font(.title2)
                    Text(structure.displayName)
                        .font(.subheadline.weight(.semibold))
                }
                Text(structure.summary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(Color.secondary.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
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
