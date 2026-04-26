import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../icons/lucide_adapter.dart' as lucide;
import '../../l10n/app_localizations.dart';

class DesktopAboutPane extends StatefulWidget {
  const DesktopAboutPane({super.key});

  @override
  State<DesktopAboutPane> createState() => _DesktopAboutPaneState();
}

enum _InfoLoadState { loading, loaded, failed }

class _DesktopAboutPaneState extends State<DesktopAboutPane> {
  String _version = '';
  String _buildNumber = '';
  String _systemInfo = '';
  _InfoLoadState _infoLoadState = _InfoLoadState.loading;

  @override
  void initState() {
    super.initState();
    _loadInfo();
  }

  String _detectSystemId() {
    if (Platform.isMacOS) return 'macos';
    if (Platform.isWindows) return 'windows';
    if (Platform.isLinux) return 'linux';
    if (Platform.isAndroid) return 'android';
    if (Platform.isIOS) return 'ios';
    return Platform.operatingSystem;
  }

  Future<void> _loadInfo() async {
    try {
      final pkg = await PackageInfo.fromPlatform();
      final sys = _detectSystemId();
      if (!mounted) return;
      setState(() {
        _version = pkg.version;
        _buildNumber = pkg.buildNumber;
        _systemInfo = sys;
        _infoLoadState = _InfoLoadState.loaded;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _version = '';
        _buildNumber = '';
        _systemInfo = Platform.operatingSystem;
        _infoLoadState = _InfoLoadState.failed;
      });
    }
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url);
    try {
      if (!await launchUrl(uri, mode: LaunchMode.platformDefault)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (_) {
      await launchUrl(uri);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;

    String localizeSystem(String systemId) {
      switch (systemId) {
        case 'macos':
          return l10n.aboutPagePlatformMacos;
        case 'windows':
          return l10n.aboutPagePlatformWindows;
        case 'linux':
          return l10n.aboutPagePlatformLinux;
        case 'android':
          return l10n.aboutPagePlatformAndroid;
        case 'ios':
          return l10n.aboutPagePlatformIos;
      }
      return l10n.aboutPagePlatformOther(systemId);
    }

    final versionDetail = switch (_infoLoadState) {
      _InfoLoadState.loading => l10n.aboutPageLoadingPlaceholder,
      _InfoLoadState.failed => l10n.aboutPageUnknownPlaceholder,
      _InfoLoadState.loaded => l10n.aboutPageVersionDetail(
        _version,
        _buildNumber,
      ),
    };

    final systemDetail = _systemInfo.isEmpty
        ? (_infoLoadState == _InfoLoadState.loading
              ? l10n.aboutPageLoadingPlaceholder
              : l10n.aboutPageUnknownPlaceholder)
        : localizeSystem(_systemInfo);

    return Container(
      alignment: Alignment.topCenter,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 960),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                height: 36,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    l10n.settingsPageAbout,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                      color: cs.onSurface.withValues(alpha: 0.9),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),

              // App header
              _AppHeaderCard(description: l10n.aboutPageAppDescription),

              const SizedBox(height: 16),

              // Info and links
              _DeskCard(
                title: l10n.settingsPageAbout,
                children: [
                  _DeskInfoRow(
                    icon: lucide.Lucide.Code,
                    label: l10n.aboutPageVersion,
                    detail: versionDetail,
                  ),
                  const _DeskRowDivider(),
                  _DeskInfoRow(
                    icon: lucide.Lucide.Phone,
                    label: l10n.aboutPageSystem,
                    detail: systemDetail,
                  ),
                  const _DeskRowDivider(),
                  _DeskNavRow(
                    icon: lucide.Lucide.Earth,
                    label: l10n.aboutPageWebsite,
                    onTap: () => _openUrl('https://kelivo.psycheas.top/'),
                  ),
                  const _DeskRowDivider(),
                  _DeskNavRowSvg(
                    svgAsset: 'assets/icons/github.svg',
                    label: l10n.aboutPageGithub,
                    onTap: () =>
                        _openUrl('https://github.com/Chevey339/kelivo'),
                  ),
                  const _DeskRowDivider(),
                  _DeskNavRow(
                    icon: lucide.Lucide.FileText,
                    label: l10n.aboutPageLicense,
                    onTap: () => _openUrl(
                      'https://github.com/Chevey339/kelivo/blob/master/LICENSE',
                    ),
                  ),
                  const _DeskRowDivider(),
                  _DeskNavRowSvg(
                    svgAsset: 'assets/icons/tencent-qq.svg',
                    label: l10n.aboutPageJoinQQGroup,
                    onTap: () => _openUrl('https://qm.qq.com/q/OQaXetKssC'),
                  ),
                  const _DeskRowDivider(),
                  _DeskNavRowSvg(
                    svgAsset: 'assets/icons/discord.svg',
                    label: l10n.aboutPageJoinDiscord,
                    onTap: () => _openUrl('https://discord.gg/Tb8DyvvV5T'),
                  ),
                  const _DeskRowDivider(),
                  // Donation item (desktop): mirrors mobile "Sponsor"
                  _DeskNavRow(
                    icon: lucide.Lucide.Heart,
                    label: l10n.settingsPageSponsor,
                    onTap: () => _showSponsorDesktopDialog(context),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AppHeaderCard extends StatefulWidget {
  const _AppHeaderCard({required this.description});
  final String description;
  @override
  State<_AppHeaderCard> createState() => _AppHeaderCardState();
}

class _AppHeaderCardState extends State<_AppHeaderCard> {
  bool _hover = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseBg = isDark ? const Color(0xFF1C1C1E) : Colors.white;
    final hoverBg = isDark
        ? Colors.white.withValues(alpha: 0.06)
        : Colors.black.withValues(alpha: 0.04);
    final overlay = _hover ? hoverBg : Colors.transparent;
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        onTap: () {},
        child: AnimatedScale(
          scale: _pressed ? 0.995 : 1.0,
          duration: const Duration(milliseconds: 110),
          curve: Curves.easeOutCubic,
          child: DecoratedBox(
            decoration: ShapeDecoration(
              color: Color.alphaBlend(overlay, baseBg),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: BorderSide(
                  width: 0.5,
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.06)
                      : cs.outlineVariant.withValues(alpha: 0.12),
                ),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: SizedBox(
                      width: 54,
                      height: 54,
                      child: Image.asset(
                        'assets/app_icon.png',
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          l10n.aboutPageAppName,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.description,
                          style: TextStyle(
                            fontSize: 13,
                            color: cs.onSurface.withValues(alpha: 0.65),
                            height: 1.2,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
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
    );
  }
}

class _DeskCard extends StatelessWidget {
  const _DeskCard({required this.title, required this.children});
  final String title;
  final List<Widget> children;
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          width: 0.5,
          color: isDark
              ? Colors.white.withValues(alpha: 0.06)
              : cs.outlineVariant.withValues(alpha: 0.12),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 2, 4, 8),
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: cs.onSurface,
                ),
              ),
            ),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _DeskRowDivider extends StatelessWidget {
  const _DeskRowDivider();
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Divider(
        height: 1,
        thickness: 0.5,
        indent: 8,
        endIndent: 8,
        color: cs.outlineVariant.withValues(alpha: 0.12),
      ),
    );
  }
}

class _DeskInfoRow extends StatelessWidget {
  const _DeskInfoRow({
    required this.icon,
    required this.label,
    required this.detail,
  });
  final IconData icon;
  final String label;
  final String detail;
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Row(
        children: [
          SizedBox(
            width: 26,
            child: Icon(
              icon,
              size: 18,
              color: cs.onSurface.withValues(alpha: 0.9),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14.5,
                color: cs.onSurface.withValues(alpha: 0.92),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            detail,
            style: TextStyle(
              fontSize: 13,
              color: cs.onSurface.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }
}

class _DeskNavRow extends StatefulWidget {
  const _DeskNavRow({
    required this.icon,
    required this.label,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  @override
  State<_DeskNavRow> createState() => _DeskNavRowState();
}

class _DeskNavRowState extends State<_DeskNavRow> {
  bool _hover = false;
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hoverBg = isDark
        ? Colors.white.withValues(alpha: 0.06)
        : Colors.black.withValues(alpha: 0.05);
    final bg = _hover ? hoverBg : Colors.transparent;
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 26,
                child: Icon(
                  widget.icon,
                  size: 18,
                  color: cs.onSurface.withValues(alpha: 0.92),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  widget.label,
                  style: TextStyle(
                    fontSize: 14.5,
                    color: cs.onSurface.withValues(alpha: 0.92),
                  ),
                ),
              ),
              Icon(
                lucide.Lucide.ChevronRight,
                size: 16,
                color: cs.onSurface.withValues(alpha: 0.6),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DeskNavRowSvg extends StatefulWidget {
  const _DeskNavRowSvg({
    required this.svgAsset,
    required this.label,
    required this.onTap,
  });
  final String svgAsset;
  final String label;
  final VoidCallback onTap;
  @override
  State<_DeskNavRowSvg> createState() => _DeskNavRowSvgState();
}

class _DeskNavRowSvgState extends State<_DeskNavRowSvg> {
  bool _hover = false;
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hoverBg = isDark
        ? Colors.white.withValues(alpha: 0.06)
        : Colors.black.withValues(alpha: 0.05);
    final bg = _hover ? hoverBg : Colors.transparent;
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 26,
                child: SvgPicture.asset(
                  widget.svgAsset,
                  colorFilter: ColorFilter.mode(
                    cs.onSurface.withValues(alpha: 0.92),
                    BlendMode.srcIn,
                  ),
                  width: 18,
                  height: 18,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  widget.label,
                  style: TextStyle(
                    fontSize: 14.5,
                    color: cs.onSurface.withValues(alpha: 0.92),
                  ),
                ),
              ),
              Icon(
                lucide.Lucide.ChevronRight,
                size: 16,
                color: cs.onSurface.withValues(alpha: 0.6),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Future<void> _showSponsorDesktopDialog(BuildContext context) async {
  final cs = Theme.of(context).colorScheme;
  final l10n = AppLocalizations.of(context)!;
  final isDark = Theme.of(context).brightness == Brightness.dark;
  const afdianUrl = 'https://ifdian.net/a/kelivo';
  final wechatQrUrl = isDark
      ? 'https://c.img.dasctf.com/LightPicture/2025/10/ee10ae78acbd01f3.png'
      : 'https://c.img.dasctf.com/LightPicture/2025/10/6ba60ac0f2f8e2b4.png';

  Future<void> open(String url) async {
    final uri = Uri.parse(url);
    try {
      if (!await launchUrl(uri, mode: LaunchMode.platformDefault)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (_) {
      await launchUrl(uri);
    }
  }

  await showDialog<void>(
    context: context,
    barrierDismissible: true,
    builder: (ctx) {
      final isDark = Theme.of(ctx).brightness == Brightness.dark;
      return Dialog(
        backgroundColor: cs.surface,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        l10n.settingsPageSponsor,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: l10n.mcpPageClose,
                      icon: Icon(
                        lucide.Lucide.X,
                        size: 18,
                        color: cs.onSurface,
                      ),
                      onPressed: () => Navigator.of(ctx).maybePop(),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Methods card
                _DeskCard(
                  title: l10n.sponsorPageMethodsSectionTitle,
                  children: [
                    _DeskNavRow(
                      icon: lucide.Lucide.Heart,
                      label: l10n.sponsorPageAfdianTitle,
                      onTap: () => open(afdianUrl),
                    ),
                    const _DeskRowDivider(),
                    _DeskNavRow(
                      icon: lucide.Lucide.Link,
                      label: l10n.sponsorPageWeChatTitle,
                      onTap: () => open(wechatQrUrl),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // WeChat QR preview card (inline)
                _DeskCard(
                  title: l10n.sponsorPageWeChatTitle,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 8,
                      ),
                      child: Center(
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: cs.outlineVariant.withValues(
                                alpha: isDark ? 0.14 : 0.18,
                              ),
                            ),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: Image.network(
                            wechatQrUrl,
                            width: 220,
                            height: 220,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              width: 220,
                              height: 220,
                              color: cs.surface,
                              alignment: Alignment.center,
                              child: Icon(
                                lucide.Lucide.ImageOff,
                                color: cs.onSurface.withValues(alpha: 0.5),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                      child: Center(
                        child: Text(
                          l10n.sponsorPageScanQrHint,
                          style: TextStyle(
                            color: cs.onSurface.withValues(alpha: 0.6),
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 6),
                // Align(
                //   alignment: Alignment.centerRight,
                //   child: TextButton(
                //     onPressed: () => Navigator.of(ctx).maybePop(),
                //     child: Text(l10n.mcpPageClose, style: TextStyle(color: cs.primary)),
                //   ),
                // ),
              ],
            ),
          ),
        ),
      );
    },
  );
}
