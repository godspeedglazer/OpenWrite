import SwiftUI

/// Anytype-inspired global graph shell — read-only placeholder canvas (local-only).
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

                var path = Path()
                path.move(to: source.position.applying(transform))
                path.addLine(to: target.position.applying(transform))
                context.stroke(
                    path,
                    with: .color(DesignTokens.Color.borderSubtle),
                    lineWidth: 1.2 / zoom
                )
            }

            for node in snapshot.nodes {
                let point = node.position.applying(transform)
                let radius: CGFloat = node.isSelected ? 22 : 18
                let circle = Path(ellipseIn: CGRect(
                    x: point.x - radius,
                    y: point.y - radius,
                    width: radius * 2,
                    height: radius * 2
                ))
                context.fill(circle, with: .color(nodeFill(node)))
                context.stroke(
                    circle,
                    with: .color(node.isSelected ? DesignTokens.Color.accent : DesignTokens.Color.borderSubtle),
                    lineWidth: node.isSelected ? 2.5 : 1
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
        .overlay {
            nodeLabels(snapshot: snapshot)
        }
        .contentShape(Rectangle())
    }

    private func nodeLabels(snapshot: GraphSnapshot) -> some View {
        ZStack {
            ForEach(snapshot.nodes) { node in
                let point = node.position
                VStack(spacing: 4) {
                    OWIconView(icon: node.pageType.owIcon, size: 12, color: DesignTokens.Color.textSecondary)
                    Text(node.title)
                        .font(DesignTokens.Typography.caption)
                        .foregroundStyle(DesignTokens.Color.textPrimary)
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 96)
                }
                .position(
                    x: point.x + effectivePan.width,
                    y: point.y + effectivePan.height + 36 * zoom
                )
                .scaleEffect(zoom)
                .onTapGesture { onSelectDocument(node.id) }
            }
        }
        .allowsHitTesting(true)
    }

    private func nodeFill(_ node: GraphSnapshot.Node) -> Color {
        node.isSelected ? DesignTokens.Color.accentMuted : DesignTokens.Color.surfaceElevated
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
                RoundedRectangle(cornerRadius: DesignTokens.Radius.medium, style: .continuous)
                    .fill(DesignTokens.Color.surfaceElevated)
                    .shadow(color: .black.opacity(0.10), radius: 12, y: 4)
                    .overlay {
                        RoundedRectangle(cornerRadius: DesignTokens.Radius.medium, style: .continuous)
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
                OWIconView(icon: .zoomOut, size: 14, color: DesignTokens.Color.accent)
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
                OWIconView(icon: .zoomIn, size: 14, color: DesignTokens.Color.accent)
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
