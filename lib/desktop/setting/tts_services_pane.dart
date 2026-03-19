import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../icons/lucide_adapter.dart' as lucide;
import '../../l10n/app_localizations.dart';
import '../../core/providers/tts_provider.dart';
import '../../core/providers/settings_provider.dart';
import '../../core/services/tts/network_tts.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../utils/brand_assets.dart';

/// Desktop: TTS (语音服务) right-side pane
/// Adapts mobile TTS page to desktop with hoverable list card style
/// similar to DesktopSearchServicesPane.
class DesktopTtsServicesPane extends StatefulWidget {
  const DesktopTtsServicesPane({super.key});
  @override
  State<DesktopTtsServicesPane> createState() => _DesktopTtsServicesPaneState();
}

class _DesktopTtsServicesPaneState extends State<DesktopTtsServicesPane> {
  Future<void> _handleAddNetworkService() async {
    final settingsProvider = context.read<SettingsProvider>();
    final created = await _showAddNetworkDialog(context);
    if (created == null) {
      return;
    }
    final list = List<TtsServiceOptions>.from(settingsProvider.ttsServices)
      ..add(created);
    await settingsProvider.setTtsServices(list);
    if (settingsProvider.usingSystemTts) {
      await settingsProvider.setTtsServiceSelected(list.length - 1);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;

    return Container(
      alignment: Alignment.topCenter,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 960),
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 36,
                  child: Row(
                    children: [
                      Expanded(
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            l10n.ttsServicesPageTitle,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w400,
                              color: cs.onSurface.withValues(alpha: 0.9),
                            ),
                          ),
                        ),
                      ),
                      _SmallIconBtn(
                        icon: lucide.Lucide.Plus,
                        onTap: _handleAddNetworkService,
                      ),
                    ],
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 16)),

              // On desktop we do not provide System TTS (flutter_tts disabled)
              // so we skip the System TTS card entirely.
              const SliverToBoxAdapter(child: SizedBox(height: 8)),

              // Network TTS services list
              SliverToBoxAdapter(child: _NetworkTtsList()),
            ],
          ),
        ),
      ),
    );
  }
}

class _NetworkTtsList extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final sp = context.watch<SettingsProvider>();
    final services = sp.ttsServices;
    if (services.isEmpty) {
      final cs = Theme.of(context).colorScheme;
      final l10n = AppLocalizations.of(context)!;
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 40),
        alignment: Alignment.center,
        child: Text(
          l10n.ttsServicesPageNoNetworkServices,
          style: TextStyle(color: cs.onSurface.withValues(alpha: 0.6)),
        ),
      );
    }
    return Column(
      children: [
        for (int i = 0; i < services.length; i++)
          Padding(
            key: ValueKey('desktop-tts-service-${services[i].id}'),
            padding: const EdgeInsets.only(bottom: 12),
            child: _NetworkServiceCard(
              service: services[i],
              selected: sp.ttsServiceSelected == i,
              onTap: () async =>
                  context.read<SettingsProvider>().setTtsServiceSelected(i),
              onEdit: () async {
                final settingsProvider = context.read<SettingsProvider>();
                final updated = await _showEditNetworkDialog(
                  context,
                  services[i],
                );
                if (updated != null) {
                  final list = List<TtsServiceOptions>.from(
                    settingsProvider.ttsServices,
                  );
                  list[i] = updated;
                  await settingsProvider.setTtsServices(list);
                }
              },
              onDelete: () async {
                final sp = context.read<SettingsProvider>();
                final list = List<TtsServiceOptions>.from(sp.ttsServices);
                list.removeAt(i);
                await sp.setTtsServices(list);
                var idx = sp.ttsServiceSelected;
                if (idx >= list.length) {
                  idx = list.isEmpty ? -1 : list.length - 1;
                }
                await sp.setTtsServiceSelected(idx);
              },
            ),
          ),
      ],
    );
  }
}

class _NetworkServiceCard extends StatefulWidget {
  const _NetworkServiceCard({
    required this.service,
    required this.selected,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });
  final TtsServiceOptions service;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  @override
  State<_NetworkServiceCard> createState() => _NetworkServiceCardState();
}

