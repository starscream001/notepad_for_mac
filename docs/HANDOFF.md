# Передача работы между платформами

Это точка входа для следующей сессии разработки. Необходимо сначала прочитать корневой `AGENTS.md`.

## Клиенты — актуальная сводка

| Клиент | Реализация | Что проверять дальше |
| --- | --- | --- |
| macOS | Swift/AppKit; universal arm64+x86_64, macOS 13+ | Нативный пакет, обновление с 0.3/0.4/0.5, геометрия на минимальном окне |
| Windows x64 | Electron + CodeMirror; NSIS EXE | Установка/удаление на Windows 10/11, Unicode-пути, диалоги, повторный запуск, DPI |
| Linux x64 | Тот же клиент; AppImage + deb | Ubuntu 24.04, Wayland/X11, AppImage/FUSE, права файла, окна и горячие клавиши |
| iOS/iPadOS/Android | mobile/, Capacitor8 + CodeMirror, local-first beta0.10.0-beta.1 | APK на физическом Android; iOS Simulator/Xcode. Подпись/TestFlight и mobile GitHub ещё впереди |

GitHub Actions подтверждает компиляцию/упаковку на каждой ОС. Живое пользовательское тестирование Windows/Linux остаётся отдельной задачей после переключения на соответствующую машину. См. [чек-лист](PLATFORM_TESTING.md).

## Где что находится

- `Sources/NotepadMac/App.swift`: окна, меню, вкладки, открытие/сохранение, сессии.
- `EditorView.swift`: текстовый редактор, номера строк, подсветка; `EditorControls.swift`: оформление кнопок/вкладок.
- `PreviewPane.swift`: WebKit, офлайн Marked в JavaScriptCore, CSP и запрет скриптов документа.
- `Sources/NotepadCore/Updates.swift`, `UpdateNetworking.swift`, `NotepadMac/AppUpdater.swift`, `NotepadUpdater/main.swift`: Mac updater с SHA256, подготовкой, заменой, подтверждением запуска и откатом.
- `desktop/main.cjs`: привилегированный процесс, диалоги/файлы/сессии/проверка GitHub.
- `desktop/preload.cjs`: ограниченный IPC API; `src/renderer.js`: CodeMirror и вкладки/preview; `src/style.css`: интерфейс.
- `desktop/core.cjs`: кодировки, окончания строк, атомарная запись, версии.
- `desktop/build.mjs`, `package.json`: сборка renderer и установочных пакетов. `npm ci` обязателен для повторяемых зависимостей.
- `scripts/publish.sh`: release из draft после успешных сборок, все пакеты и SHA256, существующие stable не перезаписываются.

## Сессии и безопасная диагностика

Mac: `~/Library/Application Support/NotepadMac/session.json`.
Desktop: Electron `app.getPath('userData')`, каталог `notepad-desktop`; точный путь зависит от ОС (Windows `%APPDATA%`, Linux `$XDG_CONFIG_HOME` или `~/.config`).
Клиенты используют независимые сессии: автоматической миграции между Swift и Electron пока нет. Документы переносятся обычными файлами.

Для теста задавать **NOTEPAD_DESKTOP_DATA** отдельным каталогом до `npm start`. Повреждённая сессия переносится в `.damaged-<time>`, не удаляется. Перед исправлениями сессий сделать копию.

## Различия 0.6, которые нельзя скрывать

- Mac поддерживает установку обновления из приложения; Windows/Linux проверяют GitHub и открывают Release для ручной установки.
- Desktop использует CodeMirror и имеет свой набор языков: текст, Markdown, HTML, SQL, Kafka/ksqlDB, JavaScript/TypeScript, Python, JSON, CSS. Mac дополнительно подсвечивает Swift/C/C++/YAML/Shell/XML.
- У Desktop нет полного списка недавних файлов и сохранения пользовательского размера шрифта; есть zoom, поиск/замена и regex CodeMirror.
- Внешние картинки/CSS/JS в preview запрещены. Это просмотр Markdown/HTML, не браузер и не сервер разработки.
- Сборки не подписаны платными сертификатами. Требуется проверка реального поведения SmartScreen/Gatekeeper; не отключать защиту целиком.
- Первая поддержка Windows/Linux — x64; ARM64 и другие дистрибутивы — после проверки.

