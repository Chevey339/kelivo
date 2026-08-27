import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';

import '../../../core/providers/asr_provider.dart';
import '../../../core/providers/settings_provider.dart';
import '../../../core/services/asr/asr_service_options.dart';
import '../../../core/services/asr/sherpa_model_manager.dart';
import '../../../core/services/asr/system_asr_service.dart';
import '../../../core/services/haptics.dart';
import '../../../icons/lucide_adapter.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/ios_tile_button.dart';
import '../../../shared/widgets/snackbar.dart';
import '../../../theme/app_font_weights.dart';
import '../../../utils/brand_assets.dart';
import 'voice_service_widgets.dart';
import 'package:Kelivo/theme/app_semantic_colors.dart';

/// The speech-recognition half of the Voice Services screen.
///
/// This widget deliberately owns only short-lived discovery/download helpers.
/// The selected provider and provider definitions stay in [SettingsProvider].
class AsrServicesSection extends StatefulWidget {
  const AsrServicesSection({
    super.key,
    this.desktop = false,
    this.modelManager,
  });

  final bool desktop;
  final SherpaModelManager? modelManager;

  @override
  State<AsrServicesSection> createState() => _AsrServicesSectionState();
}

class _AsrServicesSectionState extends State<AsrServicesSection> {
  late final SherpaModelManager _modelManager;
  late final bool _ownsModelManager;
  late final SystemAsrService _systemAsr;

  @override
  void initState() {
    super.initState();
    _ownsModelManager = widget.modelManager == null;
    _modelManager = widget.modelManager ?? SherpaModelManager();
    _systemAsr = SystemAsrService();
  }

  @override
  void dispose() {
    if (_ownsModelManager) _modelManager.dispose();
    unawaited(_systemAsr.dispose());
    super.dispose();
  }

  Future<void> _addService() async {
    final runtimeAsr = Provider.of<AsrProvider?>(context, listen: false);
    final created = await _showAsrEditor(
      context,
      desktop: widget.desktop,
      modelManager: _modelManager,
      checkSystemAvailability:
          runtimeAsr?.checkSystemAvailability ?? _systemAsr.initialize,
    );
    if (!mounted || created == null) return;

    final settings = context.read<SettingsProvider>();
    final updated = List<AsrServiceOptions>.from(settings.asrServices)
      ..add(created);
    await settings.setAsrServices(updated);
    if (settings.selectedAsrServiceId == null) {
      await settings.setSelectedAsrServiceId(created.id);
    }
    if (created is SherpaOnnxAsrOptions) {
      await runtimeAsr?.refreshAvailability(created);
    }
  }

  Future<void> _editService(AsrServiceOptions service) async {
    final runtimeAsr = Provider.of<AsrProvider?>(context, listen: false);
    final edited = await _showAsrEditor(
      context,
      desktop: widget.desktop,
      modelManager: _modelManager,
      checkSystemAvailability:
          runtimeAsr?.checkSystemAvailability ?? _systemAsr.initialize,
      initial: service,
    );
    if (!mounted || edited == null) return;

    final settings = context.read<SettingsProvider>();
    final updated = List<AsrServiceOptions>.from(settings.asrServices);
    final index = updated.indexWhere((item) => item.id == service.id);
    if (index < 0) return;
    updated[index] = edited;
    await settings.setAsrServices(updated);
    if (edited is SherpaOnnxAsrOptions) {
      await runtimeAsr?.refreshAvailability(edited);
    }
  }

