import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('zh'),
    Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hans'),
    Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'),
  ];

  /// No description provided for @helloWorld.
  ///
  /// In en, this message translates to:
  /// **'Hello World!'**
  String get helloWorld;

  /// No description provided for @settingsPageBackButton.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get settingsPageBackButton;

  /// No description provided for @settingsPageTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsPageTitle;

  /// No description provided for @settingsPageDarkMode.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get settingsPageDarkMode;

  /// No description provided for @settingsPageLightMode.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get settingsPageLightMode;

  /// No description provided for @settingsPageSystemMode.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get settingsPageSystemMode;

  /// No description provided for @settingsPageWarningMessage.
  ///
  /// In en, this message translates to:
  /// **'Some services are not configured; features may be limited.'**
  String get settingsPageWarningMessage;

  /// No description provided for @settingsPageGeneralSection.
  ///
  /// In en, this message translates to:
  /// **'General'**
  String get settingsPageGeneralSection;

  /// No description provided for @settingsPageColorMode.
  ///
  /// In en, this message translates to:
  /// **'Color Mode'**
  String get settingsPageColorMode;

  /// No description provided for @settingsPageDisplay.
  ///
  /// In en, this message translates to:
  /// **'Preferences'**
  String get settingsPageDisplay;

  /// No description provided for @settingsPageDisplaySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Appearance, behavior, and interaction preferences'**
  String get settingsPageDisplaySubtitle;

  /// No description provided for @settingsPageAssistant.
  ///
  /// In en, this message translates to:
  /// **'Assistant'**
  String get settingsPageAssistant;

  /// No description provided for @settingsPageAssistantSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Default assistant and style'**
  String get settingsPageAssistantSubtitle;

  /// No description provided for @settingsPageModelsServicesSection.
  ///
  /// In en, this message translates to:
  /// **'Models & Services'**
  String get settingsPageModelsServicesSection;

  /// No description provided for @settingsPageDefaultModel.
  ///
  /// In en, this message translates to:
  /// **'Default Model'**
  String get settingsPageDefaultModel;

  /// No description provided for @settingsPageProviders.
  ///
  /// In en, this message translates to:
  /// **'Providers'**
  String get settingsPageProviders;

  /// No description provided for @settingsPageHotkeys.
  ///
  /// In en, this message translates to:
  /// **'Hotkeys'**
  String get settingsPageHotkeys;

  /// No description provided for @settingsPageSearch.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get settingsPageSearch;

  /// No description provided for @settingsPageTts.
  ///
  /// In en, this message translates to:
  /// **'TTS'**
  String get settingsPageTts;

  /// No description provided for @settingsPageMcp.
  ///
  /// In en, this message translates to:
  /// **'MCP'**
  String get settingsPageMcp;

  /// No description provided for @settingsPageQuickPhrase.
  ///
  /// In en, this message translates to:
  /// **'Quick Phrase'**
  String get settingsPageQuickPhrase;

  /// No description provided for @settingsPageInstructionInjection.
  ///
  /// In en, this message translates to:
  /// **'Instruction Injection'**
  String get settingsPageInstructionInjection;

  /// No description provided for @settingsPageDataSection.
  ///
  /// In en, this message translates to:
  /// **'Data'**
  String get settingsPageDataSection;

  /// No description provided for @settingsPageBackup.
  ///
  /// In en, this message translates to:
  /// **'Backup'**
  String get settingsPageBackup;

  /// No description provided for @settingsPageChatStorage.
  ///
  /// In en, this message translates to:
  /// **'Chat Storage'**
  String get settingsPageChatStorage;

  /// No description provided for @settingsPageCalculating.
  ///
  /// In en, this message translates to:
  /// **'Calculating…'**
  String get settingsPageCalculating;

  /// No description provided for @settingsPageFilesCount.
  ///
  /// In en, this message translates to:
  /// **'{count} files · {size}'**
  String settingsPageFilesCount(int count, String size);

  /// No description provided for @storageSpacePageTitle.
  ///
  /// In en, this message translates to:
  /// **'Storage Space'**
  String get storageSpacePageTitle;

  /// No description provided for @storageSpaceRefreshTooltip.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get storageSpaceRefreshTooltip;

  /// No description provided for @storageSpaceLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to load storage usage'**
  String get storageSpaceLoadFailed;

  /// No description provided for @storageSpaceTotalLabel.
  ///
  /// In en, this message translates to:
  /// **'Used'**
  String get storageSpaceTotalLabel;

  /// No description provided for @storageSpaceClearableLabel.
  ///
  /// In en, this message translates to:
  /// **'Clearable: {size}'**
  String storageSpaceClearableLabel(String size);

  /// No description provided for @storageSpaceClearableHint.
  ///
  /// In en, this message translates to:
  /// **'Safe to clear: {size}'**
  String storageSpaceClearableHint(String size);

  /// No description provided for @storageSpaceCategoryImages.
  ///
  /// In en, this message translates to:
  /// **'Images'**
  String get storageSpaceCategoryImages;

  /// No description provided for @storageSpaceCategoryFiles.
  ///
  /// In en, this message translates to:
  /// **'Files'**
  String get storageSpaceCategoryFiles;

  /// No description provided for @storageSpaceCategoryFonts.
  ///
  /// In en, this message translates to:
  /// **'Fonts'**
  String get storageSpaceCategoryFonts;

  /// No description provided for @storageSpaceCategoryLocalModels.
  ///
  /// In en, this message translates to:
  /// **'Local Models'**
  String get storageSpaceCategoryLocalModels;

  /// No description provided for @storageSpaceOtherHint.
  ///
  /// In en, this message translates to:
  /// **'Fonts, downloaded local models, and other app files.'**
  String get storageSpaceOtherHint;

  /// No description provided for @storageSpaceSubOtherApp.
  ///
  /// In en, this message translates to:
  /// **'App files'**
  String get storageSpaceSubOtherApp;

  /// No description provided for @storageSpaceCategoryChatData.
  ///
  /// In en, this message translates to:
  /// **'Chat Records'**
  String get storageSpaceCategoryChatData;

  /// No description provided for @storageSpaceCategoryLegacyChatData.
  ///
  /// In en, this message translates to:
  /// **'Chat Records (Old)'**
  String get storageSpaceCategoryLegacyChatData;

  /// No description provided for @storageSpaceCategoryRestoreTraces.
  ///
  /// In en, this message translates to:
  /// **'Restore Traces'**
  String get storageSpaceCategoryRestoreTraces;

  /// No description provided for @storageSpaceCategoryDisplacedDatabases.
  ///
  /// In en, this message translates to:
  /// **'Set-Aside Databases'**
  String get storageSpaceCategoryDisplacedDatabases;

  /// No description provided for @storageSpaceSubDisplacedDatabases.
  ///
  /// In en, this message translates to:
  /// **'Kept before an automatic rebuild'**
  String get storageSpaceSubDisplacedDatabases;

  /// No description provided for @storageSpaceClearDisplacedDatabasesConfirmMessage.
  ///
  /// In en, this message translates to:
  /// **'Delete these set-aside databases? Kelivo kept them when it rebuilt its database, and they may be the only surviving copy of those chats and settings. This cannot be undone.'**
  String get storageSpaceClearDisplacedDatabasesConfirmMessage;

  /// No description provided for @storageSpaceRestoreTracesHint.
  ///
  /// In en, this message translates to:
  /// **'Previous data snapshots kept after completed restores. Clearing them does not affect the current app data.'**
  String get storageSpaceRestoreTracesHint;

  /// No description provided for @storageSpaceClearRestoreTracesButton.
  ///
  /// In en, this message translates to:
  /// **'Clear Restore Traces'**
  String get storageSpaceClearRestoreTracesButton;

  /// No description provided for @storageSpaceClearDisplacedDatabasesButton.
  ///
  /// In en, this message translates to:
  /// **'Delete Set-Aside Databases'**
  String get storageSpaceClearDisplacedDatabasesButton;

  /// No description provided for @storageSpaceClearRestoreTracesConfirmMessage.
  ///
  /// In en, this message translates to:
  /// **'Clear completed restore snapshots? Your current database, settings, and files will not be affected.'**
  String get storageSpaceClearRestoreTracesConfirmMessage;

  /// No description provided for @storageSpaceSubCompletedRestoreRuns.
  ///
  /// In en, this message translates to:
  /// **'Completed restore snapshots'**
  String get storageSpaceSubCompletedRestoreRuns;

  /// No description provided for @storageSpaceCategoryAssistantData.
  ///
  /// In en, this message translates to:
  /// **'Assistants'**
  String get storageSpaceCategoryAssistantData;

  /// No description provided for @storageSpaceCategoryCache.
  ///
  /// In en, this message translates to:
  /// **'Cache'**
  String get storageSpaceCategoryCache;

  /// No description provided for @storageSpaceCategoryLogs.
  ///
  /// In en, this message translates to:
  /// **'Logs'**
  String get storageSpaceCategoryLogs;

  /// No description provided for @storageSpaceCategoryOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get storageSpaceCategoryOther;

  /// No description provided for @storageSpaceFilesCount.
  ///
  /// In en, this message translates to:
  /// **'{count} files'**
  String storageSpaceFilesCount(int count);

  /// No description provided for @storageSpaceSafeToClearHint.
  ///
  /// In en, this message translates to:
  /// **'Safe to clear. This will not affect your chat history.'**
  String get storageSpaceSafeToClearHint;

  /// No description provided for @storageSpaceLegacyChatDataHint.
  ///
  /// In en, this message translates to:
  /// **'These are retained Hive files from before the SQLite migration. Clearing them does not delete your current chat records.'**
  String get storageSpaceLegacyChatDataHint;

  /// No description provided for @storageSpaceNotSafeToClearHint.
  ///
  /// In en, this message translates to:
  /// **'May affect your chat history. Delete with care.'**
  String get storageSpaceNotSafeToClearHint;

  /// No description provided for @storageSpaceBreakdownTitle.
  ///
  /// In en, this message translates to:
  /// **'Breakdown'**
  String get storageSpaceBreakdownTitle;

  /// No description provided for @storageSpaceSubChatMessages.
  ///
  /// In en, this message translates to:
  /// **'Messages'**
  String get storageSpaceSubChatMessages;

  /// No description provided for @storageSpaceSubChatConversations.
  ///
  /// In en, this message translates to:
  /// **'Conversations'**
  String get storageSpaceSubChatConversations;

  /// No description provided for @storageSpaceSubChatToolEvents.
  ///
  /// In en, this message translates to:
  /// **'Tool events'**
  String get storageSpaceSubChatToolEvents;

  /// No description provided for @storageSpaceSubChatDatabase.
  ///
  /// In en, this message translates to:
  /// **'Chat database'**
  String get storageSpaceSubChatDatabase;

  /// No description provided for @storageSpaceSubChatWriteAheadLog.
  ///
  /// In en, this message translates to:
  /// **'Write-ahead log'**
  String get storageSpaceSubChatWriteAheadLog;

  /// No description provided for @storageSpaceSubChatSharedMemory.
  ///
  /// In en, this message translates to:
  /// **'Shared memory index'**
  String get storageSpaceSubChatSharedMemory;

  /// No description provided for @storageSpaceSubAssistantAvatars.
  ///
  /// In en, this message translates to:
  /// **'Avatars'**
  String get storageSpaceSubAssistantAvatars;

  /// No description provided for @storageSpaceSubAssistantImages.
  ///
  /// In en, this message translates to:
  /// **'Images'**
  String get storageSpaceSubAssistantImages;

  /// No description provided for @storageSpaceSubCacheAvatars.
  ///
  /// In en, this message translates to:
  /// **'Avatar cache'**
  String get storageSpaceSubCacheAvatars;

  /// No description provided for @storageSpaceSubCacheOther.
  ///
  /// In en, this message translates to:
  /// **'Other cache'**
  String get storageSpaceSubCacheOther;

  /// No description provided for @storageSpaceSubCacheSystem.
  ///
  /// In en, this message translates to:
  /// **'System cache'**
  String get storageSpaceSubCacheSystem;

  /// No description provided for @storageSpaceSubLogsContext.
  ///
  /// In en, this message translates to:
  /// **'Context logs'**
  String get storageSpaceSubLogsContext;

  /// No description provided for @storageSpaceSubLogsFlutter.
  ///
  /// In en, this message translates to:
  /// **'Flutter logs'**
  String get storageSpaceSubLogsFlutter;

  /// No description provided for @storageSpaceSubLogsRequests.
  ///
  /// In en, this message translates to:
  /// **'Network logs'**
  String get storageSpaceSubLogsRequests;

  /// No description provided for @storageSpaceSubLogsOther.
  ///
  /// In en, this message translates to:
  /// **'Other logs'**
  String get storageSpaceSubLogsOther;

  /// No description provided for @storageSpaceClearConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Confirm clear'**
  String get storageSpaceClearConfirmTitle;

  /// No description provided for @storageSpaceClearConfirmMessage.
  ///
  /// In en, this message translates to:
  /// **'Clear {targetName}?'**
  String storageSpaceClearConfirmMessage(String targetName);

  /// No description provided for @storageSpaceClearButton.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get storageSpaceClearButton;

  /// No description provided for @storageSpaceClearDone.
  ///
  /// In en, this message translates to:
  /// **'{targetName} cleared'**
  String storageSpaceClearDone(String targetName);

  /// No description provided for @storageSpaceClearFailed.
  ///
  /// In en, this message translates to:
  /// **'Clear failed: {error}'**
  String storageSpaceClearFailed(String error);

  /// No description provided for @storageSpaceClearAvatarCacheButton.
  ///
  /// In en, this message translates to:
  /// **'Clear Avatar Cache'**
  String get storageSpaceClearAvatarCacheButton;

  /// No description provided for @storageSpaceClearCacheButton.
  ///
  /// In en, this message translates to:
  /// **'Clear Cache'**
  String get storageSpaceClearCacheButton;

  /// No description provided for @storageSpaceClearLogsButton.
  ///
  /// In en, this message translates to:
  /// **'Clear Logs'**
  String get storageSpaceClearLogsButton;

  /// No description provided for @storageSpaceClearLegacyChatDataButton.
  ///
  /// In en, this message translates to:
  /// **'Clear Old Chat Records'**
  String get storageSpaceClearLegacyChatDataButton;

  /// No description provided for @storageSpaceExportLegacyChatFileButton.
  ///
  /// In en, this message translates to:
  /// **'Export'**
  String get storageSpaceExportLegacyChatFileButton;

  /// No description provided for @storageSpaceExportDone.
  ///
  /// In en, this message translates to:
  /// **'{fileName} exported'**
  String storageSpaceExportDone(Object fileName);

  /// No description provided for @storageSpaceExportFailed.
  ///
  /// In en, this message translates to:
  /// **'Export failed: {error}'**
  String storageSpaceExportFailed(Object error);

  /// No description provided for @storageSpaceClearLegacyChatDataConfirmMessage.
  ///
  /// In en, this message translates to:
  /// **'Clear the retained old chat files? Your current SQLite chat records will remain available.'**
  String get storageSpaceClearLegacyChatDataConfirmMessage;

  /// No description provided for @storageSpaceViewLogsButton.
  ///
  /// In en, this message translates to:
  /// **'View Logs'**
  String get storageSpaceViewLogsButton;

  /// No description provided for @storageSpaceDeleteConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Confirm deletion'**
  String get storageSpaceDeleteConfirmTitle;

  /// No description provided for @storageSpaceDeleteUploadsConfirmMessage.
  ///
  /// In en, this message translates to:
  /// **'Delete {count} items? Attachments in chat history may become unavailable.'**
  String storageSpaceDeleteUploadsConfirmMessage(int count);

  /// No description provided for @storageSpaceDeletedUploadsDone.
  ///
  /// In en, this message translates to:
  /// **'Deleted {count} items'**
  String storageSpaceDeletedUploadsDone(int count);

  /// No description provided for @storageSpaceNoUploads.
  ///
  /// In en, this message translates to:
  /// **'No items'**
  String get storageSpaceNoUploads;

  /// No description provided for @storageSpaceSelectAll.
  ///
  /// In en, this message translates to:
  /// **'Select all'**
  String get storageSpaceSelectAll;

  /// No description provided for @storageSpaceClearSelection.
  ///
  /// In en, this message translates to:
  /// **'Clear selection'**
  String get storageSpaceClearSelection;

  /// No description provided for @storageSpaceSelectedCount.
  ///
  /// In en, this message translates to:
  /// **'{count} selected'**
  String storageSpaceSelectedCount(int count);

  /// No description provided for @storageSpaceUploadsCount.
  ///
  /// In en, this message translates to:
  /// **'{count} items'**
  String storageSpaceUploadsCount(int count);

  /// No description provided for @storageSpaceSourceLabel.
  ///
  /// In en, this message translates to:
  /// **'Source'**
  String get storageSpaceSourceLabel;

  /// No description provided for @storageSpaceSourceAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get storageSpaceSourceAll;

  /// No description provided for @storageSpaceSourceUserUpload.
  ///
  /// In en, this message translates to:
  /// **'User uploads'**
  String get storageSpaceSourceUserUpload;

  /// No description provided for @storageSpaceSourceAssistant.
  ///
  /// In en, this message translates to:
  /// **'Assistant'**
  String get storageSpaceSourceAssistant;

  /// No description provided for @storageSpaceSortLabel.
  ///
  /// In en, this message translates to:
  /// **'Sort'**
  String get storageSpaceSortLabel;

  /// No description provided for @storageSpaceSortNewest.
  ///
  /// In en, this message translates to:
  /// **'Newest'**
  String get storageSpaceSortNewest;

  /// No description provided for @storageSpaceSortOldest.
  ///
  /// In en, this message translates to:
  /// **'Oldest'**
  String get storageSpaceSortOldest;

  /// No description provided for @storageSpaceSortLargest.
  ///
  /// In en, this message translates to:
  /// **'Largest'**
  String get storageSpaceSortLargest;

  /// No description provided for @storageSpaceSortSmallest.
  ///
  /// In en, this message translates to:
  /// **'Smallest'**
  String get storageSpaceSortSmallest;

  /// No description provided for @settingsPageAboutSection.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get settingsPageAboutSection;

  /// No description provided for @settingsPageAbout.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get settingsPageAbout;

  /// No description provided for @settingsPageStatistics.
  ///
  /// In en, this message translates to:
  /// **'Statistics'**
  String get settingsPageStatistics;

  /// No description provided for @settingsPageDocs.
  ///
  /// In en, this message translates to:
  /// **'Docs'**
  String get settingsPageDocs;

  /// No description provided for @settingsPageLogs.
  ///
  /// In en, this message translates to:
  /// **'Logs'**
  String get settingsPageLogs;

  /// No description provided for @settingsPageSponsor.
  ///
  /// In en, this message translates to:
  /// **'Sponsor'**
  String get settingsPageSponsor;

  /// No description provided for @settingsPageShare.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get settingsPageShare;

  /// No description provided for @statsPageTitle.
  ///
  /// In en, this message translates to:
  /// **'Statistics'**
  String get statsPageTitle;

  /// No description provided for @statsPageRangeAllTime.
  ///
  /// In en, this message translates to:
  /// **'All Time'**
  String get statsPageRangeAllTime;

  /// No description provided for @statsPageRangeLast30Days.
  ///
  /// In en, this message translates to:
  /// **'Last 30 Days'**
  String get statsPageRangeLast30Days;

  /// No description provided for @statsPageRangePreviousMonth.
  ///
  /// In en, this message translates to:
  /// **'Last Month'**
  String get statsPageRangePreviousMonth;

  /// No description provided for @statsPageRangePreviousQuarter.
  ///
  /// In en, this message translates to:
  /// **'Last Quarter'**
  String get statsPageRangePreviousQuarter;

  /// No description provided for @statsPageRangeCustom.
  ///
  /// In en, this message translates to:
  /// **'Custom'**
  String get statsPageRangeCustom;

  /// No description provided for @statsPageHeatmapTitle.
  ///
  /// In en, this message translates to:
  /// **'Chat Heatmap'**
  String get statsPageHeatmapTitle;

  /// No description provided for @statsPageHeatmapLess.
  ///
  /// In en, this message translates to:
  /// **'Less'**
  String get statsPageHeatmapLess;

  /// No description provided for @statsPageHeatmapMore.
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get statsPageHeatmapMore;

  /// No description provided for @statsPageSummaryTitle.
  ///
  /// In en, this message translates to:
  /// **'Overview'**
  String get statsPageSummaryTitle;

  /// No description provided for @statsPageTotalConversations.
  ///
  /// In en, this message translates to:
  /// **'Total Conversations'**
  String get statsPageTotalConversations;

  /// No description provided for @statsPageTotalMessages.
  ///
  /// In en, this message translates to:
  /// **'Total Messages'**
  String get statsPageTotalMessages;

  /// No description provided for @statsPageInputTokens.
  ///
  /// In en, this message translates to:
  /// **'Input Tokens'**
  String get statsPageInputTokens;

  /// No description provided for @statsPageOutputTokens.
  ///
  /// In en, this message translates to:
  /// **'Output Tokens'**
  String get statsPageOutputTokens;

  /// No description provided for @statsPageCachedTokens.
  ///
  /// In en, this message translates to:
  /// **'Cached Tokens'**
  String get statsPageCachedTokens;

  /// No description provided for @statsPageLaunchCount.
  ///
  /// In en, this message translates to:
  /// **'App Launches'**
  String get statsPageLaunchCount;

  /// No description provided for @statsPageUsageTrendTitle.
  ///
  /// In en, this message translates to:
  /// **'Usage Trend'**
  String get statsPageUsageTrendTitle;

  /// No description provided for @statsPageModelUsageTitle.
  ///
  /// In en, this message translates to:
  /// **'Model Usage'**
  String get statsPageModelUsageTitle;

  /// No description provided for @statsPageAssistantUsageTitle.
  ///
  /// In en, this message translates to:
  /// **'Assistant Usage'**
  String get statsPageAssistantUsageTitle;

  /// No description provided for @statsPageTopicVolumeTitle.
  ///
  /// In en, this message translates to:
  /// **'Topic Volume'**
  String get statsPageTopicVolumeTitle;

  /// No description provided for @statsPageModelColumn.
  ///
  /// In en, this message translates to:
  /// **'Model'**
  String get statsPageModelColumn;

  /// No description provided for @statsPageAssistantColumn.
  ///
  /// In en, this message translates to:
  /// **'Assistant'**
  String get statsPageAssistantColumn;

  /// No description provided for @statsPageTopicColumn.
  ///
  /// In en, this message translates to:
  /// **'Topic'**
  String get statsPageTopicColumn;

  /// No description provided for @statsPageMessagesColumn.
  ///
  /// In en, this message translates to:
  /// **'Messages'**
  String get statsPageMessagesColumn;

  /// No description provided for @statsPageTopicsColumn.
  ///
  /// In en, this message translates to:
  /// **'Topics'**
  String get statsPageTopicsColumn;

  /// No description provided for @statsPageEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No statistics yet'**
  String get statsPageEmptyTitle;

  /// No description provided for @statsPageShowAllTooltip.
  ///
  /// In en, this message translates to:
  /// **'Show all'**
  String get statsPageShowAllTooltip;

  /// No description provided for @statsPageClose.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get statsPageClose;

  /// No description provided for @statsPageUnknownProvider.
  ///
  /// In en, this message translates to:
  /// **'Unknown Provider'**
  String get statsPageUnknownProvider;

  /// No description provided for @statsPageUnknownAssistant.
  ///
  /// In en, this message translates to:
  /// **'Default Assistant'**
  String get statsPageUnknownAssistant;

  /// No description provided for @statsPageUnknownModel.
  ///
  /// In en, this message translates to:
  /// **'Unknown Model'**
  String get statsPageUnknownModel;

  /// No description provided for @statsPageUnknownTopic.
  ///
  /// In en, this message translates to:
  /// **'Untitled Topic'**
  String get statsPageUnknownTopic;

  /// No description provided for @statsPageCustomRangeTitle.
  ///
  /// In en, this message translates to:
  /// **'Custom Range'**
  String get statsPageCustomRangeTitle;

  /// No description provided for @statsPageCustomRangeStart.
  ///
  /// In en, this message translates to:
  /// **'Start'**
  String get statsPageCustomRangeStart;

  /// No description provided for @statsPageCustomRangeEnd.
  ///
  /// In en, this message translates to:
  /// **'End'**
  String get statsPageCustomRangeEnd;

  /// No description provided for @statsPageCustomRangeCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get statsPageCustomRangeCancel;

  /// No description provided for @statsPageCustomRangeApply.
  ///
  /// In en, this message translates to:
  /// **'Apply'**
  String get statsPageCustomRangeApply;

  /// No description provided for @sponsorPageMethodsSectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Sponsorship Methods'**
  String get sponsorPageMethodsSectionTitle;

  /// No description provided for @sponsorPageSponsorsSectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Sponsors'**
  String get sponsorPageSponsorsSectionTitle;

  /// No description provided for @sponsorPageEmpty.
  ///
  /// In en, this message translates to:
  /// **'No sponsors yet'**
  String get sponsorPageEmpty;

  /// No description provided for @sponsorPageAfdianTitle.
  ///
  /// In en, this message translates to:
  /// **'Afdian'**
  String get sponsorPageAfdianTitle;

  /// No description provided for @sponsorPageAfdianSubtitle.
  ///
  /// In en, this message translates to:
  /// **'afdian.com/a/kelivo'**
  String get sponsorPageAfdianSubtitle;

  /// No description provided for @sponsorPageWeChatTitle.
  ///
  /// In en, this message translates to:
  /// **'WeChat Sponsor'**
  String get sponsorPageWeChatTitle;

  /// No description provided for @sponsorPageWeChatSubtitle.
  ///
  /// In en, this message translates to:
  /// **'WeChat sponsor code'**
  String get sponsorPageWeChatSubtitle;

  /// No description provided for @sponsorPageScanQrHint.
  ///
  /// In en, this message translates to:
  /// **'Scan the QR code to sponsor'**
  String get sponsorPageScanQrHint;

  /// No description provided for @languageDisplaySimplifiedChinese.
  ///
  /// In en, this message translates to:
  /// **'Simplified Chinese'**
  String get languageDisplaySimplifiedChinese;

  /// No description provided for @languageDisplayEnglish.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get languageDisplayEnglish;

  /// No description provided for @languageDisplayTraditionalChinese.
  ///
  /// In en, this message translates to:
  /// **'Traditional Chinese'**
  String get languageDisplayTraditionalChinese;

  /// No description provided for @languageDisplayJapanese.
  ///
  /// In en, this message translates to:
  /// **'Japanese'**
  String get languageDisplayJapanese;

  /// No description provided for @languageDisplayKorean.
  ///
  /// In en, this message translates to:
  /// **'Korean'**
  String get languageDisplayKorean;

  /// No description provided for @languageDisplayFrench.
  ///
  /// In en, this message translates to:
  /// **'French'**
  String get languageDisplayFrench;

  /// No description provided for @languageDisplayGerman.
  ///
  /// In en, this message translates to:
  /// **'German'**
  String get languageDisplayGerman;

  /// No description provided for @languageDisplayItalian.
  ///
  /// In en, this message translates to:
  /// **'Italian'**
  String get languageDisplayItalian;

  /// No description provided for @languageDisplaySpanish.
  ///
  /// In en, this message translates to:
  /// **'Spanish'**
  String get languageDisplaySpanish;

  /// No description provided for @languageSelectSheetTitle.
  ///
  /// In en, this message translates to:
  /// **'Select Translation Language'**
  String get languageSelectSheetTitle;

  /// No description provided for @languageSelectSheetClearButton.
  ///
  /// In en, this message translates to:
  /// **'Clear Translation'**
  String get languageSelectSheetClearButton;

  /// No description provided for @homePageClearContext.
  ///
  /// In en, this message translates to:
  /// **'Clear Context'**
  String get homePageClearContext;

  /// No description provided for @homePageClearContextWithCount.
  ///
  /// In en, this message translates to:
  /// **'Clear Context ({actual}/{configured})'**
  String homePageClearContextWithCount(String actual, String configured);

  /// No description provided for @homePageDefaultAssistant.
  ///
  /// In en, this message translates to:
  /// **'Default Assistant'**
  String get homePageDefaultAssistant;

  /// No description provided for @mermaidExportPng.
  ///
  /// In en, this message translates to:
  /// **'Export PNG'**
  String get mermaidExportPng;

  /// No description provided for @mermaidExportFailed.
  ///
  /// In en, this message translates to:
  /// **'Export failed'**
  String get mermaidExportFailed;

  /// No description provided for @mermaidImageTab.
  ///
  /// In en, this message translates to:
  /// **'Image'**
  String get mermaidImageTab;

  /// No description provided for @mermaidCodeTab.
  ///
  /// In en, this message translates to:
  /// **'Code'**
  String get mermaidCodeTab;

  /// No description provided for @mermaidFullScreen.
  ///
  /// In en, this message translates to:
  /// **'Full screen'**
  String get mermaidFullScreen;

  /// No description provided for @mermaidGeneratingImage.
  ///
  /// In en, this message translates to:
  /// **'Generating image'**
  String get mermaidGeneratingImage;

  /// No description provided for @mermaidGenerationFailedHint.
  ///
  /// In en, this message translates to:
  /// **'Generation failed. Try asking another way.'**
  String get mermaidGenerationFailedHint;

  /// No description provided for @mermaidPreviewOpen.
  ///
  /// In en, this message translates to:
  /// **'Open Preview'**
  String get mermaidPreviewOpen;

  /// No description provided for @mermaidPreviewOpenFailed.
  ///
  /// In en, this message translates to:
  /// **'Cannot open preview'**
  String get mermaidPreviewOpenFailed;

  /// No description provided for @assistantProviderDefaultAssistantName.
  ///
  /// In en, this message translates to:
  /// **'Default Assistant'**
  String get assistantProviderDefaultAssistantName;

  /// No description provided for @assistantProviderSampleAssistantName.
  ///
  /// In en, this message translates to:
  /// **'Sample Assistant'**
  String get assistantProviderSampleAssistantName;

  /// No description provided for @assistantProviderNewAssistantName.
  ///
  /// In en, this message translates to:
  /// **'New Assistant'**
  String get assistantProviderNewAssistantName;

  /// No description provided for @assistantProviderSampleAssistantSystemPrompt.
  ///
  /// In en, this message translates to:
  /// **'You are {model_name}, a helpful AI assistant. Answer accurately and concisely; say when you are unsure. Prefer clear structure (short paragraphs or lists) when it helps. Reply in the user\'s language by default.'**
  String assistantProviderSampleAssistantSystemPrompt(String model_name);

  /// No description provided for @displaySettingsPageLanguageTitle.
  ///
  /// In en, this message translates to:
  /// **'App Language'**
  String get displaySettingsPageLanguageTitle;

  /// No description provided for @displaySettingsPageLanguageSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Choose interface language'**
  String get displaySettingsPageLanguageSubtitle;

  /// No description provided for @assistantTagsManageTitle.
  ///
  /// In en, this message translates to:
  /// **'Manage Tags'**
  String get assistantTagsManageTitle;

  /// No description provided for @assistantTagsCreateButton.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get assistantTagsCreateButton;

  /// No description provided for @assistantTagsCreateDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Create Tag'**
  String get assistantTagsCreateDialogTitle;

  /// No description provided for @assistantTagsCreateDialogOk.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get assistantTagsCreateDialogOk;

  /// No description provided for @assistantTagsCreateDialogCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get assistantTagsCreateDialogCancel;

  /// No description provided for @assistantTagsNameHint.
  ///
  /// In en, this message translates to:
  /// **'Tag name'**
  String get assistantTagsNameHint;

  /// No description provided for @assistantTagsRenameButton.
  ///
  /// In en, this message translates to:
  /// **'Rename'**
  String get assistantTagsRenameButton;

  /// No description provided for @assistantTagsRenameDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Rename Tag'**
  String get assistantTagsRenameDialogTitle;

  /// No description provided for @assistantTagsRenameDialogOk.
  ///
  /// In en, this message translates to:
  /// **'Rename'**
  String get assistantTagsRenameDialogOk;

  /// No description provided for @assistantTagsDeleteButton.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get assistantTagsDeleteButton;

  /// No description provided for @assistantTagsDeleteConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete Tag'**
  String get assistantTagsDeleteConfirmTitle;

  /// No description provided for @assistantTagsDeleteConfirmContent.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete this tag?'**
  String get assistantTagsDeleteConfirmContent;

  /// No description provided for @assistantTagsDeleteConfirmOk.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get assistantTagsDeleteConfirmOk;

  /// No description provided for @assistantTagsDeleteConfirmCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get assistantTagsDeleteConfirmCancel;

  /// No description provided for @assistantTagsContextMenuEditAssistant.
  ///
  /// In en, this message translates to:
  /// **'Edit Assistant'**
  String get assistantTagsContextMenuEditAssistant;

  /// No description provided for @assistantTagsContextMenuManageTags.
  ///
  /// In en, this message translates to:
  /// **'Manage Tags'**
  String get assistantTagsContextMenuManageTags;

  /// No description provided for @mcpTransportOptionStdio.
  ///
  /// In en, this message translates to:
  /// **'STDIO'**
  String get mcpTransportOptionStdio;

  /// No description provided for @mcpTransportTagStdio.
  ///
  /// In en, this message translates to:
  /// **'STDIO'**
  String get mcpTransportTagStdio;

  /// No description provided for @mcpTransportTagInmemory.
  ///
  /// In en, this message translates to:
  /// **'Built-in'**
  String get mcpTransportTagInmemory;

  /// No description provided for @mcpTransportTagSse.
  ///
  /// In en, this message translates to:
  /// **'SSE'**
  String get mcpTransportTagSse;

  /// No description provided for @mcpTransportTagHttp.
  ///
  /// In en, this message translates to:
  /// **'HTTP'**
  String get mcpTransportTagHttp;

  /// No description provided for @mcpServerEditSheetStdioOnlyDesktop.
  ///
  /// In en, this message translates to:
  /// **'STDIO is only available on desktop'**
  String get mcpServerEditSheetStdioOnlyDesktop;

  /// No description provided for @mcpServerEditSheetStdioCommandLabel.
  ///
  /// In en, this message translates to:
  /// **'Command'**
  String get mcpServerEditSheetStdioCommandLabel;

  /// No description provided for @mcpServerEditSheetStdioArgumentsLabel.
  ///
  /// In en, this message translates to:
  /// **'Arguments'**
  String get mcpServerEditSheetStdioArgumentsLabel;

  /// No description provided for @mcpServerEditSheetStdioWorkingDirectoryLabel.
  ///
  /// In en, this message translates to:
  /// **'Working Directory (optional)'**
  String get mcpServerEditSheetStdioWorkingDirectoryLabel;

  /// No description provided for @mcpServerEditSheetStdioEnvironmentTitle.
  ///
  /// In en, this message translates to:
  /// **'Environment'**
  String get mcpServerEditSheetStdioEnvironmentTitle;

  /// No description provided for @mcpServerEditSheetStdioEnvNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get mcpServerEditSheetStdioEnvNameLabel;

  /// No description provided for @mcpServerEditSheetStdioEnvValueLabel.
  ///
  /// In en, this message translates to:
  /// **'Value'**
  String get mcpServerEditSheetStdioEnvValueLabel;

  /// No description provided for @mcpServerEditSheetStdioAddEnv.
  ///
  /// In en, this message translates to:
  /// **'Add Env'**
  String get mcpServerEditSheetStdioAddEnv;

  /// No description provided for @mcpServerEditSheetStdioCommandRequired.
  ///
  /// In en, this message translates to:
  /// **'Command is required for STDIO'**
  String get mcpServerEditSheetStdioCommandRequired;

  /// No description provided for @assistantTagsContextMenuDeleteAssistant.
  ///
  /// In en, this message translates to:
  /// **'Delete Assistant'**
  String get assistantTagsContextMenuDeleteAssistant;

  /// No description provided for @assistantTagsClearTag.
  ///
  /// In en, this message translates to:
  /// **'Clear Tag'**
  String get assistantTagsClearTag;

  /// No description provided for @displaySettingsPageLanguageChineseLabel.
  ///
  /// In en, this message translates to:
  /// **'Simplified Chinese'**
  String get displaySettingsPageLanguageChineseLabel;

  /// No description provided for @displaySettingsPageLanguageEnglishLabel.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get displaySettingsPageLanguageEnglishLabel;

  /// No description provided for @homePagePleaseSelectModel.
  ///
  /// In en, this message translates to:
  /// **'Please select a model first'**
  String get homePagePleaseSelectModel;

  /// No description provided for @homePageAudioAttachmentUnsupported.
  ///
  /// In en, this message translates to:
  /// **'The current model does not support audio attachments. Switch to a model that supports audio input or remove the audio file and try again.'**
  String get homePageAudioAttachmentUnsupported;

  /// No description provided for @homePagePleaseSetupTranslateModel.
  ///
  /// In en, this message translates to:
  /// **'Please set a translation model first'**
  String get homePagePleaseSetupTranslateModel;

  /// No description provided for @homePageTranslating.
  ///
  /// In en, this message translates to:
  /// **'Translating...'**
  String get homePageTranslating;

  /// No description provided for @homePageTranslateFailed.
  ///
  /// In en, this message translates to:
  /// **'Translation failed: {error}'**
  String homePageTranslateFailed(String error);

  /// No description provided for @chatServiceDefaultConversationTitle.
  ///
  /// In en, this message translates to:
  /// **'New Chat'**
  String get chatServiceDefaultConversationTitle;

  /// No description provided for @userProviderDefaultUserName.
  ///
  /// In en, this message translates to:
  /// **'User'**
  String get userProviderDefaultUserName;

  /// No description provided for @homePageDeleteMessage.
  ///
  /// In en, this message translates to:
  /// **'Delete This Version'**
  String get homePageDeleteMessage;

  /// No description provided for @homePageDeleteMessageConfirm.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete this version? This cannot be undone.'**
  String get homePageDeleteMessageConfirm;

  /// No description provided for @homePageDeleteAllVersions.
  ///
  /// In en, this message translates to:
  /// **'Delete All Versions'**
  String get homePageDeleteAllVersions;

  /// No description provided for @homePageDeleteAllVersionsConfirm.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete all versions of this message? This cannot be undone.'**
  String get homePageDeleteAllVersionsConfirm;

  /// No description provided for @homePageCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get homePageCancel;

  /// No description provided for @homePageDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get homePageDelete;

  /// No description provided for @homePageSelectMessagesToShare.
  ///
  /// In en, this message translates to:
  /// **'Please select messages to share'**
  String get homePageSelectMessagesToShare;

  /// No description provided for @homePageDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get homePageDone;

  /// No description provided for @homePageDropToUpload.
  ///
  /// In en, this message translates to:
  /// **'Drop files to upload'**
  String get homePageDropToUpload;

  /// No description provided for @assistantEditPageTitle.
  ///
  /// In en, this message translates to:
  /// **'Assistant'**
  String get assistantEditPageTitle;

  /// No description provided for @assistantEditPageNotFound.
  ///
  /// In en, this message translates to:
  /// **'Assistant not found'**
  String get assistantEditPageNotFound;

  /// No description provided for @assistantEditPageBasicTab.
  ///
  /// In en, this message translates to:
  /// **'Basic'**
  String get assistantEditPageBasicTab;

  /// No description provided for @assistantEditPagePromptsTab.
  ///
  /// In en, this message translates to:
  /// **'Prompts'**
  String get assistantEditPagePromptsTab;

  /// No description provided for @assistantEditPageMcpTab.
  ///
  /// In en, this message translates to:
  /// **'MCP'**
  String get assistantEditPageMcpTab;

  /// No description provided for @assistantEditPageQuickPhraseTab.
  ///
  /// In en, this message translates to:
  /// **'Quick Phrase'**
  String get assistantEditPageQuickPhraseTab;

  /// No description provided for @assistantEditPageCustomTab.
  ///
  /// In en, this message translates to:
  /// **'Custom'**
  String get assistantEditPageCustomTab;

  /// No description provided for @assistantEditPageRegexTab.
  ///
  /// In en, this message translates to:
  /// **'Regex Replace'**
  String get assistantEditPageRegexTab;

  /// No description provided for @assistantEditPageLocalToolsTab.
  ///
  /// In en, this message translates to:
  /// **'Local Tools'**
  String get assistantEditPageLocalToolsTab;

  /// No description provided for @assistantEditTabLayoutTooltip.
  ///
  /// In en, this message translates to:
  /// **'Customize tabs'**
  String get assistantEditTabLayoutTooltip;

  /// No description provided for @assistantEditTabLayoutTitle.
  ///
  /// In en, this message translates to:
  /// **'Customize tabs'**
  String get assistantEditTabLayoutTitle;

  /// No description provided for @assistantEditTabLayoutSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Drag tabs to reorder. Turn off tabs you do not need.'**
  String get assistantEditTabLayoutSubtitle;

  /// No description provided for @assistantEditOutlineModeTitle.
  ///
  /// In en, this message translates to:
  /// **'Section list style'**
  String get assistantEditOutlineModeTitle;

  /// No description provided for @assistantEditOutlineModeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Show an assistant overview first, then open each setting section from a list.'**
  String get assistantEditOutlineModeSubtitle;

  /// No description provided for @assistantEditTabLayoutResetTooltip.
  ///
  /// In en, this message translates to:
  /// **'Reset tab layout'**
  String get assistantEditTabLayoutResetTooltip;

  /// No description provided for @assistantEditTabLayoutAtLeastOneVisible.
  ///
  /// In en, this message translates to:
  /// **'Keep at least one tab visible'**
  String get assistantEditTabLayoutAtLeastOneVisible;

  /// No description provided for @assistantEditTabLayoutDragHandle.
  ///
  /// In en, this message translates to:
  /// **'Drag to reorder {tab}'**
  String assistantEditTabLayoutDragHandle(String tab);

  /// No description provided for @assistantEditRegexDescription.
  ///
  /// In en, this message translates to:
  /// **'Create regex rules to rewrite or visually adjust user/assistant messages.'**
  String get assistantEditRegexDescription;

  /// No description provided for @assistantEditAddRegexButton.
  ///
  /// In en, this message translates to:
  /// **'Add Regex Rule'**
  String get assistantEditAddRegexButton;

  /// No description provided for @assistantRegexAddTitle.
  ///
  /// In en, this message translates to:
  /// **'Add Regex Rule'**
  String get assistantRegexAddTitle;

  /// No description provided for @assistantRegexEditTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit Regex Rule'**
  String get assistantRegexEditTitle;

  /// No description provided for @assistantRegexNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Rule Name'**
  String get assistantRegexNameLabel;

  /// No description provided for @assistantRegexPatternLabel.
  ///
  /// In en, this message translates to:
  /// **'Regular Expression'**
  String get assistantRegexPatternLabel;

  /// No description provided for @assistantRegexReplacementLabel.
  ///
  /// In en, this message translates to:
  /// **'Replacement String'**
  String get assistantRegexReplacementLabel;

  /// No description provided for @assistantRegexScopeLabel.
  ///
  /// In en, this message translates to:
  /// **'Affecting Scope'**
  String get assistantRegexScopeLabel;

  /// No description provided for @assistantRegexScopeUser.
  ///
  /// In en, this message translates to:
  /// **'User'**
  String get assistantRegexScopeUser;

  /// No description provided for @assistantRegexScopeAssistant.
  ///
  /// In en, this message translates to:
  /// **'Assistant'**
  String get assistantRegexScopeAssistant;

  /// No description provided for @assistantRegexScopeVisualOnly.
  ///
  /// In en, this message translates to:
  /// **'Visual Only'**
  String get assistantRegexScopeVisualOnly;

  /// No description provided for @assistantRegexScopeReplaceOnly.
  ///
  /// In en, this message translates to:
  /// **'Replace Only'**
  String get assistantRegexScopeReplaceOnly;

  /// No description provided for @assistantRegexAddAction.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get assistantRegexAddAction;

  /// No description provided for @assistantRegexSaveAction.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get assistantRegexSaveAction;

  /// No description provided for @assistantRegexDeleteButton.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get assistantRegexDeleteButton;

  /// No description provided for @assistantRegexValidationError.
  ///
  /// In en, this message translates to:
  /// **'Please fill in the name, regex, and select at least one scope.'**
  String get assistantRegexValidationError;

  /// No description provided for @assistantRegexInvalidPattern.
  ///
  /// In en, this message translates to:
  /// **'Invalid regular expression'**
  String get assistantRegexInvalidPattern;

  /// No description provided for @assistantRegexCancelButton.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get assistantRegexCancelButton;

  /// No description provided for @assistantRegexUntitled.
  ///
  /// In en, this message translates to:
  /// **'Untitled Rule'**
  String get assistantRegexUntitled;

  /// No description provided for @assistantEditCustomHeadersTitle.
  ///
  /// In en, this message translates to:
  /// **'Custom Headers'**
  String get assistantEditCustomHeadersTitle;

  /// No description provided for @assistantEditCustomHeadersAdd.
  ///
  /// In en, this message translates to:
  /// **'Add Header'**
  String get assistantEditCustomHeadersAdd;

  /// No description provided for @assistantEditCustomHeadersEmpty.
  ///
  /// In en, this message translates to:
  /// **'No headers added'**
  String get assistantEditCustomHeadersEmpty;

  /// No description provided for @assistantEditCustomBodyTitle.
  ///
  /// In en, this message translates to:
  /// **'Custom Body'**
  String get assistantEditCustomBodyTitle;

  /// No description provided for @assistantEditCustomBodyAdd.
  ///
  /// In en, this message translates to:
  /// **'Add Body'**
  String get assistantEditCustomBodyAdd;

  /// No description provided for @assistantEditCustomBodyEmpty.
  ///
  /// In en, this message translates to:
  /// **'No body items added'**
  String get assistantEditCustomBodyEmpty;

  /// No description provided for @assistantEditHeaderNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Header Name'**
  String get assistantEditHeaderNameLabel;

  /// No description provided for @assistantEditHeaderValueLabel.
  ///
  /// In en, this message translates to:
  /// **'Header Value'**
  String get assistantEditHeaderValueLabel;

  /// No description provided for @assistantEditBodyKeyLabel.
  ///
  /// In en, this message translates to:
  /// **'Body Key'**
  String get assistantEditBodyKeyLabel;

  /// No description provided for @assistantEditBodyValueLabel.
  ///
  /// In en, this message translates to:
  /// **'Body Value (JSON)'**
  String get assistantEditBodyValueLabel;

  /// No description provided for @assistantEditDeleteTooltip.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get assistantEditDeleteTooltip;

  /// No description provided for @assistantEditAssistantNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Assistant Name'**
  String get assistantEditAssistantNameLabel;

  /// No description provided for @assistantEditUseAssistantAvatarTitle.
  ///
  /// In en, this message translates to:
  /// **'Use Assistant Avatar'**
  String get assistantEditUseAssistantAvatarTitle;

  /// No description provided for @assistantEditUseAssistantAvatarSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Use assistant avatar instead of model avatar'**
  String get assistantEditUseAssistantAvatarSubtitle;

  /// No description provided for @assistantEditUseAssistantNameTitle.
  ///
  /// In en, this message translates to:
  /// **'Use Assistant Name'**
  String get assistantEditUseAssistantNameTitle;

  /// No description provided for @assistantEditChatModelTitle.
  ///
  /// In en, this message translates to:
  /// **'Chat Model'**
  String get assistantEditChatModelTitle;

  /// No description provided for @assistantEditChatModelSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Default chat model for this assistant (fallback to global)'**
  String get assistantEditChatModelSubtitle;

  /// No description provided for @assistantEditTemperatureDescription.
  ///
  /// In en, this message translates to:
  /// **'Controls randomness, range 0–2'**
  String get assistantEditTemperatureDescription;

  /// No description provided for @assistantEditTopPDescription.
  ///
  /// In en, this message translates to:
  /// **'Do not change unless you know what you are doing'**
  String get assistantEditTopPDescription;

  /// No description provided for @assistantEditParameterDisabled.
  ///
  /// In en, this message translates to:
  /// **'Disabled (uses provider default)'**
  String get assistantEditParameterDisabled;

  /// No description provided for @assistantEditParameterDisabled2.
  ///
  /// In en, this message translates to:
  /// **'Disabled (no restrictions)'**
  String get assistantEditParameterDisabled2;

  /// No description provided for @assistantEditContextMessagesTitle.
  ///
  /// In en, this message translates to:
  /// **'Context Messages'**
  String get assistantEditContextMessagesTitle;

  /// No description provided for @assistantEditContextMessagesDescription.
  ///
  /// In en, this message translates to:
  /// **'How many recent messages to keep in context'**
  String get assistantEditContextMessagesDescription;

  /// No description provided for @assistantEditStreamOutputTitle.
  ///
  /// In en, this message translates to:
  /// **'Stream Output'**
  String get assistantEditStreamOutputTitle;

  /// No description provided for @assistantEditStreamOutputDescription.
  ///
  /// In en, this message translates to:
  /// **'Enable streaming responses'**
  String get assistantEditStreamOutputDescription;

  /// No description provided for @assistantEditThinkingBudgetTitle.
  ///
  /// In en, this message translates to:
  /// **'Thinking Budget'**
  String get assistantEditThinkingBudgetTitle;

  /// No description provided for @assistantEditConfigureButton.
  ///
  /// In en, this message translates to:
  /// **'Configure'**
  String get assistantEditConfigureButton;

  /// No description provided for @assistantEditMaxTokensTitle.
  ///
  /// In en, this message translates to:
  /// **'Max Tokens'**
  String get assistantEditMaxTokensTitle;

  /// No description provided for @assistantEditMaxTokensDescription.
  ///
  /// In en, this message translates to:
  /// **'Leave empty for unlimited'**
  String get assistantEditMaxTokensDescription;

  /// No description provided for @assistantEditMaxTokensHint.
  ///
  /// In en, this message translates to:
  /// **'Unlimited'**
  String get assistantEditMaxTokensHint;

  /// No description provided for @assistantEditChatBackgroundTitle.
  ///
  /// In en, this message translates to:
  /// **'Chat Background'**
  String get assistantEditChatBackgroundTitle;

  /// No description provided for @assistantEditChatBackgroundDescription.
  ///
  /// In en, this message translates to:
  /// **'Set a background image for this assistant'**
  String get assistantEditChatBackgroundDescription;

  /// No description provided for @assistantEditChooseImageButton.
  ///
  /// In en, this message translates to:
  /// **'Choose Image'**
  String get assistantEditChooseImageButton;

  /// No description provided for @assistantEditClearButton.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get assistantEditClearButton;

  /// No description provided for @desktopNavChatTooltip.
  ///
  /// In en, this message translates to:
  /// **'Chat'**
  String get desktopNavChatTooltip;

  /// No description provided for @desktopNavTranslateTooltip.
  ///
  /// In en, this message translates to:
  /// **'Translate'**
  String get desktopNavTranslateTooltip;

  /// No description provided for @desktopNavStorageTooltip.
  ///
  /// In en, this message translates to:
  /// **'Storage'**
  String get desktopNavStorageTooltip;

  /// No description provided for @desktopNavGlobalSearchTooltip.
  ///
  /// In en, this message translates to:
  /// **'Global Search'**
  String get desktopNavGlobalSearchTooltip;

  /// No description provided for @desktopNavThemeToggleTooltip.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get desktopNavThemeToggleTooltip;

  /// No description provided for @desktopNavSettingsTooltip.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get desktopNavSettingsTooltip;

  /// No description provided for @desktopAvatarMenuUseEmoji.
  ///
  /// In en, this message translates to:
  /// **'Use emoji'**
  String get desktopAvatarMenuUseEmoji;

  /// No description provided for @cameraPermissionDeniedMessage.
  ///
  /// In en, this message translates to:
  /// **'Camera unavailable: permission not granted.'**
  String get cameraPermissionDeniedMessage;

  /// No description provided for @openSystemSettings.
  ///
  /// In en, this message translates to:
  /// **'Open Settings'**
  String get openSystemSettings;

  /// No description provided for @desktopAvatarMenuChangeFromImage.
  ///
  /// In en, this message translates to:
  /// **'Change from image…'**
  String get desktopAvatarMenuChangeFromImage;

  /// No description provided for @desktopAvatarMenuReset.
  ///
  /// In en, this message translates to:
  /// **'Reset avatar'**
  String get desktopAvatarMenuReset;

  /// No description provided for @assistantEditAvatarChooseImage.
  ///
  /// In en, this message translates to:
  /// **'Choose Image'**
  String get assistantEditAvatarChooseImage;

  /// No description provided for @assistantEditAvatarChooseEmoji.
  ///
  /// In en, this message translates to:
  /// **'Choose Emoji'**
  String get assistantEditAvatarChooseEmoji;

  /// No description provided for @assistantEditAvatarEnterLink.
  ///
  /// In en, this message translates to:
  /// **'Enter Link'**
  String get assistantEditAvatarEnterLink;

  /// No description provided for @assistantEditAvatarImportQQ.
  ///
  /// In en, this message translates to:
  /// **'Import from QQ'**
  String get assistantEditAvatarImportQQ;

  /// No description provided for @assistantEditAvatarReset.
  ///
  /// In en, this message translates to:
  /// **'Reset'**
  String get assistantEditAvatarReset;

  /// No description provided for @displaySettingsPageChatMessageBackgroundTitle.
  ///
  /// In en, this message translates to:
  /// **'Chat Message Background'**
  String get displaySettingsPageChatMessageBackgroundTitle;

  /// No description provided for @displaySettingsPageChatMessageBackgroundDefault.
  ///
  /// In en, this message translates to:
  /// **'Default'**
  String get displaySettingsPageChatMessageBackgroundDefault;

  /// No description provided for @displaySettingsPageChatMessageBackgroundFrosted.
  ///
  /// In en, this message translates to:
  /// **'Frosted Glass'**
  String get displaySettingsPageChatMessageBackgroundFrosted;

  /// No description provided for @displaySettingsPageChatMessageBackgroundSolid.
  ///
  /// In en, this message translates to:
  /// **'Solid Color'**
  String get displaySettingsPageChatMessageBackgroundSolid;

  /// No description provided for @displaySettingsPageAndroidBackgroundChatTitle.
  ///
  /// In en, this message translates to:
  /// **'Background Generation (Android)'**
  String get displaySettingsPageAndroidBackgroundChatTitle;

  /// No description provided for @displaySettingsPageIosBackgroundChatTitle.
  ///
  /// In en, this message translates to:
  /// **'Background Generation (iOS)'**
  String get displaySettingsPageIosBackgroundChatTitle;

  /// No description provided for @iosBackgroundSettingsPageTitle.
  ///
  /// In en, this message translates to:
  /// **'iOS Background Generation'**
  String get iosBackgroundSettingsPageTitle;

  /// No description provided for @iosBackgroundStatusOn.
  ///
  /// In en, this message translates to:
  /// **'On'**
  String get iosBackgroundStatusOn;

  /// No description provided for @iosBackgroundStatusOff.
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get iosBackgroundStatusOff;

  /// No description provided for @iosBackgroundGenerationEnableTitle.
  ///
  /// In en, this message translates to:
  /// **'Background Generation'**
  String get iosBackgroundGenerationEnableTitle;

  /// No description provided for @iosBackgroundGenerationEnableSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Use iOS background time to keep the current reply running after the app leaves the foreground.'**
  String get iosBackgroundGenerationEnableSubtitle;

  /// No description provided for @iosBackgroundTaskRefreshTitle.
  ///
  /// In en, this message translates to:
  /// **'Background Task Recovery'**
  String get iosBackgroundTaskRefreshTitle;

  /// No description provided for @iosBackgroundTaskRefreshSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Ask iOS for refresh and processing opportunities when system conditions allow.'**
  String get iosBackgroundTaskRefreshSubtitle;

  /// No description provided for @iosLiveActivityTitle.
  ///
  /// In en, this message translates to:
  /// **'Live Activity'**
  String get iosLiveActivityTitle;

  /// No description provided for @iosLiveActivitySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Show background replies on the Lock Screen and Dynamic Island when supported.'**
  String get iosLiveActivitySubtitle;

  /// No description provided for @iosBackgroundNotificationsTitle.
  ///
  /// In en, this message translates to:
  /// **'Task Notifications'**
  String get iosBackgroundNotificationsTitle;

  /// No description provided for @iosBackgroundNotificationsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Send a local notification when a background reply completes or is interrupted.'**
  String get iosBackgroundNotificationsSubtitle;

  /// No description provided for @iosBackgroundLimitNoticeTitle.
  ///
  /// In en, this message translates to:
  /// **'iOS may still suspend work'**
  String get iosBackgroundLimitNoticeTitle;

  /// No description provided for @iosBackgroundLimitNoticeBody.
  ///
  /// In en, this message translates to:
  /// **'These options use Apple-supported background time, BackgroundTasks, notifications, and Live Activities. They improve continuity but cannot force iOS to keep Kelivo running forever.'**
  String get iosBackgroundLimitNoticeBody;

  /// No description provided for @iosBackgroundUnsupportedLiveActivity.
  ///
  /// In en, this message translates to:
  /// **'Requires iOS 16.1 or later and Live Activities enabled in Settings.'**
  String get iosBackgroundUnsupportedLiveActivity;

  /// No description provided for @iosBackgroundNativeStatusTitle.
  ///
  /// In en, this message translates to:
  /// **'System status'**
  String get iosBackgroundNativeStatusTitle;

  /// No description provided for @iosBackgroundNativeStatusUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Unavailable until running on iOS'**
  String get iosBackgroundNativeStatusUnavailable;

  /// No description provided for @iosBackgroundLiveActivityAvailable.
  ///
  /// In en, this message translates to:
  /// **'Live Activities available'**
  String get iosBackgroundLiveActivityAvailable;

  /// No description provided for @iosBackgroundLiveActivityUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Live Activities unavailable'**
  String get iosBackgroundLiveActivityUnavailable;

  /// No description provided for @iosBackgroundNotificationsAuthorized.
  ///
  /// In en, this message translates to:
  /// **'Notifications allowed'**
  String get iosBackgroundNotificationsAuthorized;

  /// No description provided for @iosBackgroundNotificationsNotAuthorized.
  ///
  /// In en, this message translates to:
  /// **'Notifications not allowed'**
  String get iosBackgroundNotificationsNotAuthorized;

  /// No description provided for @iosBackgroundGenerationActiveTitle.
  ///
  /// In en, this message translates to:
  /// **'Kelivo is generating'**
  String get iosBackgroundGenerationActiveTitle;

  /// No description provided for @iosBackgroundGenerationActiveDetail.
  ///
  /// In en, this message translates to:
  /// **'The assistant is replying in the background'**
  String get iosBackgroundGenerationActiveDetail;

  /// No description provided for @iosBackgroundGenerationStreamingDetail.
  ///
  /// In en, this message translates to:
  /// **'Receiving assistant response'**
  String get iosBackgroundGenerationStreamingDetail;

  /// No description provided for @iosBackgroundGenerationTokenCount.
  ///
  /// In en, this message translates to:
  /// **'{count} tokens'**
  String iosBackgroundGenerationTokenCount(int count);

  /// No description provided for @iosBackgroundGenerationCompleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Generation complete'**
  String get iosBackgroundGenerationCompleteTitle;

  /// No description provided for @iosBackgroundGenerationCompleteDetail.
  ///
  /// In en, this message translates to:
  /// **'Assistant reply is ready'**
  String get iosBackgroundGenerationCompleteDetail;

  /// No description provided for @iosBackgroundGenerationInterruptedTitle.
  ///
  /// In en, this message translates to:
  /// **'Generation interrupted'**
  String get iosBackgroundGenerationInterruptedTitle;

  /// No description provided for @iosBackgroundGenerationInterruptedDetail.
  ///
  /// In en, this message translates to:
  /// **'The background reply stopped before completion'**
  String get iosBackgroundGenerationInterruptedDetail;

  /// No description provided for @iosBackgroundGenerationCancelledDetail.
  ///
  /// In en, this message translates to:
  /// **'Generation stopped'**
  String get iosBackgroundGenerationCancelledDetail;

  /// No description provided for @androidBackgroundStatusOn.
  ///
  /// In en, this message translates to:
  /// **'On'**
  String get androidBackgroundStatusOn;

  /// No description provided for @androidBackgroundStatusOff.
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get androidBackgroundStatusOff;

  /// No description provided for @androidBackgroundStatusOther.
  ///
  /// In en, this message translates to:
  /// **'On and notify'**
  String get androidBackgroundStatusOther;

  /// No description provided for @androidBackgroundOptionOn.
  ///
  /// In en, this message translates to:
  /// **'On'**
  String get androidBackgroundOptionOn;

  /// No description provided for @androidBackgroundOptionOnNotify.
  ///
  /// In en, this message translates to:
  /// **'On and notify when done'**
  String get androidBackgroundOptionOnNotify;

  /// No description provided for @androidBackgroundOptionOff.
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get androidBackgroundOptionOff;

  /// No description provided for @notificationChatCompletedTitle.
  ///
  /// In en, this message translates to:
  /// **'Generation complete'**
  String get notificationChatCompletedTitle;

  /// No description provided for @notificationChatCompletedBody.
  ///
  /// In en, this message translates to:
  /// **'Assistant reply has been generated'**
  String get notificationChatCompletedBody;

  /// No description provided for @androidBackgroundNotificationTitle.
  ///
  /// In en, this message translates to:
  /// **'Kelivo is running'**
  String get androidBackgroundNotificationTitle;

  /// No description provided for @androidBackgroundNotificationText.
  ///
  /// In en, this message translates to:
  /// **'Keeping chat generation alive in background'**
  String get androidBackgroundNotificationText;

  /// No description provided for @assistantEditEmojiDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Choose Emoji'**
  String get assistantEditEmojiDialogTitle;

  /// No description provided for @assistantEditEmojiDialogHint.
  ///
  /// In en, this message translates to:
  /// **'Type or paste any emoji'**
  String get assistantEditEmojiDialogHint;

  /// No description provided for @assistantEditEmojiDialogCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get assistantEditEmojiDialogCancel;

  /// No description provided for @assistantEditEmojiDialogSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get assistantEditEmojiDialogSave;

  /// No description provided for @assistantEditImageUrlDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Enter Image URL'**
  String get assistantEditImageUrlDialogTitle;

  /// No description provided for @assistantEditImageUrlDialogHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. https://example.com/avatar.png'**
  String get assistantEditImageUrlDialogHint;

  /// No description provided for @assistantEditImageUrlDialogCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get assistantEditImageUrlDialogCancel;

  /// No description provided for @assistantEditImageUrlDialogSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get assistantEditImageUrlDialogSave;

  /// No description provided for @assistantEditQQAvatarDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Import from QQ'**
  String get assistantEditQQAvatarDialogTitle;

  /// No description provided for @assistantEditQQAvatarDialogHint.
  ///
  /// In en, this message translates to:
  /// **'Enter QQ number (5-12 digits)'**
  String get assistantEditQQAvatarDialogHint;

  /// No description provided for @assistantEditQQAvatarRandomButton.
  ///
  /// In en, this message translates to:
  /// **'Random One'**
  String get assistantEditQQAvatarRandomButton;

  /// No description provided for @assistantEditQQAvatarFailedMessage.
  ///
  /// In en, this message translates to:
  /// **'Failed to fetch random QQ avatar. Please try again.'**
  String get assistantEditQQAvatarFailedMessage;

  /// No description provided for @assistantEditQQAvatarDialogCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get assistantEditQQAvatarDialogCancel;

  /// No description provided for @assistantEditQQAvatarDialogSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get assistantEditQQAvatarDialogSave;

  /// No description provided for @assistantEditGalleryErrorMessage.
  ///
  /// In en, this message translates to:
  /// **'Unable to open gallery. Try entering an image URL.'**
  String get assistantEditGalleryErrorMessage;

  /// No description provided for @assistantEditGeneralErrorMessage.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. Try entering an image URL.'**
  String get assistantEditGeneralErrorMessage;

  /// No description provided for @providerDetailPageMultiKeyModeTitle.
  ///
  /// In en, this message translates to:
  /// **'Multi-Key Mode'**
  String get providerDetailPageMultiKeyModeTitle;

  /// No description provided for @providerDetailPageManageKeysButton.
  ///
  /// In en, this message translates to:
  /// **'Manage Keys'**
  String get providerDetailPageManageKeysButton;

  /// No description provided for @multiKeyPageTitle.
  ///
  /// In en, this message translates to:
  /// **'Multi-Key Manager'**
  String get multiKeyPageTitle;

  /// No description provided for @multiKeyPageDetect.
  ///
  /// In en, this message translates to:
  /// **'Detect'**
  String get multiKeyPageDetect;

  /// No description provided for @multiKeyPageAdd.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get multiKeyPageAdd;

  /// No description provided for @multiKeyPageAddHint.
  ///
  /// In en, this message translates to:
  /// **'Enter API keys, separated by comma or space'**
  String get multiKeyPageAddHint;

  /// No description provided for @multiKeyPageImportedSnackbar.
  ///
  /// In en, this message translates to:
  /// **'Imported {n} keys'**
  String multiKeyPageImportedSnackbar(int n);

  /// No description provided for @multiKeyPagePleaseAddModel.
  ///
  /// In en, this message translates to:
  /// **'Please add a model first'**
  String get multiKeyPagePleaseAddModel;

  /// No description provided for @multiKeyPageTotal.
  ///
  /// In en, this message translates to:
  /// **'Total'**
  String get multiKeyPageTotal;

  /// No description provided for @multiKeyPageNormal.
  ///
  /// In en, this message translates to:
  /// **'Normal'**
  String get multiKeyPageNormal;

  /// No description provided for @multiKeyPageError.
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get multiKeyPageError;

  /// No description provided for @multiKeyPageAccuracy.
  ///
  /// In en, this message translates to:
  /// **'Accuracy'**
  String get multiKeyPageAccuracy;

  /// No description provided for @multiKeyPageStrategyTitle.
  ///
  /// In en, this message translates to:
  /// **'Load Balancing Strategy'**
  String get multiKeyPageStrategyTitle;

  /// No description provided for @multiKeyPageStrategyRoundRobin.
  ///
  /// In en, this message translates to:
  /// **'Round Robin'**
  String get multiKeyPageStrategyRoundRobin;

  /// No description provided for @multiKeyPageStrategyPriority.
  ///
  /// In en, this message translates to:
  /// **'Priority'**
  String get multiKeyPageStrategyPriority;

  /// No description provided for @multiKeyPageStrategyLeastUsed.
  ///
  /// In en, this message translates to:
  /// **'Least Used'**
  String get multiKeyPageStrategyLeastUsed;

  /// No description provided for @multiKeyPageStrategyRandom.
  ///
  /// In en, this message translates to:
  /// **'Random'**
  String get multiKeyPageStrategyRandom;

  /// No description provided for @multiKeyPageNoKeys.
  ///
  /// In en, this message translates to:
  /// **'No API keys'**
  String get multiKeyPageNoKeys;

  /// No description provided for @multiKeyPageStatusActive.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get multiKeyPageStatusActive;

  /// No description provided for @multiKeyPageStatusDisabled.
  ///
  /// In en, this message translates to:
  /// **'Disabled'**
  String get multiKeyPageStatusDisabled;

  /// No description provided for @multiKeyPageStatusError.
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get multiKeyPageStatusError;

  /// No description provided for @multiKeyPageStatusRateLimited.
  ///
  /// In en, this message translates to:
  /// **'Rate Limited'**
  String get multiKeyPageStatusRateLimited;

  /// No description provided for @multiKeyPageEditAlias.
  ///
  /// In en, this message translates to:
  /// **'Edit Alias'**
  String get multiKeyPageEditAlias;

  /// No description provided for @multiKeyPageEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get multiKeyPageEdit;

  /// No description provided for @multiKeyPageKey.
  ///
  /// In en, this message translates to:
  /// **'API Key'**
  String get multiKeyPageKey;

  /// No description provided for @multiKeyPagePriority.
  ///
  /// In en, this message translates to:
  /// **'Priority (1–10)'**
  String get multiKeyPagePriority;

  /// No description provided for @multiKeyPageDuplicateKeyWarning.
  ///
  /// In en, this message translates to:
  /// **'This key already exists'**
  String get multiKeyPageDuplicateKeyWarning;

  /// No description provided for @multiKeyPageAlias.
  ///
  /// In en, this message translates to:
  /// **'Alias'**
  String get multiKeyPageAlias;

  /// No description provided for @multiKeyPageCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get multiKeyPageCancel;

  /// No description provided for @multiKeyPageSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get multiKeyPageSave;

  /// No description provided for @multiKeyPageDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get multiKeyPageDelete;

  /// No description provided for @assistantEditSystemPromptTitle.
  ///
  /// In en, this message translates to:
  /// **'System Prompt'**
  String get assistantEditSystemPromptTitle;

  /// No description provided for @assistantEditSystemPromptHint.
  ///
  /// In en, this message translates to:
  /// **'Enter system prompt…'**
  String get assistantEditSystemPromptHint;

  /// No description provided for @assistantEditSystemPromptImportButton.
  ///
  /// In en, this message translates to:
  /// **'Import file'**
  String get assistantEditSystemPromptImportButton;

  /// No description provided for @assistantEditSystemPromptImportSuccess.
  ///
  /// In en, this message translates to:
  /// **'System prompt updated from file'**
  String get assistantEditSystemPromptImportSuccess;

  /// No description provided for @assistantEditSystemPromptImportFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to import file'**
  String get assistantEditSystemPromptImportFailed;

  /// No description provided for @assistantEditSystemPromptImportEmpty.
  ///
  /// In en, this message translates to:
  /// **'File is empty'**
  String get assistantEditSystemPromptImportEmpty;

  /// No description provided for @assistantEditAvailableVariables.
  ///
  /// In en, this message translates to:
  /// **'Available variables:'**
  String get assistantEditAvailableVariables;

  /// No description provided for @assistantEditVariableDate.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get assistantEditVariableDate;

  /// No description provided for @assistantEditVariableTime.
  ///
  /// In en, this message translates to:
  /// **'Time'**
  String get assistantEditVariableTime;

  /// No description provided for @assistantEditVariableDatetime.
  ///
  /// In en, this message translates to:
  /// **'Datetime'**
  String get assistantEditVariableDatetime;

  /// No description provided for @assistantEditVariableModelId.
  ///
  /// In en, this message translates to:
  /// **'Model ID'**
  String get assistantEditVariableModelId;

  /// No description provided for @assistantEditVariableModelName.
  ///
  /// In en, this message translates to:
  /// **'Model Name'**
  String get assistantEditVariableModelName;

  /// No description provided for @assistantEditVariableLocale.
  ///
  /// In en, this message translates to:
  /// **'Locale'**
  String get assistantEditVariableLocale;

  /// No description provided for @assistantEditVariableTimezone.
  ///
  /// In en, this message translates to:
  /// **'Timezone'**
  String get assistantEditVariableTimezone;

  /// No description provided for @assistantEditVariableSystemVersion.
  ///
  /// In en, this message translates to:
  /// **'System Version'**
  String get assistantEditVariableSystemVersion;

  /// No description provided for @assistantEditVariableDeviceInfo.
  ///
  /// In en, this message translates to:
  /// **'Device Info'**
  String get assistantEditVariableDeviceInfo;

  /// No description provided for @assistantEditVariableBatteryLevel.
  ///
  /// In en, this message translates to:
  /// **'Battery Level'**
  String get assistantEditVariableBatteryLevel;

  /// No description provided for @assistantEditVariableNickname.
  ///
  /// In en, this message translates to:
  /// **'Nickname'**
  String get assistantEditVariableNickname;

  /// No description provided for @assistantEditVariableAssistantName.
  ///
  /// In en, this message translates to:
  /// **'Assistant Name'**
  String get assistantEditVariableAssistantName;

  /// No description provided for @assistantEditMessageTemplateTitle.
  ///
  /// In en, this message translates to:
  /// **'Message Template'**
  String get assistantEditMessageTemplateTitle;

  /// No description provided for @assistantEditVariableRole.
  ///
  /// In en, this message translates to:
  /// **'Role'**
  String get assistantEditVariableRole;

  /// No description provided for @assistantEditVariableMessage.
  ///
  /// In en, this message translates to:
  /// **'Message'**
  String get assistantEditVariableMessage;

  /// No description provided for @assistantEditPreviewTitle.
  ///
  /// In en, this message translates to:
  /// **'Preview'**
  String get assistantEditPreviewTitle;

  /// No description provided for @assistantEditPromptTimeVarWarning.
  ///
  /// In en, this message translates to:
  /// **'Using time variables in the system prompt makes the beginning of every request different, so prompt caching cannot hit and both cost and time-to-first-token go up. If the model needs to know the current time, use the \"Append current time\" switch below.'**
  String get assistantEditPromptTimeVarWarning;

  /// No description provided for @assistantEditPromptAppendTimeTitle.
  ///
  /// In en, this message translates to:
  /// **'Append current time'**
  String get assistantEditPromptAppendTimeTitle;

  /// No description provided for @assistantEditPromptAppendTimeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Append the send time to the end of each user message. Time stays at the end of the request, so prompt caching is unaffected.'**
  String get assistantEditPromptAppendTimeSubtitle;

  /// No description provided for @assistantEditPromptAppendTimeInfoTitle.
  ///
  /// In en, this message translates to:
  /// **'Appended time format'**
  String get assistantEditPromptAppendTimeInfoTitle;

  /// No description provided for @assistantEditPromptAppendTimeInfoBody.
  ///
  /// In en, this message translates to:
  /// **'When enabled, a blank line and then the following tag are appended at the end of each user message:\n\n{example}\n\nThe timestamp is that message’s own send time, so it stays stable when you retry.'**
  String assistantEditPromptAppendTimeInfoBody(String example);

  /// No description provided for @assistantEditPromptAppendTimeInfoClose.
  ///
  /// In en, this message translates to:
  /// **'Got it'**
  String get assistantEditPromptAppendTimeInfoClose;

  /// No description provided for @assistantEditPromptTimeVarDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'System prompt contains time variables'**
  String get assistantEditPromptTimeVarDialogTitle;

  /// No description provided for @assistantEditPromptTimeVarDialogBody.
  ///
  /// In en, this message translates to:
  /// **'Your system prompt uses {variables}. The system prompt is re-rendered on every request, so time variables make the beginning of every request different and prompt caching cannot hit. Consider removing these variables and using \"Append current time\" instead — it puts the time at the end of the request and does not affect the prefix.'**
  String assistantEditPromptTimeVarDialogBody(String variables);

  /// No description provided for @assistantEditPromptTimeVarDialogRemove.
  ///
  /// In en, this message translates to:
  /// **'Go remove'**
  String get assistantEditPromptTimeVarDialogRemove;

  /// No description provided for @assistantEditPromptTimeVarDialogKeep.
  ///
  /// In en, this message translates to:
  /// **'Enable anyway'**
  String get assistantEditPromptTimeVarDialogKeep;

  /// No description provided for @codeBlockPreviewButton.
  ///
  /// In en, this message translates to:
  /// **'Preview'**
  String get codeBlockPreviewButton;

  /// No description provided for @codeBlockSaveAsButton.
  ///
  /// In en, this message translates to:
  /// **'Save as file'**
  String get codeBlockSaveAsButton;

  /// No description provided for @codeBlockCollapseButton.
  ///
  /// In en, this message translates to:
  /// **'Collapse'**
  String get codeBlockCollapseButton;

  /// No description provided for @codeBlockExpandButton.
  ///
  /// In en, this message translates to:
  /// **'Expand'**
  String get codeBlockExpandButton;

  /// No description provided for @codeBlockDefaultFileNameStem.
  ///
  /// In en, this message translates to:
  /// **'code'**
  String get codeBlockDefaultFileNameStem;

  /// No description provided for @markdownTableLabel.
  ///
  /// In en, this message translates to:
  /// **'Table'**
  String get markdownTableLabel;

  /// No description provided for @markdownTableExportCsvTooltip.
  ///
  /// In en, this message translates to:
  /// **'Export CSV'**
  String get markdownTableExportCsvTooltip;

  /// No description provided for @markdownTableSaveImageTooltip.
  ///
  /// In en, this message translates to:
  /// **'Save to Gallery'**
  String get markdownTableSaveImageTooltip;

  /// No description provided for @markdownTableDefaultFileNameStem.
  ///
  /// In en, this message translates to:
  /// **'table'**
  String get markdownTableDefaultFileNameStem;

  /// No description provided for @markdownTableCopiedCsvSnackbar.
  ///
  /// In en, this message translates to:
  /// **'CSV copied. Long press Copy to copy as image.'**
  String get markdownTableCopiedCsvSnackbar;

  /// No description provided for @markdownTableCopiedMarkdownSnackbar.
  ///
  /// In en, this message translates to:
  /// **'Table copied.'**
  String get markdownTableCopiedMarkdownSnackbar;

  /// No description provided for @codeBlockCollapsedLines.
  ///
  /// In en, this message translates to:
  /// **'… {n} lines folded'**
  String codeBlockCollapsedLines(int n);

  /// No description provided for @htmlPreviewNotSupportedOnLinux.
  ///
  /// In en, this message translates to:
  /// **'HTML preview is not supported on Linux'**
  String get htmlPreviewNotSupportedOnLinux;

  /// No description provided for @assistantEditSampleUser.
  ///
  /// In en, this message translates to:
  /// **'User'**
  String get assistantEditSampleUser;

  /// No description provided for @assistantEditSampleMessage.
  ///
  /// In en, this message translates to:
  /// **'Hello there'**
  String get assistantEditSampleMessage;

  /// No description provided for @assistantEditSampleReply.
  ///
  /// In en, this message translates to:
  /// **'Hello, how can I help you?'**
  String get assistantEditSampleReply;

  /// No description provided for @assistantEditMcpNoServersMessage.
  ///
  /// In en, this message translates to:
  /// **'No running MCP servers'**
  String get assistantEditMcpNoServersMessage;

  /// No description provided for @assistantEditMcpConnectedTag.
  ///
  /// In en, this message translates to:
  /// **'Connected'**
  String get assistantEditMcpConnectedTag;

  /// No description provided for @assistantEditMcpToolsCountTag.
  ///
  /// In en, this message translates to:
  /// **'Tools: {enabled}/{total}'**
  String assistantEditMcpToolsCountTag(String enabled, String total);

  /// No description provided for @assistantEditModelUseGlobalDefault.
  ///
  /// In en, this message translates to:
  /// **'Use global default'**
  String get assistantEditModelUseGlobalDefault;

  /// No description provided for @assistantSettingsPageTitle.
  ///
  /// In en, this message translates to:
  /// **'Assistant Settings'**
  String get assistantSettingsPageTitle;

  /// No description provided for @assistantSettingsCopyButton.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get assistantSettingsCopyButton;

  /// No description provided for @assistantSettingsCopySuccess.
  ///
  /// In en, this message translates to:
  /// **'Assistant copied'**
  String get assistantSettingsCopySuccess;

  /// No description provided for @assistantSettingsCopySuffix.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get assistantSettingsCopySuffix;

  /// No description provided for @assistantSettingsDeleteButton.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get assistantSettingsDeleteButton;

  /// No description provided for @assistantSettingsEditButton.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get assistantSettingsEditButton;

  /// No description provided for @assistantSettingsAddSheetTitle.
  ///
  /// In en, this message translates to:
  /// **'Assistant Name'**
  String get assistantSettingsAddSheetTitle;

  /// No description provided for @assistantSettingsAddSheetHint.
  ///
  /// In en, this message translates to:
  /// **'Enter a name'**
  String get assistantSettingsAddSheetHint;

  /// No description provided for @assistantSettingsAddSheetCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get assistantSettingsAddSheetCancel;

  /// No description provided for @assistantSettingsAddSheetSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get assistantSettingsAddSheetSave;

  /// No description provided for @desktopAssistantsListTitle.
  ///
  /// In en, this message translates to:
  /// **'Assistants'**
  String get desktopAssistantsListTitle;

  /// No description provided for @desktopSidebarTabAssistants.
  ///
  /// In en, this message translates to:
  /// **'Assistants'**
  String get desktopSidebarTabAssistants;

  /// No description provided for @desktopSidebarTabTopics.
  ///
  /// In en, this message translates to:
  /// **'Topics'**
  String get desktopSidebarTabTopics;

  /// No description provided for @desktopTrayMenuShowWindow.
  ///
  /// In en, this message translates to:
  /// **'Show Window'**
  String get desktopTrayMenuShowWindow;

  /// No description provided for @desktopTrayMenuExit.
  ///
  /// In en, this message translates to:
  /// **'Exit'**
  String get desktopTrayMenuExit;

  /// No description provided for @hotkeyToggleAppVisibility.
  ///
  /// In en, this message translates to:
  /// **'Show/Hide App'**
  String get hotkeyToggleAppVisibility;

  /// No description provided for @hotkeyCloseWindow.
  ///
  /// In en, this message translates to:
  /// **'Close Window'**
  String get hotkeyCloseWindow;

  /// No description provided for @hotkeyOpenSettings.
  ///
  /// In en, this message translates to:
  /// **'Open Settings'**
  String get hotkeyOpenSettings;

  /// No description provided for @hotkeyNewTopic.
  ///
  /// In en, this message translates to:
  /// **'New Topic'**
  String get hotkeyNewTopic;

  /// No description provided for @hotkeySwitchModel.
  ///
  /// In en, this message translates to:
  /// **'Switch Model'**
  String get hotkeySwitchModel;

  /// No description provided for @hotkeyToggleAssistantPanel.
  ///
  /// In en, this message translates to:
  /// **'Toggle Assistants'**
  String get hotkeyToggleAssistantPanel;

  /// No description provided for @hotkeyToggleTopicPanel.
  ///
  /// In en, this message translates to:
  /// **'Toggle Topics'**
  String get hotkeyToggleTopicPanel;

  /// No description provided for @hotkeysPressShortcut.
  ///
  /// In en, this message translates to:
  /// **'Press a shortcut'**
  String get hotkeysPressShortcut;

  /// No description provided for @hotkeysResetDefault.
  ///
  /// In en, this message translates to:
  /// **'Reset to default'**
  String get hotkeysResetDefault;

  /// No description provided for @hotkeysClearShortcut.
  ///
  /// In en, this message translates to:
  /// **'Clear shortcut'**
  String get hotkeysClearShortcut;

  /// No description provided for @hotkeysResetAll.
  ///
  /// In en, this message translates to:
  /// **'Reset all to defaults'**
  String get hotkeysResetAll;

  /// No description provided for @assistantEditTemperatureTitle.
  ///
  /// In en, this message translates to:
  /// **'Temperature'**
  String get assistantEditTemperatureTitle;

  /// No description provided for @assistantEditTopPTitle.
  ///
  /// In en, this message translates to:
  /// **'Top-p'**
  String get assistantEditTopPTitle;

  /// No description provided for @assistantSettingsDeleteDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete Assistant'**
  String get assistantSettingsDeleteDialogTitle;

  /// No description provided for @assistantSettingsDeleteDialogContent.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete this assistant? This action cannot be undone.'**
  String get assistantSettingsDeleteDialogContent;

  /// No description provided for @assistantSettingsDeleteDialogCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get assistantSettingsDeleteDialogCancel;

  /// No description provided for @assistantSettingsDeleteDialogConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get assistantSettingsDeleteDialogConfirm;

  /// No description provided for @assistantSettingsAtLeastOneAssistantRequired.
  ///
  /// In en, this message translates to:
  /// **'At least one assistant is required'**
  String get assistantSettingsAtLeastOneAssistantRequired;

  /// No description provided for @mcpAssistantSheetTitle.
  ///
  /// In en, this message translates to:
  /// **'MCP Servers'**
  String get mcpAssistantSheetTitle;

  /// No description provided for @mcpAssistantSheetSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Servers enabled for this assistant'**
  String get mcpAssistantSheetSubtitle;

  /// No description provided for @mcpAssistantSheetSelectAll.
  ///
  /// In en, this message translates to:
  /// **'Select All'**
  String get mcpAssistantSheetSelectAll;

  /// No description provided for @mcpAssistantSheetClearAll.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get mcpAssistantSheetClearAll;

  /// No description provided for @backupPageTitle.
  ///
  /// In en, this message translates to:
  /// **'Backup & Restore'**
  String get backupPageTitle;

  /// No description provided for @backupPageWebDavTab.
  ///
  /// In en, this message translates to:
  /// **'WebDAV'**
  String get backupPageWebDavTab;

  /// No description provided for @backupPageImportExportTab.
  ///
  /// In en, this message translates to:
  /// **'Import/Export'**
  String get backupPageImportExportTab;

  /// No description provided for @backupPageWebDavServerUrl.
  ///
  /// In en, this message translates to:
  /// **'WebDAV Server URL'**
  String get backupPageWebDavServerUrl;

  /// No description provided for @backupPageUsername.
  ///
  /// In en, this message translates to:
  /// **'Username'**
  String get backupPageUsername;

  /// No description provided for @backupPagePassword.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get backupPagePassword;

  /// No description provided for @backupPagePath.
  ///
  /// In en, this message translates to:
  /// **'Path'**
  String get backupPagePath;

  /// No description provided for @backupPageChatsLabel.
  ///
  /// In en, this message translates to:
  /// **'Chats'**
  String get backupPageChatsLabel;

  /// No description provided for @backupPageFilesLabel.
  ///
  /// In en, this message translates to:
  /// **'Files'**
  String get backupPageFilesLabel;

  /// No description provided for @backupPageTestDone.
  ///
  /// In en, this message translates to:
  /// **'Test done'**
  String get backupPageTestDone;

  /// No description provided for @backupPageTestConnection.
  ///
  /// In en, this message translates to:
  /// **'Test'**
  String get backupPageTestConnection;

  /// No description provided for @backupPageRestartRequired.
  ///
  /// In en, this message translates to:
  /// **'Restart Required'**
  String get backupPageRestartRequired;

  /// No description provided for @backupPageRestartContent.
  ///
  /// In en, this message translates to:
  /// **'Import successful. Restart Kelivo to apply it safely.'**
  String get backupPageRestartContent;

  /// No description provided for @backupPageRestartContentWithSkipped.
  ///
  /// In en, this message translates to:
  /// **'Import completed, but {count} conversations with invalid message ordering were skipped. Restart Kelivo to apply the imported data safely.'**
  String backupPageRestartContentWithSkipped(int count);

  /// No description provided for @restartAppFailedMessage.
  ///
  /// In en, this message translates to:
  /// **'Kelivo could not restart automatically. Fully close it, then open it again.'**
  String get restartAppFailedMessage;

  /// No description provided for @backupRestoreRolledBackTitle.
  ///
  /// In en, this message translates to:
  /// **'Restore was rolled back'**
  String get backupRestoreRolledBackTitle;

  /// No description provided for @backupRestoreRolledBackContent.
  ///
  /// In en, this message translates to:
  /// **'The restore could not be completed. Kelivo verified and kept your previous data.'**
  String get backupRestoreRolledBackContent;

  /// No description provided for @backupRestoreFailureTitle.
  ///
  /// In en, this message translates to:
  /// **'Restore requires attention'**
  String get backupRestoreFailureTitle;

  /// No description provided for @backupRestoreFailureContent.
  ///
  /// In en, this message translates to:
  /// **'Kelivo could not verify a complete old or new data set, so chat data was not opened. Close Kelivo and try again. If this repeats, keep the diagnostic code for support.'**
  String get backupRestoreFailureContent;

  /// No description provided for @backupRestoreBusinessLeaseUnavailableTitle.
  ///
  /// In en, this message translates to:
  /// **'Kelivo is already running'**
  String get backupRestoreBusinessLeaseUnavailableTitle;

  /// No description provided for @backupRestoreBusinessLeaseUnavailableContent.
  ///
  /// In en, this message translates to:
  /// **'Kelivo\'s data is still in use by another app process. Close any other Kelivo window, then restart. Your chat data has not been opened by this process.'**
  String get backupRestoreBusinessLeaseUnavailableContent;

  /// No description provided for @backupRestoreFailureRestartButton.
  ///
  /// In en, this message translates to:
  /// **'Restart Kelivo'**
  String get backupRestoreFailureRestartButton;

  /// No description provided for @backupRestoreFailureCopyButton.
  ///
  /// In en, this message translates to:
  /// **'Copy diagnostic code'**
  String get backupRestoreFailureCopyButton;

  /// No description provided for @backupRestoreFailureCopied.
  ///
  /// In en, this message translates to:
  /// **'Diagnostic code copied'**
  String get backupRestoreFailureCopied;

  /// No description provided for @backupRestoreFailureDiagnostic.
  ///
  /// In en, this message translates to:
  /// **'Diagnostic code: {code}'**
  String backupRestoreFailureDiagnostic(String code);

  /// No description provided for @startupRecoveryMoreOptions.
  ///
  /// In en, this message translates to:
  /// **'More recovery options'**
  String get startupRecoveryMoreOptions;

  /// No description provided for @startupRecoveryRepairButton.
  ///
  /// In en, this message translates to:
  /// **'Repair and restart'**
  String get startupRecoveryRepairButton;

  /// No description provided for @startupRecoveryExportButton.
  ///
  /// In en, this message translates to:
  /// **'Export a copy of my data'**
  String get startupRecoveryExportButton;

  /// No description provided for @startupRecoveryResetButton.
  ///
  /// In en, this message translates to:
  /// **'Reset data'**
  String get startupRecoveryResetButton;

  /// No description provided for @startupRecoveryBusy.
  ///
  /// In en, this message translates to:
  /// **'Working…'**
  String get startupRecoveryBusy;

  /// No description provided for @startupRecoveryExportSucceeded.
  ///
  /// In en, this message translates to:
  /// **'A copy of your data was saved.'**
  String get startupRecoveryExportSucceeded;

  /// No description provided for @startupRecoveryExportFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not export a copy of your data.'**
  String get startupRecoveryExportFailed;

  /// No description provided for @startupRecoveryRepairFailed.
  ///
  /// In en, this message translates to:
  /// **'Repair could not fix this. Export a copy of your data, then reset.'**
  String get startupRecoveryRepairFailed;

  /// No description provided for @startupRecoveryResetFailed.
  ///
  /// In en, this message translates to:
  /// **'Reset failed. Fully close Kelivo, then open it again.'**
  String get startupRecoveryResetFailed;

  /// No description provided for @startupRecoveryResetDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Reset all data?'**
  String get startupRecoveryResetDialogTitle;

  /// No description provided for @startupRecoveryResetDialogContent.
  ///
  /// In en, this message translates to:
  /// **'This permanently deletes Kelivo\'s database on this device and starts fresh. If you might need this data, export a copy first. This cannot be undone.'**
  String get startupRecoveryResetDialogContent;

  /// No description provided for @startupRecoveryResetDialogConfirm.
  ///
  /// In en, this message translates to:
  /// **'Reset and restart'**
  String get startupRecoveryResetDialogConfirm;

  /// No description provided for @startupRecoveryResetDialogCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get startupRecoveryResetDialogCancel;

  /// No description provided for @startupRecoveryWhatFailed.
  ///
  /// In en, this message translates to:
  /// **'What failed'**
  String get startupRecoveryWhatFailed;

  /// No description provided for @startupRecoveryStageLabel.
  ///
  /// In en, this message translates to:
  /// **'Stage'**
  String get startupRecoveryStageLabel;

  /// No description provided for @startupRecoveryStageRestore.
  ///
  /// In en, this message translates to:
  /// **'Restore gate'**
  String get startupRecoveryStageRestore;

  /// No description provided for @startupRecoveryStageDatabase.
  ///
  /// In en, this message translates to:
  /// **'Database startup'**
  String get startupRecoveryStageDatabase;

  /// No description provided for @startupRecoveryDiagnosticLabel.
  ///
  /// In en, this message translates to:
  /// **'Diagnostic code'**
  String get startupRecoveryDiagnosticLabel;

  /// No description provided for @startupRecoverySchemaLabel.
  ///
  /// In en, this message translates to:
  /// **'Database version'**
  String get startupRecoverySchemaLabel;

  /// No description provided for @startupRecoverySchemaValue.
  ///
  /// In en, this message translates to:
  /// **'{installed} on disk · {expected} expected by this build'**
  String startupRecoverySchemaValue(String installed, int expected);

  /// No description provided for @startupRecoveryAppVersionLabel.
  ///
  /// In en, this message translates to:
  /// **'App'**
  String get startupRecoveryAppVersionLabel;

  /// No description provided for @startupRecoveryUnknownValue.
  ///
  /// In en, this message translates to:
  /// **'unknown'**
  String get startupRecoveryUnknownValue;

  /// No description provided for @startupRecoveryCollecting.
  ///
  /// In en, this message translates to:
  /// **'Collecting diagnostics…'**
  String get startupRecoveryCollecting;

  /// No description provided for @startupRecoveryShowDetails.
  ///
  /// In en, this message translates to:
  /// **'Show technical details'**
  String get startupRecoveryShowDetails;

  /// No description provided for @startupRecoveryHideDetails.
  ///
  /// In en, this message translates to:
  /// **'Hide technical details'**
  String get startupRecoveryHideDetails;

  /// No description provided for @startupRecoveryCopyReport.
  ///
  /// In en, this message translates to:
  /// **'Copy full report'**
  String get startupRecoveryCopyReport;

  /// No description provided for @startupRecoveryReportCopied.
  ///
  /// In en, this message translates to:
  /// **'Full report copied'**
  String get startupRecoveryReportCopied;

  /// No description provided for @startupRecoveryShareReport.
  ///
  /// In en, this message translates to:
  /// **'Export report'**
  String get startupRecoveryShareReport;

  /// No description provided for @startupRecoveryReportStored.
  ///
  /// In en, this message translates to:
  /// **'A copy of this report was saved to {path}'**
  String startupRecoveryReportStored(String path);

  /// No description provided for @startupRecoveryReportSaved.
  ///
  /// In en, this message translates to:
  /// **'Report saved to {path}'**
  String startupRecoveryReportSaved(String path);

  /// No description provided for @startupRecoveryReportShared.
  ///
  /// In en, this message translates to:
  /// **'Report exported.'**
  String get startupRecoveryReportShared;

  /// No description provided for @startupRecoveryReportSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not export the report.'**
  String get startupRecoveryReportSaveFailed;

  /// No description provided for @startupRecoverySectionDataTitle.
  ///
  /// In en, this message translates to:
  /// **'Your data'**
  String get startupRecoverySectionDataTitle;

  /// No description provided for @startupRecoverySectionDataBody.
  ///
  /// In en, this message translates to:
  /// **'Nothing has been deleted. Save a copy somewhere safe before trying anything below.'**
  String get startupRecoverySectionDataBody;

  /// No description provided for @startupRecoveryExportSavedTo.
  ///
  /// In en, this message translates to:
  /// **'A copy of your data was saved to {path}'**
  String startupRecoveryExportSavedTo(String path);

  /// No description provided for @startupRecoverySectionRepairTitle.
  ///
  /// In en, this message translates to:
  /// **'Diagnose and repair'**
  String get startupRecoverySectionRepairTitle;

  /// No description provided for @startupRecoverySectionRepairBody.
  ///
  /// In en, this message translates to:
  /// **'The integrity check only reads the database. Repair clears leftover metadata from an interrupted update and retries startup; it never deletes chats.'**
  String get startupRecoverySectionRepairBody;

  /// No description provided for @startupRecoveryIntegrityButton.
  ///
  /// In en, this message translates to:
  /// **'Check database integrity'**
  String get startupRecoveryIntegrityButton;

  /// No description provided for @startupRecoveryIntegrityHealthy.
  ///
  /// In en, this message translates to:
  /// **'SQLite found no damage in the database file.'**
  String get startupRecoveryIntegrityHealthy;

  /// No description provided for @startupRecoveryIntegrityDamaged.
  ///
  /// In en, this message translates to:
  /// **'SQLite reported problems — {detail}'**
  String startupRecoveryIntegrityDamaged(String detail);

  /// No description provided for @startupRecoveryIntegrityMissing.
  ///
  /// In en, this message translates to:
  /// **'No database file was found in the data folder.'**
  String get startupRecoveryIntegrityMissing;

  /// No description provided for @startupRecoveryIntegrityFailed.
  ///
  /// In en, this message translates to:
  /// **'The integrity check could not run.'**
  String get startupRecoveryIntegrityFailed;

  /// No description provided for @startupRecoveryDangerZone.
  ///
  /// In en, this message translates to:
  /// **'Danger zone'**
  String get startupRecoveryDangerZone;

  /// No description provided for @startupRecoveryDangerBody.
  ///
  /// In en, this message translates to:
  /// **'Resetting permanently deletes Kelivo\'s database on this device. Export a copy of your data first — a reset also destroys the evidence needed to fix the underlying problem.'**
  String get startupRecoveryDangerBody;

  /// No description provided for @startupRecoveryResetAcknowledge.
  ///
  /// In en, this message translates to:
  /// **'I exported a copy, or I do not need this data.'**
  String get startupRecoveryResetAcknowledge;

  /// No description provided for @startupDatabaseUpdateRequiredTitle.
  ///
  /// In en, this message translates to:
  /// **'Update Kelivo to continue'**
  String get startupDatabaseUpdateRequiredTitle;

  /// No description provided for @startupDatabaseUpdateRequiredContent.
  ///
  /// In en, this message translates to:
  /// **'The chat database on this device was created by a newer version of Kelivo and cannot be opened by this version. Your data has not been changed. Install the latest version of Kelivo, then open it again.'**
  String get startupDatabaseUpdateRequiredContent;

  /// No description provided for @startupDatabaseUpdateRequiredDowngradeTitle.
  ///
  /// In en, this message translates to:
  /// **'If you need an older version'**
  String get startupDatabaseUpdateRequiredDowngradeTitle;

  /// No description provided for @startupDatabaseUpdateRequiredDowngradeIntro.
  ///
  /// In en, this message translates to:
  /// **'This version cannot open the database on this device. If you must keep using an older version, follow the steps below. Do not delete or overwrite the data here until you have a backup.'**
  String get startupDatabaseUpdateRequiredDowngradeIntro;

  /// No description provided for @startupDatabaseUpdateRequiredDowngradeStep1.
  ///
  /// In en, this message translates to:
  /// **'Install and open the latest Kelivo, then export a backup from Settings → Backup.'**
  String get startupDatabaseUpdateRequiredDowngradeStep1;

  /// No description provided for @startupDatabaseUpdateRequiredDowngradeStep2.
  ///
  /// In en, this message translates to:
  /// **'Open {url} and convert that backup to the older version you want to use.'**
  String startupDatabaseUpdateRequiredDowngradeStep2(String url);

  /// No description provided for @startupDatabaseUpdateRequiredDowngradeStep3.
  ///
  /// In en, this message translates to:
  /// **'After you have confirmed the data on this device is backed up, install the older version and import the converted backup.'**
  String get startupDatabaseUpdateRequiredDowngradeStep3;

  /// No description provided for @startupDatabaseUpdateRequiredOpenTool.
  ///
  /// In en, this message translates to:
  /// **'Open conversion tool'**
  String get startupDatabaseUpdateRequiredOpenTool;

  /// No description provided for @backupPageRestoreFailedMessage.
  ///
  /// In en, this message translates to:
  /// **'Restore failed: {error}'**
  String backupPageRestoreFailedMessage(String error);

  /// No description provided for @backupPageExportFailedMessage.
  ///
  /// In en, this message translates to:
  /// **'Export failed: {error}'**
  String backupPageExportFailedMessage(String error);

  /// No description provided for @backupPageOK.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get backupPageOK;

  /// No description provided for @backupPageCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get backupPageCancel;

  /// No description provided for @backupPageSelectImportMode.
  ///
  /// In en, this message translates to:
  /// **'Select Import Mode'**
  String get backupPageSelectImportMode;

  /// No description provided for @backupPageSelectImportModeDescription.
  ///
  /// In en, this message translates to:
  /// **'Choose a restore mode. The chat and file switches determine which components are included.'**
  String get backupPageSelectImportModeDescription;

  /// No description provided for @backupPageOverwriteMode.
  ///
  /// In en, this message translates to:
  /// **'Complete Overwrite'**
  String get backupPageOverwriteMode;

  /// No description provided for @backupPageOverwriteModeDescription.
  ///
  /// In en, this message translates to:
  /// **'Replace the selected components; keep unselected components and unrelated local settings'**
  String get backupPageOverwriteModeDescription;

  /// No description provided for @backupPageMergeMode.
  ///
  /// In en, this message translates to:
  /// **'Merge'**
  String get backupPageMergeMode;

  /// No description provided for @backupPageMergeModeDescription.
  ///
  /// In en, this message translates to:
  /// **'Keep local data and add backup data. Identical conversations are skipped and conflicting conversations receive new IDs.'**
  String get backupPageMergeModeDescription;

  /// No description provided for @backupPageRestore.
  ///
  /// In en, this message translates to:
  /// **'Restore'**
  String get backupPageRestore;

  /// No description provided for @backupPageForwardCompatTitle.
  ///
  /// In en, this message translates to:
  /// **'Backup is from a newer version'**
  String get backupPageForwardCompatTitle;

  /// No description provided for @backupPageForwardCompatBody.
  ///
  /// In en, this message translates to:
  /// **'This backup was created by a newer version of Kelivo (data format {backupVersion}; this version supports {currentVersion}), and it does not say whether older versions can read it.\n\nYou can continue: anything this version does not recognise will be skipped, and the backup file itself is not modified. But if the newer version changed how existing data is stored, some content may be imported incorrectly.\n\nUpdating Kelivo first is the safer choice.'**
  String backupPageForwardCompatBody(int backupVersion, int currentVersion);

  /// No description provided for @backupPageForwardCompatContinue.
  ///
  /// In en, this message translates to:
  /// **'Import anyway'**
  String get backupPageForwardCompatContinue;

  /// No description provided for @backupPageForwardCompatCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get backupPageForwardCompatCancel;

  /// No description provided for @backupPageSchemaTooNewMessage.
  ///
  /// In en, this message translates to:
  /// **'This backup was created by a newer version of Kelivo and cannot be read by this version. Please update Kelivo and try again.'**
  String get backupPageSchemaTooNewMessage;

  /// No description provided for @backupPageBackupUploaded.
  ///
  /// In en, this message translates to:
  /// **'Backup uploaded'**
  String get backupPageBackupUploaded;

  /// No description provided for @backupPageBackup.
  ///
  /// In en, this message translates to:
  /// **'Backup'**
  String get backupPageBackup;

  /// No description provided for @backupPageExporting.
  ///
  /// In en, this message translates to:
  /// **'Exporting...'**
  String get backupPageExporting;

  /// No description provided for @backupProgressCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get backupProgressCancel;

  /// No description provided for @backupProgressCancelled.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get backupProgressCancelled;

  /// No description provided for @backupProgressPreparing.
  ///
  /// In en, this message translates to:
  /// **'Preparing'**
  String get backupProgressPreparing;

  /// No description provided for @backupProgressSnapshotting.
  ///
  /// In en, this message translates to:
  /// **'Creating database snapshot'**
  String get backupProgressSnapshotting;

  /// No description provided for @backupProgressPacking.
  ///
  /// In en, this message translates to:
  /// **'Packing'**
  String get backupProgressPacking;

  /// No description provided for @backupProgressVerifying.
  ///
  /// In en, this message translates to:
  /// **'Verifying'**
  String get backupProgressVerifying;

  /// No description provided for @backupProgressUploading.
  ///
  /// In en, this message translates to:
  /// **'Uploading'**
  String get backupProgressUploading;

  /// No description provided for @backupProgressDownloading.
  ///
  /// In en, this message translates to:
  /// **'Downloading'**
  String get backupProgressDownloading;

  /// No description provided for @backupProgressExtracting.
  ///
  /// In en, this message translates to:
  /// **'Extracting'**
  String get backupProgressExtracting;

  /// No description provided for @backupProgressValidating.
  ///
  /// In en, this message translates to:
  /// **'Validating'**
  String get backupProgressValidating;

  /// No description provided for @backupProgressReadingSettings.
  ///
  /// In en, this message translates to:
  /// **'Reading settings'**
  String get backupProgressReadingSettings;

  /// No description provided for @backupProgressStaging.
  ///
  /// In en, this message translates to:
  /// **'Staging'**
  String get backupProgressStaging;

  /// No description provided for @backupProgressCommitting.
  ///
  /// In en, this message translates to:
  /// **'Committing'**
  String get backupProgressCommitting;

  /// No description provided for @backupProgressImportingSessions.
  ///
  /// In en, this message translates to:
  /// **'Importing sessions'**
  String get backupProgressImportingSessions;

  /// No description provided for @backupProgressImportingMessages.
  ///
  /// In en, this message translates to:
  /// **'Importing messages'**
  String get backupProgressImportingMessages;

  /// No description provided for @backupProgressMaterializingFiles.
  ///
  /// In en, this message translates to:
  /// **'Writing files'**
  String get backupProgressMaterializingFiles;

  /// No description provided for @backupProgressListingRemote.
  ///
  /// In en, this message translates to:
  /// **'Listing remote backups'**
  String get backupProgressListingRemote;

  /// No description provided for @backupProgressFinalizing.
  ///
  /// In en, this message translates to:
  /// **'Finishing'**
  String get backupProgressFinalizing;

  /// No description provided for @backupProgressBytes.
  ///
  /// In en, this message translates to:
  /// **'{done} / {total}'**
  String backupProgressBytes(String done, String total);

  /// No description provided for @backupProgressItems.
  ///
  /// In en, this message translates to:
  /// **'{done} / {total}'**
  String backupProgressItems(String done, String total);

  /// No description provided for @backupPageExportToFile.
  ///
  /// In en, this message translates to:
  /// **'Export to File'**
  String get backupPageExportToFile;

  /// No description provided for @backupPageExportToFileSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Export app data to a file'**
  String get backupPageExportToFileSubtitle;

  /// No description provided for @backupPageImportBackupFile.
  ///
  /// In en, this message translates to:
  /// **'Import Backup File'**
  String get backupPageImportBackupFile;

  /// No description provided for @backupPageImportBackupFileSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Import a local backup file'**
  String get backupPageImportBackupFileSubtitle;

  /// No description provided for @backupPageImportFromOtherApps.
  ///
  /// In en, this message translates to:
  /// **'Import from Other Apps'**
  String get backupPageImportFromOtherApps;

  /// No description provided for @backupPageNotSupportedYet.
  ///
  /// In en, this message translates to:
  /// **'Not supported yet'**
  String get backupPageNotSupportedYet;

  /// No description provided for @backupPageRemoteBackups.
  ///
  /// In en, this message translates to:
  /// **'Remote Backups'**
  String get backupPageRemoteBackups;

  /// No description provided for @backupPageNoBackups.
  ///
  /// In en, this message translates to:
  /// **'No backups'**
  String get backupPageNoBackups;

  /// No description provided for @backupPageRestoreTooltip.
  ///
  /// In en, this message translates to:
  /// **'Restore'**
  String get backupPageRestoreTooltip;

  /// No description provided for @backupPageDeleteTooltip.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get backupPageDeleteTooltip;

  /// No description provided for @backupPageDeleteConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Confirm Deletion'**
  String get backupPageDeleteConfirmTitle;

  /// No description provided for @backupPageDeleteConfirmContent.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete remote backup \"{name}\"? This action cannot be undone.'**
  String backupPageDeleteConfirmContent(Object name);

  /// No description provided for @backupPageBackupManagement.
  ///
  /// In en, this message translates to:
  /// **'Backup Management'**
  String get backupPageBackupManagement;

  /// No description provided for @backupPageWebDavBackup.
  ///
  /// In en, this message translates to:
  /// **'WebDAV Backup'**
  String get backupPageWebDavBackup;

  /// No description provided for @backupPageWebDavServerSettings.
  ///
  /// In en, this message translates to:
  /// **'WebDAV Server Settings'**
  String get backupPageWebDavServerSettings;

  /// No description provided for @backupPageS3Backup.
  ///
  /// In en, this message translates to:
  /// **'S3 Backup'**
  String get backupPageS3Backup;

  /// No description provided for @backupPageS3ServerSettings.
  ///
  /// In en, this message translates to:
  /// **'S3 Settings'**
  String get backupPageS3ServerSettings;

  /// No description provided for @backupPageS3Endpoint.
  ///
  /// In en, this message translates to:
  /// **'Endpoint'**
  String get backupPageS3Endpoint;

  /// No description provided for @backupPageS3Region.
  ///
  /// In en, this message translates to:
  /// **'Region'**
  String get backupPageS3Region;

  /// No description provided for @backupPageS3Bucket.
  ///
  /// In en, this message translates to:
  /// **'Bucket'**
  String get backupPageS3Bucket;

  /// No description provided for @backupPageS3AccessKeyId.
  ///
  /// In en, this message translates to:
  /// **'Access Key ID'**
  String get backupPageS3AccessKeyId;

  /// No description provided for @backupPageS3SecretAccessKey.
  ///
  /// In en, this message translates to:
  /// **'Secret Access Key'**
  String get backupPageS3SecretAccessKey;

  /// No description provided for @backupPageS3SessionToken.
  ///
  /// In en, this message translates to:
  /// **'Session Token (Optional)'**
  String get backupPageS3SessionToken;

  /// No description provided for @backupPageS3Prefix.
  ///
  /// In en, this message translates to:
  /// **'Prefix'**
  String get backupPageS3Prefix;

  /// No description provided for @backupPageS3PathStyle.
  ///
  /// In en, this message translates to:
  /// **'Path-style addressing'**
  String get backupPageS3PathStyle;

  /// No description provided for @backupPageUserAgent.
  ///
  /// In en, this message translates to:
  /// **'User-Agent'**
  String get backupPageUserAgent;

  /// No description provided for @backupPageUserAgentHint.
  ///
  /// In en, this message translates to:
  /// **'Optional'**
  String get backupPageUserAgentHint;

  /// No description provided for @backupPageSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get backupPageSave;

  /// No description provided for @backupPageBackupNow.
  ///
  /// In en, this message translates to:
  /// **'Backup Now'**
  String get backupPageBackupNow;

  /// No description provided for @backupPageLocalBackup.
  ///
  /// In en, this message translates to:
  /// **'Local Backup'**
  String get backupPageLocalBackup;

  /// No description provided for @backupPageImportFromCherryStudio.
  ///
  /// In en, this message translates to:
  /// **'Import from Cherry Studio'**
  String get backupPageImportFromCherryStudio;

  /// No description provided for @backupPageCherryStudioUnsupportedBackupVersion.
  ///
  /// In en, this message translates to:
  /// **'This backup uses Cherry Studio format version {version}, which Kelivo cannot import yet. Export from Cherry Studio v1 instead, or wait for a Kelivo update that supports Cherry Studio v2 backups.'**
  String backupPageCherryStudioUnsupportedBackupVersion(String version);

  /// No description provided for @backupPageImportFromChatbox.
  ///
  /// In en, this message translates to:
  /// **'Import from Chatbox'**
  String get backupPageImportFromChatbox;

  /// No description provided for @backupReminderSectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Backup Reminder'**
  String get backupReminderSectionTitle;

  /// No description provided for @backupReminderEnableTitle.
  ///
  /// In en, this message translates to:
  /// **'Remind me to back up'**
  String get backupReminderEnableTitle;

  /// No description provided for @backupReminderFrequencyTitle.
  ///
  /// In en, this message translates to:
  /// **'Frequency'**
  String get backupReminderFrequencyTitle;

  /// No description provided for @backupReminderTimeTitle.
  ///
  /// In en, this message translates to:
  /// **'Reminder Time'**
  String get backupReminderTimeTitle;

  /// No description provided for @backupReminderTimeInputHint.
  ///
  /// In en, this message translates to:
  /// **'HH:mm'**
  String get backupReminderTimeInputHint;

  /// No description provided for @backupReminderTimeInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter a time from 00:00 to 23:59.'**
  String get backupReminderTimeInvalid;

  /// No description provided for @backupReminderLastBackupTitle.
  ///
  /// In en, this message translates to:
  /// **'Last Backup'**
  String get backupReminderLastBackupTitle;

  /// No description provided for @backupReminderNextReminderTitle.
  ///
  /// In en, this message translates to:
  /// **'Next Reminder'**
  String get backupReminderNextReminderTitle;

  /// No description provided for @backupReminderNever.
  ///
  /// In en, this message translates to:
  /// **'Never'**
  String get backupReminderNever;

  /// No description provided for @backupReminderDisabled.
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get backupReminderDisabled;

  /// No description provided for @backupReminderDueNow.
  ///
  /// In en, this message translates to:
  /// **'Due now'**
  String get backupReminderDueNow;

  /// No description provided for @backupReminderEveryDay.
  ///
  /// In en, this message translates to:
  /// **'Every day'**
  String get backupReminderEveryDay;

  /// No description provided for @backupReminderEveryThreeDays.
  ///
  /// In en, this message translates to:
  /// **'Every 3 days'**
  String get backupReminderEveryThreeDays;

  /// No description provided for @backupReminderEveryWeek.
  ///
  /// In en, this message translates to:
  /// **'Every week'**
  String get backupReminderEveryWeek;

  /// No description provided for @backupReminderEveryFourteenDays.
  ///
  /// In en, this message translates to:
  /// **'Every 14 days'**
  String get backupReminderEveryFourteenDays;

  /// No description provided for @backupReminderEveryMonth.
  ///
  /// In en, this message translates to:
  /// **'Every month'**
  String get backupReminderEveryMonth;

  /// No description provided for @backupReminderCustomDays.
  ///
  /// In en, this message translates to:
  /// **'Every {days} days'**
  String backupReminderCustomDays(int days);

  /// No description provided for @backupReminderCustomOption.
  ///
  /// In en, this message translates to:
  /// **'Custom...'**
  String get backupReminderCustomOption;

  /// No description provided for @backupReminderCustomDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Custom Frequency'**
  String get backupReminderCustomDialogTitle;

  /// No description provided for @backupReminderCustomDialogDescription.
  ///
  /// In en, this message translates to:
  /// **'Enter how many days to wait between backup reminders.'**
  String get backupReminderCustomDialogDescription;

  /// No description provided for @backupReminderCustomDaysLabel.
  ///
  /// In en, this message translates to:
  /// **'Days'**
  String get backupReminderCustomDaysLabel;

  /// No description provided for @backupReminderCustomDaysInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter a number from 1 to 365.'**
  String get backupReminderCustomDaysInvalid;

  /// No description provided for @backupReminderSidebarTitle.
  ///
  /// In en, this message translates to:
  /// **'Backup reminder'**
  String get backupReminderSidebarTitle;

  /// No description provided for @backupReminderSidebarSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Your backup interval has arrived.'**
  String get backupReminderSidebarSubtitle;

  /// No description provided for @backupReminderSidebarAction.
  ///
  /// In en, this message translates to:
  /// **'Go to backup'**
  String get backupReminderSidebarAction;

  /// No description provided for @backupReminderSnoozeTooltip.
  ///
  /// In en, this message translates to:
  /// **'Remind me later'**
  String get backupReminderSnoozeTooltip;

  /// No description provided for @chatHistoryPageTitle.
  ///
  /// In en, this message translates to:
  /// **'Chat History'**
  String get chatHistoryPageTitle;

  /// No description provided for @chatHistoryPageSearchTooltip.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get chatHistoryPageSearchTooltip;

  /// No description provided for @chatHistoryPageDeleteAllTooltip.
  ///
  /// In en, this message translates to:
  /// **'Delete Unpinned'**
  String get chatHistoryPageDeleteAllTooltip;

  /// No description provided for @chatHistoryPageDeleteAllDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete Unpinned Conversations'**
  String get chatHistoryPageDeleteAllDialogTitle;

  /// No description provided for @chatHistoryPageDeleteAllDialogContent.
  ///
  /// In en, this message translates to:
  /// **'Delete every non-pinned conversation for this assistant? Pinned chats stay in place.'**
  String get chatHistoryPageDeleteAllDialogContent;

  /// No description provided for @chatHistoryPageCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get chatHistoryPageCancel;

  /// No description provided for @chatHistoryPageDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get chatHistoryPageDelete;

  /// No description provided for @chatHistoryPageDeletedAllSnackbar.
  ///
  /// In en, this message translates to:
  /// **'Unpinned conversations deleted'**
  String get chatHistoryPageDeletedAllSnackbar;

  /// No description provided for @chatHistoryPageSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search conversations'**
  String get chatHistoryPageSearchHint;

  /// No description provided for @chatHistoryPageNoConversations.
  ///
  /// In en, this message translates to:
  /// **'No conversations'**
  String get chatHistoryPageNoConversations;

  /// No description provided for @chatHistoryPagePinnedSection.
  ///
  /// In en, this message translates to:
  /// **'Pinned'**
  String get chatHistoryPagePinnedSection;

  /// No description provided for @chatHistoryPagePin.
  ///
  /// In en, this message translates to:
  /// **'Pin'**
  String get chatHistoryPagePin;

  /// No description provided for @chatHistoryPagePinned.
  ///
  /// In en, this message translates to:
  /// **'Pinned'**
  String get chatHistoryPagePinned;

  /// No description provided for @messageEditPageTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit Message'**
  String get messageEditPageTitle;

  /// No description provided for @messageEditPageSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get messageEditPageSave;

  /// No description provided for @messageEditPageSaveAndSend.
  ///
  /// In en, this message translates to:
  /// **'Save & Send'**
  String get messageEditPageSaveAndSend;

  /// No description provided for @messageEditPageHint.
  ///
  /// In en, this message translates to:
  /// **'Enter message…'**
  String get messageEditPageHint;

  /// No description provided for @userMessageEditSaveOnly.
  ///
  /// In en, this message translates to:
  /// **'Save Only'**
  String get userMessageEditSaveOnly;

  /// No description provided for @userMessageEditUnsupportedSnackbar.
  ///
  /// In en, this message translates to:
  /// **'This content does not support editing'**
  String get userMessageEditUnsupportedSnackbar;

  /// No description provided for @userMessageEditOverwriteTitle.
  ///
  /// In en, this message translates to:
  /// **'Notice'**
  String get userMessageEditOverwriteTitle;

  /// No description provided for @userMessageEditOverwriteContent.
  ///
  /// In en, this message translates to:
  /// **'Editing will overwrite the existing input. Overwrite it?'**
  String get userMessageEditOverwriteContent;

  /// No description provided for @selectCopyPageTitle.
  ///
  /// In en, this message translates to:
  /// **'Select & Copy'**
  String get selectCopyPageTitle;

  /// No description provided for @selectCopyPageCopyAll.
  ///
  /// In en, this message translates to:
  /// **'Copy All'**
  String get selectCopyPageCopyAll;

  /// No description provided for @selectCopyPageCopiedAll.
  ///
  /// In en, this message translates to:
  /// **'Copied all'**
  String get selectCopyPageCopiedAll;

  /// No description provided for @bottomToolsSheetCamera.
  ///
  /// In en, this message translates to:
  /// **'Camera'**
  String get bottomToolsSheetCamera;

  /// No description provided for @bottomToolsSheetPhotos.
  ///
  /// In en, this message translates to:
  /// **'Photos'**
  String get bottomToolsSheetPhotos;

  /// No description provided for @bottomToolsSheetUpload.
  ///
  /// In en, this message translates to:
  /// **'Upload'**
  String get bottomToolsSheetUpload;

  /// No description provided for @bottomToolsSheetClearContext.
  ///
  /// In en, this message translates to:
  /// **'Clear Context'**
  String get bottomToolsSheetClearContext;

  /// No description provided for @compressContext.
  ///
  /// In en, this message translates to:
  /// **'Compress Context'**
  String get compressContext;

  /// No description provided for @compressContextDesc.
  ///
  /// In en, this message translates to:
  /// **'Summarize and start a new chat'**
  String get compressContextDesc;

  /// No description provided for @clearContextDesc.
  ///
  /// In en, this message translates to:
  /// **'Mark a context boundary'**
  String get clearContextDesc;

  /// No description provided for @contextManagement.
  ///
  /// In en, this message translates to:
  /// **'Context Management'**
  String get contextManagement;

  /// No description provided for @compressingContext.
  ///
  /// In en, this message translates to:
  /// **'Compressing context...'**
  String get compressingContext;

  /// No description provided for @compressContextFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to compress context'**
  String get compressContextFailed;

  /// No description provided for @compressContextNoMessages.
  ///
  /// In en, this message translates to:
  /// **'No messages to compress'**
  String get compressContextNoMessages;

  /// No description provided for @compressContextNoConversation.
  ///
  /// In en, this message translates to:
  /// **'No conversation to compress'**
  String get compressContextNoConversation;

  /// No description provided for @compressContextNoModel.
  ///
  /// In en, this message translates to:
  /// **'No compression model configured'**
  String get compressContextNoModel;

  /// No description provided for @compressContextEmptySummary.
  ///
  /// In en, this message translates to:
  /// **'Compression returned an empty summary'**
  String get compressContextEmptySummary;

  /// No description provided for @compressContextOptionsTitle.
  ///
  /// In en, this message translates to:
  /// **'Compress Context'**
  String get compressContextOptionsTitle;

  /// No description provided for @compressContextOptionsDesc.
  ///
  /// In en, this message translates to:
  /// **'Choose which part of the current chat is sent to the compression model.'**
  String get compressContextOptionsDesc;

  /// No description provided for @compressContextKeepStart.
  ///
  /// In en, this message translates to:
  /// **'Start'**
  String get compressContextKeepStart;

  /// No description provided for @compressContextKeepRecent.
  ///
  /// In en, this message translates to:
  /// **'Recent'**
  String get compressContextKeepRecent;

  /// No description provided for @compressContextUnlimited.
  ///
  /// In en, this message translates to:
  /// **'Unlimited'**
  String get compressContextUnlimited;

  /// No description provided for @compressContextMaxCharsLabel.
  ///
  /// In en, this message translates to:
  /// **'Characters'**
  String get compressContextMaxCharsLabel;

  /// No description provided for @compressContextInvalidLimit.
  ///
  /// In en, this message translates to:
  /// **'Enter a positive character count'**
  String get compressContextInvalidLimit;

  /// No description provided for @compressContextStartButton.
  ///
  /// In en, this message translates to:
  /// **'Compress'**
  String get compressContextStartButton;

  /// No description provided for @compressContextModelLabel.
  ///
  /// In en, this message translates to:
  /// **'Model'**
  String get compressContextModelLabel;

  /// No description provided for @compressContextModelUnset.
  ///
  /// In en, this message translates to:
  /// **'Select a model'**
  String get compressContextModelUnset;

  /// No description provided for @compressContextKeepRecentMessages.
  ///
  /// In en, this message translates to:
  /// **'Keep N'**
  String get compressContextKeepRecentMessages;

  /// No description provided for @compressContextKeepCountLabel.
  ///
  /// In en, this message translates to:
  /// **'Keep recent messages'**
  String get compressContextKeepCountLabel;

  /// No description provided for @compressContextKeepAllMessages.
  ///
  /// In en, this message translates to:
  /// **'Keeping that many covers all messages — nothing to compress'**
  String get compressContextKeepAllMessages;

  /// Keep-recent compression preview: summarized/kept char counts and the estimated result token band
  ///
  /// In en, this message translates to:
  /// **'Summarize {summarized} chars, keep {kept} chars verbatim → about {minTokens}–{maxTokens} tokens (original about {totalTokens} tokens)'**
  String compressContextEstimatePreview(
    int summarized,
    int kept,
    int minTokens,
    int maxTokens,
    int totalTokens,
  );

  /// No description provided for @bottomToolsSheetLearningMode.
  ///
  /// In en, this message translates to:
  /// **'Learning Mode'**
  String get bottomToolsSheetLearningMode;

  /// No description provided for @bottomToolsSheetLearningModeDescription.
  ///
  /// In en, this message translates to:
  /// **'Help you learn step by step'**
  String get bottomToolsSheetLearningModeDescription;

  /// No description provided for @bottomToolsSheetConfigurePrompt.
  ///
  /// In en, this message translates to:
  /// **'Configure prompt'**
  String get bottomToolsSheetConfigurePrompt;

  /// No description provided for @bottomToolsSheetPrompt.
  ///
  /// In en, this message translates to:
  /// **'Prompt'**
  String get bottomToolsSheetPrompt;

  /// No description provided for @bottomToolsSheetPromptHint.
  ///
  /// In en, this message translates to:
  /// **'Enter prompt text to inject'**
  String get bottomToolsSheetPromptHint;

  /// No description provided for @bottomToolsSheetResetDefault.
  ///
  /// In en, this message translates to:
  /// **'Reset to default'**
  String get bottomToolsSheetResetDefault;

  /// No description provided for @bottomToolsSheetSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get bottomToolsSheetSave;

  /// No description provided for @bottomToolsSheetOcr.
  ///
  /// In en, this message translates to:
  /// **'Image OCR'**
  String get bottomToolsSheetOcr;

  /// No description provided for @messageMoreSheetTitle.
  ///
  /// In en, this message translates to:
  /// **'More Actions'**
  String get messageMoreSheetTitle;

  /// No description provided for @messageMoreSheetSelectCopy.
  ///
  /// In en, this message translates to:
  /// **'Select & Copy'**
  String get messageMoreSheetSelectCopy;

  /// No description provided for @messageMoreSheetRenderWebView.
  ///
  /// In en, this message translates to:
  /// **'Render Web View'**
  String get messageMoreSheetRenderWebView;

  /// No description provided for @messageMoreSheetNotImplemented.
  ///
  /// In en, this message translates to:
  /// **'Not yet implemented'**
  String get messageMoreSheetNotImplemented;

  /// No description provided for @messageMoreSheetEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get messageMoreSheetEdit;

  /// No description provided for @messageMoreSheetShare.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get messageMoreSheetShare;

  /// No description provided for @messageMoreSheetSelectMessages.
  ///
  /// In en, this message translates to:
  /// **'Select Messages'**
  String get messageMoreSheetSelectMessages;

  /// No description provided for @messageMoreSheetCreateBranch.
  ///
  /// In en, this message translates to:
  /// **'Create Branch'**
  String get messageMoreSheetCreateBranch;

  /// No description provided for @messageMoreSheetDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete This Version'**
  String get messageMoreSheetDelete;

  /// No description provided for @messageMoreSheetDeleteAllVersions.
  ///
  /// In en, this message translates to:
  /// **'Delete All Versions'**
  String get messageMoreSheetDeleteAllVersions;

  /// No description provided for @reasoningBudgetSheetOff.
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get reasoningBudgetSheetOff;

  /// No description provided for @reasoningBudgetSheetAuto.
  ///
  /// In en, this message translates to:
  /// **'Auto'**
  String get reasoningBudgetSheetAuto;

  /// No description provided for @reasoningBudgetSheetLight.
  ///
  /// In en, this message translates to:
  /// **'Light Reasoning'**
  String get reasoningBudgetSheetLight;

  /// No description provided for @reasoningBudgetSheetMedium.
  ///
  /// In en, this message translates to:
  /// **'Medium Reasoning'**
  String get reasoningBudgetSheetMedium;

  /// No description provided for @reasoningBudgetSheetHeavy.
  ///
  /// In en, this message translates to:
  /// **'Heavy Reasoning'**
  String get reasoningBudgetSheetHeavy;

  /// No description provided for @reasoningBudgetSheetXhigh.
  ///
  /// In en, this message translates to:
  /// **'Extreme Reasoning'**
  String get reasoningBudgetSheetXhigh;

  /// No description provided for @reasoningBudgetSheetMax.
  ///
  /// In en, this message translates to:
  /// **'Maximum Reasoning'**
  String get reasoningBudgetSheetMax;

  /// No description provided for @reasoningBudgetSheetTitle.
  ///
  /// In en, this message translates to:
  /// **'Reasoning Chain Strength'**
  String get reasoningBudgetSheetTitle;

  /// No description provided for @reasoningBudgetSheetCurrentLevel.
  ///
  /// In en, this message translates to:
  /// **'Current Level: {level}'**
  String reasoningBudgetSheetCurrentLevel(String level);

  /// No description provided for @reasoningBudgetSheetOffSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Turn off reasoning, answer directly'**
  String get reasoningBudgetSheetOffSubtitle;

  /// No description provided for @reasoningBudgetSheetAutoSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Let the model decide reasoning level automatically'**
  String get reasoningBudgetSheetAutoSubtitle;

  /// No description provided for @reasoningBudgetSheetLightSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Use light reasoning to answer questions'**
  String get reasoningBudgetSheetLightSubtitle;

  /// No description provided for @reasoningBudgetSheetMediumSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Use moderate reasoning to answer questions'**
  String get reasoningBudgetSheetMediumSubtitle;

  /// No description provided for @reasoningBudgetSheetHeavySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Use heavy reasoning for complex questions'**
  String get reasoningBudgetSheetHeavySubtitle;

  /// No description provided for @reasoningBudgetSheetXhighSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Use maximum reasoning depth for the toughest problems'**
  String get reasoningBudgetSheetXhighSubtitle;

  /// No description provided for @reasoningBudgetSheetCustomLabel.
  ///
  /// In en, this message translates to:
  /// **'Custom Reasoning Budget'**
  String get reasoningBudgetSheetCustomLabel;

  /// No description provided for @reasoningBudgetSheetCustomHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. 2048 (-1 auto, 0 off)'**
  String get reasoningBudgetSheetCustomHint;

  /// No description provided for @chatMessageWidgetFileNotFound.
  ///
  /// In en, this message translates to:
  /// **'File not found: {fileName}'**
  String chatMessageWidgetFileNotFound(String fileName);

  /// No description provided for @chatMessageWidgetCannotOpenFile.
  ///
  /// In en, this message translates to:
  /// **'Cannot open file: {message}'**
  String chatMessageWidgetCannotOpenFile(String message);

  /// No description provided for @chatMessageWidgetOpenFileError.
  ///
  /// In en, this message translates to:
  /// **'Failed to open file: {error}'**
  String chatMessageWidgetOpenFileError(String error);

  /// No description provided for @chatMessageWidgetCopiedToClipboard.
  ///
  /// In en, this message translates to:
  /// **'Copied to clipboard'**
  String get chatMessageWidgetCopiedToClipboard;

  /// No description provided for @chatMessageWidgetResendTooltip.
  ///
  /// In en, this message translates to:
  /// **'Resend'**
  String get chatMessageWidgetResendTooltip;

  /// No description provided for @chatMessageWidgetMoreTooltip.
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get chatMessageWidgetMoreTooltip;

  /// No description provided for @chatMessageWidgetThinking.
  ///
  /// In en, this message translates to:
  /// **'Thinking...'**
  String get chatMessageWidgetThinking;

  /// No description provided for @chatMessageWidgetTranslation.
  ///
  /// In en, this message translates to:
  /// **'Translation'**
  String get chatMessageWidgetTranslation;

  /// No description provided for @chatMessageWidgetTranslating.
  ///
  /// In en, this message translates to:
  /// **'Translating...'**
  String get chatMessageWidgetTranslating;

  /// No description provided for @chatMessageWidgetCitationNotFound.
  ///
  /// In en, this message translates to:
  /// **'Citation source not found'**
  String get chatMessageWidgetCitationNotFound;

  /// No description provided for @chatMessageWidgetCannotOpenUrl.
  ///
  /// In en, this message translates to:
  /// **'Cannot open link: {url}'**
  String chatMessageWidgetCannotOpenUrl(String url);

  /// No description provided for @chatMessageWidgetOpenLinkError.
  ///
  /// In en, this message translates to:
  /// **'Failed to open link'**
  String get chatMessageWidgetOpenLinkError;

  /// No description provided for @chatMessageWidgetAttachmentUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Attachment unavailable'**
  String get chatMessageWidgetAttachmentUnavailable;

  /// No description provided for @chatMessageWidgetCitationsTitle.
  ///
  /// In en, this message translates to:
  /// **'Citations ({count})'**
  String chatMessageWidgetCitationsTitle(int count);

  /// No description provided for @chatMessageWidgetSearchResultsTitle.
  ///
  /// In en, this message translates to:
  /// **'Search results'**
  String get chatMessageWidgetSearchResultsTitle;

  /// No description provided for @chatMessageWidgetCitationSourcesTitle.
  ///
  /// In en, this message translates to:
  /// **'Citation sources'**
  String get chatMessageWidgetCitationSourcesTitle;

  /// No description provided for @chatMessageWidgetRegenerateTooltip.
  ///
  /// In en, this message translates to:
  /// **'Regenerate'**
  String get chatMessageWidgetRegenerateTooltip;

  /// No description provided for @chatMessageWidgetRegenerateConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Confirm Regenerate'**
  String get chatMessageWidgetRegenerateConfirmTitle;

  /// No description provided for @chatMessageWidgetRegenerateConfirmContent.
  ///
  /// In en, this message translates to:
  /// **'Regenerating only updates this message and keeps the messages below it. Continue?'**
  String get chatMessageWidgetRegenerateConfirmContent;

  /// No description provided for @chatMessageWidgetRegenerateConfirmDeleteTrailingContent.
  ///
  /// In en, this message translates to:
  /// **'Regenerating will delete all messages below this message and cannot be undone. Continue?'**
  String get chatMessageWidgetRegenerateConfirmDeleteTrailingContent;

  /// No description provided for @chatMessageWidgetRegenerateConfirmCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get chatMessageWidgetRegenerateConfirmCancel;

  /// No description provided for @chatMessageWidgetRegenerateConfirmOk.
  ///
  /// In en, this message translates to:
  /// **'Regenerate'**
  String get chatMessageWidgetRegenerateConfirmOk;

  /// No description provided for @chatMessageWidgetStopTooltip.
  ///
  /// In en, this message translates to:
  /// **'Stop'**
  String get chatMessageWidgetStopTooltip;

  /// No description provided for @chatMessageWidgetSpeakTooltip.
  ///
  /// In en, this message translates to:
  /// **'Speak'**
  String get chatMessageWidgetSpeakTooltip;

  /// No description provided for @chatMessageWidgetTranslateTooltip.
  ///
  /// In en, this message translates to:
  /// **'Translate'**
  String get chatMessageWidgetTranslateTooltip;

  /// No description provided for @chatMessageWidgetBuiltinSearchHideNote.
  ///
  /// In en, this message translates to:
  /// **'Hide builtin search tool cards'**
  String get chatMessageWidgetBuiltinSearchHideNote;

  /// No description provided for @chatMessageWidgetDeepThinking.
  ///
  /// In en, this message translates to:
  /// **'Deep Thinking'**
  String get chatMessageWidgetDeepThinking;

  /// No description provided for @chatMessageWidgetWebSearch.
  ///
  /// In en, this message translates to:
  /// **'Web Search: {query}'**
  String chatMessageWidgetWebSearch(String query);

  /// No description provided for @chatMessageWidgetBuiltinSearch.
  ///
  /// In en, this message translates to:
  /// **'Built-in Search'**
  String get chatMessageWidgetBuiltinSearch;

  /// No description provided for @chatMessageWidgetReadClipboard.
  ///
  /// In en, this message translates to:
  /// **'Read Clipboard'**
  String get chatMessageWidgetReadClipboard;

  /// No description provided for @chatMessageWidgetWriteClipboard.
  ///
  /// In en, this message translates to:
  /// **'Write Clipboard'**
  String get chatMessageWidgetWriteClipboard;

  /// No description provided for @chatMessageWidgetSpeakingTitle.
  ///
  /// In en, this message translates to:
  /// **'Speaking:'**
  String get chatMessageWidgetSpeakingTitle;

  /// No description provided for @chatMessageWidgetSpeakText.
  ///
  /// In en, this message translates to:
  /// **'Speaking: {text}'**
  String chatMessageWidgetSpeakText(String text);

  /// No description provided for @chatMessageWidgetMemoryRead.
  ///
  /// In en, this message translates to:
  /// **'Read Memory'**
  String get chatMessageWidgetMemoryRead;

  /// No description provided for @chatMessageWidgetMemoryUpdate.
  ///
  /// In en, this message translates to:
  /// **'Update Memory'**
  String get chatMessageWidgetMemoryUpdate;

  /// No description provided for @chatMessageWidgetMemorySearchProfile.
  ///
  /// In en, this message translates to:
  /// **'Search Memory'**
  String get chatMessageWidgetMemorySearchProfile;

  /// No description provided for @chatMessageWidgetMemoryEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit Memory'**
  String get chatMessageWidgetMemoryEdit;

  /// No description provided for @chatMessageWidgetMemoryDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete Memory'**
  String get chatMessageWidgetMemoryDelete;

  /// No description provided for @chatMessageWidgetUpdateUserProfile.
  ///
  /// In en, this message translates to:
  /// **'Update User Profile'**
  String get chatMessageWidgetUpdateUserProfile;

  /// No description provided for @chatMessageWidgetChatSearch.
  ///
  /// In en, this message translates to:
  /// **'Search Past Chats'**
  String get chatMessageWidgetChatSearch;

  /// No description provided for @chatMessageWidgetCreateMemory.
  ///
  /// In en, this message translates to:
  /// **'Create Memory'**
  String get chatMessageWidgetCreateMemory;

  /// No description provided for @chatMessageWidgetToolCall.
  ///
  /// In en, this message translates to:
  /// **'Tool Call: {name}'**
  String chatMessageWidgetToolCall(String name);

  /// No description provided for @chatMessageWidgetToolResult.
  ///
  /// In en, this message translates to:
  /// **'Tool Result: {name}'**
  String chatMessageWidgetToolResult(String name);

  /// No description provided for @chatMessageWidgetNoResultYet.
  ///
  /// In en, this message translates to:
  /// **'(No result yet)'**
  String get chatMessageWidgetNoResultYet;

  /// No description provided for @chatMessageWidgetArguments.
  ///
  /// In en, this message translates to:
  /// **'Arguments'**
  String get chatMessageWidgetArguments;

  /// No description provided for @chatMessageWidgetResult.
  ///
  /// In en, this message translates to:
  /// **'Result'**
  String get chatMessageWidgetResult;

  /// No description provided for @chatMessageWidgetImages.
  ///
  /// In en, this message translates to:
  /// **'Images'**
  String get chatMessageWidgetImages;

  /// No description provided for @chatMessageWidgetCitationsCount.
  ///
  /// In en, this message translates to:
  /// **'{count} citations'**
  String chatMessageWidgetCitationsCount(int count);

  /// No description provided for @chatSelectionSelectedCountTitle.
  ///
  /// In en, this message translates to:
  /// **'Selected {count} message(s)'**
  String chatSelectionSelectedCountTitle(int count);

  /// No description provided for @chatSelectionExportTxt.
  ///
  /// In en, this message translates to:
  /// **'TXT'**
  String get chatSelectionExportTxt;

  /// No description provided for @chatSelectionExportMd.
  ///
  /// In en, this message translates to:
  /// **'MD'**
  String get chatSelectionExportMd;

  /// No description provided for @chatSelectionExportImage.
  ///
  /// In en, this message translates to:
  /// **'Image'**
  String get chatSelectionExportImage;

  /// No description provided for @chatSelectionThinkingTools.
  ///
  /// In en, this message translates to:
  /// **'Thinking tools'**
  String get chatSelectionThinkingTools;

  /// No description provided for @chatSelectionThinkingContent.
  ///
  /// In en, this message translates to:
  /// **'Thinking content'**
  String get chatSelectionThinkingContent;

  /// No description provided for @chatSelectionDeleteSelected.
  ///
  /// In en, this message translates to:
  /// **'Delete Selected'**
  String get chatSelectionDeleteSelected;

  /// No description provided for @chatSelectionSelectMessagesToDelete.
  ///
  /// In en, this message translates to:
  /// **'Please select messages to delete'**
  String get chatSelectionSelectMessagesToDelete;

  /// No description provided for @chatSelectionDeleteSelectedConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete {count} selected version(s)? This cannot be undone.'**
  String chatSelectionDeleteSelectedConfirm(int count);

  /// No description provided for @chatSelectionDeleteSelectedAllVersionsConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete all versions of {count} selected message(s)? This cannot be undone.'**
  String chatSelectionDeleteSelectedAllVersionsConfirm(int count);

  /// No description provided for @messageExportSheetAssistant.
  ///
  /// In en, this message translates to:
  /// **'Assistant'**
  String get messageExportSheetAssistant;

  /// No description provided for @messageExportSheetDefaultTitle.
  ///
  /// In en, this message translates to:
  /// **'New Chat'**
  String get messageExportSheetDefaultTitle;

  /// No description provided for @messageExportSheetExporting.
  ///
  /// In en, this message translates to:
  /// **'Exporting…'**
  String get messageExportSheetExporting;

  /// No description provided for @messageExportSheetExportFailed.
  ///
  /// In en, this message translates to:
  /// **'Export failed: {error}'**
  String messageExportSheetExportFailed(String error);

  /// No description provided for @messageExportSheetExportedAs.
  ///
  /// In en, this message translates to:
  /// **'Exported as {filename}'**
  String messageExportSheetExportedAs(String filename);

  /// No description provided for @displaySettingsPageEnableDollarLatexTitle.
  ///
  /// In en, this message translates to:
  /// **'Inline \$...\$ Rendering'**
  String get displaySettingsPageEnableDollarLatexTitle;

  /// No description provided for @displaySettingsPageEnableDollarLatexSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Render inline math inside \$...\$'**
  String get displaySettingsPageEnableDollarLatexSubtitle;

  /// No description provided for @displaySettingsPageEnableMathTitle.
  ///
  /// In en, this message translates to:
  /// **'Math Formula Rendering'**
  String get displaySettingsPageEnableMathTitle;

  /// No description provided for @displaySettingsPageEnableMathSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Render LaTeX math (inline and block)'**
  String get displaySettingsPageEnableMathSubtitle;

  /// No description provided for @displaySettingsPageEnableUserMarkdownTitle.
  ///
  /// In en, this message translates to:
  /// **'Render user messages with Markdown'**
  String get displaySettingsPageEnableUserMarkdownTitle;

  /// No description provided for @displaySettingsPageEnableReasoningMarkdownTitle.
  ///
  /// In en, this message translates to:
  /// **'Render reasoning (thinking) with Markdown'**
  String get displaySettingsPageEnableReasoningMarkdownTitle;

  /// No description provided for @displaySettingsPageEnableAssistantMarkdownTitle.
  ///
  /// In en, this message translates to:
  /// **'Render assistant messages with Markdown'**
  String get displaySettingsPageEnableAssistantMarkdownTitle;

  /// No description provided for @displaySettingsPageMobileCodeBlockWrapTitle.
  ///
  /// In en, this message translates to:
  /// **'Mobile Code Block Word Wrap'**
  String get displaySettingsPageMobileCodeBlockWrapTitle;

  /// No description provided for @displaySettingsPageAutoCollapseCodeBlockTitle.
  ///
  /// In en, this message translates to:
  /// **'Auto-collapse Code Blocks'**
  String get displaySettingsPageAutoCollapseCodeBlockTitle;

  /// No description provided for @displaySettingsPageAutoCollapseCodeBlockLinesTitle.
  ///
  /// In en, this message translates to:
  /// **'Auto-collapse threshold'**
  String get displaySettingsPageAutoCollapseCodeBlockLinesTitle;

  /// No description provided for @displaySettingsPageAutoCollapseCodeBlockLinesUnit.
  ///
  /// In en, this message translates to:
  /// **'lines'**
  String get displaySettingsPageAutoCollapseCodeBlockLinesUnit;

  /// No description provided for @messageExportSheetFormatTitle.
  ///
  /// In en, this message translates to:
  /// **'Export Format'**
  String get messageExportSheetFormatTitle;

  /// No description provided for @messageExportSheetMarkdown.
  ///
  /// In en, this message translates to:
  /// **'Markdown'**
  String get messageExportSheetMarkdown;

  /// No description provided for @messageExportSheetSingleMarkdownSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Export this message as a Markdown file'**
  String get messageExportSheetSingleMarkdownSubtitle;

  /// No description provided for @messageExportSheetBatchMarkdownSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Export selected messages as a Markdown file'**
  String get messageExportSheetBatchMarkdownSubtitle;

  /// No description provided for @messageExportSheetPlainText.
  ///
  /// In en, this message translates to:
  /// **'Plain Text'**
  String get messageExportSheetPlainText;

  /// No description provided for @messageExportSheetSingleTxtSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Export this message as a TXT file'**
  String get messageExportSheetSingleTxtSubtitle;

  /// No description provided for @messageExportSheetBatchTxtSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Export selected messages as a TXT file'**
  String get messageExportSheetBatchTxtSubtitle;

  /// No description provided for @messageExportSheetExportImage.
  ///
  /// In en, this message translates to:
  /// **'Export as Image'**
  String get messageExportSheetExportImage;

  /// No description provided for @messageExportSheetSingleExportImageSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Render this message to a PNG image'**
  String get messageExportSheetSingleExportImageSubtitle;

  /// No description provided for @messageExportSheetBatchExportImageSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Render selected messages to a PNG image'**
  String get messageExportSheetBatchExportImageSubtitle;

  /// No description provided for @messageExportSheetShowThinkingAndToolCards.
  ///
  /// In en, this message translates to:
  /// **'Show Deep Thinking and tool cards'**
  String get messageExportSheetShowThinkingAndToolCards;

  /// No description provided for @messageExportSheetShowThinkingContent.
  ///
  /// In en, this message translates to:
  /// **'Show thinking content'**
  String get messageExportSheetShowThinkingContent;

  /// No description provided for @messageExportThinkingContentLabel.
  ///
  /// In en, this message translates to:
  /// **'Thinking content'**
  String get messageExportThinkingContentLabel;

  /// No description provided for @messageExportSheetDateTimeWithSecondsPattern.
  ///
  /// In en, this message translates to:
  /// **'yyyy-MM-dd HH:mm:ss'**
  String get messageExportSheetDateTimeWithSecondsPattern;

  /// No description provided for @exportDisclaimerAiGenerated.
  ///
  /// In en, this message translates to:
  /// **'Content generated by AI. Please verify carefully.'**
  String get exportDisclaimerAiGenerated;

  /// No description provided for @imagePreviewSheetSaveImage.
  ///
  /// In en, this message translates to:
  /// **'Save Image'**
  String get imagePreviewSheetSaveImage;

  /// No description provided for @imagePreviewSheetSaveSuccess.
  ///
  /// In en, this message translates to:
  /// **'Saved to gallery'**
  String get imagePreviewSheetSaveSuccess;

  /// No description provided for @imagePreviewSheetSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Save failed: {error}'**
  String imagePreviewSheetSaveFailed(String error);

  /// No description provided for @sideDrawerMenuRename.
  ///
  /// In en, this message translates to:
  /// **'Rename'**
  String get sideDrawerMenuRename;

  /// No description provided for @sideDrawerMenuPin.
  ///
  /// In en, this message translates to:
  /// **'Pin'**
  String get sideDrawerMenuPin;

  /// No description provided for @sideDrawerMenuUnpin.
  ///
  /// In en, this message translates to:
  /// **'Unpin'**
  String get sideDrawerMenuUnpin;

  /// No description provided for @sideDrawerMenuRegenerateTitle.
  ///
  /// In en, this message translates to:
  /// **'Regenerate Title'**
  String get sideDrawerMenuRegenerateTitle;

  /// No description provided for @sideDrawerMenuCopy.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get sideDrawerMenuCopy;

  /// No description provided for @sideDrawerMenuMoveTo.
  ///
  /// In en, this message translates to:
  /// **'Move to'**
  String get sideDrawerMenuMoveTo;

  /// No description provided for @sideDrawerMenuDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get sideDrawerMenuDelete;

  /// No description provided for @sideDrawerMenuSelect.
  ///
  /// In en, this message translates to:
  /// **'Select'**
  String get sideDrawerMenuSelect;

  /// No description provided for @sideDrawerSelectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Selected {count} items'**
  String sideDrawerSelectionTitle(int count);

  /// No description provided for @sideDrawerSelectionSelectAll.
  ///
  /// In en, this message translates to:
  /// **'Select all'**
  String get sideDrawerSelectionSelectAll;

  /// No description provided for @sideDrawerSelectionDeselectAll.
  ///
  /// In en, this message translates to:
  /// **'Deselect all'**
  String get sideDrawerSelectionDeselectAll;

  /// No description provided for @sideDrawerSelectionPin.
  ///
  /// In en, this message translates to:
  /// **'Pin'**
  String get sideDrawerSelectionPin;

  /// No description provided for @sideDrawerSelectionUnpin.
  ///
  /// In en, this message translates to:
  /// **'Unpin'**
  String get sideDrawerSelectionUnpin;

  /// No description provided for @sideDrawerSelectionMove.
  ///
  /// In en, this message translates to:
  /// **'Move'**
  String get sideDrawerSelectionMove;

  /// No description provided for @sideDrawerSelectionDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get sideDrawerSelectionDelete;

  /// No description provided for @sideDrawerSelectionDeleteConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete conversations'**
  String get sideDrawerSelectionDeleteConfirmTitle;

  /// No description provided for @sideDrawerSelectionDeleteConfirmContent.
  ///
  /// In en, this message translates to:
  /// **'Delete {count} conversations?'**
  String sideDrawerSelectionDeleteConfirmContent(int count);

  /// No description provided for @sideDrawerDeleteSelectedSnackbar.
  ///
  /// In en, this message translates to:
  /// **'Deleted {count} conversations'**
  String sideDrawerDeleteSelectedSnackbar(int count);

  /// No description provided for @sideDrawerMoveSelectedSnackbar.
  ///
  /// In en, this message translates to:
  /// **'Moved {count} conversations'**
  String sideDrawerMoveSelectedSnackbar(int count);

  /// No description provided for @sideDrawerDeleteSnackbar.
  ///
  /// In en, this message translates to:
  /// **'Deleted \"{title}\"'**
  String sideDrawerDeleteSnackbar(String title);

  /// No description provided for @sideDrawerRenameHint.
  ///
  /// In en, this message translates to:
  /// **'Enter new name'**
  String get sideDrawerRenameHint;

  /// No description provided for @sideDrawerCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get sideDrawerCancel;

  /// No description provided for @sideDrawerOK.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get sideDrawerOK;

  /// No description provided for @sideDrawerSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get sideDrawerSave;

  /// No description provided for @sideDrawerGreetingMorning.
  ///
  /// In en, this message translates to:
  /// **'Good morning 👋'**
  String get sideDrawerGreetingMorning;

  /// No description provided for @sideDrawerGreetingNoon.
  ///
  /// In en, this message translates to:
  /// **'Good afternoon 👋'**
  String get sideDrawerGreetingNoon;

  /// No description provided for @sideDrawerGreetingAfternoon.
  ///
  /// In en, this message translates to:
  /// **'Good afternoon 👋'**
  String get sideDrawerGreetingAfternoon;

  /// No description provided for @sideDrawerGreetingEvening.
  ///
  /// In en, this message translates to:
  /// **'Good evening 👋'**
  String get sideDrawerGreetingEvening;

  /// No description provided for @sideDrawerDateToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get sideDrawerDateToday;

  /// No description provided for @sideDrawerDateYesterday.
  ///
  /// In en, this message translates to:
  /// **'Yesterday'**
  String get sideDrawerDateYesterday;

  /// No description provided for @sideDrawerDateShortPattern.
  ///
  /// In en, this message translates to:
  /// **'MMM d'**
  String get sideDrawerDateShortPattern;

  /// No description provided for @sideDrawerDateFullPattern.
  ///
  /// In en, this message translates to:
  /// **'MMM d, yyyy'**
  String get sideDrawerDateFullPattern;

  /// No description provided for @sideDrawerSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search current assistant'**
  String get sideDrawerSearchHint;

  /// No description provided for @sideDrawerSearchAssistantsHint.
  ///
  /// In en, this message translates to:
  /// **'Search assistants'**
  String get sideDrawerSearchAssistantsHint;

  /// No description provided for @sideDrawerTopicSearchModeLabel.
  ///
  /// In en, this message translates to:
  /// **'Topic mode'**
  String get sideDrawerTopicSearchModeLabel;

  /// No description provided for @sideDrawerGlobalSearchModeLabel.
  ///
  /// In en, this message translates to:
  /// **'Global mode'**
  String get sideDrawerGlobalSearchModeLabel;

  /// No description provided for @sideDrawerSearchModeSwipeToTopicHint.
  ///
  /// In en, this message translates to:
  /// **'Swipe the search bar for topic search'**
  String get sideDrawerSearchModeSwipeToTopicHint;

  /// No description provided for @sideDrawerSearchModeSwipeToGlobalHint.
  ///
  /// In en, this message translates to:
  /// **'Swipe the search bar for global search'**
  String get sideDrawerSearchModeSwipeToGlobalHint;

  /// No description provided for @sideDrawerGlobalSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search all sessions'**
  String get sideDrawerGlobalSearchHint;

  /// No description provided for @sideDrawerGlobalSearchEmptyHint.
  ///
  /// In en, this message translates to:
  /// **'Search across titles and messages'**
  String get sideDrawerGlobalSearchEmptyHint;

  /// No description provided for @sideDrawerGlobalSearchNoResults.
  ///
  /// In en, this message translates to:
  /// **'No matching sessions'**
  String get sideDrawerGlobalSearchNoResults;

  /// No description provided for @sideDrawerGlobalSearchResultCount.
  ///
  /// In en, this message translates to:
  /// **'{count} results'**
  String sideDrawerGlobalSearchResultCount(int count);

  /// No description provided for @sideDrawerUpdateTitle.
  ///
  /// In en, this message translates to:
  /// **'New version: {version}'**
  String sideDrawerUpdateTitle(String version);

  /// No description provided for @sideDrawerUpdateTitleWithBuild.
  ///
  /// In en, this message translates to:
  /// **'New version: {version} ({build})'**
  String sideDrawerUpdateTitleWithBuild(String version, int build);

  /// No description provided for @sideDrawerLinkCopied.
  ///
  /// In en, this message translates to:
  /// **'Link copied'**
  String get sideDrawerLinkCopied;

  /// No description provided for @sideDrawerPinnedLabel.
  ///
  /// In en, this message translates to:
  /// **'Pinned'**
  String get sideDrawerPinnedLabel;

  /// No description provided for @sideDrawerHistory.
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get sideDrawerHistory;

  /// No description provided for @sideDrawerSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get sideDrawerSettings;

  /// No description provided for @sideDrawerChooseAssistantTitle.
  ///
  /// In en, this message translates to:
  /// **'Choose Assistant'**
  String get sideDrawerChooseAssistantTitle;

  /// No description provided for @sideDrawerChooseImage.
  ///
  /// In en, this message translates to:
  /// **'Choose Image'**
  String get sideDrawerChooseImage;

  /// No description provided for @sideDrawerChooseEmoji.
  ///
  /// In en, this message translates to:
  /// **'Choose Emoji'**
  String get sideDrawerChooseEmoji;

  /// No description provided for @sideDrawerEnterLink.
  ///
  /// In en, this message translates to:
  /// **'Enter Link'**
  String get sideDrawerEnterLink;

  /// No description provided for @sideDrawerImportFromQQ.
  ///
  /// In en, this message translates to:
  /// **'Import from QQ'**
  String get sideDrawerImportFromQQ;

  /// No description provided for @sideDrawerReset.
  ///
  /// In en, this message translates to:
  /// **'Reset'**
  String get sideDrawerReset;

  /// No description provided for @providerAvatarChooseBuiltInIcon.
  ///
  /// In en, this message translates to:
  /// **'Choose Built-in Icon'**
  String get providerAvatarChooseBuiltInIcon;

  /// No description provided for @providerAvatarIconDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Choose Built-in Icon'**
  String get providerAvatarIconDialogTitle;

  /// No description provided for @providerAvatarIconSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search icons'**
  String get providerAvatarIconSearchHint;

  /// No description provided for @providerAvatarIconNoResults.
  ///
  /// In en, this message translates to:
  /// **'No icons found'**
  String get providerAvatarIconNoResults;

  /// No description provided for @providerAvatarInputLobehubIcon.
  ///
  /// In en, this message translates to:
  /// **'Enter LobeHub Icon'**
  String get providerAvatarInputLobehubIcon;

  /// No description provided for @providerAvatarChooseLobehubIcon.
  ///
  /// In en, this message translates to:
  /// **'Enter LobeHub Icon'**
  String get providerAvatarChooseLobehubIcon;

  /// No description provided for @providerAvatarLobehubDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Enter LobeHub Icon'**
  String get providerAvatarLobehubDialogTitle;

  /// No description provided for @providerAvatarLobehubDialogHint.
  ///
  /// In en, this message translates to:
  /// **'Enter a LobeHub icon name, e.g. openai'**
  String get providerAvatarLobehubDialogHint;

  /// No description provided for @sideDrawerEmojiDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Choose Emoji'**
  String get sideDrawerEmojiDialogTitle;

  /// No description provided for @sideDrawerEmojiDialogHint.
  ///
  /// In en, this message translates to:
  /// **'Type or paste any emoji'**
  String get sideDrawerEmojiDialogHint;

  /// No description provided for @sideDrawerImageUrlDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Enter Image URL'**
  String get sideDrawerImageUrlDialogTitle;

  /// No description provided for @sideDrawerImageUrlDialogHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. https://example.com/avatar.png'**
  String get sideDrawerImageUrlDialogHint;

  /// No description provided for @sideDrawerQQAvatarDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Import from QQ'**
  String get sideDrawerQQAvatarDialogTitle;

  /// No description provided for @sideDrawerQQAvatarInputHint.
  ///
  /// In en, this message translates to:
  /// **'Enter QQ number (5-12 digits)'**
  String get sideDrawerQQAvatarInputHint;

  /// No description provided for @sideDrawerQQAvatarFetchFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to fetch random QQ avatar. Please try again.'**
  String get sideDrawerQQAvatarFetchFailed;

  /// No description provided for @sideDrawerRandomQQ.
  ///
  /// In en, this message translates to:
  /// **'Random QQ'**
  String get sideDrawerRandomQQ;

  /// No description provided for @sideDrawerGalleryOpenError.
  ///
  /// In en, this message translates to:
  /// **'Unable to open gallery. Try entering an image URL.'**
  String get sideDrawerGalleryOpenError;

  /// No description provided for @sideDrawerGeneralImageError.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. Try entering an image URL.'**
  String get sideDrawerGeneralImageError;

  /// No description provided for @sideDrawerSetNicknameTitle.
  ///
  /// In en, this message translates to:
  /// **'Set Nickname'**
  String get sideDrawerSetNicknameTitle;

  /// No description provided for @sideDrawerNicknameLabel.
  ///
  /// In en, this message translates to:
  /// **'Nickname'**
  String get sideDrawerNicknameLabel;

  /// No description provided for @sideDrawerNicknameHint.
  ///
  /// In en, this message translates to:
  /// **'Enter new nickname'**
  String get sideDrawerNicknameHint;

  /// No description provided for @sideDrawerRename.
  ///
  /// In en, this message translates to:
  /// **'Rename'**
  String get sideDrawerRename;

  /// No description provided for @chatInputBarHint.
  ///
  /// In en, this message translates to:
  /// **'Type a message for AI'**
  String get chatInputBarHint;

  /// No description provided for @chatInputBarSelectModelTooltip.
  ///
  /// In en, this message translates to:
  /// **'Select Model'**
  String get chatInputBarSelectModelTooltip;

  /// No description provided for @chatInputBarOnlineSearchTooltip.
  ///
  /// In en, this message translates to:
  /// **'Online Search'**
  String get chatInputBarOnlineSearchTooltip;

  /// No description provided for @chatInputBarReasoningStrengthTooltip.
  ///
  /// In en, this message translates to:
  /// **'Reasoning Strength'**
  String get chatInputBarReasoningStrengthTooltip;

  /// No description provided for @chatInputBarMcpServersTooltip.
  ///
  /// In en, this message translates to:
  /// **'MCP Servers'**
  String get chatInputBarMcpServersTooltip;

  /// No description provided for @chatInputBarMoreTooltip.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get chatInputBarMoreTooltip;

  /// No description provided for @chatInputBarVoiceInputTooltip.
  ///
  /// In en, this message translates to:
  /// **'Voice input'**
  String get chatInputBarVoiceInputTooltip;

  /// No description provided for @chatInputBarVoiceCancelTooltip.
  ///
  /// In en, this message translates to:
  /// **'Discard recording'**
  String get chatInputBarVoiceCancelTooltip;

  /// No description provided for @chatInputBarVoiceStopTooltip.
  ///
  /// In en, this message translates to:
  /// **'Stop and transcribe to input'**
  String get chatInputBarVoiceStopTooltip;

  /// No description provided for @chatInputBarVoiceSendTooltip.
  ///
  /// In en, this message translates to:
  /// **'Transcribe and send'**
  String get chatInputBarVoiceSendTooltip;

  /// No description provided for @chatInputBarVoiceTranscribing.
  ///
  /// In en, this message translates to:
  /// **'Recognizing…'**
  String get chatInputBarVoiceTranscribing;

  /// No description provided for @chatInputBarImageProcessing.
  ///
  /// In en, this message translates to:
  /// **'Processing image'**
  String get chatInputBarImageProcessing;

  /// No description provided for @chatInputBarImageMode.
  ///
  /// In en, this message translates to:
  /// **'Image mode'**
  String get chatInputBarImageMode;

  /// No description provided for @chatInputBarDisableImageModeTooltip.
  ///
  /// In en, this message translates to:
  /// **'Turn off image mode'**
  String get chatInputBarDisableImageModeTooltip;

  /// No description provided for @chatInputBarQueuedPending.
  ///
  /// In en, this message translates to:
  /// **'Queued to send'**
  String get chatInputBarQueuedPending;

  /// No description provided for @chatInputBarQueuedCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel Queue'**
  String get chatInputBarQueuedCancel;

  /// No description provided for @chatInputBarInsertNewline.
  ///
  /// In en, this message translates to:
  /// **'Newline'**
  String get chatInputBarInsertNewline;

  /// No description provided for @chatInputBarExpand.
  ///
  /// In en, this message translates to:
  /// **'Expand'**
  String get chatInputBarExpand;

  /// No description provided for @chatInputBarCollapse.
  ///
  /// In en, this message translates to:
  /// **'Collapse'**
  String get chatInputBarCollapse;

  /// No description provided for @mcpPageBackTooltip.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get mcpPageBackTooltip;

  /// No description provided for @mcpPageAddMcpTooltip.
  ///
  /// In en, this message translates to:
  /// **'Add MCP'**
  String get mcpPageAddMcpTooltip;

  /// No description provided for @mcpPageNoServers.
  ///
  /// In en, this message translates to:
  /// **'No MCP servers'**
  String get mcpPageNoServers;

  /// No description provided for @mcpPageErrorDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Connection Error'**
  String get mcpPageErrorDialogTitle;

  /// No description provided for @mcpPageErrorNoDetails.
  ///
  /// In en, this message translates to:
  /// **'No details'**
  String get mcpPageErrorNoDetails;

  /// No description provided for @mcpPageClose.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get mcpPageClose;

  /// No description provided for @mcpPageReconnect.
  ///
  /// In en, this message translates to:
  /// **'Reconnect'**
  String get mcpPageReconnect;

  /// No description provided for @mcpPageStatusConnected.
  ///
  /// In en, this message translates to:
  /// **'Connected'**
  String get mcpPageStatusConnected;

  /// No description provided for @mcpPageStatusConnecting.
  ///
  /// In en, this message translates to:
  /// **'Connecting…'**
  String get mcpPageStatusConnecting;

  /// No description provided for @mcpPageStatusDisconnected.
  ///
  /// In en, this message translates to:
  /// **'Disconnected'**
  String get mcpPageStatusDisconnected;

  /// No description provided for @mcpPageStatusAuthorizationRequired.
  ///
  /// In en, this message translates to:
  /// **'Authorization required'**
  String get mcpPageStatusAuthorizationRequired;

  /// No description provided for @mcpPageStatusAuthorizing.
  ///
  /// In en, this message translates to:
  /// **'Authorizing…'**
  String get mcpPageStatusAuthorizing;

  /// No description provided for @mcpPageStatusDisabled.
  ///
  /// In en, this message translates to:
  /// **'Disabled'**
  String get mcpPageStatusDisabled;

  /// No description provided for @mcpPageOAuthRequired.
  ///
  /// In en, this message translates to:
  /// **'OAuth sign-in is required'**
  String get mcpPageOAuthRequired;

  /// No description provided for @mcpPageOAuthSignIn.
  ///
  /// In en, this message translates to:
  /// **'Sign in with OAuth'**
  String get mcpPageOAuthSignIn;

  /// No description provided for @mcpPageToolsCount.
  ///
  /// In en, this message translates to:
  /// **'Tools: {enabled}/{total}'**
  String mcpPageToolsCount(int enabled, int total);

  /// No description provided for @mcpPageConnectionFailed.
  ///
  /// In en, this message translates to:
  /// **'Connection failed'**
  String get mcpPageConnectionFailed;

  /// No description provided for @mcpPageDetails.
  ///
  /// In en, this message translates to:
  /// **'Details'**
  String get mcpPageDetails;

  /// No description provided for @mcpPageDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get mcpPageDelete;

  /// No description provided for @mcpPageConfirmDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Confirm Delete'**
  String get mcpPageConfirmDeleteTitle;

  /// No description provided for @mcpPageConfirmDeleteContent.
  ///
  /// In en, this message translates to:
  /// **'This can be undone via Undo. Delete?'**
  String get mcpPageConfirmDeleteContent;

  /// No description provided for @mcpPageServerDeleted.
  ///
  /// In en, this message translates to:
  /// **'Server deleted'**
  String get mcpPageServerDeleted;

  /// No description provided for @mcpPageUndo.
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get mcpPageUndo;

  /// No description provided for @mcpPageCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get mcpPageCancel;

  /// No description provided for @mcpConversationSheetTitle.
  ///
  /// In en, this message translates to:
  /// **'MCP Servers'**
  String get mcpConversationSheetTitle;

  /// No description provided for @mcpConversationSheetSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Select servers enabled for this conversation'**
  String get mcpConversationSheetSubtitle;

  /// No description provided for @mcpConversationSheetSelectAll.
  ///
  /// In en, this message translates to:
  /// **'Select All'**
  String get mcpConversationSheetSelectAll;

  /// No description provided for @mcpConversationSheetClearAll.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get mcpConversationSheetClearAll;

  /// No description provided for @mcpConversationSheetNoRunning.
  ///
  /// In en, this message translates to:
  /// **'No running MCP servers'**
  String get mcpConversationSheetNoRunning;

  /// No description provided for @mcpConversationSheetConnected.
  ///
  /// In en, this message translates to:
  /// **'Connected'**
  String get mcpConversationSheetConnected;

  /// No description provided for @mcpConversationSheetToolsCount.
  ///
  /// In en, this message translates to:
  /// **'Tools: {enabled}/{total}'**
  String mcpConversationSheetToolsCount(int enabled, int total);

  /// No description provided for @mcpServerEditSheetEnabledLabel.
  ///
  /// In en, this message translates to:
  /// **'Enabled'**
  String get mcpServerEditSheetEnabledLabel;

  /// No description provided for @mcpServerEditSheetNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get mcpServerEditSheetNameLabel;

  /// No description provided for @mcpServerEditSheetTransportLabel.
  ///
  /// In en, this message translates to:
  /// **'Transport'**
  String get mcpServerEditSheetTransportLabel;

  /// No description provided for @mcpServerEditSheetSseRetryHint.
  ///
  /// In en, this message translates to:
  /// **'If SSE fails, try a few times'**
  String get mcpServerEditSheetSseRetryHint;

  /// No description provided for @mcpServerEditSheetUrlLabel.
  ///
  /// In en, this message translates to:
  /// **'Server URL'**
  String get mcpServerEditSheetUrlLabel;

  /// No description provided for @mcpServerEditSheetCustomHeadersTitle.
  ///
  /// In en, this message translates to:
  /// **'Custom Headers'**
  String get mcpServerEditSheetCustomHeadersTitle;

  /// No description provided for @mcpServerEditSheetHeaderNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Header Name'**
  String get mcpServerEditSheetHeaderNameLabel;

  /// No description provided for @mcpServerEditSheetHeaderNameHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. Authorization'**
  String get mcpServerEditSheetHeaderNameHint;

  /// No description provided for @mcpServerEditSheetHeaderValueLabel.
  ///
  /// In en, this message translates to:
  /// **'Header Value'**
  String get mcpServerEditSheetHeaderValueLabel;

  /// No description provided for @mcpServerEditSheetHeaderValueHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. Bearer xxxxxx'**
  String get mcpServerEditSheetHeaderValueHint;

  /// No description provided for @mcpServerEditSheetRemoveHeaderTooltip.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get mcpServerEditSheetRemoveHeaderTooltip;

  /// No description provided for @mcpServerEditSheetAddHeader.
  ///
  /// In en, this message translates to:
  /// **'Add Header'**
  String get mcpServerEditSheetAddHeader;

  /// No description provided for @mcpServerEditSheetTitleEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit MCP'**
  String get mcpServerEditSheetTitleEdit;

  /// No description provided for @mcpServerEditSheetTitleAdd.
  ///
  /// In en, this message translates to:
  /// **'Add MCP'**
  String get mcpServerEditSheetTitleAdd;

  /// No description provided for @mcpServerEditSheetSyncToolsTooltip.
  ///
  /// In en, this message translates to:
  /// **'Sync Tools'**
  String get mcpServerEditSheetSyncToolsTooltip;

  /// No description provided for @mcpServerEditSheetTabBasic.
  ///
  /// In en, this message translates to:
  /// **'Basic'**
  String get mcpServerEditSheetTabBasic;

  /// No description provided for @mcpServerEditSheetTabTools.
  ///
  /// In en, this message translates to:
  /// **'Tools'**
  String get mcpServerEditSheetTabTools;

  /// No description provided for @mcpServerEditSheetNoToolsHint.
  ///
  /// In en, this message translates to:
  /// **'No tools, tap refresh to sync'**
  String get mcpServerEditSheetNoToolsHint;

  /// No description provided for @mcpServerEditSheetCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get mcpServerEditSheetCancel;

  /// No description provided for @mcpServerEditSheetSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get mcpServerEditSheetSave;

  /// No description provided for @mcpServerEditSheetUrlRequired.
  ///
  /// In en, this message translates to:
  /// **'Please enter server URL'**
  String get mcpServerEditSheetUrlRequired;

  /// No description provided for @defaultModelPageBackTooltip.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get defaultModelPageBackTooltip;

  /// No description provided for @defaultModelPageTitle.
  ///
  /// In en, this message translates to:
  /// **'Default Model'**
  String get defaultModelPageTitle;

  /// No description provided for @defaultModelPageChatModelTitle.
  ///
  /// In en, this message translates to:
  /// **'Chat Model'**
  String get defaultModelPageChatModelTitle;

  /// No description provided for @defaultModelPageChatModelSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Global default chat model'**
  String get defaultModelPageChatModelSubtitle;

  /// No description provided for @defaultModelPageTitleModelTitle.
  ///
  /// In en, this message translates to:
  /// **'Title Summary Model'**
  String get defaultModelPageTitleModelTitle;

  /// No description provided for @defaultModelPageTitleModelSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Summarizes conversation titles using the current chat model by default, or a selected model.'**
  String get defaultModelPageTitleModelSubtitle;

  /// No description provided for @titleModelThinkingTitle.
  ///
  /// In en, this message translates to:
  /// **'Enable Thinking'**
  String get titleModelThinkingTitle;

  /// No description provided for @defaultModelPageSummaryModelTitle.
  ///
  /// In en, this message translates to:
  /// **'Summary Model'**
  String get defaultModelPageSummaryModelTitle;

  /// No description provided for @defaultModelPageSummaryModelSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Used for generating conversation summaries; prefer fast and cheap models'**
  String get defaultModelPageSummaryModelSubtitle;

  /// No description provided for @defaultModelPageSuggestionModelTitle.
  ///
  /// In en, this message translates to:
  /// **'Chat Suggestions Model'**
  String get defaultModelPageSuggestionModelTitle;

  /// No description provided for @defaultModelPageSuggestionModelSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Generates follow-up suggestion bubbles using the current chat model or a selected model. Disabled by default.'**
  String get defaultModelPageSuggestionModelSubtitle;

  /// No description provided for @assistantEditRecentChatsSummaryFrequencyTitle.
  ///
  /// In en, this message translates to:
  /// **'Summary Refresh Frequency'**
  String get assistantEditRecentChatsSummaryFrequencyTitle;

  /// No description provided for @assistantEditRecentChatsSummaryFrequencyDescription.
  ///
  /// In en, this message translates to:
  /// **'Refresh recent-chat summaries after the selected number of new messages.'**
  String get assistantEditRecentChatsSummaryFrequencyDescription;

  /// No description provided for @assistantEditRecentChatsSummaryFrequencyOption.
  ///
  /// In en, this message translates to:
  /// **'Every {count}'**
  String assistantEditRecentChatsSummaryFrequencyOption(int count);

  /// No description provided for @assistantEditRecentChatsSummaryFrequencyCustomButton.
  ///
  /// In en, this message translates to:
  /// **'Custom'**
  String get assistantEditRecentChatsSummaryFrequencyCustomButton;

  /// No description provided for @assistantEditRecentChatsSummaryFrequencyCustomTitle.
  ///
  /// In en, this message translates to:
  /// **'Custom Summary Frequency'**
  String get assistantEditRecentChatsSummaryFrequencyCustomTitle;

  /// No description provided for @assistantEditRecentChatsSummaryFrequencyCustomDescription.
  ///
  /// In en, this message translates to:
  /// **'Enter how many new messages should accumulate before refreshing the recent-chat summary.'**
  String get assistantEditRecentChatsSummaryFrequencyCustomDescription;

  /// No description provided for @assistantEditRecentChatsSummaryFrequencyCustomLabel.
  ///
  /// In en, this message translates to:
  /// **'New message count'**
  String get assistantEditRecentChatsSummaryFrequencyCustomLabel;

  /// No description provided for @assistantEditRecentChatsSummaryFrequencyCustomHint.
  ///
  /// In en, this message translates to:
  /// **'Enter a number greater than 0'**
  String get assistantEditRecentChatsSummaryFrequencyCustomHint;

  /// No description provided for @assistantEditRecentChatsSummaryFrequencyCustomInvalid.
  ///
  /// In en, this message translates to:
  /// **'Please enter a whole number greater than 0'**
  String get assistantEditRecentChatsSummaryFrequencyCustomInvalid;

  /// No description provided for @defaultModelPageTranslateModelTitle.
  ///
  /// In en, this message translates to:
  /// **'Translation Model'**
  String get defaultModelPageTranslateModelTitle;

  /// No description provided for @defaultModelPageTranslateModelSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Used for translating message content; prefer fast & accurate models'**
  String get defaultModelPageTranslateModelSubtitle;

  /// No description provided for @defaultModelPageOcrModelTitle.
  ///
  /// In en, this message translates to:
  /// **'OCR Model'**
  String get defaultModelPageOcrModelTitle;

  /// No description provided for @backgroundTaskFailed.
  ///
  /// In en, this message translates to:
  /// **'{task} failed: {error}'**
  String backgroundTaskFailed(String task, String error);

  /// No description provided for @defaultModelPageOcrModelSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Used for extracting text and descriptions from images'**
  String get defaultModelPageOcrModelSubtitle;

  /// No description provided for @defaultModelPageOcrModelRequiresImageInput.
  ///
  /// In en, this message translates to:
  /// **'Select a model tagged with image input for OCR'**
  String get defaultModelPageOcrModelRequiresImageInput;

  /// No description provided for @defaultModelPagePromptLabel.
  ///
  /// In en, this message translates to:
  /// **'Prompt'**
  String get defaultModelPagePromptLabel;

  /// No description provided for @defaultModelPageTitlePromptHint.
  ///
  /// In en, this message translates to:
  /// **'Enter prompt template for title summarization'**
  String get defaultModelPageTitlePromptHint;

  /// No description provided for @defaultModelPageSummaryPromptHint.
  ///
  /// In en, this message translates to:
  /// **'Enter prompt template for summary generation'**
  String get defaultModelPageSummaryPromptHint;

  /// No description provided for @defaultModelPageSuggestionPromptHint.
  ///
  /// In en, this message translates to:
  /// **'Enter prompt template for chat suggestions'**
  String get defaultModelPageSuggestionPromptHint;

  /// No description provided for @defaultModelPageTranslatePromptHint.
  ///
  /// In en, this message translates to:
  /// **'Enter prompt template for translation'**
  String get defaultModelPageTranslatePromptHint;

  /// No description provided for @defaultModelPageOcrPromptHint.
  ///
  /// In en, this message translates to:
  /// **'Enter prompt template for OCR image understanding'**
  String get defaultModelPageOcrPromptHint;

  /// No description provided for @defaultModelPageResetDefault.
  ///
  /// In en, this message translates to:
  /// **'Reset to default'**
  String get defaultModelPageResetDefault;

  /// No description provided for @defaultModelPageDisable.
  ///
  /// In en, this message translates to:
  /// **'Disable'**
  String get defaultModelPageDisable;

  /// No description provided for @defaultModelPageSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get defaultModelPageSave;

  /// No description provided for @defaultModelPageTitleVars.
  ///
  /// In en, this message translates to:
  /// **'Vars: content: {contentVar}, locale: {localeVar}'**
  String defaultModelPageTitleVars(String contentVar, String localeVar);

  /// No description provided for @defaultModelPageSummaryVars.
  ///
  /// In en, this message translates to:
  /// **'Variables: previous summary: {previousSummaryVar}, new messages: {userMessagesVar}'**
  String defaultModelPageSummaryVars(
    String previousSummaryVar,
    String userMessagesVar,
  );

  /// No description provided for @defaultModelPageSuggestionVars.
  ///
  /// In en, this message translates to:
  /// **'Variables: conversation: {contentVar}, language: {localeVar}'**
  String defaultModelPageSuggestionVars(String contentVar, String localeVar);

  /// No description provided for @defaultModelPageCompressModelTitle.
  ///
  /// In en, this message translates to:
  /// **'Compress Model'**
  String get defaultModelPageCompressModelTitle;

  /// No description provided for @defaultModelPageCompressModelSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Used for compressing conversation context; prefer fast models'**
  String get defaultModelPageCompressModelSubtitle;

  /// No description provided for @defaultModelPageCompressPromptHint.
  ///
  /// In en, this message translates to:
  /// **'Enter prompt template for context compression'**
  String get defaultModelPageCompressPromptHint;

  /// No description provided for @defaultModelPageCompressVars.
  ///
  /// In en, this message translates to:
  /// **'Variables: conversation: {contentVar}, language: {localeVar}'**
  String defaultModelPageCompressVars(String contentVar, String localeVar);

  /// No description provided for @defaultModelPageTranslateVars.
  ///
  /// In en, this message translates to:
  /// **'Variables: source text: {sourceVar}, target language: {targetVar}'**
  String defaultModelPageTranslateVars(String sourceVar, String targetVar);

  /// No description provided for @defaultModelPageUseCurrentModel.
  ///
  /// In en, this message translates to:
  /// **'Use current chat model'**
  String get defaultModelPageUseCurrentModel;

  /// No description provided for @defaultModelPageNotEnabled.
  ///
  /// In en, this message translates to:
  /// **'Not enabled'**
  String get defaultModelPageNotEnabled;

  /// No description provided for @translatePagePasteButton.
  ///
  /// In en, this message translates to:
  /// **'Paste'**
  String get translatePagePasteButton;

  /// No description provided for @translatePageCopyResult.
  ///
  /// In en, this message translates to:
  /// **'Copy result'**
  String get translatePageCopyResult;

  /// No description provided for @translatePageClearAll.
  ///
  /// In en, this message translates to:
  /// **'Clear All'**
  String get translatePageClearAll;

  /// No description provided for @translatePageInputHint.
  ///
  /// In en, this message translates to:
  /// **'Enter text to translate…'**
  String get translatePageInputHint;

  /// No description provided for @translatePageOutputHint.
  ///
  /// In en, this message translates to:
  /// **'Translated result appears here…'**
  String get translatePageOutputHint;

  /// No description provided for @modelDetailSheetAddModel.
  ///
  /// In en, this message translates to:
  /// **'Add Model'**
  String get modelDetailSheetAddModel;

  /// No description provided for @modelDetailSheetEditModel.
  ///
  /// In en, this message translates to:
  /// **'Edit Model'**
  String get modelDetailSheetEditModel;

  /// No description provided for @modelDetailSheetBasicTab.
  ///
  /// In en, this message translates to:
  /// **'Basic'**
  String get modelDetailSheetBasicTab;

  /// No description provided for @modelDetailSheetAdvancedTab.
  ///
  /// In en, this message translates to:
  /// **'Advanced'**
  String get modelDetailSheetAdvancedTab;

  /// No description provided for @modelDetailSheetBuiltinToolsTab.
  ///
  /// In en, this message translates to:
  /// **'Built-in Tools'**
  String get modelDetailSheetBuiltinToolsTab;

  /// No description provided for @modelDetailSheetModelIdLabel.
  ///
  /// In en, this message translates to:
  /// **'Model ID'**
  String get modelDetailSheetModelIdLabel;

  /// No description provided for @modelDetailSheetModelIdHint.
  ///
  /// In en, this message translates to:
  /// **'Required, suggest lowercase/digits/hyphens'**
  String get modelDetailSheetModelIdHint;

  /// No description provided for @modelDetailSheetModelIdDisabledHint.
  ///
  /// In en, this message translates to:
  /// **'{modelId}'**
  String modelDetailSheetModelIdDisabledHint(String modelId);

  /// No description provided for @modelDetailSheetModelNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Model Name'**
  String get modelDetailSheetModelNameLabel;

  /// No description provided for @modelDetailSheetModelTypeLabel.
  ///
  /// In en, this message translates to:
  /// **'Model Type'**
  String get modelDetailSheetModelTypeLabel;

  /// No description provided for @modelDetailSheetChatType.
  ///
  /// In en, this message translates to:
  /// **'Chat'**
  String get modelDetailSheetChatType;

  /// No description provided for @modelDetailSheetEmbeddingType.
  ///
  /// In en, this message translates to:
  /// **'Embedding'**
  String get modelDetailSheetEmbeddingType;

  /// No description provided for @modelDetailSheetInputModesLabel.
  ///
  /// In en, this message translates to:
  /// **'Input Modes'**
  String get modelDetailSheetInputModesLabel;

  /// No description provided for @modelDetailSheetOutputModesLabel.
  ///
  /// In en, this message translates to:
  /// **'Output Modes'**
  String get modelDetailSheetOutputModesLabel;

  /// No description provided for @modelDetailSheetAbilitiesLabel.
  ///
  /// In en, this message translates to:
  /// **'Abilities'**
  String get modelDetailSheetAbilitiesLabel;

  /// No description provided for @modelDetailSheetTextMode.
  ///
  /// In en, this message translates to:
  /// **'Text'**
  String get modelDetailSheetTextMode;

  /// No description provided for @modelDetailSheetImageMode.
  ///
  /// In en, this message translates to:
  /// **'Image'**
  String get modelDetailSheetImageMode;

  /// No description provided for @modelDetailSheetToolsAbility.
  ///
  /// In en, this message translates to:
  /// **'Tools'**
  String get modelDetailSheetToolsAbility;

  /// No description provided for @modelDetailSheetReasoningAbility.
  ///
  /// In en, this message translates to:
  /// **'Reasoning'**
  String get modelDetailSheetReasoningAbility;

  /// No description provided for @modelDetailSheetProviderOverrideDescription.
  ///
  /// In en, this message translates to:
  /// **'Provider overrides: customize provider for a specific model.'**
  String get modelDetailSheetProviderOverrideDescription;

  /// No description provided for @modelDetailSheetAddProviderOverride.
  ///
  /// In en, this message translates to:
  /// **'Add Provider Override'**
  String get modelDetailSheetAddProviderOverride;

  /// No description provided for @modelDetailSheetCustomHeadersTitle.
  ///
  /// In en, this message translates to:
  /// **'Custom Headers'**
  String get modelDetailSheetCustomHeadersTitle;

  /// No description provided for @modelDetailSheetAddHeader.
  ///
  /// In en, this message translates to:
  /// **'Add Header'**
  String get modelDetailSheetAddHeader;

  /// No description provided for @modelDetailSheetCustomBodyTitle.
  ///
  /// In en, this message translates to:
  /// **'Custom Body'**
  String get modelDetailSheetCustomBodyTitle;

  /// No description provided for @modelFetchInvertTooltip.
  ///
  /// In en, this message translates to:
  /// **'Invert'**
  String get modelFetchInvertTooltip;

  /// No description provided for @modelDetailSheetSaveFailedMessage.
  ///
  /// In en, this message translates to:
  /// **'Save failed. Please try again.'**
  String get modelDetailSheetSaveFailedMessage;

  /// No description provided for @modelDetailSheetAddBody.
  ///
  /// In en, this message translates to:
  /// **'Add Body'**
  String get modelDetailSheetAddBody;

  /// No description provided for @modelDetailSheetBuiltinToolsDescription.
  ///
  /// In en, this message translates to:
  /// **'Built-in tools depend on the provider and API mode.'**
  String get modelDetailSheetBuiltinToolsDescription;

  /// No description provided for @modelDetailSheetSearchTool.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get modelDetailSheetSearchTool;

  /// No description provided for @modelDetailSheetSearchToolDescription.
  ///
  /// In en, this message translates to:
  /// **'Enable Google Search integration'**
  String get modelDetailSheetSearchToolDescription;

  /// No description provided for @modelDetailSheetUrlContextTool.
  ///
  /// In en, this message translates to:
  /// **'URL Context'**
  String get modelDetailSheetUrlContextTool;

  /// No description provided for @modelDetailSheetUrlContextToolDescription.
  ///
  /// In en, this message translates to:
  /// **'Enable URL content ingestion'**
  String get modelDetailSheetUrlContextToolDescription;

  /// No description provided for @modelDetailSheetCodeExecutionTool.
  ///
  /// In en, this message translates to:
  /// **'Code Execution'**
  String get modelDetailSheetCodeExecutionTool;

  /// No description provided for @modelDetailSheetCodeExecutionToolDescription.
  ///
  /// In en, this message translates to:
  /// **'Enable code execution tool'**
  String get modelDetailSheetCodeExecutionToolDescription;

  /// No description provided for @modelDetailSheetYoutubeTool.
  ///
  /// In en, this message translates to:
  /// **'YouTube'**
  String get modelDetailSheetYoutubeTool;

  /// No description provided for @modelDetailSheetYoutubeToolDescription.
  ///
  /// In en, this message translates to:
  /// **'Enable YouTube URL ingestion (auto-detect links in prompts)'**
  String get modelDetailSheetYoutubeToolDescription;

  /// No description provided for @modelDetailSheetOpenaiBuiltinToolsResponsesOnlyHint.
  ///
  /// In en, this message translates to:
  /// **'Requires OpenAI Responses API.'**
  String get modelDetailSheetOpenaiBuiltinToolsResponsesOnlyHint;

  /// No description provided for @modelDetailSheetWebFetchTool.
  ///
  /// In en, this message translates to:
  /// **'Web Fetch'**
  String get modelDetailSheetWebFetchTool;

  /// No description provided for @modelDetailSheetOpenrouterWebFetchToolDescription.
  ///
  /// In en, this message translates to:
  /// **'Enable OpenRouter web fetch server tool'**
  String get modelDetailSheetOpenrouterWebFetchToolDescription;

  /// No description provided for @modelDetailSheetClaudeWebFetchToolDescription.
  ///
  /// In en, this message translates to:
  /// **'Let Claude fetch pages and PDFs from URLs in the conversation'**
  String get modelDetailSheetClaudeWebFetchToolDescription;

  /// No description provided for @modelDetailSheetClaudeCodeExecutionToolDescription.
  ///
  /// In en, this message translates to:
  /// **'Let Claude run Python and Bash in Anthropic\'s sandbox'**
  String get modelDetailSheetClaudeCodeExecutionToolDescription;

  /// No description provided for @modelDetailSheetOpenrouterShellTool.
  ///
  /// In en, this message translates to:
  /// **'Shell'**
  String get modelDetailSheetOpenrouterShellTool;

  /// No description provided for @modelDetailSheetOpenrouterShellToolDescription.
  ///
  /// In en, this message translates to:
  /// **'Run Shell commands in a hosted, isolated sandbox'**
  String get modelDetailSheetOpenrouterShellToolDescription;

  /// No description provided for @modelDetailSheetOpenaiCodeInterpreterTool.
  ///
  /// In en, this message translates to:
  /// **'Code Interpreter'**
  String get modelDetailSheetOpenaiCodeInterpreterTool;

  /// No description provided for @modelDetailSheetOpenaiCodeInterpreterToolDescription.
  ///
  /// In en, this message translates to:
  /// **'Enable code interpreter tool (container auto, memory limit 4g)'**
  String get modelDetailSheetOpenaiCodeInterpreterToolDescription;

  /// No description provided for @modelDetailSheetOpenaiImageGenerationTool.
  ///
  /// In en, this message translates to:
  /// **'Image Generation'**
  String get modelDetailSheetOpenaiImageGenerationTool;

  /// No description provided for @modelDetailSheetOpenaiImageGenerationToolDescription.
  ///
  /// In en, this message translates to:
  /// **'Enable image generation tool'**
  String get modelDetailSheetOpenaiImageGenerationToolDescription;

  /// No description provided for @modelDetailSheetCancelButton.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get modelDetailSheetCancelButton;

  /// No description provided for @modelDetailSheetAddButton.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get modelDetailSheetAddButton;

  /// No description provided for @modelDetailSheetConfirmButton.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get modelDetailSheetConfirmButton;

  /// No description provided for @modelDetailSheetInvalidIdError.
  ///
  /// In en, this message translates to:
  /// **'Please enter a valid model ID (>=2 chars)'**
  String get modelDetailSheetInvalidIdError;

  /// No description provided for @modelDetailSheetModelIdExistsError.
  ///
  /// In en, this message translates to:
  /// **'Model ID already exists'**
  String get modelDetailSheetModelIdExistsError;

  /// No description provided for @modelDetailSheetHeaderKeyHint.
  ///
  /// In en, this message translates to:
  /// **'Header Key'**
  String get modelDetailSheetHeaderKeyHint;

  /// No description provided for @modelDetailSheetHeaderValueHint.
  ///
  /// In en, this message translates to:
  /// **'Header Value'**
  String get modelDetailSheetHeaderValueHint;

  /// No description provided for @modelDetailSheetBodyKeyHint.
  ///
  /// In en, this message translates to:
  /// **'Body Key'**
  String get modelDetailSheetBodyKeyHint;

  /// No description provided for @modelDetailSheetBodyJsonHint.
  ///
  /// In en, this message translates to:
  /// **'Body JSON'**
  String get modelDetailSheetBodyJsonHint;

  /// No description provided for @modelSelectSheetSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search models or providers'**
  String get modelSelectSheetSearchHint;

  /// No description provided for @modelSelectSheetFavoritesSection.
  ///
  /// In en, this message translates to:
  /// **'Favorites'**
  String get modelSelectSheetFavoritesSection;

  /// No description provided for @modelSelectSheetFollowAssistant.
  ///
  /// In en, this message translates to:
  /// **'Follow assistant'**
  String get modelSelectSheetFollowAssistant;

  /// No description provided for @modelSelectSheetFavoriteTooltip.
  ///
  /// In en, this message translates to:
  /// **'Favorite'**
  String get modelSelectSheetFavoriteTooltip;

  /// No description provided for @modelSelectSheetChatType.
  ///
  /// In en, this message translates to:
  /// **'Chat'**
  String get modelSelectSheetChatType;

  /// No description provided for @modelSelectSheetEmbeddingType.
  ///
  /// In en, this message translates to:
  /// **'Embedding'**
  String get modelSelectSheetEmbeddingType;

  /// No description provided for @providerDetailPageShareTooltip.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get providerDetailPageShareTooltip;

  /// No description provided for @providerDetailPageDeleteProviderTooltip.
  ///
  /// In en, this message translates to:
  /// **'Delete Provider'**
  String get providerDetailPageDeleteProviderTooltip;

  /// No description provided for @providerDetailPageDeleteProviderTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete Provider'**
  String get providerDetailPageDeleteProviderTitle;

  /// No description provided for @providerDetailPageDeleteProviderContent.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete this provider? This cannot be undone.'**
  String get providerDetailPageDeleteProviderContent;

  /// No description provided for @providerDetailPageCancelButton.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get providerDetailPageCancelButton;

  /// No description provided for @providerDetailPageDeleteButton.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get providerDetailPageDeleteButton;

  /// No description provided for @providerDetailPageProviderDeletedSnackbar.
  ///
  /// In en, this message translates to:
  /// **'Provider deleted'**
  String get providerDetailPageProviderDeletedSnackbar;

  /// No description provided for @providerDetailPageConfigTab.
  ///
  /// In en, this message translates to:
  /// **'Config'**
  String get providerDetailPageConfigTab;

  /// No description provided for @providerDetailPageModelsTab.
  ///
  /// In en, this message translates to:
  /// **'Models'**
  String get providerDetailPageModelsTab;

  /// No description provided for @providerDetailPageCustomRequestTitle.
  ///
  /// In en, this message translates to:
  /// **'Custom Request'**
  String get providerDetailPageCustomRequestTitle;

  /// No description provided for @providerDetailPageCustomRequestDescription.
  ///
  /// In en, this message translates to:
  /// **'Applies to every model from this provider. Model settings override these values; these values override assistant settings.'**
  String get providerDetailPageCustomRequestDescription;

  /// No description provided for @providerDetailPageNetworkTab.
  ///
  /// In en, this message translates to:
  /// **'Network'**
  String get providerDetailPageNetworkTab;

  /// No description provided for @providerDetailPageEnabledTitle.
  ///
  /// In en, this message translates to:
  /// **'Enabled'**
  String get providerDetailPageEnabledTitle;

  /// No description provided for @providerDetailPageManageSectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Manage'**
  String get providerDetailPageManageSectionTitle;

  /// No description provided for @providerDetailPageNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get providerDetailPageNameLabel;

  /// No description provided for @providerDetailPageApiKeyHint.
  ///
  /// In en, this message translates to:
  /// **'Leave empty to use default'**
  String get providerDetailPageApiKeyHint;

  /// No description provided for @providerDetailPageHideTooltip.
  ///
  /// In en, this message translates to:
  /// **'Hide'**
  String get providerDetailPageHideTooltip;

  /// No description provided for @providerDetailPageShowTooltip.
  ///
  /// In en, this message translates to:
  /// **'Show'**
  String get providerDetailPageShowTooltip;

  /// No description provided for @providerDetailPageApiPathLabel.
  ///
  /// In en, this message translates to:
  /// **'API Path'**
  String get providerDetailPageApiPathLabel;

  /// No description provided for @providerDetailPageResponseApiTitle.
  ///
  /// In en, this message translates to:
  /// **'Response API (/responses)'**
  String get providerDetailPageResponseApiTitle;

  /// No description provided for @providerDetailPageAihubmixAppCodeLabel.
  ///
  /// In en, this message translates to:
  /// **'APP-Code (10% off)'**
  String get providerDetailPageAihubmixAppCodeLabel;

  /// No description provided for @providerDetailPageAihubmixAppCodeHelp.
  ///
  /// In en, this message translates to:
  /// **'Adds header APP-Code requests to get a 10% discount. Only affects AIhubmix.'**
  String get providerDetailPageAihubmixAppCodeHelp;

  /// No description provided for @providerDetailPageClaudePromptCachingTitle.
  ///
  /// In en, this message translates to:
  /// **'Claude Prompt Caching'**
  String get providerDetailPageClaudePromptCachingTitle;

  /// No description provided for @providerDetailPageClaudePromptCachingHelp.
  ///
  /// In en, this message translates to:
  /// **'Adds cache_control to Claude requests through Anthropic or OpenRouter.'**
  String get providerDetailPageClaudePromptCachingHelp;

  /// No description provided for @providerDetailPageClaudePromptCachingTtlTitle.
  ///
  /// In en, this message translates to:
  /// **'Cache TTL'**
  String get providerDetailPageClaudePromptCachingTtlTitle;

  /// No description provided for @providerDetailPageClaudePromptCachingTtlHelp.
  ///
  /// In en, this message translates to:
  /// **'5 minutes is the default. 1 hour costs more to write but can reduce rebuilds in long conversations.'**
  String get providerDetailPageClaudePromptCachingTtlHelp;

  /// No description provided for @providerDetailPageClaudePromptCachingTtl5m.
  ///
  /// In en, this message translates to:
  /// **'5 min'**
  String get providerDetailPageClaudePromptCachingTtl5m;

  /// No description provided for @providerDetailPageClaudePromptCachingTtl1h.
  ///
  /// In en, this message translates to:
  /// **'1 hour'**
  String get providerDetailPageClaudePromptCachingTtl1h;

  /// No description provided for @providerDetailPageBalanceTitle.
  ///
  /// In en, this message translates to:
  /// **'Account Balance'**
  String get providerDetailPageBalanceTitle;

  /// No description provided for @providerDetailPageBalanceInfo.
  ///
  /// In en, this message translates to:
  /// **'Get account balance'**
  String get providerDetailPageBalanceInfo;

  /// No description provided for @providerDetailPageBalanceApiPathLabel.
  ///
  /// In en, this message translates to:
  /// **'Balance API Path'**
  String get providerDetailPageBalanceApiPathLabel;

  /// No description provided for @providerDetailPageBalanceResultPathLabel.
  ///
  /// In en, this message translates to:
  /// **'Result JSON Path'**
  String get providerDetailPageBalanceResultPathLabel;

  /// No description provided for @providerDetailPageBalanceQueryButton.
  ///
  /// In en, this message translates to:
  /// **'Check Balance'**
  String get providerDetailPageBalanceQueryButton;

  /// No description provided for @providerDetailPageBalanceQuerying.
  ///
  /// In en, this message translates to:
  /// **'Checking...'**
  String get providerDetailPageBalanceQuerying;

  /// No description provided for @providerDetailPageBalanceResetDefaultsButton.
  ///
  /// In en, this message translates to:
  /// **'Reset'**
  String get providerDetailPageBalanceResetDefaultsButton;

  /// No description provided for @providerDetailPageBalanceResetDefaultsTooltip.
  ///
  /// In en, this message translates to:
  /// **'Reset balance settings'**
  String get providerDetailPageBalanceResetDefaultsTooltip;

  /// No description provided for @providerDetailPageBalanceResult.
  ///
  /// In en, this message translates to:
  /// **'Balance: {value}'**
  String providerDetailPageBalanceResult(String value);

  /// No description provided for @providerDetailPageBalanceError.
  ///
  /// In en, this message translates to:
  /// **'Balance query failed: {message}'**
  String providerDetailPageBalanceError(String message);

  /// No description provided for @providerDetailPageVertexAiTitle.
  ///
  /// In en, this message translates to:
  /// **'Vertex AI'**
  String get providerDetailPageVertexAiTitle;

  /// No description provided for @providerDetailPageLocationLabel.
  ///
  /// In en, this message translates to:
  /// **'Location'**
  String get providerDetailPageLocationLabel;

  /// No description provided for @providerDetailPageProjectIdLabel.
  ///
  /// In en, this message translates to:
  /// **'Project ID'**
  String get providerDetailPageProjectIdLabel;

  /// No description provided for @providerDetailPageServiceAccountJsonLabel.
  ///
  /// In en, this message translates to:
  /// **'Service Account JSON (paste or import)'**
  String get providerDetailPageServiceAccountJsonLabel;

  /// No description provided for @providerDetailPageImportJsonButton.
  ///
  /// In en, this message translates to:
  /// **'Import JSON'**
  String get providerDetailPageImportJsonButton;

  /// No description provided for @providerDetailPageImportJsonReadFailedMessage.
  ///
  /// In en, this message translates to:
  /// **'Failed to read file'**
  String get providerDetailPageImportJsonReadFailedMessage;

  /// No description provided for @providerDetailPageTestButton.
  ///
  /// In en, this message translates to:
  /// **'Test'**
  String get providerDetailPageTestButton;

  /// No description provided for @providerDetailPageSaveButton.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get providerDetailPageSaveButton;

  /// No description provided for @providerDetailPageProviderRemovedMessage.
  ///
  /// In en, this message translates to:
  /// **'Provider removed'**
  String get providerDetailPageProviderRemovedMessage;

  /// No description provided for @providerDetailPageNoModelsTitle.
  ///
  /// In en, this message translates to:
  /// **'No Models'**
  String get providerDetailPageNoModelsTitle;

  /// No description provided for @providerDetailPageNoModelsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Tap the buttons below to add models'**
  String get providerDetailPageNoModelsSubtitle;

  /// No description provided for @providerDetailPageDeleteModelButton.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get providerDetailPageDeleteModelButton;

  /// No description provided for @providerDetailPageConfirmDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Confirm Delete'**
  String get providerDetailPageConfirmDeleteTitle;

  /// No description provided for @providerDetailPageConfirmDeleteContent.
  ///
  /// In en, this message translates to:
  /// **'This can be undone via Undo. Delete?'**
  String get providerDetailPageConfirmDeleteContent;

  /// No description provided for @providerDetailPageModelDeletedSnackbar.
  ///
  /// In en, this message translates to:
  /// **'Model deleted'**
  String get providerDetailPageModelDeletedSnackbar;

  /// No description provided for @providerDetailPageUndoButton.
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get providerDetailPageUndoButton;

  /// No description provided for @providerDetailPageAddNewModelButton.
  ///
  /// In en, this message translates to:
  /// **'Add Model'**
  String get providerDetailPageAddNewModelButton;

  /// No description provided for @providerDetailPageFetchModelsButton.
  ///
  /// In en, this message translates to:
  /// **'Fetch'**
  String get providerDetailPageFetchModelsButton;

  /// No description provided for @providerDetailPageEnableProxyTitle.
  ///
  /// In en, this message translates to:
  /// **'Enable Proxy'**
  String get providerDetailPageEnableProxyTitle;

  /// No description provided for @providerDetailPageHostLabel.
  ///
  /// In en, this message translates to:
  /// **'Host'**
  String get providerDetailPageHostLabel;

  /// No description provided for @providerDetailPagePortLabel.
  ///
  /// In en, this message translates to:
  /// **'Port'**
  String get providerDetailPagePortLabel;

  /// No description provided for @providerDetailPageUsernameOptionalLabel.
  ///
  /// In en, this message translates to:
  /// **'Username (optional)'**
  String get providerDetailPageUsernameOptionalLabel;

  /// No description provided for @providerDetailPagePasswordOptionalLabel.
  ///
  /// In en, this message translates to:
  /// **'Password (optional)'**
  String get providerDetailPagePasswordOptionalLabel;

  /// No description provided for @providerDetailPageSavedSnackbar.
  ///
  /// In en, this message translates to:
  /// **'Saved'**
  String get providerDetailPageSavedSnackbar;

  /// No description provided for @providerDetailPageEmbeddingsGroupTitle.
  ///
  /// In en, this message translates to:
  /// **'Embeddings'**
  String get providerDetailPageEmbeddingsGroupTitle;

  /// No description provided for @providerDetailPageOtherModelsGroupTitle.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get providerDetailPageOtherModelsGroupTitle;

  /// No description provided for @providerDetailPageRemoveGroupTooltip.
  ///
  /// In en, this message translates to:
  /// **'Remove group'**
  String get providerDetailPageRemoveGroupTooltip;

  /// No description provided for @providerDetailPageAddGroupTooltip.
  ///
  /// In en, this message translates to:
  /// **'Add group'**
  String get providerDetailPageAddGroupTooltip;

  /// No description provided for @providerDetailPageFilterHint.
  ///
  /// In en, this message translates to:
  /// **'Type model name to filter'**
  String get providerDetailPageFilterHint;

  /// No description provided for @providerDetailPageDeleteText.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get providerDetailPageDeleteText;

  /// No description provided for @providerDetailPageEditTooltip.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get providerDetailPageEditTooltip;

  /// No description provided for @providerDetailPageTestConnectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Test Connection'**
  String get providerDetailPageTestConnectionTitle;

  /// No description provided for @providerDetailPageSelectModelButton.
  ///
  /// In en, this message translates to:
  /// **'Select Model'**
  String get providerDetailPageSelectModelButton;

  /// No description provided for @providerDetailPageChangeButton.
  ///
  /// In en, this message translates to:
  /// **'Change'**
  String get providerDetailPageChangeButton;

  /// No description provided for @providerDetailPageUseStreamingLabel.
  ///
  /// In en, this message translates to:
  /// **'Use Streaming'**
  String get providerDetailPageUseStreamingLabel;

  /// No description provided for @providerDetailPageTestingMessage.
  ///
  /// In en, this message translates to:
  /// **'Testing…'**
  String get providerDetailPageTestingMessage;

  /// No description provided for @providerDetailPageTestSuccessMessage.
  ///
  /// In en, this message translates to:
  /// **'Success'**
  String get providerDetailPageTestSuccessMessage;

  /// No description provided for @providersPageTitle.
  ///
  /// In en, this message translates to:
  /// **'Providers'**
  String get providersPageTitle;

  /// No description provided for @providersPageImportTooltip.
  ///
  /// In en, this message translates to:
  /// **'Import'**
  String get providersPageImportTooltip;

  /// No description provided for @providersPageAddTooltip.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get providersPageAddTooltip;

  /// No description provided for @providersPageSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search providers or groups'**
  String get providersPageSearchHint;

  /// No description provided for @providersPageProviderAddedSnackbar.
  ///
  /// In en, this message translates to:
  /// **'Provider added'**
  String get providersPageProviderAddedSnackbar;

  /// No description provided for @providerGroupsGroupLabel.
  ///
  /// In en, this message translates to:
  /// **'Group'**
  String get providerGroupsGroupLabel;

  /// No description provided for @providerGroupsOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get providerGroupsOther;

  /// No description provided for @providerGroupsOtherUngroupedOption.
  ///
  /// In en, this message translates to:
  /// **'Other (Ungrouped)'**
  String get providerGroupsOtherUngroupedOption;

  /// No description provided for @providerGroupsPickerTitle.
  ///
  /// In en, this message translates to:
  /// **'Select group'**
  String get providerGroupsPickerTitle;

  /// No description provided for @providerGroupsManageTitle.
  ///
  /// In en, this message translates to:
  /// **'Manage groups'**
  String get providerGroupsManageTitle;

  /// No description provided for @providerGroupsManageAction.
  ///
  /// In en, this message translates to:
  /// **'Manage groups'**
  String get providerGroupsManageAction;

  /// No description provided for @providerGroupsCreateNewGroupAction.
  ///
  /// In en, this message translates to:
  /// **'New group…'**
  String get providerGroupsCreateNewGroupAction;

  /// No description provided for @providerGroupsCreateDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'New group'**
  String get providerGroupsCreateDialogTitle;

  /// No description provided for @providerGroupsNameHint.
  ///
  /// In en, this message translates to:
  /// **'Group name'**
  String get providerGroupsNameHint;

  /// No description provided for @providerGroupsCreateDialogCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get providerGroupsCreateDialogCancel;

  /// No description provided for @providerGroupsCreateDialogOk.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get providerGroupsCreateDialogOk;

  /// No description provided for @providerGroupsCreateFailedToast.
  ///
  /// In en, this message translates to:
  /// **'Failed to create group'**
  String get providerGroupsCreateFailedToast;

  /// No description provided for @providerGroupsDeleteConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete group?'**
  String get providerGroupsDeleteConfirmTitle;

  /// No description provided for @providerGroupsDeleteConfirmContent.
  ///
  /// In en, this message translates to:
  /// **'Providers in this group will be moved to “Other”.'**
  String get providerGroupsDeleteConfirmContent;

  /// No description provided for @providerGroupsDeleteConfirmCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get providerGroupsDeleteConfirmCancel;

  /// No description provided for @providerGroupsDeleteConfirmOk.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get providerGroupsDeleteConfirmOk;

  /// No description provided for @providerGroupsDeletedToast.
  ///
  /// In en, this message translates to:
  /// **'Group deleted'**
  String get providerGroupsDeletedToast;

  /// No description provided for @providerGroupsEmptyState.
  ///
  /// In en, this message translates to:
  /// **'No groups yet.'**
  String get providerGroupsEmptyState;

  /// No description provided for @providerGroupsExpandToMoveToast.
  ///
  /// In en, this message translates to:
  /// **'Please expand the group first.'**
  String get providerGroupsExpandToMoveToast;

  /// No description provided for @providersPageSiliconFlowName.
  ///
  /// In en, this message translates to:
  /// **'SiliconFlow'**
  String get providersPageSiliconFlowName;

  /// No description provided for @providersPageAliyunName.
  ///
  /// In en, this message translates to:
  /// **'Aliyun'**
  String get providersPageAliyunName;

  /// No description provided for @providersPageZhipuName.
  ///
  /// In en, this message translates to:
  /// **'Zhipu AI'**
  String get providersPageZhipuName;

  /// No description provided for @providersPageByteDanceName.
  ///
  /// In en, this message translates to:
  /// **'ByteDance'**
  String get providersPageByteDanceName;

  /// No description provided for @providersPageEnabledStatus.
  ///
  /// In en, this message translates to:
  /// **'ON'**
  String get providersPageEnabledStatus;

  /// No description provided for @providersPageDisabledStatus.
  ///
  /// In en, this message translates to:
  /// **'OFF'**
  String get providersPageDisabledStatus;

  /// No description provided for @providersPageModelsCountSuffix.
  ///
  /// In en, this message translates to:
  /// **' models'**
  String get providersPageModelsCountSuffix;

  /// No description provided for @providersPageModelsCountSingleSuffix.
  ///
  /// In en, this message translates to:
  /// **' models'**
  String get providersPageModelsCountSingleSuffix;

  /// No description provided for @addProviderSheetTitle.
  ///
  /// In en, this message translates to:
  /// **'Add Provider'**
  String get addProviderSheetTitle;

  /// No description provided for @addProviderSheetEnabledLabel.
  ///
  /// In en, this message translates to:
  /// **'Enabled'**
  String get addProviderSheetEnabledLabel;

  /// No description provided for @addProviderSheetNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get addProviderSheetNameLabel;

  /// No description provided for @addProviderSheetApiPathLabel.
  ///
  /// In en, this message translates to:
  /// **'API Path'**
  String get addProviderSheetApiPathLabel;

  /// No description provided for @addProviderSheetVertexAiLocationLabel.
  ///
  /// In en, this message translates to:
  /// **'Location'**
  String get addProviderSheetVertexAiLocationLabel;

  /// No description provided for @addProviderSheetVertexAiProjectIdLabel.
  ///
  /// In en, this message translates to:
  /// **'Project ID'**
  String get addProviderSheetVertexAiProjectIdLabel;

  /// No description provided for @addProviderSheetVertexAiServiceAccountJsonLabel.
  ///
  /// In en, this message translates to:
  /// **'Service Account JSON (paste or import)'**
  String get addProviderSheetVertexAiServiceAccountJsonLabel;

  /// No description provided for @addProviderSheetImportJsonButton.
  ///
  /// In en, this message translates to:
  /// **'Import JSON'**
  String get addProviderSheetImportJsonButton;

  /// No description provided for @addProviderSheetCancelButton.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get addProviderSheetCancelButton;

  /// No description provided for @addProviderSheetAddButton.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get addProviderSheetAddButton;

  /// No description provided for @importProviderSheetTitle.
  ///
  /// In en, this message translates to:
  /// **'Import Provider'**
  String get importProviderSheetTitle;

  /// No description provided for @importProviderSheetScanQrTooltip.
  ///
  /// In en, this message translates to:
  /// **'Scan QR'**
  String get importProviderSheetScanQrTooltip;

  /// No description provided for @importProviderSheetFromGalleryTooltip.
  ///
  /// In en, this message translates to:
  /// **'From Gallery'**
  String get importProviderSheetFromGalleryTooltip;

  /// No description provided for @importProviderSheetImportSuccessMessage.
  ///
  /// In en, this message translates to:
  /// **'Imported {count} provider(s)'**
  String importProviderSheetImportSuccessMessage(int count);

  /// No description provided for @importProviderSheetImportFailedMessage.
  ///
  /// In en, this message translates to:
  /// **'Import failed: {error}'**
  String importProviderSheetImportFailedMessage(String error);

  /// No description provided for @importProviderSheetDescription.
  ///
  /// In en, this message translates to:
  /// **'Paste share strings (multi-line supported) or ChatBox JSON'**
  String get importProviderSheetDescription;

  /// No description provided for @importProviderSheetInputHint.
  ///
  /// In en, this message translates to:
  /// **'ai-provider:v1:... or JSON'**
  String get importProviderSheetInputHint;

  /// No description provided for @importProviderSheetCancelButton.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get importProviderSheetCancelButton;

  /// No description provided for @importProviderSheetImportButton.
  ///
  /// In en, this message translates to:
  /// **'Import'**
  String get importProviderSheetImportButton;

  /// No description provided for @shareProviderSheetTitle.
  ///
  /// In en, this message translates to:
  /// **'Share Provider'**
  String get shareProviderSheetTitle;

  /// No description provided for @shareProviderSheetDescription.
  ///
  /// In en, this message translates to:
  /// **'Copy or share via QR code.'**
  String get shareProviderSheetDescription;

  /// No description provided for @shareProviderSheetCopiedMessage.
  ///
  /// In en, this message translates to:
  /// **'Copied'**
  String get shareProviderSheetCopiedMessage;

  /// No description provided for @shareProviderSheetCopyButton.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get shareProviderSheetCopyButton;

  /// No description provided for @shareProviderSheetShareButton.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get shareProviderSheetShareButton;

  /// No description provided for @desktopProviderContextMenuShare.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get desktopProviderContextMenuShare;

  /// No description provided for @desktopProviderShareCopyText.
  ///
  /// In en, this message translates to:
  /// **'Copy code'**
  String get desktopProviderShareCopyText;

  /// No description provided for @desktopProviderShareCopyQr.
  ///
  /// In en, this message translates to:
  /// **'Copy QR'**
  String get desktopProviderShareCopyQr;

  /// No description provided for @providerDetailPageApiBaseUrlLabel.
  ///
  /// In en, this message translates to:
  /// **'API Base URL'**
  String get providerDetailPageApiBaseUrlLabel;

  /// No description provided for @providerDetailPageModelsTitle.
  ///
  /// In en, this message translates to:
  /// **'Models'**
  String get providerDetailPageModelsTitle;

  /// No description provided for @providerModelsGetButton.
  ///
  /// In en, this message translates to:
  /// **'Get'**
  String get providerModelsGetButton;

  /// No description provided for @providerDetailPageCapsVision.
  ///
  /// In en, this message translates to:
  /// **'Vision'**
  String get providerDetailPageCapsVision;

  /// No description provided for @providerDetailPageCapsImage.
  ///
  /// In en, this message translates to:
  /// **'Image'**
  String get providerDetailPageCapsImage;

  /// No description provided for @providerDetailPageCapsTool.
  ///
  /// In en, this message translates to:
  /// **'Tool'**
  String get providerDetailPageCapsTool;

  /// No description provided for @providerDetailPageCapsReasoning.
  ///
  /// In en, this message translates to:
  /// **'Reasoning'**
  String get providerDetailPageCapsReasoning;

  /// No description provided for @qrScanPageTitle.
  ///
  /// In en, this message translates to:
  /// **'Scan QR'**
  String get qrScanPageTitle;

  /// No description provided for @qrScanPageInstruction.
  ///
  /// In en, this message translates to:
  /// **'Align the QR code within the frame'**
  String get qrScanPageInstruction;

  /// No description provided for @searchServicesPageBackTooltip.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get searchServicesPageBackTooltip;

  /// No description provided for @searchServicesPageTitle.
  ///
  /// In en, this message translates to:
  /// **'Search Services'**
  String get searchServicesPageTitle;

  /// No description provided for @searchServicesPageDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get searchServicesPageDone;

  /// No description provided for @searchServicesPageEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get searchServicesPageEdit;

  /// No description provided for @searchServicesPageAddProvider.
  ///
  /// In en, this message translates to:
  /// **'Add Provider'**
  String get searchServicesPageAddProvider;

  /// No description provided for @searchServicesPageSearchProviders.
  ///
  /// In en, this message translates to:
  /// **'Search Providers'**
  String get searchServicesPageSearchProviders;

  /// No description provided for @searchServicesPageGeneralOptions.
  ///
  /// In en, this message translates to:
  /// **'General Options'**
  String get searchServicesPageGeneralOptions;

  /// No description provided for @searchServicesPageAutoTestTitle.
  ///
  /// In en, this message translates to:
  /// **'Auto-test connections on launch'**
  String get searchServicesPageAutoTestTitle;

  /// No description provided for @searchServicesPageMaxResults.
  ///
  /// In en, this message translates to:
  /// **'Max Results'**
  String get searchServicesPageMaxResults;

  /// No description provided for @searchServicesPageTimeoutSeconds.
  ///
  /// In en, this message translates to:
  /// **'Timeout (seconds)'**
  String get searchServicesPageTimeoutSeconds;

  /// No description provided for @searchServicesPageAtLeastOneServiceRequired.
  ///
  /// In en, this message translates to:
  /// **'At least one search service is required'**
  String get searchServicesPageAtLeastOneServiceRequired;

  /// No description provided for @searchServicesPageTestingStatus.
  ///
  /// In en, this message translates to:
  /// **'Testing…'**
  String get searchServicesPageTestingStatus;

  /// No description provided for @searchServicesPageConnectedStatus.
  ///
  /// In en, this message translates to:
  /// **'Connected'**
  String get searchServicesPageConnectedStatus;

  /// No description provided for @searchServicesPageFailedStatus.
  ///
  /// In en, this message translates to:
  /// **'Failed'**
  String get searchServicesPageFailedStatus;

  /// No description provided for @searchServicesPageNotTestedStatus.
  ///
  /// In en, this message translates to:
  /// **'Not tested'**
  String get searchServicesPageNotTestedStatus;

  /// No description provided for @searchServicesPageEditServiceTooltip.
  ///
  /// In en, this message translates to:
  /// **'Edit Service'**
  String get searchServicesPageEditServiceTooltip;

  /// No description provided for @searchServicesPageTestConnectionTooltip.
  ///
  /// In en, this message translates to:
  /// **'Test Connection'**
  String get searchServicesPageTestConnectionTooltip;

  /// No description provided for @searchServicesPageDeleteServiceTooltip.
  ///
  /// In en, this message translates to:
  /// **'Delete Service'**
  String get searchServicesPageDeleteServiceTooltip;

  /// No description provided for @searchServicesPageConfiguredStatus.
  ///
  /// In en, this message translates to:
  /// **'Configured'**
  String get searchServicesPageConfiguredStatus;

  /// No description provided for @miniMapTitle.
  ///
  /// In en, this message translates to:
  /// **'Minimap'**
  String get miniMapTitle;

  /// No description provided for @miniMapTooltip.
  ///
  /// In en, this message translates to:
  /// **'Minimap'**
  String get miniMapTooltip;

  /// No description provided for @miniMapScrollToBottomTooltip.
  ///
  /// In en, this message translates to:
  /// **'Scroll to bottom'**
  String get miniMapScrollToBottomTooltip;

  /// No description provided for @miniMapSearchMatchCount.
  ///
  /// In en, this message translates to:
  /// **'{count}'**
  String miniMapSearchMatchCount(int count);

  /// No description provided for @miniMapSearchNoResults.
  ///
  /// In en, this message translates to:
  /// **'No matching messages'**
  String get miniMapSearchNoResults;

  /// No description provided for @searchServicesPageApiKeyRequiredStatus.
  ///
  /// In en, this message translates to:
  /// **'API Key Required'**
  String get searchServicesPageApiKeyRequiredStatus;

  /// No description provided for @searchServicesPageUrlRequiredStatus.
  ///
  /// In en, this message translates to:
  /// **'URL Required'**
  String get searchServicesPageUrlRequiredStatus;

  /// No description provided for @searchServicesAddDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Add Search Service'**
  String get searchServicesAddDialogTitle;

  /// No description provided for @searchServicesAddDialogServiceType.
  ///
  /// In en, this message translates to:
  /// **'Service Type'**
  String get searchServicesAddDialogServiceType;

  /// No description provided for @searchServicesAddDialogBingLocal.
  ///
  /// In en, this message translates to:
  /// **'Local'**
  String get searchServicesAddDialogBingLocal;

  /// No description provided for @searchServicesAddDialogCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get searchServicesAddDialogCancel;

  /// No description provided for @searchServicesAddDialogAdd.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get searchServicesAddDialogAdd;

  /// No description provided for @searchServicesAddDialogApiKeyRequired.
  ///
  /// In en, this message translates to:
  /// **'API Key is required'**
  String get searchServicesAddDialogApiKeyRequired;

  /// No description provided for @searchServicesFieldCustomUrlOptional.
  ///
  /// In en, this message translates to:
  /// **'Custom URL (optional)'**
  String get searchServicesFieldCustomUrlOptional;

  /// No description provided for @searchServicesDialogApiKey.
  ///
  /// In en, this message translates to:
  /// **'API Key'**
  String get searchServicesDialogApiKey;

  /// No description provided for @searchServicesDialogModel.
  ///
  /// In en, this message translates to:
  /// **'Model'**
  String get searchServicesDialogModel;

  /// No description provided for @searchServicesDialogSystemPrompt.
  ///
  /// In en, this message translates to:
  /// **'System Prompt'**
  String get searchServicesDialogSystemPrompt;

  /// No description provided for @searchServicesAddDialogInstanceUrl.
  ///
  /// In en, this message translates to:
  /// **'Instance URL'**
  String get searchServicesAddDialogInstanceUrl;

  /// No description provided for @searchServicesAddDialogUrlRequired.
  ///
  /// In en, this message translates to:
  /// **'URL is required'**
  String get searchServicesAddDialogUrlRequired;

  /// No description provided for @searchServicesAddDialogEnginesOptional.
  ///
  /// In en, this message translates to:
  /// **'Engines (optional)'**
  String get searchServicesAddDialogEnginesOptional;

  /// No description provided for @searchServicesAddDialogLanguageOptional.
  ///
  /// In en, this message translates to:
  /// **'Language (optional)'**
  String get searchServicesAddDialogLanguageOptional;

  /// No description provided for @searchServicesAddDialogUsernameOptional.
  ///
  /// In en, this message translates to:
  /// **'Username (optional)'**
  String get searchServicesAddDialogUsernameOptional;

  /// No description provided for @searchServicesAddDialogPasswordOptional.
  ///
  /// In en, this message translates to:
  /// **'Password (optional)'**
  String get searchServicesAddDialogPasswordOptional;

  /// No description provided for @searchServicesAddDialogRegionOptional.
  ///
  /// In en, this message translates to:
  /// **'Region (optional, default: us-en)'**
  String get searchServicesAddDialogRegionOptional;

  /// No description provided for @searchServicesEditDialogEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get searchServicesEditDialogEdit;

  /// No description provided for @searchServicesEditDialogCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get searchServicesEditDialogCancel;

  /// No description provided for @searchServicesEditDialogSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get searchServicesEditDialogSave;

  /// No description provided for @searchServicesEditDialogBingLocalNoConfig.
  ///
  /// In en, this message translates to:
  /// **'No configuration required for Bing Local search.'**
  String get searchServicesEditDialogBingLocalNoConfig;

  /// No description provided for @searchServicesEditDialogApiKeyRequired.
  ///
  /// In en, this message translates to:
  /// **'API Key is required'**
  String get searchServicesEditDialogApiKeyRequired;

  /// No description provided for @searchServicesEditDialogInstanceUrl.
  ///
  /// In en, this message translates to:
  /// **'Instance URL'**
  String get searchServicesEditDialogInstanceUrl;

  /// No description provided for @searchServicesEditDialogUrlRequired.
  ///
  /// In en, this message translates to:
  /// **'URL is required'**
  String get searchServicesEditDialogUrlRequired;

  /// No description provided for @searchServicesEditDialogEnginesOptional.
  ///
  /// In en, this message translates to:
  /// **'Engines (optional)'**
  String get searchServicesEditDialogEnginesOptional;

  /// No description provided for @searchServicesEditDialogLanguageOptional.
  ///
  /// In en, this message translates to:
  /// **'Language (optional)'**
  String get searchServicesEditDialogLanguageOptional;

  /// No description provided for @searchServicesEditDialogUsernameOptional.
  ///
  /// In en, this message translates to:
  /// **'Username (optional)'**
  String get searchServicesEditDialogUsernameOptional;

  /// No description provided for @searchServicesEditDialogPasswordOptional.
  ///
  /// In en, this message translates to:
  /// **'Password (optional)'**
  String get searchServicesEditDialogPasswordOptional;

  /// No description provided for @searchServicesEditDialogRegionOptional.
  ///
  /// In en, this message translates to:
  /// **'Region (optional, default: us-en)'**
  String get searchServicesEditDialogRegionOptional;

  /// No description provided for @searchServiceEditorProviderTypeTitle.
  ///
  /// In en, this message translates to:
  /// **'Search provider'**
  String get searchServiceEditorProviderTypeTitle;

  /// No description provided for @searchServiceEditorConfigurationTitle.
  ///
  /// In en, this message translates to:
  /// **'Configuration'**
  String get searchServiceEditorConfigurationTitle;

  /// No description provided for @searchServiceEditorNoConfiguration.
  ///
  /// In en, this message translates to:
  /// **'This provider does not require additional configuration.'**
  String get searchServiceEditorNoConfiguration;

  /// No description provided for @searchServiceEditorMultiKeyTitle.
  ///
  /// In en, this message translates to:
  /// **'Multi-key rotation'**
  String get searchServiceEditorMultiKeyTitle;

  /// No description provided for @searchServiceEditorMultiKeyNone.
  ///
  /// In en, this message translates to:
  /// **'Not configured'**
  String get searchServiceEditorMultiKeyNone;

  /// No description provided for @searchApiKeysPageDescription.
  ///
  /// In en, this message translates to:
  /// **'Keys rotate in the order listed; the first is the primary key. Usage is not queried to avoid provider rate limiting.'**
  String get searchApiKeysPageDescription;

  /// No description provided for @searchApiKeysPagePrimaryBadge.
  ///
  /// In en, this message translates to:
  /// **'Primary'**
  String get searchApiKeysPagePrimaryBadge;

  /// No description provided for @searchApiKeysPageBatchHint.
  ///
  /// In en, this message translates to:
  /// **'Paste one or more keys — one per line or comma-separated'**
  String get searchApiKeysPageBatchHint;

  /// No description provided for @searchApiKeysPageBatchResult.
  ///
  /// In en, this message translates to:
  /// **'Added {added}, skipped {skipped} duplicate(s)'**
  String searchApiKeysPageBatchResult(String added, String skipped);

  /// No description provided for @searchApiKeysPageAdd.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get searchApiKeysPageAdd;

  /// No description provided for @searchApiKeysPageEmpty.
  ///
  /// In en, this message translates to:
  /// **'No keys configured yet.'**
  String get searchApiKeysPageEmpty;

  /// No description provided for @searchServiceEditorMultiKeyCount.
  ///
  /// In en, this message translates to:
  /// **'{count} keys'**
  String searchServiceEditorMultiKeyCount(String count);

  /// No description provided for @searchServiceEditorUsageTitle.
  ///
  /// In en, this message translates to:
  /// **'Account usage'**
  String get searchServiceEditorUsageTitle;

  /// No description provided for @searchServiceEditorUsageNotQueried.
  ///
  /// In en, this message translates to:
  /// **'Usage has not been queried yet.'**
  String get searchServiceEditorUsageNotQueried;

  /// No description provided for @searchServiceEditorUsageQuery.
  ///
  /// In en, this message translates to:
  /// **'Check usage'**
  String get searchServiceEditorUsageQuery;

  /// No description provided for @searchServiceEditorUsageQuerying.
  ///
  /// In en, this message translates to:
  /// **'Checking…'**
  String get searchServiceEditorUsageQuerying;

  /// No description provided for @searchServiceEditorUsageRemaining.
  ///
  /// In en, this message translates to:
  /// **'{remaining} credits remaining'**
  String searchServiceEditorUsageRemaining(String remaining);

  /// No description provided for @searchServiceEditorUsageBalance.
  ///
  /// In en, this message translates to:
  /// **'Balance: {balance}'**
  String searchServiceEditorUsageBalance(String balance);

  /// No description provided for @searchServiceEditorUsageUsed.
  ///
  /// In en, this message translates to:
  /// **'{used} of {limit} credits used'**
  String searchServiceEditorUsageUsed(String used, String limit);

  /// No description provided for @searchServiceEditorUsageFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not query usage: {message}'**
  String searchServiceEditorUsageFailed(String message);

  /// No description provided for @searchServiceEditorTestTitle.
  ///
  /// In en, this message translates to:
  /// **'Test search'**
  String get searchServiceEditorTestTitle;

  /// No description provided for @searchServiceEditorTestQueryHint.
  ///
  /// In en, this message translates to:
  /// **'Enter a query'**
  String get searchServiceEditorTestQueryHint;

  /// No description provided for @searchServiceEditorTestRun.
  ///
  /// In en, this message translates to:
  /// **'Run test search'**
  String get searchServiceEditorTestRun;

  /// No description provided for @searchServiceEditorTestRunning.
  ///
  /// In en, this message translates to:
  /// **'Searching…'**
  String get searchServiceEditorTestRunning;

  /// No description provided for @searchServiceEditorTestNoResults.
  ///
  /// In en, this message translates to:
  /// **'The provider returned no results.'**
  String get searchServiceEditorTestNoResults;

  /// No description provided for @searchServiceEditorTestFailed.
  ///
  /// In en, this message translates to:
  /// **'Search failed: {message}'**
  String searchServiceEditorTestFailed(String message);

  /// No description provided for @searchServiceEditorResultOpenTooltip.
  ///
  /// In en, this message translates to:
  /// **'Open result'**
  String get searchServiceEditorResultOpenTooltip;

  /// No description provided for @searchServiceEditorDeleteTooltip.
  ///
  /// In en, this message translates to:
  /// **'Delete search service'**
  String get searchServiceEditorDeleteTooltip;

  /// No description provided for @searchServiceEditorDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete search service?'**
  String get searchServiceEditorDeleteTitle;

  /// No description provided for @searchServiceEditorDeleteMessage.
  ///
  /// In en, this message translates to:
  /// **'Delete {provider}? This cannot be undone.'**
  String searchServiceEditorDeleteMessage(String provider);

  /// No description provided for @searchServiceEditorDeleteConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get searchServiceEditorDeleteConfirm;

  /// No description provided for @searchServiceEditorDiscardTitle.
  ///
  /// In en, this message translates to:
  /// **'Discard changes?'**
  String get searchServiceEditorDiscardTitle;

  /// No description provided for @searchServiceEditorDiscardMessage.
  ///
  /// In en, this message translates to:
  /// **'Your unsaved search service settings will be lost.'**
  String get searchServiceEditorDiscardMessage;

  /// No description provided for @searchServiceEditorKeepEditing.
  ///
  /// In en, this message translates to:
  /// **'Keep editing'**
  String get searchServiceEditorKeepEditing;

  /// No description provided for @searchServiceEditorDiscard.
  ///
  /// In en, this message translates to:
  /// **'Discard'**
  String get searchServiceEditorDiscard;

  /// No description provided for @searchSettingsSheetTitle.
  ///
  /// In en, this message translates to:
  /// **'Search Settings'**
  String get searchSettingsSheetTitle;

  /// No description provided for @searchSettingsSheetBuiltinSearchTitle.
  ///
  /// In en, this message translates to:
  /// **'Built-in Search'**
  String get searchSettingsSheetBuiltinSearchTitle;

  /// No description provided for @searchSettingsSheetBuiltinSearchDescription.
  ///
  /// In en, this message translates to:
  /// **'Enable model\'s built-in search'**
  String get searchSettingsSheetBuiltinSearchDescription;

  /// No description provided for @searchSettingsSheetClaudeDynamicSearchTitle.
  ///
  /// In en, this message translates to:
  /// **'Dynamic filtering'**
  String get searchSettingsSheetClaudeDynamicSearchTitle;

  /// No description provided for @searchSettingsSheetClaudeDynamicSearchDescription.
  ///
  /// In en, this message translates to:
  /// **'Filter results to save tokens'**
  String get searchSettingsSheetClaudeDynamicSearchDescription;

  /// No description provided for @searchSettingsSheetWebSearchTitle.
  ///
  /// In en, this message translates to:
  /// **'Web Search'**
  String get searchSettingsSheetWebSearchTitle;

  /// No description provided for @searchSettingsSheetWebSearchDescription.
  ///
  /// In en, this message translates to:
  /// **'Enable web search in chat'**
  String get searchSettingsSheetWebSearchDescription;

  /// No description provided for @searchSettingsSheetOpenSearchServicesTooltip.
  ///
  /// In en, this message translates to:
  /// **'Open search services'**
  String get searchSettingsSheetOpenSearchServicesTooltip;

  /// No description provided for @searchSettingsSheetNoServicesMessage.
  ///
  /// In en, this message translates to:
  /// **'No services. Add from Search Services.'**
  String get searchSettingsSheetNoServicesMessage;

  /// No description provided for @aboutPageEasterEggMessage.
  ///
  /// In en, this message translates to:
  /// **'Thanks for exploring! \n (No egg yet)'**
  String get aboutPageEasterEggMessage;

  /// No description provided for @aboutPageEasterEggButton.
  ///
  /// In en, this message translates to:
  /// **'Nice!'**
  String get aboutPageEasterEggButton;

  /// No description provided for @aboutPageKelivoSearchUnlocked.
  ///
  /// In en, this message translates to:
  /// **'An unnamed door opened a crack. You might find it in Settings.'**
  String get aboutPageKelivoSearchUnlocked;

  /// No description provided for @aboutPageKelivoSearchAlreadyUnlocked.
  ///
  /// In en, this message translates to:
  /// **'You\'ve already been through this door.'**
  String get aboutPageKelivoSearchAlreadyUnlocked;

  /// No description provided for @aboutPageAppName.
  ///
  /// In en, this message translates to:
  /// **'Kelivo'**
  String get aboutPageAppName;

  /// No description provided for @aboutPageAppDescription.
  ///
  /// In en, this message translates to:
  /// **'Open-source AI Assistant'**
  String get aboutPageAppDescription;

  /// No description provided for @aboutPageNoQQGroup.
  ///
  /// In en, this message translates to:
  /// **'No QQ group yet'**
  String get aboutPageNoQQGroup;

  /// No description provided for @aboutPageVersion.
  ///
  /// In en, this message translates to:
  /// **'Version'**
  String get aboutPageVersion;

  /// No description provided for @aboutPageVersionDetail.
  ///
  /// In en, this message translates to:
  /// **'{version} / {buildNumber}'**
  String aboutPageVersionDetail(String version, String buildNumber);

  /// No description provided for @aboutPageSystem.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get aboutPageSystem;

  /// No description provided for @aboutPageLoadingPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'...'**
  String get aboutPageLoadingPlaceholder;

  /// No description provided for @aboutPageUnknownPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'-'**
  String get aboutPageUnknownPlaceholder;

  /// No description provided for @aboutPagePlatformMacos.
  ///
  /// In en, this message translates to:
  /// **'macOS'**
  String get aboutPagePlatformMacos;

  /// No description provided for @aboutPagePlatformWindows.
  ///
  /// In en, this message translates to:
  /// **'Windows'**
  String get aboutPagePlatformWindows;

  /// No description provided for @aboutPagePlatformLinux.
  ///
  /// In en, this message translates to:
  /// **'Linux'**
  String get aboutPagePlatformLinux;

  /// No description provided for @aboutPagePlatformAndroid.
  ///
  /// In en, this message translates to:
  /// **'Android'**
  String get aboutPagePlatformAndroid;

  /// No description provided for @aboutPagePlatformIos.
  ///
  /// In en, this message translates to:
  /// **'iOS'**
  String get aboutPagePlatformIos;

  /// No description provided for @aboutPagePlatformOther.
  ///
  /// In en, this message translates to:
  /// **'Other ({os})'**
  String aboutPagePlatformOther(String os);

  /// No description provided for @aboutPageWebsite.
  ///
  /// In en, this message translates to:
  /// **'Website'**
  String get aboutPageWebsite;

  /// No description provided for @aboutPageGithub.
  ///
  /// In en, this message translates to:
  /// **'GitHub'**
  String get aboutPageGithub;

  /// No description provided for @aboutPageLicense.
  ///
  /// In en, this message translates to:
  /// **'License'**
  String get aboutPageLicense;

  /// No description provided for @aboutPageJoinQQGroup.
  ///
  /// In en, this message translates to:
  /// **'Join our QQ Group'**
  String get aboutPageJoinQQGroup;

  /// No description provided for @aboutPageQQGroupOne.
  ///
  /// In en, this message translates to:
  /// **'Kelivo Group 1'**
  String get aboutPageQQGroupOne;

  /// No description provided for @aboutPageQQGroupTwo.
  ///
  /// In en, this message translates to:
  /// **'Kelivo Group 2'**
  String get aboutPageQQGroupTwo;

  /// No description provided for @aboutPageQQGroupThree.
  ///
  /// In en, this message translates to:
  /// **'Kelivo Group 3'**
  String get aboutPageQQGroupThree;

  /// No description provided for @aboutPageJoinDiscord.
  ///
  /// In en, this message translates to:
  /// **'Join us on Discord'**
  String get aboutPageJoinDiscord;

  /// No description provided for @displaySettingsPageShowUserAvatarTitle.
  ///
  /// In en, this message translates to:
  /// **'Show User Avatar'**
  String get displaySettingsPageShowUserAvatarTitle;

  /// No description provided for @displaySettingsPageShowUserAvatarSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Display user avatar in chat messages'**
  String get displaySettingsPageShowUserAvatarSubtitle;

  /// No description provided for @displaySettingsPageShowUserNameTimestampTitle.
  ///
  /// In en, this message translates to:
  /// **'Show User Name & Timestamp'**
  String get displaySettingsPageShowUserNameTimestampTitle;

  /// No description provided for @displaySettingsPageShowUserNameTimestampSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Show user name and the timestamp below it in chat messages'**
  String get displaySettingsPageShowUserNameTimestampSubtitle;

  /// No description provided for @displaySettingsPageShowUserNameTitle.
  ///
  /// In en, this message translates to:
  /// **'Show User Name'**
  String get displaySettingsPageShowUserNameTitle;

  /// No description provided for @displaySettingsPageShowUserTimestampTitle.
  ///
  /// In en, this message translates to:
  /// **'Show User Timestamp'**
  String get displaySettingsPageShowUserTimestampTitle;

  /// No description provided for @displaySettingsPageShowUserMessageActionsTitle.
  ///
  /// In en, this message translates to:
  /// **'Show User Message Actions'**
  String get displaySettingsPageShowUserMessageActionsTitle;

  /// No description provided for @displaySettingsPageShowUserMessageActionsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Display copy, resend, and more buttons below your messages'**
  String get displaySettingsPageShowUserMessageActionsSubtitle;

  /// No description provided for @displaySettingsPageShowModelNameTimestampTitle.
  ///
  /// In en, this message translates to:
  /// **'Show Model Name & Timestamp'**
  String get displaySettingsPageShowModelNameTimestampTitle;

  /// No description provided for @displaySettingsPageShowModelNameTimestampSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Show model name and the timestamp below it in chat messages'**
  String get displaySettingsPageShowModelNameTimestampSubtitle;

  /// No description provided for @displaySettingsPageShowModelNameTitle.
  ///
  /// In en, this message translates to:
  /// **'Show Model Name'**
  String get displaySettingsPageShowModelNameTitle;

  /// No description provided for @displaySettingsPageShowModelTimestampTitle.
  ///
  /// In en, this message translates to:
  /// **'Show Model Timestamp'**
  String get displaySettingsPageShowModelTimestampTitle;

  /// No description provided for @displaySettingsPageShowProviderInChatMessageTitle.
  ///
  /// In en, this message translates to:
  /// **'Show Provider After Model Name'**
  String get displaySettingsPageShowProviderInChatMessageTitle;

  /// No description provided for @displaySettingsPageShowProviderInChatMessageSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Display provider name after the model ID in chat messages (e.g. model | provider)'**
  String get displaySettingsPageShowProviderInChatMessageSubtitle;

  /// No description provided for @displaySettingsPageChatModelIconTitle.
  ///
  /// In en, this message translates to:
  /// **'Chat Model Icon'**
  String get displaySettingsPageChatModelIconTitle;

  /// No description provided for @displaySettingsPageChatModelIconSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Show model icon in chat messages'**
  String get displaySettingsPageChatModelIconSubtitle;

  /// No description provided for @displaySettingsPageShowTokenStatsTitle.
  ///
  /// In en, this message translates to:
  /// **'Show Token & Context Stats'**
  String get displaySettingsPageShowTokenStatsTitle;

  /// No description provided for @displaySettingsPageShowTokenStatsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Show token usage and message count'**
  String get displaySettingsPageShowTokenStatsSubtitle;

  /// No description provided for @displaySettingsPageShowThinkingCardsTitle.
  ///
  /// In en, this message translates to:
  /// **'Show Thinking Cards'**
  String get displaySettingsPageShowThinkingCardsTitle;

  /// No description provided for @displaySettingsPageShowThinkingCardsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'When off, thinking-process cards are hidden in chat.'**
  String get displaySettingsPageShowThinkingCardsSubtitle;

  /// No description provided for @displaySettingsPageShowToolCardsTitle.
  ///
  /// In en, this message translates to:
  /// **'Show Tool Cards'**
  String get displaySettingsPageShowToolCardsTitle;

  /// No description provided for @displaySettingsPageShowToolCardsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'When off, tool-use cards are hidden in chat.'**
  String get displaySettingsPageShowToolCardsSubtitle;

  /// No description provided for @displaySettingsPageAutoCollapseThinkingTitle.
  ///
  /// In en, this message translates to:
  /// **'Auto-collapse Thinking'**
  String get displaySettingsPageAutoCollapseThinkingTitle;

  /// No description provided for @displaySettingsPageAutoCollapseThinkingSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Collapse reasoning after finish'**
  String get displaySettingsPageAutoCollapseThinkingSubtitle;

  /// No description provided for @displaySettingsPageCollapseThinkingStepsTitle.
  ///
  /// In en, this message translates to:
  /// **'Collapse Thinking Steps'**
  String get displaySettingsPageCollapseThinkingStepsTitle;

  /// No description provided for @displaySettingsPageCollapseThinkingStepsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Show only the latest steps until expanded'**
  String get displaySettingsPageCollapseThinkingStepsSubtitle;

  /// No description provided for @displaySettingsPageShowToolResultSummaryTitle.
  ///
  /// In en, this message translates to:
  /// **'Show Tool Result Summary'**
  String get displaySettingsPageShowToolResultSummaryTitle;

  /// No description provided for @displaySettingsPageInsertSuggestionOnlyTitle.
  ///
  /// In en, this message translates to:
  /// **'Insert suggestions without sending'**
  String get displaySettingsPageInsertSuggestionOnlyTitle;

  /// No description provided for @displaySettingsPageShowToolResultSummarySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Display the summary text below tool steps'**
  String get displaySettingsPageShowToolResultSummarySubtitle;

  /// No description provided for @displaySettingsPageHideToolResultImagesTitle.
  ///
  /// In en, this message translates to:
  /// **'Hide images in tool results'**
  String get displaySettingsPageHideToolResultImagesTitle;

  /// No description provided for @displaySettingsPageRegenerateDeleteTrailingMessagesTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete messages below when regenerating'**
  String get displaySettingsPageRegenerateDeleteTrailingMessagesTitle;

  /// No description provided for @displaySettingsPageShowRegenerateConfirmDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Confirm before regenerating'**
  String get displaySettingsPageShowRegenerateConfirmDialogTitle;

  /// No description provided for @displaySettingsPageForkKeepMessageVersionsTitle.
  ///
  /// In en, this message translates to:
  /// **'Keep Message Versions When Forking'**
  String get displaySettingsPageForkKeepMessageVersionsTitle;

  /// No description provided for @displaySettingsPageEditAssistantKeepThinkingToolCardsTitle.
  ///
  /// In en, this message translates to:
  /// **'Keep thinking and tool cards when editing assistant'**
  String get displaySettingsPageEditAssistantKeepThinkingToolCardsTitle;

  /// No description provided for @displaySettingsPageEditAssistantKeepThinkingToolCardsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'When off, the edited version keeps only the assistant text. Switching back still shows previous thinking and tool cards.'**
  String get displaySettingsPageEditAssistantKeepThinkingToolCardsSubtitle;

  /// No description provided for @chainOfThoughtExpandSteps.
  ///
  /// In en, this message translates to:
  /// **'Show {count} more steps'**
  String chainOfThoughtExpandSteps(Object count);

  /// No description provided for @chainOfThoughtCollapse.
  ///
  /// In en, this message translates to:
  /// **'Collapse'**
  String get chainOfThoughtCollapse;

  /// No description provided for @displaySettingsPageShowChatListDateTitle.
  ///
  /// In en, this message translates to:
  /// **'Show Chat List Dates'**
  String get displaySettingsPageShowChatListDateTitle;

  /// No description provided for @displaySettingsPageShowChatListDateSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Display date group labels in the conversation list'**
  String get displaySettingsPageShowChatListDateSubtitle;

  /// No description provided for @displaySettingsPageEnableImageCropperTitle.
  ///
  /// In en, this message translates to:
  /// **'Enable Image Cropping'**
  String get displaySettingsPageEnableImageCropperTitle;

  /// No description provided for @displaySettingsPageEnableImageCropperSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Crop images after selecting from gallery or camera'**
  String get displaySettingsPageEnableImageCropperSubtitle;

  /// No description provided for @displaySettingsPageKeepSidebarOpenOnAssistantTapTitle.
  ///
  /// In en, this message translates to:
  /// **'Keep sidebar open when selecting assistant'**
  String get displaySettingsPageKeepSidebarOpenOnAssistantTapTitle;

  /// No description provided for @displaySettingsPageKeepSidebarOpenOnTopicTapTitle.
  ///
  /// In en, this message translates to:
  /// **'Keep sidebar open when selecting topic'**
  String get displaySettingsPageKeepSidebarOpenOnTopicTapTitle;

  /// No description provided for @displaySettingsPageKeepAssistantListExpandedOnSidebarCloseTitle.
  ///
  /// In en, this message translates to:
  /// **'Don\'t collapse assistant list when closing sidebar'**
  String get displaySettingsPageKeepAssistantListExpandedOnSidebarCloseTitle;

  /// No description provided for @displaySettingsPageShowUpdatesTitle.
  ///
  /// In en, this message translates to:
  /// **'Show Updates'**
  String get displaySettingsPageShowUpdatesTitle;

  /// No description provided for @displaySettingsPageShowUpdatesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Show app update notifications'**
  String get displaySettingsPageShowUpdatesSubtitle;

  /// No description provided for @displaySettingsPageKeepScreenOnDuringGenerationTitle.
  ///
  /// In en, this message translates to:
  /// **'Keep Screen On While Generating'**
  String get displaySettingsPageKeepScreenOnDuringGenerationTitle;

  /// No description provided for @displaySettingsPageKeepScreenOnDuringGenerationSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Prevents the lock screen from interrupting generation. Increases battery use.'**
  String get displaySettingsPageKeepScreenOnDuringGenerationSubtitle;

  /// No description provided for @displaySettingsPageMessageNavButtonsTitle.
  ///
  /// In en, this message translates to:
  /// **'Message Navigation Buttons'**
  String get displaySettingsPageMessageNavButtonsTitle;

  /// No description provided for @displaySettingsPageMessageNavButtonsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Choose when quick jump buttons appear'**
  String get displaySettingsPageMessageNavButtonsSubtitle;

  /// No description provided for @displaySettingsPageMessageNavButtonsModeAlways.
  ///
  /// In en, this message translates to:
  /// **'Always show'**
  String get displaySettingsPageMessageNavButtonsModeAlways;

  /// No description provided for @displaySettingsPageMessageNavButtonsModeScroll.
  ///
  /// In en, this message translates to:
  /// **'Show while scrolling'**
  String get displaySettingsPageMessageNavButtonsModeScroll;

  /// No description provided for @displaySettingsPageMessageNavButtonsModeHover.
  ///
  /// In en, this message translates to:
  /// **'Show on mouse hover'**
  String get displaySettingsPageMessageNavButtonsModeHover;

  /// No description provided for @displaySettingsPageMessageNavButtonsModeScrollAndHover.
  ///
  /// In en, this message translates to:
  /// **'Show while scrolling or hovering'**
  String get displaySettingsPageMessageNavButtonsModeScrollAndHover;

  /// No description provided for @displaySettingsPageMessageNavButtonsModeNever.
  ///
  /// In en, this message translates to:
  /// **'Never show'**
  String get displaySettingsPageMessageNavButtonsModeNever;

  /// No description provided for @displaySettingsPageUseNewAssistantAvatarUxTitle.
  ///
  /// In en, this message translates to:
  /// **'Show assistant avatar in chat title bar'**
  String get displaySettingsPageUseNewAssistantAvatarUxTitle;

  /// No description provided for @displaySettingsPageHapticsOnSidebarTitle.
  ///
  /// In en, this message translates to:
  /// **'Haptics on Sidebar'**
  String get displaySettingsPageHapticsOnSidebarTitle;

  /// No description provided for @displaySettingsPageHapticsOnSidebarSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Enable haptic feedback when opening/closing sidebar'**
  String get displaySettingsPageHapticsOnSidebarSubtitle;

  /// No description provided for @displaySettingsPageHapticsGlobalTitle.
  ///
  /// In en, this message translates to:
  /// **'Global Haptics'**
  String get displaySettingsPageHapticsGlobalTitle;

  /// No description provided for @displaySettingsPageHapticsIosSwitchTitle.
  ///
  /// In en, this message translates to:
  /// **'Haptics on Switch'**
  String get displaySettingsPageHapticsIosSwitchTitle;

  /// No description provided for @displaySettingsPageHapticsOnListItemTapTitle.
  ///
  /// In en, this message translates to:
  /// **'Haptics on List Items'**
  String get displaySettingsPageHapticsOnListItemTapTitle;

  /// No description provided for @displaySettingsPageHapticsOnCardTapTitle.
  ///
  /// In en, this message translates to:
  /// **'Haptics on Cards'**
  String get displaySettingsPageHapticsOnCardTapTitle;

  /// No description provided for @displaySettingsPageHapticsOnGenerateTitle.
  ///
  /// In en, this message translates to:
  /// **'Haptics on Generate'**
  String get displaySettingsPageHapticsOnGenerateTitle;

  /// No description provided for @displaySettingsPageHapticsOnGenerateSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Enable haptic feedback during generation'**
  String get displaySettingsPageHapticsOnGenerateSubtitle;

  /// No description provided for @displaySettingsPageNewChatAfterDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'New chat after deleting topic'**
  String get displaySettingsPageNewChatAfterDeleteTitle;

  /// No description provided for @displaySettingsPageNewChatOnAssistantSwitchTitle.
  ///
  /// In en, this message translates to:
  /// **'New chat when switching assistants'**
  String get displaySettingsPageNewChatOnAssistantSwitchTitle;

  /// No description provided for @displaySettingsPageNewChatOnLaunchTitle.
  ///
  /// In en, this message translates to:
  /// **'New Chat on Launch'**
  String get displaySettingsPageNewChatOnLaunchTitle;

  /// No description provided for @displaySettingsPageEnterToSendTitle.
  ///
  /// In en, this message translates to:
  /// **'Enter Key to Send'**
  String get displaySettingsPageEnterToSendTitle;

  /// No description provided for @displaySettingsPageLongPasteAsFileTitle.
  ///
  /// In en, this message translates to:
  /// **'Paste long text as file'**
  String get displaySettingsPageLongPasteAsFileTitle;

  /// No description provided for @displaySettingsPageLongPasteAsFileThresholdTitle.
  ///
  /// In en, this message translates to:
  /// **'Conversion threshold'**
  String get displaySettingsPageLongPasteAsFileThresholdTitle;

  /// No description provided for @displaySettingsPageLongPasteAsFileThresholdUnit.
  ///
  /// In en, this message translates to:
  /// **'characters'**
  String get displaySettingsPageLongPasteAsFileThresholdUnit;

  /// No description provided for @displaySettingsPageSendShortcutTitle.
  ///
  /// In en, this message translates to:
  /// **'Send Shortcut'**
  String get displaySettingsPageSendShortcutTitle;

  /// No description provided for @displaySettingsPageSendShortcutEnter.
  ///
  /// In en, this message translates to:
  /// **'Enter'**
  String get displaySettingsPageSendShortcutEnter;

  /// No description provided for @displaySettingsPageSendShortcutCtrlEnter.
  ///
  /// In en, this message translates to:
  /// **'Ctrl/Cmd + Enter'**
  String get displaySettingsPageSendShortcutCtrlEnter;

  /// No description provided for @displaySettingsPageAutoSwitchTopicsTitle.
  ///
  /// In en, this message translates to:
  /// **'Auto switch to Topics'**
  String get displaySettingsPageAutoSwitchTopicsTitle;

  /// No description provided for @desktopDisplaySettingsTopicPositionTitle.
  ///
  /// In en, this message translates to:
  /// **'Topic position'**
  String get desktopDisplaySettingsTopicPositionTitle;

  /// No description provided for @desktopDisplaySettingsTopicPositionLeft.
  ///
  /// In en, this message translates to:
  /// **'Left'**
  String get desktopDisplaySettingsTopicPositionLeft;

  /// No description provided for @desktopDisplaySettingsTopicPositionRight.
  ///
  /// In en, this message translates to:
  /// **'Right'**
  String get desktopDisplaySettingsTopicPositionRight;

  /// No description provided for @displaySettingsPageNewChatOnLaunchSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Automatically create a new chat on launch'**
  String get displaySettingsPageNewChatOnLaunchSubtitle;

  /// No description provided for @displaySettingsPageChatFontSizeTitle.
  ///
  /// In en, this message translates to:
  /// **'Chat Font Size'**
  String get displaySettingsPageChatFontSizeTitle;

  /// No description provided for @displaySettingsPageUiFontSizeTitle.
  ///
  /// In en, this message translates to:
  /// **'UI Font Size'**
  String get displaySettingsPageUiFontSizeTitle;

  /// No description provided for @displaySettingsPageInputFontSizeTitle.
  ///
  /// In en, this message translates to:
  /// **'Input Box Font Size'**
  String get displaySettingsPageInputFontSizeTitle;

  /// No description provided for @displaySettingsPageAutoScrollEnableTitle.
  ///
  /// In en, this message translates to:
  /// **'Auto-scroll to bottom'**
  String get displaySettingsPageAutoScrollEnableTitle;

  /// No description provided for @displaySettingsPageAutoScrollIdleTitle.
  ///
  /// In en, this message translates to:
  /// **'Auto-Scroll Back Delay'**
  String get displaySettingsPageAutoScrollIdleTitle;

  /// No description provided for @displaySettingsPageAutoScrollIdleSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Wait time after user scroll before jumping to bottom'**
  String get displaySettingsPageAutoScrollIdleSubtitle;

  /// No description provided for @displaySettingsPageAutoScrollDisabledLabel.
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get displaySettingsPageAutoScrollDisabledLabel;

  /// No description provided for @displaySettingsPageChatFontSampleText.
  ///
  /// In en, this message translates to:
  /// **'This is a sample chat text'**
  String get displaySettingsPageChatFontSampleText;

  /// No description provided for @displaySettingsPageChatBackgroundMaskTitle.
  ///
  /// In en, this message translates to:
  /// **'Chat Background Overlay Opacity'**
  String get displaySettingsPageChatBackgroundMaskTitle;

  /// No description provided for @displaySettingsPageChatInputBackgroundOpacityTitle.
  ///
  /// In en, this message translates to:
  /// **'Input Box Background Opacity'**
  String get displaySettingsPageChatInputBackgroundOpacityTitle;

  /// No description provided for @displaySettingsPageThemeSettingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Theme Settings'**
  String get displaySettingsPageThemeSettingsTitle;

  /// No description provided for @displaySettingsPageThemeColorTitle.
  ///
  /// In en, this message translates to:
  /// **'Theme Color'**
  String get displaySettingsPageThemeColorTitle;

  /// No description provided for @desktopSettingsFontsTitle.
  ///
  /// In en, this message translates to:
  /// **'Fonts'**
  String get desktopSettingsFontsTitle;

  /// No description provided for @displaySettingsPageTrayTitle.
  ///
  /// In en, this message translates to:
  /// **'System Tray'**
  String get displaySettingsPageTrayTitle;

  /// No description provided for @displaySettingsPageTrayShowTrayTitle.
  ///
  /// In en, this message translates to:
  /// **'Show tray icon'**
  String get displaySettingsPageTrayShowTrayTitle;

  /// No description provided for @displaySettingsPageTrayMinimizeOnCloseTitle.
  ///
  /// In en, this message translates to:
  /// **'Minimize to tray on close'**
  String get displaySettingsPageTrayMinimizeOnCloseTitle;

  /// No description provided for @desktopFontAppLabel.
  ///
  /// In en, this message translates to:
  /// **'App Font'**
  String get desktopFontAppLabel;

  /// No description provided for @desktopFontCodeLabel.
  ///
  /// In en, this message translates to:
  /// **'Code Font'**
  String get desktopFontCodeLabel;

  /// No description provided for @desktopFontFamilySystemDefault.
  ///
  /// In en, this message translates to:
  /// **'System Default'**
  String get desktopFontFamilySystemDefault;

  /// No description provided for @desktopFontFamilyMonospaceDefault.
  ///
  /// In en, this message translates to:
  /// **'Monospace'**
  String get desktopFontFamilyMonospaceDefault;

  /// No description provided for @desktopFontFilterHint.
  ///
  /// In en, this message translates to:
  /// **'Filter fonts...'**
  String get desktopFontFilterHint;

  /// No description provided for @displaySettingsPageAppFontTitle.
  ///
  /// In en, this message translates to:
  /// **'App Font'**
  String get displaySettingsPageAppFontTitle;

  /// No description provided for @displaySettingsPageCodeFontTitle.
  ///
  /// In en, this message translates to:
  /// **'Code Font'**
  String get displaySettingsPageCodeFontTitle;

  /// No description provided for @fontPickerChooseLocalFile.
  ///
  /// In en, this message translates to:
  /// **'Choose Local File'**
  String get fontPickerChooseLocalFile;

  /// No description provided for @desktopFontLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading fonts…'**
  String get desktopFontLoading;

  /// No description provided for @displaySettingsPageFontLocalFileLabel.
  ///
  /// In en, this message translates to:
  /// **'Local file'**
  String get displaySettingsPageFontLocalFileLabel;

  /// No description provided for @displaySettingsPageFontResetLabel.
  ///
  /// In en, this message translates to:
  /// **'Reset font settings'**
  String get displaySettingsPageFontResetLabel;

  /// No description provided for @displaySettingsPageOtherSettingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Other Settings'**
  String get displaySettingsPageOtherSettingsTitle;

  /// No description provided for @themeSettingsPageDynamicColorSection.
  ///
  /// In en, this message translates to:
  /// **'Dynamic Color'**
  String get themeSettingsPageDynamicColorSection;

  /// No description provided for @themeSettingsPageUseDynamicColorTitle.
  ///
  /// In en, this message translates to:
  /// **'System Dynamic Colors'**
  String get themeSettingsPageUseDynamicColorTitle;

  /// No description provided for @themeSettingsPageUseDynamicColorSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Match system palette (Android 12+)'**
  String get themeSettingsPageUseDynamicColorSubtitle;

  /// No description provided for @themeSettingsPageUsePureBackgroundTitle.
  ///
  /// In en, this message translates to:
  /// **'Pure Background'**
  String get themeSettingsPageUsePureBackgroundTitle;

  /// No description provided for @themeSettingsPageUsePureBackgroundSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Bubbles and accents follow theme.'**
  String get themeSettingsPageUsePureBackgroundSubtitle;

  /// No description provided for @themeAdvancedSettingsPageTitle.
  ///
  /// In en, this message translates to:
  /// **'Theme Advanced'**
  String get themeAdvancedSettingsPageTitle;

  /// No description provided for @themeAdvancedSettingsPageUseLayeredSurfacesTitle.
  ///
  /// In en, this message translates to:
  /// **'Layered surfaces (experimental)'**
  String get themeAdvancedSettingsPageUseLayeredSurfacesTitle;

  /// No description provided for @themeAdvancedSettingsPageUseLayeredSurfacesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Darker page, brighter cards; both keep theme hue. Turn off to restore the previous look.'**
  String get themeAdvancedSettingsPageUseLayeredSurfacesSubtitle;

  /// No description provided for @themeAdvancedSettingsPageUseLayeredSheetTilesTitle.
  ///
  /// In en, this message translates to:
  /// **'Layered sheet tiles'**
  String get themeAdvancedSettingsPageUseLayeredSheetTilesTitle;

  /// No description provided for @themeAdvancedSettingsPageUseLayeredSheetTilesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'By default, tiles match the sheet background.'**
  String get themeAdvancedSettingsPageUseLayeredSheetTilesSubtitle;

  /// No description provided for @themeSettingsPageColorPalettesSection.
  ///
  /// In en, this message translates to:
  /// **'Color Palettes'**
  String get themeSettingsPageColorPalettesSection;

  /// No description provided for @themeSettingsPageCustomPaletteName.
  ///
  /// In en, this message translates to:
  /// **'Custom'**
  String get themeSettingsPageCustomPaletteName;

  /// No description provided for @themeSettingsPageCustomColorReset.
  ///
  /// In en, this message translates to:
  /// **'Reset'**
  String get themeSettingsPageCustomColorReset;

  /// No description provided for @themeSettingsPageCustomThemesSection.
  ///
  /// In en, this message translates to:
  /// **'Custom Themes'**
  String get themeSettingsPageCustomThemesSection;

  /// No description provided for @customThemeNewTheme.
  ///
  /// In en, this message translates to:
  /// **'New Theme'**
  String get customThemeNewTheme;

  /// No description provided for @customThemeEditTheme.
  ///
  /// In en, this message translates to:
  /// **'Edit Theme'**
  String get customThemeEditTheme;

  /// No description provided for @customThemeImportTheme.
  ///
  /// In en, this message translates to:
  /// **'Import Theme'**
  String get customThemeImportTheme;

  /// No description provided for @customThemeNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Theme name'**
  String get customThemeNameLabel;

  /// No description provided for @customThemePrimaryColor.
  ///
  /// In en, this message translates to:
  /// **'Primary'**
  String get customThemePrimaryColor;

  /// No description provided for @customThemeSecondaryColor.
  ///
  /// In en, this message translates to:
  /// **'Secondary'**
  String get customThemeSecondaryColor;

  /// No description provided for @customThemeTertiaryColor.
  ///
  /// In en, this message translates to:
  /// **'Tertiary'**
  String get customThemeTertiaryColor;

  /// No description provided for @customThemeColorAuto.
  ///
  /// In en, this message translates to:
  /// **'Auto'**
  String get customThemeColorAuto;

  /// No description provided for @customThemeSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get customThemeSave;

  /// No description provided for @customThemeCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get customThemeCancel;

  /// No description provided for @customThemeDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get customThemeDelete;

  /// No description provided for @customThemeDeleteConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete this theme?'**
  String get customThemeDeleteConfirm;

  /// No description provided for @customThemeCopied.
  ///
  /// In en, this message translates to:
  /// **'Theme JSON copied to clipboard'**
  String get customThemeCopied;

  /// No description provided for @customThemeCopyAction.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get customThemeCopyAction;

  /// No description provided for @customThemeImportHint.
  ///
  /// In en, this message translates to:
  /// **'Paste the theme JSON here'**
  String get customThemeImportHint;

  /// No description provided for @customThemeImportInvalid.
  ///
  /// In en, this message translates to:
  /// **'Invalid theme JSON'**
  String get customThemeImportInvalid;

  /// No description provided for @customThemeHexLabel.
  ///
  /// In en, this message translates to:
  /// **'Hex'**
  String get customThemeHexLabel;

  /// No description provided for @ttsServicesPageBackButton.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get ttsServicesPageBackButton;

  /// No description provided for @ttsServicesPageTitle.
  ///
  /// In en, this message translates to:
  /// **'Voice Services'**
  String get ttsServicesPageTitle;

  /// No description provided for @ttsServicesSectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Text-to-Speech'**
  String get ttsServicesSectionTitle;

  /// No description provided for @ttsServicesPageSettingsTooltip.
  ///
  /// In en, this message translates to:
  /// **'TTS settings'**
  String get ttsServicesPageSettingsTooltip;

  /// No description provided for @ttsServicesPageAddTooltip.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get ttsServicesPageAddTooltip;

  /// No description provided for @asrServicesSectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Speech Recognition'**
  String get asrServicesSectionTitle;

  /// No description provided for @asrServicesSectionDescription.
  ///
  /// In en, this message translates to:
  /// **'Turn speech into text with an on-device, system, or cloud service.'**
  String get asrServicesSectionDescription;

  /// No description provided for @asrServicesAddTooltip.
  ///
  /// In en, this message translates to:
  /// **'Add speech recognition service'**
  String get asrServicesAddTooltip;

  /// No description provided for @asrServicesEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No speech recognition service'**
  String get asrServicesEmptyTitle;

  /// No description provided for @asrServicesEmptySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Add one to show the microphone in the chat input.'**
  String get asrServicesEmptySubtitle;

  /// No description provided for @asrServicesOnDeviceGroup.
  ///
  /// In en, this message translates to:
  /// **'On-device'**
  String get asrServicesOnDeviceGroup;

  /// No description provided for @asrServicesCloudGroup.
  ///
  /// In en, this message translates to:
  /// **'Cloud'**
  String get asrServicesCloudGroup;

  /// No description provided for @asrServicesSystemTitle.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get asrServicesSystemTitle;

  /// No description provided for @asrServicesSystemSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Uses the device\'s built-in recognizer'**
  String get asrServicesSystemSubtitle;

  /// No description provided for @asrServicesLocalTitle.
  ///
  /// In en, this message translates to:
  /// **'Offline Model'**
  String get asrServicesLocalTitle;

  /// No description provided for @asrServicesLocalSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Runs offline on this device after download'**
  String get asrServicesLocalSubtitle;

  /// No description provided for @asrServicesOpenAiTitle.
  ///
  /// In en, this message translates to:
  /// **'OpenAI Realtime'**
  String get asrServicesOpenAiTitle;

  /// No description provided for @asrServicesOpenAiSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Low-latency streaming transcription'**
  String get asrServicesOpenAiSubtitle;

  /// No description provided for @asrServicesDashScopeTitle.
  ///
  /// In en, this message translates to:
  /// **'DashScope'**
  String get asrServicesDashScopeTitle;

  /// No description provided for @asrServicesDashScopeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Qwen real-time transcription'**
  String get asrServicesDashScopeSubtitle;

  /// No description provided for @asrServicesVolcengineTitle.
  ///
  /// In en, this message translates to:
  /// **'Volcengine'**
  String get asrServicesVolcengineTitle;

  /// No description provided for @asrServicesVolcengineSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Doubao streaming transcription'**
  String get asrServicesVolcengineSubtitle;

  /// No description provided for @asrServicesMimoTitle.
  ///
  /// In en, this message translates to:
  /// **'MiMo'**
  String get asrServicesMimoTitle;

  /// No description provided for @asrServicesMimoSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Segmented cloud transcription'**
  String get asrServicesMimoSubtitle;

  /// No description provided for @asrServicesStepTitle.
  ///
  /// In en, this message translates to:
  /// **'Step'**
  String get asrServicesStepTitle;

  /// No description provided for @asrServicesStepSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Step Audio segmented transcription'**
  String get asrServicesStepSubtitle;

  /// No description provided for @asrServicesAddTitle.
  ///
  /// In en, this message translates to:
  /// **'Add Speech Recognition'**
  String get asrServicesAddTitle;

  /// No description provided for @asrServicesEditTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit Speech Recognition'**
  String get asrServicesEditTitle;

  /// No description provided for @asrServicesSelectedLabel.
  ///
  /// In en, this message translates to:
  /// **'Selected'**
  String get asrServicesSelectedLabel;

  /// No description provided for @asrServicesUnavailableLabel.
  ///
  /// In en, this message translates to:
  /// **'Unavailable'**
  String get asrServicesUnavailableLabel;

  /// No description provided for @asrServicesEditAction.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get asrServicesEditAction;

  /// No description provided for @asrServicesDeleteAction.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get asrServicesDeleteAction;

  /// No description provided for @asrServicesCancelAction.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get asrServicesCancelAction;

  /// No description provided for @asrServicesAddAction.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get asrServicesAddAction;

  /// No description provided for @asrServicesSaveAction.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get asrServicesSaveAction;

  /// No description provided for @asrServicesNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get asrServicesNameLabel;

  /// No description provided for @asrServicesApiKeyLabel.
  ///
  /// In en, this message translates to:
  /// **'API Key'**
  String get asrServicesApiKeyLabel;

  /// No description provided for @asrServicesEndpointLabel.
  ///
  /// In en, this message translates to:
  /// **'Endpoint'**
  String get asrServicesEndpointLabel;

  /// No description provided for @asrServicesModelLabel.
  ///
  /// In en, this message translates to:
  /// **'Model'**
  String get asrServicesModelLabel;

  /// No description provided for @asrServicesResourceIdLabel.
  ///
  /// In en, this message translates to:
  /// **'Resource ID'**
  String get asrServicesResourceIdLabel;

  /// No description provided for @asrServicesLanguageLabel.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get asrServicesLanguageLabel;

  /// No description provided for @asrServicesAutomaticLabel.
  ///
  /// In en, this message translates to:
  /// **'Automatic'**
  String get asrServicesAutomaticLabel;

  /// No description provided for @asrServicesApiKeyRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter an API key to use this service.'**
  String get asrServicesApiKeyRequired;

  /// No description provided for @asrServicesChooseModelTitle.
  ///
  /// In en, this message translates to:
  /// **'Model'**
  String get asrServicesChooseModelTitle;

  /// No description provided for @asrServicesModelDownloadAction.
  ///
  /// In en, this message translates to:
  /// **'Download'**
  String get asrServicesModelDownloadAction;

  /// No description provided for @asrServicesModelUseAction.
  ///
  /// In en, this message translates to:
  /// **'Use model'**
  String get asrServicesModelUseAction;

  /// No description provided for @asrServicesModelDeleteAction.
  ///
  /// In en, this message translates to:
  /// **'Remove download'**
  String get asrServicesModelDeleteAction;

  /// No description provided for @asrServicesModelDownloadedLabel.
  ///
  /// In en, this message translates to:
  /// **'Downloaded'**
  String get asrServicesModelDownloadedLabel;

  /// No description provided for @asrServicesModelDownloadingLabel.
  ///
  /// In en, this message translates to:
  /// **'Downloading…'**
  String get asrServicesModelDownloadingLabel;

  /// No description provided for @asrServicesModelNotDownloadedLabel.
  ///
  /// In en, this message translates to:
  /// **'Not downloaded'**
  String get asrServicesModelNotDownloadedLabel;

  /// No description provided for @asrServicesDownloadFailed.
  ///
  /// In en, this message translates to:
  /// **'Model download failed: {error}'**
  String asrServicesDownloadFailed(String error);

  /// No description provided for @asrServicesSystemChecking.
  ///
  /// In en, this message translates to:
  /// **'Checking…'**
  String get asrServicesSystemChecking;

  /// No description provided for @asrServicesSystemAvailable.
  ///
  /// In en, this message translates to:
  /// **'Available'**
  String get asrServicesSystemAvailable;

  /// No description provided for @asrServicesSystemCheckFailed.
  ///
  /// In en, this message translates to:
  /// **'System speech recognition is unavailable on this device.'**
  String get asrServicesSystemCheckFailed;

  /// No description provided for @asrServicesMicrophonePermissionDenied.
  ///
  /// In en, this message translates to:
  /// **'Microphone permission was not granted.'**
  String get asrServicesMicrophonePermissionDenied;

  /// No description provided for @asrServicesNoSpeechDetected.
  ///
  /// In en, this message translates to:
  /// **'No speech was detected.'**
  String get asrServicesNoSpeechDetected;

  /// No description provided for @asrServicesRecognitionFailed.
  ///
  /// In en, this message translates to:
  /// **'Speech recognition failed: {error}'**
  String asrServicesRecognitionFailed(String error);

  /// No description provided for @ttsServicesPageAddNotImplemented.
  ///
  /// In en, this message translates to:
  /// **'Add TTS service not implemented'**
  String get ttsServicesPageAddNotImplemented;

  /// No description provided for @ttsServicesPageSystemTtsTitle.
  ///
  /// In en, this message translates to:
  /// **'System TTS'**
  String get ttsServicesPageSystemTtsTitle;

  /// No description provided for @ttsServicesPageSystemTtsAvailableSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Use system built-in TTS'**
  String get ttsServicesPageSystemTtsAvailableSubtitle;

  /// No description provided for @ttsServicesPageSystemTtsUnavailableSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Unavailable: {error}'**
  String ttsServicesPageSystemTtsUnavailableSubtitle(String error);

  /// No description provided for @ttsServicesPageSystemTtsUnavailableNotInitialized.
  ///
  /// In en, this message translates to:
  /// **'not initialized'**
  String get ttsServicesPageSystemTtsUnavailableNotInitialized;

  /// No description provided for @ttsServicesPageTestSpeechText.
  ///
  /// In en, this message translates to:
  /// **'Hello, this is a test speech.'**
  String get ttsServicesPageTestSpeechText;

  /// No description provided for @ttsServicesPageConfigureTooltip.
  ///
  /// In en, this message translates to:
  /// **'Configure'**
  String get ttsServicesPageConfigureTooltip;

  /// No description provided for @ttsServicesPageTestVoiceTooltip.
  ///
  /// In en, this message translates to:
  /// **'Test voice'**
  String get ttsServicesPageTestVoiceTooltip;

  /// No description provided for @ttsServicesPageStopTooltip.
  ///
  /// In en, this message translates to:
  /// **'Stop'**
  String get ttsServicesPageStopTooltip;

  /// No description provided for @ttsServicesPageDeleteTooltip.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get ttsServicesPageDeleteTooltip;

  /// No description provided for @ttsServicesPageSystemTtsSettingsTitle.
  ///
  /// In en, this message translates to:
  /// **'System TTS Settings'**
  String get ttsServicesPageSystemTtsSettingsTitle;

  /// No description provided for @ttsServicesPageEngineLabel.
  ///
  /// In en, this message translates to:
  /// **'Engine'**
  String get ttsServicesPageEngineLabel;

  /// No description provided for @ttsServicesPageAutoLabel.
  ///
  /// In en, this message translates to:
  /// **'Auto'**
  String get ttsServicesPageAutoLabel;

  /// No description provided for @ttsServicesPageLanguageLabel.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get ttsServicesPageLanguageLabel;

  /// No description provided for @ttsServicesPageSpeechRateLabel.
  ///
  /// In en, this message translates to:
  /// **'Speech rate'**
  String get ttsServicesPageSpeechRateLabel;

  /// No description provided for @ttsServicesPagePitchLabel.
  ///
  /// In en, this message translates to:
  /// **'Pitch'**
  String get ttsServicesPagePitchLabel;

  /// No description provided for @ttsServicesPageSettingsSavedMessage.
  ///
  /// In en, this message translates to:
  /// **'Settings saved.'**
  String get ttsServicesPageSettingsSavedMessage;

  /// No description provided for @ttsServicesPageDoneButton.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get ttsServicesPageDoneButton;

  /// No description provided for @ttsServicesPageNetworkSectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Network TTS'**
  String get ttsServicesPageNetworkSectionTitle;

  /// No description provided for @ttsServicesPageNoNetworkServices.
  ///
  /// In en, this message translates to:
  /// **'No TTS services.'**
  String get ttsServicesPageNoNetworkServices;

  /// No description provided for @ttsServicesDialogAddTitle.
  ///
  /// In en, this message translates to:
  /// **'Add TTS Service'**
  String get ttsServicesDialogAddTitle;

  /// No description provided for @ttsServicesDialogEditTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit TTS Service'**
  String get ttsServicesDialogEditTitle;

  /// No description provided for @ttsServicesDialogProviderType.
  ///
  /// In en, this message translates to:
  /// **'Provider'**
  String get ttsServicesDialogProviderType;

  /// No description provided for @ttsServicesDialogCancelButton.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get ttsServicesDialogCancelButton;

  /// No description provided for @ttsServicesDialogAddButton.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get ttsServicesDialogAddButton;

  /// No description provided for @ttsServicesDialogSaveButton.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get ttsServicesDialogSaveButton;

  /// No description provided for @ttsServicesFieldNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get ttsServicesFieldNameLabel;

  /// No description provided for @ttsServicesFieldApiKeyLabel.
  ///
  /// In en, this message translates to:
  /// **'API Key'**
  String get ttsServicesFieldApiKeyLabel;

  /// No description provided for @ttsServicesFieldBaseUrlLabel.
  ///
  /// In en, this message translates to:
  /// **'API Base URL'**
  String get ttsServicesFieldBaseUrlLabel;

  /// No description provided for @ttsServicesFieldModelLabel.
  ///
  /// In en, this message translates to:
  /// **'Model'**
  String get ttsServicesFieldModelLabel;

  /// No description provided for @ttsServicesFieldVoiceLabel.
  ///
  /// In en, this message translates to:
  /// **'Voice'**
  String get ttsServicesFieldVoiceLabel;

  /// No description provided for @ttsServicesFieldVoiceIdLabel.
  ///
  /// In en, this message translates to:
  /// **'Voice ID'**
  String get ttsServicesFieldVoiceIdLabel;

  /// No description provided for @ttsServicesFieldEmotionLabel.
  ///
  /// In en, this message translates to:
  /// **'Emotion'**
  String get ttsServicesFieldEmotionLabel;

  /// No description provided for @ttsServicesFieldSpeedLabel.
  ///
  /// In en, this message translates to:
  /// **'Speed'**
  String get ttsServicesFieldSpeedLabel;

  /// No description provided for @ttsServicesFieldLanguageTypeLabel.
  ///
  /// In en, this message translates to:
  /// **'Language type'**
  String get ttsServicesFieldLanguageTypeLabel;

  /// No description provided for @ttsServicesFieldLanguageLabel.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get ttsServicesFieldLanguageLabel;

  /// No description provided for @ttsServicesFieldWorkspaceIdLabel.
  ///
  /// In en, this message translates to:
  /// **'Workspace ID'**
  String get ttsServicesFieldWorkspaceIdLabel;

  /// No description provided for @ttsServicesFieldRegionLabel.
  ///
  /// In en, this message translates to:
  /// **'Region'**
  String get ttsServicesFieldRegionLabel;

  /// No description provided for @ttsServicesFieldFormatLabel.
  ///
  /// In en, this message translates to:
  /// **'Audio format'**
  String get ttsServicesFieldFormatLabel;

  /// No description provided for @ttsServicesFieldOutputFormatLabel.
  ///
  /// In en, this message translates to:
  /// **'Output format'**
  String get ttsServicesFieldOutputFormatLabel;

  /// No description provided for @ttsServicesFieldSampleRateLabel.
  ///
  /// In en, this message translates to:
  /// **'Sample rate'**
  String get ttsServicesFieldSampleRateLabel;

  /// No description provided for @ttsServicesFieldVolumeLabel.
  ///
  /// In en, this message translates to:
  /// **'Volume'**
  String get ttsServicesFieldVolumeLabel;

  /// No description provided for @ttsServicesFieldPitchLabel.
  ///
  /// In en, this message translates to:
  /// **'Pitch'**
  String get ttsServicesFieldPitchLabel;

  /// No description provided for @ttsServicesFieldLanguageBoostLabel.
  ///
  /// In en, this message translates to:
  /// **'Language boost'**
  String get ttsServicesFieldLanguageBoostLabel;

  /// No description provided for @ttsServicesFieldBitrateLabel.
  ///
  /// In en, this message translates to:
  /// **'Bitrate'**
  String get ttsServicesFieldBitrateLabel;

  /// No description provided for @ttsServicesFieldChannelLabel.
  ///
  /// In en, this message translates to:
  /// **'Channels'**
  String get ttsServicesFieldChannelLabel;

  /// No description provided for @ttsServicesFieldSubtitlesLabel.
  ///
  /// In en, this message translates to:
  /// **'Generate subtitles'**
  String get ttsServicesFieldSubtitlesLabel;

  /// No description provided for @ttsServicesFieldPronunciationDictionaryLabel.
  ///
  /// In en, this message translates to:
  /// **'Pronunciation dictionary (one entry per line)'**
  String get ttsServicesFieldPronunciationDictionaryLabel;

  /// No description provided for @ttsServicesFieldInstructionLabel.
  ///
  /// In en, this message translates to:
  /// **'Style / voice description'**
  String get ttsServicesFieldInstructionLabel;

  /// No description provided for @ttsServicesFieldStreamingLabel.
  ///
  /// In en, this message translates to:
  /// **'Streaming'**
  String get ttsServicesFieldStreamingLabel;

  /// No description provided for @ttsServicesFieldOptimizeTextPreviewLabel.
  ///
  /// In en, this message translates to:
  /// **'Optimize text preview'**
  String get ttsServicesFieldOptimizeTextPreviewLabel;

  /// No description provided for @ttsServicesFieldReferenceAudioLabel.
  ///
  /// In en, this message translates to:
  /// **'Reference audio (WAV/MP3 data URI)'**
  String get ttsServicesFieldReferenceAudioLabel;

  /// No description provided for @ttsServicesFieldChooseReferenceAudioButton.
  ///
  /// In en, this message translates to:
  /// **'Choose reference audio'**
  String get ttsServicesFieldChooseReferenceAudioButton;

  /// No description provided for @ttsServicesFieldTemperatureLabel.
  ///
  /// In en, this message translates to:
  /// **'Temperature'**
  String get ttsServicesFieldTemperatureLabel;

  /// No description provided for @ttsServicesFieldTopPLabel.
  ///
  /// In en, this message translates to:
  /// **'Top P'**
  String get ttsServicesFieldTopPLabel;

  /// No description provided for @ttsServicesFieldLatencyLabel.
  ///
  /// In en, this message translates to:
  /// **'Latency'**
  String get ttsServicesFieldLatencyLabel;

  /// No description provided for @ttsServicesEmotionAutoLabel.
  ///
  /// In en, this message translates to:
  /// **'Auto match'**
  String get ttsServicesEmotionAutoLabel;

  /// No description provided for @ttsServicesValidationApiKeyRequired.
  ///
  /// In en, this message translates to:
  /// **'API Key is required'**
  String get ttsServicesValidationApiKeyRequired;

  /// No description provided for @ttsServicesValidationReferenceIdRequired.
  ///
  /// In en, this message translates to:
  /// **'Voice/reference ID is required'**
  String get ttsServicesValidationReferenceIdRequired;

  /// No description provided for @ttsServicesValidationInstructionRequired.
  ///
  /// In en, this message translates to:
  /// **'A voice description is required'**
  String get ttsServicesValidationInstructionRequired;

  /// No description provided for @ttsServicesValidationSampleRate.
  ///
  /// In en, this message translates to:
  /// **'{format} requires {rates} Hz.'**
  String ttsServicesValidationSampleRate(String format, String rates);

  /// No description provided for @ttsServicesViewDetailsButton.
  ///
  /// In en, this message translates to:
  /// **'View details'**
  String get ttsServicesViewDetailsButton;

  /// No description provided for @ttsServicesDialogErrorTitle.
  ///
  /// In en, this message translates to:
  /// **'Error Details'**
  String get ttsServicesDialogErrorTitle;

  /// No description provided for @ttsServicesCloseButton.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get ttsServicesCloseButton;

  /// No description provided for @ttsSettingsPageTitle.
  ///
  /// In en, this message translates to:
  /// **'TTS Settings'**
  String get ttsSettingsPageTitle;

  /// No description provided for @ttsSettingsPlaybackSection.
  ///
  /// In en, this message translates to:
  /// **'Playback'**
  String get ttsSettingsPlaybackSection;

  /// No description provided for @ttsSettingsAutoPlayTitle.
  ///
  /// In en, this message translates to:
  /// **'Auto-play Assistant Replies'**
  String get ttsSettingsAutoPlayTitle;

  /// No description provided for @ttsSettingsAutoPlayDescription.
  ///
  /// In en, this message translates to:
  /// **'Start TTS automatically after an assistant reply finishes.'**
  String get ttsSettingsAutoPlayDescription;

  /// No description provided for @ttsSettingsCacheReplayTitle.
  ///
  /// In en, this message translates to:
  /// **'Reuse Audio for Replay'**
  String get ttsSettingsCacheReplayTitle;

  /// No description provided for @ttsSettingsCacheReplayDescription.
  ///
  /// In en, this message translates to:
  /// **'Replay generated network audio without requesting the TTS service again.'**
  String get ttsSettingsCacheReplayDescription;

  /// No description provided for @ttsSettingsTextSelectionSection.
  ///
  /// In en, this message translates to:
  /// **'Text Selection'**
  String get ttsSettingsTextSelectionSection;

  /// No description provided for @ttsSettingsTextSelectionFallbackDescription.
  ///
  /// In en, this message translates to:
  /// **'If no matching text is found, the full reply is played.'**
  String get ttsSettingsTextSelectionFallbackDescription;

  /// No description provided for @ttsSettingsTextSelectionFullTextTitle.
  ///
  /// In en, this message translates to:
  /// **'Full text'**
  String get ttsSettingsTextSelectionFullTextTitle;

  /// No description provided for @ttsSettingsTextSelectionFullTextDescription.
  ///
  /// In en, this message translates to:
  /// **'Play the complete assistant reply.'**
  String get ttsSettingsTextSelectionFullTextDescription;

  /// No description provided for @ttsSettingsTextSelectionQuotedOnlyTitle.
  ///
  /// In en, this message translates to:
  /// **'Quoted text only'**
  String get ttsSettingsTextSelectionQuotedOnlyTitle;

  /// No description provided for @ttsSettingsTextSelectionQuotedOnlyDescription.
  ///
  /// In en, this message translates to:
  /// **'Play text inside “”, ‘’, \"\", \'\', 「」, or 『』.'**
  String get ttsSettingsTextSelectionQuotedOnlyDescription;

  /// No description provided for @ttsSettingsTextSelectionOutsideParenthesesTitle.
  ///
  /// In en, this message translates to:
  /// **'Outside parentheses'**
  String get ttsSettingsTextSelectionOutsideParenthesesTitle;

  /// No description provided for @ttsSettingsTextSelectionOutsideParenthesesDescription.
  ///
  /// In en, this message translates to:
  /// **'Skip text inside () and （）.'**
  String get ttsSettingsTextSelectionOutsideParenthesesDescription;

  /// No description provided for @ttsSettingsTextSelectionItalicOnlyTitle.
  ///
  /// In en, this message translates to:
  /// **'Italic text only'**
  String get ttsSettingsTextSelectionItalicOnlyTitle;

  /// No description provided for @ttsSettingsTextSelectionItalicOnlyDescription.
  ///
  /// In en, this message translates to:
  /// **'Play Markdown or HTML italic text.'**
  String get ttsSettingsTextSelectionItalicOnlyDescription;

  /// No description provided for @ttsSettingsTextSelectionNonItalicTitle.
  ///
  /// In en, this message translates to:
  /// **'Non-italic text only'**
  String get ttsSettingsTextSelectionNonItalicTitle;

  /// No description provided for @ttsSettingsTextSelectionNonItalicDescription.
  ///
  /// In en, this message translates to:
  /// **'Skip Markdown or HTML italic text.'**
  String get ttsSettingsTextSelectionNonItalicDescription;

  /// No description provided for @ttsFloatingPlayerLabel.
  ///
  /// In en, this message translates to:
  /// **'TTS player'**
  String get ttsFloatingPlayerLabel;

  /// No description provided for @ttsFloatingPauseTooltip.
  ///
  /// In en, this message translates to:
  /// **'Pause'**
  String get ttsFloatingPauseTooltip;

  /// No description provided for @ttsFloatingResumeTooltip.
  ///
  /// In en, this message translates to:
  /// **'Resume'**
  String get ttsFloatingResumeTooltip;

  /// No description provided for @ttsFloatingReplayTooltip.
  ///
  /// In en, this message translates to:
  /// **'Replay'**
  String get ttsFloatingReplayTooltip;

  /// No description provided for @ttsFloatingRewind15Tooltip.
  ///
  /// In en, this message translates to:
  /// **'Back 15 seconds'**
  String get ttsFloatingRewind15Tooltip;

  /// No description provided for @ttsFloatingForward15Tooltip.
  ///
  /// In en, this message translates to:
  /// **'Forward 15 seconds'**
  String get ttsFloatingForward15Tooltip;

  /// No description provided for @ttsFloatingSpeedTooltip.
  ///
  /// In en, this message translates to:
  /// **'Playback speed'**
  String get ttsFloatingSpeedTooltip;

  /// No description provided for @ttsFloatingCloseTooltip.
  ///
  /// In en, this message translates to:
  /// **'Close player'**
  String get ttsFloatingCloseTooltip;

  /// No description provided for @ttsFloatingExpandTooltip.
  ///
  /// In en, this message translates to:
  /// **'Expand playback controls'**
  String get ttsFloatingExpandTooltip;

  /// No description provided for @ttsFloatingCollapseTooltip.
  ///
  /// In en, this message translates to:
  /// **'Collapse playback controls'**
  String get ttsFloatingCollapseTooltip;

  /// No description provided for @ttsFloatingSaveTooltip.
  ///
  /// In en, this message translates to:
  /// **'Save audio'**
  String get ttsFloatingSaveTooltip;

  /// No description provided for @ttsSaveDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Save TTS audio'**
  String get ttsSaveDialogTitle;

  /// No description provided for @ttsSaveSuccess.
  ///
  /// In en, this message translates to:
  /// **'Audio saved successfully.'**
  String get ttsSaveSuccess;

  /// No description provided for @ttsSaveNothing.
  ///
  /// In en, this message translates to:
  /// **'No audio is available to save.'**
  String get ttsSaveNothing;

  /// No description provided for @ttsSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to save audio: {message}'**
  String ttsSaveFailed(String message);

  /// No description provided for @imageViewerPageShareFailedOpenFile.
  ///
  /// In en, this message translates to:
  /// **'Unable to share, tried to open file: {message}'**
  String imageViewerPageShareFailedOpenFile(String message);

  /// No description provided for @imageViewerPageShareFailed.
  ///
  /// In en, this message translates to:
  /// **'Share failed: {error}'**
  String imageViewerPageShareFailed(String error);

  /// No description provided for @imageViewerPageShareButton.
  ///
  /// In en, this message translates to:
  /// **'Share Image'**
  String get imageViewerPageShareButton;

  /// No description provided for @imageViewerPageCloseButton.
  ///
  /// In en, this message translates to:
  /// **'Close preview'**
  String get imageViewerPageCloseButton;

  /// No description provided for @imageViewerPageSaveButton.
  ///
  /// In en, this message translates to:
  /// **'Save Image'**
  String get imageViewerPageSaveButton;

  /// No description provided for @imageViewerPageCopyButton.
  ///
  /// In en, this message translates to:
  /// **'Copy Image'**
  String get imageViewerPageCopyButton;

  /// No description provided for @imageViewerPagePreviousButton.
  ///
  /// In en, this message translates to:
  /// **'Previous Image'**
  String get imageViewerPagePreviousButton;

  /// No description provided for @imageViewerPageNextButton.
  ///
  /// In en, this message translates to:
  /// **'Next Image'**
  String get imageViewerPageNextButton;

  /// No description provided for @imageViewerPageZoomInButton.
  ///
  /// In en, this message translates to:
  /// **'Zoom In'**
  String get imageViewerPageZoomInButton;

  /// No description provided for @imageViewerPageZoomOutButton.
  ///
  /// In en, this message translates to:
  /// **'Zoom Out'**
  String get imageViewerPageZoomOutButton;

  /// No description provided for @imageViewerPageResetZoomButton.
  ///
  /// In en, this message translates to:
  /// **'Reset Zoom'**
  String get imageViewerPageResetZoomButton;

  /// No description provided for @imageViewerPageFlipHorizontalButton.
  ///
  /// In en, this message translates to:
  /// **'Flip Horizontal'**
  String get imageViewerPageFlipHorizontalButton;

  /// No description provided for @imageViewerPageFlipVerticalButton.
  ///
  /// In en, this message translates to:
  /// **'Flip Vertical'**
  String get imageViewerPageFlipVerticalButton;

  /// No description provided for @imageViewerPageRotateLeftButton.
  ///
  /// In en, this message translates to:
  /// **'Rotate Left'**
  String get imageViewerPageRotateLeftButton;

  /// No description provided for @imageViewerPageRotateRightButton.
  ///
  /// In en, this message translates to:
  /// **'Rotate Right'**
  String get imageViewerPageRotateRightButton;

  /// No description provided for @imageViewerPageCounter.
  ///
  /// In en, this message translates to:
  /// **'{index}/{total}'**
  String imageViewerPageCounter(int index, int total);

  /// No description provided for @imageViewerPageImageLabel.
  ///
  /// In en, this message translates to:
  /// **'Image {index} of {total}'**
  String imageViewerPageImageLabel(int index, int total);

  /// No description provided for @imageViewerPageImageLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Unable to load image'**
  String get imageViewerPageImageLoadFailed;

  /// No description provided for @imageViewerPageSaveSuccess.
  ///
  /// In en, this message translates to:
  /// **'Saved to gallery'**
  String get imageViewerPageSaveSuccess;

  /// No description provided for @imageViewerPageSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Save failed: {error}'**
  String imageViewerPageSaveFailed(String error);

  /// No description provided for @settingsShare.
  ///
  /// In en, this message translates to:
  /// **'Kelivo - Open Source AI Assistant'**
  String get settingsShare;

  /// No description provided for @searchProviderBingLocalDescription.
  ///
  /// In en, this message translates to:
  /// **'Uses web scraping to fetch Bing results. No API key required; may be unstable.'**
  String get searchProviderBingLocalDescription;

  /// No description provided for @searchProviderDuckDuckGoDescription.
  ///
  /// In en, this message translates to:
  /// **'Privacy-focused DuckDuckGo search via DDGS. No API key required; supports region selection.'**
  String get searchProviderDuckDuckGoDescription;

  /// No description provided for @searchProviderBraveDescription.
  ///
  /// In en, this message translates to:
  /// **'Independent search engine by Brave. Privacy-focused with no tracking or profiling.'**
  String get searchProviderBraveDescription;

  /// No description provided for @searchProviderExaDescription.
  ///
  /// In en, this message translates to:
  /// **'Neural search with semantic understanding. Great for research and finding specific content.'**
  String get searchProviderExaDescription;

  /// No description provided for @searchProviderLinkUpDescription.
  ///
  /// In en, this message translates to:
  /// **'Search API with sourced answers. Provides both results and AI-generated summaries.'**
  String get searchProviderLinkUpDescription;

  /// No description provided for @searchProviderMetasoDescription.
  ///
  /// In en, this message translates to:
  /// **'Chinese search by Metaso. Optimized for Chinese content with AI capabilities.'**
  String get searchProviderMetasoDescription;

  /// No description provided for @searchProviderSearXNGDescription.
  ///
  /// In en, this message translates to:
  /// **'Privacy-respecting metasearch engine. Self-hosted instance required; no tracking.'**
  String get searchProviderSearXNGDescription;

  /// No description provided for @searchProviderTavilyDescription.
  ///
  /// In en, this message translates to:
  /// **'AI search API optimized for LLMs. Provides high-quality, relevant results.'**
  String get searchProviderTavilyDescription;

  /// No description provided for @searchProviderZhipuDescription.
  ///
  /// In en, this message translates to:
  /// **'Chinese AI search by Zhipu AI. Optimized for Chinese content and queries.'**
  String get searchProviderZhipuDescription;

  /// No description provided for @searchProviderOllamaDescription.
  ///
  /// In en, this message translates to:
  /// **'Ollama web search API. Augments models with up-to-date information.'**
  String get searchProviderOllamaDescription;

  /// No description provided for @searchProviderJinaDescription.
  ///
  /// In en, this message translates to:
  /// **'AI search foundation with embeddings, rerankers, web reader, deepsearch, and small language models. Multilingual and multimodal.'**
  String get searchProviderJinaDescription;

  /// No description provided for @searchServiceNameBingLocal.
  ///
  /// In en, this message translates to:
  /// **'Bing (Local)'**
  String get searchServiceNameBingLocal;

  /// No description provided for @searchServiceNameDuckDuckGo.
  ///
  /// In en, this message translates to:
  /// **'DuckDuckGo'**
  String get searchServiceNameDuckDuckGo;

  /// No description provided for @searchServiceNameTavily.
  ///
  /// In en, this message translates to:
  /// **'Tavily'**
  String get searchServiceNameTavily;

  /// No description provided for @searchServiceNameExa.
  ///
  /// In en, this message translates to:
  /// **'Exa'**
  String get searchServiceNameExa;

  /// No description provided for @searchServiceNameZhipu.
  ///
  /// In en, this message translates to:
  /// **'Zhipu AI'**
  String get searchServiceNameZhipu;

  /// No description provided for @searchServiceNameSearXNG.
  ///
  /// In en, this message translates to:
  /// **'SearXNG'**
  String get searchServiceNameSearXNG;

  /// No description provided for @searchServiceNameLinkUp.
  ///
  /// In en, this message translates to:
  /// **'LinkUp'**
  String get searchServiceNameLinkUp;

  /// No description provided for @searchServiceNameBrave.
  ///
  /// In en, this message translates to:
  /// **'Brave Search'**
  String get searchServiceNameBrave;

  /// No description provided for @searchServiceNameMetaso.
  ///
  /// In en, this message translates to:
  /// **'Metaso'**
  String get searchServiceNameMetaso;

  /// No description provided for @searchServiceNameOllama.
  ///
  /// In en, this message translates to:
  /// **'Ollama'**
  String get searchServiceNameOllama;

  /// No description provided for @searchServiceNameJina.
  ///
  /// In en, this message translates to:
  /// **'Jina'**
  String get searchServiceNameJina;

  /// No description provided for @searchServiceNamePerplexity.
  ///
  /// In en, this message translates to:
  /// **'Perplexity'**
  String get searchServiceNamePerplexity;

  /// No description provided for @searchProviderPerplexityDescription.
  ///
  /// In en, this message translates to:
  /// **'Perplexity Search API. Ranked web results with region and domain filters.'**
  String get searchProviderPerplexityDescription;

  /// No description provided for @searchServiceNameBocha.
  ///
  /// In en, this message translates to:
  /// **'Bocha'**
  String get searchServiceNameBocha;

  /// No description provided for @searchProviderBochaDescription.
  ///
  /// In en, this message translates to:
  /// **'Bocha web search API. Accurate web results with optional summaries.'**
  String get searchProviderBochaDescription;

  /// No description provided for @searchServiceNameDoubao.
  ///
  /// In en, this message translates to:
  /// **'Doubao'**
  String get searchServiceNameDoubao;

  /// No description provided for @searchProviderDoubaoDescription.
  ///
  /// In en, this message translates to:
  /// **'Doubao web search API by Volcano Engine.'**
  String get searchProviderDoubaoDescription;

  /// No description provided for @searchServiceNameSerper.
  ///
  /// In en, this message translates to:
  /// **'Serper'**
  String get searchServiceNameSerper;

  /// No description provided for @searchProviderSerperDescription.
  ///
  /// In en, this message translates to:
  /// **'Serper Google Search API. Fast web results with optional country, language, time, and page filters.'**
  String get searchProviderSerperDescription;

  /// No description provided for @searchServiceNameQuerit.
  ///
  /// In en, this message translates to:
  /// **'Querit'**
  String get searchServiceNameQuerit;

  /// No description provided for @searchProviderQueritDescription.
  ///
  /// In en, this message translates to:
  /// **'Querit Search API for LLM applications. Returns real-time web results with site, time, country, and language filters.'**
  String get searchProviderQueritDescription;

  /// No description provided for @searchServiceNameGrok.
  ///
  /// In en, this message translates to:
  /// **'Grok'**
  String get searchServiceNameGrok;

  /// No description provided for @searchProviderGrokDescription.
  ///
  /// In en, this message translates to:
  /// **'Grok search via xAI Responses API. Uses web and X search tools and returns cited sources.'**
  String get searchProviderGrokDescription;

  /// No description provided for @searchServiceNameStepFun.
  ///
  /// In en, this message translates to:
  /// **'StepFun'**
  String get searchServiceNameStepFun;

  /// No description provided for @searchProviderStepFunDescription.
  ///
  /// In en, this message translates to:
  /// **'StepFun web search via POST /v1/search.'**
  String get searchProviderStepFunDescription;

  /// No description provided for @searchServiceNameFirecrawl.
  ///
  /// In en, this message translates to:
  /// **'Firecrawl'**
  String get searchServiceNameFirecrawl;

  /// No description provided for @searchProviderFirecrawlDescription.
  ///
  /// In en, this message translates to:
  /// **'Firecrawl Search API v2. API key is optional. Scrape is not supported here.'**
  String get searchProviderFirecrawlDescription;

  /// No description provided for @searchServiceNameTinyFish.
  ///
  /// In en, this message translates to:
  /// **'TinyFish'**
  String get searchServiceNameTinyFish;

  /// No description provided for @searchProviderTinyFishDescription.
  ///
  /// In en, this message translates to:
  /// **'TinyFish Search API with region/language filters. Requires an API key. Fetch/Scrape is not supported here.'**
  String get searchProviderTinyFishDescription;

  /// No description provided for @searchServiceNameAnySearch.
  ///
  /// In en, this message translates to:
  /// **'AnySearch'**
  String get searchServiceNameAnySearch;

  /// No description provided for @searchProviderAnySearchDescription.
  ///
  /// In en, this message translates to:
  /// **'Unified search for AI agents with automatic routing across web and specialist data sources. API key is optional.'**
  String get searchProviderAnySearchDescription;

  /// No description provided for @searchServiceNameParallel.
  ///
  /// In en, this message translates to:
  /// **'Parallel'**
  String get searchServiceNameParallel;

  /// No description provided for @searchProviderParallelDescription.
  ///
  /// In en, this message translates to:
  /// **'Parallel Search API. Returns LLM-optimized web excerpts with turbo, fast, basic, and advanced modes.'**
  String get searchProviderParallelDescription;

  /// No description provided for @searchServicesDialogSearchMode.
  ///
  /// In en, this message translates to:
  /// **'Search mode'**
  String get searchServicesDialogSearchMode;

  /// No description provided for @searchServiceNameYou.
  ///
  /// In en, this message translates to:
  /// **'You.com'**
  String get searchServiceNameYou;

  /// No description provided for @searchProviderYouDescription.
  ///
  /// In en, this message translates to:
  /// **'You.com Search API. Returns web and news results with highlights or snippets.'**
  String get searchProviderYouDescription;

  /// No description provided for @searchServicesDialogContentMode.
  ///
  /// In en, this message translates to:
  /// **'Content mode'**
  String get searchServicesDialogContentMode;

  /// No description provided for @searchServicesDialogHighlights.
  ///
  /// In en, this message translates to:
  /// **'Highlights'**
  String get searchServicesDialogHighlights;

  /// No description provided for @searchServicesDialogSnippets.
  ///
  /// In en, this message translates to:
  /// **'Snippets'**
  String get searchServicesDialogSnippets;

  /// No description provided for @searchServicesDialogWebSearch.
  ///
  /// In en, this message translates to:
  /// **'Web Search'**
  String get searchServicesDialogWebSearch;

  /// No description provided for @searchServicesDialogLlmContext.
  ///
  /// In en, this message translates to:
  /// **'LLM Context'**
  String get searchServicesDialogLlmContext;

  /// No description provided for @searchServicesDialogMaximumTokens.
  ///
  /// In en, this message translates to:
  /// **'Maximum tokens'**
  String get searchServicesDialogMaximumTokens;

  /// No description provided for @searchServicesDialogMaximumTokensInvalid.
  ///
  /// In en, this message translates to:
  /// **'Maximum tokens must be between 1024 and 32768.'**
  String get searchServicesDialogMaximumTokensInvalid;

  /// No description provided for @searchServiceNameKelivo.
  ///
  /// In en, this message translates to:
  /// **'Kelivo'**
  String get searchServiceNameKelivo;

  /// No description provided for @searchServicesDialogCountryOptional.
  ///
  /// In en, this message translates to:
  /// **'Country/region (optional)'**
  String get searchServicesDialogCountryOptional;

  /// No description provided for @searchServicesDialogLanguageOptional.
  ///
  /// In en, this message translates to:
  /// **'Language (optional)'**
  String get searchServicesDialogLanguageOptional;

  /// No description provided for @searchServicesDialogTimeFilterOptional.
  ///
  /// In en, this message translates to:
  /// **'Time filter (optional)'**
  String get searchServicesDialogTimeFilterOptional;

  /// No description provided for @searchServicesDialogPageOptional.
  ///
  /// In en, this message translates to:
  /// **'Page (optional)'**
  String get searchServicesDialogPageOptional;

  /// No description provided for @searchServicesDialogPageInvalid.
  ///
  /// In en, this message translates to:
  /// **'Page must be a positive integer.'**
  String get searchServicesDialogPageInvalid;

  /// No description provided for @searchServicesDialogSitesIncludeOptional.
  ///
  /// In en, this message translates to:
  /// **'Include sites (optional)'**
  String get searchServicesDialogSitesIncludeOptional;

  /// No description provided for @searchServicesDialogSitesExcludeOptional.
  ///
  /// In en, this message translates to:
  /// **'Exclude sites (optional)'**
  String get searchServicesDialogSitesExcludeOptional;

  /// No description provided for @searchServicesDialogTimeRangeOptional.
  ///
  /// In en, this message translates to:
  /// **'Time range (optional)'**
  String get searchServicesDialogTimeRangeOptional;

  /// No description provided for @searchServicesDialogCountriesOptional.
  ///
  /// In en, this message translates to:
  /// **'Countries (optional)'**
  String get searchServicesDialogCountriesOptional;

  /// No description provided for @searchServicesDialogLanguagesOptional.
  ///
  /// In en, this message translates to:
  /// **'Languages (optional)'**
  String get searchServicesDialogLanguagesOptional;

  /// No description provided for @searchServicesDialogSitesHint.
  ///
  /// In en, this message translates to:
  /// **'example.com, docs.example.com'**
  String get searchServicesDialogSitesHint;

  /// No description provided for @searchServicesDialogTimeRangeHint.
  ///
  /// In en, this message translates to:
  /// **'d7'**
  String get searchServicesDialogTimeRangeHint;

  /// No description provided for @searchServicesDialogCountriesHint.
  ///
  /// In en, this message translates to:
  /// **'united states, japan'**
  String get searchServicesDialogCountriesHint;

  /// No description provided for @searchServicesDialogLanguagesHint.
  ///
  /// In en, this message translates to:
  /// **'english, japanese'**
  String get searchServicesDialogLanguagesHint;

  /// No description provided for @generationInterrupted.
  ///
  /// In en, this message translates to:
  /// **'Generation interrupted'**
  String get generationInterrupted;

  /// No description provided for @titleForLocale.
  ///
  /// In en, this message translates to:
  /// **'New Chat'**
  String get titleForLocale;

  /// No description provided for @temporaryChatTitle.
  ///
  /// In en, this message translates to:
  /// **'Temporary Chat'**
  String get temporaryChatTitle;

  /// No description provided for @temporaryChatEmptyMessage.
  ///
  /// In en, this message translates to:
  /// **'Temporary chats do not appear in history and will be deleted completely after you leave.'**
  String get temporaryChatEmptyMessage;

  /// No description provided for @temporaryChatToggleTooltip.
  ///
  /// In en, this message translates to:
  /// **'Toggle temporary chat'**
  String get temporaryChatToggleTooltip;

  /// No description provided for @quickPhraseBackTooltip.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get quickPhraseBackTooltip;

  /// No description provided for @quickPhraseGlobalTitle.
  ///
  /// In en, this message translates to:
  /// **'Quick Phrase'**
  String get quickPhraseGlobalTitle;

  /// No description provided for @quickPhraseAssistantTitle.
  ///
  /// In en, this message translates to:
  /// **'Assistant Quick Phrase'**
  String get quickPhraseAssistantTitle;

  /// No description provided for @quickPhraseAddTooltip.
  ///
  /// In en, this message translates to:
  /// **'Add Quick Phrase'**
  String get quickPhraseAddTooltip;

  /// No description provided for @quickPhraseEmptyMessage.
  ///
  /// In en, this message translates to:
  /// **'No quick phrases yet'**
  String get quickPhraseEmptyMessage;

  /// No description provided for @quickPhraseAddTitle.
  ///
  /// In en, this message translates to:
  /// **'Add Quick Phrase'**
  String get quickPhraseAddTitle;

  /// No description provided for @quickPhraseEditTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit Quick Phrase'**
  String get quickPhraseEditTitle;

  /// No description provided for @quickPhraseTitleLabel.
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get quickPhraseTitleLabel;

  /// No description provided for @quickPhraseContentLabel.
  ///
  /// In en, this message translates to:
  /// **'Content'**
  String get quickPhraseContentLabel;

  /// No description provided for @quickPhraseCancelButton.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get quickPhraseCancelButton;

  /// No description provided for @quickPhraseSaveButton.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get quickPhraseSaveButton;

  /// No description provided for @instructionInjectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Instruction Injection'**
  String get instructionInjectionTitle;

  /// No description provided for @instructionInjectionBackTooltip.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get instructionInjectionBackTooltip;

  /// No description provided for @instructionInjectionAddTooltip.
  ///
  /// In en, this message translates to:
  /// **'Add Instruction'**
  String get instructionInjectionAddTooltip;

  /// No description provided for @instructionInjectionImportTooltip.
  ///
  /// In en, this message translates to:
  /// **'Import from files'**
  String get instructionInjectionImportTooltip;

  /// No description provided for @instructionInjectionEmptyMessage.
  ///
  /// In en, this message translates to:
  /// **'No instruction injection cards yet'**
  String get instructionInjectionEmptyMessage;

  /// No description provided for @instructionInjectionDefaultTitle.
  ///
  /// In en, this message translates to:
  /// **'Learning Mode'**
  String get instructionInjectionDefaultTitle;

  /// No description provided for @instructionInjectionAddTitle.
  ///
  /// In en, this message translates to:
  /// **'Add Instruction Injection'**
  String get instructionInjectionAddTitle;

  /// No description provided for @instructionInjectionEditTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit Instruction Injection'**
  String get instructionInjectionEditTitle;

  /// No description provided for @instructionInjectionNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get instructionInjectionNameLabel;

  /// No description provided for @instructionInjectionPromptLabel.
  ///
  /// In en, this message translates to:
  /// **'Prompt'**
  String get instructionInjectionPromptLabel;

  /// No description provided for @instructionInjectionUngroupedGroup.
  ///
  /// In en, this message translates to:
  /// **'Ungrouped'**
  String get instructionInjectionUngroupedGroup;

  /// No description provided for @instructionInjectionGroupLabel.
  ///
  /// In en, this message translates to:
  /// **'Group'**
  String get instructionInjectionGroupLabel;

  /// No description provided for @instructionInjectionGroupHint.
  ///
  /// In en, this message translates to:
  /// **'Optional'**
  String get instructionInjectionGroupHint;

  /// No description provided for @instructionInjectionImportSuccess.
  ///
  /// In en, this message translates to:
  /// **'Imported {count} instruction(s)'**
  String instructionInjectionImportSuccess(int count);

  /// No description provided for @instructionInjectionSheetSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Choose a prompt to apply before chatting'**
  String get instructionInjectionSheetSubtitle;

  /// No description provided for @mcpJsonEditButtonTooltip.
  ///
  /// In en, this message translates to:
  /// **'Edit JSON'**
  String get mcpJsonEditButtonTooltip;

  /// No description provided for @mcpJsonEditTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit JSON'**
  String get mcpJsonEditTitle;

  /// No description provided for @mcpJsonEditParseFailed.
  ///
  /// In en, this message translates to:
  /// **'JSON parse failed'**
  String get mcpJsonEditParseFailed;

  /// No description provided for @mcpJsonEditSavedApplied.
  ///
  /// In en, this message translates to:
  /// **'Saved and applied'**
  String get mcpJsonEditSavedApplied;

  /// No description provided for @mcpTimeoutSettingsTooltip.
  ///
  /// In en, this message translates to:
  /// **'Set tool call timeout'**
  String get mcpTimeoutSettingsTooltip;

  /// No description provided for @mcpTimeoutDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Tool call timeout'**
  String get mcpTimeoutDialogTitle;

  /// No description provided for @mcpTimeoutSecondsLabel.
  ///
  /// In en, this message translates to:
  /// **'Tool call timeout (seconds)'**
  String get mcpTimeoutSecondsLabel;

  /// No description provided for @mcpTimeoutInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter a positive number of seconds'**
  String get mcpTimeoutInvalid;

  /// No description provided for @quickPhraseEditButton.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get quickPhraseEditButton;

  /// No description provided for @quickPhraseDeleteButton.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get quickPhraseDeleteButton;

  /// No description provided for @quickPhraseMenuTitle.
  ///
  /// In en, this message translates to:
  /// **'Quick Phrase'**
  String get quickPhraseMenuTitle;

  /// No description provided for @chatInputBarQuickPhraseTooltip.
  ///
  /// In en, this message translates to:
  /// **'Quick Phrase'**
  String get chatInputBarQuickPhraseTooltip;

  /// No description provided for @assistantEditQuickPhraseDescription.
  ///
  /// In en, this message translates to:
  /// **'Manage quick phrases for this assistant. Click the button below to add phrases.'**
  String get assistantEditQuickPhraseDescription;

  /// No description provided for @assistantEditManageQuickPhraseButton.
  ///
  /// In en, this message translates to:
  /// **'Manage Quick Phrases'**
  String get assistantEditManageQuickPhraseButton;

  /// No description provided for @assistantEditPageMemoryTab.
  ///
  /// In en, this message translates to:
  /// **'Memory'**
  String get assistantEditPageMemoryTab;

  /// No description provided for @assistantEditLocalToolTimeInfoTitle.
  ///
  /// In en, this message translates to:
  /// **'Time Info'**
  String get assistantEditLocalToolTimeInfoTitle;

  /// No description provided for @assistantEditLocalToolTimeInfoSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Read the device date, weekday, time, timezone, UTC offset, and timestamp.'**
  String get assistantEditLocalToolTimeInfoSubtitle;

  /// No description provided for @assistantEditLocalToolClipboardTitle.
  ///
  /// In en, this message translates to:
  /// **'Clipboard'**
  String get assistantEditLocalToolClipboardTitle;

  /// No description provided for @assistantEditLocalToolClipboardSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Read or write plain text from the device clipboard when explicitly needed.'**
  String get assistantEditLocalToolClipboardSubtitle;

  /// No description provided for @assistantEditLocalToolTextToSpeechTitle.
  ///
  /// In en, this message translates to:
  /// **'Text to Speech'**
  String get assistantEditLocalToolTextToSpeechTitle;

  /// No description provided for @assistantEditLocalToolTextToSpeechSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Let the assistant read text aloud with the configured TTS playback.'**
  String get assistantEditLocalToolTextToSpeechSubtitle;

  /// No description provided for @assistantEditLocalToolAskUserTitle.
  ///
  /// In en, this message translates to:
  /// **'Ask User'**
  String get assistantEditLocalToolAskUserTitle;

  /// No description provided for @assistantEditLocalToolAskUserSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Let the assistant ask short questions and continue after you answer.'**
  String get assistantEditLocalToolAskUserSubtitle;

  /// No description provided for @assistantEditLocalToolCalculateTitle.
  ///
  /// In en, this message translates to:
  /// **'Calculator'**
  String get assistantEditLocalToolCalculateTitle;

  /// No description provided for @assistantEditLocalToolCalculateSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Evaluate mathematical expressions, supports + - * / power sqrt sin cos etc.'**
  String get assistantEditLocalToolCalculateSubtitle;

  /// No description provided for @assistantEditLocalToolScreenTimeTitle.
  ///
  /// In en, this message translates to:
  /// **'Screen Time'**
  String get assistantEditLocalToolScreenTimeTitle;

  /// No description provided for @assistantEditLocalToolScreenTimeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Query app screen usage on this device, requires the Usage access permission.'**
  String get assistantEditLocalToolScreenTimeSubtitle;

  /// No description provided for @chatMessageWidgetScreenTimeTotal.
  ///
  /// In en, this message translates to:
  /// **'Total screen time'**
  String get chatMessageWidgetScreenTimeTotal;

  /// No description provided for @chatMessageWidgetScreenTimePermissionRequired.
  ///
  /// In en, this message translates to:
  /// **'Usage access permission is not granted. Please enable it in system settings and try again.'**
  String get chatMessageWidgetScreenTimePermissionRequired;

  /// No description provided for @assistantEditLocalToolCalendarQueryTitle.
  ///
  /// In en, this message translates to:
  /// **'Query Calendar'**
  String get assistantEditLocalToolCalendarQueryTitle;

  /// No description provided for @assistantEditLocalToolCalendarQuerySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Read calendar events on this device, requires the calendar permission.'**
  String get assistantEditLocalToolCalendarQuerySubtitle;

  /// No description provided for @assistantEditLocalToolCalendarCreateTitle.
  ///
  /// In en, this message translates to:
  /// **'Create Event'**
  String get assistantEditLocalToolCalendarCreateTitle;

  /// No description provided for @assistantEditLocalToolCalendarCreateSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Create calendar events on this device with your confirmation, requires the calendar permission.'**
  String get assistantEditLocalToolCalendarCreateSubtitle;

  /// No description provided for @assistantEditLocalToolLocationTitle.
  ///
  /// In en, this message translates to:
  /// **'Current Location'**
  String get assistantEditLocalToolLocationTitle;

  /// No description provided for @assistantEditLocalToolLocationSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Read a one-shot location from this device, requires the location permission.'**
  String get assistantEditLocalToolLocationSubtitle;

  /// No description provided for @assistantEditLocalToolWeatherTitle.
  ///
  /// In en, this message translates to:
  /// **'Weather'**
  String get assistantEditLocalToolWeatherTitle;

  /// No description provided for @assistantEditLocalToolWeatherSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Get Apple Weather for the current or a specified location. WeatherKit attribution is shown in the result.'**
  String get assistantEditLocalToolWeatherSubtitle;

  /// No description provided for @assistantEditLocalToolHealthTitle.
  ///
  /// In en, this message translates to:
  /// **'Health Summary'**
  String get assistantEditLocalToolHealthTitle;

  /// No description provided for @assistantEditLocalToolHealthSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Read a privacy-preserving activity summary from Apple Health, requires Health access.'**
  String get assistantEditLocalToolHealthSubtitle;

  /// No description provided for @assistantEditLocalToolHealthSelectedCount.
  ///
  /// In en, this message translates to:
  /// **'{selected}/{total} selected'**
  String assistantEditLocalToolHealthSelectedCount(int selected, int total);

  /// No description provided for @healthDataSettingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Health Data'**
  String get healthDataSettingsTitle;

  /// No description provided for @healthDataSettingsDescription.
  ///
  /// In en, this message translates to:
  /// **'HealthKit signals available to the current assistant in daily conversation. Switches control what Kelivo may try to read; iOS still manages actual Health access.'**
  String get healthDataSettingsDescription;

  /// No description provided for @healthDataSettingsBadge.
  ///
  /// In en, this message translates to:
  /// **'{selected}/{total} on'**
  String healthDataSettingsBadge(int selected, int total);

  /// No description provided for @healthDataSettingsIosReadTitle.
  ///
  /// In en, this message translates to:
  /// **'iOS Health Read'**
  String get healthDataSettingsIosReadTitle;

  /// No description provided for @healthDataSettingsIosReadSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Device available, read range managed by iOS'**
  String get healthDataSettingsIosReadSubtitle;

  /// No description provided for @healthDataSettingsOpenSystemSettings.
  ///
  /// In en, this message translates to:
  /// **'Open system settings'**
  String get healthDataSettingsOpenSystemSettings;

  /// No description provided for @healthDataSettingsEnableAll.
  ///
  /// In en, this message translates to:
  /// **'Enable all'**
  String get healthDataSettingsEnableAll;

  /// No description provided for @healthDataSettingsDisableAll.
  ///
  /// In en, this message translates to:
  /// **'Disable all'**
  String get healthDataSettingsDisableAll;

  /// No description provided for @healthDataSettingsCategoryActivity.
  ///
  /// In en, this message translates to:
  /// **'Activity'**
  String get healthDataSettingsCategoryActivity;

  /// No description provided for @healthDataSettingsCategoryRest.
  ///
  /// In en, this message translates to:
  /// **'Rest'**
  String get healthDataSettingsCategoryRest;

  /// No description provided for @healthDataSettingsCategoryHeart.
  ///
  /// In en, this message translates to:
  /// **'Heart'**
  String get healthDataSettingsCategoryHeart;

  /// No description provided for @healthDataSettingsCategoryBody.
  ///
  /// In en, this message translates to:
  /// **'Body'**
  String get healthDataSettingsCategoryBody;

  /// No description provided for @healthDataSettingsTypeStepsTitle.
  ///
  /// In en, this message translates to:
  /// **'Steps'**
  String get healthDataSettingsTypeStepsTitle;

  /// No description provided for @healthDataSettingsTypeStepsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Walking steps summary'**
  String get healthDataSettingsTypeStepsSubtitle;

  /// No description provided for @healthDataSettingsTypeDaylightTitle.
  ///
  /// In en, this message translates to:
  /// **'Sunlight'**
  String get healthDataSettingsTypeDaylightTitle;

  /// No description provided for @healthDataSettingsTypeDaylightSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Outdoor daylight time'**
  String get healthDataSettingsTypeDaylightSubtitle;

  /// No description provided for @healthDataSettingsTypeActiveEnergyTitle.
  ///
  /// In en, this message translates to:
  /// **'Energy'**
  String get healthDataSettingsTypeActiveEnergyTitle;

  /// No description provided for @healthDataSettingsTypeActiveEnergySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Active energy burned'**
  String get healthDataSettingsTypeActiveEnergySubtitle;

  /// No description provided for @healthDataSettingsTypeExerciseMinutesTitle.
  ///
  /// In en, this message translates to:
  /// **'Exercise'**
  String get healthDataSettingsTypeExerciseMinutesTitle;

  /// No description provided for @healthDataSettingsTypeExerciseMinutesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Apple exercise minutes'**
  String get healthDataSettingsTypeExerciseMinutesSubtitle;

  /// No description provided for @healthDataSettingsTypeStandTimeTitle.
  ///
  /// In en, this message translates to:
  /// **'Stand'**
  String get healthDataSettingsTypeStandTimeTitle;

  /// No description provided for @healthDataSettingsTypeStandTimeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Stand time'**
  String get healthDataSettingsTypeStandTimeSubtitle;

  /// No description provided for @healthDataSettingsTypeDistanceTitle.
  ///
  /// In en, this message translates to:
  /// **'Distance'**
  String get healthDataSettingsTypeDistanceTitle;

  /// No description provided for @healthDataSettingsTypeDistanceSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Walking and running distance'**
  String get healthDataSettingsTypeDistanceSubtitle;

  /// No description provided for @healthDataSettingsTypeWorkoutsTitle.
  ///
  /// In en, this message translates to:
  /// **'Workouts'**
  String get healthDataSettingsTypeWorkoutsTitle;

  /// No description provided for @healthDataSettingsTypeWorkoutsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Workout records: type, duration, distance, and energy'**
  String get healthDataSettingsTypeWorkoutsSubtitle;

  /// No description provided for @healthDataSettingsTypeSleepTitle.
  ///
  /// In en, this message translates to:
  /// **'Sleep'**
  String get healthDataSettingsTypeSleepTitle;

  /// No description provided for @healthDataSettingsTypeSleepSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Sleep duration last night'**
  String get healthDataSettingsTypeSleepSubtitle;

  /// No description provided for @healthDataSettingsTypeMindfulnessTitle.
  ///
  /// In en, this message translates to:
  /// **'Resting'**
  String get healthDataSettingsTypeMindfulnessTitle;

  /// No description provided for @healthDataSettingsTypeMindfulnessSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Mindfulness or resting periods'**
  String get healthDataSettingsTypeMindfulnessSubtitle;

  /// No description provided for @healthDataSettingsTypeHeartRateTitle.
  ///
  /// In en, this message translates to:
  /// **'Heart Rate'**
  String get healthDataSettingsTypeHeartRateTitle;

  /// No description provided for @healthDataSettingsTypeHeartRateSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Latest heart rate sample'**
  String get healthDataSettingsTypeHeartRateSubtitle;

  /// No description provided for @healthDataSettingsTypeRestingHeartRateTitle.
  ///
  /// In en, this message translates to:
  /// **'Resting Heart Rate'**
  String get healthDataSettingsTypeRestingHeartRateTitle;

  /// No description provided for @healthDataSettingsTypeRestingHeartRateSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Resting heart rate sample'**
  String get healthDataSettingsTypeRestingHeartRateSubtitle;

  /// No description provided for @healthDataSettingsTypeBloodOxygenTitle.
  ///
  /// In en, this message translates to:
  /// **'Blood Oxygen'**
  String get healthDataSettingsTypeBloodOxygenTitle;

  /// No description provided for @healthDataSettingsTypeBloodOxygenSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Blood oxygen saturation'**
  String get healthDataSettingsTypeBloodOxygenSubtitle;

  /// No description provided for @healthDataSettingsTypeDietaryEnergyTitle.
  ///
  /// In en, this message translates to:
  /// **'Dietary Energy'**
  String get healthDataSettingsTypeDietaryEnergyTitle;

  /// No description provided for @healthDataSettingsTypeDietaryEnergySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Dietary calorie record'**
  String get healthDataSettingsTypeDietaryEnergySubtitle;

  /// No description provided for @healthDataSettingsTypeWaterTitle.
  ///
  /// In en, this message translates to:
  /// **'Water'**
  String get healthDataSettingsTypeWaterTitle;

  /// No description provided for @healthDataSettingsTypeWaterSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Water intake record'**
  String get healthDataSettingsTypeWaterSubtitle;

  /// No description provided for @healthDataSettingsTypeWeightTitle.
  ///
  /// In en, this message translates to:
  /// **'Weight'**
  String get healthDataSettingsTypeWeightTitle;

  /// No description provided for @healthDataSettingsTypeWeightSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Body weight sample'**
  String get healthDataSettingsTypeWeightSubtitle;

  /// No description provided for @healthDataSettingsTypeBmiTitle.
  ///
  /// In en, this message translates to:
  /// **'BMI'**
  String get healthDataSettingsTypeBmiTitle;

  /// No description provided for @healthDataSettingsTypeBmiSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Body mass index'**
  String get healthDataSettingsTypeBmiSubtitle;

  /// No description provided for @healthDataSettingsTypeBloodGlucoseTitle.
  ///
  /// In en, this message translates to:
  /// **'Blood Glucose'**
  String get healthDataSettingsTypeBloodGlucoseTitle;

  /// No description provided for @healthDataSettingsTypeBloodGlucoseSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Blood glucose sample'**
  String get healthDataSettingsTypeBloodGlucoseSubtitle;

  /// No description provided for @assistantEditLocalToolRemindersQueryTitle.
  ///
  /// In en, this message translates to:
  /// **'Query Reminders'**
  String get assistantEditLocalToolRemindersQueryTitle;

  /// No description provided for @assistantEditLocalToolRemindersQuerySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Read reminders on this device, requires full reminders access.'**
  String get assistantEditLocalToolRemindersQuerySubtitle;

  /// No description provided for @assistantEditLocalToolRemindersCreateTitle.
  ///
  /// In en, this message translates to:
  /// **'Create Reminder'**
  String get assistantEditLocalToolRemindersCreateTitle;

  /// No description provided for @assistantEditLocalToolRemindersCreateSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Create a reminder on this device with your confirmation, requires full reminders access.'**
  String get assistantEditLocalToolRemindersCreateSubtitle;

  /// No description provided for @assistantEditLocalToolRemindersCompleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Complete Reminder'**
  String get assistantEditLocalToolRemindersCompleteTitle;

  /// No description provided for @assistantEditLocalToolRemindersCompleteSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Mark a reminder as done with your confirmation, requires full reminders access.'**
  String get assistantEditLocalToolRemindersCompleteSubtitle;

  /// No description provided for @assistantEditMemorySwitchDescription.
  ///
  /// In en, this message translates to:
  /// **'Allow the assistant to create and use memories across chats.'**
  String get assistantEditMemorySwitchDescription;

  /// No description provided for @assistantEditRecentChatsSwitchTitle.
  ///
  /// In en, this message translates to:
  /// **'Recent Chats Reference'**
  String get assistantEditRecentChatsSwitchTitle;

  /// No description provided for @assistantEditRecentChatsSwitchDescription.
  ///
  /// In en, this message translates to:
  /// **'Include recent conversation titles to help with context.'**
  String get assistantEditRecentChatsSwitchDescription;

  /// No description provided for @assistantEditAddMemoryButton.
  ///
  /// In en, this message translates to:
  /// **'Add Memory'**
  String get assistantEditAddMemoryButton;

  /// No description provided for @assistantEditMemoryEmpty.
  ///
  /// In en, this message translates to:
  /// **'No memories yet'**
  String get assistantEditMemoryEmpty;

  /// No description provided for @assistantEditMemoryDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Memory'**
  String get assistantEditMemoryDialogTitle;

  /// No description provided for @assistantEditMemoryDialogHint.
  ///
  /// In en, this message translates to:
  /// **'Enter memory content'**
  String get assistantEditMemoryDialogHint;

  /// No description provided for @assistantEditAddQuickPhraseButton.
  ///
  /// In en, this message translates to:
  /// **'Add Quick Phrase'**
  String get assistantEditAddQuickPhraseButton;

  /// No description provided for @multiKeyPageDeleteSnackbarDeletedOne.
  ///
  /// In en, this message translates to:
  /// **'Deleted 1 key'**
  String get multiKeyPageDeleteSnackbarDeletedOne;

  /// No description provided for @multiKeyPageUndo.
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get multiKeyPageUndo;

  /// No description provided for @multiKeyPageUndoRestored.
  ///
  /// In en, this message translates to:
  /// **'Restored'**
  String get multiKeyPageUndoRestored;

  /// No description provided for @multiKeyPageDeleteErrorsTooltip.
  ///
  /// In en, this message translates to:
  /// **'Delete errors'**
  String get multiKeyPageDeleteErrorsTooltip;

  /// No description provided for @multiKeyPageDeleteErrorsConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete all error keys?'**
  String get multiKeyPageDeleteErrorsConfirmTitle;

  /// No description provided for @multiKeyPageDeleteErrorsConfirmContent.
  ///
  /// In en, this message translates to:
  /// **'This will remove all keys marked as error.'**
  String get multiKeyPageDeleteErrorsConfirmContent;

  /// No description provided for @multiKeyPageDeletedErrorsSnackbar.
  ///
  /// In en, this message translates to:
  /// **'Deleted {n} error keys'**
  String multiKeyPageDeletedErrorsSnackbar(int n);

  /// No description provided for @providerDetailPageProviderTypeTitle.
  ///
  /// In en, this message translates to:
  /// **'Provider Type'**
  String get providerDetailPageProviderTypeTitle;

  /// No description provided for @displaySettingsPageChatItemDisplayTitle.
  ///
  /// In en, this message translates to:
  /// **'Chat item display'**
  String get displaySettingsPageChatItemDisplayTitle;

  /// No description provided for @displaySettingsPageRenderingSettingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Rendering settings'**
  String get displaySettingsPageRenderingSettingsTitle;

  /// No description provided for @displaySettingsPageBehaviorStartupTitle.
  ///
  /// In en, this message translates to:
  /// **'Behavior & startup'**
  String get displaySettingsPageBehaviorStartupTitle;

  /// No description provided for @displaySettingsPageHapticsSettingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Haptics'**
  String get displaySettingsPageHapticsSettingsTitle;

  /// No description provided for @assistantSettingsNoPromptPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'No prompt yet'**
  String get assistantSettingsNoPromptPlaceholder;

  /// No description provided for @providersPageMultiSelectTooltip.
  ///
  /// In en, this message translates to:
  /// **'Multi-select'**
  String get providersPageMultiSelectTooltip;

  /// No description provided for @providersPageDeleteSelectedConfirmContent.
  ///
  /// In en, this message translates to:
  /// **'Delete selected providers? This cannot be undone.'**
  String get providersPageDeleteSelectedConfirmContent;

  /// No description provided for @providersPageDeleteSelectedSnackbar.
  ///
  /// In en, this message translates to:
  /// **'Deleted selected providers'**
  String get providersPageDeleteSelectedSnackbar;

  /// No description provided for @providersPageExportSelectedTitle.
  ///
  /// In en, this message translates to:
  /// **'Export {count} providers'**
  String providersPageExportSelectedTitle(int count);

  /// No description provided for @providersPageExportCopyButton.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get providersPageExportCopyButton;

  /// No description provided for @providersPageExportShareButton.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get providersPageExportShareButton;

  /// No description provided for @providersPageExportCopiedSnackbar.
  ///
  /// In en, this message translates to:
  /// **'Copied export code'**
  String get providersPageExportCopiedSnackbar;

  /// No description provided for @providersPageDeleteAction.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get providersPageDeleteAction;

  /// No description provided for @providersPageExportAction.
  ///
  /// In en, this message translates to:
  /// **'Export'**
  String get providersPageExportAction;

  /// No description provided for @assistantEditPresetTitle.
  ///
  /// In en, this message translates to:
  /// **'Preset conversation'**
  String get assistantEditPresetTitle;

  /// No description provided for @assistantEditPresetAddUser.
  ///
  /// In en, this message translates to:
  /// **'Add user preset'**
  String get assistantEditPresetAddUser;

  /// No description provided for @assistantEditPresetAddAssistant.
  ///
  /// In en, this message translates to:
  /// **'Add assistant preset'**
  String get assistantEditPresetAddAssistant;

  /// No description provided for @assistantEditPresetInputHintUser.
  ///
  /// In en, this message translates to:
  /// **'Enter user message…'**
  String get assistantEditPresetInputHintUser;

  /// No description provided for @assistantEditPresetInputHintAssistant.
  ///
  /// In en, this message translates to:
  /// **'Enter assistant message…'**
  String get assistantEditPresetInputHintAssistant;

  /// No description provided for @assistantEditPresetEmpty.
  ///
  /// In en, this message translates to:
  /// **'No preset messages yet'**
  String get assistantEditPresetEmpty;

  /// No description provided for @assistantEditPresetEditDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit preset message'**
  String get assistantEditPresetEditDialogTitle;

  /// No description provided for @assistantEditPresetRoleUser.
  ///
  /// In en, this message translates to:
  /// **'User'**
  String get assistantEditPresetRoleUser;

  /// No description provided for @assistantEditPresetRoleAssistant.
  ///
  /// In en, this message translates to:
  /// **'Assistant'**
  String get assistantEditPresetRoleAssistant;

  /// No description provided for @desktopTtsPleaseAddProvider.
  ///
  /// In en, this message translates to:
  /// **'Please add a TTS provider first'**
  String get desktopTtsPleaseAddProvider;

  /// No description provided for @settingsPageNetworkProxy.
  ///
  /// In en, this message translates to:
  /// **'Network Proxy'**
  String get settingsPageNetworkProxy;

  /// No description provided for @networkProxyEnableLabel.
  ///
  /// In en, this message translates to:
  /// **'Enable Proxy'**
  String get networkProxyEnableLabel;

  /// No description provided for @networkProxySettingsHeader.
  ///
  /// In en, this message translates to:
  /// **'Proxy Settings'**
  String get networkProxySettingsHeader;

  /// No description provided for @networkProxyType.
  ///
  /// In en, this message translates to:
  /// **'Proxy Type'**
  String get networkProxyType;

  /// No description provided for @networkProxyTypeHttp.
  ///
  /// In en, this message translates to:
  /// **'HTTP'**
  String get networkProxyTypeHttp;

  /// No description provided for @networkProxyTypeHttps.
  ///
  /// In en, this message translates to:
  /// **'HTTPS'**
  String get networkProxyTypeHttps;

  /// No description provided for @networkProxyTypeSocks5.
  ///
  /// In en, this message translates to:
  /// **'SOCKS5'**
  String get networkProxyTypeSocks5;

  /// No description provided for @networkProxyServerHost.
  ///
  /// In en, this message translates to:
  /// **'Server'**
  String get networkProxyServerHost;

  /// No description provided for @networkProxyPort.
  ///
  /// In en, this message translates to:
  /// **'Port'**
  String get networkProxyPort;

  /// No description provided for @networkProxyUsername.
  ///
  /// In en, this message translates to:
  /// **'Username'**
  String get networkProxyUsername;

  /// No description provided for @networkProxyPassword.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get networkProxyPassword;

  /// No description provided for @networkProxyBypassLabel.
  ///
  /// In en, this message translates to:
  /// **'Proxy bypass'**
  String get networkProxyBypassLabel;

  /// No description provided for @networkProxyBypassHint.
  ///
  /// In en, this message translates to:
  /// **'Comma-separated hosts/CIDR, e.g. localhost,127.0.0.1,192.168.0.0/16,*.local'**
  String get networkProxyBypassHint;

  /// No description provided for @networkProxyOptionalHint.
  ///
  /// In en, this message translates to:
  /// **'Optional'**
  String get networkProxyOptionalHint;

  /// No description provided for @networkProxyTestHeader.
  ///
  /// In en, this message translates to:
  /// **'Connection Test'**
  String get networkProxyTestHeader;

  /// No description provided for @networkProxyTestUrlHint.
  ///
  /// In en, this message translates to:
  /// **'Test URL'**
  String get networkProxyTestUrlHint;

  /// No description provided for @networkProxyTestButton.
  ///
  /// In en, this message translates to:
  /// **'Test'**
  String get networkProxyTestButton;

  /// No description provided for @networkProxyTesting.
  ///
  /// In en, this message translates to:
  /// **'Testing…'**
  String get networkProxyTesting;

  /// No description provided for @networkProxyTestSuccess.
  ///
  /// In en, this message translates to:
  /// **'Connection successful'**
  String get networkProxyTestSuccess;

  /// No description provided for @networkProxyTestFailed.
  ///
  /// In en, this message translates to:
  /// **'Test failed: {error}'**
  String networkProxyTestFailed(String error);

  /// No description provided for @networkProxyNoUrl.
  ///
  /// In en, this message translates to:
  /// **'Please enter a URL'**
  String get networkProxyNoUrl;

  /// No description provided for @networkProxyPriorityNote.
  ///
  /// In en, this message translates to:
  /// **'When both global and provider proxies are enabled, provider-level proxy takes priority.'**
  String get networkProxyPriorityNote;

  /// No description provided for @settingsPageAutoRetry.
  ///
  /// In en, this message translates to:
  /// **'Auto Retry'**
  String get settingsPageAutoRetry;

  /// No description provided for @autoRetryEnableLabel.
  ///
  /// In en, this message translates to:
  /// **'Enable auto-retry'**
  String get autoRetryEnableLabel;

  /// No description provided for @autoRetryMaxRetries.
  ///
  /// In en, this message translates to:
  /// **'Max retries'**
  String get autoRetryMaxRetries;

  /// No description provided for @autoRetryInitialDelay.
  ///
  /// In en, this message translates to:
  /// **'Initial delay (ms)'**
  String get autoRetryInitialDelay;

  /// No description provided for @autoRetryMultiplier.
  ///
  /// In en, this message translates to:
  /// **'Backoff multiplier'**
  String get autoRetryMultiplier;

  /// No description provided for @autoRetryMaxDelay.
  ///
  /// In en, this message translates to:
  /// **'Max delay (ms)'**
  String get autoRetryMaxDelay;

  /// No description provided for @autoRetryJitter.
  ///
  /// In en, this message translates to:
  /// **'Jitter'**
  String get autoRetryJitter;

  /// No description provided for @autoRetryJitterSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Randomize each wait by ±20%'**
  String get autoRetryJitterSubtitle;

  /// No description provided for @autoRetryOnNetworkError.
  ///
  /// In en, this message translates to:
  /// **'Retry on network errors'**
  String get autoRetryOnNetworkError;

  /// No description provided for @autoRetryStatusCodes.
  ///
  /// In en, this message translates to:
  /// **'Retry status codes'**
  String get autoRetryStatusCodes;

  /// No description provided for @autoRetryKeywords.
  ///
  /// In en, this message translates to:
  /// **'Retry keywords'**
  String get autoRetryKeywords;

  /// No description provided for @autoRetryStopKeywords.
  ///
  /// In en, this message translates to:
  /// **'Stop keywords'**
  String get autoRetryStopKeywords;

  /// No description provided for @autoRetryAddHint.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get autoRetryAddHint;

  /// No description provided for @autoRetryRestoreDefaults.
  ///
  /// In en, this message translates to:
  /// **'Restore defaults'**
  String get autoRetryRestoreDefaults;

  /// No description provided for @autoRetryFooter.
  ///
  /// In en, this message translates to:
  /// **'Auto-retry only runs if this request has not produced any output yet.'**
  String get autoRetryFooter;

  /// No description provided for @autoRetryCountdown.
  ///
  /// In en, this message translates to:
  /// **'{seconds}s until retry ({attempt}/{maxRetries})'**
  String autoRetryCountdown(int seconds, int attempt, int maxRetries);

  /// No description provided for @desktopShowProviderInModelCapsule.
  ///
  /// In en, this message translates to:
  /// **'Show provider in model capsule'**
  String get desktopShowProviderInModelCapsule;

  /// No description provided for @messageWebViewOpenInBrowser.
  ///
  /// In en, this message translates to:
  /// **'Open in Browser'**
  String get messageWebViewOpenInBrowser;

  /// No description provided for @messageWebViewConsoleLogs.
  ///
  /// In en, this message translates to:
  /// **'Console Logs'**
  String get messageWebViewConsoleLogs;

  /// No description provided for @messageWebViewNoConsoleMessages.
  ///
  /// In en, this message translates to:
  /// **'No console messages'**
  String get messageWebViewNoConsoleMessages;

  /// No description provided for @messageWebViewRefreshTooltip.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get messageWebViewRefreshTooltip;

  /// No description provided for @messageWebViewForwardTooltip.
  ///
  /// In en, this message translates to:
  /// **'Forward'**
  String get messageWebViewForwardTooltip;

  /// No description provided for @chatInputBarOcrTooltip.
  ///
  /// In en, this message translates to:
  /// **'Image OCR'**
  String get chatInputBarOcrTooltip;

  /// No description provided for @providerDetailPageMultiSelectButton.
  ///
  /// In en, this message translates to:
  /// **'Multi-select'**
  String get providerDetailPageMultiSelectButton;

  /// No description provided for @providerDetailPageBatchDetectButton.
  ///
  /// In en, this message translates to:
  /// **'Detect'**
  String get providerDetailPageBatchDetectButton;

  /// No description provided for @providerDetailPageBatchDetecting.
  ///
  /// In en, this message translates to:
  /// **'Detecting...'**
  String get providerDetailPageBatchDetecting;

  /// No description provided for @providerDetailPageBatchDetectStart.
  ///
  /// In en, this message translates to:
  /// **'Start Detection'**
  String get providerDetailPageBatchDetectStart;

  /// No description provided for @providerDetailPageDetectSuccess.
  ///
  /// In en, this message translates to:
  /// **'Detection successful'**
  String get providerDetailPageDetectSuccess;

  /// No description provided for @providerDetailPageDetectFailed.
  ///
  /// In en, this message translates to:
  /// **'Detection failed'**
  String get providerDetailPageDetectFailed;

  /// No description provided for @providerDetailPageDeleteSelectedModelsButton.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get providerDetailPageDeleteSelectedModelsButton;

  /// No description provided for @providerDetailPageDeleteSelectedModelsTooltip.
  ///
  /// In en, this message translates to:
  /// **'Delete selected models'**
  String get providerDetailPageDeleteSelectedModelsTooltip;

  /// No description provided for @providerDetailPageDeleteSelectedModelsConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete {count} selected model(s)? This cannot be undone.'**
  String providerDetailPageDeleteSelectedModelsConfirm(int count);

  /// No description provided for @providerDetailPageDeleteFailedDetectedModelsButton.
  ///
  /// In en, this message translates to:
  /// **'Delete unavailable'**
  String get providerDetailPageDeleteFailedDetectedModelsButton;

  /// No description provided for @providerDetailPageDeleteFailedDetectedModelsTooltip.
  ///
  /// In en, this message translates to:
  /// **'Delete models that failed detection'**
  String get providerDetailPageDeleteFailedDetectedModelsTooltip;

  /// No description provided for @providerDetailPageDeleteFailedDetectedModelsConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete {count} model(s) that failed detection? This cannot be undone.'**
  String providerDetailPageDeleteFailedDetectedModelsConfirm(int count);

  /// No description provided for @providerDetailPageSelectedModelsDeletedSnackbar.
  ///
  /// In en, this message translates to:
  /// **'Deleted {count} model(s)'**
  String providerDetailPageSelectedModelsDeletedSnackbar(int count);

  /// No description provided for @providerDetailPageDeleteAllModelsTooltip.
  ///
  /// In en, this message translates to:
  /// **'Delete all models'**
  String get providerDetailPageDeleteAllModelsTooltip;

  /// No description provided for @providerDetailPageDeleteAllModelsWarning.
  ///
  /// In en, this message translates to:
  /// **'This action cannot be undone.'**
  String get providerDetailPageDeleteAllModelsWarning;

  /// No description provided for @requestLogSettingTitle.
  ///
  /// In en, this message translates to:
  /// **'Request Logging'**
  String get requestLogSettingTitle;

  /// No description provided for @requestLogSettingSubtitle.
  ///
  /// In en, this message translates to:
  /// **'When enabled, request/response details are written to logs/logs.txt (rotated daily).'**
  String get requestLogSettingSubtitle;

  /// No description provided for @flutterLogSettingTitle.
  ///
  /// In en, this message translates to:
  /// **'Flutter Logging'**
  String get flutterLogSettingTitle;

  /// No description provided for @flutterLogSettingSubtitle.
  ///
  /// In en, this message translates to:
  /// **'When enabled, Flutter errors and print output are written to logs/flutter_logs.txt (rotated daily).'**
  String get flutterLogSettingSubtitle;

  /// No description provided for @contextLogSettingTitle.
  ///
  /// In en, this message translates to:
  /// **'Context Logging'**
  String get contextLogSettingTitle;

  /// No description provided for @contextLogSettingSubtitle.
  ///
  /// In en, this message translates to:
  /// **'When enabled, the exact messages sent to the model are written to logs/context_logs.txt (rotated daily).'**
  String get contextLogSettingSubtitle;

  /// No description provided for @contextLogViewerTitle.
  ///
  /// In en, this message translates to:
  /// **'Context'**
  String get contextLogViewerTitle;

  /// No description provided for @contextLogSnapshotMessages.
  ///
  /// In en, this message translates to:
  /// **'{count} messages'**
  String contextLogSnapshotMessages(int count);

  /// No description provided for @contextLogSnapshotTokens.
  ///
  /// In en, this message translates to:
  /// **'{count} tokens'**
  String contextLogSnapshotTokens(int count);

  /// No description provided for @contextLogSourceSystemPrompt.
  ///
  /// In en, this message translates to:
  /// **'System prompt'**
  String get contextLogSourceSystemPrompt;

  /// No description provided for @contextLogSourceMemoryRules.
  ///
  /// In en, this message translates to:
  /// **'Memory rules'**
  String get contextLogSourceMemoryRules;

  /// No description provided for @contextLogSourceSearchPrompt.
  ///
  /// In en, this message translates to:
  /// **'Search prompt'**
  String get contextLogSourceSearchPrompt;

  /// No description provided for @contextLogSourceInstructionInjection.
  ///
  /// In en, this message translates to:
  /// **'Instruction'**
  String get contextLogSourceInstructionInjection;

  /// No description provided for @contextLogSourceWorldBook.
  ///
  /// In en, this message translates to:
  /// **'World book'**
  String get contextLogSourceWorldBook;

  /// No description provided for @contextLogSourceMemorySnapshot.
  ///
  /// In en, this message translates to:
  /// **'Memory snapshot'**
  String get contextLogSourceMemorySnapshot;

  /// No description provided for @contextLogSourceChatHistory.
  ///
  /// In en, this message translates to:
  /// **'Chat history'**
  String get contextLogSourceChatHistory;

  /// No description provided for @contextLogSourceToolCall.
  ///
  /// In en, this message translates to:
  /// **'Tool call'**
  String get contextLogSourceToolCall;

  /// No description provided for @contextLogSourceToolResult.
  ///
  /// In en, this message translates to:
  /// **'Tool result'**
  String get contextLogSourceToolResult;

  /// No description provided for @contextLogTokensEstimateHint.
  ///
  /// In en, this message translates to:
  /// **'Token counts are estimates only; use the model\'s actual usage as the source of truth.'**
  String get contextLogTokensEstimateHint;

  /// No description provided for @contextLogSnapshotsCount.
  ///
  /// In en, this message translates to:
  /// **'{count} snapshots'**
  String contextLogSnapshotsCount(int count);

  /// No description provided for @contextLogSnapshotFallbackTitle.
  ///
  /// In en, this message translates to:
  /// **'Snapshot'**
  String get contextLogSnapshotFallbackTitle;

  /// No description provided for @contextLogKindFull.
  ///
  /// In en, this message translates to:
  /// **'Full snapshot'**
  String get contextLogKindFull;

  /// No description provided for @contextLogKindUpdate.
  ///
  /// In en, this message translates to:
  /// **'Incremental update'**
  String get contextLogKindUpdate;

  /// No description provided for @contextLogSectionComposition.
  ///
  /// In en, this message translates to:
  /// **'Composition'**
  String get contextLogSectionComposition;

  /// No description provided for @contextLogLoadOlder.
  ///
  /// In en, this message translates to:
  /// **'Load earlier logs'**
  String get contextLogLoadOlder;

  /// No description provided for @contextLogLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading...'**
  String get contextLogLoading;

  /// No description provided for @contextLogAllLoaded.
  ///
  /// In en, this message translates to:
  /// **'All logs loaded'**
  String get contextLogAllLoaded;

  /// No description provided for @logViewerTitle.
  ///
  /// In en, this message translates to:
  /// **'Request Logs'**
  String get logViewerTitle;

  /// No description provided for @logViewerEmpty.
  ///
  /// In en, this message translates to:
  /// **'No logs yet'**
  String get logViewerEmpty;

  /// No description provided for @logViewerCurrentLog.
  ///
  /// In en, this message translates to:
  /// **'Current Log'**
  String get logViewerCurrentLog;

  /// No description provided for @logViewerExport.
  ///
  /// In en, this message translates to:
  /// **'Export'**
  String get logViewerExport;

  /// No description provided for @logViewerOpenFolder.
  ///
  /// In en, this message translates to:
  /// **'Open Logs Folder'**
  String get logViewerOpenFolder;

  /// No description provided for @logViewerRequestsCount.
  ///
  /// In en, this message translates to:
  /// **'{count} requests'**
  String logViewerRequestsCount(int count);

  /// No description provided for @logViewerFieldId.
  ///
  /// In en, this message translates to:
  /// **'ID'**
  String get logViewerFieldId;

  /// No description provided for @logViewerFieldMethod.
  ///
  /// In en, this message translates to:
  /// **'Method'**
  String get logViewerFieldMethod;

  /// No description provided for @logViewerFieldStatus.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get logViewerFieldStatus;

  /// No description provided for @logViewerFieldStarted.
  ///
  /// In en, this message translates to:
  /// **'Started'**
  String get logViewerFieldStarted;

  /// No description provided for @logViewerFieldEnded.
  ///
  /// In en, this message translates to:
  /// **'Ended'**
  String get logViewerFieldEnded;

  /// No description provided for @logViewerFieldDuration.
  ///
  /// In en, this message translates to:
  /// **'Duration'**
  String get logViewerFieldDuration;

  /// No description provided for @logViewerSectionSummary.
  ///
  /// In en, this message translates to:
  /// **'Summary'**
  String get logViewerSectionSummary;

  /// No description provided for @logViewerSectionParameters.
  ///
  /// In en, this message translates to:
  /// **'Parameters'**
  String get logViewerSectionParameters;

  /// No description provided for @logViewerSectionRequestHeaders.
  ///
  /// In en, this message translates to:
  /// **'Request Headers'**
  String get logViewerSectionRequestHeaders;

  /// No description provided for @logViewerSectionRequestBody.
  ///
  /// In en, this message translates to:
  /// **'Request Body'**
  String get logViewerSectionRequestBody;

  /// No description provided for @logViewerSectionResponseHeaders.
  ///
  /// In en, this message translates to:
  /// **'Response Headers'**
  String get logViewerSectionResponseHeaders;

  /// No description provided for @logViewerSectionResponseBody.
  ///
  /// In en, this message translates to:
  /// **'Response Body'**
  String get logViewerSectionResponseBody;

  /// No description provided for @logViewerSectionWarnings.
  ///
  /// In en, this message translates to:
  /// **'Warnings'**
  String get logViewerSectionWarnings;

  /// No description provided for @logViewerErrorTitle.
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get logViewerErrorTitle;

  /// No description provided for @logViewerMoreCount.
  ///
  /// In en, this message translates to:
  /// **'+{count} more'**
  String logViewerMoreCount(int count);

  /// No description provided for @logViewerSectionAttachments.
  ///
  /// In en, this message translates to:
  /// **'Attachments'**
  String get logViewerSectionAttachments;

  /// No description provided for @logViewerPayloadOmitted.
  ///
  /// In en, this message translates to:
  /// **'omitted'**
  String get logViewerPayloadOmitted;

  /// No description provided for @logViewerShowMore.
  ///
  /// In en, this message translates to:
  /// **'Show more'**
  String get logViewerShowMore;

  /// No description provided for @logSettingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Log Settings'**
  String get logSettingsTitle;

  /// No description provided for @logSettingsSaveOutput.
  ///
  /// In en, this message translates to:
  /// **'Save Response Output'**
  String get logSettingsSaveOutput;

  /// No description provided for @logSettingsSaveOutputSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Log every streaming chunk (can slow generation). HTTP error bodies are always recorded.'**
  String get logSettingsSaveOutputSubtitle;

  /// No description provided for @logSettingsElidePayloads.
  ///
  /// In en, this message translates to:
  /// **'Omit Large Payloads'**
  String get logSettingsElidePayloads;

  /// No description provided for @logSettingsElidePayloadsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Replace inline base64 images and files with a placeholder. Keeps logs small and the viewer fast.'**
  String get logSettingsElidePayloadsSubtitle;

  /// No description provided for @logSettingsAutoDelete.
  ///
  /// In en, this message translates to:
  /// **'Auto-delete'**
  String get logSettingsAutoDelete;

  /// No description provided for @logSettingsAutoDeleteSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Delete logs older than specified days'**
  String get logSettingsAutoDeleteSubtitle;

  /// No description provided for @logSettingsAutoDeleteDisabled.
  ///
  /// In en, this message translates to:
  /// **'Disabled'**
  String get logSettingsAutoDeleteDisabled;

  /// No description provided for @logSettingsAutoDeleteDays.
  ///
  /// In en, this message translates to:
  /// **'{count} days'**
  String logSettingsAutoDeleteDays(int count);

  /// No description provided for @logSettingsMaxSize.
  ///
  /// In en, this message translates to:
  /// **'Max Log Size'**
  String get logSettingsMaxSize;

  /// No description provided for @logSettingsMaxSizeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Oldest logs deleted when exceeded'**
  String get logSettingsMaxSizeSubtitle;

  /// No description provided for @logSettingsMaxSizeUnlimited.
  ///
  /// In en, this message translates to:
  /// **'Unlimited'**
  String get logSettingsMaxSizeUnlimited;

  /// No description provided for @assistantEditManageSummariesTitle.
  ///
  /// In en, this message translates to:
  /// **'Manage Summaries'**
  String get assistantEditManageSummariesTitle;

  /// No description provided for @assistantEditSummaryEmpty.
  ///
  /// In en, this message translates to:
  /// **'No summaries yet'**
  String get assistantEditSummaryEmpty;

  /// No description provided for @assistantEditSummaryDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit Summary'**
  String get assistantEditSummaryDialogTitle;

  /// No description provided for @assistantEditSummaryDialogHint.
  ///
  /// In en, this message translates to:
  /// **'Enter summary content'**
  String get assistantEditSummaryDialogHint;

  /// No description provided for @assistantEditDeleteSummaryTitle.
  ///
  /// In en, this message translates to:
  /// **'Clear Summary'**
  String get assistantEditDeleteSummaryTitle;

  /// No description provided for @assistantEditDeleteSummaryContent.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to clear this summary?'**
  String get assistantEditDeleteSummaryContent;

  /// No description provided for @homePageProcessingFiles.
  ///
  /// In en, this message translates to:
  /// **'Processing files...'**
  String get homePageProcessingFiles;

  /// No description provided for @settingsPageWorldBook.
  ///
  /// In en, this message translates to:
  /// **'World Book'**
  String get settingsPageWorldBook;

  /// No description provided for @settingsPageMemory.
  ///
  /// In en, this message translates to:
  /// **'Memory'**
  String get settingsPageMemory;

  /// No description provided for @memorySettingsPageTitle.
  ///
  /// In en, this message translates to:
  /// **'Memory'**
  String get memorySettingsPageTitle;

  /// No description provided for @memorySettingsGlobalSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Memory mode, model, and prompts'**
  String get memorySettingsGlobalSubtitle;

  /// No description provided for @memorySettingsModeSection.
  ///
  /// In en, this message translates to:
  /// **'Memory mode'**
  String get memorySettingsModeSection;

  /// No description provided for @memorySettingsModelSection.
  ///
  /// In en, this message translates to:
  /// **'Memory model'**
  String get memorySettingsModelSection;

  /// No description provided for @memorySettingsModelTitle.
  ///
  /// In en, this message translates to:
  /// **'Processing model'**
  String get memorySettingsModelTitle;

  /// No description provided for @memorySettingsModelUnset.
  ///
  /// In en, this message translates to:
  /// **'Not selected'**
  String get memorySettingsModelUnset;

  /// No description provided for @memorySettingsModelTip.
  ///
  /// In en, this message translates to:
  /// **'After Auto-organize memory is enabled, this model is called frequently in the background. Prefer a cheap, fast model.'**
  String get memorySettingsModelTip;

  /// No description provided for @memorySettingsAboutTitle.
  ///
  /// In en, this message translates to:
  /// **'About memory'**
  String get memorySettingsAboutTitle;

  /// No description provided for @memorySettingsAboutSubtitle.
  ///
  /// In en, this message translates to:
  /// **'How memory works and when it runs'**
  String get memorySettingsAboutSubtitle;

  /// No description provided for @memoryAboutQuickstartTitle.
  ///
  /// In en, this message translates to:
  /// **'Get started'**
  String get memoryAboutQuickstartTitle;

  /// No description provided for @memoryAboutQuickstartBody.
  ///
  /// In en, this message translates to:
  /// **'1. In Settings → Memory, choose a processing model.\n2. On the assistant Memory tab, turn on long-term memory and Auto-organize.\n3. Chat for a few turns or tap Organize, then open All memories to see what was saved.'**
  String get memoryAboutQuickstartBody;

  /// No description provided for @memoryAboutTypesTitle.
  ///
  /// In en, this message translates to:
  /// **'Memory types'**
  String get memoryAboutTypesTitle;

  /// No description provided for @memoryAboutTypesBody.
  ///
  /// In en, this message translates to:
  /// **'Identity: stable facts about the user, such as how to address them, role, language, and long-term preferences. Write complete third-person statements.\n\nWorkflow: how they like to get work done — tools, formats, and review habits.\n\nVoice: how they want the assistant to sound — tone, length, and language style.\n\nInstruction: standing rules the assistant should follow, not one-off tasks from this chat.'**
  String get memoryAboutTypesBody;

  /// No description provided for @memoryAboutScopeTitle.
  ///
  /// In en, this message translates to:
  /// **'Global vs assistant'**
  String get memoryAboutScopeTitle;

  /// No description provided for @memoryAboutScopeBody.
  ///
  /// In en, this message translates to:
  /// **'Global memories are injected for every assistant. Assistant-scope memories are only visible to that assistant. Use global for facts that should follow the user everywhere; use assistant scope for rules or context that belong to one persona.'**
  String get memoryAboutScopeBody;

  /// No description provided for @memoryAboutInjectionTitle.
  ///
  /// In en, this message translates to:
  /// **'How memories are injected'**
  String get memoryAboutInjectionTitle;

  /// No description provided for @memoryAboutInjectionBody.
  ///
  /// In en, this message translates to:
  /// **'At the start of a chat, the newest items of each type are placed in the model context. If a type exceeds the injection limit, the block is marked mode=\"summary\" with total and shown counts; the rest can be fetched with memory_search_profile. Raise the limit in Settings → Memory for more completeness at a higher token cost.'**
  String get memoryAboutInjectionBody;

  /// No description provided for @memoryAboutPipelineTitle.
  ///
  /// In en, this message translates to:
  /// **'Background pipeline'**
  String get memoryAboutPipelineTitle;

  /// No description provided for @memoryAboutPipelineBody.
  ///
  /// In en, this message translates to:
  /// **'Auto-organize runs after chats: decide whether anything is worth remembering, extract candidates, dedupe and merge, then distill identity items into the user profile when needed. You can also tap Organize on the assistant Memory tab. That is why the processing model is called often.'**
  String get memoryAboutPipelineBody;

  /// No description provided for @memoryAboutCacheTitle.
  ///
  /// In en, this message translates to:
  /// **'Keep caching healthy'**
  String get memoryAboutCacheTitle;

  /// No description provided for @memoryAboutCacheBody.
  ///
  /// In en, this message translates to:
  /// **'The injected memory prefix is kept stable so unchanged chats can reuse the prompt cache, lowering cost and latency. Avoid pointless bulk edits or reshuffles. Day-to-day single-entry edits usually have limited impact.'**
  String get memoryAboutCacheBody;

  /// No description provided for @memoryAboutFaqTitle.
  ///
  /// In en, this message translates to:
  /// **'FAQ'**
  String get memoryAboutFaqTitle;

  /// No description provided for @memoryAboutFaqWhyNotRememberedTitle.
  ///
  /// In en, this message translates to:
  /// **'Why wasn\'t this remembered?'**
  String get memoryAboutFaqWhyNotRememberedTitle;

  /// No description provided for @memoryAboutFaqWhyNotRememberedBody.
  ///
  /// In en, this message translates to:
  /// **'Organize is skipped when there are not enough new messages to organize, no new messages to organize, or no memory processing model selected. Temporary chats are not saved to memory. You can also turn memory or Auto-organize off per assistant.'**
  String get memoryAboutFaqWhyNotRememberedBody;

  /// No description provided for @memorySettingsThinkingTitle.
  ///
  /// In en, this message translates to:
  /// **'Enable thinking'**
  String get memorySettingsThinkingTitle;

  /// No description provided for @memorySettingsThinkingSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Allow the memory model to use reasoning when supported'**
  String get memorySettingsThinkingSubtitle;

  /// No description provided for @memorySettingsInjectionSection.
  ///
  /// In en, this message translates to:
  /// **'Memory injection'**
  String get memorySettingsInjectionSection;

  /// No description provided for @memorySettingsInjectionMaxItemsTitle.
  ///
  /// In en, this message translates to:
  /// **'Items injected per type'**
  String get memorySettingsInjectionMaxItemsTitle;

  /// No description provided for @memorySettingsInjectionMaxItemsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'When a type exceeds this limit, only the newest items are injected. The rest can be fetched with memory_search_profile. A larger number is more complete but uses more tokens. If you customized the rules prompt, update it or restore the default.'**
  String get memorySettingsInjectionMaxItemsSubtitle;

  /// No description provided for @memorySettingsInjectionMaxItemsOption.
  ///
  /// In en, this message translates to:
  /// **'{n}'**
  String memorySettingsInjectionMaxItemsOption(int n);

  /// No description provided for @memorySettingsInjectionMaxItemsCustomButton.
  ///
  /// In en, this message translates to:
  /// **'Custom'**
  String get memorySettingsInjectionMaxItemsCustomButton;

  /// No description provided for @memorySettingsInjectionMaxItemsCustomTitle.
  ///
  /// In en, this message translates to:
  /// **'Custom injection count'**
  String get memorySettingsInjectionMaxItemsCustomTitle;

  /// No description provided for @memorySettingsInjectionMaxItemsCustomDescription.
  ///
  /// In en, this message translates to:
  /// **'Enter a number between 1 and 100.'**
  String get memorySettingsInjectionMaxItemsCustomDescription;

  /// No description provided for @memorySettingsInjectionMaxItemsCustomLabel.
  ///
  /// In en, this message translates to:
  /// **'Count'**
  String get memorySettingsInjectionMaxItemsCustomLabel;

  /// No description provided for @memorySettingsInjectionMaxItemsCustomHint.
  ///
  /// In en, this message translates to:
  /// **'1–100'**
  String get memorySettingsInjectionMaxItemsCustomHint;

  /// No description provided for @memorySettingsInjectionMaxItemsCustomInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter a number between 1 and 100'**
  String get memorySettingsInjectionMaxItemsCustomInvalid;

  /// No description provided for @memorySettingsPromptLangSection.
  ///
  /// In en, this message translates to:
  /// **'Prompt language'**
  String get memorySettingsPromptLangSection;

  /// No description provided for @memorySettingsPromptLangAuto.
  ///
  /// In en, this message translates to:
  /// **'Auto'**
  String get memorySettingsPromptLangAuto;

  /// No description provided for @memorySettingsPromptLangAutoSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Follow the UI language (Chinese → zh, otherwise en)'**
  String get memorySettingsPromptLangAutoSubtitle;

  /// No description provided for @memorySettingsPromptLangZh.
  ///
  /// In en, this message translates to:
  /// **'Chinese'**
  String get memorySettingsPromptLangZh;

  /// No description provided for @memorySettingsPromptLangZhSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Always use Chinese memory prompts and tool descriptions'**
  String get memorySettingsPromptLangZhSubtitle;

  /// No description provided for @memorySettingsPromptLangEn.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get memorySettingsPromptLangEn;

  /// No description provided for @memorySettingsPromptLangEnSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Always use English memory prompts and tool descriptions'**
  String get memorySettingsPromptLangEnSubtitle;

  /// No description provided for @memorySettingsPromptsSection.
  ///
  /// In en, this message translates to:
  /// **'Prompt templates'**
  String get memorySettingsPromptsSection;

  /// No description provided for @memorySettingsLegacyPromptTitle.
  ///
  /// In en, this message translates to:
  /// **'Legacy memory rules'**
  String get memorySettingsLegacyPromptTitle;

  /// No description provided for @memoryPromptEditRulesTitle.
  ///
  /// In en, this message translates to:
  /// **'Memory rules'**
  String get memoryPromptEditRulesTitle;

  /// No description provided for @memoryPromptEditRulesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Injected into the main chat system prompt'**
  String get memoryPromptEditRulesSubtitle;

  /// No description provided for @memoryPromptEditGateTitle.
  ///
  /// In en, this message translates to:
  /// **'Gatekeeper'**
  String get memoryPromptEditGateTitle;

  /// No description provided for @memoryPromptEditGateSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Decides whether a turn is worth remembering'**
  String get memoryPromptEditGateSubtitle;

  /// No description provided for @memoryPromptEditExtractTitle.
  ///
  /// In en, this message translates to:
  /// **'Extract'**
  String get memoryPromptEditExtractTitle;

  /// No description provided for @memoryPromptEditExtractSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Extracts candidate memory items from a conversation'**
  String get memoryPromptEditExtractSubtitle;

  /// No description provided for @memoryPromptEditSmartAddTitle.
  ///
  /// In en, this message translates to:
  /// **'Smart Add'**
  String get memoryPromptEditSmartAddTitle;

  /// No description provided for @memoryPromptEditSmartAddSubtitle.
  ///
  /// In en, this message translates to:
  /// **'NEW / MERGE / CONFLICT / SKIP dedupe judge'**
  String get memoryPromptEditSmartAddSubtitle;

  /// No description provided for @memoryPromptEditDistillTitle.
  ///
  /// In en, this message translates to:
  /// **'Profile Distiller'**
  String get memoryPromptEditDistillTitle;

  /// No description provided for @memoryPromptEditDistillSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Distills identity memories into profile fields'**
  String get memoryPromptEditDistillSubtitle;

  /// No description provided for @memoryPromptEditMigrateTitle.
  ///
  /// In en, this message translates to:
  /// **'Legacy migration'**
  String get memoryPromptEditMigrateTitle;

  /// No description provided for @memoryPromptEditMigrateSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Used when migration rewrites memory wording'**
  String get memoryPromptEditMigrateSubtitle;

  /// No description provided for @memoryPromptEditReset.
  ///
  /// In en, this message translates to:
  /// **'Reset to default'**
  String get memoryPromptEditReset;

  /// No description provided for @memoryPromptEditSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get memoryPromptEditSave;

  /// No description provided for @memoryPromptEditSectionPerItem.
  ///
  /// In en, this message translates to:
  /// **'Per-item prompt'**
  String get memoryPromptEditSectionPerItem;

  /// No description provided for @memoryPromptEditSectionBatch.
  ///
  /// In en, this message translates to:
  /// **'Batched prompt'**
  String get memoryPromptEditSectionBatch;

  /// No description provided for @memorySettingsEntriesSection.
  ///
  /// In en, this message translates to:
  /// **'All memories'**
  String get memorySettingsEntriesSection;

  /// No description provided for @memorySettingsLegacySection.
  ///
  /// In en, this message translates to:
  /// **'Legacy memory'**
  String get memorySettingsLegacySection;

  /// No description provided for @memorySettingsEntriesTitle.
  ///
  /// In en, this message translates to:
  /// **'Memory list'**
  String get memorySettingsEntriesTitle;

  /// No description provided for @memorySettingsEntriesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Browse, edit, archive, and delete memories'**
  String get memorySettingsEntriesSubtitle;

  /// No description provided for @memorySettingsProfileTitle.
  ///
  /// In en, this message translates to:
  /// **'User profile'**
  String get memorySettingsProfileTitle;

  /// No description provided for @memorySettingsProfileSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Structured identity fields for the model'**
  String get memorySettingsProfileSubtitle;

  /// No description provided for @memorySettingsLegacyTitle.
  ///
  /// In en, this message translates to:
  /// **'Legacy memories (read-only)'**
  String get memorySettingsLegacyTitle;

  /// No description provided for @memorySettingsLegacySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Old memories from previous versions'**
  String get memorySettingsLegacySubtitle;

  /// No description provided for @memoryEntryTypeIdentity.
  ///
  /// In en, this message translates to:
  /// **'Identity'**
  String get memoryEntryTypeIdentity;

  /// No description provided for @memoryEntryTypeWorkflow.
  ///
  /// In en, this message translates to:
  /// **'Workflow'**
  String get memoryEntryTypeWorkflow;

  /// No description provided for @memoryEntryTypeVoice.
  ///
  /// In en, this message translates to:
  /// **'Voice'**
  String get memoryEntryTypeVoice;

  /// No description provided for @memoryEntryTypeInstruction.
  ///
  /// In en, this message translates to:
  /// **'Instruction'**
  String get memoryEntryTypeInstruction;

  /// No description provided for @memoryEntryScopeGlobal.
  ///
  /// In en, this message translates to:
  /// **'Global'**
  String get memoryEntryScopeGlobal;

  /// No description provided for @memoryEntryScopeAssistant.
  ///
  /// In en, this message translates to:
  /// **'This assistant'**
  String get memoryEntryScopeAssistant;

  /// No description provided for @memoryEntryScopeAssistantNamed.
  ///
  /// In en, this message translates to:
  /// **'{name}'**
  String memoryEntryScopeAssistantNamed(String name);

  /// No description provided for @memoryEntrySourceManual.
  ///
  /// In en, this message translates to:
  /// **'Manual'**
  String get memoryEntrySourceManual;

  /// No description provided for @memoryEntrySourceTool.
  ///
  /// In en, this message translates to:
  /// **'Tool'**
  String get memoryEntrySourceTool;

  /// No description provided for @memoryEntrySourceExtracted.
  ///
  /// In en, this message translates to:
  /// **'Extracted'**
  String get memoryEntrySourceExtracted;

  /// No description provided for @memoryEntrySourceDistilled.
  ///
  /// In en, this message translates to:
  /// **'Distilled'**
  String get memoryEntrySourceDistilled;

  /// No description provided for @memoryEntryStatusActive.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get memoryEntryStatusActive;

  /// No description provided for @memoryEntryStatusArchived.
  ///
  /// In en, this message translates to:
  /// **'Archived'**
  String get memoryEntryStatusArchived;

  /// No description provided for @memoryEntryUpdatedAt.
  ///
  /// In en, this message translates to:
  /// **'Updated {date}'**
  String memoryEntryUpdatedAt(String date);

  /// No description provided for @memoryEntryActionEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get memoryEntryActionEdit;

  /// No description provided for @memoryEntryActionDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get memoryEntryActionDelete;

  /// No description provided for @memoryEntryActionArchive.
  ///
  /// In en, this message translates to:
  /// **'Archive'**
  String get memoryEntryActionArchive;

  /// No description provided for @memoryEntryActionRestore.
  ///
  /// In en, this message translates to:
  /// **'Restore'**
  String get memoryEntryActionRestore;

  /// No description provided for @memoryEntryActionSwitchScope.
  ///
  /// In en, this message translates to:
  /// **'Change scope'**
  String get memoryEntryActionSwitchScope;

  /// No description provided for @memoryEntryActionBatchDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete selected'**
  String get memoryEntryActionBatchDelete;

  /// No description provided for @memoryEntryActionAdd.
  ///
  /// In en, this message translates to:
  /// **'Add memory'**
  String get memoryEntryActionAdd;

  /// No description provided for @memoryEntryDeleteConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete memory?'**
  String get memoryEntryDeleteConfirmTitle;

  /// No description provided for @memoryEntryDeleteConfirmContent.
  ///
  /// In en, this message translates to:
  /// **'This permanently deletes the memory. This cannot be undone.'**
  String get memoryEntryDeleteConfirmContent;

  /// No description provided for @memoryEntryBatchDeleteConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete {count} memories?'**
  String memoryEntryBatchDeleteConfirmTitle(int count);

  /// No description provided for @memoryEntryBatchDeleteConfirmContent.
  ///
  /// In en, this message translates to:
  /// **'Selected memories will be permanently deleted.'**
  String get memoryEntryBatchDeleteConfirmContent;

  /// No description provided for @memoryEntrySwitchScopeConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Change memory scope?'**
  String get memoryEntrySwitchScopeConfirmTitle;

  /// No description provided for @memoryEntrySwitchScopeToGlobal.
  ///
  /// In en, this message translates to:
  /// **'Make this memory global (shared across assistants)?'**
  String get memoryEntrySwitchScopeToGlobal;

  /// No description provided for @memoryEntrySwitchScopeToAssistant.
  ///
  /// In en, this message translates to:
  /// **'Limit this memory to the current assistant?'**
  String get memoryEntrySwitchScopeToAssistant;

  /// No description provided for @memoryEntryArchivedSection.
  ///
  /// In en, this message translates to:
  /// **'Archived'**
  String get memoryEntryArchivedSection;

  /// No description provided for @memoryEntryEmpty.
  ///
  /// In en, this message translates to:
  /// **'No memories yet'**
  String get memoryEntryEmpty;

  /// No description provided for @memoryEntryEmptyDisabled.
  ///
  /// In en, this message translates to:
  /// **'Long-term memory is off for this assistant'**
  String get memoryEntryEmptyDisabled;

  /// No description provided for @memoryEntryEditTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit memory'**
  String get memoryEntryEditTitle;

  /// No description provided for @memoryEntryCreateTitle.
  ///
  /// In en, this message translates to:
  /// **'New memory'**
  String get memoryEntryCreateTitle;

  /// No description provided for @memoryEntryContentHint.
  ///
  /// In en, this message translates to:
  /// **'Enter memory content'**
  String get memoryEntryContentHint;

  /// No description provided for @memoryEntryTypeLabel.
  ///
  /// In en, this message translates to:
  /// **'Type'**
  String get memoryEntryTypeLabel;

  /// No description provided for @memoryEntryScopeLabel.
  ///
  /// In en, this message translates to:
  /// **'Scope'**
  String get memoryEntryScopeLabel;

  /// No description provided for @memoryFilterScopeAll.
  ///
  /// In en, this message translates to:
  /// **'All scopes'**
  String get memoryFilterScopeAll;

  /// No description provided for @memoryFilterScopeGlobal.
  ///
  /// In en, this message translates to:
  /// **'Global only'**
  String get memoryFilterScopeGlobal;

  /// No description provided for @memoryFilterScopeAssistant.
  ///
  /// In en, this message translates to:
  /// **'Assistant'**
  String get memoryFilterScopeAssistant;

  /// No description provided for @memoryFilterTypeAll.
  ///
  /// In en, this message translates to:
  /// **'All types'**
  String get memoryFilterTypeAll;

  /// No description provided for @memoryFilterStatusAll.
  ///
  /// In en, this message translates to:
  /// **'All statuses'**
  String get memoryFilterStatusAll;

  /// No description provided for @memoryFilterStatusActive.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get memoryFilterStatusActive;

  /// No description provided for @memoryFilterStatusArchived.
  ///
  /// In en, this message translates to:
  /// **'Archived'**
  String get memoryFilterStatusArchived;

  /// No description provided for @memorySearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search memories'**
  String get memorySearchHint;

  /// No description provided for @memorySearchEmpty.
  ///
  /// In en, this message translates to:
  /// **'No matching memories'**
  String get memorySearchEmpty;

  /// No description provided for @memoryOrphanBanner.
  ///
  /// In en, this message translates to:
  /// **'{count} orphaned assistant memories (assistant deleted)'**
  String memoryOrphanBanner(int count);

  /// No description provided for @memoryOrphanCleanupButton.
  ///
  /// In en, this message translates to:
  /// **'Clean up'**
  String get memoryOrphanCleanupButton;

  /// No description provided for @memoryOrphanConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Clean up orphaned memories?'**
  String get memoryOrphanConfirmTitle;

  /// No description provided for @memoryOrphanConfirmContent.
  ///
  /// In en, this message translates to:
  /// **'Permanently delete {count} memories whose assistant no longer exists.'**
  String memoryOrphanConfirmContent(int count);

  /// No description provided for @memoryOrganizeButton.
  ///
  /// In en, this message translates to:
  /// **'Organize'**
  String get memoryOrganizeButton;

  /// No description provided for @memoryOrganizeNeedsConversation.
  ///
  /// In en, this message translates to:
  /// **'Open a chat with this assistant to organize memories'**
  String get memoryOrganizeNeedsConversation;

  /// No description provided for @memoryOrganizeNeedsModel.
  ///
  /// In en, this message translates to:
  /// **'Select a memory model in Settings → Memory first'**
  String get memoryOrganizeNeedsModel;

  /// No description provided for @memoryOrganizeStatusNever.
  ///
  /// In en, this message translates to:
  /// **'Not organized yet'**
  String get memoryOrganizeStatusNever;

  /// No description provided for @memoryOrganizeStatusLast.
  ///
  /// In en, this message translates to:
  /// **'Last organized: {when}'**
  String memoryOrganizeStatusLast(String when);

  /// No description provided for @memoryOrganizeStatusExtracted.
  ///
  /// In en, this message translates to:
  /// **'extracted {count}'**
  String memoryOrganizeStatusExtracted(int count);

  /// No description provided for @memoryOrganizeStatusSkipped.
  ///
  /// In en, this message translates to:
  /// **'nothing to remember'**
  String get memoryOrganizeStatusSkipped;

  /// No description provided for @memoryOrganizeStatusFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed: {reason}'**
  String memoryOrganizeStatusFailed(String reason);

  /// No description provided for @memoryOrganizeStatusSkippedReason.
  ///
  /// In en, this message translates to:
  /// **'skipped: {reason}'**
  String memoryOrganizeStatusSkippedReason(String reason);

  /// No description provided for @memoryOutcomeTemporaryConversation.
  ///
  /// In en, this message translates to:
  /// **'Temporary chats are not saved to memory'**
  String get memoryOutcomeTemporaryConversation;

  /// No description provided for @memoryOutcomeMemoryDisabled.
  ///
  /// In en, this message translates to:
  /// **'Memory is off for this assistant'**
  String get memoryOutcomeMemoryDisabled;

  /// No description provided for @memoryOutcomeAutoOrganizeOff.
  ///
  /// In en, this message translates to:
  /// **'Auto-organize is off'**
  String get memoryOutcomeAutoOrganizeOff;

  /// No description provided for @memoryOutcomeStreaming.
  ///
  /// In en, this message translates to:
  /// **'Skipped while a reply is still streaming'**
  String get memoryOutcomeStreaming;

  /// No description provided for @memoryOutcomeBelowThreshold.
  ///
  /// In en, this message translates to:
  /// **'Not enough new messages to organize'**
  String get memoryOutcomeBelowThreshold;

  /// No description provided for @memoryOutcomeEmptyWindow.
  ///
  /// In en, this message translates to:
  /// **'No new messages to organize'**
  String get memoryOutcomeEmptyWindow;

  /// No description provided for @memoryOutcomeMemoryModelUnset.
  ///
  /// In en, this message translates to:
  /// **'No memory processing model selected'**
  String get memoryOutcomeMemoryModelUnset;

  /// No description provided for @memoryOutcomeMemoryModelMissing.
  ///
  /// In en, this message translates to:
  /// **'The selected memory model is no longer available'**
  String get memoryOutcomeMemoryModelMissing;

  /// No description provided for @memoryOutcomeAssistantMissing.
  ///
  /// In en, this message translates to:
  /// **'Assistant not found'**
  String get memoryOutcomeAssistantMissing;

  /// No description provided for @memoryOutcomeConversationMissing.
  ///
  /// In en, this message translates to:
  /// **'Conversation not found'**
  String get memoryOutcomeConversationMissing;

  /// No description provided for @memoryOutcomeQueueOverflow.
  ///
  /// In en, this message translates to:
  /// **'The organize queue was full, so this run was dropped'**
  String get memoryOutcomeQueueOverflow;

  /// No description provided for @memoryOutcomeGateRequestFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not reach the memory model for the remember/skip check'**
  String get memoryOutcomeGateRequestFailed;

  /// No description provided for @memoryOutcomeGateParseFailed.
  ///
  /// In en, this message translates to:
  /// **'The remember/skip check returned an unreadable reply'**
  String get memoryOutcomeGateParseFailed;

  /// No description provided for @memoryOutcomeExtractRequestFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not reach the memory model to extract memories'**
  String get memoryOutcomeExtractRequestFailed;

  /// No description provided for @memoryOutcomeExtractParseFailed.
  ///
  /// In en, this message translates to:
  /// **'The memory extract reply could not be parsed'**
  String get memoryOutcomeExtractParseFailed;

  /// No description provided for @memoryOutcomeDistillFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not distill the user profile'**
  String get memoryOutcomeDistillFailed;

  /// No description provided for @memoryOutcomeMemoryExecutionError.
  ///
  /// In en, this message translates to:
  /// **'A memory tool failed to run'**
  String get memoryOutcomeMemoryExecutionError;

  /// No description provided for @memoryOutcomeUnsupportedTool.
  ///
  /// In en, this message translates to:
  /// **'Unsupported memory tool'**
  String get memoryOutcomeUnsupportedTool;

  /// No description provided for @memoryOutcomeInvalidMemoryType.
  ///
  /// In en, this message translates to:
  /// **'Invalid memory type'**
  String get memoryOutcomeInvalidMemoryType;

  /// No description provided for @memoryOutcomeInvalidMemoryContent.
  ///
  /// In en, this message translates to:
  /// **'Invalid memory content'**
  String get memoryOutcomeInvalidMemoryContent;

  /// No description provided for @memoryOutcomeInvalidQuery.
  ///
  /// In en, this message translates to:
  /// **'Invalid search query'**
  String get memoryOutcomeInvalidQuery;

  /// No description provided for @memoryOutcomeInvalidMemoryId.
  ///
  /// In en, this message translates to:
  /// **'Invalid memory id'**
  String get memoryOutcomeInvalidMemoryId;

  /// No description provided for @memoryOutcomeMemoryNotFound.
  ///
  /// In en, this message translates to:
  /// **'Memory not found'**
  String get memoryOutcomeMemoryNotFound;

  /// No description provided for @memoryOutcomeInvalidProfileFields.
  ///
  /// In en, this message translates to:
  /// **'Invalid profile fields'**
  String get memoryOutcomeInvalidProfileFields;

  /// No description provided for @memoryOutcomeChatSearchUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Chat search is unavailable'**
  String get memoryOutcomeChatSearchUnavailable;

  /// No description provided for @memoryOrganizeJustNow.
  ///
  /// In en, this message translates to:
  /// **'just now'**
  String get memoryOrganizeJustNow;

  /// No description provided for @memoryOrganizeMinutesAgo.
  ///
  /// In en, this message translates to:
  /// **'{n} min ago'**
  String memoryOrganizeMinutesAgo(int n);

  /// No description provided for @memoryOrganizeHoursAgo.
  ///
  /// In en, this message translates to:
  /// **'{n} h ago'**
  String memoryOrganizeHoursAgo(int n);

  /// No description provided for @memoryOrganizeDaysAgo.
  ///
  /// In en, this message translates to:
  /// **'{n} d ago'**
  String memoryOrganizeDaysAgo(int n);

  /// No description provided for @memoryModelMissingNotice.
  ///
  /// In en, this message translates to:
  /// **'Select a memory processing model in Settings → Memory first.'**
  String get memoryModelMissingNotice;

  /// No description provided for @memoryModelMissingGoSelect.
  ///
  /// In en, this message translates to:
  /// **'Choose model'**
  String get memoryModelMissingGoSelect;

  /// No description provided for @memoryEntriesPageTitle.
  ///
  /// In en, this message translates to:
  /// **'All memories'**
  String get memoryEntriesPageTitle;

  /// No description provided for @userProfilePageTitle.
  ///
  /// In en, this message translates to:
  /// **'User profile'**
  String get userProfilePageTitle;

  /// No description provided for @userProfilePreferredName.
  ///
  /// In en, this message translates to:
  /// **'Preferred name'**
  String get userProfilePreferredName;

  /// No description provided for @userProfilePreferredNameHint.
  ///
  /// In en, this message translates to:
  /// **'How the model should address you — unrelated to the sidebar display name'**
  String get userProfilePreferredNameHint;

  /// No description provided for @userProfileGender.
  ///
  /// In en, this message translates to:
  /// **'Gender'**
  String get userProfileGender;

  /// No description provided for @userProfilePronouns.
  ///
  /// In en, this message translates to:
  /// **'Pronouns'**
  String get userProfilePronouns;

  /// No description provided for @userProfilePreferredLanguage.
  ///
  /// In en, this message translates to:
  /// **'Preferred language'**
  String get userProfilePreferredLanguage;

  /// No description provided for @userProfileTimezone.
  ///
  /// In en, this message translates to:
  /// **'Timezone'**
  String get userProfileTimezone;

  /// No description provided for @userProfileOccupation.
  ///
  /// In en, this message translates to:
  /// **'Occupation'**
  String get userProfileOccupation;

  /// No description provided for @userProfileLocation.
  ///
  /// In en, this message translates to:
  /// **'Location'**
  String get userProfileLocation;

  /// No description provided for @userProfileCustomSection.
  ///
  /// In en, this message translates to:
  /// **'Custom fields'**
  String get userProfileCustomSection;

  /// No description provided for @userProfileAddCustom.
  ///
  /// In en, this message translates to:
  /// **'Add custom field'**
  String get userProfileAddCustom;

  /// No description provided for @userProfileCustomKeyHint.
  ///
  /// In en, this message translates to:
  /// **'Key (custom.name)'**
  String get userProfileCustomKeyHint;

  /// No description provided for @userProfileCustomValueHint.
  ///
  /// In en, this message translates to:
  /// **'Value'**
  String get userProfileCustomValueHint;

  /// No description provided for @userProfileInvalidKey.
  ///
  /// In en, this message translates to:
  /// **'Key must be custom. followed by 1–32 letters, digits, _ or -'**
  String get userProfileInvalidKey;

  /// No description provided for @userProfileClear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get userProfileClear;

  /// No description provided for @userProfileSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get userProfileSave;

  /// No description provided for @userProfileEmptyValue.
  ///
  /// In en, this message translates to:
  /// **'Not set'**
  String get userProfileEmptyValue;

  /// No description provided for @legacyMemoryPageTitle.
  ///
  /// In en, this message translates to:
  /// **'Legacy memories'**
  String get legacyMemoryPageTitle;

  /// No description provided for @legacyMemoryBanner.
  ///
  /// In en, this message translates to:
  /// **'These memories came from an older version and are not used in chats. You can migrate them into the current memory system.'**
  String get legacyMemoryBanner;

  /// No description provided for @legacyMemoryEmpty.
  ///
  /// In en, this message translates to:
  /// **'No legacy memories'**
  String get legacyMemoryEmpty;

  /// No description provided for @legacyMemoryCopy.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get legacyMemoryCopy;

  /// No description provided for @legacyMemoryCopied.
  ///
  /// In en, this message translates to:
  /// **'Copied'**
  String get legacyMemoryCopied;

  /// No description provided for @legacyMemoryExport.
  ///
  /// In en, this message translates to:
  /// **'Export'**
  String get legacyMemoryExport;

  /// No description provided for @legacyMemoryExportTitle.
  ///
  /// In en, this message translates to:
  /// **'Kelivo legacy memory export'**
  String get legacyMemoryExportTitle;

  /// No description provided for @legacyMemoryAssistantHeader.
  ///
  /// In en, this message translates to:
  /// **'Assistant: {name}'**
  String legacyMemoryAssistantHeader(String name);

  /// No description provided for @legacyMemorySearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search legacy memories'**
  String get legacyMemorySearchHint;

  /// No description provided for @legacyMemoryMigrate.
  ///
  /// In en, this message translates to:
  /// **'Migrate'**
  String get legacyMemoryMigrate;

  /// No description provided for @legacyMemoryMigrationTitle.
  ///
  /// In en, this message translates to:
  /// **'Migrate legacy memories'**
  String get legacyMemoryMigrationTitle;

  /// No description provided for @legacyMemoryMigrationSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Use a model to classify and clean up {count} legacy memories. The originals stay unchanged.'**
  String legacyMemoryMigrationSubtitle(int count);

  /// No description provided for @legacyMemoryMigrationModel.
  ///
  /// In en, this message translates to:
  /// **'Migration model'**
  String get legacyMemoryMigrationModel;

  /// No description provided for @legacyMemoryMigrationChooseModel.
  ///
  /// In en, this message translates to:
  /// **'Choose a model'**
  String get legacyMemoryMigrationChooseModel;

  /// No description provided for @legacyMemoryMigrationTarget.
  ///
  /// In en, this message translates to:
  /// **'Save to'**
  String get legacyMemoryMigrationTarget;

  /// No description provided for @legacyMemoryMigrationTargetGlobal.
  ///
  /// In en, this message translates to:
  /// **'Global'**
  String get legacyMemoryMigrationTargetGlobal;

  /// No description provided for @legacyMemoryMigrationTargetAssistant.
  ///
  /// In en, this message translates to:
  /// **'Current assistant'**
  String get legacyMemoryMigrationTargetAssistant;

  /// No description provided for @legacyMemoryMigrationTargetOriginalAssistants.
  ///
  /// In en, this message translates to:
  /// **'Original assistants'**
  String get legacyMemoryMigrationTargetOriginalAssistants;

  /// No description provided for @legacyMemoryMigrationTargetGlobalDescription.
  ///
  /// In en, this message translates to:
  /// **'Available to every assistant'**
  String get legacyMemoryMigrationTargetGlobalDescription;

  /// No description provided for @legacyMemoryMigrationTargetAssistantDescription.
  ///
  /// In en, this message translates to:
  /// **'Only available to this assistant'**
  String get legacyMemoryMigrationTargetAssistantDescription;

  /// No description provided for @legacyMemoryMigrationTargetOriginalDescription.
  ///
  /// In en, this message translates to:
  /// **'Keep each memory with its original assistant'**
  String get legacyMemoryMigrationTargetOriginalDescription;

  /// No description provided for @legacyMemoryMigrationStart.
  ///
  /// In en, this message translates to:
  /// **'Start migration'**
  String get legacyMemoryMigrationStart;

  /// No description provided for @legacyMemoryMigrationAnalyzing.
  ///
  /// In en, this message translates to:
  /// **'Analyzing with model'**
  String get legacyMemoryMigrationAnalyzing;

  /// No description provided for @legacyMemoryMigrationWriting.
  ///
  /// In en, this message translates to:
  /// **'Saving memories'**
  String get legacyMemoryMigrationWriting;

  /// No description provided for @legacyMemoryMigrationProgress.
  ///
  /// In en, this message translates to:
  /// **'{current} of {total}'**
  String legacyMemoryMigrationProgress(int current, int total);

  /// No description provided for @legacyMemoryMigrationComplete.
  ///
  /// In en, this message translates to:
  /// **'Migration complete'**
  String get legacyMemoryMigrationComplete;

  /// No description provided for @legacyMemoryMigrationResult.
  ///
  /// In en, this message translates to:
  /// **'{created} migrated · {skipped} already existed'**
  String legacyMemoryMigrationResult(int created, int skipped);

  /// No description provided for @legacyMemoryMigrationFailed.
  ///
  /// In en, this message translates to:
  /// **'Migration stopped. You can retry; memories already saved will be skipped.'**
  String get legacyMemoryMigrationFailed;

  /// No description provided for @legacyMemoryMigrationRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get legacyMemoryMigrationRetry;

  /// No description provided for @legacyMemoryMigrationClose.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get legacyMemoryMigrationClose;

  /// No description provided for @legacyMemoryMigrationContentMode.
  ///
  /// In en, this message translates to:
  /// **'Content'**
  String get legacyMemoryMigrationContentMode;

  /// No description provided for @legacyMemoryMigrationContentPreserve.
  ///
  /// In en, this message translates to:
  /// **'Keep original'**
  String get legacyMemoryMigrationContentPreserve;

  /// No description provided for @legacyMemoryMigrationContentOrganize.
  ///
  /// In en, this message translates to:
  /// **'Rewrite with model'**
  String get legacyMemoryMigrationContentOrganize;

  /// No description provided for @legacyMemoryMigrationContentPreserveDescription.
  ///
  /// In en, this message translates to:
  /// **'The model only assigns a type. The original wording is saved as-is.'**
  String get legacyMemoryMigrationContentPreserveDescription;

  /// No description provided for @legacyMemoryMigrationContentOrganizeDescription.
  ///
  /// In en, this message translates to:
  /// **'The model classifies and rewrites each memory using the editable migrate prompt.'**
  String get legacyMemoryMigrationContentOrganizeDescription;

  /// No description provided for @legacyMemoryMigrationBatchSize.
  ///
  /// In en, this message translates to:
  /// **'Batch size'**
  String get legacyMemoryMigrationBatchSize;

  /// No description provided for @legacyMemoryMigrationPartial.
  ///
  /// In en, this message translates to:
  /// **'{created} migrated · {skipped} skipped · {failed} failed'**
  String legacyMemoryMigrationPartial(int created, int skipped, int failed);

  /// No description provided for @legacyMemoryMigrationContinue.
  ///
  /// In en, this message translates to:
  /// **'Continue migration'**
  String get legacyMemoryMigrationContinue;

  /// No description provided for @legacyMemoryMigrationErrorNetwork.
  ///
  /// In en, this message translates to:
  /// **'Network error. Check the connection and try again.'**
  String get legacyMemoryMigrationErrorNetwork;

  /// No description provided for @legacyMemoryMigrationErrorFormat.
  ///
  /// In en, this message translates to:
  /// **'The model returned an invalid response.'**
  String get legacyMemoryMigrationErrorFormat;

  /// No description provided for @legacyMemoryMigrationErrorAuth.
  ///
  /// In en, this message translates to:
  /// **'Authentication failed. Check the API key.'**
  String get legacyMemoryMigrationErrorAuth;

  /// No description provided for @legacyMemoryMigrationErrorOther.
  ///
  /// In en, this message translates to:
  /// **'Migration failed: {message}'**
  String legacyMemoryMigrationErrorOther(String message);

  /// No description provided for @legacyMemoryModeTitle.
  ///
  /// In en, this message translates to:
  /// **'Use legacy memory'**
  String get legacyMemoryModeTitle;

  /// No description provided for @legacyMemoryModeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Global setting for all assistants'**
  String get legacyMemoryModeSubtitle;

  /// No description provided for @legacyMemoryModeCacheWarning.
  ///
  /// In en, this message translates to:
  /// **'The default template injects the current time via {token}, which affects cache hit rate. Remove it if you do not need it.'**
  String legacyMemoryModeCacheWarning(String token);

  /// No description provided for @memoryUiContentLabel.
  ///
  /// In en, this message translates to:
  /// **'Content'**
  String get memoryUiContentLabel;

  /// No description provided for @memoryUiValueLabel.
  ///
  /// In en, this message translates to:
  /// **'Value'**
  String get memoryUiValueLabel;

  /// No description provided for @memoryUiCustomKeyLabel.
  ///
  /// In en, this message translates to:
  /// **'Key'**
  String get memoryUiCustomKeyLabel;

  /// No description provided for @memoryUiStatusLabel.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get memoryUiStatusLabel;

  /// No description provided for @memoryUiAssistantLabel.
  ///
  /// In en, this message translates to:
  /// **'Assistant'**
  String get memoryUiAssistantLabel;

  /// No description provided for @memoryUiAssistantAll.
  ///
  /// In en, this message translates to:
  /// **'All assistants'**
  String get memoryUiAssistantAll;

  /// No description provided for @memoryUiSearchClear.
  ///
  /// In en, this message translates to:
  /// **'Clear search'**
  String get memoryUiSearchClear;

  /// No description provided for @memoryUiAssistantLegacyTitle.
  ///
  /// In en, this message translates to:
  /// **'Legacy memories (read-only)'**
  String get memoryUiAssistantLegacyTitle;

  /// No description provided for @memoryUiAssistantLegacySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Old memories of this assistant from previous versions'**
  String get memoryUiAssistantLegacySubtitle;

  /// No description provided for @assistantEditMemorySwitchTitle.
  ///
  /// In en, this message translates to:
  /// **'Use long-term memory'**
  String get assistantEditMemorySwitchTitle;

  /// No description provided for @assistantEditMemorySwitchSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Inject saved memories into chats and let this assistant write new ones'**
  String get assistantEditMemorySwitchSubtitle;

  /// No description provided for @assistantEditAutoOrganizeTitle.
  ///
  /// In en, this message translates to:
  /// **'Auto-organize memory'**
  String get assistantEditAutoOrganizeTitle;

  /// No description provided for @assistantEditAutoOrganizeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Run the memory pipeline after chats'**
  String get assistantEditAutoOrganizeSubtitle;

  /// No description provided for @assistantEditAllowPastRecallTitle.
  ///
  /// In en, this message translates to:
  /// **'Allow recalling past chats'**
  String get assistantEditAllowPastRecallTitle;

  /// No description provided for @assistantEditAllowPastRecallSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Enable chat search across past conversations'**
  String get assistantEditAllowPastRecallSubtitle;

  /// No description provided for @assistantEditGenerateSummaryTitle.
  ///
  /// In en, this message translates to:
  /// **'Generate conversation summaries'**
  String get assistantEditGenerateSummaryTitle;

  /// No description provided for @assistantEditGenerateSummarySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Summaries are only used by chat search'**
  String get assistantEditGenerateSummarySubtitle;

  /// No description provided for @assistantEditManageMemoryTitle.
  ///
  /// In en, this message translates to:
  /// **'Memories visible to this assistant'**
  String get assistantEditManageMemoryTitle;

  /// No description provided for @assistantEditWriteScopeTitle.
  ///
  /// In en, this message translates to:
  /// **'Memory write scope'**
  String get assistantEditWriteScopeTitle;

  /// No description provided for @assistantEditWriteScopeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Where new memories are stored by default'**
  String get assistantEditWriteScopeSubtitle;

  /// No description provided for @assistantEditWriteScopeAlwaysGlobal.
  ///
  /// In en, this message translates to:
  /// **'Always global'**
  String get assistantEditWriteScopeAlwaysGlobal;

  /// No description provided for @assistantEditWriteScopeAlwaysGlobalSubtitle.
  ///
  /// In en, this message translates to:
  /// **'New memories are shared with every assistant'**
  String get assistantEditWriteScopeAlwaysGlobalSubtitle;

  /// No description provided for @assistantEditWriteScopeAlwaysAssistant.
  ///
  /// In en, this message translates to:
  /// **'Always this assistant'**
  String get assistantEditWriteScopeAlwaysAssistant;

  /// No description provided for @assistantEditWriteScopeAlwaysAssistantSubtitle.
  ///
  /// In en, this message translates to:
  /// **'New memories stay private to this assistant'**
  String get assistantEditWriteScopeAlwaysAssistantSubtitle;

  /// No description provided for @assistantEditWriteScopeToolDefaultGlobal.
  ///
  /// In en, this message translates to:
  /// **'Model chooses (default global)'**
  String get assistantEditWriteScopeToolDefaultGlobal;

  /// No description provided for @assistantEditWriteScopeToolDefaultGlobalSubtitle.
  ///
  /// In en, this message translates to:
  /// **'The model may pick global or this assistant; default is global'**
  String get assistantEditWriteScopeToolDefaultGlobalSubtitle;

  /// No description provided for @assistantEditWriteScopeToolDefaultAssistant.
  ///
  /// In en, this message translates to:
  /// **'Model chooses (default assistant)'**
  String get assistantEditWriteScopeToolDefaultAssistant;

  /// No description provided for @assistantEditWriteScopeToolDefaultAssistantSubtitle.
  ///
  /// In en, this message translates to:
  /// **'The model may pick global or this assistant; default is this assistant'**
  String get assistantEditWriteScopeToolDefaultAssistantSubtitle;

  /// No description provided for @assistantEditDedupeModeTitle.
  ///
  /// In en, this message translates to:
  /// **'Dedupe mode'**
  String get assistantEditDedupeModeTitle;

  /// No description provided for @assistantEditDedupeModeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'How candidates are judged against existing memories'**
  String get assistantEditDedupeModeSubtitle;

  /// No description provided for @assistantEditDedupeModeBatched.
  ///
  /// In en, this message translates to:
  /// **'Batched'**
  String get assistantEditDedupeModeBatched;

  /// No description provided for @assistantEditDedupeModeBatchedSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Judge all new candidates in one request. Faster and cheaper; less precise when many items arrive at once.'**
  String get assistantEditDedupeModeBatchedSubtitle;

  /// No description provided for @assistantEditDedupeModePerItem.
  ///
  /// In en, this message translates to:
  /// **'Per item'**
  String get assistantEditDedupeModePerItem;

  /// No description provided for @assistantEditDedupeModePerItemSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Judge each candidate in its own request. More accurate; uses more model calls.'**
  String get assistantEditDedupeModePerItemSubtitle;

  /// No description provided for @assistantEditOrganizeFrequencyTitle.
  ///
  /// In en, this message translates to:
  /// **'Organize every N turns'**
  String get assistantEditOrganizeFrequencyTitle;

  /// No description provided for @assistantEditOrganizeFrequencySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Run auto-organize after this many assistant replies'**
  String get assistantEditOrganizeFrequencySubtitle;

  /// No description provided for @assistantEditOrganizeFrequencyOption.
  ///
  /// In en, this message translates to:
  /// **'Every {n}'**
  String assistantEditOrganizeFrequencyOption(int n);

  /// No description provided for @assistantEditOrganizeFrequencyCustomButton.
  ///
  /// In en, this message translates to:
  /// **'Custom'**
  String get assistantEditOrganizeFrequencyCustomButton;

  /// No description provided for @assistantEditOrganizeFrequencyCustomTitle.
  ///
  /// In en, this message translates to:
  /// **'Custom frequency'**
  String get assistantEditOrganizeFrequencyCustomTitle;

  /// No description provided for @assistantEditOrganizeFrequencyCustomDescription.
  ///
  /// In en, this message translates to:
  /// **'Enter a number between 1 and 20.'**
  String get assistantEditOrganizeFrequencyCustomDescription;

  /// No description provided for @assistantEditOrganizeFrequencyCustomLabel.
  ///
  /// In en, this message translates to:
  /// **'Turns'**
  String get assistantEditOrganizeFrequencyCustomLabel;

  /// No description provided for @assistantEditOrganizeFrequencyCustomHint.
  ///
  /// In en, this message translates to:
  /// **'1–20'**
  String get assistantEditOrganizeFrequencyCustomHint;

  /// No description provided for @assistantEditOrganizeFrequencyCustomInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter a number between 1 and 20'**
  String get assistantEditOrganizeFrequencyCustomInvalid;

  /// No description provided for @worldBookTitle.
  ///
  /// In en, this message translates to:
  /// **'World Book'**
  String get worldBookTitle;

  /// No description provided for @worldBookAdd.
  ///
  /// In en, this message translates to:
  /// **'Add World Book'**
  String get worldBookAdd;

  /// No description provided for @worldBookEmptyMessage.
  ///
  /// In en, this message translates to:
  /// **'No world books yet'**
  String get worldBookEmptyMessage;

  /// No description provided for @worldBookUnnamed.
  ///
  /// In en, this message translates to:
  /// **'Unnamed World Book'**
  String get worldBookUnnamed;

  /// No description provided for @worldBookDisabledTag.
  ///
  /// In en, this message translates to:
  /// **'Disabled'**
  String get worldBookDisabledTag;

  /// No description provided for @worldBookAlwaysOnTag.
  ///
  /// In en, this message translates to:
  /// **'Always On'**
  String get worldBookAlwaysOnTag;

  /// No description provided for @worldBookAddEntry.
  ///
  /// In en, this message translates to:
  /// **'Add Entry'**
  String get worldBookAddEntry;

  /// No description provided for @worldBookExport.
  ///
  /// In en, this message translates to:
  /// **'Share / Export'**
  String get worldBookExport;

  /// No description provided for @worldBookConfig.
  ///
  /// In en, this message translates to:
  /// **'Configure'**
  String get worldBookConfig;

  /// No description provided for @worldBookDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete World Book'**
  String get worldBookDeleteTitle;

  /// No description provided for @worldBookDeleteMessage.
  ///
  /// In en, this message translates to:
  /// **'Delete “{name}”? This cannot be undone.'**
  String worldBookDeleteMessage(String name);

  /// No description provided for @worldBookCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get worldBookCancel;

  /// No description provided for @worldBookDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get worldBookDelete;

  /// No description provided for @worldBookExportFailed.
  ///
  /// In en, this message translates to:
  /// **'Export failed: {error}'**
  String worldBookExportFailed(String error);

  /// No description provided for @worldBookNoEntriesHint.
  ///
  /// In en, this message translates to:
  /// **'No entries'**
  String get worldBookNoEntriesHint;

  /// No description provided for @worldBookUnnamedEntry.
  ///
  /// In en, this message translates to:
  /// **'Unnamed Entry'**
  String get worldBookUnnamedEntry;

  /// No description provided for @worldBookKeywordsLine.
  ///
  /// In en, this message translates to:
  /// **'Keywords: {keywords}'**
  String worldBookKeywordsLine(String keywords);

  /// No description provided for @worldBookEditEntry.
  ///
  /// In en, this message translates to:
  /// **'Edit Entry'**
  String get worldBookEditEntry;

  /// No description provided for @worldBookDeleteEntry.
  ///
  /// In en, this message translates to:
  /// **'Delete Entry'**
  String get worldBookDeleteEntry;

  /// No description provided for @worldBookNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get worldBookNameLabel;

  /// No description provided for @worldBookDescriptionLabel.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get worldBookDescriptionLabel;

  /// No description provided for @worldBookEnabledLabel.
  ///
  /// In en, this message translates to:
  /// **'Enabled'**
  String get worldBookEnabledLabel;

  /// No description provided for @worldBookSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get worldBookSave;

  /// No description provided for @worldBookEntryNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Entry name'**
  String get worldBookEntryNameLabel;

  /// No description provided for @worldBookEntryEnabledLabel.
  ///
  /// In en, this message translates to:
  /// **'Entry enabled'**
  String get worldBookEntryEnabledLabel;

  /// No description provided for @worldBookEntryPriorityLabel.
  ///
  /// In en, this message translates to:
  /// **'Priority'**
  String get worldBookEntryPriorityLabel;

  /// No description provided for @worldBookEntryKeywordsLabel.
  ///
  /// In en, this message translates to:
  /// **'Keywords'**
  String get worldBookEntryKeywordsLabel;

  /// No description provided for @worldBookEntryKeywordsHint.
  ///
  /// In en, this message translates to:
  /// **'Type a keyword and tap + to add.'**
  String get worldBookEntryKeywordsHint;

  /// No description provided for @worldBookEntryKeywordInputHint.
  ///
  /// In en, this message translates to:
  /// **'Type a keyword'**
  String get worldBookEntryKeywordInputHint;

  /// No description provided for @worldBookEntryKeywordAddTooltip.
  ///
  /// In en, this message translates to:
  /// **'Add keyword'**
  String get worldBookEntryKeywordAddTooltip;

  /// No description provided for @worldBookEntryUseRegexLabel.
  ///
  /// In en, this message translates to:
  /// **'Use regex'**
  String get worldBookEntryUseRegexLabel;

  /// No description provided for @worldBookEntryCaseSensitiveLabel.
  ///
  /// In en, this message translates to:
  /// **'Case sensitive'**
  String get worldBookEntryCaseSensitiveLabel;

  /// No description provided for @worldBookEntryAlwaysOnLabel.
  ///
  /// In en, this message translates to:
  /// **'Always active'**
  String get worldBookEntryAlwaysOnLabel;

  /// No description provided for @worldBookEntryAlwaysOnHint.
  ///
  /// In en, this message translates to:
  /// **'Always inject without keyword matching'**
  String get worldBookEntryAlwaysOnHint;

  /// No description provided for @worldBookEntryScanDepthLabel.
  ///
  /// In en, this message translates to:
  /// **'Scan depth'**
  String get worldBookEntryScanDepthLabel;

  /// No description provided for @worldBookEntryContentLabel.
  ///
  /// In en, this message translates to:
  /// **'Content'**
  String get worldBookEntryContentLabel;

  /// No description provided for @worldBookEntryInjectionPositionLabel.
  ///
  /// In en, this message translates to:
  /// **'Injection position'**
  String get worldBookEntryInjectionPositionLabel;

  /// No description provided for @worldBookEntryInjectionRoleLabel.
  ///
  /// In en, this message translates to:
  /// **'Injection role'**
  String get worldBookEntryInjectionRoleLabel;

  /// No description provided for @worldBookEntryInjectDepthLabel.
  ///
  /// In en, this message translates to:
  /// **'Injection depth'**
  String get worldBookEntryInjectDepthLabel;

  /// No description provided for @worldBookInjectionPositionBeforeSystemPrompt.
  ///
  /// In en, this message translates to:
  /// **'Before system prompt'**
  String get worldBookInjectionPositionBeforeSystemPrompt;

  /// No description provided for @worldBookInjectionPositionAfterSystemPrompt.
  ///
  /// In en, this message translates to:
  /// **'After system prompt'**
  String get worldBookInjectionPositionAfterSystemPrompt;

  /// No description provided for @worldBookInjectionPositionTopOfChat.
  ///
  /// In en, this message translates to:
  /// **'Top of chat'**
  String get worldBookInjectionPositionTopOfChat;

  /// No description provided for @worldBookInjectionPositionBottomOfChat.
  ///
  /// In en, this message translates to:
  /// **'Bottom of chat'**
  String get worldBookInjectionPositionBottomOfChat;

  /// No description provided for @worldBookInjectionPositionAtDepth.
  ///
  /// In en, this message translates to:
  /// **'At depth'**
  String get worldBookInjectionPositionAtDepth;

  /// No description provided for @worldBookInjectionRoleUser.
  ///
  /// In en, this message translates to:
  /// **'User'**
  String get worldBookInjectionRoleUser;

  /// No description provided for @worldBookInjectionRoleAssistant.
  ///
  /// In en, this message translates to:
  /// **'Assistant'**
  String get worldBookInjectionRoleAssistant;

  /// No description provided for @mcpToolNeedsApproval.
  ///
  /// In en, this message translates to:
  /// **'Require approval'**
  String get mcpToolNeedsApproval;

  /// No description provided for @toolApprovalPending.
  ///
  /// In en, this message translates to:
  /// **'Waiting for approval'**
  String get toolApprovalPending;

  /// No description provided for @toolApprovalApprove.
  ///
  /// In en, this message translates to:
  /// **'Approve'**
  String get toolApprovalApprove;

  /// No description provided for @toolApprovalDeny.
  ///
  /// In en, this message translates to:
  /// **'Deny'**
  String get toolApprovalDeny;

  /// No description provided for @toolApprovalDenyTitle.
  ///
  /// In en, this message translates to:
  /// **'Deny tool call'**
  String get toolApprovalDenyTitle;

  /// No description provided for @toolApprovalDenyHint.
  ///
  /// In en, this message translates to:
  /// **'Reason (optional)'**
  String get toolApprovalDenyHint;

  /// No description provided for @toolApprovalDeniedMessage.
  ///
  /// In en, this message translates to:
  /// **'Tool call \"{toolName}\" was denied by user. Reason: {reason}'**
  String toolApprovalDeniedMessage(Object reason, Object toolName);

  /// No description provided for @askUserCardSubmit.
  ///
  /// In en, this message translates to:
  /// **'Submit answer'**
  String get askUserCardSubmit;

  /// No description provided for @askUserCardCustomHint.
  ///
  /// In en, this message translates to:
  /// **'Type your answer'**
  String get askUserCardCustomHint;

  /// No description provided for @askUserCardSomethingElse.
  ///
  /// In en, this message translates to:
  /// **'Something else'**
  String get askUserCardSomethingElse;

  /// No description provided for @askUserCardSkip.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get askUserCardSkip;

  /// No description provided for @askUserCardSkipped.
  ///
  /// In en, this message translates to:
  /// **'Skipped'**
  String get askUserCardSkipped;

  /// No description provided for @askUserCardAnswered.
  ///
  /// In en, this message translates to:
  /// **'Answered'**
  String get askUserCardAnswered;

  /// No description provided for @askUserCardInactive.
  ///
  /// In en, this message translates to:
  /// **'This question is no longer active. Regenerate or continue the conversation.'**
  String get askUserCardInactive;

  /// No description provided for @askUserCardCancelled.
  ///
  /// In en, this message translates to:
  /// **'Question cancelled'**
  String get askUserCardCancelled;

  /// No description provided for @askUserCardQuestionCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Ask 1 question} other{Ask {count} questions}}'**
  String askUserCardQuestionCount(int count);

  /// No description provided for @tokenDetailPromptTokens.
  ///
  /// In en, this message translates to:
  /// **'{count} tokens'**
  String tokenDetailPromptTokens(int count);

  /// No description provided for @tokenDetailPromptTokensWithCache.
  ///
  /// In en, this message translates to:
  /// **'{count} tokens ({cached} cached)'**
  String tokenDetailPromptTokensWithCache(int count, int cached);

  /// No description provided for @tokenDetailCompletionTokens.
  ///
  /// In en, this message translates to:
  /// **'{count} tokens'**
  String tokenDetailCompletionTokens(int count);

  /// No description provided for @tokenDetailSpeed.
  ///
  /// In en, this message translates to:
  /// **'{value} tok/s'**
  String tokenDetailSpeed(String value);

  /// No description provided for @tokenDetailDuration.
  ///
  /// In en, this message translates to:
  /// **'{value}s'**
  String tokenDetailDuration(String value);

  /// No description provided for @tokenDetailTotalTokens.
  ///
  /// In en, this message translates to:
  /// **'{count} tokens'**
  String tokenDetailTotalTokens(int count);

  /// No description provided for @debugPageTitle.
  ///
  /// In en, this message translates to:
  /// **'Debug'**
  String get debugPageTitle;

  /// No description provided for @debugPageConversationToolsTitle.
  ///
  /// In en, this message translates to:
  /// **'Conversation tools'**
  String get debugPageConversationToolsTitle;

  /// No description provided for @debugPageCreateOversizedConversationButton.
  ///
  /// In en, this message translates to:
  /// **'Create oversized conversation (30 MB)'**
  String get debugPageCreateOversizedConversationButton;

  /// No description provided for @debugPageCreateManyMessagesConversationButton.
  ///
  /// In en, this message translates to:
  /// **'Create 1024-message conversation'**
  String get debugPageCreateManyMessagesConversationButton;

  /// No description provided for @debugPageCreateDailyMixedMarkdownConversationButton.
  ///
  /// In en, this message translates to:
  /// **'Create 3000 daily mixed Markdown messages'**
  String get debugPageCreateDailyMixedMarkdownConversationButton;

  /// No description provided for @debugPageCreateLongReasoningConversationButton.
  ///
  /// In en, this message translates to:
  /// **'Create long reasoning conversation (128 messages)'**
  String get debugPageCreateLongReasoningConversationButton;

  /// No description provided for @debugPageCreatingButton.
  ///
  /// In en, this message translates to:
  /// **'Creating...'**
  String get debugPageCreatingButton;

  /// No description provided for @debugPageCreatingOversizedConversation.
  ///
  /// In en, this message translates to:
  /// **'Creating a 30 MB oversized conversation...'**
  String get debugPageCreatingOversizedConversation;

  /// No description provided for @debugPageCreatingManyMessagesConversation.
  ///
  /// In en, this message translates to:
  /// **'Creating a 1024-message conversation...'**
  String get debugPageCreatingManyMessagesConversation;

  /// No description provided for @debugPageCreatingDailyMixedMarkdownConversation.
  ///
  /// In en, this message translates to:
  /// **'Creating a 3000-message daily mixed Markdown conversation...'**
  String get debugPageCreatingDailyMixedMarkdownConversation;

  /// No description provided for @debugPageCreatingLongReasoningConversation.
  ///
  /// In en, this message translates to:
  /// **'Creating a long reasoning debug conversation...'**
  String get debugPageCreatingLongReasoningConversation;

  /// No description provided for @debugPageNoCurrentAssistant.
  ///
  /// In en, this message translates to:
  /// **'No current assistant. Create or select an assistant first.'**
  String get debugPageNoCurrentAssistant;

  /// No description provided for @debugPageConversationCreated.
  ///
  /// In en, this message translates to:
  /// **'Created debug conversation with {count} messages.'**
  String debugPageConversationCreated(int count);

  /// No description provided for @debugPageCreateConversationFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to create debug conversation: {error}'**
  String debugPageCreateConversationFailed(String error);

  /// No description provided for @debugPageOversizedConversationTitle.
  ///
  /// In en, this message translates to:
  /// **'Oversized conversation test ({sizeMB} MB)'**
  String debugPageOversizedConversationTitle(int sizeMB);

  /// No description provided for @debugPageManyMessagesConversationTitle.
  ///
  /// In en, this message translates to:
  /// **'{count}-message conversation test'**
  String debugPageManyMessagesConversationTitle(int count);

  /// No description provided for @debugPageDailyMixedMarkdownConversationTitle.
  ///
  /// In en, this message translates to:
  /// **'{count}-message daily mixed Markdown test'**
  String debugPageDailyMixedMarkdownConversationTitle(int count);

  /// No description provided for @debugPageLongReasoningConversationTitle.
  ///
  /// In en, this message translates to:
  /// **'{count}-message long reasoning test'**
  String debugPageLongReasoningConversationTitle(int count);

  /// No description provided for @debugPageOversizedConversationSeedText.
  ///
  /// In en, this message translates to:
  /// **'This is long debug text for reproducing slow rendering in oversized conversations. It includes repeated Markdown-like text, punctuation, CJK content, and plain words so chat rendering, storage, and scrolling can be profiled.'**
  String get debugPageOversizedConversationSeedText;

  /// No description provided for @debugPageManyMessagesSeedText.
  ///
  /// In en, this message translates to:
  /// **'{role} message #{index}: quick random debug sample for testing list rendering, scrolling stability, message grouping, and conversation history performance.'**
  String debugPageManyMessagesSeedText(String role, int index);

  /// No description provided for @migrationIntroTitle.
  ///
  /// In en, this message translates to:
  /// **'Upgrade Chat Storage'**
  String get migrationIntroTitle;

  /// No description provided for @migrationIntroSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Kelivo is moving chat history to a faster SQLite database. The upgrade runs before the app opens so your data stays consistent.'**
  String get migrationIntroSubtitle;

  /// No description provided for @migrationBackupNote.
  ///
  /// In en, this message translates to:
  /// **'Before migration starts, Kelivo exports a ZIP backup with settings, chat history, and local files.'**
  String get migrationBackupNote;

  /// No description provided for @migrationPerformanceNote.
  ///
  /// In en, this message translates to:
  /// **'After migration, startup, history loading, and search use SQLite indexes for smoother long-chat performance.'**
  String get migrationPerformanceNote;

  /// No description provided for @migrationSourceDatabaseLabel.
  ///
  /// In en, this message translates to:
  /// **'Hive'**
  String get migrationSourceDatabaseLabel;

  /// No description provided for @migrationTargetDatabaseLabel.
  ///
  /// In en, this message translates to:
  /// **'SQLite'**
  String get migrationTargetDatabaseLabel;

  /// No description provided for @migrationChooseFolderButton.
  ///
  /// In en, this message translates to:
  /// **'Choose Folder and Back Up'**
  String get migrationChooseFolderButton;

  /// No description provided for @migrationSaveBackupButton.
  ///
  /// In en, this message translates to:
  /// **'Save Backup ZIP'**
  String get migrationSaveBackupButton;

  /// No description provided for @migrationStartWithoutBackupButton.
  ///
  /// In en, this message translates to:
  /// **'Migrate Without Backing Up'**
  String get migrationStartWithoutBackupButton;

  /// No description provided for @migrationSkipChatsJsonOption.
  ///
  /// In en, this message translates to:
  /// **'Skip chats.json'**
  String get migrationSkipChatsJsonOption;

  /// No description provided for @migrationSkipChatsJsonDescription.
  ///
  /// In en, this message translates to:
  /// **'Still backs up the original Hive files, settings, and local files. Recommended for very large histories.'**
  String get migrationSkipChatsJsonDescription;

  /// No description provided for @migrationSkipBackupOption.
  ///
  /// In en, this message translates to:
  /// **'Skip this backup'**
  String get migrationSkipBackupOption;

  /// No description provided for @migrationSkipBackupDescription.
  ///
  /// In en, this message translates to:
  /// **'Only select this if you already have a verified backup. Migration will start immediately.'**
  String get migrationSkipBackupDescription;

  /// No description provided for @migrationBackingUpTitle.
  ///
  /// In en, this message translates to:
  /// **'Backing Up'**
  String get migrationBackingUpTitle;

  /// No description provided for @migrationBackingUpSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Exporting settings, chat history, uploaded files, images, and fonts. Keep Kelivo open until this finishes.'**
  String get migrationBackingUpSubtitle;

  /// No description provided for @migrationMigratingTitle.
  ///
  /// In en, this message translates to:
  /// **'Migrating to SQLite'**
  String get migrationMigratingTitle;

  /// No description provided for @migrationMigratingSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Writing conversations and messages in batches so large histories do not overload memory. Keep Kelivo in the foreground until migration finishes.'**
  String get migrationMigratingSubtitle;

  /// No description provided for @migrationBackingUpDetail.
  ///
  /// In en, this message translates to:
  /// **'Backing up {fileName}'**
  String migrationBackingUpDetail(String fileName);

  /// No description provided for @migrationMigratingDetail.
  ///
  /// In en, this message translates to:
  /// **'Migrated {count} messages'**
  String migrationMigratingDetail(int count);

  /// No description provided for @migrationMigratingPrepareDetail.
  ///
  /// In en, this message translates to:
  /// **'Preparing SQLite database'**
  String get migrationMigratingPrepareDetail;

  /// No description provided for @migrationMigratingToolEventsDetail.
  ///
  /// In en, this message translates to:
  /// **'Migrating tool records'**
  String get migrationMigratingToolEventsDetail;

  /// No description provided for @migrationMigratingValidateDetail.
  ///
  /// In en, this message translates to:
  /// **'Validating migrated data'**
  String get migrationMigratingValidateDetail;

  /// No description provided for @migrationBackupReadyDetail.
  ///
  /// In en, this message translates to:
  /// **'Backup ZIP is ready'**
  String get migrationBackupReadyDetail;

  /// No description provided for @migrationSavingBackupZipDetail.
  ///
  /// In en, this message translates to:
  /// **'Saving backup ZIP'**
  String get migrationSavingBackupZipDetail;

  /// No description provided for @migrationBackupFileSavedTitle.
  ///
  /// In en, this message translates to:
  /// **'Backup ZIP saved'**
  String get migrationBackupFileSavedTitle;

  /// No description provided for @migrationChecklistBackupFiles.
  ///
  /// In en, this message translates to:
  /// **'Export Hive backup ZIP'**
  String get migrationChecklistBackupFiles;

  /// No description provided for @migrationChecklistPrepareSqlite.
  ///
  /// In en, this message translates to:
  /// **'Prepare SQLite database'**
  String get migrationChecklistPrepareSqlite;

  /// No description provided for @migrationChecklistMigrateMessages.
  ///
  /// In en, this message translates to:
  /// **'Migrate conversations and messages'**
  String get migrationChecklistMigrateMessages;

  /// No description provided for @migrationChecklistMigrateToolEvents.
  ///
  /// In en, this message translates to:
  /// **'Migrate tool records'**
  String get migrationChecklistMigrateToolEvents;

  /// No description provided for @migrationChecklistValidate.
  ///
  /// In en, this message translates to:
  /// **'Validate migrated data'**
  String get migrationChecklistValidate;

  /// No description provided for @migrationStepBackup.
  ///
  /// In en, this message translates to:
  /// **'Backup'**
  String get migrationStepBackup;

  /// No description provided for @migrationStepMigrate.
  ///
  /// In en, this message translates to:
  /// **'Migrate'**
  String get migrationStepMigrate;

  /// No description provided for @migrationStepComplete.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get migrationStepComplete;

  /// No description provided for @migrationCompleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Upgrade Complete'**
  String get migrationCompleteTitle;

  /// No description provided for @migrationCompleteSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Your chat history is now stored in SQLite. Restart Kelivo to enter the upgraded app.'**
  String get migrationCompleteSubtitle;

  /// No description provided for @migrationConversationCount.
  ///
  /// In en, this message translates to:
  /// **'Conversations'**
  String get migrationConversationCount;

  /// No description provided for @migrationMessageCount.
  ///
  /// In en, this message translates to:
  /// **'Messages'**
  String get migrationMessageCount;

  /// No description provided for @migrationConvertedCount.
  ///
  /// In en, this message translates to:
  /// **'Converted'**
  String get migrationConvertedCount;

  /// No description provided for @migrationMalformedCount.
  ///
  /// In en, this message translates to:
  /// **'Malformed'**
  String get migrationMalformedCount;

  /// No description provided for @migrationMissingFilesCount.
  ///
  /// In en, this message translates to:
  /// **'Missing files'**
  String get migrationMissingFilesCount;

  /// No description provided for @migrationRestartButton.
  ///
  /// In en, this message translates to:
  /// **'Restart Kelivo'**
  String get migrationRestartButton;

  /// No description provided for @migrationFailedTitle.
  ///
  /// In en, this message translates to:
  /// **'Migration Failed'**
  String get migrationFailedTitle;

  /// No description provided for @migrationFailedSubtitle.
  ///
  /// In en, this message translates to:
  /// **'The original Hive data is still intact. Any backup that finished earlier is unchanged. Review the reason below, then retry.'**
  String get migrationFailedSubtitle;

  /// No description provided for @migrationUnknownError.
  ///
  /// In en, this message translates to:
  /// **'Unknown migration error.'**
  String get migrationUnknownError;

  /// No description provided for @migrationFailureLogTitle.
  ///
  /// In en, this message translates to:
  /// **'Failure log'**
  String get migrationFailureLogTitle;

  /// No description provided for @migrationRetryButton.
  ///
  /// In en, this message translates to:
  /// **'Retry Migration'**
  String get migrationRetryButton;

  /// No description provided for @migrationSkipButton.
  ///
  /// In en, this message translates to:
  /// **'Skip Migration and Start Fresh'**
  String get migrationSkipButton;

  /// No description provided for @migrationSkipDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Skip migration?'**
  String get migrationSkipDialogTitle;

  /// No description provided for @migrationSkipDialogMessage.
  ///
  /// In en, this message translates to:
  /// **'Kelivo will start with an empty chat database. Your old chat history stays on disk (renamed with a .retired suffix) but will NOT be migrated and will not appear in the app. Use your backup ZIP if you need to recover it later.'**
  String get migrationSkipDialogMessage;

  /// No description provided for @migrationSkipDialogCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get migrationSkipDialogCancel;

  /// No description provided for @migrationSkipDialogConfirm.
  ///
  /// In en, this message translates to:
  /// **'Skip and Start Fresh'**
  String get migrationSkipDialogConfirm;

  /// No description provided for @migrationChatsExportDegradedNote.
  ///
  /// In en, this message translates to:
  /// **'The chats.json export was skipped because of an error. The backup ZIP still contains the raw Hive files with your complete chat history.'**
  String get migrationChatsExportDegradedNote;

  /// No description provided for @timelineJumpToLatest.
  ///
  /// In en, this message translates to:
  /// **'Jump to latest'**
  String get timelineJumpToLatest;

  /// No description provided for @largeContentShowMore.
  ///
  /// In en, this message translates to:
  /// **'Show {count} more'**
  String largeContentShowMore(int count);

  /// No description provided for @largeContentCollapse.
  ///
  /// In en, this message translates to:
  /// **'Collapse'**
  String get largeContentCollapse;

  /// No description provided for @imageSettingsPageTitle.
  ///
  /// In en, this message translates to:
  /// **'Image Processing'**
  String get imageSettingsPageTitle;

  /// No description provided for @imageSettingsPageEditSectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Editing'**
  String get imageSettingsPageEditSectionTitle;

  /// No description provided for @imageSettingsPageQualitySectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Upload Image Quality'**
  String get imageSettingsPageQualitySectionTitle;

  /// No description provided for @imageSettingsPageQualityOriginal.
  ///
  /// In en, this message translates to:
  /// **'Original'**
  String get imageSettingsPageQualityOriginal;

  /// No description provided for @imageSettingsPageQualityOriginalSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Don\'t compress; upload as-is'**
  String get imageSettingsPageQualityOriginalSubtitle;

  /// No description provided for @imageSettingsPageQualityHigh.
  ///
  /// In en, this message translates to:
  /// **'High Quality'**
  String get imageSettingsPageQualityHigh;

  /// No description provided for @imageSettingsPageQualityHighSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Long edge 2048 px · quality 90'**
  String get imageSettingsPageQualityHighSubtitle;

  /// No description provided for @imageSettingsPageQualityBalanced.
  ///
  /// In en, this message translates to:
  /// **'Balanced'**
  String get imageSettingsPageQualityBalanced;

  /// No description provided for @imageSettingsPageQualityBalancedSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Long edge 1568 px · quality 85'**
  String get imageSettingsPageQualityBalancedSubtitle;

  /// No description provided for @imageSettingsPageQualitySaver.
  ///
  /// In en, this message translates to:
  /// **'Data Saver'**
  String get imageSettingsPageQualitySaver;

  /// No description provided for @imageSettingsPageQualitySaverSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Long edge 1024 px · quality 70'**
  String get imageSettingsPageQualitySaverSubtitle;

  /// No description provided for @imageSettingsPageQualityCustom.
  ///
  /// In en, this message translates to:
  /// **'Custom'**
  String get imageSettingsPageQualityCustom;

  /// No description provided for @imageSettingsPageQualityCustomSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Choose the compression quality'**
  String get imageSettingsPageQualityCustomSubtitle;

  /// No description provided for @imageSettingsPageCustomQualityTitle.
  ///
  /// In en, this message translates to:
  /// **'Compression Quality'**
  String get imageSettingsPageCustomQualityTitle;

  /// No description provided for @imageSettingsPageCompressTransparentTitle.
  ///
  /// In en, this message translates to:
  /// **'Compress Transparent & Animated Images'**
  String get imageSettingsPageCompressTransparentTitle;

  /// No description provided for @imageSettingsPageCompressTransparentSubtitle.
  ///
  /// In en, this message translates to:
  /// **'When enabled, transparent PNG, GIF, and similar formats are compressed; transparent areas become white and animations keep only the first frame.'**
  String get imageSettingsPageCompressTransparentSubtitle;

  /// No description provided for @imageSettingsPageFooter.
  ///
  /// In en, this message translates to:
  /// **'Compression happens when images are added. Previously saved or sent images are not affected. Compressed images are sent as JPEG files.'**
  String get imageSettingsPageFooter;

  /// No description provided for @memoryTraceSettingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Pipeline Traces'**
  String get memoryTraceSettingsTitle;

  /// No description provided for @memoryTraceSettingsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Inspect every background memory run step by step'**
  String get memoryTraceSettingsSubtitle;

  /// No description provided for @memoryTracePageTitle.
  ///
  /// In en, this message translates to:
  /// **'Memory Pipeline Traces'**
  String get memoryTracePageTitle;

  /// No description provided for @memoryTraceRecordingSection.
  ///
  /// In en, this message translates to:
  /// **'Recording'**
  String get memoryTraceRecordingSection;

  /// No description provided for @memoryTraceToggleTitle.
  ///
  /// In en, this message translates to:
  /// **'Record pipeline traces'**
  String get memoryTraceToggleTitle;

  /// No description provided for @memoryTraceToggleSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Keeps prompts, responses and changes of recent background runs in memory only'**
  String get memoryTraceToggleSubtitle;

  /// No description provided for @memoryTraceRunsSection.
  ///
  /// In en, this message translates to:
  /// **'Recent runs'**
  String get memoryTraceRunsSection;

  /// No description provided for @memoryTraceEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No traces yet'**
  String get memoryTraceEmptyTitle;

  /// No description provided for @memoryTraceEmptySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Traces appear here after the background memory pipeline runs.'**
  String get memoryTraceEmptySubtitle;

  /// No description provided for @memoryTraceDisabledTitle.
  ///
  /// In en, this message translates to:
  /// **'Recording is off'**
  String get memoryTraceDisabledTitle;

  /// No description provided for @memoryTraceDisabledSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Turn recording on to capture the next background memory run.'**
  String get memoryTraceDisabledSubtitle;

  /// No description provided for @memoryTraceClearAction.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get memoryTraceClearAction;

  /// No description provided for @memoryTraceClearSheetTitle.
  ///
  /// In en, this message translates to:
  /// **'Clear traces'**
  String get memoryTraceClearSheetTitle;

  /// No description provided for @memoryTraceClearSheetMessage.
  ///
  /// In en, this message translates to:
  /// **'This removes every recorded trace. Traces are never written to disk, so nothing else is affected.'**
  String get memoryTraceClearSheetMessage;

  /// No description provided for @memoryTraceClearConfirm.
  ///
  /// In en, this message translates to:
  /// **'Clear traces'**
  String get memoryTraceClearConfirm;

  /// No description provided for @memoryTraceCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get memoryTraceCancel;

  /// No description provided for @memoryTraceClearedToast.
  ///
  /// In en, this message translates to:
  /// **'Traces cleared'**
  String get memoryTraceClearedToast;

  /// No description provided for @memoryTraceCopyAction.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get memoryTraceCopyAction;

  /// No description provided for @memoryTraceCopiedToast.
  ///
  /// In en, this message translates to:
  /// **'Copied to clipboard'**
  String get memoryTraceCopiedToast;

  /// No description provided for @memoryTraceTriggerAuto.
  ///
  /// In en, this message translates to:
  /// **'Auto'**
  String get memoryTraceTriggerAuto;

  /// No description provided for @memoryTraceTriggerManual.
  ///
  /// In en, this message translates to:
  /// **'Manual'**
  String get memoryTraceTriggerManual;

  /// No description provided for @memoryTraceTriggerTool.
  ///
  /// In en, this message translates to:
  /// **'Tool call'**
  String get memoryTraceTriggerTool;

  /// No description provided for @memoryTraceTriggerSummary.
  ///
  /// In en, this message translates to:
  /// **'Summary'**
  String get memoryTraceTriggerSummary;

  /// No description provided for @memoryTraceScopeAssistant.
  ///
  /// In en, this message translates to:
  /// **'Assistant'**
  String get memoryTraceScopeAssistant;

  /// No description provided for @memoryTraceScopeGlobal.
  ///
  /// In en, this message translates to:
  /// **'Global'**
  String get memoryTraceScopeGlobal;

  /// No description provided for @memoryTraceStepGatekeeper.
  ///
  /// In en, this message translates to:
  /// **'Gatekeeper'**
  String get memoryTraceStepGatekeeper;

  /// No description provided for @memoryTraceStepExtract.
  ///
  /// In en, this message translates to:
  /// **'Extract'**
  String get memoryTraceStepExtract;

  /// No description provided for @memoryTraceStepSmartAdd.
  ///
  /// In en, this message translates to:
  /// **'Smart Add'**
  String get memoryTraceStepSmartAdd;

  /// No description provided for @memoryTraceStepDistiller.
  ///
  /// In en, this message translates to:
  /// **'Profile Distiller'**
  String get memoryTraceStepDistiller;

  /// No description provided for @memoryTraceStepSummary.
  ///
  /// In en, this message translates to:
  /// **'Conversation Summary'**
  String get memoryTraceStepSummary;

  /// No description provided for @memoryTraceStepChatSearch.
  ///
  /// In en, this message translates to:
  /// **'Past Conversation Recall'**
  String get memoryTraceStepChatSearch;

  /// No description provided for @memoryTraceStepTool.
  ///
  /// In en, this message translates to:
  /// **'Memory Tool'**
  String get memoryTraceStepTool;

  /// No description provided for @memoryTraceStatusSuccess.
  ///
  /// In en, this message translates to:
  /// **'Success'**
  String get memoryTraceStatusSuccess;

  /// No description provided for @memoryTraceStatusFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed'**
  String get memoryTraceStatusFailed;

  /// No description provided for @memoryTraceStatusSkipped.
  ///
  /// In en, this message translates to:
  /// **'Skipped'**
  String get memoryTraceStatusSkipped;

  /// No description provided for @memoryTraceStatusRunning.
  ///
  /// In en, this message translates to:
  /// **'Running'**
  String get memoryTraceStatusRunning;

  /// No description provided for @memoryTraceOutcomeAdvanced.
  ///
  /// In en, this message translates to:
  /// **'Watermark advanced'**
  String get memoryTraceOutcomeAdvanced;

  /// No description provided for @memoryTraceOutcomeHeld.
  ///
  /// In en, this message translates to:
  /// **'Watermark held'**
  String get memoryTraceOutcomeHeld;

  /// No description provided for @memoryTraceOutcomeForced.
  ///
  /// In en, this message translates to:
  /// **'Forced advance'**
  String get memoryTraceOutcomeForced;

  /// No description provided for @memoryTraceDetailTitle.
  ///
  /// In en, this message translates to:
  /// **'Trace detail'**
  String get memoryTraceDetailTitle;

  /// No description provided for @memoryTraceSectionOverview.
  ///
  /// In en, this message translates to:
  /// **'Overview'**
  String get memoryTraceSectionOverview;

  /// No description provided for @memoryTraceSectionPrompt.
  ///
  /// In en, this message translates to:
  /// **'Prompt'**
  String get memoryTraceSectionPrompt;

  /// No description provided for @memoryTraceSectionResponse.
  ///
  /// In en, this message translates to:
  /// **'Raw response'**
  String get memoryTraceSectionResponse;

  /// No description provided for @memoryTraceSectionParsed.
  ///
  /// In en, this message translates to:
  /// **'Parsed result'**
  String get memoryTraceSectionParsed;

  /// No description provided for @memoryTraceSectionMutations.
  ///
  /// In en, this message translates to:
  /// **'Changes applied'**
  String get memoryTraceSectionMutations;

  /// No description provided for @memoryTraceFieldTime.
  ///
  /// In en, this message translates to:
  /// **'Started'**
  String get memoryTraceFieldTime;

  /// No description provided for @memoryTraceFieldDuration.
  ///
  /// In en, this message translates to:
  /// **'Duration'**
  String get memoryTraceFieldDuration;

  /// No description provided for @memoryTraceFieldTrigger.
  ///
  /// In en, this message translates to:
  /// **'Trigger'**
  String get memoryTraceFieldTrigger;

  /// No description provided for @memoryTraceFieldScope.
  ///
  /// In en, this message translates to:
  /// **'Scope'**
  String get memoryTraceFieldScope;

  /// No description provided for @memoryTraceFieldConversation.
  ///
  /// In en, this message translates to:
  /// **'Chat'**
  String get memoryTraceFieldConversation;

  /// No description provided for @memoryTraceFieldAssistant.
  ///
  /// In en, this message translates to:
  /// **'Assistant'**
  String get memoryTraceFieldAssistant;

  /// No description provided for @memoryTraceFieldWindow.
  ///
  /// In en, this message translates to:
  /// **'Window'**
  String get memoryTraceFieldWindow;

  /// No description provided for @memoryTraceFieldWatermark.
  ///
  /// In en, this message translates to:
  /// **'Watermark'**
  String get memoryTraceFieldWatermark;

  /// No description provided for @memoryTraceFieldOutcome.
  ///
  /// In en, this message translates to:
  /// **'Outcome'**
  String get memoryTraceFieldOutcome;

  /// No description provided for @memoryTraceFieldError.
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get memoryTraceFieldError;

  /// No description provided for @memoryTraceMutationCreated.
  ///
  /// In en, this message translates to:
  /// **'Created'**
  String get memoryTraceMutationCreated;

  /// No description provided for @memoryTraceMutationMerged.
  ///
  /// In en, this message translates to:
  /// **'Merged'**
  String get memoryTraceMutationMerged;

  /// No description provided for @memoryTraceMutationEdited.
  ///
  /// In en, this message translates to:
  /// **'Edited'**
  String get memoryTraceMutationEdited;

  /// No description provided for @memoryTraceMutationArchived.
  ///
  /// In en, this message translates to:
  /// **'Archived'**
  String get memoryTraceMutationArchived;

  /// No description provided for @memoryTraceMutationLinked.
  ///
  /// In en, this message translates to:
  /// **'Linked'**
  String get memoryTraceMutationLinked;

  /// No description provided for @memoryTraceMutationProfileWritten.
  ///
  /// In en, this message translates to:
  /// **'Profile field written'**
  String get memoryTraceMutationProfileWritten;

  /// No description provided for @memoryTraceMutationProfileCleared.
  ///
  /// In en, this message translates to:
  /// **'Profile field cleared'**
  String get memoryTraceMutationProfileCleared;

  /// No description provided for @memoryTraceMutationSummary.
  ///
  /// In en, this message translates to:
  /// **'Chat summary written'**
  String get memoryTraceMutationSummary;

  /// No description provided for @memoryTraceBefore.
  ///
  /// In en, this message translates to:
  /// **'Before'**
  String get memoryTraceBefore;

  /// No description provided for @memoryTraceAfter.
  ///
  /// In en, this message translates to:
  /// **'After'**
  String get memoryTraceAfter;

  /// No description provided for @memoryTraceEmptyValue.
  ///
  /// In en, this message translates to:
  /// **'(empty)'**
  String get memoryTraceEmptyValue;

  /// No description provided for @memoryTraceStepsCount.
  ///
  /// In en, this message translates to:
  /// **'{count} steps'**
  String memoryTraceStepsCount(int count);

  /// No description provided for @memoryTraceMutationsCount.
  ///
  /// In en, this message translates to:
  /// **'{count} changes'**
  String memoryTraceMutationsCount(int count);

  /// No description provided for @memoryTraceRepeatCount.
  ///
  /// In en, this message translates to:
  /// **'repeated {count}×'**
  String memoryTraceRepeatCount(int count);

  /// No description provided for @memoryTraceWindowValue.
  ///
  /// In en, this message translates to:
  /// **'{size} messages · #{start}–#{end}'**
  String memoryTraceWindowValue(int size, int start, int end);

  /// No description provided for @memoryTraceShowMore.
  ///
  /// In en, this message translates to:
  /// **'Show full text'**
  String get memoryTraceShowMore;

  /// No description provided for @memoryTraceShowLess.
  ///
  /// In en, this message translates to:
  /// **'Collapse'**
  String get memoryTraceShowLess;

  /// No description provided for @messageStyleSettingsPageTitle.
  ///
  /// In en, this message translates to:
  /// **'Message Style'**
  String get messageStyleSettingsPageTitle;

  /// No description provided for @messageStyleSettingsPageReset.
  ///
  /// In en, this message translates to:
  /// **'Reset'**
  String get messageStyleSettingsPageReset;

  /// No description provided for @messageStyleSettingsPageResetConfirm.
  ///
  /// In en, this message translates to:
  /// **'Reset all message style customizations?'**
  String get messageStyleSettingsPageResetConfirm;

  /// No description provided for @messageStyleSettingsPageCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get messageStyleSettingsPageCancel;

  /// No description provided for @messageStyleSettingsPageLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get messageStyleSettingsPageLight;

  /// No description provided for @messageStyleSettingsPageDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get messageStyleSettingsPageDark;

  /// No description provided for @messageStyleSettingsPageDefaultHint.
  ///
  /// In en, this message translates to:
  /// **'Default style follows the current theme and has no extra controls.'**
  String get messageStyleSettingsPageDefaultHint;

  /// No description provided for @messageStyleSettingsPageStyleDefaultSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Follows the theme; not customizable'**
  String get messageStyleSettingsPageStyleDefaultSubtitle;

  /// No description provided for @messageStyleSettingsPageAssistantFitContent.
  ///
  /// In en, this message translates to:
  /// **'Fit assistant bubble to content'**
  String get messageStyleSettingsPageAssistantFitContent;

  /// No description provided for @messageStyleSettingsPageAssistantFitContentSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Assistant bubbles hug their text instead of filling the row'**
  String get messageStyleSettingsPageAssistantFitContentSubtitle;

  /// No description provided for @messageStyleSettingsPageAssistantSplitParagraphs.
  ///
  /// In en, this message translates to:
  /// **'Split paragraphs into bubbles'**
  String get messageStyleSettingsPageAssistantSplitParagraphs;

  /// No description provided for @messageStyleSettingsPageAssistantSplitParagraphsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Blank lines break an assistant reply into one bubble per paragraph'**
  String get messageStyleSettingsPageAssistantSplitParagraphsSubtitle;

  /// No description provided for @messageStyleSettingsPageStyleFrostedSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Translucent frosted glass'**
  String get messageStyleSettingsPageStyleFrostedSubtitle;

  /// No description provided for @messageStyleSettingsPageStyleSolidSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Opaque solid fill'**
  String get messageStyleSettingsPageStyleSolidSubtitle;

  /// No description provided for @messageStyleSettingsPageBlur.
  ///
  /// In en, this message translates to:
  /// **'Blur'**
  String get messageStyleSettingsPageBlur;

  /// No description provided for @messageStyleSettingsPageBlurHint.
  ///
  /// In en, this message translates to:
  /// **'Blur applies to content behind the bubble. It is barely visible without a chat wallpaper.'**
  String get messageStyleSettingsPageBlurHint;

  /// No description provided for @messageStyleSettingsPageBackgroundColor.
  ///
  /// In en, this message translates to:
  /// **'Background'**
  String get messageStyleSettingsPageBackgroundColor;

  /// No description provided for @messageStyleSettingsPageBackgroundOpacity.
  ///
  /// In en, this message translates to:
  /// **'Background Opacity'**
  String get messageStyleSettingsPageBackgroundOpacity;

  /// No description provided for @messageStyleSettingsPageBorderColor.
  ///
  /// In en, this message translates to:
  /// **'Border'**
  String get messageStyleSettingsPageBorderColor;

  /// No description provided for @messageStyleSettingsPageBorderOpacity.
  ///
  /// In en, this message translates to:
  /// **'Border Opacity'**
  String get messageStyleSettingsPageBorderOpacity;

  /// No description provided for @messageStyleSettingsPageBorderWidth.
  ///
  /// In en, this message translates to:
  /// **'Border Width'**
  String get messageStyleSettingsPageBorderWidth;

  /// No description provided for @messageStyleSettingsPageTextColor.
  ///
  /// In en, this message translates to:
  /// **'Text'**
  String get messageStyleSettingsPageTextColor;

  /// No description provided for @messageStyleSettingsPageCornerRadius.
  ///
  /// In en, this message translates to:
  /// **'Corner Radius'**
  String get messageStyleSettingsPageCornerRadius;

  /// No description provided for @messageStyleSettingsPagePreviewUser.
  ///
  /// In en, this message translates to:
  /// **'This is a user message'**
  String get messageStyleSettingsPagePreviewUser;

  /// No description provided for @messageStyleSettingsPagePreviewAssistant.
  ///
  /// In en, this message translates to:
  /// **'This is an assistant reply.'**
  String get messageStyleSettingsPagePreviewAssistant;

  /// No description provided for @messageStyleSettingsPagePreviewThinking.
  ///
  /// In en, this message translates to:
  /// **'Thinking'**
  String get messageStyleSettingsPagePreviewThinking;

  /// No description provided for @messageStyleSettingsPageRoleUser.
  ///
  /// In en, this message translates to:
  /// **'User'**
  String get messageStyleSettingsPageRoleUser;

  /// No description provided for @messageStyleSettingsPageRoleAssistant.
  ///
  /// In en, this message translates to:
  /// **'Assistant'**
  String get messageStyleSettingsPageRoleAssistant;

  /// No description provided for @messageStyleSettingsPageRoleAssistantHint.
  ///
  /// In en, this message translates to:
  /// **'Assistant settings also apply to thinking, tool-call, and translation cards.'**
  String get messageStyleSettingsPageRoleAssistantHint;

  /// No description provided for @localSnapshotSectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Local Copies'**
  String get localSnapshotSectionTitle;

  /// No description provided for @localSnapshotEnabledTitle.
  ///
  /// In en, this message translates to:
  /// **'Keep local copies'**
  String get localSnapshotEnabledTitle;

  /// No description provided for @localSnapshotEnabledSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Kelivo periodically saves a copy of its database on this device, so it is never the only one.'**
  String get localSnapshotEnabledSubtitle;

  /// No description provided for @localSnapshotIntervalTitle.
  ///
  /// In en, this message translates to:
  /// **'How often'**
  String get localSnapshotIntervalTitle;

  /// No description provided for @localSnapshotIntervalAutomatic.
  ///
  /// In en, this message translates to:
  /// **'Automatic'**
  String get localSnapshotIntervalAutomatic;

  /// No description provided for @localSnapshotIntervalAutomaticDetail.
  ///
  /// In en, this message translates to:
  /// **'Daily, less often as the database grows'**
  String get localSnapshotIntervalAutomaticDetail;

  /// No description provided for @localSnapshotIntervalDays.
  ///
  /// In en, this message translates to:
  /// **'{days, plural, =1{Every day} other{Every {days} days}}'**
  String localSnapshotIntervalDays(int days);

  /// No description provided for @localSnapshotKeepTitle.
  ///
  /// In en, this message translates to:
  /// **'Copies to keep'**
  String get localSnapshotKeepTitle;

  /// No description provided for @localSnapshotKeepValue.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 copy} other{{count} copies}}'**
  String localSnapshotKeepValue(int count);

  /// No description provided for @localSnapshotKeepSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Plus one from last week and one from last month, so a problem that went unnoticed is still recoverable.'**
  String get localSnapshotKeepSubtitle;

  /// No description provided for @localSnapshotKeepWeekly.
  ///
  /// In en, this message translates to:
  /// **'Keep one from last week'**
  String get localSnapshotKeepWeekly;

  /// No description provided for @localSnapshotKeepMonthly.
  ///
  /// In en, this message translates to:
  /// **'Keep one from last month'**
  String get localSnapshotKeepMonthly;

  /// No description provided for @localSnapshotKeepProtectedNote.
  ///
  /// In en, this message translates to:
  /// **'The most recent copy that still contains data is never removed automatically, whatever this is set to.'**
  String get localSnapshotKeepProtectedNote;

  /// No description provided for @localSnapshotMaximumTitle.
  ///
  /// In en, this message translates to:
  /// **'Space limit'**
  String get localSnapshotMaximumTitle;

  /// No description provided for @localSnapshotMaximumUnlimited.
  ///
  /// In en, this message translates to:
  /// **'No limit'**
  String get localSnapshotMaximumUnlimited;

  /// No description provided for @localSnapshotAnnounceTitle.
  ///
  /// In en, this message translates to:
  /// **'Notify when a copy is saved'**
  String get localSnapshotAnnounceTitle;

  /// No description provided for @localSnapshotAnnounceSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Failures are always reported. This only adds a brief message on success.'**
  String get localSnapshotAnnounceSubtitle;

  /// No description provided for @localSnapshotTakeNow.
  ///
  /// In en, this message translates to:
  /// **'Save a copy now'**
  String get localSnapshotTakeNow;

  /// No description provided for @localSnapshotManageCopies.
  ///
  /// In en, this message translates to:
  /// **'Manage copies'**
  String get localSnapshotManageCopies;

  /// No description provided for @localSnapshotUsage.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No copies} =1{1 copy} other{{count} copies}} · {size}'**
  String localSnapshotUsage(int count, String size);

  /// No description provided for @localSnapshotStatusNever.
  ///
  /// In en, this message translates to:
  /// **'No copy saved yet'**
  String get localSnapshotStatusNever;

  /// No description provided for @localSnapshotStatusSuccess.
  ///
  /// In en, this message translates to:
  /// **'Last copy {when}'**
  String localSnapshotStatusSuccess(String when);

  /// No description provided for @localSnapshotStatusFailure.
  ///
  /// In en, this message translates to:
  /// **'Last attempt failed {when}: {reason}'**
  String localSnapshotStatusFailure(String when, String reason);

  /// No description provided for @localSnapshotStatusSkippedSpace.
  ///
  /// In en, this message translates to:
  /// **'Skipped: not enough free space on this device'**
  String get localSnapshotStatusSkippedSpace;

  /// No description provided for @localSnapshotStatusUnchanged.
  ///
  /// In en, this message translates to:
  /// **'Nothing has changed since the last copy'**
  String get localSnapshotStatusUnchanged;

  /// No description provided for @localSnapshotCopiesTitle.
  ///
  /// In en, this message translates to:
  /// **'Local Copies'**
  String get localSnapshotCopiesTitle;

  /// No description provided for @localSnapshotCopiesEmpty.
  ///
  /// In en, this message translates to:
  /// **'No local copies yet'**
  String get localSnapshotCopiesEmpty;

  /// No description provided for @localSnapshotCopiesEmptyHint.
  ///
  /// In en, this message translates to:
  /// **'A copy is saved automatically as your data changes, and one is always saved before a restore.'**
  String get localSnapshotCopiesEmptyHint;

  /// No description provided for @localSnapshotCopiesScopeNote.
  ///
  /// In en, this message translates to:
  /// **'Local copies live on this device only. They protect against damage to your data inside the app, not against losing the device or uninstalling Kelivo — use WebDAV or S3 backup for that.'**
  String get localSnapshotCopiesScopeNote;

  /// No description provided for @localSnapshotOriginAutomatic.
  ///
  /// In en, this message translates to:
  /// **'Automatic'**
  String get localSnapshotOriginAutomatic;

  /// No description provided for @localSnapshotOriginManual.
  ///
  /// In en, this message translates to:
  /// **'Saved by you'**
  String get localSnapshotOriginManual;

  /// No description provided for @localSnapshotOriginBeforeRestore.
  ///
  /// In en, this message translates to:
  /// **'Before a restore'**
  String get localSnapshotOriginBeforeRestore;

  /// No description provided for @localSnapshotKindRecovered.
  ///
  /// In en, this message translates to:
  /// **'Set aside by recovery'**
  String get localSnapshotKindRecovered;

  /// No description provided for @localSnapshotCopyContents.
  ///
  /// In en, this message translates to:
  /// **'{conversations, plural, =1{1 chat} other{{conversations} chats}} · {messages, plural, =1{1 message} other{{messages} messages}}'**
  String localSnapshotCopyContents(int conversations, int messages);

  /// No description provided for @localSnapshotCopyContentsUnknown.
  ///
  /// In en, this message translates to:
  /// **'Contents unknown until restored'**
  String get localSnapshotCopyContentsUnknown;

  /// No description provided for @localSnapshotCopyPinned.
  ///
  /// In en, this message translates to:
  /// **'Kept'**
  String get localSnapshotCopyPinned;

  /// No description provided for @localSnapshotActionRestore.
  ///
  /// In en, this message translates to:
  /// **'Restore'**
  String get localSnapshotActionRestore;

  /// No description provided for @localSnapshotActionExport.
  ///
  /// In en, this message translates to:
  /// **'Export'**
  String get localSnapshotActionExport;

  /// No description provided for @localSnapshotActionDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get localSnapshotActionDelete;

  /// No description provided for @localSnapshotActionPin.
  ///
  /// In en, this message translates to:
  /// **'Keep this copy'**
  String get localSnapshotActionPin;

  /// No description provided for @localSnapshotActionUnpin.
  ///
  /// In en, this message translates to:
  /// **'Stop keeping'**
  String get localSnapshotActionUnpin;

  /// No description provided for @localSnapshotRestoreTitle.
  ///
  /// In en, this message translates to:
  /// **'Restore this copy?'**
  String get localSnapshotRestoreTitle;

  /// No description provided for @localSnapshotRestoreMessage.
  ///
  /// In en, this message translates to:
  /// **'Your current chats and settings will be replaced by this copy from {when}. A copy of what you have now is saved first, so this can be undone.'**
  String localSnapshotRestoreMessage(String when);

  /// No description provided for @localSnapshotRestorePreparing.
  ///
  /// In en, this message translates to:
  /// **'Preparing copy'**
  String get localSnapshotRestorePreparing;

  /// No description provided for @localSnapshotDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete this copy?'**
  String get localSnapshotDeleteTitle;

  /// No description provided for @localSnapshotDeleteMessage.
  ///
  /// In en, this message translates to:
  /// **'This copy will be removed from the device permanently. Any data it holds that is not in your current database will be gone.'**
  String get localSnapshotDeleteMessage;

  /// No description provided for @localSnapshotDeleteLastWarning.
  ///
  /// In en, this message translates to:
  /// **'This is the only copy that still contains data.'**
  String get localSnapshotDeleteLastWarning;

  /// No description provided for @localSnapshotExportPreparing.
  ///
  /// In en, this message translates to:
  /// **'Preparing export'**
  String get localSnapshotExportPreparing;

  /// No description provided for @localSnapshotExportDone.
  ///
  /// In en, this message translates to:
  /// **'Copy exported'**
  String get localSnapshotExportDone;

  /// No description provided for @localSnapshotExportFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not export the copy: {reason}'**
  String localSnapshotExportFailed(String reason);

  /// No description provided for @localSnapshotTakeDone.
  ///
  /// In en, this message translates to:
  /// **'Copy saved'**
  String get localSnapshotTakeDone;

  /// No description provided for @localSnapshotTakeFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not save a copy: {reason}'**
  String localSnapshotTakeFailed(String reason);

  /// No description provided for @localSnapshotDeleteDone.
  ///
  /// In en, this message translates to:
  /// **'Copy deleted'**
  String get localSnapshotDeleteDone;

  /// No description provided for @localSnapshotBusyMessage.
  ///
  /// In en, this message translates to:
  /// **'Another backup task is already running'**
  String get localSnapshotBusyMessage;

  /// No description provided for @localSnapshotRunInBackground.
  ///
  /// In en, this message translates to:
  /// **'Continue in background'**
  String get localSnapshotRunInBackground;

  /// No description provided for @localSnapshotRunningInBackground.
  ///
  /// In en, this message translates to:
  /// **'Saving a copy in the background'**
  String get localSnapshotRunningInBackground;

  /// No description provided for @startupRecoveryLocalCopiesAvailable.
  ///
  /// In en, this message translates to:
  /// **'This device still holds {count, plural, =1{1 local copy} other{{count} local copies}}, the most recent from {when}. Resetting does not delete them — after restarting you can restore one from Settings › Backup › Local Copies.'**
  String startupRecoveryLocalCopiesAvailable(int count, String when);

  /// No description provided for @startupRecoveryRecoveredCopiesDeleted.
  ///
  /// In en, this message translates to:
  /// **'It also holds {count, plural, =1{1 database copy} other{{count} database copies}} set aside by an earlier repair, and resetting DOES delete {count, plural, =1{it} other{those}} permanently. Export your data first if you want to keep {count, plural, =1{it} other{them}}.'**
  String startupRecoveryRecoveredCopiesDeleted(int count);

  /// No description provided for @toolSchemaSettingsPageTitle.
  ///
  /// In en, this message translates to:
  /// **'Tool Descriptions'**
  String get toolSchemaSettingsPageTitle;

  /// No description provided for @toolSchemaSettingsGroupSearch.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get toolSchemaSettingsGroupSearch;

  /// No description provided for @toolSchemaSettingsGroupMemory.
  ///
  /// In en, this message translates to:
  /// **'Memory'**
  String get toolSchemaSettingsGroupMemory;

  /// No description provided for @toolSchemaSettingsGroupLocal.
  ///
  /// In en, this message translates to:
  /// **'Device tools'**
  String get toolSchemaSettingsGroupLocal;

  /// No description provided for @toolSchemaSettingsModified.
  ///
  /// In en, this message translates to:
  /// **'Modified'**
  String get toolSchemaSettingsModified;

  /// No description provided for @toolSchemaSettingsResetDefault.
  ///
  /// In en, this message translates to:
  /// **'Restore default'**
  String get toolSchemaSettingsResetDefault;

  /// No description provided for @toolSchemaSettingsResetAll.
  ///
  /// In en, this message translates to:
  /// **'Restore all defaults'**
  String get toolSchemaSettingsResetAll;

  /// No description provided for @toolSchemaSettingsResetAllTitle.
  ///
  /// In en, this message translates to:
  /// **'Restore all defaults?'**
  String get toolSchemaSettingsResetAllTitle;

  /// No description provided for @toolSchemaSettingsResetAllMessage.
  ///
  /// In en, this message translates to:
  /// **'This restores every built-in tool description to the app default. Your custom wording will be lost.'**
  String get toolSchemaSettingsResetAllMessage;

  /// No description provided for @toolSchemaSettingsResetAllConfirm.
  ///
  /// In en, this message translates to:
  /// **'Restore'**
  String get toolSchemaSettingsResetAllConfirm;

  /// No description provided for @toolSchemaSettingsParamDescriptions.
  ///
  /// In en, this message translates to:
  /// **'Parameter descriptions ({count})'**
  String toolSchemaSettingsParamDescriptions(int count);

  /// No description provided for @toolSchemaSettingsMemoryLangNote.
  ///
  /// In en, this message translates to:
  /// **'Memory tool defaults follow the memory prompt language. A custom description is stored once per tool and will not switch when you change that language.'**
  String get toolSchemaSettingsMemoryLangNote;

  /// No description provided for @toolSchemaSettingsDescriptionLabel.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get toolSchemaSettingsDescriptionLabel;

  /// No description provided for @toolSchemaSettingsToolName.
  ///
  /// In en, this message translates to:
  /// **'Tool name'**
  String get toolSchemaSettingsToolName;

  /// No description provided for @toolSchemaEditorPageTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit description'**
  String get toolSchemaEditorPageTitle;

  /// No description provided for @toolSchemaSettingsCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get toolSchemaSettingsCancel;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when language+script codes are specified.
  switch (locale.languageCode) {
    case 'zh':
      {
        switch (locale.scriptCode) {
          case 'Hans':
            return AppLocalizationsZhHans();
          case 'Hant':
            return AppLocalizationsZhHant();
        }
        break;
      }
  }

  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
