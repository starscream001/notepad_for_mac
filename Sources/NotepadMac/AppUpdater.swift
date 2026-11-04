import AppKit
import Network
import NotepadCore

final class AppUpdater: NSObject, NSWindowDelegate {
    weak var app: AppDelegate?
    let defaults = UserDefaults.standard
    private let monitor = NWPathMonitor()
    private var timer: Timer?
    private var online = false
    private var retryAfter = Date.distantPast
    private var task: Task<Void, Never>?
    private var handedOff = false
    private var progressPanel: NSPanel?
    private let progressText = NSTextField(wrappingLabelWithString: "")
    private let progressBar = NSProgressIndicator()
    private var cancelButton: NSButton?
    private var settingsPanel: NSPanel?
    private let autoButton = NSButton(checkboxWithTitle: L("Автоматически проверять обновления"), target: nil, action: nil)
    private let intervalPopup = NSPopUpButton()
    private let settingsStatus = NSTextField(wrappingLabelWithString: "")
    private let intervals: [TimeInterval] = [21600, 86400, 604800]
    var busy: Bool { task != nil || handedOff }
    var isHandingOff: Bool { handedOff }
    var versionString: String { Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.3.0" }
    var enabled: Bool { defaults.object(forKey: "updatesEnabled") as? Bool ?? true }
    var interval: TimeInterval { let value = defaults.double(forKey: "updatesInterval"); return intervals.contains(value) ? value : 86400 }

    init(app: AppDelegate) { self.app = app; super.init() }
    func start() {
        acknowledgeInstall()
        monitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async { self?.online = path.status == .satisfied; self?.checkIfDue() }
        }
        monitor.start(queue: DispatchQueue(label: "NotepadMac.NetworkStatus"))
        timer = Timer.scheduledTimer(withTimeInterval: 600, repeats: true) { [weak self] _ in self?.checkIfDue() }
        NotificationCenter.default.addObserver(self, selector: #selector(becameActive), name: NSApplication.didBecomeActiveNotification, object: nil)
    }
    @objc private func becameActive() { checkIfDue() }
    func checkIfDue() {
        guard !busy, Date() >= retryAfter,
              UpdatePolicy.shouldCheck(enabled: enabled, online: online, lastAttempt: defaults.object(forKey: "updatesLastCheck") as? Date, interval: interval) else { return }
        check(manual: false)
    }
    func check(manual: Bool) {
        guard !busy else { progressPanel?.makeKeyAndOrderFront(nil); return }
        if manual { showProgress(L("Проверяем новые версии на GitHub…"), indeterminate: true) }
        task = Task { @MainActor [weak self] in
            guard let self else { return }
            var available: (GitHubRelease, GitHubRelease.Asset)?
            do {
                let release = try await UpdateNetworking.latest(version: versionString)
                guard let current = AppVersion(versionString) else { throw EditorError.message(L("Не удалось определить текущую версию приложения.")) }
                if let asset = try UpdatePolicy.candidate(from: release, newerThan: current) { available = (release, asset) }
                defaults.set(Date(), forKey: "updatesLastCheck")
                defaults.removeObject(forKey: "updatesLastError")
                retryAfter = .distantPast
                finishProgress()
                refreshSettings()
                if available == nil && manual { message(L("Установлена последняя версия"), L("Notepad Mac \(versionString). Новых стабильных версий на GitHub нет.")) }
            } catch {
                finishProgress()
                if !(error is CancellationError), (error as NSError).code != NSURLErrorCancelled {
                    retryAfter = Date().addingTimeInterval(900)
                    defaults.set(error.localizedDescription, forKey: "updatesLastError")
                    refreshSettings()
                    if manual { message(L("Не удалось проверить обновления"), L("\(error.localizedDescription)\n\nПроверьте подключение к интернету. Приложение продолжает работать без сети.")) }
                }
            }
            task = nil
            if let (release, asset) = available {
                if manual || defaults.string(forKey: "updatesOfferedVersion") != release.tag_name {
                    defaults.set(release.tag_name, forKey: "updatesOfferedVersion")
                    offer(release, asset: asset)
                }
            }
        }
    }
    private func offer(_ release: GitHubRelease, asset: GitHubRelease.Asset) {
        let alert = NSAlert()
        alert.messageText = L("Доступна Notepad Mac \(release.tag_name)")
        alert.informativeText = L("Сейчас установлена версия \(versionString).\n\nПриложение скачает обновление и перезапустится. Вкладки и несохранённый текст будут восстановлены.")
        alert.addButton(withTitle: L("Скачать и установить"))
        alert.addButton(withTitle: L("Позже"))
        alert.addButton(withTitle: L("Что нового"))
        switch alert.runModal() {
        case .alertFirstButtonReturn: install(release, asset: asset)
        case .alertThirdButtonReturn: NSWorkspace.shared.open(release.html_url)
        default: break
        }
    }
    private func install(_ release: GitHubRelease, asset: GitHubRelease.Asset) {
        let target = Bundle.main.bundleURL.resolvingSymlinksInPath().standardizedFileURL
        guard target.pathExtension == "app", !target.path.contains("/AppTranslocation/"),
              FileManager.default.isWritableFile(atPath: target.deletingLastPathComponent().path),
              (try? target.resourceValues(forKeys: [.volumeIsReadOnlyKey]).volumeIsReadOnly) != true else {
            message(L("Переместите приложение в «Программы»"), L("Для автоматической замены запустите приложение из доступной для записи папки. Если прав на папку нет, скачайте новую версию со страницы релиза и замените приложение через Finder."))
            NSWorkspace.shared.open(release.html_url); return
        }
        showProgress(L("Скачиваем обновление…"), indeterminate: false)
        task = Task { @MainActor [weak self] in
            guard let self else { return }
            let token = UUID().uuidString
            let stage = UpdateTicket.root.appendingPathComponent(token, isDirectory: true)
            do {
                try FileManager.default.createDirectory(at: stage, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
                let archive = stage.appendingPathComponent("update.zip")
                try await UpdateNetworking.download(asset, to: archive) { [weak self] written, _ in
                    DispatchQueue.main.async {
                        self?.progressBar.doubleValue = Double(written) / Double(asset.size) * 100
                        self?.progressText.stringValue = L("Скачиваем обновление: \(ByteCountFormatter.string(fromByteCount: written, countStyle: .file)) из \(ByteCountFormatter.string(fromByteCount: asset.size, countStyle: .file))")
                    }
                }
                try Task.checkCancellation()
                showProgress(L("Проверяем архив и приложение…"), indeterminate: true)
                let nextVersion = AppVersion(release.tag_name)!.description
                let prepared = try await Task.detached(priority: .userInitiated) {
                    try UpdatePolicy.verifyArchive(archive, expectedSize: asset.size, digest: asset.digest!)
                    let candidate = try UpdatePackage.unpack(archive, to: stage.appendingPathComponent("unpacked"))
                    try UpdatePackage.validate(candidate, expectedVersion: nextVersion)
                    return candidate
                }.value
                try Task.checkCancellation()
                guard app?.persist() == true else { throw EditorError.message(L("Сначала сохраните сессию или документы. Обновление не установлено.")) }
                let helperSource = Bundle.main.bundleURL.appendingPathComponent("Contents/Helpers/NotepadUpdater")
                let helper = stage.appendingPathComponent("NotepadUpdater")
                try FileManager.default.copyItem(at: helperSource, to: helper)
                try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: helper.path)
                let ticket = UpdateTicket(token: token, targetPath: target.path, candidatePath: prepared.path, version: nextVersion, previousVersion: versionString, parentPID: ProcessInfo.processInfo.processIdentifier)
                let ticketURL = stage.appendingPathComponent("ticket.json")
                try JSONEncoder().encode(ticket).write(to: ticketURL, options: .atomic)
                try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: ticketURL.path)
                let log = stage.appendingPathComponent("install.log")
                FileManager.default.createFile(atPath: log.path, contents: nil, attributes: [.posixPermissions: 0o600])
                let logHandle = try FileHandle(forWritingTo: log)
                defer { try? logHandle.close() }
                let process = Process(); process.executableURL = helper; process.arguments = [ticketURL.path]
                process.standardOutput = logHandle; process.standardError = logHandle
                try process.run()
                handedOff = true; cancelButton?.isEnabled = false
                progressText.stringValue = L("Сессия сохранена. Перезапускаем приложение…")
                task = nil
                NSApp.terminate(nil)
            } catch {
                try? FileManager.default.removeItem(at: stage)
                finishProgress(); task = nil
                if !(error is CancellationError), (error as NSError).code != NSURLErrorCancelled {
                    message(L("Обновление не установлено"), L("\(error.localizedDescription)\n\nТекущая версия и документы сохранены. Можно повторить проверку или скачать приложение со страницы GitHub."))
                }
            }
        }
    }
    private func acknowledgeInstall() {
        guard let argument = CommandLine.arguments.first(where: { $0.hasPrefix("--update-receipt=") }) else { return }
        let path = String(argument.dropFirst("--update-receipt=".count))
        do {
            let url = URL(fileURLWithPath: path)
            let ticket = try UpdateTicket.read(from: url)
            guard ticket.targetPath == Bundle.main.bundleURL.resolvingSymlinksInPath().path,
                  AppVersion(ticket.version) == AppVersion(versionString) else { return }
            let ack = url.deletingLastPathComponent().appendingPathComponent("started")
            try ticket.version.data(using: .utf8)!.write(to: ack, options: .atomic)
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
                self?.message(L("Обновлено до Notepad Mac \(ticket.version)"), L("Предыдущая версия: \(ticket.previousVersion). Вкладки и несохранённый текст восстановлены."))
            }
        } catch { NSLog("Update receipt: %@", error.localizedDescription) }
    }
    private func showProgress(_ title: String, indeterminate: Bool) {
        if progressPanel == nil {
            let panel = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 440, height: 142), styleMask: [.titled, .closable], backing: .buffered, defer: false)
            panel.title = L("Обновление Notepad Mac"); panel.delegate = self; panel.isReleasedWhenClosed = false
            let stack = NSStackView(); stack.orientation = .vertical; stack.spacing = 16; stack.alignment = .leading
            stack.edgeInsets = NSEdgeInsets(top: 20, left: 24, bottom: 20, right: 24)
            progressText.font = .systemFont(ofSize: 13); progressText.setAccessibilityLabel(L("Состояние обновления"))
            progressBar.style = .bar; progressBar.minValue = 0; progressBar.maxValue = 100
            let cancel = NSButton(title: L("Отмена"), target: self, action: #selector(cancelDownload)); cancel.bezelStyle = .rounded
            cancelButton = cancel
            stack.addArrangedSubview(progressText); stack.addArrangedSubview(progressBar); stack.addArrangedSubview(cancel)
            panel.contentView = stack
            progressText.widthAnchor.constraint(equalToConstant: 392).isActive = true
            progressBar.widthAnchor.constraint(equalToConstant: 392).isActive = true
            progressPanel = panel
        }
        progressText.stringValue = title
        progressBar.isIndeterminate = indeterminate; progressBar.doubleValue = 0
        if indeterminate { progressBar.startAnimation(nil) } else { progressBar.stopAnimation(nil) }
        cancelButton?.isEnabled = true
        progressPanel?.center(); progressPanel?.makeKeyAndOrderFront(nil)
    }
    private func finishProgress() { progressBar.stopAnimation(nil); progressPanel?.orderOut(nil) }
    @objc private func cancelDownload() { task?.cancel(); finishProgress() }
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        if sender === progressPanel { if handedOff { return false }; task?.cancel() }
        return true
    }
    private func message(_ title: String, _ body: String) { let alert = NSAlert(); alert.messageText = title; alert.informativeText = body; alert.addButton(withTitle: L("Хорошо")); alert.runModal() }
    func invalidateLocalization() { settingsPanel?.close(); settingsPanel = nil; intervalPopup.removeAllItems(); autoButton.title = L("Автоматически проверять обновления") }
    func showSettings() {
        if settingsPanel == nil {
            let panel = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 480, height: 230), styleMask: [.titled, .closable], backing: .buffered, defer: false)
            panel.title = L("Обновления"); panel.isReleasedWhenClosed = false
            let stack = NSStackView(); stack.orientation = .vertical; stack.alignment = .leading; stack.spacing = 16
            stack.edgeInsets = NSEdgeInsets(top: 24, left: 24, bottom: 24, right: 24)
            autoButton.target = self; autoButton.action = #selector(changeSettings)
            intervalPopup.addItems(withTitles: [L("Каждые 6 часов"), L("Раз в сутки"), L("Раз в неделю")])
            intervalPopup.target = self; intervalPopup.action = #selector(changeSettings); intervalPopup.setAccessibilityLabel(L("Периодичность проверки обновлений"))
            let intervalRow = NSStackView(views: [NSTextField(labelWithString: L("Проверять:")), intervalPopup]); intervalRow.spacing = 12
            let hint = NSTextField(wrappingLabelWithString: L("Проверка запускается при открытии приложения, возвращении в него и по расписанию, если подошёл срок и есть сеть. Установка — с вашего подтверждения."))
            hint.font = .systemFont(ofSize: 12); hint.textColor = .secondaryLabelColor
            settingsStatus.font = .systemFont(ofSize: 12)
            for label in [hint, settingsStatus] { label.widthAnchor.constraint(equalToConstant: 432).isActive = true }
            let check = NSButton(title: L("Проверить сейчас"), target: self, action: #selector(manualCheck)); check.bezelStyle = .rounded
            [autoButton, intervalRow, hint, settingsStatus, check].forEach(stack.addArrangedSubview)
            panel.contentView = stack; settingsPanel = panel
        }
        refreshSettings(); settingsPanel?.center(); settingsPanel?.makeKeyAndOrderFront(nil)
    }
    private func refreshSettings() {
        autoButton.state = enabled ? .on : .off
        intervalPopup.selectItem(at: intervals.firstIndex(of: interval) ?? 1); intervalPopup.isEnabled = enabled
        let last = defaults.object(forKey: "updatesLastCheck") as? Date
        let formatter = DateFormatter(); formatter.dateStyle = .medium; formatter.timeStyle = .short
        settingsStatus.stringValue = last.map { L("Последняя проверка: \(formatter.string(from: $0))") } ?? L("Обновления ещё не проверялись.")
        if let error = defaults.string(forKey: "updatesLastError") { settingsStatus.stringValue += "\n\(error)" }
    }
    @objc private func manualCheck() { check(manual: true) }
    @objc private func changeSettings() {
        defaults.set(autoButton.state == .on, forKey: "updatesEnabled")
        defaults.set(intervals[max(0, intervalPopup.indexOfSelectedItem)], forKey: "updatesInterval")
        refreshSettings(); checkIfDue()
    }
}
