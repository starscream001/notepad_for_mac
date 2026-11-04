import AppKit
import NotepadCore

extension AppDelegate {
    @objc func formatDocument(_ sender: Any?) {
        guard !formatting, let tab = current else { return }
        let kind = tab.language == "JSON" ? "json" : tab.language == "SQL" ? "sql" : "unsupported"
        guard kind != "unsupported" else {
            showFormattingError("unsupported-format"); return
        }
        let source = tab.textView.string
        let selected = tab.textView.selectedRange()
        let range = selected.length > 0 ? selected : NSRange(location: 0, length: (source as NSString).length)
        let input = (source as NSString).substring(with: range)
        guard let script = Bundle.main.url(forResource: "formatter", withExtension: "js") else { showFormattingError("formatter-unavailable"); return }
        let configured = UserDefaults.standard.string(forKey: "sqlDialect") ?? "auto"
        let ext = tab.url?.pathExtension.lowercased() ?? ""
        let dialect = configured != "auto" ? configured : ["psql", "pgsql"].contains(ext) ? "postgresql" : ext == "mysql" ? "mysql" : "sql"
        formatting = true
        DispatchQueue.global(qos: .userInitiated).async { [weak self, weak tab] in
            let result = Result { try TextFormatting.format(input, kind: kind, dialect: dialect, scriptURL: script) }
            DispatchQueue.main.async {
                guard let self else { return }; self.formatting = false
                guard let tab, self.tabs.contains(where: { $0 === tab }), self.current === tab, tab.textView.string == source else { return }
                switch result {
                case .success(let text):
                    guard text != input else { return }
                    tab.textView.insertText(text, replacementRange: range)
                    tab.textView.undoManager?.setActionName(L("Форматирование"))
                    tab.textView.setSelectedRange(NSRange(location: min(range.location, (tab.textView.string as NSString).length), length: 0))
                case .failure(let error): self.showFormattingError(error.localizedDescription)
                }
            }
        }
    }
    func showFormattingError(_ code: String) {
        let messages: [String: (String, String)] = [
            "unsupported-format": ("Выберите JSON или SQL внизу окна. Форматирование Kafka / ksqlDB пока не поддерживается.", "Choose JSON or SQL in the status bar. Kafka / ksqlDB formatting is not supported yet."),
            "invalid-json": ("JSON содержит ошибку. Исходный текст оставлен без изменений.", "Invalid JSON. Your original text has been kept."),
            "invalid-sql": ("Не удалось разобрать SQL выбранного диалекта. Исходный текст оставлен без изменений. Диалект можно выбрать в настройках.", "Cannot parse SQL using the selected dialect. Your text has been kept. Choose a dialect in Settings."),
            "too-large": ("Для быстрого форматирования: JSON — до 1 млн символов, SQL — до 50 тыс. Можно выделить меньший фрагмент.", "For responsive formatting: JSON up to 1M characters, SQL up to 50K. You can select a smaller fragment."),
            "too-deep": ("JSON слишком глубоко вложен. Исходный текст не изменён.", "JSON nesting is too deep. Your text has not been changed.")
        ]
        let message = messages[code] ?? ("Не удалось загрузить форматирование.", "Could not load the formatter.")
        let alert = NSAlert(); alert.messageText = L("Форматирование"); alert.informativeText = InterfaceLanguage.english ? message.1 : message.0; alert.runModal()
    }
}
