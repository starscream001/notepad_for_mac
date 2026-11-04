import Foundation
import JavaScriptCore

public enum TextFormatting {
    /// Create the small offline engine only for an explicit formatting command.
    public static func format(_ source: String, kind: String, dialect: String = "sql", scriptURL: URL) throws -> String {
        guard source.utf16.count <= (kind == "sql" ? 50_000 : 1_000_000) else { throw EditorError.message("too-large") }
        guard let context = JSContext() else { throw EditorError.message("formatter-unavailable") }
        context.evaluateScript(try String(contentsOf: scriptURL, encoding: .utf8))
        guard context.exception == nil,
              let function = context.objectForKeyedSubscript("NotepadFormatting")?.objectForKeyedSubscript("run"),
              let result = function.call(withArguments: [source, kind, dialect])?.toDictionary() else {
            throw EditorError.message("formatter-unavailable")
        }
        guard result["ok"] as? Bool == true, let text = result["text"] as? String else {
            throw EditorError.message(result["error"] as? String ?? "formatter-unavailable")
        }
        return text
    }
}
