import AppKit
import Security
import NotepadCore

enum GitHubRepositoryError: Error { case invalidName, nameUnavailable, permission, unknown }

private final class GitHubNoRedirect: NSObject, URLSessionTaskDelegate {
    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) { completionHandler(nil) }
}
private struct GitHubCredentials: Codable {
    let provider: String?
    let clientID: String
    let token: String
    let profile: GitHubProfile
    let expiresAt: Date?
}
private struct GitHubKeychain {
    // Separate service per bundle, including isolated QA bundles.
    var query: [String: Any] { [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: (Bundle.main.bundleIdentifier ?? "NotepadMac") + ".github", kSecAttrAccount as String: "account"] }
    func read() throws -> Data? {
        var q = query; q[kSecReturnData as String] = true; q[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?; let status = SecItemCopyMatching(q as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }; guard status == errSecSuccess, let data = result as? Data, data.count <= 65536 else { throw GitHubIdentityError.storage }; return data
    }
    func save(_ data: Data) throws {
        let attributes = [kSecValueData as String: data, kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly] as [String: Any]
        let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if status == errSecItemNotFound { var q = query; attributes.forEach { q[$0.key] = $0.value }; guard SecItemAdd(q as CFDictionary, nil) == errSecSuccess else { throw GitHubIdentityError.storage } }
        else if status != errSecSuccess { throw GitHubIdentityError.storage }
    }
    func remove() throws { let status = SecItemDelete(query as CFDictionary); guard status == errSecSuccess || status == errSecItemNotFound else { throw GitHubIdentityError.storage } }
}
@MainActor final class GitHubAccount {
    static let verificationURL = URL(string: "https://github.com/login/device")!
    let clientID: String
    private(set) var phase = "signedOut"
    private(set) var profile: GitHubProfile?
    private(set) var userCode = ""
    private(set) var error: GitHubIdentityError?
    private(set) var browserFailed = false
    private var credentials: GitHubCredentials?
    private var task: Task<Void, Never>?
    private var generation = UUID()
    private var loaded = false
    private var _syncBusy = false
    private let keychain = GitHubKeychain()
    private let redirect = GitHubNoRedirect()
    private lazy var session: URLSession = {
        let config = URLSessionConfiguration.ephemeral; config.timeoutIntervalForRequest = 15; config.timeoutIntervalForResource = 20
        return URLSession(configuration: config, delegate: redirect, delegateQueue: nil)
    }()
    var onChange: (() -> Void)?
    init() {
        let config = Bundle.main.url(forResource: "GitHubOAuth", withExtension: "json").flatMap { try? Data(contentsOf: $0) }.flatMap { try? JSONSerialization.jsonObject(with: $0) as? [String: String] }
        clientID = ProcessInfo.processInfo.environment["NOTEPAD_GITHUB_CLIENT_ID"] ?? config?["clientID"] ?? ""
        if !GitHubOAuth.validClient(clientID) { phase = "unconfigured" }
    }
    func load() {
        guard !loaded, GitHubOAuth.validClient(clientID) else { return }; loaded = true
        do {
            if let data = try keychain.read() {
                let saved = try JSONDecoder().decode(GitHubCredentials.self, from: data)
                guard saved.provider == "github-app", saved.clientID == clientID else { return }
                guard saved.expiresAt == nil || saved.expiresAt! > Date() else { try keychain.remove(); return }
                guard saved.token.range(of: "^[A-Za-z0-9_-]{10,1024}$", options: .regularExpression) != nil else { throw GitHubIdentityError.storage }
                profile = try saved.profile.validated(); credentials = saved; phase = "connected"
            }
        } catch { self.error = .storage; phase = "error" }
        onChange?()
    }
    func cancel() {
        generation = UUID(); task?.cancel(); task = nil; userCode = ""; error = nil; browserFailed = false
        phase = credentials == nil ? (GitHubOAuth.validClient(clientID) ? "signedOut" : "unconfigured") : "connected"; onChange?()
    }
    func disconnect() {
        cancel()
        do { try keychain.remove(); credentials = nil; profile = nil; phase = GitHubOAuth.validClient(clientID) ? "signedOut" : "unconfigured" }
        catch { self.error = .storage; phase = "error" }; onChange?()
    }
    func start() {
        load(); guard GitHubOAuth.validClient(clientID), credentials == nil else { return }; cancel()
        do { _ = try keychain.read() } catch { self.error = .storage; phase = "error"; onChange?(); return }
        let epoch = generation; phase = "starting"; onChange?()
        task = Task { [weak self] in
            guard let self else { return }
            do { try await self.authorize(epoch) }
            catch { self.failed(error, epoch: epoch) }
        }
    }
    func openBrowser() { guard phase == "waiting" else { return }; browserFailed = !NSWorkspace.shared.open(Self.verificationURL); onChange?() }
    func copyCode() { guard phase == "waiting" else { return }; NSPasteboard.general.clearContents(); NSPasteboard.general.setString(userCode, forType: .string) }
    func openProfile() { if let profile { NSWorkspace.shared.open(profile.url) } }
    func refresh() {
        load(); guard let saved = credentials else { return }; cancel(); let epoch = generation; phase = "checking"; onChange?()
        task = Task { [weak self] in
            guard let self else { return }
            do {
                let profile = try await self.fetchProfile(saved.token)
                try Task.checkCancellation(); guard epoch == self.generation else { return }
                let value = GitHubCredentials(provider: "github-app", clientID: self.clientID, token: saved.token, profile: profile, expiresAt: saved.expiresAt)
                try self.keychain.save(JSONEncoder().encode(value)); self.credentials = value; self.profile = profile; self.phase = "connected"; self.onChange?()
            } catch {
                if epoch == self.generation, error as? GitHubIdentityError == .unauthorized { self.disconnect(); if self.credentials == nil { self.error = .unauthorized }; self.onChange?() }
                else { self.failed(error, epoch: epoch) }
            }
        }
    }
    private func failed(_ value: Error, epoch: UUID) {
        guard epoch == generation, !(value is CancellationError) else { return }
        error = (value as? GitHubIdentityError) ?? .network; userCode = ""; phase = credentials == nil ? "error" : "connected"; onChange?()
    }
    func createRepository(name: String) async throws -> String {
        guard let saved = credentials, let profile else { throw GitHubIdentityError.unauthorized }
        guard name.range(of: "^[A-Za-z0-9][A-Za-z0-9._-]{0,99}$", options: .regularExpression) != nil, !name.hasSuffix(".git") else { throw GitHubRepositoryError.invalidName }
        let epoch = generation
        let data: Data
        do { data = try await request("https://api.github.com/user/repos", token: saved.token, json: ["name": name, "private": true, "auto_init": true, "description": "Private Notepad notes", "has_issues": false, "has_wiki": false, "has_projects": false]) }
        catch let error as GitHubRepositoryError { throw error }
        catch { throw GitHubRepositoryError.unknown }
        guard epoch == generation, let value = try? JSONSerialization.jsonObject(with: data) as? [String: Any], value["private"] as? Bool == true, value["name"] as? String == name, let owner = value["owner"] as? [String: Any], (owner["login"] as? String)?.lowercased() == profile.login.lowercased() else { throw GitHubRepositoryError.unknown }
        return profile.login + "/" + name
    }
    private var syncBusy: Bool { get { _syncBusy } set { _syncBusy = newValue } }
    func synchronize(repo: String, app: AppDelegate) async throws -> (conflicts:Int,pending:Bool) {
        guard !syncBusy, let saved=credentials, let profile else { throw GitHubIdentityError.unauthorized }
        guard repo.range(of:"^[A-Za-z0-9][A-Za-z0-9._-]{0,99}$",options:.regularExpression) != nil else { throw GitHubRepositoryError.invalidName }
        syncBusy=true;defer { syncBusy=false };let epoch=generation
        guard app.persist() else { throw GitHubIdentityError.storage }
        let initial=try app.portableNotes(), cacheURL=app.sessionURL.deletingLastPathComponent().appendingPathComponent("github-sync.json"), key=String(profile.id)+"/"+repo
        var cache:[String:[String:Any]]=[:]
        if FileManager.default.fileExists(atPath:cacheURL.path) { guard let value=try JSONSerialization.jsonObject(with:Data(contentsOf:cacheURL)) as? [String:[String:Any]] else { throw GitHubIdentityError.storage };cache=value }
        let prefix="https://api.github.com/repos/"+profile.login+"/"+repo
        func api(_ path:String,_ method:String="GET",_ body:[String:Any]?=nil) async throws -> [String:Any] {
            try Task.checkCancellation();guard epoch==self.generation else { throw CancellationError() }
            let data=try await self.request(prefix+path,token:saved.token,json:body,method:method,maximum:8*1024*1024,syncStage:path.isEmpty ? "repository" : path.hasPrefix("/git/ref/heads/") ? "branch" : method == "PATCH" ? "update" : method == "POST" ? "write" : "read")
            guard let value=try JSONSerialization.jsonObject(with:data) as? [String:Any] else { throw GitHubIdentityError.invalidResponse };return value
        }
        func sha(_ value:Any?) throws -> String { guard let s=value as? String,s.range(of:"^[0-9a-f]{40,64}$",options:.regularExpression) != nil else { throw GitHubIdentityError.invalidResponse };return s }
        let info=try await api("");guard info["private"] as? Bool == true,let branch=info["default_branch"] as? String,let owner=info["owner"] as? [String:Any],(owner["login"] as? String)?.lowercased()==profile.login.lowercased() else { throw GitHubRepositoryError.permission }
        let safeBranch=branch.addingPercentEncoding(withAllowedCharacters:.alphanumerics) ?? ""
        let ref=try await api("/git/ref/heads/"+safeBranch),head=try sha((ref["object"] as? [String:Any])?["sha"])
        let commit=try await api("/git/commits/"+head),treeSHA=try sha((commit["tree"] as? [String:Any])?["sha"])
        let tree=try await api("/git/trees/"+treeSHA+"?recursive=1");guard tree["truncated"] as? Bool != true,let entries=tree["tree"] as? [[String:Any]] else { throw GitHubIdentityError.invalidResponse }
        var remote="{\"schema\":1,\"projects\":[],\"tabs\":[]}"
        if let entry=entries.first(where:{$0["path"] as? String == ".notepad/snapshot.json"}) {
            guard entry["type"] as? String == "blob",(entry["size"] as? Int ?? Int.max)<=5242880 else { throw GitHubIdentityError.invalidResponse }
            let blob=try await api("/git/blobs/"+sha(entry["sha"]))
            guard blob["encoding"] as? String == "base64",let content=blob["content"] as? String,let data=Data(base64Encoded:content,options:.ignoreUnknownCharacters),data.count<=5242880,let object=try JSONSerialization.jsonObject(with:data) as? [String:Any] else { throw GitHubIdentityError.invalidResponse };remote=try SyncEngine.clean(object)
        }
        let merged=try SyncEngine.merge(cache[key]?["base"] as? String,initial,remote)
        var nextHead=head
        if merged.0 != remote {
            let blob=try await api("/git/blobs","POST",["content":merged.0,"encoding":"utf-8"])
            let nextTree=try await api("/git/trees","POST",["base_tree":treeSHA,"tree":[["path":".notepad/snapshot.json","mode":"100644","type":"blob","sha":try sha(blob["sha"])]]])
            let next=try await api("/git/commits","POST",["message":"Sync Notepad notes","tree":try sha(nextTree["sha"]),"parents":[head]])
            nextHead=try sha(next["sha"]);_=try await api("/git/refs/heads/"+safeBranch,"PATCH",["sha":nextHead,"force":false])
        }
        guard epoch==generation else { throw CancellationError() }
        let applied=try SyncEngine.merge(initial,app.portableNotes(),merged.0)
        try app.applyCloudNotes(applied.0)
        cache[key]=["base":merged.0,"head":nextHead,"lastSync":ISO8601DateFormatter().string(from:Date())]
        try JSONSerialization.data(withJSONObject:cache).write(to:cacheURL,options:.atomic)
        return (merged.1+applied.1,applied.0 != merged.0)
    }
    private func request(_ url: String, form: [String: String]? = nil, token: String? = nil, json: [String: Any]? = nil, method: String? = nil, maximum: Int = 65536, syncStage: String? = nil) async throws -> Data {
        var request = URLRequest(url: URL(string: url)!); request.setValue("application/json", forHTTPHeaderField: "Accept"); request.setValue("Notepad-Mac", forHTTPHeaderField: "User-Agent")
        if let form {
            request.httpMethod = "POST"; request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
            var components = URLComponents(); components.queryItems = form.map { URLQueryItem(name: $0.key, value: $0.value) }
            request.httpBody = components.percentEncodedQuery?.data(using: .utf8)
        }
        if let json { request.httpMethod = "POST"; request.httpBody = try JSONSerialization.data(withJSONObject: json); request.setValue("application/json", forHTTPHeaderField: "Content-Type") }
        if let method { request.httpMethod=method }
        if let token { request.setValue("Bearer " + token, forHTTPHeaderField: "Authorization"); request.setValue("2022-11-28", forHTTPHeaderField: "X-GitHub-Api-Version") }
        let (bytes, response) = try await session.bytes(for: request)
        guard let response = response as? HTTPURLResponse else { throw GitHubIdentityError.network }
        if let syncStage, ![200,201].contains(response.statusCode) { throw GitHubSyncHTTPFailure(status:response.statusCode,stage:syncStage,rateLimited:response.value(forHTTPHeaderField:"X-RateLimit-Remaining") == "0" || response.statusCode == 429 || response.value(forHTTPHeaderField:"Retry-After") != nil) }
        if json != nil, response.statusCode == 422 { throw GitHubRepositoryError.nameUnavailable }
        if json != nil, response.statusCode == 403 { throw GitHubRepositoryError.permission }
        if response.statusCode == 401 { throw GitHubIdentityError.unauthorized }
        if [403,429].contains(response.statusCode) { throw GitHubIdentityError.rateLimit }
        guard [200,201].contains(response.statusCode), response.expectedContentLength <= maximum else { throw GitHubIdentityError.network }
        var data = Data(); for try await byte in bytes { guard data.count < maximum else { throw GitHubIdentityError.invalidResponse }; data.append(byte) }; return data
    }
    private func fetchProfile(_ token: String) async throws -> GitHubProfile {
        try JSONDecoder().decode(GitHubProfile.self, from: await request("https://api.github.com/user", token: token)).validated()
    }
    private func authorize(_ epoch: UUID) async throws {
        let data = try await request("https://github.com/login/device/code", form: ["client_id": clientID])
        let device = try JSONDecoder().decode(GitHubDeviceCode.self, from: data).validated()
        try Task.checkCancellation(); guard epoch == generation else { return }
        userCode = device.user_code; phase = "waiting"; onChange?(); openBrowser()
        let expires = Date().addingTimeInterval(TimeInterval(device.expires_in)); var interval = device.interval
        while epoch == generation {
            guard Date().addingTimeInterval(TimeInterval(interval)) < expires else { throw GitHubIdentityError.expired }
            try await Task.sleep(nanoseconds: UInt64(interval) * 1_000_000_000)
            let result = try JSONDecoder().decode(GitHubTokenReply.self, from: await request("https://github.com/login/oauth/access_token", form: ["client_id": clientID, "device_code": device.device_code, "grant_type": "urn:ietf:params:oauth:grant-type:device_code"]))
            try Task.checkCancellation(); guard epoch == generation else { return }; guard Date() < expires else { throw GitHubIdentityError.expired }
            if result.error == "authorization_pending" { continue }
            if result.error == "slow_down" { interval += 5; continue }
            if let problem = result.error { throw problem == "access_denied" ? GitHubIdentityError.denied : problem == "expired_token" ? .expired : .configuration }
            let token = try result.token(); let profile = try await fetchProfile(token)
            try Task.checkCancellation(); guard epoch == generation else { return }
            let value = GitHubCredentials(provider: "github-app", clientID: clientID, token: token, profile: profile, expiresAt: result.expires_in.map { Date().addingTimeInterval(TimeInterval($0)) })
            try keychain.save(JSONEncoder().encode(value)); credentials = value; self.profile = profile; userCode = ""; phase = "connected"; onChange?(); return
        }
    }
}
