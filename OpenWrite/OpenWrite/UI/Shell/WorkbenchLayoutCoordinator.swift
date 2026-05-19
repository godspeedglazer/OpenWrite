import CoreGraphics
import SwiftUI

// MARK: - Resolved center workbench geometry (single source of truth)

/// Pixel-stable layout for the center workbench (editor card + optional assist column).
/// Produced only from `WorkbenchLayoutCoordinator.resolve` — views must not invent parallel widths.
struct WorkbenchCenterLayout: Equatable {
    /// Full width of the center region inside the nav split (before outer card padding).
    let centerRegionWidth: CGFloat
    /// Width inside horizontal outer padding (editor + assist + split chrome).
    let paddedInnerWidth: CGFloat
    /// Editor column inside the padded card area (HStack slot).
    let editorColumnWidth: CGFloat
    /// Trailing assist column width (0 when collapsed).
    let assistColumnWidth: CGFloat
    /// Width of the elevated editor card (`OWRoundedRect`).
    let editorCardWidth: CGFloat
    /// Width for block text layout (card minus horizontal editor insets).
    let editorBodyWidth: CGFloat
    /// When false, chat composer uses the compact vertical action board.
    let assistUsesHorizontalComposer: Bool
}

// MARK: - Coordinator

enum WorkbenchLayoutCoordinator {
    /// Gutter between editor and assist divider plus the divider hit target.
    static var assistSplitChromeWidth: CGFloat {
        DesignTokens.Layout.shellColumnGutter + DesignTokens.Layout.splitDividerHitWidth
    }

    /// Resolves editor vs assist widths so columns never overlap and editor keeps ≥55% when assist is open.
    static func resolve(
        centerRegionWidth: CGFloat,
        assistExpanded: Bool,
        preferredAssistWidth: CGFloat
    ) -> WorkbenchCenterLayout {
        let outerPad = DesignTokens.Layout.centerCardOuterPadding
        let region = max(centerRegionWidth, 0)
        let inner = max(region - outerPad * 2, 0)
        let horizontalInset = DesignTokens.Layout.editorContentLeadingInset * 2

        guard assistExpanded, inner > 0 else {
            let card = inner
            let body = max(card - horizontalInset, 320)
            return WorkbenchCenterLayout(
                centerRegionWidth: region,
                paddedInnerWidth: inner,
                editorColumnWidth: inner,
                assistColumnWidth: 0,
                editorCardWidth: card,
                editorBodyWidth: body,
                assistUsesHorizontalComposer: true
            )
        }

        let chrome = assistSplitChromeWidth
        let editorFloor = max(
            DesignTokens.Layout.editorMinWidthWhenAssistOpen,
            inner * DesignTokens.Layout.editorMinWidthWhenAssistFraction
        )

        let assistCap = max(0, inner - editorFloor - chrome)
        let assistWidth: CGFloat
        if assistCap < DesignTokens.Layout.assistStripMinWidth {
            assistWidth = max(assistCap, 0)
        } else {
            let preferred = preferredAssistWidth.clamped(
                to: DesignTokens.Layout.assistStripMinWidth ... DesignTokens.Layout.assistStripMaxWidth
            )
            assistWidth = min(preferred, assistCap)
        }

        let chromeUsed = assistWidth > 0 ? chrome : 0
        var editorColumn = max(inner - assistWidth - chromeUsed, 0)
        if editorColumn < editorFloor, assistWidth > 0 {
            editorColumn = min(editorFloor, max(0, inner - chromeUsed - DesignTokens.Layout.assistStripMinWidth))
        }
        editorColumn = min(editorColumn, max(0, inner - chromeUsed - assistWidth))

        let card = editorColumn
        let body = max(card - horizontalInset, 320)
        let horizontalComposer = assistWidth >= DesignTokens.Layout.assistStripHorizontalComposerMinWidth

        return WorkbenchCenterLayout(
            centerRegionWidth: region,
            paddedInnerWidth: inner,
            editorColumnWidth: editorColumn,
            assistColumnWidth: assistWidth,
            editorCardWidth: card,
            editorBodyWidth: body,
            assistUsesHorizontalComposer: horizontalComposer
        )
    }

    /// When the center is too narrow for editor + assist minimums, collapse assist.
    static func shouldCollapseAssist(centerRegionWidth: CGFloat) -> Bool {
        let region = max(centerRegionWidth, 0)
        let inner = max(region - DesignTokens.Layout.centerCardOuterPadding * 2, 0)
        return inner < OWShellLayout.minimumCenterWidthForAssistOpen(forCenterWidth: inner)
    }
}

// MARK: - Environment

private struct WorkbenchCenterLayoutKey: EnvironmentKey {
    static let defaultValue = WorkbenchCenterLayout(
        centerRegionWidth: 0,
        paddedInnerWidth: 0,
        editorColumnWidth: 720,
        assistColumnWidth: 0,
        editorCardWidth: 720,
        editorBodyWidth: 672,
        assistUsesHorizontalComposer: true
    )
}

extension EnvironmentValues {
    var workbenchCenterLayout: WorkbenchCenterLayout {
        get { self[WorkbenchCenterLayoutKey.self] }
        set { self[WorkbenchCenterLayoutKey.self] = newValue }
    }
}

// MARK: - Assist column divider

struct WorkbenchAssistColumnDivider: View {
    @Binding var assistWidth: CGFloat
    let minWidth: CGFloat
    let maxWidth: CGFloat
    let availableWidth: CGFloat

    @State private var dragOriginWidth: CGFloat?
    @State private var isDragging = false

    var body: some View {
        Rectangle()
            .fill(Color.clear)
            .frame(width: DesignTokens.Layout.splitDividerHitWidth)
            .padding(.leading, DesignTokens.Layout.shellColumnGutter)
            .overlay(alignment: .center) {
                Rectangle()
                    .fill(
                        isDragging
                            ? DesignTokens.Color.accent.opacity(0.55)
                            : DesignTokens.Color.borderSubtle
                    )
                    .frame(width: DesignTokens.Layout.borderWidth)
                    .padding(.leading, DesignTokens.Layout.shellColumnGutter)
            }
            .contentShape(Rectangle())
            .onHover { hovering in
                if hovering {
                    NSCursor.resizeLeftRight.push()
                } else {
                    NSCursor.pop()
                }
            }
            .gesture(
                DragGesture(minimumDistance: 1)
                    .onChanged { value in
                        if dragOriginWidth == nil {
                            dragOriginWidth = assistWidth
                        }
                        isDragging = true
                        let origin = dragOriginWidth ?? assistWidth
                        let chrome = WorkbenchLayoutCoordinator.assistSplitChromeWidth
                        let editorMin = max(
                            DesignTokens.Layout.editorMinWidthWhenAssistOpen,
                            (availableWidth - chrome) * DesignTokens.Layout.editorMinWidthWhenAssistFraction
                        )
                        let cap = max(
                            minWidth,
                            min(maxWidth, availableWidth - editorMin - chrome)
                        )
                        assistWidth = (origin - value.translation.width).clamped(to: minWidth ... cap)
                    }
                    .onEnded { _ in
                        dragOriginWidth = nil
                        isDragging = false
                        ShellChromePreferences.assistStripWidth = assistWidth
                        NSCursor.pop()
                    }
            )
    }
}

private extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
