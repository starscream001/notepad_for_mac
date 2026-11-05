import Foundation
import NotepadCore

enum ProjectTests {
    static func run() {
        let tab = SessionTab(text: "несохранено 🦊", title: "Заметка 1")
        var session = Session(tabs: [tab], selected: tab.id)
        var legacy = try! JSONSerialization.jsonObject(with: JSONEncoder().encode(session)) as! [String: Any]
        legacy.removeValue(forKey: "projects"); legacy.removeValue(forKey: "selectedProject")
        let migrated = try! JSONDecoder().decode(Session.self, from: JSONSerialization.data(withJSONObject: legacy))
        XCTAssertEqual(migrated.tabs[0].text, tab.text); XCTAssertEqual(migrated.projects == nil, true)
        var project = SessionProject(title: "Работа", selected: tab.id); project.collapsed = true
        session.archivedTabs = [tab]; session.deletedNoteIDs = [UUID()]
        session.looseSelected = tab.id
        session.projects = [project]; session.selectedProject = project.id; session.tabs[0].projectID = project.id
        let restored = try! JSONDecoder().decode(Session.self, from: JSONEncoder().encode(session))
        XCTAssertEqual(restored.tabs[0].projectID, project.id); XCTAssertEqual(restored.projects?[0].selected, tab.id)
        XCTAssertEqual(restored.archivedTabs?[0].text,tab.text)
        XCTAssertEqual(restored.deletedNoteIDs?.count,1)
        XCTAssertEqual(restored.looseSelected, tab.id)
        XCTAssertEqual(restored.projects?[0].collapsed, true); XCTAssertEqual(restored.tabs[0].text, tab.text)
    }
}
