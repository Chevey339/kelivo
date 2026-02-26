import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:re_editor/re_editor.dart';

import '../icons/lucide_adapter.dart' as lucide;
import '../l10n/app_localizations.dart';
import '../utils/brand_assets.dart';
import '../core/providers/settings_provider.dart';
import '../core/providers/assistant_provider.dart';
import '../core/services/api/chat_api_service.dart';
import '../shared/widgets/snackbar.dart';
import '../shared/widgets/plain_text_code_editor.dart';
import '../features/model/widgets/model_select_sheet.dart' show showModelSelector;
import '../features/settings/widgets/language_select_sheet.dart' show LanguageOption, supportedLanguages;
import '../utils/re_editor_utils.dart';

class DesktopTranslatePage extends StatefulWidget {
  const DesktopTranslatePage({super.key});

  @override
  State<DesktopTranslatePage> createState() => _DesktopTranslatePageState();
}

class _DesktopTranslatePageState extends State<DesktopTranslatePage> {
  final CodeLineEditingController _source = CodeLineEditingController();
  final CodeLineEditingController _output = CodeLineEditingController();

  LanguageOption? _targetLang;
  String? _modelProviderKey;
  String? _modelId;

  StreamSubscription? _subscription;
  bool _translating = false;
  int _translateRunId = 0;

  @override
  void initState() {
    super.initState();
    // Defer initializing model defaults until first frame to ensure providers are ready
    WidgetsBinding.instance.addPostFrameCallback((_) => _initDefaults());
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _source.dispose();
    _output.dispose();
    super.dispose();
  }

  void _initDefaults() {
    final settings = context.read<SettingsProvider>();
    final assistant = context.read<AssistantProvider>().currentAssistant;

    final savedLang = _languageForCode(settings.translateTargetLang);
    final locale = Localizations.localeOf(context).languageCode.toLowerCase();
    final localeLang = locale.startsWith('zh') ? _languageForCode('zh-CN') : _languageForCode('en');
    setState(() {
      _targetLang = savedLang ?? localeLang ?? supportedLanguages.first;
    });

    // Default model: translate model -> assistant's chat model -> global default
    final providerKey = settings.translateModelProvider ?? assistant?.chatModelProvider ?? settings.currentModelProvider;
    final modelId = settings.translateModelId ?? assistant?.chatModelId ?? settings.currentModelId;
    setState(() {
      _modelProviderKey = providerKey;
      _modelId = modelId;
    });
  }

  LanguageOption? _languageForCode(String? code) {
    if (code == null || code.isEmpty) return null;
    try {
      return supportedLanguages.firstWhere((e) => e.code == code);
    } catch (_) {
      return null;
    }
  }

  Future<void> _onLanguageChanged(LanguageOption? lang) async {
    if (lang == null) return;
    setState(() => _targetLang = lang);
    await context.read<SettingsProvider>().setTranslateTargetLang(lang.code);
  }

  String _displayNameFor(AppLocalizations l10n, String code) {
    switch (code) {
      case 'zh-CN':
        return l10n.languageDisplaySimplifiedChinese;
      case 'en':
        return l10n.languageDisplayEnglish;
      case 'zh-TW':
        return l10n.languageDisplayTraditionalChinese;
      case 'ja':
        return l10n.languageDisplayJapanese;
      case 'ko':
        return l10n.languageDisplayKorean;
      case 'fr':
        return l10n.languageDisplayFrench;
      case 'de':
        return l10n.languageDisplayGerman;
      case 'it':
        return l10n.languageDisplayItalian;
      case 'es':
        return l10n.languageDisplaySpanish;
      default:
        return code;
    }
  }

  Future<void> _pickModel() async {
    if (_translating) return; // avoid switching mid-stream
    final sel = await showModelSelector(context);
    if (!mounted) return;
    if (sel != null) {
      setState(() {
        _modelProviderKey = sel.providerKey;
        _modelId = sel.modelId;
      });
      // Persist translate model selection so it’s remembered next time
      await context.read<SettingsProvider>().setTranslateModel(sel.providerKey, sel.modelId);
    }
  }

