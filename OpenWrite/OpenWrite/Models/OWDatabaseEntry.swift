import Foundation

// MARK: - Cell values

enum OWDatabaseValue: Codable, Hashable, Sendable {
    case text(String)
    case code(String)
    case tags([String])
    case date(Date)
    case url(String)
    case number(Double)

    static func empty(for kind: OWFieldKind) -> OWDatabaseValue {
        switch kind {
        case .text: return .text("")
        case .code: return .code("")
        case .tags: return .tags([])
        case .date: return .date(.now)
        case .url: return .url("")
        case .number: return .number(0)
        }
    }

    var displayString: String {
        switch self {
        case .text(let s), .code(let s), .url(let s):
            return s
        case .tags(let tags):
            return tags.joined(separator: ", ")
        case .date(let d):
            return OWDatabaseEntry.dateFormatter.string(from: d)
        case .number(let n):
            if n.rounded() == n {
                return String(Int(n))
            }
            return String(n)
        }
    }

    var isEffectivelyEmpty: Bool {
        switch self {
        case .text(let s), .code(let s), .url(let s):
            return s.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .tags(let tags):
            return tags.isEmpty
        case .number:
            return false
        case .date:
            return false
        }
    }
}

// MARK: - Row

/// A single row in a universal database.
struct OWDatabaseEntry: Identifiable, Codable, Hashable, Sendable {
    var id: UUID
    var databaseID: UUID
    /// Values keyed by `OWDatabaseField.id` uuid string.
    var values: [String: OWDatabaseValue]
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        databaseID: UUID,
        values: [String: OWDatabaseValue] = [:],
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.databaseID = databaseID
        self.values = values
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .none
        return f
    }()

    mutating func touchUpdatedAt() {
        updatedAt = .now
    }

    func value(for field: OWDatabaseField) -> OWDatabaseValue? {
        values[field.id.uuidString]
    }

    mutating func setValue(_ value: OWDatabaseValue, for field: OWDatabaseField) {
        values[field.id.uuidString] = value
        touchUpdatedAt()
    }

    func displayTitle(in database: OWDatabase) -> String {
        guard let primary = database.primaryField,
              let value = value(for: primary) else {
            return "Untitled"
        }
        let text = value.displayString.trimmingCharacters(in: .whitespacesAndNewlines)
        return text.isEmpty ? "Untitled" : text
    }

    static func emptyRow(for database: OWDatabase) -> OWDatabaseEntry {
        var values: [String: OWDatabaseValue] = [:]
        for field in database.fields {
            values[field.id.uuidString] = .empty(for: field.kind)
        }
        return OWDatabaseEntry(databaseID: database.id, values: values)
    }
}
