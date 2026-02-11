import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import 'package:re_editor/re_editor.dart';

import '../../../icons/lucide_adapter.dart' as lucide;
import '../../../l10n/app_localizations.dart';
import '../../../utils/brand_assets.dart';
import '../../../core/providers/settings_provider.dart';
import '../../../core/providers/assistant_provider.dart';
import '../../../core/services/api/chat_api_service.dart';
import '../../../shared/widgets/ios_tactile.dart';
import '../../../shared/widgets/snackbar.dart';
import '../../../shared/widgets/plain_text_code_editor.dart';
import '../../settings/widgets/language_select_sheet.dart' show LanguageOption, supportedLanguages, showLanguageSelector;
import '../../../core/services/haptics.dart';
import '../../model/widgets/model_select_sheet.dart' show showModelSelector;
import '../../../utils/re_editor_utils.dart';

class TranslatePage extends StatefulWidget {
  const TranslatePage({super.key});

  @override
  State<TranslatePage> createState() => _TranslatePageState();
}

class _TranslatePageState extends State<TranslatePage> {
  final CodeLineEditingController _src = CodeLineEditingController();
  final CodeLineEditingController _dst = CodeLineEditingController();
  LanguageOption? _lang;
  String? _providerKey;
  String? _modelId;
  StreamSubscription? _sub;
  bool _loading = false;
  int _translateRunId = 0;
  Timer? _flushTimer;
  StringBuffer? _pendingBuffer;
  int _pendingRunId = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _initDefaults());
  }

  @override
  void dispose() {
    _flushTimer?.cancel();
    _sub?.cancel();
    _src.dispose();
    _dst.dispose();
    super.dispose();
  }

  void _initDefaults() {
    final settings = context.read<SettingsProvider>();
    final assistant = context.read<AssistantProvider>().currentAssistant;
    final lc = Localizations.localeOf(context).languageCode.toLowerCase();
    final savedLang = _languageForCode(settings.translateTargetLang);
    final localeLang = lc.startsWith('zh') ? _languageForCode('zh-CN') : _languageForCode('en');
    setState(() {
      _lang = savedLang ?? localeLang ?? supportedLanguages.first;
      _providerKey = settings.translateModelProvider ?? assistant?.chatModelProvider ?? settings.currentModelProvider;
      _modelId = settings.translateModelId ?? assistant?.chatModelId ?? settings.currentModelId;
    });
  }

  Future<void> _pickModel() async {
    if (_loading) return;
    final sel = await showModelSelector(context);
    if (!mounted) return;
    if (sel != null) {
      setState(() {
        _providerKey = sel.providerKey;
        _modelId = sel.modelId;
      });
      // Persist translate model selection so it’s remembered next time
      await context.read<SettingsProvider>().setTranslateModel(sel.providerKey, sel.modelId);
    }
  }

  Future<void> _pickLanguage() async {
    if (_loading) return;
    final lang = await showLanguageSelector(context);
    if (!mounted || lang == null) return;
    if (lang.code == '__clear__') {
      setState(() {
        _lang = null;
        _dst.value = const CodeLineEditingValue.empty();
      });
      await context.read<SettingsProvider>().resetTranslateTargetLang();
      return;
    }
    setState(() => _lang = lang);
    await context.read<SettingsProvider>().setTranslateTargetLang(lang.code);
  }

  Future<void> _translate() async {
    final txt = _src.text.trim();
    if (txt.isEmpty) return;
    if (_loading) {
      await _stop();
      if (!mounted) return;
    }
    await _sub?.cancel();
    _sub = null;
    if (!mounted) return;
    final l10n = AppLocalizations.of(context)!;
    final pk = _providerKey;
    final mid = _modelId;
    if (pk == null || mid == null) {
      showAppSnackBar(context, message: l10n.homePagePleaseSetupTranslateModel, type: NotificationType.warning);
      return;
    }
    final settings = context.read<SettingsProvider>();
    final cfg = settings.getProviderConfig(pk);
    final p = settings.translatePrompt
        .replaceAll('{source_text}', txt)
        .replaceAll('{target_lang}', _displayNameFor(l10n, (_lang ?? supportedLanguages.first).code));

    setState(() {
      _loading = true;
      _dst.value = const CodeLineEditingValue.empty();
    });

    final runId = ++_translateRunId;
    final buffer = StringBuffer();
    _registerPendingBuffer(buffer, runId);
    void flushNow() {
      if (!mounted || runId != _translateRunId) return;
      _setOutputText(buffer.toString());
    }

    void scheduleFlush() {
      if (_flushTimer?.isActive ?? false) return;
      _flushTimer = Timer(const Duration(milliseconds: 80), () {
        _flushTimer = null;
        flushNow();
      });
    }

    try {
      final stream = ChatApiService.sendMessageStream(
        config: cfg,
        modelId: mid,
        messages: [
          {'role': 'user', 'content': p},
        ],
      );
      _sub = stream.listen(
        (chunk) {
          if (runId != _translateRunId) return;
          final s = chunk.content;
          if (buffer.isEmpty) {
            // Remove any leading whitespace/newlines from the first chunk to avoid top gap
            final cleaned = s.replaceFirst(RegExp(r'^\s+'), '');
            buffer.write(cleaned);
          } else {
            buffer.write(s);
          }
          scheduleFlush();
        },
        onError: (e) {
          if (!mounted || runId != _translateRunId) return;
          _flushPending();
          _clearPendingBuffer();
          _sub = null;
          setState(() => _loading = false);
          // TODO: Avoid showing raw exception details to users; log error details and show a generic message.
          showAppSnackBar(context, message: l10n.homePageTranslateFailed(e.toString()), type: NotificationType.error);
        },
        onDone: () {
          if (!mounted || runId != _translateRunId) return;
          _flushPending();
          _clearPendingBuffer();
          _sub = null;
          setState(() => _loading = false);
        },
        cancelOnError: true,
      );
    } catch (e) {
      _sub = null;
      if (!mounted) return;
      setState(() => _loading = false);
      // TODO: Avoid showing raw exception details to users; log error details and show a generic message.
      showAppSnackBar(context, message: l10n.homePageTranslateFailed(e.toString()), type: NotificationType.error);
    }
  }

  void _setOutputText(String text) {
    _dst.setTextSafely(text);
  }

  Future<void> _stop() async {
    _flushPending();
    _clearPendingBuffer();
    try { await _sub?.cancel(); } catch (_) {}
    _sub = null;
    _translateRunId++;
    if (mounted) setState(() => _loading = false);
  }

  void _registerPendingBuffer(StringBuffer buffer, int runId) {
    _flushTimer?.cancel();
    _flushTimer = null;
    _pendingBuffer = buffer;
    _pendingRunId = runId;
  }

  void _flushPending() {
    final buffer = _pendingBuffer;
    if (buffer == null) return;
    _flushTimer?.cancel();
    _flushTimer = null;
    if (mounted && _pendingRunId == _translateRunId) {
      _setOutputText(buffer.toString());
    }
  }

  void _clearPendingBuffer() {
    _flushTimer?.cancel();
    _flushTimer = null;
    _pendingBuffer = null;
    _pendingRunId = 0;
  }

  LanguageOption? _languageForCode(String? code) {
    if (code == null || code.isEmpty) return null;
    try {
      return supportedLanguages.firstWhere((e) => e.code == code);
    } catch (_) {
      return null;
    }
  }

  String _displayNameFor(AppLocalizations l10n, String code) {
    switch (code) {
      case 'zh-CN': return l10n.languageDisplaySimplifiedChinese;
      case 'en': return l10n.languageDisplayEnglish;
      case 'zh-TW': return l10n.languageDisplayTraditionalChinese;
      case 'ja': return l10n.languageDisplayJapanese;
      case 'ko': return l10n.languageDisplayKorean;
      case 'fr': return l10n.languageDisplayFrench;
      case 'de': return l10n.languageDisplayGerman;
      case 'it': return l10n.languageDisplayItalian;
      case 'es': return l10n.languageDisplaySpanish;
      default: return code;
    }
  }

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData('text/plain');
    final text = data?.text ?? '';
    if (text.isEmpty) return;
    setState(() { _src.text = text; });
  }

  Future<void> _copyResult() async {
    await Clipboard.setData(ClipboardData(text: _dst.text));
    if (!mounted) return;
    showAppSnackBar(context, message: AppLocalizations.of(context)!.chatMessageWidgetCopiedToClipboard, type: NotificationType.success);
  }

  Future<void> _clearAll() async {
    await _stop();
    setState(() {
      _src.value = const CodeLineEditingValue.empty();
      _dst.value = const CodeLineEditingValue.empty();
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final asset = (_modelId != null) ? BrandAssets.assetForName(_modelId!) : null;
    final codeEditorPadding = const EdgeInsets.fromLTRB(12, 8, 12, 12);

    return Scaffold(
      appBar: AppBar(
        leading: Tooltip(
          message: l10n.settingsPageBackButton,
          child: _TactileIconButton(
            icon: lucide.Lucide.ArrowLeft,
            color: cs.onSurface,
            size: 22,
            onTap: () => Navigator.of(context).maybePop(),
          ),
        ),
        title: Text(l10n.desktopNavTranslateTooltip),
        actions: [
          // Paste
          Tooltip(
            message: l10n.translatePagePasteButton,
            child: Padding(
              padding: const EdgeInsets.only(right: 4),
              child: IosIconButton(
                icon: lucide.Lucide.Clipboard,
                size: 20,
                padding: const EdgeInsets.all(8),
                onTap: _pasteFromClipboard,
              ),
            ),
          ),
          // Copy result
          Tooltip(
            message: l10n.translatePageCopyResult,
            child: Padding(
              padding: const EdgeInsets.only(right: 4),
              child: IosIconButton(
                icon: lucide.Lucide.Copy,
                size: 20,
                padding: const EdgeInsets.all(8),
                onTap: _copyResult,
              ),
            ),
          ),
          // Clear all
          Tooltip(
            message: l10n.translatePageClearAll,
            child: Padding(
              padding: const EdgeInsets.only(right: 4),
              child: IosIconButton(
                icon: lucide.Lucide.Eraser,
                size: 20,
                padding: const EdgeInsets.all(8),
                onTap: _clearAll,
              ),
            ),
          ),
          // Model brand icon (keep original colors)
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: IosIconButton(
              padding: const EdgeInsets.all(8),
              builder: (color) {
                if (asset != null && asset.toLowerCase().endsWith('.svg')) {
                  // TODO: Add error handling/fallback UI if the brand asset path is invalid or the asset fails to load.
                  return SvgPicture.asset(asset, width: 22, height: 22);
                }
                if (asset != null) {
                  // TODO: Add error handling/fallback UI if the brand asset path is invalid or the asset fails to load.
                  return Image.asset(asset, width: 22, height: 22);
                }
                return Icon(lucide.Lucide.Bot, size: 22, color: color);
              },
              onTap: _pickModel,
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Input
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
              child: SizedBox(
                height: 200,
                child: _Card(
                  child: PlainTextCodeEditor(
                    controller: _src,
                    autofocus: false,
                    hint: l10n.translatePageInputHint,
                    padding: codeEditorPadding,
                    fontSize: 15,
                    fontHeight: 1.4,
                  ),
                ),
              ),
            ),
            // Output
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
                child: _Card(
                  child: PlainTextCodeEditor(
                    controller: _dst,
                    readOnly: true,
                    autofocus: false,
                    hint: l10n.translatePageOutputHint,
                    padding: codeEditorPadding,
                    fontSize: 15,
                    fontHeight: 1.4,
                  ),
                ),
              ),
            ),
            // Bottom: language card + translate button
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Row(
                children: [
                  Expanded(
                    child: IosCardPress(
                      borderRadius: BorderRadius.circular(12),
                      baseColor: Theme.of(context).cardColor,
                      onTap: _pickLanguage,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      child: Row(
                        children: [
                          Text((_lang ?? supportedLanguages.first).flag, style: const TextStyle(fontSize: 18)),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _displayNameFor(l10n, (_lang ?? supportedLanguages.first).code),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Icon(lucide.Lucide.ChevronDown, size: 18, color: cs.onSurface.withValues(alpha: 0.7)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  IosCardPress(
                    borderRadius: BorderRadius.circular(12),
                    baseColor: cs.primary,
                    pressedBlendStrength: isDark ? 0.08 : 0.06,
                    onTap: _loading ? _stop : _translate,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      transitionBuilder: (child, anim) => ScaleTransition(scale: anim, child: FadeTransition(opacity: anim, child: child)),
                      child: _loading
                          ? Row(
                              key: const ValueKey('stop'),
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                SvgPicture.asset('assets/icons/stop.svg', width: 18, height: 18, colorFilter: ColorFilter.mode(isDark ? Colors.black : Colors.white, BlendMode.srcIn)),
                                const SizedBox(width: 8),
                                Text(l10n.chatMessageWidgetStopTooltip, style: TextStyle(color: isDark ? Colors.black : Colors.white, fontWeight: FontWeight.w700)),
                              ],
                            )
                          : Row(
                              key: const ValueKey('go'),
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(lucide.Lucide.Languages, size: 18, color: isDark ? Colors.black : Colors.white),
                                const SizedBox(width: 8),
                                Text(l10n.chatMessageWidgetTranslateTooltip, style: TextStyle(color: isDark ? Colors.black : Colors.white, fontWeight: FontWeight.w700)),
                              ],
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.25)),
      ),
      clipBehavior: Clip.antiAlias,
      child: child,
    );
  }
}

// Copy of the tactile back icon used on settings-like pages
class _TactileIconButton extends StatefulWidget {
  const _TactileIconButton({required this.icon, required this.color, required this.onTap, this.size = 22});
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final double size;
  @override State<_TactileIconButton> createState() => _TactileIconButtonState();
}

class _TactileIconButtonState extends State<_TactileIconButton> {
  bool _pressed = false;
  @override
  Widget build(BuildContext context) {
    final base = widget.color; final pressColor = base.withValues(alpha: 0.7);
    final icon = Icon(widget.icon, size: widget.size, color: _pressed ? pressColor : base);
    return Semantics(
      button: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        onTap: () { Haptics.light(); widget.onTap(); },
        child: Padding(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6), child: icon),
      ),
    );
  }
}
