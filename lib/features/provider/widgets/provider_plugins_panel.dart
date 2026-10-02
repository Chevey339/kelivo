import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../../core/models/provider_oauth.dart';
import '../../../core/models/provider_plugin.dart';
import '../../../core/providers/model_provider.dart';
import '../../../core/providers/settings_provider.dart';
import '../../../core/services/auth/oauth_cancellation.dart';
import '../../../core/services/provider_plugins/provider_plugin_service.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/ios_tile_button.dart';
import '../../../shared/widgets/section_card.dart';

/// A compact layout shared by mobile and desktop account tabs. Dialogs are
/// bounded and scrollable; no desktop bottom sheets or new native code.
class ProviderPluginsPanel extends StatefulWidget {
  const ProviderPluginsPanel({super.key});

  @override
  State<ProviderPluginsPanel> createState() => _ProviderPluginsPanelState();
}

class _ProviderPluginsPanelState extends State<ProviderPluginsPanel> {
  final _service = ProviderPluginService.instance;
  String? _busy;
  String? _error;
  OAuthCancellation? _cancellation;

  @override
  void dispose() {
    _cancellation?.cancel();
    super.dispose();
  }

  Future<void> _run(String id, Future<void> Function() action) async {
    if (_busy != null) return;
    setState(() {
      _busy = id;
      _error = null;
    });
    try {
      await action();
    } catch (error) {
      if (!mounted) return;
      if (error is ProviderOAuthException &&
          error.kind == ProviderOAuthFailure.cancelled) {
        return;
      }
      final l = AppLocalizations.of(context)!;
      setState(
        () => _error = switch (error) {
          FormatException e => '${l.providerPluginInvalid}: ${e.message}',
          ProviderOAuthException e => '${l.providerPluginOperationFailed}: $e',
          _ => l.providerPluginOperationFailed,
        },
      );
    } finally {
      if (mounted) {
        setState(() {
          _busy = null;
          _cancellation = null;
        });
      }
    }
  }

