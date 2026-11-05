# GitHub sync 0.9 — план и продолжение

Решение владельца: полный сценарий «вход → подтверждение создания private repo → первая синхронизация», по шагам с отдельными коммитами. Не выпускать unfinished stable. Без сервера разработчика.

## Шаги

- [x] 0. Подготовленный ранее Device Flow / secure storage / UI (e798ad4). Пока OAuth read:user, НЕ GitHub App sync.
- [x] 1. Переносимый формат JS v1 и тесты безопасности/восстановления. desktop/sync-format.cjs. Не подключён к сессии/UI; native adapter впереди.
- [x] 2. Подготовлены оба auth клиента под GitHub App Device Flow без OAuth scopes; старый кеш отделён provider-маркером. Регистрационная инструкция заменена. Нужны публичный Client ID и app slug от владельца; реальный вход пока не проверен.
- [ ] 3. Добавить подтверждение «Создать приватный репозиторий и отправить выбранные проекты», имя notepad-notes, список отправляемого, Отмена. POST /user/repos с private=true и auto_init=true. Занятое имя не означает согласия подключить существующий repo. Не повторять POST автоматически при неизвестном результате сети.
- [ ] 4. Проверить установку GitHub App и доступ к новому repo. Вход и установка — разные действия. При необходимости открыть установку App в браузере с доступом только к выбранному repo. Затем Git Data API tree/commit/non-force ref update одним commit.
- [ ] 5. Получение на другом устройстве, base/local/remote, конфликтные копии, rename и tombstones. Не перезаписывать remote/не делать force push.
- [ ] 6. Оба клиента, expiry/refresh/cancel/logout/offline, ручной E2E с GitHub и Windows/Linux QA.
- [ ] 7. Поднять версии до 0.9, README/CHANGELOG/Release notes, CI и публикация. Published 0.8 не менять.

## Сценарий

Вход сам ничего не создаёт. После входа отдельное подтверждение в Notepad сообщает имя, private-доступ и проекты для отправки. После создания проверить owner/private; проверить права App; лишь затем отправлять заметки. Локальные данные сохраняются. Отказ от установки/создания не мешает локальной работе. Сначала личные аккаунты; организации отдельно.

## Формат

notepad/manifest.json: schema=1, projects [{id,title}], tabs [{id,projectId,title,file}]. Текст: notepad/tabs/<UUID>.txt. UUID — идентичность; имена не образуют пути. Не отправлять абсолютные пути, токены, savedText, настройки окон. До 100 проектов, 300 вкладок, 20 MiB на вкладку. Импорт проверяет схему/идентичность/пути и не читает произвольные файлы. Удаления/базовые ревизии ещё не реализованы.

## Регистрация — важное уточнение

Старая docs/GITHUB_SIGN_IN.md пока описывает OAuth App. Для нового сценария нужен GitHub App: НЕ отправлять владельца регистрировать старый вариант. Device Flow не требует секретного ключа в клиенте. Для sync Contents read/write, Metadata read; для создания отдельное Repository creation write вместо широкого Administration, если доступно в регистрации. Создание репозитория само по себе не гарантирует установку App/доступ к Contents. Webhooks/backend не нужны. Не использовать токен коннектора Codex для пользователей Notepad.

Источники: https://docs.github.com/en/rest/repos/repos#create-a-repository-for-the-authenticated-user и https://docs.github.com/en/apps/creating-github-apps/registering-a-github-app/choosing-permissions-for-a-github-app . Проверено 2026-11-05.

## Продолжение

Прочитать git status/log, AGENTS.md, HANDOFF.md, этот файл. Начать с шага 3, не переписывать готовое. После каждого шага обновлять статус и коммитить. Mock-тесты не означают реальную синхронизацию. Client ID/slug и E2E пока ожидаются; публикацию не запускать.

Регистрация от владельца: https://github.com/apps/notepad-desktop ; appSlug записан в общий ресурс. Передано число 5629691 (предположительно App ID), НЕ использовать его как Client ID. Публичный Client ID ещё ожидается.

Client ID получен от владельца и подключён: Iv23liPeQma6kkZ1Ndog, appSlug notepad-desktop. Следующий пользовательский тест — настоящий Device Flow в локальной Mac-сборке; создание repo и sync ещё НЕ подключены.

Выпуск 0.9: добавлены UI подтверждения и private repo POST обоих клиентов, кнопка официальной установки App; формат ещё не передаётся. Создание покрыто mock tests (44 всего), реальное создание требует пользовательского QA. Верхняя панель Mac компактная, sidebar отделён. Следующий этап: установка/права и первый sync commit; не считать completed sync.
