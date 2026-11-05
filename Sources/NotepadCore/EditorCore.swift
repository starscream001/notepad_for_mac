import Foundation

public enum TextEncoding: String, Codable, CaseIterable {
    case utf8 = "UTF-8", utf8BOM = "UTF-8 BOM", utf16LE = "UTF-16 LE", utf16BE = "UTF-16 BE"
    public var foundation: String.Encoding {
        switch self {
        case .utf8, .utf8BOM: return .utf8
        case .utf16LE: return .utf16LittleEndian
        case .utf16BE: return .utf16BigEndian
        }
    }
}

public enum LineEnding: String, Codable, CaseIterable {
    case lf = "LF", crlf = "CRLF", cr = "CR"
    public var separator: String {
        switch self { case .lf: return "\n"; case .crlf: return "\r\n"; case .cr: return "\r" }
    }
}

public struct DecodedText {
    public let text: String
    public let encoding: TextEncoding
    public let lineEnding: LineEnding
}

public enum TextCodec {
    public static func decode(_ data: Data) throws -> DecodedText {
        let encoding: TextEncoding
        let offset: Int
        if data.starts(with: [0xEF, 0xBB, 0xBF]) { encoding = .utf8BOM; offset = 3 }
        else if data.starts(with: [0xFF, 0xFE]) { encoding = .utf16LE; offset = 2 }
        else if data.starts(with: [0xFE, 0xFF]) { encoding = .utf16BE; offset = 2 }
        else { encoding = .utf8; offset = 0 }
        guard let raw = String(data: data.dropFirst(offset), encoding: encoding.foundation), !raw.contains("\0") else {
            throw EditorError.message("Не удалось прочитать файл. Поддерживаются UTF-8 и UTF-16 с BOM; бинарные файлы не открываются.")
        }
        let ending: LineEnding = raw.contains("\r\n") ? .crlf : raw.contains("\r") ? .cr : .lf
        return DecodedText(text: raw.replacingOccurrences(of: "\r\n", with: "\n").replacingOccurrences(of: "\r", with: "\n"), encoding: encoding, lineEnding: ending)
    }

    public static func encode(_ text: String, encoding: TextEncoding, lineEnding: LineEnding) throws -> Data {
        let normalized = text.replacingOccurrences(of: "\r\n", with: "\n").replacingOccurrences(of: "\r", with: "\n")
        guard let data = normalized.replacingOccurrences(of: "\n", with: lineEnding.separator).data(using: encoding.foundation) else {
            throw EditorError.message("Не удалось закодировать текст.")
        }
        switch encoding {
        case .utf8: return data
        case .utf8BOM: return Data([0xEF, 0xBB, 0xBF]) + data
        case .utf16LE: return Data([0xFF, 0xFE]) + data
        case .utf16BE: return Data([0xFE, 0xFF]) + data
        }
    }
}

public enum EditorError: LocalizedError {
    case message(String)
    public var errorDescription: String? { if case .message(let text) = self { return text }; return nil }
}

public struct SearchQuery {
    public var pattern: String
    public var regex: Bool
    public var matchCase: Bool
    public init(_ pattern: String, regex: Bool = false, matchCase: Bool = false) {
        self.pattern = pattern; self.regex = regex; self.matchCase = matchCase
    }
    private func expression() throws -> NSRegularExpression {
        try NSRegularExpression(pattern: regex ? pattern : NSRegularExpression.escapedPattern(for: pattern), options: matchCase ? [] : [.caseInsensitive])
    }
    public func matches(in text: String) throws -> [NSRange] {
        guard !pattern.isEmpty else { return [] }
        return try expression().matches(in: text, range: NSRange(location: 0, length: (text as NSString).length)).map(\.range)
    }
    public func replacing(in text: String, with replacement: String) throws -> String {
        guard !pattern.isEmpty else { return text }
        let template = regex ? replacement : NSRegularExpression.escapedTemplate(for: replacement)
        return try expression().stringByReplacingMatches(in: text, range: NSRange(location: 0, length: (text as NSString).length), withTemplate: template)
    }
    public func replacement(for text: String, with replacement: String) throws -> String {
        try replacing(in: text, with: replacement)
    }
}

public struct SessionTab: Codable {
    public var id: UUID
    public var path: String?
    public var text: String
    public var savedText: String
    public var encoding: TextEncoding
    public var lineEnding: LineEnding
    public var selection: Int
    public var syntaxLanguage: String?
    public var savedEncoding: TextEncoding?
    public var savedLineEnding: LineEnding?
    public var diskModified: Date?
    public var title: String
    public var projectID: UUID?
    public init(id: UUID = UUID(), path: String? = nil, text: String = "", savedText: String = "", encoding: TextEncoding = .utf8, lineEnding: LineEnding = .lf, selection: Int = 0, diskModified: Date? = nil, title: String = "Без имени") {
        self.id = id; self.path = path; self.text = text; self.savedText = savedText
        self.encoding = encoding; self.lineEnding = lineEnding; self.selection = selection
        self.diskModified = diskModified; self.title = title
    }
}

public struct SessionProject: Codable {
    public var id: UUID
    public var title: String
    public var selected: UUID?
    public var collapsed: Bool?
    public init(id: UUID = UUID(), title: String, selected: UUID? = nil) {
        self.id = id; self.title = title; self.selected = selected
    }
}

public struct Session: Codable {
    public var tabs: [SessionTab]
    public var selected: UUID?
    public var projects: [SessionProject]?
    public var selectedProject: UUID?
    public var looseSelected: UUID?
    public init(tabs: [SessionTab], selected: UUID?, projects: [SessionProject]? = nil, selectedProject: UUID? = nil) {
        self.tabs = tabs; self.selected = selected; self.projects = projects; self.selectedProject = selectedProject
    }
}

public enum SessionStore {
    public static func save(_ session: Session, to url: URL) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        try JSONEncoder().encode(session).write(to: url, options: [.atomic])
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
    }
    public static func load(from url: URL) throws -> Session { try JSONDecoder().decode(Session.self, from: Data(contentsOf: url)) }
}

public enum TextPosition {
    public static func lineColumn(in text: String, utf16Offset: Int) -> (line: Int, column: Int) {
        let ns = text as NSString
        let prefix = ns.substring(to: min(max(0, utf16Offset), ns.length))
        let lines = prefix.components(separatedBy: "\n")
        return (lines.count, (lines.last?.count ?? 0) + 1)
    }
    public static func offset(ofLine line: Int, in text: String) -> Int {
        let lines = text.components(separatedBy: "\n")
        return lines.prefix(max(0, min(line - 1, lines.count - 1))).reduce(0) { $0 + ($1 as NSString).length + 1 }
    }
}
