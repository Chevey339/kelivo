import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/settings_provider.dart';
import '../../../icons/lucide_adapter.dart';
import '../../../core/providers/tts_provider.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../../utils/brand_assets.dart';
import '../../../core/services/tts/network_tts.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/snackbar.dart';
import '../../../core/services/haptics.dart';

class TtsServicesPage extends StatelessWidget {
  const TtsServicesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        leading: Tooltip(
          message: l10n.ttsServicesPageBackButton,
          child: _TactileIconButton(
            icon: Lucide.ArrowLeft,
            color: cs.onSurface,
            size: 22,
            onTap: () => Navigator.of(context).maybePop(),
          ),
        ),
        title: Text(l10n.ttsServicesPageTitle),
        actions: [
          Tooltip(
            message: l10n.ttsServicesPageAddTooltip,
            child: _TactileIconButton(
              icon: Lucide.Plus,
              color: cs.onSurface,
              size: 22,
              onTap: () => _handleAddNetworkTts(context),
            ),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: Consumer2<TtsProvider, SettingsProvider>(
        builder: (context, tts, sp, _) {
          final services = sp.ttsServices;
          final available = tts.isAvailable && (tts.error == null);
          final titleText = l10n.ttsServicesPageSystemTtsTitle;
          final subText = available
              ? l10n.ttsServicesPageSystemTtsAvailableSubtitle
              : l10n.ttsServicesPageSystemTtsUnavailableSubtitle(
                  tts.error ??
                      l10n.ttsServicesPageSystemTtsUnavailableNotInitialized,
                );
          final systemLetter =
              (titleText.trim().isEmpty
                      ? '?'
                      : titleText.trim().substring(0, 1))
                  .toUpperCase();
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            children: [
              _header(context, l10n.ttsServicesPageTitle, first: true),
              _iosSectionCard(
                children: [
                  // System TTS as first row
                  _TactileRow(
                    pressedScale: 0.98,
                    haptics: false,
                    onTap: available
                        ? () async {
                            await sp.setTtsServiceSelected(-1);
                          }
                        : null,
                    builder: (pressed) {
                      final cs2 = Theme.of(context).colorScheme;
                      final base = cs2.onSurface.withValues(alpha: 0.9);
                      return _AnimatedPressColor(
                        pressed: pressed,
                        base: base,
                        builder: (c) {
                          final isDark =
                              Theme.of(context).brightness == Brightness.dark;
                          final overlay = pressed
                              ? (isDark
                                    ? Colors.black.withValues(alpha: 0.06)
                                    : Colors.white.withValues(alpha: 0.05))
                              : Colors.transparent;
                          return Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 11,
                            ),
                            child: Row(
                              children: [
                                _AvatarBadge(
                                  letter: systemLetter,
                                  overlay: overlay,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        titleText,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 15,
                                          color: c,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        subText,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: c.withValues(alpha: 0.7),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                _SmallTactileIcon(
                                  icon: Lucide.Volume2,
                                  baseColor: c,
                                  onTap: available
                                      ? () async {
                                          final demo = l10n
                                              .ttsServicesPageTestSpeechText;
                                          await tts.speakSystem(demo);
                                        }
                                      : () {},
                                  enabled: available,
                                ),
                                const SizedBox(width: 6),
                                _SmallTactileIcon(
                                  icon: Lucide.Settings2,
                                  baseColor: c,
                                  onTap: available
                                      ? () => _showSystemTtsConfig(context)
                                      : () {},
                                  enabled: available,
                                ),
                                const SizedBox(width: 8),
                                // right indicator: show check only when selected
                                Builder(
                                  builder: (_) {
                                    final sp2 = context
                                        .watch<SettingsProvider>();
                                    final sel = sp2.usingSystemTts;
                                    return sel
                                        ? Icon(Lucide.Check, size: 16, color: c)
                                        : const SizedBox(width: 16);
                                  },
                                ),
                              ],
                            ),
                          );
                        },
                      );
                    },
                  ),
                  if (services.isNotEmpty) _iosDivider(context),
                  if (services.isNotEmpty) ...[
                    for (int i = 0; i < services.length; i++) ...[
                      _NetworkTtsRowMobile(service: services[i], index: i),
                      if (i != services.length - 1) _iosDivider(context),
                    ],
                  ],
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

// --- iOS-style widgets and helpers ---

Widget _header(BuildContext context, String text, {bool first = false}) {
  final cs = Theme.of(context).colorScheme;
  return Padding(
    padding: EdgeInsets.fromLTRB(12, first ? 6 : 18, 12, 6),
    child: Text(
      text,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: cs.onSurface.withValues(alpha: 0.8),
      ),
    ),
  );
}

Future<void> _handleAddNetworkTts(BuildContext context) async {
  final sp = context.read<SettingsProvider>();
  final created = await _showAddNetworkTtsSheet(context);
  if (created == null) {
    return;
  }

  final list = List<TtsServiceOptions>.from(sp.ttsServices)..add(created);
  await sp.setTtsServices(list);
  if (sp.usingSystemTts) {
    await sp.setTtsServiceSelected(list.length - 1);
  }
}

class _TactileIconButton extends StatefulWidget {
  const _TactileIconButton({
    required this.icon,
    required this.color,
    required this.onTap,
    this.size = 22,
  });
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final double size;
  @override
  State<_TactileIconButton> createState() => _TactileIconButtonState();
}

class _TactileIconButtonState extends State<_TactileIconButton> {
  bool _pressed = false;
  @override
  Widget build(BuildContext context) {
    final base = widget.color;
    final pressColor = base.withValues(alpha: 0.7);
    final icon = Icon(
      widget.icon,
      size: widget.size,
      color: _pressed ? pressColor : base,
    );
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
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
          child: icon,
        ),
      ),
    );
  }
}

class _TactileRow extends StatefulWidget {
  const _TactileRow({
    required this.builder,
    this.onTap,
    this.pressedScale = 1.00,
    this.haptics = true,
  });
  final Widget Function(bool pressed) builder;
  final VoidCallback? onTap;
  final double pressedScale;
  final bool haptics;
  @override
  State<_TactileRow> createState() => _TactileRowState();
}

class _TactileRowState extends State<_TactileRow> {
  bool _pressed = false;
  void _set(bool v) {
    if (_pressed != v) setState(() => _pressed = v);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: widget.onTap == null ? null : (_) => _set(true),
      onTapUp: widget.onTap == null ? null : (_) => _set(false),
      onTapCancel: widget.onTap == null ? null : () => _set(false),
      onTap: widget.onTap == null
          ? null
          : () {
              if (widget.haptics &&
                  context.read<SettingsProvider>().hapticsOnListItemTap) {
                Haptics.soft();
              }
              widget.onTap!.call();
            },
      child: AnimatedScale(
        scale: _pressed ? widget.pressedScale : 1.0,
        duration: const Duration(milliseconds: 110),
        curve: Curves.easeOutCubic,
        child: widget.builder(_pressed),
      ),
    );
  }
}

class _AnimatedPressColor extends StatelessWidget {
  const _AnimatedPressColor({
    required this.pressed,
    required this.base,
    required this.builder,
  });
  final bool pressed;
  final Color base;
  final Widget Function(Color c) builder;
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final target = pressed
        ? (Color.lerp(base, isDark ? Colors.black : Colors.white, 0.55) ?? base)
        : base;
    return TweenAnimationBuilder<Color?>(
      tween: ColorTween(end: target),
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      builder: (context, color, _) => builder(color ?? base),
    );
  }
}

Widget _iosSectionCard({required List<Widget> children}) {
  return Builder(
    builder: (context) {
      final theme = Theme.of(context);
      final cs = theme.colorScheme;
      final isDark = theme.brightness == Brightness.dark;
      final Color bg = isDark
          ? Colors.white10
          : Colors.white.withValues(alpha: 0.96);
      return Container(
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: cs.outlineVariant.withValues(alpha: isDark ? 0.08 : 0.06),
            width: 0.6,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(children: children),
        ),
      );
    },
  );
}

