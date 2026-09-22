import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/widget_previews.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/ios_settings_rows.dart';
import '../../../shared/widgets/section_card.dart';
import '../../../shared/widgets/snackbar.dart';
import '../../../theme/theme_factory.dart';
import '../../home/services/local_tools_service.dart';

class PhoneControlSettingsPage extends StatefulWidget {
  const PhoneControlSettingsPage({super.key, this.requestEnable = false});

  final bool requestEnable;

  static Future<bool?> open(
    BuildContext context, {
    bool requestEnable = false,
  }) {
    return Navigator.of(context, rootNavigator: true).push<bool>(
      MaterialPageRoute(
        builder: (_) => PhoneControlSettingsPage(requestEnable: requestEnable),
      ),
    );
  }

  @override
  State<PhoneControlSettingsPage> createState() =>
      _PhoneControlSettingsPageState();
}

class _PhoneControlSettingsPageState extends State<PhoneControlSettingsPage>
    with WidgetsBindingObserver {
  PhoneControlStatus? _status;
  bool _loading = true;
  int _request = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_refresh());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(_refresh());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _refresh() async {
    final request = ++_request;
    final status = await DeviceLocalTools.phoneControlStatus();
    if (!mounted || request != _request) return;
    setState(() {
      _status = status;
      _loading = false;
    });
  }

  Future<void> _openSettings() async {
    final opened = await DeviceLocalTools.openAccessibilitySettings();
    if (!opened && mounted) {
      showAppSnackBar(
        context,
        message: AppLocalizations.of(context)!.phoneControlSettingsUnavailable,
        type: NotificationType.warning,
      );
    }
  }

  @override
  Widget build(BuildContext context) => PhoneControlSettingsView(
    status: _status,
    loading: _loading,
    onRefresh: () => unawaited(_refresh()),
    onOpenSettings: () => unawaited(_openSettings()),
    onOpenAppSettings: () => unawaited(DeviceLocalTools.openAppSettings()),
    onEnable: widget.requestEnable && DeviceLocalTools.phoneControlSupported
        ? () => Navigator.of(context).pop(true)
        : null,
  );
}

/// The same small form fits phones and wide Android windows without a separate layout.
class PhoneControlSettingsView extends StatelessWidget {
  const PhoneControlSettingsView({
    super.key,
    required this.status,
    required this.loading,
    required this.onRefresh,
    required this.onOpenSettings,
    required this.onOpenAppSettings,
    this.onEnable,
    this.haptics = true,
  });

  final PhoneControlStatus? status;
  final bool loading;
  final VoidCallback onRefresh;
  final VoidCallback onOpenSettings;
  final VoidCallback onOpenAppSettings;
  final VoidCallback? onEnable;
  final bool haptics;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    final statusText = loading
        ? l10n.phoneControlChecking
        : status == null
        ? l10n.phoneControlStatusUnavailable
        : status!.connected
        ? l10n.phoneControlReady
        : status!.enabled
        ? l10n.phoneControlDisconnected
        : l10n.phoneControlDisabled;
    Widget info(String title, String text) => SectionCard(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              Text(
                text,
                style: TextStyle(color: cs.onSurfaceVariant, height: 1.5),
              ),
            ],
          ),
        ),
      ],
    );
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.phoneControlTitle),
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft),
          tooltip: l10n.settingsPageBackButton,
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.refreshCw),
            tooltip: l10n.phoneControlRefresh,
            onPressed: onRefresh,
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                SectionCard(
                  children: [
                    IosNavRow(
                      icon: LucideIcons.accessibility,
                      label: l10n.phoneControlAccessibilityService,
                      subtitle: statusText,
                      subtitleMaxLines: null,
                      trailing: Icon(
                        status?.connected == true
                            ? LucideIcons.circleCheck
                            : LucideIcons.circle,
                        color: status?.connected == true
                            ? cs.primary
                            : cs.onSurfaceVariant,
                      ),
                    ),
                    IosNavRow(
                      icon: LucideIcons.settings,
                      haptics: haptics,
                      label: l10n.phoneControlOpenSettings,
                      onTap: onOpenSettings,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                info(l10n.phoneControlUsageTitle, l10n.phoneControlDisclosure),
                const SizedBox(height: 16),
                info(
                  l10n.phoneControlAssistantTitle,
                  l10n.phoneControlAssistantHint,
                ),
                if (status?.enabled != true && !loading) ...[
                  const SizedBox(height: 16),
                  SectionCard(
                    children: [
                      IosNavRow(
                        icon: LucideIcons.info,
                        haptics: haptics,
                        label: l10n.phoneControlRestrictedTitle,
                        subtitle: l10n.phoneControlRestrictedHint,
                        subtitleMaxLines: null,
                        onTap: onOpenAppSettings,
                      ),
                    ],
                  ),
                ],
                if (onEnable != null) ...[
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: onEnable,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Text(
                        l10n.phoneControlEnableAssistant,
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

void phoneControlPreviewAction() {}

@Preview(
  name: 'Phone control · Light',
  group: 'Phone control',
  size: Size(390, 844),
  brightness: Brightness.light,
)
@Preview(
  name: 'Phone control · Dark',
  group: 'Phone control',
  size: Size(390, 844),
  brightness: Brightness.dark,
)
Widget phoneControlSettingsPreview() => MaterialApp(
  debugShowCheckedModeBanner: false,
  locale: const Locale('zh'),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  theme: buildLightTheme(null),
  darkTheme: buildDarkTheme(null),
  home: const PhoneControlSettingsView(
    haptics: false,
    status: PhoneControlStatus(enabled: false, connected: false),
    loading: false,
    onRefresh: phoneControlPreviewAction,
    onOpenSettings: phoneControlPreviewAction,
    onOpenAppSettings: phoneControlPreviewAction,
    onEnable: phoneControlPreviewAction,
  ),
);
