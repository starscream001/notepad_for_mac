import Foundation
import NotepadCore

struct FormattingTests {
    static func run() throws {
        func check(_ value: Bool, _ message: String) { if !value { CheckState.failures += 1; print("FAIL: \(message)") } }
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let script = root.appendingPathComponent("Resources/Vendor/formatter.js")
        func format(_ text: String, _ kind: String = "json", _ dialect: String = "sql") throws -> String {
            try TextFormatting.format(text, kind: kind, dialect: dialect, scriptURL: script)
        }
        let source = #"{"id":9007199254740993,"n":1.2300e+40,"key":1,"key":2,"s":"a  b\n\"🦊","a":[{},[],true,null]}"#
        let json = try format(source)
        check(json.contains("9007199254740993") && json.contains("1.2300e+40"), "Formatting retains exact JSON numbers")
        check(json.components(separatedBy: "\"key\"").count == 3 && json.contains(#"a  b\n\"🦊"#), "Formatting retains duplicate keys and string escapes")
        check(try format(json) == json, "JSON formatting is idempotent")
        for bad in ["{\"id\":}", "{\"id\":1,}", "undefined"] {
            do { _ = try format(bad); check(false, "Invalid JSON rejected") } catch {}
        }
        let sql = "select 'a  b', $$first\nsecond$$ from \"Таблица\" -- keep this\nwhere id = $1;"
        let query = try format(sql, "sql", "postgresql")
        check(query.contains("'a  b'") && query.contains("$$first\nsecond$$") && query.contains("-- keep this") && query.contains("$1"), "SQL formatting retains literals, comments and parameters")
        check(try format(query, "sql", "postgresql") == query, "SQL formatting is idempotent")
        do { _ = try format(String(repeating: "x", count: 50_001), "sql"); check(false, "SQL size limit") } catch {}
        do { _ = try format("select 1", "kafka"); check(false, "Unsupported language rejected") } catch {}
    }
}
