import Foundation
import SwiftUI

// MARK: - Field kinds

/// Typed column in a universal database schema (massCode-inspired; clean-room Swift).
enum OWFieldKind: String, Codable, CaseIterable, Identifiable, Hashable, Sendable {
    case text
    case code
    case tags
    case date
    case url
    case number

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .text: return "Text"
        case .code: return "Code"
        case .tags: return "Tags"
        case .date: return "Date"
        case .url: return "URL"
        case .number: return "Number"
        }
    }
}

// MARK: - Field definition

struct OWDatabaseField: Identifiable, Codable, Hashable, Sendable {
    var id: UUID
    var key: String
    var label: String
    var kind: OWFieldKind
    /// Primary column shown as the row title in table views.
    var isPrimary: Bool
    var isRequired: Bool

    init(
        id: UUID = UUID(),
        key: String,
        label: String,
        kind: OWFieldKind,
        isPrimary: Bool = false,
        isRequired: Bool = false
    ) {
        self.id = id
        self.key = key
        self.label = label
        self.kind = kind
        self.isPrimary = isPrimary
        self.isRequired = isRequired
    }
}

// MARK: - Database definition

struct OWDatabase: Identifiable, Codable, Hashable, Sendable {
    var id: UUID
    var name: String
    var fields: [OWDatabaseField]
    /// `OWIcon` raw value for sidebar / header glyphs.
    var iconName: String
    /// Theme accent token name (maps to `OWDatabaseThemeTint`).
    var themeTint: String
    var createdAt: Date
    var updatedAt: Date
    var preset: DatabasePreset?

    init(
        id: UUID = UUID(),
        name: String,
        fields: [OWDatabaseField],
        iconName: String = OWIcon.database.rawValue,
        themeTint: String = OWDatabaseThemeTint.blue.rawValue,
        createdAt: Date = .now,
        updatedAt: Date = .now,
        preset: DatabasePreset? = nil
    ) {
        self.id = id
        self.name = name
        self.fields = fields
        self.iconName = iconName
        self.themeTint = themeTint
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.preset = preset
    }

    var icon: OWIcon {
        OWIcon(rawValue: iconName) ?? .database
    }

    var tint: OWDatabaseThemeTint {
        OWDatabaseThemeTint(rawValue: themeTint) ?? .blue
    }

    var primaryField: OWDatabaseField? {
        fields.first { $0.isPrimary } ?? fields.first
    }

    mutating func touchUpdatedAt() {
        updatedAt = .now
    }
}

// MARK: - Presets

enum DatabasePreset: String, Codable, CaseIterable, Identifiable, Sendable {
    case codeSnippets
    case bookmarks
    case readingList
    case custom

    var id: String { rawValue }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let raw = try container.decode(String.self)
        if raw == "contacts" {
            self = .readingList
        } else if let preset = DatabasePreset(rawValue: raw) {
            self = preset
        } else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Unknown database preset: \(raw)"
            )
        }
    }

    var displayName: String {
        switch self {
        case .codeSnippets: return "Code snippets"
        case .bookmarks: return "Bookmarks"
        case .readingList: return "Reading list"
        case .custom: return "Blank"
        }
    }

    var summary: String {
        switch self {
        case .codeSnippets:
            return "Title, language, tags, and a code body — for reusable snippets."
        case .bookmarks:
            return "Name, URL, tags, and notes for saved links."
        case .readingList:
            return "Title, author, URL, status, tags, and notes for books and articles."
        case .custom:
            return "Start with a single text column; add fields after creation."
        }
    }

    var defaultName: String {
        switch self {
        case .codeSnippets: return "Code snippets"
        case .bookmarks: return "Bookmarks"
        case .readingList: return "Reading list"
        case .custom: return "New database"
        }
    }

    var icon: OWIcon {
        switch self {
        case .codeSnippets: return .document
        case .bookmarks: return .link
        case .readingList: return .book
        case .custom: return .database
        }
    }

    var themeTint: OWDatabaseThemeTint {
        switch self {
        case .codeSnippets: return .green
        case .bookmarks: return .blue
        case .readingList: return .purple
        case .custom: return .neutral
        }
    }

    func makeDatabase(name: String? = nil) -> OWDatabase {
        let resolvedName = name?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
            ? name!.trimmingCharacters(in: .whitespacesAndNewlines)
            : defaultName
        return OWDatabase(
            name: resolvedName,
            fields: schemaFields(),
            iconName: icon.rawValue,
            themeTint: themeTint.rawValue,
            preset: self == .custom ? nil : self
        )
    }

    func schemaFields() -> [OWDatabaseField] {
        switch self {
        case .codeSnippets:
            return [
                OWDatabaseField(key: "title", label: "Title", kind: .text, isPrimary: true, isRequired: true),
                OWDatabaseField(key: "language", label: "Language", kind: .text),
                OWDatabaseField(key: "tags", label: "Tags", kind: .tags),
                OWDatabaseField(key: "body", label: "Code", kind: .code, isRequired: true)
            ]
        case .bookmarks:
            return [
                OWDatabaseField(key: "name", label: "Name", kind: .text, isPrimary: true, isRequired: true),
                OWDatabaseField(key: "url", label: "URL", kind: .url, isRequired: true),
                OWDatabaseField(key: "tags", label: "Tags", kind: .tags),
                OWDatabaseField(key: "notes", label: "Notes", kind: .text)
            ]
        case .readingList:
            return [
                OWDatabaseField(key: "title", label: "Title", kind: .text, isPrimary: true, isRequired: true),
                OWDatabaseField(key: "author", label: "Author", kind: .text),
                OWDatabaseField(key: "url", label: "URL", kind: .url),
                OWDatabaseField(key: "status", label: "Status", kind: .text),
                OWDatabaseField(key: "tags", label: "Tags", kind: .tags),
                OWDatabaseField(key: "notes", label: "Notes", kind: .text)
            ]
        case .custom:
            return [
                OWDatabaseField(key: "title", label: "Title", kind: .text, isPrimary: true, isRequired: true)
            ]
        }
    }
}

// MARK: - Theme tint

enum OWDatabaseThemeTint: String, Codable, CaseIterable, Identifiable, Sendable {
    case blue
    case green
    case purple
    case orange
    case neutral

    var id: String { rawValue }

    var displayName: String {
        rawValue.capitalized
    }

    var color: Color {
        switch self {
        case .blue: return DesignTokens.Color.accent
        case .green: return Color(red: 0.18, green: 0.62, blue: 0.42)
        case .purple: return Color(red: 0.52, green: 0.36, blue: 0.82)
        case .orange: return Color(red: 0.92, green: 0.48, blue: 0.22)
        case .neutral: return DesignTokens.Color.textSecondary
        }
    }
}
