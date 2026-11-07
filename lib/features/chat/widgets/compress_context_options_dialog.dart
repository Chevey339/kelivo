import 'dart:convert';
import 'context_compression_status.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:uuid/uuid.dart';
import '../../../core/models/chat_message.dart';
import '../../../core/models/compress_context_options.dart';
import '../../../core/models/compression_config.dart';
import '../../../core/models/context_operation.dart';
import '../../../core/models/context_compression_task.dart';
import '../../../core/providers/settings_provider.dart';
import '../../../core/providers/assistant_provider.dart';
import '../../../core/services/chat/chat_service.dart';
import '../../../core/services/chat/compression_templates.dart';
import '../../../core/services/chat/compression_prompt.dart';
import '../../../shared/widgets/ios_switch.dart';
import '../../../shared/widgets/ios_form_text_field.dart';
import '../../../theme/app_semantic_colors.dart';
import '../../../l10n/app_localizations.dart';
import '../../model/widgets/model_select_sheet.dart';
import 'context_dialog.dart';
import 'compression_controls.dart';
import 'compression_template_library.dart';
import '../../../desktop/widgets/desktop_select_dropdown.dart';
import '../../../shared/widgets/form_sheet.dart';
import '../../../shared/widgets/ios_text_button.dart';
import '../../../shared/widgets/section_card.dart';
import '../../../shared/widgets/segmented_tabs.dart';
import '../../home/widgets/model_icon.dart';

Future<CompressContextOptions?> showCompressContextOptions({
  required BuildContext context,
  required CompressContextOptionsDialog Function(bool sheet) builder,
}) => showCompressionSheetOrDialog<CompressContextOptions>(
  context,
  builder: builder,
);

class CompressContextOptionsDialog extends StatefulWidget {
  const CompressContextOptionsDialog({
    super.key,
    required this.messages,
    required this.operations,
    this.messageWindow,
    this.initialOptions,
    this.prepareInput,
    this.estimateContext,
    this.conversationId,
    this.sheet = false,
    this.previewRequest,
  });
  final List<ChatMessage> messages;
  final List<ContextOperation> operations;
  final int? messageWindow;
  final CompressContextOptions? initialOptions;
  final String? conversationId;
  final bool sheet;
  final Future<List<ChatMessage>> Function(List<ChatMessage>, bool)?
  prepareInput;
  final Future<CompressionBudget> Function(List<ChatMessage>)? estimateContext;
  final Future<CompressionRequestPreview> Function(
    CompressContextOptions,
    CompressionConfig,
  )?
  previewRequest;
  @override
  State<CompressContextOptionsDialog> createState() =>
      _CompressContextOptionsDialogState();
}