## Следующая сессия на Windows/Linux

1. Клонировать репозиторий, проверить актуальные `main` и Release, прочитать эти инструкции.
2. Установить готовый пакет, выполнить `PLATFORM_TESTING.md`, записать ОС/версию/архитектуру/результаты.
3. Для дефекта сохранить воспроизведение и лог, запустить исходники в изолированном каталоге сессии.
4. Исправить конкретный дефект, добавить смысловой тест для файлов/сессии при необходимости; перепроверить затронутый сценарий.
5. Выпустить следующий patch-релиз с описанием и всеми платформенными пакетами; не перезаписывать 0.6.0.

## Следующие продуктовые приоритеты

После стабилизации 0.6: 0.7 — мобильный прототип Android/iPhone/iPad с планшетной раскладкой; 0.8 — линтеры/форматирование/LanguageTool/LSP; 0.9+ — AI/Ollama и API адаптеров. См. ROADMAP. Эти функции пока не реализованы.

## Добавлено перед выпуском 0.6

Компактные панели, адаптивный footer Desktop, русский/английский интерфейс, Telegram @Ilya_Manik, список всех вкладок с поиском. С 0.7.0: язык интерфейса в настройках обоих клиентов. Сценарий 120 вкладок проверен на обоих клиентах в macOS, результаты в PLATFORM_TESTING. Desktop ограничивает сессию 300 вкладками. Логи ошибок renderer — errors.log в userData (не содержат специально записываемого текста документов).

## Состояние 0.7.0

Приоритет владельца: лёгкий быстрый редактор. Не добавлять автоматические линтеры, AI, LSP и индексирование без отдельной задачи. Следующий возможный шаг — открыть папку, ленивое дерево, скрываемая панель и восстановление вкладок проекта; пока не реализовано.

- Палитры: общий Resources/Palettes.json, 28 уникальных пар (две пары повторяются в исходном списке Алисы), по 14 для каждой темы. Native EditorControls.swift/Preferences.swift; Desktop renderer.js. Нижний селектор фильтруется по теме. При несовместимой смене темы сброс на Studio; язык интерфейса в Settings.
- Форматирование: Formatting/formatter.mjs; SQL formatter 15.9.0 devDependency. Только SQL/PostgreSQL/MySQL, не ksqlDB. JSON лексический pretty printer после валидации, не JSON.stringify: сохраняет большие числа и дубли ключей. Регенерация `cd desktop && npm ci && npm run build`; Resources/Vendor/formatter.js и MIT notice коммитятся, native CI не требует Node. Mac TextFormatting.swift + FormattingAction.swift, JSCore вне main queue; Desktop временный Worker с timeout 10s. Защита от применения к изменившейся вкладке, одно Undo.
- scripts/release-retention.cjs вызывается publish.sh только после публикации: newest stable должен иметь четыре пакета и SHA256, иначе удаление запрещено. Сохраняет два newest stable, у более старых удаляет только ZIP/EXE/AppImage/deb и SHA256. Draft/prerelease (в том числе архив latest), теги и notes не удаляет. Изменение исторических assets здесь явно разрешено владельцем. Новые Actions artifacts — 7 дней.
- Тестовые session dirs для новых unsigned app ID на macOS размещать в /private/tmp: Documents может вызвать TCC ожидание. Не менять пользовательскую сессию и /Applications без задачи.

## Патч 0.7.1

Список вкладок и поиск приведены к Studio. Mac tabListRows — EditorListStack с isFlipped=true: без этого короткие списки рисуются внизу viewport. Поля поиска 30pt, regex/case — push-on/off кнопки. Desktop searchPhrases через Compartment: при смене locale открытый поиск пересоздаётся с сохранением SearchQuery; CSS меняет поля, кнопки, маркировку совпадений. В списке есть aria-current, путь второй строкой, пустое состояние и число найденных/всех вкладок. Текущая версия 0.7.1; 0.7.0 опубликована отдельно.