class _NetworkServiceCardState extends State<_NetworkServiceCard> {
  bool _hover = false;
  bool _testing = false;
  String? _error;
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseBg = isDark
        ? Colors.white10
        : Colors.white.withValues(alpha: 0.96);
    final borderColor = _hover || widget.selected
        ? cs.primary.withValues(alpha: isDark ? 0.35 : 0.45)
        : cs.outlineVariant.withValues(alpha: isDark ? 0.12 : 0.08);
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          decoration: BoxDecoration(
            color: baseBg,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: borderColor, width: 1.0),
          ),
          padding: const EdgeInsets.all(14),
          constraints: const BoxConstraints(minHeight: 64),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _BrandIconBadge(
                    nameHint: widget.service.name.isNotEmpty
                        ? widget.service.name
                        : networkTtsKindDisplayName(widget.service.kind),
                    size: 24,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      widget.service.name.isNotEmpty
                          ? widget.service.name
                          : networkTtsKindDisplayName(widget.service.kind),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _SmallIconBtn(
                    icon: lucide.Lucide.Settings2,
                    onTap: widget.onEdit,
                  ),
                  const SizedBox(width: 6),
                  Tooltip(
                    message: AppLocalizations.of(
                      context,
                    )!.ttsServicesPageTestVoiceTooltip,
                    child: _SmallIconBtn(
                      icon: _testing
                          ? lucide.Lucide.Loader
                          : lucide.Lucide.Volume2,
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
                  ),
                  const SizedBox(width: 6),
                  _SmallIconBtn(
                    icon: lucide.Lucide.Trash2,
                    onTap: widget.onDelete,
                  ),
                  // no check icon on desktop
                ],
              ),
              if (_error != null && _error!.isNotEmpty) ...[
                const SizedBox(height: 8),
                _ErrorInline(message: _error!),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ErrorInline extends StatelessWidget {
  const _ErrorInline({required this.message});
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
            onPressed: () => _showErrorDialog(context, message),
            child: Text(l10n.ttsServicesViewDetailsButton),
          ),
        ],
      ),
    );
  }
}

void _showErrorDialog(BuildContext context, String message) {
  final cs = Theme.of(context).colorScheme;
  final l10n = AppLocalizations.of(context)!;
  showDialog<void>(
    context: context,
    builder: (ctx) => Dialog(
      backgroundColor: cs.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      l10n.ttsServicesDialogErrorTitle,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  _SmallIconBtn(
                    icon: lucide.Lucide.X,
                    onTap: () => Navigator.of(ctx).maybePop(),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              _deskDivider(ctx),
              const SizedBox(height: 10),
              // Make error content scrollable to avoid overflow
              Flexible(
                child: SingleChildScrollView(
                  child: SelectableText(
                    message,
                    style: TextStyle(
                      color: cs.onSurface.withValues(alpha: 0.9),
                      fontSize: 13,
                    ),
                  ),
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
      ),
    ),
  );
}

class _BrandIconBadge extends StatelessWidget {
  const _BrandIconBadge({required this.nameHint, this.size = 24});
  final String nameHint;
  final double size;
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? Colors.white12 : Colors.black.withValues(alpha: 0.06);
    final asset =
        BrandAssets.assetForName(nameHint) ??
        BrandAssets.assetForName(nameHint.split(' ').first);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
      alignment: Alignment.center,
      child: (asset == null)
          ? Text(
              nameHint.substring(0, 1).toUpperCase(),
              style: TextStyle(fontSize: size * 0.44, color: cs.onSurface),
            )
          : (asset.endsWith('.svg')
                ? SvgPicture.asset(
                    asset,
                    width: size * 0.62,
                    height: size * 0.62,
                  )
                : Image.asset(
                    asset,
                    width: size * 0.62,
                    height: size * 0.62,
                    fit: BoxFit.contain,
                  )),
    );
  }
}

class _SystemTtsCard extends StatefulWidget {
  @override
  State<_SystemTtsCard> createState() => _SystemTtsCardState();
}

