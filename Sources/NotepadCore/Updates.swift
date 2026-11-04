import Foundation
import CryptoKit

public struct AppVersion: Comparable, Equatable, CustomStringConvertible, Sendable {
    public let major: Int
    public let minor: Int
    public let patch: Int
    public let description: String
    public init?(_ text: String) {
        let value = text.hasPrefix("v") ? String(text.dropFirst()) : text
        let parts = value.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count == 3, parts.allSatisfy({ !$0.isEmpty && $0.allSatisfy({ $0.isASCII && $0.isNumber }) }),
              let major = Int(parts[0]), let minor = Int(parts[1]), let patch = Int(parts[2]) else { return nil }
        self.major = major; self.minor = minor; self.patch = patch; description = value
    }
    public static func == (lhs: Self, rhs: Self) -> Bool { (lhs.major, lhs.minor, lhs.patch) == (rhs.major, rhs.minor, rhs.patch) }
    public static func < (lhs: Self, rhs: Self) -> Bool { (lhs.major, lhs.minor, lhs.patch) < (rhs.major, rhs.minor, rhs.patch) }
}

public struct GitHubRelease: Decodable, Sendable {
    public struct Asset: Decodable, Sendable {
        public let name: String
        public let browser_download_url: URL
        public let size: Int64
        public let digest: String?
    }
    public let tag_name: String
    public let html_url: URL
    public let body: String?
    public let draft: Bool
    public let prerelease: Bool
    public let assets: [Asset]
}

public enum UpdatePolicy {
    public static let repository = "starscream001/notepad_for_mac"
    public static let repositoryURL = URL(string: "https://github.com/\(repository)")!
    public static let latestURL = URL(string: "https://api.github.com/repos/\(repository)/releases/latest")!
    public static let bundleID = "com.starscream001.notepadmac"
    public static let archiveName = "Notepad-Mac-universal.zip"
    public static let maximumDownload: Int64 = 100 * 1024 * 1024
    public static let maximumExpanded: Int64 = 500 * 1024 * 1024

    public static func shouldCheck(enabled: Bool, online: Bool, lastAttempt: Date?, interval: TimeInterval, now: Date = Date()) -> Bool {
        guard enabled, online else { return false }
        guard let lastAttempt else { return true }
        // A clock correction must not suppress checks indefinitely.
        return lastAttempt > now || now.timeIntervalSince(lastAttempt) >= interval
    }
    public static func isAllowedRedirect(_ url: URL) -> Bool {
        url.scheme == "https" && url.user == nil && url.password == nil && url.port == nil &&
        ["api.github.com", "github.com", "release-assets.githubusercontent.com", "objects.githubusercontent.com"].contains(url.host?.lowercased() ?? "")
    }
    public static func candidate(from release: GitHubRelease, newerThan current: AppVersion) throws -> GitHubRelease.Asset? {
        guard !release.draft, !release.prerelease, let version = AppVersion(release.tag_name) else { return nil }
        guard release.html_url.scheme == "https", release.html_url.host == "github.com",
              release.html_url.path == "/\(repository)/releases/tag/\(release.tag_name)",
              release.html_url.user == nil, release.html_url.password == nil, release.html_url.port == nil else {
            throw EditorError.message("GitHub вернул неожиданную ссылку на выпуск.")
        }
        guard version > current else { return nil }
        let assets = release.assets.filter { $0.name == archiveName }
        guard assets.count == 1, let asset = assets.first,
              asset.size > 0, asset.size <= maximumDownload,
              asset.browser_download_url.scheme == "https", asset.browser_download_url.host == "github.com",
              asset.browser_download_url.user == nil, asset.browser_download_url.password == nil, asset.browser_download_url.port == nil,
              asset.browser_download_url.path == "/\(repository)/releases/download/\(release.tag_name)/\(archiveName)",
              asset.browser_download_url.query == nil, asset.browser_download_url.fragment == nil,
              let digest = asset.digest, digest.hasPrefix("sha256:"), validHash(String(digest.dropFirst(7))) else {
            throw EditorError.message("В выпуске нет подходящего архива с контрольной суммой SHA-256. Откройте страницу релиза для ручной установки.")
        }
        return asset
    }
    public static func validHash(_ value: String) -> Bool {
        value.count == 64 && value.unicodeScalars.allSatisfy { (48...57).contains($0.value) || (97...102).contains($0.value) }
    }
    public static func sha256(of url: URL) throws -> String {
        let handle = try FileHandle(forReadingFrom: url); defer { try? handle.close() }
        var hash = SHA256()
        while let data = try handle.read(upToCount: 1024 * 1024), !data.isEmpty { hash.update(data: data) }
        return hash.finalize().map { String(format: "%02x", $0) }.joined()
    }
    public static func verifyArchive(_ url: URL, expectedSize: Int64, digest: String) throws {
        let size = (try FileManager.default.attributesOfItem(atPath: url.path)[.size] as? NSNumber)?.int64Value
        guard size == expectedSize, expectedSize <= maximumDownload, digest.hasPrefix("sha256:"),
              try sha256(of: url) == String(digest.dropFirst(7)) else {
            throw EditorError.message("Архив обновления повреждён или не совпадает с контрольной суммой GitHub. Установка отменена.")
        }
    }
    public static func validateArchivePaths(_ listing: String) throws {
        let paths = listing.split(separator: "\n", omittingEmptySubsequences: true)
        guard !paths.isEmpty, paths.count <= 5000 else { throw EditorError.message("Неожиданное содержимое архива обновления.") }
        for path in paths {
            let parts = path.split(separator: "/", omittingEmptySubsequences: false)
            guard !path.hasPrefix("/"), !path.contains("\\"), !path.contains("\0"),
                  parts.first == "Notepad Mac.app" || parts.first == "__MACOSX",
                  !parts.contains(".."), !parts.contains(".") else {
                throw EditorError.message("Архив содержит небезопасные пути. Установка отменена.")
            }
        }
    }
}

