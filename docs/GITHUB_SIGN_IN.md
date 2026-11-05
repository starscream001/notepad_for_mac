# GitHub App — настройка разработчиком для 0.9

Эта инструкция заменяет предыдущую регистрацию OAuth App. Конечная цель — вход, подтверждение создания private repo и sync. Текущий прогресс: [SYNC_PROGRESS](SYNC_PROGRESS.md). Рабочая 0.8 не меняется.

## Регистрация один раз

1. Открыть https://github.com/settings/apps/new под аккаунтом владельца.
2. Название: Notepad Desktop (если занято — выбрать уникальное). Homepage: https://github.com/starscream001/notepad_for_mac . Описание: приватные заметки и синхронизация в собственный репозиторий пользователя.
3. Включить Device Flow. Webhooks отключить: наш сервер не используется. Callback для этого flow не нужен; если форма требует — http://127.0.0.1/callback, он не используется приложением, локальный сервер не запускается.
4. Для будущей синхронизации: Repository permissions → Contents read/write; Metadata read. Для создания репозиториев — Repository creation write, если доступно. Не запрашивать удаление репозиториев, Issues, Actions, почту или широкий Administration ради создания.
5. Разрешить установку другими пользователями (Any account), если готовится публичный выпуск. Для этого проекта сразу выбрать Any account; Only on this account не подходит публичным пользователям.
6. Сохранить регистрацию. Нужны только публичные Client ID и slug (имя из github.com/apps/<slug>). Private key / Client Secret не нужны клиентскому Device Flow, не присылать и не коммитить.
7. Заполнить Resources/GitHubOAuth.json: clientID и appSlug. Mac и Desktop build копируют общий ресурс. Регистрацию пользователь Notepad повторять не будет.

## Вход и доступ

GitHub App Device Flow не использует OAuth scopes read:user/repo; права задаются регистрацией и установкой App. Подготовленные клиенты отправляют client_id без scope и принимают пустой scope токена GitHub App. Старые OAuth-токены read:user не должны приниматься новым валидатором.

Пользователь нажимает «Войти», копирует код, подтверждает его на https://github.com/login/device . Пароль/2FA остаются в браузере. Далее потребуется отдельное подтверждение создания private repo в Notepad. Установка App на выбранный репозиторий может потребовать дополнительного окна GitHub. Не считать вход доказательством Contents write.

## Что уже есть и чего нет

Есть Device Flow обоих клиентов, Keychain/safeStorage, профиль, cancel/logout, обработка ошибок и сроков. Подготовлен portable codec JS. Настоящий вход ожидает Client ID и QA. UI создания private repo, установка/проверка прав и обмен заметками ещё в работе. Expiring token требует повторного входа; refresh пока не реализован. Устройство не хранит client secret.

Для разработки NOTEPAD_GITHUB_CLIENT_ID — override публичного Client ID; сессии изолировать NOTEPAD_SESSION_DIR / NOTEPAD_DESKTOP_DATA. На Linux plaintext basic_text запрещён, нужен Secret Service/KWallet. Logout удаляет локальные credentials; отзыв разрешения — GitHub Settings/Applications. Токены не должны попадать в renderer, session.json или логи.

Перед релизом: реальный вход/отказ/cancel/expiry/restart/revocation, создание private repo с отдельным подтверждением, установка на выбранный repo, первая синхронизация, отсутствие потери заметок, Windows/Linux QA. Mock-тесты не заменяют эту проверку.

Источники: https://docs.github.com/en/apps/creating-github-apps/authenticating-with-a-github-app/generating-a-user-access-token-for-a-github-app и https://docs.github.com/en/apps/creating-github-apps/registering-a-github-app/choosing-permissions-for-a-github-app .

## Перепроверенные поля формы (5 ноября 2026)

- Callback URL: пусто, Device Flow игнорирует callback; localhost-заглушка не требуется.
- Expire user authorization tokens: включено.
- Request user authorization (OAuth) during installation: выключено, чтобы не запускать отдельный web callback flow. Вход запускается нашим Device Flow.
- Enable Device Flow: включено.
- Setup URL: пусто; Redirect on update: выключено.
- Webhook Active: выключено; URL/Secret пусто. SSL verification не отключать (при выключенных webhooks не используется).
- Contents: Read and write; Metadata: Read-only; Repository creation: Write / Read and write, как называется уровень в форме.
- Остальные repository/organization/account permissions: No access. Administration для создания не добавлять — отдельное Repository creation покрывает этот сценарий.
- Any account: включено.

GitHub документирует автоматический доступ App к созданным им репозиториям. Тем не менее реализация должна проверить installation/repository access до передачи заметок. После регистрации нужны публичные Client ID и URL github.com/apps/<slug>; секреты не передавать.
