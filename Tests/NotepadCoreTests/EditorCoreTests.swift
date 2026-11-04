import Foundation
import NotepadCore

final class EditorCoreTests {
    func testRoundTripAllEncodingsAndLineEndings() throws {
        let text = "Привет, мир 👋\nlet café = 42\n"
        for encoding in TextEncoding.allCases {
            for ending in LineEnding.allCases {
                let data = try TextCodec.encode(text, encoding: encoding, lineEnding: ending)
                let decoded = try TextCodec.decode(data)
                XCTAssertEqual(decoded.text, text)
                XCTAssertEqual(decoded.encoding, encoding)
                XCTAssertEqual(decoded.lineEnding, ending)
            }
        }
    }
    func testRejectsInvalidUTF8AndBinary() {
        XCTAssertThrowsError(try TextCodec.decode(Data([0xFF, 0x81, 0x00])))
        XCTAssertThrowsError(try TextCodec.decode(Data([65, 0, 66])))
    }
    func testLiteralReplacementDoesNotExpandDollarOrBackslash() throws {
        let query = SearchQuery("a.b")
        XCTAssertEqual(try query.matches(in: "A.B axb a.b").count, 2)
        XCTAssertEqual(try query.replacing(in: "a.b", with: "$1\\test"), "$1\\test")
    }
    func testRegexCaptureReplacementAndUnicodeRanges() throws {
        let query = SearchQuery(#"(\w+)=(\d+)"#, regex: true)
        XCTAssertEqual(try query.replacing(in: "👋 x=12 y=3", with: "$1: $2"), "👋 x: 12 y: 3")
        XCTAssertEqual(try SearchQuery("x").matches(in: "👋x").first, NSRange(location: 2, length: 1))
    }
    func testInvalidAndEmptyRegex() throws {
        XCTAssertThrowsError(try SearchQuery("[", regex: true).matches(in: "text"))
        XCTAssertEqual(try SearchQuery("").replacing(in: "text", with: "!"), "text")
        XCTAssertEqual(try SearchQuery("^", regex: true).matches(in: "text").first?.length, 0)
    }
    func testSessionRetainsUnsavedTextAndSelectedTab() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathComponent("session.json")
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        var tab = SessionTab(path: "/tmp/notes.txt", text: "изменения 📝", savedText: "original", encoding: .utf16LE, lineEnding: .crlf, selection: 4)
        tab.savedEncoding = .utf8; tab.savedLineEnding = .lf
        try SessionStore.save(Session(tabs: [tab], selected: tab.id), to: url)
        let restored = try SessionStore.load(from: url)
        XCTAssertEqual(restored.selected, tab.id)
        XCTAssertEqual(restored.tabs[0].text, tab.text)
        XCTAssertEqual(restored.tabs[0].savedText, "original")
        XCTAssertEqual(restored.tabs[0].savedEncoding, .utf8)
        XCTAssertEqual(restored.tabs[0].selection, 4)
        let permissions = try FileManager.default.attributesOfItem(atPath: url.path)[.posixPermissions] as? NSNumber
        XCTAssertEqual(permissions?.intValue, 0o600)
    }
    func testQueryLanguageDetection() {
        for ext in ["sql", "SQL", "psql", "pgsql", "mysql", "ddl", "dml"] { XCTAssertEqual(QuerySyntax.language(forExtension: ext), "SQL") }
        for ext in ["ksql", "KSQLDB"] { XCTAssertEqual(QuerySyntax.language(forExtension: ext), "Kafka / ksqlDB") }
        XCTAssertEqual(QuerySyntax.language(forExtension: "txt"), nil)
    }
    func testSQLTokensKeepStringsIdentifiersAndCommentsSeparate() {
        let text = "SELECT 'it''s -- text', \"FROM\", :user_id, $1, 1.5e2 -- SELECT\nFROM events /* WHERE */".replacingOccurrences(of: "\\n", with: "\n")
        let ns = text as NSString
        let tokens = QuerySyntax.tokens(in: text, kafkaMode: false)
        XCTAssertEqual(tokens.filter { $0.kind == .keyword }.map { ns.substring(with: $0.range) }, ["SELECT", "FROM"])
        XCTAssertEqual(tokens.filter { $0.kind == .string }.map { ns.substring(with: $0.range) }, ["'it''s -- text'"])
        XCTAssertEqual(tokens.filter { $0.kind == .identifier }.map { ns.substring(with: $0.range) }, ["\"FROM\""])
        XCTAssertEqual(tokens.filter { $0.kind == .comment }.count, 2)
        XCTAssertEqual(tokens.filter { $0.kind == .parameter }.count, 2)
        XCTAssertEqual(tokens.filter { $0.kind == .number }.map { ns.substring(with: $0.range) }, ["1.5e2"])
        for pair in zip(tokens, tokens.dropFirst()) { XCTAssertEqual(NSMaxRange(pair.0.range) <= pair.1.range.location, true) }
    }
    func testKafkaKeywordsAndFunctions() {
        let text = "create stream totals as select count(*) from orders window tumbling (size 5 minutes) emit changes;"
        let ns = text as NSString
        let tokens = QuerySyntax.tokens(in: text, kafkaMode: true)
        let keywords = tokens.filter { $0.kind == .keyword }.map { ns.substring(with: $0.range).uppercased() }
        for keyword in ["CREATE", "STREAM", "WINDOW", "TUMBLING", "SIZE", "MINUTES", "EMIT", "CHANGES"] { XCTAssertEqual(keywords.contains(keyword), true) }
        XCTAssertEqual(tokens.filter { $0.kind == .function }.map { ns.substring(with: $0.range) }, ["count"])
        XCTAssertEqual(QuerySyntax.tokens(in: "EMIT CHANGES", kafkaMode: false).count, 0)
    }
    func testDollarQuotesAndUnicodeQuery() {
        let text = "SELECT $$-- not comment$$, $body$SELECT 42$body$, 'Привет 👋', x👋, `a``b`, [odd]]name];"
        let ns = text as NSString
        let tokens = QuerySyntax.tokens(in: text, kafkaMode: false)
        XCTAssertEqual(tokens.filter { $0.kind == .string }.map { ns.substring(with: $0.range) }, ["$$-- not comment$$", "$body$SELECT 42$body$", "'Привет 👋'"])
        XCTAssertEqual(tokens.filter { $0.kind == .comment }.count, 0)
        XCTAssertEqual(tokens.filter { $0.kind == .identifier }.count, 2)
        XCTAssertEqual(QuerySyntax.tokens(in: "SELECT 'unfinished", kafkaMode: false).last?.kind, .string)
    }
    func testSessionRemembersLanguageAndReadsOlderSessions() throws {
        var tab = SessionTab(text: "SELECT 1;")
        tab.syntaxLanguage = "SQL"
        let data = try JSONEncoder().encode(Session(tabs: [tab], selected: tab.id))
        XCTAssertEqual(try JSONDecoder().decode(Session.self, from: data).tabs.first?.syntaxLanguage, "SQL")
        var object = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        var tabs = object["tabs"] as! [[String: Any]]
        tabs[0].removeValue(forKey: "syntaxLanguage"); object["tabs"] = tabs
        let old = try JSONSerialization.data(withJSONObject: object)
        XCTAssertEqual(try JSONDecoder().decode(Session.self, from: old).tabs.first?.syntaxLanguage, nil)
    }
    func testUTF16LineNavigation() {
        let text = "👋x\nПривет\n"
        let position = TextPosition.lineColumn(in: text, utf16Offset: 4)
        XCTAssertEqual(position.line, 2); XCTAssertEqual(position.column, 1)
        XCTAssertEqual(TextPosition.offset(ofLine: 2, in: text), 4)
        XCTAssertEqual(TextPosition.offset(ofLine: 999, in: text), (text as NSString).length)
    }
}