  Future<void> _deleteService(AsrServiceOptions service) async {
    final settings = context.read<SettingsProvider>();
    final updated = List<AsrServiceOptions>.from(settings.asrServices)
      ..removeWhere((item) => item.id == service.id);
    await settings.setAsrServices(updated);
    if (settings.selectedAsrServiceId == service.id) {
      await settings.setSelectedAsrServiceId(
        updated.isEmpty ? null : updated.first.id,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final settings = context.watch<SettingsProvider>();
    final services = settings.asrServices;

    return Padding(
      padding: EdgeInsets.only(top: widget.desktop ? 28 : 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          VoiceServiceSectionHeader(
            title: l10n.asrServicesSectionTitle,
            addTooltip: l10n.asrServicesAddTooltip,
            onAdd: _addService,
            desktop: widget.desktop,
          ),
          SizedBox(height: widget.desktop ? 16 : 0),
          if (services.isEmpty)
            _EmptyAsrState(desktop: widget.desktop)
          else if (!widget.desktop)
            VoiceServiceMobileCard(
              children: [
                for (var index = 0; index < services.length; index++) ...[
                  _AsrServiceCard(
                    key: ValueKey('asr-service-${services[index].id}'),
                    service: services[index],
                    selected:
                        settings.selectedAsrServiceId == services[index].id,
                    desktop: false,
                    modelManager: _modelManager,
                    onSelect: () =>
                        settings.setSelectedAsrServiceId(services[index].id),
                    onEdit: () => _editService(services[index]),
                    onDelete: () => _deleteService(services[index]),
                  ),
                  if (index != services.length - 1)
                    voiceServiceMobileDivider(context),
                ],
              ],
            )
          else
            Column(
              children: [
                for (var index = 0; index < services.length; index++)
                  Padding(
                    key: ValueKey('asr-service-${services[index].id}'),
                    padding: EdgeInsets.only(
                      bottom: index == services.length - 1 ? 0 : 12,
                    ),
                    child: _AsrServiceCard(
                      service: services[index],
                      selected:
                          settings.selectedAsrServiceId == services[index].id,
                      desktop: widget.desktop,
                      modelManager: _modelManager,
                      onSelect: () =>
                          settings.setSelectedAsrServiceId(services[index].id),
                      onEdit: () => _editService(services[index]),
                      onDelete: () => _deleteService(services[index]),
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

class _EmptyAsrState extends StatelessWidget {
  const _EmptyAsrState({required this.desktop});

  final bool desktop;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final content = Padding(
      padding: EdgeInsets.symmetric(
        vertical: desktop ? 40 : 22,
        horizontal: 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            l10n.asrServicesEmptyTitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: cs.onSurface.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            l10n.asrServicesEmptySubtitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: cs.onSurface.withValues(alpha: 0.5),
            ),
          ),
        ],
      ),
    );
    return desktop
        ? Center(child: content)
        : VoiceServiceMobileCard(children: [content]);
  }
}

class _AsrServiceCard extends StatefulWidget {
  const _AsrServiceCard({
    super.key,
    required this.service,
    required this.selected,
    required this.desktop,
    required this.modelManager,
    required this.onSelect,
    required this.onEdit,
    required this.onDelete,
  });

  final AsrServiceOptions service;
  final bool selected;
  final bool desktop;
  final SherpaModelManager modelManager;
  final VoidCallback onSelect;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  State<_AsrServiceCard> createState() => _AsrServiceCardState();
}

class _AsrServiceCardState extends State<_AsrServiceCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return widget.desktop ? _buildDesktop(context) : _buildMobile(context);
  }

  Widget _buildMobile(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final displayName = _serviceDisplayName(l10n, widget.service);
    return VoiceServiceTactileRow(
      onTap: widget.onSelect,
      builder: (pressed) => AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        color: pressed
            ? cs.onSurface.withValues(alpha: 0.05)
            : Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        child: Row(
          children: [
            _ProviderBadge(kind: widget.service.kind, size: 36),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 15,
                      color: cs.onSurface.withValues(alpha: 0.9),
                      fontWeight: AppFontWeights.semibold,
                    ),
                  ),
                  const SizedBox(height: 3),
                  _ServiceSubtitle(
                    service: widget.service,
                    modelManager: widget.modelManager,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            VoiceServiceSmallIconButton(
              icon: Lucide.Settings2,
              tooltip: l10n.asrServicesEditAction,
              onTap: widget.onEdit,
            ),
            const SizedBox(width: 6),
            VoiceServiceSmallIconButton(
              icon: Lucide.Trash2,
              tooltip: l10n.asrServicesDeleteAction,
              onTap: widget.onDelete,
            ),
            const SizedBox(width: 8),
            widget.selected
                ? Icon(
                    Lucide.Check,
                    size: 16,
                    color: cs.onSurface.withValues(alpha: 0.9),
                  )
                : const SizedBox(width: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildDesktop(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context)!;
    final displayName = _serviceDisplayName(l10n, widget.service);
    final background = context.appColors.surfaceCard;
    final border = _hovered || widget.selected
        ? cs.primary.withValues(alpha: isDark ? 0.35 : 0.45)
        : cs.outlineVariant.withValues(alpha: isDark ? 0.12 : 0.08);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onSelect,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 170),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.all(14),
          constraints: const BoxConstraints(minHeight: 64),
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: border, width: 1),
          ),
          child: Row(
            children: [
              _ProviderBadge(kind: widget.service.kind, size: 24),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: AppFontWeights.emphasis,
                        color: cs.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    _ServiceSubtitle(
                      service: widget.service,
                      modelManager: widget.modelManager,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              VoiceServiceSmallIconButton(
                icon: Lucide.Settings2,
                tooltip: l10n.asrServicesEditAction,
                onTap: widget.onEdit,
              ),
              const SizedBox(width: 6),
              VoiceServiceSmallIconButton(
                icon: Lucide.Trash2,
                tooltip: l10n.asrServicesDeleteAction,
                onTap: widget.onDelete,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ServiceSubtitle extends StatelessWidget {
  const _ServiceSubtitle({required this.service, required this.modelManager});

  final AsrServiceOptions service;
  final SherpaModelManager modelManager;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final style = TextStyle(
      fontSize: 12,
      color: cs.onSurface.withValues(alpha: 0.60),
    );
    if (service case final SherpaOnnxAsrOptions local) {
      final model = SherpaModelCatalog.byId(local.modelId);
      return FutureBuilder<bool>(
        future: local.modelId.isEmpty
            ? Future<bool>.value(false)
            : modelManager.isInstalled(local.modelId),
        builder: (context, snapshot) {
          final status = snapshot.data == true
              ? l10n.asrServicesModelDownloadedLabel
              : l10n.asrServicesModelNotDownloadedLabel;
          final name = model?.name ?? l10n.asrServicesLocalSubtitle;
          return Text(
            '$name · $status',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: style,
          );
        },
      );
    }
    return Text(
      _kindSubtitle(l10n, service.kind),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: style,
    );
  }
}

class _ProviderBadge extends StatelessWidget {
  const _ProviderBadge({required this.kind, this.size = 36});

  final AsrServiceKind kind;
  final double size;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final asset = _kindBrandAsset(kind);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: cs.primary.withValues(alpha: 0.11),
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: asset == null
          ? Icon(_kindIcon(kind), size: size * 0.5, color: cs.primary)
          : asset.endsWith('.svg')
          ? SvgPicture.asset(
              asset,
              width: size * 0.56,
              height: size * 0.56,
              colorFilter: isDark && BrandAssets.assetNeedsDarkInvert(asset)
                  ? ColorFilter.mode(cs.onSurface, BlendMode.srcIn)
                  : null,
            )
          : Image.asset(
              asset,
              width: size * 0.56,
              height: size * 0.56,
              fit: BoxFit.contain,
            ),
    );
  }
}

String? _kindBrandAsset(AsrServiceKind kind) {
  final hint = switch (kind) {
    AsrServiceKind.openAiRealtime => 'OpenAI',
    AsrServiceKind.dashScope => 'Qwen',
    AsrServiceKind.qwenAudio => 'Qwen',
    AsrServiceKind.volcengine => 'Doubao',
    AsrServiceKind.mimo => 'MiMo',
    AsrServiceKind.step => 'Step',
    AsrServiceKind.sherpaOnnx || AsrServiceKind.system => '',
  };
  return hint.isEmpty ? null : BrandAssets.assetForName(hint);
}

Future<AsrServiceOptions?> _showAsrEditor(
  BuildContext context, {
  required bool desktop,
  required SherpaModelManager modelManager,
  required Future<bool> Function() checkSystemAvailability,
  AsrServiceOptions? initial,
}) {
  if (desktop) {
    return showDialog<AsrServiceOptions>(
      context: context,
      builder: (dialogContext) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        backgroundColor: dialogContext.overlaySurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560, maxHeight: 720),
          child: _AsrEditor(
            initial: initial,
            desktop: true,
            modelManager: modelManager,
            checkSystemAvailability: checkSystemAvailability,
            onCancel: () => Navigator.of(dialogContext).pop(),
            onSubmit: (value) => Navigator.of(dialogContext).pop(value),
          ),
        ),
      ),
    );
  }

  final editorKey = GlobalKey<_AsrEditorState>();
  return Navigator.of(context).push<AsrServiceOptions>(
    MaterialPageRoute(
      builder: (pageContext) => Scaffold(
        backgroundColor: Theme.of(pageContext).colorScheme.surface,
        appBar: AppBar(
          leading: VoiceServicePageIconButton(
            icon: Lucide.ArrowLeft,
            tooltip: AppLocalizations.of(pageContext)!.asrServicesCancelAction,
            onTap: () => Navigator.of(pageContext).pop(),
          ),
          title: Text(
            initial == null
                ? AppLocalizations.of(pageContext)!.asrServicesAddTitle
                : AppLocalizations.of(pageContext)!.asrServicesEditTitle,
          ),
          actions: [
            VoiceServicePageIconButton(
              icon: Lucide.Check,
              tooltip: initial == null
                  ? AppLocalizations.of(pageContext)!.asrServicesAddAction
                  : AppLocalizations.of(pageContext)!.asrServicesSaveAction,
              onTap: () => editorKey.currentState?._submit(),
            ),
            const SizedBox(width: 12),
          ],
        ),
        body: _AsrEditor(
          key: editorKey,
          initial: initial,
          desktop: false,
          modelManager: modelManager,
          checkSystemAvailability: checkSystemAvailability,
          onCancel: () => Navigator.of(pageContext).pop(),
          onSubmit: (value) => Navigator.of(pageContext).pop(value),
        ),
      ),
    ),
  );
}

class _AsrEditor extends StatefulWidget {
  const _AsrEditor({
    super.key,
    required this.initial,
    required this.desktop,
    required this.modelManager,
    required this.checkSystemAvailability,
    required this.onCancel,
    required this.onSubmit,
  });

  final AsrServiceOptions? initial;
  final bool desktop;
  final SherpaModelManager modelManager;
  final Future<bool> Function() checkSystemAvailability;
  final VoidCallback onCancel;
  final ValueChanged<AsrServiceOptions> onSubmit;

  @override
  State<_AsrEditor> createState() => _AsrEditorState();
}

class _AsrEditorState extends State<_AsrEditor> {
  late AsrServiceKind _kind;
  late final TextEditingController _nameController;
  late final TextEditingController _apiKeyController;
  late final TextEditingController _endpointController;
  late final TextEditingController _modelController;
  late final TextEditingController _resourceIdController;
  late final TextEditingController _languageController;
  String _localModelId = '';
  bool _apiKeyError = false;
  bool _checkingSystem = false;
  bool? _systemAvailable;
  final Map<String, SherpaModelInstallStatus> _modelStatuses = {};
  final Map<String, SherpaDownloadCancellationToken> _downloadTokens = {};

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    _kind = initial?.kind ?? AsrServiceKind.system;
    _nameController = TextEditingController(
      text: _editableServiceName(initial),
    );
    _apiKeyController = TextEditingController(text: _apiKeyOf(initial));
    _endpointController = TextEditingController(text: _endpointOf(initial));
    _modelController = TextEditingController(text: _modelOf(initial));
    _resourceIdController = TextEditingController(text: _resourceIdOf(initial));
    _languageController = TextEditingController(text: _languageOf(initial));
    if (initial case final SherpaOnnxAsrOptions local) {
      _localModelId = local.modelId;
    }
    _refreshModelStatuses();
    if (initial is SystemAsrOptions) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _checkSystem());
    }
  }

  @override
  void dispose() {
    for (final token in _downloadTokens.values) {
      token.cancel();
    }
    _nameController.dispose();
    _apiKeyController.dispose();
    _endpointController.dispose();
    _modelController.dispose();
    _resourceIdController.dispose();
    _languageController.dispose();
    super.dispose();
  }

  Future<void> _refreshModelStatuses() async {
    final statuses = await widget.modelManager.listStatuses();
    if (!mounted) return;
    setState(() {
      for (final status in statuses) {
        _modelStatuses[status.model.id] = status;
      }
    });
  }

  Future<void> _checkSystem() async {
    if (_checkingSystem) return;
    setState(() => _checkingSystem = true);
    bool available;
    try {
      available = await widget.checkSystemAvailability();
    } catch (_) {
      available = false;
    }
    if (!mounted) return;
    setState(() {
      _checkingSystem = false;
      _systemAvailable = available;
    });
  }

  void _selectKind(AsrServiceKind kind) {
    if (kind == _kind) return;
    Haptics.light();
    setState(() {
      _kind = kind;
      _apiKeyError = false;
      _nameController.clear();
      _apiKeyController.clear();
      _endpointController.text = _defaultEndpoint(kind);
      _modelController.text = _defaultModel(kind);
      _resourceIdController.text = _defaultResourceId(kind);
      _languageController.text =
          kind == AsrServiceKind.mimo || kind == AsrServiceKind.step
          ? 'auto'
          : '';
    });
    if (kind == AsrServiceKind.system) unawaited(_checkSystem());
  }

  Future<void> _downloadModel(SherpaModelDefinition model) async {
    if (_downloadTokens.containsKey(model.id)) return;
    final token = SherpaDownloadCancellationToken();
    _downloadTokens[model.id] = token;
    setState(() {
      _modelStatuses[model.id] = SherpaModelInstallStatus(
        model: model,
        state: SherpaModelInstallState.downloading,
      );
    });
    try {
      await widget.modelManager.download(
        model.id,
        cancellationToken: token,
        onProgress: (progress) {
          if (!mounted) return;
          setState(() {
            _modelStatuses[model.id] = SherpaModelInstallStatus(
              model: model,
              state: SherpaModelInstallState.downloading,
              progress: progress,
            );
          });
        },
      );
    } on SherpaDownloadCancelledException {
      // Cancellation is an expected user action.
    } catch (error) {
      if (mounted) {
        showAppSnackBar(
          context,
          message: AppLocalizations.of(
            context,
          )!.asrServicesDownloadFailed(error.toString()),
          type: NotificationType.error,
        );
      }
    } finally {
      _downloadTokens.remove(model.id);
      await _refreshModelStatuses();
    }
  }

  Future<void> _deleteModel(SherpaModelDefinition model) async {
    try {
      await widget.modelManager.delete(model.id);
      if (_localModelId == model.id && mounted) {
        setState(() => _localModelId = '');
      }
      await _refreshModelStatuses();
      if (mounted) {
        final selected = context.read<SettingsProvider>().selectedAsrService;
        if (selected is SherpaOnnxAsrOptions && selected.modelId == model.id) {
          await Provider.of<AsrProvider?>(
            context,
            listen: false,
          )?.refreshAvailability(selected);
        }
      }
    } catch (error) {
      if (!mounted) return;
      showAppSnackBar(
        context,
        message: AppLocalizations.of(
          context,
        )!.asrServicesDownloadFailed(error.toString()),
        type: NotificationType.error,
      );
    }
  }

  bool get _canSubmit {
    if (_kind == AsrServiceKind.sherpaOnnx) {
      return _localModelId.isNotEmpty &&
          _modelStatuses[_localModelId]?.isInstalled == true;
    }
    if (_kind == AsrServiceKind.system) return _systemAvailable == true;
    return _apiKeyController.text.trim().isNotEmpty;
  }

  Future<void> _submit() async {
    if (_kind != AsrServiceKind.sherpaOnnx &&
        _kind != AsrServiceKind.system &&
        _apiKeyController.text.trim().isEmpty) {
      setState(() => _apiKeyError = true);
      return;
    }
    if (!_canSubmit) return;
    if (_kind == AsrServiceKind.system && _systemAvailable == null) {
      await _checkSystem();
      if (!mounted) return;
    }

    final l10n = AppLocalizations.of(context)!;
    final name = _nameController.text.trim().isEmpty
        ? _kindTitle(l10n, _kind)
        : _nameController.text.trim();
    final id = widget.initial?.id;
    final language = _languageController.text.trim();
    switch (_kind) {
      case AsrServiceKind.sherpaOnnx:
        final directory = await widget.modelManager.modelDirectory(
          _localModelId,
        );
        widget.onSubmit(
          SherpaOnnxAsrOptions(
            id: id,
            name: name,
            modelId: _localModelId,
            modelDirectory: directory.path,
            language: language,
          ),
        );
        return;
      case AsrServiceKind.system:
        widget.onSubmit(
          SystemAsrOptions(id: id, name: name, localeId: language),
        );
        return;
      case AsrServiceKind.openAiRealtime:
        final initial = widget.initial is OpenAiRealtimeAsrOptions
            ? widget.initial as OpenAiRealtimeAsrOptions
            : null;
        widget.onSubmit(
          OpenAiRealtimeAsrOptions(
            id: id,
            name: name,
            apiKey: _apiKeyController.text.trim(),
            websocketUrl: _valueOrDefault(
              _endpointController.text,
              _defaultEndpoint(_kind),
            ),
            model: _valueOrDefault(_modelController.text, _defaultModel(_kind)),
            language: language,
            prompt: initial?.prompt ?? '',
            sampleRate: initial?.sampleRate ?? 24000,
            vadThreshold: initial?.vadThreshold ?? 0,
            prefixPaddingMs: initial?.prefixPaddingMs ?? 300,
            silenceDurationMs: initial?.silenceDurationMs ?? 500,
          ),
        );
        return;
      case AsrServiceKind.dashScope:
        final initial = widget.initial is DashScopeAsrOptions
            ? widget.initial as DashScopeAsrOptions
            : null;
        widget.onSubmit(
          DashScopeAsrOptions(
            id: id,
            name: name,
            apiKey: _apiKeyController.text.trim(),
            websocketUrl: _valueOrDefault(
              _endpointController.text,
              _defaultEndpoint(_kind),
            ),
            model: _valueOrDefault(_modelController.text, _defaultModel(_kind)),
            language: language,
            sampleRate: initial?.sampleRate ?? 16000,
            vadThreshold: initial?.vadThreshold ?? 0,
            silenceDurationMs: initial?.silenceDurationMs ?? 800,
          ),
        );
        return;
      case AsrServiceKind.qwenAudio:
        final initial = widget.initial is QwenAudioAsrOptions
            ? widget.initial as QwenAudioAsrOptions
            : null;
        widget.onSubmit(
          QwenAudioAsrOptions(
            id: id,
            name: name,
            apiKey: _apiKeyController.text.trim(),
            workspaceId: _endpointController.text.trim(),
            region: initial?.region ?? 'cn-beijing',
            model: _valueOrDefault(_modelController.text, _defaultModel(_kind)),
            sampleRate: initial?.sampleRate ?? 16000,
            format: initial?.format ?? 'pcm',
          ),
        );
        return;
      case AsrServiceKind.volcengine:
        widget.onSubmit(
          VolcengineAsrOptions(
            id: id,
            name: name,
            apiKey: _apiKeyController.text.trim(),
            websocketUrl: _valueOrDefault(
              _endpointController.text,
              _defaultEndpoint(_kind),
            ),
            resourceId: _valueOrDefault(
              _resourceIdController.text,
              _defaultResourceId(_kind),
            ),
            language: language,
          ),
        );
        return;
      case AsrServiceKind.mimo:
        final initial = widget.initial is MimoAsrOptions
            ? widget.initial as MimoAsrOptions
            : null;
        widget.onSubmit(
          MimoAsrOptions(
            id: id,
            name: name,
            apiKey: _apiKeyController.text.trim(),
            baseUrl: _valueOrDefault(
              _endpointController.text,
              _defaultEndpoint(_kind),
            ),
            model: _valueOrDefault(_modelController.text, _defaultModel(_kind)),
            language: language.isEmpty ? 'auto' : language,
            sampleRate: initial?.sampleRate ?? 16000,
            segmentDurationSec: initial?.segmentDurationSec ?? 30,
          ),
        );
        return;
      case AsrServiceKind.step:
        final initial = widget.initial is StepAsrOptions
            ? widget.initial as StepAsrOptions
            : null;
        widget.onSubmit(
          StepAsrOptions(
            id: id,
            name: name,
            apiKey: _apiKeyController.text.trim(),
            baseUrl: _valueOrDefault(
              _endpointController.text,
              _defaultEndpoint(_kind),
            ),
            model: _valueOrDefault(_modelController.text, _defaultModel(_kind)),
            language: language.isEmpty ? 'auto' : language,
            sampleRate: initial?.sampleRate ?? 16000,
            segmentDurationSec: initial?.segmentDurationSec ?? 30,
            enableItn: initial?.enableItn ?? true,
            enableTimestamp: initial?.enableTimestamp ?? false,
            hotwords: initial?.hotwords ?? const [],
          ),
        );
        return;
    }
  }

  List<Widget> _configurationWidgets(AppLocalizations l10n) {
    final widgets = <Widget>[
      _EditorField(
        label: l10n.asrServicesNameLabel,
        controller: _nameController,
        hint: _kindTitle(l10n, _kind),
        desktop: widget.desktop,
      ),
    ];
    if (_kind == AsrServiceKind.sherpaOnnx) {
      widgets.add(
        _LocalModelPicker(
          statuses: _modelStatuses,
          selectedModelId: _localModelId,
          downloadTokens: _downloadTokens,
          onDownload: _downloadModel,
          onCancelDownload: (model) {
            _downloadTokens[model.id]?.cancel();
            widget.modelManager.cancelDownload(model.id);
          },
          onDelete: _deleteModel,
          onUse: (model) => setState(() => _localModelId = model.id),
          languageController: _languageController,
          desktop: widget.desktop,
        ),
      );
      return widgets;
    }
    if (_kind == AsrServiceKind.system) {
      widgets.add(
        _SystemConfiguration(
          available: _systemAvailable,
          checking: _checkingSystem,
          localeController: _languageController,
          onCheck: _checkSystem,
          desktop: widget.desktop,
        ),
      );
      return widgets;
    }
    widgets.addAll([
      _EditorField(
        label: l10n.asrServicesApiKeyLabel,
        controller: _apiKeyController,
        obscure: true,
        desktop: widget.desktop,
        errorText: _apiKeyError ? l10n.asrServicesApiKeyRequired : null,
        onChanged: (_) {
          if (_apiKeyError && _apiKeyController.text.trim().isNotEmpty) {
            setState(() => _apiKeyError = false);
          } else {
            setState(() {});
          }
        },
      ),
      _EditorField(
        label: l10n.asrServicesEndpointLabel,
        controller: _endpointController,
        hint: _defaultEndpoint(_kind),
        desktop: widget.desktop,
      ),
      if (_kind == AsrServiceKind.volcengine)
        _EditorField(
          label: l10n.asrServicesResourceIdLabel,
          controller: _resourceIdController,
          hint: _defaultResourceId(_kind),
          desktop: widget.desktop,
        )
      else
        _EditorField(
          label: l10n.asrServicesModelLabel,
          controller: _modelController,
          hint: _defaultModel(_kind),
          desktop: widget.desktop,
        ),
      _EditorField(
        label: l10n.asrServicesLanguageLabel,
        controller: _languageController,
        hint: l10n.asrServicesAutomaticLabel,
        desktop: widget.desktop,
      ),
    ]);
    return widgets;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final title = widget.initial == null
        ? l10n.asrServicesAddTitle
        : l10n.asrServicesEditTitle;
    final actionLabel = widget.initial == null
        ? l10n.asrServicesAddAction
        : l10n.asrServicesSaveAction;
    final configuration = _configurationWidgets(l10n);
    if (!widget.desktop) {
      return SafeArea(
        top: false,
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                children: [
                  _EditorSectionHeader(
                    text: l10n.ttsServicesDialogProviderType,
                    first: true,
                  ),
                  VoiceServiceMobileCard(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                        child: SizedBox(
                          key: const ValueKey('asr-provider-choice-grid'),
                          width: double.infinity,
                          child: _ProviderChoiceGrid(
                            selected: _kind,
                            onSelected: _selectKind,
                          ),
                        ),
                      ),
                    ],
                  ),
                  _EditorSectionHeader(text: l10n.asrServicesSectionTitle),
                  VoiceServiceMobileCard(children: configuration),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: SizedBox(
                width: double.infinity,
                child: IosTileButton(
                  label: actionLabel,
                  icon: Lucide.Check,
                  enabled: _canSubmit,
                  backgroundColor: cs.primary,
                  foregroundColor: cs.primary,
                  onTap: _submit,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: AppFontWeights.emphasis,
                    color: cs.onSurface,
                  ),
                ),
              ),
              VoiceServiceHeaderIconButton(
                icon: Lucide.X,
                tooltip: l10n.asrServicesCancelAction,
                onTap: widget.onCancel,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Divider(
            height: 6,
            thickness: 0.6,
            indent: 12,
            endIndent: 12,
            color: cs.outlineVariant.withValues(alpha: 0.18),
          ),
          const SizedBox(height: 10),
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  VoiceServiceSelectRow<AsrServiceKind>(
                    label: l10n.ttsServicesDialogProviderType,
                    value: _kind,
                    options: const [
                      AsrServiceKind.system,
                      AsrServiceKind.sherpaOnnx,
                      AsrServiceKind.openAiRealtime,
                      AsrServiceKind.dashScope,
                      AsrServiceKind.qwenAudio,
                      AsrServiceKind.volcengine,
                      AsrServiceKind.mimo,
                      AsrServiceKind.step,
                    ],
                    labelFor: (kind) => _kindTitle(l10n, kind),
                    onSelected: _selectKind,
                  ),
                  const SizedBox(height: 6),
                  ...configuration,
                  const SizedBox(height: 14),
                ],
              ),
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextButton(
                  onPressed: widget.onCancel,
                  style: TextButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                  ),
                  child: Text(l10n.asrServicesCancelAction),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: _canSubmit ? _submit : null,
                  style: FilledButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                  ),
                  child: Text(actionLabel),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EditorSectionHeader extends StatelessWidget {
  const _EditorSectionHeader({required this.text, this.first = false});

  final String text;
  final bool first;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.fromLTRB(12, first ? 6 : 18, 12, 6),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 13,
          fontWeight: AppFontWeights.semibold,
          color: cs.onSurface.withValues(alpha: 0.8),
        ),
      ),
    );
  }
}

