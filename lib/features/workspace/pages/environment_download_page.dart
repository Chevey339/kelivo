import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:Kelivo/core/providers/environment_provider.dart';
import 'package:Kelivo/core/services/sandbox/environment_installer.dart';
import 'package:Kelivo/core/services/sandbox/mirror_speed_test.dart';
import 'package:Kelivo/core/services/sandbox/rootfs_source.dart';
import 'package:Kelivo/features/workspace/widgets/environment/environment_chrome.dart';
import 'package:Kelivo/icons/lucide_adapter.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:Kelivo/shared/widgets/ios_form_text_field.dart';
import 'package:Kelivo/shared/widgets/ios_settings_rows.dart';
import 'package:Kelivo/shared/widgets/ios_tactile.dart';
import 'package:Kelivo/shared/widgets/ios_tile_button.dart';
import 'package:Kelivo/shared/widgets/section_card.dart';

String environmentDownloadSourceLabel(
  AppLocalizations l10n,
  RootfsDownloadSource source,
) => switch (source) {
  RootfsDownloadSource.automatic => l10n.workspaceEnvDownloadAutomatic,
  RootfsDownloadSource.official => l10n.workspaceEnvOfficial,
  RootfsDownloadSource.tuna => l10n.workspaceEnvMirrorNameTuna,
  RootfsDownloadSource.huawei => l10n.workspaceEnvMirrorNameHuawei,
  RootfsDownloadSource.custom => l10n.workspaceEnvDownloadCustom,
};

class EnvironmentDownloadPage extends StatefulWidget {
  const EnvironmentDownloadPage({
    super.key,
    required this.installer,
    this.install = false,
  });
  final EnvironmentInstaller installer;
  final bool install;
  @override
  State<EnvironmentDownloadPage> createState() =>
      _EnvironmentDownloadPageState();
}

class _EnvironmentDownloadPageState extends State<EnvironmentDownloadPage> {
  late RootfsDownloadSource _source;
  late final TextEditingController _url;
  bool _probing = false;
  bool _saving = false;
  String? _error;
  Map<RootfsDownloadSource, MirrorProbe> _results = {};

  @override
  void initState() {
    super.initState();
    final env = widget.installer.env;
    _source = env.downloadSource;
    _url = TextEditingController(text: env.downloadUrl);
  }

  @override
  void dispose() {
    _url.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await context.read<EnvironmentProvider>().setDownloadSource(
        _source,
        customUrl: _url.text,
      );
      if (mounted) Navigator.of(context).pop(true);
    } on FormatException {
      if (mounted) {
        setState(
          () => _error = AppLocalizations.of(
            context,
          )!.workspaceEnvDownloadInvalidUrl,
        );
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = AppLocalizations.of(context)!.workspaceEnvApplyFailed,
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _probe() async {
    setState(() {
      _probing = true;
      _results = {};
      _error = null;
    });
    try {
      final probe = await widget.installer.channel.probe();
      final arch = RootfsSource.archForAbi(probe.abi);
      if (arch == null) throw StateError('Unsupported ABI');
      final urls = <RootfsDownloadSource, Uri>{
        for (final source in [
          RootfsDownloadSource.official,
          RootfsDownloadSource.tuna,
          RootfsDownloadSource.huawei,
        ])
          source: widget.installer.source.selectedUri(source, '', arch)!,
        if (_source == RootfsDownloadSource.custom)
          RootfsDownloadSource.custom: RootfsSource.customTarballUri(
            _url.text,
            arch,
          ),
      };
      final results = await widget.installer.speedTest.probe(
        urls.values.toList(),
      );
      if (mounted) {
        setState(() => _results = Map.fromIterables(urls.keys, results));
      }
    } on FormatException {
      if (mounted) {
        setState(
          () => _error = AppLocalizations.of(
            context,
          )!.workspaceEnvDownloadInvalidUrl,
        );
      }
    } catch (_) {
      if (mounted) {
        setState(
          () =>
              _error = AppLocalizations.of(context)!.workspaceEnvMirrorsFailed,
        );
      }
    } finally {
      if (mounted) setState(() => _probing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        leading: IosIconButton(
          icon: Lucide.ArrowLeft,
          onTap: () => Navigator.of(context).maybePop(),
        ),
        title: Text(l10n.workspaceEnvDownloadSource),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          SectionCard(
            children: [
              for (final source in RootfsDownloadSource.values) ...[
                if (source.index > 0) const EnvironmentRowDivider(indent: 12),
                IosNavRow(
                  key: ValueKey('download-source-${source.name}'),
                  label: environmentDownloadSourceLabel(l10n, source),
                  subtitle: source == RootfsDownloadSource.automatic
                      ? l10n.workspaceEnvDownloadAutomaticDetail
                      : null,
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_results[source] case final result?) ...[
                        EnvironmentLatencyCapsule(
                          ms: result.ok ? result.latency!.inMilliseconds : null,
                          timedOut: !result.ok,
                        ),
                        const SizedBox(width: 8),
                      ],
                      if (_source == source)
                        Icon(Lucide.Check, size: 18, color: cs.primary),
                    ],
                  ),
                  onTap: _saving
                      ? null
                      : () => setState(() {
                          _source = source;
                          _error = null;
                        }),
                ),
              ],
            ],
          ),
          if (_source == RootfsDownloadSource.custom) ...[
            const SizedBox(height: 12),
            SectionCard(
              children: [
                IosFormTextField(
                  label: l10n.workspaceEnvDownloadCustom,
                  controller: _url,
                  inlineLabel: false,
                  keyboardType: TextInputType.url,
                  hintText: l10n.workspaceEnvDownloadCustomHint,
                  onChanged: (_) => setState(() {
                    _error = null;
                    _results.remove(RootfsDownloadSource.custom);
                  }),
                ),
              ],
            ),
            IosSectionFooter(text: l10n.workspaceEnvDownloadCustomDetail),
          ],
          IosSectionFooter(text: l10n.workspaceEnvDownloadVerified),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(_error!, style: TextStyle(color: cs.error)),
            ),
          IosTileButton(
            icon: Lucide.Gauge,
            label: _probing
                ? l10n.workspaceEnvDetectingMirrors
                : l10n.workspaceEnvSpeedTest,
            enabled: !_probing && !_saving,
            onTap: () => unawaited(_probe()),
          ),
          const SizedBox(height: 12),
          IosTileButton(
            key: const ValueKey('download-source-save'),
            icon: widget.install ? Lucide.Download : Lucide.Check,
            label: widget.install
                ? l10n.workspaceEnvDownloadStart
                : l10n.workspaceEnvDownloadSave,
            enabled: !_saving,
            backgroundColor: cs.primary,
            onTap: () => unawaited(_save()),
          ),
        ],
      ),
    );
  }
}
