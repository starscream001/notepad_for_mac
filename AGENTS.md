# Notepad — инструкции продолжения работы

Автор и владелец: Илья, https://github.com/starscream001.
Репозиторий: https://github.com/starscream001/notepad_for_mac.

## Сначала прочитать

1. `docs/HANDOFF.md` — архитектура, состояние и следующий шаг.
2. `docs/PLATFORM_TESTING.md` — проверка на текущей ОС и форма отчёта.
3. `docs/ROADMAP.md` и `CHANGELOG.md`.
4. `VERSION`, `desktop/package.json`, `.github/workflows/build.yml`.

Не начинать перенос заново. В проекте уже два клиента:
- macOS: Swift / AppKit / WebKit, `Sources/`, `Resources/`, `Package.swift`.
- Windows/Linux: Electron / CodeMirror, `desktop/`. Нативный Mac-клиент не заменять Electron без обсуждения.

## Команды

macOS: `swift run CoreChecks`, `UNIVERSAL=1 ./scripts/build.sh`.
Windows/Linux: `cd desktop`, `npm ci`, `npm test`, `npm start`.
Пакеты: `npm run dist -- --win --x64` или `npm run dist -- --linux --x64` на соответствующей ОС.
Изолированная сессия: macOS `NOTEPAD_SESSION_DIR`, Desktop `NOTEPAD_DESKTOP_DATA` — каталог теста.
Не затирать пользовательские сессии. Копировать их перед диагностикой.

## Выпуски

Рабочая ветка — `main`. История версий — теги `vX.Y.Z` и GitHub Releases, не ветки.
Не менять файлы опубликованной версии: исправления — следующим patch-релизом.
При каждом выпуске синхронно обновить `VERSION`, `Resources/Info.plist`, `desktop/package.json` + lock, `CHANGELOG.md`, README (версия, возможности, ограничения, ссылки), `docs/releases/vX.Y.Z.md`, состояние `docs/HANDOFF.md`.
CI собирает native universal macOS + Windows NSIS x64 + Linux AppImage/deb x64; публикация только после всех сборок.
Проверить публичный Release: описание, tag, ZIP/EXE/AppImage/deb и SHA256. Не называть сборку CI ручной проверкой ОС.

## Качество и дизайн

В README единый индиго/оранжевый стиль с лисом-пером, реальные скриншоты/GIF. Отдельный сайт не нужен, GitHub Pages отключён.
Для UI использовать установленный ui-ux-pro-max, если доступен. Taste применим к оформлению README в пределах GitHub (там нет JS/CSS/GSAP).
Проверять светлую/тёмную темы, минимум окна, длинные пути, много вкладок, крестики, клавиатуру и масштаб 100/150/200%.

## Границы

SQL/ksqlDB — редактирование и подсветка, без выполнения запросов и подключения к кластерам.
Предпросмотр не выполняет пользовательские скрипты и не загружает внешние/локальные ресурсы.
Не выключать sandbox/contextIsolation/nodeIntegration protections в Electron.
Не добавлять телеметрию и облако без запроса.
Донаты добровольные: +7 (963) 243-31-00, Ozon Банк. Нормализованный номер +79632433100.
Лицензия MIT, автор Ilya (starscream001).
Сертификатов подписи Windows/Apple Developer ID пока нет. Не представлять ad-hoc подпись как нотариализацию.