Widget _iosDivider(BuildContext context) {
  final cs = Theme.of(context).colorScheme;
  return Divider(
    height: 6,
    thickness: 0.6,
    indent: 54,
    endIndent: 12,
    color: cs.outlineVariant.withValues(alpha: 0.18),
  );
}

class _SmallTactileIcon extends StatefulWidget {
  const _SmallTactileIcon({
    required this.icon,
    required this.onTap,
    this.enabled = true,
    this.baseColor,
  });
  final IconData icon;
  final VoidCallback onTap;
  final bool enabled;
  final Color? baseColor;
  @override
  State<_SmallTactileIcon> createState() => _SmallTactileIconState();
}

class _SmallTactileIconState extends State<_SmallTactileIcon> {
  bool _pressed = false;
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final base = widget.baseColor ?? cs.onSurface;
    final c = widget.enabled
        ? base.withValues(alpha: _pressed ? 0.6 : 0.9)
        : base.withValues(alpha: 0.3);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: widget.enabled ? (_) => setState(() => _pressed = true) : null,
      onTapUp: widget.enabled ? (_) => setState(() => _pressed = false) : null,
      onTapCancel: widget.enabled
          ? () => setState(() => _pressed = false)
          : null,
      onTap: widget.enabled
          ? () {
              Haptics.soft();
              widget.onTap();
            }
          : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
        child: Icon(widget.icon, size: 18, color: c),
      ),
    );
  }
}