public enum UpdateCommand {
    /// Arguments are always passed directly to Process; no shell interpretation.
    @discardableResult public static func run(_ executable: String, _ arguments: [String]) throws -> String {
        let process = Process(); process.executableURL = URL(fileURLWithPath: executable); process.arguments = arguments
        let output = Pipe(); process.standardOutput = output; process.standardError = output
        try process.run()
        let data = output.fileHandleForReading.readDataToEndOfFile(); process.waitUntilExit()
        let text = String(decoding: data, as: UTF8.self)
        guard process.terminationStatus == 0 else { throw EditorError.message("Не удалось выполнить проверку обновления: \(URL(fileURLWithPath: executable).lastPathComponent). \(text.prefix(500))") }
        return text
    }
}

public enum UpdatePackage {
    public static func unpack(_ archive: URL, to directory: URL) throws -> URL {
        let listing = try UpdateCommand.run("/usr/bin/zipinfo", ["-1", archive.path])
        try UpdatePolicy.validateArchivePaths(listing)
        let detail = try UpdateCommand.run("/usr/bin/zipinfo", ["-l", archive.path])
        guard !detail.split(separator: "\n").contains(where: { $0.hasPrefix("l") }) else { throw EditorError.message("Архив обновления содержит символические ссылки.") }
        let summary = try UpdateCommand.run("/usr/bin/zipinfo", ["-t", archive.path])
        let regex = try NSRegularExpression(pattern: #"(\d+) bytes uncompressed"#)
        guard let match = regex.firstMatch(in: summary, range: NSRange(summary.startIndex..., in: summary)),
              let size = Int64((summary as NSString).substring(with: match.range(at: 1))), size <= UpdatePolicy.maximumExpanded else {
            throw EditorError.message("Распакованный архив обновления слишком большой.")
        }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false)
        try UpdateCommand.run("/usr/bin/ditto", ["-x", "-k", archive.path, directory.path])
        return directory.appendingPathComponent("Notepad Mac.app")
    }
    public static func validate(_ app: URL, expectedVersion: String) throws {
        let fm = FileManager.default
        guard app.pathExtension == "app", !((try app.resourceValues(forKeys: [.isSymbolicLinkKey])).isSymbolicLink ?? true),
              let info = NSDictionary(contentsOf: app.appendingPathComponent("Contents/Info.plist")),
              info["CFBundleIdentifier"] as? String == UpdatePolicy.bundleID,
              info["CFBundleExecutable"] as? String == "NotepadMac",
              let version = info["CFBundleShortVersionString"] as? String,
              AppVersion(version) == AppVersion(expectedVersion), AppVersion(version) != nil,
              let minimum = info["LSMinimumSystemVersion"] as? String else {
            throw EditorError.message("Пакет обновления не соответствует приложению или версии выпуска.")
        }
        let components = minimum.split(separator: ".").compactMap { Int($0) }
        guard components.count >= 2, ProcessInfo.processInfo.isOperatingSystemAtLeast(OperatingSystemVersion(majorVersion: components[0], minorVersion: components[1], patchVersion: components.count > 2 ? components[2] : 0)) else {
            throw EditorError.message("Для этой версии нужна macOS \(minimum) или новее.")
        }
        let executable = app.appendingPathComponent("Contents/MacOS/NotepadMac")
        guard fm.isExecutableFile(atPath: executable.path), executable.resolvingSymlinksInPath().path.hasPrefix(app.resolvingSymlinksInPath().path + "/") else {
            throw EditorError.message("В обновлении отсутствует исполняемый файл.")
        }
        try UpdateCommand.run("/usr/bin/codesign", ["--verify", "--deep", "--strict", app.path])
        #if arch(arm64)
        let architecture = "arm64"
        #else
        let architecture = "x86_64"
        #endif
        try UpdateCommand.run("/usr/bin/lipo", [executable.path, "-verify_arch", architecture])
    }
}

