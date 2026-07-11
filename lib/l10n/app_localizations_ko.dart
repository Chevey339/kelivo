// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Korean (`ko`).
class AppLocalizationsKo extends AppLocalizations {
  AppLocalizationsKo([String locale = 'ko']) : super(locale);

  @override
  String get helloWorld => '안녕, 세상!';

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
  String get settingsPageWarningMessage => '일부 서비스가 설정되지 않아 기능이 제한될 수 있습니다.';

  @override
  String get settingsPageGeneralSection => '일반';

  @override
  String get settingsPageColorMode => '색상 모드';

  @override
  String get settingsPageDisplay => '환경설정';

  @override
  String get settingsPageDisplaySubtitle => '화면, 동작, 상호작용 관련 환경설정';

  @override
  String get settingsPageAssistant => '어시스턴트';

  @override
  String get settingsPageAssistantSubtitle => '기본 어시스턴트 및 스타일';

  @override
  String get settingsPageModelsServicesSection => '모델 및 서비스';

  @override
  String get settingsPageDefaultModel => '기본 모델';

  @override
  String get settingsPageProviders => '공급자';

  @override
  String get settingsPageHotkeys => '단축키';

  @override
  String get settingsPageSearch => '검색';

  @override
  String get settingsPageTts => 'TTS';

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
  String get settingsPageChatStorage => '채팅 저장 공간';

  @override
  String get settingsPageCalculating => '계산 중…';

  @override
  String settingsPageFilesCount(int count, String size) {
    return '파일 $count개 · $size';
  }

  @override
  String get storageSpacePageTitle => '저장 공간';

  @override
  String get storageSpaceRefreshTooltip => '새로고침';

  @override
  String get storageSpaceLoadFailed => '저장 공간 사용량을 불러오지 못했습니다';

  @override
  String get storageSpaceTotalLabel => '사용됨';

  @override
  String storageSpaceClearableLabel(String size) {
    return '정리 가능: $size';
  }

  @override
  String storageSpaceClearableHint(String size) {
    return '안전하게 정리 가능: $size';
  }

  @override
  String get storageSpaceCategoryImages => '이미지';

  @override
  String get storageSpaceCategoryFiles => '파일';

  @override
  String get storageSpaceCategoryChatData => '채팅 기록';

  @override
  String get storageSpaceCategoryAssistantData => '어시스턴트';

  @override
  String get storageSpaceCategoryCache => '캐시';

  @override
  String get storageSpaceCategoryLogs => '로그';

  @override
  String get storageSpaceCategoryOther => '앱';

  @override
  String storageSpaceFilesCount(int count) {
    return '파일 $count개';
  }

  @override
  String get storageSpaceSafeToClearHint =>
      '안전하게 정리할 수 있습니다. 채팅 기록에는 영향을 주지 않습니다.';

  @override
  String get storageSpaceNotSafeToClearHint =>
      '채팅 기록에 영향을 줄 수 있습니다. 신중하게 삭제하세요.';

  @override
  String get storageSpaceBreakdownTitle => '세부 내역';

  @override
  String get storageSpaceSubChatMessages => '메시지';

  @override
  String get storageSpaceSubChatConversations => '대화';

  @override
  String get storageSpaceSubChatToolEvents => '도구 이벤트';

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
  String get storageSpaceSubLogsFlutter => 'Flutter 로그';

  @override
  String get storageSpaceSubLogsRequests => '네트워크 로그';

  @override
  String get storageSpaceSubLogsOther => '기타 로그';

  @override
  String get storageSpaceClearConfirmTitle => '정리 확인';

