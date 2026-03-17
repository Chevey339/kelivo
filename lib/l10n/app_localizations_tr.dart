// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Turkish (`tr`).
class AppLocalizationsTr extends AppLocalizations {
  AppLocalizationsTr([String locale = 'tr']) : super(locale);

  @override
  String get helloWorld => 'Selam Dünya!';

  @override
  String get settingsPageBackButton => 'Geri';

  @override
  String get settingsPageTitle => 'Ayarlar';

  @override
  String get settingsPageDarkMode => 'Karanlık';

  @override
  String get settingsPageLightMode => 'Işık';

  @override
  String get settingsPageSystemMode => 'Sistem';

  @override
  String get settingsPageWarningMessage =>
      'Some services are not configured; features may be limited.';

  @override
  String get settingsPageGeneralSection => 'Genel';

  @override
  String get settingsPageColorMode => 'Renk Modu';

  @override
  String get settingsPageDisplay => 'Görüntülemek';

  @override
  String get settingsPageDisplaySubtitle => 'Görünüm ve metin boyutu';

  @override
  String get settingsPageAssistant => 'Asistan';

  @override
  String get settingsPageAssistantSubtitle => 'Varsayılan yardımcı ve stil';

  @override
  String get settingsPageModelsServicesSection => 'Modeller ve Hizmetler';

  @override
  String get settingsPageDefaultModel => 'Varsayılan Model';

  @override
  String get settingsPageProviders => 'Sağlayıcılar';

  @override
  String get settingsPageHotkeys => 'Kısayol tuşları';

  @override
  String get settingsPageSearch => 'Aramak';

  @override
  String get settingsPageTts => 'TTS';

  @override
  String get settingsPageMcp => 'MCP';

  @override
  String get settingsPageQuickPhrase => 'Hızlı İfade';

  @override
  String get settingsPageInstructionInjection => 'Talimat Enjeksiyonu';

  @override
  String get settingsPageDataSection => 'Veri';

  @override
  String get settingsPageBackup => 'Yedekleme';

  @override
  String get settingsPageChatStorage => 'Sohbet Depolama Alanı';

  @override
  String get settingsPageCalculating => 'Hesaplanıyor…';

  @override
  String settingsPageFilesCount(int count, String size) {
    return '${count} dosyalar · ${size}';
  }

  @override
  String get storageSpacePageTitle => 'Depolama Alanı';

  @override
  String get storageSpaceRefreshTooltip => 'Yenile';

  @override
  String get storageSpaceLoadFailed => 'Depolama alanı kullanımı yüklenemedi';

  @override
  String get storageSpaceTotalLabel => 'Kullanılmış';

  @override
  String storageSpaceClearableLabel(String size) {
    return 'Temizlenebilir: ${size}';
  }

  @override
  String storageSpaceClearableHint(String size) {
    return 'Temizlemesi güvenli: ${size}';
  }

  @override
  String get storageSpaceCategoryImages => 'Görseller';

  @override
  String get storageSpaceCategoryFiles => 'Dosyalar';

  @override
  String get storageSpaceCategoryChatData => 'Sohbet Kayıtları';

  @override
  String get storageSpaceCategoryAssistantData => 'Asistanlar';

  @override
  String get storageSpaceCategoryCache => 'Önbellek';

  @override
  String get storageSpaceCategoryLogs => 'Günlükler';

  @override
  String get storageSpaceCategoryOther => 'Uygulama';

  @override
  String storageSpaceFilesCount(int count) {
    return '${count} dosya';
  }

  @override
  String get storageSpaceSafeToClearHint =>
      'Safe to clear. This will not affect your chat history.';

  @override
  String get storageSpaceNotSafeToClearHint =>
      'May affect your chat history. Delete with care.';

  @override
  String get storageSpaceBreakdownTitle => 'Bozulma';

  @override
  String get storageSpaceSubChatMessages => 'Mesajlar';

  @override
  String get storageSpaceSubChatConversations => 'Konuşmalar';

  @override
  String get storageSpaceSubChatToolEvents => 'Araç etkinlikleri';

  @override
  String get storageSpaceSubAssistantAvatars => 'Avatarlar';

  @override
  String get storageSpaceSubAssistantImages => 'Görseller';

  @override
  String get storageSpaceSubCacheAvatars => 'Avatar önbelleği';

  @override
  String get storageSpaceSubCacheOther => 'Diğer önbellek';

  @override
  String get storageSpaceSubCacheSystem => 'Sistem önbelleği';

  @override
  String get storageSpaceSubLogsFlutter => 'Çarpıntı günlükleri';

  @override
  String get storageSpaceSubLogsRequests => 'Ağ günlükleri';

  @override
  String get storageSpaceSubLogsOther => 'Diğer günlükler';

  @override
  String get storageSpaceClearConfirmTitle => 'Temizlemeyi onayla';

  @override
  String storageSpaceClearConfirmMessage(String targetName) {
    return '${targetName} silinsin mi?';
  }

  @override
  String get storageSpaceClearButton => 'Temizlemek';

  @override
  String storageSpaceClearDone(String targetName) {
    return '${targetName} temizlendi';
  }

  @override
  String storageSpaceClearFailed(String error) {
    return 'Temizleme başarısız oldu: ${error}';
  }

  @override
  String get storageSpaceClearAvatarCacheButton => 'Avatar Önbelleğini Temizle';

  @override
  String get storageSpaceClearCacheButton => 'Önbelleği Temizle';

  @override
  String get storageSpaceClearLogsButton => 'Günlükleri Temizle';

  @override
  String get storageSpaceViewLogsButton => 'Günlükleri Görüntüle';

  @override
  String get storageSpaceDeleteConfirmTitle => 'Silmeyi onayla';

  @override
  String storageSpaceDeleteUploadsConfirmMessage(int count) {
    return '${count} öğe silinsin mi? Sohbet geçmişindeki ekler kullanılamayabilir.';
  }

  @override
  String storageSpaceDeletedUploadsDone(int count) {
    return '${count} öğe silindi';
  }

  @override
  String get storageSpaceNoUploads => 'Öğe yok';

  @override
  String get storageSpaceSelectAll => 'Tümünü seç';

  @override
  String get storageSpaceClearSelection => 'Seçimi temizle';

  @override
  String storageSpaceSelectedCount(int count) {
    return '${count} seçildi';
  }

  @override
  String storageSpaceUploadsCount(int count) {
    return '${count} öğe';
  }

  @override
  String get settingsPageAboutSection => 'Hakkında';

  @override
  String get settingsPageAbout => 'Hakkında';

  @override
  String get settingsPageDocs => 'Dokümanlar';

  @override
  String get settingsPageLogs => 'Günlükler';

  @override
  String get settingsPageSponsor => 'Sponsor';

  @override
  String get settingsPageShare => 'Paylaşmak';

  @override
  String get sponsorPageMethodsSectionTitle => 'Sponsorluk Yöntemleri';

  @override
  String get sponsorPageSponsorsSectionTitle => 'Sponsorlar';

  @override
  String get sponsorPageEmpty => 'Henüz sponsor yok';

  @override
  String get sponsorPageAfdianTitle => 'Afdiyen';

  @override
  String get sponsorPageAfdianSubtitle => 'afdian.com/a/kelivo';

  @override
  String get sponsorPageWeChatTitle => 'WeChat Sponsoru';

  @override
  String get sponsorPageWeChatSubtitle => 'WeChat sponsor kodu';

  @override
  String get languageDisplaySimplifiedChinese => 'Basitleştirilmiş Çince';

  @override
  String get languageDisplayEnglish => 'İngilizce';

  @override
  String get languageDisplayTraditionalChinese => 'Geleneksel Çince';

  @override
  String get languageDisplayJapanese => 'Japonca';

  @override
  String get languageDisplayKorean => 'Korece';

  @override
  String get languageDisplayFrench => 'Fransızca';

  @override
  String get languageDisplayGerman => 'Almanca';

  @override
  String get languageDisplayItalian => 'İtalyan';

  @override
  String get languageDisplaySpanish => 'İspanyol';

  @override
  String get languageDisplayTurkish => 'Türkçe';

  @override
  String get languageSelectSheetTitle => 'Çeviri Dilini Seçin';

  @override
  String get languageSelectSheetClearButton => 'Çeviriyi Temizle';

  @override
  String get homePageClearContext => 'İçeriği Temizle';

  @override
  String homePageClearContextWithCount(String actual, String configured) {
    return 'İçeriği Temizle (${actual}/${configured})';
  }

  @override
  String get homePageDefaultAssistant => 'Varsayılan Asistan';

  @override
  String get mermaidExportPng => 'PNG\'yi dışa aktar';

  @override
  String get mermaidExportFailed => 'Dışa aktarma başarısız oldu';

  @override
  String get mermaidPreviewOpen => 'Önizlemeyi Aç';

  @override
  String get mermaidPreviewOpenFailed => 'Önizleme açılamıyor';

  @override
  String get assistantProviderDefaultAssistantName => 'Varsayılan Asistan';

  @override
  String get assistantProviderSampleAssistantName => 'Örnek Asistan';

  @override
  String get assistantProviderNewAssistantName => 'Yeni Asistan';

  @override
  String assistantProviderSampleAssistantSystemPrompt(
    String model_name,
    String cur_datetime,
    String locale,
    String timezone,
    String device_info,
    String system_version,
  ) {
    return 'Siz ${model_name}, memnuniyetle doğru ve yararlı yardım sağlayan bir yapay zeka asistanısınız. Geçerli saat ${cur_datetime}, cihazın dili ${locale}, saat dilimi ${timezone}, kullanıcı ${device_info}, sürüm ${system_version} kullanıyor. Kullanıcı aksini açıkça belirtmediği takdirde lütfen yanıt verirken kullanıcının cihazının dilini kullanın.';
  }

  @override
  String get displaySettingsPageLanguageTitle => 'Uygulama Dili';

  @override
  String get displaySettingsPageLanguageSubtitle => 'Arayüz dilini seçin';

  @override
  String get assistantTagsManageTitle => 'Etiketleri Yönet';

  @override
  String get assistantTagsCreateButton => 'Yaratmak';

  @override
  String get assistantTagsCreateDialogTitle => 'Etiket Oluştur';

  @override
  String get assistantTagsCreateDialogOk => 'Yaratmak';

  @override
  String get assistantTagsCreateDialogCancel => 'İptal etmek';

  @override
  String get assistantTagsNameHint => 'Etiket adı';

  @override
  String get assistantTagsRenameButton => 'Yeniden isimlendirmek';

  @override
  String get assistantTagsRenameDialogTitle => 'Etiketi Yeniden Adlandır';

  @override
  String get assistantTagsRenameDialogOk => 'Yeniden isimlendirmek';

  @override
  String get assistantTagsDeleteButton => 'Silmek';

  @override
  String get assistantTagsDeleteConfirmTitle => 'Etiketi Sil';

  @override
  String get assistantTagsDeleteConfirmContent =>
      'Are you sure you want to delete this tag?';

  @override
  String get assistantTagsDeleteConfirmOk => 'Silmek';

  @override
  String get assistantTagsDeleteConfirmCancel => 'İptal etmek';

  @override
  String get assistantTagsContextMenuEditAssistant => 'Asistanı Düzenle';

  @override
  String get assistantTagsContextMenuManageTags => 'Etiketleri Yönet';

  @override
  String get mcpTransportOptionStdio => 'STDIO';

  @override
  String get mcpTransportTagStdio => 'STDIO';

  @override
  String get mcpTransportTagInmemory => 'Yerleşik';

  @override
  String get mcpServerEditSheetStdioOnlyDesktop =>
      'STDIO is only available on desktop';

  @override
  String get mcpServerEditSheetStdioCommandLabel => 'Emretmek';

  @override
  String get mcpServerEditSheetStdioArgumentsLabel => 'Argümanlar';

  @override
  String get mcpServerEditSheetStdioWorkingDirectoryLabel =>
      'Working Directory (optional)';

  @override
  String get mcpServerEditSheetStdioEnvironmentTitle => 'Çevre';

  @override
  String get mcpServerEditSheetStdioEnvNameLabel => 'İsim';

  @override
  String get mcpServerEditSheetStdioEnvValueLabel => 'Değer';

  @override
  String get mcpServerEditSheetStdioAddEnv => 'Zarf Ekle';

  @override
  String get mcpServerEditSheetStdioCommandRequired =>
      'Command is required for STDIO';

  @override
  String get assistantTagsContextMenuDeleteAssistant => 'Asistanı Sil';

  @override
  String get assistantTagsClearTag => 'Etiketi Temizle';

  @override
  String get displaySettingsPageLanguageChineseLabel => 'Basitleştirilmiş Çince';

  @override
  String get displaySettingsPageLanguageEnglishLabel => 'İngilizce';

  @override
  String get homePagePleaseSelectModel => 'Lütfen önce bir model seçin';

  @override
  String get homePageAudioAttachmentUnsupported =>
      'The current model does not support audio attachments. Switch to a model that supports audio input or remove the audio file and try again.';

  @override
  String get homePagePleaseSetupTranslateModel =>
      'Please set a translation model first';

  @override
  String get homePageTranslating => 'Çeviri...';

  @override
  String homePageTranslateFailed(String error) {
    return 'Çeviri başarısız oldu: ${error}';
  }

  @override
  String get chatServiceDefaultConversationTitle => 'Yeni Sohbet';

  @override
  String get userProviderDefaultUserName => 'Kullanıcı';

  @override
  String get homePageDeleteMessage => 'Mesajı Sil';

  @override
  String get homePageDeleteMessageConfirm =>
      'Are you sure you want to delete this message? This cannot be undone.';

  @override
  String get homePageCancel => 'İptal etmek';

  @override
  String get homePageDelete => 'Silmek';

  @override
  String get homePageSelectMessagesToShare => 'Lütfen paylaşılacak mesajları seçin';

  @override
  String get homePageDone => 'Tamamlamak';

  @override
  String get homePageDropToUpload => 'Yüklenecek dosyaları bırakın';

  @override
  String get assistantEditPageTitle => 'Asistan';

  @override
  String get assistantEditPageNotFound => 'Asistan bulunamadı';

  @override
  String get assistantEditPageBasicTab => 'Temel';

  @override
  String get assistantEditPagePromptsTab => 'İstemler';

  @override
  String get assistantEditPageMcpTab => 'MCP';

  @override
  String get assistantEditPageQuickPhraseTab => 'Hızlı İfade';

  @override
  String get assistantEditPageCustomTab => 'Gelenek';

  @override
  String get assistantEditPageRegexTab => 'Regex\'i Değiştir';

  @override
  String get assistantEditRegexDescription =>
      'Create regex rules to rewrite or visually adjust user/assistant messages.';

  @override
  String get assistantEditAddRegexButton => 'Regex Kuralı Ekle';

  @override
  String get assistantRegexAddTitle => 'Regex Kuralı Ekle';

  @override
  String get assistantRegexEditTitle => 'Regex Kuralını Düzenle';

  @override
  String get assistantRegexNameLabel => 'Kural Adı';

