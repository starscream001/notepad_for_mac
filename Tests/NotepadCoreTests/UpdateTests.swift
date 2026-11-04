import Foundation
import NotepadCore

final class UpdateTests {
    private func release(tag: String = "v0.4.0", changes: [String: Any] = [:], assetChanges: [String: Any] = [:]) throws -> GitHubRelease {
        var asset: [String: Any] = ["name": UpdatePolicy.archiveName, "size": 12, "digest": "sha256:" + String(repeating: "a", count: 64), "browser_download_url": "https://github.com/\(UpdatePolicy.repository)/releases/download/\(tag)/\(UpdatePolicy.archiveName)"]
        asset.merge(assetChanges) { _, value in value }
        var object: [String: Any] = ["tag_name": tag, "html_url": "https://github.com/\(UpdatePolicy.repository)/releases/tag/\(tag)", "draft": false, "prerelease": false, "body": "Release notes", "assets": [asset]]
        object.merge(changes) { _, value in value }
        return try JSONDecoder().decode(GitHubRelease.self, from: JSONSerialization.data(withJSONObject: object))
    }
    func testVersionOrdering() {
        XCTAssertEqual(AppVersion("0.10.0")! > AppVersion("0.9.9")!, true)
        XCTAssertEqual(AppVersion("v0.3.0"), AppVersion("0.3.0"))
        XCTAssertEqual(AppVersion("1.0.0")! > AppVersion("0.99.999")!, true)
        for invalid in ["0.3", "", "latest", "0.3.0-beta", "0.-1.0", "0.3.0.0", "０.3.0", String(repeating: "9", count: 50) + ".0.0"] {
            XCTAssertEqual(AppVersion(invalid), nil)
        }
    }
    func testSchedule() {
        let now = Date(timeIntervalSince1970: 100_000)
        XCTAssertEqual(UpdatePolicy.shouldCheck(enabled: true, online: true, lastAttempt: nil, interval: 86400, now: now), true)
        XCTAssertEqual(UpdatePolicy.shouldCheck(enabled: false, online: true, lastAttempt: nil, interval: 86400, now: now), false)
        XCTAssertEqual(UpdatePolicy.shouldCheck(enabled: true, online: false, lastAttempt: nil, interval: 86400, now: now), false)
        XCTAssertEqual(UpdatePolicy.shouldCheck(enabled: true, online: true, lastAttempt: now.addingTimeInterval(-86000), interval: 86400, now: now), false)
        XCTAssertEqual(UpdatePolicy.shouldCheck(enabled: true, online: true, lastAttempt: now.addingTimeInterval(-86400), interval: 86400, now: now), true)
        XCTAssertEqual(UpdatePolicy.shouldCheck(enabled: true, online: true, lastAttempt: now.addingTimeInterval(1), interval: 86400, now: now), true)
    }
    func testStableReleasesOnly() throws {
        let current = AppVersion("0.3.0")!
        XCTAssertEqual(try UpdatePolicy.candidate(from: release(), newerThan: current)?.name, UpdatePolicy.archiveName)
        XCTAssertEqual(try UpdatePolicy.candidate(from: release(tag: "v0.3.0"), newerThan: current)?.name, nil)
        XCTAssertEqual(try UpdatePolicy.candidate(from: release(tag: "v0.2.0"), newerThan: current)?.name, nil)
        XCTAssertEqual(try UpdatePolicy.candidate(from: release(changes: ["prerelease": true]), newerThan: current)?.name, nil)
        XCTAssertEqual(try UpdatePolicy.candidate(from: release(changes: ["draft": true]), newerThan: current)?.name, nil)
        XCTAssertEqual(try UpdatePolicy.candidate(from: release(tag: "v0.4.0-rc1"), newerThan: current)?.name, nil)
    }
    func testUntrustedAssetsRejected() throws {
        let current = AppVersion("0.3.0")!
        for change: [String: Any] in [
            ["digest": NSNull()], ["digest": "sha256:no"], ["size": 0], ["size": UpdatePolicy.maximumDownload + 1],
            ["browser_download_url": "http://github.com/a.zip"],
            ["browser_download_url": "https://github.com.evil.invalid/\(UpdatePolicy.repository)/a.zip"],
            ["browser_download_url": "https://github.com/another/repository/releases/download/v0.4.0/Notepad-Mac-universal.zip"]
        ] { XCTAssertThrowsError(try UpdatePolicy.candidate(from: release(assetChanges: change), newerThan: current)) }
        XCTAssertThrowsError(try UpdatePolicy.candidate(from: release(changes: ["html_url": "https://example.com/"]), newerThan: current))
        XCTAssertEqual(UpdatePolicy.isAllowedRedirect(URL(string: "https://release-assets.githubusercontent.com/test")!), true)
        for url in ["http://github.com/test", "https://github.com.evil.invalid/test", "https://user@github.com/test", "https://github.com:444/test"] {
            XCTAssertEqual(UpdatePolicy.isAllowedRedirect(URL(string: url)!), false)
        }
    }
    func testDigestAndSize() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: url) }
        try Data("abc".utf8).write(to: url)
        let digest = "sha256:ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad"
        try UpdatePolicy.verifyArchive(url, expectedSize: 3, digest: digest)
        XCTAssertThrowsError(try UpdatePolicy.verifyArchive(url, expectedSize: 2, digest: digest))
        XCTAssertThrowsError(try UpdatePolicy.verifyArchive(url, expectedSize: 3, digest: "sha256:" + String(repeating: "a", count: 64)))
    }
    func testArchiveTraversalRejected() throws {
        try UpdatePolicy.validateArchivePaths("Notepad Mac.app/\nNotepad Mac.app/Contents/Info.plist\n__MACOSX/Notepad Mac.app/._Contents\n")
        for path in ["/tmp/evil", "Notepad Mac.app/../../evil", "Notepad Mac.app/./evil", "../evil", "another.app/a", "Notepad Mac.app\\evil", ""] {
            XCTAssertThrowsError(try UpdatePolicy.validateArchivePaths(path))
        }
    }
    private func fixture() throws -> (URL, URL, URL) {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let target = root.appendingPathComponent("Notepad Mac.app"), next = root.appendingPathComponent("download.app")
        for url in [target, next] { try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true) }
        try Data("old".utf8).write(to: target.appendingPathComponent("marker"))
        try Data("new".utf8).write(to: next.appendingPathComponent("marker"))
        return (root, target, next)
    }
    func testTransactionalInstallAndRollback() throws {
        let (root, target, next) = try fixture(); defer { try? FileManager.default.removeItem(at: root) }
        let transaction = UpdateTransaction(target: target, token: UUID().uuidString)
        try transaction.install(from: next) { _ in }
        XCTAssertEqual(try String(contentsOf: target.appendingPathComponent("marker")), "new")
        XCTAssertEqual(try String(contentsOf: transaction.backup.appendingPathComponent("marker")), "old")
        try transaction.rollback()
        XCTAssertEqual(try String(contentsOf: target.appendingPathComponent("marker")), "old")
        XCTAssertEqual(FileManager.default.fileExists(atPath: transaction.backup.path), false)
    }
    func testValidationAndRenameFailureKeepOriginal() throws {
        let (root, target, next) = try fixture(); defer { try? FileManager.default.removeItem(at: root) }
        let transaction = UpdateTransaction(target: target, token: UUID().uuidString)
        XCTAssertThrowsError(try transaction.install(from: next) { _ in throw EditorError.message("bad signature") })
        XCTAssertEqual(try String(contentsOf: target.appendingPathComponent("marker")), "old")
        XCTAssertEqual(FileManager.default.fileExists(atPath: transaction.prepared.path), false)
        // Model a failed second rename after the original moved to the backup.
        XCTAssertThrowsError(try transaction.install(from: next) { try FileManager.default.removeItem(at: $0) })
        XCTAssertEqual(try String(contentsOf: target.appendingPathComponent("marker")), "old")
        XCTAssertEqual(FileManager.default.fileExists(atPath: transaction.backup.path), false)
    }
    func testConfirmRemovesBackupOnlyAfterSuccess() throws {
        let (root, target, next) = try fixture(); defer { try? FileManager.default.removeItem(at: root) }
        let transaction = UpdateTransaction(target: target, token: UUID().uuidString)
        try transaction.install(from: next) { _ in }
        try transaction.confirm()
        XCTAssertEqual(try String(contentsOf: target.appendingPathComponent("marker")), "new")
        XCTAssertEqual(FileManager.default.fileExists(atPath: transaction.backup.path), false)
        XCTAssertThrowsError(try UpdatePackage.validate(next, expectedVersion: "0.3.0"))
    }
    func testForeignInstallTicketRejected() throws {
        let (root, target, next) = try fixture(); defer { try? FileManager.default.removeItem(at: root) }
        let ticket = UpdateTicket(token: UUID().uuidString, targetPath: target.path, candidatePath: next.path, version: "0.4.0", previousVersion: "0.3.0", parentPID: 123)
        let url = root.appendingPathComponent("ticket.json")
        try JSONEncoder().encode(ticket).write(to: url)
        XCTAssertThrowsError(try UpdateTicket.read(from: url))
    }
    func testLiveGitHubTransport() async throws {
        let release = try await UpdateNetworking.latest(version: "0.3.0-test")
        let asset = try UpdatePolicy.candidate(from: release, newerThan: AppVersion("0.0.0")!)!
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let archive = root.appendingPathComponent("update.zip")
        try await UpdateNetworking.download(asset, to: archive) { _, _ in }
        try UpdatePolicy.verifyArchive(archive, expectedSize: asset.size, digest: asset.digest!)
        let app = try UpdatePackage.unpack(archive, to: root.appendingPathComponent("unpacked"))
        try UpdatePackage.validate(app, expectedVersion: AppVersion(release.tag_name)!.description)
        print("Live GitHub transport, digest, unpack and signature check: passed (\(release.tag_name)).")
    }
}
