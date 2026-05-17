import SwiftUI

/// Anytype-inspired global graph — read-only wikilink canvas (local-only).
struct GraphView: View {
    let documents: [VaultDocument]
    let backlinkIndex: BacklinkIndex
    let selectedDocumentID: UUID?
    var onSelectDocument: (UUID) -> Void

    @State private var canvasSize: CGSize = .zero
    @State private var panOffset: CGSize = .zero
    @GestureState private var dragTranslation: CGSize = .zero
    @State private var zoom: CGFloat = 1

    private var effectivePan: CGSize {
        CGSize(
            width: panOffset.width + dragTranslation.width,
            height: panOffset.height + dragTranslation.height
        )
    }

    private var snapshot: GraphSnapshot {
        GraphViewModel.makeSnapshot(
            documents: documents,
            index: backlinkIndex,
            selectedDocumentID: selectedDocumentID,
            canvasSize: canvasSize == .zero ? CGSize(width: 640, height: 480) : canvasSize
        )
    }

    var body: some View {
        GeometryReader { geometry in
            let size = geometry.size

            ZStack {
                DesignTokens.Color.editorCanvas

                if documents.isEmpty {
                    emptyVaultState
                } else {
                    graphCanvas(snapshot: snapshot)
                    if snapshot.edges.isEmpty {
                        emptyGraphOverlay
                    } else {
                        graphNodeCards(snapshot: snapshot)
                    }
                }

                graphChrome(snapshot: snapshot)
            }
            .onAppear { canvasSize = size }
            .onChange(of: size) { _, newSize in canvasSize = newSize }
            .onChange(of: documents.count) { _, _ in
                panOffset = .zero
                zoom = 1
            }
        }
        .background(DesignTokens.Color.editorCanvas)
        .accessibilityIdentifier("openwrite.graph.canvas")
    }

    // MARK: - Canvas

    @ViewBuilder
    private func graphCanvas(snapshot: GraphSnapshot) -> some View {
        Canvas { context, _ in
            let transform = CGAffineTransform.identity
                .translatedBy(x: effectivePan.width, y: effectivePan.height)
                .scaledBy(x: zoom, y: zoom)

            for edge in snapshot.edges {
                guard
                    let source = snapshot.nodes.first(where: { $0.id == edge.sourceID }),
                    let target = snapshot.nodes.first(where: { $0.id == edge.targetID })
                else { continue }

                let segment = GraphViewModel.edgeSegment(from: source, to: target)
                var path = Path()
                path.move(to: segment.start.applying(transform))
                path.addLine(to: segment.end.applying(transform))
                context.stroke(
                    path,
                    with: .color(DesignTokens.Color.graphEdge),
                    lineWidth: 1.25 / zoom
                )
                drawArrowhead(
                    context: &context,
                    from: segment.start.applying(transform),
                    to: segment.end.applying(transform),
                    zoom: zoom
                )
            }
        }
        .gesture(
            DragGesture()
                .updating($dragTranslation) { value, state, _ in
                    state = value.translation
                }
                .onEnded { value in
                    panOffset = CGSize(
                        width: panOffset.width + value.translation.width,
                        height: panOffset.height + value.translation.height
                    )
                }
        )
        .contentShape(Rectangle())
    }

    private func drawArrowhead(
        context: inout GraphicsContext,
        from start: CGPoint,
        to end: CGPoint,
        zoom: CGFloat
    ) {
        let dx = end.x - start.x
        let dy = end.y - start.y
        let length = hypot(dx, dy)
        guard length > 8 else { return }

        let ux = dx / length
        let uy = dy / length
        let size: CGFloat = 6 / zoom
        let tip = end
        let left = CGPoint(x: tip.x - ux * size - uy * size * 0.5, y: tip.y - uy * size + ux * size * 0.5)
        let right = CGPoint(x: tip.x - ux * size + uy * size * 0.5, y: tip.y - uy * size - ux * size * 0.5)

        var arrow = Path()
        arrow.move(to: tip)
        arrow.addLine(to: left)
        arrow.addLine(to: right)
        arrow.closeSubpath()
        context.fill(arrow, with: .color(DesignTokens.Color.graphEdge))
    }

    // MARK: - Nodes

    private func graphNodeCards(snapshot: GraphSnapshot) -> some View {
        ZStack {
            ForEach(snapshot.nodes) { node in
                graphNodeCard(node: node)
                    .position(transformed(node.position))
                    .scaleEffect(zoom)
                    .onTapGesture { onSelectDocument(node.id) }
            }
        }
        .allowsHitTesting(true)
    }

