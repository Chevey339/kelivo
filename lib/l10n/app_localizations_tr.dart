// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Turkish (`tr`).
class AppLocalizationsTr extends AppLocalizations {
  AppLocalizationsTr([String locale = 'tr']) : super(locale);

  @override
  String get avatarInputInvalid =>
      'Geçerli bir simge adı veya HTTP(S) görsel URL\'si girin.';

  @override
  String get modelAvatarTitle => 'Model simgesi';

  @override
  String get avatarColor => 'Renkli';

  @override
  String get avatarMonochrome => 'Tek renk';

  @override
  String get settingsSearchHint => 'Ayarlarda ara';

  @override
  String get settingsSearchCancel => 'İptal';

  @override
  String get settingsSearchClear => 'Aramayı temizle';

  @override
  String get settingsSearchSuggestions => 'Hızlı erişim';

  @override
  String get settingsSearchNoResults => 'Ayar bulunamadı';

  @override
  String get settingsSearchNoResultsHint =>
      'Farklı bir ad veya daha kısa bir anahtar kelime deneyin.';

  @override
  String settingsSearchResultCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count sonuç',
      one: '1 sonuç',
    );
    return '$_temp0';
  }

  @override
  String get helloWorld => 'Merhaba Dünya!';

  @override
  String get settingsPageBackButton => 'Geri';

  @override
  String get settingsPageTitle => 'Ayarlar';

  @override
  String get settingsPageDarkMode => 'Koyu';

  @override
  String get settingsPageLightMode => 'Açık';

  @override
  String get settingsPageSystemMode => 'Sistem';

  @override
  String get settingsPageWarningMessage =>
      'Bazı hizmetler yapılandırılmamış; özellikler kısıtlı olabilir.';

  @override
  String get settingsPageGeneralSection => 'Genel';

  @override
  String get settingsPageColorMode => 'Renk Modu';

  @override
  String get settingsPageDisplay => 'Tercihler';

  @override
  String get settingsPageDisplaySubtitle =>
      'Görünüm, davranış ve etkileşim tercihleri';

  @override
  String get settingsPageAssistant => 'Asistan';

  @override
  String get settingsPageAssistantSubtitle =>
      'Varsayılan asistan ve sohbet stili';

  @override
  String get settingsPageModelsServicesSection => 'Modeller ve Hizmetler';

  @override
  String get settingsPageDefaultModel => 'Varsayılan Model';

  @override
  String get settingsPageProviders => 'Sağlayıcılar';

  @override
  String get settingsPageHotkeys => 'Kısayollar';

  @override
  String get settingsPageSearch => 'Arama';

  @override
  String get settingsPageTts => 'TTS';

  @override
  String get settingsPageMcp => 'MCP';

  @override
  String get settingsPageQuickPhrase => 'Hızlı İfade';

  @override
  String get settingsPageInstructionInjection => 'Talimat Enjeksiyonu';

  @override
  String get settingsPageDataSection => 'Veriler';

  @override
  String get settingsPageBackup => 'Yedekleme';

  @override
  String get settingsPageChatStorage => 'Sohbet Depolama';

  @override
  String get settingsPageCalculating => 'Hesaplanıyor…';

  @override
  String get storageSpacePageTitle => 'Depolama Alanı';

  @override
  String get storageSpaceRefreshTooltip => 'Yenile';

  @override
  String get storageSpaceLoadFailed =>
      'Dosyalar yüklenemedi veya hangi görsellerin kullanımda olduğu kontrol edilemedi. Lütfen yenileyip tekrar deneyin.';

  @override
  String get storageSpaceTotalLabel => 'Kullanılan';

  @override
  String storageSpaceClearableLabel(String size) {
    return 'Temizlenebilir: $size';
  }

  @override
  String storageSpaceClearableHint(String size) {
    return 'Güvenle temizlenebilir: $size';
  }

  @override
  String get storageSpaceCategoryImages => 'Görseller';

  @override
  String get storageSpaceCategoryFiles => 'Dosyalar';

  @override
  String get storageSpaceCategoryFonts => 'Yazı Tipleri';

  @override
  String get storageSpaceCategoryLocalModels => 'Yerel Modeller';

  @override
  String get storageSpaceOtherHint =>
      'Yazı tipleri, indirilen yerel modeller ve diğer uygulama dosyaları.';

  @override
  String get storageSpaceSubOtherApp => 'Uygulama dosyaları';

  @override
  String get storageSpaceCategoryChatData => 'Sohbet Kayıtları';

  @override
  String get storageSpaceCategoryLegacyChatData => 'Sohbet Kayıtları (Eski)';

  @override
  String get storageSpaceCategoryRestoreTraces => 'Geri Yükleme İzleri';

  @override
  String get storageSpaceCategoryDisplacedDatabases => 'Ayrılmış Veritabanları';

  @override
  String get storageSpaceSubDisplacedDatabases =>
      'Otomatik yeniden oluşturmadan önce saklandı';

  @override
  String get storageSpaceClearDisplacedDatabasesConfirmMessage =>
      'Bu ayrılmış veritabanları silinsin mi? Kelivo, veritabanını yeniden oluştururken bunları sakladı ve bunlar o sohbetlerin ve ayarların hayatta kalan tek kopyası olabilir. Bu işlem geri alınamaz.';

  @override
  String get storageSpaceRestoreTracesHint =>
      'Tamamlanan geri yüklemelerden sonra saklanan önceki veri anlık görüntüleri. Bunları temizlemek mevcut uygulama verilerini etkilemez.';

  @override
  String get storageSpaceClearRestoreTracesButton =>
      'Geri Yükleme İzlerini Temizle';

  @override
  String get storageSpaceClearDisplacedDatabasesButton =>
      'Ayrılmış Veritabanlarını Sil';

  @override
  String get storageSpaceClearRestoreTracesConfirmMessage =>
      'Tamamlanan geri yükleme anlık görüntüleri temizlensin mi? Mevcut veritabanınız, ayarlarınız ve dosyalarınız etkilenmeyecek.';

  @override
  String get storageSpaceSubCompletedRestoreRuns =>
      'Tamamlanan geri yükleme anlık görüntüleri';

  @override
  String get storageSpaceCategoryCache => 'Önbellek';

  @override
  String get storageSpaceCategoryLogs => 'Günlükler';

  @override
  String get storageSpaceCategoryOther => 'Diğer';

  @override
  String get storageSpaceSafeToClearHint =>
      'Temizlemek güvenlidir. Sohbet geçmişinizi etkilemez.';

  @override
  String get storageSpaceLegacyChatDataHint =>
      'Bunlar SQLite geçişinden önce kalan Hive dosyalarıdır. Temizlemek mevcut sohbet kayıtlarınızı silmez.';

  @override
  String get storageSpaceNotSafeToClearHint =>
      'Sohbet geçmişinizi etkileyebilir. Dikkatli silin.';

  @override
  String get storageSpaceBreakdownTitle => 'Ayrıntılar';

  @override
  String get storageSpaceSubChatMessages => 'Mesajlar';

  @override
  String get storageSpaceSubChatConversations => 'Sohbetler';

  @override
  String get storageSpaceSubChatToolEvents => 'Araç olayları';

  @override
  String get storageSpaceSubChatDatabase => 'Sohbet veritabanı';

  @override
  String get storageSpaceSubChatWriteAheadLog => 'Ön yazma günlüğü';

  @override
  String get storageSpaceSubChatSharedMemory => 'Paylaşılan bellek dizini';

  @override
  String get storageSpaceSubCacheAvatars => 'Avatar önbelleği';

  @override
  String get storageSpaceSubCacheOther => 'Diğer önbellek';

  @override
  String get storageSpaceSubCacheSystem => 'Sistem önbelleği';

  @override
  String get storageSpaceSubLogsContext => 'Bağlam günlükleri';

  @override
  String get storageSpaceSubLogsFlutter => 'Flutter günlükleri';

  @override
  String get storageSpaceSubLogsRequests => 'Ağ günlükleri';

  @override
  String get storageSpaceSubLogsOther => 'Diğer günlükler';

  @override
  String get storageSpaceClearConfirmTitle => 'Temizlemeyi onayla';

  @override
  String storageSpaceClearConfirmMessage(String targetName) {
    return '$targetName temizlensin mi?';
  }

  @override
  String get storageSpaceClearButton => 'Temizle';

  @override
  String storageSpaceClearDone(String targetName) {
    return '$targetName temizlendi';
  }

  @override
  String storageSpaceClearFailed(String error) {
    return 'Temizleme başarısız: $error';
  }

  @override
  String get storageSpaceClearAvatarCacheButton => 'Avatar Önbelleğini Temizle';

  @override
  String get storageSpaceClearCacheButton => 'Önbelleği Temizle';

  @override
  String get storageSpaceClearLogsButton => 'Günlükleri Temizle';

  @override
  String get storageSpaceClearLegacyChatDataButton =>
      'Eski Sohbet Kayıtlarını Temizle';

  @override
  String get storageSpaceExportLegacyChatFileButton => 'Dışa aktar';

  @override
  String storageSpaceExportDone(Object fileName) {
    return '$fileName dışa aktarıldı';
  }

  @override
  String storageSpaceExportFailed(Object error) {
    return 'Dışa aktarma başarısız: $error';
  }

  @override
  String get storageSpaceClearLegacyChatDataConfirmMessage =>
      'Saklanan eski sohbet dosyaları temizlensin mi? Mevcut SQLite sohbet kayıtlarınız kullanılabilir kalacak.';

  @override
  String get storageSpaceViewLogsButton => 'Günlükleri Görüntüle';

  @override
  String get storageSpaceDeleteConfirmTitle => 'Silmeyi onayla';

  @override
  String storageSpaceDeleteUploadsConfirmMessage(int count) {
    return '$count öğe ve bunlarla ilişkili sohbet ek kopyaları silinsin mi? Bu ekler artık sohbet geçmişinde kullanılamayacak.';
  }

  @override
  String storageSpaceDeletedUploadsDone(int count) {
    return '$count öğe silindi';
  }

  @override
  String get storageSpaceNoUploads => 'Öğe yok';

  @override
  String get storageSpaceSelectAll => 'Tümünü seç';

  @override
  String get storageSpaceClearSelection => 'Seçimi temizle';

  @override
  String storageSpaceSelectedCount(int count) {
    return '$count seçildi';
  }

  @override
  String storageSpaceUploadsCount(int count) {
    return '$count öğe';
  }

  @override
  String get storageSpaceSortLabel => 'Sırala';

  @override
  String get storageSpaceSortNewest => 'En yeni';

  @override
  String get storageSpaceSortOldest => 'En eski';

  @override
  String get storageSpaceSortLargest => 'En büyük';

  @override
  String get storageSpaceSortSmallest => 'En küçük';

  @override
  String get settingsPageAboutSection => 'Hakkında';

  @override
  String get settingsPageAbout => 'Hakkında';

  @override
  String get settingsPageStatistics => 'İstatistikler';

  @override
  String get settingsPageDocs => 'Belgeler';

  @override
  String get settingsPageLogs => 'Günlükler';

  @override
  String get settingsPageSponsor => 'Sponsor';

  @override
  String get settingsPageShare => 'Paylaş';

  @override
  String get statsPageTitle => 'İstatistikler';

  @override
  String get statsPageRangeAllTime => 'Tüm Zamanlar';

  @override
  String get statsPageRangeLast30Days => 'Son 30 Gün';

  @override
  String get statsPageRangePreviousMonth => 'Geçen Ay';

  @override
  String get statsPageRangePreviousQuarter => 'Geçen Çeyrek';

  @override
  String get statsPageRangeCustom => 'Özel';

  @override
  String get statsPageHeatmapTitle => 'Sohbet Isı Haritası';

  @override
  String get statsPageHeatmapLess => 'Az';

  @override
  String get statsPageHeatmapMore => 'Çok';

  @override
  String get statsPageSummaryTitle => 'Genel Bakış';

  @override
  String get statsPageTotalConversations => 'Toplam Sohbet';

  @override
  String get statsPageTotalMessages => 'Toplam Mesaj';

  @override
  String get statsPageInputTokens => 'Giriş Tokenları';

  @override
  String get statsPageOutputTokens => 'Çıkış Tokenları';

  @override
  String get statsPageCachedTokens => 'Önbellek Tokenları';

  @override
  String get statsPageLaunchCount => 'Uygulama Başlatmaları';

  @override
  String statsPageCost(String currency) {
    return 'Maliyet ($currency)';
  }

  @override
  String statsPageModelsWithoutPricing(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count model fiyatlandırmasız',
      one: '$count model fiyatlandırmasız',
    );
    return '$_temp0';
  }

  @override
  String get statsPageUsageTrendTitle => 'Kullanım Eğilimi';

  @override
  String get statsPageModelUsageTitle => 'Model Kullanımı';

  @override
  String get statsPageAssistantUsageTitle => 'Asistan Kullanımı';

  @override
  String get statsPageTopicVolumeTitle => 'Konu Hacmi';

  @override
  String get statsPageModelColumn => 'Model';

  @override
  String get statsPageAssistantColumn => 'Asistan';

  @override
  String get statsPageTopicColumn => 'Konu';

  @override
  String get statsPageMessagesColumn => 'Mesajlar';

  @override
  String get statsPageTopicsColumn => 'Konular';

  @override
  String get statsPageEmptyTitle => 'Henüz istatistik yok';

  @override
  String get statsPageShowAllTooltip => 'Tümünü göster';

  @override
  String get statsPageClose => 'Kapat';

  @override
  String get statsPageUnknownProvider => 'Bilinmeyen Sağlayıcı';

  @override
  String get statsPageUnknownAssistant => 'Varsayılan Asistan';

  @override
  String get statsPageUnknownModel => 'Bilinmeyen Model';

  @override
  String get statsPageUnknownTopic => 'Başlıksız Konu';

  @override
  String get statsPageCustomRangeTitle => 'Özel Aralık';

  @override
  String get statsPageCustomRangeStart => 'Başlangıç';

  @override
  String get statsPageCustomRangeEnd => 'Bitiş';

  @override
  String get statsPageCustomRangeCancel => 'İptal';

  @override
  String get statsPageCustomRangeApply => 'Uygula';

  @override
  String get sponsorPageMethodsSectionTitle => 'Sponsorluk Yöntemleri';

  @override
  String get sponsorPageSponsorsSectionTitle => 'Sponsorlar';

  @override
  String get sponsorPageEmpty => 'Henüz sponsor yok';

  @override
  String get sponsorPageAfdianTitle => 'Afdian';

  @override
  String get sponsorPageAfdianSubtitle => 'afdian.com/a/kelivo';

  @override
  String get sponsorPageWeChatTitle => 'WeChat Sponsoru';

  @override
  String get sponsorPageWeChatSubtitle => 'WeChat sponsor kodu';

  @override
  String get sponsorPageScanQrHint => 'Sponsor olmak için QR kodunu tarayın';

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
  String get languageDisplayItalian => 'İtalyanca';

  @override
  String get languageDisplaySpanish => 'İspanyolca';

  @override
  String get languageSelectSheetTitle => 'Çeviri Dilini Seç';

  @override
  String get languageSelectSheetClearButton => 'Çeviriyi Temizle';

  @override
  String get homePageClearContext => 'Bağlamı Temizle';

  @override
  String contextMessageCount(int count) {
    return '$count mesaj';
  }

  @override
  String contextMessageCountLimited(int actual, int configured) {
    return '$actual/$configured mesaj';
  }

  @override
  String get homePageDefaultAssistant => 'Varsayılan Asistan';

  @override
  String get mermaidExportPng => 'PNG Dışa Aktar';

  @override
  String get mermaidExportFailed => 'Dışa aktarma başarısız';

  @override
  String get mermaidImageTab => 'Görsel';

  @override
  String get mermaidCodeTab => 'Kod';

  @override
  String get mermaidFullScreen => 'Tam ekran';

  @override
  String get mermaidGeneratingImage => 'Görsel oluşturuluyor';

  @override
  String get mermaidGenerationFailedHint =>
      'Oluşturma başarısız. Başka bir şekilde sormayı deneyin.';

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
  String assistantProviderSampleAssistantSystemPrompt(String model_name) {
    return 'Sen $model_name, yardımcı bir AI asistanısın. Doğru ve kısa yanıt ver; emin olmadığında bunu belirt. Yardımcı olduğunda net yapı (kısa paragraflar veya listeler) kullanmayı tercih et. Varsayılan olarak kullanıcının dilinde yanıt ver.';
  }

  @override
  String get displaySettingsPageLanguageTitle => 'Uygulama Dili';

  @override
  String get displaySettingsPageLanguageSubtitle => 'Arayüz dilini seçin';

  @override
  String get assistantTagsManageTitle => 'Etiketleri Yönet';

  @override
  String get assistantTagsCreateButton => 'Oluştur';

  @override
  String get assistantTagsCreateDialogTitle => 'Etiket Oluştur';

  @override
  String get assistantTagsCreateDialogOk => 'Oluştur';

  @override
  String get assistantTagsCreateDialogCancel => 'İptal';

  @override
  String get assistantTagsNameHint => 'Etiket adı';

  @override
  String get assistantTagsRenameButton => 'Yeniden Adlandır';

  @override
  String get assistantTagsRenameDialogTitle => 'Etiketi Yeniden Adlandır';

  @override
  String get assistantTagsRenameDialogOk => 'Yeniden Adlandır';

  @override
  String get assistantTagsDeleteButton => 'Sil';

  @override
  String get assistantTagsDeleteConfirmTitle => 'Etiketi Sil';

  @override
  String get assistantTagsDeleteConfirmContent =>
      'Bu etiketi silmek istediğinizden emin misiniz?';

  @override
  String get assistantTagsDeleteConfirmOk => 'Sil';

  @override
  String get assistantTagsDeleteConfirmCancel => 'İptal';

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
  String get mcpTransportTagSse => 'SSE';

  @override
  String get mcpTransportTagHttp => 'HTTP';

  @override
  String get mcpServerEditSheetStdioCommandLabel => 'Komut';

  @override
  String get mcpServerEditSheetStdioArgumentsLabel => 'Bağımsız Değişkenler';

  @override
  String get mcpServerEditSheetStdioWorkingDirectoryLabel =>
      'Çalışma Dizini (isteğe bağlı)';

  @override
  String get mcpWorkspaceBindingLabel => 'Çalışma alanını bağla (isteğe bağlı)';

  @override
  String get mcpWorkspaceBindingHint =>
      'Sunucu bu çalışma alanına /workspace üzerinden erişebilir. Çalışma Dizini boş bırakılırsa orada başlar. Sohbetler arasında geçiş yaptığınızda bağlantı sabit kalır.';

  @override
  String get mcpWorkspaceBindingMobileOnly =>
      'Çalışma alanı bağlama, mobil Linux ortamında kullanılabilir. Bu sunucuyu masaüstünde çalıştırmak için bağlantıyı kaldırın.';

  @override
  String get mcpServerEditSheetStdioEnvironmentTitle => 'Ortam';

  @override
  String get mcpServerEditSheetStdioEnvNameLabel => 'Ad';

  @override
  String get mcpServerEditSheetStdioEnvValueLabel => 'Değer';

  @override
  String get mcpServerEditSheetStdioAddEnv => 'Ortam Değişkeni Ekle';

  @override
  String get mcpServerEditSheetStdioCommandRequired =>
      'STDIO için komut gereklidir';

  @override
  String get assistantTagsContextMenuDeleteAssistant => 'Asistanı Sil';

  @override
  String get assistantTagsClearTag => 'Etiketi Temizle';

  @override
  String get displaySettingsPageLanguageChineseLabel =>
      'Basitleştirilmiş Çince';

  @override
  String get displaySettingsPageLanguageEnglishLabel => 'İngilizce';

  @override
  String get homePagePleaseSelectModel => 'Lütfen önce bir model seçin';

  @override
  String get homePagePleaseSetupTranslateModel =>
      'Lütfen önce bir çeviri modeli ayarlayın';

  @override
  String get homePageTranslating => 'Çevriliyor...';

  @override
  String homePageTranslateFailed(String error) {
    return 'Çeviri başarısız: $error';
  }

  @override
  String get chatServiceDefaultConversationTitle => 'Yeni Sohbet';

  @override
  String get userProviderDefaultUserName => 'Kullanıcı';

  @override
  String get homePageDeleteMessage => 'Bu Sürümü Sil';

  @override
  String get homePageDeleteMessageConfirm =>
      'Bu sürümü silmek istediğinizden emin misiniz? Bu işlem geri alınamaz.';

  @override
  String get homePageDeleteAllVersions => 'Tüm Sürümleri Sil';

  @override
  String get homePageDeleteAllVersionsConfirm =>
      'Bu mesajın tüm sürümlerini silmek istediğinizden emin misiniz? Bu işlem geri alınamaz.';

  @override
  String get homePageCancel => 'İptal';

  @override
  String get homePageDelete => 'Sil';

  @override
  String get homePageSelectMessagesToShare =>
      'Lütfen paylaşmak için mesaj seçin';

  @override
  String get homePageDone => 'Tamam';

  @override
  String get homePageDropToUpload => 'Yüklemek için dosyaları bırakın';

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
  String get assistantEditPageCustomTab => 'Özel';

  @override
  String get assistantEditPageRegexTab => 'Regex Değiştirme';

  @override
  String get assistantEditPageLocalToolsTab => 'Yerel Araçlar';

  @override
  String get assistantEditTabLayoutTooltip => 'Sekmeleri özelleştir';

  @override
  String get assistantEditTabLayoutTitle => 'Sekmeleri özelleştir';

  @override
  String get assistantEditTabLayoutSubtitle =>
      'Sıralamak için sekmeleri sürükleyin. İhtiyacınız olmayan sekmeleri kapatın.';

  @override
  String get assistantEditOutlineModeTitle => 'Bölüm listesi stili';

  @override
  String get assistantEditOutlineModeSubtitle =>
      'Önce bir asistan genel bakışı gösterin, ardından her ayar bölümünü bir listeden açın.';

  @override
  String get assistantEditTabLayoutResetTooltip => 'Sekme düzenini sıfırla';

  @override
  String get assistantEditTabLayoutAtLeastOneVisible =>
      'En az bir sekme görünür kalmalı';

  @override
  String assistantEditTabLayoutDragHandle(String tab) {
    return 'Sıralamak için $tab sürükleyin';
  }

  @override
  String get assistantEditRegexDescription =>
      'Kullanıcı/asistan mesajlarını yeniden yazmak veya görsel olarak ayarlamak için regex kuralları oluşturun.';

  @override
  String get assistantEditAddRegexButton => 'Regex Kuralı Ekle';

  @override
  String get assistantRegexAddTitle => 'Regex Kuralı Ekle';

  @override
  String get assistantRegexEditTitle => 'Regex Kuralını Düzenle';

  @override
  String get assistantRegexNameLabel => 'Kural Adı';

  @override
  String get assistantRegexPatternLabel => 'Düzenli İfade';

  @override
  String get assistantRegexReplacementLabel => 'Değiştirme Dizesi';

  @override
  String get assistantRegexScopeLabel => 'Etkilenen Kapsam';

  @override
  String get assistantRegexScopeUser => 'Kullanıcı';

  @override
  String get assistantRegexScopeAssistant => 'Asistan';

  @override
  String get assistantRegexScopeVisualOnly => 'Yalnızca Görsel';

  @override
  String get assistantRegexScopeReplaceOnly => 'Yalnızca Değiştir';

  @override
  String get assistantRegexAddAction => 'Ekle';

  @override
  String get assistantRegexSaveAction => 'Kaydet';

  @override
  String get assistantRegexDeleteButton => 'Sil';

  @override
  String get assistantRegexValidationError =>
      'Lütfen adı, regex\'i doldurun ve en az bir kapsam seçin.';

  @override
  String get assistantRegexInvalidPattern => 'Geçersiz düzenli ifade';

  @override
  String get assistantRegexCancelButton => 'İptal';

  @override
  String get assistantRegexUntitled => 'Adsız Kural';

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
  String get assistantEditCustomBodyEmpty => 'Gövde öğesi eklenmedi';

  @override
  String get assistantEditHeaderNameLabel => 'Başlık Adı';

  @override
  String get assistantEditHeaderValueLabel => 'Başlık Değeri';

  @override
  String get assistantEditBodyKeyLabel => 'Gövde Anahtarı';

  @override
  String get assistantEditBodyValueLabel => 'Gövde Değeri (JSON)';

  @override
  String get assistantEditDeleteTooltip => 'Sil';

  @override
  String get assistantEditAssistantNameLabel => 'Asistan Adı';

  @override
  String get assistantEditUseAssistantAvatarTitle => 'Asistan Avatarını Kullan';

  @override
  String get assistantEditUseAssistantAvatarSubtitle =>
      'Model avatarı yerine asistan avatarını kullan';

  @override
  String get assistantEditUseAssistantNameTitle => 'Asistan Adını Kullan';

  @override
  String get assistantEditChatModelTitle => 'Sohbet Modeli';

  @override
  String get assistantEditChatModelSubtitle =>
      'Bu asistan için varsayılan sohbet modeli (ayarlanmazsa genel varsayılan kullanılır)';

  @override
  String get assistantEditTemperatureDescription =>
      'Rastgeleliği kontrol eder, aralık 0–2';

  @override
  String get assistantEditTopPDescription =>
      'Ne yaptığınızı bilmiyorsanız bu değeri değiştirmeyin';

  @override
  String get assistantEditParameterDisabled =>
      'Devre dışı (sağlayıcı varsayılanını kullanır)';

  @override
  String get assistantEditParameterDisabled2 => 'Devre dışı (kısıtlama yok)';

  @override
  String get assistantEditContextMessagesTitle => 'Bağlam Mesajları';

  @override
  String get assistantEditContextMessagesDescription =>
      'Bağlamda kaç son mesajın tutulacağı';

  @override
  String get assistantEditStreamOutputTitle => 'Akış Çıktısı';

  @override
  String get assistantEditStreamOutputDescription =>
      'Akışlı yanıtları etkinleştir';

  @override
  String get assistantEditThinkingBudgetTitle => 'Düşünme';

  @override
  String get assistantEditReasoningFollowDefault => 'Model varsayılanını izle';

  @override
  String get assistantEditReasoningClampedSubtitle =>
      'Gerçek seviye her modelin desteklediğiyle sınırlanır';

  @override
  String get assistantEditConfigureButton => 'Yapılandır';

  @override
  String get assistantEditMaxTokensTitle => 'Maks Token';

  @override
  String get assistantEditMaxTokensDescription => 'Sınırsız için boş bırakın';

  @override
  String get assistantEditMaxTokensHint => 'Sınırsız';

  @override
  String get assistantEditChatBackgroundTitle => 'Sohbet Arka Planı';

  @override
  String get assistantEditChatBackgroundDescription =>
      'Bu asistan için bir arka plan görseli ayarlayın';

  @override
  String get assistantEditChooseImageButton => 'Görsel Seç';

  @override
  String get assistantEditClearButton => 'Temizle';

  @override
  String get desktopNavChatTooltip => 'Sohbet';

  @override
  String get desktopNavTranslateTooltip => 'Çeviri';

  @override
  String get desktopNavStorageTooltip => 'Depolama';

  @override
  String get desktopNavGlobalSearchTooltip => 'Genel Arama';

  @override
  String get desktopNavThemeToggleTooltip => 'Tema';

  @override
  String get desktopNavSettingsTooltip => 'Ayarlar';

  @override
  String get desktopAvatarMenuUseEmoji => 'Emoji kullan';

  @override
  String get cameraPermissionDeniedMessage =>
      'Kamera kullanılamıyor: izin verilmedi.';

  @override
  String get openSystemSettings => 'Ayarları Aç';

  @override
  String get desktopAvatarMenuChangeFromImage => 'Görselden değiştir…';

  @override
  String get desktopAvatarMenuReset => 'Avatarı sıfırla';

  @override
  String get assistantEditAvatarChooseImage => 'Görsel Seç';

  @override
  String get assistantEditAvatarChooseEmoji => 'Emoji Seç';

  @override
  String get assistantEditAvatarEnterLink => 'Bağlantı Gir';

  @override
  String get assistantEditAvatarImportQQ => 'QQ\'dan içe aktar';

  @override
  String get assistantEditAvatarReset => 'Sıfırla';

  @override
  String get displaySettingsPageChatMessageBackgroundTitle =>
      'Sohbet Mesajı Arka Planı';

  @override
  String get displaySettingsPageChatMessageBackgroundDefault => 'Varsayılan';

  @override
  String get displaySettingsPageChatMessageBackgroundFrosted => 'Buzlu Cam';

  @override
  String get displaySettingsPageChatMessageBackgroundSolid => 'Düz Renk';

  @override
  String get displaySettingsPageAndroidBackgroundChatTitle =>
      'Arka Plan Oluşturma (Android)';

  @override
  String get displaySettingsPageIosBackgroundChatTitle =>
      'Arka Plan Oluşturma (iOS)';

  @override
  String get iosBackgroundStatusOn => 'Açık';

  @override
  String get iosBackgroundStatusOff => 'Kapalı';

  @override
  String get iosLiveActivityTitle => 'Canlı Etkinlik';

  @override
  String get iosLiveActivitySubtitle =>
      'Desteklendiğinde arka plan yanıtlarını Kilit Ekranında ve Dinamik Ada\'da göster.';

  @override
  String get notificationChatCompletedTitle => 'Oluşturma tamamlandı';

  @override
  String get notificationChatCompletedBody => 'Asistan yanıtı oluşturuldu';

  @override
  String get assistantEditEmojiDialogTitle => 'Emoji Seç';

  @override
  String get assistantEditEmojiDialogHint =>
      'Herhangi bir emoji yazın veya yapıştırın';

  @override
  String get assistantEditEmojiDialogCancel => 'İptal';

  @override
  String get assistantEditEmojiDialogSave => 'Kaydet';

  @override
  String get assistantEditImageUrlDialogTitle => 'Görsel URL\'si Gir';

  @override
  String get assistantEditImageUrlDialogHint =>
      'örn. https://example.com/avatar.png';

  @override
  String get assistantEditImageUrlDialogCancel => 'İptal';

  @override
  String get assistantEditImageUrlDialogSave => 'Kaydet';

  @override
  String get assistantEditQQAvatarDialogTitle => 'QQ\'den içe aktar';

  @override
  String get assistantEditQQAvatarDialogHint => 'QQ numarası girin (5-12 hane)';

  @override
  String get assistantEditQQAvatarRandomButton => 'Rastgele';

  @override
  String get assistantEditQQAvatarFailedMessage =>
      'Rastgele QQ avatarı alınamadı. Lütfen tekrar deneyin.';

  @override
  String get assistantEditQQAvatarDialogCancel => 'İptal';

  @override
  String get assistantEditQQAvatarDialogSave => 'Kaydet';

  @override
  String get assistantEditGalleryErrorMessage =>
      'Galeri açılamıyor. Bir görsel URL\'si girmeyi deneyin.';

  @override
  String get assistantEditGeneralErrorMessage =>
      'Bir şeyler ters gitti. Bir görsel URL\'si girmeyi deneyin.';

  @override
  String get providerDetailPageMultiKeyModeTitle => 'Çoklu Anahtar Modu';

  @override
  String get providerDetailPageManageKeysButton => 'Anahtarları Yönet';

  @override
  String get multiKeyPageTitle => 'Çoklu Anahtar Yöneticisi';

  @override
  String get multiKeyPageDetect => 'Algıla';

  @override
  String get multiKeyPageAdd => 'Ekle';

  @override
  String get multiKeyPageAddHint =>
      'API anahtarlarını girin, virgül veya boşlukla ayırın';

  @override
  String multiKeyPageImportedSnackbar(int n) {
    return '$n anahtar içe aktarıldı';
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
  String get multiKeyPageAccuracy => 'Doğruluk';

  @override
  String get multiKeyPageStrategyTitle => 'Yük Dengeleme Stratejisi';

  @override
  String get multiKeyPageStrategyRoundRobin => 'Sırayla';

  @override
  String get multiKeyPageStrategyPriority => 'Öncelik';

  @override
  String get multiKeyPageStrategyLeastUsed => 'En Az Kullanılan';

  @override
  String get multiKeyPageStrategyRandom => 'Rastgele';

  @override
  String get multiKeyPageNoKeys => 'API anahtarı yok';

  @override
  String get multiKeyPageStatusActive => 'Etkin';

  @override
  String get multiKeyPageStatusDisabled => 'Devre dışı';

  @override
  String get multiKeyPageStatusError => 'Hata';

  @override
  String get multiKeyPageStatusRateLimited => 'Hız Sınırlı';

  @override
  String get multiKeyPageEditAlias => 'Takma Adı Düzenle';

  @override
  String get multiKeyPageEdit => 'Düzenle';

  @override
  String get multiKeyPageKey => 'API Anahtarı';

  @override
  String get multiKeyPagePriority => 'Öncelik (1–10)';

  @override
  String get multiKeyPageDuplicateKeyWarning => 'Bu anahtar zaten mevcut';

  @override
  String get multiKeyPageAlias => 'Takma Ad';

  @override
  String get multiKeyPageCancel => 'İptal';

  @override
  String get multiKeyPageSave => 'Kaydet';

  @override
  String get multiKeyPageDelete => 'Sil';

  @override
  String get assistantEditSystemPromptTitle => 'Sistem İstemi';

  @override
  String get assistantEditSystemPromptHint => 'Sistem istemini girin…';

  @override
  String get assistantEditSystemPromptImportButton => 'Dosyadan içe aktar';

  @override
  String get assistantEditSystemPromptImportSuccess =>
      'Sistem istemi dosyadan güncellendi';

  @override
  String get assistantEditSystemPromptImportFailed => 'Dosya içe aktarılamadı';

  @override
  String get assistantEditSystemPromptImportEmpty => 'Dosya boş';

  @override
  String get assistantEditAvailableVariables => 'Kullanılabilir değişkenler:';

  @override
  String get assistantEditVariableDate => 'Tarih';

  @override
  String get assistantEditVariableTime => 'Saat';

  @override
  String get assistantEditVariableDatetime => 'Tarih ve saat';

  @override
  String get assistantEditVariableModelId => 'Model Kimliği';

  @override
  String get assistantEditVariableModelName => 'Model Adı';

  @override
  String get assistantEditVariableLocale => 'Yerel Ayar';

  @override
  String get assistantEditVariableTimezone => 'Saat Dilimi';

  @override
  String get assistantEditVariableSystemVersion => 'Sistem Sürümü';

  @override
  String get assistantEditVariableDeviceInfo => 'Cihaz Bilgisi';

  @override
  String get assistantEditVariableBatteryLevel => 'Pil Seviyesi';

  @override
  String get assistantEditVariableNickname => 'Takma Ad';

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
  String get assistantEditPromptTimeVarWarning =>
      'Sistem isteminde zaman değişkenleri kullanmak her isteğin başlangıcını farklı kılar; bu nedenle istem önbelleği devreye giremez ve hem maliyet hem de ilk token süresi artar. Modelin geçerli saati bilmesi gerekiyorsa aşağıdaki \"Geçerli saati ekle\" anahtarını kullanın.';

  @override
  String get assistantEditPromptIso8601Title => 'ISO 8601 biçimini kullan';

  @override
  String get assistantEditPromptIso8601Subtitle =>
      'Saat dilimi farkını dahil et, ör. 2026-08-08T14:30:05+08:00';

  @override
  String get assistantEditPromptAppendTimeTitle => 'Geçerli saati ekle';

  @override
  String get assistantEditPromptAppendTimeSubtitle =>
      'Her kullanıcı mesajının sonuna gönderim saatini ekle. Saat isteğin sonunda kalır, bu nedenle istem önbelleği etkilenmez.';

  @override
  String get assistantEditPromptAppendTimeInfoTitle => 'Eklenen saat biçimi';

  @override
  String assistantEditPromptAppendTimeInfoBody(String example) {
    return 'Etkinleştirildiğinde, her kullanıcı mesajının sonuna boş bir satır ve ardından aşağıdaki etiket eklenir:\n\n$example\n\nZaman damgası o mesajın kendi gönderim saatidir, bu nedenle yeniden denediğinizde sabit kalır.';
  }

  @override
  String get assistantEditPromptAppendTimeInfoClose => 'Anladım';

  @override
  String get assistantEditPromptTimeVarDialogTitle =>
      'Sistem istemi zaman değişkenleri içeriyor';

  @override
  String assistantEditPromptTimeVarDialogBody(String variables) {
    return 'Sistem isteminiz $variables kullanıyor. Sistem istemi her istekte yeniden oluşturulur, bu nedenle zaman değişkenleri her isteğin başlangıcını farklı kılar ve istem önbelleği devreye giremez. Bu değişkenleri kaldırıp bunun yerine \"Geçerli saati ekle\" seçeneğini kullanmayı düşünün — saat isteğin sonuna eklenir ve öneki etkilemez.';
  }

  @override
  String get assistantEditPromptTimeVarDialogRemove => 'Kaldırmaya git';

  @override
  String get assistantEditPromptTimeVarDialogKeep => 'Yine de etkinleştir';

  @override
  String get codeBlockPreviewButton => 'Önizleme';

  @override
  String get codeBlockSaveAsButton => 'Dosya olarak kaydet';

  @override
  String get codeBlockCollapseButton => 'Daralt';

  @override
  String get codeBlockExpandButton => 'Genişlet';

  @override
  String get codeBlockDefaultFileNameStem => 'kod';

  @override
  String get markdownTableLabel => 'Tablo';

  @override
  String get markdownTableExportCsvTooltip => 'CSV dışa aktar';

  @override
  String get markdownTableSaveImageTooltip => 'Galeriye kaydet';

  @override
  String get markdownTableDefaultFileNameStem => 'tablo';

  @override
  String get markdownTableCopiedCsvSnackbar =>
      'CSV kopyalandı. Görsel olarak kopyalamak için Kopyala\'ya uzun basın.';

  @override
  String get markdownTableCopiedMarkdownSnackbar => 'Tablo kopyalandı.';

  @override
  String codeBlockCollapsedLines(int n) {
    return '… $n satır katlandı';
  }

  @override
  String get htmlPreviewNotSupportedOnLinux =>
      'HTML önizleme Linux\'ta desteklenmiyor';

  @override
  String get assistantEditSampleUser => 'Kullanıcı';

  @override
  String get assistantEditSampleMessage => 'Merhaba';

  @override
  String get assistantEditSampleReply =>
      'Merhaba, size nasıl yardımcı olabilirim?';

  @override
  String get assistantEditMcpNoServersMessage => 'Çalışan MCP sunucusu yok';

  @override
  String get assistantEditMcpConnectedTag => 'Bağlı';

  @override
  String assistantEditMcpToolsCountTag(String enabled, String total) {
    return 'Araçlar: $enabled/$total';
  }

  @override
  String get assistantEditModelUseGlobalDefault => 'Genel varsayılanı kullan';

  @override
  String get assistantSettingsPageTitle => 'Asistan Ayarları';

  @override
  String get assistantSettingsCopyButton => 'Kopyala';

  @override
  String get assistantSettingsCopySuccess => 'Asistan kopyalandı';

  @override
  String get assistantSettingsCopySuffix => 'Kopya';

  @override
  String get assistantCopyTitle => 'Asistanı kopyala';

  @override
  String get assistantCopyDefaultHint =>
      'Kopyalanacakları seçin veya her şeyi kopyalayın.';

  @override
  String get assistantCopyConfiguration => 'Asistan yapılandırması';

  @override
  String get assistantCopyConfigurationHint =>
      'Her zaman dahil edilir: ad, avatar, istemler, model, parametreler ve ön ayarlı mesajlar.';

  @override
  String get assistantCopyMemories => 'Asistan anıları';

  @override
  String get assistantCopyMemoriesHint =>
      'Mevcut ve eski anıları arşiv durumunu koruyarak içerir. Genel anılar paylaşılmaya devam eder.';

  @override
  String get assistantCopyChooseMemories => 'Anıları seç';

  @override
  String get assistantCopyChooseEntries => 'Girdileri seç';

  @override
  String get assistantCopyPhrasesHint =>
      'Bu asistanın ifadelerini kopyala. Genel ifadeler paylaşılmaya devam eder.';

  @override
  String get assistantCopyBindingsHint =>
      'Bu seçenekler mevcut kaynakları yeniden kullanır; çalışma alanı dosyaları kopyalanmaz. Seçilmeyen dünya kitapları ve enjeksiyonlar genel varsayılanları kullanır.';

  @override
  String get assistantCopyWorldBooks => 'Dünya kitabı bağlantıları';

  @override
  String get assistantCopySkills => 'Beceri seçimi';

  @override
  String get assistantCopyTools => 'Araç ve arama ayarları';

  @override
  String get assistantCopyWorkspace => 'Varsayılan çalışma alanı bağlantısı';

  @override
  String get assistantCopyAll => 'Her şeyi kopyala';

  @override
  String get assistantCopyInProgress => 'Kopyalanıyor…';

  @override
  String get assistantCopyFailed =>
      'Asistan kopyalanamadı. Orijinal verileriniz değişmedi. Lütfen tekrar deneyin.';

  @override
  String get assistantCopyMemoryLoadFailed =>
      'Anılar yüklenemedi. Lütfen tekrar deneyin.';

  @override
  String get assistantCopyRetry => 'Tekrar dene';

  @override
  String get assistantCopyNoMemories =>
      'Bu asistanın kopyalanacak kişisel anısı yok.';

  @override
  String get assistantCopySelectAll => 'Tüm anıları seç';

  @override
  String get assistantSettingsDeleteButton => 'Sil';

  @override
  String get assistantSettingsEditButton => 'Düzenle';

  @override
  String get assistantSettingsAddSheetTitle => 'Asistan Adı';

  @override
  String get assistantSettingsAddSheetHint => 'Bir ad girin';

  @override
  String get assistantSettingsAddSheetCancel => 'İptal';

  @override
  String get assistantSettingsAddSheetSave => 'Kaydet';

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
  String get hotkeySwitchModel => 'Model Değiştir';

  @override
  String get hotkeyToggleAssistantPanel => 'Asistanları Aç/Kapat';

  @override
  String get hotkeyToggleTopicPanel => 'Konuları Aç/Kapat';

  @override
  String get hotkeysPressShortcut => 'Bir kısayol tuşlayın';

  @override
  String get hotkeysResetDefault => 'Varsayılana sıfırla';

  @override
  String get hotkeysClearShortcut => 'Kısayolu temizle';

  @override
  String get hotkeysResetAll => 'Tümünü varsayılana sıfırla';

  @override
  String get assistantEditTemperatureTitle => 'Sıcaklık';

  @override
  String get assistantEditTopPTitle => 'Top-p';

  @override
  String get assistantSettingsDeleteDialogTitle => 'Asistanı Sil';

  @override
  String get assistantSettingsDeleteDialogContent =>
      'Bu asistanı silmek istediğinizden emin misiniz? Bu işlem geri alınamaz.';

  @override
  String get assistantSettingsDeleteDialogCancel => 'İptal';

  @override
  String get assistantSettingsDeleteDialogConfirm => 'Sil';

  @override
  String get assistantSettingsAtLeastOneAssistantRequired =>
      'En az bir asistan gereklidir';

  @override
  String get assistantConversationMcpTitle => 'Sohbet başına MCP\'ye izin ver';

  @override
  String get assistantConversationMcpHint =>
      'Sohbetlerin kendi MCP sunucularını seçmesine izin ver. Sohbetler özelleştirilene kadar asistanın seçimini kullanır.';

  @override
  String get mcpSelectionInherited => 'Asistanı takip ediyor';

  @override
  String get mcpSelectionCustom => 'Bu sohbet için özel';

  @override
  String get mcpInheritAssistant => 'Asistan ayarlarını kullan';

  @override
  String get mcpAssistantSheetTitle => 'MCP Sunucuları';

  @override
  String get mcpAssistantSheetSubtitle =>
      'Bu asistan için etkinleştirilen sunucular';

  @override
  String get mcpAssistantSheetSelectAll => 'Tümünü Seç';

  @override
  String get mcpAssistantSheetClearAll => 'Temizle';

  @override
  String get backupPageTitle => 'Yedekleme ve Geri Yükleme';

  @override
  String get backupPageWebDavTab => 'WebDAV';

  @override
  String get backupPageImportExportTab => 'İçe/Dışa Aktarma';

  @override
  String get backupPageWebDavServerUrl => 'WebDAV Sunucu URL\'si';

  @override
  String get backupPageUsername => 'Kullanıcı adı';

  @override
  String get backupPagePassword => 'Parola';

  @override
  String get backupPagePath => 'Yol';

  @override
  String get backupPageChatsLabel => 'Sohbetler';

  @override
  String get backupPageFilesDescription =>
      'Sohbet ekleri, avatarlar, arka planlar ve özel yazı tipleri. Avatarları veya arka planları geri yüklemek için ilgili asistanları, sağlayıcıları veya ayarları da seçin.';

  @override
  String get backupPageChooseBackupFolder => 'Yedek klasörü seçin';

  @override
  String get backupPageChooseExternalFolder =>
      'iCloud Drive\'ı veya \"iPhone\'um > Kelivo\" dışında bir klasör seçin. Kelivo klasöründeki dosyalar uygulamayla birlikte silinir. Yedek kaydedilmedi.';

  @override
  String get backupPageFilesLabel => 'Dosyalar ve Görseller';

  @override
  String get backupPageScopeTitle => 'Yedekleme ve içe aktarma içeriği';

  @override
  String backupPageScopeSelectedCount(int selected, int total) {
    return '$selected/$total';
  }

  @override
  String get backupPageBackupManagementDescription =>
      'Neyin yedekleneceğini ve içe aktarılacağını seçin. Yerel, WebDAV ve S3 yedekleri için geçerlidir. Seçilmeyen içerik içe aktarmada değişmeden kalır. Beceriler ve çalışma alanları kendi dosyalarını içerir.';

  @override
  String get backupPageAssistantsLabel => 'Asistanlar';

  @override
  String get backupPageProvidersLabel => 'Sağlayıcılar';

  @override
  String get backupPageMcpLabel => 'MCP sunucuları';

  @override
  String get backupPageEnvironmentVariablesLabel => 'Ortam değişkenleri';

  @override
  String get backupPageSkillsLabel => 'Beceriler';

  @override
  String get backupPageWorldBooksLabel => 'Dünya kitapları';

  @override
  String get backupPageMemoriesLabel => 'Anılar';

  @override
  String get backupPageQuickPhrasesLabel => 'Hızlı ifadeler';

  @override
  String get backupPageInstructionsLabel => 'İstem enjeksiyonları';

  @override
  String get backupPageWorkspacesLabel => 'Çalışma alanları';

  @override
  String get backupPageSearchServicesLabel => 'Arama hizmetleri';

  @override
  String get backupPageSpeechServicesLabel => 'Konuşma hizmetleri';

  @override
  String get backupPageSettingsLabel => 'Diğer ayarlar';

  @override
  String get backupPageTestDone => 'Test tamamlandı';

  @override
  String get backupPageTestConnection => 'Test et';

  @override
  String get backupPageRestartRequired => 'Yeniden Başlatma Gerekli';

  @override
  String get backupPageRestartContent =>
      'İçe aktarma başarılı. Güvenli şekilde uygulamak için Kelivo\'yu yeniden başlatın.';

  @override
  String backupPageRestartContentWithSkipped(int count) {
    return 'İçe aktarma tamamlandı, ancak geçersiz mesaj sıralamasına sahip $count sohbet atlandı. İçe aktarılan verileri güvenli şekilde uygulamak için Kelivo\'yu yeniden başlatın.';
  }

  @override
  String get restartAppFailedMessage =>
      'Kelivo otomatik olarak yeniden başlatılamadı. Tamamen kapatın, ardından yeniden açın.';

  @override
  String get backupRestoreRolledBackTitle => 'Geri yükleme geri alındı';

  @override
  String get backupRestoreRolledBackContent =>
      'Geri yükleme tamamlanamadı. Kelivo önceki verilerinizi doğruladı ve korudu.';

  @override
  String get backupRestoreDirectoryBlockedTitle =>
      'Geri yükleme bir klasörü bekliyor';

  @override
  String get backupRestoreDirectoryBlockedContent =>
      'Windows aşağıdaki klasörü taşıyamadı. Klasörü kullanan terminalleri, düzenleyicileri veya diğer programları kapatın, ardından geri yüklemeye devam edin. Hâlâ engelleniyorsa hesabınızın klasörü taşıma iznine sahip olduğunu kontrol edin. Geri yükleme ilerlemeniz korundu.';

  @override
  String get backupRestoreContinueButton => 'Geri yüklemeye devam et';

  @override
  String get backupRestoreFailureTitle => 'Geri yükleme dikkat gerektiriyor';

  @override
  String get backupRestoreFailureContent =>
      'Kelivo eksiksiz bir eski veya yeni veri kümesini doğrulayamadı, bu nedenle sohbet verileri açılmadı. Kelivo\'yu kapatın ve tekrar deneyin. Sorun tekrarlanırsa destek için tanılama kodunu saklayın.';

  @override
  String get backupRestoreBusinessLeaseUnavailableTitle =>
      'Kelivo zaten çalışıyor';

  @override
  String get backupRestoreBusinessLeaseUnavailableContent =>
      'Kelivo\'nun verileri hâlâ başka bir uygulama süreci tarafından kullanılıyor. Diğer Kelivo pencerelerini kapatın, ardından yeniden başlatın. Sohbet verileriniz bu süreç tarafından açılmadı.';

  @override
  String get restoreProgressTitle => 'Yedeğiniz geri yükleniyor';

  @override
  String get restoreProgressWarning =>
      'Bu işlem bitene kadar Kelivo\'yu açık tutun. Şimdi kapatırsanız, bir sonraki başlatmada bu işlem baştan başlar.';

  @override
  String get restoreProgressStageCheckingBackup => 'Yedek kontrol ediliyor';

  @override
  String get restoreProgressStagePreservingCurrentData =>
      'Mevcut verileriniz korunuyor';

  @override
  String get restoreProgressStageInstallingBackup => 'Yedek yükleniyor';

  @override
  String get restoreProgressStageVerifying => 'Doğrulanıyor';

  @override
  String get restoreProgressStageRollingBack =>
      'Önceki verileriniz geri yükleniyor';

  @override
  String get restoreProgressStageFinishing => 'Tamamlanıyor';

  @override
  String get backupRestoreFailureRestartButton => 'Kelivo\'yu yeniden başlat';

  @override
  String get backupRestoreFailureCopyButton => 'Tanılama kodunu kopyala';

  @override
  String get backupRestoreFailureCopied => 'Tanılama kodu kopyalandı';

  @override
  String backupRestoreFailureDiagnostic(String code) {
    return 'Tanılama kodu: $code';
  }

  @override
  String get startupRecoveryMoreOptions => 'Daha fazla kurtarma seçeneği';

  @override
  String get startupRecoveryRepairButton => 'Onar ve yeniden başlat';

  @override
  String get startupRecoveryExportButton =>
      'Verilerimin bir kopyasını dışa aktar';

  @override
  String get startupRecoveryResetButton => 'Boş sohbet listesiyle başla';

  @override
  String get startupRecoveryBusy => 'İşleniyor…';

  @override
  String get startupRecoveryExportSucceeded =>
      'Verilerinizin bir kopyası kaydedildi.';

  @override
  String get startupRecoveryExportFailed =>
      'Verilerinizin bir kopyası dışa aktarılamadı.';

  @override
  String get startupRecoveryRepairFailed =>
      'Onarım tamamlanamadı. Verileriniz korundu; doğrulanmış bir kopya seçin veya daha fazla tanılama için verilerinizi dışa aktarın.';

  @override
  String get startupRecoveryResetFailed =>
      'Sıfırlama başarısız oldu. Kelivo\'yu tamamen kapatın, ardından yeniden açın.';

  @override
  String get startupRecoveryResetDialogTitle =>
      'Boş sohbet listesiyle başlansın mı?';

  @override
  String get startupRecoveryResetDialogContent =>
      'Bu işlem önceki sohbetlerinizi kurtarmaz. Kelivo mevcut veritabanını ve mevcut kopyaları koruyacak ve yeni bir boş sohbet listesi başlatacaktır. Sohbetlerinizi geri almak için iptal edip yerel bir kopya seçin.';

  @override
  String get startupRecoveryResetDialogConfirm =>
      'Kopyaları koru ve sıfırdan başla';

  @override
  String get startupRecoveryResetDialogCancel => 'İptal';

  @override
  String get startupRecoveryWhatFailed => 'Ne başarısız oldu';

  @override
  String get startupRecoveryStageLabel => 'Aşama';

  @override
  String get startupRecoveryStageRestore => 'Geri yükleme geçidi';

  @override
  String get startupRecoveryStageDatabase => 'Veritabanı başlatma';

  @override
  String get startupRecoveryDiagnosticLabel => 'Tanılama kodu';

  @override
  String get startupRecoverySchemaLabel => 'Veritabanı sürümü';

  @override
  String startupRecoverySchemaValue(String installed, int expected) {
    return 'Diskte $installed · bu sürüm $expected bekliyor';
  }

  @override
  String get startupRecoveryAppVersionLabel => 'Uygulama';

  @override
  String get startupRecoveryUnknownValue => 'bilinmiyor';

  @override
  String get startupRecoveryCollecting => 'Tanılama bilgileri toplanıyor…';

  @override
  String get startupRecoveryShowDetails => 'Teknik ayrıntıları göster';

  @override
  String get startupRecoveryHideDetails => 'Teknik ayrıntıları gizle';

  @override
  String get startupRecoveryCopyReport => 'Tam raporu kopyala';

  @override
  String get startupRecoveryReportCopied => 'Tam rapor kopyalandı';

  @override
  String get startupRecoveryShareReport => 'Raporu dışa aktar';

  @override
  String startupRecoveryReportStored(String path) {
    return 'Bu raporun bir kopyası $path konumuna kaydedildi';
  }

  @override
  String startupRecoveryReportSaved(String path) {
    return 'Rapor $path konumuna kaydedildi';
  }

  @override
  String get startupRecoveryReportShared => 'Rapor dışa aktarıldı.';

  @override
  String get startupRecoveryReportSaveFailed => 'Rapor dışa aktarılamadı.';

  @override
  String get startupRecoverySectionDataTitle => 'Verileriniz';

  @override
  String get startupRecoverySectionDataBody =>
      'Devam etmeden önce kalan verileri dışa aktarıp güvenli bir yerde saklayabilirsiniz.';

  @override
  String startupRecoveryExportSavedTo(String path) {
    return 'Verilerinizin bir kopyası $path konumuna kaydedildi';
  }

  @override
  String get startupRecoverySectionRepairTitle => 'Tanıla ve onar';

  @override
  String get startupRecoverySectionRepairBody =>
      'Bütünlük denetimi veritabanını yalnızca okur. Onarım, kesintiye uğramış bir güncellemeden kalan meta verileri temizler ve başlatmayı yeniden dener; sohbetleri asla silmez.';

  @override
  String get startupRecoveryIntegrityButton => 'Veritabanı bütünlüğünü denetle';

  @override
  String get startupRecoveryIntegrityHealthy =>
      'SQLite veritabanı dosyasında herhangi bir hasar bulmadı.';

  @override
  String startupRecoveryIntegrityDamaged(String detail) {
    return 'SQLite sorunlar bildirdi — $detail';
  }

  @override
  String get startupRecoveryIntegrityMissing =>
      'Veri klasöründe veritabanı dosyası bulunamadı.';

  @override
  String get startupRecoveryIntegrityFailed =>
      'Bütünlük denetimi çalıştırılamadı.';

  @override
  String get startupRecoveryDangerZone => 'Diğer seçenekler';

  @override
  String get startupRecoveryDangerBody =>
      'Yeni bir başlangıç, mevcut verileri görünümden kaldırır. Kelivo, kurtarma için eski veritabanını ve mevcut kopyaları korur. Mümkünse önce bir veri kopyası dışa aktarın.';

  @override
  String get startupRecoveryResetAcknowledge =>
      'Sohbetlerimi şimdi kurtarmadan boş sohbet listesiyle devam etmeyi seçiyorum.';

  @override
  String get startupDatabaseUpdateRequiredTitle =>
      'Devam etmek için Kelivo\'yu güncelleyin';

  @override
  String get startupDatabaseUpdateRequiredContent =>
      'Bu cihazdaki sohbet veritabanı Kelivo\'nun daha yeni bir sürümü tarafından oluşturulmuş ve bu sürüm tarafından açılamıyor. Verileriniz değiştirilmedi. Kelivo\'nun en son sürümünü yükleyip tekrar açın.';

  @override
  String get startupDatabaseUpdateRequiredDowngradeTitle =>
      'Daha eski bir sürüme ihtiyacınız varsa';

  @override
  String get startupDatabaseUpdateRequiredDowngradeIntro =>
      'Bu sürüm, bu cihazdaki veritabanını açamıyor. Daha eski bir sürümü kullanmaya devam etmeniz gerekiyorsa aşağıdaki adımları izleyin. Yedek alana kadar buradaki verileri silmeyin veya üzerine yazmayın.';

  @override
  String get startupDatabaseUpdateRequiredDowngradeStep1 =>
      'Kelivo\'nun en son sürümünü yükleyip açın, ardından Ayarlar → Yedek bölümünden bir yedek dışa aktarın.';

  @override
  String startupDatabaseUpdateRequiredDowngradeStep2(String url) {
    return '$url adresini açın ve bu yedeği kullanmak istediğiniz eski sürüme dönüştürün.';
  }

  @override
  String get startupDatabaseUpdateRequiredDowngradeStep3 =>
      'Bu cihazdaki verilerin yedeklendiğini doğruladıktan sonra eski sürümü yükleyin ve dönüştürülmüş yedeği içe aktarın.';

  @override
  String get startupDatabaseUpdateRequiredOpenTool => 'Dönüştürme aracını aç';

  @override
  String backupPageRestoreFailedMessage(String error) {
    return 'Geri yükleme başarısız: $error';
  }

  @override
  String backupPageExportFailedMessage(String error) {
    return 'Dışa aktarma başarısız: $error';
  }

  @override
  String get backupPageOK => 'Tamam';

  @override
  String get backupPageCancel => 'İptal';

  @override
  String get backupPageSelectImportMode => 'İçe Aktarma Modunu Seçin';

  @override
  String get backupPageSelectImportModeDescription =>
      'Bir geri yükleme modu seçin. Yedek Yönetimi\'ndeki anahtarlar bu içe aktarma için geçerlidir.';

  @override
  String get backupPageOverwriteMode => 'Tamamen Üzerine Yaz';

  @override
  String get backupPageOverwriteModeDescription =>
      'Seçilen bileşenleri değiştirir; seçilmeyen bileşenleri ve ilgisiz yerel ayarları korur. Sohbetlerin değiştirilmesi, yerel gönderilmemiş taslakları da temizler.';

  @override
  String get backupPageMergeMode => 'Birleştir';

  @override
  String get backupPageMergeModeDescription =>
      'Yerel verileri korur ve yedek verilerini ekler. Aynı sohbetler atlanır ve çakışan sohbetlere yeni kimlikler atanır.';

  @override
  String get backupPageRestore => 'Geri Yükle';

  @override
  String get backupPageForwardCompatTitle => 'Yedek daha yeni bir sürümden';

  @override
  String backupPageForwardCompatBody(int backupVersion, int currentVersion) {
    return 'Bu yedek, Kelivo\'nun daha yeni bir sürümü tarafından oluşturulmuş (veri biçimi $backupVersion; bu sürüm $currentVersion destekliyor) ve eski sürümlerin okuyup okuyamayacağı belirtilmemiş.\n\nDevam edebilirsiniz: bu sürümün tanımadığı her şey atlanır ve yedek dosyasının kendisi değiştirilmez. Ancak yeni sürüm mevcut verilerin saklanma biçimini değiştirdiyse bazı içerikler yanlış içe aktarılabilir.\n\nÖnce Kelivo\'yu güncellemek daha güvenli bir seçimdir.';
  }

  @override
  String get backupPageForwardCompatContinue => 'Yine de içe aktar';

  @override
  String get backupPageForwardCompatCancel => 'İptal';

  @override
  String get backupPageSchemaTooNewMessage =>
      'Bu yedek, Kelivo\'nun daha yeni bir sürümü tarafından oluşturulmuş ve bu sürüm tarafından okunamıyor. Lütfen Kelivo\'yu güncelleyip tekrar deneyin.';

  @override
  String get backupPageBackupUploaded => 'Yedek yüklendi';

  @override
  String get backupPageBackup => 'Yedekle';

  @override
  String get backupPageExporting => 'Dışa aktarılıyor...';

  @override
  String get backupProgressCancel => 'İptal';

  @override
  String get backupProgressCancelled => 'İptal edildi';

  @override
  String get backupProgressFailed => 'İşlem başarısız';

  @override
  String backupProgressFailedAt(String phase) {
    return 'Başarısız olduğu aşama: $phase';
  }

  @override
  String get backupProgressCopyError => 'Hatayı kopyala';

  @override
  String get backupProgressErrorCopied => 'Hata kopyalandı';

  @override
  String get backupProgressPreparing => 'Hazırlanıyor';

  @override
  String get backupProgressSnapshotting =>
      'Veritabanı anlık görüntüsü oluşturuluyor';

  @override
  String get backupProgressPacking => 'Paketleniyor';

  @override
  String get backupProgressVerifying => 'Doğrulanıyor';

  @override
  String get backupProgressUploading => 'Yükleniyor';

  @override
  String get backupProgressDownloading => 'İndiriliyor';

  @override
  String get backupProgressExtracting => 'Çıkarılıyor';

  @override
  String get backupProgressValidating => 'Geçerliliği kontrol ediliyor';

  @override
  String get backupProgressReadingSettings => 'Ayarlar okunuyor';

  @override
  String get backupProgressStaging => 'Hazırlanıyor';

  @override
  String get backupProgressCommitting => 'Kaydediliyor';

  @override
  String get backupProgressImportingSessions => 'Oturumlar içe aktarılıyor';

  @override
  String get backupProgressImportingMessages => 'Mesajlar içe aktarılıyor';

  @override
  String get backupProgressMaterializingFiles => 'Dosyalar yazılıyor';

  @override
  String get backupProgressListingRemote => 'Uzak yedekler listeleniyor';

  @override
  String get backupProgressFinalizing => 'Tamamlanıyor';

  @override
  String backupProgressBytes(String done, String total) {
    return '$done / $total';
  }

  @override
  String backupProgressItems(String done, String total) {
    return '$done / $total';
  }

  @override
  String get backupPageExportToFile => 'Şimdi Yedekle';

  @override
  String get backupPageExportToFileSubtitle =>
      'Seçilen içeriği yedek dosyası olarak kaydet';

  @override
  String get backupPageImportBackupFile => 'Yedek Dosyasını İçe Aktar';

  @override
  String get backupPageImportBackupFileSubtitle =>
      'Yerel bir yedek dosyasını içe aktar';

  @override
  String get backupPageImportFromOtherApps => 'Diğer Uygulamalardan İçe Aktar';

  @override
  String get backupPageNotSupportedYet => 'Henüz desteklenmiyor';

  @override
  String get backupPageRemoteBackups => 'Uzak Yedekler';

  @override
  String get backupPageNoBackups => 'Yedek yok';

  @override
  String get backupPageRestoreTooltip => 'Geri yükle';

  @override
  String get backupPageDeleteTooltip => 'Sil';

  @override
  String get backupPageDeleteConfirmTitle => 'Silmeyi Onayla';

  @override
  String backupPageDeleteConfirmContent(Object name) {
    return '\"$name\" uzak yedeğini silmek istediğinizden emin misiniz? Bu işlem geri alınamaz.';
  }

  @override
  String get backupPageBackupManagement => 'Yedek Yönetimi';

  @override
  String get backupPageWebDavBackup => 'WebDAV Yedeği';

  @override
  String get backupPageWebDavServerSettings => 'WebDAV Sunucu Ayarları';

  @override
  String get backupPageS3Backup => 'S3 Yedeği';

  @override
  String get backupPageS3ServerSettings => 'S3 Ayarları';

  @override
  String get backupPageS3Endpoint => 'Uç Nokta';

  @override
  String get backupPageS3Region => 'Bölge';

  @override
  String get backupPageS3Bucket => 'Bucket';

  @override
  String get backupPageS3AccessKeyId => 'Erişim Anahtarı Kimliği';

  @override
  String get backupPageS3SecretAccessKey => 'Gizli Erişim Anahtarı';

  @override
  String get backupPageS3SessionToken => 'Oturum Token\'ı (İsteğe Bağlı)';

  @override
  String get backupPageS3Prefix => 'Önek';

  @override
  String get backupPageS3PathStyle => 'Yol tarzı adresleme';

  @override
  String get backupPageUserAgent => 'User-Agent';

  @override
  String get backupPageUserAgentHint => 'İsteğe bağlı';

  @override
  String get backupPageSave => 'Kaydet';

  @override
  String get backupPageBackupNow => 'Şimdi Yedekle';

  @override
  String get backupPageLocalBackup => 'Yerel Yedek';

  @override
  String get backupPageIosSystemBackupNote =>
      'Kelivo\'nun yerel verileri iCloud cihaz yedeklemelerine dahil edilmez. Cihaz değiştirmeden veya uygulamayı silmeden önce iCloud Drive\'a ya da Kelivo dışında bir klasöre yedekleyin. \"iPhone\'um > Kelivo\" içindeki dosyalar uygulamayla birlikte silinir.';

  @override
  String get backupPageImportFromCherryStudio => 'Cherry Studio\'dan İçe Aktar';

  @override
  String backupPageCherryStudioUnsupportedBackupVersion(String version) {
    return 'Bu yedek, Kelivo\'nun henüz içe aktaramadığı Cherry Studio biçim sürümü $version kullanıyor. Bunun yerine Cherry Studio v1\'den dışa aktarın veya Cherry Studio v2 yedeklerini destekleyen bir Kelivo güncellemesini bekleyin.';
  }

  @override
  String get backupPageImportFromChatbox => 'Chatbox\'tan İçe Aktar';

  @override
  String get webDavScheduleTitle => 'Zamanlanmış WebDAV Yedekleme';

  @override
  String get webDavScheduleEnabled => 'Otomatik yedekleme';

  @override
  String get webDavScheduleInterval => 'Tekrarlama aralığı';

  @override
  String get webDavScheduleWifiOnly => 'Yalnızca Wi-Fi / Ethernet';

  @override
  String get webDavScheduleWifiOnlyHint =>
      'Yükleme için Wi-Fi veya Ethernet kullanılır. Android arka plan yedekleri ayrıca tarifesiz bir bağlantı bekler.';

  @override
  String get webDavScheduleAndroidHint =>
      'Android, yedeklemeleri arka planda çalıştırır. Pil ve ağ kısıtlamaları gecikmeye neden olabilir. Uygulamayı zorla durdurmak, yeniden açılana kadar yedeklemeleri duraklatır.';

  @override
  String get webDavScheduleForegroundHint =>
      'Yedeklemeler uygulama açıkken çalışır. Kaçırılan yedeklemeler uygulamaya döndüğünüzde çalışır.';

  @override
  String get webDavScheduleConfigureFirst =>
      'Otomatik yedeklemeyi açmadan önce WebDAV sunucunuzu yapılandırıp kaydedin.';

  @override
  String get webDavScheduleLastSuccess => 'Son başarılı yedekleme';

  @override
  String get webDavScheduleNextRun => 'Sonraki yedekleme (yaklaşık)';

  @override
  String get webDavScheduleStatus => 'Durum';

  @override
  String get webDavScheduleRunNow => 'Şimdi yedekle';

  @override
  String get webDavScheduleRunning => 'Yedekleniyor…';

  @override
  String get webDavScheduleFinishingBackgroundBackup =>
      'Arka plan yedeklemesi tamamlanıyor…';

  @override
  String get webDavScheduleReady => 'Sonraki yedekleme bekleniyor';

  @override
  String get webDavScheduleFailed => 'Son yedekleme başarısız oldu';

  @override
  String get webDavScheduleDisabled => 'Kapalı';

  @override
  String get webDavScheduleNotConfigured => 'WebDAV sunucusu yapılandırılmadı';

  @override
  String webDavScheduleEveryHours(int hours) {
    String _temp0 = intl.Intl.pluralLogic(
      hours,
      locale: localeName,
      other: 'Her $hours saatte',
      one: 'Her saat',
    );
    return '$_temp0';
  }

  @override
  String get webDavScheduleEveryDay => 'Her gün';

  @override
  String get webDavScheduleNever => 'Hiçbir zaman';

  @override
  String get webDavScheduleDue => 'Koşullar uygun olduğunda';

  @override
  String get webDavScheduleSaved => 'Yedekleme zamanlaması kaydedildi';

  @override
  String get webDavScheduleSaveFailed => 'Yedekleme zamanlaması kaydedilemedi';

  @override
  String get webDavScheduleSucceeded => 'Yedek yüklendi';

  @override
  String get webDavScheduleUnavailable =>
      'Arka plan zamanlaması kullanılamıyor';

  @override
  String get webDavScheduleWifiRequired => 'Wi-Fi veya Ethernet bekleniyor';

  @override
  String get webDavScheduleNetworkUnavailable => 'Ağ bağlantısı bekleniyor';

  @override
  String get webDavScheduleBackupBusy =>
      'Başka bir yedekleme veya geri yükleme sürüyor';

  @override
  String get webDavScheduleRetry => 'Yeniden deneme bekleniyor';

  @override
  String get webDavScheduleTimedOut => 'Yedekleme zaman aşımına uğradı';

  @override
  String get webDavSchedulePasswordRequired =>
      'Şifreli yedekler parola onayı gerektirir. WebDAV yedeğini elle alın veya zamanlanmış yedekleme için yedek şifrelemesini kapatın.';

  @override
  String get webDavScheduleCancelled => 'Yedekleme iptal edildi';

  @override
  String get backupReminderSectionTitle => 'Yedek Hatırlatıcısı';

  @override
  String get backupReminderEnableTitle => 'Yedeklemeyi hatırlat';

  @override
  String get backupReminderFrequencyTitle => 'Sıklık';

  @override
  String get backupReminderTimeTitle => 'Hatırlatma Saati';

  @override
  String get backupReminderTimeInputHint => 'HH:mm';

  @override
  String get backupReminderTimeInvalid =>
      '00:00 ile 23:59 arasında bir saat girin.';

  @override
  String get backupReminderLastBackupTitle => 'Son Yedek';

  @override
  String get backupReminderNextReminderTitle => 'Sonraki Hatırlatma';

  @override
  String get backupReminderNever => 'Hiç';

  @override
  String get backupReminderDisabled => 'Kapalı';

  @override
  String get backupReminderDueNow => 'Şimdi zamanı geldi';

  @override
  String get backupReminderEveryDay => 'Her gün';

  @override
  String get backupReminderEveryThreeDays => 'Her 3 günde bir';

  @override
  String get backupReminderEveryWeek => 'Her hafta';

  @override
  String get backupReminderEveryFourteenDays => 'Her 14 günde bir';

  @override
  String get backupReminderEveryMonth => 'Her ay';

  @override
  String backupReminderCustomDays(int days) {
    return 'Her $days günde bir';
  }

  @override
  String get backupReminderCustomOption => 'Özel...';

  @override
  String get backupReminderCustomDialogTitle => 'Özel Sıklık';

  @override
  String get backupReminderCustomDialogDescription =>
      'Yedek hatırlatmaları arasında kaç gün bekleneceğini girin.';

  @override
  String get backupReminderCustomDaysLabel => 'Gün';

  @override
  String get backupReminderCustomDaysInvalid =>
      '1 ile 365 arasında bir sayı girin.';

  @override
  String get backupReminderSidebarTitle => 'Yedek hatırlatması';

  @override
  String get backupReminderSidebarSubtitle => 'Yedekleme aralığınız geldi.';

  @override
  String get backupReminderSidebarAction => 'Yedeğe git';

  @override
  String get backupReminderSnoozeTooltip => 'Daha sonra hatırlat';

  @override
  String get chatHistoryPageTitle => 'Sohbet Geçmişi';

  @override
  String get chatHistoryPageSearchTooltip => 'Ara';

  @override
  String get chatHistoryPageDeleteAllTooltip => 'Sabitlenmemişleri Sil';

  @override
  String get chatHistoryPageDeleteAllDialogTitle =>
      'Sabitlenmemiş Sohbetleri Sil';

  @override
  String get chatHistoryPageDeleteAllDialogContent =>
      'Bu asistan için sabitlenmemiş tüm sohbetler silinsin mi? Sabitlenmiş sohbetler korunur.';

  @override
  String get chatHistoryPageCancel => 'İptal';

  @override
  String get chatHistoryPageDelete => 'Sil';

  @override
  String get chatHistoryPageDeletedAllSnackbar =>
      'Sabitlenmemiş sohbetler silindi';

  @override
  String get chatHistoryPageSearchHint => 'Sohbetlerde ara';

  @override
  String get chatHistoryPageNoConversations => 'Sohbet yok';

  @override
  String get chatHistoryPagePinnedSection => 'Sabitlenmiş';

  @override
  String get chatHistoryPagePin => 'Sabitle';

  @override
  String get chatHistoryPagePinned => 'Sabitlendi';

  @override
  String get messageEditPageTitle => 'Mesajı Düzenle';

  @override
  String get messageEditPageSave => 'Kaydet';

  @override
  String get messageEditPageSaveAndSend => 'Kaydet ve Gönder';

  @override
  String get messageEditPageHint => 'Mesaj girin…';

  @override
  String get userMessageEditSaveOnly => 'Yalnızca Kaydet';

  @override
  String get userMessageEditUnsupportedSnackbar =>
      'Bu içerik düzenlemeyi desteklemiyor';

  @override
  String get userMessageEditOverwriteTitle => 'Uyarı';

  @override
  String get userMessageEditOverwriteContent =>
      'Düzenleme mevcut girişi geçersiz kılacak. Üzerine yazılsın mı?';

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
  String get bottomToolsSheetUpload => 'Yükle';

  @override
  String get bottomToolsSheetClearContext => 'Bağlamı Temizle';

  @override
  String get compressContext => 'Bağlamı Sıkıştır';

  @override
  String get compressContextDesc =>
      'Daha önceki sohbeti bir özete dönüştürün. Orijinaller sohbette kalır ve istediğiniz zaman geri alabilirsiniz.';

  @override
  String get clearContextDesc =>
      'Buradan yeni bir başlangıç yapın: önceki mesajlar sohbette kalır ancak modele gönderilmez.';

  @override
  String get contextManagement => 'Bağlam Yönetimi';

  @override
  String get compressContextFailed => 'Sıkıştırma tamamlanmadı';

  @override
  String get compressContextNoMessages =>
      'Bu sohbette sıkıştırılacak bir şey yok.';

  @override
  String get compressContextNoConversation => 'Sıkıştırılacak bir sohbet yok.';

  @override
  String get compressContextNoModel =>
      'Sıkıştırma için model ayarlanmamış. Ayarlar\'dan hızlı bir model seçin.';

  @override
  String get compressContextEmptySummary =>
      'Model bir özet oluşturmadı. Farklı bir model deneyin veya seçenekleri değiştirip tekrar deneyin.';

  @override
  String get compressContextOptionsTitle => 'Bağlamı Sıkıştır';

  @override
  String get compressContextOptionsDesc =>
      'Daha önceki mesajları bir özete dönüştürün; model bir sonraki sefer bu özeti görecek. Orijinal sohbet korunur; özeti düzenleyebilir veya geri alabilirsiniz.';

  @override
  String get compressContextKeepStart => 'Daha eski geçmiş';

  @override
  String get compressContextKeepRecent => 'Daha yeni geçmiş';

  @override
  String get compressContextUnlimited => 'Tüm etkin geçmiş';

  @override
  String get compressContextMaxCharsLabel => 'Karakter';

  @override
  String get compressContextInvalidLimit => 'Pozitif bir karakter sayısı girin';

  @override
  String get compressContextStartButton => 'Sıkıştır';

  @override
  String get compressContextModelLabel => 'Model';

  @override
  String get compressContextModelUnset => 'Bir model seçin';

  @override
  String get compressContextKeepRecentMessages => 'Son turları koru';

  @override
  String get compressContextKeepCountLabel =>
      'Korunacak son kullanıcı mesajı sayısı';

  @override
  String get compressContextKeepAllMessages =>
      'Korunacak bu sayı zaten tüm sohbeti kapsıyor, sıkıştırılacak bir şey kalmadı.';

  @override
  String compressContextEstimatePreview(
    int summarized,
    int kept,
    int minTokens,
    int maxTokens,
    int totalTokens,
  ) {
    return '$summarized karakter özetlenecek, $kept karakter olduğu gibi korunacak. Sıkıştırma sonrası yaklaşık $minTokens–$maxTokens token (orijinal yaklaşık $totalTokens).';
  }

  @override
  String get bottomToolsSheetLearningMode => 'Öğrenme Modu';

  @override
  String get bottomToolsSheetLearningModeDescription =>
      'Adım adım öğrenmenize yardımcı olur';

  @override
  String get bottomToolsSheetConfigurePrompt => 'İstemi yapılandır';

  @override
  String get bottomToolsSheetPrompt => 'İstem';

  @override
  String get bottomToolsSheetPromptHint =>
      'Eklemek istediğiniz istem metnini girin';

  @override
  String get bottomToolsSheetResetDefault => 'Varsayılana sıfırla';

  @override
  String get bottomToolsSheetSave => 'Kaydet';

  @override
  String get bottomToolsSheetOcr => 'Görsel OCR';

  @override
  String get messageMoreSheetTitle => 'Daha Fazla İşlem';

  @override
  String get messageMoreSheetSelectCopy => 'Seç ve Kopyala';

  @override
  String get messageMoreSheetRenderWebView => 'Web Görünümünde İşle';

  @override
  String get messageMoreSheetNotImplemented => 'Henüz uygulanmadı';

  @override
  String get messageMoreSheetEdit => 'Düzenle';

  @override
  String get messageMoreSheetShare => 'Paylaş';

  @override
  String get messageMoreSheetSelectMessages => 'Mesajları Seç';

  @override
  String get messageMoreSheetCreateBranch => 'Dal Oluştur';

  @override
  String get messageMoreSheetDelete => 'Bu Sürümü Sil';

  @override
  String get messageMoreSheetDeleteAllVersions => 'Tüm Sürümleri Sil';

  @override
  String get reasoningBudgetSheetTitle => 'Akıl Yürütme Zinciri Gücü';

  @override
  String get reasoningLevelSheetTitle => 'Akıl Yürütme';

  @override
  String get reasoningLevelAuto => 'Otomatik';

  @override
  String get reasoningLevelAutoSubtitle =>
      'Modelin veya sağlayıcının varsayılanını kullanır';

  @override
  String get reasoningLevelOff => 'Kapalı';

  @override
  String get reasoningLevelOn => 'Açık';

  @override
  String get reasoningLevelOnSubtitle => 'Akıl yürütmeyi etkinleştir';

  @override
  String get reasoningLevelOffSubtitle =>
      'Akıl yürütmeyi kapat ve doğrudan yanıtla';

  @override
  String get reasoningLevelMinimal => 'En Az';

  @override
  String get reasoningLevelMinimalSubtitle =>
      'Soruları yanıtlamak için en hafif akıl yürütmeyi kullan';

  @override
  String get reasoningLevelLow => 'Düşük';

  @override
  String get reasoningLevelLowSubtitle =>
      'Soruları yanıtlamak için hafif akıl yürütme kullan';

  @override
  String get reasoningLevelMedium => 'Orta';

  @override
  String get reasoningLevelMediumSubtitle =>
      'Soruları yanıtlamak için orta düzeyde akıl yürütme kullan';

  @override
  String get reasoningLevelHigh => 'Yüksek';

  @override
  String get reasoningLevelHighSubtitle =>
      'Karmaşık sorular için yoğun akıl yürütme kullan';

  @override
  String get reasoningLevelXhigh => 'Çok Yüksek';

  @override
  String get reasoningLevelXhighSubtitle =>
      'Daha zor problemler için çok yüksek akıl yürütme derinliği kullan';

  @override
  String get reasoningLevelMax => 'Maks';

  @override
  String get reasoningLevelMaxSubtitle =>
      'En zor problemler için maksimum akıl yürütme derinliği kullan';

  @override
  String get reasoningLevelFollowModelDefaultSubtitle =>
      'Asistan bir seviye belirlemediğinde modelin varsayılanını kullan';

  @override
  String get reasoningLevelNoReasoning =>
      'Bu model akıl yürütmeyi desteklemiyor';

  @override
  String get reasoningLevelCustomBudget => 'Özel Akıl Yürütme Bütçesi';

  @override
  String get reasoningLevelCustomBudgetHint => 'Token bütçesi, ör. 2048';

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
    return '$budget token';
  }

  @override
  String chatMessageWidgetFileNotFound(String fileName) {
    return 'Dosya bulunamadı: $fileName';
  }

  @override
  String chatMessageWidgetCannotOpenFile(String message) {
    return 'Dosya açılamıyor: $message';
  }

  @override
  String chatMessageWidgetOpenFileError(String error) {
    return 'Dosya açılamadı: $error';
  }

  @override
  String get chatMessageWidgetCopiedToClipboard => 'Panoya kopyalandı';

  @override
  String get chatMessageWidgetResendTooltip => 'Yeniden gönder';

  @override
  String get chatMessageWidgetMoreTooltip => 'Daha fazla';

  @override
  String get chatMessageWidgetThinking => 'Düşünüyor...';

  @override
  String get chatMessageWidgetTranslation => 'Çeviri';

  @override
  String get chatMessageWidgetTranslating => 'Çevriliyor...';

  @override
  String get chatMessageWidgetCitationNotFound => 'Alıntı kaynağı bulunamadı';

  @override
  String chatMessageWidgetCannotOpenUrl(String url) {
    return 'Bağlantı açılamıyor: $url';
  }

  @override
  String get chatMessageWidgetOpenLinkError => 'Bağlantı açılamadı';

  @override
  String get chatMessageWidgetAttachmentUnavailable => 'Ek kullanılamıyor';

  @override
  String chatMessageWidgetCitationsTitle(int count) {
    return 'Alıntılar ($count)';
  }

  @override
  String get chatMessageWidgetSearchResultsTitle => 'Arama sonuçları';

  @override
  String get chatMessageWidgetCitationSourcesTitle => 'Alıntı kaynakları';

  @override
  String get chatMessageWidgetRegenerateTooltip => 'Yeniden oluştur';

  @override
  String get chatMessageWidgetRegenerateConfirmTitle =>
      'Yeniden Oluşturmayı Onayla';

  @override
  String get chatMessageWidgetRegenerateConfirmContent =>
      'Yeniden oluşturma yalnızca bu mesajı günceller ve altındaki mesajları korur. Devam edilsin mi?';

  @override
  String get chatMessageWidgetRegenerateConfirmDeleteTrailingContent =>
      'Yeniden oluşturma bu mesajın altındaki tüm mesajları siler ve geri alınamaz. Devam edilsin mi?';

  @override
  String get chatMessageWidgetRegenerateConfirmCancel => 'İptal';

  @override
  String get chatMessageWidgetRegenerateConfirmOk => 'Yeniden oluştur';

  @override
  String get chatMessageWidgetStopTooltip => 'Durdur';

  @override
  String get chatMessageWidgetSpeakTooltip => 'Seslendir';

  @override
  String get chatMessageWidgetTranslateTooltip => 'Çevir';

  @override
  String get chatMessageWidgetBuiltinSearchHideNote =>
      'Yerleşik arama aracı kartlarını gizle';

  @override
  String get chatMessageWidgetDeepThinking => 'Derin Düşünme';

  @override
  String chatMessageWidgetWebSearch(String query) {
    return 'Web Araması: $query';
  }

  @override
  String chatMessageWidgetWebFetch(String target) {
    return 'Sayfayı oku: $target';
  }

  @override
  String get chatMessageWidgetBuiltinSearch => 'Yerleşik Arama';

  @override
  String get chatMessageWidgetReadClipboard => 'Panoyu Oku';

  @override
  String get chatMessageWidgetWriteClipboard => 'Panoya Yaz';

  @override
  String get chatMessageWidgetSpeakingTitle => 'Seslendiriliyor:';

  @override
  String chatMessageWidgetSpeakText(String text) {
    return 'Seslendiriliyor: $text';
  }

  @override
  String get chatMessageWidgetMemoryRead => 'Belleği Oku';

  @override
  String get chatMessageWidgetMemoryUpdate => 'Belleği Güncelle';

  @override
  String get chatMessageWidgetMemorySearchProfile => 'Hafızada Ara';

  @override
  String get chatMessageWidgetMemoryEdit => 'Hafızayı Düzenle';

  @override
  String get chatMessageWidgetMemoryDelete => 'Hafızayı Sil';

  @override
  String get chatMessageWidgetUpdateUserProfile =>
      'Kullanıcı Profilini Güncelle';

  @override
  String get chatMessageWidgetChatSearch => 'Geçmiş Sohbetlerde Ara';

  @override
  String get chatMessageWidgetCreateMemory => 'Hafıza Oluştur';

  @override
  String chatMessageWidgetToolCall(String name) {
    return 'Araç Çağrısı: $name';
  }

  @override
  String chatMessageWidgetToolResult(String name) {
    return 'Araç Sonucu: $name';
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
    return '$count alıntı';
  }

  @override
  String chatSelectionSelectedCountTitle(int count) {
    return '$count mesaj seçildi';
  }

  @override
  String get chatSelectionExportTxt => 'TXT';

  @override
  String get chatSelectionExportMd => 'MD';

  @override
  String get chatSelectionExportImage => 'Görsel';

  @override
  String get chatSelectionThinkingTools => 'Düşünme araçları';

  @override
  String get chatSelectionThinkingContent => 'Düşünme içeriği';

  @override
  String get chatSelectionDeleteSelected => 'Seçilenleri Sil';

  @override
  String get chatSelectionSelectMessagesToDelete =>
      'Lütfen silinecek mesajları seçin';

  @override
  String chatSelectionDeleteSelectedConfirm(int count) {
    return 'Seçilen $count sürüm silinsin mi? Bu işlem geri alınamaz.';
  }

  @override
  String chatSelectionDeleteSelectedAllVersionsConfirm(int count) {
    return 'Seçilen $count mesajın tüm sürümleri silinsin mi? Bu işlem geri alınamaz.';
  }

  @override
  String get messageExportSheetAssistant => 'Asistan';

  @override
  String get messageExportSheetDefaultTitle => 'Yeni Sohbet';

  @override
  String get messageExportSheetExporting => 'Dışa aktarılıyor…';

  @override
  String messageExportSheetExportFailed(String error) {
    return 'Dışa aktarma başarısız: $error';
  }

  @override
  String messageExportSheetExportedAs(String filename) {
    return '$filename olarak dışa aktarıldı';
  }

  @override
  String get displaySettingsPageEnableDollarLatexTitle =>
      'Satır İçi \$...\$ Oluşturma';

  @override
  String get displaySettingsPageEnableDollarLatexSubtitle =>
      '\$...\$ içindeki satır içi matematiği oluştur';

  @override
  String get displaySettingsPageEnableMathTitle =>
      'Matematik Formülü Oluşturma';

  @override
  String get displaySettingsPageEnableMathSubtitle =>
      'LaTeX matematiğini oluştur (satır içi ve blok)';

  @override
  String get displaySettingsPageUseLegacyInlineCodeStyleTitle =>
      'Eski satır içi kod stili';

  @override
  String get displaySettingsPageUseLegacyInlineCodeStyleSubtitle =>
      'Satır içi kod için daha açık bir arka plan, ince bir kenarlık ve daha fazla satır aralığı kullan.';

  @override
  String get displaySettingsPageUseLegacyCodeBlockStyleTitle =>
      'Eski kod bloğu stili';

  @override
  String get displaySettingsPageUseLegacyCodeBlockStyleSubtitle =>
      'Kod blokları için önceki renkleri, yuvarlatılmış köşeleri ve aralıkları geri yükle.';

  @override
  String get displaySettingsPageEnableUserMarkdownTitle =>
      'Kullanıcı mesajlarını Markdown ile oluştur';

  @override
  String get displaySettingsPageEnableReasoningMarkdownTitle =>
      'Akıl yürütmeyi (düşünme) Markdown ile oluştur';

  @override
  String get displaySettingsPageEnableAssistantMarkdownTitle =>
      'Asistan mesajlarını Markdown ile oluştur';

  @override
  String get displaySettingsPageMobileCodeBlockWrapTitle =>
      'Mobil Kod Bloğu Sözcük Kaydırma';

  @override
  String get displaySettingsPageAutoCollapseCodeBlockTitle =>
      'Kod Bloklarını Otomatik Daralt';

  @override
  String get displaySettingsPageAutoCollapseCodeBlockLinesTitle =>
      'Otomatik daraltma eşiği';

  @override
  String get displaySettingsPageAutoCollapseCodeBlockLinesUnit => 'satır';

  @override
  String get displaySettingsPageCollapseLongUserMessagesTitle =>
      'Uzun Mesajları Daralt';

  @override
  String get displaySettingsPageCollapseLongUserMessagesSubtitle =>
      'Eşiği aşan kullanıcı mesajlarını bir genişletme düğmesinin arkasına katla';

  @override
  String get displaySettingsPageCollapseLongUserMessagesCharsTitle =>
      'Daraltma eşiği';

  @override
  String get displaySettingsPageCollapseLongUserMessagesCharsUnit => 'karakter';

  @override
  String get chatMessageExpandLongText => 'Genişlet';

  @override
  String get chatMessageCollapseLongText => 'Daralt';

  @override
  String get messageExportSheetFormatTitle => 'Dışa Aktarma Formatı';

  @override
  String get messageExportSheetMarkdown => 'Markdown';

  @override
  String get messageExportSheetSingleMarkdownSubtitle =>
      'Bu mesajı Markdown dosyası olarak dışa aktar';

  @override
  String get messageExportSheetBatchMarkdownSubtitle =>
      'Seçili mesajları Markdown dosyası olarak dışa aktar';

  @override
  String get messageExportSheetPlainText => 'Düz Metin';

  @override
  String get messageExportSheetSingleTxtSubtitle =>
      'Bu mesajı TXT dosyası olarak dışa aktar';

  @override
  String get messageExportSheetBatchTxtSubtitle =>
      'Seçili mesajları TXT dosyası olarak dışa aktar';

  @override
  String get messageExportSheetExportImage => 'Görsel Olarak Dışa Aktar';

  @override
  String get messageExportSheetSingleExportImageSubtitle =>
      'Bu mesajı PNG görseli olarak oluştur';

  @override
  String get messageExportSheetBatchExportImageSubtitle =>
      'Seçili mesajları PNG görseli olarak oluştur';

  @override
  String get messageExportSheetShowThinkingAndToolCards =>
      'Derin Düşünme ve araç kartlarını göster';

  @override
  String get messageExportSheetShowThinkingContent =>
      'Düşünme içeriğini göster';

  @override
  String get messageExportThinkingContentLabel => 'Düşünme içeriği';

  @override
  String get messageExportSheetDateTimeWithSecondsPattern =>
      'dd.MM.yyyy HH:mm:ss';

  @override
  String get exportDisclaimerAiGenerated =>
      'İçerik AI tarafından oluşturulmuştur. Lütfen dikkatlice doğrulayın.';

  @override
  String get imagePreviewSheetSaveImage => 'Görseli Kaydet';

  @override
  String get imagePreviewSheetSaveSuccess => 'Galeriye kaydedildi';

  @override
  String imagePreviewSheetSaveFailed(String error) {
    return 'Kaydetme başarısız: $error';
  }

  @override
  String get sideDrawerMenuRename => 'Yeniden adlandır';

  @override
  String get sideDrawerMenuPin => 'Sabitle';

  @override
  String get sideDrawerMenuUnpin => 'Sabitlemeyi kaldır';

  @override
  String get sideDrawerMenuRegenerateTitle => 'Başlığı Yeniden Oluştur';

  @override
  String get sideDrawerMenuCopy => 'Kopyala';

  @override
  String get sideDrawerMenuMoveTo => 'Taşı';

  @override
  String get sideDrawerMenuDelete => 'Sil';

  @override
  String get sideDrawerMenuSelect => 'Seç';

  @override
  String sideDrawerSelectionTitle(int count) {
    return '$count öğe seçildi';
  }

  @override
  String get sideDrawerSelectionSelectAll => 'Tümünü seç';

  @override
  String get sideDrawerSelectionDeselectAll => 'Seçimi kaldır';

  @override
  String get sideDrawerSelectionPin => 'Sabitle';

  @override
  String get sideDrawerSelectionUnpin => 'Sabitlemeyi kaldır';

  @override
  String get sideDrawerSelectionMove => 'Taşı';

  @override
  String get sideDrawerSelectionDelete => 'Sil';

  @override
  String get sideDrawerSelectionDeleteConfirmTitle => 'Sohbetleri sil';

  @override
  String sideDrawerSelectionDeleteConfirmContent(int count) {
    return '$count sohbet silinsin mi?';
  }

  @override
  String sideDrawerDeleteSelectedSnackbar(int count) {
    return '$count sohbet silindi';
  }

  @override
  String sideDrawerMoveSelectedSnackbar(int count) {
    return '$count sohbet taşındı';
  }

  @override
  String sideDrawerDeleteSnackbar(String title) {
    return '\"$title\" silindi';
  }

  @override
  String get sideDrawerRenameHint => 'Yeni ad girin';

  @override
  String get sideDrawerCancel => 'İptal';

  @override
  String get sideDrawerOK => 'Tamam';

  @override
  String get sideDrawerSave => 'Kaydet';

  @override
  String get sideDrawerGreetingMorning => 'Günaydın 👋';

  @override
  String get sideDrawerGreetingNoon => 'İyi günler 👋';

  @override
  String get sideDrawerGreetingAfternoon => 'İyi öğleden sonralar 👋';

  @override
  String get sideDrawerGreetingEvening => 'İyi akşamlar 👋';

  @override
  String get sideDrawerDateToday => 'Bugün';

  @override
  String get sideDrawerDateYesterday => 'Dün';

  @override
  String get sideDrawerDateShortPattern => 'd MMM';

  @override
  String get sideDrawerDateFullPattern => 'd MMM yyyy';

  @override
  String get sideDrawerSearchHint => 'Mevcut asistanda ara';

  @override
  String get sideDrawerSearchAssistantsHint => 'Asistan ara';

  @override
  String get sideDrawerTopicSearchModeLabel => 'Konu modu';

  @override
  String get sideDrawerGlobalSearchModeLabel => 'Genel mod';

  @override
  String get sideDrawerSearchModeSwipeToTopicHint =>
      'Konu araması için arama çubuğunu kaydırın';

  @override
  String get sideDrawerSearchModeSwipeToGlobalHint =>
      'Genel arama için arama çubuğunu kaydırın';

  @override
  String get sideDrawerGlobalSearchHint => 'Tüm oturumlarda ara';

  @override
  String get sideDrawerGlobalSearchEmptyHint => 'Başlıklarda ve mesajlarda ara';

  @override
  String get sideDrawerGlobalSearchNoResults => 'Eşleşen oturum yok';

  @override
  String sideDrawerGlobalSearchResultCount(int count) {
    return '$count sonuç';
  }

  @override
  String sideDrawerUpdateTitle(String version) {
    return 'Yeni sürüm: $version';
  }

  @override
  String sideDrawerUpdateTitleWithBuild(String version, int build) {
    return 'Yeni sürüm: $version ($build)';
  }

  @override
  String get sideDrawerLinkCopied => 'Bağlantı kopyalandı';

  @override
  String get sideDrawerPinnedLabel => 'Sabitlenenler';

  @override
  String get sideDrawerHistory => 'Geçmiş';

  @override
  String get sideDrawerSettings => 'Ayarlar';

  @override
  String get sideDrawerChooseAssistantTitle => 'Asistan Seç';

  @override
  String get sideDrawerChooseImage => 'Görsel Seç';

  @override
  String get sideDrawerChooseEmoji => 'Emoji Seç';

  @override
  String get sideDrawerEnterLink => 'Bağlantı Gir';

  @override
  String get sideDrawerImportFromQQ => 'QQ\'den İçe Aktar';

  @override
  String get sideDrawerReset => 'Sıfırla';

  @override
  String get providerAvatarChooseBuiltInIcon => 'Yerleşik Simge Seç';

  @override
  String get providerAvatarIconDialogTitle => 'Yerleşik Simge Seç';

  @override
  String get providerAvatarIconSearchHint => 'Simge ara';

  @override
  String get providerAvatarIconNoResults => 'Simge bulunamadı';

  @override
  String get providerAvatarInputLobehubIcon => 'LobeHub Simgesi Gir';

  @override
  String get providerAvatarChooseLobehubIcon => 'LobeHub Simgesi Gir';

  @override
  String get providerAvatarLobehubDialogTitle => 'LobeHub Simgesi Gir';

  @override
  String get providerAvatarLobehubDialogHint =>
      'Bir LobeHub simge adı girin, ör. openai';

  @override
  String get sideDrawerEmojiDialogTitle => 'Emoji Seç';

  @override
  String get sideDrawerEmojiDialogHint =>
      'Herhangi bir emoji yazın veya yapıştırın';

  @override
  String get sideDrawerImageUrlDialogTitle => 'Görsel URL\'si Gir';

  @override
  String get sideDrawerImageUrlDialogHint =>
      'ör. https://example.com/avatar.png';

  @override
  String get sideDrawerQQAvatarDialogTitle => 'QQ\'den İçe Aktar';

  @override
  String get sideDrawerQQAvatarInputHint => 'QQ numarası girin (5-12 hane)';

  @override
  String get sideDrawerQQAvatarFetchFailed =>
      'Rastgele QQ avatarı alınamadı. Lütfen tekrar deneyin.';

  @override
  String get sideDrawerRandomQQ => 'Rastgele QQ';

  @override
  String get sideDrawerGalleryOpenError =>
      'Galeri açılamıyor. Bir görsel URL\'si girmeyi deneyin.';

  @override
  String get sideDrawerGeneralImageError =>
      'Bir şeyler ters gitti. Bir görsel URL\'si girmeyi deneyin.';

  @override
  String get sideDrawerSetNicknameTitle => 'Takma Ad Belirle';

  @override
  String get sideDrawerNicknameLabel => 'Takma Ad';

  @override
  String get sideDrawerNicknameHint => 'Yeni takma ad girin';

  @override
  String get sideDrawerRename => 'Yeniden Adlandır';

  @override
  String get chatInputBarHint => 'AI\'ya mesaj yazın';

  @override
  String get chatInputBarSelectModelTooltip => 'Model Seç';

  @override
  String get chatInputBarOnlineSearchTooltip => 'Çevrimiçi Arama';

  @override
  String get chatInputBarReasoningStrengthTooltip => 'Akıl Yürütme Gücü';

  @override
  String get chatInputBarMcpServersTooltip => 'MCP Sunucuları';

  @override
  String get chatInputBarToolsTooltip => 'Araçlar';

  @override
  String get chatInputBarMoreTooltip => 'Ekle';

  @override
  String get chatInputBarVoiceInputTooltip => 'Sesli giriş';

  @override
  String get chatInputBarVoiceCancelTooltip => 'Kaydı at';

  @override
  String get chatInputBarVoiceStopTooltip => 'Durdur ve girişe dönüştür';

  @override
  String get chatInputBarVoiceSendTooltip => 'Metne dönüştür ve gönder';

  @override
  String get chatInputBarVoiceTranscribing => 'Tanınıyor…';

  @override
  String get chatInputBarVoiceAttachAudioTooltip => 'Durdur ve ses olarak ekle';

  @override
  String get chatInputBarVoiceSendAudioTooltip => 'Kaydı gönder';

  @override
  String get chatInputBarVoiceSavingAudio => 'Ses kaydediliyor…';

  @override
  String get audioClipPlayTooltip => 'Sesi oynat';

  @override
  String get audioClipPauseTooltip => 'Duraklat';

  @override
  String get audioClipPlaybackFailed => 'Bu ses oynatılamadı';

  @override
  String get chatInputBarImageProcessing => 'Görsel işleniyor';

  @override
  String get chatInputBarImageMode => 'Görsel modu';

  @override
  String get chatInputBarDisableImageModeTooltip => 'Görsel modunu kapat';

  @override
  String get chatInputBarQueuedPending => 'Gönderilmek üzere sırada';

  @override
  String get chatInputBarQueuedCancel => 'Sırayı iptal et';

  @override
  String get chatInputBarInsertNewline => 'Yeni satır';

  @override
  String get chatInputBarExpand => 'Genişlet';

  @override
  String get chatInputBarCollapse => 'Daralt';

  @override
  String get contextUsageTitle => 'Bağlam penceresi';

  @override
  String get contextUsageStateExact => 'Kesin (son yanıttan)';

  @override
  String get contextUsageStateExactCalibrated =>
      'Toplam kesin; döküm orantılı olarak tahmin edildi';

  @override
  String get contextUsageStateEstimated => 'Tahmini';

  @override
  String get contextUsageStateStale => 'Güncel değil, güncelleniyor…';

  @override
  String get contextUsageStateComputing => 'Hesaplanıyor…';

  @override
  String get contextUsageStateFailed =>
      'Kullanım hesaplanamadı. Lütfen tekrar deneyin.';

  @override
  String get contextUsageStateFailedWithPrevious =>
      'Yenilenemedi. Önceki sonuç gösteriliyor; güncel olmayabilir.';

  @override
  String get contextUsageUnavailable => 'Kullanım şu anda görüntülenemiyor.';

  @override
  String contextUsagePartialSummary(String tokens) {
    return '$tokens tahmin edildi, ayrıca bilinmeyen sunucu tarafı kullanımı var';
  }

  @override
  String get contextUsageBucketNativeCompaction => 'Sunucu tarafı sıkıştırma';

  @override
  String get contextUsageUnknownTokens => 'Bilinmiyor';

  @override
  String contextUsageLastRequestInput(String tokens) {
    return 'Modele son gönderilen gerçek miktar: $tokens';
  }

  @override
  String get contextUsageStateNone => 'Henüz veri yok';

  @override
  String get contextUsageBucketSystem => 'Sistem istemi';

  @override
  String get contextUsageBucketInjections => 'Talimat enjeksiyonları';

  @override
  String get contextUsageBucketHistory => 'Mesajlar';

  @override
  String get contextUsageBucketTools => 'Yerleşik araçlar';

  @override
  String get contextUsageBucketMemory => 'Bellek';

  @override
  String get contextUsageBucketWorldBook => 'Dünya kitapları';

  @override
  String get contextUsageBucketSkills => 'Beceriler';

  @override
  String get contextUsageBucketWorkspace => 'Çalışma alanı';

  @override
  String get contextUsageBucketSearch => 'Arama istemi';

  @override
  String get contextUsageBucketMcpTools => 'MCP araçları';

  @override
  String get contextUsageBucketAttachments => 'Ekler';

  @override
  String get contextUsageBucketDraft => 'Taslak';

  @override
  String get contextUsageBucketUsed => 'Kullanılan';

  @override
  String get contextUsageFreeSpace => 'Boş alan';

  @override
  String contextUsageUsedWindow(String used, String window, int percent) {
    return '$used / $window (%$percent)';
  }

  @override
  String get contextUsageNoWindow => 'Henüz bağlam sınırı ayarlanmamış.';

  @override
  String get contextUsageSetWindow => 'Bağlam penceresini ayarla';

  @override
  String get contextUsageRefresh => 'Yenile';

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
  String get mcpPageClose => 'Kapat';

  @override
  String get mcpPageReconnect => 'Yeniden bağlan';

  @override
  String get mcpPageStatusConnected => 'Bağlandı';

  @override
  String get mcpPageStatusConnecting => 'Bağlanıyor…';

  @override
  String get mcpPageStatusDisconnected => 'Bağlı değil';

  @override
  String get mcpPageStatusAuthorizationRequired => 'Yetkilendirme gerekli';

  @override
  String get mcpPageStatusAuthorizing => 'Yetkilendiriliyor…';

  @override
  String get mcpPageStatusDisabled => 'Devre dışı';

  @override
  String get mcpPageOAuthRequired => 'OAuth ile oturum açmanız gerekiyor';

  @override
  String get mcpPageOAuthSignIn => 'OAuth ile oturum aç';

  @override
  String mcpPageToolsCount(int enabled, int total) {
    return 'Araçlar: $enabled/$total';
  }

  @override
  String get mcpPageConnectionFailed => 'Bağlantı başarısız';

  @override
  String get mcpPageDetails => 'Ayrıntılar';

  @override
  String get mcpPageDelete => 'Sil';

  @override
  String get mcpPageConfirmDeleteTitle => 'Silmeyi Onayla';

  @override
  String get mcpPageConfirmDeleteContent =>
      'Bu işlem Geri Al ile geri alınabilir. Silinsin mi?';

  @override
  String get mcpPageServerDeleted => 'Sunucu silindi';

  @override
  String get mcpPageUndo => 'Geri Al';

  @override
  String get mcpPageCancel => 'İptal';

  @override
  String get mcpConversationSheetTitle => 'MCP Sunucuları';

  @override
  String get mcpConversationSheetSubtitle =>
      'Bu sohbet için etkinleştirilecek sunucuları seçin';

  @override
  String get mcpConversationSheetSelectAll => 'Tümünü Seç';

  @override
  String get mcpConversationSheetClearAll => 'Temizle';

  @override
  String get mcpConversationSheetNoRunning => 'Çalışan MCP sunucusu yok';

  @override
  String get mcpConversationSheetConnected => 'Bağlandı';

  @override
  String mcpConversationSheetToolsCount(int enabled, int total) {
    return 'Araçlar: $enabled/$total';
  }

  @override
  String get mcpServerEditSheetEnabledLabel => 'Etkin';

  @override
  String get mcpServerEditSheetNameLabel => 'Ad';

  @override
  String get mcpServerEditSheetTransportLabel => 'Taşıma';

  @override
  String get mcpServerEditSheetUrlLabel => 'Sunucu URL\'si';

  @override
  String get mcpServerEditSheetCustomHeadersTitle => 'Özel Başlıklar';

  @override
  String get mcpServerEditSheetHeaderNameLabel => 'Başlık Adı';

  @override
  String get mcpServerEditSheetHeaderNameHint => 'örn. Authorization';

  @override
  String get mcpServerEditSheetHeaderValueLabel => 'Başlık Değeri';

  @override
  String get mcpServerEditSheetHeaderValueHint => 'örn. Bearer xxxxxx';

  @override
  String get mcpServerEditSheetRemoveHeaderTooltip => 'Kaldır';

  @override
  String get mcpServerEditSheetAddHeader => 'Başlık Ekle';

  @override
  String get mcpServerEditSheetTitleEdit => 'MCP\'yi Düzenle';

  @override
  String get mcpServerEditSheetTitleAdd => 'MCP Ekle';

  @override
  String get mcpServerEditSheetSyncToolsTooltip => 'Araçları Eşitle';

  @override
  String get mcpServerEditSheetTabBasic => 'Temel';

  @override
  String get mcpServerEditSheetTabTools => 'Araçlar';

  @override
  String get mcpServerEditSheetNoToolsHint =>
      'Araç yok, eşitlemek için yenile\'ye dokunun';

  @override
  String get mcpServerEditSheetCancel => 'İptal';

  @override
  String get mcpServerEditSheetSave => 'Kaydet';

  @override
  String get mcpServerEditSheetUrlRequired => 'Lütfen sunucu URL\'sini girin';

  @override
  String get defaultModelPageBackTooltip => 'Geri';

  @override
  String get defaultModelPageTitle => 'Varsayılan Model';

  @override
  String get defaultModelPageChatModelTitle => 'Sohbet Modeli';

  @override
  String get defaultModelPageChatModelSubtitle =>
      'Genel varsayılan sohbet modeli';

  @override
  String get defaultModelPageTitleModelTitle => 'Başlık Özetleme Modeli';

  @override
  String get defaultModelPageTitleModelSubtitle =>
      'Sohbet başlıklarını varsayılan olarak geçerli sohbet modelini kullanarak veya seçili bir modelle özetler.';

  @override
  String get titleModelThinkingTitle => 'Akıl Yürütmeyi Etkinleştir';

  @override
  String get defaultModelPageSummaryModelTitle => 'Özet Modeli';

  @override
  String get defaultModelPageSummaryModelSubtitle =>
      'Sohbet özetleri oluşturmak için kullanılır; hızlı ve ucuz modeller tercih edilir';

  @override
  String get defaultModelPageSuggestionModelTitle => 'Sohbet Önerileri Modeli';

  @override
  String get defaultModelPageSuggestionModelSubtitle =>
      'Geçerli sohbet modelini veya seçili bir modeli kullanarak takip önerisi balonları oluşturur. Varsayılan olarak devre dışıdır.';

  @override
  String get assistantEditRecentChatsSummaryFrequencyTitle =>
      'Özet Yenileme Sıklığı';

  @override
  String get assistantEditRecentChatsSummaryFrequencyDescription =>
      'Seçilen sayıda yeni mesajdan sonra son sohbet özetlerini yenile.';

  @override
  String assistantEditRecentChatsSummaryFrequencyOption(int count) {
    return 'Her $count mesajda';
  }

  @override
  String get assistantEditRecentChatsSummaryFrequencyCustomButton => 'Özel';

  @override
  String get assistantEditRecentChatsSummaryFrequencyCustomTitle =>
      'Özel Özet Sıklığı';

  @override
  String get assistantEditRecentChatsSummaryFrequencyCustomDescription =>
      'Son sohbet özetini yenilemeden önce kaç yeni mesaj birikmesi gerektiğini girin.';

  @override
  String get assistantEditRecentChatsSummaryFrequencyCustomLabel =>
      'Yeni mesaj sayısı';

  @override
  String get assistantEditRecentChatsSummaryFrequencyCustomHint =>
      '0\'dan büyük bir sayı girin';

  @override
  String get assistantEditRecentChatsSummaryFrequencyCustomInvalid =>
      'Lütfen 0\'dan büyük bir tam sayı girin';

  @override
  String get defaultModelPageTranslateModelTitle => 'Çeviri Modeli';

  @override
  String get defaultModelPageTranslateModelSubtitle =>
      'Mesaj içeriğini çevirmek için kullanılır; hızlı ve doğru modeller tercih edilir';

  @override
  String get defaultModelPageOcrModelTitle => 'OCR Modeli';

  @override
  String backgroundTaskFailed(String task, String error) {
    return '$task başarısız oldu: $error';
  }

  @override
  String get defaultModelPageOcrModelSubtitle =>
      'Görsellerden metin ve açıklama çıkarmak için kullanılır';

  @override
  String get defaultModelPageOcrModelRequiresImageInput =>
      'OCR için görsel girişi desteklediği etiketlenmiş bir model seçin';

  @override
  String get defaultModelPagePromptLabel => 'İstem';

  @override
  String get defaultModelPageTitlePromptHint =>
      'Başlık özetleme için istem şablonunu girin';

  @override
  String get defaultModelPageSummaryPromptHint =>
      'Özet oluşturma için istem şablonunu girin';

  @override
  String get defaultModelPageSuggestionPromptHint =>
      'Sohbet önerileri için istem şablonunu girin';

  @override
  String get defaultModelPageTranslatePromptHint =>
      'Çeviri için istem şablonunu girin';

  @override
  String get defaultModelPageOcrPromptHint =>
      'OCR görsel anlama için istem şablonunu girin';

  @override
  String get defaultModelPageResetDefault => 'Varsayılana sıfırla';

  @override
  String get defaultModelPageDisable => 'Devre dışı bırak';

  @override
  String get defaultModelPageSave => 'Kaydet';

  @override
  String defaultModelPageTitleVars(String contentVar, String localeVar) {
    return 'Değişkenler: içerik: $contentVar, dil: $localeVar';
  }

  @override
  String defaultModelPageSummaryVars(
    String previousSummaryVar,
    String userMessagesVar,
  ) {
    return 'Değişkenler: önceki özet: $previousSummaryVar, yeni mesajlar: $userMessagesVar';
  }

  @override
  String defaultModelPageSuggestionVars(String contentVar, String localeVar) {
    return 'Değişkenler: sohbet: $contentVar, dil: $localeVar';
  }

  @override
  String get defaultModelPageCompressModelTitle => 'Sıkıştırma Modeli';

  @override
  String get defaultModelPageCompressModelSubtitle =>
      'Uzun sohbetleri özetlemek için kullanılan model. Genellikle hızlı bir model yeterlidir.';

  @override
  String get defaultModelPageCompressPromptHint =>
      'Sıkıştırma sırasında kullanılacak istemi girin.';

  @override
  String defaultModelPageCompressVars(String contentVar, String localeVar) {
    return 'Değişkenler: sohbet $contentVar, dil $localeVar';
  }

  @override
  String defaultModelPageTranslateVars(String sourceVar, String targetVar) {
    return 'Değişkenler: kaynak metin: $sourceVar, hedef dil: $targetVar';
  }

  @override
  String get defaultModelPageUseCurrentModel =>
      'Geçerli sohbet modelini kullan';

  @override
  String get defaultModelPageNotEnabled => 'Etkin değil';

  @override
  String get translatePagePasteButton => 'Yapıştır';

  @override
  String get translatePageCopyResult => 'Sonucu kopyala';

  @override
  String get translatePageClearAll => 'Tümünü Temizle';

  @override
  String get translatePageInputHint => 'Çevrilecek metni girin…';

  @override
  String get translatePageOutputHint => 'Çeviri sonucu burada görünecek…';

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
  String get modelDetailSheetModelIdLabel => 'Model ID';

  @override
  String get modelDetailSheetModelIdHint =>
      'Zorunlu, küçük harf/rakam/tire önerilir';

  @override
  String get modelDetailSheetModelNameLabel => 'Model Adı';

  @override
  String get modelDetailSheetModelTypeLabel => 'Model Türü';

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
  String get modelDetailSheetImageMode => 'Görsel';

  @override
  String get modelDetailSheetToolsAbility => 'Araçlar';

  @override
  String get modelDetailSheetReasoningAbility => 'Akıl Yürütme';

  @override
  String get modelDetailSheetCustomHeadersTitle => 'Özel Headers';

  @override
  String get modelDetailSheetAddHeader => 'Header Ekle';

  @override
  String get modelDetailSheetCustomBodyTitle => 'Özel Body';

  @override
  String get modelFetchInvertTooltip => 'Seçimi ters çevir';

  @override
  String get modelDetailSheetSaveFailedMessage =>
      'Kaydetme başarısız. Lütfen tekrar deneyin.';

  @override
  String get modelDetailSheetAddBody => 'Body Ekle';

  @override
  String get modelDetailSheetBuiltinToolsDescription =>
      'Yerleşik araçlar sağlayıcıya ve API moduna bağlıdır.';

  @override
  String get modelDetailSheetUrlContextTool => 'URL Bağlamı';

  @override
  String get modelDetailSheetUrlContextToolDescription =>
      'URL içeriği alımını etkinleştir';

  @override
  String get modelDetailSheetCodeExecutionTool => 'Kod Yürütme';

  @override
  String get modelDetailSheetCodeExecutionToolDescription =>
      'Kod yürütme aracını etkinleştir';

  @override
  String get modelDetailSheetYoutubeTool => 'YouTube';

  @override
  String get modelDetailSheetYoutubeToolDescription =>
      'YouTube URL alımını etkinleştir (istemlerdeki bağlantıları otomatik algıla)';

  @override
  String get modelDetailSheetOpenaiBuiltinToolsResponsesOnlyHint =>
      'OpenAI Responses API gerektirir.';

  @override
  String get modelDetailSheetWebFetchTool => 'Web Getirme';

  @override
  String get modelDetailSheetOpenrouterWebFetchToolDescription =>
      'OpenRouter web getirme sunucu aracını etkinleştir';

  @override
  String get modelDetailSheetClaudeWebFetchToolDescription =>
      'Claude\'un sohbetteki URL\'lerden sayfaları ve PDF\'leri getirmesine izin ver';

  @override
  String get modelDetailSheetClaudeCodeExecutionToolDescription =>
      'Claude\'un Anthropic korumalı alanında Python ve Bash çalıştırmasına izin ver';

  @override
  String get modelDetailSheetOpenrouterShellTool => 'Shell';

  @override
  String get modelDetailSheetOpenrouterShellToolDescription =>
      'Shell komutlarını barındırılan, izole bir korumalı alanda çalıştır';

  @override
  String get modelDetailSheetOpenaiCodeInterpreterTool => 'Kod Yorumlayıcı';

  @override
  String get modelDetailSheetOpenaiCodeInterpreterToolDescription =>
      'Kod yorumlayıcı aracını etkinleştir (kapsayıcı otomatik, bellek sınırı 4g)';

  @override
  String get modelDetailSheetOpenaiImageGenerationTool => 'Görsel Oluşturma';

  @override
  String get modelDetailSheetOpenaiImageGenerationToolDescription =>
      'Görsel oluşturma aracını etkinleştir';

  @override
  String get modelDetailSheetCancelButton => 'İptal';

  @override
  String get modelDetailSheetAddButton => 'Ekle';

  @override
  String get modelDetailSheetConfirmButton => 'Onayla';

  @override
  String get modelDetailSheetInvalidIdError =>
      'Lütfen geçerli bir model ID girin (en az 2 karakter)';

  @override
  String get modelDetailSheetHeaderKeyHint => 'Header Key';

  @override
  String get modelDetailSheetHeaderValueHint => 'Header Value';

  @override
  String get modelDetailSheetBodyKeyHint => 'Body Key';

  @override
  String get modelDetailSheetBodyJsonHint => 'Body JSON';

  @override
  String get modelSpecFormSourceCustom => 'Özel';

  @override
  String get modelSpecFormSourceCatalog => 'Katalog';

  @override
  String get modelSpecFormSourceInferred => 'Çıkarımsal';

  @override
  String get modelSpecFormSourceDefault => 'Varsayılan';

  @override
  String get modelSpecFormReset => 'Varsayılana sıfırla';

  @override
  String get modelSpecFormModalitiesSection => 'Modaliteler ve yetenekler';

  @override
  String get modelSpecFormImageType => 'Görsel';

  @override
  String get modelSpecFormAudioMode => 'Ses';

  @override
  String get modelSpecFormVideoMode => 'Video';

  @override
  String get modelSpecFormPdfMode => 'PDF';

  @override
  String get modelSpecFormStructuredOutputAbility => 'Yapılandırılmış Çıktı';

  @override
  String get modelSpecFormReasoningSection => 'Akıl yürütme';

  @override
  String get modelSpecFormDialect => 'Lehçe';

  @override
  String get modelSpecFormDialectNone => 'Yok';

  @override
  String get modelSpecFormDialectNoneSubtitle => 'Akıl yürütme alanı yok';

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
      'Uyarlanabilir düşünme; Kapalıyken between_tools kullanılır';

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
  String get modelSpecFormDialectCustom => 'Özel JSON';

  @override
  String get modelSpecFormDialectCustomSubtitle => 'Seviye başına JSON yaması';

  @override
  String get modelSpecFormLevels => 'Desteklenen seviyeler';

  @override
  String get modelSpecFormCanDisable => 'Devre dışı bırakmaya izin ver';

  @override
  String get modelSpecFormDefaultLevel => 'Varsayılan seviye';

  @override
  String get modelSpecFormBudgets => 'Token bütçeleri';

  @override
  String modelSpecFormBudgetPlaceholder(String tokens) {
    return '$tokens';
  }

  @override
  String modelSpecFormCustomPatch(String level) {
    return 'JSON yaması ($level)';
  }

  @override
  String get modelSpecFormCustomPatchHint => 'örn. reasoning_effort: high';

  @override
  String get modelSpecFormInvalidJson =>
      'Özel akıl yürütme yaması geçerli bir JSON nesnesi olmalıdır';

  @override
  String get modelSpecFormInvalidNumber => 'Lütfen geçerli bir sayı girin';

  @override
  String get modelSpecFormStrategySection => 'Strateji';

  @override
  String get modelSpecFormSampling => 'Örnekleme';

  @override
  String get modelSpecFormRequestQuirks => 'İstek uyumluluğu';

  @override
  String get modelSpecFormDynamicWebSearch =>
      'Dinamik filtreleme arama araçları';

  @override
  String get modelSpecFormDynamicWebSearchSubtitle =>
      'Dinamik filtreleme açıkken 2026-03-18 web arama ve getirme araçlarını gönder';

  @override
  String get modelSpecFormRemoteImageUrls => 'Uzak görsel bağlantıları';

  @override
  String get modelSpecFormRemoteImageUrlsSubtitle =>
      'http(s) görsel bağlantılarını olduğu gibi gönder; kapalıyken uzak bağlantılar atlanır ve yalnızca yerel görseller gönderilir';

  @override
  String get modelSpecFormPromptCacheControl => 'İstem önbellek işaretçisi';

  @override
  String get modelSpecFormPromptCacheControlSubtitle =>
      'İstem önbellekleme açıkken OpenRouter isteklerine cache_control ekle';

  @override
  String get modelSpecFormSamplingAlways => 'Her zaman';

  @override
  String get modelSpecFormSamplingAlwaysSubtitle =>
      'temperature ve diğer örnekleme alanlarını koru';

  @override
  String get modelSpecFormSamplingOnlyWhenReasoningOff =>
      'Yalnızca akıl yürütme kapalıyken';

  @override
  String get modelSpecFormSamplingOnlyWhenReasoningOffSubtitle =>
      'Model düşünürken örnekleme alanlarını kaldır';

  @override
  String get modelSpecFormSamplingNever => 'Asla';

  @override
  String get modelSpecFormSamplingNeverSubtitle =>
      'Örnekleme alanlarını her zaman kaldır';

  @override
  String get modelSpecFormReplay => 'Akıl yürütme tekrarı';

  @override
  String get modelSpecFormReplayNone => 'Yok';

  @override
  String get modelSpecFormReplayNoneSubtitle =>
      'Önceki akıl yürütmeyi modele geri gönderme';

  @override
  String get modelSpecFormReplayToolTurns => 'Araç turları';

  @override
  String get modelSpecFormReplayToolTurnsSubtitle =>
      'Akıl yürütmeyi araç çağrısı turlarında tekrarla';

  @override
  String get modelSpecFormReplayAll => 'Tümü';

  @override
  String get modelSpecFormReplayAllSubtitle =>
      'Akıl yürütmeyi her takip turunda tekrarla';

  @override
  String get modelSpecFormReplayField => 'Tekrar alanı';

  @override
  String get modelSpecFormReplayFieldReasoningContent => 'reasoning_content';

  @override
  String get modelSpecFormReplayFieldReasoning => 'reasoning';

  @override
  String get modelSpecFormReplayFieldReasoningDetails => 'reasoning_details';

  @override
  String get modelSpecFormLimitsSection => 'Sınırlar';

  @override
  String get modelSpecFormLimitsPricingSection => 'Sınırlar ve fiyatlandırma';

  @override
  String get modelSpecFormContextWindow => 'Bağlam penceresi';

  @override
  String get modelSpecFormMaxOutput => 'Maksimum çıktı';

  @override
  String get modelSpecFormPricingSection => 'Fiyatlandırma / 1M';

  @override
  String get modelSpecFormPricingInput => 'Girdi';

  @override
  String get modelSpecFormPricingOutput => 'Çıktı';

  @override
  String get modelSpecFormPricingCacheRead => 'Önbellek okuma';

  @override
  String get modelSpecFormPricingCacheWrite => 'Önbellek yazma';

  @override
  String get modelSpecFormCurrency => 'Para birimi';

  @override
  String get modelSpecFormAdvancedSection => 'İstek';

  @override
  String get modelSelectSheetSearchHint => 'Model veya sağlayıcı ara';

  @override
  String get modelSelectSheetFavoritesSection => 'Favoriler';

  @override
  String get modelSelectSheetFollowAssistant => 'Asistanı takip et';

  @override
  String get modelSelectSheetFavoriteTooltip => 'Favori';

  @override
  String get modelSelectSheetChatType => 'Sohbet';

  @override
  String get modelSelectSheetEmbeddingType => 'Gömme';

  @override
  String get providerDetailPageShareTooltip => 'Paylaş';

  @override
  String get providerDetailPageDeleteProviderTooltip => 'Sağlayıcıyı Sil';

  @override
  String get providerDetailPageDeleteProviderTitle => 'Sağlayıcıyı Sil';

  @override
  String get providerDetailPageDeleteProviderContent =>
      'Bu sağlayıcıyı silmek istediğinizden emin misiniz? Bu işlem geri alınamaz.';

  @override
  String get providerDetailPageCancelButton => 'İptal';

  @override
  String get providerDetailPageDeleteButton => 'Sil';

  @override
  String get providerDetailPageProviderDeletedSnackbar => 'Sağlayıcı silindi';

  @override
  String get providerDetailPageConfigTab => 'Yapılandırma';

  @override
  String get providerDetailPageModelsTab => 'Modeller';

  @override
  String get providerDetailPageCustomRequestTitle => 'Özel İstek';

  @override
  String get providerDetailPageCustomRequestDescription =>
      'Bu sağlayıcıdaki tüm modeller için geçerlidir. Model ayarları bu değerleri geçersiz kılar; bu değerler de asistan ayarlarını geçersiz kılar.';

  @override
  String get providerDetailPageNetworkTab => 'Ağ';

  @override
  String get providerDetailPageEnabledTitle => 'Etkin';

  @override
  String get providerDetailPageManageSectionTitle => 'Yönet';

  @override
  String get providerDetailPageNameLabel => 'Ad';

  @override
  String get providerDetailPageApiKeyHint =>
      'Varsayılanı kullanmak için boş bırakın';

  @override
  String get providerDetailPageHideTooltip => 'Gizle';

  @override
  String get providerDetailPageShowTooltip => 'Göster';

  @override
  String get providerDetailPageApiPathLabel => 'API Yolu';

  @override
  String get providerDetailPageResponseApiTitle => 'Response API (/responses)';

  @override
  String get providerDetailPagePromptCacheKeyTitle =>
      'Sohbet Önbellek Anahtarı Gönder';

  @override
  String get providerDetailPagePromptCacheKeyHelp =>
      'OpenAI uyumlu isteklere her sohbet için sabit bir prompt_cache_key ekler. Yalnızca sağlayıcınız destekliyorsa etkinleştirin. Özel Body değerleri önceliklidir; önbellek isabetleri garanti edilmez.';

  @override
  String get providerDetailPageAihubmixAppCodeLabel => 'APP-Code (%10 indirim)';

  @override
  String get providerDetailPageAihubmixAppCodeHelp =>
      '%10 indirim almak için isteklere APP-Code başlığı ekler. Yalnızca AIhubmix\'i etkiler.';

  @override
  String get providerDetailPageClaudePromptCachingTitle =>
      'Claude Prompt Caching';

  @override
  String get providerDetailPageClaudePromptCachingHelp =>
      'Anthropic veya OpenRouter üzerinden Claude isteklerine cache_control ekler.';

  @override
  String get providerDetailPageClaudePromptCachingTtlTitle => 'Önbellek TTL';

  @override
  String get providerDetailPageClaudePromptCachingTtlHelp =>
      '5 dakika varsayılandır. 1 saat yazma maliyeti daha yüksektir ancak uzun sohbetlerde yeniden oluşturmayı azaltabilir.';

  @override
  String get providerDetailPageClaudePromptCachingTtl5m => '5 dk';

  @override
  String get providerDetailPageClaudePromptCachingTtl1h => '1 saat';

  @override
  String get providerDetailPageBalanceTitle => 'Hesap Bakiyesi';

  @override
  String get providerDetailPageBalanceInfo => 'Hesap bakiyesini al';

  @override
  String get providerDetailPageBalanceApiPathLabel =>
      'Bakiye API Yolu veya URL\'si';

  @override
  String get providerDetailPageBalanceMethodLabel => 'HTTP Yöntemi';

  @override
  String providerDetailPageBalanceRequestHint(String apiKeyPlaceholder) {
    return 'Bu ayarlar yalnızca bakiye sorguları için geçerlidir. Geçerli API anahtarını eklemek için başlıklarda veya gövdede $apiKeyPlaceholder kullanın. Kimlik doğrulama varsayılan olarak Bearer\'dır; boş başlık değeri o başlığı kaldırır.';
  }

  @override
  String get providerDetailPageBalanceBodyLabel =>
      'İstek Gövdesi (İsteğe Bağlı)';

  @override
  String get providerDetailPageBalanceBodyHint =>
      'Yalnızca POST ile gönderilir. Gövde göndermemek için boş bırakın. Content-Type varsayılan olarak application/json\'dır; başka bir biçim kullanmak için başlık ekleyin.';

  @override
  String get providerDetailPageBalanceResultPathLabel => 'Sonuç JSON Yolu';

  @override
  String get providerDetailPageBalanceQueryButton => 'Bakiyeyi Kontrol Et';

  @override
  String get providerDetailPageBalanceQuerying => 'Kontrol ediliyor...';

  @override
  String get providerDetailPageBalanceResetDefaultsButton => 'Sıfırla';

  @override
  String get providerDetailPageBalanceResetDefaultsTooltip =>
      'Bakiye ayarlarını sıfırla';

  @override
  String providerDetailPageBalanceResult(String value) {
    return 'Bakiye: $value';
  }

  @override
  String providerDetailPageBalanceError(String message) {
    return 'Bakiye sorgusu başarısız oldu: $message';
  }

  @override
  String get providerDetailPageVertexAiTitle => 'Vertex AI';

  @override
  String get providerDetailPageLocationLabel => 'Konum';

  @override
  String get providerDetailPageProjectIdLabel => 'Proje Kimliği';

  @override
  String get providerDetailPageServiceAccountJsonLabel =>
      'Hizmet Hesabı JSON (yapıştır veya içe aktar)';

  @override
  String get providerDetailPageImportJsonButton => 'JSON İçe Aktar';

  @override
  String get providerDetailPageImportJsonReadFailedMessage => 'Dosya okunamadı';

  @override
  String get providerDetailPageTestButton => 'Test Et';

  @override
  String get providerDetailPageSaveButton => 'Kaydet';

  @override
  String get providerDetailPageProviderRemovedMessage => 'Sağlayıcı kaldırıldı';

  @override
  String get providerDetailPageNoModelsTitle => 'Model Yok';

  @override
  String get providerDetailPageNoModelsSubtitle =>
      'Model eklemek için aşağıdaki düğmelere dokunun';

  @override
  String get providerDetailPageDeleteModelButton => 'Sil';

  @override
  String get providerDetailPageConfirmDeleteTitle => 'Silmeyi Onayla';

  @override
  String get providerDetailPageConfirmDeleteContent =>
      'Bu işlem Geri Al ile geri alınabilir. Silinsin mi?';

  @override
  String get providerDetailPageModelDeletedSnackbar => 'Model silindi';

  @override
  String get providerDetailPageUndoButton => 'Geri Al';

  @override
  String get providerDetailPageAddNewModelButton => 'Model Ekle';

  @override
  String get providerDetailPageFetchModelsButton => 'Getir';

  @override
  String get providerDetailPageEnableProxyTitle => 'Proxy\'yi Etkinleştir';

  @override
  String get providerDetailPageHostLabel => 'Sunucu';

  @override
  String get providerDetailPagePortLabel => 'Bağlantı Noktası';

  @override
  String get providerDetailPageUsernameOptionalLabel =>
      'Kullanıcı adı (isteğe bağlı)';

  @override
  String get providerDetailPagePasswordOptionalLabel => 'Parola (isteğe bağlı)';

  @override
  String get providerDetailPageSavedSnackbar => 'Kaydedildi';

  @override
  String get providerDetailPageEmbeddingsGroupTitle => 'Gömme';

  @override
  String get providerDetailPageOtherModelsGroupTitle => 'Diğer';

  @override
  String get providerDetailPageRemoveGroupTooltip => 'Grubu kaldır';

  @override
  String get providerDetailPageAddGroupTooltip => 'Grubu ekle';

  @override
  String get providerDetailPageFilterHint => 'Filtrelemek için model adı yazın';

  @override
  String get providerDetailPageDeleteText => 'Sil';

  @override
  String get providerDetailPageEditTooltip => 'Düzenle';

  @override
  String get providerDetailPageTestConnectionTitle => 'Bağlantıyı Test Et';

  @override
  String get providerDetailPageSelectModelButton => 'Model Seç';

  @override
  String get providerDetailPageChangeButton => 'Değiştir';

  @override
  String get providerDetailPageUseStreamingLabel => 'Akış Kullan';

  @override
  String get providerDetailPageTestingMessage => 'Test ediliyor…';

  @override
  String get providerDetailPageTestSuccessMessage => 'Başarılı';

  @override
  String get providersPageTitle => 'Sağlayıcılar';

  @override
  String get providersPageImportTooltip => 'İçe Aktar';

  @override
  String get providersPageAddTooltip => 'Ekle';

  @override
  String get providersPageSearchHint => 'Sağlayıcı veya grup ara';

  @override
  String get providersPageProviderAddedSnackbar => 'Sağlayıcı eklendi';

  @override
  String get modelCatalogTitle => 'Model kataloğu';

  @override
  String modelCatalogSourceBundled(String date) {
    return 'Paketlenmiş anlık görüntü · $date';
  }

  @override
  String modelCatalogSourceRemote(String date) {
    return 'models.dev · $date tarihinde güncellendi';
  }

  @override
  String get modelCatalogAutoUpdate => 'Her 24 saatte bir otomatik güncelle';

  @override
  String get modelCatalogRefresh => 'Şimdi güncelle';

  @override
  String get modelCatalogUpdated => 'Model kataloğu güncellendi';

  @override
  String modelCatalogRefreshFailed(String error) {
    return 'Güncelleme başarısız: $error';
  }

  @override
  String modelCatalogProviderCount(int count) {
    return '$count sağlayıcı';
  }

  @override
  String modelCatalogModelCount(int count) {
    return '$count model';
  }

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
  String get providerGroupsCreateDialogCancel => 'İptal';

  @override
  String get providerGroupsCreateDialogOk => 'Oluştur';

  @override
  String get providerGroupsCreateFailedToast => 'Grup oluşturulamadı';

  @override
  String get providerGroupsDeleteConfirmTitle => 'Grup silinsin mi?';

  @override
  String get providerGroupsDeleteConfirmContent =>
      'Bu gruptaki sağlayıcılar “Diğer” grubuna taşınacak.';

  @override
  String get providerGroupsDeleteConfirmCancel => 'İptal';

  @override
  String get providerGroupsDeleteConfirmOk => 'Sil';

  @override
  String get providerGroupsDeletedToast => 'Grup silindi';

  @override
  String get providerGroupsEmptyState => 'Henüz grup yok.';

  @override
  String get providerGroupsExpandToMoveToast => 'Lütfen önce grubu genişletin.';

  @override
  String get providersPageSiliconFlowName => 'SiliconFlow';

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
  String get providersPageModelsCountSuffix => ' model';

  @override
  String get providersPageModelsCountSingleSuffix => ' model';

  @override
  String get addProviderSheetTitle => 'Sağlayıcı Ekle';

  @override
  String get addProviderSheetEnabledLabel => 'Etkin';

  @override
  String get addProviderSheetNameLabel => 'Ad';

  @override
  String get addProviderSheetApiPathLabel => 'API Yolu';

  @override
  String get addProviderSheetVertexAiLocationLabel => 'Konum';

  @override
  String get addProviderSheetVertexAiProjectIdLabel => 'Proje Kimliği';

  @override
  String get addProviderSheetVertexAiServiceAccountJsonLabel =>
      'Hizmet Hesabı JSON (yapıştır veya içe aktar)';

  @override
  String get addProviderSheetImportJsonButton => 'JSON İçe Aktar';

  @override
  String get addProviderSheetCancelButton => 'İptal';

  @override
  String get addProviderSheetAddButton => 'Ekle';

  @override
  String get importProviderSheetTitle => 'Sağlayıcı İçe Aktar';

  @override
  String get importProviderSheetScanQrTooltip => 'QR Tara';

  @override
  String get importProviderSheetFromGalleryTooltip => 'Galeriden';

  @override
  String importProviderSheetImportSuccessMessage(int count) {
    return '$count sağlayıcı içe aktarıldı';
  }

  @override
  String importProviderSheetImportFailedMessage(String error) {
    return 'İçe aktarma başarısız: $error';
  }

  @override
  String get importProviderSheetDescription =>
      'Paylaşım dizelerini (çok satırlı desteklenir) veya ChatBox JSON yapıştırın';

  @override
  String get importProviderSheetInputHint => 'ai-provider:v1:... veya JSON';

  @override
  String get importProviderSheetCancelButton => 'İptal';

  @override
  String get importProviderSheetImportButton => 'İçe Aktar';

  @override
  String get shareProviderSheetTitle => 'Sağlayıcıyı Paylaş';

  @override
  String get shareProviderSheetDescription =>
      'Kopyalayın veya QR koduyla paylaşın.';

  @override
  String get shareProviderSheetCopiedMessage => 'Kopyalandı';

  @override
  String get shareProviderSheetCopyButton => 'Kopyala';

  @override
  String get shareProviderSheetShareButton => 'Paylaş';

  @override
  String get desktopProviderContextMenuShare => 'Paylaş';

  @override
  String get desktopProviderShareCopyText => 'Kodu kopyala';

  @override
  String get desktopProviderShareCopyQr => 'QR kodu kopyala';

  @override
  String get providerDetailPageApiBaseUrlLabel => 'API Temel URL\'si';

  @override
  String get providerDetailPageModelsTitle => 'Modeller';

  @override
  String get providerModelsGetButton => 'Getir';

  @override
  String get providerDetailPageCapsVision => 'Görüntü';

  @override
  String get providerDetailPageCapsImage => 'Görsel';

  @override
  String get providerDetailPageCapsTool => 'Araç';

  @override
  String get providerDetailPageCapsReasoning => 'Akıl yürütme';

  @override
  String get qrScanPageTitle => 'QR Tara';

  @override
  String get qrScanPageInstruction => 'QR kodunu çerçeveye hizalayın';

  @override
  String get searchServicesPageBackTooltip => 'Geri';

  @override
  String get searchServicesPageTitle => 'Hizmetleri Ara';

  @override
  String get searchServicesPageDone => 'Bitti';

  @override
  String get searchServicesPageEdit => 'Düzenle';

  @override
  String get searchServicesPageAddProvider => 'Sağlayıcı Ekle';

  @override
  String get searchServicesPageSearchProviders => 'Sağlayıcıları Ara';

  @override
  String get searchServicesPageGeneralOptions => 'Genel Seçenekler';

  @override
  String get searchServicesPageAutoTestTitle =>
      'Başlangıçta bağlantıları otomatik test et';

  @override
  String get searchServicesPageWebFetchSection => 'Web sayfası okuma';

  @override
  String get searchServicesPageWebFetchModeTitle => 'Sayfaları şununla oku';

  @override
  String get searchServicesPageWebFetchFollow => 'Arama hizmetini takip et';

  @override
  String searchServicesPageWebFetchFollowValue(String name) {
    return 'Aramayı takip et · $name';
  }

  @override
  String searchServicesPageWebFetchFollowSubtitle(String name) {
    return 'Şu anda $name';
  }

  @override
  String get searchServicesPageWebFetchLocal => 'Yerel';

  @override
  String get searchServicesPageWebFetchLocalSubtitle =>
      'Ücretsiz. Bu cihaz sayfayı doğrudan ister.';

  @override
  String get searchServicesPageWebFetchProviderSubtitle =>
      'Bu hizmetin API anahtarını ve kotasını kullanır';

  @override
  String get searchServicesPageWebFetchOff => 'Kapalı';

  @override
  String get searchServicesPageWebFetchOffSubtitle =>
      'Yalnızca arama, sayfalar okunmaz';

  @override
  String get searchServicesPageWebFetchFooter =>
      'Web araması açıkken model tam sayfaları da okuyabilir. Arama hizmeti sayfaları okuyamadığında yerel okuma kullanılır; bu yöntem JavaScript gerektiren veya botları engelleyen sayfaları işleyemez.\n\nBurada yapılandırılan sayfa okuyucuyu kullanıyorsanız, araçların çakışmasını önlemek için Ayarlar → MCP bölümünden yerleşik @kelivo/fetch\'i kapatın. Burada yapılandırılan sayfa okuyucu yine de çalışır.';

  @override
  String get searchServicesPageWebFetchSupported =>
      'Web sayfalarını okuyabilir';

  @override
  String get searchServicesPageMaxResults => 'Maksimum Sonuç';

  @override
  String get searchServicesPageTimeoutSeconds => 'Zaman aşımı (saniye)';

  @override
  String get searchServicesPageAtLeastOneServiceRequired =>
      'En az bir arama hizmeti gerekli';

  @override
  String get searchServicesPageTestingStatus => 'Test ediliyor…';

  @override
  String get searchServicesPageConnectedStatus => 'Bağlandı';

  @override
  String get searchServicesPageFailedStatus => 'Başarısız';

  @override
  String get searchServicesPageNotTestedStatus => 'Test edilmedi';

  @override
  String get searchServicesPageEditServiceTooltip => 'Hizmeti Düzenle';

  @override
  String get searchServicesPageTestConnectionTooltip => 'Bağlantıyı Test Et';

  @override
  String get searchServicesPageDeleteServiceTooltip => 'Hizmeti Sil';

  @override
  String get searchServicesPageConfiguredStatus => 'Yapılandırıldı';

  @override
  String get miniMapTitle => 'Mini harita';

  @override
  String get miniMapTooltip => 'Mini harita';

  @override
  String get miniMapScrollToBottomTooltip => 'En alta kaydır';

  @override
  String miniMapSearchMatchCount(int count) {
    return '$count';
  }

  @override
  String get miniMapSearchNoResults => 'Eşleşen mesaj yok';

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
  String get searchServicesAddDialogCancel => 'İptal';

  @override
  String get searchServicesAddDialogAdd => 'Ekle';

  @override
  String get searchServicesAddDialogApiKeyRequired => 'API Anahtarı gerekli';

  @override
  String get searchServicesFieldCustomUrlOptional => 'Özel URL (isteğe bağlı)';

  @override
  String get searchServicesDialogApiKey => 'API Anahtarı';

  @override
  String get searchServicesDialogApiKeyOptional =>
      'API Anahtarı (isteğe bağlı)';

  @override
  String get searchServicesDialogModel => 'Model';

  @override
  String get searchServicesDialogSystemPrompt => 'Sistem İstemi';

  @override
  String get searchServicesAddDialogInstanceUrl => 'Örnek URL';

  @override
  String get searchServicesAddDialogUrlRequired => 'URL gerekli';

  @override
  String get searchServicesAddDialogEnginesOptional =>
      'Motorlar (isteğe bağlı)';

  @override
  String get searchServicesAddDialogLanguageOptional => 'Dil (isteğe bağlı)';

  @override
  String get searchServicesAddDialogUsernameOptional =>
      'Kullanıcı adı (isteğe bağlı)';

  @override
  String get searchServicesAddDialogPasswordOptional => 'Parola (isteğe bağlı)';

  @override
  String get searchServicesAddDialogRegionOptional =>
      'Bölge (isteğe bağlı, varsayılan: us-en)';

  @override
  String get searchServicesEditDialogEdit => 'Düzenle';

  @override
  String get searchServicesEditDialogCancel => 'İptal';

  @override
  String get searchServicesEditDialogSave => 'Kaydet';

  @override
  String get searchServicesEditDialogBingLocalNoConfig =>
      'Bing Yerel araması için yapılandırma gerekmez.';

  @override
  String get searchServicesEditDialogApiKeyRequired => 'API Anahtarı gerekli';

  @override
  String get searchServicesEditDialogInstanceUrl => 'Örnek URL';

  @override
  String get searchServicesEditDialogUrlRequired => 'URL gerekli';

  @override
  String get searchServicesEditDialogEnginesOptional =>
      'Motorlar (isteğe bağlı)';

  @override
  String get searchServicesEditDialogLanguageOptional => 'Dil (isteğe bağlı)';

  @override
  String get searchServicesEditDialogUsernameOptional =>
      'Kullanıcı adı (isteğe bağlı)';

  @override
  String get searchServicesEditDialogPasswordOptional =>
      'Parola (isteğe bağlı)';

  @override
  String get searchServicesEditDialogRegionOptional =>
      'Bölge (isteğe bağlı, varsayılan: us-en)';

  @override
  String get searchServiceEditorProviderTypeTitle => 'Arama sağlayıcısı';

  @override
  String get searchServiceEditorConfigurationTitle => 'Yapılandırma';

  @override
  String get searchServiceEditorNoConfiguration =>
      'Bu sağlayıcı ek yapılandırma gerektirmez.';

  @override
  String get searchServiceEditorMultiKeyTitle => 'Çoklu anahtar rotasyonu';

  @override
  String get searchServiceEditorMultiKeyNone => 'Yapılandırılmadı';

  @override
  String get searchApiKeysPageDescription =>
      'Anahtarlar listelenen sırayla döner; ilki birincil anahtardır. Sağlayıcı hız sınırlamasını önlemek için kullanım sorgulanmaz.';

  @override
  String get searchApiKeysPagePrimaryBadge => 'Birincil';

  @override
  String get searchApiKeysPageBatchHint =>
      'Bir veya daha fazla anahtar yapıştırın — her satıra bir tane veya virgülle ayrılmış';

  @override
  String searchApiKeysPageBatchResult(String added, String skipped) {
    return '$added eklendi, $skipped yinelenen atlandı';
  }

  @override
  String get searchApiKeysPageAdd => 'Ekle';

  @override
  String get searchApiKeysPageEmpty => 'Henüz anahtar yapılandırılmadı.';

  @override
  String searchServiceEditorMultiKeyCount(String count) {
    return '$count anahtar';
  }

  @override
  String get searchServiceEditorUsageTitle => 'Hesap kullanımı';

  @override
  String get searchServiceEditorUsageNotQueried =>
      'Kullanım henüz sorgulanmadı.';

  @override
  String get searchServiceEditorUsageQuery => 'Kullanımı kontrol et';

  @override
  String get searchServiceEditorUsageQuerying => 'Kontrol ediliyor…';

  @override
  String searchServiceEditorUsageRemaining(String remaining) {
    return '$remaining kredi kaldı';
  }

  @override
  String searchServiceEditorUsageBalance(String balance) {
    return 'Bakiye: $balance';
  }

  @override
  String searchServiceEditorUsageUsed(String used, String limit) {
    return '$limit krediden $used kullanıldı';
  }

  @override
  String searchServiceEditorUsageFailed(String message) {
    return 'Kullanım sorgulanamadı: $message';
  }

  @override
  String get searchServiceEditorTestTitle => 'Aramayı test et';

  @override
  String get searchServiceEditorTestQueryHint => 'Bir sorgu girin';

  @override
  String get searchServiceEditorTestRun => 'Test aramasını çalıştır';

  @override
  String get searchServiceEditorTestRunning => 'Aranıyor…';

  @override
  String get searchServiceEditorTestNoResults =>
      'Sağlayıcı hiçbir sonuç döndürmedi.';

  @override
  String searchServiceEditorTestFailed(String message) {
    return 'Arama başarısız: $message';
  }

  @override
  String get searchServiceEditorTestModeSearch => 'Arama';

  @override
  String get searchServiceEditorTestModeFetch => 'Sayfayı oku';

  @override
  String get searchServiceEditorTestUrlHint => 'Bir URL girin';

  @override
  String get searchServiceEditorTestFetchRun => 'Test getirmeyi çalıştır';

  @override
  String get searchServiceEditorTestFetchRunning => 'Okunuyor…';

  @override
  String searchServiceEditorTestFetchFailed(String message) {
    return 'Getirme başarısız: $message';
  }

  @override
  String searchServiceEditorTestFetchStats(String characters, String seconds) {
    return '$characters karakter · $seconds sn';
  }

  @override
  String get searchServiceEditorResultOpenTooltip => 'Sonucu aç';

  @override
  String get searchServiceEditorDeleteTooltip => 'Arama hizmetini sil';

  @override
  String get searchServiceEditorDeleteTitle => 'Arama hizmeti silinsin mi?';

  @override
  String searchServiceEditorDeleteMessage(String provider) {
    return '$provider silinsin mi? Bu işlem geri alınamaz.';
  }

  @override
  String get searchServiceEditorDeleteConfirm => 'Sil';

  @override
  String get searchServiceEditorDiscardTitle => 'Değişiklikler atılsın mı?';

  @override
  String get searchServiceEditorDiscardMessage =>
      'Kaydedilmemiş arama hizmeti ayarlarınız kaybolacak.';

  @override
  String get searchServiceEditorKeepEditing => 'Düzenlemeye devam et';

  @override
  String get searchServiceEditorDiscard => 'Vazgeç';

  @override
  String get searchSettingsSheetTitle => 'Arama Ayarları';

  @override
  String get searchSettingsSheetBuiltinSearchTitle => 'Yerleşik Arama';

  @override
  String get searchSettingsSheetBuiltinSearchDescription =>
      'Modelin yerleşik aramasını etkinleştir';

  @override
  String get searchSettingsSheetClaudeDynamicSearchTitle =>
      'Dinamik filtreleme';

  @override
  String get searchSettingsSheetClaudeDynamicSearchDescription =>
      'Token tasarrufu için sonuçları filtrele';

  @override
  String get searchSettingsSheetWebSearchTitle => 'Web Araması';

  @override
  String get searchSettingsSheetWebSearchDescription =>
      'Sohbette web aramasını etkinleştir';

  @override
  String get searchSettingsSheetOpenSearchServicesTooltip =>
      'Arama hizmetlerini aç';

  @override
  String get searchSettingsSheetNoServicesMessage =>
      'Hizmet yok. Arama Hizmetleri\'nden ekleyin.';

  @override
  String get aboutPageEasterEggMessage =>
      'Keşfettiğiniz için teşekkürler! \n (Henüz yumurta yok)';

  @override
  String get aboutPageEasterEggButton => 'Harika!';

  @override
  String get aboutPageKelivoSearchUnlocked =>
      'İsimsiz bir kapı aralandı. Ayarlar\'da bulabilirsiniz.';

  @override
  String get aboutPageKelivoSearchAlreadyUnlocked =>
      'Bu kapıdan zaten geçtiniz.';

  @override
  String get aboutPageAppName => 'Kelivo';

  @override
  String get aboutPageAppDescription => 'Açık kaynaklı AI asistanı';

  @override
  String get aboutPageNoQQGroup => 'Henüz QQ grubu yok';

  @override
  String get aboutPageVersion => 'Sürüm';

  @override
  String aboutPageVersionDetail(String version, String buildNumber) {
    return '$version / $buildNumber';
  }

  @override
  String get aboutPageSystem => 'Sistem';

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
    return 'Diğer ($os)';
  }

  @override
  String get aboutPageWebsite => 'Web sitesi';

  @override
  String get aboutPageGithub => 'GitHub';

  @override
  String get aboutPageLicense => 'Lisans';

  @override
  String get aboutPageJoinQQGroup => 'QQ Grubumuza katılın';

  @override
  String get aboutPageQQGroupOne => 'Kelivo Grup 1';

  @override
  String get aboutPageQQGroupTwo => 'Kelivo Grup 2';

  @override
  String get aboutPageQQGroupThree => 'Kelivo Grup 3';

  @override
  String get aboutPageJoinDiscord => 'Discord\'da bize katılın';

  @override
  String get displaySettingsPageShowUserAvatarTitle =>
      'Kullanıcı Avatarını Göster';

  @override
  String get displaySettingsPageShowUserAvatarSubtitle =>
      'Sohbet mesajlarında kullanıcı avatarını göster';

  @override
  String get displaySettingsPageShowUserNameTimestampTitle =>
      'Kullanıcı Adı ve Zaman Damgasını Göster';

  @override
  String get displaySettingsPageShowUserNameTimestampSubtitle =>
      'Sohbet mesajlarında kullanıcı adını ve altındaki zaman damgasını göster';

  @override
  String get displaySettingsPageShowUserNameTitle => 'Kullanıcı Adını Göster';

  @override
  String get displaySettingsPageShowUserTimestampTitle =>
      'Kullanıcı Zaman Damgasını Göster';

  @override
  String get displaySettingsPageShowUserMessageActionsTitle =>
      'Kullanıcı Mesaj İşlemlerini Göster';

  @override
  String get displaySettingsPageShowUserMessageActionsSubtitle =>
      'Mesajlarınızın altında kopyala, yeniden gönder ve diğer düğmeleri göster';

  @override
  String get displaySettingsPageShowModelNameTimestampTitle =>
      'Model Adı ve Zaman Damgasını Göster';

  @override
  String get displaySettingsPageShowModelNameTimestampSubtitle =>
      'Sohbet mesajlarında model adını ve altındaki zaman damgasını göster';

  @override
  String get displaySettingsPageShowModelNameTitle => 'Model Adını Göster';

  @override
  String get displaySettingsPageShowModelTimestampTitle =>
      'Model Zaman Damgasını Göster';

  @override
  String get displaySettingsPageShowProviderInChatMessageTitle =>
      'Model Adından Sonra Sağlayıcıyı Göster';

  @override
  String get displaySettingsPageShowProviderInChatMessageSubtitle =>
      'Sohbet mesajlarında model kimliğinden sonra sağlayıcı adını göster (ör. model | sağlayıcı)';

  @override
  String get displaySettingsPageChatModelIconTitle => 'Sohbet Model Simgesi';

  @override
  String get displaySettingsPageChatModelIconSubtitle =>
      'Sohbet mesajlarında model simgesini göster';

  @override
  String get displaySettingsPageShowTokenStatsTitle =>
      'Token ve Bağlam İstatistiklerini Göster';

  @override
  String get displaySettingsPageShowTotalTokensTitle =>
      'Tüm tur için tokenları göster';

  @override
  String get displaySettingsPageShowTotalTokensSubtitle =>
      'Bir yanıttaki tüm API isteklerinin kullanımını topla. Kapalıyken yalnızca son isteği göster. İstatistikler her zaman tüm istekleri içerir.';

  @override
  String get displaySettingsPageShowTokenStatsSubtitle =>
      'Token kullanımını ve mesaj sayısını göster';

  @override
  String get displaySettingsPageShowThinkingCardsTitle =>
      'Düşünme Kartlarını Göster';

  @override
  String get displaySettingsPageShowThinkingCardsSubtitle =>
      'Kapalıyken düşünme süreci kartları sohbette gizlenir.';

  @override
  String get displaySettingsPageShowToolCardsTitle => 'Araç Kartlarını Göster';

  @override
  String get displaySettingsPageShowToolCardsSubtitle =>
      'Kapalıyken araç kullanımı kartları sohbette gizlenir.';

  @override
  String get displaySettingsShowReasoningLevelBadge =>
      'Düğmede akıl yürütme düzeyini göster';

  @override
  String get displaySettingsShowReasoningLevelBadgeSubtitle =>
      'Giriş çubuğundaki akıl yürütme simgesinin yanında geçerli düzeyi göster';

  @override
  String get displaySettingsPageAutoCollapseThinkingTitle =>
      'Düşünmeyi Otomatik Daralt';

  @override
  String get displaySettingsPageAutoCollapseThinkingSubtitle =>
      'Akıl yürütmeyi tamamlandıktan sonra daralt';

  @override
  String get displaySettingsPageCollapseThinkingStepsTitle =>
      'Düşünme Adımlarını Daralt';

  @override
  String get displaySettingsPageCollapseThinkingStepsSubtitle =>
      'Genişletilene kadar yalnızca en son adımları göster';

  @override
  String get displaySettingsPageShowToolResultSummaryTitle =>
      'Araç Sonucu Özetini Göster';

  @override
  String get displaySettingsPageInsertSuggestionOnlyTitle =>
      'Önerileri göndermeden ekle';

  @override
  String get displaySettingsPageShowToolResultSummarySubtitle =>
      'Özet metnini araç adımlarının altında göster';

  @override
  String get displaySettingsPageHideToolResultImagesTitle =>
      'Araç sonuçlarındaki görselleri gizle';

  @override
  String get displaySettingsPageRegenerateDeleteTrailingMessagesTitle =>
      'Yeniden oluştururken aşağıdaki mesajları sil';

  @override
  String get displaySettingsPageShowRegenerateConfirmDialogTitle =>
      'Yeniden oluşturmadan önce onayla';

  @override
  String get displaySettingsPageForkKeepMessageVersionsTitle =>
      'Çatallarken Mesaj Sürümlerini Koru';

  @override
  String get displaySettingsPageEditAssistantKeepThinkingToolCardsTitle =>
      'Asistanı düzenlerken düşünme ve araç kartlarını koru';

  @override
  String get displaySettingsPageEditAssistantKeepThinkingToolCardsSubtitle =>
      'Kapalıyken düzenlenen sürüm yalnızca asistan metnini korur. Geri döndüğünüzde önceki düşünme ve araç kartları yine görünür.';

  @override
  String chainOfThoughtExpandSteps(Object count) {
    return '$count adım daha göster';
  }

  @override
  String get chainOfThoughtCollapse => 'Daralt';

  @override
  String get displaySettingsPageShowChatListDateTitle =>
      'Sohbet Listesi Tarihlerini Göster';

  @override
  String get displaySettingsPageShowChatListDateSubtitle =>
      'Sohbet listesinde tarih grubu etiketlerini göster';

  @override
  String get displaySettingsPageEnableImageCropperTitle =>
      'Görsel Kırpmayı Etkinleştir';

  @override
  String get displaySettingsPageEnableImageCropperSubtitle =>
      'Galeri veya kameradan seçtikten sonra görselleri kırp';

  @override
  String get displaySettingsPageKeepSidebarOpenOnAssistantTapTitle =>
      'Asistan seçerken kenar çubuğunu açık tut';

  @override
  String get displaySettingsPageKeepSidebarOpenOnTopicTapTitle =>
      'Konu seçerken kenar çubuğunu açık tut';

  @override
  String get displaySettingsPageKeepAssistantListExpandedOnSidebarCloseTitle =>
      'Kenar çubuğu kapanırken asistan listesini daraltma';

  @override
  String get displaySettingsPageShowUpdatesTitle => 'Güncellemeleri Göster';

  @override
  String get displaySettingsPageShowUpdatesSubtitle =>
      'Uygulama güncelleme bildirimlerini göster';

  @override
  String get displaySettingsPageKeepScreenOnDuringGenerationTitle =>
      'Oluşturma Sırasında Ekranı Açık Tut';

  @override
  String get displaySettingsPageKeepScreenOnDuringGenerationSubtitle =>
      'Üretim sırasında kilit ekranının kesintiye yol açmasını önler. Pil kullanımını artırır.';

  @override
  String get displaySettingsPageMessageNavButtonsTitle =>
      'Mesaj Gezinme Düğmeleri';

  @override
  String get displaySettingsPageMessageNavButtonsSubtitle =>
      'Hızlı atlama düğmelerinin ne zaman görüneceğini seçin';

  @override
  String get displaySettingsPageMessageNavButtonsModeAlways =>
      'Her zaman göster';

  @override
  String get displaySettingsPageMessageNavButtonsModeScroll =>
      'Kaydırırken göster';

  @override
  String get displaySettingsPageMessageNavButtonsModeHover =>
      'Fareyle üzerine gelince göster';

  @override
  String get displaySettingsPageMessageNavButtonsModeScrollAndHover =>
      'Kaydırırken veya üzerine gelince göster';

  @override
  String get displaySettingsPageMessageNavButtonsModeNever => 'Hiç gösterme';

  @override
  String get displaySettingsPageUseNewAssistantAvatarUxTitle =>
      'Sohbet başlık çubuğunda asistan avatarını göster';

  @override
  String get displaySettingsPageHapticsOnSidebarTitle =>
      'Kenar Çubuğunda Dokunsal Geri Bildirim';

  @override
  String get displaySettingsPageHapticsOnSidebarSubtitle =>
      'Kenar çubuğunu açarken/kapatırken dokunsal geri bildirimi etkinleştir';

  @override
  String get displaySettingsPageHapticsGlobalTitle =>
      'Genel Dokunsal Geri Bildirim';

  @override
  String get displaySettingsPageHapticsIosSwitchTitle =>
      'Anahtarlarda Dokunsal Geri Bildirim';

  @override
  String get displaySettingsPageHapticsOnListItemTapTitle =>
      'Liste Öğelerinde Dokunsal Geri Bildirim';

  @override
  String get displaySettingsPageHapticsOnCardTapTitle =>
      'Kartlarda Dokunsal Geri Bildirim';

  @override
  String get displaySettingsPageHapticsOnGenerateTitle =>
      'Üretimde Dokunsal Geri Bildirim';

  @override
  String get displaySettingsPageHapticsOnGenerateSubtitle =>
      'Üretim sırasında dokunsal geri bildirimi etkinleştir';

  @override
  String get displaySettingsPageNewChatAfterDeleteTitle =>
      'Konu silindikten sonra yeni sohbet';

  @override
  String get displaySettingsPageNewChatOnAssistantSwitchTitle =>
      'Asistan değiştirirken yeni sohbet';

  @override
  String get displaySettingsPageNewChatOnLaunchTitle =>
      'Başlatmada Yeni Sohbet';

  @override
  String get displaySettingsPageEnterToSendTitle => 'Göndermek için Enter Tuşu';

  @override
  String get displaySettingsPageLongPasteAsFileTitle =>
      'Uzun metni dosya olarak yapıştır';

  @override
  String get displaySettingsPageLongPasteAsFileThresholdTitle =>
      'Dönüştürme eşiği';

  @override
  String get displaySettingsPageLongPasteAsFileThresholdUnit => 'karakter';

  @override
  String get displaySettingsPageSendShortcutTitle => 'Gönderme Kısayolu';

  @override
  String get displaySettingsPageSendShortcutEnter => 'Enter';

  @override
  String get displaySettingsPageSendShortcutCtrlEnter => 'Ctrl/Cmd + Enter';

  @override
  String get displaySettingsPageAutoSwitchTopicsTitle =>
      'Otomatik olarak Konulara geç';

  @override
  String get desktopDisplaySettingsTopicPositionTitle => 'Konu konumu';

  @override
  String get desktopDisplaySettingsTopicPositionLeft => 'Sol';

  @override
  String get desktopDisplaySettingsTopicPositionRight => 'Sağ';

  @override
  String get displaySettingsPageNewChatOnLaunchSubtitle =>
      'Başlatmada otomatik olarak yeni sohbet oluştur';

  @override
  String get displaySettingsPageChatFontSizeTitle => 'Sohbet Yazı Boyutu';

  @override
  String get displaySettingsPageAutoScrollEnableTitle =>
      'Otomatik olarak alta takip et';

  @override
  String get displaySettingsPageAutoScrollDisabledLabel => 'Kapalı';

  @override
  String get displaySettingsPageChatFontSampleText =>
      'Bu bir örnek sohbet metnidir';

  @override
  String get displaySettingsPageChatBackgroundMaskTitle =>
      'Sohbet Arka Planı Kaplama Opaklığı';

  @override
  String get displaySettingsPageChatInputBackgroundOpacityTitle =>
      'Giriş Kutusu Arka Plan Opaklığı';

  @override
  String get displaySettingsPageThemeSettingsTitle => 'Tema Ayarları';

  @override
  String get displaySettingsPageThemeColorTitle => 'Tema Rengi';

  @override
  String get desktopSettingsFontsTitle => 'Yazı Tipleri';

  @override
  String get linuxHideTitleBarTitle => 'Sistem başlık çubuğunu gizle';

  @override
  String get linuxHideTitleBarDescription =>
      'Pencere düğmelerini de gizler. Pencereyi taşımak, yeniden boyutlandırmak ve kapatmak için pencere yöneticinizi kullanın.';

  @override
  String get linuxHideTitleBarError =>
      'Başlık çubuğu değiştirilemedi. Lütfen tekrar deneyin.';

  @override
  String get displaySettingsPageTrayTitle => 'Sistem Tepsisi';

  @override
  String get displaySettingsPageTrayShowTrayTitle => 'TePsi simgesini göster';

  @override
  String get displaySettingsPageTrayMinimizeOnCloseTitle =>
      'Kapatırken tepsiye küçült';

  @override
  String get desktopFontAppLabel => 'Uygulama Yazı Tipi';

  @override
  String get desktopFontCodeLabel => 'Kod Yazı Tipi';

  @override
  String get desktopFontFamilySystemDefault => 'Sistem Varsayılanı';

  @override
  String get desktopFontFamilyMonospaceDefault => 'Eş aralıklı';

  @override
  String get desktopFontFilterHint => 'Yazı tiplerini filtrele…';

  @override
  String get displaySettingsPageAppFontTitle => 'Uygulama Yazı Tipi';

  @override
  String get displaySettingsPageCodeFontTitle => 'Kod Yazı Tipi';

  @override
  String get fontPickerChooseLocalFile => 'Yerel Dosya Seç';

  @override
  String get desktopFontLoading => 'Yazı tipleri yükleniyor…';

  @override
  String get displaySettingsPageFontLocalFileLabel => 'Yerel dosya';

  @override
  String get displaySettingsPageFontResetLabel =>
      'Yazı tipi ayarlarını sıfırla';

  @override
  String get displaySettingsPageOtherSettingsTitle => 'Diğer Ayarlar';

  @override
  String get themeSettingsPageDynamicColorSection => 'Dinamik Renk';

  @override
  String get themeSettingsPageUseDynamicColorTitle => 'Sistem Dinamik Renkleri';

  @override
  String get themeSettingsPageUseDynamicColorSubtitle =>
      'Sistem paletiyle eşleştir (Android 12+)';

  @override
  String get themeSettingsPageUsePureBackgroundTitle => 'Saf Arka Plan';

  @override
  String get themeSettingsPageUsePureBackgroundSubtitle =>
      'Balonlar ve vurgular temayı izler.';

  @override
  String get themeAdvancedSettingsPageTitle => 'Gelişmiş Tema';

  @override
  String get themeAdvancedSettingsPageUseLayeredSurfacesTitle =>
      'Katmanlı yüzeyler (deneysel)';

  @override
  String get themeAdvancedSettingsPageUseLayeredSurfacesSubtitle =>
      'Daha koyu sayfa, daha parlak kartlar; ikisi de tema tonunu korur. Önceki görünüme dönmek için kapatın.';

  @override
  String get themeAdvancedSettingsPageUseLayeredSheetTilesTitle =>
      'Katmanlı sayfa döşemeleri';

  @override
  String get themeAdvancedSettingsPageUseLayeredSheetTilesSubtitle =>
      'Varsayılan olarak döşemeler sayfa arka planıyla aynı renktedir.';

  @override
  String get themeSettingsPageColorPalettesSection => 'Renk Paletleri';

  @override
  String get themeSettingsPageCustomPaletteName => 'Özel';

  @override
  String get themeSettingsPageCustomColorReset => 'Sıfırla';

  @override
  String get themeSettingsPageCustomThemesSection => 'Özel Temalar';

  @override
  String get customThemeNewTheme => 'Yeni Tema';

  @override
  String get customThemeEditTheme => 'Temayı Düzenle';

  @override
  String get customThemeImportTheme => 'Tema İçe Aktar';

  @override
  String get customThemeNameLabel => 'Tema adı';

  @override
  String get customThemePrimaryColor => 'Birincil';

  @override
  String get customThemeSecondaryColor => 'İkincil';

  @override
  String get customThemeTertiaryColor => 'Üçüncül';

  @override
  String get customThemeColorAuto => 'Otomatik';

  @override
  String get customThemeSave => 'Kaydet';

  @override
  String get customThemeCancel => 'İptal';

  @override
  String get customThemeDelete => 'Sil';

  @override
  String get customThemeDeleteConfirm => 'Bu tema silinsin mi?';

  @override
  String get customThemeCopied => 'Tema JSON\'u panoya kopyalandı';

  @override
  String get customThemeCopyAction => 'Kopyala';

  @override
  String get customThemeImportHint => 'Tema JSON\'unu buraya yapıştırın';

  @override
  String get customThemeImportInvalid => 'Geçersiz tema JSON\'u';

  @override
  String get customThemeHexLabel => 'Hex';

  @override
  String get ttsServicesPageBackButton => 'Geri';

  @override
  String get ttsServicesPageTitle => 'Ses Hizmetleri';

  @override
  String get ttsServicesSectionTitle => 'Metinden Sese';

  @override
  String get ttsServicesPageSettingsTooltip => 'TTS ayarları';

  @override
  String get ttsServicesPageAddTooltip => 'Ekle';

  @override
  String get asrServicesSectionTitle => 'Konuşma Tanıma';

  @override
  String get asrServicesSectionDescription =>
      'Cihaz üzerinde, sistem veya bulut hizmetiyle konuşmayı metne dönüştürün.';

  @override
  String get asrServicesAddTooltip => 'Konuşma tanıma hizmeti ekle';

  @override
  String get asrServicesEmptyTitle => 'Konuşma tanıma hizmeti yok';

  @override
  String get asrServicesEmptySubtitle =>
      'Sohbet girişinde mikrofonu göstermek için bir tane ekleyin.';

  @override
  String get asrServicesOnDeviceGroup => 'Cihaz üzerinde';

  @override
  String get asrServicesCloudGroup => 'Bulut';

  @override
  String get asrServicesSystemTitle => 'Sistem';

  @override
  String get asrServicesSystemSubtitle =>
      'Cihazın yerleşik tanıyıcısını kullanır';

  @override
  String get asrServicesLocalTitle => 'Çevrimdışı Model';

  @override
  String get asrServicesLocalSubtitle =>
      'İndirdikten sonra bu cihazda çevrimdışı çalışır';

  @override
  String get asrServicesOpenAiTitle => 'OpenAI Realtime';

  @override
  String get asrServicesOpenAiSubtitle =>
      'Düşük gecikmeli akışlı transkripsiyon';

  @override
  String get asrServicesGroqSubtitle => 'Whisper segmentli transkripsiyon';

  @override
  String get asrServicesMistralSubtitle => 'Voxtral segmentli transkripsiyon';

  @override
  String get asrServicesElevenLabsSubtitle => 'Scribe segmentli transkripsiyon';

  @override
  String get asrServicesDashScopeTitle => 'DashScope';

  @override
  String get asrServicesDashScopeSubtitle =>
      'Qwen gerçek zamanlı transkripsiyon';

  @override
  String get asrServicesVolcengineTitle => 'Volcengine';

  @override
  String get asrServicesVolcengineSubtitle => 'Doubao akışlı transkripsiyon';

  @override
  String get asrServicesMimoTitle => 'MiMo';

  @override
  String get asrServicesMimoSubtitle => 'Segmentli bulut transkripsiyonu';

  @override
  String get asrServicesStepTitle => 'Step';

  @override
  String get asrServicesStepSubtitle =>
      'Step Audio segmentli bulut transkripsiyonu';

  @override
  String get asrServicesAddTitle => 'Konuşma Tanıma Ekle';

  @override
  String get asrServicesEditTitle => 'Konuşma Tanımayı Düzenle';

  @override
  String get asrServicesSelectedLabel => 'Seçili';

  @override
  String get asrServicesUnavailableLabel => 'Kullanılamıyor';

  @override
  String get asrServicesEditAction => 'Düzenle';

  @override
  String get asrServicesDeleteAction => 'Sil';

  @override
  String get asrServicesCancelAction => 'İptal';

  @override
  String get asrServicesAddAction => 'Ekle';

  @override
  String get asrServicesSaveAction => 'Kaydet';

  @override
  String get asrServicesNameLabel => 'Ad';

  @override
  String get asrServicesApiKeyLabel => 'API Key';

  @override
  String get asrServicesEndpointLabel => 'Uç nokta';

  @override
  String get asrServicesRecognitionModeLabel => 'Tanıma modu';

  @override
  String get asrServicesRealtimeMode => 'Gerçek zamanlı';

  @override
  String get asrServicesRecordedMode => 'Kayıtlı ses';

  @override
  String get asrServicesQwenAudioSubtitle =>
      'Gerçek zamanlı veya kayıtlı ses transkripsiyonu';

  @override
  String get asrServicesQwenTokenPlanHint =>
      'Token Plan kullanıyorsanız Kayıtlı ses seçeneğini seçin, Çalışma Alanı ID alanına token-plan yazın ve anahtarınıza karşılık gelen bölgeyi seçin.';

  @override
  String get asrServicesWorkspaceIdHint => 'örn. token-plan';

  @override
  String get asrServicesEndpointOverrideLabel => 'Özel uç nokta (isteğe bağlı)';

  @override
  String get asrServicesWorkspaceIdInvalid =>
      'Bir çalışma alanı ID\'si girin, URL değil.';

  @override
  String get asrServicesWebSocketEndpointInvalid =>
      'Kimlik bilgileri veya parça içermeyen eksiksiz bir ws:// veya wss:// uç noktası girin.';

  @override
  String get asrServicesHttpEndpointInvalid =>
      'Kimlik bilgileri veya parça içermeyen eksiksiz bir http:// veya https:// uç noktası girin.';

  @override
  String get asrServicesModelLabel => 'Model';

  @override
  String get asrServicesResourceIdLabel => 'Kaynak ID';

  @override
  String get asrServicesLanguageLabel => 'Dil';

  @override
  String get asrServicesAutomaticLabel => 'Otomatik';

  @override
  String get asrServicesApiKeyRequired =>
      'Bu hizmeti kullanmak için bir API anahtarı girin.';

  @override
  String get asrServicesChooseModelTitle => 'Model';

  @override
  String get asrServicesModelDownloadAction => 'İndir';

  @override
  String get asrServicesModelUseAction => 'Modeli kullan';

  @override
  String get asrServicesModelDeleteAction => 'İndirmeyi kaldır';

  @override
  String get asrServicesModelDownloadedLabel => 'İndirildi';

  @override
  String get asrServicesModelDownloadingLabel => 'İndiriliyor…';

  @override
  String get asrServicesModelNotDownloadedLabel => 'İndirilmedi';

  @override
  String asrServicesDownloadFailed(String error) {
    return 'Model indirilemedi: $error';
  }

  @override
  String get asrServicesSystemChecking => 'Kontrol ediliyor…';

  @override
  String get asrServicesSystemAvailable => 'Kullanılabilir';

  @override
  String get asrServicesSystemCheckFailed =>
      'Bu cihazda sistem konuşma tanıma kullanılamıyor.';

  @override
  String get asrServicesMicrophonePermissionDenied =>
      'Mikrofon izni verilmedi.';

  @override
  String get asrServicesNoSpeechDetected => 'Konuşma algılanmadı.';

  @override
  String asrServicesRecognitionFailed(String error) {
    return 'Konuşma tanıma başarısız oldu: $error';
  }

  @override
  String get ttsServicesPageAddNotImplemented =>
      'TTS hizmeti ekleme henüz uygulanmadı';

  @override
  String get ttsServicesPageSystemTtsTitle => 'Sistem TTS';

  @override
  String get ttsServicesPageSystemTtsAvailableSubtitle =>
      'Sistemin yerleşik TTS\'ini kullan';

  @override
  String ttsServicesPageSystemTtsUnavailableSubtitle(String error) {
    return 'Kullanılamıyor: $error';
  }

  @override
  String get ttsServicesPageSystemTtsUnavailableNotInitialized =>
      'başlatılmadı';

  @override
  String get ttsServicesPageTestSpeechText =>
      'Merhaba, bu bir test konuşmasıdır.';

  @override
  String get ttsServicesPageConfigureTooltip => 'Yapılandır';

  @override
  String get ttsServicesPageTestVoiceTooltip => 'Sesi test et';

  @override
  String get ttsServicesPageStopTooltip => 'Durdur';

  @override
  String get ttsServicesPageDeleteTooltip => 'Sil';

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
  String get ttsServicesPagePitchLabel => 'Perde';

  @override
  String get ttsServicesPageSettingsSavedMessage => 'Ayarlar kaydedildi.';

  @override
  String get ttsServicesPageDoneButton => 'Bitti';

  @override
  String get ttsServicesPageNetworkSectionTitle => 'Ağ TTS';

  @override
  String get ttsServicesPageNoNetworkServices => 'TTS hizmeti yok.';

  @override
  String get ttsServicesDialogAddTitle => 'TTS Hizmeti Ekle';

  @override
  String get ttsServicesDialogEditTitle => 'TTS Hizmetini Düzenle';

  @override
  String get ttsServicesDialogProviderType => 'Sağlayıcı';

  @override
  String get ttsServicesDialogCancelButton => 'İptal';

  @override
  String get ttsServicesDialogAddButton => 'Ekle';

  @override
  String get ttsServicesDialogSaveButton => 'Kaydet';

  @override
  String get ttsServicesFieldNameLabel => 'Ad';

  @override
  String get ttsServicesFieldApiKeyLabel => 'API Anahtarı';

  @override
  String get ttsServicesFieldBaseUrlLabel => 'API Temel URL\'si';

  @override
  String get ttsServicesFieldModelLabel => 'Model';

  @override
  String get ttsServicesFieldVoiceLabel => 'Ses';

  @override
  String get ttsServicesFieldVoiceIdLabel => 'Ses Kimliği';

  @override
  String get ttsServicesFieldEmotionLabel => 'Duygu';

  @override
  String get ttsServicesFieldSpeedLabel => 'Hız';

  @override
  String get ttsServicesFieldLanguageTypeLabel => 'Dil türü';

  @override
  String get ttsServicesFieldLanguageLabel => 'Dil';

  @override
  String get ttsServicesFieldWorkspaceIdLabel => 'Çalışma Alanı Kimliği';

  @override
  String get ttsServicesFieldRegionLabel => 'Bölge';

  @override
  String get ttsServicesFieldFormatLabel => 'Ses formatı';

  @override
  String get ttsServicesFieldOutputFormatLabel => 'Çıktı formatı';

  @override
  String get ttsServicesFieldSampleRateLabel => 'Örnekleme hızı';

  @override
  String get ttsServicesFieldVolumeLabel => 'Ses düzeyi';

  @override
  String get ttsServicesFieldPitchLabel => 'Perde';

  @override
  String get ttsServicesFieldLanguageBoostLabel => 'Dil güçlendirme';

  @override
  String get ttsServicesFieldBitrateLabel => 'Bit hızı';

  @override
  String get ttsServicesFieldChannelLabel => 'Kanallar';

  @override
  String get ttsServicesFieldSubtitlesLabel => 'Altyazı oluştur';

  @override
  String get ttsServicesFieldPronunciationDictionaryLabel =>
      'Telaffuz sözlüğü (her satırda bir giriş)';

  @override
  String get ttsServicesFieldInstructionLabel => 'Stil / ses açıklaması';

  @override
  String get ttsServicesFieldStreamingLabel => 'Akış';

  @override
  String get ttsServicesFieldOptimizeTextPreviewLabel =>
      'Metin önizlemesini iyileştir';

  @override
  String get ttsServicesFieldReferenceAudioLabel =>
      'Referans ses (WAV/MP3 veri URI\'si)';

  @override
  String get ttsServicesFieldChooseReferenceAudioButton => 'Referans ses seç';

  @override
  String get ttsServicesFieldTemperatureLabel => 'Sıcaklık';

  @override
  String get ttsServicesFieldTopPLabel => 'Top P';

  @override
  String get ttsServicesFieldLatencyLabel => 'Gecikme';

  @override
  String get ttsServicesEmotionAutoLabel => 'Otomatik eşleştir';

  @override
  String get ttsServicesValidationApiKeyRequired => 'API Anahtarı gerekli';

  @override
  String get ttsServicesValidationReferenceIdRequired =>
      'Ses/referans kimliği gerekli';

  @override
  String get ttsServicesValidationInstructionRequired =>
      'Ses açıklaması gerekli';

  @override
  String ttsServicesValidationSampleRate(String format, String rates) {
    return '$format için $rates Hz gerekir.';
  }

  @override
  String get ttsServicesViewDetailsButton => 'Ayrıntıları görüntüle';

  @override
  String get ttsServicesDialogErrorTitle => 'Hata Ayrıntıları';

  @override
  String get ttsServicesCloseButton => 'Kapat';

  @override
  String get ttsSettingsPageTitle => 'TTS Ayarları';

  @override
  String get ttsSettingsPlaybackSection => 'Oynatma';

  @override
  String get ttsSettingsAutoPlayTitle => 'Asistan Yanıtlarını Otomatik Oynat';

  @override
  String get ttsSettingsAutoPlayDescription =>
      'Asistan yanıtı tamamlandıktan sonra TTS otomatik olarak başlar.';

  @override
  String get ttsSettingsCacheReplayTitle =>
      'Tekrar Oynatmada Ses Önbelleğini Kullan';

  @override
  String get ttsSettingsCacheReplayDescription =>
      'Oluşturulmuş ağ sesini TTS hizmetine yeniden istek göndermeden tekrar oynat.';

  @override
  String get ttsSettingsTextSelectionSection => 'Metin Seçimi';

  @override
  String get ttsSettingsTextSelectionFallbackDescription =>
      'Eşleşen metin bulunamazsa yanıtın tamamı oynatılır.';

  @override
  String get ttsSettingsTextSelectionFullTextTitle => 'Tam metin';

  @override
  String get ttsSettingsTextSelectionFullTextDescription =>
      'Asistan yanıtının tamamını oynat.';

  @override
  String get ttsSettingsTextSelectionQuotedOnlyTitle =>
      'Yalnızca tırnak içindeki metin';

  @override
  String get ttsSettingsTextSelectionQuotedOnlyDescription =>
      '“”, ‘’, \"\", \'\', 「」 veya 『』 içindeki metni oynat.';

  @override
  String get ttsSettingsTextSelectionOutsideParenthesesTitle =>
      'Parantez dışındaki metin';

  @override
  String get ttsSettingsTextSelectionOutsideParenthesesDescription =>
      '() ve （） içindeki metni atla.';

  @override
  String get ttsSettingsTextSelectionItalicOnlyTitle => 'Yalnızca italik metin';

  @override
  String get ttsSettingsTextSelectionItalicOnlyDescription =>
      'Markdown veya HTML italik metnini oynat.';

  @override
  String get ttsSettingsTextSelectionNonItalicTitle =>
      'Yalnızca italik olmayan metin';

  @override
  String get ttsSettingsTextSelectionNonItalicDescription =>
      'Markdown veya HTML italik metnini atla.';

  @override
  String get ttsFloatingPlayerLabel => 'TTS oynatıcı';

  @override
  String get ttsFloatingPauseTooltip => 'Duraklat';

  @override
  String get ttsFloatingResumeTooltip => 'Devam et';

  @override
  String get ttsFloatingReplayTooltip => 'Tekrar oynat';

  @override
  String get ttsFloatingRewind15Tooltip => '15 saniye geri';

  @override
  String get ttsFloatingForward15Tooltip => '15 saniye ileri';

  @override
  String get ttsFloatingSpeedTooltip => 'Oynatma hızı';

  @override
  String get ttsFloatingCloseTooltip => 'Oynatıcıyı kapat';

  @override
  String get ttsFloatingExpandTooltip => 'Oynatma kontrollerini genişlet';

  @override
  String get ttsFloatingCollapseTooltip => 'Oynatma kontrollerini daralt';

  @override
  String get ttsFloatingSaveTooltip => 'Sesi kaydet';

  @override
  String get ttsSaveDialogTitle => 'TTS sesini kaydet';

  @override
  String get ttsSaveSuccess => 'Ses başarıyla kaydedildi.';

  @override
  String get ttsSaveNothing => 'Kaydedilecek ses yok.';

  @override
  String ttsSaveFailed(String message) {
    return 'Ses kaydedilemedi: $message';
  }

  @override
  String imageViewerPageShareFailedOpenFile(String message) {
    return 'Paylaşılamadı, dosya açılmaya çalışıldı: $message';
  }

  @override
  String imageViewerPageShareFailed(String error) {
    return 'Paylaşım başarısız: $error';
  }

  @override
  String get imageViewerPageShareButton => 'Görseli Paylaş';

  @override
  String get imageViewerPageCloseButton => 'Önizlemeyi kapat';

  @override
  String get imageViewerPageSaveButton => 'Görseli Kaydet';

  @override
  String get imageViewerPageCopyButton => 'Görseli Kopyala';

  @override
  String get imageViewerPagePreviousButton => 'Önceki Görsel';

  @override
  String get imageViewerPageNextButton => 'Sonraki Görsel';

  @override
  String get imageViewerPageZoomInButton => 'Yakınlaştır';

  @override
  String get imageViewerPageZoomOutButton => 'Uzaklaştır';

  @override
  String get imageViewerPageResetZoomButton => 'Yakınlaştırmayı Sıfırla';

  @override
  String get imageViewerPageFlipHorizontalButton => 'Yatay Çevir';

  @override
  String get imageViewerPageFlipVerticalButton => 'Dikey Çevir';

  @override
  String get imageViewerPageRotateLeftButton => 'Sola Döndür';

  @override
  String get imageViewerPageRotateRightButton => 'Sağa Döndür';

  @override
  String imageViewerPageCounter(int index, int total) {
    return '$index/$total';
  }

  @override
  String imageViewerPageImageLabel(int index, int total) {
    return 'Görsel $index/$total';
  }

  @override
  String get imageViewerPageImageLoadFailed => 'Görsel yüklenemedi';

  @override
  String get imageViewerPageSaveSuccess => 'Galeriye kaydedildi';

  @override
  String imageViewerPageSaveFailed(String error) {
    return 'Kaydetme başarısız: $error';
  }

  @override
  String get settingsShare => 'Kelivo - Açık Kaynak AI Asistanı';

  @override
  String get searchProviderBingLocalDescription =>
      'Bing sonuçlarını almak için web kazıma kullanır. API anahtarı gerekmez; kararsız olabilir.';

  @override
  String get searchProviderDuckDuckGoDescription =>
      'DDGS üzerinden gizlilik odaklı DuckDuckGo araması. API anahtarı gerekmez; bölge seçimini destekler.';

  @override
  String get searchProviderBraveDescription =>
      'Brave\'in bağımsız arama motoru. İzleme veya profilleme olmadan gizlilik odaklı.';

  @override
  String get searchProviderExaDescription =>
      'Anlamsal anlayışa sahip sinirsel arama. Araştırma ve belirli içerik bulma için idealdir.';

  @override
  String get searchProviderExaMcpDescription =>
      'MCP üzerinden Exa araması. Sınırlı ücretsiz kullanım için API anahtarı isteğe bağlıdır.';

  @override
  String get searchProviderLinkUpDescription =>
      'Kaynaklı yanıtlar sunan arama API\'si. Hem sonuçları hem de AI tarafından oluşturulan özetleri sağlar.';

  @override
  String get searchProviderMetasoDescription =>
      'Metaso tarafından Çince arama. AI yetenekleriyle Çince içerik için optimize edilmiştir.';

  @override
  String get searchProviderSearXNGDescription =>
      'Gizliliğe saygılı meta arama motoru. Kendi barındırdığınız bir örnek gerekir; izleme yok.';

  @override
  String get searchProviderTavilyDescription =>
      'LLM\'ler için optimize edilmiş AI arama API\'si. Yüksek kaliteli, ilgili sonuçlar sağlar.';

  @override
  String get searchProviderZhipuDescription =>
      'Zhipu AI tarafından Çince AI araması. Çince içerik ve sorgular için optimize edilmiştir.';

  @override
  String get searchProviderOllamaDescription =>
      'Ollama web arama API\'si. Modelleri güncel bilgilerle zenginleştirir.';

  @override
  String get searchProviderDeepSeekDescription =>
      'DeepSeek resmi web arama ve sayfa getirme API\'leri. Bir DeepSeek API anahtarı kullanır.';

  @override
  String get searchProviderJinaDescription =>
      'Gömme, yeniden sıralayıcı, web okuyucu, derin arama ve küçük dil modelleri içeren AI arama altyapısı. Çok dilli ve çok modlu.';

  @override
  String get searchServiceNameBingLocal => 'Bing (Yerel)';

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
      'Perplexity Arama API\'si. Bölge ve alan adı filtreleriyle sıralanmış web sonuçları.';

  @override
  String get searchServiceNameBocha => 'Bocha';

  @override
  String get searchProviderBochaDescription =>
      'Bocha web arama API\'si. İsteğe bağlı özetlerle doğru web sonuçları.';

  @override
  String get searchServiceNameDoubao => 'Doubao';

  @override
  String get searchProviderDoubaoDescription =>
      'Volcano Engine tarafından sunulan Doubao web arama API\'si.';

  @override
  String get searchServiceNameSerper => 'Serper';

  @override
  String get searchProviderSerperDescription =>
      'Serper Google Arama API\'si. İsteğe bağlı ülke, dil, zaman ve sayfa filtreleriyle hızlı web sonuçları.';

  @override
  String get searchServiceNameQuerit => 'Querit';

  @override
  String get searchProviderQueritDescription =>
      'LLM uygulamaları için Querit Arama API\'si. Site, zaman, ülke ve dil filtreleriyle gerçek zamanlı web sonuçları döndürür.';

  @override
  String get searchServiceNameGrok => 'Grok';

  @override
  String get searchProviderGrokDescription =>
      'xAI Responses API\'si üzerinden Grok arama. Web ve X arama araçlarını kullanır ve kaynak atıflarıyla sonuç döndürür.';

  @override
  String get searchServiceNameStepFun => 'StepFun';

  @override
  String get searchProviderStepFunDescription =>
      'POST /v1/search üzerinden StepFun web araması.';

  @override
  String get searchServiceNameFirecrawl => 'Firecrawl';

  @override
  String get searchProviderFirecrawlDescription =>
      'Firecrawl Search API v2. API anahtarı isteğe bağlıdır. Scrape burada desteklenmez.';

  @override
  String get searchServiceNameTinyFish => 'TinyFish';

  @override
  String get searchProviderTinyFishDescription =>
      'Bölge/dil filtreleriyle TinyFish Arama API\'si. API anahtarı gereklidir. Fetch/Scrape burada desteklenmez.';

  @override
  String get searchServiceNameAnySearch => 'AnySearch';

  @override
  String get searchProviderAnySearchDescription =>
      'Web ve uzman veri kaynakları arasında otomatik yönlendirme yapan, AI ajanları için birleşik arama. API anahtarı isteğe bağlıdır.';

  @override
  String get searchServiceNameKagi => 'Kagi';

  @override
  String get searchProviderKagiDescription =>
      'Kagi Arama API\'si. Kagi\'den premium web arama sonuçları döndürür.';

  @override
  String get searchServiceNameKimi => 'Kimi';

  @override
  String get searchProviderKimiDescription =>
      'Kimi Arama API\'si. Pro ilgili web içeriği alıntıları döndürür; Basic başlık, bağlantı ve snippet döndürür.';

  @override
  String get searchServiceNameParallel => 'Parallel';

  @override
  String get searchProviderParallelDescription =>
      'Parallel Arama API\'si. turbo, fast, basic ve advanced modlarıyla LLM için optimize edilmiş web alıntıları döndürür.';

  @override
  String get searchServicesDialogSearchMode => 'Arama modu';

  @override
  String get searchServiceNameYou => 'You.com';

  @override
  String get searchProviderYouDescription =>
      'You.com Arama API\'si. Highlights veya Snippets ile web ve haber sonuçları döndürür.';

  @override
  String get searchServicesDialogContentMode => 'İçerik modu';

  @override
  String get searchServicesDialogHighlights => 'Highlights';

  @override
  String get searchServicesDialogSnippets => 'Snippets';

  @override
  String get searchServicesDialogWebSearch => 'Web Arama';

  @override
  String get searchServicesDialogLlmContext => 'LLM Bağlamı';

  @override
  String get searchServicesDialogMaximumTokens => 'Maksimum token';

  @override
  String get searchServicesDialogMaximumTokensInvalid =>
      'Maksimum token 1024 ile 32768 arasında olmalıdır.';

  @override
  String get searchServiceNameKelivo => 'Kelivo';

  @override
  String get searchServicesDialogCountryOptional => 'Ülke/bölge (isteğe bağlı)';

  @override
  String get searchServicesDialogLanguageOptional => 'Dil (isteğe bağlı)';

  @override
  String get searchServicesDialogTimeFilterOptional =>
      'Zaman filtresi (isteğe bağlı)';

  @override
  String get searchServicesDialogPageOptional => 'Sayfa (isteğe bağlı)';

  @override
  String get searchServicesDialogPageInvalid =>
      'Sayfa pozitif bir tam sayı olmalıdır.';

  @override
  String get searchServicesDialogSitesIncludeOptional =>
      'Dahil edilecek siteler (isteğe bağlı)';

  @override
  String get searchServicesDialogSitesExcludeOptional =>
      'Hariç tutulacak siteler (isteğe bağlı)';

  @override
  String get searchServicesDialogTimeRangeOptional =>
      'Zaman aralığı (isteğe bağlı)';

  @override
  String get searchServicesDialogCountriesOptional => 'Ülkeler (isteğe bağlı)';

  @override
  String get searchServicesDialogLanguagesOptional => 'Diller (isteğe bağlı)';

  @override
  String get searchServicesDialogSitesHint => 'example.com, docs.example.com';

  @override
  String get searchServicesDialogTimeRangeHint => 'd7';

  @override
  String get searchServicesDialogCountriesHint => 'united states, japan';

  @override
  String get searchServicesDialogLanguagesHint => 'english, japanese';

  @override
  String get generationInterrupted => 'Üretim kesildi';

  @override
  String get titleForLocale => 'Yeni Sohbet';

  @override
  String get temporaryChatTitle => 'Geçici Sohbet';

  @override
  String get temporaryChatEmptyMessage =>
      'Geçici sohbetler geçmişte görünmez ve ayrıldıktan sonra tamamen silinir.';

  @override
  String get temporaryChatToggleTooltip => 'Geçici sohbeti aç/kapat';

  @override
  String get quickPhraseBackTooltip => 'Geri';

  @override
  String get quickPhraseGlobalTitle => 'Hızlı İfade';

  @override
  String get quickPhraseAssistantTitle => 'Asistan Hızlı İfadesi';

  @override
  String get quickPhraseAddTooltip => 'Hızlı İfade Ekle';

  @override
  String get quickPhraseEmptyMessage => 'Henüz hızlı ifade yok';

  @override
  String get quickPhraseAddTitle => 'Hızlı İfade Ekle';

  @override
  String get quickPhraseEditTitle => 'Hızlı İfadeyi Düzenle';

  @override
  String get quickPhraseTitleLabel => 'Başlık';

  @override
  String get quickPhraseContentLabel => 'İçerik';

  @override
  String get quickPhraseCancelButton => 'İptal';

  @override
  String get quickPhraseSaveButton => 'Kaydet';

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
      'Henüz talimat enjeksiyon kartı yok';

  @override
  String get instructionInjectionDefaultTitle => 'Öğrenme Modu';

  @override
  String get instructionInjectionAddTitle => 'Talimat Enjeksiyonu Ekle';

  @override
  String get instructionInjectionEditTitle => 'Talimat Enjeksiyonunu Düzenle';

  @override
  String get instructionInjectionNameLabel => 'Ad';

  @override
  String get instructionInjectionPromptLabel => 'İstem';

  @override
  String get instructionInjectionUngroupedGroup => 'Gruplanmamış';

  @override
  String get instructionInjectionGroupLabel => 'Grup';

  @override
  String get instructionInjectionGroupHint => 'İsteğe bağlı';

  @override
  String instructionInjectionImportSuccess(int count) {
    return '$count talimat içe aktarıldı';
  }

  @override
  String get instructionInjectionSheetSubtitle =>
      'Sohbet etmeden önce uygulanacak bir istem seçin';

  @override
  String get mcpJsonEditButtonTooltip => 'JSON\'u düzenle';

  @override
  String get mcpJsonEditTitle => 'JSON\'u düzenle';

  @override
  String get mcpJsonEditParseFailed => 'JSON ayrıştırma başarısız';

  @override
  String get mcpJsonEditSavedApplied => 'Kaydedildi ve uygulandı';

  @override
  String get mcpTimeoutSettingsTooltip => 'Araç çağrısı zaman aşımını ayarla';

  @override
  String get mcpTimeoutDialogTitle => 'Araç çağrısı zaman aşımı';

  @override
  String get mcpTimeoutSecondsLabel => 'Araç çağrısı zaman aşımı (saniye)';

  @override
  String get mcpTimeoutInvalid => 'Pozitif bir saniye değeri girin';

  @override
  String get quickPhraseEditButton => 'Düzenle';

  @override
  String get quickPhraseDeleteButton => 'Sil';

  @override
  String get quickPhraseMenuTitle => 'Hızlı İfade';

  @override
  String get chatInputBarQuickPhraseTooltip => 'Hızlı İfade';

  @override
  String get assistantEditQuickPhraseDescription =>
      'Bu asistan için hızlı ifadeleri yönetin. İfade eklemek için aşağıdaki düğmeye tıklayın.';

  @override
  String get assistantEditManageQuickPhraseButton => 'Hızlı İfadeleri Yönet';

  @override
  String get assistantEditPageMemoryTab => 'Hafıza';

  @override
  String get assistantEditLocalToolTimeInfoTitle => 'Zaman Bilgisi';

  @override
  String get assistantEditLocalToolTimeInfoSubtitle =>
      'Cihazın tarihini, haftanın gününü, saatini, saat dilimini, UTC farkını ve zaman damgasını okur.';

  @override
  String get assistantEditLocalToolClipboardTitle => 'Pano';

  @override
  String get assistantEditLocalToolClipboardSubtitle =>
      'Açıkça gerektiğinde cihaz panosundan düz metin okur veya yazar.';

  @override
  String get assistantEditLocalToolTextToSpeechTitle => 'Metin Okuma';

  @override
  String get assistantEditLocalToolTextToSpeechSubtitle =>
      'Asistanın yapılandırılmış TTS oynatımıyla metni sesli okumasını sağlar.';

  @override
  String get assistantEditLocalToolAskUserTitle => 'Kullanıcıya Sor';

  @override
  String get assistantEditLocalToolAskUserSubtitle =>
      'Asistanın kısa sorular sormasını ve yanıtınızdan sonra devam etmesini sağlar.';

  @override
  String get assistantEditLocalToolCalculateTitle => 'Hesap Makinesi';

  @override
  String get assistantEditLocalToolCalculateSubtitle =>
      'Matematiksel ifadeleri hesaplar; + - * / kuvvet sqrt sin cos vb. destekler.';

  @override
  String get assistantEditLocalToolScreenTimeTitle => 'Ekran Süresi';

  @override
  String get assistantEditLocalToolScreenTimeSubtitle =>
      'Bu cihazdaki uygulama ekran kullanımını sorgular, Kullanım erişimi izni gerektirir.';

  @override
  String get chatMessageWidgetScreenTimeTotal => 'Toplam ekran süresi';

  @override
  String get chatMessageWidgetScreenTimePermissionRequired =>
      'Kullanım erişimi izni verilmedi. Lütfen sistem ayarlarından etkinleştirip tekrar deneyin.';

  @override
  String get assistantEditLocalToolCalendarQueryTitle => 'Takvimi Sorgula';

  @override
  String get assistantEditLocalToolCalendarQuerySubtitle =>
      'Bu cihazdaki takvim etkinliklerini okur, takvim izni gerektirir.';

  @override
  String get assistantEditLocalToolCalendarCreateTitle => 'Etkinlik Oluştur';

  @override
  String get assistantEditLocalToolCalendarCreateSubtitle =>
      'Onayınızla bu cihazda takvim etkinlikleri oluşturur, takvim izni gerektirir.';

  @override
  String get assistantEditLocalToolLocationTitle => 'Mevcut Konum';

  @override
  String get assistantEditLocalToolLocationSubtitle =>
      'Bu cihazdan tek seferlik konum okur, konum izni gerektirir.';

  @override
  String get assistantEditLocalToolWeatherTitle => 'Hava Durumu';

  @override
  String get assistantEditLocalToolWeatherSubtitle =>
      'Mevcut veya belirtilen konum için Apple Hava Durumu\'nu alır. Sonuçta WeatherKit atfı gösterilir.';

  @override
  String get assistantEditLocalToolHealthTitle => 'Sağlık Özeti';

  @override
  String get assistantEditLocalToolHealthSubtitle =>
      'Apple Health\'ten gizliliği koruyan bir etkinlik özeti okur, Health erişimi gerektirir.';

  @override
  String assistantEditLocalToolHealthSelectedCount(int selected, int total) {
    return '$selected/$total seçili';
  }

  @override
  String get healthDataSettingsTitle => 'Sağlık Verileri';

  @override
  String get healthDataSettingsDescription =>
      'Geçerli asistanın günlük sohbette kullanabileceği HealthKit sinyalleri. Anahtarlar Kelivo\'nun hangi aralığı okumayı deneyebileceğini belirler; gerçek Health erişimini yine iOS yönetir.';

  @override
  String healthDataSettingsBadge(int selected, int total) {
    return '$selected/$total açık';
  }

  @override
  String get healthDataSettingsIosReadTitle => 'iOS Health Okuma';

  @override
  String get healthDataSettingsIosReadSubtitle =>
      'Cihaz kullanılabilir, okuma aralığı iOS tarafından yönetilir';

  @override
  String get healthDataSettingsOpenSystemSettings => 'Sistem ayarlarını aç';

  @override
  String get healthDataSettingsEnableAll => 'Tümünü aç';

  @override
  String get healthDataSettingsDisableAll => 'Tümünü kapat';

  @override
  String get healthDataSettingsCategoryActivity => 'Etkinlik';

  @override
  String get healthDataSettingsCategoryRest => 'Dinlenme';

  @override
  String get healthDataSettingsCategoryHeart => 'Kalp';

  @override
  String get healthDataSettingsCategoryBody => 'Vücut';

  @override
  String get healthDataSettingsTypeStepsTitle => 'Adımlar';

  @override
  String get healthDataSettingsTypeStepsSubtitle => 'Yürüme adımları özeti';

  @override
  String get healthDataSettingsTypeDaylightTitle => 'Gün Işığı';

  @override
  String get healthDataSettingsTypeDaylightSubtitle =>
      'Dış mekân gün ışığı süresi';

  @override
  String get healthDataSettingsTypeActiveEnergyTitle => 'Enerji';

  @override
  String get healthDataSettingsTypeActiveEnergySubtitle =>
      'Yakılan aktif enerji';

  @override
  String get healthDataSettingsTypeExerciseMinutesTitle => 'Egzersiz';

  @override
  String get healthDataSettingsTypeExerciseMinutesSubtitle =>
      'Apple egzersiz dakikaları';

  @override
  String get healthDataSettingsTypeStandTimeTitle => 'Ayakta Durma';

  @override
  String get healthDataSettingsTypeStandTimeSubtitle => 'Ayakta durma süresi';

  @override
  String get healthDataSettingsTypeDistanceTitle => 'Mesafe';

  @override
  String get healthDataSettingsTypeDistanceSubtitle =>
      'Yürüme ve koşma mesafesi';

  @override
  String get healthDataSettingsTypeWorkoutsTitle => 'Antrenmanlar';

  @override
  String get healthDataSettingsTypeWorkoutsSubtitle =>
      'Antrenman kayıtları: tür, süre, mesafe ve enerji';

  @override
  String get healthDataSettingsTypeSleepTitle => 'Uyku';

  @override
  String get healthDataSettingsTypeSleepSubtitle =>
      'Son 24 saat: uyku, yatakta geçirilen süre, uyanık dönemler ve uyku evreleri';

  @override
  String get healthDataSettingsTypeMindfulnessTitle => 'Dinlenme';

  @override
  String get healthDataSettingsTypeMindfulnessSubtitle =>
      'Farkındalık veya dinlenme dönemleri';

  @override
  String get healthDataSettingsTypeHeartRateTitle => 'Kalp Atış Hızı';

  @override
  String get healthDataSettingsTypeHeartRateSubtitle =>
      'En son kalp atış hızı örneği';

  @override
  String get healthDataSettingsTypeRestingHeartRateTitle =>
      'Dinlenme Kalp Atış Hızı';

  @override
  String get healthDataSettingsTypeRestingHeartRateSubtitle =>
      'Dinlenme kalp atış hızı örneği';

  @override
  String get healthDataSettingsTypeBloodOxygenTitle => 'Kan Oksijeni';

  @override
  String get healthDataSettingsTypeBloodOxygenSubtitle =>
      'Kan oksijen doygunluğu';

  @override
  String get healthDataSettingsTypeDietaryEnergyTitle => 'Diyet Enerjisi';

  @override
  String get healthDataSettingsTypeDietaryEnergySubtitle =>
      'Diyet kalori kaydı';

  @override
  String get healthDataSettingsTypeWaterTitle => 'Su';

  @override
  String get healthDataSettingsTypeWaterSubtitle => 'Su alımı kaydı';

  @override
  String get healthDataSettingsTypeWeightTitle => 'Kilo';

  @override
  String get healthDataSettingsTypeWeightSubtitle => 'Vücut ağırlığı örneği';

  @override
  String get healthDataSettingsTypeBmiTitle => 'BMI';

  @override
  String get healthDataSettingsTypeBmiSubtitle => 'Vücut kitle indeksi';

  @override
  String get healthDataSettingsTypeBloodGlucoseTitle => 'Kan Şekeri';

  @override
  String get healthDataSettingsTypeBloodGlucoseSubtitle => 'Kan şekeri örneği';

  @override
  String get assistantEditLocalToolRemindersQueryTitle =>
      'Anımsatıcıları Sorgula';

  @override
  String get assistantEditLocalToolRemindersQuerySubtitle =>
      'Bu cihazdaki anımsatıcıları okuyun, tam anımsatıcı erişimi gerektirir.';

  @override
  String get assistantEditLocalToolRemindersCreateTitle => 'Anımsatıcı Oluştur';

  @override
  String get assistantEditLocalToolRemindersCreateSubtitle =>
      'Onayınızla bu cihazda bir anımsatıcı oluşturun, tam anımsatıcı erişimi gerektirir.';

  @override
  String get assistantEditLocalToolRemindersCompleteTitle =>
      'Anımsatıcıyı Tamamla';

  @override
  String get assistantEditLocalToolRemindersCompleteSubtitle =>
      'Onayınızla bir anımsatıcıyı tamamlandı olarak işaretleyin, tam anımsatıcı erişimi gerektirir.';

  @override
  String get assistantEditMemorySwitchDescription =>
      'Asistanın sohbetler arasında anılar oluşturmasına ve kullanmasına izin verin.';

  @override
  String get assistantEditRecentChatsSwitchTitle => 'Son Sohbetlere Başvur';

  @override
  String get assistantEditRecentChatsSwitchDescription =>
      'Bağlama yardımcı olmak için son sohbet başlıklarını dahil edin.';

  @override
  String get assistantEditAddMemoryButton => 'Anı Ekle';

  @override
  String get assistantEditMemoryEmpty => 'Henüz anı yok';

  @override
  String get assistantEditMemoryDialogTitle => 'Anı';

  @override
  String get assistantEditMemoryDialogHint => 'Anı içeriğini girin';

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
  String get multiKeyPageDeleteErrorsConfirmTitle =>
      'Tüm hatalı anahtarlar silinsin mi?';

  @override
  String get multiKeyPageDeleteErrorsConfirmContent =>
      'Bu, hata olarak işaretlenmiş tüm anahtarları kaldıracak.';

  @override
  String multiKeyPageDeletedErrorsSnackbar(int n) {
    return '$n hatalı anahtar silindi';
  }

  @override
  String get providerDetailPageProviderTypeTitle => 'Sağlayıcı Türü';

  @override
  String get displaySettingsPageChatItemDisplayTitle => 'Sohbet öğesi görünümü';

  @override
  String get displaySettingsPageRenderingSettingsTitle => 'İşleme ayarları';

  @override
  String get displaySettingsPageBehaviorStartupTitle => 'Davranış ve başlangıç';

  @override
  String get displaySettingsPageHapticsSettingsTitle =>
      'Dokunsal geri bildirim';

  @override
  String get assistantSettingsNoPromptPlaceholder => 'Henüz istem yok';

  @override
  String get providersPageMultiSelectTooltip => 'Çoklu seçim';

  @override
  String get providersPageDeleteSelectedConfirmContent =>
      'Seçili sağlayıcılar silinsin mi? Bu işlem geri alınamaz.';

  @override
  String get providersPageDeleteSelectedSnackbar =>
      'Seçili sağlayıcılar silindi';

  @override
  String providersPageExportSelectedTitle(int count) {
    return '$count sağlayıcıyı dışa aktar';
  }

  @override
  String get providersPageExportCopyButton => 'Kopyala';

  @override
  String get providersPageExportShareButton => 'Paylaş';

  @override
  String get providersPageExportCopiedSnackbar =>
      'Dışa aktarma kodu kopyalandı';

  @override
  String get providersPageDeleteAction => 'Sil';

  @override
  String get providersPageExportAction => 'Dışa aktar';

  @override
  String get assistantEditPresetTitle => 'Ön ayarlı sohbet';

  @override
  String get assistantEditPresetAddUser => 'Kullanıcı ön ayarı ekle';

  @override
  String get assistantEditPresetAddAssistant => 'Asistan ön ayarı ekle';

  @override
  String get assistantEditPresetInputHintUser => 'Kullanıcı mesajı girin…';

  @override
  String get assistantEditPresetInputHintAssistant => 'Asistan mesajı girin…';

  @override
  String get assistantEditPresetEmpty => 'Henüz ön ayarlı mesaj yok';

  @override
  String get assistantEditPresetEditDialogTitle => 'Ön ayarlı mesajı düzenle';

  @override
  String get assistantEditPresetRoleUser => 'Kullanıcı';

  @override
  String get assistantEditPresetRoleAssistant => 'Asistan';

  @override
  String get desktopTtsPleaseAddProvider =>
      'Lütfen önce bir TTS sağlayıcısı ekleyin';

  @override
  String get settingsPageNetworkProxy => 'Ağ Proxy\'si';

  @override
  String get networkProxyEnableLabel => 'Proxy\'yi Etkinleştir';

  @override
  String get networkProxySettingsHeader => 'Proxy Ayarları';

  @override
  String get networkProxyType => 'Proxy Türü';

  @override
  String get networkProxyTypeHttp => 'HTTP';

  @override
  String get networkProxyTypeHttps => 'HTTPS';

  @override
  String get networkProxyTypeSocks5 => 'SOCKS5';

  @override
  String get networkProxyServerHost => 'Sunucu';

  @override
  String get networkProxyPort => 'Bağlantı Noktası';

  @override
  String get networkProxyUsername => 'Kullanıcı Adı';

  @override
  String get networkProxyPassword => 'Parola';

  @override
  String get networkProxyBypassLabel => 'Proxy atlama';

  @override
  String get networkProxyBypassHint =>
      'Virgülle ayrılmış ana bilgisayarlar/CIDR, örn. localhost,127.0.0.1,192.168.0.0/16,*.local';

  @override
  String get networkProxyOptionalHint => 'İsteğe bağlı';

  @override
  String get networkProxyTestHeader => 'Bağlantı Testi';

  @override
  String get networkProxyTestUrlHint => 'Test URL\'si';

  @override
  String get networkProxyTestButton => 'Test Et';

  @override
  String get networkProxyTesting => 'Test ediliyor…';

  @override
  String get networkProxyTestSuccess => 'Bağlantı başarılı';

  @override
  String networkProxyTestFailed(String error) {
    return 'Test başarısız: $error';
  }

  @override
  String get networkProxyNoUrl => 'Lütfen bir URL girin';

  @override
  String get networkProxyPriorityNote =>
      'Hem genel hem de sağlayıcı proxy\'si etkinleştirildiğinde, sağlayıcı düzeyindeki proxy öncelikli olur.';

  @override
  String get settingsPageAutoRetry => 'Otomatik Yeniden Deneme';

  @override
  String get autoRetryEnableLabel => 'Otomatik yeniden denemeyi etkinleştir';

  @override
  String get autoRetryMaxRetries => 'Maksimum yeniden deneme';

  @override
  String get autoRetryInitialDelay => 'İlk gecikme (ms)';

  @override
  String get autoRetryMultiplier => 'Geri çekilme çarpanı';

  @override
  String get autoRetryMaxDelay => 'Maksimum gecikme (ms)';

  @override
  String get autoRetryJitter => 'Titreşim';

  @override
  String get autoRetryJitterSubtitle => 'Her beklemeyi ±%20 rastgeleleştir';

  @override
  String get autoRetryOnNetworkError => 'Ağ hatalarında yeniden dene';

  @override
  String get autoRetryStatusCodes => 'Yeniden deneme durum kodları';

  @override
  String get autoRetryKeywords => 'Yeniden deneme anahtar kelimeleri';

  @override
  String get autoRetryStopKeywords => 'Durdurma anahtar kelimeleri';

  @override
  String get autoRetryAddHint => 'Ekle';

  @override
  String get autoRetryRestoreDefaults => 'Varsayılanları geri yükle';

  @override
  String get autoRetryFooter =>
      'Otomatik yeniden deneme yalnızca geçerli model yanıtı henüz herhangi bir çıktı üretmediyse çalışır.';

  @override
  String autoRetryCountdown(int seconds, int attempt, int maxRetries) {
    return 'Yeniden denemeye $seconds sn ($attempt/$maxRetries)';
  }

  @override
  String get desktopShowProviderInModelCapsule =>
      'Model kapsülünde sağlayıcıyı göster';

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
  String get chatInputBarOcrTooltip => 'Görsel OCR';

  @override
  String get providerDetailPageMultiSelectButton => 'Çoklu seçim';

  @override
  String get providerDetailPageBatchDetectButton => 'Algıla';

  @override
  String get providerDetailPageBatchDetecting => 'Algılanıyor...';

  @override
  String get providerDetailPageBatchDetectStart => 'Algılamayı Başlat';

  @override
  String get providerDetailPageDetectSuccess => 'Algılama başarılı';

  @override
  String get providerDetailPageDetectFailed => 'Algılama başarısız';

  @override
  String get providerDetailPageDeleteSelectedModelsButton => 'Sil';

  @override
  String get providerDetailPageDeleteSelectedModelsTooltip =>
      'Seçili modelleri sil';

  @override
  String providerDetailPageDeleteSelectedModelsConfirm(int count) {
    return 'Seçili $count model silinsin mi? Bu işlem geri alınamaz.';
  }

  @override
  String get providerDetailPageDeleteFailedDetectedModelsButton =>
      'Kullanılamayanları sil';

  @override
  String get providerDetailPageDeleteFailedDetectedModelsTooltip =>
      'Algılamada başarısız olan modelleri sil';

  @override
  String providerDetailPageDeleteFailedDetectedModelsConfirm(int count) {
    return 'Algılamada başarısız olan $count model silinsin mi? Bu işlem geri alınamaz.';
  }

  @override
  String providerDetailPageSelectedModelsDeletedSnackbar(int count) {
    return '$count model silindi';
  }

  @override
  String get providerDetailPageDeleteAllModelsTooltip => 'Tüm modelleri sil';

  @override
  String get providerDetailPageDeleteAllModelsWarning =>
      'Bu işlem geri alınamaz.';

  @override
  String get requestLogSettingTitle => 'İstek Günlüğü';

  @override
  String get requestLogSettingSubtitle =>
      'Etkinleştirildiğinde istek/yanıt ayrıntıları logs/logs.txt dosyasına yazılır (günlük olarak döndürülür).';

  @override
  String get flutterLogSettingTitle => 'Flutter Günlüğü';

  @override
  String get flutterLogSettingSubtitle =>
      'Etkinleştirildiğinde Flutter hataları ve print çıktısı logs/flutter_logs.txt dosyasına yazılır (günlük olarak döndürülür).';

  @override
  String get contextLogSettingTitle => 'Bağlam Günlüğü';

  @override
  String get contextLogSettingSubtitle =>
      'Etkinleştirildiğinde modele gönderilen tam mesajlar logs/context_logs.txt dosyasına yazılır (günlük olarak döndürülür).';

  @override
  String get contextLogViewerTitle => 'Bağlam';

  @override
  String contextLogSnapshotMessages(int count) {
    return '$count mesaj';
  }

  @override
  String contextLogSnapshotTokens(int count) {
    return '$count token';
  }

  @override
  String get contextLogSourceSystemPrompt => 'Sistem istemi';

  @override
  String get contextLogSourceMemoryRules => 'Bellek kuralları';

  @override
  String get contextLogSourceSearchPrompt => 'Arama istemi';

  @override
  String get contextLogSourceInstructionInjection => 'Talimat';

  @override
  String get contextLogSourceWorldBook => 'Dünya kitabı';

  @override
  String get contextLogSourceMemorySnapshot => 'Bellek anlık görüntüsü';

  @override
  String get contextLogSourceChatHistory => 'Sohbet geçmişi';

  @override
  String get contextLogSourceToolCall => 'Araç çağrısı';

  @override
  String get contextLogSourceToolResult => 'Araç sonucu';

  @override
  String get contextLogTokensEstimateHint =>
      'Token sayıları yalnızca tahminidir; gerçek kaynak olarak modelin gerçek kullanımını esas alın.';

  @override
  String contextLogSnapshotsCount(int count) {
    return '$count anlık görüntü';
  }

  @override
  String get contextLogSnapshotFallbackTitle => 'Anlık görüntü';

  @override
  String get contextLogKindFull => 'Tam anlık görüntü';

  @override
  String get contextLogKindUpdate => 'Artımlı güncelleme';

  @override
  String get contextLogSectionComposition => 'Bileşim';

  @override
  String get contextLogLoadOlder => 'Daha eski günlükleri yükle';

  @override
  String get contextLogLoading => 'Yükleniyor...';

  @override
  String get contextLogAllLoaded => 'Tüm günlükler yüklendi';

  @override
  String get logViewerTitle => 'İstek Günlükleri';

  @override
  String get logViewerEmpty => 'Henüz günlük yok';

  @override
  String get logViewerCurrentLog => 'Geçerli Günlük';

  @override
  String get logViewerExport => 'Dışa aktar';

  @override
  String get logViewerOpenFolder => 'Günlük Klasörünü Aç';

  @override
  String logViewerRequestsCount(int count) {
    return '$count istek';
  }

  @override
  String get logViewerFieldId => 'ID';

  @override
  String get logViewerFieldMethod => 'Yöntem';

  @override
  String get logViewerFieldStatus => 'Durum';

  @override
  String get logViewerFieldStarted => 'Başlangıç';

  @override
  String get logViewerFieldEnded => 'Bitiş';

  @override
  String get logViewerFieldDuration => 'Süre';

  @override
  String get logViewerSectionSummary => 'Özet';

  @override
  String get logViewerSectionParameters => 'Parametreler';

  @override
  String get logViewerSectionRequestHeaders => 'İstek Başlıkları';

  @override
  String get logViewerSectionRequestBody => 'İstek Gövdesi';

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
    return '+$count daha';
  }

  @override
  String get logViewerSectionAttachments => 'Ekler';

  @override
  String get logViewerPayloadOmitted => 'atlandı';

  @override
  String get logViewerShowMore => 'Daha fazla göster';

  @override
  String get logSettingsTitle => 'Günlük Ayarları';

  @override
  String get logSettingsSaveOutput => 'Yanıt Çıktısını Kaydet';

  @override
  String get logSettingsSaveOutputSubtitle =>
      'Her akış parçasını günlüğe kaydet (üretimi yavaşlatabilir). HTTP hata gövdeleri her zaman kaydedilir.';

  @override
  String get logSettingsElidePayloads => 'Büyük Yükleri Atla';

  @override
  String get logSettingsElidePayloadsSubtitle =>
      'Satır içi base64 görselleri ve dosyaları bir yer tutucuyla değiştir. Günlükleri küçük, görüntüleyiciyi hızlı tutar.';

  @override
  String get logSettingsAutoDelete => 'Otomatik silme';

  @override
  String get logSettingsAutoDeleteSubtitle =>
      'Belirtilen günden eski günlükleri sil';

  @override
  String get logSettingsAutoDeleteDisabled => 'Devre dışı';

  @override
  String logSettingsAutoDeleteDays(int count) {
    return '$count gün';
  }

  @override
  String get logSettingsMaxSize => 'Maks. Günlük Boyutu';

  @override
  String get logSettingsMaxSizeSubtitle =>
      'Aşıldığında en eski günlükler silinir';

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
      'Bu özeti temizlemek istediğinizden emin misiniz?';

  @override
  String get homePageProcessingFiles => 'Dosyalar işleniyor...';

  @override
  String get settingsPageWorldBook => 'Dünya Kitabı';

  @override
  String get settingsPageMemory => 'Bellek';

  @override
  String get memorySettingsPageTitle => 'Hafıza';

  @override
  String get memorySettingsGlobalSubtitle => 'Hafıza modu, model ve istemler';

  @override
  String get memorySettingsModeSection => 'Hafıza modu';

  @override
  String get memorySettingsModelSection => 'Hafıza modeli';

  @override
  String get memorySettingsModelTitle => 'İşleme modeli';

  @override
  String get memorySettingsModelUnset => 'Seçilmedi';

  @override
  String get memorySettingsModelTip =>
      'Otomatik hafıza düzenleme etkinleştirildikten sonra bu model arka planda sık sık çağrılır. Ucuz ve hızlı bir model tercih edin.';

  @override
  String get memorySettingsAboutTitle => 'Hafıza hakkında';

  @override
  String get memorySettingsAboutSubtitle =>
      'Hafızanın nasıl çalıştığı ve ne zaman çalıştığı';

  @override
  String get memoryAboutQuickstartTitle => 'Başlayın';

  @override
  String get memoryAboutQuickstartBody =>
      '1. Ayarlar → Hafıza bölümünde bir işleme modeli seçin.\n2. Asistanın Hafıza sekmesinde uzun süreli hafızayı ve Otomatik düzenlemeyi açın.\n3. Birkaç tur sohbet edin veya Düzenle\'ye dokunun, ardından nelerin kaydedildiğini görmek için Tüm hafızalar\'ı açın.';

  @override
  String get memoryAboutTypesTitle => 'Hafıza türleri';

  @override
  String get memoryAboutTypesBody =>
      'Kimlik: Kullanıcı hakkında nasıl hitap edileceği, rol, dil ve uzun vadeli tercihler gibi kalıcı bilgiler. Tam üçüncü şahıs ifadeleri yazın.\n\nİş akışı: İşlerini nasıl yapmayı sevdiği — araçlar, biçimler ve inceleme alışkanlıkları.\n\nSes: Asistanın nasıl konuşmasını istediği — ton, uzunluk ve dil stili.\n\nTalimat: Asistanın uyması gereken kalıcı kurallar, bu sohbetten tek seferlik görevler değil.';

  @override
  String get memoryAboutScopeTitle => 'Genel ve asistana özel';

  @override
  String get memoryAboutScopeBody =>
      'Genel hafızalar her asistan için enjekte edilir. Asistana özel hafızalar yalnızca o asistan tarafından görülebilir. Kullanıcıyı her yerde takip etmesi gereken gerçekler için genel, tek bir kişiliğe ait kurallar veya bağlam için asistana özel kapsamı kullanın.';

  @override
  String get memoryAboutInjectionTitle => 'Hafızalar nasıl enjekte edilir';

  @override
  String get memoryAboutInjectionBody =>
      'Bir sohbetin başında, her türün en yeni öğeleri model bağlamına yerleştirilir. Bir tür enjeksiyon sınırını aşarsa, blok mode=\"summary\" olarak işaretlenir ve toplam ile gösterilen sayıları belirtilir; geri kalanı memory_search_profile ile alınabilir. Daha fazla bütünlük için Ayarlar → Hafıza bölümünde sınırı artırın, ancak daha yüksek token maliyetiyle. Her asistanın hafıza ayarlarında, her zaman tam olarak enjekte edilecek türleri seçin.';

  @override
  String get memoryAboutPipelineTitle => 'Arka plan işlem hattı';

  @override
  String get memoryAboutPipelineBody =>
      'Otomatik düzenleme sohbetlerden sonra çalışır: hatırlanmaya değer bir şey olup olmadığına karar verir, adayları çıkarır, tekrarları kaldırır ve birleştirir, ardından gerektiğinde kimlik öğelerini kullanıcı profiline damıtır. Asistanın Hafıza sekmesinde Düzenle\'ye de dokunabilirsiniz. İşleme modelinin sık sık çağrılmasının nedeni budur.';

  @override
  String get memoryAboutCacheTitle => 'Önbelleği sağlıklı tutun';

  @override
  String get memoryAboutCacheBody =>
      'Enjekte edilen hafıza öneki sabit tutulur, böylece değişmeyen sohbetler istem önbelleğini yeniden kullanabilir ve maliyet ile gecikme azalır. Gereksiz toplu düzenlemelerden veya yeniden sıralamalardan kaçının. Günlük tek girişlik düzenlemeler genellikle sınırlı etkiye sahiptir.';

  @override
  String get memoryAboutFaqTitle => 'SSS';

  @override
  String get memoryAboutFaqWhyNotRememberedTitle => 'Bu neden hatırlanmadı?';

  @override
  String get memoryAboutFaqWhyNotRememberedBody =>
      'Düzenlenecek yeterli yeni mesaj yoksa, düzenlenecek yeni mesaj yoksa veya hafıza işleme modeli seçilmemişse düzenleme atlanır. Geçici sohbetler hafızaya kaydedilmez. Ayrıca asistan başına hafızayı veya Otomatik düzenlemeyi kapatabilirsiniz.';

  @override
  String get memorySettingsThinkingTitle => 'Düşünmeyi etkinleştir';

  @override
  String get memorySettingsThinkingSubtitle =>
      'Desteklendiğinde hafıza modelinin akıl yürütme kullanmasına izin ver';

  @override
  String get memorySettingsInjectionSection => 'Hafıza enjeksiyonu';

  @override
  String get memorySettingsInjectionMaxItemsTitle =>
      'Tür başına enjekte edilen öğeler';

  @override
  String get memorySettingsInjectionMaxItemsSubtitle =>
      'Bu sınır, asistanın hafıza ayarlarında tam enjeksiyon için seçilmeyen türler için geçerlidir. Bir tür bu sınırı aşarsa yalnızca en yeni öğeler enjekte edilir. Geri kalanı memory_search_profile ile alınabilir. Daha büyük bir sayı daha eksiksizdir ancak daha fazla token kullanır. Kurallar istemini özelleştirdiyseniz güncelleyin veya varsayılana geri yükleyin.';

  @override
  String get assistantEditMemoryFullInjectionTypesTitle =>
      'Tam enjeksiyon türleri';

  @override
  String get assistantEditMemoryFullInjectionTypesNone => 'Hiçbiri';

  @override
  String assistantEditMemoryFullInjectionTypesSelected(int count) {
    return '$count seçildi';
  }

  @override
  String get assistantEditMemoryFullInjectionTypesSubtitle =>
      'Yalnızca bu asistan için geçerlidir. Öğe sınırını yok sayarak tüm etkin genel ve asistana özel hafızalarını enjekte etmek için türleri seçin. Daha fazla bağlam ve token kullanır.';

  @override
  String memorySettingsInjectionMaxItemsOption(int n) {
    return '$n';
  }

  @override
  String get memorySettingsInjectionMaxItemsCustomButton => 'Özel';

  @override
  String get memorySettingsInjectionMaxItemsCustomTitle =>
      'Özel enjeksiyon sayısı';

  @override
  String get memorySettingsInjectionMaxItemsCustomDescription =>
      '1 ile 100 arasında bir sayı girin.';

  @override
  String get memorySettingsInjectionMaxItemsCustomLabel => 'Sayı';

  @override
  String get memorySettingsInjectionMaxItemsCustomHint => '1–100';

  @override
  String get memorySettingsInjectionMaxItemsCustomInvalid =>
      '1 ile 100 arasında bir sayı girin';

  @override
  String get memorySettingsPromptLangSection => 'İstem dili';

  @override
  String get memorySettingsPromptLangAuto => 'Otomatik';

  @override
  String get memorySettingsPromptLangAutoSubtitle =>
      'Arayüz dilini takip et (Çince → zh, aksi halde en)';

  @override
  String get memorySettingsPromptLangZh => 'Çince';

  @override
  String get memorySettingsPromptLangZhSubtitle =>
      'Her zaman Çince hafıza istemleri ve araç açıklamaları kullan';

  @override
  String get memorySettingsPromptLangEn => 'İngilizce';

  @override
  String get memorySettingsPromptLangEnSubtitle =>
      'Her zaman İngilizce hafıza istemleri ve araç açıklamaları kullan';

  @override
  String get memorySettingsPromptsSection => 'İstem şablonları';

  @override
  String get memorySettingsLegacyPromptTitle => 'Eski hafıza kuralları';

  @override
  String get memoryPromptEditRulesTitle => 'Hafıza kuralları';

  @override
  String get memoryPromptEditRulesSubtitle =>
      'Ana sohbet sistem istemine eklenir';

  @override
  String get memoryPromptEditGateTitle => 'Gatekeeper';

  @override
  String get memoryPromptEditGateSubtitle =>
      'Bir turun hatırlanmaya değer olup olmadığına karar verir';

  @override
  String get memoryPromptEditExtractTitle => 'Extract';

  @override
  String get memoryPromptEditExtractSubtitle =>
      'Bir sohbetten aday bellek öğeleri çıkarır';

  @override
  String get memoryPromptEditSmartAddTitle => 'Smart Add';

  @override
  String get memoryPromptEditSmartAddSubtitle =>
      'NEW / MERGE / CONFLICT / SKIP yinelenen öğe kararı';

  @override
  String get memoryPromptEditDistillTitle => 'Profile Distiller';

  @override
  String get memoryPromptEditDistillSubtitle =>
      'Kimlik belleklerini profil alanlarına damıtır';

  @override
  String get memoryPromptEditMigrateTitle => 'Eski sürüm geçişi';

  @override
  String get memoryPromptEditMigrateSubtitle =>
      'Geçiş, bellek metnini yeniden yazdığında kullanılır';

  @override
  String get memoryPromptEditReset => 'Varsayılana sıfırla';

  @override
  String get memoryPromptEditSave => 'Kaydet';

  @override
  String get memoryPromptEditSectionPerItem => 'Öğe başına istem';

  @override
  String get memoryPromptEditSectionBatch => 'Toplu istem';

  @override
  String get memorySettingsEntriesSection => 'Tüm bellekler';

  @override
  String get memorySettingsLegacySection => 'Eski bellek';

  @override
  String get memorySettingsEntriesTitle => 'Bellek listesi';

  @override
  String get memorySettingsEntriesSubtitle =>
      'Bellekleri göz at, düzenle, arşivle ve sil';

  @override
  String get memorySettingsProfileTitle => 'Kullanıcı profili';

  @override
  String get memorySettingsProfileSubtitle =>
      'Model için yapılandırılmış kimlik alanları';

  @override
  String get memorySettingsLegacyTitle => 'Eski bellekler (salt okunur)';

  @override
  String get memorySettingsLegacySubtitle =>
      'Önceki sürümlerden kalan bellekler';

  @override
  String get memoryEntryTypeIdentity => 'Kimlik';

  @override
  String get memoryEntryTypeWorkflow => 'İş akışı';

  @override
  String get memoryEntryTypeVoice => 'Üslup';

  @override
  String get memoryEntryTypeInstruction => 'Talimat';

  @override
  String get memoryEntryScopeGlobal => 'Genel';

  @override
  String get memoryEntryScopeAssistant => 'Bu asistan';

  @override
  String memoryEntryScopeAssistantNamed(String name) {
    return '$name';
  }

  @override
  String get memoryEntrySourceManual => 'Manuel';

  @override
  String get memoryEntrySourceTool => 'Araç';

  @override
  String get memoryEntrySourceExtracted => 'Çıkarılmış';

  @override
  String get memoryEntrySourceDistilled => 'Damıtılmış';

  @override
  String get memoryEntryStatusActive => 'Etkin';

  @override
  String get memoryEntryStatusArchived => 'Arşivlendi';

  @override
  String memoryEntryUpdatedAt(String date) {
    return 'Güncellendi: $date';
  }

  @override
  String get memoryEntryActionEdit => 'Düzenle';

  @override
  String get memoryEntryActionDelete => 'Sil';

  @override
  String get memoryEntryActionArchive => 'Arşivle';

  @override
  String get memoryEntryActionRestore => 'Geri yükle';

  @override
  String get memoryEntryActionSwitchScope => 'Kapsamı değiştir';

  @override
  String get memoryEntryActionBatchDelete => 'Seçilenleri sil';

  @override
  String get memoryEntryActionAdd => 'Bellek ekle';

  @override
  String get memoryEntryDeleteConfirmTitle => 'Bellek silinsin mi?';

  @override
  String get memoryEntryDeleteConfirmContent =>
      'Bu, belleği kalıcı olarak siler. Bu işlem geri alınamaz.';

  @override
  String memoryEntryBatchDeleteConfirmTitle(int count) {
    return '$count bellek silinsin mi?';
  }

  @override
  String get memoryEntryBatchDeleteConfirmContent =>
      'Seçilen bellekler kalıcı olarak silinecek.';

  @override
  String get memoryEntrySwitchScopeConfirmTitle =>
      'Bellek kapsamı değiştirilsin mi?';

  @override
  String get memoryEntrySwitchScopeToGlobal =>
      'Bu bellek genel yapılsın mı (tüm asistanlarla paylaşılsın)?';

  @override
  String get memoryEntrySwitchScopeToAssistant =>
      'Bu anıyı yalnızca geçerli asistanla sınırla?';

  @override
  String get memoryEntryArchivedSection => 'Arşivlenmiş';

  @override
  String get memoryEntryEmpty => 'Henüz anı yok';

  @override
  String get memoryEntryEmptyDisabled =>
      'Bu asistan için uzun süreli bellek kapalı';

  @override
  String get memoryEntryEditTitle => 'Anıyı düzenle';

  @override
  String get memoryEntryCreateTitle => 'Yeni anı';

  @override
  String get memoryEntryContentHint => 'Anı içeriğini girin';

  @override
  String get memoryEntryTypeLabel => 'Tür';

  @override
  String get memoryEntryScopeLabel => 'Kapsam';

  @override
  String get memoryFilterScopeAll => 'Tüm kapsamlar';

  @override
  String get memoryFilterScopeGlobal => 'Yalnızca genel';

  @override
  String get memoryFilterScopeAssistant => 'Asistan';

  @override
  String get memoryFilterTypeAll => 'Tüm türler';

  @override
  String get memoryFilterStatusAll => 'Tüm durumlar';

  @override
  String get memoryFilterStatusActive => 'Etkin';

  @override
  String get memoryFilterStatusArchived => 'Arşivlenmiş';

  @override
  String get memorySearchHint => 'Anılarda ara';

  @override
  String get memorySearchEmpty => 'Eşleşen anı yok';

  @override
  String memoryOrphanBanner(int count) {
    return '$count sahipsiz asistan anısı (asistan silinmiş)';
  }

  @override
  String get memoryOrphanCleanupButton => 'Temizle';

  @override
  String get memoryOrphanConfirmTitle => 'Sahipsiz anılar temizlensin mi?';

  @override
  String memoryOrphanConfirmContent(int count) {
    return 'Asistanı artık mevcut olmayan $count anı kalıcı olarak silinecek.';
  }

  @override
  String get memoryOrganizeButton => 'Düzenle';

  @override
  String get memoryOrganizeNeedsConversation =>
      'Anıları düzenlemek için bu asistanla bir sohbet açın';

  @override
  String get memoryOrganizeNeedsModel =>
      'Önce Ayarlar → Bellek bölümünde bir bellek modeli seçin';

  @override
  String get memoryOrganizeStatusNever => 'Henüz düzenlenmedi';

  @override
  String memoryOrganizeStatusLast(String when) {
    return 'Son düzenleme: $when';
  }

  @override
  String memoryOrganizeStatusExtracted(int count) {
    return '$count çıkarıldı';
  }

  @override
  String get memoryOrganizeStatusSkipped => 'hatırlanacak bir şey yok';

  @override
  String memoryOrganizeStatusFailed(String reason) {
    return 'Başarısız: $reason';
  }

  @override
  String memoryOrganizeStatusSkippedReason(String reason) {
    return 'atlandı: $reason';
  }

  @override
  String get memoryOutcomeTemporaryConversation =>
      'Geçici sohbetler belleğe kaydedilmez';

  @override
  String get memoryOutcomeMemoryDisabled => 'Bu asistan için bellek kapalı';

  @override
  String get memoryOutcomeAutoOrganizeOff => 'Otomatik düzenleme kapalı';

  @override
  String get memoryOutcomeStreaming => 'Yanıt hâlâ akıtılırken atlandı';

  @override
  String get memoryOutcomeBelowThreshold =>
      'Düzenlemek için yeterli yeni mesaj yok';

  @override
  String get memoryOutcomeEmptyWindow => 'Düzenlenecek yeni mesaj yok';

  @override
  String get memoryOutcomeMemoryModelUnset => 'Bellek işleme modeli seçilmedi';

  @override
  String get memoryOutcomeMemoryModelMissing =>
      'Seçilen bellek modeli artık kullanılamıyor';

  @override
  String get memoryOutcomeAssistantMissing => 'Asistan bulunamadı';

  @override
  String get memoryOutcomeConversationMissing => 'Sohbet bulunamadı';

  @override
  String get memoryOutcomeQueueOverflow =>
      'Düzenleme kuyruğu doluydu, bu çalıştırma atıldı';

  @override
  String get memoryOutcomeGateRequestFailed =>
      'Hatırla/atla kontrolü için bellek modeline ulaşılamadı';

  @override
  String get memoryOutcomeGateParseFailed =>
      'Hatırla/atla kontrolü okunamayan bir yanıt döndürdü';

  @override
  String get memoryOutcomeExtractRequestFailed =>
      'Anıları çıkarmak için bellek modeline ulaşılamadı';

  @override
  String get memoryOutcomeExtractParseFailed =>
      'Anı çıkarma yanıtı ayrıştırılamadı';

  @override
  String get memoryOutcomeDistillFailed => 'Kullanıcı profili damıtılamadı';

  @override
  String get memoryOutcomeMemoryExecutionError =>
      'Bir bellek aracı çalıştırılamadı';

  @override
  String get memoryOutcomeUnsupportedTool => 'Desteklenmeyen bellek aracı';

  @override
  String get memoryOutcomeInvalidMemoryType => 'Geçersiz anı türü';

  @override
  String get memoryOutcomeInvalidMemoryContent => 'Geçersiz anı içeriği';

  @override
  String get memoryOutcomeInvalidQuery => 'Geçersiz arama sorgusu';

  @override
  String get memoryOutcomeInvalidMemoryId => 'Geçersiz anı kimliği';

  @override
  String get memoryOutcomeMemoryNotFound => 'Anı bulunamadı';

  @override
  String get memoryOutcomeInvalidProfileFields => 'Geçersiz profil alanları';

  @override
  String get memoryOutcomeChatSearchUnavailable =>
      'Sohbet araması kullanılamıyor';

  @override
  String get memoryOrganizeJustNow => 'az önce';

  @override
  String memoryOrganizeMinutesAgo(int n) {
    return '$n dk önce';
  }

  @override
  String memoryOrganizeHoursAgo(int n) {
    return '$n sa önce';
  }

  @override
  String memoryOrganizeDaysAgo(int n) {
    return '$n g önce';
  }

  @override
  String get memoryModelMissingNotice =>
      'Önce Ayarlar → Anılar bölümünden bir anı işleme modeli seçin.';

  @override
  String get memoryModelMissingGoSelect => 'Model seç';

  @override
  String get memoryEntriesPageTitle => 'Tüm anılar';

  @override
  String get userProfilePageTitle => 'Kullanıcı profili';

  @override
  String get userProfilePreferredName => 'Tercih edilen ad';

  @override
  String get userProfilePreferredNameHint =>
      'Modelin size nasıl hitap etmesi gerektiği — kenar çubuğundaki görünen adla ilgisi yoktur';

  @override
  String get userProfileGender => 'Cinsiyet';

  @override
  String get userProfilePronouns => 'Zamirler';

  @override
  String get userProfilePreferredLanguage => 'Tercih edilen dil';

  @override
  String get userProfileTimezone => 'Saat dilimi';

  @override
  String get userProfileOccupation => 'Meslek';

  @override
  String get userProfileLocation => 'Konum';

  @override
  String get userProfileCustomSection => 'Özel alanlar';

  @override
  String get userProfileAddCustom => 'Özel alan ekle';

  @override
  String get userProfileCustomKeyHint => 'Anahtar (custom.name)';

  @override
  String get userProfileCustomValueHint => 'Değer';

  @override
  String get userProfileInvalidKey =>
      'Anahtar custom. ile başlamalı ve ardından 1–32 harf, rakam, _ veya - gelmelidir';

  @override
  String get userProfileClear => 'Temizle';

  @override
  String get userProfileSave => 'Kaydet';

  @override
  String get userProfileEmptyValue => 'Ayarlanmadı';

  @override
  String get legacyMemoryPageTitle => 'Eski anılar';

  @override
  String get legacyMemoryBanner =>
      'Bu anılar eski bir sürümden geliyor ve sohbetlerde kullanılmıyor. Bunları mevcut anı sistemine taşıyabilirsiniz.';

  @override
  String get legacyMemoryEmpty => 'Eski anı yok';

  @override
  String get legacyMemoryCopy => 'Kopyala';

  @override
  String get legacyMemoryCopied => 'Kopyalandı';

  @override
  String get legacyMemoryExport => 'Dışa aktar';

  @override
  String get legacyMemoryExportTitle => 'Kelivo eski anı dışa aktarımı';

  @override
  String legacyMemoryAssistantHeader(String name) {
    return 'Asistan: $name';
  }

  @override
  String get legacyMemorySearchHint => 'Eski anılarda ara';

  @override
  String get legacyMemoryMigrate => 'Taşı';

  @override
  String get legacyMemoryMigrationTitle => 'Eski anıları taşı';

  @override
  String legacyMemoryMigrationSubtitle(int count) {
    return '$count eski anıyı sınıflandırmak ve temizlemek için bir model kullanın. Orijinaller değişmeden kalır.';
  }

  @override
  String get legacyMemoryMigrationModel => 'Taşıma modeli';

  @override
  String get legacyMemoryMigrationChooseModel => 'Bir model seçin';

  @override
  String get legacyMemoryMigrationTarget => 'Kaydetme yeri';

  @override
  String get legacyMemoryMigrationTargetGlobal => 'Genel';

  @override
  String get legacyMemoryMigrationTargetAssistant => 'Geçerli asistan';

  @override
  String get legacyMemoryMigrationTargetOriginalAssistants =>
      'Orijinal asistanlar';

  @override
  String get legacyMemoryMigrationTargetGlobalDescription =>
      'Tüm asistanlar tarafından kullanılabilir';

  @override
  String get legacyMemoryMigrationTargetAssistantDescription =>
      'Yalnızca bu asistan tarafından kullanılabilir';

  @override
  String get legacyMemoryMigrationTargetOriginalDescription =>
      'Her anıyı özgün asistanıyla birlikte tut';

  @override
  String get legacyMemoryMigrationStart => 'Geçişi başlat';

  @override
  String get legacyMemoryMigrationAnalyzing => 'Modelle analiz ediliyor';

  @override
  String get legacyMemoryMigrationWriting => 'Anılar kaydediliyor';

  @override
  String legacyMemoryMigrationProgress(int current, int total) {
    return '$current / $total';
  }

  @override
  String get legacyMemoryMigrationComplete => 'Geçiş tamamlandı';

  @override
  String legacyMemoryMigrationResult(int created, int skipped) {
    return '$created taşındı · $skipped zaten vardı';
  }

  @override
  String get legacyMemoryMigrationFailed =>
      'Geçiş durduruldu. Yeniden deneyebilirsiniz; zaten kaydedilmiş anılar atlanacaktır.';

  @override
  String get legacyMemoryMigrationRetry => 'Yeniden dene';

  @override
  String get legacyMemoryMigrationClose => 'Tamam';

  @override
  String get legacyMemoryMigrationContentMode => 'İçerik';

  @override
  String get legacyMemoryMigrationContentPreserve => 'Orijinali koru';

  @override
  String get legacyMemoryMigrationContentOrganize => 'Modelle yeniden yaz';

  @override
  String get legacyMemoryMigrationContentPreserveDescription =>
      'Model yalnızca bir tür atar. Orijinal ifade olduğu gibi kaydedilir.';

  @override
  String get legacyMemoryMigrationContentOrganizeDescription =>
      'Model her anıyı düzenlenebilir taşıma istemiyle sınıflandırır ve yeniden yazar.';

  @override
  String get legacyMemoryMigrationBatchSize => 'Toplu iş boyutu';

  @override
  String legacyMemoryMigrationPartial(int created, int skipped, int failed) {
    return '$created taşındı · $skipped atlandı · $failed başarısız';
  }

  @override
  String get legacyMemoryMigrationContinue => 'Geçişe devam et';

  @override
  String get legacyMemoryMigrationErrorNetwork =>
      'Ağ hatası. Bağlantıyı kontrol edip yeniden deneyin.';

  @override
  String get legacyMemoryMigrationErrorFormat =>
      'Model geçersiz bir yanıt döndürdü.';

  @override
  String get legacyMemoryMigrationErrorAuth =>
      'Kimlik doğrulama başarısız. API anahtarını kontrol edin.';

  @override
  String legacyMemoryMigrationErrorOther(String message) {
    return 'Geçiş başarısız: $message';
  }

  @override
  String get legacyMemoryModeTitle => 'Eski anıları kullan';

  @override
  String get legacyMemoryModeSubtitle => 'Tüm asistanlar için genel ayar';

  @override
  String legacyMemoryModeCacheWarning(String token) {
    return 'Varsayılan şablon $token aracılığıyla geçerli saati ekler, bu da önbellek isabet oranını etkiler. İhtiyacınız yoksa kaldırın.';
  }

  @override
  String get memoryUiContentLabel => 'İçerik';

  @override
  String get memoryUiValueLabel => 'Değer';

  @override
  String get memoryUiCustomKeyLabel => 'Anahtar';

  @override
  String get memoryUiStatusLabel => 'Durum';

  @override
  String get memoryUiAssistantLabel => 'Asistan';

  @override
  String get memoryUiAssistantAll => 'Tüm asistanlar';

  @override
  String get memoryUiSearchClear => 'Aramayı temizle';

  @override
  String get memoryUiAssistantLegacyTitle => 'Eski anılar (salt okunur)';

  @override
  String get memoryUiAssistantLegacySubtitle =>
      'Bu asistanın önceki sürümlerden kalan eski anıları';

  @override
  String get assistantEditMemorySwitchTitle => 'Uzun süreli anı kullan';

  @override
  String get assistantEditMemorySwitchSubtitle =>
      'Kaydedilmiş anıları sohbetlere ekle ve bu asistanın yeni anılar yazmasına izin ver';

  @override
  String get assistantEditAutoOrganizeTitle => 'Anıları otomatik düzenle';

  @override
  String get assistantEditAutoOrganizeSubtitle =>
      'Sohbetlerden sonra anı işlem hattını çalıştır';

  @override
  String get assistantEditAllowPastRecallTitle =>
      'Geçmiş sohbetleri hatırlamaya izin ver';

  @override
  String get assistantEditAllowPastRecallSubtitle =>
      'Geçmiş sohbetler arasında sohbet aramasını etkinleştir';

  @override
  String get assistantEditGenerateSummaryTitle => 'Sohbet özetleri oluştur';

  @override
  String get assistantEditGenerateSummarySubtitle =>
      'Özetler yalnızca sohbet araması tarafından kullanılır';

  @override
  String get assistantEditManageMemoryTitle =>
      'Bu asistanın görebildiği anılar';

  @override
  String get assistantEditWriteScopeTitle => 'Anı yazma kapsamı';

  @override
  String get assistantEditWriteScopeSubtitle =>
      'Yeni anıların varsayılan olarak nereye kaydedileceği';

  @override
  String get assistantEditWriteScopeAlwaysGlobal => 'Her zaman genel';

  @override
  String get assistantEditWriteScopeAlwaysGlobalSubtitle =>
      'Yeni anılar her asistanla paylaşılır';

  @override
  String get assistantEditWriteScopeAlwaysAssistant => 'Her zaman bu asistan';

  @override
  String get assistantEditWriteScopeAlwaysAssistantSubtitle =>
      'Yeni anılar bu asistana özel kalır';

  @override
  String get assistantEditWriteScopeToolDefaultGlobal =>
      'Model seçer (varsayılan genel)';

  @override
  String get assistantEditWriteScopeToolDefaultGlobalSubtitle =>
      'Model global veya bu asistanı seçebilir; varsayılan global';

  @override
  String get assistantEditWriteScopeToolDefaultAssistant =>
      'Model seçer (varsayılan asistan)';

  @override
  String get assistantEditWriteScopeToolDefaultAssistantSubtitle =>
      'Model global veya bu asistanı seçebilir; varsayılan bu asistan';

  @override
  String get assistantEditDedupeModeTitle => 'Tekilleştirme modu';

  @override
  String get assistantEditDedupeModeSubtitle =>
      'Adayların mevcut anılarla nasıl karşılaştırılacağı';

  @override
  String get assistantEditDedupeModeBatched => 'Toplu';

  @override
  String get assistantEditDedupeModeBatchedSubtitle =>
      'Tüm yeni adayları tek istekte değerlendir. Daha hızlı ve ucuz; aynı anda çok öğe geldiğinde daha az kesin.';

  @override
  String get assistantEditDedupeModePerItem => 'Öğe başına';

  @override
  String get assistantEditDedupeModePerItemSubtitle =>
      'Her adayı kendi isteğinde değerlendir. Daha doğru; daha fazla model çağrısı kullanır.';

  @override
  String get assistantEditOrganizeFrequencyTitle => 'Her N turda düzenle';

  @override
  String get assistantEditOrganizeFrequencySubtitle =>
      'Bu sayıda asistan yanıtından sonra otomatik düzenlemeyi çalıştır';

  @override
  String assistantEditOrganizeFrequencyOption(int n) {
    return 'Her $n';
  }

  @override
  String get assistantEditOrganizeFrequencyCustomButton => 'Özel';

  @override
  String get assistantEditOrganizeFrequencyCustomTitle => 'Özel sıklık';

  @override
  String get assistantEditOrganizeFrequencyCustomDescription =>
      '1 ile 20 arasında bir sayı girin.';

  @override
  String get assistantEditOrganizeFrequencyCustomLabel => 'Tur';

  @override
  String get assistantEditOrganizeFrequencyCustomHint => '1–20';

  @override
  String get assistantEditOrganizeFrequencyCustomInvalid =>
      '1 ile 20 arasında bir sayı girin';

  @override
  String get worldBookTitle => 'Dünya Kitabı';

  @override
  String get worldBookAdd => 'Dünya Kitabı Ekle';

  @override
  String get worldBookEmptyMessage => 'Henüz dünya kitabı yok';

  @override
  String get worldBookUnnamed => 'Adsız Dünya Kitabı';

  @override
  String get worldBookDisabledTag => 'Devre dışı';

  @override
  String get worldBookAlwaysOnTag => 'Her Zaman Açık';

  @override
  String get worldBookAddEntry => 'Girdi Ekle';

  @override
  String get worldBookExport => 'Paylaş / Dışa Aktar';

  @override
  String get worldBookConfig => 'Yapılandır';

  @override
  String get worldBookDeleteTitle => 'Dünya Kitabını Sil';

  @override
  String worldBookDeleteMessage(String name) {
    return '“$name” silinsin mi? Bu işlem geri alınamaz.';
  }

  @override
  String get worldBookCancel => 'İptal';

  @override
  String get worldBookDelete => 'Sil';

  @override
  String worldBookExportFailed(String error) {
    return 'Dışa aktarma başarısız: $error';
  }

  @override
  String get worldBookNoEntriesHint => 'Girdi yok';

  @override
  String get worldBookUnnamedEntry => 'Adsız Girdi';

  @override
  String worldBookKeywordsLine(String keywords) {
    return 'Anahtar kelimeler: $keywords';
  }

  @override
  String get worldBookEditEntry => 'Girdiyi Düzenle';

  @override
  String get worldBookDeleteEntry => 'Girdiyi Sil';

  @override
  String get worldBookNameLabel => 'Ad';

  @override
  String get worldBookDescriptionLabel => 'Açıklama';

  @override
  String get worldBookEnabledLabel => 'Etkin';

  @override
  String get worldBookSave => 'Kaydet';

  @override
  String get worldBookEntryNameLabel => 'Girdi adı';

  @override
  String get worldBookEntryEnabledLabel => 'Girdi etkin';

  @override
  String get worldBookEntryPriorityLabel => 'Öncelik';

  @override
  String get worldBookEntryKeywordsLabel => 'Anahtar kelimeler';

  @override
  String get worldBookEntryKeywordsHint =>
      'Bir anahtar kelime yazın ve eklemek için + simgesine dokunun.';

  @override
  String get worldBookEntryKeywordInputHint => 'Bir anahtar kelime yazın';

  @override
  String get worldBookEntryKeywordAddTooltip => 'Anahtar kelime ekle';

  @override
  String get worldBookEntryUseRegexLabel => 'Regex kullan';

  @override
  String get worldBookEntryCaseSensitiveLabel => 'Büyük/küçük harfe duyarlı';

  @override
  String get worldBookEntryAlwaysOnLabel => 'Her zaman etkin';

  @override
  String get worldBookEntryAlwaysOnHint =>
      'Anahtar kelime eşleşmesi olmadan her zaman ekle';

  @override
  String get worldBookEntryScanDepthLabel => 'Tarama derinliği';

  @override
  String get worldBookEntryContentLabel => 'İçerik';

  @override
  String get worldBookEntryInjectionPositionLabel => 'Ekleme konumu';

  @override
  String get worldBookEntryInjectionRoleLabel => 'Ekleme rolü';

  @override
  String get worldBookEntryInjectDepthLabel => 'Ekleme derinliği';

  @override
  String get worldBookInjectionPositionBeforeSystemPrompt =>
      'Sistem isteminden önce';

  @override
  String get worldBookInjectionPositionAfterSystemPrompt =>
      'Sistem isteminden sonra';

  @override
  String get worldBookInjectionPositionTopOfChat => 'Sohbetin başı';

  @override
  String get worldBookInjectionPositionBottomOfChat => 'Sohbetin sonu';

  @override
  String get worldBookInjectionPositionAtDepth => 'Belirli derinlikte';

  @override
  String worldBookImportUnsupportedEntries(int count) {
    return 'İçe aktarıldı. $count girdi desteklenmeyen SillyTavern özellikleri (makrolar, regex, zamanlama, filtreler veya ekleme kuralları gibi) kullanıyor. İçerikleri korundu ve devre dışı bırakıldı. Etkinleştirmeden önce gözden geçirin.';
  }

  @override
  String get worldBookInjectionRoleUser => 'Kullanıcı';

  @override
  String get worldBookInjectionRoleAssistant => 'Asistan';

  @override
  String get mcpToolNeedsApproval => 'Onay gerekli';

  @override
  String get toolApprovalPending => 'Onay bekleniyor';

  @override
  String get toolApprovalDeny => 'Reddet';

  @override
  String get toolApprovalDenyTitle => 'Araç çağrısını reddet';

  @override
  String get toolApprovalDenyHint => 'Neden (isteğe bağlı)';

  @override
  String toolApprovalDeniedMessage(Object reason, Object toolName) {
    return '\"$toolName\" araç çağrısı kullanıcı tarafından reddedildi. Neden: $reason';
  }

  @override
  String get askUserCardSubmit => 'Yanıtı gönder';

  @override
  String get askUserCardCustomHint => 'Yanıtınızı yazın';

  @override
  String get askUserCardSomethingElse => 'Başka bir şey';

  @override
  String get askUserCardSkip => 'Atla';

  @override
  String get askUserCardSkipped => 'Atlandı';

  @override
  String get askUserCardAnswered => 'Yanıtlandı';

  @override
  String get askUserCardInactive =>
      'Bu soru artık etkin değil. Yeniden oluşturun veya sohbete devam edin.';

  @override
  String get askUserCardCancelled => 'Soru iptal edildi';

  @override
  String askUserCardQuestionCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count soru sor',
      one: '1 soru sor',
    );
    return '$_temp0';
  }

  @override
  String tokenDetailPromptTokens(int count) {
    return '$count token';
  }

  @override
  String tokenDetailPromptTokensWithCache(int count, int cached) {
    return '$count token ($cached önbellekte)';
  }

  @override
  String tokenDetailCompletionTokens(int count) {
    return '$count token';
  }

  @override
  String tokenDetailSpeed(String value) {
    return '$value tok/s';
  }

  @override
  String tokenDetailDuration(String value) {
    return '${value}s';
  }

  @override
  String tokenDetailFirstResponse(String value) {
    return '${value}sn (ilk yanıt)';
  }

  @override
  String tokenDetailFirstOutput(String value) {
    return '${value}sn (ilk çıktı)';
  }

  @override
  String tokenDetailTotalTokens(int count) {
    return '$count token';
  }

  @override
  String tokenDetailReasoningTokens(int count) {
    return '$count token';
  }

  @override
  String tokenDetailCacheWriteTokens(int count) {
    return '$count önbellek yazma tokenı';
  }

  @override
  String tokenDetailCost(String amount) {
    return '$amount';
  }

  @override
  String get debugPageTitle => 'Hata ayıklama';

  @override
  String get debugPageConversationToolsTitle => 'Sohbet araçları';

  @override
  String get debugPageCreateOversizedConversationButton =>
      'Aşırı büyük sohbet oluştur (30 MB)';

  @override
  String get debugPageCreateManyMessagesConversationButton =>
      '1024 mesajlık sohbet oluştur';

  @override
  String get debugPageCreateDailyMixedMarkdownConversationButton =>
      '3000 günlük karışık Markdown mesajı oluştur';

  @override
  String get debugPageCreateLongReasoningConversationButton =>
      'Uzun akıl yürütmeli sohbet oluştur (128 mesaj)';

  @override
  String get debugPageCreatingButton => 'Oluşturuluyor...';

  @override
  String get debugPageCreatingOversizedConversation =>
      '30 MB aşırı büyük sohbet oluşturuluyor...';

  @override
  String get debugPageCreatingManyMessagesConversation =>
      '1024 mesajlık sohbet oluşturuluyor...';

  @override
  String get debugPageCreatingDailyMixedMarkdownConversation =>
      '3000 mesajlık günlük karışık Markdown sohbeti oluşturuluyor...';

  @override
  String get debugPageCreatingLongReasoningConversation =>
      'Uzun akıl yürütme hata ayıklama sohbeti oluşturuluyor...';

  @override
  String get debugPageNoCurrentAssistant =>
      'Geçerli asistan yok. Önce bir asistan oluşturun veya seçin.';

  @override
  String debugPageConversationCreated(int count) {
    return '$count mesaj içeren hata ayıklama sohbeti oluşturuldu.';
  }

  @override
  String debugPageCreateConversationFailed(String error) {
    return 'Hata ayıklama sohbeti oluşturulamadı: $error';
  }

  @override
  String debugPageOversizedConversationTitle(int sizeMB) {
    return 'Aşırı büyük sohbet testi ($sizeMB MB)';
  }

  @override
  String debugPageManyMessagesConversationTitle(int count) {
    return '$count mesajlık sohbet testi';
  }

  @override
  String debugPageDailyMixedMarkdownConversationTitle(int count) {
    return '$count mesajlık günlük karışık Markdown testi';
  }

  @override
  String debugPageLongReasoningConversationTitle(int count) {
    return '$count mesajlık uzun akıl yürütme testi';
  }

  @override
  String get debugPageOversizedConversationSeedText =>
      'Bu, aşırı büyük sohbetlerde yavaş işlemeyi yeniden üretmek için uzun bir hata ayıklama metnidir. Sohbet işleme, depolama ve kaydırma performansının profillenebilmesi için tekrarlanan Markdown benzeri metin, noktalama işaretleri, CJK içeriği ve düz kelimeler içerir.';

  @override
  String debugPageManyMessagesSeedText(String role, int index) {
    return '$role mesajı #$index: liste işleme, kaydırma kararlılığı, mesaj gruplama ve sohbet geçmişi performansını test etmek için hızlı rastgele hata ayıklama örneği.';
  }

  @override
  String get migrationIntroTitle => 'Sohbet Depolamasını Yükselt';

  @override
  String get migrationIntroSubtitle =>
      'Kelivo sohbet geçmişini daha hızlı bir SQLite veritabanına taşıyor. Verilerinizin tutarlı kalması için yükseltme uygulama açılmadan önce çalışır.';

  @override
  String get migrationBackupNote =>
      'Geçiş başlamadan önce Kelivo; ayarlar, sohbet geçmişi ve yerel dosyaları içeren bir ZIP yedeği dışa aktarır.';

  @override
  String get migrationPerformanceNote =>
      'Geçişten sonra başlatma, geçmiş yükleme ve arama, uzun sohbetlerde daha akıcı performans için SQLite dizinlerini kullanır.';

  @override
  String get migrationSourceDatabaseLabel => 'Hive';

  @override
  String get migrationTargetDatabaseLabel => 'SQLite';

  @override
  String get migrationChooseFolderButton => 'Klasör Seç ve Yedekle';

  @override
  String get migrationSaveBackupButton => 'Yedek ZIP\'i Kaydet';

  @override
  String get migrationStartWithoutBackupButton => 'Yedeklemeden Geçiş Yap';

  @override
  String get migrationSkipChatsJsonOption => 'chats.json dosyasını atla';

  @override
  String get migrationSkipChatsJsonDescription =>
      'Yine de orijinal Hive dosyaları, ayarlar ve yerel dosyalar yedeklenir. Çok büyük geçmişler için önerilir.';

  @override
  String get migrationSkipBackupOption => 'Bu yedeği atla';

  @override
  String get migrationSkipBackupDescription =>
      'Yalnızca doğrulanmış bir yedeğiniz varsa bunu seçin. Geçiş hemen başlar.';

  @override
  String get migrationBackingUpTitle => 'Yedekleniyor';

  @override
  String get migrationBackingUpSubtitle =>
      'Ayarlar, sohbet geçmişi, yüklenen dosyalar, görseller ve yazı tipleri dışa aktarılıyor. Bu işlem bitene kadar Kelivo\'yu açık tutun.';

  @override
  String get migrationMigratingTitle => 'SQLite\'a Geçiliyor';

  @override
  String get migrationMigratingSubtitle =>
      'Büyük geçmişlerin belleği aşırı yüklememesi için sohbetler ve mesajlar toplu olarak yazılıyor. Geçiş bitene kadar Kelivo\'yu ön planda tutun.';

  @override
  String migrationBackingUpDetail(String fileName) {
    return '$fileName yedekleniyor';
  }

  @override
  String migrationMigratingDetail(int count) {
    return '$count mesaj taşındı';
  }

  @override
  String get migrationMigratingPrepareDetail =>
      'SQLite veritabanı hazırlanıyor';

  @override
  String get migrationMigratingToolEventsDetail => 'Araç kayıtları taşınıyor';

  @override
  String get migrationMigratingValidateDetail => 'Taşınan veriler doğrulanıyor';

  @override
  String get migrationBackupReadyDetail => 'Yedek ZIP hazır';

  @override
  String get migrationSavingBackupZipDetail => 'Yedek ZIP kaydediliyor';

  @override
  String get migrationBackupFileSavedTitle => 'Yedek ZIP kaydedildi';

  @override
  String get migrationChecklistBackupFiles => 'Hive yedek ZIP\'ini dışa aktar';

  @override
  String get migrationChecklistPrepareSqlite => 'SQLite veritabanını hazırla';

  @override
  String get migrationChecklistMigrateMessages =>
      'Sohbetleri ve mesajları taşı';

  @override
  String get migrationChecklistMigrateToolEvents => 'Araç kayıtlarını taşı';

  @override
  String get migrationChecklistValidate => 'Taşınan verileri doğrula';

  @override
  String get migrationStepBackup => 'Yedekle';

  @override
  String get migrationStepMigrate => 'Geçiş';

  @override
  String get migrationStepComplete => 'Tamam';

  @override
  String get migrationCompleteTitle => 'Yükseltme Tamamlandı';

  @override
  String get migrationCompleteSubtitle =>
      'Sohbet geçmişiniz artık SQLite\'ta saklanıyor. Yükseltilmiş uygulamaya girmek için Kelivo\'yu yeniden başlatın.';

  @override
  String get migrationConversationCount => 'Sohbetler';

  @override
  String get migrationMessageCount => 'Mesajlar';

  @override
  String get migrationConvertedCount => 'Dönüştürülen';

  @override
  String get migrationMalformedCount => 'Bozuk';

  @override
  String get migrationMissingFilesCount => 'Eksik dosyalar';

  @override
  String get migrationRestartButton => 'Kelivo\'yu Yeniden Başlat';

  @override
  String get migrationFailedTitle => 'Geçiş Başarısız';

  @override
  String get migrationFailedSubtitle =>
      'Orijinal Hive verileri hâlâ sağlam. Daha önce tamamlanan yedekler değişmedi. Aşağıdaki nedeni inceleyip yeniden deneyin.';

  @override
  String get migrationUnknownError => 'Bilinmeyen geçiş hatası.';

  @override
  String get migrationFailureLogTitle => 'Hata günlüğü';

  @override
  String get migrationRetryButton => 'Geçişi Yeniden Dene';

  @override
  String get migrationSkipButton => 'Geçişi Atla ve Sıfırdan Başla';

  @override
  String get migrationSkipDialogTitle => 'Geçiş atlansın mı?';

  @override
  String get migrationSkipDialogMessage =>
      'Kelivo boş bir sohbet veritabanıyla başlayacak. Eski sohbet geçmişiniz diskte kalır (.retired sonekiyle yeniden adlandırılır) ancak geçiş yapılmaz ve uygulamada görünmez. Daha sonra kurtarmanız gerekirse yedek ZIP dosyanızı kullanın.';

  @override
  String get migrationSkipDialogCancel => 'İptal';

  @override
  String get migrationSkipDialogConfirm => 'Atla ve Sıfırdan Başla';

  @override
  String get migrationChatsExportDegradedNote =>
      'chats.json dışa aktarımı bir hata nedeniyle atlandı. Yedek ZIP dosyası hâlâ tam sohbet geçmişinizi içeren ham Hive dosyalarını barındırıyor.';

  @override
  String get timelineJumpToLatest => 'En sona git';

  @override
  String largeContentShowMore(int count) {
    return '$count tane daha göster';
  }

  @override
  String get largeContentCollapse => 'Daralt';

  @override
  String get imageSettingsPageTitle => 'Görüntü İşleme';

  @override
  String get imageSettingsPageEditSectionTitle => 'Düzenleme';

  @override
  String get imageSettingsPageQualitySectionTitle => 'Yükleme Görüntü Kalitesi';

  @override
  String get imageSettingsPageQualityOriginal => 'Orijinal';

  @override
  String get imageSettingsPageQualityOriginalSubtitle =>
      'Sıkıştırma yok; olduğu gibi yükle';

  @override
  String get imageSettingsPageQualityHigh => 'Yüksek Kalite';

  @override
  String get imageSettingsPageQualityHighSubtitle =>
      'Uzun kenar 2048 px · kalite 90';

  @override
  String get imageSettingsPageQualityBalanced => 'Dengeli';

  @override
  String get imageSettingsPageQualityBalancedSubtitle =>
      'Uzun kenar 1568 px · kalite 85';

  @override
  String get imageSettingsPageQualitySaver => 'Veri Tasarrufu';

  @override
  String get imageSettingsPageQualitySaverSubtitle =>
      'Uzun kenar 1024 px · kalite 70';

  @override
  String get imageSettingsPageQualityCustom => 'Özel';

  @override
  String get imageSettingsPageQualityCustomSubtitle =>
      'Sıkıştırma kalitesini seçin';

  @override
  String get imageSettingsPageCustomQualityTitle => 'Sıkıştırma Kalitesi';

  @override
  String get imageSettingsPageCompressTransparentTitle =>
      'Şeffaf ve Hareketli Görüntüleri Sıkıştır';

  @override
  String get imageSettingsPageCompressTransparentSubtitle =>
      'Etkinleştirildiğinde şeffaf PNG, GIF ve benzeri biçimler sıkıştırılır; şeffaf alanlar beyaza dönüşür ve animasyonlar yalnızca ilk kareyi korur.';

  @override
  String get imageSettingsPageFooter =>
      'Sıkıştırma, görüntüler eklendiğinde yapılır. Daha önce kaydedilen veya gönderilen görüntüler etkilenmez. Sıkıştırılan görüntüler JPEG dosyası olarak gönderilir.';

  @override
  String get imageSettingsPageSendSectionTitle => 'Gönderme';

  @override
  String get imageSettingsPageMarkdownImageLinksTitle =>
      'Markdown görüntü bağlantılarını görüntü olarak gönder';

  @override
  String get imageSettingsPageMarkdownImageLinksSubtitle =>
      'Etkinleştirildiğinde, mesaj metninizdeki bir ![alt](url) bağlantısı görsel modellere görüntü olarak gönderilir. Kapalıyken düz metin olarak kalır. Kendi eklediğiniz görüntüler her zaman görüntü olarak gönderilir.';

  @override
  String get memoryTraceSettingsTitle => 'İşlem Hattı İzleri';

  @override
  String get memoryTraceSettingsSubtitle =>
      'Her arka plan bellek çalışmasını adım adım inceleyin';

  @override
  String get memoryTracePageTitle => 'Bellek İşlem Hattı İzleri';

  @override
  String get memoryTraceRecordingSection => 'Kayıt';

  @override
  String get memoryTraceToggleTitle => 'İşlem hattı izlerini kaydet';

  @override
  String get memoryTraceToggleSubtitle =>
      'Son arka plan çalışmalarının istemlerini, yanıtlarını ve değişikliklerini yalnızca bellekte tutar';

  @override
  String get memoryTraceRunsSection => 'Son çalışmalar';

  @override
  String get memoryTraceEmptyTitle => 'Henüz iz yok';

  @override
  String get memoryTraceEmptySubtitle =>
      'Arka plan bellek işlem hattı çalıştıktan sonra izler burada görünür.';

  @override
  String get memoryTraceDisabledTitle => 'Kayıt kapalı';

  @override
  String get memoryTraceDisabledSubtitle =>
      'Bir sonraki arka plan bellek çalışmasını yakalamak için kaydı açın.';

  @override
  String get memoryTraceClearAction => 'Temizle';

  @override
  String get memoryTraceClearSheetTitle => 'İzleri temizle';

  @override
  String get memoryTraceClearSheetMessage =>
      'Bu işlem kaydedilmiş tüm izleri kaldırır. İzler hiçbir zaman diske yazılmaz, bu nedenle başka hiçbir şey etkilenmez.';

  @override
  String get memoryTraceClearConfirm => 'İzleri temizle';

  @override
  String get memoryTraceCancel => 'İptal';

  @override
  String get memoryTraceClearedToast => 'İz kayıtları temizlendi';

  @override
  String get memoryTraceCopyAction => 'Kopyala';

  @override
  String get memoryTraceCopiedToast => 'Panoya kopyalandı';

  @override
  String get memoryTraceTriggerAuto => 'Otomatik';

  @override
  String get memoryTraceTriggerManual => 'Manuel';

  @override
  String get memoryTraceTriggerTool => 'Araç çağrısı';

  @override
  String get memoryTraceTriggerSummary => 'Sohbet özeti';

  @override
  String get memoryTraceScopeAssistant => 'Asistan';

  @override
  String get memoryTraceScopeGlobal => 'Genel';

  @override
  String get memoryTraceStepGatekeeper => 'Ön denetim';

  @override
  String get memoryTraceStepExtract => 'Çıkarım';

  @override
  String get memoryTraceStepSmartAdd => 'Akıllı ekleme';

  @override
  String get memoryTraceStepDistiller => 'Profil damıtma';

  @override
  String get memoryTraceStepSummary => 'Sohbet özeti';

  @override
  String get memoryTraceStepChatSearch => 'Geçmiş sohbet hatırlama';

  @override
  String get memoryTraceStepTool => 'Bellek aracı';

  @override
  String get memoryTraceStatusSuccess => 'Başarılı';

  @override
  String get memoryTraceStatusFailed => 'Başarısız';

  @override
  String get memoryTraceStatusSkipped => 'Atlandı';

  @override
  String get memoryTraceStatusRunning => 'Çalışıyor';

  @override
  String get memoryTraceOutcomeAdvanced => 'İşaretçi ilerledi';

  @override
  String get memoryTraceOutcomeHeld => 'İşaretçi sabit kaldı';

  @override
  String get memoryTraceOutcomeForced => 'Zorla ilerletildi';

  @override
  String get memoryTraceDetailTitle => 'İz ayrıntısı';

  @override
  String get memoryTraceSectionOverview => 'Genel bakış';

  @override
  String get memoryTraceSectionPrompt => 'İstem';

  @override
  String get memoryTraceSectionResponse => 'Ham yanıt';

  @override
  String get memoryTraceSectionParsed => 'Ayrıştırılmış sonuç';

  @override
  String get memoryTraceSectionMutations => 'Uygulanan değişiklikler';

  @override
  String get memoryTraceFieldTime => 'Başlangıç';

  @override
  String get memoryTraceFieldDuration => 'Süre';

  @override
  String get memoryTraceFieldTrigger => 'Tetikleyici';

  @override
  String get memoryTraceFieldScope => 'Kapsam';

  @override
  String get memoryTraceFieldConversation => 'Sohbet';

  @override
  String get memoryTraceFieldAssistant => 'Asistan';

  @override
  String get memoryTraceFieldWindow => 'Pencere';

  @override
  String get memoryTraceFieldWatermark => 'İşaretçi';

  @override
  String get memoryTraceFieldOutcome => 'Sonuç';

  @override
  String get memoryTraceFieldError => 'Hata';

  @override
  String get memoryTraceMutationCreated => 'Oluşturuldu';

  @override
  String get memoryTraceMutationMerged => 'Birleştirildi';

  @override
  String get memoryTraceMutationEdited => 'Düzenlendi';

  @override
  String get memoryTraceMutationArchived => 'Arşivlendi';

  @override
  String get memoryTraceMutationLinked => 'İlişkilendirildi';

  @override
  String get memoryTraceMutationProfileWritten => 'Profil alanı yazıldı';

  @override
  String get memoryTraceMutationProfileCleared => 'Profil alanı temizlendi';

  @override
  String get memoryTraceMutationSummary => 'Sohbet özeti yazıldı';

  @override
  String get memoryTraceBefore => 'Önce';

  @override
  String get memoryTraceAfter => 'Sonra';

  @override
  String get memoryTraceEmptyValue => '(boş)';

  @override
  String memoryTraceStepsCount(int count) {
    return '$count adım';
  }

  @override
  String memoryTraceMutationsCount(int count) {
    return '$count değişiklik';
  }

  @override
  String memoryTraceRepeatCount(int count) {
    return '$count× tekrarlandı';
  }

  @override
  String memoryTraceWindowValue(int size, int start, int end) {
    return '$size mesaj · #$start–#$end';
  }

  @override
  String get memoryTraceShowMore => 'Tam metni göster';

  @override
  String get memoryTraceShowLess => 'Daralt';

  @override
  String get messageStyleSettingsPageTitle => 'Mesaj Stili';

  @override
  String get messageStyleSettingsPageReset => 'Sıfırla';

  @override
  String get messageStyleSettingsPageResetConfirm =>
      'Tüm mesaj stili özelleştirmeleri sıfırlansın mı?';

  @override
  String get messageStyleSettingsPageCancel => 'İptal';

  @override
  String get messageStyleSettingsPageLight => 'Açık';

  @override
  String get messageStyleSettingsPageDark => 'Koyu';

  @override
  String get messageStyleSettingsPageDefaultHint =>
      'Varsayılan stil geçerli temayı izler ve ek ayar içermez.';

  @override
  String get messageStyleSettingsPageStyleDefaultSubtitle =>
      'Temayı izler; özelleştirilemez';

  @override
  String get messageStyleSettingsPageAssistantFitContent =>
      'Asistan balonunu içeriğe sığdır';

  @override
  String get messageStyleSettingsPageAssistantFitContentSubtitle =>
      'Asistan balonları satırı doldurmak yerine metin genişliğine göre daralır';

  @override
  String get messageStyleSettingsPageAssistantSplitParagraphs =>
      'Paragrafları ayrı balonlara böl';

  @override
  String get messageStyleSettingsPageAssistantSplitParagraphsSubtitle =>
      'Asistan yanıtındaki boş satırlar her paragrafı ayrı bir balona böler';

  @override
  String get messageStyleSettingsPageStyleFrostedSubtitle =>
      'Yarı saydam buzlu cam';

  @override
  String get messageStyleSettingsPageStyleSolidSubtitle => 'Opak düz dolgu';

  @override
  String get messageStyleSettingsPageBlur => 'Bulanıklık';

  @override
  String get messageStyleSettingsPageBlurHint =>
      'Bulanıklık balonun arkasındaki içeriğe uygulanır. Sohbet duvar kağıdı olmadan pek görünmez.';

  @override
  String get messageStyleSettingsPageBackgroundColor => 'Arka plan';

  @override
  String get messageStyleSettingsPageBackgroundOpacity => 'Arka Plan Opaklığı';

  @override
  String get messageStyleSettingsPageBorderColor => 'Kenarlık';

  @override
  String get messageStyleSettingsPageBorderOpacity => 'Kenarlık Opaklığı';

  @override
  String get messageStyleSettingsPageBorderWidth => 'Kenarlık Genişliği';

  @override
  String get messageStyleSettingsPageTextColor => 'Metin';

  @override
  String get messageStyleSettingsPageCornerRadius => 'Köşe Yarıçapı';

  @override
  String get messageStyleSettingsPagePreviewUser =>
      'Bu bir kullanıcı mesajıdır';

  @override
  String get messageStyleSettingsPagePreviewAssistant =>
      'Bu bir asistan yanıtıdır.';

  @override
  String get messageStyleSettingsPagePreviewThinking => 'Düşünüyor';

  @override
  String get messageStyleSettingsPageRoleUser => 'Kullanıcı';

  @override
  String get messageStyleSettingsPageRoleAssistant => 'Asistan';

  @override
  String get messageStyleSettingsPageRoleAssistantHint =>
      'Asistan ayarları ayrıca düşünme, araç çağırma ve çeviri kartlarına da uygulanır.';

  @override
  String get localSnapshotSectionTitle => 'Yerel Kopyalar';

  @override
  String get localSnapshotEnabledTitle => 'Yerel kopyaları sakla';

  @override
  String get localSnapshotEnabledSubtitle =>
      'Kelivo veritabanının bir kopyasını düzenli olarak bu cihazda kaydeder, böylece verileriniz tek bir yerde kalmaz.';

  @override
  String get localSnapshotIntervalTitle => 'Sıklık';

  @override
  String get localSnapshotIntervalAutomatic => 'Otomatik';

  @override
  String get localSnapshotIntervalAutomaticDetail =>
      'Günlük; veritabanı büyüdükçe daha seyrek';

  @override
  String localSnapshotIntervalDays(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'Her $days günde bir',
      one: 'Her gün',
    );
    return '$_temp0';
  }

  @override
  String get localSnapshotKeepTitle => 'Saklanacak kopya sayısı';

  @override
  String localSnapshotKeepValue(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count kopya',
      one: '1 kopya',
    );
    return '$_temp0';
  }

  @override
  String get localSnapshotKeepSubtitle =>
      'Ayrıca geçen haftadan bir ve geçen aydan bir kopya saklanır, böylece fark edilmeyen bir sorun bile kurtarılabilir.';

  @override
  String get localSnapshotKeepWeekly => 'Geçen haftadan bir kopya sakla';

  @override
  String get localSnapshotKeepMonthly => 'Geçen aydan bir kopya sakla';

  @override
  String get localSnapshotKeepProtectedNote =>
      'Bu ayar ne olursa olsun, hâlâ veri içeren en son kopya otomatik olarak asla silinmez.';

  @override
  String get localSnapshotMaximumTitle => 'Alan sınırı';

  @override
  String get localSnapshotMaximumUnlimited => 'Sınır yok';

  @override
  String get localSnapshotAnnounceTitle => 'Kopya kaydedildiğinde bildir';

  @override
  String get localSnapshotAnnounceSubtitle =>
      'Hatalar her zaman bildirilir. Bu yalnızca başarı durumunda kısa bir mesaj ekler.';

  @override
  String get localSnapshotTakeNow => 'Şimdi bir kopya kaydet';

  @override
  String get localSnapshotManageCopies => 'Kopyaları yönet';

  @override
  String localSnapshotUsage(int count, String size) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count kopya',
      one: '1 kopya',
      zero: 'Kopya yok',
    );
    return '$_temp0 · $size';
  }

  @override
  String get localSnapshotStatusNever => 'Henüz kopya kaydedilmedi';

  @override
  String localSnapshotStatusSuccess(String when) {
    return 'Son kopya $when';
  }

  @override
  String localSnapshotStatusFailure(String when, String reason) {
    return 'Son deneme başarısız $when: $reason';
  }

  @override
  String get localSnapshotStatusSkippedSpace =>
      'Atlandı: bu cihazda yeterli boş alan yok';

  @override
  String get localSnapshotStatusUnchanged =>
      'Son kopyadan bu yana hiçbir şey değişmedi';

  @override
  String get localSnapshotCopiesTitle => 'Yerel Kopyalar';

  @override
  String get localSnapshotCopiesEmpty => 'Henüz yerel kopya yok';

  @override
  String get localSnapshotCopiesEmptyHint =>
      'Verileriniz değiştikçe otomatik olarak bir kopya kaydedilir ve geri yüklemeden önce her zaman bir kopya kaydedilir.';

  @override
  String get localSnapshotCopiesScopeNote =>
      'Yerel kopyalar yalnızca bu cihazda bulunur. Uygulama içindeki verilerinizin zarar görmesine karşı korur; cihazın kaybolmasına veya Kelivo\'nun kaldırılmasına karşı korumaz — bunun için WebDAV veya S3 yedeğini kullanın.';

  @override
  String get localSnapshotOriginAutomatic => 'Otomatik';

  @override
  String get localSnapshotOriginManual => 'Sizin kaydettiğiniz';

  @override
  String get localSnapshotOriginBeforeRestore => 'Geri yüklemeden önce';

  @override
  String get localSnapshotKindRecovered => 'Kurtarma tarafından ayrılan';

  @override
  String localSnapshotCopyContents(int conversations, int messages) {
    String _temp0 = intl.Intl.pluralLogic(
      conversations,
      locale: localeName,
      other: '$conversations sohbet',
      one: '1 sohbet',
    );
    String _temp1 = intl.Intl.pluralLogic(
      messages,
      locale: localeName,
      other: '$messages mesaj',
      one: '1 mesaj',
    );
    return '$_temp0 · $_temp1';
  }

  @override
  String get localSnapshotCopyContentsUnknown =>
      'İçerik geri yüklenene kadar bilinmiyor';

  @override
  String get localSnapshotCopyPinned => 'Saklanıyor';

  @override
  String get localSnapshotActionRestore => 'Geri yükle';

  @override
  String get localSnapshotActionExport => 'Dışa aktar';

  @override
  String get localSnapshotActionDelete => 'Sil';

  @override
  String get localSnapshotActionPin => 'Bu kopyayı sakla';

  @override
  String get localSnapshotActionUnpin => 'Saklamayı bırak';

  @override
  String get localSnapshotRestoreTitle => 'Bu kopya geri yüklensin mi?';

  @override
  String localSnapshotRestoreMessage(String when) {
    return 'Mevcut sohbetleriniz ve ayarlarınız $when tarihli bu kopyayla değiştirilecek. Önce mevcut sohbetleriniz ve ayarlarınızın bir kopyası kaydedilir. Gönderilmemiş taslaklar kopyalara dahil edilmez ve temizlenir.';
  }

  @override
  String get localSnapshotRestorePreparing => 'Kopya hazırlanıyor';

  @override
  String get localSnapshotDeleteTitle => 'Bu kopya silinsin mi?';

  @override
  String get localSnapshotDeleteMessage =>
      'Bu kopya cihazdan kalıcı olarak kaldırılacak. İçerdiği ve mevcut veritabanınızda bulunmayan tüm veriler kaybolacak.';

  @override
  String get localSnapshotDeleteLastWarning =>
      'Bu, hâlâ veri içeren tek kopya.';

  @override
  String get localSnapshotExportPreparing => 'Dışa aktarma hazırlanıyor';

  @override
  String get localSnapshotExportDone => 'Kopya dışa aktarıldı';

  @override
  String localSnapshotExportFailed(String reason) {
    return 'Kopya dışa aktarılamadı: $reason';
  }

  @override
  String get localSnapshotTakeDone => 'Kopya kaydedildi';

  @override
  String localSnapshotTakeFailed(String reason) {
    return 'Kopya kaydedilemedi: $reason';
  }

  @override
  String get localSnapshotDeleteDone => 'Kopya silindi';

  @override
  String get localSnapshotBusyMessage =>
      'Başka bir yedekleme görevi zaten çalışıyor';

  @override
  String get localSnapshotRunInBackground => 'Arka planda devam et';

  @override
  String get localSnapshotRunningInBackground =>
      'Arka planda bir kopya kaydediliyor';

  @override
  String startupRecoveryLocalCopiesAvailable(int count, String when) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count yerel kopya',
      one: '1 yerel kopya',
    );
    return 'Bu cihazda hâlâ $_temp0 var, en sonuncusu $when tarihli. Sıfırlama bunları silmez — yeniden başlattıktan sonra Ayarlar › Yedekleme › Yerel Kopyalar bölümünden birini geri yükleyebilirsiniz.';
  }

  @override
  String startupRecoveryRecoveredCopiesDeleted(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count veritabanı kopyası',
      one: '1 veritabanı kopyası',
    );
    String _temp1 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'onları',
      one: 'onu',
    );
    String _temp2 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Onları',
      one: 'Onu',
    );
    return 'Ayrıca daha önceki bir onarım tarafından ayrılan $_temp0 da var ve sıfırlama $_temp1 kalıcı olarak SİLER. $_temp2 saklamak istiyorsanız önce verilerinizi dışa aktarın.';
  }

  @override
  String get toolSchemaSettingsPageTitle => 'Araç Açıklamaları';

  @override
  String get toolSchemaSettingsGroupSearch => 'Arama';

  @override
  String get toolSchemaSettingsGroupImages => 'Görseller';

  @override
  String get toolSchemaSettingsGroupMemory => 'Bellek';

  @override
  String get toolSchemaSettingsGroupLocal => 'Cihaz araçları';

  @override
  String get toolSchemaSettingsModified => 'Değiştirildi';

  @override
  String get toolSchemaSettingsResetDefault => 'Varsayılana dön';

  @override
  String get toolSchemaSettingsResetAll => 'Tüm varsayılanları geri yükle';

  @override
  String get toolSchemaSettingsResetAllTitle =>
      'Tüm varsayılanlar geri yüklensin mi?';

  @override
  String get toolSchemaSettingsResetAllMessage =>
      'Bu işlem tüm yerleşik araç açıklamalarını uygulama varsayılanına geri yükler. Özel metinleriniz kaybolacak.';

  @override
  String get toolSchemaSettingsResetAllConfirm => 'Geri yükle';

  @override
  String toolSchemaSettingsParamDescriptions(int count) {
    return 'Parametre açıklamaları ($count)';
  }

  @override
  String get toolSchemaSettingsMemoryLangNote =>
      'Bellek aracı varsayılanları bellek istemi dilini izler. Özel bir açıklama araç başına bir kez saklanır ve o dili değiştirdiğinizde değişmez.';

  @override
  String get toolSchemaSettingsDescriptionLabel => 'Açıklama';

  @override
  String get toolSchemaSettingsToolName => 'Araç adı';

  @override
  String get toolSchemaEditorPageTitle => 'Açıklamayı düzenle';

  @override
  String get toolSchemaSettingsCancel => 'İptal';

  @override
  String get workspaceFileNotAvailable => 'Dosya kullanılamıyor';

  @override
  String get workspaceTerminalNotAvailable => 'Terminal kullanılamıyor';

  @override
  String get workspacePreviewCopyPath => 'Yolu kopyala';

  @override
  String get workspacePreviewShare => 'Paylaş';

  @override
  String get workspacePreviewOpenExternally => 'Harici olarak aç';

  @override
  String get workspacePreviewOpenWith => 'Şununla aç…';

  @override
  String get workspacePreviewFileTooLarge =>
      'Bu dosya önizleme için çok büyük. Bunun yerine harici olarak açın.';

  @override
  String get workspacePreviewSource => 'Kaynak';

  @override
  String get workspacePreviewRendered => 'İşlenmiş';

  @override
  String get workspacePreviewFileName => 'Ad';

  @override
  String get workspacePreviewFileSize => 'Boyut';

  @override
  String get workspacePreviewFileModified => 'Değiştirilme';

  @override
  String get workspacePreviewPathCopied => 'Yol kopyalandı';

  @override
  String workspacePreviewLineCount(int count) {
    return '$count satır';
  }

  @override
  String get workspaceFilesSort => 'Sırala';

  @override
  String get workspaceFilesSortName => 'Ad';

  @override
  String get workspaceFilesSortModified => 'Değiştirilme';

  @override
  String get workspaceFilesSortSize => 'Boyut';

  @override
  String get workspaceFilesSortAscending => 'Artan';

  @override
  String get workspaceFilesSortDescending => 'Azalan';

  @override
  String get workspaceFilesShowHidden => 'Gizli dosyaları göster';

  @override
  String get workspaceFilesHideHidden => 'Gizli dosyaları gizle';

  @override
  String get workspaceFilesRefresh => 'Yenile';

  @override
  String get workspaceFilesNewFolder => 'Yeni klasör';

  @override
  String get workspaceFilesNewFile => 'Yeni dosya';

  @override
  String get workspaceFilesImport => 'İçe aktar';

  @override
  String get workspaceFilesExport => 'Dışa aktar';

  @override
  String get workspaceFilesExportFolder => 'Klasörü dışa aktar';

  @override
  String get workspaceFilesEmpty => 'Bu klasör boş';

  @override
  String get workspaceFilesError => 'Bu dosyalar yüklenemedi';

  @override
  String get workspaceFilesRetry => 'Yeniden dene';

  @override
  String get workspaceFilesPreview => 'Önizle';

  @override
  String get workspaceFilesRename => 'Yeniden adlandır';

  @override
  String get workspaceFilesMove => 'Taşı';

  @override
  String get workspaceFilesDelete => 'Sil';

  @override
  String get workspaceFilesShare => 'Paylaş';

  @override
  String get workspaceFilesCopyPath => 'Yolu kopyala';

  @override
  String get workspaceFilesExportItem => 'Dışa aktar';

  @override
  String get workspaceFilesNameLabel => 'Ad';

  @override
  String get workspaceFilesNameHint => 'Bir ad girin';

  @override
  String get workspaceFilesCreate => 'Oluştur';

  @override
  String get workspaceFilesCancel => 'İptal';

  @override
  String get workspaceFilesConfirm => 'Onayla';

  @override
  String get workspaceFilesSave => 'Kaydet';

  @override
  String get workspaceFilesDeleteTitle => 'Bu öğe silinsin mi?';

  @override
  String workspaceFilesDeleteMessage(String name) {
    return '$name silinsin mi?';
  }

  @override
  String workspaceFilesDeleteFolderMessage(String name) {
    return '$name klasörü ve içindeki her şey silinsin mi?';
  }

  @override
  String get workspaceFilesMoveTitle => 'Klasöre taşı';

  @override
  String get workspaceFilesMoveHere => 'Buraya taşı';

  @override
  String get workspaceFilesPathCopied => 'Yol kopyalandı';

  @override
  String get workspaceFilesInvalidName => 'Bu ad geçerli değil';

  @override
  String get workspaceFilesInvalidPath => 'Bu yol bu klasörün dışında';

  @override
  String workspaceFilesOperationFailed(String error) {
    return 'Bu işlem tamamlanamadı: $error';
  }

  @override
  String get workspaceFilesActions => 'İşlemler';

  @override
  String get workspaceFilesMore => 'Daha fazla';

  @override
  String get workspaceFilesJustNow => 'Az önce';

  @override
  String workspaceFilesMinutesAgo(int count) {
    return '$count dk önce';
  }

  @override
  String workspaceFilesHoursAgo(int count) {
    return '$count sa önce';
  }

  @override
  String workspaceFilesDaysAgo(int count) {
    return '$count gün önce';
  }

  @override
  String get workspaceFilesPanelTitle => 'Sohbet dosyaları';

  @override
  String get workspaceFilesTabAttachments => 'Ekler';

  @override
  String get workspaceFilesTabOutputs => 'Çıktılar';

  @override
  String get workspaceFilesTabWorkspace => 'Çalışma alanı';

  @override
  String get workspaceFilesNoWorkspaceBound => 'Bağlı çalışma alanı yok';

  @override
  String get workspaceFilesKindManaged => 'Yönetilen';

  @override
  String get workspaceFilesKindLinked => 'Bağlantılı';

  @override
  String get workspaceFilesMissingWorkspace => 'Çalışma alanı bulunamadı';

  @override
  String get workspaceFilesClose => 'Kapat';

  @override
  String get workspacesTitle => 'Çalışma alanları';

  @override
  String get workspacesCreate => 'Oluştur';

  @override
  String get workspacesCreateTitle => 'Yeni çalışma alanı';

  @override
  String get workspacesNameLabel => 'Ad';

  @override
  String get workspacesNameHint => 'Çalışma alanı adı';

  @override
  String get workspacesLinkFolder => 'Klasör bağla';

  @override
  String get workspacesEmpty => 'Henüz çalışma alanı yok';

  @override
  String get workspacesEmptyCta => 'Bir çalışma alanı oluştur';

  @override
  String get workspacesSettings => 'Ayarlar';

  @override
  String get workspacesOpenFiles => 'Dosyaları aç';

  @override
  String get workspacesLastUsedNever => 'Hiç kullanılmadı';

  @override
  String workspacesLastUsed(String when) {
    return 'Son kullanım $when';
  }

  @override
  String get workspacesDeleteTitle => 'Bu çalışma alanı silinsin mi?';

  @override
  String workspacesDeleteMessage(String name) {
    return '$name çalışma alanı silinsin mi?';
  }

  @override
  String get workspacesDeleteAlsoFiles => 'Dosyaları da sil';

  @override
  String get workspacesUnlinkTitle =>
      'Bu çalışma alanının bağlantısı kaldırılsın mı?';

  @override
  String workspacesUnlinkMessage(String name) {
    return '$name bağlantısı kaldırılsın mı? Diskteki dosyalar korunacak.';
  }

  @override
  String get workspacesSettingsTitle => 'Çalışma alanı ayarları';

  @override
  String get workspacesShellNeedsApproval =>
      'Kabuk komutlarını çalıştırmadan önce sor';

  @override
  String get workspacesDefaultCwd => 'Varsayılan çalışma dizini';

  @override
  String get workspacesDefaultCwdHint => 'Göreli yol, örn. src';

  @override
  String get workspacesDefaultCwdInvalid =>
      '.. içermeyen göreli bir yol kullanın';

  @override
  String get workspacesCreateManaged => 'Çalışma alanı oluştur';

  @override
  String get workspacesLinkExisting => 'Mevcut bir klasörü bağla';

  @override
  String get workspacesUnlink => 'Bağlantıyı kaldır';

  @override
  String get workspacesItemMore => 'Çalışma alanı işlemleri';

  @override
  String get workspaceToolDenied => 'Reddedildi';

  @override
  String get workspaceToolTimeout => 'zaman aşımı';

  @override
  String get workspaceToolCancelled => 'iptal edildi';

  @override
  String get workspaceToolInterrupted => 'kesildi';

  @override
  String get workspaceToolEnvironmentNotReady => 'Sandbox ortamı yüklü değil';

  @override
  String get workspaceToolInstall => 'Yükle';

  @override
  String get workspaceToolFuzzy => 'yaklaşık';

  @override
  String get workspaceToolCreated => 'oluşturuldu';

  @override
  String get workspaceToolUpdated => 'güncellendi';

  @override
  String get workspaceToolTruncated => 'kısaltıldı';

  @override
  String get workspaceToolImageTag => 'görsel';

  @override
  String get workspaceToolStdout => 'stdout';

  @override
  String get workspaceToolStderr => 'stderr';

  @override
  String get workspaceToolOpenFullOutput => 'Tam çıktıyı aç';

  @override
  String get workspaceToolChangedFiles => 'Değişen dosyalar';

  @override
  String get workspaceToolCancel => 'İptal';

  @override
  String get workspaceToolCopyCommand => 'Komutu kopyala';

  @override
  String get workspaceToolCopyOutput => 'Çıktıyı kopyala';

  @override
  String get workspaceToolCopyDiff => 'Farkı kopyala';

  @override
  String get workspaceToolCopied => 'Kopyalandı';

  @override
  String get workspaceToolDiffTruncated => 'Fark kısaltıldı';

  @override
  String get workspaceToolOpenPreview => 'Önizlemeyi aç';

  @override
  String get workspaceToolNoOutput => 'Çıktı yok';

  @override
  String get workspaceToolNotAvailable => 'Kullanılamıyor';

  @override
  String get workspaceToolClose => 'Kapat';

  @override
  String get workspaceToolTitleShell => 'Komut çalıştır';

  @override
  String get workspaceToolTitleReadFile => 'Dosyayı oku';

  @override
  String get workspaceToolTitleViewImage => 'Görseli görüntüle';

  @override
  String get workspaceToolTitleWriteFile => 'Dosyaya yaz';

  @override
  String get workspaceToolTitleEditFile => 'Dosyayı düzenle';

  @override
  String get workspaceToolTitleListDir => 'Dizini listele';

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
    return '${ms}ms';
  }

  @override
  String workspaceToolDurationSec(String sec) {
    return '${sec}sn';
  }

  @override
  String get workspaceEnvTitle => 'Ortam';

  @override
  String workspaceEnvEngineUbuntu(String version) {
    return 'Ubuntu $version (PRoot)';
  }

  @override
  String workspaceEnvEngineAlpine(String version) {
    return 'Alpine $version (iSH)';
  }

  @override
  String get workspaceEnvEngineNative => 'Yerel kabuk';

  @override
  String get workspaceEnvPhaseNotInstalled => 'Yüklü değil';

  @override
  String get workspaceEnvPhaseDownloading => 'İndiriliyor';

  @override
  String get workspaceEnvPhaseVerifying => 'Doğrulanıyor';

  @override
  String get workspaceEnvPhaseExtracting => 'Çıkarılıyor';

  @override
  String get workspaceEnvPhasePatching => 'Yapılandırılıyor';

  @override
  String get workspaceEnvPhaseReady => 'Hazır';

  @override
  String get workspaceEnvPhaseError => 'Hata';

  @override
  String get workspaceEnvPhaseNeedsRestart => 'Yeniden başlatma gerekli';

  @override
  String workspaceEnvMetaLine(String version, String arch) {
    return '$version · $arch';
  }

  @override
  String workspaceEnvInstalledAt(String date) {
    return 'Kurulum tarihi $date';
  }

  @override
  String workspaceEnvDiskUsage(String size) {
    return 'Disk kullanımı $size';
  }

  @override
  String workspaceEnvRuntimeReason(String reason) {
    return '$reason';
  }

  @override
  String get workspaceEnvInstall => 'Kur';

  @override
  String get workspaceEnvInstallSubtitleAndroid =>
      'Ubuntu, Alpine, Debian seçin veya yerel bir rootfs imajı içe aktarın.';

  @override
  String get workspaceEnvInstallSubtitleIos => 'Dahili, indirme gerekmez';

  @override
  String get workspaceEnvCancel => 'İptal';

  @override
  String get workspaceEnvRetry => 'Yeniden dene';

  @override
  String get workspaceEnvRepair => 'Onar';

  @override
  String get workspaceEnvReset => 'Sıfırla';

  @override
  String get workspaceEnvResetConfirmTitle => 'Ortam sıfırlansın mı?';

  @override
  String get workspaceEnvResetConfirmBody =>
      'Bu işlem yüklü paketleri ve sandbox dosya sistemini siler.';

  @override
  String get workspaceEnvCheckForUpdate => 'Güncellemeyi denetle';

  @override
  String get workspaceEnvUpdate => 'Güncelle';

  @override
  String workspaceEnvAvailableVersion(String version) {
    return 'Sürüm $version kullanılabilir';
  }

  @override
  String get workspaceEnvUpToDate => 'Güncel sürümü kullanıyorsunuz';

  @override
  String get workspaceEnvRestartBanner =>
      'Tamamlamak için Kelivo\'yu yeniden başlatın';

  @override
  String get workspaceEnvDetectingMirrors => 'En hızlı yansılar algılanıyor…';

  @override
  String workspaceEnvApplyingMirror(String category) {
    return '$category yansısı uygulanıyor…';
  }

  @override
  String get workspaceEnvMirrorsSection => 'Yansılar';

  @override
  String get workspaceEnvUseMirror => 'Yansı kullan';

  @override
  String get workspaceEnvDetect => 'Algıla';

  @override
  String get workspaceEnvOfficial => 'Resmî';

  @override
  String get workspaceEnvMirrorsDisabled =>
      'Yansı değişiklikleri sandbox içinde çalışır ve sandbox hazır olana kadar kullanılamaz.';

  @override
  String workspaceEnvMirrorsDisabledReason(String reason) {
    return 'Yansı değişiklikleri sandbox içinde çalışır ve kullanılamıyor: $reason';
  }

  @override
  String get workspaceEnvMirrorDetectTitle => 'Yansı hızı';

  @override
  String workspaceEnvMirrorLatency(int ms) {
    return '$ms ms';
  }

  @override
  String workspaceEnvMirrorFailed(String reason) {
    return '$reason';
  }

  @override
  String get workspaceEnvErrorUnsupportedAbi =>
      'Bu cihaz mimarisi desteklenmiyor.';

  @override
  String get workspaceEnvErrorArchitectureMismatch =>
      'Yüklü sandbox mimarisi bu uygulamayla eşleşmiyor. Devam etmek için sandbox\'ı yeniden yükleyin. Mevcut sandbox dosyalarınız korundu.';

  @override
  String get workspaceEnvErrorProotMissing => 'PRoot ikili dosyası eksik.';

  @override
  String get workspaceEnvErrorInsufficientDisk =>
      'Sandbox\'ı yüklemek için yeterli boş depolama alanı yok.';

  @override
  String get workspaceEnvErrorInsufficientDiskHint =>
      'Seçilen imaj için daha fazla depolama alanı boşaltıp yeniden deneyin.';

  @override
  String get workspaceEnvErrorNetwork =>
      'İndirme başarısız oldu. Bağlantınızı denetleyip yeniden deneyin.';

  @override
  String get workspaceEnvErrorChecksumMismatch =>
      'İndirilen dosya bozuk. Yeniden deneyin.';

  @override
  String get workspaceEnvErrorExtractFailed => 'Sandbox imajı çıkarılamadı.';

  @override
  String get workspaceEnvErrorCleanupFailed =>
      'Eski sandbox dosyaları kaldırılamadı. Lütfen yeniden deneyin.';

  @override
  String get workspaceEnvCleanupIncomplete =>
      'Sandbox hazır, ancak bazı eski dosyalar kaldırılamadı. Hâlâ depolama alanı kaplıyorlar.';

  @override
  String get workspaceEnvErrorResetFailed =>
      'Sandbox sıfırlama tamamlanamadı. Lütfen yeniden deneyin.';

  @override
  String get workspaceEnvErrorPatchFailed => 'Sandbox kurulumu tamamlanamadı.';

  @override
  String get workspaceEnvErrorRepairInterrupted =>
      'Sandbox onarımı kesintiye uğradı. Mevcut sandbox korundu. Onarımı tamamlamak için yeniden deneyin.';

  @override
  String get workspaceEnvErrorRepairTimeout =>
      'Sandbox onarımı zaman aşımına uğradı. Ağ bağlantınızı kontrol edip yeniden deneyin. Mevcut sandbox korundu.';

  @override
  String get workspaceEnvRepairRestartBanner =>
      'Sandbox onarımının zaman sınırı içinde durduğu doğrulanamadı. Yeniden denemeden önce Kelivo\'yu tamamen kapatıp yeniden açın. Mevcut sandbox korundu.';

  @override
  String get workspaceEnvErrorCancelled => 'Yükleme iptal edildi.';

  @override
  String get workspaceEnvErrorGeneric =>
      'Sandbox yüklenirken bir sorun oluştu.';

  @override
  String get workspaceEnvChipInstall => 'Sandbox yükle';

  @override
  String workspaceEnvChipInstalling(int percent) {
    return 'Yükleniyor… %$percent';
  }

  @override
  String get workspaceEnvChipInstallingIndeterminate => 'Yükleniyor…';

  @override
  String get workspaceEnvChipError => 'Sandbox hatası';

  @override
  String get workspaceEnvChipRestart => 'Yeniden başlatma gerekli';

  @override
  String get workspaceEnvNativeExplanation =>
      'Masaüstünde Kelivo, Linux sandbox yerine sistem kabuğunuzu kullanır.';

  @override
  String workspaceEnvNativeShellPath(String path) {
    return 'Kabuk: $path';
  }

  @override
  String get workspaceEnvNativeShellApproval =>
      'Onay isteme modunda kabuk aracı onay gerektirir.';

  @override
  String workspaceEnvDownloadProgress(
    String downloaded,
    String total,
    int percent,
  ) {
    return '$downloaded / $total MB (%$percent)';
  }

  @override
  String get workspaceEnvMirrorsFailed => 'Aynalar algılanamadı';

  @override
  String get workspaceEnvCategoryApt => 'APT';

  @override
  String get workspaceEnvCategoryApk => 'APK';

  @override
  String get workspaceEnvCategoryPip => 'pip';

  @override
  String get workspaceEnvCategoryNpm => 'npm';

  @override
  String get skillsTitle => 'Beceriler';

  @override
  String get skillsTab => 'Beceriler';

  @override
  String get skillsSearchHint => 'Beceri ara';

  @override
  String get skillsEmptyTitle => 'Henüz beceri yok';

  @override
  String get skillsEmptyBody =>
      'Beceri, SKILL.md dosyası içeren bir klasördür. Markdown yapıştırın, .md veya .zip dosyası içe aktarın ya da bir GitHub URL\'si kullanın.';

  @override
  String get skillsEmptyFormat =>
      '---\nname: my-skill\ndescription: Bu becerinin ne yaptığı\n---\n\n# Talimatlar';

  @override
  String get skillsImport => 'İçe aktar';

  @override
  String get skillsImportPaste => 'Markdown yapıştır';

  @override
  String get skillsImportFile => 'Dosyadan';

  @override
  String get skillsImportGitHub => 'GitHub\'dan';

  @override
  String get skillsImportPasteLabel => 'SKILL.md';

  @override
  String get skillsImportPasteHint =>
      'YAML ön bilgisi içeren bir SKILL.md yapıştırın';

  @override
  String get skillsImportGitHubLabel => 'GitHub URL\'si';

  @override
  String get skillsImportGitHubHint =>
      'github.com/owner/repo veya github.com/owner/repo/tree/ref/path';

  @override
  String get skillsImportConfirm => 'İçe aktar';

  @override
  String get skillsCancel => 'İptal';

  @override
  String get skillsSave => 'Kaydet';

  @override
  String skillsUsedCount(int count) {
    return '$count kez kullanıldı';
  }

  @override
  String get skillsEnabled => 'Etkin';

  @override
  String get skillsBrowseFiles => 'Dosyalara göz at';

  @override
  String get skillsEdit => 'Düzenle';

  @override
  String get skillsExport => 'Dışa aktar';

  @override
  String get skillsDelete => 'Sil';

  @override
  String get skillsDeleteTitle => 'Bu beceri silinsin mi?';

  @override
  String skillsDeleteMessage(String name) {
    return '$name silinsin mi? Bu işlem geri alınamaz.';
  }

  @override
  String get skillsUseAll => 'Tüm becerileri kullan';

  @override
  String get skillsUseAllSubtitle =>
      'Etkin olan tüm beceriler bu asistan tarafından kullanılabilir.';

  @override
  String get skillsDisabledHint =>
      'Burada kullanmak için beceriyi Beceriler sayfasında etkinleştirin.';

  @override
  String get skillsOpenPage => 'Becerileri yönet';

  @override
  String get skillsInheritAssistant => 'Asistandan devral';

  @override
  String get skillsInheritAssistantSubtitle =>
      'Bu sohbetin asistanıyla aynı becerileri kullanın.';

  @override
  String get skillsActiveLabel => 'Etkin';

  @override
  String get skillsSessionTitle => 'Bu sohbet için beceriler';

  @override
  String get skillsEditTitle => 'Beceriyi düzenle';

  @override
  String get skillsDetailKindLabel => 'Beceri';

  @override
  String get skillsNoEnabled => 'Etkin beceri yok';

  @override
  String get terminalTitle => 'Terminal';

  @override
  String get terminalOpenInSystem => 'Sistem terminalinde aç';

  @override
  String get terminalHostDirectory => 'Ana makine dizini';

  @override
  String get terminalBindWorkspaceFirst => 'Önce bir çalışma alanı bağlayın';

  @override
  String get terminalNotAvailable => 'Kullanılamıyor';

  @override
  String get terminalRuntimeUnavailable => 'Terminal ortamı hazır değil';

  @override
  String get terminalRename => 'Yeniden adlandır';

  @override
  String get terminalClose => 'Kapat';

  @override
  String get terminalClear => 'Temizle';

  @override
  String get terminalCloseSession => 'Oturumu kapat';

  @override
  String get terminalCopy => 'Kopyala';

  @override
  String get terminalPaste => 'Yapıştır';

  @override
  String get terminalNewSession => 'Yeni oturum';

  @override
  String get terminalMore => 'Daha fazla';

  @override
  String get terminalNameLabel => 'Ad';

  @override
  String get terminalCancel => 'İptal';

  @override
  String get terminalSave => 'Kaydet';

  @override
  String get workspaceDeskMenuWorkspace => 'Çalışma alanı';

  @override
  String get workspaceDeskMenuSkills => 'Beceriler';

  @override
  String get workspaceDeskBarTitle => 'Çalışma alanı';

  @override
  String get workspaceDeskBarNoWorkspace => 'Çalışma alanı yok';

  @override
  String get workspaceDeskBarEmptyHint =>
      'Dosyaları burada görüntülemek için araç çubuğundan bir çalışma alanı bağlayın';

  @override
  String get workspaceDeskBarToggle => 'Çalışma alanı dosyaları';

  @override
  String get workspaceDeskOpenSystemTerminal => 'Sistem terminalinde aç';

  @override
  String get workspaceDeskReveal => 'Dosya yöneticisinde göster';

  @override
  String get workspaceDeskBarClose => 'Çalışma alanı çubuğunu kapat';

  @override
  String get workspaceEntryBind => 'Çalışma alanı bağla';

  @override
  String get workspaceEntryUnbind => 'Bağlantıyı kaldır';

  @override
  String get workspaceEntryChange => 'Değiştir';

  @override
  String get workspaceEntrySetAssistantDefault =>
      'Asistan varsayılanı olarak ayarla';

  @override
  String get workspaceEntryLocked => 'Kilitli';

  @override
  String get workspaceEntryChangeConfirmTitle =>
      'Çalışma alanı değiştirilsin mi?';

  @override
  String get workspaceEntryUnbindConfirmTitle => 'Bağlantı kaldırılsın mı?';

  @override
  String get workspaceEntryChangeConfirmBody =>
      'Bu sohbet zaten çalışma alanı araçlarını kullandı. Önceki mesajlardaki dosya bağlantıları artık çalışmayabilir.';

  @override
  String get workspaceEntryCwd => 'Çalışma dizini';

  @override
  String get workspaceEntryCwdHint => 'Çalışma alanı köküne göre';

  @override
  String get workspaceEntryCwdInvalid =>
      'Bu yol geçersiz veya çalışma alanının dışında';

  @override
  String get workspaceEntryCwdMissing => 'Bu dizin mevcut değil';

  @override
  String get workspaceEntryCwdCreate => 'Oluştur';

  @override
  String get workspaceEntryFiles => 'Dosyalar';

  @override
  String get workspaceEntryTerminal => 'Terminal';

  @override
  String get workspaceEntryOpenSystemTerminal => 'Sistem terminalinde aç';

  @override
  String get workspaceEntryReveal => 'Dosya yöneticisinde göster';

  @override
  String get workspaceEntrySessionSkills => 'Beceriler';

  @override
  String get workspaceEntryEnvironment => 'Ortam';

  @override
  String get workspaceEntryManage => 'Çalışma alanlarını yönet';

  @override
  String get workspaceEntryCreate => 'Yeni çalışma alanı oluştur…';

  @override
  String get workspaceEntryDefaultWorkspace => 'Varsayılan çalışma alanı';

  @override
  String get workspaceEntryDefaultWorkspaceSubtitle =>
      'Yeni sohbetler bu çalışma alanını kullanır. Mevcut sohbetler değişmez.';

  @override
  String get workspaceEntryDefaultWorkspaceUnset => 'Ayarlanmadı';

  @override
  String get workspaceEntryDefaultWorkspaceAutomaticSubtitle =>
      'Bir sohbete bağladığınız ilk çalışma alanı yeni sohbetler için hatırlanır.';

  @override
  String workspaceBindingRememberedDefault(String assistant) {
    return '“$assistant” için varsayılan çalışma alanı olarak hatırlandı. Yeni sohbetler bunu kullanacak.';
  }

  @override
  String workspaceBindingSuggestDefault(String assistant) {
    return 'Bu çalışma alanı “$assistant” ile gelecekteki sohbetlerde de kullanılsın mı?';
  }

  @override
  String get workspaceBindingUndoDefault => 'Geri al';

  @override
  String get workspaceBindingUseAsDefault => 'Varsayılan olarak ayarla';

  @override
  String get workspaceEntryNone => 'Yok';

  @override
  String get workspaceEntryStartConversationFirst => 'Önce bir sohbet başlatın';

  @override
  String get workspaceEntryTooltip => 'Çalışma alanı';

  @override
  String get workspaceEntryPickerTitle => 'Bir çalışma alanı seçin';

  @override
  String get settingsPageWorkspace => 'Çalışma alanı ve ortam';

  @override
  String get settingsPageSkills => 'Beceriler';

  @override
  String get commonClose => 'Kapat';

  @override
  String get terminalCopyAllOutput => 'Tüm çıktıyı kopyala';

  @override
  String get terminalFontDecrease => 'Yazı boyutu −';

  @override
  String get terminalFontIncrease => 'Yazı boyutu +';

  @override
  String get terminalCloseSessionConfirmMessage =>
      'Bu oturum hâlâ çalışıyor. Kapatmak süreci sonlandıracak.';

  @override
  String get terminalCopiedAll => 'Tüm çıktı kopyalandı';

  @override
  String get terminalConfirm => 'Onayla';

  @override
  String terminalExitCode(int code) {
    return 'exit $code';
  }

  @override
  String get workspaceMgmtNewWorkspace => 'Yeni çalışma alanı';

  @override
  String get workspaceMgmtEmptyHint =>
      'Proje dosyalarını bir arada tutmak için bir çalışma alanı oluşturun.';

  @override
  String get workspaceMgmtKindManagedTitle => 'Yönetilen çalışma alanı';

  @override
  String get workspaceMgmtKindManagedSubtitle =>
      'Uygulama tarafından yönetilen klasör, sandbox okuma/yazma';

  @override
  String get workspaceMgmtKindLinkedTitle => 'Bağlı klasör';

  @override
  String get workspaceMgmtKindLinkedSubtitle =>
      'Bu bilgisayardaki bir klasörü kullan';

  @override
  String get workspaceMgmtImportFromFolder => 'Klasörden içe aktar';

  @override
  String get workspaceMgmtImportFromFolderSubtitle =>
      'Bir klasörü yeni yönetilen çalışma alanına kopyala';

  @override
  String get workspaceMgmtKindSection => 'Tür';

  @override
  String get workspaceMgmtCreate => 'Oluştur';

  @override
  String get workspaceMgmtShellApprovalSubtitle => 'Her komuttan önce sor';

  @override
  String get workspaceMgmtDefaultCwdRoot => '/';

  @override
  String get workspaceMgmtPickCwdTitle => 'Varsayılan çalışma dizini';

  @override
  String get workspaceMgmtFolderPickerUnavailable =>
      'Klasör seçici kullanılamıyor.';

  @override
  String get workspaceMgmtImportProgressTitle => 'Klasör içe aktarılıyor';

  @override
  String get workspaceMgmtImportProgressPhase => 'Dosyalar kopyalanıyor…';

  @override
  String get workspaceMgmtImportFailed => 'Bu klasör içe aktarılamadı.';

  @override
  String workspaceMgmtImportDone(String name) {
    return '$name içe aktarıldı';
  }

  @override
  String get workspaceMgmtLastUsedJustNow => 'az önce';

  @override
  String workspaceMgmtLastUsedMinutesAgo(int n) {
    return '$n dk önce';
  }

  @override
  String workspaceMgmtLastUsedHoursAgo(int n) {
    return '$n sa önce';
  }

  @override
  String workspaceMgmtLastUsedDaysAgo(int n) {
    return '$n gün önce';
  }

  @override
  String workspaceMgmtRowDetail(String kind, String when) {
    return '$kind · Son kullanım $when';
  }

  @override
  String workspaceMgmtRowDetailNever(String kind) {
    return '$kind · Hiç kullanılmadı';
  }

  @override
  String get workspacePreviewBack => 'Geri';

  @override
  String get workspacePreviewWrap => 'Satırları kaydır';

  @override
  String get workspacePreviewFontDecrease => 'Daha küçük metin';

  @override
  String get workspacePreviewFontIncrease => 'Daha büyük metin';

  @override
  String get workspacePreviewCopy => 'Kopyala';

  @override
  String get workspacePreviewRetry => 'Yeniden dene';

  @override
  String get workspacePreviewLoadError => 'Bu dosya yüklenemedi.';

  @override
  String get workspacePreviewRevealInFinder => 'Finder\'da göster';

  @override
  String get workspacePreviewOpenInSystemApp => 'Sistem uygulamasıyla aç';

  @override
  String get workspacePreviewOpenInBrowser => 'Tarayıcıda aç';

  @override
  String get workspacePreviewTable => 'Tablo';

  @override
  String get workspacePreviewPlainLanguage => 'Kod';

  @override
  String get workspacePreviewOpen => 'Aç';

  @override
  String get workspacePreviewRevealFailed =>
      'Bu dosya dosya yöneticisinde gösterilemedi.';

  @override
  String get workspacePreviewEmptyTable => 'Bu tablo boş.';

  @override
  String get workspaceFilesNew => 'Yeni';

  @override
  String get workspaceFilesFoldersFirst => 'Önce klasörler';

  @override
  String get workspaceFilesSelectDirectory => 'Bu klasörü seç';

  @override
  String get workspaceFilesEmptyHint =>
      'Dosya eklemek için Yeni veya İçe Aktar\'ı kullanın';

  @override
  String get workspaceFilesEmptyAttachments => 'Henüz ek yok';

  @override
  String get workspaceFilesEmptyOutputs =>
      'Asistan henüz herhangi bir dosya oluşturmadı';

  @override
  String get workspaceFilesMoveTo => 'Taşı…';

  @override
  String workspaceFilesItemCount(int count) {
    return '$count öğe';
  }

  @override
  String get skillsImportTooltip => 'Beceri içe aktar';

  @override
  String get skillsImportPasteSubtitle =>
      'YAML frontmatter içeren SKILL.md yapıştır';

  @override
  String get skillsImportFileSubtitle => 'Bir .md veya .zip dosyası seç';

  @override
  String get skillsImportGitHubSubtitle => 'Bir depodan SKILL.md içe aktar';

  @override
  String get skillsImportResolving => 'Depo çözümleniyor…';

  @override
  String get skillsImportDownloading => 'İndiriliyor…';

  @override
  String get skillsImportExtracting => 'Çıkarılıyor…';

  @override
  String get skillsImportInstalling => 'Yükleniyor…';

  @override
  String get skillsImportGitHubRepoLabel => 'Depo URL\'si';

  @override
  String get skillsImportGitHubUrlHint =>
      'https://github.com/owner/repo veya owner/repo[/path]';

  @override
  String get skillsImportGitHubHelp =>
      'Depo kökünde veya bir alt dizinde bulunan SKILL.md desteklenir.';

  @override
  String get skillsEmptyHint =>
      'Beceri, frontmatter içeren bir SKILL.md dosyasıdır. İçe aktarıldıktan sonra asistan gerektiğinde kullanabilir.';

  @override
  String get skillsMoreActions => 'Daha fazla';

  @override
  String get skillsSearchClear => 'Temizle';

  @override
  String get skillsSessionEmpty =>
      'Henüz etkinleştirilmiş beceri yok. Önce beceri kitaplığından becerileri etkinleştirin.';

  @override
  String get workspaceToolRunning => 'Çalışıyor';

  @override
  String workspaceToolExitCode(int code) {
    return 'exit $code';
  }

  @override
  String get workspaceToolAwaitingApproval => 'Onay bekleniyor';

  @override
  String get workspaceToolCompleted => 'Tamamlandı';

  @override
  String workspaceToolLines(int count) {
    return '$count satır';
  }

  @override
  String workspaceToolItems(int count) {
    return '$count öğe';
  }

  @override
  String workspaceToolFileMatches(int count) {
    return '$count eşleşme';
  }

  @override
  String workspaceToolContentMatches(int count) {
    return '$count eşleşme';
  }

  @override
  String get workspaceToolExpand => 'Genişlet';

  @override
  String get workspaceToolSectionCommand => 'Komut';

  @override
  String get workspaceToolSectionPath => 'Yol';

  @override
  String get workspaceToolSectionPattern => 'Desen';

  @override
  String get workspaceToolSectionOutput => 'Çıktı';

  @override
  String get workspaceToolSectionDiff => 'Fark';

  @override
  String get workspaceToolSectionError => 'Hata';

  @override
  String get workspaceToolSavedOutput => 'Tam çıktı kaydedildi';

  @override
  String get workspaceToolApprove => 'İzin ver';

  @override
  String get workspaceToolDeny => 'Reddet';

  @override
  String get workspaceToolCopy => 'Kopyala';

  @override
  String get workspaceEnvEngineLocalShell => 'Yerel shell';

  @override
  String get workspaceEnvInstallEnvironment => 'Ortamı yükle';

  @override
  String get workspaceEnvInstallDescription =>
      'Araçları bir sandbox içinde çalıştırmak için bir Linux ortamı yükleyin.';

  @override
  String get workspaceEnvStatusLabel => 'Durum';

  @override
  String get workspaceEnvStatusInstalled => 'Yüklendi';

  @override
  String get workspaceEnvSizeLabel => 'Boyut';

  @override
  String get workspaceEnvPathLabel => 'Yol';

  @override
  String get workspaceEnvInstalledAtLabel => 'Yüklenme';

  @override
  String get workspaceEnvArchLabel => 'Mimari';

  @override
  String workspaceEnvArchVersion(String arch, String version) {
    return '$arch · $version';
  }

  @override
  String get workspaceEnvBrowseSection => 'Gözat';

  @override
  String get workspaceEnvBrowseFiles => 'Dosya sistemine göz at';

  @override
  String get workspaceEnvBrowseFilesDetail =>
      'Sandbox içindeki tam dizin ağacını görüntüle';

  @override
  String get workspaceEnvDetectFastMirrors => 'Hızlı yansıları algıla';

  @override
  String get workspaceEnvActionsSection => 'İşlemler';

  @override
  String get workspaceEnvInfoSection => 'Bilgi';

  @override
  String get workspaceEnvInfoBody =>
      'Ortam, sandbox tarafından kullanılan bir Linux kök dosya sistemidir. Çalışma alanları ayrı olarak saklanır ve sıfırlama sırasında silinmez. Dosyalar bu cihazdaki açılmış rootfs içinde bulunur.';

  @override
  String get workspaceEnvRepairDetail => 'Dosyaları yeniden doğrula ve onar';

  @override
  String get workspaceEnvUpdateCurrent => 'Güncel sürümdesiniz';

  @override
  String workspaceEnvUpdateAvailableShort(String version) {
    return 'Güncelleme mevcut: $version';
  }

  @override
  String get workspaceEnvResetConfirmMessage =>
      'Bu işlem tüm Linux ortamını ve içinde yüklü paketleri siler. Çalışma alanı dosyaları etkilenmez.';

  @override
  String get workspaceEnvRestartDoneBanner =>
      'Sıfırlama tamamlandı. Yüklemeyi tamamlamak için uygulamayı yeniden başlatın.';

  @override
  String get workspaceEnvPathCopied => 'Yol kopyalandı';

  @override
  String get workspaceEnvUseMirrorSubtitle => 'Seçili yansıyı sandbox\'a yaz';

  @override
  String get workspaceEnvRegionGlobal => 'Global';

  @override
  String get workspaceEnvRegionChina => 'Çin';

  @override
  String get workspaceEnvRegionEurope => 'Avrupa';

  @override
  String get workspaceEnvRegionAsia => 'Asya';

  @override
  String get workspaceEnvMirrorTimeout => 'Zaman aşımı';

  @override
  String get workspaceEnvSpeedTest => 'Hız testi';

  @override
  String get workspaceEnvApplySuccess => 'Yansı uygulandı';

  @override
  String get workspaceEnvApplyFailed => 'Yansı uygulanamadı';

  @override
  String get workspaceEnvRestoreSuccess => 'Resmi kaynak geri yüklendi';

  @override
  String get workspaceEnvMirrorsTested => 'En hızlı yansılar uygulandı';

  @override
  String get workspaceEnvRelativeJustNow => 'Az önce';

  @override
  String workspaceEnvRelativeMinutesAgo(int count) {
    return '$count dk önce';
  }

  @override
  String workspaceEnvRelativeHoursAgo(int count) {
    return '$count sa önce';
  }

  @override
  String workspaceEnvRelativeDaysAgo(int count) {
    return '$count gün önce';
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
      'Komutlar bu bilgisayarda sandbox olmadan çalışır ve bu sohbet tam erişime sahip değilse onay gerektirir.';

  @override
  String get workspaceEnvRootfsTitle => '/';

  @override
  String get workspaceEnvBrowserUnavailable =>
      'Sandbox dosya sistemi kullanılamıyor.';

  @override
  String get workspaceEnvMirrorNameOfficial => 'Resmi';

  @override
  String get workspaceEnvMirrorNameOfficialCdn => 'Resmi CDN';

  @override
  String get workspaceEnvMirrorNameOfficialPypi => 'Resmi PyPI';

  @override
  String get workspaceEnvMirrorNameOfficialNpm => 'Resmi npm';

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
  String get workspaceEnvMirrorNameJaist => 'JAIST Japonya';

  @override
  String get workspaceEnvMirrorNameKakao => 'Kakao Kore';

  @override
  String get workspaceEnvMirrorNameNpmmirror => 'npmmirror';

  @override
  String workspaceEnvSelectionNamed(String name, String region) {
    return '$name · $region';
  }

  @override
  String get workspaceFilesEmptyPickerHint =>
      'Alt klasör eklemek için Yeni klasör\'ü kullanın';

  @override
  String get skillsDetailBodyEmpty => 'Henüz beceri içeriği yok';

  @override
  String skillsDetailBodyTooLarge(String size) {
    return 'Bu dosya önizleme için çok büyük ($size).';
  }

  @override
  String get workspaceEnvSizeTimeout => 'Zaman aşımı';

  @override
  String get workspaceEnvInfoCopied => 'Ortam bilgisi kopyalandı';

  @override
  String get workspacePreviewEmptyFile => 'Bu dosya boş';

  @override
  String get workspacePreviewEmptyHint => 'Önizlenecek bir şey yok.';

  @override
  String get workspacePreviewRevealInExplorer => 'Dosya Gezgini\'nde göster';

  @override
  String get workspacePreviewRevealInFileManager => 'Dosyalar\'da göster';

  @override
  String workspaceBindingSetAssistantDefault(String assistant) {
    return '“$assistant” için varsayılan çalışma alanı olarak ayarlandı';
  }

  @override
  String get storageSpaceCategoryWorkspaceFiles => 'Çalışma alanı dosyaları';

  @override
  String get storageSpaceCategoryWorkspaceFilesHint =>
      'Yönetilen çalışma alanlarında saklanan dosyalar.';

  @override
  String get storageSpaceCategorySandboxEnvironment => 'Sandbox ortamı';

  @override
  String get storageSpaceCategorySandboxEnvironmentHint =>
      'Sandbox kurulumu ve kök dosya sistemi.';

  @override
  String get storageSpaceCategorySkills => 'Beceriler';

  @override
  String get storageSpaceCategorySkillsHint => 'Yüklü beceri dosyaları.';

  @override
  String get storageSpaceCategorySessionFiles => 'Sohbet dosyaları';

  @override
  String get storageSpaceCategorySessionFilesHint =>
      'Sohbet başına ekler ve çıktılar.';

  @override
  String get storageSpaceManageSkills => 'Becerileri yönet';

  @override
  String get storageSessionFilesCleanOrphans =>
      'Sohbeti olmayan dosyaları temizle';

  @override
  String storageSessionFilesCleanOrphansHint(String size) {
    return 'Artık bir sohbete bağlı olmayan oturum klasörlerini siler. Geri kazanılabilir: $size.';
  }

  @override
  String get workspaceDesktopFolderPath => 'Klasör yolu';

  @override
  String get workspaceDesktopFolderMissing =>
      'Mevcut bir klasör seçin veya mutlak yolunu girin.';

  @override
  String get workspaceDesktopManagedHint =>
      'Kelivo bu proje için bir klasör oluşturur ve yönetir.';

  @override
  String get workspaceDesktopHostHint =>
      'Dosyalar ve komutlar bu bilgisayarı kullanır.';

  @override
  String get workspaceDesktopSearch => 'Çalışma alanlarında ara';

  @override
  String get workspaceDesktopNoResults => 'Eşleşen çalışma alanı yok';

  @override
  String get workspaceEnvDependencies => 'Ortam ön ayarları';

  @override
  String get workspaceEnvDependenciesDetail =>
      'Araçları paylaşılan sandbox\'a yükleyin. Tüm çalışma alanları bunları kullanabilir.';

  @override
  String get workspaceEnvDependencyPython => 'Python, pip ve sanal ortamlar';

  @override
  String get workspaceEnvDependencyNode => 'Node.js ve npm';

  @override
  String get workspaceEnvDependencyGit =>
      'Depoları klonlayın ve sürümleri yönetin';

  @override
  String get workspaceEnvDependencySsh => 'SSH, SCP, SFTP ve anahtar oluşturma';

  @override
  String get workspaceEnvDependencyNetwork => 'Ağ araçları';

  @override
  String get workspaceEnvDependencyArchive => 'Arşiv araçları';

  @override
  String get workspaceEnvDependencyInstalled => 'Yüklü';

  @override
  String get workspaceEnvDependencyUnknown => 'Denetlenmedi';

  @override
  String get workspaceEnvDependencyChecking => 'Araçlar denetleniyor…';

  @override
  String get workspaceEnvDependencyInstalling => 'Yükleniyor…';

  @override
  String get workspaceEnvDependencyCheckFailed =>
      'Araçlar denetlenemedi. Yeniden denemek için yenileyin.';

  @override
  String get workspaceEnvDependencyInstallFailed =>
      'Kurulum tamamlanmadı. Günlüğü kontrol edin veya paket kaynağını değiştirip yeniden deneyin.';

  @override
  String get workspaceEnvDependencyLog => 'Kurulum günlüğü';

  @override
  String get workspaceEnvDependencyRefresh => 'Araç durumunu yenile';

  @override
  String get workspaceEnvDependencyReadyFirst =>
      'Bu araçları eklemek için önce sandbox\'ı yükleyin.';

  @override
  String get workspaceEnvDependencySources => 'Paket kaynakları';

  @override
  String get workspaceEnvDependencySourcesDetail =>
      'Kurulum seçili apt/apk kaynağını kullanır. pip ve npm kaynakları daha sonra yükleyeceğiniz paketler için geçerlidir.';

  @override
  String get workspaceEnvDownloadSource => 'Sandbox indirme kaynağı';

  @override
  String get workspaceEnvDownloadAutomatic => 'En hızlısını otomatik seç';

  @override
  String get workspaceEnvDownloadAutomaticDetail =>
      'İndirmeden önce resmi kaynağı ve yerleşik yansıları test edin.';

  @override
  String get workspaceEnvDownloadCustom => 'Özel URL';

  @override
  String get workspaceEnvDownloadCustomHint =>
      'https://example.com/ubuntu-base/releases/24.04/release/';

  @override
  String get workspaceEnvDownloadCustomDetail =>
      'Bir sürüm dizini veya tam arşiv URL\'si girin. Arşiv, seçilen sistem, sürüm ve cihaz mimarisiyle eşleşmelidir.';

  @override
  String get workspaceEnvDownloadInvalidUrl =>
      'Geçerli bir HTTP veya HTTPS URL\'si girin.';

  @override
  String get workspaceEnvDownloadVerified =>
      'İndirmeler, seçilen imajın resmi SHA-256 değeriyle doğrulanır. Paket kaynakları ayrıca yapılandırılır.';

  @override
  String get workspaceEnvDownloadStart => 'İndir ve yükle';

  @override
  String get workspaceEnvDownloadSave => 'Kaynağı kaydet';

  @override
  String get workspaceToolsTitle => 'Araçlar';

  @override
  String get workspaceToolsDescription =>
      'Bu çalışma alanında sohbetlerin hangi araçları kullanabileceğini seçin. Değişiklikler otomatik kaydedilir.';

  @override
  String get workspaceToolHelpShell =>
      'Çalışma alanı ortamında komut çalıştırın.';

  @override
  String get workspaceToolHelpRead =>
      'Dosyaları satır numaralarıyla ve sayfalama ile okuyun.';

  @override
  String get workspaceToolHelpViewImage =>
      'Modelin çalışma alanındaki bir görseli incelemesine izin verin.';

  @override
  String get workspaceToolHelpWrite =>
      'Dosya oluşturun veya içeriklerinin üzerine yazın.';

  @override
  String get workspaceToolHelpEdit =>
      'Mevcut bir dosyadaki belirli metni değiştirin.';

  @override
  String get workspaceToolHelpList => 'Dizinlere ve içeriklerine göz atın.';

  @override
  String get workspaceToolHelpGlob =>
      'Dosyaları ad veya yol desenine göre bulun.';

  @override
  String get workspaceToolHelpGrep => 'Dosyaların içindeki metni arayın.';

  @override
  String get workspaceEnvVariablesTitle => 'Ortam değişkenleri';

  @override
  String get workspaceEnvVariablesEntryDetail =>
      'Komutlar için değişkenler ve çıktı gizliliği denetimleri';

  @override
  String get workspaceEnvVariablesEmpty =>
      'Henüz değişken yok. Araçlarınız için API anahtarları veya diğer yapılandırmaları ekleyin.';

  @override
  String get workspaceEnvVariablesScope =>
      'Tüm çalışma alanları tarafından paylaşılır. Değişiklikler yeni Agent komutlarına ve yeni uygulama içi terminal oturumlarına uygulanır; mevcut oturumları uygulamak için yeniden açın. Harici sistem terminalleri kendi ortamlarını korur.';

  @override
  String get workspaceEnvPrivacyMode => 'Gizlilik modu';

  @override
  String get workspaceEnvPrivacyDetail =>
      'Komutlar gerçek değerleri kullanabilir. Çalışma alanı araç çıktısı modele gönderilmed önce, en az 5 karakterlik eşleşen değerler [REDACTED] ile değiştirilir. Yerel günlükler değişmeden kalır. Yaygın bayrakların ve sayıların yanlışlıkla değiştirilmesini önlemek için daha kısa değerler maskelenmez.';

  @override
  String get workspaceEnvVariableAdd => 'Değişken ekle';

  @override
  String get workspaceEnvVariableEdit => 'Değişkeni düzenle';

  @override
  String get workspaceEnvVariableName => 'Ad';

  @override
  String get workspaceEnvVariableValue => 'Değer';

  @override
  String get workspaceEnvVariableNote => 'Not (isteğe bağlı)';

  @override
  String get workspaceEnvVariableNameHint =>
      'Harf, rakam ve alt çizgi kullanın; rakamla başlamayın. Adlar büyük/küçük harfe duyarlıdır. Komutlarda değişkenlere \$NAME ile başvurun.';

  @override
  String get workspaceEnvVariableInvalidName =>
      'Geçerli bir değişken adı girin.';

  @override
  String get workspaceEnvVariableInvalidValue =>
      'NUL karakteri içermeyen boş olmayan bir değer girin.';

  @override
  String get workspaceEnvVariableDuplicate =>
      'Bu ada sahip bir değişken zaten var.';

  @override
  String get workspaceEnvVariablesSaveFailed =>
      'Ortam ayarları kaydedilemedi. Lütfen tekrar deneyin.';

  @override
  String get incomingShareTitle => 'Paylaşılan içerik';

  @override
  String get incomingShareReplaceDraft =>
      'Giriş kutusunda gönderilmemiş içerik var. Yeni bir sohbette paylaşılan içerikle değiştirilsin mi?';

  @override
  String get incomingShareFailed =>
      'Bazı paylaşılan içerikler içe aktarılamadı. Dosya erişimini ve kullanılabilir depolamayı kontrol edin. Aynı anda en fazla 32 dosya paylaşılabilir.';

  @override
  String get incomingShareImporting => 'İçe aktarılıyor';

  @override
  String get incomingShareMoveTo => 'Şuraya taşı…';

  @override
  String get incomingShareNewChat => 'Yeni sohbet';

  @override
  String get incomingShareMoveHint =>
      'Bu taslağı ve eklerini başka bir sohbete taşıyın. Hiçbir şey otomatik olarak gönderilmez.';

  @override
  String get incomingShareNoConversations => 'Eşleşen sohbet yok';

  @override
  String get chatInputBarRemoveAttachment => 'Eki kaldır';

  @override
  String get incomingShareMoveFailed =>
      'Sohbetler arasında geçiş yapılamadı. Taslağınız korundu.';

  @override
  String attachmentRequiresWorkspace(String name) {
    return '“$name” kullanmak için bir çalışma alanı bağlayıp dosya araçlarını etkinleştirin veya bu taslağı çalışma alanı olan bir sohbete taşıyın. Bu dosya normal bir sohbette doğrudan okunamaz.';
  }

  @override
  String get storageSessionFilesUnlinked => 'Bağlantısız sohbet';

  @override
  String get workspaceExternalMount => 'Harici klasör bağla';

  @override
  String get workspaceExternalMountSubtitle =>
      'Seçilen klasörler /mounts/<name> konumuna bağlanır ve çalışma alanları arasında paylaşılır. AI araçları, Shell ve dosya tarayıcısı bunlara erişebilir. En fazla 10 klasör.';

  @override
  String get workspaceExternalStorageTitle => 'Dosya erişimine izin ver';

  @override
  String get workspaceExternalStorageMessage =>
      'Çalışma alanında ve Shell\'de harici klasörleri okuyup yazmak için Android ayarlarından Kelivo\'nun dosyaları yönetmesine izin verin. Android 11 veya üzerinde tüm dosyalara erişimi etkinleştirin. Ardından bağlamak için cihazdaki bir klasörü seçin.';

  @override
  String get workspaceExternalGrantAccess => 'Erişim ver';

  @override
  String get workspaceExternalLocalOnly =>
      'Android yalnızca cihazdaki klasörleri bağlayabilir. Bu belge sağlayıcısı Shell\'in erişebileceği yerel bir klasör sunmuyor.';

  @override
  String get workspaceExternalUnavailable =>
      'Harici klasör kullanılamıyor. Depolama bağlantısını ve izinleri kontrol edin, ardından erişimi geri yüklemek için klasörü yeniden seçin.';

  @override
  String get workspaceExternalReconnect => 'Klasörü yeniden seç';

  @override
  String get workspaceMountAdd => 'Klasör ekle';

  @override
  String get workspaceMountEdit => 'Bağlamayı düzenle';

  @override
  String get workspaceMountEmpty => 'Bağlanmış klasör yok';

  @override
  String get workspaceMountReadOnly => 'Salt okunur';

  @override
  String get workspaceMountReadWrite => 'Okuma-yazma';

  @override
  String get workspaceMountAllowWrite => 'Yazmaya izin ver';

  @override
  String get workspaceMountPermissionsHint =>
      'Yapay zekâ dosya araçları ve dosya tarayıcısı bu ayara uyar. Shell korumaları yaygın dosya komutlarını kapsar; rastgele betikler bunları atlayabilir. Bağlama değişikliklerini kaydetmek, çalışan komutları ve terminal oturumlarını durdurur.';

  @override
  String get workspaceMountBrowse => 'Dosyalara göz at';

  @override
  String get workspaceMountUnmount => 'Bağlamayı kaldır';

  @override
  String get workspaceMountUnmountMessage =>
      'Bu bağlama kaldırılsın mı? Özgün klasör ve içindeki dosyalar korunacak.';

  @override
  String get workspaceMountInactive => 'Kullanılamıyor — klasörü yeniden seçin';

  @override
  String get workspaceMountInvalidName =>
      'En fazla 64 karakterlik bir ad kullanın; eğik çizgi, iki nokta üst üste veya kontrol karakteri içermemeli. . veya .. kullanmayın';

  @override
  String get workspaceMountDuplicate => 'Bu ada sahip bir bağlama zaten var.';

  @override
  String get workspaceMountLimit =>
      'En fazla 10 klasör bağlanabilir. Başka bir tane eklemeden önce bir bağlamayı kaldırın.';

  @override
  String get workspaceMountOverlap =>
      'Bu klasör mevcut bir bağlamayla çakışıyor. İzinlerin belirsiz kalmaması için farklı bir klasör seçin.';

  @override
  String get workspaceMountTargetOccupied =>
      '/mounts altındaki bağlama hedefi zaten yerel dosyalar içeriyor. Farklı bir bağlama adı seçin veya önce bu dosyaları taşıyın. Hiçbir dosya silinmedi.';

  @override
  String get workspaceEnvSystemImage => 'Sistem imajı';

  @override
  String get workspaceEnvDistribution => 'Dağıtım';

  @override
  String get workspaceEnvSystemVersion => 'Sürüm';

  @override
  String get workspaceEnvLocalImage => 'Yerel imaj';

  @override
  String get workspaceEnvChooseImage => 'rootfs arşivi seç';

  @override
  String get workspaceEnvLocalImageHint =>
      'Bir kök dosya sistemi arşivi (.tar.gz, .tar.xz veya .tar) içe aktarın; ISO veya disk imajı değil. Bu cihazın CPU mimarisiyle eşleşmeli ve /bin/sh içermelidir. Sistem ve sürüm, çıkarma işleminden sonra algılanır.';

  @override
  String get workspaceEnvImportImage => 'İmajı içe aktar';

  @override
  String get workspaceEnvInvalidImage =>
      'Bu cihaz için geçerli bir rootfs arşivi seçin. Eşleşen CPU mimarisine sahip çalıştırılabilir bir /bin/sh içermelidir.';

  @override
  String get workspaceEnvReplaceSystem => 'Sistemi değiştir';

  @override
  String get workspaceEnvReplaceSystemHint =>
      'Bu işlem, mevcut ortamın içindeki yüklü paketleri ve dosyaları değiştirir ve çalışan komutlarını ve terminal oturumlarını durdurur. Çalışma alanları, sohbet dosyaları ve harici klasörler korunur. Yeni imajın hazırlanması başarısız olursa mevcut ortam korunur.';

  @override
  String get workspaceEnvProotOptions => 'PRoot seçenekleri';

  @override
  String get workspaceEnvShellPath => 'Shell yolu';

  @override
  String get workspaceEnvShellAutomatic => 'Otomatik';

  @override
  String get workspaceEnvShellHint =>
      'Mevcut olduğunda /bin/bash, aksi halde /bin/sh kullanmak için boş bırakın. Özel bir shell, ortam içinde mutlak bir yol kullanmalıdır.';

  @override
  String get workspaceEnvProotArguments => 'Ek PRoot argümanları';

  @override
  String get workspaceEnvProotArgumentsHint =>
      'Her satıra bir argüman, shell tırnakları olmadan. Örneğin, -k ve 5.10.0\'ı ayrı satırlara koyun veya --kernel-release=5.10.0 kullanın. Değişiklikler yeni komutlar ve terminal oturumları için geçerlidir.';

  @override
  String get workspaceEnvProotInvalid =>
      'Geçerli bir mutlak shell yolu girin ve her satıra bir PRoot argümanı yazın.';

  @override
  String get workspaceFileMissing => 'Dosya artık mevcut değil';

  @override
  String get workspaceFilePreviewUnavailable => 'Önizleme kullanılamıyor';

  @override
  String get workspaceToolRelatedFiles => 'İlgili dosyalar';

  @override
  String get workspaceToolFilesTruncated =>
      'Yalnızca bazı dosyalar listeleniyor.';

  @override
  String get displaySettingsPageShowProducedFilesTitle =>
      'Dosyaları Yanıtların Altında Göster';

  @override
  String get displaySettingsPageShowProducedFilesSubtitle =>
      'Araçlar tarafından oluşturulan veya değiştirilen dosyaları yanıtların altında göster.';

  @override
  String get defaultModelPagePerChatModelTitle => 'Sohbet Başına Model';

  @override
  String get defaultModelPagePerChatModelSubtitle =>
      'Açık: bir sohbette model seçmek yalnızca o sohbeti etkiler. Kapalı: seçim mevcut asistanın modeli olur, böylece o asistanı kullanan tüm sohbetler bunu izler.';

  @override
  String get googleFontsTitle => 'Google Fonts';

  @override
  String get googleFontsRefresh => 'Yazı tipi listesini yenile';

  @override
  String get googleFontsSearchHint => 'Yazı tiplerinde veya dillerde ara';

  @override
  String get googleFontsHint =>
      'Önizlemek ve uygulamak için normal bir yazı tipi indirin. Yüklü yazı tipleri çevrimdışı çalışır. Katalog: Expo Google Fonts; indirmeler: Google Fonts.';

  @override
  String get googleFontsNoResults => 'Eşleşen yazı tipi yok';

  @override
  String get googleFontsFailed =>
      'Yazı tipi yüklenemedi, indirilemedi veya uygulanamadı. Bağlantınızı kontrol edip tekrar deneyin.';

  @override
  String get googleFontsDownloading => 'Yazı tipi indiriliyor…';

  @override
  String get googleFontsPreview =>
      'The quick brown fox 0123456789 · Yazı tipi önizlemesi';

  @override
  String get googleFontsLicense => 'Yazı tipi lisansı';

  @override
  String get assistantEditLocationPermissionSettingsMessage =>
      'Konum izni engellendi. Sistem ayarlarından konum erişimine izin verin, ardından bu aracı yeniden açın.';

  @override
  String get healthDataSettingsCategoryReproductive => 'Üreme sağlığı';

  @override
  String get healthDataSettingsTypeMenstrualFlowTitle => 'Adet akışı';

  @override
  String get healthDataSettingsTypeMenstrualFlowSubtitle =>
      'Son 90 günde kaydedilen adet akışı ve döngü başlangıçları';

  @override
  String get assistantEditGradientBackgroundTitle => 'Gradyan arka plan';

  @override
  String get assistantEditGradientStaticTitle => 'Statik mod';

  @override
  String get assistantEditGradientStaticDescription =>
      'Uzun sohbetlerde ve akış sırasında güç tasarrufu sağlar.';

  @override
  String get assistantEditGradientHorizontal => 'Yatay konum';

  @override
  String get assistantEditGradientVertical => 'Dikey konum';

  @override
  String get assistantEditGradientPreview => 'Önizleme';

  @override
  String get assistantEditGradientNextFrame => 'Başka bir kare';

  @override
  String get backgroundSettingsTitle => 'Arka plan görevleri';

  @override
  String get backgroundTaskTitle => 'Kelivo görevi';

  @override
  String get backgroundCompleted => 'Oluşturma tamamlandı';

  @override
  String get backgroundFailed =>
      'Oluşturma başarısız oldu. Ayrıntılar için sohbeti açın.';

  @override
  String get backgroundCancelled => 'Oluşturma iptal edildi';

  @override
  String get backgroundInterrupted =>
      'Arka plan oluşturma kesintiye uğradı. Devam etmek için sohbeti açın.';

  @override
  String get backgroundRequesting => 'Bağlanıyor';

  @override
  String get backgroundGenerating => 'Yanıt oluşturuluyor';

  @override
  String get backgroundThinking => 'Düşünüyor';

  @override
  String get backgroundToolRunning => 'Araç çalıştırılıyor';

  @override
  String get backgroundRetrying => 'Yeniden deneme bekleniyor';

  @override
  String get backgroundWorking => 'İşleniyor';

  @override
  String get backgroundTasks => 'Görevler';

  @override
  String get backgroundStopTasks => 'Görevleri durdur';

  @override
  String get backgroundOpenChat => 'Sohbeti aç';

  @override
  String get backgroundAndroidEnabled => 'Arka plan oluşturma';

  @override
  String get backgroundAndroidEnabledDetail =>
      'Kilitliyken, arka plandayken veya son uygulamalardan kaldırıldığında mevcut görevleri çalışır durumda tutun. Görevler çalışırken sistem bildirimi gerekir.';

  @override
  String get backgroundIosEnabled => 'Gelişmiş arka plan yürütme';

  @override
  String get backgroundIosEnabledDetail =>
      'Mevcut görevleri tamamlamak için süre isteyin. Ek arka plan desteği için konumu veya sessiz sesi ayrıca etkinleştirin.';

  @override
  String get backgroundNotifications => 'Görev bildirimleri';

  @override
  String get backgroundNotificationsDetail =>
      'Görüntülediğiniz sohbetin dışında bir görev tamamlandığında veya başarısız olduğunda bildir. Android\'in zorunlu sürekli bildirimini kontrol etmez.';

  @override
  String get backgroundPrivacy => 'Görev durumu gizliliği';

  @override
  String get backgroundPrivacyDetail =>
      'Bildirimlerde ve canlı durumda sohbet başlıklarını ve araç ayrıntılarını gizleyin. Yalnızca genel durum, görev sayısı ve geçen süre gösterilir.';

  @override
  String get backgroundLiveActivities => 'Canlı Etkinlikler';

  @override
  String get backgroundLiveActivitiesDetail =>
      'Mevcut görevleri Kilit Ekranında ve Dinamik Ada\'da gösterin. Kullanılabilirlik ve görünürlük sisteme bağlıdır.';

  @override
  String get backgroundOverlay => 'Yüzen görev durumu';

  @override
  String get backgroundOverlayDetail =>
      'Diğer uygulamaların üzerinde sürüklenebilir bir görev kapsülü gösterin. Sohbeti açmak için dokunun; kapatmak yalnızca kapsülü gizler.';

  @override
  String get backgroundLiveUpdates => 'Canlı Güncellemeler';

  @override
  String get backgroundLiveUpdatesDetail =>
      'Desteklenen cihazlarda Android 16 Canlı Güncellemelerini kullanın. Öne çıkarılan bir bildirim, yüzen kapsülden önceliklidir.';

  @override
  String get backgroundLocation => 'Konum destekli yürütme';

  @override
  String get backgroundLocationDetail =>
      'Arka plan görevleri sırasında düşük hassasiyetli konum güncellemeleri kullanın. Koordinatlar saklanmaz veya AI hizmetlerine gönderilmez. Gelişmiş arka plan yürütme ve konum izni gerektirir.';

  @override
  String get backgroundSilentAudio => 'Sessiz sesle canlı tutma';

  @override
  String get backgroundSilentAudioDetail =>
      'Arka plan görevleri çalışırken sessiz ses çalın. Kayıt ve konuşma oynatımına öncelik verir. Gelişmiş arka plan yürütme gerektirir; mikrofon izni gerekmez.';

  @override
  String get backgroundSpeech => 'Arka planda sesli okuma';

  @override
  String get backgroundSpeechDetail =>
      'Kilitliyken veya arka plandayken sistem ve ağ sesli okumaya devam et. Devre dışı bırakıldığında arka plana geçmek sesli okumayı duraklatır.';

  @override
  String get backgroundFinishVisibility => 'Tamamlanma durumu süresi';

  @override
  String get backgroundFinishImmediately => 'Hemen kapat';

  @override
  String get backgroundFinishOneMinute => '1 dakika';

  @override
  String get backgroundFinishFiveMinutes => '5 dakika';

  @override
  String get backgroundFinishUntilForeground => 'Uygulamaya dönünce';

  @override
  String get backgroundFinishVisibilityDetail =>
      'Android kapsülü ve iOS Kilit Ekranı tamamlanma kartı için geçerlidir. Uygulamaya dönüldüğünde tamamlanma durumu temizlenir; en fazla 15 dakika. İptal işlemi hemen kapatır.';

  @override
  String get backgroundOverlayIcon => 'Yüzen simge';

  @override
  String get backgroundIconDefault => 'Kelivo simgesi';

  @override
  String get backgroundIconImage => 'Görsel seç';

  @override
  String get backgroundIconEmoji => 'Emoji seç';

  @override
  String get backgroundPermissionsTitle => 'İzinler ve sistem ayarları';

  @override
  String get backgroundNotificationsPermission => 'Bildirim izni';

  @override
  String get backgroundBatteryOptimization => 'Pil optimizasyonu';

  @override
  String get backgroundBatteryOptimizationDetail =>
      'Daha güvenilir arka plan çalışması için sınırsız pil kullanımına izin verin.';

  @override
  String get backgroundAutostart => 'Otomatik başlatma ve arka plan kullanımı';

  @override
  String get backgroundAutostartDetail =>
      'Cihazınızın otomatik başlatma ve arka plan kısıtlamalarını manuel olarak kontrol edin. Android, bu üretici ayarları için güvenilir bir izin sorgusu sağlamaz.';

  @override
  String get backgroundLocationPermission => 'Konum izni';

  @override
  String get backgroundLocationAlways => 'Arka planda konuma izin ver';

  @override
  String get backgroundLocationAlwaysDetail =>
      'Arka plan konumu için Her Zaman erişimi verebilirsiniz. İzin yalnızca bu eylemi seçtiğinizde istenir.';

  @override
  String get backgroundSystemSettings => 'Uygulama sistem ayarları';

  @override
  String get backgroundPermissionGranted => 'İzin verildi';

  @override
  String get backgroundPermissionDenied => 'İzin verilmedi';

  @override
  String get backgroundPermissionLimited => 'Uygulama kullanılırken';

  @override
  String get backgroundPermissionUnknown => 'Manuel kontrol edin';

  @override
  String get backgroundPermissionNotDetermined => 'Henüz istenmedi';

  @override
  String get backgroundRuntimeTitle => 'Mevcut durum';

  @override
  String get backgroundRuntimeActive => 'Çalışıyor';

  @override
  String get backgroundRuntimeIdle => 'Etkin değil';

  @override
  String get backgroundLocationActive => 'Arka plan konumu';

  @override
  String get backgroundAudioActive => 'Sessiz ses';

  @override
  String get backgroundActivityActive => 'Canlı Etkinlik';

  @override
  String get backgroundOverlayActive => 'Yüzen pencere';

  @override
  String get backgroundLastError => 'Son kesinti veya hata';

  @override
  String get backgroundNoError => 'Kayıt yok';

  @override
  String get backgroundUnsupported =>
      'Bu cihazda kullanılamıyor veya sistem ayarlarında devre dışı';

  @override
  String get backgroundIosLimit =>
      'Arka plan yürütmesini iOS kontrol eder. Canlı Etkinlikler tek başına uygulamayı çalışır durumda tutmaz. Zorla kapatma üretimi durdurabilir ve canlı durumun kaldırılmasını uygulama yeniden açılana kadar geciktirebilir.';

  @override
  String get backgroundAndroidLimit =>
      'Görevler durursa bildirim, pil ve üretici arka plan ayarlarını kontrol edin. Zorla durdurma ve sistem süreç sonlandırması yine de üretimi kesintiye uğratabilir.';

  @override
  String get backgroundStale =>
      'Durum güncellenmedi. Kontrol etmek için uygulamayı açın.';

  @override
  String get backgroundIconError =>
      'Bu görsel içe aktarılamadı. Lütfen başka bir görsel seçin.';

  @override
  String get backgroundNotificationChannels => 'Bildirim kanalları';

  @override
  String get backgroundCompletionChannel => 'Tamamlanma bildirimi kanalı';

  @override
  String get backgroundOngoingChannel => 'Çalışan görev bildirimi kanalı';

  @override
  String get backgroundOverlayAppearance => 'Yüzen pencere görünümü';

  @override
  String get backgroundOverlayAppearanceDetail =>
      'Boyut, görsel, ilerleme halkası ve görünen içerik';

  @override
  String get backgroundOverlayPreviewHint =>
      'Taşımak için sürükleyin · Sohbeti açmak için dokunun · Kapatmak için basılı tutun';

  @override
  String get backgroundOverlayCard => 'Kart';

  @override
  String get backgroundOverlayCircle => 'Dairesel simge';

  @override
  String get backgroundOverlaySize => 'Boyut ve şekil';

  @override
  String get backgroundOverlayWidth => 'Genişlik';

  @override
  String get backgroundOverlayHeight => 'Yükseklik';

  @override
  String get backgroundOverlayCornerRadius => 'Köşe yarıçapı';

  @override
  String get backgroundOverlayIconSize => 'Simge boyutu';

  @override
  String get backgroundOverlayProgressSize => 'İlerleme halkası çapı';

  @override
  String get backgroundOverlayProgressStroke => 'İlerleme halkası kalınlığı';

  @override
  String get backgroundOverlayContent => 'Görünür içerik';

  @override
  String get backgroundOverlayShowProgress => 'İlerleme halkasını göster';

  @override
  String get backgroundOverlayShowTitle => 'Başlığı göster';

  @override
  String get backgroundOverlayShowSubtitle => 'Alt başlığı göster';

  @override
  String get backgroundOverlayShowTime => 'Geçen süreyi göster';

  @override
  String get backgroundOverlayShowClose => 'Kapat düğmesini göster';

  @override
  String get backgroundOverlayShowBackground => 'Arka planı göster';

  @override
  String get backgroundOverlayShowBorder => 'Kenarlığı göster';

  @override
  String get backgroundOverlayReset => 'Varsayılan görünümü geri yükle';

  @override
  String get mcpStdioEnvironmentRequired =>
      'Mobilde STDIO kullanmak için çalışma alanı ortamını yükleyin.';

  @override
  String get mcpArgumentsHint =>
      'Bağımsız değişkenleri boşlukla ayırın; boşluk içeren değerleri tırnak içine alın. Boş bağımsız değişken için \'\' kullanın.';

  @override
  String get mcpArgumentsInvalid =>
      'Bağımsız değişkenlerde kapatılmamış tırnak veya sonda tamamlanmamış kaçış olup olmadığını kontrol edin.';

  @override
  String get mcpImportEnvironment => 'Ortamdan içe aktar';

  @override
  String get mcpEnvironmentEmpty =>
      'Ortam değişkeni yok. Ortam ayarlarından ekleyin.';

  @override
  String get mcpEnvironmentHint =>
      'Ortam değişkenlerini devralır. Bu sunucu için değerini özelleştirmek üzere bir değişken içe aktarın.';

  @override
  String get mcpImportJson => 'JSON içe aktar';

  @override
  String get mcpImportJsonHint =>
      'Claude Desktop veya Cursor MCP yapılandırmasını yapıştırın. Mevcut sunucuları değiştirmeden önizleyin ve sunucu ekleyin.';

  @override
  String get mcpImportPaste => 'Panodan yapıştır';

  @override
  String get mcpImportPreview => 'Önizleme';

  @override
  String get mcpImportConfirm => 'İçe aktar';

  @override
  String get startupRecoverySnapshotTitle => 'Yerel bir kopyadan kurtar';

  @override
  String get startupRecoverySnapshotBody =>
      'Veritabanı açılamasa bile sohbetlerinizi ve ayarlarınızı kurtarmak için bu cihazdaki bir anlık görüntüyü seçin. Kelivo\'yu kaldırmayın: kaldırmak bu anlık görüntüleri de siler.';

  @override
  String get startupRecoverySnapshotEmpty =>
      'Bu cihazda veritabanı anlık görüntüsü bulunamadı. Diğer kurtarma işlemlerini denemeden önce verilerinizi dışa aktarın.';

  @override
  String get startupRecoverySnapshotButton => 'Kurtarılacak bir kopya seç';

  @override
  String startupRecoverySnapshotConfirm(String when) {
    return 'Sohbetler ve ayarlar $when anlık görüntüsünden geri yüklensin mi? Bu anlık görüntüden sonra yapılan değişiklikler dahil edilmez. Mevcut ek dosyaları ve anlık görüntü korunur. Geri yüklemeyi tamamlamak için Kelivo yeniden başlatılacak.';
  }

  @override
  String startupRecoverySnapshotFailed(String reason) {
    return 'Anlık görüntü geri yüklemesi hazırlanamadı: $reason';
  }

  @override
  String get startupRecoverySnapshotReady =>
      'Anlık görüntü hazır. Geri yüklemeyi tamamlamak için Kelivo\'yu yeniden başlatın.';

  @override
  String get scheduledTasksTitle => 'Zamanlanmış görevler';

  @override
  String get scheduledTasksDescription =>
      'Görevleri seçtiğiniz saatte otomatik çalıştırın: yeni sohbet başlatın, devam edin veya bir soruyu yeniden çalıştırın.';

  @override
  String get scheduledTasksEmpty => 'Gününüz, bir programa bağlı';

  @override
  String get scheduledTasksEmptyDetail =>
      'Sabah brifingi, günlük değerlendirme veya düzenli çalıştırmak istediğiniz herhangi bir şey için bir görev ekleyin.';

  @override
  String get scheduledTasksAdd => 'Görev ekle';

  @override
  String get scheduledTasksEdit => 'Görevi düzenle';

  @override
  String get scheduledTasksName => 'Ad';

  @override
  String get scheduledTasksNameHint => 'Sabah brifingi';

  @override
  String get scheduledTasksPrompt => 'İstem';

  @override
  String get scheduledTasksPromptHint =>
      'Asistanınızın ne yapmasını istersiniz?';

  @override
  String get scheduledTasksAssistant => 'Asistan';

  @override
  String get scheduledTasksChooseAssistant => 'Bir asistan seçin';

  @override
  String get scheduledTasksAssistantMissing => 'Asistan kullanılamıyor';

  @override
  String get scheduledTasksTime => 'Saat';

  @override
  String get scheduledTasksTimeHint => '24 saat biçimi, ör. 08:00';

  @override
  String get scheduledTasksRepeat => 'Tekrar';

  @override
  String get scheduledTasksEveryDay => 'Her gün';

  @override
  String get scheduledTasksWeekdays => 'Hafta içi';

  @override
  String get scheduledTasksEnabled => 'Etkin';

  @override
  String get scheduledTasksPermission => 'Alarmlar ve hatırlatıcılar';

  @override
  String get scheduledTasksPermissionDetail =>
      'Görevlerin seçtiğiniz saatte çalışması için kesin alarmlara izin verin. İzin verilene kadar etkin görevler bekler.';

  @override
  String get scheduledTasksPermissionAction => 'İzin ver';

  @override
  String get scheduledTasksReliability =>
      'Daha güvenilir çalıştırma için Kelivo\'yu pil ayarlarında kısıtlamasız tutun. Uygulamayı zorla durdurmak, yeniden açana kadar alarmları iptal eder. Kaçırılan çalıştırmalar atlanır; görevler cihazın saat dilimini izler.';

  @override
  String get scheduledTasksExecutionDetail =>
      'Sonuçlar sohbetlere kaydedilir. Tamamlanma bildirimi yanıtı önizler ve dokunulduğunda sohbeti açar. Çalıştırmalar 10 dakika sonra veya kullanıcı girişi ya da araç onayı gerektiğinde durur.';

  @override
  String get scheduledTasksRunNow => 'Şimdi çalıştır';

  @override
  String get scheduledTasksHistory => 'Çalıştırma geçmişi';

  @override
  String get scheduledTasksNoRuns => 'Henüz çalıştırma yok';

  @override
  String get scheduledTasksRunning => 'Çalışıyor';

  @override
  String get scheduledTasksCompleted => 'Tamamlandı';

  @override
  String get scheduledTasksFailed => 'Başarısız';

  @override
  String get scheduledTasksInterrupted => 'Kesildi';

  @override
  String get scheduledTasksPaused => 'Duraklatıldı';

  @override
  String get scheduledTasksWaitingPermission => 'İzin bekleniyor';

  @override
  String scheduledTasksNextRun(String time) {
    return 'Sonraki: $time';
  }

  @override
  String get scheduledTasksDelete => 'Görevi sil';

  @override
  String get scheduledTasksDeleteDetail =>
      'Bu zamanlamayı ve çalıştırma geçmişini silmek istiyor musunuz? Zaten oluşturulmuş sohbetler korunur.';

  @override
  String get scheduledTasksSave => 'Kaydet';

  @override
  String get scheduledTasksCancel => 'İptal';

  @override
  String get scheduledTasksInvalid =>
      'Bir ad, istem ve asistan girin; özel zamanlama için en az bir gün seçin.';

  @override
  String get scheduledTasksLoading => 'Yükleniyor…';

  @override
  String get scheduledTasksOpenChat => 'Sohbeti görüntüle';

  @override
  String get scheduledTasksNeedsInput =>
      'Kullanıcı girişi veya araç onayı gerektiği için durduruldu. Devam etmek için sohbeti açın.';

  @override
  String get scheduledTasksTimeout => 'Yürütme süresi sınırına ulaşıldı.';

  @override
  String get scheduledTasksProcessTerminated =>
      'Android önceki çalıştırmayı durdurdu.';

  @override
  String get scheduledTasksOnce => 'Bir kez';

  @override
  String get scheduledTasksCustom => 'Özel';

  @override
  String get scheduledTasksExecution => 'Görev';

  @override
  String get scheduledTasksMode => 'Eylem';

  @override
  String get scheduledTasksNewChat => 'Yeni sohbet';

  @override
  String get scheduledTasksFollowUp => 'Devam et';

  @override
  String get scheduledTasksRegenerate => 'Yeniden çalıştır';

  @override
  String get scheduledTasksChat => 'Sohbet';

  @override
  String get scheduledTasksChooseChat => 'Bir sohbet seçin';

  @override
  String get scheduledTasksMessage => 'Yeniden çalıştırılacak soru';

  @override
  String get scheduledTasksChooseMessage => 'Bir soru seçin';

  @override
  String get scheduledTasksAttachmentMessage => 'Ekli mesaj';

  @override
  String get scheduledTasksModel => 'Model';

  @override
  String get scheduledTasksChooseModel => 'Bir model seçin';

  @override
  String get scheduledTasksModelDefault =>
      'Sohbet veya asistan modelini kullan';

  @override
  String get scheduledTasksSchedule => 'Zamanlama';

  @override
  String get scheduledTasksActiveWindow => 'Etkin tarihler';

  @override
  String get scheduledTasksStartDate => 'Başlangıç tarihi';

  @override
  String get scheduledTasksEndDate => 'Bitiş tarihi';

  @override
  String get scheduledTasksActiveWindowDetail =>
      'Yalnızca bu tarihler arasında, bitiş tarihi dahil çalışır. Sınır olmaması için bir tarihi boş bırakın.';

  @override
  String get scheduledTasksDate => 'Tarih';

  @override
  String get scheduledTasksDateUnrestricted => 'Sınır yok';

  @override
  String get scheduledTasksClear => 'Temizle';

  @override
  String get scheduledTasksSearch => 'Ara';

  @override
  String get scheduledTasksNoTargets => 'Bu asistan için eşleşen öğe yok';

  @override
  String get scheduledTasksFutureDate =>
      'Gelecekte bir yürütme tarihi ve saati seçin.';

  @override
  String get scheduledTasksDateRangeInvalid =>
      'Bitiş tarihi, başlangıç tarihine eşit veya sonrasında olmalıdır.';

  @override
  String get scheduledTasksRegenerateDetail =>
      'Özgün bağlamını kullanarak seçili soru için yeni bir yanıt oluşturur. Mevcut yanıtlar ve sonraki mesajlar korunur.';

  @override
  String get scheduledTasksSaving => 'Kaydediliyor…';

  @override
  String get scheduledTasksFinished => 'Zamanlama sona erdi';

  @override
  String get scheduledTasksModelMissing =>
      'Seçili model kullanılamıyor. Başka bir model seçmek için bu görevi düzenleyin.';

  @override
  String get scheduledTasksChatMissing =>
      'Sohbet kullanılamıyor veya başka bir asistana ait.';

  @override
  String get scheduledTasksMessageMissing =>
      'Seçili soru artık kullanılamıyor.';

  @override
  String get scheduledTasksChatBusy =>
      'Bu sohbet bir yanıt oluşturuyor. Zamanlanmış çalıştırma atlandı.';

  @override
  String get scheduledTasksDesktopEmpty => 'Zamanlanmış görev yok';

  @override
  String get scheduledTasksDesktopReliability =>
      'Görevler yalnızca Kelivo çalışırken yürütülür; simge durumuna küçültüldüğünde veya sistem tepsisindeyken de devam eder. Uygulamadan çıkıldıktan veya bilgisayar uykuya geçtikten sonra kaçırılan zamanlar atlanır. Kelivo otomatik olarak başlamaz.';

  @override
  String get scheduledTasksDesktopExecutionDetail =>
      'Sonuçlar sohbetlerde kaydedilir. Görevin çalıştırma geçmişinden açabilirsiniz. Çalıştırmalar 10 dakika sonra veya kullanıcı girdisi ya da araç onayı gerektiğinde durur.';

  @override
  String get worldBookStickyLabel => 'Yapışkan (mesaj)';

  @override
  String get worldBookStickyHint =>
      'Bu girdiyi tetiklendikten sonra N mesaj boyunca etkin tut. Tekrarlanan eşleşmeler bunu uzatmaz. 0 bu etkiyi devre dışı bırakır.';

  @override
  String get worldBookCooldownLabel => 'Bekleme süresi (mesaj)';

  @override
  String get worldBookCooldownHint =>
      'Tetiklendikten sonra veya yapışkan süre bittikten sonra N mesaj boyunca yeniden etkinleşmeyi engelle. 0 bu etkiyi devre dışı bırakır.';

  @override
  String get worldBookDelayLabel => 'Gecikme (mesaj)';

  @override
  String get worldBookDelayHint =>
      'Yalnızca sohbet en az N mesaja ulaştığında etkinleşmesine izin ver. Tek tek mesajları say, karşılıklı konuşmaları değil. 0 bu etkiyi devre dışı bırakır.';

  @override
  String get worldBookDragToReorder => 'Sıralamak için sürükleyin';

  @override
  String worldBookEnabledCount(int enabled, int total) {
    return '$enabled/$total etkin';
  }

  @override
  String get assistantConversationSystemPromptTitle =>
      'Sohbete özel sistem istemi';

  @override
  String get assistantConversationSystemPromptHint =>
      'Her sohbetin kendi sistem istemini kullanmasına izin ver.';

  @override
  String get assistantConversationInjectionTitle =>
      'Sohbete özel yönerge enjeksiyonları';

  @override
  String get assistantConversationInjectionHint =>
      'Her sohbet için yönerge enjeksiyonlarını ve dünya kitaplarını seçin. Varsayılan olarak hiçbiri seçili değildir.';

  @override
  String get conversationSystemPromptTitle => 'Sohbet sistem istemi';

  @override
  String get conversationSystemPromptHint =>
      'Yalnızca bu sohbet için geçerlidir. Asistanın sistem istemini kullanmak için boş bırakın.';

  @override
  String get conversationSystemPromptClear => 'Asistan istemini kullan';

  @override
  String get conversationSystemPromptPlaceholder =>
      'Bu sohbet için bir sistem istemi yazın…';

  @override
  String get conversationPromptScope => 'Bu sohbet';

  @override
  String get oauthAccountsTab => 'Hesaplar';

  @override
  String get oauthLogin => 'Giriş yap';

  @override
  String oauthLoginTo(String provider) {
    return '$provider hesabına giriş yap';
  }

  @override
  String get oauthConnected => 'Bağlı';

  @override
  String get oauthNotConnected => 'Bağlı değil';

  @override
  String oauthWaiting(String provider) {
    return '$provider yetkilendirmesi bekleniyor';
  }

  @override
  String get oauthCancel => 'Yetkilendirmeyi iptal et';

  @override
  String get oauthOpenBrowser => 'Yetkilendirme sayfasını aç';

  @override
  String get oauthCopyCode => 'Kodu kopyala';

  @override
  String get oauthCodeHint => 'Bu kodu yetkilendirme sayfasına girin';

  @override
  String get oauthDeviceHint =>
      'Önce ChatGPT güvenlik ayarlarınızda veya çalışma alanı izinlerinizde cihaz koduyla girişi etkinleştirin.';

  @override
  String get oauthDeviceLogin => 'Cihaz kodu kullan';

  @override
  String get oauthDetails => 'Hesap ayrıntılarını görüntüle';

  @override
  String get oauthConnectAnother => 'Başka bir hesap bağla';

  @override
  String get oauthRelogin => 'Tekrar giriş yap';

  @override
  String get oauthNeedsLogin => 'Giriş gerekli';

  @override
  String oauthExpired(String provider) {
    return '$provider oturumu süresi doldu';
  }

  @override
  String get oauthLoginRestored =>
      'Giriş yapıldı. Tekrar göndermek için mesajın yeniden deneme düğmesini kullanın.';

  @override
  String get oauthLogout => 'Çıkış yap';

  @override
  String get oauthLogoutDescription =>
      'Bu hesabın kayıtlı kimlik bilgilerini bu cihazdan kaldır';

  @override
  String get oauthRefreshing => 'Yetkilendirme yenileniyor…';

  @override
  String get oauthRefreshUsage => 'Kullanımı yenile';

  @override
  String get oauthUsageDetails => 'Kullanım ayrıntıları';

  @override
  String get oauthUsageUnavailable => 'Kullanım bilgisi şu anda alınamıyor';

  @override
  String oauthLastUpdated(String time) {
    return 'Güncellendi: $time';
  }

  @override
  String get oauthSyncModels => 'Eşitle';

  @override
  String get oauthSyncing => 'Modeller eşitleniyor…';

  @override
  String get oauthModelsHint =>
      'Kullanılabilir modeller hesabınızdan eşitlenir. Model seçicide hangi modellerin görüneceğini seçin. Seçimleriniz eşitleme veya yeniden oturum açma sonrasında korunur.';

  @override
  String get oauthNoModels => 'Sohbete başlamak için modelleri eşitleyin';

  @override
  String get oauthConnection => 'Bağlantı';

  @override
  String get oauthConnectionInfo => 'Bağlantı ayrıntıları';

  @override
  String get oauthEndpoint => 'Uç nokta';

  @override
  String get oauthScope => 'Yetkilendirme kapsamı';

  @override
  String get oauthAccountId => 'Hesap kimliği';

  @override
  String get oauthTokenExpiry => 'Token sona erme';

  @override
  String get oauthName => 'Sağlayıcı adı';

  @override
  String get oauthEnabledHint => 'Bu modelleri model seçicide göster';

  @override
  String get oauthNetwork => 'Ağ proxy\'si';

  @override
  String get oauthFollowGlobal => 'Genel ayarları izle';

  @override
  String get oauthCustomRequest => 'Özel istek';

  @override
  String get oauthWeekly => 'Haftalık pencere';

  @override
  String get oauthMonthly => 'Aylık pencere';

  @override
  String get oauthTotal => 'Toplam kota';

  @override
  String oauthHours(String count) {
    return '$count saatlik pencere';
  }

  @override
  String oauthMinutes(String count) {
    return '$count dakikalık pencere';
  }

  @override
  String oauthDays(String count) {
    return '$count günlük pencere';
  }

  @override
  String get oauthWindow => 'Kullanım penceresi';

  @override
  String oauthResetsAt(String time) {
    return 'Sıfırlanma: $time';
  }

  @override
  String oauthUsedValue(String value) {
    return 'Kullanılan $value';
  }

  @override
  String get oauthNetworkError =>
      'Bağlanılamadı. Ağınızı kontrol edip tekrar deneyin.';

  @override
  String get oauthDnsError =>
      'DNS çözümlemesi başarısız oldu. Ağınızı veya proxy DNS ayarlarınızı kontrol edin.';

  @override
  String get oauthTlsError =>
      'TLS bağlantısı başarısız oldu. Ağınızın veya proxy\'nizin kullandığı sertifikaları kontrol edin.';

  @override
  String get oauthProxyError =>
      'Proxy bağlantısı başarısız oldu. Proxy adresinizi ve kimlik doğrulama ayarlarınızı kontrol edin.';

  @override
  String get oauthConnectionError =>
      'Bağlantı başarısız oldu veya kesildi. Ağınızı veya proxy ayarlarınızı kontrol edin.';

  @override
  String get oauthConnectionTimeout =>
      'Sunucuya bağlanma zaman aşımına uğradı. Ağınızı veya proxy ayarlarınızı kontrol edin.';

  @override
  String get oauthSendTimeout =>
      'İstek gönderme zaman aşımına uğradı. Ağınızı kontrol edip tekrar deneyin.';

  @override
  String get oauthReceiveTimeout =>
      'Sunucu yanıtı beklenirken zaman aşımına uğradı. Lütfen tekrar deneyin.';

  @override
  String get oauthRequestTimeout =>
      'İstek zaman aşımına uğradı. Ağınızı veya proxy ayarlarınızı kontrol edip tekrar deneyin.';

  @override
  String oauthFailureStage(String stage) {
    return 'Başarısız aşama: $stage';
  }

  @override
  String get oauthStageRequestDeviceCode => 'Cihaz kodu isteniyor';

  @override
  String get oauthStageWaitDeviceAuthorization =>
      'Cihaz yetkilendirmesi bekleniyor';

  @override
  String get oauthStagePrepareBrowser => 'Tarayıcı oturum açma hazırlanıyor';

  @override
  String get oauthStageBrowserAuthorization =>
      'Tarayıcı yetkilendirmesi ve geri çağırma';

  @override
  String get oauthStageExchangeToken => 'Yetkilendirme kodu değiştiriliyor';

  @override
  String get oauthStageRefreshToken => 'Oturum açma token\'ı yenileniyor';

  @override
  String get oauthInvalidResponse =>
      'Yetkilendirme tamamlanmadı. Lütfen tekrar deneyin.';

  @override
  String get oauthTimeout =>
      'Yetkilendirme zaman aşımına uğradı. Lütfen tekrar deneyin.';

  @override
  String get oauthDenied => 'Yetkilendirme verilmedi. Lütfen tekrar deneyin.';

  @override
  String get oauthSaving => 'Hesap bağlanıyor…';

  @override
  String get oauthQuotaExceeded => 'Bu hesabın kullanılabilir kotası yok.';

  @override
  String get oauthRateLimited =>
      'Çok fazla istek. Lütfen daha sonra tekrar deneyin.';

  @override
  String get oauthPermissionDenied => 'Bu hesap bu kaynağa erişemiyor.';

  @override
  String get oauthRequestFailed => 'Sağlayıcı isteği tamamlayamadı.';

  @override
  String get oauthQuotaAvailable => 'Kota mevcut';

  @override
  String oauthSavedResets(String count) {
    return 'Kullanılabilir kullanım sıfırlama sayısı: $count';
  }

  @override
  String get oauthPrimaryWindow => 'Birincil pencere';

  @override
  String get oauthSecondaryWindow => 'İkincil pencere';

  @override
  String get oauthAuthorizationCode =>
      'Yetkilendirme kodu veya geri çağrı URL\'si';

  @override
  String get oauthAuthorizationCodeHint =>
      'Tarayıcı otomatik olarak dönmezse, son geri çağrı URL\'sini veya yetkilendirme kodunu buraya yapıştırın.';

  @override
  String get oauthInvalidAuthorizationCode =>
      'Bu giriş denemesinden alınan kodu veya geri çağrı URL\'sini girin.';

  @override
  String get oauthSubmitAuthorizationCode => 'Girişi tamamla';

  @override
  String get oauthExtraUsage => 'Ek kullanım';

  @override
  String get oauthMonthlyTotal => 'Aylık toplam';

  @override
  String get oauthMonthlyCode => 'Aylık kod';

  @override
  String get oauthSpendCap => 'Kredi harcama üst limiti';

  @override
  String get oauthOnDemand => 'Talep üzerine kota';

  @override
  String get oauthQuotaAdvisory =>
      'Yalnızca bilgi amaçlıdır: etkin haftalık krediler bu aylık limiti belirsiz kılar.';

  @override
  String oauthCreditsValue(String value) {
    return '$value kredi';
  }

  @override
  String oauthRemainingValue(String value) {
    return 'Kalan $value';
  }

  @override
  String get oauthPromptCachingHelp =>
      'Bağlamı mesajlar arasında yeniden kullanın ve önbelleğin ne kadar süre saklanacağını seçin.';

  @override
  String get scheduledTasksPreparation => 'Yürütme ve bildirimler';

  @override
  String get scheduledTasksAllowPreparation => 'Önceden hazırlamaya izin ver';

  @override
  String get scheduledTasksPreparationDetail =>
      'Önceden hazırlama, güncel bilgi gerektirmeyen metin görevleri içindir. Araç, ek kullanamaz veya harici işlem yapamaz.';

  @override
  String get scheduledTasksIOSDetail =>
      'iOS arka plan kısıtlamaları, Kelivo\'nun belirlenen saatte uyanıp model çalıştırmasını engeller. Bunun yerine, uygulama çalışabildiğinde içerik hazırlanır ve sistem planlanan saatte bir bildirim gösterir. Yalnızca bir sonraki tekrar hazırlanır. Uygulamadan ayrıldıktan sonra hazırlık tamamlanmayabilir; sonraki tekrarları hazırlamak için Kelivo\'yu yeniden açın.';

  @override
  String get scheduledTasksContextPolicy => 'Sohbet bağlamı';

  @override
  String get scheduledTasksContextLatest => 'En son sohbeti takip et';

  @override
  String get scheduledTasksContextSnapshot =>
      'Hazırlanan anlık görüntüyü kullan';

  @override
  String get scheduledTasksUnavailable => 'Yürütülemediğinde';

  @override
  String get scheduledTasksRemind => 'Yalnızca hatırlatma gönder';

  @override
  String get scheduledTasksSkip => 'Bu tekrarı atla';

  @override
  String get scheduledTasksNotify => 'Sonuç bildirimleri';

  @override
  String get scheduledTasksShowPreview => 'Bildirimlerde sonuç metnini göster';

  @override
  String get scheduledTasksPreparationWindow =>
      'En fazla şu kadar önceden hazırla';

  @override
  String get scheduledTasksPreparationAttempts => 'Otomatik deneme limiti';

  @override
  String get scheduledTasksPreparationCooldown => 'Minimum aralık (dakika)';

  @override
  String get scheduledTasksPreparationBudget =>
      'Tüm görevlerde aynı anda en fazla bir hazırlık yapılır. Saatte toplam altı denemeden sonra otomatik hazırlık duraklar; iptal edilen istekler de sayılır. «Şimdi hazırla» deneme sayısıyla sınırlı değildir.';

  @override
  String get scheduledTasksPreparing => 'Sonuç hazırlanıyor';

  @override
  String get scheduledTasksPrepared => 'Sonuç hazırlandı';

  @override
  String get scheduledTasksPendingPreparation => 'Sonuç henüz hazırlanmadı';

  @override
  String get scheduledTasksNotificationRegistered => 'Bildirim planlandı';

  @override
  String get scheduledTasksNotificationUnavailable => 'Bildirim planlanmadı';

  @override
  String get scheduledTasksReminded => 'Zamanı geldi · yalnızca hatırlatma';

  @override
  String get scheduledTasksSkipped => 'Atlandı';

  @override
  String get scheduledTasksCancelled => 'İptal edildi';

  @override
  String get scheduledTasksReminderBody =>
      'Planlanmış görevinizin zamanı geldi. Devam etmek için Kelivo\'yu açın.';

  @override
  String get scheduledTasksResultBody => 'Planlanmış görevinizin sonucu hazır.';

  @override
  String get scheduledTasksNotificationPermission =>
      'Görev bildirimlerine izin ver';

  @override
  String get scheduledTasksPreparationCost =>
      'Hazırlık modeli çağırır ve ek ücrete yol açabilir. «En son sohbeti takip et» seçiliyken, zamanı gelmeden önceki yeni mesajlar hazırlanan sonucu geçersiz kılabilir. Kullanılmayan veya iptal edilen çıktı yine de faturalandırılabilir ve yeniden hazırlık başka bir model isteği oluşturur.';

  @override
  String get scheduledTasksAllowPreparationTip =>
      'Kelivo çalışabildiğinde bir sonraki sonucu planlanan saatinden önce oluşturun. Sonuç, zamanı gelene kadar sohbette görünmez. Hazırlık yalnızca metin kullanır; araç, ek veya özel istek gövdesi kullanmaz. Model ücretlerine yol açabilir.';

  @override
  String get scheduledTasksContextPolicyTip =>
      'En son sohbeti takip et: görev zamanı gelmeden önce yeni mesajlar, düzenlemeler veya mesaj sürümü değişiklikleri hazırlanan sonucu geçersiz kılar; yeniden hazırlama başka bir deneme kullanır ve ek ücrete yol açabilir. Zamanı geldiğinde, kaydedilen bildirim sonucu değiştirilmeden sohbete eklenir.\n\nHazırlama anındaki görüntüyü kullan: sohbet değişse bile hazırlanan sonucu koru. Sonraki mesajları yansıtmaz.';

  @override
  String get scheduledTasksPreparationWindowTip =>
      'Hazırlığın planlanan saatten en fazla ne kadar önce başlayabileceği, en fazla 24 saat. Örneğin öğlen Kelivo\'yu açmak ertesi sabahki hatırlatmayı hazırlayabilir. Daha geniş bir aralık daha fazla hazırlama şansı verir, ancak sonuç daha eski olabilir. Planlanan saati değiştirmez ve arka planda çalışmayı garanti etmez. Şimdi hazırla bu otomatik bekleme süresini ve tüm deneme sınırlarını atlar.';

  @override
  String get scheduledTasksPreparationAttemptsTip =>
      'Bu tekrar toplam deneme sınırına ulaştığında otomatik hazırlık duraklar. İlk denemeler, başarısızlıklar, iptaller ve manuel hazırlık kayda sayılır. Bu sınıra ulaşıldıktan sonra bile Şimdi hazırla çalışabilir. Daha fazla deneme daha fazla model ücretine yol açabilir; bu bir harcama sınırı değildir.';

  @override
  String get scheduledTasksPreparationCooldownTip =>
      'Aynı tekrar için hazırlık denemelerinin başlangıcı arasındaki en kısa süre. Daha uzun bekleme tekrarlanan istekleri azaltır. Yeniden deneme için yine uygulamanın çalışabilmesi gerekir; bu bir arka plan zamanlayıcısı değildir. Şimdi hazırla bu otomatik bekleme süresini ve tüm deneme sınırlarını atlar.';

  @override
  String get scheduledTasksUnavailableTip =>
      'Hazır bir sonuç yoksa ve görev zamanı geldiğinde çalıştırılamıyorsa, bir hatırlatma gönder veya bu tekrarı atla. Hatırlatma oluşturulmuş bir yanıt içermez ve bildirimlerin etkin olmasını gerektirir. Görev zamanı geldiğinde Kelivo açıksa görevi o anda çalıştırabilir.';

  @override
  String get scheduledTasksNotifyTip =>
      'Sonuç bildirimlerine ve yedek hatırlatmalara izin ver. Bunu kapatmak görevi veya model çağrılarını durdurmaz ve hazırlık ücretlerini engellemez. Ayrıca sistem bildirim izni de gerekir.';

  @override
  String get scheduledTasksShowPreviewTip =>
      'Hazırlanan sonuç metnini bildirimde göster; sistem ayarları izin veriyorsa kilit ekranında da gösterilir. Genel bir bildirim göstermek için bunu kapatın; tam sonuç sohbette kullanılabilir olmaya devam eder. Genel bildirim gizlilik ayarları da geçerlidir.';

  @override
  String scheduledTasksHours(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count saat',
      one: '1 saat',
    );
    return '$_temp0';
  }

  @override
  String scheduledTasksMinutes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count dakika',
      one: '1 dakika',
    );
    return '$_temp0';
  }

  @override
  String get scheduledTasksPreparationOff => 'Hazırlık kapalı';

  @override
  String get scheduledTasksPreparationQueued => 'Sırada';

  @override
  String get scheduledTasksPreparationQueuedDetail =>
      'Başka bir görev hazırlanıyor. Uygun görevler zaman sırasına göre devam eder.';

  @override
  String get scheduledTasksPreparationIdle => 'Sohbet bekleniyor';

  @override
  String get scheduledTasksPreparationIdleDetail =>
      'Etkin yanıtlar bittikten ve bu görevin bağlamı oturduktan sonra hazırlık devam eder.';

  @override
  String get scheduledTasksPreparationWindowWaiting =>
      'Hazırlık aralığı dışında';

  @override
  String get scheduledTasksPreparationCooldownWaiting =>
      'Yeniden deneme bekleniyor';

  @override
  String scheduledTasksPreparationRetryAt(String time) {
    return '$time sonrasında yeniden denenebilir';
  }

  @override
  String get scheduledTasksPreparationLimitReached =>
      'Otomatik deneme sınırına ulaşıldı';

  @override
  String scheduledTasksPreparationAttemptsUsed(int count, int limit) {
    return 'Bu tekrar $count deneme kullandı; otomatik sınır $limit. Manuel devam etmek için Şimdi hazırla\'yı kullanın.';
  }

  @override
  String get scheduledTasksPreparationHourlyLimit =>
      'Otomatik saatlik sınıra ulaşıldı';

  @override
  String get scheduledTasksPreparationHourlyLimitDetail =>
      'Saatlik kapasite kullanılabilir olana kadar otomatik hazırlık duraklatıldı. Şimdi hazırla\'yı yine de kullanabilirsiniz.';

  @override
  String get scheduledTasksPreparationUnavailable => 'Hazırlık kullanılamıyor';

  @override
  String get scheduledTasksPreparationReadFailed =>
      'Görev bağlamı okunamadı. Kısa süre içinde yeniden kontrol edilecek; ayrıntılar için yürütme geçmişine bakın.';

  @override
  String get scheduledTasksPreparationResultRetained =>
      'Bağlam kontrol edilemedi. Hazırlanan sonuç korundu ve yeniden kontrol edilecek.';

  @override
  String get scheduledTasksPreparationContextChanged =>
      'Sohbet veya görev bağlamı değişti, bu nedenle önceki sonuç atıldı.';

  @override
  String get scheduledTasksPreparationPublishing =>
      'Sohbete eklenmeyi bekliyor';

  @override
  String get scheduledTasksPreparationPublishingDetail =>
      'Kaydedilen sonuç, mevcut yanıt bittiğinde sohbete eklenecek.';

  @override
  String get scheduledTasksPreparationPrompt => 'Hazırlık istemi';

  @override
  String get scheduledTasksPreparationPromptTip =>
      'Yalnızca bu görevi önceden hazırlarken kullanılan, görev talimatlarından ayrı ek sistem talimatları. Üslubu değiştirebilir veya bu talimatları tamamen kaldırabilirsiniz. Araçlar ve canlı bilgiler kullanılamaz. Bu istemi düzenlemek, zamanı gelmeden önce hazırlanan sonucu geçersiz kılar; yeniden hazırlama ek model ücretine yol açabilir.';

  @override
  String get scheduledTasksPreparationPromptEmpty =>
      'Hazırlık talimatı eklememek için boş bırakın';

  @override
  String scheduledTasksPreparationPromptVariables(
    String timeVariable,
    String offsetVariable,
  ) {
    return 'Yer tutucular: $timeVariable planlanan yerel teslim saatidir; $offsetVariable onun UTC farkıdır. Sonuç hazırlanırken bunlar değiştirilir.';
  }

  @override
  String get scheduledTasksPrepareNow => 'Şimdi hazırla';

  @override
  String get scheduledTasksPrepareNowDetail =>
      'Sonraki sonucu şimdi hazırla ve planlanan saatte ilet. Otomatik bekleme süreleri ve deneme sınırları uygulanmaz. Bu, model ücretlerine yol açabilir. Mevcut hazırlanmış sonuç yeniden kullanılır.';

  @override
  String get scheduledTasksPrepareNowReady =>
      'Sonraki sonuç zaten hazır. Ek model isteği yapılmadı.';

  @override
  String get scheduledTasksPrepareNowStarted =>
      'Sonraki sonuç planlanan saati için hazırlanıyor.';

  @override
  String get scheduledTasksPrepareNowBusy =>
      'Başka bir görev hazırlanıyor. Bittiğinde lütfen tekrar deneyin.';

  @override
  String get scheduledTasksPrepareNowChatBusy =>
      'Lütfen mevcut yanıtın bitmesini bekleyip tekrar deneyin.';

  @override
  String get scheduledTasksPrepareNowDisabled =>
      'Önce bu görevi ve önceden hazırlığı etkinleştirin. Yeniden oluşturma görevleri önceden hazırlanamaz.';

  @override
  String get scheduledTasksPrepareNowUnavailable =>
      'Hazırlık henüz kullanılamıyor. Lütfen kısa süre sonra tekrar deneyin.';

  @override
  String get scheduledTasksPrepareNowNoUpcoming =>
      'Hazırlanacak yaklaşan bir tekrar yok. Görev saatini ve etkin durumunu kontrol edin.';

  @override
  String get phoneControlTitle => 'Telefon Kontrolü';

  @override
  String get phoneControlSubtitle =>
      'Erişilebilirlik aracılığıyla ekranı oku ve işlemler gerçekleştir';

  @override
  String get phoneControlAccessibilityService => 'Erişilebilirlik hizmeti';

  @override
  String get phoneControlOpenSettings => 'Erişilebilirlik ayarlarını aç';

  @override
  String get phoneControlRefresh => 'Durumu yenile';

  @override
  String get phoneControlChecking => 'Hizmet durumu kontrol ediliyor…';

  @override
  String get phoneControlReady => 'Etkin ve bağlı';

  @override
  String get phoneControlDisabled => 'Etkin değil';

  @override
  String get phoneControlDisconnected =>
      'Etkin, ancak bağlı değil. Sistem ayarlarında hizmeti kapatıp yeniden açmayı deneyin, ardından durumu yenileyin.';

  @override
  String get phoneControlStatusUnavailable =>
      'Hizmet durumu okunamadı. Yenileyip tekrar deneyin.';

  @override
  String get phoneControlSettingsUnavailable =>
      'Ayarlar açılamadı. Android Ayarları → Erişilebilirlik bölümüne manuel olarak gidin.';

  @override
  String get phoneControlUsageTitle => 'Nasıl çalışır';

  @override
  String get phoneControlDisclosure =>
      'Bir sohbette talep ettiğiniz telefon kontrolü görevleri için asistan mevcut ekranı okuyabilir, dokunabilir, metin girebilir, kaydırabilir, gezinabilir ve uygulama açabilir. Ekran içeriği, o sohbet için yapılandırılmış model sağlayıcısına gönderilir ve araç sonuçlarında saklanır. Parola alanları gizlenir. Bu hizmet ekran içeriğini sürekli kaydetmez. Bu aracı asistan için kapatabilir veya hizmeti istediğiniz zaman sistem ayarlarından devre dışı bırakabilirsiniz.';

  @override
  String get phoneControlAssistantTitle =>
      'Aracı asistanınız için etkinleştirin';

  @override
  String get phoneControlAssistantHint =>
      'Her iki izin de gereklidir: sistem Erişilebilirlik ayarlarında Kelivo telefon kontrolünü etkinleştirin, ardından asistanınızın Yerel Araçlar bölümünde Telefon Kontrolü\'nü açın (sohbet araçları menüsünden de erişilebilir). Her asistan ayrı ayrı yapılandırılır. Görev çalışırken telefonun kilidini açık tutun.';

  @override
  String get phoneControlRestrictedTitle =>
      'Erişilebilirlik anahtarı açılamıyor mu?';

  @override
  String get phoneControlRestrictedHint =>
      'Bazı indirilen APK\'ler için Android önce uygulama bilgisi menüsünde \"Kısıtlı ayarlara izin ver\" seçeneğini gerektirir. Kelivo\'nun uygulama bilgilerini açmak için dokunun, ardından Erişilebilirlik ayarlarına dönün.';

  @override
  String get phoneControlEnableAssistant =>
      'Bu asistanın telefon kontrolünü kullanmasına izin ver';

  @override
  String get composerDraftLabel => 'Taslak';

  @override
  String get composerDraftRecovered => 'Gönderilmemiş bir mesaj kurtarıldı.';

  @override
  String get composerDraftRestore => 'Düzenlemeye devam et';

  @override
  String get composerDraftDiscard => 'Vazgeç';

  @override
  String get composerDraftSaveFailed =>
      'Son taslağınız kaydedilemedi. Hâlâ bu pencerede.';

  @override
  String get composerDraftRetry => 'Kaydetmeyi yeniden dene';

  @override
  String get composerDraftConflictTitle => 'Bu sohbette zaten bir taslak var';

  @override
  String get composerDraftConflictBody =>
      'Ekle, her iki metni ve ekleri korur. Değiştir, mevcut taslağı atar. Hiçbir şey otomatik olarak gönderilmez.';

  @override
  String get composerDraftAppend => 'Ekle';

  @override
  String get composerDraftReplace => 'Taslağı değiştir';

  @override
  String get composerDraftMissingFile =>
      'Bir ek kullanılamıyor. Kaldırın veya dosyayı yeniden seçin.';

  @override
  String get composerDraftMessageMissing =>
      'Düzenlenen mesaj artık mevcut değil. Metni yeni bir mesaja kopyalayın veya bu düzenlemeyi iptal edin.';

  @override
  String get composerDraftDeleteNotice =>
      'Bu sohbetlerdeki gönderilmemiş taslaklar da silinecek.';

  @override
  String get mcpOAuthSettings => 'OAuth ayarları';

  @override
  String get mcpOAuthAutomatic => 'Otomatik';

  @override
  String get mcpOAuthMetadataUrl => 'İstemci meta veri belgesi URL\'si';

  @override
  String get mcpOAuthClientAuthentication => 'İstemci kimlik doğrulaması';

  @override
  String get mcpOAuthPublicClient => 'Genel istemci';

  @override
  String get mcpOAuthRedirectUri => 'Yerel geri çağırma URL\'si (isteğe bağlı)';

  @override
  String get mcpOAuthFillRedirectExample => 'Örneği doldur';

  @override
  String get mcpOAuthRedirectHint =>
      'Platform varsayılanını kullanmak için boş bırakın. Hizmet yalnızca localhost geri çağırmalarına izin veriyorsa bir HTTP geri döngü URL\'si kullanın. 0 bağlantı noktası kullanılabilir bir bağlantı noktası seçer; önceden kaydedilmiş bir istemci sabit bir bağlantı noktası gerektirebilir.';

  @override
  String get mcpOAuthClientIdRequired =>
      'Bir istemci kimliği girin veya otomatik kaydı seçin.';

  @override
  String get mcpOAuthMetadataUrlInvalid =>
      'Yol içeren bir HTTPS meta veri belgesi URL\'si girin.';

  @override
  String get mcpOAuthSecretRequired =>
      'Bu istemci kimlik doğrulama yöntemi bir istemci gizli anahtarı gerektirir.';

  @override
  String get mcpOAuthRedirectInvalid =>
      'localhost, 127.0.0.1 veya [::1] üzerinde, kimlik bilgileri, sorgu parametreleri veya parça içermeyen bir HTTP geri çağırma adresi kullanın.';

  @override
  String get mcpOAuthDiscovering => 'Yetkilendirme sunucusu keşfediliyor…';

  @override
  String get mcpOAuthRegistering => 'Yetkilendirme hazırlanıyor…';

  @override
  String get mcpOAuthWaitingBrowser => 'Tarayıcı yetkilendirmesi bekleniyor…';

  @override
  String get mcpOAuthExchangingToken => 'Oturum açma tamamlanıyor…';

  @override
  String get markdownPlaygroundTitle => 'Markdown Playground';

  @override
  String get markdownPlaygroundSource => 'Markdown kaynağı';

  @override
  String get markdownPlaygroundPreview => 'Önizleme';

  @override
  String get markdownPlaygroundAst => 'AST';

  @override
  String get markdownPlaygroundPlay => 'Karakterleri akıt';

  @override
  String get markdownPlaygroundPause => 'Duraklat';

  @override
  String get markdownPlaygroundResume => 'Devam et';

  @override
  String get markdownPlaygroundShowAll => 'Tamamını göster';

  @override
  String get markdownPlaygroundWidth => 'Önizleme genişliği';

  @override
  String get markdownPlaygroundTheme => 'Önizleme teması';

  @override
  String get markdownPlaygroundPlain => 'Seçili düz metin';

  @override
  String get markdownPlaygroundMarkdown => 'Seçili Markdown';

  @override
  String get markdownPlaygroundSelectionHint =>
      'Kopyalanan içeriği incelemek için önizlemede metin seçin.';

  @override
  String get markdownPlaygroundEmpty => 'Önizlemek için Markdown girin.';

  @override
  String markdownPlaygroundProgress(int shown, int total) {
    return 'Girilen $shown / $total';
  }

  @override
  String get markdownCopyMarkdownAction => 'Markdown\'u kopyala';

  @override
  String get markdownCopyCsvAction => 'CSV\'yi kopyala';

  @override
  String get markdownCopyImageAction => 'Görseli kopyala';

  @override
  String get markdownCodeLabel => 'Kod';

  @override
  String get markdownDetailsLabel => 'Ayrıntılar';

  @override
  String markdownMoreRows(int count) {
    return '$count satır daha göster';
  }

  @override
  String get markdownNoteLabel => 'Not';

  @override
  String get markdownTipLabel => 'İpucu';

  @override
  String get markdownImportantLabel => 'Önemli';

  @override
  String get markdownWarningLabel => 'Uyarı';

  @override
  String get markdownCautionLabel => 'Dikkat';

  @override
  String get markdownDangerLabel => 'Tehlike';

  @override
  String get markdownCopyRichTextAction => 'Zengin metni kopyala';

  @override
  String get markdownCopySelectionFailed => 'Seçilen metin kopyalanamadı.';

  @override
  String get recoveryMissingDataTitle => 'Önceki veriler algılandı';

  @override
  String get recoveryMissingDataBody =>
      'Kelivo mevcut sohbet veritabanını bulamadı. Yüklemeyi duraklattı ve boş bir veritabanı oluşturmadı. Aşağıda önceki kopyaları arayacağız; mevcut dosyalar korunacak.';

  @override
  String get recoveryEmptyDataTitle => 'Mevcut sohbet geçmişi boş';

  @override
  String get recoveryEmptyDataBody =>
      'Mevcut sohbet listesi boş, ancak önceki kopyalar bulundu. Sohbetlerinizi kurtarmak için aşağıdan bir kopya seçin. Mevcut dosyalar korunacak.';

  @override
  String get recoveryKeepCurrent => 'Boş sohbet listesiyle devam et';

  @override
  String get recoveryKeepCurrentConfirm =>
      'Bu işlem önceki sohbetlerinizi kurtarmadan devam eder. Mevcut sohbet listesi boş kalır; eski kopyalar korunur. Sohbetlerinizi geri istiyorsanız iptal edip yerel bir kopya seçin.';

  @override
  String get recoverySearchingCopies =>
      'Yerel veri kopyaları aranıyor ve doğrulanıyor…';

  @override
  String recoveryFoundCopies(int count) {
    return '$count doğrulanmış kopya bulundu. Sohbetlerinizi ve ayarlarınızı kurtarmak için birini seçin. Orijinal dosyalar korunacak.';
  }

  @override
  String recoveryInvalidCopy(String name) {
    return '$name: doğrulama başarısız. Orijinal dosya korundu.';
  }

  @override
  String get recoverySearchFailed =>
      'Bazı veri konumları okunamadı. Dosyalarınız korundu; diğer kurtarma işlemlerini denemeden önce bir veri kopyası dışa aktarın.';

  @override
  String get recoveryDiscoveredCopyBody =>
      'Yönetilen kopya klasörünün dışında bulundu. Bu orijinal korunur ve kurtarma öncesinde tam olarak doğrulanır.';

  @override
  String get recoveryStorageFailureTitle =>
      'Veri depolama kontrol gerektiriyor';

  @override
  String get recoveryStorageFailureBody =>
      'Veri güncellemesi tamamlanamadı. Orijinal veriler korundu. Kelivo\'yu yeniden açmayı deneyin veya kurtarmak için aşağıdan yerel bir kopya seçin.';

  @override
  String get recoveryProtectingTitle => 'Sohbet veritabanı korunuyor';

  @override
  String get recoveryProtectingData =>
      'Veritabanı kopyalanıyor ve doğrulanıyor. Görseller, ekler ve anlık görüntüler Documents içinde kalır ve yeniden kopyalanmaz. Orijinal veritabanı da korunacak.';

  @override
  String get recoveryStorageReadyTitle =>
      'Sohbet veritabanı dahili depolamaya taşındı';

  @override
  String get recoveryStorageReadyBody =>
      'Sohbetleri, asistanları ve ayarları içeren veritabanı artık uygulamanın dahili depolamasını kullanıyor. Anlık görüntüler, görseller ve ekler Dosyalar uygulamasında Documents altında erişilebilir durumda kalır. Orijinal veritabanı korunur. Daha eski sohbetler eksikse Ayarlar → Yedek → Yerel Kopyalar bölümünü açın.';

  @override
  String get recoveryRetainedData => 'Korunan orijinal veriler';

  @override
  String get recoveryNoValidCopies =>
      'Kopyalar bulundu, ancak hiçbiri doğrulamadan geçmedi. Orijinaller korundu. Daha fazla inceleme için verilerinizi dışa aktarabilirsiniz.';

  @override
  String get recoveryStorageInsufficientSpaceBody =>
      'Verilerinizi güvenli şekilde hazırlamak için yeterli depolama alanı yok. Sistem ayarlarından alan boşaltın, ardından Kelivo\'yu yeniden açın veya aşağıdaki kopyaları yeniden kontrol edin. Kelivo\'yu yüklü tutun ve verilerini ve yerel kopyalarını yerinde bırakın.';

  @override
  String get migrationFreshStartTitle => 'Yeni başlangıç hazır';

  @override
  String get migrationFreshStartSubtitle =>
      'Yeni boş bir veritabanı hazır ve önceki verileriniz korundu. Devam etmek için uygulamayı yeniden başlatın.';

  @override
  String get migrationFreshStartFailedTitle => 'Yeni başlangıç tamamlanamadı';

  @override
  String get migrationFreshStartFailedSubtitle =>
      'Önceki verileriniz korundu. Yeni başlangıcı yeniden deneyin veya uygulamayı kapatıp yeniden açın.';

  @override
  String get imageExportPreparing => 'Görsel hazırlanıyor…';

  @override
  String imageExportDiagrams(int completed, int total) {
    return 'Diyagramlar hazırlanıyor $completed/$total…';
  }

  @override
  String imageExportCapturing(int completed, int total) {
    return 'Görsel yakalanıyor $completed/$total…';
  }

  @override
  String get imageExportProcessing =>
      'Görsel birleştiriliyor ve önizleme hazırlanıyor…';

  @override
  String get imageExportSaving => 'Görsel kaydediliyor…';

  @override
  String get backupEncryptionTitle => 'Yedekleri şifrele';

  @override
  String get backupEncryptionOffHint =>
      'Şifrelenmemiş yedekler, dosyaya erişen herkes tarafından okunabilir.';

  @override
  String get backupEncryptionOnHint =>
      'Yedekler şifrelenir. Uygulamayı yeniden başlattıktan sonra parolayı tekrar girin.';

  @override
  String get backupEncryptionPasswordHint =>
      'Bu parolayı güvenli tutun. Kaybederseniz yedek geri yüklenemez. Uygulamadan çıkana kadar yalnızca bellekte tutulur.';

  @override
  String get backupEncryptionPassword => 'Parola';

  @override
  String get backupEncryptionConfirmPassword => 'Parolayı onayla';

  @override
  String get backupEncryptionMismatch => 'Parolalar eşleşmiyor.';

  @override
  String get backupEncryptionShowPassword => 'Parolayı göster';

  @override
  String get backupEncryptionHidePassword => 'Parolayı gizle';

  @override
  String get backupEncryptionUnlockTitle => 'Şifreli yedek';

  @override
  String get backupEncryptionUnlockHint =>
      'Bu yedeği oluştururken kullandığınız parolayı girin.';

  @override
  String get backupEncryptionUnlock => 'Kilidi aç';

  @override
  String get backupEncryptionFailed =>
      'Parola yanlış veya yedek hasarlı. Tekrar deneyin ya da iptal edin.';

  @override
  String get backupEncryptionInvalid => 'Şifreli yedek eksik veya geçersiz.';

  @override
  String get backupEncryptionUnsupported =>
      'Bu şifreli yedek, Kelivo\'nun daha yeni bir sürümünü gerektiriyor.';

  @override
  String get backupProgressEncrypting => 'Yedek şifreleniyor';

  @override
  String get backupProgressDecrypting => 'Yedek şifresi çözülüyor';

  @override
  String get mcpPageStatusFailed => 'Bağlantı başarısız';

  @override
  String mcpPageCardToolsShort(int enabled, int total) {
    return 'Araçlar $enabled/$total';
  }

  @override
  String mcpPageSelectServer(String name) {
    return '$name seç';
  }

  @override
  String get mcpIconTitle => 'Sunucu simgesi';

  @override
  String get mcpIconInvalid =>
      'Bu görsel kullanılamıyor. En fazla 10 MB boyutunda geçerli bir görsel seçin.';

  @override
  String get mcpSelectServers => 'Sunucuları seç';

  @override
  String get mcpMoveToGroup => 'Gruba taşı';

  @override
  String get mcpRenameGroup => 'Grubu yeniden adlandır';

  @override
  String get mcpDeleteGroupConfirm =>
      'Bu gruptaki sunucular Diğer grubuna taşınacak. Sunucular silinmeyecek.';

  @override
  String get mcpGroupNameInvalid =>
      'Boş olmayan ve benzersiz bir grup adı kullanın.';

  @override
  String get mcpEnableSelected => 'Etkinleştir';

  @override
  String get mcpDisableSelected => 'Devre dışı bırak';

  @override
  String mcpDeleteSelectedConfirm(int count) {
    return 'Seçili $count sunucu silinsin mi?';
  }

  @override
  String get browserTitle => 'Tarayıcı';

  @override
  String get browserSearchHint => 'Ara veya web sitesi adresi gir';

  @override
  String get browserStartTitle => 'Sırada nereye?';

  @override
  String get browserStartSubtitle =>
      'Özgürce gezin. İhtiyaç duyduğunuzda ajanınızın yardım etmesine izin verin.';

  @override
  String get browserNewTab => 'Yeni sekme';

  @override
  String get browserTabs => 'Sekmeler';

  @override
  String get browserCloseTab => 'Sekmeyi kapat';

  @override
  String get browserClose => 'Tarayıcıyı kapat';

  @override
  String get browserBack => 'Geri';

  @override
  String get browserForward => 'İleri';

  @override
  String get browserReload => 'Yeniden yükle';

  @override
  String get browserStop => 'Yüklemeyi durdur';

  @override
  String get browserMore => 'Daha fazla';

  @override
  String get browserBookmarks => 'Yer imleri';

  @override
  String get browserHistory => 'Geçmiş';

  @override
  String get browserSettings => 'Tarayıcı ayarları';

  @override
  String get browserAddBookmark => 'Yer imi ekle';

  @override
  String get browserRemoveBookmark => 'Yer imini kaldır';

  @override
  String get browserNoBookmarks => 'Favori siteleriniz burada görünür.';

  @override
  String get browserNoHistory => 'Tarama geçmişiniz burada görünür.';

  @override
  String get browserSearchLibrary => 'Kaydedilen sayfalarda ara';

  @override
  String get browserClearHistory => 'Geçmişi temizle';

  @override
  String get browserClearHistoryConfirm =>
      'Tüm tarama geçmişi silinsin mi? Yer imleri korunacak.';

  @override
  String get browserToday => 'Bugün';

  @override
  String get browserYesterday => 'Dün';

  @override
  String get browserDelete => 'Sil';

  @override
  String get browserCancel => 'İptal';

  @override
  String get browserDone => 'Tamam';

  @override
  String get browserFind => 'Sayfada bul';

  @override
  String get browserFindPreviousMatch => 'Önceki eşleşme';

  @override
  String get browserFindNextMatch => 'Sonraki eşleşme';

  @override
  String get browserFindHint => 'Metin bul';

  @override
  String get browserSearchEngine => 'Arama motoru';

  @override
  String get browserDesktopMode => 'Masaüstü sitesi';

  @override
  String get browserDesktopModeDescription =>
      'Açık sayfaları masaüstü kullanıcı aracısıyla yeniden yükle.';

  @override
  String get browserRestoreTabs => 'Sekmeleri geri yükle';

  @override
  String get browserRestoreTabsDescription =>
      'Kelivo başladığında sekmelerinizi yeniden aç.';

  @override
  String get browserSaveHistory => 'Geçmişi kaydet';

  @override
  String get browserSaveHistoryDescription =>
      'Ziyaret ettiğiniz sayfaların yerel bir kaydını tut.';

  @override
  String get browserClearData => 'Web sitesi verilerini temizle';

  @override
  String get browserClearDataConfirm =>
      'Çerezler, depolama ve önbellek temizlensin ve tüm sekmeler kapatılsın mı? Web sitelerinden oturumunuz kapatılacak.';

  @override
  String get browserDataCleared => 'Web sitesi verileri temizlendi';

  @override
  String get browserAgentControl => 'Asistan kontrolü';

  @override
  String get browserAgentWorking => 'AI çalışıyor';

  @override
  String get browserTakeOver => 'Devral';

  @override
  String get browserAgentPaused => 'AI işlemleri duraklatıldı';

  @override
  String get browserAllowAgent => 'Devam etmesine izin ver';

  @override
  String get browserAgentDescription =>
      'AI\'ın tarayıcıyı kullanabilmesi için sohbette bir görev gönderin. Devam etmesine izin vermek yalnızca duraklatmayı kaldırır; mesaj göndermez veya görev başlatmaz.';

  @override
  String get browserOpenExternal => 'Varsayılan tarayıcıda aç';

  @override
  String get browserCopyLink => 'Bağlantıyı kopyala';

  @override
  String get browserLinkCopied => 'Bağlantı kopyalandı';

  @override
  String get browserUnsupported =>
      'Gömülü tarayıcı bu platformda kullanılamıyor.';

  @override
  String get browserStorageUnsupported =>
      'Bu çalışma alanı uygulaması Android System WebView veya Microsoft Edge WebView2 Runtime 152 ya da daha yeni bir sürüm gerektirir. Tarayıcı motorunu güncelleyip tekrar deneyin.';

  @override
  String get browserLoadFailed => 'Bu sayfa yüklenemedi';

  @override
  String get browserRetry => 'Tekrar dene';

  @override
  String get browserFavorites => 'Favoriler';

  @override
  String get browserEditBookmark => 'Yer imini düzenle';

  @override
  String get browserBookmarkTitle => 'Başlık';

  @override
  String get browserBookmarkUrl => 'Web sitesi';

  @override
  String get browserSave => 'Kaydet';

  @override
  String get browserDownloads => 'İndirilenler';

  @override
  String get browserNoDownloads => 'İndirilen dosyalar burada görünür.';

  @override
  String get browserDownloadCancel => 'İndirmeyi iptal et';

  @override
  String get browserOpenDownload => 'Dosyayı aç';

  @override
  String get browserDownloadFailed => 'İndirme başarısız';

  @override
  String get browserAgentEnableHint =>
      'Sohbet araçlarında Tarayıcı aracını etkinleştirin, ardından burada kontrol izni verin.';

  @override
  String get browserSessionRequired =>
      'Asistan kontrolüne izin vermek için tarayıcıyı bir sohbetten açın.';

  @override
  String get browserDownloadCancelled => 'İptal edildi';

  @override
  String get browserAgentEnabled => 'Asistanın tarayıcıya erişmesine izin ver';

  @override
  String get browserAgentEnabledDescription =>
      'Etkinleştirilen asistanlar bu tarayıcıdaki sayfalara göz atabilir ve onlarla etkileşime geçebilir.';

  @override
  String get browserToolTitle => 'Tarayıcı kontrolü';

  @override
  String get browserToolSubtitle =>
      'Oturum açılmış sayfalara göz atın ve onlarla etkileşime geçin. Önce tarayıcı ayarlarında Asistan kontrolünü etkinleştirin.';

  @override
  String get browserOpen => 'Tarayıcıyı aç';

  @override
  String get browserInvalidUrl =>
      'Geçerli bir HTTP veya HTTPS web sitesi adresi girin.';

  @override
  String get browserClearDataUnavailable =>
      'Tüm web sitesi verilerini temizleme Windows tarayıcı motoru tarafından desteklenmiyor.';

  @override
  String get browserSurfaceStyle => 'Yüzey stili';

  @override
  String get browserSurfaceLiquid => 'Sıvı cam';

  @override
  String get browserSurfaceFrosted => 'Buzlu';

  @override
  String get browserSurfaceSolid => 'Düz';

  @override
  String get browserPageOptions => 'Sayfa seçenekleri';

  @override
  String get browserAskAi => 'AI bu sayfa üzerinde çalışsın';

  @override
  String get browserAskAiHint =>
      'Sohbete dönün, isteğinizi ekleyin, ardından gönderin.';

  @override
  String get browserAskAiCurrentPage => 'tarayıcıdaki geçerli sayfa';

  @override
  String get browserAskAiUnavailable =>
      'Bu sohbet kullanılamıyor. Önce bir sohbetten tarayıcıyı açın.';

  @override
  String get browserAskAiEditing =>
      'Bir sayfa görevi eklemeden önce geçerli mesajı düzenlemeyi bitirin veya iptal edin.';

  @override
  String get browserAskAiAssistantDisabled =>
      'Önce bu asistanın araçlarında Tarayıcı kontrolünü etkinleştirin.';

  @override
  String get browserAskAiBrowserDisabled =>
      'Önce tarayıcı ayarlarında asistanların tarayıcıyı kullanmasına izin verin.';

  @override
  String browserAskAiDraft(String page) {
    return 'Lütfen bu sayfa üzerinde çalışmak için tarayıcıyı kullanın:\n$page\n\nİsteğim: ';
  }

  @override
  String get browserOpenFullPage => 'Tam sayfa olarak aç';

  @override
  String get browserClosePanel => 'Tarayıcı panelini kapat';

  @override
  String get browserSearchTabs => 'Sekmelerde ara';

  @override
  String browserTabsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count sekme',
      one: '1 sekme',
    );
    return '$_temp0';
  }

  @override
  String get browserOpenInSidebar => 'Kenar çubuğunda aç';

  @override
  String get browserUserAgent => 'Kullanıcı aracısı';

  @override
  String get browserUserAgentMobile => 'Mobil';

  @override
  String get browserUserAgentDesktop => 'Masaüstü';

  @override
  String get browserUserAgentCustom => 'Özel';

  @override
  String get browserUserAgentHint => 'Özel bir User-Agent girin';

  @override
  String get browserUserAgentInvalid =>
      '2048 karaktere kadar tek satır yazdırılabilir ASCII karakter kullanın.';

  @override
  String get browserUserAgentDescription =>
      'Değişiklikler geçerli web sayfasını yeniden yükler.';

  @override
  String browserStepsShowEarlier(int count) {
    return '$count önceki adım';
  }

  @override
  String get browserOpenThisPage => 'Tarayıcıda aç';

  @override
  String get browserGroupToggleSemantics =>
      'Tarayıcı adımlarını göster veya gizle';

  @override
  String get browserStepGroupTitle => 'Gözatma';

  @override
  String browserStepCount(int count) {
    return '$count adım';
  }

  @override
  String browserStepCurrent(int count) {
    return '$count. adım';
  }

  @override
  String browserActionFailedCount(int count) {
    return '· $count başarısız';
  }

  @override
  String browserActionFailed(String action) {
    return '$action başarısız oldu';
  }

  @override
  String get browserCardOpen => 'Aç';

  @override
  String get browserCardEnable => 'Etkinleştir';

  @override
  String browserCardRunning(String action) {
    return '$action…';
  }

  @override
  String get browserCardLive => 'Canlı';

  @override
  String get browserCardOpenFailed => 'Sayfa açılamadı';

  @override
  String get browserCardBlankPage => 'Boş sayfa';

  @override
  String browserCardTabCount(int count) {
    return '$count sekme';
  }

  @override
  String get browserActionOpen => 'Sayfayı aç';

  @override
  String get browserActionNewTab => 'Yeni sekme';

  @override
  String get browserActionRender => 'Sayfayı işle';

  @override
  String get browserActionExtract => 'Metni çıkar';

  @override
  String get browserActionSnapshot => 'Sayfa yapısını oku';

  @override
  String get browserActionClick => 'Tıkla';

  @override
  String get browserActionType => 'Yaz';

  @override
  String get browserActionPress => 'Tuşa bas';

  @override
  String get browserActionScroll => 'Kaydır';

  @override
  String get browserActionWait => 'Bekle';

  @override
  String get browserActionBack => 'Geri';

  @override
  String get browserActionForward => 'İleri';

  @override
  String get browserActionReload => 'Yenile';

  @override
  String get browserActionEvaluate => 'Betik çalıştır';

  @override
  String get browserActionSwitchTab => 'Sekme değiştir';

  @override
  String get browserActionCloseTab => 'Sekmeyi kapat';

  @override
  String get browserActionListTabs => 'Sekmeleri listele';

  @override
  String get browserActionUnknown => 'Tarayıcı işlemi';

  @override
  String browserMetaChars(String count) {
    return '$count karakter';
  }

  @override
  String browserMetaElements(int count) {
    return '$count öğe';
  }

  @override
  String get browserErrAgentDisabled => 'Tarayıcı kontrolü kapalı';

  @override
  String get browserErrStaleRef =>
      'Öğe artık geçersiz; sayfanın yeniden okunması gerekiyor';

  @override
  String get browserErrNotVisible => 'Öğe gizli veya örtülü';

  @override
  String get browserErrNotFound => 'Öğe bulunamadı';

  @override
  String get browserErrTimeout => 'Sayfa yükleme zaman aşımına uğradı';

  @override
  String get browserErrHumanControl => 'Tarayıcıyı siz kontrol ediyorsunuz';

  @override
  String get browserErrTabClosed => 'Sekme kapatıldı';

  @override
  String get browserErrGeneric => 'İşlem başarısız';

  @override
  String get browserDirectionUp => 'Yukarı';

  @override
  String get browserDirectionDown => 'Aşağı';

  @override
  String get browserDirectionLeft => 'Sol';

  @override
  String get browserDirectionRight => 'Sağ';

  @override
  String browserMetaTabs(int count) {
    return '$count sekme';
  }

  @override
  String get browserTabsCurrentConversation => 'Bu sohbet';

  @override
  String get browserTabsAll => 'Tüm sekmeler';

  @override
  String get browserTabsUnassigned => 'Kişisel sekmeler';

  @override
  String get browserTabsUnknownConversation => 'Diğer sohbet';

  @override
  String get browserTabsEmptyConversation =>
      'Burada henüz sekme yok. Bir sayfa açın veya Tüm sekmeler\'den bir sekme seçin.';

  @override
  String get browserTabsNoResults => 'Eşleşen sekme yok';

  @override
  String get browserMoveToConversation => 'Bu sohbete taşı';

  @override
  String get browserReopenInConversation => 'Bu sohbette yeniden aç';

  @override
  String get browserTabBusy =>
      'Bir asistan hâlâ bu sayfayı kullanıyor. Taşımadan önce işlemin bitmesini bekleyin veya görevi durdurun.';

  @override
  String get browserLiveViewLimit =>
      'Tüm tarayıcı kaynakları kullanımda. Bir görev bittiğinde tekrar deneyin veya kullanılmayan bir sayfayı kapatın.';

  @override
  String get browserAskAiInOwnerConversation =>
      'Sahip sohbetteki AI\'dan isteyin';

  @override
  String get displaySettingsPageShowBrowserPageCardsTitle =>
      'Web sayfası kartlarını göster';

  @override
  String get browserObserverHint =>
      'AI bu sayfayı kullanıyor. Etkileşim için Devral\'ı seçin.';

  @override
  String get genuiSurfaceTitle => 'Etkileşimli arayüz';

  @override
  String get genuiStatusStreaming => 'Oluşturuluyor';

  @override
  String get genuiStatusInterrupted => 'Kesildi';

  @override
  String get genuiStatusUnsaved => 'Kaydedilmedi';

  @override
  String get genuiStatusUnsavedRetry =>
      'Kaydetmeyi yeniden denemek için dokunun';

  @override
  String get genuiReadOnlyUntilComplete =>
      'Oluşturma tamamlandığında kullanılabilir';

  @override
  String get genuiReadOnlySnapshot => 'Salt okunur anlık görüntü';

  @override
  String genuiPendingNode(String id) {
    return '$id bekleniyor';
  }

  @override
  String get genuiViewSource => 'Kaynağı görüntüle';

  @override
  String get genuiCopySource => 'Kaynağı kopyala';

  @override
  String get genuiExpand => 'Genişlet';

  @override
  String get genuiExpandedStub => 'Genişletilmiş görünümde düzenleniyor';

  @override
  String get genuiMore => 'Daha fazla';

  @override
  String get genuiReset => 'Varsayılanlara sıfırla';

  @override
  String get genuiRepair => 'Arayüzü onar';

  @override
  String get genuiInvalidTitle => 'Bu arayüz görüntülenemiyor';

  @override
  String genuiNodesFailed(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count düğüm görüntülenemiyor',
      one: '1 düğüm görüntülenemiyor',
    );
    return '$_temp0';
  }

  @override
  String genuiErrorLine(int line) {
    return 'Satır $line';
  }

  @override
  String get genuiValueUnavailable => 'Değer yok';

  @override
  String get genuiFormulaInvalid => 'Bu formül görüntülenemiyor';

  @override
  String get genuiNodeUnavailable => 'Bu bileşen kullanılamıyor';

  @override
  String get genuiErrorHeader => 'Geçersiz arayüz başlığı';

  @override
  String get genuiErrorVersion => 'Desteklenmeyen arayüz dili sürümü';

  @override
  String get genuiErrorCatalog => 'Desteklenmeyen bileşen kataloğu';

  @override
  String get genuiErrorRoot => 'Kök bileşen eksik veya geçersiz';

  @override
  String get genuiErrorSyntax => 'Geçersiz bildirim söz dizimi';

  @override
  String get genuiErrorDuplicateSymbol => 'Bir ad birden fazla kez tanımlanmış';

  @override
  String get genuiErrorDuplicateProperty =>
      'Bir özellik birden fazla kez tanımlanmış';

  @override
  String get genuiErrorReservedName => 'Bu ad ayrılmıştır';

  @override
  String genuiErrorUnknownComponent(String detail) {
    return 'Bilinmeyen bileşen $detail';
  }

  @override
  String genuiErrorUnknownProperty(String detail) {
    return 'Bilinmeyen özellik $detail';
  }

  @override
  String genuiErrorMissingProperty(String detail) {
    return 'Gerekli özellik $detail eksik';
  }

  @override
  String get genuiErrorBinding => 'Geçersiz yazılabilir giriş bağlaması';

  @override
  String get genuiErrorReference => 'Geçersiz bileşen başvurusu';

  @override
  String get genuiErrorMissingReference => 'Başvurulan içerik tanımlanmamış';

  @override
  String get genuiErrorDependency => 'Gerekli içerik görüntülenemiyor';

  @override
  String get genuiErrorCycle => 'Döngüsel başvurular desteklenmiyor';

  @override
  String get genuiErrorDuplicateParent => 'Bir bileşenin iki üst öğesi olamaz';

  @override
  String get genuiErrorUnreachableNode => 'Bu bileşen kök ağacın dışında';

  @override
  String get genuiErrorType => 'Değerin türü uyumsuz';

  @override
  String get genuiErrorValue =>
      'Değer desteklenen seçeneklerin veya aralığın dışında';

  @override
  String get genuiErrorSourceBudget => 'Arayüz kaynağı boyut sınırını aşıyor';

  @override
  String get genuiErrorDeclarationBudget =>
      'Bir bildirim boyut sınırını aşıyor';

  @override
  String get genuiErrorDeclarationCount => 'Çok fazla bildirim';

  @override
  String get genuiErrorComponentCount => 'Çok fazla bileşen';

  @override
  String get genuiErrorInputCount => 'Çok fazla giriş';

  @override
  String get genuiErrorComponentDepth => 'Bileşenler çok derin iç içe geçmiş';

  @override
  String get genuiErrorExpressionDepth => 'Hesaplama çok derin iç içe geçmiş';

  @override
  String get genuiErrorFunction => 'Bilinmeyen hesaplama işlevi';

  @override
  String get genuiErrorAction => 'Desteklenmeyen eylem';

  @override
  String get genuiErrorNestedSample => 'İç içe örnekleme desteklenmiyor';

  @override
  String get genuiErrorSample => 'Geçersiz örnekleme aralığı veya sayısı';

  @override
  String get genuiErrorDataBudget => 'Veri desteklenen boyutu aşıyor';

  @override
  String get genuiErrorRowKey =>
      'Satırların benzersiz ve boş olmayan anahtarları olmalı';

  @override
  String get genuiErrorDomain => 'Değer işlev tanım alanının dışında';

  @override
  String get genuiErrorDivisionByZero => 'Sıfıra bölme tanımsızdır';

  @override
  String get genuiErrorNonFinite => 'Hesaplama sonlu olmayan bir sayı üretti';

  @override
  String get genuiErrorOperationsBudget => 'Hesaplama işlem sınırını aştı';

  @override
  String genuiMetricTrend(String value) {
    return 'Değişim $value';
  }

  @override
  String genuiFormErrorsLeft(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count alanın düzeltilmesi gerekiyor',
      one: '1 alanın düzeltilmesi gerekiyor',
    );
    return '$_temp0';
  }

  @override
  String get genuiFieldRequired => 'Zorunlu';

  @override
  String genuiNumberRange(String min, String max) {
    return 'Aralık $min–$max';
  }

  @override
  String genuiNumberMinimum(String min) {
    return 'En az $min';
  }

  @override
  String genuiNumberMaximum(String max) {
    return 'En çok $max';
  }

  @override
  String genuiFieldTooShort(int min) {
    return 'En az $min karakter';
  }

  @override
  String genuiFieldTooLong(int max) {
    return 'En çok $max karakter';
  }

  @override
  String get genuiInvalidNumber => 'Tam ve sonlu bir sayı girin';

  @override
  String get genuiChooseOption => 'Bir seçenek seçin';

  @override
  String get genuiFinishComposing => 'Devam etmeden önce yazımı tamamlayın';

  @override
  String genuiActionDisabledDep(String id) {
    return 'Devre dışı: görüntülenemeyen $id öğesine bağlı';
  }

  @override
  String get genuiActionUnavailable => 'Bu eylem bu görünümde kullanılamıyor';

  @override
  String get genuiActionDisabled => 'Bu arayüz tarafından devre dışı bırakıldı';

  @override
  String get genuiFormUnavailable =>
      'Bu form görüntülenemeyen içerik barındırıyor';

  @override
  String genuiDecrease(String label) {
    return '$label değerini azalt';
  }

  @override
  String genuiIncrease(String label) {
    return '$label değerini artır';
  }

  @override
  String genuiCharacterCount(int used, int max) {
    return '$used / $max karakter';
  }

  @override
  String get genuiBlockLimit =>
      'Mesaj başına en fazla 3 arayüz bloğu; geri kalanı kaynak olarak gösterilir';

  @override
  String get genuiChartLine => 'Çizgi grafik';

  @override
  String get genuiChartArea => 'Alan grafik';

  @override
  String get genuiChartBar => 'Çubuk grafik';

  @override
  String get genuiChartScatter => 'Dağılım grafiği';

  @override
  String get genuiChartPie => 'Pasta grafik';

  @override
  String get genuiChartDonut => 'Halka grafik';

  @override
  String get genuiChartEmpty => 'Bu aralıkta veri yok';

  @override
  String get genuiChartAllHidden =>
      'Tüm seriler gizli. Göstermek için açıklamayı kullanın.';

  @override
  String genuiChartSummary(String kind, int series, int points, int missing) {
    String _temp0 = intl.Intl.pluralLogic(
      series,
      locale: localeName,
      other: '$series seri',
      one: '1 seri',
    );
    String _temp1 = intl.Intl.pluralLogic(
      points,
      locale: localeName,
      other: '$points veri satırı',
      one: '1 veri satırı',
    );
    String _temp2 = intl.Intl.pluralLogic(
      missing,
      locale: localeName,
      other: '$missing eksik değer',
      one: '1 eksik değer',
    );
    return '$kind, $_temp0, $_temp1, $_temp2 (bağlanmaz veya sıfırla değiştirilmez).';
  }

  @override
  String genuiChartPieSummary(String kind, int count, String total) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count öğe',
      one: '1 öğe',
    );
    return '$kind, $_temp0, toplam $total.';
  }

  @override
  String get genuiChartDomainGap => 'Tanımsız';

  @override
  String genuiChartDomainSummary(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count örneklenen nokta tanımsız',
      one: '1 örneklenen nokta tanımsız',
    );
    return '$_temp0; gölgeli boşluklar bağlanmaz.';
  }

  @override
  String genuiChartShowSeries(String name) {
    return '$name göster';
  }

  @override
  String genuiChartHideSeries(String name) {
    return '$name gizle';
  }

  @override
  String get genuiChartKeyboardHint =>
      'Sol ve sağ bir veri satırı seçer. Yukarı ve aşağı bir seri seçer. Escape seçimi temizler.';

  @override
  String get genuiChartTotal => 'Toplam';

  @override
  String get genuiChartFieldsError =>
      'Bir X alanı ve bir ila dört farklı Y alanı seçin.';

  @override
  String get genuiChartRecordsError =>
      'Grafik verisi bir kayıt listesi olmalıdır.';

  @override
  String get genuiChartXError =>
      'X değerlerinin tümü sayı veya tümü metin olmalıdır. Dağılım grafikleri sayı gerektirir.';

  @override
  String get genuiChartYError =>
      'Y alanları mevcut olmalı ve sayılar veya eksik değerler içermelidir.';

  @override
  String get genuiChartPieError =>
      'Pasta değerleri negatif olmamalı ve sıfırdan büyük sonlu bir toplamı olmalıdır.';

  @override
  String genuiChartMissingValues(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count değer eksik; sıfırla değiştirilmez.',
      one: '1 değer eksik; sıfırla değiştirilmez.',
    );
    return '$_temp0';
  }

  @override
  String get genuiChartNoVisibleValues =>
      'Seçili serilerin çizilecek değeri yok.';

  @override
  String genuiChartUnit(String unit) {
    return 'Birim: $unit';
  }

  @override
  String get genuiSomeValuesUnavailable => 'Bazı değerler kullanılamıyor';

  @override
  String get genuiViewChart => 'Grafik';

  @override
  String get genuiViewData => 'Veri';

  @override
  String get genuiTableFilterHint => 'Görünür metni filtrele';

  @override
  String genuiTableRows(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count satır',
      one: '1 satır',
    );
    return '$_temp0';
  }

  @override
  String genuiTablePageInfo(int from, int to, int total) {
    return '$total satırdan $from–$to. satırlar';
  }

  @override
  String genuiTablePerPage(int n) {
    return '$n/sayfa';
  }

  @override
  String get genuiTableEmpty => 'Eşleşen satır yok';

  @override
  String get genuiSortAsc => 'Artan sıralı';

  @override
  String get genuiSortDesc => 'Azalan sıralı';

  @override
  String get genuiSortNone => 'Sıralanmamış';

  @override
  String get genuiValueTrue => 'Doğru';

  @override
  String get genuiValueFalse => 'Yanlış';

  @override
  String get genuiTablePreviousPage => 'Önceki sayfa';

  @override
  String get genuiTableNextPage => 'Sonraki sayfa';

  @override
  String get genuiTableCellsError =>
      'Tablo verisi, sonlu skaler değerler veya eksik değerler içeren kayıtlardan oluşmalıdır.';

  @override
  String get genuiTableColumnsError =>
      'Etiketli bir ila sekiz farklı alan ve isteğe bağlı 0 ile 10 arası basamak seçin.';

  @override
  String get genuiTableRowKeyError =>
      'Her satırın null olmayan bir skaler anahtarı olmalıdır.';

  @override
  String get genuiViewStateFailed =>
      'Bu görünüm değişikliği kayıtlı durum sınırını aşıyor. Bir alanı kısaltın veya arayüzü sıfırlayıp tekrar deneyin.';

  @override
  String get genuiAttachState => 'Mevcut durumu ekle';

  @override
  String get genuiChipExactText => 'Gönderilecek tam metin (sabitlendi)';

  @override
  String get genuiChipStale =>
      'Kaynak kullanılamıyor — kaldırın veya yeniden ekleyin';

  @override
  String get genuiChipRemove => 'Ekli arayüzü kaldır';

  @override
  String get genuiReplaceTitle => 'Ekli arayüz değiştirilsin mi?';

  @override
  String get genuiReplaceBody =>
      'Bir taslak yalnızca tek bir arayüz durumu taşıyabilir.';

  @override
  String get genuiReplaceCurrent => 'Mevcut';

  @override
  String get genuiReplaceNew => 'Şununla değiştir';

  @override
  String get genuiReplaceConfirm => 'Değiştir';

  @override
  String get genuiMergeTitle => 'Taslağınıza eklensin mi?';

  @override
  String get genuiMergeConfirm => 'Ekle';

  @override
  String get genuiContextEmpty => 'Ekli parametre veya sonuç alanı yok.';

  @override
  String get genuiContextOmitted =>
      '[Bazı alanlar veya veri satırları atlandı.]';

  @override
  String get genuiChipOmitted =>
      'Önceden eklenen arayüz durumu kullanılamıyor ve dahil edilmedi.';

  @override
  String get genuiDraftChanged => 'Taslağınız değişti. Lütfen yeniden ekleyin.';

  @override
  String get genuiRepairDraft =>
      'Lütfen bu arayüzü aşağıdaki tanılama bilgileri ve kaynak alıntılarını kullanarak onarın.';

  @override
  String get genuiCopySourceMarkdown => 'Kaynağı / Markdown\'ı kopyala';

  @override
  String get genuiTextFailed => 'Arayüz durumu okunamadı. Tekrar deneyin.';

  @override
  String get genuiCopyLimit =>
      'Metin 64 KiB kopyalama sınırını aşıyor. Daha küçük bir bölüm seçin.';

  @override
  String get genuiExportSnapshot => 'Salt okunur anlık görüntüyü dışa aktar';

  @override
  String get genuiExpandedSharedState => 'Mesajla aynı durumu paylaşır';

  @override
  String get genuiExportTooLarge =>
      'Bu görsel 16 megapikseli aşıyor. Daha az mesaj seçin veya daha küçük bir arayüz dışa aktarın.';

  @override
  String get genuiWebTitle => 'Web önizlemesi';

  @override
  String get genuiWebOpen => 'Aç';

  @override
  String get genuiWebNotReady => 'Oluşturma tamamlandıktan sonra açılabilir';

  @override
  String get genuiWebInvalidMeta => 'Geçersiz başlık; yüklenmedi';

  @override
  String get genuiWebSandboxNote =>
      'Korumalı alan önizlemesi · kapatıldığında atılır';

  @override
  String get genuiWebUnsupported =>
      'Web önizlemeleri bu platformda desteklenmiyor. Tarayıcıda açmak için dışa aktarın.';

  @override
  String get genuiWebExportHtml => 'HTML dışa aktar';

  @override
  String get genuiWebInfo => 'Önizleme bilgileri';

  @override
  String get genuiWebCspNote =>
      'CSP: default-src \'none\' · Kısıtlı ağ erişimi · Yalıtılmış sayfa durumu';

  @override
  String get genuiWebFailed =>
      'Önizleme başlatma veya yükleme başarısız oldu. Kaynağını görüntüleyin veya kopyalayın.';

  @override
  String get genuiWebEmpty => 'Başlıktan sonra HTML belgesi yok';

  @override
  String get genuiWebBlockLimit =>
      'Mesaj başına en fazla 3 web önizlemesi; geri kalanı kaynak olarak gösterilir';

  @override
  String get genuiWebCloseFailed =>
      'Önceki önizlemenin kapandığı doğrulanamadı. Başka bir önizleme açmadan önce uygulamayı yeniden başlatın.';

  @override
  String get displaySettingsShowGenUiHeader =>
      'Etkileşimli arayüz başlık çubuğunu göster';

  @override
  String get displaySettingsShowGenUiHeaderSubtitle =>
      'Daha temiz bir mesaj için gizleyin. Kaynak ve işlemler arayüzün altındaki menüde kalır.';

  @override
  String get genuiClearFilter => 'Filtreyi temizle';

  @override
  String get genuiClearSelection => 'Seçimi temizle';

  @override
  String get chatInputBarQueuedPausedReason =>
      'Sıkıştırma hâlâ sürüyor, bu nedenle otomatik gönderilmeyecek.';

  @override
  String get contextChanged =>
      'Sohbet değişti. Bunu yeniden açın ve devam etmeden önce aralığı onaylayın.';

  @override
  String get contextOperationSuperseded =>
      'Daha sonraki bir özetle değiştirildi';

  @override
  String get compressIncludeAttachments => 'Ek metni ve araç sonuçları';

  @override
  String contextEditCharacters(int count) {
    return '$count karakter';
  }

  @override
  String get compressOverSnack =>
      'Özet hâlâ çok uzun ve sınırı aşacak, bu nedenle kullanılmadı. Tekrar sıkıştırın veya daha büyük bağlamı olan bir modele geçin.';

  @override
  String get contextSummaryHint =>
      'Modelin bir sonraki sefer göreceği özet budur. Kaydetmek yalnızca özeti değiştirir, mevcut yanıtları değiştirmez. Ekler yalnızca zaten çıkarılmış metni katar; görseller yeniden okunmaz.';

  @override
  String get compressAdvanced => 'Gelişmiş';

  @override
  String get compressTaskWaiting => 'Mevcut yanıt bekleniyor';

  @override
  String get contextBudgetExceeded =>
      'Bu özetle bir sonraki mesaj modelin sınırını aşacak. Özeti kısaltın, tekrar sıkıştırın veya daha büyük bağlamı olan bir modele geçin.';

  @override
  String get contextManualSupplement =>
      'Elle düzenlenen özetleri ek olarak dahil et';

  @override
  String get contextDetailEdited => 'Elle düzenlendi';

  @override
  String get contextSourceLabel => 'Özet girdisi';

  @override
  String get contextImpactSourceTitle =>
      'Zaten bir özete dahil edilmiş orijinal metin değiştirilsin mi?';

  @override
  String get chatInputBarQueuedCompressionFailed =>
      'Sıkıştırma başarısız oldu, bu nedenle bu mesaj otomatik gönderilmeyecek.';

  @override
  String contextTokenInfo(int before, int after) {
    return 'Özet girdisi ≈ $before token → özet ≈ $after token';
  }

  @override
  String get worldBookTransferFailed =>
      'Girdiler kaydedilemedi. Lütfen tekrar deneyin.';

  @override
  String contextDetailKeptCount(int count) {
    return 'En son $count kullanıcı mesajı, yanıtları ve araçları';
  }

  @override
  String get toolPermissionRequestApproval => 'Onay iste';

  @override
  String get compressNothingNew =>
      'Son seferden bu yana sıkıştırılacak yeni bir şey yok.';

  @override
  String get browserActionScreenshot => 'Ekran görüntüsü al';

  @override
  String get displaySettingsPageIosNativeSelectionMenuSubtitle =>
      'Giriş ve mesajlar için geçerlidir. Menüler yavaş geliyorsa kapatın.';

  @override
  String contextUndoneSnack(String from, String to) {
    return 'Geri alındı · $from → $to';
  }

  @override
  String get toolApprovalByFullAccess => 'Otomatik çalıştırıldı';

  @override
  String get displaySettingsPageAutoScrollSubtitle =>
      'Akış sırasında en alttayken yeni içeriği takip eder. Yukarı kaydırmak, en alta dönene kadar takibi duraklatır. Kapalıyken yeni içerik otomatik kaydırılmaz.';

  @override
  String get toolApprovalRealTarget => 'Gerçek hedef';

  @override
  String get compressTaskRetry => 'Yeniden dene';

  @override
  String get wsDeniedPathOutside => 'Hedef yetkili alanın dışında. Reddedildi.';

  @override
  String contextImpactSaveConfirm(int count) {
    return 'Kaydet ve sonraki $count ilgili işlemi geri al';
  }

  @override
  String get contextRestore => 'Geri yükle';

  @override
  String compressUsageOriginal(String value) {
    return 'önceki $value';
  }

  @override
  String toolApprovalPendingKind(String kind) {
    return 'Onay bekleniyor · $kind';
  }

  @override
  String get contextTaskApplying => 'Bu özet kullanılıyor';

  @override
  String get storageSpaceImagesHint =>
      'Görselleri silmek sohbet geçmişini ve araç sonuçlarını etkiler. Kullanımdaki avatarlar ve arka planlar korunur.';

  @override
  String get displaySettingsPageIosNativeSelectionMenuTitle =>
      'iOS 26+ yerel seçim menüsü';

  @override
  String get worldBookMoveEntries => 'Şuraya taşı…';

  @override
  String get compressReread => 'Sıkıştırılmış orijinallere geri bak';

  @override
  String get chatInputBarQueuedPausedHold =>
      'Gönderme duraklatıldı. Düzenlemek veya hemen göndermek için kuyruğu iptal edin.';

  @override
  String get contextSummaryTitle => 'Bağlam özeti';

  @override
  String get contextKeepInvalid => 'Pozitif bir kullanıcı mesajı sayısı girin.';

  @override
  String get compressTaskAbandon => 'Vazgeç';

  @override
  String get browserAgentTimedOut =>
      'İşlem zaman aşımına uğradı; AI duraklatıldı';

  @override
  String get compressCancelledSnack => 'İptal edildi. Bağlam değişmedi.';

  @override
  String get contextImpactClearTitle => 'Önceki temizleme geri alınsın mı?';

  @override
  String get compressTaskWaitingApproval => 'Bir aracı onaylamanız bekleniyor';

  @override
  String get contextTaskFailed => 'Sıkıştırma tamamlanmadı';

  @override
  String get wsDeniedSkillsReadonly => 'Beceriler klasörü salt okunur.';

  @override
  String get compressTaskMerging => 'Özetler birleştiriliyor';

  @override
  String get toolPermissionFullAccessDesc =>
      'Bu sohbetin her seferinde sormadan bu cihazdaki dosyalara erişmesine, komut çalıştırmasına ve etkin çevrimiçi araçları kullanmasına izin verir.';

  @override
  String get compressStaleSnack =>
      'Sıkıştırma tamamlanmadan sohbet değişti, bu yüzden bu sonuç kullanılmadı. Hâlâ istiyorsanız tekrar sıkıştırın.';

  @override
  String get worldBookCopyEntries => 'Şuraya kopyala…';

  @override
  String get contextEditEmpty =>
      'Özet boş olamaz. Önceki sohbeti dahil etmemek için Bağlamı temizle\'yi kullanın.';

  @override
  String get toolApprovalDenyWithReason => 'Gerekçeyle reddet…';

  @override
  String get toolApprovalRequestedPath => 'İstenen yol';

  @override
  String get toolApprovalScopeOnce => 'Yalnızca bu çağrı için geçerlidir';

  @override
  String get storageSpaceImageTypeLabel => 'Tür';

  @override
  String get contextImpactUndoTitle => 'Önceki sıkıştırma geri alınsın mı?';

  @override
  String get contextOriginalMessages => 'Orijinal mesajları görüntüle';

  @override
  String storageSpaceDeleteImagesConfirmMessage(int count) {
    return '$count görsel silinsin mi? İlgili sohbet görselleri, araç ekran görüntüleri ve sohbet kopyaları artık kullanılamayacak. Kullanımdaki avatarlar ve arka planlar korunacak.';
  }

  @override
  String get chatInputBarQueuedAfterCompress =>
      'Sıkıştırma tamamlandıktan sonra gönderilir';

  @override
  String get toolPermissionFullAccessDescMobile =>
      'Bu sohbetin her seferinde sormadan korumalı alan ve yetkili klasörler içinde araçları otomatik çalıştırmasına izin verir.';

  @override
  String get compressTaskAdjustRetry => 'Seçenekleri ayarla ve yeniden dene';

  @override
  String get contextDetailLegacy => 'Eski bir temizlemeden devralındı';

  @override
  String get contextDetailCurrent => 'Mevcut bağlam';

  @override
  String get toolPermissionUndo => 'Geri al';

  @override
  String get contextDetailViewOriginals => 'Orijinalleri görüntüle';

  @override
  String get contextTaskCompleted => 'Sıkıştırma tamamlandı';

  @override
  String get chatInputBarQueuedPaused => 'Duraklatıldı';

  @override
  String get contextCompressMarker => 'Bağlam sıkıştırıldı';

  @override
  String contextDetailParts(int count) {
    return 'Otomatik olarak $count parçaya bölündü';
  }

  @override
  String get contextEditPending =>
      'Kaydedildi. Geçerli yanıt bittikten sonra kullanılacak.';

  @override
  String get contextTaskRetry => 'Sıkıştırmayı yeniden dene';

  @override
  String get contextUndoCompressTooltip => 'Bu sıkıştırmayı geri al';

  @override
  String get contextDividerCompressed => 'Bağlam sıkıştırıldı';

  @override
  String compressSuccessSnack(String from, String to) {
    return 'Bağlam sıkıştırıldı · $from → $to';
  }

  @override
  String get contextEffectiveHistory => 'Geçerli özet ve sonraki mesajlar';

  @override
  String get compressRereadAll => 'Bölümdeki tüm orijinaller';

  @override
  String get contextDone => 'Bitti';

  @override
  String get contextMore => 'Daha fazla';

  @override
  String compressFailedSnack(String reason) {
    return 'Sıkıştırma başarısız: $reason';
  }

  @override
  String get branchInheritNote =>
      'Yeni dal yalnızca bu noktadan önce hâlâ geçerli olan özetleri ve orijinalleri taşır.';

  @override
  String get contextTaskInterrupted =>
      'Sıkıştırma kesildi. Yazdıklarınız hâlâ duruyor.';

  @override
  String get storageSpaceImageTypeAll => 'Tümü';

  @override
  String contextRangeInfo(int count, int keep) {
    return '$count mesajın yerini alır; son $keep kullanıcı mesajını ve yanıtlarını korur.';
  }

  @override
  String contextInputModeInfo(String mode, String source) {
    return 'Giriş: $mode · $source';
  }

  @override
  String get contextDetailKept => 'Korunan';

  @override
  String worldBookEntriesCopied(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count giriş kopyalandı',
      one: '1 giriş kopyalandı',
    );
    return '$_temp0';
  }

  @override
  String get toolPermissionSaveFailed => 'Kaydedilemedi. İzin değişmedi.';

  @override
  String get compressDiscardedSnack =>
      'Bağlam temizlendi. Devam eden sıkıştırma iptal edildi ve kullanılmadı.';

  @override
  String get browserActionSelect => 'Seçenek seç';

  @override
  String get toolPermissionTitle => 'İzinler';

  @override
  String get contextDetailNext => 'Sonraki gönderim';

  @override
  String get contextTaskCancel => 'Sıkıştırmayı iptal et';

  @override
  String get toolPermissionFullAccess => 'Tam erişim';

  @override
  String get chatInputBarQueuedCompressionCancelled =>
      'Sıkıştırma iptal edildi, bu yüzden bu mesaj otomatik gönderilmeyecek.';

  @override
  String get toolPermissionResetSnack =>
      'Çalışma alanı değişti · izin, onay isteme olarak sıfırlandı';

  @override
  String get contextImpactUndoOne => 'Geri al';

  @override
  String get contextDetailContinueNewChat => 'Yeni sohbette devam et';

  @override
  String get contextTaskPaused =>
      'Gönderme duraklatıldı. Düzenlemeye devam etmek için kuyruğu iptal edin.';

  @override
  String get contextTaskReview => 'Kullanmadan önce lütfen özeti inceleyin.';

  @override
  String compressApproxTokens(String value) {
    return 'Yaklaşık $value token';
  }

  @override
  String get storageSpaceImageInUseHint =>
      'Silmek için önce ilgili ayarlardan bu avatarı, arka planı veya simgeyi değiştirin ya da kaldırın.';

  @override
  String get compressRereadLastLayer =>
      'Son sıkıştırmadan önceki orijinalleri görüntüle';

  @override
  String get contextRestoreOperation => 'İşlemi geri yükle';

  @override
  String get contextOriginalHistory =>
      'Bu bölümdeki tüm orijinal mesajları yeniden oku';

  @override
  String get contextImpactEditTitle => 'Bu önceki özet kaydedilsin mi?';

  @override
  String get contextOpenNewChat => 'Yeni sohbeti aç';

  @override
  String get wsPathChanged => 'Onay beklenirken hedef değişti.';

  @override
  String get contextEditUnknownPreview =>
      'Kullanım şu anda tahmin edilemiyor. Kaydetmeden önce tekrar kontrol edilecek.';

  @override
  String get contextTaskWait =>
      'Geçerli yanıtın ve araçların bitmesi bekleniyor';

  @override
  String compressTaskElapsed(int i, int n, int seconds) {
    return 'Bölüm $i/$n · $seconds sn geçti';
  }

  @override
  String get wsContextChanged =>
      'Sohbet değişti, bu yüzden bu istek iptal edildi.';

  @override
  String contextChangeImpact(int count) {
    return 'Bu ayrıca sonraki $count ilgili sıkıştırmayı veya temizlemeyi geri alacak. Orijinal sohbet korunur. Devam edilsin mi?';
  }

  @override
  String get contextImpactSave => 'Kaydet';

  @override
  String contextTaskProgress(int done, int total) {
    return '$done/$total bölüm sıkıştırılıyor';
  }

  @override
  String get contextSummaryNotSmaller =>
      'Özet orijinalden daha kısa değil. Kullanmaya karar vermeden önce inceleyin.';

  @override
  String get storageSpaceImageTypeTool => 'Araç görselleri';

  @override
  String get contextPreviousHistory =>
      'Son sıkıştırmadan önceki orijinalleri yeniden görüntüle';

  @override
  String get contextDetailRead => 'Gerçekte okunacak içerik';

  @override
  String get contextViewGenerated => 'Oluşturulan özeti görüntüle';

  @override
  String get contextImpactDeleteDescription =>
      'Bu orijinalleri silmek, ilgili özetleri ve bunlara bağlı sonraki sıkıştırmaları da geri alacak, böylece silinen içerik tekrar gönderilmeyecek. Diğer mesajlar etkilenmez.';

  @override
  String get storageSpaceImageTypeAvatar => 'Avatarlar ve arka planlar';

  @override
  String get contextDetailAfterUndo => 'Geri alma sonrası';

  @override
  String get contextOperationUndo => 'Bu işlemi geri al';

  @override
  String contextHistoryWindowNote(int count) {
    return 'Korunan geçmiş yine de sohbetin $count mesajlık gönderme penceresiyle sınırlıdır.';
  }

  @override
  String get contextOverLimitWarning =>
      'Geri aldıktan sonra içerik modelin sınırını aşabilir. Yine de geri alabilirsiniz — göndermeden önce tekrar kontrol edeceğiz. Gerekirse yeniden sıkıştırın.';

  @override
  String get storageSpaceImageTypeChat => 'Sohbet görselleri';

  @override
  String get worldBookSelectEntries => 'Girdileri seç';

  @override
  String get compressUsageSummary => 'Tahmini özet';

  @override
  String contextDetailRange(String from, String to, int count) {
    return 'Mesajlar $from–$to · $count kullanıcı mesajı';
  }

  @override
  String get contextOperationHidden =>
      'Sonraki bir temizleme zaten etkili oldu, bu artık geçerli değil.';

  @override
  String get contextUndoClearTooltip => 'Bu temizlemeyi geri al';

  @override
  String compressKeepDescription(int count) {
    return 'Son $count kullanıcı mesajını, yanıtları ve araç etkinlikleriyle birlikte tut. Daha önceki geçmiş bir özetle değiştirilir. Yalnızca ek içeren mesajlar birer sayılır.';
  }

  @override
  String get contextOperationUndone => 'Geri alındı';

  @override
  String contextEditPreview(String value) {
    return 'Kaydettikten sonra yaklaşık $value token. Düzenleme, şu anda kullanılan içeriği hemen değiştirmez.';
  }

  @override
  String get contextDetailExcluded => 'Hariç tutulan geçmiş';

  @override
  String get worldBookNoMoveTargets =>
      'Girdileri taşımak için başka bir dünya kitabı oluşturun.';

  @override
  String worldBookSelectedEntries(int count) {
    return '$count seçildi';
  }

  @override
  String get contextDetailReplaced => 'Özetle değiştirilen kısım';

  @override
  String get displaySettingsPageAutoScrollEnabledLabel => 'Açık';

  @override
  String get contextChangeTitle =>
      'Bu değişikliğin neleri etkileyeceğini onaylayın';

  @override
  String get contextDetailTitle => 'Özet';

  @override
  String get compressModelGlobal =>
      'Ayarlar\'daki modeli kullanır ve oturum ortasında değiştirmez.';

  @override
  String get wsDeniedMountReadonly => 'Salt okunur bağlama noktası. Yazılamaz.';

  @override
  String get compressRereadDesc =>
      'Sohbet birden fazla kez sıkıştırıldıysa bu, daha az ayrıntı kaybolsun diye orijinallere geri bakar. Bu sefer daha fazla token kullanır.';

  @override
  String get toolApprovalSwitchToFullAccess => 'Tam erişime geç';

  @override
  String get compressUsageInput => 'Özet girdisi';

  @override
  String get contextDetailSummaryLabel => 'Modelin sonra göreceği özet';

  @override
  String get contextImpactDeleteTitle =>
      'Zaten sıkıştırılmış orijinaller silinsin mi?';

  @override
  String get compressAdvancedOff => 'Orijinallere geri bak: kapalı';

  @override
  String get contextOperationActive => 'Şu anda kullanımda';

  @override
  String get compressAdvancedOn => 'Orijinallere geri bak: açık';

  @override
  String get contextTaskMerging => 'Özetler birleştiriliyor';

  @override
  String contextSampledInfo(int count) {
    return 'Yalnızca seçilen $count karakter okundu; özet, seçilen geçmiş aralığının tamamının yerini alır.';
  }

  @override
  String get contextDividerRunning => 'Bağlam sıkıştırılıyor';

  @override
  String get contextClearDetails =>
      'Bundan sonra önceki sohbet modele gönderilmeyecek. Asistanın sistem talimatları, hafızası ve araçları hâlâ geçerlidir.';

  @override
  String get compressCopyResult => 'Sonucu kopyala';

  @override
  String get contextDetailInUse => 'Şu anda kullanımda';

  @override
  String get contextImpactDescription =>
      'İlgili özetler birlikte geri alınacak. Orijinal sohbet korunur ve model çağrılmaz. Diğer ilgisiz özetler olduğu gibi kalır.';

  @override
  String get compressIncludeAttachmentsDesc =>
      'Önceden çıkarılmış ek metinlerini ve eksiksiz araç kayıtlarını özgün sıralarıyla dahil eder. Görseller yeniden okunmaz.';

  @override
  String worldBookEntriesMoved(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count girdi taşındı',
      one: '1 girdi taşındı',
    );
    return '$_temp0';
  }

  @override
  String get contextImpactSourceDescription =>
      'Bu, orijinal metni değiştirecek ve onu kullanan özetleri, ayrıca bu özetlere bağlı sonraki sıkıştırmaları geri alacak. Diğer mesajlar etkilenmez ve model çağrılmaz.';

  @override
  String get contextEditTitle => 'Özeti düzenle';

  @override
  String get compressUsageNext => 'Uygulandıktan sonra, sonraki gönderim';

  @override
  String get contextSummaryEmpty =>
      'Özet boş olamaz. Önceki sohbeti dahil etmemek için Bağlamı temizle seçeneğini kullanın.';

  @override
  String get toolApprovalDenied => 'Reddedildi';

  @override
  String get contextDetailModel => 'Model · zaman';

  @override
  String compressIncludeManual(int count) {
    return 'Elle eklediğiniz $count içeriği dahil eder';
  }

  @override
  String contextBudgetInfo(int used, String limit) {
    return 'Sonraki gönderim yaklaşık $used / $limit token tutacak, yanıt için yer dahil.';
  }

  @override
  String get contextTaskDismiss => 'Kapat';

  @override
  String contextUndoBudgetInfo(int used) {
    return 'Geri aldıktan sonra: yaklaşık $used token, yanıt için yer dahil';
  }

  @override
  String get storageSpaceImageInUse => 'Kullanımda';

  @override
  String get worldBookSelectionDone => 'Bitti';

  @override
  String get contextDividerFailed => 'Sıkıştırma tamamlanmadı';

  @override
  String get toolPermissionUnboundHint =>
      'Çalışma alanı bağlı değil: bu, dosya veya Shell araçlarını açmaz.';

  @override
  String get contextChangeWaiting =>
      'Bu değişiklik, mevcut yanıt ve araçlar bittikten sonra geçerli olacak.';

  @override
  String storageSpaceDeletedUploadsPartial(int deleted, int kept) {
    return '$deleted öğe silindi; kullanımda olan veya silinemeyen $kept öğe korundu.';
  }

  @override
  String get contextSourceScopeHint =>
      'Yalnızca en son temizlemeden sonraki geçmiş işlenir. Bu, normal gönderim penceresi dışındaki daha eski mesajları içerebilir.';

  @override
  String get contextTaskPreparing => 'Sıkıştırma hazırlanıyor';

  @override
  String contextImpactUsage(String from, String to) {
    return 'Yaklaşık $from → $to token';
  }

  @override
  String contextImpactConfirm(int count) {
    return 'Sonraki $count ilgili işlemi de geri al';
  }

  @override
  String get contextDividerEdited => 'düzenlendi';

  @override
  String get compressAdjust => 'Ayarla';

  @override
  String get compressRegenerate => 'Yeniden sıkıştır';

  @override
  String get toolPermissionEnabledSnack =>
      'Bu sohbet için tam erişim etkinleştirildi';

  @override
  String get contextDetailSuperseded => 'Daha sonraki bir özetle değiştirildi';

  @override
  String get contextTaskQueued => 'Sıraya alındı — sıkıştırma bekleniyor';

  @override
  String get contextNewConversation => 'Özetle yeni sohbet oluştur';

  @override
  String get contextUnknownLimit => 'limit bilinmiyor';

  @override
  String get browserErrActionTimeout =>
      'İşlem zaman aşımına uğradı; sonuç bilinmiyor. AI\'nın devam etmesine izin vermeden önce sayfayı kontrol edin.';

  @override
  String get toolPermissionRequestApprovalDesc =>
      'Kelivo, çalışma alanı dışındaki dosyalara erişmeden, masaüstü komutlarını çalıştırmadan veya onay gerektiren diğer araçları kullanmadan önce soracaktır.';

  @override
  String get contextLimitedInputHint =>
      'Yalnızca seçilen karakter aralığı okunur. Değiştirilen geçmişin geri kalanı özete dahil edilmez; orijinal mesajlar görüntülenebilir kalır.';

  @override
  String get contextTaskCancelled => 'Sıkıştırma iptal edildi';

  @override
  String get contextDetailClearTitle => 'Bağlam temizlendi';

  @override
  String get contextImpactKeep => 'Değişmedi';

  @override
  String get contextImpactUndoAlso => 'Ayrıca geri alınacak';

  @override
  String get contextClearMarker => 'Bağlam temizlendi';

  @override
  String get toolPermissionScopeThisChat => 'Yalnızca bu sohbet';

  @override
  String get dataDirectoryTitle => 'Veri dizini';

  @override
  String get dataDirectoryChange => 'Dizini değiştir';

  @override
  String get dataDirectoryChoose => 'Boş bir yerel klasör seçin';

  @override
  String get dataDirectoryHint =>
      'Yerel sürücüde boş bir klasör seçin. Sohbet geçmişi, ekler ve uygulama tarafından yönetilen dosyalar yeniden başlatmadan sonra taşınır. Küçük cihaz ayarları ve sistem önbellekleri sistem konumlarında kalır.';

  @override
  String get dataDirectoryPendingHint =>
      'Taşıma bir sonraki yeniden başlatmada yapılacak. Kopyalama ve doğrulama tamamlanana kadar mevcut verileriniz yerinde kalır. Hedef:';

  @override
  String get dataDirectoryRestart => 'Yeniden başlat ve verileri taşı';

  @override
  String get dataDirectoryCancelMove =>
      'Taşımayı iptal et ve orijinal dizini kullan';

  @override
  String get dataDirectoryPreviousHint =>
      'Orijinal kopya korundu. Yeni dizin başarıyla başladıktan sonra disk alanı açmak için eski kopyayı kaldırabilirsiniz. Dizini tekrar değiştirmeden önce bu kopyayı temizleyin.';

  @override
  String get dataDirectoryCleanPrevious => 'Orijinal kopyayı temizle';

  @override
  String get dataDirectoryCleanConfirm =>
      'Aşağıdaki dizindeki korunan kopya kaldırılsın mı? Geçerli dizindeki veriler korunur. Taşımadan sonra değişen dosyalar silinmez.';

  @override
  String get dataDirectoryMoving =>
      'Veriler taşınıyor ve doğrulanıyor… Lütfen Kelivo\'yu açık tutun.';

  @override
  String get dataDirectoryStartupFailed => 'Veri dizini açılamıyor';

  @override
  String get dataDirectoryRetry => 'Yeniden dene';

  @override
  String get dataDirectoryUnavailable =>
      'Veri dizini kullanılamıyor. Sürücüyü yeniden bağlayın veya klasörü orijinal konumuna geri yükleyip yeniden deneyin. Boş bir veritabanı oluşturulmaz.';

  @override
  String get dataDirectoryIdentityMismatch =>
      'Bu klasör, yapılandırılmış veri diziniyle eşleşmiyor. Orijinal klasörü geri yükleyip yeniden deneyin.';

  @override
  String get dataDirectoryNotEmpty =>
      'Boş bir klasör seçin. Mevcut dosyaların üzerine yazılmaz.';

  @override
  String get dataDirectoryOverlap =>
      'Mevcut veri dizininin dışında ayrı bir klasör seçin. Üst klasörleri ve sürücü kökü kullanılamaz.';

  @override
  String get dataDirectoryLocalOnly =>
      'Ağ paylaşımı yerine yerel bir sürücü seçin.';

  @override
  String get dataDirectoryFinishPrevious =>
      'Başka bir dizin seçmeden önce bekleyen taşımayı tamamlayın veya iptal edin ve saklanan kopyayı temizleyin.';

  @override
  String get dataDirectoryPendingRestore =>
      'Bekleyen bir yedek geri yükleme var. Dizin taşımayı iptal edip yeniden başlatarak geri yüklemeyi tamamlayın, ardından taşımayı yeniden deneyin.';

  @override
  String get dataDirectorySourceChanged =>
      'Kopya oluşturulduğundan beri orijinal veriler değişti. Orijinal veriler korundu. Yeni bir taşıma başlatmadan önce bekleyen taşımayı iptal edin; saklanan kopyalar elle incelenebilir.';

  @override
  String get dataDirectoryCopyChanged =>
      'Hedef dizin beklenmeyen veya değişmiş dosyalar içeriyor. Orijinal veriler korundu. Yeniden denemeden önce hedef dizini kontrol edin.';

  @override
  String get dataDirectoryGenericError =>
      'İşlem tamamlanamadı. Kullanılabilir disk alanını, klasör izinlerini ve başka bir Kelivo sürecinin çalışıp çalışmadığını kontrol edip yeniden deneyin. Mevcut veriler korundu.';

  @override
  String get dataDirectoryCancelHint =>
      'İptal etmek, hedefe kopyalanmış dosyaları korur. Bu kısmi kopyayı kendiniz inceleyip kaldırabilirsiniz.';

  @override
  String providerDetailPageBaseUrlExample(String url) {
    return 'ör. $url';
  }

  @override
  String get providerDetailPageApiKeyExample => 'ör. sk-…';

  @override
  String get providerDetailPageRequestUrlLabel => 'İstek URL\'si';

  @override
  String providerDetailPageUrlWillAppendVersion(String v) {
    return 'URL\'de sürüm yok; alandan ayrıldığınızda $v eklenecek';
  }

  @override
  String providerDetailPageUrlAppendedVersion(String v) {
    return '$v otomatik olarak eklendi';
  }

  @override
  String get providerDetailPageUrlTrimmedSlash => 'Sondaki / kaldırıldı';

  @override
  String providerDetailPageUrlMovedPath(String path) {
    return 'Tam uç nokta algılandı; $path API Yolu alanına taşındı';
  }

  @override
  String get providerDetailPageUrlEmptyError => 'İstek göndermek için gerekli';

  @override
  String get providerDetailPageUrlInvalidError =>
      'Geçersiz URL; http:// veya https:// ile başlamalı';

  @override
  String get providerDetailPageRestoreDefaultTooltip => 'Varsayılana sıfırla';

  @override
  String get providerDetailPageClearTooltip => 'Temizle';

  @override
  String providerDetailPageTestSuccessWithLatency(String ms) {
    return 'Başarılı · $ms ms';
  }

  @override
  String providerDetailPageTestFailedWithCode(String code) {
    return 'Başarısız · $code';
  }

  @override
  String providerDetailPageTestHintMissingVersion(String url) {
    return 'URL\'de sürüm eksik olabilir; $url deneyin';
  }

  @override
  String providerAutoVersionAdded(String v) {
    return '$v otomatik olarak eklendi';
  }

  @override
  String get providerUndo => 'Geri al';

  @override
  String get sidePanelToggle => 'Yan paneli aç/kapat';

  @override
  String get sidePanelFiles => 'Dosyalar';

  @override
  String get sidePanelTopics => 'Konular';

  @override
  String get sidePanelExpand => 'Paneli genişlet';

  @override
  String get sidePanelCollapse => 'Genişletmeden çık';

  @override
  String get sidePanelAllTabs => 'Tüm sekmeler';

  @override
  String sidePanelMoreTabs(int count) {
    return '$count tane daha';
  }

  @override
  String get sidePanelSearchTabs => 'Sekmelerde ara';

  @override
  String get sidePanelOpenFile => 'Dosya aç…';

  @override
  String get sidePanelCloseOthers => 'Diğer sekmeleri kapat';

  @override
  String get sidePanelCloseRight => 'Sağdaki sekmeleri kapat';

  @override
  String get sidePanelReopenTab => 'Kapatılan sekmeyi yeniden aç';

  @override
  String get sidePanelPinned => 'Sabitlendi · kapatılamaz';

  @override
  String get sidePanelMoveTopicsLeft => 'Konuları sola geri taşı…';

  @override
  String get sidePanelPinnedHint =>
      'Konular sağdayken sabit kalır. Ayarlar › Görünüm › Konu konumu bölümünden değiştirin.';

  @override
  String get sidePanelEvictedTitle => 'Sayfa bellekten çıkarıldı';

  @override
  String sidePanelEvictedBody(int count) {
    return 'Bellek tasarrufu için arka planda bellekten çıkarıldı (en fazla $count arka plan sayfası tutulur). Taramaya devam etmek için yeniden yükleyin.';
  }

  @override
  String get sidePanelEvictedTooltip =>
      'Bellekten çıkarıldı · devam etmek için yeniden yükleyin';

  @override
  String get sidePanelFileMissing => 'Dosya kullanılamıyor';

  @override
  String sidePanelFileMissingBody(String path) {
    return '$path silindi veya taşındı.';
  }

  @override
  String get sidePanelRelocate => 'Yeniden bul';

  @override
  String sidePanelBackgroundIn(String topic) {
    return '“$topic” içinde çalışıyor';
  }

  @override
  String sidePanelWidth(int px) {
    return '${px}px';
  }

  @override
  String get sidePanelWidthMax => 'maks';

  @override
  String get sidePanelWidthMin => 'min';

  @override
  String get sidePanelRecentFiles => 'Son çıktılar ve ekler';

  @override
  String get sidePanelOpenExternalUrl => 'URL\'yi sistem tarayıcısında aç…';

  @override
  String get sidePanelWebPages => 'Web sayfaları';

  @override
  String get hotkeyToggleSidePanel => 'Yan paneli aç/kapat';

  @override
  String get hotkeySidePanelNewWeb => 'Yeni web sekmesi';

  @override
  String get hotkeySidePanelFiles => 'Dosyaları göster';

  @override
  String get hotkeySidePanelExpand => 'Yan paneli genişlet';

  @override
  String get hotkeySidePanelReopenTab => 'Kapatılan sekmeyi yeniden aç';

  @override
  String get hotkeySidePanelNextTab => 'Sonraki panel sekmesi';

  @override
  String get hotkeySidePanelPreviousTab => 'Önceki panel sekmesi';

  @override
  String get hotkeySidePanelAddress => 'Web adresine odaklan';

  @override
  String get hotkeySidePanelFocus => 'Sohbet ve panel odağı arasında geçiş yap';

  @override
  String get selectionQuote => 'Alıntıla';

  @override
  String selectionQuoteMarker(int index) {
    return '[Alıntı $index]';
  }

  @override
  String get selectionTranslate => 'Çevir';

  @override
  String get selectionAiTranslateIos => 'AI Çeviri';

  @override
  String get selectionCopyMarkdown => 'Markdown olarak kopyala';

  @override
  String get selectionCopyRich => 'Zengin metin olarak kopyala';

  @override
  String get quoteJumpToSource => 'Kaynağa git';

  @override
  String get quoteRemove => 'Alıntıyı kaldır';

  @override
  String get quoteDuplicate => 'Zaten alıntılandı';

  @override
  String get quoteLimit => 'Mesaj başına en fazla 10 alıntı';

  @override
  String get quoteLocated => 'Alıntılanan metne gidildi';

  @override
  String get quoteSourceMissing => 'Kaynak artık mevcut değil';

  @override
  String get selectionRegenerate => 'Yeniden oluştur';

  @override
  String get translating => 'Çevriliyor…';

  @override
  String get retry => 'Yeniden dene';

  @override
  String get recoveryGuideTitle => 'Sohbetlerinizi kurtaralım';

  @override
  String get recoveryGuideBody =>
      'Kelivo verilerinizi yüklemeyi duraklattı. Kurtarmak istediklerinizi seçebilmeniz için yerel kopyaları arayacağız. Mevcut dosyalar korunacak.';

  @override
  String get recoverySpaceTitle => 'Biraz boş alana ihtiyaç var';

  @override
  String get recoveryChecksNeedSpace =>
      'Yerel kopyalar bulundu ancak bunları denetlemek için yeterli alan yok. Bu, kopyaların bozuk olduğu anlamına gelmez. Biraz alan boşaltıp yeniden denetleyin.';

  @override
  String get recoveryChecksUnavailable =>
      'Bazı yerel kopyalar henüz denetlenemedi. Dosyaları hâlâ mevcut. Yeniden denetleyin veya yardım için verilerinizi dışa aktarın.';

  @override
  String get recoveryRecheckCopies => 'Yerel kopyaları yeniden denetle';

  @override
  String get recoveryCopyPreview => 'Kopya önizlemesi';

  @override
  String get recoveryRestoreRetryBody =>
      'Geri yükleme tamamlanamadı. Seçilen kopya korundu. Devam etmek için yerel kopyaları yeniden denetleyin veya Kelivo\'yu yeniden açın.';

  @override
  String recoverySpaceAmount(String required, String available) {
    return 'Son denetim: $available kullanılabilir; verilerinizi güvenle hazırlamak için en az $required boş alan gerekir.';
  }

  @override
  String get recoveryCopiesNeedUpdate =>
      'Bazı kopyalar Kelivo\'nun daha yeni bir sürümüyle oluşturulmuş. Bunları geri yüklemeden önce Kelivo\'yu güncelleyin. Bu kopyalar korundu.';

  @override
  String get imageContextAllowRecall =>
      'Modelin görselleri geri çağırmasına izin ver';

  @override
  String get imageContextAllowRecallDescription =>
      'view_image aracının gerektiğinde bu sohbetten geçmiş görselleri almasına izin verir. Bunu kapatmak, mesajlarla doğrudan gönderilen görselleri, otomatik görsel yönetimini veya çalışma alanı dosya erişimini etkilemez.';

  @override
  String get imageContextTitle => 'Görsel bağlamı';

  @override
  String get imageContextAutomatic => 'Geçmiş görsellerini otomatik yönet';

  @override
  String get imageContextDescription =>
      'Bu turda kullanılan görselleri yönetin. Orijinaller sohbetinizde kalır.';

  @override
  String get imageContextIncluded => 'Dahil edildi';

  @override
  String get imageContextOmitted => 'Dahil edilmedi';

  @override
  String get imageContextPin => 'Görseli sabitle';

  @override
  String get imageContextUnpin => 'Görsel sabitlemesini kaldır';

  @override
  String get imageContextAttachAgain => 'Yazma alanına yeniden ekle';

  @override
  String get imageContextEmpty => 'Henüz görsel yok';

  @override
  String get imageContextUnavailable =>
      'Bu görsel mevcut bağlamda kullanılamıyor.';

  @override
  String get imageContextEntryDescription =>
      'Bu turun görsellerini inceleyin ve yönetin';

  @override
  String get imageContextAutomaticDescription =>
      'Eklerinizi daha uzun süre saklayın ve eski araç görsellerini bir kenara ayırın.';

  @override
  String get imageContextActionsHint =>
      'Bir görseli önceliklendirmek için sabitleyin veya yazma alanına yeniden ekleyin.';

  @override
  String get imageContextEmptyDescription =>
      'Gönderdiğiniz görseller veya araçların okuduğu görseller burada görünecek.';

  @override
  String get imageContextUserImages => 'Görselleriniz';

  @override
  String get imageContextToolImages => 'Araç görselleri';

  @override
  String get imageContextAssistantImages => 'Oluşturulan görseller';

  @override
  String imageContextImageNumber(int index) {
    return 'Görsel $index';
  }

  @override
  String imageContextIncludedCount(int included, int total) {
    return '$total görselden $included tanesi dahil';
  }

  @override
  String get imageContextMissing => 'Kullanılamıyor';

  @override
  String get imageContextLoadFailed => 'Görseller yüklenemedi. Tekrar deneyin.';

  @override
  String get imageContextUpdateFailed =>
      'Değişiklikleriniz kaydedilemedi. Tekrar deneyin.';

  @override
  String get contextOperationsTitle => 'Sıkıştırma ve temizleme geçmişi';

  @override
  String get contextOperationsLoadMore => 'Daha fazla göster';

  @override
  String get contextOperationsDescription =>
      'Sıkıştırmaları ve temizlemeleri inceleyin, gerekirse geri alın.';

  @override
  String get contextOperationsEmpty => 'Henüz sıkıştırma veya temizleme yok.';

  @override
  String contextOperationsStored(int count) {
    return 'Kayıtlı sohbet: $count mesaj';
  }

  @override
  String contextOperationsEffective(int summaries, int messages) {
    return 'Sonraki gönderim $summaries özet ve $messages orijinal mesaj içerecek.';
  }

  @override
  String get contextOperationsScope =>
      'Bu, mevcut geçmiş uzunluğu sınırına göre hesaplanır. Sistem talimatları, bellek, araçlar ve gönderilmemiş girdiler de bağlama eklenir. Bir kaydı açarak özetini, orijinal aralığını görüntüleyebilir veya geri alabilirsiniz.';

  @override
  String get contextOperationsLoadFailed =>
      'Bu kayıtlar yüklenemedi. Lütfen tekrar deneyin.';

  @override
  String get compressNewConversation => 'Yeni sohbete sıkıştır';

  @override
  String get compressNewConversationDescription =>
      'Açıkken, özet ve korunan mesajlarla yeni bir sohbet oluşturur ve orijinal sohbeti değiştirmez. Kapalıyken bu sohbette sıkıştırır.';

  @override
  String get contextViewBoundary => 'Bağlamın temizlendiği yere git';

  @override
  String get contextFixedStart => 'Sabit bağlam başlangıcı';

  @override
  String get contextSetFixedStart => 'Bağlamı buradan başlat';

  @override
  String get contextCancelFixedStart => 'Sabit bağlam başlangıcını iptal et';

  @override
  String get contextFixedStartDescription =>
      'Geçmişi bu mesajdan itibaren gönderin, kayan mesaj sayısı sınırı olmadan.';

  @override
  String get contextBeforeFixedStart =>
      'Bu mesaj sabit bağlam başlangıcından önce. Yeniden oluşturmadan önce başlangıcı taşıyın veya iptal edin.';

  @override
  String get contextRegenerateFixedStart =>
      'Bu yanıt sabit bağlam başlangıcı olduğundan sorusu hariç tutulur. Yeniden oluşturmadan önce başlangıcı daha eski bir mesaja taşıyın veya iptal edin.';

  @override
  String get responseSpeedLabel => 'Yanıt hızı';

  @override
  String get responseSpeedStandard => 'Standart';

  @override
  String get responseSpeedUsageHint =>
      'Daha hızlı modlar daha fazla kota veya kredi kullanır.';

  @override
  String get responseSpeedLoading => 'Kullanılabilirlik kontrol ediliyor…';

  @override
  String get responseSpeedUnavailable =>
      'Bu model için kullanılabilir hızlandırma kademesi yok.';

  @override
  String get responseSpeedSaveFailed =>
      'Yanıt hızı kaydedilemedi. Tekrar deneyin.';

  @override
  String responseSpeedRequestFailed(String mode) {
    return '$mode isteği başarısız oldu. Model ve hesap kullanılabilirliğini kontrol edin veya Standart\'a geçip tekrar deneyin.';
  }

  @override
  String get responseSpeedSelectionUnavailable =>
      'Kaydedilen hız artık kullanılamıyor. Bu sohbet Standart kullanacak.';

  @override
  String get responseSpeedProviderDependent =>
      'Kullanılabilirlik sağlayıcınıza bağlıdır.';

  @override
  String responseSpeedTapTo(String mode) {
    return '$mode moduna geçmek için dokunun';
  }

  @override
  String get responseSpeedUltrafastNeedsResponses =>
      'UltraFast, Responses API\'sini gerektirir.';

  @override
  String get compressionTemplate => 'Özet şablonu';

  @override
  String get compressionGeneral => 'Genel';

  @override
  String get compressionCode => 'Kod';

  @override
  String get compressionWriting => 'Yazma';

  @override
  String get compressionResearch => 'Araştırma';

  @override
  String get compressionRoleplay => 'Rol yapma';

  @override
  String get compressionOriginalPrompt => 'Orijinal istemim';

  @override
  String get compressionMore => 'Daha fazla ayar';

  @override
  String get compressionFocus => 'Bu sefer odakta tutulacaklar';

  @override
  String get compressionFocusHint =>
      'İsteğe bağlı: temel kararlar, ilerleme veya karakter ayrıntıları';

  @override
  String get compressionForConversation => 'Bu sohbet için';

  @override
  String get compressionFollowGlobal => 'Genel varsayılanları izle';

  @override
  String get compressionSetGlobal => 'Genel varsayılan olarak ayarla';

  @override
  String get compressionGlobalDescription =>
      'Yalnızca genel varsayılanları izleyen sohbetleri etkiler. Kendi ayarları olan sohbetler değişmez.';

  @override
  String get compressionAutoTitle => 'Otomatik sıkıştırma';

  @override
  String get compressionAutoOff => 'Kapalı';

  @override
  String get compressionAutoNotify => 'Yalnızca bildir';

  @override
  String get compressionAutoOn => 'Otomatik';

  @override
  String get compressionNearLimit =>
      'Bu sohbet, modelin tutabileceği sınıra yaklaşıyor. Göndermeye devam edebilir veya önce sıkıştırabilirsiniz.';

  @override
  String get compressionKeepTurns => 'Son turları koru';

  @override
  String get compressionKeepHint =>
      'Bir tur, bir kullanıcı mesajı ile onu izleyen yanıtlar ve araç etkinliklerinden oluşur.';

  @override
  String get compressionLength => 'Özet uzunluğu (token)';

  @override
  String get compressionTrigger => 'Başlangıç';

  @override
  String get compressionTarget => 'Sıkıştır';

  @override
  String get compressionWindow => 'Özet modeli kapasitesi';

  @override
  String get compressionRequests => 'Maksimum istek';

  @override
  String get compressionReference =>
      'Dünya kitaplarına ve geçmiş belleğe başvur';

  @override
  String get compressionReferenceHint =>
      'Dünya kitapları yalnızca sıkıştırılan geçmişe göre eşleştirilir ve o zamanki bellek anlık görüntüleri kullanılır. Bu yalnızca adları ve kuralları açıklamak içindir — bu olayların yaşandığı veya bir karakterin bunları zaten bildiği anlamına gelmez.';

  @override
  String get compressionToolReferences =>
      'Yalnızca zaten okunmuş araç sonuçlarına referansları tut';

  @override
  String get compressionToolReferencesHint =>
      'Yalnızca araçlar kullanılabilir olduğunda geçerlidir. En son okunmamış sonuçlar tam olarak tutulur. Zaten okunmuş sonuçlar referans olarak tutulur — arayabilirsiniz, ancak düzenleyemezsiniz.';

  @override
  String get compressionSummaryScan =>
      'Dünya kitabı anahtar sözcüklerini özetle de eşleştir';

  @override
  String get compressionChatModel => 'Geçerli sohbet modelini takip et';

  @override
  String get compressionManageTemplates => 'Şablonları ve tarifleri yönet';

  @override
  String get compressionLocalPreview => 'İsteği önizle · model çağrısı yok';

  @override
  String get compressionTry => 'Özet dene · model tokenı kullanır';

  @override
  String get compressionPreviewOnly =>
      'Bu yalnızca bir önizleme oluşturur. İnceledikten sonra kullanın.';

  @override
  String get compressionTemplateChanged =>
      'Yeni şablon yalnızca bundan sonraki özetler için geçerlidir. Mevcut özetler olduğu gibi kalır. Ayrıntıları doldurmak için orijinallerden yeniden oluşturun.';

  @override
  String compressionRange(int count, int turns) {
    return '$count mesajı özetle · $turns kullanıcı turunu olduğu gibi koru';
  }

  @override
  String compressionCalls(int count) {
    return '$count model isteği';
  }

  @override
  String get compressionActualUsage => 'Özet modeli kullanımı';

  @override
  String compressionUsageValues(String input, String output) {
    return 'Girdi $input · çıktı $output token';
  }

  @override
  String compressionUsageUnknown(int count) {
    return '$count istek kullanım verisi döndürmedi. Bu, ücretsiz oldukları anlamına gelmez.';
  }

  @override
  String get compressionBudgetError =>
      'Bu işlem, mevcut sınırın izin verdiğinden daha fazla model isteği gerektirir, bu nedenle bağlam değişmedi. Maksimum istek sayısını artırın veya daha büyük bağlamı olan bir modele geçin.';

  @override
  String get compressionIncomplete =>
      'Özet kesildi veya reddedildi ve bağlam değişmedi. Çıktı sınırını artırın veya farklı bir model deneyin.';

  @override
  String get compressionReferenceTooLarge =>
      'Referans materyali bu modelin kapasitesini zaten dolduruyor ve özet için yer kalmıyor. Daha az referans kullanın veya daha büyük bağlamı olan bir modele geçin.';

  @override
  String get compressionReferenceChanged =>
      'Başvurulan arka plan değişti. Bu özeti gözden geçirin veya yeni bir tane oluşturun.';

  @override
  String get compressionTargetNotReached =>
      'Sıkıştırmadan sonra bile kullanım otomatik başlangıç noktasının üzerinde kalacaktı, bu nedenle orijinal bağlam korundu. Özeti kısaltın veya Başlangıç değerini artırın.';

  @override
  String get compressionTemplateMissing =>
      'Seçilen şablon kullanılamıyor. Lütfen başka bir tane seçin.';

  @override
  String get compressionTemplates => 'Şablonlar';

  @override
  String get compressionRecipes => 'Tarifler';

  @override
  String get compressionNewTemplate => 'Yeni şablon';

  @override
  String get compressionEditTemplate => 'Şablonu düzenle';

  @override
  String get compressionRestoreDefault => 'Varsayılanları geri yükle';

  @override
  String get compressionCopyEdit => 'Kopyala ve düzenle';

  @override
  String get compressionTemplateName => 'Ad';

  @override
  String get compressionPrompt => 'Özet talimatları';

  @override
  String get compressionLanguage => 'Çıktı dili';

  @override
  String get compressionLanguageConversation => 'Sohbeti takip et';

  @override
  String get compressionLanguageLegacy => 'Orijinal şablonun dil ayarını koru';

  @override
  String get compressionLanguageHint =>
      'Bir dil adı veya kodu girin. conversation (sohbeti takip et) veya legacy (orijinal şablonu koru) da kullanabilirsiniz.';

  @override
  String get compressionVariables =>
      'Bu değişkenleri kullanabilirsiniz. İstem geçmişi içermiyorsa otomatik olarak eklenecektir:';

  @override
  String get compressionDeleteTemplate =>
      'Bir yedek seçip bu şablonu silmek istiyor musunuz? Kullanımdaki özetler ve tariflerde kayıtlı kopyalar korunur.';

  @override
  String compressionTemplateReferences(int count) {
    return '$count sohbette sohbet bazlı geçersiz kılma olarak kullanılıyor.';
  }

  @override
  String get compressionSaveRecipe => 'Bu ayarları tarif olarak kaydet';

  @override
  String get compressionBindModel => 'Şu anda seçili özet modelini de kaydet';

  @override
  String get compressionRecipeHint =>
      'Bir tarifi kaydetmek veya içe aktarmak otomatik sıkıştırmayı açmaz ve mevcut sohbete uygulamaz. Yalnızca tarifi kitaplığınıza ekler.';

  @override
  String get compressionImport => 'JSON içe aktar';

  @override
  String get compressionExport => 'JSON dışa aktar';

  @override
  String get compressionCopyJson => 'JSON\'u kopyala';

  @override
  String get compressionApplyRecipe => 'Tarifi uygula';

  @override
  String get compressionInvalidSettings =>
      'Şu değerleri kontrol edin: Sıkıştır hedefi Başlangıç değerinden düşük olmalı ve istek ile token sınırları 0\'dan büyük olmalıdır.';

  @override
  String get compressionOverflowAction =>
      'Bir kez sıkıştır, sonra başarısız olan yanıtı yeniden dene';

  @override
  String compressionPlannedCalls(int count, int limit) {
    return 'Tahmini $count istek · sınır $limit, yeniden denemeler dahil';
  }

  @override
  String get compressionGlobalTemplateReference =>
      'Ayrıca genel varsayılan olarak kullanılır.';

  @override
  String compressionRecipeReferences(int count) {
    return '$count tarif, o zamanki şablonun kendi kopyasını tutar.';
  }

  @override
  String get compressionReplacementTemplate => 'Değiştirme şablonu';

  @override
  String get compressionGeneralDescription =>
      'Mevcut konu, kararlar ve çözülmemiş sorular.';

  @override
  String get compressionCodeDescription =>
      'Kod değişiklikleri, gerçek kontroller ve sonraki mühendislik adımı.';

  @override
  String get compressionWritingDescription =>
      'Kabul edilen metin, yapı, üslup ve düzenleme kısıtları.';

  @override
  String get compressionResearchDescription =>
      'Kanıtlar, kaynaklar, ölçümler ve belirsizlik.';

  @override
  String get compressionRoleplayDescription =>
      'Sahne sürekliliği, karakter durumu ve kimin ne bildiği.';

  @override
  String compressionLastUsed(String date) {
    return 'Son kullanım: $date';
  }

  @override
  String get compressionManage => 'Yönet';

  @override
  String get compressionOutputSettings => 'Özet ayarları';

  @override
  String get compressionSourceSettings => 'Referanslar ve orijinal metin';

  @override
  String get compressionSavedSettings => 'Önizleme ve kayıtlı ayarlar';

  @override
  String get compressionNoRecipes => 'Henüz kayıtlı tarif yok';

  @override
  String get compressionNoTemplatesFound => 'Eşleşen şablon yok';

  @override
  String get compressionBuiltIn => 'Yerleşik';

  @override
  String get compressionGlobalDefault => 'Genel varsayılan';

  @override
  String get compressionCustomLanguage => 'Diğer dil';

  @override
  String get compressionCustomLanguageHint =>
      'Dil adı veya kodu, ör. Japonca / ja';

  @override
  String get compressionLibraryTitle => 'Şablonlar ve tarifler';

  @override
  String get compressionBuiltInTemplates => 'Yerleşik şablonlar';

  @override
  String get compressionMyTemplates => 'Şablonlarım';

  @override
  String get compressionSearchTemplates => 'Şablon ara';

  @override
  String get compressionSearchRecipes => 'Tarif ara';

  @override
  String get compressionRecipeCreateHint =>
      'Bir yapılandırmayı yeniden kullanmak için Diğer ayarlar\'dan tarif kaydedin.';

  @override
  String get compressionTurnUnit => 'tur';

  @override
  String get compressionCallUnit => 'çağrı';

  @override
  String get compressionRequestTimeout => 'Sıkıştırma isteği zaman aşımı';

  @override
  String get compressionMinuteUnit => 'dk';

  @override
  String get compressionRequestTimeoutDefault => 'Varsayılan';

  @override
  String get compressionRequestTimeoutHint =>
      '0\'dan büyük bir dakika sayısı girin. Geçerli varsayılanı korumak için boş bırakın (sunucu tarafı sıkıştırma için 5 dakika). Parçalar halinde özetlerken her parça ve birleştirme ayrı ayrı zamanlanır.';

  @override
  String compressionRequestTimedOut(num minutes) {
    return 'Sıkıştırma $minutes dakika sonra durduruldu ve bağlam değişmedi. Tekrar deneyin veya daha uzun bir zaman aşımına izin verin.';
  }

  @override
  String get compressionAdvancedOptions => 'Sıkıştırma ayrıntıları';

  @override
  String get compressionAdvancedHint =>
      'Referanslar, orijinallere geri bakılıp bakılmayacağı ve istek sınırı';

  @override
  String get compressionAutomaticWindow => 'Otomatik';

  @override
  String get compressionAutoOffHint =>
      'İhtiyaç duyduğunuzda sıkıştırma sayfasından manuel başlatabilirsiniz.';

  @override
  String get compressionAutoNotifyHint =>
      'Kullanım sınıra yaklaştığında bildirim alırsınız ve ne zaman sıkıştıracağınıza siz karar verirsiniz.';

  @override
  String get compressionAutoOnHint =>
      'Kullanım belirlenen yüzdeye ulaştığında önceki geçmiş otomatik olarak özetlenir. Bu, ek model tokenları kullanır.';

  @override
  String get compressionBudgetHint =>
      'Bu yüzdeler, hâlâ kullanılabilir olan giriş kapasitesine göre hesaplanır.';

  @override
  String get compressionPreviewAction => 'Yerel önizleme';

  @override
  String get compressionSaveRecipeAction => 'Tarifi kaydet';

  @override
  String get compressionManualRange => 'Bu sıkıştırmanın kapsamı';

  @override
  String get compressionScopeKeepHint =>
      'En son turları olduğu gibi tutun ve önceki geçmişi özetleyin. Otomatik sıkıştırma da aynı tur sayısını kullanır.';

  @override
  String get compressionScopeAllHint =>
      'Bağlamdaki tüm geçmişi, ayrı bir son orijinal tutmadan özetleyin. Orijinal mesajlar yine de görüntülenebilir.';

  @override
  String get compressionScopeStartHint =>
      'Karakter sınırı dahilinde önceki tam mesajları sıkıştırın. Seçilmeyen mesajlar orijinal metin olarak kalır.';

  @override
  String get compressionScopeRecentHint =>
      'Karakter sınırı dahilinde daha yeni tam mesajları sıkıştırın. Seçilmeyen mesajlar orijinal metin olarak kalır.';

  @override
  String get compressionAutoKeepHint =>
      'Otomatik sıkıştırma, manuel çalıştırma için seçtiğiniz aralıktan bağımsız olarak her zaman son orijinalleri tutar. Tur sayısı manuel sıkıştırmayla paylaşılır.';

  @override
  String get requestBudgetTitle => 'Görsel ve istek bütçeleri';

  @override
  String get requestBudgetInherited => 'Devralındı';

  @override
  String get requestBudgetCustom => 'Özel';

  @override
  String get requestBudgetReset => 'Sıfırla';

  @override
  String get requestBudgetSingleImage => 'Tek görsel (MiB)';

  @override
  String get requestBudgetTotalImages => 'Tüm görseller (MiB)';

  @override
  String get requestBudgetImageCount => 'Görsel sayısı';

  @override
  String get requestBudgetBody => 'İstek gövdesi (MiB)';

  @override
  String get requestBudgetProviderHelp =>
      'Bunlar göndermeden önce yapılan yerel kontrollerdir, sağlayıcı sınırları değildir. Varsayılan değeri kullanmak için alanı boş bırakın. Görsel boyutları Base64 kodlamasını içerir; istek boyutu tam JSON gövdesini içerir.';

  @override
  String get requestBudgetModelHelp =>
      'Bu model için yerel gönderme sınırlarını geçersiz kılın. Boş alanlar gösterilen sağlayıcı ayarlarını devralır. Görsel boyutları Base64 kodlamasını içerir; istek boyutu tam JSON gövdesini içerir.';

  @override
  String get requestBudgetRetentionHelp =>
      'Bu sınırları yükseltmek otomatik geçmiş görsel saklamayı artırmaz. Görselleri korumak için sabitleyin. Daha büyük bütçeler cihaz belleği kullanımını artırabilir.';

  @override
  String get requestBudgetInvalid =>
      'Pozitif boyutlar ve pozitif tam sayı görsel sayısı girin veya devralmak için alanları boş bırakın.';

  @override
  String requestBudgetBytes(String mib, int bytes) {
    return '$mib MiB ($bytes bayt)';
  }

  @override
  String requestBudgetSingleError(int index, String actual, String limit) {
    return 'Kelivo yerel ön kontrolü: $index. görselin kodlanmış boyutu $actual, tek görsel sınırı olan $limit değerini aşıyor.';
  }

  @override
  String requestBudgetTotalError(String actual, String limit) {
    return 'Kelivo yerel ön kontrolü: kodlanmış görseller toplam $actual, görsel bütçesi olan $limit değerini aşıyor.';
  }

  @override
  String requestBudgetCountError(String actual, int limit) {
    return 'Kelivo yerel ön kontrolü: istek $actual görsel içeriyor, $limit sınırını aşıyor.';
  }

  @override
  String requestBudgetBodyError(String actual, String limit) {
    return 'Kelivo yerel ön kontrolü: tam istek gövdesi $actual, istek gövdesi bütçesi olan $limit değerini aşıyor.';
  }

  @override
  String get requestBudgetPinnedError => 'Bu görsel sabitlenmiş.';

  @override
  String get requestBudgetImageHint =>
      'Dahil edilen görselleri ve sabitlemeleri gözden geçirmek için Görsel bağlamını açın. Görsel boyutunu veya sayısını azaltın, eski görsellerin sabitlemesini kaldırın ya da sağlayıcı/model ayarlarında bütçeyi düzenleyin.';

  @override
  String get requestBudgetBodyHint =>
      'Araç sonuçları dahil sohbeti kısaltın veya sıkıştırın ya da sağlayıcı/model ayarlarında istek gövdesi bütçesini düzenleyin.';

  @override
  String imageContextEncodedSize(String size) {
    return 'Kodlanmış $size MiB';
  }

  @override
  String get imageContextPinned => 'Sabitlendi';

  @override
  String get imageContextSizeUnknown =>
      'Boyut gönderim sırasında kontrol edilecek';

  @override
  String requestBudgetAtLeast(String value) {
    return 'en az $value';
  }

  @override
  String get compressionNativeTitle =>
      'OpenAI sunucu tarafı sıkıştırmayı kullan';

  @override
  String get compressionNativeHint =>
      'Mevcut sohbet modelini kullanır ve sıkıştırma sunucuda gerçekleşir. Bu sohbette otomatik sıkıştırma açıksa o da bu yöntemi kullanır. Sağlayıcınızın OpenAI\'nin Responses API\'sini desteklemesi gerekir.';

  @override
  String get compressionNativeScopeHint =>
      'En son turları olduğu gibi tutun ve önceki geçmişi sunucu tarafı sıkıştırmaya gönderin. Otomatik sunucu tarafı sıkıştırma da aynı sayıyı kullanır; metin özeti sayısı değişmez.';

  @override
  String get compressionNativeLabel => 'Sunucu tarafı sıkıştırma';

  @override
  String get compressionNativeDescription =>
      'Sunucunun sıkıştırılmış sonucu yerel olarak kaydedildi ve bir sonraki gönderimde kullanılacak. Metin olarak görüntülenemez veya düzenlenemez. Orijinal mesajlar korunur ve bu sıkıştırmayı geri alabilirsiniz.';

  @override
  String get compressionNativeIncomplete =>
      'Sunucu tam bir sıkıştırılmış sonuç döndürmedi. Orijinal bağlam değişmedi.';

  @override
  String get compressionNativeScopeChanged =>
      'Bu sunucu tarafı sonuç başka bir bağlantıya veya hesaba ait. Devam etmek için orijinal bağlantıya geri dönün veya orijinalleri hâlâ içeren sohbette bu sıkıştırmayı geri alıp bir metin özeti oluşturun.';

  @override
  String get compressionNativeTokenHint =>
      'Sunucu tarafı sıkıştırma için token kullanımı sunucu tarafından bildirilir.';

  @override
  String get compressionNativeCopyHint =>
      'Yeni sohbet yalnızca tam sunucu tarafı sonucu ve tuttuğunuz son turları korur. Orijinaller orijinal sohbette kalır ve burada geri alınarak kurtarılamaz.';

  @override
  String get compressionNativeInputOverride =>
      'Model veya asistan ayarlarındaki özel bir input parametresi sunucu tarafındaki sonucun üzerine yazacak. Devam etmeden önce bu parametreyi kaldırın.';

  @override
  String get compressionNativeAllHint =>
      'Mevcut tüm geçmişi, ayrı bir son orijinal tutmadan sunucu tarafı sıkıştırmaya gönder. Orijinal mesajlar yine de görüntülenebilir.';

  @override
  String get compressionNativeAutoHint =>
      'Kullanım belirlenen yüzdeye ulaştığında, mevcut sohbet modeli sunucu tarafı sıkıştırmayı çalıştırır, ardından gönderme devam eder. Başarısız olursa orijinal bağlam korunur ve metin özetine geri dönülmez.';

  @override
  String get languageDisplayRussian => 'Rusça';

  @override
  String get languageDisplayTurkish => 'Türkçe';

  @override
  String sideDrawerDeleteConfirmContent(String title) {
    return '\"$title\" silinsin mi?';
  }

  @override
  String get backupPageCherryImportWarning =>
      'Bu özellik deneyseldir. Asistanları, sohbetleri, sağlayıcıları ve dosyaları içe aktarır. Bazı sağlayıcılar temel URL\'nin sonunda /v1 veya /v1beta gerektirir. İçe aktarmadan önce verilerinizi yedekleyin. Dosya seçmeye devam edilsin mi?';

  @override
  String get themePaletteDefault => 'Varsayılan';

  @override
  String get themePaletteBlue => 'Eter Mavisi';

  @override
  String get themePaletteGreen => 'Bambu Yeşili';

  @override
  String get themePalettePurple => 'Alacakaranlık Moru';

  @override
  String get themePaletteYellow => 'Kehribar Altını';

  @override
  String get themePaletteSmokyRose => 'Dumanlı Gül';

  @override
  String get themePaletteTerracotta => 'Terrakota Kili';

  @override
  String get themePaletteMonochrome => 'Kırağı Grisi';

  @override
  String get themePaletteDocument => 'Yemyeşil Nane';

  @override
  String get themePaletteCustom => 'Özel';

  @override
  String get compressionNativeImported => 'Sunucu tarafı sıkıştırma yüklendi';

  @override
  String get compressionNativeImportedDescription =>
      'Bu sohbet, sunucu tarafı sıkıştırılmış sonuç ve en son turlarla başlar. Sonuç metin olarak görüntülenemez veya düzenlenemez. Daha önceki orijinaller orijinal sohbette kalır ve burada geri alınarak kurtarılamaz.';

  @override
  String get compressionNativeOpenSource => 'Orijinal sohbeti aç';

  @override
  String get compressionNativeOriginalsUnavailable =>
      'Bu sohbette yüklenen sunucu tarafı sonuca karşılık gelen orijinaller yok. Sunucu tarafı sıkıştırmayı kullanmaya devam edebilir veya orijinalleri görüntülemek ya da metin özeti oluşturmak için orijinal sohbete dönebilirsiniz.';

  @override
  String get compressionNativeTemporaryCopyHint =>
      'Yeni geçici sohbet yalnızca tam sunucu tarafı sonucu ve son turları tutar. Orijinal geçici sohbetten ayrıldığınızda, o sohbet ve taşınmayan orijinaller silinir ve burada kurtarılamaz.';

  @override
  String get compressionNativeSourceUnavailable =>
      'Bu sohbet, tam sunucu tarafı sonucu ve tuttuğunuz son turları içerir. Orijinal sohbet artık kullanılamıyor. Buraya kopyalanmayan orijinaller kurtarılamaz ve sonuç metin olarak görüntülenemez veya düzenlenemez.';

  @override
  String get modelDetailSheetImageGenerationModel => 'Görsel modeli';

  @override
  String get modelDetailSheetImageGenerationAuto => 'Otomatik';

  @override
  String get modelDetailSheetImageGenerationComplexity => 'Görsel karmaşıklığı';

  @override
  String get modelDetailSheetImageGenerationComplexityDefault => 'Varsayılan';

  @override
  String get modelDetailSheetImageGenerationComplexityLow => 'Düşük';

  @override
  String get modelDetailSheetImageGenerationComplexityMedium => 'Orta';

  @override
  String get modelDetailSheetImageGenerationComplexityHigh => 'Yüksek';

  @override
  String get modelDetailSheetImageGenerationComplexityDescription =>
      'Görsel planlamayı sohbet akıl yürütmesinden bağımsız olarak kontrol eder. Varsayılan, sunucu davranışını kullanır ve sohbet akıl yürütmesini devralabilir.';

  @override
  String get modelDetailSheetImageGenerationOAuthHint =>
      'ChatGPT ile oturum açma farklı bir görsel modeli kullanabilir. Model ve karmaşıklık ayarları sunucu desteğine bağlıdır.';

  @override
  String get imageGenerationComplexityErrorHint =>
      'Sohbet akıl yürütmesini Otomatik, görsel karmaşıklığını Varsayılan olarak ayarlayıp görsel oluşturmayı yeniden deneyin. ChatGPT ile oturum açma farklı bir görsel modeli kullanabilir veya açık karmaşıklığı reddedebilir.';

  @override
  String get workspaceEnvNativeShellTitle => 'Varsayılan kabuk';

  @override
  String get workspaceEnvNativeShellHint =>
      'Otomatik algılama için boş bırakın. Aksi takdirde PowerShell, cmd veya -lc destekleyen bir kabuğun (bash, zsh veya fish gibi) mutlak yolunu girin. Bu ayar yalnızca bu cihaz için geçerlidir.';

  @override
  String get workspaceEnvNativeShellInvalid =>
      'Bu kabuk başlatılamadı. Mutlak yolunu ve desteklenen komut sözdizimini kontrol edin.';

  @override
  String get workspaceEnvNativeShellUnavailable => 'Kabuk kullanılamıyor';

  @override
  String get workspaceEnvNativeShellDetect => 'Yeniden algıla';

  @override
  String get workspaceEnvNativeShellSave => 'Kaydet';

  @override
  String get desktopAutostartTitle => 'Başlangıçta başlat';

  @override
  String get desktopAutostartDescription =>
      'Bu bilgisayarda oturum açtığınızda Kelivo\'yu başlat.';

  @override
  String get desktopAutostartHiddenTitle => 'Otomatik başlatmada tepsiye gizle';

  @override
  String get desktopAutostartHiddenDescription =>
      'Başlangıçta başlatma ve tepsi simgesi gerektirir. Kelivo\'yu elle açtığınızda pencere yine görünür.';

  @override
  String get desktopAutostartUnsupported =>
      'Başlangıçta başlatma için macOS 13 veya üstü gerekir.';

  @override
  String get desktopAutostartError =>
      'Başlangıç ayarı uygulanamadı. Sistem başlangıç veya oturum açma öğeleri ayarlarında bu uygulamayı kontrol edip tekrar deneyin.';

  @override
  String get compressionOutputBudget => 'Toplam çıktı sınırı (token)';

  @override
  String get compressionOutputBudgetHint =>
      'Düşünme ve özetin kendisini içerir. Özet uzunluğunu kullanmak için boş bırakın. Düşünme açıksa, özeti uzatmadan bu sınırı yükseltebilirsiniz. Modelin kendi çıktı sınırı yine geçerlidir.';

  @override
  String get responseOutputLimitReached =>
      'Yanıt kesildi: çıktı sınırı akıl yürütmeyi de kapsar. Yeniden denemeden önce çıktı sınırını artırın veya akıl yürütmeyi azaltın.';

  @override
  String responseContextLimitReached(int inputTokens, int contextWindow) {
    return 'Yanıt kesildi: bu istek $inputTokens giriş token\'ı kullandı ve $contextWindow token\'lık bağlam sınırına yaklaştı. Yeniden denemeden önce bağlamı kısaltın.';
  }

  @override
  String get responseRetryWithoutImages =>
      'Görseller olmadan yeniden dene (orijinalleri koru)';
}