class _CompressContextOptionsDialogState
    extends State<CompressContextOptionsDialog> {
  late CompressionConfig _config;
  Map<String, dynamic> _overrides = {};
  List<CompressionTemplate> _templates = builtInCompressionTemplates;
  late CompressContextLimitMode _mode;
  late ContextHistorySource _source;
  late bool _newConversation;
  bool _advanced = false;
  bool _detailsExpanded = false;
  bool _saving = false;
  bool _savingRecipe = false;
  String? _error;
  final _focus = TextEditingController();
  final _keep = TextEditingController();
  final _length = TextEditingController();
  final _trigger = TextEditingController();
  final _target = TextEditingController();
  final _window = TextEditingController();
  final _attempts = TextEditingController();
  final _maxChars = TextEditingController();
  String? _planKey;
  Future<CompressionRequestPreview>? _planFuture;
  bool _includeManual = true;
  bool _includeAttachments = true;
  String? _locale;
  bool _configLoaded = false;

  @override
  void initState() {
    super.initState();
    final settings = context.read<SettingsProvider>();
    final initial = widget.initialOptions;
    _config = settings.compressionDefaults;
    _mode = initial?.mode ?? settings.compressLimitMode;
    _source = initial?.historySource ?? ContextHistorySource.effective;
    _newConversation =
        initial?.newConversation ?? settings.compressNewConversation;
    _focus.text = initial?.focus ?? '';
    _maxChars.text = '${initial?.maxChars ?? settings.compressMaxChars}';
    _includeManual = initial?.includeEditedSummaries ?? true;
    _includeAttachments = initial?.includeAttachmentsAndTools ?? true;
    _fillFields();
    if (initial?.keepUserMessages case final int keep) _keep.text = '$keep';
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final locale = Localizations.localeOf(context).toLanguageTag();
    if (_locale == locale) return;
    if (_locale == null) {
      _templates = builtInCompressionTemplatesForLocale(locale);
    }
    _locale = locale;
    unawaited(_load());
  }

  void _fillFields() {
    _keep.text = '${_config.keepRecentUserTurns}';
    _length.text = '${_config.summaryTokens}';
    _trigger.text = '${(_config.triggerInputRatio * 100).round()}';
    _target.text = '${(_config.targetInputRatio * 100).round()}';
    _window.text = _config.planningWindow?.toString() ?? '';
    _attempts.text = '${_config.maxRequestAttempts}';
  }

  Future<void> _load() async {
    final locale = _locale!;
    try {
      final chat = context.read<ChatService?>();
      final settings = context.read<SettingsProvider>();
      final library = chat?.chatRepositoryOrNull?.compression;
      if (library != null &&
          settings.compressPrompt != SettingsProvider.defaultCompressPrompt) {
        await library.importOriginalPrompt(settings.compressPrompt);
      }
      final templates =
          await library?.templates(locale: locale) ??
          builtInCompressionTemplatesForLocale(locale);
      final overrides = widget.conversationId == null
          ? <String, dynamic>{}
          : await chat?.compressionOverrides(widget.conversationId!) ?? {};
      if (!mounted || locale != _locale) return;
      setState(() {
        _templates = templates;
        if (!_configLoaded) {
          _configLoaded = true;
          _overrides = overrides;
          _config = settings.compressionDefaults.withOverrides(overrides);
          _fillFields();
          if (widget.initialOptions?.keepUserMessages case final int keep) {
            _keep.text = '$keep';
          }
        }
      });
    } catch (error) {
      if (mounted && locale == _locale) {
        setState(() => _error = error.toString());
      }
    }
  }

  @override
  void dispose() {
    for (final controller in [
      _focus,
      _keep,
      _length,
      _trigger,
      _target,
      _window,
      _attempts,
      _maxChars,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  CompressionConfig _values() => _config.withOverrides({
    'keepRecentUserTurns': int.parse(_keep.text),
    'summaryTokens': int.parse(_length.text),
    'triggerInputRatio': double.parse(_trigger.text) / 100,
    'targetInputRatio': double.parse(_target.text) / 100,
    'planningWindow': _window.text.trim().isEmpty
        ? null
        : int.parse(_window.text),
    'maxRequestAttempts': int.parse(_attempts.text),
  });
  CompressContextOptions _options({
    bool trial = false,
    bool regenerate = false,
  }) => CompressContextOptions(
    mode: _mode,
    maxChars:
        _mode == CompressContextLimitMode.start ||
            _mode == CompressContextLimitMode.recent
        ? int.tryParse(_maxChars.text)
        : null,
    keepUserMessages: _mode == CompressContextLimitMode.keepRecent
        ? int.tryParse(_keep.text)
        : null,
    historySource: _source,
    includeEditedSummaries: _includeManual,
    includeAttachmentsAndTools: _includeAttachments,
    newConversation: _newConversation,
    focus: _focus.text,
    regenerateExisting: regenerate || _source != ContextHistorySource.effective,
    previewOnly: trial,
  );
  void _change(Map<String, dynamic> changes) => setState(() {
    _config = _config.withOverrides(changes);
    _overrides.addAll(changes);
  });

  Future<void> _saveManualRange(SettingsProvider settings) async {
    final options = _options();
    await settings.setCompressLimitMode(options.mode);
    if ((options.maxChars ?? 0) > 0) {
      await settings.setCompressMaxChars(options.maxChars!);
    }
  }

  Future<void> _saveSettings() async {
    final settings = context.read<SettingsProvider>();
    final chat = context.read<ChatService?>();
    final values = _values();
    final original = _config.toJson();
    final changed = {
      for (final e in values.toJson().entries)
        if (original[e.key] != e.value) e.key: e.value,
    };
    if (widget.conversationId != null && chat != null) {
      await chat.setCompressionOverrides(widget.conversationId!, {
        ..._overrides,
        ...changed,
      });
    } else {
      await settings.setCompressionDefaults(values);
    }
    await _saveManualRange(settings);
    await settings.setCompressNewConversation(_newConversation);
  }

  Future<void> _submit({bool trial = false, bool regenerate = false}) async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await _saveSettings();
      if (mounted) {
        Navigator.pop(context, _options(trial: trial, regenerate: regenerate));
      }
    } catch (_) {
      if (mounted) {
        setState(
          () =>
              _error = AppLocalizations.of(context)!.compressionInvalidSettings,
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _library() async {
    final result = await showCompressionTemplateLibrary(
      context,
      selectionEnabled: true,
      selectedTemplateId: _config.templateId,
      onTemplateReplaced: (replacement) {
        if (!mounted) return;
        setState(() {
          _config = _config.withOverrides({'templateId': replacement});
          if (_overrides.containsKey('templateId')) {
            _overrides['templateId'] = replacement;
          }
        });
      },
    );
    if (!mounted) return;
    final repository = context
        .read<ChatService?>()
        ?.chatRepositoryOrNull
        ?.compression;
    if (result is CompressionRecipe && repository != null) {
      // A recipe owns its snapshot; use a local ID even after its source was deleted.
      final template = CompressionTemplate.fromJson({
        ...result.template.toJson(),
        'id': const Uuid().v4(),
      });
      await repository.saveTemplate(template);
      if (!mounted) return;
      setState(() {
        final mode = _config.mode;
        _config = result.settings.withOverrides({
          'mode': mode.name,
          'templateId': template.id,
        });
        _overrides.addAll(_config.toJson(includeMode: false));
        _focus.text = result.focus;
        _fillFields();
      });
    } else if (result is CompressionTemplate) {
      _change({'templateId': result.id});
    }
    final locale = _locale!;
    final templates =
        await repository?.templates(locale: locale) ??
        builtInCompressionTemplatesForLocale(locale);
    if (mounted && locale == _locale) {
      setState(() {
        _templates = templates;
        if (!_overrides.containsKey('templateId')) {
          _config = _config.withOverrides({
            'templateId': context
                .read<SettingsProvider>()
                .compressionDefaults
                .templateId,
          });
        }
        if (!_templates.any((t) => t.id == _config.templateId)) {
          _config = _config.withOverrides({'templateId': 'general'});
          _overrides['templateId'] = 'general';
        }
      });
    }
  }

  Future<CompressionRequestPreview>? _plan() {
    if (widget.previewRequest == null) return null;
    try {
      final values = _values();
      final options = _options(regenerate: true);
      final key = jsonEncode([_locale, values.toJson(), options.toJson()]);
      if (_planKey != key) {
        _planKey = key;
        _planFuture = widget.previewRequest!(options, values);
      }
      return _planFuture;
    } catch (_) {
      return null;
    }
  }

  Future<void> _preview() async {
    try {
      final options = _options(regenerate: true);
      final values = _values();
      final selection = selectCompressionHistory(
        widget.messages,
        widget.operations,
        options,
      );
      final input =
          await widget.prepareInput?.call(
            selection.input,
            _includeAttachments,
          ) ??
          selection.input;
      if (!mounted) return;
      final prompt = widget.previewRequest == null
          ? renderCompressionPrompt(
              template: _templates.firstWhere((t) => t.id == values.templateId),
              content: buildConversationTextForCompression(
                input,
                quoteMarker: AppLocalizations.of(context)!.selectionQuoteMarker,
              ),
              focus: options.focus,
              locale: _locale!,
              targetTokens: values.summaryTokens,
            )
          : (await widget.previewRequest!(options, values)).prompt;
      if (!mounted) return;
      await showCompressionPromptPreview(context, prompt);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    }
  }

  Future<void> _saveRecipe() async {
    if (_savingRecipe) return;
    final repository = context
        .read<ChatService?>()
        ?.chatRepositoryOrNull
        ?.compression;
    if (repository == null) return;
    setState(() => _savingRecipe = true);
    try {
      final config = _values();
      final template = _templates.firstWhere((t) => t.id == config.templateId);
      final focus = _focus.text;
      await showDialog<void>(
        context: context,
        builder: (_) => _SaveRecipeDialog(
          onSave: (name, bindModel) => repository.saveRecipe(
            CompressionRecipe(
              id: const Uuid().v4(),
              name: name,
              template: template,
              settings: bindModel
                  ? config
                  : config.withOverrides({'providerId': null, 'modelId': null}),
              focus: focus,
            ),
          ),
        ),
      );
    } catch (_) {
      if (mounted) {
        setState(
          () =>
              _error = AppLocalizations.of(context)!.compressionInvalidSettings,
        );
      }
    } finally {
      if (mounted) setState(() => _savingRecipe = false);
    }
  }

  Widget _number(
    String label,
    TextEditingController controller, {
    String? hint,
    String? unit,
  }) => CompressionNumberRow(
    label: label,
    controller: controller,
    hint: hint,
    unit: unit,
    onChanged: (_) => setState(() {}),
  );

  Widget _switch(
    String label,
    bool value,
    ValueChanged<bool> change, {
    String? hint,
  }) => CompressionSettingRow(
    label: label,
    subtitle: hint,
    onTap: () => change(!value),
    trailing: IosSwitch(value: value, semanticLabel: label, onChanged: change),
  );

  Widget _section(String title, List<Widget> children) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CompressionSectionTitle(title: title),
        SectionCard(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: children,
        ),
      ],
    ),
  );

  void _selectRange(CompressContextLimitMode mode) => setState(() {
    if (mode != CompressContextLimitMode.keepRecent) {
      // An abandoned, invalid value must not block a scope that does not use it.
      try {
        _config.withOverrides({'keepRecentUserTurns': int.parse(_keep.text)});
      } on FormatException {
        _keep.text = '${_config.keepRecentUserTurns}';
      }
    }
    _mode = mode;
  });

  String _rangeLabel(AppLocalizations l10n, CompressContextLimitMode mode) =>
      switch (mode) {
        CompressContextLimitMode.keepRecent =>
          l10n.compressContextKeepRecentMessages,
        CompressContextLimitMode.unlimited => l10n.compressContextUnlimited,
        CompressContextLimitMode.start => l10n.compressContextKeepStart,
        CompressContextLimitMode.recent => l10n.compressContextKeepRecent,
      };

  String _rangeHint(AppLocalizations l10n, CompressContextLimitMode mode) =>
      switch (mode) {
        CompressContextLimitMode.keepRecent => l10n.compressionScopeKeepHint,
        CompressContextLimitMode.unlimited => l10n.compressionScopeAllHint,
        CompressContextLimitMode.start => l10n.compressionScopeStartHint,
        CompressContextLimitMode.recent => l10n.compressionScopeRecentHint,
      };

  Widget _rangeSettings(CompressionSelection selection) {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    return _section(l10n.compressionManualRange, [
      Padding(
        padding: const EdgeInsets.fromLTRB(14, 8, 14, 4),
        child: DesktopSelectDropdown<CompressContextLimitMode>(
          value: _mode,
          minHeight: 44,
          maxLabelWidth: 320,
          semanticLabel: l10n.compressionManualRange,
          options: [
            for (final mode in const [
              CompressContextLimitMode.keepRecent,
              CompressContextLimitMode.unlimited,
              CompressContextLimitMode.start,
              CompressContextLimitMode.recent,
            ])
              DesktopSelectOption(
                value: mode,
                label: _rangeLabel(l10n, mode),
                subtitle: _rangeHint(l10n, mode),
              ),
          ],
          onSelected: _selectRange,
        ),
      ),
      if (_mode == CompressContextLimitMode.keepRecent)
        _number(
          l10n.compressionKeepTurns,
          _keep,
          unit: l10n.compressionTurnUnit,
        ),
      if (_mode == CompressContextLimitMode.start ||
          _mode == CompressContextLimitMode.recent)
        _number(l10n.compressContextMaxCharsLabel, _maxChars),
      Padding(
        padding: const EdgeInsets.fromLTRB(14, 6, 14, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _rangeHint(l10n, _mode),
              style: TextStyle(
                fontSize: 12,
                height: 1.4,
                color: cs.onSurfaceVariant,
              ),
            ),
            if (_mode == CompressContextLimitMode.keepRecent) ...[
              const SizedBox(height: 4),
              Text(
                l10n.compressionKeepHint,
                style: TextStyle(
                  fontSize: 12,
                  height: 1.4,
                  color: cs.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: 8),
            Text(
              l10n.compressionRange(
                selection.covered.length,
                countUserMessages(selection.retained),
              ),
              style: TextStyle(fontSize: 12, height: 1.4, color: cs.onSurface),
            ),
          ],
        ),
      ),
    ]);
  }

  Future<void> _selectModel(
    ({String? providerKey, String? modelId}) resolved,
  ) async {
    final selected = await showModelSelector(
      context,
      initialProviderKey: resolved.providerKey,
      initialModelId: resolved.modelId,
    );
    if (selected != null && mounted) {
      _change({
        'providerId': selected.providerKey,
        'modelId': selected.modelId,
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    final selection = selectCompressionHistory(
      widget.messages,
      widget.operations,
      _options(),
    );
    final settings = context.watch<SettingsProvider>();
    final chat = context.read<ChatService?>();
    final conversation = chat?.getConversation(widget.conversationId ?? '');
    final assistant = context
        .read<AssistantProvider?>()
        ?.resolveConversationAssistant(conversation?.assistantId);
    final resolved = resolveCompressContextModel(
      compressProvider: _config.providerId,
      compressModelId: _config.modelId,
      assistantProvider:
          conversation?.chatModelProvider ?? assistant?.chatModelProvider,
      assistantModelId: conversation?.chatModelId ?? assistant?.chatModelId,
      currentProvider: settings.currentModelProvider,
      currentModelId: settings.currentModelId,
    );
    final provider = resolved.providerKey == null
        ? null
        : settings.getProviderConfig(resolved.providerKey!);
    final selectedTemplate = _templates
        .where((t) => t.id == _config.templateId)
        .firstOrNull;
    final quickTemplates = _templates
        .where((t) => t.builtIn || t.id == _config.templateId)
        .toList();
    final hintStyle = TextStyle(
      fontSize: 12,
      height: 1.45,
      color: cs.onSurface.withValues(alpha: .55),
    );

    final body = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.sheet) ...[
          Center(
            child: Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(top: 8, bottom: 12),
              decoration: BoxDecoration(
                color: cs.onSurface.withValues(alpha: .18),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        ],
        CompressionPanelHeader(
          title: _advanced ? l10n.compressionMore : l10n.compressContext,
          onBack: _advanced ? () => setState(() => _advanced = false) : null,
          onClose: () => Navigator.pop(context),
        ),
        Flexible(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (!_advanced) ...[
                  CompressionSectionTitle(
                    title: l10n.compressionTemplate,
                    action: IosTextButton(
                      label: l10n.compressionManage,
                      icon: LucideIcons.library,
                      padding: const EdgeInsets.only(left: 10),
                      onPressed: _library,
                    ),
                  ),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final columns = constraints.maxWidth < 420 ? 3 : 5;
                      final width =
                          (constraints.maxWidth - 8 * (columns - 1)) / columns;
                      return Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final template in quickTemplates)
                            SizedBox(
                              width: width,
                              child: CompressionTemplateChoice(
                                label: compressionTemplateName(l10n, template),
                                selected: template.id == _config.templateId,
                                onTap: () =>
                                    _change({'templateId': template.id}),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                  if (selectedTemplate != null)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(2, 10, 2, 20),
                      child: Text(
                        compressionTemplateDescription(l10n, selectedTemplate),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: hintStyle,
                      ),
                    ),
                  CompressionSectionTitle(
                    title: l10n.compressContextModelLabel,
                    action: _config.providerId == null
                        ? null
                        : IosTextButton(
                            label: l10n.compressionChatModel,
                            fontSize: 12,
                            padding: const EdgeInsets.only(left: 8),
                            onPressed: () =>
                                _change({'providerId': null, 'modelId': null}),
                          ),
                  ),
                  SectionCard(
                    child: CompressionSettingRow(
                      leading: resolved.modelId == null
                          ? Icon(
                              LucideIcons.bot,
                              size: 28,
                              color: cs.onSurfaceVariant,
                            )
                          : CurrentModelIcon(
                              providerKey: resolved.providerKey,
                              modelId: resolved.modelId,
                              size: 34,
                              iconScale: .65,
                              withBackground: false,
                            ),
                      label: resolved.modelId ?? l10n.compressContextModelUnset,
                      subtitle: [
                        if (provider != null) provider.name,
                        if (_config.providerId == null)
                          l10n.compressionChatModel,
                      ].join(' · '),
                      onTap: () => _selectModel(resolved),
                    ),
                  ),
                  const SizedBox(height: 18),
                  _rangeSettings(selection),
                  SectionCard(
                    children: [
                      _switch(
                        l10n.compressNewConversation,
                        _newConversation,
                        (v) => setState(() => _newConversation = v),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        child: Container(
                          height: .6,
                          color: context.appColors.hairline,
                        ),
                      ),
                      CompressionSettingRow(
                        label: l10n.compressionMore,
                        leading: Icon(
                          LucideIcons.slidersHorizontal,
                          size: 18,
                          color: cs.onSurface.withValues(alpha: .7),
                        ),
                        onTap: () => setState(() => _advanced = true),
                      ),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(2, 16, 2, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (widget.previewRequest != null &&
                            selection.covered.isNotEmpty)
                          FutureBuilder<CompressionRequestPreview>(
                            future: _plan(),
                            builder: (context, snapshot) {
                              if (snapshot.hasError) {
                                return Text(
                                  compressionErrorLabel(
                                    l10n,
                                    snapshot.error.toString(),
                                  ),
                                  style: hintStyle,
                                );
                              }
                              final plan = snapshot.data;
                              if (plan == null) return const SizedBox.shrink();
                              return Text(
                                l10n.compressionPlannedCalls(
                                  plan.estimatedRequests,
                                  plan.maxRequestAttempts,
                                ),
                                style: hintStyle,
                              );
                            },
                          ),
                        if (selection.covered.isEmpty)
                          Text(
                            l10n.compressContextKeepAllMessages,
                            style: hintStyle,
                          ),
                        if (widget.operations.any(
                          (op) => op.isCompression && !op.revoked,
                        ))
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              l10n.compressionTemplateChanged,
                              style: hintStyle,
                            ),
                          ),
                      ],
                    ),
                  ),
                ] else ...[
                  _section(l10n.compressionOutputSettings, [
                    _number(l10n.compressionLength, _length),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      child: Container(
                        height: .6,
                        color: context.appColors.hairline,
                      ),
                    ),
                    IosFormTextField(
                      label: l10n.compressionFocus,
                      controller: _focus,
                      hintText: l10n.compressionFocusHint,
                      inlineLabel: false,
                      minLines: 2,
                      maxLines: 3,
                      outerPadding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
                    ),
                  ]),
                  _section(l10n.compressionAutoTitle, [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 6, 12, 8),
                      child: SegmentedTabs(
                        radioGroup: true,
                        height: 42,
                        tabs: [
                          SegmentedTab(label: l10n.compressionAutoOff),
                          SegmentedTab(label: l10n.compressionAutoNotify),
                          SegmentedTab(label: l10n.compressionAutoOn),
                        ],
                        index: _config.mode.index,
                        onChanged: (i) => _change({
                          'mode': AutoCompressionMode.values[i].name,
                        }),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
                      child: Text(switch (_config.mode) {
                        AutoCompressionMode.off => l10n.compressionAutoOffHint,
                        AutoCompressionMode.notify =>
                          l10n.compressionAutoNotifyHint,
                        AutoCompressionMode.auto => l10n.compressionAutoOnHint,
                      }, style: hintStyle),
                    ),
                    if (_config.mode != AutoCompressionMode.off)
                      _number(l10n.compressionTrigger, _trigger, unit: '%'),
                    if (_config.mode == AutoCompressionMode.auto) ...[
                      _number(
                        l10n.compressionKeepTurns,
                        _keep,
                        unit: l10n.compressionTurnUnit,
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(14, 2, 14, 10),
                        child: Text(
                          l10n.compressionAutoKeepHint,
                          style: hintStyle,
                        ),
                      ),
                    ],
                    if (_config.mode == AutoCompressionMode.auto)
                      _number(l10n.compressionTarget, _target, unit: '%'),
                    if (_config.mode != AutoCompressionMode.off)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(14, 2, 14, 10),
                        child: Text(
                          l10n.compressionBudgetHint,
                          style: hintStyle,
                        ),
                      ),
                  ]),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: SectionCard(
                      child: CompressionDisclosure(
                        title: l10n.compressionAdvancedOptions,
                        description: l10n.compressionAdvancedHint,
                        expanded: _detailsExpanded,
                        onToggle: () => setState(
                          () => _detailsExpanded = !_detailsExpanded,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _number(
                              l10n.compressionWindow,
                              _window,
                              hint: l10n.compressionAutomaticWindow,
                            ),
                            _number(
                              l10n.compressionRequests,
                              _attempts,
                              unit: l10n.compressionCallUnit,
                            ),
                            Padding(
                              padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
                              child: CompressionSectionTitle(
                                title: l10n.compressionSourceSettings,
                              ),
                            ),
                            _switch(
                              l10n.compressionReference,
                              _config.includeReference,
                              (v) => _change({'includeReference': v}),
                              hint: l10n.compressionReferenceHint,
                            ),
                            _switch(
                              l10n.compressionToolReferences,
                              _config.replaceConsumedTools,
                              (v) => _change({'replaceConsumedTools': v}),
                              hint: l10n.compressionToolReferencesHint,
                            ),
                            _switch(
                              l10n.compressionSummaryScan,
                              _config.summaryInWorldBookScan,
                              (v) => _change({'summaryInWorldBookScan': v}),
                            ),
                            _switch(
                              l10n.compressIncludeAttachments,
                              _includeAttachments,
                              (v) => setState(() => _includeAttachments = v),
                            ),
                            _switch(
                              l10n.compressReread,
                              _source == ContextHistorySource.original,
                              (v) => setState(
                                () => _source = v
                                    ? ContextHistorySource.original
                                    : ContextHistorySource.effective,
                              ),
                              hint: l10n.compressRereadDesc,
                            ),
                            if (_source != ContextHistorySource.effective)
                              _switch(
                                l10n.compressIncludeManual(0),
                                _includeManual,
                                (v) => setState(() => _includeManual = v),
                              ),
                            IosTextButton(
                              label: l10n.compressionSetGlobal,
                              mainAxisAlignment: MainAxisAlignment.start,
                              onPressed: () async {
                                try {
                                  await settings.setCompressionDefaults(
                                    _values().withOverrides({
                                      'mode': settings
                                          .compressionDefaults
                                          .mode
                                          .name,
                                    }),
                                  );
                                  await _saveManualRange(settings);
                                } catch (_) {
                                  if (mounted) {
                                    setState(
                                      () => _error =
                                          l10n.compressionInvalidSettings,
                                    );
                                  }
                                }
                              },
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                              ),
                              child: Text(
                                l10n.compressionGlobalDescription,
                                style: hintStyle,
                              ),
                            ),
                            IosTextButton(
                              label: l10n.compressionFollowGlobal,
                              mainAxisAlignment: MainAxisAlignment.start,
                              onPressed: () => setState(() {
                                _overrides = {};
                                _config = settings.compressionDefaults;
                                _mode = settings.compressLimitMode;
                                _maxChars.text = '${settings.compressMaxChars}';
                                _fillFields();
                              }),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  CompressionSectionTitle(title: l10n.compressionSavedSettings),
                  Wrap(
                    spacing: 18,
                    children: [
                      IosTextButton(
                        label: l10n.compressionPreviewAction,
                        icon: LucideIcons.fileText,
                        padding: EdgeInsets.zero,
                        onPressed: _preview,
                      ),
                      IosTextButton(
                        label: l10n.compressionSaveRecipeAction,
                        icon: LucideIcons.bookmark,
                        padding: EdgeInsets.zero,
                        onPressed: _savingRecipe ? null : _saveRecipe,
                      ),
                    ],
                  ),
                  IosTextButton(
                    label: l10n.compressionTry,
                    icon: LucideIcons.play,
                    fontSize: 12,
                    color: cs.onSurfaceVariant,
                    padding: EdgeInsets.zero,
                    mainAxisAlignment: MainAxisAlignment.start,
                    onPressed: selection.covered.isEmpty
                        ? null
                        : () => _submit(trial: true, regenerate: true),
                  ),
                ],
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(
                      _error!,
                      style: TextStyle(fontSize: 13, color: cs.error),
                    ),
                  ),
              ],
            ),
          ),
        ),
        CompressionPanelFooter(
          child: FormSheetActions(
            cancelLabel: l10n.homePageCancel,
            confirmLabel: _advanced
                ? l10n.multiKeyPageSave
                : selection.needsRegeneration
                ? l10n.compressRegenerate
                : _newConversation
                ? l10n.compressNewConversation
                : l10n.compressContextStartButton,
            onCancel: () => Navigator.pop(context),
            busy: _saving,
            onConfirm: _saving
                ? null
                : _advanced
                ? () async {
                    try {
                      await _saveSettings();
                      if (mounted) setState(() => _advanced = false);
                    } catch (_) {
                      if (mounted) {
                        setState(
                          () => _error = l10n.compressionInvalidSettings,
                        );
                      }
                    }
                  }
                : selection.covered.isEmpty
                ? null
                : () => _submit(regenerate: selection.needsRegeneration),
          ),
        ),
      ],
    );
    if (widget.sheet) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: body,
      );
    }
    return ContextDialog(maxWidth: 520, child: body);
  }
}

