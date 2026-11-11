import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:xml/xml.dart';
import 'package:xml/xml_events.dart';

import 'safe_resize_image.dart';
import 'sandbox_path_resolver.dart';

bool isSvgImageSource(String source) {
  final uri = Uri.tryParse(source);
  return source.toLowerCase().startsWith('data:image/svg+xml') ||
      (uri?.path ?? source).toLowerCase().endsWith('.svg');
}

const _maxSvgBytes = 2 * 1024 * 1024;
const _svgElements = {
  'svg',
  'g',
  'defs',
  'symbol',
  'use',
  'title',
  'desc',
  'path',
  'rect',
  'circle',
  'ellipse',
  'line',
  'polyline',
  'polygon',
  'text',
  'tspan',
  'textPath',
  'clipPath',
  'mask',
  'linearGradient',
  'radialGradient',
  'stop',
  'pattern',
};
const _svgAttributes = {
  'id',
  'viewBox',
  'preserveAspectRatio',
  'width',
  'height',
  'x',
  'y',
  'x1',
  'y1',
  'x2',
  'y2',
  'cx',
  'cy',
  'r',
  'rx',
  'ry',
  'fx',
  'fy',
  'fr',
  'd',
  'points',
  'transform',
  'href',
  'fill',
  'fill-opacity',
  'fill-rule',
  'stroke',
  'stroke-width',
  'stroke-opacity',
  'stroke-linecap',
  'stroke-linejoin',
  'stroke-miterlimit',
  'stroke-dasharray',
  'stroke-dashoffset',
  'opacity',
  'color',
  'clip-path',
  'clip-rule',
  'clipPathUnits',
  'mask',
  'maskUnits',
  'maskContentUnits',
  'gradientUnits',
  'gradientTransform',
  'spreadMethod',
  'offset',
  'stop-color',
  'stop-opacity',
  'patternUnits',
  'patternContentUnits',
  'patternTransform',
  'font-family',
  'font-size',
  'font-weight',
  'font-style',
  'text-anchor',
  'text-decoration',
  'dominant-baseline',
  'alignment-baseline',
  'dx',
  'dy',
  'rotate',
  'textLength',
  'lengthAdjust',
  'startOffset',
  'display',
  'visibility',
  'vector-effect',
  'style',
};

/// A bounded native SVG subset: no scripts, animation, foreign content or
/// external resources. Local fragment references retain gradients and clipping.
String sanitizeSvgImage(String source) {
  if (source.length > _maxSvgBytes) {
    throw const FormatException('SVG too large');
  }
  var depth = 0, elements = 0;
  for (final event in parseEvents(source, validateDocument: true)) {
    if (event is XmlDoctypeEvent) {
      throw const FormatException('SVG document types are unsupported');
    }
    if (event is XmlStartElementEvent) {
      elements++;
      if (++depth > 48 || elements > 4096) {
        throw const FormatException('SVG complexity limit exceeded');
      }
      if (event.isSelfClosing) depth--;
    } else if (event is XmlEndElementEvent) {
      depth--;
    }
  }
  final root = XmlDocument.parse(source).rootElement;
  if (root.name.local != 'svg' ||
      (root.namespaceUri != null &&
          root.namespaceUri != 'http://www.w3.org/2000/svg')) {
    throw const FormatException('Expected an SVG image');
  }
  bool safeValue(String name, String value) {
    if (name == 'href') return RegExp(r'^#[\w:.-]+$').hasMatch(value.trim());
    if (value.contains('\\') || value.contains('@')) return false;
    for (final match in RegExp(
      r'url\s*\(([^()]*)\)',
      caseSensitive: false,
    ).allMatches(value)) {
      if (!RegExp('^["\']?#[\\w:.-]+["\']?\$').hasMatch(match[1]!.trim())) {
        return false;
      }
    }
    return true;
  }

  final pending = [root];
  while (pending.isNotEmpty) {
    final element = pending.removeLast();
    for (final child in element.children.toList()) {
      if (child is XmlElement) {
        if (!_svgElements.contains(child.name.local) ||
            (child.namespaceUri != null &&
                child.namespaceUri != 'http://www.w3.org/2000/svg')) {
          element.children.remove(child);
        } else {
          pending.add(child);
        }
      } else if (child is! XmlText && child is! XmlCDATA) {
        element.children.remove(child);
      }
    }
    element.attributes.removeWhere(
      (attribute) =>
          attribute.name.prefix != 'xmlns' &&
          attribute.name.qualified != 'xmlns' &&
          (!_svgAttributes.contains(attribute.name.local) ||
              !safeValue(attribute.name.local, attribute.value)),
    );
    final style = element.getAttribute('style');
    if (style != null) {
      element.setAttribute(
        'style',
        style
            .split(';')
            .where((rule) {
              final colon = rule.indexOf(':');
              return colon > 0 &&
                  _svgAttributes.contains(rule.substring(0, colon).trim()) &&
                  safeValue(
                    rule.substring(0, colon).trim(),
                    rule.substring(colon + 1),
                  );
            })
            .join(';'),
      );
    }
  }
  root.setAttribute('xmlns', 'http://www.w3.org/2000/svg');
  return root.toXmlString();
}