class _AvatarBadge extends StatelessWidget {
  const _AvatarBadge({required this.letter, required this.overlay});
  final String letter;
  final Color overlay;
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseBg = isDark ? Colors.white10 : cs.primary.withValues(alpha: 0.1);
    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(color: baseBg, shape: BoxShape.circle),
          alignment: Alignment.center,
          child: Text(
            letter,
            style: TextStyle(
              color: cs.primary,
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
          ),
        ),
        if (overlay != Colors.transparent)
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(color: overlay, shape: BoxShape.circle),
          ),
      ],
    );
  }
}

class _AvatarBrandBadge extends StatelessWidget {
  const _AvatarBrandBadge({required this.name, required this.overlay});
  final String name;
  final Color overlay;
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseBg = isDark ? Colors.white10 : cs.primary.withValues(alpha: 0.1);
    final asset =
        BrandAssets.assetForName(name) ??
        BrandAssets.assetForName(name.split(' ').first);
    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(color: baseBg, shape: BoxShape.circle),
          alignment: Alignment.center,
          child: asset == null
              ? Text(
                  (name.isEmpty ? '?' : name[0]).toUpperCase(),
                  style: TextStyle(
                    color: cs.primary,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                )
              : (asset.endsWith('.svg')
                    ? SvgPicture.asset(asset, width: 20, height: 20)
                    : Image.asset(
                        asset,
                        width: 20,
                        height: 20,
                        fit: BoxFit.contain,
                      )),
        ),
        if (overlay != Colors.transparent)
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(color: overlay, shape: BoxShape.circle),
          ),
      ],
    );
  }
}

class _NetworkTtsRowMobile extends StatefulWidget {
  const _NetworkTtsRowMobile({required this.service, required this.index});
  final TtsServiceOptions service;
  final int index;
  @override
  State<_NetworkTtsRowMobile> createState() => _NetworkTtsRowMobileState();
}