class _SystemTtsCardState extends State<_SystemTtsCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context)!;
    final tts = context.watch<TtsProvider>();

    final baseBg = isDark
        ? Colors.white10
        : Colors.white.withValues(alpha: 0.96);
    final borderColor = _hover
        ? cs.primary.withValues(alpha: isDark ? 0.35 : 0.45)
        : cs.outlineVariant.withValues(alpha: isDark ? 0.12 : 0.08);

    final available = tts.isAvailable && (tts.error == null);
    final titleText = l10n.ttsServicesPageSystemTtsTitle;
    final subText = available
        ? l10n.ttsServicesPageSystemTtsAvailableSubtitle
        : l10n.ttsServicesPageSystemTtsUnavailableSubtitle(
            tts.error ?? l10n.ttsServicesPageSystemTtsUnavailableNotInitialized,
          );

    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () async {
          try {
            await context.read<SettingsProvider>().setTtsServiceSelected(-1);
          } catch (_) {}
        },
        child: Container(
          decoration: BoxDecoration(
            color: baseBg,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: borderColor, width: 1.0),
          ),
          padding: const EdgeInsets.all(14),
          constraints: const BoxConstraints(minHeight: 64),
          child: Row(
            children: [
              // Brand-like circular badge with a speaker icon
              _CircleIconBadge(icon: lucide.Lucide.Volume2, size: 24),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      titleText,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subText,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: cs.onSurface.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Tooltip(
                message: l10n.ttsServicesPageTestVoiceTooltip,
                child: _SmallIconBtn(
                  icon: tts.isSpeaking
                      ? lucide.Lucide.CircleStop
                      : lucide.Lucide.Volume2,
                  onTap: available
                      ? () async {
                          if (!tts.isSpeaking) {
                            final demo = l10n.ttsServicesPageTestSpeechText;
                            await context.read<TtsProvider>().speakSystem(demo);
                          } else {
                            await context.read<TtsProvider>().stop();
                          }
                        }
                      : () {},
                ),
              ),
              const SizedBox(width: 6),
              Tooltip(
                message: l10n.ttsServicesPageSystemTtsSettingsTitle,
                child: _SmallIconBtn(
                  icon: lucide.Lucide.Settings2,
                  onTap: () => _showSettingsDialog(context),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showSettingsDialog(BuildContext context) async {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final tts = context.read<TtsProvider>();
    double rate = tts.speechRate;
    double pitch = tts.pitch;
    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        return Dialog(
          backgroundColor: cs.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 18,
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          l10n.ttsServicesPageSystemTtsSettingsTitle,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      _SmallIconBtn(
                        icon: lucide.Lucide.X,
                        onTap: () => Navigator.of(ctx).maybePop(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  _deskDivider(context),
                  const SizedBox(height: 10),
                  // Engine selection
                  FutureBuilder<List<String>>(
                    future: tts.listEngines(),
                    builder: (context, snap) {
                      final engines = snap.data ?? const <String>[];
                      final cur =
                          tts.engineId ??
                          (engines.isNotEmpty ? engines.first : '');
                      return _SelectRow(
                        label: l10n.ttsServicesPageEngineLabel,
                        value: cur.isEmpty
                            ? l10n.ttsServicesPageAutoLabel
                            : cur,
                        options: engines,
                        onSelected: (picked) async {
                          await tts.setEngineId(picked);
                          if (ctx.mounted) (ctx as Element).markNeedsBuild();
                        },
                      );
                    },
                  ),
                  const SizedBox(height: 6),
                  // Language selection
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
                      return _SelectRow(
                        label: l10n.ttsServicesPageLanguageLabel,
                        value: cur.isEmpty
                            ? l10n.ttsServicesPageAutoLabel
                            : cur,
                        options: langs,
                        onSelected: (picked) async {
                          await tts.setLanguageTag(picked);
                          if (ctx.mounted) (ctx as Element).markNeedsBuild();
                        },
                      );
                    },
                  ),
                  const SizedBox(height: 10),
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
                      if (ctx.mounted) (ctx as Element).markNeedsBuild();
                    },
                    onChangeEnd: (v) async => tts.setSpeechRate(v),
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
                      if (ctx.mounted) (ctx as Element).markNeedsBuild();
                    },
                    onChangeEnd: (v) async => tts.setPitch(v),
                  ),
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: () => Navigator.of(ctx).maybePop(),
                      icon: const Icon(lucide.Lucide.Check, size: 16),
                      label: Text(l10n.ttsServicesPageDoneButton),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

// --------- Small UI helpers (local to this file) ---------

class _CircleIconBadge extends StatelessWidget {
  const _CircleIconBadge({required this.icon, this.size = 24});
  final IconData icon;
  final double size;
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? Colors.white12 : Colors.black.withValues(alpha: 0.06);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
      alignment: Alignment.center,
      child: Icon(
        icon,
        size: size * 0.62,
        color: cs.onSurface.withValues(alpha: 0.9),
      ),
    );
  }
}

class _SmallIconBtn extends StatefulWidget {
  const _SmallIconBtn({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;
  @override
  State<_SmallIconBtn> createState() => _SmallIconBtnState();
}

class _SmallIconBtnState extends State<_SmallIconBtn> {
  bool _hover = false;
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = _hover
        ? (isDark
              ? Colors.white.withValues(alpha: 0.06)
              : Colors.black.withValues(alpha: 0.05))
        : Colors.transparent;
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(8),
          ),
          alignment: Alignment.center,
          child: Icon(widget.icon, size: 18, color: cs.onSurface),
        ),
      ),
    );
  }
}

