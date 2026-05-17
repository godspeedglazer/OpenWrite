import SwiftUI

/// Reor-style horizontal source pills tied to retrieved vault chunks.
struct RAGSourcePillsView: View {
    let hits: [RetrievalHit]
    var onOpenDocument: ((UUID) -> Void)?

    private var documentSources: [RetrievalHit] {
        hits.uniqueDocumentSources()
    }

    var body: some View {
        if !documentSources.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                Text("Sources")
                    .font(OWTypography.captionEmphasis)
                    .foregroundStyle(DesignTokens.Color.textSecondary)

                FlowLayout(spacing: 6) {
                    ForEach(documentSources) { hit in
                        sourcePill(hit)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder
    private func sourcePill(_ hit: RetrievalHit) -> some View {
        let label = hit.sourcePillTitle
        if let onOpenDocument {
            Button {
                onOpenDocument(hit.documentID)
            } label: {
                pillLabel(label)
            }
            .buttonStyle(.plain)
            .help("Open \(label)")
        } else {
            pillLabel(label)
        }
    }

    private func pillLabel(_ title: String) -> some View {
        Text(title)
            .font(OWTypography.caption)
            .foregroundStyle(DesignTokens.Color.textPrimary)
            .lineLimit(1)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(DesignTokens.Color.surface, in: Capsule())
            .overlay {
                Capsule()
                    .strokeBorder(DesignTokens.Color.borderSubtle, lineWidth: DesignTokens.Layout.borderWidth)
            }
    }
}

// MARK: - Simple horizontal wrap layout

private struct FlowLayout: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 0
        guard width > 0 else { return .zero }
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > 0, x + size.width > width {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
        }
        return CGSize(width: width, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > bounds.minX, x + size.width > bounds.maxX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}
