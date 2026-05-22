import Foundation

/// Selection snapshot for inline refine; safe to pass across actors.
struct InlineSelectionSnapshot: Sendable, Equatable {
    let documentID: UUID
    let blockID: UUID?
    let selectedText: String
    /// Character range in the block's plain `text` when known; `location == NSNotFound` if unknown.
    let selectedRange: NSRange
}

/// Pure block-level refinement merge (testable without AppKit).
enum BlockRefinement {
    /// Replaces the captured selection in `blocks` with refined prose.
    static func apply(
        _ refinedText: String,
        snapshot: InlineSelectionSnapshot,
        blocks: inout [NoteBlock],
        fallbackBlockID: UUID? = nil
    ) -> Bool {
        let trimmed = refinedText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }

        let targetID = snapshot.blockID ?? fallbackBlockID
        guard let blockID = targetID,
              let index = blocks.firstIndex(where: { $0.id == blockID }) else { return false }

        var blockText = blocks[index].text
        let ns = blockText as NSString

        if snapshot.selectedRange.location != NSNotFound,
           snapshot.selectedRange.length > 0,
           NSMaxRange(snapshot.selectedRange) <= ns.length {
            let atRange = ns.substring(with: snapshot.selectedRange)
            if atRange == snapshot.selectedText {
                blockText = ns.replacingCharacters(in: snapshot.selectedRange, with: trimmed) as String
                blocks[index].text = blockText
                return true
            }
        }

        if let range = blockText.range(of: snapshot.selectedText) {
            blockText.replaceSubrange(range, with: trimmed)
        } else if let last = blockText.range(of: snapshot.selectedText, options: .backwards) {
            blockText.replaceSubrange(last, with: trimmed)
        } else {
            blockText = trimmed
        }
        blocks[index].text = blockText
        return true
    }
}