Widget _deskDivider(BuildContext context) {
  final cs = Theme.of(context).colorScheme;
  return Divider(
    height: 6,
    thickness: 0.6,
    indent: 12,
    endIndent: 12,
    color: cs.outlineVariant.withValues(alpha: 0.18),
  );
}

class _SelectRow extends StatelessWidget {
  const _SelectRow({
    required this.label,
    required this.value,
    required this.options,
    required this.onSelected,
  });
  final String label;
  final String value;
  final List<String> options;
  final ValueChanged<String> onSelected;
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 15,
                color: cs.onSurface.withValues(alpha: 0.9),
              ),
            ),
          ),
          _SelectButton(value: value, options: options, onSelected: onSelected),
        ],
      ),
    );
  }
}

class _SelectButton extends StatefulWidget {
  const _SelectButton({
    required this.value,
    required this.options,
    required this.onSelected,
  });
  final String value;
  final List<String> options;
  final ValueChanged<String> onSelected;
  @override
  State<_SelectButton> createState() => _SelectButtonState();
}

class _SelectButtonState extends State<_SelectButton> {
  bool _hover = false;
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = _hover
        ? (isDark
              ? Colors.white.withValues(alpha: 0.06)
              : Colors.black.withValues(alpha: 0.04))
        : Colors.transparent;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: () async {
          final picked = await _showOptionsDialog(
            context,
            widget.options,
            widget.value,
          );
          if (picked != null) widget.onSelected(picked);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: cs.outlineVariant.withValues(alpha: 0.12),
              width: 0.6,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.value,
                style: TextStyle(
                  fontSize: 14,
                  color: cs.onSurface.withValues(alpha: 0.9),
                ),
              ),
              const SizedBox(width: 6),
              Icon(
                lucide.Lucide.ChevronDown,
                size: 16,
                color: cs.onSurface.withValues(alpha: 0.8),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Future<String?> _showOptionsDialog(
  BuildContext context,
  List<String> options,
  String current,
) async {
  if (options.isEmpty) return null;
  final cs = Theme.of(context).colorScheme;
  String? result;
  await showDialog<String>(
    context: context,
    barrierDismissible: true,
    builder: (ctx) {
      return Dialog(
        backgroundColor: cs.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(ctx).size.height * 0.6,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (int i = 0; i < options.length; i++) ...[
                      _DialogOption(
                        label: options[i],
                        selected: options[i] == current,
                        onTap: () => Navigator.of(ctx).pop(options[i]),
                      ),
                      if (i != options.length - 1)
                        Divider(
                          height: 10,
                          thickness: 0.6,
                          indent: 4,
                          endIndent: 4,
                          color: cs.outlineVariant.withValues(alpha: 0.12),
                        ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    },
  ).then((v) => result = v);
  return result;
}

class _DialogOption extends StatefulWidget {
  const _DialogOption({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;
  @override
  State<_DialogOption> createState() => _DialogOptionState();
}

class _DialogOptionState extends State<_DialogOption> {
  bool _hover = false;
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = widget.selected
        ? cs.primary.withValues(alpha: 0.08)
        : (_hover
              ? (isDark
                    ? Colors.white.withValues(alpha: 0.06)
                    : Colors.black.withValues(alpha: 0.04))
              : Colors.transparent);
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  widget.label,
                  style: TextStyle(
                    fontSize: 14,
                    color: cs.onSurface.withValues(alpha: 0.9),
                  ),
                ),
              ),
              if (widget.selected)
                Icon(lucide.Lucide.Check, size: 16, color: cs.primary),
            ],
          ),
        ),
      ),
    );
  }
}

Future<TtsServiceOptions?> _showAddNetworkDialog(BuildContext context) =>
    _showNetworkDialog(context, null);

Future<TtsServiceOptions?> _showEditNetworkDialog(
  BuildContext context,
  TtsServiceOptions initial,
) => _showNetworkDialog(context, initial);

