import AppKit
import NotepadCore

final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate, NSTextViewDelegate {
    var window: NSWindow!
    lazy var updater = AppUpdater(app: self)
    var formatting = false
    var preferencesPanel: NSPanel?
    var tabs: [EditorTab] = []
    var selectedID: UUID?
    var current: EditorTab? { tabs.first { $0.snapshot.id == selectedID } }
    let tabStack = NSStackView()
    let editorHost = NSView()
    let splitController = NSSplitViewController()
    var editorSplit: NSSplitView { splitController.splitView }
    var previewItem: NSSplitViewItem!
    let previewPane = PreviewPane()
    var previewEnabled = false
    var previewButton: NSButton!
    let status = NSTextField(labelWithString: "")
    let pathLabel = NSTextField(labelWithString: "")
    let findStack = NSStackView()
    let searchField = NSSearchField()
    let replaceField = NSTextField()
    let caseButton = NSButton(checkboxWithTitle: L("Регистр"), target: nil, action: nil)
    let regexButton = NSButton(checkboxWithTitle: ".* Regex", target: nil, action: nil)
    let findStatus = NSTextField(labelWithString: "")
    let languagePopup = NSPopUpButton()
    let encodingPopup = NSPopUpButton()
    let endingPopup = NSPopUpButton()
    let themePopup = NSPopUpButton()
    let palettePopup = NSPopUpButton()
    var tabButtons: [UUID: NSButton] = [:]
    var tabSurfaces: [UUID: TabSurface] = [:]
    var tabListPanel: NSPanel?
    let tabListSearch = NSSearchField()
    let tabListRows = EditorListStack()
    var persistenceWork: DispatchWorkItem?
    var didWarnPersistence = false
    var sessionWriteBlocked = false
    var fontSize: CGFloat = 14
    var wrap = true
    var sessionURL: URL {
        if let override = ProcessInfo.processInfo.environment["NOTEPAD_SESSION_DIR"] {
            return URL(fileURLWithPath: override).appendingPathComponent("session.json")
        }
        return FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("NotepadMac/session.json")
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        fontSize = CGFloat(UserDefaults.standard.double(forKey: "fontSize"))
        if fontSize < 10 { fontSize = 14 }
        wrap = UserDefaults.standard.object(forKey: "wrap") as? Bool ?? true
        makeMenu(); makeWindow(); restore()
        for argument in CommandLine.arguments.dropFirst() where !argument.hasPrefix("-") {
            openURL(URL(fileURLWithPath: argument))
        }
        if tabs.isEmpty { newDocument(nil) }
        window.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps: true)
        updater.start()

    }

    func makeMenu() {
        let main = NSMenu()
        func submenu(_ title: String) -> NSMenu {
            let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
            let menu = NSMenu(title: title); item.submenu = menu; main.addItem(item); return menu
        }
        func item(_ menu: NSMenu, _ title: String, _ action: Selector, _ key: String = "", _ modifiers: NSEvent.ModifierFlags = .command) {
            let entry = NSMenuItem(title: title, action: action, keyEquivalent: key)
            entry.keyEquivalentModifierMask = modifiers; menu.addItem(entry)
        }
        let app = submenu("Notepad Mac")
        item(app, L("Настройки…"), #selector(showPreferences), ",")
        item(app, L("О Notepad Mac"), #selector(about))
        item(app, L("Проверить обновления…"), #selector(checkForUpdates))
        item(app, L("Настройки обновлений…"), #selector(updateSettings))
        item(app, L("Поддержать разработчика…"), #selector(supportDeveloper))
        app.addItem(.separator())
        item(app, L("Скрыть Notepad Mac"), #selector(NSApplication.hide(_:)), "h")
        item(app, L("Завершить Notepad Mac"), #selector(NSApplication.terminate(_:)), "q")
        let file = submenu(L("Файл"))
        item(file, L("Новая вкладка"), #selector(newDocument(_:)), "n")
        item(file, L("Открыть…"), #selector(openDocument(_:)), "o")
        let recentItem = NSMenuItem(title: L("Недавние файлы"), action: nil, keyEquivalent: "")
        let recentMenu = NSMenu(title: L("Недавние файлы"))
        recentItem.submenu = recentMenu; file.addItem(recentItem)
        NSDocumentController.shared.recentDocumentURLs.prefix(12).forEach { url in
            let entry = NSMenuItem(title: url.lastPathComponent, action: #selector(openRecent(_:)), keyEquivalent: "")
            entry.representedObject = url; recentMenu.addItem(entry)
        }
        file.addItem(.separator())
        item(file, L("Сохранить"), #selector(saveDocument(_:)), "s")
        item(file, L("Сохранить как…"), #selector(saveAs(_:)), "s", [.command, .shift])
        item(file, L("Закрыть вкладку"), #selector(closeCurrent(_:)), "w")
        let edit = submenu(L("Правка"))
        item(edit, L("Отменить"), Selector(("undo:")), "z")
        item(edit, L("Повторить"), Selector(("redo:")), "z", [.command, .shift])
        edit.addItem(.separator())
        item(edit, L("Вырезать"), #selector(NSText.cut(_:)), "x")
        item(edit, L("Копировать"), #selector(NSText.copy(_:)), "c")
        item(edit, L("Вставить"), #selector(NSText.paste(_:)), "v")
        item(edit, L("Выделить всё"), #selector(NSText.selectAll(_:)), "a")
        edit.addItem(.separator())
        item(edit, L("Форматировать"), #selector(formatDocument(_:)), "f", [.command, .shift])
        let search = submenu(L("Поиск"))
        item(search, L("Найти / заменить…"), #selector(showFind(_:)), "f")
        item(search, L("Найти далее"), #selector(findNext(_:)), "g")
        item(search, L("Найти предыдущее"), #selector(findPrevious(_:)), "g", [.command, .shift])
        item(search, L("Перейти к строке…"), #selector(goToLine(_:)), "l")
        let view = submenu(L("Вид"))
        item(view, L("Все вкладки…"), #selector(showTabList), "a", [.command, .shift])
        item(view, L("Предпросмотр Markdown / HTML"), #selector(togglePreview(_:)), "p", [.command, .option])
        item(view, L("Перенос строк"), #selector(toggleWrap(_:)), "w", [.command, .option])
        item(view, L("Увеличить шрифт"), #selector(zoomIn(_:)), "=")
        item(view, L("Уменьшить шрифт"), #selector(zoomOut(_:)), "-")
        item(view, L("Следующая вкладка"), #selector(nextTab(_:)), "]", [.command, .shift])
        item(view, L("Предыдущая вкладка"), #selector(previousTab(_:)), "[", [.command, .shift])
        let windowMenu = submenu(L("Окно"))
        item(windowMenu, L("Свернуть"), #selector(NSWindow.performMiniaturize(_:)), "m")
        item(windowMenu, L("На весь экран"), #selector(NSWindow.toggleFullScreen(_:)), "f", [.command, .control])
        NSApp.windowsMenu = windowMenu
        NSApp.mainMenu = main
    }

    func button(_ title: String, _ action: Selector, symbol: String? = nil) -> NSButton {
        let button = NSButton(title: title, target: self, action: action)
        button.cell = EditorButtonCell(textCell: title)
        button.target = self; button.action = action
        button.contentTintColor = .labelColor
        button.bezelStyle = .rounded
        button.font = .systemFont(ofSize: 13, weight: .medium)
        button.heightAnchor.constraint(equalToConstant: 30).isActive = true
        if let symbol { button.image = NSImage(systemSymbolName: symbol, accessibilityDescription: title); button.imagePosition = .imageLeading }
        button.setAccessibilityLabel(title.isEmpty && symbol == "gearshape" ? L("Настройки…") : title); button.toolTip = title.isEmpty && symbol == "gearshape" ? L("Настройки…") : title
        return button
    }
    func row(_ views: [NSView]) -> NSStackView {
        let stack = EditorBar(views: views); stack.orientation = .horizontal; stack.spacing = 8
        stack.edgeInsets = NSEdgeInsets(top: 6, left: 12, bottom: 6, right: 12)
        return stack
    }
    func makeWindow() {
        for item in splitController.splitViewItems { splitController.removeSplitViewItem(item) }
        findStack.arrangedSubviews.forEach { findStack.removeArrangedSubview($0); $0.removeFromSuperview() }
        previewEnabled = false
        caseButton.title = L("Регистр"); regexButton.title = ".* Regex"
        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1120, height: 760), styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.backgroundColor = EditorPalette.chrome
        window.title = "Notepad Mac"; window.minSize = NSSize(width: 860, height: 440)
        window.delegate = self; window.center(); window.setFrameAutosaveName("EditorWindow")
        let root = NSStackView(); root.wantsLayer = true; root.orientation = .vertical; root.spacing = 0; root.alignment = .leading
        window.contentView = root
        pathLabel.lineBreakMode = .byTruncatingMiddle; pathLabel.textColor = .secondaryLabelColor
        pathLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        previewButton = button(L("Просмотр"), #selector(togglePreview(_:)), symbol: "rectangle.split.2x1")
        previewButton.setButtonType(.pushOnPushOff)
        let toolbar = row([button(L("Новый"), #selector(newDocument(_:)), symbol: "plus"), button(L("Открыть"), #selector(openDocument(_:)), symbol: "folder"), button(L("Сохранить"), #selector(saveDocument(_:)), symbol: "square.and.arrow.down"), NSView(), button(L("Формат"), #selector(formatDocument(_:)), symbol: "text.alignleft"), button(L("Вкладки"), #selector(showTabList), symbol: "square.stack"), previewButton, button(L("Поиск"), #selector(showFind(_:)), symbol: "magnifyingglass"), button("", #selector(showPreferences), symbol: "gearshape")])
        root.addArrangedSubview(toolbar)
        tabStack.orientation = .horizontal; tabStack.spacing = 4
        tabStack.edgeInsets = NSEdgeInsets(top: 4, left: 12, bottom: 4, right: 12)
        let tabScroll = NSScrollView(); tabScroll.hasHorizontalScroller = true; tabScroll.autohidesScrollers = true
        tabScroll.drawsBackground = false; tabScroll.documentView = tabStack
        tabStack.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([tabStack.leadingAnchor.constraint(equalTo: tabScroll.contentView.leadingAnchor), tabStack.topAnchor.constraint(equalTo: tabScroll.contentView.topAnchor), tabStack.heightAnchor.constraint(equalToConstant: 40)])
        tabScroll.heightAnchor.constraint(equalToConstant: 44).isActive = true
        root.addArrangedSubview(tabScroll)
        searchField.placeholderString = L("Найти"); searchField.setAccessibilityLabel(L("Найти"))
        searchField.target = self; searchField.action = #selector(findNext(_:))
        searchField.sendsSearchStringImmediately = false
        replaceField.placeholderString = L("Заменить на"); replaceField.setAccessibilityLabel(L("Заменить на"))
        for field in [searchField, replaceField] {
            field.font = .systemFont(ofSize: 13); field.controlSize = .regular
            field.heightAnchor.constraint(equalToConstant: 30).isActive = true
            field.isBezeled = true; field.bezelStyle = .roundedBezel
            field.backgroundColor = EditorPalette.editor; field.textColor = .labelColor
        }
        for toggle in [caseButton, regexButton] {
            let state = toggle.state
            toggle.cell = EditorButtonCell(textCell: toggle.title); toggle.setButtonType(.pushOnPushOff)
            toggle.state = state; toggle.font = .systemFont(ofSize: 13)
            toggle.heightAnchor.constraint(equalToConstant: 30).isActive = true
            toggle.setAccessibilityLabel(toggle.title)
        }
        searchField.widthAnchor.constraint(equalToConstant: 220).isActive = true
        replaceField.widthAnchor.constraint(equalToConstant: 220).isActive = true
        findStatus.font = .systemFont(ofSize: 12); findStatus.textColor = .secondaryLabelColor
        findStack.orientation = .vertical; findStack.alignment = .leading; findStack.spacing = 0
        findStack.addArrangedSubview(row([searchField, caseButton, regexButton, button(L("Назад"), #selector(findPrevious(_:))), button(L("Далее"), #selector(findNext(_:))), button(L("Закрыть"), #selector(hideFind(_:)))]))
        findStack.addArrangedSubview(row([replaceField, button(L("Заменить"), #selector(replaceOne(_:))), button(L("Заменить всё"), #selector(replaceAll(_:))), findStatus]))
        findStack.isHidden = true; root.addArrangedSubview(findStack)
        _ = splitController.view
        editorSplit.isVertical = true; editorSplit.dividerStyle = .thin
        let editController = NSViewController(); editController.view = editorHost
        let previewController = NSViewController(); previewController.view = previewPane.view
        let editItem = NSSplitViewItem(viewController: editController); editItem.minimumThickness = 280
        previewItem = NSSplitViewItem(viewController: previewController); previewItem.minimumThickness = 280; previewItem.canCollapse = true
        splitController.addSplitViewItem(editItem); splitController.addSplitViewItem(previewItem)
        previewItem.isCollapsed = true
        editorSplit.heightAnchor.constraint(greaterThanOrEqualToConstant: 120).isActive = true
        root.addArrangedSubview(editorSplit)
        let pathRow = row([pathLabel]); root.addArrangedSubview(pathRow)
        pathLabel.font = .systemFont(ofSize: 11)
        status.lineBreakMode = .byTruncatingTail
        status.font = .monospacedDigitSystemFont(ofSize: 12, weight: .regular)
        status.widthAnchor.constraint(greaterThanOrEqualToConstant: 120).isActive = true
        status.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        for popup in [languagePopup, encodingPopup, endingPopup, themePopup, palettePopup] { popup.cell = EditorPopupCell(textCell: "", pullsDown: false); popup.removeAllItems(); popup.translatesAutoresizingMaskIntoConstraints = false; popup.heightAnchor.constraint(equalToConstant: 30).isActive = true }
        languagePopup.addItems(withTitles: [L("Авто")] + Syntax.languages.map(L))
        languagePopup.target = self; languagePopup.action = #selector(changeLanguage(_:))
        languagePopup.setAccessibilityLabel(L("Язык подсветки"))
        languagePopup.toolTip = L("Язык подсветки: Авто — по расширению файла")
        encodingPopup.addItems(withTitles: TextEncoding.allCases.map(\.rawValue))
        encodingPopup.target = self; encodingPopup.action = #selector(changeEncoding(_:)); encodingPopup.setAccessibilityLabel(L("Кодировка файла"))
        endingPopup.addItems(withTitles: LineEnding.allCases.map(\.rawValue))
        endingPopup.target = self; endingPopup.action = #selector(changeEnding(_:)); endingPopup.setAccessibilityLabel(L("Окончания строк"))
        themePopup.addItems(withTitles: [L("Системная"), L("Светлая"), L("Тёмная")])
        themePopup.selectItem(at: UserDefaults.standard.integer(forKey: "theme"))
        themePopup.target = self; themePopup.action = #selector(changeTheme(_:)); themePopup.setAccessibilityLabel(L("Тема оформления"))
        for popup in [languagePopup, endingPopup, encodingPopup, themePopup] { popup.controlSize = .regular; popup.font = .systemFont(ofSize: 13) }
        languagePopup.widthAnchor.constraint(equalToConstant: 138).isActive = true
        endingPopup.widthAnchor.constraint(equalToConstant: 66).isActive = true
        encodingPopup.widthAnchor.constraint(equalToConstant: 100).isActive = true
        themePopup.widthAnchor.constraint(equalToConstant: 104).isActive = true
        palettePopup.widthAnchor.constraint(equalToConstant: 155).isActive = true
        palettePopup.target = self; palettePopup.action = #selector(preferencePaletteChanged(_:))
        palettePopup.setAccessibilityLabel(InterfaceLanguage.english ? "Color scheme" : "Цветовая схема")
        endingPopup.toolTip = L("Окончания строк") + ": LF / CRLF / CR"
        let statusRow = row([status, NSView(), languagePopup, endingPopup, encodingPopup, themePopup, palettePopup]); root.addArrangedSubview(statusRow)
        for child in root.arrangedSubviews {
            child.translatesAutoresizingMaskIntoConstraints = false
            child.widthAnchor.constraint(equalTo: root.widthAnchor).isActive = true
        }
        editorHost.heightAnchor.constraint(greaterThanOrEqualToConstant: 120).isActive = true
        changeTheme(nil)
    }

    @objc func newDocument(_ sender: Any?) {
        addTab(SessionTab(title: L("Без имени \(tabs.filter { $0.url == nil }.count + 1)")))
    }
    func addTab(_ snapshot: SessionTab) {
        let tab = EditorTab(snapshot, fontSize: fontSize, wrap: wrap)
        tab.textView.delegate = self
        tabs.append(tab); select(tab); rebuildTabs(); schedulePersistence()
    }
    func select(_ tab: EditorTab) {
        selectedID = tab.snapshot.id
        editorHost.subviews.forEach { $0.removeFromSuperview() }
        let scroll = tab.container; scroll.translatesAutoresizingMaskIntoConstraints = false; editorHost.addSubview(scroll)
        NSLayoutConstraint.activate([scroll.leadingAnchor.constraint(equalTo: editorHost.leadingAnchor), scroll.trailingAnchor.constraint(equalTo: editorHost.trailingAnchor), scroll.topAnchor.constraint(equalTo: editorHost.topAnchor), scroll.bottomAnchor.constraint(equalTo: editorHost.bottomAnchor)])
        editorHost.layoutSubtreeIfNeeded(); tab.setWrap(wrap)
        window.makeFirstResponder(tab.textView); tab.highlight(); updateStatus(); updateTabLabels(); refreshPreview(); schedulePersistence()
    }
    func rebuildTabs() {
        tabStack.arrangedSubviews.forEach { tabStack.removeArrangedSubview($0); $0.removeFromSuperview() }; tabButtons = [:]; tabSurfaces = [:]
        for tab in tabs {
            let surface = TabSurface()
            surface.translatesAutoresizingMaskIntoConstraints = false
            let selectButton = NSButton(title: "", target: self, action: #selector(selectTab(_:)))
            selectButton.isBordered = false; selectButton.font = .systemFont(ofSize: 13, weight: .medium)
            selectButton.identifier = NSUserInterfaceItemIdentifier(tab.snapshot.id.uuidString)
            selectButton.lineBreakMode = .byTruncatingTail
            selectButton.alignment = .left
            let close = NSButton(image: NSImage(systemSymbolName: "xmark", accessibilityDescription: L("Закрыть вкладку"))!, target: self, action: #selector(closeTab(_:)))
            close.isBordered = false; close.imageScaling = .scaleProportionallyDown
            close.contentTintColor = .secondaryLabelColor
            close.setAccessibilityLabel(L("Закрыть \(tab.snapshot.title)")); close.toolTip = L("Закрыть вкладку (⌘W)")
            close.identifier = selectButton.identifier
            for control in [selectButton, close] { control.translatesAutoresizingMaskIntoConstraints = false; surface.addSubview(control) }
            NSLayoutConstraint.activate([
                surface.heightAnchor.constraint(equalToConstant: 30),
                surface.widthAnchor.constraint(equalToConstant: min(220, max(150, CGFloat(tab.snapshot.title.count) * 7 + 62))),
                selectButton.leadingAnchor.constraint(equalTo: surface.leadingAnchor, constant: 12),
                selectButton.trailingAnchor.constraint(equalTo: close.leadingAnchor, constant: -6),
                selectButton.topAnchor.constraint(equalTo: surface.topAnchor, constant: 2),
                selectButton.bottomAnchor.constraint(equalTo: surface.bottomAnchor, constant: -2),
                close.widthAnchor.constraint(equalToConstant: 24), close.heightAnchor.constraint(equalToConstant: 24),
                close.trailingAnchor.constraint(equalTo: surface.trailingAnchor, constant: -5),
                close.centerYAnchor.constraint(equalTo: surface.centerYAnchor)
            ])
            tabStack.addArrangedSubview(surface); tabButtons[tab.snapshot.id] = selectButton; tabSurfaces[tab.snapshot.id] = surface
        }
        let add = button("", #selector(newDocument(_:)), symbol: "plus")
        add.setAccessibilityLabel(L("Новая вкладка")); add.toolTip = L("Новая вкладка (⌘N)")
        tabStack.addArrangedSubview(add)
        tabStack.layoutSubtreeIfNeeded(); updateTabLabels()
    }
    func updateTabLabels() {
        for tab in tabs {
            let b = tabButtons[tab.snapshot.id]
            b?.title = (tab.dirty ? "● " : "") + tab.snapshot.title
            b?.contentTintColor = tab.snapshot.id == selectedID ? .labelColor : .secondaryLabelColor
            b?.font = .systemFont(ofSize: 13, weight: tab.snapshot.id == selectedID ? .semibold : .regular)
            tabSurfaces[tab.snapshot.id]?.selected = tab.snapshot.id == selectedID
            b?.toolTip = tab.url?.path ?? tab.snapshot.title
            b?.setAccessibilityLabel(tab.snapshot.title + (tab.dirty ? L(", изменён") : ""))
        }
        if let selectedID, let button = tabButtons[selectedID] { button.scrollToVisible(button.bounds) }
        window.title = (current?.snapshot.title ?? "Notepad Mac") + " — Notepad Mac"
        window.isDocumentEdited = current?.dirty ?? false
        window.representedURL = current?.url
    }
    @objc func selectTab(_ sender: NSButton) { if let tab = tabFor(sender) { select(tab) } }
    func tabFor(_ sender: NSButton) -> EditorTab? { tabs.first { $0.snapshot.id.uuidString == sender.identifier?.rawValue } }
    @objc func nextTab(_ sender: Any?) { cycleTab(1) }
    @objc func previousTab(_ sender: Any?) { cycleTab(-1) }
    func cycleTab(_ step: Int) {
        guard let index = tabs.firstIndex(where: { $0.snapshot.id == selectedID }), !tabs.isEmpty else { return }
        select(tabs[(index + step + tabs.count) % tabs.count])
    }
    @objc func openDocument(_ sender: Any?) {
        let panel = NSOpenPanel(); panel.allowsMultipleSelection = true; panel.canChooseDirectories = false
        if panel.runModal() == .OK { panel.urls.forEach(openURL) }
    }
    @objc func openRecent(_ sender: NSMenuItem) { if let url = sender.representedObject as? URL { openURL(url) } }
    func application(_ sender: NSApplication, openFiles filenames: [String]) {
        filenames.forEach { openURL(URL(fileURLWithPath: $0)) }; sender.reply(toOpenOrPrint: .success)
    }
    func openURL(_ input: URL) {
        let url = input.standardizedFileURL.resolvingSymlinksInPath()
        if let tab = tabs.first(where: { $0.url == url }) { select(tab); return }
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
            if (attributes[.size] as? NSNumber)?.intValue ?? 0 > 20_000_000 {
                throw EditorError.message(L("В первой версии поддерживаются файлы до 20 МБ."))
            }
            let decoded = try TextCodec.decode(Data(contentsOf: url))
            addTab(SessionTab(path: url.path, text: decoded.text, savedText: decoded.text, encoding: decoded.encoding, lineEnding: decoded.lineEnding, diskModified: attributes[.modificationDate] as? Date, title: url.lastPathComponent))
            NSDocumentController.shared.noteNewRecentDocumentURL(url)
        } catch { showError(error) }
    }
    @objc func saveDocument(_ sender: Any?) { if let current { _ = save(current, choosePath: current.url == nil) } }
    @objc func saveAs(_ sender: Any?) { if let current { _ = save(current, choosePath: true) } }
    @discardableResult func save(_ tab: EditorTab, choosePath: Bool) -> Bool {
        var destination = tab.url
        if choosePath {
            let panel = NSSavePanel(); panel.nameFieldStringValue = tab.url?.lastPathComponent ?? "Untitled.txt"
            panel.directoryURL = tab.url?.deletingLastPathComponent(); panel.canCreateDirectories = true
            guard panel.runModal() == .OK, let url = panel.url else { return false }
            destination = url.standardizedFileURL.resolvingSymlinksInPath()
        }
        guard let destination else { return false }
        if tabs.contains(where: { $0 !== tab && $0.url == destination }) {
            showError(EditorError.message(L("Этот файл уже открыт в другой вкладке. Закройте её перед сохранением."))); return false
        }
        do {
            if destination == tab.url, FileManager.default.fileExists(atPath: destination.path) {
                let modified = try FileManager.default.attributesOfItem(atPath: destination.path)[.modificationDate] as? Date
                if modified != tab.snapshot.diskModified {
                    let alert = NSAlert(); alert.messageText = L("Файл изменён другой программой")
                    alert.informativeText = L("Перезаписать файл «\(destination.lastPathComponent)» текущим текстом? Для сохранения обеих версий выберите «Сохранить как…».")
                    alert.addButton(withTitle: L("Отмена")); alert.addButton(withTitle: L("Перезаписать"))
                    guard alert.runModal() == .alertSecondButtonReturn else { return false }
                }
            }
            let data = try TextCodec.encode(tab.textView.string, encoding: tab.snapshot.encoding, lineEnding: tab.snapshot.lineEnding)
            try data.write(to: destination, options: .atomic)
            tab.snapshot.path = destination.path; tab.snapshot.title = destination.lastPathComponent
            tab.snapshot.savedText = tab.textView.string; tab.savedEncoding = tab.snapshot.encoding; tab.savedEnding = tab.snapshot.lineEnding
            tab.snapshot.diskModified = try FileManager.default.attributesOfItem(atPath: destination.path)[.modificationDate] as? Date
            NSDocumentController.shared.noteNewRecentDocumentURL(destination)
            tab.textView.setAccessibilityLabel(tab.snapshot.title)
            tab.highlight(); rebuildTabs(); updateStatus(); updateTabLabels(); refreshPreview(); persist(); return true
        } catch { showError(error); return false }
    }
    @objc func closeCurrent(_ sender: Any?) { if let current { close(current) } }
    @objc func closeTab(_ sender: NSButton) { if let tab = tabFor(sender) { close(tab) } }
    func close(_ tab: EditorTab) {
        if tab.dirty {
            let alert = NSAlert(); alert.messageText = L("Сохранить «\(tab.snapshot.title)»?")
            alert.informativeText = L("При закрытии без сохранения изменения этой вкладки будут удалены.")
            alert.addButton(withTitle: L("Сохранить")); alert.addButton(withTitle: L("Отмена")); alert.addButton(withTitle: L("Не сохранять"))
            let response = alert.runModal()
            if response == .alertSecondButtonReturn { return }
            if response == .alertFirstButtonReturn && !save(tab, choosePath: tab.url == nil) { return }
        }
        let index = tabs.firstIndex(where: { $0 === tab }) ?? 0
        tab.highlightWork?.cancel(); tabs.removeAll { $0 === tab }
        if tabs.isEmpty { newDocument(nil) }
        else if selectedID == tab.snapshot.id { select(tabs[min(index, tabs.count - 1)]) }
        rebuildTabs(); persist()
    }

    func textDidChange(_ notification: Notification) {
        guard let textView = notification.object as? NSTextView, let tab = tabs.first(where: { $0.textView === textView }) else { return }
        tab.ruler.needsDisplay = true; tab.highlight(); updateTabLabels(); updateStatus(); refreshPreview(); schedulePersistence()
    }
    func textViewDidChangeSelection(_ notification: Notification) { updateStatus() }
    func updateStatus() {
        guard let tab = current else { return }
        let position = TextPosition.lineColumn(in: tab.textView.string, utf16Offset: tab.textView.selectedRange().location)
        status.stringValue = L("Стр \(position.line), стлб \(position.column)   ·   \(L(tab.language))   ·   \(tab.textView.string.count) симв.")
        pathLabel.stringValue = tab.url?.path ?? L("Новый документ · восстанавливается при следующем запуске")
        pathLabel.toolTip = pathLabel.stringValue
        languagePopup.selectItem(withTitle: L(tab.snapshot.syntaxLanguage ?? "Авто"))
        encodingPopup.selectItem(withTitle: tab.snapshot.encoding.rawValue)
        endingPopup.selectItem(withTitle: tab.snapshot.lineEnding.rawValue)
    }
    @objc func changeLanguage(_ sender: Any?) {
        guard let tab = current, let displayedLanguage = languagePopup.titleOfSelectedItem else { return }
        let language = InterfaceLanguage.source(displayedLanguage)
        tab.snapshot.syntaxLanguage = language == "Авто" ? nil : language
        tab.highlight(); updateStatus(); refreshPreview(); schedulePersistence()
    }
    @objc func changeEncoding(_ sender: Any?) {
        guard let tab = current, let title = encodingPopup.titleOfSelectedItem, let encoding = TextEncoding(rawValue: title) else { return }
        tab.snapshot.encoding = encoding; updateTabLabels(); schedulePersistence()
    }
    @objc func changeEnding(_ sender: Any?) {
        guard let tab = current, let title = endingPopup.titleOfSelectedItem, let ending = LineEnding(rawValue: title) else { return }
        tab.snapshot.lineEnding = ending; updateTabLabels(); schedulePersistence()
    }
    @objc func changeTheme(_ sender: Any?) {
        let index = themePopup.indexOfSelectedItem
        NSApp.appearance = index == 1 ? NSAppearance(named: .aqua) : index == 2 ? NSAppearance(named: .darkAqua) : nil
        UserDefaults.standard.set(index, forKey: "theme")
        refreshSchemes()
        tabs.forEach { $0.highlight(); $0.ruler.needsDisplay = true }
    }
    @objc func toggleWrap(_ sender: Any?) {
        wrap.toggle(); tabs.forEach { $0.setWrap(wrap) }; UserDefaults.standard.set(wrap, forKey: "wrap")
        (sender as? NSMenuItem)?.state = wrap ? .on : .off
    }
    @objc func zoomIn(_ sender: Any?) { changeFont(1) }
    @objc func zoomOut(_ sender: Any?) { changeFont(-1) }
    func changeFont(_ delta: CGFloat) {
        fontSize = min(32, max(10, fontSize + delta)); UserDefaults.standard.set(Double(fontSize), forKey: "fontSize")
        tabs.forEach { $0.textView.font = .monospacedSystemFont(ofSize: fontSize, weight: .regular); $0.ruler.needsDisplay = true; $0.highlight() }
    }
    @objc func showFind(_ sender: Any?) {
        findStack.isHidden = false
        if let tab = current, tab.textView.selectedRange().length > 0 {
            searchField.stringValue = (tab.textView.string as NSString).substring(with: tab.textView.selectedRange())
        }
        window.makeFirstResponder(searchField)
    }
    @objc func hideFind(_ sender: Any?) { findStack.isHidden = true; window.makeFirstResponder(current?.textView) }
    var query: SearchQuery { SearchQuery(searchField.stringValue, regex: regexButton.state == .on, matchCase: caseButton.state == .on) }
    @objc func findNext(_ sender: Any?) { find(backwards: false) }
    @objc func findPrevious(_ sender: Any?) { find(backwards: true) }
    func find(backwards: Bool) {
        guard let tab = current else { return }
        if searchField.stringValue.isEmpty { showFind(nil); return }
        do {
            let matches = try query.matches(in: tab.textView.string)
            guard !matches.isEmpty else { findStatus.stringValue = L("Совпадений нет"); NSSound.beep(); return }
            let range = tab.textView.selectedRange()
            let match: NSRange
            if backwards { match = matches.last(where: { $0.location < range.location }) ?? matches.last! }
            else { match = matches.first(where: { $0.location >= NSMaxRange(range) && !($0 == range) }) ?? matches.first! }
            tab.textView.setSelectedRange(match); tab.textView.scrollRangeToVisible(match)
            findStatus.stringValue = L("\((matches.firstIndex(of: match) ?? 0) + 1) из \(matches.count)")
        } catch { findStatus.stringValue = L("Ошибка Regex"); showError(error) }
    }
    @objc func replaceOne(_ sender: Any?) {
        guard let tab = current, !searchField.stringValue.isEmpty else { return }
        do {
            let selected = tab.textView.selectedRange()
            let matches = try query.matches(in: tab.textView.string)
            guard matches.contains(selected) else { findNext(nil); return }
            // Compute expansion against the whole document so lookarounds and captures keep their context.
            let pattern = query.regex ? query.pattern : NSRegularExpression.escapedPattern(for: query.pattern)
            let expression = try NSRegularExpression(pattern: pattern, options: query.matchCase ? [] : [.caseInsensitive])
            guard let match = expression.matches(in: tab.textView.string, range: NSRange(location: 0, length: (tab.textView.string as NSString).length)).first(where: { $0.range == selected }) else { return }
            let template = query.regex ? replaceField.stringValue : NSRegularExpression.escapedTemplate(for: replaceField.stringValue)
            let replacement = expression.replacementString(for: match, in: tab.textView.string, offset: 0, template: template)
            tab.textView.insertText(replacement, replacementRange: selected); findNext(nil)
        } catch { showError(error) }
    }
    @objc func replaceAll(_ sender: Any?) {
        guard let tab = current else { return }
        do {
            let count = try query.matches(in: tab.textView.string).count
            let replaced = try query.replacing(in: tab.textView.string, with: replaceField.stringValue)
            if count > 0 { tab.textView.insertText(replaced, replacementRange: NSRange(location: 0, length: (tab.textView.string as NSString).length)) }
            findStatus.stringValue = L("Заменено: \(count)")
        } catch { showError(error) }
    }
    @objc func goToLine(_ sender: Any?) {
        guard let tab = current else { return }
        let alert = NSAlert(); alert.messageText = L("Перейти к строке")
        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 220, height: 24)); field.stringValue = "1"; field.setAccessibilityLabel(L("Номер строки"))
        alert.accessoryView = field; alert.addButton(withTitle: L("Перейти")); alert.addButton(withTitle: L("Отмена"))
        alert.window.initialFirstResponder = field
        if alert.runModal() == .alertFirstButtonReturn, let line = Int(field.stringValue), line > 0 {
            let range = NSRange(location: TextPosition.offset(ofLine: line, in: tab.textView.string), length: 0)
            tab.textView.setSelectedRange(range); tab.textView.scrollRangeToVisible(range); window.makeFirstResponder(tab.textView)
        }
    }
    func refreshPreview() { previewPane.update(current, visible: previewEnabled) }
    @objc func togglePreview(_ sender: Any?) {
        previewEnabled.toggle()
        previewItem.isCollapsed = !previewEnabled
        window.contentView?.layoutSubtreeIfNeeded()
        previewButton.state = previewEnabled ? .on : .off
        (sender as? NSMenuItem)?.state = previewEnabled ? .on : .off
        editorSplit.adjustSubviews()
        if previewEnabled { editorSplit.setPosition(editorSplit.bounds.width * 0.5, ofDividerAt: 0) }
        current?.setWrap(wrap); refreshPreview()
    }
    @objc func showTabList() {
        if let tabListPanel { tabListPanel.makeKeyAndOrderFront(nil); filterTabList(); return }
        let panel = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 440, height: 480), styleMask: [.titled, .closable, .resizable], backing: .buffered, defer: false)
        panel.title = L("Все вкладки…"); panel.isReleasedWhenClosed = false
        panel.minSize = NSSize(width: 360, height: 260); panel.backgroundColor = EditorPalette.chrome
        tabListSearch.placeholderString = L("Поиск вкладки"); tabListSearch.target = self; tabListSearch.action = #selector(filterTabList)
        tabListSearch.sendsSearchStringImmediately = true
        tabListSearch.font = .systemFont(ofSize: 13); tabListSearch.controlSize = .regular
        tabListSearch.heightAnchor.constraint(equalToConstant: 30).isActive = true
        tabListSearch.setAccessibilityLabel(L("Поиск вкладки"))
        tabListRows.orientation = .vertical; tabListRows.alignment = .leading; tabListRows.spacing = 4
        let scroll = NSScrollView(); scroll.hasVerticalScroller = true; scroll.documentView = tabListRows
        scroll.drawsBackground = false
        let root = NSView(); panel.contentView = root
        for view in [tabListSearch, scroll, tabListRows] { view.translatesAutoresizingMaskIntoConstraints = false }
        root.addSubview(tabListSearch); root.addSubview(scroll)
        NSLayoutConstraint.activate([
            tabListSearch.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 12), tabListSearch.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -12), tabListSearch.topAnchor.constraint(equalTo: root.topAnchor, constant: 12),
            scroll.topAnchor.constraint(equalTo: tabListSearch.bottomAnchor, constant: 10), scroll.bottomAnchor.constraint(equalTo: root.bottomAnchor, constant: -12), scroll.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 12), scroll.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -12),
            tabListRows.leadingAnchor.constraint(equalTo: scroll.contentView.leadingAnchor), tabListRows.topAnchor.constraint(equalTo: scroll.contentView.topAnchor), tabListRows.widthAnchor.constraint(equalTo: scroll.contentView.widthAnchor)
        ])
        tabListPanel = panel; filterTabList(); panel.center(); panel.makeKeyAndOrderFront(nil); panel.makeFirstResponder(tabListSearch)
    }
    @objc func filterTabList() {
        tabListRows.arrangedSubviews.forEach { tabListRows.removeArrangedSubview($0); $0.removeFromSuperview() }
        let query = tabListSearch.stringValue
        for tab in tabs where query.isEmpty || (tab.url?.path ?? tab.snapshot.title).localizedCaseInsensitiveContains(query) {
            let entry = button((tab.snapshot.id == selectedID ? "✓ " : "") + (tab.dirty ? "● " : "") + tab.snapshot.title, #selector(chooseListedTab(_:)))
            entry.setButtonType(.pushOnPushOff); entry.state = tab.snapshot.id == selectedID ? .on : .off
            entry.identifier = NSUserInterfaceItemIdentifier(tab.snapshot.id.uuidString); entry.alignment = .left; entry.lineBreakMode = .byTruncatingMiddle
            entry.toolTip = tab.url?.path ?? tab.snapshot.title
            tabListRows.addArrangedSubview(entry); entry.widthAnchor.constraint(equalTo: tabListRows.widthAnchor).isActive = true
        }
        tabListPanel?.title = L("Все вкладки…") + " · \(tabListRows.arrangedSubviews.count) / \(tabs.count)"
        if tabListRows.arrangedSubviews.isEmpty {
            let empty = NSTextField(labelWithString: InterfaceLanguage.english ? "No matching tabs" : "Вкладки не найдены")
            empty.font = .systemFont(ofSize: 13); empty.textColor = .secondaryLabelColor
            tabListRows.addArrangedSubview(empty)
        }
    }
    @objc func chooseListedTab(_ sender: NSButton) { selectTab(sender); tabListPanel?.orderOut(nil); window.makeKeyAndOrderFront(nil) }
    @objc func useRussian() { setInterfaceLanguage("ru") }
    @objc func useEnglish() { setInterfaceLanguage("en") }
    func setInterfaceLanguage(_ language: String) {
        UserDefaults.standard.set(language, forKey: "interfaceLanguage")
        updater.invalidateLocalization(); SupportWindow.shared.invalidateLocalization(); tabListPanel?.close(); tabListPanel = nil
        let oldWindow = window!
        let frame = oldWindow.frame
        makeMenu(); makeWindow(); window.setFrame(frame, display: true)
        rebuildTabs(); if let tab = current { select(tab) }
        oldWindow.delegate = nil; oldWindow.close()
        window.makeKeyAndOrderFront(nil)
    }
    @objc func checkForUpdates() { updater.check(manual: true) }
    @objc func updateSettings() { updater.showSettings() }
    @objc func supportDeveloper() { SupportWindow.shared.show() }
    @objc func about() {
        let credits = NSMutableAttributedString(string: L("Разработчик — "), attributes: [.font: NSFont.systemFont(ofSize: 13), .foregroundColor: NSColor.labelColor])
        credits.append(NSAttributedString(string: L("Илья (starscream001)"), attributes: [.font: NSFont.systemFont(ofSize: 13), .link: URL(string: "https://github.com/starscream001")!]))
        credits.append(NSAttributedString(string: L("\nРепозиторий Notepad Mac"), attributes: [.font: NSFont.systemFont(ofSize: 13), .link: UpdatePolicy.repositoryURL]))
        credits.append(NSAttributedString(string: "\nTelegram: @Ilya_Manik", attributes: [.font: NSFont.systemFont(ofSize: 13), .link: URL(string: "https://t.me/Ilya_Manik")!]))
        credits.append(NSAttributedString(string: L("\n\nНативный текстовый редактор для macOS.\nБесплатно · открытый исходный код · MIT.\nПоддержка разработчика добровольная."), attributes: [.font: NSFont.systemFont(ofSize: 12), .foregroundColor: NSColor.secondaryLabelColor]))
        NSApp.orderFrontStandardAboutPanel(options: [.applicationName: "Notepad Mac", .applicationVersion: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "Development", .credits: credits])
    }
    func showError(_ error: Error) { let alert = NSAlert(); alert.messageText = InterfaceLanguage.english ? "Could Not Complete the Action" : "Не удалось выполнить действие"; alert.informativeText = L(error.localizedDescription); alert.runModal() }
    func schedulePersistence() {
        persistenceWork?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.persist() }; persistenceWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8, execute: work)
    }
    @discardableResult func persist() -> Bool {
        persistenceWork?.cancel()
        guard !sessionWriteBlocked else { return false }
        do {
            let snapshots = tabs.map { tab -> SessionTab in
                var snapshot = tab.capture()
                snapshot.savedEncoding = tab.savedEncoding; snapshot.savedLineEnding = tab.savedEnding
                return snapshot
            }
            try SessionStore.save(Session(tabs: snapshots, selected: selectedID), to: sessionURL)
            return true
        } catch {
            if !didWarnPersistence { didWarnPersistence = true; showError(EditorError.message(L("Не удалось сохранить сессию: \(error.localizedDescription). Сохраните важные вкладки в файлы."))) }
            return false
        }
    }
    func restore() {
        guard FileManager.default.fileExists(atPath: sessionURL.path) else { return }
        do {
            let session = try SessionStore.load(from: sessionURL)
            for var snapshot in session.tabs {
                let clean = snapshot.text == snapshot.savedText && (snapshot.savedEncoding ?? snapshot.encoding) == snapshot.encoding && (snapshot.savedLineEnding ?? snapshot.lineEnding) == snapshot.lineEnding
                if clean, let path = snapshot.path, let data = try? Data(contentsOf: URL(fileURLWithPath: path)), let decoded = try? TextCodec.decode(data) {
                    snapshot.text = decoded.text; snapshot.savedText = decoded.text; snapshot.encoding = decoded.encoding; snapshot.lineEnding = decoded.lineEnding
                    snapshot.savedEncoding = decoded.encoding; snapshot.savedLineEnding = decoded.lineEnding
                    snapshot.diskModified = (try? FileManager.default.attributesOfItem(atPath: path))?[.modificationDate] as? Date
                }
                let tab = EditorTab(snapshot, fontSize: fontSize, wrap: wrap)
                tab.savedEncoding = snapshot.savedEncoding ?? snapshot.encoding; tab.savedEnding = snapshot.savedLineEnding ?? snapshot.lineEnding
                tab.textView.delegate = self; tabs.append(tab)
            }
            if let selected = tabs.first(where: { $0.snapshot.id == session.selected }) ?? tabs.first { select(selected) }
            rebuildTabs()
        } catch {
            // Preserve a corrupt session for recovery before any new snapshot is written.
            let backup = sessionURL.deletingPathExtension().appendingPathExtension("damaged-\(Int(Date().timeIntervalSince1970)).json")
            do { try FileManager.default.moveItem(at: sessionURL, to: backup) }
            catch { sessionWriteBlocked = true; didWarnPersistence = true; showError(error); return }
            showError(EditorError.message(L("Сессия не прочитана. Исходная копия сохранена: \(backup.path)")))
        }
    }
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        if updater.isHandingOff { return .terminateNow } // Session was saved immediately before handoff.
        if persist() { return .terminateNow }
        let alert = NSAlert(); alert.messageText = L("Сессия не сохранена")
        alert.informativeText = L("Сохраните документы перед выходом, чтобы не потерять изменения.")
        alert.addButton(withTitle: L("Вернуться")); alert.addButton(withTitle: L("Выйти без восстановления"))
        return alert.runModal() == .alertSecondButtonReturn ? .terminateNow : .terminateCancel
    }
    func windowShouldClose(_ sender: NSWindow) -> Bool { NSApp.terminate(nil); return false }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool { window.makeKeyAndOrderFront(nil); return true }
    func windowDidResize(_ notification: Notification) { current?.ruler.needsDisplay = true }
}