/// Uses Flutter's image cache and decode sizing for Markdown, the image viewer
/// and screenshot export. Raster output also works with the existing save/copy UI.
@immutable
class SvgImageProvider extends ImageProvider<SvgImageProvider> {
  const SvgImageProvider(
    this.source, {
    this.currentColor = const Color(0xff000000),
  });
  final String source;
  final Color currentColor;

  @override
  Future<SvgImageProvider> obtainKey(ImageConfiguration configuration) =>
      SynchronousFuture(this);

  @override
  ImageStreamCompleter loadImage(
    SvgImageProvider key,
    ImageDecoderCallback decode,
  ) => MultiFrameImageStreamCompleter(
    codec: _loadCodec(decode),
    scale: 1,
    debugLabel: 'SVG image',
  );

  Future<ui.Codec> _loadCodec(ImageDecoderCallback decode) async {
    try {
      return await decode(
        await ui.ImmutableBuffer.fromUint8List(await pngBytes()),
      );
    } catch (_) {
      scheduleMicrotask(() => PaintingBinding.instance.imageCache.evict(this));
      rethrow;
    }
  }

  Future<Uint8List> _read() async {
    if (source.startsWith('data:')) {
      if (source.length > _maxSvgBytes * 4) {
        throw const FormatException('SVG too large');
      }
      final data = UriData.parse(source).contentAsBytes();
      if (data.length > _maxSvgBytes) {
        throw const FormatException('SVG too large');
      }
      return data;
    }
    final uri = Uri.tryParse(source);
    HttpClient? client;
    try {
      final Stream<List<int>> stream;
      if (uri != null && (uri.scheme == 'https' || uri.scheme == 'http')) {
        client = HttpClient()..connectionTimeout = const Duration(seconds: 15);
        final request = await client
            .getUrl(uri)
            .timeout(const Duration(seconds: 15));
        final response = await request.close().timeout(
          const Duration(seconds: 15),
        );
        if (response.statusCode != HttpStatus.ok ||
            response.contentLength > _maxSvgBytes) {
          throw const FormatException('Unable to load SVG image');
        }
        stream = response;
      } else {
        stream = File(SandboxPathResolver.fix(source)).openRead();
      }
      final bytes = BytesBuilder(copy: false);
      await for (final chunk in stream.timeout(const Duration(seconds: 15))) {
        if (bytes.length + chunk.length > _maxSvgBytes) {
          throw const FormatException('SVG too large');
        }
        bytes.add(chunk);
      }
      return bytes.takeBytes();
    } finally {
      client?.close(force: true);
    }
  }

  Future<Uint8List> pngBytes() async {
    final safe = await compute(sanitizeSvgImage, utf8.decode(await _read()));
    final picture = await vg.loadPicture(
      SvgStringLoader(safe, theme: SvgTheme(currentColor: currentColor)),
      null,
    );
    try {
      if (!picture.size.width.isFinite ||
          !picture.size.height.isFinite ||
          picture.size.isEmpty) {
        throw const FormatException('Invalid SVG dimensions');
      }
      final size = clampDecodedPixelSize(
        width: picture.size.width * 2,
        height: picture.size.height * 2,
        maxEdge: 4096,
        maxPixels: 4 * 1024 * 1024,
      );
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder)
        ..scale(
          size.width / picture.size.width,
          size.height / picture.size.height,
        );
      canvas.drawPicture(picture.picture);
      final scaled = recorder.endRecording();
      try {
        final image = await scaled.toImage(size.width, size.height);
        try {
          final data = await image.toByteData(format: ui.ImageByteFormat.png);
          return data!.buffer.asUint8List(
            data.offsetInBytes,
            data.lengthInBytes,
          );
        } finally {
          image.dispose();
        }
      } finally {
        scaled.dispose();
      }
    } finally {
      picture.picture.dispose();
    }
  }

  @override
  bool operator ==(Object other) =>
      other is SvgImageProvider &&
      source == other.source &&
      currentColor == other.currentColor;
  @override
  int get hashCode => Object.hash(source, currentColor);
}
