import AppKit
import SwiftUI

/// Anytype-inspired global graph — wikilink canvas with drag, curved edges, persisted layout.
struct GraphView: View {
    let vaultID: UUID
    let documents: [VaultDocument]
    let backlinkIndex: BacklinkIndex
    let selectedDocumentID: UUID?
    var onSelectDocument: (UUID) -> Void

    @State private var canvasSize: CGSize = .zero
    @State private var layoutCanvasSize: CGSize = CGSize(width: 640, height: 480)
    @State private var snapshot: GraphSnapshot = .empty
    @State private var edgeRoutes: [String: GraphEdgeRoute] = [:]
    @State private var layoutTask: Task<Void, Never>?
    @State private var canvasResizeDebounceTask: Task<Void, Never>?
    @State private var panOffset: CGSize = .zero
    @GestureState private var dragTranslation: CGSize = .zero
    @State private var zoom: CGFloat = 1
    @State private var nodePositions: [UUID: CGPoint] = [:]
    @State private var usesManualLayout = false
    @State private var draggingNodeID: UUID?
    @State private var nodeDragTranslation: CGSize = .zero

    private var effectivePan: CGSize {
        CGSize(
            width: panOffset.width + dragTranslation.width,
            height: panOffset.height + dragTranslation.height
        )
    }

    private var documentIDs: [UUID] {
        documents.map(\.id)
    }

    private var backlinkSignature: Int {
        var hasher = Hasher()
        for document in documents {
            hasher.combine(document.id)
            for targetID in backlinkIndex.outlinks(from: document.id) {
                hasher.combine(targetID)
            }
        }
        return hasher.finalize()
    }

    var body: some View {
        GeometryReader { geometry in
            let size = geometry.size

            ZStack(alignment: .topLeading) {
                DesignTokens.Color.editorCanvas

                if documents.isEmpty {
                    emptyVaultState(in: size)
                } else {
                    graphCanvas(snapshot: snapshot)
                    if shouldShowLinklessOverlay(snapshot: snapshot) {
                        emptyGraphOverlay(in: size)
                    }
                    graphNodeCards(snapshot: snapshot)
                }

                graphChrome(snapshot: snapshot)
            }
            .background(OWDisablesWindowDrag())
            .modifier(GraphWindowDragPolicyModifier())
            .onAppear {
                canvasSize = size
                layoutCanvasSize = resolvedLayoutCanvasSize(size)
                loadPersistedLayout()
                rebuildSnapshot()
            }
            .onChange(of: size) { _, newSize in
                canvasSize = newSize
                let resolved = resolvedLayoutCanvasSize(newSize)
                guard resolved != layoutCanvasSize else { return }
                layoutCanvasSize = resolved
                if usesManualLayout {
                    nodePositions = clampPositionsToCanvas(nodePositions, canvasSize: resolved)
                    rebuildSnapshot()
                } else {
                    canvasResizeDebounceTask?.cancel()
                    canvasResizeDebounceTask = Task {
                        try? await Task.sleep(for: .milliseconds(200))
                        guard !Task.isCancelled else { return }
                        rebuildSnapshot()
                    }
                }
            }
            .onChange(of: vaultID) { _, _ in
                resetViewTransform()
                loadPersistedLayout()
                rebuildSnapshot()
            }
            .onChange(of: documentIDs) { _, _ in
                pruneStalePositions()
                rebuildSnapshot()
            }
            .onChange(of: backlinkSignature) { _, _ in
                rebuildSnapshot()
            }
            .onChange(of: selectedDocumentID) { _, _ in
                refreshSelectionHighlight()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
                guard let route = edgeRoutes[edge.id] else { continue }

                var path = GraphViewModel.bezierPath(for: route)
                path = path.applying(transform)

                context.stroke(
                    path,
                    with: .color(DesignTokens.Color.graphEdge),
                    lineWidth: 1.25 / zoom
                )

                let transformedRoute = GraphEdgeRoute(
                    start: route.start.applying(transform),
                    end: route.end.applying(transform),
                    control: route.control.applying(transform)
                )
                let arrow = GraphViewModel.arrowTangent(at: transformedRoute)
                drawArrowhead(
                    context: &context,
                    tip: arrow.tip,
                    direction: arrow.direction,
                    zoom: zoom
                )
            }
        }
        .background(OWDisablesWindowDrag())
        .contentShape(Rectangle())
        .gesture(canvasPanGesture)
    }