  @override
  String get assistantRegexPatternLabel => 'Normal İfade';

  @override
  String get assistantRegexReplacementLabel => 'Yedek Dize';

  @override
  String get assistantRegexScopeLabel => 'Kapsamı Etkileyen';

  @override
  String get assistantRegexScopeUser => 'Kullanıcı';

  @override
  String get assistantRegexScopeAssistant => 'Asistan';

  @override
  String get assistantRegexScopeVisualOnly => 'Yalnızca Görsel';

  @override
  String get assistantRegexScopeReplaceOnly => 'Yalnızca Değiştir';

  @override
  String get assistantRegexAddAction => 'Eklemek';

  @override
  String get assistantRegexSaveAction => 'Kaydetmek';

  @override
  String get assistantRegexDeleteButton => 'Silmek';

  @override
  String get assistantRegexValidationError =>
      'Please fill in the name, regex, and select at least one scope.';

  @override
  String get assistantRegexInvalidPattern => 'Geçersiz normal ifade';

  @override
  String get assistantRegexCancelButton => 'İptal etmek';

  @override
  String get assistantRegexUntitled => 'Başlıksız Kural';

  @override
  String get assistantEditCustomHeadersTitle => 'Özel Başlıklar';

  @override
  String get assistantEditCustomHeadersAdd => 'Başlık Ekle';

  @override
  String get assistantEditCustomHeadersEmpty => 'Başlık eklenmedi';

  @override
  String get assistantEditCustomBodyTitle => 'Özel Gövde';

  @override
  String get assistantEditCustomBodyAdd => 'Gövde Ekle';

  @override
  String get assistantEditCustomBodyEmpty => 'Hiçbir gövde öğesi eklenmedi';

  @override
  String get assistantEditHeaderNameLabel => 'Başlık Adı';

  @override
  String get assistantEditHeaderValueLabel => 'Başlık Değeri';

  @override
  String get assistantEditBodyKeyLabel => 'Gövde Anahtarı';

  @override
  String get assistantEditBodyValueLabel => 'Beden Değeri (JSON)';

  @override
  String get assistantEditDeleteTooltip => 'Silmek';

  @override
  String get assistantEditAssistantNameLabel => 'Asistan Adı';

  @override
  String get assistantEditUseAssistantAvatarTitle => 'Asistan Avatarını Kullan';

  @override
  String get assistantEditUseAssistantAvatarSubtitle =>
      'Use assistant avatar instead of model avatar';

  @override
  String get assistantEditUseAssistantNameTitle => 'Asistan Adını Kullan';

  @override
  String get assistantEditChatModelTitle => 'Sohbet Modeli';

  @override
  String get assistantEditChatModelSubtitle =>
      'Default chat model for this assistant (fallback to global)';

  @override
  String get assistantEditTemperatureDescription =>
      'Controls randomness, range 0–2';

  @override
  String get assistantEditTopPDescription =>
      'Do not change unless you know what you are doing';

  @override
  String get assistantEditParameterDisabled =>
      'Disabled (uses provider default)';

  @override
  String get assistantEditParameterDisabled2 => 'Devre dışı (kısıtlama yok)';

  @override
  String get assistantEditContextMessagesTitle => 'Bağlam Mesajları';

  @override
  String get assistantEditContextMessagesDescription =>
      'How many recent messages to keep in context';

  @override
  String get assistantEditStreamOutputTitle => 'Akış Çıkışı';

  @override
  String get assistantEditStreamOutputDescription =>
      'Enable streaming responses';

  @override
  String get assistantEditThinkingBudgetTitle => 'Bütçeyi Düşünmek';

  @override
  String get assistantEditConfigureButton => 'Yapılandır';

  @override
  String get assistantEditMaxTokensTitle => 'Maksimum Jeton';

  @override
  String get assistantEditMaxTokensDescription => 'Sınırsız kullanım için boş bırakın';

  @override
  String get assistantEditMaxTokensHint => 'Sınırsız';

  @override
  String get assistantEditChatBackgroundTitle => 'Sohbet Arka Planı';

  @override
  String get assistantEditChatBackgroundDescription =>
      'Set a background image for this assistant';

  @override
  String get assistantEditChooseImageButton => 'Resim Seç';

  @override
  String get assistantEditClearButton => 'Temizlemek';

  @override
  String get desktopNavChatTooltip => 'Sohbet';

  @override
  String get desktopNavTranslateTooltip => 'Çevir';

  @override
  String get desktopNavStorageTooltip => 'Depolamak';

  @override
  String get desktopNavGlobalSearchTooltip => 'Küresel Arama';

  @override
  String get desktopNavThemeToggleTooltip => 'Tema';

  @override
  String get desktopNavSettingsTooltip => 'Ayarlar';

  @override
  String get desktopAvatarMenuUseEmoji => 'Emoji kullan';

  @override
  String get cameraPermissionDeniedMessage =>
      'Camera unavailable: permission not granted.';

  @override
  String get openSystemSettings => 'Ayarları Aç';

  @override
  String get desktopAvatarMenuChangeFromImage => 'Resimden değiştir…';

  @override
  String get desktopAvatarMenuReset => 'Avatarı sıfırla';

  @override
  String get assistantEditAvatarChooseImage => 'Resim Seç';

  @override
  String get assistantEditAvatarChooseEmoji => 'Emoji\'yi seçin';

  @override
  String get assistantEditAvatarEnterLink => 'Bağlantıyı Girin';

  @override
  String get assistantEditAvatarImportQQ => 'QQ\'dan içe aktar';

  @override
  String get assistantEditAvatarReset => 'Sıfırla';

  @override
  String get displaySettingsPageChatMessageBackgroundTitle =>
      'Chat Message Background';

  @override
  String get displaySettingsPageChatMessageBackgroundDefault => 'Varsayılan';

  @override
  String get displaySettingsPageChatMessageBackgroundFrosted => 'Buzlu cam';

  @override
  String get displaySettingsPageChatMessageBackgroundSolid => 'Düz Renk';

  @override
  String get displaySettingsPageAndroidBackgroundChatTitle =>
      'Background Generation (Android)';

  @override
  String get androidBackgroundStatusOn => 'Açık';

  @override
  String get androidBackgroundStatusOff => 'Kapalı';

  @override
  String get androidBackgroundStatusOther => 'Açık ve bildir';

  @override
  String get androidBackgroundOptionOn => 'Açık';

  @override
  String get androidBackgroundOptionOnNotify => 'Açık ve tamamlandığında bildir';

  @override
  String get androidBackgroundOptionOff => 'Kapalı';

  @override
  String get notificationChatCompletedTitle => 'Üretim tamamlandı';

  @override
  String get notificationChatCompletedBody =>
      'Assistant reply has been generated';

  @override
  String get androidBackgroundNotificationTitle => 'Kelivo koşuyor';

  @override
  String get androidBackgroundNotificationText =>
      'Keeping chat generation alive in background';

  @override
  String get assistantEditEmojiDialogTitle => 'Emoji\'yi seçin';

  @override
  String get assistantEditEmojiDialogHint => 'Herhangi bir emojiyi yazın veya yapıştırın';

  @override
  String get assistantEditEmojiDialogCancel => 'İptal etmek';

  @override
  String get assistantEditEmojiDialogSave => 'Kaydetmek';

  @override
  String get assistantEditImageUrlDialogTitle => 'Resim URL\'sini girin';

  @override
  String get assistantEditImageUrlDialogHint =>
      'e.g. https://example.com/avatar.png';

  @override
  String get assistantEditImageUrlDialogCancel => 'İptal etmek';

  @override
  String get assistantEditImageUrlDialogSave => 'Kaydetmek';

  @override
  String get assistantEditQQAvatarDialogTitle => 'QQ\'dan içe aktar';

  @override
  String get assistantEditQQAvatarDialogHint => 'QQ numarasını girin (5-12 haneli)';

  @override
  String get assistantEditQQAvatarRandomButton => 'Rastgele Bir';

  @override
  String get assistantEditQQAvatarFailedMessage =>
      'Failed to fetch random QQ avatar. Please try again.';

  @override
  String get assistantEditQQAvatarDialogCancel => 'İptal etmek';

  @override
  String get assistantEditQQAvatarDialogSave => 'Kaydetmek';

  @override
  String get assistantEditGalleryErrorMessage =>
      'Unable to open gallery. Try entering an image URL.';

  @override
  String get assistantEditGeneralErrorMessage =>
      'Something went wrong. Try entering an image URL.';

  @override
  String get providerDetailPageMultiKeyModeTitle => 'Çoklu Tuş Modu';

  @override
  String get providerDetailPageManageKeysButton => 'Anahtarları Yönet';

  @override
  String get multiKeyPageTitle => 'Çoklu Tuş Yöneticisi';

  @override
  String get multiKeyPageDetect => 'Tespit etmek';

  @override
  String get multiKeyPageAdd => 'Eklemek';

  @override
  String get multiKeyPageAddHint =>
      'Enter API keys, separated by comma or space';

  @override
  String multiKeyPageImportedSnackbar(int n) {
    return 'İçe aktarılan ${n} anahtarlar';
  }

  @override
  String get multiKeyPagePleaseAddModel => 'Lütfen önce bir model ekleyin';

  @override
  String get multiKeyPageTotal => 'Toplam';

  @override
  String get multiKeyPageNormal => 'Normal';

  @override
  String get multiKeyPageError => 'Hata';

  @override
  String get multiKeyPageAccuracy => 'Kesinlik';

  @override
  String get multiKeyPageStrategyTitle => 'Yük Dengeleme Stratejisi';

  @override
  String get multiKeyPageStrategyRoundRobin => 'Yuvarlak Robin';

  @override
  String get multiKeyPageStrategyPriority => 'Öncelik';

  @override
  String get multiKeyPageStrategyLeastUsed => 'En Az Kullanılan';

  @override
  String get multiKeyPageStrategyRandom => 'Rastgele';

  @override
  String get multiKeyPageNoKeys => 'API anahtarı yok';

  @override
  String get multiKeyPageStatusActive => 'Aktif';

  @override
  String get multiKeyPageStatusDisabled => 'Engelli';

  @override
  String get multiKeyPageStatusError => 'Hata';

  @override
  String get multiKeyPageStatusRateLimited => 'Oran Sınırlı';

  @override
  String get multiKeyPageEditAlias => 'Takma Adı Düzenle';

  @override
  String get multiKeyPageEdit => 'Düzenlemek';

  @override
  String get multiKeyPageKey => 'API Anahtarı';

  @override
  String get multiKeyPagePriority => 'Öncelik (1–10)';

  @override
  String get multiKeyPageDuplicateKeyWarning => 'Bu anahtar zaten mevcut';

  @override
  String get multiKeyPageAlias => 'Takma ad';

  @override
  String get multiKeyPageCancel => 'İptal etmek';

  @override
  String get multiKeyPageSave => 'Kaydetmek';

  @override
  String get multiKeyPageDelete => 'Silmek';

  @override
  String get assistantEditSystemPromptTitle => 'Sistem İstemi';

  @override
  String get assistantEditSystemPromptHint => 'Sistem istemini girin…';

  @override
  String get assistantEditSystemPromptImportButton => 'Dosyayı içe aktar';

  @override
  String get assistantEditSystemPromptImportSuccess =>
      'System prompt updated from file';

  @override
  String get assistantEditSystemPromptImportFailed => 'Dosya içe aktarılamadı';

  @override
  String get assistantEditSystemPromptImportEmpty => 'Dosya boş';

  @override
  String get assistantEditAvailableVariables => 'Mevcut değişkenler:';

  @override
  String get assistantEditVariableDate => 'Tarih';

  @override
  String get assistantEditVariableTime => 'Zaman';

  @override
  String get assistantEditVariableDatetime => 'Tarihsaat';

  @override
  String get assistantEditVariableModelId => 'Model Kimliği';

  @override
  String get assistantEditVariableModelName => 'Model Adı';

  @override
  String get assistantEditVariableLocale => 'Yerel ayar';

  @override
  String get assistantEditVariableTimezone => 'Saat dilimi';

  @override
  String get assistantEditVariableSystemVersion => 'Sistem Sürümü';

  @override
  String get assistantEditVariableDeviceInfo => 'Cihaz Bilgisi';

  @override
  String get assistantEditVariableBatteryLevel => 'Pil Seviyesi';

  @override
  String get assistantEditVariableNickname => 'Takma ad';

  @override
  String get assistantEditVariableAssistantName => 'Asistan Adı';

  @override
  String get assistantEditMessageTemplateTitle => 'Mesaj Şablonu';

  @override
  String get assistantEditVariableRole => 'Rol';

  @override
  String get assistantEditVariableMessage => 'Mesaj';

  @override
  String get assistantEditPreviewTitle => 'Önizleme';

  @override
  String get codeBlockPreviewButton => 'Önizleme';

  @override
  String codeBlockCollapsedLines(int n) {
    return '… ${n} satır katlanmış';
  }

  @override
  String get htmlPreviewNotSupportedOnLinux =>
      'HTML preview is not supported on Linux';

  @override
  String get assistantEditSampleUser => 'Kullanıcı';

  @override
  String get assistantEditSampleMessage => 'Selamlar';

  @override
  String get assistantEditSampleReply => 'Merhaba, size nasıl yardımcı olabilirim?';

  @override
  String get assistantEditMcpNoServersMessage => 'Çalışan MCP sunucusu yok';

  @override
  String get assistantEditMcpConnectedTag => 'Bağlı';

  @override
  String assistantEditMcpToolsCountTag(String enabled, String total) {
    return 'Araçlar: ${enabled}/${total}';
  }

  @override
  String get assistantEditModelUseGlobalDefault => 'Genel varsayılanı kullan';

  @override
  String get assistantSettingsPageTitle => 'Asistan Ayarları';

  @override
  String get assistantSettingsDefaultTag => 'Varsayılan';

  @override
  String get assistantSettingsCopyButton => 'Kopyala';

  @override
  String get assistantSettingsCopySuccess => 'Asistan kopyalandı';

  @override
  String get assistantSettingsCopySuffix => 'Kopyala';

  @override
  String get assistantSettingsDeleteButton => 'Silmek';

  @override
  String get assistantSettingsEditButton => 'Düzenlemek';

  @override
  String get assistantSettingsAddSheetTitle => 'Asistan Adı';

  @override
  String get assistantSettingsAddSheetHint => 'Bir ad girin';

  @override
  String get assistantSettingsAddSheetCancel => 'İptal etmek';

  @override
  String get assistantSettingsAddSheetSave => 'Kaydetmek';

  @override
  String get desktopAssistantsListTitle => 'Asistanlar';

  @override
  String get desktopSidebarTabAssistants => 'Asistanlar';

  @override
  String get desktopSidebarTabTopics => 'Konular';

  @override
  String get desktopTrayMenuShowWindow => 'Pencereyi Göster';

  @override
  String get desktopTrayMenuExit => 'Çıkış';

  @override
  String get hotkeyToggleAppVisibility => 'Uygulamayı Göster/Gizle';

