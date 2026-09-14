import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../core/providers/settings_provider.dart';
import '../../../core/services/auth/provider_oauth_service.dart';
import '../../../desktop/model_edit_dialog.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/responsive/screen_type_helper.dart';
import '../../../shared/widgets/ios_form_text_field.dart';
import '../../../shared/widgets/ios_settings_rows.dart';
import '../../../shared/widgets/ios_switch.dart';
import '../../../shared/widgets/ios_tactile.dart';
import '../../../shared/widgets/ios_tile_button.dart';
import '../../../shared/widgets/section_card.dart';
import '../../../theme/app_font_weights.dart';
import '../../model/widgets/model_detail_sheet.dart';
import '../widgets/oauth_account_card.dart';
import '../widgets/oauth_login_panel.dart';
import '../widgets/provider_avatar.dart';
import '../widgets/provider_custom_request_editor.dart';

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
  });
  final String providerId;
  final bool embedded;
  final bool startLogin;
  final ProviderOAuthService? service;

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
  bool _network = false;
  bool _custom = false;
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

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final config = settings.providerConfigs[widget.providerId];
    if (config == null || !config.isOAuth) return const SizedBox.shrink();
    final l = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    final credentials = config.oauthCredentials;
    final needsLogin = credentials == null || credentials.requiresLogin;
    final body = ListenableBuilder(
      listenable: _service,
      builder: (context, _) => ListView(
        padding: EdgeInsets.fromLTRB(
          widget.embedded ? 20 : 16,
          12,
          widget.embedded ? 20 : 16,
          28 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        children: [
          if (_login || credentials == null)
            OAuthLoginPanel(
              autoStart: _login,
              provider: config.oauthProvider,
              providerId: config.id,
              onConnected: (_) {
                setState(() => _login = false);
                unawaited(_refreshUsage());
              },
            )
          else
            OAuthAccountCard(
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
              expired: needsLogin,
              loadingUsage: _loadingUsage,
              usageError: _usageError == null
                  ? null
                  : oauthErrorText(context, _usageError!),
              showDetails: _usageDetails,
              onDetails: () => setState(() => _usageDetails = !_usageDetails),
              onRefresh: _refreshUsage,
              onLogin: () => setState(() => _login = true),
            ),
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
                        settings.providerConfigs[config.id]!.copyWith(
                          name: value.trim(),
                        ),
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
          const SizedBox(height: 22),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '${l.providerDetailPageModelsTab}  ${config.models.length}',
                    style: TextStyle(
                      fontSize: 13,
                      color: cs.onSurface.withValues(alpha: .6),
                    ),
                  ),
                ),
                IosTileButton(
                  label: _syncing ? l.oauthSyncing : l.oauthSyncModels,
                  icon: LucideIcons.refreshCw,
                  enabled: !_syncing && !needsLogin,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  onTap: _syncModels,
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          if (_modelError != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text(
                oauthErrorText(context, _modelError!),
                style: TextStyle(fontSize: 13, color: cs.error),
              ),
            ),
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
                )
              else
                for (final model in config.models)
                  IosNavRow(
                    label:
                        (config.modelOverrides[model] as Map?)?['name']
                            as String? ??
                        model,
                    subtitle: model,
                    onTap: () {
                      if (ResponsiveHelper.isDesktop(context) ||
                          widget.embedded) {
                        showDesktopModelEditDialog(
                          context,
                          providerKey: config.id,
                          modelId: model,
                        );
                      } else {
                        showModelDetailSheet(
                          context,
                          providerKey: config.id,
                          modelId: model,
                        );
                      }
                    },
                  ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 9, 4, 0),
            child: Text(
              '${l.oauthModelsHint}${config.oauthModelsSyncedAt == null ? '' : '\n${l.oauthLastUpdated(oauthDisplayTime(context, config.oauthModelsSyncedAt!))}'}',
              style: TextStyle(
                fontSize: 12,
                height: 1.5,
                color: cs.onSurface.withValues(alpha: .5),
              ),
            ),
          ),
          const SizedBox(height: 22),
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 10),
            child: Text(
              l.oauthConnection,
              style: TextStyle(
                fontSize: 13,
                color: cs.onSurface.withValues(alpha: .6),
              ),
            ),
          ),
          SectionCard(
            children: [
              IosNavRow(
                icon: LucideIcons.info,
                label: l.oauthConnectionInfo,
                onTap: () => setState(() => _connection = !_connection),
                trailing: Icon(
                  _connection ? LucideIcons.chevronUp : LucideIcons.chevronDown,
                  size: 16,
                  color: cs.onSurface.withValues(alpha: .4),
                ),
              ),
              if (_connection) ...[
                _copyRow(l.oauthEndpoint, config.oauthProvider!.baseUrl),
                if (config.oauthProvider!.scope.isNotEmpty)
                  _copyRow(l.oauthScope, config.oauthProvider!.scope),
                if (credentials?.accountId case final id?)
                  _copyRow(l.oauthAccountId, id),
                if (credentials != null)
                  _copyRow(
                    l.oauthTokenExpiry,
                    oauthDisplayTime(context, credentials.expiresAt),
                  ),
              ],
              IosNavRow(
                icon: LucideIcons.network,
                label: l.oauthNetwork,
                subtitle: config.proxyEnabled == true
                    ? config.proxyHost
                    : l.oauthFollowGlobal,
                onTap: () => setState(() => _network = !_network),
              ),
              if (_network)
                _OAuthNetworkEditor(key: ValueKey(config.id), config: config),
              IosNavRow(
                icon: LucideIcons.slidersHorizontal,
                label: l.oauthCustomRequest,
                detailText:
                    '${config.customHeaders.length + config.customBody.length}',
                onTap: () => setState(() => _custom = !_custom),
              ),
              if (_custom)
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: ProviderCustomRequestEditor(
                    showHeader: false,
                    headers: config.customHeaders,
                    body: config.customBody,
                    onHeadersChanged: (rows) => settings.setProviderConfig(
                      config.id,
                      settings.providerConfigs[config.id]!.copyWith(
                        customHeaders: rows,
                      ),
                    ),
                    onBodyChanged: (rows) => settings.setProviderConfig(
                      config.id,
                      settings.providerConfigs[config.id]!.copyWith(
                        customBody: rows,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          if (credentials != null) ...[
            const SizedBox(height: 24),
            SectionCard(
              children: [
                IosNavRow(
                  icon: LucideIcons.logOut,
                  label: l.oauthLogout,
                  subtitle: l.oauthLogoutDescription,
                  subtitleMaxLines: null,
                  destructive: true,
                  onTap: () async {
                    await _service.logout(config.id);
                    if (mounted) setState(() => _login = false);
                  },
                ),
              ],
            ),
          ],
        ],
      ),
    );
    final header = Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 16, 4),
      child: Row(
        children: [
          if (!widget.embedded)
            IosIconButton(
              icon: LucideIcons.chevronLeft,
              minSize: 44,
              onTap: () => Navigator.of(context).pop(),
            ),
          if (widget.embedded) const SizedBox(width: 12),
          Expanded(
            child: Text(
              config.name,
              style: TextStyle(
                fontSize: 18,
                fontWeight: AppFontWeights.semibold,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          IosIconButton(
            icon: LucideIcons.pencil,
            semanticLabel: l.oauthName,
            onTap: () => setState(() => _editingName = !_editingName),
          ),
        ],
      ),
    );
    return Material(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: widget.embedded
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                header,
                Expanded(child: body),
              ],
            )
          : SafeArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  header,
                  Expanded(child: body),
                ],
              ),
            ),
    );
  }

  Widget _copyRow(String label, String value) => IosNavRow(
    label: label,
    subtitle: value,
    subtitleMaxLines: null,
    trailing: const Icon(LucideIcons.copy, size: 14),
    onTap: () => Clipboard.setData(ClipboardData(text: value)),
  );
}

