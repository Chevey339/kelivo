import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'mermaid_bridge.dart';
import 'mermaid_image_cache.dart';
import 'markdown_line_lexer.dart';
import '../../utils/svg_preview_html.dart';

typedef DiagramCode = ({String code, bool isSvg});

List<DiagramCode> extractDiagramCodes(String markdown) {
  final diagrams = <DiagramCode>[];
  final lexer = MarkdownLineLexer();
  final body = StringBuffer();
  var language = '';

  void addDiagram() {
    final code = body.toString().trim();
    if (code.isEmpty) return;
    final isSvg = isSvgCodeBlock(language, code);
    if (language == 'mermaid' || isSvg) {
      diagrams.add((code: code, isSvg: isSvg));
    }
  }

  for (final line in const LineSplitter().convert(markdown)) {
    final wasFenced = lexer.fenced;
    lexer.consumeFence(line);
    if (!wasFenced && lexer.fenced) {
      final opening = line.trimLeft();
      var end = 0;
      while (end < opening.length && opening[end] == opening[0]) {
        end++;
      }
      language = opening.substring(end).trim().toLowerCase();
      body.clear();
    } else if (wasFenced && !lexer.fenced) {
      addDiagram();
    } else if (wasFenced) {
      body.writeln(line);
    }
  }
  if (lexer.fenced) addDiagram();
  return diagrams;
}

@visibleForTesting
MermaidViewHandle? Function(DiagramCode diagram)? debugDiagramExportViewFactory;

Map<String, String> buildThemeVarsFromColorScheme(ColorScheme cs) {
  String hex(Color c) {
    final v = c.toARGB32();
    final r = (v >> 16) & 0xFF;
    final g = (v >> 8) & 0xFF;
    final b = v & 0xFF;
    return '#'
            '${r.toRadixString(16).padLeft(2, '0')}'
            '${g.toRadixString(16).padLeft(2, '0')}'
            '${b.toRadixString(16).padLeft(2, '0')}'
        .toUpperCase();
  }

  return <String, String>{
    'primaryColor': hex(cs.primary),
    'primaryTextColor': hex(cs.onPrimary),
    'primaryBorderColor': hex(cs.primary),
    'secondaryColor': hex(cs.secondary),
    'secondaryTextColor': hex(cs.onSecondary),
    'secondaryBorderColor': hex(cs.secondary),
    'tertiaryColor': hex(cs.tertiary),
    'tertiaryTextColor': hex(cs.onTertiary),
    'tertiaryBorderColor': hex(cs.tertiary),
    'background': hex(cs.surface),
    'mainBkg': hex(cs.primaryContainer),
    'secondBkg': hex(cs.secondaryContainer),
    'lineColor': hex(cs.onSurface),
    'textColor': hex(cs.onSurface),
    'nodeBkg': hex(cs.surface),
    'nodeBorder': hex(cs.primary),
    'clusterBkg': hex(cs.surface),
    'clusterBorder': hex(cs.primary),
    'actorBorder': hex(cs.primary),
    'actorBkg': hex(cs.surface),
    'actorTextColor': hex(cs.onSurface),
    'actorLineColor': hex(cs.primary),
    'taskBorderColor': hex(cs.primary),
    'taskBkgColor': hex(cs.primary),
    'taskTextLightColor': hex(cs.onPrimary),
    'taskTextDarkColor': hex(cs.onSurface),
    'labelColor': hex(cs.onSurface),
    'errorBkgColor': hex(cs.error),
    'errorTextColor': hex(cs.onError),
  };
}

Future<void> preRenderDiagramCodesForExport(
  BuildContext context,
  List<DiagramCode> codes,
) async {
  if (codes.isEmpty) return;
  final cs = Theme.of(context).colorScheme;
  final isDark = Theme.of(context).brightness == Brightness.dark;
  final themeVars = buildThemeVarsFromColorScheme(cs);

  String cacheKey(DiagramCode diagram) => diagramImageCacheKey(
    diagram.code,
    isDark,
    themeVars,
    isSvg: diagram.isSvg,
  );
  final distinct = codes
      .toSet()
      .where((c) => MermaidImageCache.get(cacheKey(c)) == null)
      .toList();
  if (distinct.isEmpty) return;

  final overlay = Overlay.maybeOf(context);
  if (overlay == null) return;

  // Sequentially render codes with a single offscreen overlay to avoid heavy composites
  for (final diagram in distinct) {
    if (!context.mounted) return;
    final key = GlobalKey();
    final factory = debugDiagramExportViewFactory;
    final handle = factory != null
        ? factory(diagram)
        : createMermaidView(
            diagram.code,
            isDark,
            themeVars: themeVars,
            viewKey: key,
            isSvg: diagram.isSvg,
          );
    if (handle == null) continue;
    final ready = Completer<void>();
    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (ctx) {
        // Wait a few frames to allow WebView to load and mermaid to render
        WidgetsBinding.instance.addPostFrameCallback((_) async {
          if (!ready.isCompleted) ready.complete();
        });
        return Positioned(
          left: -10000,
          top: -10000,
          child: ConstrainedBox(
            constraints: const BoxConstraints.tightFor(width: 720, height: 600),
            child: Material(color: Colors.transparent, child: handle.widget),
          ),
        );
      },
    );
    overlay.insert(entry);
    try {
      // Wait initial frame and a small delay for mermaid.run
      await ready.future;
      await Future<void>.delayed(const Duration(milliseconds: 500));
      final toBytes = handle.exportPngBytes;
      if (toBytes != null) {
        Uint8List? bytes;
        // Retry a few times as Mermaid may not be ready immediately
        for (int i = 0; i < 8; i++) {
          bytes = await toBytes();
          if (bytes != null && bytes.isNotEmpty) break;
          await Future<void>.delayed(const Duration(milliseconds: 200));
        }
        if (bytes != null && bytes.isNotEmpty) {
          MermaidImageCache.put(cacheKey(diagram), bytes);
        }
      }
    } finally {
      entry.remove();
    }
  }
}
