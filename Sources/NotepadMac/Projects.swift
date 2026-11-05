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
        projectPane.edgeInsets = NSEdgeInsets(top: 8, left: 10, bottom: 8, right: 10)
        if projectPane.constraints.first(where: { $0.firstAttribute == .width }) == nil { projectPane.widthAnchor.constraint(equalToConstant: 190).isActive = true }
        let title=NSTextField(labelWithString:InterfaceLanguage.english ? "Projects" : "Проекты");title.font = .systemFont(ofSize:12,weight:.semibold);title.textColor = .secondaryLabelColor
        let add=iconButton(InterfaceLanguage.english ? "New project" : "Создать проект",#selector(createProject),symbol:"plus")
        let header=NSStackView(views:[title,NSView(),add]);header.orientation = .horizontal;header.alignment = .centerY;header.spacing=6
        header.widthAnchor.constraint(equalToConstant:170).isActive=true;header.heightAnchor.constraint(equalToConstant:30).isActive=true;projectPane.addArrangedSubview(header)
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
        let signature = String(InterfaceLanguage.english) + String(describing: selectedProjectID) + String(describing: selectedID) + projects.map { $0.id.uuidString + $0.title + String($0.collapsed ?? false) }.joined() + tabs.map { $0.snapshot.id.uuidString + $0.snapshot.title + String($0.dirty) }.joined() + archivedTabs.map { $0.id.uuidString + $0.title }.joined()
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
            pick.cell = SidebarNoteCell(textCell: title); pick.target = self; pick.action = #selector(pickProject(_:)); pick.identifier = disclosure.identifier
            pick.setButtonType(.pushOnPushOff); pick.state = id == selectedProjectID ? .on : .off; pick.alignment = .left; pick.lineBreakMode = .byTruncatingTail
            pick.bezelStyle = .smallSquare; pick.font = .systemFont(ofSize: 12, weight: .medium); pick.heightAnchor.constraint(equalToConstant: 30).isActive = true
            if let id { pick.onRename = { [weak self] in self?.renameProject(id) } }
            row.addArrangedSubview(disclosure); row.addArrangedSubview(pick)
            pick.setContentCompressionResistancePriority(.defaultLow,for:.horizontal)
            if let id { let trash=iconButton(InterfaceLanguage.english ? "Delete project" : "Удалить проект",#selector(deleteProjectButton(_:)),symbol:"trash");trash.identifier=NSUserInterfaceItemIdentifier(id.uuidString);row.addArrangedSubview(trash) }
            projectRows.addArrangedSubview(row); row.widthAnchor.constraint(equalTo: projectRows.widthAnchor).isActive = true
            if !collapsed {
                for tab in tabs where tab.snapshot.projectID == id {
                    let label = (tab.dirty ? "● " : "") + tab.snapshot.title
                    let entry = RenamableButton(title: label, target: self, action: #selector(selectTab(_:)))
                    entry.cell=SidebarNoteCell(textCell:label);entry.target=self;entry.action=#selector(selectTab(_:));entry.bezelStyle = .smallSquare;entry.setButtonType(.pushOnPushOff);entry.state=tab.snapshot.id==selectedID ? .on : .off;entry.isBordered = true; entry.alignment = .left; entry.font = .systemFont(ofSize: 12, weight: tab.snapshot.id == selectedID ? .semibold : .regular); entry.lineBreakMode = .byTruncatingTail
                    entry.identifier = NSUserInterfaceItemIdentifier(tab.snapshot.id.uuidString); entry.toolTip = displayTitle(tab)
                    entry.setAccessibilityLabel(displayTitle(tab)); entry.heightAnchor.constraint(equalToConstant: 28).isActive = true
                    entry.onRename = { [weak self, weak tab] in if let tab { self?.renameTab(tab) } }
                    addProjectEntry(entry)
                }
                for snapshot in archivedTabs where snapshot.projectID == id {
                    let entry=NSButton(title:snapshot.title,target:self,action:#selector(reopenNote(_:)));entry.isBordered=false;entry.alignment = .left;entry.font = .systemFont(ofSize:12);entry.contentTintColor = .secondaryLabelColor;entry.identifier=NSUserInterfaceItemIdentifier(snapshot.id.uuidString);entry.heightAnchor.constraint(equalToConstant:28).isActive=true;addProjectEntry(entry)
                }
            }
        }
    }
    func addProjectEntry(_ entry:NSButton) {
        let indent=NSView();indent.widthAnchor.constraint(equalToConstant:24).isActive=true
        let trash=iconButton(InterfaceLanguage.english ? "Delete note" : "Удалить заметку",#selector(deleteSidebarNote(_:)),symbol:"trash");trash.identifier=entry.identifier
        let row=NSStackView(views:[indent,entry,trash]);row.orientation = .horizontal;row.alignment = .centerY;row.spacing=0
        entry.setContentCompressionResistancePriority(.defaultLow,for:.horizontal);entry.setContentHuggingPriority(.defaultLow,for:.horizontal)
        projectRows.addArrangedSubview(row);row.widthAnchor.constraint(equalTo:projectRows.widthAnchor).isActive=true
    }
    @objc func reopenNote(_ sender:NSButton) {
        guard let index=archivedTabs.firstIndex(where:{$0.id.uuidString==sender.identifier?.rawValue}) else { return };let snapshot=archivedTabs.remove(at:index);let tab=EditorTab(snapshot,fontSize:fontSize,wrap:wrap);tab.textView.delegate=self;tabs.append(tab);select(tab);rebuildTabs();schedulePersistence()
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
        else { showEmptyProject() }
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
    func showEmptyProject() {
        selectedID=nil
        if let index=projects.firstIndex(where:{$0.id==selectedProjectID}) { projects[index].selected=nil } else { looseSelected=nil }
        editorHost.subviews.forEach { $0.removeFromSuperview() }
        let label=NSTextField(labelWithString:InterfaceLanguage.english ? "No open notes. Press + to create a note or open one from the sidebar." : "Нет открытых заметок. Нажмите + или откройте заметку слева.")
        label.font = .systemFont(ofSize:13);label.textColor = .secondaryLabelColor;label.translatesAutoresizingMaskIntoConstraints=false;editorHost.addSubview(label)
        NSLayoutConstraint.activate([label.leadingAnchor.constraint(equalTo:editorHost.leadingAnchor,constant:24),label.trailingAnchor.constraint(lessThanOrEqualTo:editorHost.trailingAnchor,constant:-24),label.topAnchor.constraint(equalTo:editorHost.topAnchor,constant:24)])
        status.stringValue="";pathLabel.stringValue="";refreshPreview();rebuildTabs();schedulePersistence()
    }
    @MainActor @objc func deleteSidebarNote(_ sender:NSButton) {
        guard let id=sender.identifier.flatMap({UUID(uuidString:$0.rawValue)}) else { return };removeNote(id)
    }
    @MainActor @objc func deleteProjectButton(_ sender:NSButton) {
        guard let id=sender.identifier.flatMap({UUID(uuidString:$0.rawValue)}),let project=projects.first(where:{$0.id==id}) else { return }
        let count=tabs.filter{$0.snapshot.projectID==id}.count+archivedTabs.filter{$0.projectID==id}.count
        let alert=NSAlert();alert.messageText=InterfaceLanguage.english ? "Delete project \(project.title)?" : "Удалить проект «\(project.title)»?"
        alert.informativeText=InterfaceLanguage.english ? "All \(count) notes, including closed notes, will be deleted. GitHub is updated on the next synchronization. External files are kept." : "Будут удалены все заметки (\(count)), включая закрытые. GitHub обновится при следующей синхронизации. Внешние файлы останутся на диске."
        alert.addButton(withTitle:InterfaceLanguage.english ? "Cancel" : "Отмена");alert.addButton(withTitle:InterfaceLanguage.english ? "Delete project" : "Удалить проект")
        guard alert.runModal() == .alertSecondButtonReturn, backupBeforeDelete() else { return }
        deletedProjectIDs.insert(id)
        for tab in tabs where tab.snapshot.projectID==id { deletedNoteIDs.insert(tab.snapshot.id);tab.highlightWork?.cancel() }
        for note in archivedTabs where note.projectID==id { deletedNoteIDs.insert(note.id) }
        tabs.removeAll{$0.snapshot.projectID==id};archivedTabs.removeAll{$0.projectID==id};projects.removeAll{$0.id==id}
        if selectedProjectID==id { switchProject(nil) };rebuildTabs();persist()
    }

}
