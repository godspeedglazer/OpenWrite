import Foundation
import SwiftUI

/// Single mutation surface for note block lists in the editor (insert, image ingest, focus-aware placement).
enum BlockDocumentEditing {
    /// Index to insert after `focusID`, or append when focus is missing / unknown.
    static func insertionIndex(in blocks: [NoteBlock], after focusID: UUID?) -> Int {
        guard let focusID,
              let index = blocks.firstIndex(where: { $0.id == focusID }) else {
            return blocks.count
        }
        return index + 1
    }

    @discardableResult
    static func insert(
        _ block: NoteBlock,
        into blocks: inout [NoteBlock],
        after focusID: UUID?
    ) -> Int {
        let index = insertionIndex(in: blocks, after: focusID)
        blocks.insert(block, at: index)
        return index
    }

    /// Inserts a pending image row, saves from the pasteboard, then replaces or removes the placeholder.
    static func ingestImage(
        into blocks: Binding<[NoteBlock]>,
        after focusID: UUID?,
        vaultRoot: URL? = VaultLocationPreferences.resolvedVaultRootURL(),
        finalize: @escaping () async -> NoteBlock? = { await ImagePasteSupport.finalizePastedImage() },
        onSettled: (() -> Void)? = nil
    ) {
        guard ImagePasteSupport.shouldIngestImageFromPasteboard else { return }
        ingestImageBlock(
            into: blocks,
            after: focusID,
            finalize: finalize,
            onSettled: onSettled
        )
    }

    /// File picker / drag-drop — same placeholder flow as paste.
    static func ingestImageFile(
        at url: URL,
        into blocks: Binding<[NoteBlock]>,
        after focusID: UUID?,
        vaultRoot: URL? = VaultLocationPreferences.resolvedVaultRootURL(),
        onSettled: (() -> Void)? = nil
    ) {
        ingestImageBlock(
            into: blocks,
            after: focusID,
            finalize: { await ImagePasteSupport.finalizeImage(at: url, vaultRoot: vaultRoot) },
            onSettled: onSettled
        )
    }

    private static func ingestImageBlock(
        into blocks: Binding<[NoteBlock]>,
        after focusID: UUID?,
        finalize: @escaping () async -> NoteBlock?,
        onSettled: (() -> Void)? = nil
    ) {
        let placeholder = ImagePasteSupport.placeholderBlock()
        let blockID = placeholder.id
        var draft = blocks.wrappedValue
        insert(placeholder, into: &draft, after: focusID)
        blocks.wrappedValue = draft

        Task {
            let finalized = await finalize()
            await MainActor.run {
                var current = blocks.wrappedValue
                guard let index = current.firstIndex(where: { $0.id == blockID }) else {
                    onSettled?()
                    return
                }
                if let finalized {
                    current[index] = finalized
                } else {
                    current.remove(at: index)
                }
                blocks.wrappedValue = current
                onSettled?()
            }
        }
    }
}
