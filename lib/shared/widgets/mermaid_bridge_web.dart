// ignore_for_file: avoid_web_libraries_in_flutter
import 'dart:async';
import 'dart:typed_data';
import 'dart:html' as html;
import 'dart:js_util' as js_util;
// Flutter 3.22+ 使用 dart:ui_web 的 platformViewRegistry，旧版本为 dart:ui 的隐藏前缀。
// 这里做兼容导入，优先使用 ui_web。
// ignore: uri_does_not_exist
// ignore: uri_does_not_exist
import 'dart:ui_web' as ui_web;
import 'package:flutter/widgets.dart';
import 'mermaid_cache.dart';

class MermaidViewHandle {
  final Widget widget;
  final Future<bool> Function() exportPng;
  final Future<Uint8List?> Function()? exportPngBytes;
  MermaidViewHandle({required this.widget, required this.exportPng, this.exportPngBytes});
}

final Map<String, html.DivElement> _containers = {};

/// Web-only Mermaid renderer using JS injection (no extra Dart packages).
/// Returns a handle with the widget and an export-to-PNG action.
MermaidViewHandle? createMermaidView(String code, bool dark, {Map<String, String>? themeVars, GlobalKey? viewKey}) {
  final container = html.DivElement()
    ..style.width = '100%'
    ..style.height = (() {
      final cached = MermaidHeightCache.get(code);
      if (cached != null) return '${cached.ceil()}px';
      return '120px';
    })() // initial height from cache if available
    ..style.display = 'block';

  final mermaidDiv = html.DivElement()
    ..classes.add('mermaid')
    ..style.width = '100%'
    ..style.display = 'block'
    ..text = code; // keep content escaped/safe

  // Center and margin similar to preview styles
  final style = html.StyleElement()
    ..text = '.mermaid{ text-align:center; margin: 12px 0; }';

  container.append(style);
  container.append(mermaidDiv);

  final viewType = 'mermaid-view-${DateTime.now().microsecondsSinceEpoch}-${_viewSeq++}';
  container.id = viewType;
  // 注册 HTML view：在新版 web SDK 使用 ui_web.platformViewRegistry。
  // Web SDK: 使用 ui_web.platformViewRegistry 注册工厂
  ui_web.platformViewRegistry.registerViewFactory(viewType, (int id) => container);
  _containers[viewType] = container;

  // Ensure Mermaid script is present, then initialize and render this node.
  _ensureMermaidLoaded().then((_) async {
    try {
      final theme = dark ? 'dark' : 'default';
      final mermaid = js_util.getProperty(html.window, 'mermaid');
      final init = {
        'startOnLoad': false,
        'theme': theme,
        'securityLevel': 'loose',
        'fontFamily': 'inherit',
      };
      if (themeVars != null && themeVars.isNotEmpty) {
        init['themeVariables'] = themeVars;
      }
      js_util.callMethod(mermaid, 'initialize', [js_util.jsify(init)]);

      // Render only this node and set explicit height to fit content
      await js_util.promiseToFuture(js_util.callMethod(mermaid, 'run', [js_util.jsify({
        'nodes': [mermaidDiv],
      })]));

      // After rendering, set container height to the SVG bbox height
      final svg = mermaidDiv.querySelector('svg');
      if (svg != null) {
        final rect = svg.getBoundingClientRect();
        final h = rect.height.ceil();
        container.style.height = '${h + 16}px';
        try { MermaidHeightCache.put(code, (h + 16).toDouble()); } catch (_) {}
      }
    } catch (_) {
      // ignore; caller will still see the code content
    }
  });

  Future<bool> export() async {
    try {
      final c = _containers[viewType];
      if (c == null) return false;
      final svg = c.querySelector('.mermaid svg');
      if (svg == null) return false;
      final rect = svg.getBoundingClientRect();
      final w = rect.width.ceil();
      final h = rect.height.ceil();
      final scale = (html.window.devicePixelRatio ?? 1) * 2;
      final canvas = html.CanvasElement(width: (w * scale).floor(), height: (h * scale).floor());
      final ctx = canvas.context2D;
      final cloned = (html.DocumentFragment.html('')..append(svg.clone(true))).children.first;
      final xmlRaw = (cloned?.outerHtml ?? svg.outerHtml) ?? '';
      final img = html.ImageElement();
      final completer = Completer<void>();
      img.onLoad.listen((_) => completer.complete());
      img.onError.listen((_) => completer.complete());
      img.src = 'data:image/svg+xml;charset=utf-8,' + Uri.encodeComponent(xmlRaw);
      await completer.future;
      final bg = (themeVars != null && themeVars['background'] != null) ? themeVars['background']! : '#ffffff';
      ctx.fillStyle = bg;
      ctx.fillRect(0, 0, canvas.width!.toDouble(), canvas.height!.toDouble());
      ctx.drawImageScaled(img, 0, 0, canvas.width!, canvas.height!);
      final dataUrl = canvas.toDataUrl('image/png');
      final a = html.AnchorElement(href: dataUrl)
        ..download = 'mermaid_${DateTime.now().millisecondsSinceEpoch}.png'
        ..style.display = 'none';
      html.document.body?.append(a);
      a.click();
      a.remove();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<Uint8List?> exportBytes() async {
    // Not implemented for web currently (Flutter web capture path likely not used)
    return null;
  }
  return MermaidViewHandle(widget: HtmlElementView(viewType: viewType), exportPng: export, exportPngBytes: exportBytes);
}

int _viewSeq = 0;
Completer<void>? _loader;

Future<void> _ensureMermaidLoaded() {
  // If already available, return immediately.
  final has = js_util.hasProperty(html.window, 'mermaid');
  if (has) return Future.value();

  if (_loader != null) return _loader!.future;
  _loader = Completer<void>();

  // Inject script tag to load local mermaid asset (offline)
  final script = html.ScriptElement()
    ..src = 'assets/mermaid.min.js'
    ..defer = true
    ..async = true
    ..type = 'text/javascript';
  void complete() {
    if (!(_loader?.isCompleted ?? true)) {
      _loader!.complete();
    }
  }
  script.onLoad.listen((_) => complete());
  script.onError.listen((_) => complete());
  html.document.head?.append(script);
  return _loader!.future;
}