class _OAuthNetworkEditor extends StatefulWidget {
  const _OAuthNetworkEditor({super.key, required this.config});
  final ProviderConfig config;
  @override
  State<_OAuthNetworkEditor> createState() => _OAuthNetworkEditorState();
}

class _OAuthNetworkEditorState extends State<_OAuthNetworkEditor> {
  late final _host = TextEditingController(text: widget.config.proxyHost);
  late final _port = TextEditingController(
    text: widget.config.proxyPort ?? '8080',
  );
  late final _username = TextEditingController(
    text: widget.config.proxyUsername,
  );
  late final _password = TextEditingController(
    text: widget.config.proxyPassword,
  );
  @override
  void dispose() {
    for (final controller in [_host, _port, _username, _password]) {
      controller.dispose();
    }
    super.dispose();
  }

  void _save({bool? enabled, String? type}) {
    final settings = context.read<SettingsProvider>();
    final config = settings.providerConfigs[widget.config.id];
    if (config == null) return;
    unawaited(
      settings.setProviderConfig(
        config.id,
        config.copyWith(
          proxyEnabled: enabled,
          proxyType: type,
          proxyHost: _host.text.trim(),
          proxyPort: _port.text.trim(),
          proxyUsername: _username.text,
          proxyPassword: _password.text,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final config = widget.config;
    return Column(
      children: [
        IosNavRow(
          label: l.providerDetailPageEnableProxyTitle,
          trailing: IosSwitch(
            value: config.proxyEnabled == true,
            onChanged: (value) => _save(enabled: value),
          ),
        ),
        if (config.proxyEnabled == true) ...[
          IosNavRow(
            label: l.networkProxyType,
            detailText: ProviderConfig.resolveProxyType(
              config.proxyType,
            ).toUpperCase(),
            onTap: () =>
                _save(type: config.proxyType == 'socks5' ? 'http' : 'socks5'),
          ),
          IosFormTextField(
            label: l.networkProxyServerHost,
            controller: _host,
            onChanged: (_) => _save(),
          ),
          IosFormTextField(
            label: l.networkProxyPort,
            controller: _port,
            keyboardType: TextInputType.number,
            onChanged: (_) => _save(),
          ),
          IosFormTextField(
            label: l.networkProxyUsername,
            controller: _username,
            onChanged: (_) => _save(),
          ),
          IosFormTextField(
            label: l.networkProxyPassword,
            controller: _password,
            onChanged: (_) => _save(),
          ),
        ],
      ],
    );
  }
}
