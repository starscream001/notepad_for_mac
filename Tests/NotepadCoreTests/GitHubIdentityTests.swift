import Foundation
import NotepadCore

enum GitHubIdentityTests {
    static func run() throws {
        XCTAssertEqual(GitHubOAuth.validClient("Iv1.exampleclient123"), true)
        XCTAssertEqual(GitHubOAuth.validClient(""), false)
        let device = try JSONDecoder().decode(GitHubDeviceCode.self, from: Data(#"{"device_code":"test_device_code_123456789","user_code":"ABCD-1234","verification_uri":"https://github.com/login/device","expires_in":900,"interval":5}"#.utf8))
        XCTAssertEqual(try device.validated().interval, 5)
        let foreign = try JSONDecoder().decode(GitHubDeviceCode.self, from: Data(#"{"device_code":"test_device_code_123456789","user_code":"ABCD-1234","verification_uri":"https://evil.example","expires_in":900,"interval":5}"#.utf8))
        do { _ = try foreign.validated(); XCTAssertEqual(true,false) } catch { XCTAssertEqual(error as? GitHubIdentityError, .invalidResponse) }
        let broad = try JSONDecoder().decode(GitHubTokenReply.self, from: Data(#"{"access_token":"gho_TEST_ONLY_TOKEN","token_type":"bearer","scope":"read:user,repo"}"#.utf8))
        do { _ = try broad.token(); XCTAssertEqual(true,false) } catch { XCTAssertEqual(error as? GitHubIdentityError, .invalidResponse) }
        let minimal = try JSONDecoder().decode(GitHubTokenReply.self, from: Data(#"{"access_token":"gho_TEST_ONLY_TOKEN","token_type":"bearer","scope":""}"#.utf8))
        XCTAssertEqual(try minimal.token(), "gho_TEST_ONLY_TOKEN")
        let invalid = try JSONDecoder().decode(GitHubProfile.self, from: Data(#"{"id":42,"login":"../settings","name":null}"#.utf8))
        do { _ = try invalid.validated(); XCTAssertEqual(true,false) } catch { XCTAssertEqual(error as? GitHubIdentityError, .invalidResponse) }
        let profile = try JSONDecoder().decode(GitHubProfile.self, from: Data(#"{"id":42,"login":"test-user","name":"Test"}"#.utf8)).validated()
        XCTAssertEqual(profile.url.absoluteString, "https://github.com/test-user")
    }
}