class _SaveRecipeDialog extends StatefulWidget {
  const _SaveRecipeDialog({required this.onSave});

  final Future<void> Function(String name, bool bindModel) onSave;

  @override
  State<_SaveRecipeDialog> createState() => _SaveRecipeDialogState();
}

class _SaveRecipeDialogState extends State<_SaveRecipeDialog> {
  // The field stays mounted throughout the route's closing animation.
  final _name = TextEditingController();
  bool _bindModel = false;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _close() {
    if (!_saving) Navigator.pop(context);
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (_saving || name.isEmpty) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.onSave(name, _bindModel);
      if (mounted) Navigator.pop(context);
    } catch (error) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = error.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    return PopScope(
      canPop: !_saving,
      child: ContextDialog(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            CompressionPanelHeader(
              title: l10n.compressionSaveRecipe,
              onClose: _close,
            ),
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    IosFormTextField(
                      label: l10n.compressionTemplateName,
                      controller: _name,
                      inlineLabel: false,
                      outerPadding: EdgeInsets.zero,
                      enabled: !_saving,
                      onChanged: (_) => setState(() {}),
                    ),
                    CompressionSettingRow(
                      label: l10n.compressionBindModel,
                      trailing: IosSwitch(
                        value: _bindModel,
                        onChanged: _saving
                            ? null
                            : (value) => setState(() => _bindModel = value),
                      ),
                    ),
                    Text(
                      l10n.compressionRecipeHint,
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.5,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Text(_error!, style: TextStyle(color: cs.error)),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 18),
            FormSheetActions(
              cancelLabel: l10n.homePageCancel,
              confirmLabel: l10n.multiKeyPageSave,
              onCancel: _close,
              busy: _saving,
              onConfirm: _saving || _name.text.trim().isEmpty ? null : _save,
            ),
          ],
        ),
      ),
    );
  }
}