    private var canvasPanGesture: some Gesture {
        DragGesture()
            .updating($dragTranslation) { value, state, _ in
                guard draggingNodeID == nil else { return }
                state = value.translation
            }
            .onEnded { value in
                guard draggingNodeID == nil else { return }
                panOffset = CGSize(
                    width: panOffset.width + value.translation.width,
                    height: panOffset.height + value.translation.height
                )
            }
    }

    private func drawArrowhead(
        context: inout GraphicsContext,
        tip: CGPoint,
        direction: CGPoint,
        zoom: CGFloat
    ) {
        let ux = direction.x
        let uy = direction.y
        let size: CGFloat = 6 / zoom
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
        ZStack(alignment: .topLeading) {
            ForEach(snapshot.nodes) { node in
                graphNodeCard(node: node)
                    .position(displayPosition(for: node))
                    .scaleEffect(zoom)
                    .highPriorityGesture(nodeDragGesture(node: node))
                    .onTapGesture {
                        guard draggingNodeID == nil else { return }
                        onSelectDocument(node.id)
                    }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .allowsHitTesting(true)
    }

    private func displayPosition(for node: GraphSnapshot.Node) -> CGPoint {
        var base = node.position
        if draggingNodeID == node.id {
            base = CGPoint(
                x: base.x + nodeDragTranslation.width / zoom,
                y: base.y + nodeDragTranslation.height / zoom
            )
        }
        return transformed(base)
    }

    private func nodeDragGesture(node: GraphSnapshot.Node) -> some Gesture {
        DragGesture(minimumDistance: 4)
            .onChanged { value in
                if draggingNodeID == nil {
                    draggingNodeID = node.id
                }
                guard draggingNodeID == node.id else { return }
                nodeDragTranslation = value.translation
            }
            .onEnded { value in
                guard draggingNodeID == node.id else { return }
                let delta = CGSize(
                    width: value.translation.width / zoom,
                    height: value.translation.height / zoom
                )
                let next = GraphViewModel.snap(CGPoint(
                    x: node.position.x + delta.width,
                    y: node.position.y + delta.height
                ))
                nodePositions[node.id] = next
                usesManualLayout = true
                persistLayout()
                rebuildSnapshot()
                draggingNodeID = nil
                nodeDragTranslation = .zero
            }
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
        .contentShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.owRect, style: .continuous))
        .background(OWDisablesWindowDrag())
    }

    private func transformed(_ point: CGPoint) -> CGPoint {
        CGPoint(
            x: point.x * zoom + effectivePan.width,
            y: point.y * zoom + effectivePan.height
        )
    }

    // MARK: - Snapshot / layout

    private func resolvedLayoutCanvasSize(_ size: CGSize) -> CGSize {
        size == .zero ? CGSize(width: 640, height: 480) : size
    }

    private func applySnapshot(_ newSnapshot: GraphSnapshot) {
        snapshot = newSnapshot
        edgeRoutes = GraphViewModel.routeEdges(snapshot: newSnapshot)
    }

