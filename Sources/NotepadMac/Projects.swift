import AppKit
import NotepadCore

extension AppDelegate {
    func displayTitle(_ tab: EditorTab) -> String {
        guard let project = projects.first(where: { $0.id == tab.snapshot.projectID }) else { return tab.snapshot.title }
        return project.title + "." + tab.snapshot.title
    }
    func configureProjects() {
        projectPane.arrangedSubviews.forEach { projectPane.removeArrangedSubview($0); $0.removeFromSuperview() }
        projectPane.orientation = .vertical; projectPane.alignment = .leading; projectPane.spacing = 8
        projectPane.edgeInsets = NSEdgeInsets(top: 10, left: 10, bottom: 10, right: 10)
        if projectPane.constraints.first(where: { $0.firstAttribute == .width }) == nil { projectPane.widthAnchor.constraint(equalToConstant: 210).isActive = true }
        let header = button(InterfaceLanguage.english ? "+ Project" : "+ Проект", #selector(createProject))
        projectPane.addArrangedSubview(header)
        projectRows.orientation = .vertical; projectRows.alignment = .leading; projectRows.spacing = 4
        let scroll = NSScrollView(); scroll.drawsBackground = false; scroll.hasVerticalScroller = true; scroll.autohidesScrollers = true; scroll.documentView = projectRows
        scroll.translatesAutoresizingMaskIntoConstraints = false; projectRows.translatesAutoresizingMaskIntoConstraints = false
        projectPane.addArrangedSubview(scroll)
        NSLayoutConstraint.activate([scroll.widthAnchor.constraint(equalTo: projectPane.widthAnchor, constant: -20), scroll.heightAnchor.constraint(greaterThanOrEqualToConstant: 80), projectRows.widthAnchor.constraint(equalTo: scroll.contentView.widthAnchor), projectRows.leadingAnchor.constraint(equalTo: scroll.contentView.leadingAnchor), projectRows.topAnchor.constraint(equalTo: scroll.contentView.topAnchor)])
        projectPane.isHidden = UserDefaults.standard.bool(forKey: "projectsHidden")
        rebuildProjects()
    }
    @objc func toggleProjects() {
        projectPane.isHidden.toggle(); UserDefaults.standard.set(projectPane.isHidden, forKey: "projectsHidden")
    }
    func rebuildProjects() {
        let signature = String(InterfaceLanguage.english) + String(describing: selectedProjectID) + String(describing: selectedID) + projects.map { $0.id.uuidString + $0.title + String($0.collapsed ?? false) }.joined() + tabs.map { $0.snapshot.id.uuidString + $0.snapshot.title + String($0.dirty) }.joined()
        guard signature != projectSignature || projectRows.arrangedSubviews.isEmpty else { return }; projectSignature = signature
        projectRows.arrangedSubviews.forEach { projectRows.removeArrangedSubview($0); $0.removeFromSuperview() }
        let groups: [(UUID?, String, Bool)] = [(nil, InterfaceLanguage.english ? "Without project" : "Без проекта", false)] + projects.map { ($0.id, $0.title, $0.collapsed ?? false) }
        for (id, title, collapsed) in groups {
            let row = NSStackView(); row.orientation = .horizontal; row.spacing = 4
            let disclosure = NSButton(title: collapsed ? "›" : "⌄", target: self, action: #selector(collapseProject(_:)))
            disclosure.isBordered = false; disclosure.identifier = NSUserInterfaceItemIdentifier(id?.uuidString ?? "loose"); disclosure.setAccessibilityLabel(title + (collapsed ? " · expand" : " · collapse"))
            disclosure.widthAnchor.constraint(equalToConstant: 20).isActive = true
            if id == nil { disclosure.isEnabled = false }
            let pick = RenamableButton(title: title, target: self, action: #selector(pickProject(_:)))
            pick.cell = EditorButtonCell(textCell: title); pick.target = self; pick.action = #selector(pickProject(_:)); pick.identifier = disclosure.identifier
            pick.setButtonType(.pushOnPushOff); pick.state = id == selectedProjectID ? .on : .off; pick.alignment = .left; pick.lineBreakMode = .byTruncatingTail
            pick.font = .systemFont(ofSize: 13, weight: .semibold); pick.heightAnchor.constraint(equalToConstant: 30).isActive = true
            if let id { pick.onRename = { [weak self] in self?.renameProject(id) } }
            row.addArrangedSubview(disclosure); row.addArrangedSubview(pick); projectRows.addArrangedSubview(row); row.widthAnchor.constraint(equalTo: projectRows.widthAnchor).isActive = true
            if !collapsed {
                for tab in tabs where tab.snapshot.projectID == id {
                    let label = (tab.dirty ? "● " : "") + tab.snapshot.title
                    let entry = RenamableButton(title: label, target: self, action: #selector(selectTab(_:)))
                    entry.isBordered = false; entry.alignment = .left; entry.font = .systemFont(ofSize: 12, weight: tab.snapshot.id == selectedID ? .semibold : .regular); entry.lineBreakMode = .byTruncatingTail
                    entry.identifier = NSUserInterfaceItemIdentifier(tab.snapshot.id.uuidString); entry.toolTip = displayTitle(tab)
                    entry.setAccessibilityLabel(displayTitle(tab)); entry.heightAnchor.constraint(equalToConstant: 28).isActive = true
                    entry.onRename = { [weak self, weak tab] in if let tab { self?.renameTab(tab) } }
                    projectRows.addArrangedSubview(entry); entry.widthAnchor.constraint(equalTo: projectRows.widthAnchor).isActive = true
                }
            }
        }
    }
    @objc func collapseProject(_ sender: NSButton) {
        guard let index = projects.firstIndex(where: { $0.id.uuidString == sender.identifier?.rawValue }) else { return }
        projects[index].collapsed = !(projects[index].collapsed ?? false); rebuildProjects(); schedulePersistence()
    }
    @objc func pickProject(_ sender: NSButton) {
        switchProject(projects.first(where: { $0.id.uuidString == sender.identifier?.rawValue })?.id)
    }
    func switchProject(_ id: UUID?) {
        selectedProjectID = id
        let remembered = projects.first(where: { $0.id == id })?.selected ?? (id == nil ? looseSelected : nil)
        if let tab = visibleTabs.first(where: { $0.snapshot.id == remembered }) ?? visibleTabs.first { select(tab) }
        else { newDocument(nil) }
        rebuildTabs(); schedulePersistence()
    }
    func namePrompt(_ title: String, value: String) -> String? {
        let alert = NSAlert(); alert.messageText = title
        let field = NSTextField(string: value); field.frame = NSRect(x: 0, y: 0, width: 300, height: 26)
        alert.accessoryView = field; alert.addButton(withTitle: InterfaceLanguage.english ? "Save" : "Сохранить"); alert.addButton(withTitle: L("Отмена")); alert.window.initialFirstResponder = field
        guard alert.runModal() == .alertFirstButtonReturn else { return nil }
        let name = field.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, name.count <= 80, !name.contains("\n"), !name.contains("/"), !name.contains("\\") else { NSSound.beep(); return nil }
        return name
    }
    @objc func createProject() {
        guard projects.count < 100 else { return }
        let base = InterfaceLanguage.english ? "Project" : "Проект"
        var n = 1; while projects.contains(where: { $0.title == "\(base) \(n)" }) { n += 1 }
        guard let name = namePrompt(InterfaceLanguage.english ? "New project" : "Новый проект", value: "\(base) \(n)") else { return }
        let project = SessionProject(title: name); projects.append(project); selectedProjectID = project.id; newDocument(nil); rebuildTabs()
    }
    func renameProject(_ id: UUID) {
        guard let index = projects.firstIndex(where: { $0.id == id }), let name = namePrompt(InterfaceLanguage.english ? "Rename project" : "Переименовать проект", value: projects[index].title) else { return }
        projects[index].title = name; rebuildTabs(); updateTabLabels(); persist()
    }
    func renameTab(_ tab: EditorTab) {
        guard let name = namePrompt(InterfaceLanguage.english ? "Rename tab" : "Переименовать вкладку", value: tab.snapshot.title) else { return }
        tab.snapshot.title = name; tab.textView.setAccessibilityLabel(name); rebuildTabs(); updateTabLabels(); persist()
    }
}