    private func graphNodeCard(node: GraphSnapshot.Node) -> some View {
        HStack(spacing: DesignTokens.Spacing.spacing2) {
            OWUnicodeIconView(
                pageType: node.pageType,
                size: 14,
                color: DesignTokens.Color.textSecondary
            )
            Text(node.title)
                .font(DesignTokens.Typography.caption)
                .foregroundStyle(DesignTokens.Color.textPrimary)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, DesignTokens.Spacing.spacing2)
        .padding(.vertical, DesignTokens.Spacing.spacing1 + 2)
        .frame(width: node.size.width, height: node.size.height)
        .background(
            RoundedRectangle(cornerRadius: DesignTokens.Radius.owRect, style: .continuous)
                .fill(node.isSelected ? DesignTokens.Color.accentMuted : DesignTokens.Color.graphNode)
        )
        .overlay {
            RoundedRectangle(cornerRadius: DesignTokens.Radius.owRect, style: .continuous)
                .strokeBorder(
                    node.isSelected ? DesignTokens.Color.graphNodeFocused : DesignTokens.Color.borderSubtle,
                    lineWidth: node.isSelected ? 2 : DesignTokens.Layout.borderWidth
                )
        }
        .shadow(
            color: DesignTokens.Shadow.subtle.color.opacity(0.35),
            radius: DesignTokens.Shadow.subtle.radius,
            x: 0,
            y: 1
        )
    }

    private func transformed(_ point: CGPoint) -> CGPoint {
        CGPoint(
            x: point.x * zoom + effectivePan.width,
            y: point.y * zoom + effectivePan.height
        )
    }

    // MARK: - Chrome

    private func graphChrome(snapshot: GraphSnapshot) -> some View {
        VStack {
            Spacer()
            HStack(spacing: DesignTokens.Spacing.spacing4) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(snapshot.nodes.count) notes")
                        .font(DesignTokens.Typography.captionEmphasis)
                        .foregroundStyle(DesignTokens.Color.textPrimary)
                    if snapshot.isolatedCount > 0 {
                        Text("\(snapshot.isolatedCount) without links")
                            .font(DesignTokens.Typography.caption)
                            .foregroundStyle(DesignTokens.Color.textTertiary)
                    }
                }

                Spacer(minLength: DesignTokens.Spacing.spacing4)

                graphZoomControls
            }
            .font(DesignTokens.Typography.caption)
            .foregroundStyle(DesignTokens.Color.textSecondary)
            .padding(.horizontal, DesignTokens.Spacing.spacing3)
            .padding(.vertical, DesignTokens.Spacing.spacing2)
            .frame(maxWidth: DesignTokens.Layout.graphFloatingBarMaxWidth)
            .background {
                RoundedRectangle(cornerRadius: DesignTokens.Radius.owRect, style: .continuous)
                    .fill(DesignTokens.Color.surfaceElevated)
                    .shadow(color: .black.opacity(0.10), radius: 12, y: 4)
                    .overlay {
                        RoundedRectangle(cornerRadius: DesignTokens.Radius.owRect, style: .continuous)
                            .strokeBorder(DesignTokens.Color.borderHairline, lineWidth: 0.5)
                    }
            }
            .padding(.horizontal, DesignTokens.Spacing.spacing2)
            .padding(.bottom, DesignTokens.Spacing.spacing2)
            .frame(maxWidth: .infinity)
        }
    }

    private var graphZoomControls: some View {
        HStack(spacing: DesignTokens.Spacing.spacing2) {
            Button {
                withAnimation(DesignTokens.Motion.animationStandard) { zoom = max(0.5, zoom - 0.15) }
            } label: {
                OWUnicodeIconView(icon: .zoomOut, size: 14, color: DesignTokens.Color.accent)
            }
            .buttonStyle(.plain)

            Button {
                withAnimation(DesignTokens.Motion.animationStandard) {
                    zoom = 1
                    panOffset = .zero
                }
            } label: {
                Text("Reset")
            }
            .buttonStyle(.plain)

            Button {
                withAnimation(DesignTokens.Motion.animationStandard) { zoom = min(2.0, zoom + 0.15) }
            } label: {
                OWUnicodeIconView(icon: .zoomIn, size: 14, color: DesignTokens.Color.accent)
            }
            .buttonStyle(.plain)
        }
        .foregroundStyle(DesignTokens.Color.accent)
    }

    // MARK: - Empty states

    private var emptyVaultState: some View {
        OWPageHero(
            title: "No notes in vault",
            subtitle: "Create a page to see it on the graph.",
            icon: .graph,
            style: .emptyState,
            compact: true
        )
    }

    private var emptyGraphOverlay: some View {
        OWPageHero(
            title: "No links yet",
            subtitle: "Connect notes with [[wikilinks]] in the editor. Unresolved titles appear once a matching page exists.",
            icon: .link,
            style: .emptyState,
            compact: true
        )
        .padding(DesignTokens.Spacing.spacing6)
        .allowsHitTesting(false)
    }
}

#Preview {
    GraphView(
        documents: [VaultDocument.welcomeSample],
        backlinkIndex: .build(from: [VaultDocument.welcomeSample]),
        selectedDocumentID: VaultDocument.welcomeSample.id,
        onSelectDocument: { _ in }
    )
    .frame(width: 720, height: 520)
}