    private func rebuildSnapshot() {
        layoutTask?.cancel()
        canvasResizeDebounceTask?.cancel()

        guard !documents.isEmpty else {
            snapshot = .empty
            edgeRoutes = [:]
            return
        }

        let overrides = usesManualLayout ? nodePositions : nil
        let allNodesPositioned = overrides.map { positions in
            !positions.isEmpty && documents.allSatisfy { positions[$0.id] != nil }
        } ?? false

        if allNodesPositioned, let overrides {
            applySnapshot(
                GraphViewModel.makeSnapshot(
                    documents: documents,
                    index: backlinkIndex,
                    selectedDocumentID: selectedDocumentID,
                    canvasSize: layoutCanvasSize,
                    positionOverrides: overrides
                )
            )
            return
        }

        let docs = documents
        let index = backlinkIndex
        let selectedID = selectedDocumentID
        let canvas = layoutCanvasSize
        let manualOverrides = overrides

        layoutTask = Task {
            let prepared = GraphViewModel.prepareAutoLayout(
                documents: docs,
                index: index,
                canvasSize: canvas
            )
            let autoPositions = await GraphViewModel.computeAutoLayoutOffMain(
                documentIDs: prepared.sortedDocuments.map(\.id),
                sizes: prepared.sizes,
                edges: prepared.edges,
                canvasSize: canvas
            )
            guard !Task.isCancelled else { return }

            let built = GraphViewModel.makeSnapshot(
                documents: docs,
                index: index,
                selectedDocumentID: selectedID,
                canvasSize: canvas,
                positionOverrides: manualOverrides,
                precomputedAutoPositions: autoPositions
            )
            await MainActor.run {
                guard !Task.isCancelled else { return }
                applySnapshot(built)
            }
        }
    }

    private func refreshSelectionHighlight() {
        guard !snapshot.nodes.isEmpty else { return }
        let nodes = snapshot.nodes.map { node in
            GraphSnapshot.Node(
                id: node.id,
                title: node.title,
                pageType: node.pageType,
                position: node.position,
                size: node.size,
                linkCount: node.linkCount,
                isSelected: node.id == selectedDocumentID
            )
        }
        snapshot = GraphSnapshot(
            nodes: nodes,
            edges: snapshot.edges,
            isolatedCount: snapshot.isolatedCount
        )
    }

    // MARK: - Layout persistence

    private func loadPersistedLayout() {
        let stored = GraphLayoutStore.load(vaultID: vaultID)
        nodePositions = clampPositionsToCanvas(stored, canvasSize: layoutCanvasSize)
        usesManualLayout = !nodePositions.isEmpty
    }

    /// Keeps saved manual positions visible after window resize or stale layout files.
    private func clampPositionsToCanvas(
        _ positions: [UUID: CGPoint],
        canvasSize: CGSize
    ) -> [UUID: CGPoint] {
        guard canvasSize.width > 1, canvasSize.height > 1 else { return positions }
        let inset: CGFloat = 48
        let maxX = max(inset, canvasSize.width - inset)
        let maxY = max(inset, canvasSize.height - inset)
        var clamped: [UUID: CGPoint] = [:]
        clamped.reserveCapacity(positions.count)
        for (id, point) in positions {
            clamped[id] = CGPoint(
                x: min(max(point.x, inset), maxX),
                y: min(max(point.y, inset), maxY)
            )
        }
        return clamped
    }

    private func persistLayout() {
        GraphLayoutStore.save(vaultID: vaultID, positions: nodePositions)
    }

    private func pruneStalePositions() {
        let liveIDs = Set(documents.map(\.id))
        let pruned = nodePositions.filter { liveIDs.contains($0.key) }
        if pruned.count != nodePositions.count {
            nodePositions = pruned
            if pruned.isEmpty {
                usesManualLayout = false
            }
            persistLayout()
            rebuildSnapshot()
        }
    }

    private func resetToAutoLayout() {
        withAnimation(DesignTokens.Motion.animationStandard) {
            usesManualLayout = false
            nodePositions = [:]
            zoom = 1
            panOffset = .zero
        }
        GraphLayoutStore.clear(vaultID: vaultID)
        rebuildSnapshot()
    }

