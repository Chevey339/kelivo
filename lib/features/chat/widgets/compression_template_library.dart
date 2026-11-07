import 'package:intl/intl.dart';
import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../../../core/database/compression_repository.dart';
import '../../../core/models/compression_config.dart';
import '../../../core/providers/settings_provider.dart';
import '../../../core/services/chat/chat_service.dart';
import '../../../core/services/chat/compression_prompt.dart';
import '../../../core/services/chat/compression_templates.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/ios_form_text_field.dart';
import 'compression_controls.dart';
import 'context_dialog.dart';
import '../../../desktop/widgets/desktop_select_dropdown.dart';
import '../../../shared/widgets/action_sheet.dart';
import '../../../shared/widgets/form_sheet.dart';
import '../../../shared/widgets/ios_tactile.dart';
import '../../../shared/widgets/ios_text_button.dart';
import '../../../shared/widgets/section_card.dart';
import '../../../shared/widgets/segmented_tabs.dart';
import '../../../theme/app_font_weights.dart';
import '../../../theme/app_semantic_colors.dart';

Future<Object?> showCompressionTemplateLibrary(
  BuildContext context, {
  bool selectionEnabled = false,
  String? selectedTemplateId,
  ValueChanged<String>? onTemplateReplaced,
}) => showCompressionSheetOrDialog<Object>(
  context,
  builder: (sheet) => CompressionTemplateLibrary(
    selectionEnabled: selectionEnabled,
    selectedTemplateId: selectedTemplateId,
    onTemplateReplaced: onTemplateReplaced,
    sheet: sheet,
  ),
);

class CompressionTemplateLibrary extends StatefulWidget {
  const CompressionTemplateLibrary({
    super.key,
    this.selectionEnabled = false,
    this.selectedTemplateId,
    this.onTemplateReplaced,
    this.sheet = false,
  });
  final bool selectionEnabled, sheet;
  final String? selectedTemplateId;
  final ValueChanged<String>? onTemplateReplaced;
  @override
  State<CompressionTemplateLibrary> createState() =>
      _CompressionTemplateLibraryState();
}

