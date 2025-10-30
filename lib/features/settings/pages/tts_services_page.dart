import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/settings_provider.dart';
import 'package:provider/provider.dart';
import '../../../icons/lucide_adapter.dart';
import '../../../core/providers/tts_provider.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/snackbar.dart';
import '../../../core/services/haptics.dart';

class TtsServicesPage extends StatelessWidget {
  const TtsServicesPage({super.key, this.embedded = false});

  /// Whether this page is embedded in a desktop settings layout (no Scaffold/AppBar)
  final bool embedded;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;

    final bodyContent = ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        _header(context, l10n.ttsServicesPageTitle, first: true),
        Consumer<TtsProvider>(builder: (context, tts, _) {
          final available = tts.isAvailable && (tts.error == null);
          final titleText = l10n.ttsServicesPageSystemTtsTitle;
          final subText = available
              ? l10n.ttsServicesPageSystemTtsAvailableSubtitle
              : l10n.ttsServicesPageSystemTtsUnavailableSubtitle(tts.error ?? l10n.ttsServicesPageSystemTtsUnavailableNotInitialized);
          final letter = (titleText.trim().isEmpty ? '?' : titleText.trim().substring(0, 1)).toUpperCase();
          return _iosSectionCard(children: [
            _TactileRow(
              pressedScale: 0.98,
              haptics: false,
              onTap: available ? () => _showSystemTtsConfig(context) : null,
              builder: (pressed) {
                final cs = Theme.of(context).colorScheme;
                final base = cs.onSurface.withOpacity(0.9);
                return _AnimatedPressColor(
                  pressed: pressed,
                  base: base,
                  builder: (c) {
                    final isDark = Theme.of(context).brightness == Brightness.dark;
                    // Light mode: white overlay; Dark mode: black overlay (per request)
                    final overlay = pressed
                        ? (isDark ? Colors.black.withOpacity(0.06) : Colors.white.withOpacity(0.05))
                        : Colors.transparent;
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                      child: Row(
                        children: [
                          _AvatarBadge(letter: letter, overlay: overlay),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(titleText, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 15, color: c, fontWeight: FontWeight.w600)),
                                const SizedBox(height: 3),
                                Text(subText, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: c.withOpacity(0.7))),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          _SmallTactileIcon(
                            icon: tts.isSpeaking ? Lucide.CircleStop : Lucide.Volume2,
                            baseColor: c,
                            onTap: available
                                ? () async {
                                    if (!tts.isSpeaking) {
                                      final demo = l10n.ttsServicesPageTestSpeechText;
                                      await tts.speak(demo);
                                    } else {
                                      await tts.stop();
                                    }
                                  }
                                : () {},
                            enabled: available,
                          ),
                          const SizedBox(width: 8),
                          Icon(Lucide.ChevronRight, size: 16, color: c),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ]);
        }),
      ],
    );

    // If embedded, return body content directly without Scaffold
    if (embedded) {
      return bodyContent;
    }

    // Otherwise, return full page with Scaffold and AppBar
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
              onTap: () {
                showAppSnackBar(
                  context,
                  message: l10n.ttsServicesPageAddNotImplemented,
                  type: NotificationType.warning,
                );
              },
            ),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: bodyContent,
    );
  }
}

// --- iOS-style widgets and helpers ---

Widget _header(BuildContext context, String text, {bool first = false}) {
  final cs = Theme.of(context).colorScheme;
  return Padding(
    padding: EdgeInsets.fromLTRB(12, first ? 6 : 18, 12, 6),
    child: Text(text, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: cs.onSurface.withOpacity(0.8))),
  );
}

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

class _TactileRow extends StatefulWidget {
  const _TactileRow({required this.builder, this.onTap, this.pressedScale = 1.00, this.haptics = true});
  final Widget Function(bool pressed) builder; final VoidCallback? onTap; final double pressedScale; final bool haptics;
  @override State<_TactileRow> createState() => _TactileRowState();
}

class _TactileRowState extends State<_TactileRow> {
  bool _pressed = false; void _set(bool v){ if(_pressed!=v) setState(()=>_pressed=v);} 
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: widget.onTap==null?null:(_)=>_set(true),
      onTapUp: widget.onTap==null?null:(_)=>_set(false),
      onTapCancel: widget.onTap==null?null:()=>_set(false),
      onTap: widget.onTap==null?null:(){
        if(widget.haptics && context.read<SettingsProvider>().hapticsOnListItemTap) Haptics.soft();
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
  const _AnimatedPressColor({required this.pressed, required this.base, required this.builder});
  final bool pressed; final Color base; final Widget Function(Color c) builder;
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final target = pressed ? (Color.lerp(base, isDark ? Colors.black : Colors.white, 0.55) ?? base) : base;
    return TweenAnimationBuilder<Color?>(
      tween: ColorTween(end: target), duration: const Duration(milliseconds: 220), curve: Curves.easeOutCubic,
      builder: (context, color, _) => builder(color ?? base),
    );
  }
}