  Future<void> _startTranslate() async {
    if (_translating) return;
    final l10n = AppLocalizations.of(context)!;
    final settings = context.read<SettingsProvider>();

    final text = _source.text.trim();
    if (text.isEmpty) return;
    await _subscription?.cancel();
    _subscription = null;
    if (!mounted) return;

    final providerKey = _modelProviderKey;
    final modelId = _modelId;
    if (providerKey == null || modelId == null) {
      showAppSnackBar(context, message: l10n.homePagePleaseSetupTranslateModel, type: NotificationType.warning);
      return;
    }

    final cfg = settings.getProviderConfig(providerKey);

    final lang = _targetLang ?? supportedLanguages.first;
    final prompt = settings.translatePrompt
        .replaceAll('{source_text}', text)
        .replaceAll('{target_lang}', _displayNameFor(l10n, lang.code));

    setState(() {
      _translating = true;
      _output.value = const CodeLineEditingValue.empty();
    });

    final runId = ++_translateRunId;
    final buffer = StringBuffer();
    Timer? flushTimer;
    void flushNow() {
      if (!mounted || runId != _translateRunId) return;
      _setOutputText(buffer.toString());
    }

    void scheduleFlush() {
      if (flushTimer?.isActive ?? false) return;
      flushTimer = Timer(const Duration(milliseconds: 80), () {
        flushTimer = null;
        flushNow();
      });
    }

    try {
      final stream = ChatApiService.sendMessageStream(
        config: cfg,
        modelId: modelId,
        messages: [
          {'role': 'user', 'content': prompt},
        ],
      );

      _subscription = stream.listen(
        (chunk) {
          // live update; remove leading whitespace on first chunk to avoid top gap
          if (runId != _translateRunId) return;
          final s = chunk.content;
          if (buffer.isEmpty) {
            buffer.write(s.replaceFirst(RegExp(r'^\s+'), ''));
          } else {
            buffer.write(s);
          }
          scheduleFlush();
        },
        onDone: () {
          if (!mounted || runId != _translateRunId) return;
          flushTimer?.cancel();
          flushNow();
          _subscription = null;
          setState(() => _translating = false);
        },
        onError: (e) {
          if (!mounted || runId != _translateRunId) return;
          flushTimer?.cancel();
          flushNow();
          _subscription = null;
          setState(() => _translating = false);
          showAppSnackBar(context, message: l10n.homePageTranslateFailed(e.toString()), type: NotificationType.error);
        },
        cancelOnError: true,
      );
    } catch (e) {
      _subscription = null;
      if (!mounted) return;
      setState(() => _translating = false);
      showAppSnackBar(context, message: l10n.homePageTranslateFailed(e.toString()), type: NotificationType.error);
    }
  }

  Future<void> _stopTranslate() async {
    try {
      await _subscription?.cancel();
    } catch (_) {}
    _subscription = null;
    _translateRunId++;
    if (mounted) setState(() => _translating = false);
  }

  void _setOutputText(String text) {
    _output.setTextSafely(text);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;

    final topBar = SizedBox(
      height: 36,
      child: Align(
        alignment: Alignment.centerLeft,
        child: Padding(
          padding: const EdgeInsets.only(left: 16, top: 8),
          child: Text(
            l10n.desktopNavTranslateTooltip, // 显示“翻译”
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: cs.onSurface,
              decoration: TextDecoration.none,
            ),
          ),
        ),
      ),
    );

    final brandAsset = (_modelId != null) ? BrandAssets.assetForName(_modelId!) : null;