Future<TtsServiceOptions?> _showNetworkDialog(
  BuildContext context,
  TtsServiceOptions? initial,
) async {
  final cs = Theme.of(context).colorScheme;
  final l10n = AppLocalizations.of(context)!;
  NetworkTtsKind kind = initial?.kind ?? NetworkTtsKind.openai;
  final nameCtl = TextEditingController(text: initial?.name ?? '');
  // Common fields
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
  await showDialog<void>(
    context: context,
    barrierDismissible: true,
    builder: (ctx) {
      return Dialog(
        backgroundColor: cs.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: StatefulBuilder(
              builder: (ctx2, setState) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            initial == null
                                ? l10n.ttsServicesDialogAddTitle
                                : l10n.ttsServicesDialogEditTitle,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        _SmallIconBtn(
                          icon: lucide.Lucide.X,
                          onTap: () => Navigator.of(ctx).maybePop(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    _deskDivider(context),
                    const SizedBox(height: 10),
                    // Scrollable form area
                    Flexible(
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Provider kind
                            _SelectRow(
                              label: l10n.ttsServicesDialogProviderType,
                              value: networkTtsKindDisplayName(kind),
                              options: [
                                networkTtsKindDisplayName(
                                  NetworkTtsKind.openai,
                                ),
                                networkTtsKindDisplayName(
                                  NetworkTtsKind.gemini,
                                ),
                                networkTtsKindDisplayName(
                                  NetworkTtsKind.minimax,
                                ),
                                networkTtsKindDisplayName(
                                  NetworkTtsKind.elevenlabs,
                                ),
                              ],
                              onSelected: (picked) {
                                setState(() {
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
                                });
                              },
                            ),
                            const SizedBox(height: 6),
                            _InputRow(
                              label: l10n.ttsServicesFieldNameLabel,
                              controller: nameCtl,
                              hint: networkTtsKindDisplayName(kind),
                            ),
                            const SizedBox(height: 6),
                            _InputRow(
                              label: l10n.ttsServicesFieldApiKeyLabel,
                              controller: apiKeyCtl,
                              obscure: true,
                            ),
                            const SizedBox(height: 6),
                            _InputRow(
                              label: l10n.ttsServicesFieldBaseUrlLabel,
                              controller: baseCtl,
                              hint: _defaultBaseUrl(kind),
                            ),
                            const SizedBox(height: 6),
                            _InputRow(
                              label: l10n.ttsServicesFieldModelLabel,
                              controller: modelCtl,
                              hint: _defaultModel(kind),
                            ),
                            const SizedBox(height: 6),
                            _InputRow(
                              label: _voiceLabelFor(kind, l10n),
                              controller: voiceCtl,
                              hint: _defaultVoice(kind),
                            ),
                            if (kind == NetworkTtsKind.minimax) ...[
                              const SizedBox(height: 6),
                              _InputRow(
                                label: l10n.ttsServicesFieldEmotionLabel,
                                controller: emotionCtl,
                                hint: 'calm',
                              ),
                              const SizedBox(height: 6),
                              _InputRow(
                                label: l10n.ttsServicesFieldSpeedLabel,
                                controller: speedCtl,
                                hint: '1.0',
                              ),
                            ],
                            const SizedBox(height: 14),
                          ],
                        ),
                      ),
                    ),
                    // Actions
                    Align(
                      alignment: Alignment.centerRight,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          TextButton(
                            onPressed: () => Navigator.of(ctx).maybePop(),
                            style: TextButton.styleFrom(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                            ),
                            child: Text(l10n.ttsServicesDialogCancelButton),
                          ),
                          const SizedBox(width: 8),
                          FilledButton(
                            onPressed: () {
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
                              if (apiKey.isEmpty) return; // guard
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
                                    double.tryParse(speedCtl.text.trim()) ??
                                    1.0;
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
                                  modelId: model.isEmpty
                                      ? _defaultModel(kind)
                                      : model,
                                  voiceId: voice,
                                );
                              }
                              Navigator.of(ctx).pop();
                            },
                            style: FilledButton.styleFrom(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 10,
                              ),
                            ),
                            child: Text(
                              initial == null
                                  ? l10n.ttsServicesDialogAddButton
                                  : l10n.ttsServicesDialogSaveButton,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      );
    },
  ).then((_) {});
  return result;
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

class _InputRow extends StatelessWidget {
  const _InputRow({
    required this.label,
    required this.controller,
    this.hint,
    this.obscure = false,
  });
  final String label;
  final TextEditingController controller;
  final String? hint;
  final bool obscure;
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
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
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
