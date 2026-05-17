import Foundation

// MARK: - Field schema

/// A single typed property field on a page.
enum PagePropertyKey: String, Codable, CaseIterable, Identifiable, Hashable, Sendable {
    case title
    case status
    case dueDate
    case tags
    case url
    case rating
    case summary
    case assignee
    case priority
    case startedAt
    case completedAt
    case author
    case publishedAt
    case mood
    case location

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .title: return "Title"
        case .status: return "Status"
        case .dueDate: return "Due"
        case .tags: return "Tags"
        case .url: return "URL"
        case .rating: return "Rating"
        case .summary: return "Summary"
        case .assignee: return "Assignee"
        case .priority: return "Priority"
        case .startedAt: return "Started"
        case .completedAt: return "Completed"
        case .author: return "Author"
        case .publishedAt: return "Published"
        case .mood: return "Mood"
        case .location: return "Location"
        }
    }

    /// Which page types surface this field in the inspector.
    func isApplicable(to pageType: PageType) -> Bool {
        PageProperties.schema(for: pageType).contains(self)
    }
}

enum PagePropertyValue: Codable, Hashable, Sendable {
    case text(String)
    case date(Date)
    case tags([String])
    case rating(Int)
    case url(URL)

    var textRepresentation: String {
        switch self {
        case .text(let s): return s
        case .date(let d): return ISO8601DateFormatter.ndl.string(from: d)
        case .tags(let t): return t.joined(separator: ", ")
        case .rating(let n): return String(n)
        case .url(let u): return u.absoluteString
        }
    }

    init?(ndlPayload: String, for key: PagePropertyKey) {
        let trimmed = ndlPayload.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return nil }
        switch key {
        case .dueDate, .startedAt, .completedAt, .publishedAt:
            if let date = ISO8601DateFormatter.ndl.date(from: trimmed)
                ?? PageProperties.fallbackDateParser.date(from: trimmed) {
                self = .date(date)
            } else {
                self = .text(trimmed)
            }
        case .tags:
            let parts = trimmed.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
            self = .tags(parts.filter { !$0.isEmpty })
        case .rating:
            if let n = Int(trimmed), (1 ... 5).contains(n) {
                self = .rating(n)
            } else {
                self = .text(trimmed)
            }
        case .url:
            if let url = URL(string: trimmed), url.scheme != nil {
                self = .url(url)
            } else {
                self = .text(trimmed)
            }
        default:
            self = .text(trimmed)
        }
    }
}

/// Typed property bag for a vault page — Codable for encrypted `.owdoc` bundles.
struct PageProperties: Codable, Hashable, Sendable {
    var values: [PagePropertyKey: PagePropertyValue]

    init(values: [PagePropertyKey: PagePropertyValue] = [:]) {
        self.values = values
    }

    subscript(key: PagePropertyKey) -> PagePropertyValue? {
        get { values[key] }
        set {
            if let newValue {
                values[key] = newValue
            } else {
                values.removeValue(forKey: key)
            }
        }
    }

    func string(for key: PagePropertyKey) -> String {
        values[key]?.textRepresentation ?? ""
    }

    mutating func setText(_ text: String, for key: PagePropertyKey) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            values.removeValue(forKey: key)
        } else {
            values[key] = PagePropertyValue(ndlPayload: trimmed, for: key) ?? .text(trimmed)
        }
    }

    // MARK: Schema per page type

    static func schema(for pageType: PageType) -> [PagePropertyKey] {
        switch pageType {
        case .note:
            return [.title, .tags, .summary]
        case .task:
            return [.title, .status, .dueDate, .priority, .assignee, .tags]
        case .reference:
            return [.title, .url, .author, .publishedAt, .rating, .tags, .summary]
        case .journal:
            return [.title, .mood, .location, .tags, .startedAt]
        case .project:
            return [.title, .status, .dueDate, .priority, .assignee, .startedAt, .completedAt, .tags, .summary]
        case .book:
            return [.title, .author, .tags, .summary, .status]
        case .document:
            return [.title, .tags, .summary, .status]
        case .wikiSite:
            return [.title, .url, .tags, .summary]
        case .collection:
            return [.title, .tags, .summary]
        }
    }

    static func defaults(for pageType: PageType, title: String) -> PageProperties {
        var props = PageProperties()
        props[.title] = .text(title)
        switch pageType {
        case .task:
            props[.status] = .text(TaskStatus.todo.rawValue)
            props[.priority] = .text(Priority.medium.rawValue)
        case .project:
            props[.status] = .text(ProjectStatus.active.rawValue)
            props[.priority] = .text(Priority.medium.rawValue)
        case .reference:
            props[.rating] = .rating(3)
        case .journal:
            props[.mood] = .text("")
        case .book:
            props[.status] = .text(ProjectStatus.planning.rawValue)
        case .document:
            props[.status] = .text(ProjectStatus.active.rawValue)
        case .wikiSite:
            break
        case .collection:
            break
        case .note:
            break
        }
        return props
    }

    static let fallbackDateParser: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()
}

// MARK: - Shared enumerations for pickers

enum TaskStatus: String, CaseIterable, Identifiable, Sendable {
    case todo
    case inProgress = "in_progress"
    case done
    case blocked
    case cancelled

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .todo: return "To Do"
        case .inProgress: return "In Progress"
        case .done: return "Done"
        case .blocked: return "Blocked"
        case .cancelled: return "Cancelled"
        }
    }
}

enum ProjectStatus: String, CaseIterable, Identifiable, Sendable {
    case planning
    case active
    case onHold = "on_hold"
    case completed
    case archived

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .planning: return "Planning"
        case .active: return "Active"
        case .onHold: return "On Hold"
        case .completed: return "Completed"
        case .archived: return "Archived"
        }
    }
}

enum Priority: String, CaseIterable, Identifiable, Sendable {
    case low
    case medium
    case high
    case urgent

    var id: String { rawValue }

    var displayName: String { rawValue.capitalized }
}

extension ISO8601DateFormatter {
    static let ndl: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()
}