    return Material(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          topBar,
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1200),
                  child: Column(
                    children: [
                      SizedBox(
                        height: 40,
                        child: Row(
                          children: [
                            // Language dropdown
                            _LanguageDropdown(
                              value: _targetLang,
                              onChanged: _translating ? null : (v) => _onLanguageChanged(v),
                            ),
                            const SizedBox(width: 8),
                            // Translate / Stop button with animation
                            _TranslateButton(
                              translating: _translating,
                              onTranslate: _startTranslate,
                              onStop: _stopTranslate,
                            ),
                            const Spacer(),
                            // Model picker button (brand icon)
                            _ModelPickerButton(
                              asset: brandAsset,
                              modelId: _modelId,
                              onTap: _pickModel,
                              enabled: !_translating,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Two large rounded rectangles: input (left) and output (right)
                      Expanded(
                        child: Row(
                          children: [
                            Expanded(
                              child: _PaneContainer(
                                overlay: _PaneActionButton(
                                  icon: lucide.Lucide.Eraser,
                                  label: '清空',
                                  onTap: () async {
                                    // TODO: Replace hard-coded label with AppLocalizations (i18n).
                                    // TODO: Confirm before clearing when either source or output is non-empty to prevent accidental data loss.
                                    if (_translating || _subscription != null) {
                                      await _stopTranslate();
                                    }
                                    _source.value = const CodeLineEditingValue.empty();
                                    _output.value = const CodeLineEditingValue.empty();
                                  },
                                ),
                                child: PlainTextCodeEditor(
                                  controller: _source,
                                  autofocus: false,
                                  hint: l10n.translatePageInputHint,
                                  padding: const EdgeInsets.all(14),
                                  fontSize: 14.5,
                                  fontHeight: 1.4,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _PaneContainer(
                                overlay: _PaneActionButton(
                                  icon: lucide.Lucide.Copy,
                                  label: '复制',
                                  onTap: () async {
                                    // TODO: Replace hard-coded label with AppLocalizations (i18n).
                                    // TODO: Handle Clipboard.setData failures and provide user feedback when copying fails.
                                    await Clipboard.setData(ClipboardData(text: _output.text));
                                    if (!context.mounted) return;
                                    showAppSnackBar(
                                      context,
                                      message: AppLocalizations.of(context)!.chatMessageWidgetCopiedToClipboard,
                                      type: NotificationType.success,
                                    );
                                  },
                                ),
                                child: PlainTextCodeEditor(
                                  controller: _output,
                                  readOnly: true,
                                  autofocus: false,
                                  hint: l10n.translatePageOutputHint,
                                  padding: const EdgeInsets.all(14),
                                  fontSize: 14.5,
                                  fontHeight: 1.4,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PaneContainer extends StatelessWidget {
  const _PaneContainer({required this.child, this.overlay});
  final Widget child;
  final Widget? overlay;
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Stack(
      children: [
        Container(
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.18)),
          ),
          clipBehavior: Clip.antiAlias,
          child: child,
        ),
        if (overlay != null)
          Positioned(
            top: 8,
            right: 8,
            child: overlay!,
          ),
      ],
    );
  }
}

class _LanguageDropdown extends StatefulWidget {
  const _LanguageDropdown({required this.value, required this.onChanged});
  final LanguageOption? value;
  final ValueChanged<LanguageOption?>? onChanged;

  @override
  State<_LanguageDropdown> createState() => _LanguageDropdownState();
}

class _LanguageDropdownState extends State<_LanguageDropdown> {
  bool _hover = false;
  bool _open = false;
  final LayerLink _link = LayerLink();
  final GlobalKey _triggerKey = GlobalKey();
  OverlayEntry? _entry;

  void _toggle() {
    if (_open) {
      _close();
    } else {
      _openMenu();
    }
  }

  void _close() {
    _entry?.remove();
    _entry = null;
    if (mounted) setState(() => _open = false);
  }

  void _openMenu() {
    if (_entry != null) return;
    final rb = _triggerKey.currentContext?.findRenderObject() as RenderBox?;
    if (rb == null) return;
    final triggerSize = rb.size;
    final triggerWidth = triggerSize.width;

    _entry = OverlayEntry(builder: (ctx) {
      final isDark = Theme.of(ctx).brightness == Brightness.dark;
      final usePure = Provider.of<SettingsProvider>(ctx, listen: false).usePureBackground;
      final bgColor = usePure
          ? (isDark ? Colors.black : Colors.white)
          : (isDark ? const Color(0xFF1C1C1E) : Colors.white);

      return Stack(children: [
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: _close,
            child: const SizedBox.expand(),
          ),
        ),
        CompositedTransformFollower(
          link: _link,
          showWhenUnlinked: false,
          offset: Offset(0, triggerSize.height + 6),
          child: _LangDropdownOverlay(
            width: triggerWidth,
            backgroundColor: bgColor,
            onClose: _close,
            onSelected: (opt) {
              widget.onChanged?.call(opt);
              _close();
            },
            selected: widget.value ?? supportedLanguages.first,
          ),
        ),
      ]);
    });
    final overlay = Overlay.maybeOf(context);
    if (overlay == null) {
      _entry = null;
      return;
    }
    overlay.insert(_entry!);
    if (mounted) {
      setState(() => _open = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final baseBorder = cs.outlineVariant.withValues(alpha: 0.18);
    final hoverBorder = cs.primary; // hover/focus border
    final borderColor = _open || _hover ? hoverBorder : baseBorder;

    final selected = widget.value ?? supportedLanguages.first;
    final label = _displayNameFor(l10n, selected.code);

    return CompositedTransformTarget(
      link: _link,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: GestureDetector(
          onTap: _toggle,
          child: AnimatedContainer(
            key: _triggerKey,
            duration: const Duration(milliseconds: 120),
            curve: Curves.easeOutCubic,
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 4),
            constraints: const BoxConstraints(minWidth: 150, minHeight: 40),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF141414) : Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: borderColor, width: 1),
              boxShadow: _open
                  ? [
                      BoxShadow(
                        color: cs.primary.withValues(alpha: 0.10),
                        blurRadius: 0,
                        spreadRadius: 2,
                      ),
                    ]
                  : null,
            ),
            child: Stack(
              alignment: Alignment.centerLeft,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(selected.flag, style: const TextStyle(fontSize: 16, height: 1)),
                    const SizedBox(width: 8),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 240),
                      child: Text(
                        label,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14,
                          color: cs.onSurface.withValues(alpha: 0.88),
                        ),
                      ),
                    ),
                    const SizedBox(width: 24),
                  ],
                ),
                Positioned.fill(
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: AnimatedRotation(
                      turns: _open ? 0.5 : 0.0,
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeOutCubic,
                      child: Icon(
                        lucide.Lucide.ChevronDown,
                        size: 14,
                        color: cs.onSurface.withValues(alpha: 0.45),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _displayNameFor(AppLocalizations l10n, String code) {
    switch (code) {
      case 'zh-CN':
        return l10n.languageDisplaySimplifiedChinese;
      case 'en':
        return l10n.languageDisplayEnglish;
      case 'zh-TW':
        return l10n.languageDisplayTraditionalChinese;
      case 'ja':
        return l10n.languageDisplayJapanese;
      case 'ko':
        return l10n.languageDisplayKorean;
      case 'fr':
        return l10n.languageDisplayFrench;
      case 'de':
        return l10n.languageDisplayGerman;
      case 'it':
        return l10n.languageDisplayItalian;
      case 'es':
        return l10n.languageDisplaySpanish;
      default:
        return code;
    }
  }
}

class _LangDropdownOverlay extends StatefulWidget {
  const _LangDropdownOverlay({
    required this.width,
    required this.backgroundColor,
    required this.onClose,
    required this.onSelected,
    required this.selected,
  });

  final double width;
  final Color backgroundColor;
  final VoidCallback onClose;
  final ValueChanged<LanguageOption> onSelected;
  final LanguageOption selected;

  @override
  State<_LangDropdownOverlay> createState() => _LangDropdownOverlayState();
}

class _LangDropdownOverlayState extends State<_LangDropdownOverlay> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _opacity;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 200));
    _opacity = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic);
    _slide = Tween<Offset>(begin: const Offset(0, -0.08), end: Offset.zero).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    WidgetsBinding.instance.addPostFrameCallback((_) => _ctrl.forward());
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final borderColor = cs.outlineVariant.withValues(alpha: 0.12);
    // divider removed

    final filtered = supportedLanguages;

    return FadeTransition(
      opacity: _opacity,
      child: SlideTransition(
        position: _slide,
        child: Material(
          color: Colors.transparent,
          child: Container(
            constraints: BoxConstraints(minWidth: widget.width, maxWidth: widget.width),
            decoration: BoxDecoration(
              color: widget.backgroundColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: borderColor, width: 0.5),
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: isDark ? 0.32 : 0.08), blurRadius: 16, offset: const Offset(0, 6)),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Options
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 350),
                  child: Scrollbar(
                    thickness: 6,
                    radius: const Radius.circular(3),
                    child: ListView.builder(
                      padding: const EdgeInsets.fromLTRB(6, 6, 6, 6),
                      shrinkWrap: true,
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final item = filtered[index];
                        final selected = item.code == widget.selected.code;
                        return _LangOptionTile(
                          option: item,
                          selected: selected,
                          onTap: () => widget.onSelected(item),
                        );
                      },
                    ),
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

// (search removed as per requirement)

class _LangOptionTile extends StatefulWidget {
  const _LangOptionTile({required this.option, required this.selected, required this.onTap});
  final LanguageOption option;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_LangOptionTile> createState() => _LangOptionTileState();
}

class _LangOptionTileState extends State<_LangOptionTile> {
  bool _hover = false;
  bool _active = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = widget.selected
        ? cs.primary.withValues(alpha: 0.12)
        : (_hover ? (isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.04)) : Colors.transparent);

    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => setState(() => _active = true),
        onTapCancel: () => setState(() => _active = false),
        onTapUp: (_) => setState(() => _active = false),
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _active ? 0.98 : 1.0,
          duration: const Duration(milliseconds: 100),
          curve: Curves.easeOut,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            curve: Curves.easeOutCubic,
            margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
            child: Row(
              children: [
                Text(widget.option.flag, style: const TextStyle(fontSize: 16, height: 1)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _localizedLabel(AppLocalizations.of(context)!, widget.option.code),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 14, color: cs.onSurface.withValues(alpha: 0.88), fontWeight: widget.selected ? FontWeight.w600 : FontWeight.w400),
                  ),
                ),
                const SizedBox(width: 8),
              Opacity(
                opacity: widget.selected ? 1 : 0,
                child: Icon(lucide.Lucide.Check, size: 14, color: cs.primary),
              ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _localizedLabel(AppLocalizations l10n, String code) {
    switch (code) {
      case 'zh-CN':
        return l10n.languageDisplaySimplifiedChinese;
      case 'en':
        return l10n.languageDisplayEnglish;
      case 'zh-TW':
        return l10n.languageDisplayTraditionalChinese;
      case 'ja':
        return l10n.languageDisplayJapanese;
      case 'ko':
        return l10n.languageDisplayKorean;
      case 'fr':
        return l10n.languageDisplayFrench;
      case 'de':
        return l10n.languageDisplayGerman;
      case 'it':
        return l10n.languageDisplayItalian;
      case 'es':
        return l10n.languageDisplaySpanish;
      default:
        return code;
    }
  }
}

class _TranslateButton extends StatefulWidget {
  const _TranslateButton({required this.translating, required this.onTranslate, required this.onStop});
  final bool translating;
  final VoidCallback onTranslate;
  final VoidCallback onStop;

  @override
  State<_TranslateButton> createState() => _TranslateButtonState();
}

class _TranslateButtonState extends State<_TranslateButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cs = Theme.of(context).colorScheme;
    final fg = isDark ? Colors.black : Colors.white;
    final base = cs.primary;
    final bg = _hover ? base.withValues(alpha: 0.92) : base;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.translating ? widget.onStop : widget.onTranslate,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            transitionBuilder: (child, anim) => ScaleTransition(scale: anim, child: FadeTransition(opacity: anim, child: child)),
            child: widget.translating
                ? Row(
                    key: const ValueKey('stop'),
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SvgPicture.asset('assets/icons/stop.svg', width: 16, height: 16, colorFilter: ColorFilter.mode(fg, BlendMode.srcIn)),
                      const SizedBox(width: 6),
                      // TODO: Replace hard-coded label with AppLocalizations (i18n).
                      Text('终止', style: TextStyle(color: fg, fontSize: 13.5, fontWeight: FontWeight.w600)),
                    ],
                  )
                : Row(
                    key: const ValueKey('translate'),
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(lucide.Lucide.Languages, size: 16, color: fg),
                      const SizedBox(width: 6),
                      // TODO: Replace hard-coded label with AppLocalizations (i18n).
                      Text('翻译', style: TextStyle(color: fg, fontSize: 13.5, fontWeight: FontWeight.w600)),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

class _ModelPickerButton extends StatelessWidget {
  const _ModelPickerButton({required this.asset, required this.modelId, required this.onTap, required this.enabled});
  final String? asset;
  final String? modelId;
  final VoidCallback onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = enabled ? (isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.05)) : Colors.transparent;
    return MouseRegion(
      cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      child: GestureDetector(
        onTap: enabled ? onTap : null,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (asset != null)
                () {
                  if (asset!.toLowerCase().endsWith('.svg')) {
                    return SvgPicture.asset(asset!, width: 18, height: 18);
                  }
                  return Image.asset(asset!, width: 18, height: 18);
                }()
              else
                Icon(lucide.Lucide.Bot, size: 18, color: cs.onSurface.withValues(alpha: 0.9)),
              if (modelId != null) ...[
                const SizedBox(width: 8),
                Text(
                  modelId!,
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500, color: cs.onSurface.withValues(alpha: 0.85)),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _PaneActionButton extends StatefulWidget {
  const _PaneActionButton({required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  State<_PaneActionButton> createState() => _PaneActionButtonState();
}

class _PaneActionButtonState extends State<_PaneActionButton> {
  bool _hover = false;
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = _hover
        ? (isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.06))
        : Colors.transparent;
    final fg = cs.onSurface.withValues(alpha: 0.9);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: Semantics(
        tooltip: widget.label,
        button: true,
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            curve: Curves.easeOutCubic,
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(widget.icon, size: 16, color: fg),
          ),
        ),
      ),
    );
  }
}
