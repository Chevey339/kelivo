import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';

import '../icons/lucide_adapter.dart';
import '../core/providers/settings_provider.dart';
import '../core/providers/assistant_provider.dart';
import '../core/services/api/builtin_tools.dart';
import '../core/services/search/search_service.dart';
import '../utils/brand_assets.dart';
import '../l10n/app_localizations.dart';

/// Show a desktop-only floating popover for search provider selection.
/// It appears above the chat input bar with blurred background, top rounded corners,
/// slightly narrower than the input width, and slides down to dismiss.
Future<void> showDesktopSearchProviderPopover(
  BuildContext context, {
  required GlobalKey anchorKey,
}) async {
  final overlay = Overlay.of(context);
  if (overlay == null) return;
  final keyContext = anchorKey.currentContext;
  if (keyContext == null) return;

  final box = keyContext.findRenderObject() as RenderBox?;
  if (box == null) return;
  final offset = box.localToGlobal(Offset.zero);
  final size = box.size;
  final anchorRect = Rect.fromLTWH(offset.dx, offset.dy, size.width, size.height);

  late OverlayEntry entry;
  entry = OverlayEntry(
    builder: (ctx) => _SearchPopoverOverlay(
      anchorRect: anchorRect,
      anchorWidth: size.width,
      onClose: () {
        try { entry.remove(); } catch (_) {}
      },
    ),
  );
  overlay.insert(entry);
}

class _SearchPopoverOverlay extends StatefulWidget {
  const _SearchPopoverOverlay({
    required this.anchorRect,
    required this.anchorWidth,
    required this.onClose,
  });

  final Rect anchorRect;
  final double anchorWidth;
  final VoidCallback onClose;

  @override
  State<_SearchPopoverOverlay> createState() => _SearchPopoverOverlayState();
}

