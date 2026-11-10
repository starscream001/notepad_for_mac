# Установка Notepad на свой iPhone / iPad

## Что можно скачать сейчас

[Mobile 0.10.0-beta.2](https://github.com/starscream001/notepad_for_mac/releases/tag/mobile-v0.10.0-beta.2) содержит Android APK и **iOS Simulator ZIP**. ZIP предназначен для симулятора Xcode на Mac. Он не устанавливается на физический iPhone и не превращается в установщик переименованием в IPA. Подписанного IPA/TestFlight у проекта пока нет.

## Бесплатно: Xcode и Personal Team

Нужны Mac, полный Xcode 26+, Node.js 22+, свой Apple Account и iPhone/iPad с iOS/iPadOS 16+.

1. Скачайте исходники репозитория или клонируйте:

   ```sh
   git clone https://github.com/starscream001/notepad_for_mac.git
   cd notepad_for_mac/mobile
   npm ci
   npm test
   npm run build
   node scripts/prepare.mjs ios
   npm run ios
   ```

2. В Xcode → Settings → Accounts добавьте свой Apple Account. Бесплатная команда отображается как **Personal Team**.
3. Подключите iPhone/iPad к Mac, подтвердите доверие компьютеру. Включите Developer Mode на устройстве, если Xcode попросит.
4. В проекте App выберите target App → Signing & Capabilities → **Automatically manage signing** → свой Personal Team.
5. Если идентификатор занят другой командой, задайте уникальный Bundle Identifier, например `com.yourname.notepad.test`. Сохраняйте этот идентификатор для последующих установок. После повторного запуска prepare проверьте параметры подписи снова.
6. Выберите подключённое устройство вместо Simulator и нажмите **Run**. При запросе iOS разрешите доверие своему разработчику в настройках устройства.
7. До переустановок экспортируйте резервную копию заметок из приложения. Не удаляйте приложение ради продления подписи: сначала попробуйте повторный Run с тем же идентификатором и командой.

Бесплатный профиль истекает через **7 дней**: потребуется пересобрать и установить приложение. Apple также ограничивает Personal Team тремя устройствами и тремя установленными приложениями на устройство. Это установка для личного теста, не общедоступный канал распространения. [Условия Apple](https://developer.apple.com/help/account/basics/about-your-developer-account/).

## Можно ли взять сертификат другого приложения?

Скопированного сертификата или подписи из чужого приложения недостаточно: подпись проверяется по содержимому сборки, ключу разработчика и provisioning profile с разрешённым App ID/возможностями/устройствами. Изменение приложения делает старую подпись недействительной. Самостоятельно выпущенный сертификат iPhone не начнёт доверять автоматически. [Объяснение Apple](https://developer.apple.com/documentation/technotes/tn3125-inside-code-signing-provisioning-profiles).

Если у вас уже есть **свой** действующий аккаунт/команда разработчика для другого приложения, можно использовать разрешённую signing identity этой команды с подходящим новым App ID и профилем Notepad. Секретный ключ не публикуется и не извлекается из стороннего приложения.

## Удобная установка для пользователей

Для распространения через TestFlight/App Store потребуется Apple Developer Program владельца и настройка App Store Connect, подписи и CI. Для пользователей скачивание TestFlight-приложения не требует покупки сертификата. В проекте этот канал пока не подключён.

[Запуск на устройстве — Apple](https://help.apple.com/xcode/mac/current/en.lproj/dev5a825a1ca.html) · [Мобильный клиент](../mobile/README.md).