class _NetworkTtsRowMobileState extends State<_NetworkTtsRowMobile> {
  bool _testing = false;
  String? _error;
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final displayName = widget.service.name.trim().isEmpty
        ? networkTtsKindDisplayName(widget.service.kind)
        : widget.service.name.trim();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _TactileRow(
          pressedScale: 0.98,
          haptics: false,
          onTap: () async => context
              .read<SettingsProvider>()
              .setTtsServiceSelected(widget.index),
          builder: (pressed) {
            final base = cs.onSurface.withValues(alpha: 0.9);
            return _AnimatedPressColor(
              pressed: pressed,
              base: base,
              builder: (c) {
                final isDark = Theme.of(context).brightness == Brightness.dark;
                final overlay = pressed
                    ? (isDark
                          ? Colors.black.withValues(alpha: 0.06)
                          : Colors.white.withValues(alpha: 0.05))
                    : Colors.transparent;
                return Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 11,
                  ),
                  child: Row(
                    children: [
                      _AvatarBrandBadge(name: displayName, overlay: overlay),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          displayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 15,
                            color: c,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      _SmallTactileIcon(
                        icon: Lucide.Settings2,
                        baseColor: c,
                        onTap: () async {
                          final sp = context.read<SettingsProvider>();
                          final updated = await _showEditNetworkTtsSheet(
                            context,
                            widget.service,
                          );
                          if (updated != null) {
                            final list = List<TtsServiceOptions>.from(
                              sp.ttsServices,
                            );
                            list[widget.index] = updated;
                            await sp.setTtsServices(list);
                          }
                        },
                      ),
                      const SizedBox(width: 6),
                      _SmallTactileIcon(
                        icon: _testing ? Lucide.Loader : Lucide.Volume2,
                        baseColor: c,
                        onTap: () async {
                          setState(() {
                            _testing = true;
                            _error = null;
                          });
                          final demo = AppLocalizations.of(
                            context,
                          )!.ttsServicesPageTestSpeechText;
                          final err = await context
                              .read<TtsProvider>()
                              .testNetworkService(widget.service, demo);
                          if (!mounted) return;
                          setState(() {
                            _testing = false;
                            _error = err;
                          });
                        },
                      ),
                      const SizedBox(width: 6),
                      _SmallTactileIcon(
                        icon: Lucide.Trash2,
                        baseColor: c,
                        onTap: () async {
                          final sp = context.read<SettingsProvider>();
                          final list = List<TtsServiceOptions>.from(
                            sp.ttsServices,
                          );
                          list.removeAt(widget.index);
                          await sp.setTtsServices(list);
                          var idx = sp.ttsServiceSelected;
                          if (idx >= list.length) {
                            idx = list.isEmpty ? -1 : list.length - 1;
                          }
                          await sp.setTtsServiceSelected(idx);
                        },
                      ),
                      const SizedBox(width: 8),
                      Builder(
                        builder: (_) {
                          final sp2 = context.watch<SettingsProvider>();
                          final sel = (sp2.ttsServiceSelected == widget.index);
                          return sel
                              ? Icon(Lucide.Check, size: 16, color: c)
                              : const SizedBox(width: 16);
                        },
                      ),
                    ],
                  ),
                );
              },
            );
          },
        ),
        if (_error != null && _error!.isNotEmpty) ...[
          const SizedBox(height: 6),
          _ErrorInlineMobile(message: _error!),
        ],
      ],
    );
  }
}

class _ErrorInlineMobile extends StatelessWidget {
  const _ErrorInlineMobile({required this.message});
  final String message;
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final oneLine = message.replaceAll('\n', ' ');
    return Container(
      decoration: BoxDecoration(
        color: cs.error.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: cs.error.withValues(alpha: 0.3), width: 0.6),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              oneLine,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12, color: cs.error),
            ),
          ),
          const SizedBox(width: 8),
          TextButton(
            onPressed: () => _showMobileErrorDetails(context, message),
            child: Text(l10n.ttsServicesViewDetailsButton),
          ),
        ],
      ),
    );
  }
}