class _CompressionTemplateLibraryState
    extends State<CompressionTemplateLibrary> {
  final _search = TextEditingController();
  List<CompressionTemplate> _templates = [];
  List<CompressionRecipe> _recipes = [];
  Map<String, DateTime> _lastUsed = {};
  bool _showRecipes = false;
  late String? _selectedTemplateId = widget.selectedTemplateId;
  String? _error;
  String? _locale;
  CompressionRepository? get _repository =>
      context.read<ChatService>().chatRepositoryOrNull?.compression;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final locale = Localizations.localeOf(context).toLanguageTag();
    if (_locale == locale) return;
    _locale = locale;
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final locale = _locale!;
    try {
      final repository = _repository;
      if (repository == null) return;
      final settings = context.read<SettingsProvider>();
      if (settings.compressPrompt != SettingsProvider.defaultCompressPrompt) {
        await repository.importOriginalPrompt(settings.compressPrompt);
      }
      final templates = await repository.templates(locale: locale);
      final recipes = await repository.recipes();
      final lastUsed = await repository.templateLastUsed();
      if (mounted && locale == _locale) {
        setState(() {
          _templates = templates;
          _recipes = recipes;
          _lastUsed = lastUsed;
        });
      }
    } catch (error) {
      if (mounted && locale == _locale) {
        setState(() => _error = error.toString());
      }
    }
  }

  Future<void> _edit(CompressionTemplate? template, {bool copy = false}) async {
    final result = await showCompressionSheetOrDialog<CompressionTemplate>(
      context,
      builder: (sheet) =>
          _TemplateEditor(template: template, copy: copy, sheet: sheet),
    );
    if (result == null || !mounted) return;
    try {
      await _repository?.saveTemplate(result, locale: _locale!);
      await _load();
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    }
  }

  Future<void> _delete(CompressionTemplate template) async {
    final repository = _repository;
    if (repository == null) return;
    final settings = context.read<SettingsProvider>();
    final chat = context.read<ChatService>();
    final used = await repository.conversationsUsing(template.id);
    final recipes = await repository.recipes();
    if (!mounted) return;
    final l10n = AppLocalizations.of(context)!;
    var replacement = 'general';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, update) => ContextDialog(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              CompressionPanelHeader(
                title: l10n.compressionDeleteTemplate,
                onClose: () => Navigator.pop(ctx, false),
              ),
              Text(l10n.compressionTemplateReferences(used.length)),
              if (settings.compressionDefaults.templateId == template.id)
                Text(l10n.compressionGlobalTemplateReference),
              Text(
                l10n.compressionRecipeReferences(
                  recipes.where((r) => r.template.id == template.id).length,
                ),
              ),
              const SizedBox(height: 12),
              CompressionSectionTitle(
                title: l10n.compressionReplacementTemplate,
              ),
              DesktopSelectDropdown<String>(
                value: replacement,
                minHeight: 44,
                semanticLabel: l10n.compressionReplacementTemplate,
                options: [
                  for (final item in _templates.where(
                    (t) => t.id != template.id,
                  ))
                    DesktopSelectOption(
                      value: item.id,
                      label: compressionTemplateName(l10n, item),
                    ),
                ],
                onSelected: (value) => update(() => replacement = value),
              ),
              const SizedBox(height: 16),
              FormSheetActions(
                cancelLabel: l10n.homePageCancel,
                confirmLabel: l10n.homePageDelete,
                destructive: true,
                onCancel: () => Navigator.pop(ctx, false),
                onConfirm: () => Navigator.pop(ctx, true),
              ),
            ],
          ),
        ),
      ),
    );
    if (confirmed != true) return;
    try {
      if (settings.compressionDefaults.templateId == template.id) {
        await settings.setCompressionDefaults(
          settings.compressionDefaults.withOverrides({
            'templateId': replacement,
          }),
        );
      }
      chat.replaceTemporaryCompressionTemplate(template.id, replacement);
      await repository.deleteTemplate(template.id, replacementId: replacement);
      if (_selectedTemplateId == template.id) {
        _selectedTemplateId = replacement;
        widget.onTemplateReplaced?.call(replacement);
      }
      if (mounted) await _load();
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    }
  }

  Future<void> _import() async {
    final repository = _repository;
    if (repository == null) return;
    try {
      final files = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
        withData: true,
      );
      if (files == null) return;
      final file = files.files.single;
      if (file.size > 1024 * 1024) {
        throw const FormatException('File exceeds 1 MB');
      }
      final bytes = file.bytes ?? await File(file.path!).readAsBytes();
      await repository.importJson(utf8.decode(bytes));
      if (mounted) await _load();
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    }
  }

  Future<void> _export(String json) async {
    try {
      final path = await FilePicker.platform.saveFile(
        fileName: 'kelivo-compression.json',
        type: FileType.custom,
        allowedExtensions: ['json'],
        bytes: Uint8List.fromList(utf8.encode(json)),
      );
      if (path != null &&
          (Platform.isMacOS || Platform.isLinux || Platform.isWindows)) {
        await File(path).writeAsString(json);
      }
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    }
  }

  void _templateMenu(BuildContext anchorContext, CompressionTemplate template) {
    final l10n = AppLocalizations.of(context)!;
    final box = anchorContext.findRenderObject()! as RenderBox;
    showAdaptiveActionMenu(
      context,
      anchor: box.localToGlobal(Offset(box.size.width, box.size.height)),
      title: compressionTemplateName(l10n, template),
      items: [
        ActionSheetItem(
          icon: LucideIcons.fileText,
          label: l10n.compressionEditTemplate,
          onTap: () => _edit(template),
        ),
        ActionSheetItem(
          icon: LucideIcons.copy,
          label: l10n.compressionCopyEdit,
          onTap: () => _edit(template, copy: true),
        ),
        ActionSheetItem(
          icon: LucideIcons.pin,
          label: l10n.compressionSetGlobal,
          onTap: () async {
            final settings = context.read<SettingsProvider>();
            await settings.setCompressionDefaults(
              settings.compressionDefaults.withOverrides({
                'templateId': template.id,
              }),
            );
          },
        ),
        ActionSheetItem(
          icon: LucideIcons.download,
          label: l10n.compressionExport,
          onTap: () => _export(_repository!.exportTemplate(template)),
        ),
        ActionSheetItem(
          icon: LucideIcons.clipboard,
          label: l10n.compressionCopyJson,
          onTap: () => Clipboard.setData(
            ClipboardData(text: _repository!.exportTemplate(template)),
          ),
        ),
        if (!template.builtIn)
          ActionSheetItem(
            icon: LucideIcons.trash2,
            label: l10n.homePageDelete,
            destructive: true,
            onTap: () => _delete(template),
          ),
      ],
    );
  }

  Widget _templateGroup(
    String title,
    List<CompressionTemplate> templates,
    String defaultId,
  ) {
    final cs = Theme.of(context).colorScheme;
    return SliverMainAxisGroup(
      slivers: [
        SliverToBoxAdapter(
          child: CompressionSectionTitle(
            title: title,
            action: Text(
              '${templates.length}',
              style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
            ),
          ),
        ),
        DecoratedSliver(
          decoration: BoxDecoration(
            color: context.appColors.surfaceCard,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: context.appColors.hairline, width: .6),
          ),
          sliver: SliverPadding(
            padding: const EdgeInsets.all(5),
            sliver: SliverList.separated(
              itemCount: templates.length,
              separatorBuilder: (_, _) => const SizedBox(height: 2),
              itemBuilder: (_, i) => _templateTile(templates[i], defaultId),
            ),
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 18)),
      ],
    );
  }

  Widget _templateTile(CompressionTemplate template, String defaultId) {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    final selected = _selectedTemplateId == template.id;
    return Semantics(
      selected: selected,
      child: IosCardPress(
        focusable: true,
        baseColor: selected
            ? cs.primary.withValues(alpha: .07)
            : Colors.transparent,
        border: Border.all(
          color: selected
              ? cs.primary.withValues(alpha: .22)
              : Colors.transparent,
          width: .6,
        ),
        borderRadius: BorderRadius.circular(9),
        onTap: widget.selectionEnabled
            ? () => Navigator.pop(context, template)
            : () => _edit(template),
        padding: const EdgeInsets.fromLTRB(10, 12, 2, 12),
        child: Row(
          children: [
            Icon(
              compressionTemplateIcon(template),
              size: 20,
              color: selected
                  ? cs.primary
                  : cs.onSurface.withValues(alpha: .55),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 7,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        compressionTemplateName(l10n, template),
                        style: TextStyle(
                          fontSize: 15,
                          color: selected ? cs.primary : cs.onSurface,
                          fontWeight: AppFontWeights.medium,
                        ),
                      ),
                      if (selected)
                        Icon(LucideIcons.check, size: 14, color: cs.primary),
                      if (defaultId == template.id)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 5,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: cs.onSurface.withValues(alpha: .05),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            l10n.compressionGlobalDefault,
                            style: TextStyle(
                              fontSize: 10,
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Text(
                    compressionTemplateDescription(l10n, template),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.4,
                      color: cs.onSurface.withValues(alpha: .6),
                    ),
                  ),
                  if (_lastUsed[template.id] case final DateTime date)
                    Padding(
                      padding: const EdgeInsets.only(top: 5),
                      child: Text(
                        l10n.compressionLastUsed(
                          DateFormat.yMd().format(date.toLocal()),
                        ),
                        style: TextStyle(
                          fontSize: 11,
                          color: cs.onSurface.withValues(alpha: .45),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Builder(
              builder: (anchorContext) => IosIconButton(
                icon: LucideIcons.ellipsis,
                minSize: 40,
                size: 18,
                tooltip: l10n.compressionMore,
                onTap: () => _templateMenu(anchorContext, template),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _recipeTile(CompressionRecipe recipe) {
    final l10n = AppLocalizations.of(context)!;
    return CompressionSettingRow(
      label: recipe.name,
      leading: Icon(
        LucideIcons.bookmark,
        size: 20,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
      subtitle: compressionTemplateName(l10n, recipe.template),
      onTap: widget.selectionEnabled
          ? () => Navigator.pop(context, recipe)
          : null,
      trailing: Builder(
        builder: (anchorContext) => IosIconButton(
          icon: LucideIcons.ellipsis,
          minSize: 40,
          size: 18,
          tooltip: l10n.compressionMore,
          onTap: () {
            final box = anchorContext.findRenderObject()! as RenderBox;
            showAdaptiveActionMenu(
              context,
              anchor: box.localToGlobal(
                Offset(box.size.width, box.size.height),
              ),
              title: recipe.name,
              items: [
                ActionSheetItem(
                  icon: LucideIcons.download,
                  label: l10n.compressionExport,
                  onTap: () => _export(_repository!.exportRecipe(recipe)),
                ),
                ActionSheetItem(
                  icon: LucideIcons.trash2,
                  label: l10n.homePageDelete,
                  destructive: true,
                  onTap: () async {
                    await _repository!.deleteRecipe(recipe.id);
                    if (mounted) await _load();
                  },
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    final defaults = context.watch<SettingsProvider>().compressionDefaults;
    final query = _search.text.trim().toLowerCase();
    final templates = _templates
        .where(
          (t) =>
              compressionTemplateName(l10n, t).toLowerCase().contains(query) ||
              compressionTemplateDescription(
                l10n,
                t,
              ).toLowerCase().contains(query),
        )
        .toList();
    final builtIn = templates.where((t) => t.builtIn).toList();
    final personal = templates.where((t) => !t.builtIn).toList();
    final recipes = _recipes
        .where((r) => r.name.toLowerCase().contains(query))
        .toList();
    final count = _showRecipes ? recipes.length : templates.length;
    return CompressionPanel(
      title: l10n.compressionLibraryTitle,
      sheet: widget.sheet,
      height: widget.sheet ? MediaQuery.sizeOf(context).height * .82 : 640,
      actions: Row(
        children: [
          IosTextButton(
            label: l10n.compressionImport,
            icon: LucideIcons.upload,
            onPressed: _import,
            color: cs.onSurface.withValues(alpha: .7),
            padding: EdgeInsets.zero,
          ),
          const Spacer(),
          if (!_showRecipes)
            Flexible(
              child: SizedBox(
                width: 170,
                child: ContextDialogActionButton(
                  label: l10n.compressionNewTemplate,
                  primary: true,
                  onTap: () => _edit(null),
                ),
              ),
            ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SegmentedTabs(
            tabs: [
              SegmentedTab(label: l10n.compressionTemplates),
              SegmentedTab(label: l10n.compressionRecipes),
            ],
            index: _showRecipes ? 1 : 0,
            onChanged: (i) => setState(() => _showRecipes = i == 1),
          ),
          IosFormTextField(
            label: '',
            controller: _search,
            hintText: _showRecipes
                ? l10n.compressionSearchRecipes
                : l10n.compressionSearchTemplates,
            prefix: Icon(
              LucideIcons.search,
              size: 17,
              color: cs.onSurfaceVariant,
            ),
            inlineLabel: false,
            outerPadding: const EdgeInsets.symmetric(vertical: 12),
            compact: true,
            onChanged: (_) => setState(() {}),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                _error!,
                style: TextStyle(fontSize: 13, color: cs.error),
              ),
            ),
          if (_showRecipes && recipes.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Text(
                l10n.compressionRecipeHint,
                style: TextStyle(
                  fontSize: 12,
                  height: 1.4,
                  color: cs.onSurfaceVariant,
                ),
              ),
            ),
          Expanded(
            child: count == 0
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _showRecipes
                              ? LucideIcons.bookmark
                              : LucideIcons.search,
                          size: 30,
                          color: cs.onSurface.withValues(alpha: .3),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _showRecipes
                              ? l10n.compressionNoRecipes
                              : l10n.compressionNoTemplatesFound,
                          style: TextStyle(
                            fontSize: 14,
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                        if (_showRecipes && query.isEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            l10n.compressionRecipeCreateHint,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 12,
                              height: 1.5,
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ],
                    ),
                  )
                : _showRecipes
                ? SectionCard(
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      itemCount: recipes.length,
                      itemBuilder: (_, i) => _recipeTile(recipes[i]),
                    ),
                  )
                : CustomScrollView(
                    slivers: [
                      if (builtIn.isNotEmpty)
                        _templateGroup(
                          l10n.compressionBuiltInTemplates,
                          builtIn,
                          defaults.templateId,
                        ),
                      if (personal.isNotEmpty)
                        _templateGroup(
                          l10n.compressionMyTemplates,
                          personal,
                          defaults.templateId,
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _TemplateEditor extends StatefulWidget {
  const _TemplateEditor({
    this.template,
    this.copy = false,
    required this.sheet,
  });
  final CompressionTemplate? template;
  final bool copy, sheet;
  @override
  State<_TemplateEditor> createState() => _TemplateEditorState();
}

class _TemplateEditorState extends State<_TemplateEditor> {
  late final _name = TextEditingController(
    text: widget.template == null
        ? ''
        : compressionTemplateName(
            AppLocalizations.of(context)!,
            widget.template!,
          ),
  );
  late final _prompt = TextEditingController(
    text: widget.template?.prompt ?? '',
  );
  late final _language = TextEditingController(
    text: widget.template?.outputLanguage ?? 'conversation',
  );
  bool _customLanguage = false;
  CompressionTemplate? get _defaultTemplate => widget.copy
      ? null
      : builtInCompressionTemplatesForLocale(
          Localizations.localeOf(context).toLanguageTag(),
        ).where((template) => template.id == widget.template?.id).firstOrNull;
  static const _languages = {
    'conversation',
    'legacy',
    'en',
    'zh-Hans',
    'zh-Hant',
  };
  @override
  void initState() {
    super.initState();
    _customLanguage = !_languages.contains(_language.text);
  }

  @override
  void dispose() {
    _name.dispose();
    _prompt.dispose();
    _language.dispose();
    super.dispose();
  }

  CompressionTemplate _value() => CompressionTemplate(
    id: widget.copy || widget.template == null
        ? const Uuid().v4()
        : widget.template!.id,
    name:
        _defaultTemplate != null &&
            _name.text.trim() ==
                compressionTemplateName(
                  AppLocalizations.of(context)!,
                  _defaultTemplate!,
                )
        ? _defaultTemplate!.name
        : _name.text.trim(),
    prompt: _prompt.text,
    scene: widget.template?.scene ?? 'general',
    builtIn: _defaultTemplate != null,
    outputLanguage: _language.text.trim().isEmpty
        ? 'conversation'
        : _language.text.trim(),
  );

  void _restoreDefault() {
    final template = _defaultTemplate!;
    setState(() {
      _name.text = compressionTemplateName(
        AppLocalizations.of(context)!,
        template,
      );
      _prompt.text = template.prompt;
      _language.text = template.outputLanguage;
      _customLanguage = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    return CompressionPanel(
      title: widget.template == null
          ? l10n.compressionNewTemplate
          : l10n.compressionEditTemplate,
      sheet: widget.sheet,
      maxWidth: 720,
      height: 680,
      actions: FormSheetActions(
        cancelLabel: l10n.homePageCancel,
        confirmLabel: l10n.multiKeyPageSave,
        onCancel: () => Navigator.pop(context),
        onConfirm: _name.text.trim().isEmpty || _prompt.text.trim().isEmpty
            ? null
            : () => Navigator.pop(context, _value()),
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_defaultTemplate != null)
              CompressionSectionTitle(
                title: l10n.compressionBuiltIn,
                action: IosTextButton(
                  label: l10n.compressionRestoreDefault,
                  onPressed: _restoreDefault,
                ),
              ),
            SectionCard(
              children: [
                IosFormTextField(
                  label: l10n.compressionTemplateName,
                  controller: _name,
                  inlineLabel: false,
                  onChanged: (_) => setState(() {}),
                ),
                CompressionSettingRow(
                  label: l10n.compressionLanguage,
                  trailing: DesktopSelectDropdown<String>(
                    value: _customLanguage ? 'custom' : _language.text,
                    minHeight: 40,
                    maxLabelWidth: 170,
                    semanticLabel: l10n.compressionLanguage,
                    options: [
                      DesktopSelectOption(
                        value: 'conversation',
                        label: l10n.compressionLanguageConversation,
                      ),
                      if (_language.text == 'legacy')
                        DesktopSelectOption(
                          value: 'legacy',
                          label: l10n.compressionLanguageLegacy,
                        ),
                      const DesktopSelectOption(value: 'en', label: 'English'),
                      const DesktopSelectOption(
                        value: 'zh-Hans',
                        label: '简体中文',
                      ),
                      const DesktopSelectOption(
                        value: 'zh-Hant',
                        label: '繁體中文',
                      ),
                      DesktopSelectOption(
                        value: 'custom',
                        label: l10n.compressionCustomLanguage,
                      ),
                    ],
                    onSelected: (value) => setState(() {
                      _customLanguage = value == 'custom';
                      _language.text = _customLanguage ? '' : value;
                    }),
                  ),
                ),
                if (_customLanguage)
                  IosFormTextField(
                    label: l10n.compressionLanguage,
                    controller: _language,
                    hintText: l10n.compressionCustomLanguageHint,
                    inlineLabel: false,
                  ),
              ],
            ),
            const SizedBox(height: 18),
            IosFormTextField(
              label: l10n.compressionPrompt,
              controller: _prompt,
              minLines: 10,
              // Keep one vertical scroll owner, including drags over the text.
              maxLines: null,
              scrollPhysics: const NeverScrollableScrollPhysics(),
              inlineLabel: false,
              outerPadding: EdgeInsets.zero,
              textStyle: TextStyle(
                fontSize: 14,
                height: 1.5,
                color: cs.onSurface,
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            Text(
              l10n.compressionVariables,
              style: TextStyle(
                fontSize: 12,
                height: 1.4,
                color: cs.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 6),
            SelectableText(
              '{content} · {previous_summary} · {background} · {focus} · {target_tokens} · {locale}',
              style: TextStyle(
                fontSize: 12,
                height: 1.5,
                color: cs.onSurface.withValues(alpha: .6),
              ),
            ),
            IosTextButton(
              label: l10n.compressionLocalPreview,
              icon: LucideIcons.fileText,
              padding: EdgeInsets.zero,
              mainAxisAlignment: MainAxisAlignment.start,
              onPressed: () => showCompressionPromptPreview(
                context,
                renderCompressionPrompt(
                  template: _value(),
                  content: '[Example history]',
                  locale: Localizations.localeOf(context).toLanguageTag(),
                  targetTokens: 4096,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
