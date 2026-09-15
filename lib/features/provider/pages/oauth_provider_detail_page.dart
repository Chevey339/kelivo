import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/providers/settings_provider.dart';
import '../../../core/services/auth/provider_oauth_service.dart';
import '../../../desktop/desktop_settings_page.dart'
    show DesktopProviderDetailPane;
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/responsive/screen_type_helper.dart';
import '../../../shared/widgets/ios_form_text_field.dart';
import '../../../shared/widgets/ios_settings_rows.dart';
import '../../../shared/widgets/ios_switch.dart';
import '../../../shared/widgets/ios_tactile.dart';
import '../../../shared/widgets/section_card.dart';
import '../../../theme/app_font_weights.dart';
import '../../model/widgets/model_detail_sheet.dart';
import '../widgets/oauth_account_card.dart';
import '../widgets/oauth_login_panel.dart';
import '../widgets/provider_avatar.dart';
import '../widgets/oauth_connection_info.dart';
import '../widgets/provider_prompt_cache_settings.dart';
import 'provider_network_page.dart';
import 'provider_custom_request_page.dart';

Future<void> showOAuthProviderDetails(
  BuildContext context,
  String providerId, {
  bool startLogin = false,
}) async {
  if (ResponsiveHelper.isDesktop(context)) {
    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'oauth-account',
      barrierColor: Theme.of(context).colorScheme.scrim.withValues(alpha: .25),
      pageBuilder: (context, _, __) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 780, maxHeight: 850),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: OAuthProviderDetailPage(
                providerId: providerId,
                startLogin: startLogin,
              ),
            ),
          ),
        ),
      ),
    );
  } else {
    await Navigator.of(context).push<void>(
      PageRouteBuilder(
        pageBuilder: (_, animation, __) => OAuthProviderDetailPage(
          providerId: providerId,
          startLogin: startLogin,
        ),
        transitionsBuilder: (_, animation, __, child) => SlideTransition(
          position: animation.drive(
            Tween(
              begin: const Offset(1, 0),
              end: Offset.zero,
            ).chain(CurveTween(curve: Curves.easeOutCubic)),
          ),
          child: child,
        ),
      ),
    );
  }
}

class OAuthProviderDetailPage extends StatefulWidget {
  const OAuthProviderDetailPage({
    super.key,
    required this.providerId,
    this.embedded = false,
    this.startLogin = false,
    this.service,
    this.desktopPaneKey,
  });
  final String providerId;
  final bool embedded;
  final bool startLogin;
  final ProviderOAuthService? service;
  final Key? desktopPaneKey;

  @override
  State<OAuthProviderDetailPage> createState() =>
      _OAuthProviderDetailPageState();
}

