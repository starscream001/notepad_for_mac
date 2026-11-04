<p align="center">
  <img src="Resources/AppIcon.png" width="76" height="76" alt="Иконка Notepad Mac — лис-перо">
</p>
<h1 align="center">Notepad</h1>
<p align="center"><strong>Текстовый редактор для macOS, Windows и Linux</strong></p>
<p align="center">
  <a href="#install">Установка</a> · <a href="#features">Возможности</a> · <a href="#updates">Обновления</a> · <a href="#formats">Форматы</a> · <a href="docs/ROADMAP.md">Дорожная карта</a> · <a href="#support">Поддержать</a>
</p>

<img src="docs/assets/hero.svg" width="100%" alt="Текст. Код. Запросы. Редактор для macOS, Windows и Linux: SQL, ksqlDB, восстановление вкладок и предпросмотр Markdown/HTML.">

<p align="center">
  <a href="https://github.com/starscream001/notepad_for_mac/releases/latest"><img src="https://img.shields.io/github/v/release/starscream001/notepad_for_mac?display_name=tag&amp;color=373475&amp;cacheSeconds=60" alt="Последняя стабильная версия"></a>
  <a href="https://github.com/starscream001/notepad_for_mac/actions/workflows/build.yml"><img src="https://github.com/starscream001/notepad_for_mac/actions/workflows/build.yml/badge.svg?branch=main" alt="Сборка и проверки"></a>
  <img src="https://img.shields.io/badge/macOS-13%2B-242938?logo=apple&amp;logoColor=white" alt="macOS 13 и новее">
  <a href="docs/STATS.md"><img src="https://img.shields.io/github/downloads/starscream001/notepad_for_mac/latest/Notepad-Mac-universal.zip?label=ZIP%20downloads&amp;color=24515A&amp;displayAssetName=false" alt="Скачивания ZIP последней стабильной версии"></a>
  <a href="LICENSE"><img src="https://img.shields.io/badge/license-MIT-373475" alt="MIT"></a>
</p>
<p align="center">
  <a href="https://github.com/starscream001/notepad_for_mac/releases/latest/download/Notepad-Mac-universal.zip"><img src="https://img.shields.io/badge/Скачать_для_Mac-EC8D40?style=for-the-badge&amp;logo=apple&amp;logoColor=white" alt="Скачать Notepad Mac"></a>
  <a href="https://github.com/starscream001/notepad_for_mac/releases"><img src="https://img.shields.io/badge/Все_версии-252A48?style=for-the-badge&amp;logo=github&amp;logoColor=white" alt="Все версии на GitHub"></a>
</p>
<p align="center"><strong>macOS · Windows · Linux</strong> · Без входа в GitHub · Бесплатно</p>

<img src="docs/assets/studio-070.jpg" width="100%" alt="Notepad 0.7.1: SQL, компактные кнопки Studio и нижний выбор палитры Ночной и золото.">

**Оформление в нижней панели.** Выберите светлую, тёмную или системную тему, затем палитру рядом: 14 светлых или 14 тёмных пар + Studio. Повторяющиеся пары объединены. Цвета меняют поверхности и акценты интерфейса; читаемый текст и подсветка кода сохраняются отдельно. [Все пары с HEX](docs/PALETTES.md).

**Форматирование без фоновой нагрузки.** Кнопка «Формат» или **⌘/Ctrl+Shift+F** обрабатывает выделение, а без выделения — документ целиком. JSON сохраняет большие числа и повторяющиеся ключи; SQL поддерживает обычный SQL, PostgreSQL и MySQL (диалект в настройках). Одно Undo отменяет результат. Ошибочный ввод остаётся без изменений. Это форматирование, а не проверка корректности запросов сервером; ksqlDB пока только подсвечивается. Предел команды: JSON — 1 млн, SQL — 50 тыс. единиц UTF-16. На диск результат записывается только по «Сохранить».

<a id="features"></a>