  @override
  String get hotkeyCloseWindow => 'Pencereyi Kapat';

  @override
  String get hotkeyOpenSettings => 'Ayarları Aç';

  @override
  String get hotkeyNewTopic => 'Yeni Konu';

  @override
  String get hotkeySwitchModel => 'Modeli Değiştir';

  @override
  String get hotkeyToggleAssistantPanel => 'Asistanları Değiştir';

  @override
  String get hotkeyToggleTopicPanel => 'Konuları Değiştir';

  @override
  String get hotkeysPressShortcut => 'Bir kısayola basın';

  @override
  String get hotkeysResetDefault => 'Varsayılana sıfırla';

  @override
  String get hotkeysClearShortcut => 'Kısayolu temizle';

  @override
  String get hotkeysResetAll => 'Tümünü varsayılanlara sıfırla';

  @override
  String get assistantEditTemperatureTitle => 'Sıcaklık';

  @override
  String get assistantEditTopPTitle => 'Üst-p';

  @override
  String get assistantSettingsDeleteDialogTitle => 'Asistanı Sil';

  @override
  String get assistantSettingsDeleteDialogContent =>
      'Are you sure you want to delete this assistant? This action cannot be undone.';

  @override
  String get assistantSettingsDeleteDialogCancel => 'İptal etmek';

  @override
  String get assistantSettingsDeleteDialogConfirm => 'Silmek';

  @override
  String get assistantSettingsAtLeastOneAssistantRequired =>
      'At least one assistant is required';

  @override
  String get mcpAssistantSheetTitle => 'MCP Sunucuları';

  @override
  String get mcpAssistantSheetSubtitle => 'Bu asistan için etkinleştirilen sunucular';

  @override
  String get mcpAssistantSheetSelectAll => 'Tümünü Seç';

  @override
  String get mcpAssistantSheetClearAll => 'Temizlemek';

  @override
  String get backupPageTitle => 'Yedekleme ve Geri Yükleme';

  @override
  String get backupPageWebDavTab => 'WebDAV';

  @override
  String get backupPageImportExportTab => 'İçe/Dışa Aktarma';

  @override
  String get backupPageWebDavServerUrl => 'WebDAV Sunucusu URL\'si';

  @override
  String get backupPageUsername => 'Kullanıcı adı';

  @override
  String get backupPagePassword => 'Şifre';

  @override
  String get backupPagePath => 'Yol';

  @override
  String get backupPageChatsLabel => 'Sohbetler';

  @override
  String get backupPageFilesLabel => 'Dosyalar';

  @override
  String get backupPageTestDone => 'Test tamamlandı';

  @override
  String get backupPageTestConnection => 'Test';

  @override
  String get backupPageRestartRequired => 'Yeniden Başlatma Gerekli';

  @override
  String get backupPageRestartContent =>
      'Restore completed. Please restart the app.';

  @override
  String get backupPageOK => 'TAMAM';

  @override
  String get backupPageCancel => 'İptal etmek';

  @override
  String get backupPageSelectImportMode => 'İçe Aktarma Modunu Seçin';

  @override
  String get backupPageSelectImportModeDescription =>
      'Choose how to import the backup data:';

  @override
  String get backupPageOverwriteMode => 'Üzerine Yazmayı Tamamla';

  @override
  String get backupPageOverwriteModeDescription =>
      'Clear all local data and restore from backup';

  @override
  String get backupPageMergeMode => 'Akıllı Birleştirme';

  @override
  String get backupPageMergeModeDescription =>
      'Add only non-existing data (intelligent deduplication)';

  @override
  String get backupPageRestore => 'Eski haline getirmek';

  @override
  String get backupPageBackupUploaded => 'Yedekleme yüklendi';

  @override
  String get backupPageBackup => 'Yedekleme';

  @override
  String get backupPageExporting => 'Dışa aktarılıyor...';

  @override
  String get backupPageExportToFile => 'Dosyaya Aktar';

  @override
  String get backupPageExportToFileSubtitle => 'Uygulama verilerini bir dosyaya aktarın';

  @override
  String get backupPageImportBackupFile => 'Yedekleme Dosyasını İçe Aktar';

  @override
  String get backupPageImportBackupFileSubtitle => 'Yerel bir yedekleme dosyasını içe aktarın';

  @override
  String get backupPageImportFromOtherApps => 'Diğer Uygulamalardan İçe Aktar';

  @override
  String get backupPageImportFromRikkaHub => 'RikkaHub\'tan içe aktar';

  @override
  String get backupPageNotSupportedYet => 'Henüz desteklenmiyor';

  @override
  String get backupPageRemoteBackups => 'Uzaktan Yedeklemeler';

  @override
  String get backupPageNoBackups => 'Yedekleme yok';

  @override
  String get backupPageRestoreTooltip => 'Eski haline getirmek';

  @override
  String get backupPageDeleteTooltip => 'Silmek';

  @override
  String get backupPageDeleteConfirmTitle => 'Silmeyi Onayla';

  @override
  String backupPageDeleteConfirmContent(Object name) {
    return '"${name}" uzaktan yedeklemesini silmek istediğinizden emin misiniz? Bu eylem geri alınamaz.';
  }

  @override
  String get backupPageBackupManagement => 'Yedekleme Yönetimi';

  @override
  String get backupPageWebDavBackup => 'WebDAV Yedekleme';

  @override
  String get backupPageWebDavServerSettings => 'WebDAV Sunucu Ayarları';

  @override
  String get backupPageS3Backup => 'S3 Yedekleme';

  @override
  String get backupPageS3ServerSettings => 'S3 Ayarları';

  @override
  String get backupPageS3Endpoint => 'Uç nokta';

  @override
  String get backupPageS3Region => 'Bölge';

  @override
  String get backupPageS3Bucket => 'Kova';

  @override
  String get backupPageS3AccessKeyId => 'Erişim Anahtarı Kimliği';

  @override
  String get backupPageS3SecretAccessKey => 'Gizli Erişim Anahtarı';

  @override
  String get backupPageS3SessionToken => 'Oturum Jetonu (İsteğe Bağlı)';

  @override
  String get backupPageS3Prefix => 'Önek';

  @override
  String get backupPageS3PathStyle => 'Yol stili adresleme';

  @override
  String get backupPageSave => 'Kaydetmek';

  @override
  String get backupPageBackupNow => 'Şimdi Yedekle';

  @override
  String get backupPageLocalBackup => 'Yerel Yedekleme';

  @override
  String get backupPageImportFromCherryStudio => 'Cherry Studio\'dan içe aktar';

  @override
  String get backupPageImportFromChatbox => 'Chatbox\'tan içe aktar';

  @override
  String get chatHistoryPageTitle => 'Sohbet Geçmişi';

  @override
  String get chatHistoryPageSearchTooltip => 'Aramak';

  @override
  String get chatHistoryPageDeleteAllTooltip => 'Sabitlenmemişleri Sil';

  @override
  String get chatHistoryPageDeleteAllDialogTitle =>
      'Delete Unpinned Conversations';

  @override
  String get chatHistoryPageDeleteAllDialogContent =>
      'Delete every non-pinned conversation for this assistant? Pinned chats stay in place.';

  @override
  String get chatHistoryPageCancel => 'İptal etmek';

  @override
  String get chatHistoryPageDelete => 'Silmek';

  @override
  String get chatHistoryPageDeletedAllSnackbar =>
      'Unpinned conversations deleted';

  @override
  String get chatHistoryPageSearchHint => 'Konuşmaları arayın';

  @override
  String get chatHistoryPageNoConversations => 'Konuşma yok';

  @override
  String get chatHistoryPagePinnedSection => 'Sabitlendi';

  @override
  String get chatHistoryPagePin => 'Sabitle';

  @override
  String get chatHistoryPagePinned => 'Sabitlendi';

  @override
  String get messageEditPageTitle => 'Mesajı Düzenle';

  @override
  String get messageEditPageSave => 'Kaydetmek';

  @override
  String get messageEditPageSaveAndSend => 'Kaydet ve Gönder';

  @override
  String get messageEditPageHint => 'Mesajı girin…';

  @override
  String get selectCopyPageTitle => 'Seç ve Kopyala';

  @override
  String get selectCopyPageCopyAll => 'Tümünü Kopyala';

  @override
  String get selectCopyPageCopiedAll => 'Tümü kopyalandı';

  @override
  String get bottomToolsSheetCamera => 'Kamera';

  @override
  String get bottomToolsSheetPhotos => 'Fotoğraflar';

  @override
  String get bottomToolsSheetUpload => 'Yüklemek';

  @override
  String get bottomToolsSheetClearContext => 'İçeriği Temizle';

  @override
  String get compressContext => 'İçeriği Sıkıştır';

  @override
  String get compressContextDesc => 'Özetleyin ve yeni bir sohbet başlatın';

  @override
  String get clearContextDesc => 'Bağlam sınırını işaretleme';

  @override
  String get contextManagement => 'Bağlam Yönetimi';

  @override
  String get compressingContext => 'Bağlam sıkıştırılıyor...';

  @override
  String get compressContextFailed => 'Bağlam sıkıştırılamadı';

  @override
  String get compressContextNoMessages => 'Sıkıştırılacak mesaj yok';

  @override
  String get bottomToolsSheetLearningMode => 'Öğrenme Modu';

  @override
  String get bottomToolsSheetLearningModeDescription =>
      'Help you learn step by step';

  @override
  String get bottomToolsSheetConfigurePrompt => 'İstemi yapılandır';

  @override
  String get bottomToolsSheetPrompt => 'Çabuk';

  @override
  String get bottomToolsSheetPromptHint => 'Enjekte edilecek bilgi istemi metnini girin';

  @override
  String get bottomToolsSheetResetDefault => 'Varsayılana sıfırla';

  @override
  String get bottomToolsSheetSave => 'Kaydetmek';

  @override
  String get bottomToolsSheetOcr => 'Görüntü OCR\'si';

  @override
  String get messageMoreSheetTitle => 'Daha Fazla Eylem';

  @override
  String get messageMoreSheetSelectCopy => 'Seç ve Kopyala';

  @override
  String get messageMoreSheetRenderWebView => 'Web Görünümünü Oluştur';

  @override
  String get messageMoreSheetNotImplemented => 'Henüz uygulanmadı';

  @override
  String get messageMoreSheetEdit => 'Düzenlemek';

  @override
  String get messageMoreSheetShare => 'Paylaşmak';

  @override
  String get messageMoreSheetCreateBranch => 'Şube Oluştur';

  @override
  String get messageMoreSheetDelete => 'Silmek';

  @override
  String get reasoningBudgetSheetOff => 'Kapalı';

  @override
  String get reasoningBudgetSheetAuto => 'Otomatik';

  @override
  String get reasoningBudgetSheetLight => 'Hafif Muhakeme';

  @override
  String get reasoningBudgetSheetMedium => 'Orta Muhakeme';

  @override
  String get reasoningBudgetSheetHeavy => 'Ağır Muhakeme';

  @override
  String get reasoningBudgetSheetXhigh => 'Aşırı Muhakeme';

  @override
  String get reasoningBudgetSheetTitle => 'Muhakeme Zinciri Gücü';

  @override
  String reasoningBudgetSheetCurrentLevel(String level) {
    return 'Mevcut Seviye: ${level}';
  }

  @override
  String get reasoningBudgetSheetOffSubtitle =>
      'Turn off reasoning, answer directly';

  @override
  String get reasoningBudgetSheetAutoSubtitle =>
      'Let the model decide reasoning level automatically';

  @override
  String get reasoningBudgetSheetLightSubtitle =>
      'Use light reasoning to answer questions';

  @override
  String get reasoningBudgetSheetMediumSubtitle =>
      'Use moderate reasoning to answer questions';

  @override
  String get reasoningBudgetSheetHeavySubtitle =>
      'Use heavy reasoning for complex questions';

  @override
  String get reasoningBudgetSheetXhighSubtitle =>
      'Use maximum reasoning depth for the toughest problems';

  @override
  String get reasoningBudgetSheetCustomLabel =>
      'Custom Reasoning Budget (tokens)';

  @override
  String get reasoningBudgetSheetCustomHint => 'örneğin 2048 (-1 otomatik, 0 kapalı)';

  @override
  String chatMessageWidgetFileNotFound(String fileName) {
    return 'Dosya bulunamadı: ${fileName}';
  }

  @override
  String chatMessageWidgetCannotOpenFile(String message) {
    return 'Dosya açılamıyor: ${message}';
  }

  @override
  String chatMessageWidgetOpenFileError(String error) {
    return 'Dosya açılamadı: ${error}';
  }

  @override
  String get chatMessageWidgetCopiedToClipboard => 'Panoya kopyalandı';

  @override
  String get chatMessageWidgetResendTooltip => 'Yeniden gönder';

  @override
  String get chatMessageWidgetMoreTooltip => 'Daha';

  @override
  String get chatMessageWidgetThinking => 'Düşünüyorum...';

  @override
  String get chatMessageWidgetTranslation => 'Çeviri';

  @override
  String get chatMessageWidgetTranslating => 'Çeviri...';

  @override
  String get chatMessageWidgetCitationNotFound => 'Alıntı kaynağı bulunamadı';

  @override
  String chatMessageWidgetCannotOpenUrl(String url) {
    return 'Bağlantı açılamıyor: ${url}';
  }

  @override
  String get chatMessageWidgetOpenLinkError => 'Bağlantı açılamadı';

  @override
  String chatMessageWidgetCitationsTitle(int count) {
    return 'Alıntılar (${count})';
  }

  @override
  String get chatMessageWidgetRegenerateTooltip => 'Yenile';

  @override
  String get chatMessageWidgetRegenerateConfirmTitle => 'Yeniden Oluşturmayı Onayla';

  @override
  String get chatMessageWidgetRegenerateConfirmContent =>
      'Regenerating will overwrite all messages after this one and cannot be undone. Are you sure?';

  @override
  String get chatMessageWidgetRegenerateConfirmCancel => 'İptal etmek';

  @override
  String get chatMessageWidgetRegenerateConfirmOk => 'Yenile';

  @override
  String get chatMessageWidgetStopTooltip => 'Durmak';

  @override
  String get chatMessageWidgetSpeakTooltip => 'Konuşmak';

  @override
  String get chatMessageWidgetTranslateTooltip => 'Çevir';

  @override
  String get chatMessageWidgetBuiltinSearchHideNote =>
      'Hide builtin search tool cards';

  @override
  String get chatMessageWidgetDeepThinking => 'Derin Düşünme';

  @override
  String get chatMessageWidgetCreateMemory => 'Bellek Oluştur';

  @override
  String get chatMessageWidgetEditMemory => 'Belleği Düzenle';

  @override
  String get chatMessageWidgetDeleteMemory => 'Belleği Sil';

  @override
  String chatMessageWidgetWebSearch(String query) {
    return 'Web Araması: ${query}';
  }

  @override
  String get chatMessageWidgetBuiltinSearch => 'Dahili Arama';

  @override
  String chatMessageWidgetToolCall(String name) {
    return 'Araç Çağrısı: ${name}';
  }

