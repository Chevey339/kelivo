import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/settings_provider.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import '../../../icons/lucide_adapter.dart';
import '../../../l10n/app_localizations.dart';
import '../../../core/services/haptics.dart';

class SponsorPage extends StatefulWidget {
  const SponsorPage({super.key});

  @override
  State<SponsorPage> createState() => _SponsorPageState();
}

class _SponsorPageState extends State<SponsorPage> {
  late Future<_SponsorData> _future;

  @override
  void initState() {
    super.initState();
    _future = _fetchSponsors();
  }

  Future<_SponsorData> _fetchSponsors() async {
    final ts = DateTime.now().millisecondsSinceEpoch;
    final uri = Uri.parse('https://kelivo.psycheas.top/sponsor.json?kelivo=$ts');
    try {
      final res = await http.get(uri).timeout(const Duration(seconds: 12));
      if (res.statusCode >= 200 && res.statusCode < 300) {
        final obj = jsonDecode(res.body) as Map<String, dynamic>;
        final updatedAt = (obj['updatedAt'] as String?) ?? '';
        final list = (obj['sponsors'] as List?) ?? const [];
        final sponsors = <_Sponsor>[];
        for (final e in list) {
          if (e is Map<String, dynamic>) {
            final name = (e['name'] as String?)?.trim() ?? '';
            final avatar = (e['avatar'] as String?)?.trim() ?? '';
            final since = (e['since'] as String?)?.trim() ?? '';
            if (name.isEmpty || avatar.isEmpty) continue;
            sponsors.add(_Sponsor(name: name, avatar: avatar, since: since));
          }
        }
        return _SponsorData(updatedAt: updatedAt, sponsors: sponsors);
      }
    } catch (_) {}
    return const _SponsorData(updatedAt: '', sponsors: <_Sponsor>[]);
  }

  // iOS-style header (neutral color)
  Widget _header(BuildContext context, String text, {bool first = false}) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.fromLTRB(12, first ? 2 : 18, 12, 6),
      child: Text(text, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: cs.onSurface.withOpacity(0.8))),
    );
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url);
    try {
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        await launchUrl(uri, mode: LaunchMode.platformDefault);
      }
    } catch (_) {
      await launchUrl(uri);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
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
        title: Text(l10n.settingsPageSponsor),
        actions: const [SizedBox(width: 12)],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        children: [
          _header(context, l10n.sponsorPageMethodsSectionTitle, first: true),
          _iosSectionCard(children: [
            _iosNavRow(
              context,
              icon: Lucide.Heart,
              label: l10n.sponsorPageAfdianTitle,
              onTap: () async {
                final uri = Uri.parse('https://afdian.com/a/kelivo');
                if (!await launchUrl(uri, mode: LaunchMode.platformDefault)) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                }
              },
            ),
            _iosDivider(context),
            _iosNavRow(
              context,
              icon: Lucide.Link,
              label: l10n.sponsorPageWeChatTitle,
              onTap: () async {
                final uri = Uri.parse('https://c.img.dasctf.com/LightPicture/2024/12/6c2a6df245ed97b3.jpg');
                if (!await launchUrl(uri, mode: LaunchMode.platformDefault)) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                }
              },
            ),
          ]),

          const SizedBox(height: 12),
          _header(context, l10n.sponsorPageSponsorsSectionTitle),
          FutureBuilder<_SponsorData>(
            future: _future,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 40),
                  child: Center(
                    child: SizedBox(
                      width: 28,
                      height: 28,
                      child: CircularProgressIndicator(color: cs.primary, strokeWidth: 3),
                    ),
                  ),
                );
              }
              final data = snapshot.data ?? const _SponsorData(updatedAt: '', sponsors: <_Sponsor>[]);
              final sponsors = data.sponsors;
              if (sponsors.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 32),
                  child: Center(
                    child: Text(l10n.sponsorPageEmpty, style: TextStyle(color: cs.onSurface.withOpacity(0.6))),
                  ),
                );
              }
              return LayoutBuilder(
                builder: (context, constraints) {
                  final w = constraints.maxWidth;
                  // Aim ~5-6 avatars per row
                  int cross = (w >= 480) ? 6 : 5;
                  final itemSize = (w - 24 - (cross - 1) * 10) / cross; // 12 padding each side, 10 spacing
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                    child: GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: cross,
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                        childAspectRatio: itemSize / (52 + 28), // avatar 52 + space for name
                      ),
                      itemCount: sponsors.length,
                      itemBuilder: (context, i) {
                        final s = sponsors[i];
                        return _SponsorTile(s: s);
                      },
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }
}

class _Sponsor {
  final String name;
  final String avatar;
  final String since;
  const _Sponsor({required this.name, required this.avatar, required this.since});
}

class _SponsorData {
  final String updatedAt;
  final List<_Sponsor> sponsors;
  const _SponsorData({required this.updatedAt, required this.sponsors});
}

class _SponsorTile extends StatelessWidget {
  const _SponsorTile({required this.s});
  final _Sponsor s;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: cs.outlineVariant.withOpacity(0.4)),
          ),
          child: ClipOval(
            child: Image.network(
              s.avatar,
              fit: BoxFit.cover,
              width: 52,
              height: 52,
              errorBuilder: (_, __, ___) => Container(
                color: cs.surface,
                alignment: Alignment.center,
                child: Icon(Icons.person, color: cs.onSurface.withOpacity(0.5)),
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        SizedBox(
          height: 18,
          child: Text(
            s.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 12, color: cs.onSurface.withOpacity(0.9)),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }
}

// --- iOS-style helpers (mirroring Settings/Display/About) ---

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
  void _setPressed(bool v) { if (_pressed != v) setState(() => _pressed = v); }
  @override
  Widget build(BuildContext context) {
    final child = widget.builder(_pressed);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: widget.onTap == null ? null : (_) => _setPressed(true),
      onTapUp: widget.onTap == null ? null : (_) => _setPressed(false),
      onTapCancel: widget.onTap == null ? null : () => _setPressed(false),
      onTap: widget.onTap == null ? null : () {
        if (widget.haptics && context.read<SettingsProvider>().hapticsOnListItemTap) Haptics.soft();
        widget.onTap!.call();
      },
      child: widget.pressedScale == 1.0
          ? child
          : AnimatedScale(scale: _pressed ? widget.pressedScale : 1.0, duration: const Duration(milliseconds: 120), curve: Curves.easeOutCubic, child: child),
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
                SizedBox(width: 36, child: Icon(icon, size: 20, color: c)),
                const SizedBox(width: 12),
                Expanded(child: Text(label, style: TextStyle(fontSize: 15, color: c), maxLines: 1, overflow: TextOverflow.ellipsis)),
                if (detailBuilder != null)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: DefaultTextStyle(style: TextStyle(fontSize: 13, color: cs.onSurface.withOpacity(0.6)), child: detailBuilder(context)),
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
        onTap: () { /* no haptics on tap to match provider */ widget.onTap(); },
        onLongPress: widget.onLongPress == null ? null : () { if (widget.haptics) Haptics.light(); widget.onLongPress!.call(); },
        child: AnimatedScale(
          scale: _pressed ? 0.95 : 1.0,
          duration: const Duration(milliseconds: 100),
          curve: Curves.easeOut,
          child: Padding(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6), child: icon),
        ),
      ),
    );
  }
}