class _OAuthProviderDetailPageState extends State<OAuthProviderDetailPage> {
  late final _service = widget.service ?? ProviderOAuthService.instance;
  late bool _login = widget.startLogin;
  bool _editingName = false;
  late final TextEditingController _name;
  bool _usageDetails = false;
  bool _loadingUsage = false;
  bool _syncing = false;
  bool _connection = false;
  Object? _usageError;
  Object? _modelError;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(
      text: context
          .read<SettingsProvider>()
          .providerConfigs[widget.providerId]
          ?.name,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_refreshUsage());
    });
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _refreshUsage() async {
    final config = context
        .read<SettingsProvider>()
        .providerConfigs[widget.providerId];
    if (config?.oauthCredentials == null ||
        config!.oauthCredentials!.requiresLogin ||
        _loadingUsage) {
      return;
    }
    setState(() {
      _loadingUsage = true;
      _usageError = null;
    });
    try {
      await _service.fetchUsage(config);
    } catch (error) {
      if (mounted) setState(() => _usageError = error);
    } finally {
      if (mounted) setState(() => _loadingUsage = false);
    }
  }

  Future<void> _syncModels() async {
    if (_syncing) return;
    setState(() {
      _syncing = true;
      _modelError = null;
    });
    try {
      await _service.syncModels(widget.providerId);
    } catch (error) {
      if (mounted) setState(() => _modelError = error);
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }

  Widget _account(ProviderConfig config) {
    final credentials = config.oauthCredentials;
    if (_login || credentials == null) {
      return OAuthLoginPanel(
        autoStart: _login,
        provider: config.oauthProvider,
        providerId: config.id,
        service: _service,
        onConnected: (_) {
          setState(() => _login = false);
          unawaited(_refreshUsage());
        },
      );
    }
    return OAuthAccountCard(
      avatar: ProviderAvatar(
        providerKey: config.id,
        displayName: config.name,
        size: 42,
      ),
      name: config.name,
      email: credentials.email,
      plan: credentials.plan,
      usage: _service.cachedUsage(config),
      refreshing: _service.isRefreshing(config.id),
      expired: credentials.requiresLogin,
      loadingUsage: _loadingUsage,
      usageError: _usageError == null
          ? null
          : oauthErrorText(context, _usageError!),
      showDetails: _usageDetails,
      onDetails: () => setState(() => _usageDetails = !_usageDetails),
      onRefresh: _refreshUsage,
      onLogin: () => setState(() => _login = true),
    );
  }

  Widget _modelStatus(ProviderConfig config) {
    final l = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 9),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_modelError != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                oauthErrorText(context, _modelError!),
                style: TextStyle(fontSize: 13, color: cs.error),
              ),
            ),
          Text(
            '${l.oauthModelsHint}${config.oauthModelsSyncedAt == null ? '' : '\n${l.oauthLastUpdated(oauthDisplayTime(context, config.oauthModelsSyncedAt!))}'}',
            style: TextStyle(
              fontSize: 12,
              height: 1.5,
              color: cs.onSurface.withValues(alpha: .5),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _logout(String id) async {
    await _service.logout(id);
    if (mounted) setState(() => _login = false);
  }

  void _openPage(Widget page) {
    Navigator.of(context).push<void>(
      PageRouteBuilder(
        pageBuilder: (_, _, _) => page,
        transitionsBuilder: (_, animation, _, child) => SlideTransition(
          position: animation.drive(
            Tween(
              begin: const Offset(1, 0),
              end: Offset.zero,
            ).chain(CurveTween(curve: Curves.easeOutCubic)),
          ),
          child: child,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final config = settings.providerConfigs[widget.providerId];
    if (config == null || !config.isOAuth) return const SizedBox.shrink();
    final l = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    final desktop = widget.embedded || ResponsiveHelper.isDesktop(context);
    final needsLogin =
        config.oauthCredentials == null ||
        config.oauthCredentials!.requiresLogin;
    return ListenableBuilder(
      listenable: _service,
      builder: (context, _) {
        if (desktop) {
          return Material(
            color: Theme.of(context).scaffoldBackgroundColor,
            child: DesktopProviderDetailPane(
              key: widget.desktopPaneKey ?? ValueKey(config.id),
              providerKey: config.id,
              displayName: config.name,
              oauthAccount: Column(
                children: [
                  _account(config),
                  if (config.oauthProvider == OAuthProvider.claude) ...[
                    const SizedBox(height: 18),
                    ProviderPromptCacheSettings(config: config, desktop: true),
                  ],
                ],
              ),
              syncingModels: _syncing,
              onSyncModels: needsLogin ? null : _syncModels,
              onClose: widget.embedded
                  ? null
                  : () => Navigator.of(context).maybePop(),
              oauthFooter: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _modelStatus(config),
                  if (config.oauthCredentials != null) ...[
                    const SizedBox(height: 20),
                    IosIconButton(
                      semanticLabel: l.oauthLogout,
                      color: cs.error,
                      minSize: 32,
                      builder: (color) => Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(LucideIcons.logOut, size: 16, color: color),
                          const SizedBox(width: 8),
                          Text(
                            l.oauthLogout,
                            style: TextStyle(fontSize: 13, color: color),
                          ),
                        ],
                      ),
                      onTap: () => _logout(config.id),
                    ),
                  ],
                ],
              ),
            ),
          );
        }
        return Material(
          color: Theme.of(context).scaffoldBackgroundColor,
          child: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  height: 56,
                  child: Row(
                    children: [
                      IosIconButton(
                        icon: LucideIcons.arrowLeft,
                        size: 22,
                        minSize: 56,
                        semanticLabel: l.settingsPageBackButton,
                        tooltip: l.settingsPageBackButton,
                        onTap: () => Navigator.of(context).maybePop(),
                      ),
                      ProviderAvatar(
                        providerKey: config.id,
                        displayName: config.name,
                        size: 24,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          config.name,
                          style: const TextStyle(fontSize: 16),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      IosIconButton(
                        icon: LucideIcons.pencil,
                        size: 22,
                        minSize: 48,
                        semanticLabel: l.oauthName,
                        onTap: () =>
                            setState(() => _editingName = !_editingName),
                      ),
                      const SizedBox(width: 4),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView(
                    padding: EdgeInsets.fromLTRB(
                      16,
                      12,
                      16,
                      28 + MediaQuery.viewInsetsOf(context).bottom,
                    ),
                    children: [
                      _account(config),
                      if (config.oauthProvider == OAuthProvider.claude) ...[
                        const SizedBox(height: 18),
                        ProviderPromptCacheSettings(config: config),
                      ],
                      const SizedBox(height: 20),
                      SectionCard(
                        children: [
                          if (_editingName)
                            IosFormTextField(
                              label: l.oauthName,
                              controller: _name,
                              onChanged: (value) {
                                if (value.trim().isNotEmpty) {
                                  settings.setProviderConfig(
                                    config.id,
                                    settings.providerConfigs[config.id]!
                                        .copyWith(name: value.trim()),
                                  );
                                }
                              },
                            ),
                          IosNavRow(
                            label: l.addProviderSheetEnabledLabel,
                            subtitle: l.oauthEnabledHint,
                            trailing: IosSwitch(
                              value: config.enabled,
                              onChanged: (value) => settings.setProviderConfig(
                                config.id,
                                settings.providerConfigs[config.id]!.copyWith(
                                  enabled: value,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      Row(
                        children: [
                          Text(
                            l.providerDetailPageModelsTitle,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: AppFontWeights.emphasis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${config.models.length}',
                            style: TextStyle(
                              fontSize: 12,
                              color: cs.onSurface.withValues(alpha: .55),
                            ),
                          ),
                          const Spacer(),
                          IosIconButton(
                            key: const ValueKey('oauth-sync-models'),
                            icon: _syncing
                                ? LucideIcons.loader
                                : LucideIcons.refreshCw,
                            size: 20,
                            minSize: 44,
                            tooltip: _syncing
                                ? l.oauthSyncing
                                : l.oauthSyncModels,
                            semanticLabel: _syncing
                                ? l.oauthSyncing
                                : l.oauthSyncModels,
                            enabled: !_syncing && !needsLogin,
                            onTap: _syncModels,
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      SectionCard(
                        children: [
                          if (config.models.isEmpty)
                            Padding(
                              padding: const EdgeInsets.all(20),
                              child: Text(
                                l.oauthNoModels,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: cs.onSurface.withValues(alpha: .5),
                                ),
                              ),
                            ),
                          for (final model in config.models)
                            IosNavRow(
                              label:
                                  (config.modelOverrides[model]
                                          as Map?)?['name']
                                      as String? ??
                                  model,
                              subtitle:
                                  (config.modelOverrides[model]
                                          as Map?)?['name'] ==
                                      null
                                  ? null
                                  : model,
                              onTap: () => showModelDetailSheet(
                                context,
                                providerKey: config.id,
                                modelId: model,
                              ),
                            ),
                        ],
                      ),
                      _modelStatus(config),
                      const SizedBox(height: 22),
                      SectionCard(
                        children: [
                          IosNavRow(
                            label: l.oauthConnectionInfo,
                            onTap: () =>
                                setState(() => _connection = !_connection),
                            trailing: Icon(
                              _connection
                                  ? LucideIcons.chevronUp
                                  : LucideIcons.chevronDown,
                              size: 16,
                              color: cs.onSurface.withValues(alpha: .9),
                            ),
                          ),
                          if (_connection) OAuthConnectionInfo(config: config),
                          IosNavRow(
                            label: l.providerDetailPageNetworkTab,
                            onTap: () => _openPage(
                              ProviderNetworkPage(
                                providerKey: config.id,
                                providerDisplayName: config.name,
                              ),
                            ),
                          ),
                          IosNavRow(
                            label: l.providerDetailPageCustomRequestTitle,
                            onTap: () => _openPage(
                              ProviderCustomRequestPage(
                                providerKey: config.id,
                                providerDisplayName: config.name,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (config.oauthCredentials != null) ...[
                        const SizedBox(height: 24),
                        SectionCard(
                          children: [
                            IosNavRow(
                              icon: LucideIcons.logOut,
                              label: l.oauthLogout,
                              subtitle: l.oauthLogoutDescription,
                              subtitleMaxLines: null,
                              destructive: true,
                              onTap: () => _logout(config.id),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