  @override
  String chatMessageWidgetToolResult(String name) {
    return 'Araç Sonucu: ${name}';
  }

  @override
  String get chatMessageWidgetNoResultYet => '(Henüz sonuç yok)';

  @override
  String get chatMessageWidgetArguments => 'Argümanlar';

  @override
  String get chatMessageWidgetResult => 'Sonuç';

  @override
  String get chatMessageWidgetImages => 'Görseller';

  @override
  String chatMessageWidgetCitationsCount(int count) {
    return 'Alıntılar (${count})';
  }

  @override
  String chatSelectionSelectedCountTitle(int count) {
    return 'Seçilen ${count} mesaj(lar)';
  }

  @override
  String get chatSelectionExportTxt => 'TXT';

  @override
  String get chatSelectionExportMd => 'MD';

  @override
  String get chatSelectionExportImage => 'Resim';

  @override
  String get chatSelectionThinkingTools => 'Düşünme araçları';

  @override
  String get chatSelectionThinkingContent => 'İçerik düşünme';

  @override
  String get messageExportSheetAssistant => 'Asistan';

  @override
  String get messageExportSheetDefaultTitle => 'Yeni Sohbet';

  @override
  String get messageExportSheetExporting => 'Dışa aktarılıyor…';

  @override
  String messageExportSheetExportFailed(String error) {
    return 'Dışa aktarma başarısız oldu: ${error}';
  }

  @override
  String messageExportSheetExportedAs(String filename) {
    return '${filename} olarak dışa aktarıldı';
  }

  @override
  String get displaySettingsPageEnableDollarLatexTitle =>
      'Inline \$...\$ Rendering';

  @override
  String get displaySettingsPageEnableDollarLatexSubtitle =>
      'Render inline math inside \$...\$';

  @override
  String get displaySettingsPageEnableMathTitle => 'Matematik Formülü Oluşturma';

  @override
  String get displaySettingsPageEnableMathSubtitle =>
      'Render LaTeX math (inline and block)';

  @override
  String get displaySettingsPageEnableUserMarkdownTitle =>
      'Render user messages with Markdown';

  @override
  String get displaySettingsPageEnableReasoningMarkdownTitle =>
      'Render reasoning (thinking) with Markdown';

  @override
  String get displaySettingsPageEnableAssistantMarkdownTitle =>
      'Render assistant messages with Markdown';

  @override
  String get displaySettingsPageMobileCodeBlockWrapTitle =>
      'Mobile Code Block Word Wrap';

  @override
  String get displaySettingsPageAutoCollapseCodeBlockTitle =>
      'Auto-collapse Code Blocks';

  @override
  String get displaySettingsPageAutoCollapseCodeBlockLinesTitle =>
      'Auto-collapse threshold';

  @override
  String get displaySettingsPageAutoCollapseCodeBlockLinesUnit => 'çizgiler';

  @override
  String get messageExportSheetFormatTitle => 'Dışa Aktarma Formatı';

  @override
  String get messageExportSheetMarkdown => 'İndirim';

  @override
  String get messageExportSheetSingleMarkdownSubtitle =>
      'Export this message as a Markdown file';

  @override
  String get messageExportSheetBatchMarkdownSubtitle =>
      'Export selected messages as a Markdown file';

  @override
  String get messageExportSheetPlainText => 'Düz Metin';

  @override
  String get messageExportSheetSingleTxtSubtitle =>
      'Export this message as a TXT file';

  @override
  String get messageExportSheetBatchTxtSubtitle =>
      'Export selected messages as a TXT file';

  @override
  String get messageExportSheetExportImage => 'Resim Olarak Dışa Aktar';

  @override
  String get messageExportSheetSingleExportImageSubtitle =>
      'Render this message to a PNG image';

  @override
  String get messageExportSheetBatchExportImageSubtitle =>
      'Render selected messages to a PNG image';

  @override
  String get messageExportSheetShowThinkingAndToolCards =>
      'Show Deep Thinking and tool cards';

  @override
  String get messageExportSheetShowThinkingContent => 'Düşünme içeriğini göster';

  @override
  String get messageExportThinkingContentLabel => 'İçerik düşünme';

  @override
  String get messageExportSheetDateTimeWithSecondsPattern =>
      'yyyy-MM-dd HH:mm:ss';

  @override
  String get exportDisclaimerAiGenerated =>
      'Content generated by AI. Please verify carefully.';

  @override
  String get imagePreviewSheetSaveImage => 'Resmi Kaydet';

  @override
  String get imagePreviewSheetSaveSuccess => 'Galeriye kaydedildi';

  @override
  String imagePreviewSheetSaveFailed(String error) {
    return 'Kaydetme başarısız oldu: ${error}';
  }

  @override
  String get sideDrawerMenuRename => 'Yeniden isimlendirmek';

  @override
  String get sideDrawerMenuPin => 'Sabitle';

  @override
  String get sideDrawerMenuUnpin => 'Sabitlemeyi kaldır';

  @override
  String get sideDrawerMenuRegenerateTitle => 'Başlığı Yeniden Oluştur';

  @override
  String get sideDrawerMenuMoveTo => 'Şuraya taşı:';

  @override
  String get sideDrawerMenuDelete => 'Silmek';

  @override
  String sideDrawerDeleteSnackbar(String title) {
    return '"${title}" silindi';
  }

  @override
  String get sideDrawerRenameHint => 'Yeni adı girin';

  @override
  String get sideDrawerCancel => 'İptal etmek';

  @override
  String get sideDrawerOK => 'TAMAM';

  @override
  String get sideDrawerSave => 'Kaydetmek';

  @override
  String get sideDrawerGreetingMorning => 'Günaydın 👋';

  @override
  String get sideDrawerGreetingNoon => 'İyi günler 👋';

  @override
  String get sideDrawerGreetingAfternoon => 'İyi günler 👋';

  @override
  String get sideDrawerGreetingEvening => 'İyi akşamlar 👋';

  @override
  String get sideDrawerDateToday => 'Bugün';

  @override
  String get sideDrawerDateYesterday => 'Dün';

  @override
  String get sideDrawerDateShortPattern => 'MMM d';

  @override
  String get sideDrawerDateFullPattern => 'MMM d, yyyy';

  @override
  String get sideDrawerSearchHint => 'Mevcut asistanı ara';

  @override
  String get sideDrawerSearchAssistantsHint => 'Arama asistanları';

  @override
  String get sideDrawerTopicSearchModeLabel => 'Konu modu';

  @override
  String get sideDrawerGlobalSearchModeLabel => 'Küresel mod';

  @override
  String get sideDrawerSearchModeSwipeToTopicHint =>
      'Swipe the search bar for topic search';

  @override
  String get sideDrawerSearchModeSwipeToGlobalHint =>
      'Swipe the search bar for global search';

  @override
  String get sideDrawerGlobalSearchHint => 'Tüm oturumları ara';

  @override
  String get sideDrawerGlobalSearchEmptyHint =>
      'Search across titles and messages';

  @override
  String get sideDrawerGlobalSearchNoResults => 'Eşleşen oturum yok';

  @override
  String sideDrawerGlobalSearchResultCount(int count) {
    return '${count} sonuçlar';
  }

  @override
  String sideDrawerUpdateTitle(String version) {
    return 'Yeni sürüm: ${version}';
  }

  @override
  String sideDrawerUpdateTitleWithBuild(String version, int build) {
    return 'Yeni sürüm: ${version} (${build})';
  }

  @override
  String get sideDrawerLinkCopied => 'Bağlantı kopyalandı';

  @override
  String get sideDrawerPinnedLabel => 'Sabitlendi';

  @override
  String get sideDrawerHistory => 'Tarih';

  @override
  String get sideDrawerSettings => 'Ayarlar';

  @override
  String get sideDrawerChooseAssistantTitle => 'Asistan\'ı seçin';

  @override
  String get sideDrawerChooseImage => 'Resim Seç';

  @override
  String get sideDrawerChooseEmoji => 'Emoji\'yi seçin';

  @override
  String get sideDrawerEnterLink => 'Bağlantıyı Girin';

  @override
  String get sideDrawerImportFromQQ => 'QQ\'dan içe aktar';

  @override
  String get sideDrawerReset => 'Sıfırla';

  @override
  String get sideDrawerEmojiDialogTitle => 'Emoji\'yi seçin';

  @override
  String get sideDrawerEmojiDialogHint => 'Herhangi bir emojiyi yazın veya yapıştırın';

  @override
  String get sideDrawerImageUrlDialogTitle => 'Resim URL\'sini girin';

  @override
  String get sideDrawerImageUrlDialogHint =>
      'e.g. https://example.com/avatar.png';

  @override
  String get sideDrawerQQAvatarDialogTitle => 'QQ\'dan içe aktar';

  @override
  String get sideDrawerQQAvatarInputHint => 'QQ numarasını girin (5-12 haneli)';

  @override
  String get sideDrawerQQAvatarFetchFailed =>
      'Failed to fetch random QQ avatar. Please try again.';

  @override
  String get sideDrawerRandomQQ => 'Rastgele QQ';

  @override
  String get sideDrawerGalleryOpenError =>
      'Unable to open gallery. Try entering an image URL.';

  @override
  String get sideDrawerGeneralImageError =>
      'Something went wrong. Try entering an image URL.';

  @override
  String get sideDrawerSetNicknameTitle => 'Takma Ad Belirle';

  @override
  String get sideDrawerNicknameLabel => 'Takma ad';

  @override
  String get sideDrawerNicknameHint => 'Yeni takma adı girin';

  @override
  String get sideDrawerRename => 'Yeniden isimlendirmek';

  @override
  String get chatInputBarHint => 'AI için bir mesaj yazın';

  @override
  String get chatInputBarSelectModelTooltip => 'Modeli Seçin';

  @override
  String get chatInputBarOnlineSearchTooltip => 'Çevrimiçi Arama';

  @override
  String get chatInputBarReasoningStrengthTooltip => 'Muhakeme Gücü';

  @override
  String get chatInputBarMcpServersTooltip => 'MCP Sunucuları';

  @override
  String get chatInputBarMoreTooltip => 'Eklemek';

  @override
  String get chatInputBarInsertNewline => 'Yeni satır';

  @override
  String get chatInputBarExpand => 'Genişletmek';

  @override
  String get chatInputBarCollapse => 'Yıkılmak';

  @override
  String get mcpPageBackTooltip => 'Geri';

  @override
  String get mcpPageAddMcpTooltip => 'MCP ekle';

  @override
  String get mcpPageNoServers => 'MCP sunucusu yok';

  @override
  String get mcpPageErrorDialogTitle => 'Bağlantı Hatası';

  @override
  String get mcpPageErrorNoDetails => 'Ayrıntı yok';

  @override
  String get mcpPageClose => 'Kapalı';

  @override
  String get mcpPageReconnect => 'Yeniden bağlan';

  @override
  String get mcpPageStatusConnected => 'Bağlı';

  @override
  String get mcpPageStatusConnecting => 'Bağlanıyor…';

  @override
  String get mcpPageStatusDisconnected => 'Bağlantı kesildi';

  @override
  String get mcpPageStatusDisabled => 'Engelli';

  @override
  String mcpPageToolsCount(int enabled, int total) {
    return 'Araçlar: ${enabled}/${total}';
  }

  @override
  String get mcpPageConnectionFailed => 'Bağlantı başarısız oldu';

  @override
  String get mcpPageDetails => 'Detaylar';

  @override
  String get mcpPageDelete => 'Silmek';

  @override
  String get mcpPageConfirmDeleteTitle => 'Silmeyi Onayla';

  @override
  String get mcpPageConfirmDeleteContent =>
      'This can be undone via Undo. Delete?';

  @override
  String get mcpPageServerDeleted => 'Sunucu silindi';

  @override
  String get mcpPageUndo => 'Geri al';

  @override
  String get mcpPageCancel => 'İptal etmek';

  @override
  String get mcpConversationSheetTitle => 'MCP Sunucuları';

  @override
  String get mcpConversationSheetSubtitle =>
      'Select servers enabled for this conversation';

  @override
  String get mcpConversationSheetSelectAll => 'Tümünü Seç';

  @override
  String get mcpConversationSheetClearAll => 'Temizlemek';

  @override
  String get mcpConversationSheetNoRunning => 'Çalışan MCP sunucusu yok';

  @override
  String get mcpConversationSheetConnected => 'Bağlı';

  @override
  String mcpConversationSheetToolsCount(int enabled, int total) {
    return 'Araçlar: ${enabled}/${total}';
  }

  @override
  String get mcpServerEditSheetEnabledLabel => 'Etkinleştirilmiş';

  @override
  String get mcpServerEditSheetNameLabel => 'İsim';

  @override
  String get mcpServerEditSheetTransportLabel => 'Taşıma';

  @override
  String get mcpServerEditSheetSseRetryHint => 'SSE başarısız olursa birkaç kez deneyin';

  @override
  String get mcpServerEditSheetUrlLabel => 'Sunucu URL\'si';

  @override
  String get mcpServerEditSheetCustomHeadersTitle => 'Özel Başlıklar';

  @override
  String get mcpServerEditSheetHeaderNameLabel => 'Başlık Adı';

  @override
  String get mcpServerEditSheetHeaderNameHint => 'örneğin Yetkilendirme';

  @override
  String get mcpServerEditSheetHeaderValueLabel => 'Başlık Değeri';

  @override
  String get mcpServerEditSheetHeaderValueHint => 'örneğin Taşıyıcı xxxxxx';

  @override
  String get mcpServerEditSheetRemoveHeaderTooltip => 'Kaldırmak';

  @override
  String get mcpServerEditSheetAddHeader => 'Başlık Ekle';

  @override
  String get mcpServerEditSheetTitleEdit => 'MCP\'yi düzenle';

  @override
  String get mcpServerEditSheetTitleAdd => 'MCP ekle';

  @override
  String get mcpServerEditSheetSyncToolsTooltip => 'Senkronizasyon Araçları';

  @override
  String get mcpServerEditSheetTabBasic => 'Temel';

  @override
  String get mcpServerEditSheetTabTools => 'Aletler';

  @override
  String get mcpServerEditSheetNoToolsHint => 'Araç yok, senkronize etmek için yenile\'ye dokunun';

  @override
  String get mcpServerEditSheetCancel => 'İptal etmek';

  @override
  String get mcpServerEditSheetSave => 'Kaydetmek';

  @override
  String get mcpServerEditSheetUrlRequired => 'Lütfen sunucu URL\'sini girin';

  @override
  String get defaultModelPageBackTooltip => 'Geri';

  @override
  String get defaultModelPageTitle => 'Varsayılan Model';

  @override
  String get defaultModelPageChatModelTitle => 'Sohbet Modeli';

  @override
  String get defaultModelPageChatModelSubtitle => 'Küresel varsayılan sohbet modeli';

  @override
  String get defaultModelPageTitleModelTitle => 'Başlık Özeti Modeli';

  @override
  String get defaultModelPageTitleModelSubtitle =>
      'Used for summarizing conversation titles; prefer fast & cheap models';

