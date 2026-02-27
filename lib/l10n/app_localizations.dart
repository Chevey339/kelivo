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
  /// **'Display'**
  String get settingsPageDisplay;

  /// No description provided for @settingsPageDisplaySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Appearance and text size'**
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

  /// No description provided for @storageSpaceCategoryChatData.
  ///
  /// In en, this message translates to:
  /// **'Chat Records'**
  String get storageSpaceCategoryChatData;

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
  /// **'App'**
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
  /// **'You are {model_name}, an AI assistant who gladly provides accurate and helpful assistance. The current time is {cur_datetime}, the device language is {locale}, timezone is {timezone}, the user is using {device_info}, version {system_version}. If the user does not explicitly specify otherwise, please use the user\'s device language when replying.'**
  String assistantProviderSampleAssistantSystemPrompt(
    String model_name,
    String cur_datetime,
    String locale,
    String timezone,
    String device_info,
    String system_version,
  );

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
  /// **'Delete Message'**
  String get homePageDeleteMessage;

  /// No description provided for @homePageDeleteMessageConfirm.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete this message? This cannot be undone.'**
  String get homePageDeleteMessageConfirm;

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
  /// **'Use assistant avatar/name instead of model'**
  String get assistantEditUseAssistantAvatarSubtitle;

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

  /// No description provided for @codeBlockPreviewButton.
  ///
  /// In en, this message translates to:
  /// **'Preview'**
  String get codeBlockPreviewButton;

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

  /// No description provided for @assistantSettingsDefaultTag.
  ///
  /// In en, this message translates to:
  /// **'Default'**
  String get assistantSettingsDefaultTag;

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
  /// **'Restore completed. Please restart the app.'**
  String get backupPageRestartContent;

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
  /// **'Choose how to import the backup data:'**
  String get backupPageSelectImportModeDescription;

  /// No description provided for @backupPageOverwriteMode.
  ///
  /// In en, this message translates to:
  /// **'Complete Overwrite'**
  String get backupPageOverwriteMode;

  /// No description provided for @backupPageOverwriteModeDescription.
  ///
  /// In en, this message translates to:
  /// **'Clear all local data and restore from backup'**
  String get backupPageOverwriteModeDescription;

  /// No description provided for @backupPageMergeMode.
  ///
  /// In en, this message translates to:
  /// **'Smart Merge'**
  String get backupPageMergeMode;

  /// No description provided for @backupPageMergeModeDescription.
  ///
  /// In en, this message translates to:
  /// **'Add only non-existing data (intelligent deduplication)'**
  String get backupPageMergeModeDescription;

  /// No description provided for @backupPageRestore.
  ///
  /// In en, this message translates to:
  /// **'Restore'**
  String get backupPageRestore;

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

  /// No description provided for @backupPageImportFromRikkaHub.
  ///
  /// In en, this message translates to:
  /// **'Import from RikkaHub'**
  String get backupPageImportFromRikkaHub;

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

  /// No description provided for @backupPageImportFromChatbox.
  ///
  /// In en, this message translates to:
  /// **'Import from Chatbox'**
  String get backupPageImportFromChatbox;

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

  /// No description provided for @messageMoreSheetCreateBranch.
  ///
  /// In en, this message translates to:
  /// **'Create Branch'**
  String get messageMoreSheetCreateBranch;

  /// No description provided for @messageMoreSheetDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get messageMoreSheetDelete;

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

  /// No description provided for @reasoningBudgetSheetCustomLabel.
  ///
  /// In en, this message translates to:
  /// **'Custom Reasoning Budget (tokens)'**
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

  /// No description provided for @chatMessageWidgetCitationsTitle.
  ///
  /// In en, this message translates to:
  /// **'Citations ({count})'**
  String chatMessageWidgetCitationsTitle(int count);

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
  /// **'Regenerating will overwrite all messages after this one and cannot be undone. Are you sure?'**
  String get chatMessageWidgetRegenerateConfirmContent;

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

  /// No description provided for @chatMessageWidgetCreateMemory.
  ///
  /// In en, this message translates to:
  /// **'Create Memory'**
  String get chatMessageWidgetCreateMemory;

  /// No description provided for @chatMessageWidgetEditMemory.
  ///
  /// In en, this message translates to:
  /// **'Edit Memory'**
  String get chatMessageWidgetEditMemory;

  /// No description provided for @chatMessageWidgetDeleteMemory.
  ///
  /// In en, this message translates to:
  /// **'Delete Memory'**
  String get chatMessageWidgetDeleteMemory;

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
  /// **'Citations ({count})'**
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
  /// **'Search chat history'**
  String get sideDrawerSearchHint;

  /// No description provided for @sideDrawerSearchAssistantsHint.
  ///
  /// In en, this message translates to:
  /// **'Search assistants'**
  String get sideDrawerSearchAssistantsHint;

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

  /// No description provided for @mcpPageStatusDisabled.
  ///
  /// In en, this message translates to:
  /// **'Disabled'**
  String get mcpPageStatusDisabled;

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
  /// **'Used for summarizing conversation titles; prefer fast & cheap models'**
  String get defaultModelPageTitleModelSubtitle;

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

  /// No description provided for @defaultModelPageOcrModelSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Used for extracting text and descriptions from images'**
  String get defaultModelPageOcrModelSubtitle;

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

  /// No description provided for @modelDetailSheetAddBody.
  ///
  /// In en, this message translates to:
  /// **'Add Body'**
  String get modelDetailSheetAddBody;

  /// No description provided for @modelDetailSheetBuiltinToolsDescription.
  ///
  /// In en, this message translates to:
  /// **'Built-in tools only support official APIs.'**
  String get modelDetailSheetBuiltinToolsDescription;

  /// No description provided for @modelDetailSheetGeminiCodeExecutionMutuallyExclusiveHint.
  ///
  /// In en, this message translates to:
  /// **'Code execution cannot coexist with Search/URL Context/MCP tools.'**
  String get modelDetailSheetGeminiCodeExecutionMutuallyExclusiveHint;

  /// No description provided for @modelDetailSheetBuiltinToolsUnsupportedHint.
  ///
  /// In en, this message translates to:
  /// **'Current provider does not support these built-in tools.'**
  String get modelDetailSheetBuiltinToolsUnsupportedHint;

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

  /// No description provided for @aboutPageSystem.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get aboutPageSystem;

  /// No description provided for @aboutPageWebsite.
  ///
  /// In en, this message translates to:
  /// **'Website'**
  String get aboutPageWebsite;

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

  /// No description provided for @displaySettingsPageMessageNavButtonsTitle.
  ///
  /// In en, this message translates to:
  /// **'Message Navigation Buttons'**
  String get displaySettingsPageMessageNavButtonsTitle;

  /// No description provided for @displaySettingsPageMessageNavButtonsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Show quick jump buttons when scrolling'**
  String get displaySettingsPageMessageNavButtonsSubtitle;

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

  /// No description provided for @fontPickerGetFromGoogleFonts.
  ///
  /// In en, this message translates to:
  /// **'Browse Google Fonts'**
  String get fontPickerGetFromGoogleFonts;

  /// No description provided for @fontPickerFilterHint.
  ///
  /// In en, this message translates to:
  /// **'Filter fonts...'**
  String get fontPickerFilterHint;

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

  /// No description provided for @themeSettingsPageColorPalettesSection.
  ///
  /// In en, this message translates to:
  /// **'Color Palettes'**
  String get themeSettingsPageColorPalettesSection;

  /// No description provided for @ttsServicesPageBackButton.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get ttsServicesPageBackButton;

  /// No description provided for @ttsServicesPageTitle.
  ///
  /// In en, this message translates to:
  /// **'Text-to-Speech'**
  String get ttsServicesPageTitle;

  /// No description provided for @ttsServicesPageAddTooltip.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get ttsServicesPageAddTooltip;

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

  /// No description provided for @imageViewerPageSaveButton.
  ///
  /// In en, this message translates to:
  /// **'Save Image'**
  String get imageViewerPageSaveButton;

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

  /// No description provided for @assistantEditMemorySwitchTitle.
  ///
  /// In en, this message translates to:
  /// **'Memory'**
  String get assistantEditMemorySwitchTitle;

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

  /// No description provided for @assistantEditManageMemoryTitle.
  ///
  /// In en, this message translates to:
  /// **'Manage Memories'**
  String get assistantEditManageMemoryTitle;

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
  /// **'Log response body content (may use significant storage)'**
  String get logSettingsSaveOutputSubtitle;

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

  /// No description provided for @fileUploadDuplicateTitle.
  ///
  /// In en, this message translates to:
  /// **'File already exists'**
  String get fileUploadDuplicateTitle;

  /// No description provided for @fileUploadDuplicateContent.
  ///
  /// In en, this message translates to:
  /// **'A file named {fileName} already exists. Use the existing file?'**
  String fileUploadDuplicateContent(String fileName);

  /// No description provided for @fileUploadDuplicateUseExisting.
  ///
  /// In en, this message translates to:
  /// **'Use existing'**
  String get fileUploadDuplicateUseExisting;

  /// No description provided for @fileUploadDuplicateUploadNew.
  ///
  /// In en, this message translates to:
  /// **'Upload new'**
  String get fileUploadDuplicateUploadNew;

  /// No description provided for @settingsPageWorldBook.
  ///
  /// In en, this message translates to:
  /// **'World Book'**
  String get settingsPageWorldBook;

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