Widget _iosSectionCard({required List<Widget> children}) {
  return Builder(builder: (context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final Color bg = isDark ? Colors.white10 : Colors.white.withOpacity(0.96);
    return Container(
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12), border: Border.all(color: cs.outlineVariant.withOpacity(isDark ? 0.08 : 0.06), width: 0.6)),
      clipBehavior: Clip.antiAlias,
      child: Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Column(children: children)),
    );
  });
}

Widget _iosDivider(BuildContext context) {
  final cs = Theme.of(context).colorScheme;
  return Divider(height: 6, thickness: 0.6, indent: 54, endIndent: 12, color: cs.outlineVariant.withOpacity(0.18));
}

class _SmallTactileIcon extends StatefulWidget {
  const _SmallTactileIcon({required this.icon, required this.onTap, this.enabled = true, this.baseColor});
  final IconData icon; final VoidCallback onTap; final bool enabled; final Color? baseColor;
  @override State<_SmallTactileIcon> createState() => _SmallTactileIconState();
}

class _SmallTactileIconState extends State<_SmallTactileIcon> {
  bool _pressed = false;
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final base = widget.baseColor ?? cs.onSurface;
    final c = widget.enabled ? base.withOpacity(_pressed ? 0.6 : 0.9) : base.withOpacity(0.3);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: widget.enabled ? (_) => setState(()=>_pressed=true) : null,
      onTapUp: widget.enabled ? (_) => setState(()=>_pressed=false) : null,
      onTapCancel: widget.enabled ? ()=>setState(()=>_pressed=false) : null,
      onTap: widget.enabled ? (){ Haptics.soft(); widget.onTap(); } : null,
      child: Padding(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6), child: Icon(widget.icon, size: 18, color: c)),
    );
  }
}

class _AvatarBadge extends StatelessWidget {
  const _AvatarBadge({required this.letter, required this.overlay});
  final String letter; final Color overlay;
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme; final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseBg = isDark ? Colors.white10 : cs.primary.withOpacity(0.1);
    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          width: 36, height: 36,
          decoration: BoxDecoration(color: baseBg, shape: BoxShape.circle),
          alignment: Alignment.center,
          child: Text(letter, style: TextStyle(color: cs.primary, fontWeight: FontWeight.w700, fontSize: 14)),
        ),
        if (overlay != Colors.transparent)
          Container(width: 36, height: 36, decoration: BoxDecoration(color: overlay, shape: BoxShape.circle)),
      ],
    );
  }
}

// Removed selected tag; background highlight indicates selection

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
                child: Container(width: 40, height: 4, decoration: BoxDecoration(color: cs.onSurface.withOpacity(0.2), borderRadius: BorderRadius.circular(999))),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(l10n.ttsServicesPageSystemTtsSettingsTitle, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
              ),
              const SizedBox(height: 10),
              // Engine selector
              FutureBuilder<List<String>>(
                future: tts.listEngines(),
                builder: (context, snap) {
                  final engines = snap.data ?? const <String>[];
                  final cur = tts.engineId ?? (engines.isNotEmpty ? engines.first : '');
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
                  final cur = tts.languageTag ?? (langs.contains('zh-CN') ? 'zh-CN' : (langs.contains('en-US') ? 'en-US' : (langs.isNotEmpty ? langs.first : '')));
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
              Text(l10n.ttsServicesPageSpeechRateLabel, style: TextStyle(fontSize: 12, color: cs.onSurface.withOpacity(0.7))),
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
              Text(l10n.ttsServicesPagePitchLabel, style: TextStyle(fontSize: 12, color: cs.onSurface.withOpacity(0.7))),
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
                    showAppSnackBar(context, message: demo, type: NotificationType.success);
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
              shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
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
      final baseColor = Theme.of(context).colorScheme.onSurface.withOpacity(0.9);
      return _AnimatedPressColor(
        pressed: pressed,
        base: baseColor,
        builder: (c) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            child: Row(
              children: [
                Expanded(child: Text(label, style: TextStyle(fontSize: 15, color: c))),
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: Text(value, style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6))),
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
      final target = pressed ? (Color.lerp(base, isDark ? Colors.black : Colors.white, 0.55) ?? base) : base;
      final bgTarget = pressed ? (isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.05)) : Colors.transparent;
      return TweenAnimationBuilder<Color?>(
        tween: ColorTween(end: target), duration: const Duration(milliseconds: 220), curve: Curves.easeOutCubic,
        builder: (context, color, _) {
          final c = color ?? base;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 200), curve: Curves.easeOutCubic,
            color: bgTarget,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(children: [Expanded(child: Text(label, style: TextStyle(fontSize: 15, color: c)))]),
          );
        },
      );
    },
  );
}

Widget _sheetDivider(BuildContext context) {
  final cs = Theme.of(context).colorScheme;
  return Divider(height: 1, thickness: 1.0, indent: 16, endIndent: 16, color: cs.outlineVariant.withOpacity(0.18));
}