  @override
  String storageSpaceClearConfirmMessage(String targetName) {
    return '$targetName을(를) 정리하시겠습니까?';
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
  String get storageSpaceViewLogsButton => '로그 보기';

  @override
  String get storageSpaceDeleteConfirmTitle => '삭제 확인';

  @override
  String storageSpaceDeleteUploadsConfirmMessage(int count) {
    return '$count개 항목을 삭제하시겠습니까? 채팅 기록의 첨부 파일을 더 이상 사용할 수 없게 될 수 있습니다.';
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
  String get settingsPageSponsor => '스폰서';

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
  String get statsPageUsageTrendTitle => '사용 추이';

  @override
  String get statsPageModelUsageTitle => '모델 사용량';

  @override
  String get statsPageAssistantUsageTitle => '어시스턴트 사용량';

  @override
  String get statsPageTopicVolumeTitle => '주제별 대화량';

  @override
  String get statsPageModelColumn => '모델';

  @override
  String get statsPageAssistantColumn => '어시스턴트';

  @override
  String get statsPageTopicColumn => '주제';

  @override
  String get statsPageMessagesColumn => '메시지';

  @override
  String get statsPageTopicsColumn => '주제';

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
  String get statsPageUnknownTopic => '제목 없는 주제';

  @override
  String get statsPageCustomRangeTitle => '사용자 지정 범위';

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
  String get sponsorPageSponsorsSectionTitle => '스폰서';

  @override
  String get sponsorPageEmpty => '아직 스폰서가 없습니다';

  @override
  String get sponsorPageAfdianTitle => 'Afdian';

  @override
  String get sponsorPageAfdianSubtitle => 'afdian.com/a/kelivo';

  @override
  String get sponsorPageWeChatTitle => 'WeChat 스폰서';

  @override
  String get sponsorPageWeChatSubtitle => 'WeChat 후원 코드';

  @override
  String get sponsorPageScanQrHint => 'QR 코드를 스캔해 후원하세요';

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
  String homePageClearContextWithCount(String actual, String configured) {
    return '컨텍스트 지우기 ($actual/$configured)';
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
  String get mermaidGeneratingImage => '이미지 생성 중';

  @override
  String get mermaidGenerationFailedHint => '생성에 실패했습니다. 다른 방식으로 다시 요청해 보세요.';

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
  String assistantProviderSampleAssistantSystemPrompt(
    String model_name,
    String cur_datetime,
    String locale,
    String timezone,
    String device_info,
    String system_version,
  ) {
    return '당신은 $model_name이며, 정확하고 유용한 도움을 기꺼이 제공하는 AI 어시스턴트입니다. 현재 시각은 $cur_datetime이고, 기기 언어는 $locale, 시간대는 $timezone이며, 사용자는 $device_info(버전 $system_version)를 사용하고 있습니다. 사용자가 별도로 명시하지 않는 한, 답변 시 사용자의 기기 언어를 사용하세요.';
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
  String get assistantTagsRenameDialogOk => '변경';

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
  String get mcpServerEditSheetStdioOnlyDesktop => 'STDIO는 데스크톱에서만 사용할 수 있습니다';

  @override
  String get mcpServerEditSheetStdioCommandLabel => '명령어';

  @override
  String get mcpServerEditSheetStdioArgumentsLabel => '인수';

  @override
  String get mcpServerEditSheetStdioWorkingDirectoryLabel => '작업 디렉터리(선택 사항)';

  @override
  String get mcpServerEditSheetStdioEnvironmentTitle => '환경 변수';

  @override
  String get mcpServerEditSheetStdioEnvNameLabel => '이름';

  @override
  String get mcpServerEditSheetStdioEnvValueLabel => '값';

  @override
  String get mcpServerEditSheetStdioAddEnv => '환경 변수 추가';

  @override
  String get mcpServerEditSheetStdioCommandRequired => 'STDIO에는 명령어가 필요합니다';

  @override
  String get assistantTagsContextMenuDeleteAssistant => '어시스턴트 삭제';

  @override
  String get assistantTagsClearTag => '태그 지우기';

  @override
  String get displaySettingsPageLanguageChineseLabel => '중국어 간체';

  @override
  String get displaySettingsPageLanguageEnglishLabel => '영어';

  @override
  String get displaySettingsPageLanguageKoreanLabel => '한국어';

  @override
  String get homePagePleaseSelectModel => '먼저 모델을 선택하세요';

  @override
  String get homePageAudioAttachmentUnsupported =>
      '현재 모델은 오디오 첨부 파일을 지원하지 않습니다. 오디오 입력을 지원하는 모델로 전환하거나 오디오 파일을 제거한 후 다시 시도하세요.';

  @override
  String get homePagePleaseSetupTranslateModel => '먼저 번역 모델을 설정하세요';

  @override
  String get homePageTranslating => '번역 중...';

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
  String get homePageDropToUpload => '파일을 여기에 놓아 업로드하세요';

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
  String get assistantEditPageCustomTab => '사용자 지정';

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
      '탭을 드래그해 순서를 바꾸세요. 필요 없는 탭은 꺼두세요.';

  @override
  String get assistantEditOutlineModeTitle => '섹션 목록 스타일';

  @override
  String get assistantEditOutlineModeSubtitle =>
      '어시스턴트 개요를 먼저 보여준 뒤, 목록에서 각 설정 섹션을 열도록 합니다.';

  @override
  String get assistantEditTabLayoutResetTooltip => '탭 레이아웃 초기화';

  @override
  String get assistantEditTabLayoutAtLeastOneVisible => '최소 하나의 탭은 표시되어야 합니다';

  @override
  String assistantEditTabLayoutDragHandle(String tab) {
    return '드래그하여 $tab 순서 변경';
  }

  @override
  String get assistantEditRegexDescription =>
      '정규식 규칙을 만들어 사용자/어시스턴트 메시지를 다시 쓰거나 표시 방식을 조정하세요.';

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
  String get assistantRegexReplacementLabel => '치환 문자열';

  @override
  String get assistantRegexScopeLabel => '적용 범위';

  @override
  String get assistantRegexScopeUser => '사용자';

  @override
  String get assistantRegexScopeAssistant => '어시스턴트';

  @override
  String get assistantRegexScopeVisualOnly => '표시에만 적용';

  @override
  String get assistantRegexScopeReplaceOnly => '치환에만 적용';

  @override
  String get assistantRegexAddAction => '추가';

  @override
  String get assistantRegexSaveAction => '저장';

  @override
  String get assistantRegexDeleteButton => '삭제';

  @override
  String get assistantRegexValidationError =>
      '이름과 정규식을 입력하고 적용 범위를 하나 이상 선택하세요.';

  @override
  String get assistantRegexInvalidPattern => '잘못된 정규식입니다';

  @override
  String get assistantRegexCancelButton => '취소';

  @override
  String get assistantRegexUntitled => '제목 없는 규칙';

  @override
  String get assistantEditCustomHeadersTitle => '사용자 지정 헤더';

  @override
  String get assistantEditCustomHeadersAdd => '헤더 추가';

  @override
  String get assistantEditCustomHeadersEmpty => '추가된 헤더가 없습니다';

  @override
  String get assistantEditCustomBodyTitle => '사용자 지정 본문';

  @override
  String get assistantEditCustomBodyAdd => '본문 추가';

  @override
  String get assistantEditCustomBodyEmpty => '추가된 본문 항목이 없습니다';

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
      '모델 아바타 대신 어시스턴트 아바타 사용';

  @override
  String get assistantEditUseAssistantNameTitle => '어시스턴트 이름 사용';

  @override
  String get assistantEditChatModelTitle => '채팅 모델';

  @override
  String get assistantEditChatModelSubtitle =>
      '이 어시스턴트의 기본 채팅 모델(설정하지 않으면 전역 설정 사용)';

  @override
  String get assistantEditTemperatureDescription => '무작위성을 조절합니다 (범위 0–2)';

  @override
  String get assistantEditTopPDescription => '정확히 알고 있는 경우가 아니라면 변경하지 마세요';

  @override
  String get assistantEditParameterDisabled => '사용 안 함 (공급자 기본값 사용)';

  @override
  String get assistantEditParameterDisabled2 => '사용 안 함 (제한 없음)';

  @override
  String get assistantEditContextMessagesTitle => '컨텍스트 메시지';

  @override
  String get assistantEditContextMessagesDescription => '컨텍스트에 유지할 최근 메시지 수';

  @override
  String get assistantEditStreamOutputTitle => '스트리밍 출력';

  @override
  String get assistantEditStreamOutputDescription => '응답을 스트리밍으로 받습니다';

  @override
  String get assistantEditThinkingBudgetTitle => '추론 예산';

  @override
  String get assistantEditConfigureButton => '구성';

  @override
  String get assistantEditMaxTokensTitle => '최대 토큰 수';

  @override
  String get assistantEditMaxTokensDescription => '비워두면 제한 없음';

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
  String get desktopNavGlobalSearchTooltip => '전체 검색';

  @override
  String get desktopNavThemeToggleTooltip => '테마';

  @override
  String get desktopNavSettingsTooltip => '설정';

  @override
  String get desktopAvatarMenuUseEmoji => '이모지 사용';

  @override
  String get cameraPermissionDeniedMessage =>
      '카메라를 사용할 수 없습니다: 권한이 허용되지 않았습니다.';

  @override
  String get openSystemSettings => '설정 열기';

  @override
  String get desktopAvatarMenuChangeFromImage => '이미지로 변경…';

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
  String get displaySettingsPageChatMessageBackgroundDefault => '기본값';

  @override
  String get displaySettingsPageChatMessageBackgroundFrosted => '반투명 유리';

  @override
  String get displaySettingsPageChatMessageBackgroundSolid => '단색';

  @override
  String get displaySettingsPageAndroidBackgroundChatTitle =>
      '백그라운드 생성 (Android)';

  @override
  String get displaySettingsPageIosBackgroundChatTitle => '백그라운드 생성 (iOS)';

  @override
  String get iosBackgroundSettingsPageTitle => 'iOS 백그라운드 생성';

  @override
  String get iosBackgroundStatusOn => '켜짐';

  @override
  String get iosBackgroundStatusOff => '꺼짐';

  @override
  String get iosBackgroundGenerationEnableTitle => '백그라운드 생성';

  @override
  String get iosBackgroundGenerationEnableSubtitle =>
      'iOS 백그라운드 실행 시간을 활용해 앱이 포그라운드를 벗어난 뒤에도 현재 응답 생성을 계속합니다.';

  @override
  String get iosBackgroundTaskRefreshTitle => '백그라운드 작업 복구';

  @override
  String get iosBackgroundTaskRefreshSubtitle =>
      '시스템 상황이 허용할 때 iOS에 새로고침 및 처리 기회를 요청합니다.';

  @override
  String get iosLiveActivityTitle => '라이브 액티비티';

  @override
  String get iosLiveActivitySubtitle =>
      '지원되는 기기에서 잠금 화면과 다이나믹 아일랜드에 백그라운드 응답을 표시합니다.';

  @override
  String get iosBackgroundNotificationsTitle => '작업 알림';

  @override
  String get iosBackgroundNotificationsSubtitle =>
      '백그라운드 응답이 완료되거나 중단되면 로컬 알림을 보냅니다.';

  @override
  String get iosBackgroundLimitNoticeTitle => 'iOS가 작업을 일시 중단할 수 있습니다';

  @override
  String get iosBackgroundLimitNoticeBody =>
      '이 옵션들은 Apple이 지원하는 백그라운드 시간, BackgroundTasks, 알림, Live Activities를 사용합니다. 연속성은 개선되지만 iOS가 Kelivo를 계속 실행하도록 강제할 수는 없습니다.';

  @override
  String get iosBackgroundUnsupportedLiveActivity =>
      'iOS 16.1 이상과 설정에서 Live Activities 활성화가 필요합니다.';

  @override
  String get iosBackgroundNativeStatusTitle => '시스템 상태';

  @override
  String get iosBackgroundNativeStatusUnavailable => 'iOS에서 실행 중이어야 사용할 수 있습니다';

  @override
  String get iosBackgroundLiveActivityAvailable => 'Live Activities 사용 가능';

  @override
  String get iosBackgroundLiveActivityUnavailable => 'Live Activities 사용 불가';

  @override
  String get iosBackgroundNotificationsAuthorized => '알림 허용됨';

  @override
  String get iosBackgroundNotificationsNotAuthorized => '알림 허용 안 됨';

  @override
  String get iosBackgroundGenerationActiveTitle => 'Kelivo가 생성 중입니다';

  @override
  String get iosBackgroundGenerationActiveDetail =>
      '어시스턴트가 백그라운드에서 답장을 작성 중입니다';

  @override
  String get iosBackgroundGenerationStreamingDetail => '어시스턴트 응답을 수신 중입니다';

  @override
  String iosBackgroundGenerationTokenCount(int count) {
    return '$count개 토큰';
  }

  @override
  String get iosBackgroundGenerationCompleteTitle => '생성 완료';

  @override
  String get iosBackgroundGenerationCompleteDetail => '어시스턴트 답장이 준비되었습니다';

  @override
  String get iosBackgroundGenerationInterruptedTitle => '생성 중단됨';

  @override
  String get iosBackgroundGenerationInterruptedDetail =>
      '백그라운드 답장이 완료되기 전에 중단되었습니다';

  @override
  String get iosBackgroundGenerationCancelledDetail => '생성이 중지되었습니다';

  @override
  String get androidBackgroundStatusOn => '켜짐';

  @override
  String get androidBackgroundStatusOff => '꺼짐';

  @override
  String get androidBackgroundStatusOther => '켜짐 및 알림';

  @override
  String get androidBackgroundOptionOn => '켜기';

  @override
  String get androidBackgroundOptionOnNotify => '켜기 및 완료 시 알림';

  @override
  String get androidBackgroundOptionOff => '끄기';

  @override
  String get notificationChatCompletedTitle => '생성 완료';

  @override
  String get notificationChatCompletedBody => '어시스턴트 답장이 생성되었습니다';

  @override
  String get androidBackgroundNotificationTitle => 'Kelivo가 실행 중입니다';

  @override
  String get androidBackgroundNotificationText => '백그라운드에서 채팅 생성을 유지하는 중입니다';

  @override
  String get assistantEditEmojiDialogTitle => '이모지 선택';

  @override
  String get assistantEditEmojiDialogHint => '이모지를 입력하거나 붙여넣으세요';

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
  String get assistantEditQQAvatarDialogHint => 'QQ 번호 입력 (5~12자리)';

  @override
  String get assistantEditQQAvatarRandomButton => '무작위로 선택';

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
  String get multiKeyPageTitle => '다중 키 관리자';

  @override
  String get multiKeyPageDetect => '감지';

  @override
  String get multiKeyPageAdd => '추가';

  @override
  String get multiKeyPageAddHint => '쉼표 또는 공백으로 구분해 API 키를 입력하세요';

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
  String get multiKeyPageStrategyTitle => '로드 밸런싱 전략';

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
  String get multiKeyPageStatusRateLimited => '속도 제한됨';

  @override
  String get multiKeyPageEditAlias => '별칭 편집';

  @override
  String get multiKeyPageEdit => '편집';

  @override
  String get multiKeyPageKey => 'API 키';

  @override
  String get multiKeyPagePriority => '우선순위 (1~10)';

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
  String get assistantEditSystemPromptHint => '시스템 프롬프트를 입력하세요…';

  @override
  String get assistantEditSystemPromptImportButton => '파일 가져오기';

  @override
  String get assistantEditSystemPromptImportSuccess =>
      '파일에서 시스템 프롬프트를 업데이트했습니다';

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
  String get assistantEditVariableDatetime => '날짜/시간';

  @override
  String get assistantEditVariableModelId => '모델 ID';

  @override
  String get assistantEditVariableModelName => '모델 이름';

  @override
  String get assistantEditVariableLocale => '로케일';

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
      'CSV를 복사했습니다. 이미지로 복사하려면 복사를 길게 누르세요.';

  @override
  String get markdownTableCopiedMarkdownSnackbar => '표를 복사했습니다.';

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
  String get assistantSettingsCopySuccess => '어시스턴트를 복사했습니다';

  @override
  String get assistantSettingsCopySuffix => '복사본';

  @override
  String get assistantSettingsDeleteButton => '삭제';

  @override
  String get assistantSettingsEditButton => '편집';

  @override
  String get assistantSettingsAddSheetTitle => '어시스턴트 이름';

  @override
  String get assistantSettingsAddSheetHint => '이름을 입력하세요';

  @override
  String get assistantSettingsAddSheetCancel => '취소';

  @override
  String get assistantSettingsAddSheetSave => '저장';

  @override
  String get desktopAssistantsListTitle => '어시스턴트';

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
  String get hotkeyToggleAssistantPanel => '어시스턴트 패널 전환';

  @override
  String get hotkeyToggleTopicPanel => '토픽 패널 전환';

  @override
  String get hotkeysPressShortcut => '단축키를 입력하세요';

  @override
  String get hotkeysResetDefault => '기본값으로 재설정';

  @override
  String get hotkeysClearShortcut => '단축키 지우기';

  @override
  String get hotkeysResetAll => '모두 기본값으로 재설정';

  @override
  String get assistantEditTemperatureTitle => 'Temperature';

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
      '최소 하나의 어시스턴트가 필요합니다';

  @override
  String get mcpAssistantSheetTitle => 'MCP 서버';

  @override
  String get mcpAssistantSheetSubtitle => '이 어시스턴트에 사용 설정된 서버';

  @override
  String get mcpAssistantSheetSelectAll => '전체 선택';

  @override
  String get mcpAssistantSheetClearAll => '전체 해제';

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
  String get backupPageTestDone => '테스트 완료';

  @override
  String get backupPageTestConnection => '테스트';

  @override
  String get backupPageRestartRequired => '재시작 필요';

  @override
  String get backupPageRestartContent => '복원이 완료되었습니다. 앱을 재시작해 주세요.';

  @override
  String get backupPageOK => '확인';

  @override
  String get backupPageCancel => '취소';

  @override
  String get backupPageSelectImportMode => '가져오기 모드 선택';

  @override
  String get backupPageSelectImportModeDescription => '백업 데이터를 가져올 방법을 선택하세요:';

  @override
  String get backupPageOverwriteMode => '완전 덮어쓰기';

  @override
  String get backupPageOverwriteModeDescription => '모든 로컬 데이터를 지우고 백업에서 복원합니다';

  @override
  String get backupPageMergeMode => '스마트 병합';

  @override
  String get backupPageMergeModeDescription => '존재하지 않는 데이터만 추가합니다 (지능형 중복 제거)';

  @override
  String get backupPageRestore => '복원';

  @override
  String get backupPageBackupUploaded => '백업을 업로드했습니다';

  @override
  String get backupPageBackup => '백업';

  @override
  String get backupPageExporting => '내보내는 중...';

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
  String get backupPageImportFromRikkaHub => 'RikkaHub에서 가져오기';

  @override
  String get backupPageNotSupportedYet => '아직 지원되지 않습니다';

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
  String get backupPageS3Bucket => '버킷';

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
  String get backupPageImportFromCherryStudio => 'Cherry Studio에서 가져오기';

  @override
  String get backupPageImportFromChatbox => 'Chatbox에서 가져오기';

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
  String get backupReminderNever => '안 함';

  @override
  String get backupReminderDisabled => '꺼짐';

  @override
  String get backupReminderDueNow => '지금 필요';

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
  String get backupReminderCustomDialogDescription =>
      '백업 알림 간격으로 며칠을 기다릴지 입력하세요.';

  @override
  String get backupReminderCustomDaysLabel => '일';

  @override
  String get backupReminderCustomDaysInvalid => '1부터 365 사이의 숫자를 입력하세요.';

  @override
  String get backupReminderSidebarTitle => '백업 알림';

  @override
  String get backupReminderSidebarSubtitle => '백업 주기가 도래했습니다.';

  @override
  String get backupReminderSidebarAction => '백업으로 이동';

  @override
  String get backupReminderSnoozeTooltip => '나중에 알림';

  @override
  String get chatHistoryPageTitle => '채팅 기록';

  @override
  String get chatHistoryPageSearchTooltip => '검색';

  @override
  String get chatHistoryPageDeleteAllTooltip => '고정 안 됨 삭제';

  @override
  String get chatHistoryPageDeleteAllDialogTitle => '고정 해제된 대화 삭제';

  @override
  String get chatHistoryPageDeleteAllDialogContent =>
      '이 어시스턴트의 고정되지 않은 모든 대화를 삭제할까요? 고정된 채팅은 그대로 유지됩니다.';

  @override
  String get chatHistoryPageCancel => '취소';

  @override
  String get chatHistoryPageDelete => '삭제';

  @override
  String get chatHistoryPageDeletedAllSnackbar => '고정되지 않은 대화를 삭제했습니다';

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
  String get userMessageEditSaveOnly => '저장만 하기';

  @override
  String get userMessageEditUnsupportedSnackbar => '이 콘텐츠는 편집을 지원하지 않습니다';

  @override
  String get userMessageEditOverwriteTitle => '알림';

  @override
  String get userMessageEditOverwriteContent => '편집하면 기존 입력 내용을 덮어씁니다. 덮어쓸까요?';

  @override
  String get selectCopyPageTitle => '선택 및 복사';

  @override
  String get selectCopyPageCopyAll => '모두 복사';

  @override
  String get selectCopyPageCopiedAll => '모두 복사했습니다';

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
  String get compressContextDesc => '요약 후 새 채팅을 시작합니다';

  @override
  String get clearContextDesc => '컨텍스트 경계를 표시합니다';

  @override
  String get contextManagement => '컨텍스트 관리';

  @override
  String get compressingContext => '컨텍스트를 압축하는 중...';

  @override
  String get compressContextFailed => '컨텍스트 압축에 실패했습니다';

  @override
  String get compressContextNoMessages => '압축할 메시지가 없습니다';

  @override
  String get compressContextNoConversation => '압축할 대화가 없습니다';

  @override
  String get compressContextNoModel => '압축에 사용할 모델이 설정되지 않았습니다';

  @override
  String get compressContextEmptySummary => '압축 결과 요약이 비어 있습니다';

  @override
  String get compressContextOptionsTitle => '컨텍스트 압축';

  @override
  String get compressContextOptionsDesc => '현재 채팅에서 압축 모델로 보낼 부분을 선택하세요.';

  @override
  String get compressContextKeepStart => '시작 부분';

  @override
  String get compressContextKeepRecent => '최근 부분';

  @override
  String get compressContextUnlimited => '무제한';

  @override
  String get compressContextMaxCharsLabel => '글자 수';

  @override
  String get compressContextInvalidLimit => '양수인 글자 수를 입력하세요';

  @override
  String get compressContextStartButton => '압축';

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
  String get messageMoreSheetNotImplemented => '아직 구현되지 않았습니다';

  @override
  String get messageMoreSheetEdit => '편집';

  @override
  String get messageMoreSheetShare => '공유';

  @override
  String get messageMoreSheetSelectMessages => '메시지 선택';

  @override
  String get messageMoreSheetCreateBranch => '브랜치 생성';

  @override
  String get messageMoreSheetDelete => '이 버전 삭제';

  @override
  String get messageMoreSheetDeleteAllVersions => '모든 버전 삭제';

  @override
  String get reasoningBudgetSheetOff => '끄기';

  @override
  String get reasoningBudgetSheetAuto => '자동';

  @override
  String get reasoningBudgetSheetLight => '가벼운 추론';

  @override
  String get reasoningBudgetSheetMedium => '보통 추론';

  @override
  String get reasoningBudgetSheetHeavy => '강한 추론';

  @override
  String get reasoningBudgetSheetXhigh => '매우 강한 추론';

  @override
  String get reasoningBudgetSheetMax => '최대 추론';

  @override
  String get reasoningBudgetSheetTitle => '추론 강도';

  @override
  String reasoningBudgetSheetCurrentLevel(String level) {
    return '현재 레벨: $level';
  }

  @override
  String get reasoningBudgetSheetOffSubtitle => '추론을 끄고 바로 답변합니다';

  @override
  String get reasoningBudgetSheetAutoSubtitle => '모델이 추론 수준을 자동으로 결정합니다';

  @override
  String get reasoningBudgetSheetLightSubtitle => '가벼운 추론으로 답변합니다';

  @override
  String get reasoningBudgetSheetMediumSubtitle => '적당한 추론으로 답변합니다';

  @override
  String get reasoningBudgetSheetHeavySubtitle => '복잡한 질문에는 깊은 추론을 사용합니다';

  @override
  String get reasoningBudgetSheetXhighSubtitle => '가장 어려운 문제에 최대 추론 깊이를 사용합니다';

  @override
  String get reasoningBudgetSheetCustomLabel => '사용자 지정 추론 예산';

  @override
  String get reasoningBudgetSheetCustomHint => '예: 2048 (-1 자동, 0 끄기)';

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
    return '파일 열기에 실패했습니다: $error';
  }

  @override
  String get chatMessageWidgetCopiedToClipboard => '클립보드에 복사되었습니다';

  @override
  String get chatMessageWidgetResendTooltip => '다시 보내기';

  @override
  String get chatMessageWidgetMoreTooltip => '더보기';

  @override
  String get chatMessageWidgetThinking => '생각 중...';

  @override
  String get chatMessageWidgetTranslation => '번역';

  @override
  String get chatMessageWidgetTranslating => '번역 중...';

  @override
  String get chatMessageWidgetCitationNotFound => '인용 출처를 찾을 수 없습니다';

  @override
  String chatMessageWidgetCannotOpenUrl(String url) {
    return '링크를 열 수 없습니다: $url';
  }

  @override
  String get chatMessageWidgetOpenLinkError => '링크 열기에 실패했습니다';

  @override
  String chatMessageWidgetCitationsTitle(int count) {
    return '인용 ($count)';
  }

  @override
  String get chatMessageWidgetSearchResultsTitle => '검색 결과';

  @override
  String get chatMessageWidgetCitationSourcesTitle => '인용 출처';

  @override
  String get chatMessageWidgetRegenerateTooltip => '재생성';

  @override
  String get chatMessageWidgetRegenerateConfirmTitle => '재생성 확인';

  @override
  String get chatMessageWidgetRegenerateConfirmContent =>
      '재생성하면 이 메시지만 업데이트되고 아래 메시지는 그대로 유지됩니다. 계속하시겠습니까?';

  @override
  String get chatMessageWidgetRegenerateConfirmDeleteTrailingContent =>
      '재생성하면 이 메시지 아래의 모든 메시지가 삭제되며 되돌릴 수 없습니다. 계속하시겠습니까?';

  @override
  String get chatMessageWidgetRegenerateConfirmCancel => '취소';

  @override
  String get chatMessageWidgetRegenerateConfirmOk => '재생성';

  @override
  String get chatMessageWidgetStopTooltip => '중지';

  @override
  String get chatMessageWidgetSpeakTooltip => '읽어주기';

  @override
  String get chatMessageWidgetTranslateTooltip => '번역';

  @override
  String get chatMessageWidgetBuiltinSearchHideNote => '내장 검색 도구 카드 숨기기';

  @override
  String get chatMessageWidgetDeepThinking => '심층 추론';

  @override
  String get chatMessageWidgetCreateMemory => '메모리 생성';

  @override
  String get chatMessageWidgetEditMemory => '메모리 편집';

  @override
  String get chatMessageWidgetDeleteMemory => '메모리 삭제';

  @override
  String chatMessageWidgetWebSearch(String query) {
    return '웹 검색: $query';
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
  String get chatMessageWidgetArguments => '인자';

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
  String get chatSelectionThinkingTools => '추론 도구';

  @override
  String get chatSelectionThinkingContent => '추론 내용';

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
    return '내보내기에 실패했습니다: $error';
  }

  @override
  String messageExportSheetExportedAs(String filename) {
    return '$filename(으)로 내보냈습니다';
  }

  @override
  String get displaySettingsPageEnableDollarLatexTitle => '인라인 \$...\$ 렌더링';

  @override
  String get displaySettingsPageEnableDollarLatexSubtitle =>
      '\$...\$ 안의 인라인 수식을 렌더링합니다';

  @override
  String get displaySettingsPageEnableMathTitle => '수식 렌더링';

  @override
  String get displaySettingsPageEnableMathSubtitle =>
      'LaTeX 수식을 렌더링합니다 (인라인 및 블록)';

  @override
  String get displaySettingsPageEnableUserMarkdownTitle =>
      '사용자 메시지를 Markdown으로 렌더링';

  @override
  String get displaySettingsPageEnableReasoningMarkdownTitle =>
      '추론(생각) 내용을 Markdown으로 렌더링';

  @override
  String get displaySettingsPageEnableAssistantMarkdownTitle =>
      '어시스턴트 메시지를 Markdown으로 렌더링';

  @override
  String get displaySettingsPageMobileCodeBlockWrapTitle => '모바일 코드 블록 자동 줄바꿈';

  @override
  String get displaySettingsPageAutoCollapseCodeBlockTitle => '코드 블록 자동 접기';

  @override
  String get displaySettingsPageAutoCollapseCodeBlockLinesTitle => '자동 접기 기준';

  @override
  String get displaySettingsPageAutoCollapseCodeBlockLinesUnit => '줄';

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
  String get messageExportSheetShowThinkingAndToolCards => '심층 추론 및 도구 카드 표시';

  @override
  String get messageExportSheetShowThinkingContent => '추론 내용 표시';

  @override
  String get messageExportThinkingContentLabel => '추론 내용';

  @override
  String get messageExportSheetDateTimeWithSecondsPattern =>
      'yyyy-MM-dd HH:mm:ss';

  @override
  String get exportDisclaimerAiGenerated => 'AI가 생성한 콘텐츠입니다. 내용을 꼼꼼히 확인하세요.';

  @override
  String get imagePreviewSheetSaveImage => '이미지 저장';

  @override
  String get imagePreviewSheetSaveSuccess => '갤러리에 저장되었습니다';

  @override
  String imagePreviewSheetSaveFailed(String error) {
    return '저장에 실패했습니다: $error';
  }

  @override
  String get sideDrawerMenuRename => '이름 변경';

  @override
  String get sideDrawerMenuPin => '고정';

  @override
  String get sideDrawerMenuUnpin => '고정 해제';

  @override
  String get sideDrawerMenuRegenerateTitle => '제목 재생성';

  @override
  String get sideDrawerMenuMoveTo => '이동';

  @override
  String get sideDrawerMenuDelete => '삭제';

  @override
  String sideDrawerDeleteSnackbar(String title) {
    return '\"$title\" 삭제됨';
  }

  @override
  String get sideDrawerRenameHint => '새 이름을 입력하세요';

  @override
  String get sideDrawerCancel => '취소';

  @override
  String get sideDrawerOK => '확인';

  @override
  String get sideDrawerSave => '저장';

  @override
  String get sideDrawerGreetingMorning => '좋은 아침이에요 👋';

  @override
  String get sideDrawerGreetingNoon => '좋은 오후예요 👋';

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
  String get sideDrawerTopicSearchModeLabel => '주제 모드';

  @override
  String get sideDrawerGlobalSearchModeLabel => '전체 모드';

  @override
  String get sideDrawerSearchModeSwipeToTopicHint =>
      '검색창을 스와이프하면 주제 검색으로 전환됩니다';

  @override
  String get sideDrawerSearchModeSwipeToGlobalHint =>
      '검색창을 스와이프하면 전체 검색으로 전환됩니다';

  @override
  String get sideDrawerGlobalSearchHint => '모든 세션 검색';

  @override
  String get sideDrawerGlobalSearchEmptyHint => '제목과 메시지 전체에서 검색합니다';

  @override
  String get sideDrawerGlobalSearchNoResults => '일치하는 세션이 없습니다';

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
  String get providerAvatarLobehubDialogHint =>
      'LobeHub 아이콘 이름을 입력하세요 (예: openai)';

  @override
  String get sideDrawerEmojiDialogTitle => '이모지 선택';

  @override
  String get sideDrawerEmojiDialogHint => '이모지를 입력하거나 붙여넣으세요';

  @override
  String get sideDrawerImageUrlDialogTitle => '이미지 URL 입력';

  @override
  String get sideDrawerImageUrlDialogHint =>
      '예: https://example.com/avatar.png';

  @override
  String get sideDrawerQQAvatarDialogTitle => 'QQ에서 가져오기';

  @override
  String get sideDrawerQQAvatarInputHint => 'QQ 번호를 입력하세요 (5~12자리)';

  @override
  String get sideDrawerQQAvatarFetchFailed =>
      '무작위 QQ 아바타를 가져오지 못했습니다. 다시 시도하세요.';

  @override
  String get sideDrawerRandomQQ => '무작위 QQ';

  @override
  String get sideDrawerGalleryOpenError => '갤러리를 열 수 없습니다. 이미지 URL을 입력해 보세요.';

  @override
  String get sideDrawerGeneralImageError => '문제가 발생했습니다. 이미지 URL을 입력해 보세요.';

  @override
  String get sideDrawerSetNicknameTitle => '닉네임 설정';

  @override
  String get sideDrawerNicknameLabel => '닉네임';

  @override
  String get sideDrawerNicknameHint => '새 닉네임을 입력하세요';

  @override
  String get sideDrawerRename => '이름 변경';

  @override
  String get chatInputBarHint => 'AI에게 보낼 메시지를 입력하세요';

  @override
  String get chatInputBarSelectModelTooltip => '모델 선택';

  @override
  String get chatInputBarOnlineSearchTooltip => '온라인 검색';

  @override
  String get chatInputBarReasoningStrengthTooltip => '추론 강도';

  @override
  String get chatInputBarMcpServersTooltip => 'MCP 서버';

  @override
  String get chatInputBarMoreTooltip => '추가';

  @override
  String get chatInputBarImageMode => '이미지 모드';

  @override
  String get chatInputBarDisableImageModeTooltip => '이미지 모드 끄기';

  @override
  String get chatInputBarQueuedPending => '전송 대기 중';

  @override
  String get chatInputBarQueuedCancel => '대기열 취소';

  @override
  String get chatInputBarInsertNewline => '줄바꿈';

  @override
  String get chatInputBarExpand => '펼치기';

  @override
  String get chatInputBarCollapse => '접기';

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
  String get mcpPageReconnect => '재연결';

  @override
  String get mcpPageStatusConnected => '연결됨';

  @override
  String get mcpPageStatusConnecting => '연결 중…';

  @override
  String get mcpPageStatusDisconnected => '연결 끊김';

  @override
  String get mcpPageStatusDisabled => '사용 안 함';

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
  String get mcpPageConfirmDeleteContent => '삭제 후 실행 취소로 되돌릴 수 있습니다. 삭제하시겠습니까?';

  @override
  String get mcpPageServerDeleted => '서버가 삭제되었습니다';

  @override
  String get mcpPageUndo => '실행 취소';

  @override
  String get mcpPageCancel => '취소';

  @override
  String get mcpConversationSheetTitle => 'MCP 서버';

  @override
  String get mcpConversationSheetSubtitle => '이 대화에서 사용할 서버를 선택하세요';

  @override
  String get mcpConversationSheetSelectAll => '전체 선택';

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
  String get mcpServerEditSheetSseRetryHint => 'SSE 연결이 실패하면 몇 번 다시 시도해 보세요';

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
  String get defaultModelPageTitleModelTitle => '제목 요약 모델';

  @override
  String get defaultModelPageTitleModelSubtitle =>
      '대화 제목 요약에 사용됩니다. 빠르고 저렴한 모델을 권장합니다';

  @override
  String get titleModelThinkingTitle => '추론 사용';

  @override
  String get defaultModelPageSummaryModelTitle => '요약 모델';

  @override
  String get defaultModelPageSummaryModelSubtitle =>
      '대화 요약 생성에 사용됩니다. 빠르고 저렴한 모델을 권장합니다';

  @override
  String get defaultModelPageSuggestionModelTitle => '채팅 추천 모델';

  @override
  String get defaultModelPageSuggestionModelSubtitle =>
      '어시스턴트 응답 후 표시되는 추천 질문 버블에 사용됩니다. 모델을 선택하기 전까지는 사용할 수 없습니다.';

  @override
  String get assistantEditRecentChatsSummaryFrequencyTitle => '요약 갱신 빈도';

  @override
  String get assistantEditRecentChatsSummaryFrequencyDescription =>
      '선택한 개수만큼 새 메시지가 쌓이면 최근 채팅 요약을 갱신합니다.';

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
      '최근 채팅 요약을 갱신하기 전에 쌓여야 할 새 메시지 개수를 입력하세요.';

  @override
  String get assistantEditRecentChatsSummaryFrequencyCustomLabel => '새 메시지 개수';

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
      '메시지 내용 번역에 사용됩니다. 빠르고 정확한 모델을 권장합니다';

  @override
  String get defaultModelPageOcrModelTitle => 'OCR 모델';

  @override
  String get defaultModelPageOcrModelSubtitle => '이미지에서 텍스트와 설명을 추출하는 데 사용됩니다';

  @override
  String get defaultModelPageOcrModelRequiresImageInput =>
      'OCR을 사용하려면 이미지 입력을 지원하는 모델을 선택하세요';

  @override
  String get defaultModelPagePromptLabel => '프롬프트';

  @override
  String get defaultModelPageTitlePromptHint => '제목 요약에 사용할 프롬프트 템플릿을 입력하세요';

  @override
  String get defaultModelPageSummaryPromptHint => '요약 생성에 사용할 프롬프트 템플릿을 입력하세요';

  @override
  String get defaultModelPageSuggestionPromptHint =>
      '채팅 추천에 사용할 프롬프트 템플릿을 입력하세요';

  @override
  String get defaultModelPageTranslatePromptHint => '번역에 사용할 프롬프트 템플릿을 입력하세요';

  @override
  String get defaultModelPageOcrPromptHint => 'OCR 이미지 이해에 사용할 프롬프트 템플릿을 입력하세요';

  @override
  String get defaultModelPageResetDefault => '기본값으로 재설정';

  @override
  String get defaultModelPageSave => '저장';

  @override
  String defaultModelPageTitleVars(String contentVar, String localeVar) {
    return '변수: 내용: $contentVar, 언어: $localeVar';
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
    return '변수: 대화: $contentVar, 언어: $localeVar';
  }

  @override
  String get defaultModelPageCompressModelTitle => '압축 모델';

  @override
  String get defaultModelPageCompressModelSubtitle =>
      '대화 컨텍스트 압축에 사용됩니다. 빠른 모델을 권장합니다';

  @override
  String get defaultModelPageCompressPromptHint =>
      '컨텍스트 압축에 사용할 프롬프트 템플릿을 입력하세요';

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
  String get defaultModelPageNotEnabled => '사용 안 함';

  @override
  String get translatePagePasteButton => '붙여넣기';

  @override
  String get translatePageCopyResult => '결과 복사';

  @override
  String get translatePageClearAll => '모두 지우기';

  @override
  String get translatePageInputHint => '번역할 텍스트를 입력하세요…';

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
  String get modelDetailSheetModelIdHint => '필수, 소문자/숫자/하이픈 권장';

  @override
  String modelDetailSheetModelIdDisabledHint(String modelId) {
    return '$modelId';
  }

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
  String get modelDetailSheetProviderOverrideDescription =>
      '공급자 재정의: 특정 모델에 대해 공급자를 별도로 지정합니다.';

  @override
  String get modelDetailSheetAddProviderOverride => '공급자 재정의 추가';

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
      '내장 도구는 공식 API에서만 지원됩니다.';

  @override
  String get modelDetailSheetBuiltinToolsUnsupportedHint =>
      '현재 공급자는 이 내장 도구를 지원하지 않습니다.';

  @override
  String get modelDetailSheetSearchTool => '검색';

  @override
  String get modelDetailSheetSearchToolDescription => 'Google 검색 연동 사용';

  @override
  String get modelDetailSheetUrlContextTool => 'URL 컨텍스트';

  @override
  String get modelDetailSheetUrlContextToolDescription => 'URL 콘텐츠 수집 사용';

  @override
  String get modelDetailSheetCodeExecutionTool => '코드 실행';

  @override
  String get modelDetailSheetCodeExecutionToolDescription => '코드 실행 도구 사용';

  @override
  String get modelDetailSheetYoutubeTool => 'YouTube';

  @override
  String get modelDetailSheetYoutubeToolDescription =>
      'YouTube URL 수집 사용(프롬프트 내 링크 자동 감지)';

  @override
  String get modelDetailSheetOpenaiBuiltinToolsResponsesOnlyHint =>
      'OpenAI Responses API가 필요합니다.';

  @override
  String get modelDetailSheetOpenaiCodeInterpreterTool => '코드 인터프리터';

  @override
  String get modelDetailSheetOpenaiCodeInterpreterToolDescription =>
      '코드 인터프리터 도구 사용(컨테이너 자동, 메모리 제한 4g)';

  @override
  String get modelDetailSheetOpenaiImageGenerationTool => '이미지 생성';

  @override
  String get modelDetailSheetOpenaiImageGenerationToolDescription =>
      '이미지 생성 도구 사용';

  @override
  String get modelDetailSheetCancelButton => '취소';

  @override
  String get modelDetailSheetAddButton => '추가';

  @override
  String get modelDetailSheetConfirmButton => '확인';

  @override
  String get modelDetailSheetInvalidIdError => '올바른 모델 ID를 입력해 주세요(2자 이상)';

  @override
  String get modelDetailSheetModelIdExistsError => '이미 존재하는 모델 ID입니다';

  @override
  String get modelDetailSheetHeaderKeyHint => '헤더 키';

  @override
  String get modelDetailSheetHeaderValueHint => '헤더 값';

  @override
  String get modelDetailSheetBodyKeyHint => '본문 키';

  @override
  String get modelDetailSheetBodyJsonHint => '본문 JSON';

  @override
  String get modelSelectSheetSearchHint => '모델 또는 공급자 검색';

  @override
  String get modelSelectSheetFavoritesSection => '즐겨찾기';

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
  String get providerDetailPageNetworkTab => '네트워크';

  @override
  String get providerDetailPageEnabledTitle => '사용';

  @override
  String get providerDetailPageManageSectionTitle => '관리';

  @override
  String get providerDetailPageNameLabel => '이름';

  @override
  String get providerDetailPageApiKeyHint => '비워두면 기본값을 사용합니다';

  @override
  String get providerDetailPageHideTooltip => '숨기기';

  @override
  String get providerDetailPageShowTooltip => '표시';

  @override
  String get providerDetailPageApiPathLabel => 'API 경로';

  @override
  String get providerDetailPageResponseApiTitle => 'Response API (/responses)';

  @override
  String get providerDetailPageAihubmixAppCodeLabel => 'APP-Code(10% 할인)';

  @override
  String get providerDetailPageAihubmixAppCodeHelp =>
      '요청 헤더에 APP-Code를 추가해 10% 할인을 받습니다. AIhubmix에만 적용됩니다.';

  @override
  String get providerDetailPageClaudePromptCachingTitle => 'Claude 프롬프트 캐싱';

  @override
  String get providerDetailPageClaudePromptCachingHelp =>
      'Anthropic 또는 OpenRouter를 통한 Claude 요청에 cache_control을 추가합니다.';

  @override
  String get providerDetailPageClaudePromptCachingTtlTitle => '캐시 TTL';

  @override
  String get providerDetailPageClaudePromptCachingTtlHelp =>
      '기본값은 5분입니다. 1시간은 쓰기 비용이 더 들지만 긴 대화에서 재구성을 줄일 수 있습니다.';

  @override
  String get providerDetailPageClaudePromptCachingTtl5m => '5분';

  @override
  String get providerDetailPageClaudePromptCachingTtl1h => '1시간';

  @override
  String get providerDetailPageBalanceTitle => '계정 잔액';

  @override
  String get providerDetailPageBalanceInfo => '계정 잔액 조회';

  @override
  String get providerDetailPageBalanceApiPathLabel => '잔액 API 경로';

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
      '실행 취소로 되돌릴 수 있습니다. 삭제할까요?';

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
  String get providerDetailPageUsernameOptionalLabel => '사용자 이름(선택 사항)';

  @override
  String get providerDetailPagePasswordOptionalLabel => '비밀번호(선택 사항)';

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
  String get providerDetailPageFilterHint => '모델 이름을 입력해 필터링';

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
  String get providerGroupsGroupLabel => '그룹';

  @override
  String get providerGroupsOther => '기타';

  @override
  String get providerGroupsOtherUngroupedOption => '기타(미분류)';

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
  String get providerGroupsCreateFailedToast => '그룹 생성에 실패했습니다';

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
  String get providersPageEnabledStatus => 'ON';

  @override
  String get providersPageDisabledStatus => 'OFF';

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
      '서비스 계정 JSON(붙여넣기 또는 가져오기)';

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
  String get shareProviderSheetDescription => 'QR 코드로 복사하거나 공유하세요.';

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
  String get qrScanPageInstruction => '프레임 안에 QR 코드를 맞춰주세요';

  @override
  String get searchServicesPageBackTooltip => '뒤로';

  @override
  String get searchServicesPageTitle => '검색 서비스';

  @override
  String get searchServicesPageDone => '완료';

  @override
  String get searchServicesPageEdit => '편집';

  @override
  String get searchServicesPageAddProvider => '공급자 추가';

  @override
  String get searchServicesPageSearchProviders => '검색 공급자';

  @override
  String get searchServicesPageGeneralOptions => '일반 옵션';

  @override
  String get searchServicesPageAutoTestTitle => '시작 시 연결 자동 테스트';

  @override
  String get searchServicesPageMaxResults => '최대 결과 수';

  @override
  String get searchServicesPageTimeoutSeconds => '제한 시간(초)';

  @override
  String get searchServicesPageAtLeastOneServiceRequired =>
      '검색 서비스가 하나 이상 필요합니다';

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
  String get searchServicesAddDialogApiKeyRequired => 'API 키가 필요합니다';

  @override
  String get searchServicesFieldCustomUrlOptional => '사용자 지정 URL(선택 사항)';

  @override
  String get searchServicesDialogApiKey => 'API 키';

  @override
  String get searchServicesDialogModel => '모델';

  @override
  String get searchServicesDialogSystemPrompt => '시스템 프롬프트';

  @override
  String get searchServicesAddDialogInstanceUrl => '인스턴스 URL';

  @override
  String get searchServicesAddDialogUrlRequired => 'URL이 필요합니다';

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
      'Bing 로컬 검색은 별도 설정이 필요하지 않습니다.';

  @override
  String get searchServicesEditDialogApiKeyRequired => 'API 키가 필요합니다';

  @override
  String get searchServicesEditDialogInstanceUrl => '인스턴스 URL';

  @override
  String get searchServicesEditDialogUrlRequired => 'URL이 필요합니다';

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
  String get searchSettingsSheetTitle => '검색 설정';

  @override
  String get searchSettingsSheetBuiltinSearchTitle => '내장 검색';

  @override
  String get searchSettingsSheetBuiltinSearchDescription => '모델의 내장 검색 사용';

  @override
  String get searchSettingsSheetClaudeDynamicSearchTitle => '내장 검색(신규)';

  @override
  String get searchSettingsSheetClaudeDynamicSearchDescription =>
      '지원되는 공식 Claude 모델에서 동적 필터링을 적용한 `web_search_20260209`를 사용합니다.';

  @override
  String get searchSettingsSheetWebSearchTitle => '웹 검색';

  @override
  String get searchSettingsSheetWebSearchDescription => '채팅에서 웹 검색 사용';

  @override
  String get searchSettingsSheetOpenSearchServicesTooltip => '검색 서비스 열기';

  @override
  String get searchSettingsSheetNoServicesMessage =>
      '서비스가 없습니다. 검색 서비스에서 추가하세요.';

  @override
  String get aboutPageEasterEggMessage => '탐험해 주셔서 감사합니다!\n(아직 에그는 없어요)';

  @override
  String get aboutPageEasterEggButton => '좋아요!';

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
  String get aboutPageJoinQQGroup => 'QQ 그룹 참여하기';

  @override
  String get aboutPageQQGroupOne => 'Kelivo 그룹 1';

  @override
  String get aboutPageQQGroupTwo => 'Kelivo 그룹 2';

  @override
  String get aboutPageJoinDiscord => 'Discord에 참여하기';

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
      '채팅 메시지에 사용자 이름과 그 아래 타임스탬프를 표시합니다';

  @override
  String get displaySettingsPageShowUserNameTitle => '사용자 이름 표시';

  @override
  String get displaySettingsPageShowUserTimestampTitle => '사용자 메시지 시간 표시';

  @override
  String get displaySettingsPageShowUserMessageActionsTitle =>
      '사용자 메시지 작업 버튼 표시';

  @override
  String get displaySettingsPageShowUserMessageActionsSubtitle =>
      '내 메시지 아래에 복사, 재전송 등의 버튼을 표시합니다';

  @override
  String get displaySettingsPageShowModelNameTimestampTitle => '모델 이름 및 시간 표시';

  @override
  String get displaySettingsPageShowModelNameTimestampSubtitle =>
      '채팅 메시지 아래에 모델 이름과 시간을 표시합니다';

  @override
  String get displaySettingsPageShowModelNameTitle => '모델 이름 표시';

  @override
  String get displaySettingsPageShowModelTimestampTitle => '모델 시간 표시';

  @override
  String get displaySettingsPageShowProviderInChatMessageTitle =>
      '모델 이름 뒤에 공급자 표시';

  @override
  String get displaySettingsPageShowProviderInChatMessageSubtitle =>
      '채팅 메시지의 모델 ID 뒤에 공급자 이름을 표시합니다 (예: model | provider)';

  @override
  String get displaySettingsPageChatModelIconTitle => '채팅 모델 아이콘';

  @override
  String get displaySettingsPageChatModelIconSubtitle =>
      '채팅 메시지에 모델 아이콘을 표시합니다';

  @override
  String get displaySettingsPageShowTokenStatsTitle => '토큰 및 컨텍스트 통계 표시';

  @override
  String get displaySettingsPageShowTokenStatsSubtitle =>
      '토큰 사용량과 메시지 수를 표시합니다';

  @override
  String get displaySettingsPageAutoCollapseThinkingTitle => '추론 자동 접기';

  @override
  String get displaySettingsPageAutoCollapseThinkingSubtitle =>
      '완료 후 추론 내용을 접습니다';

  @override
  String get displaySettingsPageCollapseThinkingStepsTitle => '추론 단계 접기';

  @override
  String get displaySettingsPageCollapseThinkingStepsSubtitle =>
      '펼치기 전까지 최신 단계만 표시합니다';

  @override
  String get displaySettingsPageShowToolResultSummaryTitle => '도구 결과 요약 표시';

  @override
  String get displaySettingsPageInsertSuggestionOnlyTitle =>
      '전송하지 않고 제안 내용만 입력';

  @override
  String get displaySettingsPageShowToolResultSummarySubtitle =>
      '도구 단계 아래에 요약 텍스트를 표시합니다';

  @override
  String get displaySettingsPageRegenerateDeleteTrailingMessagesTitle =>
      '재생성 시 아래쪽 메시지 삭제';

  @override
  String get displaySettingsPageShowRegenerateConfirmDialogTitle => '재생성 전 확인';

  @override
  String chainOfThoughtExpandSteps(Object count) {
    return '단계 $count개 더 보기';
  }

  @override
  String get chainOfThoughtCollapse => '접기';

  @override
  String get displaySettingsPageShowChatListDateTitle => '채팅 목록 날짜 표시';

  @override
  String get displaySettingsPageShowChatListDateSubtitle =>
      '대화 목록에 날짜 구분 라벨을 표시합니다';

  @override
  String get displaySettingsPageEnableImageCropperTitle => '이미지 자르기 사용';

  @override
  String get displaySettingsPageEnableImageCropperSubtitle =>
      '갤러리나 카메라에서 선택한 이미지를 자릅니다';

  @override
  String get displaySettingsPageKeepSidebarOpenOnAssistantTapTitle =>
      '어시스턴트 선택 시 사이드바 유지';

  @override
  String get displaySettingsPageKeepSidebarOpenOnTopicTapTitle =>
      '토픽 선택 시 사이드바 유지';

  @override
  String get displaySettingsPageKeepAssistantListExpandedOnSidebarCloseTitle =>
      '사이드바를 닫을 때 어시스턴트 목록 접지 않기';

  @override
  String get displaySettingsPageShowUpdatesTitle => '업데이트 표시';

  @override
  String get displaySettingsPageShowUpdatesSubtitle => '앱 업데이트 알림을 표시합니다';

  @override
  String get displaySettingsPageMessageNavButtonsTitle => '메시지 이동 버튼';

  @override
  String get displaySettingsPageMessageNavButtonsSubtitle =>
      '빠른 이동 버튼이 표시되는 시점을 선택합니다';

  @override
  String get displaySettingsPageMessageNavButtonsModeAlways => '항상 표시';

  @override
  String get displaySettingsPageMessageNavButtonsModeScroll => '스크롤 중 표시';

  @override
  String get displaySettingsPageMessageNavButtonsModeHover => '마우스를 올렸을 때 표시';

  @override
  String get displaySettingsPageMessageNavButtonsModeScrollAndHover =>
      '스크롤 중이거나 마우스를 올렸을 때 표시';

  @override
  String get displaySettingsPageMessageNavButtonsModeNever => '표시 안 함';

  @override
  String get displaySettingsPageUseNewAssistantAvatarUxTitle =>
      '채팅 제목 표시줄에 어시스턴트 아바타 표시';

  @override
  String get displaySettingsPageHapticsOnSidebarTitle => '사이드바 햅틱';

  @override
  String get displaySettingsPageHapticsOnSidebarSubtitle =>
      '사이드바를 열고 닫을 때 햅틱 피드백을 사용합니다';

  @override
  String get displaySettingsPageHapticsGlobalTitle => '전체 햅틱';

  @override
  String get displaySettingsPageHapticsIosSwitchTitle => '스위치 햅틱';

  @override
  String get displaySettingsPageHapticsOnListItemTapTitle => '목록 항목 햅틱';

  @override
  String get displaySettingsPageHapticsOnCardTapTitle => '카드 햅틱';

  @override
  String get displaySettingsPageHapticsOnGenerateTitle => '생성 시 햅틱';

  @override
  String get displaySettingsPageHapticsOnGenerateSubtitle =>
      '생성 중 햅틱 피드백을 사용합니다';

  @override
  String get displaySettingsPageNewChatAfterDeleteTitle => '토픽 삭제 후 새 채팅 시작';

  @override
  String get displaySettingsPageNewChatOnAssistantSwitchTitle =>
      '어시스턴트 전환 시 새 채팅 시작';

  @override
  String get displaySettingsPageNewChatOnLaunchTitle => '실행 시 새 채팅 시작';

  @override
  String get displaySettingsPageEnterToSendTitle => 'Enter 키로 전송';

  @override
  String get displaySettingsPageSendShortcutTitle => '전송 단축키';

  @override
  String get displaySettingsPageSendShortcutEnter => 'Enter';

  @override
  String get displaySettingsPageSendShortcutCtrlEnter => 'Ctrl/Cmd + Enter';

  @override
  String get displaySettingsPageAutoSwitchTopicsTitle => '토픽으로 자동 전환';

  @override
  String get desktopDisplaySettingsTopicPositionTitle => '토픽 위치';

  @override
  String get desktopDisplaySettingsTopicPositionLeft => '왼쪽';

  @override
  String get desktopDisplaySettingsTopicPositionRight => '오른쪽';

  @override
  String get displaySettingsPageNewChatOnLaunchSubtitle =>
      '실행 시 자동으로 새 채팅을 만듭니다';

  @override
  String get displaySettingsPageChatFontSizeTitle => '채팅 글꼴 크기';

  @override
  String get displaySettingsPageAutoScrollEnableTitle => '하단으로 자동 스크롤';

  @override
  String get displaySettingsPageAutoScrollIdleTitle => '자동 스크롤 복귀 지연 시간';

  @override
  String get displaySettingsPageAutoScrollIdleSubtitle =>
      '사용자가 스크롤한 후 하단으로 이동하기까지의 대기 시간';

  @override
  String get displaySettingsPageAutoScrollDisabledLabel => '끄기';

  @override
  String get displaySettingsPageChatFontSampleText => '채팅 글꼴 미리보기 예시 텍스트입니다';

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
  String get desktopFontFilterHint => '글꼴 필터...';

  @override
  String get displaySettingsPageAppFontTitle => '앱 글꼴';

  @override
  String get displaySettingsPageCodeFontTitle => '코드 글꼴';

  @override
  String get fontPickerChooseLocalFile => '로컬 파일 선택';

  @override
  String get fontPickerGetFromGoogleFonts => 'Google Fonts 찾아보기';

  @override
  String get fontPickerFilterHint => '글꼴 필터...';

  @override
  String get desktopFontLoading => '글꼴 불러오는 중…';

  @override
  String get displaySettingsPageFontLocalFileLabel => '로컬 파일';

  @override
  String get displaySettingsPageFontResetLabel => '글꼴 설정 초기화';

  @override
  String get displaySettingsPageOtherSettingsTitle => '기타 설정';

  @override
  String get themeSettingsPageDynamicColorSection => '다이나믹 컬러';

  @override
  String get themeSettingsPageUseDynamicColorTitle => '시스템 다이나믹 컬러';

  @override
  String get themeSettingsPageUseDynamicColorSubtitle =>
      '시스템 팔레트에 맞춥니다 (Android 12 이상)';

  @override
  String get themeSettingsPageUsePureBackgroundTitle => '순수 배경';

  @override
  String get themeSettingsPageUsePureBackgroundSubtitle =>
      '말풍선과 강조 색상은 테마를 따릅니다.';

  @override
  String get themeSettingsPageColorPalettesSection => '색상 팔레트';

  @override
  String get ttsServicesPageBackButton => '뒤로';

  @override
  String get ttsServicesPageTitle => '음성 합성';

  @override
  String get ttsServicesPageSettingsTooltip => 'TTS 설정';

  @override
  String get ttsServicesPageAddTooltip => '추가';

  @override
  String get ttsServicesPageAddNotImplemented => 'TTS 서비스 추가 기능은 아직 구현되지 않았습니다';

  @override
  String get ttsServicesPageSystemTtsTitle => '시스템 TTS';

  @override
  String get ttsServicesPageSystemTtsAvailableSubtitle => '시스템에 내장된 TTS를 사용합니다';

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
  String get ttsServicesPageStopTooltip => '정지';

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
  String get ttsServicesValidationApiKeyRequired => 'API 키를 입력해야 합니다';

  @override
  String get ttsServicesViewDetailsButton => '자세히 보기';

  @override
  String get ttsServicesDialogErrorTitle => '오류 상세 정보';

  @override
  String get ttsServicesCloseButton => '닫기';

  @override
  String get ttsSettingsPageTitle => 'TTS 설정';

  @override
  String get ttsSettingsPlaybackSection => '재생';

  @override
  String get ttsSettingsAutoPlayTitle => '어시스턴트 답변 자동 재생';

  @override
  String get ttsSettingsAutoPlayDescription => '어시스턴트 답변이 끝나면 자동으로 TTS를 재생합니다.';

  @override
  String get ttsSettingsTextSelectionSection => '텍스트 선택';

  @override
  String get ttsSettingsTextSelectionFallbackDescription =>
      '일치하는 텍스트가 없으면 전체 답변을 재생합니다.';

  @override
  String get ttsSettingsTextSelectionFullTextTitle => '전체 텍스트';

  @override
  String get ttsSettingsTextSelectionFullTextDescription =>
      '어시스턴트의 전체 답변을 재생합니다.';

  @override
  String get ttsSettingsTextSelectionQuotedOnlyTitle => '인용된 텍스트만';

  @override
  String get ttsSettingsTextSelectionQuotedOnlyDescription =>
      '“”, ‘’, \"\", \'\', 「」, 『』 안의 텍스트만 재생합니다.';

  @override
  String get ttsSettingsTextSelectionOutsideParenthesesTitle => '괄호 밖 텍스트';

  @override
  String get ttsSettingsTextSelectionOutsideParenthesesDescription =>
      '() 및 （） 안의 텍스트는 건너뜁니다.';

  @override
  String get ttsSettingsTextSelectionItalicOnlyTitle => '기울임체 텍스트만';

  @override
  String get ttsSettingsTextSelectionItalicOnlyDescription =>
      'Markdown 또는 HTML의 기울임체 텍스트를 재생합니다.';

  @override
  String get ttsSettingsTextSelectionNonItalicTitle => '기울임체가 아닌 텍스트만';

  @override
  String get ttsSettingsTextSelectionNonItalicDescription =>
      'Markdown 또는 HTML의 기울임체 텍스트는 건너뜁니다.';

  @override
  String get ttsFloatingPlayerLabel => 'TTS 플레이어';

  @override
  String get ttsFloatingPauseTooltip => '일시정지';

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
  String imageViewerPageShareFailedOpenFile(String message) {
    return '공유할 수 없어 파일 열기를 시도했습니다: $message';
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
    return '이미지 $index/$total';
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
      '웹 스크래핑으로 Bing 검색 결과를 가져옵니다. API 키가 필요 없지만 불안정할 수 있습니다.';

  @override
  String get searchProviderDuckDuckGoDescription =>
      'DDGS를 통한 개인정보 보호 중심의 DuckDuckGo 검색입니다. API 키가 필요 없으며 지역 선택을 지원합니다.';

  @override
  String get searchProviderBraveDescription =>
      'Brave의 독립 검색 엔진입니다. 추적이나 프로파일링 없이 개인정보를 보호합니다.';

  @override
  String get searchProviderExaDescription =>
      '의미 이해 기반의 신경망 검색입니다. 리서치와 특정 콘텐츠 찾기에 적합합니다.';

  @override
  String get searchProviderLinkUpDescription =>
      '출처가 명시된 답변을 제공하는 검색 API입니다. 검색 결과와 AI 생성 요약을 함께 제공합니다.';

  @override
  String get searchProviderMetasoDescription =>
      'Metaso의 중국어 검색입니다. AI 기능으로 중국어 콘텐츠에 최적화되어 있습니다.';

  @override
  String get searchProviderSearXNGDescription =>
      '개인정보를 존중하는 메타 검색 엔진입니다. 자체 호스팅 인스턴스가 필요하며 추적하지 않습니다.';

  @override
  String get searchProviderTavilyDescription =>
      'LLM에 최적화된 AI 검색 API입니다. 고품질의 관련성 높은 결과를 제공합니다.';

  @override
  String get searchProviderZhipuDescription =>
      'Zhipu AI의 중국어 AI 검색입니다. 중국어 콘텐츠와 쿼리에 최적화되어 있습니다.';

  @override
  String get searchProviderOllamaDescription =>
      'Ollama 웹 검색 API입니다. 모델에 최신 정보를 보강합니다.';

  @override
  String get searchProviderJinaDescription =>
      '임베딩, 재순위화, 웹 리더, 딥서치, 소형 언어 모델을 갖춘 AI 검색 기반입니다. 다국어 및 멀티모달을 지원합니다.';

  @override
  String get searchServiceNameBingLocal => 'Bing (로컬)';

  @override
  String get searchServiceNameDuckDuckGo => 'DuckDuckGo';

  @override
  String get searchServiceNameTavily => 'Tavily';

  @override
  String get searchServiceNameExa => 'Exa';

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
  String get searchServiceNameJina => 'Jina';

  @override
  String get searchServiceNamePerplexity => 'Perplexity';

  @override
  String get searchProviderPerplexityDescription =>
      'Perplexity 검색 API입니다. 지역 및 도메인 필터로 순위가 매겨진 웹 결과를 제공합니다.';

  @override
  String get searchServiceNameBocha => 'Bocha';

  @override
  String get searchProviderBochaDescription =>
      'Bocha 웹 검색 API입니다. 정확한 웹 결과와 선택적 요약을 제공합니다.';

  @override
  String get searchServiceNameSerper => 'Serper';

  @override
  String get searchProviderSerperDescription =>
      'Serper Google 검색 API입니다. 국가, 언어, 시간, 페이지 필터를 선택적으로 적용해 빠른 웹 결과를 제공합니다.';

  @override
  String get searchServiceNameQuerit => 'Querit';

  @override
  String get searchProviderQueritDescription =>
      'LLM 애플리케이션을 위한 Querit 검색 API입니다. 사이트, 시간, 국가, 언어 필터로 실시간 웹 결과를 반환합니다.';

  @override
  String get searchServiceNameGrok => 'Grok';

  @override
  String get searchProviderGrokDescription =>
      'xAI Responses API를 통한 Grok 검색입니다. 웹 및 X 검색 도구를 사용하고 출처를 인용해 반환합니다.';

  @override
  String get searchServicesDialogCountryOptional => '국가/지역 (선택 사항)';

  @override
  String get searchServicesDialogLanguageOptional => '언어 (선택 사항)';

  @override
  String get searchServicesDialogTimeFilterOptional => '기간 필터 (선택 사항)';

  @override
  String get searchServicesDialogPageOptional => '페이지 (선택 사항)';

  @override
  String get searchServicesDialogPageInvalid => '페이지는 양의 정수여야 합니다.';

  @override
  String get searchServicesDialogSitesIncludeOptional => '포함할 사이트 (선택 사항)';

  @override
  String get searchServicesDialogSitesExcludeOptional => '제외할 사이트 (선택 사항)';

  @override
  String get searchServicesDialogTimeRangeOptional => '기간 범위 (선택 사항)';

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
  String get instructionInjectionAddTooltip => '지침 추가';

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
    return '지침 $count개를 가져왔습니다';
  }

  @override
  String get instructionInjectionSheetSubtitle => '채팅 전에 적용할 프롬프트를 선택하세요';

  @override
  String get mcpJsonEditButtonTooltip => 'JSON 편집';

  @override
  String get mcpJsonEditTitle => 'JSON 편집';

  @override
  String get mcpJsonEditParseFailed => 'JSON 파싱에 실패했습니다';

  @override
  String get mcpJsonEditSavedApplied => '저장 및 적용 완료';

  @override
  String get mcpTimeoutSettingsTooltip => '도구 호출 제한 시간 설정';

  @override
  String get mcpTimeoutDialogTitle => '도구 호출 제한 시간';

  @override
  String get mcpTimeoutSecondsLabel => '도구 호출 제한 시간(초)';

  @override
  String get mcpTimeoutInvalid => '양수의 초 값을 입력하세요';

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
      '이 어시스턴트의 빠른 문구를 관리하세요. 아래 버튼을 눌러 문구를 추가할 수 있습니다.';

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
      '필요한 경우 기기 클립보드에서 일반 텍스트를 읽거나 씁니다.';

  @override
  String get assistantEditLocalToolTextToSpeechTitle => '텍스트 음성 변환';

  @override
  String get assistantEditLocalToolTextToSpeechSubtitle =>
      '설정된 TTS 재생으로 어시스턴트가 텍스트를 소리 내어 읽도록 합니다.';

  @override
  String get assistantEditLocalToolAskUserTitle => '사용자에게 질문';

  @override
  String get assistantEditLocalToolAskUserSubtitle =>
      '어시스턴트가 짧은 질문을 하고 답변 후 이어서 진행하도록 합니다.';

  @override
  String get assistantEditLocalToolCalculateTitle => '계산기';

  @override
  String get assistantEditLocalToolCalculateSubtitle =>
      '수식을 계산합니다. + - * / power sqrt sin cos 등을 지원합니다.';

  @override
  String get assistantEditMemorySwitchTitle => '메모리';

  @override
  String get assistantEditMemorySwitchDescription =>
      '어시스턴트가 채팅 간에 메모리를 생성하고 사용하도록 허용합니다.';

  @override
  String get assistantEditRecentChatsSwitchTitle => '최근 채팅 참조';

  @override
  String get assistantEditRecentChatsSwitchDescription =>
      '맥락 파악에 도움이 되도록 최근 대화 제목을 포함합니다.';

  @override
  String get assistantEditManageMemoryTitle => '메모리 관리';

  @override
  String get assistantEditAddMemoryButton => '메모리 추가';

  @override
  String get assistantEditMemoryEmpty => '아직 메모리가 없습니다';

  @override
  String get assistantEditMemoryDialogTitle => '메모리';

  @override
  String get assistantEditMemoryDialogHint => '메모리 내용을 입력하세요';

  @override
  String get assistantEditAddQuickPhraseButton => '빠른 문구 추가';

  @override
  String get multiKeyPageDeleteSnackbarDeletedOne => '키 1개를 삭제했습니다';

  @override
  String get multiKeyPageUndo => '실행 취소';

  @override
  String get multiKeyPageUndoRestored => '복원됨';

  @override
  String get multiKeyPageDeleteErrorsTooltip => '오류 삭제';

  @override
  String get multiKeyPageDeleteErrorsConfirmTitle => '오류로 표시된 키를 모두 삭제할까요?';

  @override
  String get multiKeyPageDeleteErrorsConfirmContent => '오류로 표시된 모든 키가 삭제됩니다.';

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
      '선택한 공급자를 삭제할까요? 이 작업은 되돌릴 수 없습니다.';

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
  String get assistantEditPresetTitle => '사전 설정 대화';

  @override
  String get assistantEditPresetAddUser => '사용자 사전 설정 추가';

  @override
  String get assistantEditPresetAddAssistant => '어시스턴트 사전 설정 추가';

  @override
  String get assistantEditPresetInputHintUser => '사용자 메시지를 입력하세요…';

  @override
  String get assistantEditPresetInputHintAssistant => '어시스턴트 메시지를 입력하세요…';

  @override
  String get assistantEditPresetEmpty => '아직 사전 설정 메시지가 없습니다';

  @override
  String get assistantEditPresetEditDialogTitle => '사전 설정 메시지 편집';

  @override
  String get assistantEditPresetRoleUser => '사용자';

  @override
  String get assistantEditPresetRoleAssistant => '어시스턴트';

  @override
  String get desktopTtsPleaseAddProvider => '먼저 TTS 공급자를 추가하세요';

  @override
  String get settingsPageNetworkProxy => '네트워크 프록시';

  @override
  String get networkProxyEnableLabel => '프록시 사용';

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
      '전역 프록시와 공급자별 프록시가 모두 사용 설정된 경우, 공급자별 프록시가 우선 적용됩니다.';

  @override
  String get desktopShowProviderInModelCapsule => '모델 캡슐에 공급자 표시';

  @override
  String get messageWebViewOpenInBrowser => '브라우저에서 열기';

  @override
  String get messageWebViewConsoleLogs => '콘솔 로그';

  @override
  String get messageWebViewNoConsoleMessages => '콘솔 메시지가 없습니다';

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
    return '선택한 모델 $count개를 삭제할까요? 이 작업은 되돌릴 수 없습니다.';
  }

  @override
  String get providerDetailPageDeleteFailedDetectedModelsButton =>
      '사용 불가 모델 삭제';

  @override
  String get providerDetailPageDeleteFailedDetectedModelsTooltip =>
      '감지에 실패한 모델 삭제';

  @override
  String providerDetailPageDeleteFailedDetectedModelsConfirm(int count) {
    return '감지에 실패한 모델 $count개를 삭제할까요? 이 작업은 되돌릴 수 없습니다.';
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
      '사용 설정하면 요청/응답 세부 정보가 logs/logs.txt에 기록되며 매일 순환됩니다.';

  @override
  String get flutterLogSettingTitle => 'Flutter 로깅';

  @override
  String get flutterLogSettingSubtitle =>
      '사용 설정하면 Flutter 오류 및 print 출력이 logs/flutter_logs.txt에 기록되며 매일 순환됩니다.';

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
  String get logViewerFieldStarted => '시작 시각';

  @override
  String get logViewerFieldEnded => '종료 시각';

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
    return '+$count개 더 보기';
  }

  @override
  String get logSettingsTitle => '로그 설정';

  @override
  String get logSettingsSaveOutput => '응답 출력 저장';

  @override
  String get logSettingsSaveOutputSubtitle =>
      '응답 본문 내용을 로그로 남깁니다 (저장 공간을 많이 사용할 수 있습니다)';

  @override
  String get logSettingsAutoDelete => '자동 삭제';

  @override
  String get logSettingsAutoDeleteSubtitle => '지정한 일수보다 오래된 로그를 삭제합니다';

  @override
  String get logSettingsAutoDeleteDisabled => '사용 안 함';

  @override
  String logSettingsAutoDeleteDays(int count) {
    return '$count일';
  }

  @override
  String get logSettingsMaxSize => '최대 로그 크기';

  @override
  String get logSettingsMaxSizeSubtitle => '초과 시 가장 오래된 로그부터 삭제됩니다';

  @override
  String get logSettingsMaxSizeUnlimited => '무제한';

  @override
  String get assistantEditManageSummariesTitle => '요약 관리';

  @override
  String get assistantEditSummaryEmpty => '아직 요약이 없습니다';

  @override
  String get assistantEditSummaryDialogTitle => '요약 편집';

  @override
  String get assistantEditSummaryDialogHint => '요약 내용을 입력하세요';

  @override
  String get assistantEditDeleteSummaryTitle => '요약 지우기';

  @override
  String get assistantEditDeleteSummaryContent => '이 요약을 지우시겠습니까?';

  @override
  String get homePageProcessingFiles => '파일 처리 중...';

  @override
  String get fileUploadDuplicateTitle => '파일이 이미 존재합니다';

  @override
  String fileUploadDuplicateContent(String fileName) {
    return '$fileName 파일이 이미 존재합니다. 기존 파일을 사용할까요?';
  }

  @override
  String get fileUploadDuplicateUseExisting => '기존 파일 사용';

  @override
  String get fileUploadDuplicateUploadNew => '새로 업로드';

  @override
  String get settingsPageWorldBook => '월드북';

  @override
  String get worldBookTitle => '월드북';

  @override
  String get worldBookAdd => '월드북 추가';

  @override
  String get worldBookEmptyMessage => '아직 월드북이 없습니다';

  @override
  String get worldBookUnnamed => '이름 없는 월드북';

  @override
  String get worldBookDisabledTag => '사용 안 함';

  @override
  String get worldBookAlwaysOnTag => '항상 켜짐';

  @override
  String get worldBookAddEntry => '항목 추가';

  @override
  String get worldBookExport => '공유 / 내보내기';

  @override
  String get worldBookConfig => '구성';

  @override
  String get worldBookDeleteTitle => '월드북 삭제';

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
  String get worldBookEnabledLabel => '사용';

  @override
  String get worldBookSave => '저장';

  @override
  String get worldBookEntryNameLabel => '항목 이름';

  @override
  String get worldBookEntryEnabledLabel => '항목 사용';

  @override
  String get worldBookEntryPriorityLabel => '우선순위';

  @override
  String get worldBookEntryKeywordsLabel => '키워드';

  @override
  String get worldBookEntryKeywordsHint => '키워드를 입력하고 +를 눌러 추가하세요.';

  @override
  String get worldBookEntryKeywordInputHint => '키워드를 입력하세요';

  @override
  String get worldBookEntryKeywordAddTooltip => '키워드 추가';

  @override
  String get worldBookEntryUseRegexLabel => '정규식 사용';

  @override
  String get worldBookEntryCaseSensitiveLabel => '대소문자 구분';

  @override
  String get worldBookEntryAlwaysOnLabel => '항상 활성';

  @override
  String get worldBookEntryAlwaysOnHint => '키워드 일치 없이 항상 주입합니다';

  @override
  String get worldBookEntryScanDepthLabel => '검색 깊이';

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
  String get toolApprovalDenyHint => '사유 (선택 사항)';

  @override
  String toolApprovalDeniedMessage(Object reason, Object toolName) {
    return '도구 호출 \"$toolName\"이(가) 사용자에 의해 거부되었습니다. 사유: $reason';
  }

  @override
  String get askUserCardSubmit => '답변 제출';

  @override
  String get askUserCardCustomHint => '답변을 입력하세요';

  @override
  String get askUserCardSomethingElse => '다른 답변';

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
  String get askUserCardCancelled => '질문이 취소되었습니다';

  @override
  String askUserCardQuestionCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '질문 $count개 하기',
      one: '질문 1개 하기',
    );
    return '$_temp0';
  }

