import SwiftUI

struct EditorView: View {
    let document: VaultDocument

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text(document.title)
                    .font(.largeTitle.bold())

                ForEach(document.rootBlocks) { block in
                    blockView(block)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(24)
        }
    }

    @ViewBuilder
    private func blockView(_ block: NoteBlock) -> some View {
        switch block.kind {
        case .heading1:
            Text(block.text).font(.title)
        case .heading2:
            Text(block.text).font(.title2)
        case .heading3:
            Text(block.text).font(.title3)
        case .bullet:
            HStack(alignment: .top, spacing: 8) {
                Text("•")
                Text(block.text)
            }
        case .quote:
            Text(block.text)
                .padding(.leading, 12)
                .overlay(alignment: .leading) {
                    Rectangle()
                        .fill(Color.secondary.opacity(0.4))
                        .frame(width: 3)
                }
        case .code:
            Text(block.text)
                .font(.system(.body, design: .monospaced))
                .padding(8)
                .background(Color.secondary.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 6))
        case .divider:
            Divider()
        case .wikilink:
            Text(block.text)
                .foregroundStyle(.tint)
        case .paragraph:
            Text(block.text)
        }
    }
}
