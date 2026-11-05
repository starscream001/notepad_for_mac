import AppKit

extension AppDelegate {
    @MainActor @objc func showPreferences() {
        if let preferencesPanel { preferencesPanel.makeKeyAndOrderFront(nil); return }
        let panel = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 410, height: 560), styleMask: [.titled, .closable], backing: .buffered, defer: false)
        panel.title = L("Настройки…"); panel.isReleasedWhenClosed = false
        let stack = EditorListStack(); stack.orientation = .vertical; stack.alignment = .leading; stack.spacing = 16
        stack.edgeInsets = NSEdgeInsets(top: 24, left: 24, bottom: 24, right: 24)
        let language = NSPopUpButton(); language.addItems(withTitles: ["Русский", "English"]); language.selectItem(at: InterfaceLanguage.english ? 1 : 0)
        language.target = self; language.action = #selector(preferenceLanguageChanged(_:)); language.setAccessibilityLabel("Interface language")
        let dialect = NSPopUpButton(); dialect.addItems(withTitles: [L("Авто"), "SQL", "PostgreSQL", "MySQL"])
        let choices = ["auto","sql","postgresql","mysql"]
        dialect.selectItem(at: choices.firstIndex(of: UserDefaults.standard.string(forKey: "sqlDialect") ?? "auto") ?? 0)
        dialect.target = self; dialect.action = #selector(preferenceDialectChanged(_:)); dialect.setAccessibilityLabel(L("Диалект SQL"))
        for (label, popup) in [(L("Интерфейс / Interface"), language), (L("Диалект SQL"), dialect)] {
            let text = NSTextField(labelWithString: label); text.widthAnchor.constraint(equalToConstant: 155).isActive = true
            let row = NSStackView(views: [text, popup]); row.spacing = 12; stack.addArrangedSubview(row)
        }
        let hint = NSTextField(wrappingLabelWithString: L("Форматирование запускается только по команде. Авто выбирает диалект по расширению .psql / .pgsql / .mysql; для .sql используется обычный SQL."))
        hint.font = .systemFont(ofSize: 12); hint.textColor = .secondaryLabelColor; hint.widthAnchor.constraint(equalToConstant: 362).isActive = true
        stack.addArrangedSubview(hint)
        let divider = NSBox(); divider.boxType = .separator; divider.widthAnchor.constraint(equalToConstant: 362).isActive = true; stack.addArrangedSubview(divider)
        let githubView=GitHubSettingsView(account:githubAccount);githubSettingsView=githubView;stack.addArrangedSubview(githubView)
        let scroll=NSScrollView();scroll.hasVerticalScroller=true;scroll.autohidesScrollers=true;scroll.drawsBackground=false;scroll.documentView=stack
        stack.translatesAutoresizingMaskIntoConstraints=false
        NSLayoutConstraint.activate([stack.widthAnchor.constraint(equalToConstant:410),stack.leadingAnchor.constraint(equalTo:scroll.contentView.leadingAnchor),stack.topAnchor.constraint(equalTo:scroll.contentView.topAnchor)])
        panel.contentView = scroll; preferencesPanel = panel; panel.center(); panel.makeKeyAndOrderFront(nil)
    }
    @objc func preferenceLanguageChanged(_ sender: NSPopUpButton) {
        preferencesPanel?.close(); preferencesPanel = nil
        setInterfaceLanguage(sender.indexOfSelectedItem == 1 ? "en" : "ru")
    }
    var availableSchemes: [ColorScheme] {
        ColorScheme.all.filter { $0.dark == (NSApp.effectiveAppearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua) }
    }
    func refreshSchemes() {
        let choices = availableSchemes
        if let current = ColorScheme.current, !choices.contains(where: { $0.id == current.id }) {
            UserDefaults.standard.set("studio", forKey: "colorScheme")
        }
        palettePopup.removeAllItems(); palettePopup.addItems(withTitles: ["Studio"] + choices.map { InterfaceLanguage.english ? $0.en : $0.ru })
        palettePopup.selectItem(at: choices.firstIndex { $0.id == UserDefaults.standard.string(forKey: "colorScheme") }.map { $0 + 1 } ?? 0)
    }
    @objc func preferencePaletteChanged(_ sender: NSPopUpButton) {
        UserDefaults.standard.set(sender.indexOfSelectedItem == 0 ? "studio" : availableSchemes[sender.indexOfSelectedItem - 1].id, forKey: "colorScheme")
        // Recreate the chrome so AppKit's resolved dynamic colors cannot retain an old scheme.
        preferencesPanel?.close(); preferencesPanel = nil
        setInterfaceLanguage(InterfaceLanguage.english ? "en" : "ru")

    }
    @objc func preferenceDialectChanged(_ sender: NSPopUpButton) {
        UserDefaults.standard.set(["auto","sql","postgresql","mysql"][sender.indexOfSelectedItem], forKey: "sqlDialect")
    }
}