void _showMobileErrorDetails(BuildContext context, String message) {
  final cs = Theme.of(context).colorScheme;
  final l10n = AppLocalizations.of(context)!;
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: cs.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (ctx) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: cs.onSurface.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  l10n.ttsServicesDialogErrorTitle,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              SelectableText(
                message,
                style: TextStyle(
                  color: cs.onSurface.withValues(alpha: 0.9),
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.of(ctx).maybePop(),
                  child: Text(l10n.ttsServicesCloseButton),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

// Removed selected tag; background highlight indicates selection

Future<TtsServiceOptions?> _showAddNetworkTtsSheet(BuildContext context) =>
    _showNetworkTtsSheet(context, null);

Future<TtsServiceOptions?> _showEditNetworkTtsSheet(
  BuildContext context,
  TtsServiceOptions initial,
) => _showNetworkTtsSheet(context, initial);

Future<TtsServiceOptions?> _showNetworkTtsSheet(
  BuildContext context,
  TtsServiceOptions? initial,
) async {
  final cs = Theme.of(context).colorScheme;
  final l10n = AppLocalizations.of(context)!;
  NetworkTtsKind kind = initial?.kind ?? NetworkTtsKind.openai;
  final nameCtl = TextEditingController(text: initial?.name ?? '');
  final apiKeyCtl = TextEditingController(
    text: (initial is OpenAiTtsOptions)
        ? initial.apiKey
        : (initial is GeminiTtsOptions)
        ? initial.apiKey
        : (initial is MiniMaxTtsOptions)
        ? initial.apiKey
        : (initial is ElevenLabsTtsOptions)
        ? initial.apiKey
        : '',
  );
  final baseCtl = TextEditingController(
    text: (initial is OpenAiTtsOptions)
        ? initial.baseUrl
        : (initial is GeminiTtsOptions)
        ? initial.baseUrl
        : (initial is MiniMaxTtsOptions)
        ? initial.baseUrl
        : (initial is ElevenLabsTtsOptions)
        ? initial.baseUrl
        : '',
  );
  final modelCtl = TextEditingController(
    text: (initial is OpenAiTtsOptions)
        ? initial.model
        : (initial is GeminiTtsOptions)
        ? initial.model
        : (initial is MiniMaxTtsOptions)
        ? initial.model
        : (initial is ElevenLabsTtsOptions)
        ? initial.modelId
        : '',
  );
  final voiceCtl = TextEditingController(
    text: (initial is OpenAiTtsOptions)
        ? initial.voice
        : (initial is GeminiTtsOptions)
        ? initial.voiceName
        : (initial is MiniMaxTtsOptions)
        ? initial.voiceId
        : (initial is ElevenLabsTtsOptions)
        ? initial.voiceId
        : '',
  );
  final emotionCtl = TextEditingController(
    text: (initial is MiniMaxTtsOptions) ? initial.emotion : 'calm',
  );
  final speedCtl = TextEditingController(
    text: (initial is MiniMaxTtsOptions) ? initial.speed.toString() : '1.0',
  );

  TtsServiceOptions? result;
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: cs.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (ctx) {
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle + Header with only a Check on the right
            const SizedBox(height: 6),
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: cs.onSurface.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 6, 4, 6),
              child: Row(
                children: [
                  _TactileIconButton(
                    icon: Lucide.X,
                    color: cs.onSurface,
                    size: 20,
                    onTap: () => Navigator.of(ctx).maybePop(),
                  ),
                  Expanded(
                    child: Center(
                      child: Text(
                        initial == null
                            ? l10n.ttsServicesDialogAddTitle
                            : l10n.ttsServicesDialogEditTitle,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  _TactileIconButton(
                    icon: Lucide.Check,
                    color: cs.onSurface,
                    size: 20,
                    onTap: () {
                      final name = (nameCtl.text.trim().isEmpty)
                          ? networkTtsKindDisplayName(kind)
                          : nameCtl.text.trim();
                      final apiKey = apiKeyCtl.text.trim();
                      final base = baseCtl.text.trim().isEmpty
                          ? _defaultBaseUrl(kind)
                          : baseCtl.text.trim();
                      final model = modelCtl.text.trim().isEmpty
                          ? _defaultModel(kind)
                          : modelCtl.text.trim();
                      final voice = voiceCtl.text.trim().isEmpty
                          ? _defaultVoice(kind)
                          : voiceCtl.text.trim();
                      if (apiKey.isEmpty) {
                        Navigator.of(ctx).maybePop();
                        return;
                      }
                      if (kind == NetworkTtsKind.openai) {
                        result = OpenAiTtsOptions(
                          enabled: true,
                          name: name,
                          apiKey: apiKey,
                          baseUrl: base,
                          model: model,
                          voice: voice,
                        );
                      } else if (kind == NetworkTtsKind.gemini) {
                        result = GeminiTtsOptions(
                          enabled: true,
                          name: name,
                          apiKey: apiKey,
                          baseUrl: base,
                          model: model,
                          voiceName: voice,
                        );
                      } else if (kind == NetworkTtsKind.minimax) {
                        final spd =
                            double.tryParse(speedCtl.text.trim()) ?? 1.0;
                        result = MiniMaxTtsOptions(
                          enabled: true,
                          name: name,
                          apiKey: apiKey,
                          baseUrl: base,
                          model: model,
                          voiceId: voice,
                          emotion: emotionCtl.text.trim().isEmpty
                              ? 'calm'
                              : emotionCtl.text.trim(),
                          speed: spd,
                        );
                      } else {
                        // ElevenLabs
                        result = ElevenLabsTtsOptions(
                          enabled: true,
                          name: name,
                          apiKey: apiKey,
                          baseUrl: base,
                          modelId: model.isEmpty ? _defaultModel(kind) : model,
                          voiceId: voice,
                        );
                      }
                      Navigator.of(ctx).pop();
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            // Content
            Padding(
              padding: EdgeInsets.only(
                left: 12,
                right: 12,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 12,
              ),
              child: StatefulBuilder(
                builder: (ctx2, setState) {
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _sheetSelectRow(
                        ctx2,
                        label: l10n.ttsServicesDialogProviderType,
                        value: networkTtsKindDisplayName(kind),
                        options: [
                          networkTtsKindDisplayName(NetworkTtsKind.openai),
                          networkTtsKindDisplayName(NetworkTtsKind.gemini),
                          networkTtsKindDisplayName(NetworkTtsKind.minimax),
                          networkTtsKindDisplayName(NetworkTtsKind.elevenlabs),
                        ],
                        onSelected: (picked) async {
                          if (picked ==
                              networkTtsKindDisplayName(
                                NetworkTtsKind.openai,
                              )) {
                            kind = NetworkTtsKind.openai;
                          }
                          if (picked ==
                              networkTtsKindDisplayName(
                                NetworkTtsKind.gemini,
                              )) {
                            kind = NetworkTtsKind.gemini;
                          }
                          if (picked ==
                              networkTtsKindDisplayName(
                                NetworkTtsKind.minimax,
                              )) {
                            kind = NetworkTtsKind.minimax;
                          }
                          if (picked ==
                              networkTtsKindDisplayName(
                                NetworkTtsKind.elevenlabs,
                              )) {
                            kind = NetworkTtsKind.elevenlabs;
                          }
                          (ctx as Element).markNeedsBuild();
                        },
                      ),
                      const SizedBox(height: 6),
                      _inputRowMobile(
                        context,
                        label: l10n.ttsServicesFieldNameLabel,
                        controller: nameCtl,
                        hint: networkTtsKindDisplayName(kind),
                      ),
                      const SizedBox(height: 6),
                      _inputRowMobile(
                        context,
                        label: l10n.ttsServicesFieldApiKeyLabel,
                        controller: apiKeyCtl,
                        obscure: true,
                      ),
                      const SizedBox(height: 6),
                      _inputRowMobile(
                        context,
                        label: l10n.ttsServicesFieldBaseUrlLabel,
                        controller: baseCtl,
                        hint: _defaultBaseUrl(kind),
                      ),
                      const SizedBox(height: 6),
                      _inputRowMobile(
                        context,
                        label: l10n.ttsServicesFieldModelLabel,
                        controller: modelCtl,
                        hint: _defaultModel(kind),
                      ),
                      const SizedBox(height: 6),
                      _inputRowMobile(
                        context,
                        label: _voiceLabelFor(kind, l10n),
                        controller: voiceCtl,
                        hint: _defaultVoice(kind),
                      ),
                      if (kind == NetworkTtsKind.minimax) ...[
                        const SizedBox(height: 6),
                        _inputRowMobile(
                          context,
                          label: l10n.ttsServicesFieldEmotionLabel,
                          controller: emotionCtl,
                          hint: 'calm',
                        ),
                        const SizedBox(height: 6),
                        _inputRowMobile(
                          context,
                          label: l10n.ttsServicesFieldSpeedLabel,
                          controller: speedCtl,
                          hint: '1.0',
                        ),
                      ],
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      );
    },
  );
  return result;
}

Future<void> _showSystemTtsConfig(BuildContext context) async {
  final cs = Theme.of(context).colorScheme;
  final l10n = AppLocalizations.of(context)!;
  final tts = context.read<TtsProvider>();
  double rate = tts.speechRate;
  double pitch = tts.pitch;
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: false,
    backgroundColor: cs.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (ctx) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: cs.onSurface.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  l10n.ttsServicesPageSystemTtsSettingsTitle,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              // Engine selector
              FutureBuilder<List<String>>(
                future: tts.listEngines(),
                builder: (context, snap) {
                  final engines = snap.data ?? const <String>[];
                  final cur =
                      tts.engineId ?? (engines.isNotEmpty ? engines.first : '');
                  return _sheetSelectRow(
                    context,
                    label: l10n.ttsServicesPageEngineLabel,
                    value: cur.isEmpty ? l10n.ttsServicesPageAutoLabel : cur,
                    options: engines,
                    onSelected: (picked) async {
                      await tts.setEngineId(picked);
                      (ctx as Element).markNeedsBuild();
                    },
                  );
                },
              ),
              const SizedBox(height: 4),
              // Language selector
              FutureBuilder<List<String>>(
                future: tts.listLanguages(),
                builder: (context, snap) {
                  final langs = snap.data ?? const <String>[];
                  final cur =
                      tts.languageTag ??
                      (langs.contains('zh-CN')
                          ? 'zh-CN'
                          : (langs.contains('en-US')
                                ? 'en-US'
                                : (langs.isNotEmpty ? langs.first : '')));
                  return _sheetSelectRow(
                    context,
                    label: l10n.ttsServicesPageLanguageLabel,
                    value: cur.isEmpty ? l10n.ttsServicesPageAutoLabel : cur,
                    options: langs,
                    onSelected: (picked) async {
                      await tts.setLanguageTag(picked);
                      (ctx as Element).markNeedsBuild();
                    },
                  );
                },
              ),
              const SizedBox(height: 8),
              Text(
                l10n.ttsServicesPageSpeechRateLabel,
                style: TextStyle(
                  fontSize: 12,
                  color: cs.onSurface.withValues(alpha: 0.7),
                ),
              ),
              Slider(
                value: rate,
                min: 0.1,
                max: 1.0,
                onChanged: (v) {
                  rate = v;
                  // Rebuild this bottom sheet
                  (ctx as Element).markNeedsBuild();
                },
                onChangeEnd: (v) async {
                  await tts.setSpeechRate(v);
                },
              ),
              const SizedBox(height: 4),
              Text(
                l10n.ttsServicesPagePitchLabel,
                style: TextStyle(
                  fontSize: 12,
                  color: cs.onSurface.withValues(alpha: 0.7),
                ),
              ),
              Slider(
                value: pitch,
                min: 0.5,
                max: 2.0,
                onChanged: (v) {
                  pitch = v;
                  (ctx as Element).markNeedsBuild();
                },
                onChangeEnd: (v) async {
                  await tts.setPitch(v);
                },
              ),
              const SizedBox(height: 6),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () async {
                    final demo = l10n.ttsServicesPageSettingsSavedMessage;
                    Navigator.of(ctx).maybePop();
                    showAppSnackBar(
                      context,
                      message: demo,
                      type: NotificationType.success,
                    );
                  },
                  icon: Icon(Lucide.Check, size: 16),
                  label: Text(l10n.ttsServicesPageDoneButton),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

Widget _sheetSelectRow(
  BuildContext context, {
  required String label,
  required String value,
  required List<String> options,
  required Future<void> Function(String picked) onSelected,
}) {
  final cs = Theme.of(context).colorScheme;
  return _TactileRow(
    onTap: options.isEmpty
        ? null
        : () async {
            final picked = await showModalBottomSheet<String>(
              context: context,
              backgroundColor: cs.surface,
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              ),
              builder: (ctx2) {
                return SafeArea(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: MediaQuery.of(ctx2).size.height * 0.6,
                    ),
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: options.length,
                      separatorBuilder: (c, i) => _sheetDivider(ctx2),
                      itemBuilder: (c, i) => _sheetOption(
                        ctx2,
                        label: options[i],
                        onTap: () => Navigator.of(ctx2).pop(options[i]),
                      ),
                    ),
                  ),
                );
              },
            );
            if (picked != null && picked.isNotEmpty) {
              await onSelected(picked);
            }
          },
    builder: (pressed) {
      final baseColor = Theme.of(
        context,
      ).colorScheme.onSurface.withValues(alpha: 0.9);
      return _AnimatedPressColor(
        pressed: pressed,
        base: baseColor,
        builder: (c) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            child: Row(
              children: [
                Expanded(
                  child: Text(label, style: TextStyle(fontSize: 15, color: c)),
                ),
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: Text(
                    value,
                    style: TextStyle(
                      fontSize: 13,
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ),
                Icon(Lucide.ChevronRight, size: 16, color: c),
              ],
            ),
          );
        },
      );
    },
  );
}

// Bottom sheet iOS-style option
Widget _sheetOption(
  BuildContext context, {
  required String label,
  required VoidCallback onTap,
}) {
  final cs = Theme.of(context).colorScheme;
  final isDark = Theme.of(context).brightness == Brightness.dark;
  return _TactileRow(
    pressedScale: 1.00,
    haptics: true,
    onTap: onTap,
    builder: (pressed) {
      final base = cs.onSurface;
      final target = pressed
          ? (Color.lerp(base, isDark ? Colors.black : Colors.white, 0.55) ??
                base)
          : base;
      final bgTarget = pressed
          ? (isDark
                ? Colors.white.withValues(alpha: 0.06)
                : Colors.black.withValues(alpha: 0.05))
          : Colors.transparent;
      return TweenAnimationBuilder<Color?>(
        tween: ColorTween(end: target),
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        builder: (context, color, _) {
          final c = color ?? base;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            color: bgTarget,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Expanded(
                  child: Text(label, style: TextStyle(fontSize: 15, color: c)),
                ),
              ],
            ),
          );
        },
      );
    },
  );
}

Widget _sheetDivider(BuildContext context) {
  final cs = Theme.of(context).colorScheme;
  return Divider(
    height: 1,
    thickness: 0.6,
    indent: 16,
    endIndent: 16,
    color: cs.outlineVariant.withValues(alpha: 0.18),
  );
}

Widget _inputRowMobile(
  BuildContext context, {
  required String label,
  required TextEditingController controller,
  String? hint,
  bool obscure = false,
}) {
  final cs = Theme.of(context).colorScheme;
  return Padding(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: cs.onSurface.withValues(alpha: 0.7),
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          obscureText: obscure,
          decoration: InputDecoration(
            hintText: hint,
            isDense: true,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
      ],
    ),
  );
}

String _defaultBaseUrl(NetworkTtsKind k) {
  switch (k) {
    case NetworkTtsKind.openai:
      return 'https://api.openai.com/v1';
    case NetworkTtsKind.gemini:
      return 'https://generativelanguage.googleapis.com/v1beta';
    case NetworkTtsKind.minimax:
      return 'https://api.minimaxi.com/v1';
    case NetworkTtsKind.elevenlabs:
      return 'https://api.elevenlabs.io';
  }
}

String _defaultModel(NetworkTtsKind k) {
  switch (k) {
    case NetworkTtsKind.openai:
      return 'gpt-4o-mini-tts';
    case NetworkTtsKind.gemini:
      return 'gemini-2.5-flash-preview-tts';
    case NetworkTtsKind.minimax:
      return 'speech-2.5-hd-preview';
    case NetworkTtsKind.elevenlabs:
      return 'eleven_multilingual_v2';
  }
}

String _defaultVoice(NetworkTtsKind k) {
  switch (k) {
    case NetworkTtsKind.openai:
      return 'alloy';
    case NetworkTtsKind.gemini:
      return 'Kore';
    case NetworkTtsKind.minimax:
      return 'female-shaonv';
    case NetworkTtsKind.elevenlabs:
      return '';
  }
}

String _voiceLabelFor(NetworkTtsKind k, AppLocalizations l10n) {
  switch (k) {
    case NetworkTtsKind.openai:
      return l10n.ttsServicesFieldVoiceLabel;
    case NetworkTtsKind.gemini:
      return l10n.ttsServicesFieldVoiceLabel; // same label
    case NetworkTtsKind.minimax:
      return l10n.ttsServicesFieldVoiceIdLabel;
    case NetworkTtsKind.elevenlabs:
      return l10n.ttsServicesFieldVoiceIdLabel;
  }
}
