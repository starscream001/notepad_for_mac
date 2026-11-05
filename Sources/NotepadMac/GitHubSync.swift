import AppKit
import JavaScriptCore
import NotepadCore

@MainActor enum SyncEngine {
    static func invoke(_ method: String, _ arguments: [Any]) throws -> JSValue {
        guard let url = Bundle.main.url(forResource:"SyncCore",withExtension:"js"), let script = try? String(contentsOf:url), let context = JSContext() else { throw GitHubIdentityError.invalidResponse }
        context.evaluateScript(script)
        guard let function = context.objectForKeyedSubscript("NotepadSync")?.objectForKeyedSubscript(method), let result = function.call(withArguments:arguments), !result.isUndefined, context.exception == nil else { throw GitHubIdentityError.invalidResponse }
        return result
    }
    static func clean(_ value: [String:Any]) throws -> String { guard let result = try invoke("stringify",[value]).toString() else { throw GitHubIdentityError.invalidResponse };return result }
    static func merge(_ base: String?, _ local: String, _ remote: String) throws -> (String,Int) {
        let empty = "{\"schema\":1,\"projects\":[],\"tabs\":[]}"
        let ids = try JSONSerialization.data(withJSONObject:(0..<300).map { _ in UUID().uuidString.lowercased() })
        guard let text = try invoke("mergeJSON",[base ?? empty,local,remote,String(decoding:ids,as:UTF8.self)]).toString(), let object = try JSONSerialization.jsonObject(with:Data(text.utf8)) as? [String:Any],let snapshot = object["snapshot"] as? [String:Any] else { throw GitHubIdentityError.invalidResponse }
        return (try clean(snapshot),object["conflicts"] as? Int ?? 0)
    }
}
@MainActor extension AppDelegate {
    func portableNotes() throws -> String {
        let records=tabs.map { $0.capture() } + archivedTabs
        return try SyncEngine.clean(["schema":1,"deleted":deletedNoteIDs.map { $0.uuidString.lowercased() },"projects":projects.map { ["id":$0.id.uuidString.lowercased(),"title":$0.title] },"tabs":records.map { tab -> [String:Any] in ["id":tab.id.uuidString.lowercased(),"projectId":tab.projectID.map { $0.uuidString.lowercased() } as Any? ?? NSNull(),"title":tab.title,"text":tab.text] }])
    }
    func applyCloudNotes(_ text: String) throws {
        guard let object = try JSONSerialization.jsonObject(with:Data(text.utf8)) as? [String:Any],let ps=object["projects"] as? [[String:Any]],let ts=object["tabs"] as? [[String:Any]] else { throw GitHubIdentityError.invalidResponse }
        guard persist() else { throw GitHubIdentityError.storage }
        let backup=sessionURL.deletingLastPathComponent().appendingPathComponent("session.before-sync.json")
        try Data(contentsOf:sessionURL).write(to:backup,options:.atomic)
        let oldProjects=projects,oldTabs=tabs,oldSnapshots=tabs.map { $0.capture() },oldArchive=archivedTabs,oldDeleted=deletedNoteIDs
        deletedNoteIDs=Set((object["deleted"] as? [String] ?? []).compactMap(UUID.init(uuidString:)))
        let oldSelected=selectedID
        projects=try ps.map { p in guard let id=(p["id"] as? String).flatMap(UUID.init(uuidString:)),let title=p["title"] as? String else { throw GitHubIdentityError.invalidResponse };var project=oldProjects.first { $0.id==id } ?? SessionProject(id:id,title:title);project.title=title;return project }
        var next:[EditorTab]=[];var nextArchive:[SessionTab]=[]
        for t in ts {
            guard let id=(t["id"] as? String).flatMap(UUID.init(uuidString:)),let title=t["title"] as? String,let text=t["text"] as? String else { throw GitHubIdentityError.invalidResponse }
            let project=(t["projectId"] as? String).flatMap(UUID.init(uuidString:))
            if var archived=oldArchive.first(where:{$0.id==id}) { archived.title=title;archived.projectID=project;archived.text=text;nextArchive.append(archived);continue }
            if let tab=oldTabs.first(where:{$0.snapshot.id==id}) { tab.snapshot.title=title;tab.snapshot.projectID=project;if tab.textView.string != text { tab.textView.string=text;tab.highlight() };next.append(tab) }
            else { var snapshot=SessionTab(id:id,text:text,title:title);snapshot.projectID=project;snapshot.syntaxLanguage=Syntax.language(for:(title as NSString).pathExtension);let tab=EditorTab(snapshot,fontSize:fontSize,wrap:wrap);tab.textView.delegate=self;next.append(tab) }
        }
        tabs=next;archivedTabs=nextArchive
        guard persist() else {
            projects=oldProjects;tabs=oldTabs;archivedTabs=oldArchive;deletedNoteIDs=oldDeleted;for (tab,snapshot) in zip(tabs,oldSnapshots) { tab.snapshot=snapshot;tab.textView.string=snapshot.text };throw GitHubIdentityError.storage
        }
        if let tab=tabs.first(where:{$0.snapshot.id==oldSelected}) ?? tabs.first { select(tab) };rebuildTabs();updateTabLabels();schedulePersistence()
    }
}

@MainActor extension AppDelegate {
    @objc func showGitHubSync() {
        showPreferences()
        if githubAccount.profile != nil { githubSettingsView?.synchronize() }
    }
    @objc func deleteNote() {
        guard let tab=current else { return }
        let alert=NSAlert();alert.messageText=InterfaceLanguage.english ? "Delete note?" : "Удалить заметку?"
        alert.informativeText=InterfaceLanguage.english ? "The note is removed locally and from GitHub after synchronization. An external file on disk is kept." : "Заметка удалится локально, а после синхронизации — из GitHub. Внешний файл на диске не удаляется."
        alert.addButton(withTitle:InterfaceLanguage.english ? "Cancel" : "Отмена");alert.addButton(withTitle:InterfaceLanguage.english ? "Delete" : "Удалить")
        guard alert.runModal() == .alertSecondButtonReturn else { return }
        guard persist() else { return }
        do { try Data(contentsOf:sessionURL).write(to:sessionURL.deletingLastPathComponent().appendingPathComponent("session.before-delete.json"),options:.atomic) } catch { showError(error);return }
        deletedNoteIDs.insert(tab.snapshot.id);archivedTabs.removeAll { $0.id==tab.snapshot.id };tabs.removeAll { $0 === tab }
        if let next=visibleTabs.first { select(next) } else { newDocument(nil) };rebuildTabs();persist()
    }
}
