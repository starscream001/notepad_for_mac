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
    static func main() throws {
        let tests = EditorCoreTests()
        try tests.testRoundTripAllEncodingsAndLineEndings()
        tests.testRejectsInvalidUTF8AndBinary()
        try tests.testLiteralReplacementDoesNotExpandDollarOrBackslash()
        try tests.testRegexCaptureReplacementAndUnicodeRanges()
        try tests.testInvalidAndEmptyRegex()
        try tests.testSessionRetainsUnsavedTextAndSelectedTab()
        tests.testUTF16LineNavigation()
        guard CheckState.failures == 0 else { exit(1) }
        print("7 checks passed (including all 12 encoding / line-ending combinations).")
    }
}
