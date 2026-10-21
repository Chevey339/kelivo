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

class BrowserStepGroupBody extends StatefulWidget {
  const BrowserStepGroupBody({
    super.key,
    required this.actions,
    required this.conversationId,
    this.lite = false,
    this.service,
    this.onOpen,
  });
  final List<BrowserToolAction> actions;
  final String conversationId;
  final bool lite;
  final BrowserService? service;
  final ValueChanged<String?>? onOpen;

  @override
  State<BrowserStepGroupBody> createState() => _BrowserStepGroupBodyState();
}

class _BrowserStepGroupBodyState extends State<BrowserStepGroupBody> {
  bool? _expanded;
  Object? _cardSignature;
  Widget? _card;
  BrowserService get _browser => widget.service ?? BrowserService.instance;
  bool get _running => widget.actions.any((action) => action.loading);
  int get _failures => widget.actions.where((action) => action.failed).length;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _card = null;
  }

  @override
  void didUpdateWidget(BrowserStepGroupBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    _card = null;
    // A user's explicit choice wins; otherwise defaults follow the live result.
    if (oldWidget.actions.first.id != widget.actions.first.id) _expanded = null;
  }

  Widget _pageCard(BuildContext context) {
    final actions = widget.actions;
    final page = actions.reversed.where((action) => action.hasPage).firstOrNull;
    final lastTabId = actions.reversed
        .map((action) => action.tabId)
        .whereType<String>()
        .firstOrNull;
    final previewId = page?.tabId ?? lastTabId;
    final liveTab = _browser.tabs
        .where((tab) => tab.id == previewId)
        .firstOrNull;
    final bytes = previewId == null ? null : _browser.previewForTab(previewId);
    final signature = (bytes, liveTab?.title, liveTab?.url);
    if (_card != null && signature == _cardSignature) return _card!;
    _cardSignature = signature;
    final l = AppLocalizations.of(context)!;
    final current = actions.lastWhere(
      (action) => action.loading,
      orElse: () => actions.last,
    );
    final failure = actions.reversed
        .where((action) => action.failed)
        .firstOrNull;
    final failed = !_running && page == null && _failures > 0;
    final url =
        page?.url ??
        actions.reversed
            .map((action) => action.url)
            .where((url) => url.isNotEmpty)
            .firstOrNull ??
        liveTab?.url ??
        '';
    final title = page?.title.isNotEmpty == true
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
          open(lastTabId);
        } else {
          openBrowserPage(
            context,
            conversationId: widget.conversationId,
            tabId: lastTabId,
          );
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    final expanded = _expanded ?? (_running || _failures > 0);
    // Keep the operation list linear in group size; copying every preceding
    // prefix would retain O(N²) references in long agent sessions.
    BrowserToolAction? snapshot;
    final previousSnapshots = <BrowserToolAction?>[];
    for (final action in widget.actions) {
      previousSnapshots.add(snapshot);
      if (action.action == 'snapshot') snapshot = action;
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        ListenableBuilder(
          listenable: _browser,
          builder: (context, _) => _pageCard(context),
        ),
        if (!widget.lite) ...[
          Semantics(
            button: true,
            expanded: expanded,
            child: IosCardPress(
              key: const ValueKey('browser-actions-toggle'),
              onTap: () => setState(() => _expanded = !expanded),
              baseColor: Colors.transparent,
              padding: EdgeInsets.zero,
              child: SizedBox(
                height: 28,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AnimatedRotation(
                      turns: expanded ? .5 : 0,
                      duration: MediaQuery.disableAnimationsOf(context)
                          ? Duration.zero
                          : const Duration(milliseconds: 200),
                      child: Icon(
                        LucideIcons.chevronDown,
                        size: 14,
                        color: cs.primary,
                      ),
                    ),
                    const SizedBox(width: 3),
                    Text(
                      expanded
                          ? l.chainOfThoughtCollapse
                          : l.browserActionCount(widget.actions.length),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: AppFontWeights.semibold,
                        color: cs.primary,
                      ),
                    ),
                    if (_failures > 0)
                      Flexible(
                        child: Padding(
                          padding: const EdgeInsets.only(left: 6),
                          child: Text(
                            l.browserActionFailedCount(_failures),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 12, color: cs.error),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          AnimatedSize(
            duration: MediaQuery.disableAnimationsOf(context)
                ? Duration.zero
                : const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topLeft,
            child: expanded
                ? Stack(
                    children: [
                      Positioned(
                        left: 7,
                        top: 12,
                        bottom: 12,
                        child: SizedBox(
                          width: 1,
                          child: ColoredBox(
                            color: cs.onSurface.withValues(alpha: .12),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Column(
                          children: [
                            for (var i = 0; i < widget.actions.length; i++)
                              BrowserActionRow(
                                key: ValueKey(
                                  'browser-action-$i-${widget.actions[i].id}',
                                ),
                                action: widget.actions[i],
                                preceding: [
                                  if (previousSnapshots[i] case final snapshot?)
                                    snapshot,
                                ],
                                service: _browser,
                              ),
                          ],
                        ),
                      ),
                    ],
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ],
    );
  }
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
    final fill = dark ? cs.onSurface.withValues(alpha: .06) : Colors.white;
    final l = AppLocalizations.of(context)!;
    return IosCardPress(
      key: const ValueKey('browser-page-card'),
      onTap: onTap,
      pressedScale: .98,
      borderRadius: BorderRadius.circular(12),
      baseColor: fill,
      border: Border.all(
        color: dark
            ? cs.onSurface.withValues(alpha: .08)
            : cs.primary.withValues(alpha: .12),
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
                            width: 16 + 11.0 * (tabUrls.length.clamp(1, 3) - 1),
                            height: 16,
                            child: Stack(
                              children: [
                                for (
                                  var i = 0;
                                  i < tabUrls.length.clamp(1, 3);
                                  i++
                                )
                                  Positioned(
                                    left: i * 11.0,
                                    child: Container(
                                      width: 16,
                                      height: 16,
                                      decoration: BoxDecoration(
                                        color: fill,
                                        borderRadius: BorderRadius.circular(4),
                                        border: Border.all(
                                          color: fill,
                                          width: 1.5,
                                        ),
                                      ),
                                      child: BrowserFavicon(
                                        url: tabUrls[i],
                                        size: 13,
                                        service: service,
                                      ),
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

class BrowserActionSpinner extends StatelessWidget {
  const BrowserActionSpinner({super.key, required this.color, this.size = 13});
  final Color color;
  final double size;
  @override
  Widget build(BuildContext context) {
    final icon = Icon(LucideIcons.loaderCircle, size: size, color: color);
    return MediaQuery.disableAnimationsOf(context)
        ? icon
        : icon
              .animate(onPlay: (controller) => controller.repeat())
              .rotate(duration: 900.ms);
  }
}

class BrowserActionRow extends StatelessWidget {
  const BrowserActionRow({
    super.key,
    required this.action,
    required this.preceding,
    this.service,
  });
  final BrowserToolAction action;
  final List<BrowserToolAction> preceding;
  final BrowserService? service;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    final fg = chatSurfaceForegroundPalette(context);
    final browser = service ?? BrowserService.instance;
    final tab = action.action == 'switch_tab'
        ? browser.tabs.where((tab) => tab.id == action.tabId).firstOrNull
        : null;
    final target = tab == null
        ? action.target(l, preceding)
        : browserUrlLabel(tab.url, includePath: true);
    final chip = {'open', 'new_tab', 'switch_tab'}.contains(action.action);
    final color = action.failed
        ? cs.error
        : action.loading
        ? cs.primary
        : fg.body;
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 22),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 15,
              height: 16,
              child: action.loading
                  ? BrowserActionSpinner(color: cs.primary)
                  : Icon(
                      action.failed
                          ? LucideIcons.circleAlert
                          : browserActionIcon(action.action),
                      size: 14,
                      color: action.failed ? cs.error : fg.muted,
                    ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 5,
                    runSpacing: 2,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        action.failed
                            ? l.browserActionFailed(action.label(l))
                            : action.label(l),
                        style: TextStyle(
                          fontSize: 12,
                          height: 16 / 12,
                          color: color,
                          fontWeight: action.loading
                              ? AppFontWeights.semibold
                              : FontWeight.normal,
                        ),
                      ),
                      if (target != null && target.isNotEmpty)
                        if (chip)
                          _BrowserTargetChip(
                            text: target,
                            url: tab?.url ?? action.url,
                            service: browser,
                          )
                        else
                          Text(
                            target,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              height: 16 / 12,
                              color: color,
                            ),
                          ),
                    ],
                  ),
                  if (action.failed)
                    Padding(
                      padding: const EdgeInsets.only(top: 1),
                      child: Text(
                        browserErrorSummary(l, action.error),
                        style: TextStyle(
                          fontSize: 11,
                          color: cs.error.withValues(alpha: .85),
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

class _BrowserTargetChip extends StatelessWidget {
  const _BrowserTargetChip({
    required this.text,
    required this.url,
    required this.service,
  });
  final String text, url;
  final BrowserService service;
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      constraints: const BoxConstraints(maxWidth: 180),
      height: 18,
      padding: const EdgeInsets.only(left: 2, right: 6),
      decoration: BoxDecoration(
        color: dark ? cs.onSurface.withValues(alpha: .06) : Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: dark
              ? cs.onSurface.withValues(alpha: .08)
              : cs.primary.withValues(alpha: .12),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          BrowserFavicon(url: url, size: 12, service: service),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                color: chatSurfaceForegroundPalette(context).body,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
