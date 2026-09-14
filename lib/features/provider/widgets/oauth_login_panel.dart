import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/providers/settings_provider.dart';
import '../../../core/services/auth/provider_oauth_service.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/ios_tile_button.dart';
import '../../../shared/widgets/section_card.dart';
import '../../../theme/app_font_weights.dart';
import '../../../theme/app_semantic_colors.dart';
import 'provider_avatar.dart';

String oauthErrorText(BuildContext context, Object error) {
  final l = AppLocalizations.of(context)!;
  if (error is! ProviderOAuthException) return l.oauthNetworkError;
  final summary = switch (error.kind) {
    ProviderOAuthFailure.loginRequired => l.oauthNeedsLogin,
    ProviderOAuthFailure.timeout => l.oauthTimeout,
    ProviderOAuthFailure.denied => l.oauthDenied,
    ProviderOAuthFailure.network => l.oauthNetworkError,
    ProviderOAuthFailure.quotaExceeded => l.oauthQuotaExceeded,
    ProviderOAuthFailure.usageUnavailable => l.oauthUsageUnavailable,
    ProviderOAuthFailure.requestRejected => switch (error.statusCode) {
      429 => l.oauthRateLimited,
      403 => l.oauthPermissionDenied,
      _ => l.oauthRequestFailed,
    },
    _ => l.oauthInvalidResponse,
  };
  final status = [
    if (error.statusCode != null) 'HTTP ${error.statusCode}',
    if (error.code?.isNotEmpty == true) error.code!,
  ].join(' / ');
  return [
    '$summary${status.isEmpty ? '' : ' ($status)'}',
    if (error.message?.isNotEmpty == true) error.message!,
  ].join('\n');
}

class OAuthLoginPanel extends StatefulWidget {
  const OAuthLoginPanel({
    super.key,
    this.provider,
    this.providerId,
    this.onConnected,
    this.onViewDetails,
    this.autoStart = false,
  });
  final bool autoStart;
  final OAuthProvider? provider;
  final String? providerId;
  final ValueChanged<ProviderConfig>? onConnected;
  final ValueChanged<String>? onViewDetails;

  @override
  State<OAuthLoginPanel> createState() => _OAuthLoginPanelState();
}

class _OAuthLoginPanelState extends State<OAuthLoginPanel> {
  OAuthCancellation? _cancellation;
  OAuthProvider? _active;
  OAuthLoginPrompt? _prompt;
  ProviderConfig? _connected;
  Object? _error;

