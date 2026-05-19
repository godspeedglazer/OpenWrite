import SwiftUI

// MARK: - OWIcon

/// Legacy path-drawn icon vocabulary — **deprecated** in product UI.
/// Use `OWUnicodeIcon` / `OWUnicodeIconView` instead. See `docs/design/OWIcons.md`.
/// Stable raw-value IDs for persistence; render with `OWUnicodeIconView`, not `OWIconView`.
enum OWIcon: String, CaseIterable, Sendable {
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

  enum Rendering {
    case stroke
    case fill
  }

  var rendering: Rendering {
    switch self {
    case .statusDot, .starFilled, .warningFill, .micActive, .checkmarkCircle:
      return .fill
    default:
      return .stroke
    }
  }
}

// MARK: - View

@available(*, deprecated, message: "Use OWUnicodeIconView instead.")
struct OWIconView: View {
  let icon: OWIcon
  var size: CGFloat = 16
  var strokeWidth: CGFloat?
  var color: Color = DesignTokens.Color.textSecondary

  private var lineWidth: CGFloat {
    strokeWidth ?? max(1.25, size * 0.09)
  }

  var body: some View {
    Group {
      switch icon.rendering {
      case .stroke:
        OWIconShape(icon: icon)
          .stroke(
            color,
            style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round)
          )
      case .fill:
        OWIconShape(icon: icon)
          .fill(color)
      }
    }
    .frame(width: size, height: size)
    .accessibilityHidden(true)
  }
}

// MARK: - Label & empty state

struct OWLabel: View {
  let title: String
  let icon: OWIcon
  var iconSize: CGFloat = 14

  var body: some View {
    HStack(spacing: DesignTokens.Spacing.spacing1) {
      OWUnicodeIconView(icon: icon, size: iconSize)
      Text(title)
        .font(OWTypography.captionEmphasis)
    }
  }
}

/// Toolbar / action-bar control — OW Rect, not stadium pill.
struct OWToolbarActionButtonStyle: ButtonStyle {
  var isEnabled: Bool

  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .font(OWTypography.captionEmphasis)
      .foregroundStyle(isEnabled ? DesignTokens.Color.accent : DesignTokens.Color.textTertiary)
      .padding(.horizontal, DesignTokens.Spacing.spacing2)
      .padding(.vertical, DesignTokens.Spacing.spacing1)
      .background(
        isEnabled ? DesignTokens.Color.accentMuted : DesignTokens.Color.surfaceElevated,
        in: RoundedRectangle(cornerRadius: DesignTokens.Radius.owRect, style: .continuous)
      )
      .overlay {
        RoundedRectangle(cornerRadius: DesignTokens.Radius.owRect, style: .continuous)
          .strokeBorder(
            isEnabled ? DesignTokens.Color.accent.opacity(0.4) : DesignTokens.Color.borderHairline,
            lineWidth: DesignTokens.Layout.borderWidth
          )
      }
      .opacity(configuration.isPressed ? 0.88 : 1)
      .openWriteButtonKeyboardFocus(in: RoundedRectangle(cornerRadius: DesignTokens.Radius.owRect, style: .continuous))
  }
}

struct OWEmptyState: View {
  let title: String
  var icon: OWIcon
  var description: Text?

