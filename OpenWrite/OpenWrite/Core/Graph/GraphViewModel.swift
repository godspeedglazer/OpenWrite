import CoreGraphics
import Foundation
import SwiftUI

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

    let nodes: [GraphSnapshot.Node]
    let edges: [GraphSnapshot.Edge]
    let isolatedCount: Int

    static let empty = GraphSnapshot(nodes: [], edges: [], isolatedCount: 0)
}

/// Routed edge geometry for canvas drawing (curved, fanned attachments).
struct GraphEdgeRoute: Sendable {
    let start: CGPoint
    let end: CGPoint
    let control: CGPoint
}

enum GraphViewModel {
    /// Soft cap for force-directed layout on the main graph tab.
    static let recommendedMaxNodes = 120

    private static let baseCardSize = CGSize(
        width: DesignTokens.Layout.graphNodeCardWidth,
        height: DesignTokens.Layout.graphNodeCardHeight
    )
    private static let minSpacing = DesignTokens.Layout.graphNodeMinSpacing
    private static let snapGrid: CGFloat = 8

    static func layoutIterationCount(nodeCount: Int) -> Int {
        switch nodeCount {
        case ...20: 90
        case 21...50: 60
        case 51...100: 40
        default: 25
        }
    }

    static func makeSnapshot(
        documents: [VaultDocument],
        index: BacklinkIndex,
        selectedDocumentID: UUID?,
        canvasSize: CGSize,
        positionOverrides: [UUID: CGPoint]? = nil,
        precomputedAutoPositions: [CGPoint]? = nil
    ) -> GraphSnapshot {
        guard !documents.isEmpty else { return .empty }

        let sortedDocuments = documents.sorted {
            $0.displayTitle.localizedCaseInsensitiveCompare($1.displayTitle) == .orderedAscending
        }

        let linkCounts = linkCounts(for: sortedDocuments, index: index)
        let sizes = sortedDocuments.map { nodeSize(linkCount: linkCounts[$0.id] ?? 0) }
        let edgeList = edgePairs(documents: sortedDocuments, index: index)

        let needsAutoLayout = sortedDocuments.contains { positionOverrides?[$0.id] == nil }
        let autoPositions: [CGPoint]
        if !needsAutoLayout {
            autoPositions = []
        } else if let precomputedAutoPositions, precomputedAutoPositions.count == sortedDocuments.count {
            autoPositions = precomputedAutoPositions
        } else {
            autoPositions = computeAutoLayout(
                documentIDs: sortedDocuments.map(\.id),
                sizes: sizes,
                edges: edgeList,
                canvasSize: canvasSize,
                iterations: layoutIterationCount(nodeCount: sortedDocuments.count)
            )
        }

        let positions: [CGPoint] = sortedDocuments.enumerated().map { offset, document in
            if let override = positionOverrides?[document.id] {
                return snap(override)
            }
            return autoPositions[offset]
        }

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

    /// Sorted vault pages plus force-layout inputs (call on main actor before async layout).
    static func prepareAutoLayout(
        documents: [VaultDocument],
        index: BacklinkIndex,
        canvasSize: CGSize
    ) -> (sortedDocuments: [VaultDocument], sizes: [CGSize], edges: [(Int, Int)]) {
        let sortedDocuments = documents.sorted {
            $0.displayTitle.localizedCaseInsensitiveCompare($1.displayTitle) == .orderedAscending
        }
        let linkCounts = linkCounts(for: sortedDocuments, index: index)
        let sizes = sortedDocuments.map { nodeSize(linkCount: linkCounts[$0.id] ?? 0) }
        let edges = edgePairs(documents: sortedDocuments, index: index)
        return (sortedDocuments, sizes, edges)
    }

    /// Force-directed auto layout (no center pile-up). Prefer `computeAutoLayoutOffMain` from views.
    static func computeAutoLayout(
        documentIDs: [UUID],
        sizes: [CGSize],
        edges: [(Int, Int)],
        canvasSize: CGSize,
        iterations: Int? = nil
    ) -> [CGPoint] {
        let count = documentIDs.count
        guard count > 0 else { return [] }

        let center = CGPoint(x: canvasSize.width / 2, y: canvasSize.height / 2)
        if count == 1 { return [center] }

        let iterationCount = iterations ?? layoutIterationCount(nodeCount: count)
        let area = canvasSize.width * canvasSize.height
        let k = sqrt(max(area, 10_000) / CGFloat(count))
        let padding: CGFloat = 56

        var positions = seededLayout(count: count, sizes: sizes, edges: edges, canvasSize: canvasSize)

        for iteration in 0..<iterationCount {
            let cooling = 1 - CGFloat(iteration) / CGFloat(max(iterationCount, 1))
            var displacements = Array(repeating: CGPoint.zero, count: count)

            for i in 0..<count {
                for j in (i + 1)..<count {
                    var dx = positions[i].x - positions[j].x
                    var dy = positions[i].y - positions[j].y
                    var dist = hypot(dx, dy)
                    if dist < 0.01 {
                        let jitter = CGFloat((i + j + iteration) % 7 + 1) * 0.4
                        dx = jitter
                        dy = -jitter * 0.6
                        dist = hypot(dx, dy)
                    }
                    let repulse = (k * k / dist) * (0.85 + cooling * 0.15)
                    let fx = (dx / dist) * repulse
                    let fy = (dy / dist) * repulse
                    displacements[i].x += fx
                    displacements[i].y += fy
                    displacements[j].x -= fx
                    displacements[j].y -= fy
                }
            }

            for (sourceIndex, targetIndex) in edges {
                var dx = positions[targetIndex].x - positions[sourceIndex].x
                var dy = positions[targetIndex].y - positions[sourceIndex].y
                var dist = hypot(dx, dy)
                if dist < 0.01 {
                    dx = 1
                    dy = 0
                    dist = 1
                }
                let attract = (dist * dist / k) * 0.04 * (0.5 + cooling * 0.5)
                let fx = (dx / dist) * attract
                let fy = (dy / dist) * attract
                displacements[sourceIndex].x += fx
                displacements[sourceIndex].y += fy
                displacements[targetIndex].x -= fx
                displacements[targetIndex].y -= fy
            }

            for i in 0..<count {
                let minDist = max(sizes[i].width, sizes[i].height) + minSpacing
                for j in 0..<count where i != j {
                    var dx = positions[i].x - positions[j].x
                    var dy = positions[i].y - positions[j].y
                    var dist = hypot(dx, dy)
                    if dist < minDist {
                        if dist < 0.01 {
                            dx = 1
                            dy = 0
                            dist = 1
                        }
                        let overlap = (minDist - dist) / dist * 0.9
                        displacements[i].x += dx * overlap
                        displacements[i].y += dy * overlap
                    }
                }
            }

            for i in 0..<count {
                var disp = displacements[i]
                let mag = hypot(disp.x, disp.y)
                if mag > 0.001 {
                    let capped = min(mag, 24 * cooling + 4)
                    disp.x = disp.x / mag * capped
                    disp.y = disp.y / mag * capped
                }
                positions[i].x += disp.x
                positions[i].y += disp.y
                positions[i].x = min(max(positions[i].x, padding), canvasSize.width - padding)
                positions[i].y = min(max(positions[i].y, padding), canvasSize.height - padding)
            }
        }

        return positions
    }

    /// Runs force layout off the main actor (one shot per graph load / resize debounce).
    static func computeAutoLayoutOffMain(
        documentIDs: [UUID],
        sizes: [CGSize],
        edges: [(Int, Int)],
        canvasSize: CGSize
    ) async -> [CGPoint] {
        let iterations = layoutIterationCount(nodeCount: documentIDs.count)
        return await Task.detached(priority: .userInitiated) {
            computeAutoLayout(
                documentIDs: documentIDs,
                sizes: sizes,
                edges: edges,
                canvasSize: canvasSize,
                iterations: iterations
            )
        }.value
    }

    static func snap(_ point: CGPoint) -> CGPoint {
        CGPoint(
            x: (point.x / snapGrid).rounded() * snapGrid,
            y: (point.y / snapGrid).rounded() * snapGrid
        )
    }

    // MARK: - Edge routing

    static func routeEdges(snapshot: GraphSnapshot) -> [String: GraphEdgeRoute] {
        let nodesByID = Dictionary(uniqueKeysWithValues: snapshot.nodes.map { ($0.id, $0) })
        var routes: [String: GraphEdgeRoute] = [:]
        routes.reserveCapacity(snapshot.edges.count)

        var pairBuckets: [String: [GraphSnapshot.Edge]] = [:]
        for edge in snapshot.edges {
            let key = undirectedPairKey(edge.sourceID, edge.targetID)
            pairBuckets[key, default: []].append(edge)
        }

        var sourceBuckets: [UUID: [GraphSnapshot.Edge]] = [:]
        var targetBuckets: [UUID: [GraphSnapshot.Edge]] = [:]
        for edge in snapshot.edges {
            sourceBuckets[edge.sourceID, default: []].append(edge)
            targetBuckets[edge.targetID, default: []].append(edge)
        }

        for edge in snapshot.edges {
            guard
                let source = nodesByID[edge.sourceID],
                let target = nodesByID[edge.targetID]
            else { continue }

            let pairKey = undirectedPairKey(edge.sourceID, edge.targetID)
            let pairEdges = pairBuckets[pairKey] ?? [edge]
            let pairIndex = pairEdges.firstIndex(where: { $0.id == edge.id }) ?? 0
            let pairCount = pairEdges.count

            let sourceFan = fanIndex(
                edge: edge,
                bucket: sourceBuckets[edge.sourceID] ?? [],
                nodesByID: nodesByID,
                fromNodeID: edge.sourceID
            )
            let sourceFanCount = sourceBuckets[edge.sourceID]?.count ?? 1

            let targetFan = fanIndex(
                edge: edge,
                bucket: targetBuckets[edge.targetID] ?? [],
                nodesByID: nodesByID,
                fromNodeID: edge.targetID
            )
            let targetFanCount = targetBuckets[edge.targetID]?.count ?? 1

            let pairOffset = curveOffset(index: pairIndex, count: pairCount, span: 72)
            let sourceSpread = fanSpread(index: sourceFan, count: sourceFanCount, span: 0.42)
            let targetSpread = fanSpread(index: targetFan, count: targetFanCount, span: 0.42)

            let chordAngle = atan2(target.position.y - source.position.y, target.position.x - source.position.x)
            let startAngle = chordAngle + sourceSpread
            let endAngle = chordAngle + .pi + targetSpread

            let start = borderPoint(center: source.position, size: source.size, angle: startAngle)
            let end = borderPoint(center: target.position, size: target.size, angle: endAngle)

            let mid = CGPoint(x: (start.x + end.x) / 2, y: (start.y + end.y) / 2)
            let perpX = -(end.y - start.y)
            let perpY = end.x - start.x
            let perpLen = max(hypot(perpX, perpY), 0.001)
            let curve = pairOffset + CGFloat(pairIndex - (pairCount - 1) / 2) * 4
            let control = CGPoint(
                x: mid.x + perpX / perpLen * curve,
                y: mid.y + perpY / perpLen * curve
            )

            routes[edge.id] = GraphEdgeRoute(start: start, end: end, control: control)
        }

        return routes
    }

    static func bezierPath(for route: GraphEdgeRoute) -> Path {
        var path = Path()
        path.move(to: route.start)
        path.addQuadCurve(to: route.end, control: route.control)
        return path
    }

    static func arrowTangent(at route: GraphEdgeRoute, samples: Int = 12) -> (tip: CGPoint, direction: CGPoint) {
        let tip = route.end
        let t = CGFloat(samples - 1) / CGFloat(samples)
        let u = 1 - t
        let near = CGPoint(
            x: u * u * route.start.x + 2 * u * t * route.control.x + t * t * route.end.x,
            y: u * u * route.start.y + 2 * u * t * route.control.y + t * t * route.end.y
        )
        let dx = tip.x - near.x
        let dy = tip.y - near.y
        let len = max(hypot(dx, dy), 0.001)
        return (tip, CGPoint(x: dx / len, y: dy / len))
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

    // MARK: - Layout helpers

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

    private static func seededLayout(
        count: Int,
        sizes: [CGSize],
        edges: [(Int, Int)],
        canvasSize: CGSize
    ) -> [CGPoint] {
        let center = CGPoint(x: canvasSize.width / 2, y: canvasSize.height / 2)
        let maxCard = sizes.max(by: { $0.width * $0.height < $1.width * $1.height }) ?? baseCardSize
        let minDist = max(maxCard.width, maxCard.height) + minSpacing
        let circumference = CGFloat(count) * minDist * 1.15
        let radius = max(120, circumference / (2 * .pi))

        var positions = (0..<count).map { index -> CGPoint in
            let angle = (Double(index) / Double(count)) * 2 * .pi - .pi / 2
            return CGPoint(
                x: center.x + radius * CGFloat(cos(angle)),
                y: center.y + radius * CGFloat(sin(angle))
            )
        }

        if edges.isEmpty { return positions }

        var adjacency: [Int: [Int]] = [:]
        for (a, b) in edges {
            adjacency[a, default: []].append(b)
            adjacency[b, default: []].append(a)
        }

        var depth = Array(repeating: -1, count: count)
        var queue: [Int] = []
        let start = adjacency.max(by: { $0.value.count < $1.value.count })?.key ?? 0
        depth[start] = 0
        queue.append(start)

        while !queue.isEmpty {
            let node = queue.removeFirst()
            for neighbor in adjacency[node] ?? [] where depth[neighbor] < 0 {
                depth[neighbor] = depth[node] + 1
                queue.append(neighbor)
            }
        }

        let maxDepth = depth.max() ?? 0
        for i in 0..<count where depth[i] < 0 {
            depth[i] = maxDepth + 1
        }

        var nodesPerLayer: [Int: Int] = [:]
        for layer in depth {
            nodesPerLayer[layer, default: 0] += 1
        }

        let layerRadius = radius * 0.55
        var layerCounts: [Int: Int] = [:]
        for i in 0..<count {
            let layer = depth[i]
            let slot = layerCounts[layer, default: 0]
            layerCounts[layer] = slot + 1
            let layerSize = nodesPerLayer[layer] ?? 1
            let angle = (Double(slot) / Double(max(layerSize, 1))) * 2 * .pi - .pi / 2
            let r = layer == 0 ? radius * 0.35 : layerRadius + CGFloat(layer) * (minDist * 0.55)
            positions[i] = CGPoint(
                x: center.x + r * CGFloat(cos(angle)),
                y: center.y + r * CGFloat(sin(angle))
            )
        }

        return positions
    }

    private static func undirectedPairKey(_ a: UUID, _ b: UUID) -> String {
        a.uuidString < b.uuidString ? "\(a.uuidString)|\(b.uuidString)" : "\(b.uuidString)|\(a.uuidString)"
    }

    private static func curveOffset(index: Int, count: Int, span: CGFloat) -> CGFloat {
        guard count > 1 else { return 28 }
        let center = CGFloat(count - 1) / 2
        return (CGFloat(index) - center) * (span / max(CGFloat(count - 1), 1))
    }

    private static func fanSpread(index: Int, count: Int, span: CGFloat) -> CGFloat {
        guard count > 1 else { return 0 }
        let center = CGFloat(count - 1) / 2
        return (CGFloat(index) - center) * (span / CGFloat(count - 1))
    }

    private static func fanIndex(
        edge: GraphSnapshot.Edge,
        bucket: [GraphSnapshot.Edge],
        nodesByID: [UUID: GraphSnapshot.Node],
        fromNodeID: UUID
    ) -> Int {
        let sorted = bucket.sorted { lhs, rhs in
            let otherL = lhs.sourceID == fromNodeID ? lhs.targetID : lhs.sourceID
            let otherR = rhs.sourceID == fromNodeID ? rhs.targetID : rhs.sourceID
            guard let nodeL = nodesByID[otherL], let nodeR = nodesByID[otherR] else { return lhs.id < rhs.id }
            let angleL = atan2(nodeL.position.y - nodesByID[fromNodeID]!.position.y, nodeL.position.x - nodesByID[fromNodeID]!.position.x)
            let angleR = atan2(nodeR.position.y - nodesByID[fromNodeID]!.position.y, nodeR.position.x - nodesByID[fromNodeID]!.position.x)
            return angleL < angleR
        }
        return sorted.firstIndex(where: { $0.id == edge.id }) ?? 0
    }

    private static func borderPoint(center: CGPoint, size: CGSize, angle: CGFloat) -> CGPoint {
        let dx = cos(angle)
        let dy = sin(angle)
        let halfW = size.width / 2
        let halfH = size.height / 2
        let scaleX = abs(dx) > 0.001 ? halfW / abs(dx) : .greatestFiniteMagnitude
        let scaleY = abs(dy) > 0.001 ? halfH / abs(dy) : .greatestFiniteMagnitude
        let scale = min(scaleX, scaleY)
        return CGPoint(x: center.x + dx * scale, y: center.y + dy * scale)
    }

    // Legacy straight segment (previews / tests)
    static func edgeSegment(
        from source: GraphSnapshot.Node,
        to target: GraphSnapshot.Node
    ) -> (start: CGPoint, end: CGPoint) {
        let angle = atan2(target.position.y - source.position.y, target.position.x - source.position.x)
        let start = borderPoint(center: source.position, size: source.size, angle: angle)
        let end = borderPoint(center: target.position, size: target.size, angle: angle + .pi)
        return (start, end)
    }
}
