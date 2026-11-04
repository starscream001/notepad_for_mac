import AppKit

enum InterfaceLanguage {
    static var english: Bool { UserDefaults.standard.string(forKey: "interfaceLanguage") == "en" }
    static let translations: [String: String] = [
        "Файл":"File", "Правка":"Edit", "Вид":"View", "Окно":"Window", "Поиск":"Search", "Новый":"New", "Открыть":"Open", "Открыть…":"Open…", "Сохранить":"Save", "Сохранить как…":"Save As…", "Новая вкладка":"New Tab", "Новая вкладка (⌘N)":"New Tab (⌘N)", "Закрыть вкладку":"Close Tab", "Закрыть вкладку (⌘W)":"Close Tab (⌘W)", "Недавние файлы":"Recent Files", "О Notepad Mac":"About Notepad Mac", "Проверить обновления…":"Check for Updates…", "Настройки обновлений…":"Update Settings…", "Поддержать разработчика…":"Support the Developer…", "Скрыть Notepad Mac":"Hide Notepad Mac", "Завершить Notepad Mac":"Quit Notepad Mac", "Отменить":"Undo", "Повторить":"Redo", "Вырезать":"Cut", "Копировать":"Copy", "Вставить":"Paste", "Выделить всё":"Select All", "Найти / заменить…":"Find / Replace…", "Найти далее":"Find Next", "Найти предыдущее":"Find Previous", "Перейти к строке…":"Go to Line…", "Предпросмотр Markdown / HTML":"Markdown / HTML Preview", "Перенос строк":"Word Wrap", "Увеличить шрифт":"Increase Font Size", "Уменьшить шрифт":"Decrease Font Size", "Следующая вкладка":"Next Tab", "Предыдущая вкладка":"Previous Tab", "Свернуть":"Minimize", "На весь экран":"Enter Full Screen", "Просмотр":"Preview", "Найти":"Find", "Заменить на":"Replace with", "Регистр":"Match case", "Назад":"Previous", "Далее":"Next", "Закрыть":"Close", "Заменить":"Replace", "Заменить всё":"Replace All", "Язык подсветки":"Syntax language", "Язык подсветки: Авто — по расширению файла":"Syntax language: Auto uses the file extension", "Кодировка файла":"File encoding", "Окончания строк":"Line endings", "Тема оформления":"Appearance", "Системная":"System", "Светлая":"Light", "Тёмная":"Dark", "Авто":"Auto", "Обычный текст":"Plain Text", "Новый документ · восстанавливается при следующем запуске":"New document · restored on next launch", "Файл изменён другой программой":"File Changed Outside the Editor", "Отмена":"Cancel", "Перезаписать":"Overwrite", "Не сохранять":"Don’t Save", "При закрытии без сохранения изменения этой вкладки будут удалены.":"Closing without saving discards changes in this tab.", "Совпадений нет":"No matches", "Ошибка Regex":"Invalid regex", "Перейти к строке":"Go to Line", "Номер строки":"Line number", "Перейти":"Go", "Разработчик — ":"Developer — ", "Илья (starscream001)":"Ilya (starscream001)", "\nРепозиторий Notepad Mac":"\nNotepad Mac Repository", "\n\nНативный текстовый редактор для macOS.\nБесплатно · открытый исходный код · MIT.\nПоддержка разработчика добровольная.":"\n\nNative text editor for macOS.\nFree · open source · MIT.\nDeveloper support is voluntary.", "Сессия не сохранена":"Session Not Saved", "Сохраните документы перед выходом, чтобы не потерять изменения.":"Save your documents before quitting to avoid losing changes.", "Вернуться":"Go Back", "Выйти без восстановления":"Quit Without Recovery", "Этот файл уже открыт в другой вкладке. Закройте её перед сохранением.":"This file is already open in another tab. Close it before saving.", "В первой версии поддерживаются файлы до 20 МБ.":"Files up to 20 MB are supported.", "Интерфейс / Interface":"Interface Language", "Вкладки":"Tabs", "Все вкладки…":"All Tabs…", "Поиск вкладки":"Find a tab"
    ]
    static let extra: [String: String] = [
        "Формат": "Format", "Форматировать": "Format Document / Selection", "Форматирование": "Formatting", "Настройки…": "Settings…", "Диалект SQL": "SQL dialect",
        "Форматирование запускается только по команде. Авто выбирает диалект по расширению .psql / .pgsql / .mysql; для .sql используется обычный SQL.": "Formatting runs only on command. Auto detects .psql / .pgsql / .mysql; .sql uses standard SQL.",
        "Автоматически проверять обновления": "Automatically check for updates",
        "Каждые 6 часов": "Every 6 hours",
        "Раз в сутки": "Daily",
        "Раз в неделю": "Weekly",
        "Не удалось определить текущую версию приложения.": "Could not determine the current application version.",
        "Не удалось проверить обновления": "Could Not Check for Updates",
        "Обновление Notepad Mac": "Notepad Mac Update",
        "Обновление не установлено": "Update Not Installed",
        "Обновления ещё не проверялись.": "Updates have not been checked yet.",
        "Обновления": "Updates",
        "Переместите приложение в «Программы»": "Move the App to Applications",
        "Периодичность проверки обновлений": "Update check interval",
        "Позже": "Later",
        "Проверить сейчас": "Check Now",
        "Проверяем архив и приложение…": "Verifying the archive and application…",
        "Проверяем новые версии на GitHub…": "Checking GitHub for updates…",
        "Проверять:": "Check:",
        "Сессия сохранена. Перезапускаем приложение…": "Session saved. Restarting the app…",
        "Скачать и установить": "Download and Install",
        "Скачиваем обновление…": "Downloading update…",
        "Сначала сохраните сессию или документы. Обновление не установлено.": "Save your session or documents first. The update was not installed.",
        "Состояние обновления": "Update status",
        "Установлена последняя версия": "You Are Up to Date",
        "Хорошо": "OK",
        "Что нового": "Release Notes",
        "Проверка запускается при открытии приложения, возвращении в него и по расписанию, если подошёл срок и есть сеть. Установка — с вашего подтверждения.": "Checks run on launch, on returning to the app and periodically when due and online. Installation requires your confirmation.",
        "Для автоматической замены запустите приложение из доступной для записи папки. Если прав на папку нет, скачайте новую версию со страницы релиза и замените приложение через Finder.": "Run the app from a writable folder for in-app updates. Otherwise download the release and replace the app using Finder.",
        "QR-код для поддержки разработчика через банк": "Bank QR code to support the developer",
        "Можно поддержать проект отзывом, сообщением об ошибке или звездой на GitHub.": "You can also help with feedback, bug reports or a star on GitHub.",
        "Открыть проект на GitHub": "Open Project on GitHub",
        "Открыть ссылку": "Open Link",
        "Отсканируйте QR телефоном. Сумму и перевод подтвердите в своём банковском приложении.": "Scan the QR with your phone. Confirm the amount and payment in your banking app.",
        "Перевод через СБП по номеру телефона. Выберите Ozon Банк и подтвердите перевод в своём банке.": "Transfer via SBP using the phone number. Select Ozon Bank and confirm in your banking app.",
        "Поддержать разработчика": "Support the Developer",
        "Поддержка Notepad Mac": "Support Notepad Mac",
        "Разработчик — Илья (starscream001).\nNotepad Mac бесплатный и открытый. Поддержка добровольная — все функции доступны каждому.": "Developer — Ilya (starscream001).\nNotepad Mac is free and open source. Support is voluntary; all features are available to everyone.",
        "Скопировать номер": "Copy Phone Number",
        "Скопировать ссылку": "Copy Link"
    ]
    static func source(_ displayed: String) -> String {
        translations.first(where: { $0.value == displayed })?.key ?? displayed
    }
}
func L(_ text: String) -> String {
    guard InterfaceLanguage.english else { return text }
    if let value = InterfaceLanguage.translations[text] ?? InterfaceLanguage.extra[text] { return value }
    let patterns: [(String, String)] = [
        (#"^Последняя проверка: (.+)$"#, "Last checked: $1"),
        (#"^Получатель: (.+)$"#, "Recipient: $1"),
        (#"^Без имени (\d+)$"#, "Untitled $1"),
        (#"^Закрыть (.+)$"#, "Close $1"),
        (#"^Сохранить «(.+)»\?$"#, "Save “$1”?"),
        (#"^Стр (\d+), стлб (\d+)   ·   (.+)   ·   (\d+) симв\.$"#, "Ln $1, Col $2   ·   $3   ·   $4 chars"),
        (#"^Заменено: (\d+)$"#, "Replaced: $1"),
        (#"^(\d+) из (\d+)$"#, "$1 of $2")
    ]
    for (pattern, replacement) in patterns {
        if let regex = try? NSRegularExpression(pattern: pattern), regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) != nil {
            return regex.stringByReplacingMatches(in: text, range: NSRange(text.startIndex..., in: text), withTemplate: replacement)
        }
    }
    return text
}