class _ProviderChoiceGrid extends StatelessWidget {
  const _ProviderChoiceGrid({required this.selected, required this.onSelected});

  final AsrServiceKind selected;
  final ValueChanged<AsrServiceKind> onSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _GroupLabel(text: l10n.asrServicesOnDeviceGroup),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final kind in const [
              AsrServiceKind.system,
              AsrServiceKind.sherpaOnnx,
            ])
              _ProviderChoice(
                kind: kind,
                selected: kind == selected,
                onTap: () => onSelected(kind),
              ),
          ],
        ),
        const SizedBox(height: 16),
        _GroupLabel(text: l10n.asrServicesCloudGroup),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final kind in const [
              AsrServiceKind.openAiRealtime,
              AsrServiceKind.dashScope,
              AsrServiceKind.qwenAudio,
              AsrServiceKind.volcengine,
              AsrServiceKind.mimo,
              AsrServiceKind.step,
            ])
              _ProviderChoice(
                kind: kind,
                selected: kind == selected,
                onTap: () => onSelected(kind),
              ),
          ],
        ),
      ],
    );
  }
}

class _ProviderChoice extends StatelessWidget {
  const _ProviderChoice({
    required this.kind,
    required this.selected,
    required this.onTap,
  });

  final AsrServiceKind kind;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    return VoiceServiceTactileRow(
      onTap: onTap,
      builder: (pressed) {
        final base = selected
            ? cs.primary.withValues(alpha: 0.13)
            : cs.onSurface.withValues(alpha: 0.06);
        return AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            color: pressed
                ? Color.alphaBlend(cs.onSurface.withValues(alpha: 0.06), base)
                : base,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected
                  ? cs.primary.withValues(alpha: 0.5)
                  : cs.outlineVariant.withValues(alpha: 0.22),
              width: 0.8,
            ),
          ),
          child: Text(
            _kindTitle(l10n, kind),
            style: TextStyle(
              fontSize: 14,
              fontWeight: AppFontWeights.semibold,
              color: selected ? cs.primary : cs.onSurface,
            ),
          ),
        );
      },
    );
  }
}

