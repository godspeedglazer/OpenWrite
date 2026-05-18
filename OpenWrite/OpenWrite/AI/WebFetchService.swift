import Foundation
import os

// MARK: - Models

struct WebPageSnapshot: Sendable, Hashable {
    let url: URL
    let finalURL: URL
    let title: String?
    let text: String
}

enum WebFetchError: Error, LocalizedError, Sendable {
    case disabled
    case invalidURL
    case blockedScheme
    case blockedHost
    case blockedPrivateNetwork
    case notOnAllowlist
    case unsupportedContentType
    case responseTooLarge
    case httpStatus(Int)
    case timeout
    case emptyBody
    case redirectLimitExceeded

    var errorDescription: String? {
        switch self {
        case .disabled:
            return "Web lookup is turned off for this chat."
        case .invalidURL:
            return "That link is not a valid web address."
        case .blockedScheme:
            return "Only secure HTTPS links can be fetched."
        case .blockedHost:
            return "That host is not allowed for web lookup."
        case .blockedPrivateNetwork:
            return "Private or local network addresses cannot be fetched."
        case .notOnAllowlist:
            return "That domain is not on your web allowlist."
        case .unsupportedContentType:
            return "That page type cannot be converted to text."
        case .responseTooLarge:
            return "The page is larger than the safe fetch limit."
        case .httpStatus(let code):
            return "The server returned HTTP \(code)."
        case .timeout:
            return "The page took too long to load."
        case .emptyBody:
            return "The page had no readable text."
        case .redirectLimitExceeded:
            return "Too many redirects while loading the page."
        }
    }
}

// MARK: - URL extraction

enum WebURLExtractor {
  private static let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)

    /// Pulls http(s) links from user text (including bare URLs and @https://… mentions).
    static func extract(from text: String, maxCount: Int = AISafetyLimits.maxWebURLsPerMessage) -> [URL] {
        var found: [URL] = []
        var seen = Set<String>()

        func append(_ raw: String) {
            let trimmed = raw.trimmingCharacters(in: CharacterSet(charactersIn: "<>\"'()[]{}.,;"))
            guard let url = URL(string: trimmed),
                  let scheme = url.scheme?.lowercased(),
                  scheme == "https" || (scheme == "http" && WebFetchPolicy.permitsInsecureHTTP(for: url))
            else { return }
            let key = url.absoluteString
            guard seen.insert(key).inserted else { return }
            found.append(url)
        }

        if let detector {
            let range = NSRange(text.startIndex..., in: text)
            detector.enumerateMatches(in: text, options: [], range: range) { match, _, _ in
                guard found.count < maxCount,
                      let match,
                      let url = match.url
                else { return }
                append(url.absoluteString)
            }
        }

        // Mention-style @https://example.com
        let mentionPattern = #"@((?:https?)://[^\s]+)"#
        if let regex = try? NSRegularExpression(pattern: mentionPattern) {
            let range = NSRange(text.startIndex..., in: text)
            regex.enumerateMatches(in: text, range: range) { match, _, _ in
                guard found.count < maxCount,
                      let match,
                      match.numberOfRanges > 1,
                      let capture = Range(match.range(at: 1), in: text)
                else { return }
                append(String(text[capture]))
            }
        }

        return Array(found.prefix(maxCount))
    }
}

// MARK: - Policy

enum WebFetchPolicy {
    private static let logger = Logger(subsystem: "com.openwrite.ai", category: "WebFetch")

    static let allowlistDefaultsKey = "com.openwrite.web.domainAllowlist"

    static func permitsInsecureHTTP(for url: URL) -> Bool {
        #if DEBUG
        guard let host = url.host?.lowercased() else { return false }
        return host == "localhost" || host == "127.0.0.1" || host == "::1"
        #else
        return false
        #endif
    }

