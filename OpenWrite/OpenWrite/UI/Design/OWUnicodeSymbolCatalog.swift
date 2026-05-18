import Foundation

// MARK: - OWUnicodeSymbolCatalog
//
// Curated single-scalar glyphs for page icons — system fonts only, no bundled assets.
// Monochrome symbols preferred; emoji tab is optional and slim.

enum OWUnicodeSymbolCatalog {

    struct Section: Identifiable, Sendable, Hashable {
        let id: String
        let title: String
        /// Single-character strings (one extended grapheme each).
        let symbols: [String]
    }

    enum PickerTab: String, CaseIterable, Identifiable, Sendable {
        case symbols = "Symbols"
        case emoji = "Emoji"
        var id: String { rawValue }
    }

    // MARK: Emoji (slim quick-pick)

    /// Curated emoji — Text-only rendering (no UIImage / asset generation).
    static let emojiQuickPick: [String] = [
        "📝", "✅", "📁", "📚", "🔖", "💡", "🎯", "⭐",
        "🌐", "📓", "🗂️", "📄", "🧠", "🔥", "❤️", "🎨",
        "📌", "🔗", "📊", "🗓️", "✨", "🚀", "🔔", "🏷️",
        "📎", "🗃️", "📋", "🧩", "🛠️", "⚙️", "🔒", "🔑",
        "🪄", "🤖", "🧬", "🫧", "💬", "📣", "🎧", "🎬",
        "📷", "🖼️", "🗺️", "🧭",
        "☀️", "🌙", "🌧️", "🌱", "🍀", "🐾", "☕", "🍎",
        "🏠", "🏢", "✈️", "🚗", "⚡", "💎", "🎁", "🏆"
    ]

    // MARK: Symbol sections

