import CoreGraphics
import Foundation

/// Read-only graph snapshot for placeholder layout (E-06 shell).
struct GraphSnapshot: Sendable {
    struct Node: Identifiable, Sendable {
        let id: UUID
        let title: String
        let pageType: PageType
        let position: CGPoint
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
    static func makeSnapshot(
        documents: [VaultDocument],
        index: BacklinkIndex,
        selectedDocumentID: UUID?,
        canvasSize: CGSize
    ) -> GraphSnapshot {
        guard !documents.isEmpty else { return .empty }

        let linkedIDs = linkedDocumentIDs(documents: documents, index: index)
        let displayDocuments = documents.filter { linkedIDs.contains($0.id) || documents.count <= 12 }
        let nodesToLayout = displayDocuments.isEmpty ? documents : displayDocuments

        let center = CGPoint(x: canvasSize.width / 2, y: canvasSize.height / 2)
        let radius = max(120, min(canvasSize.width, canvasSize.height) * 0.32)
        let positions = circleLayout(count: nodesToLayout.count, center: center, radius: radius)

        let nodes: [GraphSnapshot.Node] = nodesToLayout.enumerated().map { offset, document in
            GraphSnapshot.Node(
                id: document.id,
                title: document.displayTitle,
                pageType: document.pageType,
                position: positions[offset],
                isSelected: document.id == selectedDocumentID
            )
        }

        let nodeIDs = Set(nodesToLayout.map(\.id))
        var edges: [GraphSnapshot.Edge] = []
        for document in nodesToLayout {
            for targetID in index.outlinks(from: document.id) where nodeIDs.contains(targetID) {
                let edgeID = "\(document.id.uuidString)->\(targetID.uuidString)"
                edges.append(GraphSnapshot.Edge(id: edgeID, sourceID: document.id, targetID: targetID))
            }
        }

        let isolatedCount = documents.count - linkedIDs.count
        return GraphSnapshot(nodes: nodes, edges: edges, isolatedCount: max(0, isolatedCount))
    }

    private static func linkedDocumentIDs(documents: [VaultDocument], index: BacklinkIndex) -> Set<UUID> {
        var ids = Set<UUID>()
        for document in documents {
            if !index.outlinks(from: document.id).isEmpty || !index.backlinks(to: document.id).isEmpty {
                ids.insert(document.id)
            }
        }
        return ids
    }

    private static func circleLayout(count: Int, center: CGPoint, radius: CGFloat) -> [CGPoint] {
        guard count > 0 else { return [] }
        if count == 1 { return [center] }

        return (0..<count).map { index in
            let angle = (Double(index) / Double(count)) * 2 * .pi - .pi / 2
            return CGPoint(
                x: center.x + radius * CGFloat(cos(angle)),
                y: center.y + radius * CGFloat(sin(angle))
            )
        }
    }
}
