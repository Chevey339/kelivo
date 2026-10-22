import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/services/browser/browser_service.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/ios_tactile.dart';
import '../../../theme/app_font_weights.dart';
import '../../../theme/app_semantic_colors.dart';
import '../../chat/widgets/chat_surface.dart';
import '../browser_navigation.dart';
import '../models/browser_tool_presentation.dart';
import 'browser_favicon.dart';

/// Cached page preview shared by collapsed and expanded timeline groups.
class BrowserStepGroupBody extends StatefulWidget {
  const BrowserStepGroupBody({
    super.key,
    required this.actions,
    required this.conversationId,
    this.lite = false,
    this.service,
    this.onOpen,
    this.running,
  });
  final List<BrowserToolAction> actions;
  final String conversationId;
  final bool lite;
  final BrowserService? service;
  final ValueChanged<String?>? onOpen;
  final bool? running;

  @override
  State<BrowserStepGroupBody> createState() => _BrowserStepGroupBodyState();
}

class _BrowserStepGroupBodyState extends State<BrowserStepGroupBody> {
  Object? _cardSignature;
  Widget? _card;
  String? _watchedTab;
  bool _previewVisible = false;
  VoidCallback? _releasePreview;
  BrowserService get _browser => widget.service ?? BrowserService.instance;
  bool get _running =>
      widget.running ?? widget.actions.any((action) => action.loading);
  int get _failures => widget.actions.where((action) => action.failed).length;

  String? get _previewTabId {
    if (_running &&
        _browser.agentSessionId == widget.conversationId &&
        _browser.agentTabId != null) {
      return _browser.agentTabId;
    }
    return widget.actions.reversed
        .map((action) => action.tabId)
        .whereType<String>()
        .firstOrNull;
  }

  @override
  void initState() {
    super.initState();
    _browser.addListener(_syncPreview);
  }

  void _syncPreview() {
    final id = widget.lite || !_previewVisible ? null : _previewTabId;
    if (_watchedTab == id) return;
    _releasePreview?.call();
    _watchedTab = id;
    _releasePreview = id == null ? null : _browser.watchTabPreview(id);
  }

  @override
  void dispose() {
    _browser.removeListener(_syncPreview);
    _releasePreview?.call();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _card = null;
    _previewVisible =
        Visibility.of(context) && TickerMode.valuesOf(context).enabled;
    _syncPreview();
  }

