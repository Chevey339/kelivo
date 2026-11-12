import 'dart:convert';
import 'dart:typed_data';

const browserFaviconMaxBytes = 32 * 1024;
const browserFaviconMaxSites = 48;

String? browserFaviconSite(String url) {
  final uri = Uri.tryParse(url);
  if (uri == null ||
      !const ['http', 'https'].contains(uri.scheme) ||
      uri.host.isEmpty ||
      uri.userInfo.isNotEmpty) {
    return null;
  }
  return uri.origin;
}

String browserFaviconDocument(String url) =>
    Uri.tryParse(url)?.removeFragment().toString() ?? url;

bool isBrowserFavicon(Uint8List bytes) {
  if (bytes.length < 24 || bytes.length > browserFaviconMaxBytes) return false;
  const signature = [137, 80, 78, 71, 13, 10, 26, 10];
  for (var i = 0; i < signature.length; i++) {
    if (bytes[i] != signature[i]) return false;
  }
  if (ascii.decode(bytes.sublist(12, 16), allowInvalid: true) != 'IHDR') {
    return false;
  }
  final header = ByteData.sublistView(bytes);
  final width = header.getUint32(16);
  final height = header.getUint32(20);
  return width > 0 && height > 0 && width <= 64 && height <= 64;
}

Uint8List? decodeBrowserFavicon(Object? encoded) {
  if (encoded is! String ||
      encoded.length > 4 * ((browserFaviconMaxBytes + 2) ~/ 3)) {
    return null;
  }
  try {
    final bytes = base64Decode(encoded);
    return isBrowserFavicon(bytes) ? bytes : null;
  } on FormatException {
    return null;
  }
}

/// The browser itself loads/decodes PNG, ICO and SVG using its cookie session,
/// proxy and image policy. Cross-origin images must permit canvas access; a
/// tainted canvas is never exported. No Dart HTTP client or third-party service.
const browserFaviconScript = r'''
(async () => {
  if (!/^https?:$/.test(location.protocol)) return null;
  const page = document;
  const pageUrl = location.href.split('#')[0];
  const current = () => document === page && location.href.split('#')[0] === pageUrl;
  const links = Array.from(document.querySelectorAll('link[rel]'))
    .filter(link => /(?:^|\s)(?:icon|apple-touch-icon(?:-precomposed)?)(?:\s|$)/i.test(link.rel)
      && (!link.media || matchMedia(link.media).matches))
    .sort((a, b) => Number(/apple-touch/i.test(a.rel)) - Number(/apple-touch/i.test(b.rel)));
  const urls = [...new Set(links.map(link => link.href))].slice(0, 4);
  const fallback = new URL('/favicon.ico', location.href).href;
  if (!urls.includes(fallback)) urls.push(fallback);
  for (const source of urls) {
    if (!current()) return null;
    if (source.length > 65536 || !/^(https?:|data:image\/)/i.test(source)) continue;
    const png = await new Promise(resolve => {
      const image = new Image();
      let settled = false;
      const finish = value => {
        if (settled) return;
        settled = true;
        clearTimeout(timer);
        image.onload = image.onerror = null;
        image.src = 'data:,';
        resolve(value);
      };
      const timer = setTimeout(() => finish(null), 1400);
      // Same-origin requests retain cookies. Public CDN icons can opt into CORS.
      image.crossOrigin = 'anonymous';
      image.onerror = () => finish(null);
      image.onload = () => {
        try {
          if (!current() || !image.naturalWidth || !image.naturalHeight ||
              image.naturalWidth > 4096 || image.naturalHeight > 4096) {
            finish(null); return;
          }
          const canvas = document.createElement('canvas');
          canvas.width = canvas.height = 64;
          const context = canvas.getContext('2d');
          if (!context) { finish(null); return; }
          const scale = Math.min(64 / image.naturalWidth, 64 / image.naturalHeight);
          const width = image.naturalWidth * scale, height = image.naturalHeight * scale;
          context.drawImage(image, (64 - width) / 2, (64 - height) / 2, width, height);
          const value = canvas.toDataURL('image/png').split(',')[1];
          finish(value && value.length <= 43692 ? value : null);
        } catch (_) { finish(null); }
      };
      image.src = source;
    });
    if (png && current()) return {pageUrl, png};
  }
  return null;
})()
''';
