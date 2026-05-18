import SwiftUI

// MARK: - OWUnicodeIcon

/// Unicode / open-character glyphs for OpenWrite UI — no SF Symbols, no custom Path strokes.
/// See `docs/design/OWIcons.md`.
enum OWUnicodeIcon: String, CaseIterable, Sendable {
  case note
  case task
  case journal
  case project
  case reference
  case collection
  case book
  case document
  case wiki
  case graph
  case search
  case settings
  case lockShield
  case plus
  case chevronRight
  case chevronDown
  case back
  case forward
  case chat
  case related
  case pastWrites
  case sparkles
  case send
  case stop
  case mic
  case micActive
  case link
  case warning
  case warningFill
  case clock
  case statusDot
  case tag
  case sliders
  case editCompose
  case zoomOut
  case zoomIn
  case grid
  case database
  case publish
  case checkmark
  case person
  case agent
  case collapseTrailing
  case checkmarkCircle
  case star
  case starFilled
  case waveform
  case missingNote
  case notes
  case ai

  var character: String {
    switch self {
    case .note: return "◆"
    case .task: return "✓"
    case .journal: return "◇"
    case .project: return "▣"
    case .reference: return "⧉"
    case .collection: return "⊞"
    case .book: return "▤"
    case .document: return "▢"
    // "◍" reads as a small globe/meridian — far clearer than the old "⌁" (electric arrow)
    // which rendered as gibberish in the chat composer's web-fetch toggle.
    case .wiki: return "◍"
    case .graph: return "◉"
    case .search: return "⌕"
    case .settings: return "⚙"
    case .lockShield: return "⌾"
    case .plus: return "+"
    case .chevronRight: return "›"
    case .chevronDown: return "▾"
    case .back: return "←"
    case .forward: return "→"
    case .chat: return "✉"
    case .related: return "⊛"
    case .pastWrites: return "⟲"
    case .sparkles: return "✦"
    case .send: return "↑"
    case .stop: return "■"
    case .mic: return "◌"
    case .micActive: return "●"
    case .link: return "⧉"
    case .warning, .warningFill: return "⚠"
    case .clock: return "◷"
    case .statusDot: return "●"
    case .tag: return "#"
    case .sliders: return "≡"
    case .editCompose: return "✎"
    case .zoomOut: return "−"
    case .zoomIn: return "+"
    case .grid: return "⊞"
    case .database: return "⊟"
    case .publish: return "↗"
    case .checkmark, .checkmarkCircle: return "✓"
    case .person: return "○"
    case .agent: return "◈"
    case .collapseTrailing: return "‹"
    case .star: return "☆"
    case .starFilled: return "★"
    case .waveform: return "〰"
    case .missingNote: return "?"
    case .notes: return "≡"
    case .ai: return "✦"
    }
  }

  var accessibilityLabel: String {
    switch self {
    case .note: return "Note"
    case .task: return "Task"
    case .journal: return "Journal"
    case .project: return "Project"
    case .reference: return "Reference"
    case .collection: return "Collection"
    case .book: return "Book"
    case .document: return "Document"
    case .wiki: return "Wiki"
    case .graph: return "Graph"
    case .search: return "Search"
    case .settings: return "Settings"
    case .lockShield: return "Lock"
    case .plus: return "Add"
    case .chevronRight: return "Next"
    case .chevronDown: return "Menu"
    case .back: return "Back"
    case .forward: return "Forward"
    case .chat: return "Chat"
    case .related: return "Related"
    case .pastWrites: return "Past writes"
    case .sparkles: return "AI"
    case .send: return "Send"
    case .stop: return "Stop"
    case .mic: return "Microphone"
    case .micActive: return "Recording"
    case .link: return "Link"
    case .warning, .warningFill: return "Warning"
    case .clock: return "Clock"
    case .statusDot: return "Status"
    case .tag: return "Tag"
    case .sliders: return "Settings"
    case .editCompose: return "Compose"
    case .zoomOut: return "Zoom out"
    case .zoomIn: return "Zoom in"
    case .grid: return "Grid"
    case .database: return "Database"
    case .publish: return "Publish"
    case .checkmark, .checkmarkCircle: return "Selected"
    case .person: return "Person"
    case .agent: return "Agent"
    case .collapseTrailing: return "Collapse"
    case .star: return "Star"
    case .starFilled: return "Star filled"
    case .waveform: return "Audio"
    case .missingNote: return "Missing note"
    case .notes: return "Notes"
    case .ai: return "AI"
    }
  }
}

