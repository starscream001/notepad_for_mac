import Foundation
import NotepadCore

enum SyncFailureTests {
    static func run() {
        let missing=GitHubSyncHTTPFailure(status:404,stage:"repository")
        XCTAssertEqual(missing.needsRepositoryAccess,true)
        XCTAssertEqual(missing.message(english:false).contains("HTTP 404"),true)
        XCTAssertEqual(missing.message(english:true).contains("repository check"),true)
        let rate=GitHubSyncHTTPFailure(status:403,stage:"read",rateLimited:true)
        XCTAssertEqual(rate.needsRepositoryAccess,false)
        XCTAssertEqual(rate.message(english:true).contains("request limit"),true)
        XCTAssertEqual(GitHubSyncHTTPFailure(status:409,stage:"branch").message(english:true).contains("README"),true)
        XCTAssertEqual(GitHubSyncHTTPFailure(status:422,stage:"update").message(english:true).contains("No forced overwrite"),true)
    }
}
