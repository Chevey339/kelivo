import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;

import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../icons/lucide_adapter.dart';
import 'package:haptic_feedback/haptic_feedback.dart' as HF;
import 'package:provider/provider.dart';
import '../../../core/providers/settings_provider.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/ios_switch.dart';
import '../../../shared/widgets/snackbar.dart';
import '../../../core/services/haptics.dart';

class AboutPage extends StatefulWidget {
  const AboutPage({super.key, this.embedded = false});

  /// Whether this page is embedded in a desktop settings layout (no Scaffold/AppBar)
  final bool embedded;

  @override
  State<AboutPage> createState() => _AboutPageState();
}

class _AboutPageState extends State<AboutPage> {
  String _version = '';
  String _buildNumber = '';
  String _systemInfo = '';
  int _versionTapCount = 0;
  DateTime? _lastVersionTap;

  @override
  void initState() {
    super.initState();
    _loadInfo();
  }

  Future<void> _loadInfo() async {
    final pkg = await PackageInfo.fromPlatform();
    String sys;
    if (kIsWeb) {
      sys = 'Web';
    } else if (Platform.isAndroid) {
      sys = 'Android';
    } else if (Platform.isIOS) {
      sys = 'iOS';
    } else if (Platform.isMacOS) {
      sys = 'macOS';
    } else if (Platform.isWindows) {
      sys = 'Windows';
    } else if (Platform.isLinux) {
      sys = 'Linux';
    } else {
      sys = Platform.operatingSystem;
    }
    setState(() {
      _version = pkg.version;
      _buildNumber = pkg.buildNumber;
      _systemInfo = sys;
    });
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      // Fallback: try in-app web view
      await launchUrl(uri, mode: LaunchMode.platformDefault);
    }
  }

  void _onVersionTap() {
    final now = DateTime.now();
    // Reset the counter if taps are spaced too far apart
    if (_lastVersionTap == null || now.difference(_lastVersionTap!) > const Duration(seconds: 2)) {
      _versionTapCount = 0;
    }
    _lastVersionTap = now;
    _versionTapCount++;

    const threshold = 7;
    if (_versionTapCount < threshold) return;

    _versionTapCount = 0; // reset after unlock
    _showEasterEgg();
  }

  void _showEasterEgg() {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      constraints: BoxConstraints(
        minWidth: MediaQuery.of(context).size.width,
        maxWidth: MediaQuery.of(context).size.width,
      ),
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        // Local state for preview controls inside the sheet
        bool iosSwitchValue = false;
        return StatefulBuilder(
          builder: (dialogContext, dialogSetState) {
            int testCounter = 0;
            
            return SafeArea(
              child: FractionallySizedBox(
                heightFactor: 0.7,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Icon(Lucide.Sparkles, size: 28, color: cs.primary),
                      const SizedBox(height: 10),
                      Text(
                        l10n.aboutPageEasterEggTitle,
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: SingleChildScrollView(
                          child: Column(
                            children: [
                              Text(
                                l10n.aboutPageEasterEggMessage,
                                style: TextStyle(color: cs.onSurface.withValues(alpha: 0.75), height: 1.3),
                              ),
                              const SizedBox(height: 24),
                              const Divider(),
                              const SizedBox(height: 16),
                              Text(
                                'Toast Notification Test Area',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: cs.onSurface,
                                ),
                              ),
                              const SizedBox(height: 16),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                alignment: WrapAlignment.center,
                                children: [
                                  _TestButton(
                                    label: 'Success',
                                    color: const Color(0xFF34C759),
                                    onTap: () {
                                      testCounter++;
                                      showAppSnackBar(
                                        context,
                                        message: 'Operation completed successfully! #$testCounter',
                                        type: NotificationType.success,
                                      );
                                    },
                                  ),
                                  _TestButton(
                                    label: 'Error',
                                    color: const Color(0xFFFF3B30),
                                    onTap: () {
                                      testCounter++;
                                      showAppSnackBar(
                                        context,
                                        message: 'An error occurred. Please try again. #$testCounter',
                                        type: NotificationType.error,
                                      );
                                    },
                                  ),
                                  _TestButton(
                                    label: 'Warning',
                                    color: const Color(0xFFFF9500),
                                    onTap: () {
                                      testCounter++;
                                      showAppSnackBar(
                                        context,
                                        message: 'Warning: Low battery detected #$testCounter',
                                        type: NotificationType.warning,
                                      );
                                    },
                                  ),
                                  _TestButton(
                                    label: 'Info',
                                    color: cs.primary,
                                    onTap: () {
                                      testCounter++;
                                      showAppSnackBar(
                                        context,
                                        message: 'New message received #$testCounter',
                                        type: NotificationType.info,
                                      );
                                    },
                                  ),
                                  _TestButton(
                                    label: 'With Action',
                                    color: cs.secondary,
                                    onTap: () {
                                      testCounter++;
                                      showAppSnackBar(
                                        context,
                                        message: 'File downloaded #$testCounter',
                                        type: NotificationType.success,
                                        actionLabel: 'Open',
                                        onAction: () {
                                          showAppSnackBar(
                                            context,
                                            message: 'Opening file...',
                                            type: NotificationType.info,
                                          );
                                        },
                                      );
                                    },
                                  ),
                                  _TestButton(
                                    label: 'Long Message',
                                    color: cs.tertiary,
                                    onTap: () {
                                      testCounter++;
                                      showAppSnackBar(
                                        context,
                                        message: 'This is a very long message that demonstrates how the toast notification handles multiline text gracefully #$testCounter',
                                        type: NotificationType.info,
                                        duration: const Duration(seconds: 5),
                                      );
                                    },
                                  ),
                                  _TestButton(
                                    label: 'Quick Burst',
                                    color: cs.onSurface.withValues(alpha: 0.7),
                                    onTap: () {
                                      for (int i = 0; i < 5; i++) {
                                        Future.delayed(Duration(milliseconds: i * 100), () {
                                          if (mounted) {
                                            showAppSnackBar(
                                              context,
                                              message: 'Rapid notification ${i + 1}',
                                              type: NotificationType.info,
                                              duration: const Duration(seconds: 2),
                                            );
                                          }
                                        });
                                      }
                                    },
                                  ),
                                  _TestButton(
                                    label: 'Dismiss All',
                                    color: cs.error,
                                    onTap: () {
                                      AppSnackBarManager().dismissAll();
                                    },
                                  ),
                                ],
                              ),
                              // Removed vibration/flutter_vibrate sections.
                              const SizedBox(height: 24),
                              const Divider(),
                              const SizedBox(height: 16),
                              Text(
                                'Haptic Feedback (Plugin) Test',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: cs.onSurface,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                alignment: WrapAlignment.center,
                                children: [
                                  for (final e in [
                                    ['success', HF.HapticsType.success],
                                    ['warning', HF.HapticsType.warning],
                                    ['error', HF.HapticsType.error],
                                    ['light', HF.HapticsType.light],
                                    ['medium', HF.HapticsType.medium],
                                    ['heavy', HF.HapticsType.heavy],
                                    ['rigid', HF.HapticsType.rigid],
                                    ['soft', HF.HapticsType.soft],
                                    ['selection', HF.HapticsType.selection],
                                  ])
                                    _TestButton(
                                      label: e[0] as String,
                                      color: cs.primary,
                                      onTap: () async {
                                        if (!context.read<SettingsProvider>().hapticsGlobalEnabled) return;
                                        try {
                                          final can = await HF.Haptics.canVibrate();
                                          if (can) {
                                            await HF.Haptics.vibrate(e[1] as HF.HapticsType);
                                          }
                                        } catch (_) {}
                                      },
                              ),
                              _TestButton(
                                label: 'Play All',
                                color: cs.secondary,
                                onTap: () async {
                                      if (!context.read<SettingsProvider>().hapticsGlobalEnabled) return;
                                      try {
                                        final can = await HF.Haptics.canVibrate();
                                        if (!can) return;
                                        final types = <HF.HapticsType>[
                                          HF.HapticsType.success,
                                          HF.HapticsType.warning,
                                          HF.HapticsType.error,
                                          HF.HapticsType.light,
                                          HF.HapticsType.medium,
                                          HF.HapticsType.heavy,
                                          HF.HapticsType.rigid,
                                          HF.HapticsType.soft,
                                          HF.HapticsType.selection,
                                        ];
                                        for (final t in types) {
                                          await HF.Haptics.vibrate(t);
                                          await Future.delayed(const Duration(milliseconds: 180));
                                        }
                                      } catch (_) {}
                                    },
                                  ),
                                ],
                              ),
                              const SizedBox(height: 24),
                              const Divider(),
                              const SizedBox(height: 16),
                              Text(
                                'Custom Switch Preview',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: cs.onSurface,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Material(
                                color: Colors.transparent,
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                                  child: Row(
                                    children: [
                                      Text(
                                        'iOS‑style switch',
                                        style: TextStyle(color: cs.onSurface.withValues(alpha: 0.9)),
                                      ),
                                      const Spacer(),
                                      IosSwitch(
                                        value: iosSwitchValue,
                                        onChanged: (v) => dialogSetState(() => iosSwitchValue = v),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      FilledButton(
                        onPressed: () => Navigator.of(ctx).maybePop(),
                        child: Text(l10n.aboutPageEasterEggButton),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;

    final bodyContent = ListView(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
        children: [
          // Header card: left icon + right title/description
          _iosSectionCard(children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: SizedBox(
                      width: 54,
                      height: 54,
                      child: Image.asset('assets/app_icon.png', fit: BoxFit.cover),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Kelivo',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          l10n.aboutPageAppDescription,
                          style: TextStyle(fontSize: 13, color: cs.onSurface.withOpacity(0.65), height: 1.2),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ]),

          const SizedBox(height: 12),

          // iOS-style list card
          _iosSectionCard(children: [
            // Version (tap 7x to unlock easter egg) — logic unchanged
            _iosNavRow(
              context,
              icon: Lucide.Code,
              label: l10n.aboutPageVersion,
              detailBuilder: (_) => Text(_version.isEmpty ? '...' : '$_version / $_buildNumber'),
              onTap: _onVersionTap,
            ),
            _iosDivider(context),
            _iosNavRow(
              context,
              icon: Lucide.Phone,
              label: l10n.aboutPageSystem,
              detailBuilder: (_) => Text(_systemInfo.isEmpty ? '...' : _systemInfo),
              onTap: null, // informational only
            ),
            _iosDivider(context),
            _iosNavRow(
              context,
              icon: Lucide.Earth,
              label: l10n.aboutPageWebsite,
              onTap: () async {
                final uri = Uri.parse('https://kelivo.psycheas.top/');
                if (!await launchUrl(uri, mode: LaunchMode.platformDefault)) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                }
              },
            ),
            _iosDivider(context),
            _iosNavRow(
              context,
              icon: Lucide.Github,
              label: 'GitHub',
              onTap: () => _openUrl('https://github.com/Chevey339/kelivo'),
            ),
            _iosDivider(context),
            _iosNavRow(
              context,
              icon: Lucide.FileText,
              label: l10n.aboutPageLicense,
              onTap: () => _openUrl('https://github.com/Chevey339/kelivo/blob/master/LICENSE'),
            ),
            _iosDivider(context),
            _iosNavRowSvgLeading(
              context,
              svgAsset: 'assets/icons/discord.svg',
              label: l10n.aboutPageJoinDiscord,
              onTap: () => _openUrl('https://discord.gg/Tb8DyvvV5T'),
            ),
          ]),

          const SizedBox(height: 24),
        ],
      );

    // If embedded, return body content directly without Scaffold
    if (widget.embedded) {
      return bodyContent;
    }

    // Otherwise, return full page with Scaffold and AppBar
    return Scaffold(
      appBar: AppBar(
        leading: Tooltip(
          message: l10n.settingsPageBackButton,
          child: _TactileIconButton(
            icon: Lucide.ArrowLeft,
            color: cs.onSurface,
            size: 22,
            onTap: () => Navigator.of(context).maybePop(),
          ),
        ),
        title: Text(l10n.settingsPageAbout),
        actions: const [SizedBox(width: 12)],
      ),
      body: bodyContent,
    );
  }
}

// --- iOS-style helpers (mirroring Settings/Display pages) ---

Widget _iosSectionCard({required List<Widget> children}) {
  return Builder(builder: (context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final Color bg = isDark ? Colors.white10 : Colors.white.withOpacity(0.96);
    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.outlineVariant.withOpacity(isDark ? 0.08 : 0.06), width: 0.6),
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(children: children),
      ),
    );
  });
}

Widget _iosDivider(BuildContext context) {
  final cs = Theme.of(context).colorScheme;
  return Divider(height: 6, thickness: 0.6, indent: 54, endIndent: 12, color: cs.outlineVariant.withOpacity(0.18));
}

class _AnimatedPressColor extends StatelessWidget {
  const _AnimatedPressColor({required this.pressed, required this.base, required this.builder});
  final bool pressed;
  final Color base;
  final Widget Function(Color color) builder;
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final target = pressed ? (Color.lerp(base, isDark ? Colors.black : Colors.white, 0.55) ?? base) : base;
    return TweenAnimationBuilder<Color?>(
      tween: ColorTween(end: target),
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      builder: (context, color, _) => builder(color ?? base),
    );
  }
}

class _TactileRow extends StatefulWidget {
  const _TactileRow({required this.builder, this.onTap, this.pressedScale = 1.00, this.haptics = false});
  final Widget Function(bool pressed) builder;
  final VoidCallback? onTap;
  final double pressedScale;
  final bool haptics;
  @override
  State<_TactileRow> createState() => _TactileRowState();
}

class _TactileRowState extends State<_TactileRow> {
  bool _pressed = false;
  void _setPressed(bool v) {
    if (_pressed != v) setState(() => _pressed = v);
  }
  @override
  Widget build(BuildContext context) {
    final child = widget.builder(_pressed);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: widget.onTap == null ? null : (_) => _setPressed(true),
      onTapUp: widget.onTap == null ? null : (_) => _setPressed(false),
      onTapCancel: widget.onTap == null ? null : () => _setPressed(false),
      onTap: widget.onTap == null
          ? null
          : () {
              if (widget.haptics && context.read<SettingsProvider>().hapticsOnListItemTap) Haptics.soft();
              widget.onTap!.call();
            },
      child: widget.pressedScale == 1.0
          ? child
          : AnimatedScale(
              scale: _pressed ? widget.pressedScale : 1.0,
              duration: const Duration(milliseconds: 120),
              curve: Curves.easeOutCubic,
              child: child,
            ),
    );
  }
}

Widget _iosNavRow(
  BuildContext context, {
  required IconData icon,
  required String label,
  VoidCallback? onTap,
  String? detailText,
  Widget Function(BuildContext ctx)? detailBuilder,
}) {
  final cs = Theme.of(context).colorScheme;
  final interactive = onTap != null;
  return _TactileRow(
    onTap: onTap,
    pressedScale: 1.00, // list rows: color shift only, no scale
    haptics: false,
    builder: (pressed) {
      final baseColor = cs.onSurface.withOpacity(0.9);
      return _AnimatedPressColor(
        pressed: pressed,
        base: baseColor,
        builder: (c) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            child: Row(
              children: [
                SizedBox(width: 36, child: Icon(icon, size: 20, color: c)),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(fontSize: 15, color: c),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (detailBuilder != null)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: DefaultTextStyle(
                      style: TextStyle(fontSize: 13, color: cs.onSurface.withOpacity(0.6)),
                      child: detailBuilder(context),
                    ),
                  )
                else if (detailText != null)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: Text(detailText, style: TextStyle(fontSize: 13, color: cs.onSurface.withOpacity(0.6))),
                  ),
                if (interactive) Icon(Lucide.ChevronRight, size: 16, color: c),
              ],
            ),
          );
        },
      );
    },
  );
}

Widget _iosNavRowSvgLeading(
  BuildContext context, {
  required String svgAsset,
  required String label,
  VoidCallback? onTap,
  String? detailText,
  Widget Function(BuildContext ctx)? detailBuilder,
}) {
  final cs = Theme.of(context).colorScheme;
  final interactive = onTap != null;
  return _TactileRow(
    onTap: onTap,
    pressedScale: 1.00,
    haptics: false,
    builder: (pressed) {
      final baseColor = cs.onSurface.withOpacity(0.9);
      return _AnimatedPressColor(
        pressed: pressed,
        base: baseColor,
        builder: (c) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            child: Row(
              children: [
                SizedBox(
                  width: 36,
                  child: SvgPicture.asset(
                    svgAsset,
                    width: 20,
                    height: 20,
                    colorFilter: ColorFilter.mode(c, BlendMode.srcIn),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(fontSize: 15, color: c),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (detailBuilder != null)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: DefaultTextStyle(
                      style: TextStyle(fontSize: 13, color: cs.onSurface.withOpacity(0.6)),
                      child: detailBuilder(context),
                    ),
                  )
                else if (detailText != null)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: Text(detailText, style: TextStyle(fontSize: 13, color: cs.onSurface.withOpacity(0.6))),
                  ),
                if (interactive) Icon(Lucide.ChevronRight, size: 16, color: c),
              ],
            ),
          );
        },
      );
    },
  );
}

