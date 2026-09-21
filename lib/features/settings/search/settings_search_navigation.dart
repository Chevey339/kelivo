import 'package:flutter/material.dart';

import '../../assistant/pages/assistant_settings_page.dart';
import '../../backup/pages/backup_page.dart';
import '../../instruction_injection/pages/instruction_injection_page.dart';
import '../../mcp/pages/mcp_page.dart';
import '../../model/pages/default_model_page.dart';
import '../../provider/pages/providers_page.dart';
import '../../quick_phrase/pages/quick_phrases_page.dart';
import '../../scheduled_tasks/pages/scheduled_tasks_page.dart';
import '../../search/pages/search_services_page.dart';
import '../../stats/pages/stats_page.dart';
import '../../workspace/pages/skills_page.dart';
import '../../workspace/pages/workspace_settings_page.dart';
import '../../world_book/pages/world_book_page.dart';
import '../pages/about_page.dart';
import '../pages/auto_retry_page.dart';
import '../pages/display_settings_page.dart';
import '../pages/image_settings_page.dart';
import '../pages/log_viewer_page.dart';
import '../pages/memory_settings_page.dart';
import '../pages/message_style_settings_page.dart';
import '../pages/mobile_background_settings_page.dart';
import '../pages/network_proxy_page.dart';
import '../pages/sponsor_page.dart';
import '../pages/storage_space_page.dart';
import '../pages/theme_advanced_settings_page.dart';
import '../pages/theme_settings_page.dart';
import '../pages/tool_schema_settings_page.dart';
import '../pages/tts_services_page.dart';
import '../widgets/settings_search_target.dart';
import 'settings_search_index.dart';

Future<void> openMobileSettingsSearchResult(
  BuildContext context,
  SettingsSearchItem item,
) async {
  final Widget page = switch (item.destination) {
    SettingsSearchDestination.display => const DisplaySettingsPage(),
    SettingsSearchDestination.theme => const ThemeSettingsPage(),
    SettingsSearchDestination.themeAdvanced =>
      const ThemeAdvancedSettingsPage(),
    SettingsSearchDestination.chatDisplay =>
      const ChatItemDisplaySettingsPage(),
    SettingsSearchDestination.rendering => const RenderingSettingsPage(),
    SettingsSearchDestination.behavior => const BehaviorStartupSettingsPage(),
    SettingsSearchDestination.image => const ImageSettingsPage(),
    SettingsSearchDestination.messageStyle => const MessageStyleSettingsPage(),
    SettingsSearchDestination.autoRetry => const AutoRetryPage(),
    SettingsSearchDestination.haptics => const HapticsSettingsPage(),
    SettingsSearchDestination.background =>
      const MobileBackgroundSettingsPage(),
    SettingsSearchDestination.assistant => const AssistantSettingsPage(),
    SettingsSearchDestination.providers => const ProvidersPage(),
    SettingsSearchDestination.defaultModel => const DefaultModelPage(),
    SettingsSearchDestination.search => const SearchServicesPage(),
    SettingsSearchDestination.tts => const TtsServicesPage(),
    SettingsSearchDestination.mcp => const McpPage(),
    SettingsSearchDestination.workspace => const WorkspaceSettingsPage(),
    SettingsSearchDestination.skills => const SkillsPage(),
    SettingsSearchDestination.quickPhrases => const QuickPhrasesPage(),
    SettingsSearchDestination.instructionInjection =>
      const InstructionInjectionPage(),
    SettingsSearchDestination.worldBook => const WorldBookPage(),
    SettingsSearchDestination.memory => const MemorySettingsPage(),
    SettingsSearchDestination.networkProxy => const NetworkProxyPage(),
    SettingsSearchDestination.backup => const BackupPage(),
    SettingsSearchDestination.storage => const StorageSpacePage(),
    SettingsSearchDestination.scheduledTasks => const ScheduledTasksPage(),
    SettingsSearchDestination.stats => const StatsPage(),
    SettingsSearchDestination.toolSchemas => const ToolSchemaSettingsPage(),
    SettingsSearchDestination.logs => const LogViewerPage(),
    SettingsSearchDestination.about => const AboutPage(),
    SettingsSearchDestination.sponsor => const SponsorPage(),
    SettingsSearchDestination.colorMode || SettingsSearchDestination.hotkeys =>
      throw StateError('This destination is handled by its settings host.'),
  };
  await Navigator.of(context).push<void>(
    MaterialPageRoute(
      builder: (_) =>
          SettingsSearchTarget(label: item.targetLabel, child: page),
    ),
  );
}