    static let sections: [Section] = [
        Section(id: "geometric", title: "Geometric", symbols: [
            "◆", "◇", "○", "●", "◎", "◉", "◯", "⬤", "⬜", "⬛",
            "□", "■", "▢", "▣", "▤", "▥", "▦", "▧", "▨", "▩",
            "▪", "▫", "▬", "▭", "▮", "▯", "◈", "◊", "⬡", "⬢",
            "⬣", "⬟", "⬠", "⬭", "⬮", "⬯", "⌑", "⌾", "⌿", "⍀"
        ]),
        Section(id: "triangles", title: "Triangles", symbols: [
            "△", "▲", "▽", "▼", "◁", "◀", "▷", "▶", "◃", "▸",
            "▹", "►", "◅", "◢", "◣", "◤", "◥", "⊿", "◬", "⏢"
        ]),
        Section(id: "stars", title: "Stars & marks", symbols: [
            "★", "☆", "✦", "✧", "✪", "✫", "✬", "✭", "✮", "✯",
            "✰", "⋆", "≛", "⁂", "※", "✱", "✲", "✳", "✴", "✵",
            "✶", "✷", "✸", "✹", "✺", "✻", "✼", "✽", "✾", "✿"
        ]),
        Section(id: "arrows", title: "Arrows", symbols: [
            "→", "←", "↑", "↓", "↔", "↕", "↖", "↗", "↘", "↙",
            "⇒", "⇐", "⇑", "⇓", "⇔", "⇕", "⇨", "⇦", "⇧", "⇩",
            "⟶", "⟵", "⟷", "⟹", "⟸", "⟺", "⟼", "⟽", "⟾", "⟿",
            "➔", "➜", "➝", "➞", "➟", "➠", "➡", "➢", "➣", "➤",
            "➥", "➦", "➧", "➨", "➩", "➪", "➫", "➬", "➭", "➮",
            "↩", "↪", "↫", "↬", "↭", "↮", "↯", "⤴", "⤵", "⤶",
            "⤷", "⤸", "⤹", "⤺", "⤻", "↰", "↱", "↲", "↳", "↴"
        ]),
        Section(id: "math", title: "Math", symbols: [
            "+", "−", "±", "×", "÷", "∓", "∔", "∕", "∞", "∂",
            "∇", "∆", "√", "∛", "∜", "∫", "∬", "∭", "∑", "∏",
            "≤", "≥", "≠", "≈", "≡", "≅", "≃", "≪", "≫", "∝",
            "∠", "∡", "∢", "°", "′", "″", "⊥", "∥", "∦", "∴",
            "∵", "∄", "∀", "∃", "∅", "∈", "∉", "∋", "∌", "⊂",
            "⊃", "⊆", "⊇", "∪", "∩", "⊕", "⊖", "⊗", "⊘", "⊙",
            "⊚", "⊛", "⊞", "⊟", "⊠", "⊡", "⊢", "⊨", "⊻", "¬",
            "∧", "∨", "½", "⅓", "¼", "¾", "⅛", "⅜", "⅝", "⅞"
        ]),
        Section(id: "greek", title: "Greek", symbols: [
            "α", "β", "γ", "δ", "ε", "ζ", "η", "θ", "ι", "κ",
            "λ", "μ", "ν", "ξ", "ο", "π", "ρ", "σ", "τ", "υ",
            "φ", "χ", "ψ", "ω", "Α", "Β", "Γ", "Δ", "Ε", "Ζ",
            "Η", "Θ", "Ι", "Κ", "Λ", "Μ", "Ν", "Ξ", "Ο", "Π",
            "Ρ", "Σ", "Τ", "Υ", "Φ", "Χ", "Ψ", "Ω"
        ]),
        Section(id: "letters", title: "Letters in shapes", symbols: [
            "Ⓐ", "Ⓑ", "Ⓒ", "Ⓓ", "Ⓔ", "Ⓕ", "Ⓖ", "Ⓗ", "Ⓘ", "Ⓙ",
            "Ⓚ", "Ⓛ", "Ⓜ", "Ⓝ", "Ⓞ", "Ⓟ", "Ⓠ", "Ⓡ", "Ⓢ", "Ⓣ",
            "Ⓤ", "Ⓥ", "Ⓦ", "Ⓧ", "Ⓨ", "Ⓩ", "ⓐ", "ⓑ", "ⓒ", "ⓓ",
            "ⓔ", "ⓕ", "ⓖ", "ⓗ", "ⓘ", "ⓙ", "ⓚ", "ⓛ", "ⓜ", "ⓝ",
            "ⓞ", "ⓟ", "ⓠ", "ⓡ", "ⓢ", "ⓣ", "ⓤ", "ⓥ", "ⓦ", "ⓧ",
            "ⓨ", "ⓩ"
        ]),
        Section(id: "numbers", title: "Numbers", symbols: [
            "⓪", "①", "②", "③", "④", "⑤", "⑥", "⑦", "⑧", "⑨",
            "⑩", "⑪", "⑫", "⑬", "⑭", "⑮", "⑯", "⑰", "⑱", "⑲",
            "⑳", "⓵", "⓶", "⓷", "⓸", "⓹", "⓺", "⓻", "⓼", "⓽",
            "⓾", "❶", "❷", "❸", "❹", "❺", "❻", "❼", "❽", "❾",
            "❿"
        ]),
        Section(id: "punctuation", title: "Punctuation & ornaments", symbols: [
            "•", "‣", "⁃", "◦", "․", "‥", "…", "·", "·", "‧",
            "–", "—", "―", "‒", "¶", "§", "†", "‡", "‖", "‗",
            "‚", "„", "‹", "›", "«", "»", "‘", "’", "“", "”",
            "′", "″", "‴", "⁁", "⁂", "⁎", "⁕", "⁜", "※", "⁘"
        ]),
        Section(id: "dingbats", title: "Dingbats", symbols: [
            "✁", "✂", "✃", "✄", "✆", "✇", "✈", "✉", "✎", "✏",
            "✐", "✑", "✒", "✓", "✔", "✕", "✖", "✗", "✘", "✙",
            "✚", "✛", "✜", "✝", "✞", "✟", "✠", "✡", "✢", "✣",
            "✤", "✥", "⌘", "⌥", "⇧", "⌃", "⌫", "⌦", "⎋", "⏎",
            "↵", "⌁", "⌂", "⌇", "⌈", "⌉", "⌊", "⌋", "⌌", "⌍"
        ]),
        Section(id: "technical", title: "Technical", symbols: [
            "⚙", "⚡", "⚗", "⚛", "⚠", "⚑", "⚐", "⚒", "⚓", "⚔",
            "⚕", "⚖", "⚜", "⌚", "⌛", "⏱", "⏲", "⏳", "⏸", "⏹",
            "⏺", "⏏", "⏯", "⎈", "⎇", "⎆", "⎄", "⎃", "⎁", "⎀",
            "⌗", "⌖", "⌕", "⌔", "⌓", "⌒", "⌜", "⌝", "⌞", "⌟",
            "⎔", "⎕", "⎖", "⎗", "⎘", "⎙", "⎚", "⎛", "⎜", "⎝"
        ]),
        Section(id: "nature", title: "Nature & weather", symbols: [
            "☀", "☁", "☂", "☃", "☄", "☇", "☈", "☉", "☊", "☋",
            "☌", "☍", "☎", "☏", "☐", "☑", "☒", "☓", "☔", "☕",
            "☘", "☙", "☚", "☛", "☜", "☝", "☞", "☟", "☠", "☡",
            "☢", "☣", "☤", "☥", "☦", "☧", "☨", "☩", "☪", "☫",
            "☬", "☭", "☮", "☯", "☰", "☱", "☲", "☳", "☴", "☵"
        ]),
        Section(id: "music", title: "Music", symbols: [
            "♩", "♪", "♫", "♬", "♭", "♮", "♯", "𝄞", "𝄢", "𝄪",
            "𝄫", "𝄬", "𝄭", "𝄮", "𝄯", "𝅝", "𝅗", "𝅘", "𝅙", "𝅚"
        ]),
        Section(id: "chess", title: "Chess", symbols: [
            "♔", "♕", "♖", "♗", "♘", "♙", "♚", "♛", "♜", "♝",
            "♞", "♟"
        ]),
        Section(id: "cards", title: "Cards & dice", symbols: [
            "♠", "♣", "♥", "♦", "♤", "♧", "♡", "♢", "⚀", "⚁",
            "⚂", "⚃", "⚄", "⚅", "⛀", "⛁", "⛂", "⛃", "⟐", "⟡"
        ]),
        Section(id: "currency", title: "Currency", symbols: [
            "¢", "£", "¤", "¥", "€", "₩", "₪", "₫", "₭", "₮",
            "₱", "₲", "₳", "₴", "₵", "₶", "₷", "₸", "₹", "₺",
            "₻", "₼", "₽", "₾", "₿", "＄", "￠", "￡", "￥", "￦"
        ]),
        Section(id: "misc", title: "Miscellaneous", symbols: [
            "⌁", "⌂", "⛨", "⛓", "⛭", "⛮", "⛯", "⛰", "⛱", "⛲",
            "⛴", "⛵", "⛶", "⛷", "⛸", "⛹", "⛺", "⛻", "⛼", "⛽",
            "⛾", "⛿", "⬀", "⬁", "⬂", "⬃", "⬄", "⬅", "⬆", "⬇",
            "⬈", "⬉", "⬊", "⬋", "⬌", "⬍", "⬎", "⬏", "⬐", "⬑",
            "⬒", "⬓", "⬔", "⬕", "⬖", "⬗", "⬘", "⬙", "⬚", "⬛"
        ])
    ]