  Future<bool> _confirm(String title, Widget content, String action) async {
    if (!mounted) return false;
    final l = AppLocalizations.of(context)!;
    return await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: Text(title),
            content: SizedBox(
              width: 480,
              child: SingleChildScrollView(child: content),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: Text(l.providerPluginCancel),
              ),
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: Text(action),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _import() => _run('import', () async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['json'],
      allowMultiple: false,
      withReadStream: true,
    );
    if (result == null || !mounted) return;
    final file = result.files.single;
    if (file.size > ProviderPluginManifest.maxBytes) {
      throw const FormatException('Provider plugin exceeds 256 KiB');
    }
    final stream =
        file.readStream ??
        (file.path == null ? null : File(file.path!).openRead());
    if (stream == null) throw const FormatException('Cannot read plugin file');
    final bytes = BytesBuilder(copy: false);
    await for (final chunk in stream) {
      if (bytes.length + chunk.length > ProviderPluginManifest.maxBytes) {
        throw const FormatException('Provider plugin exceeds 256 KiB');
      }
      bytes.add(chunk);
    }
    final manifest = ProviderPluginManifest.parse(
      utf8.decode(bytes.takeBytes()),
    );
    if (!mounted) return;
    final l = AppLocalizations.of(context)!;
    final oauth = manifest.oauth;
    final accepted = await _confirm(
      l.providerPluginImport,
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l.providerPluginTrust),
          const SizedBox(height: 12),
          SelectableText(
            [
              '${manifest.name} (${manifest.id})',
              '${l.providerPluginVersion}: ${manifest.version}',
              '${l.providerPluginProtocol}: ${manifest.protocol}',
              'API: ${manifest.baseUrl}',
              if (oauth != null) ...[
                'OAuth: ${oauth.authorizationEndpoint}',
                'Token: ${oauth.tokenEndpoint}',
                'Client ID: ${oauth.clientId}',
                'Scopes: ${oauth.scopes.join(' ')}',
                if (oauth.issuer != null) 'Issuer: ${oauth.issuer}',
                if (oauth.loopbackRedirect != null)
                  'Redirect: ${oauth.loopbackRedirect}',
              ],
            ].join('\n'),
          ),
        ],
      ),
      l.providerPluginInstall,
    );
    if (accepted && mounted) await _service.install(manifest);
  });

  Future<void> _login(ProviderConfig config) => _run(config.id, () async {
    final cancellation = OAuthCancellation();
    _cancellation = cancellation;
    await _service.login(config.id, cancellation);
  });

  Future<void> _key(ProviderConfig config) => _run(config.id, () async {
    final l = AppLocalizations.of(context)!;
    final controller = TextEditingController(text: config.apiKey);
    try {
      final accepted = await _confirm(
        '${config.name} · API Key',
        TextField(
          controller: controller,
          obscureText: true,
          autocorrect: false,
          enableSuggestions: false,
          decoration: const InputDecoration(labelText: 'API Key'),
        ),
        l.providerPluginSave,
      );
      if (!accepted || !mounted) return;
      final settings = context.read<SettingsProvider>();
      final current = settings.providerConfigs[config.id];
      if (current?.providerPlugin?.fingerprint !=
          config.providerPlugin?.fingerprint) {
        return;
      }
      await settings.setProviderConfig(
        config.id,
        current!.copyWith(apiKey: controller.text.trim()),
      );
    } finally {
      controller.dispose();
    }
  });

  Future<void> _models(ProviderConfig config) => _run(config.id, () async {
    final settings = context.read<SettingsProvider>();
    final models = await ProviderManager.listModels(config);
    final current = settings.providerConfigs[config.id];
    if (current == null ||
        current.providerPlugin?.fingerprint !=
            config.providerPlugin?.fingerprint ||
        current.providerPluginSession?.credentials.sessionId !=
            config.providerPluginSession?.credentials.sessionId) {
      return;
    }
    await settings.setProviderConfig(
      current.id,
      current.copyWith(models: models.map((model) => model.id).toList()),
    );
  });

  Future<void> _remove(ProviderConfig config) => _run(config.id, () async {
    final l = AppLocalizations.of(context)!;
    if (await _confirm(
          l.providerPluginRemove,
          Text(config.name),
          l.providerPluginRemove,
        ) &&
        mounted) {
      await _service.uninstall(config.id);
    }
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final settings = context.watch<SettingsProvider>();
    final configs = settings.providerConfigs.values
        .where((config) => config.providerPlugin != null)
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 16),
        Text(
          l.providerPluginTitle,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        if (_busy == null)
          IosTileButton(
            label: l.providerPluginImport,
            icon: LucideIcons.plus,
            onTap: _import,
          ),
        if (_busy != null) ...[
          const LinearProgressIndicator(),
          if (_cancellation != null)
            TextButton(
              onPressed: () => _cancellation?.cancel(),
              child: Text(l.providerPluginCancel),
            ),
        ],
        if (_error != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        for (final config in configs) ...[
          const SizedBox(height: 8),
          SectionCard(
            padding: const EdgeInsets.all(12),
            children: [
              Text(config.name, style: Theme.of(context).textTheme.titleSmall),
              SelectableText(config.providerPlugin!.baseUrl.toString()),
              if (config.isPluginOAuth)
                Text(
                  config.providerPluginSession == null ||
                          config
                              .providerPluginSession!
                              .credentials
                              .requiresLogin
                      ? l.providerPluginSignedOut
                      : l.providerPluginSignedIn,
                ),
              if (_busy == null)
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    if (config.isPluginOAuth) ...[
                      TextButton(
                        onPressed: () => _login(config),
                        child: Text(l.oauthLogin),
                      ),
                      if (config.providerPluginSession != null)
                        TextButton(
                          onPressed: () =>
                              _run(config.id, () => _service.logout(config.id)),
                          child: Text(l.providerPluginLogout),
                        ),
                    ] else
                      TextButton(
                        onPressed: () => _key(config),
                        child: const Text('API Key'),
                      ),
                    TextButton(
                      onPressed: () => _models(config),
                      child: Text(l.providerPluginModels),
                    ),
                    TextButton(
                      onPressed: () => _run(
                        config.id,
                        () => Clipboard.setData(
                          ClipboardData(
                            text: const JsonEncoder.withIndent(
                              '  ',
                            ).convert(config.providerPlugin!.toJson()),
                          ),
                        ),
                      ),
                      child: Text(l.providerPluginCopy),
                    ),
                    TextButton(
                      onPressed: () => _remove(config),
                      child: Text(l.providerPluginRemove),
                    ),
                  ],
                ),
            ],
          ),
        ],
      ],
    );
  }
}
