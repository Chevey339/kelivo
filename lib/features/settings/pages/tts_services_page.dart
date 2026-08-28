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
import '../../../shared/widgets/ios_switch.dart';
import '../../../shared/widgets/ios_tile_button.dart';
import '../../../core/services/haptics.dart';
import 'tts_settings_page.dart';
import '../widgets/asr_services_section.dart';
import '../widgets/voice_service_widgets.dart';
import '../widgets/mimo_reference_audio_picker.dart';
import '../../../theme/app_font_weights.dart';
import 'package:Kelivo/theme/app_semantic_colors.dart';
import 'package:Kelivo/shared/widgets/section_card.dart';

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
            message: l10n.ttsServicesPageSettingsTooltip,
            child: _TactileIconButton(
              icon: Lucide.Settings2,
              color: cs.onSurface,
              size: 22,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const TtsSettingsPage(),
                ),
              ),
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
              VoiceServiceSectionHeader(
                title: l10n.ttsServicesSectionTitle,
                addTooltip: l10n.ttsServicesPageAddTooltip,
                onAdd: () => _handleAddNetworkTts(context),
                first: true,
              ),
              SectionCard(
                children: [
                  // System TTS as first row
                  _TactileRow(
                    pressedScale: 0.98,
                    haptics: false,
                    onTap: available
                        ? () async {
                            await sp.setSelectedTtsServiceId(null);
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
                              ? cs2.surface.withValues(
                                  alpha: isDark ? 0.06 : 0.05,
                                )
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
                                          fontWeight: AppFontWeights.semibold,
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
              const AsrServicesSection(),
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
        fontWeight: AppFontWeights.semibold,
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
    await sp.setSelectedTtsServiceId(created.id);
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
    final cs = Theme.of(context).colorScheme;
    final target = pressed
        ? (Color.lerp(base, cs.surface, 0.55) ?? base)
        : base;
    return TweenAnimationBuilder<Color?>(
      tween: ColorTween(end: target),
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      builder: (context, color, _) => builder(color ?? base),
    );
  }
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
    final baseBg = cs.primary.withValues(alpha: isDark ? 0.18 : 0.1);
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
              fontWeight: AppFontWeights.emphasis,
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
    final baseBg = cs.primary.withValues(alpha: isDark ? 0.18 : 0.1);
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
                    fontWeight: AppFontWeights.emphasis,
                    fontSize: 14,
                  ),
                )
              : (asset.endsWith('.svg')
                    ? SvgPicture.asset(
                        asset,
                        width: 20,
                        height: 20,
                        colorFilter:
                            isDark && BrandAssets.assetNeedsDarkInvert(asset)
                            ? ColorFilter.mode(cs.onSurface, BlendMode.srcIn)
                            : null,
                      )
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
              .setSelectedTtsServiceId(widget.service.id),
          builder: (pressed) {
            final base = cs.onSurface.withValues(alpha: 0.9);
            return _AnimatedPressColor(
              pressed: pressed,
              base: base,
              builder: (c) {
                final isDark = Theme.of(context).brightness == Brightness.dark;
                final overlay = pressed
                    ? cs.surface.withValues(alpha: isDark ? 0.06 : 0.05)
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
                            fontWeight: AppFontWeights.semibold,
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
                        },
                      ),
                      const SizedBox(width: 8),
                      Builder(
                        builder: (_) {
                          final sp2 = context.watch<SettingsProvider>();
                          final sel =
                              sp2.selectedTtsServiceId == widget.service.id;
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
    backgroundColor: context.overlaySurface,
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
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: AppFontWeights.emphasis,
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
    _showNetworkTtsEditorPage(context, null);

Future<TtsServiceOptions?> _showEditNetworkTtsSheet(
  BuildContext context,
  TtsServiceOptions initial,
) => _showNetworkTtsEditorPage(context, initial);

Future<TtsServiceOptions?> _showNetworkTtsEditorPage(
  BuildContext context,
  TtsServiceOptions? initial,
) {
  return Navigator.of(context).push<TtsServiceOptions>(
    MaterialPageRoute(builder: (_) => _NetworkTtsEditorPage(initial: initial)),
  );
}

class _NetworkTtsEditorPage extends StatefulWidget {
  const _NetworkTtsEditorPage({this.initial});

  final TtsServiceOptions? initial;

  @override
  State<_NetworkTtsEditorPage> createState() => _NetworkTtsEditorPageState();
}

class _NetworkTtsEditorPageState extends State<_NetworkTtsEditorPage> {
  final _formKey = GlobalKey<FormState>();
  late NetworkTtsKind _kind;
  late final TextEditingController _nameCtl;
  late final TextEditingController _apiKeyCtl;
  late final TextEditingController _baseCtl;
  late final TextEditingController _modelCtl;
  late final TextEditingController _voiceCtl;
  late final TextEditingController _emotionCtl;
  late final TextEditingController _speedCtl;
  late final TextEditingController _languageTypeCtl;
  late final TextEditingController _languageCtl;
  late final TextEditingController _volumeCtl;
  late final TextEditingController _pitchCtl;
  late final TextEditingController _languageBoostCtl;
  late final TextEditingController _formatCtl;
  late final TextEditingController _sampleRateCtl;
  late final TextEditingController _bitrateCtl;
  late final TextEditingController _channelCtl;
  late final TextEditingController _pronunciationCtl;
  late final TextEditingController _regionCtl;
  late final TextEditingController _instructionCtl;
  late final TextEditingController _outputFormatCtl;
  late final TextEditingController _temperatureCtl;
  late final TextEditingController _topPCtl;
  late final TextEditingController _latencyCtl;
  late bool _subtitleEnable;
  late bool _stream;
  late bool _optimizeTextPreview;

  bool get _isMimoVoiceDesign =>
      _kind == NetworkTtsKind.mimo &&
      _modelCtl.text.trim() == 'mimo-v2.5-tts-voicedesign';

  bool get _isMimoVoiceClone =>
      _kind == NetworkTtsKind.mimo &&
      _modelCtl.text.trim() == 'mimo-v2.5-tts-voiceclone';

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    _kind = initial?.kind ?? NetworkTtsKind.openai;
    _nameCtl = TextEditingController(text: initial?.name ?? '');
    _apiKeyCtl = TextEditingController(text: _apiKeyOf(initial));
    _baseCtl = TextEditingController(text: _baseUrlOf(initial));
    _modelCtl = TextEditingController(text: _modelOf(initial));
    _voiceCtl = TextEditingController(text: _voiceOf(initial));
    _emotionCtl = TextEditingController(
      text: (initial is MiniMaxTtsOptions) ? initial.emotion : '',
    );
    _speedCtl = TextEditingController(
      text: initial is MiniMaxTtsOptions
          ? initial.speed.toString()
          : initial is StepTtsOptions
          ? initial.speed.toString()
          : initial is FishAudioTtsOptions
          ? initial.speed.toString()
          : '1.0',
    );
    _languageTypeCtl = TextEditingController(
      text: (initial is QwenTtsOptions) ? initial.languageType : 'Auto',
    );
    _languageCtl = TextEditingController(
      text: initial is XaiTtsOptions
          ? initial.language
          : initial is AzureTtsOptions
          ? initial.language
          : 'auto',
    );
    _volumeCtl = TextEditingController(
      text: initial is MiniMaxTtsOptions
          ? initial.volume.toString()
          : initial is StepTtsOptions
          ? initial.volume.toString()
          : '1.0',
    );
    _pitchCtl = TextEditingController(
      text: initial is MiniMaxTtsOptions ? initial.pitch.toString() : '0',
    );
    _languageBoostCtl = TextEditingController(
      text: initial is MiniMaxTtsOptions ? initial.languageBoost : '',
    );
    _formatCtl = TextEditingController(
      text: initial is MiniMaxTtsOptions
          ? initial.format
          : initial is QwenAudioTtsOptions
          ? initial.format
          : initial is FishAudioTtsOptions
          ? initial.format
          : 'mp3',
    );
    _sampleRateCtl = TextEditingController(
      text: initial is MiniMaxTtsOptions
          ? initial.sampleRate.toString()
          : initial is QwenAudioTtsOptions
          ? initial.sampleRate.toString()
          : initial is StepTtsOptions
          ? initial.sampleRate.toString()
          : initial is FishAudioTtsOptions
          ? initial.sampleRate.toString()
          : '32000',
    );
    _bitrateCtl = TextEditingController(
      text: initial is MiniMaxTtsOptions
          ? initial.bitrate.toString()
          : '128000',
    );
    _channelCtl = TextEditingController(
      text: initial is MiniMaxTtsOptions ? initial.channel.toString() : '1',
    );
    _pronunciationCtl = TextEditingController(
      text: initial is MiniMaxTtsOptions
          ? initial.pronunciationDictionary.join('\n')
          : '',
    );
    _regionCtl = TextEditingController(
      text: initial is QwenAudioTtsOptions ? initial.region : 'cn-beijing',
    );
    _instructionCtl = TextEditingController(
      text: initial is MimoTtsOptions
          ? initial.instruction
          : initial is StepTtsOptions
          ? initial.instruction
          : '',
    );
    _outputFormatCtl = TextEditingController(
      text: initial is ElevenLabsTtsOptions
          ? initial.outputFormat
          : initial is StepTtsOptions
          ? initial.responseFormat
          : 'mp3_44100_128',
    );
    _temperatureCtl = TextEditingController(
      text: initial is FishAudioTtsOptions
          ? initial.temperature.toString()
          : '0.7',
    );
    _topPCtl = TextEditingController(
      text: initial is FishAudioTtsOptions ? initial.topP.toString() : '0.7',
    );
    _latencyCtl = TextEditingController(
      text: initial is FishAudioTtsOptions ? initial.latency : 'normal',
    );
    _subtitleEnable = initial is MiniMaxTtsOptions
        ? initial.subtitleEnable
        : false;
    _stream = initial is MimoTtsOptions ? initial.stream : true;
    _optimizeTextPreview = initial is MimoTtsOptions
        ? initial.optimizeTextPreview
        : false;
  }

  @override
  void dispose() {
    _nameCtl.dispose();
    _apiKeyCtl.dispose();
    _baseCtl.dispose();
    _modelCtl.dispose();
    _voiceCtl.dispose();
    _emotionCtl.dispose();
    _speedCtl.dispose();
    _languageTypeCtl.dispose();
    _languageCtl.dispose();
    _volumeCtl.dispose();
    _pitchCtl.dispose();
    _languageBoostCtl.dispose();
    _formatCtl.dispose();
    _sampleRateCtl.dispose();
    _bitrateCtl.dispose();
    _channelCtl.dispose();
    _pronunciationCtl.dispose();
    _regionCtl.dispose();
    _instructionCtl.dispose();
    _outputFormatCtl.dispose();
    _temperatureCtl.dispose();
    _topPCtl.dispose();
    _latencyCtl.dispose();
    super.dispose();
  }

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
        title: Text(
          widget.initial == null
              ? l10n.ttsServicesDialogAddTitle
              : l10n.ttsServicesDialogEditTitle,
        ),
        actions: [
          Tooltip(
            message: widget.initial == null
                ? l10n.ttsServicesDialogAddButton
                : l10n.ttsServicesDialogSaveButton,
            child: _TactileIconButton(
              icon: Lucide.Check,
              color: cs.onSurface,
              size: 22,
              onTap: _submit,
            ),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                  children: [
                    _header(
                      context,
                      l10n.ttsServicesDialogProviderType,
                      first: true,
                    ),
                    SectionCard(
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                          child: _ProviderKindWrap(
                            value: _kind,
                            onChanged: _changeKind,
                          ),
                        ),
                      ],
                    ),
                    _header(context, l10n.ttsServicesPageTitle),
                    SectionCard(
                      children: [
                        _TtsEditorTextField(
                          label: l10n.ttsServicesFieldNameLabel,
                          controller: _nameCtl,
                          hint: networkTtsKindDisplayName(_kind),
                        ),
                        _TtsEditorTextField(
                          label: l10n.ttsServicesFieldApiKeyLabel,
                          controller: _apiKeyCtl,
                          obscure: true,
                        ),
                        _TtsEditorTextField(
                          label: _kind == NetworkTtsKind.qwenAudio
                              ? l10n.ttsServicesFieldWorkspaceIdLabel
                              : l10n.ttsServicesFieldBaseUrlLabel,
                          controller: _baseCtl,
                          hint: _kind == NetworkTtsKind.qwenAudio
                              ? null
                              : _kind == NetworkTtsKind.azure
                              ? 'https://<region>.tts.speech.microsoft.com'
                              : _defaultBaseUrl(_kind),
                        ),
                        if (_kind != NetworkTtsKind.xai &&
                            _kind != NetworkTtsKind.azure)
                          _TtsEditorTextField(
                            label: l10n.ttsServicesFieldModelLabel,
                            controller: _modelCtl,
                            hint: _defaultModel(_kind),
                            onChanged: _kind == NetworkTtsKind.mimo
                                ? (_) => setState(() {})
                                : null,
                          ),
                        if (!_isMimoVoiceDesign)
                          _TtsEditorTextField(
                            label: _isMimoVoiceClone
                                ? l10n.ttsServicesFieldReferenceAudioLabel
                                : _voiceLabelFor(_kind, l10n),
                            controller: _voiceCtl,
                            hint: _defaultVoice(_kind),
                          ),
                        if (_isMimoVoiceClone)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
                            child: SizedBox(
                              width: double.infinity,
                              child: IosTileButton(
                                label: l10n
                                    .ttsServicesFieldChooseReferenceAudioButton,
                                icon: Lucide.FileText,
                                onTap: _pickMimoReferenceAudio,
                              ),
                            ),
                          ),
                        if (_kind == NetworkTtsKind.minimax) ...[
                          _TtsEditorSelectField(
                            label: l10n.ttsServicesFieldEmotionLabel,
                            value: _emotionCtl.text,
                            options: miniMaxEmotionValues,
                            labelFor: (value) => value.isEmpty
                                ? l10n.ttsServicesEmotionAutoLabel
                                : value,
                            onChanged: (value) =>
                                setState(() => _emotionCtl.text = value),
                          ),
                          _TtsEditorTextField(
                            label: l10n.ttsServicesFieldSpeedLabel,
                            controller: _speedCtl,
                            hint: '1.0',
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                          ),
                          _TtsEditorTextField(
                            label: l10n.ttsServicesFieldVolumeLabel,
                            controller: _volumeCtl,
                            hint: '1.0',
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                          ),
                          _TtsEditorTextField(
                            label: l10n.ttsServicesFieldPitchLabel,
                            controller: _pitchCtl,
                            hint: '0',
                            keyboardType: TextInputType.number,
                          ),
                          _TtsEditorTextField(
                            label: l10n.ttsServicesFieldLanguageBoostLabel,
                            controller: _languageBoostCtl,
                            hint: 'auto',
                          ),
                          _TtsEditorSelectField(
                            label: l10n.ttsServicesFieldFormatLabel,
                            value: _formatCtl.text,
                            options: miniMaxAudioFormats,
                            onChanged: (value) =>
                                setState(() => _formatCtl.text = value),
                          ),
                          _TtsEditorSelectField(
                            label: l10n.ttsServicesFieldSampleRateLabel,
                            value: _sampleRateCtl.text,
                            options: miniMaxSampleRates
                                .map((value) => value.toString())
                                .toList(growable: false),
                            onChanged: (value) =>
                                setState(() => _sampleRateCtl.text = value),
                          ),
                          _TtsEditorSelectField(
                            label: l10n.ttsServicesFieldBitrateLabel,
                            value: _bitrateCtl.text,
                            options: miniMaxBitrates
                                .map((value) => value.toString())
                                .toList(growable: false),
                            onChanged: (value) =>
                                setState(() => _bitrateCtl.text = value),
                          ),
                          _TtsEditorSelectField(
                            label: l10n.ttsServicesFieldChannelLabel,
                            value: _channelCtl.text,
                            options: const <String>['1', '2'],
                            onChanged: (value) =>
                                setState(() => _channelCtl.text = value),
                          ),
                          _TtsEditorTextField(
                            label: l10n
                                .ttsServicesFieldPronunciationDictionaryLabel,
                            controller: _pronunciationCtl,
                            maxLines: 3,
                          ),
                        ],
                        if (_kind == NetworkTtsKind.qwen) ...[
                          _TtsEditorTextField(
                            label: l10n.ttsServicesFieldLanguageTypeLabel,
                            controller: _languageTypeCtl,
                            hint: 'Auto',
                          ),
                        ],
                        if (_kind == NetworkTtsKind.xai ||
                            _kind == NetworkTtsKind.azure) ...[
                          _TtsEditorTextField(
                            label: l10n.ttsServicesFieldLanguageLabel,
                            controller: _languageCtl,
                            hint: _kind == NetworkTtsKind.azure
                                ? 'zh-CN'
                                : 'auto',
                          ),
                        ],
                        if (_kind == NetworkTtsKind.elevenlabs) ...[
                          _TtsEditorTextField(
                            label: l10n.ttsServicesFieldOutputFormatLabel,
                            controller: _outputFormatCtl,
                            hint: 'mp3_44100_128',
                          ),
                        ],
                        if (_kind == NetworkTtsKind.mimo) ...[
                          _TtsEditorTextField(
                            label: l10n.ttsServicesFieldInstructionLabel,
                            controller: _instructionCtl,
                            maxLines: 3,
                          ),
                          _TtsEditorSwitchField(
                            label: l10n.ttsServicesFieldStreamingLabel,
                            value: _stream,
                            onChanged: (value) =>
                                setState(() => _stream = value),
                          ),
                          if (_isMimoVoiceDesign)
                            _TtsEditorSwitchField(
                              label:
                                  l10n.ttsServicesFieldOptimizeTextPreviewLabel,
                              value: _optimizeTextPreview,
                              onChanged: (value) =>
                                  setState(() => _optimizeTextPreview = value),
                            ),
                        ],
                        if (_kind == NetworkTtsKind.qwenAudio) ...[
                          _TtsEditorTextField(
                            label: l10n.ttsServicesFieldRegionLabel,
                            controller: _regionCtl,
                            hint: 'cn-beijing',
                          ),
                          _TtsEditorSelectField(
                            label: l10n.ttsServicesFieldFormatLabel,
                            value: _formatCtl.text,
                            options: const <String>['mp3', 'wav', 'pcm'],
                            onChanged: (value) =>
                                setState(() => _formatCtl.text = value),
                          ),
                          _TtsEditorTextField(
                            label: l10n.ttsServicesFieldSampleRateLabel,
                            controller: _sampleRateCtl,
                            keyboardType: TextInputType.number,
                          ),
                        ],
                        if (_kind == NetworkTtsKind.step) ...[
                          _TtsEditorSelectField(
                            label: l10n.ttsServicesFieldOutputFormatLabel,
                            value: _outputFormatCtl.text,
                            options: const <String>['mp3', 'wav', 'pcm'],
                            onChanged: (value) =>
                                setState(() => _outputFormatCtl.text = value),
                          ),
                          _TtsEditorTextField(
                            label: l10n.ttsServicesFieldSpeedLabel,
                            controller: _speedCtl,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                          ),
                          _TtsEditorTextField(
                            label: l10n.ttsServicesFieldVolumeLabel,
                            controller: _volumeCtl,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                          ),
                          _TtsEditorTextField(
                            label: l10n.ttsServicesFieldSampleRateLabel,
                            controller: _sampleRateCtl,
                            keyboardType: TextInputType.number,
                          ),
                          _TtsEditorTextField(
                            label: l10n.ttsServicesFieldInstructionLabel,
                            controller: _instructionCtl,
                            maxLines: 3,
                          ),
                        ],
                        if (_kind == NetworkTtsKind.fishAudio) ...[
                          _TtsEditorSelectField(
                            label: l10n.ttsServicesFieldFormatLabel,
                            value: _formatCtl.text,
                            options: fishAudioSampleRates.keys.toList(
                              growable: false,
                            ),
                            onChanged: (value) {
                              final allowed = fishAudioSampleRates[value]!;
                              setState(() {
                                _formatCtl.text = value;
                                if (!allowed.contains(
                                  int.tryParse(_sampleRateCtl.text),
                                )) {
                                  _sampleRateCtl.text = allowed.last.toString();
                                }
                              });
                            },
                          ),
                          _TtsEditorTextField(
                            label: l10n.ttsServicesFieldTemperatureLabel,
                            controller: _temperatureCtl,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                          ),
                          _TtsEditorTextField(
                            label: l10n.ttsServicesFieldTopPLabel,
                            controller: _topPCtl,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                          ),
                          _TtsEditorTextField(
                            label: l10n.ttsServicesFieldSpeedLabel,
                            controller: _speedCtl,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                          ),
                          _TtsEditorSelectField(
                            label: l10n.ttsServicesFieldSampleRateLabel,
                            value: _sampleRateCtl.text,
                            options:
                                (fishAudioSampleRates[_formatCtl.text] ??
                                        const <int>[44100])
                                    .map((value) => value.toString())
                                    .toList(growable: false),
                            onChanged: (value) =>
                                setState(() => _sampleRateCtl.text = value),
                          ),
                          _TtsEditorTextField(
                            label: l10n.ttsServicesFieldLatencyLabel,
                            controller: _latencyCtl,
                            hint: 'normal',
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: SizedBox(
                  width: double.infinity,
                  child: IosTileButton(
                    label: widget.initial == null
                        ? l10n.ttsServicesDialogAddButton
                        : l10n.ttsServicesDialogSaveButton,
                    icon: Lucide.Check,
                    onTap: _submit,
                    backgroundColor: cs.primary,
                    foregroundColor: cs.primary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _submit() {
    final l10n = AppLocalizations.of(context)!;
    if (_apiKeyCtl.text.trim().isEmpty) {
      showAppSnackBar(
        context,
        message: l10n.ttsServicesValidationApiKeyRequired,
        type: NotificationType.error,
      );
      return;
    }
    if (_kind == NetworkTtsKind.azure &&
        !isValidAzureTtsEndpoint(_baseCtl.text)) {
      showAppSnackBar(
        context,
        message: l10n.searchServicesAddDialogUrlRequired,
        type: NotificationType.error,
      );
      return;
    }
    if ((_kind == NetworkTtsKind.fishAudio || _isMimoVoiceClone) &&
        _voiceCtl.text.trim().isEmpty) {
      showAppSnackBar(
        context,
        message: l10n.ttsServicesValidationReferenceIdRequired,
        type: NotificationType.error,
      );
      return;
    }
    if (_isMimoVoiceDesign && _instructionCtl.text.trim().isEmpty) {
      showAppSnackBar(
        context,
        message: l10n.ttsServicesValidationInstructionRequired,
        type: NotificationType.error,
      );
      return;
    }
    if (_kind == NetworkTtsKind.fishAudio) {
      final allowed = fishAudioSampleRates[_formatCtl.text] ?? const <int>[];
      final sampleRate = int.tryParse(_sampleRateCtl.text);
      if (!allowed.contains(sampleRate)) {
        showAppSnackBar(
          context,
          message: AppLocalizations.of(context)!
              .ttsServicesValidationSampleRate(
                _formatCtl.text,
                allowed.join(', '),
              ),
          type: NotificationType.error,
        );
        return;
      }
    }
    Navigator.of(context).pop(_buildOptions());
  }

  Future<void> _pickMimoReferenceAudio() async {
    try {
      final dataUri = await pickMimoReferenceAudioDataUri();
      if (dataUri == null || !mounted) return;
      setState(() => _voiceCtl.text = dataUri);
    } catch (error) {
      if (!mounted) return;
      showAppSnackBar(
        context,
        message: error.toString(),
        type: NotificationType.error,
      );
    }
  }

  void _changeKind(NetworkTtsKind kind) {
    if (_kind == kind) return;
    setState(() => _kind = kind);
    _baseCtl.text = kind == NetworkTtsKind.qwenAudio
        ? ''
        : _defaultBaseUrl(kind);
    _modelCtl.text = _defaultModel(kind);
    _voiceCtl.text = _defaultVoice(kind);
    _languageCtl.text = kind == NetworkTtsKind.azure ? 'zh-CN' : 'auto';
    _emotionCtl.text = '';
    _speedCtl.text = '1.0';
    _volumeCtl.text = '1.0';
    _pitchCtl.text = '0';
    _languageBoostCtl.clear();
    _formatCtl.text = 'mp3';
    _sampleRateCtl.text = switch (kind) {
      NetworkTtsKind.qwenAudio => '22050',
      NetworkTtsKind.step => '24000',
      _ => '32000',
    };
    _bitrateCtl.text = '128000';
    _channelCtl.text = '1';
    _pronunciationCtl.clear();
    _regionCtl.text = 'cn-beijing';
    _instructionCtl.clear();
    _outputFormatCtl.text = switch (kind) {
      NetworkTtsKind.elevenlabs => 'mp3_44100_128',
      _ => 'mp3',
    };
    _temperatureCtl.text = '0.7';
    _topPCtl.text = '0.7';
    _latencyCtl.text = 'normal';
    _subtitleEnable = false;
    _stream = true;
    _optimizeTextPreview = false;
    if (mounted) setState(() {});
  }

  TtsServiceOptions _buildOptions() {
    final initial = widget.initial;
    final name = _nameCtl.text.trim().isEmpty
        ? networkTtsKindDisplayName(_kind)
        : _nameCtl.text.trim();
    final apiKey = _apiKeyCtl.text.trim();
    final base = _baseCtl.text.trim().isEmpty
        ? _defaultBaseUrl(_kind)
        : _baseCtl.text.trim();
    final model = _modelCtl.text.trim().isEmpty
        ? _defaultModel(_kind)
        : _modelCtl.text.trim();
    final rawVoice = _voiceCtl.text.trim();
    final voice = rawVoice.isEmpty ? _defaultVoice(_kind) : rawVoice;
    switch (_kind) {
      case NetworkTtsKind.openai:
        return OpenAiTtsOptions(
          id: initial?.id,
          enabled: true,
          name: name,
          apiKey: apiKey,
          baseUrl: base,
          model: model,
          voice: voice,
        );
      case NetworkTtsKind.gemini:
        return GeminiTtsOptions(
          id: initial?.id,
          enabled: true,
          name: name,
          apiKey: apiKey,
          baseUrl: base,
          model: model,
          voiceName: voice,
        );
      case NetworkTtsKind.azure:
        return AzureTtsOptions(
          id: initial?.id,
          enabled: true,
          name: name,
          apiKey: apiKey,
          baseUrl: base,
          language: _languageCtl.text.trim().isEmpty
              ? 'zh-CN'
              : _languageCtl.text.trim(),
          voice: voice,
        );
      case NetworkTtsKind.minimax:
        return MiniMaxTtsOptions(
          id: initial?.id,
          enabled: true,
          name: name,
          apiKey: apiKey,
          baseUrl: base,
          model: model,
          voiceId: voice,
          emotion: _emotionCtl.text.trim(),
          speed: double.tryParse(_speedCtl.text.trim()) ?? 1.0,
          volume: double.tryParse(_volumeCtl.text.trim()) ?? 1.0,
          pitch: int.tryParse(_pitchCtl.text.trim()) ?? 0,
          languageBoost: _languageBoostCtl.text.trim(),
          format: _formatCtl.text.trim(),
          sampleRate: int.tryParse(_sampleRateCtl.text.trim()) ?? 32000,
          bitrate: int.tryParse(_bitrateCtl.text.trim()) ?? 128000,
          channel: int.tryParse(_channelCtl.text.trim()) ?? 1,
          subtitleEnable: _subtitleEnable,
          pronunciationDictionary: _pronunciationCtl.text
              .split('\n')
              .map((value) => value.trim())
              .where((value) => value.isNotEmpty)
              .toList(growable: false),
        );
      case NetworkTtsKind.qwen:
        return QwenTtsOptions(
          id: initial?.id,
          enabled: true,
          name: name,
          apiKey: apiKey,
          baseUrl: base,
          model: model,
          voice: voice,
          languageType: _languageTypeCtl.text.trim().isEmpty
              ? 'Auto'
              : _languageTypeCtl.text.trim(),
        );
      case NetworkTtsKind.groq:
        return GroqTtsOptions(
          id: initial?.id,
          enabled: true,
          name: name,
          apiKey: apiKey,
          baseUrl: base,
          model: model,
          voice: voice,
        );
      case NetworkTtsKind.xai:
        return XaiTtsOptions(
          id: initial?.id,
          enabled: true,
          name: name,
          apiKey: apiKey,
          baseUrl: base,
          voiceId: voice,
          language: _languageCtl.text.trim().isEmpty
              ? 'auto'
              : _languageCtl.text.trim(),
        );
      case NetworkTtsKind.elevenlabs:
        return ElevenLabsTtsOptions(
          id: initial?.id,
          enabled: true,
          name: name,
          apiKey: apiKey,
          baseUrl: base,
          modelId: model,
          voiceId: voice,
          outputFormat: _outputFormatCtl.text.trim().isEmpty
              ? 'mp3_44100_128'
              : _outputFormatCtl.text.trim(),
        );
      case NetworkTtsKind.mimo:
        return MimoTtsOptions(
          id: initial?.id,
          enabled: true,
          name: name,
          apiKey: apiKey,
          baseUrl: base,
          model: model,
          voice: model == 'mimo-v2.5-tts-voicedesign' ? '' : voice,
          instruction: _instructionCtl.text.trim(),
          stream: _stream,
          optimizeTextPreview: _optimizeTextPreview,
        );
      case NetworkTtsKind.qwenAudio:
        return QwenAudioTtsOptions(
          id: initial?.id,
          enabled: true,
          name: name,
          apiKey: apiKey,
          workspaceId: base == _defaultBaseUrl(_kind) ? '' : base,
          region: _regionCtl.text.trim().isEmpty
              ? 'cn-beijing'
              : _regionCtl.text.trim(),
          model: model,
          voice: voice,
          format: _formatCtl.text.trim().isEmpty
              ? 'mp3'
              : _formatCtl.text.trim(),
          sampleRate: int.tryParse(_sampleRateCtl.text.trim()) ?? 22050,
        );
      case NetworkTtsKind.step:
        return StepTtsOptions(
          id: initial?.id,
          enabled: true,
          name: name,
          apiKey: apiKey,
          baseUrl: base,
          model: model,
          voice: voice,
          responseFormat:
              _outputFormatCtl.text.trim().isEmpty ||
                  _outputFormatCtl.text.contains('_')
              ? 'mp3'
              : _outputFormatCtl.text.trim(),
          speed: double.tryParse(_speedCtl.text.trim()) ?? 1.0,
          volume: double.tryParse(_volumeCtl.text.trim()) ?? 1.0,
          sampleRate: int.tryParse(_sampleRateCtl.text.trim()) ?? 24000,
          instruction: _instructionCtl.text.trim(),
        );
      case NetworkTtsKind.fishAudio:
        return FishAudioTtsOptions(
          id: initial?.id,
          enabled: true,
          name: name,
          apiKey: apiKey,
          baseUrl: base,
          model: model,
          referenceId: voice,
          format: _formatCtl.text.trim().isEmpty
              ? 'mp3'
              : _formatCtl.text.trim(),
          temperature: double.tryParse(_temperatureCtl.text.trim()) ?? 0.7,
          topP: double.tryParse(_topPCtl.text.trim()) ?? 0.7,
          speed: double.tryParse(_speedCtl.text.trim()) ?? 1.0,
          sampleRate: int.tryParse(_sampleRateCtl.text.trim()) ?? 44100,
          latency: _latencyCtl.text.trim().isEmpty
              ? 'normal'
              : _latencyCtl.text.trim(),
        );
    }
  }
}

class _ProviderKindWrap extends StatelessWidget {
  const _ProviderKindWrap({required this.value, required this.onChanged});

  final NetworkTtsKind value;
  final ValueChanged<NetworkTtsKind> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final kind in _networkTtsKinds)
          _ProviderKindChip(
            kind: kind,
            selected: kind == value,
            onTap: () => onChanged(kind),
          ),
      ],
    );
  }
}

class _ProviderKindChip extends StatelessWidget {
  const _ProviderKindChip({
    required this.kind,
    required this.selected,
    required this.onTap,
  });

  final NetworkTtsKind kind;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return _TactileRow(
      pressedScale: 0.98,
      onTap: onTap,
      builder: (pressed) {
        final bg = selected
            ? cs.primary.withValues(alpha: 0.13)
            : cs.onSurface.withValues(alpha: 0.06);
        final border = selected
            ? cs.primary.withValues(alpha: 0.5)
            : cs.outlineVariant.withValues(alpha: 0.22);
        return AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            color: pressed
                ? Color.alphaBlend(cs.onSurface.withValues(alpha: 0.06), bg)
                : bg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: border, width: 0.8),
          ),
          child: Text(
            networkTtsKindDisplayName(kind),
            style: TextStyle(
              fontSize: 14,
              fontWeight: AppFontWeights.semibold,
              color: selected ? cs.primary : cs.onSurface,
            ),
          ),
        );
      },
    );
  }
}

class _TtsEditorTextField extends StatefulWidget {
  const _TtsEditorTextField({
    required this.label,
    required this.controller,
    this.hint,
    this.obscure = false,
    this.keyboardType,
    this.maxLines = 1,
    this.onChanged,
  });

  final String label;
  final TextEditingController controller;
  final String? hint;
  final bool obscure;
  final TextInputType? keyboardType;
  final int maxLines;
  final ValueChanged<String>? onChanged;

  @override
  State<_TtsEditorTextField> createState() => _TtsEditorTextFieldState();
}

class _TtsEditorTextFieldState extends State<_TtsEditorTextField> {
  bool _obscured = true;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final fieldBg = context.appColors.surfaceFill;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: AppFontWeights.semibold,
              color: cs.onSurface.withValues(alpha: 0.72),
            ),
          ),
          const SizedBox(height: 7),
          TextField(
            controller: widget.controller,
            obscureText: widget.obscure && _obscured,
            autocorrect: !widget.obscure,
            enableSuggestions: !widget.obscure,
            keyboardType: widget.keyboardType,
            maxLines: widget.obscure ? 1 : widget.maxLines,
            onChanged: widget.onChanged,
            style: TextStyle(
              fontSize: 15,
              fontWeight: AppFontWeights.medium,
              color: cs.onSurface.withValues(alpha: 0.92),
            ),
            decoration: InputDecoration(
              hintText: widget.hint,
              isDense: true,
              filled: true,
              fillColor: fieldBg,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: cs.primary, width: 1),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 12,
              ),
              suffixIcon: widget.obscure
                  ? _SmallTactileIcon(
                      icon: _obscured ? Lucide.Eye : Lucide.EyeOff,
                      onTap: () => setState(() => _obscured = !_obscured),
                    )
                  : null,
            ),
          ),
        ],
      ),
    );
  }
}

