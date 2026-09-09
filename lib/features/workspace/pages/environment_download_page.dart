import 'dart:async';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
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
import 'package:Kelivo/shared/widgets/option_sheet.dart';
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
  RootfsDownloadSource.local => l10n.workspaceEnvLocalImage,
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
  late RootfsImage _image;
  late String _localPath;
  RootfsSource get _resolver => widget.installer.source.forImage(_image);
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
    _image = env.rootfsImage;
    _localPath = env.localArchivePath;
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
      await context.read<EnvironmentProvider>().setRootfsSelection(
        imageId: _image.id,
        source: _source,
        customUrl: _url.text,
        localArchivePath: _localPath,
      );
      if (mounted) Navigator.of(context).pop(true);
    } on FormatException {
      if (mounted) {
        setState(
          () => _error = _source == RootfsDownloadSource.local
              ? AppLocalizations.of(context)!.workspaceEnvInvalidImage
              : AppLocalizations.of(context)!.workspaceEnvDownloadInvalidUrl,
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
          if (_resolver.availableSources.contains(RootfsDownloadSource.tuna))
            RootfsDownloadSource.tuna,
          if (_resolver.availableSources.contains(RootfsDownloadSource.huawei))
            RootfsDownloadSource.huawei,
        ])
          source: _resolver.selectedUri(source, '', arch)!,
        if (_source == RootfsDownloadSource.custom)
          RootfsDownloadSource.custom: RootfsSource.customTarballUri(
            _url.text,
            arch,
            image: _image,
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
          () => _error = _source == RootfsDownloadSource.local
              ? AppLocalizations.of(context)!.workspaceEnvInvalidImage
              : AppLocalizations.of(context)!.workspaceEnvDownloadInvalidUrl,
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

  void _selectImage(RootfsImage image) {
    setState(() {
      _image = image;
      if (!_resolver.availableSources.contains(_source)) {
        _source = RootfsDownloadSource.automatic;
      }
      _results = {};
      _error = null;
    });
  }

  Future<void> _pickDistribution() async {
    final selected = await showOptionSheet<String>(
      context,
      title: AppLocalizations.of(context)!.workspaceEnvDistribution,
      selected: _image.distro,
      items: [
        for (final distro in ['ubuntu', 'alpine', 'debian'])
          OptionSheetItem(value: distro, label: RootfsImage.distroName(distro)),
      ],
    );
    if (mounted && selected != null && selected != _image.distro) {
      _selectImage(RootfsCatalog.defaultForDistro(selected));
    }
  }

  Future<void> _pickVersion() async {
    final selected = await showOptionSheet<String>(
      context,
      title: AppLocalizations.of(context)!.workspaceEnvSystemVersion,
      selected: _image.id,
      items: [
        for (final image in RootfsCatalog.forDistro(_image.distro))
          OptionSheetItem(value: image.id, label: image.version),
      ],
    );
    if (mounted && selected != null && selected != _image.id) {
      _selectImage(RootfsCatalog.byId(selected));
    }
  }

  Future<void> _pickLocal() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['tar', 'gz', 'xz', 'tgz', 'txz'],
        withData: false,
      );
      final path = result?.files.single.path;
      if (mounted && path != null) {
        setState(() {
          _localPath = path;
          _error = null;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = AppLocalizations.of(context)!.workspaceEnvInvalidImage,
        );
      }
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
        title: Text(l10n.workspaceEnvSystemImage),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          if (_source != RootfsDownloadSource.local) ...[
            SectionCard(
              children: [
                IosNavRow(
                  key: const ValueKey('rootfs-distro'),
                  label: l10n.workspaceEnvDistribution,
                  detailText: RootfsImage.distroName(_image.distro),
                  onTap: _saving || _probing
                      ? null
                      : () => unawaited(_pickDistribution()),
                ),
                const EnvironmentRowDivider(indent: 12),
                IosNavRow(
                  key: const ValueKey('rootfs-version'),
                  label: l10n.workspaceEnvSystemVersion,
                  detailText: _image.version,
                  onTap: _saving || _probing
                      ? null
                      : () => unawaited(_pickVersion()),
                ),
              ],
            ),
            const SizedBox(height: 12),
          ],
          SectionCard(
            children: [
              for (final source in _resolver.availableSources) ...[
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
                  onTap: _saving || _probing
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
          if (_source == RootfsDownloadSource.local) ...[
            const SizedBox(height: 12),
            SectionCard(
              children: [
                IosNavRow(
                  key: const ValueKey('rootfs-local-file'),
                  icon: Lucide.FileArchive,
                  label: l10n.workspaceEnvChooseImage,
                  subtitle: _localPath.isEmpty ? null : p.basename(_localPath),
                  onTap: _saving ? null : () => unawaited(_pickLocal()),
                ),
              ],
            ),
            IosSectionFooter(text: l10n.workspaceEnvLocalImageHint),
          ] else
            IosSectionFooter(text: l10n.workspaceEnvDownloadVerified),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(_error!, style: TextStyle(color: cs.error)),
            ),
          if (_source != RootfsDownloadSource.local)
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
                ? _source == RootfsDownloadSource.local
                      ? l10n.workspaceEnvImportImage
                      : l10n.workspaceEnvDownloadStart
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