class _SearchPopoverOverlayState extends State<_SearchPopoverOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fadeIn;
  bool _closing = false;
  // Positive dy means positioned slightly below final spot (slide up to appear)
  Offset _offset = const Offset(0, 0.12);

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 260));
    _fadeIn = CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic);
    // Kick off enter: slide up into place from slightly below
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      setState(() => _offset = Offset.zero);
      try { await _controller.forward(); } catch (_) {}
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _close() async {
    if (_closing) return;
    _closing = true;
    // Slide down out of the clipped area, then fade out
    setState(() => _offset = const Offset(0, 1.0));
    try { await _controller.reverse(); } catch (_) {}
    if (mounted) widget.onClose();
  }

  @override
  Widget build(BuildContext context) {
    final screen = MediaQuery.of(context).size;
    final cs = Theme.of(context).colorScheme;
    // Slightly narrower than input width
    final width = (widget.anchorWidth - 16).clamp(260.0, 720.0);
    final left = (widget.anchorRect.left + (widget.anchorRect.width - width) / 2)
        .clamp(8.0, screen.width - width - 8.0);
    final clipHeight = widget.anchorRect.top.clamp(0.0, screen.height);

    return Stack(
      children: [
        // Transparent barrier to close on outside tap
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: _close,
          ),
        ),
        // Clip area so the panel is only visible above the input's top edge
        Positioned(
          left: 0,
          right: 0,
          top: 0,
          height: clipHeight,
          child: ClipRect(
            child: Stack(
              children: [
                Positioned(
                  left: left,
                  width: width,
                  bottom: 0,
                  child: FadeTransition(
                    opacity: _fadeIn,
                    child: AnimatedSlide(
                      duration: const Duration(milliseconds: 260),
                      curve: Curves.easeOutCubic,
                      offset: _offset,
                      child: _GlassPanel(
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
                        child: _SearchContent(onDone: _close),
              ),
            ),
          ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _GlassPanel extends StatelessWidget {
  const _GlassPanel({required this.child, this.borderRadius});
  final Widget child;
  final BorderRadius? borderRadius;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ClipRRect(
      borderRadius: borderRadius ?? BorderRadius.circular(14),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: (isDark ? Colors.black : Colors.white).withOpacity(isDark ? 0.28 : 0.56),
            border: Border(
              top: BorderSide(color: Colors.white.withOpacity(isDark ? 0.06 : 0.18), width: 0.7),
              left: BorderSide(color: Colors.white.withOpacity(isDark ? 0.04 : 0.12), width: 0.6),
              right: BorderSide(color: Colors.white.withOpacity(isDark ? 0.04 : 0.12), width: 0.6),
            ),
          ),
          child: Material(
            type: MaterialType.transparency,
            child: child,
          ),
        ),
      ),
    );
  }
}

class _SearchContent extends StatelessWidget {
  const _SearchContent({required this.onDone});
  final VoidCallback onDone;

  bool _supportsBuiltInSearch(SettingsProvider settings, AssistantProvider ap) {
    final a = ap.currentAssistant;
    final providerKey = a?.chatModelProvider ?? settings.currentModelProvider;
    final modelId = a?.chatModelId ?? settings.currentModelId;
    if (providerKey == null || (modelId ?? '').isEmpty) return false;
    final cfg = settings.getProviderConfig(providerKey);
    final isGemini = cfg.providerType == ProviderKind.google;
    final isClaude = cfg.providerType == ProviderKind.claude;
    final isOpenAIResponses = cfg.providerType == ProviderKind.openai && (cfg.useResponseApi == true);
    final isGrok = cfg.providerType == ProviderKind.openai && (modelId ?? '').toLowerCase().contains('grok');
    if (!(isGemini || isClaude || isOpenAIResponses || isGrok)) return false;
    final mid = modelId!.toLowerCase();
    if (isGrok) return true; // All Grok models assumed to support search
    if (isClaude) {
      const supported = <String>{
        'claude-opus-4-6',
        'claude-sonnet-4-5-20250929',
        'claude-sonnet-4-20250514',
        'claude-3-7-sonnet-20250219',
        'claude-haiku-4-5-20251001',
        'claude-3-5-haiku-latest',
        'claude-sonnet-4-6',
        'claude-opus-4-1-20250805',
        'claude-opus-4-20250514',
      };
      if (!supported.contains(mid)) return false;
    }
    if (isOpenAIResponses) {
      bool isSupportedOpenAI(String id) {
        final m = id.toLowerCase();
        return m.startsWith('gpt-4o') ||
            m.startsWith('gpt-4.1') ||
            m.startsWith('o4-mini') ||
            m == 'o3' ||
            m.startsWith('o3-') ||
            m.startsWith('gpt-5');
      }
      if (!isSupportedOpenAI(mid)) return false;
    }
    return true;
  }

  bool _hasUrlContextEnabled(SettingsProvider settings, AssistantProvider ap) {
    final a = ap.currentAssistant;
    final providerKey = a?.chatModelProvider ?? settings.currentModelProvider;
    final modelId = a?.chatModelId ?? settings.currentModelId;
    if (providerKey == null || (modelId ?? '').isEmpty) return false;
    final cfg = settings.getProviderConfig(providerKey);
    final rawOv = cfg.modelOverrides[modelId!] ;
    final ov = rawOv is Map ? rawOv : null;
    final tools = BuiltInToolNames.parseAndNormalize(ov?['builtInTools']);
    return tools.contains(BuiltInToolNames.urlContext);
  }

  bool _hasBuiltInSearchEnabled(SettingsProvider settings, AssistantProvider ap) {
    final a = ap.currentAssistant;
    final providerKey = a?.chatModelProvider ?? settings.currentModelProvider;
    final modelId = a?.chatModelId ?? settings.currentModelId;
    if (providerKey == null || (modelId ?? '').isEmpty) return false;
    final cfg = settings.getProviderConfig(providerKey);
    final rawOv = cfg.modelOverrides[modelId!] ;
    final ov = rawOv is Map ? rawOv : null;
    final tools = BuiltInToolNames.parseAndNormalize(ov?['builtInTools']);
    return tools.contains(BuiltInToolNames.search);
  }

  Future<void> _enableBuiltInSearch(BuildContext context) async {
    final sp = context.read<SettingsProvider>();
    final ap = context.read<AssistantProvider>();
    final a = ap.currentAssistant;
    final providerKey = a?.chatModelProvider ?? sp.currentModelProvider;
    final modelId = a?.chatModelId ?? sp.currentModelId;
    if (providerKey == null || (modelId ?? '').isEmpty) return;
    final cfg = sp.getProviderConfig(providerKey);
    final overrides = Map<String, dynamic>.from(cfg.modelOverrides);
    final rawMo = overrides[modelId!];
    final existingMo = rawMo is Map ? rawMo : null;
    final mo = Map<String, dynamic>.from(existingMo?.map((k, v) => MapEntry(k.toString(), v)) ?? const <String, dynamic>{});

    final tools = BuiltInToolNames.parseAndNormalize(mo['builtInTools'])..add(BuiltInToolNames.search);
    mo['builtInTools'] = BuiltInToolNames.orderedForStorage(tools);
    overrides[modelId] = mo;
    await sp.setProviderConfig(providerKey, cfg.copyWith(modelOverrides: overrides));
    await sp.setSearchEnabled(false);
  }

  Future<void> _disableBuiltInSearch(BuildContext context) async {
    final sp = context.read<SettingsProvider>();
    final ap = context.read<AssistantProvider>();
    final a = ap.currentAssistant;
    final providerKey = a?.chatModelProvider ?? sp.currentModelProvider;
    final modelId = a?.chatModelId ?? sp.currentModelId;
    if (providerKey == null || (modelId ?? '').isEmpty) return;
    final cfg = sp.getProviderConfig(providerKey);
    final overrides = Map<String, dynamic>.from(cfg.modelOverrides);
    final rawMo = overrides[modelId!];
    final existingMo = rawMo is Map ? rawMo : null;
    final mo = Map<String, dynamic>.from(existingMo?.map((k, v) => MapEntry(k.toString(), v)) ?? const <String, dynamic>{});

    final tools = BuiltInToolNames.parseAndNormalize(mo['builtInTools'])..remove(BuiltInToolNames.search);
    if (tools.isEmpty) {
      mo.remove('builtInTools');
    } else {
      mo['builtInTools'] = BuiltInToolNames.orderedForStorage(tools);
    }
    overrides[modelId] = mo;
    await sp.setProviderConfig(providerKey, cfg.copyWith(modelOverrides: overrides));
  }

  @override
  Widget build(BuildContext context) {
    final sp = context.watch<SettingsProvider>();
    final ap = context.watch<AssistantProvider>();
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    final services = sp.searchServices;
    final selected = sp.searchServiceSelected
        .clamp(0, services.isNotEmpty ? services.length - 1 : 0);
    final enabled = sp.searchEnabled;
    final supportsBuiltIn = _supportsBuiltInSearch(sp, ap);
    final builtInEnabled = _hasBuiltInSearchEnabled(sp, ap);
    final hasUrlContext = _hasUrlContextEnabled(sp, ap);
    // When url_context is active, treat as built-in mode (hide external search options)
    final builtInMode = builtInEnabled || hasUrlContext;

    final rows = <Widget>[];

    // 1) Cancel item at top
    rows.add(_RowItem(
      leading: Icon(Lucide.CircleX, size: 16, color: cs.onSurface),
      label: l10n.homePageCancel,
      selected: false,
      onTap: () async {
        await _disableBuiltInSearch(context);
        await context.read<SettingsProvider>().setSearchEnabled(false);
        onDone();
      },
    ));

    // 2) Built-in search (when supported)
    if (supportsBuiltIn) {
      rows.add(_RowItem(
        leading: Icon(Lucide.Search, size: 16, color: cs.onSurface),
        label: l10n.searchSettingsSheetBuiltinSearchTitle,
        selected: builtInEnabled,
        onTap: () async {
          await _enableBuiltInSearch(context);
          onDone();
        },
      ));
    }

    // 3) External services list (hidden when url_context is active)
    if (!builtInMode) {
      for (int i = 0; i < services.length; i++) {
        final s = services[i];
        final svc = SearchService.getService(s);
        final name = svc.name;
        final isSelectedActive = enabled && (i == selected);
        rows.add(_RowItem(
          leading: _BrandIcon(name: name),
          label: name,
          selected: isSelectedActive,
          onTap: () async {
            await context.read<SettingsProvider>().setSearchServiceSelected(i);
            await _disableBuiltInSearch(context);
            await context.read<SettingsProvider>().setSearchEnabled(true);
            onDone();
          },
        ));
      }
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 420),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 2),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ...rows.map((w) => Padding(padding: const EdgeInsets.only(bottom: 1), child: w)),
            ],
          ),
        ),
      ),
    );
  }
}