## Рабочая вкладка — без лишнего

**Русский / English.** Язык интерфейса выбирается в настройках (кнопка ⚙). Названия файлов и текст документов не переводятся.

**Много вкладок.** Строка прокручивается горизонтально, выбранная вкладка появляется в видимой области. Кнопка **«Вкладки / Tabs»** открывает список с поиском по имени или пути; **⌘/Ctrl+Shift+A** — быстрый вызов. Проверен сценарий **120 документов** в обоих клиентах. Desktop поддерживает до 300 вкладок; объём доступной памяти зависит от файлов.


В **0.7.1** также доработаны **«Вкладки» и «Найти»**: компактные поля, согласованные кнопки, выделение текущего документа, счётчик результатов и понятный пустой список. Базовый выпуск 0.7 добавил оформление **Studio**, одинаковая высота кнопок сверху и снизу, **28 цветовых схем** из подборки Алисы и форматирование **JSON / SQL** по команде. Mac остаётся нативным; Windows/Linux используют Electron и CodeMirror.

[Изменения 0.7.1](https://github.com/starscream001/notepad_for_mac/releases/tag/v0.7.1) · [История версий](CHANGELOG.md) · [План развития](docs/ROADMAP.md)


<table>
<tr>
<td width="50%" valign="top">
<h3>Текст и код</h3>
<p>Вкладки сверху, номера строк, автоотступы, перенос строк и привычные сочетания клавиш вашей ОС. Открывайте несколько файлов и переключайтесь между ними.</p>
</td>
<td width="50%" valign="top">
<h3>SQL и Kafka / ksqlDB</h3>
<p>Ключевые слова, строки, функции, параметры и комментарии. Язык определяется по расширению; для новой вкладки или <code>.txt</code> его можно выбрать вручную.</p>
</td>
</tr>
<tr>
<td width="50%" valign="top">
<h3>Продолжить с того же места</h3>
<p>После перезапуска восстанавливаются вкладки, несохранённый текст, позиция курсора и выбранная подсветка. Светлая, тёмная и системная темы.</p>
</td>
<td width="50%" valign="top">
<h3>Найти и изменить</h3>
<p>Поиск и замена с регулярными выражениями, учёт регистра и отмена правок. UTF-8 / UTF-16, окончания строк LF / CRLF / CR.</p>
</td>
</tr>
</table>

Запись файлов атомарная. Перед перезаписью документа, изменённого другой программой, редактор предупредит. Текст документов остаётся на вашем компьютере.

<a id="install"></a>
<a id="установить-на-mac"></a>

## Выберите свою платформу

| Платформа | Готовое приложение | Установка |
| --- | --- | --- |
| **macOS 13+** · Intel / Apple Silicon | [Скачать ZIP](https://github.com/starscream001/notepad_for_mac/releases/latest/download/Notepad-Mac-universal.zip) | Распаковать → перенести в «Программы» |
| **Windows x64** | [Скачать Setup EXE](https://github.com/starscream001/notepad_for_mac/releases/download/v0.7.1/Notepad-Desktop-0.7.1-Windows-x64-Setup.exe) | Запустить → установить для себя |
| **Linux x64** | [AppImage](https://github.com/starscream001/notepad_for_mac/releases/download/v0.7.1/Notepad-Desktop-0.7.1-Linux-x64.AppImage) · [deb](https://github.com/starscream001/notepad_for_mac/releases/download/v0.7.1/Notepad-Desktop-0.7.1-Linux-x64.deb) | Разрешить выполнение AppImage или установить deb |

Готовые пакеты не требуют Node.js, Xcode или компиляции. Windows/Linux — первая версия поддержки; автоматическая упаковка проверяется в CI, ручная проверка на машинах владельца ещё впереди. [Инструкции Windows/Linux](docs/PLATFORM_TESTING.md).

### Установка на Mac

<img src="docs/assets/install.svg" width="100%" alt="1. Скачать ZIP без входа в GitHub. 2. Распаковать двойным нажатием в Finder. 3. Перетащить приложение в Программы и запустить.">

1. **[Скачайте Notepad-Mac-universal.zip](https://github.com/starscream001/notepad_for_mac/releases/latest/download/Notepad-Mac-universal.zip)**.
2. Дважды нажмите на архив в **«Загрузках»**.
3. Перетащите **Notepad Mac.app** в **«Программы»** и запустите.

Нужна **macOS 13 Ventura или новее**. Один файл подходит для **Intel и Apple Silicon**. Xcode и самостоятельная компиляция для запуска не требуются.

<details>
<summary><strong>macOS блокирует первый запуск?</strong></summary>

Приложение пока имеет локальную подпись и не заверено Apple. После первой попытки запуска откройте ** → Системные настройки → Конфиденциальность и безопасность**. Найдите сообщение о Notepad Mac и нажмите **«Всё равно открыть»**, затем подтвердите запуск. Название кнопки зависит от версии macOS.

</details>

<details>
<summary><strong>Какой файл скачивать из Releases?</strong></summary>

В [последнем релизе](https://github.com/starscream001/notepad_for_mac/releases/latest), в разделе **Assets**, выберите **Notepad-Mac-universal.zip** — это готовое приложение. Файл `.sha256` нужен для дополнительной проверки архива. **Source code (zip / tar.gz)** содержит исходники для разработчиков.

Finder может показывать имя приложения без расширения `.app`.

</details>

<a id="updates"></a>

## Обновляйтесь без поисков

<table>
<tr>
<td width="52%" valign="top">
<h3>Проверять удобно. Устанавливать спокойно.</h3>
<p>Меню <strong>Notepad Mac → Проверить обновления…</strong> ищет стабильный выпуск на GitHub. Автопроверка работает при запуске, возвращении в редактор и по расписанию при наличии сети.</p>
<p><strong>6 часов · сутки · неделя</strong><br>По умолчанию — раз в сутки. Автопроверку можно отключить; ручная проверка остаётся доступной.</p>
<p>Загрузка показывает прогресс и допускает отмену. Перед заменой проверяются архив и пакет, сохраняется сессия. Предыдущая версия остаётся до подтверждения запуска новой.</p>
<p><a href="docs/UPDATES.md">Подробнее о процессе обновления →</a></p>
</td>
<td width="48%" valign="top">
<img src="docs/assets/updates.jpg" width="100%" alt="Настройки обновлений: автоматическая проверка, периодичность, последняя проверка и кнопка Проверить сейчас.">
</td>
</tr>
</table>

**Первый переход с 0.1 / 0.2 на 0.3 — вручную:** скачайте ZIP и замените приложение через Finder после выхода через **⌘Q**. Начиная с 0.3, последующие версии можно устанавливать из редактора. Сессии прежних версий совместимы.

[Что нового в 0.7.1](https://github.com/starscream001/notepad_for_mac/releases/tag/v0.7.1) · [История изменений](CHANGELOG.md) · [Все релизы](https://github.com/starscream001/notepad_for_mac/releases)

<a id="formats"></a>

**Windows/Linux:** меню «Помощь → Проверить обновления» или кнопка в «О проекте». Проверка также работает при запуске и по расписанию (6 ч / сутки / неделя). Новый установщик скачивается со страницы Release и запускается вручную. Установка внутри приложения сейчас реализована в нативном Mac-клиенте.

## Предпросмотр Markdown и HTML

<img src="docs/assets/preview.gif" width="100%" alt="Реальная демонстрация: Markdown, обновление текста и HTML со встроенным CSS.">


Нажмите **«Просмотр»** или **⌥⌘P**: слева — исходный текст, справа — результат. Панели можно растягивать разделителем. Просмотр обновляется при вводе и работает без интернета. Поддерживаются Markdown (включая таблицы и блоки кода) и HTML со встроенным CSS. Для новой вкладки выберите нужный язык внизу окна.

Скрипты, формы, внешние ресурсы и локальные файлы из HTML не загружаются. Ссылки открываются в браузере. Предел предпросмотра — 2 МБ.

## Файлы, с которыми вы работаете

Ниже — полный набор подсветки **нативного Mac-клиента**. В **Windows/Linux 0.6** доступны текст, SQL/ksqlDB, Markdown, HTML, JavaScript/TypeScript, Python, JSON и CSS. Сближение возможностей запланировано в [дорожной карте](docs/ROADMAP.md).

Открывайте обычные текстовые файлы с любыми расширениями: `.txt`, `.log`, `.csv`, `.ini` и другие. Подсветка предусмотрена для:

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
| Markdown / Shell | `.md`, `.markdown`, `.sh`, `.bash`, `.zsh` |

**«Язык» внизу окна** позволяет включить нужную подсветку для любого файла. **«Авто»** определяет её по расширению. Примеры: [SQL](examples/query.sql) и [ksqlDB](examples/stream.ksql).

Поддержка запросов относится к редактированию и подсветке текста. Кодировки: **UTF-8, UTF-8 BOM, UTF-16 LE/BE с BOM**. Word, PDF, Excel и другие бинарные форматы, а также Windows-1251 пока не поддерживаются.

<details>
<summary><strong>Горячие клавиши</strong></summary>

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

</details>

<details>
<summary><strong>Восстановление сессии и ограничения</strong></summary>

При выходе через **⌘Q** сессия сохраняется локально. При закрытии отдельной изменённой вкладки можно сохранить файл, отменить закрытие или удалить изменения этой вкладки.

Файл сессии: `~/Library/Application Support/NotepadMac/session.json`. Он содержит полный текст открытых документов и доступен текущему пользователю (`0600`). Важные документы сохраняйте в обычные файлы: восстановление сессии не заменяет резервные копии.

Предел при открытии — **20 МБ**. Подсветка отключается для текстов от 500 000 UTF-16 единиц. Смешанные окончания строк нормализуются при сохранении. Подсветка — облегчённый лексический разбор; пока нет Windows DLL-плагинов, макросов, сворачивания кода, разделения редактора и поиска по папке.

</details>

<a id="support"></a>

## Сделано Ильёй. Развивается с вашей поддержкой.

Разработчик — **Илья ([starscream001](https://github.com/starscream001))**. Notepad Mac — бесплатный проект с открытым исходным кодом. Поддержка добровольная; все функции доступны каждому.

<table>
<tr>
<td width="50%" valign="top">
<h3>Поддержать через СБП</h3>
<p><strong>+7 (963) 243-31-00</strong><br>Ozon Банк</p>
<p>Сумму вы выбираете самостоятельно. В приложении откройте <strong>«Поддержать разработчика…»</strong>, чтобы скопировать номер.</p>
<p><a href="docs/SUPPORT.md">Все способы поддержки →</a></p>
</td>
<td width="50%" valign="top">
<h3>Помочь проекту</h3>
<p>Поставьте звезду репозиторию, расскажите о редакторе, сообщите об ошибке или предложите улучшение.</p>
<p><a href="https://github.com/starscream001/notepad_for_mac/issues">Обсудить идею или ошибку →</a></p>
</td>
</tr>
</table>

**MIT.** Можно использовать, изменять и распространять программу, в том числе коммерчески, сохраняя уведомление об авторстве и текст лицензии. Программа предоставляется «как есть», без гарантий.

[Полная лицензия](LICENSE) · [Пояснение на русском](docs/LICENSING.md) · [Как считаются скачивания](docs/STATS.md)

<details>
<summary><strong>Разработчикам: сборка, проверки и выпуск версии</strong></summary>

Нужны macOS 13+, Swift 5.9+ и Apple Command Line Tools либо Xcode. Внешних пакетов нет.

```sh
git clone https://github.com/starscream001/notepad_for_mac.git
cd notepad_for_mac
swift run CoreChecks
UNIVERSAL=1 ./scripts/build.sh
open "dist/Notepad Mac.app"
```

Для сборки только под текущий Mac выполните `./scripts/build.sh`. Для разработки — `swift run NotepadMac`. Проверка настоящей загрузки с GitHub: `swift run CoreChecks --network`.

В `dist/` создаются приложение, ZIP и SHA-256. Установщик `NotepadUpdater` компилируется отдельно и входит в `.app`. Скрипт подписывает приложение ad-hoc и проверяет подпись.

**22 проверки ядра** покрывают текст, кодировки, поиск, сессии, SQL / ksqlDB, версии и расписание обновлений, SHA-256, пути ZIP и откат замены приложения. Полный сценарий замены 0.2 → 0.3 с перезапуском и восстановлением несохранённого текста проверен на Apple Silicon. Intel собирается перекрёстно; запуск на реальном Intel Mac нужно проверить отдельно.

### Версии на GitHub

Рабочая ветка — **`main`**. Готовые версии закрепляются тегами **`v0.1.0`**, **`v0.2.0`**, **`v0.3.0`** и публикуются в **Releases**. Отдельные ветки для версий не требуются.

Номер хранится в [VERSION](VERSION), описание — в [docs/releases](docs/releases), краткая история — в [CHANGELOG.md](CHANGELOG.md). Для следующего релиза обновите номер, добавьте `docs/releases/v<версия>.md`, запись в историю и отправьте изменения в `main`.

GitHub Actions запускает проверки и universal-сборку. Новый релиз публикуется из черновика после добавления ZIP и контрольной суммы. Опубликованные номерные версии не перезаписываются. Кнопка скачивания использует стандартный `releases/latest/download/…`.

Промежуточные сборки: **Actions → Artifacts → Notepad-Mac-universal**. Они хранятся 30 дней и требуют входа в GitHub.

| Путь | Содержимое |
|---|---|
| `Sources/NotepadCore` | Текст, поиск, сессия, SQL / ksqlDB и ядро обновлений |
| `Sources/NotepadMac` | Нативный интерфейс AppKit / TextKit |
| `Sources/NotepadUpdater` | Установка, резервная копия и откат |
| `Tests/NotepadCoreTests` | Проверки ядра |
| `Resources` | Иконка, метаданные и реквизиты поддержки |
| `docs` | Документация, история версий и иллюстрации |

Для отдельной тестовой сессии: `NOTEPAD_SESSION_DIR=/путь/к/папке`.

</details>

---

<p align="center">Notepad · macOS / Windows / Linux · <a href="LICENSE">MIT</a></p>
<p align="center">Независимый проект, вдохновлённый Notepad++. Интерфейс и иконка — собственные.</p>

## Продолжить разработку на другом компьютере

Начните с [AGENTS.md](AGENTS.md), затем [HANDOFF](docs/HANDOFF.md) и [платформенного чек-листа](docs/PLATFORM_TESTING.md). Там зафиксированы архитектура, команды, различия клиентов и следующие шаги.

**Дальше:** минимальные проекты с папкой и скрываемым деревом. Мобильные/планшетные клиенты, линтеры и AI остаются в дорожной карте; объём и номера следующих выпусков уточняются отдельно. [Подробности и ограничения](docs/ROADMAP.md).

**Контакты:** [GitHub · starscream001](https://github.com/starscream001) · [Telegram · @Ilya_Manik](https://t.me/Ilya_Manik).

## Хранение выпусков

Установщики и SHA256 доступны для **двух последних стабильных версий**. После успешного выпуска Actions удаляет эти файлы у более старых номерных релизов; теги, исходники и описания изменений остаются. Временные артефакты новых запусков Actions хранятся 7 дней. Сами установщики не коммитятся в Git.