class _GroupLabel extends StatelessWidget {
  const _GroupLabel({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 12,
        fontWeight: AppFontWeights.semibold,
        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.66),
      ),
    );
  }
}

class _SystemConfiguration extends StatelessWidget {
  const _SystemConfiguration({
    required this.available,
    required this.checking,
    required this.localeController,
    required this.onCheck,
    required this.desktop,
  });

  final bool? available;
  final bool checking;
  final TextEditingController localeController;
  final VoidCallback onCheck;
  final bool desktop;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context)!;
    final statusText = checking
        ? l10n.asrServicesSystemChecking
        : available == true
        ? l10n.asrServicesSystemAvailable
        : available == false
        ? l10n.asrServicesSystemCheckFailed
        : l10n.asrServicesSystemSubtitle;
    final controlColor = desktop
        ? Colors.transparent
        : (context.appColors.surfaceFill);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(
            horizontal: desktop ? 4 : 12,
            vertical: desktop ? 6 : 10,
          ),
          child: Semantics(
            button: true,
            label: statusText,
            child: MouseRegion(
              cursor: checking
                  ? SystemMouseCursors.basic
                  : SystemMouseCursors.click,
              child: GestureDetector(
                key: const ValueKey('asr-system-status'),
                behavior: HitTestBehavior.opaque,
                onTap: checking ? null : onCheck,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: available == false
                        ? cs.error.withValues(alpha: isDark ? 0.10 : 0.06)
                        : controlColor,
                    borderRadius: BorderRadius.circular(desktop ? 10 : 12),
                    border: desktop || available == false
                        ? Border.all(
                            color: available == false
                                ? cs.error.withValues(alpha: 0.42)
                                : cs.onSurface.withValues(alpha: 0.24),
                          )
                        : null,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        checking
                            ? Lucide.Loader
                            : available == true
                            ? Lucide.Check
                            : Lucide.Mic,
                        size: 17,
                        color: available == false
                            ? cs.error
                            : available == true
                            ? cs.primary
                            : cs.onSurface.withValues(alpha: 0.58),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          statusText,
                          style: TextStyle(
                            fontSize: 12,
                            height: 1.35,
                            color: available == false
                                ? cs.error
                                : cs.onSurface.withValues(alpha: 0.70),
                          ),
                        ),
                      ),
                      if (!checking)
                        Icon(
                          Lucide.RefreshCw,
                          size: 16,
                          color: cs.onSurface.withValues(alpha: 0.44),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        _EditorField(
          label: l10n.asrServicesLanguageLabel,
          controller: localeController,
          hint: l10n.asrServicesAutomaticLabel,
          desktop: desktop,
        ),
      ],
    );
  }
}

