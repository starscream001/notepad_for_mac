# Мобильная версия: состояние и продолжение

## Текущий этап

`mobile/`, версия `0.10.0-beta.2`, отдельный prerelease `mobile-v0.10.0-beta.2`. Android APK — debug beta. iOS artifact — приложение для симулятора, не установщик на телефон. Инструкции владельцу и пользователю в [mobile/README](../mobile/README.md).

Оболочка без UI-фреймворка: Capacitor 8.6, CodeMirror 6, локальные assets. `src/model.mjs` использует переносимый `Resources/SyncCore.js`, `src/journal.mjs` сериализует записи в два чередующихся слота, `src/storage.js` — Capacitor Filesystem/Directory.Data. Browser preview использует отдельный localStorage. Повреждённый единственный слот не затирается; один повреждённый слот восстанавливается из другого. Ошибки записи видны в UI. Перед удалением сохраняется before-delete.json.

`src/app.js` — phone/tablet shell, автосохранение с задержкой 300 мс и сохранение по background/pagehide, импорт/экспорт, явное удаление. ОС не гарантирует выполнение асинхронной записи при мгновенном убийстве процесса: проверять реальным стресс-тестом, не обещать отсутствие потерь последних ещё не сохранённых символов. Подтверждённые записи защищены журналом.

`npm ci && npm test && npm run build`; `node scripts/prepare.mjs android|ios`. Android SDK36/JDK21, iOS Xcode26+. Папки android/ios/www/node_modules/release игнорируются; генерируются подготовительным скриптом. Версия iOS 0.10.0/build100002, Android versionName0.10.0-beta.2/versionCode100002. При следующей beta поднять build number в prepare.mjs. Скрипт создаёт iOS PrivacyInfo.xcprivacy и иконки; не включать в репозиторий ключи подписи.

## Проверено

- Unit-тесты: close/delete/naming, удаление проекта с закрытыми заметками, additive import, восстановление после оборванного слота, ошибка записи и повтор.
- Browser UI: 375×812, 812×375, 1024×768. Русский текст/emoji, Markdown preview, восстановление после reload, создание проекта, светлая/тёмная тема, переключение EN; горизонтального overflow на телефоне нет. Это проверка web-слоя.
- Локально нет полного Xcode или JDK: нативная компиляция выполняется CI. Не утверждать ручную проверку iOS/Android.

## Следующие шаги на устройстве

1. APK: установка, экранная клавиатура, курсор и выделение с русским/emoji, поворот экрана, кнопка Back, safe areas на Android15/16.
2. Набрать текст, дождаться «На устройстве», свернуть, завершить процесс и открыть. Затем тестировать прерывание во время записи. Сохранить backup до стресс-теста.
3. Импорт Files/Android picker, экспорт заметки и backup в выбранную пользователем папку. Отмена системного окна не меняет заметки.
4. Проекты: закрыть последнюю вкладку; удалить последнюю заметку; повтор номера1; удалить проект с закрытыми заметками; перезапуск. Ничего не создавать автоматически в пустом проекте.
5. 100/300 заметок, длинные имена, 1МБ вставка, поиск, HTML sanitization. Большой системный шрифт, VoiceOver/TalkBack, Reduce Motion.
6. iPhone/iPad: установить Xcode, Team, запустить на физическом устройстве, проверить safe areas/клавиатуру/экспорт. Затем постоянная подпись Android и TestFlight.

## GitHub — реализация beta.2

`src/github-auth.mjs` — Device Flow с отменой/generation и защищёнными сериализованными записями; `github-native.js` — native HTTP без redirects и ограничение GitHub hosts, native secure credential plugin. `github-sync.mjs` — общий snapshot/merge, Git Data API с pinned parent/base_tree и non-force PATCH. `github-view.js` — системный браузер, отдельные подтверждения создания репозитория и отправки всех заметок. Client ID общий публичный, Client Secret отсутствует. В сессию/backup попадает только имя репозитория, не credential.

Android: Keystore AES-GCM + encrypted SharedPreferences. iOS: Keychain ThisDeviceOnly. Bridge logging выключен. Native исходники копируются/регистрируются prepare.mjs, не терять их при регенерации платформ. Реальные OAuth/два устройства E2E проверяет владелец после установки; unit-тесты используют синтетические ответы и не являются входом в его аккаунт.

Следующее: проверка физического Android/iPhone/iPad, постоянная подпись APK/TestFlight, реальная пара desktop/mobile на приватном репозитории с конфликтами и удалениями. Mobile login не требует передачи токена разработчику.

## Подтверждённый выпуск

[mobile-v0.10.0-beta.1](https://github.com/starscream001/notepad_for_mac/releases/tag/mobile-v0.10.0-beta.1) опубликован. Actions42105213434: Android APK и iOS Simulator compile SUCCESS,6 mobile tests pass,4 файла с SHA256 загружены. Десктопный Latest — v0.9.4. Следующий обязательный шаг — физическое устройство; не выдавать успешную компиляцию за эту проверку.


## Beta.2

16 unit tests; format/preview dialogs and visible Menu actions; native adjustResize + viewport keyboard handling. GitHub sign-in/create/sync implemented in mobile/src/github-*. Protected credential plugin native/android and native/ios is installed by prepare.mjs. No fallback to localStorage or Filesystem for tokens. loggingBehavior=none. Mobile settings store only repository name; portable export excludes credentials. CI Android14 tablet test validates controls/IME geometry and encrypted credential roundtrip with disposable synthetic data, no real login. iOS compile and physical-device checks remain distinct. Release links and update/backup instructions in mobile/README.md.
