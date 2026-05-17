import CoreGraphics
import Foundation

/// Read-only graph snapshot for vault wikilink visualization (E-06).
struct GraphSnapshot: Sendable {
    struct Node: Identifiable, Sendable {
        let id: UUID
        let title: String
        let pageType: PageType
        let position: CGPoint
        let size: CGSize
        let linkCount: Int
        let isSelected: Bool
    }

    struct Edge: Identifiable, Sendable {
        let id: String
        let sourceID: UUID
        let targetID: UUID
    }

    let nodes: [Node]
    let edges: [Edge]
    let isolatedCount: Int

    static let empty = GraphSnapshot(nodes: [], edges: [], isolatedCount: 0)
}

enum GraphViewModel {
    private static let baseCardSize = CGSize(
        width: DesignTokens.Layout.graphNodeCardWidth,
        height: DesignTokens.Layout.graphNodeCardHeight
    )
    private static let minSpacing = DesignTokens.Layout.graphNodeMinSpacing
    private static let layoutIterations = 48

    static func makeSnapshot(
        documents: [VaultDocument],
        index: BacklinkIndex,
        selectedDocumentID: UUID?,
        canvasSize: CGSize
    ) -> GraphSnapshot {
        guard !documents.isEmpty else { return .empty }

        let sortedDocuments = documents.sorted {
            $0.displayTitle.localizedCaseInsensitiveCompare($1.displayTitle) == .orderedAscending
        }

        let linkCounts = linkCounts(for: sortedDocuments, index: index)
        let sizes = sortedDocuments.map { nodeSize(linkCount: linkCounts[$0.id] ?? 0) }
        let positions = layoutPositions(
            count: sortedDocuments.count,
            sizes: sizes,
            edges: edgePairs(documents: sortedDocuments, index: index),
            canvasSize: canvasSize
        )

        let nodes: [GraphSnapshot.Node] = sortedDocuments.enumerated().map { offset, document in
            GraphSnapshot.Node(
                id: document.id,
                title: document.displayTitle,
                pageType: document.pageType,
                position: positions[offset],
                size: sizes[offset],
                linkCount: linkCounts[document.id] ?? 0,
                isSelected: document.id == selectedDocumentID
            )
        }

        let nodeIDs = Set(sortedDocuments.map(\.id))
        var edges: [GraphSnapshot.Edge] = []
        for document in sortedDocuments {
            for targetID in index.outlinks(from: document.id) where nodeIDs.contains(targetID) {
                let edgeID = "\(document.id.uuidString)->\(targetID.uuidString)"
                edges.append(GraphSnapshot.Edge(id: edgeID, sourceID: document.id, targetID: targetID))
            }
        }

        let isolatedCount = sortedDocuments.filter { (linkCounts[$0.id] ?? 0) == 0 }.count
        return GraphSnapshot(nodes: nodes, edges: edges, isolatedCount: isolatedCount)
    }

    // MARK: - Node sizing

    private static func linkCounts(
        for documents: [VaultDocument],
        index: BacklinkIndex
    ) -> [UUID: Int] {
        var counts: [UUID: Int] = [:]
        for document in documents {
            let out = index.outlinks(from: document.id).count
            let incoming = index.backlinks(to: document.id).count
            counts[document.id] = out + incoming
        }
        return counts
    }

    private static func nodeSize(linkCount: Int) -> CGSize {
        guard linkCount > 0 else { return baseCardSize }
        let scale = min(1.15, 1 + CGFloat(linkCount) * 0.03)
        return CGSize(width: baseCardSize.width * scale, height: baseCardSize.height * scale)
    }

    // MARK: - Layout

    private static func edgePairs(
        documents: [VaultDocument],
        index: BacklinkIndex
    ) -> [(Int, Int)] {
        let idToIndex = Dictionary(uniqueKeysWithValues: documents.enumerated().map { ($1.id, $0) })
        var pairs: [(Int, Int)] = []
        var seen = Set<String>()
        for (sourceIndex, document) in documents.enumerated() {
            for targetID in index.outlinks(from: document.id) {
                guard let targetIndex = idToIndex[targetID] else { continue }
                let key = "\(min(sourceIndex, targetIndex))-\(max(sourceIndex, targetIndex))"
                guard seen.insert(key).inserted else { continue }
                pairs.append((sourceIndex, targetIndex))
            }
        }
        return pairs
    }