## Патч 0.7.2

Текущая версия 0.7.2. Отдельный About в верхней панели, Settings gear в footer обоих клиентов. Язык и SQL остаются в Settings, параметры документа — внизу. Resources/Palettes.json светлые сокращены до paper/sky/red (всегда белый фон, цвет кнопок/активной вкладки); все 14 dark оставлены как были (всего 17 схем + Studio). Studio в обеих темах. По последнему решению владельца peach/cream и остальные светлые фоны удалены. Публиковать каждый патч с README/CHANGELOG/notes, не заменять уже опубликованные бинарники.

## Патч 0.7.3 — Windows updater

Текущая версия 0.7.3. Владелец уточнил Windows: только там добавлена загрузка и запуск установщика без браузера. Linux остаётся ручным. `desktop/updates.cjs` — строгий candidate, HTTPS redirect allowlist, потоковый размер/SHA256, отмена/cleanup, повторная проверка перед install. `main.cjs` хранит preparedUpdate вне renderer, пишет Zone.Identifier, запускает shell.openPath после snapshot/persist и только затем завершает app. `preload` даёт ограниченные cancelUpdate/installUpdate/onUpdate. Renderer modal показывает progress/ready/errors; install сначала ждёт flush. NSIS runAfterFinish=true; без silent и обхода UAC/SmartScreen. Новых зависимостей нет. `updates.cjs` обязательно включён в builder.files.

Переход <=0.7.2 → 0.7.3 один раз вручную, затем обновления из программы. Нет автоматического отката NSIS, не заявлять обратное. Ручное испытание install/restart на Windows обязательно по PLATFORM_TESTING; macOS не может подтвердить реальную работу мастера Windows. Node-тесты моделируют запуск (не исполняют EXE), проверяют повреждения/отмену/ошибку записи сессии. См. UPDATES.md.

## Текущее состояние 0.8.0 — виртуальные проекты

Этот раздел заменяет старые предположения о дереве папок и номерах будущих этапов выше. Проект — группа вкладок, НЕ каталог. Проекты слева, сверху только вкладки активного проекта; «Без проекта» для старых документов. Имя UI/экспорта `Project.Tab`, базовое имя хранится отдельно. Двойной клик — переименование, не fs rename. До 100 проектов, Desktop до 300 вкладок всего. Удаление проектов/перенос вкладок между группами пока не включены.

Native: `Projects.swift`, SessionProject/SessionTab.projectID, Session.projects/selectedProject/looseSelected. `visibleTabs` определяет верхние вкладки/цикл/закрытие/список. Все документы всё равно сохраняются в session.json. При legacy restore копия session.before-projects.json; сироты переводятся в «Без проекта» без потери текста. EditorListStack isFlipped для списка. Workspace NSStackView distribution=.fill и низкий hugging editorSplit обязательны: иначе редактор сжимается до 280pt и оставляет пустую область.

Desktop: `projects.cjs` нормализует старые сессии и membership, входит в builder.files. main сохраняет projects/selectedProject, renderer хранит выбранную вкладку проекта, настройки looseSelected/projectsHidden. Никаких сканеров каталогов. `src/preview.js` DOMPurify WHOLE_DOCUMENT сохраняет корневые атрибуты/inline styles, CSP и sandbox запрещают скрипты/внешние ресурсы. Native не создаёт внешний body поверх полного HTML. Пример регрессии `examples/preview-layout.html`; MD `examples/preview.md`.

Проверены CoreChecks, 31 Node-тест, production native и Electron package на Mac, реальные UI обоих клиентов в изолированных каталогах `/private/tmp/notepad-08-qa/native` и `/private/tmp/notepad-08-qa/desktop`. Test app IDs `.projectsqa`; обычное приложение/его сессия не изменялись. Проверены миграция, создание, независимые вкладки, last selection, переименование, несохранённый текст, HTML CSS/Grid/table и Markdown. Windows/Linux: CI не заменяет ручную установку/перезапуск/DPI.

