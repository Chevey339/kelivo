// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Korean (`ko`).
class AppLocalizationsKo extends AppLocalizations {
  AppLocalizationsKo([String locale = 'ko']) : super(locale);

  @override
  String get avatarInputInvalid => '유효한 아이콘 이름 또는 HTTP(S) 이미지 URL을 입력하세요.';

  @override
  String get modelAvatarTitle => '모델 아이콘';

  @override
  String get avatarColor => '컬러';

  @override
  String get avatarMonochrome => '단색';

  @override
  String get settingsSearchHint => '설정 검색';

  @override
  String get settingsSearchCancel => '취소';

  @override
  String get settingsSearchClear => '검색 지우기';

  @override
  String get settingsSearchSuggestions => '빠른 접근';

  @override
  String get settingsSearchNoResults => '설정을 찾을 수 없습니다';

  @override
  String get settingsSearchNoResultsHint => '다른 이름이나 더 짧은 키워드를 입력해 보세요.';

  @override
  String settingsSearchResultCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count개 결과',
    );
    return '$_temp0';
  }

  @override
  String get helloWorld => '안녕하세요!';

  @override
  String get settingsPageBackButton => '뒤로';

  @override
  String get settingsPageTitle => '설정';

  @override
  String get settingsPageDarkMode => '어둡게';

  @override
  String get settingsPageLightMode => '밝게';

  @override
  String get settingsPageSystemMode => '시스템';

  @override
  String get settingsPageWarningMessage => '일부 서비스가 구성되지 않아 일부 기능이 제한될 수 있습니다.';

  @override
  String get settingsPageGeneralSection => '일반';

  @override
  String get settingsPageColorMode => '색상 모드';

  @override
  String get settingsPageDisplay => '환경설정';

  @override
  String get settingsPageDisplaySubtitle => '외관, 동작 및 상호작용 환경설정';

  @override
  String get settingsPageAssistant => '어시스턴트';

  @override
  String get settingsPageAssistantSubtitle => '기본 어시스턴트 및 대화 스타일';

  @override
  String get settingsPageModelsServicesSection => '모델 및 서비스';

  @override
  String get settingsPageDefaultModel => '기본 모델';

  @override
  String get settingsPageProviders => '공급자';

  @override
  String get settingsPageHotkeys => '단축키';

  @override
  String get settingsPageSearch => '검색 서비스';

  @override
  String get settingsPageTts => 'TTS';

  @override
  String get settingsPageMcp => 'MCP';

  @override
  String get settingsPageQuickPhrase => '빠른 문구';

  @override
  String get settingsPageInstructionInjection => '지시문 주입';

  @override
  String get settingsPageDataSection => '데이터';

  @override
  String get settingsPageBackup => '백업';

  @override
  String get settingsPageChatStorage => '채팅 기록 저장소';

  @override
  String get settingsPageCalculating => '계산 중…';

  @override
  String get storageSpacePageTitle => '저장 공간';

  @override
  String get storageSpaceRefreshTooltip => '새로고침';

  @override
  String get storageSpaceLoadFailed =>
      '파일을 불러오거나 이미지 사용 여부를 확인할 수 없습니다. 새로고침 후 다시 시도하세요.';

  @override
  String get storageSpaceTotalLabel => '사용 중';

  @override
  String storageSpaceClearableLabel(String size) {
    return '정리 가능: $size';
  }

  @override
  String storageSpaceClearableHint(String size) {
    return '정리 가능한 공간: $size';
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
  String get storageSpaceOtherHint => '글꼴, 다운로드한 로컬 모델 및 기타 앱 파일입니다.';

  @override
  String get storageSpaceSubOtherApp => '앱 파일';

  @override
  String get storageSpaceCategoryChatData => '채팅 기록';

  @override
  String get storageSpaceCategoryLegacyChatData => '채팅 기록 (이전)';

  @override
  String get storageSpaceCategoryRestoreTraces => '복원 흔적';

  @override
  String get storageSpaceCategoryDisplacedDatabases => '보관된 이전 데이터베이스';

  @override
  String get storageSpaceSubDisplacedDatabases => '자동 재구축 전에 보관된 데이터베이스';

  @override
  String get storageSpaceClearDisplacedDatabasesConfirmMessage =>
      '이 보관된 이전 데이터베이스를 삭제할까요? Kelivo가 데이터베이스를 재구축할 때 남긴 것으로, 해당 채팅 기록과 설정의 유일한 사본일 수 있습니다. 삭제 후에는 복구할 수 없습니다.';

  @override
  String get storageSpaceRestoreTracesHint =>
      '복원 완료 후 보관된 이전 데이터 스냅샷입니다. 정리해도 현재 앱 데이터에는 영향을 주지 않습니다.';

  @override
  String get storageSpaceClearRestoreTracesButton => '복원 흔적 정리';

  @override
  String get storageSpaceClearDisplacedDatabasesButton => '보관된 이전 데이터베이스 삭제';

  @override
  String get storageSpaceClearRestoreTracesConfirmMessage =>
      '완료된 복원 스냅샷을 정리할까요? 현재 데이터베이스, 설정 및 파일에는 영향을 주지 않습니다.';

  @override
  String get storageSpaceSubCompletedRestoreRuns => '완료된 복원 스냅샷';

  @override
  String get storageSpaceCategoryCache => '캐시';

  @override
  String get storageSpaceCategoryLogs => '로그';

  @override
  String get storageSpaceCategoryOther => '기타';

  @override
  String get storageSpaceSafeToClearHint =>
      '안전하게 정리할 수 있으며 채팅 기록에는 영향을 주지 않습니다.';

  @override
  String get storageSpaceLegacyChatDataHint =>
      'SQLite로 마이그레이션하기 전에 보관된 Hive 이전 파일입니다. 정리해도 현재 채팅 기록은 삭제되지 않습니다.';

  @override
  String get storageSpaceNotSafeToClearHint => '채팅 기록에 영향을 줄 수 있으니 신중하게 삭제하세요.';

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
  String get storageSpaceSubChatWriteAheadLog => '쓰기 로그';

  @override
  String get storageSpaceSubChatSharedMemory => '공유 메모리 인덱스';

  @override
  String get storageSpaceSubCacheAvatars => '아바타 캐시';

  @override
  String get storageSpaceSubCacheOther => '기타 캐시';

  @override
  String get storageSpaceSubCacheSystem => '시스템 캐시';

  @override
  String get storageSpaceSubLogsContext => '컨텍스트 로그';

  @override
  String get storageSpaceSubLogsFlutter => '실행 로그';

  @override
  String get storageSpaceSubLogsRequests => '네트워크 로그';

  @override
  String get storageSpaceSubLogsOther => '기타 로그';

  @override
  String get storageSpaceClearConfirmTitle => '정리 확인';

  @override
  String storageSpaceClearConfirmMessage(String targetName) {
    return '$targetName을(를) 정리할까요?';
  }

  @override
  String get storageSpaceClearButton => '정리';

  @override
  String storageSpaceClearDone(String targetName) {
    return '$targetName 정리 완료';
  }

  @override
  String storageSpaceClearFailed(String error) {
    return '정리 실패: $error';
  }

  @override
  String get storageSpaceClearAvatarCacheButton => '아바타 캐시 정리';

  @override
  String get storageSpaceClearCacheButton => '캐시 정리';

  @override
  String get storageSpaceClearLogsButton => '로그 정리';

  @override
  String get storageSpaceClearLegacyChatDataButton => '이전 채팅 기록 정리';

  @override
  String get storageSpaceExportLegacyChatFileButton => '내보내기';

  @override
  String storageSpaceExportDone(Object fileName) {
    return '$fileName 내보내기 완료';
  }

  @override
  String storageSpaceExportFailed(Object error) {
    return '내보내기 실패: $error';
  }

  @override
  String get storageSpaceClearLegacyChatDataConfirmMessage =>
      '보관된 이전 채팅 파일을 정리할까요? 현재 SQLite 채팅 기록은 계속 사용할 수 있습니다.';

  @override
  String get storageSpaceViewLogsButton => '로그 보기';

  @override
  String get storageSpaceDeleteConfirmTitle => '삭제 확인';

  @override
  String storageSpaceDeleteUploadsConfirmMessage(int count) {
    return '$count개 항목과 연결된 대화 첨부 파일 사본을 삭제할까요? 삭제 후에는 채팅 기록에서 해당 첨부 파일을 사용할 수 없습니다.';
  }

  @override
  String storageSpaceDeletedUploadsDone(int count) {
    return '$count개 항목 삭제 완료';
  }

  @override
  String get storageSpaceNoUploads => '항목 없음';

  @override
  String get storageSpaceSelectAll => '전체 선택';

  @override
  String get storageSpaceClearSelection => '선택 해제';

  @override
  String storageSpaceSelectedCount(int count) {
    return '$count개 선택됨';
  }

  @override
  String storageSpaceUploadsCount(int count) {
    return '$count개 항목';
  }

  @override
  String get storageSpaceSortLabel => '정렬';

  @override
  String get storageSpaceSortNewest => '최신순';

  @override
  String get storageSpaceSortOldest => '오래된순';

  @override
  String get storageSpaceSortLargest => '큰 용량순';

  @override
  String get storageSpaceSortSmallest => '작은 용량순';

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
    return '비용 ($currency)';
  }

  @override
  String statsPageModelsWithoutPricing(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count개 모델 가격 정보 없음',
    );
    return '$_temp0';
  }

  @override
  String get statsPageUsageTrendTitle => '사용량 추이';

  @override
  String get statsPageModelUsageTitle => '모델 사용률';

  @override
  String get statsPageAssistantUsageTitle => '어시스턴트 사용률';

  @override
  String get statsPageTopicVolumeTitle => '토픽 내용량';

  @override
  String get statsPageModelColumn => '모델';

  @override
  String get statsPageAssistantColumn => '어시스턴트';

  @override
  String get statsPageTopicColumn => '토픽';

  @override
  String get statsPageMessagesColumn => '메시지 수';

  @override
  String get statsPageTopicsColumn => '토픽 수';

  @override
  String get statsPageEmptyTitle => '아직 통계가 없습니다';

  @override
  String get statsPageShowAllTooltip => '전체 보기';

  @override
  String get statsPageClose => '닫기';

  @override
  String get statsPageUnknownProvider => '알 수 없는 공급자';

  @override
  String get statsPageUnknownAssistant => '기본 어시스턴트';

  @override
  String get statsPageUnknownModel => '알 수 없는 모델';

  @override
  String get statsPageUnknownTopic => '제목 없는 토픽';

  @override
  String get statsPageCustomRangeTitle => '사용자 지정 기간';

  @override
  String get statsPageCustomRangeStart => '시작';

  @override
  String get statsPageCustomRangeEnd => '종료';

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
  String get sponsorPageWeChatTitle => '위챗 후원';

  @override
  String get sponsorPageWeChatSubtitle => '위챗 후원 코드';

  @override
  String get sponsorPageScanQrHint => 'QR 코드를 스캔하여 후원하세요';

  @override
  String get languageDisplaySimplifiedChinese => '중국어 간체';

  @override
  String get languageDisplayEnglish => '영어';

  @override
  String get languageDisplayTraditionalChinese => '중국어 번체';

  @override
  String get languageDisplayJapanese => '일본어';

  @override
  String get languageDisplayKorean => '한국어';

  @override
  String get languageDisplayFrench => '프랑스어';

  @override
  String get languageDisplayGerman => '독일어';

  @override
  String get languageDisplayItalian => '이탈리아어';

  @override
  String get languageDisplaySpanish => '스페인어';

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
  String get mermaidExportPng => 'PNG 내보내기';

  @override
  String get mermaidExportFailed => '내보내기 실패';

  @override
  String get mermaidImageTab => '이미지';

  @override
  String get mermaidCodeTab => '코드';

  @override
  String get mermaidFullScreen => '전체 화면';

  @override
  String get mermaidGeneratingImage => '이미지 생성 중';

  @override
  String get mermaidGenerationFailedHint => '생성에 실패했습니다. 다른 방식으로 질문해 보세요.';

  @override
  String get mermaidPreviewOpen => '미리보기 열기';

  @override
  String get mermaidPreviewOpenFailed => '미리보기를 열 수 없습니다';

  @override
  String get assistantProviderDefaultAssistantName => '기본 어시스턴트';

  @override
  String get assistantProviderSampleAssistantName => '샘플 어시스턴트';

  @override
  String get assistantProviderNewAssistantName => '새 어시스턴트';

  @override
  String assistantProviderSampleAssistantSystemPrompt(String model_name) {
    return '당신은 $model_name이며, 사용자를 돕는 AI 어시스턴트입니다. 정확하고 간결하게 답변하고, 확실하지 않을 때는 그렇다고 말하세요. 도움이 된다면 명확한 구조(짧은 문단이나 목록)를 사용하세요. 기본적으로 사용자의 언어로 답변하세요.';
  }

  @override
  String get displaySettingsPageLanguageTitle => '앱 언어';

  @override
  String get displaySettingsPageLanguageSubtitle => '인터페이스 언어 선택';

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
  String get mcpServerEditSheetStdioWorkingDirectoryLabel => '작업 디렉터리 (선택 사항)';

  @override
  String get mcpWorkspaceBindingLabel => '작업 공간 바인딩 (선택 사항)';

  @override
  String get mcpWorkspaceBindingHint =>
      '서버는 /workspace에서 이 작업 공간에 접근할 수 있습니다. 작업 디렉터리를 비워 두면 해당 디렉터리에서 시작합니다. 채팅을 전환해도 바인딩은 유지됩니다.';

  @override
  String get mcpWorkspaceBindingMobileOnly =>
      '작업 공간 바인딩은 모바일 Linux 환경에서 사용할 수 있습니다. 데스크톱에서 이 서버를 실행하려면 바인딩을 해제하세요.';

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
  String get displaySettingsPageLanguageChineseLabel => '중국어 간체';

  @override
  String get displaySettingsPageLanguageEnglishLabel => '영어';

  @override
  String get homePagePleaseSelectModel => '먼저 모델을 선택하세요';

  @override
  String get homePagePleaseSetupTranslateModel => '먼저 번역 모델을 설정하세요';

  @override
  String get homePageTranslating => '번역 중...';

  @override
  String homePageTranslateFailed(String error) {
    return '번역 실패: $error';
  }

  @override
  String get chatServiceDefaultConversationTitle => '새 대화';

  @override
  String get userProviderDefaultUserName => '사용자';

  @override
  String get homePageDeleteMessage => '이 버전 삭제';

  @override
  String get homePageDeleteMessageConfirm =>
      '현재 버전을 삭제하시겠습니까? 이 작업은 되돌릴 수 없습니다.';

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
  String get homePageDropToUpload => '파일을 끌어다 놓아 업로드';

  @override
  String get assistantEditPageTitle => '어시스턴트';

  @override
  String get assistantEditPageNotFound => '어시스턴트를 찾을 수 없습니다';

  @override
  String get assistantEditPageBasicTab => '기본 설정';

  @override
  String get assistantEditPagePromptsTab => '프롬프트';

  @override
  String get assistantEditPageMcpTab => 'MCP';

  @override
  String get assistantEditPageQuickPhraseTab => '빠른 문구';

  @override
  String get assistantEditPageCustomTab => '사용자 지정 요청';

  @override
  String get assistantEditPageRegexTab => '정규식 치환';

  @override
  String get assistantEditPageLocalToolsTab => '로컬 도구';

  @override
  String get assistantEditTabLayoutTooltip => '탭 사용자 지정';

  @override
  String get assistantEditTabLayoutTitle => '탭 사용자 지정';

  @override
  String get assistantEditTabLayoutSubtitle =>
      '탭을 드래그하여 순서를 변경하세요. 필요 없는 탭은 끄세요.';

  @override
  String get assistantEditOutlineModeTitle => '섹션 목록 스타일';

  @override
  String get assistantEditOutlineModeSubtitle =>
      '먼저 어시스턴트 개요를 표시한 다음 목록에서 각 설정 섹션을 여세요.';

  @override
  String get assistantEditTabLayoutResetTooltip => '탭 레이아웃 초기화';

  @override
  String get assistantEditTabLayoutAtLeastOneVisible => '탭을 하나 이상 표시해야 합니다';

  @override
  String assistantEditTabLayoutDragHandle(String tab) {
    return '드래그하여 $tab 순서 변경';
  }

  @override
  String get assistantEditRegexDescription =>
      '사용자/어시스턴트 메시지를 다시 작성하거나 표시만 조정하는 정규식 규칙을 만드세요.';

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
  String get assistantRegexReplacementLabel => '대체 문자열';

  @override
  String get assistantRegexScopeLabel => '적용 범위';

  @override
  String get assistantRegexScopeUser => '사용자';

  @override
  String get assistantRegexScopeAssistant => '어시스턴트';

  @override
  String get assistantRegexScopeVisualOnly => '표시만';

  @override
  String get assistantRegexScopeReplaceOnly => '대체만';

  @override
  String get assistantRegexAddAction => '추가';

  @override
  String get assistantRegexSaveAction => '저장';

  @override
  String get assistantRegexDeleteButton => '삭제';

  @override
  String get assistantRegexValidationError => '이름과 정규식을 입력하고 범위를 하나 이상 선택하세요.';

  @override
  String get assistantRegexInvalidPattern => '유효하지 않은 정규식입니다';

  @override
  String get assistantRegexCancelButton => '취소';

  @override
  String get assistantRegexUntitled => '제목 없는 규칙';

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
  String get assistantEditBodyValueLabel => '본문 값 (JSON)';

  @override
  String get assistantEditDeleteTooltip => '삭제';

  @override
  String get assistantEditAssistantNameLabel => '어시스턴트 이름';

  @override
  String get assistantEditUseAssistantAvatarTitle => '어시스턴트 아바타 사용';

  @override
  String get assistantEditUseAssistantAvatarSubtitle =>
      '채팅에서 모델 아바타 대신 어시스턴트 아바타 사용';

  @override
  String get assistantEditUseAssistantNameTitle => '어시스턴트 이름 사용';

  @override
  String get assistantEditChatModelTitle => '채팅 모델';

  @override
  String get assistantEditChatModelSubtitle =>
      '이 어시스턴트의 기본 채팅 모델 (설정하지 않으면 전역 기본값 사용)';

  @override
  String get assistantEditTemperatureDescription => '출력의 무작위성을 제어합니다. 범위 0–2';

  @override
  String get assistantEditTopPDescription => '무엇을 하는지 모른다면 변경하지 마세요';

  @override
  String get assistantEditParameterDisabled => '비활성화됨 (공급자 기본값 사용)';

  @override
  String get assistantEditParameterDisabled2 => '비활성화됨 (제한 없음)';

  @override
  String get assistantEditContextMessagesTitle => '컨텍스트 메시지 수';

  @override
  String get assistantEditContextMessagesDescription => '컨텍스트에 유지할 최근 메시지 수';

  @override
  String get assistantEditStreamOutputTitle => '스트리밍 출력';

  @override
  String get assistantEditStreamOutputDescription => '스트리밍 응답 활성화';

  @override
  String get assistantEditThinkingBudgetTitle => '사고';

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
  String get assistantEditMaxTokensDescription => '비워 두면 무제한';

  @override
  String get assistantEditMaxTokensHint => '무제한';

  @override
  String get assistantEditChatBackgroundTitle => '채팅 배경';

  @override
  String get assistantEditChatBackgroundDescription => '이 어시스턴트의 채팅 배경 이미지 설정';

  @override
  String get assistantEditChooseImageButton => '이미지 선택';

  @override
  String get assistantEditClearButton => '지우기';

  @override
  String get desktopNavChatTooltip => '채팅';

  @override
  String get desktopNavTranslateTooltip => '번역';

  @override
  String get desktopNavStorageTooltip => '저장소';

  @override
  String get desktopNavGlobalSearchTooltip => '전체 검색';

  @override
  String get desktopNavThemeToggleTooltip => '테마';

  @override
  String get desktopNavSettingsTooltip => '설정';

  @override
  String get desktopAvatarMenuUseEmoji => '이모지 사용';

  @override
  String get cameraPermissionDeniedMessage => '카메라를 사용할 수 없음: 권한이 부여되지 않았습니다.';

  @override
  String get openSystemSettings => '설정 열기';

  @override
  String get desktopAvatarMenuChangeFromImage => '이미지에서 변경…';

  @override
  String get desktopAvatarMenuReset => '아바타 초기화';

  @override
  String get assistantEditAvatarChooseImage => '이미지 선택';

  @override
  String get assistantEditAvatarChooseEmoji => '이모지 선택';

  @override
  String get assistantEditAvatarEnterLink => '링크 입력';

  @override
  String get assistantEditAvatarImportQQ => 'QQ에서 가져오기';

  @override
  String get assistantEditAvatarReset => '초기화';

  @override
  String get displaySettingsPageChatMessageBackgroundTitle => '채팅 메시지 배경';

  @override
  String get displaySettingsPageChatMessageBackgroundDefault => '기본';

  @override
  String get displaySettingsPageChatMessageBackgroundFrosted => '프로스트 글래스';

  @override
  String get displaySettingsPageChatMessageBackgroundSolid => '단색';

  @override
  String get displaySettingsPageAndroidBackgroundChatTitle =>
      '백그라운드 생성 (Android)';

  @override
  String get displaySettingsPageIosBackgroundChatTitle => '백그라운드 생성 (iOS)';

  @override
  String get iosBackgroundStatusOn => '켜짐';

  @override
  String get iosBackgroundStatusOff => '꺼짐';

  @override
  String get iosLiveActivityTitle => '실시간 활동';

  @override
  String get iosLiveActivitySubtitle =>
      '지원되는 경우 잠금 화면과 다이나믹 아일랜드에 백그라운드 응답 상태를 표시합니다.';

  @override
  String get notificationChatCompletedTitle => '생성 완료';

  @override
  String get notificationChatCompletedBody => '어시스턴트 응답이 생성되었습니다';

  @override
  String get assistantEditEmojiDialogTitle => '이모지 선택';

  @override
  String get assistantEditEmojiDialogHint => '아무 이모지나 입력하거나 붙여넣으세요';

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
  String get assistantEditQQAvatarDialogHint => 'QQ 번호 입력 (5-12자리)';

  @override
  String get assistantEditQQAvatarRandomButton => '무작위';

  @override
  String get assistantEditQQAvatarFailedMessage =>
      '무작위 QQ 아바타를 가져오지 못했습니다. 다시 시도해 주세요.';

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
  String get multiKeyPageDetect => '감지';

  @override
  String get multiKeyPageAdd => '추가';

  @override
  String get multiKeyPageAddHint => 'API 키를 입력하세요. 쉼표 또는 공백으로 구분';

  @override
  String multiKeyPageImportedSnackbar(int n) {
    return '키 $n개를 가져왔습니다';
  }

  @override
  String get multiKeyPagePleaseAddModel => '먼저 모델을 추가해 주세요';

  @override
  String get multiKeyPageTotal => '전체';

  @override
  String get multiKeyPageNormal => '정상';

  @override
  String get multiKeyPageError => '오류';

  @override
  String get multiKeyPageAccuracy => '정확도';

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
  String get multiKeyPageStatusActive => '활성';

  @override
  String get multiKeyPageStatusDisabled => '비활성화됨';

  @override
  String get multiKeyPageStatusError => '오류';

  @override
  String get multiKeyPageStatusRateLimited => '속도 제한';

  @override
  String get multiKeyPageEditAlias => '별칭 편집';

  @override
  String get multiKeyPageEdit => '편집';

  @override
  String get multiKeyPageKey => 'API 키';

  @override
  String get multiKeyPagePriority => '우선순위 (1–10)';

  @override
  String get multiKeyPageDuplicateKeyWarning => '이미 존재하는 키입니다';

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
  String get assistantEditSystemPromptImportSuccess =>
      '파일에서 시스템 프롬프트를 업데이트했습니다';

  @override
  String get assistantEditSystemPromptImportFailed => '파일 가져오기 실패';

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
  String get assistantEditVariableLocale => '로캘';

  @override
  String get assistantEditVariableTimezone => '시간대';

  @override
  String get assistantEditVariableSystemVersion => '시스템 버전';

  @override
  String get assistantEditVariableDeviceInfo => '기기 정보';

  @override
  String get assistantEditVariableBatteryLevel => '배터리 잔량';

  @override
  String get assistantEditVariableNickname => '닉네임';

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
      '시스템 프롬프트에 시간 변수를 사용하면 매 요청의 시작 부분이 달라져 프롬프트 캐시가 적중하지 못하고 비용과 첫 토큰 지연이 모두 증가합니다. 모델이 현재 시간을 알아야 한다면 아래의 \"현재 시간 추가\" 스위치를 사용하세요.';

  @override
  String get assistantEditPromptIso8601Title => 'ISO 8601 형식 사용';

  @override
  String get assistantEditPromptIso8601Subtitle =>
      '시간대 오프셋 포함, 예: 2026-08-08T14:30:05+08:00';

  @override
  String get assistantEditPromptAppendTimeTitle => '현재 시간 추가';

  @override
  String get assistantEditPromptAppendTimeSubtitle =>
      '각 사용자 메시지 끝에 전송 시각을 추가합니다. 시간이 요청 끝에 위치하므로 프롬프트 캐시에 영향을 주지 않습니다.';

  @override
  String get assistantEditPromptAppendTimeInfoTitle => '추가되는 시간 형식';

  @override
  String assistantEditPromptAppendTimeInfoBody(String example) {
    return '활성화하면 각 사용자 메시지 끝에 빈 줄과 다음 태그가 추가됩니다:\n\n$example\n\n타임스탬프는 해당 메시지 자체의 전송 시각이므로 재시도해도 변경되지 않습니다.';
  }

  @override
  String get assistantEditPromptAppendTimeInfoClose => '확인';

  @override
  String get assistantEditPromptTimeVarDialogTitle => '시스템 프롬프트에 시간 변수가 있습니다';

  @override
  String assistantEditPromptTimeVarDialogBody(String variables) {
    return '시스템 프롬프트에서 $variables을(를) 사용하고 있습니다. 시스템 프롬프트는 매 요청마다 다시 렌더링되므로 시간 변수가 있으면 매 요청의 시작 부분이 달라져 프롬프트 캐시가 적중하지 못합니다. 이 변수를 제거하고 \"현재 시간 추가\"를 사용하는 것을 권장합니다. 이 옵션은 시간을 요청 끝에 배치하여 접두사에 영향을 주지 않습니다.';
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
  String get codeBlockDefaultFileNameStem => '코드';

  @override
  String get markdownTableLabel => '표';

  @override
  String get markdownTableExportCsvTooltip => 'CSV 내보내기';

  @override
  String get markdownTableSaveImageTooltip => '갤러리에 저장';

  @override
  String get markdownTableDefaultFileNameStem => '표';

  @override
  String get markdownTableCopiedCsvSnackbar =>
      'CSV가 복사되었습니다. 복사를 길게 누르면 이미지로 복사됩니다.';

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
  String get assistantEditSampleMessage => '안녕하세요';

  @override
  String get assistantEditSampleReply => '안녕하세요, 무엇을 도와드릴까요?';

  @override
  String get assistantEditMcpNoServersMessage => '실행 중인 MCP 서버가 없습니다';

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
  String get assistantSettingsCopySuccess => '어시스턴트가 복사되었습니다';

  @override
  String get assistantSettingsCopySuffix => '사본';

  @override
  String get assistantCopyTitle => '어시스턴트 복사';

  @override
  String get assistantCopyDefaultHint => '복사할 항목을 선택하거나 전체를 복사하세요.';

  @override
  String get assistantCopyConfiguration => '어시스턴트 구성';

  @override
  String get assistantCopyConfigurationHint =>
      '항상 포함: 이름, 아바타, 프롬프트, 모델, 매개변수 및 사전 설정 메시지.';

  @override
  String get assistantCopyMemories => '어시스턴트 전용 기억';

  @override
  String get assistantCopyMemoriesHint =>
      '현재 및 레거시 기억을 포함하며 보관 상태를 유지합니다. 전역 기억은 계속 공유됩니다.';

  @override
  String get assistantCopyChooseMemories => '기억 선택';

  @override
  String get assistantCopyChooseEntries => '항목 선택';

  @override
  String get assistantCopyPhrasesHint =>
      '이 어시스턴트의 빠른 문구를 복사합니다. 전역 문구는 계속 공유됩니다.';

  @override
  String get assistantCopyBindingsHint =>
      '이 옵션들은 기존 리소스를 재사용하며 작업 공간 파일은 복사되지 않습니다. 선택하지 않은 세계관 책과 지시 주입은 전역 기본값을 사용합니다.';

  @override
  String get assistantCopyWorldBooks => '세계관 책 바인딩';

  @override
  String get assistantCopySkills => '스킬 선택';

  @override
  String get assistantCopyTools => '도구 및 검색 설정';

  @override
  String get assistantCopyWorkspace => '기본 작업 공간 바인딩';

  @override
  String get assistantCopyAll => '전체 복사';

  @override
  String get assistantCopyInProgress => '복사 중…';

  @override
  String get assistantCopyFailed =>
      '어시스턴트를 복사하지 못했습니다. 원본 데이터는 변경되지 않았습니다. 다시 시도해 주세요.';

  @override
  String get assistantCopyMemoryLoadFailed => '기억을 불러오지 못했습니다. 다시 시도해 주세요.';

  @override
  String get assistantCopyRetry => '재시도';

  @override
  String get assistantCopyNoMemories => '이 어시스턴트에는 복사할 전용 기억이 없습니다.';

  @override
  String get assistantCopySelectAll => '모든 기억 선택';

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
  String get desktopSidebarTabTopics => '토픽';

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
  String get hotkeyNewTopic => '새 토픽';

  @override
  String get hotkeySwitchModel => '모델 전환';

  @override
  String get hotkeyToggleAssistantPanel => '어시스턴트 표시 전환';

  @override
  String get hotkeyToggleTopicPanel => '토픽 표시 전환';

  @override
  String get hotkeysPressShortcut => '단축키를 누르세요';

  @override
  String get hotkeysResetDefault => '기본값으로 재설정';

  @override
  String get hotkeysClearShortcut => '단축키 지우기';

  @override
  String get hotkeysResetAll => '모든 단축키를 기본값으로 재설정';

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
      '어시스턴트가 최소 하나 필요합니다';

  @override
  String get assistantConversationMcpTitle => '대화별 MCP 허용';

  @override
  String get assistantConversationMcpHint =>
      '대화에서 자체 MCP 서버를 선택할 수 있습니다. 사용자 지정 전까지는 대화가 어시스턴트의 선택을 따릅니다.';

  @override
  String get mcpSelectionInherited => '어시스턴트 설정 따름';

  @override
  String get mcpSelectionCustom => '이 대화 전용 설정';

  @override
  String get mcpInheritAssistant => '어시스턴트 설정 사용';

  @override
  String get mcpAssistantSheetTitle => 'MCP 서버';

  @override
  String get mcpAssistantSheetSubtitle => '이 어시스턴트에 활성화된 서버';

  @override
  String get mcpAssistantSheetSelectAll => '전체 선택';

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
  String get backupPageFilesDescription =>
      '채팅 첨부 파일, 아바타, 배경 및 사용자 지정 글꼴입니다. 아바타나 배경을 복원하려면 해당 어시스턴트, 공급자 또는 설정도 함께 선택하세요.';

  @override
  String get backupPageChooseBackupFolder => '백업 폴더 선택';

  @override
  String get backupPageChooseExternalFolder =>
      'iCloud Drive 또는 \'내 iPhone > Kelivo\' 외부의 폴더를 선택하세요. Kelivo 폴더의 파일은 앱과 함께 삭제됩니다. 백업이 저장되지 않았습니다.';

  @override
  String get backupPageFilesLabel => '파일 및 이미지';

  @override
  String get backupPageScopeTitle => '백업 및 가져오기 내용';

  @override
  String backupPageScopeSelectedCount(int selected, int total) {
    return '$selected/$total';
  }

  @override
  String get backupPageBackupManagementDescription =>
      '백업 및 가져올 내용을 선택하세요. 로컬, WebDAV 및 S3 백업에 적용됩니다. 선택하지 않은 내용은 가져오기 시 변경되지 않습니다. 스킬과 작업 공간은 각자의 파일을 포함합니다.';

  @override
  String get backupPageAssistantsLabel => '어시스턴트';

  @override
  String get backupPageProvidersLabel => '공급자';

  @override
  String get backupPageMcpLabel => 'MCP 서버';

  @override
  String get backupPageEnvironmentVariablesLabel => '환경 변수';

  @override
  String get backupPageSkillsLabel => '스킬';

  @override
  String get backupPageWorldBooksLabel => '세계관 책';

  @override
  String get backupPageMemoriesLabel => '기억';

  @override
  String get backupPageQuickPhrasesLabel => '빠른 문구';

  @override
  String get backupPageInstructionsLabel => '프롬프트 주입';

  @override
  String get backupPageWorkspacesLabel => '작업 공간';

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
  String get backupPageRestartRequired => '재시작 필요';

  @override
  String get backupPageRestartContent =>
      '가져오기에 성공했습니다. 안전하게 적용하려면 Kelivo를 재시작하세요.';

  @override
  String backupPageRestartContentWithSkipped(int count) {
    return '가져오기가 완료되었지만 메시지 순서가 잘못된 대화 $count개를 건너뛰었습니다. 가져온 데이터를 안전하게 적용하려면 Kelivo를 재시작하세요.';
  }

  @override
  String get restartAppFailedMessage =>
      'Kelivo를 자동으로 재시작하지 못했습니다. 완전히 종료한 후 다시 실행하세요.';

  @override
  String get backupRestoreRolledBackTitle => '복원이 롤백되었습니다';

  @override
  String get backupRestoreRolledBackContent =>
      '복원을 완료하지 못했습니다. Kelivo가 확인 후 기존 데이터를 유지했습니다.';

  @override
  String get backupRestoreDirectoryBlockedTitle => '복원이 폴더 해제를 기다리는 중입니다';

  @override
  String get backupRestoreDirectoryBlockedContent =>
      'Windows가 아래 폴더를 이동하지 못했습니다. 해당 폴더를 사용 중인 터미널, 편집기 또는 기타 프로그램을 닫은 후 복원을 계속하세요. 계속 차단되면 현재 계정에 폴더 이동 권한이 있는지 확인하세요. 복원 진행 상황은 유지되었습니다.';

  @override
  String get backupRestoreContinueButton => '복원 계속';

  @override
  String get backupRestoreFailureTitle => '복원에 조치가 필요합니다';

  @override
  String get backupRestoreFailureContent =>
      'Kelivo가 기존 또는 새 데이터 세트의 완전성을 확인하지 못해 채팅 데이터를 열지 않았습니다. Kelivo를 종료한 후 다시 시도하세요. 문제가 반복되면 지원을 위해 진단 코드를 보관하세요.';

  @override
  String get backupRestoreBusinessLeaseUnavailableTitle => 'Kelivo가 이미 실행 중입니다';

  @override
  String get backupRestoreBusinessLeaseUnavailableContent =>
      'Kelivo의 데이터가 다른 앱 프로세스에서 아직 사용 중입니다. 다른 Kelivo 창을 닫은 후 다시 시작하세요. 현재 프로세스는 채팅 데이터를 열지 않았습니다.';

  @override
  String get restoreProgressTitle => '백업 복원 중';

  @override
  String get restoreProgressWarning =>
      '완료될 때까지 Kelivo를 열어 두세요. 지금 닫으면 다음 실행 시 처음부터 다시 시작됩니다.';

  @override
  String get restoreProgressStageCheckingBackup => '백업 확인 중';

  @override
  String get restoreProgressStagePreservingCurrentData => '현재 데이터 보존 중';

  @override
  String get restoreProgressStageInstallingBackup => '백업 설치 중';

  @override
  String get restoreProgressStageVerifying => '확인 중';

  @override
  String get restoreProgressStageRollingBack => '이전 데이터 복원 중';

  @override
  String get restoreProgressStageFinishing => '마무리 중';

  @override
  String get backupRestoreFailureRestartButton => 'Kelivo 재시작';

  @override
  String get backupRestoreFailureCopyButton => '진단 코드 복사';

  @override
  String get backupRestoreFailureCopied => '진단 코드가 복사되었습니다';

  @override
  String backupRestoreFailureDiagnostic(String code) {
    return '진단 코드: $code';
  }

  @override
  String get startupRecoveryMoreOptions => '추가 복구 옵션';

  @override
  String get startupRecoveryRepairButton => '복구 후 재시작';

  @override
  String get startupRecoveryExportButton => '내 데이터 사본 내보내기';

  @override
  String get startupRecoveryResetButton => '빈 채팅 목록으로 시작';

  @override
  String get startupRecoveryBusy => '처리 중…';

  @override
  String get startupRecoveryExportSucceeded => '데이터 사본이 저장되었습니다.';

  @override
  String get startupRecoveryExportFailed => '데이터 사본을 내보낼 수 없습니다.';

  @override
  String get startupRecoveryRepairFailed =>
      '복구를 완료할 수 없습니다. 데이터는 보존되어 있습니다. 검증된 사본을 선택하거나 데이터를 내보내 추가로 진단하세요.';

  @override
  String get startupRecoveryResetFailed =>
      '초기화에 실패했습니다. Kelivo를 완전히 종료한 후 다시 열어 주세요.';

  @override
  String get startupRecoveryResetDialogTitle => '빈 채팅 목록으로 시작할까요?';

  @override
  String get startupRecoveryResetDialogContent =>
      '이 작업은 이전 채팅을 복구하지 않습니다. Kelivo는 현재 데이터베이스와 기존 사본을 유지하고 새로운 빈 채팅 목록을 시작합니다. 채팅을 되찾으려면 취소하고 로컬 사본을 선택하세요.';

  @override
  String get startupRecoveryResetDialogConfirm => '사본 유지하고 새로 시작';

  @override
  String get startupRecoveryResetDialogCancel => '취소';

  @override
  String get startupRecoveryWhatFailed => '실패 원인';

  @override
  String get startupRecoveryStageLabel => '단계';

  @override
  String get startupRecoveryStageRestore => '복원 게이트';

  @override
  String get startupRecoveryStageDatabase => '데이터베이스 시작';

  @override
  String get startupRecoveryDiagnosticLabel => '진단 코드';

  @override
  String get startupRecoverySchemaLabel => '데이터베이스 버전';

  @override
  String startupRecoverySchemaValue(String installed, int expected) {
    return '디스크: $installed · 이 빌드에서 요구: $expected';
  }

  @override
  String get startupRecoveryAppVersionLabel => '앱';

  @override
  String get startupRecoveryUnknownValue => '알 수 없음';

  @override
  String get startupRecoveryCollecting => '진단 정보 수집 중…';

  @override
  String get startupRecoveryShowDetails => '기술 세부 정보 표시';

  @override
  String get startupRecoveryHideDetails => '기술 세부 정보 숨기기';

  @override
  String get startupRecoveryCopyReport => '전체 보고서 복사';

  @override
  String get startupRecoveryReportCopied => '전체 보고서가 복사되었습니다';

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
  String get startupRecoveryReportSaveFailed => '보고서를 내보낼 수 없습니다.';

  @override
  String get startupRecoverySectionDataTitle => '내 데이터';

  @override
  String get startupRecoverySectionDataBody =>
      '계속하기 전에 남은 데이터를 내보내 안전한 곳에 보관할 수도 있습니다.';

  @override
  String startupRecoveryExportSavedTo(String path) {
    return '데이터 사본이 $path에 저장되었습니다';
  }

  @override
  String get startupRecoverySectionRepairTitle => '진단 및 복구';

  @override
  String get startupRecoverySectionRepairBody =>
      '무결성 검사는 데이터베이스를 읽기만 합니다. 복구는 중단된 업데이트에서 남은 메타데이터를 정리하고 시작을 다시 시도하며, 채팅을 삭제하지 않습니다.';

  @override
  String get startupRecoveryIntegrityButton => '데이터베이스 무결성 검사';

  @override
  String get startupRecoveryIntegrityHealthy =>
      'SQLite가 데이터베이스 파일에서 손상을 발견하지 않았습니다.';

  @override
  String startupRecoveryIntegrityDamaged(String detail) {
    return 'SQLite가 문제를 보고했습니다 — $detail';
  }

  @override
  String get startupRecoveryIntegrityMissing =>
      '데이터 폴더에서 데이터베이스 파일을 찾을 수 없습니다.';

  @override
  String get startupRecoveryIntegrityFailed => '무결성 검사를 실행할 수 없습니다.';

  @override
  String get startupRecoveryDangerZone => '기타 옵션';

  @override
  String get startupRecoveryDangerBody =>
      '새로 시작하면 현재 데이터가 표시되지 않습니다. Kelivo는 복구를 위해 기존 데이터베이스와 기존 사본을 보존합니다. 가능하면 먼저 데이터 사본을 내보내세요.';

  @override
  String get startupRecoveryResetAcknowledge =>
      '지금 채팅을 복구하지 않고 빈 채팅 목록으로 계속 진행하는 데 동의합니다.';

  @override
  String get startupDatabaseUpdateRequiredTitle => '계속하려면 Kelivo를 업데이트하세요';

  @override
  String get startupDatabaseUpdateRequiredContent =>
      '이 기기의 채팅 데이터베이스는 더 새로운 버전의 Kelivo에서 생성되어 현재 버전에서는 열 수 없습니다. 데이터는 변경되지 않았습니다. 최신 버전의 Kelivo를 설치한 후 다시 열어 주세요.';

  @override
  String get startupDatabaseUpdateRequiredDowngradeTitle => '이전 버전이 필요한 경우';

  @override
  String get startupDatabaseUpdateRequiredDowngradeIntro =>
      '현재 버전은 이 기기의 데이터베이스를 열 수 없습니다. 이전 버전을 계속 사용해야 한다면 아래 단계를 따르세요. 백업이 완료되기 전까지는 여기의 데이터를 삭제하거나 덮어쓰지 마세요.';

  @override
  String get startupDatabaseUpdateRequiredDowngradeStep1 =>
      '최신 버전의 Kelivo를 설치하고 열어서 설정 → 백업에서 백업 파일을 내보내세요.';

  @override
  String startupDatabaseUpdateRequiredDowngradeStep2(String url) {
    return '$url을(를) 열고 해당 백업을 사용하려는 이전 버전으로 변환하세요.';
  }

  @override
  String get startupDatabaseUpdateRequiredDowngradeStep3 =>
      '이 기기의 데이터가 백업되었음을 확인한 후 이전 버전을 설치하고 변환된 백업을 가져오세요.';

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
      '복원 방식을 선택하세요. 백업 관리의 스위치는 이번 가져오기에도 적용됩니다.';

  @override
  String get backupPageOverwriteMode => '완전 덮어쓰기';

  @override
  String get backupPageOverwriteModeDescription =>
      '선택한 항목을 교체하고 선택하지 않은 항목과 관련 없는 로컬 설정은 유지합니다. 채팅을 교체하면 로컬의 전송되지 않은 임시 저장 내용도 삭제됩니다.';

  @override
  String get backupPageMergeMode => '병합';

  @override
  String get backupPageMergeModeDescription =>
      '로컬 데이터를 유지하고 백업 데이터를 추가합니다. 동일한 대화는 건너뛰고 충돌하는 대화에는 새 ID가 부여됩니다.';

  @override
  String get backupPageRestore => '복원';

  @override
  String get backupPageForwardCompatTitle => '더 새로운 버전의 백업입니다';

  @override
  String backupPageForwardCompatBody(int backupVersion, int currentVersion) {
    return '이 백업은 더 새로운 버전의 Kelivo에서 생성되었습니다(데이터 형식 $backupVersion, 현재 버전 지원 $currentVersion). 이전 버전에서 읽을 수 있는지 여부는 명시되지 않았습니다.\n\n계속할 수 있습니다. 현재 버전이 인식하지 못하는 내용은 건너뛰며 백업 파일 자체는 수정되지 않습니다. 하지만 새 버전에서 기존 데이터 저장 방식을 변경했다면 일부 내용이 잘못 가져와질 수 있습니다.\n\nKelivo를 먼저 업데이트하는 것이 더 안전합니다.';
  }

  @override
  String get backupPageForwardCompatContinue => '그래도 가져오기';

  @override
  String get backupPageForwardCompatCancel => '취소';

  @override
  String get backupPageSchemaTooNewMessage =>
      '이 백업은 더 새로운 버전의 Kelivo에서 생성되어 현재 버전에서는 읽을 수 없습니다. Kelivo를 업데이트한 후 다시 시도하세요.';

  @override
  String get backupPageBackupUploaded => '백업 업로드됨';

  @override
  String get backupPageBackup => '백업';

  @override
  String get backupPageExporting => '내보내는 중...';

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
  String get backupProgressErrorCopied => '오류가 복사됨';

  @override
  String get backupProgressPreparing => '준비 중';

  @override
  String get backupProgressSnapshotting => '데이터베이스 스냅샷 생성 중';

  @override
  String get backupProgressPacking => '패키징 중';

  @override
  String get backupProgressVerifying => '검증 중';

  @override
  String get backupProgressUploading => '업로드 중';

  @override
  String get backupProgressDownloading => '다운로드 중';

  @override
  String get backupProgressExtracting => '압축 해제 중';

  @override
  String get backupProgressValidating => '확인 중';

  @override
  String get backupProgressReadingSettings => '설정 읽는 중';

  @override
  String get backupProgressStaging => '준비 중';

  @override
  String get backupProgressCommitting => '커밋 중';

  @override
  String get backupProgressImportingSessions => '세션 가져오는 중';

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
  String get backupPageExportToFile => '지금 백업';

  @override
  String get backupPageExportToFileSubtitle => '선택한 콘텐츠를 백업 파일로 저장';

  @override
  String get backupPageImportBackupFile => '백업 파일 가져오기';

  @override
  String get backupPageImportBackupFileSubtitle => '로컬 백업 파일 가져오기';

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
    return '원격 백업 \"$name\"을(를) 삭제하시겠습니까? 이 작업은 되돌릴 수 없습니다.';
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
  String get backupPageS3Bucket => 'Bucket';

  @override
  String get backupPageS3AccessKeyId => '액세스 키 ID';

  @override
  String get backupPageS3SecretAccessKey => '비밀 액세스 키';

  @override
  String get backupPageS3SessionToken => '세션 토큰 (선택 사항)';

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
  String get backupPageIosSystemBackupNote =>
      'Kelivo의 로컬 데이터는 iCloud 기기 백업에 포함되지 않습니다. 기기를 변경하거나 앱을 삭제하기 전에 iCloud Drive 또는 Kelivo 외부의 폴더에 백업하세요. \'내 iPhone > Kelivo\'의 파일은 앱과 함께 삭제됩니다.';

  @override
  String get backupPageImportFromCherryStudio => 'Cherry Studio에서 가져오기';

  @override
  String backupPageCherryStudioUnsupportedBackupVersion(String version) {
    return '이 백업은 Cherry Studio 형식 버전 $version을(를) 사용하며, Kelivo에서는 아직 가져올 수 없습니다. Cherry Studio v1에서 내보내거나 Cherry Studio v2 백업을 지원하는 Kelivo 업데이트를 기다리세요.';
  }

  @override
  String get backupPageImportFromChatbox => 'Chatbox에서 가져오기';

  @override
  String get webDavScheduleTitle => 'WebDAV 예약 백업';

  @override
  String get webDavScheduleEnabled => '자동 백업';

  @override
  String get webDavScheduleInterval => '반복 간격';

  @override
  String get webDavScheduleWifiOnly => 'Wi-Fi / 이더넷에서만';

  @override
  String get webDavScheduleWifiOnlyHint =>
      '업로드에 Wi-Fi 또는 이더넷을 사용합니다. Android 백그라운드 백업은 데이터 사용량 제한이 없는 연결도 기다립니다.';

  @override
  String get webDavScheduleAndroidHint =>
      'Android는 백그라운드에서 백업을 실행합니다. 배터리 및 네트워크 제한으로 지연될 수 있습니다. 앱을 강제 중지하면 다시 열 때까지 백업이 중지됩니다.';

  @override
  String get webDavScheduleForegroundHint =>
      '앱이 열려 있는 동안 백업을 실행합니다. 놓친 백업은 앱으로 돌아오면 실행합니다.';

  @override
  String get webDavScheduleConfigureFirst =>
      '자동 백업을 켜기 전에 WebDAV 서버를 설정하고 저장하세요.';

  @override
  String get webDavScheduleLastSuccess => '마지막 백업 성공';

  @override
  String get webDavScheduleNextRun => '다음 백업 (예상)';

  @override
  String get webDavScheduleStatus => '상태';

  @override
  String get webDavScheduleRunNow => '지금 백업';

  @override
  String get webDavScheduleRunning => '백업 중…';

  @override
  String get webDavScheduleFinishingBackgroundBackup => '백그라운드 백업 마무리 중…';

  @override
  String get webDavScheduleReady => '다음 백업 대기 중';

  @override
  String get webDavScheduleFailed => '마지막 백업 실패';

  @override
  String get webDavScheduleDisabled => '꺼짐';

  @override
  String get webDavScheduleNotConfigured => 'WebDAV 서버가 설정되지 않았습니다';

  @override
  String webDavScheduleEveryHours(int hours) {
    String _temp0 = intl.Intl.pluralLogic(
      hours,
      locale: localeName,
      other: '$hours시간마다',
      one: '매시간',
    );
    return '$_temp0';
  }

  @override
  String get webDavScheduleEveryDay => '매일';

  @override
  String get webDavScheduleNever => '없음';

  @override
  String get webDavScheduleDue => '조건이 충족되면';

  @override
  String get webDavScheduleSaved => '백업 일정이 저장되었습니다';

  @override
  String get webDavScheduleSaveFailed => '백업 일정을 저장하지 못했습니다';

  @override
  String get webDavScheduleSucceeded => '백업이 업로드되었습니다';

  @override
  String get webDavScheduleUnavailable => '백그라운드 예약을 사용할 수 없습니다';

  @override
  String get webDavScheduleWifiRequired => 'Wi-Fi 또는 이더넷 대기 중';

  @override
  String get webDavScheduleNetworkUnavailable => '네트워크 연결 대기 중';

  @override
  String get webDavScheduleBackupBusy => '다른 백업 또는 복원이 진행 중입니다';

  @override
  String get webDavScheduleRetry => '재시도 대기 중';

  @override
  String get webDavScheduleTimedOut => '백업 시간이 초과되었습니다';

  @override
  String get webDavSchedulePasswordRequired =>
      '암호화 백업에는 비밀번호 확인이 필요합니다. WebDAV에 수동으로 백업하거나 예약 백업을 사용하려면 백업 암호화를 끄세요.';

  @override
  String get webDavScheduleCancelled => '백업이 취소되었습니다';

  @override
  String get backupReminderSectionTitle => '백업 알림';

  @override
  String get backupReminderEnableTitle => '백업 알림 받기';

  @override
  String get backupReminderFrequencyTitle => '빈도';

  @override
  String get backupReminderTimeTitle => '알림 시간';

  @override
  String get backupReminderTimeInputHint => 'HH:mm';

  @override
  String get backupReminderTimeInvalid => '00:00부터 23:59 사이의 시간을 입력하세요.';

  @override
  String get backupReminderLastBackupTitle => '마지막 백업';

  @override
  String get backupReminderNextReminderTitle => '다음 알림';

  @override
  String get backupReminderNever => '없음';

  @override
  String get backupReminderDisabled => '꺼짐';

  @override
  String get backupReminderDueNow => '지금 알림 예정';

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
  String get backupReminderCustomOption => '사용자 지정...';

  @override
  String get backupReminderCustomDialogTitle => '사용자 지정 빈도';

  @override
  String get backupReminderCustomDialogDescription => '백업 알림 사이의 일수를 입력하세요.';

  @override
  String get backupReminderCustomDaysLabel => '일수';

  @override
  String get backupReminderCustomDaysInvalid => '1에서 365 사이의 숫자를 입력하세요.';

  @override
  String get backupReminderSidebarTitle => '백업 알림';

  @override
  String get backupReminderSidebarSubtitle => '설정한 백업 주기가 되었습니다.';

  @override
  String get backupReminderSidebarAction => '백업하러 가기';

  @override
  String get backupReminderSnoozeTooltip => '나중에 알림';

  @override
  String get chatHistoryPageTitle => '채팅 기록';

  @override
  String get chatHistoryPageSearchTooltip => '검색';

  @override
  String get chatHistoryPageDeleteAllTooltip => '고정되지 않은 항목 삭제';

  @override
  String get chatHistoryPageDeleteAllDialogTitle => '고정되지 않은 대화 삭제';

  @override
  String get chatHistoryPageDeleteAllDialogContent =>
      '이 어시스턴트의 고정되지 않은 모든 대화를 삭제할까요? 고정된 채팅은 유지됩니다.';

  @override
  String get chatHistoryPageCancel => '취소';

  @override
  String get chatHistoryPageDelete => '삭제';

  @override
  String get chatHistoryPageDeletedAllSnackbar => '고정되지 않은 대화가 삭제되었습니다';

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
  String get messageEditPageSaveAndSend => '저장 및 전송';

  @override
  String get messageEditPageHint => '메시지를 입력하세요…';

  @override
  String get userMessageEditSaveOnly => '저장만';

  @override
  String get userMessageEditUnsupportedSnackbar => '이 콘텐츠는 편집을 지원하지 않습니다';

  @override
  String get userMessageEditOverwriteTitle => '알림';

  @override
  String get userMessageEditOverwriteContent =>
      '편집하면 입력창의 기존 내용을 덮어씁니다. 덮어쓸까요?';

  @override
  String get selectCopyPageTitle => '선택 및 복사';

  @override
  String get selectCopyPageCopyAll => '전체 복사';

  @override
  String get selectCopyPageCopiedAll => '전체 복사됨';

  @override
  String get bottomToolsSheetCamera => '카메라';

  @override
  String get bottomToolsSheetPhotos => '사진';

  @override
  String get bottomToolsSheetUpload => '업로드';

  @override
  String get bottomToolsSheetClearContext => '컨텍스트 지우기';

  @override
  String get compressContext => '컨텍스트 압축';

  @override
  String get compressContextDesc =>
      '이전 채팅을 요약으로 만듭니다. 원본은 채팅에 그대로 남아 있으며 언제든지 취소할 수 있습니다.';

  @override
  String get clearContextDesc =>
      '여기서 새로 시작합니다. 이전 메시지는 채팅에 남아 있지만 모델에 전송되지 않습니다.';

  @override
  String get contextManagement => '컨텍스트 관리';

  @override
  String get compressContextFailed => '압축이 완료되지 않았습니다';

  @override
  String get compressContextNoMessages => '이 채팅에는 압축할 내용이 없습니다.';

  @override
  String get compressContextNoConversation => '압축할 대화가 없습니다.';

  @override
  String get compressContextNoModel =>
      '압축에 사용할 모델이 설정되지 않았습니다. 설정에서 빠른 모델을 선택하세요.';

  @override
  String get compressContextEmptySummary =>
      '모델이 요약을 생성하지 않았습니다. 다른 모델을 사용하거나 옵션을 변경한 후 다시 시도하세요.';

  @override
  String get compressContextOptionsTitle => '컨텍스트 압축';

  @override
  String get compressContextOptionsDesc =>
      '이전 메시지를 요약으로 만들면 다음에 모델이 보게 되는 것은 이 요약입니다. 원본 채팅은 유지되며 요약을 편집하거나 취소할 수 있습니다.';

  @override
  String get compressContextKeepStart => '이전 기록';

  @override
  String get compressContextKeepRecent => '최근 기록';

  @override
  String get compressContextUnlimited => '전체 활성 기록';

  @override
  String get compressContextMaxCharsLabel => '문자 수';

  @override
  String get compressContextInvalidLimit => '0보다 큰 문자 수를 입력하세요';

  @override
  String get compressContextStartButton => '압축';

  @override
  String get compressContextModelLabel => '모델';

  @override
  String get compressContextModelUnset => '모델 선택';

  @override
  String get compressContextKeepRecentMessages => '최근 턴 유지';

  @override
  String get compressContextKeepCountLabel => '유지할 최근 사용자 메시지 수';

  @override
  String get compressContextKeepAllMessages =>
      '유지할 메시지 수가 전체 채팅을 포함하므로 압축할 내용이 남아 있지 않습니다.';

  @override
  String compressContextEstimatePreview(
    int summarized,
    int kept,
    int minTokens,
    int maxTokens,
    int totalTokens,
  ) {
    return '$summarized자를 요약하고 $kept자를 그대로 유지합니다. 압축 후 약 $minTokens–$maxTokens 토큰(원본 약 $totalTokens 토큰)';
  }

  @override
  String get bottomToolsSheetLearningMode => '학습 모드';

  @override
  String get bottomToolsSheetLearningModeDescription => '단계별로 학습을 도와드립니다';

  @override
  String get bottomToolsSheetConfigurePrompt => '프롬프트 설정';

  @override
  String get bottomToolsSheetPrompt => '프롬프트';

  @override
  String get bottomToolsSheetPromptHint => '주입할 프롬프트 텍스트를 입력하세요';

  @override
  String get bottomToolsSheetResetDefault => '기본값으로 재설정';

  @override
  String get bottomToolsSheetSave => '저장';

  @override
  String get bottomToolsSheetOcr => '이미지 OCR';

  @override
  String get messageMoreSheetTitle => '추가 작업';

  @override
  String get messageMoreSheetSelectCopy => '선택 및 복사';

  @override
  String get messageMoreSheetRenderWebView => '웹 뷰로 렌더링';

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
  String get reasoningBudgetSheetTitle => '추론 체인 강도';

  @override
  String get reasoningLevelSheetTitle => '추론';

  @override
  String get reasoningLevelAuto => '자동';

  @override
  String get reasoningLevelAutoSubtitle => '모델 또는 공급자의 기본 설정을 사용합니다';

  @override
  String get reasoningLevelOff => '끄기';

  @override
  String get reasoningLevelOn => '켜기';

  @override
  String get reasoningLevelOnSubtitle => '추론을 활성화합니다';

  @override
  String get reasoningLevelOffSubtitle => '추론을 끄고 바로 답변합니다';

  @override
  String get reasoningLevelMinimal => '최소';

  @override
  String get reasoningLevelMinimalSubtitle => '최소한의 추론으로 질문에 답변합니다';

  @override
  String get reasoningLevelLow => '낮음';

  @override
  String get reasoningLevelLowSubtitle => '적은 추론으로 질문에 답변합니다';

  @override
  String get reasoningLevelMedium => '중간';

  @override
  String get reasoningLevelMediumSubtitle => '적당한 추론으로 질문에 답변합니다';

  @override
  String get reasoningLevelHigh => '높음';

  @override
  String get reasoningLevelHighSubtitle => '복잡한 질문에 많은 추론을 사용합니다';

  @override
  String get reasoningLevelXhigh => '매우 높음';

  @override
  String get reasoningLevelXhighSubtitle => '더 어려운 문제에 매우 높은 추론 깊이를 사용합니다';

  @override
  String get reasoningLevelMax => '최대';

  @override
  String get reasoningLevelMaxSubtitle => '가장 어려운 문제에 최대 추론 깊이를 사용합니다';

  @override
  String get reasoningLevelFollowModelDefaultSubtitle =>
      '어시스턴트가 설정하지 않은 경우 모델의 기본값을 사용합니다';

  @override
  String get reasoningLevelNoReasoning => '이 모델은 추론을 지원하지 않습니다';

  @override
  String get reasoningLevelCustomBudget => '사용자 지정 추론 예산';

  @override
  String get reasoningLevelCustomBudgetHint => '토큰 예산, 예: 2048';

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
    return '파일을 찾을 수 없음: $fileName';
  }

  @override
  String chatMessageWidgetCannotOpenFile(String message) {
    return '파일을 열 수 없음: $message';
  }

  @override
  String chatMessageWidgetOpenFileError(String error) {
    return '파일 열기 실패: $error';
  }

  @override
  String get chatMessageWidgetCopiedToClipboard => '클립보드에 복사됨';

  @override
  String get chatMessageWidgetResendTooltip => '다시 보내기';

  @override
  String get chatMessageWidgetMoreTooltip => '더 보기';

  @override
  String get chatMessageWidgetThinking => '생각 중...';

  @override
  String get chatMessageWidgetTranslation => '번역';

  @override
  String get chatMessageWidgetTranslating => '번역 중...';

  @override
  String get chatMessageWidgetCitationNotFound => '인용 출처를 찾을 수 없음';

  @override
  String chatMessageWidgetCannotOpenUrl(String url) {
    return '링크를 열 수 없음: $url';
  }

  @override
  String get chatMessageWidgetOpenLinkError => '링크 열기 실패';

  @override
  String get chatMessageWidgetAttachmentUnavailable => '첨부 파일을 사용할 수 없음';

  @override
  String chatMessageWidgetCitationsTitle(int count) {
    return '인용 ($count)';
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
      '다시 생성하면 이 메시지 아래의 모든 메시지가 삭제되며 되돌릴 수 없습니다. 계속하시겠습니까?';

  @override
  String get chatMessageWidgetRegenerateConfirmCancel => '취소';

  @override
  String get chatMessageWidgetRegenerateConfirmOk => '다시 생성';

  @override
  String get chatMessageWidgetStopTooltip => '중지';

  @override
  String get chatMessageWidgetSpeakTooltip => '읽기';

  @override
  String get chatMessageWidgetTranslateTooltip => '번역';

  @override
  String get chatMessageWidgetBuiltinSearchHideNote => '내장 검색 도구 카드 숨기기';

  @override
  String get chatMessageWidgetDeepThinking => '심층 사고';

  @override
  String chatMessageWidgetWebSearch(String query) {
    return '웹 검색: $query';
  }

  @override
  String chatMessageWidgetWebFetch(String target) {
    return '페이지 읽기: $target';
  }

  @override
  String get chatMessageWidgetBuiltinSearch => '내장 검색';

  @override
  String get chatMessageWidgetReadClipboard => '클립보드 읽기';

  @override
  String get chatMessageWidgetWriteClipboard => '클립보드 쓰기';

  @override
  String get chatMessageWidgetSpeakingTitle => '읽는 중:';

  @override
  String chatMessageWidgetSpeakText(String text) {
    return '읽는 중: $text';
  }

  @override
  String get chatMessageWidgetMemoryRead => '메모리 읽기';

  @override
  String get chatMessageWidgetMemoryUpdate => '메모리 업데이트';

  @override
  String get chatMessageWidgetMemorySearchProfile => '기억 검색';

  @override
  String get chatMessageWidgetMemoryEdit => '기억 편집';

  @override
  String get chatMessageWidgetMemoryDelete => '기억 삭제';

  @override
  String get chatMessageWidgetUpdateUserProfile => '사용자 프로필 업데이트';

  @override
  String get chatMessageWidgetChatSearch => '지난 대화 검색';

  @override
  String get chatMessageWidgetCreateMemory => '기억 생성';

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
  String get chatSelectionThinkingTools => '사고 도구';

  @override
  String get chatSelectionThinkingContent => '사고 내용';

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
  String get messageExportSheetDefaultTitle => '새 대화';

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
      '\$...\$ 안의 내용을 인라인 수식으로 렌더링';

  @override
  String get displaySettingsPageEnableMathTitle => '수학 공식 렌더링';

  @override
  String get displaySettingsPageEnableMathSubtitle => 'LaTeX 수식 렌더링(인라인 및 블록)';

  @override
  String get displaySettingsPageUseLegacyInlineCodeStyleTitle =>
      '이전 인라인 코드 스타일';

  @override
  String get displaySettingsPageUseLegacyInlineCodeStyleSubtitle =>
      '인라인 코드에 더 밝은 배경, 얇은 테두리, 더 넓은 줄 간격을 사용합니다.';

  @override
  String get displaySettingsPageUseLegacyCodeBlockStyleTitle => '이전 코드 블록 스타일';

  @override
  String get displaySettingsPageUseLegacyCodeBlockStyleSubtitle =>
      '코드 블록의 이전 색상, 모서리 둥글기, 간격을 복원합니다.';

  @override
  String get displaySettingsPageEnableUserMarkdownTitle =>
      '사용자 메시지 Markdown 렌더링';

  @override
  String get displaySettingsPageEnableReasoningMarkdownTitle =>
      '추론(사고) Markdown 렌더링';

  @override
  String get displaySettingsPageEnableAssistantMarkdownTitle =>
      '어시스턴트 메시지 Markdown 렌더링';

  @override
  String get displaySettingsPageMobileCodeBlockWrapTitle => '모바일 코드 블록 자동 줄바꿈';

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
      '기준을 초과한 사용자 메시지를 접어서 펼치기 버튼으로 표시';

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
      '이 메시지를 Markdown 파일로 내보내기';

  @override
  String get messageExportSheetBatchMarkdownSubtitle =>
      '선택한 메시지를 Markdown 파일로 내보내기';

  @override
  String get messageExportSheetPlainText => '일반 텍스트';

  @override
  String get messageExportSheetSingleTxtSubtitle => '이 메시지를 TXT 파일로 내보내기';

  @override
  String get messageExportSheetBatchTxtSubtitle => '선택한 메시지를 TXT 파일로 내보내기';

  @override
  String get messageExportSheetExportImage => '이미지로 내보내기';

  @override
  String get messageExportSheetSingleExportImageSubtitle =>
      '이 메시지를 PNG 이미지로 렌더링';

  @override
  String get messageExportSheetBatchExportImageSubtitle =>
      '선택한 메시지를 PNG 이미지로 렌더링';

  @override
  String get messageExportSheetShowThinkingAndToolCards => '깊은 사고 및 도구 카드 표시';

  @override
  String get messageExportSheetShowThinkingContent => '사고 내용 표시';

  @override
  String get messageExportThinkingContentLabel => '사고 내용';

  @override
  String get messageExportSheetDateTimeWithSecondsPattern =>
      'yyyy-MM-dd HH:mm:ss';

  @override
  String get exportDisclaimerAiGenerated => 'AI가 생성한 콘텐츠입니다. 신중하게 확인하세요.';

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
  String get sideDrawerMenuSelect => '선택';

  @override
  String sideDrawerSelectionTitle(int count) {
    return '$count개 선택됨';
  }

  @override
  String get sideDrawerSelectionSelectAll => '전체 선택';

  @override
  String get sideDrawerSelectionDeselectAll => '전체 선택 해제';

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
  String sideDrawerDeleteSelectedSnackbar(int count) {
    return '대화 $count개 삭제됨';
  }

  @override
  String sideDrawerMoveSelectedSnackbar(int count) {
    return '대화 $count개 이동됨';
  }

  @override
  String sideDrawerDeleteSnackbar(String title) {
    return '\"$title\" 삭제됨';
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
  String get sideDrawerGreetingMorning => '좋은 아침이에요 👋';

  @override
  String get sideDrawerGreetingNoon => '좋은 점심이에요 👋';

  @override
  String get sideDrawerGreetingAfternoon => '좋은 오후예요 👋';

  @override
  String get sideDrawerGreetingEvening => '좋은 저녁이에요 👋';

  @override
  String get sideDrawerDateToday => '오늘';

  @override
  String get sideDrawerDateYesterday => '어제';

  @override
  String get sideDrawerDateShortPattern => 'M월 d일';

  @override
  String get sideDrawerDateFullPattern => 'yyyy년 M월 d일';

  @override
  String get sideDrawerSearchHint => '현재 어시스턴트 검색';

  @override
  String get sideDrawerSearchAssistantsHint => '어시스턴트 검색';

  @override
  String get sideDrawerTopicSearchModeLabel => '토픽 모드';

  @override
  String get sideDrawerGlobalSearchModeLabel => '전체 모드';

  @override
  String get sideDrawerSearchModeSwipeToTopicHint => '검색창을 스와이프하여 토픽 검색';

  @override
  String get sideDrawerSearchModeSwipeToGlobalHint => '검색창을 스와이프하여 전체 검색';

  @override
  String get sideDrawerGlobalSearchHint => '모든 세션 검색';

  @override
  String get sideDrawerGlobalSearchEmptyHint => '제목과 메시지에서 전체 검색';

  @override
  String get sideDrawerGlobalSearchNoResults => '일치하는 세션 없음';

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
    return '새 버전: $version ($build)';
  }

  @override
  String get sideDrawerLinkCopied => '링크가 복사되었습니다';

  @override
  String get sideDrawerPinnedLabel => '고정됨';

  @override
  String get sideDrawerHistory => '기록';

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
  String get sideDrawerReset => '초기화';

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
  String get providerAvatarLobehubDialogHint => 'LobeHub 아이콘 이름 입력, 예: openai';

  @override
  String get sideDrawerEmojiDialogTitle => '이모지 선택';

  @override
  String get sideDrawerEmojiDialogHint => '아무 이모지나 입력하거나 붙여넣으세요';

  @override
  String get sideDrawerImageUrlDialogTitle => '이미지 URL 입력';

  @override
  String get sideDrawerImageUrlDialogHint =>
      '예: https://example.com/avatar.png';

  @override
  String get sideDrawerQQAvatarDialogTitle => 'QQ에서 가져오기';

  @override
  String get sideDrawerQQAvatarInputHint => 'QQ 번호 입력 (5-12자리)';

  @override
  String get sideDrawerQQAvatarFetchFailed =>
      '랜덤 QQ 아바타를 가져오지 못했습니다. 다시 시도해 주세요.';

  @override
  String get sideDrawerRandomQQ => '랜덤 QQ';

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
  String get chatInputBarOnlineSearchTooltip => '온라인 검색';

  @override
  String get chatInputBarReasoningStrengthTooltip => '추론 강도';

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
  String get chatInputBarVoiceStopTooltip => '중지하고 텍스트로 변환';

  @override
  String get chatInputBarVoiceSendTooltip => '텍스트로 변환 후 전송';

  @override
  String get chatInputBarVoiceTranscribing => '인식 중…';

  @override
  String get chatInputBarVoiceAttachAudioTooltip => '중지하고 오디오로 첨부';

  @override
  String get chatInputBarVoiceSendAudioTooltip => '녹음 전송';

  @override
  String get chatInputBarVoiceSavingAudio => '오디오 저장 중…';

  @override
  String get audioClipPlayTooltip => '오디오 재생';

  @override
  String get audioClipPauseTooltip => '일시정지';

  @override
  String get audioClipPlaybackFailed => '이 오디오를 재생할 수 없습니다';

  @override
  String get chatInputBarImageProcessing => '이미지 처리 중';

  @override
  String get chatInputBarImageMode => '이미지 모드';

  @override
  String get chatInputBarDisableImageModeTooltip => '이미지 모드 끄기';

  @override
  String get chatInputBarQueuedPending => '전송 대기 중';

  @override
  String get chatInputBarQueuedCancel => '대기 취소';

  @override
  String get chatInputBarInsertNewline => '줄바꿈';

  @override
  String get chatInputBarExpand => '펼치기';

  @override
  String get chatInputBarCollapse => '접기';

  @override
  String get contextUsageTitle => '컨텍스트 창';

  @override
  String get contextUsageStateExact => '정확함(마지막 응답 기준)';

  @override
  String get contextUsageStateExactCalibrated => '총량은 정확하며, 항목별 내역은 비율로 추정됩니다';

  @override
  String get contextUsageStateEstimated => '추정';

  @override
  String get contextUsageStateStale => '오래됨, 업데이트 중…';

  @override
  String get contextUsageStateComputing => '계산 중…';

  @override
  String get contextUsageStateFailed => '사용량을 계산하지 못했습니다. 다시 시도하세요.';

  @override
  String get contextUsageStateFailedWithPrevious =>
      '새로 고치지 못했습니다. 이전 결과를 표시 중이며 오래된 정보일 수 있습니다.';

  @override
  String get contextUsageUnavailable => '지금은 사용량을 표시할 수 없습니다.';

  @override
  String contextUsagePartialSummary(String tokens) {
    return '$tokens 추정, 서버 측 사용량은 알 수 없음';
  }

  @override
  String get contextUsageBucketNativeCompaction => '서버 측 압축';

  @override
  String get contextUsageUnknownTokens => '알 수 없음';

  @override
  String contextUsageLastRequestInput(String tokens) {
    return '마지막으로 실제 모델에 전송된 양: $tokens';
  }

  @override
  String get contextUsageStateNone => '아직 데이터 없음';

  @override
  String get contextUsageBucketSystem => '시스템 프롬프트';

  @override
  String get contextUsageBucketInjections => '지시 주입';

  @override
  String get contextUsageBucketHistory => '메시지';

  @override
  String get contextUsageBucketTools => '내장 도구';

  @override
  String get contextUsageBucketMemory => '메모리';

  @override
  String get contextUsageBucketWorldBook => '세계관 책';

  @override
  String get contextUsageBucketSkills => '스킬';

  @override
  String get contextUsageBucketWorkspace => '작업 공간';

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
    return '$used / $window ($percent%)';
  }

  @override
  String get contextUsageNoWindow => '아직 컨텍스트 한도가 설정되지 않았습니다.';

  @override
  String get contextUsageSetWindow => '컨텍스트 창 설정';

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
  String get mcpPageStatusDisconnected => '연결 안 됨';

  @override
  String get mcpPageStatusAuthorizationRequired => '인증 필요';

  @override
  String get mcpPageStatusAuthorizing => '인증 중…';

  @override
  String get mcpPageStatusDisabled => '사용 안 함';

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
  String get mcpPageConfirmDeleteContent => '실행 취소로 복구할 수 있습니다. 삭제하시겠습니까?';

  @override
  String get mcpPageServerDeleted => '서버가 삭제되었습니다';

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
  String get mcpConversationSheetClearAll => '모두 해제';

  @override
  String get mcpConversationSheetNoRunning => '실행 중인 MCP 서버가 없습니다';

  @override
  String get mcpConversationSheetConnected => '연결됨';

  @override
  String mcpConversationSheetToolsCount(int enabled, int total) {
    return '도구: $enabled/$total';
  }

  @override
  String get mcpServerEditSheetEnabledLabel => '사용';

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
  String get mcpServerEditSheetRemoveHeaderTooltip => '삭제';

  @override
  String get mcpServerEditSheetAddHeader => '헤더 추가';

  @override
  String get mcpServerEditSheetTitleEdit => 'MCP 편집';

  @override
  String get mcpServerEditSheetTitleAdd => 'MCP 추가';

  @override
  String get mcpServerEditSheetSyncToolsTooltip => '도구 동기화';

  @override
  String get mcpServerEditSheetTabBasic => '기본 설정';

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
  String get defaultModelPageTitleModelTitle => '제목 요약 모델';

  @override
  String get defaultModelPageTitleModelSubtitle =>
      '대화 제목을 요약하는 데 사용되며, 기본적으로 현재 채팅 모델을 따르거나 다른 모델을 지정할 수 있습니다.';

  @override
  String get titleModelThinkingTitle => '사고 활성화';

  @override
  String get defaultModelPageSummaryModelTitle => '요약 모델';

  @override
  String get defaultModelPageSummaryModelSubtitle =>
      '대화 요약을 생성하는 데 사용되며, 빠르고 저렴한 모델을 권장합니다';

  @override
  String get defaultModelPageSuggestionModelTitle => '채팅 제안 모델';

  @override
  String get defaultModelPageSuggestionModelSubtitle =>
      '어시스턴트 응답 후 채팅 제안을 생성하는 데 사용되며, 현재 채팅 모델을 따르거나 다른 모델을 지정할 수 있습니다. 기본적으로 비활성화되어 있습니다.';

  @override
  String get assistantEditRecentChatsSummaryFrequencyTitle => '요약 갱신 빈도';

  @override
  String get assistantEditRecentChatsSummaryFrequencyDescription =>
      '선택한 개수만큼 새 메시지가 누적되면 최근 채팅 요약이 갱신됩니다.';

  @override
  String assistantEditRecentChatsSummaryFrequencyOption(int count) {
    return '$count개마다';
  }

  @override
  String get assistantEditRecentChatsSummaryFrequencyCustomButton => '사용자 지정';

  @override
  String get assistantEditRecentChatsSummaryFrequencyCustomTitle =>
      '사용자 지정 요약 빈도';

  @override
  String get assistantEditRecentChatsSummaryFrequencyCustomDescription =>
      '최근 채팅 요약을 갱신하기 전에 누적할 새 메시지 수를 입력하세요.';

  @override
  String get assistantEditRecentChatsSummaryFrequencyCustomLabel => '새 메시지 수';

  @override
  String get assistantEditRecentChatsSummaryFrequencyCustomHint =>
      '0보다 큰 숫자를 입력하세요';

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
  String get defaultModelPageOcrModelSubtitle => '이미지에서 텍스트와 설명을 추출하는 데 사용됩니다';

  @override
  String get defaultModelPageOcrModelRequiresImageInput =>
      'OCR에 사용할 이미지 입력 지원 모델을 선택하세요';

  @override
  String get defaultModelPagePromptLabel => '프롬프트';

  @override
  String get defaultModelPageTitlePromptHint => '제목 요약용 프롬프트 템플릿을 입력하세요';

  @override
  String get defaultModelPageSummaryPromptHint => '요약 생성용 프롬프트 템플릿을 입력하세요';

  @override
  String get defaultModelPageSuggestionPromptHint =>
      '채팅 제안 생성용 프롬프트 템플릿을 입력하세요';

  @override
  String get defaultModelPageTranslatePromptHint => '번역용 프롬프트 템플릿을 입력하세요';

  @override
  String get defaultModelPageOcrPromptHint => 'OCR 이미지 이해용 프롬프트 템플릿을 입력하세요';

  @override
  String get defaultModelPageResetDefault => '기본값으로 재설정';

  @override
  String get defaultModelPageDisable => '비활성화';

  @override
  String get defaultModelPageSave => '저장';

  @override
  String defaultModelPageTitleVars(String contentVar, String localeVar) {
    return '변수: 대화 내용: $contentVar, 언어: $localeVar';
  }

  @override
  String defaultModelPageSummaryVars(
    String previousSummaryVar,
    String userMessagesVar,
  ) {
    return '변수: 이전 요약: $previousSummaryVar, 새 메시지: $userMessagesVar';
  }

  @override
  String defaultModelPageSuggestionVars(String contentVar, String localeVar) {
    return '변수: 대화 내용: $contentVar, 언어: $localeVar';
  }

  @override
  String get defaultModelPageCompressModelTitle => '압축 모델';

  @override
  String get defaultModelPageCompressModelSubtitle =>
      '긴 대화를 요약하는 데 사용하는 모델입니다. 보통 빠른 모델이면 충분합니다.';

  @override
  String get defaultModelPageCompressPromptHint => '압축 시 사용할 프롬프트를 입력하세요';

  @override
  String defaultModelPageCompressVars(String contentVar, String localeVar) {
    return '변수: 대화 내용 $contentVar, 언어 $localeVar';
  }

  @override
  String defaultModelPageTranslateVars(String sourceVar, String targetVar) {
    return '변수: 원본 텍스트: $sourceVar, 대상 언어: $targetVar';
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
  String get translatePageInputHint => '번역할 내용을 입력하세요…';

  @override
  String get translatePageOutputHint => '번역 결과가 여기에 표시됩니다…';

  @override
  String get modelDetailSheetAddModel => '모델 추가';

  @override
  String get modelDetailSheetEditModel => '모델 편집';

  @override
  String get modelDetailSheetBasicTab => '기본 설정';

  @override
  String get modelDetailSheetAdvancedTab => '고급';

  @override
  String get modelDetailSheetBuiltinToolsTab => '내장 도구';

  @override
  String get modelDetailSheetModelIdLabel => '모델 ID';

  @override
  String get modelDetailSheetModelIdHint => '필수, 소문자/숫자/하이픈 권장';

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
  String get modelFetchInvertTooltip => '반전';

  @override
  String get modelDetailSheetSaveFailedMessage => '저장에 실패했습니다. 다시 시도해 주세요.';

  @override
  String get modelDetailSheetAddBody => '본문 추가';

  @override
  String get modelDetailSheetBuiltinToolsDescription =>
      '내장 도구는 공급자와 API 모드에 따라 달라집니다.';

  @override
  String get modelDetailSheetUrlContextTool => 'URL 컨텍스트';

  @override
  String get modelDetailSheetUrlContextToolDescription => 'URL 콘텐츠 처리를 활성화합니다';

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
  String get modelDetailSheetWebFetchTool => '웹 가져오기';

  @override
  String get modelDetailSheetOpenrouterWebFetchToolDescription =>
      'OpenRouter 웹 가져오기 서버 도구를 활성화합니다';

  @override
  String get modelDetailSheetClaudeWebFetchToolDescription =>
      'Claude가 대화의 URL에서 웹 페이지와 PDF를 가져오도록 허용합니다';

  @override
  String get modelDetailSheetClaudeCodeExecutionToolDescription =>
      'Claude가 Anthropic 샌드박스에서 Python과 Bash를 실행하도록 허용합니다';

  @override
  String get modelDetailSheetOpenrouterShellTool => 'Shell';

  @override
  String get modelDetailSheetOpenrouterShellToolDescription =>
      '호스팅된 격리 샌드박스에서 Shell 명령을 실행합니다';

  @override
  String get modelDetailSheetOpenaiCodeInterpreterTool => '코드 인터프리터';

  @override
  String get modelDetailSheetOpenaiCodeInterpreterToolDescription =>
      '코드 인터프리터 도구를 활성화합니다(컨테이너 자동, 메모리 제한 4g)';

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
  String get modelDetailSheetInvalidIdError => '유효한 모델 ID를 입력하세요(2자 이상)';

  @override
  String get modelDetailSheetHeaderKeyHint => '헤더 키';

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
  String get modelSpecFormSourceInferred => '추론됨';

  @override
  String get modelSpecFormSourceDefault => '기본값';

  @override
  String get modelSpecFormReset => '기본값으로 재설정';

  @override
  String get modelSpecFormModalitiesSection => '모달리티 및 기능';

  @override
  String get modelSpecFormImageType => '이미지';

  @override
  String get modelSpecFormAudioMode => '오디오';

  @override
  String get modelSpecFormVideoMode => '비디오';

  @override
  String get modelSpecFormPdfMode => 'PDF';

  @override
  String get modelSpecFormStructuredOutputAbility => '구조화된 출력';

  @override
  String get modelSpecFormReasoningSection => '추론';

  @override
  String get modelSpecFormDialect => '방언';

  @override
  String get modelSpecFormDialectNone => '없음';

  @override
  String get modelSpecFormDialectNoneSubtitle => '추론 필드를 쓰지 않음';

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
      '적응형 사고, 끄면 between_tools 사용';

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
  String get modelSpecFormDialectCustomSubtitle => '레벨별 JSON 패치';

  @override
  String get modelSpecFormLevels => '지원되는 레벨';

  @override
  String get modelSpecFormCanDisable => '비활성화 허용';

  @override
  String get modelSpecFormDefaultLevel => '기본 레벨';

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
      '동적 필터링이 켜져 있으면 2026-03-18 웹 검색 및 가져오기 도구를 사용합니다';

  @override
  String get modelSpecFormRemoteImageUrls => '원격 이미지 링크';

  @override
  String get modelSpecFormRemoteImageUrlsSubtitle =>
      'http(s) 이미지 링크를 그대로 전송합니다. 끄면 원격 링크는 제외되고 로컬 이미지만 전송됩니다';

  @override
  String get modelSpecFormPromptCacheControl => '프롬프트 캐시 마커';

  @override
  String get modelSpecFormPromptCacheControlSubtitle =>
      '프롬프트 캐싱이 켜져 있으면 OpenRouter 요청에 cache_control을 추가합니다';

  @override
  String get modelSpecFormSamplingAlways => '항상';

  @override
  String get modelSpecFormSamplingAlwaysSubtitle =>
      'temperature 등 샘플링 필드를 유지합니다';

  @override
  String get modelSpecFormSamplingOnlyWhenReasoningOff => '추론이 꺼져 있을 때만';

  @override
  String get modelSpecFormSamplingOnlyWhenReasoningOffSubtitle =>
      '모델이 사고하는 동안 샘플링 필드를 제거합니다';

  @override
  String get modelSpecFormSamplingNever => '안 함';

  @override
  String get modelSpecFormSamplingNeverSubtitle => '항상 샘플링 필드를 제거합니다';

  @override
  String get modelSpecFormReplay => '추론 재전송';

  @override
  String get modelSpecFormReplayNone => '없음';

  @override
  String get modelSpecFormReplayNoneSubtitle => '이전 추론을 모델에 다시 보내지 않습니다';

  @override
  String get modelSpecFormReplayToolTurns => '도구 호출 턴';

  @override
  String get modelSpecFormReplayToolTurnsSubtitle => '도구 호출 턴에서만 추론을 재전송합니다';

  @override
  String get modelSpecFormReplayAll => '전체';

  @override
  String get modelSpecFormReplayAllSubtitle => '모든 후속 턴에서 추론을 재전송합니다';

  @override
  String get modelSpecFormReplayField => '재전송 필드';

  @override
  String get modelSpecFormReplayFieldReasoningContent => 'reasoning_content';

  @override
  String get modelSpecFormReplayFieldReasoning => 'reasoning';

  @override
  String get modelSpecFormReplayFieldReasoningDetails => 'reasoning_details';

  @override
  String get modelSpecFormLimitsSection => '한도';

  @override
  String get modelSpecFormLimitsPricingSection => '한도 및 가격';

  @override
  String get modelSpecFormContextWindow => '컨텍스트 창';

  @override
  String get modelSpecFormMaxOutput => '최대 출력';

  @override
  String get modelSpecFormPricingSection => '가격 / 1M';

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
  String get modelSelectSheetSearchHint => '모델 또는 공급자 검색';

  @override
  String get modelSelectSheetFavoritesSection => '즐겨찾기';

  @override
  String get modelSelectSheetFollowAssistant => '어시스턴트 따르기';

  @override
  String get modelSelectSheetFavoriteTooltip => '즐겨찾기';

  @override
  String get modelSelectSheetChatType => '채팅';

  @override
  String get modelSelectSheetEmbeddingType => '임베딩';

  @override
  String get providerDetailPageShareTooltip => '공유';

  @override
  String get providerDetailPageDeleteProviderTooltip => '공급자 삭제';

  @override
  String get providerDetailPageDeleteProviderTitle => '공급자 삭제';

  @override
  String get providerDetailPageDeleteProviderContent =>
      '이 공급자를 삭제하시겠습니까? 이 작업은 되돌릴 수 없습니다.';

  @override
  String get providerDetailPageCancelButton => '취소';

  @override
  String get providerDetailPageDeleteButton => '삭제';

  @override
  String get providerDetailPageProviderDeletedSnackbar => '공급자가 삭제되었습니다';

  @override
  String get providerDetailPageConfigTab => '설정';

  @override
  String get providerDetailPageModelsTab => '모델';

  @override
  String get providerDetailPageCustomRequestTitle => '사용자 지정 요청';

  @override
  String get providerDetailPageCustomRequestDescription =>
      '이 공급자의 모든 모델에 적용됩니다. 모델 설정이 이 값을 우선하며, 이 값은 어시스턴트 설정을 우선합니다.';

  @override
  String get providerDetailPageNetworkTab => '네트워크';

  @override
  String get providerDetailPageEnabledTitle => '사용';

  @override
  String get providerDetailPageManageSectionTitle => '관리';

  @override
  String get providerDetailPageNameLabel => '이름';

  @override
  String get providerDetailPageApiKeyHint => '비워 두면 기본값 사용';

  @override
  String get providerDetailPageHideTooltip => '숨기기';

  @override
  String get providerDetailPageShowTooltip => '표시';

  @override
  String get providerDetailPageApiPathLabel => 'API 경로';

  @override
  String get providerDetailPageResponseApiTitle => 'Response API (/responses)';

  @override
  String get providerDetailPagePromptCacheKeyTitle => '대화 캐시 키 전송';

  @override
  String get providerDetailPagePromptCacheKeyHelp =>
      'OpenAI 호환 요청에 대화별로 안정적인 prompt_cache_key를 추가합니다. 공급자가 지원하는 경우에만 활성화하세요. 사용자 지정 Body 값이 우선하며, 캐시 적중은 보장되지 않습니다.';

  @override
  String get providerDetailPageAihubmixAppCodeLabel => 'APP-Code (10% 할인)';

  @override
  String get providerDetailPageAihubmixAppCodeHelp =>
      '요청에 APP-Code 헤더를 추가하여 10% 할인을 받습니다. AIhubmix에만 적용됩니다.';

  @override
  String get providerDetailPageClaudePromptCachingTitle => 'Claude 프롬프트 캐싱';

  @override
  String get providerDetailPageClaudePromptCachingHelp =>
      'Anthropic 또는 OpenRouter를 통한 Claude 요청에 cache_control을 추가합니다.';

  @override
  String get providerDetailPageClaudePromptCachingTtlTitle => '캐시 TTL';

  @override
  String get providerDetailPageClaudePromptCachingTtlHelp =>
      '기본값은 5분입니다. 1시간은 쓰기 비용이 더 높지만 긴 대화에서 캐시 재생성을 줄일 수 있습니다.';

  @override
  String get providerDetailPageClaudePromptCachingTtl5m => '5분';

  @override
  String get providerDetailPageClaudePromptCachingTtl1h => '1시간';

  @override
  String get providerDetailPageBalanceTitle => '계정 잔액';

  @override
  String get providerDetailPageBalanceInfo => '계정 잔액 가져오기';

  @override
  String get providerDetailPageBalanceApiPathLabel => '잔액 API 경로 또는 URL';

  @override
  String get providerDetailPageBalanceMethodLabel => 'HTTP 메서드';

  @override
  String providerDetailPageBalanceRequestHint(String apiKeyPlaceholder) {
    return '이 설정은 잔액 조회에만 적용됩니다. 헤더나 본문에서 $apiKeyPlaceholder를 사용하면 현재 API 키가 삽입됩니다. 인증은 기본적으로 Bearer를 사용하며, 헤더 값을 비우면 해당 헤더가 제거됩니다.';
  }

  @override
  String get providerDetailPageBalanceBodyLabel => '요청 본문 (선택 사항)';

  @override
  String get providerDetailPageBalanceBodyHint =>
      'POST로만 전송됩니다. 비워 두면 본문을 보내지 않습니다. Content-Type은 기본적으로 application/json이며, 다른 형식을 사용하려면 헤더를 추가하세요.';

  @override
  String get providerDetailPageBalanceResultPathLabel => '결과 JSON 경로';

  @override
  String get providerDetailPageBalanceQueryButton => '잔액 확인';

  @override
  String get providerDetailPageBalanceQuerying => '확인 중...';

  @override
  String get providerDetailPageBalanceResetDefaultsButton => '초기화';

  @override
  String get providerDetailPageBalanceResetDefaultsTooltip => '잔액 설정 초기화';

  @override
  String providerDetailPageBalanceResult(String value) {
    return '잔액: $value';
  }

  @override
  String providerDetailPageBalanceError(String message) {
    return '잔액 조회 실패: $message';
  }

  @override
  String get providerDetailPageVertexAiTitle => 'Vertex AI';

  @override
  String get providerDetailPageLocationLabel => '위치';

  @override
  String get providerDetailPageProjectIdLabel => '프로젝트 ID';

  @override
  String get providerDetailPageServiceAccountJsonLabel =>
      '서비스 계정 JSON (붙여넣기 또는 가져오기)';

  @override
  String get providerDetailPageImportJsonButton => 'JSON 가져오기';

  @override
  String get providerDetailPageImportJsonReadFailedMessage => '파일을 읽지 못했습니다';

  @override
  String get providerDetailPageTestButton => '테스트';

  @override
  String get providerDetailPageSaveButton => '저장';

  @override
  String get providerDetailPageProviderRemovedMessage => '공급자가 제거되었습니다';

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
      '삭제 후 실행 취소로 복구할 수 있습니다. 삭제하시겠습니까?';

  @override
  String get providerDetailPageModelDeletedSnackbar => '모델이 삭제되었습니다';

  @override
  String get providerDetailPageUndoButton => '실행 취소';

  @override
  String get providerDetailPageAddNewModelButton => '모델 추가';

  @override
  String get providerDetailPageFetchModelsButton => '가져오기';

  @override
  String get providerDetailPageEnableProxyTitle => '프록시 사용';

  @override
  String get providerDetailPageHostLabel => '호스트';

  @override
  String get providerDetailPagePortLabel => '포트';

  @override
  String get providerDetailPageUsernameOptionalLabel => '사용자 이름 (선택 사항)';

  @override
  String get providerDetailPagePasswordOptionalLabel => '비밀번호 (선택 사항)';

  @override
  String get providerDetailPageSavedSnackbar => '저장되었습니다';

  @override
  String get providerDetailPageEmbeddingsGroupTitle => '임베딩';

  @override
  String get providerDetailPageOtherModelsGroupTitle => '기타';

  @override
  String get providerDetailPageRemoveGroupTooltip => '그룹 제거';

  @override
  String get providerDetailPageAddGroupTooltip => '그룹 추가';

  @override
  String get providerDetailPageFilterHint => '모델 이름을 입력하여 필터링';

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
  String get providersPageTitle => '공급자';

  @override
  String get providersPageImportTooltip => '가져오기';

  @override
  String get providersPageAddTooltip => '추가';

  @override
  String get providersPageSearchHint => '공급자 또는 그룹 검색';

  @override
  String get providersPageProviderAddedSnackbar => '공급자가 추가되었습니다';

  @override
  String get modelCatalogTitle => '모델 카탈로그';

  @override
  String modelCatalogSourceBundled(String date) {
    return '내장 스냅샷 · $date';
  }

  @override
  String modelCatalogSourceRemote(String date) {
    return 'models.dev · $date 업데이트';
  }

  @override
  String get modelCatalogAutoUpdate => '24시간마다 자동 업데이트';

  @override
  String get modelCatalogRefresh => '지금 업데이트';

  @override
  String get modelCatalogUpdated => '모델 카탈로그가 업데이트되었습니다';

  @override
  String modelCatalogRefreshFailed(String error) {
    return '업데이트 실패: $error';
  }

  @override
  String modelCatalogProviderCount(int count) {
    return '공급자 $count개';
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
  String get providerGroupsOtherUngroupedOption => '기타 (그룹 없음)';

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
  String get providerGroupsDeleteConfirmTitle => '그룹을 삭제할까요?';

  @override
  String get providerGroupsDeleteConfirmContent => '이 그룹의 공급자는 “기타”로 이동됩니다.';

  @override
  String get providerGroupsDeleteConfirmCancel => '취소';

  @override
  String get providerGroupsDeleteConfirmOk => '삭제';

  @override
  String get providerGroupsDeletedToast => '그룹이 삭제되었습니다';

  @override
  String get providerGroupsEmptyState => '아직 그룹이 없습니다.';

  @override
  String get providerGroupsExpandToMoveToast => '먼저 그룹을 펼쳐 주세요.';

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
  String get addProviderSheetTitle => '공급자 추가';

  @override
  String get addProviderSheetEnabledLabel => '사용';

  @override
  String get addProviderSheetNameLabel => '이름';

  @override
  String get addProviderSheetApiPathLabel => 'API 경로';

  @override
  String get addProviderSheetVertexAiLocationLabel => '위치';

  @override
  String get addProviderSheetVertexAiProjectIdLabel => '프로젝트 ID';

  @override
  String get addProviderSheetVertexAiServiceAccountJsonLabel =>
      '서비스 계정 JSON (붙여넣기 또는 가져오기)';

  @override
  String get addProviderSheetImportJsonButton => 'JSON 가져오기';

  @override
  String get addProviderSheetCancelButton => '취소';

  @override
  String get addProviderSheetAddButton => '추가';

  @override
  String get importProviderSheetTitle => '공급자 가져오기';

  @override
  String get importProviderSheetScanQrTooltip => 'QR 스캔';

  @override
  String get importProviderSheetFromGalleryTooltip => '갤러리에서';

  @override
  String importProviderSheetImportSuccessMessage(int count) {
    return '공급자 $count개를 가져왔습니다';
  }

  @override
  String importProviderSheetImportFailedMessage(String error) {
    return '가져오기 실패: $error';
  }

  @override
  String get importProviderSheetDescription =>
      '공유 문자열(여러 줄 지원) 또는 ChatBox JSON을 붙여넣으세요';

  @override
  String get importProviderSheetInputHint => 'ai-provider:v1:... 또는 JSON';

  @override
  String get importProviderSheetCancelButton => '취소';

  @override
  String get importProviderSheetImportButton => '가져오기';

  @override
  String get shareProviderSheetTitle => '공급자 공유';

  @override
  String get shareProviderSheetDescription => '복사하거나 QR 코드로 공유하세요.';

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
  String get providerDetailPageApiBaseUrlLabel => 'API Base URL';

  @override
  String get providerDetailPageModelsTitle => '모델';

  @override
  String get providerModelsGetButton => '가져오기';

  @override
  String get providerDetailPageCapsVision => '비전';

  @override
  String get providerDetailPageCapsImage => '이미지';

  @override
  String get providerDetailPageCapsTool => '도구';

  @override
  String get providerDetailPageCapsReasoning => '추론';

  @override
  String get qrScanPageTitle => 'QR 스캔';

  @override
  String get qrScanPageInstruction => 'QR 코드를 프레임 안에 맞춰 주세요';

  @override
  String get searchServicesPageBackTooltip => '뒤로';

  @override
  String get searchServicesPageTitle => '서비스 검색';

  @override
  String get searchServicesPageDone => '완료';

  @override
  String get searchServicesPageEdit => '편집';

  @override
  String get searchServicesPageAddProvider => '공급자 추가';

  @override
  String get searchServicesPageSearchProviders => '공급자 검색';

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
    return '현재 $name';
  }

  @override
  String get searchServicesPageWebFetchLocal => '로컬';

  @override
  String get searchServicesPageWebFetchLocalSubtitle =>
      '무료. 이 기기에서 직접 페이지를 요청합니다.';

  @override
  String get searchServicesPageWebFetchProviderSubtitle =>
      '이 서비스의 API Key와 할당량을 사용합니다';

  @override
  String get searchServicesPageWebFetchOff => '끔';

  @override
  String get searchServicesPageWebFetchOffSubtitle => '검색만 하고 페이지는 읽지 않음';

  @override
  String get searchServicesPageWebFetchFooter =>
      '웹 검색을 켜면 모델이 페이지 전체 내용도 읽을 수 있습니다. 검색 서비스가 페이지를 읽을 수 없을 때는 로컬 읽기를 사용하며, 로컬 읽기는 JavaScript가 필요한 페이지나 봇 차단이 있는 페이지를 처리할 수 없습니다.\n\n여기서 설정한 페이지 리더를 사용하는 경우, 도구 중복을 피하려면 설정 → MCP에서 내장 @kelivo/fetch를 비활성화하세요. 여기서 설정한 페이지 리더는 계속 정상 작동합니다.';

  @override
  String get searchServicesPageWebFetchSupported => '웹 페이지 읽기 지원';

  @override
  String get searchServicesPageMaxResults => '최대 결과 수';

  @override
  String get searchServicesPageTimeoutSeconds => '시간 제한(초)';

  @override
  String get searchServicesPageAtLeastOneServiceRequired =>
      '검색 서비스가 최소 하나 필요합니다';

  @override
  String get searchServicesPageTestingStatus => '테스트 중…';

  @override
  String get searchServicesPageConnectedStatus => '연결됨';

  @override
  String get searchServicesPageFailedStatus => '실패';

  @override
  String get searchServicesPageNotTestedStatus => '테스트 안 함';

  @override
  String get searchServicesPageEditServiceTooltip => '서비스 편집';

  @override
  String get searchServicesPageTestConnectionTooltip => '연결 테스트';

  @override
  String get searchServicesPageDeleteServiceTooltip => '서비스 삭제';

  @override
  String get searchServicesPageConfiguredStatus => '설정됨';

  @override
  String get miniMapTitle => '미니맵';

  @override
  String get miniMapTooltip => '미니맵';

  @override
  String get miniMapScrollToBottomTooltip => '맨 아래로 스크롤';

  @override
  String miniMapSearchMatchCount(int count) {
    return '$count';
  }

  @override
  String get miniMapSearchNoResults => '일치하는 메시지 없음';

  @override
  String get searchServicesPageApiKeyRequiredStatus => 'API Key 필요';

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
  String get searchServicesAddDialogApiKeyRequired => 'API Key는 필수입니다';

  @override
  String get searchServicesFieldCustomUrlOptional => '사용자 지정 URL(선택 사항)';

  @override
  String get searchServicesDialogApiKey => 'API Key';

  @override
  String get searchServicesDialogApiKeyOptional => 'API Key(선택 사항)';

  @override
  String get searchServicesDialogModel => '모델';

  @override
  String get searchServicesDialogSystemPrompt => '시스템 프롬프트';

  @override
  String get searchServicesAddDialogInstanceUrl => '인스턴스 URL';

  @override
  String get searchServicesAddDialogUrlRequired => 'URL은 필수입니다';

  @override
  String get searchServicesAddDialogEnginesOptional => '엔진(선택 사항)';

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
  String get searchServicesEditDialogApiKeyRequired => 'API Key는 필수입니다';

  @override
  String get searchServicesEditDialogInstanceUrl => '인스턴스 URL';

  @override
  String get searchServicesEditDialogUrlRequired => 'URL은 필수입니다';

  @override
  String get searchServicesEditDialogEnginesOptional => '엔진(선택 사항)';

  @override
  String get searchServicesEditDialogLanguageOptional => '언어(선택 사항)';

  @override
  String get searchServicesEditDialogUsernameOptional => '사용자 이름(선택 사항)';

  @override
  String get searchServicesEditDialogPasswordOptional => '비밀번호(선택 사항)';

  @override
  String get searchServicesEditDialogRegionOptional => '지역(선택 사항, 기본값: us-en)';

  @override
  String get searchServiceEditorProviderTypeTitle => '검색 공급자';

  @override
  String get searchServiceEditorConfigurationTitle => '구성';

  @override
  String get searchServiceEditorNoConfiguration => '이 공급자는 추가 구성이 필요하지 않습니다.';

  @override
  String get searchServiceEditorMultiKeyTitle => '다중 Key 순환';

  @override
  String get searchServiceEditorMultiKeyNone => '구성되지 않음';

  @override
  String get searchApiKeysPageDescription =>
      '목록의 Key는 순서대로 순환 사용되며, 첫 번째가 기본 Key입니다. 공급자 속도 제한을 피하기 위해 사용량은 조회하지 않습니다.';

  @override
  String get searchApiKeysPagePrimaryBadge => '기본';

  @override
  String get searchApiKeysPageBatchHint =>
      '여러 Key를 한 번에 붙여넣을 수 있습니다. 한 줄에 하나씩 또는 쉼표로 구분하세요';

  @override
  String searchApiKeysPageBatchResult(String added, String skipped) {
    return '$added개 추가됨, 중복 $skipped개 건너뜀';
  }

  @override
  String get searchApiKeysPageAdd => '추가';

  @override
  String get searchApiKeysPageEmpty => '아직 구성된 Key가 없습니다.';

  @override
  String searchServiceEditorMultiKeyCount(String count) {
    return 'Key $count개';
  }

  @override
  String get searchServiceEditorUsageTitle => '계정 사용량';

  @override
  String get searchServiceEditorUsageNotQueried => '아직 사용량을 조회하지 않았습니다.';

  @override
  String get searchServiceEditorUsageQuery => '사용량 조회';

  @override
  String get searchServiceEditorUsageQuerying => '조회 중…';

  @override
  String searchServiceEditorUsageRemaining(String remaining) {
    return '남은 크레딧 $remaining개';
  }

  @override
  String searchServiceEditorUsageBalance(String balance) {
    return '잔액: $balance';
  }

  @override
  String searchServiceEditorUsageUsed(String used, String limit) {
    return '크레딧 $used / $limit 사용됨';
  }

  @override
  String searchServiceEditorUsageFailed(String message) {
    return '사용량을 조회할 수 없습니다: $message';
  }

  @override
  String get searchServiceEditorTestTitle => '검색 테스트';

  @override
  String get searchServiceEditorTestQueryHint => '검색어 입력';

  @override
  String get searchServiceEditorTestRun => '테스트 검색 실행';

  @override
  String get searchServiceEditorTestRunning => '검색 중…';

  @override
  String get searchServiceEditorTestNoResults => '공급자가 결과를 반환하지 않았습니다.';

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
  String get searchServiceEditorTestFetchRun => '테스트 가져오기 실행';

  @override
  String get searchServiceEditorTestFetchRunning => '읽는 중…';

  @override
  String searchServiceEditorTestFetchFailed(String message) {
    return '가져오기 실패: $message';
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
  String get searchServiceEditorDeleteTitle => '검색 서비스를 삭제할까요?';

  @override
  String searchServiceEditorDeleteMessage(String provider) {
    return '$provider을(를) 삭제할까요? 이 작업은 되돌릴 수 없습니다.';
  }

  @override
  String get searchServiceEditorDeleteConfirm => '삭제';

  @override
  String get searchServiceEditorDiscardTitle => '변경 사항을 버릴까요?';

  @override
  String get searchServiceEditorDiscardMessage => '저장하지 않은 검색 서비스 설정이 사라집니다.';

  @override
  String get searchServiceEditorKeepEditing => '계속 편집';

  @override
  String get searchServiceEditorDiscard => '버리기';

  @override
  String get searchSettingsSheetTitle => '검색 설정';

  @override
  String get searchSettingsSheetBuiltinSearchTitle => '모델 내장 검색';

  @override
  String get searchSettingsSheetBuiltinSearchDescription => '모델의 내장 검색 기능 사용';

  @override
  String get searchSettingsSheetClaudeDynamicSearchTitle => '동적 필터링';

  @override
  String get searchSettingsSheetClaudeDynamicSearchDescription =>
      '결과를 필터링하여 토큰 절약';

  @override
  String get searchSettingsSheetWebSearchTitle => '웹 검색';

  @override
  String get searchSettingsSheetWebSearchDescription => '채팅에서 웹 검색 사용';

  @override
  String get searchSettingsSheetOpenSearchServicesTooltip => '검색 서비스 열기';

  @override
  String get searchSettingsSheetNoServicesMessage =>
      '사용 가능한 서비스가 없습니다. \"검색 서비스\"에서 추가하세요.';

  @override
  String get aboutPageEasterEggMessage => '둘러봐 주셔서 감사합니다! \n (아직 이스터에그는 없어요)';

  @override
  String get aboutPageEasterEggButton => '좋아요!';

  @override
  String get aboutPageKelivoSearchUnlocked => '이름 없는 문이 살짝 열렸습니다. 설정에서 찾아보세요.';

  @override
  String get aboutPageKelivoSearchAlreadyUnlocked => '이미 이 문을 열어본 적이 있습니다.';

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
    return '기타 ($os)';
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
  String get aboutPageQQGroupOne => 'Kelivo 1그룹';

  @override
  String get aboutPageQQGroupTwo => 'Kelivo 2그룹';

  @override
  String get aboutPageQQGroupThree => 'Kelivo 3그룹';

  @override
  String get aboutPageJoinDiscord => 'Discord에서 참여하기';

  @override
  String get displaySettingsPageShowUserAvatarTitle => '사용자 아바타 표시';

  @override
  String get displaySettingsPageShowUserAvatarSubtitle => '채팅 메시지에 사용자 아바타 표시';

  @override
  String get displaySettingsPageShowUserNameTimestampTitle =>
      '사용자 이름 및 타임스탬프 표시';

  @override
  String get displaySettingsPageShowUserNameTimestampSubtitle =>
      '채팅 메시지에 사용자 이름과 그 아래 타임스탬프 표시';

  @override
  String get displaySettingsPageShowUserNameTitle => '사용자 이름 표시';

  @override
  String get displaySettingsPageShowUserTimestampTitle => '사용자 타임스탬프 표시';

  @override
  String get displaySettingsPageShowUserMessageActionsTitle => '사용자 메시지 작업 표시';

  @override
  String get displaySettingsPageShowUserMessageActionsSubtitle =>
      '내 메시지 아래에 복사, 재전송, 더보기 버튼 표시';

  @override
  String get displaySettingsPageShowModelNameTimestampTitle =>
      '모델 이름 및 타임스탬프 표시';

  @override
  String get displaySettingsPageShowModelNameTimestampSubtitle =>
      '채팅 메시지에 모델 이름과 그 아래 타임스탬프 표시';

  @override
  String get displaySettingsPageShowModelNameTitle => '모델 이름 표시';

  @override
  String get displaySettingsPageShowModelTimestampTitle => '모델 타임스탬프 표시';

  @override
  String get displaySettingsPageShowProviderInChatMessageTitle =>
      '모델 이름 뒤에 공급자 표시';

  @override
  String get displaySettingsPageShowProviderInChatMessageSubtitle =>
      '채팅 메시지에서 모델 ID 뒤에 공급자 이름 표시 (예: 모델 | 공급자)';

  @override
  String get displaySettingsPageChatModelIconTitle => '채팅 모델 아이콘';

  @override
  String get displaySettingsPageChatModelIconSubtitle => '채팅 메시지에 모델 아이콘 표시';

  @override
  String get displaySettingsPageShowTokenStatsTitle => '토큰 및 컨텍스트 통계 표시';

  @override
  String get displaySettingsPageShowTotalTokensTitle => '전체 턴의 토큰 표시';

  @override
  String get displaySettingsPageShowTotalTokensSubtitle =>
      '답변의 모든 API 요청 사용량을 합산합니다. 끄면 마지막 요청만 표시됩니다. 통계에는 항상 모든 요청이 포함됩니다.';

  @override
  String get displaySettingsPageShowTokenStatsSubtitle => '토큰 사용량과 메시지 수 표시';

  @override
  String get displaySettingsPageShowThinkingCardsTitle => '사고 카드 표시';

  @override
  String get displaySettingsPageShowThinkingCardsSubtitle =>
      '끄면 채팅에서 사고 과정 카드가 숨겨집니다.';

  @override
  String get displaySettingsPageShowToolCardsTitle => '도구 카드 표시';

  @override
  String get displaySettingsPageShowToolCardsSubtitle =>
      '끄면 채팅에서 도구 사용 카드가 숨겨집니다.';

  @override
  String get displaySettingsShowReasoningLevelBadge => '버튼에 추론 수준 표시';

  @override
  String get displaySettingsShowReasoningLevelBadgeSubtitle =>
      '입력창의 추론 아이콘 옆에 현재 수준 표시';

  @override
  String get displaySettingsPageAutoCollapseThinkingTitle => '사고 자동 접기';

  @override
  String get displaySettingsPageAutoCollapseThinkingSubtitle =>
      '완료 후 추론을 접어 인터페이스를 깔끔하게 유지';

  @override
  String get displaySettingsPageCollapseThinkingStepsTitle => '사고 단계 접기';

  @override
  String get displaySettingsPageCollapseThinkingStepsSubtitle =>
      '기본적으로 최신 단계만 표시하고 펼치면 전체 표시';

  @override
  String get displaySettingsPageShowToolResultSummaryTitle => '도구 결과 요약 표시';

  @override
  String get displaySettingsPageInsertSuggestionOnlyTitle => '보내지 않고 제안만 입력';

  @override
  String get displaySettingsPageShowToolResultSummarySubtitle =>
      '도구 단계 아래에 요약 텍스트 표시';

  @override
  String get displaySettingsPageHideToolResultImagesTitle => '도구 결과의 이미지 숨기기';

  @override
  String get displaySettingsPageRegenerateDeleteTrailingMessagesTitle =>
      '재생성 시 아래 메시지 삭제';

  @override
  String get displaySettingsPageShowRegenerateConfirmDialogTitle => '재생성 전 확인';

  @override
  String get displaySettingsPageForkKeepMessageVersionsTitle =>
      '분기 시 메시지 버전 유지';

  @override
  String get displaySettingsPageEditAssistantKeepThinkingToolCardsTitle =>
      '어시스턴트 편집 시 사고 및 도구 카드 유지';

  @override
  String get displaySettingsPageEditAssistantKeepThinkingToolCardsSubtitle =>
      '끄면 편집된 버전에는 어시스턴트 본문만 유지됩니다. 이전 버전으로 전환하면 이전 사고 및 도구 카드를 계속 볼 수 있습니다.';

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
      '대화 목록에 날짜 그룹 라벨 표시';

  @override
  String get displaySettingsPageEnableImageCropperTitle => '이미지 자르기 활성화';

  @override
  String get displaySettingsPageEnableImageCropperSubtitle =>
      '갤러리 또는 카메라에서 이미지 선택 후 자르기 허용';

  @override
  String get displaySettingsPageKeepSidebarOpenOnAssistantTapTitle =>
      '어시스턴트 선택 시 사이드바 유지';

  @override
  String get displaySettingsPageKeepSidebarOpenOnTopicTapTitle =>
      '토픽 선택 시 사이드바 유지';

  @override
  String get displaySettingsPageKeepAssistantListExpandedOnSidebarCloseTitle =>
      '사이드바 닫을 때 어시스턴트 목록 접지 않기';

  @override
  String get displaySettingsPageShowUpdatesTitle => '업데이트 표시';

  @override
  String get displaySettingsPageShowUpdatesSubtitle => '앱 업데이트 알림 표시';

  @override
  String get displaySettingsPageKeepScreenOnDuringGenerationTitle =>
      '생성 중 화면 켜짐 유지';

  @override
  String get displaySettingsPageKeepScreenOnDuringGenerationSubtitle =>
      '생성 중 화면 잠금으로 인한 중단을 방지합니다. 배터리 사용량이 증가합니다.';

  @override
  String get displaySettingsPageMessageNavButtonsTitle => '메시지 탐색 버튼';

  @override
  String get displaySettingsPageMessageNavButtonsSubtitle =>
      '빠른 이동 버튼이 표시되는 시점 선택';

  @override
  String get displaySettingsPageMessageNavButtonsModeAlways => '항상 표시';

  @override
  String get displaySettingsPageMessageNavButtonsModeScroll => '스크롤 중 표시';

  @override
  String get displaySettingsPageMessageNavButtonsModeHover => '마우스 오버 시 표시';

  @override
  String get displaySettingsPageMessageNavButtonsModeScrollAndHover =>
      '스크롤 또는 마우스 오버 시 표시';

  @override
  String get displaySettingsPageMessageNavButtonsModeNever => '표시 안 함';

  @override
  String get displaySettingsPageUseNewAssistantAvatarUxTitle =>
      '채팅 제목 표시줄에 어시스턴트 아바타 표시';

  @override
  String get displaySettingsPageHapticsOnSidebarTitle => '사이드바 햅틱';

  @override
  String get displaySettingsPageHapticsOnSidebarSubtitle =>
      '사이드바 열기/닫기 시 햅틱 피드백 활성화';

  @override
  String get displaySettingsPageHapticsGlobalTitle => '전역 햅틱';

  @override
  String get displaySettingsPageHapticsIosSwitchTitle => '스위치 햅틱';

  @override
  String get displaySettingsPageHapticsOnListItemTapTitle => '목록 항목 햅틱';

  @override
  String get displaySettingsPageHapticsOnCardTapTitle => '카드 햅틱';

  @override
  String get displaySettingsPageHapticsOnGenerateTitle => '생성 시 햅틱';

  @override
  String get displaySettingsPageHapticsOnGenerateSubtitle => '생성 중 햅틱 피드백 활성화';

  @override
  String get displaySettingsPageNewChatAfterDeleteTitle => '주제 삭제 후 새 대화';

  @override
  String get displaySettingsPageNewChatOnAssistantSwitchTitle =>
      '어시스턴트 전환 시 새 대화';

  @override
  String get displaySettingsPageNewChatOnLaunchTitle => '실행 시 새 대화';

  @override
  String get displaySettingsPageEnterToSendTitle => 'Enter 키로 전송';

  @override
  String get displaySettingsPageLongPasteAsFileTitle => '긴 텍스트를 파일로 붙여넣기';

  @override
  String get displaySettingsPageLongPasteAsFileThresholdTitle => '변환 임계값';

  @override
  String get displaySettingsPageLongPasteAsFileThresholdUnit => '자';

  @override
  String get displaySettingsPageSendShortcutTitle => '전송 단축키';

  @override
  String get displaySettingsPageSendShortcutEnter => 'Enter';

  @override
  String get displaySettingsPageSendShortcutCtrlEnter => 'Ctrl/Cmd + Enter';

  @override
  String get displaySettingsPageAutoSwitchTopicsTitle => '주제로 자동 전환';

  @override
  String get desktopDisplaySettingsTopicPositionTitle => '주제 위치';

  @override
  String get desktopDisplaySettingsTopicPositionLeft => '왼쪽';

  @override
  String get desktopDisplaySettingsTopicPositionRight => '오른쪽';

  @override
  String get displaySettingsPageNewChatOnLaunchSubtitle => '실행 시 자동으로 새 대화 생성';

  @override
  String get displaySettingsPageChatFontSizeTitle => '채팅 글꼴 크기';

  @override
  String get displaySettingsPageAutoScrollEnableTitle => '하단 자동 따라가기';

  @override
  String get displaySettingsPageAutoScrollDisabledLabel => '끔';

  @override
  String get displaySettingsPageChatFontSampleText => '이것은 채팅 텍스트 예시입니다';

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
      '창 버튼도 함께 숨겨집니다. 창 이동, 크기 조정, 닫기는 창 관리자를 사용하세요.';

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
  String get desktopFontFilterHint => '글꼴 필터링...';

  @override
  String get displaySettingsPageAppFontTitle => '앱 글꼴';

  @override
  String get displaySettingsPageCodeFontTitle => '코드 글꼴';

  @override
  String get fontPickerChooseLocalFile => '로컬 파일 선택';

  @override
  String get desktopFontLoading => '글꼴 불러오는 중...';

  @override
  String get displaySettingsPageFontLocalFileLabel => '로컬 파일';

  @override
  String get displaySettingsPageFontResetLabel => '글꼴 설정 초기화';

  @override
  String get displaySettingsPageOtherSettingsTitle => '기타 설정';

  @override
  String get themeSettingsPageDynamicColorSection => '동적 색상';

  @override
  String get themeSettingsPageUseDynamicColorTitle => '시스템 동적 색상';

  @override
  String get themeSettingsPageUseDynamicColorSubtitle =>
      '시스템 팔레트 따르기 (Android 12+)';

  @override
  String get themeSettingsPageUsePureBackgroundTitle => '단색 배경';

  @override
  String get themeSettingsPageUsePureBackgroundSubtitle =>
      '말풍선과 강조 색상만 테마를 따릅니다.';

  @override
  String get themeAdvancedSettingsPageTitle => '테마 고급 설정';

  @override
  String get themeAdvancedSettingsPageUseLayeredSurfacesTitle => '계층형 표면 (실험적)';

  @override
  String get themeAdvancedSettingsPageUseLayeredSurfacesSubtitle =>
      '페이지는 더 어둡게, 카드는 더 밝게; 둘 다 테마 색상을 유지합니다. 끄면 이전 모양으로 돌아갑니다.';

  @override
  String get themeAdvancedSettingsPageUseLayeredSheetTilesTitle => '계층형 시트 타일';

  @override
  String get themeAdvancedSettingsPageUseLayeredSheetTilesSubtitle =>
      '기본적으로 타일은 시트 배경과 같은 색상입니다.';

  @override
  String get themeSettingsPageColorPalettesSection => '색상 팔레트';

  @override
  String get themeSettingsPageCustomPaletteName => '사용자 지정';

  @override
  String get themeSettingsPageCustomColorReset => '초기화';

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
  String get customThemePrimaryColor => '기본';

  @override
  String get customThemeSecondaryColor => '보조';

  @override
  String get customThemeTertiaryColor => '3차';

  @override
  String get customThemeColorAuto => '자동';

  @override
  String get customThemeSave => '저장';

  @override
  String get customThemeCancel => '취소';

  @override
  String get customThemeDelete => '삭제';

  @override
  String get customThemeDeleteConfirm => '이 테마를 삭제할까요?';

  @override
  String get customThemeCopied => '테마 JSON이 클립보드에 복사되었습니다';

  @override
  String get customThemeCopyAction => '복사';

  @override
  String get customThemeImportHint => '여기에 테마 JSON을 붙여넣으세요';

  @override
  String get customThemeImportInvalid => '잘못된 테마 JSON';

  @override
  String get customThemeHexLabel => '16진수';

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
      '온디바이스, 시스템 또는 클라우드 서비스로 음성을 텍스트로 변환합니다.';

  @override
  String get asrServicesAddTooltip => '음성 인식 서비스 추가';

  @override
  String get asrServicesEmptyTitle => '음성 인식 서비스 없음';

  @override
  String get asrServicesEmptySubtitle => '하나 추가하면 채팅 입력창에 마이크가 표시됩니다.';

  @override
  String get asrServicesOnDeviceGroup => '기기 내';

  @override
  String get asrServicesCloudGroup => '클라우드';

  @override
  String get asrServicesSystemTitle => '시스템';

  @override
  String get asrServicesSystemSubtitle => '기기에 내장된 인식기 사용';

  @override
  String get asrServicesLocalTitle => '오프라인 모델';

  @override
  String get asrServicesLocalSubtitle => '다운로드 후 이 기기에서 오프라인으로 실행';

  @override
  String get asrServicesOpenAiTitle => 'OpenAI Realtime';

  @override
  String get asrServicesOpenAiSubtitle => '저지연 스트리밍 전사';

  @override
  String get asrServicesGroqSubtitle => 'Whisper 분할 클라우드 전사';

  @override
  String get asrServicesMistralSubtitle => 'Voxtral 분할 클라우드 전사';

  @override
  String get asrServicesElevenLabsSubtitle => 'Scribe 분할 클라우드 전사';

  @override
  String get asrServicesDashScopeTitle => 'DashScope';

  @override
  String get asrServicesDashScopeSubtitle => 'Qwen 실시간 전사';

  @override
  String get asrServicesVolcengineTitle => 'Volcengine';

  @override
  String get asrServicesVolcengineSubtitle => 'Doubao 스트리밍 전사';

  @override
  String get asrServicesMimoTitle => 'MiMo';

  @override
  String get asrServicesMimoSubtitle => '분할 클라우드 전사';

  @override
  String get asrServicesStepTitle => 'Step';

  @override
  String get asrServicesStepSubtitle => 'Step Audio 분할 클라우드 전사';

  @override
  String get asrServicesAddTitle => '음성 인식 추가';

  @override
  String get asrServicesEditTitle => '음성 인식 편집';

  @override
  String get asrServicesSelectedLabel => '선택됨';

  @override
  String get asrServicesUnavailableLabel => '사용 불가';

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
  String get asrServicesApiKeyLabel => 'API Key';

  @override
  String get asrServicesEndpointLabel => '엔드포인트';

  @override
  String get asrServicesRecognitionModeLabel => '인식 방식';

  @override
  String get asrServicesRealtimeMode => '실시간';

  @override
  String get asrServicesRecordedMode => '녹음 오디오';

  @override
  String get asrServicesQwenAudioSubtitle => '실시간 또는 녹음 오디오 전사';

  @override
  String get asrServicesQwenTokenPlanHint =>
      'Token Plan을 사용하는 경우 녹음 오디오를 선택하고 Workspace ID에 token-plan을 입력한 뒤 키에 해당하는 리전을 선택하세요.';

  @override
  String get asrServicesWorkspaceIdHint => '예: token-plan';

  @override
  String get asrServicesEndpointOverrideLabel => '사용자 지정 엔드포인트(선택 사항)';

  @override
  String get asrServicesWorkspaceIdInvalid => 'URL이 아닌 Workspace ID를 입력하세요.';

  @override
  String get asrServicesWebSocketEndpointInvalid =>
      '사용자 이름, 비밀번호 또는 URL 조각이 없는 완전한 ws:// 또는 wss:// 엔드포인트를 입력하세요.';

  @override
  String get asrServicesHttpEndpointInvalid =>
      '사용자 이름, 비밀번호 또는 URL 조각이 없는 완전한 http:// 또는 https:// 엔드포인트를 입력하세요.';

  @override
  String get asrServicesModelLabel => '모델';

  @override
  String get asrServicesResourceIdLabel => '리소스 ID';

  @override
  String get asrServicesLanguageLabel => '언어';

  @override
  String get asrServicesAutomaticLabel => '자동';

  @override
  String get asrServicesApiKeyRequired => '이 서비스를 사용하려면 API Key를 입력하세요.';

  @override
  String get asrServicesChooseModelTitle => '모델';

  @override
  String get asrServicesModelDownloadAction => '다운로드';

  @override
  String get asrServicesModelUseAction => '이 모델 사용';

  @override
  String get asrServicesModelDeleteAction => '다운로드 삭제';

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
  String get asrServicesMicrophonePermissionDenied => '마이크 권한이 부여되지 않았습니다.';

  @override
  String get asrServicesNoSpeechDetected => '음성이 감지되지 않았습니다.';

  @override
  String asrServicesRecognitionFailed(String error) {
    return '음성 인식 실패: $error';
  }

  @override
  String get ttsServicesPageAddNotImplemented => 'TTS 서비스 추가가 아직 구현되지 않았습니다';

  @override
  String get ttsServicesPageSystemTtsTitle => '시스템 TTS';

  @override
  String get ttsServicesPageSystemTtsAvailableSubtitle => '시스템 내장 TTS 사용';

  @override
  String ttsServicesPageSystemTtsUnavailableSubtitle(String error) {
    return '사용 불가: $error';
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
  String get ttsServicesDialogProviderType => '공급자';

  @override
  String get ttsServicesDialogCancelButton => '취소';

  @override
  String get ttsServicesDialogAddButton => '추가';

  @override
  String get ttsServicesDialogSaveButton => '저장';

  @override
  String get ttsServicesFieldNameLabel => '이름';

  @override
  String get ttsServicesFieldApiKeyLabel => 'API Key';

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
  String get ttsServicesFieldWorkspaceIdLabel => '작업 공간 ID';

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
  String get ttsServicesFieldPitchLabel => '피치';

  @override
  String get ttsServicesFieldLanguageBoostLabel => '언어 부스트';

  @override
  String get ttsServicesFieldBitrateLabel => '비트레이트';

  @override
  String get ttsServicesFieldChannelLabel => '채널 수';

  @override
  String get ttsServicesFieldSubtitlesLabel => '자막 생성';

  @override
  String get ttsServicesFieldPronunciationDictionaryLabel =>
      '발음 사전 (한 줄에 항목 하나)';

  @override
  String get ttsServicesFieldInstructionLabel => '스타일 / 음성 설명';

  @override
  String get ttsServicesFieldStreamingLabel => '스트리밍';

  @override
  String get ttsServicesFieldOptimizeTextPreviewLabel => '텍스트 미리보기 최적화';

  @override
  String get ttsServicesFieldReferenceAudioLabel => '참조 오디오 (WAV/MP3 데이터 URI)';

  @override
  String get ttsServicesFieldChooseReferenceAudioButton => '참조 오디오 선택';

  @override
  String get ttsServicesFieldTemperatureLabel => '온도';

  @override
  String get ttsServicesFieldTopPLabel => 'Top P';

  @override
  String get ttsServicesFieldLatencyLabel => '지연 모드';

  @override
  String get ttsServicesEmotionAutoLabel => '자동 매칭';

  @override
  String get ttsServicesValidationApiKeyRequired => 'API Key는 필수입니다';

  @override
  String get ttsServicesValidationReferenceIdRequired => '음성/참조 ID는 필수입니다';

  @override
  String get ttsServicesValidationInstructionRequired => '음성 설명은 필수입니다';

  @override
  String ttsServicesValidationSampleRate(String format, String rates) {
    return '$format 형식은 $rates Hz가 필요합니다.';
  }

  @override
  String get ttsServicesViewDetailsButton => '상세 보기';

  @override
  String get ttsServicesDialogErrorTitle => '오류 상세';

  @override
  String get ttsServicesCloseButton => '닫기';

  @override
  String get ttsSettingsPageTitle => 'TTS 설정';

  @override
  String get ttsSettingsPlaybackSection => '재생';

  @override
  String get ttsSettingsAutoPlayTitle => '어시스턴트 답변 자동 재생';

  @override
  String get ttsSettingsAutoPlayDescription =>
      '어시스턴트 답변이 완료되면 자동으로 TTS 재생을 시작합니다.';

  @override
  String get ttsSettingsCacheReplayTitle => '재생 시 오디오 재사용';

  @override
  String get ttsSettingsCacheReplayDescription =>
      '생성된 네트워크 오디오를 다시 요청하지 않고 재생합니다.';

  @override
  String get ttsSettingsTextSelectionSection => '텍스트 선택';

  @override
  String get ttsSettingsTextSelectionFallbackDescription =>
      '일치하는 텍스트가 없으면 전체 답변을 재생합니다.';

  @override
  String get ttsSettingsTextSelectionFullTextTitle => '전체 텍스트';

  @override
  String get ttsSettingsTextSelectionFullTextDescription =>
      '어시스턴트 답변 전체를 재생합니다.';

  @override
  String get ttsSettingsTextSelectionQuotedOnlyTitle => '따옴표 안의 텍스트만';

  @override
  String get ttsSettingsTextSelectionQuotedOnlyDescription =>
      '“”, ‘’, \"\", \'\', 「」 또는 『』 안의 텍스트를 재생합니다.';

  @override
  String get ttsSettingsTextSelectionOutsideParenthesesTitle => '괄호 밖 텍스트';

  @override
  String get ttsSettingsTextSelectionOutsideParenthesesDescription =>
      '() 및 （） 안의 텍스트를 건너뜁니다.';

  @override
  String get ttsSettingsTextSelectionItalicOnlyTitle => '기울임 텍스트만';

  @override
  String get ttsSettingsTextSelectionItalicOnlyDescription =>
      'Markdown 또는 HTML 기울임 텍스트를 재생합니다.';

  @override
  String get ttsSettingsTextSelectionNonItalicTitle => '기울임이 아닌 텍스트만';

  @override
  String get ttsSettingsTextSelectionNonItalicDescription =>
      'Markdown 또는 HTML 기울임 텍스트를 건너뜁니다.';

  @override
  String get ttsFloatingPlayerLabel => 'TTS 플레이어';

  @override
  String get ttsFloatingPauseTooltip => '일시정지';

  @override
  String get ttsFloatingResumeTooltip => '계속 재생';

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
    return '오디오 저장 실패: $message';
  }

  @override
  String imageViewerPageShareFailedOpenFile(String message) {
    return '공유할 수 없어 파일을 열려고 시도했습니다: $message';
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
  String get imageViewerPageResetZoomButton => '확대/축소 초기화';

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
    return '$total장 중 $index번째 이미지';
  }

  @override
  String get imageViewerPageImageLoadFailed => '이미지를 불러올 수 없습니다';

  @override
  String get imageViewerPageSaveSuccess => '갤러리에 저장되었습니다';

  @override
  String imageViewerPageSaveFailed(String error) {
    return '저장 실패: $error';
  }

  @override
  String get settingsShare => 'Kelivo - 오픈 소스 AI 어시스턴트';

  @override
  String get searchProviderBingLocalDescription =>
      '웹 스크래핑으로 Bing 검색 결과를 가져옵니다. API 키가 필요 없지만 불안정할 수 있습니다.';

  @override
  String get searchProviderDuckDuckGoDescription =>
      'DDGS 기반의 개인정보 보호 중심 DuckDuckGo 검색입니다. API 키가 필요 없으며 지역 설정을 지원합니다.';

  @override
  String get searchProviderBraveDescription =>
      'Brave의 독립 검색 엔진입니다. 추적이나 프로파일링 없이 개인정보를 보호합니다.';

  @override
  String get searchProviderExaDescription =>
      '의미론적 이해를 갖춘 신경 검색입니다. 연구 및 특정 콘텐츠 찾기에 적합합니다.';

  @override
  String get searchProviderExaMcpDescription =>
      'MCP를 통한 Exa 검색입니다. API 키는 선택 사항이며 제한된 무료 사용이 가능합니다.';

  @override
  String get searchProviderLinkUpDescription =>
      '출처가 있는 답변을 제공하는 검색 API입니다. 검색 결과와 AI 생성 요약을 모두 제공합니다.';

  @override
  String get searchProviderMetasoDescription =>
      '메타소의 중국어 검색입니다. AI 기능과 함께 중국어 콘텐츠에 최적화되어 있습니다.';

  @override
  String get searchProviderSearXNGDescription =>
      '개인정보를 존중하는 메타 검색 엔진입니다. 자체 호스팅 인스턴스가 필요하며 추적하지 않습니다.';

  @override
  String get searchProviderTavilyDescription =>
      'LLM에 최적화된 AI 검색 API입니다. 고품질의 관련성 높은 결과를 제공합니다.';

  @override
  String get searchProviderZhipuDescription =>
      '즈푸 AI의 중국어 AI 검색입니다. 중국어 콘텐츠와 쿼리에 최적화되어 있습니다.';

  @override
  String get searchProviderOllamaDescription =>
      'Ollama 웹 검색 API입니다. 최신 정보로 모델을 보강합니다.';

  @override
  String get searchProviderDeepSeekDescription =>
      'DeepSeek 공식 웹 검색 및 페이지 가져오기 API입니다. DeepSeek API 키를 사용합니다.';

  @override
  String get searchProviderJinaDescription =>
      '임베딩, 리랭커, 웹 리더, 딥서치, 소형 언어 모델을 갖춘 AI 검색 기반입니다. 다국어 및 멀티모달을 지원합니다.';

  @override
  String get searchServiceNameBingLocal => 'Bing (Local)';

  @override
  String get searchServiceNameDuckDuckGo => 'DuckDuckGo';

  @override
  String get searchServiceNameTavily => 'Tavily';

  @override
  String get searchServiceNameExa => 'Exa';

  @override
  String get searchServiceNameExaMcp => 'Exa MCP';

  @override
  String get searchServiceNameZhipu => '즈푸';

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
      'Perplexity 검색 API. 지역 및 도메인 필터를 지원하는 순위 기반 웹 결과를 제공합니다.';

  @override
  String get searchServiceNameBocha => 'Bocha';

  @override
  String get searchProviderBochaDescription =>
      'Bocha 웹 검색 API. 선택적 요약과 함께 정확한 웹 결과를 제공합니다.';

  @override
  String get searchServiceNameDoubao => 'Doubao';

  @override
  String get searchProviderDoubaoDescription =>
      'Volcano Engine의 Doubao 웹 검색 API.';

  @override
  String get searchServiceNameSerper => 'Serper';

  @override
  String get searchProviderSerperDescription =>
      'Serper Google 검색 API. 국가, 언어, 시간, 페이지 필터를 지원하는 빠른 웹 결과를 제공합니다.';

  @override
  String get searchServiceNameQuerit => 'Querit';

  @override
  String get searchProviderQueritDescription =>
      'LLM 애플리케이션을 위한 Querit 검색 API. 사이트, 시간, 국가, 언어 필터를 지원하는 실시간 웹 결과를 반환합니다.';

  @override
  String get searchServiceNameGrok => 'Grok';

  @override
  String get searchProviderGrokDescription =>
      'xAI Responses API를 통한 Grok 검색. 웹 및 X 검색 도구를 사용하며 인용된 출처를 반환합니다.';

  @override
  String get searchServiceNameStepFun => 'StepFun';

  @override
  String get searchProviderStepFunDescription =>
      'POST /v1/search를 통한 StepFun 웹 검색.';

  @override
  String get searchServiceNameFirecrawl => 'Firecrawl';

  @override
  String get searchProviderFirecrawlDescription =>
      'Firecrawl Search API v2. API 키는 선택 사항입니다. 여기서는 Scrape를 지원하지 않습니다.';

  @override
  String get searchServiceNameTinyFish => 'TinyFish';

  @override
  String get searchProviderTinyFishDescription =>
      '지역/언어 필터를 지원하는 TinyFish Search API. API 키가 필요합니다. 여기서는 Fetch/Scrape를 지원하지 않습니다.';

  @override
  String get searchServiceNameAnySearch => 'AnySearch';

  @override
  String get searchProviderAnySearchDescription =>
      '웹과 전문 데이터 소스 간 자동 라우팅을 제공하는 AI 에이전트용 통합 검색. API 키는 선택 사항입니다.';

  @override
  String get searchServiceNameKagi => 'Kagi';

  @override
  String get searchProviderKagiDescription =>
      'Kagi 검색 API. Kagi의 프리미엄 웹 검색 결과를 반환합니다.';

  @override
  String get searchServiceNameKimi => 'Kimi';

  @override
  String get searchProviderKimiDescription =>
      'Kimi 검색 API. Pro는 관련 웹 콘텐츠 발췌를 반환하고, Basic은 제목, 링크, 스니펫을 반환합니다.';

  @override
  String get searchServiceNameParallel => 'Parallel';

  @override
  String get searchProviderParallelDescription =>
      'Parallel 검색 API. turbo, fast, basic, advanced 모드를 지원하는 LLM 최적화 웹 발췌를 반환합니다.';

  @override
  String get searchServicesDialogSearchMode => '검색 모드';

  @override
  String get searchServiceNameYou => 'You.com';

  @override
  String get searchProviderYouDescription =>
      'You.com 검색 API. Highlights 또는 Snippets와 함께 웹 및 뉴스 결과를 반환합니다.';

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
      '최대 토큰 수는 1024에서 32768 사이여야 합니다.';

  @override
  String get searchServiceNameKelivo => 'Kelivo';

  @override
  String get searchServicesDialogCountryOptional => '국가/지역 (선택 사항)';

  @override
  String get searchServicesDialogLanguageOptional => '언어 (선택 사항)';

  @override
  String get searchServicesDialogTimeFilterOptional => '시간 필터 (선택 사항)';

  @override
  String get searchServicesDialogPageOptional => '페이지 (선택 사항)';

  @override
  String get searchServicesDialogPageInvalid => '페이지는 양의 정수여야 합니다.';

  @override
  String get searchServicesDialogSitesIncludeOptional => '포함할 사이트 (선택 사항)';

  @override
  String get searchServicesDialogSitesExcludeOptional => '제외할 사이트 (선택 사항)';

  @override
  String get searchServicesDialogTimeRangeOptional => '시간 범위 (선택 사항)';

  @override
  String get searchServicesDialogCountriesOptional => '국가 (선택 사항)';

  @override
  String get searchServicesDialogLanguagesOptional => '언어 (선택 사항)';

  @override
  String get searchServicesDialogSitesHint => 'example.com, docs.example.com';

  @override
  String get searchServicesDialogTimeRangeHint => 'd7';

  @override
  String get searchServicesDialogCountriesHint => 'united states, japan';

  @override
  String get searchServicesDialogLanguagesHint => 'english, japanese';

  @override
  String get generationInterrupted => '생성이 중단되었습니다';

  @override
  String get titleForLocale => '새 대화';

  @override
  String get temporaryChatTitle => '임시 대화';

  @override
  String get temporaryChatEmptyMessage => '임시 대화는 기록에 표시되지 않으며, 나가면 완전히 삭제됩니다.';

  @override
  String get temporaryChatToggleTooltip => '임시 대화 전환';

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
  String get instructionInjectionTitle => '지시 주입';

  @override
  String get instructionInjectionBackTooltip => '뒤로';

  @override
  String get instructionInjectionAddTooltip => '지시 추가';

  @override
  String get instructionInjectionImportTooltip => '파일에서 가져오기';

  @override
  String get instructionInjectionEmptyMessage => '아직 지시 주입 카드가 없습니다';

  @override
  String get instructionInjectionDefaultTitle => '학습 모드';

  @override
  String get instructionInjectionAddTitle => '지시 주입 추가';

  @override
  String get instructionInjectionEditTitle => '지시 주입 편집';

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
    return '$count개의 지시를 가져왔습니다';
  }

  @override
  String get instructionInjectionSheetSubtitle => '채팅 전에 적용할 프롬프트를 선택하세요';

  @override
  String get mcpJsonEditButtonTooltip => 'JSON 편집';

  @override
  String get mcpJsonEditTitle => 'JSON 편집';

  @override
  String get mcpJsonEditParseFailed => 'JSON 구문 분석 실패';

  @override
  String get mcpJsonEditSavedApplied => '저장 및 적용됨';

  @override
  String get mcpTimeoutSettingsTooltip => '도구 호출 시간 제한 설정';

  @override
  String get mcpTimeoutDialogTitle => '도구 호출 시간 제한';

  @override
  String get mcpTimeoutSecondsLabel => '도구 호출 시간 제한 (초)';

  @override
  String get mcpTimeoutInvalid => '양수 초를 입력하세요';

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
      '이 어시스턴트의 빠른 문구를 관리합니다. 아래 버튼을 클릭하여 문구를 추가하세요.';

  @override
  String get assistantEditManageQuickPhraseButton => '빠른 문구 관리';

  @override
  String get assistantEditPageMemoryTab => '메모리';

  @override
  String get assistantEditLocalToolTimeInfoTitle => '시간 정보';

  @override
  String get assistantEditLocalToolTimeInfoSubtitle =>
      '기기의 날짜, 요일, 시간, 시간대, UTC 오프셋 및 타임스탬프를 읽습니다.';

  @override
  String get assistantEditLocalToolClipboardTitle => '클립보드';

  @override
  String get assistantEditLocalToolClipboardSubtitle =>
      '명시적으로 필요할 때 기기 클립보드의 일반 텍스트를 읽거나 씁니다.';

  @override
  String get assistantEditLocalToolTextToSpeechTitle => '텍스트 음성 변환';

  @override
  String get assistantEditLocalToolTextToSpeechSubtitle =>
      '설정된 TTS 재생으로 어시스턴트가 텍스트를 소리 내어 읽도록 합니다.';

  @override
  String get assistantEditLocalToolAskUserTitle => '사용자에게 질문';

  @override
  String get assistantEditLocalToolAskUserSubtitle =>
      '어시스턴트가 짧은 질문을 하고 답변 후 계속 진행하도록 합니다.';

  @override
  String get assistantEditLocalToolCalculateTitle => '계산기';

  @override
  String get assistantEditLocalToolCalculateSubtitle =>
      '수학 표현식을 계산하며 + - * / 거듭제곱 sqrt sin cos 등을 지원합니다.';

  @override
  String get assistantEditLocalToolScreenTimeTitle => '스크린 타임';

  @override
  String get assistantEditLocalToolScreenTimeSubtitle =>
      '이 기기의 앱 화면 사용 시간을 조회하며, 사용 정보 접근 권한이 필요합니다.';

  @override
  String get chatMessageWidgetScreenTimeTotal => '총 스크린 타임';

  @override
  String get chatMessageWidgetScreenTimePermissionRequired =>
      '사용 정보 접근 권한이 부여되지 않았습니다. 시스템 설정에서 활성화한 후 다시 시도하세요.';

  @override
  String get assistantEditLocalToolCalendarQueryTitle => '캘린더 조회';

  @override
  String get assistantEditLocalToolCalendarQuerySubtitle =>
      '이 기기의 캘린더 일정을 읽으며, 캘린더 권한이 필요합니다.';

  @override
  String get assistantEditLocalToolCalendarCreateTitle => '일정 만들기';

  @override
  String get assistantEditLocalToolCalendarCreateSubtitle =>
      '확인 후 이 기기에 캘린더 일정을 만들며, 캘린더 권한이 필요합니다.';

  @override
  String get assistantEditLocalToolLocationTitle => '현재 위치';

  @override
  String get assistantEditLocalToolLocationSubtitle =>
      '이 기기에서 일회성 위치를 읽으며, 위치 권한이 필요합니다.';

  @override
  String get assistantEditLocalToolWeatherTitle => '날씨';

  @override
  String get assistantEditLocalToolWeatherSubtitle =>
      '현재 위치 또는 지정한 위치의 Apple 날씨를 가져옵니다. 결과에 WeatherKit 출처가 표시됩니다.';

  @override
  String get assistantEditLocalToolHealthTitle => '건강 요약';

  @override
  String get assistantEditLocalToolHealthSubtitle =>
      'Apple 건강에서 개인정보를 보호하는 활동 요약을 읽으며, 건강 접근 권한이 필요합니다.';

  @override
  String assistantEditLocalToolHealthSelectedCount(int selected, int total) {
    return '$selected/$total 선택됨';
  }

  @override
  String get healthDataSettingsTitle => '건강 데이터';

  @override
  String get healthDataSettingsDescription =>
      '현재 어시스턴트가 일상 대화에서 사용할 수 있는 HealthKit 신호입니다. 스위치는 Kelivo가 읽기를 시도할 수 있는 범위를 제어하며, 실제 접근 권한은 여전히 iOS가 관리합니다.';

  @override
  String healthDataSettingsBadge(int selected, int total) {
    return '$selected/$total 켜짐';
  }

  @override
  String get healthDataSettingsIosReadTitle => 'iOS 건강 읽기';

  @override
  String get healthDataSettingsIosReadSubtitle => '기기 사용 가능, 읽기 범위는 iOS가 관리';

  @override
  String get healthDataSettingsOpenSystemSettings => '시스템 설정 열기';

  @override
  String get healthDataSettingsEnableAll => '모두 켜기';

  @override
  String get healthDataSettingsDisableAll => '모두 끄기';

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
  String get healthDataSettingsTypeStepsSubtitle => '걷기 걸음 수 요약';

  @override
  String get healthDataSettingsTypeDaylightTitle => '햇빛';

  @override
  String get healthDataSettingsTypeDaylightSubtitle => '야외 일광 시간';

  @override
  String get healthDataSettingsTypeActiveEnergyTitle => '에너지';

  @override
  String get healthDataSettingsTypeActiveEnergySubtitle => '활동 에너지 소모';

  @override
  String get healthDataSettingsTypeExerciseMinutesTitle => '운동';

  @override
  String get healthDataSettingsTypeExerciseMinutesSubtitle => 'Apple 운동 분';

  @override
  String get healthDataSettingsTypeStandTimeTitle => '서기';

  @override
  String get healthDataSettingsTypeStandTimeSubtitle => '서 있는 시간';

  @override
  String get healthDataSettingsTypeDistanceTitle => '거리';

  @override
  String get healthDataSettingsTypeDistanceSubtitle => '걷기 및 달리기 거리';

  @override
  String get healthDataSettingsTypeWorkoutsTitle => '운동';

  @override
  String get healthDataSettingsTypeWorkoutsSubtitle =>
      '운동 기록: 유형, 시간, 거리 및 에너지';

  @override
  String get healthDataSettingsTypeSleepTitle => '수면';

  @override
  String get healthDataSettingsTypeSleepSubtitle =>
      '지난 24시간: 수면, 침대에 있던 시간, 깨어 있던 시간 및 수면 단계';

  @override
  String get healthDataSettingsTypeMindfulnessTitle => '휴식';

  @override
  String get healthDataSettingsTypeMindfulnessSubtitle => '마음챙김 또는 휴식 시간';

  @override
  String get healthDataSettingsTypeHeartRateTitle => '심박수';

  @override
  String get healthDataSettingsTypeHeartRateSubtitle => '최신 심박수 샘플';

  @override
  String get healthDataSettingsTypeRestingHeartRateTitle => '안정 심박수';

  @override
  String get healthDataSettingsTypeRestingHeartRateSubtitle => '안정 심박수 샘플';

  @override
  String get healthDataSettingsTypeBloodOxygenTitle => '혈중 산소';

  @override
  String get healthDataSettingsTypeBloodOxygenSubtitle => '혈중 산소 포화도';

  @override
  String get healthDataSettingsTypeDietaryEnergyTitle => '섭취 에너지';

  @override
  String get healthDataSettingsTypeDietaryEnergySubtitle => '식이 칼로리 기록';

  @override
  String get healthDataSettingsTypeWaterTitle => '수분';

  @override
  String get healthDataSettingsTypeWaterSubtitle => '수분 섭취 기록';

  @override
  String get healthDataSettingsTypeWeightTitle => '체중';

  @override
  String get healthDataSettingsTypeWeightSubtitle => '체중 샘플';

  @override
  String get healthDataSettingsTypeBmiTitle => 'BMI';

  @override
  String get healthDataSettingsTypeBmiSubtitle => '체질량 지수';

  @override
  String get healthDataSettingsTypeBloodGlucoseTitle => '혈당';

  @override
  String get healthDataSettingsTypeBloodGlucoseSubtitle => '혈당 샘플';

  @override
  String get assistantEditLocalToolRemindersQueryTitle => '알림 조회';

  @override
  String get assistantEditLocalToolRemindersQuerySubtitle =>
      '이 기기의 미리 알림을 읽습니다. 미리 알림 전체 접근 권한이 필요합니다.';

  @override
  String get assistantEditLocalToolRemindersCreateTitle => '미리 알림 생성';

  @override
  String get assistantEditLocalToolRemindersCreateSubtitle =>
      '확인 후 이 기기에 미리 알림을 생성합니다. 미리 알림 전체 접근 권한이 필요합니다.';

  @override
  String get assistantEditLocalToolRemindersCompleteTitle => '미리 알림 완료';

  @override
  String get assistantEditLocalToolRemindersCompleteSubtitle =>
      '확인 후 미리 알림을 완료로 표시합니다. 미리 알림 전체 접근 권한이 필요합니다.';

  @override
  String get assistantEditMemorySwitchDescription =>
      '어시스턴트가 대화 간에 기억을 생성하고 사용하도록 허용합니다.';

  @override
  String get assistantEditRecentChatsSwitchTitle => '최근 대화 참조';

  @override
  String get assistantEditRecentChatsSwitchDescription =>
      '컨텍스트에 도움이 되도록 최근 대화 제목을 포함합니다.';

  @override
  String get assistantEditAddMemoryButton => '기억 추가';

  @override
  String get assistantEditMemoryEmpty => '아직 기억이 없습니다';

  @override
  String get assistantEditMemoryDialogTitle => '기억';

  @override
  String get assistantEditMemoryDialogHint => '기억 내용을 입력하세요';

  @override
  String get assistantEditAddQuickPhraseButton => '빠른 문구 추가';

  @override
  String get multiKeyPageDeleteSnackbarDeletedOne => '키 1개를 삭제했습니다';

  @override
  String get multiKeyPageUndo => '실행 취소';

  @override
  String get multiKeyPageUndoRestored => '복원되었습니다';

  @override
  String get multiKeyPageDeleteErrorsTooltip => '오류 삭제';

  @override
  String get multiKeyPageDeleteErrorsConfirmTitle => '모든 오류 키를 삭제할까요?';

  @override
  String get multiKeyPageDeleteErrorsConfirmContent => '오류로 표시된 모든 키가 제거됩니다.';

  @override
  String multiKeyPageDeletedErrorsSnackbar(int n) {
    return '오류 키 $n개를 삭제했습니다';
  }

  @override
  String get providerDetailPageProviderTypeTitle => '공급자 유형';

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
  String get providersPageMultiSelectTooltip => '다중 선택';

  @override
  String get providersPageDeleteSelectedConfirmContent =>
      '선택한 공급자를 삭제하시겠습니까? 이 작업은 되돌릴 수 없습니다.';

  @override
  String get providersPageDeleteSelectedSnackbar => '선택한 공급자를 삭제했습니다';

  @override
  String providersPageExportSelectedTitle(int count) {
    return '공급자 $count개 내보내기';
  }

  @override
  String get providersPageExportCopyButton => '복사';

  @override
  String get providersPageExportShareButton => '공유';

  @override
  String get providersPageExportCopiedSnackbar => '내보내기 코드를 복사했습니다';

  @override
  String get providersPageDeleteAction => '삭제';

  @override
  String get providersPageExportAction => '내보내기';

  @override
  String get assistantEditPresetTitle => '프리셋 대화';

  @override
  String get assistantEditPresetAddUser => '사용자 프리셋 추가';

  @override
  String get assistantEditPresetAddAssistant => '어시스턴트 프리셋 추가';

  @override
  String get assistantEditPresetInputHintUser => '사용자 메시지를 입력하세요…';

  @override
  String get assistantEditPresetInputHintAssistant => '어시스턴트 메시지를 입력하세요…';

  @override
  String get assistantEditPresetEmpty => '아직 프리셋 메시지가 없습니다';

  @override
  String get assistantEditPresetEditDialogTitle => '프리셋 메시지 편집';

  @override
  String get assistantEditPresetRoleUser => '사용자';

  @override
  String get assistantEditPresetRoleAssistant => '어시스턴트';

  @override
  String get desktopTtsPleaseAddProvider => '먼저 TTS 공급자를 추가하세요';

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
  String get networkProxyBypassLabel => '프록시 우회';

  @override
  String get networkProxyBypassHint =>
      '쉼표로 구분된 호스트/CIDR, 예: localhost,127.0.0.1,192.168.0.0/16,*.local';

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
      '전역 프록시와 공급자 프록시가 모두 활성화된 경우 공급자 수준 프록시가 우선합니다.';

  @override
  String get settingsPageAutoRetry => '자동 재시도';

  @override
  String get autoRetryEnableLabel => '자동 재시도 활성화';

  @override
  String get autoRetryMaxRetries => '최대 재시도 횟수';

  @override
  String get autoRetryInitialDelay => '초기 지연 (ms)';

  @override
  String get autoRetryMultiplier => '백오프 배수';

  @override
  String get autoRetryMaxDelay => '최대 지연 (ms)';

  @override
  String get autoRetryJitter => '지터';

  @override
  String get autoRetryJitterSubtitle => '각 대기 시간을 ±20% 무작위화';

  @override
  String get autoRetryOnNetworkError => '네트워크 오류 시 재시도';

  @override
  String get autoRetryStatusCodes => '재시도 상태 코드';

  @override
  String get autoRetryKeywords => '재시도 키워드';

  @override
  String get autoRetryStopKeywords => '중지 키워드';

  @override
  String get autoRetryAddHint => '추가';

  @override
  String get autoRetryRestoreDefaults => '기본값 복원';

  @override
  String get autoRetryFooter =>
      '자동 재시도는 현재 모델 응답이 아직 아무 출력도 생성하지 않았을 때만 실행됩니다.';

  @override
  String autoRetryCountdown(int seconds, int attempt, int maxRetries) {
    return '$seconds초 후 재시도 ($attempt/$maxRetries)';
  }

  @override
  String get desktopShowProviderInModelCapsule => '모델 캡슐에 공급자 표시';

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
  String get providerDetailPageMultiSelectButton => '다중 선택';

  @override
  String get providerDetailPageBatchDetectButton => '감지';

  @override
  String get providerDetailPageBatchDetecting => '감지 중...';

  @override
  String get providerDetailPageBatchDetectStart => '감지 시작';

  @override
  String get providerDetailPageDetectSuccess => '감지 성공';

  @override
  String get providerDetailPageDetectFailed => '감지 실패';

  @override
  String get providerDetailPageDeleteSelectedModelsButton => '삭제';

  @override
  String get providerDetailPageDeleteSelectedModelsTooltip => '선택한 모델 삭제';

  @override
  String providerDetailPageDeleteSelectedModelsConfirm(int count) {
    return '선택한 모델 $count개를 삭제하시겠습니까? 이 작업은 되돌릴 수 없습니다.';
  }

  @override
  String get providerDetailPageDeleteFailedDetectedModelsButton => '사용 불가 삭제';

  @override
  String get providerDetailPageDeleteFailedDetectedModelsTooltip =>
      '감지에 실패한 모델 삭제';

  @override
  String providerDetailPageDeleteFailedDetectedModelsConfirm(int count) {
    return '감지에 실패한 모델 $count개를 삭제하시겠습니까? 이 작업은 되돌릴 수 없습니다.';
  }

  @override
  String providerDetailPageSelectedModelsDeletedSnackbar(int count) {
    return '모델 $count개를 삭제했습니다';
  }

  @override
  String get providerDetailPageDeleteAllModelsTooltip => '모든 모델 삭제';

  @override
  String get providerDetailPageDeleteAllModelsWarning => '이 작업은 되돌릴 수 없습니다.';

  @override
  String get requestLogSettingTitle => '요청 로깅';

  @override
  String get requestLogSettingSubtitle =>
      '활성화하면 요청/응답 세부 정보가 logs/logs.txt에 기록됩니다(매일 순환).';

  @override
  String get flutterLogSettingTitle => 'Flutter 로깅';

  @override
  String get flutterLogSettingSubtitle =>
      '활성화하면 Flutter 오류와 print 출력이 logs/flutter_logs.txt에 기록됩니다(매일 순환).';

  @override
  String get contextLogSettingTitle => '컨텍스트 로깅';

  @override
  String get contextLogSettingSubtitle =>
      '활성화하면 모델에 전송된 정확한 메시지가 logs/context_logs.txt에 기록됩니다(매일 순환).';

  @override
  String get contextLogViewerTitle => '컨텍스트';

  @override
  String contextLogSnapshotMessages(int count) {
    return '메시지 $count개';
  }

  @override
  String contextLogSnapshotTokens(int count) {
    return '토큰 $count개';
  }

  @override
  String get contextLogSourceSystemPrompt => '시스템 프롬프트';

  @override
  String get contextLogSourceMemoryRules => '메모리 규칙';

  @override
  String get contextLogSourceSearchPrompt => '검색 프롬프트';

  @override
  String get contextLogSourceInstructionInjection => '지시 주입';

  @override
  String get contextLogSourceWorldBook => '월드 북';

  @override
  String get contextLogSourceMemorySnapshot => '메모리 스냅샷';

  @override
  String get contextLogSourceChatHistory => '채팅 기록';

  @override
  String get contextLogSourceToolCall => '도구 호출';

  @override
  String get contextLogSourceToolResult => '도구 결과';

  @override
  String get contextLogTokensEstimateHint =>
      '토큰 수는 추정치일 뿐이며, 모델의 실제 사용량을 기준으로 삼으세요.';

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
  String get contextLogLoading => '불러오는 중...';

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
    return '요청 $count개';
  }

  @override
  String get logViewerFieldId => 'ID';

  @override
  String get logViewerFieldMethod => '메서드';

  @override
  String get logViewerFieldStatus => '상태';

  @override
  String get logViewerFieldStarted => '시작';

  @override
  String get logViewerFieldEnded => '종료';

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
      '모든 스트리밍 청크를 기록합니다(생성 속도가 느려질 수 있음). HTTP 오류 응답 본문은 항상 기록됩니다.';

  @override
  String get logSettingsElidePayloads => '대용량 페이로드 생략';

  @override
  String get logSettingsElidePayloadsSubtitle =>
      '인라인 base64 이미지와 파일을 자리 표시자로 대체합니다. 로그가 작아지고 뷰어가 빨라집니다.';

  @override
  String get logSettingsAutoDelete => '자동 삭제';

  @override
  String get logSettingsAutoDeleteSubtitle => '지정한 일수보다 오래된 로그 삭제';

  @override
  String get logSettingsAutoDeleteDisabled => '사용 안 함';

  @override
  String logSettingsAutoDeleteDays(int count) {
    return '$count일';
  }

  @override
  String get logSettingsMaxSize => '최대 로그 크기';

  @override
  String get logSettingsMaxSizeSubtitle => '초과하면 가장 오래된 로그부터 삭제';

  @override
  String get logSettingsMaxSizeUnlimited => '제한 없음';

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
  String get homePageProcessingFiles => '파일 처리 중...';

  @override
  String get settingsPageWorldBook => '세계관';

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
  String get memorySettingsModelUnset => '선택 안 됨';

  @override
  String get memorySettingsModelTip =>
      '자동 정리 메모리를 켜면 이 모델이 백그라운드에서 자주 호출됩니다. 저렴하고 빠른 모델을 선택하는 것이 좋습니다.';

  @override
  String get memorySettingsAboutTitle => '메모리 정보';

  @override
  String get memorySettingsAboutSubtitle => '메모리 작동 방식과 실행 시점';

  @override
  String get memoryAboutQuickstartTitle => '시작하기';

  @override
  String get memoryAboutQuickstartBody =>
      '1. 설정 → 메모리에서 처리 모델을 선택하세요.\n2. 어시스턴트의 메모리 탭에서 장기 메모리와 자동 정리를 켜세요.\n3. 몇 번 대화하거나 정리를 누른 뒤, 모든 메모리를 열어 저장된 내용을 확인하세요.';

  @override
  String get memoryAboutTypesTitle => '메모리 유형';

  @override
  String get memoryAboutTypesBody =>
      '정체성: 호칭, 직업, 언어, 장기 선호 등 사용자에 대한 안정적인 정보. 완전한 3인칭 문장으로 작성하세요.\n\n작업 흐름: 사용자가 일을 처리하는 방식을 선호하는 정도 — 도구, 형식, 검토 습관.\n\n말투: 어시스턴트가 어떻게 말하기를 원하는지 — 어조, 길이, 언어 스타일.\n\n지시: 어시스턴트가 지속적으로 따라야 할 규칙이며, 이 대화에서의 일회성 작업이 아닙니다.';

  @override
  String get memoryAboutScopeTitle => '전역 vs 어시스턴트';

  @override
  String get memoryAboutScopeBody =>
      '전역 메모리는 모든 어시스턴트에 주입됩니다. 어시스턴트 범위 메모리는 해당 어시스턴트에게만 표시됩니다. 모든 곳에서 사용자와 함께해야 하는 사실에는 전역을, 하나의 페르소나에 속하는 규칙이나 컨텍스트에는 어시스턴트 범위를 사용하세요.';

  @override
  String get memoryAboutInjectionTitle => '메모리 주입 방식';

  @override
  String get memoryAboutInjectionBody =>
      '대화 시작 시 각 유형의 최신 항목이 모델 컨텍스트에 배치됩니다. 유형이 주입 한도를 초과하면 해당 블록에 mode=\"summary\"와 total 및 shown 개수가 표시되며, 나머지는 memory_search_profile로 가져올 수 있습니다. 설정 → 메모리에서 한도를 높이면 더 완전해지지만 토큰 비용이 증가합니다. 각 어시스턴트의 메모리 설정에서 항상 전체 주입할 유형을 선택하세요.';

  @override
  String get memoryAboutPipelineTitle => '백그라운드 파이프라인';

  @override
  String get memoryAboutPipelineBody =>
      '자동 정리는 대화 후 실행됩니다: 기억할 가치가 있는지 판단 → 후보 추출 → 중복 제거 및 병합 → 필요 시 정체성 항목을 사용자 프로필로 정제. 어시스턴트의 메모리 탭에서 정리를 눌러도 됩니다. 그래서 처리 모델이 자주 호출됩니다.';

  @override
  String get memoryAboutCacheTitle => '캐시 상태 유지';

  @override
  String get memoryAboutCacheBody =>
      '주입되는 메모리 접두사는 변경되지 않은 대화가 프롬프트 캐시를 재사용할 수 있도록 안정적으로 유지되어 비용과 지연을 줄입니다. 의미 없는 대량 편집이나 재정렬은 피하세요. 일상적인 단일 항목 편집은 보통 영향이 제한적입니다.';

  @override
  String get memoryAboutFaqTitle => '자주 묻는 질문';

  @override
  String get memoryAboutFaqWhyNotRememberedTitle => '왜 기억하지 못했나요?';

  @override
  String get memoryAboutFaqWhyNotRememberedBody =>
      '정리할 새 메시지가 충분하지 않거나, 정리할 새 메시지가 없거나, 메모리 처리 모델이 선택되지 않은 경우 정리가 건너뛰어집니다. 임시 대화는 메모리에 저장되지 않습니다. 어시스턴트별로 메모리나 자동 정리를 끌 수도 있습니다.';

  @override
  String get memorySettingsThinkingTitle => '사고 활성화';

  @override
  String get memorySettingsThinkingSubtitle =>
      '모델이 지원하는 경우 메모리 모델이 추론을 사용하도록 허용';

  @override
  String get memorySettingsInjectionSection => '메모리 주입';

  @override
  String get memorySettingsInjectionMaxItemsTitle => '유형별 주입 항목 수';

  @override
  String get memorySettingsInjectionMaxItemsSubtitle =>
      '이 한도는 어시스턴트의 메모리 설정에서 전체 주입으로 선택되지 않은 유형에 적용됩니다. 유형이 이 한도를 초과하면 최신 항목만 주입됩니다. 나머지는 memory_search_profile로 가져올 수 있습니다. 숫자가 클수록 더 완전하지만 토큰을 더 사용합니다. 규칙 프롬프트를 사용자 지정한 경우 업데이트하거나 기본값으로 복원하세요.';

  @override
  String get assistantEditMemoryFullInjectionTypesTitle => '전체 주입 유형';

  @override
  String get assistantEditMemoryFullInjectionTypesNone => '선택 안 됨';

  @override
  String assistantEditMemoryFullInjectionTypesSelected(int count) {
    return '$count개 선택됨';
  }

  @override
  String get assistantEditMemoryFullInjectionTypesSubtitle =>
      '이 어시스턴트에만 적용됩니다. 항목 한도를 무시하고 활성 전역 및 어시스턴트 메모리를 모두 주입할 유형을 선택하세요. 컨텍스트와 토큰을 더 사용합니다.';

  @override
  String memorySettingsInjectionMaxItemsOption(int n) {
    return '$n';
  }

  @override
  String get memorySettingsInjectionMaxItemsCustomButton => '사용자 지정';

  @override
  String get memorySettingsInjectionMaxItemsCustomTitle => '사용자 지정 주입 수';

  @override
  String get memorySettingsInjectionMaxItemsCustomDescription =>
      '1에서 100 사이의 숫자를 입력하세요.';

  @override
  String get memorySettingsInjectionMaxItemsCustomLabel => '개수';

  @override
  String get memorySettingsInjectionMaxItemsCustomHint => '1–100';

  @override
  String get memorySettingsInjectionMaxItemsCustomInvalid =>
      '1에서 100 사이의 숫자를 입력하세요';

  @override
  String get memorySettingsPromptLangSection => '프롬프트 언어';

  @override
  String get memorySettingsPromptLangAuto => '자동';

  @override
  String get memorySettingsPromptLangAutoSubtitle =>
      'UI 언어 따르기 (중국어 → zh, 그 외 → en)';

  @override
  String get memorySettingsPromptLangZh => '중국어';

  @override
  String get memorySettingsPromptLangZhSubtitle => '항상 중국어 메모리 프롬프트와 도구 설명 사용';

  @override
  String get memorySettingsPromptLangEn => 'English';

  @override
  String get memorySettingsPromptLangEnSubtitle => '항상 영어 메모리 프롬프트와 도구 설명 사용';

  @override
  String get memorySettingsPromptsSection => '프롬프트 템플릿';

  @override
  String get memorySettingsLegacyPromptTitle => '레거시 메모리 규칙';

  @override
  String get memoryPromptEditRulesTitle => '메모리 규칙';

  @override
  String get memoryPromptEditRulesSubtitle => '메인 채팅 시스템 프롬프트에 주입됩니다';

  @override
  String get memoryPromptEditGateTitle => '게이트키퍼';

  @override
  String get memoryPromptEditGateSubtitle => '이번 턴이 기억할 가치가 있는지 판단합니다';

  @override
  String get memoryPromptEditExtractTitle => '추출';

  @override
  String get memoryPromptEditExtractSubtitle => '대화에서 후보 기억 항목을 추출합니다';

  @override
  String get memoryPromptEditSmartAddTitle => '스마트 추가';

  @override
  String get memoryPromptEditSmartAddSubtitle =>
      'NEW / MERGE / CONFLICT / SKIP 중복 판정';

  @override
  String get memoryPromptEditDistillTitle => '프로필 증류기';

  @override
  String get memoryPromptEditDistillSubtitle => '정체성 기억에서 프로필 필드를 증류합니다';

  @override
  String get memoryPromptEditMigrateTitle => '레거시 마이그레이션';

  @override
  String get memoryPromptEditMigrateSubtitle => '모델 정리 시 기억 원문을 재작성하는 데 사용됩니다';

  @override
  String get memoryPromptEditReset => '기본값으로 복원';

  @override
  String get memoryPromptEditSave => '저장';

  @override
  String get memoryPromptEditSectionPerItem => '항목별 프롬프트';

  @override
  String get memoryPromptEditSectionBatch => '일괄 프롬프트';

  @override
  String get memorySettingsEntriesSection => '모든 기억';

  @override
  String get memorySettingsLegacySection => '레거시 기억';

  @override
  String get memorySettingsEntriesTitle => '기억 목록';

  @override
  String get memorySettingsEntriesSubtitle => '기억을 탐색, 편집, 보관 및 삭제합니다';

  @override
  String get memorySettingsProfileTitle => '사용자 프로필';

  @override
  String get memorySettingsProfileSubtitle => '모델이 사용하는 구조화된 정체성 필드';

  @override
  String get memorySettingsLegacyTitle => '레거시 기억 (읽기 전용)';

  @override
  String get memorySettingsLegacySubtitle => '이전 버전의 기억';

  @override
  String get memoryEntryTypeIdentity => '정체성';

  @override
  String get memoryEntryTypeWorkflow => '워크플로';

  @override
  String get memoryEntryTypeVoice => '말투';

  @override
  String get memoryEntryTypeInstruction => '지시';

  @override
  String get memoryEntryScopeGlobal => '전역';

  @override
  String get memoryEntryScopeAssistant => '이 어시스턴트';

  @override
  String memoryEntryScopeAssistantNamed(String name) {
    return '$name';
  }

  @override
  String get memoryEntrySourceManual => '수동';

  @override
  String get memoryEntrySourceTool => '도구';

  @override
  String get memoryEntrySourceExtracted => '추출됨';

  @override
  String get memoryEntrySourceDistilled => '증류됨';

  @override
  String get memoryEntryStatusActive => '활성';

  @override
  String get memoryEntryStatusArchived => '보관됨';

  @override
  String memoryEntryUpdatedAt(String date) {
    return '$date에 업데이트됨';
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
  String get memoryEntryActionAdd => '기억 추가';

  @override
  String get memoryEntryDeleteConfirmTitle => '기억을 삭제할까요?';

  @override
  String get memoryEntryDeleteConfirmContent =>
      '이 기억이 영구적으로 삭제됩니다. 되돌릴 수 없습니다.';

  @override
  String memoryEntryBatchDeleteConfirmTitle(int count) {
    return '기억 $count개를 삭제할까요?';
  }

  @override
  String get memoryEntryBatchDeleteConfirmContent => '선택한 기억이 영구적으로 삭제됩니다.';

  @override
  String get memoryEntrySwitchScopeConfirmTitle => '기억 범위를 변경할까요?';

  @override
  String get memoryEntrySwitchScopeToGlobal =>
      '이 기억을 전역으로 설정할까요(모든 어시스턴트와 공유)?';

  @override
  String get memoryEntrySwitchScopeToAssistant => '이 기억을 현재 어시스턴트로 제한할까요?';

  @override
  String get memoryEntryArchivedSection => '보관됨';

  @override
  String get memoryEntryEmpty => '아직 기억이 없습니다';

  @override
  String get memoryEntryEmptyDisabled => '이 어시스턴트의 장기 기억이 꺼져 있습니다';

  @override
  String get memoryEntryEditTitle => '기억 편집';

  @override
  String get memoryEntryCreateTitle => '새 기억';

  @override
  String get memoryEntryContentHint => '기억 내용 입력';

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
  String get memorySearchHint => '기억 검색';

  @override
  String get memorySearchEmpty => '일치하는 기억이 없습니다';

  @override
  String memoryOrphanBanner(int count) {
    return '고아 어시스턴트 기억 $count개(어시스턴트 삭제됨)';
  }

  @override
  String get memoryOrphanCleanupButton => '정리';

  @override
  String get memoryOrphanConfirmTitle => '고아 기억을 정리할까요?';

  @override
  String memoryOrphanConfirmContent(int count) {
    return '어시스턴트가 더 이상 존재하지 않는 기억 $count개를 영구 삭제합니다.';
  }

  @override
  String get memoryOrganizeButton => '정리';

  @override
  String get memoryOrganizeNeedsConversation => '기억을 정리하려면 이 어시스턴트와의 대화를 여세요';

  @override
  String get memoryOrganizeNeedsModel => '먼저 설정 → 기억에서 기억 처리 모델을 선택하세요';

  @override
  String get memoryOrganizeStatusNever => '아직 정리되지 않음';

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
  String get memoryOutcomeTemporaryConversation => '임시 대화는 기억에 저장되지 않습니다';

  @override
  String get memoryOutcomeMemoryDisabled => '이 어시스턴트의 기억이 꺼져 있습니다';

  @override
  String get memoryOutcomeAutoOrganizeOff => '자동 정리가 꺼져 있습니다';

  @override
  String get memoryOutcomeStreaming => '응답이 아직 생성 중이라 건너뛰었습니다';

  @override
  String get memoryOutcomeBelowThreshold => '정리할 새 메시지가 충분하지 않습니다';

  @override
  String get memoryOutcomeEmptyWindow => '정리할 새 메시지가 없습니다';

  @override
  String get memoryOutcomeMemoryModelUnset => '기억 처리 모델이 선택되지 않았습니다';

  @override
  String get memoryOutcomeMemoryModelMissing => '선택한 기억 모델을 더 이상 사용할 수 없습니다';

  @override
  String get memoryOutcomeAssistantMissing => '어시스턴트를 찾을 수 없습니다';

  @override
  String get memoryOutcomeConversationMissing => '대화를 찾을 수 없습니다';

  @override
  String get memoryOutcomeQueueOverflow => '정리 대기열이 가득 차 이번 작업이 취소되었습니다';

  @override
  String get memoryOutcomeGateRequestFailed =>
      '기억/건너뛰기 판단을 위해 기억 모델에 요청할 수 없습니다';

  @override
  String get memoryOutcomeGateParseFailed => '기억/건너뛰기 판단 응답을 해석할 수 없습니다';

  @override
  String get memoryOutcomeExtractRequestFailed => '기억 추출을 위해 기억 모델에 요청할 수 없습니다';

  @override
  String get memoryOutcomeExtractParseFailed => '기억 추출 응답을 해석할 수 없습니다';

  @override
  String get memoryOutcomeDistillFailed => '사용자 프로필을 추출할 수 없습니다';

  @override
  String get memoryOutcomeMemoryExecutionError => '기억 도구 실행에 실패했습니다';

  @override
  String get memoryOutcomeUnsupportedTool => '지원되지 않는 기억 도구입니다';

  @override
  String get memoryOutcomeInvalidMemoryType => '기억 유형이 올바르지 않습니다';

  @override
  String get memoryOutcomeInvalidMemoryContent => '유효하지 않은 메모리 내용입니다';

  @override
  String get memoryOutcomeInvalidQuery => '유효하지 않은 검색어입니다';

  @override
  String get memoryOutcomeInvalidMemoryId => '유효하지 않은 메모리 ID입니다';

  @override
  String get memoryOutcomeMemoryNotFound => '메모리를 찾을 수 없습니다';

  @override
  String get memoryOutcomeInvalidProfileFields => '유효하지 않은 프로필 필드입니다';

  @override
  String get memoryOutcomeChatSearchUnavailable => '대화 검색을 사용할 수 없습니다';

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
  String get memoryModelMissingNotice => '먼저 설정 → 메모리에서 메모리 처리 모델을 선택하세요.';

  @override
  String get memoryModelMissingGoSelect => '모델 선택';

  @override
  String get memoryEntriesPageTitle => '전체 메모리';

  @override
  String get userProfilePageTitle => '사용자 프로필';

  @override
  String get userProfilePreferredName => '선호 이름';

  @override
  String get userProfilePreferredNameHint =>
      '모델이 당신을 어떻게 부를지 지정합니다. 사이드바 표시 이름과는 무관합니다';

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
  String get userProfileCustomSection => '사용자 정의 필드';

  @override
  String get userProfileAddCustom => '사용자 정의 필드 추가';

  @override
  String get userProfileCustomKeyHint => '키 (custom.name)';

  @override
  String get userProfileCustomValueHint => '값';

  @override
  String get userProfileInvalidKey =>
      '키는 custom. 뒤에 1–32자의 영문자, 숫자, _ 또는 -여야 합니다';

  @override
  String get userProfileClear => '지우기';

  @override
  String get userProfileSave => '저장';

  @override
  String get userProfileEmptyValue => '설정되지 않음';

  @override
  String get legacyMemoryPageTitle => '레거시 메모리';

  @override
  String get legacyMemoryBanner =>
      '이 메모리는 이전 버전에서 가져온 것으로 대화에 사용되지 않습니다. 현재 메모리 시스템으로 마이그레이션할 수 있습니다.';

  @override
  String get legacyMemoryEmpty => '레거시 메모리가 없습니다';

  @override
  String get legacyMemoryCopy => '복사';

  @override
  String get legacyMemoryCopied => '복사됨';

  @override
  String get legacyMemoryExport => '내보내기';

  @override
  String get legacyMemoryExportTitle => 'Kelivo 레거시 메모리 내보내기';

  @override
  String legacyMemoryAssistantHeader(String name) {
    return '어시스턴트: $name';
  }

  @override
  String get legacyMemorySearchHint => '레거시 메모리 검색';

  @override
  String get legacyMemoryMigrate => '마이그레이션';

  @override
  String get legacyMemoryMigrationTitle => '레거시 메모리 마이그레이션';

  @override
  String legacyMemoryMigrationSubtitle(int count) {
    return '모델을 사용하여 $count개의 레거시 메모리를 분류하고 정리합니다. 원본 데이터는 변경되지 않습니다.';
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
  String get legacyMemoryMigrationTargetGlobalDescription => '모든 어시스턴트가 사용 가능';

  @override
  String get legacyMemoryMigrationTargetAssistantDescription =>
      '이 어시스턴트만 사용 가능';

  @override
  String get legacyMemoryMigrationTargetOriginalDescription =>
      '각 기억을 원래 어시스턴트에 유지';

  @override
  String get legacyMemoryMigrationStart => '마이그레이션 시작';

  @override
  String get legacyMemoryMigrationAnalyzing => '모델로 분석 중';

  @override
  String get legacyMemoryMigrationWriting => '기억 저장 중';

  @override
  String legacyMemoryMigrationProgress(int current, int total) {
    return '$total개 중 $current개';
  }

  @override
  String get legacyMemoryMigrationComplete => '마이그레이션 완료';

  @override
  String legacyMemoryMigrationResult(int created, int skipped) {
    return '$created개 마이그레이션됨 · $skipped개 이미 존재함';
  }

  @override
  String get legacyMemoryMigrationFailed =>
      '마이그레이션이 중단되었습니다. 다시 시도할 수 있으며, 이미 저장된 기억은 건너뜁니다.';

  @override
  String get legacyMemoryMigrationRetry => '다시 시도';

  @override
  String get legacyMemoryMigrationClose => '완료';

  @override
  String get legacyMemoryMigrationContentMode => '내용 처리';

  @override
  String get legacyMemoryMigrationContentPreserve => '원문 유지';

  @override
  String get legacyMemoryMigrationContentOrganize => '모델로 재작성';

  @override
  String get legacyMemoryMigrationContentPreserveDescription =>
      '모델은 유형만 지정하며, 원래 문구가 그대로 저장됩니다.';

  @override
  String get legacyMemoryMigrationContentOrganizeDescription =>
      '모델이 편집 가능한 마이그레이션 프롬프트를 사용해 각 기억을 분류하고 재작성합니다.';

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
      '네트워크 오류입니다. 연결을 확인한 후 다시 시도하세요.';

  @override
  String get legacyMemoryMigrationErrorFormat => '모델이 잘못된 응답을 반환했습니다.';

  @override
  String get legacyMemoryMigrationErrorAuth => '인증에 실패했습니다. API 키를 확인하세요.';

  @override
  String legacyMemoryMigrationErrorOther(String message) {
    return '마이그레이션 실패: $message';
  }

  @override
  String get legacyMemoryModeTitle => '레거시 기억 사용';

  @override
  String get legacyMemoryModeSubtitle => '모든 어시스턴트에 적용되는 전역 설정';

  @override
  String legacyMemoryModeCacheWarning(String token) {
    return '기본 템플릿은 $token을(를) 통해 현재 시간을 주입하며, 이는 캐시 적중률에 영향을 줍니다. 필요하지 않으면 삭제하세요.';
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
  String get memoryUiSearchClear => '검색 지우기';

  @override
  String get memoryUiAssistantLegacyTitle => '레거시 기억 (읽기 전용)';

  @override
  String get memoryUiAssistantLegacySubtitle => '이전 버전에서 가져온 이 어시스턴트의 기억';

  @override
  String get assistantEditMemorySwitchTitle => '장기 기억 사용';

  @override
  String get assistantEditMemorySwitchSubtitle =>
      '저장된 기억을 대화에 주입하고 이 어시스턴트가 새 기억을 작성하도록 허용';

  @override
  String get assistantEditAutoOrganizeTitle => '기억 자동 정리';

  @override
  String get assistantEditAutoOrganizeSubtitle => '대화 후 기억 파이프라인 실행';

  @override
  String get assistantEditAllowPastRecallTitle => '과거 대화 회상 허용';

  @override
  String get assistantEditAllowPastRecallSubtitle => '과거 대화 전체에 걸친 대화 검색 활성화';

  @override
  String get assistantEditGenerateSummaryTitle => '대화 요약 생성';

  @override
  String get assistantEditGenerateSummarySubtitle => '요약은 대화 검색에만 사용됩니다';

  @override
  String get assistantEditManageMemoryTitle => '이 어시스턴트가 볼 수 있는 기억';

  @override
  String get assistantEditWriteScopeTitle => '기억 쓰기 범위';

  @override
  String get assistantEditWriteScopeSubtitle => '새 기억이 기본적으로 저장되는 위치';

  @override
  String get assistantEditWriteScopeAlwaysGlobal => '항상 전역';

  @override
  String get assistantEditWriteScopeAlwaysGlobalSubtitle =>
      '새 기억이 모든 어시스턴트와 공유됩니다';

  @override
  String get assistantEditWriteScopeAlwaysAssistant => '항상 이 어시스턴트';

  @override
  String get assistantEditWriteScopeAlwaysAssistantSubtitle =>
      '새 기억이 이 어시스턴트에게만 비공개로 유지됩니다';

  @override
  String get assistantEditWriteScopeToolDefaultGlobal => '모델이 선택 (기본 전역)';

  @override
  String get assistantEditWriteScopeToolDefaultGlobalSubtitle =>
      '모델이 전역 또는 이 어시스턴트를 선택할 수 있으며, 기본값은 전역입니다';

  @override
  String get assistantEditWriteScopeToolDefaultAssistant =>
      '모델 선택 (기본: 이 어시스턴트)';

  @override
  String get assistantEditWriteScopeToolDefaultAssistantSubtitle =>
      '모델이 전역 또는 이 어시스턴트를 선택할 수 있으며, 기본값은 이 어시스턴트입니다';

  @override
  String get assistantEditDedupeModeTitle => '중복 제거 방식';

  @override
  String get assistantEditDedupeModeSubtitle => '후보 기억을 기존 항목과 비교하는 방식';

  @override
  String get assistantEditDedupeModeBatched => '일괄 처리';

  @override
  String get assistantEditDedupeModeBatchedSubtitle =>
      '이번 라운드의 모든 후보를 한 번의 요청으로 판단합니다. 더 빠르고 저렴하지만 항목이 많으면 정확도가 떨어집니다.';

  @override
  String get assistantEditDedupeModePerItem => '항목별';

  @override
  String get assistantEditDedupeModePerItemSubtitle =>
      '각 후보를 개별 요청으로 판단합니다. 더 정확하지만 모델 호출이 늘어납니다.';

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
  String get assistantEditOrganizeFrequencyCustomTitle => '사용자 지정 빈도';

  @override
  String get assistantEditOrganizeFrequencyCustomDescription =>
      '1에서 20 사이의 숫자를 입력하세요.';

  @override
  String get assistantEditOrganizeFrequencyCustomLabel => '턴 수';

  @override
  String get assistantEditOrganizeFrequencyCustomHint => '1–20';

  @override
  String get assistantEditOrganizeFrequencyCustomInvalid =>
      '1에서 20 사이의 숫자를 입력하세요';

  @override
  String get worldBookTitle => '세계관';

  @override
  String get worldBookAdd => '세계관 추가';

  @override
  String get worldBookEmptyMessage => '아직 세계관이 없습니다';

  @override
  String get worldBookUnnamed => '이름 없는 세계관';

  @override
  String get worldBookDisabledTag => '비활성화됨';

  @override
  String get worldBookAlwaysOnTag => '상시 활성';

  @override
  String get worldBookAddEntry => '항목 추가';

  @override
  String get worldBookExport => '공유/내보내기';

  @override
  String get worldBookConfig => '설정';

  @override
  String get worldBookDeleteTitle => '세계관 삭제';

  @override
  String worldBookDeleteMessage(String name) {
    return '“$name”을(를) 삭제할까요? 이 작업은 되돌릴 수 없습니다.';
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
  String get worldBookEntryKeywordsHint => '키워드를 입력한 후 +를 눌러 추가하세요.';

  @override
  String get worldBookEntryKeywordInputHint => '키워드 입력';

  @override
  String get worldBookEntryKeywordAddTooltip => '키워드 추가';

  @override
  String get worldBookEntryUseRegexLabel => '정규식 사용';

  @override
  String get worldBookEntryCaseSensitiveLabel => '대소문자 구분';

  @override
  String get worldBookEntryAlwaysOnLabel => '항상 활성화';

  @override
  String get worldBookEntryAlwaysOnHint => '키워드 일치 없이 항상 주입';

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
  String get worldBookInjectionPositionTopOfChat => '대화 상단';

  @override
  String get worldBookInjectionPositionBottomOfChat => '대화 하단';

  @override
  String get worldBookInjectionPositionAtDepth => '지정 깊이';

  @override
  String worldBookImportUnsupportedEntries(int count) {
    return '가져왔습니다. $count개 항목이 지원되지 않는 SillyTavern 기능(매크로, 정규식, 타이밍, 필터, 삽입 규칙 등)을 사용합니다. 내용은 유지하고 비활성화했습니다. 활성화하기 전에 검토하세요.';
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
  String get toolApprovalDeny => '거부';

  @override
  String get toolApprovalDenyTitle => '도구 호출 거부';

  @override
  String get toolApprovalDenyHint => '이유 (선택 사항)';

  @override
  String toolApprovalDeniedMessage(Object reason, Object toolName) {
    return '도구 호출 \"$toolName\"이(가) 사용자에 의해 거부되었습니다. 이유: $reason';
  }

  @override
  String get askUserCardSubmit => '답변 제출';

  @override
  String get askUserCardCustomHint => '답변을 입력하세요';

  @override
  String get askUserCardSomethingElse => '기타';

  @override
  String get askUserCardSkip => '건너뛰기';

  @override
  String get askUserCardSkipped => '건너뜀';

  @override
  String get askUserCardAnswered => '답변 완료';

  @override
  String get askUserCardInactive =>
      '이 질문은 더 이상 활성 상태가 아닙니다. 다시 생성하거나 대화를 계속하세요.';

  @override
  String get askUserCardCancelled => '질문이 취소됨';

  @override
  String askUserCardQuestionCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count개 질문하기',
    );
    return '$_temp0';
  }

  @override
  String tokenDetailPromptTokens(int count) {
    return '$count 토큰';
  }

  @override
  String tokenDetailPromptTokensWithCache(int count, int cached) {
    return '$count 토큰 ($cached 캐시됨)';
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
  String tokenDetailFirstResponse(String value) {
    return '$value초 (첫 응답)';
  }

  @override
  String tokenDetailFirstOutput(String value) {
    return '$value초 (첫 출력)';
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
    return '$count 캐시 쓰기 토큰';
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
  String get debugPageCreateOversizedConversationButton => '대용량 대화 생성 (30 MB)';

  @override
  String get debugPageCreateManyMessagesConversationButton => '1024개 메시지 대화 생성';

  @override
  String get debugPageCreateDailyMixedMarkdownConversationButton =>
      '일상 혼합 Markdown 메시지 3000개 생성';

  @override
  String get debugPageCreateLongReasoningConversationButton =>
      '긴 추론 대화 생성 (128개 메시지)';

  @override
  String get debugPageCreatingButton => '생성 중...';

  @override
  String get debugPageCreatingOversizedConversation => '30 MB 대용량 대화 생성 중...';

  @override
  String get debugPageCreatingManyMessagesConversation =>
      '1024개 메시지 대화 생성 중...';

  @override
  String get debugPageCreatingDailyMixedMarkdownConversation =>
      '3000개 메시지 일상 혼합 Markdown 대화 생성 중...';

  @override
  String get debugPageCreatingLongReasoningConversation =>
      '긴 추론 디버그 대화를 생성하는 중...';

  @override
  String get debugPageNoCurrentAssistant =>
      '현재 어시스턴트가 없습니다. 먼저 어시스턴트를 생성하거나 선택하세요.';

  @override
  String debugPageConversationCreated(int count) {
    return '$count개의 메시지가 포함된 디버그 대화를 생성했습니다.';
  }

  @override
  String debugPageCreateConversationFailed(String error) {
    return '디버그 대화 생성 실패: $error';
  }

  @override
  String debugPageOversizedConversationTitle(int sizeMB) {
    return '대용량 대화 테스트($sizeMB MB)';
  }

  @override
  String debugPageManyMessagesConversationTitle(int count) {
    return '$count개 메시지 대화 테스트';
  }

  @override
  String debugPageDailyMixedMarkdownConversationTitle(int count) {
    return '$count개 일상 혼합 Markdown 메시지 테스트';
  }

  @override
  String debugPageLongReasoningConversationTitle(int count) {
    return '$count개 긴 추론 테스트';
  }

  @override
  String get debugPageOversizedConversationSeedText =>
      '대용량 대화에서 느린 렌더링을 재현하기 위한 긴 디버그 텍스트입니다. 반복되는 Markdown 스타일 텍스트, 문장 부호, CJK 콘텐츠, 일반 단어를 포함하여 채팅 렌더링, 저장, 스크롤 성능을 프로파일링할 수 있습니다.';

  @override
  String debugPageManyMessagesSeedText(String role, int index) {
    return '$role 메시지 #$index: 목록 렌더링, 스크롤 안정성, 메시지 그룹화, 대화 기록 성능을 테스트하기 위한 빠른 무작위 디버그 샘플입니다.';
  }

  @override
  String get migrationIntroTitle => '채팅 저장소 업그레이드';

  @override
  String get migrationIntroSubtitle =>
      'Kelivo가 채팅 기록을 더 빠른 SQLite 데이터베이스로 이전합니다. 데이터 일관성을 유지하기 위해 앱이 열리기 전에 업그레이드가 실행됩니다.';

  @override
  String get migrationBackupNote =>
      '마이그레이션 시작 전에 설정, 채팅 기록, 로컬 파일을 포함한 ZIP 백업을 내보냅니다.';

  @override
  String get migrationPerformanceNote =>
      '마이그레이션 후에는 시작, 기록 로드, 검색이 SQLite 인덱스를 사용하여 긴 대화에서도 더 부드럽게 동작합니다.';

  @override
  String get migrationSourceDatabaseLabel => 'Hive';

  @override
  String get migrationTargetDatabaseLabel => 'SQLite';

  @override
  String get migrationChooseFolderButton => '폴더 선택 및 백업';

  @override
  String get migrationSaveBackupButton => '백업 ZIP 저장';

  @override
  String get migrationStartWithoutBackupButton => '백업 없이 마이그레이션';

  @override
  String get migrationSkipChatsJsonOption => 'chats.json 건너뛰기';

  @override
  String get migrationSkipChatsJsonDescription =>
      '원본 Hive 파일, 설정, 로컬 파일은 계속 백업됩니다. 매우 큰 기록에 권장됩니다.';

  @override
  String get migrationSkipBackupOption => '이번 백업 건너뛰기';

  @override
  String get migrationSkipBackupDescription =>
      '검증된 백업이 이미 있는 경우에만 선택하세요. 마이그레이션이 즉시 시작됩니다.';

  @override
  String get migrationBackingUpTitle => '백업 중';

  @override
  String get migrationBackingUpSubtitle =>
      '설정, 채팅 기록, 업로드된 파일, 이미지, 글꼴을 내보내는 중입니다. 완료될 때까지 Kelivo를 열어 두세요.';

  @override
  String get migrationMigratingTitle => 'SQLite로 마이그레이션 중';

  @override
  String get migrationMigratingSubtitle =>
      '대용량 기록이 메모리를 과부하시키지 않도록 대화와 메시지를 일괄로 기록하는 중입니다. 마이그레이션이 완료될 때까지 Kelivo를 포그라운드에 유지하세요.';

  @override
  String migrationBackingUpDetail(String fileName) {
    return '$fileName 백업 중';
  }

  @override
  String migrationMigratingDetail(int count) {
    return '$count개 메시지 마이그레이션됨';
  }

  @override
  String get migrationMigratingPrepareDetail => 'SQLite 데이터베이스 준비 중';

  @override
  String get migrationMigratingToolEventsDetail => '도구 기록 마이그레이션 중';

  @override
  String get migrationMigratingValidateDetail => '마이그레이션된 데이터 검증 중';

  @override
  String get migrationBackupReadyDetail => '백업 ZIP이 준비되었습니다';

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
  String get migrationChecklistValidate => '마이그레이션된 데이터 검증';

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
      '채팅 기록이 이제 SQLite에 저장됩니다. 업그레이드된 앱으로 들어가려면 Kelivo를 다시 시작하세요.';

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
  String get migrationRestartButton => 'Kelivo 재시작';

  @override
  String get migrationFailedTitle => '마이그레이션 실패';

  @override
  String get migrationFailedSubtitle =>
      '원본 Hive 데이터는 그대로 유지되며, 이미 완료된 백업도 변경되지 않습니다. 아래 원인을 확인한 후 다시 시도하세요.';

  @override
  String get migrationUnknownError => '알 수 없는 마이그레이션 오류입니다.';

  @override
  String get migrationFailureLogTitle => '실패 로그';

  @override
  String get migrationRetryButton => '마이그레이션 재시도';

  @override
  String get migrationSkipButton => '마이그레이션 건너뛰고 새로 시작';

  @override
  String get migrationSkipDialogTitle => '마이그레이션을 건너뛸까요?';

  @override
  String get migrationSkipDialogMessage =>
      'Kelivo가 빈 채팅 데이터베이스로 시작됩니다. 기존 채팅 기록은 디스크에 남아 있지만(.retired 접미사로 이름 변경) 마이그레이션되지 않으며 앱에 표시되지 않습니다. 나중에 복구하려면 백업 ZIP을 사용하세요.';

  @override
  String get migrationSkipDialogCancel => '취소';

  @override
  String get migrationSkipDialogConfirm => '건너뛰고 새로 시작';

  @override
  String get migrationChatsExportDegradedNote =>
      '오류로 인해 chats.json 내보내기가 건너뛰어졌습니다. 백업 ZIP에는 전체 채팅 기록이 담긴 원본 Hive 파일이 여전히 포함되어 있습니다.';

  @override
  String get timelineJumpToLatest => '최신으로 이동';

  @override
  String largeContentShowMore(int count) {
    return '$count개 더 보기';
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
  String get imageSettingsPageQualityOriginalSubtitle => '압축하지 않고 그대로 업로드';

  @override
  String get imageSettingsPageQualityHigh => '고품질';

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
  String get imageSettingsPageQualityCustomSubtitle => '압축 품질 직접 선택';

  @override
  String get imageSettingsPageCustomQualityTitle => '압축 품질';

  @override
  String get imageSettingsPageCompressTransparentTitle => '투명 및 애니메이션 이미지 압축';

  @override
  String get imageSettingsPageCompressTransparentSubtitle =>
      '활성화하면 투명 PNG, GIF 등의 형식이 압축됩니다. 투명 영역은 흰색으로 채워지고 애니메이션은 첫 프레임만 유지됩니다.';

  @override
  String get imageSettingsPageFooter =>
      '압축은 이미지를 추가할 때 수행되며, 이미 저장되었거나 전송된 이미지는 영향을 받지 않습니다. 압축된 이미지는 JPEG 파일로 전송됩니다.';

  @override
  String get imageSettingsPageSendSectionTitle => '전송';

  @override
  String get imageSettingsPageMarkdownImageLinksTitle =>
      'Markdown 이미지 링크를 이미지로 전송';

  @override
  String get imageSettingsPageMarkdownImageLinksSubtitle =>
      '활성화하면 메시지 텍스트의 ![alt](url) 링크가 비전 모델에 이미지로 전송됩니다. 비활성화하면 일반 텍스트로 유지됩니다. 직접 첨부한 이미지는 항상 이미지로 전송됩니다.';

  @override
  String get memoryTraceSettingsTitle => '파이프라인 추적';

  @override
  String get memoryTraceSettingsSubtitle => '매 백그라운드 메모리 실행 과정을 단계별로 확인';

  @override
  String get memoryTracePageTitle => '메모리 파이프라인 추적';

  @override
  String get memoryTraceRecordingSection => '기록';

  @override
  String get memoryTraceToggleTitle => '파이프라인 추적 기록';

  @override
  String get memoryTraceToggleSubtitle =>
      '최근 백그라운드 실행의 프롬프트, 응답 및 변경 사항을 메모리에만 보관합니다';

  @override
  String get memoryTraceRunsSection => '최근 실행';

  @override
  String get memoryTraceEmptyTitle => '아직 추적 기록이 없습니다';

  @override
  String get memoryTraceEmptySubtitle =>
      '백그라운드 메모리 파이프라인이 실행되면 추적 기록이 여기에 표시됩니다.';

  @override
  String get memoryTraceDisabledTitle => '기록이 꺼져 있습니다';

  @override
  String get memoryTraceDisabledSubtitle => '기록을 켜면 다음 백그라운드 메모리 실행이 캡처됩니다.';

  @override
  String get memoryTraceClearAction => '지우기';

  @override
  String get memoryTraceClearSheetTitle => '추적 기록 지우기';

  @override
  String get memoryTraceClearSheetMessage =>
      '기록된 모든 추적이 삭제됩니다. 추적은 디스크에 기록되지 않으므로 다른 데이터에는 영향을 주지 않습니다.';

  @override
  String get memoryTraceClearConfirm => '추적 기록 지우기';

  @override
  String get memoryTraceCancel => '취소';

  @override
  String get memoryTraceClearedToast => '추적 기록이 삭제되었습니다';

  @override
  String get memoryTraceCopyAction => '복사';

  @override
  String get memoryTraceCopiedToast => '클립보드에 복사되었습니다';

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
  String get memoryTraceStepChatSearch => '과거 대화 검색';

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
  String get memoryTraceOutcomeAdvanced => '워터마크 진행됨';

  @override
  String get memoryTraceOutcomeHeld => '워터마크 유지됨';

  @override
  String get memoryTraceOutcomeForced => '강제 진행';

  @override
  String get memoryTraceDetailTitle => '추적 상세';

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
  String get memoryTraceFieldConversation => '대화';

  @override
  String get memoryTraceFieldAssistant => '어시스턴트';

  @override
  String get memoryTraceFieldWindow => '메시지 창';

  @override
  String get memoryTraceFieldWatermark => '워터마크';

  @override
  String get memoryTraceFieldOutcome => '결과';

  @override
  String get memoryTraceFieldError => '오류';

  @override
  String get memoryTraceMutationCreated => '생성됨';

  @override
  String get memoryTraceMutationMerged => '병합됨';

  @override
  String get memoryTraceMutationEdited => '수정됨';

  @override
  String get memoryTraceMutationArchived => '보관됨';

  @override
  String get memoryTraceMutationLinked => '연결됨';

  @override
  String get memoryTraceMutationProfileWritten => '프로필 필드 작성됨';

  @override
  String get memoryTraceMutationProfileCleared => '프로필 필드 삭제됨';

  @override
  String get memoryTraceMutationSummary => '대화 요약 작성됨';

  @override
  String get memoryTraceBefore => '변경 전';

  @override
  String get memoryTraceAfter => '변경 후';

  @override
  String get memoryTraceEmptyValue => '(비어 있음)';

  @override
  String memoryTraceStepsCount(int count) {
    return '$count단계';
  }

  @override
  String memoryTraceMutationsCount(int count) {
    return '$count개 변경';
  }

  @override
  String memoryTraceRepeatCount(int count) {
    return '$count회 반복';
  }

  @override
  String memoryTraceWindowValue(int size, int start, int end) {
    return '$size개 메시지 · #$start–#$end';
  }

  @override
  String get memoryTraceShowMore => '전체 텍스트 보기';

  @override
  String get memoryTraceShowLess => '접기';

  @override
  String get messageStyleSettingsPageTitle => '메시지 스타일';

  @override
  String get messageStyleSettingsPageReset => '초기화';

  @override
  String get messageStyleSettingsPageResetConfirm =>
      '모든 메시지 스타일 사용자 지정을 초기화할까요?';

  @override
  String get messageStyleSettingsPageCancel => '취소';

  @override
  String get messageStyleSettingsPageLight => '라이트';

  @override
  String get messageStyleSettingsPageDark => '다크';

  @override
  String get messageStyleSettingsPageDefaultHint =>
      '기본 스타일은 현재 테마를 따르며 조정할 수 있는 항목이 없습니다.';

  @override
  String get messageStyleSettingsPageStyleDefaultSubtitle =>
      '테마를 따르며 사용자 지정 불가';

  @override
  String get messageStyleSettingsPageAssistantFitContent =>
      '어시스턴트 말풍선을 내용에 맞추기';

  @override
  String get messageStyleSettingsPageAssistantFitContentSubtitle =>
      '어시스턴트 말풍선이 행을 채우지 않고 텍스트 너비에 맞게 줄어듭니다';

  @override
  String get messageStyleSettingsPageAssistantSplitParagraphs =>
      '문단을 말풍선으로 나누기';

  @override
  String get messageStyleSettingsPageAssistantSplitParagraphsSubtitle =>
      '어시스턴트 답변의 빈 줄마다 문단별로 하나의 말풍선으로 나눕니다';

  @override
  String get messageStyleSettingsPageStyleFrostedSubtitle => '반투명 프로스트 유리';

  @override
  String get messageStyleSettingsPageStyleSolidSubtitle => '불투명 단색 채우기';

  @override
  String get messageStyleSettingsPageBlur => '흐림';

  @override
  String get messageStyleSettingsPageBlurHint =>
      '흐림은 말풍선 뒤의 내용에 적용됩니다. 채팅 배경화면이 없으면 효과가 거의 보이지 않습니다.';

  @override
  String get messageStyleSettingsPageBackgroundColor => '배경';

  @override
  String get messageStyleSettingsPageBackgroundOpacity => '배경 불투명도';

  @override
  String get messageStyleSettingsPageBorderColor => '테두리';

  @override
  String get messageStyleSettingsPageBorderOpacity => '테두리 불투명도';

  @override
  String get messageStyleSettingsPageBorderWidth => '테두리 너비';

  @override
  String get messageStyleSettingsPageTextColor => '텍스트';

  @override
  String get messageStyleSettingsPageCornerRadius => '모서리 반경';

  @override
  String get messageStyleSettingsPagePreviewUser => '사용자 메시지입니다';

  @override
  String get messageStyleSettingsPagePreviewAssistant => '어시스턴트 답변입니다.';

  @override
  String get messageStyleSettingsPagePreviewThinking => '생각 중';

  @override
  String get messageStyleSettingsPageRoleUser => '사용자';

  @override
  String get messageStyleSettingsPageRoleAssistant => '어시스턴트';

  @override
  String get messageStyleSettingsPageRoleAssistantHint =>
      '어시스턴트 설정은 생각, 도구 호출, 번역 카드에도 적용됩니다.';

  @override
  String get localSnapshotSectionTitle => '로컬 사본';

  @override
  String get localSnapshotEnabledTitle => '로컬 사본 유지';

  @override
  String get localSnapshotEnabledSubtitle =>
      'Kelivo가 이 기기에 데이터베이스 사본을 주기적으로 저장하여 데이터가 단 하나만 존재하지 않도록 합니다.';

  @override
  String get localSnapshotIntervalTitle => '주기';

  @override
  String get localSnapshotIntervalAutomatic => '자동';

  @override
  String get localSnapshotIntervalAutomaticDetail => '매일, 데이터베이스가 커질수록 간격이 길어짐';

  @override
  String localSnapshotIntervalDays(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days일마다',
    );
    return '$_temp0';
  }

  @override
  String get localSnapshotKeepTitle => '보관할 사본 수';

  @override
  String localSnapshotKeepValue(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count개 사본',
    );
    return '$_temp0';
  }

  @override
  String get localSnapshotKeepSubtitle =>
      '지난주 사본 하나와 지난달 사본 하나를 추가로 보관하여, 늦게 발견된 문제도 복구할 수 있습니다.';

  @override
  String get localSnapshotKeepWeekly => '지난주 사본 하나 보관';

  @override
  String get localSnapshotKeepMonthly => '지난달 사본 하나 보관';

  @override
  String get localSnapshotKeepProtectedNote =>
      '이 설정과 관계없이 데이터가 남아 있는 가장 최근 사본은 자동으로 삭제되지 않습니다.';

  @override
  String get localSnapshotMaximumTitle => '공간 제한';

  @override
  String get localSnapshotMaximumUnlimited => '제한 없음';

  @override
  String get localSnapshotAnnounceTitle => '복사본 저장 시 알림';

  @override
  String get localSnapshotAnnounceSubtitle =>
      '실패는 항상 알려드립니다. 이 설정은 성공 시 짧은 메시지만 추가합니다.';

  @override
  String get localSnapshotTakeNow => '지금 복사본 저장';

  @override
  String get localSnapshotManageCopies => '복사본 관리';

  @override
  String localSnapshotUsage(int count, String size) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '복사본 $count개',
      zero: '복사본 없음',
    );
    return '$_temp0 · $size';
  }

  @override
  String get localSnapshotStatusNever => '아직 저장된 복사본이 없습니다';

  @override
  String localSnapshotStatusSuccess(String when) {
    return '마지막 복사본 $when';
  }

  @override
  String localSnapshotStatusFailure(String when, String reason) {
    return '마지막 시도 실패 $when: $reason';
  }

  @override
  String get localSnapshotStatusSkippedSpace => '건너뜀: 이 기기의 여유 공간이 부족합니다';

  @override
  String get localSnapshotStatusUnchanged => '마지막 복사본 이후 변경된 내용이 없습니다';

  @override
  String get localSnapshotCopiesTitle => '로컬 복사본';

  @override
  String get localSnapshotCopiesEmpty => '아직 로컬 복사본이 없습니다';

  @override
  String get localSnapshotCopiesEmptyHint =>
      '데이터가 변경되면 자동으로 복사본이 저장되며, 복원 전에도 항상 복사본이 저장됩니다.';

  @override
  String get localSnapshotCopiesScopeNote =>
      '로컬 복사본은 이 기기에만 저장됩니다. 앱 내 데이터 손상이나 실수로 인한 삭제는 방지할 수 있지만, 기기 분실이나 Kelivo 제거로 인한 손실은 방지할 수 없습니다. 이를 위해서는 WebDAV 또는 S3 백업을 사용하세요.';

  @override
  String get localSnapshotOriginAutomatic => '자동';

  @override
  String get localSnapshotOriginManual => '직접 저장';

  @override
  String get localSnapshotOriginBeforeRestore => '복원 전';

  @override
  String get localSnapshotKindRecovered => '복구 과정에서 보관됨';

  @override
  String localSnapshotCopyContents(int conversations, int messages) {
    String _temp0 = intl.Intl.pluralLogic(
      conversations,
      locale: localeName,
      other: '대화 $conversations개',
    );
    String _temp1 = intl.Intl.pluralLogic(
      messages,
      locale: localeName,
      other: '메시지 $messages개',
    );
    return '$_temp0 · $_temp1';
  }

  @override
  String get localSnapshotCopyContentsUnknown => '내용은 복원 후에 확인할 수 있습니다';

  @override
  String get localSnapshotCopyPinned => '보관됨';

  @override
  String get localSnapshotActionRestore => '복원';

  @override
  String get localSnapshotActionExport => '내보내기';

  @override
  String get localSnapshotActionDelete => '삭제';

  @override
  String get localSnapshotActionPin => '이 복사본 보관';

  @override
  String get localSnapshotActionUnpin => '보관 해제';

  @override
  String get localSnapshotRestoreTitle => '이 복사본을 복원할까요?';

  @override
  String localSnapshotRestoreMessage(String when) {
    return '현재 채팅과 설정이 $when의 복사본으로 대체됩니다. 대체 전에 현재 채팅과 설정의 복사본이 먼저 저장됩니다. 전송되지 않은 임시 저장 내용은 복사본에 포함되지 않으며 이번 복원 시 삭제됩니다.';
  }

  @override
  String get localSnapshotRestorePreparing => '복사본 준비 중';

  @override
  String get localSnapshotDeleteTitle => '이 복사본을 삭제할까요?';

  @override
  String get localSnapshotDeleteMessage =>
      '이 복사본은 기기에서 영구적으로 삭제됩니다. 현재 데이터베이스에 없는 이 복사본의 데이터는 복구할 수 없습니다.';

  @override
  String get localSnapshotDeleteLastWarning => '이것은 아직 데이터가 남아 있는 유일한 복사본입니다.';

  @override
  String get localSnapshotExportPreparing => '내보내기 준비 중';

  @override
  String get localSnapshotExportDone => '복사본을 내보냈습니다';

  @override
  String localSnapshotExportFailed(String reason) {
    return '복사본을 내보낼 수 없습니다: $reason';
  }

  @override
  String get localSnapshotTakeDone => '복사본이 저장되었습니다';

  @override
  String localSnapshotTakeFailed(String reason) {
    return '복사본을 저장할 수 없습니다: $reason';
  }

  @override
  String get localSnapshotDeleteDone => '복사본이 삭제되었습니다';

  @override
  String get localSnapshotBusyMessage => '다른 백업 작업이 이미 진행 중입니다';

  @override
  String get localSnapshotRunInBackground => '백그라운드에서 계속';

  @override
  String get localSnapshotRunningInBackground => '백그라운드에서 복사본을 저장하는 중';

  @override
  String startupRecoveryLocalCopiesAvailable(int count, String when) {
    return '이 기기에는 아직 로컬 복사본 $count개가 남아 있으며, 가장 최근 것은 $when의 것입니다. 초기화해도 삭제되지 않습니다. 재시작 후 설정 › 백업 › 로컬 복사본에서 복원할 수 있습니다.';
  }

  @override
  String startupRecoveryRecoveredCopiesDeleted(int count) {
    return '또한 이전 복구 과정에서 보관된 데이터베이스 복사본 $count개가 있으며, 초기화하면 영구적으로 삭제됩니다. 보관하려면 먼저 데이터를 내보내세요.';
  }

  @override
  String get toolSchemaSettingsPageTitle => '도구 설명';

  @override
  String get toolSchemaSettingsGroupSearch => '검색';

  @override
  String get toolSchemaSettingsGroupImages => '이미지';

  @override
  String get toolSchemaSettingsGroupMemory => '메모리';

  @override
  String get toolSchemaSettingsGroupLocal => '기기 도구';

  @override
  String get toolSchemaSettingsModified => '수정됨';

  @override
  String get toolSchemaSettingsResetDefault => '기본값 복원';

  @override
  String get toolSchemaSettingsResetAll => '모두 기본값으로 복원';

  @override
  String get toolSchemaSettingsResetAllTitle => '모두 기본값으로 복원할까요?';

  @override
  String get toolSchemaSettingsResetAllMessage =>
      '모든 내장 도구 설명이 앱 기본값으로 복원됩니다. 사용자 지정 문구는 사라집니다.';

  @override
  String get toolSchemaSettingsResetAllConfirm => '복원';

  @override
  String toolSchemaSettingsParamDescriptions(int count) {
    return '매개변수 설명 ($count)';
  }

  @override
  String get toolSchemaSettingsMemoryLangNote =>
      '메모리 도구의 기본 설명은 메모리 프롬프트 언어를 따릅니다. 사용자 지정 설명은 도구당 한 번만 저장되며 해당 언어를 변경해도 바뀌지 않습니다.';

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
      '파일이 너무 커서 미리 볼 수 없습니다. 외부 앱으로 여세요.';

  @override
  String get workspacePreviewSource => '소스';

  @override
  String get workspacePreviewRendered => '렌더링';

  @override
  String get workspacePreviewFileName => '이름';

  @override
  String get workspacePreviewFileSize => '크기';

  @override
  String get workspacePreviewFileModified => '수정됨';

  @override
  String get workspacePreviewPathCopied => '경로가 복사됨';

  @override
  String workspacePreviewLineCount(int count) {
    return '$count줄';
  }

  @override
  String get workspaceFilesSort => '정렬';

  @override
  String get workspaceFilesSortName => '이름';

  @override
  String get workspaceFilesSortModified => '수정됨';

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
  String get workspaceFilesRefresh => '새로 고침';

  @override
  String get workspaceFilesNewFolder => '새 폴더';

  @override
  String get workspaceFilesNewFile => '새 파일';

  @override
  String get workspaceFilesImport => '가져오기';

  @override
  String get workspaceFilesExport => '내보내기';

  @override
  String get workspaceFilesExportFolder => '폴더 내보내기';

  @override
  String get workspaceFilesEmpty => '이 폴더가 비어 있습니다';

  @override
  String get workspaceFilesError => '이 파일들을 불러오지 못했습니다';

  @override
  String get workspaceFilesRetry => '다시 시도';

  @override
  String get workspaceFilesPreview => '미리 보기';

  @override
  String get workspaceFilesRename => '이름 바꾸기';

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
  String get workspaceFilesCreate => '생성';

  @override
  String get workspaceFilesCancel => '취소';

  @override
  String get workspaceFilesConfirm => '확인';

  @override
  String get workspaceFilesSave => '저장';

  @override
  String get workspaceFilesDeleteTitle => '이 항목을 삭제할까요?';

  @override
  String workspaceFilesDeleteMessage(String name) {
    return '$name을(를) 삭제할까요?';
  }

  @override
  String workspaceFilesDeleteFolderMessage(String name) {
    return '폴더 $name 및 그 안의 모든 내용을 삭제할까요?';
  }

  @override
  String get workspaceFilesMoveTitle => '폴더로 이동';

  @override
  String get workspaceFilesMoveHere => '여기로 이동';

  @override
  String get workspaceFilesPathCopied => '경로가 복사되었습니다';

  @override
  String get workspaceFilesInvalidName => '유효하지 않은 이름입니다';

  @override
  String get workspaceFilesInvalidPath => '해당 경로는 이 폴더 밖에 있습니다';

  @override
  String workspaceFilesOperationFailed(String error) {
    return '작업을 완료하지 못했습니다: $error';
  }

  @override
  String get workspaceFilesActions => '작업';

  @override
  String get workspaceFilesMore => '더 보기';

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
  String get workspaceFilesTabOutputs => '출력';

  @override
  String get workspaceFilesTabWorkspace => '작업 공간';

  @override
  String get workspaceFilesNoWorkspaceBound => '바인딩된 작업 공간 없음';

  @override
  String get workspaceFilesKindManaged => '관리됨';

  @override
  String get workspaceFilesKindLinked => '연결됨';

  @override
  String get workspaceFilesMissingWorkspace => '작업 공간을 찾을 수 없음';

  @override
  String get workspaceFilesClose => '닫기';

  @override
  String get workspacesTitle => '작업 공간';

  @override
  String get workspacesCreate => '생성';

  @override
  String get workspacesCreateTitle => '새 작업 공간';

  @override
  String get workspacesNameLabel => '이름';

  @override
  String get workspacesNameHint => '작업 공간 이름';

  @override
  String get workspacesLinkFolder => '폴더 연결';

  @override
  String get workspacesEmpty => '아직 작업 공간이 없습니다';

  @override
  String get workspacesEmptyCta => '작업 공간 만들기';

  @override
  String get workspacesSettings => '설정';

  @override
  String get workspacesOpenFiles => '파일 열기';

  @override
  String get workspacesLastUsedNever => '사용한 적 없음';

  @override
  String workspacesLastUsed(String when) {
    return '마지막 사용 $when';
  }

  @override
  String get workspacesDeleteTitle => '이 작업 공간을 삭제할까요?';

  @override
  String workspacesDeleteMessage(String name) {
    return '작업 공간 $name을(를) 삭제할까요?';
  }

  @override
  String get workspacesDeleteAlsoFiles => '파일도 삭제';

  @override
  String get workspacesUnlinkTitle => '이 작업 공간의 연결을 해제할까요?';

  @override
  String workspacesUnlinkMessage(String name) {
    return '$name의 연결을 해제할까요? 디스크의 파일은 유지됩니다.';
  }

  @override
  String get workspacesSettingsTitle => '작업 공간 설정';

  @override
  String get workspacesShellNeedsApproval => '셸 명령을 실행하기 전에 확인';

  @override
  String get workspacesDefaultCwd => '기본 작업 디렉터리';

  @override
  String get workspacesDefaultCwdHint => '상대 경로, 예: src';

  @override
  String get workspacesDefaultCwdInvalid => '..가 없는 상대 경로를 사용하세요';

  @override
  String get workspacesCreateManaged => '작업 공간 만들기';

  @override
  String get workspacesLinkExisting => '기존 폴더 연결';

  @override
  String get workspacesUnlink => '연결 해제';

  @override
  String get workspacesItemMore => '작업 공간 작업';

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
  String get workspaceToolFuzzy => '유사';

  @override
  String get workspaceToolCreated => '생성됨';

  @override
  String get workspaceToolUpdated => '업데이트됨';

  @override
  String get workspaceToolTruncated => '잘림';

  @override
  String get workspaceToolImageTag => '이미지';

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
  String get workspaceToolCopyDiff => '차이 복사';

  @override
  String get workspaceToolCopied => '복사됨';

  @override
  String get workspaceToolDiffTruncated => '차이가 잘림';

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
    return 'Ubuntu $version (PRoot)';
  }

  @override
  String workspaceEnvEngineAlpine(String version) {
    return 'Alpine $version (iSH)';
  }

  @override
  String get workspaceEnvEngineNative => '네이티브 셸';

  @override
  String get workspaceEnvPhaseNotInstalled => '설치되지 않음';

  @override
  String get workspaceEnvPhaseDownloading => '다운로드 중';

  @override
  String get workspaceEnvPhaseVerifying => '확인 중';

  @override
  String get workspaceEnvPhaseExtracting => '압축 해제 중';

  @override
  String get workspaceEnvPhasePatching => '패치 중';

  @override
  String get workspaceEnvPhaseReady => '준비됨';

  @override
  String get workspaceEnvPhaseError => '오류';

  @override
  String get workspaceEnvPhaseNeedsRestart => '재시작 필요';

  @override
  String workspaceEnvMetaLine(String version, String arch) {
    return '$version · $arch';
  }

  @override
  String workspaceEnvInstalledAt(String date) {
    return '설치일 $date';
  }

  @override
  String workspaceEnvDiskUsage(String size) {
    return '디스크 사용량 $size';
  }

  @override
  String workspaceEnvRuntimeReason(String reason) {
    return '$reason';
  }

  @override
  String get workspaceEnvInstall => '설치';

  @override
  String get workspaceEnvInstallSubtitleAndroid =>
      'Ubuntu, Alpine, Debian 중 선택하거나 로컬 rootfs 이미지를 가져올 수 있습니다.';

  @override
  String get workspaceEnvInstallSubtitleIos => '내장됨, 다운로드 불필요';

  @override
  String get workspaceEnvCancel => '취소';

  @override
  String get workspaceEnvRetry => '재시도';

  @override
  String get workspaceEnvRepair => '복구';

  @override
  String get workspaceEnvReset => '초기화';

  @override
  String get workspaceEnvResetConfirmTitle => '환경을 초기화할까요?';

  @override
  String get workspaceEnvResetConfirmBody => '설치된 패키지와 샌드박스 파일 시스템이 삭제됩니다.';

  @override
  String get workspaceEnvCheckForUpdate => '업데이트 확인';

  @override
  String get workspaceEnvUpdate => '업데이트';

  @override
  String workspaceEnvAvailableVersion(String version) {
    return '버전 $version 사용 가능';
  }

  @override
  String get workspaceEnvUpToDate => '최신 상태입니다';

  @override
  String get workspaceEnvRestartBanner => '완료하려면 Kelivo를 재시작하세요';

  @override
  String get workspaceEnvDetectingMirrors => '가장 빠른 미러 감지 중…';

  @override
  String workspaceEnvApplyingMirror(String category) {
    return '$category 미러 적용 중…';
  }

  @override
  String get workspaceEnvMirrorsSection => '미러';

  @override
  String get workspaceEnvUseMirror => '미러 사용';

  @override
  String get workspaceEnvDetect => '감지';

  @override
  String get workspaceEnvOfficial => '공식';

  @override
  String get workspaceEnvMirrorsDisabled =>
      '미러 변경은 샌드박스에서 실행되며 준비되기 전까지 사용할 수 없습니다.';

  @override
  String workspaceEnvMirrorsDisabledReason(String reason) {
    return '미러 변경은 샌드박스에서 실행되며 사용할 수 없습니다: $reason';
  }

  @override
  String get workspaceEnvMirrorDetectTitle => '미러 속도';

  @override
  String workspaceEnvMirrorLatency(int ms) {
    return '$ms ms';
  }

  @override
  String workspaceEnvMirrorFailed(String reason) {
    return '$reason';
  }

  @override
  String get workspaceEnvErrorUnsupportedAbi => '이 기기의 아키텍처는 지원되지 않습니다.';

  @override
  String get workspaceEnvErrorArchitectureMismatch =>
      '설치된 샌드박스 아키텍처가 이 앱과 일치하지 않습니다. 계속하려면 샌드박스를 다시 설치하세요. 기존 샌드박스 파일은 보존되었습니다.';

  @override
  String get workspaceEnvErrorProotMissing => 'PRoot 바이너리가 없습니다.';

  @override
  String get workspaceEnvErrorInsufficientDisk => '샌드박스를 설치할 저장 공간이 부족합니다.';

  @override
  String get workspaceEnvErrorInsufficientDiskHint =>
      '선택한 이미지에 필요한 저장 공간을 확보한 후 다시 시도하세요.';

  @override
  String get workspaceEnvErrorNetwork => '다운로드에 실패했습니다. 연결을 확인하고 다시 시도하세요.';

  @override
  String get workspaceEnvErrorChecksumMismatch => '다운로드 파일이 손상되었습니다. 다시 시도하세요.';

  @override
  String get workspaceEnvErrorExtractFailed => '샌드박스 이미지를 압축 해제할 수 없습니다.';

  @override
  String get workspaceEnvErrorCleanupFailed =>
      '이전 샌드박스 파일을 삭제할 수 없습니다. 다시 시도하세요.';

  @override
  String get workspaceEnvCleanupIncomplete =>
      '샌드박스는 준비되었지만 일부 이전 파일을 삭제하지 못했습니다. 해당 파일은 여전히 저장 공간을 차지합니다.';

  @override
  String get workspaceEnvErrorResetFailed => '샌드박스 초기화를 완료할 수 없습니다. 다시 시도하세요.';

  @override
  String get workspaceEnvErrorPatchFailed => '샌드박스 설정을 완료할 수 없습니다.';

  @override
  String get workspaceEnvErrorRepairInterrupted =>
      '샌드박스 복구가 중단되었습니다. 기존 샌드박스는 유지되었습니다. 복구를 완료하려면 다시 시도하세요.';

  @override
  String get workspaceEnvErrorRepairTimeout =>
      '샌드박스 복구 시간이 초과되었습니다. 네트워크 연결을 확인한 후 다시 시도하세요. 기존 샌드박스는 유지되었습니다.';

  @override
  String get workspaceEnvRepairRestartBanner =>
      '제한 시간 내에 샌드박스 복구가 중지되었는지 확인하지 못했습니다. 다시 시도하기 전에 Kelivo를 완전히 종료한 후 다시 여세요. 기존 샌드박스는 유지되었습니다.';

  @override
  String get workspaceEnvErrorCancelled => '설치가 취소되었습니다.';

  @override
  String get workspaceEnvErrorGeneric => '샌드박스 설치 중 문제가 발생했습니다.';

  @override
  String get workspaceEnvChipInstall => '샌드박스 설치';

  @override
  String workspaceEnvChipInstalling(int percent) {
    return '설치 중… $percent %';
  }

  @override
  String get workspaceEnvChipInstallingIndeterminate => '설치 중…';

  @override
  String get workspaceEnvChipError => '샌드박스 오류';

  @override
  String get workspaceEnvChipRestart => '재시작 필요';

  @override
  String get workspaceEnvNativeExplanation =>
      '데스크톱에서 Kelivo는 Linux 샌드박스 대신 시스템 셸을 사용합니다.';

  @override
  String workspaceEnvNativeShellPath(String path) {
    return '셸: $path';
  }

  @override
  String get workspaceEnvNativeShellApproval => '승인 요청 모드에서는 셸 도구에 승인이 필요합니다.';

  @override
  String workspaceEnvDownloadProgress(
    String downloaded,
    String total,
    int percent,
  ) {
    return '$downloaded / $total MB ($percent%)';
  }

  @override
  String get workspaceEnvMirrorsFailed => '미러를 감지할 수 없습니다';

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
      '스킬은 SKILL.md 파일이 포함된 폴더입니다. Markdown을 붙여넣거나 .md 또는 .zip 파일을 가져오거나 GitHub URL에서 설치하세요.';

  @override
  String get skillsEmptyFormat =>
      '---\nname: my-skill\ndescription: 이 스킬이 하는 일\n---\n\n# 지침';

  @override
  String get skillsImport => '가져오기';

  @override
  String get skillsImportPaste => 'Markdown 붙여넣기';

  @override
  String get skillsImportFile => '파일에서';

  @override
  String get skillsImportGitHub => 'GitHub에서';

  @override
  String get skillsImportPasteLabel => 'SKILL.md';

  @override
  String get skillsImportPasteHint => 'YAML 프런트매터가 포함된 SKILL.md를 붙여넣으세요';

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
    return '$count회 사용됨';
  }

  @override
  String get skillsEnabled => '사용';

  @override
  String get skillsBrowseFiles => '파일 찾아보기';

  @override
  String get skillsEdit => '편집';

  @override
  String get skillsExport => '내보내기';

  @override
  String get skillsDelete => '삭제';

  @override
  String get skillsDeleteTitle => '이 스킬을 삭제할까요?';

  @override
  String skillsDeleteMessage(String name) {
    return '$name을(를) 삭제할까요? 이 작업은 되돌릴 수 없습니다.';
  }

  @override
  String get skillsUseAll => '모든 스킬 사용';

  @override
  String get skillsUseAllSubtitle => '활성화된 모든 스킬을 이 어시스턴트가 사용할 수 있습니다.';

  @override
  String get skillsDisabledHint => '여기서 사용하려면 스킬 페이지에서 이 스킬을 활성화하세요.';

  @override
  String get skillsOpenPage => '스킬 관리';

  @override
  String get skillsInheritAssistant => '어시스턴트 따르기';

  @override
  String get skillsInheritAssistantSubtitle => '이 대화의 어시스턴트와 동일한 스킬을 사용합니다.';

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
  String get terminalBindWorkspaceFirst => '먼저 작업 공간을 바인딩하세요';

  @override
  String get terminalNotAvailable => '사용할 수 없음';

  @override
  String get terminalRuntimeUnavailable => '터미널 환경이 준비되지 않았습니다';

  @override
  String get terminalRename => '이름 변경';

  @override
  String get terminalClose => '닫기';

  @override
  String get terminalClear => '지우기';

  @override
  String get terminalCloseSession => '세션 닫기';

  @override
  String get terminalCopy => '복사';

  @override
  String get terminalPaste => '붙여넣기';

  @override
  String get terminalNewSession => '새 세션';

  @override
  String get terminalMore => '더 보기';

  @override
  String get terminalNameLabel => '이름';

  @override
  String get terminalCancel => '취소';

  @override
  String get terminalSave => '저장';

  @override
  String get workspaceDeskMenuWorkspace => '작업 공간';

  @override
  String get workspaceDeskMenuSkills => '스킬';

  @override
  String get workspaceDeskBarTitle => '작업 공간';

  @override
  String get workspaceDeskBarNoWorkspace => '작업 공간 없음';

  @override
  String get workspaceDeskBarEmptyHint =>
      '툴바에서 작업 공간을 바인딩하면 여기에서 파일을 탐색할 수 있습니다';

  @override
  String get workspaceDeskBarToggle => '작업 공간 파일';

  @override
  String get workspaceDeskOpenSystemTerminal => '시스템 터미널에서 열기';

  @override
  String get workspaceDeskReveal => '파일 관리자에서 보기';

  @override
  String get workspaceDeskBarClose => '작업 공간 바 닫기';

  @override
  String get workspaceEntryBind => '작업 공간 바인딩';

  @override
  String get workspaceEntryUnbind => '바인딩 해제';

  @override
  String get workspaceEntryChange => '변경';

  @override
  String get workspaceEntrySetAssistantDefault => '어시스턴트 기본값으로 설정';

  @override
  String get workspaceEntryLocked => '잠김';

  @override
  String get workspaceEntryChangeConfirmTitle => '작업 공간을 변경할까요?';

  @override
  String get workspaceEntryUnbindConfirmTitle => '바인딩을 해제할까요?';

  @override
  String get workspaceEntryChangeConfirmBody =>
      '이 대화에서 이미 작업 공간 도구를 사용했습니다. 이전 메시지의 파일 링크가 더 이상 작동하지 않을 수 있습니다.';

  @override
  String get workspaceEntryCwd => '작업 디렉터리';

  @override
  String get workspaceEntryCwdHint => '작업 공간 루트 기준';

  @override
  String get workspaceEntryCwdInvalid => '경로가 유효하지 않거나 작업 공간을 벗어났습니다';

  @override
  String get workspaceEntryCwdMissing => '해당 디렉터리가 존재하지 않습니다';

  @override
  String get workspaceEntryCwdCreate => '생성하기';

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
  String get workspaceEntryEnvironment => '환경';

  @override
  String get workspaceEntryManage => '작업 공간 관리';

  @override
  String get workspaceEntryCreate => '새 작업 공간 만들기…';

  @override
  String get workspaceEntryDefaultWorkspace => '기본 작업 공간';

  @override
  String get workspaceEntryDefaultWorkspaceSubtitle =>
      '새 대화에서 이 작업 공간을 사용합니다. 기존 대화는 변경되지 않습니다.';

  @override
  String get workspaceEntryDefaultWorkspaceUnset => '설정되지 않음';

  @override
  String get workspaceEntryDefaultWorkspaceAutomaticSubtitle =>
      '대화에 처음 바인딩한 작업 공간이 새 대화를 위해 기억됩니다.';

  @override
  String workspaceBindingRememberedDefault(String assistant) {
    return '“$assistant”의 기본 작업 공간으로 기억되었습니다. 새 대화에서 사용됩니다.';
  }

  @override
  String workspaceBindingSuggestDefault(String assistant) {
    return '“$assistant”와의 향후 대화에서도 이 작업 공간을 사용할까요?';
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
  String get workspaceEntryTooltip => '작업 공간';

  @override
  String get workspaceEntryPickerTitle => '작업 공간 선택';

  @override
  String get settingsPageWorkspace => '작업 공간 및 환경';

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
      '세션이 아직 실행 중입니다. 닫으면 프로세스가 종료됩니다.';

  @override
  String get terminalCopiedAll => '전체 출력을 복사했습니다';

  @override
  String get terminalConfirm => '확인';

  @override
  String terminalExitCode(int code) {
    return 'exit $code';
  }

  @override
  String get workspaceMgmtNewWorkspace => '새 작업 공간';

  @override
  String get workspaceMgmtEmptyHint => '프로젝트 파일을 함께 보관할 작업 공간을 만드세요.';

  @override
  String get workspaceMgmtKindManagedTitle => '관리형 작업 공간';

  @override
  String get workspaceMgmtKindManagedSubtitle => '앱 관리 폴더, 샌드박스 읽기/쓰기';

  @override
  String get workspaceMgmtKindLinkedTitle => '연결된 폴더';

  @override
  String get workspaceMgmtKindLinkedSubtitle => '이 컴퓨터의 폴더 사용';

  @override
  String get workspaceMgmtImportFromFolder => '폴더에서 가져오기';

  @override
  String get workspaceMgmtImportFromFolderSubtitle => '폴더를 새 관리형 작업 공간으로 복사';

  @override
  String get workspaceMgmtKindSection => '유형';

  @override
  String get workspaceMgmtCreate => '만들기';

  @override
  String get workspaceMgmtShellApprovalSubtitle => '각 명령 실행 전에 확인';

  @override
  String get workspaceMgmtDefaultCwdRoot => '/';

  @override
  String get workspaceMgmtPickCwdTitle => '기본 작업 디렉터리';

  @override
  String get workspaceMgmtFolderPickerUnavailable => '폴더 선택을 사용할 수 없습니다.';

  @override
  String get workspaceMgmtImportProgressTitle => '폴더 가져오는 중';

  @override
  String get workspaceMgmtImportProgressPhase => '파일 복사 중…';

  @override
  String get workspaceMgmtImportFailed => '해당 폴더를 가져올 수 없습니다.';

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
    return '$kind · 마지막 사용 $when';
  }

  @override
  String workspaceMgmtRowDetailNever(String kind) {
    return '$kind · 사용한 적 없음';
  }

  @override
  String get workspacePreviewBack => '뒤로';

  @override
  String get workspacePreviewWrap => '줄 바꿈';

  @override
  String get workspacePreviewFontDecrease => '글자 작게';

  @override
  String get workspacePreviewFontIncrease => '글자 크게';

  @override
  String get workspacePreviewCopy => '복사';

  @override
  String get workspacePreviewRetry => '다시 시도';

  @override
  String get workspacePreviewLoadError => '이 파일을 불러올 수 없습니다.';

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
  String get workspacePreviewRevealFailed => '파일 관리자에서 이 파일을 표시할 수 없습니다.';

  @override
  String get workspacePreviewEmptyTable => '이 표는 비어 있습니다.';

  @override
  String get workspaceFilesNew => '새로 만들기';

  @override
  String get workspaceFilesFoldersFirst => '폴더 먼저';

  @override
  String get workspaceFilesSelectDirectory => '이 폴더 선택';

  @override
  String get workspaceFilesEmptyHint => '새로 만들기 또는 가져오기로 파일 추가';

  @override
  String get workspaceFilesEmptyAttachments => '아직 첨부 파일이 없습니다';

  @override
  String get workspaceFilesEmptyOutputs => '어시스턴트가 아직 파일을 생성하지 않았습니다';

  @override
  String get workspaceFilesMoveTo => '이동…';

  @override
  String workspaceFilesItemCount(int count) {
    return '$count개 항목';
  }

  @override
  String get skillsImportTooltip => '스킬 가져오기';

  @override
  String get skillsImportPasteSubtitle => 'YAML frontmatter가 포함된 SKILL.md 붙여넣기';

  @override
  String get skillsImportFileSubtitle => '.md 또는 .zip 파일 선택';

  @override
  String get skillsImportGitHubSubtitle => '저장소에서 SKILL.md 가져오기';

  @override
  String get skillsImportResolving => '저장소 확인 중…';

  @override
  String get skillsImportDownloading => '다운로드 중…';

  @override
  String get skillsImportExtracting => '압축 해제 중…';

  @override
  String get skillsImportInstalling => '설치 중…';

  @override
  String get skillsImportGitHubRepoLabel => '저장소 URL';

  @override
  String get skillsImportGitHubUrlHint =>
      'https://github.com/owner/repo 또는 owner/repo[/path]';

  @override
  String get skillsImportGitHubHelp => '저장소 루트 또는 하위 디렉터리의 SKILL.md를 지원합니다.';

  @override
  String get skillsEmptyHint =>
      '스킬은 frontmatter가 포함된 SKILL.md입니다. 가져오면 어시스턴트가 필요할 때 사용할 수 있습니다.';

  @override
  String get skillsMoreActions => '더 보기';

  @override
  String get skillsSearchClear => '지우기';

  @override
  String get skillsSessionEmpty => '활성화된 스킬이 없습니다. 먼저 스킬 라이브러리에서 스킬을 활성화하세요.';

  @override
  String get workspaceToolRunning => '실행 중';

  @override
  String workspaceToolExitCode(int code) {
    return 'exit $code';
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
    return '$count개 항목';
  }

  @override
  String workspaceToolFileMatches(int count) {
    return '$count개 일치';
  }

  @override
  String workspaceToolContentMatches(int count) {
    return '$count개 일치';
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
  String get workspaceToolSectionDiff => '차이';

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
  String get workspaceEnvEngineLocalShell => '로컬 셸';

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
  String get workspaceEnvInstalledAtLabel => '설치 시점';

  @override
  String get workspaceEnvArchLabel => '아키텍처';

  @override
  String workspaceEnvArchVersion(String arch, String version) {
    return '$arch · $version';
  }

  @override
  String get workspaceEnvBrowseSection => '탐색';

  @override
  String get workspaceEnvBrowseFiles => '파일 시스템 탐색';

  @override
  String get workspaceEnvBrowseFilesDetail => '샌드박스 내부의 전체 디렉터리 트리 보기';

  @override
  String get workspaceEnvDetectFastMirrors => '빠른 미러 감지';

  @override
  String get workspaceEnvActionsSection => '작업';

  @override
  String get workspaceEnvInfoSection => '정보';

  @override
  String get workspaceEnvInfoBody =>
      '환경은 샌드박스에서 사용하는 Linux 루트 파일 시스템입니다. 작업 공간은 별도로 저장되며 초기화해도 삭제되지 않습니다. 파일은 이 기기에 압축 해제된 rootfs에 저장됩니다.';

  @override
  String get workspaceEnvRepairDetail => '파일 재검증 및 패치';

  @override
  String get workspaceEnvUpdateCurrent => '최신 상태입니다';

  @override
  String workspaceEnvUpdateAvailableShort(String version) {
    return '업데이트 가능: $version';
  }

  @override
  String get workspaceEnvResetConfirmMessage =>
      '이 작업은 전체 Linux 환경과 그 안에 설치된 패키지를 삭제합니다. 작업 공간 파일은 영향을 받지 않습니다.';

  @override
  String get workspaceEnvRestartDoneBanner =>
      '초기화가 완료되었습니다. 설치를 완료하려면 앱을 다시 시작하세요.';

  @override
  String get workspaceEnvPathCopied => '경로가 복사되었습니다';

  @override
  String get workspaceEnvUseMirrorSubtitle => '선택한 미러를 샌드박스에 기록';

  @override
  String get workspaceEnvRegionGlobal => '글로벌';

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
  String get workspaceEnvApplySuccess => '미러가 적용되었습니다';

  @override
  String get workspaceEnvApplyFailed => '미러를 적용할 수 없습니다';

  @override
  String get workspaceEnvRestoreSuccess => '공식 소스가 복원되었습니다';

  @override
  String get workspaceEnvMirrorsTested => '가장 빠른 미러가 적용되었습니다';

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
      '명령은 샌드박스 없이 이 컴퓨터에서 직접 실행되며, 이 대화에 전체 액세스가 활성화되어 있지 않으면 승인이 필요합니다.';

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
  String get workspaceEnvMirrorNameTuna => '칭화 TUNA';

  @override
  String get workspaceEnvMirrorNameAlibaba => '알리바바';

  @override
  String get workspaceEnvMirrorNameUstc => 'USTC';

  @override
  String get workspaceEnvMirrorNameHuawei => '화웨이';

  @override
  String get workspaceEnvMirrorNameTencent => '텐센트';

  @override
  String get workspaceEnvMirrorNameNetease => '넷이즈';

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
  String get workspaceFilesEmptyPickerHint => '새 폴더로 하위 폴더 추가';

  @override
  String get skillsDetailBodyEmpty => '아직 스킬 본문이 없습니다';

  @override
  String skillsDetailBodyTooLarge(String size) {
    return '파일이 너무 커서 미리 볼 수 없습니다($size).';
  }

  @override
  String get workspaceEnvSizeTimeout => '시간 초과';

  @override
  String get workspaceEnvInfoCopied => '환경 정보가 복사되었습니다';

  @override
  String get workspacePreviewEmptyFile => '파일이 비어 있습니다';

  @override
  String get workspacePreviewEmptyHint => '미리 볼 내용이 없습니다.';

  @override
  String get workspacePreviewRevealInExplorer => '파일 탐색기에서 보기';

  @override
  String get workspacePreviewRevealInFileManager => '파일에서 보기';

  @override
  String workspaceBindingSetAssistantDefault(String assistant) {
    return '「$assistant」의 기본 작업 공간으로 설정되었습니다';
  }

  @override
  String get storageSpaceCategoryWorkspaceFiles => '작업 공간 파일';

  @override
  String get storageSpaceCategoryWorkspaceFilesHint => '관리되는 작업 공간에 저장된 파일입니다.';

  @override
  String get storageSpaceCategorySandboxEnvironment => '샌드박스 환경';

  @override
  String get storageSpaceCategorySandboxEnvironmentHint =>
      '샌드박스 설치 및 루트 파일 시스템입니다.';

  @override
  String get storageSpaceCategorySkills => '스킬';

  @override
  String get storageSpaceCategorySkillsHint => '설치된 스킬 파일입니다.';

  @override
  String get storageSpaceCategorySessionFiles => '대화 파일';

  @override
  String get storageSpaceCategorySessionFilesHint => '대화별 첨부 파일 및 출력입니다.';

  @override
  String get storageSpaceManageSkills => '스킬 관리';

  @override
  String get storageSessionFilesCleanOrphans => '연결된 대화가 없는 대화 파일 정리';

  @override
  String storageSessionFilesCleanOrphansHint(String size) {
    return '더 이상 대화가 없는 세션 폴더를 삭제합니다. 확보 가능: $size.';
  }

  @override
  String get workspaceDesktopFolderPath => '폴더 경로';

  @override
  String get workspaceDesktopFolderMissing => '기존 폴더를 선택하거나 절대 경로를 입력하세요.';

  @override
  String get workspaceDesktopManagedHint =>
      'Kelivo가 이 프로젝트를 위한 폴더를 생성하고 관리합니다.';

  @override
  String get workspaceDesktopHostHint => '파일과 명령이 이 컴퓨터에서 실행됩니다.';

  @override
  String get workspaceDesktopSearch => '작업 공간 검색';

  @override
  String get workspaceDesktopNoResults => '일치하는 작업 공간이 없습니다';

  @override
  String get workspaceEnvDependencies => '환경 프리셋';

  @override
  String get workspaceEnvDependenciesDetail =>
      '공유 샌드박스에 도구를 설치합니다. 모든 작업 공간에서 사용할 수 있습니다.';

  @override
  String get workspaceEnvDependencyPython => 'Python, pip 및 가상 환경';

  @override
  String get workspaceEnvDependencyNode => 'Node.js 및 npm';

  @override
  String get workspaceEnvDependencyGit => '저장소 복제 및 버전 관리';

  @override
  String get workspaceEnvDependencySsh => 'SSH, SCP, SFTP 및 키 생성';

  @override
  String get workspaceEnvDependencyNetwork => '네트워크 도구';

  @override
  String get workspaceEnvDependencyArchive => '압축 도구';

  @override
  String get workspaceEnvDependencyInstalled => '설치됨';

  @override
  String get workspaceEnvDependencyUnknown => '확인 안 됨';

  @override
  String get workspaceEnvDependencyChecking => '도구 확인 중…';

  @override
  String get workspaceEnvDependencyInstalling => '설치 중…';

  @override
  String get workspaceEnvDependencyCheckFailed =>
      '도구를 확인하지 못했습니다. 새로 고쳐 다시 시도하세요.';

  @override
  String get workspaceEnvDependencyInstallFailed =>
      '설치가 완료되지 않았습니다. 로그를 확인하거나 패키지 소스를 변경한 후 다시 시도하세요.';

  @override
  String get workspaceEnvDependencyLog => '설치 로그';

  @override
  String get workspaceEnvDependencyRefresh => '도구 상태 새로 고침';

  @override
  String get workspaceEnvDependencyReadyFirst => '이 도구들을 추가하려면 먼저 샌드박스를 설치하세요.';

  @override
  String get workspaceEnvDependencySources => '패키지 소스';

  @override
  String get workspaceEnvDependencySourcesDetail =>
      '프리셋은 선택한 apt/apk 소스로 설치합니다. pip 및 npm 소스는 이후 설치하는 패키지에 적용됩니다.';

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
      '릴리스 디렉터리 또는 전체 아카이브 URL을 입력하세요. 아카이브는 선택한 시스템, 버전 및 기기 아키텍처와 일치해야 합니다.';

  @override
  String get workspaceEnvDownloadInvalidUrl => '유효한 HTTP 또는 HTTPS URL을 입력하세요.';

  @override
  String get workspaceEnvDownloadVerified =>
      '다운로드 후 선택한 이미지의 공식 SHA-256으로 검증합니다. 패키지 소스는 별도로 구성할 수 있습니다.';

  @override
  String get workspaceEnvDownloadStart => '다운로드 및 설치';

  @override
  String get workspaceEnvDownloadSave => '소스 저장';

  @override
  String get workspaceToolsTitle => '도구';

  @override
  String get workspaceToolsDescription =>
      '이 작업 공간의 대화에서 사용할 수 있는 도구를 선택하세요. 변경 사항은 자동으로 저장됩니다.';

  @override
  String get workspaceToolHelpShell => '작업 공간 환경에서 명령을 실행합니다.';

  @override
  String get workspaceToolHelpRead => '줄 번호와 페이지 넘김으로 파일을 읽습니다.';

  @override
  String get workspaceToolHelpViewImage => '모델이 작업 공간의 이미지를 확인할 수 있게 합니다.';

  @override
  String get workspaceToolHelpWrite => '파일을 생성하거나 내용을 덮어씁니다.';

  @override
  String get workspaceToolHelpEdit => '기존 파일의 특정 텍스트를 바꿉니다.';

  @override
  String get workspaceToolHelpList => '디렉터리와 그 항목을 탐색합니다.';

  @override
  String get workspaceToolHelpGlob => '파일 이름이나 경로 패턴으로 파일을 찾습니다.';

  @override
  String get workspaceToolHelpGrep => '파일 내부의 텍스트를 검색합니다.';

  @override
  String get workspaceEnvVariablesTitle => '환경 변수';

  @override
  String get workspaceEnvVariablesEntryDetail => '명령에 사용할 변수와 출력 개인정보 보호 설정';

  @override
  String get workspaceEnvVariablesEmpty =>
      '아직 변수가 없습니다. 도구에 필요한 API 키나 기타 구성을 추가하세요.';

  @override
  String get workspaceEnvVariablesScope =>
      '모든 작업 공간에서 공유됩니다. 변경 사항은 새 Agent 명령과 새 인앱 터미널 세션에 적용되며, 기존 세션은 다시 열어야 적용됩니다. 외부 시스템 터미널은 자체 환경을 사용합니다.';

  @override
  String get workspaceEnvPrivacyMode => '개인정보 보호 모드';

  @override
  String get workspaceEnvPrivacyDetail =>
      '명령은 실제 값을 사용할 수 있습니다. 작업 공간 도구 출력이 모델로 전송되기 전에 5자 이상인 일치하는 값이 [REDACTED]로 바뀝니다. 로컬 로그는 원문을 유지합니다. 흔한 플래그와 숫자를 잘못 바꾸지 않도록 더 짧은 값은 가리지 않습니다.';

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
      '이름에는 영문자, 숫자, 밑줄을 사용하며 숫자로 시작할 수 없습니다. 이름은 대소문자를 구분합니다. 명령에서 \$NAME으로 변수를 참조하세요.';

  @override
  String get workspaceEnvVariableInvalidName => '유효한 변수 이름을 입력하세요.';

  @override
  String get workspaceEnvVariableInvalidValue => 'NUL 문자 없이 비어 있지 않은 값을 입력하세요.';

  @override
  String get workspaceEnvVariableDuplicate => '같은 이름의 변수가 이미 있습니다.';

  @override
  String get workspaceEnvVariablesSaveFailed => '환경 설정을 저장하지 못했습니다. 다시 시도하세요.';

  @override
  String get incomingShareTitle => '공유된 콘텐츠';

  @override
  String get incomingShareReplaceDraft =>
      '입력 상자에 보내지 않은 내용이 있습니다. 공유된 콘텐츠로 바꾸고 새 대화를 시작할까요?';

  @override
  String get incomingShareFailed =>
      '일부 공유 콘텐츠를 가져오지 못했습니다. 파일 접근 권한과 사용 가능한 저장 공간을 확인하세요. 한 번에 최대 32개 파일을 공유할 수 있습니다.';

  @override
  String get incomingShareImporting => '가져오는 중';

  @override
  String get incomingShareMoveTo => '이동…';

  @override
  String get incomingShareNewChat => '새 대화';

  @override
  String get incomingShareMoveHint =>
      '이 초안과 첨부 파일을 다른 대화로 이동합니다. 아무것도 자동으로 전송되지 않습니다.';

  @override
  String get incomingShareNoConversations => '일치하는 대화 없음';

  @override
  String get chatInputBarRemoveAttachment => '첨부 파일 제거';

  @override
  String get incomingShareMoveFailed => '대화를 전환하지 못했습니다. 초안은 유지되었습니다.';

  @override
  String attachmentRequiresWorkspace(String name) {
    return '「$name」은(는) 일반 대화에서 직접 읽을 수 없습니다. 작업 공간을 연결하고 파일 도구를 활성화하거나, 초안을 작업 공간이 있는 대화로 이동하세요.';
  }

  @override
  String get storageSessionFilesUnlinked => '연결되지 않은 대화';

  @override
  String get workspaceExternalMount => '외부 폴더 마운트';

  @override
  String get workspaceExternalMountSubtitle =>
      '선택한 폴더는 /mounts/<name>에 마운트되어 모든 작업 공간에서 공유됩니다. AI 도구, Shell 및 파일 브라우저에서 접근할 수 있습니다. 최대 10개 폴더.';

  @override
  String get workspaceExternalStorageTitle => '파일 접근 허용';

  @override
  String get workspaceExternalStorageMessage =>
      '작업 공간과 Shell에서 외부 폴더를 읽고 쓰려면 Android 설정에서 Kelivo의 파일 관리 권한을 허용하세요. Android 11 이상에서는 \'모든 파일 접근 권한\'을 켠 다음, 마운트할 기기 내 폴더를 선택하세요.';

  @override
  String get workspaceExternalGrantAccess => '권한 허용';

  @override
  String get workspaceExternalLocalOnly =>
      'Android는 기기 내 폴더만 마운트할 수 있습니다. 이 문서 공급자는 Shell에서 접근할 수 있는 로컬 폴더를 제공하지 않습니다.';

  @override
  String get workspaceExternalUnavailable =>
      '외부 폴더를 사용할 수 없습니다. 저장소 연결과 접근 권한을 확인한 뒤 폴더를 다시 선택하여 접근을 복원하세요.';

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
  String get workspaceMountReadWrite => '읽기/쓰기';

  @override
  String get workspaceMountAllowWrite => '쓰기 허용';

  @override
  String get workspaceMountPermissionsHint =>
      'AI 파일 도구와 파일 브라우저는 이 설정을 따릅니다. Shell은 일반적인 파일 명령만 검사하며, 임의 스크립트는 이를 우회할 수 있습니다. 마운트 변경 사항을 저장하면 실행 중인 명령과 터미널 세션이 중지됩니다.';

  @override
  String get workspaceMountBrowse => '파일 탐색';

  @override
  String get workspaceMountUnmount => '마운트 해제';

  @override
  String get workspaceMountUnmountMessage =>
      '이 마운트를 제거할까요? 원본 폴더와 그 안의 파일은 유지됩니다.';

  @override
  String get workspaceMountInactive => '사용 불가 — 폴더를 다시 선택하세요';

  @override
  String get workspaceMountInvalidName =>
      '이름은 최대 64자이며 슬래시, 콜론, 제어 문자를 포함할 수 없고 . 또는 ..일 수 없습니다.';

  @override
  String get workspaceMountDuplicate => '같은 이름의 마운트가 이미 있습니다.';

  @override
  String get workspaceMountLimit =>
      '최대 10개의 폴더를 마운트할 수 있습니다. 추가하려면 먼저 마운트를 제거하세요.';

  @override
  String get workspaceMountOverlap =>
      '이 폴더는 기존 마운트와 겹칩니다. 권한이 모호해지지 않도록 다른 폴더를 선택하세요.';

  @override
  String get workspaceMountTargetOccupied =>
      '/mounts 아래의 마운트 대상에 이미 로컬 파일이 있습니다. 다른 마운트 이름을 선택하거나 해당 파일을 먼저 옮기세요. 삭제된 파일은 없습니다.';

  @override
  String get workspaceEnvSystemImage => '시스템 이미지';

  @override
  String get workspaceEnvDistribution => '배포판';

  @override
  String get workspaceEnvSystemVersion => '버전';

  @override
  String get workspaceEnvLocalImage => '로컬 이미지';

  @override
  String get workspaceEnvChooseImage => 'rootfs 아카이브 선택';

  @override
  String get workspaceEnvLocalImageHint =>
      '루트 파일 시스템 아카이브(.tar.gz, .tar.xz, .tar)를 가져오세요. ISO나 디스크 이미지는 지원하지 않습니다. 이 기기의 CPU 아키텍처와 일치해야 하며 /bin/sh를 포함해야 합니다. 시스템과 버전은 압축 해제 후 자동으로 감지됩니다.';

  @override
  String get workspaceEnvImportImage => '이미지 가져오기';

  @override
  String get workspaceEnvInvalidImage =>
      '이 기기에 맞는 유효한 rootfs 아카이브를 선택하세요. CPU 아키텍처가 일치하는 실행 가능한 /bin/sh가 포함되어야 합니다.';

  @override
  String get workspaceEnvReplaceSystem => '시스템 교체';

  @override
  String get workspaceEnvReplaceSystemHint =>
      '교체하면 현재 환경 내의 패키지와 파일이 대체되고 실행 중인 명령과 터미널 세션이 중지됩니다. 작업 공간, 채팅 파일, 외부 폴더는 유지됩니다. 새 이미지 준비에 실패하면 현재 환경이 보존됩니다.';

  @override
  String get workspaceEnvProotOptions => 'PRoot 옵션';

  @override
  String get workspaceEnvShellPath => 'Shell 경로';

  @override
  String get workspaceEnvShellAutomatic => '자동';

  @override
  String get workspaceEnvShellHint =>
      '비워 두면 /bin/bash를 사용하고, 없으면 /bin/sh를 사용합니다. 사용자 지정 Shell은 환경 내 절대 경로여야 합니다.';

  @override
  String get workspaceEnvProotArguments => '추가 PRoot 인수';

  @override
  String get workspaceEnvProotArgumentsHint =>
      '한 줄에 인수 하나씩, Shell 따옴표 없이 입력하세요. 예를 들어 -k와 5.10.0을 각각 다른 줄에 두거나 --kernel-release=5.10.0을 사용하세요. 변경 사항은 새 명령과 터미널 세션에 적용됩니다.';

  @override
  String get workspaceEnvProotInvalid =>
      '유효한 Shell 절대 경로를 입력하고 PRoot 인수를 한 줄에 하나씩 입력하세요.';

  @override
  String get workspaceFileMissing => '파일이 더 이상 존재하지 않습니다';

  @override
  String get workspaceFilePreviewUnavailable => '미리보기를 사용할 수 없음';

  @override
  String get workspaceToolRelatedFiles => '관련 파일';

  @override
  String get workspaceToolFilesTruncated => '일부 파일만 표시됩니다.';

  @override
  String get displaySettingsPageShowProducedFilesTitle => '답변 아래에 파일 표시';

  @override
  String get displaySettingsPageShowProducedFilesSubtitle =>
      '도구가 생성하거나 수정한 파일을 답변 아래에 표시합니다.';

  @override
  String get defaultModelPagePerChatModelTitle => '대화별 모델';

  @override
  String get defaultModelPagePerChatModelSubtitle =>
      '켜면 대화에서 모델을 선택할 때 해당 대화에만 적용됩니다. 끄면 현재 어시스턴트의 모델이 변경되어 해당 어시스턴트를 사용하는 모든 대화에 적용됩니다.';

  @override
  String get googleFontsTitle => 'Google Fonts';

  @override
  String get googleFontsRefresh => '글꼴 목록 새로 고침';

  @override
  String get googleFontsSearchHint => '글꼴 또는 언어 검색';

  @override
  String get googleFontsHint =>
      '일반 글꼴을 다운로드하면 미리 보고 적용할 수 있습니다. 설치된 글꼴은 오프라인에서도 작동합니다. 카탈로그: Expo Google Fonts, 다운로드: Google Fonts.';

  @override
  String get googleFontsNoResults => '일치하는 글꼴 없음';

  @override
  String get googleFontsFailed =>
      '글꼴을 불러오거나 다운로드하거나 적용할 수 없습니다. 연결을 확인한 후 다시 시도하세요.';

  @override
  String get googleFontsDownloading => '글꼴 다운로드 중…';

  @override
  String get googleFontsPreview => '다람쥐 헌 쳇바퀴에 타고파 0123456789 · 글꼴 미리보기';

  @override
  String get googleFontsLicense => '글꼴 라이선스';

  @override
  String get assistantEditLocationPermissionSettingsMessage =>
      '위치 권한이 차단되어 있습니다. 시스템 설정에서 위치 접근을 허용한 후 이 도구를 다시 켜세요.';

  @override
  String get healthDataSettingsCategoryReproductive => '생식 건강';

  @override
  String get healthDataSettingsTypeMenstrualFlowTitle => '월경량';

  @override
  String get healthDataSettingsTypeMenstrualFlowSubtitle =>
      '최근 90일 동안 기록된 월경량 및 주기 시작일';

  @override
  String get assistantEditGradientBackgroundTitle => '그라데이션 배경';

  @override
  String get assistantEditGradientStaticTitle => '정적 모드';

  @override
  String get assistantEditGradientStaticDescription =>
      '긴 대화와 스트리밍 중에 전력을 절약합니다.';

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
  String get backgroundFailed => '생성 실패. 자세한 내용은 대화를 여세요.';

  @override
  String get backgroundCancelled => '생성 취소됨';

  @override
  String get backgroundInterrupted => '백그라운드 생성이 중단되었습니다. 계속하려면 대화를 여세요.';

  @override
  String get backgroundRequesting => '연결 중';

  @override
  String get backgroundGenerating => '답변 생성 중';

  @override
  String get backgroundThinking => '생각 중';

  @override
  String get backgroundToolRunning => '도구 실행 중';

  @override
  String get backgroundRetrying => '재시도 대기 중';

  @override
  String get backgroundWorking => '처리 중';

  @override
  String get backgroundTasks => '작업';

  @override
  String get backgroundStopTasks => '작업 중지';

  @override
  String get backgroundOpenChat => '대화 열기';

  @override
  String get backgroundAndroidEnabled => '백그라운드 생성';

  @override
  String get backgroundAndroidEnabledDetail =>
      '잠금, 백그라운드 전환 또는 최근 앱에서 제거된 후에도 현재 작업을 계속 실행합니다. 작업 실행 중에는 시스템 알림이 필요합니다.';

  @override
  String get backgroundIosEnabled => '향상된 백그라운드 실행';

  @override
  String get backgroundIosEnabledDetail =>
      '현재 작업을 완료할 시간을 요청합니다. 추가 백그라운드 지원을 위해 위치 또는 무음 오디오를 별도로 활성화하세요.';

  @override
  String get backgroundNotifications => '작업 알림';

  @override
  String get backgroundNotificationsDetail =>
      '현재 보고 있는 대화 외부에서 작업이 완료되거나 실패하면 알립니다. Android의 필수 상시 알림은 제어하지 않습니다.';

  @override
  String get backgroundPrivacy => '작업 상태 개인정보 보호';

  @override
  String get backgroundPrivacyDetail =>
      '알림 및 실시간 상태에서 대화 제목과 도구 세부 정보를 숨깁니다. 일반 상태, 작업 수, 경과 시간만 표시됩니다.';

  @override
  String get backgroundLiveActivities => '실시간 활동';

  @override
  String get backgroundLiveActivitiesDetail =>
      '잠금 화면과 다이나믹 아일랜드에 현재 작업을 표시합니다. 사용 가능 여부와 표시 위치는 시스템에 따라 다릅니다.';

  @override
  String get backgroundOverlay => '플로팅 작업 상태';

  @override
  String get backgroundOverlayDetail =>
      '다른 앱 위에 드래그 가능한 작업 캡슐을 표시합니다. 탭하면 대화가 열리고, 닫으면 캡슐만 숨겨집니다.';

  @override
  String get backgroundLiveUpdates => '실시간 업데이트';

  @override
  String get backgroundLiveUpdatesDetail =>
      '지원되는 기기에서 Android 16 실시간 업데이트를 사용합니다. 승격된 알림은 플로팅 캡슐보다 우선합니다.';

  @override
  String get backgroundLocation => '위치 보조 실행';

  @override
  String get backgroundLocationDetail =>
      '백그라운드 작업 중에 대략적인 위치 업데이트를 사용합니다. 좌표는 저장되거나 AI 서비스로 전송되지 않습니다. 향상된 백그라운드 실행과 위치 권한이 필요합니다.';

  @override
  String get backgroundSilentAudio => '무음 오디오 유지';

  @override
  String get backgroundSilentAudioDetail =>
      '백그라운드 작업이 실행되는 동안 무음 오디오를 재생합니다. 녹음 및 음성 재생에 양보합니다. 향상된 백그라운드 실행이 필요하며 마이크 권한은 필요하지 않습니다.';

  @override
  String get backgroundSpeech => '백그라운드 읽기';

  @override
  String get backgroundSpeechDetail =>
      '잠금 화면 또는 백그라운드 상태에서도 시스템 및 네트워크 읽기를 계속합니다. 끄면 백그라운드로 전환될 때 읽기가 일시 중지됩니다.';

  @override
  String get backgroundFinishVisibility => '완료 상태 유지 시간';

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
      'Android 캡슐 및 iOS 잠금 화면 완료 카드에 적용됩니다. 앱으로 돌아오면 완료 상태가 정리되며 최대 15분까지 유지됩니다. 취소 시 즉시 닫힙니다.';

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
      '배터리 사용을 제한 없이 허용하면 백그라운드 작업이 더 안정적으로 실행됩니다.';

  @override
  String get backgroundAutostart => '자동 시작 및 백그라운드 실행';

  @override
  String get backgroundAutostartDetail =>
      '기기의 자동 시작 및 백그라운드 제한을 직접 확인하세요. Android는 이러한 제조사 설정의 권한 상태를 안정적으로 조회할 수 없습니다.';

  @override
  String get backgroundLocationPermission => '위치 권한';

  @override
  String get backgroundLocationAlways => '백그라운드 위치 허용';

  @override
  String get backgroundLocationAlwaysDetail =>
      '백그라운드 위치에 대해 \'항상 허용\' 권한을 부여할 수 있습니다. 이 항목을 선택할 때만 권한을 요청합니다.';

  @override
  String get backgroundSystemSettings => '앱 시스템 설정';

  @override
  String get backgroundPermissionGranted => '허용됨';

  @override
  String get backgroundPermissionDenied => '허용되지 않음';

  @override
  String get backgroundPermissionLimited => '앱 사용 중';

  @override
  String get backgroundPermissionUnknown => '직접 확인 필요';

  @override
  String get backgroundPermissionNotDetermined => '요청 안 함';

  @override
  String get backgroundRuntimeTitle => '현재 상태';

  @override
  String get backgroundRuntimeActive => '실행 중';

  @override
  String get backgroundRuntimeIdle => '실행 안 함';

  @override
  String get backgroundLocationActive => '백그라운드 위치';

  @override
  String get backgroundAudioActive => '무음 오디오';

  @override
  String get backgroundActivityActive => '실시간 활동';

  @override
  String get backgroundOverlayActive => '플로팅 창';

  @override
  String get backgroundLastError => '최근 중단 또는 오류';

  @override
  String get backgroundNoError => '기록 없음';

  @override
  String get backgroundUnsupported => '이 기기에서 지원되지 않거나 시스템 설정에서 허용되지 않음';

  @override
  String get backgroundIosLimit =>
      '백그라운드 실행은 iOS가 제어하며, 실시간 활동만으로는 앱이 계속 실행되지 않습니다. 강제 종료하면 생성이 중단되고 실시간 상태 정리가 앱을 다시 열 때까지 지연될 수 있습니다.';

  @override
  String get backgroundAndroidLimit =>
      '작업이 중단되면 알림, 배터리 및 제조사 백그라운드 설정을 확인하세요. 강제 중지나 시스템 프로세스 종료로 인해 생성이 중단될 수 있습니다.';

  @override
  String get backgroundStale => '상태가 업데이트되지 않았습니다. 앱을 열어 확인하세요.';

  @override
  String get backgroundIconError => '이 이미지를 가져올 수 없습니다. 다른 이미지를 선택하세요.';

  @override
  String get backgroundNotificationChannels => '알림 채널';

  @override
  String get backgroundCompletionChannel => '작업 완료 알림 채널';

  @override
  String get backgroundOngoingChannel => '작업 실행 알림 채널';

  @override
  String get backgroundOverlayAppearance => '플로팅 창 모양';

  @override
  String get backgroundOverlayAppearanceDetail => '크기, 아이콘, 진행 링 및 표시 내용';

  @override
  String get backgroundOverlayPreviewHint => '드래그하여 이동 · 탭하여 대화 열기 · 길게 눌러 닫기';

  @override
  String get backgroundOverlayCard => '정보 카드';

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
  String get backgroundOverlayProgressSize => '진행 링 지름';

  @override
  String get backgroundOverlayProgressStroke => '진행 링 두께';

  @override
  String get backgroundOverlayContent => '표시할 내용';

  @override
  String get backgroundOverlayShowProgress => '진행 링 표시';

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
  String get backgroundOverlayReset => '기본 모양으로 복원';

  @override
  String get mcpStdioEnvironmentRequired =>
      '모바일에서 STDIO를 사용하려면 먼저 작업 공간 환경을 설치하세요.';

  @override
  String get mcpArgumentsHint =>
      '인수는 공백으로 구분하고, 공백이 포함된 값은 따옴표로 감싸세요. 빈 인수는 \'\'로 입력하세요.';

  @override
  String get mcpArgumentsInvalid => '인수의 따옴표가 닫혔는지, 끝에 미완성 이스케이프가 있는지 확인하세요.';

  @override
  String get mcpImportEnvironment => '환경에서 가져오기';

  @override
  String get mcpEnvironmentEmpty => '환경 변수가 없습니다. 환경 설정에서 먼저 추가하세요.';

  @override
  String get mcpEnvironmentHint =>
      '환경 변수를 상속합니다. 변수를 가져오면 이 서버에 한해 값을 변경할 수 있습니다.';

  @override
  String get mcpImportJson => 'JSON 가져오기';

  @override
  String get mcpImportJsonHint =>
      'Claude Desktop 또는 Cursor의 MCP 구성을 붙여넣으세요. 미리 본 후 서버를 추가하며 기존 구성은 덮어쓰지 않습니다.';

  @override
  String get mcpImportPaste => '클립보드에서 붙여넣기';

  @override
  String get mcpImportPreview => '미리 보기';

  @override
  String get mcpImportConfirm => '가져오기';

  @override
  String get startupRecoverySnapshotTitle => '로컬 사본에서 복구';

  @override
  String get startupRecoverySnapshotBody =>
      '데이터베이스를 열 수 없더라도 이 기기의 스냅샷을 선택해 대화와 설정을 복구할 수 있습니다. Kelivo를 제거하지 마세요. 제거하면 이 스냅샷도 함께 삭제됩니다.';

  @override
  String get startupRecoverySnapshotEmpty =>
      '이 기기에서 데이터베이스 스냅샷을 찾지 못했습니다. 다른 복구 작업을 시도하기 전에 먼저 데이터를 내보내세요.';

  @override
  String get startupRecoverySnapshotButton => '복구할 사본 선택';

  @override
  String startupRecoverySnapshotConfirm(String when) {
    return '대화와 설정을 $when 스냅샷으로 복구할까요? 이 스냅샷 이후의 변경 사항은 포함되지 않습니다. 기존 첨부 파일과 스냅샷은 유지되며, 복구를 완료하려면 Kelivo가 다시 시작됩니다.';
  }

  @override
  String startupRecoverySnapshotFailed(String reason) {
    return '스냅샷 복구를 준비할 수 없습니다: $reason';
  }

  @override
  String get startupRecoverySnapshotReady =>
      '스냅샷이 준비되었습니다. 복구를 완료하려면 Kelivo를 다시 시작하세요.';

  @override
  String get scheduledTasksTitle => '예약 작업';

  @override
  String get scheduledTasksDescription =>
      '지정한 시간에 작업을 자동으로 실행합니다. 새 대화 시작, 이어서 질문, 다시 실행을 지원합니다.';

  @override
  String get scheduledTasksEmpty => '시간에 맡기는 하루';

  @override
  String get scheduledTasksEmptyDetail =>
      '아침 브리핑, 매일 회고 등 정기적으로 실행하고 싶은 작업을 추가하세요.';

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
  String get scheduledTasksPromptHint => '어시스턴트가 무엇을 하면 좋을까요?';

  @override
  String get scheduledTasksAssistant => '어시스턴트';

  @override
  String get scheduledTasksChooseAssistant => '어시스턴트 선택';

  @override
  String get scheduledTasksAssistantMissing => '어시스턴트를 사용할 수 없음';

  @override
  String get scheduledTasksTime => '시간';

  @override
  String get scheduledTasksTimeHint => '24시간 형식, 예: 08:00';

  @override
  String get scheduledTasksRepeat => '반복';

  @override
  String get scheduledTasksEveryDay => '매일';

  @override
  String get scheduledTasksWeekdays => '평일';

  @override
  String get scheduledTasksEnabled => '사용';

  @override
  String get scheduledTasksPermission => '알람 및 리마인더';

  @override
  String get scheduledTasksPermissionDetail =>
      '정확한 알람을 허용해야 지정한 시간에 작업이 실행됩니다. 권한이 부여될 때까지 사용 설정된 작업은 대기합니다.';

  @override
  String get scheduledTasksPermissionAction => '허용';

  @override
  String get scheduledTasksReliability =>
      '더 안정적인 실행을 위해 배터리 설정에서 Kelivo를 제한 없이 사용하도록 설정하세요. 앱을 강제 중지하면 다시 열 때까지 알람이 취소됩니다. 놓친 실행은 건너뛰며, 작업은 기기 시간대를 따릅니다.';

  @override
  String get scheduledTasksExecutionDetail =>
      '결과는 대화에 저장됩니다. 완료 알림에 답변 미리보기가 표시되며 탭하면 대화가 열립니다. 실행은 10분 후 또는 사용자 입력이나 도구 승인이 필요할 때 중지됩니다.';

  @override
  String get scheduledTasksRunNow => '지금 실행';

  @override
  String get scheduledTasksHistory => '실행 기록';

  @override
  String get scheduledTasksNoRuns => '아직 실행 기록이 없습니다';

  @override
  String get scheduledTasksRunning => '실행 중';

  @override
  String get scheduledTasksCompleted => '완료됨';

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
      '이 일정과 실행 기록을 삭제할까요? 이미 생성된 대화는 유지됩니다.';

  @override
  String get scheduledTasksSave => '저장';

  @override
  String get scheduledTasksCancel => '취소';

  @override
  String get scheduledTasksInvalid =>
      '이름, 프롬프트, 어시스턴트를 입력하고 사용자 지정 일정은 요일을 하나 이상 선택하세요.';

  @override
  String get scheduledTasksLoading => '불러오는 중…';

  @override
  String get scheduledTasksOpenChat => '대화 보기';

  @override
  String get scheduledTasksNeedsInput =>
      '사용자 입력이나 도구 승인이 필요하여 중지되었습니다. 대화를 열어 계속하세요.';

  @override
  String get scheduledTasksTimeout => '실행 시간 제한에 도달했습니다.';

  @override
  String get scheduledTasksProcessTerminated => 'Android에서 이전 실행을 중지했습니다.';

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
  String get scheduledTasksFollowUp => '이어서 질문';

  @override
  String get scheduledTasksRegenerate => '다시 실행';

  @override
  String get scheduledTasksChat => '대화';

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
  String get scheduledTasksActiveWindow => '활성 기간';

  @override
  String get scheduledTasksStartDate => '시작 날짜';

  @override
  String get scheduledTasksEndDate => '종료 날짜';

  @override
  String get scheduledTasksActiveWindowDetail =>
      '종료일을 포함한 이 날짜 범위 내에서만 실행됩니다. 날짜를 설정하지 않으면 제한이 없습니다.';

  @override
  String get scheduledTasksDate => '날짜';

  @override
  String get scheduledTasksDateUnrestricted => '제한 없음';

  @override
  String get scheduledTasksClear => '지우기';

  @override
  String get scheduledTasksSearch => '검색';

  @override
  String get scheduledTasksNoTargets => '이 어시스턴트에 해당하는 항목이 없습니다';

  @override
  String get scheduledTasksFutureDate => '미래의 실행 날짜와 시간을 선택하세요.';

  @override
  String get scheduledTasksDateRangeInvalid => '종료 날짜는 시작 날짜와 같거나 이후여야 합니다.';

  @override
  String get scheduledTasksRegenerateDetail =>
      '원래 컨텍스트를 사용하여 선택한 질문에 대한 새 답변을 생성합니다. 기존 답변과 이후 메시지는 유지됩니다.';

  @override
  String get scheduledTasksSaving => '저장 중…';

  @override
  String get scheduledTasksFinished => '일정 종료됨';

  @override
  String get scheduledTasksModelMissing =>
      '선택한 모델을 사용할 수 없습니다. 이 작업을 편집하여 다른 모델을 선택하세요.';

  @override
  String get scheduledTasksChatMissing => '대화를 사용할 수 없거나 다른 어시스턴트에 속해 있습니다.';

  @override
  String get scheduledTasksMessageMissing => '선택한 질문을 더 이상 사용할 수 없습니다.';

  @override
  String get scheduledTasksChatBusy => '이 대화가 답변을 생성 중입니다. 예약된 실행을 건너뛰었습니다.';

  @override
  String get scheduledTasksDesktopEmpty => '예약된 작업 없음';

  @override
  String get scheduledTasksDesktopReliability =>
      '작업은 Kelivo가 실행 중일 때만 실행되며, 최소화되거나 시스템 트레이에 있을 때도 포함됩니다. 앱 종료 또는 컴퓨터 절전 중 놓친 시간은 건너뜁니다. Kelivo는 자동으로 시작되지 않습니다.';

  @override
  String get scheduledTasksDesktopExecutionDetail =>
      '결과는 대화에 저장됩니다. 작업의 실행 기록에서 열 수 있습니다. 실행은 10분 후 또는 사용자 입력이나 도구 승인이 필요할 때 중지됩니다.';

  @override
  String get worldBookStickyLabel => '고정 (메시지 수)';

  @override
  String get worldBookStickyHint =>
      '트리거 후 N개의 메시지 동안 이 항목을 활성 상태로 유지합니다. 반복 일치는 연장하지 않습니다. 0은 이 효과를 비활성화합니다.';

  @override
  String get worldBookCooldownLabel => '쿨다운 (메시지 수)';

  @override
  String get worldBookCooldownHint =>
      '트리거 후 또는 고정 종료 후 N개의 메시지 동안 재활성화를 방지합니다. 0은 이 효과를 비활성화합니다.';

  @override
  String get worldBookDelayLabel => '지연 (메시지 수)';

  @override
  String get worldBookDelayHint =>
      '대화에 최소 N개의 메시지가 있을 때만 활성화를 허용합니다. 대화 교환이 아닌 개별 메시지를 기준으로 계산합니다. 0은 이 효과를 비활성화합니다.';

  @override
  String get worldBookDragToReorder => '드래그하여 순서 변경';

  @override
  String worldBookEnabledCount(int enabled, int total) {
    return '$enabled/$total 활성화됨';
  }

  @override
  String get assistantConversationSystemPromptTitle => '대화별 시스템 프롬프트';

  @override
  String get assistantConversationSystemPromptHint =>
      '각 대화가 자체 시스템 프롬프트를 사용하도록 허용합니다.';

  @override
  String get assistantConversationInjectionTitle => '대화별 지시 주입';

  @override
  String get assistantConversationInjectionHint =>
      '각 대화에 대해 지시 주입과 세계관 책을 선택합니다. 기본적으로 아무것도 선택되지 않습니다.';

  @override
  String get conversationSystemPromptTitle => '대화 시스템 프롬프트';

  @override
  String get conversationSystemPromptHint =>
      '이 대화에만 적용됩니다. 비워 두면 어시스턴트의 시스템 프롬프트를 사용합니다.';

  @override
  String get conversationSystemPromptClear => '어시스턴트 프롬프트 사용';

  @override
  String get conversationSystemPromptPlaceholder => '이 대화의 시스템 프롬프트를 작성하세요…';

  @override
  String get conversationPromptScope => '이 대화';

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
  String get oauthCodeHint => '인증 페이지에 이 코드를 입력하세요';

  @override
  String get oauthDeviceHint =>
      '먼저 ChatGPT 보안 설정 또는 작업 공간 권한에서 기기 코드 로그인을 활성화하세요.';

  @override
  String get oauthDeviceLogin => '기기 코드 사용';

  @override
  String get oauthDetails => '계정 세부정보 보기';

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
  String get oauthLoginRestored => '로그인되었습니다. 메시지 재시도 버튼을 사용하여 다시 보내세요.';

  @override
  String get oauthLogout => '로그아웃';

  @override
  String get oauthLogoutDescription => '이 기기에서 이 계정의 저장된 자격 증명을 제거합니다';

  @override
  String get oauthRefreshing => '권한 갱신 중…';

  @override
  String get oauthRefreshUsage => '사용량 새로고침';

  @override
  String get oauthUsageDetails => '사용량 상세';

  @override
  String get oauthUsageUnavailable => '현재 사용량을 가져올 수 없습니다';

  @override
  String oauthLastUpdated(String time) {
    return '$time에 업데이트됨';
  }

  @override
  String get oauthSyncModels => '동기화';

  @override
  String get oauthSyncing => '모델 동기화 중…';

  @override
  String get oauthModelsHint =>
      '사용 가능한 모델은 계정에서 동기화됩니다. 모델 선택기에 표시할 모델을 선택하세요. 선택 사항은 동기화하거나 다시 로그인해도 유지됩니다.';

  @override
  String get oauthNoModels => '모델을 동기화하면 대화를 시작할 수 있습니다';

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
  String get oauthName => '공급자 이름';

  @override
  String get oauthEnabledHint => '모델 선택기에 이 모델 표시';

  @override
  String get oauthNetwork => '네트워크 프록시';

  @override
  String get oauthFollowGlobal => '전역 설정 따르기';

  @override
  String get oauthCustomRequest => '사용자 지정 요청';

  @override
  String get oauthWeekly => '주간 기간';

  @override
  String get oauthMonthly => '월간 기간';

  @override
  String get oauthTotal => '총 할당량';

  @override
  String oauthHours(String count) {
    return '$count시간 기간';
  }

  @override
  String oauthMinutes(String count) {
    return '$count분 기간';
  }

  @override
  String oauthDays(String count) {
    return '$count일 기간';
  }

  @override
  String get oauthWindow => '사용량 기간';

  @override
  String oauthResetsAt(String time) {
    return '$time에 초기화';
  }

  @override
  String oauthUsedValue(String value) {
    return '사용됨 $value';
  }

  @override
  String get oauthNetworkError => '연결할 수 없습니다. 네트워크를 확인한 후 다시 시도하세요.';

  @override
  String get oauthDnsError => 'DNS 조회에 실패했습니다. 네트워크 또는 프록시 DNS 설정을 확인하세요.';

  @override
  String get oauthTlsError => 'TLS 연결에 실패했습니다. 네트워크 또는 프록시에서 사용하는 인증서를 확인하세요.';

  @override
  String get oauthProxyError => '프록시 연결에 실패했습니다. 프록시 주소와 인증 설정을 확인하세요.';

  @override
  String get oauthConnectionError =>
      '연결에 실패했거나 중단되었습니다. 네트워크 또는 프록시 설정을 확인하세요.';

  @override
  String get oauthConnectionTimeout =>
      '서버 연결 시간이 초과되었습니다. 네트워크 또는 프록시 설정을 확인하세요.';

  @override
  String get oauthSendTimeout => '요청 전송 시간이 초과되었습니다. 네트워크를 확인한 후 다시 시도하세요.';

  @override
  String get oauthReceiveTimeout => '서버 응답 대기 시간이 초과되었습니다. 다시 시도하세요.';

  @override
  String get oauthRequestTimeout =>
      '요청 시간이 초과되었습니다. 네트워크 또는 프록시 설정을 확인한 후 다시 시도하세요.';

  @override
  String oauthFailureStage(String stage) {
    return '실패 단계: $stage';
  }

  @override
  String get oauthStageRequestDeviceCode => '기기 코드 요청 중';

  @override
  String get oauthStageWaitDeviceAuthorization => '기기 인증 대기 중';

  @override
  String get oauthStagePrepareBrowser => '브라우저 로그인 준비 중';

  @override
  String get oauthStageBrowserAuthorization => '브라우저 인증 및 콜백';

  @override
  String get oauthStageExchangeToken => '인증 코드 교환 중';

  @override
  String get oauthStageRefreshToken => '로그인 토큰 갱신 중';

  @override
  String get oauthInvalidResponse => '인증이 완료되지 않았습니다. 다시 시도하세요.';

  @override
  String get oauthTimeout => '인증 시간이 초과되었습니다. 다시 시도하세요.';

  @override
  String get oauthDenied => '인증이 승인되지 않았습니다. 다시 시도하세요.';

  @override
  String get oauthSaving => '계정 연결 중…';

  @override
  String get oauthQuotaExceeded => '이 계정에는 사용 가능한 할당량이 없습니다.';

  @override
  String get oauthRateLimited => '요청이 너무 많습니다. 잠시 후 다시 시도해 주세요.';

  @override
  String get oauthPermissionDenied => '이 계정은 이 리소스에 접근할 수 없습니다.';

  @override
  String get oauthRequestFailed => '공급자가 요청을 완료하지 못했습니다.';

  @override
  String get oauthQuotaAvailable => '할당량 사용 가능';

  @override
  String oauthSavedResets(String count) {
    return '사용 가능한 사용량 재설정 횟수: $count';
  }

  @override
  String get oauthPrimaryWindow => '기본 기간';

  @override
  String get oauthSecondaryWindow => '보조 기간';

  @override
  String get oauthAuthorizationCode => '인증 코드 또는 콜백 URL';

  @override
  String get oauthAuthorizationCodeHint =>
      '브라우저가 자동으로 돌아오지 않으면 최종 콜백 URL 또는 인증 코드를 여기에 붙여넣으세요.';

  @override
  String get oauthInvalidAuthorizationCode => '이번 로그인 시도의 코드 또는 콜백 URL을 입력하세요.';

  @override
  String get oauthSubmitAuthorizationCode => '로그인 완료';

  @override
  String get oauthExtraUsage => '추가 사용량';

  @override
  String get oauthMonthlyTotal => '월간 총 할당량';

  @override
  String get oauthMonthlyCode => '월간 코드 할당량';

  @override
  String get oauthSpendCap => '크레딧 지출 한도';

  @override
  String get oauthOnDemand => '온디맨드 할당량';

  @override
  String get oauthQuotaAdvisory => '참고용: 주간 크레딧이 유효하여 이 월간 한도를 확인할 수 없습니다.';

  @override
  String oauthCreditsValue(String value) {
    return '$value 크레딧';
  }

  @override
  String oauthRemainingValue(String value) {
    return '남은 $value';
  }

  @override
  String get oauthPromptCachingHelp => '여러 메시지에서 컨텍스트를 재사용하고 캐시 보존 기간을 설정합니다.';

  @override
  String get scheduledTasksPreparation => '실행 및 알림';

  @override
  String get scheduledTasksAllowPreparation => '사전 준비 허용';

  @override
  String get scheduledTasksPreparationDetail =>
      '사전 준비는 실시간 정보가 필요 없는 텍스트 작업에 적합하며, 도구, 첨부 파일 또는 외부 작업을 사용하지 않습니다.';

  @override
  String get scheduledTasksIOSDetail =>
      'iOS 백그라운드 제한으로 인해 Kelivo는 지정된 시간에 자동으로 깨어나 모델을 실행할 수 없습니다. 대신 앱이 실행될 수 있을 때 콘텐츠를 미리 준비하고, 시스템이 예정된 시간에 알림을 표시합니다. 다음 한 번의 결과만 준비됩니다. 앱을 나간 후에는 준비가 완료되지 않을 수 있으며, 이후 작업은 Kelivo를 다시 열어야 준비됩니다.';

  @override
  String get scheduledTasksContextPolicy => '대화 컨텍스트';

  @override
  String get scheduledTasksContextLatest => '최신 대화 따르기';

  @override
  String get scheduledTasksContextSnapshot => '준비 시점의 스냅샷 사용';

  @override
  String get scheduledTasksUnavailable => '실행할 수 없을 때';

  @override
  String get scheduledTasksRemind => '알림만 보내기';

  @override
  String get scheduledTasksSkip => '이번 회차 건너뛰기';

  @override
  String get scheduledTasksNotify => '결과 알림';

  @override
  String get scheduledTasksShowPreview => '알림에 결과 본문 표시';

  @override
  String get scheduledTasksPreparationWindow => '최대 사전 준비';

  @override
  String get scheduledTasksPreparationAttempts => '자동 준비 시도 횟수 상한';

  @override
  String get scheduledTasksPreparationCooldown => '준비 최소 간격(분)';

  @override
  String get scheduledTasksPreparationBudget =>
      '모든 작업을 합쳐 한 번에 하나만 준비할 수 있습니다. 시간당 누적 시도 6회 후 자동 준비가 일시 중지되며, 취소된 요청도 횟수에 포함됩니다. 「지금 준비」는 시도 횟수 상한의 제한을 받지 않습니다.';

  @override
  String get scheduledTasksPreparing => '결과 준비 중';

  @override
  String get scheduledTasksPrepared => '결과 준비 완료';

  @override
  String get scheduledTasksPendingPreparation => '이번 결과는 아직 준비되지 않음';

  @override
  String get scheduledTasksNotificationRegistered => '알림 등록됨';

  @override
  String get scheduledTasksNotificationUnavailable => '알림 미등록';

  @override
  String get scheduledTasksReminded => '만료됨 · 알림만';

  @override
  String get scheduledTasksSkipped => '건너뜀';

  @override
  String get scheduledTasksCancelled => '취소됨';

  @override
  String get scheduledTasksReminderBody =>
      '예약된 작업 시간이 되었습니다. Kelivo를 열어 계속하세요.';

  @override
  String get scheduledTasksResultBody => '예약된 작업 결과가 준비되었습니다.';

  @override
  String get scheduledTasksNotificationPermission => '작업 알림 허용';

  @override
  String get scheduledTasksPreparationCost =>
      '사전 준비는 모델을 호출하므로 추가 비용이 발생할 수 있습니다. 「최신 대화 따르기」를 선택하면 만료 전 새 메시지로 인해 준비된 내용이 무효화될 수 있습니다. 결과를 사용하지 않거나 요청이 취소되어도 과금될 수 있으며, 다시 준비하면 모델이 다시 호출됩니다.';

  @override
  String get scheduledTasksAllowPreparationTip =>
      'Kelivo가 실행될 수 있을 때 다음 작업 결과를 미리 생성하며, 만료 전에는 채팅에 표시되지 않습니다. 텍스트만 사용하고 도구, 첨부 파일 또는 사용자 지정 요청 본문은 사용하지 않습니다. 모델 호출로 비용이 발생할 수 있습니다.';

  @override
  String get scheduledTasksContextPolicyTip =>
      '최신 대화 따르기: 작업 시간 전에 새 메시지를 보내거나 메시지를 편집하거나 메시지 버전을 전환하면 준비된 내용이 무효화됩니다. 다시 준비하면 시도 횟수를 차감하며 추가 비용이 발생할 수 있습니다. 작업 시간이 되면 저장된 알림 결과가 그대로 대화에 추가됩니다.\n\n준비 시점 스냅샷 사용: 대화가 변경되어도 준비된 결과를 유지합니다. 이후 메시지는 반영되지 않습니다.';

  @override
  String get scheduledTasksPreparationWindowTip =>
      '작업 시간 전 최대 24시간까지 준비를 시작할 수 있습니다. 예를 들어 다음 날 아침 알림이라면 전날 정오에 Kelivo를 열었을 때 준비할 기회가 생깁니다. 시간이 길수록 준비 기회는 많아지지만 내용이 더 일찍 오래될 수 있습니다. 작업 시간을 변경하지 않으며 백그라운드 정기 실행을 보장하지도 않습니다. 「지금 준비」는 이 자동 대기 시간과 모든 시도 제한을 우회합니다.';

  @override
  String get scheduledTasksPreparationAttemptsTip =>
      '이번 회차의 누적 시도 횟수가 상한에 도달하면 자동 준비가 일시 중지됩니다. 최초 시도, 실패, 취소, 수동 준비가 모두 시도 기록에 포함됩니다. 상한에 도달해도 「지금 준비」는 여전히 실행할 수 있습니다. 시도가 많을수록 모델 비용이 더 발생할 수 있으며 이는 지출 한도가 아닙니다.';

  @override
  String get scheduledTasksPreparationCooldownTip =>
      '같은 회차의 준비 시도 시작 사이의 최소 간격(분)입니다. 간격이 길수록 반복 요청이 줄어듭니다. 재시도하려면 여전히 앱이 실행 중이어야 하며 백그라운드 타이머가 아닙니다. 「지금 준비」는 이 자동 대기 시간과 모든 시도 제한을 우회합니다.';

  @override
  String get scheduledTasksUnavailableTip =>
      '사용 가능한 준비 결과가 없고 작업 시간에 작업을 실행할 수 없으면 알림을 보내거나 이번 회차를 건너뜁니다. 알림에는 모델이 생성한 답변이 포함되지 않으며 알림이 활성화되어 있어야 합니다. 작업 시간에 Kelivo가 열려 있으면 그때 작업을 실행할 수 있습니다.';

  @override
  String get scheduledTasksNotifyTip =>
      '결과 알림과 실행 불가 시 알림을 허용합니다. 끄더라도 작업 실행과 모델 호출은 중단되지 않으며 사전 준비 비용도 발생할 수 있습니다. 시스템 알림 권한도 필요합니다.';

  @override
  String get scheduledTasksShowPreviewTip =>
      '알림에 준비된 결과 텍스트를 표시하며, 시스템 설정이 허용하면 잠금 화면에도 표시합니다. 끄면 일반 안내만 표시되며 전체 결과는 대화에서 확인할 수 있습니다. 전역 알림 개인정보 설정도 함께 적용됩니다.';

  @override
  String scheduledTasksHours(int count) {
    return '$count시간';
  }

  @override
  String scheduledTasksMinutes(int count) {
    return '$count분';
  }

  @override
  String get scheduledTasksPreparationOff => '준비 꺼짐';

  @override
  String get scheduledTasksPreparationQueued => '대기 중';

  @override
  String get scheduledTasksPreparationQueuedDetail =>
      '다른 작업을 준비 중입니다. 이후 예정 시간 순서대로 준비합니다.';

  @override
  String get scheduledTasksPreparationIdle => '대화 대기 중';

  @override
  String get scheduledTasksPreparationIdleDetail =>
      '현재 응답이 완료되고 이 작업의 대화 상태가 안정되면 준비를 계속합니다.';

  @override
  String get scheduledTasksPreparationWindowWaiting => '준비 시간 전';

  @override
  String get scheduledTasksPreparationCooldownWaiting => '재시도 대기 중';

  @override
  String scheduledTasksPreparationRetryAt(String time) {
    return '다음 시도 가능: $time';
  }

  @override
  String get scheduledTasksPreparationLimitReached => '자동 준비 횟수 소진';

  @override
  String scheduledTasksPreparationAttemptsUsed(int count, int limit) {
    return '이번 회차에서 $count회 시도했으며 자동 준비 상한은 $limit회입니다. 「지금 준비」로 계속할 수 있습니다.';
  }

  @override
  String get scheduledTasksPreparationHourlyLimit => '자동 준비 시간당 상한 도달';

  @override
  String get scheduledTasksPreparationHourlyLimitDetail =>
      '시간당 준비 횟수 상한에 도달하여 자동 준비가 일시 중지됩니다. 여전히 「지금 준비」를 사용할 수 있습니다.';

  @override
  String get scheduledTasksPreparationUnavailable => '준비 불가';

  @override
  String get scheduledTasksPreparationReadFailed =>
      '작업 정보를 읽을 수 없습니다. 잠시 후 다시 확인합니다. 자세한 내용은 실행 기록을 참조하세요.';

  @override
  String get scheduledTasksPreparationResultRetained =>
      '컨텍스트를 확인할 수 없습니다. 준비된 결과는 유지되며 잠시 후 다시 확인합니다.';

  @override
  String get scheduledTasksPreparationContextChanged =>
      '대화 내용 또는 설정이 변경되어 이전 준비 결과가 무효화되었습니다.';

  @override
  String get scheduledTasksPreparationPublishing => '대화에 추가 대기 중';

  @override
  String get scheduledTasksPreparationPublishingDetail =>
      '현재 응답이 끝나면 저장된 결과를 대화에 추가합니다.';

  @override
  String get scheduledTasksPreparationPrompt => '준비 프롬프트';

  @override
  String get scheduledTasksPreparationPromptTip =>
      '이 작업을 미리 준비할 때만 추가되는 시스템 프롬프트로, 작업 내용과 분리됩니다. 말투나 요구 사항을 사용자 지정할 수 있으며 비워 두면 준비 프롬프트를 추가하지 않습니다. 설정과 관계없이 사전 준비에서는 도구를 사용하거나 실시간 정보를 가져올 수 없습니다. 작업 시간 전에 수정하면 준비된 결과가 무효화되며 다시 준비하면 추가 모델 비용이 발생할 수 있습니다.';

  @override
  String get scheduledTasksPreparationPromptEmpty => '비워 두면 준비 프롬프트를 추가하지 않습니다';

  @override
  String scheduledTasksPreparationPromptVariables(
    String timeVariable,
    String offsetVariable,
  ) {
    return '사용 가능한 자리표시자: $timeVariable은 예정된 현지 시간, $offsetVariable은 해당 시간의 UTC 오프셋입니다. 준비 시 자동으로 치환됩니다.';
  }

  @override
  String get scheduledTasksPrepareNow => '지금 준비';

  @override
  String get scheduledTasksPrepareNowDetail =>
      '다음 내용을 지금 준비하고 예정된 시간에 전송합니다. 자동 준비의 대기 시간과 시도 제한이 적용되지 않습니다. 모델을 호출하여 비용이 발생할 수 있으며, 이미 준비된 결과가 있으면 재사용합니다.';

  @override
  String get scheduledTasksPrepareNowReady =>
      '이번 결과는 이미 준비되어 있어 모델을 다시 호출하지 않았습니다.';

  @override
  String get scheduledTasksPrepareNowStarted => '다음 내용을 준비 중이며 예정된 시간에 게시됩니다.';

  @override
  String get scheduledTasksPrepareNowBusy => '다른 작업을 준비 중입니다. 완료된 후 다시 시도하세요.';

  @override
  String get scheduledTasksPrepareNowChatBusy => '현재 응답이 끝난 후 다시 준비해 주세요.';

  @override
  String get scheduledTasksPrepareNowDisabled =>
      '먼저 작업과 「사전 준비 허용」을 활성화하세요. 재생성 모드는 사전 준비를 지원하지 않습니다.';

  @override
  String get scheduledTasksPrepareNowUnavailable =>
      '아직 준비를 시작할 수 없습니다. 잠시 후 다시 시도하세요.';

  @override
  String get scheduledTasksPrepareNowNoUpcoming =>
      '사전 준비할 다음 작업이 없습니다. 작업 시간과 활성화 상태를 확인하세요.';

  @override
  String get phoneControlTitle => '휴대폰 제어';

  @override
  String get phoneControlSubtitle => '접근성을 통해 화면을 읽고 작업 수행';

  @override
  String get phoneControlAccessibilityService => '접근성 서비스';

  @override
  String get phoneControlOpenSettings => '접근성 설정 열기';

  @override
  String get phoneControlRefresh => '상태 새로고침';

  @override
  String get phoneControlChecking => '서비스 상태 확인 중…';

  @override
  String get phoneControlReady => '활성화됨 및 연결됨';

  @override
  String get phoneControlDisabled => '활성화되지 않음';

  @override
  String get phoneControlDisconnected =>
      '활성화되었지만 연결되지 않았습니다. 시스템 설정에서 서비스를 껐다 켠 후 상태를 새로고침하세요.';

  @override
  String get phoneControlStatusUnavailable =>
      '서비스 상태를 읽을 수 없습니다. 새로고침하여 다시 시도하세요.';

  @override
  String get phoneControlSettingsUnavailable =>
      '설정을 열 수 없습니다. Android 설정 → 접근성으로 직접 이동하세요.';

  @override
  String get phoneControlUsageTitle => '사용 방법';

  @override
  String get phoneControlDisclosure =>
      '대화에서 요청한 휴대폰 제어 작업을 위해 어시스턴트는 현재 화면을 읽고, 탭하고, 텍스트를 입력하고, 스크롤하고, 탐색하고, 앱을 열 수 있습니다. 화면 내용은 해당 대화에 구성된 모델 공급자에게 전송되며 도구 결과에 저장됩니다. 비밀번호 필드는 숨겨집니다. 이 서비스는 화면 내용을 지속적으로 기록하지 않습니다. 언제든지 어시스턴트의 이 도구를 끄거나 시스템 설정에서 서비스를 비활성화할 수 있습니다.';

  @override
  String get phoneControlAssistantTitle => '어시스턴트 도구 활성화';

  @override
  String get phoneControlAssistantHint =>
      '두 가지 권한이 모두 필요합니다: 시스템 접근성 설정에서 Kelivo 휴대폰 제어를 활성화한 다음, 어시스턴트의 로컬 도구에서 휴대폰 제어를 활성화하세요(대화 도구 메뉴에서도 가능). 각 어시스턴트는 개별적으로 구성됩니다. 작업을 실행하는 동안 휴대폰 잠금을 해제해 두세요.';

  @override
  String get phoneControlRestrictedTitle => '접근성 스위치를 사용할 수 없나요?';

  @override
  String get phoneControlRestrictedHint =>
      '일부 다운로드한 APK의 경우 Android에서 먼저 앱 정보 메뉴에서 \'제한된 설정 허용\'이 필요합니다. 탭하여 Kelivo 앱 정보를 연 다음 접근성 설정으로 돌아오세요.';

  @override
  String get phoneControlEnableAssistant => '이 어시스턴트가 휴대폰 제어를 사용하도록 허용';

  @override
  String get composerDraftLabel => '임시 저장';

  @override
  String get composerDraftRecovered => '전송하지 않은 메시지가 복구되었습니다.';

  @override
  String get composerDraftRestore => '계속 편집';

  @override
  String get composerDraftDiscard => '버리기';

  @override
  String get composerDraftSaveFailed =>
      '최신 임시 저장을 저장하지 못했습니다. 내용은 이 창에 남아 있습니다.';

  @override
  String get composerDraftRetry => '저장 재시도';

  @override
  String get composerDraftConflictTitle => '이 대화에는 이미 임시 저장이 있습니다';

  @override
  String get composerDraftConflictBody =>
      '추가하면 두 텍스트와 첨부 파일이 모두 유지됩니다. 교체하면 기존 임시 저장이 삭제됩니다. 자동으로 전송되는 내용은 없습니다.';

  @override
  String get composerDraftAppend => '추가';

  @override
  String get composerDraftReplace => '임시 저장 교체';

  @override
  String get composerDraftMissingFile =>
      '첨부 파일을 사용할 수 없습니다. 제거하거나 파일을 다시 선택하세요.';

  @override
  String get composerDraftMessageMissing =>
      '편집 중인 메시지가 더 이상 존재하지 않습니다. 텍스트를 새 메시지로 복사하거나 이 편집을 취소하세요.';

  @override
  String get composerDraftDeleteNotice => '이 대화의 전송하지 않은 임시 저장도 함께 삭제됩니다.';

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
  String get mcpOAuthFillRedirectExample => '예시 입력';

  @override
  String get mcpOAuthRedirectHint =>
      '비워 두면 플랫폼 기본 콜백을 사용합니다. 서비스가 localhost 콜백만 허용하는 경우 HTTP 루프백 URL을 사용하세요. 포트 0은 사용 가능한 포트를 자동 선택합니다. 사전 등록된 클라이언트는 고정 포트를 요구할 수 있습니다.';

  @override
  String get mcpOAuthClientIdRequired => '클라이언트 ID를 입력하거나 자동 등록을 선택하세요.';

  @override
  String get mcpOAuthMetadataUrlInvalid => '경로가 포함된 HTTPS 메타데이터 문서 URL을 입력하세요.';

  @override
  String get mcpOAuthSecretRequired => '이 클라이언트 인증 방식에는 클라이언트 시크릿이 필요합니다.';

  @override
  String get mcpOAuthRedirectInvalid =>
      'localhost, 127.0.0.1 또는 [::1]의 HTTP 콜백을 사용하세요. 자격 증명, 쿼리 매개변수 또는 프래그먼트는 포함하지 마세요.';

  @override
  String get mcpOAuthDiscovering => '인증 서버 검색 중…';

  @override
  String get mcpOAuthRegistering => '인증 준비 중…';

  @override
  String get mcpOAuthWaitingBrowser => '브라우저 인증 대기 중…';

  @override
  String get mcpOAuthExchangingToken => '로그인 완료 중…';

  @override
  String get markdownPlaygroundTitle => 'Markdown Playground';

  @override
  String get markdownPlaygroundSource => 'Markdown 소스';

  @override
  String get markdownPlaygroundPreview => '미리보기';

  @override
  String get markdownPlaygroundAst => 'AST';

  @override
  String get markdownPlaygroundPlay => '문자 단위로 입력';

  @override
  String get markdownPlaygroundPause => '일시정지';

  @override
  String get markdownPlaygroundResume => '계속';

  @override
  String get markdownPlaygroundShowAll => '전체 표시';

  @override
  String get markdownPlaygroundWidth => '미리보기 너비';

  @override
  String get markdownPlaygroundTheme => '미리보기 테마';

  @override
  String get markdownPlaygroundPlain => '선택한 일반 텍스트';

  @override
  String get markdownPlaygroundMarkdown => '선택한 Markdown';

  @override
  String get markdownPlaygroundSelectionHint =>
      '미리보기에서 텍스트를 선택하여 복사된 내용을 확인하세요.';

  @override
  String get markdownPlaygroundEmpty => 'Markdown을 입력하면 미리 볼 수 있습니다.';

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
    return '$count개 행 더 보기';
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
  String get recoveryMissingDataTitle => '이전 데이터가 감지되었습니다';

  @override
  String get recoveryMissingDataBody =>
      'Kelivo가 현재 채팅 데이터베이스를 찾지 못했습니다. 로딩을 일시 중지했으며 빈 데이터베이스를 새로 만들지 않았습니다. 아래에서 이전 사본을 찾아볼 것이며, 기존 파일은 유지됩니다.';

  @override
  String get recoveryEmptyDataTitle => '현재 채팅 기록이 비어 있습니다';

  @override
  String get recoveryEmptyDataBody =>
      '현재 채팅 목록이 비어 있지만 이전 사본을 찾았습니다. 아래에서 사본을 선택해 채팅을 복구할 수 있습니다. 기존 파일은 유지됩니다.';

  @override
  String get recoveryKeepCurrent => '빈 채팅 목록으로 계속';

  @override
  String get recoveryKeepCurrentConfirm =>
      '이 작업은 이전 채팅을 복구하지 않고 계속합니다. 현재 채팅 목록은 비어 있는 상태로 유지되며 이전 사본은 보존됩니다. 채팅을 되찾으려면 취소하고 로컬 사본을 선택하세요.';

  @override
  String get recoverySearchingCopies => '로컬 데이터 사본을 찾고 검증하는 중…';

  @override
  String recoveryFoundCopies(int count) {
    return '검증을 통과한 사본 $count개를 찾았습니다. 하나를 선택해 채팅과 설정을 복구하세요. 원본 파일은 유지됩니다.';
  }

  @override
  String recoveryInvalidCopy(String name) {
    return '$name: 검증에 실패했습니다. 원본 파일은 유지되었습니다.';
  }

  @override
  String get recoverySearchFailed =>
      '일부 데이터 위치를 읽을 수 없습니다. 파일은 유지되었으며, 다른 복구 작업을 시도하기 전에 데이터 사본을 내보내세요.';

  @override
  String get recoveryDiscoveredCopyBody =>
      '관리되는 사본 폴더 외부에서 발견되었습니다. 이 원본은 보존되며 복구 전에 전체 검증을 거칩니다.';

  @override
  String get recoveryStorageFailureTitle => '데이터 저장소를 확인해야 합니다';

  @override
  String get recoveryStorageFailureBody =>
      '데이터 업데이트를 완료하지 못했습니다. 원본 데이터는 유지되었습니다. Kelivo를 다시 열거나 아래에서 로컬 사본을 선택해 복구해 보세요.';

  @override
  String get recoveryProtectingTitle => '채팅 데이터베이스 보호 중';

  @override
  String get recoveryProtectingData =>
      '데이터베이스를 복사하고 검증하는 중입니다. 이미지, 첨부 파일, 스냅샷은 Documents에 그대로 남아 다시 복사되지 않습니다. 원본 데이터베이스도 유지됩니다.';

  @override
  String get recoveryStorageReadyTitle => '채팅 데이터베이스가 내부 저장소로 이동되었습니다';

  @override
  String get recoveryStorageReadyBody =>
      '채팅, 어시스턴트, 설정을 담은 데이터베이스가 이제 앱 내부 저장소를 사용합니다. 스냅샷, 이미지, 첨부 파일은 파일 앱의 Documents에서 계속 접근할 수 있습니다. 원본 데이터베이스는 유지됩니다. 이전 채팅이 누락된 경우 설정 → 백업 → 로컬 사본을 여세요.';

  @override
  String get recoveryRetainedData => '보존된 원본 데이터';

  @override
  String get recoveryNoValidCopies =>
      '사본을 찾았지만 검증을 통과한 사본이 없습니다. 원본은 모두 유지되었습니다. 데이터를 내보내 추가로 진단할 수 있습니다.';

  @override
  String get recoveryStorageInsufficientSpaceBody =>
      '데이터를 안전하게 준비하기에 저장 공간이 부족합니다. 시스템 설정에서 공간을 확보한 뒤 Kelivo를 다시 열거나 아래 사본을 다시 확인하세요. Kelivo를 설치된 상태로 두고 데이터와 로컬 사본을 그대로 유지하세요.';

  @override
  String get migrationFreshStartTitle => '새로 시작할 준비가 되었습니다';

  @override
  String get migrationFreshStartSubtitle =>
      '새 빈 데이터베이스가 준비되었으며 이전 데이터는 유지되었습니다. 계속하려면 앱을 다시 시작하세요.';

  @override
  String get migrationFreshStartFailedTitle => '새로 시작을 완료하지 못했습니다';

  @override
  String get migrationFreshStartFailedSubtitle =>
      '이전 데이터는 유지되었습니다. 새로 시작을 다시 시도하거나 앱을 닫았다가 다시 여세요.';

  @override
  String get imageExportPreparing => '이미지 준비 중…';

  @override
  String imageExportDiagrams(int completed, int total) {
    return '다이어그램 준비 중 $completed/$total…';
  }

  @override
  String imageExportCapturing(int completed, int total) {
    return '이미지 캡처 중 $completed/$total…';
  }

  @override
  String get imageExportProcessing => '이미지를 합성하고 미리 보기를 준비하는 중…';

  @override
  String get imageExportSaving => '이미지 저장 중…';

  @override
  String get backupEncryptionTitle => '백업 암호화';

  @override
  String get backupEncryptionOffHint => '암호화되지 않은 백업은 파일을 가진 누구나 읽을 수 있습니다.';

  @override
  String get backupEncryptionOnHint =>
      '백업이 암호화됩니다. 앱을 다시 시작한 후 비밀번호를 다시 입력하세요.';

  @override
  String get backupEncryptionPasswordHint =>
      '이 비밀번호를 안전하게 보관하세요. 분실하면 백업을 복원할 수 없습니다. 비밀번호는 앱을 종료할 때까지 메모리에만 보관됩니다.';

  @override
  String get backupEncryptionPassword => '비밀번호';

  @override
  String get backupEncryptionConfirmPassword => '비밀번호 확인';

  @override
  String get backupEncryptionMismatch => '비밀번호가 일치하지 않습니다.';

  @override
  String get backupEncryptionShowPassword => '비밀번호 표시';

  @override
  String get backupEncryptionHidePassword => '비밀번호 숨기기';

  @override
  String get backupEncryptionUnlockTitle => '암호화된 백업';

  @override
  String get backupEncryptionUnlockHint => '이 백업을 만들 때 사용한 비밀번호를 입력하세요.';

  @override
  String get backupEncryptionUnlock => '잠금 해제';

  @override
  String get backupEncryptionFailed =>
      '비밀번호가 틀렸거나 백업이 손상되었습니다. 다시 시도하거나 취소하세요.';

  @override
  String get backupEncryptionInvalid => '암호화된 백업이 불완전하거나 유효하지 않습니다.';

  @override
  String get backupEncryptionUnsupported =>
      '이 암호화된 백업을 사용하려면 더 새로운 버전의 Kelivo가 필요합니다.';

  @override
  String get backupProgressEncrypting => '백업 암호화 중';

  @override
  String get backupProgressDecrypting => '백업 복호화 중';

  @override
  String get mcpPageStatusFailed => '연결 실패';

  @override
  String mcpPageCardToolsShort(int enabled, int total) {
    return '도구 $enabled/$total';
  }

  @override
  String mcpPageSelectServer(String name) {
    return '$name 선택';
  }

  @override
  String get mcpIconTitle => '서버 아이콘';

  @override
  String get mcpIconInvalid => '이 이미지를 사용할 수 없습니다. 10 MB 이하의 유효한 이미지를 선택하세요.';

  @override
  String get mcpSelectServers => '서버 선택';

  @override
  String get mcpMoveToGroup => '그룹으로 이동';

  @override
  String get mcpRenameGroup => '그룹 이름 변경';

  @override
  String get mcpDeleteGroupConfirm => '이 그룹의 서버는 기타로 이동됩니다. 서버는 삭제되지 않습니다.';

  @override
  String get mcpGroupNameInvalid => '비어 있지 않고 중복되지 않는 그룹 이름을 입력하세요.';

  @override
  String get mcpEnableSelected => '활성화';

  @override
  String get mcpDisableSelected => '비활성화';

  @override
  String mcpDeleteSelectedConfirm(int count) {
    return '선택한 서버 $count개를 삭제할까요?';
  }

  @override
  String get browserTitle => '브라우저';

  @override
  String get browserSearchHint => '검색 또는 웹사이트 입력';

  @override
  String get browserStartTitle => '다음은 어디로 갈까요?';

  @override
  String get browserStartSubtitle => '자유롭게 둘러보세요. 필요할 때 에이전트의 도움을 받을 수 있습니다.';

  @override
  String get browserNewTab => '새 탭';

  @override
  String get browserTabs => '탭';

  @override
  String get browserCloseTab => '탭 닫기';

  @override
  String get browserClose => '브라우저 닫기';

  @override
  String get browserBack => '뒤로';

  @override
  String get browserForward => '앞으로';

  @override
  String get browserReload => '새로고침';

  @override
  String get browserStop => '로딩 중지';

  @override
  String get browserMore => '더 보기';

  @override
  String get browserBookmarks => '북마크';

  @override
  String get browserHistory => '방문 기록';

  @override
  String get browserSettings => '브라우저 설정';

  @override
  String get browserAddBookmark => '북마크 추가';

  @override
  String get browserRemoveBookmark => '북마크 제거';

  @override
  String get browserNoBookmarks => '즐겨 찾는 사이트가 여기에 모입니다.';

  @override
  String get browserNoHistory => '방문 기록이 여기에 표시됩니다.';

  @override
  String get browserSearchLibrary => '저장된 페이지 검색';

  @override
  String get browserClearHistory => '방문 기록 지우기';

  @override
  String get browserClearHistoryConfirm => '모든 방문 기록을 삭제할까요? 북마크는 유지됩니다.';

  @override
  String get browserToday => '오늘';

  @override
  String get browserYesterday => '어제';

  @override
  String get browserDelete => '삭제';

  @override
  String get browserCancel => '취소';

  @override
  String get browserDone => '완료';

  @override
  String get browserFind => '페이지에서 찾기';

  @override
  String get browserFindPreviousMatch => '이전 일치 항목';

  @override
  String get browserFindNextMatch => '다음 일치 항목';

  @override
  String get browserFindHint => '텍스트 찾기';

  @override
  String get browserSearchEngine => '검색 엔진';

  @override
  String get browserDesktopMode => '데스크톱 웹사이트';

  @override
  String get browserDesktopModeDescription =>
      '데스크톱 사용자 에이전트로 열린 페이지를 다시 로드합니다.';

  @override
  String get browserRestoreTabs => '탭 복원';

  @override
  String get browserRestoreTabsDescription => 'Kelivo를 시작할 때 탭을 다시 엽니다.';

  @override
  String get browserSaveHistory => '방문 기록 저장';

  @override
  String get browserSaveHistoryDescription => '방문한 페이지를 로컬에 기록합니다.';

  @override
  String get browserClearData => '웹사이트 데이터 지우기';

  @override
  String get browserClearDataConfirm =>
      '쿠키, 저장소 및 캐시를 지우고 모든 탭을 닫을까요? 웹사이트에서 로그아웃됩니다.';

  @override
  String get browserDataCleared => '웹사이트 데이터를 지웠습니다';

  @override
  String get browserAgentControl => '에이전트 제어';

  @override
  String get browserAgentWorking => 'AI가 작업 중입니다';

  @override
  String get browserTakeOver => '직접 제어';

  @override
  String get browserAgentPaused => 'AI 작업이 일시 중지됨';

  @override
  String get browserAllowAgent => '계속 허용';

  @override
  String get browserAgentDescription =>
      '채팅에서 작업을 보내면 AI가 브라우저를 사용할 수 있습니다. 계속 허용은 일시 중지만 해제하며, 메시지를 보내거나 작업을 시작하지 않습니다.';

  @override
  String get browserOpenExternal => '기본 브라우저에서 열기';

  @override
  String get browserCopyLink => '링크 복사';

  @override
  String get browserLinkCopied => '링크를 복사했습니다';

  @override
  String get browserUnsupported => '이 플랫폼에서는 내장 브라우저를 사용할 수 없습니다.';

  @override
  String get browserStorageUnsupported =>
      '이 작업 공간 앱은 Android System WebView 또는 Microsoft Edge WebView2 Runtime 버전 152 이상이 필요합니다. 브라우저 엔진을 업데이트한 후 다시 시도하세요.';

  @override
  String get browserLoadFailed => '이 페이지를 불러올 수 없습니다';

  @override
  String get browserRetry => '다시 시도';

  @override
  String get browserFavorites => '즐겨찾기';

  @override
  String get browserEditBookmark => '북마크 편집';

  @override
  String get browserBookmarkTitle => '제목';

  @override
  String get browserBookmarkUrl => '웹사이트';

  @override
  String get browserSave => '저장';

  @override
  String get browserDownloads => '다운로드';

  @override
  String get browserNoDownloads => '다운로드한 파일이 여기에 표시됩니다.';

  @override
  String get browserDownloadCancel => '다운로드 취소';

  @override
  String get browserOpenDownload => '파일 열기';

  @override
  String get browserDownloadFailed => '다운로드 실패';

  @override
  String get browserAgentEnableHint =>
      '채팅 도구에서 브라우저 도구를 활성화한 후 여기에서 제어를 허용하세요.';

  @override
  String get browserSessionRequired => '에이전트 제어를 허용하려면 대화에서 브라우저를 여세요.';

  @override
  String get browserDownloadCancelled => '취소됨';

  @override
  String get browserAgentEnabled => '어시스턴트의 브라우저 접근 허용';

  @override
  String get browserAgentEnabledDescription =>
      '활성화된 어시스턴트는 이 브라우저의 페이지를 탐색하고 상호 작용할 수 있습니다.';

  @override
  String get browserToolTitle => '브라우저 제어';

  @override
  String get browserToolSubtitle =>
      '로그인된 페이지를 탐색하고 상호 작용합니다. 먼저 브라우저 설정에서 에이전트 제어를 활성화하세요.';

  @override
  String get browserOpen => '브라우저 열기';

  @override
  String get browserInvalidUrl => '유효한 HTTP 또는 HTTPS 웹사이트 주소를 입력하세요.';

  @override
  String get browserClearDataUnavailable =>
      'Windows 브라우저 엔진은 모든 웹사이트 데이터 지우기를 지원하지 않습니다.';

  @override
  String get browserSurfaceStyle => '표면 스타일';

  @override
  String get browserSurfaceLiquid => '리퀴드 글래스';

  @override
  String get browserSurfaceFrosted => '프로스트';

  @override
  String get browserSurfaceSolid => '단색';

  @override
  String get browserPageOptions => '페이지 옵션';

  @override
  String get browserAskAi => 'AI가 이 페이지를 처리하도록 하기';

  @override
  String get browserAskAiHint => '채팅으로 돌아가 요청을 추가한 후 전송하세요.';

  @override
  String get browserAskAiCurrentPage => '브라우저 현재 페이지';

  @override
  String get browserAskAiUnavailable => '이 대화를 사용할 수 없습니다. 먼저 채팅에서 브라우저를 여세요.';

  @override
  String get browserAskAiEditing => '페이지 작업을 추가하기 전에 현재 메시지 편집을 완료하거나 취소하세요.';

  @override
  String get browserAskAiAssistantDisabled =>
      '먼저 이 어시스턴트의 도구에서 브라우저 제어를 활성화하세요.';

  @override
  String get browserAskAiBrowserDisabled =>
      '먼저 브라우저 설정에서 어시스턴트의 브라우저 사용을 허용하세요.';

  @override
  String browserAskAiDraft(String page) {
    return '브라우저를 사용해 이 페이지를 처리해 주세요:\n$page\n\n내 요청: ';
  }

  @override
  String get browserOpenFullPage => '전체 페이지로 열기';

  @override
  String get browserClosePanel => '브라우저 패널 닫기';

  @override
  String get browserSearchTabs => '탭 검색';

  @override
  String browserTabsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '탭 $count개',
      one: '탭 1개',
    );
    return '$_temp0';
  }

  @override
  String get browserOpenInSidebar => '사이드바에서 열기';

  @override
  String get browserUserAgent => '사용자 에이전트';

  @override
  String get browserUserAgentMobile => '모바일';

  @override
  String get browserUserAgentDesktop => '데스크톱';

  @override
  String get browserUserAgentCustom => '사용자 지정';

  @override
  String get browserUserAgentHint => '사용자 지정 User-Agent 입력';

  @override
  String get browserUserAgentInvalid => '최대 2048자의 인쇄 가능한 ASCII 문자 한 줄을 사용하세요.';

  @override
  String get browserUserAgentDescription => '변경하면 현재 웹페이지가 다시 로드됩니다.';

  @override
  String browserStepsShowEarlier(int count) {
    return '이전 단계 $count개';
  }

  @override
  String get browserOpenThisPage => '브라우저에서 열기';

  @override
  String get browserGroupToggleSemantics => '브라우저 단계 표시 또는 숨기기';

  @override
  String get browserStepGroupTitle => '웹 탐색';

  @override
  String browserStepCount(int count) {
    return '$count단계';
  }

  @override
  String browserStepCurrent(int count) {
    return '$count단계';
  }

  @override
  String browserActionFailedCount(int count) {
    return '· $count개 실패';
  }

  @override
  String browserActionFailed(String action) {
    return '$action 실패';
  }

  @override
  String get browserCardOpen => '열기';

  @override
  String get browserCardEnable => '활성화';

  @override
  String browserCardRunning(String action) {
    return '$action 중…';
  }

  @override
  String get browserCardLive => '실시간';

  @override
  String get browserCardOpenFailed => '페이지를 열지 못했습니다';

  @override
  String get browserCardBlankPage => '빈 페이지';

  @override
  String browserCardTabCount(int count) {
    return '탭 $count개';
  }

  @override
  String get browserActionOpen => '페이지 열기';

  @override
  String get browserActionNewTab => '새 탭';

  @override
  String get browserActionRender => '페이지 렌더링';

  @override
  String get browserActionExtract => '텍스트 추출';

  @override
  String get browserActionSnapshot => '페이지 구조 읽기';

  @override
  String get browserActionClick => '클릭';

  @override
  String get browserActionType => '텍스트 입력';

  @override
  String get browserActionPress => '키 누르기';

  @override
  String get browserActionScroll => '스크롤';

  @override
  String get browserActionWait => '대기';

  @override
  String get browserActionBack => '뒤로';

  @override
  String get browserActionForward => '앞으로';

  @override
  String get browserActionReload => '새로고침';

  @override
  String get browserActionEvaluate => '스크립트 실행';

  @override
  String get browserActionSwitchTab => '탭 전환';

  @override
  String get browserActionCloseTab => '탭 닫기';

  @override
  String get browserActionListTabs => '탭 목록';

  @override
  String get browserActionUnknown => '브라우저 작업';

  @override
  String browserMetaChars(String count) {
    return '$count자';
  }

  @override
  String browserMetaElements(int count) {
    return '요소 $count개';
  }

  @override
  String get browserErrAgentDisabled => '브라우저 제어가 꺼져 있습니다';

  @override
  String get browserErrStaleRef => '요소가 만료되었습니다. 페이지를 다시 읽어야 합니다';

  @override
  String get browserErrNotVisible => '요소가 숨겨져 있거나 가려져 있습니다';

  @override
  String get browserErrNotFound => '요소를 찾을 수 없습니다';

  @override
  String get browserErrTimeout => '페이지 로드 시간 초과';

  @override
  String get browserErrHumanControl => '사용자가 브라우저를 제어하고 있습니다';

  @override
  String get browserErrTabClosed => '탭이 닫혔습니다';

  @override
  String get browserErrGeneric => '작업 실패';

  @override
  String get browserDirectionUp => '위';

  @override
  String get browserDirectionDown => '아래';

  @override
  String get browserDirectionLeft => '왼쪽';

  @override
  String get browserDirectionRight => '오른쪽';

  @override
  String browserMetaTabs(int count) {
    return '탭 $count개';
  }

  @override
  String get browserTabsCurrentConversation => '이 대화';

  @override
  String get browserTabsAll => '모든 탭';

  @override
  String get browserTabsUnassigned => '개인 탭';

  @override
  String get browserTabsUnknownConversation => '다른 대화';

  @override
  String get browserTabsEmptyConversation =>
      '아직 탭이 없습니다. 페이지를 열거나 모든 탭에서 탭을 선택하세요.';

  @override
  String get browserTabsNoResults => '일치하는 탭이 없습니다';

  @override
  String get browserMoveToConversation => '이 대화로 이동';

  @override
  String get browserReopenInConversation => '이 대화에서 다시 열기';

  @override
  String get browserTabBusy =>
      '어시스턴트가 아직 이 페이지를 사용 중입니다. 작업이 끝나거나 작업을 중지한 후 이동하세요.';

  @override
  String get browserLiveViewLimit =>
      '모든 브라우저 리소스가 사용 중입니다. 작업이 끝난 후 다시 시도하거나 사용하지 않는 페이지를 닫으세요.';

  @override
  String get browserAskAiInOwnerConversation => '소유 대화에서 AI에게 요청';

  @override
  String get displaySettingsPageShowBrowserPageCardsTitle => '웹페이지 카드 표시';

  @override
  String get browserObserverHint =>
      'AI가 이 페이지를 사용 중입니다. 상호작용하려면 \'인수\'를 선택하세요.';

  @override
  String get genuiSurfaceTitle => '인터랙티브 UI';

  @override
  String get genuiStatusStreaming => '생성 중';

  @override
  String get genuiStatusInterrupted => '중단됨';

  @override
  String get genuiStatusUnsaved => '저장되지 않음';

  @override
  String get genuiStatusUnsavedRetry => '탭하여 저장 재시도';

  @override
  String get genuiReadOnlyUntilComplete => '생성이 완료되면 사용 가능';

  @override
  String get genuiReadOnlySnapshot => '읽기 전용 스냅샷';

  @override
  String genuiPendingNode(String id) {
    return '$id 대기 중';
  }

  @override
  String get genuiViewSource => '소스 보기';

  @override
  String get genuiCopySource => '소스 복사';

  @override
  String get genuiExpand => '펼치기';

  @override
  String get genuiExpandedStub => '펼친 보기에서 편집 중';

  @override
  String get genuiMore => '더 보기';

  @override
  String get genuiReset => '기본값으로 재설정';

  @override
  String get genuiRepair => 'UI 복구';

  @override
  String get genuiInvalidTitle => '이 UI를 표시할 수 없습니다';

  @override
  String genuiNodesFailed(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '노드 $count개를 표시할 수 없습니다',
      one: '노드 1개를 표시할 수 없습니다',
    );
    return '$_temp0';
  }

  @override
  String genuiErrorLine(int line) {
    return '$line번째 줄';
  }

  @override
  String get genuiValueUnavailable => '값 없음';

  @override
  String get genuiFormulaInvalid => '이 수식을 표시할 수 없습니다';

  @override
  String get genuiNodeUnavailable => '이 구성 요소를 사용할 수 없습니다';

  @override
  String get genuiErrorHeader => '잘못된 UI 헤더';

  @override
  String get genuiErrorVersion => '지원되지 않는 UI 언어 버전';

  @override
  String get genuiErrorCatalog => '지원되지 않는 컴포넌트 카탈로그';

  @override
  String get genuiErrorRoot => '루트 컴포넌트가 없거나 유효하지 않음';

  @override
  String get genuiErrorSyntax => '선언 구문이 올바르지 않음';

  @override
  String get genuiErrorDuplicateSymbol => '같은 이름이 두 번 이상 정의됨';

  @override
  String get genuiErrorDuplicateProperty => '같은 속성이 두 번 이상 정의됨';

  @override
  String get genuiErrorReservedName => '예약된 이름임';

  @override
  String genuiErrorUnknownComponent(String detail) {
    return '알 수 없는 컴포넌트 $detail';
  }

  @override
  String genuiErrorUnknownProperty(String detail) {
    return '알 수 없는 속성 $detail';
  }

  @override
  String genuiErrorMissingProperty(String detail) {
    return '필수 속성 $detail이(가) 없음';
  }

  @override
  String get genuiErrorBinding => '쓰기 가능한 입력 바인딩이 아님';

  @override
  String get genuiErrorReference => '컴포넌트 참조가 유효하지 않음';

  @override
  String get genuiErrorMissingReference => '참조된 콘텐츠가 아직 정의되지 않음';

  @override
  String get genuiErrorDependency => '필요한 콘텐츠를 표시할 수 없음';

  @override
  String get genuiErrorCycle => '순환 참조는 지원되지 않음';

  @override
  String get genuiErrorDuplicateParent => '컴포넌트는 두 개의 부모를 가질 수 없음';

  @override
  String get genuiErrorUnreachableNode => '이 컴포넌트는 루트 트리 밖에 있음';

  @override
  String get genuiErrorType => '값의 타입이 호환되지 않음';

  @override
  String get genuiErrorValue => '값이 지원되는 옵션이나 범위를 벗어남';

  @override
  String get genuiErrorSourceBudget => 'UI 소스가 크기 제한을 초과함';

  @override
  String get genuiErrorDeclarationBudget => '선언 하나가 크기 제한을 초과함';

  @override
  String get genuiErrorDeclarationCount => '선언 수가 너무 많음';

  @override
  String get genuiErrorComponentCount => '컴포넌트 수가 너무 많음';

  @override
  String get genuiErrorInputCount => '입력 수가 너무 많음';

  @override
  String get genuiErrorComponentDepth => '컴포넌트 중첩이 너무 깊음';

  @override
  String get genuiErrorExpressionDepth => '계산 중첩이 너무 깊음';

  @override
  String get genuiErrorFunction => '알 수 없는 계산 함수';

  @override
  String get genuiErrorAction => '지원되지 않는 작업';

  @override
  String get genuiErrorNestedSample => '중첩 샘플링은 지원되지 않음';

  @override
  String get genuiErrorSample => '샘플링 범위 또는 개수가 유효하지 않음';

  @override
  String get genuiErrorDataBudget => '데이터가 지원되는 크기를 초과함';

  @override
  String get genuiErrorRowKey => '각 행에는 비어 있지 않은 고유 키가 필요함';

  @override
  String get genuiErrorDomain => '값이 함수 정의역을 벗어남';

  @override
  String get genuiErrorDivisionByZero => '0으로 나눌 수 없음';

  @override
  String get genuiErrorNonFinite => '계산 결과가 유한한 수가 아님';

  @override
  String get genuiErrorOperationsBudget => '계산 작업량이 한도를 초과함';

  @override
  String genuiMetricTrend(String value) {
    return '변화 $value';
  }

  @override
  String genuiFormErrorsLeft(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count개 항목을 수정해야 합니다',
      one: '1개 항목을 수정해야 합니다',
    );
    return '$_temp0';
  }

  @override
  String get genuiFieldRequired => '필수';

  @override
  String genuiNumberRange(String min, String max) {
    return '범위 $min–$max';
  }

  @override
  String genuiNumberMinimum(String min) {
    return '최솟값 $min';
  }

  @override
  String genuiNumberMaximum(String max) {
    return '최댓값 $max';
  }

  @override
  String genuiFieldTooShort(int min) {
    return '최소 $min자';
  }

  @override
  String genuiFieldTooLong(int max) {
    return '최대 $max자';
  }

  @override
  String get genuiInvalidNumber => '완전한 유한한 수를 입력하세요';

  @override
  String get genuiChooseOption => '옵션을 선택하세요';

  @override
  String get genuiFinishComposing => '계속하려면 입력기 조합을 먼저 완료하세요';

  @override
  String genuiActionDisabledDep(String id) {
    return '비활성화됨: 표시할 수 없는 $id에 의존함';
  }

  @override
  String get genuiActionUnavailable => '이 보기에서는 이 작업을 사용할 수 없음';

  @override
  String get genuiActionDisabled => '이 UI에서 비활성화됨';

  @override
  String get genuiFormUnavailable => '이 양식에 표시할 수 없는 콘텐츠가 포함되어 있음';

  @override
  String genuiDecrease(String label) {
    return '$label 줄이기';
  }

  @override
  String genuiIncrease(String label) {
    return '$label 늘리기';
  }

  @override
  String genuiCharacterCount(int used, int max) {
    return '$used / $max자';
  }

  @override
  String get genuiBlockLimit => '메시지당 최대 3개의 UI 블록이 렌더링되며, 나머지는 소스로 표시됩니다';

  @override
  String get genuiChartLine => '꺾은선 차트';

  @override
  String get genuiChartArea => '영역 차트';

  @override
  String get genuiChartBar => '막대 차트';

  @override
  String get genuiChartScatter => '산점도';

  @override
  String get genuiChartPie => '원형 차트';

  @override
  String get genuiChartDonut => '도넛 차트';

  @override
  String get genuiChartEmpty => '이 범위에 데이터가 없습니다';

  @override
  String get genuiChartAllHidden => '모든 계열이 숨겨져 있습니다. 범례에서 표시할 계열을 선택하세요.';

  @override
  String genuiChartSummary(String kind, int series, int points, int missing) {
    String _temp0 = intl.Intl.pluralLogic(
      series,
      locale: localeName,
      other: '계열 $series개',
    );
    String _temp1 = intl.Intl.pluralLogic(
      points,
      locale: localeName,
      other: '데이터 행 $points개',
    );
    String _temp2 = intl.Intl.pluralLogic(
      missing,
      locale: localeName,
      other: '누락 값 $missing개',
    );
    return '$kind, $_temp0, $_temp1, $_temp2 (연결되지 않거나 0으로 대체됨).';
  }

  @override
  String genuiChartPieSummary(String kind, int count, String total) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '항목 $count개',
    );
    return '$kind, $_temp0, 합계 $total.';
  }

  @override
  String get genuiChartDomainGap => '정의되지 않음';

  @override
  String genuiChartDomainSummary(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '샘플링된 점 $count개가 정의되지 않음',
    );
    return '$_temp0; 음영 처리된 구간은 연결되지 않습니다.';
  }

  @override
  String genuiChartShowSeries(String name) {
    return '$name 표시';
  }

  @override
  String genuiChartHideSeries(String name) {
    return '$name 숨기기';
  }

  @override
  String get genuiChartKeyboardHint =>
      '왼쪽 및 오른쪽 방향키로 데이터 행을, 위 및 아래 방향키로 계열을 선택합니다. Esc 키로 선택을 해제합니다.';

  @override
  String get genuiChartTotal => '합계';

  @override
  String get genuiChartFieldsError => 'X 필드 하나와 서로 다른 Y 필드 1~4개를 선택하세요.';

  @override
  String get genuiChartRecordsError => '차트 데이터는 레코드 목록이어야 합니다.';

  @override
  String get genuiChartXError => 'X 값은 모두 숫자이거나 모두 텍스트여야 합니다. 산점도에는 숫자가 필요합니다.';

  @override
  String get genuiChartYError => 'Y 필드가 존재해야 하며 숫자 또는 누락 값만 포함해야 합니다.';

  @override
  String get genuiChartPieError =>
      '원형 차트 값은 음수가 아니어야 하며, 합계가 0보다 큰 유한한 수여야 합니다.';

  @override
  String genuiChartMissingValues(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '값 $count개가 누락되었으며 0으로 대체되지 않습니다.',
    );
    return '$_temp0';
  }

  @override
  String get genuiChartNoVisibleValues => '선택한 계열에 그릴 값이 없습니다.';

  @override
  String genuiChartUnit(String unit) {
    return '단위: $unit';
  }

  @override
  String get genuiSomeValuesUnavailable => '일부 값을 계산할 수 없습니다';

  @override
  String get genuiViewChart => '차트';

  @override
  String get genuiViewData => '데이터';

  @override
  String get genuiTableFilterHint => '표시된 텍스트 필터링';

  @override
  String genuiTableRows(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count행',
    );
    return '$_temp0';
  }

  @override
  String genuiTablePageInfo(int from, int to, int total) {
    return '$total행 중 $from–$to행';
  }

  @override
  String genuiTablePerPage(int n) {
    return '페이지당 $n행';
  }

  @override
  String get genuiTableEmpty => '일치하는 행이 없습니다';

  @override
  String get genuiSortAsc => '오름차순 정렬됨';

  @override
  String get genuiSortDesc => '내림차순 정렬됨';

  @override
  String get genuiSortNone => '정렬되지 않음';

  @override
  String get genuiValueTrue => '참';

  @override
  String get genuiValueFalse => '거짓';

  @override
  String get genuiTablePreviousPage => '이전 페이지';

  @override
  String get genuiTableNextPage => '다음 페이지';

  @override
  String get genuiTableCellsError => '표 데이터는 유한한 스칼라 값 또는 누락 값을 가진 레코드여야 합니다.';

  @override
  String get genuiTableColumnsError =>
      '서로 다른 필드 1~8개를 선택하고 레이블과 선택적 소수 자릿수(0~10)를 지정하세요.';

  @override
  String get genuiTableRowKeyError => '모든 행에는 null이 아닌 스칼라 키가 필요합니다.';

  @override
  String get genuiViewStateFailed =>
      '이 보기 변경이 저장된 상태 한도를 초과했습니다. 필드를 줄이거나 UI를 재설정한 후 다시 시도하세요.';

  @override
  String get genuiAttachState => '현재 상태 첨부';

  @override
  String get genuiChipExactText => '전송될 정확한 텍스트 (고정됨)';

  @override
  String get genuiChipStale => '소스를 사용할 수 없음 — 제거하거나 다시 첨부하세요';

  @override
  String get genuiChipRemove => '첨부된 UI 제거';

  @override
  String get genuiReplaceTitle => '첨부된 UI를 교체할까요?';

  @override
  String get genuiReplaceBody => '초안에는 UI 상태를 하나만 첨부할 수 있습니다.';

  @override
  String get genuiReplaceCurrent => '현재';

  @override
  String get genuiReplaceNew => '다음으로 교체';

  @override
  String get genuiReplaceConfirm => '교체';

  @override
  String get genuiMergeTitle => '초안에 추가할까요?';

  @override
  String get genuiMergeConfirm => '추가';

  @override
  String get genuiContextEmpty => '첨부된 매개변수 또는 결과 필드가 없습니다.';

  @override
  String get genuiContextOmitted => '[일부 필드 또는 데이터 행이 생략되었습니다.]';

  @override
  String get genuiChipOmitted => '이전에 첨부된 UI 상태를 사용할 수 없어 포함되지 않았습니다.';

  @override
  String get genuiDraftChanged => '초안이 변경되었습니다. 다시 첨부해 주세요.';

  @override
  String get genuiRepairDraft => '아래 진단 및 소스 발췌를 참고하여 이 인터페이스를 수정해 주세요.';

  @override
  String get genuiCopySourceMarkdown => '소스 / Markdown 복사';

  @override
  String get genuiTextFailed => '인터페이스 상태를 읽을 수 없습니다. 다시 시도해 주세요.';

  @override
  String get genuiCopyLimit => '텍스트가 64 KiB 복사 한도를 초과합니다. 더 작은 부분을 선택해 주세요.';

  @override
  String get genuiExportSnapshot => '읽기 전용 스냅샷 내보내기';

  @override
  String get genuiExpandedSharedState => '메시지와 동일한 상태 공유';

  @override
  String get genuiExportTooLarge =>
      '이미지가 1600만 픽셀을 초과합니다. 선택한 메시지를 줄이거나 더 작은 UI를 내보내 주세요.';

  @override
  String get genuiWebTitle => '웹 미리보기';

  @override
  String get genuiWebOpen => '열기';

  @override
  String get genuiWebNotReady => '생성이 완료된 후 열 수 있습니다';

  @override
  String get genuiWebInvalidMeta => '헤더 메타데이터가 유효하지 않아 로드되지 않았습니다';

  @override
  String get genuiWebSandboxNote => '샌드박스 미리보기 · 닫으면 유지되지 않음';

  @override
  String get genuiWebUnsupported =>
      '이 플랫폼에서는 웹 미리보기를 지원하지 않습니다. 내보낸 후 브라우저에서 열어 주세요.';

  @override
  String get genuiWebExportHtml => 'HTML 내보내기';

  @override
  String get genuiWebInfo => '미리보기 정보';

  @override
  String get genuiWebCspNote =>
      'CSP: default-src \'none\' · 네트워크 액세스 제한 · 격리된 페이지 상태';

  @override
  String get genuiWebFailed => '미리보기 초기화 또는 로드에 실패했습니다. 소스를 확인하거나 복사할 수 있습니다.';

  @override
  String get genuiWebEmpty => '헤더 뒤에 HTML 문서가 없습니다';

  @override
  String get genuiWebBlockLimit => '메시지당 최대 3개의 웹 미리보기가 렌더링되며, 나머지는 소스로 표시됩니다';

  @override
  String get genuiWebCloseFailed =>
      '이전 미리보기가 닫혔는지 확인할 수 없습니다. 앱을 다시 시작한 후 다른 미리보기를 열어 주세요.';

  @override
  String get displaySettingsShowGenUiHeader => '대화형 UI 제목 표시줄 표시';

  @override
  String get displaySettingsShowGenUiHeaderSubtitle =>
      '숨기면 메시지가 더 깔끔해집니다. 소스와 작업은 UI 아래 메뉴에서 계속 사용할 수 있습니다.';

  @override
  String get genuiClearFilter => '필터 지우기';

  @override
  String get genuiClearSelection => '선택 지우기';

  @override
  String get chatInputBarQueuedPausedReason => '압축이 아직 진행 중이라 자동으로 전송되지 않습니다.';

  @override
  String get contextChanged => '채팅 내용이 변경되었습니다. 다시 열어 처리할 범위를 확인한 후 계속하세요.';

  @override
  String get contextOperationSuperseded => '이후 요약으로 대체됨';

  @override
  String get compressIncludeAttachments => '첨부 텍스트 및 도구 결과';

  @override
  String contextEditCharacters(int count) {
    return '$count자';
  }

  @override
  String get compressOverSnack =>
      '요약이 여전히 너무 길어 한도를 초과하므로 사용되지 않았습니다. 다시 압축하거나 컨텍스트가 더 큰 모델로 전환하세요.';

  @override
  String get contextSummaryHint =>
      '다음에 모델이 보게 되는 것은 이 요약입니다. 저장은 요약만 변경하며 이미 생성된 응답은 변경하지 않습니다. 첨부 파일은 이미 추출된 텍스트만 사용하며 이미지는 다시 읽지 않습니다.';

  @override
  String get compressAdvanced => '고급';

  @override
  String get compressTaskWaiting => '현재 답변 대기 중';

  @override
  String get contextBudgetExceeded =>
      '현재 요약으로는 다음 메시지가 모델의 한도를 초과합니다. 요약을 줄이거나 다시 압축하거나 컨텍스트가 더 큰 모델로 전환하세요.';

  @override
  String get contextManualSupplement => '수동으로 편집한 요약을 보충으로 포함';

  @override
  String get contextDetailEdited => '수동으로 편집됨';

  @override
  String get contextSourceLabel => '요약 입력';

  @override
  String get contextImpactSourceTitle => '이미 요약에 포함된 원문을 수정하시겠습니까?';

  @override
  String get chatInputBarQueuedCompressionFailed =>
      '압축에 실패하여 이 메시지는 자동으로 전송되지 않습니다.';

  @override
  String contextTokenInfo(int before, int after) {
    return '요약 입력 약 $before 토큰 → 요약 약 $after 토큰';
  }

  @override
  String get worldBookTransferFailed => '항목을 저장하지 못했습니다. 다시 시도해 주세요.';

  @override
  String contextDetailKeptCount(int count) {
    return '최근 사용자 메시지 $count개 및 해당 답변, 도구 과정';
  }

  @override
  String get toolPermissionRequestApproval => '승인 요청';

  @override
  String get compressNothingNew => '지난번 압축 이후 새로 압축할 내용이 없습니다.';

  @override
  String get browserActionScreenshot => '페이지 캡처';

  @override
  String get displaySettingsPageIosNativeSelectionMenuSubtitle =>
      '입력창과 메시지 선택 영역에 적용됩니다. 메뉴가 느리면 끄세요.';

  @override
  String contextUndoneSnack(String from, String to) {
    return '실행 취소됨 · $from → $to';
  }

  @override
  String get toolApprovalByFullAccess => '자동 실행됨';

  @override
  String get displaySettingsPageAutoScrollSubtitle =>
      '켜면 스트리밍 중 맨 아래에 있을 때 새 내용을 자동으로 따라갑니다. 위로 스크롤하면 읽던 위치를 유지하고, 다시 맨 아래로 돌아오면 따라갑니다. 끄면 새 내용이 자동으로 스크롤되지 않습니다.';

  @override
  String get toolApprovalRealTarget => '실제 대상';

  @override
  String get compressTaskRetry => '재시도';

  @override
  String get wsDeniedPathOutside => '대상이 승인된 영역 밖에 있습니다. 거부되었습니다.';

  @override
  String contextImpactSaveConfirm(int count) {
    return '저장하고 이후 관련 작업 $count개 취소';
  }

  @override
  String get contextRestore => '복원';

  @override
  String compressUsageOriginal(String value) {
    return '원래 $value';
  }

  @override
  String toolApprovalPendingKind(String kind) {
    return '승인 대기 중 · $kind';
  }

  @override
  String get contextTaskApplying => '이 요약을 사용하는 중';

  @override
  String get storageSpaceImagesHint =>
      '삭제하면 채팅 이미지와 도구 결과에 영향을 줍니다. 사용 중인 아바타와 배경은 보호됩니다.';

  @override
  String get displaySettingsPageIosNativeSelectionMenuTitle =>
      'iOS 26+ 기본 선택 메뉴';

  @override
  String get worldBookMoveEntries => '이동…';

  @override
  String get compressReread => '압축된 원문 다시 보기';

  @override
  String get chatInputBarQueuedPausedHold =>
      '전송이 일시 중지되었습니다. 편집하거나 바로 전송하려면 대기열을 취소하세요.';

  @override
  String get contextSummaryTitle => '컨텍스트 요약';

  @override
  String get contextKeepInvalid => '사용자 메시지 수를 양의 정수로 입력하세요.';

  @override
  String get compressTaskAbandon => '포기';

  @override
  String get browserAgentTimedOut => '작업 시간 초과, AI 일시 중지됨';

  @override
  String get compressCancelledSnack => '취소되었습니다. 컨텍스트는 변경되지 않았습니다.';

  @override
  String get contextImpactClearTitle => '이전 지우기를 취소하시겠습니까?';

  @override
  String get compressTaskWaitingApproval => '도구 승인을 기다리는 중입니다';

  @override
  String get contextTaskFailed => '압축이 완료되지 않았습니다';

  @override
  String get wsDeniedSkillsReadonly => '스킬 폴더는 읽기 전용입니다.';

  @override
  String get compressTaskMerging => '요약 병합 중';

  @override
  String get toolPermissionFullAccessDesc =>
      '이 대화가 매번 묻지 않고 이 기기의 파일에 접근하고, 명령을 실행하며, 활성화된 온라인 도구를 사용할 수 있도록 허용합니다.';

  @override
  String get compressStaleSnack =>
      '압축이 끝나기 전에 채팅이 변경되어 이번 결과는 사용되지 않았습니다. 원하시면 다시 압축하세요.';

  @override
  String get worldBookCopyEntries => '복사…';

  @override
  String get contextEditEmpty =>
      '요약은 비워 둘 수 없습니다. 이전 채팅을 제외하려면 \'컨텍스트 지우기\'를 사용하세요.';

  @override
  String get toolApprovalDenyWithReason => '이유와 함께 거부…';

  @override
  String get toolApprovalRequestedPath => '요청 경로';

  @override
  String get toolApprovalScopeOnce => '이번 호출에만 적용';

  @override
  String get storageSpaceImageTypeLabel => '유형';

  @override
  String get contextImpactUndoTitle => '이전 압축을 취소할까요?';

  @override
  String get contextOriginalMessages => '원본 메시지 보기';

  @override
  String storageSpaceDeleteImagesConfirmMessage(int count) {
    return '이미지 $count장을 삭제할까요? 관련 채팅 이미지, 도구 스크린샷 및 대화 사본은 더 이상 사용할 수 없습니다. 사용 중인 아바타와 배경은 유지됩니다.';
  }

  @override
  String get chatInputBarQueuedAfterCompress => '압축 완료 후 전송';

  @override
  String get toolPermissionFullAccessDescMobile =>
      '이 대화가 매번 묻지 않고 샌드박스와 승인된 폴더 내에서 도구를 자동으로 실행할 수 있도록 허용합니다.';

  @override
  String get compressTaskAdjustRetry => '옵션 조정 후 재시도';

  @override
  String get contextDetailLegacy => '이전 버전의 지우기 기록에서 이어짐';

  @override
  String get contextDetailCurrent => '현재 컨텍스트';

  @override
  String get toolPermissionUndo => '실행 취소';

  @override
  String get contextDetailViewOriginals => '원본 보기';

  @override
  String get contextTaskCompleted => '압축 완료';

  @override
  String get chatInputBarQueuedPaused => '일시 중지됨';

  @override
  String get contextCompressMarker => '컨텍스트 압축됨';

  @override
  String contextDetailParts(int count) {
    return '자동으로 $count개 부분으로 분할됨';
  }

  @override
  String get contextEditPending => '저장되었습니다. 현재 답변이 끝난 후에 적용됩니다.';

  @override
  String get contextTaskRetry => '압축 다시 시도';

  @override
  String get contextUndoCompressTooltip => '이 압축 실행 취소';

  @override
  String get contextDividerCompressed => '컨텍스트 압축됨';

  @override
  String compressSuccessSnack(String from, String to) {
    return '컨텍스트 압축됨 · $from → $to';
  }

  @override
  String get contextEffectiveHistory => '현재 요약 및 이후 메시지';

  @override
  String get compressRereadAll => '이 구간의 전체 원문';

  @override
  String get contextDone => '완료';

  @override
  String get contextMore => '더 보기';

  @override
  String compressFailedSnack(String reason) {
    return '압축 실패: $reason';
  }

  @override
  String get branchInheritNote => '새 분기는 이 지점 이전까지 유효했던 요약과 원문만 가져옵니다.';

  @override
  String get contextTaskInterrupted => '압축이 중단되었습니다. 입력하신 내용은 그대로 남아 있습니다.';

  @override
  String get storageSpaceImageTypeAll => '전체';

  @override
  String contextRangeInfo(int count, int keep) {
    return '메시지 $count개를 대체하며, 최근 사용자 메시지 $keep개와 그 응답은 그대로 유지합니다.';
  }

  @override
  String contextInputModeInfo(String mode, String source) {
    return '입력: $mode · $source';
  }

  @override
  String get contextDetailKept => '그대로 유지';

  @override
  String worldBookEntriesCopied(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '항목 $count개를 복사했습니다',
      one: '항목 1개를 복사했습니다',
    );
    return '$_temp0';
  }

  @override
  String get toolPermissionSaveFailed => '저장하지 못했습니다. 권한은 변경되지 않았습니다.';

  @override
  String get compressDiscardedSnack =>
      '컨텍스트가 지워졌습니다. 진행 중이던 압축은 취소되어 사용되지 않았습니다.';

  @override
  String get browserActionSelect => '옵션 선택';

  @override
  String get toolPermissionTitle => '권한';

  @override
  String get contextDetailNext => '다음 전송';

  @override
  String get contextTaskCancel => '압축 취소';

  @override
  String get toolPermissionFullAccess => '전체 액세스';

  @override
  String get chatInputBarQueuedCompressionCancelled =>
      '압축이 취소되어 이 메시지는 자동으로 전송되지 않습니다.';

  @override
  String get toolPermissionResetSnack =>
      '작업 공간이 변경됨 · 이 대화의 권한이 승인 요청으로 초기화되었습니다';

  @override
  String get contextImpactUndoOne => '실행 취소';

  @override
  String get contextDetailContinueNewChat => '새 채팅에서 계속';

  @override
  String get contextTaskPaused => '전송이 일시 중지되었습니다. 계속 편집하려면 대기열을 취소하세요.';

  @override
  String get contextTaskReview => '사용하기 전에 요약을 확인해 주세요.';

  @override
  String compressApproxTokens(String value) {
    return '약 $value 토큰';
  }

  @override
  String get storageSpaceImageInUseHint =>
      '삭제하기 전에 해당 설정에서 이 아바타, 배경 또는 아이콘을 변경하거나 제거하세요.';

  @override
  String get compressRereadLastLayer => '마지막 압축 이전의 원문 보기';

  @override
  String get contextRestoreOperation => '작업 복원';

  @override
  String get contextOriginalHistory => '이 구간의 전체 원문 메시지 다시 읽기';

  @override
  String get contextImpactEditTitle => '이 이전 요약을 저장할까요?';

  @override
  String get contextOpenNewChat => '새 채팅 열기';

  @override
  String get wsPathChanged => '승인 대기 중에 대상이 변경되었습니다.';

  @override
  String get contextEditUnknownPreview =>
      '지금은 사용량을 추정할 수 없습니다. 저장 전에 다시 확인합니다.';

  @override
  String get contextTaskWait => '현재 응답과 도구 실행이 끝나기를 기다리는 중';

  @override
  String compressTaskElapsed(int i, int n, int seconds) {
    return '$i/$n 구간 · $seconds초 경과';
  }

  @override
  String get wsContextChanged => '대화가 변경되어 이 요청이 취소되었습니다.';

  @override
  String contextChangeImpact(int count) {
    return '이렇게 하면 이후 관련된 압축 또는 지우기 $count건도 함께 취소됩니다. 원본 채팅은 유지됩니다. 계속할까요?';
  }

  @override
  String get contextImpactSave => '저장';

  @override
  String contextTaskProgress(int done, int total) {
    return '세그먼트 $done/$total 압축 중';
  }

  @override
  String get contextSummaryNotSmaller =>
      '요약이 원문보다 짧지 않습니다. 사용할지 결정하기 전에 확인해 주세요.';

  @override
  String get storageSpaceImageTypeTool => '도구 이미지';

  @override
  String get contextPreviousHistory => '마지막 압축 이전의 원문 다시 보기';

  @override
  String get contextDetailRead => '실제로 읽히는 내용';

  @override
  String get contextViewGenerated => '생성된 요약 보기';

  @override
  String get contextImpactDeleteDescription =>
      '이 원문을 삭제하면 관련 요약과 이를 의존하는 이후 압축도 함께 취소되어, 삭제된 내용이 다시 전송되지 않습니다. 다른 메시지는 영향을 받지 않습니다.';

  @override
  String get storageSpaceImageTypeAvatar => '아바타 및 배경';

  @override
  String get contextDetailAfterUndo => '취소 후';

  @override
  String get contextOperationUndo => '이 작업 취소';

  @override
  String contextHistoryWindowNote(int count) {
    return '그대로 유지된 기록은 여전히 현재 채팅의 \"최대 $count개 메시지 전송\" 제한을 받습니다.';
  }

  @override
  String get contextOverLimitWarning =>
      '취소하면 내용이 모델의 한도를 초과할 수 있습니다. 취소는 가능하며, 전송 전에 다시 확인합니다. 필요하면 다시 압축하세요.';

  @override
  String get storageSpaceImageTypeChat => '채팅 이미지';

  @override
  String get worldBookSelectEntries => '항목 다중 선택';

  @override
  String get compressUsageSummary => '예상 요약';

  @override
  String contextDetailRange(String from, String to, int count) {
    return '$from–$to번째 · 사용자 메시지 $count개';
  }

  @override
  String get contextOperationHidden => '이후에 지우기가 이미 적용되어 이 작업은 더 이상 적용되지 않습니다.';

  @override
  String get contextUndoClearTooltip => '이 지우기 취소';

  @override
  String compressKeepDescription(int count) {
    return '최근 사용자 메시지 $count개와 그 답변 및 도구 활동을 유지합니다. 이전 기록은 요약으로 대체됩니다. 첨부 파일만 있는 메시지도 각각 1개로 계산됩니다.';
  }

  @override
  String get contextOperationUndone => '취소됨';

  @override
  String contextEditPreview(String value) {
    return '저장 후 약 $value 토큰입니다. 편집해도 현재 사용 중인 내용은 즉시 변경되지 않습니다.';
  }

  @override
  String get contextDetailExcluded => '더 이상 전송 안 함';

  @override
  String get worldBookNoMoveTargets => '먼저 다른 세계관 책을 만들어 항목을 이동하세요.';

  @override
  String worldBookSelectedEntries(int count) {
    return '$count개 선택됨';
  }

  @override
  String get contextDetailReplaced => '요약으로 대체된 부분';

  @override
  String get displaySettingsPageAutoScrollEnabledLabel => '켜기';

  @override
  String get contextChangeTitle => '이 변경의 영향을 확인하세요';

  @override
  String get contextDetailTitle => '압축 요약';

  @override
  String get compressModelGlobal => '설정의 모델을 사용하며, 세션 중에는 변경되지 않습니다.';

  @override
  String get wsDeniedMountReadonly => '읽기 전용 마운트라 쓸 수 없습니다.';

  @override
  String get compressRereadDesc =>
      '채팅이 여러 번 압축된 경우 원문을 다시 확인하여 세부 정보 손실을 줄입니다. 이번에는 토큰을 더 사용합니다.';

  @override
  String get toolApprovalSwitchToFullAccess => '완전 액세스로 전환';

  @override
  String get compressUsageInput => '이번 요약 입력';

  @override
  String get contextDetailSummaryLabel => '이후 모델에 전달될 요약';

  @override
  String get contextImpactDeleteTitle => '이미 압축된 원문을 삭제할까요?';

  @override
  String get compressAdvancedOff => '원문 다시 보기: 꺼짐';

  @override
  String get contextOperationActive => '현재 사용 중';

  @override
  String get compressAdvancedOn => '원문 다시 보기: 켜짐';

  @override
  String get contextTaskMerging => '요약 병합 중';

  @override
  String contextSampledInfo(int count) {
    return '이번에는 선택한 $count자만 읽었으며, 요약은 선택한 전체 기록 범위를 대체합니다.';
  }

  @override
  String get contextDividerRunning => '컨텍스트 압축 중';

  @override
  String get contextClearDetails =>
      '이제부터 이전 채팅은 모델에 전송되지 않습니다. 어시스턴트의 시스템 지침, 메모리, 도구는 계속 적용됩니다.';

  @override
  String get compressCopyResult => '결과 복사';

  @override
  String get contextDetailInUse => '현재 사용 중';

  @override
  String get contextImpactDescription =>
      '관련 요약이 함께 취소됩니다. 원본 채팅은 유지되며 모델은 다시 호출되지 않습니다. 다른 무관한 요약은 그대로 유지됩니다.';

  @override
  String get compressIncludeAttachmentsDesc =>
      '이미 추출된 첨부 텍스트와 전체 도구 기록을 원래 순서대로 포함합니다. 이미지는 다시 읽지 않습니다.';

  @override
  String worldBookEntriesMoved(int count) {
    return '항목 $count개 이동됨';
  }

  @override
  String get contextImpactSourceDescription =>
      '확인하면 이 원문이 변경되고, 이를 사용한 요약과 그 요약에 의존하는 이후 압축이 취소됩니다. 다른 채팅은 영향을 받지 않으며 모델은 다시 호출되지 않습니다.';

  @override
  String get contextEditTitle => '요약 편집';

  @override
  String get compressUsageNext => '적용 후, 다음 전송';

  @override
  String get contextSummaryEmpty =>
      '요약은 비워 둘 수 없습니다. 이전 채팅을 포함하지 않으려면 \'컨텍스트 비우기\'를 사용하세요.';

  @override
  String get toolApprovalDenied => '거부됨';

  @override
  String get contextDetailModel => '모델 · 시간';

  @override
  String compressIncludeManual(int count) {
    return '직접 추가한 $count개 항목 포함';
  }

  @override
  String contextBudgetInfo(int used, String limit) {
    return '다음 전송은 약 $used / $limit 토큰을 사용합니다(답변 공간 포함).';
  }

  @override
  String get contextTaskDismiss => '닫기';

  @override
  String contextUndoBudgetInfo(int used) {
    return '취소 후 약 $used 토큰(답변 공간 포함)';
  }

  @override
  String get storageSpaceImageInUse => '사용 중';

  @override
  String get worldBookSelectionDone => '완료';

  @override
  String get contextDividerFailed => '압축이 완료되지 않았습니다';

  @override
  String get toolPermissionUnboundHint =>
      '작업 공간이 연결되지 않음: 이 설정으로는 파일 또는 셸 도구가 활성화되지 않습니다.';

  @override
  String get contextChangeWaiting => '현재 답변과 도구 사용이 끝난 후 이 변경 사항이 적용됩니다.';

  @override
  String storageSpaceDeletedUploadsPartial(int deleted, int kept) {
    return '$deleted개 항목을 삭제했습니다. 사용 중이거나 삭제할 수 없는 $kept개 항목은 유지했습니다.';
  }

  @override
  String get contextSourceScopeHint =>
      '최근 지우기 경계 이후의 기록만 포함됩니다. 평소 전송 범위 밖의 오래된 메시지가 포함될 수 있습니다.';

  @override
  String get contextTaskPreparing => '압축 준비 중';

  @override
  String contextImpactUsage(String from, String to) {
    return '약 $from → $to 토큰';
  }

  @override
  String contextImpactConfirm(int count) {
    return '이후 관련 작업 $count개도 함께 취소';
  }

  @override
  String get contextDividerEdited => '편집됨';

  @override
  String get compressAdjust => '조정';

  @override
  String get compressRegenerate => '다시 압축';

  @override
  String get toolPermissionEnabledSnack => '이 대화에서 전체 접근이 활성화되었습니다';

  @override
  String get contextDetailSuperseded => '이후 요약으로 대체됨';

  @override
  String get contextTaskQueued => '대기 중 — 압축 대기';

  @override
  String get contextNewConversation => '요약으로 새 채팅 만들기';

  @override
  String get contextUnknownLimit => '한도 알 수 없음';

  @override
  String get browserErrActionTimeout =>
      '작업 시간 초과, 결과 미확인. 페이지를 확인한 후 AI가 계속하도록 허용하세요.';

  @override
  String get toolPermissionRequestApprovalDesc =>
      '작업 공간 외부 파일 접근, 데스크톱 명령 및 기타 승인이 필요한 도구는 실행 전에 확인합니다.';

  @override
  String get contextLimitedInputHint =>
      '선택한 문자 범위만 읽습니다. 대체된 기록의 나머지 내용은 요약에 포함되지 않으며 원본 메시지는 계속 확인할 수 있습니다.';

  @override
  String get contextTaskCancelled => '압축이 취소되었습니다';

  @override
  String get contextDetailClearTitle => '컨텍스트가 비워졌습니다';

  @override
  String get contextImpactKeep => '변경 없음';

  @override
  String get contextImpactUndoAlso => '함께 실행 취소';

  @override
  String get contextClearMarker => '컨텍스트가 비워졌습니다';

  @override
  String get toolPermissionScopeThisChat => '이 대화만';

  @override
  String get dataDirectoryTitle => '데이터 디렉터리';

  @override
  String get dataDirectoryChange => '디렉터리 변경';

  @override
  String get dataDirectoryChoose => '빈 로컬 폴더 선택';

  @override
  String get dataDirectoryHint =>
      '로컬 드라이브의 빈 폴더를 선택하세요. 채팅 기록, 첨부 파일 및 앱 관리 파일은 재시작 후 이동됩니다. 일부 기기 설정과 시스템 캐시는 시스템 위치에 그대로 유지됩니다.';

  @override
  String get dataDirectoryPendingHint =>
      '다음 재시작 시 이동됩니다. 복사 및 검증이 완료될 때까지 현재 데이터는 그대로 유지됩니다. 대상:';

  @override
  String get dataDirectoryRestart => '재시작하고 데이터 이동';

  @override
  String get dataDirectoryCancelMove => '이동 취소하고 원래 디렉터리 사용';

  @override
  String get dataDirectoryPreviousHint =>
      '원본 데이터 사본이 유지되었습니다. 새 디렉터리가 정상적으로 시작된 후 디스크 공간을 확보하려면 이전 사본을 정리할 수 있습니다. 디렉터리를 다시 변경하기 전에 먼저 정리하세요.';

  @override
  String get dataDirectoryCleanPrevious => '원본 사본 정리';

  @override
  String get dataDirectoryCleanConfirm =>
      '아래 디렉터리의 유지된 사본을 제거할까요? 현재 디렉터리의 데이터는 유지되며, 이동 후 변경된 파일은 삭제되지 않습니다.';

  @override
  String get dataDirectoryMoving => '데이터 이동 및 검증 중… Kelivo를 열어 두세요.';

  @override
  String get dataDirectoryStartupFailed => '데이터 디렉터리를 열 수 없습니다';

  @override
  String get dataDirectoryRetry => '재시도';

  @override
  String get dataDirectoryUnavailable =>
      '데이터 디렉터리를 사용할 수 없습니다. 드라이브를 다시 연결하거나 폴더를 원래 위치로 복원한 후 재시도하세요. 빈 데이터베이스는 생성되지 않습니다.';

  @override
  String get dataDirectoryIdentityMismatch =>
      '이 폴더는 설정된 데이터 디렉터리와 일치하지 않습니다. 원래 폴더를 복원한 후 재시도하세요.';

  @override
  String get dataDirectoryNotEmpty => '빈 폴더를 선택하세요. 기존 파일은 덮어쓰지 않습니다.';

  @override
  String get dataDirectoryOverlap =>
      '현재 데이터 디렉터리 밖의 별도 폴더를 선택하세요. 상위 폴더와 드라이브 루트는 사용할 수 없습니다.';

  @override
  String get dataDirectoryLocalOnly => '네트워크 공유 대신 로컬 드라이브를 선택하세요.';

  @override
  String get dataDirectoryFinishPrevious =>
      '대기 중인 이동을 완료하거나 취소하고, 보관된 복사본을 정리한 후 다른 디렉터리를 선택하세요.';

  @override
  String get dataDirectoryPendingRestore =>
      '백업 복원이 대기 중입니다. 디렉터리 이동을 취소하고 재시작하여 복원을 완료한 후 다시 이동하세요.';

  @override
  String get dataDirectorySourceChanged =>
      '복사 후 원본 데이터가 변경되었습니다. 원본은 보관되었습니다. 새 이동을 시작하기 전에 대기 중인 이동을 취소하세요. 보관된 복사본은 직접 확인할 수 있습니다.';

  @override
  String get dataDirectoryCopyChanged =>
      '대상에 예상치 못한 파일이나 변경된 파일이 있습니다. 원본 데이터는 보관되었습니다. 대상 폴더를 확인한 후 다시 시도하세요.';

  @override
  String get dataDirectoryGenericError =>
      '작업을 완료하지 못했습니다. 디스크 여유 공간, 폴더 권한, 다른 Kelivo 프로세스 실행 여부를 확인한 후 다시 시도하세요. 기존 데이터는 보관되었습니다.';

  @override
  String get dataDirectoryCancelHint =>
      '취소하면 대상에 이미 복사된 파일은 유지됩니다. 해당 부분 복사본은 직접 확인하고 삭제할 수 있습니다.';

  @override
  String providerDetailPageBaseUrlExample(String url) {
    return '예: $url';
  }

  @override
  String get providerDetailPageApiKeyExample => '예: sk-…';

  @override
  String get providerDetailPageRequestUrlLabel => '요청 URL';

  @override
  String providerDetailPageUrlWillAppendVersion(String v) {
    return 'URL에 버전이 없습니다. 입력란을 벗어나면 $v이(가) 추가됩니다';
  }

  @override
  String providerDetailPageUrlAppendedVersion(String v) {
    return '$v이(가) 자동으로 추가되었습니다';
  }

  @override
  String get providerDetailPageUrlTrimmedSlash => '끝의 /를 제거했습니다';

  @override
  String providerDetailPageUrlMovedPath(String path) {
    return '전체 엔드포인트가 감지되어 $path을(를) API 경로로 이동했습니다';
  }

  @override
  String get providerDetailPageUrlEmptyError => '요청을 보내려면 필수입니다';

  @override
  String get providerDetailPageUrlInvalidError =>
      '잘못된 URL입니다. http:// 또는 https://로 시작해야 합니다';

  @override
  String get providerDetailPageRestoreDefaultTooltip => '기본값 복원';

  @override
  String get providerDetailPageClearTooltip => '지우기';

  @override
  String providerDetailPageTestSuccessWithLatency(String ms) {
    return '성공 · $ms ms';
  }

  @override
  String providerDetailPageTestFailedWithCode(String code) {
    return '실패 · $code';
  }

  @override
  String providerDetailPageTestHintMissingVersion(String url) {
    return 'URL에 버전이 없을 수 있습니다. $url을(를) 사용해 보세요';
  }

  @override
  String providerAutoVersionAdded(String v) {
    return '$v이(가) 자동으로 추가되었습니다';
  }

  @override
  String get providerUndo => '실행 취소';

  @override
  String get sidePanelToggle => '사이드 패널 전환';

  @override
  String get sidePanelFiles => '파일';

  @override
  String get sidePanelTopics => '주제';

  @override
  String get sidePanelExpand => '패널 확장';

  @override
  String get sidePanelCollapse => '확장 종료';

  @override
  String get sidePanelAllTabs => '모든 탭';

  @override
  String sidePanelMoreTabs(int count) {
    return '$count개 더';
  }

  @override
  String get sidePanelSearchTabs => '탭 검색';

  @override
  String get sidePanelOpenFile => '파일 열기…';

  @override
  String get sidePanelCloseOthers => '다른 탭 닫기';

  @override
  String get sidePanelCloseRight => '오른쪽 탭 닫기';

  @override
  String get sidePanelReopenTab => '닫은 탭 다시 열기';

  @override
  String get sidePanelPinned => '고정됨 · 닫을 수 없음';

  @override
  String get sidePanelMoveTopicsLeft => '주제를 왼쪽으로 다시 이동…';

  @override
  String get sidePanelPinnedHint =>
      '주제는 오른쪽에 있는 동안 고정됩니다. 설정 › 표시 › 주제 위치에서 변경하세요.';

  @override
  String get sidePanelEvictedTitle => '페이지 언로드됨';

  @override
  String sidePanelEvictedBody(int count) {
    return '메모리 절약을 위해 백그라운드에서 언로드되었습니다(백그라운드 페이지 최대 $count개 유지). 다시 로드하여 계속 탐색하세요.';
  }

  @override
  String get sidePanelEvictedTooltip => '언로드됨 · 계속하려면 다시 로드';

  @override
  String get sidePanelFileMissing => '파일을 사용할 수 없음';

  @override
  String sidePanelFileMissingBody(String path) {
    return '$path이(가) 삭제되었거나 이동되었습니다.';
  }

  @override
  String get sidePanelRelocate => '다시 찾기';

  @override
  String sidePanelBackgroundIn(String topic) {
    return '“$topic”에서 실행 중';
  }

  @override
  String sidePanelWidth(int px) {
    return '${px}px';
  }

  @override
  String get sidePanelWidthMax => '최대';

  @override
  String get sidePanelWidthMin => '최소';

  @override
  String get sidePanelRecentFiles => '최근 출력 및 첨부 파일';

  @override
  String get sidePanelOpenExternalUrl => '시스템 브라우저에서 URL 열기…';

  @override
  String get sidePanelWebPages => '웹 페이지';

  @override
  String get hotkeyToggleSidePanel => '사이드 패널 전환';

  @override
  String get hotkeySidePanelNewWeb => '새 웹 탭';

  @override
  String get hotkeySidePanelFiles => '파일 표시';

  @override
  String get hotkeySidePanelExpand => '사이드 패널 확장';

  @override
  String get hotkeySidePanelReopenTab => '닫은 탭 다시 열기';

  @override
  String get hotkeySidePanelNextTab => '다음 패널 탭';

  @override
  String get hotkeySidePanelPreviousTab => '이전 패널 탭';

  @override
  String get hotkeySidePanelAddress => '웹 주소로 이동';

  @override
  String get hotkeySidePanelFocus => '채팅과 패널 포커스 전환';

  @override
  String get selectionQuote => '인용';

  @override
  String selectionQuoteMarker(int index) {
    return '[인용 $index]';
  }

  @override
  String get selectionTranslate => '번역';

  @override
  String get selectionAiTranslateIos => 'AI 번역';

  @override
  String get selectionCopyMarkdown => 'Markdown으로 복사';

  @override
  String get selectionCopyRich => '서식 있는 텍스트로 복사';

  @override
  String get quoteJumpToSource => '원문으로 이동';

  @override
  String get quoteRemove => '인용 제거';

  @override
  String get quoteDuplicate => '이미 인용된 내용입니다';

  @override
  String get quoteLimit => '메시지당 최대 10개까지 인용할 수 있습니다';

  @override
  String get quoteLocated => '인용된 원문으로 이동했습니다';

  @override
  String get quoteSourceMissing => '원문이 더 이상 존재하지 않습니다';

  @override
  String get selectionRegenerate => '다시 생성';

  @override
  String get translating => '번역 중…';

  @override
  String get retry => '다시 시도';

  @override
  String get recoveryGuideTitle => '채팅을 복구해 보겠습니다';

  @override
  String get recoveryGuideBody =>
      'Kelivo가 데이터 로드를 일시 중지했습니다. 로컬 사본을 찾아 복구할 항목을 선택할 수 있도록 합니다. 기존 파일은 유지됩니다.';

  @override
  String get recoverySpaceTitle => '약간의 여유 공간이 필요합니다';

  @override
  String get recoveryChecksNeedSpace =>
      '로컬 사본을 찾았지만 공간이 부족하여 확인할 수 없습니다. 사본이 손상되었다는 의미는 아닙니다. 공간을 확보한 후 다시 확인하세요.';

  @override
  String get recoveryChecksUnavailable =>
      '일부 로컬 사본을 아직 확인할 수 없습니다. 해당 파일은 그대로 유지됩니다. 다시 확인하거나 데이터를 내보내 도움을 요청하세요.';

  @override
  String get recoveryRecheckCopies => '로컬 사본 다시 확인';

  @override
  String get recoveryCopyPreview => '사본 미리보기';

  @override
  String get recoveryRestoreRetryBody =>
      '복구를 완료하지 못했습니다. 선택한 사본은 유지되었습니다. 로컬 사본을 다시 확인하거나 Kelivo를 다시 열어 계속하세요.';

  @override
  String recoverySpaceAmount(String required, String available) {
    return '마지막 확인: 사용 가능 $available; 데이터를 안전하게 준비하려면 최소 $required의 여유 공간이 필요합니다.';
  }

  @override
  String get recoveryCopiesNeedUpdate =>
      '일부 사본은 최신 버전의 Kelivo에서 생성되었습니다. 해당 사본을 복구하려면 Kelivo를 업데이트하세요. 이 사본들은 유지되었습니다.';

  @override
  String get imageContextAllowRecall => '모델이 이미지를 다시 불러오도록 허용';

  @override
  String get imageContextAllowRecallDescription =>
      'view_image가 필요할 때 이 대화의 이전 이미지를 다시 불러올 수 있도록 합니다. 이 기능을 끄더라도 메시지와 함께 직접 전송된 이미지, 자동 이미지 관리, 작업 공간 파일 접근에는 영향을 주지 않습니다.';

  @override
  String get imageContextTitle => '이미지 컨텍스트';

  @override
  String get imageContextAutomatic => '기록 이미지 자동 관리';

  @override
  String get imageContextDescription =>
      '이번 턴에 포함되는 이미지를 관리합니다. 원본은 채팅에 그대로 유지됩니다.';

  @override
  String get imageContextIncluded => '포함됨';

  @override
  String get imageContextOmitted => '포함되지 않음';

  @override
  String get imageContextPin => '이미지 고정';

  @override
  String get imageContextUnpin => '고정 해제';

  @override
  String get imageContextAttachAgain => '입력창에 다시 추가';

  @override
  String get imageContextEmpty => '아직 이미지가 없습니다';

  @override
  String get imageContextUnavailable => '현재 컨텍스트에서 이 이미지를 사용할 수 없습니다.';

  @override
  String get imageContextEntryDescription => '이번 턴에 사용할 이미지 검토 및 관리';

  @override
  String get imageContextAutomaticDescription =>
      '업로드한 첨부 파일을 더 오래 유지하고 오래된 도구 이미지는 따로 보관합니다.';

  @override
  String get imageContextActionsHint => '고정하여 우선 유지하거나 입력창에 다시 추가하세요.';

  @override
  String get imageContextEmptyDescription => '보내거나 도구가 읽은 이미지가 여기에 표시됩니다.';

  @override
  String get imageContextUserImages => '내 이미지';

  @override
  String get imageContextToolImages => '도구 이미지';

  @override
  String get imageContextAssistantImages => '생성된 이미지';

  @override
  String imageContextImageNumber(int index) {
    return '이미지 $index';
  }

  @override
  String imageContextIncludedCount(int included, int total) {
    return '$total개 중 $included개 이미지 포함';
  }

  @override
  String get imageContextMissing => '사용 불가';

  @override
  String get imageContextLoadFailed => '이미지를 불러올 수 없습니다. 다시 시도하세요.';

  @override
  String get imageContextUpdateFailed => '변경 사항을 저장할 수 없습니다. 다시 시도하세요.';

  @override
  String get contextOperationsTitle => '압축 및 기록 비우기';

  @override
  String get contextOperationsLoadMore => '더 보기';

  @override
  String get contextOperationsDescription =>
      '압축 및 비우기 기록을 확인하고 필요하면 취소할 수 있습니다.';

  @override
  String get contextOperationsEmpty => '아직 압축 또는 비우기 기록이 없습니다.';

  @override
  String contextOperationsStored(int count) {
    return '저장된 채팅: 메시지 $count개';
  }

  @override
  String contextOperationsEffective(int summaries, int messages) {
    return '다음 전송에는 요약 $summaries개와 원문 메시지 $messages개가 포함됩니다.';
  }

  @override
  String get contextOperationsScope =>
      '현재 기록 개수 한도를 기준으로 계산했습니다. 시스템 지침, 메모리, 도구, 아직 전송하지 않은 입력은 별도로 컨텍스트에 추가됩니다. 기록을 열면 요약, 해당 원문 범위를 확인하거나 취소할 수 있습니다.';

  @override
  String get contextOperationsLoadFailed => '이 기록을 불러올 수 없습니다. 다시 시도해 주세요.';

  @override
  String get compressNewConversation => '새 채팅으로 압축';

  @override
  String get compressNewConversationDescription =>
      '켜면 요약과 유지된 메시지로 새 채팅을 만들고 원래 채팅은 변경하지 않습니다. 끄면 현재 채팅에서 바로 압축합니다.';

  @override
  String get contextViewBoundary => '컨텍스트가 비워진 위치로 이동';

  @override
  String get contextFixedStart => '고정 컨텍스트 시작';

  @override
  String get contextSetFixedStart => '여기서 컨텍스트 시작';

  @override
  String get contextCancelFixedStart => '고정 컨텍스트 시작 취소';

  @override
  String get contextFixedStartDescription =>
      '이 메시지부터 기록을 전송하며, 순환 메시지 수 제한을 적용하지 않습니다.';

  @override
  String get contextBeforeFixedStart =>
      '이 메시지는 고정 컨텍스트 시작 이전에 있습니다. 다시 생성하기 전에 시작 지점을 이동하거나 취소하세요.';

  @override
  String get contextRegenerateFixedStart =>
      '이 답변이 고정 컨텍스트 시작이므로 해당 질문은 제외됩니다. 다시 생성하기 전에 시작 지점을 더 이전 메시지로 이동하거나 취소하세요.';

  @override
  String get responseSpeedLabel => '응답 속도';

  @override
  String get responseSpeedStandard => '표준';

  @override
  String get responseSpeedUsageHint => '빠른 모드는 더 많은 할당량 또는 크레딧을 사용합니다.';

  @override
  String get responseSpeedLoading => '사용 가능 여부 확인 중…';

  @override
  String get responseSpeedUnavailable => '이 모델에서 사용할 수 있는 가속 등급이 없습니다.';

  @override
  String get responseSpeedSaveFailed => '응답 속도를 저장할 수 없습니다. 다시 시도하세요.';

  @override
  String responseSpeedRequestFailed(String mode) {
    return '$mode 요청에 실패했습니다. 모델 및 계정 지원 여부를 확인하거나 표준 모드로 전환하여 다시 시도하세요.';
  }

  @override
  String get responseSpeedSelectionUnavailable =>
      '저장된 속도를 더 이상 사용할 수 없습니다. 이 채팅은 표준 모드를 사용합니다.';

  @override
  String get responseSpeedProviderDependent => '지원 여부는 공급자에 따라 다릅니다.';

  @override
  String responseSpeedTapTo(String mode) {
    return '탭하여 $mode(으)로 전환';
  }

  @override
  String get responseSpeedUltrafastNeedsResponses =>
      'UltraFast는 Responses API가 필요합니다.';

  @override
  String get compressionTemplate => '요약 템플릿';

  @override
  String get compressionGeneral => '일반';

  @override
  String get compressionCode => '코드';

  @override
  String get compressionWriting => '글쓰기';

  @override
  String get compressionResearch => '연구';

  @override
  String get compressionRoleplay => '역할극';

  @override
  String get compressionOriginalPrompt => '내 원본 프롬프트';

  @override
  String get compressionMore => '추가 설정';

  @override
  String get compressionFocus => '이번에 중점적으로 남길 내용';

  @override
  String get compressionFocusHint => '선택 사항: 핵심 결정, 진행 상황 또는 캐릭터 세부 정보';

  @override
  String get compressionForConversation => '이 대화에 적용';

  @override
  String get compressionFollowGlobal => '전역 기본값 따르기';

  @override
  String get compressionSetGlobal => '전역 기본값으로 설정';

  @override
  String get compressionGlobalDescription =>
      '전역 기본값을 따르는 대화에만 적용됩니다. 별도 설정이 있는 대화는 변경되지 않습니다.';

  @override
  String get compressionAutoTitle => '자동 압축';

  @override
  String get compressionAutoOff => '끔';

  @override
  String get compressionAutoNotify => '알림만';

  @override
  String get compressionAutoOn => '자동';

  @override
  String get compressionNearLimit =>
      '이 대화가 모델이 기억할 수 있는 한도에 가까워졌습니다. 계속 보내거나 먼저 압축할 수 있습니다.';

  @override
  String get compressionKeepTurns => '최근 유지';

  @override
  String get compressionKeepHint => '한 턴은 사용자 메시지 하나와 그 뒤의 답변 및 도구 내용을 포함합니다.';

  @override
  String get compressionLength => '요약 길이(토큰)';

  @override
  String get compressionTrigger => '사용량 도달 시';

  @override
  String get compressionTarget => '압축 목표';

  @override
  String get compressionWindow => '요약 모델 용량';

  @override
  String get compressionRequests => '최대 요청 수';

  @override
  String get compressionReference => '세계관 책과 과거 기억 참조';

  @override
  String get compressionReferenceHint =>
      '이번에 압축할 기록만을 기준으로 세계관을 찾고, 당시 저장된 메모리를 사용합니다. 이 내용은 모델이 인물 이름과 규칙을 이해하도록 돕기 위한 것일 뿐, 해당 사건이 발생했다거나 캐릭터가 이미 알고 있다는 의미가 아닙니다.';

  @override
  String get compressionToolReferences => '이미 읽은 도구 결과는 참조만 유지';

  @override
  String get compressionToolReferencesHint =>
      '도구를 사용할 수 있을 때만 적용됩니다. 최신 미확인 결과는 전체 유지되고, 이미 읽은 결과는 참조로만 남아 필요할 때 원본 기록을 다시 볼 수 있지만 수정할 수는 없습니다.';

  @override
  String get compressionSummaryScan => '압축된 요약도 세계관 키워드 매칭에 사용';

  @override
  String get compressionChatModel => '현재 대화 모델 따르기';

  @override
  String get compressionManageTemplates => '템플릿 및 레시피 관리';

  @override
  String get compressionLocalPreview => '요청 미리보기 · 모델 호출 없음';

  @override
  String get compressionTry => '요약 시험 생성 · 모델 토큰 사용';

  @override
  String get compressionPreviewOnly => '먼저 미리보기를 생성합니다. 확인한 후 사용할지 결정하세요.';

  @override
  String get compressionTemplateChanged =>
      '새 템플릿은 앞으로 생성되는 요약에만 적용됩니다. 이미 생성된 요약은 그대로 유지됩니다. 세부 내용을 채우려면 원문에서 다시 생성하세요.';

  @override
  String compressionRange(int count, int turns) {
    return '$count개 메시지 압축 · $turns개 사용자 턴 원문 유지';
  }

  @override
  String compressionCalls(int count) {
    return '모델 요청 $count회';
  }

  @override
  String get compressionActualUsage => '요약 모델 실제 사용량';

  @override
  String compressionUsageValues(String input, String output) {
    return '입력 $input · 출력 $output 토큰';
  }

  @override
  String compressionUsageUnknown(int count) {
    return '$count회 요청이 사용량 데이터를 반환하지 않았습니다. 무료였다는 뜻은 아닙니다.';
  }

  @override
  String get compressionBudgetError =>
      '현재 한도보다 더 많은 모델 요청이 필요하므로 컨텍스트가 변경되지 않았습니다. 최대 요청 수를 높이거나 컨텍스트가 더 큰 모델로 전환하세요.';

  @override
  String get compressionIncomplete =>
      '요약이 중단되었거나 거부되어 컨텍스트가 변경되지 않았습니다. 출력 한도를 높이거나 다른 모델을 사용해 보세요.';

  @override
  String get compressionReferenceTooLarge =>
      '참고 자료가 이미 이 모델의 용량을 채워 요약할 공간이 없습니다. 참고 자료를 줄이거나 컨텍스트가 더 큰 모델로 전환하세요.';

  @override
  String get compressionReferenceChanged =>
      '참조한 배경이 변경되었습니다. 이 요약을 검토하거나 새로 생성하세요.';

  @override
  String get compressionTargetNotReached =>
      '압축 후에도 사용량이 자동 시작 지점보다 높아 원래 컨텍스트가 유지되었습니다. 요약을 더 줄이거나 시작 지점을 높이세요.';

  @override
  String get compressionTemplateMissing =>
      '선택한 템플릿을 사용할 수 없습니다. 다른 템플릿을 선택하세요.';

  @override
  String get compressionTemplates => '템플릿';

  @override
  String get compressionRecipes => '레시피';

  @override
  String get compressionNewTemplate => '새 템플릿';

  @override
  String get compressionEditTemplate => '템플릿 편집';

  @override
  String get compressionRestoreDefault => '기본값 복원';

  @override
  String get compressionCopyEdit => '복사 후 편집';

  @override
  String get compressionTemplateName => '이름';

  @override
  String get compressionPrompt => '요약 지시문';

  @override
  String get compressionLanguage => '출력 언어';

  @override
  String get compressionLanguageConversation => '대화 따르기';

  @override
  String get compressionLanguageLegacy => '원본 템플릿의 언어 설정 유지';

  @override
  String get compressionLanguageHint =>
      '언어 이름이나 코드를 입력하세요. conversation(대화 따르기) 또는 legacy(원본 템플릿 유지)를 사용할 수도 있습니다.';

  @override
  String get compressionVariables =>
      '다음 변수를 사용할 수 있습니다. 프롬프트에 기록이 포함되지 않으면 자동으로 추가됩니다:';

  @override
  String get compressionDeleteTemplate =>
      '대체 템플릿을 선택하고 이 템플릿을 삭제할까요? 이미 사용 중인 요약과 레시피에 저장된 사본은 유지됩니다.';

  @override
  String compressionTemplateReferences(int count) {
    return '$count개 채팅에서 개별 재정의로 사용 중입니다.';
  }

  @override
  String get compressionSaveRecipe => '현재 설정을 레시피로 저장';

  @override
  String get compressionBindModel => '현재 선택한 요약 모델도 함께 저장';

  @override
  String get compressionRecipeHint =>
      '레시피를 저장하거나 가져와도 자동 압축이 켜지지 않으며 현재 채팅에 적용되지 않습니다. 레시피가 라이브러리에 추가될 뿐입니다.';

  @override
  String get compressionImport => 'JSON 가져오기';

  @override
  String get compressionExport => 'JSON 내보내기';

  @override
  String get compressionCopyJson => 'JSON 복사';

  @override
  String get compressionApplyRecipe => '레시피 적용';

  @override
  String get compressionInvalidSettings =>
      '다음 값을 확인하세요: 압축 대상은 시작 지점보다 낮아야 하며, 요청 및 토큰 한도는 0보다 커야 합니다.';

  @override
  String get compressionOverflowAction => '한 번 압축한 후 실패한 응답 다시 시도';

  @override
  String compressionPlannedCalls(int count, int limit) {
    return '예상 $count회 요청 · 이번 한도 $limit회(재시도 포함)';
  }

  @override
  String get compressionGlobalTemplateReference => '전역 기본값으로도 사용됩니다.';

  @override
  String compressionRecipeReferences(int count) {
    return '$count개 레시피가 그 시점의 템플릿 사본을 각각 보관합니다.';
  }

  @override
  String get compressionReplacementTemplate => '대체 템플릿';

  @override
  String get compressionGeneralDescription => '현재 주제, 결정 사항, 미해결 질문을 유지합니다.';

  @override
  String get compressionCodeDescription => '코드 변경, 실제 검증, 다음 엔지니어링 단계를 구분합니다.';

  @override
  String get compressionWritingDescription => '채택된 텍스트, 구조, 문체, 편집 제약을 보존합니다.';

  @override
  String get compressionResearchDescription => '근거, 출처, 측정값, 불확실성을 유지합니다.';

  @override
  String get compressionRoleplayDescription =>
      '장면 연속성, 인물 상태, 각 인물의 지식 범위를 유지합니다.';

  @override
  String compressionLastUsed(String date) {
    return '최근 사용: $date';
  }

  @override
  String get compressionManage => '관리';

  @override
  String get compressionOutputSettings => '요약 설정';

  @override
  String get compressionSourceSettings => '참조 및 원문';

  @override
  String get compressionSavedSettings => '미리보기 및 저장된 설정';

  @override
  String get compressionNoRecipes => '저장된 레시피가 없습니다';

  @override
  String get compressionNoTemplatesFound => '일치하는 템플릿이 없습니다';

  @override
  String get compressionBuiltIn => '내장';

  @override
  String get compressionGlobalDefault => '전역 기본값';

  @override
  String get compressionCustomLanguage => '기타 언어';

  @override
  String get compressionCustomLanguageHint => '언어 이름 또는 코드, 예: 일본어 / ja';

  @override
  String get compressionLibraryTitle => '템플릿 및 레시피';

  @override
  String get compressionBuiltInTemplates => '내장 템플릿';

  @override
  String get compressionMyTemplates => '내 템플릿';

  @override
  String get compressionSearchTemplates => '템플릿 검색';

  @override
  String get compressionSearchRecipes => '레시피 검색';

  @override
  String get compressionRecipeCreateHint =>
      '「추가 설정」에서 현재 구성을 레시피로 저장하여 재사용하세요.';

  @override
  String get compressionTurnUnit => '턴';

  @override
  String get compressionCallUnit => '회';

  @override
  String get compressionRequestTimeout => '압축 요청 시간 초과';

  @override
  String get compressionMinuteUnit => '분';

  @override
  String get compressionRequestTimeoutDefault => '기본값';

  @override
  String get compressionRequestTimeoutHint =>
      '0보다 큰 분 단위 숫자를 입력하세요. 비워 두면 현재 기본값(서버 측 압축은 5분)이 유지됩니다. 부분별로 요약할 때는 각 부분과 병합에 별도로 시간이 적용됩니다.';

  @override
  String compressionRequestTimedOut(num minutes) {
    return '압축이 $minutes분 후 중단되었으며 컨텍스트는 변경되지 않았습니다. 다시 시도하거나 시간 초과를 늘리세요.';
  }

  @override
  String get compressionAdvancedOptions => '압축 세부 정보';

  @override
  String get compressionAdvancedHint => '참고 자료, 원문 다시 보기 여부, 요청 한도';

  @override
  String get compressionAutomaticWindow => '자동';

  @override
  String get compressionAutoOffHint => '필요할 때 압축 페이지에서 수동으로 시작할 수 있습니다.';

  @override
  String get compressionAutoNotifyHint =>
      '사용량이 한도에 가까워지면 알림을 받고, 압축 시점은 직접 결정합니다.';

  @override
  String get compressionAutoOnHint =>
      '사용량이 설정한 비율에 도달하면 이전 기록이 자동으로 요약됩니다. 추가 모델 토큰이 사용됩니다.';

  @override
  String get compressionBudgetHint => '이 백분율은 아직 사용 가능한 입력 용량을 기준으로 계산됩니다.';

  @override
  String get compressionPreviewAction => '로컬 미리보기';

  @override
  String get compressionSaveRecipeAction => '레시피 저장';

  @override
  String get compressionManualRange => '이번 압축 범위';

  @override
  String get compressionScopeKeepHint =>
      '최근 몇 턴은 원문 그대로 유지하고 이전 기록을 요약합니다. 자동 압축도 같은 턴 수를 사용합니다.';

  @override
  String get compressionScopeAllHint =>
      '현재 컨텍스트의 모든 기록을 요약하며 최근 원문을 따로 유지하지 않습니다. 원본 메시지는 여전히 볼 수 있습니다.';

  @override
  String get compressionScopeStartHint =>
      '글자 수 한도 내에서 이전의 완전한 메시지를 압축합니다. 선택되지 않은 메시지는 원문으로 유지됩니다.';

  @override
  String get compressionScopeRecentHint =>
      '글자 수 한도 내에서 최근의 완전한 메시지를 압축합니다. 선택되지 않은 메시지는 원문으로 유지됩니다.';

  @override
  String get compressionAutoKeepHint =>
      '자동 압축은 수동 실행에서 선택한 범위와 관계없이 항상 최근 원문을 유지합니다. 턴 수는 수동 압축과 공유됩니다.';

  @override
  String get requestBudgetTitle => '이미지 및 요청 예산';

  @override
  String get requestBudgetInherited => '상속됨';

  @override
  String get requestBudgetCustom => '사용자 지정';

  @override
  String get requestBudgetReset => '기본값 복원';

  @override
  String get requestBudgetSingleImage => '단일 이미지 (MiB)';

  @override
  String get requestBudgetTotalImages => '전체 이미지 (MiB)';

  @override
  String get requestBudgetImageCount => '이미지 수';

  @override
  String get requestBudgetBody => '요청 본문 (MiB)';

  @override
  String get requestBudgetProviderHelp =>
      '전송 전 로컬 검사이며 공급자 한도가 아닙니다. 비워 두면 표시된 기본값을 사용합니다. 이미지 크기는 Base64 인코딩을 포함하며, 요청 크기는 전체 JSON 본문을 포함합니다.';

  @override
  String get requestBudgetModelHelp =>
      '이 모델의 로컬 전송 한도를 재정의합니다. 비워 두면 표시된 공급자 설정을 상속합니다. 이미지 크기는 Base64 인코딩을 포함하며, 요청 크기는 전체 JSON 본문을 포함합니다.';

  @override
  String get requestBudgetRetentionHelp =>
      '한도를 높여도 자동으로 보관되는 기록 이미지가 늘어나지 않습니다. 이미지를 고정하여 보관하세요. 예산이 클수록 기기 메모리 사용량이 증가할 수 있습니다.';

  @override
  String get requestBudgetInvalid =>
      '양수 크기와 양의 정수 이미지 수를 입력하거나, 필드를 비워 두어 상속하세요.';

  @override
  String requestBudgetBytes(String mib, int bytes) {
    return '$mib MiB ($bytes 바이트)';
  }

  @override
  String requestBudgetSingleError(int index, String actual, String limit) {
    return 'Kelivo 로컬 사전 검사: 이미지 $index의 인코딩 크기가 $actual로 단일 이미지 한도 $limit을(를) 초과했습니다.';
  }

  @override
  String requestBudgetTotalError(String actual, String limit) {
    return 'Kelivo 로컬 사전 검사: 인코딩된 이미지 합계가 $actual로 이미지 예산 $limit을(를) 초과했습니다.';
  }

  @override
  String requestBudgetCountError(String actual, int limit) {
    return 'Kelivo 로컬 사전 검사: 요청에 이미지가 $actual개 포함되어 한도 $limit개를 초과했습니다.';
  }

  @override
  String requestBudgetBodyError(String actual, String limit) {
    return 'Kelivo 로컬 사전 검사: 전체 요청 본문이 $actual로 요청 본문 예산 $limit을(를) 초과했습니다.';
  }

  @override
  String get requestBudgetPinnedError => '이 이미지는 고정되어 있습니다.';

  @override
  String get requestBudgetImageHint =>
      '이미지 컨텍스트를 열어 포함된 이미지와 고정 상태를 확인하세요. 이미지 크기나 수를 줄이거나, 오래된 이미지 고정을 해제하거나, 공급자/모델 설정에서 예산을 조정하세요.';

  @override
  String get requestBudgetBodyHint =>
      '도구 결과를 포함한 대화를 줄이거나 압축하거나, 공급자/모델 설정에서 요청 본문 예산을 조정하세요.';

  @override
  String imageContextEncodedSize(String size) {
    return '인코딩 후 $size MiB';
  }

  @override
  String get imageContextPinned => '고정됨';

  @override
  String get imageContextSizeUnknown => '전송 시 크기 확인';

  @override
  String requestBudgetAtLeast(String value) {
    return '최소 $value';
  }

  @override
  String get compressionNativeTitle => 'OpenAI 서버 측 압축 사용';

  @override
  String get compressionNativeHint =>
      '현재 채팅 모델을 사용하며 압축은 서버에서 이루어집니다. 이 채팅에서 자동 압축이 켜져 있으면 이 방식도 사용됩니다. 공급자가 OpenAI의 Responses API를 지원해야 합니다.';

  @override
  String get compressionNativeScopeHint =>
      '최근 몇 턴은 원문 그대로 유지하고 이전 기록을 서버 측 압축으로 보냅니다. 서버 측 자동 압축도 같은 턴 수를 사용하며, 텍스트 요약의 턴 수는 변경되지 않습니다.';

  @override
  String get compressionNativeLabel => '서버 측 압축';

  @override
  String get compressionNativeDescription =>
      '서버의 압축 결과가 로컬에 저장되며 다음 전송에 사용됩니다. 텍스트로 보거나 편집할 수 없습니다. 원본 메시지는 유지되며 이 압축을 취소할 수 있습니다.';

  @override
  String get compressionNativeIncomplete =>
      '서버가 완전한 압축 결과를 반환하지 않았습니다. 원래 컨텍스트는 변경되지 않았습니다.';

  @override
  String get compressionNativeScopeChanged =>
      '이 서버 측 결과는 다른 연결이나 계정에 속합니다. 계속하려면 원래 연결로 전환하거나, 원문이 남아 있는 채팅에서 이 압축을 취소하고 텍스트 요약을 생성하세요.';

  @override
  String get compressionNativeTokenHint => '서버 측 압축의 토큰 사용량은 서버에서 보고됩니다.';

  @override
  String get compressionNativeCopyHint =>
      '새 채팅에는 완전한 서버 측 결과와 유지한 최근 턴만 포함됩니다. 원문은 원래 채팅에 남아 있으며 여기서 취소해도 복원할 수 없습니다.';

  @override
  String get compressionNativeInputOverride =>
      '모델 또는 어시스턴트 설정의 사용자 지정 input 매개변수가 서버 측 결과를 덮어씁니다. 계속하기 전에 해당 매개변수를 제거하세요.';

  @override
  String get compressionNativeAllHint =>
      '현재 표시되는 모든 기록을 서버 측 압축으로 보내고, 최근 원문은 별도로 보관하지 않습니다. 원본 메시지는 계속 확인할 수 있습니다.';

  @override
  String get compressionNativeAutoHint =>
      '사용량이 설정한 비율에 도달하면 현재 대화 모델로 서버 측 압축을 수행한 후 전송을 계속합니다. 실패하면 원본 컨텍스트를 유지하며 텍스트 요약으로 대체하지 않습니다.';

  @override
  String get languageDisplayRussian => '러시아어';

  @override
  String get languageDisplayTurkish => '튀르키예어';

  @override
  String sideDrawerDeleteConfirmContent(String title) {
    return '\"$title\"을(를) 삭제하시겠습니까?';
  }

  @override
  String get backupPageCherryImportWarning =>
      '이 기능은 실험적입니다. 어시스턴트, 대화, 공급자 및 파일을 가져옵니다. 일부 공급자는 기본 URL 끝에 /v1 또는 /v1beta가 필요합니다. 가져오기 전에 데이터를 백업하세요. 파일 선택을 계속하시겠습니까?';

  @override
  String get themePaletteDefault => '기본';

  @override
  String get themePaletteBlue => '에테르 블루';

  @override
  String get themePaletteGreen => '뱀부 그린';

  @override
  String get themePalettePurple => '트와일라잇 퍼플';

  @override
  String get themePaletteYellow => '앰버 골드';

  @override
  String get themePaletteSmokyRose => '스모키 로즈';

  @override
  String get themePaletteTerracotta => '테라코타 클레이';

  @override
  String get themePaletteMonochrome => '프로스트 그레이';

  @override
  String get themePaletteDocument => '버던트 민트';

  @override
  String get themePaletteCustom => '사용자 지정';

  @override
  String get compressionNativeImported => '서버 측 압축 결과 불러옴';

  @override
  String get compressionNativeImportedDescription =>
      '이 대화는 서버 측 압축 결과와 최근 몇 턴으로 시작합니다. 압축 결과는 텍스트로 보거나 수정할 수 없습니다. 이전 원문은 원래 대화에 남아 있으며 여기서 실행 취소로 복원할 수 없습니다.';

  @override
  String get compressionNativeOpenSource => '원래 대화 열기';

  @override
  String get compressionNativeOriginalsUnavailable =>
      '이 대화에는 불러온 서버 측 압축 결과에 대응하는 원문이 없습니다. 서버 측 압축을 계속 사용하거나, 원래 대화로 돌아가 원문을 확인하거나 텍스트 요약을 생성할 수 있습니다.';

  @override
  String get compressionNativeTemporaryCopyHint =>
      '새 임시 대화에는 완전한 서버 측 압축 결과와 최근 턴만 유지됩니다. 원래 임시 대화를 떠나면 해당 대화와 이전되지 않은 원문은 삭제되며 여기서 복원할 수 없습니다.';

  @override
  String get compressionNativeSourceUnavailable =>
      '이 대화에는 완전한 서버 측 압축 결과와 유지한 최근 턴이 저장되어 있습니다. 원래 대화는 더 이상 사용할 수 없습니다. 여기로 복사되지 않은 원문은 복원할 수 없으며, 압축 결과는 텍스트로 보거나 수정할 수 없습니다.';

  @override
  String get modelDetailSheetImageGenerationModel => '이미지 모델';

  @override
  String get modelDetailSheetImageGenerationAuto => '자동';

  @override
  String get modelDetailSheetImageGenerationComplexity => '이미지 복잡도';

  @override
  String get modelDetailSheetImageGenerationComplexityDefault => '기본';

  @override
  String get modelDetailSheetImageGenerationComplexityLow => '낮음';

  @override
  String get modelDetailSheetImageGenerationComplexityMedium => '중간';

  @override
  String get modelDetailSheetImageGenerationComplexityHigh => '높음';

  @override
  String get modelDetailSheetImageGenerationComplexityDescription =>
      '채팅 추론과 별도로 이미지 계획을 제어합니다. 기본은 서버 동작을 사용하며 채팅 추론을 따를 수 있습니다.';

  @override
  String get modelDetailSheetImageGenerationOAuthHint =>
      'ChatGPT 로그인은 다른 이미지 모델을 사용할 수 있습니다. 모델 및 복잡도 설정은 서버 지원 여부에 따라 달라집니다.';

  @override
  String get imageGenerationComplexityErrorHint =>
      '채팅 추론을 자동으로, 이미지 복잡도를 기본으로 설정한 후 이미지 생성을 다시 시도하세요. ChatGPT 로그인은 다른 이미지 모델을 사용하거나 명시적 복잡도를 거부할 수 있습니다.';

  @override
  String get workspaceEnvNativeShellTitle => '기본 셸';

  @override
  String get workspaceEnvNativeShellHint =>
      '비워 두면 자동으로 감지합니다. 그렇지 않으면 PowerShell, cmd 또는 -lc를 지원하는 셸(bash, zsh, fish 등)의 절대 경로를 입력하세요. 이 설정은 이 기기에만 적용됩니다.';

  @override
  String get workspaceEnvNativeShellInvalid =>
      '이 셸을 시작할 수 없습니다. 절대 경로와 지원되는 명령 구문을 확인하세요.';

  @override
  String get workspaceEnvNativeShellUnavailable => '셸을 사용할 수 없음';

  @override
  String get workspaceEnvNativeShellDetect => '다시 감지';

  @override
  String get workspaceEnvNativeShellSave => '저장';

  @override
  String get desktopAutostartTitle => '시작 시 실행';

  @override
  String get desktopAutostartDescription => '이 컴퓨터에 로그인하면 Kelivo를 시작합니다.';

  @override
  String get desktopAutostartHiddenTitle => '자동 시작 시 트레이로 숨기기';

  @override
  String get desktopAutostartHiddenDescription =>
      '시작 시 실행과 트레이 아이콘이 필요합니다. Kelivo를 직접 열면 창이 계속 표시됩니다.';

  @override
  String get desktopAutostartUnsupported => '시작 시 실행은 macOS 13 이상이 필요합니다.';

  @override
  String get desktopAutostartError =>
      '시작 설정을 적용할 수 없습니다. 시스템 시작 항목 또는 로그인 항목 설정에서 이 앱을 확인한 후 다시 시도하세요.';

  @override
  String get compressionOutputBudget => '총 출력 한도 (토큰)';

  @override
  String get compressionOutputBudgetHint =>
      '사고 과정과 요약 본문을 포함합니다. 비워 두면 요약 목표 길이와 같습니다. 사고가 켜져 있으면 요약 목표 길이를 늘리지 않고 이 한도를 높일 수 있습니다. 모델 자체의 출력 한도는 여전히 적용됩니다.';

  @override
  String get responseOutputLimitReached =>
      '응답이 잘렸습니다: 출력 한도에 추론이 포함됩니다. 출력 한도를 늘리거나 추론을 줄인 후 다시 시도하세요.';

  @override
  String responseContextLimitReached(int inputTokens, int contextWindow) {
    return '응답이 잘렸습니다: 이번 요청은 입력 토큰 $inputTokens개를 사용해 $contextWindow 토큰 컨텍스트 한도에 근접했습니다. 컨텍스트를 줄인 후 다시 시도하세요.';
  }

  @override
  String get responseRetryWithoutImages => '이미지 없이 재시도(원본 유지)';
}
