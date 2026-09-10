import 'dart:convert';

import 'package:xml/xml.dart';
import 'package:xml/xml_events.dart';

bool isSvgCodeBlock(String language, String source) {
  final lang = language.trim().toLowerCase();
  if (lang == 'svg') return true;
  if (lang != 'xml') return false;
  try {
    // Pull parsing consumes each preamble event once and stops at the root.
    // It also accepts a root whose body is still being streamed.
    for (final event in parseEvents(source, validateDocument: true)) {
      if (event is XmlStartElementEvent) return event.localName == 'svg';
      if (event is XmlTextEvent && event.value.trim().isNotEmpty) return false;
    }
  } on XmlException {
    return false;
  }
  return false;
}

String? svgPreviewDataUri(String source) {
  try {
    final root = XmlDocument.parse(source).rootElement;
    if (root.name.local != 'svg' ||
        (root.namespaceUri != null &&
            root.namespaceUri != 'http://www.w3.org/2000/svg')) {
      return null;
    }
    if (root.namespaceUri == null) {
      root.setAttribute('xmlns', 'http://www.w3.org/2000/svg');
    }
    return 'data:image/svg+xml;base64,${base64Encode(utf8.encode(root.toXmlString()))}';
  } on XmlException {
    return null;
  }
}

/// Uses an SVG image document so embedded scripts cannot run in the WebView.
/// The existing diagram bridge requests its PNG, then disposes the WebView.
String buildSvgPreviewHtml(String source) {
  final uri = svgPreviewDataUri(source) ?? '';
  return '''<!doctype html>
<html><head><meta charset="utf-8" /></head><body>
<script>
const image = new Image();
let loaded = false;
function sendExport(data) {
  if (window.ExportChannel) ExportChannel.postMessage(data);
  if (window.chrome && window.chrome.webview) {
    window.chrome.webview.postMessage(JSON.stringify({type: 'export', data}));
  }
}
image.onload = function() { loaded = true; };
image.src = '$uri';
window.exportSvgToPng = function() {
  if (!loaded || !image.naturalWidth || !image.naturalHeight) {
    sendExport('');
    return;
  }
  try {
    const w = image.naturalWidth, h = image.naturalHeight;
    // Bound memory even for model-generated SVGs with enormous dimensions.
    const scale = Math.min(4, 2048 / Math.max(w, h));
    const canvas = document.createElement('canvas');
    canvas.width = Math.max(1, Math.round(w * scale));
    canvas.height = Math.max(1, Math.round(h * scale));
    const ctx = canvas.getContext('2d');
    ctx.fillStyle = '#f8f8f8';
    ctx.fillRect(0, 0, canvas.width, canvas.height);
    ctx.drawImage(image, 0, 0, canvas.width, canvas.height);
    sendExport(canvas.toDataURL('image/png').split(',')[1]);
  } catch (_) { sendExport(''); }
};
</script></body></html>''';
}