Следующее: сначала PLATFORM_TESTING на Windows/Linux. Затем переносимый формат/экспорт и sync conflict core, первый GitHub адаптер, отдельный мобильный прототип. `ROADMAP.md` и `SYNC-0.9.md` — актуальный план. Не встраивать secret OAuth в приложение, не заводить сервер разработчика, не активировать синхронизацию без пользователя. Остальные Git/облака подключать постепенно. MIT в 0.8 сохранён, лицензирование будущих модулей ещё не выбрано. Центральные WinGet/Homebrew/Flathub пока НЕ содержат приложение; `packaging/README.md` содержит реальные команды GitHub CLI и требования подачи.

При Save/Save As вкладка проекта сохраняет базовый alias; иначе экспорт Project.Note.txt повторно добавлял бы Project в UI. Для документов без проекта имя обновляется по выбранному имени файла, как раньше.

## Подготовка GitHub sign-in — текущая незавершённая публикация 0.9

По последнему решению владельца сначала только нормальный вход через браузер, без токена вручную и без синхронизации. Владелец выбрал «подготовь код и инструкцию», OAuth App ещё НЕ зарегистрирована/Client ID не получен. Код и инструкции локально; VERSION остаётся 0.8.0, опубликованные assets не менять. Не объявлять реальный вход протестированным. Следующий шаг: владелец по `GITHUB_SIGN_IN.md` регистрирует OAuth App + Enable Device Flow, передаёт публичный Client ID; заполнить Resources/GitHubOAuth.json, пройти E2E и тогда выпустить 0.9.

Device Flow выбран, потому что GitHub требует client secret для обычного code exchange, а здесь нет сервера и нельзя встраивать secret в публичный native client. Scope только read:user, никаких repo. Resources/GitHubOAuth.json общий, env NOTEPAD_GITHUB_CLIENT_ID для разработки. scripts/build.sh копирует ресурс; desktop/build.mjs создаёт ignored github-oauth.json, обязательно включён в builder.files вместе с github-auth.cjs/github-storage.cjs.

Native: NotepadCore/GitHubIdentity.swift (строгие валидаторы), NotepadMac/GitHubAccount.swift (@MainActor, URLSession no redirects, Keychain service bundleID.github) и GitHubSettingsView.swift; showPreferences @MainActor. Task generation защищает от позднего ответа после cancel/logout; Keychain write синхронна на actor. Expiring tokens учитываются, refresh token пока не используется: повторный вход после expiry. Profile check вручную; кеш профиля офлайн.

Desktop: github-auth.cjs (инъекции для тестов, serial credential writes и generation/AbortController), github-storage.cjs (safeStorage ciphertext, Linux known backend only). main/preload дают только status/start/cancel/disconnect/refresh/open fixed URLs/copy-code; токен/device_code не передаются renderer. src/github-account.js — локализованный UI. Logout очищает локальное хранилище, не отзывает grant: Settings/Applications на GitHub вручную.

Проверено: 39 Node-тестов, CoreChecks, production native и Electron Mac package; реальные settings UI до конфигурации и браузерный UI fixture для waiting/connected/cancel/logout/RU/EN. Реальная авторизация, защищённое хранилище ОС после согласия пользователя, Windows/Linux QA — впереди. QA bundles .authqa, каталоги /private/tmp/notepad-auth-qa. Fixture work/auth-web только тестовый, не часть приложения; фиктивный TEST-CODE, никаких реальных токенов. Тестовые mock ответы не выдавать за вход в аккаунт владельца.

## Новая задача: полный GitHub sync по шагам

