import Foundation
import JavaScriptCore

enum SyncScriptTests {
    static func run() throws {
        let context=JSContext()!
        context.evaluateScript(try String(contentsOfFile:"Resources/SyncCore.js",encoding:.utf8))
        let sample="{\"schema\":1,\"projects\":[],\"tabs\":[{\"id\":\"11111111-1111-4111-8111-111111111111\",\"projectId\":null,\"title\":\"Заметка\",\"text\":\"Привет 🦊\"}]}"
        // Native bridge supplies the serialized empty base, never a JS null argument.
        let empty="{\"schema\":1,\"projects\":[],\"tabs\":[]}"
        let result=context.objectForKeyedSubscript("NotepadSync")!.objectForKeyedSubscript("mergeJSON")!.call(withArguments:[empty,sample,empty,"[]"])!.toString()!
        XCTAssertEqual(context.exception == nil,true)
        let value=try JSONSerialization.jsonObject(with:Data(result.utf8)) as! [String:Any]
        let snapshot=value["snapshot"] as! [String:Any]
        XCTAssertEqual((snapshot["tabs"] as! [[String:Any]])[0]["text"] as? String,"Привет 🦊")
        let deleted="{\"schema\":1,\"projects\":[],\"tabs\":[],\"deleted\":[\"11111111-1111-4111-8111-111111111111\"]}"
        let removal=context.objectForKeyedSubscript("NotepadSync")!.objectForKeyedSubscript("mergeJSON")!.call(withArguments:[sample,deleted,sample,"[]"])!.toString()!
        let removed=try JSONSerialization.jsonObject(with:Data(removal.utf8)) as! [String:Any]
        XCTAssertEqual(((removed["snapshot"] as! [String:Any])["tabs"] as! [Any]).count,0)
        let projectID="33333333-3333-4333-8333-333333333333"
        let projectBase="{\"schema\":1,\"projects\":[{\"id\":\"\(projectID)\",\"title\":\"Work\"}],\"tabs\":[]}"
        let projectDeleted="{\"schema\":1,\"projects\":[],\"tabs\":[],\"deletedProjects\":[\"\(projectID)\"]}"
        let projectRemoval=context.objectForKeyedSubscript("NotepadSync")!.objectForKeyedSubscript("mergeJSON")!.call(withArguments:[projectBase,projectDeleted,projectBase,"[]"])!.toString()!
        XCTAssertEqual(context.exception == nil,true)
        let projectResult=(try JSONSerialization.jsonObject(with:Data(projectRemoval.utf8)) as! [String:Any])["snapshot"] as! [String:Any]
        XCTAssertEqual((projectResult["projects"] as! [Any]).count,0)
        XCTAssertEqual(projectResult["deletedProjects"] as? [String],[projectID])

    }
}