class _TtsEditorSelectField extends StatelessWidget {
  const _TtsEditorSelectField({
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
    this.labelFor,
  });

  final String label;
  final String value;
  final List<String> options;
  final ValueChanged<String> onChanged;
  final String Function(String value)? labelFor;

  @override
  Widget build(BuildContext context) {
    final values = <String>[if (!options.contains(value)) value, ...options];
    return VoiceServiceMobileSelectRow<String>(
      label: label,
      value: value,
      options: values,
      labelFor: labelFor ?? (option) => option,
      onSelected: onChanged,
    );
  }
}

class _TtsEditorSwitchField extends StatelessWidget {
  const _TtsEditorSwitchField({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return _TactileRow(
      onTap: () => onChanged(!value),
      builder: (pressed) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: AppFontWeights.medium,
                  color: cs.onSurface.withValues(alpha: pressed ? 0.68 : 0.9),
                ),
              ),
            ),
            const SizedBox(width: 12),
            IosSwitch(value: value, onChanged: onChanged),
          ],
        ),
      ),
    );
  }
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
    backgroundColor: context.overlaySurface,
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
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: AppFontWeights.emphasis,
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
  return _TactileRow(
    onTap: options.isEmpty
        ? null
        : () async {
            final picked = await showModalBottomSheet<String>(
              context: context,
              backgroundColor: context.overlaySurface,
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
          ? (Color.lerp(base, cs.surface, 0.55) ?? base)
          : base;
      final bgTarget = pressed
          ? (cs.onSurface.withValues(alpha: isDark ? 0.06 : 0.05))
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

const List<NetworkTtsKind> _networkTtsKinds = [
  NetworkTtsKind.openai,
  NetworkTtsKind.gemini,
  NetworkTtsKind.azure,
  NetworkTtsKind.minimax,
  NetworkTtsKind.qwen,
  NetworkTtsKind.qwenAudio,
  NetworkTtsKind.groq,
  NetworkTtsKind.xai,
  NetworkTtsKind.elevenlabs,
  NetworkTtsKind.mimo,
  NetworkTtsKind.step,
  NetworkTtsKind.fishAudio,
];

String _apiKeyOf(TtsServiceOptions? option) {
  if (option is OpenAiTtsOptions) return option.apiKey;
  if (option is GeminiTtsOptions) return option.apiKey;
  if (option is AzureTtsOptions) return option.apiKey;
  if (option is MiniMaxTtsOptions) return option.apiKey;
  if (option is QwenTtsOptions) return option.apiKey;
  if (option is QwenAudioTtsOptions) return option.apiKey;
  if (option is GroqTtsOptions) return option.apiKey;
  if (option is XaiTtsOptions) return option.apiKey;
  if (option is ElevenLabsTtsOptions) return option.apiKey;
  if (option is MimoTtsOptions) return option.apiKey;
  if (option is StepTtsOptions) return option.apiKey;
  if (option is FishAudioTtsOptions) return option.apiKey;
  return '';
}

String _baseUrlOf(TtsServiceOptions? option) {
  if (option is OpenAiTtsOptions) return option.baseUrl;
  if (option is GeminiTtsOptions) return option.baseUrl;
  if (option is AzureTtsOptions) return option.baseUrl;
  if (option is MiniMaxTtsOptions) return option.baseUrl;
  if (option is QwenTtsOptions) return option.baseUrl;
  if (option is QwenAudioTtsOptions) return option.workspaceId;
  if (option is GroqTtsOptions) return option.baseUrl;
  if (option is XaiTtsOptions) return option.baseUrl;
  if (option is ElevenLabsTtsOptions) return option.baseUrl;
  if (option is MimoTtsOptions) return option.baseUrl;
  if (option is StepTtsOptions) return option.baseUrl;
  if (option is FishAudioTtsOptions) return option.baseUrl;
  return '';
}

String _modelOf(TtsServiceOptions? option) {
  if (option is OpenAiTtsOptions) return option.model;
  if (option is GeminiTtsOptions) return option.model;
  if (option is MiniMaxTtsOptions) return option.model;
  if (option is QwenTtsOptions) return option.model;
  if (option is QwenAudioTtsOptions) return option.model;
  if (option is GroqTtsOptions) return option.model;
  if (option is ElevenLabsTtsOptions) return option.modelId;
  if (option is MimoTtsOptions) return option.model;
  if (option is StepTtsOptions) return option.model;
  if (option is FishAudioTtsOptions) return option.model;
  return '';
}

String _voiceOf(TtsServiceOptions? option) {
  if (option is OpenAiTtsOptions) return option.voice;
  if (option is GeminiTtsOptions) return option.voiceName;
  if (option is AzureTtsOptions) return option.voice;
  if (option is MiniMaxTtsOptions) return option.voiceId;
  if (option is QwenTtsOptions) return option.voice;
  if (option is QwenAudioTtsOptions) return option.voice;
  if (option is GroqTtsOptions) return option.voice;
  if (option is XaiTtsOptions) return option.voiceId;
  if (option is ElevenLabsTtsOptions) return option.voiceId;
  if (option is MimoTtsOptions) return option.voice;
  if (option is StepTtsOptions) return option.voice;
  if (option is FishAudioTtsOptions) return option.referenceId;
  return '';
}

String _defaultBaseUrl(NetworkTtsKind k) {
  switch (k) {
    case NetworkTtsKind.openai:
      return 'https://api.openai.com/v1';
    case NetworkTtsKind.gemini:
      return 'https://generativelanguage.googleapis.com/v1beta';
    case NetworkTtsKind.azure:
      return '';
    case NetworkTtsKind.minimax:
      return 'https://api.minimaxi.com/v1';
    case NetworkTtsKind.qwen:
      return 'https://dashscope.aliyuncs.com/api/v1';
    case NetworkTtsKind.groq:
      return 'https://api.groq.com/openai/v1';
    case NetworkTtsKind.xai:
      return 'https://api.x.ai/v1';
    case NetworkTtsKind.elevenlabs:
      return 'https://api.elevenlabs.io';
    case NetworkTtsKind.mimo:
      return 'https://api.xiaomimimo.com/v1';
    case NetworkTtsKind.qwenAudio:
      return 'wss://dashscope.aliyuncs.com/api-ws/v1/inference';
    case NetworkTtsKind.step:
      return 'https://api.stepfun.com/v1';
    case NetworkTtsKind.fishAudio:
      return 'https://api.fish.audio';
  }
}

String _defaultModel(NetworkTtsKind k) {
  switch (k) {
    case NetworkTtsKind.openai:
      return 'gpt-4o-mini-tts';
    case NetworkTtsKind.gemini:
      return 'gemini-3.1-flash-tts-preview';
    case NetworkTtsKind.azure:
      return '';
    case NetworkTtsKind.minimax:
      return 'speech-2.8-turbo';
    case NetworkTtsKind.qwen:
      return 'qwen3-tts-flash';
    case NetworkTtsKind.groq:
      return 'canopylabs/orpheus-v1-english';
    case NetworkTtsKind.xai:
      return '';
    case NetworkTtsKind.elevenlabs:
      return 'eleven_multilingual_v2';
    case NetworkTtsKind.mimo:
      return 'mimo-v2.5-tts';
    case NetworkTtsKind.qwenAudio:
      return 'qwen-audio-3.0-tts-flash';
    case NetworkTtsKind.step:
      return 'stepaudio-2.5-tts';
    case NetworkTtsKind.fishAudio:
      return 's2.1-pro';
  }
}

String _defaultVoice(NetworkTtsKind k) {
  switch (k) {
    case NetworkTtsKind.openai:
      return 'alloy';
    case NetworkTtsKind.gemini:
      return 'Kore';
    case NetworkTtsKind.azure:
      return 'zh-CN-XiaoxiaoNeural';
    case NetworkTtsKind.minimax:
      return 'female-shaonv';
    case NetworkTtsKind.qwen:
      return 'Cherry';
    case NetworkTtsKind.groq:
      return 'austin';
    case NetworkTtsKind.xai:
      return 'eve';
    case NetworkTtsKind.elevenlabs:
      return '';
    case NetworkTtsKind.mimo:
      return 'mimo_default';
    case NetworkTtsKind.qwenAudio:
      return 'longanhuan_v3.6';
    case NetworkTtsKind.step:
      return 'cixingnansheng';
    case NetworkTtsKind.fishAudio:
      return '';
  }
}

String _voiceLabelFor(NetworkTtsKind k, AppLocalizations l10n) {
  switch (k) {
    case NetworkTtsKind.openai:
      return l10n.ttsServicesFieldVoiceLabel;
    case NetworkTtsKind.gemini:
      return l10n.ttsServicesFieldVoiceLabel; // same label
    case NetworkTtsKind.azure:
      return l10n.ttsServicesFieldVoiceLabel;
    case NetworkTtsKind.minimax:
      return l10n.ttsServicesFieldVoiceIdLabel;
    case NetworkTtsKind.qwen:
      return l10n.ttsServicesFieldVoiceLabel;
    case NetworkTtsKind.groq:
      return l10n.ttsServicesFieldVoiceLabel;
    case NetworkTtsKind.xai:
      return l10n.ttsServicesFieldVoiceIdLabel;
    case NetworkTtsKind.elevenlabs:
      return l10n.ttsServicesFieldVoiceIdLabel;
    case NetworkTtsKind.mimo:
      return l10n.ttsServicesFieldVoiceLabel;
    case NetworkTtsKind.qwenAudio:
      return l10n.ttsServicesFieldVoiceLabel;
    case NetworkTtsKind.step:
      return l10n.ttsServicesFieldVoiceLabel;
    case NetworkTtsKind.fishAudio:
      return l10n.ttsServicesFieldVoiceIdLabel;
  }
}