/// Copy to the destination volume before changing the original. A failed
/// replacement restores the original directory; the previous version stays until
/// the new application acknowledges startup.
public final class UpdateTransaction {
    public let target: URL
    public let backup: URL
    public let prepared: URL
    private let fm = FileManager.default
    public init(target: URL, token: String) {
        self.target = target
        backup = target.deletingLastPathComponent().appendingPathComponent(".NotepadMac-previous-\(token).app")
        prepared = target.deletingLastPathComponent().appendingPathComponent(".NotepadMac-next-\(token).app")
    }
    public func install(from source: URL, validate: (URL) throws -> Void) throws {
        guard !fm.fileExists(atPath: backup.path), !fm.fileExists(atPath: prepared.path), fm.fileExists(atPath: target.path) else {
            throw EditorError.message("Папка установки изменилась. Запустите проверку обновления снова.")
        }
        do {
            try fm.copyItem(at: source, to: prepared)
            try validate(prepared)
        } catch { try? fm.removeItem(at: prepared); throw error }
        do { try fm.moveItem(at: target, to: backup) }
        catch { try? fm.removeItem(at: prepared); throw error }
        do { try fm.moveItem(at: prepared, to: target) }
        catch {
            // Never delete the backup if restoring it fails.
            try? fm.moveItem(at: backup, to: target)
            try? fm.removeItem(at: prepared)
            throw error
        }
    }
    public func rollback() throws {
        guard fm.fileExists(atPath: backup.path) else { return }
        let failed = prepared
        if fm.fileExists(atPath: target.path) { try fm.moveItem(at: target, to: failed) }
        do { try fm.moveItem(at: backup, to: target) }
        catch { if fm.fileExists(atPath: failed.path) { try? fm.moveItem(at: failed, to: target) }; throw error }
        try? fm.removeItem(at: failed)
    }
    public func confirm() throws { if fm.fileExists(atPath: backup.path) { try fm.removeItem(at: backup) } }
}

public struct UpdateTicket: Codable {
    public let token: String
    public let targetPath: String
    public let candidatePath: String
    public let version: String
    public let previousVersion: String
    public let parentPID: Int32
    public init(token: String, targetPath: String, candidatePath: String, version: String, previousVersion: String, parentPID: Int32) {
        self.token = token; self.targetPath = targetPath; self.candidatePath = candidatePath
        self.version = version; self.previousVersion = previousVersion; self.parentPID = parentPID
    }
    public static var root: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("NotepadMac/Updates", isDirectory: true)
    }
    public static func read(from url: URL) throws -> UpdateTicket {
        let resolved = url.resolvingSymlinksInPath().standardizedFileURL
        let ticket = try JSONDecoder().decode(Self.self, from: Data(contentsOf: resolved))
        guard UUID(uuidString: ticket.token) != nil,
              resolved.lastPathComponent == "ticket.json",
              resolved.deletingLastPathComponent().lastPathComponent == ticket.token,
              resolved.deletingLastPathComponent().deletingLastPathComponent() == root.resolvingSymlinksInPath().standardizedFileURL,
              AppVersion(ticket.version) != nil, AppVersion(ticket.previousVersion) != nil,
              ticket.parentPID > 1 else { throw EditorError.message("Недействительный запрос на установку обновления.") }
        let staging = resolved.deletingLastPathComponent().path + "/"
        guard URL(fileURLWithPath: ticket.candidatePath).resolvingSymlinksInPath().path.hasPrefix(staging),
              ticket.targetPath.hasSuffix(".app"), !ticket.targetPath.hasPrefix(staging),
              ticket.targetPath == URL(fileURLWithPath: ticket.targetPath).resolvingSymlinksInPath().path else {
            throw EditorError.message("Недействительный путь установки обновления.")
        }
        return ticket
    }
}
