import 'package:flutter/material.dart';

import '../../../core/providers/mcp_provider.dart';
import '../../../core/services/mcp/mcp_oauth_service.dart';
import '../../../icons/lucide_adapter.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/ios_form_text_field.dart';
import '../../../shared/widgets/ios_tile_button.dart';
import '../../../shared/widgets/segmented_tabs.dart';
import '../../../theme/app_font_weights.dart';

enum McpOAuthRegistrationMode { automatic, clientId, metadataDocument }

class McpOAuthFormController {
  McpOAuthFormController(McpServerConfig? server)
    : mode = switch (server?.oauthClient?.registrationSource) {
        McpOAuthClientRegistrationSource.preRegistered =>
          McpOAuthRegistrationMode.clientId,
        McpOAuthClientRegistrationSource.cimd =>
          McpOAuthRegistrationMode.metadataDocument,
        _ => McpOAuthRegistrationMode.automatic,
      },
      clientId = TextEditingController(
        text:
            server?.oauthClient?.registrationSource ==
                McpOAuthClientRegistrationSource.dcr
            ? ''
            : server?.oauthClient?.clientId ?? '',
      ),
      secret = TextEditingController(
        text:
            server?.oauthClient?.registrationSource ==
                McpOAuthClientRegistrationSource.dcr
            ? ''
            : server?.oauthClient?.clientSecret ?? '',
      ),
      redirect = TextEditingController(text: server?.oauthRedirectUri ?? ''),
      authMethod =
          server?.oauthClient?.registrationSource ==
              McpOAuthClientRegistrationSource.dcr
          ? 'none'
          : server?.oauthClient?.tokenEndpointAuthMethod ?? 'none';

  McpOAuthRegistrationMode mode;
  final TextEditingController clientId;
  final TextEditingController secret;
  final TextEditingController redirect;
  String authMethod;

  String? get redirectUri =>
      redirect.text.trim().isEmpty ? null : redirect.text.trim();

  String? validate(AppLocalizations l10n) {
    if (mode != McpOAuthRegistrationMode.automatic &&
        clientId.text.trim().isEmpty) {
      return l10n.mcpOAuthClientIdRequired;
    }
    if (mode == McpOAuthRegistrationMode.metadataDocument) {
      final uri = Uri.tryParse(clientId.text.trim());
      if (uri == null ||
          uri.scheme != 'https' ||
          uri.host.isEmpty ||
          uri.path.isEmpty ||
          uri.path == '/' ||
          uri.hasFragment ||
          uri.userInfo.isNotEmpty) {
        return l10n.mcpOAuthMetadataUrlInvalid;
      }
    }
    if (mode == McpOAuthRegistrationMode.clientId &&
        authMethod != 'none' &&
        secret.text.isEmpty) {
      return l10n.mcpOAuthSecretRequired;
    }
    if (redirectUri != null) {
      final uri = Uri.tryParse(redirectUri!);
      if (uri == null ||
          uri.scheme != 'http' ||
          !{'localhost', '127.0.0.1', '::1'}.contains(uri.host) ||
          uri.hasQuery ||
          uri.hasFragment ||
          uri.userInfo.isNotEmpty ||
          uri.port > 65535) {
        return l10n.mcpOAuthRedirectInvalid;
      }
    }
    return null;
  }

  McpOAuthClientRegistration? registrationFor(McpServerConfig? latest) {
    if (mode == McpOAuthRegistrationMode.automatic) {
      final current = latest?.oauthClient;
      return current?.registrationSource == McpOAuthClientRegistrationSource.dcr
          ? current
          : null;
    }
    final source = mode == McpOAuthRegistrationMode.metadataDocument
        ? McpOAuthClientRegistrationSource.cimd
        : McpOAuthClientRegistrationSource.preRegistered;
    final previous = latest?.oauthClient;
    final clientSecret =
        mode == McpOAuthRegistrationMode.clientId && authMethod != 'none'
        ? secret.text
        : null;
    final method = mode == McpOAuthRegistrationMode.metadataDocument
        ? 'none'
        : authMethod;
    // Keep the issuer and actual registered callback on a no-op edit, including
    // registration completed while this editor was open.
    if (previous?.clientId == clientId.text.trim() &&
        previous?.registrationSource == source &&
        previous?.clientSecret == clientSecret &&
        previous?.tokenEndpointAuthMethod == method &&
        latest?.oauthRedirectUri == redirectUri) {
      return previous;
    }
    return McpOAuthClientRegistration(
      clientId: clientId.text.trim(),
      clientSecret: clientSecret,
      tokenEndpointAuthMethod: method,
      registrationSource: source,
      redirectUri: redirectUri,
      authorizationServer:
          previous?.clientId == clientId.text.trim() &&
              previous?.registrationSource == source
          ? previous?.authorizationServer
          : null,
    );
  }