// MARK: - View

struct OWUnicodeIconView: View {
  let character: String
  var size: CGFloat = 16
  var color: Color = DesignTokens.Color.textSecondary

  init(_ icon: OWUnicodeIcon, size: CGFloat = 16, color: Color = DesignTokens.Color.textSecondary) {
    character = icon.character
    self.size = size
    self.color = color
  }

  init(icon: OWIcon, size: CGFloat = 16, color: Color = DesignTokens.Color.textSecondary) {
    character = icon.unicodeCharacter
    self.size = size
    self.color = color
  }

  init(pageType: PageType, size: CGFloat = 16, color: Color = DesignTokens.Color.textSecondary) {
    character = pageType.unicodeCharacter
    self.size = size
    self.color = color
  }

  init(character: String, size: CGFloat = 16, color: Color = DesignTokens.Color.textSecondary) {
    self.character = character
    self.size = size
    self.color = color
  }

  var body: some View {
    Text(character)
      .font(.system(size: fontSize))
      .foregroundStyle(color)
      .frame(width: size, height: size)
      .minimumScaleFactor(0.6)
      .lineLimit(1)
      .multilineTextAlignment(.center)
      .accessibilityHidden(true)
  }

  private var fontSize: CGFloat {
    max(10, size * 0.72)
  }
}

// MARK: - Icon well

struct OWUnicodePageTypeIconWell: View {
  var icon: OWIcon?
  var unicodeIcon: OWUnicodeIcon?
  var pageType: PageType?
  var customCharacter: String?
  var size: CGFloat = DesignTokens.Layout.objectIconWellSize

  init(icon: OWIcon, pageType: PageType? = nil, size: CGFloat = DesignTokens.Layout.objectIconWellSize) {
    self.icon = icon
    self.pageType = pageType
    self.size = size
  }

  init(pageType: PageType, size: CGFloat = DesignTokens.Layout.objectIconWellSize) {
    self.pageType = pageType
    self.size = size
  }

  init(character: String, pageType: PageType? = nil, size: CGFloat = DesignTokens.Layout.objectIconWellSize) {
    customCharacter = character
    self.pageType = pageType
    self.size = size
  }

  private var glyphCharacter: String {
    if let customCharacter, !customCharacter.isEmpty { return customCharacter }
    if let pageType { return pageType.unicodeCharacter }
    if let icon { return icon.unicodeCharacter }
    if let unicodeIcon { return unicodeIcon.character }
    return OWUnicodeIcon.note.character
  }

  var body: some View {
    ZStack {
      RoundedRectangle(cornerRadius: wellCornerRadius, style: .continuous)
        .fill(wellBackground)
      OWUnicodeIconView(character: glyphCharacter, size: glyphSize, color: glyphColor)
    }
    .frame(width: size, height: size)
    .accessibilityHidden(true)
  }

  private var wellCornerRadius: CGFloat {
    size > DesignTokens.Layout.objectIconWellSize ? DesignTokens.Radius.medium : DesignTokens.Radius.small
  }

  private var glyphSize: CGFloat { size * 0.55 }

  private var glyphColor: Color {
    if let pageType {
      return DesignTokens.ObjectType.accent(for: pageType)
    }
    return DesignTokens.Color.accent
  }

  private var wellBackground: Color {
    if let pageType {
      return DesignTokens.ObjectType.wellBackground(for: pageType)
    }
    return DesignTokens.Color.accent.opacity(0.22)
  }
}

// MARK: - Domain mapping

extension PageType {
  var unicodeIcon: OWUnicodeIcon {
    switch self {
    case .note: return .note
    case .task: return .task
    case .reference: return .reference
    case .journal: return .journal
    case .project: return .project
    case .book: return .book
    case .document: return .document
    case .wikiSite: return .wiki
    case .collection: return .collection
    }
  }