  @override
  String get defaultModelPageSummaryModelTitle => 'Özet Modeli';

  @override
  String get defaultModelPageSummaryModelSubtitle =>
      'Used for generating conversation summaries; prefer fast and cheap models';

  @override
  String get assistantEditRecentChatsSummaryFrequencyTitle =>
      'Summary Refresh Frequency';

  @override
  String get assistantEditRecentChatsSummaryFrequencyDescription =>
      'Refresh recent-chat summaries after the selected number of new messages.';

  @override
  String assistantEditRecentChatsSummaryFrequencyOption(int count) {
    return 'Her ${count}';
  }

  @override
  String get assistantEditRecentChatsSummaryFrequencyCustomButton => 'Gelenek';

  @override
  String get assistantEditRecentChatsSummaryFrequencyCustomTitle =>
      'Custom Summary Frequency';

  @override
  String get assistantEditRecentChatsSummaryFrequencyCustomDescription =>
      'Enter how many new messages should accumulate before refreshing the recent-chat summary.';

  @override
  String get assistantEditRecentChatsSummaryFrequencyCustomLabel =>
      'New message count';

  @override
  String get assistantEditRecentChatsSummaryFrequencyCustomHint =>
      'Enter a number greater than 0';

  @override
  String get assistantEditRecentChatsSummaryFrequencyCustomInvalid =>
      'Please enter a whole number greater than 0';

  @override
  String get defaultModelPageTranslateModelTitle => 'Çeviri Modeli';

  @override
  String get defaultModelPageTranslateModelSubtitle =>
      'Used for translating message content; prefer fast & accurate models';

  @override
  String get defaultModelPageOcrModelTitle => 'OCR Modeli';

  @override
  String get defaultModelPageOcrModelSubtitle =>
      'Used for extracting text and descriptions from images';

  @override
  String get defaultModelPagePromptLabel => 'Çabuk';

  @override
  String get defaultModelPageTitlePromptHint =>
      'Enter prompt template for title summarization';

  @override
  String get defaultModelPageSummaryPromptHint =>
      'Enter prompt template for summary generation';

  @override
  String get defaultModelPageTranslatePromptHint =>
      'Enter prompt template for translation';

  @override
  String get defaultModelPageOcrPromptHint =>
      'Enter prompt template for OCR image understanding';

  @override
  String get defaultModelPageResetDefault => 'Varsayılana sıfırla';

  @override
  String get defaultModelPageSave => 'Kaydetmek';

  @override
  String defaultModelPageTitleVars(String contentVar, String localeVar) {
    return 'Değişkenler: içerik: ${contentVar}, yerel ayar: ${localeVar}';
  }

  @override
  String defaultModelPageSummaryVars(
    String previousSummaryVar,
    String userMessagesVar,
  ) {
    return 'Değişkenler: önceki özet: ${previousSummaryVar}, yeni mesajlar: ${userMessagesVar}';
  }

  @override
  String get defaultModelPageCompressModelTitle => 'Modeli Sıkıştır';

  @override
  String get defaultModelPageCompressModelSubtitle =>
      'Used for compressing conversation context; prefer fast models';

  @override
  String get defaultModelPageCompressPromptHint =>
      'Enter prompt template for context compression';

  @override
  String defaultModelPageCompressVars(String contentVar, String localeVar) {
    return 'Değişkenler: konuşma: ${contentVar}, dil: ${localeVar}';
  }

  @override
  String defaultModelPageTranslateVars(String sourceVar, String targetVar) {
    return 'Değişkenler: kaynak metin: ${sourceVar}, hedef dil: ${targetVar}';
  }

  @override
  String get defaultModelPageUseCurrentModel => 'Mevcut sohbet modelini kullan';

  @override
  String get translatePagePasteButton => 'Yapıştır';

  @override
  String get translatePageCopyResult => 'Sonucu kopyala';

  @override
  String get translatePageClearAll => 'Tümünü Temizle';

  @override
  String get translatePageInputHint => 'Çevrilecek metni girin…';

  @override
  String get translatePageOutputHint => 'Çevrilmiş sonuç burada görünür…';

  @override
  String get modelDetailSheetAddModel => 'Model Ekle';

  @override
  String get modelDetailSheetEditModel => 'Modeli Düzenle';

  @override
  String get modelDetailSheetBasicTab => 'Temel';

  @override
  String get modelDetailSheetAdvancedTab => 'Gelişmiş';

  @override
  String get modelDetailSheetBuiltinToolsTab => 'Yerleşik Araçlar';

  @override
  String get modelDetailSheetModelIdLabel => 'Model Kimliği';

  @override
  String get modelDetailSheetModelIdHint =>
      'Required, suggest lowercase/digits/hyphens';

  @override
  String modelDetailSheetModelIdDisabledHint(String modelId) {
    return '${modelId}';
  }

  @override
  String get modelDetailSheetModelNameLabel => 'Model Adı';

  @override
  String get modelDetailSheetModelTypeLabel => 'Modeli Türü';

  @override
  String get modelDetailSheetChatType => 'Sohbet';

  @override
  String get modelDetailSheetEmbeddingType => 'Gömme';

  @override
  String get modelDetailSheetInputModesLabel => 'Giriş Modları';

  @override
  String get modelDetailSheetOutputModesLabel => 'Çıkış Modları';

  @override
  String get modelDetailSheetAbilitiesLabel => 'Yetenekler';

  @override
  String get modelDetailSheetTextMode => 'Metin';

  @override
  String get modelDetailSheetImageMode => 'Resim';

  @override
  String get modelDetailSheetToolsAbility => 'Aletler';

  @override
  String get modelDetailSheetReasoningAbility => 'muhakeme';

  @override
  String get modelDetailSheetProviderOverrideDescription =>
      'Provider overrides: customize provider for a specific model.';

  @override
  String get modelDetailSheetAddProviderOverride => 'Sağlayıcıyı Geçersiz Kılma Ekle';

  @override
  String get modelDetailSheetCustomHeadersTitle => 'Özel Başlıklar';

  @override
  String get modelDetailSheetAddHeader => 'Başlık Ekle';

  @override
  String get modelDetailSheetCustomBodyTitle => 'Özel Gövde';

  @override
  String get modelFetchInvertTooltip => 'Ters çevir';

  @override
  String get modelDetailSheetSaveFailedMessage =>
      'Save failed. Please try again.';

  @override
  String get modelDetailSheetAddBody => 'Gövde Ekle';

  @override
  String get modelDetailSheetBuiltinToolsDescription =>
      'Built-in tools only support official APIs.';

  @override
  String get modelDetailSheetGeminiCodeExecutionMutuallyExclusiveHint =>
      'Code execution cannot coexist with Search/URL Context/MCP tools.';

  @override
  String get modelDetailSheetBuiltinToolsUnsupportedHint =>
      'Current provider does not support these built-in tools.';

  @override
  String get modelDetailSheetSearchTool => 'Aramak';

  @override
  String get modelDetailSheetSearchToolDescription =>
      'Enable Google Search integration';

  @override
  String get modelDetailSheetUrlContextTool => 'URL İçeriği';

  @override
  String get modelDetailSheetUrlContextToolDescription =>
      'Enable URL content ingestion';

  @override
  String get modelDetailSheetCodeExecutionTool => 'Kod Yürütme';

  @override
  String get modelDetailSheetCodeExecutionToolDescription =>
      'Enable code execution tool';

  @override
  String get modelDetailSheetYoutubeTool => 'YouTube';

  @override
  String get modelDetailSheetYoutubeToolDescription =>
      'Enable YouTube URL ingestion (auto-detect links in prompts)';

  @override
  String get modelDetailSheetOpenaiBuiltinToolsResponsesOnlyHint =>
      'Requires OpenAI Responses API.';

  @override
  String get modelDetailSheetOpenaiCodeInterpreterTool => 'Kod Yorumlayıcı';

  @override
  String get modelDetailSheetOpenaiCodeInterpreterToolDescription =>
      'Enable code interpreter tool (container auto, memory limit 4g)';

  @override
  String get modelDetailSheetOpenaiImageGenerationTool => 'Görüntü Üretimi';

  @override
  String get modelDetailSheetOpenaiImageGenerationToolDescription =>
      'Enable image generation tool';

  @override
  String get modelDetailSheetCancelButton => 'İptal etmek';

  @override
  String get modelDetailSheetAddButton => 'Eklemek';

  @override
  String get modelDetailSheetConfirmButton => 'Onaylamak';

  @override
  String get modelDetailSheetInvalidIdError =>
      'Please enter a valid model ID (>=2 chars)';

  @override
  String get modelDetailSheetModelIdExistsError => 'Model Kimliği zaten mevcut';

  @override
  String get modelDetailSheetHeaderKeyHint => 'Başlık Anahtarı';

  @override
  String get modelDetailSheetHeaderValueHint => 'Başlık Değeri';

  @override
  String get modelDetailSheetBodyKeyHint => 'Gövde Anahtarı';

  @override
  String get modelDetailSheetBodyJsonHint => 'Gövde JSON\'u';

  @override
  String get modelSelectSheetSearchHint => 'Modelleri veya sağlayıcıları arayın';

  @override
  String get modelSelectSheetFavoritesSection => 'Favoriler';

  @override
  String get modelSelectSheetFavoriteTooltip => 'Favori';

  @override
  String get modelSelectSheetChatType => 'Sohbet';

  @override
  String get modelSelectSheetEmbeddingType => 'Gömme';

  @override
  String get providerDetailPageShareTooltip => 'Paylaşmak';

  @override
  String get providerDetailPageDeleteProviderTooltip => 'Sağlayıcıyı Sil';

  @override
  String get providerDetailPageDeleteProviderTitle => 'Sağlayıcıyı Sil';

  @override
  String get providerDetailPageDeleteProviderContent =>
      'Are you sure you want to delete this provider? This cannot be undone.';

  @override
  String get providerDetailPageCancelButton => 'İptal etmek';

  @override
  String get providerDetailPageDeleteButton => 'Silmek';

  @override
  String get providerDetailPageProviderDeletedSnackbar => 'Sağlayıcı silindi';

  @override
  String get providerDetailPageConfigTab => 'Yapılandırma';

  @override
  String get providerDetailPageModelsTab => 'Modeller';

  @override
  String get providerDetailPageNetworkTab => 'Ağ';

  @override
  String get providerDetailPageEnabledTitle => 'Etkinleştirilmiş';

  @override
  String get providerDetailPageManageSectionTitle => 'Üstesinden gelmek';

  @override
  String get providerDetailPageNameLabel => 'İsim';

  @override
  String get providerDetailPageApiKeyHint => 'Varsayılanı kullanmak için boş bırakın';

  @override
  String get providerDetailPageHideTooltip => 'Saklamak';

  @override
  String get providerDetailPageShowTooltip => 'Göstermek';

  @override
  String get providerDetailPageApiPathLabel => 'API Yolu';

  @override
  String get providerDetailPageResponseApiTitle => 'Yanıt API\'si (/yanıtlar)';

  @override
  String get providerDetailPageAihubmixAppCodeLabel => 'APP Kodu (%10 indirim)';

  @override
  String get providerDetailPageAihubmixAppCodeHelp =>
      'Adds header APP-Code requests to get a 10% discount. Only affects AIhubmix.';

  @override
  String get providerDetailPageVertexAiTitle => 'Vertex AI';

  @override
  String get providerDetailPageLocationLabel => 'Konum';

  @override
  String get providerDetailPageProjectIdLabel => 'Proje Kimliği';

  @override
  String get providerDetailPageServiceAccountJsonLabel =>
      'Service Account JSON (paste or import)';

  @override
  String get providerDetailPageImportJsonButton => 'JSON\'u içe aktar';

  @override
  String get providerDetailPageImportJsonReadFailedMessage =>
      'Failed to read file';

  @override
  String get providerDetailPageTestButton => 'Test';

  @override
  String get providerDetailPageSaveButton => 'Kaydetmek';

  @override
  String get providerDetailPageProviderRemovedMessage => 'Sağlayıcı kaldırıldı';

  @override
  String get providerDetailPageNoModelsTitle => 'Model Yok';

  @override
  String get providerDetailPageNoModelsSubtitle =>
      'Tap the buttons below to add models';

  @override
  String get providerDetailPageDeleteModelButton => 'Silmek';

  @override
  String get providerDetailPageConfirmDeleteTitle => 'Silmeyi Onayla';

  @override
  String get providerDetailPageConfirmDeleteContent =>
      'This can be undone via Undo. Delete?';

  @override
  String get providerDetailPageModelDeletedSnackbar => 'Model silindi';

  @override
  String get providerDetailPageUndoButton => 'Geri al';

  @override
  String get providerDetailPageAddNewModelButton => 'Model Ekle';

  @override
  String get providerDetailPageFetchModelsButton => 'Gidip getirmek';

  @override
  String get providerDetailPageEnableProxyTitle => 'Proxy\'yi Etkinleştir';

  @override
  String get providerDetailPageHostLabel => 'Ev sahibi';

  @override
  String get providerDetailPagePortLabel => 'Liman';

  @override
  String get providerDetailPageUsernameOptionalLabel => 'Kullanıcı adı (isteğe bağlı)';

  @override
  String get providerDetailPagePasswordOptionalLabel => 'Şifre (isteğe bağlı)';

  @override
  String get providerDetailPageSavedSnackbar => 'Kaydedildi';

  @override
  String get providerDetailPageEmbeddingsGroupTitle => 'Gömmeler';

  @override
  String get providerDetailPageOtherModelsGroupTitle => 'Diğer';

  @override
  String get providerDetailPageRemoveGroupTooltip => 'Grubu kaldır';

  @override
  String get providerDetailPageAddGroupTooltip => 'Grup ekle';

  @override
  String get providerDetailPageFilterHint => 'Filtrelenecek model adını yazın';

  @override
  String get providerDetailPageDeleteText => 'Silmek';

  @override
  String get providerDetailPageEditTooltip => 'Düzenlemek';

  @override
  String get providerDetailPageTestConnectionTitle => 'Bağlantıyı Test Et';

  @override
  String get providerDetailPageSelectModelButton => 'Modeli Seçin';

  @override
  String get providerDetailPageChangeButton => 'Değiştirmek';

  @override
  String get providerDetailPageUseStreamingLabel => 'Akışı Kullan';

  @override
  String get providerDetailPageTestingMessage => 'Test…';

  @override
  String get providerDetailPageTestSuccessMessage => 'Başarı';

  @override
  String get providersPageTitle => 'Sağlayıcılar';

  @override
  String get providersPageImportTooltip => 'İçe aktarmak';

  @override
  String get providersPageAddTooltip => 'Eklemek';

  @override
  String get providersPageSearchHint => 'Sağlayıcıları veya grupları arayın';

  @override
  String get providersPageProviderAddedSnackbar => 'Sağlayıcı eklendi';

  @override
  String get providerGroupsGroupLabel => 'Grup';

  @override
  String get providerGroupsOther => 'Diğer';