class _LocalModelPicker extends StatelessWidget {
  const _LocalModelPicker({
    required this.statuses,
    required this.selectedModelId,
    required this.downloadTokens,
    required this.onDownload,
    required this.onCancelDownload,
    required this.onDelete,
    required this.onUse,
    required this.languageController,
    required this.desktop,
  });

  final Map<String, SherpaModelInstallStatus> statuses;
  final String selectedModelId;
  final Map<String, SherpaDownloadCancellationToken> downloadTokens;
  final ValueChanged<SherpaModelDefinition> onDownload;
  final ValueChanged<SherpaModelDefinition> onCancelDownload;
  final ValueChanged<SherpaModelDefinition> onDelete;
  final ValueChanged<SherpaModelDefinition> onUse;
  final TextEditingController languageController;
  final bool desktop;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final listColor = desktop
        ? Colors.transparent
        : (context.appColors.surfaceFill);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(
            horizontal: desktop ? 4 : 12,
            vertical: desktop ? 6 : 10,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l10n.asrServicesChooseModelTitle,
                style: TextStyle(
                  fontSize: desktop ? 12 : 13,
                  fontWeight: desktop
                      ? AppFontWeights.regular
                      : AppFontWeights.semibold,
                  color: cs.onSurface.withValues(alpha: 0.72),
                ),
              ),
              SizedBox(height: desktop ? 6 : 7),
              Container(
                key: const ValueKey('asr-local-model-list'),
                decoration: BoxDecoration(
                  color: listColor,
                  borderRadius: BorderRadius.circular(desktop ? 10 : 12),
                  border: desktop
                      ? Border.all(color: cs.onSurface.withValues(alpha: 0.24))
                      : null,
                ),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    for (
                      var i = 0;
                      i < SherpaModelCatalog.models.length;
                      i++
                    ) ...[
                      _ModelRow(
                        key: ValueKey(
                          'asr-model-${SherpaModelCatalog.models[i].id}',
                        ),
                        model: SherpaModelCatalog.models[i],
                        status: statuses[SherpaModelCatalog.models[i].id],
                        selected:
                            selectedModelId == SherpaModelCatalog.models[i].id,
                        downloading: downloadTokens.containsKey(
                          SherpaModelCatalog.models[i].id,
                        ),
                        onDownload: () =>
                            onDownload(SherpaModelCatalog.models[i]),
                        onCancelDownload: () =>
                            onCancelDownload(SherpaModelCatalog.models[i]),
                        onDelete: () => onDelete(SherpaModelCatalog.models[i]),
                        onUse: () => onUse(SherpaModelCatalog.models[i]),
                      ),
                      if (i != SherpaModelCatalog.models.length - 1)
                        Divider(
                          height: 0.6,
                          thickness: 0.6,
                          indent: 12,
                          endIndent: 12,
                          color: cs.outlineVariant.withValues(alpha: 0.18),
                        ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
        _EditorField(
          label: l10n.asrServicesLanguageLabel,
          controller: languageController,
          hint: l10n.asrServicesAutomaticLabel,
          desktop: desktop,
        ),
      ],
    );
  }
}