  @override
  String tokenDetailPromptTokens(int count) {
    return '토큰 $count개';
  }

  @override
  String tokenDetailPromptTokensWithCache(int count, int cached) {
    return '토큰 $count개 (캐시 $cached개)';
  }

  @override
  String tokenDetailCompletionTokens(int count) {
    return '토큰 $count개';
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
  String tokenDetailTotalTokens(int count) {
    return '토큰 $count개';
  }

  @override
  String get debugPageTitle => '디버그';

  @override
  String get debugPageConversationToolsTitle => '대화 도구';

  @override
  String get debugPageCreateOversizedConversationButton => '대용량 대화 생성 (30 MB)';

  @override
  String get debugPageCreateManyMessagesConversationButton => '메시지 1024개 대화 생성';

  @override
  String get debugPageCreateDailyMixedMarkdownConversationButton =>
      '일별 혼합 Markdown 메시지 3000개 생성';

  @override
  String get debugPageCreateLongReasoningConversationButton =>
      '긴 추론 대화 생성 (메시지 128개)';

  @override
  String get debugPageCreatingButton => '생성 중...';

  @override
  String get debugPageCreatingOversizedConversation => '30MB 대용량 대화를 생성하는 중...';

  @override
  String get debugPageCreatingManyMessagesConversation =>
      '메시지 1024개 대화를 생성하는 중...';

  @override
  String get debugPageCreatingDailyMixedMarkdownConversation =>
      '메시지 3000개짜리 일별 혼합 Markdown 대화를 생성하는 중...';

  @override
  String get debugPageCreatingLongReasoningConversation =>
      '긴 추론 디버그 대화를 생성하는 중...';

  @override
  String get debugPageNoCurrentAssistant =>
      '현재 어시스턴트가 없습니다. 먼저 어시스턴트를 생성하거나 선택하세요.';

  @override
  String debugPageConversationCreated(int count) {
    return '메시지 $count개짜리 디버그 대화를 생성했습니다.';
  }

  @override
  String debugPageCreateConversationFailed(String error) {
    return '디버그 대화 생성에 실패했습니다: $error';
  }

  @override
  String debugPageOversizedConversationTitle(int sizeMB) {
    return '대용량 대화 테스트 ($sizeMB MB)';
  }

  @override
  String debugPageManyMessagesConversationTitle(int count) {
    return '메시지 $count개 대화 테스트';
  }

  @override
  String debugPageDailyMixedMarkdownConversationTitle(int count) {
    return '메시지 $count개 일별 혼합 Markdown 테스트';
  }

  @override
  String debugPageLongReasoningConversationTitle(int count) {
    return '메시지 $count개 긴 추론 테스트';
  }

  @override
  String get debugPageOversizedConversationSeedText =>
      '이 텍스트는 대용량 대화에서의 느린 렌더링을 재현하기 위한 긴 디버그 텍스트입니다. 채팅 렌더링, 저장, 스크롤 성능을 측정할 수 있도록 반복된 Markdown 형식 텍스트, 문장 부호, 한중일 문자, 일반 단어를 포함합니다.';

  @override
  String debugPageManyMessagesSeedText(String role, int index) {
    return '$role 메시지 #$index: 목록 렌더링, 스크롤 안정성, 메시지 그룹화, 대화 기록 성능을 테스트하기 위한 임의의 디버그 샘플입니다.';
  }
}