  @override
  String get providerGroupsOtherUngroupedOption => 'Diğer (Gruplanmamış)';

  @override
  String get providerGroupsPickerTitle => 'Grup seç';

  @override
  String get providerGroupsManageTitle => 'Grupları yönet';

  @override
  String get providerGroupsManageAction => 'Grupları yönet';

  @override
  String get providerGroupsCreateNewGroupAction => 'Yeni grup…';

  @override
  String get providerGroupsCreateDialogTitle => 'Yeni grup';

  @override
  String get providerGroupsNameHint => 'Grup adı';

  @override
  String get providerGroupsCreateDialogCancel => 'İptal etmek';

  @override
  String get providerGroupsCreateDialogOk => 'Yaratmak';

  @override
  String get providerGroupsCreateFailedToast => 'Grup oluşturulamadı';

  @override
  String get providerGroupsDeleteConfirmTitle => 'Grup silinsin mi?';

  @override
  String get providerGroupsDeleteConfirmContent =>
      'Providers in this group will be moved to “Other”.';

  @override
  String get providerGroupsDeleteConfirmCancel => 'İptal etmek';

  @override
  String get providerGroupsDeleteConfirmOk => 'Silmek';

  @override
  String get providerGroupsDeletedToast => 'Grup silindi';

  @override
  String get providerGroupsEmptyState => 'Henüz grup yok.';

  @override
  String get providerGroupsExpandToMoveToast =>
      'Please expand the group first.';

  @override
  String get providersPageSiliconFlowName => 'Silikon Akışı';

  @override
  String get providersPageAliyunName => 'Aliyun';

  @override
  String get providersPageZhipuName => 'Zhipu AI';

  @override
  String get providersPageByteDanceName => 'ByteDance';

  @override
  String get providersPageEnabledStatus => 'AÇIK';

  @override
  String get providersPageDisabledStatus => 'KAPALI';

  @override
  String get providersPageModelsCountSuffix => 'modeller';

  @override
  String get providersPageModelsCountSingleSuffix => 'modeller';

  @override
  String get addProviderSheetTitle => 'Sağlayıcı Ekle';

  @override
  String get addProviderSheetEnabledLabel => 'Etkinleştirilmiş';

  @override
  String get addProviderSheetNameLabel => 'İsim';

  @override
  String get addProviderSheetApiPathLabel => 'API Yolu';

  @override
  String get addProviderSheetVertexAiLocationLabel => 'Konum';

  @override
  String get addProviderSheetVertexAiProjectIdLabel => 'Proje Kimliği';

  @override
  String get addProviderSheetVertexAiServiceAccountJsonLabel =>
      'Service Account JSON (paste or import)';

  @override
  String get addProviderSheetImportJsonButton => 'JSON\'u içe aktar';

  @override
  String get addProviderSheetCancelButton => 'İptal etmek';

  @override
  String get addProviderSheetAddButton => 'Eklemek';

  @override
  String get importProviderSheetTitle => 'İthalat Sağlayıcısı';

  @override
  String get importProviderSheetScanQrTooltip => 'QR\'yi tara';

  @override
  String get importProviderSheetFromGalleryTooltip => 'Galeriden';

  @override
  String importProviderSheetImportSuccessMessage(int count) {
    return 'İçe aktarılan ${count} sağlayıcı(lar)';
  }

  @override
  String importProviderSheetImportFailedMessage(String error) {
    return 'İçe aktarma başarısız oldu: ${error}';
  }

  @override
  String get importProviderSheetDescription =>
      'Paste share strings (multi-line supported) or ChatBox JSON';

  @override
  String get importProviderSheetInputHint => 'ai-provider:v1:... veya JSON';

  @override
  String get importProviderSheetCancelButton => 'İptal etmek';

  @override
  String get importProviderSheetImportButton => 'İçe aktarmak';

  @override
  String get shareProviderSheetTitle => 'Paylaşım Sağlayıcı';

  @override
  String get shareProviderSheetDescription => 'QR koduyla kopyalayın veya paylaşın.';

  @override
  String get shareProviderSheetCopiedMessage => 'Kopyalandı';

  @override
  String get shareProviderSheetCopyButton => 'Kopyala';

  @override
  String get shareProviderSheetShareButton => 'Paylaşmak';

  @override
  String get desktopProviderContextMenuShare => 'Paylaşmak';

  @override
  String get desktopProviderShareCopyText => 'Kodu kopyala';

  @override
  String get desktopProviderShareCopyQr => 'QR\'yi kopyala';

  @override
  String get providerDetailPageApiBaseUrlLabel => 'API Temel URL\'si';

  @override
  String get providerDetailPageModelsTitle => 'Modeller';

  @override
  String get providerModelsGetButton => 'Elde etmek';

  @override
  String get providerDetailPageCapsVision => 'Görüş';

  @override
  String get providerDetailPageCapsImage => 'Resim';

  @override
  String get providerDetailPageCapsTool => 'Alet';

  @override
  String get providerDetailPageCapsReasoning => 'muhakeme';

  @override
  String get qrScanPageTitle => 'QR\'yi tara';

  @override
  String get qrScanPageInstruction => 'QR kodunu çerçevenin içine hizalayın';

  @override
  String get searchServicesPageBackTooltip => 'Geri';

  @override
  String get searchServicesPageTitle => 'Arama Hizmetleri';

  @override
  String get searchServicesPageDone => 'Tamamlamak';

  @override
  String get searchServicesPageEdit => 'Düzenlemek';

  @override
  String get searchServicesPageAddProvider => 'Sağlayıcı Ekle';

  @override
  String get searchServicesPageSearchProviders => 'Arama Sağlayıcıları';

  @override
  String get searchServicesPageGeneralOptions => 'Genel Seçenekler';

  @override
  String get searchServicesPageAutoTestTitle =>
      'Auto-test connections on launch';

  @override
  String get searchServicesPageMaxResults => 'Maksimum Sonuçlar';

  @override
  String get searchServicesPageTimeoutSeconds => 'Zaman aşımı (saniye)';

  @override
  String get searchServicesPageAtLeastOneServiceRequired =>
      'At least one search service is required';

  @override
  String get searchServicesPageTestingStatus => 'Test…';

  @override
  String get searchServicesPageConnectedStatus => 'Bağlı';

  @override
  String get searchServicesPageFailedStatus => 'Arızalı';

  @override
  String get searchServicesPageNotTestedStatus => 'Test edilmedi';

  @override
  String get searchServicesPageEditServiceTooltip => 'Hizmeti Düzenle';

  @override
  String get searchServicesPageTestConnectionTooltip => 'Bağlantıyı Test Et';

  @override
  String get searchServicesPageDeleteServiceTooltip => 'Hizmeti Sil';

  @override
  String get searchServicesPageConfiguredStatus => 'Yapılandırılmış';

  @override
  String get miniMapTitle => 'Mini harita';

  @override
  String get miniMapTooltip => 'Mini harita';

  @override
  String get miniMapScrollToBottomTooltip => 'Aşağıya doğru kaydır';

  @override
  String get searchServicesPageApiKeyRequiredStatus => 'API Anahtarı Gerekli';

  @override
  String get searchServicesPageUrlRequiredStatus => 'URL Gerekli';

  @override
  String get searchServicesAddDialogTitle => 'Arama Hizmeti Ekle';

  @override
  String get searchServicesAddDialogServiceType => 'Hizmet Türü';

  @override
  String get searchServicesAddDialogBingLocal => 'Yerel';

  @override
  String get searchServicesAddDialogCancel => 'İptal etmek';

  @override
  String get searchServicesAddDialogAdd => 'Eklemek';

  @override
  String get searchServicesAddDialogApiKeyRequired => 'API Anahtarı gerekli';

  @override
  String get searchServicesFieldCustomUrlOptional => 'Özel URL (isteğe bağlı)';

  @override
  String get searchServicesAddDialogInstanceUrl => 'Örnek URL\'si';

  @override
  String get searchServicesAddDialogUrlRequired => 'URL gerekli';

  @override
  String get searchServicesAddDialogEnginesOptional => 'Motorlar (isteğe bağlı)';

  @override
  String get searchServicesAddDialogLanguageOptional => 'Dil (isteğe bağlı)';

  @override
  String get searchServicesAddDialogUsernameOptional => 'Kullanıcı adı (isteğe bağlı)';

  @override
  String get searchServicesAddDialogPasswordOptional => 'Şifre (isteğe bağlı)';

  @override
  String get searchServicesAddDialogRegionOptional =>
      'Region (optional, default: us-en)';

  @override
  String get searchServicesEditDialogEdit => 'Düzenlemek';

  @override
  String get searchServicesEditDialogCancel => 'İptal etmek';

  @override
  String get searchServicesEditDialogSave => 'Kaydetmek';

  @override
  String get searchServicesEditDialogBingLocalNoConfig =>
      'No configuration required for Bing Local search.';

  @override
  String get searchServicesEditDialogApiKeyRequired => 'API Anahtarı gerekli';

  @override
  String get searchServicesEditDialogInstanceUrl => 'Örnek URL\'si';

  @override
  String get searchServicesEditDialogUrlRequired => 'URL gerekli';

  @override
  String get searchServicesEditDialogEnginesOptional => 'Motorlar (isteğe bağlı)';

  @override
  String get searchServicesEditDialogLanguageOptional => 'Dil (isteğe bağlı)';

  @override
  String get searchServicesEditDialogUsernameOptional => 'Kullanıcı adı (isteğe bağlı)';

  @override
  String get searchServicesEditDialogPasswordOptional => 'Şifre (isteğe bağlı)';

  @override
  String get searchServicesEditDialogRegionOptional =>
      'Region (optional, default: us-en)';

  @override
  String get searchSettingsSheetTitle => 'Arama Ayarları';

  @override
  String get searchSettingsSheetBuiltinSearchTitle => 'Dahili Arama';

  @override
  String get searchSettingsSheetBuiltinSearchDescription =>
      'Enable model\'s built-in search';

  @override
  String get searchSettingsSheetWebSearchTitle => 'Web Araması';

  @override
  String get searchSettingsSheetWebSearchDescription =>
      'Enable web search in chat';

  @override
  String get searchSettingsSheetOpenSearchServicesTooltip =>
      'Open search services';

  @override
  String get searchSettingsSheetNoServicesMessage =>
      'No services. Add from Search Services.';

  @override
  String get aboutPageEasterEggMessage =>
      'Thanks for exploring! \n (No egg yet)';

  @override
  String get aboutPageEasterEggButton => 'Güzel!';

  @override
  String get aboutPageAppDescription => 'Açık kaynaklı AI Asistanı';

  @override
  String get aboutPageNoQQGroup => 'Henüz QQ grubu yok';

  @override
  String get aboutPageVersion => 'Sürüm';

  @override
  String get aboutPageSystem => 'Sistem';

  @override
  String get aboutPageWebsite => 'Web sitesi';

  @override
  String get aboutPageLicense => 'Lisans';

  @override
  String get aboutPageJoinQQGroup => 'QQ Grubumuza katılın';

  @override
  String get aboutPageJoinDiscord => 'Discord\'da bize katılın';

  @override
  String get displaySettingsPageShowUserAvatarTitle => 'Kullanıcı Avatarını Göster';

  @override
  String get displaySettingsPageShowUserAvatarSubtitle =>
      'Display user avatar in chat messages';

  @override
  String get displaySettingsPageShowUserNameTimestampTitle =>
      'Show User Name & Timestamp';

  @override
  String get displaySettingsPageShowUserNameTimestampSubtitle =>
      'Show user name and the timestamp below it in chat messages';

  @override
  String get displaySettingsPageShowUserMessageActionsTitle =>
      'Show User Message Actions';

  @override
  String get displaySettingsPageShowUserMessageActionsSubtitle =>
      'Display copy, resend, and more buttons below your messages';

  @override
  String get displaySettingsPageShowModelNameTimestampTitle =>
      'Show Model Name & Timestamp';

  @override
  String get displaySettingsPageShowModelNameTimestampSubtitle =>
      'Show model name and the timestamp below it in chat messages';

  @override
  String get displaySettingsPageShowProviderInChatMessageTitle =>
      'Show Provider After Model Name';

  @override
  String get displaySettingsPageShowProviderInChatMessageSubtitle =>
      'Display provider name after the model ID in chat messages (e.g. model | provider)';

  @override
  String get displaySettingsPageChatModelIconTitle => 'Sohbet Modeli Simgesi';

  @override
  String get displaySettingsPageChatModelIconSubtitle =>
      'Show model icon in chat messages';

  @override
  String get displaySettingsPageShowTokenStatsTitle =>
      'Show Token & Context Stats';

  @override
  String get displaySettingsPageShowTokenStatsSubtitle =>
      'Show token usage and message count';

  @override
  String get displaySettingsPageAutoCollapseThinkingTitle =>
      'Auto-collapse Thinking';

  @override
  String get displaySettingsPageAutoCollapseThinkingSubtitle =>
      'Collapse reasoning after finish';

  @override
  String get displaySettingsPageShowChatListDateTitle => 'Sohbet Listesi Tarihlerini Göster';

  @override
  String get displaySettingsPageShowChatListDateSubtitle =>
      'Display date group labels in the conversation list';

  @override
  String get displaySettingsPageKeepSidebarOpenOnAssistantTapTitle =>
      'Keep sidebar open when selecting assistant';

  @override
  String get displaySettingsPageKeepSidebarOpenOnTopicTapTitle =>
      'Keep sidebar open when selecting topic';

  @override
  String get displaySettingsPageKeepAssistantListExpandedOnSidebarCloseTitle =>
      'Don\'t collapse assistant list when closing sidebar';

  @override
  String get displaySettingsPageShowUpdatesTitle => 'Güncellemeleri Göster';

  @override
  String get displaySettingsPageShowUpdatesSubtitle =>
      'Show app update notifications';

  @override
  String get displaySettingsPageMessageNavButtonsTitle =>
      'Message Navigation Buttons';

  @override
  String get displaySettingsPageMessageNavButtonsSubtitle =>
      'Show quick jump buttons when scrolling';

  @override
  String get displaySettingsPageHapticsOnSidebarTitle => 'Kenar Çubuğundaki Dokunma';

  @override
  String get displaySettingsPageHapticsOnSidebarSubtitle =>
      'Enable haptic feedback when opening/closing sidebar';

  @override
  String get displaySettingsPageHapticsGlobalTitle => 'Küresel Dokunuş';

  @override
  String get displaySettingsPageHapticsIosSwitchTitle => 'Switch\'te Dokunma';

  @override
  String get displaySettingsPageHapticsOnListItemTapTitle =>
      'Haptics on List Items';

  @override
  String get displaySettingsPageHapticsOnCardTapTitle => 'Kartlardaki Dokunma';

  @override
  String get displaySettingsPageHapticsOnGenerateTitle => 'Generate\'de Haptikler';

  @override
  String get displaySettingsPageHapticsOnGenerateSubtitle =>
      'Enable haptic feedback during generation';

  @override
  String get displaySettingsPageNewChatAfterDeleteTitle =>
      'New chat after deleting topic';