class _ModelRow extends StatelessWidget {
  const _ModelRow({
    super.key,
    required this.model,
    required this.status,
    required this.selected,
    required this.downloading,
    required this.onDownload,
    required this.onCancelDownload,
    required this.onDelete,
    required this.onUse,
  });

  final SherpaModelDefinition model;
  final SherpaModelInstallStatus? status;
  final bool selected;
  final bool downloading;
  final VoidCallback onDownload;
  final VoidCallback onCancelDownload;
  final VoidCallback onDelete;
  final VoidCallback onUse;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final installed = status?.isInstalled == true;
    final downloadProgress = status?.progress;
    final progress = downloadProgress?.progress;
    final percent = downloadProgress?.displayPercent;
    final statusLabel = downloading
        ? percent == null
              ? l10n.asrServicesModelDownloadingLabel
              : '${l10n.asrServicesModelDownloadingLabel} $percent%'
        : installed
        ? l10n.asrServicesModelDownloadedLabel
        : l10n.asrServicesModelNotDownloadedLabel;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 170),
      curve: Curves.easeOutCubic,
      color: selected
          ? cs.primary.withValues(alpha: 0.065)
          : Colors.transparent,
      padding: const EdgeInsets.fromLTRB(12, 11, 12, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  model.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: AppFontWeights.semibold,
                    color: cs.onSurface,
                  ),
                ),
              ),
              if (selected) ...[
                const SizedBox(width: 8),
                Icon(Lucide.Check, size: 17, color: cs.primary),
              ],
            ],
          ),
          const SizedBox(height: 3),
          Text(
            '${_formatBytes(model.downloadBytes)} · $statusLabel',
            style: TextStyle(
              fontSize: 11,
              color: cs.onSurface.withValues(alpha: 0.56),
            ),
          ),
          const SizedBox(height: 7),
          Text(
            model.description,
            style: TextStyle(
              fontSize: 12,
              height: 1.35,
              color: cs.onSurface.withValues(alpha: 0.62),
            ),
          ),
          if (downloading) ...[
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: SizedBox(
                key: ValueKey('asr-model-progress-${model.id}'),
                height: 4,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final fraction =
                        progress?.clamp(0.0, 1.0).toDouble() ?? 0.0;
                    return Stack(
                      fit: StackFit.expand,
                      children: [
                        ColoredBox(color: cs.onSurface.withValues(alpha: 0.08)),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            curve: Curves.easeOutCubic,
                            width: constraints.maxWidth * fraction,
                            color: cs.primary,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ],
          const SizedBox(height: 7),
          Align(
            alignment: Alignment.centerRight,
            child: Wrap(
              spacing: 4,
              runSpacing: 4,
              children: [
                if (downloading)
                  _CompactAction(
                    label: l10n.asrServicesCancelAction,
                    icon: Lucide.X,
                    onTap: onCancelDownload,
                  )
                else if (!installed)
                  _CompactAction(
                    label: l10n.asrServicesModelDownloadAction,
                    icon: Lucide.Download,
                    prominent: true,
                    onTap: onDownload,
                  )
                else ...[
                  if (!selected)
                    _CompactAction(
                      label: l10n.asrServicesModelUseAction,
                      icon: Lucide.Check,
                      prominent: true,
                      onTap: onUse,
                    ),
                  _CompactAction(
                    label: l10n.asrServicesModelDeleteAction,
                    icon: Lucide.Trash2,
                    destructive: true,
                    onTap: onDelete,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CompactAction extends StatefulWidget {
  const _CompactAction({
    required this.label,
    required this.icon,
    required this.onTap,
    this.prominent = false,
    this.destructive = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool prominent;
  final bool destructive;

  @override
  State<_CompactAction> createState() => _CompactActionState();
}

class _CompactActionState extends State<_CompactAction> {
  bool _hovered = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final color = widget.destructive
        ? cs.error
        : widget.prominent
        ? cs.primary
        : cs.onSurface.withValues(alpha: 0.72);
    final backgroundAlpha = _pressed
        ? 0.14
        : _hovered
        ? 0.09
        : widget.prominent
        ? 0.07
        : 0.0;
    return Semantics(
      button: true,
      label: widget.label,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (_) => setState(() => _pressed = true),
          onTapUp: (_) => setState(() => _pressed = false),
          onTapCancel: () => setState(() => _pressed = false),
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 130),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              color: color.withValues(alpha: backgroundAlpha),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(widget.icon, size: 14, color: color),
                const SizedBox(width: 5),
                Text(
                  widget.label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: AppFontWeights.semibold,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EditorField extends StatefulWidget {
  const _EditorField({
    required this.label,
    required this.controller,
    this.hint,
    this.obscure = false,
    this.errorText,
    this.onChanged,
    this.desktop = false,
  });

  final String label;
  final TextEditingController controller;
  final String? hint;
  final bool obscure;
  final String? errorText;
  final ValueChanged<String>? onChanged;
  final bool desktop;

  @override
  State<_EditorField> createState() => _EditorFieldState();
}

class _EditorFieldState extends State<_EditorField> {
  bool _obscured = true;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    if (widget.desktop) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.label,
              style: TextStyle(
                fontSize: 12,
                color: cs.onSurface.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: widget.controller,
              obscureText: widget.obscure,
              autocorrect: !widget.obscure,
              enableSuggestions: !widget.obscure,
              onChanged: widget.onChanged,
              decoration: InputDecoration(
                hintText: widget.hint,
                errorText: widget.errorText,
                isDense: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ],
        ),
      );
    }

    final fieldBg = context.appColors.surfaceFill;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: AppFontWeights.semibold,
              color: cs.onSurface.withValues(alpha: 0.72),
            ),
          ),
          const SizedBox(height: 7),
          TextField(
            controller: widget.controller,
            obscureText: widget.obscure && _obscured,
            autocorrect: !widget.obscure,
            enableSuggestions: !widget.obscure,
            onChanged: widget.onChanged,
            style: TextStyle(
              fontSize: 15,
              fontWeight: AppFontWeights.medium,
              color: cs.onSurface.withValues(alpha: 0.92),
            ),
            decoration: InputDecoration(
              hintText: widget.hint,
              errorText: widget.errorText,
              isDense: true,
              filled: true,
              fillColor: fieldBg,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: cs.primary, width: 1),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: cs.error, width: 1),
              ),
              focusedErrorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: cs.error, width: 1),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 12,
              ),
              suffixIcon: widget.obscure
                  ? _EditorVisibilityButton(
                      icon: _obscured ? Lucide.Eye : Lucide.EyeOff,
                      onTap: () => setState(() => _obscured = !_obscured),
                    )
                  : null,
            ),
          ),
        ],
      ),
    );
  }
}