enum CheckState { static var failures = 0 }
func XCTAssertEqual<T: Equatable>(_ actual: T, _ expected: T, file: StaticString = #file, line: UInt = #line) {
    if actual != expected { CheckState.failures += 1; print("FAIL \(file):\(line): \(actual) != \(expected)") }
}
func XCTAssertThrowsError<T>(_ expression: @autoclosure () throws -> T, file: StaticString = #file, line: UInt = #line) {
    do { _ = try expression(); CheckState.failures += 1; print("FAIL \(file):\(line): expected an error") } catch {}
}
@main struct CoreChecks {
    static func main() async {
        do { try await run() }
        catch { print("FAIL: \(error.localizedDescription)"); exit(1) }
    }
    static func run() async throws {
        let tests = EditorCoreTests()
        try tests.testRoundTripAllEncodingsAndLineEndings()
        tests.testRejectsInvalidUTF8AndBinary()
        try tests.testLiteralReplacementDoesNotExpandDollarOrBackslash()
        try tests.testRegexCaptureReplacementAndUnicodeRanges()
        try tests.testInvalidAndEmptyRegex()
        try tests.testSessionRetainsUnsavedTextAndSelectedTab()
        tests.testUTF16LineNavigation()
        tests.testQueryLanguageDetection()
        tests.testSQLTokensKeepStringsIdentifiersAndCommentsSeparate()
        tests.testKafkaKeywordsAndFunctions()
        tests.testDollarQuotesAndUnicodeQuery()
        try tests.testSessionRemembersLanguageAndReadsOlderSessions()
        let updates = UpdateTests()
        updates.testVersionOrdering()
        updates.testSchedule()
        try updates.testStableReleasesOnly()
        try updates.testUntrustedAssetsRejected()
        try updates.testDigestAndSize()
        try updates.testArchiveTraversalRejected()
        try updates.testTransactionalInstallAndRollback()
        try updates.testValidationAndRenameFailureKeepOriginal()
        try updates.testConfirmRemovesBackupOnlyAfterSuccess()
        try updates.testForeignInstallTicketRejected()
        if CommandLine.arguments.contains("--network") { try await updates.testLiveGitHubTransport() }
        guard CheckState.failures == 0 else { exit(1) }
        print("22 checks passed (including all 12 encoding / line-ending combinations).")
    }
}