  @override
  String get displaySettingsPageNewChatOnAssistantSwitchTitle =>
      'New chat when switching assistants';

  @override
  String get displaySettingsPageNewChatOnLaunchTitle => 'Lansmanda Yeni Sohbet';

  @override
  String get displaySettingsPageEnterToSendTitle => 'Gönderilecek Anahtarı Girin';

  @override
  String get displaySettingsPageSendShortcutTitle => 'Kısayol Gönder';

  @override
  String get displaySettingsPageSendShortcutEnter => 'Girmek';

  @override
  String get displaySettingsPageSendShortcutCtrlEnter => 'Ctrl/Cmd + Enter';

  @override
  String get displaySettingsPageAutoSwitchTopicsTitle =>
      'Auto switch to Topics';

  @override
  String get desktopDisplaySettingsTopicPositionTitle => 'Konu konumu';

  @override
  String get desktopDisplaySettingsTopicPositionLeft => 'Sol';

  @override
  String get desktopDisplaySettingsTopicPositionRight => 'Sağ';

  @override
  String get displaySettingsPageNewChatOnLaunchSubtitle =>
      'Automatically create a new chat on launch';

  @override
  String get displaySettingsPageChatFontSizeTitle => 'Sohbet Yazı Tipi Boyutu';

  @override
  String get displaySettingsPageAutoScrollEnableTitle =>
      'Auto-scroll to bottom';

  @override
  String get displaySettingsPageAutoScrollIdleTitle => 'Otomatik Geri Kaydırma Gecikmesi';

  @override
  String get displaySettingsPageAutoScrollIdleSubtitle =>
      'Wait time after user scroll before jumping to bottom';

  @override
  String get displaySettingsPageAutoScrollDisabledLabel => 'Kapalı';

  @override
  String get displaySettingsPageChatFontSampleText =>
      'This is a sample chat text';

  @override
  String get displaySettingsPageChatBackgroundMaskTitle =>
      'Chat Background Overlay Opacity';

  @override
  String get displaySettingsPageThemeSettingsTitle => 'Tema Ayarları';

  @override
  String get displaySettingsPageThemeColorTitle => 'Tema Rengi';

  @override
  String get desktopSettingsFontsTitle => 'Yazı tipleri';

  @override
  String get displaySettingsPageTrayTitle => 'Sistem Tepsisi';

  @override
  String get displaySettingsPageTrayShowTrayTitle => 'Tepsi simgesini göster';

  @override
  String get displaySettingsPageTrayMinimizeOnCloseTitle =>
      'Minimize to tray on close';

  @override
  String get desktopFontAppLabel => 'Uygulama Yazı Tipi';

  @override
  String get desktopFontCodeLabel => 'Kod Yazı Tipi';

  @override
  String get desktopFontFamilySystemDefault => 'Sistem Varsayılanı';

  @override
  String get desktopFontFamilyMonospaceDefault => 'Tek uzay';

  @override
  String get desktopFontFilterHint => 'Yazı tiplerini filtrele...';

  @override
  String get displaySettingsPageAppFontTitle => 'Uygulama Yazı Tipi';

  @override
  String get displaySettingsPageCodeFontTitle => 'Kod Yazı Tipi';

  @override
  String get fontPickerChooseLocalFile => 'Yerel Dosyayı Seçin';

  @override
  String get fontPickerGetFromGoogleFonts => 'Google Fonts\'a Göz Atın';

  @override
  String get fontPickerFilterHint => 'Yazı tiplerini filtrele...';

  @override
  String get desktopFontLoading => 'Yazı tipleri yükleniyor…';

  @override
  String get displaySettingsPageFontLocalFileLabel => 'Yerel dosya';

  @override
  String get displaySettingsPageFontResetLabel => 'Yazı tipi ayarlarını sıfırla';

  @override
  String get displaySettingsPageOtherSettingsTitle => 'Diğer Ayarlar';

  @override
  String get themeSettingsPageDynamicColorSection => 'Dinamik Renk';

  @override
  String get themeSettingsPageUseDynamicColorTitle => 'Sistem Dinamik Renkleri';

  @override
  String get themeSettingsPageUseDynamicColorSubtitle =>
      'Match system palette (Android 12+)';

  @override
  String get themeSettingsPageUsePureBackgroundTitle => 'Saf Arka Plan';

  @override
  String get themeSettingsPageUsePureBackgroundSubtitle =>
      'Bubbles and accents follow theme.';

  @override
  String get themeSettingsPageColorPalettesSection => 'Renk Paletleri';

  @override
  String get ttsServicesPageBackButton => 'Geri';

  @override
  String get ttsServicesPageTitle => 'Metinden Konuşmaya';

  @override
  String get ttsServicesPageAddTooltip => 'Eklemek';

  @override
  String get ttsServicesPageAddNotImplemented =>
      'Add TTS service not implemented';

  @override
  String get ttsServicesPageSystemTtsTitle => 'Sistem TTS\'si';

  @override
  String get ttsServicesPageSystemTtsAvailableSubtitle =>
      'Use system built-in TTS';

  @override
  String ttsServicesPageSystemTtsUnavailableSubtitle(String error) {
    return 'Kullanılamıyor: ${error}';
  }

  @override
  String get ttsServicesPageSystemTtsUnavailableNotInitialized =>
      'not initialized';

  @override
  String get ttsServicesPageTestSpeechText => 'Merhaba bu bir deneme konuşmasıdır.';

  @override
  String get ttsServicesPageConfigureTooltip => 'Yapılandır';

  @override
  String get ttsServicesPageTestVoiceTooltip => 'Sesi test et';

  @override
  String get ttsServicesPageStopTooltip => 'Durmak';

  @override
  String get ttsServicesPageDeleteTooltip => 'Silmek';

  @override
  String get ttsServicesPageSystemTtsSettingsTitle => 'Sistem TTS Ayarları';

  @override
  String get ttsServicesPageEngineLabel => 'Motor';

  @override
  String get ttsServicesPageAutoLabel => 'Otomatik';

  @override
  String get ttsServicesPageLanguageLabel => 'Dil';

  @override
  String get ttsServicesPageSpeechRateLabel => 'Konuşma hızı';

  @override
  String get ttsServicesPagePitchLabel => 'Saha';

  @override
  String get ttsServicesPageSettingsSavedMessage => 'Ayarlar kaydedildi.';

  @override
  String get ttsServicesPageDoneButton => 'Tamamlamak';

  @override
  String get ttsServicesPageNetworkSectionTitle => 'Ağ TTS\'si';

  @override
  String get ttsServicesPageNoNetworkServices => 'TTS hizmeti yok.';

  @override
  String get ttsServicesDialogAddTitle => 'TTS Hizmeti Ekle';

  @override
  String get ttsServicesDialogEditTitle => 'TTS Hizmetini Düzenle';

  @override
  String get ttsServicesDialogProviderType => 'sağlayıcı';

  @override
  String get ttsServicesDialogCancelButton => 'İptal etmek';

  @override
  String get ttsServicesDialogAddButton => 'Eklemek';

  @override
  String get ttsServicesDialogSaveButton => 'Kaydetmek';

  @override
  String get ttsServicesFieldNameLabel => 'İsim';

  @override
  String get ttsServicesFieldApiKeyLabel => 'API Anahtarı';

  @override
  String get ttsServicesFieldBaseUrlLabel => 'API Temel URL\'si';

  @override
  String get ttsServicesFieldModelLabel => 'Modeli';

  @override
  String get ttsServicesFieldVoiceLabel => 'Ses';

  @override
  String get ttsServicesFieldVoiceIdLabel => 'Ses Kimliği';

  @override
  String get ttsServicesFieldEmotionLabel => 'Duygu';

  @override
  String get ttsServicesFieldSpeedLabel => 'Hız';

  @override
  String get ttsServicesViewDetailsButton => 'Ayrıntıları görüntüle';

  @override
  String get ttsServicesDialogErrorTitle => 'Hata Ayrıntıları';

  @override
  String get ttsServicesCloseButton => 'Kapalı';

  @override
  String imageViewerPageShareFailedOpenFile(String message) {
    return 'Paylaşılamadı, dosya açılmaya çalışıldı: ${message}';
  }

  @override
  String imageViewerPageShareFailed(String error) {
    return 'Paylaşım başarısız oldu: ${error}';
  }

  @override
  String get imageViewerPageShareButton => 'Resmi Paylaş';

  @override
  String get imageViewerPageSaveButton => 'Resmi Kaydet';

  @override
  String get imageViewerPageSaveSuccess => 'Galeriye kaydedildi';

  @override
  String imageViewerPageSaveFailed(String error) {
    return 'Kaydetme başarısız oldu: ${error}';
  }

  @override
  String get settingsShare => 'Kelivo - Açık Kaynak Yapay Zeka Asistanı';

  @override
  String get searchProviderBingLocalDescription =>
      'Uses web scraping to fetch Bing results. No API key required; may be unstable.';

  @override
  String get searchProviderDuckDuckGoDescription =>
      'Privacy-focused DuckDuckGo search via DDGS. No API key required; supports region selection.';

  @override
  String get searchProviderBraveDescription =>
      'Independent search engine by Brave. Privacy-focused with no tracking or profiling.';

  @override
  String get searchProviderExaDescription =>
      'Neural search with semantic understanding. Great for research and finding specific content.';

  @override
  String get searchProviderLinkUpDescription =>
      'Search API with sourced answers. Provides both results and AI-generated summaries.';

  @override
  String get searchProviderMetasoDescription =>
      'Chinese search by Metaso. Optimized for Chinese content with AI capabilities.';

  @override
  String get searchProviderSearXNGDescription =>
      'Privacy-respecting metasearch engine. Self-hosted instance required; no tracking.';

  @override
  String get searchProviderTavilyDescription =>
      'AI search API optimized for LLMs. Provides high-quality, relevant results.';

  @override
  String get searchProviderZhipuDescription =>
      'Chinese AI search by Zhipu AI. Optimized for Chinese content and queries.';

  @override
  String get searchProviderOllamaDescription =>
      'Ollama web search API. Augments models with up-to-date information.';

  @override
  String get searchProviderJinaDescription =>
      'AI search foundation with embeddings, rerankers, web reader, deepsearch, and small language models. Multilingual and multimodal.';

  @override
  String get searchServiceNameBingLocal => 'Bing (Yerel)';

  @override
  String get searchServiceNameDuckDuckGo => 'ÖrdekDuckGo';

  @override
  String get searchServiceNameTavily => 'Tavily';

  @override
  String get searchServiceNameExa => 'Exa';

  @override
  String get searchServiceNameZhipu => 'Zhipu AI';

  @override
  String get searchServiceNameSearXNG => 'SearXNG';

  @override
  String get searchServiceNameLinkUp => 'Bağlantı Kur';

  @override
  String get searchServiceNameBrave => 'Cesur Arama';

  @override
  String get searchServiceNameMetaso => 'Metaso';

  @override
  String get searchServiceNameOllama => 'Ollama';

  @override
  String get searchServiceNameJina => 'Jina';

  @override
  String get searchServiceNamePerplexity => 'Şaşkınlık';

  @override
  String get searchProviderPerplexityDescription =>
      'Perplexity Search API. Ranked web results with region and domain filters.';

  @override
  String get searchServiceNameBocha => 'Bocha';

  @override
  String get searchProviderBochaDescription =>
      'Bocha web search API. Accurate web results with optional summaries.';

  @override
  String get generationInterrupted => 'Üretim kesintiye uğradı';

  @override
  String get titleForLocale => 'Yeni Sohbet';

  @override
  String get quickPhraseBackTooltip => 'Geri';

  @override
  String get quickPhraseGlobalTitle => 'Hızlı İfade';

  @override
  String get quickPhraseAssistantTitle => 'Asistan Hızlı İfadesi';

  @override
  String get quickPhraseAddTooltip => 'Hızlı İfade Ekle';

  @override
  String get quickPhraseEmptyMessage => 'Henüz kısa ifade yok';

  @override
  String get quickPhraseAddTitle => 'Hızlı İfade Ekle';

  @override
  String get quickPhraseEditTitle => 'Hızlı İfadeyi Düzenle';

  @override
  String get quickPhraseTitleLabel => 'Başlık';

  @override
  String get quickPhraseContentLabel => 'İçerik';

  @override
  String get quickPhraseCancelButton => 'İptal etmek';

  @override
  String get quickPhraseSaveButton => 'Kaydetmek';

  @override
  String get instructionInjectionTitle => 'Talimat Enjeksiyonu';

  @override
  String get instructionInjectionBackTooltip => 'Geri';

  @override
  String get instructionInjectionAddTooltip => 'Talimat Ekle';

  @override
  String get instructionInjectionImportTooltip => 'Dosyalardan içe aktar';

  @override
  String get instructionInjectionEmptyMessage =>
      'No instruction injection cards yet';

  @override
  String get instructionInjectionDefaultTitle => 'Öğrenme Modu';

  @override
  String get instructionInjectionAddTitle => 'Talimat Ekleme Ekle';

  @override
  String get instructionInjectionEditTitle => 'Talimat Eklemeyi Düzenle';

  @override
  String get instructionInjectionNameLabel => 'İsim';

  @override
  String get instructionInjectionPromptLabel => 'Çabuk';

  @override
  String get instructionInjectionUngroupedGroup => 'Gruplandırılmamış';

  @override
  String get instructionInjectionGroupLabel => 'Grup';

  @override
  String get instructionInjectionGroupHint => 'İsteğe bağlı';

  @override
  String instructionInjectionImportSuccess(int count) {
    return '${count} talimat(lar)ı içe aktarıldı';
  }

  @override
  String get instructionInjectionSheetSubtitle =>
      'Choose a prompt to apply before chatting';

  @override
  String get mcpJsonEditButtonTooltip => 'JSON\'u düzenle';

  @override
  String get mcpJsonEditTitle => 'JSON\'u düzenle';

  @override
  String get mcpJsonEditParseFailed => 'JSON ayrıştırması başarısız oldu';

  @override
  String get mcpJsonEditSavedApplied => 'Kaydedildi ve uygulandı';

  @override
  String get mcpTimeoutSettingsTooltip => 'Araç çağrısı zaman aşımını ayarla';

  @override
  String get mcpTimeoutDialogTitle => 'Araç çağrısı zaman aşımı';

  @override
  String get mcpTimeoutSecondsLabel => 'Araç çağrısı zaman aşımı (saniye)';

  @override
  String get mcpTimeoutInvalid => 'Pozitif bir saniye sayısı girin';

  @override
  String get quickPhraseEditButton => 'Düzenlemek';

  @override
  String get quickPhraseDeleteButton => 'Silmek';

  @override
  String get quickPhraseMenuTitle => 'Hızlı İfade';

  @override
  String get chatInputBarQuickPhraseTooltip => 'Hızlı İfade';

  @override
  String get assistantEditQuickPhraseDescription =>
      'Manage quick phrases for this assistant. Click the button below to add phrases.';

  @override
  String get assistantEditManageQuickPhraseButton => 'Hızlı İfadeleri Yönet';