class _EditorVisibilityButton extends StatefulWidget {
  const _EditorVisibilityButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  State<_EditorVisibilityButton> createState() =>
      _EditorVisibilityButtonState();
}

class _EditorVisibilityButtonState extends State<_EditorVisibilityButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.onSurface;
    return Semantics(
      button: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        onTap: () {
          Haptics.light();
          widget.onTap();
        },
        child: SizedBox(
          width: 44,
          height: 44,
          child: Icon(
            widget.icon,
            size: 18,
            color: color.withValues(alpha: _pressed ? 0.55 : 0.72),
          ),
        ),
      ),
    );
  }
}

IconData _kindIcon(AsrServiceKind kind) {
  switch (kind) {
    case AsrServiceKind.system:
      return Lucide.Mic;
    case AsrServiceKind.sherpaOnnx:
      return Lucide.HardDrive;
    case AsrServiceKind.openAiRealtime:
      return Lucide.AudioWaveform;
    case AsrServiceKind.dashScope:
      return Lucide.Network;
    case AsrServiceKind.qwenAudio:
      return Lucide.Network;
    case AsrServiceKind.volcengine:
      return Lucide.AudioWaveform;
    case AsrServiceKind.mimo:
      return Lucide.Globe;
    case AsrServiceKind.step:
      return Lucide.AudioWaveform;
  }
}

String _serviceDisplayName(AppLocalizations l10n, AsrServiceOptions service) {
  final name = service.name.trim();
  return name.isEmpty || _isDefaultServiceName(service.kind, name)
      ? _kindTitle(l10n, service.kind)
      : name;
}

String _editableServiceName(AsrServiceOptions? service) {
  if (service == null) return '';
  final name = service.name.trim();
  return _isDefaultServiceName(service.kind, name) ? '' : name;
}

