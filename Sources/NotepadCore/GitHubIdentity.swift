import Foundation

public enum GitHubIdentityError: String, Error { case invalidResponse, network, unauthorized, rateLimit, storage, expired, denied, configuration }
public struct GitHubProfile: Codable, Equatable {
    public let id: Int
    public let login: String
    public let name: String?
    public var url: URL { URL(string: "https://github.com/" + login)! }
    public func validated() throws -> Self {
        guard id > 0, login.range(of: "^[A-Za-z0-9][A-Za-z0-9-]{0,38}$", options: .regularExpression) != nil else { throw GitHubIdentityError.invalidResponse }
        return GitHubProfile(id: id, login: login, name: name.map { $0.split(whereSeparator: { $0.isWhitespace }).joined(separator: " ").prefix(100).description })
    }
}
public struct GitHubDeviceCode: Decodable {
    public let device_code: String
    public let user_code: String
    public let verification_uri: String
    public let expires_in: Int
    public let interval: Int
    public func validated() throws -> Self {
        guard device_code.range(of: "^[A-Za-z0-9_-]{10,200}$", options: .regularExpression) != nil,
              user_code.range(of: "^[A-Z0-9]{4}-[A-Z0-9]{4}$", options: .regularExpression) != nil,
              verification_uri == "https://github.com/login/device", (1...1800).contains(expires_in), (1...60).contains(interval) else { throw GitHubIdentityError.invalidResponse }
        return self
    }
}
public struct GitHubTokenReply: Decodable {
    public let access_token: String?
    public let token_type: String?
    public let scope: String?
    public let error: String?
    public let expires_in: Int?
    public func token() throws -> String {
        guard let token = access_token, token.range(of: "^[A-Za-z0-9_-]{10,1024}$", options: .regularExpression) != nil,
              token_type?.lowercased() == "bearer", let scope,
              scope.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              expires_in == nil || (1...31_536_000).contains(expires_in!) else { throw GitHubIdentityError.invalidResponse }
        return token
    }
}
public enum GitHubOAuth {
    public static func validClient(_ id: String) -> Bool { id.range(of: "^[A-Za-z0-9_.-]{10,100}$", options: .regularExpression) != nil }
}