class _RowItem extends StatefulWidget {
  const _RowItem({
    required this.leading,
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final Widget leading;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_RowItem> createState() => _RowItemState();
}

class _RowItemState extends State<_RowItem> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final onColor = widget.selected ? cs.primary : cs.onSurface;
    // Use stronger overlay for hover to be clearly visible on glass
    final baseBg = Colors.transparent;
    final hoverBg = (isDark ? Colors.white : Colors.black).withOpacity(isDark ? 0.12 : 0.10);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: _hovered ? hoverBg : baseBg,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              SizedBox(width: 22, height: 22, child: Center(child: widget.leading)),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  widget.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                    decoration: TextDecoration.none,
                  ).copyWith(color: onColor),
                ),
              ),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 160),
                child: widget.selected
                    ? Icon(Lucide.Check, key: const ValueKey('check'), size: 16, color: cs.primary)
                    : const SizedBox(width: 16, key: ValueKey('space')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BrandIcon extends StatelessWidget {
  const _BrandIcon({required this.name});
  final String name;

  @override
  Widget build(BuildContext context) {
    final asset = BrandAssets.assetForName(name);
    final color = Theme.of(context).colorScheme.onSurface;
    if (asset == null) {
      return Text(
        name.isNotEmpty ? name.characters.first.toUpperCase() : '?',
        style: TextStyle(fontWeight: FontWeight.w700, color: color),
      );
    }
    if (asset.endsWith('.svg')) {
      return SvgPicture.asset(
        asset,
        width: 16,
        height: 16,
        // Keep original colors if provided; otherwise tint to onSurface subtly
        colorFilter: asset.contains('color') ? null : ColorFilter.mode(color, BlendMode.srcIn),
      );
    }
    return Image.asset(
      asset,
      width: 16,
      height: 16,
      color: asset.endsWith('.png') ? null : color,
      colorBlendMode: asset.endsWith('.png') ? null : BlendMode.srcIn,
      fit: BoxFit.contain,
    );
  }
}
