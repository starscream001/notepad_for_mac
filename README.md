<p align="center">
  <img src="Resources/AppIcon.png" width="128" height="128" alt="Notepad Mac — лис-перо">
</p>

<h1 align="center">Notepad Mac</h1>
<p align="center"><strong>Текст, код и запросы. В привычных вкладках. На вашем Mac.</strong></p>
<p align="center">Нативный редактор с SQL и Kafka / ksqlDB, поиском с Regex и восстановлением несохранённого текста.</p>

<p align="center">
  <a href="https://github.com/starscream001/notepad_for_mac/releases/latest"><img src="https://img.shields.io/github/v/release/starscream001/notepad_for_mac?display_name=tag&amp;color=373475&amp;cacheSeconds=60" alt="Последняя версия"></a>
  <a href="https://github.com/starscream001/notepad_for_mac/actions/workflows/build.yml"><img src="https://github.com/starscream001/notepad_for_mac/actions/workflows/build.yml/badge.svg?branch=main" alt="Сборка и проверки"></a>
  <img src="https://img.shields.io/badge/macOS-13%2B-242938?logo=apple&amp;logoColor=white" alt="macOS 13 и новее">
  <img src="https://img.shields.io/badge/Apple_Silicon_%2B_Intel-universal-24515A" alt="Apple Silicon и Intel">
  <a href="LICENSE"><img src="https://img.shields.io/badge/license-MIT-373475" alt="Лицензия MIT"></a>
</p>

<p align="center">
  <a href="https://github.com/starscream001/notepad_for_mac/releases/latest/download/Notepad-Mac-universal.zip"><img src="https://img.shields.io/badge/Скачать_для_Mac-EC8D40?style=for-the-badge&amp;logo=apple&amp;logoColor=white" alt="Скачать приложение для Mac"></a>
</p>
<p align="center">
  <a href="#install">Установка</a> ·
  <a href="#features">Возможности</a> ·
  <a href="#formats">Форматы</a> ·
  <a href="CHANGELOG.md">Что нового</a> ·
  <a href="https://github.com/starscream001/notepad_for_mac/releases">Все релизы</a>
</p>

---

<a id="install"></a>
<a id="установить-на-mac"></a>

## Установка за минуту