    static func validate(_ url: URL) throws {
        guard let scheme = url.scheme?.lowercased() else {
            throw WebFetchError.invalidURL
        }
        switch scheme {
        case "https":
            break
        case "http":
            guard permitsInsecureHTTP(for: url) else {
                throw WebFetchError.blockedScheme
            }
        default:
            throw WebFetchError.blockedScheme
        }

        guard let host = url.host?.lowercased(), !host.isEmpty else {
            throw WebFetchError.invalidURL
        }

        if host == "localhost" || host.hasSuffix(".localhost") {
            throw WebFetchError.blockedPrivateNetwork
        }

        if let allowlist = domainAllowlist(), !allowlist.isEmpty {
            guard allowlist.contains(where: { host == $0 || host.hasSuffix(".\($0)") }) else {
                throw WebFetchError.notOnAllowlist
            }
        }

        if isBlockedLiteralHost(host) {
            throw WebFetchError.blockedPrivateNetwork
        }

        if let addresses = try? resolveHostAddresses(host) {
            for address in addresses where isPrivateOrReserved(address) {
                throw WebFetchError.blockedPrivateNetwork
            }
        }
    }

    static func logFetchStarted(host: String) {
        logger.info("web_fetch_start host=\(host, privacy: .public)")
    }

    static func logFetchFinished(host: String, byteCount: Int) {
        logger.info("web_fetch_done host=\(host, privacy: .public) bytes=\(byteCount, privacy: .public)")
    }

    static func logFetchFailed(host: String, reason: String) {
        logger.warning("web_fetch_fail host=\(host, privacy: .public) reason=\(reason, privacy: .public)")
    }

    private static func domainAllowlist() -> [String]? {
        let raw = UserDefaults.standard.string(forKey: allowlistDefaultsKey)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard let raw, !raw.isEmpty else { return nil }
        return raw
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
            .filter { !$0.isEmpty }
    }

    private static func isBlockedLiteralHost(_ host: String) -> Bool {
        let blocked = [
            "0.0.0.0",
            "127.0.0.1",
            "::1",
            "metadata.google.internal",
            "169.254.169.254"
        ]
        if blocked.contains(host) { return true }
        if host.hasPrefix("127.") { return true }
        if host.hasPrefix("10.") { return true }
        if host.hasPrefix("192.168.") { return true }
        if host.hasPrefix("169.254.") { return true }
        if host.hasPrefix("fe80:") || host.hasPrefix("fc") || host.hasPrefix("fd") { return true }
        if host.contains(":"), host.split(separator: ":").count > 2 {
            // IPv6 literals
            if host.hasPrefix("::ffff:") {
                let v4 = String(host.dropFirst("::ffff:".count))
                return isBlockedLiteralHost(v4)
            }
        }
        if host.hasPrefix("172.") {
            let parts = host.split(separator: ".")
            if parts.count >= 2, let second = Int(parts[1]), (16 ... 31).contains(second) {
                return true
            }
        }
        return false
    }

    private static func resolveHostAddresses(_ host: String) throws -> [Data] {
        var hints = addrinfo()
        hints.ai_family = AF_UNSPEC
        hints.ai_socktype = SOCK_STREAM
        var result: UnsafeMutablePointer<addrinfo>?
        let status = getaddrinfo(host, nil, &hints, &result)
        guard status == 0, let result else {
            if status != 0 { throw WebFetchError.blockedHost }
            return []
        }
        defer { freeaddrinfo(result) }

        var addresses: [Data] = []
        var cursor: UnsafeMutablePointer<addrinfo>? = result
        while let node = cursor?.pointee {
            if let addr = node.ai_addr {
                let length = Int(node.ai_addrlen)
                addresses.append(Data(bytes: addr, count: length))
            }
            cursor = node.ai_next
        }
        return addresses
    }