    // MARK: Aggregates

    static var categoryTitles: [String] {
        sections.map(\.title)
    }

    static var symbolCount: Int {
        sections.reduce(0) { $0 + $1.symbols.count }
    }

    static var allSymbols: [String] {
        sections.flatMap(\.symbols)
    }

    // MARK: Filtering

    static func filteredSections(matching query: String) -> [Section] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return sections }
        let lower = trimmed.lowercased()

        return sections.compactMap { section in
            if section.title.lowercased().contains(lower) {
                return section
            }
            if sectionKeywords[section.id]?.contains(where: { $0.contains(lower) }) == true {
                return section
            }
            let matched = section.symbols.filter { symbol in
                symbol == trimmed || symbol.localizedCaseInsensitiveContains(trimmed)
            }
            guard !matched.isEmpty else { return nil }
            return Section(id: section.id, title: section.title, symbols: matched)
        }
    }

    static func filteredEmojis(matching query: String) -> [String] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return emojiQuickPick }
        return emojiQuickPick.filter { $0.contains(trimmed) }
    }

    /// Returns a single display character safe for persistence (one grapheme).
    /// First extended grapheme cluster (RTL-safe, emoji-safe).
    static func normalizedPick(_ raw: String) -> String? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let first = trimmed.first else { return nil }
        return String(first)
    }

    // Search aliases (category id → extra terms)
    private static let sectionKeywords: [String: [String]] = [
        "geometric": ["shape", "diamond", "square", "circle", "poly"],
        "triangles": ["triangle", "pointer", "caret"],
        "stars": ["star", "asterisk", "sparkle"],
        "arrows": ["arrow", "direction", "pointer"],
        "math": ["math", "equation", "logic", "calculus", "fraction"],
        "greek": ["greek", "alpha", "beta", "gamma", "lambda"],
        "letters": ["letter", "enclosed"],
        "numbers": ["number", "digit", "index"],
        "punctuation": ["punct", "ornament", "bullet", "dash"],
        "dingbats": ["dingbat", "check", "scissors", "mail"],
        "technical": ["tech", "gear", "settings", "clock", "media"],
        "nature": ["weather", "sun", "rain", "cloud"],
        "music": ["music", "note", "clef"],
        "chess": ["chess", "game"],
        "cards": ["card", "suit", "dice", "spade", "heart"],
        "currency": ["money", "dollar", "euro", "yen"],
        "misc": ["other", "misc"]
    ]
}
