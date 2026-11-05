import Foundation

/// Safe diagnostics: no response bodies, repository content, URLs or credentials.
public struct GitHubSyncHTTPFailure: Error {
    public let status: Int
    public let stage: String
    public let rateLimited: Bool
    public init(status:Int,stage:String,rateLimited:Bool=false) { self.status=status;self.stage=stage;self.rateLimited=rateLimited }
    public var needsRepositoryAccess: Bool { status == 403 && !rateLimited || status == 404 }
    public func message(english:Bool) -> String {
        let stages=["repository": ["проверка репозитория","repository check"],"branch":["чтение ветки","read branch"],"read":["загрузка заметок","download notes"],"write":["отправка заметок","upload notes"],"update":["обновление ветки","update branch"]]
        let step=stages[stage]?[english ? 1 : 0] ?? (english ? "request" : "запрос")
        let detail:String
        if rateLimited || status == 429 { detail=english ? "GitHub's request limit was reached. Wait before retrying." : "Достигнут лимит запросов GitHub. Повторите позже." }
        else { switch status {
        case 401: detail=english ? "The session expired or access was revoked. Sign out and sign in again." : "Вход истёк или доступ отозван. Выйдите и войдите снова."
        case 403: detail=english ? "GitHub denied access. Allow the Notepad App access to this repository with Contents: Read and write. Accept updated App permissions if GitHub asks." : "GitHub запретил доступ. Разрешите приложению Notepad доступ к этому репозиторию с правом Contents: Read and write. Подтвердите новые права App, если GitHub их запрашивает."
        case 404: detail=english ? "The repository or branch was not found, or the App cannot access it. Check its name. If it exists, allow Notepad access to this repository in connection options." : "Репозиторий или ветка не найдены либо недоступны приложению. Проверьте имя. Если репозиторий существует, откройте параметры подключения и разрешите Notepad доступ именно к нему."
        case 409 where stage == "branch": detail=english ? "The repository is empty. Add a README on GitHub to create its first branch, then synchronize again." : "Репозиторий пуст. Добавьте README на GitHub, чтобы появилась первая ветка, и повторите синхронизацию."
        case 409 where stage == "update",422 where stage == "update": detail=english ? "The branch changed or its protection rules rejected the update. Retry synchronization; if it repeats, check branch rules. No forced overwrite was performed." : "Ветка изменилась либо её правила отклонили обновление. Повторите синхронизацию; при повторной ошибке проверьте защиту ветки. Принудительная перезапись не выполнялась."
        case 422: detail=english ? "GitHub rejected the write. Check App write permission and repository rules." : "GitHub отклонил запись. Проверьте право записи App и правила репозитория."
        case 500...599: detail=english ? "GitHub is temporarily unavailable. Retry later." : "GitHub временно недоступен. Повторите позже."
        default: detail=english ? "GitHub rejected the request. Retry or check the connection options." : "GitHub отклонил запрос. Повторите или проверьте параметры подключения."
        } }
        return "HTTP \(status) · \(step). \(detail) " + (english ? "Local notes are preserved." : "Локальные заметки сохранены.")
    }
}