bool _isDefaultServiceName(AsrServiceKind kind, String name) {
  return switch (kind) {
    AsrServiceKind.sherpaOnnx => const {
      'Sherpa-ONNX',
      'Offline Model',
      '本地离线模型',
      '本機離線模型',
      '本地模型',
      '本機模型',
    }.contains(name),
    AsrServiceKind.system => const {
      'System speech recognition',
      'System Recognition',
      'System',
      '系统语音识别',
      '系統語音辨識',
      '系统',
      '系統',
    }.contains(name),
    AsrServiceKind.openAiRealtime => const {
      'OpenAI Realtime ASR',
      'OpenAI Realtime',
    }.contains(name),
    AsrServiceKind.dashScope => const {
      'DashScope ASR',
      'DashScope Realtime',
      'DashScope 实时识别',
      'DashScope 即時辨識',
      'DashScope',
    }.contains(name),
    AsrServiceKind.qwenAudio => const {
      'Qwen Audio ASR',
      'Qwen Audio',
    }.contains(name),
    AsrServiceKind.volcengine => const {
      'Volcengine ASR',
      'Volcengine Speech Recognition',
      'Volcengine',
      '火山引擎语音识别',
      '火山引擎語音辨識',
      '火山引擎',
    }.contains(name),
    AsrServiceKind.mimo => const {
      'MiMo ASR',
      'MiMo Speech Recognition',
      'MiMo 语音识别',
      'MiMo 語音辨識',
      'MiMo',
    }.contains(name),
    AsrServiceKind.step => const {
      'Step ASR',
      'Step Speech Recognition',
      'Step',
      '阶跃星辰语音识别',
      '階躍星辰語音辨識',
      '阶跃星辰',
      '階躍星辰',
    }.contains(name),
  };
}

String _kindTitle(AppLocalizations l10n, AsrServiceKind kind) {
  switch (kind) {
    case AsrServiceKind.system:
      return l10n.asrServicesSystemTitle;
    case AsrServiceKind.sherpaOnnx:
      return l10n.asrServicesLocalTitle;
    case AsrServiceKind.openAiRealtime:
      return l10n.asrServicesOpenAiTitle;
    case AsrServiceKind.dashScope:
      return l10n.asrServicesDashScopeTitle;
    case AsrServiceKind.qwenAudio:
      return 'Qwen Audio';
    case AsrServiceKind.volcengine:
      return l10n.asrServicesVolcengineTitle;
    case AsrServiceKind.mimo:
      return l10n.asrServicesMimoTitle;
    case AsrServiceKind.step:
      return l10n.asrServicesStepTitle;
  }
}

String _kindSubtitle(AppLocalizations l10n, AsrServiceKind kind) {
  switch (kind) {
    case AsrServiceKind.system:
      return l10n.asrServicesSystemSubtitle;
    case AsrServiceKind.sherpaOnnx:
      return l10n.asrServicesLocalSubtitle;
    case AsrServiceKind.openAiRealtime:
      return l10n.asrServicesOpenAiSubtitle;
    case AsrServiceKind.dashScope:
      return l10n.asrServicesDashScopeSubtitle;
    case AsrServiceKind.qwenAudio:
      return 'Qwen Audio 3.0 ASR (/api-ws/v1/inference)';
    case AsrServiceKind.volcengine:
      return l10n.asrServicesVolcengineSubtitle;
    case AsrServiceKind.mimo:
      return l10n.asrServicesMimoSubtitle;
    case AsrServiceKind.step:
      return l10n.asrServicesStepSubtitle;
  }
}

String _apiKeyOf(AsrServiceOptions? options) {
  return switch (options) {
    OpenAiRealtimeAsrOptions value => value.apiKey,
    DashScopeAsrOptions value => value.apiKey,
    QwenAudioAsrOptions value => value.apiKey,
    VolcengineAsrOptions value => value.apiKey,
    MimoAsrOptions value => value.apiKey,
    StepAsrOptions value => value.apiKey,
    _ => '',
  };
}

String _endpointOf(AsrServiceOptions? options) {
  return switch (options) {
    OpenAiRealtimeAsrOptions value => value.websocketUrl,
    DashScopeAsrOptions value => value.websocketUrl,
    QwenAudioAsrOptions value => value.workspaceId,
    VolcengineAsrOptions value => value.websocketUrl,
    MimoAsrOptions value => value.baseUrl,
    StepAsrOptions value => value.baseUrl,
    _ => '',
  };
}

String _modelOf(AsrServiceOptions? options) {
  return switch (options) {
    OpenAiRealtimeAsrOptions value => value.model,
    DashScopeAsrOptions value => value.model,
    QwenAudioAsrOptions value => value.model,
    MimoAsrOptions value => value.model,
    StepAsrOptions value => value.model,
    _ => '',
  };
}

String _resourceIdOf(AsrServiceOptions? options) {
  return switch (options) {
    VolcengineAsrOptions value => value.resourceId,
    _ => '',
  };
}

String _languageOf(AsrServiceOptions? options) {
  return switch (options) {
    SherpaOnnxAsrOptions value => value.language,
    SystemAsrOptions value => value.localeId,
    OpenAiRealtimeAsrOptions value => value.language,
    DashScopeAsrOptions value => value.language,
    VolcengineAsrOptions value => value.language,
    MimoAsrOptions value => value.language,
    StepAsrOptions value => value.language,
    _ => '',
  };
}

String _defaultEndpoint(AsrServiceKind kind) {
  switch (kind) {
    case AsrServiceKind.openAiRealtime:
      return 'wss://api.openai.com/v1/realtime?intent=transcription';
    case AsrServiceKind.dashScope:
      return 'wss://dashscope.aliyuncs.com/api-ws/v1/realtime';
    case AsrServiceKind.qwenAudio:
      return '';
    case AsrServiceKind.volcengine:
      return 'wss://openspeech.bytedance.com/api/v3/sauc/bigmodel';
    case AsrServiceKind.mimo:
      return 'https://api.xiaomimimo.com/v1';
    case AsrServiceKind.step:
      return 'https://api.stepfun.com';
    case AsrServiceKind.sherpaOnnx:
    case AsrServiceKind.system:
      return '';
  }
}

String _defaultModel(AsrServiceKind kind) {
  switch (kind) {
    case AsrServiceKind.openAiRealtime:
      return 'gpt-live-transcribe';
    case AsrServiceKind.dashScope:
      return 'qwen3-asr-flash-realtime';
    case AsrServiceKind.qwenAudio:
      return 'qwen-audio-3.0-asr-flash-streaming';
    case AsrServiceKind.volcengine:
      return '';
    case AsrServiceKind.mimo:
      return 'mimo-v2.5-asr';
    case AsrServiceKind.step:
      return 'stepaudio-2.5-asr';
    case AsrServiceKind.sherpaOnnx:
    case AsrServiceKind.system:
      return '';
  }
}

String _defaultResourceId(AsrServiceKind kind) {
  // Keep Seed-ASR 2.0 default. Compatible: volc.bigasr.sauc.duration (ASR 1.0).
  // Needs real Key verification before changing the app default.
  return kind == AsrServiceKind.volcengine
      ? VolcengineAsrOptions.seedAsrDurationResourceId
      : '';
}

String _valueOrDefault(String value, String fallback) {
  final trimmed = value.trim();
  return trimmed.isEmpty ? fallback : trimmed;
}

String _formatBytes(int bytes) {
  final mb = bytes / (1024 * 1024);
  return '${mb.round()} MB';
}
