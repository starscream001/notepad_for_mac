import AppKit
import NotepadCore

final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate, NSTextViewDelegate {
    var window: NSWindow!
    var tabs: [EditorTab] = []
    var selectedID: UUID?
    var current: EditorTab? { tabs.first { $0.snapshot.id == selectedID } }
    let tabStack = NSStackView()
    let editorHost = NSView()
    let status = NSTextField(labelWithString: "")
    let pathLabel = NSTextField(labelWithString: "")
    let findStack = NSStackView()
    let searchField = NSSearchField()
    let replaceField = NSTextField()
    let caseButton = NSButton(checkboxWithTitle: "Регистр", target: nil, action: nil)
    let regexButton = NSButton(checkboxWithTitle: ".* Regex", target: nil, action: nil)
    let findStatus = NSTextField(labelWithString: "")
    let languagePopup = NSPopUpButton()
    let encodingPopup = NSPopUpButton()
    let endingPopup = NSPopUpButton()
    let themePopup = NSPopUpButton()
    var tabButtons: [UUID: NSButton] = [:]
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
        item(app, "О Notepad Mac", #selector(about))
        app.addItem(.separator())
        item(app, "Скрыть Notepad Mac", #selector(NSApplication.hide(_:)), "h")
        item(app, "Завершить Notepad Mac", #selector(NSApplication.terminate(_:)), "q")
        let file = submenu("Файл")
        item(file, "Новая вкладка", #selector(newDocument(_:)), "n")
        item(file, "Открыть…", #selector(openDocument(_:)), "o")
        let recentItem = NSMenuItem(title: "Недавние файлы", action: nil, keyEquivalent: "")
        let recentMenu = NSMenu(title: "Недавние файлы")
        recentItem.submenu = recentMenu; file.addItem(recentItem)
        NSDocumentController.shared.recentDocumentURLs.prefix(12).forEach { url in
            let entry = NSMenuItem(title: url.lastPathComponent, action: #selector(openRecent(_:)), keyEquivalent: "")
            entry.representedObject = url; recentMenu.addItem(entry)
        }
        file.addItem(.separator())
        item(file, "Сохранить", #selector(saveDocument(_:)), "s")
        item(file, "Сохранить как…", #selector(saveAs(_:)), "s", [.command, .shift])
        item(file, "Закрыть вкладку", #selector(closeCurrent(_:)), "w")
        let edit = submenu("Правка")
        item(edit, "Отменить", Selector(("undo:")), "z")
        item(edit, "Повторить", Selector(("redo:")), "z", [.command, .shift])
        edit.addItem(.separator())
        item(edit, "Вырезать", #selector(NSText.cut(_:)), "x")
        item(edit, "Копировать", #selector(NSText.copy(_:)), "c")
        item(edit, "Вставить", #selector(NSText.paste(_:)), "v")
        item(edit, "Выделить всё", #selector(NSText.selectAll(_:)), "a")
        let search = submenu("Поиск")
        item(search, "Найти / заменить…", #selector(showFind(_:)), "f")
        item(search, "Найти далее", #selector(findNext(_:)), "g")
        item(search, "Найти предыдущее", #selector(findPrevious(_:)), "g", [.command, .shift])
        item(search, "Перейти к строке…", #selector(goToLine(_:)), "l")
        let view = submenu("Вид")
        item(view, "Перенос строк", #selector(toggleWrap(_:)), "w", [.command, .option])
        item(view, "Увеличить шрифт", #selector(zoomIn(_:)), "=")
        item(view, "Уменьшить шрифт", #selector(zoomOut(_:)), "-")
        item(view, "Следующая вкладка", #selector(nextTab(_:)), "]", [.command, .shift])
        item(view, "Предыдущая вкладка", #selector(previousTab(_:)), "[", [.command, .shift])
        let windowMenu = submenu("Окно")
        item(windowMenu, "Свернуть", #selector(NSWindow.performMiniaturize(_:)), "m")
        item(windowMenu, "На весь экран", #selector(NSWindow.toggleFullScreen(_:)), "f", [.command, .control])
        NSApp.windowsMenu = windowMenu
        NSApp.mainMenu = main
    }

    func button(_ title: String, _ action: Selector, symbol: String? = nil) -> NSButton {
        let button = NSButton(title: title, target: self, action: action)
        button.bezelStyle = .rounded
        if let symbol { button.image = NSImage(systemSymbolName: symbol, accessibilityDescription: title); button.imagePosition = .imageLeading }
        button.setAccessibilityLabel(title); button.toolTip = title
        return button
    }
    func row(_ views: [NSView]) -> NSStackView {
        let stack = NSStackView(views: views); stack.orientation = .horizontal; stack.spacing = 8
        stack.edgeInsets = NSEdgeInsets(top: 8, left: 12, bottom: 8, right: 12)
        return stack
    }
    func makeWindow() {
        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1120, height: 760), styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
        window.title = "Notepad Mac"; window.minSize = NSSize(width: 860, height: 440)
        window.delegate = self; window.center(); window.setFrameAutosaveName("EditorWindow")
        let root = NSStackView(); root.wantsLayer = true; root.orientation = .vertical; root.spacing = 0; root.alignment = .leading
        window.contentView = root
        pathLabel.lineBreakMode = .byTruncatingMiddle; pathLabel.textColor = .secondaryLabelColor
        pathLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        let toolbar = row([button("Новый", #selector(newDocument(_:)), symbol: "plus"), button("Открыть", #selector(openDocument(_:)), symbol: "folder"), button("Сохранить", #selector(saveDocument(_:)), symbol: "square.and.arrow.down"), NSView(), button("Поиск", #selector(showFind(_:)), symbol: "magnifyingglass")])
        root.addArrangedSubview(toolbar)
        tabStack.orientation = .horizontal; tabStack.spacing = 4
        tabStack.edgeInsets = NSEdgeInsets(top: 4, left: 12, bottom: 4, right: 12)
        let tabScroll = NSScrollView(); tabScroll.hasHorizontalScroller = true; tabScroll.autohidesScrollers = true
        tabScroll.drawsBackground = false; tabScroll.documentView = tabStack
        tabStack.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([tabStack.leadingAnchor.constraint(equalTo: tabScroll.contentView.leadingAnchor), tabStack.topAnchor.constraint(equalTo: tabScroll.contentView.topAnchor), tabStack.heightAnchor.constraint(equalToConstant: 38)])
        tabScroll.heightAnchor.constraint(equalToConstant: 50).isActive = true
        root.addArrangedSubview(tabScroll)
        searchField.placeholderString = "Найти"; searchField.setAccessibilityLabel("Найти")
        searchField.target = self; searchField.action = #selector(findNext(_:))
        searchField.sendsSearchStringImmediately = false
        replaceField.placeholderString = "Заменить на"; replaceField.setAccessibilityLabel("Заменить на")
        searchField.widthAnchor.constraint(equalToConstant: 220).isActive = true
        replaceField.widthAnchor.constraint(equalToConstant: 220).isActive = true
        findStatus.font = .systemFont(ofSize: 11); findStatus.textColor = .secondaryLabelColor
        findStack.orientation = .vertical; findStack.alignment = .leading; findStack.spacing = 0
        findStack.addArrangedSubview(row([searchField, caseButton, regexButton, button("Назад", #selector(findPrevious(_:))), button("Далее", #selector(findNext(_:))), button("Закрыть", #selector(hideFind(_:)))]))
        findStack.addArrangedSubview(row([replaceField, button("Заменить", #selector(replaceOne(_:))), button("Заменить всё", #selector(replaceAll(_:))), findStatus]))
        findStack.isHidden = true; root.addArrangedSubview(findStack)
        root.addArrangedSubview(editorHost)
        let pathRow = row([pathLabel]); root.addArrangedSubview(pathRow)
        status.font = .monospacedDigitSystemFont(ofSize: 11, weight: .regular)
        status.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        languagePopup.addItems(withTitles: ["Авто"] + Syntax.languages)
        languagePopup.target = self; languagePopup.action = #selector(changeLanguage(_:))
        languagePopup.setAccessibilityLabel("Язык подсветки")
        languagePopup.toolTip = "Язык подсветки: Авто — по расширению файла"
        encodingPopup.addItems(withTitles: TextEncoding.allCases.map(\.rawValue))
        encodingPopup.target = self; encodingPopup.action = #selector(changeEncoding(_:)); encodingPopup.setAccessibilityLabel("Кодировка файла")
        endingPopup.addItems(withTitles: LineEnding.allCases.map(\.rawValue))
        endingPopup.target = self; endingPopup.action = #selector(changeEnding(_:)); endingPopup.setAccessibilityLabel("Окончания строк")
        themePopup.addItems(withTitles: ["Системная", "Светлая", "Тёмная"])
        themePopup.selectItem(at: UserDefaults.standard.integer(forKey: "theme"))
        themePopup.target = self; themePopup.action = #selector(changeTheme(_:)); themePopup.setAccessibilityLabel("Тема оформления")
        let statusRow = row([status, NSView(), NSTextField(labelWithString: "Язык:"), languagePopup, endingPopup, encodingPopup, themePopup]); root.addArrangedSubview(statusRow)
        for child in root.arrangedSubviews {
            child.translatesAutoresizingMaskIntoConstraints = false
            child.widthAnchor.constraint(equalTo: root.widthAnchor).isActive = true
        }
        editorHost.heightAnchor.constraint(greaterThanOrEqualToConstant: 120).isActive = true
        changeTheme(nil)
    }

    @objc func newDocument(_ sender: Any?) {
        addTab(SessionTab(title: "Без имени \(tabs.filter { $0.url == nil }.count + 1)"))
    }
    func addTab(_ snapshot: SessionTab) {
        let tab = EditorTab(snapshot, fontSize: fontSize, wrap: wrap)
        tab.textView.delegate = self
        tabs.append(tab); select(tab); rebuildTabs(); schedulePersistence()
    }
    func select(_ tab: EditorTab) {
        selectedID = tab.snapshot.id
        editorHost.subviews.forEach { $0.removeFromSuperview() }
        let scroll = tab.scroll; scroll.translatesAutoresizingMaskIntoConstraints = false; editorHost.addSubview(scroll)
        NSLayoutConstraint.activate([scroll.leadingAnchor.constraint(equalTo: editorHost.leadingAnchor), scroll.trailingAnchor.constraint(equalTo: editorHost.trailingAnchor), scroll.topAnchor.constraint(equalTo: editorHost.topAnchor), scroll.bottomAnchor.constraint(equalTo: editorHost.bottomAnchor)])
        editorHost.layoutSubtreeIfNeeded(); tab.setWrap(wrap)
        window.makeFirstResponder(tab.textView); tab.highlight(); updateStatus(); updateTabLabels(); schedulePersistence()
    }
    func rebuildTabs() {
        tabStack.arrangedSubviews.forEach { tabStack.removeArrangedSubview($0); $0.removeFromSuperview() }; tabButtons = [:]
        for tab in tabs {
            let selectButton = button("", #selector(selectTab(_:)))
            selectButton.setButtonType(.pushOnPushOff)
            selectButton.identifier = NSUserInterfaceItemIdentifier(tab.snapshot.id.uuidString)
            selectButton.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
            selectButton.widthAnchor.constraint(lessThanOrEqualToConstant: 210).isActive = true
            selectButton.lineBreakMode = .byTruncatingTail
            let close = button("", #selector(closeTab(_:)), symbol: "xmark")
            close.setAccessibilityLabel("Закрыть \(tab.snapshot.title)"); close.toolTip = "Закрыть вкладку"
            close.identifier = selectButton.identifier; close.bezelStyle = .inline
            close.widthAnchor.constraint(equalToConstant: 24).isActive = true
            let group = NSStackView(views: [selectButton, close]); group.spacing = 2
            tabStack.addArrangedSubview(group); tabButtons[tab.snapshot.id] = selectButton
        }
        let add = button("", #selector(newDocument(_:)), symbol: "plus")
        add.setAccessibilityLabel("Новая вкладка"); add.toolTip = "Новая вкладка (⌘N)"
        tabStack.addArrangedSubview(add)
        tabStack.layoutSubtreeIfNeeded(); updateTabLabels()
    }
    func updateTabLabels() {
        for tab in tabs {
            let b = tabButtons[tab.snapshot.id]
            b?.title = (tab.dirty ? "● " : "") + tab.snapshot.title
            b?.state = tab.snapshot.id == selectedID ? .on : .off
            b?.toolTip = tab.url?.path ?? tab.snapshot.title
            b?.setAccessibilityLabel(tab.snapshot.title + (tab.dirty ? ", изменён" : ""))
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
                throw EditorError.message("В первой версии поддерживаются файлы до 20 МБ.")
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
            showError(EditorError.message("Этот файл уже открыт в другой вкладке. Закройте её перед сохранением.")); return false
        }
        do {
            if destination == tab.url, FileManager.default.fileExists(atPath: destination.path) {
                let modified = try FileManager.default.attributesOfItem(atPath: destination.path)[.modificationDate] as? Date
                if modified != tab.snapshot.diskModified {
                    let alert = NSAlert(); alert.messageText = "Файл изменён другой программой"
                    alert.informativeText = "Перезаписать файл «\(destination.lastPathComponent)» текущим текстом? Для сохранения обеих версий выберите «Сохранить как…»."
                    alert.addButton(withTitle: "Отмена"); alert.addButton(withTitle: "Перезаписать")
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
            tab.highlight(); rebuildTabs(); updateStatus(); updateTabLabels(); persist(); return true
        } catch { showError(error); return false }
    }
    @objc func closeCurrent(_ sender: Any?) { if let current { close(current) } }
    @objc func closeTab(_ sender: NSButton) { if let tab = tabFor(sender) { close(tab) } }
    func close(_ tab: EditorTab) {
        if tab.dirty {
            let alert = NSAlert(); alert.messageText = "Сохранить «\(tab.snapshot.title)»?"
            alert.informativeText = "При закрытии без сохранения изменения этой вкладки будут удалены."
            alert.addButton(withTitle: "Сохранить"); alert.addButton(withTitle: "Отмена"); alert.addButton(withTitle: "Не сохранять")
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
        tab.ruler.needsDisplay = true; tab.highlight(); updateTabLabels(); updateStatus(); schedulePersistence()
    }
    func textViewDidChangeSelection(_ notification: Notification) { updateStatus() }
    func updateStatus() {
        guard let tab = current else { return }
        let position = TextPosition.lineColumn(in: tab.textView.string, utf16Offset: tab.textView.selectedRange().location)
        status.stringValue = "Стр \(position.line), стлб \(position.column)   ·   \(tab.language)   ·   \(tab.textView.string.count) симв."
        pathLabel.stringValue = tab.url?.path ?? "Новый документ · восстанавливается при следующем запуске"
        pathLabel.toolTip = pathLabel.stringValue
        languagePopup.selectItem(withTitle: tab.snapshot.syntaxLanguage ?? "Авто")
        encodingPopup.selectItem(withTitle: tab.snapshot.encoding.rawValue)
        endingPopup.selectItem(withTitle: tab.snapshot.lineEnding.rawValue)
    }
    @objc func changeLanguage(_ sender: Any?) {
        guard let tab = current, let language = languagePopup.titleOfSelectedItem else { return }
        tab.snapshot.syntaxLanguage = language == "Авто" ? nil : language
        tab.highlight(); updateStatus(); schedulePersistence()
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
            guard !matches.isEmpty else { findStatus.stringValue = "Совпадений нет"; NSSound.beep(); return }
            let range = tab.textView.selectedRange()
            let match: NSRange
            if backwards { match = matches.last(where: { $0.location < range.location }) ?? matches.last! }
            else { match = matches.first(where: { $0.location >= NSMaxRange(range) && !($0 == range) }) ?? matches.first! }
            tab.textView.setSelectedRange(match); tab.textView.scrollRangeToVisible(match)
            findStatus.stringValue = "\((matches.firstIndex(of: match) ?? 0) + 1) из \(matches.count)"
        } catch { findStatus.stringValue = "Ошибка Regex"; showError(error) }
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
            findStatus.stringValue = "Заменено: \(count)"
        } catch { showError(error) }
    }
    @objc func goToLine(_ sender: Any?) {
        guard let tab = current else { return }
        let alert = NSAlert(); alert.messageText = "Перейти к строке"
        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 220, height: 24)); field.stringValue = "1"; field.setAccessibilityLabel("Номер строки")
        alert.accessoryView = field; alert.addButton(withTitle: "Перейти"); alert.addButton(withTitle: "Отмена")
        alert.window.initialFirstResponder = field
        if alert.runModal() == .alertFirstButtonReturn, let line = Int(field.stringValue), line > 0 {
            let range = NSRange(location: TextPosition.offset(ofLine: line, in: tab.textView.string), length: 0)
            tab.textView.setSelectedRange(range); tab.textView.scrollRangeToVisible(range); window.makeFirstResponder(tab.textView)
        }
    }
    @objc func about() {
        NSApp.orderFrontStandardAboutPanel(options: [.applicationName: "Notepad Mac", .applicationVersion: "0.2.0", .credits: NSAttributedString(string: "Нативный текстовый редактор для macOS.\nНезависимый проект, вдохновлённый Notepad++.")])
    }
    func showError(_ error: Error) { let alert = NSAlert(error: error); alert.runModal() }
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
            if !didWarnPersistence { didWarnPersistence = true; showError(EditorError.message("Не удалось сохранить сессию: \(error.localizedDescription). Сохраните важные вкладки в файлы.")) }
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
            showError(EditorError.message("Сессия не прочитана. Исходная копия сохранена: \(backup.path)"))
        }
    }
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        if persist() { return .terminateNow }
        let alert = NSAlert(); alert.messageText = "Сессия не сохранена"
        alert.informativeText = "Сохраните документы перед выходом, чтобы не потерять изменения."
        alert.addButton(withTitle: "Вернуться"); alert.addButton(withTitle: "Выйти без восстановления")
        return alert.runModal() == .alertSecondButtonReturn ? .terminateNow : .terminateCancel
    }
    func windowShouldClose(_ sender: NSWindow) -> Bool { NSApp.terminate(nil); return false }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool { window.makeKeyAndOrderFront(nil); return true }
    func windowDidResize(_ notification: Notification) { current?.ruler.needsDisplay = true }
}
