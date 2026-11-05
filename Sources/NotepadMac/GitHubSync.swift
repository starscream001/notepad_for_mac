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
        return try SyncEngine.clean(["schema":1,"deletedProjects":deletedProjectIDs.map { $0.uuidString.lowercased() },"deleted":deletedNoteIDs.map { $0.uuidString.lowercased() },"projects":projects.map { ["id":$0.id.uuidString.lowercased(),"title":$0.title] },"tabs":records.map { tab -> [String:Any] in ["id":tab.id.uuidString.lowercased(),"projectId":tab.projectID.map { $0.uuidString.lowercased() } as Any? ?? NSNull(),"title":tab.title,"text":tab.text] }])
    }
    func applyCloudNotes(_ text: String) throws {
        guard let object = try JSONSerialization.jsonObject(with:Data(text.utf8)) as? [String:Any],let ps=object["projects"] as? [[String:Any]],let ts=object["tabs"] as? [[String:Any]] else { throw GitHubIdentityError.invalidResponse }
        guard persist() else { throw GitHubIdentityError.storage }
        let backup=sessionURL.deletingLastPathComponent().appendingPathComponent("session.before-sync.json")
        try Data(contentsOf:sessionURL).write(to:backup,options:.atomic)
        let oldProjects=projects,oldTabs=tabs,oldSnapshots=tabs.map { $0.capture() },oldArchive=archivedTabs,oldDeleted=deletedNoteIDs,oldDeletedProjects=deletedProjectIDs
        deletedNoteIDs=Set((object["deleted"] as? [String] ?? []).compactMap(UUID.init(uuidString:)))
        deletedProjectIDs=Set((object["deletedProjects"] as? [String] ?? []).compactMap(UUID.init(uuidString:)))
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
            projects=oldProjects;tabs=oldTabs;archivedTabs=oldArchive;deletedNoteIDs=oldDeleted;deletedProjectIDs=oldDeletedProjects;for (tab,snapshot) in zip(tabs,oldSnapshots) { tab.snapshot=snapshot;tab.textView.string=snapshot.text };throw GitHubIdentityError.storage
        }
        if !projects.contains(where:{$0.id==selectedProjectID}) { selectedProjectID=nil }
        if let tab=visibleTabs.first(where:{$0.snapshot.id==oldSelected}) ?? visibleTabs.first { select(tab) } else { showEmptyProject() };rebuildTabs();updateTabLabels();schedulePersistence()
    }
}

@MainActor extension AppDelegate {
    @objc func showGitHubSync() {
        if let synchronizationPanel { synchronizationPanel.makeKeyAndOrderFront(nil);return }
        let panel=NSPanel(contentRect:NSRect(x:0,y:0,width:410,height:540),styleMask:[.titled,.closable],backing:.buffered,defer:false)
        panel.title=InterfaceLanguage.english ? "Synchronization" : "Синхронизация";panel.isReleasedWhenClosed=false
        let stack=EditorListStack();stack.orientation = .vertical;stack.alignment = .leading;stack.spacing=16;stack.edgeInsets=NSEdgeInsets(top:24,left:24,bottom:24,right:24)
        let provider=button("GitHub ›",#selector(toggleGitHubOptions(_:)))
        provider.setAccessibilityLabel("GitHub");stack.addArrangedSubview(provider)
        let view=GitHubSettingsView(account:githubAccount);githubSettingsView=view;view.isHidden=true;stack.addArrangedSubview(view)
        let scroll=NSScrollView();scroll.hasVerticalScroller=true;scroll.autohidesScrollers=true;scroll.drawsBackground=false;scroll.documentView=stack;stack.translatesAutoresizingMaskIntoConstraints=false
        NSLayoutConstraint.activate([stack.widthAnchor.constraint(equalToConstant:410),stack.leadingAnchor.constraint(equalTo:scroll.contentView.leadingAnchor),stack.topAnchor.constraint(equalTo:scroll.contentView.topAnchor)])
        panel.contentView=scroll;synchronizationPanel=panel;panel.center();panel.makeKeyAndOrderFront(nil)
    }
    @objc func toggleGitHubOptions(_ sender:NSButton) {
        guard let view=githubSettingsView else { return };view.isHidden.toggle();sender.title=view.isHidden ? "GitHub ›" : "GitHub ⌄"
    }
    @objc func deleteNote() { if let id=current?.snapshot.id { removeNote(id) } }
    func backupBeforeDelete() -> Bool {
        guard persist() else { return false }
        do { try Data(contentsOf:sessionURL).write(to:sessionURL.deletingLastPathComponent().appendingPathComponent("session.before-delete.json"),options:.atomic);return true } catch { showError(error);return false }
    }
    func removeNote(_ id:UUID) {
        guard let title=tabs.first(where:{$0.snapshot.id==id})?.snapshot.title ?? archivedTabs.first(where:{$0.id==id})?.title else { return }
        let alert=NSAlert();alert.messageText=InterfaceLanguage.english ? "Delete note \(title)?" : "Удалить заметку «\(title)»?"
        alert.informativeText=InterfaceLanguage.english ? "The note is removed locally and from GitHub after synchronization. An external file on disk is kept." : "Заметка удалится локально, а после синхронизации — из GitHub. Внешний файл на диске не удаляется."
        alert.addButton(withTitle:InterfaceLanguage.english ? "Cancel" : "Отмена");alert.addButton(withTitle:InterfaceLanguage.english ? "Delete" : "Удалить")
        guard alert.runModal() == .alertSecondButtonReturn, backupBeforeDelete() else { return }
        tabs.first(where:{$0.snapshot.id==id})?.highlightWork?.cancel()
        deletedNoteIDs.insert(id);archivedTabs.removeAll { $0.id==id };tabs.removeAll { $0.snapshot.id==id }
        if selectedID==id { if let next=visibleTabs.first { select(next) } else { showEmptyProject() } };rebuildTabs();persist()
    }
}
