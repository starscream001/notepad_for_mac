# Менеджеры пакетов и установка командой

В 0.8 приложение **ещё не зарегистрировано** в центральных каталогах WinGet/Homebrew/Flathub или APT. Не писать `winget install Notepad` как рабочую команду нашего приложения: одноимённые пакеты могут принадлежать другим разработчикам.

## Что требуется для каталогов

| Канал | Подготовка | Установка и обновление после публикации |
| --- | --- | --- |
| WinGet | YAML manifest: уникальный ID издателя/приложения, версия, x64 NSIS, HTTPS URL EXE, SHA256, scope и silent switches; тест на Windows; PR в microsoft/winget-pkgs и проверка Microsoft | `winget install --id <наш-ID> --exact`, затем `winget upgrade --id <наш-ID> --exact` |
| Homebrew Cask | Cask: версия, URL ZIP, SHA256, `app "Notepad Mac.app"`, требование macOS 13+; собственный tap либо проверка Homebrew | `brew install --cask <наш-cask>`, затем `brew upgrade --cask <наш-cask>` |
| Debian/Ubuntu APT | Хостинг `.deb`, Packages/Release, GPG-подпись репозитория, инструкция подключения ключа с signed-by | `apt install` / `apt upgrade` после подключения источника |
| Flathub | Отдельный Flatpak manifest, sandbox-разрешения, проверяемая сборка и review | `flatpak install` / `flatpak update` |

Это план каналов распространения, а не текущие опубликованные IDs. Для WinGet полезен `wingetcreate new <URL-EXE>`; SHA256 и параметры должны соответствовать готовому установщику. Для первых пакетов сертификаты/правила каталогов проверяются отдельно; контрольная сумма не заменяет доверенную подпись.

**Важно про хранение:** сейчас установщики удаляются у релизов старше двух стабильных версий. Перед включением каталога с закреплёнными версиями эту политику нужно согласовать: иначе старый manifest останется со ссылкой на уже удалённый файл. Нельзя обещать стабильный пакетный канал, пока этот вопрос не решён.

Официальные инструкции: [WinGet manifest](https://learn.microsoft.com/en-us/windows/package-manager/package/manifest), [проверка и публикация](https://learn.microsoft.com/en-us/windows/package-manager/package/repository), [Homebrew Cask](https://docs.brew.sh/Cask-Cookbook).

## Скачать из GitHub командой уже сейчас

`git clone` скачивает исходники. Для готовой программы компилятор не нужен: берите файлы Release. Если установлен и настроен [GitHub CLI](https://cli.github.com/manual/gh_release_download):

```sh
# macOS: готовое universal-приложение и контрольная сумма
mkdir notepad-download
cd notepad-download
gh release download --repo starscream001/notepad_for_mac --pattern 'Notepad-Mac-universal.zip' --pattern 'Notepad-Mac-universal.zip.sha256'
shasum -a 256 -c Notepad-Mac-universal.zip.sha256
ditto -xk Notepad-Mac-universal.zip .
# Завершите старую версию; перенесите Notepad Mac.app в «Программы».
```

```powershell
# Windows: готовый установщик последнего стабильного выпуска
gh release download --repo starscream001/notepad_for_mac --pattern '*-Windows-x64-Setup.exe' --pattern '*-Windows-x64-Setup.exe.sha256' --dir notepad-download
# Проверка суммы, запуск обычного мастера установки
$setup = Get-ChildItem .\notepad-download\*-Windows-x64-Setup.exe | Select-Object -First 1
$expected = (Get-Content ($setup.FullName + '.sha256')).Split(' ')[0]
if ((Get-FileHash $setup.FullName -Algorithm SHA256).Hash -ne $expected) { throw 'SHA256 mismatch' }
Start-Process -FilePath $setup.FullName -Wait
```

```sh
# Linux x64: AppImage + SHA256
mkdir notepad-download
cd notepad-download
gh release download --repo starscream001/notepad_for_mac --pattern '*-Linux-x64.AppImage' --pattern '*-Linux-x64.AppImage.sha256'
sha256sum -c ./*.AppImage.sha256
chmod +x ./*.AppImage
./*.AppImage
```

Команды скачивают файлы из нашего Release, не регистрируют приложение в каталогах пакетов. Суммы получены из того же GitHub-источника; системные проверки подписи сохраняются. Linux `.deb` можно аналогично скачать по `--pattern '*.deb'` и установить своим менеджером пакетов.