**[Скачать Notepad-Mac-universal.zip](https://github.com/starscream001/notepad_for_mac/releases/latest/download/Notepad-Mac-universal.zip)**

1. **Скачайте ZIP** по кнопке выше. Вход в GitHub не нужен.
2. **Распакуйте** архив двойным нажатием в папке «Загрузки».
3. **Перетащите Notepad Mac.app в «Программы»** и запустите оттуда.

Один архив подходит для **Intel и Apple Silicon**. Нужна **macOS 13 Ventura или новее**. Версию macOS можно посмотреть в ** → Об этом Mac**. Компилировать код или устанавливать Xcode для запуска не требуется.

<details>
<summary><strong>macOS блокирует первый запуск?</strong></summary>

Приложение пока имеет локальную подпись и не заверено Apple. Поэтому при первом запуске возможно предупреждение о разработчике.

1. Попробуйте открыть Notepad Mac и закройте предупреждение.
2. Откройте ** → Системные настройки → Конфиденциальность и безопасность**.
3. Прокрутите до раздела «Безопасность», найдите сообщение о Notepad Mac и нажмите **«Всё равно открыть»**. Название кнопки зависит от версии macOS.
4. Подтвердите открытие. При следующих запусках этот шаг обычно не требуется.

</details>

<details>
<summary><strong>Какой файл выбирать на странице Releases?</strong></summary>

В [последнем релизе](https://github.com/starscream001/notepad_for_mac/releases/latest) раскройте **Assets**:

| Файл | Для чего |
|---|---|
| **Notepad-Mac-universal.zip** | Готовое приложение — скачивайте его |
| Notepad-Mac-universal.zip.sha256 | Дополнительная проверка целостности архива |
| Source code (zip / tar.gz) | Исходники для разработчиков |

Finder может показывать имя приложения без расширения `.app` — это нормально.

</details>

<details>
<summary><strong>Как обновить приложение?</strong></summary>

Сохраните важные файлы через **⌘S** и завершите приложение через **⌘Q**. Скачайте новый ZIP по той же кнопке, распакуйте и перенесите приложение в «Программы». В диалоге Finder выберите **«Заменить»**.

Вкладки и несохранённый текст хранятся отдельно от приложения и восстанавливаются после обновления. Сессия 0.1 совместима с 0.2.

</details>

<a id="features"></a>

## В редакторе

| Для повседневной работы | Для кода и запросов |
|---|---|
| **Вкладки сверху** — имена файлов, отметка изменений, «+» и закрытие | **SQL / ksqlDB** — ключевые слова, функции, строки, параметры и комментарии |
| **Поиск и замена** — учёт регистра, регулярные выражения, замена всех совпадений | **Выбор языка** — автоматически по расширению или вручную для каждой вкладки |
| **Восстановление сессии** — вкладки, текст, курсор и выбранный язык | **Номера строк** — переход к строке, автоотступы, Tab на четыре позиции |
| **Три темы** — системная, светлая и тёмная; размер шрифта и перенос строк | **Кодировки** — UTF-8 / UTF-16; LF, CRLF и CR |

Запись файлов атомарная. Если файл изменился в другой программе, редактор предупредит перед перезаписью. Текст документов остаётся на вашем Mac.

### Новое в 0.2

**SQL + Kafka / ksqlDB**, выбор языка для каждой вкладки и новая иконка **«лис-перо»**.

[Описание релиза 0.2.0](https://github.com/starscream001/notepad_for_mac/releases/tag/v0.2.0) · [Вся история изменений](CHANGELOG.md)

<a id="formats"></a>

## Файлы и подсветка

Редактор работает с **обычными текстовыми файлами**: `.txt`, `.log`, `.csv`, `.ini` и любыми другими расширениями. Для следующих языков предусмотрена подсветка:

| Язык / формат | Расширения |
|---|---|
| **SQL** | `.sql`, `.psql`, `.pgsql`, `.mysql`, `.ddl`, `.dml` |
| **Kafka / ksqlDB** | `.ksql`, `.ksqldb` |
| Swift | `.swift` |
| JavaScript / TypeScript | `.js`, `.jsx`, `.mjs`, `.cjs`, `.ts`, `.tsx` |
| Python | `.py`, `.pyw` |
| JSON / YAML | `.json`, `.yaml`, `.yml` |
| HTML / XML / SVG | `.html`, `.htm`, `.xml`, `.svg` |
| CSS / SCSS | `.css`, `.scss` |
| C / C++ / Objective-C | `.c`, `.h`, `.cpp`, `.hpp`, `.cc`, `.m`, `.mm` |
| Markdown | `.md`, `.markdown` |
| Shell | `.sh`, `.bash`, `.zsh` |

Чтобы включить подсветку в новой вкладке или `.txt`, выберите **«Язык → SQL»** или **«Язык → Kafka / ksqlDB»** внизу окна. **«Авто»** определяет язык по расширению. Выбор сохраняется при перезапуске.

Поддержка SQL и Kafka относится к **редактированию текста запросов**. Примеры: [SQL](examples/query.sql) и [ksqlDB](examples/stream.ksql).

**Кодировки:** UTF-8, UTF-8 BOM, UTF-16 LE/BE с BOM. Word, PDF, Excel и другие бинарные форматы не поддерживаются. Windows-1251 пока не поддерживается.

## Горячие клавиши

| Действие | Клавиши |
|---|---|
| Новая вкладка / открыть | ⌘N / ⌘O |
| Сохранить / сохранить как | ⌘S / ⇧⌘S |
| Закрыть вкладку | ⌘W |
| Найти / заменить | ⌘F |
| Следующее / предыдущее совпадение | ⌘G / ⇧⌘G |
| Перейти к строке | ⌘L |
| Следующая / предыдущая вкладка | ⇧⌘] / ⇧⌘[ |
| Перенос строк | ⌥⌘W |
| Размер шрифта | ⌘= / ⌘− |

<details>
<summary><strong>Восстановление вкладок и ограничения</strong></summary>

При выходе через **⌘Q** сессия сохраняется локально. При закрытии отдельной изменённой вкладки редактор предложит сохранить файл, отменить закрытие или удалить изменения этой вкладки.

Сессия находится в `~/Library/Application Support/NotepadMac/session.json`. В ней хранится полный текст открытых документов. Файл доступен текущему пользователю (`0600`). Это восстановление сессии, а не резервная копия важных документов.

При открытии действует предел **20 МБ**. Для текстов от 500 000 UTF-16 единиц подсветка отключается для отзывчивости. Смешанные окончания строк при сохранении нормализуются в выбранный формат.

Подсветка — облегчённый лексический разбор, а не полноценная проверка синтаксиса. Пока нет Windows DLL-плагинов, макросов, сворачивания кода, разделения редактора и поиска по папке.

</details>

<details>
<summary><strong>Для разработчиков: сборка, проверки и релизы</strong></summary>

### Локальная сборка

Нужны macOS 13+, Swift 5.9+ и Apple Command Line Tools либо Xcode. Внешних пакетов нет.

```sh
git clone https://github.com/starscream001/notepad_for_mac.git
cd notepad_for_mac
swift run CoreChecks
./scripts/build.sh
open "dist/Notepad Mac.app"
```

Если инструменты не установлены: `xcode-select --install`.

Universal-сборка для Intel и Apple Silicon:

```sh
UNIVERSAL=1 ./scripts/build.sh
```

Результат — `.app`, ZIP и SHA-256 в `dist/`. Скрипт создаёт все размеры иконки, подписывает приложение ad-hoc и проверяет подпись. Для разработки: `swift run NotepadMac` или открытие `Package.swift` в Xcode.

### Проверки

`swift run CoreChecks` выполняет 12 проверок: сочетания кодировок и окончаний строк, кириллица и emoji, поиск и замена, сессия и совместимость старых сессий, позиции Unicode, SQL / ksqlDB и сохранение выбранного языка.

Запуск приложения проверен на Apple Silicon. Intel собирается перекрёстно; запуск на реальном Intel Mac нужно проверить отдельно.

### Как устроены версии

- Номер версии хранится в **[VERSION](VERSION)**.
- Описание каждой версии — в **[docs/releases](docs/releases)**, краткая история — в **[CHANGELOG.md](CHANGELOG.md)**.
- GitHub Actions проверяет код и собирает приложение при push в `main`, pull request, по тегу `v…` и вручную.
- Новая версия из `main` публикуется в **GitHub Releases** после успешной сборки: тег, описание, готовый ZIP и контрольная сумма.
- Сначала создаётся черновик с файлами, затем он публикуется. Опубликованные номерные версии не перезаписываются.
- Кнопка скачивания использует стандартный маршрут GitHub **`releases/latest/download/…`** и ведёт на последнюю стабильную версию.
- Промежуточные сборки доступны в **Actions → Artifacts → Notepad-Mac-universal**, хранятся 30 дней и требуют входа в GitHub.

Для следующего релиза обновите `VERSION`, добавьте `docs/releases/v<версия>.md` и запись в `CHANGELOG.md`, затем отправьте изменения в `main`.

### Структура проекта

| Путь | Содержимое |
|---|---|
| `Sources/NotepadCore` | Кодировки, поиск, сессия, позиции текста, SQL / ksqlDB |
| `Sources/NotepadMac` | AppKit, TextKit, окно, вкладки, меню и подсветка |
| `Tests/NotepadCoreTests` | Проверки ядра без зависимости на XCTest |
| `Resources` | Метаданные приложения и выбранная иконка |
| `scripts` | Сборка, упаковка и публикация релизов |
| `examples` | Примеры SQL и ksqlDB |

Для изолированной тестовой сессии задайте `NOTEPAD_SESSION_DIR=/путь/к/папке`.

</details>

---

Независимый проект, вдохновлённый Notepad++. Интерфейс написан на Swift / AppKit / TextKit; исходники и логотип Notepad++ не используются. Лицензия **[MIT](LICENSE)**. Прежний сайт сохранён в ветке [`archive/previous-site`](https://github.com/starscream001/notepad_for_mac/tree/archive/previous-site).