    private func resetViewTransform() {
        zoom = 1
        panOffset = .zero
        draggingNodeID = nil
        nodeDragTranslation = .zero
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
                    if usesManualLayout {
                        Text("Custom layout")
                            .font(DesignTokens.Typography.caption)
                            .foregroundStyle(DesignTokens.Color.textTertiary)
                    } else if snapshot.isolatedCount > 0 {
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
            .openWriteFocusChrome()

            Button {
                resetToAutoLayout()
            } label: {
                Text("Reset")
            }
            .buttonStyle(.plain)
            .openWriteFocusChrome()
            .help("Reset zoom, pan, and auto-layout positions")

            Button {
                withAnimation(DesignTokens.Motion.animationStandard) { zoom = min(2.0, zoom + 0.15) }
            } label: {
                OWUnicodeIconView(icon: .zoomIn, size: 14, color: DesignTokens.Color.accent)
            }
            .buttonStyle(.plain)
        .openWriteFocusChrome()
        }
        .foregroundStyle(DesignTokens.Color.accent)
    }

    // MARK: - Empty states

    /// Center "No links yet" hero only when several notes exist but none are linked.
    /// Single-note vaults keep the node visible without a overlapping empty-state card.
    private func shouldShowLinklessOverlay(snapshot: GraphSnapshot) -> Bool {
        snapshot.edges.isEmpty && snapshot.nodes.count > 1
    }

    private func emptyVaultState(in size: CGSize) -> some View {
        centeredGraphHero(
            size: size,
            title: "No notes in vault",
            subtitle: "Create a page to see it on the graph.",
            icon: .graph
        )
    }

    private func emptyGraphOverlay(in size: CGSize) -> some View {
        centeredGraphHero(
            size: size,
            title: "No links yet",
            subtitle: "Connect notes with [[wikilinks]] in the editor. Unresolved titles appear once a matching page exists.",
            icon: .link
        )
    }

    private func centeredGraphHero(
        size: CGSize,
        title: String,
        subtitle: String,
        icon: OWIcon
    ) -> some View {
        let narrow = size.width < DesignTokens.Layout.graphEmptyStateCompactWidth
        let readableWidth = min(
            size.width - DesignTokens.Spacing.spacing6 * 2,
            DesignTokens.Layout.graphEmptyStateMaxReadableWidth
        )

        return VStack(spacing: 0) {
            Spacer(minLength: DesignTokens.Layout.graphChromeTopReserve)

            OWPageHero(
                title: title,
                subtitle: subtitle,
                icon: icon,
                style: .emptyState,
                compact: true,
                narrow: narrow
            )
            .frame(maxWidth: max(readableWidth, 220))
            .frame(maxWidth: .infinity)

            Spacer(minLength: DesignTokens.Layout.graphChromeBottomReserve)
        }
        .frame(width: size.width, height: size.height, alignment: .center)
        .allowsHitTesting(false)
    }
}

// MARK: - Window drag policy

/// Suppresses `isMovableByWindowBackground` while the graph is visible; chrome configurator may re-apply.
private struct GraphWindowDragPolicyModifier: ViewModifier {
    func body(content: Content) -> some View {
        content.background(GraphWindowDragPolicyHost())
    }
}

private struct GraphWindowDragPolicyHost: NSViewRepresentable {
    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: .zero)
        view.openWriteSuppressFocusRing()
        context.coordinator.activate(from: view)
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        context.coordinator.activate(from: nsView)
    }

    static func dismantleNSView(_ nsView: NSView, coordinator: Coordinator) {
        coordinator.deactivate()
    }

    final class Coordinator {
        private var isActive = false

        func activate(from view: NSView) {
            if !isActive {
                isActive = true
                OWWindowChrome.suppressBackgroundWindowDrag = true
            }
            if let window = view.window {
                OWWindowChrome.apply(to: window)
            }
        }

        func deactivate() {
            guard isActive else { return }
            isActive = false
            OWWindowChrome.suppressBackgroundWindowDrag = false
            OWWindowChrome.reapplyToKeyWindow()
        }
    }
}

#Preview {
    GraphView(
        vaultID: OpenWriteVault.primaryID,
        documents: [VaultDocument.welcomeSample],
        backlinkIndex: .build(from: [VaultDocument.welcomeSample]),
        selectedDocumentID: VaultDocument.welcomeSample.id,
        onSelectDocument: { _ in }
    )
    .frame(width: 720, height: 520)
}
