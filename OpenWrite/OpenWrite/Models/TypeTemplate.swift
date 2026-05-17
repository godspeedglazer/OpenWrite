import Foundation

/// Default block layouts per page type — clean-room Anytype-style starter layouts.
struct TypeTemplate: Identifiable, Hashable, Sendable {
    var id: PageType { pageType }
    let pageType: PageType
    let suggestedTitle: String
    let rootBlocks: [NoteBlock]
    let properties: PageProperties

    static func template(for pageType: PageType, title: String? = nil) -> TypeTemplate {
        let suggested = title ?? pageType.displayName
        switch pageType {
        case .note:
            return noteTemplate(title: suggested)
        case .task:
            return taskTemplate(title: suggested)
        case .reference:
            return referenceTemplate(title: suggested)
        case .journal:
            return journalTemplate(title: suggested)
        case .project:
            return projectTemplate(title: suggested)
        }
    }

    static func allBuiltIn() -> [TypeTemplate] {
        PageType.allCases.map { template(for: $0) }
    }

    // MARK: - Per-type layouts

    private static func noteTemplate(title: String) -> TypeTemplate {
        TypeTemplate(
            pageType: .note,
            suggestedTitle: title,
            rootBlocks: [
                NoteBlock(kind: .heading1, text: title),
                NoteBlock(kind: .paragraph, text: "Capture ideas, drafts, and free-form writing."),
                NoteBlock(kind: .bullet, text: "Local-only — your vault never leaves this Mac"),
                NoteBlock(kind: .divider, text: ""),
                NoteBlock(kind: .paragraph, text: "")
            ],
            properties: PageProperties.defaults(for: .note, title: title)
        )
    }

    private static func taskTemplate(title: String) -> TypeTemplate {
        TypeTemplate(
            pageType: .task,
            suggestedTitle: title,
            rootBlocks: [
                NoteBlock(kind: .heading2, text: "Description"),
                NoteBlock(kind: .paragraph, text: "What needs to be done?"),
                NoteBlock(kind: .heading3, text: "Checklist"),
                NoteBlock(kind: .bullet, text: "First step"),
                NoteBlock(kind: .bullet, text: "Second step")
            ],
            properties: PageProperties.defaults(for: .task, title: title)
        )
    }

    private static func referenceTemplate(title: String) -> TypeTemplate {
        TypeTemplate(
            pageType: .reference,
            suggestedTitle: title,
            rootBlocks: [
                NoteBlock(kind: .heading1, text: title),
                NoteBlock(kind: .paragraph, text: "Source material and citations."),
                NoteBlock(kind: .quote, text: "Pull quotes or excerpts go here."),
                NoteBlock(kind: .heading3, text: "Notes"),
                NoteBlock(kind: .paragraph, text: "")
            ],
            properties: PageProperties.defaults(for: .reference, title: title)
        )
    }

    private static func journalTemplate(title: String) -> TypeTemplate {
        let dayTitle = title == PageType.journal.displayName
            ? journalDayTitle()
            : title
        return TypeTemplate(
            pageType: .journal,
            suggestedTitle: dayTitle,
            rootBlocks: [
                NoteBlock(kind: .heading1, text: dayTitle),
                NoteBlock(kind: .paragraph, text: "Today I…"),
                NoteBlock(kind: .heading3, text: "Gratitude"),
                NoteBlock(kind: .bullet, text: ""),
                NoteBlock(kind: .heading3, text: "Reflection"),
                NoteBlock(kind: .paragraph, text: "")
            ],
            properties: PageProperties.defaults(for: .journal, title: dayTitle)
        )
    }

    private static func projectTemplate(title: String) -> TypeTemplate {
        TypeTemplate(
            pageType: .project,
            suggestedTitle: title,
            rootBlocks: [
                NoteBlock(kind: .heading1, text: title),
                NoteBlock(kind: .paragraph, text: "Outcome and scope for this project."),
                NoteBlock(kind: .heading2, text: "Milestones"),
                NoteBlock(kind: .bullet, text: "Kickoff"),
                NoteBlock(kind: .bullet, text: "Ship"),
                NoteBlock(kind: .heading2, text: "Resources"),
                NoteBlock(kind: .wikilink, text: "Related notes")
            ],
            properties: PageProperties.defaults(for: .project, title: title)
        )
    }

    private static func journalDayTitle() -> String {
        let f = DateFormatter()
        f.dateStyle = .long
        f.timeStyle = .none
        return f.string(from: .now)
    }
}