  @override
  void initState() {
    super.initState();
    if (widget.autoStart && widget.provider != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(_login(widget.provider!));
      });
    }
  }

  @override
  void dispose() {
    _cancellation?.cancel();
    super.dispose();
  }

  Future<void> _login(OAuthProvider provider, {bool? deviceCode}) async {
    if (_active != null) return;
    final cancellation = OAuthCancellation();
    setState(() {
      _active = provider;
      _error = null;
      _prompt = null;
      _cancellation = cancellation;
    });
    try {
      final connected = await ProviderOAuthService.instance.login(
        provider: provider,
        providerId: widget.providerId,
        cancellation: cancellation,
        deviceCode:
            deviceCode ??
            (Platform.isAndroid ||
                Platform.isIOS ||
                provider != OAuthProvider.chatgpt),
        onPrompt: (value) {
          if (mounted && identical(cancellation, _cancellation)) {
            setState(() => _prompt = value);
          }
        },
      );
      if (!mounted) return;
      setState(() => _connected = connected);
      widget.onConnected?.call(connected);
      unawaited(_sync(connected));
    } catch (error) {
      if (mounted && !cancellation.isCancelled) setState(() => _error = error);
    } finally {
      if (mounted && identical(cancellation, _cancellation)) {
        setState(() {
          _active = null;
          _cancellation = null;
        });
      }
    }
  }

  Future<void> _sync(ProviderConfig config) async {
    try {
      await ProviderOAuthService.instance.syncModels(config.id);
    } catch (error) {
      if (mounted) setState(() => _error = error);
    }
    try {
      await ProviderOAuthService.instance.fetchUsage(config);
    } catch (_) {
      /* Usage can be retried from the account page. */
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    if (_active case final active?) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 8),
        child: Column(
          children: [
            ProviderAvatar(
              providerKey: active.displayName,
              displayName: active.displayName,
              size: 48,
            ),
            const SizedBox(height: 20),
            Text(
              l.oauthWaiting(active.displayName),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 17,
                fontWeight: AppFontWeights.semibold,
              ),
            ),
            const SizedBox(height: 20),
            if (_prompt?.userCode case final code?) ...[
              Text(
                l.oauthCodeHint,
                style: TextStyle(
                  fontSize: 13,
                  color: cs.onSurface.withValues(alpha: .6),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                code,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: AppFontWeights.semibold,
                  letterSpacing: 3,
                ),
              ),
              const SizedBox(height: 12),
              IosTileButton(
                label: l.oauthCopyCode,
                icon: LucideIcons.copy,
                onTap: () => Clipboard.setData(ClipboardData(text: code)),
              ),
              const SizedBox(height: 12),
              if (active == OAuthProvider.chatgpt)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Text(
                    l.oauthDeviceHint,
                    style: TextStyle(
                      fontSize: 12,
                      color: cs.onSurface.withValues(alpha: .6),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
            ],
            if (_prompt != null)
              IosTileButton(
                label: l.oauthOpenBrowser,
                icon: LucideIcons.externalLink,
                onTap: () => launchUrl(
                  _prompt!.url,
                  mode: LaunchMode.externalApplication,
                ),
              ),
            const SizedBox(height: 12),
            IosTileButton(
              label: l.oauthCancel,
              icon: LucideIcons.x,
              foregroundColor: cs.error,
              onTap: () => _cancellation?.cancel(),
            ),
          ],
        ),
      );
    }
    if (_connected case final connected?) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 28),
        child: Column(
          children: [
            ProviderAvatar(
              providerKey: connected.id,
              displayName: connected.name,
              size: 48,
            ),
            const SizedBox(height: 16),
            Text(
              l.oauthConnected,
              style: TextStyle(
                fontSize: 18,
                fontWeight: AppFontWeights.semibold,
                color: context.appColors.success,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              connected.oauthCredentials?.email ?? connected.name,
              textAlign: TextAlign.center,
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  oauthErrorText(context, _error!),
                  style: TextStyle(color: cs.error),
                ),
              ),
            const SizedBox(height: 24),
            if (widget.onViewDetails != null)
              IosTileButton(
                label: l.oauthDetails,
                icon: LucideIcons.arrowRight,
                backgroundColor: cs.primary,
                onTap: () => widget.onViewDetails!(connected.id),
              ),
            if (widget.provider == null) ...[
              const SizedBox(height: 12),
              IosTileButton(
                label: l.oauthConnectAnother,
                icon: LucideIcons.plus,
                onTap: () => setState(() {
                  _connected = null;
                  _error = null;
                }),
              ),
            ],
          ],
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionCard(
          dividers: true,
          children: [
            for (final provider
                in widget.provider == null
                    ? OAuthProvider.values
                    : [widget.provider!])
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 14,
                ),
                child: Row(
                  children: [
                    ProviderAvatar(
                      providerKey: provider.displayName,
                      displayName: provider.displayName,
                      size: 34,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            provider.displayName,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: AppFontWeights.semibold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            switch (provider) {
                              OAuthProvider.chatgpt => 'Codex',
                              OAuthProvider.grok => 'xAI',
                              OAuthProvider.kimi => 'Kimi Code',
                            },
                            style: TextStyle(
                              fontSize: 12,
                              color: cs.onSurface.withValues(alpha: .6),
                            ),
                          ),
                        ],
                      ),
                    ),
                    IosTileButton(
                      label: widget.providerId == null
                          ? l.oauthLogin
                          : l.oauthRelogin,
                      icon: LucideIcons.logIn,
                      backgroundColor: cs.primary,
                      onTap: () => _login(provider),
                    ),
                  ],
                ),
              ),
          ],
        ),
        if (_error != null) ...[
          const SizedBox(height: 14),
          Text(
            oauthErrorText(context, _error!),
            style: TextStyle(color: cs.error),
            textAlign: TextAlign.center,
          ),
          if (!(Platform.isAndroid || Platform.isIOS) &&
              (widget.provider == OAuthProvider.chatgpt ||
                  widget.provider == null)) ...[
            const SizedBox(height: 12),
            IosTileButton(
              label: l.oauthDeviceLogin,
              icon: LucideIcons.keyRound,
              onTap: () => _login(OAuthProvider.chatgpt, deviceCode: true),
            ),
          ],
        ],
      ],
    );
  }
}