Владелец разрешил реализовать вход → подтверждённое создание private repo → sync и просит коммит/точку продолжения после каждого шага. Актуальный чек-лист docs/SYNC_PROGRESS.md. Пока сделан шаг 1: JS portable codec + тесты; ещё не подключён к UI. Следующий шаг 2: GitHub App вместо старого OAuth App, регистрационная инструкция и оба auth клиента. Client ID/slug отсутствуют. Не выпускать 0.9 до E2E. Предыдущий OAuth-only план больше не является конечным объёмом задачи.

Checkpoint 2: JS/Swift auth переведён на GitHub App: device request без scope, token reply scope пустой, credentials.provider=github-app (старый OAuth кеш не подхватывать). GITHUB_SIGN_IN.md заменён на App-регистрацию. Client ID/slug ещё пусты. Далее шаг 3 в SYNC_PROGRESS: private repo confirmation + API + проверка установки. Проверки: 42 Node tests, CoreChecks и native build.

Client ID Iv23liPeQma6kkZ1Ndog подключён. Для владельца собрана VERSION=0.9.0-dev ./scripts/build.sh (Mac arm64) с настоящим Device Flow, выходной ZIP в outputs. Это локальный тест входа, не опубликованный stable и не готовая синхронизация. CoreChecks и 42 Node-теста проходят. Ждать результат ручного входа владельца; далее шаг 3 SYNC_PROGRESS.

0.9.0: владелец подтвердил настоящий GitHub вход. Добавлено private repo creation с подтверждением native alert / main-process Electron dialog; токены остаются вне renderer. Новый github-repository.cjs включён в builder. Mac toolbar right icons, detachesHiddenViews=false и высота42; Sidebar отделена. Sync ещё не включён. Реальное создание repo/Windows/Linux QA пока не подтверждены.

## 0.9.1 — текущее состояние

Manual sync обоих клиентов подключён. Основная документация docs/SYNC.md, архитектура/этапы docs/SYNC_PROGRESS.md. Shared Resources/SyncCore.js исполняется Electron main и JavaScriptCore native. Отдельная кнопка GitHub, explicit delete с tombstones, закрытие переносит в archivedTabs. Native Session поля archivedTabs/deletedNoteIDs optional для совместимости, Desktop archive + settings.deletedNoteIds. Реальная сетевая отправка .notepad/snapshot.json одним commit и non-force PATCH; base cache per accountID/repo. Миграции early per-file codec не надо: он не использовался для cloud.

54 Node tests, CoreChecks (включая реальный JavaScriptCore), native close/reopen UI с Unicode проверены. Реальный GitHub 2-device E2E агент не проходил/токен владельца не извлекал. Передача действительно подключена в коде, но не утверждать full manual platform QA. Следующие проверки: реальный upload/download/delete и отмена/401/смена repo. Ограничения: manual only, own private account repo, 300 notes/100 projects/1MiB per note/5MiB total, no E2EE; old Git history сохраняет удалённый текст.

0.9.2: пользователь попросил вернуть и увеличить лису, поправить layout. Native toolbar fox36 + edgeInsets3+3 =42pt; fixed horizontal hugging/compression. PNG AppIcon теперь копируется build.sh в bundle. Sidebar190pt, header Projects/+ вместо большой кнопки; addProjectEntry даёт24pt child indentation, SidebarNoteCell выделяет current. Tabs overlay scrolling. Desktop logo36 не скрывается вместе с brand label. QA bundles ui092qa/ui092narrow, отдельные session dirs.

UI 0.9.2 проверен в широкой сборке1120pt и отдельной узкой QA860pt (debug fixture; исходник восстановлен в1120pt). Все11команд+лиса видны; toolbar height42pt, fox36pt, отступы3pt. Публичный код не содержит QA-размеров.


## 0.9.3 — удаление и пустые проекты

Кнопки trash у проектов и каждой заметки (включая archive), подтверждения с backup session.before-delete.json. Удаление проекта каскадно создаёт note tombstones и новый optional deletedProjects в shared SyncCore.js (native Session.deletedProjectIDs / desktop settings.deletedProjectIds). Чистый snapshot не может содержать живой project с tombstone. Merge исключает проект; конфликтные заметки переносятся в null project. Обновлять оба устройства: старый 0.9.2 не знает project tombstones.