  @override
  String get assistantEditPageMemoryTab => 'Hafıza';

  @override
  String get assistantEditMemorySwitchTitle => 'Hafıza';

  @override
  String get assistantEditMemorySwitchDescription =>
      'Allow the assistant to create and use memories across chats.';

  @override
  String get assistantEditRecentChatsSwitchTitle => 'Son Sohbetler Referansı';

  @override
  String get assistantEditRecentChatsSwitchDescription =>
      'Include recent conversation titles to help with context.';

  @override
  String get assistantEditManageMemoryTitle => 'Anıları Yönet';

  @override
  String get assistantEditAddMemoryButton => 'Bellek Ekle';

  @override
  String get assistantEditMemoryEmpty => 'Henüz anı yok';

  @override
  String get assistantEditMemoryDialogTitle => 'Hafıza';

  @override
  String get assistantEditMemoryDialogHint => 'Bellek içeriğini girin';

  @override
  String get assistantEditAddQuickPhraseButton => 'Hızlı İfade Ekle';

  @override
  String get multiKeyPageDeleteSnackbarDeletedOne => '1 anahtar silindi';

  @override
  String get multiKeyPageUndo => 'Geri al';

  @override
  String get multiKeyPageUndoRestored => 'Geri yüklendi';

  @override
  String get multiKeyPageDeleteErrorsTooltip => 'Hataları sil';

  @override
  String get multiKeyPageDeleteErrorsConfirmTitle => 'Tüm hata anahtarları silinsin mi?';

  @override
  String get multiKeyPageDeleteErrorsConfirmContent =>
      'This will remove all keys marked as error.';

  @override
  String multiKeyPageDeletedErrorsSnackbar(int n) {
    return '${n} hata anahtarları silindi';
  }

  @override
  String get providerDetailPageProviderTypeTitle => 'Sağlayıcı Türü';

  @override
  String get displaySettingsPageChatItemDisplayTitle => 'Sohbet öğesi ekranı';

  @override
  String get displaySettingsPageRenderingSettingsTitle => 'Oluşturma ayarları';

  @override
  String get displaySettingsPageBehaviorStartupTitle => 'Davranış ve başlangıç';

  @override
  String get displaySettingsPageHapticsSettingsTitle => 'Dokunsal';

  @override
  String get assistantSettingsNoPromptPlaceholder => 'Henüz istem yok';

  @override
  String get providersPageMultiSelectTooltip => 'Çoklu seçim';

  @override
  String get providersPageDeleteSelectedConfirmContent =>
      'Delete selected providers? This cannot be undone.';

  @override
  String get providersPageDeleteSelectedSnackbar =>
      'Deleted selected providers';

  @override
  String providersPageExportSelectedTitle(int count) {
    return '${count} sağlayıcıyı dışa aktar';
  }

  @override
  String get providersPageExportCopyButton => 'Kopyala';

  @override
  String get providersPageExportShareButton => 'Paylaşmak';

  @override
  String get providersPageExportCopiedSnackbar => 'Kopyalanan dışa aktarma kodu';

  @override
  String get providersPageDeleteAction => 'Silmek';

  @override
  String get providersPageExportAction => 'İhracat';

  @override
  String get assistantEditPresetTitle => 'Önceden ayarlanmış konuşma';

  @override
  String get assistantEditPresetAddUser => 'Kullanıcı ön ayarı ekle';

  @override
  String get assistantEditPresetAddAssistant => 'Asistan ön ayarı ekle';

  @override
  String get assistantEditPresetInputHintUser => 'Kullanıcı mesajını girin…';

  @override
  String get assistantEditPresetInputHintAssistant =>
      'Enter assistant message…';

  @override
  String get assistantEditPresetEmpty => 'Henüz önceden ayarlanmış mesaj yok';

  @override
  String get assistantEditPresetEditDialogTitle => 'Önceden ayarlanmış mesajı düzenleyin';

  @override
  String get assistantEditPresetRoleUser => 'Kullanıcı';

  @override
  String get assistantEditPresetRoleAssistant => 'Asistan';

  @override
  String get desktopTtsPleaseAddProvider => 'Lütfen önce bir TTS sağlayıcısı ekleyin';

  @override
  String get settingsPageNetworkProxy => 'Ağ Proxy\'si';

  @override
  String get networkProxyEnableLabel => 'Proxy\'yi Etkinleştir';

  @override
  String get networkProxySettingsHeader => 'Proxy Ayarları';

  @override
  String get networkProxyType => 'Vekil Türü';

  @override
  String get networkProxyTypeHttp => 'HTTP';

  @override
  String get networkProxyTypeHttps => 'HTTPS';

  @override
  String get networkProxyTypeSocks5 => 'ÇORAP5';

  @override
  String get networkProxyServerHost => 'Sunucu';

  @override
  String get networkProxyPort => 'Liman';

  @override
  String get networkProxyUsername => 'Kullanıcı adı';

  @override
  String get networkProxyPassword => 'Şifre';

  @override
  String get networkProxyBypassLabel => 'Proxy bypass\'ı';

  @override
  String get networkProxyBypassHint =>
      'Comma-separated hosts/CIDR, e.g. localhost,127.0.0.1,192.168.0.0/16,*.local';

  @override
  String get networkProxyOptionalHint => 'İsteğe bağlı';

  @override
  String get networkProxyTestHeader => 'Bağlantı Testi';

  @override
  String get networkProxyTestUrlHint => 'URL\'yi test edin';

  @override
  String get networkProxyTestButton => 'Test';

  @override
  String get networkProxyTesting => 'Test…';

  @override
  String get networkProxyTestSuccess => 'Bağlantı başarılı';

  @override
  String networkProxyTestFailed(String error) {
    return 'Test başarısız oldu: ${error}';
  }

  @override
  String get networkProxyNoUrl => 'Lütfen bir URL girin';

  @override
  String get networkProxyPriorityNote =>
      'When both global and provider proxies are enabled, provider-level proxy takes priority.';

  @override
  String get desktopShowProviderInModelCapsule =>
      'Show provider in model capsule';

  @override
  String get messageWebViewOpenInBrowser => 'Tarayıcıda Aç';

  @override
  String get messageWebViewConsoleLogs => 'Konsol Günlükleri';

  @override
  String get messageWebViewNoConsoleMessages => 'Konsol mesajı yok';

  @override
  String get messageWebViewRefreshTooltip => 'Yenile';

  @override
  String get messageWebViewForwardTooltip => 'İleri';

  @override
  String get chatInputBarOcrTooltip => 'Görüntü OCR\'si';

  @override
  String get providerDetailPageBatchDetectButton => 'Tespit etmek';

  @override
  String get providerDetailPageBatchDetecting => 'Algılanıyor...';

  @override
  String get providerDetailPageBatchDetectStart => 'Algılamayı Başlat';

  @override
  String get providerDetailPageDetectSuccess => 'Algılama başarılı';

  @override
  String get providerDetailPageDetectFailed => 'Algılama başarısız oldu';

  @override
  String get providerDetailPageDeleteAllModelsWarning =>
      'This action cannot be undone.';

  @override
  String get requestLogSettingTitle => 'Günlük Kaydı İste';

  @override
  String get requestLogSettingSubtitle =>
      'When enabled, request/response details are written to logs/logs.txt (rotated daily).';

  @override
  String get flutterLogSettingTitle => 'Çarpıntı Günlüğü';

  @override
  String get flutterLogSettingSubtitle =>
      'When enabled, Flutter errors and print output are written to logs/flutter_logs.txt (rotated daily).';

  @override
  String get logViewerTitle => 'Günlük Talep Et';

  @override
  String get logViewerEmpty => 'Henüz günlük yok';

  @override
  String get logViewerCurrentLog => 'Mevcut Günlük';

  @override
  String get logViewerExport => 'İhracat';

  @override
  String get logViewerOpenFolder => 'Günlükler Klasörünü Aç';

  @override
  String logViewerRequestsCount(int count) {
    return '${count} istek';
  }

  @override
  String get logViewerFieldId => 'İD';

  @override
  String get logViewerFieldMethod => 'Yöntem';

  @override
  String get logViewerFieldStatus => 'Durum';

  @override
  String get logViewerFieldStarted => 'Başlatıldı';

  @override
  String get logViewerFieldEnded => 'Sona erdi';

  @override
  String get logViewerFieldDuration => 'Süre';

  @override
  String get logViewerSectionSummary => 'Özet';

  @override
  String get logViewerSectionParameters => 'Parametreler';

  @override
  String get logViewerSectionRequestHeaders => 'Başlıkları Talep Et';

  @override
  String get logViewerSectionRequestBody => 'Talep Gövdesi';

  @override
  String get logViewerSectionResponseHeaders => 'Yanıt Başlıkları';

  @override
  String get logViewerSectionResponseBody => 'Yanıt Gövdesi';

  @override
  String get logViewerSectionWarnings => 'Uyarılar';

  @override
  String get logViewerErrorTitle => 'Hata';

  @override
  String logViewerMoreCount(int count) {
    return '+${count} daha';
  }

  @override
  String get logSettingsTitle => 'Günlük Ayarları';

  @override
  String get logSettingsSaveOutput => 'Yanıt Çıkışını Kaydet';

  @override
  String get logSettingsSaveOutputSubtitle =>
      'Log response body content (may use significant storage)';

  @override
  String get logSettingsAutoDelete => 'Otomatik sil';

  @override
  String get logSettingsAutoDeleteSubtitle =>
      'Delete logs older than specified days';

  @override
  String get logSettingsAutoDeleteDisabled => 'Engelli';

  @override
  String logSettingsAutoDeleteDays(int count) {
    return '${count} gün';
  }

  @override
  String get logSettingsMaxSize => 'Maksimum Günlük Boyutu';

  @override
  String get logSettingsMaxSizeSubtitle => 'En eski günlükler aşıldığında silinir';

  @override
  String get logSettingsMaxSizeUnlimited => 'Sınırsız';

  @override
  String get assistantEditManageSummariesTitle => 'Özetleri Yönet';

  @override
  String get assistantEditSummaryEmpty => 'Henüz özet yok';

  @override
  String get assistantEditSummaryDialogTitle => 'Özeti Düzenle';

  @override
  String get assistantEditSummaryDialogHint => 'Özet içeriğini girin';

  @override
  String get assistantEditDeleteSummaryTitle => 'Özeti Temizle';

  @override
  String get assistantEditDeleteSummaryContent =>
      'Are you sure you want to clear this summary?';

  @override
  String get homePageProcessingFiles => 'Dosyalar işleniyor...';

  @override
  String get fileUploadDuplicateTitle => 'Dosya zaten mevcut';

  @override
  String fileUploadDuplicateContent(String fileName) {
    return '${fileName} adlı bir dosya zaten mevcut. Mevcut dosya kullanılsın mı?';
  }

  @override
  String get fileUploadDuplicateUseExisting => 'Mevcut olanı kullan';

  @override
  String get fileUploadDuplicateUploadNew => 'Yenisini yükle';

  @override
  String get settingsPageWorldBook => 'Dünya Kitabı';

  @override
  String get worldBookTitle => 'Dünya Kitabı';

  @override
  String get worldBookAdd => 'Dünya Kitabı Ekle';

  @override
  String get worldBookEmptyMessage => 'Henüz dünya kitabı yok';

  @override
  String get worldBookUnnamed => 'İsimsiz Dünya Kitabı';

  @override
  String get worldBookDisabledTag => 'Engelli';

  @override
  String get worldBookAlwaysOnTag => 'Daima Açık';

  @override
  String get worldBookAddEntry => 'Giriş Ekle';

  @override
  String get worldBookExport => 'Paylaş / Dışa Aktar';

  @override
  String get worldBookConfig => 'Yapılandır';

  @override
  String get worldBookDeleteTitle => 'Dünya Kitabını Sil';

  @override
  String worldBookDeleteMessage(String name) {
    return '“${name}” silinsin mi? Bu geri alınamaz.';
  }

  @override
  String get worldBookCancel => 'İptal etmek';

  @override
  String get worldBookDelete => 'Silmek';

  @override
  String worldBookExportFailed(String error) {
    return 'Dışa aktarma başarısız oldu: ${error}';
  }

  @override
  String get worldBookNoEntriesHint => 'Giriş yok';

  @override
  String get worldBookUnnamedEntry => 'İsimsiz Giriş';

  @override
  String worldBookKeywordsLine(String keywords) {
    return 'Anahtar kelimeler: ${keywords}';
  }

  @override
  String get worldBookEditEntry => 'Girişi Düzenle';

  @override
  String get worldBookDeleteEntry => 'Girişi Sil';

  @override
  String get worldBookNameLabel => 'İsim';

  @override
  String get worldBookDescriptionLabel => 'Tanım';

  @override
  String get worldBookEnabledLabel => 'Etkinleştirilmiş';

  @override
  String get worldBookSave => 'Kaydetmek';

  @override
  String get worldBookEntryNameLabel => 'Giriş adı';

  @override
  String get worldBookEntryEnabledLabel => 'Giriş etkinleştirildi';

  @override
  String get worldBookEntryPriorityLabel => 'Öncelik';

  @override
  String get worldBookEntryKeywordsLabel => 'Anahtar Kelimeler';

  @override
  String get worldBookEntryKeywordsHint => 'Bir anahtar kelime yazın ve eklemek için +\'ya dokunun.';

  @override
  String get worldBookEntryKeywordInputHint => 'Bir anahtar kelime yazın';

  @override
  String get worldBookEntryKeywordAddTooltip => 'Anahtar kelime ekle';

  @override
  String get worldBookEntryUseRegexLabel => 'Normal ifadeyi kullan';

  @override
  String get worldBookEntryCaseSensitiveLabel => 'Harfe duyarlı';

  @override
  String get worldBookEntryAlwaysOnLabel => 'Her zaman aktif';

  @override
  String get worldBookEntryAlwaysOnHint =>
      'Always inject without keyword matching';

  @override
  String get worldBookEntryScanDepthLabel => 'Tarama derinliği';

  @override
  String get worldBookEntryContentLabel => 'İçerik';

  @override
  String get worldBookEntryInjectionPositionLabel => 'Enjeksiyon konumu';

  @override
  String get worldBookEntryInjectionRoleLabel => 'Enjeksiyon rolü';

  @override
  String get worldBookEntryInjectDepthLabel => 'Enjeksiyon derinliği';

  @override
  String get worldBookInjectionPositionBeforeSystemPrompt =>
      'Before system prompt';

  @override
  String get worldBookInjectionPositionAfterSystemPrompt =>
      'After system prompt';

  @override
  String get worldBookInjectionPositionTopOfChat => 'Sohbetin zirvesi';

  @override
  String get worldBookInjectionPositionBottomOfChat => 'Sohbetin alt kısmı';

  @override
  String get worldBookInjectionPositionAtDepth => 'Derinlikte';

  @override
  String get worldBookInjectionRoleUser => 'Kullanıcı';

  @override
  String get worldBookInjectionRoleAssistant => 'Asistan';
}