// AppBar tactile icon button copied from provider detail page (with slight press scale)
class _TactileIconButton extends StatefulWidget {
  const _TactileIconButton({
    required this.icon,
    required this.color,
    required this.onTap,
    this.onLongPress,
    this.semanticLabel,
    this.size = 22,
    this.haptics = true,
  });

  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final String? semanticLabel;
  final double size;
  final bool haptics;

  @override
  State<_TactileIconButton> createState() => _TactileIconButtonState();
}

class _TactileIconButtonState extends State<_TactileIconButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final base = widget.color;
    final pressColor = base.withOpacity(0.7);
    final icon = Icon(widget.icon, size: widget.size, color: _pressed ? pressColor : base, semanticLabel: widget.semanticLabel);

    return Semantics(
      button: true,
      label: widget.semanticLabel,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        onTap: () {
          // Follow provider detail: no haptics on tap
          widget.onTap();
        },
        onLongPress: widget.onLongPress == null
            ? null
            : () {
                if (widget.haptics) Haptics.light();
                widget.onLongPress!.call();
              },
        child: AnimatedScale(
          scale: _pressed ? 0.95 : 1.0,
          duration: const Duration(milliseconds: 100),
          curve: Curves.easeOut,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
            child: icon,
          ),
        ),
      ),
    );
  }
}

class _TestButton extends StatelessWidget {
  const _TestButton({
    required this.label,
    required this.color,
    required this.onTap,
  });

  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: color.withValues(alpha: isDark ? 0.2 : 0.1),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: isDark ? color : color.withValues(alpha: 0.9),
            ),
          ),
        ),
      ),
    );
  }
}
