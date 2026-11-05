import AppKit
import NotepadCore

@MainActor final class GitHubSettingsView: NSStackView {
    let account: GitHubAccount
    let status = NSTextField(wrappingLabelWithString: "")
    let detail = NSTextField(wrappingLabelWithString: "")
    let problem = NSTextField(wrappingLabelWithString: "")
    let code = NSTextField(string: "")
    let actions = NSStackView()
    private var creating = false
    init(account: GitHubAccount) {
        self.account = account; super.init(frame: .zero)
        orientation = .vertical; alignment = .leading; spacing = 10
        let title = NSTextField(labelWithString: "GitHub"); title.font = .systemFont(ofSize: 15, weight: .semibold)
        addArrangedSubview(title); addArrangedSubview(status); addArrangedSubview(detail); addArrangedSubview(problem)
        for label in [status, detail, problem] { label.widthAnchor.constraint(equalToConstant: 362).isActive = true; label.font = .systemFont(ofSize: 12); label.isSelectable = true }
        detail.textColor = .secondaryLabelColor
        code.isEditable = false; code.isSelectable = true; code.font = .monospacedSystemFont(ofSize: 20, weight: .semibold); code.alignment = .center
        code.setAccessibilityLabel("GitHub sign-in code"); code.widthAnchor.constraint(equalToConstant: 200).isActive = true; addArrangedSubview(code)
        actions.orientation = .vertical; actions.alignment = .leading; actions.spacing = 6; addArrangedSubview(actions)
        account.onChange = { [weak self] in self?.render() }; account.load(); render()
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    private func text(_ ru: String, _ en: String) -> String { InterfaceLanguage.english ? en : ru }
    private func add(_ ru: String, _ en: String, _ selector: Selector, enabled: Bool = true) {
        let title = text(ru,en), b = NSButton(title: title, target: self, action: selector)
        b.cell = EditorButtonCell(textCell: title); b.target = self; b.action = selector; b.font = .systemFont(ofSize: 13); b.isEnabled = enabled; b.alphaValue = enabled ? 1 : 0.45
        b.heightAnchor.constraint(equalToConstant: 30).isActive = true; actions.addArrangedSubview(b)
    }
    func render() {
        actions.arrangedSubviews.forEach { actions.removeArrangedSubview($0); $0.removeFromSuperview() }
        detail.stringValue = text("Пока только вход в аккаунт. Синхронизация заметок ещё не подключена.","Account sign-in only. Note synchronization is not connected yet.")
        problem.stringValue = account.error.map { message($0) } ?? (account.browserFailed ? text("Откройте GitHub кнопкой ниже.","Open GitHub using the button below.") : "")
        problem.isHidden = problem.stringValue.isEmpty; code.isHidden = account.phase != "waiting"; code.stringValue = account.userCode
        if let profile = account.profile {
            status.stringValue = "@" + profile.login + (profile.name.map { " · " + $0 } ?? "")
            add("Разрешить доступ GitHub","Allow GitHub access",#selector(installApp))
            add("Создать приватный репозиторий","Create private repository",#selector(createRepository),enabled: !creating)
            add("Профиль","Profile",#selector(openProfile)); add("Проверить вход","Check connection",#selector(refresh),enabled:account.phase != "checking"); add("Выйти","Sign out",#selector(signOut))
        } else {
            switch account.phase {
            case "unconfigured": status.stringValue = text("Вход будет доступен после настройки приложения разработчиком.","Sign-in will be available after the developer configures the app.")
            case "starting": status.stringValue = text("Подготавливаем безопасный вход…","Preparing secure sign-in…")
            case "waiting": status.stringValue = text("Скопируйте код и введите его на github.com/login/device. Подтвердите вход в браузере, затем вернитесь сюда.","Copy the code and enter it at github.com/login/device. Approve sign-in in your browser, then return here.")
            case "error": status.stringValue = text("Вход не завершён.","Sign-in did not complete.")
            default: status.stringValue = text("Аккаунт не подключён. Заметки остаются на устройстве.","Not connected. Your notes stay on this device.")
            }
            if account.phase == "waiting" { add("Копировать код","Copy code",#selector(copyCode)); add("Открыть GitHub","Open GitHub",#selector(openBrowser)) }
            if ["starting","waiting"].contains(account.phase) { add("Отмена","Cancel",#selector(cancel)) }
            else { add("Войти через браузер","Sign in with browser",#selector(signIn),enabled:account.phase != "unconfigured"); if account.phase == "error" { add("Выйти / очистить вход","Sign out / clear account",#selector(signOut)) } }
        }
    }
    private func message(_ error: GitHubIdentityError) -> String {
        switch error {
        case .storage: return text("Не удалось открыть защищённое хранилище. Попробуйте снова; токен открытым текстом не сохраняется.","Secure storage is unavailable. Retry; tokens are never saved as plaintext.")
        case .unauthorized: return text("Доступ отозван или истёк. Войдите снова.","Access was revoked or expired. Sign in again.")
        case .expired: return text("Время действия кода истекло. Начните вход заново.","The code expired. Start sign-in again.")
        case .denied: return text("Вход отклонён в браузере.","Sign-in was declined in the browser.")
        case .rateLimit: return text("GitHub ограничил запросы. Повторите позже.","GitHub is limiting requests. Try again later.")
        case .configuration: return text("Проверьте регистрацию OAuth App и Enable Device Flow.","Check the OAuth App registration and Enable Device Flow.")
        case .invalidResponse: return text("GitHub вернул неожиданный ответ. Вход остановлен.","GitHub returned an unexpected response. Sign-in stopped.")
        case .network: return text("Не удалось связаться с GitHub. Проверьте сеть.","Could not reach GitHub. Check your connection.")
        }
    }
    @objc private func createRepository() {
        guard !creating, let profile = account.profile else { return }
        let alert = NSAlert(); alert.messageText = text("Создать приватный репозиторий?","Create a private repository?")
        alert.informativeText = text("Аккаунт: ","Account: ") + profile.login + text(". Будет создано пустое хранилище с README. Заметки пока не отправляются.",". An empty repository with a README will be created. Notes are not uploaded yet.")
        let name = NSTextField(string: "notepad-notes"); name.frame = NSRect(x:0,y:0,width:300,height:26); alert.accessoryView = name
        alert.addButton(withTitle: text("Отмена","Cancel")); alert.addButton(withTitle: text("Создать","Create"))
        guard alert.runModal() == .alertSecondButtonReturn else { return }
        let value = name.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        creating = true; render(); problem.stringValue = text("Создаём приватный репозиторий…","Creating private repository…"); problem.isHidden = false
        Task { [weak self] in
            guard let self else { return }
            let message: String
            do { let repo = try await account.createRepository(name:value); message = text("Создан приватный репозиторий: ","Private repository created: ") + repo + text(". Синхронизация ещё не включена.",". Synchronization is not enabled yet.") }
            catch GitHubRepositoryError.nameUnavailable { message = text("Имя занято или недопустимо. Существующий репозиторий не изменён.","Name unavailable or invalid. No existing repository was changed.") }
            catch GitHubRepositoryError.permission { message = text("GitHub не дал разрешение: проверьте установку App и Repository creation.","GitHub denied creation: check the App installation and Repository creation permission.") }
            catch GitHubRepositoryError.invalidName { message = text("Допустимы латинские буквы, цифры, точка, дефис и подчёркивание, до 100 знаков.","Use letters, digits, dot, hyphen and underscore, up to 100 characters.") }
            catch { message = text("Не удалось подтвердить создание. Проверьте список репозиториев GitHub перед повтором.","Could not confirm creation. Check your GitHub repositories before retrying.") }
            creating = false; render(); problem.stringValue = message; problem.isHidden = false
        }
    }
    @objc private func installApp() { NSWorkspace.shared.open(URL(string:"https://github.com/apps/notepad-desktop/installations/new")!) }
    @objc private func signIn() { account.start() }
    @objc private func cancel() { account.cancel() }
    @objc private func signOut() { account.disconnect() }
    @objc private func refresh() { account.refresh() }
    @objc private func openProfile() { account.openProfile() }
    @objc private func openBrowser() { account.openBrowser() }
    @objc private func copyCode() { account.copyCode(); problem.stringValue = text("Код скопирован.","Code copied."); problem.isHidden = false }
}