    private static func isPrivateOrReserved(_ addressData: Data) -> Bool {
        guard addressData.count >= 4 else { return false }
        return addressData.withUnsafeBytes { raw -> Bool in
            guard let base = raw.baseAddress else { return false }
            if addressData.count == 4 {
                let bytes = base.assumingMemoryBound(to: UInt8.self)
                let b0 = bytes[0]
                let b1 = bytes[1]
                if b0 == 10 { return true }
                if b0 == 127 { return true }
                if b0 == 169 && b1 == 254 { return true }
                if b0 == 192 && b1 == 168 { return true }
                if b0 == 172 && (16 ... 31).contains(b1) { return true }
                if b0 == 0 { return true }
                return false
            }
            if addressData.count == 16 {
                let bytes = base.assumingMemoryBound(to: UInt8.self)
                if bytes[0] == 0xfe && (bytes[1] & 0xc0) == 0x80 { return true }
                if (bytes[0] & 0xfe) == 0xfc { return true }
                let mapped = (0 ..< 10).allSatisfy { bytes[$0] == 0 } && bytes[10] == 0xff && bytes[11] == 0xff
                if mapped {
                    let b0 = bytes[12]
                    let b1 = bytes[13]
                    if b0 == 10 { return true }
                    if b0 == 127 { return true }
                    if b0 == 169 && b1 == 254 { return true }
                    if b0 == 192 && b1 == 168 { return true }
                    if b0 == 172 && (16 ... 31).contains(b1) { return true }
                }
            }
            return false
        }
    }
}

// MARK: - HTML → text

enum HTMLTextExtractor {
    static func plainText(from html: String, maxChars: Int) -> String {
        var work = html
        let patterns = [
            "(?is)<script[^>]*>.*?</script>",
            "(?is)<style[^>]*>.*?</style>",
            "(?is)<noscript[^>]*>.*?</noscript>",
            "(?is)<!--.*?-->"
        ]
        for pattern in patterns {
            work = work.replacingOccurrences(
                of: pattern,
                with: " ",
                options: .regularExpression
            )
        }
        work = work.replacingOccurrences(of: "(?is)<br\\s*/?>", with: "\n", options: .regularExpression)
        work = work.replacingOccurrences(of: "(?is)</p>", with: "\n\n", options: .regularExpression)
        work = work.replacingOccurrences(of: "(?is)<[^>]+>", with: " ", options: .regularExpression)
        work = decodeBasicEntities(work)
        let collapsed = work
            .replacingOccurrences(of: #"[ \t]{2,}"#, with: " ", options: .regularExpression)
            .replacingOccurrences(of: #"\n{3,}"#, with: "\n\n", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if collapsed.count <= maxChars { return collapsed }
        return String(collapsed.prefix(max(0, maxChars - 3))) + "..."
    }

    static func parseTitle(from html: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: "(?is)<title[^>]*>(.*?)</title>") else {
            return nil
        }
        let range = NSRange(html.startIndex..., in: html)
        guard let match = regex.firstMatch(in: html, range: range),
              let capture = Range(match.range(at: 1), in: html)
        else { return nil }
        let title = String(html[capture])
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return title.isEmpty ? nil : title
    }

    private static func decodeBasicEntities(_ text: String) -> String {
        text
            .replacingOccurrences(of: "&nbsp;", with: " ")
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#39;", with: "'")
    }
}

// MARK: - Service

struct WebFetchService: Sendable {
    private let session: URLSession

    init(session: URLSession? = nil) {
        if let session {
            self.session = session
        } else {
            let configuration = URLSessionConfiguration.ephemeral
            configuration.timeoutIntervalForRequest = AISafetyLimits.webFetchTimeoutSeconds
            configuration.timeoutIntervalForResource = AISafetyLimits.webFetchTimeoutSeconds
            configuration.waitsForConnectivity = false
            configuration.httpShouldSetCookies = false
            configuration.httpCookieAcceptPolicy = .never
            self.session = URLSession(configuration: configuration)
        }
    }

    func fetchPages(urls: [URL]) async -> [WebPageSnapshot] {
        var snapshots: [WebPageSnapshot] = []
        for url in urls {
            let host = url.host ?? url.absoluteString
            do {
                let page = try await fetchPage(url: url)
                WebFetchPolicy.logFetchFinished(host: host, byteCount: page.text.utf8.count)
                snapshots.append(page)
            } catch {
                let reason = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
                WebFetchPolicy.logFetchFailed(host: host, reason: String(reason.prefix(120)))
            }
        }
        return snapshots
    }

