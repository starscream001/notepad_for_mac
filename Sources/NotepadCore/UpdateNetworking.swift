import Foundation

private final class DownloadObserver: NSObject, URLSessionDownloadDelegate, @unchecked Sendable {
    let progress: @Sendable (Int64, Int64) -> Void
    private var redirects = 0
    init(progress: @escaping @Sendable (Int64, Int64) -> Void) { self.progress = progress }
    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) {
        redirects += 1
        completionHandler(redirects <= 8 && request.url.map(UpdatePolicy.isAllowedRedirect) == true ? request : nil)
    }
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        if totalBytesWritten > UpdatePolicy.maximumDownload || totalBytesExpectedToWrite > UpdatePolicy.maximumDownload { downloadTask.cancel(); return }
        progress(totalBytesWritten, totalBytesExpectedToWrite)
    }
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {}
}

public enum UpdateNetworking {
    public static func latest(version: String) async throws -> GitHubRelease {
        var request = URLRequest(url: UpdatePolicy.latestURL, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 15)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("NotepadMac/\(version)", forHTTPHeaderField: "User-Agent")
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 15; configuration.timeoutIntervalForResource = 20
        configuration.urlCache = nil
        let session = URLSession(configuration: configuration); defer { session.invalidateAndCancel() }
        let (data, response) = try await session.data(for: request)
        try Task.checkCancellation()
        guard let http = response as? HTTPURLResponse, http.url == UpdatePolicy.latestURL else { throw EditorError.message("Не удалось получить ответ GitHub.") }
        if http.statusCode == 403 || http.statusCode == 429 { throw EditorError.message("GitHub временно ограничил запросы. Повторите проверку позже.") }
        guard http.statusCode == 200, data.count < 2 * 1024 * 1024 else { throw EditorError.message("GitHub недоступен (HTTP \(http.statusCode)). Повторите проверку позже.") }
        return try JSONDecoder().decode(GitHubRelease.self, from: data)
    }
    public static func download(_ asset: GitHubRelease.Asset, to archive: URL, progress: @escaping @Sendable (Int64, Int64) -> Void) async throws {
        let delegate = DownloadObserver(progress: progress)
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 30; configuration.timeoutIntervalForResource = 600
        let session = URLSession(configuration: configuration, delegate: delegate, delegateQueue: nil)
        defer { session.invalidateAndCancel() }
        let (download, response) = try await session.download(from: asset.browser_download_url, delegate: delegate)
        defer { try? FileManager.default.removeItem(at: download) }
        try Task.checkCancellation()
        guard let http = response as? HTTPURLResponse, http.statusCode == 200,
              http.url.map(UpdatePolicy.isAllowedRedirect) == true else { throw EditorError.message("Не удалось скачать архив с GitHub.") }
        try FileManager.default.moveItem(at: download, to: archive)
    }
}
