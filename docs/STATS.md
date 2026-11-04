# Статистика проекта

GitHub хранит `download_count` для каждого файла релиза. Кнопка скачивания README и встроенный установщик загружают тот же `Notepad-Mac-universal.zip`, поэтому их загрузки входят в счётчик файла.

Счётчик в README показывает ZIP **последней стабильной версии**, без скачиваний контрольной суммы. Повторные загрузки и автообновления тоже учитываются. Это не число уникальных пользователей, установок или активных устройств. Отдельный источник «кнопка README / страница Releases / обновление» GitHub в этом счётчике не разделяет.

Посещения и клонирования репозитория доступны владельцу в **Insights → Traffic** за последние 14 дней. В приложении нет собственного счётчика запусков или аналитического SDK.

## Посмотреть загрузки всех версий

Если установлен GitHub CLI:

```sh
gh api repos/starscream001/notepad_for_mac/releases --paginate \
  --jq '.[] | select(.draft == false) | .tag_name as $version | .assets[] | select(.name == "Notepad-Mac-universal.zip") | [$version, .download_count] | @tsv'
```

[GitHub: release assets](https://docs.github.com/en/rest/releases/assets) · [GitHub: traffic](https://docs.github.com/en/repositories/viewing-activity-and-data-for-your-repository/viewing-traffic-to-a-repository)
