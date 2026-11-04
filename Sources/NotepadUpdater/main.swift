import AppKit
import Foundation
import Darwin
import NotepadCore

func launch(_ app: URL, arguments: [String]) throws -> NSRunningApplication {
    let configuration = NSWorkspace.OpenConfiguration()
    configuration.activates = true; configuration.createsNewApplicationInstance = true; configuration.arguments = arguments
    if let isolatedSession = ProcessInfo.processInfo.environment["NOTEPAD_SESSION_DIR"] { configuration.environment = ["NOTEPAD_SESSION_DIR": isolatedSession] }
    var result: Result<NSRunningApplication, Error>?
    NSWorkspace.shared.openApplication(at: app, configuration: configuration) { application, error in
        DispatchQueue.main.async {
            if let application { result = .success(application) }
            else { result = .failure(error ?? EditorError.message("macOS не удалось открыть приложение.")) }
        }
    }
    let deadline = Date().addingTimeInterval(30)
    while result == nil && Date() < deadline { RunLoop.current.run(until: Date().addingTimeInterval(0.1)) }
    guard let result else { throw EditorError.message("macOS не ответила на запрос запуска приложения.") }
    return try result.get()
}

func showFailure(_ text: String) {
    NSApplication.shared.setActivationPolicy(.accessory)
    NSApp.activate(ignoringOtherApps: true)
    let alert = NSAlert(); alert.messageText = "Обновление Notepad Mac"
    alert.informativeText = text; alert.addButton(withTitle: "Хорошо"); alert.runModal()
}

func install(ticketURL: URL) throws {
    let ticket = try UpdateTicket.read(from: ticketURL)
    let candidate = URL(fileURLWithPath: ticket.candidatePath)
    let target = URL(fileURLWithPath: ticket.targetPath)
    let stage = ticketURL.deletingLastPathComponent()
    try UpdatePackage.validate(candidate, expectedVersion: ticket.version)
    try UpdatePackage.validate(target, expectedVersion: ticket.previousVersion)
    guard let next = AppVersion(ticket.version), let previous = AppVersion(ticket.previousVersion), next > previous else {
        throw EditorError.message("Версия обновления должна быть новее установленной.")
    }
    let deadline = Date().addingTimeInterval(90)
    while kill(ticket.parentPID, 0) == 0 {
        guard Date() < deadline else { throw EditorError.message("Приложение не завершилось. Текущая версия не изменена. Повторите обновление.") }
        Thread.sleep(forTimeInterval: 0.1)
    }
    guard errno == ESRCH else { throw EditorError.message("Не удалось подтвердить завершение приложения.") }
    let transaction = UpdateTransaction(target: target, token: ticket.token)
    try transaction.install(from: candidate) { try UpdatePackage.validate($0, expectedVersion: ticket.version) }
    do {
        let application = try launch(target, arguments: ["--update-receipt=\(ticketURL.path)"])
        let acknowledgement = stage.appendingPathComponent("started")
        let timeout = Date().addingTimeInterval(60)
        while Date() < timeout {
            if (try? String(contentsOf: acknowledgement, encoding: .utf8)) == ticket.version {
                try? transaction.confirm()
                try? FileManager.default.removeItem(at: stage)
                return
            }
            if application.isTerminated { throw EditorError.message("Новая версия завершилась до подтверждения запуска.") }
            RunLoop.current.run(until: Date().addingTimeInterval(0.1))
        }
        // A running application may be waiting on a macOS permission dialog.
        // Keep the backup, rather than replacing a running bundle again.
        showFailure("Новая версия установлена, но запуск ещё не подтверждён. Проверьте окно приложения или сообщение macOS. Предыдущая копия сохранена:\n\(transaction.backup.path)")
    } catch {
        try transaction.rollback()
        _ = try? launch(target, arguments: [])
        throw EditorError.message("\(error.localizedDescription)\n\nПредыдущая версия восстановлена. Документы сохранены в сессии.")
    }
}

guard CommandLine.arguments.count == 2 else { fputs("Expected update ticket path.\n", stderr); exit(2) }
do { try install(ticketURL: URL(fileURLWithPath: CommandLine.arguments[1])) }
catch { NSLog("Update failed: %@", error.localizedDescription); showFailure(error.localizedDescription); exit(1) }