    func fetchPage(url: URL) async throws -> WebPageSnapshot {
        try WebFetchPolicy.validate(url)
        let host = url.host ?? "unknown"
        WebFetchPolicy.logFetchStarted(host: host)

        var current = url
        var redirectCount = 0
        while true {
            try WebFetchPolicy.validate(current)
            var request = URLRequest(url: current)
            request.httpMethod = "GET"
            request.timeoutInterval = AISafetyLimits.webFetchTimeoutSeconds
            request.setValue("text/html, text/plain;q=0.9, */*;q=0.1", forHTTPHeaderField: "Accept")
            request.setValue("OpenWrite/1.0 (safe-fetch)", forHTTPHeaderField: "User-Agent")

            let (data, response) = try await downloadCapped(request: request)
            guard let http = response as? HTTPURLResponse else {
                throw WebFetchError.invalidURL
            }

            if (300 ..< 400).contains(http.statusCode), let location = http.value(forHTTPHeaderField: "Location") {
                redirectCount += 1
                guard redirectCount <= AISafetyLimits.webFetchMaxRedirects else {
                    throw WebFetchError.redirectLimitExceeded
                }
                guard let next = URL(string: location, relativeTo: current)?.absoluteURL else {
                    throw WebFetchError.invalidURL
                }
                current = next
                continue
            }

            guard (200 ..< 300).contains(http.statusCode) else {
                throw WebFetchError.httpStatus(http.statusCode)
            }

            let mime = (http.value(forHTTPHeaderField: "Content-Type") ?? "text/html")
                .split(separator: ";").first.map(String.init)?
                .lowercased() ?? "text/html"
            guard mime.hasPrefix("text/html")
                || mime.hasPrefix("text/plain")
                || mime.contains("application/xhtml")
            else {
                throw WebFetchError.unsupportedContentType
            }

            let charset = Self.parseCharset(from: http.value(forHTTPHeaderField: "Content-Type"))
            let body = Self.decodeBody(data, charset: charset)
            let title: String?
            let text: String
            if mime.hasPrefix("text/plain") {
                title = nil
                text = AIInput.sanitizeSnippet(body, maxChars: AISafetyLimits.maxWebTextChars)
            } else {
                title = HTMLTextExtractor.parseTitle(from: body)
                text = HTMLTextExtractor.plainText(from: body, maxChars: AISafetyLimits.maxWebTextChars)
            }

            guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw WebFetchError.emptyBody
            }

            return WebPageSnapshot(
                url: url,
                finalURL: current,
                title: title,
                text: text
            )
        }
    }

    private func downloadCapped(request: URLRequest) async throws -> (Data, URLResponse) {
        let (bytes, response) = try await session.bytes(for: request)
        var data = Data()
        data.reserveCapacity(min(32_768, AISafetyLimits.maxWebFetchBytes))
        for try await byte in bytes {
            data.append(byte)
            if data.count > AISafetyLimits.maxWebFetchBytes {
                throw WebFetchError.responseTooLarge
            }
        }
        return (data, response)
    }

    private static func parseCharset(from contentType: String?) -> String.Encoding? {
        guard let contentType else { return nil }
        let lower = contentType.lowercased()
        guard let range = lower.range(of: "charset=") else { return nil }
        let charset = String(lower[range.upperBound...])
            .trimmingCharacters(in: CharacterSet(charactersIn: "\"' "))
        return String.Encoding(charsetName: charset)
    }

    private static func decodeBody(_ data: Data, charset: String.Encoding?) -> String {
        if let charset, let text = String(data: data, encoding: charset), !text.isEmpty {
            return text
        }
        if let utf8 = String(data: data, encoding: .utf8) { return utf8 }
        return String(decoding: data, as: UTF8.self)
    }
}

private extension String.Encoding {
    init?(charsetName: String) {
        let cf = CFStringConvertIANACharSetNameToEncoding(charsetName as CFString)
        if cf == kCFStringEncodingInvalidId {
            switch charsetName.lowercased() {
            case "utf-8", "utf8": self = .utf8
            case "iso-8859-1", "latin1": self = .isoLatin1
            default: return nil
            }
        } else {
            let ns = CFStringConvertEncodingToNSStringEncoding(cf)
            self = String.Encoding(rawValue: ns)
        }
    }
}
