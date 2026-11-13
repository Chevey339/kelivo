// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Russian (`ru`).
class AppLocalizationsRu extends AppLocalizations {
  AppLocalizationsRu([String locale = 'ru']) : super(locale);

  @override
  String get avatarInputInvalid =>
      'Введите корректное имя значка или URL изображения HTTP(S).';

  @override
  String get modelAvatarTitle => 'Значок модели';

  @override
  String get avatarColor => 'Цветной';

  @override
  String get avatarMonochrome => 'Монохромный';

  @override
  String get settingsSearchHint => 'Поиск настроек';

  @override
  String get settingsSearchCancel => 'Отмена';

  @override
  String get settingsSearchClear => 'Очистить поиск';

  @override
  String get settingsSearchSuggestions => 'Быстрый доступ';

  @override
  String get settingsSearchNoResults => 'Настройки не найдены';

  @override
  String get settingsSearchNoResultsHint =>
      'Попробуйте другое название или более короткий запрос.';

  @override
  String settingsSearchResultCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count результата',
      many: '$count результатов',
      few: '$count результата',
      one: '$count результат',
    );
    return '$_temp0';
  }

  @override
  String get helloWorld => 'Привет, мир!';

  @override
  String get settingsPageBackButton => 'Назад';

  @override
  String get settingsPageTitle => 'Настройки';

  @override
  String get settingsPageDarkMode => 'Тёмная';

  @override
  String get settingsPageLightMode => 'Светлая';

  @override
  String get settingsPageSystemMode => 'Системная';

  @override
  String get settingsPageWarningMessage =>
      'Некоторые сервисы не настроены; часть функций может быть недоступна.';

  @override
  String get settingsPageGeneralSection => 'Общие';

  @override
  String get settingsPageColorMode => 'Цветовой режим';

  @override
  String get settingsPageDisplay => 'Предпочтения';

  @override
  String get settingsPageDisplaySubtitle =>
      'Внешний вид, поведение и взаимодействие';

  @override
  String get settingsPageAssistant => 'Ассистент';

  @override
  String get settingsPageAssistantSubtitle => 'Ассистент по умолчанию и стиль';

  @override
  String get settingsPageModelsServicesSection => 'Модели и сервисы';

  @override
  String get settingsPageDefaultModel => 'Модель по умолчанию';

  @override
  String get settingsPageProviders => 'Провайдеры';

  @override
  String get settingsPageHotkeys => 'Горячие клавиши';

  @override
  String get settingsPageSearch => 'Поиск';

  @override
  String get settingsPageTts => 'TTS';

  @override
  String get settingsPageMcp => 'MCP';

  @override
  String get settingsPageQuickPhrase => 'Быстрые фразы';

  @override
  String get settingsPageInstructionInjection => 'Внедрение инструкций';

  @override
  String get settingsPageDataSection => 'Данные';

  @override
  String get settingsPageBackup => 'Резервная копия';

  @override
  String get settingsPageChatStorage => 'Хранилище чатов';

  @override
  String get settingsPageCalculating => 'Подсчёт…';

  @override
  String get storageSpacePageTitle => 'Хранилище';

  @override
  String get storageSpaceRefreshTooltip => 'Обновить';

  @override
  String get storageSpaceLoadFailed =>
      'Не удалось загрузить файлы или проверить использование изображений. Обновите и повторите попытку.';

  @override
  String get storageSpaceTotalLabel => 'Использовано';

  @override
  String storageSpaceClearableLabel(String size) {
    return 'Можно очистить: $size';
  }

  @override
  String storageSpaceClearableHint(String size) {
    return 'Безопасно очистить: $size';
  }

  @override
  String get storageSpaceCategoryImages => 'Изображения';

  @override
  String get storageSpaceCategoryFiles => 'Файлы';

  @override
  String get storageSpaceCategoryFonts => 'Шрифты';

  @override
  String get storageSpaceCategoryLocalModels => 'Локальные модели';

  @override
  String get storageSpaceOtherHint =>
      'Шрифты, загруженные локальные модели и другие файлы приложения.';

  @override
  String get storageSpaceSubOtherApp => 'Файлы приложения';

  @override
  String get storageSpaceCategoryChatData => 'Записи чатов';

  @override
  String get storageSpaceCategoryLegacyChatData => 'Записи чатов (старые)';

  @override
  String get storageSpaceCategoryRestoreTraces => 'Следы восстановления';

  @override
  String get storageSpaceCategoryDisplacedDatabases => 'Отложенные базы данных';

  @override
  String get storageSpaceSubDisplacedDatabases =>
      'Сохранены перед автоматическим пересозданием';

  @override
  String get storageSpaceClearDisplacedDatabasesConfirmMessage =>
      'Удалить эти отложенные базы данных? Kelivo сохранил их при пересоздании своей базы данных, и они могут быть единственной сохранившейся копией этих чатов и настроек. Это действие нельзя отменить.';

  @override
  String get storageSpaceRestoreTracesHint =>
      'Снимки прежних данных, сохранённые после завершённых восстановлений. Их очистка не влияет на текущие данные приложения.';

  @override
  String get storageSpaceClearRestoreTracesButton =>
      'Очистить следы восстановления';

  @override
  String get storageSpaceClearDisplacedDatabasesButton =>
      'Удалить отложенные базы данных';

  @override
  String get storageSpaceClearRestoreTracesConfirmMessage =>
      'Очистить снимки завершённых восстановлений? Текущая база данных, настройки и файлы не будут затронуты.';

  @override
  String get storageSpaceSubCompletedRestoreRuns =>
      'Снимки завершённых восстановлений';

  @override
  String get storageSpaceCategoryCache => 'Кэш';

  @override
  String get storageSpaceCategoryLogs => 'Журналы';

  @override
  String get storageSpaceCategoryOther => 'Другое';

  @override
  String get storageSpaceSafeToClearHint =>
      'Можно безопасно очистить. Это не повлияет на историю чатов.';

  @override
  String get storageSpaceLegacyChatDataHint =>
      'Это сохранённые старые файлы Hive, оставшиеся до перехода на SQLite. Их очистка не удалит текущие записи чатов.';

  @override
  String get storageSpaceNotSafeToClearHint =>
      'Может повлиять на историю чатов. Удаляйте с осторожностью.';

  @override
  String get storageSpaceBreakdownTitle => 'Детализация';

  @override
  String get storageSpaceSubChatMessages => 'Сообщения';

  @override
  String get storageSpaceSubChatConversations => 'Беседы';

  @override
  String get storageSpaceSubChatToolEvents => 'События инструментов';

  @override
  String get storageSpaceSubChatDatabase => 'База данных чатов';

  @override
  String get storageSpaceSubChatWriteAheadLog => 'Журнал упреждающей записи';

  @override
  String get storageSpaceSubChatSharedMemory => 'Индекс общей памяти';

  @override
  String get storageSpaceSubCacheAvatars => 'Кэш аватаров';

  @override
  String get storageSpaceSubCacheOther => 'Другой кэш';

  @override
  String get storageSpaceSubCacheSystem => 'Системный кэш';

  @override
  String get storageSpaceSubLogsContext => 'Журналы контекста';

  @override
  String get storageSpaceSubLogsFlutter => 'Журналы Flutter';

  @override
  String get storageSpaceSubLogsRequests => 'Журналы сети';

  @override
  String get storageSpaceSubLogsOther => 'Другие журналы';

  @override
  String get storageSpaceClearConfirmTitle => 'Подтвердите очистку';

  @override
  String storageSpaceClearConfirmMessage(String targetName) {
    return 'Очистить $targetName?';
  }

  @override
  String get storageSpaceClearButton => 'Очистить';

  @override
  String storageSpaceClearDone(String targetName) {
    return '$targetName очищено';
  }

  @override
  String storageSpaceClearFailed(String error) {
    return 'Не удалось очистить: $error';
  }

  @override
  String get storageSpaceClearAvatarCacheButton => 'Очистить кэш аватаров';

  @override
  String get storageSpaceClearCacheButton => 'Очистить кэш';

  @override
  String get storageSpaceClearLogsButton => 'Очистить журналы';

  @override
  String get storageSpaceClearLegacyChatDataButton =>
      'Очистить старые записи чатов';

  @override
  String get storageSpaceExportLegacyChatFileButton => 'Экспорт';

  @override
  String storageSpaceExportDone(Object fileName) {
    return '$fileName экспортирован';
  }

  @override
  String storageSpaceExportFailed(Object error) {
    return 'Не удалось экспортировать: $error';
  }

  @override
  String get storageSpaceClearLegacyChatDataConfirmMessage =>
      'Очистить сохранённые старые файлы чатов? Текущие записи чатов SQLite останутся доступными.';

  @override
  String get storageSpaceViewLogsButton => 'Просмотреть журналы';

  @override
  String get storageSpaceDeleteConfirmTitle => 'Подтвердите удаление';

  @override
  String storageSpaceDeleteUploadsConfirmMessage(int count) {
    return 'Удалить элементы ($count) и связанные с ними копии вложений бесед? Эти вложения станут недоступны в истории чатов.';
  }

  @override
  String storageSpaceDeletedUploadsDone(int count) {
    return 'Удалено элементов: $count';
  }

  @override
  String get storageSpaceNoUploads => 'Нет элементов';

  @override
  String get storageSpaceSelectAll => 'Выбрать все';

  @override
  String get storageSpaceClearSelection => 'Снять выделение';

  @override
  String storageSpaceSelectedCount(int count) {
    return 'Выбрано: $count';
  }

  @override
  String storageSpaceUploadsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count элемента',
      many: '$count элементов',
      few: '$count элемента',
      one: '$count элемент',
    );
    return '$_temp0';
  }

  @override
  String get storageSpaceSortLabel => 'Сортировка';

  @override
  String get storageSpaceSortNewest => 'Сначала новые';

  @override
  String get storageSpaceSortOldest => 'Сначала старые';

  @override
  String get storageSpaceSortLargest => 'Сначала крупные';

  @override
  String get storageSpaceSortSmallest => 'Сначала мелкие';

  @override
  String get settingsPageAboutSection => 'О приложении';

  @override
  String get settingsPageAbout => 'О приложении';

  @override
  String get settingsPageStatistics => 'Статистика';

  @override
  String get settingsPageDocs => 'Документация';

  @override
  String get settingsPageLogs => 'Журналы';

  @override
  String get settingsPageSponsor => 'Поддержать';

  @override
  String get settingsPageShare => 'Поделиться';

  @override
  String get statsPageTitle => 'Статистика';

  @override
  String get statsPageRangeAllTime => 'За всё время';

  @override
  String get statsPageRangeLast30Days => 'Последние 30 дней';

  @override
  String get statsPageRangePreviousMonth => 'Прошлый месяц';

  @override
  String get statsPageRangePreviousQuarter => 'Прошлый квартал';

  @override
  String get statsPageRangeCustom => 'Свой период';

  @override
  String get statsPageHeatmapTitle => 'Тепловая карта чатов';

  @override
  String get statsPageHeatmapLess => 'Меньше';

  @override
  String get statsPageHeatmapMore => 'Больше';

  @override
  String get statsPageSummaryTitle => 'Обзор';

  @override
  String get statsPageTotalConversations => 'Всего чатов';

  @override
  String get statsPageTotalMessages => 'Всего сообщений';

  @override
  String get statsPageInputTokens => 'Входные токены';

  @override
  String get statsPageOutputTokens => 'Выходные токены';

  @override
  String get statsPageCachedTokens => 'Кэшированные токены';

  @override
  String get statsPageLaunchCount => 'Запуски приложения';

  @override
  String statsPageCost(String currency) {
    return 'Стоимость ($currency)';
  }

  @override
  String statsPageModelsWithoutPricing(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count модели без цены',
      many: '$count моделей без цены',
      few: '$count модели без цены',
      one: '$count модель без цены',
    );
    return '$_temp0';
  }

  @override
  String get statsPageUsageTrendTitle => 'Динамика использования';

  @override
  String get statsPageModelUsageTitle => 'Использование моделей';

  @override
  String get statsPageAssistantUsageTitle => 'Использование ассистентов';

  @override
  String get statsPageTopicVolumeTitle => 'Объём по темам';

  @override
  String get statsPageModelColumn => 'Модель';

  @override
  String get statsPageAssistantColumn => 'Ассистент';

  @override
  String get statsPageTopicColumn => 'Тема';

  @override
  String get statsPageMessagesColumn => 'Сообщения';

  @override
  String get statsPageTopicsColumn => 'Темы';

  @override
  String get statsPageEmptyTitle => 'Статистики пока нет';

  @override
  String get statsPageShowAllTooltip => 'Показать все';

  @override
  String get statsPageClose => 'Закрыть';

  @override
  String get statsPageUnknownProvider => 'Неизвестный провайдер';

  @override
  String get statsPageUnknownAssistant => 'Ассистент по умолчанию';

  @override
  String get statsPageUnknownModel => 'Неизвестная модель';

  @override
  String get statsPageUnknownTopic => 'Тема без названия';

  @override
  String get statsPageCustomRangeTitle => 'Свой период';

  @override
  String get statsPageCustomRangeStart => 'Начало';

  @override
  String get statsPageCustomRangeEnd => 'Конец';

  @override
  String get statsPageCustomRangeCancel => 'Отмена';

  @override
  String get statsPageCustomRangeApply => 'Применить';

  @override
  String get sponsorPageMethodsSectionTitle => 'Способы поддержки';

  @override
  String get sponsorPageSponsorsSectionTitle => 'Спонсоры';

  @override
  String get sponsorPageEmpty => 'Пока нет спонсоров';

  @override
  String get sponsorPageAfdianTitle => 'Afdian';

  @override
  String get sponsorPageAfdianSubtitle => 'afdian.com/a/kelivo';

  @override
  String get sponsorPageWeChatTitle => 'Поддержка через WeChat';

  @override
  String get sponsorPageWeChatSubtitle => 'QR-код для поддержки в WeChat';

  @override
  String get sponsorPageScanQrHint => 'Отсканируйте QR-код, чтобы поддержать';

  @override
  String get languageDisplaySimplifiedChinese => 'Китайский (упрощённый)';

  @override
  String get languageDisplayEnglish => 'Английский';

  @override
  String get languageDisplayTraditionalChinese => 'Китайский (традиционный)';

  @override
  String get languageDisplayJapanese => 'Японский';

  @override
  String get languageDisplayKorean => 'Корейский';

  @override
  String get languageDisplayFrench => 'Французский';

  @override
  String get languageDisplayGerman => 'Немецкий';

  @override
  String get languageDisplayItalian => 'Итальянский';

  @override
  String get languageDisplaySpanish => 'Испанский';

  @override
  String get languageSelectSheetTitle => 'Выбор языка перевода';

  @override
  String get languageSelectSheetClearButton => 'Очистить перевод';

  @override
  String get homePageClearContext => 'Очистить контекст';

  @override
  String contextMessageCount(int count) {
    return '$count сообщений';
  }

  @override
  String contextMessageCountLimited(int actual, int configured) {
    return '$actual/$configured сообщений';
  }

  @override
  String get homePageDefaultAssistant => 'Ассистент по умолчанию';

  @override
  String get mermaidExportPng => 'Экспорт PNG';

  @override
  String get mermaidExportFailed => 'Не удалось экспортировать';

  @override
  String get mermaidImageTab => 'Изображение';

  @override
  String get mermaidCodeTab => 'Код';

  @override
  String get mermaidFullScreen => 'Полный экран';

  @override
  String get mermaidGeneratingImage => 'Создание изображения';

  @override
  String get mermaidGenerationFailedHint =>
      'Не удалось создать. Попробуйте спросить иначе.';

  @override
  String get mermaidPreviewOpen => 'Открыть предпросмотр';

  @override
  String get mermaidPreviewOpenFailed => 'Не удалось открыть предпросмотр';

  @override
  String get assistantProviderDefaultAssistantName => 'Ассистент по умолчанию';

  @override
  String get assistantProviderSampleAssistantName => 'Пример ассистента';

  @override
  String get assistantProviderNewAssistantName => 'Новый ассистент';

  @override
  String assistantProviderSampleAssistantSystemPrompt(String model_name) {
    return 'Ты — $model_name, полезный ИИ-ассистент. Отвечай точно и кратко; если не уверен, скажи об этом. Когда это помогает, используй понятную структуру (короткие абзацы или списки). По умолчанию отвечай на языке пользователя.';
  }

  @override
  String get displaySettingsPageLanguageTitle => 'Язык приложения';

  @override
  String get displaySettingsPageLanguageSubtitle => 'Выберите язык интерфейса';

  @override
  String get assistantTagsManageTitle => 'Управление тегами';

  @override
  String get assistantTagsCreateButton => 'Создать';

  @override
  String get assistantTagsCreateDialogTitle => 'Создать тег';

  @override
  String get assistantTagsCreateDialogOk => 'Создать';

  @override
  String get assistantTagsCreateDialogCancel => 'Отмена';

  @override
  String get assistantTagsNameHint => 'Название тега';

  @override
  String get assistantTagsRenameButton => 'Переименовать';

  @override
  String get assistantTagsRenameDialogTitle => 'Переименовать тег';

  @override
  String get assistantTagsRenameDialogOk => 'Переименовать';

  @override
  String get assistantTagsDeleteButton => 'Удалить';

  @override
  String get assistantTagsDeleteConfirmTitle => 'Удалить тег';

  @override
  String get assistantTagsDeleteConfirmContent =>
      'Вы уверены, что хотите удалить этот тег?';

  @override
  String get assistantTagsDeleteConfirmOk => 'Удалить';

  @override
  String get assistantTagsDeleteConfirmCancel => 'Отмена';

  @override
  String get assistantTagsContextMenuEditAssistant =>
      'Редактировать ассистента';

  @override
  String get assistantTagsContextMenuManageTags => 'Управление тегами';

  @override
  String get mcpTransportOptionStdio => 'STDIO';

  @override
  String get mcpTransportTagStdio => 'STDIO';

  @override
  String get mcpTransportTagInmemory => 'Встроенный';

  @override
  String get mcpTransportTagSse => 'SSE';

  @override
  String get mcpTransportTagHttp => 'HTTP';

  @override
  String get mcpServerEditSheetStdioCommandLabel => 'Команда';

  @override
  String get mcpServerEditSheetStdioArgumentsLabel => 'Аргументы';

  @override
  String get mcpServerEditSheetStdioWorkingDirectoryLabel =>
      'Рабочий каталог (необязательно)';

  @override
  String get mcpWorkspaceBindingLabel =>
      'Привязать рабочую область (необязательно)';

  @override
  String get mcpWorkspaceBindingHint =>
      'Сервер может получить доступ к этой рабочей области по пути /workspace. Оставьте рабочий каталог пустым, чтобы запускать сервер оттуда. Привязка не меняется при переключении чатов.';

  @override
  String get mcpWorkspaceBindingMobileOnly =>
      'Привязка рабочей области доступна в мобильной среде Linux. Отвяжите её, чтобы запустить этот сервер на десктопе.';

  @override
  String get mcpServerEditSheetStdioEnvironmentTitle => 'Переменные окружения';

  @override
  String get mcpServerEditSheetStdioEnvNameLabel => 'Имя';

  @override
  String get mcpServerEditSheetStdioEnvValueLabel => 'Значение';

  @override
  String get mcpServerEditSheetStdioAddEnv => 'Добавить переменную';

  @override
  String get mcpServerEditSheetStdioCommandRequired =>
      'Для STDIO требуется команда';

  @override
  String get assistantTagsContextMenuDeleteAssistant => 'Удалить ассистента';

  @override
  String get assistantTagsClearTag => 'Очистить тег';

  @override
  String get displaySettingsPageLanguageChineseLabel =>
      'Китайский (упрощённый)';

  @override
  String get displaySettingsPageLanguageEnglishLabel => 'English';

  @override
  String get homePagePleaseSelectModel => 'Сначала выберите модель';

  @override
  String get homePagePleaseSetupTranslateModel =>
      'Сначала настройте модель перевода';

  @override
  String get homePageTranslating => 'Перевод...';

  @override
  String homePageTranslateFailed(String error) {
    return 'Ошибка перевода: $error';
  }

  @override
  String get chatServiceDefaultConversationTitle => 'Новый чат';

  @override
  String get userProviderDefaultUserName => 'Пользователь';

  @override
  String get homePageDeleteMessage => 'Удалить эту версию';

  @override
  String get homePageDeleteMessageConfirm =>
      'Вы уверены, что хотите удалить эту версию? Это действие нельзя отменить.';

  @override
  String get homePageDeleteAllVersions => 'Удалить все версии';

  @override
  String get homePageDeleteAllVersionsConfirm =>
      'Вы уверены, что хотите удалить все версии этого сообщения? Это действие нельзя отменить.';

  @override
  String get homePageCancel => 'Отмена';

  @override
  String get homePageDelete => 'Удалить';

  @override
  String get homePageSelectMessagesToShare => 'Выберите сообщения для отправки';

  @override
  String get homePageDone => 'Готово';

  @override
  String get homePageDropToUpload => 'Перетащите файлы сюда для загрузки';

  @override
  String get assistantEditPageTitle => 'Ассистент';

  @override
  String get assistantEditPageNotFound => 'Ассистент не найден';

  @override
  String get assistantEditPageBasicTab => 'Основные';

  @override
  String get assistantEditPagePromptsTab => 'Промпты';

  @override
  String get assistantEditPageMcpTab => 'MCP';

  @override
  String get assistantEditPageQuickPhraseTab => 'Быстрые фразы';

  @override
  String get assistantEditPageCustomTab => 'Пользовательский запрос';

  @override
  String get assistantEditPageRegexTab => 'Замена по регулярному выражению';

  @override
  String get assistantEditPageLocalToolsTab => 'Локальные инструменты';

  @override
  String get assistantEditTabLayoutTooltip => 'Настроить вкладки';

  @override
  String get assistantEditTabLayoutTitle => 'Настроить вкладки';

  @override
  String get assistantEditTabLayoutSubtitle =>
      'Перетаскивайте вкладки для изменения порядка. Отключите ненужные вкладки.';

  @override
  String get assistantEditOutlineModeTitle => 'Стиль списка разделов';

  @override
  String get assistantEditOutlineModeSubtitle =>
      'Сначала показывать обзор ассистента, затем открывать разделы настроек из списка.';

  @override
  String get assistantEditTabLayoutResetTooltip =>
      'Сбросить расположение вкладок';

  @override
  String get assistantEditTabLayoutAtLeastOneVisible =>
      'Оставьте хотя бы одну видимую вкладку';

  @override
  String assistantEditTabLayoutDragHandle(String tab) {
    return 'Перетащите, чтобы изменить порядок $tab';
  }

  @override
  String get assistantEditRegexDescription =>
      'Создавайте правила регулярных выражений для изменения или визуальной корректировки сообщений пользователя/ассистента.';

  @override
  String get assistantEditAddRegexButton => 'Добавить правило regex';

  @override
  String get assistantRegexAddTitle => 'Добавить правило regex';

  @override
  String get assistantRegexEditTitle => 'Изменить правило regex';

  @override
  String get assistantRegexNameLabel => 'Название правила';

  @override
  String get assistantRegexPatternLabel => 'Регулярное выражение';

  @override
  String get assistantRegexReplacementLabel => 'Строка замены';

  @override
  String get assistantRegexScopeLabel => 'Область действия';

  @override
  String get assistantRegexScopeUser => 'Пользователь';

  @override
  String get assistantRegexScopeAssistant => 'Ассистент';

  @override
  String get assistantRegexScopeVisualOnly => 'Только визуально';

  @override
  String get assistantRegexScopeReplaceOnly => 'Только замена';

  @override
  String get assistantRegexAddAction => 'Добавить';

  @override
  String get assistantRegexSaveAction => 'Сохранить';

  @override
  String get assistantRegexDeleteButton => 'Удалить';

  @override
  String get assistantRegexValidationError =>
      'Укажите название, регулярное выражение и выберите хотя бы одну область.';

  @override
  String get assistantRegexInvalidPattern =>
      'Недопустимое регулярное выражение';

  @override
  String get assistantRegexCancelButton => 'Отмена';

  @override
  String get assistantRegexUntitled => 'Правило без названия';

  @override
  String get assistantEditCustomHeadersTitle => 'Пользовательские заголовки';

  @override
  String get assistantEditCustomHeadersAdd => 'Добавить заголовок';

  @override
  String get assistantEditCustomHeadersEmpty => 'Заголовки не добавлены';

  @override
  String get assistantEditCustomBodyTitle => 'Пользовательское тело запроса';

  @override
  String get assistantEditCustomBodyAdd => 'Добавить поле тела';

  @override
  String get assistantEditCustomBodyEmpty => 'Поля тела не добавлены';

  @override
  String get assistantEditHeaderNameLabel => 'Имя заголовка';

  @override
  String get assistantEditHeaderValueLabel => 'Значение заголовка';

  @override
  String get assistantEditBodyKeyLabel => 'Ключ поля тела';

  @override
  String get assistantEditBodyValueLabel => 'Значение поля тела (JSON)';

  @override
  String get assistantEditDeleteTooltip => 'Удалить';

  @override
  String get assistantEditAssistantNameLabel => 'Имя ассистента';

  @override
  String get assistantEditUseAssistantAvatarTitle =>
      'Использовать аватар ассистента';

  @override
  String get assistantEditUseAssistantAvatarSubtitle =>
      'Использовать аватар ассистента вместо аватара модели';

  @override
  String get assistantEditUseAssistantNameTitle =>
      'Использовать имя ассистента';

  @override
  String get assistantEditChatModelTitle => 'Модель чата';

  @override
  String get assistantEditChatModelSubtitle =>
      'Модель чата по умолчанию для этого ассистента (иначе используется глобальная)';

  @override
  String get assistantEditTemperatureDescription =>
      'Управляет случайностью, диапазон 0–2';

  @override
  String get assistantEditTopPDescription =>
      'Не изменяйте, если не уверены в своих действиях';

  @override
  String get assistantEditParameterDisabled =>
      'Отключено (используется значение провайдера по умолчанию)';

  @override
  String get assistantEditParameterDisabled2 => 'Отключено (без ограничений)';

  @override
  String get assistantEditContextMessagesTitle => 'Сообщения контекста';

  @override
  String get assistantEditContextMessagesDescription =>
      'Сколько последних сообщений сохранять в контексте';

  @override
  String get assistantEditStreamOutputTitle => 'Потоковый вывод';

  @override
  String get assistantEditStreamOutputDescription =>
      'Включить потоковые ответы';

  @override
  String get assistantEditThinkingBudgetTitle => 'Рассуждение';

  @override
  String get assistantEditReasoningFollowDefault => 'Как в модели по умолчанию';

  @override
  String get assistantEditReasoningClampedSubtitle =>
      'Фактический уровень ограничивается возможностями каждой модели';

  @override
  String get assistantEditConfigureButton => 'Настроить';

  @override
  String get assistantEditMaxTokensTitle => 'Макс. токенов';

  @override
  String get assistantEditMaxTokensDescription =>
      'Оставьте пустым для неограниченного';

  @override
  String get assistantEditMaxTokensHint => 'Без ограничений';

  @override
  String get assistantEditChatBackgroundTitle => 'Фон чата';

  @override
  String get assistantEditChatBackgroundDescription =>
      'Задать фоновое изображение для этого ассистента';

  @override
  String get assistantEditChooseImageButton => 'Выбрать изображение';

  @override
  String get assistantEditClearButton => 'Очистить';

  @override
  String get desktopNavChatTooltip => 'Чат';

  @override
  String get desktopNavTranslateTooltip => 'Перевод';

  @override
  String get desktopNavStorageTooltip => 'Хранилище';

  @override
  String get desktopNavGlobalSearchTooltip => 'Глобальный поиск';

  @override
  String get desktopNavThemeToggleTooltip => 'Тема';

  @override
  String get desktopNavSettingsTooltip => 'Настройки';

  @override
  String get desktopAvatarMenuUseEmoji => 'Использовать эмодзи';

  @override
  String get cameraPermissionDeniedMessage =>
      'Камера недоступна: разрешение не предоставлено.';

  @override
  String get openSystemSettings => 'Открыть настройки';

  @override
  String get desktopAvatarMenuChangeFromImage => 'Сменить из изображения…';

  @override
  String get desktopAvatarMenuReset => 'Сбросить аватар';

  @override
  String get assistantEditAvatarChooseImage => 'Выбрать изображение';

  @override
  String get assistantEditAvatarChooseEmoji => 'Выбрать эмодзи';

  @override
  String get assistantEditAvatarEnterLink => 'Ввести ссылку';

  @override
  String get assistantEditAvatarImportQQ => 'Импорт из QQ';

  @override
  String get assistantEditAvatarReset => 'Сбросить';

  @override
  String get displaySettingsPageChatMessageBackgroundTitle =>
      'Фон сообщений чата';

  @override
  String get displaySettingsPageChatMessageBackgroundDefault => 'По умолчанию';

  @override
  String get displaySettingsPageChatMessageBackgroundFrosted =>
      'Матовое стекло';

  @override
  String get displaySettingsPageChatMessageBackgroundSolid => 'Сплошной цвет';

  @override
  String get displaySettingsPageAndroidBackgroundChatTitle =>
      'Генерация в фоне (Android)';

  @override
  String get displaySettingsPageIosBackgroundChatTitle =>
      'Генерация в фоне (iOS)';

  @override
  String get iosBackgroundStatusOn => 'Вкл.';

  @override
  String get iosBackgroundStatusOff => 'Выкл.';

  @override
  String get iosLiveActivityTitle => 'Live Activity';

  @override
  String get iosLiveActivitySubtitle =>
      'Показывать статус фоновых ответов на экране блокировки и в Dynamic Island, если поддерживается.';

  @override
  String get notificationChatCompletedTitle => 'Генерация завершена';

  @override
  String get notificationChatCompletedBody => 'Ответ ассистента сгенерирован';

  @override
  String get assistantEditEmojiDialogTitle => 'Выбрать эмодзи';

  @override
  String get assistantEditEmojiDialogHint =>
      'Введите или вставьте любой эмодзи';

  @override
  String get assistantEditEmojiDialogCancel => 'Отмена';

  @override
  String get assistantEditEmojiDialogSave => 'Сохранить';

  @override
  String get assistantEditImageUrlDialogTitle => 'Введите URL изображения';

  @override
  String get assistantEditImageUrlDialogHint =>
      'например, https://example.com/avatar.png';

  @override
  String get assistantEditImageUrlDialogCancel => 'Отмена';

  @override
  String get assistantEditImageUrlDialogSave => 'Сохранить';

  @override
  String get assistantEditQQAvatarDialogTitle => 'Импорт из QQ';

  @override
  String get assistantEditQQAvatarDialogHint => 'Введите номер QQ (5–12 цифр)';

  @override
  String get assistantEditQQAvatarRandomButton => 'Случайный';

  @override
  String get assistantEditQQAvatarFailedMessage =>
      'Не удалось получить случайный аватар QQ. Попробуйте ещё раз.';

  @override
  String get assistantEditQQAvatarDialogCancel => 'Отмена';

  @override
  String get assistantEditQQAvatarDialogSave => 'Сохранить';

  @override
  String get assistantEditGalleryErrorMessage =>
      'Не удалось открыть галерею. Попробуйте ввести ссылку на изображение.';

  @override
  String get assistantEditGeneralErrorMessage =>
      'Что-то пошло не так. Попробуйте ввести ссылку на изображение.';

  @override
  String get providerDetailPageMultiKeyModeTitle => 'Режим нескольких ключей';

  @override
  String get providerDetailPageManageKeysButton => 'Управление ключами';

  @override
  String get multiKeyPageTitle => 'Управление ключами';

  @override
  String get multiKeyPageDetect => 'Проверить';

  @override
  String get multiKeyPageAdd => 'Добавить';

  @override
  String get multiKeyPageAddHint =>
      'Введите API-ключи через запятую или пробел';

  @override
  String multiKeyPageImportedSnackbar(int n) {
    return 'Импортировано ключей: $n';
  }

  @override
  String get multiKeyPagePleaseAddModel => 'Сначала добавьте модель';

  @override
  String get multiKeyPageTotal => 'Всего';

  @override
  String get multiKeyPageNormal => 'Норма';

  @override
  String get multiKeyPageError => 'Ошибка';

  @override
  String get multiKeyPageAccuracy => 'Точность';

  @override
  String get multiKeyPageStrategyTitle => 'Стратегия балансировки нагрузки';

  @override
  String get multiKeyPageStrategyRoundRobin => 'По кругу';

  @override
  String get multiKeyPageStrategyPriority => 'По приоритету';

  @override
  String get multiKeyPageStrategyLeastUsed => 'Наименее используемый';

  @override
  String get multiKeyPageStrategyRandom => 'Случайно';

  @override
  String get multiKeyPageNoKeys => 'Нет API-ключей';

  @override
  String get multiKeyPageStatusActive => 'Активен';

  @override
  String get multiKeyPageStatusDisabled => 'Отключён';

  @override
  String get multiKeyPageStatusError => 'Ошибка';

  @override
  String get multiKeyPageStatusRateLimited => 'Ограничение скорости';

  @override
  String get multiKeyPageEditAlias => 'Изменить псевдоним';

  @override
  String get multiKeyPageEdit => 'Изменить';

  @override
  String get multiKeyPageKey => 'API-ключ';

  @override
  String get multiKeyPagePriority => 'Приоритет (1–10)';

  @override
  String get multiKeyPageDuplicateKeyWarning => 'Этот ключ уже существует';

  @override
  String get multiKeyPageAlias => 'Псевдоним';

  @override
  String get multiKeyPageCancel => 'Отмена';

  @override
  String get multiKeyPageSave => 'Сохранить';

  @override
  String get multiKeyPageDelete => 'Удалить';

  @override
  String get assistantEditSystemPromptTitle => 'Системный промпт';

  @override
  String get assistantEditSystemPromptHint => 'Введите системный промпт…';

  @override
  String get assistantEditSystemPromptImportButton => 'Импорт из файла';

  @override
  String get assistantEditSystemPromptImportSuccess =>
      'Системный промпт обновлён из файла';

  @override
  String get assistantEditSystemPromptImportFailed =>
      'Не удалось импортировать файл';

  @override
  String get assistantEditSystemPromptImportEmpty => 'Файл пуст';

  @override
  String get assistantEditAvailableVariables => 'Доступные переменные:';

  @override
  String get assistantEditVariableDate => 'Дата';

  @override
  String get assistantEditVariableTime => 'Время';

  @override
  String get assistantEditVariableDatetime => 'Дата и время';

  @override
  String get assistantEditVariableModelId => 'ID модели';

  @override
  String get assistantEditVariableModelName => 'Название модели';

  @override
  String get assistantEditVariableLocale => 'Язык и регион';

  @override
  String get assistantEditVariableTimezone => 'Часовой пояс';

  @override
  String get assistantEditVariableSystemVersion => 'Версия системы';

  @override
  String get assistantEditVariableDeviceInfo => 'Информация об устройстве';

  @override
  String get assistantEditVariableBatteryLevel => 'Уровень заряда';

  @override
  String get assistantEditVariableNickname => 'Имя пользователя';

  @override
  String get assistantEditVariableAssistantName => 'Имя ассистента';

  @override
  String get assistantEditMessageTemplateTitle => 'Шаблон сообщения';

  @override
  String get assistantEditVariableRole => 'Роль';

  @override
  String get assistantEditVariableMessage => 'Сообщение';

  @override
  String get assistantEditPreviewTitle => 'Предпросмотр';

  @override
  String get assistantEditPromptTimeVarWarning =>
      'Использование переменных времени в системном промпте делает начало каждого запроса разным, поэтому кэширование промпта не срабатывает, а затраты и время до первого токена растут. Если модели нужно знать текущее время, используйте переключатель «Добавлять текущее время» ниже.';

  @override
  String get assistantEditPromptIso8601Title => 'Использовать формат ISO 8601';

  @override
  String get assistantEditPromptIso8601Subtitle =>
      'Включать смещение часового пояса, например 2026-08-08T14:30:05+08:00';

  @override
  String get assistantEditPromptAppendTimeTitle => 'Добавлять текущее время';

  @override
  String get assistantEditPromptAppendTimeSubtitle =>
      'Добавлять время отправки в конец каждого сообщения пользователя. Время остаётся в конце запроса, поэтому кэширование промпта не затрагивается.';

  @override
  String get assistantEditPromptAppendTimeInfoTitle =>
      'Формат добавляемого времени';

  @override
  String assistantEditPromptAppendTimeInfoBody(String example) {
    return 'Если включено, в конец каждого сообщения пользователя добавляется пустая строка, а затем следующий тег:\n\n$example\n\nВременная метка — это время отправки самого сообщения, поэтому она не меняется при повторной попытке.';
  }

  @override
  String get assistantEditPromptAppendTimeInfoClose => 'Понятно';

  @override
  String get assistantEditPromptTimeVarDialogTitle =>
      'Системный промпт содержит переменные времени';

  @override
  String assistantEditPromptTimeVarDialogBody(String variables) {
    return 'В вашем системном промпте используются $variables. Системный промпт заново формируется при каждом запросе, поэтому переменные времени делают начало каждого запроса разным и кэширование промпта не срабатывает. Рекомендуется удалить эти переменные и использовать «Добавлять текущее время» — оно помещает время в конец запроса и не влияет на префикс.';
  }

  @override
  String get assistantEditPromptTimeVarDialogRemove => 'Перейти к удалению';

  @override
  String get assistantEditPromptTimeVarDialogKeep => 'Всё равно включить';

  @override
  String get codeBlockPreviewButton => 'Предпросмотр';

  @override
  String get codeBlockSaveAsButton => 'Сохранить как файл';

  @override
  String get codeBlockCollapseButton => 'Свернуть';

  @override
  String get codeBlockExpandButton => 'Развернуть';

  @override
  String get codeBlockDefaultFileNameStem => 'код';

  @override
  String get markdownTableLabel => 'Таблица';

  @override
  String get markdownTableExportCsvTooltip => 'Экспорт CSV';

  @override
  String get markdownTableSaveImageTooltip => 'Сохранить в галерею';

  @override
  String get markdownTableDefaultFileNameStem => 'таблица';

  @override
  String get markdownTableCopiedCsvSnackbar =>
      'CSV скопирован. Долгое нажатие на «Копировать» копирует как изображение.';

  @override
  String get markdownTableCopiedMarkdownSnackbar => 'Таблица скопирована.';

  @override
  String codeBlockCollapsedLines(int n) {
    return '… свёрнуто строк: $n';
  }

  @override
  String get htmlPreviewNotSupportedOnLinux =>
      'Предпросмотр HTML не поддерживается в Linux';

  @override
  String get assistantEditSampleUser => 'Пользователь';

  @override
  String get assistantEditSampleMessage => 'Привет';

  @override
  String get assistantEditSampleReply => 'Здравствуйте, чем я могу помочь?';

  @override
  String get assistantEditMcpNoServersMessage => 'Нет запущенных серверов MCP';

  @override
  String get assistantEditMcpConnectedTag => 'Подключено';

  @override
  String assistantEditMcpToolsCountTag(String enabled, String total) {
    return 'Инструменты: $enabled/$total';
  }

  @override
  String get assistantEditModelUseGlobalDefault =>
      'Использовать глобальное значение по умолчанию';

  @override
  String get assistantSettingsPageTitle => 'Настройки ассистента';

  @override
  String get assistantSettingsCopyButton => 'Копировать';

  @override
  String get assistantSettingsCopySuccess => 'Ассистент скопирован';

  @override
  String get assistantSettingsCopySuffix => 'Копия';

  @override
  String get assistantCopyTitle => 'Копировать ассистента';

  @override
  String get assistantCopyDefaultHint =>
      'Выберите, что копировать, или скопируйте всё.';

  @override
  String get assistantCopyConfiguration => 'Конфигурация ассистента';

  @override
  String get assistantCopyConfigurationHint =>
      'Всегда включаются: имя, аватар, промпты, модель, параметры и предварительно заданные сообщения.';

  @override
  String get assistantCopyMemories => 'Память ассистента';

  @override
  String get assistantCopyMemoriesHint =>
      'Включает текущую и устаревшую память с сохранением статуса архива. Глобальная память остаётся общей.';

  @override
  String get assistantCopyChooseMemories => 'Выбрать воспоминания';

  @override
  String get assistantCopyChooseEntries => 'Выбрать записи';

  @override
  String get assistantCopyPhrasesHint =>
      'Копировать фразы этого ассистента. Глобальные фразы остаются общими.';

  @override
  String get assistantCopyBindingsHint =>
      'Эти параметры используют существующие ресурсы; файлы рабочей области не копируются. Невыбранные мировые книги и инъекции используют глобальные настройки по умолчанию.';

  @override
  String get assistantCopyWorldBooks => 'Привязки мировых книг';

  @override
  String get assistantCopySkills => 'Выбор навыков';

  @override
  String get assistantCopyTools => 'Настройки инструментов и поиска';

  @override
  String get assistantCopyWorkspace => 'Привязка рабочей области по умолчанию';

  @override
  String get assistantCopyAll => 'Копировать всё';

  @override
  String get assistantCopyInProgress => 'Копирование…';

  @override
  String get assistantCopyFailed =>
      'Не удалось скопировать ассистента. Исходные данные не изменены. Попробуйте ещё раз.';

  @override
  String get assistantCopyMemoryLoadFailed =>
      'Не удалось загрузить воспоминания. Попробуйте ещё раз.';

  @override
  String get assistantCopyRetry => 'Повторить';

  @override
  String get assistantCopyNoMemories =>
      'У этого ассистента нет личных воспоминаний для копирования.';

  @override
  String get assistantCopySelectAll => 'Выбрать все воспоминания';

  @override
  String get assistantSettingsDeleteButton => 'Удалить';

  @override
  String get assistantSettingsEditButton => 'Изменить';

  @override
  String get assistantSettingsAddSheetTitle => 'Имя ассистента';

  @override
  String get assistantSettingsAddSheetHint => 'Введите имя';

  @override
  String get assistantSettingsAddSheetCancel => 'Отмена';

  @override
  String get assistantSettingsAddSheetSave => 'Сохранить';

  @override
  String get desktopAssistantsListTitle => 'Ассистенты';

  @override
  String get desktopSidebarTabAssistants => 'Ассистенты';

  @override
  String get desktopSidebarTabTopics => 'Темы';

  @override
  String get desktopTrayMenuShowWindow => 'Показать окно';

  @override
  String get desktopTrayMenuExit => 'Выход';

  @override
  String get hotkeyToggleAppVisibility => 'Показать/скрыть приложение';

  @override
  String get hotkeyCloseWindow => 'Закрыть окно';

  @override
  String get hotkeyOpenSettings => 'Открыть настройки';

  @override
  String get hotkeyNewTopic => 'Новая тема';

  @override
  String get hotkeySwitchModel => 'Сменить модель';

  @override
  String get hotkeyToggleAssistantPanel => 'Переключить ассистентов';

  @override
  String get hotkeyToggleTopicPanel => 'Переключить темы';

  @override
  String get hotkeysPressShortcut => 'Нажмите сочетание клавиш';

  @override
  String get hotkeysResetDefault => 'Сбросить по умолчанию';

  @override
  String get hotkeysClearShortcut => 'Очистить сочетание';

  @override
  String get hotkeysResetAll => 'Сбросить все по умолчанию';

  @override
  String get assistantEditTemperatureTitle => 'Температура';

  @override
  String get assistantEditTopPTitle => 'Top-p';

  @override
  String get assistantSettingsDeleteDialogTitle => 'Удалить ассистента';

  @override
  String get assistantSettingsDeleteDialogContent =>
      'Вы уверены, что хотите удалить этого ассистента? Это действие нельзя отменить.';

  @override
  String get assistantSettingsDeleteDialogCancel => 'Отмена';

  @override
  String get assistantSettingsDeleteDialogConfirm => 'Удалить';

  @override
  String get assistantSettingsAtLeastOneAssistantRequired =>
      'Требуется хотя бы один ассистент';

  @override
  String get assistantConversationMcpTitle => 'Разрешить MCP для каждого чата';

  @override
  String get assistantConversationMcpHint =>
      'Позволяет чатам выбирать собственные MCP-серверы. Пока не настроено, чаты используют выбор ассистента.';

  @override
  String get mcpSelectionInherited => 'Как у ассистента';

  @override
  String get mcpSelectionCustom => 'Свой выбор для этого чата';

  @override
  String get mcpInheritAssistant => 'Использовать настройки ассистента';

  @override
  String get mcpAssistantSheetTitle => 'MCP-серверы';

  @override
  String get mcpAssistantSheetSubtitle =>
      'Серверы, включённые для этого ассистента';

  @override
  String get mcpAssistantSheetSelectAll => 'Выбрать все';

  @override
  String get mcpAssistantSheetClearAll => 'Снять выбор';

  @override
  String get backupPageTitle => 'Резервное копирование и восстановление';

  @override
  String get backupPageWebDavTab => 'WebDAV';

  @override
  String get backupPageImportExportTab => 'Импорт/экспорт';

  @override
  String get backupPageWebDavServerUrl => 'URL сервера WebDAV';

  @override
  String get backupPageUsername => 'Имя пользователя';

  @override
  String get backupPagePassword => 'Пароль';

  @override
  String get backupPagePath => 'Путь';

  @override
  String get backupPageChatsLabel => 'Чаты';

  @override
  String get backupPageFilesDescription =>
      'Вложения чатов, аватары, фоны и пользовательские шрифты. Чтобы восстановить аватары или фоны, также выберите соответствующих ассистентов, провайдеров или настройки.';

  @override
  String get backupPageChooseBackupFolder =>
      'Выберите папку для резервной копии';

  @override
  String get backupPageChooseExternalFolder =>
      'Выберите iCloud Drive или папку вне «На моём iPhone > Kelivo». Файлы в папке Kelivo удаляются вместе с приложением. Резервная копия не сохранена.';

  @override
  String get backupPageFilesLabel => 'Файлы и изображения';

  @override
  String get backupPageScopeTitle => 'Содержимое резервной копии и импорта';

  @override
  String backupPageScopeSelectedCount(int selected, int total) {
    return '$selected/$total';
  }

  @override
  String get backupPageBackupManagementDescription =>
      'Выберите, что копировать и импортировать. Применяется к локальным, WebDAV и S3 резервным копиям. Невыбранное содержимое при импорте остаётся без изменений. Навыки и рабочие области включают собственные файлы.';

  @override
  String get backupPageAssistantsLabel => 'Ассистенты';

  @override
  String get backupPageProvidersLabel => 'Провайдеры';

  @override
  String get backupPageMcpLabel => 'MCP-серверы';

  @override
  String get backupPageEnvironmentVariablesLabel => 'Переменные окружения';

  @override
  String get backupPageSkillsLabel => 'Навыки';

  @override
  String get backupPageWorldBooksLabel => 'Миры';

  @override
  String get backupPageMemoriesLabel => 'Воспоминания';

  @override
  String get backupPageQuickPhrasesLabel => 'Быстрые фразы';

  @override
  String get backupPageInstructionsLabel => 'Внедрения промптов';

  @override
  String get backupPageWorkspacesLabel => 'Рабочие области';

  @override
  String get backupPageSearchServicesLabel => 'Сервисы поиска';

  @override
  String get backupPageSpeechServicesLabel => 'Сервисы речи';

  @override
  String get backupPageSettingsLabel => 'Прочие настройки';

  @override
  String get backupPageTestDone => 'Проверка завершена';

  @override
  String get backupPageTestConnection => 'Проверить';

  @override
  String get backupPageRestartRequired => 'Требуется перезапуск';

  @override
  String get backupPageRestartContent =>
      'Импорт выполнен. Перезапустите Kelivo, чтобы безопасно применить изменения.';

  @override
  String backupPageRestartContentWithSkipped(int count) {
    return 'Импорт завершён, но пропущено чатов с недопустимым порядком сообщений: $count. Перезапустите Kelivo, чтобы безопасно применить импортированные данные.';
  }

  @override
  String get restartAppFailedMessage =>
      'Kelivo не удалось перезапустить автоматически. Полностью закройте приложение и откройте его снова.';

  @override
  String get backupRestoreRolledBackTitle => 'Восстановление отменено';

  @override
  String get backupRestoreRolledBackContent =>
      'Восстановление не удалось завершить. Kelivo проверил и сохранил ваши прежние данные.';

  @override
  String get backupRestoreDirectoryBlockedTitle =>
      'Восстановление ожидает освобождения папки';

  @override
  String get backupRestoreDirectoryBlockedContent =>
      'Windows не удалось переместить папку ниже. Закройте терминалы, редакторы и другие программы, использующие её, затем продолжите восстановление. Если папка всё ещё заблокирована, проверьте, что ваша учётная запись может её перемещать. Прогресс восстановления сохранён.';

  @override
  String get backupRestoreContinueButton => 'Продолжить восстановление';

  @override
  String get backupRestoreFailureTitle => 'Восстановление требует внимания';

  @override
  String get backupRestoreFailureContent =>
      'Kelivo не удалось проверить полноту старых или новых данных, поэтому данные чатов не были открыты. Закройте Kelivo и повторите попытку. Если проблема повторяется, сохраните диагностический код для поддержки.';

  @override
  String get backupRestoreBusinessLeaseUnavailableTitle => 'Kelivo уже запущен';

  @override
  String get backupRestoreBusinessLeaseUnavailableContent =>
      'Данные Kelivo всё ещё используются другим процессом приложения. Закройте другие окна Kelivo и перезапустите. Этот процесс не открывал данные чатов.';

  @override
  String get restoreProgressTitle => 'Восстановление резервной копии';

  @override
  String get restoreProgressWarning =>
      'Не закрывайте Kelivo до завершения. Если закрыть его сейчас, при следующем запуске восстановление начнётся заново.';

  @override
  String get restoreProgressStageCheckingBackup => 'Проверка резервной копии';

  @override
  String get restoreProgressStagePreservingCurrentData =>
      'Сохранение текущих данных';

  @override
  String get restoreProgressStageInstallingBackup =>
      'Установка резервной копии';

  @override
  String get restoreProgressStageVerifying => 'Проверка';

  @override
  String get restoreProgressStageRollingBack =>
      'Восстановление предыдущих данных';

  @override
  String get restoreProgressStageFinishing => 'Завершение';

  @override
  String get backupRestoreFailureRestartButton => 'Перезапустить Kelivo';

  @override
  String get backupRestoreFailureCopyButton => 'Копировать диагностический код';

  @override
  String get backupRestoreFailureCopied => 'Диагностический код скопирован';

  @override
  String backupRestoreFailureDiagnostic(String code) {
    return 'Диагностический код: $code';
  }

  @override
  String get startupRecoveryMoreOptions => 'Другие варианты восстановления';

  @override
  String get startupRecoveryRepairButton => 'Исправить и перезапустить';

  @override
  String get startupRecoveryExportButton => 'Экспортировать копию моих данных';

  @override
  String get startupRecoveryResetButton => 'Начать с пустого списка чатов';

  @override
  String get startupRecoveryBusy => 'Выполняется…';

  @override
  String get startupRecoveryExportSucceeded => 'Копия ваших данных сохранена.';

  @override
  String get startupRecoveryExportFailed =>
      'Не удалось экспортировать копию ваших данных.';

  @override
  String get startupRecoveryRepairFailed =>
      'Не удалось завершить исправление. Ваши данные сохранены; выберите проверенную копию или экспортируйте данные для дальнейшей диагностики.';

  @override
  String get startupRecoveryResetFailed =>
      'Не удалось выполнить сброс. Полностью закройте Kelivo и откройте его снова.';

  @override
  String get startupRecoveryResetDialogTitle =>
      'Начать с пустого списка чатов?';

  @override
  String get startupRecoveryResetDialogContent =>
      'Это не восстановит ваши предыдущие чаты. Kelivo сохранит текущую базу данных и существующие копии и создаст новый пустой список чатов. Чтобы вернуть чаты, отмените действие и выберите локальную копию.';

  @override
  String get startupRecoveryResetDialogConfirm =>
      'Сохранить копии и начать заново';

  @override
  String get startupRecoveryResetDialogCancel => 'Отмена';

  @override
  String get startupRecoveryWhatFailed => 'Что не удалось';

  @override
  String get startupRecoveryStageLabel => 'Этап';

  @override
  String get startupRecoveryStageRestore => 'Этап восстановления';

  @override
  String get startupRecoveryStageDatabase => 'Запуск базы данных';

  @override
  String get startupRecoveryDiagnosticLabel => 'Диагностический код';

  @override
  String get startupRecoverySchemaLabel => 'Версия базы данных';

  @override
  String startupRecoverySchemaValue(String installed, int expected) {
    return '$installed на диске · $expected требуется этой сборкой';
  }

  @override
  String get startupRecoveryAppVersionLabel => 'Приложение';

  @override
  String get startupRecoveryUnknownValue => 'неизвестно';

  @override
  String get startupRecoveryCollecting => 'Сбор диагностических данных…';

  @override
  String get startupRecoveryShowDetails => 'Показать технические подробности';

  @override
  String get startupRecoveryHideDetails => 'Скрыть технические подробности';

  @override
  String get startupRecoveryCopyReport => 'Копировать полный отчёт';

  @override
  String get startupRecoveryReportCopied => 'Полный отчёт скопирован';

  @override
  String get startupRecoveryShareReport => 'Экспортировать отчёт';

  @override
  String startupRecoveryReportStored(String path) {
    return 'Копия этого отчёта сохранена в $path';
  }

  @override
  String startupRecoveryReportSaved(String path) {
    return 'Отчёт сохранён в $path';
  }

  @override
  String get startupRecoveryReportShared => 'Отчёт экспортирован.';

  @override
  String get startupRecoveryReportSaveFailed =>
      'Не удалось экспортировать отчёт.';

  @override
  String get startupRecoverySectionDataTitle => 'Ваши данные';

  @override
  String get startupRecoverySectionDataBody =>
      'Вы также можете экспортировать оставшиеся данные и сохранить их в надёжном месте, прежде чем продолжить.';

  @override
  String startupRecoveryExportSavedTo(String path) {
    return 'Копия ваших данных сохранена в $path';
  }

  @override
  String get startupRecoverySectionRepairTitle => 'Диагностика и исправление';

  @override
  String get startupRecoverySectionRepairBody =>
      'Проверка целостности только читает базу данных. Исправление очищает оставшиеся метаданные прерванного обновления и повторяет запуск; оно никогда не удаляет чаты.';

  @override
  String get startupRecoveryIntegrityButton =>
      'Проверить целостность базы данных';

  @override
  String get startupRecoveryIntegrityHealthy =>
      'SQLite не обнаружил повреждений в файле базы данных.';

  @override
  String startupRecoveryIntegrityDamaged(String detail) {
    return 'SQLite сообщил о проблемах — $detail';
  }

  @override
  String get startupRecoveryIntegrityMissing =>
      'В папке данных не найден файл базы данных.';

  @override
  String get startupRecoveryIntegrityFailed =>
      'Не удалось выполнить проверку целостности.';

  @override
  String get startupRecoveryDangerZone => 'Другие варианты';

  @override
  String get startupRecoveryDangerBody =>
      'Новый старт скрывает текущие данные из вида. Kelivo сохранит старую базу данных и существующие копии для восстановления. Если возможно, сначала экспортируйте копию данных.';

  @override
  String get startupRecoveryResetAcknowledge =>
      'Я выбираю продолжить с пустым списком чатов, не восстанавливая чаты сейчас.';

  @override
  String get startupDatabaseUpdateRequiredTitle =>
      'Обновите Kelivo, чтобы продолжить';

  @override
  String get startupDatabaseUpdateRequiredContent =>
      'База данных чатов на этом устройстве была создана более новой версией Kelivo, и эта версия не может её открыть. Ваши данные не изменены. Установите последнюю версию Kelivo и откройте её снова.';

  @override
  String get startupDatabaseUpdateRequiredDowngradeTitle =>
      'Если вам нужна более старая версия';

  @override
  String get startupDatabaseUpdateRequiredDowngradeIntro =>
      'Эта версия не может открыть базу данных на этом устройстве. Если вам необходимо остаться на более старой версии, выполните шаги ниже. Не удаляйте и не перезаписывайте данные здесь, пока не сделаете резервную копию.';

  @override
  String get startupDatabaseUpdateRequiredDowngradeStep1 =>
      'Установите и откройте последнюю версию Kelivo, затем экспортируйте резервную копию в разделе «Настройки → Резервная копия».';

  @override
  String startupDatabaseUpdateRequiredDowngradeStep2(String url) {
    return 'Откройте $url и преобразуйте эту резервную копию в формат более старой версии, которую вы хотите использовать.';
  }

  @override
  String get startupDatabaseUpdateRequiredDowngradeStep3 =>
      'После того как вы убедитесь, что данные на этом устройстве сохранены в резервной копии, установите более старую версию и импортируйте преобразованную резервную копию.';

  @override
  String get startupDatabaseUpdateRequiredOpenTool =>
      'Открыть инструмент преобразования';

  @override
  String backupPageRestoreFailedMessage(String error) {
    return 'Не удалось восстановить: $error';
  }

  @override
  String backupPageExportFailedMessage(String error) {
    return 'Не удалось экспортировать: $error';
  }

  @override
  String get backupPageOK => 'ОК';

  @override
  String get backupPageCancel => 'Отмена';

  @override
  String get backupPageSelectImportMode => 'Выберите режим импорта';

  @override
  String get backupPageSelectImportModeDescription =>
      'Выберите режим восстановления. Переключатели в управлении резервными копиями применяются к этому импорту.';

  @override
  String get backupPageOverwriteMode => 'Полная перезапись';

  @override
  String get backupPageOverwriteModeDescription =>
      'Заменить выбранные компоненты; сохранить невыбранные компоненты и несвязанные локальные настройки. При замене чатов также очищаются локальные неотправленные черновики.';

  @override
  String get backupPageMergeMode => 'Объединение';

  @override
  String get backupPageMergeModeDescription =>
      'Сохранить локальные данные и добавить данные из резервной копии. Идентичные чаты пропускаются, а конфликтующим чатам назначаются новые ID.';

  @override
  String get backupPageRestore => 'Восстановить';

  @override
  String get backupPageForwardCompatTitle =>
      'Резервная копия создана более новой версией';

  @override
  String backupPageForwardCompatBody(int backupVersion, int currentVersion) {
    return 'Эта резервная копия создана более новой версией Kelivo (формат данных $backupVersion; эта версия поддерживает $currentVersion), и в ней не указано, могут ли её читать более старые версии.\n\nВы можете продолжить: всё, что эта версия не распознаёт, будет пропущено, а сам файл резервной копии не изменяется. Но если более новая версия изменила способ хранения существующих данных, часть содержимого может быть импортирована неправильно.\n\nБезопаснее сначала обновить Kelivo.';
  }

  @override
  String get backupPageForwardCompatContinue => 'Всё равно импортировать';

  @override
  String get backupPageForwardCompatCancel => 'Отмена';

  @override
  String get backupPageSchemaTooNewMessage =>
      'Эта резервная копия создана более новой версией Kelivo, и эта версия не может её прочитать. Обновите Kelivo и повторите попытку.';

  @override
  String get backupPageBackupUploaded => 'Резервная копия загружена';

  @override
  String get backupPageBackup => 'Создать резервную копию';

  @override
  String get backupPageExporting => 'Экспорт...';

  @override
  String get backupProgressCancel => 'Отмена';

  @override
  String get backupProgressCancelled => 'Отменено';

  @override
  String get backupProgressFailed => 'Операция не выполнена';

  @override
  String backupProgressFailedAt(String phase) {
    return 'Ошибка на этапе: $phase';
  }

  @override
  String get backupProgressCopyError => 'Копировать ошибку';

  @override
  String get backupProgressErrorCopied => 'Ошибка скопирована';

  @override
  String get backupProgressPreparing => 'Подготовка';

  @override
  String get backupProgressSnapshotting => 'Создание снимка базы данных';

  @override
  String get backupProgressPacking => 'Упаковка';

  @override
  String get backupProgressVerifying => 'Проверка';

  @override
  String get backupProgressUploading => 'Загрузка';

  @override
  String get backupProgressDownloading => 'Скачивание';

  @override
  String get backupProgressExtracting => 'Распаковка';

  @override
  String get backupProgressValidating => 'Валидация';

  @override
  String get backupProgressReadingSettings => 'Чтение настроек';

  @override
  String get backupProgressStaging => 'Подготовка данных';

  @override
  String get backupProgressCommitting => 'Фиксация';

  @override
  String get backupProgressImportingSessions => 'Импорт сеансов';

  @override
  String get backupProgressImportingMessages => 'Импорт сообщений';

  @override
  String get backupProgressMaterializingFiles => 'Запись файлов';

  @override
  String get backupProgressListingRemote =>
      'Получение списка удалённых резервных копий';

  @override
  String get backupProgressFinalizing => 'Завершение';

  @override
  String backupProgressBytes(String done, String total) {
    return '$done / $total';
  }

  @override
  String backupProgressItems(String done, String total) {
    return '$done / $total';
  }

  @override
  String get backupPageExportToFile => 'Создать резервную копию';

  @override
  String get backupPageExportToFileSubtitle =>
      'Сохранить выбранное содержимое в файл резервной копии';

  @override
  String get backupPageImportBackupFile => 'Импорт файла резервной копии';

  @override
  String get backupPageImportBackupFileSubtitle =>
      'Импорт локального файла резервной копии';

  @override
  String get backupPageImportFromOtherApps => 'Импорт из других приложений';

  @override
  String get backupPageNotSupportedYet => 'Пока не поддерживается';

  @override
  String get backupPageRemoteBackups => 'Удалённые резервные копии';

  @override
  String get backupPageNoBackups => 'Нет резервных копий';

  @override
  String get backupPageRestoreTooltip => 'Восстановить';

  @override
  String get backupPageDeleteTooltip => 'Удалить';

  @override
  String get backupPageDeleteConfirmTitle => 'Подтверждение удаления';

  @override
  String backupPageDeleteConfirmContent(Object name) {
    return 'Вы уверены, что хотите удалить удалённую резервную копию «$name»? Это действие нельзя отменить.';
  }

  @override
  String get backupPageBackupManagement => 'Управление резервными копиями';

  @override
  String get backupPageWebDavBackup => 'Резервное копирование WebDAV';

  @override
  String get backupPageWebDavServerSettings => 'Настройки сервера WebDAV';

  @override
  String get backupPageS3Backup => 'Резервное копирование S3';

  @override
  String get backupPageS3ServerSettings => 'Настройки S3';

  @override
  String get backupPageS3Endpoint => 'Endpoint';

  @override
  String get backupPageS3Region => 'Регион';

  @override
  String get backupPageS3Bucket => 'Bucket';

  @override
  String get backupPageS3AccessKeyId => 'Access Key ID';

  @override
  String get backupPageS3SecretAccessKey => 'Secret Access Key';

  @override
  String get backupPageS3SessionToken => 'Session Token (необязательно)';

  @override
  String get backupPageS3Prefix => 'Префикс';

  @override
  String get backupPageS3PathStyle => 'Адресация в стиле пути (path-style)';

  @override
  String get backupPageUserAgent => 'User-Agent';

  @override
  String get backupPageUserAgentHint => 'Необязательно';

  @override
  String get backupPageSave => 'Сохранить';

  @override
  String get backupPageBackupNow => 'Создать резервную копию';

  @override
  String get backupPageLocalBackup => 'Локальная резервная копия';

  @override
  String get backupPageIosSystemBackupNote =>
      'Локальные данные Kelivo не включаются в резервные копии устройств iCloud. Перед сменой устройства или удалением приложения сохраните резервную копию в iCloud Drive или другую папку вне Kelivo. Файлы в «На моём iPhone > Kelivo» удаляются вместе с приложением.';

  @override
  String get backupPageImportFromCherryStudio => 'Импорт из Cherry Studio';

  @override
  String backupPageCherryStudioUnsupportedBackupVersion(String version) {
    return 'Эта резервная копия использует версию формата Cherry Studio $version, которую Kelivo пока не может импортировать. Экспортируйте резервную копию из Cherry Studio v1 или дождитесь обновления Kelivo с поддержкой резервных копий Cherry Studio v2.';
  }

  @override
  String get backupPageImportFromChatbox => 'Импорт из Chatbox';

  @override
  String get webDavScheduleTitle =>
      'Резервное копирование на WebDAV по расписанию';

  @override
  String get webDavScheduleEnabled => 'Автоматическое резервное копирование';

  @override
  String get webDavScheduleInterval => 'Интервал повторения';

  @override
  String get webDavScheduleWifiOnly => 'Только Wi-Fi / Ethernet';

  @override
  String get webDavScheduleWifiOnlyHint =>
      'Использовать Wi-Fi или Ethernet для загрузки. Фоновые резервные копии на Android также ожидают подключения без лимита трафика.';

  @override
  String get webDavScheduleAndroidHint =>
      'Android создаёт резервные копии в фоне. Ограничения батареи и сети могут задержать запуск. Принудительная остановка приложения приостанавливает копирование до следующего открытия.';

  @override
  String get webDavScheduleForegroundHint =>
      'Резервные копии создаются, пока приложение открыто. Пропущенные задания выполняются при возвращении в приложение.';

  @override
  String get webDavScheduleConfigureFirst =>
      'Перед включением автоматического резервного копирования настройте и сохраните сервер WebDAV.';

  @override
  String get webDavScheduleLastSuccess => 'Последняя успешная резервная копия';

  @override
  String get webDavScheduleNextRun => 'Следующая резервная копия (примерно)';

  @override
  String get webDavScheduleStatus => 'Статус';

  @override
  String get webDavScheduleRunNow => 'Создать копию сейчас';

  @override
  String get webDavScheduleRunning => 'Создание резервной копии…';

  @override
  String get webDavScheduleFinishingBackgroundBackup =>
      'Завершение фонового резервного копирования…';

  @override
  String get webDavScheduleReady =>
      'Ожидание следующего резервного копирования';

  @override
  String get webDavScheduleFailed =>
      'Последнее резервное копирование не удалось';

  @override
  String get webDavScheduleDisabled => 'Отключено';

  @override
  String get webDavScheduleNotConfigured => 'Сервер WebDAV не настроен';

  @override
  String webDavScheduleEveryHours(int hours) {
    String _temp0 = intl.Intl.pluralLogic(
      hours,
      locale: localeName,
      other: 'Каждые $hours часа',
      many: 'Каждые $hours часов',
      few: 'Каждые $hours часа',
      one: 'Каждый $hours час',
    );
    return '$_temp0';
  }

  @override
  String get webDavScheduleEveryDay => 'Каждый день';

  @override
  String get webDavScheduleNever => 'Никогда';

  @override
  String get webDavScheduleDue => 'Когда позволят условия';

  @override
  String get webDavScheduleSaved =>
      'Расписание резервного копирования сохранено';

  @override
  String get webDavScheduleSaveFailed =>
      'Не удалось сохранить расписание резервного копирования';

  @override
  String get webDavScheduleSucceeded => 'Резервная копия загружена';

  @override
  String get webDavScheduleUnavailable => 'Фоновое планирование недоступно';

  @override
  String get webDavScheduleWifiRequired => 'Ожидание Wi-Fi или Ethernet';

  @override
  String get webDavScheduleNetworkUnavailable => 'Ожидание подключения к сети';

  @override
  String get webDavScheduleBackupBusy =>
      'Выполняется другое резервное копирование или восстановление';

  @override
  String get webDavScheduleRetry => 'Ожидание повторной попытки';

  @override
  String get webDavScheduleTimedOut => 'Время резервного копирования истекло';

  @override
  String get webDavSchedulePasswordRequired =>
      'Для зашифрованной резервной копии требуется подтверждение пароля. Создайте копию на WebDAV вручную или отключите шифрование для резервного копирования по расписанию.';

  @override
  String get webDavScheduleCancelled => 'Резервное копирование отменено';

  @override
  String get backupReminderSectionTitle =>
      'Напоминание о резервном копировании';

  @override
  String get backupReminderEnableTitle =>
      'Напоминать мне о резервном копировании';

  @override
  String get backupReminderFrequencyTitle => 'Частота';

  @override
  String get backupReminderTimeTitle => 'Время напоминания';

  @override
  String get backupReminderTimeInputHint => 'HH:mm';

  @override
  String get backupReminderTimeInvalid => 'Введите время от 00:00 до 23:59.';

  @override
  String get backupReminderLastBackupTitle => 'Последняя резервная копия';

  @override
  String get backupReminderNextReminderTitle => 'Следующее напоминание';

  @override
  String get backupReminderNever => 'Никогда';

  @override
  String get backupReminderDisabled => 'Выкл.';

  @override
  String get backupReminderDueNow => 'Пора сейчас';

  @override
  String get backupReminderEveryDay => 'Каждый день';

  @override
  String get backupReminderEveryThreeDays => 'Каждые 3 дня';

  @override
  String get backupReminderEveryWeek => 'Каждую неделю';

  @override
  String get backupReminderEveryFourteenDays => 'Каждые 14 дней';

  @override
  String get backupReminderEveryMonth => 'Каждый месяц';

  @override
  String backupReminderCustomDays(int days) {
    return 'Каждые $days дн.';
  }

  @override
  String get backupReminderCustomOption => 'Другой интервал...';

  @override
  String get backupReminderCustomDialogTitle => 'Свой интервал';

  @override
  String get backupReminderCustomDialogDescription =>
      'Укажите, через сколько дней напоминать о резервной копии.';

  @override
  String get backupReminderCustomDaysLabel => 'Дней';

  @override
  String get backupReminderCustomDaysInvalid => 'Введите число от 1 до 365.';

  @override
  String get backupReminderSidebarTitle => 'Напоминание о резервной копии';

  @override
  String get backupReminderSidebarSubtitle =>
      'Подошёл срок создания резервной копии.';

  @override
  String get backupReminderSidebarAction => 'Перейти к резервной копии';

  @override
  String get backupReminderSnoozeTooltip => 'Напомнить позже';

  @override
  String get chatHistoryPageTitle => 'История чатов';

  @override
  String get chatHistoryPageSearchTooltip => 'Поиск';

  @override
  String get chatHistoryPageDeleteAllTooltip => 'Удалить незакреплённые';

  @override
  String get chatHistoryPageDeleteAllDialogTitle =>
      'Удалить незакреплённые чаты';

  @override
  String get chatHistoryPageDeleteAllDialogContent =>
      'Удалить все незакреплённые чаты этого ассистента? Закреплённые чаты останутся.';

  @override
  String get chatHistoryPageCancel => 'Отмена';

  @override
  String get chatHistoryPageDelete => 'Удалить';

  @override
  String get chatHistoryPageDeletedAllSnackbar => 'Незакреплённые чаты удалены';

  @override
  String get chatHistoryPageSearchHint => 'Поиск чатов';

  @override
  String get chatHistoryPageNoConversations => 'Нет чатов';

  @override
  String get chatHistoryPagePinnedSection => 'Закреплённые';

  @override
  String get chatHistoryPagePin => 'Закрепить';

  @override
  String get chatHistoryPagePinned => 'Закреплено';

  @override
  String get messageEditPageTitle => 'Редактировать сообщение';

  @override
  String get messageEditPageSave => 'Сохранить';

  @override
  String get messageEditPageSaveAndSend => 'Сохранить и отправить';

  @override
  String get messageEditPageHint => 'Введите сообщение…';

  @override
  String get userMessageEditSaveOnly => 'Только сохранить';

  @override
  String get userMessageEditUnsupportedSnackbar =>
      'Это содержимое нельзя редактировать';

  @override
  String get userMessageEditOverwriteTitle => 'Уведомление';

  @override
  String get userMessageEditOverwriteContent =>
      'Изменения перезапишут текущий ввод. Перезаписать?';

  @override
  String get selectCopyPageTitle => 'Выбрать и скопировать';

  @override
  String get selectCopyPageCopyAll => 'Копировать всё';

  @override
  String get selectCopyPageCopiedAll => 'Всё скопировано';

  @override
  String get bottomToolsSheetCamera => 'Камера';

  @override
  String get bottomToolsSheetPhotos => 'Фото';

  @override
  String get bottomToolsSheetUpload => 'Загрузить файл';

  @override
  String get bottomToolsSheetClearContext => 'Очистить контекст';

  @override
  String get compressContext => 'Сжать контекст';

  @override
  String get compressContextDesc =>
      'Сожмите раннюю часть чата в сводку. Оригиналы останутся в чате, и вы сможете отменить это в любой момент.';

  @override
  String get clearContextDesc =>
      'Начните заново с этого места: ранние сообщения останутся в чате, но не будут отправляться модели.';

  @override
  String get contextManagement => 'Управление контекстом';

  @override
  String get compressContextFailed => 'Сжатие не завершилось';

  @override
  String get compressContextNoMessages => 'В этом чате нечего сжимать.';

  @override
  String get compressContextNoConversation => 'Нет беседы для сжатия.';

  @override
  String get compressContextNoModel =>
      'Модель для сжатия не выбрана. Выберите быструю в настройках.';

  @override
  String get compressContextEmptySummary =>
      'Модель не создала сводку. Попробуйте другую модель или измените параметры и повторите попытку.';

  @override
  String get compressContextOptionsTitle => 'Сжать контекст';

  @override
  String get compressContextOptionsDesc =>
      'Превратите ранние сообщения в сводку — именно её модель увидит в следующий раз. Оригинальный чат сохраняется; сводку можно изменить или отменить.';

  @override
  String get compressContextKeepStart => 'Ранняя история';

  @override
  String get compressContextKeepRecent => 'Недавняя история';

  @override
  String get compressContextUnlimited => 'Вся активная история';

  @override
  String get compressContextMaxCharsLabel => 'Символы';

  @override
  String get compressContextInvalidLimit =>
      'Введите положительное число символов';

  @override
  String get compressContextStartButton => 'Сжать';

  @override
  String get compressContextModelLabel => 'Модель';

  @override
  String get compressContextModelUnset => 'Выберите модель';

  @override
  String get compressContextKeepRecentMessages => 'Сохранять недавние ходы';

  @override
  String get compressContextKeepCountLabel =>
      'Сколько последних сообщений пользователя сохранить';

  @override
  String get compressContextKeepAllMessages =>
      'Это количество последних сообщений уже охватывает весь чат, поэтому сжимать нечего.';

  @override
  String compressContextEstimatePreview(
    int summarized,
    int kept,
    int minTokens,
    int maxTokens,
    int totalTokens,
  ) {
    return 'Будет суммировано $summarized символов, сохранено без изменений $kept. После сжатия примерно $minTokens–$maxTokens токенов (исходно примерно $totalTokens).';
  }

  @override
  String get bottomToolsSheetLearningMode => 'Режим обучения';

  @override
  String get bottomToolsSheetLearningModeDescription =>
      'Помогает учиться шаг за шагом';

  @override
  String get bottomToolsSheetConfigurePrompt => 'Настроить промпт';

  @override
  String get bottomToolsSheetPrompt => 'Промпт';

  @override
  String get bottomToolsSheetPromptHint =>
      'Введите текст промпта для внедрения';

  @override
  String get bottomToolsSheetResetDefault => 'Сбросить по умолчанию';

  @override
  String get bottomToolsSheetSave => 'Сохранить';

  @override
  String get bottomToolsSheetOcr => 'OCR изображений';

  @override
  String get messageMoreSheetTitle => 'Другие действия';

  @override
  String get messageMoreSheetSelectCopy => 'Выбрать и скопировать';

  @override
  String get messageMoreSheetRenderWebView => 'Отобразить веб-представление';

  @override
  String get messageMoreSheetNotImplemented => 'Пока не реализовано';

  @override
  String get messageMoreSheetEdit => 'Изменить';

  @override
  String get messageMoreSheetShare => 'Поделиться';

  @override
  String get messageMoreSheetSelectMessages => 'Выбрать сообщения';

  @override
  String get messageMoreSheetCreateBranch => 'Создать ветку';

  @override
  String get messageMoreSheetDelete => 'Удалить эту версию';

  @override
  String get messageMoreSheetDeleteAllVersions => 'Удалить все версии';

  @override
  String get reasoningBudgetSheetTitle => 'Интенсивность цепочки рассуждений';

  @override
  String get reasoningLevelSheetTitle => 'Рассуждение';

  @override
  String get reasoningLevelAuto => 'Авто';

  @override
  String get reasoningLevelAutoSubtitle =>
      'Использует настройки по умолчанию модели или провайдера';

  @override
  String get reasoningLevelOff => 'Выкл.';

  @override
  String get reasoningLevelOn => 'Вкл.';

  @override
  String get reasoningLevelOnSubtitle => 'Включить рассуждение';

  @override
  String get reasoningLevelOffSubtitle =>
      'Отключить рассуждение и отвечать напрямую';

  @override
  String get reasoningLevelMinimal => 'Минимальная';

  @override
  String get reasoningLevelMinimalSubtitle =>
      'Использовать минимальное рассуждение для ответа на вопросы';

  @override
  String get reasoningLevelLow => 'Низкая';

  @override
  String get reasoningLevelLowSubtitle =>
      'Использовать небольшое рассуждение для ответа на вопросы';

  @override
  String get reasoningLevelMedium => 'Средняя';

  @override
  String get reasoningLevelMediumSubtitle =>
      'Использовать умеренное рассуждение для ответа на вопросы';

  @override
  String get reasoningLevelHigh => 'Высокая';

  @override
  String get reasoningLevelHighSubtitle =>
      'Использовать интенсивное рассуждение для сложных вопросов';

  @override
  String get reasoningLevelXhigh => 'Очень высокая';

  @override
  String get reasoningLevelXhighSubtitle =>
      'Использовать очень высокую глубину рассуждения для сложных задач';

  @override
  String get reasoningLevelMax => 'Макс.';

  @override
  String get reasoningLevelMaxSubtitle =>
      'Использовать максимальную глубину рассуждения для самых сложных задач';

  @override
  String get reasoningLevelFollowModelDefaultSubtitle =>
      'Использовать значение модели по умолчанию, если ассистент его не задаёт';

  @override
  String get reasoningLevelNoReasoning =>
      'Эта модель не поддерживает рассуждение';

  @override
  String get reasoningLevelCustomBudget => 'Свой бюджет рассуждения';

  @override
  String get reasoningLevelCustomBudgetHint => 'Бюджет токенов, например 2048';

  @override
  String get reasoningLevelCompactMin => 'min';

  @override
  String get reasoningLevelCompactLow => 'low';

  @override
  String get reasoningLevelCompactMid => 'mid';

  @override
  String get reasoningLevelCompactHigh => 'high';

  @override
  String get reasoningLevelCompactXhigh => 'xhigh';

  @override
  String get reasoningLevelCompactMax => 'max';

  @override
  String reasoningLevelBudgetTokens(String budget) {
    return '$budget токенов';
  }

  @override
  String chatMessageWidgetFileNotFound(String fileName) {
    return 'Файл не найден: $fileName';
  }

  @override
  String chatMessageWidgetCannotOpenFile(String message) {
    return 'Не удаётся открыть файл: $message';
  }

  @override
  String chatMessageWidgetOpenFileError(String error) {
    return 'Не удалось открыть файл: $error';
  }

  @override
  String get chatMessageWidgetCopiedToClipboard => 'Скопировано в буфер обмена';

  @override
  String get chatMessageWidgetResendTooltip => 'Отправить повторно';

  @override
  String get chatMessageWidgetMoreTooltip => 'Ещё';

  @override
  String get chatMessageWidgetThinking => 'Думает...';

  @override
  String get chatMessageWidgetTranslation => 'Перевод';

  @override
  String get chatMessageWidgetTranslating => 'Перевод...';

  @override
  String get chatMessageWidgetCitationNotFound => 'Источник цитаты не найден';

  @override
  String chatMessageWidgetCannotOpenUrl(String url) {
    return 'Не удаётся открыть ссылку: $url';
  }

  @override
  String get chatMessageWidgetOpenLinkError => 'Не удалось открыть ссылку';

  @override
  String get chatMessageWidgetAttachmentUnavailable => 'Вложение недоступно';

  @override
  String chatMessageWidgetCitationsTitle(int count) {
    return 'Цитаты ($count)';
  }

  @override
  String get chatMessageWidgetSearchResultsTitle => 'Результаты поиска';

  @override
  String get chatMessageWidgetCitationSourcesTitle => 'Источники цитат';

  @override
  String get chatMessageWidgetRegenerateTooltip => 'Сгенерировать заново';

  @override
  String get chatMessageWidgetRegenerateConfirmTitle =>
      'Подтвердить повторную генерацию';

  @override
  String get chatMessageWidgetRegenerateConfirmContent =>
      'Повторная генерация обновит только это сообщение и сохранит сообщения ниже. Продолжить?';

  @override
  String get chatMessageWidgetRegenerateConfirmDeleteTrailingContent =>
      'Повторная генерация удалит все сообщения ниже этого, и отменить это будет невозможно. Продолжить?';

  @override
  String get chatMessageWidgetRegenerateConfirmCancel => 'Отмена';

  @override
  String get chatMessageWidgetRegenerateConfirmOk => 'Сгенерировать заново';

  @override
  String get chatMessageWidgetStopTooltip => 'Остановить';

  @override
  String get chatMessageWidgetSpeakTooltip => 'Озвучить';

  @override
  String get chatMessageWidgetTranslateTooltip => 'Перевести';

  @override
  String get chatMessageWidgetBuiltinSearchHideNote =>
      'Скрыть карточки встроенного инструмента поиска';

  @override
  String get chatMessageWidgetDeepThinking => 'Глубокое рассуждение';

  @override
  String chatMessageWidgetWebSearch(String query) {
    return 'Веб-поиск: $query';
  }

  @override
  String chatMessageWidgetWebFetch(String target) {
    return 'Чтение страницы: $target';
  }

  @override
  String get chatMessageWidgetBuiltinSearch => 'Встроенный поиск';

  @override
  String get chatMessageWidgetReadClipboard => 'Чтение буфера обмена';

  @override
  String get chatMessageWidgetWriteClipboard => 'Запись в буфер обмена';

  @override
  String get chatMessageWidgetSpeakingTitle => 'Озвучивание:';

  @override
  String chatMessageWidgetSpeakText(String text) {
    return 'Озвучивание: $text';
  }

  @override
  String get chatMessageWidgetMemoryRead => 'Чтение памяти';

  @override
  String get chatMessageWidgetMemoryUpdate => 'Обновление памяти';

  @override
  String get chatMessageWidgetMemorySearchProfile => 'Поиск в памяти';

  @override
  String get chatMessageWidgetMemoryEdit => 'Редактировать память';

  @override
  String get chatMessageWidgetMemoryDelete => 'Удалить из памяти';

  @override
  String get chatMessageWidgetUpdateUserProfile =>
      'Обновить профиль пользователя';

  @override
  String get chatMessageWidgetChatSearch => 'Поиск по прошлым чатам';

  @override
  String get chatMessageWidgetCreateMemory => 'Создать запись в памяти';

  @override
  String chatMessageWidgetToolCall(String name) {
    return 'Вызов инструмента: $name';
  }

  @override
  String chatMessageWidgetToolResult(String name) {
    return 'Результат инструмента: $name';
  }

  @override
  String get chatMessageWidgetNoResultYet => '(Результата пока нет)';

  @override
  String get chatMessageWidgetArguments => 'Аргументы';

  @override
  String get chatMessageWidgetResult => 'Результат';

  @override
  String get chatMessageWidgetImages => 'Изображения';

  @override
  String chatMessageWidgetCitationsCount(int count) {
    return 'Цитат: $count';
  }

  @override
  String chatSelectionSelectedCountTitle(int count) {
    return 'Выбрано сообщений: $count';
  }

  @override
  String get chatSelectionExportTxt => 'TXT';

  @override
  String get chatSelectionExportMd => 'MD';

  @override
  String get chatSelectionExportImage => 'Изображение';

  @override
  String get chatSelectionThinkingTools => 'Инструменты рассуждения';

  @override
  String get chatSelectionThinkingContent => 'Содержимое рассуждения';

  @override
  String get chatSelectionDeleteSelected => 'Удалить выбранное';

  @override
  String get chatSelectionSelectMessagesToDelete =>
      'Выберите сообщения для удаления';

  @override
  String chatSelectionDeleteSelectedConfirm(int count) {
    return 'Удалить выбранные версии ($count)? Это действие нельзя отменить.';
  }

  @override
  String chatSelectionDeleteSelectedAllVersionsConfirm(int count) {
    return 'Удалить все версии выбранных сообщений ($count)? Это действие нельзя отменить.';
  }

  @override
  String get messageExportSheetAssistant => 'Ассистент';

  @override
  String get messageExportSheetDefaultTitle => 'Новый чат';

  @override
  String get messageExportSheetExporting => 'Экспорт…';

  @override
  String messageExportSheetExportFailed(String error) {
    return 'Не удалось выполнить экспорт: $error';
  }

  @override
  String messageExportSheetExportedAs(String filename) {
    return 'Экспортировано как $filename';
  }

  @override
  String get displaySettingsPageEnableDollarLatexTitle => 'Рендеринг \$...\$';

  @override
  String get displaySettingsPageEnableDollarLatexSubtitle =>
      'Отображать содержимое между \$...\$ как встроенную математическую формулу';

  @override
  String get displaySettingsPageEnableMathTitle =>
      'Рендеринг математических формул';

  @override
  String get displaySettingsPageEnableMathSubtitle =>
      'Отображать математику LaTeX (встроенную и блочную)';

  @override
  String get displaySettingsPageUseLegacyInlineCodeStyleTitle =>
      'Старый стиль встроенного кода';

  @override
  String get displaySettingsPageUseLegacyInlineCodeStyleSubtitle =>
      'Использовать более светлый фон, тонкую рамку и увеличенный межстрочный интервал для встроенного кода.';

  @override
  String get displaySettingsPageUseLegacyCodeBlockStyleTitle =>
      'Старый стиль блоков кода';

  @override
  String get displaySettingsPageUseLegacyCodeBlockStyleSubtitle =>
      'Восстановить прежние цвета, скругления и отступы для блоков кода.';

  @override
  String get displaySettingsPageEnableUserMarkdownTitle =>
      'Рендеринг сообщений пользователя в Markdown';

  @override
  String get displaySettingsPageEnableReasoningMarkdownTitle =>
      'Рендеринг рассуждений (thinking) в Markdown';

  @override
  String get displaySettingsPageEnableAssistantMarkdownTitle =>
      'Рендеринг сообщений ассистента в Markdown';

  @override
  String get displaySettingsPageMobileCodeBlockWrapTitle =>
      'Перенос строк в блоках кода на мобильных';

  @override
  String get displaySettingsPageAutoCollapseCodeBlockTitle =>
      'Автоматически сворачивать блоки кода';

  @override
  String get displaySettingsPageAutoCollapseCodeBlockLinesTitle =>
      'Порог автосворачивания';

  @override
  String get displaySettingsPageAutoCollapseCodeBlockLinesUnit => 'строк';

  @override
  String get displaySettingsPageCollapseLongUserMessagesTitle =>
      'Сворачивать длинные сообщения';

  @override
  String get displaySettingsPageCollapseLongUserMessagesSubtitle =>
      'Сообщения пользователя длиннее порога сворачиваются с кнопкой развернуть';

  @override
  String get displaySettingsPageCollapseLongUserMessagesCharsTitle =>
      'Порог сворачивания';

  @override
  String get displaySettingsPageCollapseLongUserMessagesCharsUnit => 'символов';

  @override
  String get chatMessageExpandLongText => 'Развернуть';

  @override
  String get chatMessageCollapseLongText => 'Свернуть';

  @override
  String get messageExportSheetFormatTitle => 'Формат экспорта';

  @override
  String get messageExportSheetMarkdown => 'Markdown';

  @override
  String get messageExportSheetSingleMarkdownSubtitle =>
      'Экспортировать это сообщение как файл Markdown';

  @override
  String get messageExportSheetBatchMarkdownSubtitle =>
      'Экспортировать выбранные сообщения как файл Markdown';

  @override
  String get messageExportSheetPlainText => 'Обычный текст';

  @override
  String get messageExportSheetSingleTxtSubtitle =>
      'Экспортировать это сообщение как файл TXT';

  @override
  String get messageExportSheetBatchTxtSubtitle =>
      'Экспортировать выбранные сообщения как файл TXT';

  @override
  String get messageExportSheetExportImage => 'Экспортировать как изображение';

  @override
  String get messageExportSheetSingleExportImageSubtitle =>
      'Отрисовать это сообщение в PNG-изображение';

  @override
  String get messageExportSheetBatchExportImageSubtitle =>
      'Отрисовать выбранные сообщения в PNG-изображение';

  @override
  String get messageExportSheetShowThinkingAndToolCards =>
      'Показывать карточки рассуждений и инструментов';

  @override
  String get messageExportSheetShowThinkingContent =>
      'Показывать содержимое рассуждений';

  @override
  String get messageExportThinkingContentLabel => 'Содержимое рассуждений';

  @override
  String get messageExportSheetDateTimeWithSecondsPattern =>
      'dd.MM.yyyy HH:mm:ss';

  @override
  String get exportDisclaimerAiGenerated =>
      'Содержимое создано ИИ. Пожалуйста, проверяйте внимательно.';

  @override
  String get imagePreviewSheetSaveImage => 'Сохранить изображение';

  @override
  String get imagePreviewSheetSaveSuccess => 'Сохранено в галерею';

  @override
  String imagePreviewSheetSaveFailed(String error) {
    return 'Не удалось сохранить: $error';
  }

  @override
  String get sideDrawerMenuRename => 'Переименовать';

  @override
  String get sideDrawerMenuPin => 'Закрепить';

  @override
  String get sideDrawerMenuUnpin => 'Открепить';

  @override
  String get sideDrawerMenuRegenerateTitle => 'Сгенерировать заголовок заново';

  @override
  String get sideDrawerMenuCopy => 'Копировать';

  @override
  String get sideDrawerMenuMoveTo => 'Переместить в';

  @override
  String get sideDrawerMenuDelete => 'Удалить';

  @override
  String get sideDrawerMenuSelect => 'Выбрать';

  @override
  String sideDrawerSelectionTitle(int count) {
    return 'Выбрано: $count';
  }

  @override
  String get sideDrawerSelectionSelectAll => 'Выбрать все';

  @override
  String get sideDrawerSelectionDeselectAll => 'Снять выделение';

  @override
  String get sideDrawerSelectionPin => 'Закрепить';

  @override
  String get sideDrawerSelectionUnpin => 'Открепить';

  @override
  String get sideDrawerSelectionMove => 'Переместить';

  @override
  String get sideDrawerSelectionDelete => 'Удалить';

  @override
  String get sideDrawerSelectionDeleteConfirmTitle => 'Удалить чаты';

  @override
  String sideDrawerSelectionDeleteConfirmContent(int count) {
    return 'Удалить чаты ($count)?';
  }

  @override
  String sideDrawerDeleteSelectedSnackbar(int count) {
    return 'Удалено чатов: $count';
  }

  @override
  String sideDrawerMoveSelectedSnackbar(int count) {
    return 'Перемещено чатов: $count';
  }

  @override
  String sideDrawerDeleteSnackbar(String title) {
    return 'Удалён чат «$title»';
  }

  @override
  String get sideDrawerRenameHint => 'Введите новое название';

  @override
  String get sideDrawerCancel => 'Отмена';

  @override
  String get sideDrawerOK => 'ОК';

  @override
  String get sideDrawerSave => 'Сохранить';

  @override
  String get sideDrawerGreetingMorning => 'Доброе утро 👋';

  @override
  String get sideDrawerGreetingNoon => 'Добрый день 👋';

  @override
  String get sideDrawerGreetingAfternoon => 'Добрый день 👋';

  @override
  String get sideDrawerGreetingEvening => 'Добрый вечер 👋';

  @override
  String get sideDrawerDateToday => 'Сегодня';

  @override
  String get sideDrawerDateYesterday => 'Вчера';

  @override
  String get sideDrawerDateShortPattern => 'd MMM';

  @override
  String get sideDrawerDateFullPattern => 'd MMM yyyy';

  @override
  String get sideDrawerSearchHint => 'Поиск по текущему ассистенту';

  @override
  String get sideDrawerSearchAssistantsHint => 'Поиск ассистентов';

  @override
  String get sideDrawerTopicSearchModeLabel => 'Режим темы';

  @override
  String get sideDrawerGlobalSearchModeLabel => 'Глобальный режим';

  @override
  String get sideDrawerSearchModeSwipeToTopicHint =>
      'Смахните строку поиска для поиска по теме';

  @override
  String get sideDrawerSearchModeSwipeToGlobalHint =>
      'Смахните строку поиска для глобального поиска';

  @override
  String get sideDrawerGlobalSearchHint => 'Поиск по всем сессиям';

  @override
  String get sideDrawerGlobalSearchEmptyHint =>
      'Поиск по заголовкам и сообщениям';

  @override
  String get sideDrawerGlobalSearchNoResults => 'Нет подходящих сессий';

  @override
  String sideDrawerGlobalSearchResultCount(int count) {
    return 'Результатов: $count';
  }

  @override
  String sideDrawerUpdateTitle(String version) {
    return 'Новая версия: $version';
  }

  @override
  String sideDrawerUpdateTitleWithBuild(String version, int build) {
    return 'Новая версия: $version ($build)';
  }

  @override
  String get sideDrawerLinkCopied => 'Ссылка скопирована';

  @override
  String get sideDrawerPinnedLabel => 'Закреплённые';

  @override
  String get sideDrawerHistory => 'История';

  @override
  String get sideDrawerSettings => 'Настройки';

  @override
  String get sideDrawerChooseAssistantTitle => 'Выбор ассистента';

  @override
  String get sideDrawerChooseImage => 'Выбрать изображение';

  @override
  String get sideDrawerChooseEmoji => 'Выбрать эмодзи';

  @override
  String get sideDrawerEnterLink => 'Ввести ссылку';

  @override
  String get sideDrawerImportFromQQ => 'Импорт из QQ';

  @override
  String get sideDrawerReset => 'Сбросить';

  @override
  String get providerAvatarChooseBuiltInIcon => 'Выбрать встроенную иконку';

  @override
  String get providerAvatarIconDialogTitle => 'Выбрать встроенную иконку';

  @override
  String get providerAvatarIconSearchHint => 'Поиск иконок';

  @override
  String get providerAvatarIconNoResults => 'Иконки не найдены';

  @override
  String get providerAvatarInputLobehubIcon => 'Ввести иконку LobeHub';

  @override
  String get providerAvatarChooseLobehubIcon => 'Ввести иконку LobeHub';

  @override
  String get providerAvatarLobehubDialogTitle => 'Ввести иконку LobeHub';

  @override
  String get providerAvatarLobehubDialogHint =>
      'Введите название иконки LobeHub, например openai';

  @override
  String get sideDrawerEmojiDialogTitle => 'Выбрать эмодзи';

  @override
  String get sideDrawerEmojiDialogHint => 'Введите или вставьте любой эмодзи';

  @override
  String get sideDrawerImageUrlDialogTitle => 'Ввести URL изображения';

  @override
  String get sideDrawerImageUrlDialogHint =>
      'например, https://example.com/avatar.png';

  @override
  String get sideDrawerQQAvatarDialogTitle => 'Импорт из QQ';

  @override
  String get sideDrawerQQAvatarInputHint => 'Введите номер QQ (5–12 цифр)';

  @override
  String get sideDrawerQQAvatarFetchFailed =>
      'Не удалось получить случайный аватар QQ. Попробуйте ещё раз.';

  @override
  String get sideDrawerRandomQQ => 'Случайный QQ';

  @override
  String get sideDrawerGalleryOpenError =>
      'Не удалось открыть галерею. Попробуйте ввести URL изображения.';

  @override
  String get sideDrawerGeneralImageError =>
      'Что-то пошло не так. Попробуйте ввести URL изображения.';

  @override
  String get sideDrawerSetNicknameTitle => 'Задать никнейм';

  @override
  String get sideDrawerNicknameLabel => 'Никнейм';

  @override
  String get sideDrawerNicknameHint => 'Введите новый никнейм';

  @override
  String get sideDrawerRename => 'Переименовать';

  @override
  String get chatInputBarHint => 'Введите сообщение для ИИ';

  @override
  String get chatInputBarSelectModelTooltip => 'Выбрать модель';

  @override
  String get chatInputBarOnlineSearchTooltip => 'Онлайн-поиск';

  @override
  String get chatInputBarReasoningStrengthTooltip =>
      'Интенсивность рассуждения';

  @override
  String get chatInputBarMcpServersTooltip => 'Серверы MCP';

  @override
  String get chatInputBarToolsTooltip => 'Инструменты';

  @override
  String get chatInputBarMoreTooltip => 'Добавить';

  @override
  String get chatInputBarVoiceInputTooltip => 'Голосовой ввод';

  @override
  String get chatInputBarVoiceCancelTooltip => 'Отменить запись';

  @override
  String get chatInputBarVoiceStopTooltip => 'Остановить и распознать в текст';

  @override
  String get chatInputBarVoiceSendTooltip => 'Распознать и отправить';

  @override
  String get chatInputBarVoiceTranscribing => 'Распознавание…';

  @override
  String get chatInputBarVoiceAttachAudioTooltip =>
      'Остановить и прикрепить как аудио';

  @override
  String get chatInputBarVoiceSendAudioTooltip => 'Отправить запись';

  @override
  String get chatInputBarVoiceSavingAudio => 'Сохранение аудио…';

  @override
  String get audioClipPlayTooltip => 'Воспроизвести аудио';

  @override
  String get audioClipPauseTooltip => 'Пауза';

  @override
  String get audioClipPlaybackFailed => 'Не удалось воспроизвести это аудио';

  @override
  String get chatInputBarImageProcessing => 'Обработка изображения';

  @override
  String get chatInputBarImageMode => 'Режим изображений';

  @override
  String get chatInputBarDisableImageModeTooltip =>
      'Отключить режим изображений';

  @override
  String get chatInputBarQueuedPending => 'В очереди на отправку';

  @override
  String get chatInputBarQueuedCancel => 'Отменить очередь';

  @override
  String get chatInputBarInsertNewline => 'Новая строка';

  @override
  String get chatInputBarExpand => 'Развернуть';

  @override
  String get chatInputBarCollapse => 'Свернуть';

  @override
  String get contextUsageTitle => 'Контекстное окно';

  @override
  String get contextUsageStateExact => 'Точно (из последнего ответа)';

  @override
  String get contextUsageStateExactCalibrated =>
      'Итог точный; разбивка оценена пропорционально';

  @override
  String get contextUsageStateEstimated => 'Оценка';

  @override
  String get contextUsageStateStale => 'Устарело, обновление…';

  @override
  String get contextUsageStateComputing => 'Вычисление…';

  @override
  String get contextUsageStateFailed =>
      'Не удалось рассчитать использование. Попробуйте ещё раз.';

  @override
  String get contextUsageStateFailedWithPrevious =>
      'Не удалось обновить. Показан предыдущий результат, который может быть устаревшим.';

  @override
  String get contextUsageUnavailable => 'Использование сейчас недоступно.';

  @override
  String contextUsagePartialSummary(String tokens) {
    return 'Оценено $tokens, плюс неизвестное использование на стороне сервера';
  }

  @override
  String get contextUsageBucketNativeCompaction => 'Сжатие на стороне сервера';

  @override
  String get contextUsageUnknownTokens => 'Неизвестно';

  @override
  String contextUsageLastRequestInput(String tokens) {
    return 'Последний фактически отправленный модели объём: $tokens';
  }

  @override
  String get contextUsageStateNone => 'Пока нет данных';

  @override
  String get contextUsageBucketSystem => 'Системный промпт';

  @override
  String get contextUsageBucketInjections => 'Внедрённые инструкции';

  @override
  String get contextUsageBucketHistory => 'Сообщения';

  @override
  String get contextUsageBucketTools => 'Встроенные инструменты';

  @override
  String get contextUsageBucketMemory => 'Память';

  @override
  String get contextUsageBucketWorldBook => 'Мировые книги';

  @override
  String get contextUsageBucketSkills => 'Навыки';

  @override
  String get contextUsageBucketWorkspace => 'Рабочая область';

  @override
  String get contextUsageBucketSearch => 'Промпт поиска';

  @override
  String get contextUsageBucketMcpTools => 'Инструменты MCP';

  @override
  String get contextUsageBucketAttachments => 'Вложения';

  @override
  String get contextUsageBucketDraft => 'Черновик';

  @override
  String get contextUsageBucketUsed => 'Использовано';

  @override
  String get contextUsageFreeSpace => 'Свободное место';

  @override
  String contextUsageUsedWindow(String used, String window, int percent) {
    return '$used / $window ($percent%)';
  }

  @override
  String get contextUsageNoWindow => 'Лимит контекста ещё не задан.';

  @override
  String get contextUsageSetWindow => 'Задать контекстное окно';

  @override
  String get contextUsageRefresh => 'Обновить';

  @override
  String get mcpPageBackTooltip => 'Назад';

  @override
  String get mcpPageAddMcpTooltip => 'Добавить MCP';

  @override
  String get mcpPageNoServers => 'Нет серверов MCP';

  @override
  String get mcpPageErrorDialogTitle => 'Ошибка подключения';

  @override
  String get mcpPageErrorNoDetails => 'Нет подробностей';

  @override
  String get mcpPageClose => 'Закрыть';

  @override
  String get mcpPageReconnect => 'Переподключиться';

  @override
  String get mcpPageStatusConnected => 'Подключено';

  @override
  String get mcpPageStatusConnecting => 'Подключение…';

  @override
  String get mcpPageStatusDisconnected => 'Не подключено';

  @override
  String get mcpPageStatusAuthorizationRequired => 'Требуется авторизация';

  @override
  String get mcpPageStatusAuthorizing => 'Авторизация…';

  @override
  String get mcpPageStatusDisabled => 'Отключено';

  @override
  String get mcpPageOAuthRequired => 'Требуется вход через OAuth';

  @override
  String get mcpPageOAuthSignIn => 'Войти через OAuth';

  @override
  String mcpPageToolsCount(int enabled, int total) {
    return 'Инструменты: $enabled/$total';
  }

  @override
  String get mcpPageConnectionFailed => 'Не удалось подключиться';

  @override
  String get mcpPageDetails => 'Подробности';

  @override
  String get mcpPageDelete => 'Удалить';

  @override
  String get mcpPageConfirmDeleteTitle => 'Подтвердите удаление';

  @override
  String get mcpPageConfirmDeleteContent => 'Удаление можно отменить. Удалить?';

  @override
  String get mcpPageServerDeleted => 'Сервер удалён';

  @override
  String get mcpPageUndo => 'Отменить';

  @override
  String get mcpPageCancel => 'Отмена';

  @override
  String get mcpConversationSheetTitle => 'Серверы MCP';

  @override
  String get mcpConversationSheetSubtitle =>
      'Выберите серверы, включённые для этого чата';

  @override
  String get mcpConversationSheetSelectAll => 'Выбрать все';

  @override
  String get mcpConversationSheetClearAll => 'Снять выбор';

  @override
  String get mcpConversationSheetNoRunning => 'Нет запущенных серверов MCP';

  @override
  String get mcpConversationSheetConnected => 'Подключено';

  @override
  String mcpConversationSheetToolsCount(int enabled, int total) {
    return 'Инструменты: $enabled/$total';
  }

  @override
  String get mcpServerEditSheetEnabledLabel => 'Включено';

  @override
  String get mcpServerEditSheetNameLabel => 'Название';

  @override
  String get mcpServerEditSheetTransportLabel => 'Транспорт';

  @override
  String get mcpServerEditSheetUrlLabel => 'URL сервера';

  @override
  String get mcpServerEditSheetCustomHeadersTitle =>
      'Пользовательские заголовки';

  @override
  String get mcpServerEditSheetHeaderNameLabel => 'Имя заголовка';

  @override
  String get mcpServerEditSheetHeaderNameHint => 'например, Authorization';

  @override
  String get mcpServerEditSheetHeaderValueLabel => 'Значение заголовка';

  @override
  String get mcpServerEditSheetHeaderValueHint => 'например, Bearer xxxxxx';

  @override
  String get mcpServerEditSheetRemoveHeaderTooltip => 'Удалить';

  @override
  String get mcpServerEditSheetAddHeader => 'Добавить заголовок';

  @override
  String get mcpServerEditSheetTitleEdit => 'Изменить MCP';

  @override
  String get mcpServerEditSheetTitleAdd => 'Добавить MCP';

  @override
  String get mcpServerEditSheetSyncToolsTooltip =>
      'Синхронизировать инструменты';

  @override
  String get mcpServerEditSheetTabBasic => 'Основные';

  @override
  String get mcpServerEditSheetTabTools => 'Инструменты';

  @override
  String get mcpServerEditSheetNoToolsHint =>
      'Нет инструментов, нажмите обновить для синхронизации';

  @override
  String get mcpServerEditSheetCancel => 'Отмена';

  @override
  String get mcpServerEditSheetSave => 'Сохранить';

  @override
  String get mcpServerEditSheetUrlRequired => 'Введите URL сервера';

  @override
  String get defaultModelPageBackTooltip => 'Назад';

  @override
  String get defaultModelPageTitle => 'Модель по умолчанию';

  @override
  String get defaultModelPageChatModelTitle => 'Модель чата';

  @override
  String get defaultModelPageChatModelSubtitle =>
      'Глобальная модель чата по умолчанию';

  @override
  String get defaultModelPageTitleModelTitle => 'Модель для заголовков';

  @override
  String get defaultModelPageTitleModelSubtitle =>
      'Суммирует заголовки чатов: по умолчанию используется текущая модель чата или выбранная модель.';

  @override
  String get titleModelThinkingTitle => 'Включить рассуждение';

  @override
  String get defaultModelPageSummaryModelTitle => 'Модель для сводок';

  @override
  String get defaultModelPageSummaryModelSubtitle =>
      'Используется для создания сводок чатов; предпочтительны быстрые и недорогие модели';

  @override
  String get defaultModelPageSuggestionModelTitle =>
      'Модель для предложений в чате';

  @override
  String get defaultModelPageSuggestionModelSubtitle =>
      'Создаёт подсказки-продолжения с использованием текущей модели чата или выбранной модели. По умолчанию отключено.';

  @override
  String get assistantEditRecentChatsSummaryFrequencyTitle =>
      'Частота обновления сводки';

  @override
  String get assistantEditRecentChatsSummaryFrequencyDescription =>
      'Обновлять сводку недавних чатов после выбранного числа новых сообщений.';

  @override
  String assistantEditRecentChatsSummaryFrequencyOption(int count) {
    return 'Каждые $count';
  }

  @override
  String get assistantEditRecentChatsSummaryFrequencyCustomButton => 'Другое';

  @override
  String get assistantEditRecentChatsSummaryFrequencyCustomTitle =>
      'Своя частота сводки';

  @override
  String get assistantEditRecentChatsSummaryFrequencyCustomDescription =>
      'Укажите, сколько новых сообщений должно накопиться перед обновлением сводки недавних чатов.';

  @override
  String get assistantEditRecentChatsSummaryFrequencyCustomLabel =>
      'Число новых сообщений';

  @override
  String get assistantEditRecentChatsSummaryFrequencyCustomHint =>
      'Введите число больше 0';

  @override
  String get assistantEditRecentChatsSummaryFrequencyCustomInvalid =>
      'Введите целое число больше 0';

  @override
  String get defaultModelPageTranslateModelTitle => 'Модель перевода';

  @override
  String get defaultModelPageTranslateModelSubtitle =>
      'Используется для перевода содержимого сообщений; предпочтительны быстрые и точные модели';

  @override
  String get defaultModelPageOcrModelTitle => 'Модель OCR';

  @override
  String backgroundTaskFailed(String task, String error) {
    return '$task: ошибка — $error';
  }

  @override
  String get defaultModelPageOcrModelSubtitle =>
      'Используется для извлечения текста и описаний из изображений';

  @override
  String get defaultModelPageOcrModelRequiresImageInput =>
      'Выберите модель с поддержкой ввода изображений для OCR';

  @override
  String get defaultModelPagePromptLabel => 'Промпт';

  @override
  String get defaultModelPageTitlePromptHint =>
      'Введите шаблон промпта для создания заголовков';

  @override
  String get defaultModelPageSummaryPromptHint =>
      'Введите шаблон промпта для создания сводок';

  @override
  String get defaultModelPageSuggestionPromptHint =>
      'Введите шаблон промпта для предложений в чате';

  @override
  String get defaultModelPageTranslatePromptHint =>
      'Введите шаблон промпта для перевода';

  @override
  String get defaultModelPageOcrPromptHint =>
      'Введите шаблон промпта для распознавания изображений OCR';

  @override
  String get defaultModelPageResetDefault => 'Сбросить по умолчанию';

  @override
  String get defaultModelPageDisable => 'Отключить';

  @override
  String get defaultModelPageSave => 'Сохранить';

  @override
  String defaultModelPageTitleVars(String contentVar, String localeVar) {
    return 'Переменные: content: $contentVar, locale: $localeVar';
  }

  @override
  String defaultModelPageSummaryVars(
    String previousSummaryVar,
    String userMessagesVar,
  ) {
    return 'Переменные: предыдущая сводка: $previousSummaryVar, новые сообщения: $userMessagesVar';
  }

  @override
  String defaultModelPageSuggestionVars(String contentVar, String localeVar) {
    return 'Переменные: чат: $contentVar, язык: $localeVar';
  }

  @override
  String get defaultModelPageCompressModelTitle => 'Модель сжатия';

  @override
  String get defaultModelPageCompressModelSubtitle =>
      'Модель, используемая для сжатия длинных чатов в сводку. Обычно достаточно быстрой модели.';

  @override
  String get defaultModelPageCompressPromptHint =>
      'Введите промпт, используемый при сжатии.';

  @override
  String defaultModelPageCompressVars(String contentVar, String localeVar) {
    return 'Переменные: беседа $contentVar, язык $localeVar';
  }

  @override
  String defaultModelPageTranslateVars(String sourceVar, String targetVar) {
    return 'Переменные: исходный текст: $sourceVar, целевой язык: $targetVar';
  }

  @override
  String get defaultModelPageUseCurrentModel =>
      'Использовать текущую модель чата';

  @override
  String get defaultModelPageNotEnabled => 'Не включено';

  @override
  String get translatePagePasteButton => 'Вставить';

  @override
  String get translatePageCopyResult => 'Копировать результат';

  @override
  String get translatePageClearAll => 'Очистить всё';

  @override
  String get translatePageInputHint => 'Введите текст для перевода…';

  @override
  String get translatePageOutputHint => 'Здесь появится перевод…';

  @override
  String get modelDetailSheetAddModel => 'Добавить модель';

  @override
  String get modelDetailSheetEditModel => 'Изменить модель';

  @override
  String get modelDetailSheetBasicTab => 'Основные';

  @override
  String get modelDetailSheetAdvancedTab => 'Дополнительно';

  @override
  String get modelDetailSheetBuiltinToolsTab => 'Встроенные инструменты';

  @override
  String get modelDetailSheetModelIdLabel => 'ID модели';

  @override
  String get modelDetailSheetModelIdHint =>
      'Обязательно, рекомендуются строчные буквы, цифры и дефисы';

  @override
  String get modelDetailSheetModelNameLabel => 'Название модели';

  @override
  String get modelDetailSheetModelTypeLabel => 'Тип модели';

  @override
  String get modelDetailSheetChatType => 'Чат';

  @override
  String get modelDetailSheetEmbeddingType => 'Эмбеддинг';

  @override
  String get modelDetailSheetInputModesLabel => 'Режимы ввода';

  @override
  String get modelDetailSheetOutputModesLabel => 'Режимы вывода';

  @override
  String get modelDetailSheetAbilitiesLabel => 'Возможности';

  @override
  String get modelDetailSheetTextMode => 'Текст';

  @override
  String get modelDetailSheetImageMode => 'Изображение';

  @override
  String get modelDetailSheetToolsAbility => 'Инструменты';

  @override
  String get modelDetailSheetReasoningAbility => 'Рассуждение';

  @override
  String get modelDetailSheetCustomHeadersTitle => 'Пользовательские заголовки';

  @override
  String get modelDetailSheetAddHeader => 'Добавить заголовок';

  @override
  String get modelDetailSheetCustomBodyTitle => 'Пользовательское тело запроса';

  @override
  String get modelFetchInvertTooltip => 'Инвертировать';

  @override
  String get modelDetailSheetSaveFailedMessage =>
      'Не удалось сохранить. Попробуйте ещё раз.';

  @override
  String get modelDetailSheetAddBody => 'Добавить поле';

  @override
  String get modelDetailSheetBuiltinToolsDescription =>
      'Встроенные инструменты зависят от провайдера и режима API.';

  @override
  String get modelDetailSheetUrlContextTool => 'Контекст URL';

  @override
  String get modelDetailSheetUrlContextToolDescription =>
      'Включить обработку содержимого URL';

  @override
  String get modelDetailSheetCodeExecutionTool => 'Выполнение кода';

  @override
  String get modelDetailSheetCodeExecutionToolDescription =>
      'Включить инструмент выполнения кода';

  @override
  String get modelDetailSheetYoutubeTool => 'YouTube';

  @override
  String get modelDetailSheetYoutubeToolDescription =>
      'Включить обработку ссылок YouTube (автоопределение ссылок в запросах)';

  @override
  String get modelDetailSheetOpenaiBuiltinToolsResponsesOnlyHint =>
      'Требуется OpenAI Responses API.';

  @override
  String get modelDetailSheetWebFetchTool => 'Загрузка веб-страниц';

  @override
  String get modelDetailSheetOpenrouterWebFetchToolDescription =>
      'Включить серверный инструмент загрузки веб-страниц OpenRouter';

  @override
  String get modelDetailSheetClaudeWebFetchToolDescription =>
      'Разрешить Claude загружать страницы и PDF по ссылкам из чата';

  @override
  String get modelDetailSheetClaudeCodeExecutionToolDescription =>
      'Разрешить Claude запускать Python и Bash в песочнице Anthropic';

  @override
  String get modelDetailSheetOpenrouterShellTool => 'Shell';

  @override
  String get modelDetailSheetOpenrouterShellToolDescription =>
      'Запуск команд Shell в размещённой изолированной песочнице';

  @override
  String get modelDetailSheetOpenaiCodeInterpreterTool => 'Интерпретатор кода';

  @override
  String get modelDetailSheetOpenaiCodeInterpreterToolDescription =>
      'Включить инструмент интерпретатора кода (контейнер автоматически, лимит памяти 4g)';

  @override
  String get modelDetailSheetOpenaiImageGenerationTool =>
      'Генерация изображений';

  @override
  String get modelDetailSheetOpenaiImageGenerationToolDescription =>
      'Включить инструмент генерации изображений';

  @override
  String get modelDetailSheetCancelButton => 'Отмена';

  @override
  String get modelDetailSheetAddButton => 'Добавить';

  @override
  String get modelDetailSheetConfirmButton => 'Подтвердить';

  @override
  String get modelDetailSheetInvalidIdError =>
      'Введите корректный ID модели (не менее 2 символов)';

  @override
  String get modelDetailSheetHeaderKeyHint => 'Ключ заголовка';

  @override
  String get modelDetailSheetHeaderValueHint => 'Значение заголовка';

  @override
  String get modelDetailSheetBodyKeyHint => 'Ключ поля';

  @override
  String get modelDetailSheetBodyJsonHint => 'JSON поля';

  @override
  String get modelSpecFormSourceCustom => 'Пользовательское';

  @override
  String get modelSpecFormSourceCatalog => 'Каталог';

  @override
  String get modelSpecFormSourceInferred => 'Предположительно';

  @override
  String get modelSpecFormSourceDefault => 'По умолчанию';

  @override
  String get modelSpecFormReset => 'Сбросить по умолчанию';

  @override
  String get modelSpecFormModalitiesSection => 'Модальности и возможности';

  @override
  String get modelSpecFormImageType => 'Изображение';

  @override
  String get modelSpecFormAudioMode => 'Аудио';

  @override
  String get modelSpecFormVideoMode => 'Видео';

  @override
  String get modelSpecFormPdfMode => 'PDF';

  @override
  String get modelSpecFormStructuredOutputAbility => 'Структурированный вывод';

  @override
  String get modelSpecFormReasoningSection => 'Рассуждение';

  @override
  String get modelSpecFormDialect => 'Диалект';

  @override
  String get modelSpecFormDialectNone => 'Нет';

  @override
  String get modelSpecFormDialectNoneSubtitle => 'Без полей рассуждения';

  @override
  String get modelSpecFormDialectOpenaiReasoningEffort =>
      'OpenAI reasoning effort';

  @override
  String get modelSpecFormDialectOpenaiReasoningEffortSubtitle =>
      'reasoning_effort';

  @override
  String get modelSpecFormDialectOpenaiResponsesReasoning =>
      'OpenAI Responses reasoning';

  @override
  String get modelSpecFormDialectOpenaiResponsesReasoningSubtitle =>
      'reasoning.effort';

  @override
  String get modelSpecFormDialectOpenrouterReasoning => 'OpenRouter reasoning';

  @override
  String get modelSpecFormDialectOpenrouterReasoningSubtitle => 'reasoning';

  @override
  String get modelSpecFormDialectAnthropicBudget => 'Anthropic budget';

  @override
  String get modelSpecFormDialectAnthropicBudgetSubtitle =>
      'thinking.budget_tokens';

  @override
  String get modelSpecFormDialectAnthropicAdaptiveEffort =>
      'Anthropic adaptive effort';

  @override
  String get modelSpecFormDialectAnthropicAdaptiveEffortSubtitle =>
      'thinking + output_config.effort';

  @override
  String get modelSpecFormDialectAnthropicBetweenTools =>
      'Anthropic adaptive / between_tools';

  @override
  String get modelSpecFormDialectAnthropicBetweenToolsSubtitle =>
      'Адаптивное рассуждение; при выключении используется between_tools';

  @override
  String get modelSpecFormDialectAnthropicEffort => 'Anthropic effort';

  @override
  String get modelSpecFormDialectAnthropicEffortSubtitle =>
      'thinking + output_config.effort';

  @override
  String get modelSpecFormDialectGeminiThinkingBudget =>
      'Gemini thinking budget';

  @override
  String get modelSpecFormDialectGeminiThinkingBudgetSubtitle =>
      'thinkingConfig.thinkingBudget';

  @override
  String get modelSpecFormDialectGeminiThinkingLevel => 'Gemini thinking level';

  @override
  String get modelSpecFormDialectGeminiThinkingLevelSubtitle =>
      'thinkingConfig.thinkingLevel';

  @override
  String get modelSpecFormDialectQwenEnableThinking => 'Qwen enable thinking';

  @override
  String get modelSpecFormDialectQwenEnableThinkingSubtitle =>
      'enable_thinking';

  @override
  String get modelSpecFormDialectThinkingType => 'Thinking type';

  @override
  String get modelSpecFormDialectThinkingTypeSubtitle => 'thinking.type';

  @override
  String get modelSpecFormDialectSiliconflowEnableThinking =>
      'SiliconFlow enable thinking';

  @override
  String get modelSpecFormDialectSiliconflowEnableThinkingSubtitle =>
      'enable_thinking';

  @override
  String get modelSpecFormDialectInternThinkingMode => 'Intern thinking mode';

  @override
  String get modelSpecFormDialectInternThinkingModeSubtitle => 'thinking_mode';

  @override
  String get modelSpecFormDialectChatTemplateKwargs => 'Chat template kwargs';

  @override
  String get modelSpecFormDialectChatTemplateKwargsSubtitle =>
      'chat_template_kwargs.enable_thinking';

  @override
  String get modelSpecFormDialectKimiThinking => 'Kimi thinking';

  @override
  String get modelSpecFormDialectKimiThinkingSubtitle => 'thinking';

  @override
  String get modelSpecFormDialectCustom => 'Пользовательский JSON';

  @override
  String get modelSpecFormDialectCustomSubtitle =>
      'JSON-патч для каждого уровня';

  @override
  String get modelSpecFormLevels => 'Поддерживаемые уровни';

  @override
  String get modelSpecFormCanDisable => 'Разрешить отключение';

  @override
  String get modelSpecFormDefaultLevel => 'Уровень по умолчанию';

  @override
  String get modelSpecFormBudgets => 'Бюджеты токенов';

  @override
  String modelSpecFormBudgetPlaceholder(String tokens) {
    return '$tokens';
  }

  @override
  String modelSpecFormCustomPatch(String level) {
    return 'JSON-патч ($level)';
  }

  @override
  String get modelSpecFormCustomPatchHint => 'например, reasoning_effort: high';

  @override
  String get modelSpecFormInvalidJson =>
      'Пользовательский патч рассуждения должен быть допустимым объектом JSON';

  @override
  String get modelSpecFormInvalidNumber => 'Введите корректное число';

  @override
  String get modelSpecFormStrategySection => 'Стратегия';

  @override
  String get modelSpecFormSampling => 'Сэмплирование';

  @override
  String get modelSpecFormRequestQuirks => 'Совместимость запросов';

  @override
  String get modelSpecFormDynamicWebSearch =>
      'Инструменты поиска с динамической фильтрацией';

  @override
  String get modelSpecFormDynamicWebSearchSubtitle =>
      'При включённой динамической фильтрации используются инструменты веб-поиска и загрузки версии 2026-03-18';

  @override
  String get modelSpecFormRemoteImageUrls => 'Удалённые ссылки на изображения';

  @override
  String get modelSpecFormRemoteImageUrlsSubtitle =>
      'Отправлять ссылки на изображения http(s) как есть; при выключении удалённые ссылки отбрасываются и отправляются только локальные изображения';

  @override
  String get modelSpecFormPromptCacheControl => 'Маркер кэша промпта';

  @override
  String get modelSpecFormPromptCacheControlSubtitle =>
      'При включённом кэшировании промпта добавлять cache_control в запросы OpenRouter';

  @override
  String get modelSpecFormSamplingAlways => 'Всегда';

  @override
  String get modelSpecFormSamplingAlwaysSubtitle =>
      'Сохранять temperature и другие поля сэмплирования';

  @override
  String get modelSpecFormSamplingOnlyWhenReasoningOff =>
      'Только когда рассуждение выключено';

  @override
  String get modelSpecFormSamplingOnlyWhenReasoningOffSubtitle =>
      'Удалять поля сэмплирования, пока модель рассуждает';

  @override
  String get modelSpecFormSamplingNever => 'Никогда';

  @override
  String get modelSpecFormSamplingNeverSubtitle =>
      'Всегда удалять поля сэмплирования';

  @override
  String get modelSpecFormReplay => 'Повтор рассуждения';

  @override
  String get modelSpecFormReplayNone => 'Нет';

  @override
  String get modelSpecFormReplayNoneSubtitle =>
      'Не отправлять предыдущее рассуждение обратно модели';

  @override
  String get modelSpecFormReplayToolTurns => 'Ходы с инструментами';

  @override
  String get modelSpecFormReplayToolTurnsSubtitle =>
      'Повторять рассуждение в ходах с вызовом инструментов';

  @override
  String get modelSpecFormReplayAll => 'Все';

  @override
  String get modelSpecFormReplayAllSubtitle =>
      'Повторять рассуждение в каждом последующем ходе';

  @override
  String get modelSpecFormReplayField => 'Поле повтора';

  @override
  String get modelSpecFormReplayFieldReasoningContent => 'reasoning_content';

  @override
  String get modelSpecFormReplayFieldReasoning => 'reasoning';

  @override
  String get modelSpecFormReplayFieldReasoningDetails => 'reasoning_details';

  @override
  String get modelSpecFormLimitsSection => 'Лимиты';

  @override
  String get modelSpecFormLimitsPricingSection => 'Лимиты и цены';

  @override
  String get modelSpecFormContextWindow => 'Контекстное окно';

  @override
  String get modelSpecFormMaxOutput => 'Макс. вывод';

  @override
  String get modelSpecFormPricingSection => 'Цены / 1M';

  @override
  String get modelSpecFormPricingInput => 'Ввод';

  @override
  String get modelSpecFormPricingOutput => 'Вывод';

  @override
  String get modelSpecFormPricingCacheRead => 'Чтение кэша';

  @override
  String get modelSpecFormPricingCacheWrite => 'Запись кэша';

  @override
  String get modelSpecFormCurrency => 'Валюта';

  @override
  String get modelSpecFormAdvancedSection => 'Запрос';

  @override
  String get modelSelectSheetSearchHint => 'Поиск моделей или провайдеров';

  @override
  String get modelSelectSheetFavoritesSection => 'Избранное';

  @override
  String get modelSelectSheetFollowAssistant => 'Следовать за ассистентом';

  @override
  String get modelSelectSheetFavoriteTooltip => 'В избранное';

  @override
  String get modelSelectSheetChatType => 'Чат';

  @override
  String get modelSelectSheetEmbeddingType => 'Эмбеддинг';

  @override
  String get providerDetailPageShareTooltip => 'Поделиться';

  @override
  String get providerDetailPageDeleteProviderTooltip => 'Удалить провайдера';

  @override
  String get providerDetailPageDeleteProviderTitle => 'Удалить провайдера';

  @override
  String get providerDetailPageDeleteProviderContent =>
      'Вы уверены, что хотите удалить этого провайдера? Это действие нельзя отменить.';

  @override
  String get providerDetailPageCancelButton => 'Отмена';

  @override
  String get providerDetailPageDeleteButton => 'Удалить';

  @override
  String get providerDetailPageProviderDeletedSnackbar => 'Провайдер удалён';

  @override
  String get providerDetailPageConfigTab => 'Настройки';

  @override
  String get providerDetailPageModelsTab => 'Модели';

  @override
  String get providerDetailPageCustomRequestTitle => 'Пользовательский запрос';

  @override
  String get providerDetailPageCustomRequestDescription =>
      'Применяется ко всем моделям этого провайдера. Настройки модели переопределяют эти значения; эти значения переопределяют настройки ассистента.';

  @override
  String get providerDetailPageNetworkTab => 'Сеть';

  @override
  String get providerDetailPageEnabledTitle => 'Включён';

  @override
  String get providerDetailPageManageSectionTitle => 'Управление';

  @override
  String get providerDetailPageNameLabel => 'Название';

  @override
  String get providerDetailPageApiKeyHint =>
      'Оставьте пустым, чтобы использовать значение по умолчанию';

  @override
  String get providerDetailPageHideTooltip => 'Скрыть';

  @override
  String get providerDetailPageShowTooltip => 'Показать';

  @override
  String get providerDetailPageApiPathLabel => 'Путь API';

  @override
  String get providerDetailPageResponseApiTitle => 'Response API (/responses)';

  @override
  String get providerDetailPagePromptCacheKeyTitle =>
      'Отправлять ключ кэша чата';

  @override
  String get providerDetailPagePromptCacheKeyHelp =>
      'Добавляет стабильный prompt_cache_key для каждого чата в запросы, совместимые с OpenAI. Включайте, только если ваш провайдер это поддерживает. Значения из пользовательского Body имеют приоритет; попадание в кэш не гарантируется.';

  @override
  String get providerDetailPageAihubmixAppCodeLabel => 'APP-Code (скидка 10%)';

  @override
  String get providerDetailPageAihubmixAppCodeHelp =>
      'Добавляет заголовок APP-Code к запросам для скидки 10%. Действует только для AIhubmix.';

  @override
  String get providerDetailPageClaudePromptCachingTitle =>
      'Кэширование промптов Claude';

  @override
  String get providerDetailPageClaudePromptCachingHelp =>
      'Добавляет cache_control к запросам Claude через Anthropic или OpenRouter.';

  @override
  String get providerDetailPageClaudePromptCachingTtlTitle => 'TTL кэша';

  @override
  String get providerDetailPageClaudePromptCachingTtlHelp =>
      'По умолчанию 5 минут. 1 час стоит дороже при записи, но может сократить пересоздание кэша в длинных чатах.';

  @override
  String get providerDetailPageClaudePromptCachingTtl5m => '5 мин';

  @override
  String get providerDetailPageClaudePromptCachingTtl1h => '1 час';

  @override
  String get providerDetailPageBalanceTitle => 'Баланс аккаунта';

  @override
  String get providerDetailPageBalanceInfo => 'Получать баланс аккаунта';

  @override
  String get providerDetailPageBalanceApiPathLabel =>
      'Путь API баланса или URL';

  @override
  String get providerDetailPageBalanceMethodLabel => 'HTTP-метод';

  @override
  String providerDetailPageBalanceRequestHint(String apiKeyPlaceholder) {
    return 'Эти настройки применяются только к запросам баланса. Используйте $apiKeyPlaceholder в заголовках или теле, чтобы подставить текущий API-ключ. Аутентификация по умолчанию — Bearer; пустое значение заголовка удаляет этот заголовок.';
  }

  @override
  String get providerDetailPageBalanceBodyLabel =>
      'Тело запроса (необязательно)';

  @override
  String get providerDetailPageBalanceBodyHint =>
      'Отправляется только с POST. Оставьте пустым, чтобы не отправлять тело. Content-Type по умолчанию — application/json; добавьте заголовок, чтобы использовать другой формат.';

  @override
  String get providerDetailPageBalanceResultPathLabel =>
      'JSON-путь к результату';

  @override
  String get providerDetailPageBalanceQueryButton => 'Проверить баланс';

  @override
  String get providerDetailPageBalanceQuerying => 'Проверка...';

  @override
  String get providerDetailPageBalanceResetDefaultsButton => 'Сбросить';

  @override
  String get providerDetailPageBalanceResetDefaultsTooltip =>
      'Сбросить настройки баланса';

  @override
  String providerDetailPageBalanceResult(String value) {
    return 'Баланс: $value';
  }

  @override
  String providerDetailPageBalanceError(String message) {
    return 'Не удалось проверить баланс: $message';
  }

  @override
  String get providerDetailPageVertexAiTitle => 'Vertex AI';

  @override
  String get providerDetailPageLocationLabel => 'Регион';

  @override
  String get providerDetailPageProjectIdLabel => 'ID проекта';

  @override
  String get providerDetailPageServiceAccountJsonLabel =>
      'JSON сервисного аккаунта (вставьте или импортируйте)';

  @override
  String get providerDetailPageImportJsonButton => 'Импорт JSON';

  @override
  String get providerDetailPageImportJsonReadFailedMessage =>
      'Не удалось прочитать файл';

  @override
  String get providerDetailPageTestButton => 'Проверить';

  @override
  String get providerDetailPageSaveButton => 'Сохранить';

  @override
  String get providerDetailPageProviderRemovedMessage => 'Провайдер удалён';

  @override
  String get providerDetailPageNoModelsTitle => 'Нет моделей';

  @override
  String get providerDetailPageNoModelsSubtitle =>
      'Нажмите кнопки ниже, чтобы добавить модели';

  @override
  String get providerDetailPageDeleteModelButton => 'Удалить';

  @override
  String get providerDetailPageConfirmDeleteTitle => 'Подтвердите удаление';

  @override
  String get providerDetailPageConfirmDeleteContent =>
      'Это можно отменить через «Отменить». Удалить?';

  @override
  String get providerDetailPageModelDeletedSnackbar => 'Модель удалена';

  @override
  String get providerDetailPageUndoButton => 'Отменить';

  @override
  String get providerDetailPageAddNewModelButton => 'Добавить модель';

  @override
  String get providerDetailPageFetchModelsButton => 'Получить';

  @override
  String get providerDetailPageEnableProxyTitle => 'Включить прокси';

  @override
  String get providerDetailPageHostLabel => 'Хост';

  @override
  String get providerDetailPagePortLabel => 'Порт';

  @override
  String get providerDetailPageUsernameOptionalLabel =>
      'Имя пользователя (необязательно)';

  @override
  String get providerDetailPagePasswordOptionalLabel =>
      'Пароль (необязательно)';

  @override
  String get providerDetailPageSavedSnackbar => 'Сохранено';

  @override
  String get providerDetailPageEmbeddingsGroupTitle => 'Эмбеддинги';

  @override
  String get providerDetailPageOtherModelsGroupTitle => 'Другие';

  @override
  String get providerDetailPageRemoveGroupTooltip => 'Удалить группу';

  @override
  String get providerDetailPageAddGroupTooltip => 'Добавить группу';

  @override
  String get providerDetailPageFilterHint =>
      'Введите название модели для фильтрации';

  @override
  String get providerDetailPageDeleteText => 'Удалить';

  @override
  String get providerDetailPageEditTooltip => 'Изменить';

  @override
  String get providerDetailPageTestConnectionTitle => 'Проверить подключение';

  @override
  String get providerDetailPageSelectModelButton => 'Выбрать модель';

  @override
  String get providerDetailPageChangeButton => 'Сменить';

  @override
  String get providerDetailPageUseStreamingLabel =>
      'Использовать потоковую передачу';

  @override
  String get providerDetailPageTestingMessage => 'Проверка…';

  @override
  String get providerDetailPageTestSuccessMessage => 'Успешно';

  @override
  String get providersPageTitle => 'Провайдеры';

  @override
  String get providersPageImportTooltip => 'Импорт';

  @override
  String get providersPageAddTooltip => 'Добавить';

  @override
  String get providersPageSearchHint => 'Поиск провайдеров или групп';

  @override
  String get providersPageProviderAddedSnackbar => 'Провайдер добавлен';

  @override
  String get modelCatalogTitle => 'Каталог моделей';

  @override
  String modelCatalogSourceBundled(String date) {
    return 'Встроенный снимок · $date';
  }

  @override
  String modelCatalogSourceRemote(String date) {
    return 'models.dev · обновлено $date';
  }

  @override
  String get modelCatalogAutoUpdate => 'Автообновление каждые 24 часа';

  @override
  String get modelCatalogRefresh => 'Обновить сейчас';

  @override
  String get modelCatalogUpdated => 'Каталог моделей обновлён';

  @override
  String modelCatalogRefreshFailed(String error) {
    return 'Ошибка обновления: $error';
  }

  @override
  String modelCatalogProviderCount(int count) {
    return '$count провайдеров';
  }

  @override
  String modelCatalogModelCount(int count) {
    return '$count моделей';
  }

  @override
  String get providerGroupsGroupLabel => 'Группа';

  @override
  String get providerGroupsOther => 'Другие';

  @override
  String get providerGroupsOtherUngroupedOption => 'Другие (без группы)';

  @override
  String get providerGroupsPickerTitle => 'Выбрать группу';

  @override
  String get providerGroupsManageTitle => 'Управление группами';

  @override
  String get providerGroupsManageAction => 'Управление группами';

  @override
  String get providerGroupsCreateNewGroupAction => 'Новая группа…';

  @override
  String get providerGroupsCreateDialogTitle => 'Новая группа';

  @override
  String get providerGroupsNameHint => 'Название группы';

  @override
  String get providerGroupsCreateDialogCancel => 'Отмена';

  @override
  String get providerGroupsCreateDialogOk => 'Создать';

  @override
  String get providerGroupsCreateFailedToast => 'Не удалось создать группу';

  @override
  String get providerGroupsDeleteConfirmTitle => 'Удалить группу?';

  @override
  String get providerGroupsDeleteConfirmContent =>
      'Провайдеры из этой группы будут перемещены в «Другие».';

  @override
  String get providerGroupsDeleteConfirmCancel => 'Отмена';

  @override
  String get providerGroupsDeleteConfirmOk => 'Удалить';

  @override
  String get providerGroupsDeletedToast => 'Группа удалена';

  @override
  String get providerGroupsEmptyState => 'Групп пока нет.';

  @override
  String get providerGroupsExpandToMoveToast => 'Сначала разверните группу.';

  @override
  String get providersPageSiliconFlowName => 'SiliconFlow';

  @override
  String get providersPageAliyunName => 'Aliyun';

  @override
  String get providersPageZhipuName => 'Zhipu AI';

  @override
  String get providersPageByteDanceName => 'ByteDance';

  @override
  String get providersPageEnabledStatus => 'ВКЛ';

  @override
  String get providersPageDisabledStatus => 'ВЫКЛ';

  @override
  String get providersPageModelsCountSuffix => ' моделей';

  @override
  String get providersPageModelsCountSingleSuffix => ' модель';

  @override
  String get addProviderSheetTitle => 'Добавить провайдера';

  @override
  String get addProviderSheetEnabledLabel => 'Включён';

  @override
  String get addProviderSheetNameLabel => 'Название';

  @override
  String get addProviderSheetApiPathLabel => 'Путь API';

  @override
  String get addProviderSheetVertexAiLocationLabel => 'Регион';

  @override
  String get addProviderSheetVertexAiProjectIdLabel => 'ID проекта';

  @override
  String get addProviderSheetVertexAiServiceAccountJsonLabel =>
      'JSON сервисного аккаунта (вставьте или импортируйте)';

  @override
  String get addProviderSheetImportJsonButton => 'Импорт JSON';

  @override
  String get addProviderSheetCancelButton => 'Отмена';

  @override
  String get addProviderSheetAddButton => 'Добавить';

  @override
  String get importProviderSheetTitle => 'Импорт провайдера';

  @override
  String get importProviderSheetScanQrTooltip => 'Сканировать QR';

  @override
  String get importProviderSheetFromGalleryTooltip => 'Из галереи';

  @override
  String importProviderSheetImportSuccessMessage(int count) {
    return 'Импортировано провайдеров: $count';
  }

  @override
  String importProviderSheetImportFailedMessage(String error) {
    return 'Ошибка импорта: $error';
  }

  @override
  String get importProviderSheetDescription =>
      'Вставьте строки общего доступа (можно несколько строк) или JSON ChatBox';

  @override
  String get importProviderSheetInputHint => 'ai-provider:v1:... или JSON';

  @override
  String get importProviderSheetCancelButton => 'Отмена';

  @override
  String get importProviderSheetImportButton => 'Импорт';

  @override
  String get shareProviderSheetTitle => 'Поделиться провайдером';

  @override
  String get shareProviderSheetDescription =>
      'Скопируйте или поделитесь через QR-код.';

  @override
  String get shareProviderSheetCopiedMessage => 'Скопировано';

  @override
  String get shareProviderSheetCopyButton => 'Копировать';

  @override
  String get shareProviderSheetShareButton => 'Поделиться';

  @override
  String get desktopProviderContextMenuShare => 'Поделиться';

  @override
  String get desktopProviderShareCopyText => 'Копировать текст';

  @override
  String get desktopProviderShareCopyQr => 'Копировать QR';

  @override
  String get providerDetailPageApiBaseUrlLabel => 'Базовый URL API';

  @override
  String get providerDetailPageModelsTitle => 'Модели';

  @override
  String get providerModelsGetButton => 'Получить';

  @override
  String get providerDetailPageCapsVision => 'Зрение';

  @override
  String get providerDetailPageCapsImage => 'Изображения';

  @override
  String get providerDetailPageCapsTool => 'Инструменты';

  @override
  String get providerDetailPageCapsReasoning => 'Рассуждение';

  @override
  String get qrScanPageTitle => 'Сканировать QR';

  @override
  String get qrScanPageInstruction => 'Поместите QR-код в рамку';

  @override
  String get searchServicesPageBackTooltip => 'Назад';

  @override
  String get searchServicesPageTitle => 'Поисковые сервисы';

  @override
  String get searchServicesPageDone => 'Готово';

  @override
  String get searchServicesPageEdit => 'Изменить';

  @override
  String get searchServicesPageAddProvider => 'Добавить провайдера';

  @override
  String get searchServicesPageSearchProviders => 'Поисковые провайдеры';

  @override
  String get searchServicesPageGeneralOptions => 'Общие параметры';

  @override
  String get searchServicesPageAutoTestTitle =>
      'Автопроверка подключений при запуске';

  @override
  String get searchServicesPageWebFetchSection => 'Чтение веб-страниц';

  @override
  String get searchServicesPageWebFetchModeTitle => 'Читать страницы через';

  @override
  String get searchServicesPageWebFetchFollow => 'Как в поисковом сервисе';

  @override
  String searchServicesPageWebFetchFollowValue(String name) {
    return 'Как в поиске · $name';
  }

  @override
  String searchServicesPageWebFetchFollowSubtitle(String name) {
    return 'Сейчас: $name';
  }

  @override
  String get searchServicesPageWebFetchLocal => 'Локально';

  @override
  String get searchServicesPageWebFetchLocalSubtitle =>
      'Бесплатно. Это устройство запрашивает страницу напрямую.';

  @override
  String get searchServicesPageWebFetchProviderSubtitle =>
      'Использует API-ключ и квоту этого сервиса';

  @override
  String get searchServicesPageWebFetchOff => 'Выкл.';

  @override
  String get searchServicesPageWebFetchOffSubtitle =>
      'Только поиск, без чтения страниц';

  @override
  String get searchServicesPageWebFetchFooter =>
      'При включённом веб-поиске модель также может читать страницы целиком. Если поисковый сервис не умеет читать страницы, используется локальное чтение, которое не справляется со страницами, требующими JavaScript, или блокирующими ботов.\n\nЕсли вы используете настроенное здесь чтение страниц, отключите встроенный @kelivo/fetch в разделе «Настройки → MCP», чтобы инструменты не дублировались. Настроенное здесь чтение страниц продолжит работать.';

  @override
  String get searchServicesPageWebFetchSupported => 'Умеет читать веб-страницы';

  @override
  String get searchServicesPageMaxResults => 'Макс. результатов';

  @override
  String get searchServicesPageTimeoutSeconds => 'Тайм-аут (секунды)';

  @override
  String get searchServicesPageAtLeastOneServiceRequired =>
      'Требуется хотя бы один поисковый сервис';

  @override
  String get searchServicesPageTestingStatus => 'Проверка…';

  @override
  String get searchServicesPageConnectedStatus => 'Подключено';

  @override
  String get searchServicesPageFailedStatus => 'Ошибка';

  @override
  String get searchServicesPageNotTestedStatus => 'Не проверено';

  @override
  String get searchServicesPageEditServiceTooltip => 'Изменить сервис';

  @override
  String get searchServicesPageTestConnectionTooltip => 'Проверить подключение';

  @override
  String get searchServicesPageDeleteServiceTooltip => 'Удалить сервис';

  @override
  String get searchServicesPageConfiguredStatus => 'Настроено';

  @override
  String get miniMapTitle => 'Мини-карта';

  @override
  String get miniMapTooltip => 'Мини-карта';

  @override
  String get miniMapScrollToBottomTooltip => 'Прокрутить вниз';

  @override
  String miniMapSearchMatchCount(int count) {
    return '$count';
  }

  @override
  String get miniMapSearchNoResults => 'Нет подходящих сообщений';

  @override
  String get searchServicesPageApiKeyRequiredStatus => 'Требуется API-ключ';

  @override
  String get searchServicesPageUrlRequiredStatus => 'Требуется URL';

  @override
  String get searchServicesAddDialogTitle => 'Добавить поисковый сервис';

  @override
  String get searchServicesAddDialogServiceType => 'Тип сервиса';

  @override
  String get searchServicesAddDialogBingLocal => 'Локальный';

  @override
  String get searchServicesAddDialogCancel => 'Отмена';

  @override
  String get searchServicesAddDialogAdd => 'Добавить';

  @override
  String get searchServicesAddDialogApiKeyRequired => 'Требуется API-ключ';

  @override
  String get searchServicesFieldCustomUrlOptional => 'Свой URL (необязательно)';

  @override
  String get searchServicesDialogApiKey => 'API-ключ';

  @override
  String get searchServicesDialogApiKeyOptional => 'API-ключ (необязательно)';

  @override
  String get searchServicesDialogModel => 'Модель';

  @override
  String get searchServicesDialogSystemPrompt => 'Системный промпт';

  @override
  String get searchServicesAddDialogInstanceUrl => 'URL экземпляра';

  @override
  String get searchServicesAddDialogUrlRequired => 'URL обязателен';

  @override
  String get searchServicesAddDialogEnginesOptional =>
      'Поисковые системы (необязательно)';

  @override
  String get searchServicesAddDialogLanguageOptional => 'Язык (необязательно)';

  @override
  String get searchServicesAddDialogUsernameOptional =>
      'Имя пользователя (необязательно)';

  @override
  String get searchServicesAddDialogPasswordOptional =>
      'Пароль (необязательно)';

  @override
  String get searchServicesAddDialogRegionOptional =>
      'Регион (необязательно, по умолчанию: us-en)';

  @override
  String get searchServicesEditDialogEdit => 'Изменить';

  @override
  String get searchServicesEditDialogCancel => 'Отмена';

  @override
  String get searchServicesEditDialogSave => 'Сохранить';

  @override
  String get searchServicesEditDialogBingLocalNoConfig =>
      'Для локального поиска Bing настройка не требуется.';

  @override
  String get searchServicesEditDialogApiKeyRequired => 'API-ключ обязателен';

  @override
  String get searchServicesEditDialogInstanceUrl => 'URL экземпляра';

  @override
  String get searchServicesEditDialogUrlRequired => 'URL обязателен';

  @override
  String get searchServicesEditDialogEnginesOptional =>
      'Поисковые системы (необязательно)';

  @override
  String get searchServicesEditDialogLanguageOptional => 'Язык (необязательно)';

  @override
  String get searchServicesEditDialogUsernameOptional =>
      'Имя пользователя (необязательно)';

  @override
  String get searchServicesEditDialogPasswordOptional =>
      'Пароль (необязательно)';

  @override
  String get searchServicesEditDialogRegionOptional =>
      'Регион (необязательно, по умолчанию: us-en)';

  @override
  String get searchServiceEditorProviderTypeTitle => 'Поисковый провайдер';

  @override
  String get searchServiceEditorConfigurationTitle => 'Конфигурация';

  @override
  String get searchServiceEditorNoConfiguration =>
      'Этому провайдеру не требуется дополнительная настройка.';

  @override
  String get searchServiceEditorMultiKeyTitle => 'Ротация нескольких ключей';

  @override
  String get searchServiceEditorMultiKeyNone => 'Не настроено';

  @override
  String get searchApiKeysPageDescription =>
      'Ключи используются по очереди в порядке списка; первый — основной. Использование не запрашивается, чтобы избежать ограничений провайдера.';

  @override
  String get searchApiKeysPagePrimaryBadge => 'Основной';

  @override
  String get searchApiKeysPageBatchHint =>
      'Вставьте один или несколько ключей — по одному в строке или через запятую';

  @override
  String searchApiKeysPageBatchResult(String added, String skipped) {
    return 'Добавлено: $added, пропущено дубликатов: $skipped';
  }

  @override
  String get searchApiKeysPageAdd => 'Добавить';

  @override
  String get searchApiKeysPageEmpty => 'Ключи ещё не настроены.';

  @override
  String searchServiceEditorMultiKeyCount(String count) {
    return 'Ключей: $count';
  }

  @override
  String get searchServiceEditorUsageTitle => 'Использование аккаунта';

  @override
  String get searchServiceEditorUsageNotQueried =>
      'Использование ещё не запрашивалось.';

  @override
  String get searchServiceEditorUsageQuery => 'Проверить использование';

  @override
  String get searchServiceEditorUsageQuerying => 'Проверка…';

  @override
  String searchServiceEditorUsageRemaining(String remaining) {
    return 'Осталось кредитов: $remaining';
  }

  @override
  String searchServiceEditorUsageBalance(String balance) {
    return 'Баланс: $balance';
  }

  @override
  String searchServiceEditorUsageUsed(String used, String limit) {
    return 'Использовано $used из $limit кредитов';
  }

  @override
  String searchServiceEditorUsageFailed(String message) {
    return 'Не удалось запросить использование: $message';
  }

  @override
  String get searchServiceEditorTestTitle => 'Тестовый поиск';

  @override
  String get searchServiceEditorTestQueryHint => 'Введите запрос';

  @override
  String get searchServiceEditorTestRun => 'Запустить тестовый поиск';

  @override
  String get searchServiceEditorTestRunning => 'Поиск…';

  @override
  String get searchServiceEditorTestNoResults =>
      'Провайдер не вернул результатов.';

  @override
  String searchServiceEditorTestFailed(String message) {
    return 'Ошибка поиска: $message';
  }

  @override
  String get searchServiceEditorTestModeSearch => 'Поиск';

  @override
  String get searchServiceEditorTestModeFetch => 'Чтение страницы';

  @override
  String get searchServiceEditorTestUrlHint => 'Введите URL';

  @override
  String get searchServiceEditorTestFetchRun => 'Запустить тестовую загрузку';

  @override
  String get searchServiceEditorTestFetchRunning => 'Чтение…';

  @override
  String searchServiceEditorTestFetchFailed(String message) {
    return 'Ошибка загрузки: $message';
  }

  @override
  String searchServiceEditorTestFetchStats(String characters, String seconds) {
    return '$characters символов · $seconds с';
  }

  @override
  String get searchServiceEditorResultOpenTooltip => 'Открыть результат';

  @override
  String get searchServiceEditorDeleteTooltip => 'Удалить поисковый сервис';

  @override
  String get searchServiceEditorDeleteTitle => 'Удалить поисковый сервис?';

  @override
  String searchServiceEditorDeleteMessage(String provider) {
    return 'Удалить $provider? Это действие нельзя отменить.';
  }

  @override
  String get searchServiceEditorDeleteConfirm => 'Удалить';

  @override
  String get searchServiceEditorDiscardTitle => 'Отменить изменения?';

  @override
  String get searchServiceEditorDiscardMessage =>
      'Несохранённые настройки поискового сервиса будут потеряны.';

  @override
  String get searchServiceEditorKeepEditing => 'Продолжить редактирование';

  @override
  String get searchServiceEditorDiscard => 'Отменить';

  @override
  String get searchSettingsSheetTitle => 'Настройки поиска';

  @override
  String get searchSettingsSheetBuiltinSearchTitle => 'Встроенный поиск';

  @override
  String get searchSettingsSheetBuiltinSearchDescription =>
      'Включить встроенный поиск модели';

  @override
  String get searchSettingsSheetClaudeDynamicSearchTitle =>
      'Динамическая фильтрация';

  @override
  String get searchSettingsSheetClaudeDynamicSearchDescription =>
      'Фильтровать результаты для экономии токенов';

  @override
  String get searchSettingsSheetWebSearchTitle => 'Веб-поиск';

  @override
  String get searchSettingsSheetWebSearchDescription =>
      'Включить веб-поиск в чате';

  @override
  String get searchSettingsSheetOpenSearchServicesTooltip =>
      'Открыть поисковые сервисы';

  @override
  String get searchSettingsSheetNoServicesMessage =>
      'Нет сервисов. Добавьте их в разделе «Поисковые сервисы».';

  @override
  String get aboutPageEasterEggMessage =>
      'Спасибо за любопытство! \n (Пасхалки пока нет)';

  @override
  String get aboutPageEasterEggButton => 'Отлично!';

  @override
  String get aboutPageKelivoSearchUnlocked =>
      'Безымянная дверь приоткрылась. Возможно, вы найдёте её в настройках.';

  @override
  String get aboutPageKelivoSearchAlreadyUnlocked =>
      'Вы уже проходили через эту дверь.';

  @override
  String get aboutPageAppName => 'Kelivo';

  @override
  String get aboutPageAppDescription => 'Открытый ИИ-ассистент';

  @override
  String get aboutPageNoQQGroup => 'Группы QQ пока нет';

  @override
  String get aboutPageVersion => 'Версия';

  @override
  String aboutPageVersionDetail(String version, String buildNumber) {
    return '$version / $buildNumber';
  }

  @override
  String get aboutPageSystem => 'Система';

  @override
  String get aboutPageLoadingPlaceholder => '...';

  @override
  String get aboutPageUnknownPlaceholder => '-';

  @override
  String get aboutPagePlatformMacos => 'macOS';

  @override
  String get aboutPagePlatformWindows => 'Windows';

  @override
  String get aboutPagePlatformLinux => 'Linux';

  @override
  String get aboutPagePlatformAndroid => 'Android';

  @override
  String get aboutPagePlatformIos => 'iOS';

  @override
  String aboutPagePlatformOther(String os) {
    return 'Другая ($os)';
  }

  @override
  String get aboutPageWebsite => 'Сайт';

  @override
  String get aboutPageGithub => 'GitHub';

  @override
  String get aboutPageLicense => 'Лицензия';

  @override
  String get aboutPageJoinQQGroup => 'Вступить в нашу группу QQ';

  @override
  String get aboutPageQQGroupOne => 'Kelivo Группа 1';

  @override
  String get aboutPageQQGroupTwo => 'Kelivo Группа 2';

  @override
  String get aboutPageQQGroupThree => 'Kelivo Группа 3';

  @override
  String get aboutPageJoinDiscord => 'Присоединяйтесь к нам в Discord';

  @override
  String get displaySettingsPageShowUserAvatarTitle =>
      'Показывать аватар пользователя';

  @override
  String get displaySettingsPageShowUserAvatarSubtitle =>
      'Показывать аватар пользователя в сообщениях чата';

  @override
  String get displaySettingsPageShowUserNameTimestampTitle =>
      'Показывать имя пользователя и время';

  @override
  String get displaySettingsPageShowUserNameTimestampSubtitle =>
      'Показывать имя пользователя и время под ним в сообщениях чата';

  @override
  String get displaySettingsPageShowUserNameTitle =>
      'Показывать имя пользователя';

  @override
  String get displaySettingsPageShowUserTimestampTitle =>
      'Показывать время пользователя';

  @override
  String get displaySettingsPageShowUserMessageActionsTitle =>
      'Показывать действия с сообщениями пользователя';

  @override
  String get displaySettingsPageShowUserMessageActionsSubtitle =>
      'Показывать кнопки копирования, повторной отправки и другие под вашими сообщениями';

  @override
  String get displaySettingsPageShowModelNameTimestampTitle =>
      'Показывать название модели и время';

  @override
  String get displaySettingsPageShowModelNameTimestampSubtitle =>
      'Показывать название модели и время под ним в сообщениях чата';

  @override
  String get displaySettingsPageShowModelNameTitle =>
      'Показывать название модели';

  @override
  String get displaySettingsPageShowModelTimestampTitle =>
      'Показывать время модели';

  @override
  String get displaySettingsPageShowProviderInChatMessageTitle =>
      'Показывать провайдера после названия модели';

  @override
  String get displaySettingsPageShowProviderInChatMessageSubtitle =>
      'Показывать имя провайдера после ID модели в сообщениях чата (например, модель | провайдер)';

  @override
  String get displaySettingsPageChatModelIconTitle => 'Иконка модели в чате';

  @override
  String get displaySettingsPageChatModelIconSubtitle =>
      'Показывать иконку модели в сообщениях чата';

  @override
  String get displaySettingsPageShowTokenStatsTitle =>
      'Показывать статистику токенов и контекста';

  @override
  String get displaySettingsPageShowTotalTokensTitle =>
      'Показывать токены за весь ход';

  @override
  String get displaySettingsPageShowTotalTokensSubtitle =>
      'Суммировать использование по всем API-запросам в ответе. Если выключено, показывать только последний запрос. Статистика всегда включает все запросы.';

  @override
  String get displaySettingsPageShowTokenStatsSubtitle =>
      'Показывать использование токенов и количество сообщений';

  @override
  String get displaySettingsPageShowThinkingCardsTitle =>
      'Показывать карточки рассуждений';

  @override
  String get displaySettingsPageShowThinkingCardsSubtitle =>
      'Если выключено, карточки рассуждений скрыты в чате.';

  @override
  String get displaySettingsPageShowToolCardsTitle =>
      'Показывать карточки инструментов';

  @override
  String get displaySettingsPageShowToolCardsSubtitle =>
      'Если выключено, карточки использования инструментов скрыты в чате.';

  @override
  String get displaySettingsShowReasoningLevelBadge =>
      'Показывать уровень рассуждения на кнопке';

  @override
  String get displaySettingsShowReasoningLevelBadgeSubtitle =>
      'Показывать текущий уровень рядом с иконкой рассуждения в панели ввода';

  @override
  String get displaySettingsPageAutoCollapseThinkingTitle =>
      'Автоматически сворачивать рассуждение';

  @override
  String get displaySettingsPageAutoCollapseThinkingSubtitle =>
      'Сворачивать рассуждение после завершения';

  @override
  String get displaySettingsPageCollapseThinkingStepsTitle =>
      'Сворачивать шаги рассуждения';

  @override
  String get displaySettingsPageCollapseThinkingStepsSubtitle =>
      'Показывать только последние шаги до раскрытия';

  @override
  String get displaySettingsPageShowToolResultSummaryTitle =>
      'Показывать сводку результатов инструментов';

  @override
  String get displaySettingsPageInsertSuggestionOnlyTitle =>
      'Вставлять предложения без отправки';

  @override
  String get displaySettingsPageShowToolResultSummarySubtitle =>
      'Показывать текст сводки под шагами инструментов';

  @override
  String get displaySettingsPageHideToolResultImagesTitle =>
      'Скрывать изображения в результатах инструментов';

  @override
  String get displaySettingsPageRegenerateDeleteTrailingMessagesTitle =>
      'Удалять сообщения ниже при повторной генерации';

  @override
  String get displaySettingsPageShowRegenerateConfirmDialogTitle =>
      'Подтверждать перед повторной генерацией';

  @override
  String get displaySettingsPageForkKeepMessageVersionsTitle =>
      'Сохранять версии сообщений при создании ветки';

  @override
  String get displaySettingsPageEditAssistantKeepThinkingToolCardsTitle =>
      'Сохранять карточки рассуждений и инструментов при редактировании ассистента';

  @override
  String get displaySettingsPageEditAssistantKeepThinkingToolCardsSubtitle =>
      'Если выключено, отредактированная версия сохраняет только текст ассистента. При переключении обратно предыдущие карточки рассуждений и инструментов всё равно отображаются.';

  @override
  String chainOfThoughtExpandSteps(Object count) {
    return 'Показать ещё $count шаг(ов)';
  }

  @override
  String get chainOfThoughtCollapse => 'Свернуть';

  @override
  String get displaySettingsPageShowChatListDateTitle =>
      'Показывать даты в списке чатов';

  @override
  String get displaySettingsPageShowChatListDateSubtitle =>
      'Показывать метки групп по дате в списке чатов';

  @override
  String get displaySettingsPageEnableImageCropperTitle =>
      'Включить обрезку изображений';

  @override
  String get displaySettingsPageEnableImageCropperSubtitle =>
      'Обрезать изображения после выбора из галереи или камеры';

  @override
  String get displaySettingsPageKeepSidebarOpenOnAssistantTapTitle =>
      'Не закрывать боковую панель при выборе ассистента';

  @override
  String get displaySettingsPageKeepSidebarOpenOnTopicTapTitle =>
      'Не закрывать боковую панель при выборе темы';

  @override
  String get displaySettingsPageKeepAssistantListExpandedOnSidebarCloseTitle =>
      'Не сворачивать список ассистентов при закрытии боковой панели';

  @override
  String get displaySettingsPageShowUpdatesTitle => 'Показывать обновления';

  @override
  String get displaySettingsPageShowUpdatesSubtitle =>
      'Показывать уведомления об обновлениях приложения';

  @override
  String get displaySettingsPageKeepScreenOnDuringGenerationTitle =>
      'Не выключать экран во время генерации';

  @override
  String get displaySettingsPageKeepScreenOnDuringGenerationSubtitle =>
      'Не даёт блокировке экрана прерывать генерацию. Повышает расход батареи.';

  @override
  String get displaySettingsPageMessageNavButtonsTitle =>
      'Кнопки навигации по сообщениям';

  @override
  String get displaySettingsPageMessageNavButtonsSubtitle =>
      'Выберите, когда показывать кнопки быстрого перехода';

  @override
  String get displaySettingsPageMessageNavButtonsModeAlways =>
      'Показывать всегда';

  @override
  String get displaySettingsPageMessageNavButtonsModeScroll =>
      'Показывать при прокрутке';

  @override
  String get displaySettingsPageMessageNavButtonsModeHover =>
      'Показывать при наведении мыши';

  @override
  String get displaySettingsPageMessageNavButtonsModeScrollAndHover =>
      'Показывать при прокрутке или наведении';

  @override
  String get displaySettingsPageMessageNavButtonsModeNever => 'Не показывать';

  @override
  String get displaySettingsPageUseNewAssistantAvatarUxTitle =>
      'Показывать аватар ассистента в заголовке чата';

  @override
  String get displaySettingsPageHapticsOnSidebarTitle =>
      'Тактильный отклик на боковой панели';

  @override
  String get displaySettingsPageHapticsOnSidebarSubtitle =>
      'Включить тактильный отклик при открытии/закрытии боковой панели';

  @override
  String get displaySettingsPageHapticsGlobalTitle =>
      'Глобальный тактильный отклик';

  @override
  String get displaySettingsPageHapticsIosSwitchTitle =>
      'Тактильный отклик переключателей';

  @override
  String get displaySettingsPageHapticsOnListItemTapTitle =>
      'Тактильный отклик на элементах списка';

  @override
  String get displaySettingsPageHapticsOnCardTapTitle =>
      'Тактильный отклик на карточках';

  @override
  String get displaySettingsPageHapticsOnGenerateTitle =>
      'Тактильный отклик при генерации';

  @override
  String get displaySettingsPageHapticsOnGenerateSubtitle =>
      'Включить тактильный отклик во время генерации';

  @override
  String get displaySettingsPageNewChatAfterDeleteTitle =>
      'Новый чат после удаления темы';

  @override
  String get displaySettingsPageNewChatOnAssistantSwitchTitle =>
      'Новый чат при смене ассистента';

  @override
  String get displaySettingsPageNewChatOnLaunchTitle => 'Новый чат при запуске';

  @override
  String get displaySettingsPageEnterToSendTitle => 'Отправка по клавише Enter';

  @override
  String get displaySettingsPageLongPasteAsFileTitle =>
      'Вставлять длинный текст как файл';

  @override
  String get displaySettingsPageLongPasteAsFileThresholdTitle =>
      'Порог преобразования';

  @override
  String get displaySettingsPageLongPasteAsFileThresholdUnit => 'символов';

  @override
  String get displaySettingsPageSendShortcutTitle =>
      'Сочетание клавиш для отправки';

  @override
  String get displaySettingsPageSendShortcutEnter => 'Enter';

  @override
  String get displaySettingsPageSendShortcutCtrlEnter => 'Ctrl/Cmd + Enter';

  @override
  String get displaySettingsPageAutoSwitchTopicsTitle => 'Автопереход к темам';

  @override
  String get desktopDisplaySettingsTopicPositionTitle => 'Положение тем';

  @override
  String get desktopDisplaySettingsTopicPositionLeft => 'Слева';

  @override
  String get desktopDisplaySettingsTopicPositionRight => 'Справа';

  @override
  String get displaySettingsPageNewChatOnLaunchSubtitle =>
      'Автоматически создавать новый чат при запуске';

  @override
  String get displaySettingsPageChatFontSizeTitle => 'Размер шрифта чата';

  @override
  String get displaySettingsPageAutoScrollEnableTitle => 'Автопрокрутка вниз';

  @override
  String get displaySettingsPageAutoScrollDisabledLabel => 'Выкл.';

  @override
  String get displaySettingsPageChatFontSampleText => 'Это пример текста чата';

  @override
  String get displaySettingsPageChatBackgroundMaskTitle =>
      'Непрозрачность затемнения фона чата';

  @override
  String get displaySettingsPageChatInputBackgroundOpacityTitle =>
      'Непрозрачность фона поля ввода';

  @override
  String get displaySettingsPageThemeSettingsTitle => 'Настройки темы';

  @override
  String get displaySettingsPageThemeColorTitle => 'Цвет темы';

  @override
  String get desktopSettingsFontsTitle => 'Шрифты';

  @override
  String get linuxHideTitleBarTitle => 'Скрыть системный заголовок окна';

  @override
  String get linuxHideTitleBarDescription =>
      'Также скрывает кнопки окна. Используйте оконный менеджер для перемещения, изменения размера и закрытия окна.';

  @override
  String get linuxHideTitleBarError =>
      'Не удалось изменить заголовок окна. Попробуйте ещё раз.';

  @override
  String get displaySettingsPageTrayTitle => 'Системный трей';

  @override
  String get displaySettingsPageTrayShowTrayTitle => 'Показывать значок в трее';

  @override
  String get displaySettingsPageTrayMinimizeOnCloseTitle =>
      'Сворачивать в трей при закрытии';

  @override
  String get desktopFontAppLabel => 'Шрифт приложения';

  @override
  String get desktopFontCodeLabel => 'Шрифт кода';

  @override
  String get desktopFontFamilySystemDefault => 'Системный по умолчанию';

  @override
  String get desktopFontFamilyMonospaceDefault => 'Моноширинный';

  @override
  String get desktopFontFilterHint => 'Фильтр шрифтов...';

  @override
  String get displaySettingsPageAppFontTitle => 'Шрифт приложения';

  @override
  String get displaySettingsPageCodeFontTitle => 'Шрифт кода';

  @override
  String get fontPickerChooseLocalFile => 'Выбрать локальный файл';

  @override
  String get desktopFontLoading => 'Загрузка шрифтов…';

  @override
  String get displaySettingsPageFontLocalFileLabel => 'Локальный файл';

  @override
  String get displaySettingsPageFontResetLabel => 'Сбросить настройки шрифта';

  @override
  String get displaySettingsPageOtherSettingsTitle => 'Другие настройки';

  @override
  String get themeSettingsPageDynamicColorSection => 'Динамический цвет';

  @override
  String get themeSettingsPageUseDynamicColorTitle =>
      'Системные динамические цвета';

  @override
  String get themeSettingsPageUseDynamicColorSubtitle =>
      'Следовать системной палитре (Android 12+)';

  @override
  String get themeSettingsPageUsePureBackgroundTitle => 'Чистый фон';

  @override
  String get themeSettingsPageUsePureBackgroundSubtitle =>
      'Пузыри и акценты следуют теме.';

  @override
  String get themeAdvancedSettingsPageTitle => 'Расширенные настройки темы';

  @override
  String get themeAdvancedSettingsPageUseLayeredSurfacesTitle =>
      'Многослойные поверхности (экспериментально)';

  @override
  String get themeAdvancedSettingsPageUseLayeredSurfacesSubtitle =>
      'Страница темнее, карточки светлее; оба сохраняют оттенок темы. Отключите, чтобы вернуть прежний вид.';

  @override
  String get themeAdvancedSettingsPageUseLayeredSheetTilesTitle =>
      'Многослойные плитки в окнах';

  @override
  String get themeAdvancedSettingsPageUseLayeredSheetTilesSubtitle =>
      'По умолчанию плитки совпадают с фоном окна.';

  @override
  String get themeSettingsPageColorPalettesSection => 'Цветовые палитры';

  @override
  String get themeSettingsPageCustomPaletteName => 'Пользовательская';

  @override
  String get themeSettingsPageCustomColorReset => 'Сбросить';

  @override
  String get themeSettingsPageCustomThemesSection => 'Пользовательские темы';

  @override
  String get customThemeNewTheme => 'Новая тема';

  @override
  String get customThemeEditTheme => 'Изменить тему';

  @override
  String get customThemeImportTheme => 'Импорт темы';

  @override
  String get customThemeNameLabel => 'Название темы';

  @override
  String get customThemePrimaryColor => 'Основной';

  @override
  String get customThemeSecondaryColor => 'Дополнительный';

  @override
  String get customThemeTertiaryColor => 'Третичный';

  @override
  String get customThemeColorAuto => 'Авто';

  @override
  String get customThemeSave => 'Сохранить';

  @override
  String get customThemeCancel => 'Отмена';

  @override
  String get customThemeDelete => 'Удалить';

  @override
  String get customThemeDeleteConfirm => 'Удалить эту тему?';

  @override
  String get customThemeCopied => 'JSON темы скопирован в буфер обмена';

  @override
  String get customThemeCopyAction => 'Копировать';

  @override
  String get customThemeImportHint => 'Вставьте JSON темы здесь';

  @override
  String get customThemeImportInvalid => 'Неверный JSON темы';

  @override
  String get customThemeHexLabel => 'Hex';

  @override
  String get ttsServicesPageBackButton => 'Назад';

  @override
  String get ttsServicesPageTitle => 'Голосовые сервисы';

  @override
  String get ttsServicesSectionTitle => 'Синтез речи';

  @override
  String get ttsServicesPageSettingsTooltip => 'Настройки TTS';

  @override
  String get ttsServicesPageAddTooltip => 'Добавить';

  @override
  String get asrServicesSectionTitle => 'Распознавание речи';

  @override
  String get asrServicesSectionDescription =>
      'Преобразуйте речь в текст с помощью локального, системного или облачного сервиса.';

  @override
  String get asrServicesAddTooltip => 'Добавить сервис распознавания речи';

  @override
  String get asrServicesEmptyTitle => 'Нет сервиса распознавания речи';

  @override
  String get asrServicesEmptySubtitle =>
      'Добавьте его, чтобы в поле ввода чата появился микрофон.';

  @override
  String get asrServicesOnDeviceGroup => 'На устройстве';

  @override
  String get asrServicesCloudGroup => 'Облако';

  @override
  String get asrServicesSystemTitle => 'Система';

  @override
  String get asrServicesSystemSubtitle =>
      'Использует встроенный распознаватель устройства';

  @override
  String get asrServicesLocalTitle => 'Офлайн-модель';

  @override
  String get asrServicesLocalSubtitle =>
      'Работает офлайн на этом устройстве после загрузки';

  @override
  String get asrServicesOpenAiTitle => 'OpenAI Realtime';

  @override
  String get asrServicesOpenAiSubtitle =>
      'Потоковая транскрипция с низкой задержкой';

  @override
  String get asrServicesGroqSubtitle => 'Сегментированная транскрипция Whisper';

  @override
  String get asrServicesMistralSubtitle =>
      'Сегментированная транскрипция Voxtral';

  @override
  String get asrServicesElevenLabsSubtitle =>
      'Сегментированная транскрипция Scribe';

  @override
  String get asrServicesDashScopeTitle => 'DashScope';

  @override
  String get asrServicesDashScopeSubtitle =>
      'Транскрипция Qwen в реальном времени';

  @override
  String get asrServicesVolcengineTitle => 'Volcengine';

  @override
  String get asrServicesVolcengineSubtitle => 'Потоковая транскрипция Doubao';

  @override
  String get asrServicesMimoTitle => 'MiMo';

  @override
  String get asrServicesMimoSubtitle =>
      'Сегментированная облачная транскрипция';

  @override
  String get asrServicesStepTitle => 'Step';

  @override
  String get asrServicesStepSubtitle =>
      'Сегментированная транскрипция Step Audio';

  @override
  String get asrServicesAddTitle => 'Добавить распознавание речи';

  @override
  String get asrServicesEditTitle => 'Изменить распознавание речи';

  @override
  String get asrServicesSelectedLabel => 'Выбрано';

  @override
  String get asrServicesUnavailableLabel => 'Недоступно';

  @override
  String get asrServicesEditAction => 'Изменить';

  @override
  String get asrServicesDeleteAction => 'Удалить';

  @override
  String get asrServicesCancelAction => 'Отмена';

  @override
  String get asrServicesAddAction => 'Добавить';

  @override
  String get asrServicesSaveAction => 'Сохранить';

  @override
  String get asrServicesNameLabel => 'Название';

  @override
  String get asrServicesApiKeyLabel => 'API Key';

  @override
  String get asrServicesEndpointLabel => 'Конечная точка';

  @override
  String get asrServicesRecognitionModeLabel => 'Режим распознавания';

  @override
  String get asrServicesRealtimeMode => 'В реальном времени';

  @override
  String get asrServicesRecordedMode => 'Записанный звук';

  @override
  String get asrServicesQwenAudioSubtitle =>
      'Транскрипция в реальном времени или записанного звука';

  @override
  String get asrServicesQwenTokenPlanHint =>
      'Для Token Plan выберите «Записанный звук», укажите token-plan в качестве ID рабочей области и выберите регион, соответствующий вашему ключу.';

  @override
  String get asrServicesWorkspaceIdHint => 'например, token-plan';

  @override
  String get asrServicesEndpointOverrideLabel =>
      'Своя конечная точка (необязательно)';

  @override
  String get asrServicesWorkspaceIdInvalid =>
      'Введите ID рабочей области, а не URL.';

  @override
  String get asrServicesWebSocketEndpointInvalid =>
      'Введите полную конечную точку ws:// или wss:// без учётных данных и фрагмента.';

  @override
  String get asrServicesHttpEndpointInvalid =>
      'Введите полную конечную точку http:// или https:// без учётных данных и фрагмента.';

  @override
  String get asrServicesModelLabel => 'Модель';

  @override
  String get asrServicesResourceIdLabel => 'ID ресурса';

  @override
  String get asrServicesLanguageLabel => 'Язык';

  @override
  String get asrServicesAutomaticLabel => 'Автоматически';

  @override
  String get asrServicesApiKeyRequired =>
      'Введите API-ключ, чтобы использовать этот сервис.';

  @override
  String get asrServicesChooseModelTitle => 'Модель';

  @override
  String get asrServicesModelDownloadAction => 'Скачать';

  @override
  String get asrServicesModelUseAction => 'Использовать модель';

  @override
  String get asrServicesModelDeleteAction => 'Удалить загрузку';

  @override
  String get asrServicesModelDownloadedLabel => 'Загружено';

  @override
  String get asrServicesModelDownloadingLabel => 'Загрузка…';

  @override
  String get asrServicesModelNotDownloadedLabel => 'Не загружено';

  @override
  String asrServicesDownloadFailed(String error) {
    return 'Не удалось загрузить модель: $error';
  }

  @override
  String get asrServicesSystemChecking => 'Проверка…';

  @override
  String get asrServicesSystemAvailable => 'Доступно';

  @override
  String get asrServicesSystemCheckFailed =>
      'Системное распознавание речи недоступно на этом устройстве.';

  @override
  String get asrServicesMicrophonePermissionDenied =>
      'Разрешение на использование микрофона не предоставлено.';

  @override
  String get asrServicesNoSpeechDetected => 'Речь не обнаружена.';

  @override
  String asrServicesRecognitionFailed(String error) {
    return 'Ошибка распознавания речи: $error';
  }

  @override
  String get ttsServicesPageAddNotImplemented =>
      'Добавление TTS-сервиса пока не реализовано';

  @override
  String get ttsServicesPageSystemTtsTitle => 'Системный TTS';

  @override
  String get ttsServicesPageSystemTtsAvailableSubtitle =>
      'Использовать встроенный системный TTS';

  @override
  String ttsServicesPageSystemTtsUnavailableSubtitle(String error) {
    return 'Недоступно: $error';
  }

  @override
  String get ttsServicesPageSystemTtsUnavailableNotInitialized =>
      'не инициализировано';

  @override
  String get ttsServicesPageTestSpeechText =>
      'Здравствуйте, это тестовая речь.';

  @override
  String get ttsServicesPageConfigureTooltip => 'Настроить';

  @override
  String get ttsServicesPageTestVoiceTooltip => 'Проверить голос';

  @override
  String get ttsServicesPageStopTooltip => 'Остановить';

  @override
  String get ttsServicesPageDeleteTooltip => 'Удалить';

  @override
  String get ttsServicesPageSystemTtsSettingsTitle =>
      'Настройки системного TTS';

  @override
  String get ttsServicesPageEngineLabel => 'Движок';

  @override
  String get ttsServicesPageAutoLabel => 'Авто';

  @override
  String get ttsServicesPageLanguageLabel => 'Язык';

  @override
  String get ttsServicesPageSpeechRateLabel => 'Скорость речи';

  @override
  String get ttsServicesPagePitchLabel => 'Тон';

  @override
  String get ttsServicesPageSettingsSavedMessage => 'Настройки сохранены.';

  @override
  String get ttsServicesPageDoneButton => 'Готово';

  @override
  String get ttsServicesPageNetworkSectionTitle => 'Сетевой TTS';

  @override
  String get ttsServicesPageNoNetworkServices => 'Нет TTS-сервисов.';

  @override
  String get ttsServicesDialogAddTitle => 'Добавить TTS-сервис';

  @override
  String get ttsServicesDialogEditTitle => 'Изменить TTS-сервис';

  @override
  String get ttsServicesDialogProviderType => 'Провайдер';

  @override
  String get ttsServicesDialogCancelButton => 'Отмена';

  @override
  String get ttsServicesDialogAddButton => 'Добавить';

  @override
  String get ttsServicesDialogSaveButton => 'Сохранить';

  @override
  String get ttsServicesFieldNameLabel => 'Название';

  @override
  String get ttsServicesFieldApiKeyLabel => 'API-ключ';

  @override
  String get ttsServicesFieldBaseUrlLabel => 'Базовый URL API';

  @override
  String get ttsServicesFieldModelLabel => 'Модель';

  @override
  String get ttsServicesFieldVoiceLabel => 'Голос';

  @override
  String get ttsServicesFieldVoiceIdLabel => 'ID голоса';

  @override
  String get ttsServicesFieldEmotionLabel => 'Эмоция';

  @override
  String get ttsServicesFieldSpeedLabel => 'Скорость';

  @override
  String get ttsServicesFieldLanguageTypeLabel => 'Тип языка';

  @override
  String get ttsServicesFieldLanguageLabel => 'Язык';

  @override
  String get ttsServicesFieldWorkspaceIdLabel => 'ID рабочей области';

  @override
  String get ttsServicesFieldRegionLabel => 'Регион';

  @override
  String get ttsServicesFieldFormatLabel => 'Формат аудио';

  @override
  String get ttsServicesFieldOutputFormatLabel => 'Формат вывода';

  @override
  String get ttsServicesFieldSampleRateLabel => 'Частота дискретизации';

  @override
  String get ttsServicesFieldVolumeLabel => 'Громкость';

  @override
  String get ttsServicesFieldPitchLabel => 'Тон';

  @override
  String get ttsServicesFieldLanguageBoostLabel => 'Усиление языка';

  @override
  String get ttsServicesFieldBitrateLabel => 'Битрейт';

  @override
  String get ttsServicesFieldChannelLabel => 'Каналы';

  @override
  String get ttsServicesFieldSubtitlesLabel => 'Создавать субтитры';

  @override
  String get ttsServicesFieldPronunciationDictionaryLabel =>
      'Словарь произношения (одна запись на строку)';

  @override
  String get ttsServicesFieldInstructionLabel => 'Стиль / описание голоса';

  @override
  String get ttsServicesFieldStreamingLabel => 'Потоковая передача';

  @override
  String get ttsServicesFieldOptimizeTextPreviewLabel =>
      'Оптимизировать текст для озвучивания';

  @override
  String get ttsServicesFieldReferenceAudioLabel =>
      'Опорное аудио (data URI WAV/MP3)';

  @override
  String get ttsServicesFieldChooseReferenceAudioButton =>
      'Выбрать опорное аудио';

  @override
  String get ttsServicesFieldTemperatureLabel => 'Температура';

  @override
  String get ttsServicesFieldTopPLabel => 'Top P';

  @override
  String get ttsServicesFieldLatencyLabel => 'Задержка';

  @override
  String get ttsServicesEmotionAutoLabel => 'Автоподбор';

  @override
  String get ttsServicesValidationApiKeyRequired => 'Требуется API Key';

  @override
  String get ttsServicesValidationReferenceIdRequired =>
      'Требуется ID голоса/опорного аудио';

  @override
  String get ttsServicesValidationInstructionRequired =>
      'Требуется описание голоса';

  @override
  String ttsServicesValidationSampleRate(String format, String rates) {
    return '$format требует $rates Гц.';
  }

  @override
  String get ttsServicesViewDetailsButton => 'Подробнее';

  @override
  String get ttsServicesDialogErrorTitle => 'Подробности ошибки';

  @override
  String get ttsServicesCloseButton => 'Закрыть';

  @override
  String get ttsSettingsPageTitle => 'Настройки TTS';

  @override
  String get ttsSettingsPlaybackSection => 'Воспроизведение';

  @override
  String get ttsSettingsAutoPlayTitle =>
      'Автовоспроизведение ответов ассистента';

  @override
  String get ttsSettingsAutoPlayDescription =>
      'Автоматически запускать TTS после завершения ответа ассистента.';

  @override
  String get ttsSettingsCacheReplayTitle => 'Использовать кэш при повторе';

  @override
  String get ttsSettingsCacheReplayDescription =>
      'Повторно воспроизводить созданное сетевое аудио без нового запроса к сервису TTS.';

  @override
  String get ttsSettingsTextSelectionSection => 'Выбор текста';

  @override
  String get ttsSettingsTextSelectionFallbackDescription =>
      'Если подходящий текст не найден, воспроизводится весь ответ.';

  @override
  String get ttsSettingsTextSelectionFullTextTitle => 'Весь текст';

  @override
  String get ttsSettingsTextSelectionFullTextDescription =>
      'Воспроизводить полный ответ ассистента.';

  @override
  String get ttsSettingsTextSelectionQuotedOnlyTitle =>
      'Только текст в кавычках';

  @override
  String get ttsSettingsTextSelectionQuotedOnlyDescription =>
      'Воспроизводить текст внутри “”, ‘’, \"\", \'\', 「」 или 『』.';

  @override
  String get ttsSettingsTextSelectionOutsideParenthesesTitle =>
      'Текст вне скобок';

  @override
  String get ttsSettingsTextSelectionOutsideParenthesesDescription =>
      'Пропускать текст внутри () и （）.';

  @override
  String get ttsSettingsTextSelectionItalicOnlyTitle => 'Только курсив';

  @override
  String get ttsSettingsTextSelectionItalicOnlyDescription =>
      'Воспроизводить курсивный текст Markdown или HTML.';

  @override
  String get ttsSettingsTextSelectionNonItalicTitle =>
      'Только текст без курсива';

  @override
  String get ttsSettingsTextSelectionNonItalicDescription =>
      'Пропускать курсивный текст Markdown или HTML.';

  @override
  String get ttsFloatingPlayerLabel => 'Плеер TTS';

  @override
  String get ttsFloatingPauseTooltip => 'Пауза';

  @override
  String get ttsFloatingResumeTooltip => 'Продолжить';

  @override
  String get ttsFloatingReplayTooltip => 'Повторить';

  @override
  String get ttsFloatingRewind15Tooltip => 'Назад на 15 секунд';

  @override
  String get ttsFloatingForward15Tooltip => 'Вперёд на 15 секунд';

  @override
  String get ttsFloatingSpeedTooltip => 'Скорость воспроизведения';

  @override
  String get ttsFloatingCloseTooltip => 'Закрыть плеер';

  @override
  String get ttsFloatingExpandTooltip =>
      'Развернуть элементы управления воспроизведением';

  @override
  String get ttsFloatingCollapseTooltip =>
      'Свернуть элементы управления воспроизведением';

  @override
  String get ttsFloatingSaveTooltip => 'Сохранить аудио';

  @override
  String get ttsSaveDialogTitle => 'Сохранить аудио TTS';

  @override
  String get ttsSaveSuccess => 'Аудио успешно сохранено.';

  @override
  String get ttsSaveNothing => 'Нет аудио для сохранения.';

  @override
  String ttsSaveFailed(String message) {
    return 'Не удалось сохранить аудио: $message';
  }

  @override
  String imageViewerPageShareFailedOpenFile(String message) {
    return 'Не удалось поделиться, попытка открыть файл: $message';
  }

  @override
  String imageViewerPageShareFailed(String error) {
    return 'Не удалось поделиться: $error';
  }

  @override
  String get imageViewerPageShareButton => 'Поделиться изображением';

  @override
  String get imageViewerPageCloseButton => 'Закрыть просмотр';

  @override
  String get imageViewerPageSaveButton => 'Сохранить изображение';

  @override
  String get imageViewerPageCopyButton => 'Копировать изображение';

  @override
  String get imageViewerPagePreviousButton => 'Предыдущее изображение';

  @override
  String get imageViewerPageNextButton => 'Следующее изображение';

  @override
  String get imageViewerPageZoomInButton => 'Увеличить';

  @override
  String get imageViewerPageZoomOutButton => 'Уменьшить';

  @override
  String get imageViewerPageResetZoomButton => 'Сбросить масштаб';

  @override
  String get imageViewerPageFlipHorizontalButton => 'Отразить по горизонтали';

  @override
  String get imageViewerPageFlipVerticalButton => 'Отразить по вертикали';

  @override
  String get imageViewerPageRotateLeftButton => 'Повернуть влево';

  @override
  String get imageViewerPageRotateRightButton => 'Повернуть вправо';

  @override
  String imageViewerPageCounter(int index, int total) {
    return '$index/$total';
  }

  @override
  String imageViewerPageImageLabel(int index, int total) {
    return 'Изображение $index из $total';
  }

  @override
  String get imageViewerPageImageLoadFailed =>
      'Не удалось загрузить изображение';

  @override
  String get imageViewerPageSaveSuccess => 'Сохранено в галерею';

  @override
  String imageViewerPageSaveFailed(String error) {
    return 'Не удалось сохранить: $error';
  }

  @override
  String get settingsShare => 'Kelivo — открытый ИИ-ассистент';

  @override
  String get searchProviderBingLocalDescription =>
      'Получает результаты Bing путём парсинга веб-страниц. API-ключ не требуется; может работать нестабильно.';

  @override
  String get searchProviderDuckDuckGoDescription =>
      'Приватный поиск DuckDuckGo через DDGS. API-ключ не требуется; поддерживает выбор региона.';

  @override
  String get searchProviderBraveDescription =>
      'Независимая поисковая система от Brave. Ориентирована на приватность, без отслеживания и профилирования.';

  @override
  String get searchProviderExaDescription =>
      'Нейронный поиск с семантическим пониманием. Отлично подходит для исследований и поиска конкретного контента.';

  @override
  String get searchProviderExaMcpDescription =>
      'Поиск Exa через MCP. API-ключ необязателен для ограниченного бесплатного использования.';

  @override
  String get searchProviderLinkUpDescription =>
      'Поисковый API с ответами по источникам. Предоставляет как результаты, так и сводки, созданные ИИ.';

  @override
  String get searchProviderMetasoDescription =>
      'Китайский поиск от Metaso. Оптимизирован для китайского контента с возможностями ИИ.';

  @override
  String get searchProviderSearXNGDescription =>
      'Метапоисковик, уважающий приватность. Требуется собственный экземпляр; без отслеживания.';

  @override
  String get searchProviderTavilyDescription =>
      'Поисковый API на базе ИИ, оптимизированный для LLM. Предоставляет качественные релевантные результаты.';

  @override
  String get searchProviderZhipuDescription =>
      'Китайский ИИ-поиск от Zhipu AI. Оптимизирован для китайского контента и запросов.';

  @override
  String get searchProviderOllamaDescription =>
      'API веб-поиска Ollama. Дополняет модели актуальной информацией.';

  @override
  String get searchProviderDeepSeekDescription =>
      'Официальные API веб-поиска и загрузки страниц DeepSeek. Использует API-ключ DeepSeek.';

  @override
  String get searchProviderJinaDescription =>
      'Основа для ИИ-поиска с эмбеддингами, реранкерами, веб-ридером, глубоким поиском и малыми языковыми моделями. Многоязычный и мультимодальный.';

  @override
  String get searchServiceNameBingLocal => 'Bing (локальный)';

  @override
  String get searchServiceNameDuckDuckGo => 'DuckDuckGo';

  @override
  String get searchServiceNameTavily => 'Tavily';

  @override
  String get searchServiceNameExa => 'Exa';

  @override
  String get searchServiceNameExaMcp => 'Exa MCP';

  @override
  String get searchServiceNameZhipu => 'Zhipu AI';

  @override
  String get searchServiceNameSearXNG => 'SearXNG';

  @override
  String get searchServiceNameLinkUp => 'LinkUp';

  @override
  String get searchServiceNameBrave => 'Brave Search';

  @override
  String get searchServiceNameMetaso => 'Metaso';

  @override
  String get searchServiceNameOllama => 'Ollama';

  @override
  String get searchServiceNameDeepSeek => 'DeepSeek';

  @override
  String get searchServiceNameJina => 'Jina';

  @override
  String get searchServiceNamePerplexity => 'Perplexity';

  @override
  String get searchProviderPerplexityDescription =>
      'Perplexity Search API. Ранжированные веб-результаты с фильтрами по региону и домену.';

  @override
  String get searchServiceNameBocha => 'Bocha';

  @override
  String get searchProviderBochaDescription =>
      'Bocha web search API. Точные веб-результаты с необязательными сводками.';

  @override
  String get searchServiceNameDoubao => 'Doubao';

  @override
  String get searchProviderDoubaoDescription =>
      'Doubao web search API от Volcano Engine.';

  @override
  String get searchServiceNameSerper => 'Serper';

  @override
  String get searchProviderSerperDescription =>
      'Serper Google Search API. Быстрые веб-результаты с необязательными фильтрами по стране, языку, времени и странице.';

  @override
  String get searchServiceNameQuerit => 'Querit';

  @override
  String get searchProviderQueritDescription =>
      'Querit Search API для приложений LLM. Возвращает веб-результаты в реальном времени с фильтрами по сайту, времени, стране и языку.';

  @override
  String get searchServiceNameGrok => 'Grok';

  @override
  String get searchProviderGrokDescription =>
      'Поиск Grok через xAI Responses API. Использует инструменты веб-поиска и поиска по X и возвращает источники со ссылками.';

  @override
  String get searchServiceNameStepFun => 'StepFun';

  @override
  String get searchProviderStepFunDescription =>
      'Веб-поиск StepFun через POST /v1/search.';

  @override
  String get searchServiceNameFirecrawl => 'Firecrawl';

  @override
  String get searchProviderFirecrawlDescription =>
      'Firecrawl Search API v2. API-ключ необязателен. Scrape здесь не поддерживается.';

  @override
  String get searchServiceNameTinyFish => 'TinyFish';

  @override
  String get searchProviderTinyFishDescription =>
      'TinyFish Search API с фильтрами по региону и языку. Требуется API-ключ. Fetch/Scrape здесь не поддерживается.';

  @override
  String get searchServiceNameAnySearch => 'AnySearch';

  @override
  String get searchProviderAnySearchDescription =>
      'Единый поиск для AI-агентов с автоматической маршрутизацией по веб-и специализированным источникам данных. API-ключ необязателен.';

  @override
  String get searchServiceNameKagi => 'Kagi';

  @override
  String get searchProviderKagiDescription =>
      'Kagi Search API. Возвращает премиальные результаты веб-поиска от Kagi.';

  @override
  String get searchServiceNameKimi => 'Kimi';

  @override
  String get searchProviderKimiDescription =>
      'Kimi Search API. Pro возвращает фрагменты релевантного веб-контента; Basic возвращает заголовки, ссылки и сниппеты.';

  @override
  String get searchServiceNameParallel => 'Parallel';

  @override
  String get searchProviderParallelDescription =>
      'Parallel Search API. Возвращает оптимизированные для LLM веб-выдержки в режимах turbo, fast, basic и advanced.';

  @override
  String get searchServicesDialogSearchMode => 'Режим поиска';

  @override
  String get searchServiceNameYou => 'You.com';

  @override
  String get searchProviderYouDescription =>
      'You.com Search API. Возвращает веб-результаты и новости с highlights или сниппетами.';

  @override
  String get searchServicesDialogContentMode => 'Режим контента';

  @override
  String get searchServicesDialogHighlights => 'Highlights';

  @override
  String get searchServicesDialogSnippets => 'Snippets';

  @override
  String get searchServicesDialogWebSearch => 'Web Search';

  @override
  String get searchServicesDialogLlmContext => 'LLM Context';

  @override
  String get searchServicesDialogMaximumTokens => 'Максимум токенов';

  @override
  String get searchServicesDialogMaximumTokensInvalid =>
      'Максимум токенов должен быть от 1024 до 32768.';

  @override
  String get searchServiceNameKelivo => 'Kelivo';

  @override
  String get searchServicesDialogCountryOptional =>
      'Страна/регион (необязательно)';

  @override
  String get searchServicesDialogLanguageOptional => 'Язык (необязательно)';

  @override
  String get searchServicesDialogTimeFilterOptional =>
      'Фильтр по времени (необязательно)';

  @override
  String get searchServicesDialogPageOptional => 'Страница (необязательно)';

  @override
  String get searchServicesDialogPageInvalid =>
      'Номер страницы должен быть положительным целым числом.';

  @override
  String get searchServicesDialogSitesIncludeOptional =>
      'Включаемые сайты (необязательно)';

  @override
  String get searchServicesDialogSitesExcludeOptional =>
      'Исключаемые сайты (необязательно)';

  @override
  String get searchServicesDialogTimeRangeOptional =>
      'Диапазон времени (необязательно)';

  @override
  String get searchServicesDialogCountriesOptional => 'Страны (необязательно)';

  @override
  String get searchServicesDialogLanguagesOptional => 'Языки (необязательно)';

  @override
  String get searchServicesDialogSitesHint => 'example.com, docs.example.com';

  @override
  String get searchServicesDialogTimeRangeHint => 'd7';

  @override
  String get searchServicesDialogCountriesHint => 'united states, japan';

  @override
  String get searchServicesDialogLanguagesHint => 'english, japanese';

  @override
  String get generationInterrupted => 'Генерация прервана';

  @override
  String get titleForLocale => 'Новый чат';

  @override
  String get temporaryChatTitle => 'Временный чат';

  @override
  String get temporaryChatEmptyMessage =>
      'Временные чаты не отображаются в истории и будут полностью удалены после выхода.';

  @override
  String get temporaryChatToggleTooltip => 'Переключить временный чат';

  @override
  String get quickPhraseBackTooltip => 'Назад';

  @override
  String get quickPhraseGlobalTitle => 'Быстрая фраза';

  @override
  String get quickPhraseAssistantTitle => 'Быстрые фразы ассистента';

  @override
  String get quickPhraseAddTooltip => 'Добавить быструю фразу';

  @override
  String get quickPhraseEmptyMessage => 'Быстрых фраз пока нет';

  @override
  String get quickPhraseAddTitle => 'Добавить быструю фразу';

  @override
  String get quickPhraseEditTitle => 'Изменить быструю фразу';

  @override
  String get quickPhraseTitleLabel => 'Название';

  @override
  String get quickPhraseContentLabel => 'Содержание';

  @override
  String get quickPhraseCancelButton => 'Отмена';

  @override
  String get quickPhraseSaveButton => 'Сохранить';

  @override
  String get instructionInjectionTitle => 'Внедрение инструкций';

  @override
  String get instructionInjectionBackTooltip => 'Назад';

  @override
  String get instructionInjectionAddTooltip => 'Добавить инструкцию';

  @override
  String get instructionInjectionImportTooltip => 'Импорт из файлов';

  @override
  String get instructionInjectionEmptyMessage =>
      'Карточек внедрения инструкций пока нет';

  @override
  String get instructionInjectionDefaultTitle => 'Режим обучения';

  @override
  String get instructionInjectionAddTitle => 'Добавить внедрение инструкции';

  @override
  String get instructionInjectionEditTitle => 'Изменить внедрение инструкции';

  @override
  String get instructionInjectionNameLabel => 'Название';

  @override
  String get instructionInjectionPromptLabel => 'Промпт';

  @override
  String get instructionInjectionUngroupedGroup => 'Без группы';

  @override
  String get instructionInjectionGroupLabel => 'Группа';

  @override
  String get instructionInjectionGroupHint => 'Необязательно';

  @override
  String instructionInjectionImportSuccess(int count) {
    return 'Импортировано инструкций: $count';
  }

  @override
  String get instructionInjectionSheetSubtitle =>
      'Выберите промпт для применения перед чатом';

  @override
  String get mcpJsonEditButtonTooltip => 'Изменить JSON';

  @override
  String get mcpJsonEditTitle => 'Изменить JSON';

  @override
  String get mcpJsonEditParseFailed => 'Не удалось разобрать JSON';

  @override
  String get mcpJsonEditSavedApplied => 'Сохранено и применено';

  @override
  String get mcpTimeoutSettingsTooltip =>
      'Настроить тайм-аут вызова инструмента';

  @override
  String get mcpTimeoutDialogTitle => 'Тайм-аут вызова инструмента';

  @override
  String get mcpTimeoutSecondsLabel => 'Тайм-аут вызова инструмента (секунды)';

  @override
  String get mcpTimeoutInvalid => 'Введите положительное число секунд';

  @override
  String get quickPhraseEditButton => 'Изменить';

  @override
  String get quickPhraseDeleteButton => 'Удалить';

  @override
  String get quickPhraseMenuTitle => 'Быстрая фраза';

  @override
  String get chatInputBarQuickPhraseTooltip => 'Быстрая фраза';

  @override
  String get assistantEditQuickPhraseDescription =>
      'Управляйте быстрыми фразами этого ассистента. Нажмите кнопку ниже, чтобы добавить фразы.';

  @override
  String get assistantEditManageQuickPhraseButton =>
      'Управление быстрыми фразами';

  @override
  String get assistantEditPageMemoryTab => 'Память';

  @override
  String get assistantEditLocalToolTimeInfoTitle => 'Информация о времени';

  @override
  String get assistantEditLocalToolTimeInfoSubtitle =>
      'Чтение даты, дня недели, времени, часового пояса, смещения UTC и отметки времени устройства.';

  @override
  String get assistantEditLocalToolClipboardTitle => 'Буфер обмена';

  @override
  String get assistantEditLocalToolClipboardSubtitle =>
      'Чтение или запись простого текста из буфера обмена устройства при явной необходимости.';

  @override
  String get assistantEditLocalToolTextToSpeechTitle => 'Синтез речи';

  @override
  String get assistantEditLocalToolTextToSpeechSubtitle =>
      'Позволить ассистенту озвучивать текст с помощью настроенного воспроизведения TTS.';

  @override
  String get assistantEditLocalToolAskUserTitle => 'Спросить пользователя';

  @override
  String get assistantEditLocalToolAskUserSubtitle =>
      'Позволить ассистенту задавать короткие вопросы и продолжать после вашего ответа.';

  @override
  String get assistantEditLocalToolCalculateTitle => 'Калькулятор';

  @override
  String get assistantEditLocalToolCalculateSubtitle =>
      'Вычисление математических выражений, поддерживаются + - * / степень sqrt sin cos и др.';

  @override
  String get assistantEditLocalToolScreenTimeTitle => 'Экранное время';

  @override
  String get assistantEditLocalToolScreenTimeSubtitle =>
      'Запрос времени использования приложений на этом устройстве, требуется разрешение на доступ к данным об использовании.';

  @override
  String get chatMessageWidgetScreenTimeTotal => 'Общее экранное время';

  @override
  String get chatMessageWidgetScreenTimePermissionRequired =>
      'Разрешение на доступ к данным об использовании не предоставлено. Включите его в системных настройках и повторите попытку.';

  @override
  String get assistantEditLocalToolCalendarQueryTitle => 'Запрос календаря';

  @override
  String get assistantEditLocalToolCalendarQuerySubtitle =>
      'Чтение событий календаря на этом устройстве, требуется разрешение на календарь.';

  @override
  String get assistantEditLocalToolCalendarCreateTitle => 'Создать событие';

  @override
  String get assistantEditLocalToolCalendarCreateSubtitle =>
      'Создание событий календаря на этом устройстве после вашего подтверждения, требуется разрешение на календарь.';

  @override
  String get assistantEditLocalToolLocationTitle => 'Текущее местоположение';

  @override
  String get assistantEditLocalToolLocationSubtitle =>
      'Однократное чтение местоположения с этого устройства, требуется разрешение на геолокацию.';

  @override
  String get assistantEditLocalToolWeatherTitle => 'Погода';

  @override
  String get assistantEditLocalToolWeatherSubtitle =>
      'Получение Apple Weather для текущего или указанного местоположения. В результате отображается атрибуция WeatherKit.';

  @override
  String get assistantEditLocalToolHealthTitle => 'Сводка здоровья';

  @override
  String get assistantEditLocalToolHealthSubtitle =>
      'Чтение конфиденциальной сводки активности из Apple Health, требуется доступ к Health.';

  @override
  String assistantEditLocalToolHealthSelectedCount(int selected, int total) {
    return 'Выбрано $selected/$total';
  }

  @override
  String get healthDataSettingsTitle => 'Данные здоровья';

  @override
  String get healthDataSettingsDescription =>
      'Сигналы HealthKit, доступные текущему ассистенту в повседневном чате. Переключатели определяют, что Kelivo может попытаться прочитать; фактический доступ по-прежнему управляется iOS.';

  @override
  String healthDataSettingsBadge(int selected, int total) {
    return 'Включено $selected/$total';
  }

  @override
  String get healthDataSettingsIosReadTitle => 'Чтение Health в iOS';

  @override
  String get healthDataSettingsIosReadSubtitle =>
      'Устройство доступно, диапазон чтения управляется iOS';

  @override
  String get healthDataSettingsOpenSystemSettings =>
      'Открыть системные настройки';

  @override
  String get healthDataSettingsEnableAll => 'Включить все';

  @override
  String get healthDataSettingsDisableAll => 'Отключить все';

  @override
  String get healthDataSettingsCategoryActivity => 'Активность';

  @override
  String get healthDataSettingsCategoryRest => 'Отдых';

  @override
  String get healthDataSettingsCategoryHeart => 'Сердце';

  @override
  String get healthDataSettingsCategoryBody => 'Тело';

  @override
  String get healthDataSettingsTypeStepsTitle => 'Шаги';

  @override
  String get healthDataSettingsTypeStepsSubtitle => 'Сводка пройденных шагов';

  @override
  String get healthDataSettingsTypeDaylightTitle => 'Солнечный свет';

  @override
  String get healthDataSettingsTypeDaylightSubtitle =>
      'Время на дневном свете на улице';

  @override
  String get healthDataSettingsTypeActiveEnergyTitle => 'Энергия';

  @override
  String get healthDataSettingsTypeActiveEnergySubtitle =>
      'Сожжённая активная энергия';

  @override
  String get healthDataSettingsTypeExerciseMinutesTitle => 'Упражнения';

  @override
  String get healthDataSettingsTypeExerciseMinutesSubtitle =>
      'Минуты упражнений Apple';

  @override
  String get healthDataSettingsTypeStandTimeTitle => 'Стояние';

  @override
  String get healthDataSettingsTypeStandTimeSubtitle => 'Время стояния';

  @override
  String get healthDataSettingsTypeDistanceTitle => 'Расстояние';

  @override
  String get healthDataSettingsTypeDistanceSubtitle =>
      'Расстояние ходьбы и бега';

  @override
  String get healthDataSettingsTypeWorkoutsTitle => 'Тренировки';

  @override
  String get healthDataSettingsTypeWorkoutsSubtitle =>
      'Записи тренировок: тип, длительность, дистанция и энергия';

  @override
  String get healthDataSettingsTypeSleepTitle => 'Сон';

  @override
  String get healthDataSettingsTypeSleepSubtitle =>
      'За последние 24 часа: сон, время в постели, периоды бодрствования и стадии сна';

  @override
  String get healthDataSettingsTypeMindfulnessTitle => 'Отдых';

  @override
  String get healthDataSettingsTypeMindfulnessSubtitle =>
      'Периоды осознанности или отдыха';

  @override
  String get healthDataSettingsTypeHeartRateTitle => 'Пульс';

  @override
  String get healthDataSettingsTypeHeartRateSubtitle =>
      'Последний образец пульса';

  @override
  String get healthDataSettingsTypeRestingHeartRateTitle => 'Пульс в покое';

  @override
  String get healthDataSettingsTypeRestingHeartRateSubtitle =>
      'Образец пульса в покое';

  @override
  String get healthDataSettingsTypeBloodOxygenTitle => 'Кислород в крови';

  @override
  String get healthDataSettingsTypeBloodOxygenSubtitle =>
      'Насыщение крови кислородом';

  @override
  String get healthDataSettingsTypeDietaryEnergyTitle => 'Энергия из пищи';

  @override
  String get healthDataSettingsTypeDietaryEnergySubtitle =>
      'Запись калорий из пищи';

  @override
  String get healthDataSettingsTypeWaterTitle => 'Вода';

  @override
  String get healthDataSettingsTypeWaterSubtitle => 'Запись потребления воды';

  @override
  String get healthDataSettingsTypeWeightTitle => 'Вес';

  @override
  String get healthDataSettingsTypeWeightSubtitle => 'Образец массы тела';

  @override
  String get healthDataSettingsTypeBmiTitle => 'ИМТ';

  @override
  String get healthDataSettingsTypeBmiSubtitle => 'Индекс массы тела';

  @override
  String get healthDataSettingsTypeBloodGlucoseTitle => 'Глюкоза в крови';

  @override
  String get healthDataSettingsTypeBloodGlucoseSubtitle =>
      'Образец глюкозы в крови';

  @override
  String get assistantEditLocalToolRemindersQueryTitle => 'Запрос напоминаний';

  @override
  String get assistantEditLocalToolRemindersQuerySubtitle =>
      'Чтение напоминаний на этом устройстве, требуется полный доступ к напоминаниям.';

  @override
  String get assistantEditLocalToolRemindersCreateTitle =>
      'Создать напоминание';

  @override
  String get assistantEditLocalToolRemindersCreateSubtitle =>
      'Создание напоминания на этом устройстве после вашего подтверждения, требуется полный доступ к напоминаниям.';

  @override
  String get assistantEditLocalToolRemindersCompleteTitle =>
      'Завершить напоминание';

  @override
  String get assistantEditLocalToolRemindersCompleteSubtitle =>
      'Отметка напоминания как выполненного после вашего подтверждения, требуется полный доступ к напоминаниям.';

  @override
  String get assistantEditMemorySwitchDescription =>
      'Разрешить ассистенту создавать и использовать воспоминания в разных чатах.';

  @override
  String get assistantEditRecentChatsSwitchTitle => 'Ссылка на недавние чаты';

  @override
  String get assistantEditRecentChatsSwitchDescription =>
      'Включать названия недавних чатов для лучшего контекста.';

  @override
  String get assistantEditAddMemoryButton => 'Добавить воспоминание';

  @override
  String get assistantEditMemoryEmpty => 'Воспоминаний пока нет';

  @override
  String get assistantEditMemoryDialogTitle => 'Воспоминание';

  @override
  String get assistantEditMemoryDialogHint => 'Введите содержимое воспоминания';

  @override
  String get assistantEditAddQuickPhraseButton => 'Добавить быструю фразу';

  @override
  String get multiKeyPageDeleteSnackbarDeletedOne => 'Удалён 1 ключ';

  @override
  String get multiKeyPageUndo => 'Отменить';

  @override
  String get multiKeyPageUndoRestored => 'Восстановлено';

  @override
  String get multiKeyPageDeleteErrorsTooltip => 'Удалить ошибки';

  @override
  String get multiKeyPageDeleteErrorsConfirmTitle =>
      'Удалить все ключи с ошибками?';

  @override
  String get multiKeyPageDeleteErrorsConfirmContent =>
      'Это удалит все ключи, отмеченные как ошибочные.';

  @override
  String multiKeyPageDeletedErrorsSnackbar(int n) {
    return 'Удалено ключей с ошибками: $n';
  }

  @override
  String get providerDetailPageProviderTypeTitle => 'Тип провайдера';

  @override
  String get displaySettingsPageChatItemDisplayTitle =>
      'Отображение элементов чата';

  @override
  String get displaySettingsPageRenderingSettingsTitle =>
      'Настройки отображения';

  @override
  String get displaySettingsPageBehaviorStartupTitle => 'Поведение и запуск';

  @override
  String get displaySettingsPageHapticsSettingsTitle => 'Тактильная отдача';

  @override
  String get assistantSettingsNoPromptPlaceholder => 'Промпт пока не задан';

  @override
  String get providersPageMultiSelectTooltip => 'Множественный выбор';

  @override
  String get providersPageDeleteSelectedConfirmContent =>
      'Удалить выбранные провайдеры? Это действие нельзя отменить.';

  @override
  String get providersPageDeleteSelectedSnackbar =>
      'Выбранные провайдеры удалены';

  @override
  String providersPageExportSelectedTitle(int count) {
    return 'Экспорт провайдеров: $count';
  }

  @override
  String get providersPageExportCopyButton => 'Копировать';

  @override
  String get providersPageExportShareButton => 'Поделиться';

  @override
  String get providersPageExportCopiedSnackbar => 'Код экспорта скопирован';

  @override
  String get providersPageDeleteAction => 'Удалить';

  @override
  String get providersPageExportAction => 'Экспорт';

  @override
  String get assistantEditPresetTitle => 'Предустановленный чат';

  @override
  String get assistantEditPresetAddUser => 'Добавить сообщение пользователя';

  @override
  String get assistantEditPresetAddAssistant => 'Добавить сообщение ассистента';

  @override
  String get assistantEditPresetInputHintUser =>
      'Введите сообщение пользователя…';

  @override
  String get assistantEditPresetInputHintAssistant =>
      'Введите сообщение ассистента…';

  @override
  String get assistantEditPresetEmpty => 'Предустановленных сообщений пока нет';

  @override
  String get assistantEditPresetEditDialogTitle =>
      'Редактировать предустановленное сообщение';

  @override
  String get assistantEditPresetRoleUser => 'Пользователь';

  @override
  String get assistantEditPresetRoleAssistant => 'Ассистент';

  @override
  String get desktopTtsPleaseAddProvider => 'Сначала добавьте провайдера TTS';

  @override
  String get settingsPageNetworkProxy => 'Сетевой прокси';

  @override
  String get networkProxyEnableLabel => 'Включить прокси';

  @override
  String get networkProxySettingsHeader => 'Настройки прокси';

  @override
  String get networkProxyType => 'Тип прокси';

  @override
  String get networkProxyTypeHttp => 'HTTP';

  @override
  String get networkProxyTypeHttps => 'HTTPS';

  @override
  String get networkProxyTypeSocks5 => 'SOCKS5';

  @override
  String get networkProxyServerHost => 'Сервер';

  @override
  String get networkProxyPort => 'Порт';

  @override
  String get networkProxyUsername => 'Имя пользователя';

  @override
  String get networkProxyPassword => 'Пароль';

  @override
  String get networkProxyBypassLabel => 'Обход прокси';

  @override
  String get networkProxyBypassHint =>
      'Хосты/CIDR через запятую, например: localhost,127.0.0.1,192.168.0.0/16,*.local';

  @override
  String get networkProxyOptionalHint => 'Необязательно';

  @override
  String get networkProxyTestHeader => 'Проверка подключения';

  @override
  String get networkProxyTestUrlHint => 'Тестовый URL';

  @override
  String get networkProxyTestButton => 'Проверить';

  @override
  String get networkProxyTesting => 'Проверка…';

  @override
  String get networkProxyTestSuccess => 'Подключение успешно';

  @override
  String networkProxyTestFailed(String error) {
    return 'Ошибка проверки: $error';
  }

  @override
  String get networkProxyNoUrl => 'Введите URL';

  @override
  String get networkProxyPriorityNote =>
      'Если включены и глобальный, и прокси провайдера, приоритет имеет прокси провайдера.';

  @override
  String get settingsPageAutoRetry => 'Автоповтор';

  @override
  String get autoRetryEnableLabel => 'Включить автоповтор';

  @override
  String get autoRetryMaxRetries => 'Макс. число повторов';

  @override
  String get autoRetryInitialDelay => 'Начальная задержка (мс)';

  @override
  String get autoRetryMultiplier => 'Множитель задержки';

  @override
  String get autoRetryMaxDelay => 'Макс. задержка (мс)';

  @override
  String get autoRetryJitter => 'Разброс';

  @override
  String get autoRetryJitterSubtitle =>
      'Случайное отклонение каждой задержки на ±20%';

  @override
  String get autoRetryOnNetworkError => 'Повторять при сетевых ошибках';

  @override
  String get autoRetryStatusCodes => 'Коды состояния для повтора';

  @override
  String get autoRetryKeywords => 'Ключевые слова для повтора';

  @override
  String get autoRetryStopKeywords => 'Ключевые слова остановки';

  @override
  String get autoRetryAddHint => 'Добавить';

  @override
  String get autoRetryRestoreDefaults => 'Восстановить по умолчанию';

  @override
  String get autoRetryFooter =>
      'Автоповтор выполняется только если текущий ответ модели ещё не выдал никакого вывода.';

  @override
  String autoRetryCountdown(int seconds, int attempt, int maxRetries) {
    return 'Повтор через $seconds с ($attempt/$maxRetries)';
  }

  @override
  String get desktopShowProviderInModelCapsule =>
      'Показывать провайдера в капсуле модели';

  @override
  String get messageWebViewOpenInBrowser => 'Открыть в браузере';

  @override
  String get messageWebViewConsoleLogs => 'Логи консоли';

  @override
  String get messageWebViewNoConsoleMessages => 'Нет сообщений консоли';

  @override
  String get messageWebViewRefreshTooltip => 'Обновить';

  @override
  String get messageWebViewForwardTooltip => 'Вперёд';

  @override
  String get chatInputBarOcrTooltip => 'Распознавание текста (OCR)';

  @override
  String get providerDetailPageMultiSelectButton => 'Множественный выбор';

  @override
  String get providerDetailPageBatchDetectButton => 'Проверить';

  @override
  String get providerDetailPageBatchDetecting => 'Проверка...';

  @override
  String get providerDetailPageBatchDetectStart => 'Начать проверку';

  @override
  String get providerDetailPageDetectSuccess => 'Проверка успешна';

  @override
  String get providerDetailPageDetectFailed => 'Проверка не удалась';

  @override
  String get providerDetailPageDeleteSelectedModelsButton => 'Удалить';

  @override
  String get providerDetailPageDeleteSelectedModelsTooltip =>
      'Удалить выбранные модели';

  @override
  String providerDetailPageDeleteSelectedModelsConfirm(int count) {
    return 'Удалить выбранные модели ($count)? Это действие нельзя отменить.';
  }

  @override
  String get providerDetailPageDeleteFailedDetectedModelsButton =>
      'Удалить недоступные';

  @override
  String get providerDetailPageDeleteFailedDetectedModelsTooltip =>
      'Удалить модели, не прошедшие проверку';

  @override
  String providerDetailPageDeleteFailedDetectedModelsConfirm(int count) {
    return 'Удалить модели, не прошедшие проверку ($count)? Это действие нельзя отменить.';
  }

  @override
  String providerDetailPageSelectedModelsDeletedSnackbar(int count) {
    return 'Удалено моделей: $count';
  }

  @override
  String get providerDetailPageDeleteAllModelsTooltip => 'Удалить все модели';

  @override
  String get providerDetailPageDeleteAllModelsWarning =>
      'Это действие нельзя отменить.';

  @override
  String get requestLogSettingTitle => 'Логирование запросов';

  @override
  String get requestLogSettingSubtitle =>
      'При включении сведения о запросах и ответах записываются в logs/logs.txt (ротация ежедневно).';

  @override
  String get flutterLogSettingTitle => 'Логирование Flutter';

  @override
  String get flutterLogSettingSubtitle =>
      'При включении ошибки Flutter и вывод print записываются в logs/flutter_logs.txt (ротация ежедневно).';

  @override
  String get contextLogSettingTitle => 'Логирование контекста';

  @override
  String get contextLogSettingSubtitle =>
      'При включении точные сообщения, отправляемые модели, записываются в logs/context_logs.txt (ротация ежедневно).';

  @override
  String get contextLogViewerTitle => 'Контекст';

  @override
  String contextLogSnapshotMessages(int count) {
    return 'Сообщений: $count';
  }

  @override
  String contextLogSnapshotTokens(int count) {
    return 'Токенов: $count';
  }

  @override
  String get contextLogSourceSystemPrompt => 'Системный промпт';

  @override
  String get contextLogSourceMemoryRules => 'Правила памяти';

  @override
  String get contextLogSourceSearchPrompt => 'Промпт поиска';

  @override
  String get contextLogSourceInstructionInjection => 'Инструкция';

  @override
  String get contextLogSourceWorldBook => 'Книга мира';

  @override
  String get contextLogSourceMemorySnapshot => 'Снимок памяти';

  @override
  String get contextLogSourceChatHistory => 'История чата';

  @override
  String get contextLogSourceToolCall => 'Вызов инструмента';

  @override
  String get contextLogSourceToolResult => 'Результат инструмента';

  @override
  String get contextLogTokensEstimateHint =>
      'Количество токенов приблизительное; ориентируйтесь на фактическое использование модели.';

  @override
  String contextLogSnapshotsCount(int count) {
    return 'Снимков: $count';
  }

  @override
  String get contextLogSnapshotFallbackTitle => 'Снимок';

  @override
  String get contextLogKindFull => 'Полный снимок';

  @override
  String get contextLogKindUpdate => 'Инкрементальное обновление';

  @override
  String get contextLogSectionComposition => 'Состав';

  @override
  String get contextLogLoadOlder => 'Загрузить более ранние логи';

  @override
  String get contextLogLoading => 'Загрузка...';

  @override
  String get contextLogAllLoaded => 'Все логи загружены';

  @override
  String get logViewerTitle => 'Журнал запросов';

  @override
  String get logViewerEmpty => 'Логов пока нет';

  @override
  String get logViewerCurrentLog => 'Текущий лог';

  @override
  String get logViewerExport => 'Экспорт';

  @override
  String get logViewerOpenFolder => 'Открыть папку логов';

  @override
  String logViewerRequestsCount(int count) {
    return '$count запросов';
  }

  @override
  String get logViewerFieldId => 'ID';

  @override
  String get logViewerFieldMethod => 'Метод';

  @override
  String get logViewerFieldStatus => 'Статус';

  @override
  String get logViewerFieldStarted => 'Начало';

  @override
  String get logViewerFieldEnded => 'Окончание';

  @override
  String get logViewerFieldDuration => 'Длительность';

  @override
  String get logViewerSectionSummary => 'Сводка';

  @override
  String get logViewerSectionParameters => 'Параметры';

  @override
  String get logViewerSectionRequestHeaders => 'Заголовки запроса';

  @override
  String get logViewerSectionRequestBody => 'Тело запроса';

  @override
  String get logViewerSectionResponseHeaders => 'Заголовки ответа';

  @override
  String get logViewerSectionResponseBody => 'Тело ответа';

  @override
  String get logViewerSectionWarnings => 'Предупреждения';

  @override
  String get logViewerErrorTitle => 'Ошибка';

  @override
  String logViewerMoreCount(int count) {
    return 'ещё +$count';
  }

  @override
  String get logViewerSectionAttachments => 'Вложения';

  @override
  String get logViewerPayloadOmitted => 'опущено';

  @override
  String get logViewerShowMore => 'Показать больше';

  @override
  String get logSettingsTitle => 'Настройки логов';

  @override
  String get logSettingsSaveOutput => 'Сохранять вывод ответа';

  @override
  String get logSettingsSaveOutputSubtitle =>
      'Записывать каждый фрагмент потокового ответа (может замедлить генерацию). Тела HTTP-ошибок записываются всегда.';

  @override
  String get logSettingsElidePayloads => 'Опускать большие данные';

  @override
  String get logSettingsElidePayloadsSubtitle =>
      'Заменять встроенные base64-изображения и файлы заполнителем. Логи остаются компактными, а просмотр — быстрым.';

  @override
  String get logSettingsAutoDelete => 'Автоудаление';

  @override
  String get logSettingsAutoDeleteSubtitle =>
      'Удалять логи старше указанного числа дней';

  @override
  String get logSettingsAutoDeleteDisabled => 'Отключено';

  @override
  String logSettingsAutoDeleteDays(int count) {
    return '$count дн.';
  }

  @override
  String get logSettingsMaxSize => 'Макс. размер логов';

  @override
  String get logSettingsMaxSizeSubtitle =>
      'При превышении удаляются самые старые логи';

  @override
  String get logSettingsMaxSizeUnlimited => 'Без ограничений';

  @override
  String get assistantEditManageSummariesTitle => 'Управление сводками';

  @override
  String get assistantEditSummaryEmpty => 'Сводок пока нет';

  @override
  String get assistantEditSummaryDialogTitle => 'Изменить сводку';

  @override
  String get assistantEditSummaryDialogHint => 'Введите содержимое сводки';

  @override
  String get assistantEditDeleteSummaryTitle => 'Очистить сводку';

  @override
  String get assistantEditDeleteSummaryContent =>
      'Вы уверены, что хотите очистить эту сводку?';

  @override
  String get homePageProcessingFiles => 'Обработка файлов...';

  @override
  String get settingsPageWorldBook => 'Книга мира';

  @override
  String get settingsPageMemory => 'Память';

  @override
  String get memorySettingsPageTitle => 'Память';

  @override
  String get memorySettingsGlobalSubtitle => 'Режим памяти, модель и промпты';

  @override
  String get memorySettingsModeSection => 'Режим памяти';

  @override
  String get memorySettingsModelSection => 'Модель памяти';

  @override
  String get memorySettingsModelTitle => 'Модель обработки';

  @override
  String get memorySettingsModelUnset => 'Не выбрана';

  @override
  String get memorySettingsModelTip =>
      'После включения автоупорядочивания памяти эта модель часто вызывается в фоне. Предпочитайте дешёвую и быструю модель.';

  @override
  String get memorySettingsAboutTitle => 'О памяти';

  @override
  String get memorySettingsAboutSubtitle =>
      'Как работает память и когда она запускается';

  @override
  String get memoryAboutQuickstartTitle => 'Начало работы';

  @override
  String get memoryAboutQuickstartBody =>
      '1. В разделе «Настройки → Память» выберите модель обработки.\n2. На вкладке «Память» ассистента включите долговременную память и автоупорядочивание.\n3. Поговорите несколько ходов или нажмите «Упорядочить», затем откройте «Все воспоминания», чтобы увидеть сохранённое.';

  @override
  String get memoryAboutTypesTitle => 'Типы памяти';

  @override
  String get memoryAboutTypesBody =>
      'Личность: стабильные факты о пользователе, например как к нему обращаться, роль, язык и долгосрочные предпочтения. Пишите полные утверждения от третьего лица.\n\nРабочий процесс: как пользователь предпочитает выполнять работу — инструменты, форматы и привычки проверки.\n\nГолос: как пользователь хочет, чтобы звучал ассистент — тон, длина и языковой стиль.\n\nИнструкция: постоянные правила, которым должен следовать ассистент, а не разовые задачи из этого чата.';

  @override
  String get memoryAboutScopeTitle => 'Глобальная и ассистентская';

  @override
  String get memoryAboutScopeBody =>
      'Глобальные воспоминания внедряются для каждого ассистента. Воспоминания области ассистента видны только этому ассистенту. Используйте глобальные для фактов, которые должны следовать за пользователем везде; используйте область ассистента для правил или контекста, принадлежащих одной персоне.';

  @override
  String get memoryAboutInjectionTitle => 'Как внедряются воспоминания';

  @override
  String get memoryAboutInjectionBody =>
      'В начале чата самые новые элементы каждого типа помещаются в контекст модели. Если тип превышает лимит внедрения, блок помечается mode=\"summary\" с общим и показанным количеством; остальное можно получить через memory_search_profile. Увеличьте лимит в разделе «Настройки → Память» для большей полноты при более высоких затратах токенов. В настройках памяти каждого ассистента выберите типы для полного внедрения.';

  @override
  String get memoryAboutPipelineTitle => 'Фоновый конвейер';

  @override
  String get memoryAboutPipelineBody =>
      'Автоупорядочивание запускается после чатов: решить, стоит ли что-то запоминать, извлечь кандидатов, удалить дубликаты и объединить, затем при необходимости сжать элементы личности в профиль пользователя. Вы также можете нажать «Упорядочить» на вкладке «Память» ассистента. Поэтому модель обработки вызывается часто.';

  @override
  String get memoryAboutCacheTitle => 'Поддерживайте кэширование в порядке';

  @override
  String get memoryAboutCacheBody =>
      'Внедряемый префикс памяти остаётся стабильным, чтобы неизменённые чаты могли повторно использовать кэш промптов, снижая затраты и задержку. Избегайте бессмысленных массовых правок или перестановок. Повседневные правки отдельных записей обычно имеют ограниченное влияние.';

  @override
  String get memoryAboutFaqTitle => 'Частые вопросы';

  @override
  String get memoryAboutFaqWhyNotRememberedTitle =>
      'Почему это не запомнилось?';

  @override
  String get memoryAboutFaqWhyNotRememberedBody =>
      'Упорядочивание пропускается, когда недостаточно новых сообщений для упорядочивания, нет новых сообщений для упорядочивания или не выбрана модель обработки памяти. Временные чаты не сохраняются в память. Вы также можете отключить память или автоупорядочивание для каждого ассистента.';

  @override
  String get memorySettingsThinkingTitle => 'Включить рассуждение';

  @override
  String get memorySettingsThinkingSubtitle =>
      'Разрешить модели памяти использовать рассуждение, когда это поддерживается';

  @override
  String get memorySettingsInjectionSection => 'Внедрение памяти';

  @override
  String get memorySettingsInjectionMaxItemsTitle =>
      'Элементов внедряется на тип';

  @override
  String get memorySettingsInjectionMaxItemsSubtitle =>
      'Этот лимит применяется к типам, не выбранным для полного внедрения в настройках памяти ассистента. Когда тип превышает этот лимит, внедряются только самые новые элементы. Остальное можно получить через memory_search_profile. Большее число полнее, но использует больше токенов. Если вы настроили промпт правил, обновите его или восстановите значение по умолчанию.';

  @override
  String get assistantEditMemoryFullInjectionTypesTitle =>
      'Типы полного внедрения';

  @override
  String get assistantEditMemoryFullInjectionTypesNone => 'Нет';

  @override
  String assistantEditMemoryFullInjectionTypesSelected(int count) {
    return 'Выбрано: $count';
  }

  @override
  String get assistantEditMemoryFullInjectionTypesSubtitle =>
      'Применяется только к этому ассистенту. Выберите типы, чтобы внедрять все их активные глобальные воспоминания и воспоминания ассистента, игнорируя лимит элементов. Использует больше контекста и токенов.';

  @override
  String memorySettingsInjectionMaxItemsOption(int n) {
    return '$n';
  }

  @override
  String get memorySettingsInjectionMaxItemsCustomButton => 'Своё значение';

  @override
  String get memorySettingsInjectionMaxItemsCustomTitle =>
      'Своё количество внедрения';

  @override
  String get memorySettingsInjectionMaxItemsCustomDescription =>
      'Введите число от 1 до 100.';

  @override
  String get memorySettingsInjectionMaxItemsCustomLabel => 'Количество';

  @override
  String get memorySettingsInjectionMaxItemsCustomHint => '1–100';

  @override
  String get memorySettingsInjectionMaxItemsCustomInvalid =>
      'Введите число от 1 до 100';

  @override
  String get memorySettingsPromptLangSection => 'Язык промптов';

  @override
  String get memorySettingsPromptLangAuto => 'Авто';

  @override
  String get memorySettingsPromptLangAutoSubtitle =>
      'Следовать языку интерфейса (китайский → zh, иначе en)';

  @override
  String get memorySettingsPromptLangZh => 'Китайский';

  @override
  String get memorySettingsPromptLangZhSubtitle =>
      'Всегда использовать китайские промпты памяти и описания инструментов';

  @override
  String get memorySettingsPromptLangEn => 'Английский';

  @override
  String get memorySettingsPromptLangEnSubtitle =>
      'Всегда использовать английские промпты памяти и описания инструментов';

  @override
  String get memorySettingsPromptsSection => 'Шаблоны промптов';

  @override
  String get memorySettingsLegacyPromptTitle => 'Устаревшие правила памяти';

  @override
  String get memoryPromptEditRulesTitle => 'Правила памяти';

  @override
  String get memoryPromptEditRulesSubtitle =>
      'Добавляется в системный промпт основного чата';

  @override
  String get memoryPromptEditGateTitle => 'Привратник';

  @override
  String get memoryPromptEditGateSubtitle =>
      'Решает, стоит ли запоминать этот обмен';

  @override
  String get memoryPromptEditExtractTitle => 'Извлечение';

  @override
  String get memoryPromptEditExtractSubtitle =>
      'Извлекает кандидатов в память из чата';

  @override
  String get memoryPromptEditSmartAddTitle => 'Умное добавление';

  @override
  String get memoryPromptEditSmartAddSubtitle =>
      'Решение о дедупликации NEW / MERGE / CONFLICT / SKIP';

  @override
  String get memoryPromptEditDistillTitle => 'Составитель профиля';

  @override
  String get memoryPromptEditDistillSubtitle =>
      'Превращает воспоминания о личности в поля профиля';

  @override
  String get memoryPromptEditMigrateTitle => 'Миграция старых данных';

  @override
  String get memoryPromptEditMigrateSubtitle =>
      'Используется, когда миграция переписывает текст воспоминаний';

  @override
  String get memoryPromptEditReset => 'Сбросить по умолчанию';

  @override
  String get memoryPromptEditSave => 'Сохранить';

  @override
  String get memoryPromptEditSectionPerItem => 'Промпт для каждой записи';

  @override
  String get memoryPromptEditSectionBatch => 'Пакетный промпт';

  @override
  String get memorySettingsEntriesSection => 'Все воспоминания';

  @override
  String get memorySettingsLegacySection => 'Старая память';

  @override
  String get memorySettingsEntriesTitle => 'Список воспоминаний';

  @override
  String get memorySettingsEntriesSubtitle =>
      'Просмотр, редактирование, архивирование и удаление воспоминаний';

  @override
  String get memorySettingsProfileTitle => 'Профиль пользователя';

  @override
  String get memorySettingsProfileSubtitle =>
      'Структурированные поля личности для модели';

  @override
  String get memorySettingsLegacyTitle => 'Старые воспоминания (только чтение)';

  @override
  String get memorySettingsLegacySubtitle =>
      'Воспоминания из предыдущих версий';

  @override
  String get memoryEntryTypeIdentity => 'Личность';

  @override
  String get memoryEntryTypeWorkflow => 'Рабочий процесс';

  @override
  String get memoryEntryTypeVoice => 'Тон';

  @override
  String get memoryEntryTypeInstruction => 'Инструкция';

  @override
  String get memoryEntryScopeGlobal => 'Глобально';

  @override
  String get memoryEntryScopeAssistant => 'Этот ассистент';

  @override
  String memoryEntryScopeAssistantNamed(String name) {
    return '$name';
  }

  @override
  String get memoryEntrySourceManual => 'Вручную';

  @override
  String get memoryEntrySourceTool => 'Инструмент';

  @override
  String get memoryEntrySourceExtracted => 'Извлечено';

  @override
  String get memoryEntrySourceDistilled => 'Дистиллировано';

  @override
  String get memoryEntryStatusActive => 'Активно';

  @override
  String get memoryEntryStatusArchived => 'В архиве';

  @override
  String memoryEntryUpdatedAt(String date) {
    return 'Обновлено $date';
  }

  @override
  String get memoryEntryActionEdit => 'Изменить';

  @override
  String get memoryEntryActionDelete => 'Удалить';

  @override
  String get memoryEntryActionArchive => 'В архив';

  @override
  String get memoryEntryActionRestore => 'Восстановить';

  @override
  String get memoryEntryActionSwitchScope => 'Изменить область';

  @override
  String get memoryEntryActionBatchDelete => 'Удалить выбранные';

  @override
  String get memoryEntryActionAdd => 'Добавить воспоминание';

  @override
  String get memoryEntryDeleteConfirmTitle => 'Удалить воспоминание?';

  @override
  String get memoryEntryDeleteConfirmContent =>
      'Воспоминание будет удалено безвозвратно. Это действие нельзя отменить.';

  @override
  String memoryEntryBatchDeleteConfirmTitle(int count) {
    return 'Удалить воспоминания ($count)?';
  }

  @override
  String get memoryEntryBatchDeleteConfirmContent =>
      'Выбранные воспоминания будут удалены безвозвратно.';

  @override
  String get memoryEntrySwitchScopeConfirmTitle =>
      'Изменить область воспоминания?';

  @override
  String get memoryEntrySwitchScopeToGlobal =>
      'Сделать это воспоминание глобальным (общим для всех ассистентов)?';

  @override
  String get memoryEntrySwitchScopeToAssistant =>
      'Ограничить эту память текущим ассистентом?';

  @override
  String get memoryEntryArchivedSection => 'В архиве';

  @override
  String get memoryEntryEmpty => 'Памяти пока нет';

  @override
  String get memoryEntryEmptyDisabled =>
      'Долговременная память отключена для этого ассистента';

  @override
  String get memoryEntryEditTitle => 'Изменить память';

  @override
  String get memoryEntryCreateTitle => 'Новая память';

  @override
  String get memoryEntryContentHint => 'Введите содержимое памяти';

  @override
  String get memoryEntryTypeLabel => 'Тип';

  @override
  String get memoryEntryScopeLabel => 'Область';

  @override
  String get memoryFilterScopeAll => 'Все области';

  @override
  String get memoryFilterScopeGlobal => 'Только глобальные';

  @override
  String get memoryFilterScopeAssistant => 'Ассистент';

  @override
  String get memoryFilterTypeAll => 'Все типы';

  @override
  String get memoryFilterStatusAll => 'Все статусы';

  @override
  String get memoryFilterStatusActive => 'Активные';

  @override
  String get memoryFilterStatusArchived => 'В архиве';

  @override
  String get memorySearchHint => 'Поиск по памяти';

  @override
  String get memorySearchEmpty => 'Нет подходящих записей памяти';

  @override
  String memoryOrphanBanner(int count) {
    return 'Осиротевших записей памяти ассистентов: $count (ассистент удалён)';
  }

  @override
  String get memoryOrphanCleanupButton => 'Очистить';

  @override
  String get memoryOrphanConfirmTitle => 'Очистить осиротевшие записи памяти?';

  @override
  String memoryOrphanConfirmContent(int count) {
    return 'Будет безвозвратно удалено записей памяти, чей ассистент больше не существует: $count.';
  }

  @override
  String get memoryOrganizeButton => 'Упорядочить';

  @override
  String get memoryOrganizeNeedsConversation =>
      'Откройте чат с этим ассистентом, чтобы упорядочить память';

  @override
  String get memoryOrganizeNeedsModel =>
      'Сначала выберите модель обработки памяти в разделе Настройки → Память';

  @override
  String get memoryOrganizeStatusNever => 'Ещё не упорядочивалось';

  @override
  String memoryOrganizeStatusLast(String when) {
    return 'Последнее упорядочивание: $when';
  }

  @override
  String memoryOrganizeStatusExtracted(int count) {
    return 'извлечено: $count';
  }

  @override
  String get memoryOrganizeStatusSkipped => 'нечего запоминать';

  @override
  String memoryOrganizeStatusFailed(String reason) {
    return 'Ошибка: $reason';
  }

  @override
  String memoryOrganizeStatusSkippedReason(String reason) {
    return 'пропущено: $reason';
  }

  @override
  String get memoryOutcomeTemporaryConversation =>
      'Временные чаты не сохраняются в память';

  @override
  String get memoryOutcomeMemoryDisabled =>
      'Память отключена для этого ассистента';

  @override
  String get memoryOutcomeAutoOrganizeOff =>
      'Автоматическое упорядочивание отключено';

  @override
  String get memoryOutcomeStreaming => 'Пропущено, пока ответ ещё генерируется';

  @override
  String get memoryOutcomeBelowThreshold =>
      'Недостаточно новых сообщений для упорядочивания';

  @override
  String get memoryOutcomeEmptyWindow =>
      'Нет новых сообщений для упорядочивания';

  @override
  String get memoryOutcomeMemoryModelUnset =>
      'Модель обработки памяти не выбрана';

  @override
  String get memoryOutcomeMemoryModelMissing =>
      'Выбранная модель обработки памяти больше недоступна';

  @override
  String get memoryOutcomeAssistantMissing => 'Ассистент не найден';

  @override
  String get memoryOutcomeConversationMissing => 'Чат не найден';

  @override
  String get memoryOutcomeQueueOverflow =>
      'Очередь упорядочивания заполнена, поэтому этот запуск отброшен';

  @override
  String get memoryOutcomeGateRequestFailed =>
      'Не удалось обратиться к модели памяти для проверки «запомнить/пропустить»';

  @override
  String get memoryOutcomeGateParseFailed =>
      'Ответ проверки «запомнить/пропустить» не удалось разобрать';

  @override
  String get memoryOutcomeExtractRequestFailed =>
      'Не удалось обратиться к модели памяти для извлечения памяти';

  @override
  String get memoryOutcomeExtractParseFailed =>
      'Ответ извлечения памяти не удалось разобрать';

  @override
  String get memoryOutcomeDistillFailed =>
      'Не удалось выделить профиль пользователя';

  @override
  String get memoryOutcomeMemoryExecutionError =>
      'Не удалось выполнить инструмент памяти';

  @override
  String get memoryOutcomeUnsupportedTool =>
      'Неподдерживаемый инструмент памяти';

  @override
  String get memoryOutcomeInvalidMemoryType => 'Недопустимый тип памяти';

  @override
  String get memoryOutcomeInvalidMemoryContent =>
      'Недопустимое содержимое памяти';

  @override
  String get memoryOutcomeInvalidQuery => 'Недопустимый поисковый запрос';

  @override
  String get memoryOutcomeInvalidMemoryId => 'Недопустимый ID памяти';

  @override
  String get memoryOutcomeMemoryNotFound => 'Память не найдена';

  @override
  String get memoryOutcomeInvalidProfileFields => 'Недопустимые поля профиля';

  @override
  String get memoryOutcomeChatSearchUnavailable => 'Поиск по чатам недоступен';

  @override
  String get memoryOrganizeJustNow => 'только что';

  @override
  String memoryOrganizeMinutesAgo(int n) {
    return '$n мин назад';
  }

  @override
  String memoryOrganizeHoursAgo(int n) {
    return '$n ч назад';
  }

  @override
  String memoryOrganizeDaysAgo(int n) {
    return '$n дн назад';
  }

  @override
  String get memoryModelMissingNotice =>
      'Сначала выберите модель обработки памяти в разделе Настройки → Память.';

  @override
  String get memoryModelMissingGoSelect => 'Выбрать модель';

  @override
  String get memoryEntriesPageTitle => 'Все воспоминания';

  @override
  String get userProfilePageTitle => 'Профиль пользователя';

  @override
  String get userProfilePreferredName => 'Предпочитаемое имя';

  @override
  String get userProfilePreferredNameHint =>
      'Как модель должна к вам обращаться — не связано с отображаемым именем в боковой панели';

  @override
  String get userProfileGender => 'Пол';

  @override
  String get userProfilePronouns => 'Местоимения';

  @override
  String get userProfilePreferredLanguage => 'Предпочитаемый язык';

  @override
  String get userProfileTimezone => 'Часовой пояс';

  @override
  String get userProfileOccupation => 'Род занятий';

  @override
  String get userProfileLocation => 'Местоположение';

  @override
  String get userProfileCustomSection => 'Пользовательские поля';

  @override
  String get userProfileAddCustom => 'Добавить пользовательское поле';

  @override
  String get userProfileCustomKeyHint => 'Ключ (custom.name)';

  @override
  String get userProfileCustomValueHint => 'Значение';

  @override
  String get userProfileInvalidKey =>
      'Ключ должен быть custom. и далее 1–32 буквы, цифры, _ или -';

  @override
  String get userProfileClear => 'Очистить';

  @override
  String get userProfileSave => 'Сохранить';

  @override
  String get userProfileEmptyValue => 'Не задано';

  @override
  String get legacyMemoryPageTitle => 'Старые воспоминания';

  @override
  String get legacyMemoryBanner =>
      'Эти воспоминания из старой версии и не используются в чатах. Вы можете перенести их в текущую систему памяти.';

  @override
  String get legacyMemoryEmpty => 'Нет старых воспоминаний';

  @override
  String get legacyMemoryCopy => 'Копировать';

  @override
  String get legacyMemoryCopied => 'Скопировано';

  @override
  String get legacyMemoryExport => 'Экспорт';

  @override
  String get legacyMemoryExportTitle => 'Экспорт старых воспоминаний Kelivo';

  @override
  String legacyMemoryAssistantHeader(String name) {
    return 'Ассистент: $name';
  }

  @override
  String get legacyMemorySearchHint => 'Поиск старых воспоминаний';

  @override
  String get legacyMemoryMigrate => 'Перенести';

  @override
  String get legacyMemoryMigrationTitle => 'Перенос старых воспоминаний';

  @override
  String legacyMemoryMigrationSubtitle(int count) {
    return 'Используйте модель для классификации и очистки $count старых воспоминаний. Оригиналы останутся без изменений.';
  }

  @override
  String get legacyMemoryMigrationModel => 'Модель переноса';

  @override
  String get legacyMemoryMigrationChooseModel => 'Выберите модель';

  @override
  String get legacyMemoryMigrationTarget => 'Сохранить в';

  @override
  String get legacyMemoryMigrationTargetGlobal => 'Глобально';

  @override
  String get legacyMemoryMigrationTargetAssistant => 'Текущий ассистент';

  @override
  String get legacyMemoryMigrationTargetOriginalAssistants =>
      'Исходные ассистенты';

  @override
  String get legacyMemoryMigrationTargetGlobalDescription =>
      'Доступно всем ассистентам';

  @override
  String get legacyMemoryMigrationTargetAssistantDescription =>
      'Доступно только этому ассистенту';

  @override
  String get legacyMemoryMigrationTargetOriginalDescription =>
      'Сохранять каждое воспоминание за его исходным ассистентом';

  @override
  String get legacyMemoryMigrationStart => 'Начать миграцию';

  @override
  String get legacyMemoryMigrationAnalyzing => 'Анализ с помощью модели';

  @override
  String get legacyMemoryMigrationWriting => 'Сохранение воспоминаний';

  @override
  String legacyMemoryMigrationProgress(int current, int total) {
    return '$current из $total';
  }

  @override
  String get legacyMemoryMigrationComplete => 'Миграция завершена';

  @override
  String legacyMemoryMigrationResult(int created, int skipped) {
    return 'Перенесено: $created · уже существовало: $skipped';
  }

  @override
  String get legacyMemoryMigrationFailed =>
      'Миграция остановлена. Можно повторить попытку; уже сохранённые воспоминания будут пропущены.';

  @override
  String get legacyMemoryMigrationRetry => 'Повторить';

  @override
  String get legacyMemoryMigrationClose => 'Готово';

  @override
  String get legacyMemoryMigrationContentMode => 'Обработка содержимого';

  @override
  String get legacyMemoryMigrationContentPreserve => 'Сохранить оригинал';

  @override
  String get legacyMemoryMigrationContentOrganize => 'Переписать моделью';

  @override
  String get legacyMemoryMigrationContentPreserveDescription =>
      'Модель только назначает тип. Исходный текст сохраняется без изменений.';

  @override
  String get legacyMemoryMigrationContentOrganizeDescription =>
      'Модель классифицирует и переписывает каждое воспоминание с помощью редактируемого промпта миграции.';

  @override
  String get legacyMemoryMigrationBatchSize => 'Размер пакета';

  @override
  String legacyMemoryMigrationPartial(int created, int skipped, int failed) {
    return 'Перенесено: $created · пропущено: $skipped · ошибок: $failed';
  }

  @override
  String get legacyMemoryMigrationContinue => 'Продолжить миграцию';

  @override
  String get legacyMemoryMigrationErrorNetwork =>
      'Ошибка сети. Проверьте подключение и повторите попытку.';

  @override
  String get legacyMemoryMigrationErrorFormat =>
      'Модель вернула некорректный ответ.';

  @override
  String get legacyMemoryMigrationErrorAuth =>
      'Ошибка аутентификации. Проверьте API-ключ.';

  @override
  String legacyMemoryMigrationErrorOther(String message) {
    return 'Ошибка миграции: $message';
  }

  @override
  String get legacyMemoryModeTitle => 'Использовать устаревшую память';

  @override
  String get legacyMemoryModeSubtitle =>
      'Глобальная настройка для всех ассистентов';

  @override
  String legacyMemoryModeCacheWarning(String token) {
    return 'Шаблон по умолчанию внедряет текущее время через $token, что влияет на долю попаданий в кэш. Удалите его, если он не нужен.';
  }

  @override
  String get memoryUiContentLabel => 'Содержимое';

  @override
  String get memoryUiValueLabel => 'Значение';

  @override
  String get memoryUiCustomKeyLabel => 'Ключ';

  @override
  String get memoryUiStatusLabel => 'Статус';

  @override
  String get memoryUiAssistantLabel => 'Ассистент';

  @override
  String get memoryUiAssistantAll => 'Все ассистенты';

  @override
  String get memoryUiSearchClear => 'Очистить поиск';

  @override
  String get memoryUiAssistantLegacyTitle =>
      'Устаревшие воспоминания (только чтение)';

  @override
  String get memoryUiAssistantLegacySubtitle =>
      'Старые воспоминания этого ассистента из предыдущих версий';

  @override
  String get assistantEditMemorySwitchTitle =>
      'Использовать долговременную память';

  @override
  String get assistantEditMemorySwitchSubtitle =>
      'Внедрять сохранённые воспоминания в чаты и разрешить этому ассистенту записывать новые';

  @override
  String get assistantEditAutoOrganizeTitle =>
      'Автоматическая организация памяти';

  @override
  String get assistantEditAutoOrganizeSubtitle =>
      'Запускать конвейер памяти после чатов';

  @override
  String get assistantEditAllowPastRecallTitle =>
      'Разрешить вспоминать прошлые чаты';

  @override
  String get assistantEditAllowPastRecallSubtitle =>
      'Включить поиск по прошлым беседам';

  @override
  String get assistantEditGenerateSummaryTitle => 'Генерировать сводки бесед';

  @override
  String get assistantEditGenerateSummarySubtitle =>
      'Сводки используются только для поиска по чатам';

  @override
  String get assistantEditManageMemoryTitle =>
      'Воспоминания, видимые этому ассистенту';

  @override
  String get assistantEditWriteScopeTitle => 'Область записи воспоминаний';

  @override
  String get assistantEditWriteScopeSubtitle =>
      'Куда по умолчанию сохраняются новые воспоминания';

  @override
  String get assistantEditWriteScopeAlwaysGlobal => 'Всегда глобально';

  @override
  String get assistantEditWriteScopeAlwaysGlobalSubtitle =>
      'Новые воспоминания доступны всем ассистентам';

  @override
  String get assistantEditWriteScopeAlwaysAssistant => 'Всегда этот ассистент';

  @override
  String get assistantEditWriteScopeAlwaysAssistantSubtitle =>
      'Новые воспоминания остаются приватными для этого ассистента';

  @override
  String get assistantEditWriteScopeToolDefaultGlobal =>
      'Выбирает модель (по умолчанию глобально)';

  @override
  String get assistantEditWriteScopeToolDefaultGlobalSubtitle =>
      'Модель может выбрать глобальную область или этого ассистента; по умолчанию — глобальная';

  @override
  String get assistantEditWriteScopeToolDefaultAssistant =>
      'Выбирает модель (по умолчанию этот ассистент)';

  @override
  String get assistantEditWriteScopeToolDefaultAssistantSubtitle =>
      'Модель может выбрать глобальную область или этого ассистента; по умолчанию — этот ассистент';

  @override
  String get assistantEditDedupeModeTitle => 'Режим дедупликации';

  @override
  String get assistantEditDedupeModeSubtitle =>
      'Как кандидаты сравниваются с существующими воспоминаниями';

  @override
  String get assistantEditDedupeModeBatched => 'Пакетно';

  @override
  String get assistantEditDedupeModeBatchedSubtitle =>
      'Все новые кандидаты проверяются одним запросом. Быстрее и дешевле; менее точно при большом числе элементов.';

  @override
  String get assistantEditDedupeModePerItem => 'По одному';

  @override
  String get assistantEditDedupeModePerItemSubtitle =>
      'Каждый кандидат проверяется отдельным запросом. Точнее; больше вызовов модели.';

  @override
  String get assistantEditOrganizeFrequencyTitle =>
      'Упорядочивать каждые N ходов';

  @override
  String get assistantEditOrganizeFrequencySubtitle =>
      'Запускать автоупорядочивание после указанного числа ответов ассистента';

  @override
  String assistantEditOrganizeFrequencyOption(int n) {
    return 'Каждые $n';
  }

  @override
  String get assistantEditOrganizeFrequencyCustomButton => 'Своё значение';

  @override
  String get assistantEditOrganizeFrequencyCustomTitle => 'Своя частота';

  @override
  String get assistantEditOrganizeFrequencyCustomDescription =>
      'Введите число от 1 до 20.';

  @override
  String get assistantEditOrganizeFrequencyCustomLabel => 'Ходы';

  @override
  String get assistantEditOrganizeFrequencyCustomHint => '1–20';

  @override
  String get assistantEditOrganizeFrequencyCustomInvalid =>
      'Введите число от 1 до 20';

  @override
  String get worldBookTitle => 'Книга мира';

  @override
  String get worldBookAdd => 'Добавить книгу мира';

  @override
  String get worldBookEmptyMessage => 'Книг мира пока нет';

  @override
  String get worldBookUnnamed => 'Книга мира без названия';

  @override
  String get worldBookDisabledTag => 'Отключено';

  @override
  String get worldBookAlwaysOnTag => 'Всегда включено';

  @override
  String get worldBookAddEntry => 'Добавить запись';

  @override
  String get worldBookExport => 'Поделиться / экспорт';

  @override
  String get worldBookConfig => 'Настроить';

  @override
  String get worldBookDeleteTitle => 'Удалить книгу мира';

  @override
  String worldBookDeleteMessage(String name) {
    return 'Удалить «$name»? Это действие нельзя отменить.';
  }

  @override
  String get worldBookCancel => 'Отмена';

  @override
  String get worldBookDelete => 'Удалить';

  @override
  String worldBookExportFailed(String error) {
    return 'Ошибка экспорта: $error';
  }

  @override
  String get worldBookNoEntriesHint => 'Записей нет';

  @override
  String get worldBookUnnamedEntry => 'Запись без названия';

  @override
  String worldBookKeywordsLine(String keywords) {
    return 'Ключевые слова: $keywords';
  }

  @override
  String get worldBookEditEntry => 'Изменить запись';

  @override
  String get worldBookDeleteEntry => 'Удалить запись';

  @override
  String get worldBookNameLabel => 'Название';

  @override
  String get worldBookDescriptionLabel => 'Описание';

  @override
  String get worldBookEnabledLabel => 'Включено';

  @override
  String get worldBookSave => 'Сохранить';

  @override
  String get worldBookEntryNameLabel => 'Название записи';

  @override
  String get worldBookEntryEnabledLabel => 'Запись включена';

  @override
  String get worldBookEntryPriorityLabel => 'Приоритет';

  @override
  String get worldBookEntryKeywordsLabel => 'Ключевые слова';

  @override
  String get worldBookEntryKeywordsHint =>
      'Введите ключевое слово и нажмите +, чтобы добавить.';

  @override
  String get worldBookEntryKeywordInputHint => 'Введите ключевое слово';

  @override
  String get worldBookEntryKeywordAddTooltip => 'Добавить ключевое слово';

  @override
  String get worldBookEntryUseRegexLabel => 'Использовать регулярное выражение';

  @override
  String get worldBookEntryCaseSensitiveLabel => 'С учётом регистра';

  @override
  String get worldBookEntryAlwaysOnLabel => 'Всегда активна';

  @override
  String get worldBookEntryAlwaysOnHint =>
      'Всегда добавлять без сопоставления по ключевым словам';

  @override
  String get worldBookEntryScanDepthLabel => 'Глубина сканирования';

  @override
  String get worldBookEntryContentLabel => 'Содержимое';

  @override
  String get worldBookEntryInjectionPositionLabel => 'Позиция вставки';

  @override
  String get worldBookEntryInjectionRoleLabel => 'Роль вставки';

  @override
  String get worldBookEntryInjectDepthLabel => 'Глубина вставки';

  @override
  String get worldBookInjectionPositionBeforeSystemPrompt =>
      'Перед системным промптом';

  @override
  String get worldBookInjectionPositionAfterSystemPrompt =>
      'После системного промпта';

  @override
  String get worldBookInjectionPositionTopOfChat => 'Начало чата';

  @override
  String get worldBookInjectionPositionBottomOfChat => 'Конец чата';

  @override
  String get worldBookInjectionPositionAtDepth => 'На заданной глубине';

  @override
  String worldBookImportUnsupportedEntries(int count) {
    return 'Импортировано. Записей с неподдерживаемыми функциями SillyTavern (такими как макросы, регулярные выражения, тайминг, фильтры или правила вставки): $count. Их содержимое сохранено, но они отключены. Проверьте их перед включением.';
  }

  @override
  String get worldBookInjectionRoleUser => 'Пользователь';

  @override
  String get worldBookInjectionRoleAssistant => 'Ассистент';

  @override
  String get mcpToolNeedsApproval => 'Требуется одобрение';

  @override
  String get toolApprovalPending => 'Ожидает одобрения';

  @override
  String get toolApprovalDeny => 'Отклонить';

  @override
  String get toolApprovalDenyTitle => 'Отклонить вызов инструмента';

  @override
  String get toolApprovalDenyHint => 'Причина (необязательно)';

  @override
  String toolApprovalDeniedMessage(Object reason, Object toolName) {
    return 'Вызов инструмента \"$toolName\" отклонён пользователем. Причина: $reason';
  }

  @override
  String get askUserCardSubmit => 'Отправить ответ';

  @override
  String get askUserCardCustomHint => 'Введите ваш ответ';

  @override
  String get askUserCardSomethingElse => 'Другое';

  @override
  String get askUserCardSkip => 'Пропустить';

  @override
  String get askUserCardSkipped => 'Пропущено';

  @override
  String get askUserCardAnswered => 'Отвечено';

  @override
  String get askUserCardInactive =>
      'Этот вопрос больше не активен. Перегенерируйте или продолжите чат.';

  @override
  String get askUserCardCancelled => 'Вопрос отменён';

  @override
  String askUserCardQuestionCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Задать $count вопроса',
      many: 'Задать $count вопросов',
      few: 'Задать $count вопроса',
      one: 'Задать $count вопрос',
    );
    return '$_temp0';
  }

  @override
  String tokenDetailPromptTokens(int count) {
    return '$count токенов';
  }

  @override
  String tokenDetailPromptTokensWithCache(int count, int cached) {
    return '$count токенов ($cached из кэша)';
  }

  @override
  String tokenDetailCompletionTokens(int count) {
    return '$count токенов';
  }

  @override
  String tokenDetailSpeed(String value) {
    return '$value ток/с';
  }

  @override
  String tokenDetailDuration(String value) {
    return '$value с';
  }

  @override
  String tokenDetailFirstResponse(String value) {
    return '$value с (первый ответ)';
  }

  @override
  String tokenDetailFirstOutput(String value) {
    return '$value с (первый вывод)';
  }

  @override
  String tokenDetailTotalTokens(int count) {
    return '$count токенов';
  }

  @override
  String tokenDetailReasoningTokens(int count) {
    return '$count токенов';
  }

  @override
  String tokenDetailCacheWriteTokens(int count) {
    return '$count токенов записи в кэш';
  }

  @override
  String tokenDetailCost(String amount) {
    return '$amount';
  }

  @override
  String get debugPageTitle => 'Отладка';

  @override
  String get debugPageConversationToolsTitle => 'Инструменты чата';

  @override
  String get debugPageCreateOversizedConversationButton =>
      'Создать огромный чат (30 МБ)';

  @override
  String get debugPageCreateManyMessagesConversationButton =>
      'Создать чат из 1024 сообщений';

  @override
  String get debugPageCreateDailyMixedMarkdownConversationButton =>
      'Создать 3000 повседневных сообщений со смешанным Markdown';

  @override
  String get debugPageCreateLongReasoningConversationButton =>
      'Создать чат с длинными рассуждениями (128 сообщений)';

  @override
  String get debugPageCreatingButton => 'Создание...';

  @override
  String get debugPageCreatingOversizedConversation =>
      'Создание огромного чата на 30 МБ...';

  @override
  String get debugPageCreatingManyMessagesConversation =>
      'Создание чата из 1024 сообщений...';

  @override
  String get debugPageCreatingDailyMixedMarkdownConversation =>
      'Создание чата из 3000 повседневных сообщений со смешанным Markdown...';

  @override
  String get debugPageCreatingLongReasoningConversation =>
      'Создание длинного отладочного чата с рассуждением...';

  @override
  String get debugPageNoCurrentAssistant =>
      'Текущий ассистент не выбран. Сначала создайте или выберите ассистента.';

  @override
  String debugPageConversationCreated(int count) {
    return 'Создан отладочный чат с сообщениями: $count.';
  }

  @override
  String debugPageCreateConversationFailed(String error) {
    return 'Не удалось создать отладочный чат: $error';
  }

  @override
  String debugPageOversizedConversationTitle(int sizeMB) {
    return 'Тест огромного чата ($sizeMB МБ)';
  }

  @override
  String debugPageManyMessagesConversationTitle(int count) {
    return 'Тест чата из $count сообщений';
  }

  @override
  String debugPageDailyMixedMarkdownConversationTitle(int count) {
    return 'Тест повседневных сообщений с Markdown ($count)';
  }

  @override
  String debugPageLongReasoningConversationTitle(int count) {
    return 'Тест длинного рассуждения ($count сообщений)';
  }

  @override
  String get debugPageOversizedConversationSeedText =>
      'Это длинный отладочный текст для воспроизведения медленного рендеринга в огромных чатах. Он содержит повторяющийся текст в стиле Markdown, знаки препинания, иероглифы CJK и обычные слова, чтобы можно было профилировать рендеринг чата, хранение и прокрутку.';

  @override
  String debugPageManyMessagesSeedText(String role, int index) {
    return 'Сообщение $role #$index: быстрый случайный отладочный образец для проверки рендеринга списка, стабильности прокрутки, группировки сообщений и производительности истории чата.';
  }

  @override
  String get migrationIntroTitle => 'Обновление хранилища чатов';

  @override
  String get migrationIntroSubtitle =>
      'Kelivo переносит историю чатов в более быструю базу данных SQLite. Обновление выполняется до открытия приложения, чтобы данные оставались согласованными.';

  @override
  String get migrationBackupNote =>
      'Перед началом миграции Kelivo экспортирует ZIP-резервную копию с настройками, историей чатов и локальными файлами.';

  @override
  String get migrationPerformanceNote =>
      'После миграции запуск, загрузка истории и поиск используют индексы SQLite, что делает работу с длинными чатами плавнее.';

  @override
  String get migrationSourceDatabaseLabel => 'Hive';

  @override
  String get migrationTargetDatabaseLabel => 'SQLite';

  @override
  String get migrationChooseFolderButton =>
      'Выбрать папку и создать резервную копию';

  @override
  String get migrationSaveBackupButton => 'Сохранить ZIP-резервную копию';

  @override
  String get migrationStartWithoutBackupButton =>
      'Мигрировать без резервной копии';

  @override
  String get migrationSkipChatsJsonOption => 'Пропустить chats.json';

  @override
  String get migrationSkipChatsJsonDescription =>
      'Исходные файлы Hive, настройки и локальные файлы всё равно будут сохранены. Рекомендуется для очень больших историй.';

  @override
  String get migrationSkipBackupOption => 'Пропустить эту резервную копию';

  @override
  String get migrationSkipBackupDescription =>
      'Выбирайте это, только если у вас уже есть проверенная резервная копия. Миграция начнётся сразу.';

  @override
  String get migrationBackingUpTitle => 'Создание резервной копии';

  @override
  String get migrationBackingUpSubtitle =>
      'Экспорт настроек, истории чатов, загруженных файлов, изображений и шрифтов. Не закрывайте Kelivo до завершения.';

  @override
  String get migrationMigratingTitle => 'Миграция в SQLite';

  @override
  String get migrationMigratingSubtitle =>
      'Чаты и сообщения записываются пакетами, чтобы большие истории не перегружали память. Держите Kelivo на переднем плане до завершения миграции.';

  @override
  String migrationBackingUpDetail(String fileName) {
    return 'Резервное копирование $fileName';
  }

  @override
  String migrationMigratingDetail(int count) {
    return 'Мигрировано сообщений: $count';
  }

  @override
  String get migrationMigratingPrepareDetail => 'Подготовка базы данных SQLite';

  @override
  String get migrationMigratingToolEventsDetail =>
      'Миграция записей инструментов';

  @override
  String get migrationMigratingValidateDetail =>
      'Проверка мигрированных данных';

  @override
  String get migrationBackupReadyDetail => 'ZIP-резервная копия готова';

  @override
  String get migrationSavingBackupZipDetail => 'Сохранение ZIP-резервной копии';

  @override
  String get migrationBackupFileSavedTitle => 'ZIP-резервная копия сохранена';

  @override
  String get migrationChecklistBackupFiles =>
      'Экспорт ZIP-резервной копии Hive';

  @override
  String get migrationChecklistPrepareSqlite => 'Подготовка базы данных SQLite';

  @override
  String get migrationChecklistMigrateMessages => 'Миграция чатов и сообщений';

  @override
  String get migrationChecklistMigrateToolEvents =>
      'Миграция записей инструментов';

  @override
  String get migrationChecklistValidate => 'Проверка мигрированных данных';

  @override
  String get migrationStepBackup => 'Резервная копия';

  @override
  String get migrationStepMigrate => 'Миграция';

  @override
  String get migrationStepComplete => 'Готово';

  @override
  String get migrationCompleteTitle => 'Обновление завершено';

  @override
  String get migrationCompleteSubtitle =>
      'Ваша история чатов теперь хранится в SQLite. Перезапустите Kelivo, чтобы войти в обновлённое приложение.';

  @override
  String get migrationConversationCount => 'Чаты';

  @override
  String get migrationMessageCount => 'Сообщения';

  @override
  String get migrationConvertedCount => 'Преобразовано';

  @override
  String get migrationMalformedCount => 'С ошибками';

  @override
  String get migrationMissingFilesCount => 'Отсутствующие файлы';

  @override
  String get migrationRestartButton => 'Перезапустить Kelivo';

  @override
  String get migrationFailedTitle => 'Миграция не удалась';

  @override
  String get migrationFailedSubtitle =>
      'Исходные данные Hive не повреждены. Ранее завершённая резервная копия не изменена. Ознакомьтесь с причиной ниже и повторите попытку.';

  @override
  String get migrationUnknownError => 'Неизвестная ошибка миграции.';

  @override
  String get migrationFailureLogTitle => 'Журнал ошибок';

  @override
  String get migrationRetryButton => 'Повторить миграцию';

  @override
  String get migrationSkipButton => 'Пропустить миграцию и начать с нуля';

  @override
  String get migrationSkipDialogTitle => 'Пропустить миграцию?';

  @override
  String get migrationSkipDialogMessage =>
      'Kelivo запустится с пустой базой данных чатов. Старая история чатов останется на диске (переименована с суффиксом .retired), но НЕ будет перенесена и не появится в приложении. Если позже понадобится её восстановить, используйте резервную копию ZIP.';

  @override
  String get migrationSkipDialogCancel => 'Отмена';

  @override
  String get migrationSkipDialogConfirm => 'Пропустить и начать с нуля';

  @override
  String get migrationChatsExportDegradedNote =>
      'Экспорт chats.json был пропущен из-за ошибки. Резервная копия ZIP по-прежнему содержит исходные файлы Hive с полной историей чатов.';

  @override
  String get timelineJumpToLatest => 'Перейти к последнему';

  @override
  String largeContentShowMore(int count) {
    return 'Показать ещё $count';
  }

  @override
  String get largeContentCollapse => 'Свернуть';

  @override
  String get imageSettingsPageTitle => 'Обработка изображений';

  @override
  String get imageSettingsPageEditSectionTitle => 'Редактирование';

  @override
  String get imageSettingsPageQualitySectionTitle =>
      'Качество загружаемых изображений';

  @override
  String get imageSettingsPageQualityOriginal => 'Оригинал';

  @override
  String get imageSettingsPageQualityOriginalSubtitle =>
      'Без сжатия; загрузка как есть';

  @override
  String get imageSettingsPageQualityHigh => 'Высокое качество';

  @override
  String get imageSettingsPageQualityHighSubtitle =>
      'Длинная сторона 2048 пикс. · качество 90';

  @override
  String get imageSettingsPageQualityBalanced => 'Сбалансированное';

  @override
  String get imageSettingsPageQualityBalancedSubtitle =>
      'Длинная сторона 1568 пикс. · качество 85';

  @override
  String get imageSettingsPageQualitySaver => 'Экономия трафика';

  @override
  String get imageSettingsPageQualitySaverSubtitle =>
      'Длинная сторона 1024 пикс. · качество 70';

  @override
  String get imageSettingsPageQualityCustom => 'Своё';

  @override
  String get imageSettingsPageQualityCustomSubtitle =>
      'Выберите качество сжатия';

  @override
  String get imageSettingsPageCustomQualityTitle => 'Качество сжатия';

  @override
  String get imageSettingsPageCompressTransparentTitle =>
      'Сжимать прозрачные и анимированные изображения';

  @override
  String get imageSettingsPageCompressTransparentSubtitle =>
      'Если включено, прозрачные PNG, GIF и подобные форматы сжимаются; прозрачные области становятся белыми, а от анимации остаётся только первый кадр.';

  @override
  String get imageSettingsPageFooter =>
      'Сжатие выполняется при добавлении изображений. Ранее сохранённые или отправленные изображения не затрагиваются. Сжатые изображения отправляются как файлы JPEG.';

  @override
  String get imageSettingsPageSendSectionTitle => 'Отправка';

  @override
  String get imageSettingsPageMarkdownImageLinksTitle =>
      'Отправлять Markdown-ссылки на изображения как изображения';

  @override
  String get imageSettingsPageMarkdownImageLinksSubtitle =>
      'Если включено, ссылка ![alt](url) в тексте сообщения отправляется моделям зрения как изображение. Если выключено, она остаётся обычным текстом. Изображения, прикреплённые вами, всегда отправляются как изображения.';

  @override
  String get memoryTraceSettingsTitle => 'Трассировки конвейера';

  @override
  String get memoryTraceSettingsSubtitle =>
      'Пошагово просматривайте каждый фоновый запуск обработки памяти';

  @override
  String get memoryTracePageTitle => 'Трассировки конвейера памяти';

  @override
  String get memoryTraceRecordingSection => 'Запись';

  @override
  String get memoryTraceToggleTitle => 'Записывать трассировки конвейера';

  @override
  String get memoryTraceToggleSubtitle =>
      'Хранит в памяти только запросы, ответы и изменения последних фоновых запусков';

  @override
  String get memoryTraceRunsSection => 'Последние запуски';

  @override
  String get memoryTraceEmptyTitle => 'Трассировок пока нет';

  @override
  String get memoryTraceEmptySubtitle =>
      'Трассировки появятся здесь после запуска фонового конвейера памяти.';

  @override
  String get memoryTraceDisabledTitle => 'Запись выключена';

  @override
  String get memoryTraceDisabledSubtitle =>
      'Включите запись, чтобы зафиксировать следующий фоновый запуск обработки памяти.';

  @override
  String get memoryTraceClearAction => 'Очистить';

  @override
  String get memoryTraceClearSheetTitle => 'Очистить трассировки';

  @override
  String get memoryTraceClearSheetMessage =>
      'Это удалит все записанные трассировки. Трассировки никогда не записываются на диск, поэтому другие данные не затрагиваются.';

  @override
  String get memoryTraceClearConfirm => 'Очистить трассировки';

  @override
  String get memoryTraceCancel => 'Отмена';

  @override
  String get memoryTraceClearedToast => 'Трассировки очищены';

  @override
  String get memoryTraceCopyAction => 'Копировать';

  @override
  String get memoryTraceCopiedToast => 'Скопировано в буфер обмена';

  @override
  String get memoryTraceTriggerAuto => 'Авто';

  @override
  String get memoryTraceTriggerManual => 'Вручную';

  @override
  String get memoryTraceTriggerTool => 'Вызов инструмента';

  @override
  String get memoryTraceTriggerSummary => 'Сводка';

  @override
  String get memoryTraceScopeAssistant => 'Ассистент';

  @override
  String get memoryTraceScopeGlobal => 'Глобально';

  @override
  String get memoryTraceStepGatekeeper => 'Проверка допуска';

  @override
  String get memoryTraceStepExtract => 'Извлечение';

  @override
  String get memoryTraceStepSmartAdd => 'Умное добавление';

  @override
  String get memoryTraceStepDistiller => 'Дистилляция профиля';

  @override
  String get memoryTraceStepSummary => 'Сводка чата';

  @override
  String get memoryTraceStepChatSearch => 'Поиск по прошлым чатам';

  @override
  String get memoryTraceStepTool => 'Инструмент памяти';

  @override
  String get memoryTraceStatusSuccess => 'Успешно';

  @override
  String get memoryTraceStatusFailed => 'Ошибка';

  @override
  String get memoryTraceStatusSkipped => 'Пропущено';

  @override
  String get memoryTraceStatusRunning => 'Выполняется';

  @override
  String get memoryTraceOutcomeAdvanced => 'Водяной знак продвинут';

  @override
  String get memoryTraceOutcomeHeld => 'Водяной знак без изменений';

  @override
  String get memoryTraceOutcomeForced => 'Принудительное продвижение';

  @override
  String get memoryTraceDetailTitle => 'Детали трассировки';

  @override
  String get memoryTraceSectionOverview => 'Обзор';

  @override
  String get memoryTraceSectionPrompt => 'Промпт';

  @override
  String get memoryTraceSectionResponse => 'Необработанный ответ';

  @override
  String get memoryTraceSectionParsed => 'Разобранный результат';

  @override
  String get memoryTraceSectionMutations => 'Применённые изменения';

  @override
  String get memoryTraceFieldTime => 'Начало';

  @override
  String get memoryTraceFieldDuration => 'Длительность';

  @override
  String get memoryTraceFieldTrigger => 'Триггер';

  @override
  String get memoryTraceFieldScope => 'Область действия';

  @override
  String get memoryTraceFieldConversation => 'Чат';

  @override
  String get memoryTraceFieldAssistant => 'Ассистент';

  @override
  String get memoryTraceFieldWindow => 'Окно сообщений';

  @override
  String get memoryTraceFieldWatermark => 'Водяной знак';

  @override
  String get memoryTraceFieldOutcome => 'Результат';

  @override
  String get memoryTraceFieldError => 'Ошибка';

  @override
  String get memoryTraceMutationCreated => 'Создано';

  @override
  String get memoryTraceMutationMerged => 'Объединено';

  @override
  String get memoryTraceMutationEdited => 'Изменено';

  @override
  String get memoryTraceMutationArchived => 'В архиве';

  @override
  String get memoryTraceMutationLinked => 'Связано';

  @override
  String get memoryTraceMutationProfileWritten => 'Поле профиля записано';

  @override
  String get memoryTraceMutationProfileCleared => 'Поле профиля очищено';

  @override
  String get memoryTraceMutationSummary => 'Сводка чата записана';

  @override
  String get memoryTraceBefore => 'До';

  @override
  String get memoryTraceAfter => 'После';

  @override
  String get memoryTraceEmptyValue => '(пусто)';

  @override
  String memoryTraceStepsCount(int count) {
    return '$count шагов';
  }

  @override
  String memoryTraceMutationsCount(int count) {
    return '$count изменений';
  }

  @override
  String memoryTraceRepeatCount(int count) {
    return 'повторено $count×';
  }

  @override
  String memoryTraceWindowValue(int size, int start, int end) {
    return '$size сообщений · #$start–#$end';
  }

  @override
  String get memoryTraceShowMore => 'Показать полностью';

  @override
  String get memoryTraceShowLess => 'Свернуть';

  @override
  String get messageStyleSettingsPageTitle => 'Стиль сообщений';

  @override
  String get messageStyleSettingsPageReset => 'Сбросить';

  @override
  String get messageStyleSettingsPageResetConfirm =>
      'Сбросить все настройки стиля сообщений?';

  @override
  String get messageStyleSettingsPageCancel => 'Отмена';

  @override
  String get messageStyleSettingsPageLight => 'Светлая';

  @override
  String get messageStyleSettingsPageDark => 'Тёмная';

  @override
  String get messageStyleSettingsPageDefaultHint =>
      'Стиль по умолчанию следует текущей теме и не имеет дополнительных настроек.';

  @override
  String get messageStyleSettingsPageStyleDefaultSubtitle =>
      'Следует теме; не настраивается';

  @override
  String get messageStyleSettingsPageAssistantFitContent =>
      'Подгонять пузырь ассистента по содержимому';

  @override
  String get messageStyleSettingsPageAssistantFitContentSubtitle =>
      'Пузыри ассистента сжимаются по ширине текста, а не занимают всю строку';

  @override
  String get messageStyleSettingsPageAssistantSplitParagraphs =>
      'Разделять абзацы на пузыри';

  @override
  String get messageStyleSettingsPageAssistantSplitParagraphsSubtitle =>
      'Пустые строки разбивают ответ ассистента на отдельные пузыри для каждого абзаца';

  @override
  String get messageStyleSettingsPageStyleFrostedSubtitle =>
      'Полупрозрачное матовое стекло';

  @override
  String get messageStyleSettingsPageStyleSolidSubtitle =>
      'Непрозрачная сплошная заливка';

  @override
  String get messageStyleSettingsPageBlur => 'Размытие';

  @override
  String get messageStyleSettingsPageBlurHint =>
      'Размытие применяется к содержимому за пузырём. Без обоев чата оно почти незаметно.';

  @override
  String get messageStyleSettingsPageBackgroundColor => 'Фон';

  @override
  String get messageStyleSettingsPageBackgroundOpacity => 'Непрозрачность фона';

  @override
  String get messageStyleSettingsPageBorderColor => 'Граница';

  @override
  String get messageStyleSettingsPageBorderOpacity => 'Непрозрачность границы';

  @override
  String get messageStyleSettingsPageBorderWidth => 'Ширина границы';

  @override
  String get messageStyleSettingsPageTextColor => 'Текст';

  @override
  String get messageStyleSettingsPageCornerRadius => 'Радиус углов';

  @override
  String get messageStyleSettingsPagePreviewUser =>
      'Это сообщение пользователя';

  @override
  String get messageStyleSettingsPagePreviewAssistant =>
      'Это ответ ассистента.';

  @override
  String get messageStyleSettingsPagePreviewThinking => 'Размышление';

  @override
  String get messageStyleSettingsPageRoleUser => 'Пользователь';

  @override
  String get messageStyleSettingsPageRoleAssistant => 'Ассистент';

  @override
  String get messageStyleSettingsPageRoleAssistantHint =>
      'Настройки ассистента также применяются к карточкам рассуждения, вызова инструментов и перевода.';

  @override
  String get localSnapshotSectionTitle => 'Локальные копии';

  @override
  String get localSnapshotEnabledTitle => 'Хранить локальные копии';

  @override
  String get localSnapshotEnabledSubtitle =>
      'Kelivo периодически сохраняет копию своей базы данных на этом устройстве, чтобы данные не хранились только в одном месте.';

  @override
  String get localSnapshotIntervalTitle => 'Как часто';

  @override
  String get localSnapshotIntervalAutomatic => 'Автоматически';

  @override
  String get localSnapshotIntervalAutomaticDetail =>
      'Ежедневно, реже по мере роста базы данных';

  @override
  String localSnapshotIntervalDays(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'Каждые $days дня',
      many: 'Каждые $days дней',
      few: 'Каждые $days дня',
      one: 'Каждый день',
    );
    return '$_temp0';
  }

  @override
  String get localSnapshotKeepTitle => 'Сколько копий хранить';

  @override
  String localSnapshotKeepValue(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count копии',
      many: '$count копий',
      few: '$count копии',
      one: '$count копия',
    );
    return '$_temp0';
  }

  @override
  String get localSnapshotKeepSubtitle =>
      'Плюс по одной копии за прошлую неделю и прошлый месяц, чтобы проблему, замеченную не сразу, всё ещё можно было исправить.';

  @override
  String get localSnapshotKeepWeekly => 'Хранить одну за прошлую неделю';

  @override
  String get localSnapshotKeepMonthly => 'Хранить одну за прошлый месяц';

  @override
  String get localSnapshotKeepProtectedNote =>
      'Самая свежая копия, в которой ещё есть данные, никогда не удаляется автоматически, независимо от этого значения.';

  @override
  String get localSnapshotMaximumTitle => 'Ограничение места';

  @override
  String get localSnapshotMaximumUnlimited => 'Без ограничений';

  @override
  String get localSnapshotAnnounceTitle => 'Уведомлять о сохранении копии';

  @override
  String get localSnapshotAnnounceSubtitle =>
      'Об ошибках сообщается всегда. Эта настройка добавляет лишь краткое сообщение при успехе.';

  @override
  String get localSnapshotTakeNow => 'Сохранить копию сейчас';

  @override
  String get localSnapshotManageCopies => 'Управление копиями';

  @override
  String localSnapshotUsage(int count, String size) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count копии',
      many: '$count копий',
      few: '$count копии',
      one: '$count копия',
      zero: 'Нет копий',
    );
    return '$_temp0 · $size';
  }

  @override
  String get localSnapshotStatusNever => 'Копия ещё не сохранялась';

  @override
  String localSnapshotStatusSuccess(String when) {
    return 'Последняя копия: $when';
  }

  @override
  String localSnapshotStatusFailure(String when, String reason) {
    return 'Последняя попытка не удалась $when: $reason';
  }

  @override
  String get localSnapshotStatusSkippedSpace =>
      'Пропущено: недостаточно свободного места на устройстве';

  @override
  String get localSnapshotStatusUnchanged =>
      'С момента последней копии ничего не изменилось';

  @override
  String get localSnapshotCopiesTitle => 'Локальные копии';

  @override
  String get localSnapshotCopiesEmpty => 'Локальных копий пока нет';

  @override
  String get localSnapshotCopiesEmptyHint =>
      'Копия сохраняется автоматически при изменении данных, а также всегда перед восстановлением.';

  @override
  String get localSnapshotCopiesScopeNote =>
      'Локальные копии хранятся только на этом устройстве. Они защищают от повреждения данных внутри приложения, но не от потери устройства или удаления Kelivo — для этого используйте резервное копирование через WebDAV или S3.';

  @override
  String get localSnapshotOriginAutomatic => 'Автоматически';

  @override
  String get localSnapshotOriginManual => 'Сохранено вами';

  @override
  String get localSnapshotOriginBeforeRestore => 'Перед восстановлением';

  @override
  String get localSnapshotKindRecovered => 'Отложено при восстановлении';

  @override
  String localSnapshotCopyContents(int conversations, int messages) {
    String _temp0 = intl.Intl.pluralLogic(
      conversations,
      locale: localeName,
      other: '$conversations чата',
      many: '$conversations чатов',
      few: '$conversations чата',
      one: '$conversations чат',
    );
    String _temp1 = intl.Intl.pluralLogic(
      messages,
      locale: localeName,
      other: '$messages сообщения',
      many: '$messages сообщений',
      few: '$messages сообщения',
      one: '$messages сообщение',
    );
    return '$_temp0 · $_temp1';
  }

  @override
  String get localSnapshotCopyContentsUnknown =>
      'Содержимое станет известно после восстановления';

  @override
  String get localSnapshotCopyPinned => 'Сохранена';

  @override
  String get localSnapshotActionRestore => 'Восстановить';

  @override
  String get localSnapshotActionExport => 'Экспорт';

  @override
  String get localSnapshotActionDelete => 'Удалить';

  @override
  String get localSnapshotActionPin => 'Сохранить эту копию';

  @override
  String get localSnapshotActionUnpin => 'Больше не сохранять';

  @override
  String get localSnapshotRestoreTitle => 'Восстановить эту копию?';

  @override
  String localSnapshotRestoreMessage(String when) {
    return 'Текущие чаты и настройки будут заменены этой копией от $when. Сначала будет сохранена копия текущих чатов и настроек. Неотправленные черновики не входят в копии и будут удалены.';
  }

  @override
  String get localSnapshotRestorePreparing => 'Подготовка копии';

  @override
  String get localSnapshotDeleteTitle => 'Удалить эту копию?';

  @override
  String get localSnapshotDeleteMessage =>
      'Эта копия будет безвозвратно удалена с устройства. Любые данные в ней, которых нет в текущей базе данных, будут утеряны.';

  @override
  String get localSnapshotDeleteLastWarning =>
      'Это единственная копия, в которой ещё есть данные.';

  @override
  String get localSnapshotExportPreparing => 'Подготовка экспорта';

  @override
  String get localSnapshotExportDone => 'Копия экспортирована';

  @override
  String localSnapshotExportFailed(String reason) {
    return 'Не удалось экспортировать копию: $reason';
  }

  @override
  String get localSnapshotTakeDone => 'Копия сохранена';

  @override
  String localSnapshotTakeFailed(String reason) {
    return 'Не удалось сохранить копию: $reason';
  }

  @override
  String get localSnapshotDeleteDone => 'Копия удалена';

  @override
  String get localSnapshotBusyMessage =>
      'Другая задача резервного копирования уже выполняется';

  @override
  String get localSnapshotRunInBackground => 'Продолжить в фоне';

  @override
  String get localSnapshotRunningInBackground => 'Сохранение копии в фоне';

  @override
  String startupRecoveryLocalCopiesAvailable(int count, String when) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count локальной копии',
      many: '$count локальных копий',
      few: '$count локальные копии',
      one: '$count локальная копия',
    );
    return 'На этом устройстве всё ещё есть $_temp0, самая свежая от $when. Сброс их не удалит — после перезапуска можно восстановить одну из них в разделе Настройки › Резервное копирование › Локальные копии.';
  }

  @override
  String startupRecoveryRecoveredCopiesDeleted(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count копии базы данных',
      many: '$count копий базы данных',
      few: '$count копии базы данных',
      one: '$count копия базы данных',
    );
    String _temp1 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'их',
      many: 'их',
      few: 'их',
      one: 'её',
    );
    String _temp2 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'их',
      many: 'их',
      few: 'их',
      one: 'её',
    );
    return 'Кроме того, есть $_temp0, отложенная при предыдущем восстановлении, и сброс БЕЗВОЗВРАТНО удалит $_temp1. Если хотите сохранить $_temp2, сначала экспортируйте данные.';
  }

  @override
  String get toolSchemaSettingsPageTitle => 'Описания инструментов';

  @override
  String get toolSchemaSettingsGroupSearch => 'Поиск';

  @override
  String get toolSchemaSettingsGroupImages => 'Изображения';

  @override
  String get toolSchemaSettingsGroupMemory => 'Память';

  @override
  String get toolSchemaSettingsGroupLocal => 'Инструменты устройства';

  @override
  String get toolSchemaSettingsModified => 'Изменено';

  @override
  String get toolSchemaSettingsResetDefault => 'Восстановить по умолчанию';

  @override
  String get toolSchemaSettingsResetAll =>
      'Восстановить все значения по умолчанию';

  @override
  String get toolSchemaSettingsResetAllTitle =>
      'Восстановить все значения по умолчанию?';

  @override
  String get toolSchemaSettingsResetAllMessage =>
      'Все описания встроенных инструментов будут восстановлены до значений по умолчанию. Ваши пользовательские формулировки будут потеряны.';

  @override
  String get toolSchemaSettingsResetAllConfirm => 'Восстановить';

  @override
  String toolSchemaSettingsParamDescriptions(int count) {
    return 'Описания параметров ($count)';
  }

  @override
  String get toolSchemaSettingsMemoryLangNote =>
      'Описания инструмента памяти по умолчанию следуют языку промпта памяти. Пользовательское описание хранится один раз для каждого инструмента и не изменится при смене этого языка.';

  @override
  String get toolSchemaSettingsDescriptionLabel => 'Описание';

  @override
  String get toolSchemaSettingsToolName => 'Имя инструмента';

  @override
  String get toolSchemaEditorPageTitle => 'Изменить описание';

  @override
  String get toolSchemaSettingsCancel => 'Отмена';

  @override
  String get workspaceFileNotAvailable => 'Файл недоступен';

  @override
  String get workspaceTerminalNotAvailable => 'Терминал недоступен';

  @override
  String get workspacePreviewCopyPath => 'Копировать путь';

  @override
  String get workspacePreviewShare => 'Поделиться';

  @override
  String get workspacePreviewOpenExternally => 'Открыть во внешнем приложении';

  @override
  String get workspacePreviewOpenWith => 'Открыть с помощью…';

  @override
  String get workspacePreviewFileTooLarge =>
      'Файл слишком большой для предпросмотра. Откройте его во внешнем приложении.';

  @override
  String get workspacePreviewSource => 'Исходный код';

  @override
  String get workspacePreviewRendered => 'Просмотр';

  @override
  String get workspacePreviewFileName => 'Имя';

  @override
  String get workspacePreviewFileSize => 'Размер';

  @override
  String get workspacePreviewFileModified => 'Изменён';

  @override
  String get workspacePreviewPathCopied => 'Путь скопирован';

  @override
  String workspacePreviewLineCount(int count) {
    return 'Строк: $count';
  }

  @override
  String get workspaceFilesSort => 'Сортировка';

  @override
  String get workspaceFilesSortName => 'Имя';

  @override
  String get workspaceFilesSortModified => 'Изменён';

  @override
  String get workspaceFilesSortSize => 'Размер';

  @override
  String get workspaceFilesSortAscending => 'По возрастанию';

  @override
  String get workspaceFilesSortDescending => 'По убыванию';

  @override
  String get workspaceFilesShowHidden => 'Показать скрытые файлы';

  @override
  String get workspaceFilesHideHidden => 'Скрыть скрытые файлы';

  @override
  String get workspaceFilesRefresh => 'Обновить';

  @override
  String get workspaceFilesNewFolder => 'Новая папка';

  @override
  String get workspaceFilesNewFile => 'Новый файл';

  @override
  String get workspaceFilesImport => 'Импорт';

  @override
  String get workspaceFilesExport => 'Экспорт';

  @override
  String get workspaceFilesExportFolder => 'Экспортировать папку';

  @override
  String get workspaceFilesEmpty => 'Эта папка пуста';

  @override
  String get workspaceFilesError => 'Не удалось загрузить эти файлы';

  @override
  String get workspaceFilesRetry => 'Повторить';

  @override
  String get workspaceFilesPreview => 'Предпросмотр';

  @override
  String get workspaceFilesRename => 'Переименовать';

  @override
  String get workspaceFilesMove => 'Переместить';

  @override
  String get workspaceFilesDelete => 'Удалить';

  @override
  String get workspaceFilesShare => 'Поделиться';

  @override
  String get workspaceFilesCopyPath => 'Копировать путь';

  @override
  String get workspaceFilesExportItem => 'Экспорт';

  @override
  String get workspaceFilesNameLabel => 'Имя';

  @override
  String get workspaceFilesNameHint => 'Введите имя';

  @override
  String get workspaceFilesCreate => 'Создать';

  @override
  String get workspaceFilesCancel => 'Отмена';

  @override
  String get workspaceFilesConfirm => 'Подтвердить';

  @override
  String get workspaceFilesSave => 'Сохранить';

  @override
  String get workspaceFilesDeleteTitle => 'Удалить этот элемент?';

  @override
  String workspaceFilesDeleteMessage(String name) {
    return 'Удалить $name?';
  }

  @override
  String workspaceFilesDeleteFolderMessage(String name) {
    return 'Удалить папку $name и всё её содержимое?';
  }

  @override
  String get workspaceFilesMoveTitle => 'Переместить в папку';

  @override
  String get workspaceFilesMoveHere => 'Переместить сюда';

  @override
  String get workspaceFilesPathCopied => 'Путь скопирован';

  @override
  String get workspaceFilesInvalidName => 'Недопустимое имя';

  @override
  String get workspaceFilesInvalidPath =>
      'Этот путь находится за пределами текущей папки';

  @override
  String workspaceFilesOperationFailed(String error) {
    return 'Не удалось выполнить действие: $error';
  }

  @override
  String get workspaceFilesActions => 'Действия';

  @override
  String get workspaceFilesMore => 'Ещё';

  @override
  String get workspaceFilesJustNow => 'Только что';

  @override
  String workspaceFilesMinutesAgo(int count) {
    return '$count мин назад';
  }

  @override
  String workspaceFilesHoursAgo(int count) {
    return '$count ч назад';
  }

  @override
  String workspaceFilesDaysAgo(int count) {
    return '$count дн назад';
  }

  @override
  String get workspaceFilesPanelTitle => 'Файлы чата';

  @override
  String get workspaceFilesTabAttachments => 'Вложения';

  @override
  String get workspaceFilesTabOutputs => 'Результаты';

  @override
  String get workspaceFilesTabWorkspace => 'Рабочая область';

  @override
  String get workspaceFilesNoWorkspaceBound => 'Рабочая область не привязана';

  @override
  String get workspaceFilesKindManaged => 'Управляемая';

  @override
  String get workspaceFilesKindLinked => 'Связанная';

  @override
  String get workspaceFilesMissingWorkspace => 'Рабочая область не найдена';

  @override
  String get workspaceFilesClose => 'Закрыть';

  @override
  String get workspacesTitle => 'Рабочие области';

  @override
  String get workspacesCreate => 'Создать';

  @override
  String get workspacesCreateTitle => 'Новая рабочая область';

  @override
  String get workspacesNameLabel => 'Название';

  @override
  String get workspacesNameHint => 'Название рабочей области';

  @override
  String get workspacesLinkFolder => 'Связать папку';

  @override
  String get workspacesEmpty => 'Рабочих областей пока нет';

  @override
  String get workspacesEmptyCta => 'Создать рабочую область';

  @override
  String get workspacesSettings => 'Настройки';

  @override
  String get workspacesOpenFiles => 'Открыть файлы';

  @override
  String get workspacesLastUsedNever => 'Не использовалась';

  @override
  String workspacesLastUsed(String when) {
    return 'Последнее использование: $when';
  }

  @override
  String get workspacesDeleteTitle => 'Удалить эту рабочую область?';

  @override
  String workspacesDeleteMessage(String name) {
    return 'Удалить рабочую область $name?';
  }

  @override
  String get workspacesDeleteAlsoFiles => 'Также удалить файлы';

  @override
  String get workspacesUnlinkTitle => 'Отвязать эту рабочую область?';

  @override
  String workspacesUnlinkMessage(String name) {
    return 'Отвязать $name? Файлы на диске будут сохранены.';
  }

  @override
  String get workspacesSettingsTitle => 'Настройки рабочей области';

  @override
  String get workspacesShellNeedsApproval =>
      'Спрашивать перед выполнением команд оболочки';

  @override
  String get workspacesDefaultCwd => 'Рабочий каталог по умолчанию';

  @override
  String get workspacesDefaultCwdHint => 'Относительный путь, например src';

  @override
  String get workspacesDefaultCwdInvalid =>
      'Используйте относительный путь без ..';

  @override
  String get workspacesCreateManaged => 'Создать рабочую область';

  @override
  String get workspacesLinkExisting => 'Привязать существующую папку';

  @override
  String get workspacesUnlink => 'Отвязать';

  @override
  String get workspacesItemMore => 'Действия с рабочей областью';

  @override
  String get workspaceToolDenied => 'Отклонено';

  @override
  String get workspaceToolTimeout => 'тайм-аут';

  @override
  String get workspaceToolCancelled => 'отменено';

  @override
  String get workspaceToolInterrupted => 'прервано';

  @override
  String get workspaceToolEnvironmentNotReady => 'Песочница не установлена';

  @override
  String get workspaceToolInstall => 'Установить';

  @override
  String get workspaceToolFuzzy => 'нечёткое';

  @override
  String get workspaceToolCreated => 'создано';

  @override
  String get workspaceToolUpdated => 'обновлено';

  @override
  String get workspaceToolTruncated => 'обрезано';

  @override
  String get workspaceToolImageTag => 'изображение';

  @override
  String get workspaceToolStdout => 'stdout';

  @override
  String get workspaceToolStderr => 'stderr';

  @override
  String get workspaceToolOpenFullOutput => 'Открыть полный вывод';

  @override
  String get workspaceToolChangedFiles => 'Изменённые файлы';

  @override
  String get workspaceToolCancel => 'Отмена';

  @override
  String get workspaceToolCopyCommand => 'Копировать команду';

  @override
  String get workspaceToolCopyOutput => 'Копировать вывод';

  @override
  String get workspaceToolCopyDiff => 'Копировать diff';

  @override
  String get workspaceToolCopied => 'Скопировано';

  @override
  String get workspaceToolDiffTruncated => 'Diff обрезан';

  @override
  String get workspaceToolOpenPreview => 'Открыть предпросмотр';

  @override
  String get workspaceToolNoOutput => 'Нет вывода';

  @override
  String get workspaceToolNotAvailable => 'Недоступно';

  @override
  String get workspaceToolClose => 'Закрыть';

  @override
  String get workspaceToolTitleShell => 'Выполнить команду';

  @override
  String get workspaceToolTitleReadFile => 'Прочитать файл';

  @override
  String get workspaceToolTitleViewImage => 'Просмотр изображения';

  @override
  String get workspaceToolTitleWriteFile => 'Записать файл';

  @override
  String get workspaceToolTitleEditFile => 'Редактировать файл';

  @override
  String get workspaceToolTitleListDir => 'Список каталога';

  @override
  String get workspaceToolTitleGlob => 'Glob';

  @override
  String get workspaceToolTitleGrep => 'Grep';

  @override
  String workspaceToolCount(int count) {
    return '$count';
  }

  @override
  String workspaceToolMoreFiles(int count) {
    return '+$count';
  }

  @override
  String workspaceToolDurationMs(int ms) {
    return '$ms мс';
  }

  @override
  String workspaceToolDurationSec(String sec) {
    return '$sec с';
  }

  @override
  String get workspaceEnvTitle => 'Среда';

  @override
  String workspaceEnvEngineUbuntu(String version) {
    return 'Ubuntu $version (PRoot)';
  }

  @override
  String workspaceEnvEngineAlpine(String version) {
    return 'Alpine $version (iSH)';
  }

  @override
  String get workspaceEnvEngineNative => 'Системная оболочка';

  @override
  String get workspaceEnvPhaseNotInstalled => 'Не установлено';

  @override
  String get workspaceEnvPhaseDownloading => 'Загрузка';

  @override
  String get workspaceEnvPhaseVerifying => 'Проверка';

  @override
  String get workspaceEnvPhaseExtracting => 'Распаковка';

  @override
  String get workspaceEnvPhasePatching => 'Настройка';

  @override
  String get workspaceEnvPhaseReady => 'Готово';

  @override
  String get workspaceEnvPhaseError => 'Ошибка';

  @override
  String get workspaceEnvPhaseNeedsRestart => 'Требуется перезапуск';

  @override
  String workspaceEnvMetaLine(String version, String arch) {
    return '$version · $arch';
  }

  @override
  String workspaceEnvInstalledAt(String date) {
    return 'Установлено $date';
  }

  @override
  String workspaceEnvDiskUsage(String size) {
    return 'Занято $size';
  }

  @override
  String workspaceEnvRuntimeReason(String reason) {
    return '$reason';
  }

  @override
  String get workspaceEnvInstall => 'Установить';

  @override
  String get workspaceEnvInstallSubtitleAndroid =>
      'Выберите Ubuntu, Alpine, Debian или импортируйте локальный образ rootfs.';

  @override
  String get workspaceEnvInstallSubtitleIos => 'Встроено, без загрузки';

  @override
  String get workspaceEnvCancel => 'Отмена';

  @override
  String get workspaceEnvRetry => 'Повторить';

  @override
  String get workspaceEnvRepair => 'Восстановить';

  @override
  String get workspaceEnvReset => 'Сбросить';

  @override
  String get workspaceEnvResetConfirmTitle => 'Сбросить окружение?';

  @override
  String get workspaceEnvResetConfirmBody =>
      'Это удалит установленные пакеты и файловую систему песочницы.';

  @override
  String get workspaceEnvCheckForUpdate => 'Проверить обновления';

  @override
  String get workspaceEnvUpdate => 'Обновить';

  @override
  String workspaceEnvAvailableVersion(String version) {
    return 'Доступна версия $version';
  }

  @override
  String get workspaceEnvUpToDate => 'У вас последняя версия';

  @override
  String get workspaceEnvRestartBanner =>
      'Перезапустите Kelivo, чтобы завершить';

  @override
  String get workspaceEnvDetectingMirrors => 'Поиск самых быстрых зеркал…';

  @override
  String workspaceEnvApplyingMirror(String category) {
    return 'Применение зеркала $category…';
  }

  @override
  String get workspaceEnvMirrorsSection => 'Зеркала';

  @override
  String get workspaceEnvUseMirror => 'Использовать зеркало';

  @override
  String get workspaceEnvDetect => 'Проверить скорость';

  @override
  String get workspaceEnvOfficial => 'Официальное';

  @override
  String get workspaceEnvMirrorsDisabled =>
      'Изменения зеркал выполняются в песочнице и недоступны, пока она не готова.';

  @override
  String workspaceEnvMirrorsDisabledReason(String reason) {
    return 'Изменения зеркал выполняются в песочнице и недоступны: $reason';
  }

  @override
  String get workspaceEnvMirrorDetectTitle => 'Скорость зеркал';

  @override
  String workspaceEnvMirrorLatency(int ms) {
    return '$ms мс';
  }

  @override
  String workspaceEnvMirrorFailed(String reason) {
    return '$reason';
  }

  @override
  String get workspaceEnvErrorUnsupportedAbi =>
      'Архитектура этого устройства не поддерживается.';

  @override
  String get workspaceEnvErrorArchitectureMismatch =>
      'Архитектура установленной песочницы не соответствует этому приложению. Переустановите песочницу, чтобы продолжить. Ваши существующие файлы песочницы сохранены.';

  @override
  String get workspaceEnvErrorProotMissing =>
      'Отсутствует исполняемый файл PRoot.';

  @override
  String get workspaceEnvErrorInsufficientDisk =>
      'Недостаточно свободного места для установки песочницы.';

  @override
  String get workspaceEnvErrorInsufficientDiskHint =>
      'Освободите больше места для выбранного образа и повторите попытку.';

  @override
  String get workspaceEnvErrorNetwork =>
      'Не удалось загрузить. Проверьте подключение и повторите попытку.';

  @override
  String get workspaceEnvErrorChecksumMismatch =>
      'Загруженный файл повреждён. Повторите попытку.';

  @override
  String get workspaceEnvErrorExtractFailed =>
      'Не удалось распаковать образ песочницы.';

  @override
  String get workspaceEnvErrorCleanupFailed =>
      'Не удалось удалить старые файлы песочницы. Повторите попытку.';

  @override
  String get workspaceEnvCleanupIncomplete =>
      'Песочница готова, но некоторые старые файлы не удалось удалить. Они по-прежнему занимают место.';

  @override
  String get workspaceEnvErrorResetFailed =>
      'Не удалось завершить сброс песочницы. Повторите попытку.';

  @override
  String get workspaceEnvErrorPatchFailed =>
      'Не удалось завершить настройку песочницы.';

  @override
  String get workspaceEnvErrorRepairInterrupted =>
      'Исправление песочницы было прервано. Существующая песочница сохранена. Повторите попытку, чтобы завершить исправление.';

  @override
  String get workspaceEnvErrorRepairTimeout =>
      'Время ожидания исправления песочницы истекло. Проверьте подключение к сети и повторите попытку. Существующая песочница сохранена.';

  @override
  String get workspaceEnvRepairRestartBanner =>
      'Не удалось подтвердить, что исправление песочницы остановилось в пределах отведённого времени. Полностью закройте и снова откройте Kelivo, прежде чем повторять попытку. Существующая песочница сохранена.';

  @override
  String get workspaceEnvErrorCancelled => 'Установка отменена.';

  @override
  String get workspaceEnvErrorGeneric =>
      'При установке песочницы произошла ошибка.';

  @override
  String get workspaceEnvChipInstall => 'Установить песочницу';

  @override
  String workspaceEnvChipInstalling(int percent) {
    return 'Установка… $percent %';
  }

  @override
  String get workspaceEnvChipInstallingIndeterminate => 'Установка…';

  @override
  String get workspaceEnvChipError => 'Ошибка песочницы';

  @override
  String get workspaceEnvChipRestart => 'Требуется перезапуск';

  @override
  String get workspaceEnvNativeExplanation =>
      'На десктопе Kelivo использует системную оболочку вместо песочницы Linux.';

  @override
  String workspaceEnvNativeShellPath(String path) {
    return 'Оболочка: $path';
  }

  @override
  String get workspaceEnvNativeShellApproval =>
      'В режиме «Запрашивать подтверждение» инструмент оболочки требует подтверждения.';

  @override
  String workspaceEnvDownloadProgress(
    String downloaded,
    String total,
    int percent,
  ) {
    return '$downloaded / $total МБ ($percent%)';
  }

  @override
  String get workspaceEnvMirrorsFailed => 'Не удалось обнаружить зеркала';

  @override
  String get workspaceEnvCategoryApt => 'APT';

  @override
  String get workspaceEnvCategoryApk => 'APK';

  @override
  String get workspaceEnvCategoryPip => 'pip';

  @override
  String get workspaceEnvCategoryNpm => 'npm';

  @override
  String get skillsTitle => 'Навыки';

  @override
  String get skillsTab => 'Навыки';

  @override
  String get skillsSearchHint => 'Поиск навыков';

  @override
  String get skillsEmptyTitle => 'Навыков пока нет';

  @override
  String get skillsEmptyBody =>
      'Навык — это папка с файлом SKILL.md. Вставьте Markdown, импортируйте файл .md или .zip либо установите с GitHub.';

  @override
  String get skillsEmptyFormat =>
      '---\nname: my-skill\ndescription: Что делает этот навык\n---\n\n# Инструкции';

  @override
  String get skillsImport => 'Импорт';

  @override
  String get skillsImportPaste => 'Вставить Markdown';

  @override
  String get skillsImportFile => 'Из файла';

  @override
  String get skillsImportGitHub => 'С GitHub';

  @override
  String get skillsImportPasteLabel => 'SKILL.md';

  @override
  String get skillsImportPasteHint => 'Вставьте SKILL.md с YAML-заголовком';

  @override
  String get skillsImportGitHubLabel => 'URL GitHub';

  @override
  String get skillsImportGitHubHint =>
      'github.com/owner/repo или github.com/owner/repo/tree/ref/path';

  @override
  String get skillsImportConfirm => 'Импорт';

  @override
  String get skillsCancel => 'Отмена';

  @override
  String get skillsSave => 'Сохранить';

  @override
  String skillsUsedCount(int count) {
    return 'использовано $count раз';
  }

  @override
  String get skillsEnabled => 'Включено';

  @override
  String get skillsBrowseFiles => 'Просмотр файлов';

  @override
  String get skillsEdit => 'Изменить';

  @override
  String get skillsExport => 'Экспорт';

  @override
  String get skillsDelete => 'Удалить';

  @override
  String get skillsDeleteTitle => 'Удалить этот навык?';

  @override
  String skillsDeleteMessage(String name) {
    return 'Удалить $name? Это действие нельзя отменить.';
  }

  @override
  String get skillsUseAll => 'Использовать все навыки';

  @override
  String get skillsUseAllSubtitle =>
      'Этому ассистенту доступны все включённые навыки.';

  @override
  String get skillsDisabledHint =>
      'Включите этот навык на странице «Навыки», чтобы использовать его здесь.';

  @override
  String get skillsOpenPage => 'Управление навыками';

  @override
  String get skillsInheritAssistant => 'Наследовать от ассистента';

  @override
  String get skillsInheritAssistantSubtitle =>
      'Использовать те же навыки, что и у ассистента этого чата.';

  @override
  String get skillsActiveLabel => 'Активен';

  @override
  String get skillsSessionTitle => 'Навыки для этого чата';

  @override
  String get skillsEditTitle => 'Изменить навык';

  @override
  String get skillsDetailKindLabel => 'Навык';

  @override
  String get skillsNoEnabled => 'Нет включённых навыков';

  @override
  String get terminalTitle => 'Терминал';

  @override
  String get terminalOpenInSystem => 'Открыть в системном терминале';

  @override
  String get terminalHostDirectory => 'Каталог хоста';

  @override
  String get terminalBindWorkspaceFirst => 'Сначала привяжите рабочую область';

  @override
  String get terminalNotAvailable => 'Недоступно';

  @override
  String get terminalRuntimeUnavailable => 'Среда терминала не готова';

  @override
  String get terminalRename => 'Переименовать';

  @override
  String get terminalClose => 'Закрыть';

  @override
  String get terminalClear => 'Очистить';

  @override
  String get terminalCloseSession => 'Закрыть сеанс';

  @override
  String get terminalCopy => 'Копировать';

  @override
  String get terminalPaste => 'Вставить';

  @override
  String get terminalNewSession => 'Новый сеанс';

  @override
  String get terminalMore => 'Ещё';

  @override
  String get terminalNameLabel => 'Название';

  @override
  String get terminalCancel => 'Отмена';

  @override
  String get terminalSave => 'Сохранить';

  @override
  String get workspaceDeskMenuWorkspace => 'Рабочая область';

  @override
  String get workspaceDeskMenuSkills => 'Навыки';

  @override
  String get workspaceDeskBarTitle => 'Рабочая область';

  @override
  String get workspaceDeskBarNoWorkspace => 'Нет рабочей области';

  @override
  String get workspaceDeskBarEmptyHint =>
      'Привяжите рабочую область на панели инструментов, чтобы просматривать здесь файлы';

  @override
  String get workspaceDeskBarToggle => 'Файлы рабочей области';

  @override
  String get workspaceDeskOpenSystemTerminal => 'Открыть в системном терминале';

  @override
  String get workspaceDeskReveal => 'Показать в файловом менеджере';

  @override
  String get workspaceDeskBarClose => 'Закрыть панель рабочей области';

  @override
  String get workspaceEntryBind => 'Привязать рабочую область';

  @override
  String get workspaceEntryUnbind => 'Отвязать';

  @override
  String get workspaceEntryChange => 'Изменить';

  @override
  String get workspaceEntrySetAssistantDefault =>
      'Сделать рабочей областью ассистента по умолчанию';

  @override
  String get workspaceEntryLocked => 'Заблокировано';

  @override
  String get workspaceEntryChangeConfirmTitle => 'Изменить рабочую область?';

  @override
  String get workspaceEntryUnbindConfirmTitle => 'Отвязать?';

  @override
  String get workspaceEntryChangeConfirmBody =>
      'В этом чате уже использовались инструменты рабочей области. Ссылки на файлы в предыдущих сообщениях могут перестать работать.';

  @override
  String get workspaceEntryCwd => 'Рабочий каталог';

  @override
  String get workspaceEntryCwdHint => 'Относительно корня рабочей области';

  @override
  String get workspaceEntryCwdInvalid =>
      'Этот путь недопустим или выходит за пределы рабочей области';

  @override
  String get workspaceEntryCwdMissing => 'Этот каталог не существует';

  @override
  String get workspaceEntryCwdCreate => 'Создать его';

  @override
  String get workspaceEntryFiles => 'Файлы';

  @override
  String get workspaceEntryTerminal => 'Терминал';

  @override
  String get workspaceEntryOpenSystemTerminal =>
      'Открыть в системном терминале';

  @override
  String get workspaceEntryReveal => 'Показать в файловом менеджере';

  @override
  String get workspaceEntrySessionSkills => 'Навыки';

  @override
  String get workspaceEntryEnvironment => 'Среда';

  @override
  String get workspaceEntryManage => 'Управление рабочими областями';

  @override
  String get workspaceEntryCreate => 'Создать новую рабочую область…';

  @override
  String get workspaceEntryDefaultWorkspace => 'Рабочая область по умолчанию';

  @override
  String get workspaceEntryDefaultWorkspaceSubtitle =>
      'Новые чаты используют эту рабочую область. Существующие чаты не изменяются.';

  @override
  String get workspaceEntryDefaultWorkspaceUnset => 'Не задана';

  @override
  String get workspaceEntryDefaultWorkspaceAutomaticSubtitle =>
      'Первая рабочая область, привязанная к чату, будет запомнена для новых чатов.';

  @override
  String workspaceBindingRememberedDefault(String assistant) {
    return 'Запомнена как рабочая область по умолчанию для «$assistant». Новые чаты будут её использовать.';
  }

  @override
  String workspaceBindingSuggestDefault(String assistant) {
    return 'Использовать эту рабочую область и для будущих чатов с «$assistant»?';
  }

  @override
  String get workspaceBindingUndoDefault => 'Отменить';

  @override
  String get workspaceBindingUseAsDefault => 'Сделать по умолчанию';

  @override
  String get workspaceEntryNone => 'Нет';

  @override
  String get workspaceEntryStartConversationFirst => 'Сначала начните чат';

  @override
  String get workspaceEntryTooltip => 'Рабочая область';

  @override
  String get workspaceEntryPickerTitle => 'Выберите рабочую область';

  @override
  String get settingsPageWorkspace => 'Рабочая область и окружение';

  @override
  String get settingsPageSkills => 'Навыки';

  @override
  String get commonClose => 'Закрыть';

  @override
  String get terminalCopyAllOutput => 'Копировать весь вывод';

  @override
  String get terminalFontDecrease => 'Размер шрифта −';

  @override
  String get terminalFontIncrease => 'Размер шрифта +';

  @override
  String get terminalCloseSessionConfirmMessage =>
      'Сеанс всё ещё выполняется. Закрытие завершит процесс.';

  @override
  String get terminalCopiedAll => 'Весь вывод скопирован';

  @override
  String get terminalConfirm => 'Подтвердить';

  @override
  String terminalExitCode(int code) {
    return 'exit $code';
  }

  @override
  String get workspaceMgmtNewWorkspace => 'Новая рабочая область';

  @override
  String get workspaceMgmtEmptyHint =>
      'Создайте рабочую область, чтобы хранить файлы проекта вместе.';

  @override
  String get workspaceMgmtKindManagedTitle => 'Управляемая рабочая область';

  @override
  String get workspaceMgmtKindManagedSubtitle =>
      'Папка приложения, чтение и запись в песочнице';

  @override
  String get workspaceMgmtKindLinkedTitle => 'Связанная папка';

  @override
  String get workspaceMgmtKindLinkedSubtitle =>
      'Использовать папку на этом компьютере';

  @override
  String get workspaceMgmtImportFromFolder => 'Импорт из папки';

  @override
  String get workspaceMgmtImportFromFolderSubtitle =>
      'Скопировать папку в новую управляемую рабочую область';

  @override
  String get workspaceMgmtKindSection => 'Тип';

  @override
  String get workspaceMgmtCreate => 'Создать';

  @override
  String get workspaceMgmtShellApprovalSubtitle =>
      'Спрашивать перед каждой командой';

  @override
  String get workspaceMgmtDefaultCwdRoot => '/';

  @override
  String get workspaceMgmtPickCwdTitle => 'Рабочий каталог по умолчанию';

  @override
  String get workspaceMgmtFolderPickerUnavailable => 'Выбор папки недоступен.';

  @override
  String get workspaceMgmtImportProgressTitle => 'Импорт папки';

  @override
  String get workspaceMgmtImportProgressPhase => 'Копирование файлов…';

  @override
  String get workspaceMgmtImportFailed => 'Не удалось импортировать эту папку.';

  @override
  String workspaceMgmtImportDone(String name) {
    return 'Импортировано: $name';
  }

  @override
  String get workspaceMgmtLastUsedJustNow => 'только что';

  @override
  String workspaceMgmtLastUsedMinutesAgo(int n) {
    return '$n мин назад';
  }

  @override
  String workspaceMgmtLastUsedHoursAgo(int n) {
    return '$n ч назад';
  }

  @override
  String workspaceMgmtLastUsedDaysAgo(int n) {
    return '$n дн назад';
  }

  @override
  String workspaceMgmtRowDetail(String kind, String when) {
    return '$kind · Последнее использование $when';
  }

  @override
  String workspaceMgmtRowDetailNever(String kind) {
    return '$kind · Не использовалась';
  }

  @override
  String get workspacePreviewBack => 'Назад';

  @override
  String get workspacePreviewWrap => 'Перенос строк';

  @override
  String get workspacePreviewFontDecrease => 'Уменьшить текст';

  @override
  String get workspacePreviewFontIncrease => 'Увеличить текст';

  @override
  String get workspacePreviewCopy => 'Копировать';

  @override
  String get workspacePreviewRetry => 'Повторить';

  @override
  String get workspacePreviewLoadError => 'Не удалось загрузить этот файл.';

  @override
  String get workspacePreviewRevealInFinder => 'Показать в Finder';

  @override
  String get workspacePreviewOpenInSystemApp =>
      'Открыть в системном приложении';

  @override
  String get workspacePreviewOpenInBrowser => 'Открыть в браузере';

  @override
  String get workspacePreviewTable => 'Таблица';

  @override
  String get workspacePreviewPlainLanguage => 'Код';

  @override
  String get workspacePreviewOpen => 'Открыть';

  @override
  String get workspacePreviewRevealFailed =>
      'Не удалось показать этот файл в файловом менеджере.';

  @override
  String get workspacePreviewEmptyTable => 'Эта таблица пуста.';

  @override
  String get workspaceFilesNew => 'Создать';

  @override
  String get workspaceFilesFoldersFirst => 'Сначала папки';

  @override
  String get workspaceFilesSelectDirectory => 'Выбрать эту папку';

  @override
  String get workspaceFilesEmptyHint =>
      'Добавьте файлы через «Создать» или «Импорт»';

  @override
  String get workspaceFilesEmptyAttachments => 'Вложений пока нет';

  @override
  String get workspaceFilesEmptyOutputs =>
      'Ассистент ещё не создал ни одного файла';

  @override
  String get workspaceFilesMoveTo => 'Переместить в…';

  @override
  String workspaceFilesItemCount(int count) {
    return '$count элементов';
  }

  @override
  String get skillsImportTooltip => 'Импортировать навык';

  @override
  String get skillsImportPasteSubtitle =>
      'Вставьте SKILL.md с YAML frontmatter';

  @override
  String get skillsImportFileSubtitle => 'Выберите файл .md или .zip';

  @override
  String get skillsImportGitHubSubtitle =>
      'Импортировать SKILL.md из репозитория';

  @override
  String get skillsImportResolving => 'Разрешение репозитория…';

  @override
  String get skillsImportDownloading => 'Загрузка…';

  @override
  String get skillsImportExtracting => 'Распаковка…';

  @override
  String get skillsImportInstalling => 'Установка…';

  @override
  String get skillsImportGitHubRepoLabel => 'URL репозитория';

  @override
  String get skillsImportGitHubUrlHint =>
      'https://github.com/owner/repo или owner/repo[/path]';

  @override
  String get skillsImportGitHubHelp =>
      'Поддерживается SKILL.md в корне репозитория или в подкаталоге.';

  @override
  String get skillsEmptyHint =>
      'Навык — это SKILL.md с frontmatter. После импорта ассистент сможет использовать его по необходимости.';

  @override
  String get skillsMoreActions => 'Ещё';

  @override
  String get skillsSearchClear => 'Очистить';

  @override
  String get skillsSessionEmpty =>
      'Включённых навыков пока нет. Сначала включите навыки в библиотеке.';

  @override
  String get workspaceToolRunning => 'Выполняется';

  @override
  String workspaceToolExitCode(int code) {
    return 'exit $code';
  }

  @override
  String get workspaceToolAwaitingApproval => 'Ожидает одобрения';

  @override
  String get workspaceToolCompleted => 'Готово';

  @override
  String workspaceToolLines(int count) {
    return '$count строк';
  }

  @override
  String workspaceToolItems(int count) {
    return '$count элементов';
  }

  @override
  String workspaceToolFileMatches(int count) {
    return '$count совпадений';
  }

  @override
  String workspaceToolContentMatches(int count) {
    return '$count совпадений';
  }

  @override
  String get workspaceToolExpand => 'Развернуть';

  @override
  String get workspaceToolSectionCommand => 'Команда';

  @override
  String get workspaceToolSectionPath => 'Путь';

  @override
  String get workspaceToolSectionPattern => 'Шаблон';

  @override
  String get workspaceToolSectionOutput => 'Вывод';

  @override
  String get workspaceToolSectionDiff => 'Различия';

  @override
  String get workspaceToolSectionError => 'Ошибка';

  @override
  String get workspaceToolSavedOutput => 'Полный вывод сохранён';

  @override
  String get workspaceToolApprove => 'Разрешить';

  @override
  String get workspaceToolDeny => 'Отклонить';

  @override
  String get workspaceToolCopy => 'Копировать';

  @override
  String get workspaceEnvEngineLocalShell => 'Локальный shell';

  @override
  String get workspaceEnvInstallEnvironment => 'Установить окружение';

  @override
  String get workspaceEnvInstallDescription =>
      'Установите окружение Linux, чтобы запускать инструменты в песочнице.';

  @override
  String get workspaceEnvStatusLabel => 'Статус';

  @override
  String get workspaceEnvStatusInstalled => 'Установлено';

  @override
  String get workspaceEnvSizeLabel => 'Размер';

  @override
  String get workspaceEnvPathLabel => 'Путь';

  @override
  String get workspaceEnvInstalledAtLabel => 'Установлено';

  @override
  String get workspaceEnvArchLabel => 'Архитектура';

  @override
  String workspaceEnvArchVersion(String arch, String version) {
    return '$arch · $version';
  }

  @override
  String get workspaceEnvBrowseSection => 'Обзор';

  @override
  String get workspaceEnvBrowseFiles => 'Просмотр файловой системы';

  @override
  String get workspaceEnvBrowseFilesDetail =>
      'Просмотр полного дерева каталогов в песочнице';

  @override
  String get workspaceEnvDetectFastMirrors => 'Найти быстрые зеркала';

  @override
  String get workspaceEnvActionsSection => 'Действия';

  @override
  String get workspaceEnvInfoSection => 'Информация';

  @override
  String get workspaceEnvInfoBody =>
      'Среда — это корневая файловая система Linux, используемая песочницей. Рабочие области хранятся отдельно и не удаляются при сбросе. Файлы находятся в распакованном rootfs на этом устройстве.';

  @override
  String get workspaceEnvRepairDetail =>
      'Повторная проверка и исправление файлов';

  @override
  String get workspaceEnvUpdateCurrent => 'У вас последняя версия';

  @override
  String workspaceEnvUpdateAvailableShort(String version) {
    return 'Доступно обновление: $version';
  }

  @override
  String get workspaceEnvResetConfirmMessage =>
      'Это удалит всю среду Linux и все установленные в ней пакеты. Файлы рабочей области не затрагиваются.';

  @override
  String get workspaceEnvRestartDoneBanner =>
      'Сброс завершён. Перезапустите приложение, чтобы завершить установку.';

  @override
  String get workspaceEnvPathCopied => 'Путь скопирован';

  @override
  String get workspaceEnvUseMirrorSubtitle =>
      'Записать выбранное зеркало в песочницу';

  @override
  String get workspaceEnvRegionGlobal => 'Глобальный';

  @override
  String get workspaceEnvRegionChina => 'Китай';

  @override
  String get workspaceEnvRegionEurope => 'Европа';

  @override
  String get workspaceEnvRegionAsia => 'Азия';

  @override
  String get workspaceEnvMirrorTimeout => 'Тайм-аут';

  @override
  String get workspaceEnvSpeedTest => 'Проверить скорость';

  @override
  String get workspaceEnvApplySuccess => 'Зеркало применено';

  @override
  String get workspaceEnvApplyFailed => 'Не удалось применить зеркало';

  @override
  String get workspaceEnvRestoreSuccess => 'Официальный источник восстановлен';

  @override
  String get workspaceEnvMirrorsTested => 'Применены самые быстрые зеркала';

  @override
  String get workspaceEnvRelativeJustNow => 'Только что';

  @override
  String workspaceEnvRelativeMinutesAgo(int count) {
    return '$count мин назад';
  }

  @override
  String workspaceEnvRelativeHoursAgo(int count) {
    return '$count ч назад';
  }

  @override
  String workspaceEnvRelativeDaysAgo(int count) {
    return '$count дн назад';
  }

  @override
  String workspaceEnvDownloadLine(
    String downloaded,
    String total,
    String phase,
  ) {
    return '$downloaded / $total · $phase';
  }

  @override
  String get workspaceEnvNativeUnsandboxed =>
      'Команды выполняются на этом компьютере без песочницы и требуют одобрения, если у этого чата нет полного доступа.';

  @override
  String get workspaceEnvRootfsTitle => '/';

  @override
  String get workspaceEnvBrowserUnavailable =>
      'Файловая система песочницы недоступна.';

  @override
  String get workspaceEnvMirrorNameOfficial => 'Официальное';

  @override
  String get workspaceEnvMirrorNameOfficialCdn => 'Официальный CDN';

  @override
  String get workspaceEnvMirrorNameOfficialPypi => 'Официальный PyPI';

  @override
  String get workspaceEnvMirrorNameOfficialNpm => 'Официальный npm';

  @override
  String get workspaceEnvMirrorNameTuna => 'Tsinghua TUNA';

  @override
  String get workspaceEnvMirrorNameAlibaba => 'Alibaba';

  @override
  String get workspaceEnvMirrorNameUstc => 'USTC';

  @override
  String get workspaceEnvMirrorNameHuawei => 'Huawei';

  @override
  String get workspaceEnvMirrorNameTencent => 'Tencent';

  @override
  String get workspaceEnvMirrorNameNetease => 'NetEase';

  @override
  String get workspaceEnvMirrorNameLeaseweb => 'LEASEWEB UK';

  @override
  String get workspaceEnvMirrorNameRwth => 'RWTH Germany';

  @override
  String get workspaceEnvMirrorNameJaist => 'JAIST Japan';

  @override
  String get workspaceEnvMirrorNameKakao => 'Kakao Korea';

  @override
  String get workspaceEnvMirrorNameNpmmirror => 'npmmirror';

  @override
  String workspaceEnvSelectionNamed(String name, String region) {
    return '$name · $region';
  }

  @override
  String get workspaceFilesEmptyPickerHint =>
      'Нажмите «Новая папка», чтобы добавить подпапку';

  @override
  String get skillsDetailBodyEmpty => 'Содержимое навыка пока отсутствует';

  @override
  String skillsDetailBodyTooLarge(String size) {
    return 'Файл слишком большой для предпросмотра ($size).';
  }

  @override
  String get workspaceEnvSizeTimeout => 'Время ожидания истекло';

  @override
  String get workspaceEnvInfoCopied => 'Информация об окружении скопирована';

  @override
  String get workspacePreviewEmptyFile => 'Файл пуст';

  @override
  String get workspacePreviewEmptyHint => 'Нечего просматривать.';

  @override
  String get workspacePreviewRevealInExplorer => 'Показать в Проводнике';

  @override
  String get workspacePreviewRevealInFileManager => 'Показать в файлах';

  @override
  String workspaceBindingSetAssistantDefault(String assistant) {
    return 'Рабочая область назначена по умолчанию для «$assistant»';
  }

  @override
  String get storageSpaceCategoryWorkspaceFiles => 'Файлы рабочих областей';

  @override
  String get storageSpaceCategoryWorkspaceFilesHint =>
      'Файлы, хранящиеся в управляемых рабочих областях.';

  @override
  String get storageSpaceCategorySandboxEnvironment => 'Окружение песочницы';

  @override
  String get storageSpaceCategorySandboxEnvironmentHint =>
      'Установочный каталог песочницы и корневая файловая система.';

  @override
  String get storageSpaceCategorySkills => 'Навыки';

  @override
  String get storageSpaceCategorySkillsHint => 'Файлы установленных навыков.';

  @override
  String get storageSpaceCategorySessionFiles => 'Файлы чатов';

  @override
  String get storageSpaceCategorySessionFilesHint =>
      'Вложения и результаты по каждому чату.';

  @override
  String get storageSpaceManageSkills => 'Управление навыками';

  @override
  String get storageSessionFilesCleanOrphans =>
      'Очистить файлы чатов без чатов';

  @override
  String storageSessionFilesCleanOrphansHint(String size) {
    return 'Удаляет папки сеансов, у которых больше нет чата. Можно освободить: $size.';
  }

  @override
  String get workspaceDesktopFolderPath => 'Путь к папке';

  @override
  String get workspaceDesktopFolderMissing =>
      'Выберите существующую папку или введите её абсолютный путь.';

  @override
  String get workspaceDesktopManagedHint =>
      'Kelivo создаст и будет управлять папкой для этого проекта.';

  @override
  String get workspaceDesktopHostHint =>
      'Файлы и команды используют этот компьютер.';

  @override
  String get workspaceDesktopSearch => 'Поиск рабочих областей';

  @override
  String get workspaceDesktopNoResults => 'Нет подходящих рабочих областей';

  @override
  String get workspaceEnvDependencies => 'Пресеты окружения';

  @override
  String get workspaceEnvDependenciesDetail =>
      'Установите инструменты в общую песочницу. Они будут доступны всем рабочим областям.';

  @override
  String get workspaceEnvDependencyPython =>
      'Python, pip и виртуальные окружения';

  @override
  String get workspaceEnvDependencyNode => 'Node.js и npm';

  @override
  String get workspaceEnvDependencyGit =>
      'Клонирование репозиториев и управление версиями';

  @override
  String get workspaceEnvDependencySsh => 'SSH, SCP, SFTP и создание ключей';

  @override
  String get workspaceEnvDependencyNetwork => 'Сетевые инструменты';

  @override
  String get workspaceEnvDependencyArchive => 'Инструменты для архивов';

  @override
  String get workspaceEnvDependencyInstalled => 'Установлено';

  @override
  String get workspaceEnvDependencyUnknown => 'Не проверено';

  @override
  String get workspaceEnvDependencyChecking => 'Проверка инструментов…';

  @override
  String get workspaceEnvDependencyInstalling => 'Установка…';

  @override
  String get workspaceEnvDependencyCheckFailed =>
      'Не удалось проверить инструменты. Нажмите «Обновить», чтобы повторить.';

  @override
  String get workspaceEnvDependencyInstallFailed =>
      'Установка не завершена. Проверьте журнал или смените источник пакетов и повторите попытку.';

  @override
  String get workspaceEnvDependencyLog => 'Журнал установки';

  @override
  String get workspaceEnvDependencyRefresh => 'Обновить состояние инструментов';

  @override
  String get workspaceEnvDependencyReadyFirst =>
      'Сначала установите песочницу, чтобы добавить эти инструменты.';

  @override
  String get workspaceEnvDependencySources => 'Источники пакетов';

  @override
  String get workspaceEnvDependencySourcesDetail =>
      'Установка использует выбранный источник apt/apk. Источники pip и npm применяются к пакетам, которые вы установите позже.';

  @override
  String get workspaceEnvDownloadSource => 'Источник загрузки песочницы';

  @override
  String get workspaceEnvDownloadAutomatic => 'Автовыбор самого быстрого';

  @override
  String get workspaceEnvDownloadAutomaticDetail =>
      'Проверить скорость официального источника и встроенных зеркал перед загрузкой.';

  @override
  String get workspaceEnvDownloadCustom => 'Свой URL';

  @override
  String get workspaceEnvDownloadCustomHint =>
      'https://example.com/ubuntu-base/releases/24.04/release/';

  @override
  String get workspaceEnvDownloadCustomDetail =>
      'Укажите каталог релиза или полный URL архива. Архив должен соответствовать выбранной системе, версии и архитектуре устройства.';

  @override
  String get workspaceEnvDownloadInvalidUrl =>
      'Введите корректный URL HTTP или HTTPS.';

  @override
  String get workspaceEnvDownloadVerified =>
      'Загрузки проверяются по официальному SHA-256 выбранного образа. Источники пакетов настраиваются отдельно.';

  @override
  String get workspaceEnvDownloadStart => 'Скачать и установить';

  @override
  String get workspaceEnvDownloadSave => 'Сохранить источник';

  @override
  String get workspaceToolsTitle => 'Инструменты';

  @override
  String get workspaceToolsDescription =>
      'Выберите, какие инструменты могут использовать чаты в этой рабочей области. Изменения сохраняются автоматически.';

  @override
  String get workspaceToolHelpShell =>
      'Выполнять команды в среде рабочей области.';

  @override
  String get workspaceToolHelpRead =>
      'Читать файлы с номерами строк и постранично.';

  @override
  String get workspaceToolHelpViewImage =>
      'Позволить модели просмотреть изображение из рабочей области.';

  @override
  String get workspaceToolHelpWrite =>
      'Создавать файлы или перезаписывать их содержимое.';

  @override
  String get workspaceToolHelpEdit =>
      'Заменять указанный текст в существующем файле.';

  @override
  String get workspaceToolHelpList => 'Просматривать каталоги и их содержимое.';

  @override
  String get workspaceToolHelpGlob =>
      'Находить файлы по имени или шаблону пути.';

  @override
  String get workspaceToolHelpGrep => 'Искать текст внутри файлов.';

  @override
  String get workspaceEnvVariablesTitle => 'Переменные среды';

  @override
  String get workspaceEnvVariablesEntryDetail =>
      'Переменные для команд и управление приватностью вывода';

  @override
  String get workspaceEnvVariablesEmpty =>
      'Переменных пока нет. Добавьте API-ключи или другие настройки для ваших инструментов.';

  @override
  String get workspaceEnvVariablesScope =>
      'Общие для всех рабочих областей. Изменения применяются к новым командам Agent и новым сеансам терминала в приложении; чтобы применить их, откройте существующие сеансы заново. Внешние системные терминалы сохраняют собственное окружение.';

  @override
  String get workspaceEnvPrivacyMode => 'Режим приватности';

  @override
  String get workspaceEnvPrivacyDetail =>
      'Команды могут использовать реальные значения. Перед отправкой вывода инструментов рабочей области модели совпадающие значения длиной не менее 5 символов заменяются на [REDACTED]. Локальные журналы остаются без изменений. Более короткие значения не маскируются, чтобы не заменять распространённые флаги и числа.';

  @override
  String get workspaceEnvVariableAdd => 'Добавить переменную';

  @override
  String get workspaceEnvVariableEdit => 'Изменить переменную';

  @override
  String get workspaceEnvVariableName => 'Имя';

  @override
  String get workspaceEnvVariableValue => 'Значение';

  @override
  String get workspaceEnvVariableNote => 'Примечание (необязательно)';

  @override
  String get workspaceEnvVariableNameHint =>
      'Используйте буквы, цифры и подчёркивания; имя не должно начинаться с цифры. Имена чувствительны к регистру. Ссылайтесь на переменные в командах через \$NAME.';

  @override
  String get workspaceEnvVariableInvalidName =>
      'Введите корректное имя переменной.';

  @override
  String get workspaceEnvVariableInvalidValue =>
      'Введите непустое значение без символов NUL.';

  @override
  String get workspaceEnvVariableDuplicate =>
      'Переменная с таким именем уже существует.';

  @override
  String get workspaceEnvVariablesSaveFailed =>
      'Не удалось сохранить настройки среды. Попробуйте ещё раз.';

  @override
  String get incomingShareTitle => 'Общий контент';

  @override
  String get incomingShareReplaceDraft =>
      'В поле ввода есть неотправленное содержимое. Заменить его общим контентом в новом чате?';

  @override
  String get incomingShareFailed =>
      'Не удалось импортировать часть общего контента. Проверьте доступ к файлам и свободное место. За один раз можно поделиться не более чем 32 файлами.';

  @override
  String get incomingShareImporting => 'Импорт';

  @override
  String get incomingShareMoveTo => 'Переместить в…';

  @override
  String get incomingShareNewChat => 'Новый чат';

  @override
  String get incomingShareMoveHint =>
      'Переместить этот черновик и его вложения в другой чат. Ничего не будет отправлено автоматически.';

  @override
  String get incomingShareNoConversations => 'Нет подходящих чатов';

  @override
  String get chatInputBarRemoveAttachment => 'Удалить вложение';

  @override
  String get incomingShareMoveFailed =>
      'Не удалось переключить чат. Ваш черновик сохранён.';

  @override
  String attachmentRequiresWorkspace(String name) {
    return 'Чтобы использовать «$name», привяжите рабочую область и включите файловые инструменты или переместите этот черновик в чат с рабочей областью. Этот файл нельзя прочитать напрямую в обычном чате.';
  }

  @override
  String get storageSessionFilesUnlinked => 'Несвязанный чат';

  @override
  String get workspaceExternalMount => 'Подключить внешнюю папку';

  @override
  String get workspaceExternalMountSubtitle =>
      'Выбранные папки подключаются в /mounts/<name> и доступны всем рабочим областям. К ним могут обращаться инструменты ИИ, Shell и файловый браузер. Не более 10 папок.';

  @override
  String get workspaceExternalStorageTitle => 'Разрешить доступ к файлам';

  @override
  String get workspaceExternalStorageMessage =>
      'Чтобы читать и записывать внешние папки в рабочей области и Shell, разрешите Kelivo управлять файлами в настройках Android. На Android 11 и новее включите доступ ко всем файлам. Затем выберите папку на устройстве для монтирования.';

  @override
  String get workspaceExternalGrantAccess => 'Предоставить доступ';

  @override
  String get workspaceExternalLocalOnly =>
      'Android может монтировать только папки на устройстве. Этот провайдер документов не предоставляет локальную папку для Shell.';

  @override
  String get workspaceExternalUnavailable =>
      'Внешняя папка недоступна. Проверьте подключение к хранилищу и разрешения, затем снова выберите папку, чтобы восстановить доступ.';

  @override
  String get workspaceExternalReconnect => 'Выбрать папку снова';

  @override
  String get workspaceMountAdd => 'Добавить папку';

  @override
  String get workspaceMountEdit => 'Изменить монтирование';

  @override
  String get workspaceMountEmpty => 'Нет смонтированных папок';

  @override
  String get workspaceMountReadOnly => 'Только чтение';

  @override
  String get workspaceMountReadWrite => 'Чтение и запись';

  @override
  String get workspaceMountAllowWrite => 'Разрешить запись';

  @override
  String get workspaceMountPermissionsHint =>
      'Файловые инструменты ИИ и файловый браузер соблюдают эту настройку. Проверки Shell охватывают распространённые файловые команды; произвольные скрипты могут их обойти. Сохранение изменений монтирования останавливает выполняющиеся команды и сеансы терминала.';

  @override
  String get workspaceMountBrowse => 'Просмотр файлов';

  @override
  String get workspaceMountUnmount => 'Размонтировать';

  @override
  String get workspaceMountUnmountMessage =>
      'Удалить это монтирование? Исходная папка и её файлы сохранятся.';

  @override
  String get workspaceMountInactive => 'Недоступно — выберите папку снова';

  @override
  String get workspaceMountInvalidName =>
      'Используйте имя до 64 символов без косых черт, двоеточий и управляющих символов. Не используйте . или ..';

  @override
  String get workspaceMountDuplicate =>
      'Монтирование с таким именем уже существует.';

  @override
  String get workspaceMountLimit =>
      'Можно смонтировать до 10 папок. Размонтируйте одну, прежде чем добавлять другую.';

  @override
  String get workspaceMountOverlap =>
      'Эта папка пересекается с существующим монтированием. Выберите другую папку, чтобы разрешения оставались однозначными.';

  @override
  String get workspaceMountTargetOccupied =>
      'Цель монтирования в /mounts уже содержит локальные файлы. Выберите другое имя монтирования или сначала переместите эти файлы. Никакие файлы не были удалены.';

  @override
  String get workspaceEnvSystemImage => 'Системный образ';

  @override
  String get workspaceEnvDistribution => 'Дистрибутив';

  @override
  String get workspaceEnvSystemVersion => 'Версия';

  @override
  String get workspaceEnvLocalImage => 'Локальный образ';

  @override
  String get workspaceEnvChooseImage => 'Выбрать архив rootfs';

  @override
  String get workspaceEnvLocalImageHint =>
      'Импортируйте архив корневой файловой системы (.tar.gz, .tar.xz или .tar), а не ISO или образ диска. Он должен соответствовать архитектуре процессора этого устройства и содержать /bin/sh. Система и версия определяются после распаковки.';

  @override
  String get workspaceEnvImportImage => 'Импортировать образ';

  @override
  String get workspaceEnvInvalidImage =>
      'Выберите корректный архив rootfs для этого устройства. Он должен содержать исполняемый /bin/sh с соответствующей архитектурой процессора.';

  @override
  String get workspaceEnvReplaceSystem => 'Заменить систему';

  @override
  String get workspaceEnvReplaceSystemHint =>
      'Это заменит установленные пакеты и файлы внутри текущего окружения и остановит его команды и сеансы терминала. Рабочие области, файлы чатов и внешние папки сохранятся. Если подготовка нового образа не удастся, текущее окружение сохранится.';

  @override
  String get workspaceEnvProotOptions => 'Параметры PRoot';

  @override
  String get workspaceEnvShellPath => 'Путь к Shell';

  @override
  String get workspaceEnvShellAutomatic => 'Автоматически';

  @override
  String get workspaceEnvShellHint =>
      'Оставьте пустым, чтобы использовать /bin/bash, если он доступен, иначе /bin/sh. Пользовательский Shell должен указываться абсолютным путём внутри окружения.';

  @override
  String get workspaceEnvProotArguments => 'Дополнительные аргументы PRoot';

  @override
  String get workspaceEnvProotArgumentsHint =>
      'Один аргумент на строку, без кавычек Shell. Например, укажите -k и 5.10.0 на отдельных строках или используйте --kernel-release=5.10.0. Изменения применяются к новым командам и сеансам терминала.';

  @override
  String get workspaceEnvProotInvalid =>
      'Укажите корректный абсолютный путь к Shell и по одному аргументу PRoot на строку.';

  @override
  String get workspaceFileMissing => 'Файл больше не существует';

  @override
  String get workspaceFilePreviewUnavailable => 'Предпросмотр недоступен';

  @override
  String get workspaceToolRelatedFiles => 'Связанные файлы';

  @override
  String get workspaceToolFilesTruncated => 'Показаны только некоторые файлы.';

  @override
  String get displaySettingsPageShowProducedFilesTitle =>
      'Показывать файлы под ответами';

  @override
  String get displaySettingsPageShowProducedFilesSubtitle =>
      'Показывать файлы, созданные или изменённые инструментами, под ответами.';

  @override
  String get defaultModelPagePerChatModelTitle => 'Модель для каждого чата';

  @override
  String get defaultModelPagePerChatModelSubtitle =>
      'Вкл.: выбор модели в чате применяется только к этому чату. Выкл.: он становится моделью текущего ассистента, и все чаты с этим ассистентом следуют ей.';

  @override
  String get googleFontsTitle => 'Google Fonts';

  @override
  String get googleFontsRefresh => 'Обновить список шрифтов';

  @override
  String get googleFontsSearchHint => 'Поиск шрифтов или языков';

  @override
  String get googleFontsHint =>
      'Скачайте обычное начертание шрифта, чтобы просмотреть и применить его. Установленные шрифты работают офлайн. Каталог: Expo Google Fonts; загрузка: Google Fonts.';

  @override
  String get googleFontsNoResults => 'Подходящих шрифтов нет';

  @override
  String get googleFontsFailed =>
      'Не удалось загрузить, скачать или применить шрифт. Проверьте подключение и повторите попытку.';

  @override
  String get googleFontsDownloading => 'Скачивание шрифта…';

  @override
  String get googleFontsPreview => 'The quick brown fox 0123456789 · 字体预览';

  @override
  String get googleFontsLicense => 'Лицензия шрифта';

  @override
  String get assistantEditLocationPermissionSettingsMessage =>
      'Доступ к геолокации заблокирован. Разрешите доступ к геолокации в системных настройках, затем снова включите этот инструмент.';

  @override
  String get healthDataSettingsCategoryReproductive =>
      'Репродуктивное здоровье';

  @override
  String get healthDataSettingsTypeMenstrualFlowTitle =>
      'Менструальные выделения';

  @override
  String get healthDataSettingsTypeMenstrualFlowSubtitle =>
      'Записанные менструальные выделения и начала циклов за последние 90 дней';

  @override
  String get assistantEditGradientBackgroundTitle => 'Градиентный фон';

  @override
  String get assistantEditGradientStaticTitle => 'Статический режим';

  @override
  String get assistantEditGradientStaticDescription =>
      'Экономит заряд при долгих чатах и потоковой генерации.';

  @override
  String get assistantEditGradientHorizontal => 'Горизонтальное положение';

  @override
  String get assistantEditGradientVertical => 'Вертикальное положение';

  @override
  String get assistantEditGradientPreview => 'Предпросмотр';

  @override
  String get assistantEditGradientNextFrame => 'Другой кадр';

  @override
  String get backgroundSettingsTitle => 'Фоновые задачи';

  @override
  String get backgroundTaskTitle => 'Задача Kelivo';

  @override
  String get backgroundCompleted => 'Генерация завершена';

  @override
  String get backgroundFailed =>
      'Генерация не удалась. Откройте чат, чтобы узнать подробности.';

  @override
  String get backgroundCancelled => 'Генерация отменена';

  @override
  String get backgroundInterrupted =>
      'Фоновая генерация была прервана. Откройте чат, чтобы продолжить.';

  @override
  String get backgroundRequesting => 'Подключение';

  @override
  String get backgroundGenerating => 'Генерация ответа';

  @override
  String get backgroundThinking => 'Размышление';

  @override
  String get backgroundToolRunning => 'Выполнение инструмента';

  @override
  String get backgroundRetrying => 'Ожидание повторной попытки';

  @override
  String get backgroundWorking => 'Выполняется';

  @override
  String get backgroundTasks => 'Задачи';

  @override
  String get backgroundStopTasks => 'Остановить задачи';

  @override
  String get backgroundOpenChat => 'Открыть чат';

  @override
  String get backgroundAndroidEnabled => 'Фоновая генерация';

  @override
  String get backgroundAndroidEnabledDetail =>
      'Продолжать текущие задачи при блокировке, работе в фоне или удалении из недавних приложений. Пока задачи выполняются, требуется системное уведомление.';

  @override
  String get backgroundIosEnabled => 'Расширенное фоновое выполнение';

  @override
  String get backgroundIosEnabledDetail =>
      'Запрашивать время для завершения текущих задач. Для дополнительной поддержки в фоне отдельно включите геолокацию или беззвучное аудио.';

  @override
  String get backgroundNotifications => 'Уведомления о задачах';

  @override
  String get backgroundNotificationsDetail =>
      'Уведомлять о завершении или сбое задачи вне открытого чата. Не управляет обязательным постоянным уведомлением Android.';

  @override
  String get backgroundPrivacy => 'Конфиденциальность статуса задач';

  @override
  String get backgroundPrivacyDetail =>
      'Скрывать названия чатов и сведения об инструментах в уведомлениях и текущем статусе. Показываются только общий статус, число задач и затраченное время.';

  @override
  String get backgroundLiveActivities => 'Live Activities';

  @override
  String get backgroundLiveActivitiesDetail =>
      'Показывать текущие задачи на экране блокировки и в Dynamic Island. Доступность и видимость зависят от системы.';

  @override
  String get backgroundOverlay => 'Плавающий статус задач';

  @override
  String get backgroundOverlayDetail =>
      'Показывать перетаскиваемую капсулу задач поверх других приложений. Нажмите, чтобы открыть чат; закрытие только скрывает капсулу.';

  @override
  String get backgroundLiveUpdates => 'Live Updates';

  @override
  String get backgroundLiveUpdatesDetail =>
      'Использовать Android 16 Live Updates на поддерживаемых устройствах. Повышенное уведомление имеет приоритет над плавающей капсулой.';

  @override
  String get backgroundLocation => 'Выполнение с поддержкой геолокации';

  @override
  String get backgroundLocationDetail =>
      'Использовать приблизительные обновления геолокации во время фоновых задач. Координаты не сохраняются и не отправляются в сервисы ИИ. Требуется расширенное фоновое выполнение и разрешение на геолокацию.';

  @override
  String get backgroundSilentAudio => 'Поддержка беззвучным аудио';

  @override
  String get backgroundSilentAudioDetail =>
      'Воспроизводить беззвучное аудио во время фоновых задач. Уступает запись и воспроизведению речи. Требуется расширенное фоновое выполнение; разрешение на микрофон не нужно.';

  @override
  String get backgroundSpeech => 'Фоновое чтение вслух';

  @override
  String get backgroundSpeechDetail =>
      'Продолжать системное и сетевое чтение вслух при блокировке экрана или в фоне. Если выключено, при переходе в фон чтение приостанавливается.';

  @override
  String get backgroundFinishVisibility =>
      'Длительность показа статуса завершения';

  @override
  String get backgroundFinishImmediately => 'Скрывать сразу';

  @override
  String get backgroundFinishOneMinute => '1 минута';

  @override
  String get backgroundFinishFiveMinutes => '5 минут';

  @override
  String get backgroundFinishUntilForeground => 'До возврата в приложение';

  @override
  String get backgroundFinishVisibilityDetail =>
      'Применяется к капсуле Android и карточке завершения на экране блокировки iOS. При возврате в приложение статус завершения очищается; максимум — 15 минут. При отмене скрывается сразу.';

  @override
  String get backgroundOverlayIcon => 'Значок плавающего окна';

  @override
  String get backgroundIconDefault => 'Значок Kelivo';

  @override
  String get backgroundIconImage => 'Выбрать изображение';

  @override
  String get backgroundIconEmoji => 'Выбрать эмодзи';

  @override
  String get backgroundPermissionsTitle => 'Разрешения и системные настройки';

  @override
  String get backgroundNotificationsPermission => 'Разрешение на уведомления';

  @override
  String get backgroundBatteryOptimization => 'Оптимизация батареи';

  @override
  String get backgroundBatteryOptimizationDetail =>
      'Разрешите неограниченное использование батареи для более надёжной фоновой работы.';

  @override
  String get backgroundAutostart => 'Автозапуск и фоновая работа';

  @override
  String get backgroundAutostartDetail =>
      'Проверьте ограничения автозапуска и фоновой работы вашего устройства вручную. Android не предоставляет надёжного способа запросить состояние этих настроек производителя.';

  @override
  String get backgroundLocationPermission => 'Разрешение на геолокацию';

  @override
  String get backgroundLocationAlways => 'Разрешить геолокацию в фоне';

  @override
  String get backgroundLocationAlwaysDetail =>
      'Можно предоставить доступ «Всегда» для фоновой геолокации. Разрешение запрашивается только при выборе этого действия.';

  @override
  String get backgroundSystemSettings => 'Системные настройки приложения';

  @override
  String get backgroundPermissionGranted => 'Разрешено';

  @override
  String get backgroundPermissionDenied => 'Не разрешено';

  @override
  String get backgroundPermissionLimited => 'При использовании приложения';

  @override
  String get backgroundPermissionUnknown => 'Проверьте вручную';

  @override
  String get backgroundPermissionNotDetermined => 'Не запрошено';

  @override
  String get backgroundRuntimeTitle => 'Текущее состояние';

  @override
  String get backgroundRuntimeActive => 'Работает';

  @override
  String get backgroundRuntimeIdle => 'Неактивно';

  @override
  String get backgroundLocationActive => 'Фоновая геолокация';

  @override
  String get backgroundAudioActive => 'Беззвучное аудио';

  @override
  String get backgroundActivityActive => 'Live Activity';

  @override
  String get backgroundOverlayActive => 'Плавающее окно';

  @override
  String get backgroundLastError => 'Последнее прерывание или ошибка';

  @override
  String get backgroundNoError => 'Нет записей';

  @override
  String get backgroundUnsupported =>
      'Недоступно на этом устройстве или запрещено в системных настройках';

  @override
  String get backgroundIosLimit =>
      'Фоновое выполнение контролируется iOS. Сами Live Activities не поддерживают работу приложения. Принудительное закрытие может остановить генерацию и отложить очистку живого статуса до повторного открытия приложения.';

  @override
  String get backgroundAndroidLimit =>
      'Если задачи прерываются, проверьте настройки уведомлений, батареи и фоновой работы производителя. Принудительная остановка и завершение системного процесса всё равно могут прервать генерацию.';

  @override
  String get backgroundStale =>
      'Статус не обновлён. Откройте приложение, чтобы проверить.';

  @override
  String get backgroundIconError =>
      'Не удалось импортировать это изображение. Выберите другое изображение.';

  @override
  String get backgroundNotificationChannels => 'Каналы уведомлений';

  @override
  String get backgroundCompletionChannel =>
      'Канал уведомлений о завершении задачи';

  @override
  String get backgroundOngoingChannel =>
      'Канал уведомлений о выполняющейся задаче';

  @override
  String get backgroundOverlayAppearance => 'Внешний вид плавающего окна';

  @override
  String get backgroundOverlayAppearanceDetail =>
      'Размер, изображение, кольцо прогресса и отображаемое содержимое';

  @override
  String get backgroundOverlayPreviewHint =>
      'Перетащите, чтобы переместить · Нажмите, чтобы открыть чат · Удерживайте, чтобы скрыть';

  @override
  String get backgroundOverlayCard => 'Карточка';

  @override
  String get backgroundOverlayCircle => 'Круглый значок';

  @override
  String get backgroundOverlaySize => 'Размер и форма';

  @override
  String get backgroundOverlayWidth => 'Ширина';

  @override
  String get backgroundOverlayHeight => 'Высота';

  @override
  String get backgroundOverlayCornerRadius => 'Радиус скругления';

  @override
  String get backgroundOverlayIconSize => 'Размер значка';

  @override
  String get backgroundOverlayProgressSize => 'Диаметр кольца прогресса';

  @override
  String get backgroundOverlayProgressStroke => 'Толщина кольца прогресса';

  @override
  String get backgroundOverlayContent => 'Отображаемое содержимое';

  @override
  String get backgroundOverlayShowProgress => 'Показывать кольцо прогресса';

  @override
  String get backgroundOverlayShowTitle => 'Показывать заголовок';

  @override
  String get backgroundOverlayShowSubtitle => 'Показывать подзаголовок';

  @override
  String get backgroundOverlayShowTime => 'Показывать затраченное время';

  @override
  String get backgroundOverlayShowClose => 'Показывать кнопку закрытия';

  @override
  String get backgroundOverlayShowBackground => 'Показывать фон';

  @override
  String get backgroundOverlayShowBorder => 'Показывать рамку';

  @override
  String get backgroundOverlayReset => 'Восстановить оформление по умолчанию';

  @override
  String get mcpStdioEnvironmentRequired =>
      'Установите окружение рабочей области, чтобы использовать STDIO на мобильном устройстве.';

  @override
  String get mcpArgumentsHint =>
      'Разделяйте аргументы пробелами; значения с пробелами заключайте в кавычки. Для пустого аргумента используйте \'\'.';

  @override
  String get mcpArgumentsInvalid =>
      'Проверьте, не осталась ли незакрытая кавычка или незавершённая escape-последовательность в аргументах.';

  @override
  String get mcpImportEnvironment => 'Импортировать из окружения';

  @override
  String get mcpEnvironmentEmpty =>
      'Нет переменных окружения. Добавьте их в настройках окружения.';

  @override
  String get mcpEnvironmentHint =>
      'Наследует переменные окружения. Импортируйте переменную, чтобы задать своё значение для этого сервера.';

  @override
  String get mcpImportJson => 'Импорт JSON';

  @override
  String get mcpImportJsonHint =>
      'Вставьте конфигурацию MCP из Claude Desktop или Cursor. Просмотрите и добавьте серверы, не заменяя существующие.';

  @override
  String get mcpImportPaste => 'Вставить из буфера обмена';

  @override
  String get mcpImportPreview => 'Предпросмотр';

  @override
  String get mcpImportConfirm => 'Импортировать';

  @override
  String get startupRecoverySnapshotTitle => 'Восстановить из локальной копии';

  @override
  String get startupRecoverySnapshotBody =>
      'Выберите снимок на этом устройстве, чтобы восстановить чаты и настройки, даже если база данных не открывается. Не удаляйте Kelivo: при удалении эти снимки тоже будут удалены.';

  @override
  String get startupRecoverySnapshotEmpty =>
      'На этом устройстве не найдено снимков базы данных. Экспортируйте данные, прежде чем пробовать другие способы восстановления.';

  @override
  String get startupRecoverySnapshotButton =>
      'Выбрать копию для восстановления';

  @override
  String startupRecoverySnapshotConfirm(String when) {
    return 'Восстановить чаты и настройки из снимка от $when? Изменения, сделанные после этого снимка, не будут включены. Существующие файлы вложений и снимок сохранятся. Kelivo перезапустится для завершения восстановления.';
  }

  @override
  String startupRecoverySnapshotFailed(String reason) {
    return 'Не удалось подготовить восстановление из снимка: $reason';
  }

  @override
  String get startupRecoverySnapshotReady =>
      'Снимок готов. Перезапустите Kelivo, чтобы завершить восстановление.';

  @override
  String get scheduledTasksTitle => 'Запланированные задачи';

  @override
  String get scheduledTasksDescription =>
      'Автоматически выполняйте задачи в выбранное время: начинайте новый чат, продолжайте диалог или повторяйте запрос.';

  @override
  String get scheduledTasksEmpty => 'Ваш день по расписанию';

  @override
  String get scheduledTasksEmptyDetail =>
      'Добавьте задачу для утренней сводки, ежедневного обзора или чего угодно, что нужно выполнять регулярно.';

  @override
  String get scheduledTasksAdd => 'Добавить задачу';

  @override
  String get scheduledTasksEdit => 'Изменить задачу';

  @override
  String get scheduledTasksName => 'Название';

  @override
  String get scheduledTasksNameHint => 'Утренняя сводка';

  @override
  String get scheduledTasksPrompt => 'Запрос';

  @override
  String get scheduledTasksPromptHint =>
      'Что вы хотите, чтобы сделал ваш ассистент?';

  @override
  String get scheduledTasksAssistant => 'Ассистент';

  @override
  String get scheduledTasksChooseAssistant => 'Выберите ассистента';

  @override
  String get scheduledTasksAssistantMissing => 'Ассистент недоступен';

  @override
  String get scheduledTasksTime => 'Время';

  @override
  String get scheduledTasksTimeHint => '24-часовой формат, например 08:00';

  @override
  String get scheduledTasksRepeat => 'Повтор';

  @override
  String get scheduledTasksEveryDay => 'Каждый день';

  @override
  String get scheduledTasksWeekdays => 'Будни';

  @override
  String get scheduledTasksEnabled => 'Включено';

  @override
  String get scheduledTasksPermission => 'Будильники и напоминания';

  @override
  String get scheduledTasksPermissionDetail =>
      'Разрешите точные будильники, чтобы задачи запускались в выбранное время. Включённые задачи будут ждать предоставления разрешения.';

  @override
  String get scheduledTasksPermissionAction => 'Разрешить';

  @override
  String get scheduledTasksReliability =>
      'Снимите ограничения батареи для Kelivo, чтобы задачи выполнялись надёжнее. Принудительная остановка приложения отменяет будильники до повторного открытия. Пропущенные запуски не выполняются; задачи следуют часовому поясу устройства.';

  @override
  String get scheduledTasksExecutionDetail =>
      'Результаты сохраняются в чатах. Уведомление о завершении показывает превью ответа и открывает чат при нажатии. Запуск останавливается через 10 минут или когда требуется ввод пользователя или подтверждение инструмента.';

  @override
  String get scheduledTasksRunNow => 'Запустить сейчас';

  @override
  String get scheduledTasksHistory => 'История запусков';

  @override
  String get scheduledTasksNoRuns => 'Запусков пока нет';

  @override
  String get scheduledTasksRunning => 'Выполняется';

  @override
  String get scheduledTasksCompleted => 'Завершено';

  @override
  String get scheduledTasksFailed => 'Ошибка';

  @override
  String get scheduledTasksInterrupted => 'Прервано';

  @override
  String get scheduledTasksPaused => 'Приостановлено';

  @override
  String get scheduledTasksWaitingPermission => 'Ожидание разрешения';

  @override
  String scheduledTasksNextRun(String time) {
    return 'Далее: $time';
  }

  @override
  String get scheduledTasksDelete => 'Удалить задачу';

  @override
  String get scheduledTasksDeleteDetail =>
      'Удалить это расписание и историю запусков? Уже созданные чаты будут сохранены.';

  @override
  String get scheduledTasksSave => 'Сохранить';

  @override
  String get scheduledTasksCancel => 'Отмена';

  @override
  String get scheduledTasksInvalid =>
      'Введите название, запрос и ассистента, а для пользовательского расписания выберите хотя бы один день.';

  @override
  String get scheduledTasksLoading => 'Загрузка…';

  @override
  String get scheduledTasksOpenChat => 'Открыть чат';

  @override
  String get scheduledTasksNeedsInput =>
      'Остановлено, так как требовался ввод пользователя или подтверждение инструмента. Откройте чат, чтобы продолжить.';

  @override
  String get scheduledTasksTimeout => 'Достигнут лимит времени выполнения.';

  @override
  String get scheduledTasksProcessTerminated =>
      'Android остановил предыдущий запуск.';

  @override
  String get scheduledTasksOnce => 'Однократно';

  @override
  String get scheduledTasksCustom => 'Пользовательское';

  @override
  String get scheduledTasksExecution => 'Задача';

  @override
  String get scheduledTasksMode => 'Действие';

  @override
  String get scheduledTasksNewChat => 'Новый чат';

  @override
  String get scheduledTasksFollowUp => 'Продолжить';

  @override
  String get scheduledTasksRegenerate => 'Запустить снова';

  @override
  String get scheduledTasksChat => 'Чат';

  @override
  String get scheduledTasksChooseChat => 'Выберите чат';

  @override
  String get scheduledTasksMessage => 'Вопрос для повторного запуска';

  @override
  String get scheduledTasksChooseMessage => 'Выберите вопрос';

  @override
  String get scheduledTasksAttachmentMessage => 'Сообщение с вложениями';

  @override
  String get scheduledTasksModel => 'Модель';

  @override
  String get scheduledTasksChooseModel => 'Выберите модель';

  @override
  String get scheduledTasksModelDefault =>
      'Использовать модель чата или ассистента';

  @override
  String get scheduledTasksSchedule => 'Расписание';

  @override
  String get scheduledTasksActiveWindow => 'Активные даты';

  @override
  String get scheduledTasksStartDate => 'Дата начала';

  @override
  String get scheduledTasksEndDate => 'Дата окончания';

  @override
  String get scheduledTasksActiveWindowDetail =>
      'Запускается только в этих датах, включая дату окончания. Если дата не задана, ограничения нет.';

  @override
  String get scheduledTasksDate => 'Дата';

  @override
  String get scheduledTasksDateUnrestricted => 'Без ограничений';

  @override
  String get scheduledTasksClear => 'Очистить';

  @override
  String get scheduledTasksSearch => 'Поиск';

  @override
  String get scheduledTasksNoTargets =>
      'Нет подходящих элементов для этого ассистента';

  @override
  String get scheduledTasksFutureDate =>
      'Выберите будущие дату и время выполнения.';

  @override
  String get scheduledTasksDateRangeInvalid =>
      'Дата окончания должна быть не раньше даты начала.';

  @override
  String get scheduledTasksRegenerateDetail =>
      'Создаёт новый ответ на выбранный вопрос с использованием исходного контекста. Существующие ответы и последующие сообщения сохраняются.';

  @override
  String get scheduledTasksSaving => 'Сохранение…';

  @override
  String get scheduledTasksFinished => 'Расписание завершено';

  @override
  String get scheduledTasksModelMissing =>
      'Выбранная модель недоступна. Отредактируйте задачу и выберите другую модель.';

  @override
  String get scheduledTasksChatMissing =>
      'Чат недоступен или принадлежит другому ассистенту.';

  @override
  String get scheduledTasksMessageMissing =>
      'Выбранный вопрос больше недоступен.';

  @override
  String get scheduledTasksChatBusy =>
      'В этом чате создаётся ответ. Запланированный запуск пропущен.';

  @override
  String get scheduledTasksDesktopEmpty => 'Нет запланированных задач';

  @override
  String get scheduledTasksDesktopReliability =>
      'Задачи выполняются только пока Kelivo запущен, в том числе в свёрнутом виде или в системном трее. Пропущенные моменты времени не выполняются после выхода или сна компьютера. Kelivo не запускается автоматически.';

  @override
  String get scheduledTasksDesktopExecutionDetail =>
      'Результаты сохраняются в чатах. Открывайте их из истории запусков задачи. Запуск останавливается через 10 минут или когда требуется ввод пользователя или подтверждение инструмента.';

  @override
  String get worldBookStickyLabel => 'Закрепление (сообщения)';

  @override
  String get worldBookStickyHint =>
      'Запись остаётся активной в течение N сообщений после срабатывания. Повторные совпадения не продлевают её. 0 отключает этот эффект.';

  @override
  String get worldBookCooldownLabel => 'Перезарядка (сообщения)';

  @override
  String get worldBookCooldownHint =>
      'Запрещает повторное срабатывание в течение N сообщений после срабатывания или окончания закрепления. 0 отключает этот эффект.';

  @override
  String get worldBookDelayLabel => 'Задержка (сообщения)';

  @override
  String get worldBookDelayHint =>
      'Разрешает срабатывание только после того, как в чате будет не менее N сообщений. Считаются отдельные сообщения, а не обмены. 0 отключает этот эффект.';

  @override
  String get worldBookDragToReorder => 'Перетащите для изменения порядка';

  @override
  String worldBookEnabledCount(int enabled, int total) {
    return 'Включено $enabled/$total';
  }

  @override
  String get assistantConversationSystemPromptTitle =>
      'Системный промпт для каждого чата';

  @override
  String get assistantConversationSystemPromptHint =>
      'Разрешить каждому чату использовать собственный системный промпт.';

  @override
  String get assistantConversationInjectionTitle =>
      'Инъекции инструкций для каждого чата';

  @override
  String get assistantConversationInjectionHint =>
      'Выбирайте инъекции инструкций и мировые книги для каждого чата. По умолчанию ничего не выбрано.';

  @override
  String get conversationSystemPromptTitle => 'Системный промпт чата';

  @override
  String get conversationSystemPromptHint =>
      'Действует только для этого чата. Оставьте пустым, чтобы использовать системный промпт ассистента.';

  @override
  String get conversationSystemPromptClear => 'Использовать промпт ассистента';

  @override
  String get conversationSystemPromptPlaceholder =>
      'Напишите системный промпт для этого чата…';

  @override
  String get conversationPromptScope => 'Этот чат';

  @override
  String get oauthAccountsTab => 'Аккаунты';

  @override
  String get oauthLogin => 'Войти';

  @override
  String oauthLoginTo(String provider) {
    return 'Войти в $provider';
  }

  @override
  String get oauthConnected => 'Подключено';

  @override
  String get oauthNotConnected => 'Не подключено';

  @override
  String oauthWaiting(String provider) {
    return 'Ожидание авторизации $provider';
  }

  @override
  String get oauthCancel => 'Отменить авторизацию';

  @override
  String get oauthOpenBrowser => 'Открыть страницу авторизации';

  @override
  String get oauthCopyCode => 'Копировать код';

  @override
  String get oauthCodeHint => 'Введите этот код на странице авторизации';

  @override
  String get oauthDeviceHint =>
      'Сначала включите вход по коду устройства в настройках безопасности ChatGPT или разрешениях рабочей области.';

  @override
  String get oauthDeviceLogin => 'Использовать код устройства';

  @override
  String get oauthDetails => 'Просмотреть данные аккаунта';

  @override
  String get oauthConnectAnother => 'Подключить другой аккаунт';

  @override
  String get oauthRelogin => 'Войти снова';

  @override
  String get oauthNeedsLogin => 'Требуется вход';

  @override
  String oauthExpired(String provider) {
    return 'Срок входа в $provider истёк';
  }

  @override
  String get oauthLoginRestored =>
      'Вход выполнен. Используйте кнопку повтора на сообщении, чтобы отправить снова.';

  @override
  String get oauthLogout => 'Выйти';

  @override
  String get oauthLogoutDescription =>
      'Удалить сохранённые учётные данные этого аккаунта с этого устройства';

  @override
  String get oauthRefreshing => 'Обновление авторизации…';

  @override
  String get oauthRefreshUsage => 'Обновить использование';

  @override
  String get oauthUsageDetails => 'Детали использования';

  @override
  String get oauthUsageUnavailable => 'Использование сейчас недоступно';

  @override
  String oauthLastUpdated(String time) {
    return 'Обновлено $time';
  }

  @override
  String get oauthSyncModels => 'Синхронизировать';

  @override
  String get oauthSyncing => 'Синхронизация моделей…';

  @override
  String get oauthModelsHint =>
      'Доступные модели синхронизируются из вашего аккаунта. Выберите модели, которые будут отображаться в списке выбора моделей. Ваш выбор сохраняется при синхронизации и повторном входе.';

  @override
  String get oauthNoModels => 'Синхронизируйте модели, чтобы начать чат';

  @override
  String get oauthConnection => 'Подключение';

  @override
  String get oauthConnectionInfo => 'Детали подключения';

  @override
  String get oauthEndpoint => 'Конечная точка';

  @override
  String get oauthScope => 'Область авторизации';

  @override
  String get oauthAccountId => 'ID аккаунта';

  @override
  String get oauthTokenExpiry => 'Срок действия токена';

  @override
  String get oauthName => 'Название провайдера';

  @override
  String get oauthEnabledHint =>
      'Показывать эти модели в списке выбора моделей';

  @override
  String get oauthNetwork => 'Сетевой прокси';

  @override
  String get oauthFollowGlobal => 'Следовать глобальным настройкам';

  @override
  String get oauthCustomRequest => 'Пользовательский запрос';

  @override
  String get oauthWeekly => 'Недельное окно';

  @override
  String get oauthMonthly => 'Месячное окно';

  @override
  String get oauthTotal => 'Общая квота';

  @override
  String oauthHours(String count) {
    return 'Окно $count ч';
  }

  @override
  String oauthMinutes(String count) {
    return 'Окно $count мин';
  }

  @override
  String oauthDays(String count) {
    return 'Окно $count дн.';
  }

  @override
  String get oauthWindow => 'Окно использования';

  @override
  String oauthResetsAt(String time) {
    return 'Сброс $time';
  }

  @override
  String oauthUsedValue(String value) {
    return 'Использовано $value';
  }

  @override
  String get oauthNetworkError =>
      'Не удалось подключиться. Проверьте сеть и повторите попытку.';

  @override
  String get oauthDnsError =>
      'Не удалось выполнить DNS-запрос. Проверьте сеть или настройки DNS прокси.';

  @override
  String get oauthTlsError =>
      'Не удалось установить TLS-соединение. Проверьте сертификаты, используемые вашей сетью или прокси.';

  @override
  String get oauthProxyError =>
      'Не удалось подключиться через прокси. Проверьте адрес прокси и настройки аутентификации.';

  @override
  String get oauthConnectionError =>
      'Соединение не удалось или было прервано. Проверьте настройки сети или прокси.';

  @override
  String get oauthConnectionTimeout =>
      'Время подключения к серверу истекло. Проверьте настройки сети или прокси.';

  @override
  String get oauthSendTimeout =>
      'Время отправки запроса истекло. Проверьте сеть и повторите попытку.';

  @override
  String get oauthReceiveTimeout =>
      'Время ожидания ответа сервера истекло. Повторите попытку.';

  @override
  String get oauthRequestTimeout =>
      'Время запроса истекло. Проверьте настройки сети или прокси и повторите попытку.';

  @override
  String oauthFailureStage(String stage) {
    return 'Сбой на этапе: $stage';
  }

  @override
  String get oauthStageRequestDeviceCode => 'Запрос кода устройства';

  @override
  String get oauthStageWaitDeviceAuthorization =>
      'Ожидание авторизации устройства';

  @override
  String get oauthStagePrepareBrowser => 'Подготовка входа через браузер';

  @override
  String get oauthStageBrowserAuthorization =>
      'Авторизация в браузере и обратный вызов';

  @override
  String get oauthStageExchangeToken => 'Обмен кода авторизации';

  @override
  String get oauthStageRefreshToken => 'Обновление токена входа';

  @override
  String get oauthInvalidResponse =>
      'Авторизация не завершена. Повторите попытку.';

  @override
  String get oauthTimeout => 'Время авторизации истекло. Повторите попытку.';

  @override
  String get oauthDenied => 'Авторизация не предоставлена. Повторите попытку.';

  @override
  String get oauthSaving => 'Подключение аккаунта…';

  @override
  String get oauthQuotaExceeded => 'У этого аккаунта нет доступной квоты.';

  @override
  String get oauthRateLimited =>
      'Слишком много запросов. Повторите попытку позже.';

  @override
  String get oauthPermissionDenied =>
      'У этого аккаунта нет доступа к этому ресурсу.';

  @override
  String get oauthRequestFailed => 'Провайдер не смог выполнить запрос.';

  @override
  String get oauthQuotaAvailable => 'Квота доступна';

  @override
  String oauthSavedResets(String count) {
    return 'Доступно сбросов квоты: $count';
  }

  @override
  String get oauthPrimaryWindow => 'Основное окно';

  @override
  String get oauthSecondaryWindow => 'Дополнительное окно';

  @override
  String get oauthAuthorizationCode =>
      'Код авторизации или URL обратного вызова';

  @override
  String get oauthAuthorizationCodeHint =>
      'Если браузер не вернулся автоматически, вставьте сюда итоговый URL обратного вызова или код авторизации.';

  @override
  String get oauthInvalidAuthorizationCode =>
      'Введите код или URL обратного вызова из этой попытки входа.';

  @override
  String get oauthSubmitAuthorizationCode => 'Завершить вход';

  @override
  String get oauthExtraUsage => 'Дополнительное использование';

  @override
  String get oauthMonthlyTotal => 'Месячный лимит';

  @override
  String get oauthMonthlyCode => 'Месячный лимит кода';

  @override
  String get oauthSpendCap => 'Лимит расходования кредитов';

  @override
  String get oauthOnDemand => 'Квота по требованию';

  @override
  String get oauthQuotaAdvisory =>
      'Только для справки: активные недельные кредиты делают этот месячный лимит неопределённым.';

  @override
  String oauthCreditsValue(String value) {
    return '$value кредитов';
  }

  @override
  String oauthRemainingValue(String value) {
    return 'Осталось $value';
  }

  @override
  String get oauthPromptCachingHelp =>
      'Повторно используйте контекст между сообщениями и выберите, как долго хранится кэш.';

  @override
  String get scheduledTasksPreparation => 'Выполнение и уведомления';

  @override
  String get scheduledTasksAllowPreparation =>
      'Разрешить заблаговременную подготовку';

  @override
  String get scheduledTasksPreparationDetail =>
      'Заблаговременная подготовка подходит для текстовых задач, не требующих актуальной информации. Она не использует инструменты и вложения и не выполняет внешних действий.';

  @override
  String get scheduledTasksIOSDetail =>
      'Ограничения фоновой работы iOS не позволяют Kelivo просыпаться в заданное время для запуска модели. Вместо этого содержимое готовится, пока приложение может работать, а система показывает уведомление в запланированное время. Готовится только ближайший запуск. Подготовка может не завершиться после выхода из приложения; откройте Kelivo снова, чтобы подготовить последующие запуски.';

  @override
  String get scheduledTasksContextPolicy => 'Контекст чата';

  @override
  String get scheduledTasksContextLatest => 'Следовать последнему чату';

  @override
  String get scheduledTasksContextSnapshot =>
      'Использовать снимок на момент подготовки';

  @override
  String get scheduledTasksUnavailable => 'Если выполнить невозможно';

  @override
  String get scheduledTasksRemind => 'Только отправить напоминание';

  @override
  String get scheduledTasksSkip => 'Пропустить этот запуск';

  @override
  String get scheduledTasksNotify => 'Уведомления о результатах';

  @override
  String get scheduledTasksShowPreview =>
      'Показывать текст результата в уведомлениях';

  @override
  String get scheduledTasksPreparationWindow => 'Готовить не ранее чем за';

  @override
  String get scheduledTasksPreparationAttempts =>
      'Предел автоматических попыток';

  @override
  String get scheduledTasksPreparationCooldown =>
      'Минимальный интервал (минуты)';

  @override
  String get scheduledTasksPreparationBudget =>
      'Одновременно готовится не более одной задачи из всех. Автоматическая подготовка приостанавливается после шести попыток в час, включая отменённые запросы. На «Подготовить сейчас» ограничение по числу попыток не распространяется.';

  @override
  String get scheduledTasksPreparing => 'Подготовка результата';

  @override
  String get scheduledTasksPrepared => 'Результат подготовлен';

  @override
  String get scheduledTasksPendingPreparation => 'Результат ещё не подготовлен';

  @override
  String get scheduledTasksNotificationRegistered =>
      'Уведомление запланировано';

  @override
  String get scheduledTasksNotificationUnavailable =>
      'Уведомление не запланировано';

  @override
  String get scheduledTasksReminded => 'Срок наступил · только напоминание';

  @override
  String get scheduledTasksSkipped => 'Пропущено';

  @override
  String get scheduledTasksCancelled => 'Отменено';

  @override
  String get scheduledTasksReminderBody =>
      'Срок вашей запланированной задачи наступил. Откройте Kelivo, чтобы продолжить.';

  @override
  String get scheduledTasksResultBody =>
      'Результат вашей запланированной задачи готов.';

  @override
  String get scheduledTasksNotificationPermission =>
      'Разрешить уведомления о задачах';

  @override
  String get scheduledTasksPreparationCost =>
      'Подготовка вызывает модель и может стоить дополнительно. При выборе «Следовать последнему чату» новые сообщения до наступления срока могут сделать подготовленный результат недействительным. За неиспользованный или отменённый вывод может всё равно начисляться оплата, а повторная подготовка снова вызывает модель.';

  @override
  String get scheduledTasksAllowPreparationTip =>
      'Создавать следующий результат до назначенного времени, пока Kelivo может работать. Результат не появляется в чате до наступления срока. Подготовка использует только текст, без инструментов, вложений и пользовательских тел запросов. Это может повлечь расходы на модель.';

  @override
  String get scheduledTasksContextPolicyTip =>
      'Следовать последнему чату: до наступления срока новые сообщения, правки или переключение версий сообщений аннулируют подготовленный результат; повторная подготовка расходует попытку и может стоить дополнительно. После наступления срока сохранённый результат уведомления добавляется в чат без изменений.\n\nИспользовать снимок на момент подготовки: сохранять подготовленный результат, даже если чат изменился. Он не будет учитывать последующие сообщения.';

  @override
  String get scheduledTasksPreparationWindowTip =>
      'За сколько времени до запланированного момента может начаться подготовка, максимум 24 часа. Например, открыв Kelivo в полдень, можно подготовить напоминание на следующее утро. Больший интервал даёт больше возможностей для подготовки, но результат может быть менее актуальным. Это не меняет время задачи и не гарантирует фоновое выполнение. «Подготовить сейчас» обходит этот период автоматического ожидания и все лимиты попыток.';

  @override
  String get scheduledTasksPreparationAttemptsTip =>
      'Автоматическая подготовка приостанавливается, когда для этого наступления достигнут общий лимит попыток. Первые попытки, ошибки, отмены и ручная подготовка учитываются в записи. «Подготовить сейчас» может выполняться и после достижения этого лимита. Больше попыток — больше возможных списаний за модель; это не лимит расходов.';

  @override
  String get scheduledTasksPreparationCooldownTip =>
      'Минимальное время между началом попыток подготовки для одного и того же наступления. Более длительное ожидание сокращает повторные запросы. Повторная попытка всё равно требует, чтобы приложение могло работать; это не фоновый таймер. «Подготовить сейчас» обходит этот период автоматического ожидания и все лимиты попыток.';

  @override
  String get scheduledTasksUnavailableTip =>
      'Если подготовленный результат недоступен и задача не может выполниться в срок, отправить напоминание или пропустить это наступление. Напоминание не содержит сгенерированного ответа и требует включённых уведомлений. Если Kelivo открыт в момент наступления срока, задача может выполниться тогда.';

  @override
  String get scheduledTasksNotifyTip =>
      'Разрешить уведомления о результатах и резервные напоминания. Отключение не останавливает задачу или вызовы модели и не предотвращает списания за подготовку. Также требуется разрешение системы на уведомления.';

  @override
  String get scheduledTasksShowPreviewTip =>
      'Показывать текст подготовленного результата в уведомлении, в том числе на экране блокировки, если это разрешено системными настройками. Отключите, чтобы показывать общее уведомление; полный результат остаётся доступен в чате. Также применяются глобальные настройки приватности уведомлений.';

  @override
  String scheduledTasksHours(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count часа',
      many: '$count часов',
      few: '$count часа',
      one: '$count час',
    );
    return '$_temp0';
  }

  @override
  String scheduledTasksMinutes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count минуты',
      many: '$count минут',
      few: '$count минуты',
      one: '$count минута',
    );
    return '$_temp0';
  }

  @override
  String get scheduledTasksPreparationOff => 'Подготовка отключена';

  @override
  String get scheduledTasksPreparationQueued => 'В очереди';

  @override
  String get scheduledTasksPreparationQueuedDetail =>
      'Подготавливается другая задача. Подходящие задачи продолжаются в порядке времени наступления.';

  @override
  String get scheduledTasksPreparationIdle => 'Ожидание чата';

  @override
  String get scheduledTasksPreparationIdleDetail =>
      'Подготовка возобновится после завершения активных ответов и стабилизации контекста этой задачи.';

  @override
  String get scheduledTasksPreparationWindowWaiting => 'Вне окна подготовки';

  @override
  String get scheduledTasksPreparationCooldownWaiting => 'Ожидание повтора';

  @override
  String scheduledTasksPreparationRetryAt(String time) {
    return 'Повтор возможен после $time';
  }

  @override
  String get scheduledTasksPreparationLimitReached =>
      'Достигнут лимит автоматических попыток';

  @override
  String scheduledTasksPreparationAttemptsUsed(int count, int limit) {
    return 'Для этого наступления использовано попыток: $count; автоматический лимит: $limit. Используйте «Подготовить сейчас», чтобы продолжить вручную.';
  }

  @override
  String get scheduledTasksPreparationHourlyLimit =>
      'Достигнут почасовой лимит автоматической подготовки';

  @override
  String get scheduledTasksPreparationHourlyLimitDetail =>
      'Автоматическая подготовка приостановлена до появления почасовой квоты. Вы всё ещё можете использовать «Подготовить сейчас».';

  @override
  String get scheduledTasksPreparationUnavailable => 'Подготовка недоступна';

  @override
  String get scheduledTasksPreparationReadFailed =>
      'Не удалось прочитать контекст задачи. Скоро будет выполнена повторная проверка; подробности см. в истории выполнения.';

  @override
  String get scheduledTasksPreparationResultRetained =>
      'Не удалось проверить контекст. Подготовленный результат сохранён, проверка будет повторена.';

  @override
  String get scheduledTasksPreparationContextChanged =>
      'Чат или контекст задачи изменились, поэтому прежний результат отменён.';

  @override
  String get scheduledTasksPreparationPublishing => 'Ожидание добавления в чат';

  @override
  String get scheduledTasksPreparationPublishingDetail =>
      'Сохранённый результат будет добавлен в чат после завершения текущего ответа.';

  @override
  String get scheduledTasksPreparationPrompt => 'Промпт подготовки';

  @override
  String get scheduledTasksPreparationPromptTip =>
      'Дополнительные системные инструкции, используемые только при заблаговременной подготовке этой задачи, отдельно от инструкций задачи. Вы можете изменить стиль или полностью убрать эти инструкции. Инструменты и актуальная информация остаются недоступны. Изменение этого промпта аннулирует результат, подготовленный до наступления срока; повторная подготовка может привести к дополнительному списанию за модель.';

  @override
  String get scheduledTasksPreparationPromptEmpty =>
      'Оставьте пустым, чтобы не добавлять инструкции подготовки';

  @override
  String scheduledTasksPreparationPromptVariables(
    String timeVariable,
    String offsetVariable,
  ) {
    return 'Плейсхолдеры: $timeVariable — запланированное локальное время доставки; $offsetVariable — его смещение UTC. Они заменяются при подготовке результата.';
  }

  @override
  String get scheduledTasksPrepareNow => 'Подготовить сейчас';

  @override
  String get scheduledTasksPrepareNowDetail =>
      'Подготовить следующий результат сейчас и доставить его в запланированное время. Периоды автоматического ожидания и лимиты попыток не применяются. Это может привести к списаниям за модель. Существующий подготовленный результат используется повторно.';

  @override
  String get scheduledTasksPrepareNowReady =>
      'Следующий результат уже подготовлен. Дополнительный запрос к модели не выполнялся.';

  @override
  String get scheduledTasksPrepareNowStarted =>
      'Идёт подготовка следующего результата к запланированному времени.';

  @override
  String get scheduledTasksPrepareNowBusy =>
      'Подготавливается другая задача. Повторите попытку после её завершения.';

  @override
  String get scheduledTasksPrepareNowChatBusy =>
      'Дождитесь завершения текущего ответа и повторите попытку.';

  @override
  String get scheduledTasksPrepareNowDisabled =>
      'Сначала включите задачу и заблаговременную подготовку. Задачи с режимом перегенерации нельзя подготовить заранее.';

  @override
  String get scheduledTasksPrepareNowUnavailable =>
      'Подготовка пока недоступна. Повторите попытку чуть позже.';

  @override
  String get scheduledTasksPrepareNowNoUpcoming =>
      'Нет предстоящего наступления для подготовки. Проверьте время задачи и состояние включения.';

  @override
  String get phoneControlTitle => 'Управление телефоном';

  @override
  String get phoneControlSubtitle =>
      'Чтение экрана и выполнение действий через специальные возможности';

  @override
  String get phoneControlAccessibilityService =>
      'Служба специальных возможностей';

  @override
  String get phoneControlOpenSettings =>
      'Открыть настройки специальных возможностей';

  @override
  String get phoneControlRefresh => 'Обновить статус';

  @override
  String get phoneControlChecking => 'Проверка статуса службы…';

  @override
  String get phoneControlReady => 'Включена и подключена';

  @override
  String get phoneControlDisabled => 'Не включена';

  @override
  String get phoneControlDisconnected =>
      'Включена, но не подключена. Попробуйте выключить и снова включить службу в системных настройках, затем обновите статус.';

  @override
  String get phoneControlStatusUnavailable =>
      'Не удалось прочитать статус службы. Обновите, чтобы повторить попытку.';

  @override
  String get phoneControlSettingsUnavailable =>
      'Не удалось открыть настройки. Откройте Android Настройки → Специальные возможности вручную.';

  @override
  String get phoneControlUsageTitle => 'Как это работает';

  @override
  String get phoneControlDisclosure =>
      'Для задач управления телефоном, которые вы запрашиваете в чате, ассистент может читать текущий экран, нажимать, вводить текст, прокручивать, перемещаться и открывать приложения. Содержимое экрана отправляется провайдеру модели, настроенному для этого чата, и сохраняется в результатах его инструментов. Поля паролей скрыты. Служба не ведёт непрерывную запись содержимого экрана. Вы можете в любой момент отключить этот инструмент для ассистента или отключить службу в системных настройках.';

  @override
  String get phoneControlAssistantTitle => 'Включите инструмент для ассистента';

  @override
  String get phoneControlAssistantHint =>
      'Требуются оба разрешения: включите Kelivo phone control в системных настройках Специальных возможностей, затем включите «Управление телефоном» в разделе «Локальные инструменты» вашего ассистента (также доступно в меню инструментов чата). Каждый ассистент настраивается отдельно. Держите телефон разблокированным во время выполнения задачи.';

  @override
  String get phoneControlRestrictedTitle =>
      'Переключатель специальных возможностей недоступен?';

  @override
  String get phoneControlRestrictedHint =>
      'Для некоторых загруженных APK Android сначала требует «Разрешить ограниченные настройки» в меню информации о приложении. Нажмите, чтобы открыть информацию о приложении Kelivo, затем вернитесь в настройки Специальных возможностей.';

  @override
  String get phoneControlEnableAssistant =>
      'Разрешить этому ассистенту использовать управление телефоном';

  @override
  String get composerDraftLabel => 'Черновик';

  @override
  String get composerDraftRecovered =>
      'Восстановлено неотправленное сообщение.';

  @override
  String get composerDraftRestore => 'Продолжить редактирование';

  @override
  String get composerDraftDiscard => 'Отменить';

  @override
  String get composerDraftSaveFailed =>
      'Не удалось сохранить последний черновик. Он всё ещё в этом окне.';

  @override
  String get composerDraftRetry => 'Повторить сохранение';

  @override
  String get composerDraftConflictTitle => 'В этом чате уже есть черновик';

  @override
  String get composerDraftConflictBody =>
      'Добавление сохраняет оба текста и вложения. Замена отменяет существующий черновик. Ничего не отправляется автоматически.';

  @override
  String get composerDraftAppend => 'Добавить';

  @override
  String get composerDraftReplace => 'Заменить черновик';

  @override
  String get composerDraftMissingFile =>
      'Вложение недоступно. Удалите его или выберите файл снова.';

  @override
  String get composerDraftMessageMissing =>
      'Редактируемое сообщение больше не существует. Скопируйте текст в новое сообщение или отмените это редактирование.';

  @override
  String get composerDraftDeleteNotice =>
      'Неотправленные черновики в этих чатах также будут удалены.';

  @override
  String get mcpOAuthSettings => 'Настройки OAuth';

  @override
  String get mcpOAuthAutomatic => 'Автоматически';

  @override
  String get mcpOAuthMetadataUrl => 'URL документа метаданных клиента';

  @override
  String get mcpOAuthClientAuthentication => 'Аутентификация клиента';

  @override
  String get mcpOAuthPublicClient => 'Публичный клиент';

  @override
  String get mcpOAuthRedirectUri =>
      'Локальный URL обратного вызова (необязательно)';

  @override
  String get mcpOAuthFillRedirectExample => 'Заполнить примером';

  @override
  String get mcpOAuthRedirectHint =>
      'Оставьте пустым для использования значения по умолчанию платформы. Используйте HTTP loopback URL, если служба разрешает только обратные вызовы localhost. Порт 0 выбирает доступный порт; предварительно зарегистрированный клиент может требовать фиксированный порт.';

  @override
  String get mcpOAuthClientIdRequired =>
      'Введите ID клиента или выберите автоматическую регистрацию.';

  @override
  String get mcpOAuthMetadataUrlInvalid =>
      'Введите HTTPS URL документа метаданных с путём.';

  @override
  String get mcpOAuthSecretRequired =>
      'Этот метод аутентификации клиента требует секрет клиента.';

  @override
  String get mcpOAuthRedirectInvalid =>
      'Используйте HTTP обратный вызов на localhost, 127.0.0.1 или [::1], без учётных данных, параметров запроса или фрагмента.';

  @override
  String get mcpOAuthDiscovering => 'Обнаружение сервера авторизации…';

  @override
  String get mcpOAuthRegistering => 'Подготовка авторизации…';

  @override
  String get mcpOAuthWaitingBrowser => 'Ожидание авторизации в браузере…';

  @override
  String get mcpOAuthExchangingToken => 'Завершение входа…';

  @override
  String get markdownPlaygroundTitle => 'Markdown Playground';

  @override
  String get markdownPlaygroundSource => 'Исходный Markdown';

  @override
  String get markdownPlaygroundPreview => 'Предпросмотр';

  @override
  String get markdownPlaygroundAst => 'AST';

  @override
  String get markdownPlaygroundPlay => 'Поток символов';

  @override
  String get markdownPlaygroundPause => 'Пауза';

  @override
  String get markdownPlaygroundResume => 'Продолжить';

  @override
  String get markdownPlaygroundShowAll => 'Показать полностью';

  @override
  String get markdownPlaygroundWidth => 'Ширина предпросмотра';

  @override
  String get markdownPlaygroundTheme => 'Тема предпросмотра';

  @override
  String get markdownPlaygroundPlain => 'Выделенный простой текст';

  @override
  String get markdownPlaygroundMarkdown => 'Выделенный Markdown';

  @override
  String get markdownPlaygroundSelectionHint =>
      'Выделите текст в предпросмотре, чтобы проверить скопированное содержимое.';

  @override
  String get markdownPlaygroundEmpty => 'Введите Markdown для предпросмотра.';

  @override
  String markdownPlaygroundProgress(int shown, int total) {
    return 'Введено $shown / $total';
  }

  @override
  String get markdownCopyMarkdownAction => 'Копировать Markdown';

  @override
  String get markdownCopyCsvAction => 'Копировать CSV';

  @override
  String get markdownCopyImageAction => 'Копировать изображение';

  @override
  String get markdownCodeLabel => 'Код';

  @override
  String get markdownDetailsLabel => 'Подробности';

  @override
  String markdownMoreRows(int count) {
    return 'Показать ещё $count строк';
  }

  @override
  String get markdownNoteLabel => 'Примечание';

  @override
  String get markdownTipLabel => 'Совет';

  @override
  String get markdownImportantLabel => 'Важно';

  @override
  String get markdownWarningLabel => 'Предупреждение';

  @override
  String get markdownCautionLabel => 'Осторожно';

  @override
  String get markdownDangerLabel => 'Опасно';

  @override
  String get markdownCopyRichTextAction => 'Копировать форматированный текст';

  @override
  String get markdownCopySelectionFailed =>
      'Не удалось скопировать выделенный текст.';

  @override
  String get recoveryMissingDataTitle => 'Обнаружены предыдущие данные';

  @override
  String get recoveryMissingDataBody =>
      'Kelivo не удалось найти текущую базу данных чатов. Загрузка приостановлена, пустая база данных не создавалась. Ниже мы поищем предыдущие копии; существующие файлы будут сохранены.';

  @override
  String get recoveryEmptyDataTitle => 'Текущая история чатов пуста';

  @override
  String get recoveryEmptyDataBody =>
      'Текущий список чатов пуст, но найдены предыдущие копии. Выберите копию ниже, чтобы восстановить чаты. Существующие файлы будут сохранены.';

  @override
  String get recoveryKeepCurrent => 'Продолжить с пустым списком чатов';

  @override
  String get recoveryKeepCurrentConfirm =>
      'Продолжение без восстановления предыдущих чатов. Текущий список чатов останется пустым; старые копии будут сохранены. Если вы хотите вернуть чаты, отмените и выберите локальную копию.';

  @override
  String get recoverySearchingCopies =>
      'Поиск и проверка локальных копий данных…';

  @override
  String recoveryFoundCopies(int count) {
    return 'Найдено проверенных копий: $count. Выберите одну, чтобы восстановить чаты и настройки. Исходные файлы будут сохранены.';
  }

  @override
  String recoveryInvalidCopy(String name) {
    return '$name: проверка не пройдена. Исходный файл сохранён.';
  }

  @override
  String get recoverySearchFailed =>
      'Некоторые расположения данных не удалось прочитать. Ваши файлы сохранены; перед другими действиями восстановления экспортируйте копию данных.';

  @override
  String get recoveryDiscoveredCopyBody =>
      'Найдено вне папки управляемых копий. Этот оригинал сохранён и будет полностью проверен перед восстановлением.';

  @override
  String get recoveryStorageFailureTitle =>
      'Требуется проверить хранилище данных';

  @override
  String get recoveryStorageFailureBody =>
      'Не удалось завершить обновление данных. Исходные данные сохранены. Попробуйте снова открыть Kelivo или выберите локальную копию ниже для восстановления.';

  @override
  String get recoveryProtectingTitle => 'Защита базы данных чатов';

  @override
  String get recoveryProtectingData =>
      'Копирование и проверка базы данных. Изображения, вложения и снимки остаются в Documents и повторно не копируются. Исходная база данных будет сохранена.';

  @override
  String get recoveryStorageReadyTitle =>
      'База данных чатов перемещена во внутреннее хранилище';

  @override
  String get recoveryStorageReadyBody =>
      'База данных с чатами, ассистентами и настройками теперь использует внутреннее хранилище приложения. Снимки, изображения и вложения остаются доступны в приложении «Файлы» в папке Documents. Исходная база данных сохранена. Если старые чаты отсутствуют, откройте «Настройки → Резервное копирование → Локальные копии».';

  @override
  String get recoveryRetainedData => 'Сохранённые исходные данные';

  @override
  String get recoveryNoValidCopies =>
      'Копии найдены, но ни одна не прошла проверку. Оригиналы сохранены. Вы можете экспортировать данные для дальнейшей диагностики.';

  @override
  String get recoveryStorageInsufficientSpaceBody =>
      'Недостаточно места в хранилище, чтобы безопасно подготовить данные. Освободите место в системных настройках, затем снова откройте Kelivo или перепроверьте копии ниже. Не удаляйте Kelivo и оставьте его данные и локальные копии на месте.';

  @override
  String get migrationFreshStartTitle => 'Новый старт готов';

  @override
  String get migrationFreshStartSubtitle =>
      'Новая пустая база данных готова, предыдущие данные сохранены. Перезапустите приложение, чтобы продолжить.';

  @override
  String get migrationFreshStartFailedTitle =>
      'Не удалось выполнить новый старт';

  @override
  String get migrationFreshStartFailedSubtitle =>
      'Предыдущие данные сохранены. Повторите новый старт или закройте и снова откройте приложение.';

  @override
  String get imageExportPreparing => 'Подготовка изображения…';

  @override
  String imageExportDiagrams(int completed, int total) {
    return 'Подготовка диаграмм $completed/$total…';
  }

  @override
  String imageExportCapturing(int completed, int total) {
    return 'Создание снимка $completed/$total…';
  }

  @override
  String get imageExportProcessing =>
      'Объединение изображения и подготовка предпросмотра…';

  @override
  String get imageExportSaving => 'Сохранение изображения…';

  @override
  String get backupEncryptionTitle => 'Шифровать резервные копии';

  @override
  String get backupEncryptionOffHint =>
      'Незашифрованные резервные копии может прочитать любой, у кого есть файл.';

  @override
  String get backupEncryptionOnHint =>
      'Резервные копии шифруются. После перезапуска приложения введите пароль снова.';

  @override
  String get backupEncryptionPasswordHint =>
      'Надёжно сохраните этот пароль. Если вы его потеряете, резервную копию нельзя будет восстановить. Он хранится в памяти до выхода из приложения.';

  @override
  String get backupEncryptionPassword => 'Пароль';

  @override
  String get backupEncryptionConfirmPassword => 'Подтвердите пароль';

  @override
  String get backupEncryptionMismatch => 'Пароли не совпадают.';

  @override
  String get backupEncryptionShowPassword => 'Показать пароль';

  @override
  String get backupEncryptionHidePassword => 'Скрыть пароль';

  @override
  String get backupEncryptionUnlockTitle => 'Зашифрованная резервная копия';

  @override
  String get backupEncryptionUnlockHint =>
      'Введите пароль, использованный при создании этой резервной копии.';

  @override
  String get backupEncryptionUnlock => 'Разблокировать';

  @override
  String get backupEncryptionFailed =>
      'Неверный пароль или резервная копия повреждена. Повторите попытку или отмените.';

  @override
  String get backupEncryptionInvalid =>
      'Зашифрованная резервная копия неполна или имеет неверный формат.';

  @override
  String get backupEncryptionUnsupported =>
      'Для этой зашифрованной резервной копии требуется более новая версия Kelivo.';

  @override
  String get backupProgressEncrypting => 'Шифрование резервной копии';

  @override
  String get backupProgressDecrypting => 'Расшифровка резервной копии';

  @override
  String get mcpPageStatusFailed => 'Ошибка подключения';

  @override
  String mcpPageCardToolsShort(int enabled, int total) {
    return 'Инструменты $enabled/$total';
  }

  @override
  String mcpPageSelectServer(String name) {
    return 'Выбрать $name';
  }

  @override
  String get mcpIconTitle => 'Значок сервера';

  @override
  String get mcpIconInvalid =>
      'Не удалось использовать это изображение. Выберите допустимое изображение размером до 10 МБ.';

  @override
  String get mcpSelectServers => 'Выбрать серверы';

  @override
  String get mcpMoveToGroup => 'Переместить в группу';

  @override
  String get mcpRenameGroup => 'Переименовать группу';

  @override
  String get mcpDeleteGroupConfirm =>
      'Серверы из этой группы будут перемещены в «Другие». Сами серверы не будут удалены.';

  @override
  String get mcpGroupNameInvalid =>
      'Введите непустое и уникальное название группы.';

  @override
  String get mcpEnableSelected => 'Включить';

  @override
  String get mcpDisableSelected => 'Отключить';

  @override
  String mcpDeleteSelectedConfirm(int count) {
    return 'Удалить выбранные серверы ($count)?';
  }

  @override
  String get browserTitle => 'Браузер';

  @override
  String get browserSearchHint => 'Поиск или ввод адреса сайта';

  @override
  String get browserStartTitle => 'Куда дальше?';

  @override
  String get browserStartSubtitle =>
      'Просматривайте свободно. Ассистент поможет, когда понадобится.';

  @override
  String get browserNewTab => 'Новая вкладка';

  @override
  String get browserTabs => 'Вкладки';

  @override
  String get browserCloseTab => 'Закрыть вкладку';

  @override
  String get browserClose => 'Закрыть браузер';

  @override
  String get browserBack => 'Назад';

  @override
  String get browserForward => 'Вперёд';

  @override
  String get browserReload => 'Обновить';

  @override
  String get browserStop => 'Остановить загрузку';

  @override
  String get browserMore => 'Ещё';

  @override
  String get browserBookmarks => 'Закладки';

  @override
  String get browserHistory => 'История';

  @override
  String get browserSettings => 'Настройки браузера';

  @override
  String get browserAddBookmark => 'Добавить закладку';

  @override
  String get browserRemoveBookmark => 'Удалить закладку';

  @override
  String get browserNoBookmarks => 'Ваши избранные сайты собраны здесь.';

  @override
  String get browserNoHistory => 'История просмотров появится здесь.';

  @override
  String get browserSearchLibrary => 'Поиск сохранённых страниц';

  @override
  String get browserClearHistory => 'Очистить историю';

  @override
  String get browserClearHistoryConfirm =>
      'Удалить всю историю просмотров? Закладки сохранятся.';

  @override
  String get browserToday => 'Сегодня';

  @override
  String get browserYesterday => 'Вчера';

  @override
  String get browserDelete => 'Удалить';

  @override
  String get browserCancel => 'Отмена';

  @override
  String get browserDone => 'Готово';

  @override
  String get browserFind => 'Найти на странице';

  @override
  String get browserFindPreviousMatch => 'Предыдущее совпадение';

  @override
  String get browserFindNextMatch => 'Следующее совпадение';

  @override
  String get browserFindHint => 'Найти текст';

  @override
  String get browserSearchEngine => 'Поисковая система';

  @override
  String get browserDesktopMode => 'Полная версия сайта';

  @override
  String get browserDesktopModeDescription =>
      'Перезагружать открытые страницы с пользовательским агентом настольного браузера.';

  @override
  String get browserRestoreTabs => 'Восстанавливать вкладки';

  @override
  String get browserRestoreTabsDescription =>
      'Снова открывать ваши вкладки при запуске Kelivo.';

  @override
  String get browserSaveHistory => 'Сохранять историю';

  @override
  String get browserSaveHistoryDescription =>
      'Хранить локальную запись посещённых страниц.';

  @override
  String get browserClearData => 'Очистить данные сайтов';

  @override
  String get browserClearDataConfirm =>
      'Очистить cookie, хранилище и кеш и закрыть все вкладки? Вы выйдете из аккаунтов на сайтах.';

  @override
  String get browserDataCleared => 'Данные сайтов очищены';

  @override
  String get browserAgentControl => 'Управление ассистентом';

  @override
  String get browserAgentWorking => 'ИИ работает';

  @override
  String get browserTakeOver => 'Перехватить управление';

  @override
  String get browserAgentPaused => 'Действия ИИ приостановлены';

  @override
  String get browserAllowAgent => 'Разрешить продолжить';

  @override
  String get browserAgentDescription =>
      'Отправьте задачу в чате, чтобы ИИ мог использовать браузер. Разрешение продолжить лишь снимает паузу; оно не отправляет сообщение и не запускает задачу.';

  @override
  String get browserOpenExternal => 'Открыть в браузере по умолчанию';

  @override
  String get browserCopyLink => 'Копировать ссылку';

  @override
  String get browserLinkCopied => 'Ссылка скопирована';

  @override
  String get browserUnsupported =>
      'Встроенный браузер недоступен на этой платформе.';

  @override
  String get browserStorageUnsupported =>
      'Для этого приложения рабочей области требуется Android System WebView или Microsoft Edge WebView2 Runtime версии 152 или новее. Обновите браузерный движок и повторите попытку.';

  @override
  String get browserLoadFailed => 'Не удалось загрузить эту страницу';

  @override
  String get browserRetry => 'Повторить';

  @override
  String get browserFavorites => 'Избранное';

  @override
  String get browserEditBookmark => 'Изменить закладку';

  @override
  String get browserBookmarkTitle => 'Название';

  @override
  String get browserBookmarkUrl => 'Адрес сайта';

  @override
  String get browserSave => 'Сохранить';

  @override
  String get browserDownloads => 'Загрузки';

  @override
  String get browserNoDownloads => 'Загруженные файлы появятся здесь.';

  @override
  String get browserDownloadCancel => 'Отменить загрузку';

  @override
  String get browserOpenDownload => 'Открыть файл';

  @override
  String get browserDownloadFailed => 'Не удалось загрузить';

  @override
  String get browserAgentEnableHint =>
      'Включите инструмент «Браузер» в инструментах чата, затем разрешите управление здесь.';

  @override
  String get browserSessionRequired =>
      'Откройте браузер из чата, чтобы разрешить управление ассистентом.';

  @override
  String get browserDownloadCancelled => 'Отменено';

  @override
  String get browserAgentEnabled => 'Разрешить ассистенту доступ к браузеру';

  @override
  String get browserAgentEnabledDescription =>
      'Включённые ассистенты могут просматривать страницы в этом браузере и взаимодействовать с ними.';

  @override
  String get browserToolTitle => 'Управление браузером';

  @override
  String get browserToolSubtitle =>
      'Просматривайте страницы с выполненным входом и взаимодействуйте с ними. Сначала включите управление ассистентом в настройках браузера.';

  @override
  String get browserOpen => 'Открыть браузер';

  @override
  String get browserInvalidUrl =>
      'Введите действительный адрес сайта HTTP или HTTPS.';

  @override
  String get browserClearDataUnavailable =>
      'Браузерный движок Windows не поддерживает очистку всех данных сайтов.';

  @override
  String get browserSurfaceStyle => 'Стиль поверхности';

  @override
  String get browserSurfaceLiquid => 'Жидкое стекло';

  @override
  String get browserSurfaceFrosted => 'Матовый';

  @override
  String get browserSurfaceSolid => 'Сплошной';

  @override
  String get browserPageOptions => 'Параметры страницы';

  @override
  String get browserAskAi => 'Поручить страницу ИИ';

  @override
  String get browserAskAiHint =>
      'Вернитесь в чат, добавьте запрос и отправьте.';

  @override
  String get browserAskAiCurrentPage => 'текущая страница браузера';

  @override
  String get browserAskAiUnavailable =>
      'Этот чат недоступен. Сначала откройте браузер из чата.';

  @override
  String get browserAskAiEditing =>
      'Завершите или отмените редактирование текущего сообщения, прежде чем добавлять задачу для страницы.';

  @override
  String get browserAskAiAssistantDisabled =>
      'Сначала включите управление браузером в инструментах этого ассистента.';

  @override
  String get browserAskAiBrowserDisabled =>
      'Сначала разрешите ассистентам использовать браузер в настройках браузера.';

  @override
  String browserAskAiDraft(String page) {
    return 'Пожалуйста, используй браузер, чтобы поработать с этой страницей:\n$page\n\nМой запрос: ';
  }

  @override
  String get browserOpenFullPage => 'Открыть на всю страницу';

  @override
  String get browserClosePanel => 'Закрыть панель браузера';

  @override
  String get browserSearchTabs => 'Поиск вкладок';

  @override
  String browserTabsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count вкладки',
      many: '$count вкладок',
      few: '$count вкладки',
      one: '$count вкладка',
    );
    return '$_temp0';
  }

  @override
  String get browserOpenInSidebar => 'Открыть в боковой панели';

  @override
  String get browserUserAgent => 'User agent';

  @override
  String get browserUserAgentMobile => 'Мобильный';

  @override
  String get browserUserAgentDesktop => 'Настольный';

  @override
  String get browserUserAgentCustom => 'Свой';

  @override
  String get browserUserAgentHint => 'Введите свой User-Agent';

  @override
  String get browserUserAgentInvalid =>
      'Используйте одну строку до 2048 печатных символов ASCII.';

  @override
  String get browserUserAgentDescription =>
      'Изменения перезагрузят текущую веб-страницу.';

  @override
  String browserStepsShowEarlier(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count предыдущих шага',
      many: '$count предыдущих шагов',
      few: '$count предыдущих шага',
      one: '$count предыдущий шаг',
    );
    return '$_temp0';
  }

  @override
  String get browserOpenThisPage => 'Открыть в браузере';

  @override
  String get browserGroupToggleSemantics => 'Показать или скрыть шаги браузера';

  @override
  String get browserStepGroupTitle => 'Просмотр веб-страниц';

  @override
  String browserStepCount(int count) {
    return '$count шагов';
  }

  @override
  String browserStepCurrent(int count) {
    return 'шаг $count';
  }

  @override
  String browserActionFailedCount(int count) {
    return '· $count с ошибкой';
  }

  @override
  String browserActionFailed(String action) {
    return '$action — ошибка';
  }

  @override
  String get browserCardOpen => 'Открыть';

  @override
  String get browserCardEnable => 'Включить';

  @override
  String browserCardRunning(String action) {
    return '$action…';
  }

  @override
  String get browserCardLive => 'В реальном времени';

  @override
  String get browserCardOpenFailed => 'Не удалось открыть страницу';

  @override
  String get browserCardBlankPage => 'Пустая страница';

  @override
  String browserCardTabCount(int count) {
    return '$count вкладок';
  }

  @override
  String get browserActionOpen => 'Открыть страницу';

  @override
  String get browserActionNewTab => 'Новая вкладка';

  @override
  String get browserActionRender => 'Отрисовать страницу';

  @override
  String get browserActionExtract => 'Извлечь текст';

  @override
  String get browserActionSnapshot => 'Прочитать структуру страницы';

  @override
  String get browserActionClick => 'Нажать';

  @override
  String get browserActionType => 'Ввести текст';

  @override
  String get browserActionPress => 'Нажать клавишу';

  @override
  String get browserActionScroll => 'Прокрутить';

  @override
  String get browserActionWait => 'Подождать';

  @override
  String get browserActionBack => 'Назад';

  @override
  String get browserActionForward => 'Вперёд';

  @override
  String get browserActionReload => 'Перезагрузить';

  @override
  String get browserActionEvaluate => 'Выполнить скрипт';

  @override
  String get browserActionSwitchTab => 'Переключить вкладку';

  @override
  String get browserActionCloseTab => 'Закрыть вкладку';

  @override
  String get browserActionListTabs => 'Список вкладок';

  @override
  String get browserActionUnknown => 'Действие браузера';

  @override
  String browserMetaChars(String count) {
    return '$count символов';
  }

  @override
  String browserMetaElements(int count) {
    return '$count элементов';
  }

  @override
  String get browserErrAgentDisabled => 'Управление браузером выключено';

  @override
  String get browserErrStaleRef => 'Элемент устарел; страницу нужно перечитать';

  @override
  String get browserErrNotVisible => 'Элемент скрыт или перекрыт';

  @override
  String get browserErrNotFound => 'Элемент не найден';

  @override
  String get browserErrTimeout => 'Время загрузки страницы истекло';

  @override
  String get browserErrHumanControl => 'Вы управляете браузером';

  @override
  String get browserErrTabClosed => 'Вкладка была закрыта';

  @override
  String get browserErrGeneric => 'Действие не выполнено';

  @override
  String get browserDirectionUp => 'Вверх';

  @override
  String get browserDirectionDown => 'Вниз';

  @override
  String get browserDirectionLeft => 'Влево';

  @override
  String get browserDirectionRight => 'Вправо';

  @override
  String browserMetaTabs(int count) {
    return '$count вкладок';
  }

  @override
  String get browserTabsCurrentConversation => 'Этот чат';

  @override
  String get browserTabsAll => 'Все вкладки';

  @override
  String get browserTabsUnassigned => 'Личные вкладки';

  @override
  String get browserTabsUnknownConversation => 'Другой чат';

  @override
  String get browserTabsEmptyConversation =>
      'Здесь пока нет вкладок. Откройте страницу или выберите вкладку в разделе «Все вкладки».';

  @override
  String get browserTabsNoResults => 'Нет подходящих вкладок';

  @override
  String get browserMoveToConversation => 'Переместить в этот чат';

  @override
  String get browserReopenInConversation => 'Открыть заново в этом чате';

  @override
  String get browserTabBusy =>
      'Ассистент всё ещё использует эту страницу. Дождитесь завершения или остановите задачу, прежде чем перемещать её.';

  @override
  String get browserLiveViewLimit =>
      'Все ресурсы браузера заняты. Повторите попытку после завершения задачи или закройте неиспользуемую страницу.';

  @override
  String get browserAskAiInOwnerConversation => 'Спросить ИИ в исходном чате';

  @override
  String get displaySettingsPageShowBrowserPageCardsTitle =>
      'Показывать карточки веб-страниц';

  @override
  String get browserObserverHint =>
      'ИИ использует эту страницу. Выберите «Перехватить управление», чтобы взаимодействовать.';

  @override
  String get genuiSurfaceTitle => 'Интерактивный интерфейс';

  @override
  String get genuiStatusStreaming => 'Генерация';

  @override
  String get genuiStatusInterrupted => 'Прервано';

  @override
  String get genuiStatusUnsaved => 'Не сохранено';

  @override
  String get genuiStatusUnsavedRetry => 'Нажмите, чтобы повторить сохранение';

  @override
  String get genuiReadOnlyUntilComplete =>
      'Доступно после завершения генерации';

  @override
  String get genuiReadOnlySnapshot => 'Снимок только для чтения';

  @override
  String genuiPendingNode(String id) {
    return 'Ожидание $id';
  }

  @override
  String get genuiViewSource => 'Просмотреть исходный код';

  @override
  String get genuiCopySource => 'Копировать исходный код';

  @override
  String get genuiExpand => 'Развернуть';

  @override
  String get genuiExpandedStub => 'Редактируется в развёрнутом виде';

  @override
  String get genuiMore => 'Ещё';

  @override
  String get genuiReset => 'Сбросить к значениям по умолчанию';

  @override
  String get genuiRepair => 'Исправить интерфейс';

  @override
  String get genuiInvalidTitle => 'Этот интерфейс невозможно отобразить';

  @override
  String genuiNodesFailed(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count узла невозможно отобразить',
      many: '$count узлов невозможно отобразить',
      few: '$count узла невозможно отобразить',
      one: '$count узел невозможно отобразить',
    );
    return '$_temp0';
  }

  @override
  String genuiErrorLine(int line) {
    return 'Строка $line';
  }

  @override
  String get genuiValueUnavailable => 'Нет значения';

  @override
  String get genuiFormulaInvalid => 'Эту формулу невозможно отобразить';

  @override
  String get genuiNodeUnavailable => 'Этот компонент недоступен';

  @override
  String get genuiErrorHeader => 'Недопустимый заголовок интерфейса';

  @override
  String get genuiErrorVersion => 'Неподдерживаемая версия языка интерфейса';

  @override
  String get genuiErrorCatalog => 'Неподдерживаемый каталог компонентов';

  @override
  String get genuiErrorRoot =>
      'Корневой компонент отсутствует или недействителен';

  @override
  String get genuiErrorSyntax => 'Неверный синтаксис объявления';

  @override
  String get genuiErrorDuplicateSymbol => 'Имя определено более одного раза';

  @override
  String get genuiErrorDuplicateProperty =>
      'Свойство определено более одного раза';

  @override
  String get genuiErrorReservedName => 'Это имя зарезервировано';

  @override
  String genuiErrorUnknownComponent(String detail) {
    return 'Неизвестный компонент $detail';
  }

  @override
  String genuiErrorUnknownProperty(String detail) {
    return 'Неизвестное свойство $detail';
  }

  @override
  String genuiErrorMissingProperty(String detail) {
    return 'Отсутствует обязательное свойство $detail';
  }

  @override
  String get genuiErrorBinding =>
      'Недействительная привязка записываемого ввода';

  @override
  String get genuiErrorReference => 'Недействительная ссылка на компонент';

  @override
  String get genuiErrorMissingReference =>
      'Содержимое, на которое есть ссылка, не определено';

  @override
  String get genuiErrorDependency =>
      'Требуемое содержимое невозможно отобразить';

  @override
  String get genuiErrorCycle => 'Циклические ссылки не поддерживаются';

  @override
  String get genuiErrorDuplicateParent =>
      'Компонент не может иметь двух родителей';

  @override
  String get genuiErrorUnreachableNode =>
      'Этот компонент находится вне корневого дерева';

  @override
  String get genuiErrorType => 'Несовместимый тип значения';

  @override
  String get genuiErrorValue =>
      'Значение вне поддерживаемых вариантов или диапазона';

  @override
  String get genuiErrorSourceBudget =>
      'Исходный код интерфейса превышает предельный размер';

  @override
  String get genuiErrorDeclarationBudget =>
      'Объявление превышает предельный размер';

  @override
  String get genuiErrorDeclarationCount => 'Слишком много объявлений';

  @override
  String get genuiErrorComponentCount => 'Слишком много компонентов';

  @override
  String get genuiErrorInputCount => 'Слишком много полей ввода';

  @override
  String get genuiErrorComponentDepth =>
      'Слишком глубокая вложенность компонентов';

  @override
  String get genuiErrorExpressionDepth =>
      'Слишком глубокая вложенность вычислений';

  @override
  String get genuiErrorFunction => 'Неизвестная функция вычисления';

  @override
  String get genuiErrorAction => 'Неподдерживаемое действие';

  @override
  String get genuiErrorNestedSample => 'Вложенная выборка не поддерживается';

  @override
  String get genuiErrorSample =>
      'Недействительный диапазон или количество выборки';

  @override
  String get genuiErrorDataBudget => 'Данные превышают поддерживаемый размер';

  @override
  String get genuiErrorRowKey =>
      'Строки должны иметь уникальные непустые ключи';

  @override
  String get genuiErrorDomain => 'Значение вне области определения функции';

  @override
  String get genuiErrorDivisionByZero => 'Деление на ноль не определено';

  @override
  String get genuiErrorNonFinite => 'Результат вычисления — не конечное число';

  @override
  String get genuiErrorOperationsBudget =>
      'Вычисление превысило лимит операций';

  @override
  String genuiMetricTrend(String value) {
    return 'Изменение $value';
  }

  @override
  String genuiFormErrorsLeft(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count поля требуют внимания',
      many: '$count полей требуют внимания',
      few: '$count поля требуют внимания',
      one: '$count поле требует внимания',
    );
    return '$_temp0';
  }

  @override
  String get genuiFieldRequired => 'Обязательно';

  @override
  String genuiNumberRange(String min, String max) {
    return 'Диапазон $min–$max';
  }

  @override
  String genuiNumberMinimum(String min) {
    return 'Минимум $min';
  }

  @override
  String genuiNumberMaximum(String max) {
    return 'Максимум $max';
  }

  @override
  String genuiFieldTooShort(int min) {
    return 'Не менее $min символов';
  }

  @override
  String genuiFieldTooLong(int max) {
    return 'Не более $max символов';
  }

  @override
  String get genuiInvalidNumber => 'Введите полное конечное число';

  @override
  String get genuiChooseOption => 'Выберите вариант';

  @override
  String get genuiFinishComposing => 'Завершите ввод перед продолжением';

  @override
  String genuiActionDisabledDep(String id) {
    return 'Отключено: зависит от $id, который невозможно отобразить';
  }

  @override
  String get genuiActionUnavailable =>
      'Это действие недоступно в данном представлении';

  @override
  String get genuiActionDisabled => 'Отключено этим интерфейсом';

  @override
  String get genuiFormUnavailable =>
      'Эта форма содержит содержимое, которое невозможно отобразить';

  @override
  String genuiDecrease(String label) {
    return 'Уменьшить $label';
  }

  @override
  String genuiIncrease(String label) {
    return 'Увеличить $label';
  }

  @override
  String genuiCharacterCount(int used, int max) {
    return '$used / $max символов';
  }

  @override
  String get genuiBlockLimit =>
      'До 3 блоков интерфейса на сообщение; остальные показаны как исходный код';

  @override
  String get genuiChartLine => 'Линейный график';

  @override
  String get genuiChartArea => 'График с областями';

  @override
  String get genuiChartBar => 'Столбчатая диаграмма';

  @override
  String get genuiChartScatter => 'Точечная диаграмма';

  @override
  String get genuiChartPie => 'Круговая диаграмма';

  @override
  String get genuiChartDonut => 'Кольцевая диаграмма';

  @override
  String get genuiChartEmpty => 'Нет данных в этом диапазоне';

  @override
  String get genuiChartAllHidden =>
      'Все ряды скрыты. Покажите ряд через легенду.';

  @override
  String genuiChartSummary(String kind, int series, int points, int missing) {
    String _temp0 = intl.Intl.pluralLogic(
      series,
      locale: localeName,
      other: '$series ряда',
      many: '$series рядов',
      few: '$series ряда',
      one: '$series ряд',
    );
    String _temp1 = intl.Intl.pluralLogic(
      points,
      locale: localeName,
      other: '$points строки данных',
      many: '$points строк данных',
      few: '$points строки данных',
      one: '$points строка данных',
    );
    String _temp2 = intl.Intl.pluralLogic(
      missing,
      locale: localeName,
      other: '$missing пропущенного значения',
      many: '$missing пропущенных значений',
      few: '$missing пропущенных значения',
      one: '$missing пропущенное значение',
    );
    return '$kind, $_temp0, $_temp1, $_temp2 (не соединены или заменены нулём).';
  }

  @override
  String genuiChartPieSummary(String kind, int count, String total) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count элемента',
      many: '$count элементов',
      few: '$count элемента',
      one: '$count элемент',
    );
    return '$kind, $_temp0, всего $total.';
  }

  @override
  String get genuiChartDomainGap => 'Не определено';

  @override
  String genuiChartDomainSummary(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count выборочной точки не определены',
      many: '$count выборочных точек не определены',
      few: '$count выборочные точки не определены',
      one: '$count выборочная точка не определена',
    );
    return '$_temp0; заштрихованные разрывы не соединены.';
  }

  @override
  String genuiChartShowSeries(String name) {
    return 'Показать $name';
  }

  @override
  String genuiChartHideSeries(String name) {
    return 'Скрыть $name';
  }

  @override
  String get genuiChartKeyboardHint =>
      'Стрелки влево и вправо выбирают строку данных. Стрелки вверх и вниз выбирают ряд. Escape снимает выбор.';

  @override
  String get genuiChartTotal => 'Итого';

  @override
  String get genuiChartFieldsError =>
      'Выберите поле X и от одного до четырёх различных полей Y.';

  @override
  String get genuiChartRecordsError =>
      'Данные графика должны быть списком записей.';

  @override
  String get genuiChartXError =>
      'Значения X должны быть все числами или все текстом. Для точечных диаграмм требуются числа.';

  @override
  String get genuiChartYError =>
      'Поля Y должны существовать и содержать числа или пропущенные значения.';

  @override
  String get genuiChartPieError =>
      'Значения круговой диаграммы должны быть неотрицательными, а итоговая сумма — конечной и больше нуля.';

  @override
  String genuiChartMissingValues(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count значения пропущено; они не заменены нулём.',
      many: '$count значений пропущено; они не заменены нулём.',
      few: '$count значения пропущены; они не заменены нулём.',
      one: '$count значение пропущено; оно не заменено нулём.',
    );
    return '$_temp0';
  }

  @override
  String get genuiChartNoVisibleValues =>
      'У выбранных рядов нет значений для построения.';

  @override
  String genuiChartUnit(String unit) {
    return 'Единица: $unit';
  }

  @override
  String get genuiSomeValuesUnavailable => 'Некоторые значения недоступны';

  @override
  String get genuiViewChart => 'График';

  @override
  String get genuiViewData => 'Данные';

  @override
  String get genuiTableFilterHint => 'Фильтр по видимому тексту';

  @override
  String genuiTableRows(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count строки',
      many: '$count строк',
      few: '$count строки',
      one: '$count строка',
    );
    return '$_temp0';
  }

  @override
  String genuiTablePageInfo(int from, int to, int total) {
    return 'Строки $from–$to из $total';
  }

  @override
  String genuiTablePerPage(int n) {
    return '$n/стр.';
  }

  @override
  String get genuiTableEmpty => 'Нет подходящих строк';

  @override
  String get genuiSortAsc => 'По возрастанию';

  @override
  String get genuiSortDesc => 'По убыванию';

  @override
  String get genuiSortNone => 'Без сортировки';

  @override
  String get genuiValueTrue => 'Да';

  @override
  String get genuiValueFalse => 'Нет';

  @override
  String get genuiTablePreviousPage => 'Предыдущая страница';

  @override
  String get genuiTableNextPage => 'Следующая страница';

  @override
  String get genuiTableCellsError =>
      'Данные таблицы должны содержать записи с конечными скалярными значениями или пропущенными значениями.';

  @override
  String get genuiTableColumnsError =>
      'Выберите от одного до восьми различных полей с заголовками и необязательным числом знаков после запятой от 0 до 10.';

  @override
  String get genuiTableRowKeyError =>
      'Каждой строке нужен скалярный ключ, отличный от null.';

  @override
  String get genuiViewStateFailed =>
      'Это изменение представления превышает лимит сохранённого состояния. Сократите ввод или сбросьте интерфейс и повторите попытку.';

  @override
  String get genuiAttachState => 'Прикрепить текущее состояние';

  @override
  String get genuiChipExactText => 'Точный текст для отправки (зафиксирован)';

  @override
  String get genuiChipStale =>
      'Источник недоступен — удалите или прикрепите снова';

  @override
  String get genuiChipRemove => 'Удалить прикреплённый интерфейс';

  @override
  String get genuiReplaceTitle => 'Заменить прикреплённый интерфейс?';

  @override
  String get genuiReplaceBody =>
      'Черновик может содержать одно состояние интерфейса.';

  @override
  String get genuiReplaceCurrent => 'Текущий';

  @override
  String get genuiReplaceNew => 'Заменить на';

  @override
  String get genuiReplaceConfirm => 'Заменить';

  @override
  String get genuiMergeTitle => 'Добавить в черновик?';

  @override
  String get genuiMergeConfirm => 'Добавить';

  @override
  String get genuiContextEmpty =>
      'Поля параметров или результатов не прикреплены.';

  @override
  String get genuiContextOmitted =>
      '[Некоторые поля или строки данных опущены.]';

  @override
  String get genuiChipOmitted =>
      'Ранее прикреплённое состояние интерфейса недоступно и не было включено.';

  @override
  String get genuiDraftChanged =>
      'Черновик изменился. Попробуйте прикрепить снова.';

  @override
  String get genuiRepairDraft =>
      'Пожалуйста, исправьте этот интерфейс, используя диагностику и фрагменты исходного кода ниже.';

  @override
  String get genuiCopySourceMarkdown => 'Копировать исходник / Markdown';

  @override
  String get genuiTextFailed =>
      'Не удалось прочитать состояние интерфейса. Попробуйте снова.';

  @override
  String get genuiCopyLimit =>
      'Текст превышает лимит копирования 64 КиБ. Выберите меньший фрагмент.';

  @override
  String get genuiExportSnapshot => 'Экспортировать снимок только для чтения';

  @override
  String get genuiExpandedSharedState =>
      'Использует то же состояние, что и сообщение';

  @override
  String get genuiExportTooLarge =>
      'Изображение превышает 16 мегапикселей. Выберите меньше сообщений или экспортируйте меньший интерфейс.';

  @override
  String get genuiWebTitle => 'Веб-предпросмотр';

  @override
  String get genuiWebOpen => 'Открыть';

  @override
  String get genuiWebNotReady => 'Можно открыть после завершения генерации';

  @override
  String get genuiWebInvalidMeta => 'Недопустимый заголовок; не загружено';

  @override
  String get genuiWebSandboxNote =>
      'Предпросмотр в песочнице · отбрасывается при закрытии';

  @override
  String get genuiWebUnsupported =>
      'Веб-предпросмотр не поддерживается на этой платформе. Экспортируйте, чтобы открыть в браузере.';

  @override
  String get genuiWebExportHtml => 'Экспортировать HTML';

  @override
  String get genuiWebInfo => 'Сведения о предпросмотре';

  @override
  String get genuiWebCspNote =>
      'CSP: default-src \'none\' · Ограниченный доступ к сети · Изолированное состояние страницы';

  @override
  String get genuiWebFailed =>
      'Не удалось инициализировать или загрузить предпросмотр. Просмотрите или скопируйте исходный код.';

  @override
  String get genuiWebEmpty => 'После заголовка нет HTML-документа';

  @override
  String get genuiWebBlockLimit =>
      'До 3 веб-предпросмотров на сообщение; остальные показаны как исходный код';

  @override
  String get genuiWebCloseFailed =>
      'Не удалось подтвердить закрытие предыдущего предпросмотра. Перезапустите приложение, прежде чем открывать другой.';

  @override
  String get displaySettingsShowGenUiHeader =>
      'Показывать заголовок интерактивного интерфейса';

  @override
  String get displaySettingsShowGenUiHeaderSubtitle =>
      'Скройте для более чистого сообщения. Исходный код и действия остаются в меню под интерфейсом.';

  @override
  String get genuiClearFilter => 'Сбросить фильтр';

  @override
  String get genuiClearSelection => 'Сбросить выбор';

  @override
  String get chatInputBarQueuedPausedReason =>
      'Сжатие ещё выполняется, поэтому это не отправится автоматически.';

  @override
  String get contextChanged =>
      'Чат изменился. Откройте это снова и подтвердите диапазон, прежде чем продолжить.';

  @override
  String get contextOperationSuperseded => 'Заменено более поздней сводкой';

  @override
  String get compressIncludeAttachments =>
      'Текст вложений и результаты инструментов';

  @override
  String contextEditCharacters(int count) {
    return '$count символов';
  }

  @override
  String get compressOverSnack =>
      'Сводка всё ещё слишком длинная и превысит лимит, поэтому она не была использована. Сожмите ещё раз или переключитесь на модель с большим контекстом.';

  @override
  String get contextSummaryHint =>
      'Это сводка, которую модель увидит в следующий раз. Сохранение изменяет только сводку, а не существующие ответы. Вложения дают только уже извлечённый текст; изображения повторно не распознаются.';

  @override
  String get compressAdvanced => 'Дополнительно';

  @override
  String get compressTaskWaiting => 'Ожидание текущего ответа';

  @override
  String get contextBudgetExceeded =>
      'С этой сводкой следующее сообщение превысит лимит модели. Сократите сводку, сожмите ещё раз или переключитесь на модель с большим контекстом.';

  @override
  String get contextManualSupplement =>
      'Включать вручную изменённые сводки как дополнения';

  @override
  String get contextDetailEdited => 'Изменено вручную';

  @override
  String get contextSourceLabel => 'Источник сводки';

  @override
  String get contextImpactSourceTitle =>
      'Изменить исходный текст, уже включённый в сводку?';

  @override
  String get chatInputBarQueuedCompressionFailed =>
      'Сжатие не удалось, поэтому это сообщение не отправится автоматически.';

  @override
  String contextTokenInfo(int before, int after) {
    return 'Вход сводки ≈ $before токенов → сводка ≈ $after токенов';
  }

  @override
  String get worldBookTransferFailed =>
      'Не удалось сохранить записи. Попробуйте ещё раз.';

  @override
  String contextDetailKeptCount(int count) {
    return 'Последние $count сообщений пользователя, ответы и инструменты';
  }

  @override
  String get toolPermissionRequestApproval => 'Запрашивать подтверждение';

  @override
  String get compressNothingNew =>
      'С прошлого раза нет нового содержимого для сжатия.';

  @override
  String get browserActionScreenshot => 'Сделать снимок экрана';

  @override
  String get displaySettingsPageIosNativeSelectionMenuSubtitle =>
      'Применяется к полю ввода и сообщениям. Отключите, если меню работает медленно.';

  @override
  String contextUndoneSnack(String from, String to) {
    return 'Отменено · $from → $to';
  }

  @override
  String get toolApprovalByFullAccess => 'Выполнено автоматически';

  @override
  String get displaySettingsPageAutoScrollSubtitle =>
      'Во время потоковой передачи автоматически следить за новым содержимым, если вы внизу. Прокрутка вверх приостанавливает слежение до возврата вниз. Если выключено, новое содержимое не прокручивается автоматически.';

  @override
  String get toolApprovalRealTarget => 'Фактическая цель';

  @override
  String get compressTaskRetry => 'Повторить';

  @override
  String get wsDeniedPathOutside =>
      'Цель находится вне разрешённой области. Отказано.';

  @override
  String contextImpactSaveConfirm(int count) {
    return 'Сохранить и отменить следующие связанные операции: $count';
  }

  @override
  String get contextRestore => 'Восстановить';

  @override
  String compressUsageOriginal(String value) {
    return 'было $value';
  }

  @override
  String toolApprovalPendingKind(String kind) {
    return 'Ожидает подтверждения · $kind';
  }

  @override
  String get contextTaskApplying => 'Используется эта сводка';

  @override
  String get storageSpaceImagesHint =>
      'Удаление затрагивает изображения в чатах и результаты инструментов. Используемые аватары и фоны защищены.';

  @override
  String get displaySettingsPageIosNativeSelectionMenuTitle =>
      'Нативное меню выделения iOS 26+';

  @override
  String get worldBookMoveEntries => 'Переместить в…';

  @override
  String get compressReread => 'Вернуться к просмотру сжатых оригиналов';

  @override
  String get chatInputBarQueuedPausedHold =>
      'Отправка приостановлена. Отмените очередь, чтобы изменить или отправить сейчас.';

  @override
  String get contextSummaryTitle => 'Сводка контекста';

  @override
  String get contextKeepInvalid =>
      'Введите положительное число сообщений пользователя.';

  @override
  String get compressTaskAbandon => 'Отменить';

  @override
  String get browserAgentTimedOut => 'Время операции истекло; ИИ приостановлен';

  @override
  String get compressCancelledSnack => 'Отменено. Контекст не изменён.';

  @override
  String get contextImpactClearTitle => 'Отменить предыдущую очистку?';

  @override
  String get compressTaskWaitingApproval => 'Ждём вашего одобрения инструмента';

  @override
  String get contextTaskFailed => 'Сжатие не завершилось';

  @override
  String get wsDeniedSkillsReadonly =>
      'Папка навыков доступна только для чтения.';

  @override
  String get compressTaskMerging => 'Объединение сводок';

  @override
  String get toolPermissionFullAccessDesc =>
      'Позволяет этому чату получать доступ к файлам на этом устройстве, выполнять команды и использовать включённые онлайн-инструменты без запроса каждый раз.';

  @override
  String get compressStaleSnack =>
      'Чат изменился до завершения сжатия, поэтому результат не использован. Сожмите снова, если всё ещё нужно.';

  @override
  String get worldBookCopyEntries => 'Копировать в…';

  @override
  String get contextEditEmpty =>
      'Сводка не может быть пустой. Чтобы не включать ранний чат, используйте «Очистить контекст».';

  @override
  String get toolApprovalDenyWithReason => 'Отклонить с причиной…';

  @override
  String get toolApprovalRequestedPath => 'Запрошенный путь';

  @override
  String get toolApprovalScopeOnce => 'Действует только для этого вызова';

  @override
  String get storageSpaceImageTypeLabel => 'Тип';

  @override
  String get contextImpactUndoTitle => 'Отменить предыдущее сжатие?';

  @override
  String get contextOriginalMessages => 'Просмотреть исходные сообщения';

  @override
  String storageSpaceDeleteImagesConfirmMessage(int count) {
    return 'Удалить изображения ($count)? Связанные изображения чатов, снимки экрана инструментов и копии бесед станут недоступны. Используемые аватары и фоны будут сохранены.';
  }

  @override
  String get chatInputBarQueuedAfterCompress => 'Отправка после сжатия';

  @override
  String get toolPermissionFullAccessDescMobile =>
      'Позволяет этому чату автоматически запускать инструменты в песочнице и авторизованных папках без запроса каждый раз.';

  @override
  String get compressTaskAdjustRetry => 'Изменить параметры и повторить';

  @override
  String get contextDetailLegacy => 'Перенесено из старой очистки';

  @override
  String get contextDetailCurrent => 'Текущий контекст';

  @override
  String get toolPermissionUndo => 'Отменить';

  @override
  String get contextDetailViewOriginals => 'Показать оригиналы';

  @override
  String get contextTaskCompleted => 'Сжатие завершено';

  @override
  String get chatInputBarQueuedPaused => 'Приостановлено';

  @override
  String get contextCompressMarker => 'Контекст сжат';

  @override
  String contextDetailParts(int count) {
    return 'Автоматически разделено на $count частей';
  }

  @override
  String get contextEditPending =>
      'Сохранено. Будет использовано после завершения текущего ответа.';

  @override
  String get contextTaskRetry => 'Повторить сжатие';

  @override
  String get contextUndoCompressTooltip => 'Отменить это сжатие';

  @override
  String get contextDividerCompressed => 'Контекст сжат';

  @override
  String compressSuccessSnack(String from, String to) {
    return 'Контекст сжат · $from → $to';
  }

  @override
  String get contextEffectiveHistory =>
      'Текущая сводка и последующие сообщения';

  @override
  String get compressRereadAll => 'Все оригиналы в сегменте';

  @override
  String get contextDone => 'Готово';

  @override
  String get contextMore => 'Ещё';

  @override
  String compressFailedSnack(String reason) {
    return 'Ошибка сжатия: $reason';
  }

  @override
  String get branchInheritNote =>
      'Новая ветка переносит только сводки и оригиналы, действовавшие до этой точки.';

  @override
  String get contextTaskInterrupted =>
      'Сжатие прервано. Введённый текст сохранён.';

  @override
  String get storageSpaceImageTypeAll => 'Все';

  @override
  String contextRangeInfo(int count, int keep) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count сообщения',
      many: '$count сообщений',
      few: '$count сообщения',
      one: '$count сообщение',
    );
    String _temp1 = intl.Intl.pluralLogic(
      keep,
      locale: localeName,
      other: '$keep последних сообщения пользователя',
      many: '$keep последних сообщений пользователя',
      few: '$keep последних сообщения пользователя',
      one: '$keep последнее сообщение пользователя',
    );
    return 'Заменяет $_temp0; сохраняет $_temp1 и ответы на них.';
  }

  @override
  String contextInputModeInfo(String mode, String source) {
    return 'Ввод сводки: $mode · $source';
  }

  @override
  String get contextDetailKept => 'Сохранено';

  @override
  String worldBookEntriesCopied(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Скопировано $count элемента',
      many: 'Скопировано $count элементов',
      few: 'Скопировано $count элемента',
      one: 'Скопирован $count элемент',
    );
    return '$_temp0';
  }

  @override
  String get toolPermissionSaveFailed =>
      'Не удалось сохранить. Разрешение не изменено.';

  @override
  String get compressDiscardedSnack =>
      'Контекст очищен. Текущее сжатие отменено и не использовано.';

  @override
  String get browserActionSelect => 'Выбрать вариант';

  @override
  String get toolPermissionTitle => 'Разрешения';

  @override
  String get contextDetailNext => 'Следующая отправка';

  @override
  String get contextTaskCancel => 'Отменить сжатие';

  @override
  String get toolPermissionFullAccess => 'Полный доступ';

  @override
  String get chatInputBarQueuedCompressionCancelled =>
      'Сжатие отменено, поэтому это сообщение не отправится автоматически.';

  @override
  String get toolPermissionResetSnack =>
      'Рабочая область изменена · разрешение сброшено на «Запрашивать подтверждение»';

  @override
  String get contextImpactUndoOne => 'Отменить';

  @override
  String get contextDetailContinueNewChat => 'Продолжить в новом чате';

  @override
  String get contextTaskPaused =>
      'Отправка приостановлена. Отмените очередь, чтобы продолжить редактирование.';

  @override
  String get contextTaskReview =>
      'Просмотрите сводку, прежде чем использовать её.';

  @override
  String compressApproxTokens(String value) {
    return 'Прибл. $value токенов';
  }

  @override
  String get storageSpaceImageInUseHint =>
      'Сначала замените или удалите этот аватар, фон или значок в соответствующих настройках, затем удаляйте.';

  @override
  String get compressRereadLastLayer =>
      'Показать оригиналы до последнего сжатия';

  @override
  String get contextRestoreOperation => 'Восстановить операцию';

  @override
  String get contextOriginalHistory =>
      'Перечитать все оригинальные сообщения в этом сегменте';

  @override
  String get contextImpactEditTitle => 'Сохранить эту раннюю сводку?';

  @override
  String get contextOpenNewChat => 'Открыть новый чат';

  @override
  String get wsPathChanged =>
      'Цель изменилась во время ожидания подтверждения.';

  @override
  String get contextEditUnknownPreview =>
      'Сейчас нельзя оценить расход. Он будет проверен ещё раз перед сохранением.';

  @override
  String get contextTaskWait =>
      'Ожидание завершения текущего ответа и инструментов';

  @override
  String compressTaskElapsed(int i, int n, int seconds) {
    return 'Часть $i/$n · прошло $seconds с';
  }

  @override
  String get wsContextChanged => 'Чат изменился, поэтому запрос отменён.';

  @override
  String contextChangeImpact(int count) {
    return 'Это также отменит следующие связанные сжатия или очистки: $count. Исходный чат сохранится. Продолжить?';
  }

  @override
  String get contextImpactSave => 'Сохранить';

  @override
  String contextTaskProgress(int done, int total) {
    return 'Сжатие сегментов $done/$total';
  }

  @override
  String get contextSummaryNotSmaller =>
      'Сводка не короче оригинала. Просмотрите её, прежде чем решить, использовать ли.';

  @override
  String get storageSpaceImageTypeTool => 'Изображения инструментов';

  @override
  String get contextPreviousHistory =>
      'Перечитать оригиналы до последнего сжатия';

  @override
  String get contextDetailRead => 'Что будет фактически прочитано';

  @override
  String get contextViewGenerated => 'Просмотреть созданную сводку';

  @override
  String get contextImpactDeleteDescription =>
      'При удалении этих оригиналов также будут отменены связанные сводки и последующие сжатия, зависящие от них, чтобы удалённое содержимое больше не отправлялось. Остальные сообщения не затронуты.';

  @override
  String get storageSpaceImageTypeAvatar => 'Аватары и фоны';

  @override
  String get contextDetailAfterUndo => 'После отмены';

  @override
  String get contextOperationUndo => 'Отменить эту операцию';

  @override
  String contextHistoryWindowNote(int count) {
    return 'Сохранённая история по-прежнему ограничена окном отправки чата в $count сообщений.';
  }

  @override
  String get contextOverLimitWarning =>
      'После отмены содержимое может превысить лимит модели. Отменить всё равно можно — мы проверим ещё раз перед отправкой. При необходимости сожмите снова.';

  @override
  String get storageSpaceImageTypeChat => 'Изображения чата';

  @override
  String get worldBookSelectEntries => 'Выбрать записи';

  @override
  String get compressUsageSummary => 'Ожидаемая сводка';

  @override
  String contextDetailRange(String from, String to, int count) {
    return 'Сообщения $from–$to · сообщений пользователя: $count';
  }

  @override
  String get contextOperationHidden =>
      'Позже уже была очистка, поэтому это больше не действует.';

  @override
  String get contextUndoClearTooltip => 'Отменить эту очистку';

  @override
  String compressKeepDescription(int count) {
    return 'Сохранить последние сообщения пользователя ($count) вместе с ответами и действиями инструментов. Более ранняя история заменяется сводкой. Сообщения только с вложениями считаются по одному.';
  }

  @override
  String get contextOperationUndone => 'Отменено';

  @override
  String contextEditPreview(String value) {
    return 'Около $value токенов после сохранения. Редактирование не меняет сразу то, что используется сейчас.';
  }

  @override
  String get contextDetailExcluded => 'Исключённая история';

  @override
  String get worldBookNoMoveTargets =>
      'Создайте другую мировую книгу, чтобы переместить в неё записи.';

  @override
  String worldBookSelectedEntries(int count) {
    return 'Выбрано: $count';
  }

  @override
  String get contextDetailReplaced => 'Заменено сводкой';

  @override
  String get displaySettingsPageAutoScrollEnabledLabel => 'Вкл.';

  @override
  String get contextChangeTitle => 'Подтвердите, на что повлияет это изменение';

  @override
  String get contextDetailTitle => 'Сводка';

  @override
  String get compressModelGlobal =>
      'Использует модель из настроек и не меняет её в середине сеанса.';

  @override
  String get wsDeniedMountReadonly => 'Только для чтения. Запись невозможна.';

  @override
  String get compressRereadDesc =>
      'Если чат сжимался несколько раз, это позволит заглянуть в оригиналы, чтобы меньше деталей потерялось. В этот раз будет использовано больше токенов.';

  @override
  String get toolApprovalSwitchToFullAccess => 'Переключить на полный доступ';

  @override
  String get compressUsageInput => 'Вход сводки';

  @override
  String get contextDetailSummaryLabel => 'Сводка, которую модель увидит далее';

  @override
  String get contextImpactDeleteTitle => 'Удалить уже сжатые оригиналы?';

  @override
  String get compressAdvancedOff => 'Просмотр оригиналов: выкл.';

  @override
  String get contextOperationActive => 'Сейчас используется';

  @override
  String get compressAdvancedOn => 'Просмотр оригиналов: вкл.';

  @override
  String get contextTaskMerging => 'Объединение сводок';

  @override
  String contextSampledInfo(int count) {
    return 'Прочитано только выбранных символов: $count; сводка заменит весь выбранный диапазон истории.';
  }

  @override
  String get contextDividerRunning => 'Сжатие контекста';

  @override
  String get contextClearDetails =>
      'С этого момента ранний чат не будет отправляться модели. Системные инструкции ассистента, память и инструменты по-прежнему действуют.';

  @override
  String get compressCopyResult => 'Копировать результат';

  @override
  String get contextDetailInUse => 'Сейчас используется';

  @override
  String get contextImpactDescription =>
      'Связанные сводки будут отменены вместе. Исходный чат сохранится, модель не будет вызвана. Другие несвязанные сводки останутся как есть.';

  @override
  String get compressIncludeAttachmentsDesc =>
      'Включает уже извлечённый текст вложений и полные записи инструментов в исходном порядке. Изображения повторно не распознаются.';

  @override
  String worldBookEntriesMoved(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Перемещено $count записи',
      many: 'Перемещено $count записей',
      few: 'Перемещено $count записи',
      one: 'Перемещена $count запись',
    );
    return '$_temp0';
  }

  @override
  String get contextImpactSourceDescription =>
      'Это изменит исходный текст и отменит сводки, которые его использовали, а также последующие сжатия, зависящие от этих сводок. Другие сообщения не затронуты, модель не будет вызвана.';

  @override
  String get contextEditTitle => 'Редактировать сводку';

  @override
  String get compressUsageNext => 'После применения, при следующей отправке';

  @override
  String get contextSummaryEmpty =>
      'Сводка не может быть пустой. Чтобы не включать предыдущий чат, используйте «Очистить контекст».';

  @override
  String get toolApprovalDenied => 'Отклонено';

  @override
  String get contextDetailModel => 'Модель · время';

  @override
  String compressIncludeManual(int count) {
    return 'Включает $count ваших ручных дополнений';
  }

  @override
  String contextBudgetInfo(int used, String limit) {
    return 'Следующая отправка займёт примерно $used / $limit токенов, включая место для ответа.';
  }

  @override
  String get contextTaskDismiss => 'Закрыть';

  @override
  String contextUndoBudgetInfo(int used) {
    return 'После отмены: примерно $used токенов, включая место для ответа';
  }

  @override
  String get storageSpaceImageInUse => 'Используется';

  @override
  String get worldBookSelectionDone => 'Готово';

  @override
  String get contextDividerFailed => 'Сжатие не завершено';

  @override
  String get toolPermissionUnboundHint =>
      'Рабочая область не привязана: это не включает инструменты файлов или оболочки.';

  @override
  String get contextChangeWaiting =>
      'Это изменение вступит в силу после завершения текущего ответа и работы инструментов.';

  @override
  String storageSpaceDeletedUploadsPartial(int deleted, int kept) {
    return 'Удалено элементов: $deleted; сохранено элементов, которые используются или не могут быть удалены: $kept.';
  }

  @override
  String get contextSourceScopeHint =>
      'Учитывается только история после последней очистки. Она может включать более старые сообщения за пределами обычного окна отправки.';

  @override
  String get contextTaskPreparing => 'Подготовка сжатия';

  @override
  String contextImpactUsage(String from, String to) {
    return 'Примерно $from → $to токенов';
  }

  @override
  String contextImpactConfirm(int count) {
    return 'Также отменить следующие $count связанных операций';
  }

  @override
  String get contextDividerEdited => 'изменено';

  @override
  String get compressAdjust => 'Настроить';

  @override
  String get compressRegenerate => 'Пересжать';

  @override
  String get toolPermissionEnabledSnack =>
      'Полный доступ включён для этого чата';

  @override
  String get contextDetailSuperseded => 'Заменено более поздней сводкой';

  @override
  String get contextTaskQueued => 'В очереди — ожидание сжатия';

  @override
  String get contextNewConversation => 'Создать новый чат со сводкой';

  @override
  String get contextUnknownLimit => 'лимит неизвестен';

  @override
  String get browserErrActionTimeout =>
      'Время операции истекло; результат неизвестен. Проверьте страницу, прежде чем разрешить ИИ продолжить.';

  @override
  String get toolPermissionRequestApprovalDesc =>
      'Kelivo будет запрашивать разрешение перед доступом к файлам вне рабочей области, выполнением команд рабочего стола или использованием других инструментов, требующих одобрения.';

  @override
  String get contextLimitedInputHint =>
      'Читается только выбранный диапазон символов. Остальная часть заменяемой истории не включается в сводку; исходные сообщения остаются доступными.';

  @override
  String get contextTaskCancelled => 'Сжатие отменено';

  @override
  String get contextDetailClearTitle => 'Контекст очищен';

  @override
  String get contextImpactKeep => 'Без изменений';

  @override
  String get contextImpactUndoAlso => 'Также отменяется';

  @override
  String get contextClearMarker => 'Контекст очищен';

  @override
  String get toolPermissionScopeThisChat => 'Только этот чат';

  @override
  String get dataDirectoryTitle => 'Каталог данных';

  @override
  String get dataDirectoryChange => 'Изменить каталог';

  @override
  String get dataDirectoryChoose => 'Выберите пустую локальную папку';

  @override
  String get dataDirectoryHint =>
      'Выберите пустую папку на локальном диске. История чатов, вложения и файлы, управляемые приложением, переместятся после перезапуска. Небольшие настройки устройства и системные кэши останутся в системных расположениях.';

  @override
  String get dataDirectoryPendingHint =>
      'Перемещение запланировано на следующий перезапуск. Текущие данные останутся на месте до завершения копирования и проверки. Назначение:';

  @override
  String get dataDirectoryRestart => 'Перезапустить и переместить данные';

  @override
  String get dataDirectoryCancelMove =>
      'Отменить перемещение и оставить исходный каталог';

  @override
  String get dataDirectoryPreviousHint =>
      'Исходная копия сохранена. После успешного запуска нового каталога можно удалить старую копию, чтобы освободить место на диске. Очистите её перед повторным изменением каталога.';

  @override
  String get dataDirectoryCleanPrevious => 'Очистить исходную копию';

  @override
  String get dataDirectoryCleanConfirm =>
      'Удалить сохранённую копию из указанного ниже каталога? Данные в текущем каталоге будут сохранены. Файлы, изменённые после перемещения, не будут удалены.';

  @override
  String get dataDirectoryMoving =>
      'Перемещение и проверка данных… Пожалуйста, не закрывайте Kelivo.';

  @override
  String get dataDirectoryStartupFailed => 'Не удалось открыть каталог данных';

  @override
  String get dataDirectoryRetry => 'Повторить';

  @override
  String get dataDirectoryUnavailable =>
      'Каталог данных недоступен. Подключите диск заново или восстановите папку в исходном расположении, затем повторите попытку. Пустая база данных создана не будет.';

  @override
  String get dataDirectoryIdentityMismatch =>
      'Эта папка не соответствует настроенному каталогу данных. Восстановите исходную папку и повторите попытку.';

  @override
  String get dataDirectoryNotEmpty =>
      'Выберите пустую папку. Существующие файлы не будут перезаписаны.';

  @override
  String get dataDirectoryOverlap =>
      'Выберите отдельную папку вне текущего каталога данных. Нельзя использовать её родительские папки и корень диска.';

  @override
  String get dataDirectoryLocalOnly =>
      'Выберите папку на локальном диске, а не сетевой ресурс.';

  @override
  String get dataDirectoryFinishPrevious =>
      'Завершите или отмените ожидающее перемещение и удалите сохранённую копию, прежде чем выбирать другой каталог.';

  @override
  String get dataDirectoryPendingRestore =>
      'Ожидается восстановление из резервной копии. Отмените перемещение каталога и перезапустите приложение, чтобы завершить восстановление, затем повторите перемещение.';

  @override
  String get dataDirectorySourceChanged =>
      'Исходные данные изменились после создания копии. Они сохранены. Отмените ожидающее перемещение, прежде чем начинать новое; сохранённые копии можно проверить вручную.';

  @override
  String get dataDirectoryCopyChanged =>
      'В целевом каталоге обнаружены неожиданные или изменённые файлы. Исходные данные сохранены. Проверьте целевой каталог и повторите попытку.';

  @override
  String get dataDirectoryGenericError =>
      'Не удалось завершить операцию. Проверьте свободное место на диске, права доступа к папке и наличие других запущенных процессов Kelivo, затем повторите попытку. Существующие данные сохранены.';

  @override
  String get dataDirectoryCancelHint =>
      'При отмене файлы, уже скопированные в целевой каталог, останутся. Вы можете проверить и удалить эту частичную копию самостоятельно.';

  @override
  String providerDetailPageBaseUrlExample(String url) {
    return 'например, $url';
  }

  @override
  String get providerDetailPageApiKeyExample => 'например, sk-…';

  @override
  String get providerDetailPageRequestUrlLabel => 'URL запроса';

  @override
  String providerDetailPageUrlWillAppendVersion(String v) {
    return 'В URL нет версии; $v будет добавлена при выходе из поля';
  }

  @override
  String providerDetailPageUrlAppendedVersion(String v) {
    return 'Автоматически добавлена $v';
  }

  @override
  String get providerDetailPageUrlTrimmedSlash => 'Удалён завершающий /';

  @override
  String providerDetailPageUrlMovedPath(String path) {
    return 'Обнаружен полный адрес; $path перемещён в «API-путь»';
  }

  @override
  String get providerDetailPageUrlEmptyError =>
      'Требуется для отправки запросов';

  @override
  String get providerDetailPageUrlInvalidError =>
      'Неверный URL; должен начинаться с http:// или https://';

  @override
  String get providerDetailPageRestoreDefaultTooltip =>
      'Восстановить по умолчанию';

  @override
  String get providerDetailPageClearTooltip => 'Очистить';

  @override
  String providerDetailPageTestSuccessWithLatency(String ms) {
    return 'Успешно · $ms мс';
  }

  @override
  String providerDetailPageTestFailedWithCode(String code) {
    return 'Ошибка · $code';
  }

  @override
  String providerDetailPageTestHintMissingVersion(String url) {
    return 'Возможно, в URL отсутствует версия; попробуйте $url';
  }

  @override
  String providerAutoVersionAdded(String v) {
    return 'Автоматически добавлена $v';
  }

  @override
  String get providerUndo => 'Отменить';

  @override
  String get sidePanelToggle => 'Показать / скрыть боковую панель';

  @override
  String get sidePanelFiles => 'Файлы';

  @override
  String get sidePanelTopics => 'Темы';

  @override
  String get sidePanelExpand => 'Развернуть панель';

  @override
  String get sidePanelCollapse => 'Выйти из развёрнутого режима';

  @override
  String get sidePanelAllTabs => 'Все вкладки';

  @override
  String sidePanelMoreTabs(int count) {
    return 'ещё $count';
  }

  @override
  String get sidePanelSearchTabs => 'Поиск вкладок';

  @override
  String get sidePanelOpenFile => 'Открыть файл…';

  @override
  String get sidePanelCloseOthers => 'Закрыть другие вкладки';

  @override
  String get sidePanelCloseRight => 'Закрыть вкладки справа';

  @override
  String get sidePanelReopenTab => 'Открыть закрытую вкладку';

  @override
  String get sidePanelPinned => 'Закреплено · нельзя закрыть';

  @override
  String get sidePanelMoveTopicsLeft => 'Вернуть темы влево…';

  @override
  String get sidePanelPinnedHint =>
      'Темы закреплены, пока находятся справа. Измените это в разделе Настройки › Отображение › Положение тем.';

  @override
  String get sidePanelEvictedTitle => 'Страница выгружена';

  @override
  String sidePanelEvictedBody(int count) {
    return 'Выгружена в фоне для экономии памяти (сохраняется до $count фоновых страниц). Перезагрузите, чтобы продолжить просмотр.';
  }

  @override
  String get sidePanelEvictedTooltip =>
      'Выгружена · перезагрузите, чтобы продолжить';

  @override
  String get sidePanelFileMissing => 'Файл недоступен';

  @override
  String sidePanelFileMissingBody(String path) {
    return '$path был удалён или перемещён.';
  }

  @override
  String get sidePanelRelocate => 'Найти снова';

  @override
  String sidePanelBackgroundIn(String topic) {
    return 'Работает в «$topic»';
  }

  @override
  String sidePanelWidth(int px) {
    return '${px}px';
  }

  @override
  String get sidePanelWidthMax => 'макс.';

  @override
  String get sidePanelWidthMin => 'мин.';

  @override
  String get sidePanelRecentFiles => 'Недавние результаты и вложения';

  @override
  String get sidePanelOpenExternalUrl => 'Открыть URL в системном браузере…';

  @override
  String get sidePanelWebPages => 'Веб-страницы';

  @override
  String get hotkeyToggleSidePanel => 'Показать / скрыть боковую панель';

  @override
  String get hotkeySidePanelNewWeb => 'Новая веб-вкладка';

  @override
  String get hotkeySidePanelFiles => 'Показать файлы';

  @override
  String get hotkeySidePanelExpand => 'Развернуть боковую панель';

  @override
  String get hotkeySidePanelReopenTab => 'Открыть закрытую вкладку';

  @override
  String get hotkeySidePanelNextTab => 'Следующая вкладка панели';

  @override
  String get hotkeySidePanelPreviousTab => 'Предыдущая вкладка панели';

  @override
  String get hotkeySidePanelAddress => 'Фокус на адресной строке';

  @override
  String get hotkeySidePanelFocus => 'Переключить фокус между чатом и панелью';

  @override
  String get selectionQuote => 'Цитировать';

  @override
  String selectionQuoteMarker(int index) {
    return '[Цитата $index]';
  }

  @override
  String get selectionTranslate => 'Перевести';

  @override
  String get selectionAiTranslateIos => 'ИИ-перевод';

  @override
  String get selectionCopyMarkdown => 'Копировать как Markdown';

  @override
  String get selectionCopyRich => 'Копировать форматированный текст';

  @override
  String get quoteJumpToSource => 'Перейти к источнику';

  @override
  String get quoteRemove => 'Удалить цитату';

  @override
  String get quoteDuplicate => 'Уже в цитатах';

  @override
  String get quoteLimit => 'Не более 10 цитат в сообщении';

  @override
  String get quoteLocated => 'Переход к цитируемому тексту';

  @override
  String get quoteSourceMissing => 'Источник больше не существует';

  @override
  String get selectionRegenerate => 'Сгенерировать заново';

  @override
  String get translating => 'Перевод…';

  @override
  String get retry => 'Повторить';

  @override
  String get recoveryGuideTitle => 'Восстановим ваши чаты';

  @override
  String get recoveryGuideBody =>
      'Kelivo приостановил загрузку данных. Мы поищем локальные копии, чтобы вы могли выбрать, что восстановить. Существующие файлы будут сохранены.';

  @override
  String get recoverySpaceTitle => 'Требуется свободное место';

  @override
  String get recoveryChecksNeedSpace =>
      'Локальные копии найдены, но для их проверки недостаточно места. Это не значит, что они повреждены. Освободите место и проверьте снова.';

  @override
  String get recoveryChecksUnavailable =>
      'Некоторые локальные копии пока не удалось проверить. Их файлы по-прежнему доступны. Проверьте снова или экспортируйте данные для помощи.';

  @override
  String get recoveryRecheckCopies => 'Проверить локальные копии снова';

  @override
  String get recoveryCopyPreview => 'Предпросмотр копии';

  @override
  String get recoveryRestoreRetryBody =>
      'Восстановление не завершено. Выбранная копия сохранена. Проверьте локальные копии снова или перезапустите Kelivo, чтобы продолжить.';

  @override
  String recoverySpaceAmount(String required, String available) {
    return 'Последняя проверка: доступно $available; для безопасной подготовки данных требуется не менее $required свободного места.';
  }

  @override
  String get recoveryCopiesNeedUpdate =>
      'Некоторые копии созданы более новой версией Kelivo. Обновите Kelivo перед их восстановлением. Эти копии сохранены.';

  @override
  String get imageContextAllowRecall =>
      'Разрешить модели вспоминать изображения';

  @override
  String get imageContextAllowRecallDescription =>
      'Разрешить view_image при необходимости извлекать исторические изображения из этого чата. Отключение не влияет на изображения, отправленные напрямую с сообщениями, автоматическое управление изображениями или доступ к файлам рабочей области.';

  @override
  String get imageContextTitle => 'Контекст изображений';

  @override
  String get imageContextAutomatic =>
      'Автоматически управлять историческими изображениями';

  @override
  String get imageContextDescription =>
      'Управление изображениями, используемыми в этом ходе. Оригиналы остаются в чате.';

  @override
  String get imageContextIncluded => 'Включено';

  @override
  String get imageContextOmitted => 'Не включено';

  @override
  String get imageContextPin => 'Закрепить изображение';

  @override
  String get imageContextUnpin => 'Открепить изображение';

  @override
  String get imageContextAttachAgain => 'Снова добавить в поле ввода';

  @override
  String get imageContextEmpty => 'Изображений пока нет';

  @override
  String get imageContextUnavailable =>
      'Это изображение недоступно в текущем контексте.';

  @override
  String get imageContextEntryDescription =>
      'Просмотр и управление изображениями для этого хода';

  @override
  String get imageContextAutomaticDescription =>
      'Дольше сохранять ваши вложения и откладывать более старые изображения инструментов.';

  @override
  String get imageContextActionsHint =>
      'Закрепите, чтобы отдать приоритет изображению, или снова добавьте его в поле ввода.';

  @override
  String get imageContextEmptyDescription =>
      'Отправленные вами изображения или изображения, прочитанные инструментами, появятся здесь.';

  @override
  String get imageContextUserImages => 'Ваши изображения';

  @override
  String get imageContextToolImages => 'Изображения инструментов';

  @override
  String get imageContextAssistantImages => 'Сгенерированные изображения';

  @override
  String imageContextImageNumber(int index) {
    return 'Изображение $index';
  }

  @override
  String imageContextIncludedCount(int included, int total) {
    return 'Включено изображений: $included из $total';
  }

  @override
  String get imageContextMissing => 'Недоступно';

  @override
  String get imageContextLoadFailed =>
      'Не удалось загрузить изображения. Попробуйте ещё раз.';

  @override
  String get imageContextUpdateFailed =>
      'Не удалось сохранить изменения. Попробуйте ещё раз.';

  @override
  String get contextOperationsTitle => 'Сжатие и очистка истории';

  @override
  String get contextOperationsLoadMore => 'Показать ещё';

  @override
  String get contextOperationsDescription =>
      'Просматривайте сжатия и очистки, при необходимости отменяйте их.';

  @override
  String get contextOperationsEmpty => 'Пока нет сжатий или очисток.';

  @override
  String contextOperationsStored(int count) {
    return 'Сохранённый чат: сообщений — $count';
  }

  @override
  String contextOperationsEffective(int summaries, int messages) {
    return 'Следующая отправка включит сводок: $summaries, исходных сообщений: $messages.';
  }

  @override
  String get contextOperationsScope =>
      'Учитывается текущий лимит длины истории. Системные инструкции, память, инструменты и неотправленный ввод также добавляются в контекст. Откройте запись, чтобы просмотреть сводку, исходный диапазон или отменить её.';

  @override
  String get contextOperationsLoadFailed =>
      'Не удалось загрузить эти записи. Попробуйте ещё раз.';

  @override
  String get compressNewConversation => 'Сжать в новый чат';

  @override
  String get compressNewConversationDescription =>
      'Если включено, создаётся новый чат со сводкой и сохранёнными сообщениями, а исходный чат остаётся без изменений. Если выключено, сжатие выполняется в этом чате.';

  @override
  String get contextViewBoundary => 'Перейти к месту очистки контекста';

  @override
  String get contextFixedStart => 'Фиксированное начало контекста';

  @override
  String get contextSetFixedStart => 'Начать контекст здесь';

  @override
  String get contextCancelFixedStart =>
      'Отменить фиксированное начало контекста';

  @override
  String get contextFixedStartDescription =>
      'Отправлять историю начиная с этого сообщения, без скользящего лимита количества сообщений.';

  @override
  String get contextBeforeFixedStart =>
      'Это сообщение находится до фиксированного начала контекста. Переместите или отмените начало, прежде чем генерировать его заново.';

  @override
  String get contextRegenerateFixedStart =>
      'Этот ответ является фиксированным началом контекста, поэтому его вопрос исключён. Переместите начало на более раннее сообщение или отмените его, прежде чем генерировать заново.';

  @override
  String get responseSpeedLabel => 'Скорость ответа';

  @override
  String get responseSpeedStandard => 'Стандартная';

  @override
  String get responseSpeedUsageHint =>
      'Ускоренные режимы расходуют больше квоты или кредитов.';

  @override
  String get responseSpeedLoading => 'Проверка доступности…';

  @override
  String get responseSpeedUnavailable =>
      'Для этой модели нет доступного уровня ускорения.';

  @override
  String get responseSpeedSaveFailed =>
      'Не удалось сохранить скорость ответа. Попробуйте ещё раз.';

  @override
  String responseSpeedRequestFailed(String mode) {
    return 'Запрос в режиме $mode не удался. Проверьте доступность модели и аккаунта или переключитесь на стандартный режим и повторите попытку.';
  }

  @override
  String get responseSpeedSelectionUnavailable =>
      'Сохранённая скорость больше недоступна. Этот чат будет использовать стандартный режим.';

  @override
  String get responseSpeedProviderDependent =>
      'Доступность зависит от вашего провайдера.';

  @override
  String responseSpeedTapTo(String mode) {
    return 'Нажмите, чтобы переключиться на $mode';
  }

  @override
  String get responseSpeedUltrafastNeedsResponses =>
      'Для UltraFast требуется Responses API.';

  @override
  String get compressionTemplate => 'Шаблон сводки';

  @override
  String get compressionGeneral => 'Общий';

  @override
  String get compressionCode => 'Код';

  @override
  String get compressionWriting => 'Текст';

  @override
  String get compressionResearch => 'Исследование';

  @override
  String get compressionRoleplay => 'Ролевая игра';

  @override
  String get compressionOriginalPrompt => 'Мой исходный промпт';

  @override
  String get compressionMore => 'Дополнительные настройки';

  @override
  String get compressionFocus => 'На чём сделать акцент в этот раз';

  @override
  String get compressionFocusHint =>
      'Необязательно: ключевые решения, прогресс или детали персонажей';

  @override
  String get compressionForConversation => 'Для этого чата';

  @override
  String get compressionFollowGlobal =>
      'Следовать глобальным настройкам по умолчанию';

  @override
  String get compressionSetGlobal =>
      'Сделать глобальными настройками по умолчанию';

  @override
  String get compressionGlobalDescription =>
      'Влияет только на чаты, использующие глобальные настройки по умолчанию. Чаты с собственными настройками не изменяются.';

  @override
  String get compressionAutoTitle => 'Автоматическое сжатие';

  @override
  String get compressionAutoOff => 'Выкл.';

  @override
  String get compressionAutoNotify => 'Только уведомлять';

  @override
  String get compressionAutoOn => 'Автоматически';

  @override
  String get compressionNearLimit =>
      'Этот чат близок к пределу, который может удержать модель. Можно продолжать отправлять сообщения или сначала сжать.';

  @override
  String get compressionKeepTurns => 'Сохранять последние';

  @override
  String get compressionKeepHint =>
      'Один ход — это одно сообщение пользователя плюс следующие за ним ответы и действия инструментов.';

  @override
  String get compressionLength => 'Длина сводки (токены)';

  @override
  String get compressionTrigger => 'Начинать при';

  @override
  String get compressionTarget => 'Сжимать до';

  @override
  String get compressionWindow => 'Ёмкость модели сводки';

  @override
  String get compressionRequests => 'Максимум запросов';

  @override
  String get compressionReference =>
      'Учитывать книги мира и историческую память';

  @override
  String get compressionReferenceHint =>
      'Мировые книги сопоставляются только с историей, которая сжимается, с использованием снимков памяти того времени. Это нужно только для объяснения имён и правил — это не означает, что те события произошли или что персонаж уже о них знает.';

  @override
  String get compressionToolReferences =>
      'Оставлять только ссылки на уже прочитанные результаты инструментов';

  @override
  String get compressionToolReferencesHint =>
      'Применяется только при доступных инструментах. Последние непрочитанные результаты сохраняются полностью. Уже прочитанные результаты сохраняются как ссылки — их можно просмотреть, но нельзя редактировать.';

  @override
  String get compressionSummaryScan =>
      'Также сопоставлять ключевые слова мировых книг со сводкой';

  @override
  String get compressionChatModel => 'Следовать текущей модели чата';

  @override
  String get compressionManageTemplates => 'Управление шаблонами и рецептами';

  @override
  String get compressionLocalPreview =>
      'Предпросмотр запроса · без вызова модели';

  @override
  String get compressionTry => 'Попробовать сводку · расходует токены модели';

  @override
  String get compressionPreviewOnly =>
      'Это создаёт только предварительный просмотр. Используйте его после проверки.';

  @override
  String get compressionTemplateChanged =>
      'Новый шаблон применяется только к будущим сводкам. Уже созданные сводки остаются как есть. Чтобы восстановить детали, пересоздайте их из оригиналов.';

  @override
  String compressionRange(int count, int turns) {
    return 'Сжать $count сообщений · сохранить $turns раундов дословно';
  }

  @override
  String compressionCalls(int count) {
    return 'Запросов к модели: $count';
  }

  @override
  String get compressionActualUsage => 'Фактический расход модели сводки';

  @override
  String compressionUsageValues(String input, String output) {
    return 'Ввод $input · вывод $output токенов';
  }

  @override
  String compressionUsageUnknown(int count) {
    return 'Для $count запросов не вернулись данные об использовании. Это не значит, что они были бесплатными.';
  }

  @override
  String get compressionBudgetError =>
      'Для этого потребуется больше запросов к модели, чем позволяет текущий лимит, поэтому контекст не изменён. Увеличьте «Максимум запросов» или переключитесь на модель с большим контекстом.';

  @override
  String get compressionIncomplete =>
      'Сводка была обрезана или отклонена, контекст не изменён. Увеличьте лимит вывода или попробуйте другую модель.';

  @override
  String get compressionReferenceTooLarge =>
      'Справочные материалы уже занимают всю ёмкость этой модели, и для сводки не остаётся места. Используйте меньше справочных материалов или переключитесь на модель с большим контекстом.';

  @override
  String get compressionReferenceChanged =>
      'Используемый справочный фон изменился. Проверьте эту сводку или создайте новую.';

  @override
  String get compressionTargetNotReached =>
      'Даже после сжатия использование всё ещё будет выше порога автоматического запуска, поэтому исходный контекст сохранён. Сократите сводку или увеличьте «Запускать при».';

  @override
  String get compressionTemplateMissing =>
      'Выбранный шаблон недоступен. Пожалуйста, выберите другой.';

  @override
  String get compressionTemplates => 'Шаблоны';

  @override
  String get compressionRecipes => 'Рецепты';

  @override
  String get compressionNewTemplate => 'Новый шаблон';

  @override
  String get compressionEditTemplate => 'Изменить шаблон';

  @override
  String get compressionRestoreDefault => 'Восстановить значения по умолчанию';

  @override
  String get compressionCopyEdit => 'Копировать и изменить';

  @override
  String get compressionTemplateName => 'Название';

  @override
  String get compressionPrompt => 'Инструкции для сводки';

  @override
  String get compressionLanguage => 'Язык вывода';

  @override
  String get compressionLanguageConversation => 'Как в чате';

  @override
  String get compressionLanguageLegacy =>
      'Сохранить языковую настройку исходного шаблона';

  @override
  String get compressionLanguageHint =>
      'Введите название или код языка. Также можно указать conversation (следовать за чатом) или legacy (сохранить исходный шаблон).';

  @override
  String get compressionVariables =>
      'Можно использовать эти переменные. Если в промпте нет истории, она будет добавлена автоматически:';

  @override
  String get compressionDeleteTemplate =>
      'Выбрать замену и удалить этот шаблон? Уже используемые сводки и копии, сохранённые в рецептах, останутся.';

  @override
  String compressionTemplateReferences(int count) {
    return 'Используется как переопределение для отдельных чатов: $count.';
  }

  @override
  String get compressionSaveRecipe => 'Сохранить эти настройки как рецепт';

  @override
  String get compressionBindModel =>
      'Также сохранить выбранную сейчас модель для сводок';

  @override
  String get compressionRecipeHint =>
      'Сохранение или импорт рецепта не включает автоматическое сжатие и не применяет его к текущему чату. Рецепт только добавляется в библиотеку.';

  @override
  String get compressionImport => 'Импорт JSON';

  @override
  String get compressionExport => 'Экспорт JSON';

  @override
  String get compressionCopyJson => 'Копировать JSON';

  @override
  String get compressionApplyRecipe => 'Применить рецепт';

  @override
  String get compressionInvalidSettings =>
      'Проверьте значения: «Сжимать до» должно быть меньше «Запускать при», а лимиты запросов и токенов должны быть больше 0.';

  @override
  String get compressionOverflowAction =>
      'Сжать один раз, затем повторить неудачный ответ';

  @override
  String compressionPlannedCalls(int count, int limit) {
    return 'Ожидается запросов: $count · лимит $limit, включая повторы';
  }

  @override
  String get compressionGlobalTemplateReference =>
      'Также используется как глобальный шаблон по умолчанию.';

  @override
  String compressionRecipeReferences(int count) {
    return 'Рецептов, сохраняющих собственную копию шаблона на тот момент: $count.';
  }

  @override
  String get compressionReplacementTemplate => 'Заменяющий шаблон';

  @override
  String get compressionGeneralDescription =>
      'Текущая тема, решения и открытые вопросы.';

  @override
  String get compressionCodeDescription =>
      'Изменения кода, фактические проверки и следующий шаг разработки.';

  @override
  String get compressionWritingDescription =>
      'Принятый текст, структура, стиль и требования к редактированию.';

  @override
  String get compressionResearchDescription =>
      'Доказательства, источники, измерения и неопределённость.';

  @override
  String get compressionRoleplayDescription =>
      'Непрерывность сцены, состояние персонажей и кто что знает.';

  @override
  String compressionLastUsed(String date) {
    return 'Последнее использование: $date';
  }

  @override
  String get compressionManage => 'Управление';

  @override
  String get compressionOutputSettings => 'Настройки сводки';

  @override
  String get compressionSourceSettings => 'Ссылки и исходный текст';

  @override
  String get compressionSavedSettings => 'Предпросмотр и сохранённые настройки';

  @override
  String get compressionNoRecipes => 'Сохранённых рецептов пока нет';

  @override
  String get compressionNoTemplatesFound => 'Подходящих шаблонов нет';

  @override
  String get compressionBuiltIn => 'Встроенные';

  @override
  String get compressionGlobalDefault => 'Глобальный по умолчанию';

  @override
  String get compressionCustomLanguage => 'Другой язык';

  @override
  String get compressionCustomLanguageHint =>
      'Название или код языка, например Japanese / ja';

  @override
  String get compressionLibraryTitle => 'Шаблоны и рецепты';

  @override
  String get compressionBuiltInTemplates => 'Встроенные шаблоны';

  @override
  String get compressionMyTemplates => 'Мои шаблоны';

  @override
  String get compressionSearchTemplates => 'Поиск шаблонов';

  @override
  String get compressionSearchRecipes => 'Поиск рецептов';

  @override
  String get compressionRecipeCreateHint =>
      'Сохраните рецепт в разделе «Дополнительные настройки», чтобы повторно использовать конфигурацию.';

  @override
  String get compressionTurnUnit => 'ходов';

  @override
  String get compressionCallUnit => 'вызовов';

  @override
  String get compressionRequestTimeout => 'Тайм-аут запроса сжатия';

  @override
  String get compressionMinuteUnit => 'мин';

  @override
  String get compressionRequestTimeoutDefault => 'По умолчанию';

  @override
  String get compressionRequestTimeoutHint =>
      'Введите число минут больше 0. Оставьте пустым, чтобы сохранить текущее значение по умолчанию (5 минут для серверного сжатия). При сжатии по частям каждая часть и объединение учитываются отдельно.';

  @override
  String compressionRequestTimedOut(num minutes) {
    return 'Сжатие остановлено после $minutes мин, контекст не изменён. Попробуйте снова или увеличьте тайм-аут.';
  }

  @override
  String get compressionAdvancedOptions => 'Детали сжатия';

  @override
  String get compressionAdvancedHint =>
      'Справочные материалы, повторное обращение к оригиналам и лимит запросов';

  @override
  String get compressionAutomaticWindow => 'Авто';

  @override
  String get compressionAutoOffHint => 'Сжимайте вручную, когда потребуется.';

  @override
  String get compressionAutoNotifyHint =>
      'Вы получите уведомление, когда использование приблизится к лимиту, а когда сжимать — решаете вы.';

  @override
  String get compressionAutoOnHint =>
      'Когда использование достигает заданного процента, ранняя история автоматически сворачивается в сводку. Это дополнительно расходует токены модели.';

  @override
  String get compressionBudgetHint =>
      'Эти проценты рассчитываются от доступной ёмкости ввода.';

  @override
  String get compressionPreviewAction => 'Локальный предпросмотр';

  @override
  String get compressionSaveRecipeAction => 'Сохранить рецепт';

  @override
  String get compressionManualRange => 'Область этого сжатия';

  @override
  String get compressionScopeKeepHint =>
      'Последние ходы сохраняются как есть, более ранняя история сворачивается в сводку. Автоматическое сжатие использует то же число ходов.';

  @override
  String get compressionScopeAllHint =>
      'Свернуть в сводку всю историю, которая сейчас в контексте, не сохраняя отдельно недавние оригиналы. Исходные сообщения по-прежнему можно просмотреть.';

  @override
  String get compressionScopeStartHint =>
      'В пределах лимита символов сжимаются более ранние полные сообщения. Невыбранные сообщения остаются исходным текстом.';

  @override
  String get compressionScopeRecentHint =>
      'В пределах лимита символов сжимаются более поздние полные сообщения. Невыбранные сообщения остаются исходным текстом.';

  @override
  String get compressionAutoKeepHint =>
      'Автоматическое сжатие всегда сохраняет недавние оригиналы независимо от диапазона, выбранного для ручного запуска. Число ходов общее с ручным сжатием.';

  @override
  String get requestBudgetTitle => 'Лимиты изображений и запросов';

  @override
  String get requestBudgetInherited => 'Унаследовано';

  @override
  String get requestBudgetCustom => 'Свои значения';

  @override
  String get requestBudgetReset => 'Сбросить';

  @override
  String get requestBudgetSingleImage => 'Одно изображение (МиБ)';

  @override
  String get requestBudgetTotalImages => 'Все изображения (МиБ)';

  @override
  String get requestBudgetImageCount => 'Количество изображений';

  @override
  String get requestBudgetBody => 'Тело запроса (МиБ)';

  @override
  String get requestBudgetProviderHelp =>
      'Это локальные проверки перед отправкой, а не лимиты провайдера. Оставьте поле пустым, чтобы использовать значение по умолчанию. Размер изображений учитывает кодирование Base64; размер запроса включает полное тело JSON.';

  @override
  String get requestBudgetModelHelp =>
      'Переопределяет локальные лимиты отправки для этой модели. Пустые поля наследуют настройки провайдера, указанные в подсказке. Размер изображений учитывает кодирование Base64; размер запроса включает полное тело JSON.';

  @override
  String get requestBudgetRetentionHelp =>
      'Увеличение этих лимитов не увеличивает автоматическое сохранение изображений в истории. Закрепляйте изображения, чтобы сохранить их. Большие лимиты могут увеличить расход памяти устройства.';

  @override
  String get requestBudgetInvalid =>
      'Введите положительные размеры и положительное целое количество изображений или оставьте поля пустыми для наследования.';

  @override
  String requestBudgetBytes(String mib, int bytes) {
    return '$mib МиБ ($bytes байт)';
  }

  @override
  String requestBudgetSingleError(int index, String actual, String limit) {
    return 'Локальная проверка Kelivo: изображение $index после кодирования занимает $actual, что превышает лимит одного изображения $limit.';
  }

  @override
  String requestBudgetTotalError(String actual, String limit) {
    return 'Локальная проверка Kelivo: изображения после кодирования в сумме занимают $actual, что превышает лимит изображений $limit.';
  }

  @override
  String requestBudgetCountError(String actual, int limit) {
    return 'Локальная проверка Kelivo: запрос содержит изображений ($actual), что превышает лимит $limit.';
  }

  @override
  String requestBudgetBodyError(String actual, String limit) {
    return 'Локальная проверка Kelivo: полное тело запроса занимает $actual, что превышает лимит запроса $limit.';
  }

  @override
  String get requestBudgetPinnedError => 'Это изображение закреплено.';

  @override
  String get requestBudgetImageHint =>
      'Откройте «Контекст изображений», чтобы просмотреть включённые изображения и закрепления. Уменьшите размер или количество изображений, открепите старые изображения или измените лимит в настройках провайдера/модели.';

  @override
  String get requestBudgetBodyHint =>
      'Сократите или сожмите чат, включая результаты инструментов, или измените лимит тела запроса в настройках провайдера/модели.';

  @override
  String imageContextEncodedSize(String size) {
    return '$size МиБ после кодирования';
  }

  @override
  String get imageContextPinned => 'Закреплено';

  @override
  String get imageContextSizeUnknown => 'Размер проверяется при отправке';

  @override
  String requestBudgetAtLeast(String value) {
    return 'не менее $value';
  }

  @override
  String get compressionNativeTitle => 'Использовать серверное сжатие OpenAI';

  @override
  String get compressionNativeHint =>
      'Используется текущая модель чата, сжатие выполняется на сервере. Если в этом чате включено автоматическое сжатие, оно тоже будет использовать этот способ. Ваш провайдер должен поддерживать Responses API OpenAI.';

  @override
  String get compressionNativeScopeHint =>
      'Последние ходы сохраняются как есть, более ранняя история отправляется на серверное сжатие. Автоматическое серверное сжатие использует то же число; число ходов для текстовых сводок не меняется.';

  @override
  String get compressionNativeLabel => 'Серверное сжатие';

  @override
  String get compressionNativeDescription =>
      'Результат сжатия с сервера сохранён локально и будет использоваться при следующей отправке. Его нельзя просмотреть или изменить как текст. Исходные сообщения сохранены, и это сжатие можно отменить.';

  @override
  String get compressionNativeIncomplete =>
      'Сервер не вернул полный результат сжатия. Исходный контекст не изменён.';

  @override
  String get compressionNativeScopeChanged =>
      'Этот серверный результат относится к другому подключению или аккаунту. Вернитесь к исходному подключению, чтобы продолжить, или отмените это сжатие в чате, где ещё есть оригиналы, и создайте текстовую сводку.';

  @override
  String get compressionNativeTokenHint =>
      'Использование токенов для серверного сжатия определяется сервером.';

  @override
  String get compressionNativeCopyHint =>
      'Новый чат сохранит только полный серверный результат и оставленные вами недавние ходы. Оригиналы остаются в исходном чате, и отмена здесь их не восстановит.';

  @override
  String get compressionNativeInputOverride =>
      'Пользовательский параметр input в настройках модели или ассистента перезапишет результат серверной обработки. Удалите этот параметр, чтобы продолжить.';

  @override
  String get compressionNativeAllHint =>
      'Отправить всю текущую историю на серверную обработку, не сохраняя отдельно недавние оригиналы. Исходные сообщения по-прежнему можно просмотреть.';

  @override
  String get compressionNativeAutoHint =>
      'Когда использование достигнет заданного процента, текущая модель чата выполнит серверную обработку, после чего отправка продолжится. При сбое исходный контекст сохраняется, и приложение не переключится на текстовое резюме.';

  @override
  String get languageDisplayRussian => 'Русский';

  @override
  String get languageDisplayTurkish => 'Турецкий';

  @override
  String sideDrawerDeleteConfirmContent(String title) {
    return 'Удалить «$title»?';
  }

  @override
  String get backupPageCherryImportWarning =>
      'Эта функция экспериментальная. Она импортирует ассистентов, чаты, провайдеров и файлы. Некоторым провайдерам требуется /v1 или /v1beta в конце базового URL. Перед импортом создайте резервную копию данных. Продолжить выбор файла?';

  @override
  String get themePaletteDefault => 'По умолчанию';

  @override
  String get themePaletteBlue => 'Небесно-синий';

  @override
  String get themePaletteGreen => 'Бамбуково-зелёный';

  @override
  String get themePalettePurple => 'Сумеречно-фиолетовый';

  @override
  String get themePaletteYellow => 'Янтарно-золотой';

  @override
  String get themePaletteSmokyRose => 'Дымчатая роза';

  @override
  String get themePaletteTerracotta => 'Терракотовая глина';

  @override
  String get themePaletteMonochrome => 'Морозный серый';

  @override
  String get themePaletteDocument => 'Мятно-зелёный';

  @override
  String get themePaletteCustom => 'Пользовательская';

  @override
  String get compressionNativeImported =>
      'Результат серверной обработки загружен';

  @override
  String get compressionNativeImportedDescription =>
      'Этот чат начинается с результата серверной обработки и последних реплик. Результат нельзя просмотреть или изменить как текст. Более ранние оригиналы остаются в исходном чате, и их нельзя восстановить отменой здесь.';

  @override
  String get compressionNativeOpenSource => 'Открыть исходный чат';

  @override
  String get compressionNativeOriginalsUnavailable =>
      'В этом чате нет оригиналов для загруженного результата серверной обработки. Вы можете продолжить использовать серверную обработку или вернуться в исходный чат, чтобы просмотреть оригиналы или создать текстовое резюме.';

  @override
  String get compressionNativeTemporaryCopyHint =>
      'Новый временный чат сохранит только полный результат серверной обработки и последние реплики. Когда вы покинете исходный временный чат, он и все неперенесённые оригиналы будут удалены и не смогут быть восстановлены здесь.';

  @override
  String get compressionNativeSourceUnavailable =>
      'В этом чате сохранены полный результат серверной обработки и оставленные последние реплики. Исходный чат больше недоступен. Оригиналы, не скопированные сюда, нельзя восстановить, а результат нельзя просмотреть или изменить как текст.';

  @override
  String get modelDetailSheetImageGenerationModel => 'Модель изображений';

  @override
  String get modelDetailSheetImageGenerationAuto => 'Авто';

  @override
  String get modelDetailSheetImageGenerationComplexity =>
      'Сложность изображения';

  @override
  String get modelDetailSheetImageGenerationComplexityDefault => 'По умолчанию';

  @override
  String get modelDetailSheetImageGenerationComplexityLow => 'Низкая';

  @override
  String get modelDetailSheetImageGenerationComplexityMedium => 'Средняя';

  @override
  String get modelDetailSheetImageGenerationComplexityHigh => 'Высокая';

  @override
  String get modelDetailSheetImageGenerationComplexityDescription =>
      'Управляет планированием изображения отдельно от рассуждений чата. «По умолчанию» использует поведение сервера и может наследовать уровень рассуждений чата.';

  @override
  String get modelDetailSheetImageGenerationOAuthHint =>
      'Вход через ChatGPT может использовать другую модель изображений. Настройки модели и сложности зависят от поддержки сервера.';

  @override
  String get imageGenerationComplexityErrorHint =>
      'Установите рассуждения чата в «Авто», а сложность изображения — в «По умолчанию», затем повторите генерацию изображения. Вход через ChatGPT может использовать другую модель изображений или отклонять явную сложность.';

  @override
  String get workspaceEnvNativeShellTitle => 'Оболочка по умолчанию';

  @override
  String get workspaceEnvNativeShellHint =>
      'Оставьте пустым для автоматического определения. Иначе укажите абсолютный путь к PowerShell, cmd или оболочке, поддерживающей -lc (например, bash, zsh или fish). Эта настройка применяется только к этому устройству.';

  @override
  String get workspaceEnvNativeShellInvalid =>
      'Не удалось запустить эту оболочку. Проверьте абсолютный путь и поддерживаемый синтаксис команд.';

  @override
  String get workspaceEnvNativeShellUnavailable => 'Оболочка недоступна';

  @override
  String get workspaceEnvNativeShellDetect => 'Определить снова';

  @override
  String get workspaceEnvNativeShellSave => 'Сохранить';

  @override
  String get desktopAutostartTitle => 'Запускать при входе';

  @override
  String get desktopAutostartDescription =>
      'Запускать Kelivo при входе в систему на этом компьютере.';

  @override
  String get desktopAutostartHiddenTitle => 'Скрывать в трей при автозапуске';

  @override
  String get desktopAutostartHiddenDescription =>
      'Требуется автозапуск и значок в трее. При ручном запуске Kelivo окно всё равно отображается.';

  @override
  String get desktopAutostartUnsupported =>
      'Автозапуск требует macOS 13 или новее.';

  @override
  String get desktopAutostartError =>
      'Не удалось применить настройку автозапуска. Проверьте Kelivo в настройках автозагрузки или элементов входа системы и повторите попытку.';

  @override
  String get compressionOutputBudget => 'Общий лимит вывода (токены)';

  @override
  String get compressionOutputBudgetHint =>
      'Включает рассуждение и само резюме. Оставьте пустым, чтобы использовать длину резюме. Если рассуждение включено, этот лимит можно увеличить, не удлиняя резюме. Собственный лимит вывода модели по-прежнему действует.';

  @override
  String get responseOutputLimitReached =>
      'Ответ обрезан: лимит вывода включает рассуждение. Увеличьте лимит вывода или уменьшите рассуждение, затем повторите попытку.';

  @override
  String responseContextLimitReached(int inputTokens, int contextWindow) {
    return 'Ответ обрезан: этот запрос использовал $inputTokens входных токенов, что близко к лимиту контекста в $contextWindow токенов. Сократите контекст, затем повторите попытку.';
  }

  @override
  String get responseRetryWithoutImages =>
      'Повторить без изображений (сохранить оригиналы)';
}
