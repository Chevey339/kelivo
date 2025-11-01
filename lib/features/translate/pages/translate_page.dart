import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';

import '../../../icons/lucide_adapter.dart' as lucide;
import '../../../l10n/app_localizations.dart';
import '../../../utils/brand_assets.dart';
import '../../../core/providers/settings_provider.dart';
import '../../../core/providers/assistant_provider.dart';
import '../../../core/services/api/chat_api_service.dart';
import '../../../shared/widgets/ios_tactile.dart';
import '../../../shared/widgets/snackbar.dart';
import '../../settings/widgets/language_select_sheet.dart' show LanguageOption, supportedLanguages, showLanguageSelector;
import '../../../core/services/haptics.dart';
import '../../model/widgets/model_select_sheet.dart' show showModelSelector;

class TranslatePage extends StatefulWidget {
  const TranslatePage({super.key});

  @override
  State<TranslatePage> createState() => _TranslatePageState();
}

class _TranslatePageState extends State<TranslatePage> {
  final TextEditingController _src = TextEditingController();
  final TextEditingController _dst = TextEditingController();
  LanguageOption? _lang;
  String? _providerKey;
  String? _modelId;
  StreamSubscription? _sub;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _initDefaults());
  }

  @override
  void dispose() {
    _sub?.cancel();
    _src.dispose();
    _dst.dispose();
    super.dispose();
  }

  void _initDefaults() {
    final settings = context.read<SettingsProvider>();
    final assistant = context.read<AssistantProvider>().currentAssistant;
    // default language
    final lc = Localizations.localeOf(context).languageCode.toLowerCase();
    setState(() {
      if (lc.startsWith('zh')) {
        _lang = supportedLanguages.firstWhere((e) => e.code == 'en', orElse: () => supportedLanguages.first);
      } else {
        _lang = supportedLanguages.firstWhere((e) => e.code == 'zh-CN', orElse: () => supportedLanguages.first);
      }
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
    }
  }

  Future<void> _pickLanguage() async {
    if (_loading) return;
    final lang = await showLanguageSelector(context);
    if (!mounted || lang == null) return;
    if (lang.code == '__clear__') {
      setState(() => _dst.clear());
      return;
    }
    setState(() => _lang = lang);
  }

  Future<void> _translate() async {
    final l10n = AppLocalizations.of(context)!;
    final txt = _src.text.trim();
    if (txt.isEmpty) return;
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
      _dst.text = '';
    });

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
          _dst.text += chunk.content;
        },
        onError: (e) {
          if (!mounted) return;
          setState(() => _loading = false);
          showAppSnackBar(context, message: l10n.homePageTranslateFailed(e.toString()), type: NotificationType.error);
        },
        onDone: () {
          if (!mounted) return;
          setState(() => _loading = false);
        },
        cancelOnError: true,
      );
    } catch (e) {
      setState(() => _loading = false);
      showAppSnackBar(context, message: l10n.homePageTranslateFailed(e.toString()), type: NotificationType.error);
    }
  }

  Future<void> _stop() async {
    try { await _sub?.cancel(); } catch (_) {}
    if (mounted) setState(() => _loading = false);
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
    setState(() { _src.clear(); _dst.clear(); });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final asset = (_modelId != null) ? BrandAssets.assetForName(_modelId!) : null;

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
                  return SvgPicture.asset(asset, width: 22, height: 22);
                }
                if (asset != null) {
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
                  child: TextField(
                    controller: _src,
                    keyboardType: TextInputType.multiline,
                    expands: true,
                    maxLines: null,
                    minLines: null,
                    decoration: const InputDecoration(
                      hintText: '输入要翻译的内容…',
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.fromLTRB(12, 8, 12, 12),
                    ),
                    contextMenuBuilder: (context, editableTextState) => const SizedBox.shrink(),
                    style: const TextStyle(fontSize: 15, height: 1.4),
                  ),
                ),
              ),
            ),
            // Output
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
                child: _Card(
                  child: TextField(
                    controller: _dst,
                    readOnly: true,
                    keyboardType: TextInputType.multiline,
                    maxLines: null,
                    expands: true,
                    decoration: const InputDecoration(
                      hintText: '翻译结果会显示在这里…',
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.fromLTRB(12, 6, 12, 12),
                    ),
                    enableInteractiveSelection: false,
                    contextMenuBuilder: (context, editableTextState) => const SizedBox.shrink(),
                    style: const TextStyle(fontSize: 15, height: 1.4),
                  ),
                ),
              ),
            ),
            // Bottom: language card + translate button
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 2, 16, 14),
              child: Row(
                children: [
                  Expanded(
                    child: IosCardPress(
                      borderRadius: BorderRadius.circular(12),
                      baseColor: Theme.of(context).cardColor,
                      onTap: _pickLanguage,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
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
                          Icon(lucide.Lucide.ChevronDown, size: 18, color: cs.onSurface.withOpacity(0.7)),
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
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
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
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant.withOpacity(0.25)),
      ),
      clipBehavior: Clip.antiAlias,
      child: child,
    );
  }
}

// Copy of the tactile back icon used on settings-like pages
class _TactileIconButton extends StatefulWidget {
  const _TactileIconButton({required this.icon, required this.color, required this.onTap, this.onLongPress, this.semanticLabel, this.size = 22, this.haptics = true});
  final IconData icon; final Color color; final VoidCallback onTap; final VoidCallback? onLongPress; final String? semanticLabel; final double size; final bool haptics;
  @override State<_TactileIconButton> createState() => _TactileIconButtonState();
}

class _TactileIconButtonState extends State<_TactileIconButton> {
  bool _pressed = false;
  @override
  Widget build(BuildContext context) {
    final base = widget.color; final pressColor = base.withOpacity(0.7);
    final icon = Icon(widget.icon, size: widget.size, color: _pressed ? pressColor : base, semanticLabel: widget.semanticLabel);
    return Semantics(
      button: true, label: widget.semanticLabel,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        onTap: () { if (widget.haptics) Haptics.light(); widget.onTap(); },
        onLongPress: widget.onLongPress == null ? null : () { if (widget.haptics) Haptics.light(); widget.onLongPress!.call(); },
        child: Padding(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6), child: icon),
      ),
    );
  }
}