    private static func layoutPositions(
        count: Int,
        sizes: [CGSize],
        edges: [(Int, Int)],
        canvasSize: CGSize
    ) -> [CGPoint] {
        guard count > 0 else { return [] }

        let center = CGPoint(x: canvasSize.width / 2, y: canvasSize.height / 2)
        if count == 1 { return [center] }

        let maxCard = sizes.max(by: { $0.width * $0.height < $1.width * $1.height }) ?? baseCardSize
        let minDist = max(maxCard.width, maxCard.height) + minSpacing
        let circumference = CGFloat(count) * minDist
        let radius = max(100, circumference / (2 * .pi))

        var positions = circleLayout(count: count, center: center, radius: radius)
        refineLayout(positions: &positions, sizes: sizes, edges: edges, canvasSize: canvasSize)
        return positions
    }

    private static func circleLayout(count: Int, center: CGPoint, radius: CGFloat) -> [CGPoint] {
        (0..<count).map { index in
            let angle = (Double(index) / Double(count)) * 2 * .pi - .pi / 2
            return CGPoint(
                x: center.x + radius * CGFloat(cos(angle)),
                y: center.y + radius * CGFloat(sin(angle))
            )
        }
    }

    private static func refineLayout(
        positions: inout [CGPoint],
        sizes: [CGSize],
        edges: [(Int, Int)],
        canvasSize: CGSize
    ) {
        let center = CGPoint(x: canvasSize.width / 2, y: canvasSize.height / 2)
        let padding: CGFloat = 48

        for _ in 0..<layoutIterations {
            var forces = Array(repeating: CGPoint.zero, count: positions.count)

            for i in 0..<positions.count {
                for j in (i + 1)..<positions.count {
                    let dx = positions[j].x - positions[i].x
                    let dy = positions[j].y - positions[i].y
                    var dist = hypot(dx, dy)
                    if dist < 1 { dist = 1 }
                    let minDist = (sizes[i].width + sizes[j].width) / 2 + minSpacing
                    if dist < minDist {
                        let push = (minDist - dist) / dist * 0.55
                        let fx = dx * push
                        let fy = dy * push
                        forces[i].x -= fx
                        forces[i].y -= fy
                        forces[j].x += fx
                        forces[j].y += fy
                    }
                }
            }

            for (sourceIndex, targetIndex) in edges {
                let dx = positions[targetIndex].x - positions[sourceIndex].x
                let dy = positions[targetIndex].y - positions[sourceIndex].y
                let dist = hypot(dx, dy)
                let ideal: CGFloat = 160
                guard dist > 1 else { continue }
                let pull = (dist - ideal) / dist * 0.06
                forces[sourceIndex].x += dx * pull
                forces[sourceIndex].y += dy * pull
                forces[targetIndex].x -= dx * pull
                forces[targetIndex].y -= dy * pull
            }

            for i in 0..<positions.count {
                forces[i].x += (center.x - positions[i].x) * 0.025
                forces[i].y += (center.y - positions[i].y) * 0.025
            }

            for i in 0..<positions.count {
                positions[i].x += forces[i].x
                positions[i].y += forces[i].y
                positions[i].x = min(max(positions[i].x, padding), canvasSize.width - padding)
                positions[i].y = min(max(positions[i].y, padding), canvasSize.height - padding)
            }
        }
    }

    // MARK: - Geometry helpers (edges)

    static func edgeSegment(
        from source: GraphSnapshot.Node,
        to target: GraphSnapshot.Node
    ) -> (start: CGPoint, end: CGPoint) {
        let start = borderPoint(center: source.position, size: source.size, toward: target.position)
        let end = borderPoint(center: target.position, size: target.size, toward: source.position)
        return (start, end)
    }

    private static func borderPoint(center: CGPoint, size: CGSize, toward other: CGPoint) -> CGPoint {
        let dx = other.x - center.x
        let dy = other.y - center.y
        let dist = hypot(dx, dy)
        guard dist > 0.001 else { return center }

        let halfW = size.width / 2
        let halfH = size.height / 2
        let scaleX = abs(dx) > 0.001 ? halfW / abs(dx) : .greatestFiniteMagnitude
        let scaleY = abs(dy) > 0.001 ? halfH / abs(dy) : .greatestFiniteMagnitude
        let scale = min(scaleX, scaleY)
        return CGPoint(x: center.x + dx * scale, y: center.y + dy * scale)
    }
}
