export const strings={
'Контрольная сумма SHA256 не совпала. Установщик не запускается.':'Update SHA256 does not match.',
'Размер обновления не совпал.':'Update size does not match.',
'Загрузка обновления не завершена.':'Update download is incomplete.',
'Превышен размер обновления.':'Update download is too large.',
'Недопустимый сервер загрузки обновления.':'Unexpected update download server.',
'Не удалось проверить данные обновления.':'Update metadata could not be verified.',
'В релизе нет установщика Windows.':'Update installer is missing.',
'Превышено время загрузки обновления.':'Update download timed out.',

'Цветовая схема':'Color scheme',
'Формат':'Format','Настройки':'Settings','Диалект SQL':'SQL dialect','Форматирование JSON и SQL — только по кнопке. Авто определяет диалект по расширению файла.':'JSON and SQL formatting runs only on command. Auto detects the dialect from the file extension.',
'＋ Новый':'+ New','Открыть':'Open','Сохранить':'Save','Найти':'Find','Предпросмотр':'Preview','О проекте':'About',
'Вкладки':'Tabs','Все вкладки':'All tabs','Поиск вкладки':'Find a tab','Язык':'Syntax','Авто':'Auto','Текст':'Plain text','Тема':'Theme','Кодировка':'Encoding','Окончания строк':'Line endings','Системная':'System','Тёмная':'Dark','Светлая':'Light','Интерфейс':'Interface',
'Текст. Код. Запросы.':'Text. Code. Queries.','Разработчик —':'Developer —','Репозиторий на GitHub':'GitHub repository','Дорожная карта':'Roadmap','Поддержать разработчика':'Support the developer','СБП · Ozon Банк':'SBP · Ozon Bank','Скопировать номер':'Copy phone number','Поддержка добровольная. Все функции бесплатны. MIT.':'Support is voluntary. All features are free. MIT.',
'Обновления':'Updates','Проверять при запуске и по расписанию':'Check on startup and periodically','Период':'Interval','6 часов':'6 hours','Сутки':'Daily','Неделя':'Weekly','Проверить сейчас':'Check now','Windows: загрузка и запуск установщика внутри приложения. Linux: установка из Release. Документы не отправляются.':'Windows: in-app download and installer launch. Linux: install from Release. Documents stay on your computer.',
'О приложении и поддержка':'About and support','Открытые документы':'Open documents','Редактор':'Editor','Предпросмотр документа':'Document preview','Новая вкладка':'New tab','Закрыть':'Close','Ширина панелей':'Panel width','ПРЕДПРОСМОТР':'PREVIEW','Markdown / HTML · без скриптов':'Markdown / HTML · scripts disabled',
'Номер скопирован':'Phone number copied','Установлена последняя доступная версия для вашей ОС.':'You have the latest available version for your OS.'
};
const reverse=Object.fromEntries(Object.entries(strings).map(([ru,en])=>[en,ru]));
export function translate(value,locale){return locale==='en'?(strings[value]||value):(reverse[value]||value);}
export function localizeDOM(locale){document.documentElement.lang=locale;for(const element of document.querySelectorAll('[aria-label],[placeholder],[title]')){for(const attr of ['aria-label','placeholder','title'])if(element.hasAttribute(attr))element.setAttribute(attr,translate(element.getAttribute(attr),locale));}for(const root of document.querySelectorAll('header,footer,#about-dialog,#settings-dialog,#tabs-dialog,.preview-label')){const walker=document.createTreeWalker(root,NodeFilter.SHOW_TEXT);let node;while(node=walker.nextNode()){const trimmed=node.textContent.trim();if(trimmed)node.textContent=node.textContent.replace(trimmed,translate(trimmed,locale));}for(const element of [root,...root.querySelectorAll('[aria-label]')])if(element.hasAttribute('aria-label'))element.setAttribute('aria-label',translate(element.getAttribute('aria-label'),locale));}}