  void dispose() {
    clientId.dispose();
    secret.dispose();
    redirect.dispose();
  }
}

/// Shared fields embedded in the existing mobile sheet and desktop dialog.
class McpOAuthSettings extends StatefulWidget {
  const McpOAuthSettings({super.key, required this.controller});
  final McpOAuthFormController controller;

  @override
  State<McpOAuthSettings> createState() => _McpOAuthSettingsState();
}

class _McpOAuthSettingsState extends State<McpOAuthSettings> {
  static const _redirectExample = 'http://127.0.0.1:0/callback';

  late bool expanded =
      widget.controller.mode != McpOAuthRegistrationMode.automatic ||
      widget.controller.redirectUri != null;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final form = widget.controller;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        IosTileButton(
          key: const ValueKey('mcp-oauth-settings-toggle'),
          label: l10n.mcpOAuthSettings,
          icon: Lucide.KeyRound,
          onTap: () => setState(() => expanded = !expanded),
        ),
        if (expanded) ...[
          const SizedBox(height: 10),
          SegmentedTabs(
            tabs: [
              SegmentedTab(label: l10n.mcpOAuthAutomatic),
              const SegmentedTab(label: 'Client ID'),
              const SegmentedTab(label: 'CIMD'),
            ],
            index: form.mode.index,
            onChanged: (index) => setState(
              () => form.mode = McpOAuthRegistrationMode.values[index],
            ),
          ),
          if (form.mode != McpOAuthRegistrationMode.automatic) ...[
            const SizedBox(height: 10),
            IosFormTextField(
              key: const ValueKey('mcp-oauth-client-id'),
              label: form.mode == McpOAuthRegistrationMode.metadataDocument
                  ? l10n.mcpOAuthMetadataUrl
                  : 'Client ID',
              controller: form.clientId,
              inlineLabel: false,
              outerPadding: EdgeInsets.zero,
              autocorrect: false,
              enableSuggestions: false,
            ),
          ],
          if (form.mode == McpOAuthRegistrationMode.clientId) ...[
            const SizedBox(height: 10),
            Text(l10n.mcpOAuthClientAuthentication),
            const SizedBox(height: 6),
            SegmentedTabs(
              tabs: [
                SegmentedTab(label: l10n.mcpOAuthPublicClient),
                const SegmentedTab(label: 'Secret / POST'),
                const SegmentedTab(label: 'Secret / Basic'),
              ],
              index: const [
                'none',
                'client_secret_post',
                'client_secret_basic',
              ].indexOf(form.authMethod),
              onChanged: (index) => setState(
                () => form.authMethod = const [
                  'none',
                  'client_secret_post',
                  'client_secret_basic',
                ][index],
              ),
            ),
            if (form.authMethod != 'none') ...[
              const SizedBox(height: 10),
              IosFormTextField(
                key: const ValueKey('mcp-oauth-client-secret'),
                label: 'Client secret',
                controller: form.secret,
                obscureText: true,
                inlineLabel: false,
                outerPadding: EdgeInsets.zero,
                autocorrect: false,
                enableSuggestions: false,
              ),
            ],
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Text(
                  l10n.mcpOAuthRedirectUri,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: AppFontWeights.semibold,
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.85),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IosTileButton(
                key: const ValueKey('mcp-oauth-fill-redirect-example'),
                icon: Lucide.CornerDownLeft,
                label: l10n.mcpOAuthFillRedirectExample,
                fontSize: 12,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                onTap: () {
                  form.redirect.value = TextEditingValue(
                    text: _redirectExample,
                    selection: TextSelection.collapsed(
                      offset: _redirectExample.length,
                    ),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 6),
          IosFormTextField(
            key: const ValueKey('mcp-oauth-redirect'),
            label: '',
            controller: form.redirect,
            hintText: _redirectExample,
            inlineLabel: false,
            outerPadding: EdgeInsets.zero,
            autocorrect: false,
            enableSuggestions: false,
          ),
          const SizedBox(height: 6),
          Text(
            l10n.mcpOAuthRedirectHint,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ],
    );
  }
}
