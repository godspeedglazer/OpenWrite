import Foundation

/// Block-level Enter / Backspace semantics for the writing editor.
enum BlockKeyboardEditing {
    struct SplitResult: Sendable {
        let newBlockID: UUID
        let focusBlockID: UUID
    }

    struct MergeResult: Sendable {
        let focusBlockID: UUID
        let removedBlockID: UUID
    }

    /// Enter at cursor: same-kind block below; second half keeps attributes (font, callout, etc.).
    static func split(
        blocks: inout [NoteBlock],
        blockID: UUID,
        cursorOffset: Int
    ) -> SplitResult? {
        guard let index = blocks.firstIndex(where: { $0.id == blockID }) else { return nil }
        let source = blocks[index]
        guard source.kind != .divider, source.kind != .image, source.kind != .property else { return nil }

        let text = source.text
        let offset = min(max(cursorOffset, 0), (text as NSString).length)
        let ns = text as NSString
        let before = ns.substring(to: offset)
        let after = ns.substring(from: offset)

        var updated = source
        updated.text = before
        blocks[index] = updated

        let newKind: NoteBlock.Kind = after.isEmpty && before.isEmpty ? .paragraph : source.kind
        let newBlock = NoteBlock(
            kind: newKind,
            text: after,
            attributes: source.attributes
        )
        blocks.insert(newBlock, at: index + 1)
        return SplitResult(newBlockID: newBlock.id, focusBlockID: newBlock.id)
    }

    /// Backspace at column 0: merge into previous text block or delete empty row.
    static func mergeWithPrevious(
        blocks: inout [NoteBlock],
        blockID: UUID
    ) -> MergeResult? {
        guard let index = blocks.firstIndex(where: { $0.id == blockID }),
              index > 0 else { return nil }

        let current = blocks[index]
        guard current.kind != .divider, current.kind != .image, current.kind != .property else { return nil }

        if current.text.isEmpty {
            let removed = current.id
            blocks.remove(at: index)
            let focusID = blocks[min(index, blocks.count - 1)].id
            return MergeResult(focusBlockID: focusID, removedBlockID: removed)
        }

        var previous = blocks[index - 1]
        guard previous.kind != .divider, previous.kind != .image, previous.kind != .property else { return nil }

        let joiner = needsJoiner(between: previous.kind, and: current.kind) ? "\n" : ""
        previous.text += joiner + current.text
        blocks[index - 1] = previous
        let removed = current.id
        blocks.remove(at: index)
        return MergeResult(focusBlockID: previous.id, removedBlockID: removed)
    }

    private static func needsJoiner(between left: NoteBlock.Kind, and right: NoteBlock.Kind) -> Bool {
        switch (left, right) {
        case (.code, .code):
            return true
        default:
            return false
        }
    }
}
