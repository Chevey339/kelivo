// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Korean (`ko`).
class AppLocalizationsKo extends AppLocalizations {
  AppLocalizationsKo([String locale = 'ko']) : super(locale);

  @override
  String get settingsSearchHint => '설정 검색';

  @override
  String get settingsSearchCancel => '취소';

  @override
  String get settingsSearchClear => '검색어 지우기';

  @override
  String get settingsSearchSuggestions => '자주 쓰는 설정';

  @override
  String get settingsSearchNoResults => '설정을 찾을 수 없습니다';

  @override
  String get settingsSearchNoResultsHint => '다른 이름이나 더 짧은 키워드로 검색해 보세요.';

  @override
  String settingsSearchResultCount(int count) {
    return '결과 $count개';
  }

  @override
  String get helloWorld => 'Hello World!';

  @override
  String get settingsPageBackButton => '뒤로';

  @override
  String get settingsPageTitle => '설정';

  @override
  String get settingsPageDarkMode => '다크';

  @override
  String get settingsPageLightMode => '라이트';

  @override
  String get settingsPageSystemMode => '시스템';

  @override
  String get settingsPageWarningMessage =>
      '일부 서비스가 구성되지 않았습니다. 기능이 제한될 수 있습니다.';

  @override
  String get settingsPageGeneralSection => '일반';

  @override
  String get settingsPageColorMode => '색상 모드';

  @override
  String get settingsPageDisplay => '환경설정';

  @override
  String get settingsPageDisplaySubtitle => '모양, 동작 및 상호작용 환경설정';

  @override
  String get settingsPageAssistant => '어시스턴트';

  @override
  String get settingsPageAssistantSubtitle => '기본 어시스턴트 및 스타일';

  @override
  String get settingsPageModelsServicesSection => '모델 및 서비스';

  @override
  String get settingsPageDefaultModel => '기본 모델';

  @override
  String get settingsPageProviders => '제공업체';

  @override
  String get settingsPageHotkeys => '단축키';

  @override
  String get settingsPageSearch => '검색 서비스';

  @override
  String get settingsPageTts => '음성 서비스';

  @override
  String get settingsPageMcp => 'MCP';

  @override
  String get settingsPageQuickPhrase => '빠른 문구';

  @override
  String get settingsPageInstructionInjection => '지침 주입';

  @override
  String get settingsPageDataSection => '데이터';

  @override
  String get settingsPageBackup => '백업';

  @override
  String get settingsPageChatStorage => '저장 공간';

  @override
  String get settingsPageCalculating => '계산 중…';

  @override
  String get storageSpacePageTitle => '저장 공간';

  @override
  String get storageSpaceRefreshTooltip => '새로고침';

  @override
  String get storageSpaceLoadFailed => '저장 공간 사용량을 불러오지 못했습니다';

  @override
  String get storageSpaceTotalLabel => '사용 중인 용량';

  @override
  String storageSpaceClearableLabel(String size) {
    return '지울 수 있는 용량: $size';
  }

  @override
  String storageSpaceClearableHint(String size) {
    return '안전하게 지울 수 있는 용량: $size';
  }

  @override
  String get storageSpaceCategoryImages => '이미지';

  @override
  String get storageSpaceCategoryFiles => '파일';

  @override
  String get storageSpaceCategoryFonts => '글꼴';

  @override
  String get storageSpaceCategoryLocalModels => '로컬 모델';

  @override
  String get storageSpaceOtherHint => '글꼴, 다운로드한 로컬 모델, 기타 앱 파일입니다.';

  @override
  String get storageSpaceSubOtherApp => '앱 파일';

  @override
  String get storageSpaceCategoryChatData => '채팅 기록';

  @override
  String get storageSpaceCategoryLegacyChatData => '채팅 기록(구버전)';

  @override
  String get storageSpaceCategoryRestoreTraces => '복원 잔여 데이터';

  @override
  String get storageSpaceCategoryDisplacedDatabases => '따로 보존한 데이터베이스';

  @override
  String get storageSpaceSubDisplacedDatabases => '자동 재구축 전에 보존됨';

  @override
  String get storageSpaceClearDisplacedDatabasesConfirmMessage =>
      '따로 보존한 데이터베이스를 삭제하시겠습니까? Kelivo가 데이터베이스를 재구축할 때 보존해 둔 것으로, 그 안의 채팅과 설정이 남아 있는 유일한 사본일 수 있습니다. 이 작업은 되돌릴 수 없습니다.';

  @override
  String get storageSpaceRestoreTracesHint =>
      '복원을 완료한 뒤 보존해 둔 이전 데이터 스냅샷입니다. 지워도 현재 앱 데이터에는 영향을 주지 않습니다.';

  @override
  String get storageSpaceClearRestoreTracesButton => '복원 잔여 데이터 지우기';

  @override
  String get storageSpaceClearDisplacedDatabasesButton => '따로 보존한 데이터베이스 삭제';

  @override
  String get storageSpaceClearRestoreTracesConfirmMessage =>
      '완료된 복원 스냅샷을 지우시겠습니까? 현재 데이터베이스, 설정, 파일은 영향을 받지 않습니다.';

  @override
  String get storageSpaceSubCompletedRestoreRuns => '완료된 복원 스냅샷';

  @override
  String get storageSpaceCategoryAssistantData => '어시스턴트';

  @override
  String get storageSpaceCategoryCache => '캐시';

  @override
  String get storageSpaceCategoryLogs => '로그';

  @override
  String get storageSpaceCategoryOther => '기타';

  @override
  String get storageSpaceSafeToClearHint =>
      '안전하게 지울 수 있습니다. 채팅 기록에는 영향을 주지 않습니다.';

  @override
  String get storageSpaceLegacyChatDataHint =>
      'SQLite 마이그레이션 이전부터 남아 있는 Hive 파일입니다. 지워도 현재 채팅 기록은 삭제되지 않습니다.';

  @override
  String get storageSpaceNotSafeToClearHint =>
      '채팅 기록에 영향을 줄 수 있습니다. 주의해서 삭제하세요.';

  @override
  String get storageSpaceBreakdownTitle => '세부 내역';

  @override
  String get storageSpaceSubChatMessages => '메시지';

  @override
  String get storageSpaceSubChatConversations => '대화';

  @override
  String get storageSpaceSubChatToolEvents => '도구 이벤트';

  @override
  String get storageSpaceSubChatDatabase => '채팅 데이터베이스';

  @override
  String get storageSpaceSubChatWriteAheadLog => '미리 쓰기 로그(WAL)';

  @override
  String get storageSpaceSubChatSharedMemory => '공유 메모리 인덱스';

  @override
  String get storageSpaceSubAssistantAvatars => '아바타';

  @override
  String get storageSpaceSubAssistantImages => '이미지';

  @override
  String get storageSpaceSubCacheAvatars => '아바타 캐시';

  @override
  String get storageSpaceSubCacheOther => '기타 캐시';

  @override
  String get storageSpaceSubCacheSystem => '시스템 캐시';

  @override
  String get storageSpaceSubLogsContext => '컨텍스트 로그';

  @override
  String get storageSpaceSubLogsFlutter => 'Flutter 로그';

  @override
  String get storageSpaceSubLogsRequests => '요청 로그';

  @override
  String get storageSpaceSubLogsOther => '기타 로그';

  @override
  String get storageSpaceClearConfirmTitle => '지우기 확인';

  @override
  String storageSpaceClearConfirmMessage(String targetName) {
    return '$targetName을(를) 지우시겠습니까?';
  }

  @override
  String get storageSpaceClearButton => '지우기';

  @override
  String storageSpaceClearDone(String targetName) {
    return '$targetName 지워짐';
  }

  @override
  String storageSpaceClearFailed(String error) {
    return '지우기 실패: $error';
  }

  @override
  String get storageSpaceClearAvatarCacheButton => '아바타 캐시 지우기';

  @override
  String get storageSpaceClearCacheButton => '캐시 지우기';

  @override
  String get storageSpaceClearLogsButton => '로그 지우기';

  @override
  String get storageSpaceClearLegacyChatDataButton => '구버전 채팅 기록 지우기';

  @override
  String get storageSpaceExportLegacyChatFileButton => '내보내기';

  @override
  String storageSpaceExportDone(Object fileName) {
    return '$fileName 내보냄';
  }

  @override
  String storageSpaceExportFailed(Object error) {
    return '내보내기 실패: $error';
  }

  @override
  String get storageSpaceClearLegacyChatDataConfirmMessage =>
      '남아 있는 구버전 채팅 기록 파일을 지우시겠습니까? 현재 SQLite 채팅 기록은 계속 사용할 수 있습니다.';

  @override
  String get storageSpaceViewLogsButton => '로그 보기';

  @override
  String get storageSpaceDeleteConfirmTitle => '삭제 확인';

  @override
  String storageSpaceDeleteUploadsConfirmMessage(int count) {
    return '항목 $count개와 대화에 첨부된 사본을 함께 삭제하시겠습니까? 삭제하면 채팅 기록에서 이 첨부 파일을 더 이상 사용할 수 없습니다.';
  }

  @override
  String storageSpaceDeletedUploadsDone(int count) {
    return '항목 $count개 삭제됨';
  }

  @override
  String get storageSpaceNoUploads => '항목 없음';

  @override
  String get storageSpaceSelectAll => '모두 선택';

  @override
  String get storageSpaceClearSelection => '선택 해제';

  @override
  String storageSpaceSelectedCount(int count) {
    return '$count개 선택됨';
  }

  @override
  String storageSpaceUploadsCount(int count) {
    return '항목 $count개';
  }

  @override
  String get storageSpaceSourceLabel => '출처';

  @override
  String get storageSpaceSourceAll => '전체';

  @override
  String get storageSpaceSourceUserUpload => '사용자 업로드';

  @override
  String get storageSpaceSourceAssistant => '어시스턴트 생성';

  @override
  String get storageSpaceSortLabel => '정렬';

  @override
  String get storageSpaceSortNewest => '최신순';

  @override
  String get storageSpaceSortOldest => '오래된 순';

  @override
  String get storageSpaceSortLargest => '크기 큰 순';

  @override
  String get storageSpaceSortSmallest => '크기 작은 순';

  @override
  String get settingsPageAboutSection => '정보';

  @override
  String get settingsPageAbout => '정보';

  @override
  String get settingsPageStatistics => '통계';

  @override
  String get settingsPageDocs => '문서';

  @override
  String get settingsPageLogs => '로그';

  @override
  String get settingsPageSponsor => '후원';

  @override
  String get settingsPageShare => '공유';

  @override
  String get statsPageTitle => '통계';

  @override
  String get statsPageRangeAllTime => '전체 기간';

  @override
  String get statsPageRangeLast30Days => '최근 30일';

  @override
  String get statsPageRangePreviousMonth => '지난달';

  @override
  String get statsPageRangePreviousQuarter => '지난 분기';

  @override
  String get statsPageRangeCustom => '사용자 지정';

  @override
  String get statsPageHeatmapTitle => '채팅 히트맵';

  @override
  String get statsPageHeatmapLess => '적음';

  @override
  String get statsPageHeatmapMore => '많음';

  @override
  String get statsPageSummaryTitle => '개요';

  @override
  String get statsPageTotalConversations => '총 대화 수';

  @override
  String get statsPageTotalMessages => '총 메시지 수';

  @override
  String get statsPageInputTokens => '입력 토큰';

  @override
  String get statsPageOutputTokens => '출력 토큰';

  @override
  String get statsPageCachedTokens => '캐시된 토큰';

  @override
  String get statsPageLaunchCount => '앱 실행 횟수';

  @override
  String statsPageCost(String currency) {
    return '비용($currency)';
  }

  @override
  String statsPageModelsWithoutPricing(int count) {
    return '가격 정보가 없는 모델 $count개';
  }

  @override
  String get statsPageUsageTrendTitle => '사용량 추이';

  @override
  String get statsPageModelUsageTitle => '모델 사용량';

  @override
  String get statsPageAssistantUsageTitle => '어시스턴트 사용량';

  @override
  String get statsPageTopicVolumeTitle => '대화 분량';

  @override
  String get statsPageModelColumn => '모델';

  @override
  String get statsPageAssistantColumn => '어시스턴트';

  @override
  String get statsPageTopicColumn => '대화';

  @override
  String get statsPageMessagesColumn => '메시지 수';

  @override
  String get statsPageTopicsColumn => '대화 수';

  @override
  String get statsPageEmptyTitle => '아직 통계가 없습니다';

  @override
  String get statsPageShowAllTooltip => '모두 보기';

  @override
  String get statsPageClose => '닫기';

  @override
  String get statsPageUnknownProvider => '알 수 없는 제공업체';

  @override
  String get statsPageUnknownAssistant => '기본 어시스턴트';

  @override
  String get statsPageUnknownModel => '알 수 없는 모델';

  @override
  String get statsPageUnknownTopic => '제목 없는 대화';

  @override
  String get statsPageCustomRangeTitle => '사용자 지정 기간';

  @override
  String get statsPageCustomRangeStart => '시작 날짜';

  @override
  String get statsPageCustomRangeEnd => '종료 날짜';

  @override
  String get statsPageCustomRangeCancel => '취소';

  @override
  String get statsPageCustomRangeApply => '적용';

  @override
  String get sponsorPageMethodsSectionTitle => '후원 방법';

  @override
  String get sponsorPageSponsorsSectionTitle => '후원자';

  @override
  String get sponsorPageEmpty => '아직 후원자가 없습니다';

  @override
  String get sponsorPageAfdianTitle => 'Afdian';

  @override
  String get sponsorPageAfdianSubtitle => 'afdian.com/a/kelivo';

  @override
  String get sponsorPageWeChatTitle => 'WeChat 후원';

  @override
  String get sponsorPageWeChatSubtitle => 'WeChat 후원 코드';

  @override
  String get sponsorPageScanQrHint => 'QR 코드를 스캔해 후원하세요';

  @override
  String get languageDisplaySimplifiedChinese => '简体中文';

  @override
  String get languageDisplayEnglish => 'English';

  @override
  String get languageDisplayTraditionalChinese => '繁體中文';

  @override
  String get languageDisplayJapanese => '日本語';

  @override
  String get languageDisplayKorean => '한국어';

  @override
  String get languageDisplayFrench => 'Français';

  @override
  String get languageDisplayGerman => 'Deutsch';

  @override
  String get languageDisplayItalian => 'Italiano';

  @override
  String get languageDisplaySpanish => 'Español';

  @override
  String get languageSelectSheetTitle => '번역 언어 선택';

  @override
  String get languageSelectSheetClearButton => '번역 지우기';

  @override
  String get homePageClearContext => '컨텍스트 지우기';

  @override
  String contextMessageCount(int count) {
    return '메시지 $count개';
  }

  @override
  String contextMessageCountLimited(int actual, int configured) {
    return '메시지 $actual/$configured개';
  }

  @override
  String get homePageDefaultAssistant => '기본 어시스턴트';

  @override
  String get mermaidExportPng => 'PNG로 내보내기';

  @override
  String get mermaidExportFailed => '내보내기 실패';

  @override
  String get mermaidImageTab => '이미지';

  @override
  String get mermaidCodeTab => '코드';

  @override
  String get mermaidFullScreen => '전체 화면';

  @override
  String get mermaidGeneratingImage => '다이어그램 렌더링 중';

  @override
  String get mermaidGenerationFailedHint =>
      '다이어그램을 렌더링하지 못했습니다. 다른 방식으로 요청해 보세요.';

  @override
  String get mermaidPreviewOpen => '브라우저에서 미리보기';

  @override
  String get mermaidPreviewOpenFailed => '미리보기를 열 수 없습니다';

  @override
  String get assistantProviderDefaultAssistantName => '기본 어시스턴트';

  @override
  String get assistantProviderSampleAssistantName => '예시 어시스턴트';

  @override
  String get assistantProviderNewAssistantName => '새 어시스턴트';

  @override
  String assistantProviderSampleAssistantSystemPrompt(String model_name) {
    return '당신은 도움이 되는 AI 어시스턴트 $model_name입니다. 정확하고 간결하게 답하고, 확실하지 않으면 그렇다고 밝히세요. 도움이 된다면 짧은 문단이나 목록으로 구조를 명확히 하세요. 기본적으로 사용자의 언어로 답하세요.';
  }

  @override
  String get displaySettingsPageLanguageTitle => '앱 언어';

  @override
  String get displaySettingsPageLanguageSubtitle => '인터페이스 언어를 선택합니다';

  @override
  String get assistantTagsManageTitle => '태그 관리';

  @override
  String get assistantTagsCreateButton => '만들기';

  @override
  String get assistantTagsCreateDialogTitle => '태그 만들기';

  @override
  String get assistantTagsCreateDialogOk => '만들기';

  @override
  String get assistantTagsCreateDialogCancel => '취소';

  @override
  String get assistantTagsNameHint => '태그 이름';

  @override
  String get assistantTagsRenameButton => '이름 변경';

  @override
  String get assistantTagsRenameDialogTitle => '태그 이름 변경';

  @override
  String get assistantTagsRenameDialogOk => '이름 변경';

  @override
  String get assistantTagsDeleteButton => '삭제';

  @override
  String get assistantTagsDeleteConfirmTitle => '태그 삭제';

  @override
  String get assistantTagsDeleteConfirmContent => '이 태그를 삭제하시겠습니까?';

  @override
  String get assistantTagsDeleteConfirmOk => '삭제';

  @override
  String get assistantTagsDeleteConfirmCancel => '취소';

  @override
  String get assistantTagsContextMenuEditAssistant => '어시스턴트 편집';

  @override
  String get assistantTagsContextMenuManageTags => '태그 관리';

  @override
  String get mcpTransportOptionStdio => 'STDIO';

  @override
  String get mcpTransportTagStdio => 'STDIO';

  @override
  String get mcpTransportTagInmemory => '내장';

  @override
  String get mcpTransportTagSse => 'SSE';

  @override
  String get mcpTransportTagHttp => 'HTTP';

  @override
  String get mcpServerEditSheetStdioCommandLabel => '명령';

  @override
  String get mcpServerEditSheetStdioArgumentsLabel => '인수';

  @override
  String get mcpServerEditSheetStdioWorkingDirectoryLabel => '작업 디렉터리(선택 사항)';

  @override
  String get mcpWorkspaceBindingLabel => '워크스페이스 지정(선택 사항)';

  @override
  String get mcpWorkspaceBindingHint =>
      '서버는 /workspace에서 이 워크스페이스에 액세스할 수 있습니다. ‘작업 디렉터리’를 비워 두면 이 경로에서 시작합니다. 다른 채팅으로 전환해도 지정된 워크스페이스는 바뀌지 않습니다.';

  @override
  String get mcpWorkspaceBindingMobileOnly =>
      '워크스페이스 지정은 모바일 Linux 환경에서 사용할 수 있습니다. 데스크톱에서 이 서버를 실행하려면 지정을 해제하세요.';

  @override
  String get mcpServerEditSheetStdioEnvironmentTitle => '환경 변수';

  @override
  String get mcpServerEditSheetStdioEnvNameLabel => '이름';

  @override
  String get mcpServerEditSheetStdioEnvValueLabel => '값';

  @override
  String get mcpServerEditSheetStdioAddEnv => '환경 변수 추가';

  @override
  String get mcpServerEditSheetStdioCommandRequired => 'STDIO에는 명령이 필요합니다';

  @override
  String get assistantTagsContextMenuDeleteAssistant => '어시스턴트 삭제';

  @override
  String get assistantTagsClearTag => '태그 지우기';

  @override
  String get displaySettingsPageLanguageChineseLabel => '简体中文';

  @override
  String get displaySettingsPageLanguageEnglishLabel => 'English';

  @override
  String get homePagePleaseSelectModel => '먼저 모델을 선택하세요';

  @override
  String get homePagePleaseSetupTranslateModel => '먼저 번역 모델을 설정하세요';

  @override
  String get homePageTranslating => '번역 중…';

  @override
  String homePageTranslateFailed(String error) {
    return '번역 실패: $error';
  }

  @override
  String get chatServiceDefaultConversationTitle => '새 채팅';

  @override
  String get userProviderDefaultUserName => '사용자';

  @override
  String get homePageDeleteMessage => '이 버전 삭제';

  @override
  String get homePageDeleteMessageConfirm =>
      '이 버전을 삭제하시겠습니까? 이 작업은 되돌릴 수 없습니다.';

  @override
  String get homePageDeleteAllVersions => '모든 버전 삭제';

  @override
  String get homePageDeleteAllVersionsConfirm =>
      '이 메시지의 모든 버전을 삭제하시겠습니까? 이 작업은 되돌릴 수 없습니다.';

  @override
  String get homePageCancel => '취소';

  @override
  String get homePageDelete => '삭제';

  @override
  String get homePageSelectMessagesToShare => '공유할 메시지를 선택하세요';

  @override
  String get homePageDone => '완료';

  @override
  String get homePageDropToUpload => '업로드할 파일을 여기에 놓으세요';

  @override
  String get assistantEditPageTitle => '어시스턴트';

  @override
  String get assistantEditPageNotFound => '어시스턴트를 찾을 수 없습니다';

  @override
  String get assistantEditPageBasicTab => '기본';

  @override
  String get assistantEditPagePromptsTab => '프롬프트';

  @override
  String get assistantEditPageMcpTab => 'MCP';

  @override
  String get assistantEditPageQuickPhraseTab => '빠른 문구';

  @override
  String get assistantEditPageCustomTab => '요청';

  @override
  String get assistantEditPageRegexTab => '정규식 바꾸기';

  @override
  String get assistantEditPageLocalToolsTab => '기기 도구';

  @override
  String get assistantEditTabLayoutTooltip => '탭 맞춤 설정';

  @override
  String get assistantEditTabLayoutTitle => '탭 맞춤 설정';

  @override
  String get assistantEditTabLayoutSubtitle =>
      '탭을 드래그하여 순서를 변경하세요. 필요 없는 탭은 끄세요.';

  @override
  String get assistantEditOutlineModeTitle => '섹션 목록 보기';

  @override
  String get assistantEditOutlineModeSubtitle =>
      '어시스턴트 개요를 먼저 표시한 뒤 목록에서 각 설정 섹션을 엽니다.';

  @override
  String get assistantEditTabLayoutResetTooltip => '탭 레이아웃 재설정';

  @override
  String get assistantEditTabLayoutAtLeastOneVisible => '탭을 하나 이상 표시해야 합니다';

  @override
  String assistantEditTabLayoutDragHandle(String tab) {
    return '$tab 탭을 드래그하여 순서 변경';
  }

  @override
  String get assistantEditRegexDescription =>
      '정규식 규칙을 만들어 사용자/어시스턴트 메시지를 바꾸거나 표시되는 모습만 조정하세요.';

  @override
  String get assistantEditAddRegexButton => '정규식 규칙 추가';

  @override
  String get assistantRegexAddTitle => '정규식 규칙 추가';

  @override
  String get assistantRegexEditTitle => '정규식 규칙 편집';

  @override
  String get assistantRegexNameLabel => '규칙 이름';

  @override
  String get assistantRegexPatternLabel => '정규식';

  @override
  String get assistantRegexReplacementLabel => '바꿀 문자열';

  @override
  String get assistantRegexScopeLabel => '적용 대상';

  @override
  String get assistantRegexScopeUser => '사용자';

  @override
  String get assistantRegexScopeAssistant => '어시스턴트';

  @override
  String get assistantRegexScopeVisualOnly => '표시할 때만';

  @override
  String get assistantRegexScopeReplaceOnly => '전송할 때만';

  @override
  String get assistantRegexAddAction => '추가';

  @override
  String get assistantRegexSaveAction => '저장';

  @override
  String get assistantRegexDeleteButton => '삭제';

  @override
  String get assistantRegexValidationError =>
      '이름과 정규식을 입력하고 적용 대상을 하나 이상 선택하세요.';

  @override
  String get assistantRegexInvalidPattern => '잘못된 정규식';

  @override
  String get assistantRegexCancelButton => '취소';

  @override
  String get assistantRegexUntitled => '이름 없는 규칙';

  @override
  String get assistantEditCustomHeadersTitle => '사용자 지정 헤더';

  @override
  String get assistantEditCustomHeadersAdd => '헤더 추가';

  @override
  String get assistantEditCustomHeadersEmpty => '추가된 헤더 없음';

  @override
  String get assistantEditCustomBodyTitle => '사용자 지정 본문';

  @override
  String get assistantEditCustomBodyAdd => '본문 추가';

  @override
  String get assistantEditCustomBodyEmpty => '추가된 본문 항목 없음';

  @override
  String get assistantEditHeaderNameLabel => '헤더 이름';

  @override
  String get assistantEditHeaderValueLabel => '헤더 값';

  @override
  String get assistantEditBodyKeyLabel => '본문 키';

  @override
  String get assistantEditBodyValueLabel => '본문 값(JSON)';

  @override
  String get assistantEditDeleteTooltip => '삭제';

  @override
  String get assistantEditAssistantNameLabel => '어시스턴트 이름';

  @override
  String get assistantEditUseAssistantAvatarTitle => '어시스턴트 아바타 사용';

  @override
  String get assistantEditUseAssistantAvatarSubtitle =>
      '모델 아바타 대신 어시스턴트 아바타를 사용합니다';

  @override
  String get assistantEditUseAssistantNameTitle => '어시스턴트 이름 사용';

  @override
  String get assistantEditChatModelTitle => '채팅 모델';

  @override
  String get assistantEditChatModelSubtitle =>
      '이 어시스턴트의 기본 채팅 모델을 설정합니다(설정하지 않으면 전역 기본값 사용)';

  @override
  String get assistantEditTemperatureDescription => '무작위성을 조절합니다(범위 0~2)';

  @override
  String get assistantEditTopPDescription => '잘 모르는 경우 이 값을 변경하지 마세요';

  @override
  String get assistantEditParameterDisabled => '비활성화됨(제공업체 기본값 사용)';

  @override
  String get assistantEditParameterDisabled2 => '비활성화됨(제한 없음)';

  @override
  String get assistantEditContextMessagesTitle => '컨텍스트 메시지 수';

  @override
  String get assistantEditContextMessagesDescription => '컨텍스트에 유지할 최근 메시지 수';

  @override
  String get assistantEditStreamOutputTitle => '스트리밍 출력';

  @override
  String get assistantEditStreamOutputDescription => '스트리밍 응답을 활성화합니다';

  @override
  String get assistantEditThinkingBudgetTitle => '추론 수준';

  @override
  String get assistantEditReasoningFollowDefault => '모델 기본값 따르기';

  @override
  String get assistantEditReasoningClampedSubtitle =>
      '실제 수준은 각 모델이 지원하는 범위로 조정됩니다';

  @override
  String get assistantEditConfigureButton => '구성';

  @override
  String get assistantEditMaxTokensTitle => '최대 토큰 수';

  @override
  String get assistantEditMaxTokensDescription => '비워 두면 무제한입니다';

  @override
  String get assistantEditMaxTokensHint => '무제한';

  @override
  String get assistantEditChatBackgroundTitle => '채팅 배경';

  @override
  String get assistantEditChatBackgroundDescription => '이 어시스턴트의 배경 이미지를 설정합니다';

  @override
  String get assistantEditChooseImageButton => '이미지 선택';

  @override
  String get assistantEditClearButton => '지우기';

  @override
  String get desktopNavChatTooltip => '채팅';

  @override
  String get desktopNavTranslateTooltip => '번역';

  @override
  String get desktopNavStorageTooltip => '저장 공간';

  @override
  String get desktopNavGlobalSearchTooltip => '전역 검색';

  @override
  String get desktopNavThemeToggleTooltip => '색상 모드 전환';

  @override
  String get desktopNavSettingsTooltip => '설정';

  @override
  String get desktopAvatarMenuUseEmoji => '이모지 사용';

  @override
  String get cameraPermissionDeniedMessage => '카메라 권한이 허용되지 않았습니다.';

  @override
  String get openSystemSettings => '설정 열기';

  @override
  String get desktopAvatarMenuChangeFromImage => '이미지로 변경…';

  @override
  String get desktopAvatarMenuReset => '아바타 재설정';

  @override
  String get assistantEditAvatarChooseImage => '이미지 선택';

  @override
  String get assistantEditAvatarChooseEmoji => '이모지 선택';

  @override
  String get assistantEditAvatarEnterLink => '링크 입력';

  @override
  String get assistantEditAvatarImportQQ => 'QQ에서 가져오기';

  @override
  String get assistantEditAvatarReset => '재설정';

  @override
  String get displaySettingsPageChatMessageBackgroundTitle => '채팅 메시지 배경';

  @override
  String get displaySettingsPageChatMessageBackgroundDefault => '기본';

  @override
  String get displaySettingsPageChatMessageBackgroundFrosted => '반투명 유리';

  @override
  String get displaySettingsPageChatMessageBackgroundSolid => '단색';

  @override
  String get displaySettingsPageAndroidBackgroundChatTitle =>
      '백그라운드 생성(Android)';

  @override
  String get displaySettingsPageIosBackgroundChatTitle => '백그라운드 생성(iOS)';

  @override
  String get iosBackgroundStatusOn => '켜짐';

  @override
  String get iosBackgroundStatusOff => '꺼짐';

  @override
  String get iosLiveActivityTitle => '실시간 현황';

  @override
  String get iosLiveActivitySubtitle =>
      '지원되는 경우 잠금 화면과 Dynamic Island에 백그라운드 응답 상태를 표시합니다.';

  @override
  String get notificationChatCompletedTitle => '생성 완료';

  @override
  String get notificationChatCompletedBody => '어시스턴트 응답이 생성되었습니다';

  @override
  String get assistantEditEmojiDialogTitle => '이모지 선택';

  @override
  String get assistantEditEmojiDialogHint => '이모지 입력 또는 붙여넣기';

  @override
  String get assistantEditEmojiDialogCancel => '취소';

  @override
  String get assistantEditEmojiDialogSave => '저장';

  @override
  String get assistantEditImageUrlDialogTitle => '이미지 URL 입력';

  @override
  String get assistantEditImageUrlDialogHint =>
      '예: https://example.com/avatar.png';

  @override
  String get assistantEditImageUrlDialogCancel => '취소';

  @override
  String get assistantEditImageUrlDialogSave => '저장';

  @override
  String get assistantEditQQAvatarDialogTitle => 'QQ에서 가져오기';

  @override
  String get assistantEditQQAvatarDialogHint => 'QQ 번호 입력(5~12자리)';

  @override
  String get assistantEditQQAvatarRandomButton => '무작위 선택';

  @override
  String get assistantEditQQAvatarFailedMessage =>
      '무작위 QQ 아바타를 불러오지 못했습니다. 다시 시도하세요.';

  @override
  String get assistantEditQQAvatarDialogCancel => '취소';

  @override
  String get assistantEditQQAvatarDialogSave => '저장';

  @override
  String get assistantEditGalleryErrorMessage =>
      '갤러리를 열 수 없습니다. 이미지 URL을 입력해 보세요.';

  @override
  String get assistantEditGeneralErrorMessage =>
      '문제가 발생했습니다. 이미지 URL을 입력해 보세요.';

  @override
  String get providerDetailPageMultiKeyModeTitle => '다중 키 모드';

  @override
  String get providerDetailPageManageKeysButton => '키 관리';

  @override
  String get multiKeyPageTitle => '다중 키 관리';

  @override
  String get multiKeyPageDetect => '검사';

  @override
  String get multiKeyPageAdd => '추가';

  @override
  String get multiKeyPageAddHint => 'API 키 입력(쉼표나 공백으로 구분)';

  @override
  String multiKeyPageImportedSnackbar(int n) {
    return '키 $n개 가져옴';
  }

  @override
  String get multiKeyPagePleaseAddModel => '먼저 모델을 추가하세요';

  @override
  String get multiKeyPageTotal => '전체';

  @override
  String get multiKeyPageNormal => '정상';

  @override
  String get multiKeyPageError => '오류';

  @override
  String get multiKeyPageAccuracy => '성공률';

  @override
  String get multiKeyPageStrategyTitle => '부하 분산 전략';

  @override
  String get multiKeyPageStrategyRoundRobin => '라운드 로빈';

  @override
  String get multiKeyPageStrategyPriority => '우선순위';

  @override
  String get multiKeyPageStrategyLeastUsed => '최소 사용';

  @override
  String get multiKeyPageStrategyRandom => '무작위';

  @override
  String get multiKeyPageNoKeys => 'API 키 없음';

  @override
  String get multiKeyPageStatusActive => '정상';

  @override
  String get multiKeyPageStatusDisabled => '비활성화됨';

  @override
  String get multiKeyPageStatusError => '오류';

  @override
  String get multiKeyPageStatusRateLimited => '요청 한도 초과';

  @override
  String get multiKeyPageEditAlias => '별칭 편집';

  @override
  String get multiKeyPageEdit => '편집';

  @override
  String get multiKeyPageKey => 'API 키';

  @override
  String get multiKeyPagePriority => '우선순위(1~10)';

  @override
  String get multiKeyPageDuplicateKeyWarning => '이 키가 이미 있습니다';

  @override
  String get multiKeyPageAlias => '별칭';

  @override
  String get multiKeyPageCancel => '취소';

  @override
  String get multiKeyPageSave => '저장';

  @override
  String get multiKeyPageDelete => '삭제';

  @override
  String get assistantEditSystemPromptTitle => '시스템 프롬프트';

  @override
  String get assistantEditSystemPromptHint => '시스템 프롬프트 입력…';

  @override
  String get assistantEditSystemPromptImportButton => '파일에서 가져오기';

  @override
  String get assistantEditSystemPromptImportSuccess => '파일에서 시스템 프롬프트 업데이트됨';

  @override
  String get assistantEditSystemPromptImportFailed => '파일을 가져오지 못했습니다';

  @override
  String get assistantEditSystemPromptImportEmpty => '파일이 비어 있습니다';

  @override
  String get assistantEditAvailableVariables => '사용 가능한 변수:';

  @override
  String get assistantEditVariableDate => '날짜';

  @override
  String get assistantEditVariableTime => '시간';

  @override
  String get assistantEditVariableDatetime => '날짜 및 시간';

  @override
  String get assistantEditVariableModelId => '모델 ID';

  @override
  String get assistantEditVariableModelName => '모델 이름';

  @override
  String get assistantEditVariableLocale => '언어';

  @override
  String get assistantEditVariableTimezone => '시간대';

  @override
  String get assistantEditVariableSystemVersion => '시스템 버전';

  @override
  String get assistantEditVariableDeviceInfo => '기기 정보';

  @override
  String get assistantEditVariableBatteryLevel => '배터리 잔량';

  @override
  String get assistantEditVariableNickname => '사용자 닉네임';

  @override
  String get assistantEditVariableAssistantName => '어시스턴트 이름';

  @override
  String get assistantEditMessageTemplateTitle => '메시지 템플릿';

  @override
  String get assistantEditVariableRole => '역할';

  @override
  String get assistantEditVariableMessage => '메시지';

  @override
  String get assistantEditPreviewTitle => '미리보기';

  @override
  String get assistantEditPromptTimeVarWarning =>
      '시스템 프롬프트에 시간 변수를 사용하면 요청마다 앞부분이 달라져 프롬프트 캐시를 활용할 수 없고, 비용과 첫 토큰까지 걸리는 시간이 모두 늘어납니다. 모델이 현재 시간을 알아야 한다면 아래의 ‘현재 시간 덧붙이기’ 스위치를 사용하세요.';

  @override
  String get assistantEditPromptIso8601Title => 'ISO 8601 형식 사용';

  @override
  String get assistantEditPromptIso8601Subtitle =>
      '시간대 오프셋을 포함합니다(예: 2026-08-08T14:30:05+08:00)';

  @override
  String get assistantEditPromptAppendTimeTitle => '현재 시간 덧붙이기';

  @override
  String get assistantEditPromptAppendTimeSubtitle =>
      '각 사용자 메시지 끝에 보낸 시간을 덧붙입니다. 시간은 요청 끝에 위치하므로 프롬프트 캐싱에 영향을 주지 않습니다.';

  @override
  String get assistantEditPromptAppendTimeInfoTitle => '덧붙이는 시간 형식';

  @override
  String assistantEditPromptAppendTimeInfoBody(String example) {
    return '활성화하면 각 사용자 메시지 끝에 빈 줄을 하나 넣고 다음 태그를 덧붙입니다:\n\n$example\n\n타임스탬프는 각 메시지를 보낸 시간이므로 다시 시도해도 바뀌지 않습니다.';
  }

  @override
  String get assistantEditPromptAppendTimeInfoClose => '확인';

  @override
  String get assistantEditPromptTimeVarDialogTitle => '시스템 프롬프트에 시간 변수가 있습니다';

  @override
  String assistantEditPromptTimeVarDialogBody(String variables) {
    return '시스템 프롬프트에서 $variables 변수를 사용하고 있습니다. 시스템 프롬프트는 요청마다 다시 렌더링되므로, 시간 변수가 있으면 요청마다 앞부분이 달라져 프롬프트 캐시를 활용할 수 없습니다. 이 변수를 제거하고 대신 ‘현재 시간 덧붙이기’를 사용해 보세요. 이 기능은 시간을 요청 끝에 넣으므로 앞부분에는 영향을 주지 않습니다.';
  }

  @override
  String get assistantEditPromptTimeVarDialogRemove => '제거하러 가기';

  @override
  String get assistantEditPromptTimeVarDialogKeep => '그래도 활성화';

  @override
  String get codeBlockPreviewButton => '미리보기';

  @override
  String get codeBlockSaveAsButton => '파일로 저장';

  @override
  String get codeBlockCollapseButton => '접기';

  @override
  String get codeBlockExpandButton => '펼치기';

  @override
  String get codeBlockDefaultFileNameStem => 'code';

  @override
  String get markdownTableLabel => '표';

  @override
  String get markdownTableExportCsvTooltip => 'CSV 내보내기';

  @override
  String get markdownTableSaveImageTooltip => '갤러리에 저장';

  @override
  String get markdownTableDefaultFileNameStem => 'table';

  @override
  String get markdownTableCopiedCsvSnackbar =>
      'CSV가 복사되었습니다. 이미지로 복사하려면 ‘복사’를 길게 누르세요.';

  @override
  String get markdownTableCopiedMarkdownSnackbar => '표가 복사되었습니다.';

  @override
  String codeBlockCollapsedLines(int n) {
    return '… $n줄 접힘';
  }

  @override
  String get htmlPreviewNotSupportedOnLinux => 'Linux에서는 HTML 미리보기를 지원하지 않습니다';

  @override
  String get assistantEditSampleUser => '사용자';

  @override
  String get assistantEditSampleMessage => '안녕';

  @override
  String get assistantEditSampleReply => '안녕하세요, 무엇을 도와드릴까요?';

  @override
  String get assistantEditMcpNoServersMessage => '실행 중인 MCP 서버 없음';

  @override
  String get assistantEditMcpConnectedTag => '연결됨';

  @override
  String assistantEditMcpToolsCountTag(String enabled, String total) {
    return '도구: $enabled/$total';
  }

  @override
  String get assistantEditModelUseGlobalDefault => '전역 기본값 사용';

  @override
  String get assistantSettingsPageTitle => '어시스턴트 설정';

  @override
  String get assistantSettingsCopyButton => '복사';

  @override
  String get assistantSettingsCopySuccess => '어시스턴트 복사됨';

  @override
  String get assistantSettingsCopySuffix => '사본';

  @override
  String get assistantSettingsDeleteButton => '삭제';

  @override
  String get assistantSettingsEditButton => '편집';

  @override
  String get assistantSettingsAddSheetTitle => '어시스턴트 이름';

  @override
  String get assistantSettingsAddSheetHint => '이름 입력';

  @override
  String get assistantSettingsAddSheetCancel => '취소';

  @override
  String get assistantSettingsAddSheetSave => '저장';

  @override
  String get desktopAssistantsListTitle => '어시스턴트 목록';

  @override
  String get desktopSidebarTabAssistants => '어시스턴트';

  @override
  String get desktopSidebarTabTopics => '대화';

  @override
  String get desktopTrayMenuShowWindow => '창 표시';

  @override
  String get desktopTrayMenuExit => '종료';

  @override
  String get hotkeyToggleAppVisibility => '앱 표시/숨기기';

  @override
  String get hotkeyCloseWindow => '창 닫기';

  @override
  String get hotkeyOpenSettings => '설정 열기';

  @override
  String get hotkeyNewTopic => '새 대화';

  @override
  String get hotkeySwitchModel => '모델 전환';

  @override
  String get hotkeyToggleAssistantPanel => '어시스턴트 목록 표시/숨기기';

  @override
  String get hotkeyToggleTopicPanel => '대화 목록 표시/숨기기';

  @override
  String get hotkeysPressShortcut => '단축키를 누르세요';

  @override
  String get hotkeysResetDefault => '기본값으로 재설정';

  @override
  String get hotkeysClearShortcut => '단축키 지우기';

  @override
  String get hotkeysResetAll => '모두 기본값으로 재설정';

  @override
  String get assistantEditTemperatureTitle => '온도';

  @override
  String get assistantEditTopPTitle => 'Top-p';

  @override
  String get assistantSettingsDeleteDialogTitle => '어시스턴트 삭제';

  @override
  String get assistantSettingsDeleteDialogContent =>
      '이 어시스턴트를 삭제하시겠습니까? 이 작업은 되돌릴 수 없습니다.';

  @override
  String get assistantSettingsDeleteDialogCancel => '취소';

  @override
  String get assistantSettingsDeleteDialogConfirm => '삭제';

  @override
  String get assistantSettingsAtLeastOneAssistantRequired =>
      '어시스턴트가 하나 이상 있어야 합니다';

  @override
  String get mcpAssistantSheetTitle => 'MCP 서버';

  @override
  String get mcpAssistantSheetSubtitle => '이 어시스턴트에서 사용할 서버';

  @override
  String get mcpAssistantSheetSelectAll => '모두 선택';

  @override
  String get mcpAssistantSheetClearAll => '선택 해제';

  @override
  String get backupPageTitle => '백업 및 복원';

  @override
  String get backupPageWebDavTab => 'WebDAV';

  @override
  String get backupPageImportExportTab => '가져오기/내보내기';

  @override
  String get backupPageWebDavServerUrl => 'WebDAV 서버 URL';

  @override
  String get backupPageUsername => '사용자 이름';

  @override
  String get backupPagePassword => '비밀번호';

  @override
  String get backupPagePath => '경로';

  @override
  String get backupPageChatsLabel => '채팅';

  @override
  String get backupPageFilesLabel => '파일';

  @override
  String get backupPageScopeTitle => '백업 및 가져오기 항목';

  @override
  String backupPageScopeSelectedCount(int selected, int total) {
    return '$selected/$total';
  }

  @override
  String get backupPageBackupManagementDescription =>
      '백업하고 가져올 항목을 선택하세요. 로컬, WebDAV, S3 백업에 모두 적용됩니다. 가져올 때 선택하지 않은 항목은 변경되지 않습니다. 스킬과 워크스페이스에는 각각의 파일도 포함됩니다.';

  @override
  String get backupPageAssistantsLabel => '어시스턴트';

  @override
  String get backupPageProvidersLabel => '제공업체';

  @override
  String get backupPageMcpLabel => 'MCP 서버';

  @override
  String get backupPageEnvironmentVariablesLabel => '환경 변수';

  @override
  String get backupPageSkillsLabel => '스킬';

  @override
  String get backupPageWorldBooksLabel => '월드북';

  @override
  String get backupPageMemoriesLabel => '메모리';

  @override
  String get backupPageQuickPhrasesLabel => '빠른 문구';

  @override
  String get backupPageInstructionsLabel => '지침 주입';

  @override
  String get backupPageWorkspacesLabel => '워크스페이스';

  @override
  String get backupPageSearchServicesLabel => '검색 서비스';

  @override
  String get backupPageSpeechServicesLabel => '음성 서비스';

  @override
  String get backupPageSettingsLabel => '기타 설정';

  @override
  String get backupPageTestDone => '테스트 완료';

  @override
  String get backupPageTestConnection => '테스트';

  @override
  String get backupPageRestartRequired => '다시 시작 필요';

  @override
  String get backupPageRestartContent =>
      '가져오기에 성공했습니다. 안전하게 적용하려면 Kelivo를 다시 시작하세요.';

  @override
  String backupPageRestartContentWithSkipped(int count) {
    return '가져오기가 완료되었지만, 메시지 순서가 잘못된 대화 $count개를 건너뛰었습니다. 가져온 데이터를 안전하게 적용하려면 Kelivo를 다시 시작하세요.';
  }

  @override
  String get restartAppFailedMessage =>
      'Kelivo를 자동으로 다시 시작하지 못했습니다. 완전히 종료한 다음 다시 여세요.';

  @override
  String get backupRestoreRolledBackTitle => '복원을 되돌렸습니다';

  @override
  String get backupRestoreRolledBackContent =>
      '복원을 완료하지 못했습니다. Kelivo가 이전 데이터를 검증한 뒤 그대로 유지했습니다.';

  @override
  String get backupRestoreFailureTitle => '복원에 조치가 필요합니다';

  @override
  String get backupRestoreFailureContent =>
      'Kelivo가 기존 또는 새 데이터가 온전한지 검증하지 못해 채팅 데이터를 열지 않았습니다. Kelivo를 종료한 후 다시 시도하세요. 문제가 계속되면 지원을 요청할 때 쓸 수 있도록 진단 코드를 보관하세요.';

  @override
  String get backupRestoreBusinessLeaseUnavailableTitle => 'Kelivo가 이미 실행 중입니다';

  @override
  String get backupRestoreBusinessLeaseUnavailableContent =>
      '다른 Kelivo 프로세스가 아직 데이터를 사용하고 있습니다. 다른 Kelivo 창을 모두 닫은 다음 다시 시작하세요. 이 프로세스에서는 아직 채팅 데이터를 열지 않았습니다.';

  @override
  String get restoreProgressTitle => '백업 복원 중';

  @override
  String get restoreProgressWarning =>
      '완료될 때까지 Kelivo를 열어 두세요. 지금 종료하면 다음 실행 시 처음부터 다시 시작합니다.';

  @override
  String get restoreProgressStageCheckingBackup => '백업 확인 중';

  @override
  String get restoreProgressStagePreservingCurrentData => '현재 데이터 보존 중';

  @override
  String get restoreProgressStageInstallingBackup => '백업 적용 중';

  @override
  String get restoreProgressStageVerifying => '검증 중';

  @override
  String get restoreProgressStageRollingBack => '이전 데이터 복원 중';

  @override
  String get restoreProgressStageFinishing => '마무리 중';

  @override
  String get backupRestoreFailureRestartButton => 'Kelivo 다시 시작';

  @override
  String get backupRestoreFailureCopyButton => '진단 코드 복사';

  @override
  String get backupRestoreFailureCopied => '진단 코드 복사됨';

  @override
  String backupRestoreFailureDiagnostic(String code) {
    return '진단 코드: $code';
  }

  @override
  String get startupRecoveryMoreOptions => '추가 복구 옵션';

  @override
  String get startupRecoveryRepairButton => '복구 후 다시 시작';

  @override
  String get startupRecoveryExportButton => '내 데이터 사본 내보내기';

  @override
  String get startupRecoveryResetButton => '데이터 초기화';

  @override
  String get startupRecoveryBusy => '작업 중…';

  @override
  String get startupRecoveryExportSucceeded => '데이터 사본이 저장되었습니다.';

  @override
  String get startupRecoveryExportFailed => '데이터 사본을 내보내지 못했습니다.';

  @override
  String get startupRecoveryRepairFailed =>
      '복구를 완료하지 못했습니다. 데이터는 그대로 보존되어 있습니다. 유효성 검사를 통과한 사본을 선택하거나, 추가 진단을 위해 데이터를 내보내세요.';

  @override
  String get startupRecoveryResetFailed =>
      '초기화에 실패했습니다. Kelivo를 완전히 종료한 다음 다시 여세요.';

  @override
  String get startupRecoveryResetDialogTitle => '모든 데이터를 초기화하시겠습니까?';

  @override
  String get startupRecoveryResetDialogContent =>
      '빈 데이터베이스로 새로 시작하시겠습니까? 현재 데이터베이스와 저널 파일, 기존 사본은 복원에 쓸 수 있도록 보존됩니다.';

  @override
  String get startupRecoveryResetDialogConfirm => '초기화 후 다시 시작';

  @override
  String get startupRecoveryResetDialogCancel => '취소';

  @override
  String get startupRecoveryWhatFailed => '실패 원인';

  @override
  String get startupRecoveryStageLabel => '단계';

  @override
  String get startupRecoveryStageRestore => '복원 처리';

  @override
  String get startupRecoveryStageDatabase => '데이터베이스 시작';

  @override
  String get startupRecoveryDiagnosticLabel => '진단 코드';

  @override
  String get startupRecoverySchemaLabel => '데이터베이스 버전';

  @override
  String startupRecoverySchemaValue(String installed, int expected) {
    return '디스크: $installed · 이 빌드에 필요한 버전: $expected';
  }

  @override
  String get startupRecoveryAppVersionLabel => '앱';

  @override
  String get startupRecoveryUnknownValue => '알 수 없음';

  @override
  String get startupRecoveryCollecting => '진단 정보 수집 중…';

  @override
  String get startupRecoveryShowDetails => '기술 세부 정보 보기';

  @override
  String get startupRecoveryHideDetails => '기술 세부 정보 숨기기';

  @override
  String get startupRecoveryCopyReport => '전체 보고서 복사';

  @override
  String get startupRecoveryReportCopied => '전체 보고서 복사됨';

  @override
  String get startupRecoveryShareReport => '보고서 내보내기';

  @override
  String startupRecoveryReportStored(String path) {
    return '이 보고서의 사본이 $path에 저장되었습니다';
  }

  @override
  String startupRecoveryReportSaved(String path) {
    return '보고서가 $path에 저장되었습니다';
  }

  @override
  String get startupRecoveryReportShared => '보고서를 내보냈습니다.';

  @override
  String get startupRecoveryReportSaveFailed => '보고서를 내보내지 못했습니다.';

  @override
  String get startupRecoverySectionDataTitle => '내 데이터';

  @override
  String get startupRecoverySectionDataBody =>
      '삭제된 데이터는 없습니다. 아래 작업을 시도하기 전에 안전한 곳에 사본을 저장하세요.';

  @override
  String startupRecoveryExportSavedTo(String path) {
    return '데이터 사본이 $path에 저장되었습니다';
  }

  @override
  String get startupRecoverySectionRepairTitle => '진단 및 복구';

  @override
  String get startupRecoverySectionRepairBody =>
      '무결성 검사는 데이터베이스를 읽기만 합니다. 복구는 중단된 업데이트가 남긴 메타데이터를 지우고 앱 시작을 다시 시도하며, 채팅은 삭제하지 않습니다.';

  @override
  String get startupRecoveryIntegrityButton => '데이터베이스 무결성 검사';

  @override
  String get startupRecoveryIntegrityHealthy =>
      'SQLite 검사에서 데이터베이스 파일의 손상이 발견되지 않았습니다.';

  @override
  String startupRecoveryIntegrityDamaged(String detail) {
    return 'SQLite에서 문제를 발견했습니다: $detail';
  }

  @override
  String get startupRecoveryIntegrityMissing =>
      '데이터 폴더에서 데이터베이스 파일을 찾을 수 없습니다.';

  @override
  String get startupRecoveryIntegrityFailed => '무결성 검사를 실행하지 못했습니다.';

  @override
  String get startupRecoveryDangerZone => '위험 영역';

  @override
  String get startupRecoveryDangerBody =>
      '새로 시작하면 현재 데이터가 더 이상 표시되지 않습니다. Kelivo는 복원에 쓸 수 있도록 이전 데이터베이스와 기존 사본을 보존합니다. 가능하면 먼저 데이터 사본을 내보내세요.';

  @override
  String get startupRecoveryResetAcknowledge => '빈 데이터베이스로 새로 시작하겠습니다.';

  @override
  String get startupDatabaseUpdateRequiredTitle => '계속하려면 Kelivo를 업데이트하세요';

  @override
  String get startupDatabaseUpdateRequiredContent =>
      '이 기기의 채팅 데이터베이스는 더 높은 버전의 Kelivo에서 만들어져 현재 버전에서는 열 수 없습니다. 데이터는 변경되지 않았습니다. 최신 버전의 Kelivo를 설치한 다음 다시 여세요.';

  @override
  String get startupDatabaseUpdateRequiredDowngradeTitle => '이전 버전이 필요한 경우';

  @override
  String get startupDatabaseUpdateRequiredDowngradeIntro =>
      '현재 버전에서는 이 기기의 데이터베이스를 열 수 없습니다. 이전 버전을 계속 사용해야 한다면 아래 단계를 따르세요. 백업을 마치기 전에는 이 기기의 데이터를 삭제하거나 덮어쓰지 마세요.';

  @override
  String get startupDatabaseUpdateRequiredDowngradeStep1 =>
      '최신 버전의 Kelivo를 설치하고 연 다음, ‘설정 → 백업’에서 백업을 내보내세요.';

  @override
  String startupDatabaseUpdateRequiredDowngradeStep2(String url) {
    return '$url에 접속해 그 백업을 사용하려는 이전 버전에 맞게 변환하세요.';
  }

  @override
  String get startupDatabaseUpdateRequiredDowngradeStep3 =>
      '이 기기의 데이터가 백업되었는지 확인한 다음, 이전 버전을 설치하고 변환한 백업을 가져오세요.';

  @override
  String get startupDatabaseUpdateRequiredOpenTool => '변환 도구 열기';

  @override
  String backupPageRestoreFailedMessage(String error) {
    return '복원 실패: $error';
  }

  @override
  String backupPageExportFailedMessage(String error) {
    return '내보내기 실패: $error';
  }

  @override
  String get backupPageOK => '확인';

  @override
  String get backupPageCancel => '취소';

  @override
  String get backupPageSelectImportMode => '가져오기 모드 선택';

  @override
  String get backupPageSelectImportModeDescription =>
      '가져오기 모드를 선택하세요. ‘백업 관리’의 스위치 설정이 이번 가져오기에도 적용됩니다.';

  @override
  String get backupPageOverwriteMode => '덮어쓰기';

  @override
  String get backupPageOverwriteModeDescription =>
      '선택한 항목은 교체하고, 선택하지 않은 항목과 기타 로컬 설정은 유지합니다. 채팅을 교체하면 이 기기에서 보내지 않은 초안도 지워집니다.';

  @override
  String get backupPageMergeMode => '병합';

  @override
  String get backupPageMergeModeDescription =>
      '로컬 데이터를 유지하고 백업 데이터를 추가합니다. 동일한 대화는 건너뛰고, 충돌하는 대화에는 새 ID를 부여합니다.';

  @override
  String get backupPageRestore => '복원';

  @override
  String get backupPageForwardCompatTitle => '더 높은 버전의 Kelivo에서 만든 백업입니다';

  @override
  String backupPageForwardCompatBody(int backupVersion, int currentVersion) {
    return '이 백업은 더 높은 버전의 Kelivo에서 만들어졌으며(데이터 형식 $backupVersion, 현재 버전의 지원 형식 $currentVersion), 이전 버전에서 읽을 수 있는지는 명시되어 있지 않습니다.\n\n계속 진행할 수도 있습니다. 이 경우 현재 버전에서 인식하지 못하는 내용은 건너뛰며, 백업 파일 자체는 수정되지 않습니다. 다만 더 높은 버전에서 기존 데이터의 저장 방식이 바뀌었다면 일부 내용을 잘못 가져올 수 있습니다.\n\n먼저 Kelivo를 업데이트하는 편이 더 안전합니다.';
  }

  @override
  String get backupPageForwardCompatContinue => '그래도 가져오기';

  @override
  String get backupPageForwardCompatCancel => '취소';

  @override
  String get backupPageSchemaTooNewMessage =>
      '이 백업은 더 높은 버전의 Kelivo에서 만들어져 현재 버전에서는 읽을 수 없습니다. Kelivo를 업데이트한 후 다시 시도하세요.';

  @override
  String get backupPageBackupUploaded => '백업 업로드됨';

  @override
  String get backupPageBackup => '지금 백업';

  @override
  String get backupPageExporting => '내보내는 중…';

  @override
  String get backupProgressCancel => '취소';

  @override
  String get backupProgressCancelled => '취소됨';

  @override
  String get backupProgressFailed => '작업 실패';

  @override
  String backupProgressFailedAt(String phase) {
    return '실패 단계: $phase';
  }

  @override
  String get backupProgressCopyError => '오류 복사';

  @override
  String get backupProgressErrorCopied => '오류 복사됨';

  @override
  String get backupProgressPreparing => '준비 중';

  @override
  String get backupProgressSnapshotting => '데이터베이스 스냅샷 만드는 중';

  @override
  String get backupProgressPacking => '압축 중';

  @override
  String get backupProgressVerifying => '검증 중';

  @override
  String get backupProgressUploading => '업로드 중';

  @override
  String get backupProgressDownloading => '다운로드 중';

  @override
  String get backupProgressExtracting => '압축 해제 중';

  @override
  String get backupProgressValidating => '유효성 검사 중';

  @override
  String get backupProgressReadingSettings => '설정 읽는 중';

  @override
  String get backupProgressStaging => '반영 준비 중';

  @override
  String get backupProgressCommitting => '반영 중';

  @override
  String get backupProgressImportingSessions => '대화 가져오는 중';

  @override
  String get backupProgressImportingMessages => '메시지 가져오는 중';

  @override
  String get backupProgressMaterializingFiles => '파일 쓰는 중';

  @override
  String get backupProgressListingRemote => '원격 백업 목록 불러오는 중';

  @override
  String get backupProgressFinalizing => '마무리 중';

  @override
  String backupProgressBytes(String done, String total) {
    return '$done / $total';
  }

  @override
  String backupProgressItems(String done, String total) {
    return '$done / $total';
  }

  @override
  String get backupPageExportToFile => '파일로 내보내기';

  @override
  String get backupPageExportToFileSubtitle => '앱 데이터를 파일로 내보냅니다';

  @override
  String get backupPageImportBackupFile => '백업 파일 가져오기';

  @override
  String get backupPageImportBackupFileSubtitle => '로컬 백업 파일을 가져옵니다';

  @override
  String get backupPageImportFromOtherApps => '다른 앱에서 가져오기';

  @override
  String get backupPageNotSupportedYet => '아직 지원되지 않음';

  @override
  String get backupPageRemoteBackups => '원격 백업';

  @override
  String get backupPageNoBackups => '백업 없음';

  @override
  String get backupPageRestoreTooltip => '복원';

  @override
  String get backupPageDeleteTooltip => '삭제';

  @override
  String get backupPageDeleteConfirmTitle => '삭제 확인';

  @override
  String backupPageDeleteConfirmContent(Object name) {
    return '원격 백업 “$name”을(를) 삭제하시겠습니까? 이 작업은 되돌릴 수 없습니다.';
  }

  @override
  String get backupPageBackupManagement => '백업 관리';

  @override
  String get backupPageWebDavBackup => 'WebDAV 백업';

  @override
  String get backupPageWebDavServerSettings => 'WebDAV 서버 설정';

  @override
  String get backupPageS3Backup => 'S3 백업';

  @override
  String get backupPageS3ServerSettings => 'S3 설정';

  @override
  String get backupPageS3Endpoint => '엔드포인트';

  @override
  String get backupPageS3Region => '리전';

  @override
  String get backupPageS3Bucket => '버킷';

  @override
  String get backupPageS3AccessKeyId => '액세스 키 ID';

  @override
  String get backupPageS3SecretAccessKey => '보안 액세스 키';

  @override
  String get backupPageS3SessionToken => '세션 토큰(선택 사항)';

  @override
  String get backupPageS3Prefix => '접두사';

  @override
  String get backupPageS3PathStyle => '경로 스타일 주소 지정';

  @override
  String get backupPageUserAgent => 'User-Agent';

  @override
  String get backupPageUserAgentHint => '선택 사항';

  @override
  String get backupPageSave => '저장';

  @override
  String get backupPageBackupNow => '지금 백업';

  @override
  String get backupPageLocalBackup => '로컬 백업';

  @override
  String get backupPageImportFromCherryStudio => 'Cherry Studio에서 가져오기';

  @override
  String backupPageCherryStudioUnsupportedBackupVersion(String version) {
    return '이 백업은 Kelivo에서 아직 가져올 수 없는 Cherry Studio 형식(버전 $version)을 사용합니다. 대신 Cherry Studio v1에서 내보내거나, Cherry Studio v2 백업을 지원하는 Kelivo 업데이트를 기다리세요.';
  }

  @override
  String get backupPageImportFromChatbox => 'Chatbox에서 가져오기';

  @override
  String get backupReminderSectionTitle => '백업 리마인더';

  @override
  String get backupReminderEnableTitle => '백업 리마인더 받기';

  @override
  String get backupReminderFrequencyTitle => '리마인더 주기';

  @override
  String get backupReminderTimeTitle => '리마인더 시간';

  @override
  String get backupReminderTimeInputHint => 'HH:mm';

  @override
  String get backupReminderTimeInvalid => '00:00~23:59 사이의 시간을 입력하세요.';

  @override
  String get backupReminderLastBackupTitle => '마지막 백업';

  @override
  String get backupReminderNextReminderTitle => '다음 리마인더';

  @override
  String get backupReminderNever => '없음';

  @override
  String get backupReminderDisabled => '꺼짐';

  @override
  String get backupReminderDueNow => '지금';

  @override
  String get backupReminderEveryDay => '매일';

  @override
  String get backupReminderEveryThreeDays => '3일마다';

  @override
  String get backupReminderEveryWeek => '매주';

  @override
  String get backupReminderEveryFourteenDays => '14일마다';

  @override
  String get backupReminderEveryMonth => '매월';

  @override
  String backupReminderCustomDays(int days) {
    return '$days일마다';
  }

  @override
  String get backupReminderCustomOption => '사용자 지정…';

  @override
  String get backupReminderCustomDialogTitle => '사용자 지정 주기';

  @override
  String get backupReminderCustomDialogDescription =>
      '백업 리마인더 사이의 간격을 일 단위로 입력하세요.';

  @override
  String get backupReminderCustomDaysLabel => '일수';

  @override
  String get backupReminderCustomDaysInvalid => '1~365 사이의 숫자를 입력하세요.';

  @override
  String get backupReminderSidebarTitle => '백업 리마인더';

  @override
  String get backupReminderSidebarSubtitle => '설정한 백업 주기가 되었습니다.';

  @override
  String get backupReminderSidebarAction => '백업으로 이동';

  @override
  String get backupReminderSnoozeTooltip => '나중에 알림';

  @override
  String get chatHistoryPageTitle => '채팅 기록';

  @override
  String get chatHistoryPageSearchTooltip => '검색';

  @override
  String get chatHistoryPageDeleteAllTooltip => '고정하지 않은 대화 삭제';

  @override
  String get chatHistoryPageDeleteAllDialogTitle => '고정하지 않은 대화 삭제';

  @override
  String get chatHistoryPageDeleteAllDialogContent =>
      '이 어시스턴트의 고정하지 않은 대화를 모두 삭제하시겠습니까? 고정된 대화는 그대로 유지됩니다.';

  @override
  String get chatHistoryPageCancel => '취소';

  @override
  String get chatHistoryPageDelete => '삭제';

  @override
  String get chatHistoryPageDeletedAllSnackbar => '고정하지 않은 대화 삭제됨';

  @override
  String get chatHistoryPageSearchHint => '대화 검색';

  @override
  String get chatHistoryPageNoConversations => '대화 없음';

  @override
  String get chatHistoryPagePinnedSection => '고정됨';

  @override
  String get chatHistoryPagePin => '고정';

  @override
  String get chatHistoryPagePinned => '고정됨';

  @override
  String get messageEditPageTitle => '메시지 편집';

  @override
  String get messageEditPageSave => '저장';

  @override
  String get messageEditPageSaveAndSend => '저장 후 보내기';

  @override
  String get messageEditPageHint => '메시지 입력…';

  @override
  String get userMessageEditSaveOnly => '저장만';

  @override
  String get userMessageEditUnsupportedSnackbar => '이 내용은 편집할 수 없습니다';

  @override
  String get userMessageEditOverwriteTitle => '안내';

  @override
  String get userMessageEditOverwriteContent =>
      '편집하면 입력창의 기존 내용을 덮어씁니다. 덮어쓰시겠습니까?';

  @override
  String get selectCopyPageTitle => '텍스트 선택';

  @override
  String get selectCopyPageCopyAll => '모두 복사';

  @override
  String get selectCopyPageCopiedAll => '모두 복사됨';

  @override
  String get bottomToolsSheetCamera => '카메라';

  @override
  String get bottomToolsSheetPhotos => '사진';

  @override
  String get bottomToolsSheetUpload => '파일 업로드';

  @override
  String get bottomToolsSheetClearContext => '컨텍스트 지우기';

  @override
  String get compressContext => '컨텍스트 압축';

  @override
  String get compressContextDesc => '요약한 후 새 채팅을 시작합니다';

  @override
  String get clearContextDesc => '컨텍스트 경계를 표시합니다';

  @override
  String get contextManagement => '컨텍스트 관리';

  @override
  String get compressingContext => '컨텍스트 압축 중…';

  @override
  String get compressContextFailed => '컨텍스트를 압축하지 못했습니다';

  @override
  String get compressContextNoMessages => '압축할 메시지가 없습니다';

  @override
  String get compressContextNoConversation => '압축할 대화가 없습니다';

  @override
  String get compressContextNoModel => '압축 모델이 구성되지 않았습니다';

  @override
  String get compressContextEmptySummary => '압축 결과 요약이 비어 있습니다';

  @override
  String get compressContextOptionsTitle => '컨텍스트 압축';

  @override
  String get compressContextOptionsDesc => '압축 모델에 보낼 현재 채팅의 범위를 선택하세요.';

  @override
  String get compressContextKeepStart => '앞부분';

  @override
  String get compressContextKeepRecent => '뒷부분';

  @override
  String get compressContextUnlimited => '무제한';

  @override
  String get compressContextMaxCharsLabel => '글자 수';

  @override
  String get compressContextInvalidLimit => '0보다 큰 숫자를 입력하세요';

  @override
  String get compressContextStartButton => '압축';

  @override
  String get compressContextModelLabel => '압축 모델';

  @override
  String get compressContextModelUnset => '모델 선택';

  @override
  String get compressContextKeepRecentMessages => 'N개 유지';

  @override
  String get compressContextKeepCountLabel => '유지할 최근 턴 수';

  @override
  String get compressContextKeepAllMessages =>
      '이 개수만큼 유지하면 모든 메시지가 포함되어 압축할 내용이 없습니다';

  @override
  String compressContextEstimatePreview(
    int summarized,
    int kept,
    int minTokens,
    int maxTokens,
    int totalTokens,
  ) {
    return '$summarized자 요약, $kept자는 원문 유지 → 약 $minTokens~$maxTokens 토큰(원래 약 $totalTokens 토큰)';
  }

  @override
  String get bottomToolsSheetLearningMode => '학습 모드';

  @override
  String get bottomToolsSheetLearningModeDescription => '단계별 학습을 돕습니다';

  @override
  String get bottomToolsSheetConfigurePrompt => '프롬프트 구성';

  @override
  String get bottomToolsSheetPrompt => '프롬프트';

  @override
  String get bottomToolsSheetPromptHint => '주입할 프롬프트 입력';

  @override
  String get bottomToolsSheetResetDefault => '기본값으로 재설정';

  @override
  String get bottomToolsSheetSave => '저장';

  @override
  String get bottomToolsSheetOcr => '이미지 OCR';

  @override
  String get messageMoreSheetTitle => '더보기';

  @override
  String get messageMoreSheetSelectCopy => '텍스트 선택';

  @override
  String get messageMoreSheetRenderWebView => '웹 페이지로 보기';

  @override
  String get messageMoreSheetNotImplemented => '아직 구현되지 않음';

  @override
  String get messageMoreSheetEdit => '편집';

  @override
  String get messageMoreSheetShare => '공유';

  @override
  String get messageMoreSheetSelectMessages => '메시지 선택';

  @override
  String get messageMoreSheetCreateBranch => '분기 만들기';

  @override
  String get messageMoreSheetDelete => '이 버전 삭제';

  @override
  String get messageMoreSheetDeleteAllVersions => '모든 버전 삭제';

  @override
  String get reasoningBudgetSheetTitle => '추론 수준';

  @override
  String get reasoningLevelSheetTitle => '추론';

  @override
  String get reasoningLevelAuto => '자동';

  @override
  String get reasoningLevelAutoSubtitle => '모델 또는 제공업체의 기본값을 사용합니다';

  @override
  String get reasoningLevelOff => '꺼짐';

  @override
  String get reasoningLevelOffSubtitle => '추론을 끄고 바로 답합니다';

  @override
  String get reasoningLevelMinimal => '최소';

  @override
  String get reasoningLevelMinimalSubtitle => '가장 가벼운 추론으로 질문에 답합니다';

  @override
  String get reasoningLevelLow => '낮음';

  @override
  String get reasoningLevelLowSubtitle => '가벼운 추론으로 질문에 답합니다';

  @override
  String get reasoningLevelMedium => '중간';

  @override
  String get reasoningLevelMediumSubtitle => '적당한 추론으로 질문에 답합니다';

  @override
  String get reasoningLevelHigh => '높음';

  @override
  String get reasoningLevelHighSubtitle => '깊은 추론으로 복잡한 질문에 답합니다';

  @override
  String get reasoningLevelXhigh => '매우 높음';

  @override
  String get reasoningLevelXhighSubtitle => '매우 깊은 추론으로 더 어려운 문제를 해결합니다';

  @override
  String get reasoningLevelMax => '최대';

  @override
  String get reasoningLevelMaxSubtitle => '최대 깊이의 추론으로 가장 어려운 문제를 해결합니다';

  @override
  String get reasoningLevelFollowModelDefaultSubtitle =>
      '어시스턴트에 설정된 값이 없으면 모델 기본값을 사용합니다';

  @override
  String get reasoningLevelNoReasoning => '이 모델은 추론을 지원하지 않습니다';

  @override
  String get reasoningLevelCustomBudget => '사용자 지정 추론 예산';

  @override
  String get reasoningLevelCustomBudgetHint => '토큰 예산(예: 2048)';

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
    return '$budget 토큰';
  }

  @override
  String chatMessageWidgetFileNotFound(String fileName) {
    return '파일을 찾을 수 없습니다: $fileName';
  }

  @override
  String chatMessageWidgetCannotOpenFile(String message) {
    return '파일을 열 수 없습니다: $message';
  }

  @override
  String chatMessageWidgetOpenFileError(String error) {
    return '파일을 열지 못했습니다: $error';
  }

  @override
  String get chatMessageWidgetCopiedToClipboard => '클립보드에 복사됨';

  @override
  String get chatMessageWidgetResendTooltip => '다시 보내기';

  @override
  String get chatMessageWidgetMoreTooltip => '더보기';

  @override
  String get chatMessageWidgetThinking => '생각 중…';

  @override
  String get chatMessageWidgetTranslation => '번역';

  @override
  String get chatMessageWidgetTranslating => '번역 중…';

  @override
  String get chatMessageWidgetCitationNotFound => '인용 출처를 찾을 수 없습니다';

  @override
  String chatMessageWidgetCannotOpenUrl(String url) {
    return '링크를 열 수 없습니다: $url';
  }

  @override
  String get chatMessageWidgetOpenLinkError => '링크를 열지 못했습니다';

  @override
  String get chatMessageWidgetAttachmentUnavailable => '첨부 파일을 사용할 수 없음';

  @override
  String chatMessageWidgetCitationsTitle(int count) {
    return '인용($count)';
  }

  @override
  String get chatMessageWidgetSearchResultsTitle => '검색 결과';

  @override
  String get chatMessageWidgetCitationSourcesTitle => '인용 출처';

  @override
  String get chatMessageWidgetRegenerateTooltip => '다시 생성';

  @override
  String get chatMessageWidgetRegenerateConfirmTitle => '다시 생성 확인';

  @override
  String get chatMessageWidgetRegenerateConfirmContent =>
      '다시 생성하면 이 메시지만 업데이트되고 아래 메시지는 유지됩니다. 계속하시겠습니까?';

  @override
  String get chatMessageWidgetRegenerateConfirmDeleteTrailingContent =>
      '다시 생성하면 이 메시지 아래의 모든 메시지가 삭제되며, 이 작업은 되돌릴 수 없습니다. 계속하시겠습니까?';

  @override
  String get chatMessageWidgetRegenerateConfirmCancel => '취소';

  @override
  String get chatMessageWidgetRegenerateConfirmOk => '다시 생성';

  @override
  String get chatMessageWidgetStopTooltip => '중지';

  @override
  String get chatMessageWidgetSpeakTooltip => '소리 내어 읽기';

  @override
  String get chatMessageWidgetTranslateTooltip => '번역';

  @override
  String get chatMessageWidgetBuiltinSearchHideNote => '모델 내장 검색 도구 카드 숨기기';

  @override
  String get chatMessageWidgetDeepThinking => '생각 과정';

  @override
  String chatMessageWidgetWebSearch(String query) {
    return '웹 검색: $query';
  }

  @override
  String chatMessageWidgetWebFetch(String target) {
    return '페이지 읽기: $target';
  }

  @override
  String get chatMessageWidgetBuiltinSearch => '모델 내장 검색';

  @override
  String get chatMessageWidgetReadClipboard => '클립보드 읽기';

  @override
  String get chatMessageWidgetWriteClipboard => '클립보드 쓰기';

  @override
  String get chatMessageWidgetSpeakingTitle => '소리 내어 읽는 중:';

  @override
  String chatMessageWidgetSpeakText(String text) {
    return '소리 내어 읽는 중: $text';
  }

  @override
  String get chatMessageWidgetMemoryRead => '메모리 읽기';

  @override
  String get chatMessageWidgetMemoryUpdate => '메모리 업데이트';

  @override
  String get chatMessageWidgetMemorySearchProfile => '메모리 검색';

  @override
  String get chatMessageWidgetMemoryEdit => '메모리 편집';

  @override
  String get chatMessageWidgetMemoryDelete => '메모리 삭제';

  @override
  String get chatMessageWidgetUpdateUserProfile => '사용자 프로필 업데이트';

  @override
  String get chatMessageWidgetChatSearch => '지난 채팅 검색';

  @override
  String get chatMessageWidgetCreateMemory => '메모리 만들기';

  @override
  String chatMessageWidgetToolCall(String name) {
    return '도구 호출: $name';
  }

  @override
  String chatMessageWidgetToolResult(String name) {
    return '도구 결과: $name';
  }

  @override
  String get chatMessageWidgetNoResultYet => '(아직 결과 없음)';

  @override
  String get chatMessageWidgetArguments => '인수';

  @override
  String get chatMessageWidgetResult => '결과';

  @override
  String get chatMessageWidgetImages => '이미지';

  @override
  String chatMessageWidgetCitationsCount(int count) {
    return '인용 $count개';
  }

  @override
  String chatSelectionSelectedCountTitle(int count) {
    return '메시지 $count개 선택됨';
  }

  @override
  String get chatSelectionExportTxt => 'TXT';

  @override
  String get chatSelectionExportMd => 'MD';

  @override
  String get chatSelectionExportImage => '이미지';

  @override
  String get chatSelectionThinkingTools => '생각 및 도구 카드';

  @override
  String get chatSelectionThinkingContent => '생각 내용';

  @override
  String get chatSelectionDeleteSelected => '선택 항목 삭제';

  @override
  String get chatSelectionSelectMessagesToDelete => '삭제할 메시지를 선택하세요';

  @override
  String chatSelectionDeleteSelectedConfirm(int count) {
    return '선택한 버전 $count개를 삭제하시겠습니까? 이 작업은 되돌릴 수 없습니다.';
  }

  @override
  String chatSelectionDeleteSelectedAllVersionsConfirm(int count) {
    return '선택한 메시지 $count개의 모든 버전을 삭제하시겠습니까? 이 작업은 되돌릴 수 없습니다.';
  }

  @override
  String get messageExportSheetAssistant => '어시스턴트';

  @override
  String get messageExportSheetDefaultTitle => '새 채팅';

  @override
  String get messageExportSheetExporting => '내보내는 중…';

  @override
  String messageExportSheetExportFailed(String error) {
    return '내보내기 실패: $error';
  }

  @override
  String messageExportSheetExportedAs(String filename) {
    return '$filename(으)로 내보냄';
  }

  @override
  String get displaySettingsPageEnableDollarLatexTitle => '인라인 \$...\$ 렌더링';

  @override
  String get displaySettingsPageEnableDollarLatexSubtitle =>
      '\$...\$ 안의 내용을 인라인 수식으로 렌더링합니다';

  @override
  String get displaySettingsPageEnableMathTitle => '수식 렌더링';

  @override
  String get displaySettingsPageEnableMathSubtitle =>
      'LaTeX 수식(인라인 및 블록)을 렌더링합니다';

  @override
  String get displaySettingsPageEnableUserMarkdownTitle =>
      '사용자 메시지를 Markdown으로 렌더링';

  @override
  String get displaySettingsPageEnableReasoningMarkdownTitle =>
      '생각 내용을 Markdown으로 렌더링';

  @override
  String get displaySettingsPageEnableAssistantMarkdownTitle =>
      '어시스턴트 메시지를 Markdown으로 렌더링';

  @override
  String get displaySettingsPageMobileCodeBlockWrapTitle => '모바일 코드 블록 자동 줄 바꿈';

  @override
  String get displaySettingsPageAutoCollapseCodeBlockTitle => '코드 블록 자동 접기';

  @override
  String get displaySettingsPageAutoCollapseCodeBlockLinesTitle => '자동 접기 기준';

  @override
  String get displaySettingsPageAutoCollapseCodeBlockLinesUnit => '줄';

  @override
  String get displaySettingsPageCollapseLongUserMessagesTitle => '긴 메시지 접기';

  @override
  String get displaySettingsPageCollapseLongUserMessagesSubtitle =>
      '기준보다 긴 사용자 메시지를 접고 펼치기 버튼으로 볼 수 있게 합니다';

  @override
  String get displaySettingsPageCollapseLongUserMessagesCharsTitle => '접기 기준';

  @override
  String get displaySettingsPageCollapseLongUserMessagesCharsUnit => '자';

  @override
  String get chatMessageExpandLongText => '펼치기';

  @override
  String get chatMessageCollapseLongText => '접기';

  @override
  String get messageExportSheetFormatTitle => '내보내기 형식';

  @override
  String get messageExportSheetMarkdown => 'Markdown';

  @override
  String get messageExportSheetSingleMarkdownSubtitle =>
      '이 메시지를 Markdown 파일로 내보냅니다';

  @override
  String get messageExportSheetBatchMarkdownSubtitle =>
      '선택한 메시지를 Markdown 파일로 내보냅니다';

  @override
  String get messageExportSheetPlainText => '일반 텍스트';

  @override
  String get messageExportSheetSingleTxtSubtitle => '이 메시지를 TXT 파일로 내보냅니다';

  @override
  String get messageExportSheetBatchTxtSubtitle => '선택한 메시지를 TXT 파일로 내보냅니다';

  @override
  String get messageExportSheetExportImage => '이미지로 내보내기';

  @override
  String get messageExportSheetSingleExportImageSubtitle =>
      '이 메시지를 PNG 이미지로 렌더링합니다';

  @override
  String get messageExportSheetBatchExportImageSubtitle =>
      '선택한 메시지를 PNG 이미지로 렌더링합니다';

  @override
  String get messageExportSheetShowThinkingAndToolCards => '생각 및 도구 카드 표시';

  @override
  String get messageExportSheetShowThinkingContent => '생각 내용 표시';

  @override
  String get messageExportThinkingContentLabel => '생각 내용';

  @override
  String get messageExportSheetDateTimeWithSecondsPattern =>
      'yyyy년 M월 d일 HH:mm:ss';

  @override
  String get exportDisclaimerAiGenerated => 'AI가 생성한 콘텐츠입니다. 내용을 꼼꼼히 확인하세요.';

  @override
  String get imagePreviewSheetSaveImage => '이미지 저장';

  @override
  String get imagePreviewSheetSaveSuccess => '갤러리에 저장됨';

  @override
  String imagePreviewSheetSaveFailed(String error) {
    return '저장 실패: $error';
  }

  @override
  String get sideDrawerMenuRename => '이름 변경';

  @override
  String get sideDrawerMenuPin => '고정';

  @override
  String get sideDrawerMenuUnpin => '고정 해제';

  @override
  String get sideDrawerMenuRegenerateTitle => '제목 다시 생성';

  @override
  String get sideDrawerMenuCopy => '복사';

  @override
  String get sideDrawerMenuMoveTo => '이동';

  @override
  String get sideDrawerMenuDelete => '삭제';

  @override
  String get sideDrawerMenuSelect => '여러 개 선택';

  @override
  String sideDrawerSelectionTitle(int count) {
    return '$count개 선택됨';
  }

  @override
  String get sideDrawerSelectionSelectAll => '모두 선택';

  @override
  String get sideDrawerSelectionDeselectAll => '모두 선택 해제';

  @override
  String get sideDrawerSelectionPin => '고정';

  @override
  String get sideDrawerSelectionUnpin => '고정 해제';

  @override
  String get sideDrawerSelectionMove => '이동';

  @override
  String get sideDrawerSelectionDelete => '삭제';

  @override
  String get sideDrawerSelectionDeleteConfirmTitle => '대화 삭제';

  @override
  String sideDrawerSelectionDeleteConfirmContent(int count) {
    return '대화 $count개를 삭제하시겠습니까?';
  }

  @override
  String sideDrawerDeleteConfirmContent(String title) {
    return '“$title”을(를) 삭제하시겠습니까?';
  }

  @override
  String sideDrawerDeleteSelectedSnackbar(int count) {
    return '대화 $count개 삭제됨';
  }

  @override
  String sideDrawerMoveSelectedSnackbar(int count) {
    return '대화 $count개 이동됨';
  }

  @override
  String sideDrawerDeleteSnackbar(String title) {
    return '“$title” 삭제됨';
  }

  @override
  String get sideDrawerRenameHint => '새 이름 입력';

  @override
  String get sideDrawerCancel => '취소';

  @override
  String get sideDrawerOK => '확인';

  @override
  String get sideDrawerSave => '저장';

  @override
  String get sideDrawerGreetingMorning => '좋은 아침입니다 👋';

  @override
  String get sideDrawerGreetingNoon => '안녕하세요 👋';

  @override
  String get sideDrawerGreetingAfternoon => '안녕하세요 👋';

  @override
  String get sideDrawerGreetingEvening => '좋은 저녁입니다 👋';

  @override
  String get sideDrawerDateToday => '오늘';

  @override
  String get sideDrawerDateYesterday => '어제';

  @override
  String get sideDrawerDateShortPattern => 'M월 d일';

  @override
  String get sideDrawerDateFullPattern => 'yyyy년 M월 d일';

  @override
  String get sideDrawerSearchHint => '현재 어시스턴트의 대화 검색';

  @override
  String get sideDrawerSearchAssistantsHint => '어시스턴트 검색';

  @override
  String get sideDrawerTopicSearchModeLabel => '대화 모드';

  @override
  String get sideDrawerGlobalSearchModeLabel => '전역 모드';

  @override
  String get sideDrawerSearchModeSwipeToTopicHint => '검색창을 스와이프해 대화 검색으로 전환';

  @override
  String get sideDrawerSearchModeSwipeToGlobalHint => '검색창을 스와이프해 전역 검색으로 전환';

  @override
  String get sideDrawerGlobalSearchHint => '모든 대화 검색';

  @override
  String get sideDrawerGlobalSearchEmptyHint => '제목과 메시지 전체에서 검색';

  @override
  String get sideDrawerGlobalSearchNoResults => '일치하는 대화가 없습니다';

  @override
  String sideDrawerGlobalSearchResultCount(int count) {
    return '결과 $count개';
  }

  @override
  String sideDrawerUpdateTitle(String version) {
    return '새 버전: $version';
  }

  @override
  String sideDrawerUpdateTitleWithBuild(String version, int build) {
    return '새 버전: $version($build)';
  }

  @override
  String get sideDrawerLinkCopied => '다운로드 링크 복사됨';

  @override
  String get sideDrawerPinnedLabel => '고정됨';

  @override
  String get sideDrawerHistory => '채팅 기록';

  @override
  String get sideDrawerSettings => '설정';

  @override
  String get sideDrawerChooseAssistantTitle => '어시스턴트 선택';

  @override
  String get sideDrawerChooseImage => '이미지 선택';

  @override
  String get sideDrawerChooseEmoji => '이모지 선택';

  @override
  String get sideDrawerEnterLink => '링크 입력';

  @override
  String get sideDrawerImportFromQQ => 'QQ에서 가져오기';

  @override
  String get sideDrawerReset => '재설정';

  @override
  String get providerAvatarChooseBuiltInIcon => '내장 아이콘 선택';

  @override
  String get providerAvatarIconDialogTitle => '내장 아이콘 선택';

  @override
  String get providerAvatarIconSearchHint => '아이콘 검색';

  @override
  String get providerAvatarIconNoResults => '아이콘을 찾을 수 없습니다';

  @override
  String get providerAvatarInputLobehubIcon => 'LobeHub 아이콘 입력';

  @override
  String get providerAvatarChooseLobehubIcon => 'LobeHub 아이콘 입력';

  @override
  String get providerAvatarLobehubDialogTitle => 'LobeHub 아이콘 입력';

  @override
  String get providerAvatarLobehubDialogHint => 'LobeHub 아이콘 이름 입력(예: openai)';

  @override
  String get sideDrawerEmojiDialogTitle => '이모지 선택';

  @override
  String get sideDrawerEmojiDialogHint => '이모지 입력 또는 붙여넣기';

  @override
  String get sideDrawerImageUrlDialogTitle => '이미지 URL 입력';

  @override
  String get sideDrawerImageUrlDialogHint =>
      '예: https://example.com/avatar.png';

  @override
  String get sideDrawerQQAvatarDialogTitle => 'QQ에서 가져오기';

  @override
  String get sideDrawerQQAvatarInputHint => 'QQ 번호 입력(5~12자리)';

  @override
  String get sideDrawerQQAvatarFetchFailed =>
      '무작위 QQ 아바타를 불러오지 못했습니다. 다시 시도하세요.';

  @override
  String get sideDrawerRandomQQ => '무작위 선택';

  @override
  String get sideDrawerGalleryOpenError => '갤러리를 열 수 없습니다. 이미지 URL을 입력해 보세요.';

  @override
  String get sideDrawerGeneralImageError => '문제가 발생했습니다. 이미지 URL을 입력해 보세요.';

  @override
  String get sideDrawerSetNicknameTitle => '닉네임 설정';

  @override
  String get sideDrawerNicknameLabel => '닉네임';

  @override
  String get sideDrawerNicknameHint => '새 닉네임 입력';

  @override
  String get sideDrawerRename => '이름 변경';

  @override
  String get chatInputBarHint => 'AI에게 메시지 보내기';

  @override
  String get chatInputBarSelectModelTooltip => '모델 선택';

  @override
  String get chatInputBarOnlineSearchTooltip => '웹 검색';

  @override
  String get chatInputBarReasoningStrengthTooltip => '추론 수준';

  @override
  String get chatInputBarMcpServersTooltip => 'MCP 서버';

  @override
  String get chatInputBarToolsTooltip => '도구';

  @override
  String get chatInputBarMoreTooltip => '추가';

  @override
  String get chatInputBarVoiceInputTooltip => '음성 입력';

  @override
  String get chatInputBarVoiceCancelTooltip => '녹음 취소';

  @override
  String get chatInputBarVoiceStopTooltip => '중지 후 텍스트로 변환';

  @override
  String get chatInputBarVoiceSendTooltip => '텍스트로 변환 후 보내기';

  @override
  String get chatInputBarVoiceTranscribing => '인식 중…';

  @override
  String get chatInputBarVoiceAttachAudioTooltip => '중지 후 오디오로 첨부';

  @override
  String get chatInputBarVoiceSendAudioTooltip => '녹음 보내기';

  @override
  String get chatInputBarVoiceSavingAudio => '오디오 저장 중…';

  @override
  String get audioClipPlayTooltip => '오디오 재생';

  @override
  String get audioClipPauseTooltip => '일시 중지';

  @override
  String get audioClipPlaybackFailed => '이 오디오를 재생하지 못했습니다';

  @override
  String get chatInputBarImageProcessing => '이미지 처리 중';

  @override
  String get chatInputBarImageMode => '이미지 생성 모드';

  @override
  String get chatInputBarDisableImageModeTooltip => '이미지 생성 모드 끄기';

  @override
  String get chatInputBarQueuedPending => '전송 대기 중';

  @override
  String get chatInputBarQueuedCancel => '대기 취소';

  @override
  String get chatInputBarInsertNewline => '줄 바꿈';

  @override
  String get chatInputBarExpand => '펼치기';

  @override
  String get chatInputBarCollapse => '접기';

  @override
  String get contextUsageTitle => '컨텍스트 윈도우';

  @override
  String get contextUsageStateExact => '정확한 값(마지막 응답 기준)';

  @override
  String get contextUsageStateExactCalibrated => '정확한 값(항목별 값은 추정치로 비례 조정)';

  @override
  String get contextUsageStateEstimated => '추정치';

  @override
  String get contextUsageStateStale => '오래된 값, 업데이트 중…';

  @override
  String get contextUsageStateComputing => '계산 중…';

  @override
  String get contextUsageStateNone => '아직 데이터가 없습니다';

  @override
  String get contextUsageBucketSystem => '시스템 프롬프트';

  @override
  String get contextUsageBucketInjections => '지침 주입';

  @override
  String get contextUsageBucketHistory => '메시지 기록';

  @override
  String get contextUsageBucketTools => '내장 도구';

  @override
  String get contextUsageBucketMemory => '메모리';

  @override
  String get contextUsageBucketWorldBook => '월드북';

  @override
  String get contextUsageBucketSkills => '스킬';

  @override
  String get contextUsageBucketWorkspace => '워크스페이스';

  @override
  String get contextUsageBucketSearch => '검색 프롬프트';

  @override
  String get contextUsageBucketMcpTools => 'MCP 도구';

  @override
  String get contextUsageBucketAttachments => '첨부 파일';

  @override
  String get contextUsageBucketDraft => '초안';

  @override
  String get contextUsageBucketUsed => '사용됨';

  @override
  String get contextUsageFreeSpace => '남은 공간';

  @override
  String contextUsageUsedWindow(String used, String window, int percent) {
    return '$used / $window($percent%)';
  }

  @override
  String get contextUsageNoWindow => '컨텍스트 윈도우 없음';

  @override
  String get contextUsageSetWindow => '컨텍스트 윈도우 설정';

  @override
  String get contextUsageRefresh => '새로고침';

  @override
  String get mcpPageBackTooltip => '뒤로';

  @override
  String get mcpPageAddMcpTooltip => 'MCP 추가';

  @override
  String get mcpPageNoServers => 'MCP 서버 없음';

  @override
  String get mcpPageErrorDialogTitle => '연결 오류';

  @override
  String get mcpPageErrorNoDetails => '세부 정보 없음';

  @override
  String get mcpPageClose => '닫기';

  @override
  String get mcpPageReconnect => '다시 연결';

  @override
  String get mcpPageStatusConnected => '연결됨';

  @override
  String get mcpPageStatusConnecting => '연결 중…';

  @override
  String get mcpPageStatusDisconnected => '연결되지 않음';

  @override
  String get mcpPageStatusAuthorizationRequired => '인증 필요';

  @override
  String get mcpPageStatusAuthorizing => '인증 중…';

  @override
  String get mcpPageStatusDisabled => '비활성화됨';

  @override
  String get mcpPageOAuthRequired => 'OAuth 로그인이 필요합니다';

  @override
  String get mcpPageOAuthSignIn => 'OAuth로 로그인';

  @override
  String mcpPageToolsCount(int enabled, int total) {
    return '도구: $enabled/$total';
  }

  @override
  String get mcpPageConnectionFailed => '연결 실패';

  @override
  String get mcpPageDetails => '세부 정보';

  @override
  String get mcpPageDelete => '삭제';

  @override
  String get mcpPageConfirmDeleteTitle => '삭제 확인';

  @override
  String get mcpPageConfirmDeleteContent => '‘실행 취소’로 되돌릴 수 있습니다. 삭제하시겠습니까?';

  @override
  String get mcpPageServerDeleted => '서버 삭제됨';

  @override
  String get mcpPageUndo => '실행 취소';

  @override
  String get mcpPageCancel => '취소';

  @override
  String get mcpConversationSheetTitle => 'MCP 서버';

  @override
  String get mcpConversationSheetSubtitle => '이 대화에서 사용할 서버 선택';

  @override
  String get mcpConversationSheetSelectAll => '모두 선택';

  @override
  String get mcpConversationSheetClearAll => '선택 해제';

  @override
  String get mcpConversationSheetNoRunning => '실행 중인 MCP 서버 없음';

  @override
  String get mcpConversationSheetConnected => '연결됨';

  @override
  String mcpConversationSheetToolsCount(int enabled, int total) {
    return '도구: $enabled/$total';
  }

  @override
  String get mcpServerEditSheetEnabledLabel => '활성화';

  @override
  String get mcpServerEditSheetNameLabel => '이름';

  @override
  String get mcpServerEditSheetTransportLabel => '전송 방식';

  @override
  String get mcpServerEditSheetUrlLabel => '서버 URL';

  @override
  String get mcpServerEditSheetCustomHeadersTitle => '사용자 지정 헤더';

  @override
  String get mcpServerEditSheetHeaderNameLabel => '헤더 이름';

  @override
  String get mcpServerEditSheetHeaderNameHint => '예: Authorization';

  @override
  String get mcpServerEditSheetHeaderValueLabel => '헤더 값';

  @override
  String get mcpServerEditSheetHeaderValueHint => '예: Bearer xxxxxx';

  @override
  String get mcpServerEditSheetRemoveHeaderTooltip => '제거';

  @override
  String get mcpServerEditSheetAddHeader => '헤더 추가';

  @override
  String get mcpServerEditSheetTitleEdit => 'MCP 편집';

  @override
  String get mcpServerEditSheetTitleAdd => 'MCP 추가';

  @override
  String get mcpServerEditSheetSyncToolsTooltip => '도구 동기화';

  @override
  String get mcpServerEditSheetTabBasic => '기본';

  @override
  String get mcpServerEditSheetTabTools => '도구';

  @override
  String get mcpServerEditSheetNoToolsHint => '도구가 없습니다. 새로고침을 눌러 동기화하세요';

  @override
  String get mcpServerEditSheetCancel => '취소';

  @override
  String get mcpServerEditSheetSave => '저장';

  @override
  String get mcpServerEditSheetUrlRequired => '서버 URL을 입력하세요';

  @override
  String get defaultModelPageBackTooltip => '뒤로';

  @override
  String get defaultModelPageTitle => '기본 모델';

  @override
  String get defaultModelPageChatModelTitle => '채팅 모델';

  @override
  String get defaultModelPageChatModelSubtitle => '전역 기본 채팅 모델';

  @override
  String get defaultModelPageTitleModelTitle => '제목 생성 모델';

  @override
  String get defaultModelPageTitleModelSubtitle =>
      '기본적으로 현재 채팅 모델로 대화 내용을 요약해 제목을 생성하며, 다른 모델을 선택할 수도 있습니다.';

  @override
  String get titleModelThinkingTitle => '추론 활성화';

  @override
  String get defaultModelPageSummaryModelTitle => '요약 모델';

  @override
  String get defaultModelPageSummaryModelSubtitle =>
      '대화 요약을 생성하는 데 사용되며, 빠르고 저렴한 모델을 권장합니다';

  @override
  String get defaultModelPageSuggestionModelTitle => '채팅 제안 모델';

  @override
  String get defaultModelPageSuggestionModelSubtitle =>
      '현재 채팅 모델 또는 선택한 모델로 후속 질문을 제안하는 말풍선을 생성합니다. 기본적으로 비활성화되어 있습니다.';

  @override
  String get assistantEditRecentChatsSummaryFrequencyTitle => '요약 갱신 주기';

  @override
  String get assistantEditRecentChatsSummaryFrequencyDescription =>
      '새 메시지가 선택한 개수만큼 쌓이면 대화 요약을 갱신합니다.';

  @override
  String assistantEditRecentChatsSummaryFrequencyOption(int count) {
    return '메시지 $count개마다';
  }

  @override
  String get assistantEditRecentChatsSummaryFrequencyCustomButton => '사용자 지정';

  @override
  String get assistantEditRecentChatsSummaryFrequencyCustomTitle =>
      '사용자 지정 요약 갱신 주기';

  @override
  String get assistantEditRecentChatsSummaryFrequencyCustomDescription =>
      '새 메시지가 몇 개 쌓이면 대화 요약을 갱신할지 입력하세요.';

  @override
  String get assistantEditRecentChatsSummaryFrequencyCustomLabel => '새 메시지 수';

  @override
  String get assistantEditRecentChatsSummaryFrequencyCustomHint =>
      '0보다 큰 숫자 입력';

  @override
  String get assistantEditRecentChatsSummaryFrequencyCustomInvalid =>
      '0보다 큰 정수를 입력하세요';

  @override
  String get defaultModelPageTranslateModelTitle => '번역 모델';

  @override
  String get defaultModelPageTranslateModelSubtitle =>
      '메시지 내용을 번역하는 데 사용되며, 빠르고 정확한 모델을 권장합니다';

  @override
  String get defaultModelPageOcrModelTitle => 'OCR 모델';

  @override
  String backgroundTaskFailed(String task, String error) {
    return '$task 실패: $error';
  }

  @override
  String get defaultModelPageOcrModelSubtitle =>
      '이미지의 텍스트를 추출하고 내용을 설명하는 데 사용됩니다';

  @override
  String get defaultModelPageOcrModelRequiresImageInput =>
      'OCR에는 이미지 입력을 지원하는 모델을 선택하세요';

  @override
  String get defaultModelPagePromptLabel => '프롬프트';

  @override
  String get defaultModelPageTitlePromptHint => '제목 생성에 사용할 프롬프트 템플릿 입력';

  @override
  String get defaultModelPageSummaryPromptHint => '대화 요약 생성에 사용할 프롬프트 템플릿 입력';

  @override
  String get defaultModelPageSuggestionPromptHint => '채팅 제안에 사용할 프롬프트 템플릿 입력';

  @override
  String get defaultModelPageTranslatePromptHint => '번역에 사용할 프롬프트 템플릿 입력';

  @override
  String get defaultModelPageOcrPromptHint => 'OCR 이미지 인식에 사용할 프롬프트 템플릿 입력';

  @override
  String get defaultModelPageResetDefault => '기본값으로 재설정';

  @override
  String get defaultModelPageDisable => '비활성화';

  @override
  String get defaultModelPageSave => '저장';

  @override
  String defaultModelPageTitleVars(String contentVar, String localeVar) {
    return '변수: 대화: $contentVar, 언어: $localeVar';
  }

  @override
  String defaultModelPageSummaryVars(
    String previousSummaryVar,
    String userMessagesVar,
  ) {
    return '변수: 기존 대화 요약: $previousSummaryVar, 새 메시지: $userMessagesVar';
  }

  @override
  String defaultModelPageSuggestionVars(String contentVar, String localeVar) {
    return '변수: 대화: $contentVar, 언어: $localeVar';
  }

  @override
  String get defaultModelPageCompressModelTitle => '압축 모델';

  @override
  String get defaultModelPageCompressModelSubtitle =>
      '대화 컨텍스트를 압축하는 데 사용되며, 빠른 모델을 권장합니다';

  @override
  String get defaultModelPageCompressPromptHint => '컨텍스트 압축에 사용할 프롬프트 템플릿 입력';

  @override
  String defaultModelPageCompressVars(String contentVar, String localeVar) {
    return '변수: 대화: $contentVar, 언어: $localeVar';
  }

  @override
  String defaultModelPageTranslateVars(String sourceVar, String targetVar) {
    return '변수: 원문: $sourceVar, 대상 언어: $targetVar';
  }

  @override
  String get defaultModelPageUseCurrentModel => '현재 채팅 모델 사용';

  @override
  String get defaultModelPageNotEnabled => '활성화되지 않음';

  @override
  String get translatePagePasteButton => '붙여넣기';

  @override
  String get translatePageCopyResult => '결과 복사';

  @override
  String get translatePageClearAll => '모두 지우기';

  @override
  String get translatePageInputHint => '번역할 텍스트 입력…';

  @override
  String get translatePageOutputHint => '번역 결과가 여기에 표시됩니다…';

  @override
  String get modelDetailSheetAddModel => '모델 추가';

  @override
  String get modelDetailSheetEditModel => '모델 편집';

  @override
  String get modelDetailSheetBasicTab => '기본';

  @override
  String get modelDetailSheetAdvancedTab => '고급';

  @override
  String get modelDetailSheetBuiltinToolsTab => '내장 도구';

  @override
  String get modelDetailSheetModelIdLabel => '모델 ID';

  @override
  String get modelDetailSheetModelIdHint => '필수, 영문 소문자/숫자/하이픈 권장';

  @override
  String get modelDetailSheetModelNameLabel => '모델 이름';

  @override
  String get modelDetailSheetModelTypeLabel => '모델 유형';

  @override
  String get modelDetailSheetChatType => '채팅';

  @override
  String get modelDetailSheetEmbeddingType => '임베딩';

  @override
  String get modelDetailSheetInputModesLabel => '입력 모드';

  @override
  String get modelDetailSheetOutputModesLabel => '출력 모드';

  @override
  String get modelDetailSheetAbilitiesLabel => '기능';

  @override
  String get modelDetailSheetTextMode => '텍스트';

  @override
  String get modelDetailSheetImageMode => '이미지';

  @override
  String get modelDetailSheetToolsAbility => '도구';

  @override
  String get modelDetailSheetReasoningAbility => '추론';

  @override
  String get modelDetailSheetCustomHeadersTitle => '사용자 지정 헤더';

  @override
  String get modelDetailSheetAddHeader => '헤더 추가';

  @override
  String get modelDetailSheetCustomBodyTitle => '사용자 지정 본문';

  @override
  String get modelFetchInvertTooltip => '선택 반전';

  @override
  String get modelDetailSheetSaveFailedMessage => '저장에 실패했습니다. 다시 시도하세요.';

  @override
  String get modelDetailSheetAddBody => '본문 추가';

  @override
  String get modelDetailSheetBuiltinToolsDescription =>
      '내장 도구는 제공업체와 API 모드에 따라 다릅니다.';

  @override
  String get modelDetailSheetUrlContextTool => 'URL 컨텍스트';

  @override
  String get modelDetailSheetUrlContextToolDescription => 'URL 콘텐츠 읽기를 활성화합니다';

  @override
  String get modelDetailSheetCodeExecutionTool => '코드 실행';

  @override
  String get modelDetailSheetCodeExecutionToolDescription => '코드 실행 도구를 활성화합니다';

  @override
  String get modelDetailSheetYoutubeTool => 'YouTube';

  @override
  String get modelDetailSheetYoutubeToolDescription =>
      'YouTube URL 읽기를 활성화합니다(프롬프트의 링크 자동 감지)';

  @override
  String get modelDetailSheetOpenaiBuiltinToolsResponsesOnlyHint =>
      'OpenAI Responses API가 필요합니다.';

  @override
  String get modelDetailSheetWebFetchTool => '웹 페이지 읽기';

  @override
  String get modelDetailSheetOpenrouterWebFetchToolDescription =>
      'OpenRouter 웹 페이지 읽기 서버 도구를 활성화합니다';

  @override
  String get modelDetailSheetClaudeWebFetchToolDescription =>
      'Claude가 대화에 포함된 URL의 웹 페이지와 PDF를 읽도록 허용합니다';

  @override
  String get modelDetailSheetClaudeCodeExecutionToolDescription =>
      'Claude가 Anthropic 샌드박스에서 Python과 Bash를 실행하도록 허용합니다';

  @override
  String get modelDetailSheetOpenrouterShellTool => '셸';

  @override
  String get modelDetailSheetOpenrouterShellToolDescription =>
      '호스팅된 격리 샌드박스에서 셸 명령을 실행합니다';

  @override
  String get modelDetailSheetOpenaiCodeInterpreterTool => '코드 인터프리터';

  @override
  String get modelDetailSheetOpenaiCodeInterpreterToolDescription =>
      '코드 인터프리터 도구를 활성화합니다(컨테이너 auto, 메모리 한도 4g)';

  @override
  String get modelDetailSheetOpenaiImageGenerationTool => '이미지 생성';

  @override
  String get modelDetailSheetOpenaiImageGenerationToolDescription =>
      '이미지 생성 도구를 활성화합니다';

  @override
  String get modelDetailSheetCancelButton => '취소';

  @override
  String get modelDetailSheetAddButton => '추가';

  @override
  String get modelDetailSheetConfirmButton => '확인';

  @override
  String get modelDetailSheetInvalidIdError => '2자 이상의 유효한 모델 ID를 입력하세요';

  @override
  String get modelDetailSheetHeaderKeyHint => '헤더 이름';

  @override
  String get modelDetailSheetHeaderValueHint => '헤더 값';

  @override
  String get modelDetailSheetBodyKeyHint => '본문 키';

  @override
  String get modelDetailSheetBodyJsonHint => '본문 JSON';

  @override
  String get modelSpecFormSourceCustom => '사용자 지정';

  @override
  String get modelSpecFormSourceCatalog => '카탈로그';

  @override
  String get modelSpecFormSourceInferred => '추정';

  @override
  String get modelSpecFormSourceDefault => '기본값';

  @override
  String get modelSpecFormReset => '기본값으로 재설정';

  @override
  String get modelSpecFormModalitiesSection => '모달리티 및 기능';

  @override
  String get modelSpecFormImageType => '이미지 생성';

  @override
  String get modelSpecFormAudioMode => '오디오';

  @override
  String get modelSpecFormVideoMode => '동영상';

  @override
  String get modelSpecFormPdfMode => 'PDF';

  @override
  String get modelSpecFormStructuredOutputAbility => '구조화된 출력';

  @override
  String get modelSpecFormReasoningSection => '추론';

  @override
  String get modelSpecFormDialect => '추론 필드 형식';

  @override
  String get modelSpecFormDialectNone => '없음';

  @override
  String get modelSpecFormDialectNoneSubtitle => '추론 필드 없음';

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
  String get modelSpecFormDialectCustom => '사용자 지정 JSON';

  @override
  String get modelSpecFormDialectCustomSubtitle => '수준별 JSON 패치';

  @override
  String get modelSpecFormLevels => '지원 수준';

  @override
  String get modelSpecFormCanDisable => '비활성화 허용';

  @override
  String get modelSpecFormDefaultLevel => '기본 수준';

  @override
  String get modelSpecFormBudgets => '토큰 예산';

  @override
  String modelSpecFormBudgetPlaceholder(String tokens) {
    return '$tokens';
  }

  @override
  String modelSpecFormCustomPatch(String level) {
    return 'JSON 패치($level)';
  }

  @override
  String get modelSpecFormCustomPatchHint => '예: reasoning_effort: high';

  @override
  String get modelSpecFormInvalidJson => '사용자 지정 추론 패치는 유효한 JSON 객체여야 합니다';

  @override
  String get modelSpecFormInvalidNumber => '유효한 숫자를 입력하세요';

  @override
  String get modelSpecFormStrategySection => '전략';

  @override
  String get modelSpecFormSampling => '샘플링';

  @override
  String get modelSpecFormRequestQuirks => '요청 호환성';

  @override
  String get modelSpecFormDynamicWebSearch => '동적 필터링 검색 도구';

  @override
  String get modelSpecFormDynamicWebSearchSubtitle =>
      '동적 필터링을 켜면 2026-03-18 버전의 웹 검색 및 웹 페이지 읽기 도구를 사용합니다';

  @override
  String get modelSpecFormRemoteImageUrls => '원격 이미지 링크';

  @override
  String get modelSpecFormRemoteImageUrlsSubtitle =>
      'http(s) 이미지 링크를 그대로 보내며, 끄면 원격 링크는 제외하고 로컬 이미지만 보냅니다';

  @override
  String get modelSpecFormPromptCacheControl => '프롬프트 캐시 마커';

  @override
  String get modelSpecFormPromptCacheControlSubtitle =>
      '프롬프트 캐싱을 켜면 OpenRouter 요청에 cache_control을 추가합니다';

  @override
  String get modelSpecFormSamplingAlways => '항상';

  @override
  String get modelSpecFormSamplingAlwaysSubtitle =>
      'temperature 등 샘플링 필드를 유지합니다';

  @override
  String get modelSpecFormSamplingOnlyWhenReasoningOff => '추론이 꺼져 있을 때만';

  @override
  String get modelSpecFormSamplingOnlyWhenReasoningOffSubtitle =>
      '모델이 추론하는 동안 샘플링 필드를 제거합니다';

  @override
  String get modelSpecFormSamplingNever => '안 함';

  @override
  String get modelSpecFormSamplingNeverSubtitle => '샘플링 필드를 항상 제거합니다';

  @override
  String get modelSpecFormReplay => '추론 재전송';

  @override
  String get modelSpecFormReplayNone => '안 함';

  @override
  String get modelSpecFormReplayNoneSubtitle => '이전 추론을 모델에 재전송하지 않습니다';

  @override
  String get modelSpecFormReplayToolTurns => '도구 호출 턴만';

  @override
  String get modelSpecFormReplayToolTurnsSubtitle => '도구 호출 턴에서만 추론을 재전송합니다';

  @override
  String get modelSpecFormReplayAll => '모두';

  @override
  String get modelSpecFormReplayAllSubtitle => '이후 모든 턴에서 추론을 재전송합니다';

  @override
  String get modelSpecFormReplayField => '재전송 필드';

  @override
  String get modelSpecFormReplayFieldReasoningContent => 'reasoning_content';

  @override
  String get modelSpecFormReplayFieldReasoning => 'reasoning';

  @override
  String get modelSpecFormReplayFieldReasoningDetails => 'reasoning_details';

  @override
  String get modelSpecFormLimitsSection => '토큰 한도';

  @override
  String get modelSpecFormLimitsPricingSection => '토큰 한도 및 가격';

  @override
  String get modelSpecFormContextWindow => '컨텍스트 윈도우';

  @override
  String get modelSpecFormMaxOutput => '최대 출력 토큰';

  @override
  String get modelSpecFormPricingSection => '100만 토큰당 가격';

  @override
  String get modelSpecFormPricingInput => '입력';

  @override
  String get modelSpecFormPricingOutput => '출력';

  @override
  String get modelSpecFormPricingCacheRead => '캐시 읽기';

  @override
  String get modelSpecFormPricingCacheWrite => '캐시 쓰기';

  @override
  String get modelSpecFormCurrency => '통화';

  @override
  String get modelSpecFormAdvancedSection => '요청';

  @override
  String get modelSelectSheetSearchHint => '모델 또는 제공업체 검색';

  @override
  String get modelSelectSheetFavoritesSection => '즐겨찾기';

  @override
  String get modelSelectSheetFollowAssistant => '어시스턴트 설정 따르기';

  @override
  String get modelSelectSheetFavoriteTooltip => '즐겨찾기';

  @override
  String get modelSelectSheetChatType => '채팅';

  @override
  String get modelSelectSheetEmbeddingType => '임베딩';

  @override
  String get providerDetailPageShareTooltip => '공유';

  @override
  String get providerDetailPageDeleteProviderTooltip => '제공업체 삭제';

  @override
  String get providerDetailPageDeleteProviderTitle => '제공업체 삭제';

  @override
  String get providerDetailPageDeleteProviderContent =>
      '이 제공업체를 삭제하시겠습니까? 이 작업은 되돌릴 수 없습니다.';

  @override
  String get providerDetailPageCancelButton => '취소';

  @override
  String get providerDetailPageDeleteButton => '삭제';

  @override
  String get providerDetailPageProviderDeletedSnackbar => '제공업체 삭제됨';

  @override
  String get providerDetailPageConfigTab => '구성';

  @override
  String get providerDetailPageModelsTab => '모델';

  @override
  String get providerDetailPageCustomRequestTitle => '사용자 지정 요청';

  @override
  String get providerDetailPageCustomRequestDescription =>
      '이 제공업체의 모든 모델에 적용됩니다. 모델 설정은 이 값보다, 이 값은 어시스턴트 설정보다 우선 적용됩니다.';

  @override
  String get providerDetailPageNetworkTab => '네트워크';

  @override
  String get providerDetailPageEnabledTitle => '활성화';

  @override
  String get providerDetailPageManageSectionTitle => '관리';

  @override
  String get providerDetailPageNameLabel => '이름';

  @override
  String get providerDetailPageApiKeyHint => '비워 두면 기본값을 사용합니다';

  @override
  String get providerDetailPageHideTooltip => '숨기기';

  @override
  String get providerDetailPageShowTooltip => '표시';

  @override
  String get providerDetailPageApiPathLabel => 'API 경로';

  @override
  String get providerDetailPageResponseApiTitle => 'Responses API(/responses)';

  @override
  String get providerDetailPagePromptCacheKeyTitle => '대화 캐시 키 보내기';

  @override
  String get providerDetailPagePromptCacheKeyHelp =>
      'OpenAI 호환 요청에 대화마다 고정된 prompt_cache_key를 추가합니다. 제공업체가 지원하는 경우에만 활성화하세요. 사용자 지정 본문의 값이 우선 적용되며, 캐시 히트는 보장되지 않습니다.';

  @override
  String get providerDetailPageAihubmixAppCodeLabel => 'APP-Code(10% 할인)';

  @override
  String get providerDetailPageAihubmixAppCodeHelp =>
      '요청에 APP-Code 헤더를 추가해 10% 할인을 받습니다. AIhubmix에만 적용됩니다.';

  @override
  String get providerDetailPageClaudePromptCachingTitle => 'Claude 프롬프트 캐싱';

  @override
  String get providerDetailPageClaudePromptCachingHelp =>
      'Anthropic 또는 OpenRouter로 보내는 Claude 요청에 cache_control을 추가합니다.';

  @override
  String get providerDetailPageClaudePromptCachingTtlTitle => '캐시 TTL';

  @override
  String get providerDetailPageClaudePromptCachingTtlHelp =>
      '기본값은 5분입니다. 1시간은 캐시 쓰기 비용이 더 높지만 긴 대화에서 캐시를 다시 만드는 횟수를 줄일 수 있습니다.';

  @override
  String get providerDetailPageClaudePromptCachingTtl5m => '5분';

  @override
  String get providerDetailPageClaudePromptCachingTtl1h => '1시간';

  @override
  String get providerDetailPageBalanceTitle => '계정 잔액';

  @override
  String get providerDetailPageBalanceInfo => '계정 잔액 불러오기';

  @override
  String get providerDetailPageBalanceApiPathLabel => '잔액 API 경로';

  @override
  String get providerDetailPageBalanceResultPathLabel => '결과 JSON 경로';

  @override
  String get providerDetailPageBalanceQueryButton => '잔액 확인';

  @override
  String get providerDetailPageBalanceQuerying => '확인 중…';

  @override
  String get providerDetailPageBalanceResetDefaultsButton => '재설정';

  @override
  String get providerDetailPageBalanceResetDefaultsTooltip => '잔액 설정 재설정';

  @override
  String providerDetailPageBalanceResult(String value) {
    return '잔액: $value';
  }

  @override
  String providerDetailPageBalanceError(String message) {
    return '잔액 확인 실패: $message';
  }

  @override
  String get providerDetailPageVertexAiTitle => 'Vertex AI';

  @override
  String get providerDetailPageLocationLabel => '리전';

  @override
  String get providerDetailPageProjectIdLabel => '프로젝트 ID';

  @override
  String get providerDetailPageServiceAccountJsonLabel =>
      '서비스 계정 JSON(붙여넣기 또는 가져오기)';

  @override
  String get providerDetailPageImportJsonButton => 'JSON 가져오기';

  @override
  String get providerDetailPageImportJsonReadFailedMessage => '파일을 읽지 못했습니다';

  @override
  String get providerDetailPageTestButton => '테스트';

  @override
  String get providerDetailPageSaveButton => '저장';

  @override
  String get providerDetailPageProviderRemovedMessage => '제공업체 삭제됨';

  @override
  String get providerDetailPageNoModelsTitle => '모델 없음';

  @override
  String get providerDetailPageNoModelsSubtitle => '아래 버튼을 눌러 모델을 추가하세요';

  @override
  String get providerDetailPageDeleteModelButton => '삭제';

  @override
  String get providerDetailPageConfirmDeleteTitle => '삭제 확인';

  @override
  String get providerDetailPageConfirmDeleteContent =>
      '‘실행 취소’로 되돌릴 수 있습니다. 삭제하시겠습니까?';

  @override
  String get providerDetailPageModelDeletedSnackbar => '모델 삭제됨';

  @override
  String get providerDetailPageUndoButton => '실행 취소';

  @override
  String get providerDetailPageAddNewModelButton => '모델 추가';

  @override
  String get providerDetailPageFetchModelsButton => '불러오기';

  @override
  String get providerDetailPageEnableProxyTitle => '프록시 활성화';

  @override
  String get providerDetailPageHostLabel => '호스트';

  @override
  String get providerDetailPagePortLabel => '포트';

  @override
  String get providerDetailPageUsernameOptionalLabel => '사용자 이름(선택 사항)';

  @override
  String get providerDetailPagePasswordOptionalLabel => '비밀번호(선택 사항)';

  @override
  String get providerDetailPageSavedSnackbar => '저장됨';

  @override
  String get providerDetailPageEmbeddingsGroupTitle => '임베딩';

  @override
  String get providerDetailPageOtherModelsGroupTitle => '기타';

  @override
  String get providerDetailPageRemoveGroupTooltip => '그룹 모델 모두 제거';

  @override
  String get providerDetailPageAddGroupTooltip => '그룹 모델 모두 추가';

  @override
  String get providerDetailPageFilterHint => '필터링할 모델 이름 입력';

  @override
  String get providerDetailPageDeleteText => '삭제';

  @override
  String get providerDetailPageEditTooltip => '편집';

  @override
  String get providerDetailPageTestConnectionTitle => '연결 테스트';

  @override
  String get providerDetailPageSelectModelButton => '모델 선택';

  @override
  String get providerDetailPageChangeButton => '변경';

  @override
  String get providerDetailPageUseStreamingLabel => '스트리밍 사용';

  @override
  String get providerDetailPageTestingMessage => '테스트 중…';

  @override
  String get providerDetailPageTestSuccessMessage => '성공';

  @override
  String get providersPageTitle => '제공업체';

  @override
  String get providersPageImportTooltip => '가져오기';

  @override
  String get providersPageAddTooltip => '추가';

  @override
  String get providersPageSearchHint => '제공업체 또는 그룹 검색';

  @override
  String get providersPageProviderAddedSnackbar => '제공업체 추가됨';

  @override
  String get modelCatalogTitle => '모델 카탈로그';

  @override
  String modelCatalogSourceBundled(String date) {
    return '내장 스냅샷 · $date';
  }

  @override
  String modelCatalogSourceRemote(String date) {
    return 'models.dev · 업데이트: $date';
  }

  @override
  String get modelCatalogAutoUpdate => '24시간마다 자동 업데이트';

  @override
  String get modelCatalogRefresh => '지금 업데이트';

  @override
  String get modelCatalogUpdated => '모델 카탈로그 업데이트됨';

  @override
  String modelCatalogRefreshFailed(String error) {
    return '업데이트 실패: $error';
  }

  @override
  String modelCatalogProviderCount(int count) {
    return '제공업체 $count개';
  }

  @override
  String modelCatalogModelCount(int count) {
    return '모델 $count개';
  }

  @override
  String get providerGroupsGroupLabel => '그룹';

  @override
  String get providerGroupsOther => '기타';

  @override
  String get providerGroupsOtherUngroupedOption => '기타(그룹 없음)';

  @override
  String get providerGroupsPickerTitle => '그룹 선택';

  @override
  String get providerGroupsManageTitle => '그룹 관리';

  @override
  String get providerGroupsManageAction => '그룹 관리';

  @override
  String get providerGroupsCreateNewGroupAction => '새 그룹…';

  @override
  String get providerGroupsCreateDialogTitle => '새 그룹';

  @override
  String get providerGroupsNameHint => '그룹 이름';

  @override
  String get providerGroupsCreateDialogCancel => '취소';

  @override
  String get providerGroupsCreateDialogOk => '만들기';

  @override
  String get providerGroupsCreateFailedToast => '그룹을 만들지 못했습니다';

  @override
  String get providerGroupsDeleteConfirmTitle => '그룹을 삭제하시겠습니까?';

  @override
  String get providerGroupsDeleteConfirmContent => '이 그룹의 제공업체는 ‘기타’로 이동됩니다.';

  @override
  String get providerGroupsDeleteConfirmCancel => '취소';

  @override
  String get providerGroupsDeleteConfirmOk => '삭제';

  @override
  String get providerGroupsDeletedToast => '그룹 삭제됨';

  @override
  String get providerGroupsEmptyState => '아직 그룹이 없습니다.';

  @override
  String get providerGroupsExpandToMoveToast => '먼저 그룹을 펼치세요.';

  @override
  String get providersPageSiliconFlowName => 'SiliconFlow';

  @override
  String get providersPageAliyunName => 'Aliyun';

  @override
  String get providersPageZhipuName => 'Zhipu AI';

  @override
  String get providersPageByteDanceName => 'ByteDance';

  @override
  String get providersPageEnabledStatus => '켜짐';

  @override
  String get providersPageDisabledStatus => '꺼짐';

  @override
  String get providersPageModelsCountSuffix => '개 모델';

  @override
  String get providersPageModelsCountSingleSuffix => '개 모델';

  @override
  String get addProviderSheetTitle => '제공업체 추가';

  @override
  String get addProviderSheetEnabledLabel => '활성화';

  @override
  String get addProviderSheetNameLabel => '이름';

  @override
  String get addProviderSheetApiPathLabel => 'API 경로';

  @override
  String get addProviderSheetVertexAiLocationLabel => '리전';

  @override
  String get addProviderSheetVertexAiProjectIdLabel => '프로젝트 ID';

  @override
  String get addProviderSheetVertexAiServiceAccountJsonLabel =>
      '서비스 계정 JSON(붙여넣기 또는 가져오기)';

  @override
  String get addProviderSheetImportJsonButton => 'JSON 가져오기';

  @override
  String get addProviderSheetCancelButton => '취소';

  @override
  String get addProviderSheetAddButton => '추가';

  @override
  String get importProviderSheetTitle => '제공업체 가져오기';

  @override
  String get importProviderSheetScanQrTooltip => 'QR 코드 스캔';

  @override
  String get importProviderSheetFromGalleryTooltip => '갤러리에서 가져오기';

  @override
  String importProviderSheetImportSuccessMessage(int count) {
    return '제공업체 $count개 가져옴';
  }

  @override
  String importProviderSheetImportFailedMessage(String error) {
    return '가져오기 실패: $error';
  }

  @override
  String get importProviderSheetDescription =>
      '공유 문자열(여러 줄 가능) 또는 Chatbox JSON 붙여넣기';

  @override
  String get importProviderSheetInputHint => 'ai-provider:v1:... 또는 JSON';

  @override
  String get importProviderSheetCancelButton => '취소';

  @override
  String get importProviderSheetImportButton => '가져오기';

  @override
  String get shareProviderSheetTitle => '제공업체 공유';

  @override
  String get shareProviderSheetDescription => '공유 문자열을 복사하거나 QR 코드로 공유하세요.';

  @override
  String get shareProviderSheetCopiedMessage => '복사됨';

  @override
  String get shareProviderSheetCopyButton => '복사';

  @override
  String get shareProviderSheetShareButton => '공유';

  @override
  String get desktopProviderContextMenuShare => '공유';

  @override
  String get desktopProviderShareCopyText => '코드 복사';

  @override
  String get desktopProviderShareCopyQr => 'QR 복사';

  @override
  String get providerDetailPageApiBaseUrlLabel => 'API 기본 URL';

  @override
  String get providerDetailPageModelsTitle => '모델';

  @override
  String get providerModelsGetButton => '불러오기';

  @override
  String get providerDetailPageCapsVision => '비전';

  @override
  String get providerDetailPageCapsImage => '이미지 생성';

  @override
  String get providerDetailPageCapsTool => '도구';

  @override
  String get providerDetailPageCapsReasoning => '추론';

  @override
  String get qrScanPageTitle => 'QR 코드 스캔';

  @override
  String get qrScanPageInstruction => 'QR 코드를 프레임 안에 맞추세요';

  @override
  String get searchServicesPageBackTooltip => '뒤로';

  @override
  String get searchServicesPageTitle => '검색 서비스';

  @override
  String get searchServicesPageDone => '완료';

  @override
  String get searchServicesPageEdit => '편집';

  @override
  String get searchServicesPageAddProvider => '검색 서비스 추가';

  @override
  String get searchServicesPageSearchProviders => '검색 서비스 목록';

  @override
  String get searchServicesPageGeneralOptions => '일반 옵션';

  @override
  String get searchServicesPageAutoTestTitle => '실행 시 연결 자동 테스트';

  @override
  String get searchServicesPageWebFetchSection => '웹 페이지 읽기';

  @override
  String get searchServicesPageWebFetchModeTitle => '페이지 읽기 방식';

  @override
  String get searchServicesPageWebFetchFollow => '검색 서비스 따르기';

  @override
  String searchServicesPageWebFetchFollowValue(String name) {
    return '검색 따르기 · $name';
  }

  @override
  String searchServicesPageWebFetchFollowSubtitle(String name) {
    return '현재: $name';
  }

  @override
  String get searchServicesPageWebFetchLocal => '로컬';

  @override
  String get searchServicesPageWebFetchLocalSubtitle =>
      '무료입니다. 이 기기에서 페이지를 직접 요청합니다.';

  @override
  String get searchServicesPageWebFetchProviderSubtitle =>
      '이 서비스의 API 키와 한도를 사용합니다';

  @override
  String get searchServicesPageWebFetchOff => '꺼짐';

  @override
  String get searchServicesPageWebFetchOffSubtitle => '페이지를 읽지 않고 검색만 합니다';

  @override
  String get searchServicesPageWebFetchFooter =>
      '웹 검색이 켜져 있으면 모델이 페이지 전체 내용도 읽을 수 있습니다. 검색 서비스가 페이지를 읽을 수 없으면 로컬 읽기로 전환되며, 로컬 읽기는 JavaScript가 필요하거나 봇을 차단하는 페이지를 처리할 수 없습니다.';

  @override
  String get searchServicesPageWebFetchSupported => '웹 페이지 읽기 지원';

  @override
  String get searchServicesPageMaxResults => '최대 결과 수';

  @override
  String get searchServicesPageTimeoutSeconds => '제한 시간(초)';

  @override
  String get searchServicesPageAtLeastOneServiceRequired =>
      '검색 서비스가 하나 이상 있어야 합니다';

  @override
  String get searchServicesPageTestingStatus => '테스트 중…';

  @override
  String get searchServicesPageConnectedStatus => '연결됨';

  @override
  String get searchServicesPageFailedStatus => '실패';

  @override
  String get searchServicesPageNotTestedStatus => '테스트되지 않음';

  @override
  String get searchServicesPageEditServiceTooltip => '서비스 편집';

  @override
  String get searchServicesPageTestConnectionTooltip => '연결 테스트';

  @override
  String get searchServicesPageDeleteServiceTooltip => '서비스 삭제';

  @override
  String get searchServicesPageConfiguredStatus => '구성됨';

  @override
  String get miniMapTitle => '미니맵';

  @override
  String get miniMapTooltip => '미니맵';

  @override
  String get miniMapScrollToBottomTooltip => '맨 아래로 스크롤';

  @override
  String miniMapSearchMatchCount(int count) {
    return '$count개';
  }

  @override
  String get miniMapSearchNoResults => '일치하는 메시지가 없습니다';

  @override
  String get searchServicesPageApiKeyRequiredStatus => 'API 키 필요';

  @override
  String get searchServicesPageUrlRequiredStatus => 'URL 필요';

  @override
  String get searchServicesAddDialogTitle => '검색 서비스 추가';

  @override
  String get searchServicesAddDialogServiceType => '서비스 유형';

  @override
  String get searchServicesAddDialogBingLocal => '로컬';

  @override
  String get searchServicesAddDialogCancel => '취소';

  @override
  String get searchServicesAddDialogAdd => '추가';

  @override
  String get searchServicesAddDialogApiKeyRequired => 'API 키를 입력하세요';

  @override
  String get searchServicesFieldCustomUrlOptional => '사용자 지정 URL(선택 사항)';

  @override
  String get searchServicesDialogApiKey => 'API 키';

  @override
  String get searchServicesDialogApiKeyOptional => 'API 키(선택 사항)';

  @override
  String get searchServicesDialogModel => '모델';

  @override
  String get searchServicesDialogSystemPrompt => '시스템 프롬프트';

  @override
  String get searchServicesAddDialogInstanceUrl => '인스턴스 URL';

  @override
  String get searchServicesAddDialogUrlRequired => '유효한 URL을 입력하세요';

  @override
  String get searchServicesAddDialogEnginesOptional => '검색 엔진(선택 사항)';

  @override
  String get searchServicesAddDialogLanguageOptional => '언어(선택 사항)';

  @override
  String get searchServicesAddDialogUsernameOptional => '사용자 이름(선택 사항)';

  @override
  String get searchServicesAddDialogPasswordOptional => '비밀번호(선택 사항)';

  @override
  String get searchServicesAddDialogRegionOptional => '지역(선택 사항, 기본값: us-en)';

  @override
  String get searchServicesEditDialogEdit => '편집';

  @override
  String get searchServicesEditDialogCancel => '취소';

  @override
  String get searchServicesEditDialogSave => '저장';

  @override
  String get searchServicesEditDialogBingLocalNoConfig =>
      'Bing 로컬 검색은 구성이 필요하지 않습니다.';

  @override
  String get searchServicesEditDialogApiKeyRequired => 'API 키를 입력하세요';

  @override
  String get searchServicesEditDialogInstanceUrl => '인스턴스 URL';

  @override
  String get searchServicesEditDialogUrlRequired => 'URL을 입력하세요';

  @override
  String get searchServicesEditDialogEnginesOptional => '검색 엔진(선택 사항)';

  @override
  String get searchServicesEditDialogLanguageOptional => '언어(선택 사항)';

  @override
  String get searchServicesEditDialogUsernameOptional => '사용자 이름(선택 사항)';

  @override
  String get searchServicesEditDialogPasswordOptional => '비밀번호(선택 사항)';

  @override
  String get searchServicesEditDialogRegionOptional => '지역(선택 사항, 기본값: us-en)';

  @override
  String get searchServiceEditorProviderTypeTitle => '검색 제공업체';

  @override
  String get searchServiceEditorConfigurationTitle => '구성';

  @override
  String get searchServiceEditorNoConfiguration => '이 제공업체는 추가 구성이 필요하지 않습니다.';

  @override
  String get searchServiceEditorMultiKeyTitle => '다중 키 순환';

  @override
  String get searchServiceEditorMultiKeyNone => '구성되지 않음';

  @override
  String get searchApiKeysPageDescription =>
      '목록 순서대로 키를 순환하여 사용하며, 첫 번째 키가 기본 키입니다. 제공업체의 요청 한도에 걸리지 않도록 사용량은 확인하지 않습니다.';

  @override
  String get searchApiKeysPagePrimaryBadge => '기본';

  @override
  String get searchApiKeysPageBatchHint => '키 붙여넣기(여러 개는 한 줄에 하나씩 또는 쉼표로 구분)';

  @override
  String searchApiKeysPageBatchResult(String added, String skipped) {
    return '$added개 추가, 중복 $skipped개 건너뜀';
  }

  @override
  String get searchApiKeysPageAdd => '추가';

  @override
  String get searchApiKeysPageEmpty => '아직 구성된 키가 없습니다.';

  @override
  String searchServiceEditorMultiKeyCount(String count) {
    return '키 $count개';
  }

  @override
  String get searchServiceEditorUsageTitle => '계정 사용량';

  @override
  String get searchServiceEditorUsageNotQueried => '아직 사용량을 확인하지 않았습니다.';

  @override
  String get searchServiceEditorUsageQuery => '사용량 확인';

  @override
  String get searchServiceEditorUsageQuerying => '확인 중…';

  @override
  String searchServiceEditorUsageRemaining(String remaining) {
    return '크레딧 $remaining 남음';
  }

  @override
  String searchServiceEditorUsageBalance(String balance) {
    return '잔액: $balance';
  }

  @override
  String searchServiceEditorUsageUsed(String used, String limit) {
    return '크레딧 $limit 중 $used 사용됨';
  }

  @override
  String searchServiceEditorUsageFailed(String message) {
    return '사용량을 확인하지 못했습니다: $message';
  }

  @override
  String get searchServiceEditorTestTitle => '검색 테스트';

  @override
  String get searchServiceEditorTestQueryHint => '검색어 입력';

  @override
  String get searchServiceEditorTestRun => '검색 테스트 실행';

  @override
  String get searchServiceEditorTestRunning => '검색 중…';

  @override
  String get searchServiceEditorTestNoResults => '제공업체에서 반환한 결과가 없습니다.';

  @override
  String searchServiceEditorTestFailed(String message) {
    return '검색 실패: $message';
  }

  @override
  String get searchServiceEditorTestModeSearch => '검색';

  @override
  String get searchServiceEditorTestModeFetch => '페이지 읽기';

  @override
  String get searchServiceEditorTestUrlHint => 'URL 입력';

  @override
  String get searchServiceEditorTestFetchRun => '페이지 읽기 테스트 실행';

  @override
  String get searchServiceEditorTestFetchRunning => '읽는 중…';

  @override
  String searchServiceEditorTestFetchFailed(String message) {
    return '페이지 읽기 실패: $message';
  }

  @override
  String searchServiceEditorTestFetchStats(String characters, String seconds) {
    return '$characters자 · $seconds초';
  }

  @override
  String get searchServiceEditorResultOpenTooltip => '결과 열기';

  @override
  String get searchServiceEditorDeleteTooltip => '검색 서비스 삭제';

  @override
  String get searchServiceEditorDeleteTitle => '검색 서비스를 삭제하시겠습니까?';

  @override
  String searchServiceEditorDeleteMessage(String provider) {
    return '$provider을(를) 삭제하시겠습니까? 이 작업은 되돌릴 수 없습니다.';
  }

  @override
  String get searchServiceEditorDeleteConfirm => '삭제';

  @override
  String get searchServiceEditorDiscardTitle => '변경 사항을 삭제하시겠습니까?';

  @override
  String get searchServiceEditorDiscardMessage => '저장하지 않은 검색 서비스 설정이 사라집니다.';

  @override
  String get searchServiceEditorKeepEditing => '계속 편집';

  @override
  String get searchServiceEditorDiscard => '삭제';

  @override
  String get searchSettingsSheetTitle => '검색 설정';

  @override
  String get searchSettingsSheetBuiltinSearchTitle => '모델 내장 검색';

  @override
  String get searchSettingsSheetBuiltinSearchDescription => '모델 내장 검색을 활성화합니다';

  @override
  String get searchSettingsSheetClaudeDynamicSearchTitle => '동적 필터링';

  @override
  String get searchSettingsSheetClaudeDynamicSearchDescription =>
      '결과를 필터링하여 토큰을 절약합니다';

  @override
  String get searchSettingsSheetWebSearchTitle => '웹 검색';

  @override
  String get searchSettingsSheetWebSearchDescription => '채팅에서 웹 검색을 활성화합니다';

  @override
  String get searchSettingsSheetOpenSearchServicesTooltip => '검색 서비스 열기';

  @override
  String get searchSettingsSheetNoServicesMessage =>
      '서비스가 없습니다. ‘검색 서비스’에서 추가하세요.';

  @override
  String get aboutPageEasterEggMessage => '둘러봐 주셔서 감사합니다! \n (아직 이스터에그는 없습니다)';

  @override
  String get aboutPageEasterEggButton => '좋습니다!';

  @override
  String get aboutPageKelivoSearchUnlocked => '이름 없는 문이 살짝 열렸습니다. 설정에서 찾아보세요.';

  @override
  String get aboutPageKelivoSearchAlreadyUnlocked => '이미 지나온 문입니다.';

  @override
  String get aboutPageAppName => 'Kelivo';

  @override
  String get aboutPageAppDescription => '오픈소스 AI 어시스턴트';

  @override
  String get aboutPageNoQQGroup => '아직 QQ 그룹이 없습니다';

  @override
  String get aboutPageVersion => '버전';

  @override
  String aboutPageVersionDetail(String version, String buildNumber) {
    return '$version / $buildNumber';
  }

  @override
  String get aboutPageSystem => '시스템';

  @override
  String get aboutPageLoadingPlaceholder => '…';

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
    return '기타($os)';
  }

  @override
  String get aboutPageWebsite => '웹사이트';

  @override
  String get aboutPageGithub => 'GitHub';

  @override
  String get aboutPageLicense => '라이선스';

  @override
  String get aboutPageJoinQQGroup => 'QQ 그룹 참여';

  @override
  String get aboutPageQQGroupOne => 'Kelivo 그룹 1';

  @override
  String get aboutPageQQGroupTwo => 'Kelivo 그룹 2';

  @override
  String get aboutPageQQGroupThree => 'Kelivo 그룹 3';

  @override
  String get aboutPageJoinDiscord => 'Discord 커뮤니티 참여';

  @override
  String get displaySettingsPageShowUserAvatarTitle => '사용자 아바타 표시';

  @override
  String get displaySettingsPageShowUserAvatarSubtitle =>
      '채팅 메시지에 사용자 아바타를 표시합니다';

  @override
  String get displaySettingsPageShowUserNameTimestampTitle =>
      '사용자 이름 및 타임스탬프 표시';

  @override
  String get displaySettingsPageShowUserNameTimestampSubtitle =>
      '채팅 메시지에 사용자 이름과 그 아래의 타임스탬프를 표시합니다';

  @override
  String get displaySettingsPageShowUserNameTitle => '사용자 이름 표시';

  @override
  String get displaySettingsPageShowUserTimestampTitle => '사용자 타임스탬프 표시';

  @override
  String get displaySettingsPageShowUserMessageActionsTitle => '사용자 메시지 작업 표시';

  @override
  String get displaySettingsPageShowUserMessageActionsSubtitle =>
      '내 메시지 아래에 복사, 다시 보내기, 더보기 버튼을 표시합니다';

  @override
  String get displaySettingsPageShowModelNameTimestampTitle =>
      '모델 이름 및 타임스탬프 표시';

  @override
  String get displaySettingsPageShowModelNameTimestampSubtitle =>
      '채팅 메시지에 모델 이름과 그 아래의 타임스탬프를 표시합니다';

  @override
  String get displaySettingsPageShowModelNameTitle => '모델 이름 표시';

  @override
  String get displaySettingsPageShowModelTimestampTitle => '모델 타임스탬프 표시';

  @override
  String get displaySettingsPageShowProviderInChatMessageTitle =>
      '모델 이름 뒤에 제공업체 표시';

  @override
  String get displaySettingsPageShowProviderInChatMessageSubtitle =>
      '채팅 메시지에서 모델 이름 뒤에 제공업체 이름을 표시합니다(예: 모델 | 제공업체)';

  @override
  String get displaySettingsPageChatModelIconTitle => '모델 아이콘 표시';

  @override
  String get displaySettingsPageChatModelIconSubtitle =>
      '채팅 메시지에 모델 아이콘을 표시합니다';

  @override
  String get displaySettingsPageShowTokenStatsTitle => '토큰 및 컨텍스트 통계 표시';

  @override
  String get displaySettingsPageShowTotalTokensTitle => '턴 전체의 토큰 표시';

  @override
  String get displaySettingsPageShowTotalTokensSubtitle =>
      '한 응답에 포함된 모든 API 요청의 사용량을 합산합니다. 끄면 마지막 요청의 사용량만 표시합니다. 통계에는 항상 모든 요청이 포함됩니다.';

  @override
  String get displaySettingsPageShowTokenStatsSubtitle =>
      '토큰 사용량과 메시지 수를 표시합니다';

  @override
  String get displaySettingsPageShowThinkingCardsTitle => '생각 카드 표시';

  @override
  String get displaySettingsPageShowThinkingCardsSubtitle =>
      '끄면 채팅에 생각 카드를 표시하지 않습니다.';

  @override
  String get displaySettingsPageShowToolCardsTitle => '도구 카드 표시';

  @override
  String get displaySettingsPageShowToolCardsSubtitle =>
      '끄면 채팅에 도구 카드를 표시하지 않습니다.';

  @override
  String get displaySettingsShowReasoningLevelBadge => '버튼에 추론 수준 표시';

  @override
  String get displaySettingsShowReasoningLevelBadgeSubtitle =>
      '입력창의 추론 아이콘 옆에 현재 수준을 표시합니다';

  @override
  String get displaySettingsPageAutoCollapseThinkingTitle => '생각 자동 접기';

  @override
  String get displaySettingsPageAutoCollapseThinkingSubtitle =>
      '생각이 끝나면 자동으로 접습니다';

  @override
  String get displaySettingsPageCollapseThinkingStepsTitle => '생각 단계 접기';

  @override
  String get displaySettingsPageCollapseThinkingStepsSubtitle =>
      '펼치기 전까지 최근 단계만 표시합니다';

  @override
  String get displaySettingsPageShowToolResultSummaryTitle => '도구 결과 요약 표시';

  @override
  String get displaySettingsPageInsertSuggestionOnlyTitle =>
      '제안을 보내지 않고 입력창에 삽입';

  @override
  String get displaySettingsPageShowToolResultSummarySubtitle =>
      '도구 단계 아래에 요약 텍스트를 표시합니다';

  @override
  String get displaySettingsPageHideToolResultImagesTitle => '도구 결과의 이미지 숨기기';

  @override
  String get displaySettingsPageRegenerateDeleteTrailingMessagesTitle =>
      '다시 생성할 때 아래 메시지 삭제';

  @override
  String get displaySettingsPageShowRegenerateConfirmDialogTitle =>
      '다시 생성하기 전에 확인';

  @override
  String get displaySettingsPageForkKeepMessageVersionsTitle =>
      '분기할 때 메시지 버전 유지';

  @override
  String get displaySettingsPageEditAssistantKeepThinkingToolCardsTitle =>
      '응답 편집 시 생각 및 도구 카드 유지';

  @override
  String get displaySettingsPageEditAssistantKeepThinkingToolCardsSubtitle =>
      '끄면 편집한 버전에는 응답 텍스트만 남습니다. 이전 버전으로 전환하면 기존 생각 및 도구 카드를 계속 볼 수 있습니다.';

  @override
  String chainOfThoughtExpandSteps(Object count) {
    return '$count단계 더 보기';
  }

  @override
  String get chainOfThoughtCollapse => '접기';

  @override
  String get displaySettingsPageShowChatListDateTitle => '대화 목록 날짜 표시';

  @override
  String get displaySettingsPageShowChatListDateSubtitle =>
      '대화 목록에 날짜 그룹 레이블을 표시합니다';

  @override
  String get displaySettingsPageEnableImageCropperTitle => '이미지 자르기 활성화';

  @override
  String get displaySettingsPageEnableImageCropperSubtitle =>
      '갤러리나 카메라에서 이미지를 선택한 후 자를 수 있습니다';

  @override
  String get displaySettingsPageKeepSidebarOpenOnAssistantTapTitle =>
      '어시스턴트 선택 시 사이드바 열어 두기';

  @override
  String get displaySettingsPageKeepSidebarOpenOnTopicTapTitle =>
      '대화 선택 시 사이드바 열어 두기';

  @override
  String get displaySettingsPageKeepAssistantListExpandedOnSidebarCloseTitle =>
      '사이드바를 닫아도 어시스턴트 목록 펼쳐 두기';

  @override
  String get displaySettingsPageShowUpdatesTitle => '업데이트 알림 표시';

  @override
  String get displaySettingsPageShowUpdatesSubtitle => '앱 업데이트 알림을 표시합니다';

  @override
  String get displaySettingsPageKeepScreenOnDuringGenerationTitle =>
      '생성 중 화면 켜짐 유지';

  @override
  String get displaySettingsPageKeepScreenOnDuringGenerationSubtitle =>
      '화면이 잠겨 생성이 중단되지 않게 합니다. 배터리 사용량이 늘어납니다.';

  @override
  String get displaySettingsPageMessageNavButtonsTitle => '메시지 이동 버튼';

  @override
  String get displaySettingsPageMessageNavButtonsSubtitle =>
      '빠른 이동 버튼을 표시할 시점을 선택합니다';

  @override
  String get displaySettingsPageMessageNavButtonsModeAlways => '항상 표시';

  @override
  String get displaySettingsPageMessageNavButtonsModeScroll => '스크롤할 때 표시';

  @override
  String get displaySettingsPageMessageNavButtonsModeHover => '마우스를 올리면 표시';

  @override
  String get displaySettingsPageMessageNavButtonsModeScrollAndHover =>
      '스크롤하거나 마우스를 올리면 표시';

  @override
  String get displaySettingsPageMessageNavButtonsModeNever => '표시 안 함';

  @override
  String get displaySettingsPageUseNewAssistantAvatarUxTitle =>
      '채팅 제목 표시줄에 어시스턴트 아바타 표시';

  @override
  String get displaySettingsPageHapticsOnSidebarTitle => '사이드바 햅틱';

  @override
  String get displaySettingsPageHapticsOnSidebarSubtitle =>
      '사이드바를 열거나 닫을 때 햅틱 피드백을 활성화합니다';

  @override
  String get displaySettingsPageHapticsGlobalTitle => '전역 햅틱';

  @override
  String get displaySettingsPageHapticsIosSwitchTitle => '스위치 햅틱';

  @override
  String get displaySettingsPageHapticsOnListItemTapTitle => '목록 항목 햅틱';

  @override
  String get displaySettingsPageHapticsOnCardTapTitle => '카드 햅틱';

  @override
  String get displaySettingsPageHapticsOnGenerateTitle => '생성 중 햅틱';

  @override
  String get displaySettingsPageHapticsOnGenerateSubtitle =>
      '생성 중에 햅틱 피드백을 활성화합니다';

  @override
  String get displaySettingsPageNewChatAfterDeleteTitle => '대화 삭제 후 새 채팅';

  @override
  String get displaySettingsPageNewChatOnAssistantSwitchTitle =>
      '어시스턴트 전환 시 새 채팅';

  @override
  String get displaySettingsPageNewChatOnLaunchTitle => '실행 시 새 채팅';

  @override
  String get displaySettingsPageEnterToSendTitle => 'Enter 키로 보내기';

  @override
  String get displaySettingsPageLongPasteAsFileTitle => '긴 텍스트를 파일로 붙여넣기';

  @override
  String get displaySettingsPageLongPasteAsFileThresholdTitle => '변환 기준';

  @override
  String get displaySettingsPageLongPasteAsFileThresholdUnit => '자';

  @override
  String get displaySettingsPageSendShortcutTitle => '보내기 단축키';

  @override
  String get displaySettingsPageSendShortcutEnter => 'Enter';

  @override
  String get displaySettingsPageSendShortcutCtrlEnter => 'Ctrl/Cmd + Enter';

  @override
  String get displaySettingsPageAutoSwitchTopicsTitle => '대화 탭으로 자동 전환';

  @override
  String get desktopDisplaySettingsTopicPositionTitle => '대화 목록 위치';

  @override
  String get desktopDisplaySettingsTopicPositionLeft => '왼쪽';

  @override
  String get desktopDisplaySettingsTopicPositionRight => '오른쪽';

  @override
  String get displaySettingsPageNewChatOnLaunchSubtitle =>
      '앱을 실행하면 자동으로 새 채팅을 만듭니다';

  @override
  String get displaySettingsPageChatFontSizeTitle => '채팅 글꼴 크기';

  @override
  String get displaySettingsPageAutoScrollEnableTitle => '맨 아래로 자동 스크롤';

  @override
  String get displaySettingsPageAutoScrollIdleTitle => '자동 스크롤 복귀 지연 시간';

  @override
  String get displaySettingsPageAutoScrollIdleSubtitle =>
      '직접 스크롤한 뒤 맨 아래로 돌아가기까지 기다리는 시간입니다';

  @override
  String get displaySettingsPageAutoScrollDisabledLabel => '꺼짐';

  @override
  String get displaySettingsPageChatFontSampleText => '채팅 텍스트 예시입니다';

  @override
  String get displaySettingsPageChatBackgroundMaskTitle => '채팅 배경 오버레이 불투명도';

  @override
  String get displaySettingsPageChatInputBackgroundOpacityTitle =>
      '입력창 배경 불투명도';

  @override
  String get displaySettingsPageThemeSettingsTitle => '테마 설정';

  @override
  String get displaySettingsPageThemeColorTitle => '테마 색상';

  @override
  String get desktopSettingsFontsTitle => '글꼴';

  @override
  String get linuxHideTitleBarTitle => '시스템 제목 표시줄 숨기기';

  @override
  String get linuxHideTitleBarDescription =>
      '창 버튼도 함께 숨깁니다. 창을 이동하거나 크기를 조절하거나 닫으려면 창 관리자를 사용하세요.';

  @override
  String get linuxHideTitleBarError => '제목 표시줄을 변경할 수 없습니다. 다시 시도하세요.';

  @override
  String get displaySettingsPageTrayTitle => '시스템 트레이';

  @override
  String get displaySettingsPageTrayShowTrayTitle => '트레이 아이콘 표시';

  @override
  String get displaySettingsPageTrayMinimizeOnCloseTitle => '닫을 때 트레이로 최소화';

  @override
  String get desktopFontAppLabel => '앱 글꼴';

  @override
  String get desktopFontCodeLabel => '코드 글꼴';

  @override
  String get desktopFontFamilySystemDefault => '시스템 기본값';

  @override
  String get desktopFontFamilyMonospaceDefault => '고정폭';

  @override
  String get desktopFontFilterHint => '글꼴 필터링…';

  @override
  String get displaySettingsPageAppFontTitle => '앱 글꼴';

  @override
  String get displaySettingsPageCodeFontTitle => '코드 글꼴';

  @override
  String get fontPickerChooseLocalFile => '로컬 파일 선택';

  @override
  String get desktopFontLoading => '글꼴 불러오는 중…';

  @override
  String get displaySettingsPageFontLocalFileLabel => '로컬 파일';

  @override
  String get displaySettingsPageFontResetLabel => '글꼴 설정 재설정';

  @override
  String get displaySettingsPageOtherSettingsTitle => '기타 설정';

  @override
  String get themeSettingsPageDynamicColorSection => '동적 색상';

  @override
  String get themeSettingsPageUseDynamicColorTitle => '시스템 동적 색상';

  @override
  String get themeSettingsPageUseDynamicColorSubtitle =>
      '시스템 팔레트를 따릅니다(Android 12+)';

  @override
  String get themeSettingsPageUsePureBackgroundTitle => '단색 배경';

  @override
  String get themeSettingsPageUsePureBackgroundSubtitle =>
      '말풍선과 강조 색상만 테마를 따릅니다.';

  @override
  String get themeAdvancedSettingsPageTitle => '테마 고급 설정';

  @override
  String get themeAdvancedSettingsPageUseLayeredSurfacesTitle => '계층형 표면(실험적)';

  @override
  String get themeAdvancedSettingsPageUseLayeredSurfacesSubtitle =>
      '페이지는 더 어둡게, 카드는 더 밝게 표시하며 둘 다 테마 색조를 유지합니다. 끄면 이전 모습으로 복원됩니다.';

  @override
  String get themeAdvancedSettingsPageUseLayeredSheetTilesTitle => '계층형 시트 타일';

  @override
  String get themeAdvancedSettingsPageUseLayeredSheetTilesSubtitle =>
      '기본적으로 타일은 시트 배경과 같은 색입니다.';

  @override
  String get themeSettingsPageColorPalettesSection => '색상 팔레트';

  @override
  String get themeSettingsPageCustomPaletteName => '사용자 지정';

  @override
  String get themeSettingsPageCustomColorReset => '재설정';

  @override
  String get themeSettingsPageCustomThemesSection => '사용자 지정 테마';

  @override
  String get customThemeNewTheme => '새 테마';

  @override
  String get customThemeEditTheme => '테마 편집';

  @override
  String get customThemeImportTheme => '테마 가져오기';

  @override
  String get customThemeNameLabel => '테마 이름';

  @override
  String get customThemePrimaryColor => '기본 색상';

  @override
  String get customThemeSecondaryColor => '보조 색상';

  @override
  String get customThemeTertiaryColor => '3차 색상';

  @override
  String get customThemeColorAuto => '자동';

  @override
  String get customThemeSave => '저장';

  @override
  String get customThemeCancel => '취소';

  @override
  String get customThemeDelete => '삭제';

  @override
  String get customThemeDeleteConfirm => '이 테마를 삭제하시겠습니까?';

  @override
  String get customThemeCopied => '클립보드에 테마 JSON 복사됨';

  @override
  String get customThemeCopyAction => '복사';

  @override
  String get customThemeImportHint => '여기에 테마 JSON 붙여넣기';

  @override
  String get customThemeImportInvalid => '잘못된 테마 JSON';

  @override
  String get customThemeHexLabel => 'Hex';

  @override
  String get ttsServicesPageBackButton => '뒤로';

  @override
  String get ttsServicesPageTitle => '음성 서비스';

  @override
  String get ttsServicesSectionTitle => '텍스트 음성 변환';

  @override
  String get ttsServicesPageSettingsTooltip => 'TTS 설정';

  @override
  String get ttsServicesPageAddTooltip => '추가';

  @override
  String get asrServicesSectionTitle => '음성 인식';

  @override
  String get asrServicesSectionDescription =>
      '기기 내, 시스템 또는 클라우드 서비스로 음성을 텍스트로 변환합니다.';

  @override
  String get asrServicesAddTooltip => '음성 인식 서비스 추가';

  @override
  String get asrServicesEmptyTitle => '음성 인식 서비스 없음';

  @override
  String get asrServicesEmptySubtitle => '채팅 입력창에 마이크를 표시하려면 서비스를 추가하세요.';

  @override
  String get asrServicesOnDeviceGroup => '기기 내';

  @override
  String get asrServicesCloudGroup => '클라우드';

  @override
  String get asrServicesSystemTitle => '시스템';

  @override
  String get asrServicesSystemSubtitle => '기기에 내장된 음성 인식 기능을 사용합니다';

  @override
  String get asrServicesLocalTitle => '오프라인 모델';

  @override
  String get asrServicesLocalSubtitle => '다운로드 후 이 기기에서 오프라인으로 실행됩니다';

  @override
  String get asrServicesOpenAiTitle => 'OpenAI Realtime';

  @override
  String get asrServicesOpenAiSubtitle => '저지연 스트리밍 텍스트 변환';

  @override
  String get asrServicesGroqSubtitle => 'Whisper 구간별 텍스트 변환';

  @override
  String get asrServicesMistralSubtitle => 'Voxtral 구간별 텍스트 변환';

  @override
  String get asrServicesDashScopeTitle => 'DashScope';

  @override
  String get asrServicesDashScopeSubtitle => 'Qwen 실시간 텍스트 변환';

  @override
  String get asrServicesVolcengineTitle => 'Volcengine';

  @override
  String get asrServicesVolcengineSubtitle => 'Doubao 스트리밍 텍스트 변환';

  @override
  String get asrServicesMimoTitle => 'MiMo';

  @override
  String get asrServicesMimoSubtitle => '클라우드 구간별 텍스트 변환';

  @override
  String get asrServicesStepTitle => 'Step';

  @override
  String get asrServicesStepSubtitle => 'Step Audio 구간별 텍스트 변환';

  @override
  String get asrServicesAddTitle => '음성 인식 서비스 추가';

  @override
  String get asrServicesEditTitle => '음성 인식 서비스 편집';

  @override
  String get asrServicesSelectedLabel => '선택됨';

  @override
  String get asrServicesUnavailableLabel => '사용할 수 없음';

  @override
  String get asrServicesEditAction => '편집';

  @override
  String get asrServicesDeleteAction => '삭제';

  @override
  String get asrServicesCancelAction => '취소';

  @override
  String get asrServicesAddAction => '추가';

  @override
  String get asrServicesSaveAction => '저장';

  @override
  String get asrServicesNameLabel => '이름';

  @override
  String get asrServicesApiKeyLabel => 'API 키';

  @override
  String get asrServicesEndpointLabel => '엔드포인트';

  @override
  String get asrServicesModelLabel => '모델';

  @override
  String get asrServicesResourceIdLabel => '리소스 ID';

  @override
  String get asrServicesLanguageLabel => '언어';

  @override
  String get asrServicesAutomaticLabel => '자동';

  @override
  String get asrServicesApiKeyRequired => '이 서비스를 사용하려면 API 키를 입력하세요.';

  @override
  String get asrServicesChooseModelTitle => '모델';

  @override
  String get asrServicesModelDownloadAction => '다운로드';

  @override
  String get asrServicesModelUseAction => '모델 사용';

  @override
  String get asrServicesModelDeleteAction => '다운로드 제거';

  @override
  String get asrServicesModelDownloadedLabel => '다운로드됨';

  @override
  String get asrServicesModelDownloadingLabel => '다운로드 중…';

  @override
  String get asrServicesModelNotDownloadedLabel => '다운로드되지 않음';

  @override
  String asrServicesDownloadFailed(String error) {
    return '모델 다운로드 실패: $error';
  }

  @override
  String get asrServicesSystemChecking => '확인 중…';

  @override
  String get asrServicesSystemAvailable => '사용 가능';

  @override
  String get asrServicesSystemCheckFailed => '이 기기에서는 시스템 음성 인식을 사용할 수 없습니다.';

  @override
  String get asrServicesMicrophonePermissionDenied => '마이크 권한이 허용되지 않았습니다.';

  @override
  String get asrServicesNoSpeechDetected => '음성이 감지되지 않았습니다.';

  @override
  String asrServicesRecognitionFailed(String error) {
    return '음성 인식 실패: $error';
  }

  @override
  String get ttsServicesPageAddNotImplemented => 'TTS 서비스 추가 기능이 구현되지 않았습니다';

  @override
  String get ttsServicesPageSystemTtsTitle => '시스템 TTS';

  @override
  String get ttsServicesPageSystemTtsAvailableSubtitle => '시스템 내장 TTS를 사용합니다';

  @override
  String ttsServicesPageSystemTtsUnavailableSubtitle(String error) {
    return '사용할 수 없음: $error';
  }

  @override
  String get ttsServicesPageSystemTtsUnavailableNotInitialized => '초기화되지 않음';

  @override
  String get ttsServicesPageTestSpeechText => '안녕하세요, 테스트 음성입니다.';

  @override
  String get ttsServicesPageConfigureTooltip => '구성';

  @override
  String get ttsServicesPageTestVoiceTooltip => '음성 테스트';

  @override
  String get ttsServicesPageStopTooltip => '중지';

  @override
  String get ttsServicesPageDeleteTooltip => '삭제';

  @override
  String get ttsServicesPageSystemTtsSettingsTitle => '시스템 TTS 설정';

  @override
  String get ttsServicesPageEngineLabel => '엔진';

  @override
  String get ttsServicesPageAutoLabel => '자동';

  @override
  String get ttsServicesPageLanguageLabel => '언어';

  @override
  String get ttsServicesPageSpeechRateLabel => '말하기 속도';

  @override
  String get ttsServicesPagePitchLabel => '음높이';

  @override
  String get ttsServicesPageSettingsSavedMessage => '설정이 저장되었습니다.';

  @override
  String get ttsServicesPageDoneButton => '완료';

  @override
  String get ttsServicesPageNetworkSectionTitle => '네트워크 TTS';

  @override
  String get ttsServicesPageNoNetworkServices => 'TTS 서비스가 없습니다.';

  @override
  String get ttsServicesDialogAddTitle => 'TTS 서비스 추가';

  @override
  String get ttsServicesDialogEditTitle => 'TTS 서비스 편집';

  @override
  String get ttsServicesDialogProviderType => '제공업체';

  @override
  String get ttsServicesDialogCancelButton => '취소';

  @override
  String get ttsServicesDialogAddButton => '추가';

  @override
  String get ttsServicesDialogSaveButton => '저장';

  @override
  String get ttsServicesFieldNameLabel => '이름';

  @override
  String get ttsServicesFieldApiKeyLabel => 'API 키';

  @override
  String get ttsServicesFieldBaseUrlLabel => 'API 기본 URL';

  @override
  String get ttsServicesFieldModelLabel => '모델';

  @override
  String get ttsServicesFieldVoiceLabel => '음성';

  @override
  String get ttsServicesFieldVoiceIdLabel => '음성 ID';

  @override
  String get ttsServicesFieldEmotionLabel => '감정';

  @override
  String get ttsServicesFieldSpeedLabel => '속도';

  @override
  String get ttsServicesFieldLanguageTypeLabel => '언어 유형';

  @override
  String get ttsServicesFieldLanguageLabel => '언어';

  @override
  String get ttsServicesFieldWorkspaceIdLabel => '워크스페이스 ID';

  @override
  String get ttsServicesFieldRegionLabel => '리전';

  @override
  String get ttsServicesFieldFormatLabel => '오디오 형식';

  @override
  String get ttsServicesFieldOutputFormatLabel => '출력 형식';

  @override
  String get ttsServicesFieldSampleRateLabel => '샘플 레이트';

  @override
  String get ttsServicesFieldVolumeLabel => '볼륨';

  @override
  String get ttsServicesFieldPitchLabel => '음높이';

  @override
  String get ttsServicesFieldLanguageBoostLabel => '언어 강화';

  @override
  String get ttsServicesFieldBitrateLabel => '비트레이트';

  @override
  String get ttsServicesFieldChannelLabel => '채널';

  @override
  String get ttsServicesFieldSubtitlesLabel => '자막 생성';

  @override
  String get ttsServicesFieldPronunciationDictionaryLabel => '발음 사전(한 줄에 하나씩)';

  @override
  String get ttsServicesFieldInstructionLabel => '스타일/음성 설명';

  @override
  String get ttsServicesFieldStreamingLabel => '스트리밍';

  @override
  String get ttsServicesFieldOptimizeTextPreviewLabel => '낭독 텍스트 최적화';

  @override
  String get ttsServicesFieldReferenceAudioLabel => '참조 오디오(WAV/MP3 data URI)';

  @override
  String get ttsServicesFieldChooseReferenceAudioButton => '참조 오디오 선택';

  @override
  String get ttsServicesFieldTemperatureLabel => '온도';

  @override
  String get ttsServicesFieldTopPLabel => 'Top P';

  @override
  String get ttsServicesFieldLatencyLabel => '지연 시간 모드';

  @override
  String get ttsServicesEmotionAutoLabel => '자동 매칭';

  @override
  String get ttsServicesValidationApiKeyRequired => 'API 키를 입력하세요';

  @override
  String get ttsServicesValidationReferenceIdRequired => '음성/참조 ID를 입력하세요';

  @override
  String get ttsServicesValidationInstructionRequired => '음성 설명을 입력하세요';

  @override
  String ttsServicesValidationSampleRate(String format, String rates) {
    return '$format 형식은 ${rates}Hz만 지원합니다.';
  }

  @override
  String get ttsServicesViewDetailsButton => '세부 정보 보기';

  @override
  String get ttsServicesDialogErrorTitle => '오류 세부 정보';

  @override
  String get ttsServicesCloseButton => '닫기';

  @override
  String get ttsSettingsPageTitle => 'TTS 설정';

  @override
  String get ttsSettingsPlaybackSection => '재생';

  @override
  String get ttsSettingsAutoPlayTitle => '어시스턴트 응답 자동 재생';

  @override
  String get ttsSettingsAutoPlayDescription =>
      '어시스턴트 응답이 끝나면 자동으로 TTS 재생을 시작합니다.';

  @override
  String get ttsSettingsCacheReplayTitle => '다시 재생할 때 오디오 재사용';

  @override
  String get ttsSettingsCacheReplayDescription =>
      '다시 재생할 때 네트워크 TTS로 이미 생성한 오디오를 사용하며, TTS 서비스에 새로 요청하지 않습니다.';

  @override
  String get ttsSettingsTextSelectionSection => '읽을 텍스트';

  @override
  String get ttsSettingsTextSelectionFallbackDescription =>
      '일치하는 텍스트가 없으면 응답 전체를 읽습니다.';

  @override
  String get ttsSettingsTextSelectionFullTextTitle => '전체 텍스트';

  @override
  String get ttsSettingsTextSelectionFullTextDescription =>
      '어시스턴트 응답 전체를 읽습니다.';

  @override
  String get ttsSettingsTextSelectionQuotedOnlyTitle => '따옴표 안 텍스트만';

  @override
  String get ttsSettingsTextSelectionQuotedOnlyDescription =>
      '“”, ‘’, \"\", \'\', 「」 또는 『』 안의 텍스트를 읽습니다.';

  @override
  String get ttsSettingsTextSelectionOutsideParenthesesTitle => '괄호 밖 텍스트만';

  @override
  String get ttsSettingsTextSelectionOutsideParenthesesDescription =>
      '() 및 （） 안의 텍스트를 건너뜁니다.';

  @override
  String get ttsSettingsTextSelectionItalicOnlyTitle => '기울임꼴 텍스트만';

  @override
  String get ttsSettingsTextSelectionItalicOnlyDescription =>
      'Markdown 또는 HTML 기울임꼴 텍스트를 읽습니다.';

  @override
  String get ttsSettingsTextSelectionNonItalicTitle => '기울임꼴이 아닌 텍스트만';

  @override
  String get ttsSettingsTextSelectionNonItalicDescription =>
      'Markdown 또는 HTML 기울임꼴 텍스트를 건너뜁니다.';

  @override
  String get ttsFloatingPlayerLabel => 'TTS 플레이어';

  @override
  String get ttsFloatingPauseTooltip => '일시 중지';

  @override
  String get ttsFloatingResumeTooltip => '재개';

  @override
  String get ttsFloatingReplayTooltip => '다시 재생';

  @override
  String get ttsFloatingRewind15Tooltip => '15초 뒤로';

  @override
  String get ttsFloatingForward15Tooltip => '15초 앞으로';

  @override
  String get ttsFloatingSpeedTooltip => '재생 속도';

  @override
  String get ttsFloatingCloseTooltip => '플레이어 닫기';

  @override
  String get ttsFloatingExpandTooltip => '재생 컨트롤 펼치기';

  @override
  String get ttsFloatingCollapseTooltip => '재생 컨트롤 접기';

  @override
  String get ttsFloatingSaveTooltip => '오디오 저장';

  @override
  String get ttsSaveDialogTitle => 'TTS 오디오 저장';

  @override
  String get ttsSaveSuccess => '오디오가 저장되었습니다.';

  @override
  String get ttsSaveNothing => '저장할 오디오가 없습니다.';

  @override
  String ttsSaveFailed(String message) {
    return '오디오를 저장하지 못했습니다: $message';
  }

  @override
  String imageViewerPageShareFailedOpenFile(String message) {
    return '공유할 수 없고 파일도 열지 못했습니다: $message';
  }

  @override
  String imageViewerPageShareFailed(String error) {
    return '공유 실패: $error';
  }

  @override
  String get imageViewerPageShareButton => '이미지 공유';

  @override
  String get imageViewerPageCloseButton => '미리보기 닫기';

  @override
  String get imageViewerPageSaveButton => '이미지 저장';

  @override
  String get imageViewerPageCopyButton => '이미지 복사';

  @override
  String get imageViewerPagePreviousButton => '이전 이미지';

  @override
  String get imageViewerPageNextButton => '다음 이미지';

  @override
  String get imageViewerPageZoomInButton => '확대';

  @override
  String get imageViewerPageZoomOutButton => '축소';

  @override
  String get imageViewerPageResetZoomButton => '확대/축소 재설정';

  @override
  String get imageViewerPageFlipHorizontalButton => '좌우 반전';

  @override
  String get imageViewerPageFlipVerticalButton => '상하 반전';

  @override
  String get imageViewerPageRotateLeftButton => '왼쪽으로 회전';

  @override
  String get imageViewerPageRotateRightButton => '오른쪽으로 회전';

  @override
  String imageViewerPageCounter(int index, int total) {
    return '$index/$total';
  }

  @override
  String imageViewerPageImageLabel(int index, int total) {
    return '$total개 중 $index번째 이미지';
  }

  @override
  String get imageViewerPageImageLoadFailed => '이미지를 불러올 수 없습니다';

  @override
  String get imageViewerPageSaveSuccess => '갤러리에 저장됨';

  @override
  String imageViewerPageSaveFailed(String error) {
    return '저장 실패: $error';
  }

  @override
  String get settingsShare => 'Kelivo - 오픈소스 AI 어시스턴트';

  @override
  String get searchProviderBingLocalDescription =>
      '웹 스크래핑으로 Bing 검색 결과를 불러옵니다. API 키가 필요 없지만 불안정할 수 있습니다.';

  @override
  String get searchProviderDuckDuckGoDescription =>
      '개인정보 보호에 중점을 둔 DDGS 기반 DuckDuckGo 검색입니다. API 키가 필요 없으며 지역을 선택할 수 있습니다.';

  @override
  String get searchProviderBraveDescription =>
      'Brave의 독립 검색 엔진입니다. 개인정보 보호에 중점을 두며 추적이나 프로파일링을 하지 않습니다.';

  @override
  String get searchProviderExaDescription =>
      '의미를 이해하는 신경망 검색입니다. 리서치나 특정 콘텐츠를 찾는 데 적합합니다.';

  @override
  String get searchProviderExaMcpDescription =>
      'MCP 기반 Exa 검색입니다. API 키 없이도 무료 한도 내에서 사용할 수 있습니다.';

  @override
  String get searchProviderLinkUpDescription =>
      '출처가 표시된 답변을 지원하는 검색 API입니다. 검색 결과와 AI가 생성한 요약을 모두 제공합니다.';

  @override
  String get searchProviderMetasoDescription =>
      'Metaso의 중국어 검색입니다. 중국어 콘텐츠에 최적화되어 있으며 AI 기능을 제공합니다.';

  @override
  String get searchProviderSearXNGDescription =>
      '개인정보를 보호하는 메타 검색 엔진입니다. 자체 호스팅 인스턴스가 필요하며 추적하지 않습니다.';

  @override
  String get searchProviderTavilyDescription =>
      'LLM에 최적화된 AI 검색 API입니다. 관련성 높은 고품질 결과를 제공합니다.';

  @override
  String get searchProviderZhipuDescription =>
      'Zhipu AI의 중국어 AI 검색입니다. 중국어 콘텐츠와 검색어에 최적화되어 있습니다.';

  @override
  String get searchProviderOllamaDescription =>
      'Ollama 웹 검색 API입니다. 최신 정보로 모델을 보강합니다.';

  @override
  String get searchProviderDeepSeekDescription =>
      'DeepSeek 공식 웹 검색 및 페이지 읽기 API입니다. DeepSeek API 키를 사용합니다.';

  @override
  String get searchProviderJinaDescription =>
      '임베딩, 리랭커, 웹 리더, 딥서치, 소형 언어 모델을 갖춘 AI 검색 인프라입니다. 다국어와 멀티모달을 지원합니다.';

  @override
  String get searchServiceNameBingLocal => 'Bing(로컬)';

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
      'Perplexity 검색 API입니다. 지역 및 도메인 필터를 지원하며 순위가 매겨진 웹 검색 결과를 제공합니다.';

  @override
  String get searchServiceNameBocha => 'Bocha';

  @override
  String get searchProviderBochaDescription =>
      'Bocha 웹 검색 API입니다. 정확한 웹 검색 결과를 제공하며, 필요하면 요약도 함께 받을 수 있습니다.';

  @override
  String get searchServiceNameDoubao => 'Doubao';

  @override
  String get searchProviderDoubaoDescription =>
      'Volcengine의 Doubao 웹 검색 API입니다.';

  @override
  String get searchServiceNameSerper => 'Serper';

  @override
  String get searchProviderSerperDescription =>
      'Serper Google 검색 API입니다. 빠른 웹 검색 결과를 제공하며 국가, 언어, 기간, 페이지 필터를 선택적으로 사용할 수 있습니다.';

  @override
  String get searchServiceNameQuerit => 'Querit';

  @override
  String get searchProviderQueritDescription =>
      'LLM 앱용 Querit 검색 API입니다. 사이트, 기간, 국가, 언어 필터를 지원하며 실시간 웹 검색 결과를 반환합니다.';

  @override
  String get searchServiceNameGrok => 'Grok';

  @override
  String get searchProviderGrokDescription =>
      'xAI Responses API 기반 Grok 검색입니다. 웹 및 X 검색 도구를 사용하며 인용 출처를 함께 반환합니다.';

  @override
  String get searchServiceNameStepFun => 'StepFun';

  @override
  String get searchProviderStepFunDescription =>
      'POST /v1/search를 사용하는 StepFun 웹 검색입니다.';

  @override
  String get searchServiceNameFirecrawl => 'Firecrawl';

  @override
  String get searchProviderFirecrawlDescription =>
      'Firecrawl 검색 API v2입니다. API 키는 선택 사항입니다. 이 서비스에서는 Scrape를 지원하지 않습니다.';

  @override
  String get searchServiceNameTinyFish => 'TinyFish';

  @override
  String get searchProviderTinyFishDescription =>
      '지역/언어 필터를 지원하는 TinyFish 검색 API입니다. API 키가 필요합니다. 이 서비스에서는 Fetch/Scrape를 지원하지 않습니다.';

  @override
  String get searchServiceNameAnySearch => 'AnySearch';

  @override
  String get searchProviderAnySearchDescription =>
      'AI 에이전트용 통합 검색으로, 웹과 전문 데이터 소스 사이에서 검색을 자동으로 라우팅합니다. API 키는 선택 사항입니다.';

  @override
  String get searchServiceNameKagi => 'Kagi';

  @override
  String get searchProviderKagiDescription =>
      'Kagi 검색 API입니다. Kagi의 프리미엄 웹 검색 결과를 반환합니다.';

  @override
  String get searchServiceNameKimi => 'Kimi';

  @override
  String get searchProviderKimiDescription =>
      'Kimi 검색 API입니다. Pro는 관련 웹 콘텐츠의 발췌문을 반환하고, Basic은 제목, 링크, 스니펫을 반환합니다.';

  @override
  String get searchServiceNameParallel => 'Parallel';

  @override
  String get searchProviderParallelDescription =>
      'Parallel 검색 API입니다. LLM에 최적화된 웹 발췌문을 반환하며 turbo, fast, basic, advanced 모드를 지원합니다.';

  @override
  String get searchServicesDialogSearchMode => '검색 모드';

  @override
  String get searchServiceNameYou => 'You.com';

  @override
  String get searchProviderYouDescription =>
      'You.com 검색 API입니다. Highlights 또는 Snippets 형식으로 웹 및 뉴스 검색 결과를 반환합니다.';

  @override
  String get searchServicesDialogContentMode => '콘텐츠 모드';

  @override
  String get searchServicesDialogHighlights => 'Highlights';

  @override
  String get searchServicesDialogSnippets => 'Snippets';

  @override
  String get searchServicesDialogWebSearch => 'Web Search';

  @override
  String get searchServicesDialogLlmContext => 'LLM Context';

  @override
  String get searchServicesDialogMaximumTokens => '최대 토큰 수';

  @override
  String get searchServicesDialogMaximumTokensInvalid =>
      '최대 토큰 수는 1024~32768 사이여야 합니다.';

  @override
  String get searchServiceNameKelivo => 'Kelivo';

  @override
  String get searchServicesDialogCountryOptional => '국가/지역(선택 사항)';

  @override
  String get searchServicesDialogLanguageOptional => '언어(선택 사항)';

  @override
  String get searchServicesDialogTimeFilterOptional => '기간 필터(선택 사항)';

  @override
  String get searchServicesDialogPageOptional => '페이지(선택 사항)';

  @override
  String get searchServicesDialogPageInvalid => '페이지는 양의 정수여야 합니다.';

  @override
  String get searchServicesDialogSitesIncludeOptional => '포함할 사이트(선택 사항)';

  @override
  String get searchServicesDialogSitesExcludeOptional => '제외할 사이트(선택 사항)';

  @override
  String get searchServicesDialogTimeRangeOptional => '기간(선택 사항)';

  @override
  String get searchServicesDialogCountriesOptional => '국가(선택 사항)';

  @override
  String get searchServicesDialogLanguagesOptional => '언어(선택 사항)';

  @override
  String get searchServicesDialogSitesHint => 'example.com, docs.example.com';

  @override
  String get searchServicesDialogTimeRangeHint => 'd7';

  @override
  String get searchServicesDialogCountriesHint => 'united states, japan';

  @override
  String get searchServicesDialogLanguagesHint => 'english, japanese';

  @override
  String get generationInterrupted => '생성 중단됨';

  @override
  String get titleForLocale => '새 채팅';

  @override
  String get temporaryChatTitle => '임시 채팅';

  @override
  String get temporaryChatEmptyMessage => '임시 채팅은 기록에 표시되지 않으며, 나가면 완전히 삭제됩니다.';

  @override
  String get temporaryChatToggleTooltip => '임시 채팅 전환';

  @override
  String get quickPhraseBackTooltip => '뒤로';

  @override
  String get quickPhraseGlobalTitle => '빠른 문구';

  @override
  String get quickPhraseAssistantTitle => '어시스턴트 빠른 문구';

  @override
  String get quickPhraseAddTooltip => '빠른 문구 추가';

  @override
  String get quickPhraseEmptyMessage => '아직 빠른 문구가 없습니다';

  @override
  String get quickPhraseAddTitle => '빠른 문구 추가';

  @override
  String get quickPhraseEditTitle => '빠른 문구 편집';

  @override
  String get quickPhraseTitleLabel => '제목';

  @override
  String get quickPhraseContentLabel => '내용';

  @override
  String get quickPhraseCancelButton => '취소';

  @override
  String get quickPhraseSaveButton => '저장';

  @override
  String get instructionInjectionTitle => '지침 주입';

  @override
  String get instructionInjectionBackTooltip => '뒤로';

  @override
  String get instructionInjectionAddTooltip => '지침 주입 추가';

  @override
  String get instructionInjectionImportTooltip => '파일에서 가져오기';

  @override
  String get instructionInjectionEmptyMessage => '아직 지침 주입 카드가 없습니다';

  @override
  String get instructionInjectionDefaultTitle => '학습 모드';

  @override
  String get instructionInjectionAddTitle => '지침 주입 추가';

  @override
  String get instructionInjectionEditTitle => '지침 주입 편집';

  @override
  String get instructionInjectionNameLabel => '이름';

  @override
  String get instructionInjectionPromptLabel => '프롬프트';

  @override
  String get instructionInjectionUngroupedGroup => '그룹 없음';

  @override
  String get instructionInjectionGroupLabel => '그룹';

  @override
  String get instructionInjectionGroupHint => '선택 사항';

  @override
  String instructionInjectionImportSuccess(int count) {
    return '지침 주입 $count개 가져옴';
  }

  @override
  String get instructionInjectionSheetSubtitle => '채팅에 적용할 프롬프트 선택';

  @override
  String get mcpJsonEditButtonTooltip => 'JSON 편집';

  @override
  String get mcpJsonEditTitle => 'JSON 편집';

  @override
  String get mcpJsonEditParseFailed => 'JSON 파싱 실패';

  @override
  String get mcpJsonEditSavedApplied => '저장 및 적용됨';

  @override
  String get mcpTimeoutSettingsTooltip => '도구 호출 제한 시간 설정';

  @override
  String get mcpTimeoutDialogTitle => '도구 호출 제한 시간';

  @override
  String get mcpTimeoutSecondsLabel => '도구 호출 제한 시간(초)';

  @override
  String get mcpTimeoutInvalid => '초 단위로 0보다 큰 숫자를 입력하세요';

  @override
  String get quickPhraseEditButton => '편집';

  @override
  String get quickPhraseDeleteButton => '삭제';

  @override
  String get quickPhraseMenuTitle => '빠른 문구';

  @override
  String get chatInputBarQuickPhraseTooltip => '빠른 문구';

  @override
  String get assistantEditQuickPhraseDescription =>
      '이 어시스턴트의 빠른 문구를 관리합니다. 아래 버튼을 눌러 문구를 추가하세요.';

  @override
  String get assistantEditManageQuickPhraseButton => '빠른 문구 관리';

  @override
  String get assistantEditPageMemoryTab => '메모리';

  @override
  String get assistantEditLocalToolTimeInfoTitle => '시간 정보';

  @override
  String get assistantEditLocalToolTimeInfoSubtitle =>
      '기기의 날짜, 요일, 시간, 시간대, UTC 오프셋, 타임스탬프를 읽습니다.';

  @override
  String get assistantEditLocalToolClipboardTitle => '클립보드';

  @override
  String get assistantEditLocalToolClipboardSubtitle =>
      '명확히 필요할 때 기기 클립보드의 일반 텍스트를 읽거나 씁니다.';

  @override
  String get assistantEditLocalToolTextToSpeechTitle => '텍스트 음성 변환';

  @override
  String get assistantEditLocalToolTextToSpeechSubtitle =>
      '어시스턴트가 구성된 TTS로 텍스트를 소리 내어 읽도록 허용합니다.';

  @override
  String get assistantEditLocalToolAskUserTitle => '사용자에게 질문';

  @override
  String get assistantEditLocalToolAskUserSubtitle =>
      '어시스턴트가 짧은 질문을 하고 답변을 받은 뒤 계속 진행하도록 허용합니다.';

  @override
  String get assistantEditLocalToolCalculateTitle => '계산기';

  @override
  String get assistantEditLocalToolCalculateSubtitle =>
      '수식을 계산합니다. + - * / 거듭제곱 sqrt sin cos 등을 지원합니다.';

  @override
  String get assistantEditLocalToolScreenTimeTitle => '화면 사용 시간';

  @override
  String get assistantEditLocalToolScreenTimeSubtitle =>
      '이 기기의 앱별 화면 사용 시간을 조회합니다. 사용 정보 접근 권한이 필요합니다.';

  @override
  String get chatMessageWidgetScreenTimeTotal => '총 화면 사용 시간';

  @override
  String get chatMessageWidgetScreenTimePermissionRequired =>
      '사용 정보 접근 권한이 허용되지 않았습니다. 시스템 설정에서 권한을 허용한 후 다시 시도하세요.';

  @override
  String get assistantEditLocalToolCalendarQueryTitle => '캘린더 조회';

  @override
  String get assistantEditLocalToolCalendarQuerySubtitle =>
      '이 기기의 캘린더 일정을 읽습니다. 캘린더 권한이 필요합니다.';

  @override
  String get assistantEditLocalToolCalendarCreateTitle => '일정 만들기';

  @override
  String get assistantEditLocalToolCalendarCreateSubtitle =>
      '사용자가 확인하면 이 기기에 캘린더 일정을 만듭니다. 캘린더 권한이 필요합니다.';

  @override
  String get assistantEditLocalToolLocationTitle => '현재 위치';

  @override
  String get assistantEditLocalToolLocationSubtitle =>
      '이 기기의 현재 위치를 한 번 읽습니다. 위치 권한이 필요합니다.';

  @override
  String get assistantEditLocalToolWeatherTitle => '날씨';

  @override
  String get assistantEditLocalToolWeatherSubtitle =>
      '현재 위치 또는 지정한 위치의 Apple 날씨 정보를 불러옵니다. 결과에 WeatherKit 데이터 출처가 표시됩니다.';

  @override
  String get assistantEditLocalToolHealthTitle => '건강 요약';

  @override
  String get assistantEditLocalToolHealthSubtitle =>
      'Apple 건강에서 개인정보가 보호되는 활동 요약을 읽습니다. 건강 데이터 액세스 권한이 필요합니다.';

  @override
  String assistantEditLocalToolHealthSelectedCount(int selected, int total) {
    return '$selected/$total개 선택됨';
  }

  @override
  String get healthDataSettingsTitle => '건강 데이터';

  @override
  String get healthDataSettingsDescription =>
      '현재 어시스턴트가 일상 대화에서 사용할 수 있는 HealthKit 지표입니다. 스위치는 Kelivo가 읽기를 시도할 수 있는 항목을 정하지만, 실제 건강 데이터 액세스 권한은 여전히 iOS에서 관리합니다.';

  @override
  String healthDataSettingsBadge(int selected, int total) {
    return '$selected/$total개 켜짐';
  }

  @override
  String get healthDataSettingsIosReadTitle => 'iOS 건강 읽기';

  @override
  String get healthDataSettingsIosReadSubtitle =>
      '이 기기에서 사용할 수 있으며, 읽기 범위는 iOS에서 관리합니다';

  @override
  String get healthDataSettingsOpenSystemSettings => '시스템 설정 열기';

  @override
  String get healthDataSettingsEnableAll => '모두 활성화';

  @override
  String get healthDataSettingsDisableAll => '모두 비활성화';

  @override
  String get healthDataSettingsCategoryActivity => '활동';

  @override
  String get healthDataSettingsCategoryRest => '휴식';

  @override
  String get healthDataSettingsCategoryHeart => '심장';

  @override
  String get healthDataSettingsCategoryBody => '신체';

  @override
  String get healthDataSettingsTypeStepsTitle => '걸음 수';

  @override
  String get healthDataSettingsTypeStepsSubtitle => '걸음 수 요약';

  @override
  String get healthDataSettingsTypeDaylightTitle => '일광 시간';

  @override
  String get healthDataSettingsTypeDaylightSubtitle => '야외 일광 시간';

  @override
  String get healthDataSettingsTypeActiveEnergyTitle => '활동 에너지';

  @override
  String get healthDataSettingsTypeActiveEnergySubtitle => '소모한 활동 에너지';

  @override
  String get healthDataSettingsTypeExerciseMinutesTitle => '운동하기';

  @override
  String get healthDataSettingsTypeExerciseMinutesSubtitle =>
      'Apple 운동하기 시간(분)';

  @override
  String get healthDataSettingsTypeStandTimeTitle => '일어서기';

  @override
  String get healthDataSettingsTypeStandTimeSubtitle => '일어서기 시간';

  @override
  String get healthDataSettingsTypeDistanceTitle => '걷기 + 달리기 거리';

  @override
  String get healthDataSettingsTypeDistanceSubtitle => '걷거나 달린 거리';

  @override
  String get healthDataSettingsTypeWorkoutsTitle => '운동';

  @override
  String get healthDataSettingsTypeWorkoutsSubtitle =>
      '운동 기록: 유형, 소요 시간, 거리, 소모 에너지';

  @override
  String get healthDataSettingsTypeSleepTitle => '수면';

  @override
  String get healthDataSettingsTypeSleepSubtitle =>
      '최근 24시간: 수면, 침대에 있던 시간, 깨어 있던 시간, 수면 단계';

  @override
  String get healthDataSettingsTypeMindfulnessTitle => '마음 챙기기';

  @override
  String get healthDataSettingsTypeMindfulnessSubtitle => '마음 챙기기 또는 휴식 시간';

  @override
  String get healthDataSettingsTypeHeartRateTitle => '심박수';

  @override
  String get healthDataSettingsTypeHeartRateSubtitle => '최신 심박수 측정값';

  @override
  String get healthDataSettingsTypeRestingHeartRateTitle => '안정 시 심박수';

  @override
  String get healthDataSettingsTypeRestingHeartRateSubtitle => '안정 시 심박수 측정값';

  @override
  String get healthDataSettingsTypeBloodOxygenTitle => '혈중 산소';

  @override
  String get healthDataSettingsTypeBloodOxygenSubtitle => '혈중 산소 포화도';

  @override
  String get healthDataSettingsTypeDietaryEnergyTitle => '식이 에너지';

  @override
  String get healthDataSettingsTypeDietaryEnergySubtitle => '섭취 칼로리 기록';

  @override
  String get healthDataSettingsTypeWaterTitle => '물';

  @override
  String get healthDataSettingsTypeWaterSubtitle => '물 섭취량 기록';

  @override
  String get healthDataSettingsTypeWeightTitle => '체중';

  @override
  String get healthDataSettingsTypeWeightSubtitle => '체중 측정값';

  @override
  String get healthDataSettingsTypeBmiTitle => 'BMI';

  @override
  String get healthDataSettingsTypeBmiSubtitle => '체질량 지수';

  @override
  String get healthDataSettingsTypeBloodGlucoseTitle => '혈당';

  @override
  String get healthDataSettingsTypeBloodGlucoseSubtitle => '혈당 측정값';

  @override
  String get assistantEditLocalToolRemindersQueryTitle => '미리 알림 조회';

  @override
  String get assistantEditLocalToolRemindersQuerySubtitle =>
      '이 기기의 미리 알림을 읽습니다. 미리 알림 전체 접근 권한이 필요합니다.';

  @override
  String get assistantEditLocalToolRemindersCreateTitle => '미리 알림 만들기';

  @override
  String get assistantEditLocalToolRemindersCreateSubtitle =>
      '사용자가 확인하면 이 기기에 미리 알림을 만듭니다. 미리 알림 전체 접근 권한이 필요합니다.';

  @override
  String get assistantEditLocalToolRemindersCompleteTitle => '미리 알림 완료';

  @override
  String get assistantEditLocalToolRemindersCompleteSubtitle =>
      '사용자가 확인하면 미리 알림을 완료로 표시합니다. 미리 알림 전체 접근 권한이 필요합니다.';

  @override
  String get assistantEditMemorySwitchDescription =>
      '어시스턴트가 메모리를 만들고 여러 채팅에서 사용하도록 허용합니다.';

  @override
  String get assistantEditRecentChatsSwitchTitle => '최근 채팅 참조';

  @override
  String get assistantEditRecentChatsSwitchDescription =>
      '최근 채팅 제목을 포함해 컨텍스트를 보강합니다.';

  @override
  String get assistantEditAddMemoryButton => '메모리 추가';

  @override
  String get assistantEditMemoryEmpty => '아직 메모리가 없습니다';

  @override
  String get assistantEditMemoryDialogTitle => '메모리';

  @override
  String get assistantEditMemoryDialogHint => '메모리 내용 입력';

  @override
  String get assistantEditAddQuickPhraseButton => '빠른 문구 추가';

  @override
  String get multiKeyPageDeleteSnackbarDeletedOne => '키 1개 삭제됨';

  @override
  String get multiKeyPageUndo => '실행 취소';

  @override
  String get multiKeyPageUndoRestored => '복원됨';

  @override
  String get multiKeyPageDeleteErrorsTooltip => '오류 키 삭제';

  @override
  String get multiKeyPageDeleteErrorsConfirmTitle => '오류 키를 모두 삭제하시겠습니까?';

  @override
  String get multiKeyPageDeleteErrorsConfirmContent => '오류로 표시된 키가 모두 삭제됩니다.';

  @override
  String multiKeyPageDeletedErrorsSnackbar(int n) {
    return '오류 키 $n개 삭제됨';
  }

  @override
  String get providerDetailPageProviderTypeTitle => '제공업체 유형';

  @override
  String get displaySettingsPageChatItemDisplayTitle => '채팅 항목 표시';

  @override
  String get displaySettingsPageRenderingSettingsTitle => '렌더링 설정';

  @override
  String get displaySettingsPageBehaviorStartupTitle => '동작 및 시작';

  @override
  String get displaySettingsPageHapticsSettingsTitle => '햅틱';

  @override
  String get assistantSettingsNoPromptPlaceholder => '아직 프롬프트가 없습니다';

  @override
  String get providersPageMultiSelectTooltip => '여러 개 선택';

  @override
  String get providersPageDeleteSelectedConfirmContent =>
      '선택한 제공업체를 삭제하시겠습니까? 이 작업은 되돌릴 수 없습니다.';

  @override
  String get providersPageDeleteSelectedSnackbar => '선택한 제공업체 삭제됨';

  @override
  String providersPageExportSelectedTitle(int count) {
    return '제공업체 $count개 내보내기';
  }

  @override
  String get providersPageExportCopyButton => '복사';

  @override
  String get providersPageExportShareButton => '공유';

  @override
  String get providersPageExportCopiedSnackbar => '공유 문자열 복사됨';

  @override
  String get providersPageDeleteAction => '삭제';

  @override
  String get providersPageExportAction => '내보내기';

  @override
  String get assistantEditPresetTitle => '프리셋 대화';

  @override
  String get assistantEditPresetAddUser => '사용자 메시지 추가';

  @override
  String get assistantEditPresetAddAssistant => '어시스턴트 메시지 추가';

  @override
  String get assistantEditPresetInputHintUser => '사용자 메시지 입력…';

  @override
  String get assistantEditPresetInputHintAssistant => '어시스턴트 메시지 입력…';

  @override
  String get assistantEditPresetEmpty => '아직 프리셋 메시지가 없습니다';

  @override
  String get assistantEditPresetEditDialogTitle => '프리셋 메시지 편집';

  @override
  String get assistantEditPresetRoleUser => '사용자';

  @override
  String get assistantEditPresetRoleAssistant => '어시스턴트';

  @override
  String get desktopTtsPleaseAddProvider => '먼저 TTS 서비스를 추가하세요';

  @override
  String get settingsPageNetworkProxy => '네트워크 프록시';

  @override
  String get networkProxyEnableLabel => '프록시 활성화';

  @override
  String get networkProxySettingsHeader => '프록시 설정';

  @override
  String get networkProxyType => '프록시 유형';

  @override
  String get networkProxyTypeHttp => 'HTTP';

  @override
  String get networkProxyTypeHttps => 'HTTPS';

  @override
  String get networkProxyTypeSocks5 => 'SOCKS5';

  @override
  String get networkProxyServerHost => '서버';

  @override
  String get networkProxyPort => '포트';

  @override
  String get networkProxyUsername => '사용자 이름';

  @override
  String get networkProxyPassword => '비밀번호';

  @override
  String get networkProxyBypassLabel => '프록시 예외';

  @override
  String get networkProxyBypassHint =>
      '쉼표로 구분한 호스트/CIDR(예: localhost,127.0.0.1,192.168.0.0/16,*.local)';

  @override
  String get networkProxyOptionalHint => '선택 사항';

  @override
  String get networkProxyTestHeader => '연결 테스트';

  @override
  String get networkProxyTestUrlHint => '테스트 URL';

  @override
  String get networkProxyTestButton => '테스트';

  @override
  String get networkProxyTesting => '테스트 중…';

  @override
  String get networkProxyTestSuccess => '연결 성공';

  @override
  String networkProxyTestFailed(String error) {
    return '테스트 실패: $error';
  }

  @override
  String get networkProxyNoUrl => 'URL을 입력하세요';

  @override
  String get networkProxyPriorityNote =>
      '전역 프록시와 제공업체 프록시가 모두 활성화되어 있으면 제공업체 프록시가 우선 적용됩니다.';

  @override
  String get settingsPageAutoRetry => '자동 재시도';

  @override
  String get autoRetryEnableLabel => '자동 재시도 활성화';

  @override
  String get autoRetryMaxRetries => '최대 재시도 횟수';

  @override
  String get autoRetryInitialDelay => '초기 지연 시간(ms)';

  @override
  String get autoRetryMultiplier => '백오프 배수';

  @override
  String get autoRetryMaxDelay => '최대 지연 시간(ms)';

  @override
  String get autoRetryJitter => '지터';

  @override
  String get autoRetryJitterSubtitle => '대기 시간을 매번 ±20% 범위에서 무작위로 조정합니다';

  @override
  String get autoRetryOnNetworkError => '네트워크 오류 시 재시도';

  @override
  String get autoRetryStatusCodes => '재시도할 상태 코드';

  @override
  String get autoRetryKeywords => '재시도 키워드';

  @override
  String get autoRetryStopKeywords => '재시도 중단 키워드';

  @override
  String get autoRetryAddHint => '추가';

  @override
  String get autoRetryRestoreDefaults => '기본값 복원';

  @override
  String get autoRetryFooter => '자동 재시도는 현재 모델 응답에 아직 출력된 내용이 없을 때만 실행됩니다.';

  @override
  String autoRetryCountdown(int seconds, int attempt, int maxRetries) {
    return '$seconds초 후 재시도($attempt/$maxRetries)';
  }

  @override
  String get desktopShowProviderInModelCapsule => '모델 캡슐에 제공업체 표시';

  @override
  String get messageWebViewOpenInBrowser => '브라우저에서 열기';

  @override
  String get messageWebViewConsoleLogs => '콘솔 로그';

  @override
  String get messageWebViewNoConsoleMessages => '콘솔 메시지 없음';

  @override
  String get messageWebViewRefreshTooltip => '새로고침';

  @override
  String get messageWebViewForwardTooltip => '앞으로';

  @override
  String get chatInputBarOcrTooltip => '이미지 OCR';

  @override
  String get providerDetailPageMultiSelectButton => '여러 개 선택';

  @override
  String get providerDetailPageBatchDetectButton => '검사';

  @override
  String get providerDetailPageBatchDetecting => '검사 중…';

  @override
  String get providerDetailPageBatchDetectStart => '검사 시작';

  @override
  String get providerDetailPageDetectSuccess => '검사 성공';

  @override
  String get providerDetailPageDetectFailed => '검사 실패';

  @override
  String get providerDetailPageDeleteSelectedModelsButton => '삭제';

  @override
  String get providerDetailPageDeleteSelectedModelsTooltip => '선택한 모델 삭제';

  @override
  String providerDetailPageDeleteSelectedModelsConfirm(int count) {
    return '선택한 모델 $count개를 삭제하시겠습니까? 이 작업은 되돌릴 수 없습니다.';
  }

  @override
  String get providerDetailPageDeleteFailedDetectedModelsButton =>
      '사용할 수 없는 모델 삭제';

  @override
  String get providerDetailPageDeleteFailedDetectedModelsTooltip =>
      '검사에 실패한 모델 삭제';

  @override
  String providerDetailPageDeleteFailedDetectedModelsConfirm(int count) {
    return '검사에 실패한 모델 $count개를 삭제하시겠습니까? 이 작업은 되돌릴 수 없습니다.';
  }

  @override
  String providerDetailPageSelectedModelsDeletedSnackbar(int count) {
    return '모델 $count개 삭제됨';
  }

  @override
  String get providerDetailPageDeleteAllModelsTooltip => '모델 모두 삭제';

  @override
  String get providerDetailPageDeleteAllModelsWarning => '이 작업은 되돌릴 수 없습니다.';

  @override
  String get requestLogSettingTitle => '요청 로깅';

  @override
  String get requestLogSettingSubtitle =>
      '활성화하면 요청/응답 세부 정보가 logs/logs.txt에 기록됩니다(매일 교체).';

  @override
  String get flutterLogSettingTitle => 'Flutter 로깅';

  @override
  String get flutterLogSettingSubtitle =>
      '활성화하면 Flutter 오류와 print 출력이 logs/flutter_logs.txt에 기록됩니다(매일 교체).';

  @override
  String get contextLogSettingTitle => '컨텍스트 로깅';

  @override
  String get contextLogSettingSubtitle =>
      '활성화하면 모델에 보낸 메시지가 그대로 logs/context_logs.txt에 기록됩니다(매일 교체).';

  @override
  String get contextLogViewerTitle => '컨텍스트';

  @override
  String contextLogSnapshotMessages(int count) {
    return '메시지 $count개';
  }

  @override
  String contextLogSnapshotTokens(int count) {
    return '$count 토큰';
  }

  @override
  String get contextLogSourceSystemPrompt => '시스템 프롬프트';

  @override
  String get contextLogSourceMemoryRules => '메모리 규칙';

  @override
  String get contextLogSourceSearchPrompt => '검색 프롬프트';

  @override
  String get contextLogSourceInstructionInjection => '지침 주입';

  @override
  String get contextLogSourceWorldBook => '월드북';

  @override
  String get contextLogSourceMemorySnapshot => '메모리 스냅샷';

  @override
  String get contextLogSourceChatHistory => '메시지 기록';

  @override
  String get contextLogSourceToolCall => '도구 호출';

  @override
  String get contextLogSourceToolResult => '도구 결과';

  @override
  String get contextLogTokensEstimateHint =>
      '토큰 수는 추정치일 뿐입니다. 모델의 실제 사용량을 기준으로 삼으세요.';

  @override
  String contextLogSnapshotsCount(int count) {
    return '스냅샷 $count개';
  }

  @override
  String get contextLogSnapshotFallbackTitle => '스냅샷';

  @override
  String get contextLogKindFull => '전체 스냅샷';

  @override
  String get contextLogKindUpdate => '증분 업데이트';

  @override
  String get contextLogSectionComposition => '구성';

  @override
  String get contextLogLoadOlder => '이전 로그 불러오기';

  @override
  String get contextLogLoading => '불러오는 중…';

  @override
  String get contextLogAllLoaded => '모든 로그를 불러왔습니다';

  @override
  String get logViewerTitle => '요청 로그';

  @override
  String get logViewerEmpty => '아직 로그가 없습니다';

  @override
  String get logViewerCurrentLog => '현재 로그';

  @override
  String get logViewerExport => '내보내기';

  @override
  String get logViewerOpenFolder => '로그 폴더 열기';

  @override
  String logViewerRequestsCount(int count) {
    return '요청 $count건';
  }

  @override
  String get logViewerFieldId => 'ID';

  @override
  String get logViewerFieldMethod => '메서드';

  @override
  String get logViewerFieldStatus => '상태';

  @override
  String get logViewerFieldStarted => '시작 시간';

  @override
  String get logViewerFieldEnded => '종료 시간';

  @override
  String get logViewerFieldDuration => '소요 시간';

  @override
  String get logViewerSectionSummary => '요약';

  @override
  String get logViewerSectionParameters => '매개변수';

  @override
  String get logViewerSectionRequestHeaders => '요청 헤더';

  @override
  String get logViewerSectionRequestBody => '요청 본문';

  @override
  String get logViewerSectionResponseHeaders => '응답 헤더';

  @override
  String get logViewerSectionResponseBody => '응답 본문';

  @override
  String get logViewerSectionWarnings => '경고';

  @override
  String get logViewerErrorTitle => '오류';

  @override
  String logViewerMoreCount(int count) {
    return '+$count개 더';
  }

  @override
  String get logViewerSectionAttachments => '첨부 파일';

  @override
  String get logViewerPayloadOmitted => '생략됨';

  @override
  String get logViewerShowMore => '더 보기';

  @override
  String get logSettingsTitle => '로그 설정';

  @override
  String get logSettingsSaveOutput => '응답 출력 저장';

  @override
  String get logSettingsSaveOutputSubtitle =>
      '스트리밍 청크를 모두 기록합니다(생성 속도가 느려질 수 있음). HTTP 오류 응답 본문은 항상 기록됩니다.';

  @override
  String get logSettingsElidePayloads => '대용량 페이로드 생략';

  @override
  String get logSettingsElidePayloadsSubtitle =>
      '인라인 base64 이미지와 파일을 자리 표시자로 바꿉니다. 로그 크기가 작게 유지되고 로그 뷰어도 빨라집니다.';

  @override
  String get logSettingsAutoDelete => '자동 삭제';

  @override
  String get logSettingsAutoDeleteSubtitle => '지정한 일수보다 오래된 로그를 삭제합니다';

  @override
  String get logSettingsAutoDeleteDisabled => '꺼짐';

  @override
  String logSettingsAutoDeleteDays(int count) {
    return '$count일';
  }

  @override
  String get logSettingsMaxSize => '최대 로그 크기';

  @override
  String get logSettingsMaxSizeSubtitle => '초과하면 가장 오래된 로그부터 삭제합니다';

  @override
  String get logSettingsMaxSizeUnlimited => '무제한';

  @override
  String get assistantEditManageSummariesTitle => '요약 관리';

  @override
  String get assistantEditSummaryEmpty => '아직 요약이 없습니다';

  @override
  String get assistantEditSummaryDialogTitle => '요약 편집';

  @override
  String get assistantEditSummaryDialogHint => '요약 내용 입력';

  @override
  String get assistantEditDeleteSummaryTitle => '요약 지우기';

  @override
  String get assistantEditDeleteSummaryContent => '이 요약을 지우시겠습니까?';

  @override
  String get homePageProcessingFiles => '파일 처리 중…';

  @override
  String get settingsPageWorldBook => '월드북';

  @override
  String get settingsPageMemory => '메모리';

  @override
  String get memorySettingsPageTitle => '메모리';

  @override
  String get memorySettingsGlobalSubtitle => '메모리 모드, 모델 및 프롬프트';

  @override
  String get memorySettingsModeSection => '메모리 모드';

  @override
  String get memorySettingsModelSection => '메모리 모델';

  @override
  String get memorySettingsModelTitle => '처리 모델';

  @override
  String get memorySettingsModelUnset => '선택되지 않음';

  @override
  String get memorySettingsModelTip =>
      '‘메모리 자동 정리’를 활성화하면 이 모델이 백그라운드에서 자주 호출됩니다. 저렴하고 빠른 모델을 권장합니다.';

  @override
  String get memorySettingsAboutTitle => '메모리 정보';

  @override
  String get memorySettingsAboutSubtitle => '메모리의 작동 방식과 실행 시점';

  @override
  String get memoryAboutQuickstartTitle => '시작하기';

  @override
  String get memoryAboutQuickstartBody =>
      '1. ‘설정 → 메모리’에서 처리 모델을 선택하세요.\n2. 어시스턴트의 ‘메모리’ 탭에서 ‘장기 메모리 사용’과 ‘메모리 자동 정리’를 켜세요.\n3. 몇 번 채팅하거나 ‘메모리 정리’를 누른 다음, ‘모든 메모리’를 열어 저장된 내용을 확인하세요.';

  @override
  String get memoryAboutTypesTitle => '메모리 유형';

  @override
  String get memoryAboutTypesBody =>
      '사용자 정보: 호칭, 직업, 언어, 장기적인 선호 등 사용자에 대해 잘 바뀌지 않는 사실입니다. 완전한 3인칭 문장으로 작성하세요.\n\n작업 방식: 도구, 형식, 검토 습관 등 사용자가 일할 때 선호하는 방식입니다.\n\n말투: 어조, 길이, 문체 등 사용자가 어시스턴트에게 바라는 말하기 방식입니다.\n\n지침: 이번 채팅의 일회성 작업이 아니라 어시스턴트가 늘 따라야 하는 규칙입니다.';

  @override
  String get memoryAboutScopeTitle => '전역과 어시스턴트 범위';

  @override
  String get memoryAboutScopeBody =>
      '전역 메모리는 모든 어시스턴트에 주입됩니다. 어시스턴트 범위 메모리는 그 어시스턴트만 볼 수 있습니다. 모든 어시스턴트가 알아야 하는 사실에는 전역을, 한 어시스턴트에만 속하는 규칙이나 컨텍스트에는 어시스턴트 범위를 사용하세요.';

  @override
  String get memoryAboutInjectionTitle => '메모리 주입 방식';

  @override
  String get memoryAboutInjectionBody =>
      '채팅을 시작할 때 유형별 최신 항목이 모델 컨텍스트에 포함됩니다. 어떤 유형이 주입 한도를 넘으면 그 블록은 mode=\"summary\"로 표시되고, total과 shown으로 전체 개수와 포함된 개수를 나타냅니다. 나머지는 memory_search_profile로 불러올 수 있습니다. ‘설정 → 메모리’에서 한도를 높이면 더 많은 항목이 포함되지만 토큰 비용이 늘어납니다.';

  @override
  String get memoryAboutPipelineTitle => '백그라운드 파이프라인';

  @override
  String get memoryAboutPipelineBody =>
      '자동 정리는 채팅 후에 실행되며 기억 여부 판단, 후보 추출, 중복 제거 및 병합을 차례로 거친 뒤 필요하면 사용자 정보 항목을 사용자 프로필로 정제합니다. 어시스턴트의 ‘메모리’ 탭에서 ‘메모리 정리’를 눌러 실행할 수도 있습니다. 그래서 처리 모델이 자주 호출됩니다.';

  @override
  String get memoryAboutCacheTitle => '캐시 효율 유지';

  @override
  String get memoryAboutCacheBody =>
      '앞부분에 주입되는 메모리는 안정적으로 유지되므로, 메모리가 바뀌지 않은 채팅은 프롬프트 캐시를 재사용해 비용과 지연 시간을 줄일 수 있습니다. 불필요한 대량 편집이나 재정렬은 피하세요. 평소처럼 항목을 하나씩 편집하는 정도는 대개 영향이 크지 않습니다.';

  @override
  String get memoryAboutFaqTitle => '자주 묻는 질문';

  @override
  String get memoryAboutFaqWhyNotRememberedTitle => '왜 기억되지 않았나요?';

  @override
  String get memoryAboutFaqWhyNotRememberedBody =>
      '정리할 새 메시지가 부족하거나, 정리할 새 메시지가 없거나, 선택된 메모리 처리 모델이 없으면 정리를 건너뜁니다. 임시 채팅은 메모리에 저장되지 않습니다. 어시스턴트별로 ‘장기 메모리 사용’이나 ‘메모리 자동 정리’를 끌 수도 있습니다.';

  @override
  String get memorySettingsThinkingTitle => '추론 활성화';

  @override
  String get memorySettingsThinkingSubtitle =>
      '지원되는 경우 메모리 모델이 추론을 사용하도록 허용합니다';

  @override
  String get memorySettingsInjectionSection => '메모리 주입';

  @override
  String get memorySettingsInjectionMaxItemsTitle => '유형별 주입 항목 수';

  @override
  String get memorySettingsInjectionMaxItemsSubtitle =>
      '이 한도는 전체 주입 대상으로 선택하지 않은 유형에 적용됩니다. 어떤 유형의 메모리가 이 한도를 넘으면 최신 항목만 주입됩니다. 나머지는 memory_search_profile로 불러올 수 있습니다. 숫자가 클수록 더 많은 항목이 포함되지만 토큰을 더 많이 사용합니다. 규칙 프롬프트를 편집했다면 함께 업데이트하거나 기본값으로 재설정하세요.';

  @override
  String get memorySettingsFullInjectionTypesTitle => '항상 전체 주입할 유형';

  @override
  String get memorySettingsFullInjectionTypesSubtitle =>
      '현재 어시스턴트가 볼 수 있는 활성 메모리를 모두 주입할 유형을 하나 이상 선택하세요. 선택한 유형에는 항목 수 한도가 적용되지 않으며 컨텍스트와 토큰을 더 많이 사용합니다.';

  @override
  String memorySettingsInjectionMaxItemsOption(int n) {
    return '$n';
  }

  @override
  String get memorySettingsInjectionMaxItemsCustomButton => '사용자 지정';

  @override
  String get memorySettingsInjectionMaxItemsCustomTitle => '사용자 지정 주입 항목 수';

  @override
  String get memorySettingsInjectionMaxItemsCustomDescription =>
      '1~100 사이의 숫자를 입력하세요.';

  @override
  String get memorySettingsInjectionMaxItemsCustomLabel => '항목 수';

  @override
  String get memorySettingsInjectionMaxItemsCustomHint => '1~100';

  @override
  String get memorySettingsInjectionMaxItemsCustomInvalid =>
      '1~100 사이의 숫자를 입력하세요';

  @override
  String get memorySettingsPromptLangSection => '프롬프트 언어';

  @override
  String get memorySettingsPromptLangAuto => '자동';

  @override
  String get memorySettingsPromptLangAutoSubtitle =>
      '앱 언어를 따릅니다(중국어 → zh, 그 외 → en)';

  @override
  String get memorySettingsPromptLangZh => '중국어';

  @override
  String get memorySettingsPromptLangZhSubtitle =>
      '항상 중국어 메모리 프롬프트와 도구 설명을 사용합니다';

  @override
  String get memorySettingsPromptLangEn => '영어';

  @override
  String get memorySettingsPromptLangEnSubtitle =>
      '항상 영어 메모리 프롬프트와 도구 설명을 사용합니다';

  @override
  String get memorySettingsPromptsSection => '프롬프트 템플릿';

  @override
  String get memorySettingsLegacyPromptTitle => '구버전 메모리 규칙';

  @override
  String get memoryPromptEditRulesTitle => '메모리 규칙';

  @override
  String get memoryPromptEditRulesSubtitle => '메인 채팅의 시스템 프롬프트에 주입됩니다';

  @override
  String get memoryPromptEditGateTitle => '게이트키퍼';

  @override
  String get memoryPromptEditGateSubtitle => '이번 턴을 기억할지 판단합니다';

  @override
  String get memoryPromptEditExtractTitle => '추출';

  @override
  String get memoryPromptEditExtractSubtitle => '대화에서 후보 메모리 항목을 추출합니다';

  @override
  String get memoryPromptEditSmartAddTitle => '스마트 추가';

  @override
  String get memoryPromptEditSmartAddSubtitle =>
      'NEW / MERGE / CONFLICT / SKIP 중복 판정';

  @override
  String get memoryPromptEditDistillTitle => '프로필 정제';

  @override
  String get memoryPromptEditDistillSubtitle => '사용자 정보 메모리를 프로필 필드로 정제합니다';

  @override
  String get memoryPromptEditMigrateTitle => '구버전 메모리 마이그레이션';

  @override
  String get memoryPromptEditMigrateSubtitle =>
      '마이그레이션에서 ‘모델로 다시 쓰기’를 선택하면 메모리 원문을 다시 쓰는 데 사용됩니다';

  @override
  String get memoryPromptEditReset => '기본값으로 재설정';

  @override
  String get memoryPromptEditSave => '저장';

  @override
  String get memoryPromptEditSectionPerItem => '항목별 프롬프트';

  @override
  String get memoryPromptEditSectionBatch => '일괄 프롬프트';

  @override
  String get memorySettingsEntriesSection => '모든 메모리';

  @override
  String get memorySettingsLegacySection => '구버전 메모리';

  @override
  String get memorySettingsEntriesTitle => '메모리 목록';

  @override
  String get memorySettingsEntriesSubtitle => '메모리를 찾아보고 편집, 보관, 삭제합니다';

  @override
  String get memorySettingsProfileTitle => '사용자 프로필';

  @override
  String get memorySettingsProfileSubtitle => '모델에 제공하는 구조화된 사용자 정보 필드';

  @override
  String get memorySettingsLegacyTitle => '구버전 메모리(읽기 전용)';

  @override
  String get memorySettingsLegacySubtitle => '이전 버전의 메모리';

  @override
  String get memoryEntryTypeIdentity => '사용자 정보';

  @override
  String get memoryEntryTypeWorkflow => '작업 방식';

  @override
  String get memoryEntryTypeVoice => '말투';

  @override
  String get memoryEntryTypeInstruction => '지침';

  @override
  String get memoryEntryScopeGlobal => '전역';

  @override
  String get memoryEntryScopeAssistant => '이 어시스턴트';

  @override
  String memoryEntryScopeAssistantNamed(String name) {
    return '$name';
  }

  @override
  String get memoryEntrySourceManual => '직접 입력';

  @override
  String get memoryEntrySourceTool => '도구';

  @override
  String get memoryEntrySourceExtracted => '추출됨';

  @override
  String get memoryEntrySourceDistilled => '정제됨';

  @override
  String get memoryEntryStatusActive => '활성';

  @override
  String get memoryEntryStatusArchived => '보관됨';

  @override
  String memoryEntryUpdatedAt(String date) {
    return '업데이트: $date';
  }

  @override
  String get memoryEntryActionEdit => '편집';

  @override
  String get memoryEntryActionDelete => '삭제';

  @override
  String get memoryEntryActionArchive => '보관';

  @override
  String get memoryEntryActionRestore => '복원';

  @override
  String get memoryEntryActionSwitchScope => '범위 변경';

  @override
  String get memoryEntryActionBatchDelete => '선택 항목 삭제';

  @override
  String get memoryEntryActionAdd => '메모리 추가';

  @override
  String get memoryEntryDeleteConfirmTitle => '메모리를 삭제하시겠습니까?';

  @override
  String get memoryEntryDeleteConfirmContent =>
      '이 메모리를 영구적으로 삭제합니다. 이 작업은 되돌릴 수 없습니다.';

  @override
  String memoryEntryBatchDeleteConfirmTitle(int count) {
    return '메모리 $count개를 삭제하시겠습니까?';
  }

  @override
  String get memoryEntryBatchDeleteConfirmContent => '선택한 메모리가 영구적으로 삭제됩니다.';

  @override
  String get memoryEntrySwitchScopeConfirmTitle => '메모리 범위를 변경하시겠습니까?';

  @override
  String get memoryEntrySwitchScopeToGlobal =>
      '이 메모리를 전역(모든 어시스턴트와 공유)으로 설정하시겠습니까?';

  @override
  String get memoryEntrySwitchScopeToAssistant =>
      '이 메모리를 현재 어시스턴트에서만 사용하도록 제한하시겠습니까?';

  @override
  String get memoryEntryArchivedSection => '보관됨';

  @override
  String get memoryEntryEmpty => '아직 메모리가 없습니다';

  @override
  String get memoryEntryEmptyDisabled => '이 어시스턴트의 장기 메모리가 꺼져 있습니다';

  @override
  String get memoryEntryEditTitle => '메모리 편집';

  @override
  String get memoryEntryCreateTitle => '새 메모리';

  @override
  String get memoryEntryContentHint => '메모리 내용 입력';

  @override
  String get memoryEntryTypeLabel => '유형';

  @override
  String get memoryEntryScopeLabel => '범위';

  @override
  String get memoryFilterScopeAll => '모든 범위';

  @override
  String get memoryFilterScopeGlobal => '전역만';

  @override
  String get memoryFilterScopeAssistant => '어시스턴트';

  @override
  String get memoryFilterTypeAll => '모든 유형';

  @override
  String get memoryFilterStatusAll => '모든 상태';

  @override
  String get memoryFilterStatusActive => '활성';

  @override
  String get memoryFilterStatusArchived => '보관됨';

  @override
  String get memorySearchHint => '메모리 검색';

  @override
  String get memorySearchEmpty => '일치하는 메모리가 없습니다';

  @override
  String memoryOrphanBanner(int count) {
    return '소속 없는 어시스턴트 메모리 $count개(어시스턴트 삭제됨)';
  }

  @override
  String get memoryOrphanCleanupButton => '정리';

  @override
  String get memoryOrphanConfirmTitle => '소속 없는 메모리를 정리하시겠습니까?';

  @override
  String memoryOrphanConfirmContent(int count) {
    return '소속 어시스턴트가 더 이상 없는 메모리 $count개를 영구적으로 삭제합니다.';
  }

  @override
  String get memoryOrganizeButton => '메모리 정리';

  @override
  String get memoryOrganizeNeedsConversation => '메모리를 정리하려면 이 어시스턴트와의 채팅을 여세요';

  @override
  String get memoryOrganizeNeedsModel => '먼저 ‘설정 → 메모리’에서 메모리 처리 모델을 선택하세요';

  @override
  String get memoryOrganizeStatusNever => '아직 정리하지 않음';

  @override
  String memoryOrganizeStatusLast(String when) {
    return '마지막 정리: $when';
  }

  @override
  String memoryOrganizeStatusExtracted(int count) {
    return '$count개 추출됨';
  }

  @override
  String get memoryOrganizeStatusSkipped => '기억할 내용 없음';

  @override
  String memoryOrganizeStatusFailed(String reason) {
    return '실패: $reason';
  }

  @override
  String memoryOrganizeStatusSkippedReason(String reason) {
    return '건너뜀: $reason';
  }

  @override
  String get memoryOutcomeTemporaryConversation => '임시 채팅은 메모리에 저장되지 않습니다';

  @override
  String get memoryOutcomeMemoryDisabled => '이 어시스턴트의 장기 메모리가 꺼져 있습니다';

  @override
  String get memoryOutcomeAutoOrganizeOff => '자동 정리가 꺼져 있습니다';

  @override
  String get memoryOutcomeStreaming => '응답이 아직 스트리밍 중입니다';

  @override
  String get memoryOutcomeBelowThreshold => '정리할 새 메시지가 부족합니다';

  @override
  String get memoryOutcomeEmptyWindow => '정리할 새 메시지가 없습니다';

  @override
  String get memoryOutcomeMemoryModelUnset => '선택된 메모리 처리 모델이 없습니다';

  @override
  String get memoryOutcomeMemoryModelMissing => '선택한 메모리 모델을 더 이상 사용할 수 없습니다';

  @override
  String get memoryOutcomeAssistantMissing => '어시스턴트를 찾을 수 없습니다';

  @override
  String get memoryOutcomeConversationMissing => '대화를 찾을 수 없습니다';

  @override
  String get memoryOutcomeQueueOverflow => '정리 대기열이 가득 차서 이번 실행은 처리되지 않았습니다';

  @override
  String get memoryOutcomeGateRequestFailed =>
      '기억 여부를 판단하는 중 메모리 모델에 연결하지 못했습니다';

  @override
  String get memoryOutcomeGateParseFailed => '기억 여부 판단 응답을 파싱하지 못했습니다';

  @override
  String get memoryOutcomeExtractRequestFailed =>
      '메모리를 추출하는 중 메모리 모델에 연결하지 못했습니다';

  @override
  String get memoryOutcomeExtractParseFailed => '메모리 추출 응답을 파싱하지 못했습니다';

  @override
  String get memoryOutcomeDistillFailed => '사용자 프로필을 정제하지 못했습니다';

  @override
  String get memoryOutcomeMemoryExecutionError => '메모리 도구를 실행하지 못했습니다';

  @override
  String get memoryOutcomeUnsupportedTool => '지원되지 않는 메모리 도구';

  @override
  String get memoryOutcomeInvalidMemoryType => '잘못된 메모리 유형';

  @override
  String get memoryOutcomeInvalidMemoryContent => '잘못된 메모리 내용';

  @override
  String get memoryOutcomeInvalidQuery => '잘못된 검색어';

  @override
  String get memoryOutcomeInvalidMemoryId => '잘못된 메모리 ID';

  @override
  String get memoryOutcomeMemoryNotFound => '메모리를 찾을 수 없습니다';

  @override
  String get memoryOutcomeInvalidProfileFields => '잘못된 프로필 필드';

  @override
  String get memoryOutcomeChatSearchUnavailable => '지난 채팅 검색을 사용할 수 없습니다';

  @override
  String get memoryOrganizeJustNow => '방금 전';

  @override
  String memoryOrganizeMinutesAgo(int n) {
    return '$n분 전';
  }

  @override
  String memoryOrganizeHoursAgo(int n) {
    return '$n시간 전';
  }

  @override
  String memoryOrganizeDaysAgo(int n) {
    return '$n일 전';
  }

  @override
  String get memoryModelMissingNotice => '먼저 ‘설정 → 메모리’에서 메모리 처리 모델을 선택하세요.';

  @override
  String get memoryModelMissingGoSelect => '모델 선택';

  @override
  String get memoryEntriesPageTitle => '모든 메모리';

  @override
  String get userProfilePageTitle => '사용자 프로필';

  @override
  String get userProfilePreferredName => '호칭';

  @override
  String get userProfilePreferredNameHint =>
      '모델이 부를 호칭으로, 사이드바에 표시되는 닉네임과는 관계없습니다';

  @override
  String get userProfileGender => '성별';

  @override
  String get userProfilePronouns => '대명사';

  @override
  String get userProfilePreferredLanguage => '선호 언어';

  @override
  String get userProfileTimezone => '시간대';

  @override
  String get userProfileOccupation => '직업';

  @override
  String get userProfileLocation => '위치';

  @override
  String get userProfileCustomSection => '사용자 지정 필드';

  @override
  String get userProfileAddCustom => '사용자 지정 필드 추가';

  @override
  String get userProfileCustomKeyHint => '키(custom.name)';

  @override
  String get userProfileCustomValueHint => '값';

  @override
  String get userProfileInvalidKey =>
      '키는 custom. 뒤에 영문자, 숫자, _, - 중 1~32자가 와야 합니다';

  @override
  String get userProfileClear => '지우기';

  @override
  String get userProfileSave => '저장';

  @override
  String get userProfileEmptyValue => '설정되지 않음';

  @override
  String get legacyMemoryPageTitle => '구버전 메모리';

  @override
  String get legacyMemoryBanner =>
      '이 메모리는 이전 버전에서 만들어졌으며 채팅에 사용되지 않습니다. 현재 메모리 시스템으로 마이그레이션할 수 있습니다.';

  @override
  String get legacyMemoryEmpty => '구버전 메모리 없음';

  @override
  String get legacyMemoryCopy => '복사';

  @override
  String get legacyMemoryCopied => '복사됨';

  @override
  String get legacyMemoryExport => '내보내기';

  @override
  String get legacyMemoryExportTitle => 'Kelivo 구버전 메모리 내보내기';

  @override
  String legacyMemoryAssistantHeader(String name) {
    return '어시스턴트: $name';
  }

  @override
  String get legacyMemorySearchHint => '구버전 메모리 검색';

  @override
  String get legacyMemoryMigrate => '마이그레이션';

  @override
  String get legacyMemoryMigrationTitle => '구버전 메모리 마이그레이션';

  @override
  String legacyMemoryMigrationSubtitle(int count) {
    return '모델로 구버전 메모리 $count개를 분류하고 정리합니다. 원본은 변경되지 않습니다.';
  }

  @override
  String get legacyMemoryMigrationModel => '마이그레이션 모델';

  @override
  String get legacyMemoryMigrationChooseModel => '모델 선택';

  @override
  String get legacyMemoryMigrationTarget => '저장 위치';

  @override
  String get legacyMemoryMigrationTargetGlobal => '전역';

  @override
  String get legacyMemoryMigrationTargetAssistant => '현재 어시스턴트';

  @override
  String get legacyMemoryMigrationTargetOriginalAssistants => '원래 어시스턴트';

  @override
  String get legacyMemoryMigrationTargetGlobalDescription =>
      '모든 어시스턴트에서 사용할 수 있습니다';

  @override
  String get legacyMemoryMigrationTargetAssistantDescription =>
      '이 어시스턴트에서만 사용할 수 있습니다';

  @override
  String get legacyMemoryMigrationTargetOriginalDescription =>
      '각 메모리를 원래 어시스턴트 소속으로 유지합니다';

  @override
  String get legacyMemoryMigrationStart => '마이그레이션 시작';

  @override
  String get legacyMemoryMigrationAnalyzing => '모델로 분석 중';

  @override
  String get legacyMemoryMigrationWriting => '메모리 저장 중';

  @override
  String legacyMemoryMigrationProgress(int current, int total) {
    return '$current/$total';
  }

  @override
  String get legacyMemoryMigrationComplete => '마이그레이션 완료';

  @override
  String legacyMemoryMigrationResult(int created, int skipped) {
    return '$created개 마이그레이션됨 · $skipped개는 이미 있음';
  }

  @override
  String get legacyMemoryMigrationFailed =>
      '마이그레이션이 중지되었습니다. 다시 시도할 수 있으며, 이미 저장된 메모리는 건너뜁니다.';

  @override
  String get legacyMemoryMigrationRetry => '다시 시도';

  @override
  String get legacyMemoryMigrationClose => '완료';

  @override
  String get legacyMemoryMigrationContentMode => '내용';

  @override
  String get legacyMemoryMigrationContentPreserve => '원문 유지';

  @override
  String get legacyMemoryMigrationContentOrganize => '모델로 다시 쓰기';

  @override
  String get legacyMemoryMigrationContentPreserveDescription =>
      '모델은 유형만 지정합니다. 원문은 그대로 저장됩니다.';

  @override
  String get legacyMemoryMigrationContentOrganizeDescription =>
      '편집 가능한 마이그레이션 프롬프트로 모델이 각 메모리를 분류하고 다시 씁니다.';

  @override
  String get legacyMemoryMigrationBatchSize => '배치 크기';

  @override
  String legacyMemoryMigrationPartial(int created, int skipped, int failed) {
    return '$created개 마이그레이션됨 · $skipped개 건너뜀 · $failed개 실패';
  }

  @override
  String get legacyMemoryMigrationContinue => '마이그레이션 계속';

  @override
  String get legacyMemoryMigrationErrorNetwork =>
      '네트워크 오류가 발생했습니다. 연결을 확인하고 다시 시도하세요.';

  @override
  String get legacyMemoryMigrationErrorFormat => '모델이 잘못된 형식의 응답을 반환했습니다.';

  @override
  String get legacyMemoryMigrationErrorAuth => '인증에 실패했습니다. API 키를 확인하세요.';

  @override
  String legacyMemoryMigrationErrorOther(String message) {
    return '마이그레이션 실패: $message';
  }

  @override
  String get legacyMemoryModeTitle => '구버전 메모리 사용';

  @override
  String get legacyMemoryModeSubtitle => '모든 어시스턴트에 적용되는 전역 설정';

  @override
  String legacyMemoryModeCacheWarning(String token) {
    return '기본 템플릿은 $token 변수로 현재 시간을 주입하므로 캐시 히트율에 영향을 줍니다. 필요 없으면 제거하세요.';
  }

  @override
  String get memoryUiContentLabel => '내용';

  @override
  String get memoryUiValueLabel => '값';

  @override
  String get memoryUiCustomKeyLabel => '키';

  @override
  String get memoryUiStatusLabel => '상태';

  @override
  String get memoryUiAssistantLabel => '어시스턴트';

  @override
  String get memoryUiAssistantAll => '모든 어시스턴트';

  @override
  String get memoryUiSearchClear => '검색어 지우기';

  @override
  String get memoryUiAssistantLegacyTitle => '구버전 메모리(읽기 전용)';

  @override
  String get memoryUiAssistantLegacySubtitle => '이 어시스턴트의 이전 버전 메모리';

  @override
  String get assistantEditMemorySwitchTitle => '장기 메모리 사용';

  @override
  String get assistantEditMemorySwitchSubtitle =>
      '저장된 메모리를 채팅에 주입하고, 이 어시스턴트가 새 메모리를 저장하도록 허용합니다';

  @override
  String get assistantEditAutoOrganizeTitle => '메모리 자동 정리';

  @override
  String get assistantEditAutoOrganizeSubtitle => '채팅 후 메모리 파이프라인을 실행합니다';

  @override
  String get assistantEditAllowPastRecallTitle => '지난 채팅 검색 허용';

  @override
  String get assistantEditAllowPastRecallSubtitle =>
      '이 어시스턴트의 지난 채팅을 검색할 수 있게 합니다';

  @override
  String get assistantEditGenerateSummaryTitle => '대화 요약 생성';

  @override
  String get assistantEditGenerateSummarySubtitle => '요약은 지난 채팅 검색에만 사용됩니다';

  @override
  String get assistantEditManageMemoryTitle => '이 어시스턴트가 볼 수 있는 메모리';

  @override
  String get assistantEditWriteScopeTitle => '메모리 저장 범위';

  @override
  String get assistantEditWriteScopeSubtitle => '새 메모리의 기본 저장 위치를 정합니다';

  @override
  String get assistantEditWriteScopeAlwaysGlobal => '항상 전역';

  @override
  String get assistantEditWriteScopeAlwaysGlobalSubtitle =>
      '새 메모리를 모든 어시스턴트와 공유합니다';

  @override
  String get assistantEditWriteScopeAlwaysAssistant => '항상 이 어시스턴트';

  @override
  String get assistantEditWriteScopeAlwaysAssistantSubtitle =>
      '새 메모리는 이 어시스턴트만 사용할 수 있습니다';

  @override
  String get assistantEditWriteScopeToolDefaultGlobal => '모델이 선택(기본값: 전역)';

  @override
  String get assistantEditWriteScopeToolDefaultGlobalSubtitle =>
      '모델이 전역 또는 이 어시스턴트를 선택할 수 있으며, 기본값은 전역입니다';

  @override
  String get assistantEditWriteScopeToolDefaultAssistant =>
      '모델이 선택(기본값: 이 어시스턴트)';

  @override
  String get assistantEditWriteScopeToolDefaultAssistantSubtitle =>
      '모델이 전역 또는 이 어시스턴트를 선택할 수 있으며, 기본값은 이 어시스턴트입니다';

  @override
  String get assistantEditDedupeModeTitle => '중복 제거 모드';

  @override
  String get assistantEditDedupeModeSubtitle => '후보를 기존 메모리와 비교해 판정하는 방식을 정합니다';

  @override
  String get assistantEditDedupeModeBatched => '일괄';

  @override
  String get assistantEditDedupeModeBatchedSubtitle =>
      '새 후보를 모두 한 번의 요청으로 판정합니다. 더 빠르고 저렴하지만, 한꺼번에 많은 항목이 들어오면 정확도가 떨어집니다.';

  @override
  String get assistantEditDedupeModePerItem => '항목별';

  @override
  String get assistantEditDedupeModePerItemSubtitle =>
      '후보마다 별도의 요청으로 판정합니다. 더 정확하지만 모델 호출이 늘어납니다.';

  @override
  String get assistantEditOrganizeFrequencyTitle => 'N턴마다 정리';

  @override
  String get assistantEditOrganizeFrequencySubtitle =>
      '어시스턴트 응답이 이 횟수만큼 쌓이면 자동 정리를 실행합니다';

  @override
  String assistantEditOrganizeFrequencyOption(int n) {
    return '$n턴마다';
  }

  @override
  String get assistantEditOrganizeFrequencyCustomButton => '사용자 지정';

  @override
  String get assistantEditOrganizeFrequencyCustomTitle => '사용자 지정 정리 주기';

  @override
  String get assistantEditOrganizeFrequencyCustomDescription =>
      '1~20 사이의 숫자를 입력하세요.';

  @override
  String get assistantEditOrganizeFrequencyCustomLabel => '턴 수';

  @override
  String get assistantEditOrganizeFrequencyCustomHint => '1~20';

  @override
  String get assistantEditOrganizeFrequencyCustomInvalid =>
      '1~20 사이의 숫자를 입력하세요';

  @override
  String get worldBookTitle => '월드북';

  @override
  String get worldBookAdd => '월드북 추가';

  @override
  String get worldBookEmptyMessage => '아직 월드북이 없습니다';

  @override
  String get worldBookUnnamed => '이름 없는 월드북';

  @override
  String get worldBookDisabledTag => '비활성화됨';

  @override
  String get worldBookAlwaysOnTag => '항상 활성';

  @override
  String get worldBookAddEntry => '항목 추가';

  @override
  String get worldBookExport => '공유/내보내기';

  @override
  String get worldBookConfig => '구성';

  @override
  String get worldBookDeleteTitle => '월드북 삭제';

  @override
  String worldBookDeleteMessage(String name) {
    return '“$name”을(를) 삭제하시겠습니까? 이 작업은 되돌릴 수 없습니다.';
  }

  @override
  String get worldBookCancel => '취소';

  @override
  String get worldBookDelete => '삭제';

  @override
  String worldBookExportFailed(String error) {
    return '내보내기 실패: $error';
  }

  @override
  String get worldBookNoEntriesHint => '항목 없음';

  @override
  String get worldBookUnnamedEntry => '이름 없는 항목';

  @override
  String worldBookKeywordsLine(String keywords) {
    return '키워드: $keywords';
  }

  @override
  String get worldBookEditEntry => '항목 편집';

  @override
  String get worldBookDeleteEntry => '항목 삭제';

  @override
  String get worldBookNameLabel => '이름';

  @override
  String get worldBookDescriptionLabel => '설명';

  @override
  String get worldBookEnabledLabel => '활성화';

  @override
  String get worldBookSave => '저장';

  @override
  String get worldBookEntryNameLabel => '항목 이름';

  @override
  String get worldBookEntryEnabledLabel => '항목 활성화';

  @override
  String get worldBookEntryPriorityLabel => '우선순위';

  @override
  String get worldBookEntryKeywordsLabel => '키워드';

  @override
  String get worldBookEntryKeywordsHint => '키워드를 입력하고 +를 눌러 추가하세요.';

  @override
  String get worldBookEntryKeywordInputHint => '키워드 입력';

  @override
  String get worldBookEntryKeywordAddTooltip => '키워드 추가';

  @override
  String get worldBookEntryUseRegexLabel => '정규식 사용';

  @override
  String get worldBookEntryCaseSensitiveLabel => '대소문자 구분';

  @override
  String get worldBookEntryAlwaysOnLabel => '항상 활성';

  @override
  String get worldBookEntryAlwaysOnHint => '키워드 일치 여부와 관계없이 항상 주입합니다';

  @override
  String get worldBookEntryScanDepthLabel => '스캔 깊이';

  @override
  String get worldBookEntryContentLabel => '내용';

  @override
  String get worldBookEntryInjectionPositionLabel => '주입 위치';

  @override
  String get worldBookEntryInjectionRoleLabel => '주입 역할';

  @override
  String get worldBookEntryInjectDepthLabel => '주입 깊이';

  @override
  String get worldBookInjectionPositionBeforeSystemPrompt => '시스템 프롬프트 앞';

  @override
  String get worldBookInjectionPositionAfterSystemPrompt => '시스템 프롬프트 뒤';

  @override
  String get worldBookInjectionPositionTopOfChat => '채팅 맨 위';

  @override
  String get worldBookInjectionPositionBottomOfChat => '채팅 맨 아래';

  @override
  String get worldBookInjectionPositionAtDepth => '지정 깊이';

  @override
  String worldBookImportUnsupportedEntries(int count) {
    return '가져왔습니다. 항목 $count개가 지원되지 않는 SillyTavern 기능(매크로, 정규식, 타이밍, 필터, 삽입 규칙 등)을 사용합니다. 이 항목은 내용을 유지한 채 비활성화되었습니다. 확인한 후 활성화하세요.';
  }

  @override
  String get worldBookInjectionRoleUser => '사용자';

  @override
  String get worldBookInjectionRoleAssistant => '어시스턴트';

  @override
  String get mcpToolNeedsApproval => '승인 필요';

  @override
  String get toolApprovalPending => '승인 대기 중';

  @override
  String get toolApprovalApprove => '승인';

  @override
  String get toolApprovalDeny => '거부';

  @override
  String get toolApprovalDenyTitle => '도구 호출 거부';

  @override
  String get toolApprovalDenyHint => '이유(선택 사항)';

  @override
  String toolApprovalDeniedMessage(Object reason, Object toolName) {
    return '사용자가 “$toolName” 도구 호출을 거부했습니다. 이유: $reason';
  }

  @override
  String get askUserCardSubmit => '답변 제출';

  @override
  String get askUserCardCustomHint => '답변 입력';

  @override
  String get askUserCardSomethingElse => '직접 입력';

  @override
  String get askUserCardSkip => '건너뛰기';

  @override
  String get askUserCardSkipped => '건너뜀';

  @override
  String get askUserCardAnswered => '답변 완료';

  @override
  String get askUserCardInactive => '이 질문은 더 이상 유효하지 않습니다. 다시 생성하거나 대화를 계속하세요.';

  @override
  String get askUserCardCancelled => '질문 취소됨';

  @override
  String askUserCardQuestionCount(int count) {
    return '질문 $count개';
  }

  @override
  String tokenDetailPromptTokens(int count) {
    return '$count 토큰';
  }

  @override
  String tokenDetailPromptTokensWithCache(int count, int cached) {
    return '$count 토큰(캐시 $cached)';
  }

  @override
  String tokenDetailCompletionTokens(int count) {
    return '$count 토큰';
  }

  @override
  String tokenDetailSpeed(String value) {
    return '$value tok/s';
  }

  @override
  String tokenDetailDuration(String value) {
    return '$value초';
  }

  @override
  String tokenDetailFirstToken(String value) {
    return '$value초(첫 토큰)';
  }

  @override
  String tokenDetailTotalTokens(int count) {
    return '$count 토큰';
  }

  @override
  String tokenDetailReasoningTokens(int count) {
    return '$count 토큰';
  }

  @override
  String tokenDetailCacheWriteTokens(int count) {
    return '캐시 쓰기 $count 토큰';
  }

  @override
  String tokenDetailCost(String amount) {
    return '$amount';
  }

  @override
  String get debugPageTitle => '디버그';

  @override
  String get debugPageConversationToolsTitle => '대화 도구';

  @override
  String get debugPageCreateOversizedConversationButton => '초대형 대화 만들기(30MB)';

  @override
  String get debugPageCreateManyMessagesConversationButton =>
      '메시지가 1024개인 대화 만들기';

  @override
  String get debugPageCreateDailyMixedMarkdownConversationButton =>
      '일상 혼합 Markdown 메시지 3000개 만들기';

  @override
  String get debugPageCreateLongReasoningConversationButton =>
      '생각 과정이 긴 대화 만들기(메시지 128개)';

  @override
  String get debugPageCreatingButton => '만드는 중…';

  @override
  String get debugPageCreatingOversizedConversation => '30MB 초대형 대화 만드는 중…';

  @override
  String get debugPageCreatingManyMessagesConversation =>
      '메시지가 1024개인 대화 만드는 중…';

  @override
  String get debugPageCreatingDailyMixedMarkdownConversation =>
      '메시지가 3000개인 일상 혼합 Markdown 대화 만드는 중…';

  @override
  String get debugPageCreatingLongReasoningConversation =>
      '생각 과정이 긴 디버그 대화 만드는 중…';

  @override
  String get debugPageNoCurrentAssistant =>
      '현재 어시스턴트가 없습니다. 먼저 어시스턴트를 만들거나 선택하세요.';

  @override
  String debugPageConversationCreated(int count) {
    return '메시지 $count개가 포함된 디버그 대화가 생성되었습니다.';
  }

  @override
  String debugPageCreateConversationFailed(String error) {
    return '디버그 대화를 만들지 못했습니다: $error';
  }

  @override
  String debugPageOversizedConversationTitle(int sizeMB) {
    return '초대형 대화 테스트(${sizeMB}MB)';
  }

  @override
  String debugPageManyMessagesConversationTitle(int count) {
    return '대화 테스트(메시지 $count개)';
  }

  @override
  String debugPageDailyMixedMarkdownConversationTitle(int count) {
    return '일상 혼합 Markdown 테스트(메시지 $count개)';
  }

  @override
  String debugPageLongReasoningConversationTitle(int count) {
    return '긴 생각 과정 테스트(메시지 $count개)';
  }

  @override
  String get debugPageOversizedConversationSeedText =>
      '초대형 대화에서 렌더링이 느려지는 문제를 재현하기 위한 긴 디버그 텍스트입니다. 반복되는 Markdown 형식의 텍스트, 문장 부호, CJK 문자, 일반 단어가 들어 있어 채팅 렌더링, 저장, 스크롤 성능을 프로파일링할 수 있습니다.';

  @override
  String debugPageManyMessagesSeedText(String role, int index) {
    return '$role 메시지 #$index: 목록 렌더링, 스크롤 안정성, 메시지 그룹화, 대화 기록 성능을 테스트하기 위한 간단한 무작위 디버그 샘플입니다.';
  }

  @override
  String get migrationIntroTitle => '채팅 저장소 업그레이드';

  @override
  String get migrationIntroSubtitle =>
      'Kelivo가 채팅 기록을 더 빠른 SQLite 데이터베이스로 옮깁니다. 앱이 열리기 전에 업그레이드하므로 데이터가 일관되게 유지됩니다.';

  @override
  String get migrationBackupNote =>
      '마이그레이션을 시작하기 전에 Kelivo가 설정, 채팅 기록, 로컬 파일이 담긴 ZIP 백업을 내보냅니다.';

  @override
  String get migrationPerformanceNote =>
      '마이그레이션 후에는 앱 시작, 기록 불러오기, 검색에 SQLite 인덱스를 사용하므로 긴 채팅에서도 더 매끄럽게 작동합니다.';

  @override
  String get migrationSourceDatabaseLabel => 'Hive';

  @override
  String get migrationTargetDatabaseLabel => 'SQLite';

  @override
  String get migrationChooseFolderButton => '폴더 선택 후 백업';

  @override
  String get migrationSaveBackupButton => '백업 ZIP 저장';

  @override
  String get migrationStartWithoutBackupButton => '백업 없이 마이그레이션';

  @override
  String get migrationSkipChatsJsonOption => 'chats.json 건너뛰기';

  @override
  String get migrationSkipChatsJsonDescription =>
      '원본 Hive 파일, 설정, 로컬 파일은 그대로 백업합니다. 채팅 기록이 매우 큰 경우 권장합니다.';

  @override
  String get migrationSkipBackupOption => '이번 백업 건너뛰기';

  @override
  String get migrationSkipBackupDescription =>
      '검증된 백업이 이미 있는 경우에만 선택하세요. 마이그레이션이 바로 시작됩니다.';

  @override
  String get migrationBackingUpTitle => '백업 중';

  @override
  String get migrationBackingUpSubtitle =>
      '설정, 채팅 기록, 업로드한 파일, 이미지, 글꼴을 내보내는 중입니다. 완료될 때까지 Kelivo를 열어 두세요.';

  @override
  String get migrationMigratingTitle => 'SQLite로 마이그레이션 중';

  @override
  String get migrationMigratingSubtitle =>
      '기록이 많아도 기기 메모리(RAM)가 부족해지지 않도록 대화와 메시지를 나누어 저장하는 중입니다. 마이그레이션이 끝날 때까지 Kelivo를 화면에 띄워 두세요.';

  @override
  String migrationBackingUpDetail(String fileName) {
    return '$fileName 백업 중';
  }

  @override
  String migrationMigratingDetail(int count) {
    return '메시지 $count개 마이그레이션됨';
  }

  @override
  String get migrationMigratingPrepareDetail => 'SQLite 데이터베이스 준비 중';

  @override
  String get migrationMigratingToolEventsDetail => '도구 기록 마이그레이션 중';

  @override
  String get migrationMigratingValidateDetail => '마이그레이션된 데이터 유효성 검사 중';

  @override
  String get migrationBackupReadyDetail => '백업 ZIP 준비됨';

  @override
  String get migrationSavingBackupZipDetail => '백업 ZIP 저장 중';

  @override
  String get migrationBackupFileSavedTitle => '백업 ZIP 저장됨';

  @override
  String get migrationChecklistBackupFiles => 'Hive 백업 ZIP 내보내기';

  @override
  String get migrationChecklistPrepareSqlite => 'SQLite 데이터베이스 준비';

  @override
  String get migrationChecklistMigrateMessages => '대화 및 메시지 마이그레이션';

  @override
  String get migrationChecklistMigrateToolEvents => '도구 기록 마이그레이션';

  @override
  String get migrationChecklistValidate => '마이그레이션된 데이터 유효성 검사';

  @override
  String get migrationStepBackup => '백업';

  @override
  String get migrationStepMigrate => '마이그레이션';

  @override
  String get migrationStepComplete => '완료';

  @override
  String get migrationCompleteTitle => '업그레이드 완료';

  @override
  String get migrationCompleteSubtitle =>
      '이제 채팅 기록이 SQLite에 저장됩니다. 업그레이드된 앱을 사용하려면 Kelivo를 다시 시작하세요.';

  @override
  String get migrationConversationCount => '대화';

  @override
  String get migrationMessageCount => '메시지';

  @override
  String get migrationConvertedCount => '변환됨';

  @override
  String get migrationMalformedCount => '형식 오류';

  @override
  String get migrationMissingFilesCount => '누락된 파일';

  @override
  String get migrationRestartButton => 'Kelivo 다시 시작';

  @override
  String get migrationFailedTitle => '마이그레이션 실패';

  @override
  String get migrationFailedSubtitle =>
      '원본 Hive 데이터는 그대로 남아 있습니다. 앞서 완료된 백업도 변경되지 않았습니다. 아래 원인을 확인한 후 다시 시도하세요.';

  @override
  String get migrationUnknownError => '알 수 없는 마이그레이션 오류가 발생했습니다.';

  @override
  String get migrationFailureLogTitle => '실패 로그';

  @override
  String get migrationRetryButton => '마이그레이션 다시 시도';

  @override
  String get migrationSkipButton => '마이그레이션 건너뛰고 새로 시작';

  @override
  String get migrationSkipDialogTitle => '마이그레이션을 건너뛰시겠습니까?';

  @override
  String get migrationSkipDialogMessage =>
      'Kelivo가 빈 채팅 데이터베이스로 시작됩니다. 구버전 채팅 기록은 이름에 .retired 접미사가 붙은 채 디스크에 남지만, 마이그레이션되지 않으며 앱에도 표시되지 않습니다. 나중에 복원하려면 백업 ZIP을 사용하세요.';

  @override
  String get migrationSkipDialogCancel => '취소';

  @override
  String get migrationSkipDialogConfirm => '건너뛰고 새로 시작';

  @override
  String get migrationChatsExportDegradedNote =>
      '오류가 발생해 chats.json 내보내기를 건너뛰었습니다. 백업 ZIP에는 전체 채팅 기록이 담긴 원본 Hive 파일이 그대로 포함되어 있습니다.';

  @override
  String get timelineJumpToLatest => '최신으로 이동';

  @override
  String largeContentShowMore(int count) {
    return '$count줄 더 보기';
  }

  @override
  String get largeContentCollapse => '접기';

  @override
  String get imageSettingsPageTitle => '이미지 처리';

  @override
  String get imageSettingsPageEditSectionTitle => '편집';

  @override
  String get imageSettingsPageQualitySectionTitle => '업로드 이미지 품질';

  @override
  String get imageSettingsPageQualityOriginal => '원본';

  @override
  String get imageSettingsPageQualityOriginalSubtitle => '압축하지 않고 그대로 업로드합니다';

  @override
  String get imageSettingsPageQualityHigh => '고화질';

  @override
  String get imageSettingsPageQualityHighSubtitle => '긴 변 2048px · 품질 90';

  @override
  String get imageSettingsPageQualityBalanced => '균형';

  @override
  String get imageSettingsPageQualityBalancedSubtitle => '긴 변 1568px · 품질 85';

  @override
  String get imageSettingsPageQualitySaver => '데이터 절약';

  @override
  String get imageSettingsPageQualitySaverSubtitle => '긴 변 1024px · 품질 70';

  @override
  String get imageSettingsPageQualityCustom => '사용자 지정';

  @override
  String get imageSettingsPageQualityCustomSubtitle => '압축 품질을 직접 선택합니다';

  @override
  String get imageSettingsPageCustomQualityTitle => '압축 품질';

  @override
  String get imageSettingsPageCompressTransparentTitle => '투명 및 애니메이션 이미지 압축';

  @override
  String get imageSettingsPageCompressTransparentSubtitle =>
      '활성화하면 투명 PNG, GIF 등의 형식도 압축합니다. 투명한 영역은 흰색으로 바뀌고 애니메이션은 첫 프레임만 유지됩니다.';

  @override
  String get imageSettingsPageFooter =>
      '이미지를 추가할 때 압축합니다. 이미 저장했거나 보낸 이미지에는 영향을 주지 않습니다. 압축한 이미지는 JPEG 파일로 전송됩니다.';

  @override
  String get imageSettingsPageSendSectionTitle => '전송';

  @override
  String get imageSettingsPageMarkdownImageLinksTitle =>
      'Markdown 이미지 링크를 이미지로 보내기';

  @override
  String get imageSettingsPageMarkdownImageLinksSubtitle =>
      '활성화하면 메시지 텍스트의 ![alt](url) 링크가 비전 모델에 이미지로 전송됩니다. 끄면 일반 텍스트로 유지됩니다. 직접 첨부한 이미지는 항상 이미지로 전송됩니다.';

  @override
  String get memoryTraceSettingsTitle => '파이프라인 추적 기록';

  @override
  String get memoryTraceSettingsSubtitle => '모든 백그라운드 메모리 실행을 단계별로 확인합니다';

  @override
  String get memoryTracePageTitle => '메모리 파이프라인 추적 기록';

  @override
  String get memoryTraceRecordingSection => '기록';

  @override
  String get memoryTraceToggleTitle => '파이프라인 추적 기록 남기기';

  @override
  String get memoryTraceToggleSubtitle =>
      '최근 백그라운드 실행의 프롬프트, 응답, 변경 사항은 앱이 실행되는 동안에만 유지되며 디스크에 저장되지 않습니다';

  @override
  String get memoryTraceRunsSection => '최근 실행';

  @override
  String get memoryTraceEmptyTitle => '아직 추적 기록이 없습니다';

  @override
  String get memoryTraceEmptySubtitle =>
      '백그라운드 메모리 파이프라인이 실행되면 여기에 추적 기록이 표시됩니다.';

  @override
  String get memoryTraceDisabledTitle => '기록이 꺼져 있습니다';

  @override
  String get memoryTraceDisabledSubtitle => '기록을 켜면 다음 백그라운드 메모리 실행부터 기록됩니다.';

  @override
  String get memoryTraceClearAction => '지우기';

  @override
  String get memoryTraceClearSheetTitle => '추적 기록 지우기';

  @override
  String get memoryTraceClearSheetMessage =>
      '모든 추적 기록을 지웁니다. 추적 기록은 디스크에 저장되지 않으므로 다른 데이터에는 영향을 주지 않습니다.';

  @override
  String get memoryTraceClearConfirm => '추적 기록 지우기';

  @override
  String get memoryTraceCancel => '취소';

  @override
  String get memoryTraceClearedToast => '추적 기록 지워짐';

  @override
  String get memoryTraceCopyAction => '복사';

  @override
  String get memoryTraceCopiedToast => '클립보드에 복사됨';

  @override
  String get memoryTraceTriggerAuto => '자동';

  @override
  String get memoryTraceTriggerManual => '수동';

  @override
  String get memoryTraceTriggerTool => '도구 호출';

  @override
  String get memoryTraceTriggerSummary => '대화 요약';

  @override
  String get memoryTraceScopeAssistant => '어시스턴트';

  @override
  String get memoryTraceScopeGlobal => '전역';

  @override
  String get memoryTraceStepGatekeeper => '게이트키퍼';

  @override
  String get memoryTraceStepExtract => '추출';

  @override
  String get memoryTraceStepSmartAdd => '스마트 추가';

  @override
  String get memoryTraceStepDistiller => '프로필 정제';

  @override
  String get memoryTraceStepSummary => '대화 요약';

  @override
  String get memoryTraceStepChatSearch => '지난 채팅 검색';

  @override
  String get memoryTraceStepTool => '메모리 도구';

  @override
  String get memoryTraceStatusSuccess => '성공';

  @override
  String get memoryTraceStatusFailed => '실패';

  @override
  String get memoryTraceStatusSkipped => '건너뜀';

  @override
  String get memoryTraceStatusRunning => '실행 중';

  @override
  String get memoryTraceOutcomeAdvanced => '처리 지점 이동됨';

  @override
  String get memoryTraceOutcomeHeld => '처리 지점 유지됨';

  @override
  String get memoryTraceOutcomeForced => '처리 지점 강제 이동됨';

  @override
  String get memoryTraceDetailTitle => '추적 기록 세부 정보';

  @override
  String get memoryTraceSectionOverview => '개요';

  @override
  String get memoryTraceSectionPrompt => '프롬프트';

  @override
  String get memoryTraceSectionResponse => '원본 응답';

  @override
  String get memoryTraceSectionParsed => '파싱 결과';

  @override
  String get memoryTraceSectionMutations => '적용된 변경 사항';

  @override
  String get memoryTraceFieldTime => '시작 시간';

  @override
  String get memoryTraceFieldDuration => '소요 시간';

  @override
  String get memoryTraceFieldTrigger => '트리거';

  @override
  String get memoryTraceFieldScope => '범위';

  @override
  String get memoryTraceFieldConversation => '채팅';

  @override
  String get memoryTraceFieldAssistant => '어시스턴트';

  @override
  String get memoryTraceFieldWindow => '메시지 범위';

  @override
  String get memoryTraceFieldWatermark => '처리 지점';

  @override
  String get memoryTraceFieldOutcome => '결과';

  @override
  String get memoryTraceFieldError => '오류';

  @override
  String get memoryTraceMutationCreated => '생성됨';

  @override
  String get memoryTraceMutationMerged => '병합됨';

  @override
  String get memoryTraceMutationEdited => '편집됨';

  @override
  String get memoryTraceMutationArchived => '보관됨';

  @override
  String get memoryTraceMutationLinked => '연관됨';

  @override
  String get memoryTraceMutationProfileWritten => '프로필 필드 기록됨';

  @override
  String get memoryTraceMutationProfileCleared => '프로필 필드 지워짐';

  @override
  String get memoryTraceMutationSummary => '대화 요약 기록됨';

  @override
  String get memoryTraceBefore => '변경 전';

  @override
  String get memoryTraceAfter => '변경 후';

  @override
  String get memoryTraceEmptyValue => '(비어 있음)';

  @override
  String memoryTraceStepsCount(int count) {
    return '단계 $count개';
  }

  @override
  String memoryTraceMutationsCount(int count) {
    return '변경 사항 $count개';
  }

  @override
  String memoryTraceRepeatCount(int count) {
    return '$count회 반복';
  }

  @override
  String memoryTraceWindowValue(int size, int start, int end) {
    return '메시지 $size개 · #$start~#$end';
  }

  @override
  String get memoryTraceShowMore => '전체 텍스트 보기';

  @override
  String get memoryTraceShowLess => '접기';

  @override
  String get messageStyleSettingsPageTitle => '메시지 스타일';

  @override
  String get messageStyleSettingsPageReset => '재설정';

  @override
  String get messageStyleSettingsPageResetConfirm =>
      '메시지 스타일 맞춤 설정을 모두 재설정하시겠습니까?';

  @override
  String get messageStyleSettingsPageCancel => '취소';

  @override
  String get messageStyleSettingsPageLight => '라이트';

  @override
  String get messageStyleSettingsPageDark => '다크';

  @override
  String get messageStyleSettingsPageDefaultHint =>
      '기본 스타일은 현재 테마를 따르며 추가로 조절할 수 있는 항목이 없습니다.';

  @override
  String get messageStyleSettingsPageStyleDefaultSubtitle =>
      '테마를 따르며 맞춤 설정할 수 없습니다';

  @override
  String get messageStyleSettingsPageAssistantFitContent =>
      '어시스턴트 말풍선을 내용에 맞추기';

  @override
  String get messageStyleSettingsPageAssistantFitContentSubtitle =>
      '어시스턴트 말풍선이 가로 폭 전체를 채우지 않고 텍스트 너비에 맞춰집니다';

  @override
  String get messageStyleSettingsPageAssistantSplitParagraphs => '문단마다 말풍선 나누기';

  @override
  String get messageStyleSettingsPageAssistantSplitParagraphsSubtitle =>
      '어시스턴트 응답을 빈 줄에서 나눠 문단마다 별도의 말풍선으로 표시합니다';

  @override
  String get messageStyleSettingsPageStyleFrostedSubtitle =>
      '배경이 흐리게 비치는 유리 효과';

  @override
  String get messageStyleSettingsPageStyleSolidSubtitle => '불투명한 단색 배경';

  @override
  String get messageStyleSettingsPageBlur => '흐림 강도';

  @override
  String get messageStyleSettingsPageBlurHint =>
      '흐림 효과는 말풍선 뒤의 내용에 적용됩니다. 채팅 배경을 설정하지 않으면 효과가 거의 보이지 않습니다.';

  @override
  String get messageStyleSettingsPageBackgroundColor => '배경색';

  @override
  String get messageStyleSettingsPageBackgroundOpacity => '배경 불투명도';

  @override
  String get messageStyleSettingsPageBorderColor => '테두리 색상';

  @override
  String get messageStyleSettingsPageBorderOpacity => '테두리 불투명도';

  @override
  String get messageStyleSettingsPageBorderWidth => '테두리 두께';

  @override
  String get messageStyleSettingsPageTextColor => '텍스트 색상';

  @override
  String get messageStyleSettingsPageCornerRadius => '모서리 반경';

  @override
  String get messageStyleSettingsPagePreviewUser => '사용자 메시지입니다';

  @override
  String get messageStyleSettingsPagePreviewAssistant => '어시스턴트 응답입니다.';

  @override
  String get messageStyleSettingsPagePreviewThinking => '생각 중';

  @override
  String get messageStyleSettingsPageRoleUser => '사용자';

  @override
  String get messageStyleSettingsPageRoleAssistant => '어시스턴트';

  @override
  String get messageStyleSettingsPageRoleAssistantHint =>
      '어시스턴트 설정은 생각 카드, 도구 카드, 번역 카드에도 적용됩니다.';

  @override
  String get localSnapshotSectionTitle => '로컬 사본';

  @override
  String get localSnapshotEnabledTitle => '로컬 사본 자동 저장';

  @override
  String get localSnapshotEnabledSubtitle =>
      'Kelivo가 이 기기에 데이터베이스 사본을 주기적으로 저장해, 데이터베이스가 하나뿐인 상태가 되지 않도록 합니다.';

  @override
  String get localSnapshotIntervalTitle => '저장 주기';

  @override
  String get localSnapshotIntervalAutomatic => '자동';

  @override
  String get localSnapshotIntervalAutomaticDetail =>
      '매일 저장하며, 데이터베이스가 커질수록 간격이 길어집니다';

  @override
  String localSnapshotIntervalDays(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days일마다',
      one: '매일',
    );
    return '$_temp0';
  }

  @override
  String get localSnapshotKeepTitle => '유지할 사본 수';

  @override
  String localSnapshotKeepValue(int count) {
    return '사본 $count개';
  }

  @override
  String get localSnapshotKeepSubtitle =>
      '지난주와 지난달 사본도 1개씩 추가로 유지해, 뒤늦게 문제를 발견해도 복원할 수 있습니다.';

  @override
  String get localSnapshotKeepWeekly => '지난주 사본 1개 유지';

  @override
  String get localSnapshotKeepMonthly => '지난달 사본 1개 유지';

  @override
  String get localSnapshotKeepProtectedNote =>
      '설정과 관계없이, 데이터가 남아 있는 가장 최근 사본은 자동으로 삭제되지 않습니다.';

  @override
  String get localSnapshotMaximumTitle => '용량 한도';

  @override
  String get localSnapshotMaximumUnlimited => '제한 없음';

  @override
  String get localSnapshotAnnounceTitle => '사본 저장 시 알림';

  @override
  String get localSnapshotAnnounceSubtitle =>
      '실패는 항상 알립니다. 이 설정을 켜면 성공했을 때도 짧은 메시지를 표시합니다.';

  @override
  String get localSnapshotTakeNow => '지금 사본 저장';

  @override
  String get localSnapshotManageCopies => '사본 관리';

  @override
  String localSnapshotUsage(int count, String size) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '사본 $count개',
      zero: '사본 없음',
    );
    return '$_temp0 · $size';
  }

  @override
  String get localSnapshotStatusNever => '아직 저장된 사본이 없습니다';

  @override
  String localSnapshotStatusSuccess(String when) {
    return '마지막 사본: $when';
  }

  @override
  String localSnapshotStatusFailure(String when, String reason) {
    return '마지막 시도 실패($when): $reason';
  }

  @override
  String get localSnapshotStatusSkippedSpace => '이 기기의 저장 공간이 부족해 건너뛰었습니다';

  @override
  String get localSnapshotStatusUnchanged => '마지막 사본 이후 변경된 내용이 없습니다';

  @override
  String get localSnapshotCopiesTitle => '로컬 사본';

  @override
  String get localSnapshotCopiesEmpty => '아직 로컬 사본이 없습니다';

  @override
  String get localSnapshotCopiesEmptyHint =>
      '데이터가 바뀌면 사본이 자동으로 저장되며, 복원하기 전에도 항상 사본이 저장됩니다.';

  @override
  String get localSnapshotCopiesScopeNote =>
      '로컬 사본은 이 기기에만 저장됩니다. 앱 안에서 데이터가 손상되거나 실수로 삭제된 경우에는 대비할 수 있지만, 기기 분실이나 Kelivo 제거에는 대비할 수 없습니다. 이런 경우에는 WebDAV 또는 S3 백업을 사용하세요.';

  @override
  String get localSnapshotOriginAutomatic => '자동';

  @override
  String get localSnapshotOriginManual => '직접 저장';

  @override
  String get localSnapshotOriginBeforeRestore => '복원 전';

  @override
  String get localSnapshotKindRecovered => '복구 중 따로 보존';

  @override
  String localSnapshotCopyContents(int conversations, int messages) {
    return '채팅 $conversations개 · 메시지 $messages개';
  }

  @override
  String get localSnapshotCopyContentsUnknown => '복원해야 내용을 확인할 수 있음';

  @override
  String get localSnapshotCopyPinned => '고정됨';

  @override
  String get localSnapshotActionRestore => '복원';

  @override
  String get localSnapshotActionExport => '내보내기';

  @override
  String get localSnapshotActionDelete => '삭제';

  @override
  String get localSnapshotActionPin => '이 사본 고정';

  @override
  String get localSnapshotActionUnpin => '고정 해제';

  @override
  String get localSnapshotRestoreTitle => '이 사본을 복원하시겠습니까?';

  @override
  String localSnapshotRestoreMessage(String when) {
    return '현재 채팅과 설정이 $when에 저장된 이 사본으로 교체됩니다. 먼저 현재 채팅과 설정의 사본을 저장합니다. 보내지 않은 초안은 사본에 포함되지 않으므로 지워집니다.';
  }

  @override
  String get localSnapshotRestorePreparing => '사본 준비 중';

  @override
  String get localSnapshotDeleteTitle => '이 사본을 삭제하시겠습니까?';

  @override
  String get localSnapshotDeleteMessage =>
      '이 사본이 기기에서 영구적으로 삭제됩니다. 현재 데이터베이스에 없는 데이터가 이 사본에 있다면 함께 사라집니다.';

  @override
  String get localSnapshotDeleteLastWarning => '이 사본은 데이터가 남아 있는 유일한 사본입니다.';

  @override
  String get localSnapshotExportPreparing => '내보내기 준비 중';

  @override
  String get localSnapshotExportDone => '사본 내보냄';

  @override
  String localSnapshotExportFailed(String reason) {
    return '사본을 내보내지 못했습니다: $reason';
  }

  @override
  String get localSnapshotTakeDone => '사본 저장됨';

  @override
  String localSnapshotTakeFailed(String reason) {
    return '사본을 저장하지 못했습니다: $reason';
  }

  @override
  String get localSnapshotDeleteDone => '사본 삭제됨';

  @override
  String get localSnapshotBusyMessage => '다른 사본 저장 작업이 이미 실행 중입니다';

  @override
  String get localSnapshotRunInBackground => '백그라운드에서 계속';

  @override
  String get localSnapshotRunningInBackground => '백그라운드에서 사본 저장 중';

  @override
  String startupRecoveryLocalCopiesAvailable(int count, String when) {
    return '이 기기에는 아직 로컬 사본 $count개가 있으며, 가장 최근 사본은 $when에 저장되었습니다. 초기화해도 이 사본은 삭제되지 않습니다. 다시 시작한 후 ‘설정 › 백업 › 로컬 사본’에서 하나를 선택해 복원할 수 있습니다.';
  }

  @override
  String startupRecoveryRecoveredCopiesDeleted(int count) {
    return '이전 복구 과정에서 따로 보존한 데이터베이스 사본 $count개도 있으며, 초기화하면 이 사본도 함께 영구적으로 삭제됩니다. 유지하려면 먼저 데이터를 내보내세요.';
  }

  @override
  String get toolSchemaSettingsPageTitle => '도구 설명';

  @override
  String get toolSchemaSettingsGroupSearch => '검색';

  @override
  String get toolSchemaSettingsGroupMemory => '메모리';

  @override
  String get toolSchemaSettingsGroupLocal => '기기 도구';

  @override
  String get toolSchemaSettingsModified => '수정됨';

  @override
  String get toolSchemaSettingsResetDefault => '기본값 복원';

  @override
  String get toolSchemaSettingsResetAll => '모든 기본값 복원';

  @override
  String get toolSchemaSettingsResetAllTitle => '모든 기본값을 복원하시겠습니까?';

  @override
  String get toolSchemaSettingsResetAllMessage =>
      '모든 내장 도구 설명을 앱 기본값으로 복원합니다. 사용자 지정 문구가 사라집니다.';

  @override
  String get toolSchemaSettingsResetAllConfirm => '복원';

  @override
  String toolSchemaSettingsParamDescriptions(int count) {
    return '매개변수 설명($count)';
  }

  @override
  String get toolSchemaSettingsMemoryLangNote =>
      '메모리 도구 설명의 기본값은 메모리 프롬프트 언어를 따릅니다. 사용자 지정 설명은 도구마다 하나만 저장되므로 프롬프트 언어를 변경해도 그대로 유지됩니다.';

  @override
  String get toolSchemaSettingsDescriptionLabel => '설명';

  @override
  String get toolSchemaSettingsToolName => '도구 이름';

  @override
  String get toolSchemaEditorPageTitle => '설명 편집';

  @override
  String get toolSchemaSettingsCancel => '취소';

  @override
  String get workspaceFileNotAvailable => '파일을 사용할 수 없음';

  @override
  String get workspaceTerminalNotAvailable => '터미널을 사용할 수 없음';

  @override
  String get workspacePreviewCopyPath => '경로 복사';

  @override
  String get workspacePreviewShare => '공유';

  @override
  String get workspacePreviewOpenExternally => '외부 앱으로 열기';

  @override
  String get workspacePreviewOpenWith => '다른 앱으로 열기…';

  @override
  String get workspacePreviewFileTooLarge =>
      '이 파일은 너무 커서 미리 볼 수 없습니다. 대신 외부 앱으로 여세요.';

  @override
  String get workspacePreviewSource => '소스';

  @override
  String get workspacePreviewRendered => '렌더링';

  @override
  String get workspacePreviewFileName => '이름';

  @override
  String get workspacePreviewFileSize => '크기';

  @override
  String get workspacePreviewFileModified => '수정한 날짜';

  @override
  String get workspacePreviewPathCopied => '경로 복사됨';

  @override
  String workspacePreviewLineCount(int count) {
    return '$count줄';
  }

  @override
  String get workspaceFilesSort => '정렬';

  @override
  String get workspaceFilesSortName => '이름';

  @override
  String get workspaceFilesSortModified => '수정한 날짜';

  @override
  String get workspaceFilesSortSize => '크기';

  @override
  String get workspaceFilesSortAscending => '오름차순';

  @override
  String get workspaceFilesSortDescending => '내림차순';

  @override
  String get workspaceFilesShowHidden => '숨김 파일 표시';

  @override
  String get workspaceFilesHideHidden => '숨김 파일 숨기기';

  @override
  String get workspaceFilesRefresh => '새로고침';

  @override
  String get workspaceFilesNewFolder => '새 폴더';

  @override
  String get workspaceFilesNewFile => '새 파일';

  @override
  String get workspaceFilesImport => '가져오기';

  @override
  String get workspaceFilesExport => '내보내기';

  @override
  String get workspaceFilesExportFolder => '현재 폴더 내보내기';

  @override
  String get workspaceFilesEmpty => '이 폴더는 비어 있습니다';

  @override
  String get workspaceFilesError => '파일을 불러오지 못했습니다';

  @override
  String get workspaceFilesRetry => '다시 시도';

  @override
  String get workspaceFilesPreview => '미리보기';

  @override
  String get workspaceFilesRename => '이름 변경';

  @override
  String get workspaceFilesMove => '이동';

  @override
  String get workspaceFilesDelete => '삭제';

  @override
  String get workspaceFilesShare => '공유';

  @override
  String get workspaceFilesCopyPath => '경로 복사';

  @override
  String get workspaceFilesExportItem => '내보내기';

  @override
  String get workspaceFilesNameLabel => '이름';

  @override
  String get workspaceFilesNameHint => '이름 입력';

  @override
  String get workspaceFilesCreate => '만들기';

  @override
  String get workspaceFilesCancel => '취소';

  @override
  String get workspaceFilesConfirm => '확인';

  @override
  String get workspaceFilesSave => '저장';

  @override
  String get workspaceFilesDeleteTitle => '이 항목을 삭제하시겠습니까?';

  @override
  String workspaceFilesDeleteMessage(String name) {
    return '$name을(를) 삭제하시겠습니까?';
  }

  @override
  String workspaceFilesDeleteFolderMessage(String name) {
    return '$name 폴더와 그 안의 모든 항목을 삭제하시겠습니까?';
  }

  @override
  String get workspaceFilesMoveTitle => '폴더로 이동';

  @override
  String get workspaceFilesMoveHere => '여기로 이동';

  @override
  String get workspaceFilesPathCopied => '경로 복사됨';

  @override
  String get workspaceFilesInvalidName => '이름이 유효하지 않습니다';

  @override
  String get workspaceFilesInvalidPath => '경로가 이 폴더를 벗어납니다';

  @override
  String workspaceFilesOperationFailed(String error) {
    return '작업을 완료하지 못했습니다: $error';
  }

  @override
  String get workspaceFilesActions => '작업';

  @override
  String get workspaceFilesMore => '더보기';

  @override
  String get workspaceFilesJustNow => '방금 전';

  @override
  String workspaceFilesMinutesAgo(int count) {
    return '$count분 전';
  }

  @override
  String workspaceFilesHoursAgo(int count) {
    return '$count시간 전';
  }

  @override
  String workspaceFilesDaysAgo(int count) {
    return '$count일 전';
  }

  @override
  String get workspaceFilesPanelTitle => '대화 파일';

  @override
  String get workspaceFilesTabAttachments => '첨부 파일';

  @override
  String get workspaceFilesTabOutputs => '출력 파일';

  @override
  String get workspaceFilesTabWorkspace => '워크스페이스';

  @override
  String get workspaceFilesNoWorkspaceBound => '지정된 워크스페이스 없음';

  @override
  String get workspaceFilesKindManaged => '관리형';

  @override
  String get workspaceFilesKindLinked => '연결형';

  @override
  String get workspaceFilesMissingWorkspace => '워크스페이스를 찾을 수 없습니다';

  @override
  String get workspaceFilesClose => '닫기';

  @override
  String get workspacesTitle => '워크스페이스';

  @override
  String get workspacesCreate => '만들기';

  @override
  String get workspacesCreateTitle => '새 워크스페이스';

  @override
  String get workspacesNameLabel => '이름';

  @override
  String get workspacesNameHint => '워크스페이스 이름';

  @override
  String get workspacesLinkFolder => '폴더 연결';

  @override
  String get workspacesEmpty => '아직 워크스페이스가 없습니다';

  @override
  String get workspacesEmptyCta => '워크스페이스 만들기';

  @override
  String get workspacesSettings => '설정';

  @override
  String get workspacesOpenFiles => '파일 열기';

  @override
  String get workspacesLastUsedNever => '사용한 적 없음';

  @override
  String workspacesLastUsed(String when) {
    return '마지막 사용: $when';
  }

  @override
  String get workspacesDeleteTitle => '이 워크스페이스를 삭제하시겠습니까?';

  @override
  String workspacesDeleteMessage(String name) {
    return '$name 워크스페이스를 삭제하시겠습니까?';
  }

  @override
  String get workspacesDeleteAlsoFiles => '파일도 함께 삭제';

  @override
  String get workspacesUnlinkTitle => '이 워크스페이스의 연결을 해제하시겠습니까?';

  @override
  String workspacesUnlinkMessage(String name) {
    return '$name 워크스페이스의 연결을 해제하시겠습니까? 디스크의 파일은 유지됩니다.';
  }

  @override
  String get workspacesSettingsTitle => '워크스페이스 설정';

  @override
  String get workspacesShellNeedsApproval => '셸 명령 실행 전에 확인';

  @override
  String get workspacesDefaultCwd => '기본 작업 디렉터리';

  @override
  String get workspacesDefaultCwdHint => '상대 경로(예: src)';

  @override
  String get workspacesDefaultCwdInvalid => '.. 없는 상대 경로를 사용하세요';

  @override
  String get workspacesCreateManaged => '워크스페이스 만들기';

  @override
  String get workspacesLinkExisting => '기존 폴더 연결';

  @override
  String get workspacesUnlink => '연결 해제';

  @override
  String get workspacesItemMore => '워크스페이스 작업';

  @override
  String get workspaceToolDenied => '거부됨';

  @override
  String get workspaceToolTimeout => '시간 초과';

  @override
  String get workspaceToolCancelled => '취소됨';

  @override
  String get workspaceToolInterrupted => '중단됨';

  @override
  String get workspaceToolEnvironmentNotReady => '샌드박스 환경이 설치되지 않음';

  @override
  String get workspaceToolInstall => '설치';

  @override
  String get workspaceToolFuzzy => '유사 일치';

  @override
  String get workspaceToolCreated => '생성됨';

  @override
  String get workspaceToolUpdated => '업데이트됨';

  @override
  String get workspaceToolTruncated => '잘림';

  @override
  String get workspaceToolImageTag => '이미지';

  @override
  String get workspaceToolAllowAll => '이 대화에서 모두 허용';

  @override
  String get workspaceToolStdout => 'stdout';

  @override
  String get workspaceToolStderr => 'stderr';

  @override
  String get workspaceToolOpenFullOutput => '전체 출력 열기';

  @override
  String get workspaceToolChangedFiles => '변경된 파일';

  @override
  String get workspaceToolCancel => '취소';

  @override
  String get workspaceToolCopyCommand => '명령 복사';

  @override
  String get workspaceToolCopyOutput => '출력 복사';

  @override
  String get workspaceToolCopyDiff => 'diff 복사';

  @override
  String get workspaceToolCopied => '복사됨';

  @override
  String get workspaceToolDiffTruncated => 'diff 잘림';

  @override
  String get workspaceToolOpenPreview => '미리보기 열기';

  @override
  String get workspaceToolNoOutput => '출력 없음';

  @override
  String get workspaceToolNotAvailable => '사용할 수 없음';

  @override
  String get workspaceToolClose => '닫기';

  @override
  String get workspaceToolTitleShell => '명령 실행';

  @override
  String get workspaceToolTitleReadFile => '파일 읽기';

  @override
  String get workspaceToolTitleViewImage => '이미지 보기';

  @override
  String get workspaceToolTitleWriteFile => '파일 쓰기';

  @override
  String get workspaceToolTitleEditFile => '파일 편집';

  @override
  String get workspaceToolTitleListDir => '디렉터리 목록';

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
    return '$sec초';
  }

  @override
  String get workspaceEnvTitle => '환경';

  @override
  String workspaceEnvEngineUbuntu(String version) {
    return 'Ubuntu $version(PRoot)';
  }

  @override
  String workspaceEnvEngineAlpine(String version) {
    return 'Alpine $version(iSH)';
  }

  @override
  String get workspaceEnvEngineNative => '시스템 셸';

  @override
  String get workspaceEnvPhaseNotInstalled => '설치되지 않음';

  @override
  String get workspaceEnvPhaseDownloading => '다운로드 중';

  @override
  String get workspaceEnvPhaseVerifying => '검증 중';

  @override
  String get workspaceEnvPhaseExtracting => '압축 해제 중';

  @override
  String get workspaceEnvPhasePatching => '패치 적용 중';

  @override
  String get workspaceEnvPhaseReady => '준비됨';

  @override
  String get workspaceEnvPhaseError => '오류';

  @override
  String get workspaceEnvPhaseNeedsRestart => '다시 시작 필요';

  @override
  String workspaceEnvMetaLine(String version, String arch) {
    return '$version · $arch';
  }

  @override
  String workspaceEnvInstalledAt(String date) {
    return '설치일: $date';
  }

  @override
  String workspaceEnvDiskUsage(String size) {
    return '디스크 사용량: $size';
  }

  @override
  String workspaceEnvRuntimeReason(String reason) {
    return '$reason';
  }

  @override
  String get workspaceEnvInstall => '설치';

  @override
  String get workspaceEnvInstallSubtitleAndroid =>
      'Ubuntu, Alpine, Debian 중에서 선택하거나 로컬 rootfs 이미지를 가져오세요.';

  @override
  String get workspaceEnvInstallSubtitleIos => '내장됨, 다운로드 필요 없음';

  @override
  String get workspaceEnvCancel => '취소';

  @override
  String get workspaceEnvRetry => '다시 시도';

  @override
  String get workspaceEnvRepair => '복구';

  @override
  String get workspaceEnvReset => '초기화';

  @override
  String get workspaceEnvResetConfirmTitle => '환경을 초기화하시겠습니까?';

  @override
  String get workspaceEnvResetConfirmBody => '설치된 패키지와 샌드박스 파일 시스템을 삭제합니다.';

  @override
  String get workspaceEnvCheckForUpdate => '업데이트 확인';

  @override
  String get workspaceEnvUpdate => '업데이트';

  @override
  String workspaceEnvAvailableVersion(String version) {
    return '$version 버전을 사용할 수 있습니다';
  }

  @override
  String get workspaceEnvUpToDate => '최신 버전입니다';

  @override
  String get workspaceEnvRestartBanner => '설치를 완료하려면 Kelivo를 다시 시작하세요';

  @override
  String get workspaceEnvDetectingMirrors => '가장 빠른 미러 찾는 중…';

  @override
  String workspaceEnvApplyingMirror(String category) {
    return '$category 미러 적용 중…';
  }

  @override
  String get workspaceEnvMirrorsSection => '미러';

  @override
  String get workspaceEnvUseMirror => '미러 사용';

  @override
  String get workspaceEnvDetect => '속도 테스트';

  @override
  String get workspaceEnvOfficial => '공식';

  @override
  String get workspaceEnvMirrorsDisabled =>
      '미러 변경은 샌드박스에서 실행되므로 샌드박스가 준비될 때까지 사용할 수 없습니다.';

  @override
  String workspaceEnvMirrorsDisabledReason(String reason) {
    return '미러 변경은 샌드박스에서 실행되므로 지금은 사용할 수 없습니다: $reason';
  }

  @override
  String get workspaceEnvMirrorDetectTitle => '미러 속도';

  @override
  String workspaceEnvMirrorLatency(int ms) {
    return '${ms}ms';
  }

  @override
  String workspaceEnvMirrorFailed(String reason) {
    return '$reason';
  }

  @override
  String get workspaceEnvErrorUnsupportedAbi => '이 기기의 아키텍처를 지원하지 않습니다.';

  @override
  String get workspaceEnvErrorArchitectureMismatch =>
      '설치된 샌드박스의 아키텍처가 이 앱과 일치하지 않습니다. 계속하려면 샌드박스를 다시 설치하세요. 기존 샌드박스 파일은 보존되었습니다.';

  @override
  String get workspaceEnvErrorProotMissing => 'PRoot 바이너리가 없습니다.';

  @override
  String get workspaceEnvErrorInsufficientDisk => '샌드박스를 설치할 저장 공간이 부족합니다.';

  @override
  String get workspaceEnvErrorInsufficientDiskHint =>
      '선택한 이미지에 필요한 저장 공간을 더 확보한 후 다시 시도하세요.';

  @override
  String get workspaceEnvErrorNetwork => '다운로드에 실패했습니다. 연결을 확인하고 다시 시도하세요.';

  @override
  String get workspaceEnvErrorChecksumMismatch =>
      '다운로드한 파일이 손상되었습니다. 다시 시도하세요.';

  @override
  String get workspaceEnvErrorExtractFailed => '샌드박스 이미지의 압축을 해제하지 못했습니다.';

  @override
  String get workspaceEnvErrorCleanupFailed =>
      '이전 샌드박스 파일을 제거하지 못했습니다. 다시 시도하세요.';

  @override
  String get workspaceEnvCleanupIncomplete =>
      '샌드박스가 준비되었지만 일부 이전 파일을 제거하지 못했습니다. 이 파일은 여전히 저장 공간을 차지합니다.';

  @override
  String get workspaceEnvErrorResetFailed => '샌드박스 초기화를 완료하지 못했습니다. 다시 시도하세요.';

  @override
  String get workspaceEnvErrorPatchFailed => '샌드박스 구성을 완료하지 못했습니다.';

  @override
  String get workspaceEnvErrorCancelled => '설치가 취소되었습니다.';

  @override
  String get workspaceEnvErrorGeneric => '샌드박스를 설치하는 중 문제가 발생했습니다.';

  @override
  String get workspaceEnvChipInstall => '샌드박스 설치';

  @override
  String workspaceEnvChipInstalling(int percent) {
    return '설치 중… $percent%';
  }

  @override
  String get workspaceEnvChipInstallingIndeterminate => '설치 중…';

  @override
  String get workspaceEnvChipError => '샌드박스 오류';

  @override
  String get workspaceEnvChipRestart => '다시 시작 필요';

  @override
  String get workspaceEnvNativeExplanation =>
      '데스크톱에서는 Kelivo가 Linux 샌드박스 대신 시스템 셸을 사용합니다.';

  @override
  String workspaceEnvNativeShellPath(String path) {
    return '셸: $path';
  }

  @override
  String get workspaceEnvNativeShellApproval =>
      '셸 도구는 ‘이 대화에서 모두 허용’을 켜지 않으면 승인이 필요합니다.';

  @override
  String workspaceEnvDownloadProgress(
    String downloaded,
    String total,
    int percent,
  ) {
    return '$downloaded / ${total}MB($percent%)';
  }

  @override
  String get workspaceEnvMirrorsFailed => '미러 속도를 테스트하지 못했습니다';

  @override
  String get workspaceEnvCategoryApt => 'APT';

  @override
  String get workspaceEnvCategoryApk => 'APK';

  @override
  String get workspaceEnvCategoryPip => 'pip';

  @override
  String get workspaceEnvCategoryNpm => 'npm';

  @override
  String get skillsTitle => '스킬';

  @override
  String get skillsTab => '스킬';

  @override
  String get skillsSearchHint => '스킬 검색';

  @override
  String get skillsEmptyTitle => '아직 스킬이 없습니다';

  @override
  String get skillsEmptyBody =>
      '스킬은 SKILL.md 파일이 들어 있는 폴더입니다. Markdown, .md 또는 .zip 파일, GitHub URL로 가져오세요.';

  @override
  String get skillsEmptyFormat =>
      '---\nname: my-skill\ndescription: 이 스킬이 하는 일\n---\n\n# 지침';

  @override
  String get skillsImport => '가져오기';

  @override
  String get skillsImportPaste => 'Markdown 붙여넣기';

  @override
  String get skillsImportFile => '파일에서 가져오기';

  @override
  String get skillsImportGitHub => 'GitHub에서 가져오기';

  @override
  String get skillsImportPasteLabel => 'SKILL.md';

  @override
  String get skillsImportPasteHint => 'YAML 프런트매터가 포함된 SKILL.md 붙여넣기';

  @override
  String get skillsImportGitHubLabel => 'GitHub URL';

  @override
  String get skillsImportGitHubHint =>
      'github.com/owner/repo 또는 github.com/owner/repo/tree/ref/path';

  @override
  String get skillsImportConfirm => '가져오기';

  @override
  String get skillsCancel => '취소';

  @override
  String get skillsSave => '저장';

  @override
  String skillsUsedCount(int count) {
    return '$count회 사용';
  }

  @override
  String get skillsEnabled => '활성화';

  @override
  String get skillsBrowseFiles => '파일 찾아보기';

  @override
  String get skillsEdit => '편집';

  @override
  String get skillsExport => '내보내기';

  @override
  String get skillsDelete => '삭제';

  @override
  String get skillsDeleteTitle => '이 스킬을 삭제하시겠습니까?';

  @override
  String skillsDeleteMessage(String name) {
    return '$name 스킬을 삭제하시겠습니까? 이 작업은 되돌릴 수 없습니다.';
  }

  @override
  String get skillsUseAll => '모든 스킬 사용';

  @override
  String get skillsUseAllSubtitle => '이 어시스턴트가 활성화된 모든 스킬을 사용할 수 있습니다.';

  @override
  String get skillsDisabledHint => '여기서 사용하려면 ‘스킬’ 페이지에서 이 스킬을 활성화하세요.';

  @override
  String get skillsOpenPage => '스킬 관리';

  @override
  String get skillsInheritAssistant => '어시스턴트 설정 따르기';

  @override
  String get skillsInheritAssistantSubtitle => '이 채팅의 어시스턴트와 같은 스킬을 사용합니다.';

  @override
  String get skillsActiveLabel => '활성';

  @override
  String get skillsSessionTitle => '이 채팅의 스킬';

  @override
  String get skillsEditTitle => '스킬 편집';

  @override
  String get skillsDetailKindLabel => '스킬';

  @override
  String get skillsNoEnabled => '활성화된 스킬 없음';

  @override
  String get terminalTitle => '터미널';

  @override
  String get terminalOpenInSystem => '시스템 터미널에서 열기';

  @override
  String get terminalHostDirectory => '호스트 디렉터리';

  @override
  String get terminalBindWorkspaceFirst => '먼저 워크스페이스를 지정하세요';

  @override
  String get terminalNotAvailable => '사용할 수 없음';

  @override
  String get terminalRuntimeUnavailable => '터미널 환경이 준비되지 않았습니다';

  @override
  String get terminalRename => '이름 변경';

  @override
  String get terminalClose => '닫기';

  @override
  String get terminalClear => '화면 지우기';

  @override
  String get terminalCloseSession => '세션 닫기';

  @override
  String get terminalCopy => '복사';

  @override
  String get terminalPaste => '붙여넣기';

  @override
  String get terminalNewSession => '새 세션';

  @override
  String get terminalMore => '더보기';

  @override
  String get terminalNameLabel => '이름';

  @override
  String get terminalCancel => '취소';

  @override
  String get terminalSave => '저장';

  @override
  String get workspaceDeskMenuWorkspace => '워크스페이스';

  @override
  String get workspaceDeskMenuSkills => '스킬';

  @override
  String get workspaceDeskBarTitle => '워크스페이스';

  @override
  String get workspaceDeskBarNoWorkspace => '워크스페이스 없음';

  @override
  String get workspaceDeskBarEmptyHint =>
      '도구 모음에서 워크스페이스를 지정하면 여기에서 파일을 볼 수 있습니다';

  @override
  String get workspaceDeskBarToggle => '워크스페이스 파일';

  @override
  String get workspaceDeskOpenSystemTerminal => '시스템 터미널에서 열기';

  @override
  String get workspaceDeskReveal => '파일 관리자에서 보기';

  @override
  String get workspaceDeskBarClose => '워크스페이스 패널 닫기';

  @override
  String get workspaceEntryBind => '워크스페이스 지정';

  @override
  String get workspaceEntryUnbind => '지정 해제';

  @override
  String get workspaceEntryChange => '변경';

  @override
  String get workspaceEntrySetAssistantDefault => '어시스턴트 기본 워크스페이스로 설정';

  @override
  String get workspaceEntryLocked => '잠김';

  @override
  String get workspaceEntryChangeConfirmTitle => '워크스페이스를 변경하시겠습니까?';

  @override
  String get workspaceEntryUnbindConfirmTitle => '워크스페이스 지정을 해제하시겠습니까?';

  @override
  String get workspaceEntryChangeConfirmBody =>
      '이 대화에서 이미 워크스페이스 도구를 사용했습니다. 이전 메시지의 파일 링크가 더 이상 작동하지 않을 수 있습니다.';

  @override
  String get workspaceEntryCwd => '작업 디렉터리';

  @override
  String get workspaceEntryCwdHint => '워크스페이스 루트 기준 상대 경로';

  @override
  String get workspaceEntryCwdInvalid => '경로가 유효하지 않거나 워크스페이스를 벗어납니다';

  @override
  String get workspaceEntryCwdMissing => '디렉터리가 존재하지 않습니다';

  @override
  String get workspaceEntryCwdCreate => '디렉터리 만들기';

  @override
  String get workspaceEntryFiles => '파일';

  @override
  String get workspaceEntryTerminal => '터미널';

  @override
  String get workspaceEntryOpenSystemTerminal => '시스템 터미널에서 열기';

  @override
  String get workspaceEntryReveal => '파일 관리자에서 보기';

  @override
  String get workspaceEntrySessionSkills => '스킬';

  @override
  String get workspaceEntryAllowAll => '이 대화에서 모두 허용';

  @override
  String get workspaceEntryAllowAllSubtitle => '이 대화의 셸 명령은 승인 없이 실행됩니다.';

  @override
  String get workspaceEntryEnvironment => '환경';

  @override
  String get workspaceEntryManage => '워크스페이스 관리';

  @override
  String get workspaceEntryCreate => '새 워크스페이스 만들기…';

  @override
  String get workspaceEntryDefaultWorkspace => '기본 워크스페이스';

  @override
  String get workspaceEntryDefaultWorkspaceSubtitle =>
      '새 대화에서 이 워크스페이스를 사용합니다. 기존 대화는 그대로 유지됩니다.';

  @override
  String get workspaceEntryDefaultWorkspaceUnset => '설정되지 않음';

  @override
  String get workspaceEntryDefaultWorkspaceAutomaticSubtitle =>
      '대화에 처음 지정한 워크스페이스를 기억해 새 대화에서 사용합니다.';

  @override
  String workspaceBindingRememberedDefault(String assistant) {
    return '“$assistant”의 기본 워크스페이스로 기억했습니다. 새 대화에서 이 워크스페이스를 사용합니다.';
  }

  @override
  String workspaceBindingSuggestDefault(String assistant) {
    return '앞으로 “$assistant”의 새 대화에도 이 워크스페이스를 사용하시겠습니까?';
  }

  @override
  String get workspaceBindingUndoDefault => '실행 취소';

  @override
  String get workspaceBindingUseAsDefault => '기본값으로 설정';

  @override
  String get workspaceEntryNone => '없음';

  @override
  String get workspaceEntryStartConversationFirst => '먼저 대화를 시작하세요';

  @override
  String get workspaceEntryTooltip => '워크스페이스';

  @override
  String get workspaceEntryPickerTitle => '워크스페이스 선택';

  @override
  String get settingsPageWorkspace => '워크스페이스 및 환경';

  @override
  String get settingsPageSkills => '스킬';

  @override
  String get commonClose => '닫기';

  @override
  String get terminalCopyAllOutput => '전체 출력 복사';

  @override
  String get terminalFontDecrease => '글꼴 크기 −';

  @override
  String get terminalFontIncrease => '글꼴 크기 +';

  @override
  String get terminalCloseSessionConfirmMessage =>
      '이 세션이 아직 실행 중입니다. 닫으면 프로세스가 종료됩니다.';

  @override
  String get terminalCopiedAll => '전체 출력 복사됨';

  @override
  String get terminalConfirm => '확인';

  @override
  String terminalExitCode(int code) {
    return '종료 코드 $code';
  }

  @override
  String get workspaceMgmtNewWorkspace => '새 워크스페이스';

  @override
  String get workspaceMgmtEmptyHint => '프로젝트 파일을 한곳에 모아 두려면 워크스페이스를 만드세요.';

  @override
  String get workspaceMgmtKindManagedTitle => '관리형 워크스페이스';

  @override
  String get workspaceMgmtKindManagedSubtitle => '샌드박스에서 읽고 쓰는 앱 내 폴더';

  @override
  String get workspaceMgmtKindLinkedTitle => '연결된 폴더';

  @override
  String get workspaceMgmtKindLinkedSubtitle => '이 컴퓨터의 폴더를 사용합니다';

  @override
  String get workspaceMgmtImportFromFolder => '폴더에서 가져오기';

  @override
  String get workspaceMgmtImportFromFolderSubtitle => '폴더를 새 관리형 워크스페이스로 복사합니다';

  @override
  String get workspaceMgmtKindSection => '유형';

  @override
  String get workspaceMgmtCreate => '만들기';

  @override
  String get workspaceMgmtShellApprovalSubtitle => '명령을 실행할 때마다 먼저 확인합니다';

  @override
  String get workspaceMgmtDefaultCwdRoot => '/';

  @override
  String get workspaceMgmtPickCwdTitle => '기본 작업 디렉터리';

  @override
  String get workspaceMgmtFolderPickerUnavailable => '폴더 선택기를 사용할 수 없습니다.';

  @override
  String get workspaceMgmtImportProgressTitle => '폴더 가져오는 중';

  @override
  String get workspaceMgmtImportProgressPhase => '파일 복사 중…';

  @override
  String get workspaceMgmtImportFailed => '폴더를 가져오지 못했습니다.';

  @override
  String workspaceMgmtImportDone(String name) {
    return '$name 가져옴';
  }

  @override
  String get workspaceMgmtLastUsedJustNow => '방금 전';

  @override
  String workspaceMgmtLastUsedMinutesAgo(int n) {
    return '$n분 전';
  }

  @override
  String workspaceMgmtLastUsedHoursAgo(int n) {
    return '$n시간 전';
  }

  @override
  String workspaceMgmtLastUsedDaysAgo(int n) {
    return '$n일 전';
  }

  @override
  String workspaceMgmtRowDetail(String kind, String when) {
    return '$kind · 마지막 사용: $when';
  }

  @override
  String workspaceMgmtRowDetailNever(String kind) {
    return '$kind · 사용한 적 없음';
  }

  @override
  String get workspacePreviewBack => '뒤로';

  @override
  String get workspacePreviewWrap => '자동 줄 바꿈';

  @override
  String get workspacePreviewFontDecrease => '글자 작게';

  @override
  String get workspacePreviewFontIncrease => '글자 크게';

  @override
  String get workspacePreviewCopy => '복사';

  @override
  String get workspacePreviewRetry => '다시 시도';

  @override
  String get workspacePreviewLoadError => '이 파일을 불러오지 못했습니다.';

  @override
  String get workspacePreviewRevealInFinder => 'Finder에서 보기';

  @override
  String get workspacePreviewOpenInSystemApp => '시스템 앱으로 열기';

  @override
  String get workspacePreviewOpenInBrowser => '브라우저에서 열기';

  @override
  String get workspacePreviewTable => '표';

  @override
  String get workspacePreviewPlainLanguage => '코드';

  @override
  String get workspacePreviewOpen => '열기';

  @override
  String get workspacePreviewRevealFailed => '파일 관리자에서 이 파일을 표시하지 못했습니다.';

  @override
  String get workspacePreviewEmptyTable => '이 표는 비어 있습니다.';

  @override
  String get workspaceFilesNew => '새로 만들기';

  @override
  String get workspaceFilesFoldersFirst => '폴더 우선';

  @override
  String get workspaceFilesSelectDirectory => '이 폴더 선택';

  @override
  String get workspaceFilesEmptyHint => '‘새로 만들기’ 또는 ‘가져오기’로 파일을 추가하세요';

  @override
  String get workspaceFilesEmptyAttachments => '아직 첨부 파일이 없습니다';

  @override
  String get workspaceFilesEmptyOutputs => '아직 어시스턴트가 만든 파일이 없습니다';

  @override
  String get workspaceFilesMoveTo => '이동…';

  @override
  String workspaceFilesItemCount(int count) {
    return '항목 $count개';
  }

  @override
  String get skillsImportTooltip => '스킬 가져오기';

  @override
  String get skillsImportPasteSubtitle => 'YAML 프런트매터가 포함된 SKILL.md를 붙여넣습니다';

  @override
  String get skillsImportFileSubtitle => '.md 또는 .zip 파일을 선택합니다';

  @override
  String get skillsImportGitHubSubtitle => '리포지토리에서 SKILL.md를 가져옵니다';

  @override
  String get skillsImportResolving => '리포지토리 확인 중…';

  @override
  String get skillsImportDownloading => '다운로드 중…';

  @override
  String get skillsImportExtracting => '압축 해제 중…';

  @override
  String get skillsImportInstalling => '설치 중…';

  @override
  String get skillsImportGitHubRepoLabel => '리포지토리 URL';

  @override
  String get skillsImportGitHubUrlHint =>
      'https://github.com/owner/repo 또는 owner/repo[/path]';

  @override
  String get skillsImportGitHubHelp => '리포지토리 루트나 하위 디렉터리에 있는 SKILL.md를 지원합니다.';

  @override
  String get skillsEmptyHint =>
      '스킬은 프런트매터가 포함된 SKILL.md입니다. 가져오면 어시스턴트가 필요할 때 사용할 수 있습니다.';

  @override
  String get skillsMoreActions => '더보기';

  @override
  String get skillsSearchClear => '지우기';

  @override
  String get skillsSessionEmpty =>
      '아직 활성화된 스킬이 없습니다. 먼저 ‘스킬’ 페이지에서 스킬을 활성화하세요.';

  @override
  String get workspaceToolRunning => '처리 중';

  @override
  String workspaceToolExitCode(int code) {
    return '종료 코드 $code';
  }

  @override
  String get workspaceToolAwaitingApproval => '승인 대기 중';

  @override
  String get workspaceToolCompleted => '완료';

  @override
  String workspaceToolLines(int count) {
    return '$count줄';
  }

  @override
  String workspaceToolItems(int count) {
    return '항목 $count개';
  }

  @override
  String workspaceToolFileMatches(int count) {
    return '일치 항목 $count개';
  }

  @override
  String workspaceToolContentMatches(int count) {
    return '일치 항목 $count개';
  }

  @override
  String get workspaceToolExpand => '펼치기';

  @override
  String get workspaceToolSectionCommand => '명령';

  @override
  String get workspaceToolSectionPath => '경로';

  @override
  String get workspaceToolSectionPattern => '패턴';

  @override
  String get workspaceToolSectionOutput => '출력';

  @override
  String get workspaceToolSectionDiff => 'Diff';

  @override
  String get workspaceToolSectionError => '오류';

  @override
  String get workspaceToolSavedOutput => '전체 출력 저장됨';

  @override
  String get workspaceToolApprove => '허용';

  @override
  String get workspaceToolDeny => '거부';

  @override
  String get workspaceToolCopy => '복사';

  @override
  String get workspaceEnvEngineLocalShell => '시스템 셸';

  @override
  String get workspaceEnvInstallEnvironment => '환경 설치';

  @override
  String get workspaceEnvInstallDescription =>
      '샌드박스에서 도구를 실행하려면 Linux 환경을 설치하세요.';

  @override
  String get workspaceEnvStatusLabel => '상태';

  @override
  String get workspaceEnvStatusInstalled => '설치됨';

  @override
  String get workspaceEnvSizeLabel => '크기';

  @override
  String get workspaceEnvPathLabel => '경로';

  @override
  String get workspaceEnvInstalledAtLabel => '설치일';

  @override
  String get workspaceEnvArchLabel => '아키텍처';

  @override
  String workspaceEnvArchVersion(String arch, String version) {
    return '$arch · $version';
  }

  @override
  String get workspaceEnvBrowseSection => '찾아보기';

  @override
  String get workspaceEnvBrowseFiles => '파일 시스템 찾아보기';

  @override
  String get workspaceEnvBrowseFilesDetail => '샌드박스 안의 전체 디렉터리 트리를 볼 수 있습니다';

  @override
  String get workspaceEnvDetectFastMirrors => '가장 빠른 미러 자동 선택';

  @override
  String get workspaceEnvActionsSection => '작업';

  @override
  String get workspaceEnvInfoSection => '정보';

  @override
  String get workspaceEnvInfoBody =>
      '환경은 샌드박스가 사용하는 Linux 루트 파일 시스템입니다. 워크스페이스는 따로 저장되며 초기화해도 삭제되지 않습니다. 파일은 이 기기에 압축 해제된 rootfs 안에 있습니다.';

  @override
  String get workspaceEnvRepairDetail => '파일을 다시 검증하고 패치합니다';

  @override
  String get workspaceEnvUpdateCurrent => '최신 버전입니다';

  @override
  String workspaceEnvUpdateAvailableShort(String version) {
    return '업데이트 가능: $version';
  }

  @override
  String get workspaceEnvResetConfirmMessage =>
      'Linux 환경 전체와 그 안에 설치된 모든 패키지가 삭제됩니다. 워크스페이스 파일은 영향을 받지 않습니다.';

  @override
  String get workspaceEnvRestartDoneBanner =>
      '초기화가 완료되었습니다. 설치를 완료하려면 앱을 다시 시작하세요.';

  @override
  String get workspaceEnvPathCopied => '경로 복사됨';

  @override
  String get workspaceEnvUseMirrorSubtitle => '선택한 미러를 샌드박스에 적용합니다';

  @override
  String get workspaceEnvRegionGlobal => '전 세계';

  @override
  String get workspaceEnvRegionChina => '중국';

  @override
  String get workspaceEnvRegionEurope => '유럽';

  @override
  String get workspaceEnvRegionAsia => '아시아';

  @override
  String get workspaceEnvMirrorTimeout => '시간 초과';

  @override
  String get workspaceEnvSpeedTest => '속도 테스트';

  @override
  String get workspaceEnvApplySuccess => '미러 적용됨';

  @override
  String get workspaceEnvApplyFailed => '미러를 적용하지 못했습니다';

  @override
  String get workspaceEnvRestoreSuccess => '공식 소스로 복원됨';

  @override
  String get workspaceEnvMirrorsTested => '가장 빠른 미러 적용됨';

  @override
  String get workspaceEnvRelativeJustNow => '방금 전';

  @override
  String workspaceEnvRelativeMinutesAgo(int count) {
    return '$count분 전';
  }

  @override
  String workspaceEnvRelativeHoursAgo(int count) {
    return '$count시간 전';
  }

  @override
  String workspaceEnvRelativeDaysAgo(int count) {
    return '$count일 전';
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
      '명령은 샌드박스가 아닌 이 컴퓨터에서 실행되며, ‘이 대화에서 모두 허용’을 켜지 않으면 승인이 필요합니다.';

  @override
  String get workspaceEnvRootfsTitle => '/';

  @override
  String get workspaceEnvBrowserUnavailable => '샌드박스 파일 시스템을 사용할 수 없습니다.';

  @override
  String get workspaceEnvMirrorNameOfficial => '공식';

  @override
  String get workspaceEnvMirrorNameOfficialCdn => '공식 CDN';

  @override
  String get workspaceEnvMirrorNameOfficialPypi => '공식 PyPI';

  @override
  String get workspaceEnvMirrorNameOfficialNpm => '공식 npm';

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
  String get workspaceFilesEmptyPickerHint => '‘새 폴더’로 하위 폴더를 추가하세요';

  @override
  String get skillsDetailBodyEmpty => '아직 스킬 본문이 없습니다';

  @override
  String skillsDetailBodyTooLarge(String size) {
    return '이 파일은 너무 커서 미리 볼 수 없습니다($size).';
  }

  @override
  String get workspaceEnvSizeTimeout => '계산 시간 초과';

  @override
  String get workspaceEnvInfoCopied => '환경 정보 복사됨';

  @override
  String get workspacePreviewEmptyFile => '이 파일은 비어 있습니다';

  @override
  String get workspacePreviewEmptyHint => '미리 볼 내용이 없습니다.';

  @override
  String get workspacePreviewRevealInExplorer => '파일 탐색기에서 보기';

  @override
  String get workspacePreviewRevealInFileManager => '파일 관리자에서 보기';

  @override
  String workspaceBindingSetAssistantDefault(String assistant) {
    return '“$assistant”의 기본 워크스페이스로 설정됨';
  }

  @override
  String get storageSpaceCategoryWorkspaceFiles => '워크스페이스 파일';

  @override
  String get storageSpaceCategoryWorkspaceFilesHint => '관리형 워크스페이스에 저장된 파일입니다.';

  @override
  String get storageSpaceCategorySandboxEnvironment => '샌드박스 환경';

  @override
  String get storageSpaceCategorySandboxEnvironmentHint =>
      '샌드박스 설치 디렉터리와 루트 파일 시스템입니다.';

  @override
  String get storageSpaceCategorySkills => '스킬';

  @override
  String get storageSpaceCategorySkillsHint => '설치된 스킬 파일입니다.';

  @override
  String get storageSpaceCategorySessionFiles => '대화 파일';

  @override
  String get storageSpaceCategorySessionFilesHint => '대화별 첨부 파일과 출력 파일입니다.';

  @override
  String get storageSpaceManageSkills => '스킬 관리';

  @override
  String get storageSessionFilesCleanOrphans => '소속 없는 대화 파일 정리';

  @override
  String storageSessionFilesCleanOrphansHint(String size) {
    return '연결된 대화가 없는 대화 파일 폴더를 삭제합니다. 확보 가능한 용량: $size.';
  }

  @override
  String get workspaceDesktopFolderPath => '폴더 경로';

  @override
  String get workspaceDesktopFolderMissing => '기존 폴더를 선택하거나 폴더의 절대 경로를 입력하세요.';

  @override
  String get workspaceDesktopManagedHint => 'Kelivo가 이 프로젝트용 폴더를 만들고 관리합니다.';

  @override
  String get workspaceDesktopHostHint => '이 컴퓨터에서 파일에 액세스하고 명령을 실행합니다.';

  @override
  String get workspaceDesktopSearch => '워크스페이스 검색';

  @override
  String get workspaceDesktopNoResults => '일치하는 워크스페이스가 없습니다';

  @override
  String get workspaceEnvDependencies => '환경 프리셋';

  @override
  String get workspaceEnvDependenciesDetail =>
      '공유 샌드박스에 도구를 설치합니다. 모든 워크스페이스에서 사용할 수 있습니다.';

  @override
  String get workspaceEnvDependencyPython => 'Python, pip 및 가상 환경';

  @override
  String get workspaceEnvDependencyNode => 'Node.js 및 npm';

  @override
  String get workspaceEnvDependencyGit => '리포지토리 복제 및 버전 관리';

  @override
  String get workspaceEnvDependencySsh => 'SSH, SCP, SFTP 및 키 생성';

  @override
  String get workspaceEnvDependencyNetwork => '네트워크 도구';

  @override
  String get workspaceEnvDependencyArchive => '압축 도구';

  @override
  String get workspaceEnvDependencyInstalled => '설치됨';

  @override
  String get workspaceEnvDependencyUnknown => '확인되지 않음';

  @override
  String get workspaceEnvDependencyChecking => '도구 확인 중…';

  @override
  String get workspaceEnvDependencyInstalling => '설치 중…';

  @override
  String get workspaceEnvDependencyCheckFailed =>
      '도구를 확인하지 못했습니다. 새로고침을 눌러 다시 시도하세요.';

  @override
  String get workspaceEnvDependencyInstallFailed =>
      '설치가 완료되지 않았습니다. 로그를 확인하거나 패키지 소스를 변경한 후 다시 시도하세요.';

  @override
  String get workspaceEnvDependencyLog => '설치 로그';

  @override
  String get workspaceEnvDependencyRefresh => '도구 상태 새로고침';

  @override
  String get workspaceEnvDependencyReadyFirst => '이 도구를 추가하려면 먼저 샌드박스를 설치하세요.';

  @override
  String get workspaceEnvDependencySources => '패키지 소스';

  @override
  String get workspaceEnvDependencySourcesDetail =>
      '프리셋은 선택한 apt/apk 소스로 설치됩니다. pip 및 npm 소스는 이후에 설치하는 패키지에 적용됩니다.';

  @override
  String get workspaceEnvDownloadSource => '샌드박스 다운로드 소스';

  @override
  String get workspaceEnvDownloadAutomatic => '가장 빠른 소스 자동 선택';

  @override
  String get workspaceEnvDownloadAutomaticDetail =>
      '다운로드 전에 공식 소스와 내장 미러의 속도를 테스트합니다.';

  @override
  String get workspaceEnvDownloadCustom => '사용자 지정 URL';

  @override
  String get workspaceEnvDownloadCustomHint =>
      'https://example.com/ubuntu-base/releases/24.04/release/';

  @override
  String get workspaceEnvDownloadCustomDetail =>
      '릴리스 디렉터리나 압축 파일의 전체 URL을 입력하세요. 압축 파일은 선택한 시스템, 버전, 기기 아키텍처와 일치해야 합니다.';

  @override
  String get workspaceEnvDownloadInvalidUrl => '유효한 HTTP 또는 HTTPS URL을 입력하세요.';

  @override
  String get workspaceEnvDownloadVerified =>
      '다운로드한 파일은 선택한 이미지의 공식 SHA-256 값으로 검증됩니다. 패키지 소스는 별도로 구성할 수 있습니다.';

  @override
  String get workspaceEnvDownloadStart => '다운로드 후 설치';

  @override
  String get workspaceEnvDownloadSave => '저장';

  @override
  String get workspaceToolsTitle => '도구';

  @override
  String get workspaceToolsDescription =>
      '이 워크스페이스의 대화에서 사용할 수 있는 도구를 선택하세요. 변경 사항은 자동으로 저장됩니다.';

  @override
  String get workspaceToolHelpShell => '워크스페이스 환경에서 명령을 실행합니다.';

  @override
  String get workspaceToolHelpRead => '줄 번호와 함께 파일을 읽으며, 필요한 부분만 나눠 읽을 수 있습니다.';

  @override
  String get workspaceToolHelpViewImage => '모델이 워크스페이스의 이미지를 살펴보도록 허용합니다.';

  @override
  String get workspaceToolHelpWrite => '파일을 만들거나 내용을 덮어씁니다.';

  @override
  String get workspaceToolHelpEdit => '기존 파일의 특정 텍스트를 바꿉니다.';

  @override
  String get workspaceToolHelpList => '디렉터리와 그 안의 항목을 탐색합니다.';

  @override
  String get workspaceToolHelpGlob => '이름이나 경로 패턴으로 파일을 찾습니다.';

  @override
  String get workspaceToolHelpGrep => '파일 안의 텍스트를 검색합니다.';

  @override
  String get workspaceEnvVariablesTitle => '환경 변수';

  @override
  String get workspaceEnvVariablesEntryDetail => '명령에서 쓰는 변수와 출력 가리기 설정';

  @override
  String get workspaceEnvVariablesEmpty =>
      '아직 변수가 없습니다. 도구에 필요한 API 키나 기타 구성 값을 추가하세요.';

  @override
  String get workspaceEnvVariablesScope =>
      '모든 워크스페이스에서 공유됩니다. 변경 사항은 새 에이전트 명령과 새 앱 내 터미널 세션에 적용됩니다. 기존 세션에 적용하려면 세션을 다시 여세요. 외부 시스템 터미널은 자체 환경 변수를 유지합니다.';

  @override
  String get workspaceEnvPrivacyMode => '민감 정보 가리기';

  @override
  String get workspaceEnvPrivacyDetail =>
      '명령에서는 실제 값을 사용할 수 있습니다. 워크스페이스 도구 출력이 모델로 전송되기 전에, 출력에 포함된 5자 이상의 변수 값이 [REDACTED]로 바뀝니다. 로컬 로그는 변경되지 않습니다. 일반적인 플래그와 숫자가 잘못 바뀌지 않도록 이보다 짧은 값은 가리지 않습니다.';

  @override
  String get workspaceEnvVariableAdd => '변수 추가';

  @override
  String get workspaceEnvVariableEdit => '변수 편집';

  @override
  String get workspaceEnvVariableName => '이름';

  @override
  String get workspaceEnvVariableValue => '값';

  @override
  String get workspaceEnvVariableNote => '메모(선택 사항)';

  @override
  String get workspaceEnvVariableNameHint =>
      '영문자, 숫자, 밑줄을 사용하고 숫자로 시작하지 마세요. 이름은 대소문자를 구분합니다. 명령에서는 \$NAME 형식으로 변수를 참조하세요.';

  @override
  String get workspaceEnvVariableInvalidName => '유효한 변수 이름을 입력하세요.';

  @override
  String get workspaceEnvVariableInvalidValue =>
      '비어 있지 않고 NUL 문자가 없는 값을 입력하세요.';

  @override
  String get workspaceEnvVariableDuplicate => '같은 이름의 변수가 이미 있습니다.';

  @override
  String get workspaceEnvVariablesSaveFailed =>
      '환경 변수 설정을 저장하지 못했습니다. 다시 시도하세요.';

  @override
  String get incomingShareTitle => '공유된 콘텐츠';

  @override
  String get incomingShareReplaceDraft =>
      '입력창에 보내지 않은 내용이 있습니다. 공유된 콘텐츠로 교체하고 새 채팅을 시작하시겠습니까?';

  @override
  String get incomingShareFailed =>
      '공유된 콘텐츠 중 일부를 가져오지 못했습니다. 파일 액세스 권한과 사용 가능한 저장 공간을 확인하세요. 파일은 한 번에 최대 32개까지 공유할 수 있습니다.';

  @override
  String get incomingShareImporting => '가져오는 중';

  @override
  String get incomingShareMoveTo => '이동…';

  @override
  String get incomingShareNewChat => '새 대화';

  @override
  String get incomingShareMoveHint =>
      '이 초안과 첨부 파일을 다른 대화로 옮깁니다. 자동으로 전송되지 않습니다.';

  @override
  String get incomingShareNoConversations => '일치하는 대화가 없습니다';

  @override
  String get chatInputBarRemoveAttachment => '첨부 파일 제거';

  @override
  String get incomingShareMoveFailed => '대화를 전환하지 못했습니다. 초안은 그대로 유지되었습니다.';

  @override
  String attachmentRequiresWorkspace(String name) {
    return '“$name” 파일을 사용하려면 워크스페이스를 지정하고 파일 도구를 활성화하거나, 이 초안을 워크스페이스가 있는 대화로 옮기세요. 이 파일은 일반 대화에서 바로 읽을 수 없습니다.';
  }

  @override
  String get storageSessionFilesUnlinked => '소속 없는 대화 파일';

  @override
  String get workspaceExternalMount => '외부 폴더 마운트';

  @override
  String get workspaceExternalMountSubtitle =>
      '선택한 폴더는 /mounts/<name>에 마운트되어 모든 워크스페이스에서 공유됩니다. AI 도구, 셸, 파일 브라우저에서 이 폴더에 액세스할 수 있습니다. 최대 10개까지 마운트할 수 있습니다.';

  @override
  String get workspaceExternalStorageTitle => '파일 액세스 허용';

  @override
  String get workspaceExternalStorageMessage =>
      '워크스페이스와 셸에서 외부 폴더를 읽고 쓰려면 Android 설정에서 Kelivo가 파일을 관리하도록 허용하세요. Android 11 이상에서는 ‘모든 파일 액세스’를 활성화하세요. 그런 다음 마운트할 기기 내 폴더를 선택하세요.';

  @override
  String get workspaceExternalGrantAccess => '권한 허용';

  @override
  String get workspaceExternalLocalOnly =>
      'Android에서는 기기 내 폴더만 마운트할 수 있습니다. 이 문서 제공 앱은 셸에서 액세스할 수 있는 로컬 폴더를 제공하지 않습니다.';

  @override
  String get workspaceExternalUnavailable =>
      '외부 폴더를 사용할 수 없습니다. 저장소 연결과 권한을 확인한 다음, 폴더를 다시 선택해 액세스를 복원하세요.';

  @override
  String get workspaceExternalReconnect => '폴더 다시 선택';

  @override
  String get workspaceMountAdd => '폴더 추가';

  @override
  String get workspaceMountEdit => '마운트 편집';

  @override
  String get workspaceMountEmpty => '마운트된 폴더 없음';

  @override
  String get workspaceMountReadOnly => '읽기 전용';

  @override
  String get workspaceMountReadWrite => '읽기 및 쓰기';

  @override
  String get workspaceMountAllowWrite => '쓰기 허용';

  @override
  String get workspaceMountPermissionsHint =>
      'AI 파일 도구와 파일 브라우저는 이 설정을 따릅니다. 셸은 일반적인 파일 명령만 검사하므로 임의의 스크립트는 이 제한을 우회할 수 있습니다. 마운트 변경 사항을 저장하면 실행 중인 명령과 터미널 세션이 중지됩니다.';

  @override
  String get workspaceMountBrowse => '파일 찾아보기';

  @override
  String get workspaceMountUnmount => '마운트 해제';

  @override
  String get workspaceMountUnmountMessage =>
      '이 마운트를 해제하시겠습니까? 원본 폴더와 그 안의 파일은 유지됩니다.';

  @override
  String get workspaceMountInactive => '사용할 수 없음: 폴더를 다시 선택하세요';

  @override
  String get workspaceMountInvalidName =>
      '이름은 슬래시, 콜론, 제어 문자 없이 64자 이하로 입력하세요. 또한 . 또는 ..은 이름으로 사용할 수 없습니다.';

  @override
  String get workspaceMountDuplicate => '같은 이름의 마운트가 이미 있습니다.';

  @override
  String get workspaceMountLimit =>
      '폴더는 최대 10개까지 마운트할 수 있습니다. 다른 폴더를 추가하려면 먼저 마운트를 하나 해제하세요.';

  @override
  String get workspaceMountOverlap =>
      '이 폴더가 기존 마운트와 겹칩니다. 권한이 충돌하지 않도록 다른 폴더를 선택하세요.';

  @override
  String get workspaceMountTargetOccupied =>
      '/mounts 아래의 마운트 경로에 이미 로컬 파일이 있습니다. 다른 마운트 이름을 선택하거나 먼저 그 파일을 다른 곳으로 이동하세요. 기존 파일은 제거되지 않았습니다.';

  @override
  String get workspaceEnvSystemImage => '시스템 이미지';

  @override
  String get workspaceEnvDistribution => '배포판';

  @override
  String get workspaceEnvSystemVersion => '버전';

  @override
  String get workspaceEnvLocalImage => '로컬 이미지';

  @override
  String get workspaceEnvChooseImage => 'rootfs 압축 파일 선택';

  @override
  String get workspaceEnvLocalImageHint =>
      'ISO나 디스크 이미지가 아닌 루트 파일 시스템 압축 파일(.tar.gz, .tar.xz 또는 .tar)을 가져오세요. 압축 파일은 이 기기의 CPU 아키텍처와 일치해야 하며 /bin/sh를 포함해야 합니다. 시스템과 버전은 압축을 해제한 후 자동으로 인식됩니다.';

  @override
  String get workspaceEnvImportImage => '이미지 가져오기';

  @override
  String get workspaceEnvInvalidImage =>
      '이 기기에 맞는 유효한 rootfs 압축 파일을 선택하세요. CPU 아키텍처가 일치하는 실행 가능한 /bin/sh가 있어야 합니다.';

  @override
  String get workspaceEnvReplaceSystem => '시스템 교체';

  @override
  String get workspaceEnvReplaceSystemHint =>
      '현재 환경에 설치된 패키지와 파일을 교체하고, 실행 중인 명령과 터미널 세션을 중지합니다. 워크스페이스, 대화 파일, 외부 폴더는 유지됩니다. 새 이미지 준비에 실패하면 현재 환경이 그대로 보존됩니다.';

  @override
  String get workspaceEnvProotOptions => 'PRoot 옵션';

  @override
  String get workspaceEnvShellPath => '셸 경로';

  @override
  String get workspaceEnvShellAutomatic => '자동';

  @override
  String get workspaceEnvShellHint =>
      '비워 두면 /bin/bash를 사용하며, /bin/bash가 없으면 /bin/sh를 사용합니다. 사용자 지정 셸 경로는 환경 안의 절대 경로여야 합니다.';

  @override
  String get workspaceEnvProotArguments => '추가 PRoot 인수';

  @override
  String get workspaceEnvProotArgumentsHint =>
      '한 줄에 인수를 하나씩, 셸 따옴표 없이 입력하세요. 예를 들어 -k와 5.10.0을 각각 다른 줄에 입력하거나 --kernel-release=5.10.0을 사용하세요. 변경 사항은 이후에 시작하는 명령과 터미널 세션에 적용됩니다.';

  @override
  String get workspaceEnvProotInvalid =>
      '셸 경로에는 유효한 절대 경로를 입력하고, PRoot 인수는 한 줄에 하나씩 입력하세요.';

  @override
  String get workspaceFileMissing => '파일이 더 이상 존재하지 않습니다';

  @override
  String get workspaceFilePreviewUnavailable => '미리보기를 사용할 수 없음';

  @override
  String get workspaceToolRelatedFiles => '관련 파일';

  @override
  String get workspaceToolFilesTruncated => '일부 파일만 표시됩니다.';

  @override
  String get displaySettingsPageShowProducedFilesTitle => '응답 아래에 파일 표시';

  @override
  String get displaySettingsPageShowProducedFilesSubtitle =>
      '도구가 만들거나 수정한 파일을 응답 아래에 표시합니다.';

  @override
  String get defaultModelPagePerChatModelTitle => '채팅별 모델';

  @override
  String get defaultModelPagePerChatModelSubtitle =>
      '켜면 채팅에서 선택한 모델이 그 채팅에만 적용됩니다. 끄면 선택한 모델이 현재 어시스턴트의 모델이 되어, 이 어시스턴트를 사용하는 모든 채팅에 적용됩니다.';

  @override
  String get googleFontsTitle => 'Google Fonts';

  @override
  String get googleFontsRefresh => '글꼴 목록 새로고침';

  @override
  String get googleFontsSearchHint => '글꼴 또는 언어 검색';

  @override
  String get googleFontsHint =>
      '글꼴을 보통 굵기로 다운로드해 미리 보고 적용하세요. 설치한 글꼴은 오프라인에서도 사용할 수 있습니다. 카탈로그: Expo Google Fonts, 다운로드: Google Fonts.';

  @override
  String get googleFontsNoResults => '일치하는 글꼴이 없습니다';

  @override
  String get googleFontsFailed =>
      '글꼴을 불러오거나 다운로드하거나 적용하지 못했습니다. 연결을 확인하고 다시 시도하세요.';

  @override
  String get googleFontsDownloading => '글꼴 다운로드 중…';

  @override
  String get googleFontsPreview =>
      'The quick brown fox 0123456789 · 다람쥐 헌 쳇바퀴에 타고파';

  @override
  String get googleFontsLicense => '글꼴 라이선스';

  @override
  String get assistantEditLocationPermissionSettingsMessage =>
      '위치 권한이 차단되어 있습니다. 시스템 설정에서 위치 액세스를 허용한 다음 이 도구를 다시 켜세요.';

  @override
  String get healthDataSettingsCategoryReproductive => '생식 건강';

  @override
  String get healthDataSettingsTypeMenstrualFlowTitle => '생리 기록';

  @override
  String get healthDataSettingsTypeMenstrualFlowSubtitle =>
      '최근 90일 동안 기록된 생리량과 주기 시작일';

  @override
  String get assistantEditGradientBackgroundTitle => '그라데이션 배경';

  @override
  String get assistantEditGradientStaticTitle => '정적 모드';

  @override
  String get assistantEditGradientStaticDescription =>
      '긴 채팅이나 스트리밍 중에 전력을 절약합니다.';

  @override
  String get assistantEditGradientHorizontal => '가로 위치';

  @override
  String get assistantEditGradientVertical => '세로 위치';

  @override
  String get assistantEditGradientPreview => '미리보기';

  @override
  String get assistantEditGradientNextFrame => '다른 프레임';

  @override
  String get backgroundSettingsTitle => '백그라운드 작업';

  @override
  String get backgroundTaskTitle => 'Kelivo 작업';

  @override
  String get backgroundCompleted => '생성 완료';

  @override
  String get backgroundFailed => '생성에 실패했습니다. 채팅을 열어 자세한 내용을 확인하세요.';

  @override
  String get backgroundCancelled => '생성 취소됨';

  @override
  String get backgroundInterrupted => '백그라운드 생성이 중단되었습니다. 계속하려면 채팅을 여세요.';

  @override
  String get backgroundRequesting => '요청 중';

  @override
  String get backgroundGenerating => '응답 생성 중';

  @override
  String get backgroundThinking => '생각 중';

  @override
  String get backgroundToolRunning => '도구 실행 중';

  @override
  String get backgroundRetrying => '재시도 대기 중';

  @override
  String get backgroundWorking => '작업 중';

  @override
  String get backgroundTasks => '작업';

  @override
  String get backgroundStopTasks => '작업 중지';

  @override
  String get backgroundOpenChat => '채팅 열기';

  @override
  String get backgroundAndroidEnabled => '백그라운드 생성';

  @override
  String get backgroundAndroidEnabledDetail =>
      '화면이 잠기거나, 앱이 백그라운드로 전환되거나, 최근 앱 목록에서 지워져도 현재 작업을 계속 실행합니다. 작업이 실행되는 동안에는 진행 중 알림이 항상 표시됩니다.';

  @override
  String get backgroundIosEnabled => '향상된 백그라운드 실행';

  @override
  String get backgroundIosEnabledDetail =>
      '현재 작업을 마칠 시간을 시스템에 요청합니다. 백그라운드 실행을 보강하려면 위치 정보나 무음 오디오를 따로 활성화하세요.';

  @override
  String get backgroundNotifications => '작업 알림';

  @override
  String get backgroundNotificationsDetail =>
      '현재 보고 있지 않은 채팅에서 작업이 완료되거나 실패하면 알림을 보냅니다. Android에서 필수로 표시되는 진행 중 알림은 이 설정으로 제어되지 않습니다.';

  @override
  String get backgroundPrivacy => '작업 상태 개인정보 보호';

  @override
  String get backgroundPrivacyDetail =>
      '알림과 실시간 상태에서 대화 제목과 도구 세부 정보를 숨깁니다. 일반 상태, 작업 수, 경과 시간만 표시됩니다.';

  @override
  String get backgroundLiveActivities => '실시간 현황';

  @override
  String get backgroundLiveActivitiesDetail =>
      '잠금 화면과 Dynamic Island에 현재 작업을 표시합니다. 사용 가능 여부와 표시 방식은 시스템에 따라 다릅니다.';

  @override
  String get backgroundOverlay => '작업 플로팅 창';

  @override
  String get backgroundOverlayDetail =>
      '다른 앱 위에 드래그할 수 있는 작업 캡슐을 표시합니다. 캡슐을 누르면 채팅이 열리며, 닫으면 캡슐만 숨겨집니다.';

  @override
  String get backgroundLiveUpdates => '실시간 업데이트';

  @override
  String get backgroundLiveUpdatesDetail =>
      '지원되는 기기에서 Android 16 실시간 업데이트를 사용합니다. 실시간 업데이트로 표시된 알림은 플로팅 캡슐보다 우선합니다.';

  @override
  String get backgroundLocation => '위치 정보로 실행 유지';

  @override
  String get backgroundLocationDetail =>
      '백그라운드 작업 중에 대략적인 위치 업데이트를 사용합니다. 좌표는 저장되지 않으며 AI 서비스로 전송되지도 않습니다. 향상된 백그라운드 실행과 위치 권한이 필요합니다.';

  @override
  String get backgroundSilentAudio => '무음 오디오로 실행 유지';

  @override
  String get backgroundSilentAudioDetail =>
      '백그라운드 작업이 실행되는 동안 무음 오디오를 재생합니다. 녹음하거나 소리 내어 읽는 중에는 재생을 멈춥니다. 향상된 백그라운드 실행이 필요하지만 마이크 권한은 필요하지 않습니다.';

  @override
  String get backgroundSpeech => '백그라운드에서 소리 내어 읽기';

  @override
  String get backgroundSpeechDetail =>
      '화면이 잠기거나 앱이 백그라운드로 전환되어도 시스템 TTS와 네트워크 TTS로 계속 소리 내어 읽습니다. 비활성화하면 앱이 백그라운드로 전환될 때 소리 내어 읽기가 일시 중지됩니다.';

  @override
  String get backgroundFinishVisibility => '완료 상태 표시 시간';

  @override
  String get backgroundFinishImmediately => '즉시 닫기';

  @override
  String get backgroundFinishOneMinute => '1분';

  @override
  String get backgroundFinishFiveMinutes => '5분';

  @override
  String get backgroundFinishUntilForeground => '앱으로 돌아올 때까지';

  @override
  String get backgroundFinishVisibilityDetail =>
      'Android 캡슐과 iOS 잠금 화면의 완료 카드에 적용됩니다. 앱으로 돌아오면 완료 상태가 지워지며, 최대 표시 시간은 15분입니다. 작업을 취소하면 즉시 닫힙니다.';

  @override
  String get backgroundOverlayIcon => '플로팅 아이콘';

  @override
  String get backgroundIconDefault => 'Kelivo 아이콘';

  @override
  String get backgroundIconImage => '이미지 선택';

  @override
  String get backgroundIconEmoji => '이모지 선택';

  @override
  String get backgroundPermissionsTitle => '권한 및 시스템 설정';

  @override
  String get backgroundNotificationsPermission => '알림 권한';

  @override
  String get backgroundBatteryOptimization => '배터리 최적화';

  @override
  String get backgroundBatteryOptimizationDetail =>
      '백그라운드 작업을 더 안정적으로 실행하려면 배터리를 제한 없이 사용하도록 허용하세요.';

  @override
  String get backgroundAutostart => '자동 실행 및 백그라운드 사용';

  @override
  String get backgroundAutostartDetail =>
      '기기의 자동 실행 및 백그라운드 제한 설정을 직접 확인하세요. Android에서는 이러한 제조사 설정의 권한 상태를 정확하게 조회할 수 없습니다.';

  @override
  String get backgroundLocationPermission => '위치 권한';

  @override
  String get backgroundLocationAlways => '백그라운드 위치 허용';

  @override
  String get backgroundLocationAlwaysDetail =>
      '백그라운드에서 위치를 사용할 수 있도록 위치 액세스를 ‘항상’으로 허용할 수 있습니다. 이 항목을 선택할 때만 권한을 요청합니다.';

  @override
  String get backgroundSystemSettings => '앱 시스템 설정';

  @override
  String get backgroundPermissionGranted => '허용됨';

  @override
  String get backgroundPermissionDenied => '허용되지 않음';

  @override
  String get backgroundPermissionLimited => '앱을 사용하는 동안';

  @override
  String get backgroundPermissionUnknown => '직접 확인 필요';

  @override
  String get backgroundPermissionNotDetermined => '요청되지 않음';

  @override
  String get backgroundRuntimeTitle => '현재 상태';

  @override
  String get backgroundRuntimeActive => '실행 중';

  @override
  String get backgroundRuntimeIdle => '비활성';

  @override
  String get backgroundLocationActive => '백그라운드 위치';

  @override
  String get backgroundAudioActive => '무음 오디오';

  @override
  String get backgroundActivityActive => '실시간 현황';

  @override
  String get backgroundOverlayActive => '플로팅 창';

  @override
  String get backgroundLastError => '마지막 중단 또는 오류';

  @override
  String get backgroundNoError => '기록 없음';

  @override
  String get backgroundUnsupported => '이 기기에서 사용할 수 없거나 시스템 설정에서 비활성화되어 있습니다';

  @override
  String get backgroundIosLimit =>
      '백그라운드 실행은 iOS가 제어합니다. 실시간 현황만으로는 앱이 계속 실행되지 않습니다. 앱을 강제 종료하면 생성이 중단될 수 있으며, 앱을 다시 열 때까지 실시간 상태가 지워지지 않을 수 있습니다.';

  @override
  String get backgroundAndroidLimit =>
      '작업이 멈추면 알림, 배터리, 제조사의 백그라운드 설정을 확인하세요. 이렇게 설정해도 강제 중지나 시스템의 프로세스 종료로 생성이 중단될 수 있습니다.';

  @override
  String get backgroundStale => '상태가 업데이트되지 않았습니다. 앱을 열어 확인하세요.';

  @override
  String get backgroundIconError => '이 이미지를 가져올 수 없습니다. 다른 이미지를 선택하세요.';

  @override
  String get backgroundNotificationChannels => '알림 설정';

  @override
  String get backgroundCompletionChannel => '완료 알림 카테고리';

  @override
  String get backgroundOngoingChannel => '실행 중인 작업 알림 카테고리';

  @override
  String get backgroundOverlayAppearance => '플로팅 창 모양';

  @override
  String get backgroundOverlayAppearanceDetail => '크기, 아이콘, 진행률 링, 표시 내용';

  @override
  String get backgroundOverlayPreviewHint => '드래그하여 이동 · 눌러서 채팅 열기 · 길게 눌러 닫기';

  @override
  String get backgroundOverlayCard => '카드';

  @override
  String get backgroundOverlayCircle => '원형 아이콘';

  @override
  String get backgroundOverlaySize => '크기 및 모양';

  @override
  String get backgroundOverlayWidth => '너비';

  @override
  String get backgroundOverlayHeight => '높이';

  @override
  String get backgroundOverlayCornerRadius => '모서리 반경';

  @override
  String get backgroundOverlayIconSize => '아이콘 크기';

  @override
  String get backgroundOverlayProgressSize => '진행률 링 지름';

  @override
  String get backgroundOverlayProgressStroke => '진행률 링 두께';

  @override
  String get backgroundOverlayContent => '표시 내용';

  @override
  String get backgroundOverlayShowProgress => '진행률 링 표시';

  @override
  String get backgroundOverlayShowTitle => '제목 표시';

  @override
  String get backgroundOverlayShowSubtitle => '부제목 표시';

  @override
  String get backgroundOverlayShowTime => '경과 시간 표시';

  @override
  String get backgroundOverlayShowClose => '닫기 버튼 표시';

  @override
  String get backgroundOverlayShowBackground => '배경 표시';

  @override
  String get backgroundOverlayShowBorder => '테두리 표시';

  @override
  String get backgroundOverlayReset => '기본 모양 복원';

  @override
  String get mcpStdioEnvironmentRequired =>
      '모바일에서 STDIO를 사용하려면 워크스페이스 환경을 설치하세요.';

  @override
  String get mcpArgumentsHint =>
      '인수는 공백으로 구분하고, 공백이 포함된 값은 따옴표로 묶으세요. 빈 인수는 \'\'로 입력하세요.';

  @override
  String get mcpArgumentsInvalid =>
      '인수에 닫히지 않은 따옴표나 끝에 남은 이스케이프 문자가 있는지 확인하세요.';

  @override
  String get mcpImportEnvironment => '환경 변수에서 가져오기';

  @override
  String get mcpEnvironmentEmpty => '환경 변수가 없습니다. ‘환경 변수’ 설정에서 추가하세요.';

  @override
  String get mcpEnvironmentHint =>
      '기본적으로 환경 변수를 상속합니다. 이 서버에서 값을 따로 설정하려면 변수를 가져오세요.';

  @override
  String get mcpImportJson => 'JSON 가져오기';

  @override
  String get mcpImportJsonHint =>
      'Claude Desktop 또는 Cursor의 MCP 구성을 붙여넣으세요. 미리보기로 확인한 후 서버를 추가할 수 있으며, 기존 서버는 교체되지 않습니다.';

  @override
  String get mcpImportPaste => '클립보드에서 붙여넣기';

  @override
  String get mcpImportPreview => '미리보기';

  @override
  String get mcpImportConfirm => '가져오기';

  @override
  String get startupRecoverySnapshotTitle => '로컬 사본에서 복원';

  @override
  String get startupRecoverySnapshotBody =>
      '데이터베이스가 열리지 않아도 이 기기의 로컬 사본을 선택해 채팅과 설정을 복원할 수 있습니다. Kelivo를 제거하지 마세요. 앱을 제거하면 이 사본도 함께 삭제됩니다.';

  @override
  String get startupRecoverySnapshotEmpty =>
      '이 기기에서 로컬 사본을 찾을 수 없습니다. 다른 복구 작업을 시도하기 전에 데이터를 내보내세요.';

  @override
  String get startupRecoverySnapshotButton => '사본 선택';

  @override
  String startupRecoverySnapshotConfirm(String when) {
    return '$when의 채팅과 설정으로 복원하시겠습니까? 이 사본 이후의 변경 사항은 포함되지 않습니다. 기존 첨부 파일과 이 사본은 유지됩니다. Kelivo가 다시 시작되어 복원을 완료합니다.';
  }

  @override
  String startupRecoverySnapshotFailed(String reason) {
    return '사본 복원을 준비하지 못했습니다: $reason';
  }

  @override
  String get startupRecoverySnapshotReady =>
      '사본이 준비되었습니다. 복원을 완료하려면 Kelivo를 다시 시작하세요.';

  @override
  String get scheduledTasksTitle => '예약된 작업';

  @override
  String get scheduledTasksDescription =>
      '선택한 시간에 작업을 자동으로 실행합니다. 새 채팅을 시작하거나, 후속 질문을 보내거나, 질문을 다시 실행할 수 있습니다.';

  @override
  String get scheduledTasksEmpty => '반복할 일은 예약해 두세요';

  @override
  String get scheduledTasksEmptyDetail =>
      '아침 브리핑, 하루 회고 등 정기적으로 실행할 작업을 추가하세요.';

  @override
  String get scheduledTasksAdd => '작업 추가';

  @override
  String get scheduledTasksEdit => '작업 편집';

  @override
  String get scheduledTasksName => '이름';

  @override
  String get scheduledTasksNameHint => '아침 브리핑';

  @override
  String get scheduledTasksPrompt => '프롬프트';

  @override
  String get scheduledTasksPromptHint => '어시스턴트에게 맡길 작업을 입력하세요';

  @override
  String get scheduledTasksAssistant => '어시스턴트';

  @override
  String get scheduledTasksChooseAssistant => '어시스턴트 선택';

  @override
  String get scheduledTasksAssistantMissing => '어시스턴트를 사용할 수 없음';

  @override
  String get scheduledTasksTime => '시간';

  @override
  String get scheduledTasksTimeHint => '24시간제(예: 08:00)';

  @override
  String get scheduledTasksRepeat => '반복';

  @override
  String get scheduledTasksEveryDay => '매일';

  @override
  String get scheduledTasksWeekdays => '평일';

  @override
  String get scheduledTasksEnabled => '활성화';

  @override
  String get scheduledTasksPermission => '알람 및 리마인더';

  @override
  String get scheduledTasksPermissionDetail =>
      '선택한 시간에 작업을 실행하려면 정확한 알람을 허용하세요. 권한이 허용될 때까지 활성화된 작업은 대기합니다.';

  @override
  String get scheduledTasksPermissionAction => '허용';

  @override
  String get scheduledTasksReliability =>
      '더 안정적으로 실행하려면 배터리 설정에서 Kelivo를 ‘제한 없음’으로 설정해 두세요. 앱을 강제 중지하면 알람이 취소되며, 앱을 다시 열면 다시 설정됩니다. 놓친 실행은 건너뛰며, 작업은 기기의 시간대를 따릅니다.';

  @override
  String get scheduledTasksExecutionDetail =>
      '결과는 채팅에 저장됩니다. 완료 알림에서 응답을 미리 볼 수 있으며, 알림을 누르면 그 채팅이 열립니다. 실행은 10분이 지나거나 사용자 입력 또는 도구 승인이 필요하면 중지됩니다.';

  @override
  String get scheduledTasksRunNow => '지금 실행';

  @override
  String get scheduledTasksHistory => '실행 기록';

  @override
  String get scheduledTasksNoRuns => '아직 실행 기록이 없습니다';

  @override
  String get scheduledTasksRunning => '실행 중';

  @override
  String get scheduledTasksCompleted => '완료';

  @override
  String get scheduledTasksFailed => '실패';

  @override
  String get scheduledTasksInterrupted => '중단됨';

  @override
  String get scheduledTasksPaused => '일시 중지됨';

  @override
  String get scheduledTasksWaitingPermission => '권한 대기 중';

  @override
  String scheduledTasksNextRun(String time) {
    return '다음: $time';
  }

  @override
  String get scheduledTasksDelete => '작업 삭제';

  @override
  String get scheduledTasksDeleteDetail =>
      '이 작업과 실행 기록을 삭제하시겠습니까? 이미 생성된 대화는 유지됩니다.';

  @override
  String get scheduledTasksSave => '저장';

  @override
  String get scheduledTasksCancel => '취소';

  @override
  String get scheduledTasksInvalid =>
      '이름과 프롬프트를 입력하고 어시스턴트를 선택한 다음, 사용자 지정 반복이라면 요일도 하나 이상 선택하세요.';

  @override
  String get scheduledTasksLoading => '불러오는 중…';

  @override
  String get scheduledTasksOpenChat => '대화 보기';

  @override
  String get scheduledTasksNeedsInput =>
      '사용자 입력이나 도구 승인이 필요해 중지되었습니다. 계속하려면 대화를 여세요.';

  @override
  String get scheduledTasksTimeout => '실행 제한 시간에 도달했습니다.';

  @override
  String get scheduledTasksProcessTerminated => 'Android가 이전 실행을 중지했습니다.';

  @override
  String get scheduledTasksOnce => '한 번';

  @override
  String get scheduledTasksCustom => '사용자 지정';

  @override
  String get scheduledTasksExecution => '작업';

  @override
  String get scheduledTasksMode => '실행 방식';

  @override
  String get scheduledTasksNewChat => '새 채팅';

  @override
  String get scheduledTasksFollowUp => '후속 질문';

  @override
  String get scheduledTasksRegenerate => '다시 실행';

  @override
  String get scheduledTasksChat => '대상 대화';

  @override
  String get scheduledTasksChooseChat => '대화 선택';

  @override
  String get scheduledTasksMessage => '다시 실행할 질문';

  @override
  String get scheduledTasksChooseMessage => '질문 선택';

  @override
  String get scheduledTasksAttachmentMessage => '첨부 파일이 있는 메시지';

  @override
  String get scheduledTasksModel => '모델';

  @override
  String get scheduledTasksChooseModel => '모델 선택';

  @override
  String get scheduledTasksModelDefault => '대화 또는 어시스턴트 모델 사용';

  @override
  String get scheduledTasksSchedule => '일정';

  @override
  String get scheduledTasksActiveWindow => '실행 기간';

  @override
  String get scheduledTasksStartDate => '시작 날짜';

  @override
  String get scheduledTasksEndDate => '종료 날짜';

  @override
  String get scheduledTasksActiveWindowDetail =>
      '이 기간 안에서만 실행되며, 종료 날짜도 포함됩니다. 날짜를 설정하지 않으면 제한이 없습니다.';

  @override
  String get scheduledTasksDate => '날짜';

  @override
  String get scheduledTasksDateUnrestricted => '제한 없음';

  @override
  String get scheduledTasksClear => '지우기';

  @override
  String get scheduledTasksSearch => '검색';

  @override
  String get scheduledTasksNoTargets => '이 어시스턴트에는 일치하는 항목이 없습니다';

  @override
  String get scheduledTasksFutureDate => '실행 날짜와 시간은 현재 이후로 선택하세요.';

  @override
  String get scheduledTasksDateRangeInvalid => '종료 날짜는 시작 날짜와 같거나 그 이후여야 합니다.';

  @override
  String get scheduledTasksRegenerateDetail =>
      '선택한 질문에 대해 원래 컨텍스트로 새 답변을 생성합니다. 기존 답변과 이후 메시지는 유지됩니다.';

  @override
  String get scheduledTasksSaving => '저장 중…';

  @override
  String get scheduledTasksFinished => '일정 종료';

  @override
  String get scheduledTasksModelMissing =>
      '선택한 모델을 사용할 수 없습니다. 이 작업을 편집해 다른 모델을 선택하세요.';

  @override
  String get scheduledTasksChatMissing => '대상 대화를 사용할 수 없거나 다른 어시스턴트에 속해 있습니다.';

  @override
  String get scheduledTasksMessageMissing => '선택한 질문을 더 이상 사용할 수 없습니다.';

  @override
  String get scheduledTasksChatBusy =>
      '이 대화에서 응답을 생성하는 중입니다. 이번 예약 실행은 건너뛰었습니다.';

  @override
  String get scheduledTasksDesktopEmpty => '예약된 작업 없음';

  @override
  String get scheduledTasksDesktopReliability =>
      '작업은 Kelivo가 실행 중일 때만 실행되며, 창을 최소화했거나 시스템 트레이에 있을 때도 실행됩니다. Kelivo가 종료되어 있거나 컴퓨터가 절전 모드인 동안 놓친 실행은 건너뜁니다. Kelivo는 자동으로 시작되지 않습니다.';

  @override
  String get scheduledTasksDesktopExecutionDetail =>
      '결과는 채팅에 저장됩니다. 작업의 실행 기록에서 결과를 열 수 있습니다. 실행은 10분이 지나거나 사용자 입력 또는 도구 승인이 필요하면 중지됩니다.';

  @override
  String get worldBookStickyLabel => '유지(메시지 수)';

  @override
  String get worldBookStickyHint =>
      '트리거된 후 메시지 N개 동안 이 항목을 활성 상태로 유지합니다. 키워드가 반복해서 일치해도 유지 기간은 늘어나지 않습니다. 0으로 설정하면 이 기능이 비활성화됩니다.';

  @override
  String get worldBookCooldownLabel => '쿨다운(메시지 수)';

  @override
  String get worldBookCooldownHint =>
      '트리거된 후 또는 유지 기간이 끝난 후 메시지 N개 동안 다시 트리거되지 않도록 합니다. 0으로 설정하면 이 기능이 비활성화됩니다.';

  @override
  String get worldBookDelayLabel => '지연(메시지 수)';

  @override
  String get worldBookDelayHint =>
      '대화의 메시지가 N개 이상일 때만 이 항목이 트리거되도록 허용합니다. 주고받은 횟수가 아니라 개별 메시지 수로 셉니다. 0으로 설정하면 이 기능이 비활성화됩니다.';

  @override
  String get worldBookDragToReorder => '드래그하여 순서 변경';

  @override
  String worldBookEnabledCount(int enabled, int total) {
    return '$enabled/$total개 활성화됨';
  }

  @override
  String get assistantConversationSystemPromptTitle => '대화별 시스템 프롬프트';

  @override
  String get assistantConversationSystemPromptHint =>
      '각 대화가 자체 시스템 프롬프트를 사용하도록 허용합니다.';

  @override
  String get assistantConversationInjectionTitle => '대화별 지침 주입';

  @override
  String get assistantConversationInjectionHint =>
      '대화마다 지침 주입과 월드북을 따로 선택합니다. 기본적으로 아무것도 선택되지 않습니다.';

  @override
  String get conversationSystemPromptTitle => '대화 시스템 프롬프트';

  @override
  String get conversationSystemPromptHint =>
      '이 대화에만 적용됩니다. 비워 두면 어시스턴트의 시스템 프롬프트를 사용합니다.';

  @override
  String get conversationSystemPromptClear => '어시스턴트 프롬프트 사용';

  @override
  String get conversationSystemPromptPlaceholder => '이 대화의 시스템 프롬프트 작성…';

  @override
  String get conversationPromptScope => '이 대화만';

  @override
  String get oauthAccountsTab => '계정';

  @override
  String get oauthLogin => '로그인';

  @override
  String oauthLoginTo(String provider) {
    return '$provider에 로그인';
  }

  @override
  String get oauthConnected => '연결됨';

  @override
  String get oauthNotConnected => '연결되지 않음';

  @override
  String oauthWaiting(String provider) {
    return '$provider 인증 대기 중';
  }

  @override
  String get oauthCancel => '인증 취소';

  @override
  String get oauthOpenBrowser => '인증 페이지 열기';

  @override
  String get oauthCopyCode => '코드 복사';

  @override
  String get oauthCodeHint => '인증 페이지에서 이 코드를 입력하세요';

  @override
  String get oauthDeviceHint =>
      '먼저 ChatGPT 보안 설정이나 워크스페이스 권한에서 기기 코드 로그인을 활성화하세요.';

  @override
  String get oauthDeviceLogin => '기기 코드로 로그인';

  @override
  String get oauthDetails => '계정 세부 정보 보기';

  @override
  String get oauthConnectAnother => '다른 계정 연결';

  @override
  String get oauthRelogin => '다시 로그인';

  @override
  String get oauthNeedsLogin => '로그인 필요';

  @override
  String oauthExpired(String provider) {
    return '$provider 로그인이 만료되었습니다';
  }

  @override
  String get oauthLoginRestored => '로그인되었습니다. 메시지의 다시 생성 버튼을 눌러 다시 보내세요.';

  @override
  String get oauthLogout => '로그아웃';

  @override
  String get oauthLogoutDescription => '이 기기에 저장된 이 계정의 자격 증명을 제거합니다';

  @override
  String get oauthRefreshing => '인증 갱신 중…';

  @override
  String get oauthRefreshUsage => '사용량 새로고침';

  @override
  String get oauthUsageDetails => '사용량 세부 정보';

  @override
  String get oauthUsageUnavailable => '지금은 사용량을 불러올 수 없습니다';

  @override
  String oauthLastUpdated(String time) {
    return '업데이트: $time';
  }

  @override
  String get oauthSyncModels => '동기화';

  @override
  String get oauthSyncing => '모델 동기화 중…';

  @override
  String get oauthModelsHint => '사용 가능한 모델은 계정에서 동기화됩니다.';

  @override
  String get oauthNoModels => '채팅을 시작하려면 모델을 동기화하세요';

  @override
  String get oauthConnection => '연결';

  @override
  String get oauthConnectionInfo => '연결 정보';

  @override
  String get oauthEndpoint => '엔드포인트';

  @override
  String get oauthScope => '권한 범위';

  @override
  String get oauthAccountId => '계정 ID';

  @override
  String get oauthTokenExpiry => '토큰 만료';

  @override
  String get oauthName => '제공업체 이름';

  @override
  String get oauthEnabledHint => '모델 선택기에 이 제공업체의 모델을 표시합니다';

  @override
  String get oauthNetwork => '네트워크 프록시';

  @override
  String get oauthFollowGlobal => '전역 설정 따르기';

  @override
  String get oauthCustomRequest => '사용자 지정 요청';

  @override
  String get oauthWeekly => '주간 한도';

  @override
  String get oauthMonthly => '월간 한도';

  @override
  String get oauthTotal => '총 한도';

  @override
  String oauthHours(String count) {
    return '$count시간 한도';
  }

  @override
  String oauthMinutes(String count) {
    return '$count분 한도';
  }

  @override
  String oauthDays(String count) {
    return '$count일 한도';
  }

  @override
  String get oauthWindow => '사용 한도';

  @override
  String oauthResetsAt(String time) {
    return '초기화: $time';
  }

  @override
  String oauthUsedValue(String value) {
    return '$value 사용됨';
  }

  @override
  String get oauthNetworkError => '연결하지 못했습니다. 네트워크를 확인하고 다시 시도하세요.';

  @override
  String get oauthInvalidResponse => '인증이 완료되지 않았습니다. 다시 시도하세요.';

  @override
  String get oauthTimeout => '인증 시간이 초과되었습니다. 다시 시도하세요.';

  @override
  String get oauthDenied => '인증이 승인되지 않았습니다. 다시 시도하세요.';

  @override
  String get oauthSaving => '계정 연결 중…';

  @override
  String get oauthQuotaExceeded => '이 계정에 남은 한도가 없습니다.';

  @override
  String get oauthRateLimited => '요청이 너무 많습니다. 나중에 다시 시도하세요.';

  @override
  String get oauthPermissionDenied => '이 계정은 이 리소스에 액세스할 수 없습니다.';

  @override
  String get oauthRequestFailed => '제공업체가 요청을 완료하지 못했습니다.';

  @override
  String get oauthQuotaAvailable => '한도가 남아 있습니다';

  @override
  String oauthSavedResets(String count) {
    return '사용 가능한 한도 초기화 횟수: $count';
  }

  @override
  String get oauthPrimaryWindow => '기본 한도';

  @override
  String get oauthSecondaryWindow => '보조 한도';

  @override
  String get oauthAuthorizationCode => '인증 코드 또는 콜백 URL';

  @override
  String get oauthAuthorizationCodeHint =>
      '브라우저에서 앱으로 자동으로 돌아오지 않으면 최종 콜백 URL이나 인증 코드를 여기에 붙여넣으세요.';

  @override
  String get oauthInvalidAuthorizationCode =>
      '이번 로그인 시도의 인증 코드 또는 콜백 URL을 입력하세요.';

  @override
  String get oauthSubmitAuthorizationCode => '로그인 완료';

  @override
  String get oauthExtraUsage => '추가 사용량';

  @override
  String get oauthPromptCachingHelp =>
      '여러 메시지에서 컨텍스트를 재사용하며, 캐시 유지 시간을 선택할 수 있습니다.';

  @override
  String get scheduledTasksPreparation => '실행 및 알림';

  @override
  String get scheduledTasksAllowPreparation => '사전 준비 허용';

  @override
  String get scheduledTasksPreparationDetail =>
      '사전 준비는 실시간 정보가 필요 없는 텍스트 작업에 적합합니다. 도구나 첨부 파일을 사용하거나 외부 동작을 실행할 수 없습니다.';

  @override
  String get scheduledTasksIOSDetail =>
      'iOS의 백그라운드 제한으로 인해 Kelivo는 정해진 시간에 깨어나 모델을 실행할 수 없습니다. 대신 앱이 실행될 수 있을 때 내용을 미리 준비하고, 예정 시간에 시스템이 알림을 표시합니다. 다음 회차만 미리 준비합니다. 앱을 나가면 준비가 끝나지 않을 수 있으므로, 이후 회차를 준비하려면 Kelivo를 다시 여세요.';

  @override
  String get scheduledTasksContextPolicy => '대화 컨텍스트';

  @override
  String get scheduledTasksContextLatest => '최신 대화 따르기';

  @override
  String get scheduledTasksContextSnapshot => '준비 시점 스냅샷 사용';

  @override
  String get scheduledTasksUnavailable => '실행할 수 없을 때';

  @override
  String get scheduledTasksRemind => '리마인더만 보내기';

  @override
  String get scheduledTasksSkip => '이번 회차 건너뛰기';

  @override
  String get scheduledTasksNotify => '결과 알림';

  @override
  String get scheduledTasksShowPreview => '알림에 결과 텍스트 표시';

  @override
  String get scheduledTasksPreparationWindow => '사전 준비 가능 시간';

  @override
  String get scheduledTasksPreparationAttempts => '자동 시도 한도';

  @override
  String get scheduledTasksPreparationCooldown => '최소 간격(분)';

  @override
  String get scheduledTasksPreparationBudget =>
      '모든 작업을 통틀어 한 번에 하나만 준비합니다. 자동 준비는 시간당 총 6회 시도하면 일시 중지되며, 취소된 요청도 횟수에 포함됩니다. ‘지금 준비’는 시도 횟수 제한을 받지 않습니다.';

  @override
  String get scheduledTasksPreparing => '결과 준비 중';

  @override
  String get scheduledTasksPrepared => '결과 준비됨';

  @override
  String get scheduledTasksPendingPreparation => '아직 결과가 준비되지 않음';

  @override
  String get scheduledTasksNotificationRegistered => '알림 예약됨';

  @override
  String get scheduledTasksNotificationUnavailable => '알림이 예약되지 않음';

  @override
  String get scheduledTasksReminded => '예정 시간 도달 · 리마인더만 보냄';

  @override
  String get scheduledTasksSkipped => '건너뜀';

  @override
  String get scheduledTasksCancelled => '취소됨';

  @override
  String get scheduledTasksReminderBody =>
      '예약된 작업의 예정 시간이 되었습니다. 계속하려면 Kelivo를 여세요.';

  @override
  String get scheduledTasksResultBody => '예약된 작업의 결과가 준비되었습니다.';

  @override
  String get scheduledTasksNotificationPermission => '작업 알림 허용';

  @override
  String get scheduledTasksPreparationCost =>
      '사전 준비는 모델을 호출하므로 추가 비용이 발생할 수 있습니다. ‘최신 대화 따르기’를 선택하면 예정 시간 전에 새 메시지가 추가될 경우 준비된 결과가 무효화될 수 있습니다. 사용되지 않거나 취소된 출력에도 요금이 청구될 수 있으며, 다시 준비하면 모델 요청이 한 번 더 발생합니다.';

  @override
  String get scheduledTasksAllowPreparationTip =>
      'Kelivo가 실행될 수 있을 때 예정 시간보다 먼저 다음 결과를 생성합니다. 결과는 예정 시간이 될 때까지 채팅에 추가되지 않습니다. 사전 준비는 텍스트만 사용하며, 도구, 첨부 파일, 사용자 지정 요청 본문은 사용하지 않습니다. 모델 사용 요금이 발생할 수 있습니다.';

  @override
  String get scheduledTasksContextPolicyTip =>
      '‘최신 대화 따르기’: 예정 시간 전에 새 메시지가 추가되거나, 메시지가 편집되거나, 메시지 버전이 전환되면 준비된 결과가 무효화됩니다. 다시 준비하면 시도 횟수가 1회 늘어나고 추가 비용이 발생할 수 있습니다. 예정 시간이 되면 저장된 알림 결과가 그대로 대화에 추가됩니다.\n\n‘준비 시점 스냅샷 사용’: 대화가 바뀌어도 준비된 결과를 유지합니다. 이후 메시지는 반영되지 않습니다.';

  @override
  String get scheduledTasksPreparationWindowTip =>
      '예정 시간보다 얼마나 일찍 준비를 시작할 수 있는지 정합니다(최대 24시간). 예를 들어 정오에 Kelivo를 열면 다음 날 아침 작업을 미리 준비할 수 있습니다. 사전 준비 가능 시간이 길수록 준비할 기회는 많아지지만, 결과가 최신 상태가 아닐 수 있습니다. 이 설정은 예정 시간을 바꾸지 않으며 백그라운드 실행을 보장하지도 않습니다. ‘지금 준비’에는 이 자동 대기 시간과 모든 시도 한도가 적용되지 않습니다.';

  @override
  String get scheduledTasksPreparationAttemptsTip =>
      '이번 회차의 총 시도 횟수가 한도에 도달하면 자동 준비가 일시 중지됩니다. 첫 시도, 실패, 취소, 수동 준비가 모두 시도 횟수에 포함됩니다. 한도에 도달한 뒤에도 ‘지금 준비’는 실행할 수 있습니다. 시도가 많을수록 모델 사용 요금이 더 발생할 수 있으며, 이 한도는 비용 한도가 아닙니다.';

  @override
  String get scheduledTasksPreparationCooldownTip =>
      '같은 회차에서 준비 시도를 시작하는 시점 사이의 최소 간격입니다. 간격이 길수록 반복 요청이 줄어듭니다. 재시도도 앱이 실행될 수 있을 때만 진행되며, 백그라운드 타이머로 동작하지 않습니다. ‘지금 준비’에는 이 자동 대기 시간과 모든 시도 한도가 적용되지 않습니다.';

  @override
  String get scheduledTasksUnavailableTip =>
      '예정 시간에 준비된 결과가 없고 작업도 실행할 수 없으면 리마인더를 보내거나 이번 회차를 건너뜁니다. 리마인더에는 생성된 답변이 포함되지 않으며, 알림이 활성화되어 있어야 합니다. 예정 시간에 Kelivo가 열려 있으면 그때 작업을 실행할 수 있습니다.';

  @override
  String get scheduledTasksNotifyTip =>
      '결과 알림과, 실행할 수 없을 때 보내는 리마인더를 허용합니다. 끄더라도 작업 실행이나 모델 호출은 중지되지 않으며, 사전 준비에 따른 요금도 계속 발생할 수 있습니다. 시스템 알림 권한도 필요합니다.';

  @override
  String get scheduledTasksShowPreviewTip =>
      '준비된 결과 텍스트를 알림에 표시하며, 시스템 설정에서 허용하면 잠금 화면에도 표시합니다. 끄면 일반 안내만 표시되며, 전체 결과는 채팅에서 계속 볼 수 있습니다. 전역 알림 개인정보 보호 설정도 적용됩니다.';

  @override
  String scheduledTasksHours(int count) {
    return '$count시간';
  }

  @override
  String scheduledTasksMinutes(int count) {
    return '$count분';
  }

  @override
  String get scheduledTasksPreparationOff => '사전 준비 꺼짐';

  @override
  String get scheduledTasksPreparationQueued => '대기 중';

  @override
  String get scheduledTasksPreparationQueuedDetail =>
      '다른 작업을 준비하는 중입니다. 준비할 수 있는 작업은 예정 시간 순으로 차례대로 준비됩니다.';

  @override
  String get scheduledTasksPreparationIdle => '응답 완료 대기 중';

  @override
  String get scheduledTasksPreparationIdleDetail =>
      '진행 중인 응답이 끝나고 이 작업의 컨텍스트가 안정되면 준비를 재개합니다.';

  @override
  String get scheduledTasksPreparationWindowWaiting => '사전 준비 가능 시간 전';

  @override
  String get scheduledTasksPreparationCooldownWaiting => '재시도 대기 중';

  @override
  String scheduledTasksPreparationRetryAt(String time) {
    return '재시도 가능 시간: $time';
  }

  @override
  String get scheduledTasksPreparationLimitReached => '자동 시도 한도에 도달함';

  @override
  String scheduledTasksPreparationAttemptsUsed(int count, int limit) {
    return '이번 회차에서 $count회 시도했으며, 자동 시도 한도는 $limit회입니다. 직접 계속하려면 ‘지금 준비’를 사용하세요.';
  }

  @override
  String get scheduledTasksPreparationHourlyLimit => '시간당 자동 시도 한도에 도달함';

  @override
  String get scheduledTasksPreparationHourlyLimitDetail =>
      '시간당 한도에 여유가 생길 때까지 자동 준비가 일시 중지됩니다. ‘지금 준비’는 계속 사용할 수 있습니다.';

  @override
  String get scheduledTasksPreparationUnavailable => '준비할 수 없음';

  @override
  String get scheduledTasksPreparationReadFailed =>
      '작업 컨텍스트를 읽지 못했습니다. 잠시 후 다시 확인합니다. 자세한 내용은 실행 기록을 확인하세요.';

  @override
  String get scheduledTasksPreparationResultRetained =>
      '컨텍스트를 확인하지 못했습니다. 준비된 결과는 유지되며, 나중에 다시 확인합니다.';

  @override
  String get scheduledTasksPreparationContextChanged =>
      '대화 또는 작업 컨텍스트가 바뀌어 이전 결과가 무효화되었습니다.';

  @override
  String get scheduledTasksPreparationPublishing => '채팅에 추가 대기 중';

  @override
  String get scheduledTasksPreparationPublishingDetail =>
      '현재 응답이 끝나면 저장된 결과가 채팅에 추가됩니다.';

  @override
  String get scheduledTasksPreparationPrompt => '준비 프롬프트';

  @override
  String get scheduledTasksPreparationPromptTip =>
      '이 작업을 미리 준비할 때만 사용하는 추가 시스템 지침으로, 작업 프롬프트와는 별개입니다. 스타일을 바꾸거나 이 지침을 완전히 제거할 수 있습니다. 도구와 실시간 정보는 여전히 사용할 수 없습니다. 예정 시간 전에 이 프롬프트를 편집하면 이미 준비된 결과가 무효화되며, 다시 준비하면 모델 사용 요금이 또 발생할 수 있습니다.';

  @override
  String get scheduledTasksPreparationPromptEmpty => '비워 두면 준비 지침을 추가하지 않습니다';

  @override
  String scheduledTasksPreparationPromptVariables(
    String timeVariable,
    String offsetVariable,
  ) {
    return '변수: $timeVariable은(는) 현지 시간 기준의 예정 시간이고, $offsetVariable은(는) 그 시간의 UTC 오프셋입니다. 결과를 준비할 때 실제 값으로 바뀝니다.';
  }

  @override
  String get scheduledTasksPrepareNow => '지금 준비';

  @override
  String get scheduledTasksPrepareNowDetail =>
      '다음 결과를 지금 준비해 예정 시간에 전달합니다. 자동 대기 시간과 시도 한도는 적용되지 않습니다. 모델 사용 요금이 발생할 수 있습니다. 이미 준비된 결과가 있으면 그대로 사용합니다.';

  @override
  String get scheduledTasksPrepareNowReady =>
      '다음 결과가 이미 준비되어 있습니다. 모델에 추가로 요청하지 않았습니다.';

  @override
  String get scheduledTasksPrepareNowStarted => '예정 시간에 전달할 다음 결과를 준비하는 중입니다.';

  @override
  String get scheduledTasksPrepareNowBusy =>
      '다른 작업을 준비하는 중입니다. 완료된 후 다시 시도하세요.';

  @override
  String get scheduledTasksPrepareNowChatBusy =>
      '현재 응답이 끝날 때까지 기다린 후 다시 시도하세요.';

  @override
  String get scheduledTasksPrepareNowDisabled =>
      '먼저 이 작업과 ‘사전 준비 허용’을 활성화하세요. ‘다시 실행’ 방식의 작업은 미리 준비할 수 없습니다.';

  @override
  String get scheduledTasksPrepareNowUnavailable =>
      '아직 준비를 시작할 수 없습니다. 잠시 후 다시 시도하세요.';

  @override
  String get scheduledTasksPrepareNowNoUpcoming =>
      '준비할 다음 회차가 없습니다. 작업 시간과 활성화 상태를 확인하세요.';

  @override
  String get phoneControlTitle => '휴대폰 제어';

  @override
  String get phoneControlSubtitle => '접근성 서비스로 화면을 읽고 작업을 수행합니다';

  @override
  String get phoneControlAccessibilityService => '접근성 서비스';

  @override
  String get phoneControlOpenSettings => '접근성 설정 열기';

  @override
  String get phoneControlRefresh => '상태 새로고침';

  @override
  String get phoneControlChecking => '서비스 상태 확인 중…';

  @override
  String get phoneControlReady => '활성화되어 연결됨';

  @override
  String get phoneControlDisabled => '활성화되지 않음';

  @override
  String get phoneControlDisconnected =>
      '활성화되었지만 연결되지 않았습니다. 시스템 설정에서 서비스를 껐다가 다시 켠 다음 새로고침해 보세요.';

  @override
  String get phoneControlStatusUnavailable =>
      '서비스 상태를 확인할 수 없습니다. 새로고침을 눌러 다시 시도하세요.';

  @override
  String get phoneControlSettingsUnavailable =>
      '설정을 열 수 없습니다. Android에서 ‘설정 → 접근성’을 직접 여세요.';

  @override
  String get phoneControlUsageTitle => '작동 방식';

  @override
  String get phoneControlDisclosure =>
      '대화에서 휴대폰 제어 작업을 요청하면 어시스턴트가 현재 화면을 읽고, 탭하고, 텍스트를 입력하고, 스크롤하고, 이동하고, 앱을 열 수 있습니다. 화면 내용은 그 대화에 구성된 모델 제공업체로 전송되고 대화의 도구 결과에 저장됩니다. 비밀번호 필드는 숨겨집니다. 이 서비스는 화면 내용을 계속 기록하지 않습니다. 언제든지 어시스턴트에서 이 도구를 끄거나 시스템 설정에서 서비스를 비활성화할 수 있습니다.';

  @override
  String get phoneControlAssistantTitle => '어시스턴트에서도 도구 활성화';

  @override
  String get phoneControlAssistantHint =>
      '두 가지 설정이 모두 필요합니다. 시스템 접근성 설정에서 ‘Kelivo 휴대폰 제어’를 활성화한 다음, 사용할 어시스턴트의 ‘기기 도구’에서 ‘휴대폰 제어’를 활성화하세요(채팅의 도구 메뉴에서도 설정할 수 있습니다). 어시스턴트마다 따로 구성해야 합니다. 작업을 실행하는 동안에는 휴대폰 잠금을 해제해 두세요.';

  @override
  String get phoneControlRestrictedTitle => '접근성 스위치를 켤 수 없나요?';

  @override
  String get phoneControlRestrictedHint =>
      '다운로드한 일부 APK의 경우, Android에서 먼저 앱 정보 메뉴의 ‘제한된 설정 허용’을 선택해야 합니다. 여기를 눌러 Kelivo 앱 정보를 연 다음 접근성 설정으로 돌아가세요.';

  @override
  String get phoneControlEnableAssistant => '이 어시스턴트에 휴대폰 제어 허용';

  @override
  String get composerDraftLabel => '초안';

  @override
  String get composerDraftRecovered => '보내지 않은 메시지가 복구되었습니다.';

  @override
  String get composerDraftRestore => '계속 편집';

  @override
  String get composerDraftDiscard => '삭제';

  @override
  String get composerDraftSaveFailed =>
      '최신 초안을 저장하지 못했습니다. 초안은 이 창에 그대로 남아 있습니다.';

  @override
  String get composerDraftRetry => '저장 다시 시도';

  @override
  String get composerDraftConflictTitle => '이 대화에 이미 초안이 있습니다';

  @override
  String get composerDraftConflictBody =>
      '‘덧붙이기’는 양쪽의 텍스트와 첨부 파일을 모두 유지합니다. ‘초안 교체’는 기존 초안을 삭제합니다. 자동으로 전송되지 않습니다.';

  @override
  String get composerDraftAppend => '덧붙이기';

  @override
  String get composerDraftReplace => '초안 교체';

  @override
  String get composerDraftMissingFile =>
      '사용할 수 없는 첨부 파일이 있습니다. 제거하거나 파일을 다시 선택하세요.';

  @override
  String get composerDraftMessageMissing =>
      '편집 중인 메시지가 더 이상 존재하지 않습니다. 텍스트를 새 메시지로 복사하거나 이 편집 내용을 삭제하세요.';

  @override
  String get composerDraftDeleteNotice => '대화에 있는 보내지 않은 초안도 함께 삭제됩니다.';

  @override
  String get mcpOAuthSettings => 'OAuth 설정';

  @override
  String get mcpOAuthAutomatic => '자동';

  @override
  String get mcpOAuthMetadataUrl => '클라이언트 메타데이터 문서 URL';

  @override
  String get mcpOAuthClientAuthentication => '클라이언트 인증';

  @override
  String get mcpOAuthPublicClient => '공개 클라이언트';

  @override
  String get mcpOAuthRedirectUri => '로컬 콜백 URL(선택 사항)';

  @override
  String get mcpOAuthFillRedirectExample => '예시 채우기';

  @override
  String get mcpOAuthRedirectHint =>
      '비워 두면 플랫폼 기본값을 사용합니다. 서비스가 localhost 콜백만 허용하는 경우 HTTP 루프백 URL을 사용하세요. 포트 0을 입력하면 사용 가능한 포트를 자동으로 선택합니다. 사전 등록된 클라이언트에는 고정 포트가 필요할 수 있습니다.';

  @override
  String get mcpOAuthClientIdRequired => '클라이언트 ID를 입력하거나 자동 등록을 선택하세요.';

  @override
  String get mcpOAuthMetadataUrlInvalid => '경로가 포함된 HTTPS 메타데이터 문서 URL을 입력하세요.';

  @override
  String get mcpOAuthSecretRequired => '이 클라이언트 인증 방식에는 클라이언트 시크릿이 필요합니다.';

  @override
  String get mcpOAuthRedirectInvalid =>
      'localhost, 127.0.0.1 또는 [::1]의 HTTP 콜백을 사용하고 자격 증명, 쿼리 매개변수, 프래그먼트는 넣지 마세요.';

  @override
  String get mcpOAuthDiscovering => '인증 서버 찾는 중…';

  @override
  String get mcpOAuthRegistering => '인증 준비 중…';

  @override
  String get mcpOAuthWaitingBrowser => '브라우저 인증 대기 중…';

  @override
  String get mcpOAuthExchangingToken => '로그인 마무리 중…';

  @override
  String get markdownPlaygroundTitle => 'Markdown 플레이그라운드';

  @override
  String get markdownPlaygroundSource => 'Markdown 소스';

  @override
  String get markdownPlaygroundPreview => '미리보기';

  @override
  String get markdownPlaygroundAst => 'AST';

  @override
  String get markdownPlaygroundPlay => '글자 단위 스트리밍';

  @override
  String get markdownPlaygroundPause => '일시 중지';

  @override
  String get markdownPlaygroundResume => '재개';

  @override
  String get markdownPlaygroundShowAll => '전체 보기';

  @override
  String get markdownPlaygroundWidth => '미리보기 너비';

  @override
  String get markdownPlaygroundTheme => '미리보기 테마';

  @override
  String get markdownPlaygroundPlain => '선택 영역의 일반 텍스트';

  @override
  String get markdownPlaygroundMarkdown => '선택 영역의 Markdown';

  @override
  String get markdownPlaygroundSelectionHint =>
      '미리보기에서 텍스트를 선택해 복사될 내용을 확인하세요.';

  @override
  String get markdownPlaygroundEmpty => '미리 보려면 Markdown을 입력하세요.';

  @override
  String markdownPlaygroundProgress(int shown, int total) {
    return '입력 $shown / $total';
  }

  @override
  String get markdownCopyMarkdownAction => 'Markdown 복사';

  @override
  String get markdownCopyCsvAction => 'CSV 복사';

  @override
  String get markdownCopyImageAction => '이미지 복사';

  @override
  String get markdownCodeLabel => '코드';

  @override
  String get markdownDetailsLabel => '세부 정보';

  @override
  String markdownMoreRows(int count) {
    return '$count행 더 보기';
  }

  @override
  String get markdownNoteLabel => '참고';

  @override
  String get markdownTipLabel => '팁';

  @override
  String get markdownImportantLabel => '중요';

  @override
  String get markdownWarningLabel => '경고';

  @override
  String get markdownCautionLabel => '주의';

  @override
  String get markdownDangerLabel => '위험';

  @override
  String get markdownCopyRichTextAction => '서식 있는 텍스트 복사';

  @override
  String get markdownCopySelectionFailed => '선택한 텍스트를 복사하지 못했습니다.';

  @override
  String get recoveryMissingDataTitle => '이전 데이터가 발견되었습니다';

  @override
  String get recoveryMissingDataBody =>
      '현재 데이터베이스가 없지만 이 기기에 이전 데이터가 남아 있습니다. Kelivo는 시작을 일시 중지했으며, 빈 데이터베이스를 새로 만들지 않았습니다. 남아 있는 파일과 사본은 모두 보존됩니다.';

  @override
  String get recoveryEmptyDataTitle => '현재 채팅 기록이 비어 있습니다';

  @override
  String get recoveryEmptyDataBody =>
      '현재 데이터베이스에 채팅이 없지만 이전 사본이 발견되었습니다. Kelivo가 시작을 일시 중지했으므로 사본을 복원할지, 현재 데이터를 유지할지 직접 선택할 수 있습니다. 자동으로 덮어쓰는 데이터는 없습니다.';

  @override
  String get recoveryKeepCurrent => '현재 데이터 유지 후 계속';

  @override
  String get recoveryKeepCurrentConfirm =>
      '현재의 빈 데이터베이스로 계속하시겠습니까? 이전 사본은 그대로 남아 있으므로 나중에 복원할 수 있습니다.';

  @override
  String get recoverySearchingCopies => '이 기기의 데이터 사본을 찾아 유효성을 검사하는 중…';

  @override
  String recoveryFoundCopies(int count) {
    return '유효성 검사를 통과한 사본 $count개를 찾았습니다. 하나를 선택해 채팅과 설정을 복원하세요. 원본 파일은 그대로 유지됩니다.';
  }

  @override
  String recoveryInvalidCopy(String name) {
    return '$name: 유효성 검사에 실패했습니다. 원본 파일은 그대로 유지됩니다.';
  }

  @override
  String get recoverySearchFailed =>
      '일부 데이터 위치를 읽지 못했습니다. 파일은 그대로 유지됩니다. 다른 복구 작업을 시도하기 전에 데이터 사본을 내보내세요.';

  @override
  String get recoveryDiscoveredCopyBody =>
      '앱이 관리하는 사본 폴더 밖에서 발견된 사본입니다. 원본 파일은 그대로 보존되며, 복원하기 전에 전체 유효성 검사를 거칩니다.';

  @override
  String get recoveryStorageFailureTitle => '데이터 저장소에 조치가 필요합니다';

  @override
  String get recoveryStorageFailureBody =>
      'Kelivo가 보호된 데이터 저장소를 활성화하지 못했습니다. 시작이 중단되었으며 원본 데이터는 그대로 유지됩니다. 데이터 사본을 내보내거나 다시 시도하세요. 빈 데이터베이스는 새로 만들지 않습니다.';

  @override
  String get recoveryProtectingTitle => '채팅 데이터베이스 보호 중';

  @override
  String get recoveryProtectingData =>
      '데이터베이스를 복사하고 검증하는 중입니다. 이미지, 첨부 파일, 로컬 사본은 Documents 폴더에 그대로 남아 있으므로 따로 복사하지 않습니다. 원본 데이터베이스는 그대로 보존됩니다.';

  @override
  String get recoveryStorageReadyTitle => '채팅 데이터베이스를 앱 내부 저장소로 옮겼습니다';

  @override
  String get recoveryStorageReadyBody =>
      '채팅, 어시스턴트, 설정이 담긴 데이터베이스는 이제 앱 내부 저장소에 저장됩니다. 로컬 사본, 이미지, 첨부 파일은 계속 ‘파일’ 앱의 Kelivo 폴더에서 볼 수 있습니다. 원본 데이터베이스도 그대로 보존됩니다. 이전 채팅이 보이지 않으면 ‘설정 → 백업 → 로컬 사본’을 여세요.';

  @override
  String get recoveryRetainedData => '보존된 원본 데이터';

  @override
  String get recoveryNoValidCopies =>
      '사본을 찾았지만 유효성 검사를 통과한 사본이 없습니다. 원본은 모두 그대로 유지됩니다. 추가 진단을 위해 데이터를 내보낼 수 있습니다.';

  @override
  String get recoveryStorageInsufficientSpaceBody =>
      '원본 데이터베이스를 보존하면서 검증된 내부 사본을 만들기에는 저장 공간이 부족합니다. 기존 데이터와 로컬 사본은 변경되지 않았습니다. 저장 공간을 확보한 다음 다시 시도하세요.';
}