  var unicodeCharacter: String { unicodeIcon.character }
}

extension OWIcon {
  var unicodeIcon: OWUnicodeIcon {
    OWUnicodeIcon(rawValue: rawValue) ?? .note
  }

  var unicodeCharacter: String { unicodeIcon.character }
}

extension SidebarSection {
  var unicodeIcon: OWUnicodeIcon {
    switch self {
    case .notes: return .notes
    case .graph: return .graph
    case .search: return .search
    case .ai: return .sparkles
    case .publish: return .publish
    }
  }
}

extension CenterWorkbenchTab {
  var unicodeIcon: OWUnicodeIcon {
    switch self {
    case .editor: return .note
    case .graph: return .graph
    case .database: return .database
    }
  }
}

extension InspectorTab {
  var unicodeIcon: OWUnicodeIcon {
    switch self {
    case .chat: return .chat
    case .related: return .related
    case .pastWrites: return .pastWrites
    }
  }
}

extension StructureTemplate {
  var unicodeIcon: OWUnicodeIcon { pageType.unicodeIcon }
}

// MARK: - Path-drawn glyphs
//
// Vector replacements for unicode characters that render too small or too unfamiliar at
// composer scale (the chat 2×2 toggle board). 1.5pt strokes scaled to size, .round caps —
// matches Lucide / Anytype simple-icon density and stays crisp at 16–24pt.

/// Magnifying glass — replaces unicode `⌕` for search affordances.
struct OWSearchGlyph: View {
    var size: CGFloat = 20
    var color: Color = DesignTokens.Color.textSecondary

    var body: some View {
        Canvas { context, canvasSize in
            let scale = min(canvasSize.width, canvasSize.height) / 24
            let stroke = max(1.4, 1.6 * scale)
            let lensCenter = CGPoint(x: 10 * scale, y: 10 * scale)
            let lensRadius = 6 * scale
            let lensRect = CGRect(
                x: lensCenter.x - lensRadius,
                y: lensCenter.y - lensRadius,
                width: lensRadius * 2,
                height: lensRadius * 2
            )
            context.stroke(
                Path(ellipseIn: lensRect),
                with: .color(color),
                style: StrokeStyle(lineWidth: stroke, lineCap: .round)
            )
            var handle = Path()
            handle.move(to: CGPoint(x: 14.5 * scale, y: 14.5 * scale))
            handle.addLine(to: CGPoint(x: 20 * scale, y: 20 * scale))
            context.stroke(
                handle,
                with: .color(color),
                style: StrokeStyle(lineWidth: stroke, lineCap: .round)
            )
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

/// Globe / web — replaces unicode `⌁` / `◍` for the chat composer's "fetch web pages" toggle.
struct OWGlobeGlyph: View {
    var size: CGFloat = 20
    var color: Color = DesignTokens.Color.textSecondary

    var body: some View {
        Canvas { context, canvasSize in
            let scale = min(canvasSize.width, canvasSize.height) / 24
            let stroke = max(1.3, 1.5 * scale)
            let style = StrokeStyle(lineWidth: stroke, lineCap: .round, lineJoin: .round)
            let center = CGPoint(x: 12 * scale, y: 12 * scale)
            let radius = 9 * scale

            let circle = CGRect(
                x: center.x - radius,
                y: center.y - radius,
                width: radius * 2,
                height: radius * 2
            )
            context.stroke(Path(ellipseIn: circle), with: .color(color), style: style)

            var equator = Path()
            equator.move(to: CGPoint(x: center.x - radius, y: center.y))
            equator.addLine(to: CGPoint(x: center.x + radius, y: center.y))
            context.stroke(equator, with: .color(color), style: style)

            let meridianRect = CGRect(
                x: center.x - radius * 0.45,
                y: center.y - radius,
                width: radius * 0.9,
                height: radius * 2
            )
            context.stroke(Path(ellipseIn: meridianRect), with: .color(color), style: style)
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}
