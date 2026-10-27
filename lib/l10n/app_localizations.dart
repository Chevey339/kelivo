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

  /// No description provided for @settingsSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search settings'**
  String get settingsSearchHint;

  /// No description provided for @settingsSearchCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get settingsSearchCancel;

  /// No description provided for @settingsSearchClear.
  ///
  /// In en, this message translates to:
  /// **'Clear search'**
  String get settingsSearchClear;

  /// No description provided for @settingsSearchSuggestions.
  ///
  /// In en, this message translates to:
  /// **'Quick access'**
  String get settingsSearchSuggestions;

  /// No description provided for @settingsSearchNoResults.
  ///
  /// In en, this message translates to:
  /// **'No settings found'**
  String get settingsSearchNoResults;

  /// No description provided for @settingsSearchNoResultsHint.
  ///
  /// In en, this message translates to:
  /// **'Try a different name or a shorter keyword.'**
  String get settingsSearchNoResultsHint;

  /// No description provided for @settingsSearchResultCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 result} other{{count} results}}'**
  String settingsSearchResultCount(int count);

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
  /// **'Could not load files or check which images are in use. Please refresh and try again.'**
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
  /// **'Delete {count} items and their associated conversation attachment copies? These attachments will no longer be available in chat history.'**
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

  /// No description provided for @statsPageCost.
  ///
  /// In en, this message translates to:
  /// **'Cost ({currency})'**
  String statsPageCost(String currency);

  /// No description provided for @statsPageModelsWithoutPricing.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} model without pricing} other{{count} models without pricing}}'**
  String statsPageModelsWithoutPricing(int count);

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

  /// No description provided for @contextMessageCount.
  ///
  /// In en, this message translates to:
  /// **'{count} messages'**
  String contextMessageCount(int count);

  /// No description provided for @contextMessageCountLimited.
  ///
  /// In en, this message translates to:
  /// **'{actual}/{configured} messages'**
  String contextMessageCountLimited(int actual, int configured);

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

  /// No description provided for @mcpWorkspaceBindingLabel.
  ///
  /// In en, this message translates to:
  /// **'Bind workspace (optional)'**
  String get mcpWorkspaceBindingLabel;

  /// No description provided for @mcpWorkspaceBindingHint.
  ///
  /// In en, this message translates to:
  /// **'The server can access this workspace at /workspace. Leave Working Directory empty to start there. The binding stays fixed when you switch chats.'**
  String get mcpWorkspaceBindingHint;

  /// No description provided for @mcpWorkspaceBindingMobileOnly.
  ///
  /// In en, this message translates to:
  /// **'Workspace binding is available in the mobile Linux environment. Unbind it to run this server on desktop.'**
  String get mcpWorkspaceBindingMobileOnly;

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
  /// **'Thinking'**
  String get assistantEditThinkingBudgetTitle;

  /// No description provided for @assistantEditReasoningFollowDefault.
  ///
  /// In en, this message translates to:
  /// **'Follow model default'**
  String get assistantEditReasoningFollowDefault;

  /// No description provided for @assistantEditReasoningClampedSubtitle.
  ///
  /// In en, this message translates to:
  /// **'The actual level is clamped to what each model supports'**
  String get assistantEditReasoningClampedSubtitle;

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

  /// No description provided for @assistantEditPromptIso8601Title.
  ///
  /// In en, this message translates to:
  /// **'Use ISO 8601 format'**
  String get assistantEditPromptIso8601Title;

  /// No description provided for @assistantEditPromptIso8601Subtitle.
  ///
  /// In en, this message translates to:
  /// **'Include the time zone offset, e.g. 2026-08-08T14:30:05+08:00'**
  String get assistantEditPromptIso8601Subtitle;

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

  /// No description provided for @backupPageScopeTitle.
  ///
  /// In en, this message translates to:
  /// **'Backup and import content'**
  String get backupPageScopeTitle;

  /// No description provided for @backupPageScopeSelectedCount.
  ///
  /// In en, this message translates to:
  /// **'{selected}/{total}'**
  String backupPageScopeSelectedCount(int selected, int total);

  /// No description provided for @backupPageBackupManagementDescription.
  ///
  /// In en, this message translates to:
  /// **'Choose what to back up and import. Applies to local, WebDAV and S3 backups. Unselected content stays unchanged on import. Skills and workspaces include their own files.'**
  String get backupPageBackupManagementDescription;

  /// No description provided for @backupPageAssistantsLabel.
  ///
  /// In en, this message translates to:
  /// **'Assistants'**
  String get backupPageAssistantsLabel;

  /// No description provided for @backupPageProvidersLabel.
  ///
  /// In en, this message translates to:
  /// **'Providers'**
  String get backupPageProvidersLabel;

  /// No description provided for @backupPageMcpLabel.
  ///
  /// In en, this message translates to:
  /// **'MCP servers'**
  String get backupPageMcpLabel;

  /// No description provided for @backupPageEnvironmentVariablesLabel.
  ///
  /// In en, this message translates to:
  /// **'Environment variables'**
  String get backupPageEnvironmentVariablesLabel;

  /// No description provided for @backupPageSkillsLabel.
  ///
  /// In en, this message translates to:
  /// **'Skills'**
  String get backupPageSkillsLabel;

  /// No description provided for @backupPageWorldBooksLabel.
  ///
  /// In en, this message translates to:
  /// **'World books'**
  String get backupPageWorldBooksLabel;

  /// No description provided for @backupPageMemoriesLabel.
  ///
  /// In en, this message translates to:
  /// **'Memories'**
  String get backupPageMemoriesLabel;

  /// No description provided for @backupPageQuickPhrasesLabel.
  ///
  /// In en, this message translates to:
  /// **'Quick phrases'**
  String get backupPageQuickPhrasesLabel;

  /// No description provided for @backupPageInstructionsLabel.
  ///
  /// In en, this message translates to:
  /// **'Prompt injections'**
  String get backupPageInstructionsLabel;

  /// No description provided for @backupPageWorkspacesLabel.
  ///
  /// In en, this message translates to:
  /// **'Workspaces'**
  String get backupPageWorkspacesLabel;

  /// No description provided for @backupPageSearchServicesLabel.
  ///
  /// In en, this message translates to:
  /// **'Search services'**
  String get backupPageSearchServicesLabel;

  /// No description provided for @backupPageSpeechServicesLabel.
  ///
  /// In en, this message translates to:
  /// **'Speech services'**
  String get backupPageSpeechServicesLabel;

  /// No description provided for @backupPageSettingsLabel.
  ///
  /// In en, this message translates to:
  /// **'Other settings'**
  String get backupPageSettingsLabel;

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

  /// No description provided for @backupRestoreDirectoryBlockedTitle.
  ///
  /// In en, this message translates to:
  /// **'Restore is waiting for a folder'**
  String get backupRestoreDirectoryBlockedTitle;

  /// No description provided for @backupRestoreDirectoryBlockedContent.
  ///
  /// In en, this message translates to:
  /// **'Windows could not move the folder below. Close terminals, editors, or other programs using it, then continue restoring. If it is still blocked, check that your account can move the folder. Your restore progress has been kept.'**
  String get backupRestoreDirectoryBlockedContent;

  /// No description provided for @backupRestoreContinueButton.
  ///
  /// In en, this message translates to:
  /// **'Continue restore'**
  String get backupRestoreContinueButton;

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

  /// No description provided for @restoreProgressTitle.
  ///
  /// In en, this message translates to:
  /// **'Restoring your backup'**
  String get restoreProgressTitle;

  /// No description provided for @restoreProgressWarning.
  ///
  /// In en, this message translates to:
  /// **'Keep Kelivo open until this finishes. If you close it now, the next launch starts this over.'**
  String get restoreProgressWarning;

  /// No description provided for @restoreProgressStageCheckingBackup.
  ///
  /// In en, this message translates to:
  /// **'Checking the backup'**
  String get restoreProgressStageCheckingBackup;

  /// No description provided for @restoreProgressStagePreservingCurrentData.
  ///
  /// In en, this message translates to:
  /// **'Preserving your current data'**
  String get restoreProgressStagePreservingCurrentData;

  /// No description provided for @restoreProgressStageInstallingBackup.
  ///
  /// In en, this message translates to:
  /// **'Installing the backup'**
  String get restoreProgressStageInstallingBackup;

  /// No description provided for @restoreProgressStageVerifying.
  ///
  /// In en, this message translates to:
  /// **'Verifying'**
  String get restoreProgressStageVerifying;

  /// No description provided for @restoreProgressStageRollingBack.
  ///
  /// In en, this message translates to:
  /// **'Restoring your previous data'**
  String get restoreProgressStageRollingBack;

  /// No description provided for @restoreProgressStageFinishing.
  ///
  /// In en, this message translates to:
  /// **'Finishing up'**
  String get restoreProgressStageFinishing;

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
  /// **'Repair could not complete. Your data is preserved; choose a validated copy or export your data for further diagnosis.'**
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
  /// **'Start with a new empty database? The current database, its journals and existing copies will be retained for recovery.'**
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
  /// **'A fresh start removes the current data from view. Kelivo will preserve the old database and existing copies for recovery. Export a data copy first if possible.'**
  String get startupRecoveryDangerBody;

  /// No description provided for @startupRecoveryResetAcknowledge.
  ///
  /// In en, this message translates to:
  /// **'I want to start with a new empty database.'**
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
  /// **'Choose a restore mode. The switches in Backup Management apply to this import.'**
  String get backupPageSelectImportModeDescription;

  /// No description provided for @backupPageOverwriteMode.
  ///
  /// In en, this message translates to:
  /// **'Complete Overwrite'**
  String get backupPageOverwriteMode;

  /// No description provided for @backupPageOverwriteModeDescription.
  ///
  /// In en, this message translates to:
  /// **'Replace the selected components; keep unselected components and unrelated local settings. Replacing chats also clears local unsent drafts.'**
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

  /// No description provided for @backupProgressFailed.
  ///
  /// In en, this message translates to:
  /// **'Operation failed'**
  String get backupProgressFailed;

  /// No description provided for @backupProgressFailedAt.
  ///
  /// In en, this message translates to:
  /// **'Failed during: {phase}'**
  String backupProgressFailedAt(String phase);

  /// No description provided for @backupProgressCopyError.
  ///
  /// In en, this message translates to:
  /// **'Copy error'**
  String get backupProgressCopyError;

  /// No description provided for @backupProgressErrorCopied.
  ///
  /// In en, this message translates to:
  /// **'Error copied'**
  String get backupProgressErrorCopied;

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

  /// No description provided for @backupPageIosSystemBackupNote.
  ///
  /// In en, this message translates to:
  /// **'Kelivo\'s local data is set to be excluded from iCloud device backups. Export a backup file before changing devices or deleting the app.'**
  String get backupPageIosSystemBackupNote;

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
  /// **'Create a summary you can review and undo'**
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
  /// **'Create an editable, reversible summary in this chat. Original messages are kept.'**
  String get compressContextOptionsDesc;

  /// No description provided for @compressContextKeepStart.
  ///
  /// In en, this message translates to:
  /// **'Start sample'**
  String get compressContextKeepStart;

  /// No description provided for @compressContextKeepRecent.
  ///
  /// In en, this message translates to:
  /// **'End sample'**
  String get compressContextKeepRecent;

  /// No description provided for @compressContextUnlimited.
  ///
  /// In en, this message translates to:
  /// **'All content'**
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
  /// **'Recent user messages'**
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

  /// No description provided for @reasoningBudgetSheetTitle.
  ///
  /// In en, this message translates to:
  /// **'Reasoning Chain Strength'**
  String get reasoningBudgetSheetTitle;

  /// No description provided for @reasoningLevelSheetTitle.
  ///
  /// In en, this message translates to:
  /// **'Reasoning'**
  String get reasoningLevelSheetTitle;

  /// No description provided for @reasoningLevelAuto.
  ///
  /// In en, this message translates to:
  /// **'Auto'**
  String get reasoningLevelAuto;

  /// No description provided for @reasoningLevelAutoSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Uses the model or provider default'**
  String get reasoningLevelAutoSubtitle;

  /// No description provided for @reasoningLevelOff.
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get reasoningLevelOff;

  /// No description provided for @reasoningLevelOffSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Turn off reasoning and answer directly'**
  String get reasoningLevelOffSubtitle;

  /// No description provided for @reasoningLevelMinimal.
  ///
  /// In en, this message translates to:
  /// **'Minimal'**
  String get reasoningLevelMinimal;

  /// No description provided for @reasoningLevelMinimalSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Use the lightest reasoning to answer questions'**
  String get reasoningLevelMinimalSubtitle;

  /// No description provided for @reasoningLevelLow.
  ///
  /// In en, this message translates to:
  /// **'Low'**
  String get reasoningLevelLow;

  /// No description provided for @reasoningLevelLowSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Use light reasoning to answer questions'**
  String get reasoningLevelLowSubtitle;

  /// No description provided for @reasoningLevelMedium.
  ///
  /// In en, this message translates to:
  /// **'Medium'**
  String get reasoningLevelMedium;

  /// No description provided for @reasoningLevelMediumSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Use moderate reasoning to answer questions'**
  String get reasoningLevelMediumSubtitle;

  /// No description provided for @reasoningLevelHigh.
  ///
  /// In en, this message translates to:
  /// **'High'**
  String get reasoningLevelHigh;

  /// No description provided for @reasoningLevelHighSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Use heavy reasoning for complex questions'**
  String get reasoningLevelHighSubtitle;

  /// No description provided for @reasoningLevelXhigh.
  ///
  /// In en, this message translates to:
  /// **'Extra High'**
  String get reasoningLevelXhigh;

  /// No description provided for @reasoningLevelXhighSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Use very high reasoning depth for harder problems'**
  String get reasoningLevelXhighSubtitle;

  /// No description provided for @reasoningLevelMax.
  ///
  /// In en, this message translates to:
  /// **'Max'**
  String get reasoningLevelMax;

  /// No description provided for @reasoningLevelMaxSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Use maximum reasoning depth for the toughest problems'**
  String get reasoningLevelMaxSubtitle;

  /// No description provided for @reasoningLevelFollowModelDefaultSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Use the model\'s default when the assistant doesn\'t set one'**
  String get reasoningLevelFollowModelDefaultSubtitle;

  /// No description provided for @reasoningLevelNoReasoning.
  ///
  /// In en, this message translates to:
  /// **'This model does not support reasoning'**
  String get reasoningLevelNoReasoning;

  /// No description provided for @reasoningLevelCustomBudget.
  ///
  /// In en, this message translates to:
  /// **'Custom Reasoning Budget'**
  String get reasoningLevelCustomBudget;

  /// No description provided for @reasoningLevelCustomBudgetHint.
  ///
  /// In en, this message translates to:
  /// **'Token budget, e.g. 2048'**
  String get reasoningLevelCustomBudgetHint;

  /// No description provided for @reasoningLevelCompactMin.
  ///
  /// In en, this message translates to:
  /// **'min'**
  String get reasoningLevelCompactMin;

  /// No description provided for @reasoningLevelCompactLow.
  ///
  /// In en, this message translates to:
  /// **'low'**
  String get reasoningLevelCompactLow;

  /// No description provided for @reasoningLevelCompactMid.
  ///
  /// In en, this message translates to:
  /// **'mid'**
  String get reasoningLevelCompactMid;

  /// No description provided for @reasoningLevelCompactHigh.
  ///
  /// In en, this message translates to:
  /// **'high'**
  String get reasoningLevelCompactHigh;

  /// No description provided for @reasoningLevelCompactXhigh.
  ///
  /// In en, this message translates to:
  /// **'xhigh'**
  String get reasoningLevelCompactXhigh;

  /// No description provided for @reasoningLevelCompactMax.
  ///
  /// In en, this message translates to:
  /// **'max'**
  String get reasoningLevelCompactMax;

  /// No description provided for @reasoningLevelBudgetTokens.
  ///
  /// In en, this message translates to:
  /// **'{budget} tokens'**
  String reasoningLevelBudgetTokens(String budget);

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

  /// No description provided for @chatMessageWidgetWebFetch.
  ///
  /// In en, this message translates to:
  /// **'Read page: {target}'**
  String chatMessageWidgetWebFetch(String target);

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

  /// No description provided for @displaySettingsPageCollapseLongUserMessagesTitle.
  ///
  /// In en, this message translates to:
  /// **'Collapse Long Messages'**
  String get displaySettingsPageCollapseLongUserMessagesTitle;

  /// No description provided for @displaySettingsPageCollapseLongUserMessagesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Fold user messages past the threshold behind an expand button'**
  String get displaySettingsPageCollapseLongUserMessagesSubtitle;

  /// No description provided for @displaySettingsPageCollapseLongUserMessagesCharsTitle.
  ///
  /// In en, this message translates to:
  /// **'Collapse threshold'**
  String get displaySettingsPageCollapseLongUserMessagesCharsTitle;

  /// No description provided for @displaySettingsPageCollapseLongUserMessagesCharsUnit.
  ///
  /// In en, this message translates to:
  /// **'chars'**
  String get displaySettingsPageCollapseLongUserMessagesCharsUnit;

  /// No description provided for @chatMessageExpandLongText.
  ///
  /// In en, this message translates to:
  /// **'Expand'**
  String get chatMessageExpandLongText;

  /// No description provided for @chatMessageCollapseLongText.
  ///
  /// In en, this message translates to:
  /// **'Collapse'**
  String get chatMessageCollapseLongText;

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

  /// No description provided for @chatInputBarToolsTooltip.
  ///
  /// In en, this message translates to:
  /// **'Tools'**
  String get chatInputBarToolsTooltip;

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

  /// No description provided for @chatInputBarVoiceAttachAudioTooltip.
  ///
  /// In en, this message translates to:
  /// **'Stop and attach as audio'**
  String get chatInputBarVoiceAttachAudioTooltip;

  /// No description provided for @chatInputBarVoiceSendAudioTooltip.
  ///
  /// In en, this message translates to:
  /// **'Send recording'**
  String get chatInputBarVoiceSendAudioTooltip;

  /// No description provided for @chatInputBarVoiceSavingAudio.
  ///
  /// In en, this message translates to:
  /// **'Saving audio…'**
  String get chatInputBarVoiceSavingAudio;

  /// No description provided for @audioClipPlayTooltip.
  ///
  /// In en, this message translates to:
  /// **'Play audio'**
  String get audioClipPlayTooltip;

  /// No description provided for @audioClipPauseTooltip.
  ///
  /// In en, this message translates to:
  /// **'Pause'**
  String get audioClipPauseTooltip;

  /// No description provided for @audioClipPlaybackFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t play this audio'**
  String get audioClipPlaybackFailed;

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

  /// No description provided for @contextUsageTitle.
  ///
  /// In en, this message translates to:
  /// **'Context window'**
  String get contextUsageTitle;

  /// No description provided for @contextUsageStateExact.
  ///
  /// In en, this message translates to:
  /// **'Exact (from last response)'**
  String get contextUsageStateExact;

  /// No description provided for @contextUsageStateExactCalibrated.
  ///
  /// In en, this message translates to:
  /// **'Exact (breakdown scaled from estimate)'**
  String get contextUsageStateExactCalibrated;

  /// No description provided for @contextUsageStateEstimated.
  ///
  /// In en, this message translates to:
  /// **'Estimated'**
  String get contextUsageStateEstimated;

  /// No description provided for @contextUsageStateStale.
  ///
  /// In en, this message translates to:
  /// **'Stale, updating…'**
  String get contextUsageStateStale;

  /// No description provided for @contextUsageStateComputing.
  ///
  /// In en, this message translates to:
  /// **'Computing…'**
  String get contextUsageStateComputing;

  /// No description provided for @contextUsageStateNone.
  ///
  /// In en, this message translates to:
  /// **'No data yet'**
  String get contextUsageStateNone;

  /// No description provided for @contextUsageBucketSystem.
  ///
  /// In en, this message translates to:
  /// **'System prompt'**
  String get contextUsageBucketSystem;

  /// No description provided for @contextUsageBucketInjections.
  ///
  /// In en, this message translates to:
  /// **'Instruction injections'**
  String get contextUsageBucketInjections;

  /// No description provided for @contextUsageBucketHistory.
  ///
  /// In en, this message translates to:
  /// **'Messages'**
  String get contextUsageBucketHistory;

  /// No description provided for @contextUsageBucketTools.
  ///
  /// In en, this message translates to:
  /// **'Built-in tools'**
  String get contextUsageBucketTools;

  /// No description provided for @contextUsageBucketMemory.
  ///
  /// In en, this message translates to:
  /// **'Memory'**
  String get contextUsageBucketMemory;

  /// No description provided for @contextUsageBucketWorldBook.
  ///
  /// In en, this message translates to:
  /// **'World books'**
  String get contextUsageBucketWorldBook;

  /// No description provided for @contextUsageBucketSkills.
  ///
  /// In en, this message translates to:
  /// **'Skills'**
  String get contextUsageBucketSkills;

  /// No description provided for @contextUsageBucketWorkspace.
  ///
  /// In en, this message translates to:
  /// **'Workspace'**
  String get contextUsageBucketWorkspace;

  /// No description provided for @contextUsageBucketSearch.
  ///
  /// In en, this message translates to:
  /// **'Search prompt'**
  String get contextUsageBucketSearch;

  /// No description provided for @contextUsageBucketMcpTools.
  ///
  /// In en, this message translates to:
  /// **'MCP tools'**
  String get contextUsageBucketMcpTools;

  /// No description provided for @contextUsageBucketAttachments.
  ///
  /// In en, this message translates to:
  /// **'Attachments'**
  String get contextUsageBucketAttachments;

  /// No description provided for @contextUsageBucketDraft.
  ///
  /// In en, this message translates to:
  /// **'Draft'**
  String get contextUsageBucketDraft;

  /// No description provided for @contextUsageBucketUsed.
  ///
  /// In en, this message translates to:
  /// **'Used'**
  String get contextUsageBucketUsed;

  /// No description provided for @contextUsageFreeSpace.
  ///
  /// In en, this message translates to:
  /// **'Free space'**
  String get contextUsageFreeSpace;

  /// Context usage summary: used tokens, window size, and percent
  ///
  /// In en, this message translates to:
  /// **'{used} / {window} ({percent}%)'**
  String contextUsageUsedWindow(String used, String window, int percent);

  /// No description provided for @contextUsageNoWindow.
  ///
  /// In en, this message translates to:
  /// **'No context window'**
  String get contextUsageNoWindow;

  /// No description provided for @contextUsageSetWindow.
  ///
  /// In en, this message translates to:
  /// **'Set context window'**
  String get contextUsageSetWindow;

  /// No description provided for @contextUsageRefresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get contextUsageRefresh;

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

  /// No description provided for @modelSpecFormSourceCustom.
  ///
  /// In en, this message translates to:
  /// **'Custom'**
  String get modelSpecFormSourceCustom;

  /// No description provided for @modelSpecFormSourceCatalog.
  ///
  /// In en, this message translates to:
  /// **'Catalog'**
  String get modelSpecFormSourceCatalog;

  /// No description provided for @modelSpecFormSourceInferred.
  ///
  /// In en, this message translates to:
  /// **'Inferred'**
  String get modelSpecFormSourceInferred;

  /// No description provided for @modelSpecFormSourceDefault.
  ///
  /// In en, this message translates to:
  /// **'Default'**
  String get modelSpecFormSourceDefault;

  /// No description provided for @modelSpecFormReset.
  ///
  /// In en, this message translates to:
  /// **'Reset to default'**
  String get modelSpecFormReset;

  /// No description provided for @modelSpecFormModalitiesSection.
  ///
  /// In en, this message translates to:
  /// **'Modalities & abilities'**
  String get modelSpecFormModalitiesSection;

  /// No description provided for @modelSpecFormImageType.
  ///
  /// In en, this message translates to:
  /// **'Image'**
  String get modelSpecFormImageType;

  /// No description provided for @modelSpecFormAudioMode.
  ///
  /// In en, this message translates to:
  /// **'Audio'**
  String get modelSpecFormAudioMode;

  /// No description provided for @modelSpecFormVideoMode.
  ///
  /// In en, this message translates to:
  /// **'Video'**
  String get modelSpecFormVideoMode;

  /// No description provided for @modelSpecFormPdfMode.
  ///
  /// In en, this message translates to:
  /// **'PDF'**
  String get modelSpecFormPdfMode;

  /// No description provided for @modelSpecFormStructuredOutputAbility.
  ///
  /// In en, this message translates to:
  /// **'Structured Output'**
  String get modelSpecFormStructuredOutputAbility;

  /// No description provided for @modelSpecFormReasoningSection.
  ///
  /// In en, this message translates to:
  /// **'Reasoning'**
  String get modelSpecFormReasoningSection;

  /// No description provided for @modelSpecFormDialect.
  ///
  /// In en, this message translates to:
  /// **'Dialect'**
  String get modelSpecFormDialect;

  /// No description provided for @modelSpecFormDialectNone.
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get modelSpecFormDialectNone;

  /// No description provided for @modelSpecFormDialectNoneSubtitle.
  ///
  /// In en, this message translates to:
  /// **'No reasoning fields'**
  String get modelSpecFormDialectNoneSubtitle;

  /// No description provided for @modelSpecFormDialectOpenaiReasoningEffort.
  ///
  /// In en, this message translates to:
  /// **'OpenAI reasoning effort'**
  String get modelSpecFormDialectOpenaiReasoningEffort;

  /// No description provided for @modelSpecFormDialectOpenaiReasoningEffortSubtitle.
  ///
  /// In en, this message translates to:
  /// **'reasoning_effort'**
  String get modelSpecFormDialectOpenaiReasoningEffortSubtitle;

  /// No description provided for @modelSpecFormDialectOpenaiResponsesReasoning.
  ///
  /// In en, this message translates to:
  /// **'OpenAI Responses reasoning'**
  String get modelSpecFormDialectOpenaiResponsesReasoning;

  /// No description provided for @modelSpecFormDialectOpenaiResponsesReasoningSubtitle.
  ///
  /// In en, this message translates to:
  /// **'reasoning.effort'**
  String get modelSpecFormDialectOpenaiResponsesReasoningSubtitle;

  /// No description provided for @modelSpecFormDialectOpenrouterReasoning.
  ///
  /// In en, this message translates to:
  /// **'OpenRouter reasoning'**
  String get modelSpecFormDialectOpenrouterReasoning;

  /// No description provided for @modelSpecFormDialectOpenrouterReasoningSubtitle.
  ///
  /// In en, this message translates to:
  /// **'reasoning'**
  String get modelSpecFormDialectOpenrouterReasoningSubtitle;

  /// No description provided for @modelSpecFormDialectAnthropicBudget.
  ///
  /// In en, this message translates to:
  /// **'Anthropic budget'**
  String get modelSpecFormDialectAnthropicBudget;

  /// No description provided for @modelSpecFormDialectAnthropicBudgetSubtitle.
  ///
  /// In en, this message translates to:
  /// **'thinking.budget_tokens'**
  String get modelSpecFormDialectAnthropicBudgetSubtitle;

  /// No description provided for @modelSpecFormDialectAnthropicAdaptiveEffort.
  ///
  /// In en, this message translates to:
  /// **'Anthropic adaptive effort'**
  String get modelSpecFormDialectAnthropicAdaptiveEffort;

  /// No description provided for @modelSpecFormDialectAnthropicAdaptiveEffortSubtitle.
  ///
  /// In en, this message translates to:
  /// **'thinking + output_config.effort'**
  String get modelSpecFormDialectAnthropicAdaptiveEffortSubtitle;

  /// No description provided for @modelSpecFormDialectAnthropicBetweenTools.
  ///
  /// In en, this message translates to:
  /// **'Anthropic adaptive / between_tools'**
  String get modelSpecFormDialectAnthropicBetweenTools;

  /// No description provided for @modelSpecFormDialectAnthropicBetweenToolsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Adaptive thinking; Off uses between_tools'**
  String get modelSpecFormDialectAnthropicBetweenToolsSubtitle;

  /// No description provided for @modelSpecFormDialectAnthropicEffort.
  ///
  /// In en, this message translates to:
  /// **'Anthropic effort'**
  String get modelSpecFormDialectAnthropicEffort;

  /// No description provided for @modelSpecFormDialectAnthropicEffortSubtitle.
  ///
  /// In en, this message translates to:
  /// **'thinking + output_config.effort'**
  String get modelSpecFormDialectAnthropicEffortSubtitle;

  /// No description provided for @modelSpecFormDialectGeminiThinkingBudget.
  ///
  /// In en, this message translates to:
  /// **'Gemini thinking budget'**
  String get modelSpecFormDialectGeminiThinkingBudget;

  /// No description provided for @modelSpecFormDialectGeminiThinkingBudgetSubtitle.
  ///
  /// In en, this message translates to:
  /// **'thinkingConfig.thinkingBudget'**
  String get modelSpecFormDialectGeminiThinkingBudgetSubtitle;

  /// No description provided for @modelSpecFormDialectGeminiThinkingLevel.
  ///
  /// In en, this message translates to:
  /// **'Gemini thinking level'**
  String get modelSpecFormDialectGeminiThinkingLevel;

  /// No description provided for @modelSpecFormDialectGeminiThinkingLevelSubtitle.
  ///
  /// In en, this message translates to:
  /// **'thinkingConfig.thinkingLevel'**
  String get modelSpecFormDialectGeminiThinkingLevelSubtitle;

  /// No description provided for @modelSpecFormDialectQwenEnableThinking.
  ///
  /// In en, this message translates to:
  /// **'Qwen enable thinking'**
  String get modelSpecFormDialectQwenEnableThinking;

  /// No description provided for @modelSpecFormDialectQwenEnableThinkingSubtitle.
  ///
  /// In en, this message translates to:
  /// **'enable_thinking'**
  String get modelSpecFormDialectQwenEnableThinkingSubtitle;

  /// No description provided for @modelSpecFormDialectThinkingType.
  ///
  /// In en, this message translates to:
  /// **'Thinking type'**
  String get modelSpecFormDialectThinkingType;

  /// No description provided for @modelSpecFormDialectThinkingTypeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'thinking.type'**
  String get modelSpecFormDialectThinkingTypeSubtitle;

  /// No description provided for @modelSpecFormDialectSiliconflowEnableThinking.
  ///
  /// In en, this message translates to:
  /// **'SiliconFlow enable thinking'**
  String get modelSpecFormDialectSiliconflowEnableThinking;

  /// No description provided for @modelSpecFormDialectSiliconflowEnableThinkingSubtitle.
  ///
  /// In en, this message translates to:
  /// **'enable_thinking'**
  String get modelSpecFormDialectSiliconflowEnableThinkingSubtitle;

  /// No description provided for @modelSpecFormDialectInternThinkingMode.
  ///
  /// In en, this message translates to:
  /// **'Intern thinking mode'**
  String get modelSpecFormDialectInternThinkingMode;

  /// No description provided for @modelSpecFormDialectInternThinkingModeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'thinking_mode'**
  String get modelSpecFormDialectInternThinkingModeSubtitle;

  /// No description provided for @modelSpecFormDialectChatTemplateKwargs.
  ///
  /// In en, this message translates to:
  /// **'Chat template kwargs'**
  String get modelSpecFormDialectChatTemplateKwargs;

  /// No description provided for @modelSpecFormDialectChatTemplateKwargsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'chat_template_kwargs.enable_thinking'**
  String get modelSpecFormDialectChatTemplateKwargsSubtitle;

  /// No description provided for @modelSpecFormDialectKimiThinking.
  ///
  /// In en, this message translates to:
  /// **'Kimi thinking'**
  String get modelSpecFormDialectKimiThinking;

  /// No description provided for @modelSpecFormDialectKimiThinkingSubtitle.
  ///
  /// In en, this message translates to:
  /// **'thinking'**
  String get modelSpecFormDialectKimiThinkingSubtitle;

  /// No description provided for @modelSpecFormDialectCustom.
  ///
  /// In en, this message translates to:
  /// **'Custom JSON'**
  String get modelSpecFormDialectCustom;

  /// No description provided for @modelSpecFormDialectCustomSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Per-level JSON patch'**
  String get modelSpecFormDialectCustomSubtitle;

  /// No description provided for @modelSpecFormLevels.
  ///
  /// In en, this message translates to:
  /// **'Supported levels'**
  String get modelSpecFormLevels;

  /// No description provided for @modelSpecFormCanDisable.
  ///
  /// In en, this message translates to:
  /// **'Allow disabling'**
  String get modelSpecFormCanDisable;

  /// No description provided for @modelSpecFormDefaultLevel.
  ///
  /// In en, this message translates to:
  /// **'Default level'**
  String get modelSpecFormDefaultLevel;

  /// No description provided for @modelSpecFormBudgets.
  ///
  /// In en, this message translates to:
  /// **'Token budgets'**
  String get modelSpecFormBudgets;

  /// No description provided for @modelSpecFormBudgetPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'{tokens}'**
  String modelSpecFormBudgetPlaceholder(String tokens);

  /// No description provided for @modelSpecFormCustomPatch.
  ///
  /// In en, this message translates to:
  /// **'JSON patch ({level})'**
  String modelSpecFormCustomPatch(String level);

  /// No description provided for @modelSpecFormCustomPatchHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. reasoning_effort: high'**
  String get modelSpecFormCustomPatchHint;

  /// No description provided for @modelSpecFormInvalidJson.
  ///
  /// In en, this message translates to:
  /// **'Custom reasoning patch must be a valid JSON object'**
  String get modelSpecFormInvalidJson;

  /// No description provided for @modelSpecFormInvalidNumber.
  ///
  /// In en, this message translates to:
  /// **'Please enter a valid number'**
  String get modelSpecFormInvalidNumber;

  /// No description provided for @modelSpecFormStrategySection.
  ///
  /// In en, this message translates to:
  /// **'Strategy'**
  String get modelSpecFormStrategySection;

  /// No description provided for @modelSpecFormSampling.
  ///
  /// In en, this message translates to:
  /// **'Sampling'**
  String get modelSpecFormSampling;

  /// No description provided for @modelSpecFormRequestQuirks.
  ///
  /// In en, this message translates to:
  /// **'Request compatibility'**
  String get modelSpecFormRequestQuirks;

  /// No description provided for @modelSpecFormDynamicWebSearch.
  ///
  /// In en, this message translates to:
  /// **'Dynamic filtering search tools'**
  String get modelSpecFormDynamicWebSearch;

  /// No description provided for @modelSpecFormDynamicWebSearchSubtitle.
  ///
  /// In en, this message translates to:
  /// **'When dynamic filtering is on, send the 2026-03-18 web search and fetch tools'**
  String get modelSpecFormDynamicWebSearchSubtitle;

  /// No description provided for @modelSpecFormRemoteImageUrls.
  ///
  /// In en, this message translates to:
  /// **'Remote image links'**
  String get modelSpecFormRemoteImageUrls;

  /// No description provided for @modelSpecFormRemoteImageUrlsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Send http(s) image links as-is; when off, remote links are dropped and only local images are sent'**
  String get modelSpecFormRemoteImageUrlsSubtitle;

  /// No description provided for @modelSpecFormPromptCacheControl.
  ///
  /// In en, this message translates to:
  /// **'Prompt cache marker'**
  String get modelSpecFormPromptCacheControl;

  /// No description provided for @modelSpecFormPromptCacheControlSubtitle.
  ///
  /// In en, this message translates to:
  /// **'When prompt caching is on, add cache_control to OpenRouter requests'**
  String get modelSpecFormPromptCacheControlSubtitle;

  /// No description provided for @modelSpecFormSamplingAlways.
  ///
  /// In en, this message translates to:
  /// **'Always'**
  String get modelSpecFormSamplingAlways;

  /// No description provided for @modelSpecFormSamplingAlwaysSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Keep temperature and other sampling fields'**
  String get modelSpecFormSamplingAlwaysSubtitle;

  /// No description provided for @modelSpecFormSamplingOnlyWhenReasoningOff.
  ///
  /// In en, this message translates to:
  /// **'Only when reasoning is off'**
  String get modelSpecFormSamplingOnlyWhenReasoningOff;

  /// No description provided for @modelSpecFormSamplingOnlyWhenReasoningOffSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Strip sampling fields while the model is thinking'**
  String get modelSpecFormSamplingOnlyWhenReasoningOffSubtitle;

  /// No description provided for @modelSpecFormSamplingNever.
  ///
  /// In en, this message translates to:
  /// **'Never'**
  String get modelSpecFormSamplingNever;

  /// No description provided for @modelSpecFormSamplingNeverSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Always strip sampling fields'**
  String get modelSpecFormSamplingNeverSubtitle;

  /// No description provided for @modelSpecFormReplay.
  ///
  /// In en, this message translates to:
  /// **'Reasoning replay'**
  String get modelSpecFormReplay;

  /// No description provided for @modelSpecFormReplayNone.
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get modelSpecFormReplayNone;

  /// No description provided for @modelSpecFormReplayNoneSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Do not send prior reasoning back to the model'**
  String get modelSpecFormReplayNoneSubtitle;

  /// No description provided for @modelSpecFormReplayToolTurns.
  ///
  /// In en, this message translates to:
  /// **'Tool turns'**
  String get modelSpecFormReplayToolTurns;

  /// No description provided for @modelSpecFormReplayToolTurnsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Replay reasoning on tool-call turns'**
  String get modelSpecFormReplayToolTurnsSubtitle;

  /// No description provided for @modelSpecFormReplayAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get modelSpecFormReplayAll;

  /// No description provided for @modelSpecFormReplayAllSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Replay reasoning on every follow-up turn'**
  String get modelSpecFormReplayAllSubtitle;

  /// No description provided for @modelSpecFormReplayField.
  ///
  /// In en, this message translates to:
  /// **'Replay field'**
  String get modelSpecFormReplayField;

  /// No description provided for @modelSpecFormReplayFieldReasoningContent.
  ///
  /// In en, this message translates to:
  /// **'reasoning_content'**
  String get modelSpecFormReplayFieldReasoningContent;

  /// No description provided for @modelSpecFormReplayFieldReasoning.
  ///
  /// In en, this message translates to:
  /// **'reasoning'**
  String get modelSpecFormReplayFieldReasoning;

  /// No description provided for @modelSpecFormReplayFieldReasoningDetails.
  ///
  /// In en, this message translates to:
  /// **'reasoning_details'**
  String get modelSpecFormReplayFieldReasoningDetails;

  /// No description provided for @modelSpecFormLimitsSection.
  ///
  /// In en, this message translates to:
  /// **'Limits'**
  String get modelSpecFormLimitsSection;

  /// No description provided for @modelSpecFormLimitsPricingSection.
  ///
  /// In en, this message translates to:
  /// **'Limits & pricing'**
  String get modelSpecFormLimitsPricingSection;

  /// No description provided for @modelSpecFormContextWindow.
  ///
  /// In en, this message translates to:
  /// **'Context window'**
  String get modelSpecFormContextWindow;

  /// No description provided for @modelSpecFormMaxOutput.
  ///
  /// In en, this message translates to:
  /// **'Max output'**
  String get modelSpecFormMaxOutput;

  /// No description provided for @modelSpecFormPricingSection.
  ///
  /// In en, this message translates to:
  /// **'Pricing / 1M'**
  String get modelSpecFormPricingSection;

  /// No description provided for @modelSpecFormPricingInput.
  ///
  /// In en, this message translates to:
  /// **'Input'**
  String get modelSpecFormPricingInput;

  /// No description provided for @modelSpecFormPricingOutput.
  ///
  /// In en, this message translates to:
  /// **'Output'**
  String get modelSpecFormPricingOutput;

  /// No description provided for @modelSpecFormPricingCacheRead.
  ///
  /// In en, this message translates to:
  /// **'Cache read'**
  String get modelSpecFormPricingCacheRead;

  /// No description provided for @modelSpecFormPricingCacheWrite.
  ///
  /// In en, this message translates to:
  /// **'Cache write'**
  String get modelSpecFormPricingCacheWrite;

  /// No description provided for @modelSpecFormCurrency.
  ///
  /// In en, this message translates to:
  /// **'Currency'**
  String get modelSpecFormCurrency;

  /// No description provided for @modelSpecFormAdvancedSection.
  ///
  /// In en, this message translates to:
  /// **'Request'**
  String get modelSpecFormAdvancedSection;

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

  /// No description provided for @providerDetailPagePromptCacheKeyTitle.
  ///
  /// In en, this message translates to:
  /// **'Send Conversation Cache Key'**
  String get providerDetailPagePromptCacheKeyTitle;

  /// No description provided for @providerDetailPagePromptCacheKeyHelp.
  ///
  /// In en, this message translates to:
  /// **'Adds a stable prompt_cache_key for each conversation to OpenAI-compatible requests. Enable only if your provider supports it. Custom Body values take precedence; cache hits are not guaranteed.'**
  String get providerDetailPagePromptCacheKeyHelp;

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

  /// No description provided for @modelCatalogTitle.
  ///
  /// In en, this message translates to:
  /// **'Model catalog'**
  String get modelCatalogTitle;

  /// No description provided for @modelCatalogSourceBundled.
  ///
  /// In en, this message translates to:
  /// **'Bundled snapshot · {date}'**
  String modelCatalogSourceBundled(String date);

  /// No description provided for @modelCatalogSourceRemote.
  ///
  /// In en, this message translates to:
  /// **'models.dev · updated {date}'**
  String modelCatalogSourceRemote(String date);

  /// No description provided for @modelCatalogAutoUpdate.
  ///
  /// In en, this message translates to:
  /// **'Auto-update every 24 hours'**
  String get modelCatalogAutoUpdate;

  /// No description provided for @modelCatalogRefresh.
  ///
  /// In en, this message translates to:
  /// **'Update now'**
  String get modelCatalogRefresh;

  /// No description provided for @modelCatalogUpdated.
  ///
  /// In en, this message translates to:
  /// **'Model catalog updated'**
  String get modelCatalogUpdated;

  /// No description provided for @modelCatalogRefreshFailed.
  ///
  /// In en, this message translates to:
  /// **'Update failed: {error}'**
  String modelCatalogRefreshFailed(String error);

  /// No description provided for @modelCatalogProviderCount.
  ///
  /// In en, this message translates to:
  /// **'{count} providers'**
  String modelCatalogProviderCount(int count);

  /// No description provided for @modelCatalogModelCount.
  ///
  /// In en, this message translates to:
  /// **'{count} models'**
  String modelCatalogModelCount(int count);

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

  /// No description provided for @searchServicesPageWebFetchSection.
  ///
  /// In en, this message translates to:
  /// **'Web page reading'**
  String get searchServicesPageWebFetchSection;

  /// No description provided for @searchServicesPageWebFetchModeTitle.
  ///
  /// In en, this message translates to:
  /// **'Read pages with'**
  String get searchServicesPageWebFetchModeTitle;

  /// No description provided for @searchServicesPageWebFetchFollow.
  ///
  /// In en, this message translates to:
  /// **'Follow search service'**
  String get searchServicesPageWebFetchFollow;

  /// No description provided for @searchServicesPageWebFetchFollowValue.
  ///
  /// In en, this message translates to:
  /// **'Follow search · {name}'**
  String searchServicesPageWebFetchFollowValue(String name);

  /// No description provided for @searchServicesPageWebFetchFollowSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Currently {name}'**
  String searchServicesPageWebFetchFollowSubtitle(String name);

  /// No description provided for @searchServicesPageWebFetchLocal.
  ///
  /// In en, this message translates to:
  /// **'Local'**
  String get searchServicesPageWebFetchLocal;

  /// No description provided for @searchServicesPageWebFetchLocalSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Free. This device requests the page directly.'**
  String get searchServicesPageWebFetchLocalSubtitle;

  /// No description provided for @searchServicesPageWebFetchProviderSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Uses this service\'s API key and quota'**
  String get searchServicesPageWebFetchProviderSubtitle;

  /// No description provided for @searchServicesPageWebFetchOff.
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get searchServicesPageWebFetchOff;

  /// No description provided for @searchServicesPageWebFetchOffSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Search only, without reading pages'**
  String get searchServicesPageWebFetchOffSubtitle;

  /// No description provided for @searchServicesPageWebFetchFooter.
  ///
  /// In en, this message translates to:
  /// **'With web search on, the model can also read full pages. When the search service can\'t read pages, local reading is used, which can\'t handle pages that need JavaScript or block bots.'**
  String get searchServicesPageWebFetchFooter;

  /// No description provided for @searchServicesPageWebFetchSupported.
  ///
  /// In en, this message translates to:
  /// **'Can read web pages'**
  String get searchServicesPageWebFetchSupported;

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

  /// No description provided for @searchServicesDialogApiKeyOptional.
  ///
  /// In en, this message translates to:
  /// **'API Key (optional)'**
  String get searchServicesDialogApiKeyOptional;

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

  /// No description provided for @searchServiceEditorTestModeSearch.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get searchServiceEditorTestModeSearch;

  /// No description provided for @searchServiceEditorTestModeFetch.
  ///
  /// In en, this message translates to:
  /// **'Read page'**
  String get searchServiceEditorTestModeFetch;

  /// No description provided for @searchServiceEditorTestUrlHint.
  ///
  /// In en, this message translates to:
  /// **'Enter a URL'**
  String get searchServiceEditorTestUrlHint;

  /// No description provided for @searchServiceEditorTestFetchRun.
  ///
  /// In en, this message translates to:
  /// **'Run test fetch'**
  String get searchServiceEditorTestFetchRun;

  /// No description provided for @searchServiceEditorTestFetchRunning.
  ///
  /// In en, this message translates to:
  /// **'Reading…'**
  String get searchServiceEditorTestFetchRunning;

  /// No description provided for @searchServiceEditorTestFetchFailed.
  ///
  /// In en, this message translates to:
  /// **'Fetch failed: {message}'**
  String searchServiceEditorTestFetchFailed(String message);

  /// No description provided for @searchServiceEditorTestFetchStats.
  ///
  /// In en, this message translates to:
  /// **'{characters} characters · {seconds}s'**
  String searchServiceEditorTestFetchStats(String characters, String seconds);

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

  /// No description provided for @displaySettingsPageShowTotalTokensTitle.
  ///
  /// In en, this message translates to:
  /// **'Show tokens for the entire turn'**
  String get displaySettingsPageShowTotalTokensTitle;

  /// No description provided for @displaySettingsPageShowTotalTokensSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Sum usage across all API requests in a reply. When off, show only the final request. Statistics always include all requests.'**
  String get displaySettingsPageShowTotalTokensSubtitle;

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

  /// No description provided for @displaySettingsShowReasoningLevelBadge.
  ///
  /// In en, this message translates to:
  /// **'Show reasoning level on the button'**
  String get displaySettingsShowReasoningLevelBadge;

  /// No description provided for @displaySettingsShowReasoningLevelBadgeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Show the current level next to the reasoning icon in the input bar'**
  String get displaySettingsShowReasoningLevelBadgeSubtitle;

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

  /// No description provided for @displaySettingsPageAutoScrollEnableTitle.
  ///
  /// In en, this message translates to:
  /// **'Auto-follow bottom'**
  String get displaySettingsPageAutoScrollEnableTitle;

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

  /// No description provided for @linuxHideTitleBarTitle.
  ///
  /// In en, this message translates to:
  /// **'Hide system title bar'**
  String get linuxHideTitleBarTitle;

  /// No description provided for @linuxHideTitleBarDescription.
  ///
  /// In en, this message translates to:
  /// **'Also hides window buttons. Use your window manager to move, resize, and close the window.'**
  String get linuxHideTitleBarDescription;

  /// No description provided for @linuxHideTitleBarError.
  ///
  /// In en, this message translates to:
  /// **'Unable to change the title bar. Please try again.'**
  String get linuxHideTitleBarError;

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

  /// No description provided for @asrServicesGroqSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Whisper segmented transcription'**
  String get asrServicesGroqSubtitle;

  /// No description provided for @asrServicesMistralSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Voxtral segmented transcription'**
  String get asrServicesMistralSubtitle;

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

  /// No description provided for @searchProviderExaMcpDescription.
  ///
  /// In en, this message translates to:
  /// **'Exa search via MCP. An API key is optional for limited free usage.'**
  String get searchProviderExaMcpDescription;

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

  /// No description provided for @searchProviderDeepSeekDescription.
  ///
  /// In en, this message translates to:
  /// **'DeepSeek official web search and page fetch APIs. Uses a DeepSeek API key.'**
  String get searchProviderDeepSeekDescription;

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

  /// No description provided for @searchServiceNameExaMcp.
  ///
  /// In en, this message translates to:
  /// **'Exa MCP'**
  String get searchServiceNameExaMcp;

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

  /// No description provided for @searchServiceNameDeepSeek.
  ///
  /// In en, this message translates to:
  /// **'DeepSeek'**
  String get searchServiceNameDeepSeek;

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

  /// No description provided for @searchServiceNameKagi.
  ///
  /// In en, this message translates to:
  /// **'Kagi'**
  String get searchServiceNameKagi;

  /// No description provided for @searchProviderKagiDescription.
  ///
  /// In en, this message translates to:
  /// **'Kagi Search API. Returns premium web search results from Kagi.'**
  String get searchProviderKagiDescription;

  /// No description provided for @searchServiceNameKimi.
  ///
  /// In en, this message translates to:
  /// **'Kimi'**
  String get searchServiceNameKimi;

  /// No description provided for @searchProviderKimiDescription.
  ///
  /// In en, this message translates to:
  /// **'Kimi Search API. Pro returns relevant web content excerpts; Basic returns titles, links, and snippets.'**
  String get searchProviderKimiDescription;

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
  /// **'Past 24 hours: sleep, time in bed, awake periods and sleep stages'**
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
  /// **'Auto-retry only runs if the current model response has not produced any output yet.'**
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
  /// **'This limit applies to types not selected for full injection. When a type exceeds this limit, only the newest items are injected. The rest can be fetched with memory_search_profile. A larger number is more complete but uses more tokens. If you customized the rules prompt, update it or restore the default.'**
  String get memorySettingsInjectionMaxItemsSubtitle;

  /// No description provided for @memorySettingsFullInjectionTypesTitle.
  ///
  /// In en, this message translates to:
  /// **'Always inject these types'**
  String get memorySettingsFullInjectionTypesTitle;

  /// No description provided for @memorySettingsFullInjectionTypesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Select one or more types to inject all their active memories visible to the current assistant. These types ignore the item limit and use more context and tokens.'**
  String get memorySettingsFullInjectionTypesSubtitle;

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

  /// No description provided for @worldBookImportUnsupportedEntries.
  ///
  /// In en, this message translates to:
  /// **'Imported. {count} entries use unsupported SillyTavern features (such as macros, regex, timing, filters, or insertion rules). Their content was kept and they were disabled. Review them before enabling.'**
  String worldBookImportUnsupportedEntries(int count);

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

  /// No description provided for @tokenDetailFirstToken.
  ///
  /// In en, this message translates to:
  /// **'{value}s (first token)'**
  String tokenDetailFirstToken(String value);

  /// No description provided for @tokenDetailTotalTokens.
  ///
  /// In en, this message translates to:
  /// **'{count} tokens'**
  String tokenDetailTotalTokens(int count);

  /// No description provided for @tokenDetailReasoningTokens.
  ///
  /// In en, this message translates to:
  /// **'{count} tokens'**
  String tokenDetailReasoningTokens(int count);

  /// No description provided for @tokenDetailCacheWriteTokens.
  ///
  /// In en, this message translates to:
  /// **'{count} cache write tokens'**
  String tokenDetailCacheWriteTokens(int count);

  /// No description provided for @tokenDetailCost.
  ///
  /// In en, this message translates to:
  /// **'{amount}'**
  String tokenDetailCost(String amount);

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

  /// No description provided for @imageSettingsPageSendSectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Sending'**
  String get imageSettingsPageSendSectionTitle;

  /// No description provided for @imageSettingsPageMarkdownImageLinksTitle.
  ///
  /// In en, this message translates to:
  /// **'Send Markdown image links as images'**
  String get imageSettingsPageMarkdownImageLinksTitle;

  /// No description provided for @imageSettingsPageMarkdownImageLinksSubtitle.
  ///
  /// In en, this message translates to:
  /// **'When enabled, an ![alt](url) link in your message text is sent to vision models as an image. When off it stays plain text. Images you attach yourself are always sent as images.'**
  String get imageSettingsPageMarkdownImageLinksSubtitle;

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
  /// **'Your current chats and settings will be replaced by this copy from {when}. A copy of the current chats and settings is saved first. Unsent drafts are excluded from copies and will be cleared.'**
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

  /// No description provided for @workspaceFileNotAvailable.
  ///
  /// In en, this message translates to:
  /// **'File not available'**
  String get workspaceFileNotAvailable;

  /// No description provided for @workspaceTerminalNotAvailable.
  ///
  /// In en, this message translates to:
  /// **'Terminal not available'**
  String get workspaceTerminalNotAvailable;

  /// No description provided for @workspacePreviewCopyPath.
  ///
  /// In en, this message translates to:
  /// **'Copy path'**
  String get workspacePreviewCopyPath;

  /// No description provided for @workspacePreviewShare.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get workspacePreviewShare;

  /// No description provided for @workspacePreviewOpenExternally.
  ///
  /// In en, this message translates to:
  /// **'Open externally'**
  String get workspacePreviewOpenExternally;

  /// No description provided for @workspacePreviewOpenWith.
  ///
  /// In en, this message translates to:
  /// **'Open with…'**
  String get workspacePreviewOpenWith;

  /// No description provided for @workspacePreviewFileTooLarge.
  ///
  /// In en, this message translates to:
  /// **'This file is too large to preview. Open it externally instead.'**
  String get workspacePreviewFileTooLarge;

  /// No description provided for @workspacePreviewSource.
  ///
  /// In en, this message translates to:
  /// **'Source'**
  String get workspacePreviewSource;

  /// No description provided for @workspacePreviewRendered.
  ///
  /// In en, this message translates to:
  /// **'Rendered'**
  String get workspacePreviewRendered;

  /// No description provided for @workspacePreviewFileName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get workspacePreviewFileName;

  /// No description provided for @workspacePreviewFileSize.
  ///
  /// In en, this message translates to:
  /// **'Size'**
  String get workspacePreviewFileSize;

  /// No description provided for @workspacePreviewFileModified.
  ///
  /// In en, this message translates to:
  /// **'Modified'**
  String get workspacePreviewFileModified;

  /// No description provided for @workspacePreviewPathCopied.
  ///
  /// In en, this message translates to:
  /// **'Path copied'**
  String get workspacePreviewPathCopied;

  /// No description provided for @workspacePreviewLineCount.
  ///
  /// In en, this message translates to:
  /// **'{count} lines'**
  String workspacePreviewLineCount(int count);

  /// No description provided for @workspaceFilesSort.
  ///
  /// In en, this message translates to:
  /// **'Sort'**
  String get workspaceFilesSort;

  /// No description provided for @workspaceFilesSortName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get workspaceFilesSortName;

  /// No description provided for @workspaceFilesSortModified.
  ///
  /// In en, this message translates to:
  /// **'Modified'**
  String get workspaceFilesSortModified;

  /// No description provided for @workspaceFilesSortSize.
  ///
  /// In en, this message translates to:
  /// **'Size'**
  String get workspaceFilesSortSize;

  /// No description provided for @workspaceFilesSortAscending.
  ///
  /// In en, this message translates to:
  /// **'Ascending'**
  String get workspaceFilesSortAscending;

  /// No description provided for @workspaceFilesSortDescending.
  ///
  /// In en, this message translates to:
  /// **'Descending'**
  String get workspaceFilesSortDescending;

  /// No description provided for @workspaceFilesShowHidden.
  ///
  /// In en, this message translates to:
  /// **'Show hidden files'**
  String get workspaceFilesShowHidden;

  /// No description provided for @workspaceFilesHideHidden.
  ///
  /// In en, this message translates to:
  /// **'Hide hidden files'**
  String get workspaceFilesHideHidden;

  /// No description provided for @workspaceFilesRefresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get workspaceFilesRefresh;

  /// No description provided for @workspaceFilesNewFolder.
  ///
  /// In en, this message translates to:
  /// **'New folder'**
  String get workspaceFilesNewFolder;

  /// No description provided for @workspaceFilesNewFile.
  ///
  /// In en, this message translates to:
  /// **'New file'**
  String get workspaceFilesNewFile;

  /// No description provided for @workspaceFilesImport.
  ///
  /// In en, this message translates to:
  /// **'Import'**
  String get workspaceFilesImport;

  /// No description provided for @workspaceFilesExport.
  ///
  /// In en, this message translates to:
  /// **'Export'**
  String get workspaceFilesExport;

  /// No description provided for @workspaceFilesExportFolder.
  ///
  /// In en, this message translates to:
  /// **'Export folder'**
  String get workspaceFilesExportFolder;

  /// No description provided for @workspaceFilesEmpty.
  ///
  /// In en, this message translates to:
  /// **'This folder is empty'**
  String get workspaceFilesEmpty;

  /// No description provided for @workspaceFilesError.
  ///
  /// In en, this message translates to:
  /// **'Couldn’t load these files'**
  String get workspaceFilesError;

  /// No description provided for @workspaceFilesRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get workspaceFilesRetry;

  /// No description provided for @workspaceFilesPreview.
  ///
  /// In en, this message translates to:
  /// **'Preview'**
  String get workspaceFilesPreview;

  /// No description provided for @workspaceFilesRename.
  ///
  /// In en, this message translates to:
  /// **'Rename'**
  String get workspaceFilesRename;

  /// No description provided for @workspaceFilesMove.
  ///
  /// In en, this message translates to:
  /// **'Move'**
  String get workspaceFilesMove;

  /// No description provided for @workspaceFilesDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get workspaceFilesDelete;

  /// No description provided for @workspaceFilesShare.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get workspaceFilesShare;

  /// No description provided for @workspaceFilesCopyPath.
  ///
  /// In en, this message translates to:
  /// **'Copy path'**
  String get workspaceFilesCopyPath;

  /// No description provided for @workspaceFilesExportItem.
  ///
  /// In en, this message translates to:
  /// **'Export'**
  String get workspaceFilesExportItem;

  /// No description provided for @workspaceFilesNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get workspaceFilesNameLabel;

  /// No description provided for @workspaceFilesNameHint.
  ///
  /// In en, this message translates to:
  /// **'Enter a name'**
  String get workspaceFilesNameHint;

  /// No description provided for @workspaceFilesCreate.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get workspaceFilesCreate;

  /// No description provided for @workspaceFilesCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get workspaceFilesCancel;

  /// No description provided for @workspaceFilesConfirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get workspaceFilesConfirm;

  /// No description provided for @workspaceFilesSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get workspaceFilesSave;

  /// No description provided for @workspaceFilesDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete this item?'**
  String get workspaceFilesDeleteTitle;

  /// No description provided for @workspaceFilesDeleteMessage.
  ///
  /// In en, this message translates to:
  /// **'Delete {name}?'**
  String workspaceFilesDeleteMessage(String name);

  /// No description provided for @workspaceFilesDeleteFolderMessage.
  ///
  /// In en, this message translates to:
  /// **'Delete folder {name} and everything inside?'**
  String workspaceFilesDeleteFolderMessage(String name);

  /// No description provided for @workspaceFilesMoveTitle.
  ///
  /// In en, this message translates to:
  /// **'Move to folder'**
  String get workspaceFilesMoveTitle;

  /// No description provided for @workspaceFilesMoveHere.
  ///
  /// In en, this message translates to:
  /// **'Move here'**
  String get workspaceFilesMoveHere;

  /// No description provided for @workspaceFilesPathCopied.
  ///
  /// In en, this message translates to:
  /// **'Path copied'**
  String get workspaceFilesPathCopied;

  /// No description provided for @workspaceFilesInvalidName.
  ///
  /// In en, this message translates to:
  /// **'That name isn’t valid'**
  String get workspaceFilesInvalidName;

  /// No description provided for @workspaceFilesInvalidPath.
  ///
  /// In en, this message translates to:
  /// **'That path is outside this folder'**
  String get workspaceFilesInvalidPath;

  /// No description provided for @workspaceFilesOperationFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn’t complete that action: {error}'**
  String workspaceFilesOperationFailed(String error);

  /// No description provided for @workspaceFilesActions.
  ///
  /// In en, this message translates to:
  /// **'Actions'**
  String get workspaceFilesActions;

  /// No description provided for @workspaceFilesMore.
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get workspaceFilesMore;

  /// No description provided for @workspaceFilesJustNow.
  ///
  /// In en, this message translates to:
  /// **'Just now'**
  String get workspaceFilesJustNow;

  /// No description provided for @workspaceFilesMinutesAgo.
  ///
  /// In en, this message translates to:
  /// **'{count}m ago'**
  String workspaceFilesMinutesAgo(int count);

  /// No description provided for @workspaceFilesHoursAgo.
  ///
  /// In en, this message translates to:
  /// **'{count}h ago'**
  String workspaceFilesHoursAgo(int count);

  /// No description provided for @workspaceFilesDaysAgo.
  ///
  /// In en, this message translates to:
  /// **'{count}d ago'**
  String workspaceFilesDaysAgo(int count);

  /// No description provided for @workspaceFilesPanelTitle.
  ///
  /// In en, this message translates to:
  /// **'Conversation files'**
  String get workspaceFilesPanelTitle;

  /// No description provided for @workspaceFilesTabAttachments.
  ///
  /// In en, this message translates to:
  /// **'Attachments'**
  String get workspaceFilesTabAttachments;

  /// No description provided for @workspaceFilesTabOutputs.
  ///
  /// In en, this message translates to:
  /// **'Outputs'**
  String get workspaceFilesTabOutputs;

  /// No description provided for @workspaceFilesTabWorkspace.
  ///
  /// In en, this message translates to:
  /// **'Workspace'**
  String get workspaceFilesTabWorkspace;

  /// No description provided for @workspaceFilesNoWorkspaceBound.
  ///
  /// In en, this message translates to:
  /// **'No workspace bound'**
  String get workspaceFilesNoWorkspaceBound;

  /// No description provided for @workspaceFilesKindManaged.
  ///
  /// In en, this message translates to:
  /// **'Managed'**
  String get workspaceFilesKindManaged;

  /// No description provided for @workspaceFilesKindLinked.
  ///
  /// In en, this message translates to:
  /// **'Linked'**
  String get workspaceFilesKindLinked;

  /// No description provided for @workspaceFilesMissingWorkspace.
  ///
  /// In en, this message translates to:
  /// **'Workspace not found'**
  String get workspaceFilesMissingWorkspace;

  /// No description provided for @workspaceFilesClose.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get workspaceFilesClose;

  /// No description provided for @workspacesTitle.
  ///
  /// In en, this message translates to:
  /// **'Workspaces'**
  String get workspacesTitle;

  /// No description provided for @workspacesCreate.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get workspacesCreate;

  /// No description provided for @workspacesCreateTitle.
  ///
  /// In en, this message translates to:
  /// **'New workspace'**
  String get workspacesCreateTitle;

  /// No description provided for @workspacesNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get workspacesNameLabel;

  /// No description provided for @workspacesNameHint.
  ///
  /// In en, this message translates to:
  /// **'Workspace name'**
  String get workspacesNameHint;

  /// No description provided for @workspacesLinkFolder.
  ///
  /// In en, this message translates to:
  /// **'Link folder'**
  String get workspacesLinkFolder;

  /// No description provided for @workspacesEmpty.
  ///
  /// In en, this message translates to:
  /// **'No workspaces yet'**
  String get workspacesEmpty;

  /// No description provided for @workspacesEmptyCta.
  ///
  /// In en, this message translates to:
  /// **'Create a workspace'**
  String get workspacesEmptyCta;

  /// No description provided for @workspacesSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get workspacesSettings;

  /// No description provided for @workspacesOpenFiles.
  ///
  /// In en, this message translates to:
  /// **'Open files'**
  String get workspacesOpenFiles;

  /// No description provided for @workspacesLastUsedNever.
  ///
  /// In en, this message translates to:
  /// **'Never used'**
  String get workspacesLastUsedNever;

  /// No description provided for @workspacesLastUsed.
  ///
  /// In en, this message translates to:
  /// **'Last used {when}'**
  String workspacesLastUsed(String when);

  /// No description provided for @workspacesDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete this workspace?'**
  String get workspacesDeleteTitle;

  /// No description provided for @workspacesDeleteMessage.
  ///
  /// In en, this message translates to:
  /// **'Delete workspace {name}?'**
  String workspacesDeleteMessage(String name);

  /// No description provided for @workspacesDeleteAlsoFiles.
  ///
  /// In en, this message translates to:
  /// **'Also delete files'**
  String get workspacesDeleteAlsoFiles;

  /// No description provided for @workspacesUnlinkTitle.
  ///
  /// In en, this message translates to:
  /// **'Unlink this workspace?'**
  String get workspacesUnlinkTitle;

  /// No description provided for @workspacesUnlinkMessage.
  ///
  /// In en, this message translates to:
  /// **'Unlink {name}? Files on disk will be kept.'**
  String workspacesUnlinkMessage(String name);

  /// No description provided for @workspacesSettingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Workspace settings'**
  String get workspacesSettingsTitle;

  /// No description provided for @workspacesShellNeedsApproval.
  ///
  /// In en, this message translates to:
  /// **'Ask before running shell commands'**
  String get workspacesShellNeedsApproval;

  /// No description provided for @workspacesDefaultCwd.
  ///
  /// In en, this message translates to:
  /// **'Default working directory'**
  String get workspacesDefaultCwd;

  /// No description provided for @workspacesDefaultCwdHint.
  ///
  /// In en, this message translates to:
  /// **'Relative path, e.g. src'**
  String get workspacesDefaultCwdHint;

  /// No description provided for @workspacesDefaultCwdInvalid.
  ///
  /// In en, this message translates to:
  /// **'Use a relative path without ..'**
  String get workspacesDefaultCwdInvalid;

  /// No description provided for @workspacesCreateManaged.
  ///
  /// In en, this message translates to:
  /// **'Create workspace'**
  String get workspacesCreateManaged;

  /// No description provided for @workspacesLinkExisting.
  ///
  /// In en, this message translates to:
  /// **'Link an existing folder'**
  String get workspacesLinkExisting;

  /// No description provided for @workspacesUnlink.
  ///
  /// In en, this message translates to:
  /// **'Unlink'**
  String get workspacesUnlink;

  /// No description provided for @workspacesItemMore.
  ///
  /// In en, this message translates to:
  /// **'Workspace actions'**
  String get workspacesItemMore;

  /// No description provided for @workspaceToolDenied.
  ///
  /// In en, this message translates to:
  /// **'Denied'**
  String get workspaceToolDenied;

  /// No description provided for @workspaceToolTimeout.
  ///
  /// In en, this message translates to:
  /// **'timeout'**
  String get workspaceToolTimeout;

  /// No description provided for @workspaceToolCancelled.
  ///
  /// In en, this message translates to:
  /// **'cancelled'**
  String get workspaceToolCancelled;

  /// No description provided for @workspaceToolInterrupted.
  ///
  /// In en, this message translates to:
  /// **'interrupted'**
  String get workspaceToolInterrupted;

  /// No description provided for @workspaceToolEnvironmentNotReady.
  ///
  /// In en, this message translates to:
  /// **'Sandbox environment not installed'**
  String get workspaceToolEnvironmentNotReady;

  /// No description provided for @workspaceToolInstall.
  ///
  /// In en, this message translates to:
  /// **'Install'**
  String get workspaceToolInstall;

  /// No description provided for @workspaceToolFuzzy.
  ///
  /// In en, this message translates to:
  /// **'fuzzy'**
  String get workspaceToolFuzzy;

  /// No description provided for @workspaceToolCreated.
  ///
  /// In en, this message translates to:
  /// **'created'**
  String get workspaceToolCreated;

  /// No description provided for @workspaceToolUpdated.
  ///
  /// In en, this message translates to:
  /// **'updated'**
  String get workspaceToolUpdated;

  /// No description provided for @workspaceToolTruncated.
  ///
  /// In en, this message translates to:
  /// **'truncated'**
  String get workspaceToolTruncated;

  /// No description provided for @workspaceToolImageTag.
  ///
  /// In en, this message translates to:
  /// **'image'**
  String get workspaceToolImageTag;

  /// No description provided for @workspaceToolStdout.
  ///
  /// In en, this message translates to:
  /// **'stdout'**
  String get workspaceToolStdout;

  /// No description provided for @workspaceToolStderr.
  ///
  /// In en, this message translates to:
  /// **'stderr'**
  String get workspaceToolStderr;

  /// No description provided for @workspaceToolOpenFullOutput.
  ///
  /// In en, this message translates to:
  /// **'Open full output'**
  String get workspaceToolOpenFullOutput;

  /// No description provided for @workspaceToolChangedFiles.
  ///
  /// In en, this message translates to:
  /// **'Changed files'**
  String get workspaceToolChangedFiles;

  /// No description provided for @workspaceToolCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get workspaceToolCancel;

  /// No description provided for @workspaceToolCopyCommand.
  ///
  /// In en, this message translates to:
  /// **'Copy command'**
  String get workspaceToolCopyCommand;

  /// No description provided for @workspaceToolCopyOutput.
  ///
  /// In en, this message translates to:
  /// **'Copy output'**
  String get workspaceToolCopyOutput;

  /// No description provided for @workspaceToolCopyDiff.
  ///
  /// In en, this message translates to:
  /// **'Copy diff'**
  String get workspaceToolCopyDiff;

  /// No description provided for @workspaceToolCopied.
  ///
  /// In en, this message translates to:
  /// **'Copied'**
  String get workspaceToolCopied;

  /// No description provided for @workspaceToolDiffTruncated.
  ///
  /// In en, this message translates to:
  /// **'Diff truncated'**
  String get workspaceToolDiffTruncated;

  /// No description provided for @workspaceToolOpenPreview.
  ///
  /// In en, this message translates to:
  /// **'Open preview'**
  String get workspaceToolOpenPreview;

  /// No description provided for @workspaceToolNoOutput.
  ///
  /// In en, this message translates to:
  /// **'No output'**
  String get workspaceToolNoOutput;

  /// No description provided for @workspaceToolNotAvailable.
  ///
  /// In en, this message translates to:
  /// **'Not available'**
  String get workspaceToolNotAvailable;

  /// No description provided for @workspaceToolClose.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get workspaceToolClose;

  /// No description provided for @workspaceToolTitleShell.
  ///
  /// In en, this message translates to:
  /// **'Run command'**
  String get workspaceToolTitleShell;

  /// No description provided for @workspaceToolTitleReadFile.
  ///
  /// In en, this message translates to:
  /// **'Read file'**
  String get workspaceToolTitleReadFile;

  /// No description provided for @workspaceToolTitleViewImage.
  ///
  /// In en, this message translates to:
  /// **'View image'**
  String get workspaceToolTitleViewImage;

  /// No description provided for @workspaceToolTitleWriteFile.
  ///
  /// In en, this message translates to:
  /// **'Write file'**
  String get workspaceToolTitleWriteFile;

  /// No description provided for @workspaceToolTitleEditFile.
  ///
  /// In en, this message translates to:
  /// **'Edit file'**
  String get workspaceToolTitleEditFile;

  /// No description provided for @workspaceToolTitleListDir.
  ///
  /// In en, this message translates to:
  /// **'List directory'**
  String get workspaceToolTitleListDir;

  /// No description provided for @workspaceToolTitleGlob.
  ///
  /// In en, this message translates to:
  /// **'Glob'**
  String get workspaceToolTitleGlob;

  /// No description provided for @workspaceToolTitleGrep.
  ///
  /// In en, this message translates to:
  /// **'Grep'**
  String get workspaceToolTitleGrep;

  /// No description provided for @workspaceToolCount.
  ///
  /// In en, this message translates to:
  /// **'{count}'**
  String workspaceToolCount(int count);

  /// No description provided for @workspaceToolMoreFiles.
  ///
  /// In en, this message translates to:
  /// **'+{count}'**
  String workspaceToolMoreFiles(int count);

  /// No description provided for @workspaceToolDurationMs.
  ///
  /// In en, this message translates to:
  /// **'{ms}ms'**
  String workspaceToolDurationMs(int ms);

  /// No description provided for @workspaceToolDurationSec.
  ///
  /// In en, this message translates to:
  /// **'{sec}s'**
  String workspaceToolDurationSec(String sec);

  /// No description provided for @workspaceEnvTitle.
  ///
  /// In en, this message translates to:
  /// **'Environment'**
  String get workspaceEnvTitle;

  /// No description provided for @workspaceEnvEngineUbuntu.
  ///
  /// In en, this message translates to:
  /// **'Ubuntu {version} (PRoot)'**
  String workspaceEnvEngineUbuntu(String version);

  /// No description provided for @workspaceEnvEngineAlpine.
  ///
  /// In en, this message translates to:
  /// **'Alpine {version} (iSH)'**
  String workspaceEnvEngineAlpine(String version);

  /// No description provided for @workspaceEnvEngineNative.
  ///
  /// In en, this message translates to:
  /// **'Native shell'**
  String get workspaceEnvEngineNative;

  /// No description provided for @workspaceEnvPhaseNotInstalled.
  ///
  /// In en, this message translates to:
  /// **'Not installed'**
  String get workspaceEnvPhaseNotInstalled;

  /// No description provided for @workspaceEnvPhaseDownloading.
  ///
  /// In en, this message translates to:
  /// **'Downloading'**
  String get workspaceEnvPhaseDownloading;

  /// No description provided for @workspaceEnvPhaseVerifying.
  ///
  /// In en, this message translates to:
  /// **'Verifying'**
  String get workspaceEnvPhaseVerifying;

  /// No description provided for @workspaceEnvPhaseExtracting.
  ///
  /// In en, this message translates to:
  /// **'Extracting'**
  String get workspaceEnvPhaseExtracting;

  /// No description provided for @workspaceEnvPhasePatching.
  ///
  /// In en, this message translates to:
  /// **'Patching'**
  String get workspaceEnvPhasePatching;

  /// No description provided for @workspaceEnvPhaseReady.
  ///
  /// In en, this message translates to:
  /// **'Ready'**
  String get workspaceEnvPhaseReady;

  /// No description provided for @workspaceEnvPhaseError.
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get workspaceEnvPhaseError;

  /// No description provided for @workspaceEnvPhaseNeedsRestart.
  ///
  /// In en, this message translates to:
  /// **'Restart required'**
  String get workspaceEnvPhaseNeedsRestart;

  /// No description provided for @workspaceEnvMetaLine.
  ///
  /// In en, this message translates to:
  /// **'{version} · {arch}'**
  String workspaceEnvMetaLine(String version, String arch);

  /// No description provided for @workspaceEnvInstalledAt.
  ///
  /// In en, this message translates to:
  /// **'Installed {date}'**
  String workspaceEnvInstalledAt(String date);

  /// No description provided for @workspaceEnvDiskUsage.
  ///
  /// In en, this message translates to:
  /// **'Disk usage {size}'**
  String workspaceEnvDiskUsage(String size);

  /// No description provided for @workspaceEnvRuntimeReason.
  ///
  /// In en, this message translates to:
  /// **'{reason}'**
  String workspaceEnvRuntimeReason(String reason);

  /// No description provided for @workspaceEnvInstall.
  ///
  /// In en, this message translates to:
  /// **'Install'**
  String get workspaceEnvInstall;

  /// No description provided for @workspaceEnvInstallSubtitleAndroid.
  ///
  /// In en, this message translates to:
  /// **'Choose Ubuntu, Alpine, Debian, or import a local rootfs image.'**
  String get workspaceEnvInstallSubtitleAndroid;

  /// No description provided for @workspaceEnvInstallSubtitleIos.
  ///
  /// In en, this message translates to:
  /// **'Bundled, no download'**
  String get workspaceEnvInstallSubtitleIos;

  /// No description provided for @workspaceEnvCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get workspaceEnvCancel;

  /// No description provided for @workspaceEnvRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get workspaceEnvRetry;

  /// No description provided for @workspaceEnvRepair.
  ///
  /// In en, this message translates to:
  /// **'Repair'**
  String get workspaceEnvRepair;

  /// No description provided for @workspaceEnvReset.
  ///
  /// In en, this message translates to:
  /// **'Reset'**
  String get workspaceEnvReset;

  /// No description provided for @workspaceEnvResetConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Reset environment?'**
  String get workspaceEnvResetConfirmTitle;

  /// No description provided for @workspaceEnvResetConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'This deletes installed packages and the sandbox filesystem.'**
  String get workspaceEnvResetConfirmBody;

  /// No description provided for @workspaceEnvCheckForUpdate.
  ///
  /// In en, this message translates to:
  /// **'Check for update'**
  String get workspaceEnvCheckForUpdate;

  /// No description provided for @workspaceEnvUpdate.
  ///
  /// In en, this message translates to:
  /// **'Update'**
  String get workspaceEnvUpdate;

  /// No description provided for @workspaceEnvAvailableVersion.
  ///
  /// In en, this message translates to:
  /// **'Version {version} is available'**
  String workspaceEnvAvailableVersion(String version);

  /// No description provided for @workspaceEnvUpToDate.
  ///
  /// In en, this message translates to:
  /// **'You\'re up to date'**
  String get workspaceEnvUpToDate;

  /// No description provided for @workspaceEnvRestartBanner.
  ///
  /// In en, this message translates to:
  /// **'Restart Kelivo to finish'**
  String get workspaceEnvRestartBanner;

  /// No description provided for @workspaceEnvDetectingMirrors.
  ///
  /// In en, this message translates to:
  /// **'Detecting fastest mirrors…'**
  String get workspaceEnvDetectingMirrors;

  /// No description provided for @workspaceEnvApplyingMirror.
  ///
  /// In en, this message translates to:
  /// **'Applying {category} mirror…'**
  String workspaceEnvApplyingMirror(String category);

  /// No description provided for @workspaceEnvMirrorsSection.
  ///
  /// In en, this message translates to:
  /// **'Mirrors'**
  String get workspaceEnvMirrorsSection;

  /// No description provided for @workspaceEnvUseMirror.
  ///
  /// In en, this message translates to:
  /// **'Use mirror'**
  String get workspaceEnvUseMirror;

  /// No description provided for @workspaceEnvDetect.
  ///
  /// In en, this message translates to:
  /// **'Detect'**
  String get workspaceEnvDetect;

  /// No description provided for @workspaceEnvOfficial.
  ///
  /// In en, this message translates to:
  /// **'Official'**
  String get workspaceEnvOfficial;

  /// No description provided for @workspaceEnvMirrorsDisabled.
  ///
  /// In en, this message translates to:
  /// **'Mirror changes run in the sandbox and are unavailable until it is ready.'**
  String get workspaceEnvMirrorsDisabled;

  /// No description provided for @workspaceEnvMirrorsDisabledReason.
  ///
  /// In en, this message translates to:
  /// **'Mirror changes run in the sandbox and are unavailable: {reason}'**
  String workspaceEnvMirrorsDisabledReason(String reason);

  /// No description provided for @workspaceEnvMirrorDetectTitle.
  ///
  /// In en, this message translates to:
  /// **'Mirror speed'**
  String get workspaceEnvMirrorDetectTitle;

  /// No description provided for @workspaceEnvMirrorLatency.
  ///
  /// In en, this message translates to:
  /// **'{ms} ms'**
  String workspaceEnvMirrorLatency(int ms);

  /// No description provided for @workspaceEnvMirrorFailed.
  ///
  /// In en, this message translates to:
  /// **'{reason}'**
  String workspaceEnvMirrorFailed(String reason);

  /// No description provided for @workspaceEnvErrorUnsupportedAbi.
  ///
  /// In en, this message translates to:
  /// **'This device architecture is not supported.'**
  String get workspaceEnvErrorUnsupportedAbi;

  /// No description provided for @workspaceEnvErrorArchitectureMismatch.
  ///
  /// In en, this message translates to:
  /// **'The installed sandbox architecture does not match this app. Reinstall the sandbox to continue. Your existing sandbox files have been preserved.'**
  String get workspaceEnvErrorArchitectureMismatch;

  /// No description provided for @workspaceEnvErrorProotMissing.
  ///
  /// In en, this message translates to:
  /// **'The PRoot binary is missing.'**
  String get workspaceEnvErrorProotMissing;

  /// No description provided for @workspaceEnvErrorInsufficientDisk.
  ///
  /// In en, this message translates to:
  /// **'Not enough free storage to install the sandbox.'**
  String get workspaceEnvErrorInsufficientDisk;

  /// No description provided for @workspaceEnvErrorInsufficientDiskHint.
  ///
  /// In en, this message translates to:
  /// **'Free more storage for the selected image and try again.'**
  String get workspaceEnvErrorInsufficientDiskHint;

  /// No description provided for @workspaceEnvErrorNetwork.
  ///
  /// In en, this message translates to:
  /// **'Download failed. Check your connection and try again.'**
  String get workspaceEnvErrorNetwork;

  /// No description provided for @workspaceEnvErrorChecksumMismatch.
  ///
  /// In en, this message translates to:
  /// **'The download was corrupted. Try again.'**
  String get workspaceEnvErrorChecksumMismatch;

  /// No description provided for @workspaceEnvErrorExtractFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not extract the sandbox image.'**
  String get workspaceEnvErrorExtractFailed;

  /// No description provided for @workspaceEnvErrorCleanupFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not remove old sandbox files. Please try again.'**
  String get workspaceEnvErrorCleanupFailed;

  /// No description provided for @workspaceEnvCleanupIncomplete.
  ///
  /// In en, this message translates to:
  /// **'The sandbox is ready, but some old files could not be removed. They still take up storage space.'**
  String get workspaceEnvCleanupIncomplete;

  /// No description provided for @workspaceEnvErrorResetFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not finish resetting the sandbox. Please try again.'**
  String get workspaceEnvErrorResetFailed;

  /// No description provided for @workspaceEnvErrorPatchFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not finish setting up the sandbox.'**
  String get workspaceEnvErrorPatchFailed;

  /// No description provided for @workspaceEnvErrorCancelled.
  ///
  /// In en, this message translates to:
  /// **'Installation was cancelled.'**
  String get workspaceEnvErrorCancelled;

  /// No description provided for @workspaceEnvErrorGeneric.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong installing the sandbox.'**
  String get workspaceEnvErrorGeneric;

  /// No description provided for @workspaceEnvChipInstall.
  ///
  /// In en, this message translates to:
  /// **'Install sandbox'**
  String get workspaceEnvChipInstall;

  /// No description provided for @workspaceEnvChipInstalling.
  ///
  /// In en, this message translates to:
  /// **'Installing… {percent} %'**
  String workspaceEnvChipInstalling(int percent);

  /// No description provided for @workspaceEnvChipInstallingIndeterminate.
  ///
  /// In en, this message translates to:
  /// **'Installing…'**
  String get workspaceEnvChipInstallingIndeterminate;

  /// No description provided for @workspaceEnvChipError.
  ///
  /// In en, this message translates to:
  /// **'Sandbox error'**
  String get workspaceEnvChipError;

  /// No description provided for @workspaceEnvChipRestart.
  ///
  /// In en, this message translates to:
  /// **'Restart required'**
  String get workspaceEnvChipRestart;

  /// No description provided for @workspaceEnvNativeExplanation.
  ///
  /// In en, this message translates to:
  /// **'On desktop, Kelivo uses your system shell instead of a Linux sandbox.'**
  String get workspaceEnvNativeExplanation;

  /// No description provided for @workspaceEnvNativeShellPath.
  ///
  /// In en, this message translates to:
  /// **'Shell: {path}'**
  String workspaceEnvNativeShellPath(String path);

  /// No description provided for @workspaceEnvNativeShellApproval.
  ///
  /// In en, this message translates to:
  /// **'The shell tool needs approval in Ask for approval mode.'**
  String get workspaceEnvNativeShellApproval;

  /// No description provided for @workspaceEnvDownloadProgress.
  ///
  /// In en, this message translates to:
  /// **'{downloaded} / {total} MB ({percent}%)'**
  String workspaceEnvDownloadProgress(
    String downloaded,
    String total,
    int percent,
  );

  /// No description provided for @workspaceEnvMirrorsFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not detect mirrors'**
  String get workspaceEnvMirrorsFailed;

  /// No description provided for @workspaceEnvCategoryApt.
  ///
  /// In en, this message translates to:
  /// **'APT'**
  String get workspaceEnvCategoryApt;

  /// No description provided for @workspaceEnvCategoryApk.
  ///
  /// In en, this message translates to:
  /// **'APK'**
  String get workspaceEnvCategoryApk;

  /// No description provided for @workspaceEnvCategoryPip.
  ///
  /// In en, this message translates to:
  /// **'pip'**
  String get workspaceEnvCategoryPip;

  /// No description provided for @workspaceEnvCategoryNpm.
  ///
  /// In en, this message translates to:
  /// **'npm'**
  String get workspaceEnvCategoryNpm;

  /// No description provided for @skillsTitle.
  ///
  /// In en, this message translates to:
  /// **'Skills'**
  String get skillsTitle;

  /// No description provided for @skillsTab.
  ///
  /// In en, this message translates to:
  /// **'Skills'**
  String get skillsTab;

  /// No description provided for @skillsSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search skills'**
  String get skillsSearchHint;

  /// No description provided for @skillsEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No skills yet'**
  String get skillsEmptyTitle;

  /// No description provided for @skillsEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'A skill is a folder with a SKILL.md file. Import markdown, a .md or .zip file, or a GitHub URL.'**
  String get skillsEmptyBody;

  /// No description provided for @skillsEmptyFormat.
  ///
  /// In en, this message translates to:
  /// **'---\nname: my-skill\ndescription: What this skill does\n---\n\n# Instructions'**
  String get skillsEmptyFormat;

  /// No description provided for @skillsImport.
  ///
  /// In en, this message translates to:
  /// **'Import'**
  String get skillsImport;

  /// No description provided for @skillsImportPaste.
  ///
  /// In en, this message translates to:
  /// **'Paste markdown'**
  String get skillsImportPaste;

  /// No description provided for @skillsImportFile.
  ///
  /// In en, this message translates to:
  /// **'From file'**
  String get skillsImportFile;

  /// No description provided for @skillsImportGitHub.
  ///
  /// In en, this message translates to:
  /// **'From GitHub'**
  String get skillsImportGitHub;

  /// No description provided for @skillsImportPasteLabel.
  ///
  /// In en, this message translates to:
  /// **'SKILL.md'**
  String get skillsImportPasteLabel;

  /// No description provided for @skillsImportPasteHint.
  ///
  /// In en, this message translates to:
  /// **'Paste a SKILL.md with YAML frontmatter'**
  String get skillsImportPasteHint;

  /// No description provided for @skillsImportGitHubLabel.
  ///
  /// In en, this message translates to:
  /// **'GitHub URL'**
  String get skillsImportGitHubLabel;

  /// No description provided for @skillsImportGitHubHint.
  ///
  /// In en, this message translates to:
  /// **'github.com/owner/repo or github.com/owner/repo/tree/ref/path'**
  String get skillsImportGitHubHint;

  /// No description provided for @skillsImportConfirm.
  ///
  /// In en, this message translates to:
  /// **'Import'**
  String get skillsImportConfirm;

  /// No description provided for @skillsCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get skillsCancel;

  /// No description provided for @skillsSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get skillsSave;

  /// No description provided for @skillsUsedCount.
  ///
  /// In en, this message translates to:
  /// **'used {count} times'**
  String skillsUsedCount(int count);

  /// No description provided for @skillsEnabled.
  ///
  /// In en, this message translates to:
  /// **'Enabled'**
  String get skillsEnabled;

  /// No description provided for @skillsBrowseFiles.
  ///
  /// In en, this message translates to:
  /// **'Browse files'**
  String get skillsBrowseFiles;

  /// No description provided for @skillsEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get skillsEdit;

  /// No description provided for @skillsExport.
  ///
  /// In en, this message translates to:
  /// **'Export'**
  String get skillsExport;

  /// No description provided for @skillsDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get skillsDelete;

  /// No description provided for @skillsDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete this skill?'**
  String get skillsDeleteTitle;

  /// No description provided for @skillsDeleteMessage.
  ///
  /// In en, this message translates to:
  /// **'Delete {name}? This cannot be undone.'**
  String skillsDeleteMessage(String name);

  /// No description provided for @skillsUseAll.
  ///
  /// In en, this message translates to:
  /// **'Use all skills'**
  String get skillsUseAll;

  /// No description provided for @skillsUseAllSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Every enabled skill is available to this assistant.'**
  String get skillsUseAllSubtitle;

  /// No description provided for @skillsDisabledHint.
  ///
  /// In en, this message translates to:
  /// **'Enable this skill in Skills to use it here.'**
  String get skillsDisabledHint;

  /// No description provided for @skillsOpenPage.
  ///
  /// In en, this message translates to:
  /// **'Manage skills'**
  String get skillsOpenPage;

  /// No description provided for @skillsInheritAssistant.
  ///
  /// In en, this message translates to:
  /// **'Inherit from assistant'**
  String get skillsInheritAssistant;

  /// No description provided for @skillsInheritAssistantSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Use the same skills as this conversation’s assistant.'**
  String get skillsInheritAssistantSubtitle;

  /// No description provided for @skillsActiveLabel.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get skillsActiveLabel;

  /// No description provided for @skillsSessionTitle.
  ///
  /// In en, this message translates to:
  /// **'Skills for this chat'**
  String get skillsSessionTitle;

  /// No description provided for @skillsEditTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit skill'**
  String get skillsEditTitle;

  /// No description provided for @skillsDetailKindLabel.
  ///
  /// In en, this message translates to:
  /// **'Skill'**
  String get skillsDetailKindLabel;

  /// No description provided for @skillsNoEnabled.
  ///
  /// In en, this message translates to:
  /// **'No enabled skills'**
  String get skillsNoEnabled;

  /// No description provided for @terminalTitle.
  ///
  /// In en, this message translates to:
  /// **'Terminal'**
  String get terminalTitle;

  /// No description provided for @terminalOpenInSystem.
  ///
  /// In en, this message translates to:
  /// **'Open in system terminal'**
  String get terminalOpenInSystem;

  /// No description provided for @terminalHostDirectory.
  ///
  /// In en, this message translates to:
  /// **'Host directory'**
  String get terminalHostDirectory;

  /// No description provided for @terminalBindWorkspaceFirst.
  ///
  /// In en, this message translates to:
  /// **'Bind a workspace first'**
  String get terminalBindWorkspaceFirst;

  /// No description provided for @terminalNotAvailable.
  ///
  /// In en, this message translates to:
  /// **'Not available'**
  String get terminalNotAvailable;

  /// No description provided for @terminalRuntimeUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Terminal environment is not ready'**
  String get terminalRuntimeUnavailable;

  /// No description provided for @terminalRename.
  ///
  /// In en, this message translates to:
  /// **'Rename'**
  String get terminalRename;

  /// No description provided for @terminalClose.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get terminalClose;

  /// No description provided for @terminalClear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get terminalClear;

  /// No description provided for @terminalCloseSession.
  ///
  /// In en, this message translates to:
  /// **'Close session'**
  String get terminalCloseSession;

  /// No description provided for @terminalCopy.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get terminalCopy;

  /// No description provided for @terminalPaste.
  ///
  /// In en, this message translates to:
  /// **'Paste'**
  String get terminalPaste;

  /// No description provided for @terminalNewSession.
  ///
  /// In en, this message translates to:
  /// **'New session'**
  String get terminalNewSession;

  /// No description provided for @terminalMore.
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get terminalMore;

  /// No description provided for @terminalNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get terminalNameLabel;

  /// No description provided for @terminalCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get terminalCancel;

  /// No description provided for @terminalSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get terminalSave;

  /// No description provided for @workspaceDeskMenuWorkspace.
  ///
  /// In en, this message translates to:
  /// **'Workspace'**
  String get workspaceDeskMenuWorkspace;

  /// No description provided for @workspaceDeskMenuSkills.
  ///
  /// In en, this message translates to:
  /// **'Skills'**
  String get workspaceDeskMenuSkills;

  /// No description provided for @workspaceDeskBarTitle.
  ///
  /// In en, this message translates to:
  /// **'Workspace'**
  String get workspaceDeskBarTitle;

  /// No description provided for @workspaceDeskBarNoWorkspace.
  ///
  /// In en, this message translates to:
  /// **'No workspace'**
  String get workspaceDeskBarNoWorkspace;

  /// No description provided for @workspaceDeskBarEmptyHint.
  ///
  /// In en, this message translates to:
  /// **'Bind a workspace from the toolbar to browse files here'**
  String get workspaceDeskBarEmptyHint;

  /// No description provided for @workspaceDeskBarToggle.
  ///
  /// In en, this message translates to:
  /// **'Workspace files'**
  String get workspaceDeskBarToggle;

  /// No description provided for @workspaceDeskOpenSystemTerminal.
  ///
  /// In en, this message translates to:
  /// **'Open in system terminal'**
  String get workspaceDeskOpenSystemTerminal;

  /// No description provided for @workspaceDeskReveal.
  ///
  /// In en, this message translates to:
  /// **'Reveal in file manager'**
  String get workspaceDeskReveal;

  /// No description provided for @workspaceDeskBarClose.
  ///
  /// In en, this message translates to:
  /// **'Close workspace bar'**
  String get workspaceDeskBarClose;

  /// No description provided for @workspaceEntryBind.
  ///
  /// In en, this message translates to:
  /// **'Bind workspace'**
  String get workspaceEntryBind;

  /// No description provided for @workspaceEntryUnbind.
  ///
  /// In en, this message translates to:
  /// **'Unbind'**
  String get workspaceEntryUnbind;

  /// No description provided for @workspaceEntryChange.
  ///
  /// In en, this message translates to:
  /// **'Change'**
  String get workspaceEntryChange;

  /// No description provided for @workspaceEntrySetAssistantDefault.
  ///
  /// In en, this message translates to:
  /// **'Set as assistant default'**
  String get workspaceEntrySetAssistantDefault;

  /// No description provided for @workspaceEntryLocked.
  ///
  /// In en, this message translates to:
  /// **'Locked'**
  String get workspaceEntryLocked;

  /// No description provided for @workspaceEntryChangeConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Change workspace?'**
  String get workspaceEntryChangeConfirmTitle;

  /// No description provided for @workspaceEntryUnbindConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Unbind?'**
  String get workspaceEntryUnbindConfirmTitle;

  /// No description provided for @workspaceEntryChangeConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'This conversation has already used workspace tools. File links in earlier messages may no longer work.'**
  String get workspaceEntryChangeConfirmBody;

  /// No description provided for @workspaceEntryCwd.
  ///
  /// In en, this message translates to:
  /// **'Working directory'**
  String get workspaceEntryCwd;

  /// No description provided for @workspaceEntryCwdHint.
  ///
  /// In en, this message translates to:
  /// **'Relative to the workspace root'**
  String get workspaceEntryCwdHint;

  /// No description provided for @workspaceEntryCwdInvalid.
  ///
  /// In en, this message translates to:
  /// **'That path is invalid or leaves the workspace'**
  String get workspaceEntryCwdInvalid;

  /// No description provided for @workspaceEntryCwdMissing.
  ///
  /// In en, this message translates to:
  /// **'That directory does not exist'**
  String get workspaceEntryCwdMissing;

  /// No description provided for @workspaceEntryCwdCreate.
  ///
  /// In en, this message translates to:
  /// **'Create it'**
  String get workspaceEntryCwdCreate;

  /// No description provided for @workspaceEntryFiles.
  ///
  /// In en, this message translates to:
  /// **'Files'**
  String get workspaceEntryFiles;

  /// No description provided for @workspaceEntryTerminal.
  ///
  /// In en, this message translates to:
  /// **'Terminal'**
  String get workspaceEntryTerminal;

  /// No description provided for @workspaceEntryOpenSystemTerminal.
  ///
  /// In en, this message translates to:
  /// **'Open in system terminal'**
  String get workspaceEntryOpenSystemTerminal;

  /// No description provided for @workspaceEntryReveal.
  ///
  /// In en, this message translates to:
  /// **'Reveal in file manager'**
  String get workspaceEntryReveal;

  /// No description provided for @workspaceEntrySessionSkills.
  ///
  /// In en, this message translates to:
  /// **'Skills'**
  String get workspaceEntrySessionSkills;

  /// No description provided for @workspaceEntryEnvironment.
  ///
  /// In en, this message translates to:
  /// **'Environment'**
  String get workspaceEntryEnvironment;

  /// No description provided for @workspaceEntryManage.
  ///
  /// In en, this message translates to:
  /// **'Manage workspaces'**
  String get workspaceEntryManage;

  /// No description provided for @workspaceEntryCreate.
  ///
  /// In en, this message translates to:
  /// **'Create new workspace…'**
  String get workspaceEntryCreate;

  /// No description provided for @workspaceEntryDefaultWorkspace.
  ///
  /// In en, this message translates to:
  /// **'Default workspace'**
  String get workspaceEntryDefaultWorkspace;

  /// No description provided for @workspaceEntryDefaultWorkspaceSubtitle.
  ///
  /// In en, this message translates to:
  /// **'New conversations use this workspace. Existing conversations stay unchanged.'**
  String get workspaceEntryDefaultWorkspaceSubtitle;

  /// No description provided for @workspaceEntryDefaultWorkspaceUnset.
  ///
  /// In en, this message translates to:
  /// **'Not set'**
  String get workspaceEntryDefaultWorkspaceUnset;

  /// No description provided for @workspaceEntryDefaultWorkspaceAutomaticSubtitle.
  ///
  /// In en, this message translates to:
  /// **'The first workspace you bind to a conversation will be remembered for new conversations.'**
  String get workspaceEntryDefaultWorkspaceAutomaticSubtitle;

  /// No description provided for @workspaceBindingRememberedDefault.
  ///
  /// In en, this message translates to:
  /// **'Remembered as the default workspace for “{assistant}”. New conversations will use it.'**
  String workspaceBindingRememberedDefault(String assistant);

  /// No description provided for @workspaceBindingSuggestDefault.
  ///
  /// In en, this message translates to:
  /// **'Use this workspace for future conversations with “{assistant}” too?'**
  String workspaceBindingSuggestDefault(String assistant);

  /// No description provided for @workspaceBindingUndoDefault.
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get workspaceBindingUndoDefault;

  /// No description provided for @workspaceBindingUseAsDefault.
  ///
  /// In en, this message translates to:
  /// **'Set as default'**
  String get workspaceBindingUseAsDefault;

  /// No description provided for @workspaceEntryNone.
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get workspaceEntryNone;

  /// No description provided for @workspaceEntryStartConversationFirst.
  ///
  /// In en, this message translates to:
  /// **'Start a conversation first'**
  String get workspaceEntryStartConversationFirst;

  /// No description provided for @workspaceEntryTooltip.
  ///
  /// In en, this message translates to:
  /// **'Workspace'**
  String get workspaceEntryTooltip;

  /// No description provided for @workspaceEntryPickerTitle.
  ///
  /// In en, this message translates to:
  /// **'Choose a workspace'**
  String get workspaceEntryPickerTitle;

  /// No description provided for @settingsPageWorkspace.
  ///
  /// In en, this message translates to:
  /// **'Workspace & environment'**
  String get settingsPageWorkspace;

  /// No description provided for @settingsPageSkills.
  ///
  /// In en, this message translates to:
  /// **'Skills'**
  String get settingsPageSkills;

  /// No description provided for @commonClose.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get commonClose;

  /// No description provided for @terminalCopyAllOutput.
  ///
  /// In en, this message translates to:
  /// **'Copy all output'**
  String get terminalCopyAllOutput;

  /// No description provided for @terminalFontDecrease.
  ///
  /// In en, this message translates to:
  /// **'Font size −'**
  String get terminalFontDecrease;

  /// No description provided for @terminalFontIncrease.
  ///
  /// In en, this message translates to:
  /// **'Font size +'**
  String get terminalFontIncrease;

  /// No description provided for @terminalCloseSessionConfirmMessage.
  ///
  /// In en, this message translates to:
  /// **'This session is still running. Closing it will end the process.'**
  String get terminalCloseSessionConfirmMessage;

  /// No description provided for @terminalCopiedAll.
  ///
  /// In en, this message translates to:
  /// **'Copied all output'**
  String get terminalCopiedAll;

  /// No description provided for @terminalConfirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get terminalConfirm;

  /// No description provided for @terminalExitCode.
  ///
  /// In en, this message translates to:
  /// **'exit {code}'**
  String terminalExitCode(int code);

  /// No description provided for @workspaceMgmtNewWorkspace.
  ///
  /// In en, this message translates to:
  /// **'New workspace'**
  String get workspaceMgmtNewWorkspace;

  /// No description provided for @workspaceMgmtEmptyHint.
  ///
  /// In en, this message translates to:
  /// **'Create a workspace to keep project files together.'**
  String get workspaceMgmtEmptyHint;

  /// No description provided for @workspaceMgmtKindManagedTitle.
  ///
  /// In en, this message translates to:
  /// **'Managed workspace'**
  String get workspaceMgmtKindManagedTitle;

  /// No description provided for @workspaceMgmtKindManagedSubtitle.
  ///
  /// In en, this message translates to:
  /// **'App-managed folder, sandbox read/write'**
  String get workspaceMgmtKindManagedSubtitle;

  /// No description provided for @workspaceMgmtKindLinkedTitle.
  ///
  /// In en, this message translates to:
  /// **'Linked folder'**
  String get workspaceMgmtKindLinkedTitle;

  /// No description provided for @workspaceMgmtKindLinkedSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Use a folder on this computer'**
  String get workspaceMgmtKindLinkedSubtitle;

  /// No description provided for @workspaceMgmtImportFromFolder.
  ///
  /// In en, this message translates to:
  /// **'Import from folder'**
  String get workspaceMgmtImportFromFolder;

  /// No description provided for @workspaceMgmtImportFromFolderSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Copy a folder into a new managed workspace'**
  String get workspaceMgmtImportFromFolderSubtitle;

  /// No description provided for @workspaceMgmtKindSection.
  ///
  /// In en, this message translates to:
  /// **'Type'**
  String get workspaceMgmtKindSection;

  /// No description provided for @workspaceMgmtCreate.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get workspaceMgmtCreate;

  /// No description provided for @workspaceMgmtShellApprovalSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Ask before each command'**
  String get workspaceMgmtShellApprovalSubtitle;

  /// No description provided for @workspaceMgmtDefaultCwdRoot.
  ///
  /// In en, this message translates to:
  /// **'/'**
  String get workspaceMgmtDefaultCwdRoot;

  /// No description provided for @workspaceMgmtPickCwdTitle.
  ///
  /// In en, this message translates to:
  /// **'Default working directory'**
  String get workspaceMgmtPickCwdTitle;

  /// No description provided for @workspaceMgmtFolderPickerUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Folder picker is not available.'**
  String get workspaceMgmtFolderPickerUnavailable;

  /// No description provided for @workspaceMgmtImportProgressTitle.
  ///
  /// In en, this message translates to:
  /// **'Importing folder'**
  String get workspaceMgmtImportProgressTitle;

  /// No description provided for @workspaceMgmtImportProgressPhase.
  ///
  /// In en, this message translates to:
  /// **'Copying files…'**
  String get workspaceMgmtImportProgressPhase;

  /// No description provided for @workspaceMgmtImportFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not import that folder.'**
  String get workspaceMgmtImportFailed;

  /// No description provided for @workspaceMgmtImportDone.
  ///
  /// In en, this message translates to:
  /// **'Imported {name}'**
  String workspaceMgmtImportDone(String name);

  /// No description provided for @workspaceMgmtLastUsedJustNow.
  ///
  /// In en, this message translates to:
  /// **'just now'**
  String get workspaceMgmtLastUsedJustNow;

  /// No description provided for @workspaceMgmtLastUsedMinutesAgo.
  ///
  /// In en, this message translates to:
  /// **'{n} min ago'**
  String workspaceMgmtLastUsedMinutesAgo(int n);

  /// No description provided for @workspaceMgmtLastUsedHoursAgo.
  ///
  /// In en, this message translates to:
  /// **'{n} hr ago'**
  String workspaceMgmtLastUsedHoursAgo(int n);

  /// No description provided for @workspaceMgmtLastUsedDaysAgo.
  ///
  /// In en, this message translates to:
  /// **'{n} d ago'**
  String workspaceMgmtLastUsedDaysAgo(int n);

  /// No description provided for @workspaceMgmtRowDetail.
  ///
  /// In en, this message translates to:
  /// **'{kind} · Last used {when}'**
  String workspaceMgmtRowDetail(String kind, String when);

  /// No description provided for @workspaceMgmtRowDetailNever.
  ///
  /// In en, this message translates to:
  /// **'{kind} · Never used'**
  String workspaceMgmtRowDetailNever(String kind);

  /// No description provided for @workspacePreviewBack.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get workspacePreviewBack;

  /// No description provided for @workspacePreviewWrap.
  ///
  /// In en, this message translates to:
  /// **'Wrap lines'**
  String get workspacePreviewWrap;

  /// No description provided for @workspacePreviewFontDecrease.
  ///
  /// In en, this message translates to:
  /// **'Smaller text'**
  String get workspacePreviewFontDecrease;

  /// No description provided for @workspacePreviewFontIncrease.
  ///
  /// In en, this message translates to:
  /// **'Larger text'**
  String get workspacePreviewFontIncrease;

  /// No description provided for @workspacePreviewCopy.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get workspacePreviewCopy;

  /// No description provided for @workspacePreviewRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get workspacePreviewRetry;

  /// No description provided for @workspacePreviewLoadError.
  ///
  /// In en, this message translates to:
  /// **'Couldn’t load this file.'**
  String get workspacePreviewLoadError;

  /// No description provided for @workspacePreviewRevealInFinder.
  ///
  /// In en, this message translates to:
  /// **'Show in Finder'**
  String get workspacePreviewRevealInFinder;

  /// No description provided for @workspacePreviewOpenInSystemApp.
  ///
  /// In en, this message translates to:
  /// **'Open with system app'**
  String get workspacePreviewOpenInSystemApp;

  /// No description provided for @workspacePreviewOpenInBrowser.
  ///
  /// In en, this message translates to:
  /// **'Open in browser'**
  String get workspacePreviewOpenInBrowser;

  /// No description provided for @workspacePreviewTable.
  ///
  /// In en, this message translates to:
  /// **'Table'**
  String get workspacePreviewTable;

  /// No description provided for @workspacePreviewPlainLanguage.
  ///
  /// In en, this message translates to:
  /// **'Code'**
  String get workspacePreviewPlainLanguage;

  /// No description provided for @workspacePreviewOpen.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get workspacePreviewOpen;

  /// No description provided for @workspacePreviewRevealFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn’t show this file in the file manager.'**
  String get workspacePreviewRevealFailed;

  /// No description provided for @workspacePreviewEmptyTable.
  ///
  /// In en, this message translates to:
  /// **'This table is empty.'**
  String get workspacePreviewEmptyTable;

  /// No description provided for @workspaceFilesNew.
  ///
  /// In en, this message translates to:
  /// **'New'**
  String get workspaceFilesNew;

  /// No description provided for @workspaceFilesFoldersFirst.
  ///
  /// In en, this message translates to:
  /// **'Folders first'**
  String get workspaceFilesFoldersFirst;

  /// No description provided for @workspaceFilesSelectDirectory.
  ///
  /// In en, this message translates to:
  /// **'Select this folder'**
  String get workspaceFilesSelectDirectory;

  /// No description provided for @workspaceFilesEmptyHint.
  ///
  /// In en, this message translates to:
  /// **'Use New or Import to add files'**
  String get workspaceFilesEmptyHint;

  /// No description provided for @workspaceFilesEmptyAttachments.
  ///
  /// In en, this message translates to:
  /// **'No attachments yet'**
  String get workspaceFilesEmptyAttachments;

  /// No description provided for @workspaceFilesEmptyOutputs.
  ///
  /// In en, this message translates to:
  /// **'The assistant hasn’t produced any files yet'**
  String get workspaceFilesEmptyOutputs;

  /// No description provided for @workspaceFilesMoveTo.
  ///
  /// In en, this message translates to:
  /// **'Move to…'**
  String get workspaceFilesMoveTo;

  /// No description provided for @workspaceFilesItemCount.
  ///
  /// In en, this message translates to:
  /// **'{count} items'**
  String workspaceFilesItemCount(int count);

  /// No description provided for @skillsImportTooltip.
  ///
  /// In en, this message translates to:
  /// **'Import skill'**
  String get skillsImportTooltip;

  /// No description provided for @skillsImportPasteSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Paste SKILL.md with YAML frontmatter'**
  String get skillsImportPasteSubtitle;

  /// No description provided for @skillsImportFileSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Choose a .md or .zip file'**
  String get skillsImportFileSubtitle;

  /// No description provided for @skillsImportGitHubSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Import SKILL.md from a repository'**
  String get skillsImportGitHubSubtitle;

  /// No description provided for @skillsImportResolving.
  ///
  /// In en, this message translates to:
  /// **'Resolving repository…'**
  String get skillsImportResolving;

  /// No description provided for @skillsImportDownloading.
  ///
  /// In en, this message translates to:
  /// **'Downloading…'**
  String get skillsImportDownloading;

  /// No description provided for @skillsImportExtracting.
  ///
  /// In en, this message translates to:
  /// **'Extracting…'**
  String get skillsImportExtracting;

  /// No description provided for @skillsImportInstalling.
  ///
  /// In en, this message translates to:
  /// **'Installing…'**
  String get skillsImportInstalling;

  /// No description provided for @skillsImportGitHubRepoLabel.
  ///
  /// In en, this message translates to:
  /// **'Repository URL'**
  String get skillsImportGitHubRepoLabel;

  /// No description provided for @skillsImportGitHubUrlHint.
  ///
  /// In en, this message translates to:
  /// **'https://github.com/owner/repo or owner/repo[/path]'**
  String get skillsImportGitHubUrlHint;

  /// No description provided for @skillsImportGitHubHelp.
  ///
  /// In en, this message translates to:
  /// **'SKILL.md at the repo root or in a subdirectory is supported.'**
  String get skillsImportGitHubHelp;

  /// No description provided for @skillsEmptyHint.
  ///
  /// In en, this message translates to:
  /// **'A skill is a SKILL.md with frontmatter. After import, the assistant can use it on demand.'**
  String get skillsEmptyHint;

  /// No description provided for @skillsMoreActions.
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get skillsMoreActions;

  /// No description provided for @skillsSearchClear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get skillsSearchClear;

  /// No description provided for @skillsSessionEmpty.
  ///
  /// In en, this message translates to:
  /// **'No enabled skills yet. Enable skills in the library first.'**
  String get skillsSessionEmpty;

  /// No description provided for @workspaceToolRunning.
  ///
  /// In en, this message translates to:
  /// **'Running'**
  String get workspaceToolRunning;

  /// No description provided for @workspaceToolExitCode.
  ///
  /// In en, this message translates to:
  /// **'exit {code}'**
  String workspaceToolExitCode(int code);

  /// No description provided for @workspaceToolAwaitingApproval.
  ///
  /// In en, this message translates to:
  /// **'Awaiting approval'**
  String get workspaceToolAwaitingApproval;

  /// No description provided for @workspaceToolCompleted.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get workspaceToolCompleted;

  /// No description provided for @workspaceToolLines.
  ///
  /// In en, this message translates to:
  /// **'{count} lines'**
  String workspaceToolLines(int count);

  /// No description provided for @workspaceToolItems.
  ///
  /// In en, this message translates to:
  /// **'{count} items'**
  String workspaceToolItems(int count);

  /// No description provided for @workspaceToolFileMatches.
  ///
  /// In en, this message translates to:
  /// **'{count} matches'**
  String workspaceToolFileMatches(int count);

  /// No description provided for @workspaceToolContentMatches.
  ///
  /// In en, this message translates to:
  /// **'{count} matches'**
  String workspaceToolContentMatches(int count);

  /// No description provided for @workspaceToolExpand.
  ///
  /// In en, this message translates to:
  /// **'Expand'**
  String get workspaceToolExpand;

  /// No description provided for @workspaceToolSectionCommand.
  ///
  /// In en, this message translates to:
  /// **'Command'**
  String get workspaceToolSectionCommand;

  /// No description provided for @workspaceToolSectionPath.
  ///
  /// In en, this message translates to:
  /// **'Path'**
  String get workspaceToolSectionPath;

  /// No description provided for @workspaceToolSectionPattern.
  ///
  /// In en, this message translates to:
  /// **'Pattern'**
  String get workspaceToolSectionPattern;

  /// No description provided for @workspaceToolSectionOutput.
  ///
  /// In en, this message translates to:
  /// **'Output'**
  String get workspaceToolSectionOutput;

  /// No description provided for @workspaceToolSectionDiff.
  ///
  /// In en, this message translates to:
  /// **'Diff'**
  String get workspaceToolSectionDiff;

  /// No description provided for @workspaceToolSectionError.
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get workspaceToolSectionError;

  /// No description provided for @workspaceToolSavedOutput.
  ///
  /// In en, this message translates to:
  /// **'Full output saved'**
  String get workspaceToolSavedOutput;

  /// No description provided for @workspaceToolApprove.
  ///
  /// In en, this message translates to:
  /// **'Allow'**
  String get workspaceToolApprove;

  /// No description provided for @workspaceToolDeny.
  ///
  /// In en, this message translates to:
  /// **'Deny'**
  String get workspaceToolDeny;

  /// No description provided for @workspaceToolCopy.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get workspaceToolCopy;

  /// No description provided for @workspaceEnvEngineLocalShell.
  ///
  /// In en, this message translates to:
  /// **'Local shell'**
  String get workspaceEnvEngineLocalShell;

  /// No description provided for @workspaceEnvInstallEnvironment.
  ///
  /// In en, this message translates to:
  /// **'Install environment'**
  String get workspaceEnvInstallEnvironment;

  /// No description provided for @workspaceEnvInstallDescription.
  ///
  /// In en, this message translates to:
  /// **'Install a Linux environment to run tools in a sandbox.'**
  String get workspaceEnvInstallDescription;

  /// No description provided for @workspaceEnvStatusLabel.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get workspaceEnvStatusLabel;

  /// No description provided for @workspaceEnvStatusInstalled.
  ///
  /// In en, this message translates to:
  /// **'Installed'**
  String get workspaceEnvStatusInstalled;

  /// No description provided for @workspaceEnvSizeLabel.
  ///
  /// In en, this message translates to:
  /// **'Size'**
  String get workspaceEnvSizeLabel;

  /// No description provided for @workspaceEnvPathLabel.
  ///
  /// In en, this message translates to:
  /// **'Path'**
  String get workspaceEnvPathLabel;

  /// No description provided for @workspaceEnvInstalledAtLabel.
  ///
  /// In en, this message translates to:
  /// **'Installed'**
  String get workspaceEnvInstalledAtLabel;

  /// No description provided for @workspaceEnvArchLabel.
  ///
  /// In en, this message translates to:
  /// **'Architecture'**
  String get workspaceEnvArchLabel;

  /// No description provided for @workspaceEnvArchVersion.
  ///
  /// In en, this message translates to:
  /// **'{arch} · {version}'**
  String workspaceEnvArchVersion(String arch, String version);

  /// No description provided for @workspaceEnvBrowseSection.
  ///
  /// In en, this message translates to:
  /// **'Browse'**
  String get workspaceEnvBrowseSection;

  /// No description provided for @workspaceEnvBrowseFiles.
  ///
  /// In en, this message translates to:
  /// **'Browse file system'**
  String get workspaceEnvBrowseFiles;

  /// No description provided for @workspaceEnvBrowseFilesDetail.
  ///
  /// In en, this message translates to:
  /// **'View the full directory tree inside the sandbox'**
  String get workspaceEnvBrowseFilesDetail;

  /// No description provided for @workspaceEnvDetectFastMirrors.
  ///
  /// In en, this message translates to:
  /// **'Detect fast mirrors'**
  String get workspaceEnvDetectFastMirrors;

  /// No description provided for @workspaceEnvActionsSection.
  ///
  /// In en, this message translates to:
  /// **'Actions'**
  String get workspaceEnvActionsSection;

  /// No description provided for @workspaceEnvInfoSection.
  ///
  /// In en, this message translates to:
  /// **'Info'**
  String get workspaceEnvInfoSection;

  /// No description provided for @workspaceEnvInfoBody.
  ///
  /// In en, this message translates to:
  /// **'The environment is a Linux root filesystem used by the sandbox. Workspaces are stored separately and are not deleted when you reset. Files live in the extracted rootfs on this device.'**
  String get workspaceEnvInfoBody;

  /// No description provided for @workspaceEnvRepairDetail.
  ///
  /// In en, this message translates to:
  /// **'Re-verify and patch files'**
  String get workspaceEnvRepairDetail;

  /// No description provided for @workspaceEnvUpdateCurrent.
  ///
  /// In en, this message translates to:
  /// **'You\'re up to date'**
  String get workspaceEnvUpdateCurrent;

  /// No description provided for @workspaceEnvUpdateAvailableShort.
  ///
  /// In en, this message translates to:
  /// **'Update available: {version}'**
  String workspaceEnvUpdateAvailableShort(String version);

  /// No description provided for @workspaceEnvResetConfirmMessage.
  ///
  /// In en, this message translates to:
  /// **'This will delete the entire Linux environment and any packages installed in it. Workspace files are not affected.'**
  String get workspaceEnvResetConfirmMessage;

  /// No description provided for @workspaceEnvRestartDoneBanner.
  ///
  /// In en, this message translates to:
  /// **'Reset finished. Restart the app to complete installation.'**
  String get workspaceEnvRestartDoneBanner;

  /// No description provided for @workspaceEnvPathCopied.
  ///
  /// In en, this message translates to:
  /// **'Path copied'**
  String get workspaceEnvPathCopied;

  /// No description provided for @workspaceEnvUseMirrorSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Write the selected mirror into the sandbox'**
  String get workspaceEnvUseMirrorSubtitle;

  /// No description provided for @workspaceEnvRegionGlobal.
  ///
  /// In en, this message translates to:
  /// **'Global'**
  String get workspaceEnvRegionGlobal;

  /// No description provided for @workspaceEnvRegionChina.
  ///
  /// In en, this message translates to:
  /// **'China'**
  String get workspaceEnvRegionChina;

  /// No description provided for @workspaceEnvRegionEurope.
  ///
  /// In en, this message translates to:
  /// **'Europe'**
  String get workspaceEnvRegionEurope;

  /// No description provided for @workspaceEnvRegionAsia.
  ///
  /// In en, this message translates to:
  /// **'Asia'**
  String get workspaceEnvRegionAsia;

  /// No description provided for @workspaceEnvMirrorTimeout.
  ///
  /// In en, this message translates to:
  /// **'Timeout'**
  String get workspaceEnvMirrorTimeout;

  /// No description provided for @workspaceEnvSpeedTest.
  ///
  /// In en, this message translates to:
  /// **'Test speed'**
  String get workspaceEnvSpeedTest;

  /// No description provided for @workspaceEnvApplySuccess.
  ///
  /// In en, this message translates to:
  /// **'Mirror applied'**
  String get workspaceEnvApplySuccess;

  /// No description provided for @workspaceEnvApplyFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not apply mirror'**
  String get workspaceEnvApplyFailed;

  /// No description provided for @workspaceEnvRestoreSuccess.
  ///
  /// In en, this message translates to:
  /// **'Official source restored'**
  String get workspaceEnvRestoreSuccess;

  /// No description provided for @workspaceEnvMirrorsTested.
  ///
  /// In en, this message translates to:
  /// **'Fastest mirrors applied'**
  String get workspaceEnvMirrorsTested;

  /// No description provided for @workspaceEnvRelativeJustNow.
  ///
  /// In en, this message translates to:
  /// **'Just now'**
  String get workspaceEnvRelativeJustNow;

  /// No description provided for @workspaceEnvRelativeMinutesAgo.
  ///
  /// In en, this message translates to:
  /// **'{count}m ago'**
  String workspaceEnvRelativeMinutesAgo(int count);

  /// No description provided for @workspaceEnvRelativeHoursAgo.
  ///
  /// In en, this message translates to:
  /// **'{count}h ago'**
  String workspaceEnvRelativeHoursAgo(int count);

  /// No description provided for @workspaceEnvRelativeDaysAgo.
  ///
  /// In en, this message translates to:
  /// **'{count}d ago'**
  String workspaceEnvRelativeDaysAgo(int count);

  /// No description provided for @workspaceEnvDownloadLine.
  ///
  /// In en, this message translates to:
  /// **'{downloaded} / {total} · {phase}'**
  String workspaceEnvDownloadLine(
    String downloaded,
    String total,
    String phase,
  );

  /// No description provided for @workspaceEnvNativeUnsandboxed.
  ///
  /// In en, this message translates to:
  /// **'Commands run on this computer without a sandbox and need approval unless this chat has full access.'**
  String get workspaceEnvNativeUnsandboxed;

  /// No description provided for @workspaceEnvRootfsTitle.
  ///
  /// In en, this message translates to:
  /// **'/'**
  String get workspaceEnvRootfsTitle;

  /// No description provided for @workspaceEnvBrowserUnavailable.
  ///
  /// In en, this message translates to:
  /// **'The sandbox file system is not available.'**
  String get workspaceEnvBrowserUnavailable;

  /// No description provided for @workspaceEnvMirrorNameOfficial.
  ///
  /// In en, this message translates to:
  /// **'Official'**
  String get workspaceEnvMirrorNameOfficial;

  /// No description provided for @workspaceEnvMirrorNameOfficialCdn.
  ///
  /// In en, this message translates to:
  /// **'Official CDN'**
  String get workspaceEnvMirrorNameOfficialCdn;

  /// No description provided for @workspaceEnvMirrorNameOfficialPypi.
  ///
  /// In en, this message translates to:
  /// **'Official PyPI'**
  String get workspaceEnvMirrorNameOfficialPypi;

  /// No description provided for @workspaceEnvMirrorNameOfficialNpm.
  ///
  /// In en, this message translates to:
  /// **'Official npm'**
  String get workspaceEnvMirrorNameOfficialNpm;

  /// No description provided for @workspaceEnvMirrorNameTuna.
  ///
  /// In en, this message translates to:
  /// **'Tsinghua TUNA'**
  String get workspaceEnvMirrorNameTuna;

  /// No description provided for @workspaceEnvMirrorNameAlibaba.
  ///
  /// In en, this message translates to:
  /// **'Alibaba'**
  String get workspaceEnvMirrorNameAlibaba;

  /// No description provided for @workspaceEnvMirrorNameUstc.
  ///
  /// In en, this message translates to:
  /// **'USTC'**
  String get workspaceEnvMirrorNameUstc;

  /// No description provided for @workspaceEnvMirrorNameHuawei.
  ///
  /// In en, this message translates to:
  /// **'Huawei'**
  String get workspaceEnvMirrorNameHuawei;

  /// No description provided for @workspaceEnvMirrorNameTencent.
  ///
  /// In en, this message translates to:
  /// **'Tencent'**
  String get workspaceEnvMirrorNameTencent;

  /// No description provided for @workspaceEnvMirrorNameNetease.
  ///
  /// In en, this message translates to:
  /// **'NetEase'**
  String get workspaceEnvMirrorNameNetease;

  /// No description provided for @workspaceEnvMirrorNameLeaseweb.
  ///
  /// In en, this message translates to:
  /// **'LEASEWEB UK'**
  String get workspaceEnvMirrorNameLeaseweb;

  /// No description provided for @workspaceEnvMirrorNameRwth.
  ///
  /// In en, this message translates to:
  /// **'RWTH Germany'**
  String get workspaceEnvMirrorNameRwth;

  /// No description provided for @workspaceEnvMirrorNameJaist.
  ///
  /// In en, this message translates to:
  /// **'JAIST Japan'**
  String get workspaceEnvMirrorNameJaist;

  /// No description provided for @workspaceEnvMirrorNameKakao.
  ///
  /// In en, this message translates to:
  /// **'Kakao Korea'**
  String get workspaceEnvMirrorNameKakao;

  /// No description provided for @workspaceEnvMirrorNameNpmmirror.
  ///
  /// In en, this message translates to:
  /// **'npmmirror'**
  String get workspaceEnvMirrorNameNpmmirror;

  /// No description provided for @workspaceEnvSelectionNamed.
  ///
  /// In en, this message translates to:
  /// **'{name} · {region}'**
  String workspaceEnvSelectionNamed(String name, String region);

  /// No description provided for @workspaceFilesEmptyPickerHint.
  ///
  /// In en, this message translates to:
  /// **'Use New folder to add a subfolder'**
  String get workspaceFilesEmptyPickerHint;

  /// No description provided for @skillsDetailBodyEmpty.
  ///
  /// In en, this message translates to:
  /// **'No skill body yet'**
  String get skillsDetailBodyEmpty;

  /// No description provided for @skillsDetailBodyTooLarge.
  ///
  /// In en, this message translates to:
  /// **'This file is too large to preview ({size}).'**
  String skillsDetailBodyTooLarge(String size);

  /// No description provided for @workspaceEnvSizeTimeout.
  ///
  /// In en, this message translates to:
  /// **'Timed out'**
  String get workspaceEnvSizeTimeout;

  /// No description provided for @workspaceEnvInfoCopied.
  ///
  /// In en, this message translates to:
  /// **'Environment info copied'**
  String get workspaceEnvInfoCopied;

  /// No description provided for @workspacePreviewEmptyFile.
  ///
  /// In en, this message translates to:
  /// **'This file is empty'**
  String get workspacePreviewEmptyFile;

  /// No description provided for @workspacePreviewEmptyHint.
  ///
  /// In en, this message translates to:
  /// **'There\'s nothing to preview.'**
  String get workspacePreviewEmptyHint;

  /// No description provided for @workspacePreviewRevealInExplorer.
  ///
  /// In en, this message translates to:
  /// **'Show in File Explorer'**
  String get workspacePreviewRevealInExplorer;

  /// No description provided for @workspacePreviewRevealInFileManager.
  ///
  /// In en, this message translates to:
  /// **'Show in Files'**
  String get workspacePreviewRevealInFileManager;

  /// No description provided for @workspaceBindingSetAssistantDefault.
  ///
  /// In en, this message translates to:
  /// **'Set as default workspace for “{assistant}”'**
  String workspaceBindingSetAssistantDefault(String assistant);

  /// No description provided for @storageSpaceCategoryWorkspaceFiles.
  ///
  /// In en, this message translates to:
  /// **'Workspace files'**
  String get storageSpaceCategoryWorkspaceFiles;

  /// No description provided for @storageSpaceCategoryWorkspaceFilesHint.
  ///
  /// In en, this message translates to:
  /// **'Files stored in managed workspaces.'**
  String get storageSpaceCategoryWorkspaceFilesHint;

  /// No description provided for @storageSpaceCategorySandboxEnvironment.
  ///
  /// In en, this message translates to:
  /// **'Sandbox environment'**
  String get storageSpaceCategorySandboxEnvironment;

  /// No description provided for @storageSpaceCategorySandboxEnvironmentHint.
  ///
  /// In en, this message translates to:
  /// **'Sandbox install and root filesystem.'**
  String get storageSpaceCategorySandboxEnvironmentHint;

  /// No description provided for @storageSpaceCategorySkills.
  ///
  /// In en, this message translates to:
  /// **'Skills'**
  String get storageSpaceCategorySkills;

  /// No description provided for @storageSpaceCategorySkillsHint.
  ///
  /// In en, this message translates to:
  /// **'Installed skill files.'**
  String get storageSpaceCategorySkillsHint;

  /// No description provided for @storageSpaceCategorySessionFiles.
  ///
  /// In en, this message translates to:
  /// **'Conversation files'**
  String get storageSpaceCategorySessionFiles;

  /// No description provided for @storageSpaceCategorySessionFilesHint.
  ///
  /// In en, this message translates to:
  /// **'Per-conversation attachments and outputs.'**
  String get storageSpaceCategorySessionFilesHint;

  /// No description provided for @storageSpaceManageSkills.
  ///
  /// In en, this message translates to:
  /// **'Manage skills'**
  String get storageSpaceManageSkills;

  /// No description provided for @storageSessionFilesCleanOrphans.
  ///
  /// In en, this message translates to:
  /// **'Clean orphaned conversation files'**
  String get storageSessionFilesCleanOrphans;

  /// No description provided for @storageSessionFilesCleanOrphansHint.
  ///
  /// In en, this message translates to:
  /// **'Deletes session folders that no longer have a conversation. Reclaimable: {size}.'**
  String storageSessionFilesCleanOrphansHint(String size);

  /// No description provided for @workspaceDesktopFolderPath.
  ///
  /// In en, this message translates to:
  /// **'Folder path'**
  String get workspaceDesktopFolderPath;

  /// No description provided for @workspaceDesktopFolderMissing.
  ///
  /// In en, this message translates to:
  /// **'Choose an existing folder or enter its absolute path.'**
  String get workspaceDesktopFolderMissing;

  /// No description provided for @workspaceDesktopManagedHint.
  ///
  /// In en, this message translates to:
  /// **'Kelivo creates and manages a folder for this project.'**
  String get workspaceDesktopManagedHint;

  /// No description provided for @workspaceDesktopHostHint.
  ///
  /// In en, this message translates to:
  /// **'Files and commands use this computer.'**
  String get workspaceDesktopHostHint;

  /// No description provided for @workspaceDesktopSearch.
  ///
  /// In en, this message translates to:
  /// **'Search workspaces'**
  String get workspaceDesktopSearch;

  /// No description provided for @workspaceDesktopNoResults.
  ///
  /// In en, this message translates to:
  /// **'No matching workspaces'**
  String get workspaceDesktopNoResults;

  /// No description provided for @workspaceEnvDependencies.
  ///
  /// In en, this message translates to:
  /// **'Environment presets'**
  String get workspaceEnvDependencies;

  /// No description provided for @workspaceEnvDependenciesDetail.
  ///
  /// In en, this message translates to:
  /// **'Install tools in the shared sandbox. All workspaces can use them.'**
  String get workspaceEnvDependenciesDetail;

  /// No description provided for @workspaceEnvDependencyPython.
  ///
  /// In en, this message translates to:
  /// **'Python, pip and virtual environments'**
  String get workspaceEnvDependencyPython;

  /// No description provided for @workspaceEnvDependencyNode.
  ///
  /// In en, this message translates to:
  /// **'Node.js and npm'**
  String get workspaceEnvDependencyNode;

  /// No description provided for @workspaceEnvDependencyGit.
  ///
  /// In en, this message translates to:
  /// **'Clone repositories and manage versions'**
  String get workspaceEnvDependencyGit;

  /// No description provided for @workspaceEnvDependencySsh.
  ///
  /// In en, this message translates to:
  /// **'SSH, SCP, SFTP and key generation'**
  String get workspaceEnvDependencySsh;

  /// No description provided for @workspaceEnvDependencyNetwork.
  ///
  /// In en, this message translates to:
  /// **'Network tools'**
  String get workspaceEnvDependencyNetwork;

  /// No description provided for @workspaceEnvDependencyArchive.
  ///
  /// In en, this message translates to:
  /// **'Archive tools'**
  String get workspaceEnvDependencyArchive;

  /// No description provided for @workspaceEnvDependencyInstalled.
  ///
  /// In en, this message translates to:
  /// **'Installed'**
  String get workspaceEnvDependencyInstalled;

  /// No description provided for @workspaceEnvDependencyUnknown.
  ///
  /// In en, this message translates to:
  /// **'Not checked'**
  String get workspaceEnvDependencyUnknown;

  /// No description provided for @workspaceEnvDependencyChecking.
  ///
  /// In en, this message translates to:
  /// **'Checking tools…'**
  String get workspaceEnvDependencyChecking;

  /// No description provided for @workspaceEnvDependencyInstalling.
  ///
  /// In en, this message translates to:
  /// **'Installing…'**
  String get workspaceEnvDependencyInstalling;

  /// No description provided for @workspaceEnvDependencyCheckFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not check tools. Tap refresh to try again.'**
  String get workspaceEnvDependencyCheckFailed;

  /// No description provided for @workspaceEnvDependencyInstallFailed.
  ///
  /// In en, this message translates to:
  /// **'Installation did not finish. Check the log or change the package source, then retry.'**
  String get workspaceEnvDependencyInstallFailed;

  /// No description provided for @workspaceEnvDependencyLog.
  ///
  /// In en, this message translates to:
  /// **'Installation log'**
  String get workspaceEnvDependencyLog;

  /// No description provided for @workspaceEnvDependencyRefresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh tool status'**
  String get workspaceEnvDependencyRefresh;

  /// No description provided for @workspaceEnvDependencyReadyFirst.
  ///
  /// In en, this message translates to:
  /// **'Install the sandbox first to add these tools.'**
  String get workspaceEnvDependencyReadyFirst;

  /// No description provided for @workspaceEnvDependencySources.
  ///
  /// In en, this message translates to:
  /// **'Package sources'**
  String get workspaceEnvDependencySources;

  /// No description provided for @workspaceEnvDependencySourcesDetail.
  ///
  /// In en, this message translates to:
  /// **'Installation uses the selected apt/apk source. pip and npm sources apply to packages you install later.'**
  String get workspaceEnvDependencySourcesDetail;

  /// No description provided for @workspaceEnvDownloadSource.
  ///
  /// In en, this message translates to:
  /// **'Sandbox download source'**
  String get workspaceEnvDownloadSource;

  /// No description provided for @workspaceEnvDownloadAutomatic.
  ///
  /// In en, this message translates to:
  /// **'Auto-select fastest'**
  String get workspaceEnvDownloadAutomatic;

  /// No description provided for @workspaceEnvDownloadAutomaticDetail.
  ///
  /// In en, this message translates to:
  /// **'Test the official source and built-in mirrors before downloading.'**
  String get workspaceEnvDownloadAutomaticDetail;

  /// No description provided for @workspaceEnvDownloadCustom.
  ///
  /// In en, this message translates to:
  /// **'Custom URL'**
  String get workspaceEnvDownloadCustom;

  /// No description provided for @workspaceEnvDownloadCustomHint.
  ///
  /// In en, this message translates to:
  /// **'https://example.com/ubuntu-base/releases/24.04/release/'**
  String get workspaceEnvDownloadCustomHint;

  /// No description provided for @workspaceEnvDownloadCustomDetail.
  ///
  /// In en, this message translates to:
  /// **'Enter a release directory or a complete archive URL. The archive must match the selected system, version, and device architecture.'**
  String get workspaceEnvDownloadCustomDetail;

  /// No description provided for @workspaceEnvDownloadInvalidUrl.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid HTTP or HTTPS URL.'**
  String get workspaceEnvDownloadInvalidUrl;

  /// No description provided for @workspaceEnvDownloadVerified.
  ///
  /// In en, this message translates to:
  /// **'Downloads are verified against the selected image’s official SHA-256. Package sources are configured separately.'**
  String get workspaceEnvDownloadVerified;

  /// No description provided for @workspaceEnvDownloadStart.
  ///
  /// In en, this message translates to:
  /// **'Download and install'**
  String get workspaceEnvDownloadStart;

  /// No description provided for @workspaceEnvDownloadSave.
  ///
  /// In en, this message translates to:
  /// **'Save source'**
  String get workspaceEnvDownloadSave;

  /// No description provided for @workspaceToolsTitle.
  ///
  /// In en, this message translates to:
  /// **'Tools'**
  String get workspaceToolsTitle;

  /// No description provided for @workspaceToolsDescription.
  ///
  /// In en, this message translates to:
  /// **'Choose which tools conversations can use in this workspace. Changes are saved automatically.'**
  String get workspaceToolsDescription;

  /// No description provided for @workspaceToolHelpShell.
  ///
  /// In en, this message translates to:
  /// **'Run commands in the workspace environment.'**
  String get workspaceToolHelpShell;

  /// No description provided for @workspaceToolHelpRead.
  ///
  /// In en, this message translates to:
  /// **'Read files with line numbers and paging.'**
  String get workspaceToolHelpRead;

  /// No description provided for @workspaceToolHelpViewImage.
  ///
  /// In en, this message translates to:
  /// **'Let the model inspect an image from the workspace.'**
  String get workspaceToolHelpViewImage;

  /// No description provided for @workspaceToolHelpWrite.
  ///
  /// In en, this message translates to:
  /// **'Create files or overwrite their contents.'**
  String get workspaceToolHelpWrite;

  /// No description provided for @workspaceToolHelpEdit.
  ///
  /// In en, this message translates to:
  /// **'Replace specific text in an existing file.'**
  String get workspaceToolHelpEdit;

  /// No description provided for @workspaceToolHelpList.
  ///
  /// In en, this message translates to:
  /// **'Browse directories and their entries.'**
  String get workspaceToolHelpList;

  /// No description provided for @workspaceToolHelpGlob.
  ///
  /// In en, this message translates to:
  /// **'Find files by name or path pattern.'**
  String get workspaceToolHelpGlob;

  /// No description provided for @workspaceToolHelpGrep.
  ///
  /// In en, this message translates to:
  /// **'Search text inside files.'**
  String get workspaceToolHelpGrep;

  /// No description provided for @workspaceEnvVariablesTitle.
  ///
  /// In en, this message translates to:
  /// **'Environment variables'**
  String get workspaceEnvVariablesTitle;

  /// No description provided for @workspaceEnvVariablesEntryDetail.
  ///
  /// In en, this message translates to:
  /// **'Variables for commands, with output privacy controls'**
  String get workspaceEnvVariablesEntryDetail;

  /// No description provided for @workspaceEnvVariablesEmpty.
  ///
  /// In en, this message translates to:
  /// **'No variables yet. Add API keys or other configuration for your tools.'**
  String get workspaceEnvVariablesEmpty;

  /// No description provided for @workspaceEnvVariablesScope.
  ///
  /// In en, this message translates to:
  /// **'Shared by all workspaces. Changes apply to new Agent commands and new in-app terminal sessions; reopen existing sessions to apply them. External system terminals keep their own environment.'**
  String get workspaceEnvVariablesScope;

  /// No description provided for @workspaceEnvPrivacyMode.
  ///
  /// In en, this message translates to:
  /// **'Privacy mode'**
  String get workspaceEnvPrivacyMode;

  /// No description provided for @workspaceEnvPrivacyDetail.
  ///
  /// In en, this message translates to:
  /// **'Commands can use the real values. Before workspace tool output is sent to the model, matching values of at least 5 characters are replaced with [REDACTED]. Local logs remain unchanged. Shorter values are not masked, to avoid replacing common flags and numbers.'**
  String get workspaceEnvPrivacyDetail;

  /// No description provided for @workspaceEnvVariableAdd.
  ///
  /// In en, this message translates to:
  /// **'Add variable'**
  String get workspaceEnvVariableAdd;

  /// No description provided for @workspaceEnvVariableEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit variable'**
  String get workspaceEnvVariableEdit;

  /// No description provided for @workspaceEnvVariableName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get workspaceEnvVariableName;

  /// No description provided for @workspaceEnvVariableValue.
  ///
  /// In en, this message translates to:
  /// **'Value'**
  String get workspaceEnvVariableValue;

  /// No description provided for @workspaceEnvVariableNote.
  ///
  /// In en, this message translates to:
  /// **'Note (optional)'**
  String get workspaceEnvVariableNote;

  /// No description provided for @workspaceEnvVariableNameHint.
  ///
  /// In en, this message translates to:
  /// **'Use letters, digits and underscores; do not start with a digit. Names are case-sensitive. Reference variables in commands with \$NAME.'**
  String get workspaceEnvVariableNameHint;

  /// No description provided for @workspaceEnvVariableInvalidName.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid variable name.'**
  String get workspaceEnvVariableInvalidName;

  /// No description provided for @workspaceEnvVariableInvalidValue.
  ///
  /// In en, this message translates to:
  /// **'Enter a nonempty value without NUL characters.'**
  String get workspaceEnvVariableInvalidValue;

  /// No description provided for @workspaceEnvVariableDuplicate.
  ///
  /// In en, this message translates to:
  /// **'A variable with this name already exists.'**
  String get workspaceEnvVariableDuplicate;

  /// No description provided for @workspaceEnvVariablesSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not save the environment settings. Please try again.'**
  String get workspaceEnvVariablesSaveFailed;

  /// No description provided for @incomingShareTitle.
  ///
  /// In en, this message translates to:
  /// **'Shared content'**
  String get incomingShareTitle;

  /// No description provided for @incomingShareReplaceDraft.
  ///
  /// In en, this message translates to:
  /// **'There is unsent content in the input box. Replace it with the shared content in a new chat?'**
  String get incomingShareReplaceDraft;

  /// No description provided for @incomingShareFailed.
  ///
  /// In en, this message translates to:
  /// **'Some shared content could not be imported. Check file access and available storage. Up to 32 files can be shared at once.'**
  String get incomingShareFailed;

  /// No description provided for @incomingShareImporting.
  ///
  /// In en, this message translates to:
  /// **'Importing'**
  String get incomingShareImporting;

  /// No description provided for @incomingShareMoveTo.
  ///
  /// In en, this message translates to:
  /// **'Move to…'**
  String get incomingShareMoveTo;

  /// No description provided for @incomingShareNewChat.
  ///
  /// In en, this message translates to:
  /// **'New conversation'**
  String get incomingShareNewChat;

  /// No description provided for @incomingShareMoveHint.
  ///
  /// In en, this message translates to:
  /// **'Move this draft and its attachments to another conversation. Nothing will be sent automatically.'**
  String get incomingShareMoveHint;

  /// No description provided for @incomingShareNoConversations.
  ///
  /// In en, this message translates to:
  /// **'No matching conversations'**
  String get incomingShareNoConversations;

  /// No description provided for @chatInputBarRemoveAttachment.
  ///
  /// In en, this message translates to:
  /// **'Remove attachment'**
  String get chatInputBarRemoveAttachment;

  /// No description provided for @incomingShareMoveFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not switch conversations. Your draft has been kept.'**
  String get incomingShareMoveFailed;

  /// No description provided for @attachmentRequiresWorkspace.
  ///
  /// In en, this message translates to:
  /// **'To use “{name}”, bind a workspace and enable file tools, or move this draft to a conversation with a workspace. This file cannot be read directly in a regular chat.'**
  String attachmentRequiresWorkspace(String name);

  /// No description provided for @storageSessionFilesUnlinked.
  ///
  /// In en, this message translates to:
  /// **'Unlinked conversation'**
  String get storageSessionFilesUnlinked;

  /// No description provided for @workspaceExternalMount.
  ///
  /// In en, this message translates to:
  /// **'Mount external folder'**
  String get workspaceExternalMount;

  /// No description provided for @workspaceExternalMountSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Selected folders are mounted at /mounts/<name> and shared across workspaces. AI tools, Shell and the file browser can access them. Up to 10 folders.'**
  String get workspaceExternalMountSubtitle;

  /// No description provided for @workspaceExternalStorageTitle.
  ///
  /// In en, this message translates to:
  /// **'Allow file access'**
  String get workspaceExternalStorageTitle;

  /// No description provided for @workspaceExternalStorageMessage.
  ///
  /// In en, this message translates to:
  /// **'To read and write external folders in the workspace and Shell, allow Kelivo to manage files in Android settings. On Android 11 or later, enable All files access. Then select an on-device folder to mount.'**
  String get workspaceExternalStorageMessage;

  /// No description provided for @workspaceExternalGrantAccess.
  ///
  /// In en, this message translates to:
  /// **'Grant access'**
  String get workspaceExternalGrantAccess;

  /// No description provided for @workspaceExternalLocalOnly.
  ///
  /// In en, this message translates to:
  /// **'Android can mount on-device folders only. This document provider does not expose a local folder to Shell.'**
  String get workspaceExternalLocalOnly;

  /// No description provided for @workspaceExternalUnavailable.
  ///
  /// In en, this message translates to:
  /// **'The external folder is unavailable. Check its storage connection and permissions, then select the folder again to restore access.'**
  String get workspaceExternalUnavailable;

  /// No description provided for @workspaceExternalReconnect.
  ///
  /// In en, this message translates to:
  /// **'Select folder again'**
  String get workspaceExternalReconnect;

  /// No description provided for @workspaceMountAdd.
  ///
  /// In en, this message translates to:
  /// **'Add folder'**
  String get workspaceMountAdd;

  /// No description provided for @workspaceMountEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit mount'**
  String get workspaceMountEdit;

  /// No description provided for @workspaceMountEmpty.
  ///
  /// In en, this message translates to:
  /// **'No mounted folders'**
  String get workspaceMountEmpty;

  /// No description provided for @workspaceMountReadOnly.
  ///
  /// In en, this message translates to:
  /// **'Read-only'**
  String get workspaceMountReadOnly;

  /// No description provided for @workspaceMountReadWrite.
  ///
  /// In en, this message translates to:
  /// **'Read-write'**
  String get workspaceMountReadWrite;

  /// No description provided for @workspaceMountAllowWrite.
  ///
  /// In en, this message translates to:
  /// **'Allow writes'**
  String get workspaceMountAllowWrite;

  /// No description provided for @workspaceMountPermissionsHint.
  ///
  /// In en, this message translates to:
  /// **'AI file tools and the file browser respect this setting. Shell guards cover common file commands; arbitrary scripts may bypass them. Saving mount changes stops running commands and terminal sessions.'**
  String get workspaceMountPermissionsHint;

  /// No description provided for @workspaceMountBrowse.
  ///
  /// In en, this message translates to:
  /// **'Browse files'**
  String get workspaceMountBrowse;

  /// No description provided for @workspaceMountUnmount.
  ///
  /// In en, this message translates to:
  /// **'Unmount'**
  String get workspaceMountUnmount;

  /// No description provided for @workspaceMountUnmountMessage.
  ///
  /// In en, this message translates to:
  /// **'Remove this mount? The original folder and its files will be kept.'**
  String get workspaceMountUnmountMessage;

  /// No description provided for @workspaceMountInactive.
  ///
  /// In en, this message translates to:
  /// **'Unavailable — select the folder again'**
  String get workspaceMountInactive;

  /// No description provided for @workspaceMountInvalidName.
  ///
  /// In en, this message translates to:
  /// **'Use a name of up to 64 characters without slashes, colons or control characters. Do not use . or ..'**
  String get workspaceMountInvalidName;

  /// No description provided for @workspaceMountDuplicate.
  ///
  /// In en, this message translates to:
  /// **'A mount with this name already exists.'**
  String get workspaceMountDuplicate;

  /// No description provided for @workspaceMountLimit.
  ///
  /// In en, this message translates to:
  /// **'Up to 10 folders can be mounted. Remove a mount before adding another.'**
  String get workspaceMountLimit;

  /// No description provided for @workspaceMountOverlap.
  ///
  /// In en, this message translates to:
  /// **'This folder overlaps an existing mount. Choose a different folder so permissions remain unambiguous.'**
  String get workspaceMountOverlap;

  /// No description provided for @workspaceMountTargetOccupied.
  ///
  /// In en, this message translates to:
  /// **'A mount target under /mounts already contains local files. Choose a different mount name or move those files first. No files were removed.'**
  String get workspaceMountTargetOccupied;

  /// No description provided for @workspaceEnvSystemImage.
  ///
  /// In en, this message translates to:
  /// **'System image'**
  String get workspaceEnvSystemImage;

  /// No description provided for @workspaceEnvDistribution.
  ///
  /// In en, this message translates to:
  /// **'Distribution'**
  String get workspaceEnvDistribution;

  /// No description provided for @workspaceEnvSystemVersion.
  ///
  /// In en, this message translates to:
  /// **'Version'**
  String get workspaceEnvSystemVersion;

  /// No description provided for @workspaceEnvLocalImage.
  ///
  /// In en, this message translates to:
  /// **'Local image'**
  String get workspaceEnvLocalImage;

  /// No description provided for @workspaceEnvChooseImage.
  ///
  /// In en, this message translates to:
  /// **'Choose rootfs archive'**
  String get workspaceEnvChooseImage;

  /// No description provided for @workspaceEnvLocalImageHint.
  ///
  /// In en, this message translates to:
  /// **'Import a root filesystem archive (.tar.gz, .tar.xz, or .tar), not an ISO or a disk image. It must match this device’s CPU architecture and contain /bin/sh. The system and version are detected after extraction.'**
  String get workspaceEnvLocalImageHint;

  /// No description provided for @workspaceEnvImportImage.
  ///
  /// In en, this message translates to:
  /// **'Import image'**
  String get workspaceEnvImportImage;

  /// No description provided for @workspaceEnvInvalidImage.
  ///
  /// In en, this message translates to:
  /// **'Select a valid rootfs archive for this device. It must contain an executable /bin/sh with the matching CPU architecture.'**
  String get workspaceEnvInvalidImage;

  /// No description provided for @workspaceEnvReplaceSystem.
  ///
  /// In en, this message translates to:
  /// **'Replace system'**
  String get workspaceEnvReplaceSystem;

  /// No description provided for @workspaceEnvReplaceSystemHint.
  ///
  /// In en, this message translates to:
  /// **'This replaces installed packages and files inside the current environment and stops its commands and terminal sessions. Workspaces, chat files, and external folders are kept. If preparing the new image fails, the current environment is preserved.'**
  String get workspaceEnvReplaceSystemHint;

  /// No description provided for @workspaceEnvProotOptions.
  ///
  /// In en, this message translates to:
  /// **'PRoot options'**
  String get workspaceEnvProotOptions;

  /// No description provided for @workspaceEnvShellPath.
  ///
  /// In en, this message translates to:
  /// **'Shell path'**
  String get workspaceEnvShellPath;

  /// No description provided for @workspaceEnvShellAutomatic.
  ///
  /// In en, this message translates to:
  /// **'Automatic'**
  String get workspaceEnvShellAutomatic;

  /// No description provided for @workspaceEnvShellHint.
  ///
  /// In en, this message translates to:
  /// **'Leave empty to use /bin/bash when available, otherwise /bin/sh. A custom shell must use an absolute path inside the environment.'**
  String get workspaceEnvShellHint;

  /// No description provided for @workspaceEnvProotArguments.
  ///
  /// In en, this message translates to:
  /// **'Extra PRoot arguments'**
  String get workspaceEnvProotArguments;

  /// No description provided for @workspaceEnvProotArgumentsHint.
  ///
  /// In en, this message translates to:
  /// **'One argument per line, without shell quotes. For example, put -k and 5.10.0 on separate lines, or use --kernel-release=5.10.0. Changes apply to new commands and terminal sessions.'**
  String get workspaceEnvProotArgumentsHint;

  /// No description provided for @workspaceEnvProotInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid absolute shell path and one PRoot argument per line.'**
  String get workspaceEnvProotInvalid;

  /// No description provided for @workspaceFileMissing.
  ///
  /// In en, this message translates to:
  /// **'File no longer exists'**
  String get workspaceFileMissing;

  /// No description provided for @workspaceFilePreviewUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Preview unavailable'**
  String get workspaceFilePreviewUnavailable;

  /// No description provided for @workspaceToolRelatedFiles.
  ///
  /// In en, this message translates to:
  /// **'Related files'**
  String get workspaceToolRelatedFiles;

  /// No description provided for @workspaceToolFilesTruncated.
  ///
  /// In en, this message translates to:
  /// **'Only some files are listed.'**
  String get workspaceToolFilesTruncated;

  /// No description provided for @displaySettingsPageShowProducedFilesTitle.
  ///
  /// In en, this message translates to:
  /// **'Show Files Below Replies'**
  String get displaySettingsPageShowProducedFilesTitle;

  /// No description provided for @displaySettingsPageShowProducedFilesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Show files created or modified by tools below replies.'**
  String get displaySettingsPageShowProducedFilesSubtitle;

  /// No description provided for @defaultModelPagePerChatModelTitle.
  ///
  /// In en, this message translates to:
  /// **'Per-Chat Model'**
  String get defaultModelPagePerChatModelTitle;

  /// No description provided for @defaultModelPagePerChatModelSubtitle.
  ///
  /// In en, this message translates to:
  /// **'On: picking a model in a chat applies to that chat only. Off: it becomes the current assistant\'s model, so every chat using that assistant follows it.'**
  String get defaultModelPagePerChatModelSubtitle;

  /// No description provided for @googleFontsTitle.
  ///
  /// In en, this message translates to:
  /// **'Google Fonts'**
  String get googleFontsTitle;

  /// No description provided for @googleFontsRefresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh font list'**
  String get googleFontsRefresh;

  /// No description provided for @googleFontsSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search fonts or languages'**
  String get googleFontsSearchHint;

  /// No description provided for @googleFontsHint.
  ///
  /// In en, this message translates to:
  /// **'Download a regular font to preview and apply it. Installed fonts work offline. Catalog: Expo Google Fonts; downloads: Google Fonts.'**
  String get googleFontsHint;

  /// No description provided for @googleFontsNoResults.
  ///
  /// In en, this message translates to:
  /// **'No matching fonts'**
  String get googleFontsNoResults;

  /// No description provided for @googleFontsFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not load, download, or apply the font. Check your connection and try again.'**
  String get googleFontsFailed;

  /// No description provided for @googleFontsDownloading.
  ///
  /// In en, this message translates to:
  /// **'Downloading font…'**
  String get googleFontsDownloading;

  /// No description provided for @googleFontsPreview.
  ///
  /// In en, this message translates to:
  /// **'The quick brown fox 0123456789 · 字体预览'**
  String get googleFontsPreview;

  /// No description provided for @googleFontsLicense.
  ///
  /// In en, this message translates to:
  /// **'Font license'**
  String get googleFontsLicense;

  /// No description provided for @assistantEditLocationPermissionSettingsMessage.
  ///
  /// In en, this message translates to:
  /// **'Location permission is blocked. Allow location access in system settings, then turn this tool on again.'**
  String get assistantEditLocationPermissionSettingsMessage;

  /// No description provided for @healthDataSettingsCategoryReproductive.
  ///
  /// In en, this message translates to:
  /// **'Reproductive health'**
  String get healthDataSettingsCategoryReproductive;

  /// No description provided for @healthDataSettingsTypeMenstrualFlowTitle.
  ///
  /// In en, this message translates to:
  /// **'Menstrual flow'**
  String get healthDataSettingsTypeMenstrualFlowTitle;

  /// No description provided for @healthDataSettingsTypeMenstrualFlowSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Recorded menstrual flow and cycle starts in the past 90 days'**
  String get healthDataSettingsTypeMenstrualFlowSubtitle;

  /// No description provided for @assistantEditGradientBackgroundTitle.
  ///
  /// In en, this message translates to:
  /// **'Gradient background'**
  String get assistantEditGradientBackgroundTitle;

  /// No description provided for @assistantEditGradientStaticTitle.
  ///
  /// In en, this message translates to:
  /// **'Static mode'**
  String get assistantEditGradientStaticTitle;

  /// No description provided for @assistantEditGradientStaticDescription.
  ///
  /// In en, this message translates to:
  /// **'Saves power during long chats and streaming.'**
  String get assistantEditGradientStaticDescription;

  /// No description provided for @assistantEditGradientHorizontal.
  ///
  /// In en, this message translates to:
  /// **'Horizontal position'**
  String get assistantEditGradientHorizontal;

  /// No description provided for @assistantEditGradientVertical.
  ///
  /// In en, this message translates to:
  /// **'Vertical position'**
  String get assistantEditGradientVertical;

  /// No description provided for @assistantEditGradientPreview.
  ///
  /// In en, this message translates to:
  /// **'Preview'**
  String get assistantEditGradientPreview;

  /// No description provided for @assistantEditGradientNextFrame.
  ///
  /// In en, this message translates to:
  /// **'Another frame'**
  String get assistantEditGradientNextFrame;

  /// No description provided for @backgroundSettingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Background tasks'**
  String get backgroundSettingsTitle;

  /// No description provided for @backgroundTaskTitle.
  ///
  /// In en, this message translates to:
  /// **'Kelivo task'**
  String get backgroundTaskTitle;

  /// No description provided for @backgroundCompleted.
  ///
  /// In en, this message translates to:
  /// **'Generation complete'**
  String get backgroundCompleted;

  /// No description provided for @backgroundFailed.
  ///
  /// In en, this message translates to:
  /// **'Generation failed. Open the chat for details.'**
  String get backgroundFailed;

  /// No description provided for @backgroundCancelled.
  ///
  /// In en, this message translates to:
  /// **'Generation cancelled'**
  String get backgroundCancelled;

  /// No description provided for @backgroundInterrupted.
  ///
  /// In en, this message translates to:
  /// **'Background generation was interrupted. Open the chat to continue.'**
  String get backgroundInterrupted;

  /// No description provided for @backgroundRequesting.
  ///
  /// In en, this message translates to:
  /// **'Connecting'**
  String get backgroundRequesting;

  /// No description provided for @backgroundGenerating.
  ///
  /// In en, this message translates to:
  /// **'Generating reply'**
  String get backgroundGenerating;

  /// No description provided for @backgroundThinking.
  ///
  /// In en, this message translates to:
  /// **'Thinking'**
  String get backgroundThinking;

  /// No description provided for @backgroundToolRunning.
  ///
  /// In en, this message translates to:
  /// **'Running tool'**
  String get backgroundToolRunning;

  /// No description provided for @backgroundRetrying.
  ///
  /// In en, this message translates to:
  /// **'Waiting to retry'**
  String get backgroundRetrying;

  /// No description provided for @backgroundWorking.
  ///
  /// In en, this message translates to:
  /// **'Working'**
  String get backgroundWorking;

  /// No description provided for @backgroundTasks.
  ///
  /// In en, this message translates to:
  /// **'Tasks'**
  String get backgroundTasks;

  /// No description provided for @backgroundStopTasks.
  ///
  /// In en, this message translates to:
  /// **'Stop tasks'**
  String get backgroundStopTasks;

  /// No description provided for @backgroundOpenChat.
  ///
  /// In en, this message translates to:
  /// **'Open chat'**
  String get backgroundOpenChat;

  /// No description provided for @backgroundAndroidEnabled.
  ///
  /// In en, this message translates to:
  /// **'Background generation'**
  String get backgroundAndroidEnabled;

  /// No description provided for @backgroundAndroidEnabledDetail.
  ///
  /// In en, this message translates to:
  /// **'Keep current tasks running when locked, in the background, or removed from recent apps. A system notification is required while tasks run.'**
  String get backgroundAndroidEnabledDetail;

  /// No description provided for @backgroundIosEnabled.
  ///
  /// In en, this message translates to:
  /// **'Enhanced background execution'**
  String get backgroundIosEnabled;

  /// No description provided for @backgroundIosEnabledDetail.
  ///
  /// In en, this message translates to:
  /// **'Request time to finish current tasks. Enable location or silent audio separately for additional background support.'**
  String get backgroundIosEnabledDetail;

  /// No description provided for @backgroundNotifications.
  ///
  /// In en, this message translates to:
  /// **'Task notifications'**
  String get backgroundNotifications;

  /// No description provided for @backgroundNotificationsDetail.
  ///
  /// In en, this message translates to:
  /// **'Notify when a task completes or fails outside the chat you are viewing. Does not control Android’s required ongoing notification.'**
  String get backgroundNotificationsDetail;

  /// No description provided for @backgroundPrivacy.
  ///
  /// In en, this message translates to:
  /// **'Task status privacy'**
  String get backgroundPrivacy;

  /// No description provided for @backgroundPrivacyDetail.
  ///
  /// In en, this message translates to:
  /// **'Hide conversation titles and tool details in notifications and live status. Only generic status, task count and elapsed time are shown.'**
  String get backgroundPrivacyDetail;

  /// No description provided for @backgroundLiveActivities.
  ///
  /// In en, this message translates to:
  /// **'Live Activities'**
  String get backgroundLiveActivities;

  /// No description provided for @backgroundLiveActivitiesDetail.
  ///
  /// In en, this message translates to:
  /// **'Show current tasks on the Lock Screen and Dynamic Island. Availability and visibility depend on the system.'**
  String get backgroundLiveActivitiesDetail;

  /// No description provided for @backgroundOverlay.
  ///
  /// In en, this message translates to:
  /// **'Floating task status'**
  String get backgroundOverlay;

  /// No description provided for @backgroundOverlayDetail.
  ///
  /// In en, this message translates to:
  /// **'Show a draggable task capsule over other apps. Tap it to open the chat; closing it only hides the capsule.'**
  String get backgroundOverlayDetail;

  /// No description provided for @backgroundLiveUpdates.
  ///
  /// In en, this message translates to:
  /// **'Live Updates'**
  String get backgroundLiveUpdates;

  /// No description provided for @backgroundLiveUpdatesDetail.
  ///
  /// In en, this message translates to:
  /// **'Use Android 16 Live Updates on supported devices. A promoted notification takes priority over the floating capsule.'**
  String get backgroundLiveUpdatesDetail;

  /// No description provided for @backgroundLocation.
  ///
  /// In en, this message translates to:
  /// **'Location-assisted execution'**
  String get backgroundLocation;

  /// No description provided for @backgroundLocationDetail.
  ///
  /// In en, this message translates to:
  /// **'Use coarse location updates during background tasks. Coordinates are not stored or sent to AI services. Requires enhanced background execution and location permission.'**
  String get backgroundLocationDetail;

  /// No description provided for @backgroundSilentAudio.
  ///
  /// In en, this message translates to:
  /// **'Silent audio keep-alive'**
  String get backgroundSilentAudio;

  /// No description provided for @backgroundSilentAudioDetail.
  ///
  /// In en, this message translates to:
  /// **'Play silent audio while background tasks run. Yields to recording and speech playback. Requires enhanced background execution; no microphone permission is needed.'**
  String get backgroundSilentAudioDetail;

  /// No description provided for @backgroundSpeech.
  ///
  /// In en, this message translates to:
  /// **'Background read-aloud'**
  String get backgroundSpeech;

  /// No description provided for @backgroundSpeechDetail.
  ///
  /// In en, this message translates to:
  /// **'Continue system and network read-aloud when locked or in the background. When disabled, moving to the background pauses speech.'**
  String get backgroundSpeechDetail;

  /// No description provided for @backgroundFinishVisibility.
  ///
  /// In en, this message translates to:
  /// **'Completed status duration'**
  String get backgroundFinishVisibility;

  /// No description provided for @backgroundFinishImmediately.
  ///
  /// In en, this message translates to:
  /// **'Immediately dismiss'**
  String get backgroundFinishImmediately;

  /// No description provided for @backgroundFinishOneMinute.
  ///
  /// In en, this message translates to:
  /// **'1 minute'**
  String get backgroundFinishOneMinute;

  /// No description provided for @backgroundFinishFiveMinutes.
  ///
  /// In en, this message translates to:
  /// **'5 minutes'**
  String get backgroundFinishFiveMinutes;

  /// No description provided for @backgroundFinishUntilForeground.
  ///
  /// In en, this message translates to:
  /// **'Until returning to the app'**
  String get backgroundFinishUntilForeground;

  /// No description provided for @backgroundFinishVisibilityDetail.
  ///
  /// In en, this message translates to:
  /// **'Applies to the Android capsule and iOS Lock Screen completion card. Returning to the app clears completed status; the maximum is 15 minutes. Cancellation dismisses immediately.'**
  String get backgroundFinishVisibilityDetail;

  /// No description provided for @backgroundOverlayIcon.
  ///
  /// In en, this message translates to:
  /// **'Floating icon'**
  String get backgroundOverlayIcon;

  /// No description provided for @backgroundIconDefault.
  ///
  /// In en, this message translates to:
  /// **'Kelivo icon'**
  String get backgroundIconDefault;

  /// No description provided for @backgroundIconImage.
  ///
  /// In en, this message translates to:
  /// **'Choose image'**
  String get backgroundIconImage;

  /// No description provided for @backgroundIconEmoji.
  ///
  /// In en, this message translates to:
  /// **'Choose Emoji'**
  String get backgroundIconEmoji;

  /// No description provided for @backgroundPermissionsTitle.
  ///
  /// In en, this message translates to:
  /// **'Permissions and system settings'**
  String get backgroundPermissionsTitle;

  /// No description provided for @backgroundNotificationsPermission.
  ///
  /// In en, this message translates to:
  /// **'Notification permission'**
  String get backgroundNotificationsPermission;

  /// No description provided for @backgroundBatteryOptimization.
  ///
  /// In en, this message translates to:
  /// **'Battery optimization'**
  String get backgroundBatteryOptimization;

  /// No description provided for @backgroundBatteryOptimizationDetail.
  ///
  /// In en, this message translates to:
  /// **'Allow unrestricted battery usage for more reliable background work.'**
  String get backgroundBatteryOptimizationDetail;

  /// No description provided for @backgroundAutostart.
  ///
  /// In en, this message translates to:
  /// **'Autostart and background usage'**
  String get backgroundAutostart;

  /// No description provided for @backgroundAutostartDetail.
  ///
  /// In en, this message translates to:
  /// **'Check your device’s autostart and background restrictions manually. Android does not provide a reliable permission query for these vendor settings.'**
  String get backgroundAutostartDetail;

  /// No description provided for @backgroundLocationPermission.
  ///
  /// In en, this message translates to:
  /// **'Location permission'**
  String get backgroundLocationPermission;

  /// No description provided for @backgroundLocationAlways.
  ///
  /// In en, this message translates to:
  /// **'Allow location in the background'**
  String get backgroundLocationAlways;

  /// No description provided for @backgroundLocationAlwaysDetail.
  ///
  /// In en, this message translates to:
  /// **'You can grant Always access for background location. Permission is requested only when you choose this action.'**
  String get backgroundLocationAlwaysDetail;

  /// No description provided for @backgroundSystemSettings.
  ///
  /// In en, this message translates to:
  /// **'App system settings'**
  String get backgroundSystemSettings;

  /// No description provided for @backgroundPermissionGranted.
  ///
  /// In en, this message translates to:
  /// **'Allowed'**
  String get backgroundPermissionGranted;

  /// No description provided for @backgroundPermissionDenied.
  ///
  /// In en, this message translates to:
  /// **'Not allowed'**
  String get backgroundPermissionDenied;

  /// No description provided for @backgroundPermissionLimited.
  ///
  /// In en, this message translates to:
  /// **'While using the app'**
  String get backgroundPermissionLimited;

  /// No description provided for @backgroundPermissionUnknown.
  ///
  /// In en, this message translates to:
  /// **'Check manually'**
  String get backgroundPermissionUnknown;

  /// No description provided for @backgroundPermissionNotDetermined.
  ///
  /// In en, this message translates to:
  /// **'Not requested'**
  String get backgroundPermissionNotDetermined;

  /// No description provided for @backgroundRuntimeTitle.
  ///
  /// In en, this message translates to:
  /// **'Current status'**
  String get backgroundRuntimeTitle;

  /// No description provided for @backgroundRuntimeActive.
  ///
  /// In en, this message translates to:
  /// **'Running'**
  String get backgroundRuntimeActive;

  /// No description provided for @backgroundRuntimeIdle.
  ///
  /// In en, this message translates to:
  /// **'Inactive'**
  String get backgroundRuntimeIdle;

  /// No description provided for @backgroundLocationActive.
  ///
  /// In en, this message translates to:
  /// **'Background location'**
  String get backgroundLocationActive;

  /// No description provided for @backgroundAudioActive.
  ///
  /// In en, this message translates to:
  /// **'Silent audio'**
  String get backgroundAudioActive;

  /// No description provided for @backgroundActivityActive.
  ///
  /// In en, this message translates to:
  /// **'Live Activity'**
  String get backgroundActivityActive;

  /// No description provided for @backgroundOverlayActive.
  ///
  /// In en, this message translates to:
  /// **'Floating window'**
  String get backgroundOverlayActive;

  /// No description provided for @backgroundLastError.
  ///
  /// In en, this message translates to:
  /// **'Last interruption or error'**
  String get backgroundLastError;

  /// No description provided for @backgroundNoError.
  ///
  /// In en, this message translates to:
  /// **'None recorded'**
  String get backgroundNoError;

  /// No description provided for @backgroundUnsupported.
  ///
  /// In en, this message translates to:
  /// **'Unavailable on this device or disabled in system settings'**
  String get backgroundUnsupported;

  /// No description provided for @backgroundIosLimit.
  ///
  /// In en, this message translates to:
  /// **'iOS controls background execution. Live Activities alone do not keep the app running. Force-quitting can stop generation and delay removal of live status until the app opens again.'**
  String get backgroundIosLimit;

  /// No description provided for @backgroundAndroidLimit.
  ///
  /// In en, this message translates to:
  /// **'Check notification, battery and vendor background settings if tasks stop. Force stop and system process termination can still interrupt generation.'**
  String get backgroundAndroidLimit;

  /// No description provided for @backgroundStale.
  ///
  /// In en, this message translates to:
  /// **'Status has not updated. Open the app to check.'**
  String get backgroundStale;

  /// No description provided for @backgroundIconError.
  ///
  /// In en, this message translates to:
  /// **'Unable to import this image. Please choose another image.'**
  String get backgroundIconError;

  /// No description provided for @backgroundNotificationChannels.
  ///
  /// In en, this message translates to:
  /// **'Notification channels'**
  String get backgroundNotificationChannels;

  /// No description provided for @backgroundCompletionChannel.
  ///
  /// In en, this message translates to:
  /// **'Completion notification channel'**
  String get backgroundCompletionChannel;

  /// No description provided for @backgroundOngoingChannel.
  ///
  /// In en, this message translates to:
  /// **'Running task notification channel'**
  String get backgroundOngoingChannel;

  /// No description provided for @backgroundOverlayAppearance.
  ///
  /// In en, this message translates to:
  /// **'Floating window appearance'**
  String get backgroundOverlayAppearance;

  /// No description provided for @backgroundOverlayAppearanceDetail.
  ///
  /// In en, this message translates to:
  /// **'Size, artwork, progress ring and visible content'**
  String get backgroundOverlayAppearanceDetail;

  /// No description provided for @backgroundOverlayPreviewHint.
  ///
  /// In en, this message translates to:
  /// **'Drag to move · Tap to open chat · Hold to dismiss'**
  String get backgroundOverlayPreviewHint;

  /// No description provided for @backgroundOverlayCard.
  ///
  /// In en, this message translates to:
  /// **'Card'**
  String get backgroundOverlayCard;

  /// No description provided for @backgroundOverlayCircle.
  ///
  /// In en, this message translates to:
  /// **'Circular icon'**
  String get backgroundOverlayCircle;

  /// No description provided for @backgroundOverlaySize.
  ///
  /// In en, this message translates to:
  /// **'Size and shape'**
  String get backgroundOverlaySize;

  /// No description provided for @backgroundOverlayWidth.
  ///
  /// In en, this message translates to:
  /// **'Width'**
  String get backgroundOverlayWidth;

  /// No description provided for @backgroundOverlayHeight.
  ///
  /// In en, this message translates to:
  /// **'Height'**
  String get backgroundOverlayHeight;

  /// No description provided for @backgroundOverlayCornerRadius.
  ///
  /// In en, this message translates to:
  /// **'Corner radius'**
  String get backgroundOverlayCornerRadius;

  /// No description provided for @backgroundOverlayIconSize.
  ///
  /// In en, this message translates to:
  /// **'Icon size'**
  String get backgroundOverlayIconSize;

  /// No description provided for @backgroundOverlayProgressSize.
  ///
  /// In en, this message translates to:
  /// **'Progress ring diameter'**
  String get backgroundOverlayProgressSize;

  /// No description provided for @backgroundOverlayProgressStroke.
  ///
  /// In en, this message translates to:
  /// **'Progress ring thickness'**
  String get backgroundOverlayProgressStroke;

  /// No description provided for @backgroundOverlayContent.
  ///
  /// In en, this message translates to:
  /// **'Visible content'**
  String get backgroundOverlayContent;

  /// No description provided for @backgroundOverlayShowProgress.
  ///
  /// In en, this message translates to:
  /// **'Show progress ring'**
  String get backgroundOverlayShowProgress;

  /// No description provided for @backgroundOverlayShowTitle.
  ///
  /// In en, this message translates to:
  /// **'Show title'**
  String get backgroundOverlayShowTitle;

  /// No description provided for @backgroundOverlayShowSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Show subtitle'**
  String get backgroundOverlayShowSubtitle;

  /// No description provided for @backgroundOverlayShowTime.
  ///
  /// In en, this message translates to:
  /// **'Show elapsed time'**
  String get backgroundOverlayShowTime;

  /// No description provided for @backgroundOverlayShowClose.
  ///
  /// In en, this message translates to:
  /// **'Show close button'**
  String get backgroundOverlayShowClose;

  /// No description provided for @backgroundOverlayShowBackground.
  ///
  /// In en, this message translates to:
  /// **'Show background'**
  String get backgroundOverlayShowBackground;

  /// No description provided for @backgroundOverlayShowBorder.
  ///
  /// In en, this message translates to:
  /// **'Show border'**
  String get backgroundOverlayShowBorder;

  /// No description provided for @backgroundOverlayReset.
  ///
  /// In en, this message translates to:
  /// **'Restore default appearance'**
  String get backgroundOverlayReset;

  /// No description provided for @mcpStdioEnvironmentRequired.
  ///
  /// In en, this message translates to:
  /// **'Install the workspace environment to use STDIO on mobile.'**
  String get mcpStdioEnvironmentRequired;

  /// No description provided for @mcpArgumentsHint.
  ///
  /// In en, this message translates to:
  /// **'Separate arguments with spaces; quote values containing spaces. Use \'\' for an empty argument.'**
  String get mcpArgumentsHint;

  /// No description provided for @mcpArgumentsInvalid.
  ///
  /// In en, this message translates to:
  /// **'Check for an unclosed quote or trailing escape in arguments.'**
  String get mcpArgumentsInvalid;

  /// No description provided for @mcpImportEnvironment.
  ///
  /// In en, this message translates to:
  /// **'Import from Environment'**
  String get mcpImportEnvironment;

  /// No description provided for @mcpEnvironmentEmpty.
  ///
  /// In en, this message translates to:
  /// **'No environment variables. Add them in Environment settings.'**
  String get mcpEnvironmentEmpty;

  /// No description provided for @mcpEnvironmentHint.
  ///
  /// In en, this message translates to:
  /// **'Inherits environment variables. Import a variable to customize its value for this server.'**
  String get mcpEnvironmentHint;

  /// No description provided for @mcpImportJson.
  ///
  /// In en, this message translates to:
  /// **'Import JSON'**
  String get mcpImportJson;

  /// No description provided for @mcpImportJsonHint.
  ///
  /// In en, this message translates to:
  /// **'Paste a Claude Desktop or Cursor MCP configuration. Preview and add servers without replacing existing ones.'**
  String get mcpImportJsonHint;

  /// No description provided for @mcpImportPaste.
  ///
  /// In en, this message translates to:
  /// **'Paste from Clipboard'**
  String get mcpImportPaste;

  /// No description provided for @mcpImportPreview.
  ///
  /// In en, this message translates to:
  /// **'Preview'**
  String get mcpImportPreview;

  /// No description provided for @mcpImportConfirm.
  ///
  /// In en, this message translates to:
  /// **'Import'**
  String get mcpImportConfirm;

  /// No description provided for @startupRecoverySnapshotTitle.
  ///
  /// In en, this message translates to:
  /// **'Restore from a database snapshot'**
  String get startupRecoverySnapshotTitle;

  /// No description provided for @startupRecoverySnapshotBody.
  ///
  /// In en, this message translates to:
  /// **'Choose a snapshot on this device to recover your chats and settings, even when the database cannot open. Do not uninstall Kelivo: uninstalling also removes these snapshots.'**
  String get startupRecoverySnapshotBody;

  /// No description provided for @startupRecoverySnapshotEmpty.
  ///
  /// In en, this message translates to:
  /// **'No database snapshots were found on this device. Export your data before trying other recovery actions.'**
  String get startupRecoverySnapshotEmpty;

  /// No description provided for @startupRecoverySnapshotButton.
  ///
  /// In en, this message translates to:
  /// **'Choose a snapshot'**
  String get startupRecoverySnapshotButton;

  /// No description provided for @startupRecoverySnapshotConfirm.
  ///
  /// In en, this message translates to:
  /// **'Restore chats and settings from {when}? Changes made after this snapshot will not be included. Existing attachment files and the snapshot will be kept. Kelivo will restart to complete the restore.'**
  String startupRecoverySnapshotConfirm(String when);

  /// No description provided for @startupRecoverySnapshotFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not prepare the snapshot restore: {reason}'**
  String startupRecoverySnapshotFailed(String reason);

  /// No description provided for @startupRecoverySnapshotReady.
  ///
  /// In en, this message translates to:
  /// **'The snapshot is ready. Restart Kelivo to complete the restore.'**
  String get startupRecoverySnapshotReady;

  /// No description provided for @scheduledTasksTitle.
  ///
  /// In en, this message translates to:
  /// **'Scheduled tasks'**
  String get scheduledTasksTitle;

  /// No description provided for @scheduledTasksDescription.
  ///
  /// In en, this message translates to:
  /// **'Run tasks automatically at your chosen time: start a new chat, follow up, or run a question again.'**
  String get scheduledTasksDescription;

  /// No description provided for @scheduledTasksEmpty.
  ///
  /// In en, this message translates to:
  /// **'Your day, on a schedule'**
  String get scheduledTasksEmpty;

  /// No description provided for @scheduledTasksEmptyDetail.
  ///
  /// In en, this message translates to:
  /// **'Add a task for a morning briefing, a daily review, or anything you want to run regularly.'**
  String get scheduledTasksEmptyDetail;

  /// No description provided for @scheduledTasksAdd.
  ///
  /// In en, this message translates to:
  /// **'Add task'**
  String get scheduledTasksAdd;

  /// No description provided for @scheduledTasksEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit task'**
  String get scheduledTasksEdit;

  /// No description provided for @scheduledTasksName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get scheduledTasksName;

  /// No description provided for @scheduledTasksNameHint.
  ///
  /// In en, this message translates to:
  /// **'Morning briefing'**
  String get scheduledTasksNameHint;

  /// No description provided for @scheduledTasksPrompt.
  ///
  /// In en, this message translates to:
  /// **'Prompt'**
  String get scheduledTasksPrompt;

  /// No description provided for @scheduledTasksPromptHint.
  ///
  /// In en, this message translates to:
  /// **'What would you like your assistant to do?'**
  String get scheduledTasksPromptHint;

  /// No description provided for @scheduledTasksAssistant.
  ///
  /// In en, this message translates to:
  /// **'Assistant'**
  String get scheduledTasksAssistant;

  /// No description provided for @scheduledTasksChooseAssistant.
  ///
  /// In en, this message translates to:
  /// **'Choose an assistant'**
  String get scheduledTasksChooseAssistant;

  /// No description provided for @scheduledTasksAssistantMissing.
  ///
  /// In en, this message translates to:
  /// **'Assistant unavailable'**
  String get scheduledTasksAssistantMissing;

  /// No description provided for @scheduledTasksTime.
  ///
  /// In en, this message translates to:
  /// **'Time'**
  String get scheduledTasksTime;

  /// No description provided for @scheduledTasksTimeHint.
  ///
  /// In en, this message translates to:
  /// **'24-hour time, e.g. 08:00'**
  String get scheduledTasksTimeHint;

  /// No description provided for @scheduledTasksRepeat.
  ///
  /// In en, this message translates to:
  /// **'Repeat'**
  String get scheduledTasksRepeat;

  /// No description provided for @scheduledTasksEveryDay.
  ///
  /// In en, this message translates to:
  /// **'Every day'**
  String get scheduledTasksEveryDay;

  /// No description provided for @scheduledTasksWeekdays.
  ///
  /// In en, this message translates to:
  /// **'Weekdays'**
  String get scheduledTasksWeekdays;

  /// No description provided for @scheduledTasksEnabled.
  ///
  /// In en, this message translates to:
  /// **'Enabled'**
  String get scheduledTasksEnabled;

  /// No description provided for @scheduledTasksPermission.
  ///
  /// In en, this message translates to:
  /// **'Alarms & reminders'**
  String get scheduledTasksPermission;

  /// No description provided for @scheduledTasksPermissionDetail.
  ///
  /// In en, this message translates to:
  /// **'Allow exact alarms to run tasks at your chosen time. Enabled tasks will wait until permission is granted.'**
  String get scheduledTasksPermissionDetail;

  /// No description provided for @scheduledTasksPermissionAction.
  ///
  /// In en, this message translates to:
  /// **'Allow'**
  String get scheduledTasksPermissionAction;

  /// No description provided for @scheduledTasksReliability.
  ///
  /// In en, this message translates to:
  /// **'Keep Kelivo unrestricted in battery settings for more reliable execution. Force stopping the app cancels alarms until you reopen it. Missed runs are skipped; tasks follow the device time zone.'**
  String get scheduledTasksReliability;

  /// No description provided for @scheduledTasksExecutionDetail.
  ///
  /// In en, this message translates to:
  /// **'Results are saved in chats. A completion notification previews the reply and opens the conversation when tapped. Runs stop after 10 minutes or when user input or tool approval is needed.'**
  String get scheduledTasksExecutionDetail;

  /// No description provided for @scheduledTasksRunNow.
  ///
  /// In en, this message translates to:
  /// **'Run now'**
  String get scheduledTasksRunNow;

  /// No description provided for @scheduledTasksHistory.
  ///
  /// In en, this message translates to:
  /// **'Run history'**
  String get scheduledTasksHistory;

  /// No description provided for @scheduledTasksNoRuns.
  ///
  /// In en, this message translates to:
  /// **'No runs yet'**
  String get scheduledTasksNoRuns;

  /// No description provided for @scheduledTasksRunning.
  ///
  /// In en, this message translates to:
  /// **'Running'**
  String get scheduledTasksRunning;

  /// No description provided for @scheduledTasksCompleted.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get scheduledTasksCompleted;

  /// No description provided for @scheduledTasksFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed'**
  String get scheduledTasksFailed;

  /// No description provided for @scheduledTasksInterrupted.
  ///
  /// In en, this message translates to:
  /// **'Interrupted'**
  String get scheduledTasksInterrupted;

  /// No description provided for @scheduledTasksPaused.
  ///
  /// In en, this message translates to:
  /// **'Paused'**
  String get scheduledTasksPaused;

  /// No description provided for @scheduledTasksWaitingPermission.
  ///
  /// In en, this message translates to:
  /// **'Waiting for permission'**
  String get scheduledTasksWaitingPermission;

  /// No description provided for @scheduledTasksNextRun.
  ///
  /// In en, this message translates to:
  /// **'Next: {time}'**
  String scheduledTasksNextRun(String time);

  /// No description provided for @scheduledTasksDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete task'**
  String get scheduledTasksDelete;

  /// No description provided for @scheduledTasksDeleteDetail.
  ///
  /// In en, this message translates to:
  /// **'Delete this schedule and its run history? Conversations already created will be kept.'**
  String get scheduledTasksDeleteDetail;

  /// No description provided for @scheduledTasksSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get scheduledTasksSave;

  /// No description provided for @scheduledTasksCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get scheduledTasksCancel;

  /// No description provided for @scheduledTasksInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter a name, prompt and assistant, and select at least one day for a custom schedule.'**
  String get scheduledTasksInvalid;

  /// No description provided for @scheduledTasksLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading…'**
  String get scheduledTasksLoading;

  /// No description provided for @scheduledTasksOpenChat.
  ///
  /// In en, this message translates to:
  /// **'View conversation'**
  String get scheduledTasksOpenChat;

  /// No description provided for @scheduledTasksNeedsInput.
  ///
  /// In en, this message translates to:
  /// **'Stopped because user input or tool approval was required. Open the conversation to continue.'**
  String get scheduledTasksNeedsInput;

  /// No description provided for @scheduledTasksTimeout.
  ///
  /// In en, this message translates to:
  /// **'The execution time limit was reached.'**
  String get scheduledTasksTimeout;

  /// No description provided for @scheduledTasksProcessTerminated.
  ///
  /// In en, this message translates to:
  /// **'Android stopped the previous run.'**
  String get scheduledTasksProcessTerminated;

  /// No description provided for @scheduledTasksOnce.
  ///
  /// In en, this message translates to:
  /// **'Once'**
  String get scheduledTasksOnce;

  /// No description provided for @scheduledTasksCustom.
  ///
  /// In en, this message translates to:
  /// **'Custom'**
  String get scheduledTasksCustom;

  /// No description provided for @scheduledTasksExecution.
  ///
  /// In en, this message translates to:
  /// **'Task'**
  String get scheduledTasksExecution;

  /// No description provided for @scheduledTasksMode.
  ///
  /// In en, this message translates to:
  /// **'Action'**
  String get scheduledTasksMode;

  /// No description provided for @scheduledTasksNewChat.
  ///
  /// In en, this message translates to:
  /// **'New chat'**
  String get scheduledTasksNewChat;

  /// No description provided for @scheduledTasksFollowUp.
  ///
  /// In en, this message translates to:
  /// **'Follow up'**
  String get scheduledTasksFollowUp;

  /// No description provided for @scheduledTasksRegenerate.
  ///
  /// In en, this message translates to:
  /// **'Run again'**
  String get scheduledTasksRegenerate;

  /// No description provided for @scheduledTasksChat.
  ///
  /// In en, this message translates to:
  /// **'Conversation'**
  String get scheduledTasksChat;

  /// No description provided for @scheduledTasksChooseChat.
  ///
  /// In en, this message translates to:
  /// **'Choose a conversation'**
  String get scheduledTasksChooseChat;

  /// No description provided for @scheduledTasksMessage.
  ///
  /// In en, this message translates to:
  /// **'Question to run again'**
  String get scheduledTasksMessage;

  /// No description provided for @scheduledTasksChooseMessage.
  ///
  /// In en, this message translates to:
  /// **'Choose a question'**
  String get scheduledTasksChooseMessage;

  /// No description provided for @scheduledTasksAttachmentMessage.
  ///
  /// In en, this message translates to:
  /// **'Message with attachments'**
  String get scheduledTasksAttachmentMessage;

  /// No description provided for @scheduledTasksModel.
  ///
  /// In en, this message translates to:
  /// **'Model'**
  String get scheduledTasksModel;

  /// No description provided for @scheduledTasksChooseModel.
  ///
  /// In en, this message translates to:
  /// **'Choose a model'**
  String get scheduledTasksChooseModel;

  /// No description provided for @scheduledTasksModelDefault.
  ///
  /// In en, this message translates to:
  /// **'Use the conversation or assistant model'**
  String get scheduledTasksModelDefault;

  /// No description provided for @scheduledTasksSchedule.
  ///
  /// In en, this message translates to:
  /// **'Schedule'**
  String get scheduledTasksSchedule;

  /// No description provided for @scheduledTasksActiveWindow.
  ///
  /// In en, this message translates to:
  /// **'Active dates'**
  String get scheduledTasksActiveWindow;

  /// No description provided for @scheduledTasksStartDate.
  ///
  /// In en, this message translates to:
  /// **'Start date'**
  String get scheduledTasksStartDate;

  /// No description provided for @scheduledTasksEndDate.
  ///
  /// In en, this message translates to:
  /// **'End date'**
  String get scheduledTasksEndDate;

  /// No description provided for @scheduledTasksActiveWindowDetail.
  ///
  /// In en, this message translates to:
  /// **'Runs only within these dates, including the end date. Leave a date unset for no limit.'**
  String get scheduledTasksActiveWindowDetail;

  /// No description provided for @scheduledTasksDate.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get scheduledTasksDate;

  /// No description provided for @scheduledTasksDateUnrestricted.
  ///
  /// In en, this message translates to:
  /// **'No limit'**
  String get scheduledTasksDateUnrestricted;

  /// No description provided for @scheduledTasksClear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get scheduledTasksClear;

  /// No description provided for @scheduledTasksSearch.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get scheduledTasksSearch;

  /// No description provided for @scheduledTasksNoTargets.
  ///
  /// In en, this message translates to:
  /// **'No matching items for this assistant'**
  String get scheduledTasksNoTargets;

  /// No description provided for @scheduledTasksFutureDate.
  ///
  /// In en, this message translates to:
  /// **'Choose a future execution date and time.'**
  String get scheduledTasksFutureDate;

  /// No description provided for @scheduledTasksDateRangeInvalid.
  ///
  /// In en, this message translates to:
  /// **'The end date must be on or after the start date.'**
  String get scheduledTasksDateRangeInvalid;

  /// No description provided for @scheduledTasksRegenerateDetail.
  ///
  /// In en, this message translates to:
  /// **'Generates another answer to the selected question using its original context. Existing answers and later messages are kept.'**
  String get scheduledTasksRegenerateDetail;

  /// No description provided for @scheduledTasksSaving.
  ///
  /// In en, this message translates to:
  /// **'Saving…'**
  String get scheduledTasksSaving;

  /// No description provided for @scheduledTasksFinished.
  ///
  /// In en, this message translates to:
  /// **'Schedule ended'**
  String get scheduledTasksFinished;

  /// No description provided for @scheduledTasksModelMissing.
  ///
  /// In en, this message translates to:
  /// **'The selected model is unavailable. Edit this task to choose another model.'**
  String get scheduledTasksModelMissing;

  /// No description provided for @scheduledTasksChatMissing.
  ///
  /// In en, this message translates to:
  /// **'The conversation is unavailable or belongs to another assistant.'**
  String get scheduledTasksChatMissing;

  /// No description provided for @scheduledTasksMessageMissing.
  ///
  /// In en, this message translates to:
  /// **'The selected question is no longer available.'**
  String get scheduledTasksMessageMissing;

  /// No description provided for @scheduledTasksChatBusy.
  ///
  /// In en, this message translates to:
  /// **'This conversation is generating a reply. The scheduled run was skipped.'**
  String get scheduledTasksChatBusy;

  /// No description provided for @scheduledTasksDesktopEmpty.
  ///
  /// In en, this message translates to:
  /// **'No scheduled tasks'**
  String get scheduledTasksDesktopEmpty;

  /// No description provided for @scheduledTasksDesktopReliability.
  ///
  /// In en, this message translates to:
  /// **'Tasks run only while Kelivo is running, including when minimized or in the system tray. Missed times are skipped after quitting or computer sleep. Kelivo will not start automatically.'**
  String get scheduledTasksDesktopReliability;

  /// No description provided for @scheduledTasksDesktopExecutionDetail.
  ///
  /// In en, this message translates to:
  /// **'Results are saved in chats. Open them from the task’s run history. Runs stop after 10 minutes or when user input or tool approval is needed.'**
  String get scheduledTasksDesktopExecutionDetail;

  /// No description provided for @worldBookStickyLabel.
  ///
  /// In en, this message translates to:
  /// **'Sticky (messages)'**
  String get worldBookStickyLabel;

  /// No description provided for @worldBookStickyHint.
  ///
  /// In en, this message translates to:
  /// **'Keep this entry active for N messages after triggering. Repeated matches do not extend it. 0 disables this effect.'**
  String get worldBookStickyHint;

  /// No description provided for @worldBookCooldownLabel.
  ///
  /// In en, this message translates to:
  /// **'Cooldown (messages)'**
  String get worldBookCooldownLabel;

  /// No description provided for @worldBookCooldownHint.
  ///
  /// In en, this message translates to:
  /// **'Prevent reactivation for N messages after triggering or after sticky ends. 0 disables this effect.'**
  String get worldBookCooldownHint;

  /// No description provided for @worldBookDelayLabel.
  ///
  /// In en, this message translates to:
  /// **'Delay (messages)'**
  String get worldBookDelayLabel;

  /// No description provided for @worldBookDelayHint.
  ///
  /// In en, this message translates to:
  /// **'Allow activation only after the conversation has at least N messages. Count individual messages, not exchanges. 0 disables this effect.'**
  String get worldBookDelayHint;

  /// No description provided for @worldBookDragToReorder.
  ///
  /// In en, this message translates to:
  /// **'Drag to reorder'**
  String get worldBookDragToReorder;

  /// No description provided for @worldBookEnabledCount.
  ///
  /// In en, this message translates to:
  /// **'{enabled}/{total} enabled'**
  String worldBookEnabledCount(int enabled, int total);

  /// No description provided for @assistantConversationSystemPromptTitle.
  ///
  /// In en, this message translates to:
  /// **'Per-conversation system prompt'**
  String get assistantConversationSystemPromptTitle;

  /// No description provided for @assistantConversationSystemPromptHint.
  ///
  /// In en, this message translates to:
  /// **'Allow each conversation to use its own system prompt.'**
  String get assistantConversationSystemPromptHint;

  /// No description provided for @assistantConversationInjectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Per-conversation instruction injections'**
  String get assistantConversationInjectionTitle;

  /// No description provided for @assistantConversationInjectionHint.
  ///
  /// In en, this message translates to:
  /// **'Choose instruction injections and world books for each conversation. None selected by default.'**
  String get assistantConversationInjectionHint;

  /// No description provided for @conversationSystemPromptTitle.
  ///
  /// In en, this message translates to:
  /// **'Conversation system prompt'**
  String get conversationSystemPromptTitle;

  /// No description provided for @conversationSystemPromptHint.
  ///
  /// In en, this message translates to:
  /// **'Applies only to this conversation. Leave blank to use the assistant’s system prompt.'**
  String get conversationSystemPromptHint;

  /// No description provided for @conversationSystemPromptClear.
  ///
  /// In en, this message translates to:
  /// **'Use assistant prompt'**
  String get conversationSystemPromptClear;

  /// No description provided for @conversationSystemPromptPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Write a system prompt for this conversation…'**
  String get conversationSystemPromptPlaceholder;

  /// No description provided for @conversationPromptScope.
  ///
  /// In en, this message translates to:
  /// **'This conversation'**
  String get conversationPromptScope;

  /// No description provided for @oauthAccountsTab.
  ///
  /// In en, this message translates to:
  /// **'Accounts'**
  String get oauthAccountsTab;

  /// No description provided for @oauthLogin.
  ///
  /// In en, this message translates to:
  /// **'Log in'**
  String get oauthLogin;

  /// No description provided for @oauthLoginTo.
  ///
  /// In en, this message translates to:
  /// **'Log in to {provider}'**
  String oauthLoginTo(String provider);

  /// No description provided for @oauthConnected.
  ///
  /// In en, this message translates to:
  /// **'Connected'**
  String get oauthConnected;

  /// No description provided for @oauthNotConnected.
  ///
  /// In en, this message translates to:
  /// **'Not connected'**
  String get oauthNotConnected;

  /// No description provided for @oauthWaiting.
  ///
  /// In en, this message translates to:
  /// **'Waiting for {provider} authorization'**
  String oauthWaiting(String provider);

  /// No description provided for @oauthCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel authorization'**
  String get oauthCancel;

  /// No description provided for @oauthOpenBrowser.
  ///
  /// In en, this message translates to:
  /// **'Open authorization page'**
  String get oauthOpenBrowser;

  /// No description provided for @oauthCopyCode.
  ///
  /// In en, this message translates to:
  /// **'Copy code'**
  String get oauthCopyCode;

  /// No description provided for @oauthCodeHint.
  ///
  /// In en, this message translates to:
  /// **'Enter this code on the authorization page'**
  String get oauthCodeHint;

  /// No description provided for @oauthDeviceHint.
  ///
  /// In en, this message translates to:
  /// **'Enable device code login in your ChatGPT security settings or workspace permissions first.'**
  String get oauthDeviceHint;

  /// No description provided for @oauthDeviceLogin.
  ///
  /// In en, this message translates to:
  /// **'Use device code'**
  String get oauthDeviceLogin;

  /// No description provided for @oauthDetails.
  ///
  /// In en, this message translates to:
  /// **'View account details'**
  String get oauthDetails;

  /// No description provided for @oauthConnectAnother.
  ///
  /// In en, this message translates to:
  /// **'Connect another account'**
  String get oauthConnectAnother;

  /// No description provided for @oauthRelogin.
  ///
  /// In en, this message translates to:
  /// **'Log in again'**
  String get oauthRelogin;

  /// No description provided for @oauthNeedsLogin.
  ///
  /// In en, this message translates to:
  /// **'Login required'**
  String get oauthNeedsLogin;

  /// No description provided for @oauthExpired.
  ///
  /// In en, this message translates to:
  /// **'{provider} login has expired'**
  String oauthExpired(String provider);

  /// No description provided for @oauthLoginRestored.
  ///
  /// In en, this message translates to:
  /// **'Logged in. Use the message retry button to send again.'**
  String get oauthLoginRestored;

  /// No description provided for @oauthLogout.
  ///
  /// In en, this message translates to:
  /// **'Log out'**
  String get oauthLogout;

  /// No description provided for @oauthLogoutDescription.
  ///
  /// In en, this message translates to:
  /// **'Remove this account’s saved credentials from this device'**
  String get oauthLogoutDescription;

  /// No description provided for @oauthRefreshing.
  ///
  /// In en, this message translates to:
  /// **'Refreshing authorization…'**
  String get oauthRefreshing;

  /// No description provided for @oauthRefreshUsage.
  ///
  /// In en, this message translates to:
  /// **'Refresh usage'**
  String get oauthRefreshUsage;

  /// No description provided for @oauthUsageDetails.
  ///
  /// In en, this message translates to:
  /// **'Usage details'**
  String get oauthUsageDetails;

  /// No description provided for @oauthUsageUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Usage is currently unavailable'**
  String get oauthUsageUnavailable;

  /// No description provided for @oauthLastUpdated.
  ///
  /// In en, this message translates to:
  /// **'Updated {time}'**
  String oauthLastUpdated(String time);

  /// No description provided for @oauthSyncModels.
  ///
  /// In en, this message translates to:
  /// **'Sync'**
  String get oauthSyncModels;

  /// No description provided for @oauthSyncing.
  ///
  /// In en, this message translates to:
  /// **'Syncing models…'**
  String get oauthSyncing;

  /// No description provided for @oauthModelsHint.
  ///
  /// In en, this message translates to:
  /// **'Available models are synced from your account.'**
  String get oauthModelsHint;

  /// No description provided for @oauthNoModels.
  ///
  /// In en, this message translates to:
  /// **'Sync models to start chatting'**
  String get oauthNoModels;

  /// No description provided for @oauthConnection.
  ///
  /// In en, this message translates to:
  /// **'Connection'**
  String get oauthConnection;

  /// No description provided for @oauthConnectionInfo.
  ///
  /// In en, this message translates to:
  /// **'Connection details'**
  String get oauthConnectionInfo;

  /// No description provided for @oauthEndpoint.
  ///
  /// In en, this message translates to:
  /// **'Endpoint'**
  String get oauthEndpoint;

  /// No description provided for @oauthScope.
  ///
  /// In en, this message translates to:
  /// **'Authorization scope'**
  String get oauthScope;

  /// No description provided for @oauthAccountId.
  ///
  /// In en, this message translates to:
  /// **'Account ID'**
  String get oauthAccountId;

  /// No description provided for @oauthTokenExpiry.
  ///
  /// In en, this message translates to:
  /// **'Token expires'**
  String get oauthTokenExpiry;

  /// No description provided for @oauthName.
  ///
  /// In en, this message translates to:
  /// **'Provider name'**
  String get oauthName;

  /// No description provided for @oauthEnabledHint.
  ///
  /// In en, this message translates to:
  /// **'Show these models in the model picker'**
  String get oauthEnabledHint;

  /// No description provided for @oauthNetwork.
  ///
  /// In en, this message translates to:
  /// **'Network proxy'**
  String get oauthNetwork;

  /// No description provided for @oauthFollowGlobal.
  ///
  /// In en, this message translates to:
  /// **'Follow global settings'**
  String get oauthFollowGlobal;

  /// No description provided for @oauthCustomRequest.
  ///
  /// In en, this message translates to:
  /// **'Custom request'**
  String get oauthCustomRequest;

  /// No description provided for @oauthWeekly.
  ///
  /// In en, this message translates to:
  /// **'Weekly window'**
  String get oauthWeekly;

  /// No description provided for @oauthMonthly.
  ///
  /// In en, this message translates to:
  /// **'Monthly window'**
  String get oauthMonthly;

  /// No description provided for @oauthTotal.
  ///
  /// In en, this message translates to:
  /// **'Total quota'**
  String get oauthTotal;

  /// No description provided for @oauthHours.
  ///
  /// In en, this message translates to:
  /// **'{count} hour window'**
  String oauthHours(String count);

  /// No description provided for @oauthMinutes.
  ///
  /// In en, this message translates to:
  /// **'{count} minute window'**
  String oauthMinutes(String count);

  /// No description provided for @oauthDays.
  ///
  /// In en, this message translates to:
  /// **'{count} day window'**
  String oauthDays(String count);

  /// No description provided for @oauthWindow.
  ///
  /// In en, this message translates to:
  /// **'Usage window'**
  String get oauthWindow;

  /// No description provided for @oauthResetsAt.
  ///
  /// In en, this message translates to:
  /// **'Resets {time}'**
  String oauthResetsAt(String time);

  /// No description provided for @oauthUsedValue.
  ///
  /// In en, this message translates to:
  /// **'Used {value}'**
  String oauthUsedValue(String value);

  /// No description provided for @oauthNetworkError.
  ///
  /// In en, this message translates to:
  /// **'Could not connect. Check your network and try again.'**
  String get oauthNetworkError;

  /// No description provided for @oauthInvalidResponse.
  ///
  /// In en, this message translates to:
  /// **'Authorization did not complete. Please try again.'**
  String get oauthInvalidResponse;

  /// No description provided for @oauthTimeout.
  ///
  /// In en, this message translates to:
  /// **'Authorization timed out. Please try again.'**
  String get oauthTimeout;

  /// No description provided for @oauthDenied.
  ///
  /// In en, this message translates to:
  /// **'Authorization was not granted. Please try again.'**
  String get oauthDenied;

  /// No description provided for @oauthSaving.
  ///
  /// In en, this message translates to:
  /// **'Connecting account…'**
  String get oauthSaving;

  /// No description provided for @oauthQuotaExceeded.
  ///
  /// In en, this message translates to:
  /// **'This account has no available quota.'**
  String get oauthQuotaExceeded;

  /// No description provided for @oauthRateLimited.
  ///
  /// In en, this message translates to:
  /// **'Too many requests. Please try again later.'**
  String get oauthRateLimited;

  /// No description provided for @oauthPermissionDenied.
  ///
  /// In en, this message translates to:
  /// **'This account cannot access this resource.'**
  String get oauthPermissionDenied;

  /// No description provided for @oauthRequestFailed.
  ///
  /// In en, this message translates to:
  /// **'The provider could not complete the request.'**
  String get oauthRequestFailed;

  /// No description provided for @oauthQuotaAvailable.
  ///
  /// In en, this message translates to:
  /// **'Quota is available'**
  String get oauthQuotaAvailable;

  /// No description provided for @oauthSavedResets.
  ///
  /// In en, this message translates to:
  /// **'Available usage resets: {count}'**
  String oauthSavedResets(String count);

  /// No description provided for @oauthPrimaryWindow.
  ///
  /// In en, this message translates to:
  /// **'Primary window'**
  String get oauthPrimaryWindow;

  /// No description provided for @oauthSecondaryWindow.
  ///
  /// In en, this message translates to:
  /// **'Secondary window'**
  String get oauthSecondaryWindow;

  /// No description provided for @oauthAuthorizationCode.
  ///
  /// In en, this message translates to:
  /// **'Authorization code or callback URL'**
  String get oauthAuthorizationCode;

  /// No description provided for @oauthAuthorizationCodeHint.
  ///
  /// In en, this message translates to:
  /// **'If the browser does not return automatically, paste the final callback URL or authorization code here.'**
  String get oauthAuthorizationCodeHint;

  /// No description provided for @oauthInvalidAuthorizationCode.
  ///
  /// In en, this message translates to:
  /// **'Enter the code or callback URL from this login attempt.'**
  String get oauthInvalidAuthorizationCode;

  /// No description provided for @oauthSubmitAuthorizationCode.
  ///
  /// In en, this message translates to:
  /// **'Complete login'**
  String get oauthSubmitAuthorizationCode;

  /// No description provided for @oauthExtraUsage.
  ///
  /// In en, this message translates to:
  /// **'Extra usage'**
  String get oauthExtraUsage;

  /// No description provided for @oauthPromptCachingHelp.
  ///
  /// In en, this message translates to:
  /// **'Reuse context across messages and choose how long the cache is retained.'**
  String get oauthPromptCachingHelp;

  /// No description provided for @scheduledTasksPreparation.
  ///
  /// In en, this message translates to:
  /// **'Execution and notifications'**
  String get scheduledTasksPreparation;

  /// No description provided for @scheduledTasksAllowPreparation.
  ///
  /// In en, this message translates to:
  /// **'Allow advance preparation'**
  String get scheduledTasksAllowPreparation;

  /// No description provided for @scheduledTasksPreparationDetail.
  ///
  /// In en, this message translates to:
  /// **'Advance preparation is for text tasks that do not need current information. It cannot use tools or attachments, or perform external actions.'**
  String get scheduledTasksPreparationDetail;

  /// No description provided for @scheduledTasksIOSDetail.
  ///
  /// In en, this message translates to:
  /// **'iOS background limits prevent Kelivo from waking at a set time to run a model. Instead, content is prepared while the app can run, and the system shows a notification at the scheduled time. Only the next occurrence is prepared. Preparation may not finish after leaving the app; reopen Kelivo to prepare subsequent occurrences.'**
  String get scheduledTasksIOSDetail;

  /// No description provided for @scheduledTasksContextPolicy.
  ///
  /// In en, this message translates to:
  /// **'Conversation context'**
  String get scheduledTasksContextPolicy;

  /// No description provided for @scheduledTasksContextLatest.
  ///
  /// In en, this message translates to:
  /// **'Follow the latest conversation'**
  String get scheduledTasksContextLatest;

  /// No description provided for @scheduledTasksContextSnapshot.
  ///
  /// In en, this message translates to:
  /// **'Use the prepared snapshot'**
  String get scheduledTasksContextSnapshot;

  /// No description provided for @scheduledTasksUnavailable.
  ///
  /// In en, this message translates to:
  /// **'When unable to execute'**
  String get scheduledTasksUnavailable;

  /// No description provided for @scheduledTasksRemind.
  ///
  /// In en, this message translates to:
  /// **'Send a reminder only'**
  String get scheduledTasksRemind;

  /// No description provided for @scheduledTasksSkip.
  ///
  /// In en, this message translates to:
  /// **'Skip this occurrence'**
  String get scheduledTasksSkip;

  /// No description provided for @scheduledTasksNotify.
  ///
  /// In en, this message translates to:
  /// **'Result notifications'**
  String get scheduledTasksNotify;

  /// No description provided for @scheduledTasksShowPreview.
  ///
  /// In en, this message translates to:
  /// **'Show result text in notifications'**
  String get scheduledTasksShowPreview;

  /// No description provided for @scheduledTasksPreparationWindow.
  ///
  /// In en, this message translates to:
  /// **'Prepare up to'**
  String get scheduledTasksPreparationWindow;

  /// No description provided for @scheduledTasksPreparationAttempts.
  ///
  /// In en, this message translates to:
  /// **'Automatic attempt limit'**
  String get scheduledTasksPreparationAttempts;

  /// No description provided for @scheduledTasksPreparationCooldown.
  ///
  /// In en, this message translates to:
  /// **'Minimum interval (minutes)'**
  String get scheduledTasksPreparationCooldown;

  /// No description provided for @scheduledTasksPreparationBudget.
  ///
  /// In en, this message translates to:
  /// **'At most one preparation at a time across all tasks. Automatic preparation pauses after six total attempts per hour, including cancelled requests. Prepare now is not limited by attempt counts.'**
  String get scheduledTasksPreparationBudget;

  /// No description provided for @scheduledTasksPreparing.
  ///
  /// In en, this message translates to:
  /// **'Preparing result'**
  String get scheduledTasksPreparing;

  /// No description provided for @scheduledTasksPrepared.
  ///
  /// In en, this message translates to:
  /// **'Result prepared'**
  String get scheduledTasksPrepared;

  /// No description provided for @scheduledTasksPendingPreparation.
  ///
  /// In en, this message translates to:
  /// **'Result not prepared yet'**
  String get scheduledTasksPendingPreparation;

  /// No description provided for @scheduledTasksNotificationRegistered.
  ///
  /// In en, this message translates to:
  /// **'Notification scheduled'**
  String get scheduledTasksNotificationRegistered;

  /// No description provided for @scheduledTasksNotificationUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Notification not scheduled'**
  String get scheduledTasksNotificationUnavailable;

  /// No description provided for @scheduledTasksReminded.
  ///
  /// In en, this message translates to:
  /// **'Due · reminder only'**
  String get scheduledTasksReminded;

  /// No description provided for @scheduledTasksSkipped.
  ///
  /// In en, this message translates to:
  /// **'Skipped'**
  String get scheduledTasksSkipped;

  /// No description provided for @scheduledTasksCancelled.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get scheduledTasksCancelled;

  /// No description provided for @scheduledTasksReminderBody.
  ///
  /// In en, this message translates to:
  /// **'Your scheduled task is due. Open Kelivo to continue.'**
  String get scheduledTasksReminderBody;

  /// No description provided for @scheduledTasksResultBody.
  ///
  /// In en, this message translates to:
  /// **'Your scheduled task result is ready.'**
  String get scheduledTasksResultBody;

  /// No description provided for @scheduledTasksNotificationPermission.
  ///
  /// In en, this message translates to:
  /// **'Allow task notifications'**
  String get scheduledTasksNotificationPermission;

  /// No description provided for @scheduledTasksPreparationCost.
  ///
  /// In en, this message translates to:
  /// **'Preparation calls the model and may cost extra. With “Follow latest conversation”, new messages before the due time can invalidate a prepared result. Unused or cancelled output may still be billed, and preparing again makes another model request.'**
  String get scheduledTasksPreparationCost;

  /// No description provided for @scheduledTasksAllowPreparationTip.
  ///
  /// In en, this message translates to:
  /// **'Generate the next result before its scheduled time, while Kelivo can run. The result stays out of the chat until it is due. Preparation uses text only, without tools, attachments or custom request bodies. It may incur model charges.'**
  String get scheduledTasksAllowPreparationTip;

  /// No description provided for @scheduledTasksContextPolicyTip.
  ///
  /// In en, this message translates to:
  /// **'Follow latest conversation: before the task is due, new messages, edits or switching message versions invalidate the prepared result; preparing again uses another attempt and may cost extra. Once due, the saved notification result is added to the chat unchanged.\n\nUse preparation snapshot: keep the prepared result even if the conversation changes. It will not reflect later messages.'**
  String get scheduledTasksContextPolicyTip;

  /// No description provided for @scheduledTasksPreparationWindowTip.
  ///
  /// In en, this message translates to:
  /// **'How far ahead of the scheduled time preparation may begin, up to 24 hours. For example, opening Kelivo at noon can prepare the next morning’s reminder. A larger window gives more chances to prepare, but the result may be less current. It does not change the scheduled time or guarantee background execution. Prepare now bypasses this automatic waiting period and all attempt limits.'**
  String get scheduledTasksPreparationWindowTip;

  /// No description provided for @scheduledTasksPreparationAttemptsTip.
  ///
  /// In en, this message translates to:
  /// **'Automatic preparation pauses when this occurrence reaches the total attempt limit. First attempts, failures, cancellations and manual preparation all count in the record. Prepare now can still run after this limit is reached. More attempts may incur more model charges; this is not a spending limit.'**
  String get scheduledTasksPreparationAttemptsTip;

  /// No description provided for @scheduledTasksPreparationCooldownTip.
  ///
  /// In en, this message translates to:
  /// **'Minimum time between the start of preparation attempts for the same occurrence. Waiting longer reduces repeated requests. A retry still needs the app to be able to run; it is not a background timer. Prepare now bypasses this automatic waiting period and all attempt limits.'**
  String get scheduledTasksPreparationCooldownTip;

  /// No description provided for @scheduledTasksUnavailableTip.
  ///
  /// In en, this message translates to:
  /// **'If no prepared result is available and the task cannot run when due, send a reminder or skip the occurrence. A reminder contains no generated answer and requires notifications to be enabled. If Kelivo is open when the task is due, it can run the task then.'**
  String get scheduledTasksUnavailableTip;

  /// No description provided for @scheduledTasksNotifyTip.
  ///
  /// In en, this message translates to:
  /// **'Allow result notifications and fallback reminders. Turning this off does not stop the task or model calls, and does not prevent preparation charges. System notification permission is also required.'**
  String get scheduledTasksNotifyTip;

  /// No description provided for @scheduledTasksShowPreviewTip.
  ///
  /// In en, this message translates to:
  /// **'Show the prepared result text in the notification, including on the lock screen if allowed by system settings. Turn this off to show a generic notice; the full result remains available in the chat. Global notification privacy settings also apply.'**
  String get scheduledTasksShowPreviewTip;

  /// No description provided for @scheduledTasksHours.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 hour} other{{count} hours}}'**
  String scheduledTasksHours(int count);

  /// No description provided for @scheduledTasksMinutes.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 minute} other{{count} minutes}}'**
  String scheduledTasksMinutes(int count);

  /// No description provided for @scheduledTasksPreparationOff.
  ///
  /// In en, this message translates to:
  /// **'Preparation off'**
  String get scheduledTasksPreparationOff;

  /// No description provided for @scheduledTasksPreparationQueued.
  ///
  /// In en, this message translates to:
  /// **'Queued'**
  String get scheduledTasksPreparationQueued;

  /// No description provided for @scheduledTasksPreparationQueuedDetail.
  ///
  /// In en, this message translates to:
  /// **'Another task is being prepared. Eligible tasks continue in due-time order.'**
  String get scheduledTasksPreparationQueuedDetail;

  /// No description provided for @scheduledTasksPreparationIdle.
  ///
  /// In en, this message translates to:
  /// **'Waiting for chat'**
  String get scheduledTasksPreparationIdle;

  /// No description provided for @scheduledTasksPreparationIdleDetail.
  ///
  /// In en, this message translates to:
  /// **'Preparation resumes after active replies finish and this task’s context settles.'**
  String get scheduledTasksPreparationIdleDetail;

  /// No description provided for @scheduledTasksPreparationWindowWaiting.
  ///
  /// In en, this message translates to:
  /// **'Outside preparation window'**
  String get scheduledTasksPreparationWindowWaiting;

  /// No description provided for @scheduledTasksPreparationCooldownWaiting.
  ///
  /// In en, this message translates to:
  /// **'Waiting to retry'**
  String get scheduledTasksPreparationCooldownWaiting;

  /// No description provided for @scheduledTasksPreparationRetryAt.
  ///
  /// In en, this message translates to:
  /// **'Can retry after {time}'**
  String scheduledTasksPreparationRetryAt(String time);

  /// No description provided for @scheduledTasksPreparationLimitReached.
  ///
  /// In en, this message translates to:
  /// **'Automatic attempt limit reached'**
  String get scheduledTasksPreparationLimitReached;

  /// No description provided for @scheduledTasksPreparationAttemptsUsed.
  ///
  /// In en, this message translates to:
  /// **'This occurrence has used {count} attempts; the automatic limit is {limit}. Use Prepare now to continue manually.'**
  String scheduledTasksPreparationAttemptsUsed(int count, int limit);

  /// No description provided for @scheduledTasksPreparationHourlyLimit.
  ///
  /// In en, this message translates to:
  /// **'Automatic hourly limit reached'**
  String get scheduledTasksPreparationHourlyLimit;

  /// No description provided for @scheduledTasksPreparationHourlyLimitDetail.
  ///
  /// In en, this message translates to:
  /// **'Automatic preparation is paused until hourly capacity is available. You can still use Prepare now.'**
  String get scheduledTasksPreparationHourlyLimitDetail;

  /// No description provided for @scheduledTasksPreparationUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Preparation unavailable'**
  String get scheduledTasksPreparationUnavailable;

  /// No description provided for @scheduledTasksPreparationReadFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not read task context. It will be checked again shortly; see execution history for details.'**
  String get scheduledTasksPreparationReadFailed;

  /// No description provided for @scheduledTasksPreparationResultRetained.
  ///
  /// In en, this message translates to:
  /// **'Context could not be checked. The prepared result is retained and will be checked again.'**
  String get scheduledTasksPreparationResultRetained;

  /// No description provided for @scheduledTasksPreparationContextChanged.
  ///
  /// In en, this message translates to:
  /// **'The conversation or task context changed, so the earlier result was discarded.'**
  String get scheduledTasksPreparationContextChanged;

  /// No description provided for @scheduledTasksPreparationPublishing.
  ///
  /// In en, this message translates to:
  /// **'Waiting to add to chat'**
  String get scheduledTasksPreparationPublishing;

  /// No description provided for @scheduledTasksPreparationPublishingDetail.
  ///
  /// In en, this message translates to:
  /// **'The saved result will be added to the conversation when the current reply finishes.'**
  String get scheduledTasksPreparationPublishingDetail;

  /// No description provided for @scheduledTasksPreparationPrompt.
  ///
  /// In en, this message translates to:
  /// **'Preparation prompt'**
  String get scheduledTasksPreparationPrompt;

  /// No description provided for @scheduledTasksPreparationPromptTip.
  ///
  /// In en, this message translates to:
  /// **'Extra system instructions used only when preparing this task in advance, separate from the task instructions. You can change the style or remove these instructions entirely. Tools and live information remain unavailable. Editing this prompt invalidates any result prepared before the due time; preparing it again may incur another model charge.'**
  String get scheduledTasksPreparationPromptTip;

  /// No description provided for @scheduledTasksPreparationPromptEmpty.
  ///
  /// In en, this message translates to:
  /// **'Leave empty to add no preparation instructions'**
  String get scheduledTasksPreparationPromptEmpty;

  /// No description provided for @scheduledTasksPreparationPromptVariables.
  ///
  /// In en, this message translates to:
  /// **'Placeholders: {timeVariable} is the planned local delivery time; {offsetVariable} is its UTC offset. These are replaced when preparing the result.'**
  String scheduledTasksPreparationPromptVariables(
    String timeVariable,
    String offsetVariable,
  );

  /// No description provided for @scheduledTasksPrepareNow.
  ///
  /// In en, this message translates to:
  /// **'Prepare now'**
  String get scheduledTasksPrepareNow;

  /// No description provided for @scheduledTasksPrepareNowDetail.
  ///
  /// In en, this message translates to:
  /// **'Prepare the next result now and deliver it at the scheduled time. Automatic waiting periods and attempt limits do not apply. This may incur model charges. An existing prepared result is reused.'**
  String get scheduledTasksPrepareNowDetail;

  /// No description provided for @scheduledTasksPrepareNowReady.
  ///
  /// In en, this message translates to:
  /// **'The next result is already prepared. No additional model request was made.'**
  String get scheduledTasksPrepareNowReady;

  /// No description provided for @scheduledTasksPrepareNowStarted.
  ///
  /// In en, this message translates to:
  /// **'Preparing the next result for its scheduled time.'**
  String get scheduledTasksPrepareNowStarted;

  /// No description provided for @scheduledTasksPrepareNowBusy.
  ///
  /// In en, this message translates to:
  /// **'Another task is being prepared. Please try again when it finishes.'**
  String get scheduledTasksPrepareNowBusy;

  /// No description provided for @scheduledTasksPrepareNowChatBusy.
  ///
  /// In en, this message translates to:
  /// **'Please wait for the current reply to finish, then try again.'**
  String get scheduledTasksPrepareNowChatBusy;

  /// No description provided for @scheduledTasksPrepareNowDisabled.
  ///
  /// In en, this message translates to:
  /// **'Enable this task and advance preparation first. Regenerate tasks cannot be prepared in advance.'**
  String get scheduledTasksPrepareNowDisabled;

  /// No description provided for @scheduledTasksPrepareNowUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Preparation is not available yet. Please try again shortly.'**
  String get scheduledTasksPrepareNowUnavailable;

  /// No description provided for @scheduledTasksPrepareNowNoUpcoming.
  ///
  /// In en, this message translates to:
  /// **'There is no upcoming occurrence to prepare. Check the task time and enabled state.'**
  String get scheduledTasksPrepareNowNoUpcoming;

  /// No description provided for @phoneControlTitle.
  ///
  /// In en, this message translates to:
  /// **'Phone Control'**
  String get phoneControlTitle;

  /// No description provided for @phoneControlSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Read the screen and perform actions through Accessibility'**
  String get phoneControlSubtitle;

  /// No description provided for @phoneControlAccessibilityService.
  ///
  /// In en, this message translates to:
  /// **'Accessibility service'**
  String get phoneControlAccessibilityService;

  /// No description provided for @phoneControlOpenSettings.
  ///
  /// In en, this message translates to:
  /// **'Open accessibility settings'**
  String get phoneControlOpenSettings;

  /// No description provided for @phoneControlRefresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh status'**
  String get phoneControlRefresh;

  /// No description provided for @phoneControlChecking.
  ///
  /// In en, this message translates to:
  /// **'Checking service status…'**
  String get phoneControlChecking;

  /// No description provided for @phoneControlReady.
  ///
  /// In en, this message translates to:
  /// **'Enabled and connected'**
  String get phoneControlReady;

  /// No description provided for @phoneControlDisabled.
  ///
  /// In en, this message translates to:
  /// **'Not enabled'**
  String get phoneControlDisabled;

  /// No description provided for @phoneControlDisconnected.
  ///
  /// In en, this message translates to:
  /// **'Enabled, but not connected. Try turning the service off and on in system settings, then refresh.'**
  String get phoneControlDisconnected;

  /// No description provided for @phoneControlStatusUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Unable to read service status. Refresh to try again.'**
  String get phoneControlStatusUnavailable;

  /// No description provided for @phoneControlSettingsUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Unable to open settings. Open Android Settings → Accessibility manually.'**
  String get phoneControlSettingsUnavailable;

  /// No description provided for @phoneControlUsageTitle.
  ///
  /// In en, this message translates to:
  /// **'How it works'**
  String get phoneControlUsageTitle;

  /// No description provided for @phoneControlDisclosure.
  ///
  /// In en, this message translates to:
  /// **'For phone control tasks you request in a conversation, the assistant can read the current screen, tap, enter text, scroll, navigate, and open apps. Screen content is sent to the model provider configured for that conversation and is saved in its tool results. Password fields are hidden. This service does not continuously record screen content. You can turn off this tool for the assistant, or disable the service in system settings at any time.'**
  String get phoneControlDisclosure;

  /// No description provided for @phoneControlAssistantTitle.
  ///
  /// In en, this message translates to:
  /// **'Enable the tool for your assistant'**
  String get phoneControlAssistantTitle;

  /// No description provided for @phoneControlAssistantHint.
  ///
  /// In en, this message translates to:
  /// **'Both permissions are required: enable Kelivo phone control in system Accessibility settings, then enable Phone Control under your assistant’s Local Tools (also available in the chat tools menu). Each assistant is configured separately. Keep the phone unlocked while running a task.'**
  String get phoneControlAssistantHint;

  /// No description provided for @phoneControlRestrictedTitle.
  ///
  /// In en, this message translates to:
  /// **'Accessibility switch unavailable?'**
  String get phoneControlRestrictedTitle;

  /// No description provided for @phoneControlRestrictedHint.
  ///
  /// In en, this message translates to:
  /// **'For some downloaded APKs, Android requires “Allow restricted settings” in the app info menu first. Tap to open Kelivo’s app info, then return to Accessibility settings.'**
  String get phoneControlRestrictedHint;

  /// No description provided for @phoneControlEnableAssistant.
  ///
  /// In en, this message translates to:
  /// **'Allow this assistant to use phone control'**
  String get phoneControlEnableAssistant;

  /// No description provided for @composerDraftLabel.
  ///
  /// In en, this message translates to:
  /// **'Draft'**
  String get composerDraftLabel;

  /// No description provided for @composerDraftRecovered.
  ///
  /// In en, this message translates to:
  /// **'An unsent message was recovered.'**
  String get composerDraftRecovered;

  /// No description provided for @composerDraftRestore.
  ///
  /// In en, this message translates to:
  /// **'Continue editing'**
  String get composerDraftRestore;

  /// No description provided for @composerDraftDiscard.
  ///
  /// In en, this message translates to:
  /// **'Discard'**
  String get composerDraftDiscard;

  /// No description provided for @composerDraftSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Your latest draft could not be saved. It is still in this window.'**
  String get composerDraftSaveFailed;

  /// No description provided for @composerDraftRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry saving'**
  String get composerDraftRetry;

  /// No description provided for @composerDraftConflictTitle.
  ///
  /// In en, this message translates to:
  /// **'This conversation already has a draft'**
  String get composerDraftConflictTitle;

  /// No description provided for @composerDraftConflictBody.
  ///
  /// In en, this message translates to:
  /// **'Append keeps both texts and attachments. Replace discards the existing draft. Nothing is sent automatically.'**
  String get composerDraftConflictBody;

  /// No description provided for @composerDraftAppend.
  ///
  /// In en, this message translates to:
  /// **'Append'**
  String get composerDraftAppend;

  /// No description provided for @composerDraftReplace.
  ///
  /// In en, this message translates to:
  /// **'Replace draft'**
  String get composerDraftReplace;

  /// No description provided for @composerDraftMissingFile.
  ///
  /// In en, this message translates to:
  /// **'An attachment is unavailable. Remove it or choose the file again.'**
  String get composerDraftMissingFile;

  /// No description provided for @composerDraftMessageMissing.
  ///
  /// In en, this message translates to:
  /// **'The message being edited no longer exists. Copy the text to a new message or discard this edit.'**
  String get composerDraftMessageMissing;

  /// No description provided for @composerDraftDeleteNotice.
  ///
  /// In en, this message translates to:
  /// **'Unsent drafts in these conversations will also be deleted.'**
  String get composerDraftDeleteNotice;

  /// No description provided for @mcpOAuthSettings.
  ///
  /// In en, this message translates to:
  /// **'OAuth settings'**
  String get mcpOAuthSettings;

  /// No description provided for @mcpOAuthAutomatic.
  ///
  /// In en, this message translates to:
  /// **'Automatic'**
  String get mcpOAuthAutomatic;

  /// No description provided for @mcpOAuthMetadataUrl.
  ///
  /// In en, this message translates to:
  /// **'Client metadata document URL'**
  String get mcpOAuthMetadataUrl;

  /// No description provided for @mcpOAuthClientAuthentication.
  ///
  /// In en, this message translates to:
  /// **'Client authentication'**
  String get mcpOAuthClientAuthentication;

  /// No description provided for @mcpOAuthPublicClient.
  ///
  /// In en, this message translates to:
  /// **'Public client'**
  String get mcpOAuthPublicClient;

  /// No description provided for @mcpOAuthRedirectUri.
  ///
  /// In en, this message translates to:
  /// **'Local callback URL (optional)'**
  String get mcpOAuthRedirectUri;

  /// No description provided for @mcpOAuthFillRedirectExample.
  ///
  /// In en, this message translates to:
  /// **'Fill example'**
  String get mcpOAuthFillRedirectExample;

  /// No description provided for @mcpOAuthRedirectHint.
  ///
  /// In en, this message translates to:
  /// **'Leave empty to use the platform default. Use an HTTP loopback URL if the service only allows localhost callbacks. Port 0 selects an available port; a pre-registered client may require a fixed port.'**
  String get mcpOAuthRedirectHint;

  /// No description provided for @mcpOAuthClientIdRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter a client ID or choose automatic registration.'**
  String get mcpOAuthClientIdRequired;

  /// No description provided for @mcpOAuthMetadataUrlInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter an HTTPS metadata document URL with a path.'**
  String get mcpOAuthMetadataUrlInvalid;

  /// No description provided for @mcpOAuthSecretRequired.
  ///
  /// In en, this message translates to:
  /// **'This client authentication method requires a client secret.'**
  String get mcpOAuthSecretRequired;

  /// No description provided for @mcpOAuthRedirectInvalid.
  ///
  /// In en, this message translates to:
  /// **'Use an HTTP callback on localhost, 127.0.0.1 or [::1], without credentials, query parameters or a fragment.'**
  String get mcpOAuthRedirectInvalid;

  /// No description provided for @mcpOAuthDiscovering.
  ///
  /// In en, this message translates to:
  /// **'Discovering authorization server…'**
  String get mcpOAuthDiscovering;

  /// No description provided for @mcpOAuthRegistering.
  ///
  /// In en, this message translates to:
  /// **'Preparing authorization…'**
  String get mcpOAuthRegistering;

  /// No description provided for @mcpOAuthWaitingBrowser.
  ///
  /// In en, this message translates to:
  /// **'Waiting for browser authorization…'**
  String get mcpOAuthWaitingBrowser;

  /// No description provided for @mcpOAuthExchangingToken.
  ///
  /// In en, this message translates to:
  /// **'Completing sign-in…'**
  String get mcpOAuthExchangingToken;

  /// No description provided for @markdownPlaygroundTitle.
  ///
  /// In en, this message translates to:
  /// **'Markdown Playground'**
  String get markdownPlaygroundTitle;

  /// No description provided for @markdownPlaygroundSource.
  ///
  /// In en, this message translates to:
  /// **'Markdown source'**
  String get markdownPlaygroundSource;

  /// No description provided for @markdownPlaygroundPreview.
  ///
  /// In en, this message translates to:
  /// **'Preview'**
  String get markdownPlaygroundPreview;

  /// No description provided for @markdownPlaygroundAst.
  ///
  /// In en, this message translates to:
  /// **'AST'**
  String get markdownPlaygroundAst;

  /// No description provided for @markdownPlaygroundPlay.
  ///
  /// In en, this message translates to:
  /// **'Stream characters'**
  String get markdownPlaygroundPlay;

  /// No description provided for @markdownPlaygroundPause.
  ///
  /// In en, this message translates to:
  /// **'Pause'**
  String get markdownPlaygroundPause;

  /// No description provided for @markdownPlaygroundResume.
  ///
  /// In en, this message translates to:
  /// **'Resume'**
  String get markdownPlaygroundResume;

  /// No description provided for @markdownPlaygroundShowAll.
  ///
  /// In en, this message translates to:
  /// **'Show complete'**
  String get markdownPlaygroundShowAll;

  /// No description provided for @markdownPlaygroundWidth.
  ///
  /// In en, this message translates to:
  /// **'Preview width'**
  String get markdownPlaygroundWidth;

  /// No description provided for @markdownPlaygroundTheme.
  ///
  /// In en, this message translates to:
  /// **'Preview theme'**
  String get markdownPlaygroundTheme;

  /// No description provided for @markdownPlaygroundPlain.
  ///
  /// In en, this message translates to:
  /// **'Selected plain text'**
  String get markdownPlaygroundPlain;

  /// No description provided for @markdownPlaygroundMarkdown.
  ///
  /// In en, this message translates to:
  /// **'Selected Markdown'**
  String get markdownPlaygroundMarkdown;

  /// No description provided for @markdownPlaygroundSelectionHint.
  ///
  /// In en, this message translates to:
  /// **'Select text in the preview to inspect copied content.'**
  String get markdownPlaygroundSelectionHint;

  /// No description provided for @markdownPlaygroundEmpty.
  ///
  /// In en, this message translates to:
  /// **'Enter Markdown to preview it.'**
  String get markdownPlaygroundEmpty;

  /// No description provided for @markdownPlaygroundProgress.
  ///
  /// In en, this message translates to:
  /// **'Input {shown} / {total}'**
  String markdownPlaygroundProgress(int shown, int total);

  /// No description provided for @markdownCopyMarkdownAction.
  ///
  /// In en, this message translates to:
  /// **'Copy Markdown'**
  String get markdownCopyMarkdownAction;

  /// No description provided for @markdownCopyCsvAction.
  ///
  /// In en, this message translates to:
  /// **'Copy CSV'**
  String get markdownCopyCsvAction;

  /// No description provided for @markdownCopyImageAction.
  ///
  /// In en, this message translates to:
  /// **'Copy image'**
  String get markdownCopyImageAction;

  /// No description provided for @markdownCodeLabel.
  ///
  /// In en, this message translates to:
  /// **'Code'**
  String get markdownCodeLabel;

  /// No description provided for @markdownDetailsLabel.
  ///
  /// In en, this message translates to:
  /// **'Details'**
  String get markdownDetailsLabel;

  /// No description provided for @markdownMoreRows.
  ///
  /// In en, this message translates to:
  /// **'Show {count} more rows'**
  String markdownMoreRows(int count);

  /// No description provided for @markdownNoteLabel.
  ///
  /// In en, this message translates to:
  /// **'Note'**
  String get markdownNoteLabel;

  /// No description provided for @markdownTipLabel.
  ///
  /// In en, this message translates to:
  /// **'Tip'**
  String get markdownTipLabel;

  /// No description provided for @markdownImportantLabel.
  ///
  /// In en, this message translates to:
  /// **'Important'**
  String get markdownImportantLabel;

  /// No description provided for @markdownWarningLabel.
  ///
  /// In en, this message translates to:
  /// **'Warning'**
  String get markdownWarningLabel;

  /// No description provided for @markdownCautionLabel.
  ///
  /// In en, this message translates to:
  /// **'Caution'**
  String get markdownCautionLabel;

  /// No description provided for @markdownDangerLabel.
  ///
  /// In en, this message translates to:
  /// **'Danger'**
  String get markdownDangerLabel;

  /// No description provided for @markdownCopyRichTextAction.
  ///
  /// In en, this message translates to:
  /// **'Copy rich text'**
  String get markdownCopyRichTextAction;

  /// No description provided for @markdownCopySelectionFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not copy the selected text.'**
  String get markdownCopySelectionFailed;

  /// No description provided for @recoveryMissingDataTitle.
  ///
  /// In en, this message translates to:
  /// **'Previous data detected'**
  String get recoveryMissingDataTitle;

  /// No description provided for @recoveryMissingDataBody.
  ///
  /// In en, this message translates to:
  /// **'The current database is missing, but this device still contains previous data. Kelivo has paused startup and has not created an empty database. Your remaining files and copies are being preserved.'**
  String get recoveryMissingDataBody;

  /// No description provided for @recoveryEmptyDataTitle.
  ///
  /// In en, this message translates to:
  /// **'Current chat history is empty'**
  String get recoveryEmptyDataTitle;

  /// No description provided for @recoveryEmptyDataBody.
  ///
  /// In en, this message translates to:
  /// **'The current database has no conversations, but previous copies were found. Kelivo has paused startup so you can recover a copy or explicitly keep the current data. Nothing will be overwritten automatically.'**
  String get recoveryEmptyDataBody;

  /// No description provided for @recoveryKeepCurrent.
  ///
  /// In en, this message translates to:
  /// **'Keep current data and continue'**
  String get recoveryKeepCurrent;

  /// No description provided for @recoveryKeepCurrentConfirm.
  ///
  /// In en, this message translates to:
  /// **'Continue with the current empty database? Previous copies will remain available for recovery later.'**
  String get recoveryKeepCurrentConfirm;

  /// No description provided for @recoverySearchingCopies.
  ///
  /// In en, this message translates to:
  /// **'Finding and validating local data copies…'**
  String get recoverySearchingCopies;

  /// No description provided for @recoveryFoundCopies.
  ///
  /// In en, this message translates to:
  /// **'Found {count} validated copies. Choose one to recover your chats and settings. The original files will be kept.'**
  String recoveryFoundCopies(int count);

  /// No description provided for @recoveryInvalidCopy.
  ///
  /// In en, this message translates to:
  /// **'{name}: validation failed. The original file has been kept.'**
  String recoveryInvalidCopy(String name);

  /// No description provided for @recoverySearchFailed.
  ///
  /// In en, this message translates to:
  /// **'Some data locations could not be read. Your files have been kept; export a data copy before trying other recovery actions.'**
  String get recoverySearchFailed;

  /// No description provided for @recoveryDiscoveredCopyBody.
  ///
  /// In en, this message translates to:
  /// **'Found outside the managed copy folder. This original is preserved and will be fully validated before recovery.'**
  String get recoveryDiscoveredCopyBody;

  /// No description provided for @recoveryStorageFailureTitle.
  ///
  /// In en, this message translates to:
  /// **'Data storage needs attention'**
  String get recoveryStorageFailureTitle;

  /// No description provided for @recoveryStorageFailureBody.
  ///
  /// In en, this message translates to:
  /// **'Kelivo could not activate its protected data storage. Startup has stopped and the original data has been kept. Export a copy of your data or retry; no empty database will be created.'**
  String get recoveryStorageFailureBody;

  /// No description provided for @recoveryProtectingTitle.
  ///
  /// In en, this message translates to:
  /// **'Protecting the chat database'**
  String get recoveryProtectingTitle;

  /// No description provided for @recoveryProtectingData.
  ///
  /// In en, this message translates to:
  /// **'Copying and verifying the database. Images, attachments and snapshots stay in Documents and are not copied again. The original database will be kept.'**
  String get recoveryProtectingData;

  /// No description provided for @recoveryStorageReadyTitle.
  ///
  /// In en, this message translates to:
  /// **'Chat database moved to internal storage'**
  String get recoveryStorageReadyTitle;

  /// No description provided for @recoveryStorageReadyBody.
  ///
  /// In en, this message translates to:
  /// **'The database containing chats, assistants and settings now uses internal app storage. Snapshots, images and attachments remain accessible in the Files app under Documents. The original database is retained. If older chats are missing, open Settings → Backup → Local Copies.'**
  String get recoveryStorageReadyBody;

  /// No description provided for @recoveryRetainedData.
  ///
  /// In en, this message translates to:
  /// **'Retained original data'**
  String get recoveryRetainedData;

  /// No description provided for @recoveryNoValidCopies.
  ///
  /// In en, this message translates to:
  /// **'Copies were found, but none passed validation. The originals have been kept. You can export your data for further diagnosis.'**
  String get recoveryNoValidCopies;

  /// No description provided for @recoveryStorageInsufficientSpaceBody.
  ///
  /// In en, this message translates to:
  /// **'There is not enough free space to keep the original database and create its verified internal copy. Existing data and snapshots are unchanged. Free some space, then retry.'**
  String get recoveryStorageInsufficientSpaceBody;

  /// No description provided for @migrationFreshStartTitle.
  ///
  /// In en, this message translates to:
  /// **'Fresh start is ready'**
  String get migrationFreshStartTitle;

  /// No description provided for @migrationFreshStartSubtitle.
  ///
  /// In en, this message translates to:
  /// **'A new empty database is ready, and your previous data has been retained. Restart the app to continue.'**
  String get migrationFreshStartSubtitle;

  /// No description provided for @migrationFreshStartFailedTitle.
  ///
  /// In en, this message translates to:
  /// **'Fresh start could not be completed'**
  String get migrationFreshStartFailedTitle;

  /// No description provided for @migrationFreshStartFailedSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Your previous data has been retained. Retry starting fresh, or close and reopen the app.'**
  String get migrationFreshStartFailedSubtitle;

  /// No description provided for @imageExportPreparing.
  ///
  /// In en, this message translates to:
  /// **'Preparing image…'**
  String get imageExportPreparing;

  /// No description provided for @imageExportDiagrams.
  ///
  /// In en, this message translates to:
  /// **'Preparing diagrams {completed}/{total}…'**
  String imageExportDiagrams(int completed, int total);

  /// No description provided for @imageExportCapturing.
  ///
  /// In en, this message translates to:
  /// **'Capturing image {completed}/{total}…'**
  String imageExportCapturing(int completed, int total);

  /// No description provided for @imageExportProcessing.
  ///
  /// In en, this message translates to:
  /// **'Combining image and preparing preview…'**
  String get imageExportProcessing;

  /// No description provided for @imageExportSaving.
  ///
  /// In en, this message translates to:
  /// **'Saving image…'**
  String get imageExportSaving;

  /// No description provided for @backupEncryptionTitle.
  ///
  /// In en, this message translates to:
  /// **'Encrypt backups'**
  String get backupEncryptionTitle;

  /// No description provided for @backupEncryptionOffHint.
  ///
  /// In en, this message translates to:
  /// **'Unencrypted backups can be read by anyone with the file.'**
  String get backupEncryptionOffHint;

  /// No description provided for @backupEncryptionOnHint.
  ///
  /// In en, this message translates to:
  /// **'Backups are encrypted. Enter the password again after restarting the app.'**
  String get backupEncryptionOnHint;

  /// No description provided for @backupEncryptionPasswordHint.
  ///
  /// In en, this message translates to:
  /// **'Keep this password safe. If you lose it, the backup cannot be restored. It is kept in memory until you exit the app.'**
  String get backupEncryptionPasswordHint;

  /// No description provided for @backupEncryptionPassword.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get backupEncryptionPassword;

  /// No description provided for @backupEncryptionConfirmPassword.
  ///
  /// In en, this message translates to:
  /// **'Confirm password'**
  String get backupEncryptionConfirmPassword;

  /// No description provided for @backupEncryptionMismatch.
  ///
  /// In en, this message translates to:
  /// **'Passwords do not match.'**
  String get backupEncryptionMismatch;

  /// No description provided for @backupEncryptionShowPassword.
  ///
  /// In en, this message translates to:
  /// **'Show password'**
  String get backupEncryptionShowPassword;

  /// No description provided for @backupEncryptionHidePassword.
  ///
  /// In en, this message translates to:
  /// **'Hide password'**
  String get backupEncryptionHidePassword;

  /// No description provided for @backupEncryptionUnlockTitle.
  ///
  /// In en, this message translates to:
  /// **'Encrypted backup'**
  String get backupEncryptionUnlockTitle;

  /// No description provided for @backupEncryptionUnlockHint.
  ///
  /// In en, this message translates to:
  /// **'Enter the password used to create this backup.'**
  String get backupEncryptionUnlockHint;

  /// No description provided for @backupEncryptionUnlock.
  ///
  /// In en, this message translates to:
  /// **'Unlock'**
  String get backupEncryptionUnlock;

  /// No description provided for @backupEncryptionFailed.
  ///
  /// In en, this message translates to:
  /// **'The password is incorrect, or the backup is damaged. Try again or cancel.'**
  String get backupEncryptionFailed;

  /// No description provided for @backupEncryptionInvalid.
  ///
  /// In en, this message translates to:
  /// **'The encrypted backup is incomplete or invalid.'**
  String get backupEncryptionInvalid;

  /// No description provided for @backupEncryptionUnsupported.
  ///
  /// In en, this message translates to:
  /// **'This encrypted backup requires a newer version of Kelivo.'**
  String get backupEncryptionUnsupported;

  /// No description provided for @backupProgressEncrypting.
  ///
  /// In en, this message translates to:
  /// **'Encrypting backup'**
  String get backupProgressEncrypting;

  /// No description provided for @backupProgressDecrypting.
  ///
  /// In en, this message translates to:
  /// **'Decrypting backup'**
  String get backupProgressDecrypting;

  /// No description provided for @mcpPageStatusFailed.
  ///
  /// In en, this message translates to:
  /// **'Connection failed'**
  String get mcpPageStatusFailed;

  /// No description provided for @mcpPageCardToolsShort.
  ///
  /// In en, this message translates to:
  /// **'Tools {enabled}/{total}'**
  String mcpPageCardToolsShort(int enabled, int total);

  /// No description provided for @mcpPageSelectServer.
  ///
  /// In en, this message translates to:
  /// **'Select {name}'**
  String mcpPageSelectServer(String name);

  /// No description provided for @mcpIconTitle.
  ///
  /// In en, this message translates to:
  /// **'Server icon'**
  String get mcpIconTitle;

  /// No description provided for @mcpIconInvalid.
  ///
  /// In en, this message translates to:
  /// **'Unable to use this image. Choose a valid image up to 10 MB.'**
  String get mcpIconInvalid;

  /// No description provided for @mcpSelectServers.
  ///
  /// In en, this message translates to:
  /// **'Select servers'**
  String get mcpSelectServers;

  /// No description provided for @mcpMoveToGroup.
  ///
  /// In en, this message translates to:
  /// **'Move to group'**
  String get mcpMoveToGroup;

  /// No description provided for @mcpRenameGroup.
  ///
  /// In en, this message translates to:
  /// **'Rename group'**
  String get mcpRenameGroup;

  /// No description provided for @mcpDeleteGroupConfirm.
  ///
  /// In en, this message translates to:
  /// **'Servers in this group will be moved to Other. The servers will not be deleted.'**
  String get mcpDeleteGroupConfirm;

  /// No description provided for @mcpGroupNameInvalid.
  ///
  /// In en, this message translates to:
  /// **'Use a nonempty, unique group name.'**
  String get mcpGroupNameInvalid;

  /// No description provided for @mcpEnableSelected.
  ///
  /// In en, this message translates to:
  /// **'Enable'**
  String get mcpEnableSelected;

  /// No description provided for @mcpDisableSelected.
  ///
  /// In en, this message translates to:
  /// **'Disable'**
  String get mcpDisableSelected;

  /// No description provided for @mcpDeleteSelectedConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete {count} selected servers?'**
  String mcpDeleteSelectedConfirm(int count);

  /// No description provided for @browserTitle.
  ///
  /// In en, this message translates to:
  /// **'Browser'**
  String get browserTitle;

  /// No description provided for @browserSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search or enter website'**
  String get browserSearchHint;

  /// No description provided for @browserStartTitle.
  ///
  /// In en, this message translates to:
  /// **'Where to next?'**
  String get browserStartTitle;

  /// No description provided for @browserStartSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Browse freely. Let your agent help when you need it.'**
  String get browserStartSubtitle;

  /// No description provided for @browserNewTab.
  ///
  /// In en, this message translates to:
  /// **'New tab'**
  String get browserNewTab;

  /// No description provided for @browserTabs.
  ///
  /// In en, this message translates to:
  /// **'Tabs'**
  String get browserTabs;

  /// No description provided for @browserCloseTab.
  ///
  /// In en, this message translates to:
  /// **'Close tab'**
  String get browserCloseTab;

  /// No description provided for @browserClose.
  ///
  /// In en, this message translates to:
  /// **'Close browser'**
  String get browserClose;

  /// No description provided for @browserBack.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get browserBack;

  /// No description provided for @browserForward.
  ///
  /// In en, this message translates to:
  /// **'Forward'**
  String get browserForward;

  /// No description provided for @browserReload.
  ///
  /// In en, this message translates to:
  /// **'Reload'**
  String get browserReload;

  /// No description provided for @browserStop.
  ///
  /// In en, this message translates to:
  /// **'Stop loading'**
  String get browserStop;

  /// No description provided for @browserMore.
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get browserMore;

  /// No description provided for @browserBookmarks.
  ///
  /// In en, this message translates to:
  /// **'Bookmarks'**
  String get browserBookmarks;

  /// No description provided for @browserHistory.
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get browserHistory;

  /// No description provided for @browserSettings.
  ///
  /// In en, this message translates to:
  /// **'Browser settings'**
  String get browserSettings;

  /// No description provided for @browserAddBookmark.
  ///
  /// In en, this message translates to:
  /// **'Add bookmark'**
  String get browserAddBookmark;

  /// No description provided for @browserRemoveBookmark.
  ///
  /// In en, this message translates to:
  /// **'Remove bookmark'**
  String get browserRemoveBookmark;

  /// No description provided for @browserNoBookmarks.
  ///
  /// In en, this message translates to:
  /// **'Your favorite places, all together.'**
  String get browserNoBookmarks;

  /// No description provided for @browserNoHistory.
  ///
  /// In en, this message translates to:
  /// **'Your browsing history appears here.'**
  String get browserNoHistory;

  /// No description provided for @browserSearchLibrary.
  ///
  /// In en, this message translates to:
  /// **'Search saved pages'**
  String get browserSearchLibrary;

  /// No description provided for @browserClearHistory.
  ///
  /// In en, this message translates to:
  /// **'Clear history'**
  String get browserClearHistory;

  /// No description provided for @browserClearHistoryConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete all browsing history? Bookmarks will be kept.'**
  String get browserClearHistoryConfirm;

  /// No description provided for @browserToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get browserToday;

  /// No description provided for @browserYesterday.
  ///
  /// In en, this message translates to:
  /// **'Yesterday'**
  String get browserYesterday;

  /// No description provided for @browserDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get browserDelete;

  /// No description provided for @browserCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get browserCancel;

  /// No description provided for @browserDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get browserDone;

  /// No description provided for @browserFind.
  ///
  /// In en, this message translates to:
  /// **'Find on page'**
  String get browserFind;

  /// No description provided for @browserFindPreviousMatch.
  ///
  /// In en, this message translates to:
  /// **'Previous match'**
  String get browserFindPreviousMatch;

  /// No description provided for @browserFindNextMatch.
  ///
  /// In en, this message translates to:
  /// **'Next match'**
  String get browserFindNextMatch;

  /// No description provided for @browserFindHint.
  ///
  /// In en, this message translates to:
  /// **'Find text'**
  String get browserFindHint;

  /// No description provided for @browserSearchEngine.
  ///
  /// In en, this message translates to:
  /// **'Search engine'**
  String get browserSearchEngine;

  /// No description provided for @browserDesktopMode.
  ///
  /// In en, this message translates to:
  /// **'Desktop website'**
  String get browserDesktopMode;

  /// No description provided for @browserDesktopModeDescription.
  ///
  /// In en, this message translates to:
  /// **'Reload open pages with a desktop user agent.'**
  String get browserDesktopModeDescription;

  /// No description provided for @browserRestoreTabs.
  ///
  /// In en, this message translates to:
  /// **'Restore tabs'**
  String get browserRestoreTabs;

  /// No description provided for @browserRestoreTabsDescription.
  ///
  /// In en, this message translates to:
  /// **'Reopen your tabs when Kelivo starts.'**
  String get browserRestoreTabsDescription;

  /// No description provided for @browserSaveHistory.
  ///
  /// In en, this message translates to:
  /// **'Save history'**
  String get browserSaveHistory;

  /// No description provided for @browserSaveHistoryDescription.
  ///
  /// In en, this message translates to:
  /// **'Keep a local record of the pages you visit.'**
  String get browserSaveHistoryDescription;

  /// No description provided for @browserClearData.
  ///
  /// In en, this message translates to:
  /// **'Clear website data'**
  String get browserClearData;

  /// No description provided for @browserClearDataConfirm.
  ///
  /// In en, this message translates to:
  /// **'Clear cookies, storage and cache, and close all tabs? You will be signed out of websites.'**
  String get browserClearDataConfirm;

  /// No description provided for @browserDataCleared.
  ///
  /// In en, this message translates to:
  /// **'Website data cleared'**
  String get browserDataCleared;

  /// No description provided for @browserAgentControl.
  ///
  /// In en, this message translates to:
  /// **'Agent control'**
  String get browserAgentControl;

  /// No description provided for @browserAgentWorking.
  ///
  /// In en, this message translates to:
  /// **'AI is working'**
  String get browserAgentWorking;

  /// No description provided for @browserTakeOver.
  ///
  /// In en, this message translates to:
  /// **'Take over'**
  String get browserTakeOver;

  /// No description provided for @browserAgentPaused.
  ///
  /// In en, this message translates to:
  /// **'AI actions paused'**
  String get browserAgentPaused;

  /// No description provided for @browserAllowAgent.
  ///
  /// In en, this message translates to:
  /// **'Allow to continue'**
  String get browserAllowAgent;

  /// No description provided for @browserAgentDescription.
  ///
  /// In en, this message translates to:
  /// **'Send a task in chat to let AI use the browser. Allowing it to continue only removes the pause; it does not send a message or start a task.'**
  String get browserAgentDescription;

  /// No description provided for @browserOpenExternal.
  ///
  /// In en, this message translates to:
  /// **'Open in default browser'**
  String get browserOpenExternal;

  /// No description provided for @browserCopyLink.
  ///
  /// In en, this message translates to:
  /// **'Copy link'**
  String get browserCopyLink;

  /// No description provided for @browserLinkCopied.
  ///
  /// In en, this message translates to:
  /// **'Link copied'**
  String get browserLinkCopied;

  /// No description provided for @browserUnsupported.
  ///
  /// In en, this message translates to:
  /// **'The embedded browser is not available on this platform.'**
  String get browserUnsupported;

  /// No description provided for @browserLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'This page could not be loaded'**
  String get browserLoadFailed;

  /// No description provided for @browserRetry.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get browserRetry;

  /// No description provided for @browserFavorites.
  ///
  /// In en, this message translates to:
  /// **'Favorites'**
  String get browserFavorites;

  /// No description provided for @browserEditBookmark.
  ///
  /// In en, this message translates to:
  /// **'Edit bookmark'**
  String get browserEditBookmark;

  /// No description provided for @browserBookmarkTitle.
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get browserBookmarkTitle;

  /// No description provided for @browserBookmarkUrl.
  ///
  /// In en, this message translates to:
  /// **'Website'**
  String get browserBookmarkUrl;

  /// No description provided for @browserSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get browserSave;

  /// No description provided for @browserDownloads.
  ///
  /// In en, this message translates to:
  /// **'Downloads'**
  String get browserDownloads;

  /// No description provided for @browserNoDownloads.
  ///
  /// In en, this message translates to:
  /// **'Downloaded files appear here.'**
  String get browserNoDownloads;

  /// No description provided for @browserDownloadCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel download'**
  String get browserDownloadCancel;

  /// No description provided for @browserOpenDownload.
  ///
  /// In en, this message translates to:
  /// **'Open file'**
  String get browserOpenDownload;

  /// No description provided for @browserDownloadFailed.
  ///
  /// In en, this message translates to:
  /// **'Download failed'**
  String get browserDownloadFailed;

  /// No description provided for @browserAgentEnableHint.
  ///
  /// In en, this message translates to:
  /// **'Enable the Browser tool in chat tools, then allow control here.'**
  String get browserAgentEnableHint;

  /// No description provided for @browserSessionRequired.
  ///
  /// In en, this message translates to:
  /// **'Open the browser from a conversation to allow agent control.'**
  String get browserSessionRequired;

  /// No description provided for @browserDownloadCancelled.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get browserDownloadCancelled;

  /// No description provided for @browserAgentEnabled.
  ///
  /// In en, this message translates to:
  /// **'Allow assistant browser access'**
  String get browserAgentEnabled;

  /// No description provided for @browserAgentEnabledDescription.
  ///
  /// In en, this message translates to:
  /// **'Enabled assistants can browse and interact with pages in this browser.'**
  String get browserAgentEnabledDescription;

  /// No description provided for @browserToolTitle.
  ///
  /// In en, this message translates to:
  /// **'Browser control'**
  String get browserToolTitle;

  /// No description provided for @browserToolSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Browse and interact with signed-in pages. Enable Agent control in browser settings first.'**
  String get browserToolSubtitle;

  /// No description provided for @browserOpen.
  ///
  /// In en, this message translates to:
  /// **'Open browser'**
  String get browserOpen;

  /// No description provided for @browserInvalidUrl.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid HTTP or HTTPS website address.'**
  String get browserInvalidUrl;

  /// No description provided for @browserClearDataUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Clearing all website data is not supported by the Windows browser engine.'**
  String get browserClearDataUnavailable;

  /// No description provided for @browserSurfaceStyle.
  ///
  /// In en, this message translates to:
  /// **'Surface style'**
  String get browserSurfaceStyle;

  /// No description provided for @browserSurfaceLiquid.
  ///
  /// In en, this message translates to:
  /// **'Liquid glass'**
  String get browserSurfaceLiquid;

  /// No description provided for @browserSurfaceFrosted.
  ///
  /// In en, this message translates to:
  /// **'Frosted'**
  String get browserSurfaceFrosted;

  /// No description provided for @browserSurfaceSolid.
  ///
  /// In en, this message translates to:
  /// **'Solid'**
  String get browserSurfaceSolid;

  /// No description provided for @browserPageOptions.
  ///
  /// In en, this message translates to:
  /// **'Page options'**
  String get browserPageOptions;

  /// No description provided for @browserAskAi.
  ///
  /// In en, this message translates to:
  /// **'Let AI work on this page'**
  String get browserAskAi;

  /// No description provided for @browserAskAiHint.
  ///
  /// In en, this message translates to:
  /// **'Return to chat, add your request, then send.'**
  String get browserAskAiHint;

  /// No description provided for @browserAskAiCurrentPage.
  ///
  /// In en, this message translates to:
  /// **'the current browser page'**
  String get browserAskAiCurrentPage;

  /// No description provided for @browserAskAiUnavailable.
  ///
  /// In en, this message translates to:
  /// **'This chat is unavailable. Open the browser from a chat first.'**
  String get browserAskAiUnavailable;

  /// No description provided for @browserAskAiEditing.
  ///
  /// In en, this message translates to:
  /// **'Finish or cancel editing the current message before adding a page task.'**
  String get browserAskAiEditing;

  /// No description provided for @browserAskAiAssistantDisabled.
  ///
  /// In en, this message translates to:
  /// **'Enable Browser control in this assistant’s tools first.'**
  String get browserAskAiAssistantDisabled;

  /// No description provided for @browserAskAiBrowserDisabled.
  ///
  /// In en, this message translates to:
  /// **'Allow assistants to use the browser in browser settings first.'**
  String get browserAskAiBrowserDisabled;

  /// No description provided for @browserAskAiDraft.
  ///
  /// In en, this message translates to:
  /// **'Please use the browser to work on this page:\n{page}\n\nMy request: '**
  String browserAskAiDraft(String page);

  /// No description provided for @browserOpenFullPage.
  ///
  /// In en, this message translates to:
  /// **'Open in full page'**
  String get browserOpenFullPage;

  /// No description provided for @browserClosePanel.
  ///
  /// In en, this message translates to:
  /// **'Close browser panel'**
  String get browserClosePanel;

  /// No description provided for @browserSearchTabs.
  ///
  /// In en, this message translates to:
  /// **'Search tabs'**
  String get browserSearchTabs;

  /// No description provided for @browserTabsCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 tab} other{{count} tabs}}'**
  String browserTabsCount(int count);

  /// No description provided for @browserOpenInSidebar.
  ///
  /// In en, this message translates to:
  /// **'Open in sidebar'**
  String get browserOpenInSidebar;

  /// No description provided for @browserUserAgent.
  ///
  /// In en, this message translates to:
  /// **'User agent'**
  String get browserUserAgent;

  /// No description provided for @browserUserAgentMobile.
  ///
  /// In en, this message translates to:
  /// **'Mobile'**
  String get browserUserAgentMobile;

  /// No description provided for @browserUserAgentDesktop.
  ///
  /// In en, this message translates to:
  /// **'Desktop'**
  String get browserUserAgentDesktop;

  /// No description provided for @browserUserAgentCustom.
  ///
  /// In en, this message translates to:
  /// **'Custom'**
  String get browserUserAgentCustom;

  /// No description provided for @browserUserAgentHint.
  ///
  /// In en, this message translates to:
  /// **'Enter a custom User-Agent'**
  String get browserUserAgentHint;

  /// No description provided for @browserUserAgentInvalid.
  ///
  /// In en, this message translates to:
  /// **'Use a single line of up to 2048 printable ASCII characters.'**
  String get browserUserAgentInvalid;

  /// No description provided for @browserUserAgentDescription.
  ///
  /// In en, this message translates to:
  /// **'Changes reload the current webpage.'**
  String get browserUserAgentDescription;

  /// No description provided for @browserStepsShowEarlier.
  ///
  /// In en, this message translates to:
  /// **'{count} earlier steps'**
  String browserStepsShowEarlier(int count);

  /// No description provided for @browserOpenThisPage.
  ///
  /// In en, this message translates to:
  /// **'Open in browser'**
  String get browserOpenThisPage;

  /// No description provided for @browserGroupToggleSemantics.
  ///
  /// In en, this message translates to:
  /// **'Show or hide browser steps'**
  String get browserGroupToggleSemantics;

  /// No description provided for @browserStepGroupTitle.
  ///
  /// In en, this message translates to:
  /// **'Browsing'**
  String get browserStepGroupTitle;

  /// Browser page card browserStepCount
  ///
  /// In en, this message translates to:
  /// **'{count} steps'**
  String browserStepCount(int count);

  /// Browser page card browserStepCurrent
  ///
  /// In en, this message translates to:
  /// **'step {count}'**
  String browserStepCurrent(int count);

  /// Browser page card browserActionFailedCount
  ///
  /// In en, this message translates to:
  /// **'· {count} failed'**
  String browserActionFailedCount(int count);

  /// Browser page card browserActionFailed
  ///
  /// In en, this message translates to:
  /// **'{action} failed'**
  String browserActionFailed(String action);

  /// No description provided for @browserCardOpen.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get browserCardOpen;

  /// No description provided for @browserCardEnable.
  ///
  /// In en, this message translates to:
  /// **'Enable'**
  String get browserCardEnable;

  /// Browser page card browserCardRunning
  ///
  /// In en, this message translates to:
  /// **'{action}…'**
  String browserCardRunning(String action);

  /// No description provided for @browserCardLive.
  ///
  /// In en, this message translates to:
  /// **'Live'**
  String get browserCardLive;

  /// No description provided for @browserCardOpenFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t open page'**
  String get browserCardOpenFailed;

  /// No description provided for @browserCardBlankPage.
  ///
  /// In en, this message translates to:
  /// **'Blank page'**
  String get browserCardBlankPage;

  /// Browser page card browserCardTabCount
  ///
  /// In en, this message translates to:
  /// **'{count} tabs'**
  String browserCardTabCount(int count);

  /// No description provided for @browserActionOpen.
  ///
  /// In en, this message translates to:
  /// **'Open page'**
  String get browserActionOpen;

  /// No description provided for @browserActionNewTab.
  ///
  /// In en, this message translates to:
  /// **'New tab'**
  String get browserActionNewTab;

  /// No description provided for @browserActionRender.
  ///
  /// In en, this message translates to:
  /// **'Render page'**
  String get browserActionRender;

  /// No description provided for @browserActionExtract.
  ///
  /// In en, this message translates to:
  /// **'Extract text'**
  String get browserActionExtract;

  /// No description provided for @browserActionSnapshot.
  ///
  /// In en, this message translates to:
  /// **'Read page structure'**
  String get browserActionSnapshot;

  /// No description provided for @browserActionClick.
  ///
  /// In en, this message translates to:
  /// **'Click'**
  String get browserActionClick;

  /// No description provided for @browserActionType.
  ///
  /// In en, this message translates to:
  /// **'Type'**
  String get browserActionType;

  /// No description provided for @browserActionPress.
  ///
  /// In en, this message translates to:
  /// **'Press key'**
  String get browserActionPress;

  /// No description provided for @browserActionScroll.
  ///
  /// In en, this message translates to:
  /// **'Scroll'**
  String get browserActionScroll;

  /// No description provided for @browserActionWait.
  ///
  /// In en, this message translates to:
  /// **'Wait'**
  String get browserActionWait;

  /// No description provided for @browserActionBack.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get browserActionBack;

  /// No description provided for @browserActionForward.
  ///
  /// In en, this message translates to:
  /// **'Forward'**
  String get browserActionForward;

  /// No description provided for @browserActionReload.
  ///
  /// In en, this message translates to:
  /// **'Reload'**
  String get browserActionReload;

  /// No description provided for @browserActionEvaluate.
  ///
  /// In en, this message translates to:
  /// **'Run script'**
  String get browserActionEvaluate;

  /// No description provided for @browserActionSwitchTab.
  ///
  /// In en, this message translates to:
  /// **'Switch tab'**
  String get browserActionSwitchTab;

  /// No description provided for @browserActionCloseTab.
  ///
  /// In en, this message translates to:
  /// **'Close tab'**
  String get browserActionCloseTab;

  /// No description provided for @browserActionListTabs.
  ///
  /// In en, this message translates to:
  /// **'List tabs'**
  String get browserActionListTabs;

  /// No description provided for @browserActionUnknown.
  ///
  /// In en, this message translates to:
  /// **'Browser action'**
  String get browserActionUnknown;

  /// Browser page card browserMetaChars
  ///
  /// In en, this message translates to:
  /// **'{count} chars'**
  String browserMetaChars(String count);

  /// Browser page card browserMetaElements
  ///
  /// In en, this message translates to:
  /// **'{count} elements'**
  String browserMetaElements(int count);

  /// No description provided for @browserErrAgentDisabled.
  ///
  /// In en, this message translates to:
  /// **'Browser control is off'**
  String get browserErrAgentDisabled;

  /// No description provided for @browserErrStaleRef.
  ///
  /// In en, this message translates to:
  /// **'Element is stale; page needs re-reading'**
  String get browserErrStaleRef;

  /// No description provided for @browserErrNotVisible.
  ///
  /// In en, this message translates to:
  /// **'Element hidden or covered'**
  String get browserErrNotVisible;

  /// No description provided for @browserErrNotFound.
  ///
  /// In en, this message translates to:
  /// **'Element not found'**
  String get browserErrNotFound;

  /// No description provided for @browserErrTimeout.
  ///
  /// In en, this message translates to:
  /// **'Page load timed out'**
  String get browserErrTimeout;

  /// No description provided for @browserErrHumanControl.
  ///
  /// In en, this message translates to:
  /// **'You\'re controlling the browser'**
  String get browserErrHumanControl;

  /// No description provided for @browserErrTabClosed.
  ///
  /// In en, this message translates to:
  /// **'Tab was closed'**
  String get browserErrTabClosed;

  /// No description provided for @browserErrGeneric.
  ///
  /// In en, this message translates to:
  /// **'Action failed'**
  String get browserErrGeneric;

  /// No description provided for @browserDirectionUp.
  ///
  /// In en, this message translates to:
  /// **'Up'**
  String get browserDirectionUp;

  /// No description provided for @browserDirectionDown.
  ///
  /// In en, this message translates to:
  /// **'Down'**
  String get browserDirectionDown;

  /// No description provided for @browserDirectionLeft.
  ///
  /// In en, this message translates to:
  /// **'Left'**
  String get browserDirectionLeft;

  /// No description provided for @browserDirectionRight.
  ///
  /// In en, this message translates to:
  /// **'Right'**
  String get browserDirectionRight;

  /// Number of tabs returned by list_tabs
  ///
  /// In en, this message translates to:
  /// **'{count} tabs'**
  String browserMetaTabs(int count);

  /// No description provided for @browserTabsCurrentConversation.
  ///
  /// In en, this message translates to:
  /// **'This chat'**
  String get browserTabsCurrentConversation;

  /// No description provided for @browserTabsAll.
  ///
  /// In en, this message translates to:
  /// **'All tabs'**
  String get browserTabsAll;

  /// No description provided for @browserTabsUnassigned.
  ///
  /// In en, this message translates to:
  /// **'Personal tabs'**
  String get browserTabsUnassigned;

  /// No description provided for @browserTabsUnknownConversation.
  ///
  /// In en, this message translates to:
  /// **'Other chat'**
  String get browserTabsUnknownConversation;

  /// No description provided for @browserTabsEmptyConversation.
  ///
  /// In en, this message translates to:
  /// **'No tabs here yet. Open a page or choose a tab from All tabs.'**
  String get browserTabsEmptyConversation;

  /// No description provided for @browserTabsNoResults.
  ///
  /// In en, this message translates to:
  /// **'No matching tabs'**
  String get browserTabsNoResults;

  /// No description provided for @browserMoveToConversation.
  ///
  /// In en, this message translates to:
  /// **'Move to this chat'**
  String get browserMoveToConversation;

  /// No description provided for @browserReopenInConversation.
  ///
  /// In en, this message translates to:
  /// **'Reopen in this chat'**
  String get browserReopenInConversation;

  /// No description provided for @browserTabBusy.
  ///
  /// In en, this message translates to:
  /// **'An assistant is still using this page. Wait for it to finish or stop the task before moving it.'**
  String get browserTabBusy;

  /// No description provided for @browserLiveViewLimit.
  ///
  /// In en, this message translates to:
  /// **'All browser resources are in use. Try again when a task finishes, or close an unused page.'**
  String get browserLiveViewLimit;

  /// No description provided for @browserAskAiInOwnerConversation.
  ///
  /// In en, this message translates to:
  /// **'Ask AI in the owning chat'**
  String get browserAskAiInOwnerConversation;

  /// No description provided for @displaySettingsPageShowBrowserPageCardsTitle.
  ///
  /// In en, this message translates to:
  /// **'Show webpage cards'**
  String get displaySettingsPageShowBrowserPageCardsTitle;

  /// No description provided for @browserObserverHint.
  ///
  /// In en, this message translates to:
  /// **'AI is using this page. Select Take over to interact.'**
  String get browserObserverHint;

  /// No description provided for @genuiSurfaceTitle.
  ///
  /// In en, this message translates to:
  /// **'Interactive UI'**
  String get genuiSurfaceTitle;

  /// No description provided for @genuiStatusStreaming.
  ///
  /// In en, this message translates to:
  /// **'Generating'**
  String get genuiStatusStreaming;

  /// No description provided for @genuiStatusInterrupted.
  ///
  /// In en, this message translates to:
  /// **'Interrupted'**
  String get genuiStatusInterrupted;

  /// No description provided for @genuiStatusUnsaved.
  ///
  /// In en, this message translates to:
  /// **'Not saved'**
  String get genuiStatusUnsaved;

  /// No description provided for @genuiStatusUnsavedRetry.
  ///
  /// In en, this message translates to:
  /// **'Tap to retry saving'**
  String get genuiStatusUnsavedRetry;

  /// No description provided for @genuiReadOnlyUntilComplete.
  ///
  /// In en, this message translates to:
  /// **'Available when generation finishes'**
  String get genuiReadOnlyUntilComplete;

  /// No description provided for @genuiReadOnlySnapshot.
  ///
  /// In en, this message translates to:
  /// **'Read-only snapshot'**
  String get genuiReadOnlySnapshot;

  /// No description provided for @genuiPendingNode.
  ///
  /// In en, this message translates to:
  /// **'Waiting for {id}'**
  String genuiPendingNode(String id);

  /// No description provided for @genuiViewSource.
  ///
  /// In en, this message translates to:
  /// **'View source'**
  String get genuiViewSource;

  /// No description provided for @genuiCopySource.
  ///
  /// In en, this message translates to:
  /// **'Copy source'**
  String get genuiCopySource;

  /// No description provided for @genuiExpand.
  ///
  /// In en, this message translates to:
  /// **'Expand'**
  String get genuiExpand;

  /// No description provided for @genuiExpandedStub.
  ///
  /// In en, this message translates to:
  /// **'Being edited in expanded view'**
  String get genuiExpandedStub;

  /// No description provided for @genuiMore.
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get genuiMore;

  /// No description provided for @genuiReset.
  ///
  /// In en, this message translates to:
  /// **'Reset to defaults'**
  String get genuiReset;

  /// No description provided for @genuiRepair.
  ///
  /// In en, this message translates to:
  /// **'Repair UI'**
  String get genuiRepair;

  /// No description provided for @genuiInvalidTitle.
  ///
  /// In en, this message translates to:
  /// **'This UI can\'t be displayed'**
  String get genuiInvalidTitle;

  /// No description provided for @genuiNodesFailed.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 node can\'t be displayed} other{{count} nodes can\'t be displayed}}'**
  String genuiNodesFailed(int count);

  /// No description provided for @genuiErrorLine.
  ///
  /// In en, this message translates to:
  /// **'Line {line}'**
  String genuiErrorLine(int line);

  /// No description provided for @genuiValueUnavailable.
  ///
  /// In en, this message translates to:
  /// **'No value'**
  String get genuiValueUnavailable;

  /// No description provided for @genuiFormulaInvalid.
  ///
  /// In en, this message translates to:
  /// **'This formula can\'t be displayed'**
  String get genuiFormulaInvalid;

  /// No description provided for @genuiNodeUnavailable.
  ///
  /// In en, this message translates to:
  /// **'This component is unavailable'**
  String get genuiNodeUnavailable;

  /// No description provided for @genuiErrorHeader.
  ///
  /// In en, this message translates to:
  /// **'Invalid UI header'**
  String get genuiErrorHeader;

  /// No description provided for @genuiErrorVersion.
  ///
  /// In en, this message translates to:
  /// **'Unsupported UI language version'**
  String get genuiErrorVersion;

  /// No description provided for @genuiErrorCatalog.
  ///
  /// In en, this message translates to:
  /// **'Unsupported component catalog'**
  String get genuiErrorCatalog;

  /// No description provided for @genuiErrorRoot.
  ///
  /// In en, this message translates to:
  /// **'Missing or invalid root component'**
  String get genuiErrorRoot;

  /// No description provided for @genuiErrorSyntax.
  ///
  /// In en, this message translates to:
  /// **'Invalid declaration syntax'**
  String get genuiErrorSyntax;

  /// No description provided for @genuiErrorDuplicateSymbol.
  ///
  /// In en, this message translates to:
  /// **'A name is defined more than once'**
  String get genuiErrorDuplicateSymbol;

  /// No description provided for @genuiErrorDuplicateProperty.
  ///
  /// In en, this message translates to:
  /// **'A property is defined more than once'**
  String get genuiErrorDuplicateProperty;

  /// No description provided for @genuiErrorReservedName.
  ///
  /// In en, this message translates to:
  /// **'This name is reserved'**
  String get genuiErrorReservedName;

  /// No description provided for @genuiErrorUnknownComponent.
  ///
  /// In en, this message translates to:
  /// **'Unknown component {detail}'**
  String genuiErrorUnknownComponent(String detail);

  /// No description provided for @genuiErrorUnknownProperty.
  ///
  /// In en, this message translates to:
  /// **'Unknown property {detail}'**
  String genuiErrorUnknownProperty(String detail);

  /// No description provided for @genuiErrorMissingProperty.
  ///
  /// In en, this message translates to:
  /// **'Required property {detail} is missing'**
  String genuiErrorMissingProperty(String detail);

  /// No description provided for @genuiErrorBinding.
  ///
  /// In en, this message translates to:
  /// **'Invalid writable input binding'**
  String get genuiErrorBinding;

  /// No description provided for @genuiErrorReference.
  ///
  /// In en, this message translates to:
  /// **'Invalid component reference'**
  String get genuiErrorReference;

  /// No description provided for @genuiErrorMissingReference.
  ///
  /// In en, this message translates to:
  /// **'Referenced content has not been defined'**
  String get genuiErrorMissingReference;

  /// No description provided for @genuiErrorDependency.
  ///
  /// In en, this message translates to:
  /// **'Required content cannot be displayed'**
  String get genuiErrorDependency;

  /// No description provided for @genuiErrorCycle.
  ///
  /// In en, this message translates to:
  /// **'Circular references are not supported'**
  String get genuiErrorCycle;

  /// No description provided for @genuiErrorDuplicateParent.
  ///
  /// In en, this message translates to:
  /// **'A component cannot have two parents'**
  String get genuiErrorDuplicateParent;

  /// No description provided for @genuiErrorUnreachableNode.
  ///
  /// In en, this message translates to:
  /// **'This component is outside the root tree'**
  String get genuiErrorUnreachableNode;

  /// No description provided for @genuiErrorType.
  ///
  /// In en, this message translates to:
  /// **'Value has an incompatible type'**
  String get genuiErrorType;

  /// No description provided for @genuiErrorValue.
  ///
  /// In en, this message translates to:
  /// **'Value is outside the supported options or range'**
  String get genuiErrorValue;

  /// No description provided for @genuiErrorSourceBudget.
  ///
  /// In en, this message translates to:
  /// **'UI source exceeds the size limit'**
  String get genuiErrorSourceBudget;

  /// No description provided for @genuiErrorDeclarationBudget.
  ///
  /// In en, this message translates to:
  /// **'A declaration exceeds the size limit'**
  String get genuiErrorDeclarationBudget;

  /// No description provided for @genuiErrorDeclarationCount.
  ///
  /// In en, this message translates to:
  /// **'Too many declarations'**
  String get genuiErrorDeclarationCount;

  /// No description provided for @genuiErrorComponentCount.
  ///
  /// In en, this message translates to:
  /// **'Too many components'**
  String get genuiErrorComponentCount;

  /// No description provided for @genuiErrorInputCount.
  ///
  /// In en, this message translates to:
  /// **'Too many inputs'**
  String get genuiErrorInputCount;

  /// No description provided for @genuiErrorComponentDepth.
  ///
  /// In en, this message translates to:
  /// **'Components are nested too deeply'**
  String get genuiErrorComponentDepth;

  /// No description provided for @genuiErrorExpressionDepth.
  ///
  /// In en, this message translates to:
  /// **'Calculation is nested too deeply'**
  String get genuiErrorExpressionDepth;

  /// No description provided for @genuiErrorFunction.
  ///
  /// In en, this message translates to:
  /// **'Unknown calculation function'**
  String get genuiErrorFunction;

  /// No description provided for @genuiErrorAction.
  ///
  /// In en, this message translates to:
  /// **'Unsupported action'**
  String get genuiErrorAction;

  /// No description provided for @genuiErrorNestedSample.
  ///
  /// In en, this message translates to:
  /// **'Nested sampling is not supported'**
  String get genuiErrorNestedSample;

  /// No description provided for @genuiErrorSample.
  ///
  /// In en, this message translates to:
  /// **'Invalid sampling range or count'**
  String get genuiErrorSample;

  /// No description provided for @genuiErrorDataBudget.
  ///
  /// In en, this message translates to:
  /// **'Data exceeds the supported size'**
  String get genuiErrorDataBudget;

  /// No description provided for @genuiErrorRowKey.
  ///
  /// In en, this message translates to:
  /// **'Rows need unique nonempty keys'**
  String get genuiErrorRowKey;

  /// No description provided for @genuiErrorDomain.
  ///
  /// In en, this message translates to:
  /// **'The value is outside the function domain'**
  String get genuiErrorDomain;

  /// No description provided for @genuiErrorDivisionByZero.
  ///
  /// In en, this message translates to:
  /// **'Division by zero is undefined'**
  String get genuiErrorDivisionByZero;

  /// No description provided for @genuiErrorNonFinite.
  ///
  /// In en, this message translates to:
  /// **'Calculation produced a nonfinite number'**
  String get genuiErrorNonFinite;

  /// No description provided for @genuiErrorOperationsBudget.
  ///
  /// In en, this message translates to:
  /// **'Calculation exceeded the operation limit'**
  String get genuiErrorOperationsBudget;

  /// No description provided for @genuiMetricTrend.
  ///
  /// In en, this message translates to:
  /// **'Change {value}'**
  String genuiMetricTrend(String value);

  /// No description provided for @genuiFormErrorsLeft.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 field needs attention} other{{count} fields need attention}}'**
  String genuiFormErrorsLeft(int count);

  /// No description provided for @genuiFieldRequired.
  ///
  /// In en, this message translates to:
  /// **'Required'**
  String get genuiFieldRequired;

  /// No description provided for @genuiNumberRange.
  ///
  /// In en, this message translates to:
  /// **'Range {min}–{max}'**
  String genuiNumberRange(String min, String max);

  /// No description provided for @genuiNumberMinimum.
  ///
  /// In en, this message translates to:
  /// **'Minimum {min}'**
  String genuiNumberMinimum(String min);

  /// No description provided for @genuiNumberMaximum.
  ///
  /// In en, this message translates to:
  /// **'Maximum {max}'**
  String genuiNumberMaximum(String max);

  /// No description provided for @genuiFieldTooShort.
  ///
  /// In en, this message translates to:
  /// **'At least {min} characters'**
  String genuiFieldTooShort(int min);

  /// No description provided for @genuiFieldTooLong.
  ///
  /// In en, this message translates to:
  /// **'At most {max} characters'**
  String genuiFieldTooLong(int max);

  /// No description provided for @genuiInvalidNumber.
  ///
  /// In en, this message translates to:
  /// **'Enter a complete finite number'**
  String get genuiInvalidNumber;

  /// No description provided for @genuiChooseOption.
  ///
  /// In en, this message translates to:
  /// **'Choose an option'**
  String get genuiChooseOption;

  /// No description provided for @genuiFinishComposing.
  ///
  /// In en, this message translates to:
  /// **'Finish composing before continuing'**
  String get genuiFinishComposing;

  /// No description provided for @genuiActionDisabledDep.
  ///
  /// In en, this message translates to:
  /// **'Disabled: depends on {id}, which can\'t be displayed'**
  String genuiActionDisabledDep(String id);

  /// No description provided for @genuiActionUnavailable.
  ///
  /// In en, this message translates to:
  /// **'This action isn\'t available in this view'**
  String get genuiActionUnavailable;

  /// No description provided for @genuiActionDisabled.
  ///
  /// In en, this message translates to:
  /// **'Disabled by this UI'**
  String get genuiActionDisabled;

  /// No description provided for @genuiFormUnavailable.
  ///
  /// In en, this message translates to:
  /// **'This form contains content that can\'t be displayed'**
  String get genuiFormUnavailable;

  /// No description provided for @genuiDecrease.
  ///
  /// In en, this message translates to:
  /// **'Decrease {label}'**
  String genuiDecrease(String label);

  /// No description provided for @genuiIncrease.
  ///
  /// In en, this message translates to:
  /// **'Increase {label}'**
  String genuiIncrease(String label);

  /// No description provided for @genuiCharacterCount.
  ///
  /// In en, this message translates to:
  /// **'{used} / {max} characters'**
  String genuiCharacterCount(int used, int max);

  /// No description provided for @genuiBlockLimit.
  ///
  /// In en, this message translates to:
  /// **'Up to 3 UI blocks per message; the rest are shown as source'**
  String get genuiBlockLimit;

  /// No description provided for @genuiChartLine.
  ///
  /// In en, this message translates to:
  /// **'Line chart'**
  String get genuiChartLine;

  /// No description provided for @genuiChartArea.
  ///
  /// In en, this message translates to:
  /// **'Area chart'**
  String get genuiChartArea;

  /// No description provided for @genuiChartBar.
  ///
  /// In en, this message translates to:
  /// **'Bar chart'**
  String get genuiChartBar;

  /// No description provided for @genuiChartScatter.
  ///
  /// In en, this message translates to:
  /// **'Scatter plot'**
  String get genuiChartScatter;

  /// No description provided for @genuiChartPie.
  ///
  /// In en, this message translates to:
  /// **'Pie chart'**
  String get genuiChartPie;

  /// No description provided for @genuiChartDonut.
  ///
  /// In en, this message translates to:
  /// **'Donut chart'**
  String get genuiChartDonut;

  /// No description provided for @genuiChartEmpty.
  ///
  /// In en, this message translates to:
  /// **'No data in this range'**
  String get genuiChartEmpty;

  /// No description provided for @genuiChartAllHidden.
  ///
  /// In en, this message translates to:
  /// **'All series are hidden. Use the legend to show one.'**
  String get genuiChartAllHidden;

  /// No description provided for @genuiChartSummary.
  ///
  /// In en, this message translates to:
  /// **'{kind}, {series, plural, =1{1 series} other{{series} series}}, {points, plural, =1{1 data row} other{{points} data rows}}, {missing, plural, =1{1 missing value} other{{missing} missing values}} (not connected or replaced with zero).'**
  String genuiChartSummary(String kind, int series, int points, int missing);

  /// No description provided for @genuiChartPieSummary.
  ///
  /// In en, this message translates to:
  /// **'{kind}, {count, plural, =1{1 item} other{{count} items}}, total {total}.'**
  String genuiChartPieSummary(String kind, int count, String total);

  /// No description provided for @genuiChartDomainGap.
  ///
  /// In en, this message translates to:
  /// **'Undefined'**
  String get genuiChartDomainGap;

  /// No description provided for @genuiChartDomainSummary.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 sampled point is undefined} other{{count} sampled points are undefined}}; shaded gaps are not connected.'**
  String genuiChartDomainSummary(int count);

  /// No description provided for @genuiChartShowSeries.
  ///
  /// In en, this message translates to:
  /// **'Show {name}'**
  String genuiChartShowSeries(String name);

  /// No description provided for @genuiChartHideSeries.
  ///
  /// In en, this message translates to:
  /// **'Hide {name}'**
  String genuiChartHideSeries(String name);

  /// No description provided for @genuiChartKeyboardHint.
  ///
  /// In en, this message translates to:
  /// **'Left and right select a data row. Up and down select a series. Escape clears selection.'**
  String get genuiChartKeyboardHint;

  /// No description provided for @genuiChartTotal.
  ///
  /// In en, this message translates to:
  /// **'Total'**
  String get genuiChartTotal;

  /// No description provided for @genuiChartFieldsError.
  ///
  /// In en, this message translates to:
  /// **'Choose an X field and one to four distinct Y fields.'**
  String get genuiChartFieldsError;

  /// No description provided for @genuiChartRecordsError.
  ///
  /// In en, this message translates to:
  /// **'Chart data must be a list of records.'**
  String get genuiChartRecordsError;

  /// No description provided for @genuiChartXError.
  ///
  /// In en, this message translates to:
  /// **'X values must all be numbers or all be text. Scatter plots require numbers.'**
  String get genuiChartXError;

  /// No description provided for @genuiChartYError.
  ///
  /// In en, this message translates to:
  /// **'Y fields must exist and contain numbers or missing values.'**
  String get genuiChartYError;

  /// No description provided for @genuiChartPieError.
  ///
  /// In en, this message translates to:
  /// **'Pie values must be nonnegative and have a finite total greater than zero.'**
  String get genuiChartPieError;

  /// No description provided for @genuiChartMissingValues.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 value is missing; it is not replaced with zero.} other{{count} values are missing; they are not replaced with zero.}}'**
  String genuiChartMissingValues(int count);

  /// No description provided for @genuiChartNoVisibleValues.
  ///
  /// In en, this message translates to:
  /// **'The selected series have no values to plot.'**
  String get genuiChartNoVisibleValues;

  /// No description provided for @genuiChartUnit.
  ///
  /// In en, this message translates to:
  /// **'Unit: {unit}'**
  String genuiChartUnit(String unit);

  /// No description provided for @genuiSomeValuesUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Some values are unavailable'**
  String get genuiSomeValuesUnavailable;

  /// No description provided for @genuiViewChart.
  ///
  /// In en, this message translates to:
  /// **'Chart'**
  String get genuiViewChart;

  /// No description provided for @genuiViewData.
  ///
  /// In en, this message translates to:
  /// **'Data'**
  String get genuiViewData;

  /// No description provided for @genuiTableFilterHint.
  ///
  /// In en, this message translates to:
  /// **'Filter visible text'**
  String get genuiTableFilterHint;

  /// No description provided for @genuiTableRows.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 row} other{{count} rows}}'**
  String genuiTableRows(int count);

  /// No description provided for @genuiTablePageInfo.
  ///
  /// In en, this message translates to:
  /// **'Rows {from}–{to} of {total}'**
  String genuiTablePageInfo(int from, int to, int total);

  /// No description provided for @genuiTablePerPage.
  ///
  /// In en, this message translates to:
  /// **'{n}/page'**
  String genuiTablePerPage(int n);

  /// No description provided for @genuiTableEmpty.
  ///
  /// In en, this message translates to:
  /// **'No matching rows'**
  String get genuiTableEmpty;

  /// No description provided for @genuiSortAsc.
  ///
  /// In en, this message translates to:
  /// **'Sorted ascending'**
  String get genuiSortAsc;

  /// No description provided for @genuiSortDesc.
  ///
  /// In en, this message translates to:
  /// **'Sorted descending'**
  String get genuiSortDesc;

  /// No description provided for @genuiSortNone.
  ///
  /// In en, this message translates to:
  /// **'Not sorted'**
  String get genuiSortNone;

  /// No description provided for @genuiValueTrue.
  ///
  /// In en, this message translates to:
  /// **'True'**
  String get genuiValueTrue;

  /// No description provided for @genuiValueFalse.
  ///
  /// In en, this message translates to:
  /// **'False'**
  String get genuiValueFalse;

  /// No description provided for @genuiTablePreviousPage.
  ///
  /// In en, this message translates to:
  /// **'Previous page'**
  String get genuiTablePreviousPage;

  /// No description provided for @genuiTableNextPage.
  ///
  /// In en, this message translates to:
  /// **'Next page'**
  String get genuiTableNextPage;

  /// No description provided for @genuiTableCellsError.
  ///
  /// In en, this message translates to:
  /// **'Table data must contain records with finite scalar values or missing values.'**
  String get genuiTableCellsError;

  /// No description provided for @genuiTableColumnsError.
  ///
  /// In en, this message translates to:
  /// **'Choose one to eight distinct fields with labels and optional digits from 0 to 10.'**
  String get genuiTableColumnsError;

  /// No description provided for @genuiTableRowKeyError.
  ///
  /// In en, this message translates to:
  /// **'Every row needs a non-null scalar key.'**
  String get genuiTableRowKeyError;

  /// No description provided for @genuiViewStateFailed.
  ///
  /// In en, this message translates to:
  /// **'This view change exceeds the saved state limit. Shorten a field or reset the UI and try again.'**
  String get genuiViewStateFailed;

  /// No description provided for @genuiAttachState.
  ///
  /// In en, this message translates to:
  /// **'Attach current state'**
  String get genuiAttachState;

  /// No description provided for @genuiChipExactText.
  ///
  /// In en, this message translates to:
  /// **'Exact text to be sent (frozen)'**
  String get genuiChipExactText;

  /// No description provided for @genuiChipStale.
  ///
  /// In en, this message translates to:
  /// **'Source unavailable — remove or attach again'**
  String get genuiChipStale;

  /// No description provided for @genuiChipRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove attached UI'**
  String get genuiChipRemove;

  /// No description provided for @genuiReplaceTitle.
  ///
  /// In en, this message translates to:
  /// **'Replace attached UI?'**
  String get genuiReplaceTitle;

  /// No description provided for @genuiReplaceBody.
  ///
  /// In en, this message translates to:
  /// **'A draft can carry one UI state.'**
  String get genuiReplaceBody;

  /// No description provided for @genuiReplaceCurrent.
  ///
  /// In en, this message translates to:
  /// **'Current'**
  String get genuiReplaceCurrent;

  /// No description provided for @genuiReplaceNew.
  ///
  /// In en, this message translates to:
  /// **'Replace with'**
  String get genuiReplaceNew;

  /// No description provided for @genuiReplaceConfirm.
  ///
  /// In en, this message translates to:
  /// **'Replace'**
  String get genuiReplaceConfirm;

  /// No description provided for @genuiMergeTitle.
  ///
  /// In en, this message translates to:
  /// **'Add to your draft?'**
  String get genuiMergeTitle;

  /// No description provided for @genuiMergeConfirm.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get genuiMergeConfirm;

  /// No description provided for @genuiContextEmpty.
  ///
  /// In en, this message translates to:
  /// **'No parameter or result fields are attached.'**
  String get genuiContextEmpty;

  /// No description provided for @genuiContextOmitted.
  ///
  /// In en, this message translates to:
  /// **'[Some fields or data rows are omitted.]'**
  String get genuiContextOmitted;

  /// No description provided for @genuiChipOmitted.
  ///
  /// In en, this message translates to:
  /// **'The previously attached UI state is unavailable and was not included.'**
  String get genuiChipOmitted;

  /// No description provided for @genuiDraftChanged.
  ///
  /// In en, this message translates to:
  /// **'Your draft changed. Try attaching again.'**
  String get genuiDraftChanged;

  /// No description provided for @genuiRepairDraft.
  ///
  /// In en, this message translates to:
  /// **'Please repair this interface using the diagnostics and source excerpts below.'**
  String get genuiRepairDraft;

  /// No description provided for @genuiCopySourceMarkdown.
  ///
  /// In en, this message translates to:
  /// **'Copy source / Markdown'**
  String get genuiCopySourceMarkdown;

  /// No description provided for @genuiTextFailed.
  ///
  /// In en, this message translates to:
  /// **'The interface state could not be read. Try again.'**
  String get genuiTextFailed;

  /// No description provided for @genuiCopyLimit.
  ///
  /// In en, this message translates to:
  /// **'Text exceeds the 64 KiB copy limit. Select a smaller section.'**
  String get genuiCopyLimit;

  /// No description provided for @genuiExportSnapshot.
  ///
  /// In en, this message translates to:
  /// **'Export read-only snapshot'**
  String get genuiExportSnapshot;

  /// No description provided for @genuiExpandedSharedState.
  ///
  /// In en, this message translates to:
  /// **'Shares the same state as the message'**
  String get genuiExpandedSharedState;

  /// No description provided for @genuiExportTooLarge.
  ///
  /// In en, this message translates to:
  /// **'This image exceeds 16 megapixels. Select fewer messages or export a smaller UI.'**
  String get genuiExportTooLarge;

  /// No description provided for @genuiWebTitle.
  ///
  /// In en, this message translates to:
  /// **'Web preview'**
  String get genuiWebTitle;

  /// No description provided for @genuiWebOpen.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get genuiWebOpen;

  /// No description provided for @genuiWebNotReady.
  ///
  /// In en, this message translates to:
  /// **'Can be opened after generation finishes'**
  String get genuiWebNotReady;

  /// No description provided for @genuiWebInvalidMeta.
  ///
  /// In en, this message translates to:
  /// **'Invalid header; not loaded'**
  String get genuiWebInvalidMeta;

  /// No description provided for @genuiWebSandboxNote.
  ///
  /// In en, this message translates to:
  /// **'Sandboxed preview · discarded on close'**
  String get genuiWebSandboxNote;

  /// No description provided for @genuiWebUnsupported.
  ///
  /// In en, this message translates to:
  /// **'Web previews aren\'t supported on this platform. Export to open in a browser.'**
  String get genuiWebUnsupported;

  /// No description provided for @genuiWebExportHtml.
  ///
  /// In en, this message translates to:
  /// **'Export HTML'**
  String get genuiWebExportHtml;

  /// No description provided for @genuiWebInfo.
  ///
  /// In en, this message translates to:
  /// **'Preview information'**
  String get genuiWebInfo;

  /// No description provided for @genuiWebCspNote.
  ///
  /// In en, this message translates to:
  /// **'CSP: default-src \'none\' · Restricted network access · Isolated page state'**
  String get genuiWebCspNote;

  /// No description provided for @genuiWebFailed.
  ///
  /// In en, this message translates to:
  /// **'Preview initialization or loading failed. View or copy its source.'**
  String get genuiWebFailed;

  /// No description provided for @genuiWebEmpty.
  ///
  /// In en, this message translates to:
  /// **'No HTML document after the header'**
  String get genuiWebEmpty;

  /// No description provided for @genuiWebBlockLimit.
  ///
  /// In en, this message translates to:
  /// **'Up to 3 web previews per message; the rest are shown as source'**
  String get genuiWebBlockLimit;

  /// No description provided for @genuiWebCloseFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t confirm the previous preview closed. Restart the app before opening another.'**
  String get genuiWebCloseFailed;

  /// No description provided for @displaySettingsShowGenUiHeader.
  ///
  /// In en, this message translates to:
  /// **'Show interactive UI title bar'**
  String get displaySettingsShowGenUiHeader;

  /// No description provided for @displaySettingsShowGenUiHeaderSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Hide for a cleaner message. Source and actions remain in the menu below the UI.'**
  String get displaySettingsShowGenUiHeaderSubtitle;

  /// No description provided for @genuiClearFilter.
  ///
  /// In en, this message translates to:
  /// **'Clear filter'**
  String get genuiClearFilter;

  /// No description provided for @genuiClearSelection.
  ///
  /// In en, this message translates to:
  /// **'Clear selection'**
  String get genuiClearSelection;

  /// No description provided for @chatInputBarQueuedPausedReason.
  ///
  /// In en, this message translates to:
  /// **'Compression did not finish; sending stays paused'**
  String get chatInputBarQueuedPausedReason;

  /// No description provided for @contextChanged.
  ///
  /// In en, this message translates to:
  /// **'History changed. Reopen this action to review its current scope.'**
  String get contextChanged;

  /// No description provided for @contextOperationSuperseded.
  ///
  /// In en, this message translates to:
  /// **'Included in a later summary'**
  String get contextOperationSuperseded;

  /// No description provided for @compressIncludeAttachments.
  ///
  /// In en, this message translates to:
  /// **'Attachment text & tool results'**
  String get compressIncludeAttachments;

  /// No description provided for @contextEditCharacters.
  ///
  /// In en, this message translates to:
  /// **'{count} characters'**
  String contextEditCharacters(int count);

  /// No description provided for @compressOverSnack.
  ///
  /// In en, this message translates to:
  /// **'The summary would exceed the context limit and was not applied.'**
  String get compressOverSnack;

  /// No description provided for @contextSummaryHint.
  ///
  /// In en, this message translates to:
  /// **'This is the summary used in subsequent requests. Saving changes does not rewrite existing replies. Attachments contribute only available text; images are not reinterpreted.'**
  String get contextSummaryHint;

  /// No description provided for @compressAdvanced.
  ///
  /// In en, this message translates to:
  /// **'Advanced'**
  String get compressAdvanced;

  /// No description provided for @compressTaskWaiting.
  ///
  /// In en, this message translates to:
  /// **'Waiting for the current reply'**
  String get compressTaskWaiting;

  /// No description provided for @contextBudgetExceeded.
  ///
  /// In en, this message translates to:
  /// **'The estimated context exceeds this model’s limit. Shorten the summary, compress again, or choose a model with a larger context.'**
  String get contextBudgetExceeded;

  /// No description provided for @contextManualSupplement.
  ///
  /// In en, this message translates to:
  /// **'Include manually edited summaries as supplements'**
  String get contextManualSupplement;

  /// No description provided for @contextDetailEdited.
  ///
  /// In en, this message translates to:
  /// **'Manually edited'**
  String get contextDetailEdited;

  /// No description provided for @contextSourceLabel.
  ///
  /// In en, this message translates to:
  /// **'Summary input'**
  String get contextSourceLabel;

  /// No description provided for @contextImpactSourceTitle.
  ///
  /// In en, this message translates to:
  /// **'Change compressed originals?'**
  String get contextImpactSourceTitle;

  /// No description provided for @chatInputBarQueuedCompressionFailed.
  ///
  /// In en, this message translates to:
  /// **'Compression failed; sending stays paused'**
  String get chatInputBarQueuedCompressionFailed;

  /// No description provided for @contextTokenInfo.
  ///
  /// In en, this message translates to:
  /// **'Summary input ≈ {before} tokens → summary ≈ {after} tokens'**
  String contextTokenInfo(int before, int after);

  /// No description provided for @worldBookTransferFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not save the entries. Please try again.'**
  String get worldBookTransferFailed;

  /// No description provided for @contextDetailKeptCount.
  ///
  /// In en, this message translates to:
  /// **'Latest {count} user messages, replies and tools'**
  String contextDetailKeptCount(int count);

  /// No description provided for @toolPermissionRequestApproval.
  ///
  /// In en, this message translates to:
  /// **'Ask for approval'**
  String get toolPermissionRequestApproval;

  /// No description provided for @compressNothingNew.
  ///
  /// In en, this message translates to:
  /// **'Nothing new to compress since the last summary'**
  String get compressNothingNew;

  /// No description provided for @browserActionScreenshot.
  ///
  /// In en, this message translates to:
  /// **'Capture screenshot'**
  String get browserActionScreenshot;

  /// No description provided for @displaySettingsPageIosNativeSelectionMenuSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Applies to input and messages. Turn off if menus feel slow.'**
  String get displaySettingsPageIosNativeSelectionMenuSubtitle;

  /// No description provided for @contextUndoneSnack.
  ///
  /// In en, this message translates to:
  /// **'Undone · {from} → {to}'**
  String contextUndoneSnack(String from, String to);

  /// No description provided for @toolApprovalByFullAccess.
  ///
  /// In en, this message translates to:
  /// **'Ran automatically'**
  String get toolApprovalByFullAccess;

  /// No description provided for @displaySettingsPageAutoScrollSubtitle.
  ///
  /// In en, this message translates to:
  /// **'While streaming, follow new content when at the bottom. Scrolling up pauses following until you return to the bottom. When off, new content does not scroll automatically.'**
  String get displaySettingsPageAutoScrollSubtitle;

  /// No description provided for @toolApprovalRealTarget.
  ///
  /// In en, this message translates to:
  /// **'Actual target'**
  String get toolApprovalRealTarget;

  /// No description provided for @compressTaskRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get compressTaskRetry;

  /// No description provided for @wsDeniedPathOutside.
  ///
  /// In en, this message translates to:
  /// **'Target is outside the authorized area. Denied.'**
  String get wsDeniedPathOutside;

  /// No description provided for @contextImpactSaveConfirm.
  ///
  /// In en, this message translates to:
  /// **'Save and undo {count} nodes'**
  String contextImpactSaveConfirm(int count);

  /// No description provided for @contextRestore.
  ///
  /// In en, this message translates to:
  /// **'Restore'**
  String get contextRestore;

  /// No description provided for @compressUsageOriginal.
  ///
  /// In en, this message translates to:
  /// **'was {value}'**
  String compressUsageOriginal(String value);

  /// No description provided for @toolApprovalPendingKind.
  ///
  /// In en, this message translates to:
  /// **'Awaiting approval · {kind}'**
  String toolApprovalPendingKind(String kind);

  /// No description provided for @contextTaskApplying.
  ///
  /// In en, this message translates to:
  /// **'Applying summary'**
  String get contextTaskApplying;

  /// No description provided for @storageSpaceImagesHint.
  ///
  /// In en, this message translates to:
  /// **'Deleting images affects chat history and tool results. Avatars and backgrounds in use are protected.'**
  String get storageSpaceImagesHint;

  /// No description provided for @displaySettingsPageIosNativeSelectionMenuTitle.
  ///
  /// In en, this message translates to:
  /// **'iOS 26+ native selection menu'**
  String get displaySettingsPageIosNativeSelectionMenuTitle;

  /// No description provided for @worldBookMoveEntries.
  ///
  /// In en, this message translates to:
  /// **'Move to…'**
  String get worldBookMoveEntries;

  /// No description provided for @compressReread.
  ///
  /// In en, this message translates to:
  /// **'Re-read compressed originals'**
  String get compressReread;

  /// No description provided for @chatInputBarQueuedPausedHold.
  ///
  /// In en, this message translates to:
  /// **'Input remains paused; cancel the queue to edit or send'**
  String get chatInputBarQueuedPausedHold;

  /// No description provided for @contextSummaryTitle.
  ///
  /// In en, this message translates to:
  /// **'Context summary'**
  String get contextSummaryTitle;

  /// No description provided for @contextKeepInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter a positive number of user messages.'**
  String get contextKeepInvalid;

  /// No description provided for @compressTaskAbandon.
  ///
  /// In en, this message translates to:
  /// **'Dismiss'**
  String get compressTaskAbandon;

  /// No description provided for @browserAgentTimedOut.
  ///
  /// In en, this message translates to:
  /// **'Operation timed out; AI paused'**
  String get browserAgentTimedOut;

  /// No description provided for @compressCancelledSnack.
  ///
  /// In en, this message translates to:
  /// **'Compression cancelled. Current context is unchanged.'**
  String get compressCancelledSnack;

  /// No description provided for @contextImpactClearTitle.
  ///
  /// In en, this message translates to:
  /// **'Undo earlier clear?'**
  String get contextImpactClearTitle;

  /// No description provided for @compressTaskWaitingApproval.
  ///
  /// In en, this message translates to:
  /// **'Waiting for tool approval'**
  String get compressTaskWaitingApproval;

  /// No description provided for @contextTaskFailed.
  ///
  /// In en, this message translates to:
  /// **'Compression failed'**
  String get contextTaskFailed;

  /// No description provided for @wsDeniedSkillsReadonly.
  ///
  /// In en, this message translates to:
  /// **'Skills folder is read-only.'**
  String get wsDeniedSkillsReadonly;

  /// No description provided for @compressTaskMerging.
  ///
  /// In en, this message translates to:
  /// **'Merging summaries'**
  String get compressTaskMerging;

  /// No description provided for @toolPermissionFullAccessDesc.
  ///
  /// In en, this message translates to:
  /// **'Lets this conversation access files on this device, run commands, and use enabled online tools without asking each time.'**
  String get toolPermissionFullAccessDesc;

  /// No description provided for @compressStaleSnack.
  ///
  /// In en, this message translates to:
  /// **'Chat history changed; the summary was not applied.'**
  String get compressStaleSnack;

  /// No description provided for @worldBookCopyEntries.
  ///
  /// In en, this message translates to:
  /// **'Copy to…'**
  String get worldBookCopyEntries;

  /// No description provided for @contextEditEmpty.
  ///
  /// In en, this message translates to:
  /// **'Summary cannot be empty. Use Clear context to exclude all earlier history.'**
  String get contextEditEmpty;

  /// No description provided for @toolApprovalDenyWithReason.
  ///
  /// In en, this message translates to:
  /// **'Deny with reason…'**
  String get toolApprovalDenyWithReason;

  /// No description provided for @toolApprovalRequestedPath.
  ///
  /// In en, this message translates to:
  /// **'Requested path'**
  String get toolApprovalRequestedPath;

  /// No description provided for @toolApprovalScopeOnce.
  ///
  /// In en, this message translates to:
  /// **'Applies to this call only'**
  String get toolApprovalScopeOnce;

  /// No description provided for @storageSpaceImageTypeLabel.
  ///
  /// In en, this message translates to:
  /// **'Type'**
  String get storageSpaceImageTypeLabel;

  /// No description provided for @contextImpactUndoTitle.
  ///
  /// In en, this message translates to:
  /// **'Undo earlier compression?'**
  String get contextImpactUndoTitle;

  /// No description provided for @contextOriginalMessages.
  ///
  /// In en, this message translates to:
  /// **'View original messages'**
  String get contextOriginalMessages;

  /// No description provided for @storageSpaceDeleteImagesConfirmMessage.
  ///
  /// In en, this message translates to:
  /// **'Delete {count} images? Related chat images, tool screenshots, and conversation copies will no longer be available. Avatars and backgrounds in use will be kept.'**
  String storageSpaceDeleteImagesConfirmMessage(int count);

  /// No description provided for @chatInputBarQueuedAfterCompress.
  ///
  /// In en, this message translates to:
  /// **'Sends after compression'**
  String get chatInputBarQueuedAfterCompress;

  /// No description provided for @toolPermissionFullAccessDescMobile.
  ///
  /// In en, this message translates to:
  /// **'Lets this conversation run tools automatically inside the sandbox and authorized folders, without asking each time.'**
  String get toolPermissionFullAccessDescMobile;

  /// No description provided for @compressTaskAdjustRetry.
  ///
  /// In en, this message translates to:
  /// **'Adjust options and retry'**
  String get compressTaskAdjustRetry;

  /// No description provided for @contextDetailLegacy.
  ///
  /// In en, this message translates to:
  /// **'Converted from legacy clear'**
  String get contextDetailLegacy;

  /// No description provided for @contextDetailCurrent.
  ///
  /// In en, this message translates to:
  /// **'Current context'**
  String get contextDetailCurrent;

  /// No description provided for @toolPermissionUndo.
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get toolPermissionUndo;

  /// No description provided for @contextDetailViewOriginals.
  ///
  /// In en, this message translates to:
  /// **'View originals'**
  String get contextDetailViewOriginals;

  /// No description provided for @contextTaskCompleted.
  ///
  /// In en, this message translates to:
  /// **'Compression complete'**
  String get contextTaskCompleted;

  /// No description provided for @chatInputBarQueuedPaused.
  ///
  /// In en, this message translates to:
  /// **'Paused'**
  String get chatInputBarQueuedPaused;

  /// No description provided for @contextCompressMarker.
  ///
  /// In en, this message translates to:
  /// **'Context compressed'**
  String get contextCompressMarker;

  /// No description provided for @contextDetailParts.
  ///
  /// In en, this message translates to:
  /// **'{count} segments'**
  String contextDetailParts(int count);

  /// No description provided for @contextEditPending.
  ///
  /// In en, this message translates to:
  /// **'Saved; applies after the current reply'**
  String get contextEditPending;

  /// No description provided for @contextTaskRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry compression'**
  String get contextTaskRetry;

  /// No description provided for @contextUndoCompressTooltip.
  ///
  /// In en, this message translates to:
  /// **'Undo this compression'**
  String get contextUndoCompressTooltip;

  /// No description provided for @contextDividerCompressed.
  ///
  /// In en, this message translates to:
  /// **'Context compressed'**
  String get contextDividerCompressed;

  /// No description provided for @compressSuccessSnack.
  ///
  /// In en, this message translates to:
  /// **'Context compressed · {from} → {to}'**
  String compressSuccessSnack(String from, String to);

  /// No description provided for @contextEffectiveHistory.
  ///
  /// In en, this message translates to:
  /// **'Current summary and later messages'**
  String get contextEffectiveHistory;

  /// No description provided for @compressRereadAll.
  ///
  /// In en, this message translates to:
  /// **'All originals in segment'**
  String get compressRereadAll;

  /// No description provided for @contextDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get contextDone;

  /// No description provided for @contextMore.
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get contextMore;

  /// No description provided for @compressFailedSnack.
  ///
  /// In en, this message translates to:
  /// **'Compression failed: {reason}'**
  String compressFailedSnack(String reason);

  /// No description provided for @branchInheritNote.
  ///
  /// In en, this message translates to:
  /// **'Only inherits context nodes active before this point'**
  String get branchInheritNote;

  /// No description provided for @contextTaskInterrupted.
  ///
  /// In en, this message translates to:
  /// **'Compression interrupted; input is preserved'**
  String get contextTaskInterrupted;

  /// No description provided for @storageSpaceImageTypeAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get storageSpaceImageTypeAll;

  /// No description provided for @contextRangeInfo.
  ///
  /// In en, this message translates to:
  /// **'Replaces {count} messages; keeps {keep} recent user messages and their replies.'**
  String contextRangeInfo(int count, int keep);

  /// No description provided for @contextInputModeInfo.
  ///
  /// In en, this message translates to:
  /// **'Input: {mode} · {source}'**
  String contextInputModeInfo(String mode, String source);

  /// No description provided for @contextDetailKept.
  ///
  /// In en, this message translates to:
  /// **'Kept'**
  String get contextDetailKept;

  /// No description provided for @worldBookEntriesCopied.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Copied 1 entry} other{Copied {count} entries}}'**
  String worldBookEntriesCopied(int count);

  /// No description provided for @toolPermissionSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn’t save. Permission unchanged.'**
  String get toolPermissionSaveFailed;

  /// No description provided for @compressDiscardedSnack.
  ///
  /// In en, this message translates to:
  /// **'Context cleared; the running compression was discarded.'**
  String get compressDiscardedSnack;

  /// No description provided for @browserActionSelect.
  ///
  /// In en, this message translates to:
  /// **'Select option'**
  String get browserActionSelect;

  /// No description provided for @toolPermissionTitle.
  ///
  /// In en, this message translates to:
  /// **'Permissions'**
  String get toolPermissionTitle;

  /// No description provided for @contextDetailNext.
  ///
  /// In en, this message translates to:
  /// **'Next request'**
  String get contextDetailNext;

  /// No description provided for @contextTaskCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel compression'**
  String get contextTaskCancel;

  /// No description provided for @toolPermissionFullAccess.
  ///
  /// In en, this message translates to:
  /// **'Full access'**
  String get toolPermissionFullAccess;

  /// No description provided for @chatInputBarQueuedCompressionCancelled.
  ///
  /// In en, this message translates to:
  /// **'Compression cancelled; sending stays paused'**
  String get chatInputBarQueuedCompressionCancelled;

  /// No description provided for @toolPermissionResetSnack.
  ///
  /// In en, this message translates to:
  /// **'Workspace changed · permission reset to Ask for approval'**
  String get toolPermissionResetSnack;

  /// No description provided for @contextImpactUndoOne.
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get contextImpactUndoOne;

  /// No description provided for @contextDetailContinueNewChat.
  ///
  /// In en, this message translates to:
  /// **'Continue in new chat'**
  String get contextDetailContinueNewChat;

  /// No description provided for @contextTaskPaused.
  ///
  /// In en, this message translates to:
  /// **'Sending paused — cancel the queue to edit'**
  String get contextTaskPaused;

  /// No description provided for @contextTaskReview.
  ///
  /// In en, this message translates to:
  /// **'Review the summary before applying'**
  String get contextTaskReview;

  /// No description provided for @compressApproxTokens.
  ///
  /// In en, this message translates to:
  /// **'Approx. {value} tokens'**
  String compressApproxTokens(String value);

  /// No description provided for @storageSpaceImageInUseHint.
  ///
  /// In en, this message translates to:
  /// **'Change or remove this avatar, background, or icon in its settings before deleting it.'**
  String get storageSpaceImageInUseHint;

  /// No description provided for @compressRereadLastLayer.
  ///
  /// In en, this message translates to:
  /// **'Expand last layer'**
  String get compressRereadLastLayer;

  /// No description provided for @contextRestoreOperation.
  ///
  /// In en, this message translates to:
  /// **'Restore operation'**
  String get contextRestoreOperation;

  /// No description provided for @contextOriginalHistory.
  ///
  /// In en, this message translates to:
  /// **'Re-read all original messages in this segment'**
  String get contextOriginalHistory;

  /// No description provided for @contextImpactEditTitle.
  ///
  /// In en, this message translates to:
  /// **'Save earlier summary?'**
  String get contextImpactEditTitle;

  /// No description provided for @contextOpenNewChat.
  ///
  /// In en, this message translates to:
  /// **'Open new chat'**
  String get contextOpenNewChat;

  /// No description provided for @wsPathChanged.
  ///
  /// In en, this message translates to:
  /// **'Target changed while awaiting approval.'**
  String get wsPathChanged;

  /// No description provided for @contextEditUnknownPreview.
  ///
  /// In en, this message translates to:
  /// **'Usage is unavailable; it will be checked again before saving.'**
  String get contextEditUnknownPreview;

  /// No description provided for @contextTaskWait.
  ///
  /// In en, this message translates to:
  /// **'Waiting for the current reply and tools to finish'**
  String get contextTaskWait;

  /// No description provided for @compressTaskElapsed.
  ///
  /// In en, this message translates to:
  /// **'Part {i}/{n} · {seconds}s elapsed'**
  String compressTaskElapsed(int i, int n, int seconds);

  /// No description provided for @wsContextChanged.
  ///
  /// In en, this message translates to:
  /// **'Conversation context changed. Request expired.'**
  String get wsContextChanged;

  /// No description provided for @contextChangeImpact.
  ///
  /// In en, this message translates to:
  /// **'This change will also undo {count} affected context operations. Original messages are kept. Continue?'**
  String contextChangeImpact(int count);

  /// No description provided for @contextImpactSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get contextImpactSave;

  /// No description provided for @contextTaskProgress.
  ///
  /// In en, this message translates to:
  /// **'Compressing {done}/{total} segments'**
  String contextTaskProgress(int done, int total);

  /// No description provided for @contextSummaryNotSmaller.
  ///
  /// In en, this message translates to:
  /// **'The summary is not shorter than its input. Review it before applying.'**
  String get contextSummaryNotSmaller;

  /// No description provided for @storageSpaceImageTypeTool.
  ///
  /// In en, this message translates to:
  /// **'Tool images'**
  String get storageSpaceImageTypeTool;

  /// No description provided for @contextPreviousHistory.
  ///
  /// In en, this message translates to:
  /// **'Re-read the last compression layer'**
  String get contextPreviousHistory;

  /// No description provided for @contextDetailRead.
  ///
  /// In en, this message translates to:
  /// **'Read'**
  String get contextDetailRead;

  /// No description provided for @contextViewGenerated.
  ///
  /// In en, this message translates to:
  /// **'View generated summary'**
  String get contextViewGenerated;

  /// No description provided for @contextImpactDeleteDescription.
  ///
  /// In en, this message translates to:
  /// **'Delete the originals and undo related summaries so removed content is not sent again. Other messages and independent nodes are unchanged.'**
  String get contextImpactDeleteDescription;

  /// No description provided for @storageSpaceImageTypeAvatar.
  ///
  /// In en, this message translates to:
  /// **'Avatars & backgrounds'**
  String get storageSpaceImageTypeAvatar;

  /// No description provided for @contextDetailAfterUndo.
  ///
  /// In en, this message translates to:
  /// **'After undo'**
  String get contextDetailAfterUndo;

  /// No description provided for @contextOperationUndo.
  ///
  /// In en, this message translates to:
  /// **'Undo this context operation'**
  String get contextOperationUndo;

  /// No description provided for @contextHistoryWindowNote.
  ///
  /// In en, this message translates to:
  /// **'Recent history is still limited by the chat’s {count}-message sending window.'**
  String contextHistoryWindowNote(int count);

  /// No description provided for @contextOverLimitWarning.
  ///
  /// In en, this message translates to:
  /// **'Undo may exceed the context limit. You can still undo and recompress; sending checks the limit again.'**
  String get contextOverLimitWarning;

  /// No description provided for @storageSpaceImageTypeChat.
  ///
  /// In en, this message translates to:
  /// **'Chat images'**
  String get storageSpaceImageTypeChat;

  /// No description provided for @worldBookSelectEntries.
  ///
  /// In en, this message translates to:
  /// **'Select entries'**
  String get worldBookSelectEntries;

  /// No description provided for @compressUsageSummary.
  ///
  /// In en, this message translates to:
  /// **'Est. summary'**
  String get compressUsageSummary;

  /// No description provided for @contextDetailRange.
  ///
  /// In en, this message translates to:
  /// **'Messages {from}–{to} · {count} user messages'**
  String contextDetailRange(String from, String to, int count);

  /// No description provided for @contextOperationHidden.
  ///
  /// In en, this message translates to:
  /// **'Excluded by a later clear'**
  String get contextOperationHidden;

  /// No description provided for @contextUndoClearTooltip.
  ///
  /// In en, this message translates to:
  /// **'Undo this clear'**
  String get contextUndoClearTooltip;

  /// No description provided for @compressKeepDescription.
  ///
  /// In en, this message translates to:
  /// **'Keep the latest {count} user messages with their replies and tools. Earlier history is summarized; attachment-only messages also count.'**
  String compressKeepDescription(int count);

  /// No description provided for @contextOperationUndone.
  ///
  /// In en, this message translates to:
  /// **'Undone'**
  String get contextOperationUndone;

  /// No description provided for @contextEditPreview.
  ///
  /// In en, this message translates to:
  /// **'Approx. {value} tokens after saving. Editing does not change active context.'**
  String contextEditPreview(String value);

  /// No description provided for @contextDetailExcluded.
  ///
  /// In en, this message translates to:
  /// **'Excluded history'**
  String get contextDetailExcluded;

  /// No description provided for @worldBookNoMoveTargets.
  ///
  /// In en, this message translates to:
  /// **'Create another world book to move entries into it.'**
  String get worldBookNoMoveTargets;

  /// No description provided for @worldBookSelectedEntries.
  ///
  /// In en, this message translates to:
  /// **'{count} selected'**
  String worldBookSelectedEntries(int count);

  /// No description provided for @contextDetailReplaced.
  ///
  /// In en, this message translates to:
  /// **'Replaced'**
  String get contextDetailReplaced;

  /// No description provided for @displaySettingsPageAutoScrollEnabledLabel.
  ///
  /// In en, this message translates to:
  /// **'On'**
  String get displaySettingsPageAutoScrollEnabledLabel;

  /// No description provided for @contextChangeTitle.
  ///
  /// In en, this message translates to:
  /// **'Review affected context'**
  String get contextChangeTitle;

  /// No description provided for @contextDetailTitle.
  ///
  /// In en, this message translates to:
  /// **'Summary'**
  String get contextDetailTitle;

  /// No description provided for @compressModelGlobal.
  ///
  /// In en, this message translates to:
  /// **'Global setting · fixed when started'**
  String get compressModelGlobal;

  /// No description provided for @wsDeniedMountReadonly.
  ///
  /// In en, this message translates to:
  /// **'Read-only mount. Can’t write.'**
  String get wsDeniedMountReadonly;

  /// No description provided for @compressRereadDesc.
  ///
  /// In en, this message translates to:
  /// **'Recover details lost across summaries. Uses more tokens.'**
  String get compressRereadDesc;

  /// No description provided for @toolApprovalSwitchToFullAccess.
  ///
  /// In en, this message translates to:
  /// **'Switch to full access'**
  String get toolApprovalSwitchToFullAccess;

  /// No description provided for @compressUsageInput.
  ///
  /// In en, this message translates to:
  /// **'Summary input'**
  String get compressUsageInput;

  /// No description provided for @contextDetailSummaryLabel.
  ///
  /// In en, this message translates to:
  /// **'Summary used in later requests'**
  String get contextDetailSummaryLabel;

  /// No description provided for @contextImpactDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete compressed originals?'**
  String get contextImpactDeleteTitle;

  /// No description provided for @compressAdvancedOff.
  ///
  /// In en, this message translates to:
  /// **'Re-read originals off'**
  String get compressAdvancedOff;

  /// No description provided for @contextOperationActive.
  ///
  /// In en, this message translates to:
  /// **'Currently applied'**
  String get contextOperationActive;

  /// No description provided for @compressAdvancedOn.
  ///
  /// In en, this message translates to:
  /// **'Re-read originals on'**
  String get compressAdvancedOn;

  /// No description provided for @contextTaskMerging.
  ///
  /// In en, this message translates to:
  /// **'Merging summaries'**
  String get contextTaskMerging;

  /// No description provided for @contextSampledInfo.
  ///
  /// In en, this message translates to:
  /// **'Only the selected {count} characters were read; the summary replaces the entire selected history range.'**
  String contextSampledInfo(int count);

  /// No description provided for @contextDividerRunning.
  ///
  /// In en, this message translates to:
  /// **'Compressing context'**
  String get contextDividerRunning;

  /// No description provided for @contextClearDetails.
  ///
  /// In en, this message translates to:
  /// **'Earlier chat history is excluded from future requests. System instructions, memory and tool definitions still apply.'**
  String get contextClearDetails;

  /// No description provided for @compressCopyResult.
  ///
  /// In en, this message translates to:
  /// **'Copy result'**
  String get compressCopyResult;

  /// No description provided for @contextDetailInUse.
  ///
  /// In en, this message translates to:
  /// **'In use'**
  String get contextDetailInUse;

  /// No description provided for @contextImpactDescription.
  ///
  /// In en, this message translates to:
  /// **'Related summaries will be undone together. Original messages and independent nodes are kept; no model is called automatically.'**
  String get contextImpactDescription;

  /// No description provided for @compressIncludeAttachmentsDesc.
  ///
  /// In en, this message translates to:
  /// **'Include available attachment text and bounded tool records. Truncation is marked; images are not reinterpreted.'**
  String get compressIncludeAttachmentsDesc;

  /// No description provided for @worldBookEntriesMoved.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Moved 1 entry} other{Moved {count} entries}}'**
  String worldBookEntriesMoved(int count);

  /// No description provided for @contextImpactSourceDescription.
  ///
  /// In en, this message translates to:
  /// **'Change the originals and undo their summaries and dependent nodes together. Other messages and independent nodes are kept; no model is called.'**
  String get contextImpactSourceDescription;

  /// No description provided for @contextEditTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit summary'**
  String get contextEditTitle;

  /// No description provided for @compressUsageNext.
  ///
  /// In en, this message translates to:
  /// **'Next request'**
  String get compressUsageNext;

  /// No description provided for @contextSummaryEmpty.
  ///
  /// In en, this message translates to:
  /// **'The summary cannot be empty. Use Clear context to exclude history.'**
  String get contextSummaryEmpty;

  /// No description provided for @toolApprovalDenied.
  ///
  /// In en, this message translates to:
  /// **'Denied'**
  String get toolApprovalDenied;

  /// No description provided for @contextDetailModel.
  ///
  /// In en, this message translates to:
  /// **'Model · time'**
  String get contextDetailModel;

  /// No description provided for @compressIncludeManual.
  ///
  /// In en, this message translates to:
  /// **'Include manual edits · {count}'**
  String compressIncludeManual(int count);

  /// No description provided for @contextBudgetInfo.
  ///
  /// In en, this message translates to:
  /// **'Estimated next request (including output reserve): {used} / {limit} tokens'**
  String contextBudgetInfo(int used, String limit);

  /// No description provided for @contextTaskDismiss.
  ///
  /// In en, this message translates to:
  /// **'Dismiss status'**
  String get contextTaskDismiss;

  /// No description provided for @contextUndoBudgetInfo.
  ///
  /// In en, this message translates to:
  /// **'After undo: approximately {used} tokens including output reserve'**
  String contextUndoBudgetInfo(int used);

  /// No description provided for @storageSpaceImageInUse.
  ///
  /// In en, this message translates to:
  /// **'In use'**
  String get storageSpaceImageInUse;

  /// No description provided for @worldBookSelectionDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get worldBookSelectionDone;

  /// No description provided for @contextDividerFailed.
  ///
  /// In en, this message translates to:
  /// **'Compression failed'**
  String get contextDividerFailed;

  /// No description provided for @toolPermissionUnboundHint.
  ///
  /// In en, this message translates to:
  /// **'No workspace bound: this does not turn on file or shell tools.'**
  String get toolPermissionUnboundHint;

  /// No description provided for @contextChangeWaiting.
  ///
  /// In en, this message translates to:
  /// **'Waiting for the current reply and tools to finish before applying this change.'**
  String get contextChangeWaiting;

  /// No description provided for @storageSpaceDeletedUploadsPartial.
  ///
  /// In en, this message translates to:
  /// **'Deleted {deleted} items; kept {kept} items that are in use or could not be deleted.'**
  String storageSpaceDeletedUploadsPartial(int deleted, int kept);

  /// No description provided for @contextSourceScopeHint.
  ///
  /// In en, this message translates to:
  /// **'Only history after the latest clear is included. This may include older messages outside the normal send window.'**
  String get contextSourceScopeHint;

  /// No description provided for @contextTaskPreparing.
  ///
  /// In en, this message translates to:
  /// **'Preparing compression'**
  String get contextTaskPreparing;

  /// No description provided for @contextImpactUsage.
  ///
  /// In en, this message translates to:
  /// **'Approx. {from} → {to} tokens'**
  String contextImpactUsage(String from, String to);

  /// No description provided for @contextImpactConfirm.
  ///
  /// In en, this message translates to:
  /// **'Undo {count} nodes'**
  String contextImpactConfirm(int count);

  /// No description provided for @contextDividerEdited.
  ///
  /// In en, this message translates to:
  /// **'edited'**
  String get contextDividerEdited;

  /// No description provided for @compressAdjust.
  ///
  /// In en, this message translates to:
  /// **'Adjust'**
  String get compressAdjust;

  /// No description provided for @compressRegenerate.
  ///
  /// In en, this message translates to:
  /// **'Recompress'**
  String get compressRegenerate;

  /// No description provided for @toolPermissionEnabledSnack.
  ///
  /// In en, this message translates to:
  /// **'Full access enabled for this chat'**
  String get toolPermissionEnabledSnack;

  /// No description provided for @contextDetailSuperseded.
  ///
  /// In en, this message translates to:
  /// **'Superseded by a later summary'**
  String get contextDetailSuperseded;

  /// No description provided for @contextTaskQueued.
  ///
  /// In en, this message translates to:
  /// **'Queued — waiting for compression'**
  String get contextTaskQueued;

  /// No description provided for @contextNewConversation.
  ///
  /// In en, this message translates to:
  /// **'Create a new chat with the summary'**
  String get contextNewConversation;

  /// No description provided for @contextUnknownLimit.
  ///
  /// In en, this message translates to:
  /// **'unknown limit'**
  String get contextUnknownLimit;

  /// No description provided for @browserErrActionTimeout.
  ///
  /// In en, this message translates to:
  /// **'Operation timed out; outcome unknown. Check the page before allowing AI to continue.'**
  String get browserErrActionTimeout;

  /// No description provided for @toolPermissionRequestApprovalDesc.
  ///
  /// In en, this message translates to:
  /// **'Kelivo will ask before accessing files outside the workspace, running desktop commands, or using other tools that need approval.'**
  String get toolPermissionRequestApprovalDesc;

  /// No description provided for @contextLimitedInputHint.
  ///
  /// In en, this message translates to:
  /// **'Only the selected character window is read. The rest of the replaced history is not included in the summary; original messages remain available.'**
  String get contextLimitedInputHint;

  /// No description provided for @contextTaskCancelled.
  ///
  /// In en, this message translates to:
  /// **'Compression cancelled'**
  String get contextTaskCancelled;

  /// No description provided for @contextDetailClearTitle.
  ///
  /// In en, this message translates to:
  /// **'Context cleared'**
  String get contextDetailClearTitle;

  /// No description provided for @contextImpactKeep.
  ///
  /// In en, this message translates to:
  /// **'Unchanged'**
  String get contextImpactKeep;

  /// No description provided for @contextImpactUndoAlso.
  ///
  /// In en, this message translates to:
  /// **'Also undone'**
  String get contextImpactUndoAlso;

  /// No description provided for @contextClearMarker.
  ///
  /// In en, this message translates to:
  /// **'Context cleared'**
  String get contextClearMarker;

  /// No description provided for @toolPermissionScopeThisChat.
  ///
  /// In en, this message translates to:
  /// **'This chat only'**
  String get toolPermissionScopeThisChat;

  /// No description provided for @dataDirectoryTitle.
  ///
  /// In en, this message translates to:
  /// **'Data directory'**
  String get dataDirectoryTitle;

  /// No description provided for @dataDirectoryChange.
  ///
  /// In en, this message translates to:
  /// **'Change directory'**
  String get dataDirectoryChange;

  /// No description provided for @dataDirectoryChoose.
  ///
  /// In en, this message translates to:
  /// **'Choose an empty local folder'**
  String get dataDirectoryChoose;

  /// No description provided for @dataDirectoryHint.
  ///
  /// In en, this message translates to:
  /// **'Choose an empty folder on a local drive. Chat history, attachments and app-managed files move after a restart. Small device settings and system caches stay in their system locations.'**
  String get dataDirectoryHint;

  /// No description provided for @dataDirectoryPendingHint.
  ///
  /// In en, this message translates to:
  /// **'The move is scheduled for the next restart. Your current data remains in place until copying and verification finish. Destination:'**
  String get dataDirectoryPendingHint;

  /// No description provided for @dataDirectoryRestart.
  ///
  /// In en, this message translates to:
  /// **'Restart and move data'**
  String get dataDirectoryRestart;

  /// No description provided for @dataDirectoryCancelMove.
  ///
  /// In en, this message translates to:
  /// **'Cancel move and keep original directory'**
  String get dataDirectoryCancelMove;

  /// No description provided for @dataDirectoryPreviousHint.
  ///
  /// In en, this message translates to:
  /// **'The original copy was retained. Once the new directory has started successfully, you can remove the old copy to free disk space. Clean it before changing directories again.'**
  String get dataDirectoryPreviousHint;

  /// No description provided for @dataDirectoryCleanPrevious.
  ///
  /// In en, this message translates to:
  /// **'Clean up original copy'**
  String get dataDirectoryCleanPrevious;

  /// No description provided for @dataDirectoryCleanConfirm.
  ///
  /// In en, this message translates to:
  /// **'Remove the retained copy from the directory below? Data in the current directory will be kept. Files changed since the move will not be deleted.'**
  String get dataDirectoryCleanConfirm;

  /// No description provided for @dataDirectoryMoving.
  ///
  /// In en, this message translates to:
  /// **'Moving and verifying data… Please keep Kelivo open.'**
  String get dataDirectoryMoving;

  /// No description provided for @dataDirectoryStartupFailed.
  ///
  /// In en, this message translates to:
  /// **'Unable to open the data directory'**
  String get dataDirectoryStartupFailed;

  /// No description provided for @dataDirectoryRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get dataDirectoryRetry;

  /// No description provided for @dataDirectoryUnavailable.
  ///
  /// In en, this message translates to:
  /// **'The data directory is unavailable. Reconnect the drive or restore the folder to its original location, then retry. No empty database will be created.'**
  String get dataDirectoryUnavailable;

  /// No description provided for @dataDirectoryIdentityMismatch.
  ///
  /// In en, this message translates to:
  /// **'This folder does not match the configured data directory. Restore the original folder and retry.'**
  String get dataDirectoryIdentityMismatch;

  /// No description provided for @dataDirectoryNotEmpty.
  ///
  /// In en, this message translates to:
  /// **'Choose an empty folder. Existing files will not be overwritten.'**
  String get dataDirectoryNotEmpty;

  /// No description provided for @dataDirectoryOverlap.
  ///
  /// In en, this message translates to:
  /// **'Choose a separate folder outside the current data directory. Its parent folders and the drive root cannot be used.'**
  String get dataDirectoryOverlap;

  /// No description provided for @dataDirectoryLocalOnly.
  ///
  /// In en, this message translates to:
  /// **'Choose a local drive rather than a network share.'**
  String get dataDirectoryLocalOnly;

  /// No description provided for @dataDirectoryFinishPrevious.
  ///
  /// In en, this message translates to:
  /// **'Finish or cancel the pending move, and clean up the retained copy before choosing another directory.'**
  String get dataDirectoryFinishPrevious;

  /// No description provided for @dataDirectoryPendingRestore.
  ///
  /// In en, this message translates to:
  /// **'A backup restore is pending. Cancel the directory move and restart to finish restoring, then try the move again.'**
  String get dataDirectoryPendingRestore;

  /// No description provided for @dataDirectorySourceChanged.
  ///
  /// In en, this message translates to:
  /// **'The original data has changed since the copy was made. It has been kept. Cancel the pending move before starting a new one; retained copies can be inspected manually.'**
  String get dataDirectorySourceChanged;

  /// No description provided for @dataDirectoryCopyChanged.
  ///
  /// In en, this message translates to:
  /// **'The destination contains unexpected or changed files. The original data has been kept. Check the destination before retrying.'**
  String get dataDirectoryCopyChanged;

  /// No description provided for @dataDirectoryGenericError.
  ///
  /// In en, this message translates to:
  /// **'The operation could not finish. Check available disk space, folder permissions and whether another Kelivo process is running, then retry. Existing data has been kept.'**
  String get dataDirectoryGenericError;

  /// No description provided for @dataDirectoryCancelHint.
  ///
  /// In en, this message translates to:
  /// **'Cancelling keeps any files already copied to the destination. You can inspect and remove that partial copy yourself.'**
  String get dataDirectoryCancelHint;
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