Последняя вкладка после close/delete не вызывает newDocument/newTab. Native showEmptyProject / Desktop emptyProject очищают редактор, статус, preview и selection. Переключение и восстановление пустого проекта не создают документов. Имена заполняют минимальную дыру среди открытых и закрытых заметок текущего проекта, без глобального счётчика.

Отдельная панель/диалог «Синхронизация», провайдер GitHub раскрывается вручную. GitHub удалён из общих настроек; там только переход. Sync больше не запускается автоматически при нажатии toolbar. Дополнительные create/access/logout скрыты в connection options, profile/refresh UI убраны.

QA: native ui093qa /private/tmp/notepad-ui093-qa: last-note delete → empty → Note1; close last → archived sidebar; archived-note delete; cascade project delete; Synchronization/GitHub disclosure. Desktop source Electron on Mac isolated /private/tmp/notepad-ui093-desktop: last-note delete/name reuse/project delete, restart, restored CSS, sync disclosure. No real account used. Found 0.9.2 CSS accidentally contained Swift Projects.swift; restored v0.9.1 CSS plus current overrides; build.mjs now parses CSS and fails warnings. Native final build/CoreChecks and 55 Node tests pass. Windows/Linux still CI-only.


0.9.4: владелец прислал общий sync failure на Mac после входа. Причина пока неизвестна: на скрине нет HTTP-кода. НЕ утверждать, что это подтверждённый 403. Native request(syncStage:) теперь выбрасывает GitHubSyncHTTPFailure из NotepadCore с HTTP-кодом/этапом без rawbody/credentials; UI различает ошибки, раскрывает connection options для403/404. CoreChecks SyncFailureTests. Уточнение владельцу о существовании notepad-notes отправлено асинхронно. Реальный токен не читать; следующий результат владельца даст код.

Мобильная работа начата по прямому запросу, отдельно mobile/0.10.0-beta.1; desktop VERSION не превращать в beta. Архитектура Capacitor8.6 + CodeMirror, shared SyncCore and preview; local-first. Native Java/Xcode отсутствуют локально, для APK/симулятора нужны Actions. См. docs/MOBILE.md и mobile/README.md после завершения подготовки.


Мобильный checkpoint: подготовлены src/model/journal/storage/app, responsive shell, UTF-8 import/share export и additive JSON backup. 6 Node tests pass; browser375×812/812×375/1024×768, RU/EN/dark/Markdown/reload/project checked. Native platforms reproducibly generated with pinned npm lock, prepare icon/version/privacy script. Separate workflow mobile.yml publishes Android debug APK + iOS-Simulator prerelease only after both compile. Current instructions docs/MOBILE.md. Physical devices NOT tested. NativeFolders ignored; do not mistake missing localJava/Xcode for unsupportedmobile platforms.

Mobile CI checkpoint: first Android run42103140887 stopped before compilation because sdkmanager was missing from PATH. mobile.yml now explicitly installs/configures SDK via android-actions/setup-android@v3 and uses setup-java@v5. iOS compilation still in progress. Stable0.9.4 first run passed builds but publish.sh deliberately skipped publication because main advanced; latest-source desktop run must publish. Do not claim0.9.4 public until /releases/tags/v0.9.4 verified.

Mobile CI: iOS Simulator compile SUCCESS in run42103140887 (also repeated in42103520688). Android setup-android v3 defaults to removed tools package; explicitly set packages: platform-tools (SDK36/build-tools installed in subsequent step). No native app compiler failure observed yet.

Owner clarified sync failure: notepad-notes was NOT created yet. Explained in-app Connection options → Create private repository → Synchronize. No need to read token or presume403. Mobile beta final guard: preview closes automatically on switching to a non-Markdown/HTML note; publisher refuses stale main builds. Android compiler succeeded (8,049,964-byte preliminary APK, SHA verified), current iOS repetition queued; previous iOS builds compiled successfully.
