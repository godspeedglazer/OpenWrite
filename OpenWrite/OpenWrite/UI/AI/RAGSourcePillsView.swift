import SwiftUI

/// Reor-style horizontal source pills tied to retrieved vault chunks.
struct RAGSourcePillsView: View {
    let hits: [RetrievalHit]
    var onOpenDocument: ((UUID) -> Void)?
    /// Inline chips for chat bubbles — no section title, tighter padding.
    var compact: Bool = false

    private var documentSources: [RAGDocumentSource] {
        hits.groupedDocumentSources()
    }

    var body: some View {
        if !documentSources.isEmpty {
            Group {
                if compact {
                    FlowLayout(spacing: 4) {
                        ForEach(documentSources) { source in
                            sourcePill(source)
                        }
                    }
                } else {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Sources")
                            .font(OWTypography.captionEmphasis)
                            .foregroundStyle(DesignTokens.Color.textSecondary)

                        FlowLayout(spacing: 6) {
                            ForEach(documentSources) { source in
                                sourcePill(source)
                            }
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder
    private func sourcePill(_ source: RAGDocumentSource) -> some View {
        if let onOpenDocument {
            Button {
                onOpenDocument(source.documentID)
            } label: {
                pillLabel(source)
            }
            .buttonStyle(.plain)
            .openWriteFocusChrome()
            .help(pillHelp(source))
        } else {
            pillLabel(source)
        }
    }

    private func pillHelp(_ source: RAGDocumentSource) -> String {
        var parts = [source.primaryLabel]
        if let subtitle = source.subtitle { parts.append(subtitle) }
        if let badge = source.chunkBadge { parts.append(badge) }
        if let excerpt = source.representativeHit.sourcePillExcerpt { parts.append(excerpt) }
        return parts.joined(separator: "\n")
    }

    private func pillLabel(_ source: RAGDocumentSource) -> some View {
        HStack(spacing: 5) {
            VStack(alignment: .leading, spacing: 1) {
                Text(source.primaryLabel)
                    .font(compact ? OWTypography.captionEmphasis : OWTypography.captionEmphasis)
                    .foregroundStyle(compact ? DesignTokens.Color.textPrimary : DesignTokens.Color.textPrimary)
                    .lineLimit(1)
                    .truncationMode(.tail)

                if let subtitle = source.subtitle {
                    Text(subtitle)
                        .font(OWTypography.caption2)
                        .foregroundStyle(DesignTokens.Color.textTertiary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
            }

            if let badge = source.chunkBadge {
                Text(badge)
                    .font(OWTypography.caption2.monospacedDigit())
                    .foregroundStyle(DesignTokens.Color.textSecondary)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(DesignTokens.Color.background.opacity(0.65), in: Capsule())
            }
        }
        .frame(maxWidth: compact ? 168 : 196, alignment: .leading)
        .padding(.horizontal, compact ? 7 : 10)
        .padding(.vertical, compact ? 4 : 6)
        .background(
            compact
                ? DesignTokens.Color.background.opacity(0.55)
                : DesignTokens.Color.surface.opacity(0.95),
            in: Capsule()
        )
        .overlay {
            if !compact {
                Capsule()
                    .strokeBorder(DesignTokens.Color.borderSubtle, lineWidth: DesignTokens.Layout.borderWidth)
            }
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