  @override
  void didUpdateWidget(BrowserStepGroupBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.service != widget.service) {
      (oldWidget.service ?? BrowserService.instance).removeListener(
        _syncPreview,
      );
      _releasePreview?.call();
      _watchedTab = null;
      _browser.addListener(_syncPreview);
    }
    _syncPreview();
    if (!identical(oldWidget.actions, widget.actions) ||
        oldWidget.conversationId != widget.conversationId ||
        oldWidget.lite != widget.lite ||
        oldWidget.running != widget.running ||
        oldWidget.service != widget.service ||
        oldWidget.onOpen != widget.onOpen) {
      _card = null;
    }
  }

  Widget _pageCard(BuildContext context) {
    final actions = widget.actions;
    final page = actions.reversed.where((action) => action.hasPage).firstOrNull;
    final lastTabId = actions.reversed
        .map((action) => action.tabId)
        .whereType<String>()
        .firstOrNull;
    final previewId = _previewTabId ?? page?.tabId ?? lastTabId;
    final liveTab = _browser.tabs
        .where((tab) => tab.id == previewId)
        .firstOrNull;
    final bytes = previewId == null ? null : _browser.previewForTab(previewId);
    final l = AppLocalizations.of(context)!;
    final signature = (previewId, bytes, liveTab?.title, liveTab?.url, l);
    if (_card != null && signature == _cardSignature) return _card!;
    _cardSignature = signature;
    final current = actions.lastWhere(
      (action) => action.loading,
      orElse: () => actions.last,
    );
    final failure = actions.reversed
        .where((action) => action.failed)
        .firstOrNull;
    final failed = !_running && page == null && _failures > 0;
    final url =
        (_running ? liveTab?.url : null) ??
        page?.url ??
        actions.reversed
            .map((action) => action.url)
            .where((url) => url.isNotEmpty)
            .firstOrNull ??
        liveTab?.url ??
        '';
    final title = _running && liveTab?.title.isNotEmpty == true
        ? liveTab!.title
        : page?.title.isNotEmpty == true
        ? page!.title
        : (url == 'about:blank' || url.isEmpty
              ? l.browserCardBlankPage
              : browserUrlLabel(url));
    final tabUrls = <String, String>{};
    for (final action in actions) {
      if (action.tabId case final id?) {
        if (action.url.isNotEmpty || !tabUrls.containsKey(id)) {
          tabUrls[id] = action.url;
        }
      }
    }
    final host = browserUrlLabel(url);
    return _card = BrowserPageCard(
      title: failed ? l.browserCardOpenFailed : title,
      subtitle: _running
          ? l.browserCardRunning(current.label(l))
          : failed
          ? browserErrorSummary(l, failure!.error)
          : tabUrls.length > 1
          ? '${l.browserCardTabCount(tabUrls.length)} · $host'
          : host,
      url: url,
      preview: bytes,
      tabUrls: tabUrls.values.toList(),
      running: _running,
      failed: failed,
      enable: failed && failure!.error.contains('browser_agent_disabled'),
      lite: widget.lite,
      service: _browser,
      onTap: () {
        if (widget.onOpen case final open?) {
          open(previewId ?? lastTabId);
        } else {
          openBrowserPage(
            context,
            conversationId: widget.conversationId,
            tabId: previewId ?? lastTabId,
          );
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: _browser,
    builder: (context, _) => _pageCard(context),
  );
}

class BrowserPageCard extends StatelessWidget {
  const BrowserPageCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.url,
    required this.onTap,
    this.preview,
    this.tabUrls = const [],
    this.running = false,
    this.failed = false,
    this.enable = false,
    this.lite = false,
    this.service,
  });
  final String title, subtitle, url;
  final VoidCallback onTap;
  final Uint8List? preview;
  final List<String> tabUrls;
  final bool running, failed, enable, lite;
  final BrowserService? service;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final fg = chatSurfaceForegroundPalette(context);
    final dark = theme.brightness == Brightness.dark;
    final fill = chatQuietFill(context);
    final l = AppLocalizations.of(context)!;
    return IosCardPress(
      key: const ValueKey('browser-page-card'),
      onTap: onTap,
      pressedScale: .98,
      borderRadius: BorderRadius.circular(12),
      baseColor: fill,
      border: Border.all(
        color: cs.onSurface.withValues(alpha: dark ? .08 : .06),
      ),
      padding: EdgeInsets.fromLTRB(lite ? 10 : 7, 7, 10, 7),
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: lite ? 20 : 48),
        child: Row(
          children: [
            if (lite)
              BrowserFavicon(url: url, size: 14, service: service)
            else
              _thumbnail(context),
            SizedBox(width: lite ? 8 : 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      height: 18 / 13,
                      fontWeight: AppFontWeights.semibold,
                      color: cs.onSurface,
                    ),
                  ),
                  if (!lite) ...[
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        if (tabUrls.length > 1)
                          SizedBox(
                            width: 16 + 12.0 * (tabUrls.length.clamp(1, 3) - 1),
                            height: 16,
                            child: Stack(
                              children: [
                                for (
                                  var i = 0;
                                  i < tabUrls.length.clamp(1, 3);
                                  i++
                                )
                                  Positioned(
                                    left: i * 12.0,
                                    child: BrowserFavicon(
                                      url: tabUrls[i],
                                      size: 16,
                                      service: service,
                                    ),
                                  ),
                              ],
                            ),
                          )
                        else
                          BrowserFavicon(url: url, size: 14, service: service),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11.5,
                              height: 16 / 11.5,
                              color: failed ? cs.error : fg.muted,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 6),
            Text(
              enable ? l.browserCardEnable : l.browserCardOpen,
              style: TextStyle(
                fontSize: 12,
                color: cs.primary,
                fontWeight: AppFontWeights.semibold,
              ),
            ),
            Icon(LucideIcons.chevronRight, size: 14, color: cs.primary),
          ],
        ),
      ),
    );
  }

  Widget _thumbnail(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    Widget placeholder() => ColoredBox(
      key: ValueKey(
        failed ? 'browser-preview-error' : 'browser-preview-placeholder',
      ),
      color: (failed ? cs.error : cs.onSurface).withValues(
        alpha: failed ? .06 : .05,
      ),
      child: Center(
        child: failed
            ? Icon(LucideIcons.circleAlert, size: 18, color: cs.error)
            : BrowserFavicon(url: url, size: 22, service: service),
      ),
    );
    return SizedBox(
      width: 72,
      height: 48,
      child: DecoratedBox(
        position: DecorationPosition.foreground,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: cs.onSurface.withValues(
              alpha: Theme.of(context).brightness == Brightness.dark
                  ? .10
                  : .08,
            ),
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (preview != null && !failed)
                Image.memory(
                  preview!,
                  fit: BoxFit.cover,
                  alignment: Alignment.topCenter,
                  gaplessPlayback: true,
                  excludeFromSemantics: true,
                  errorBuilder: (_, __, ___) => placeholder(),
                )
              else
                placeholder(),
              if (running)
                Positioned(left: 4, bottom: 4, child: _BrowserLiveBadge()),
            ],
          ),
        ),
      ),
    );
  }
}

class _BrowserLiveBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    Widget dot = Container(
      width: 5,
      height: 5,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: context.appColors.success,
      ),
    );
    if (!MediaQuery.disableAnimationsOf(context)) {
      dot = dot
          .animate(onPlay: (controller) => controller.repeat(reverse: true))
          .fade(begin: 1, end: .3, duration: 700.ms);
    }
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: .55),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            dot,
            const SizedBox(width: 3),
            Text(
              AppLocalizations.of(context)!.browserCardLive,
              style: const TextStyle(fontSize: 8.5, color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}
