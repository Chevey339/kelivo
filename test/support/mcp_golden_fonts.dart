import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';

Future<void> loadMcpGoldenFonts() async {
  final fonts =
      jsonDecode(await rootBundle.loadString('FontManifest.json')) as List;
  for (final font in fonts.cast<Map<String, dynamic>>()) {
    final loader = FontLoader(font['family'] as String);
    for (final asset in (font['fonts'] as List).cast<Map<String, dynamic>>()) {
      loader.addFont(rootBundle.load(asset['asset'] as String));
    }
    await loader.load();
  }
  final bytes = File(
    'test/fixtures/fonts/JetBrainsMono-Regular.ttf',
  ).readAsBytesSync();
  for (final family in ['mcp-golden', 'Roboto']) {
    await (FontLoader(
      family,
    )..addFont(Future.value(ByteData.sublistView(bytes)))).load();
  }
}