  var body: some View {
    VStack(spacing: DesignTokens.Spacing.spacing3) {
      OWUnicodeIconView(icon: icon, size: 40, color: DesignTokens.Color.textTertiary)
      Text(title)
        .font(OWTypography.captionEmphasis)
        .foregroundStyle(DesignTokens.Color.textPrimary)
      if let description {
        description
          .font(OWTypography.caption)
          .foregroundStyle(DesignTokens.Color.textSecondary)
          .multilineTextAlignment(.center)
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .padding()
  }
}

// MARK: - Shape

@available(*, deprecated, message: "Use OWUnicodeIconView instead.")
struct OWIconShape: Shape {
  let icon: OWIcon

  func path(in rect: CGRect) -> Path {
    let scale = min(rect.width, rect.height) / 24
    let offset = CGPoint(x: rect.midX - 12 * scale, y: rect.midY - 12 * scale)
    return icon.unitPath().applying(
      CGAffineTransform(translationX: offset.x, y: offset.y).scaledBy(x: scale, y: scale)
    )
  }
}

// MARK: - Domain mapping

extension PageType {
  var owIcon: OWIcon {
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
}

extension SidebarSection {
  var owIcon: OWIcon {
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
  var owIcon: OWIcon {
    switch self {
    case .editor: return .note
    case .agents: return .agent
    case .graph: return .graph
    case .database: return .database
    }
  }
}

extension InspectorTab {
  var owIcon: OWIcon {
    switch self {
    case .chat: return .chat
    case .related: return .related
    case .pastWrites: return .pastWrites
    }
  }
}

extension StructureTemplate {
  var owIcon: OWIcon {
    pageType.owIcon
  }
}

// MARK: - Unit paths (24×24)

private extension OWIcon {
  func unitPath() -> Path {
    switch self {
    case .note: return notePath()
    case .task: return taskPath()
    case .journal: return journalPath()
    case .project: return projectPath()
    case .reference, .link: return linkPath()
    case .collection: return collectionPath()
    case .book: return bookPath()
    case .document: return documentPath()
    case .wiki: return wikiPath()
    case .graph: return graphPath()
    case .search: return searchPath()
    case .settings: return settingsPath()
    case .lockShield: return lockShieldPath()
    case .plus: return plusPath()
    case .chevronRight: return chevronPath(right: true)
    case .chevronDown: return chevronPath(right: false)
    case .back: return chevronPath(right: true, mirrored: true)
    case .forward: return chevronPath(right: true, mirrored: false)
    case .chat: return chatPath()
    case .related: return relatedPath()
    case .pastWrites: return pastWritesPath()
    case .sparkles, .ai: return sparklesPath()
    case .collapseTrailing: return chevronPath(right: true)
    case .send: return sendPath()
    case .stop: return statusDotPath()
    case .mic: return micPath(filled: false)
    case .micActive: return micPath(filled: true)
    case .warning: return warningPath(filled: false)
    case .warningFill: return warningPath(filled: true)
    case .clock: return clockPath()
    case .statusDot: return statusDotPath()
    case .tag: return tagPath()
    case .sliders: return slidersPath()
    case .editCompose: return editComposePath()
    case .zoomOut: return zoomPath(plus: false)
    case .zoomIn: return zoomPath(plus: true)
    case .grid: return gridPath()
    case .database: return databasePath()
    case .publish: return publishPath()
    case .checkmark: return checkmarkPath()
    case .person, .agent: return personPath()
    case .checkmarkCircle: return checkmarkCirclePath()
    case .star: return starPath(filled: false)
    case .starFilled: return starPath(filled: true)
    case .waveform: return waveformPath()
    case .missingNote: return missingNotePath()
    case .notes: return notesPath()
    }
  }

  func notePath() -> Path {
    var p = Path()
    p.addRoundedRect(in: CGRect(x: 5, y: 3, width: 14, height: 18), cornerSize: CGSize(width: 2, height: 2))
    p.move(to: CGPoint(x: 8, y: 9))
    p.addLine(to: CGPoint(x: 16, y: 9))
    p.move(to: CGPoint(x: 8, y: 13))
    p.addLine(to: CGPoint(x: 16, y: 13))
    p.move(to: CGPoint(x: 8, y: 17))
    p.addLine(to: CGPoint(x: 13, y: 17))
    return p
  }

  func taskPath() -> Path {
    var p = Path()
    p.addEllipse(in: CGRect(x: 4, y: 4, width: 16, height: 16))
    p.move(to: CGPoint(x: 8, y: 12.5))
    p.addLine(to: CGPoint(x: 11, y: 15.5))
    p.addLine(to: CGPoint(x: 16.5, y: 9))
    return p
  }

  func journalPath() -> Path {
    var p = Path()
    p.addRoundedRect(in: CGRect(x: 5, y: 4, width: 14, height: 16), cornerSize: CGSize(width: 1.5, height: 1.5))
    p.move(to: CGPoint(x: 9, y: 4))
    p.addLine(to: CGPoint(x: 9, y: 20))
    p.move(to: CGPoint(x: 12, y: 9))
    p.addLine(to: CGPoint(x: 16, y: 9))
    p.move(to: CGPoint(x: 12, y: 13))
    p.addLine(to: CGPoint(x: 16, y: 13))
    return p
  }

  func projectPath() -> Path {
    var p = Path()
    p.move(to: CGPoint(x: 4, y: 9))
    p.addLine(to: CGPoint(x: 12, y: 9))
    p.addLine(to: CGPoint(x: 12, y: 6))
    p.addLine(to: CGPoint(x: 20, y: 6))
    p.addLine(to: CGPoint(x: 20, y: 19))
    p.addLine(to: CGPoint(x: 4, y: 19))
    p.closeSubpath()
    return p
  }

  func linkPath() -> Path {
    var p = Path()
    p.addArc(center: CGPoint(x: 9, y: 12), radius: 4, startAngle: .degrees(40), endAngle: .degrees(220), clockwise: false)
    p.addArc(center: CGPoint(x: 15, y: 12), radius: 4, startAngle: .degrees(-40), endAngle: .degrees(140), clockwise: true)
    return p
  }

  func collectionPath() -> Path {
    var p = Path()
    p.move(to: CGPoint(x: 4, y: 8))
    p.addLine(to: CGPoint(x: 20, y: 8))
    p.addLine(to: CGPoint(x: 20, y: 18))
    p.addLine(to: CGPoint(x: 4, y: 18))
    p.closeSubpath()
    p.move(to: CGPoint(x: 4, y: 11))
    p.addLine(to: CGPoint(x: 20, y: 11))
    p.move(to: CGPoint(x: 8, y: 14))
    p.addLine(to: CGPoint(x: 16, y: 14))
    return p
  }

  func bookPath() -> Path {
    var p = Path()
    p.addRoundedRect(in: CGRect(x: 4, y: 4, width: 7, height: 16), cornerSize: CGSize(width: 1, height: 1))
    p.addRoundedRect(in: CGRect(x: 13, y: 4, width: 7, height: 16), cornerSize: CGSize(width: 1, height: 1))
    p.move(to: CGPoint(x: 7.5, y: 4))
    p.addLine(to: CGPoint(x: 7.5, y: 20))
    p.move(to: CGPoint(x: 16.5, y: 4))
    p.addLine(to: CGPoint(x: 16.5, y: 20))
    return p
  }

  func documentPath() -> Path {
    var p = notePath()
    p.move(to: CGPoint(x: 8, y: 17))
    p.addLine(to: CGPoint(x: 16, y: 17))
    return p
  }

  func wikiPath() -> Path {
    var p = Path()
    p.addEllipse(in: CGRect(x: 4, y: 4, width: 16, height: 16))
    p.move(to: CGPoint(x: 12, y: 4))
    p.addLine(to: CGPoint(x: 12, y: 20))
    p.addEllipse(in: CGRect(x: 6, y: 9, width: 12, height: 6))
    return p
  }

  func graphPath() -> Path {
    var p = Path()
    let nodes = [CGPoint(x: 12, y: 5), CGPoint(x: 5, y: 18), CGPoint(x: 19, y: 18)]
    for pt in nodes {
      p.addEllipse(in: CGRect(x: pt.x - 2.5, y: pt.y - 2.5, width: 5, height: 5))
    }
    p.move(to: nodes[0])
    p.addLine(to: nodes[1])
    p.move(to: nodes[0])
    p.addLine(to: nodes[2])
    p.move(to: nodes[1])
    p.addLine(to: nodes[2])
    return p
  }

  func searchPath() -> Path {
    var p = Path()
    p.addEllipse(in: CGRect(x: 4, y: 4, width: 11, height: 11))
    p.move(to: CGPoint(x: 13.5, y: 13.5))
    p.addLine(to: CGPoint(x: 19.5, y: 19.5))
    return p
  }

  func settingsPath() -> Path {
    var p = Path()
    p.addEllipse(in: CGRect(x: 9, y: 9, width: 6, height: 6))
    for i in 0 ..< 6 {
      let angle = Double(i) * .pi / 3
      let inner = CGPoint(x: 12 + cos(angle) * 4.5, y: 12 + sin(angle) * 4.5)
      let outer = CGPoint(x: 12 + cos(angle) * 9, y: 12 + sin(angle) * 9)
      p.move(to: inner)
      p.addLine(to: outer)
    }
    return p
  }

  func lockShieldPath() -> Path {
    var p = Path()
    p.move(to: CGPoint(x: 12, y: 3))
    p.addLine(to: CGPoint(x: 19, y: 6))
    p.addLine(to: CGPoint(x: 19, y: 13))
    p.addQuadCurve(to: CGPoint(x: 12, y: 21), control: CGPoint(x: 19, y: 18))
    p.addQuadCurve(to: CGPoint(x: 5, y: 13), control: CGPoint(x: 5, y: 18))
    p.addLine(to: CGPoint(x: 5, y: 6))
    p.closeSubpath()
    p.addRoundedRect(in: CGRect(x: 9, y: 11, width: 6, height: 5), cornerSize: CGSize(width: 1, height: 1))
    p.move(to: CGPoint(x: 12, y: 11))
    p.addLine(to: CGPoint(x: 12, y: 9))
    p.addArc(center: CGPoint(x: 12, y: 9), radius: 2, startAngle: .degrees(180), endAngle: .degrees(0), clockwise: false)
    return p
  }

  func plusPath() -> Path {
    var p = Path()
    p.move(to: CGPoint(x: 12, y: 5))
    p.addLine(to: CGPoint(x: 12, y: 19))
    p.move(to: CGPoint(x: 5, y: 12))
    p.addLine(to: CGPoint(x: 19, y: 12))
    return p
  }

  func chevronPath(right: Bool, mirrored: Bool = false) -> Path {
    var p = Path()
    if right {
      p.move(to: CGPoint(x: 9, y: 6))
      p.addLine(to: CGPoint(x: 15, y: 12))
      p.addLine(to: CGPoint(x: 9, y: 18))
    } else {
      p.move(to: CGPoint(x: 6, y: 9))
      p.addLine(to: CGPoint(x: 12, y: 15))
      p.addLine(to: CGPoint(x: 18, y: 9))
    }
    if mirrored {
      return p.applying(CGAffineTransform(scaleX: -1, y: 1).translatedBy(x: 24, y: 0))
    }
    return p
  }

  func chatPath() -> Path {
    var p = Path()
    p.addRoundedRect(in: CGRect(x: 3, y: 4, width: 13, height: 10), cornerSize: CGSize(width: 2, height: 2))
    p.move(to: CGPoint(x: 6, y: 14))
    p.addLine(to: CGPoint(x: 6, y: 17))
    p.addLine(to: CGPoint(x: 9, y: 14))
    p.addRoundedRect(in: CGRect(x: 10, y: 8, width: 11, height: 9), cornerSize: CGSize(width: 2, height: 2))
    return p
  }

  func relatedPath() -> Path {
    var p = Path()
    p.addEllipse(in: CGRect(x: 4, y: 4, width: 16, height: 16))
    var link = linkPath()
    link = link.applying(CGAffineTransform(scaleX: 0.75, y: 0.75).translatedBy(x: 3, y: 3))
    p.addPath(link)
    return p
  }

  func pastWritesPath() -> Path {
    var p = Path()
    p.addEllipse(in: CGRect(x: 4, y: 4, width: 16, height: 16))
    p.move(to: CGPoint(x: 12, y: 12))
    p.addLine(to: CGPoint(x: 12, y: 8))
    p.move(to: CGPoint(x: 12, y: 12))
    p.addLine(to: CGPoint(x: 15.5, y: 14))
    p.move(to: CGPoint(x: 16, y: 16))
    p.addLine(to: CGPoint(x: 20, y: 20))
    p.addLine(to: CGPoint(x: 18, y: 20))
    p.addLine(to: CGPoint(x: 20, y: 18))
    return p
  }

  func sparklesPath() -> Path {
    var p = Path()
    for center in [CGPoint(x: 7, y: 7), CGPoint(x: 17, y: 6), CGPoint(x: 15, y: 16), CGPoint(x: 6, y: 15)] {
      p.move(to: CGPoint(x: center.x, y: center.y - 2.5))
      p.addLine(to: CGPoint(x: center.x, y: center.y + 2.5))
      p.move(to: CGPoint(x: center.x - 2.5, y: center.y))
      p.addLine(to: CGPoint(x: center.x + 2.5, y: center.y))
    }
    return p
  }

  func sendPath() -> Path {
    var p = Path()
    p.addEllipse(in: CGRect(x: 3, y: 3, width: 18, height: 18))
    p.move(to: CGPoint(x: 12, y: 16))
    p.addLine(to: CGPoint(x: 12, y: 7))
    p.move(to: CGPoint(x: 8.5, y: 10.5))
    p.addLine(to: CGPoint(x: 12, y: 7))
    p.addLine(to: CGPoint(x: 15.5, y: 10.5))
    return p
  }

  func micPath(filled: Bool) -> Path {
    var p = Path()
    if filled {
      p.addRoundedRect(in: CGRect(x: 9, y: 5, width: 6, height: 10), cornerSize: CGSize(width: 3, height: 3))
    } else {
      p.addRoundedRect(in: CGRect(x: 9, y: 5, width: 6, height: 10), cornerSize: CGSize(width: 3, height: 3))
    }
    p.move(to: CGPoint(x: 12, y: 15))
    p.addLine(to: CGPoint(x: 12, y: 18))
    p.move(to: CGPoint(x: 8, y: 18))
    p.addLine(to: CGPoint(x: 16, y: 18))
    p.move(to: CGPoint(x: 7, y: 11))
    p.addQuadCurve(to: CGPoint(x: 7, y: 13), control: CGPoint(x: 5, y: 12))
    p.move(to: CGPoint(x: 17, y: 11))
    p.addQuadCurve(to: CGPoint(x: 17, y: 13), control: CGPoint(x: 19, y: 12))
    return p
  }

  func warningPath(filled: Bool) -> Path {
    var p = Path()
    p.move(to: CGPoint(x: 12, y: 4))
    p.addLine(to: CGPoint(x: 20, y: 19))
    p.addLine(to: CGPoint(x: 4, y: 19))
    p.closeSubpath()
    if !filled {
      p.move(to: CGPoint(x: 12, y: 9))
      p.addLine(to: CGPoint(x: 12, y: 14))
      p.move(to: CGPoint(x: 12, y: 17))
      p.addEllipse(in: CGRect(x: 11.25, y: 16.25, width: 1.5, height: 1.5))
    }
    return p
  }

  func clockPath() -> Path {
    var p = Path()
    p.addEllipse(in: CGRect(x: 4, y: 4, width: 16, height: 16))
    p.move(to: CGPoint(x: 12, y: 12))
    p.addLine(to: CGPoint(x: 12, y: 8))
    p.move(to: CGPoint(x: 12, y: 12))
    p.addLine(to: CGPoint(x: 15.5, y: 14))
    return p
  }

  func statusDotPath() -> Path {
    Path(ellipseIn: CGRect(x: 10, y: 10, width: 4, height: 4))
  }

  func tagPath() -> Path {
    var p = Path()
    p.move(to: CGPoint(x: 5, y: 6))
    p.addLine(to: CGPoint(x: 14, y: 6))
    p.addLine(to: CGPoint(x: 19, y: 12))
    p.addLine(to: CGPoint(x: 14, y: 18))
    p.addLine(to: CGPoint(x: 5, y: 18))
    p.closeSubpath()
    p.addEllipse(in: CGRect(x: 7.5, y: 10.5, width: 3, height: 3))
    return p
  }

  func slidersPath() -> Path {
    var p = Path()
    for y in [8.0, 12.0, 16.0] {
      p.move(to: CGPoint(x: 5, y: y))
      p.addLine(to: CGPoint(x: 19, y: y))
    }
    p.addEllipse(in: CGRect(x: 9, y: 6.5, width: 3, height: 3))
    p.addEllipse(in: CGRect(x: 14, y: 10.5, width: 3, height: 3))
    p.addEllipse(in: CGRect(x: 8, y: 14.5, width: 3, height: 3))
    return p
  }

  func editComposePath() -> Path {
    var p = Path()
    p.addRoundedRect(in: CGRect(x: 4, y: 6, width: 14, height: 14), cornerSize: CGSize(width: 2, height: 2))
    p.move(to: CGPoint(x: 14, y: 6))
    p.addLine(to: CGPoint(x: 19, y: 11))
    p.move(to: CGPoint(x: 13, y: 8))
    p.addLine(to: CGPoint(x: 17, y: 12))
    return p
  }

  func zoomPath(plus: Bool) -> Path {
    var p = searchPath()
    if plus {
      p.move(to: CGPoint(x: 16, y: 16))
      p.addLine(to: CGPoint(x: 16, y: 20))
      p.move(to: CGPoint(x: 14, y: 18))
      p.addLine(to: CGPoint(x: 18, y: 18))
    } else {
      p.move(to: CGPoint(x: 14, y: 18))
      p.addLine(to: CGPoint(x: 18, y: 18))
    }
    return p
  }

  func gridPath() -> Path {
    var p = Path()
    for x in [8.0, 12.0, 16.0] {
      p.move(to: CGPoint(x: x, y: 5))
      p.addLine(to: CGPoint(x: x, y: 19))
    }
    for y in [8.0, 12.0, 16.0] {
      p.move(to: CGPoint(x: 5, y: y))
      p.addLine(to: CGPoint(x: 19, y: y))
    }
    return p
  }

  /// Lucide `database` — ellipse cap, side walls, mid band.
  func databasePath() -> Path {
    var p = Path()
    p.addEllipse(in: CGRect(x: 3, y: 2, width: 18, height: 6))
    p.move(to: CGPoint(x: 3, y: 5))
    p.addLine(to: CGPoint(x: 3, y: 19))
    p.addCurve(
      to: CGPoint(x: 21, y: 19),
      control1: CGPoint(x: 3, y: 22),
      control2: CGPoint(x: 21, y: 22)
    )
    p.addLine(to: CGPoint(x: 21, y: 5))
    p.move(to: CGPoint(x: 3, y: 12))
    p.addCurve(
      to: CGPoint(x: 21, y: 12),
      control1: CGPoint(x: 3, y: 15),
      control2: CGPoint(x: 21, y: 15)
    )
    return p
  }

  func publishPath() -> Path {
    var p = Path()
    p.addRoundedRect(in: CGRect(x: 5, y: 7, width: 14, height: 14), cornerSize: CGSize(width: 2, height: 2))
    p.move(to: CGPoint(x: 12, y: 16))
    p.addLine(to: CGPoint(x: 12, y: 4))
    p.move(to: CGPoint(x: 9, y: 7))
    p.addLine(to: CGPoint(x: 12, y: 4))
    p.addLine(to: CGPoint(x: 15, y: 7))
    return p
  }

  func checkmarkPath() -> Path {
    var p = Path()
    p.move(to: CGPoint(x: 5, y: 12.5))
    p.addLine(to: CGPoint(x: 10, y: 17.5))
    p.addLine(to: CGPoint(x: 19, y: 7))
    return p
  }

  func checkmarkCirclePath() -> Path {
    var p = Path()
    p.addEllipse(in: CGRect(x: 4, y: 4, width: 16, height: 16))
    p.move(to: CGPoint(x: 8, y: 12.5))
    p.addLine(to: CGPoint(x: 11, y: 15.5))
    p.addLine(to: CGPoint(x: 16.5, y: 9))
    return p
  }

  func personPath() -> Path {
    var p = Path()
    p.addEllipse(in: CGRect(x: 8.5, y: 4, width: 7, height: 7))
    p.move(to: CGPoint(x: 5, y: 20))
    p.addQuadCurve(to: CGPoint(x: 19, y: 20), control: CGPoint(x: 12, y: 14))
    return p
  }

  func starPath(filled: Bool) -> Path {
    var p = Path()
    var angle = -Double.pi / 2
    let step = Double.pi / 5
    var points: [CGPoint] = []
    for i in 0 ..< 10 {
      let radius = i.isMultiple(of: 2) ? 8.0 : 3.5
      points.append(CGPoint(x: 12 + cos(angle) * radius, y: 12 + sin(angle) * radius))
      angle += step
    }
    p.move(to: points[0])
    for pt in points.dropFirst() { p.addLine(to: pt) }
    p.closeSubpath()
    _ = filled
    return p
  }

  func waveformPath() -> Path {
    var p = Path()
    p.move(to: CGPoint(x: 3, y: 12))
    p.addCurve(to: CGPoint(x: 8, y: 8), control1: CGPoint(x: 4, y: 12), control2: CGPoint(x: 6, y: 8))
    p.addCurve(to: CGPoint(x: 12, y: 16), control1: CGPoint(x: 10, y: 8), control2: CGPoint(x: 11, y: 16))
    p.addCurve(to: CGPoint(x: 16, y: 7), control1: CGPoint(x: 13, y: 16), control2: CGPoint(x: 14, y: 7))
    p.addCurve(to: CGPoint(x: 21, y: 12), control1: CGPoint(x: 18, y: 7), control2: CGPoint(x: 20, y: 12))
    return p
  }

  func missingNotePath() -> Path {
    var p = notePath()
    p.move(to: CGPoint(x: 11, y: 15))
    p.addLine(to: CGPoint(x: 11, y: 16.5))
    p.move(to: CGPoint(x: 11, y: 18.5))
    p.addEllipse(in: CGRect(x: 10.25, y: 18, width: 1.5, height: 1.5))
    return p
  }

  func notesPath() -> Path {
    var p = Path()
    p.addRoundedRect(in: CGRect(x: 5, y: 3, width: 14, height: 18), cornerSize: CGSize(width: 2, height: 2))
    p.move(to: CGPoint(x: 8, y: 8))
    p.addLine(to: CGPoint(x: 16, y: 8))
    p.move(to: CGPoint(x: 8, y: 12))
    p.addLine(to: CGPoint(x: 16, y: 12))
    p.move(to: CGPoint(x: 8, y: 16))
    p.addLine(to: CGPoint(x: 13, y: 16))
    return p
  }
}
