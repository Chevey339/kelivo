import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../l10n/app_localizations.dart';

/// Read-only presentation of an existing tool result; never runs browser work.
class BrowserToolAction {
  BrowserToolAction({
    required this.id,
    required this.arguments,
    String? content,
    Map<String, dynamic>? metadata,
    this.loading = false,
  }) : result = _result(content),
       browserMetadata = _map(metadata?['browser']);

  final String id;
  final Map<String, dynamic> arguments;
  final bool loading;
  final Map<String, dynamic> result, browserMetadata;

  static Map<String, dynamic> _map(Object? value) => value is Map
      ? {
          for (final entry in value.entries)
            if (entry.key is String) entry.key as String: entry.value,
        }
      : const {};

  static Map<String, dynamic> _result(String? content) {
    if (content == null) return const {};
    try {
      final image = content.indexOf('\n![](');
      return _map(
        jsonDecode(image < 0 ? content : content.substring(0, image)),
      );
    } on FormatException {
      return const {};
    }
  }

  String get action => _string(
    arguments['action'] ?? browserMetadata['action'] ?? result['action'],
  );
  Map<String, dynamic> get page => _map(result['page']);
  bool get failed =>
      !loading &&
      (result['ok'] == false || browserMetadata['status'] == 'error');
  String get error => _string(result['error']);
  String? get tabId {
    final id = _string(
      browserMetadata['tabId'] ??
          page['tab_id'] ??
          arguments['tab_id'] ??
          page['closed_tab_id'],
    );
    return id.isEmpty ? null : id;
  }

  String get url => _string(page['url'] ?? arguments['url']);
  String get title => _string(page['title']);
  bool get hasPage =>
      !failed && !loading && (page['url'] is String || page['title'] is String);
  static String _string(Object? value) => value is String ? value : '';

  String label(AppLocalizations l) => browserActionLabel(l, action);

  String? target(AppLocalizations l, List<BrowserToolAction> preceding) {
    switch (action) {
      case 'open':
      case 'new_tab':
        return url.isEmpty ? null : browserUrlLabel(url, includePath: true);
      case 'render':
        return quoteBrowserText(_string(arguments['title']));
      case 'type':
        return quoteBrowserText(_string(arguments['text']));
      case 'click':
        final snapshot = preceding.reversed
            .where((item) => item.action == 'snapshot')
            .firstOrNull;
        final elements = snapshot?.page['elements'];
        if (elements is List && arguments['ref'] != null) {
          for (final element in elements) {
            if (element is Map && element['ref'] == arguments['ref']) {
              final name = _string(element['name']);
              if (name.isNotEmpty) return quoteBrowserText(name);
            }
          }
        }
        return quoteBrowserText(_string(arguments['selector']));
      case 'extract':
        final content = page['content'];
        if (content is! String) return null;
        final length = content.runes.length;
        return l.browserMetaChars(
          length > 1000 ? '${(length / 1000).toStringAsFixed(1)}k' : '$length',
        );
      case 'snapshot':
        final elements = page['elements'];
        return elements is List ? l.browserMetaElements(elements.length) : null;
      case 'list_tabs':
        final tabs = page['tabs'];
        return tabs is List ? l.browserMetaTabs(tabs.length) : null;
      case 'press':
        return _string(arguments['key']);
      case 'scroll':
        return switch (arguments['direction']) {
          'up' => l.browserDirectionUp,
          'down' => l.browserDirectionDown,
          'left' => l.browserDirectionLeft,
          'right' => l.browserDirectionRight,
          _ => null,
        };
      default:
        return null;
    }
  }
}

String? quoteBrowserText(String text) {
  if (text.isEmpty) return null;
  final head = text.runes.take(25).toList();
  return '「${String.fromCharCodes(head.take(24))}${head.length > 24 ? '…' : ''}」';
}

String browserUrlLabel(String url, {bool includePath = false}) {
  final uri = Uri.tryParse(url);
  if (uri == null || uri.host.isEmpty) return '';
  final host = uri.host.replaceFirst(RegExp(r'^www\.'), '');
  return includePath && uri.path != '/' ? '$host${uri.path}' : host;
}

String browserActionLabel(AppLocalizations l, String action) =>
    switch (action) {
      'open' => l.browserActionOpen,
      'new_tab' => l.browserActionNewTab,
      'render' => l.browserActionRender,
      'extract' => l.browserActionExtract,
      'snapshot' => l.browserActionSnapshot,
      'click' => l.browserActionClick,
      'type' => l.browserActionType,
      'press' => l.browserActionPress,
      'scroll' => l.browserActionScroll,
      'wait' => l.browserActionWait,
      'back' => l.browserActionBack,
      'forward' => l.browserActionForward,
      'reload' => l.browserActionReload,
      'evaluate' => l.browserActionEvaluate,
      'switch_tab' => l.browserActionSwitchTab,
      'close_tab' => l.browserActionCloseTab,
      'list_tabs' => l.browserActionListTabs,
      _ => l.browserActionUnknown,
    };

IconData browserActionIcon(String action) => switch (action) {
  'open' => LucideIcons.arrowUpRight,
  'new_tab' => LucideIcons.squarePlus,
  'render' => LucideIcons.code,
  'extract' => LucideIcons.fileText,
  'snapshot' => LucideIcons.scanEye,
  'click' => LucideIcons.mousePointerClick,
  'type' => LucideIcons.keyboard,
  'press' => LucideIcons.cornerDownLeft,
  'scroll' => LucideIcons.arrowUpDown,
  'wait' => LucideIcons.hourglass,
  'back' => LucideIcons.arrowLeft,
  'forward' => LucideIcons.arrowRight,
  'reload' => LucideIcons.rotateCw,
  'evaluate' => LucideIcons.squareTerminal,
  'switch_tab' => LucideIcons.arrowLeftRight,
  'close_tab' => LucideIcons.x,
  'list_tabs' => LucideIcons.list,
  _ => LucideIcons.appWindow,
};

String browserErrorSummary(AppLocalizations l, String error) {
  if (error.contains('browser_agent_disabled')) {
    return l.browserErrAgentDisabled;
  }
  if (error.contains('stale_ref')) return l.browserErrStaleRef;
  if (error.contains('element_not_visible') ||
      error.contains('element_covered')) {
    return l.browserErrNotVisible;
  }
  if (error.contains('element_not_found')) return l.browserErrNotFound;
  if (error.toLowerCase().contains('timeout')) return l.browserErrTimeout;
  if (error.contains('browser_human_control')) return l.browserErrHumanControl;
  if (error.contains('browser_tab_closed') ||
      error.contains('browser_tab_not_found')) {
    return l.browserErrTabClosed;
  }
  return l.browserErrGeneric;
}

/// Collapsed preview estimate. Expanded rows are measured by the lazy list;
/// estimating them must not decode every tool result in a long browser run.
double estimateBrowserGroupBodyHeight({required bool lite}) =>
    (lite ? 36 : 64) + 4 + 8;
