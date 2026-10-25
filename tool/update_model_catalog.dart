import 'dart:convert';
import 'dart:io';

import 'package:Kelivo/core/services/model_catalog/catalog_entry.dart';
import 'package:Kelivo/core/services/model_catalog/model_catalog_trim.dart';

const String _defaultOutput = 'assets/model_catalog/models_dev.json';
const String _defaultUrl = 'https://models.dev/api.json';

/// Regenerates the bundled models.dev catalog snapshot.
///
/// Usage:
///   dart run tool/update_model_catalog.dart
///       [--input <path>]
///       [--output assets/model_catalog/models_dev.json]
///       [--url https://models.dev/api.json]
Future<void> main(List<String> args) async {
  try {
    final options = _parseArgs(args);
    final sourceText = options.input != null
        ? await File(options.input!).readAsString()
        : await _download(options.url);
    final decoded = jsonDecode(sourceText);
    if (decoded is! Map) {
      throw const FormatException('raw catalog must be a JSON object');
    }
    final raw = Map<String, dynamic>.from(decoded);
    final trimmed = trimModelsDevJson(raw);
    final catalog = parseTrimmedCatalog(trimmed);
    final encoded = jsonEncode(trimmed);
    final output = File(options.output);
    output.parent.createSync(recursive: true);
    final bytes = utf8.encode('$encoded\n');
    await output.writeAsBytes(bytes);
    _printStats(catalog, bytes.length);
  } on FormatException catch (error) {
    stderr.writeln(error.message);
    _usage(stderr);
    exitCode = 64;
  } catch (error) {
    stderr.writeln(error);
    exitCode = 1;
  }
}

class _Options {
  const _Options({
    this.input,
    this.output = _defaultOutput,
    this.url = _defaultUrl,
  });

  final String? input;
  final String output;
  final String url;
}

_Options _parseArgs(List<String> args) {
  String? input;
  var output = _defaultOutput;
  var url = _defaultUrl;
  for (var i = 0; i < args.length; i++) {
    String takeValue(String flag) {
      if (i + 1 >= args.length) {
        throw FormatException('$flag requires a value');
      }
      return args[++i];
    }

    switch (args[i]) {
      case '--input':
        input = takeValue('--input');
      case '--output':
        output = takeValue('--output');
      case '--url':
        url = takeValue('--url');
      case '--help':
      case '-h':
        _usage(stdout);
        exit(0);
      default:
        throw FormatException('Unknown argument: ${args[i]}');
    }
  }
  return _Options(input: input, output: output, url: url);
}

void _usage(IOSink sink) {
  sink.writeln(
    'Usage: dart run tool/update_model_catalog.dart '
    '[--input <path>] '
    '[--output $_defaultOutput] '
    '[--url $_defaultUrl]',
  );
}

Future<String> _download(String url) async {
  final uri = Uri.parse(url);
  final client = HttpClient();
  try {
    final request = await client.getUrl(uri);
    final response = await request.close();
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw HttpException(
        'GET $url failed with HTTP ${response.statusCode}',
        uri: uri,
      );
    }
    return await utf8.decodeStream(response);
  } finally {
    client.close(force: true);
  }
}

void _printStats(ModelCatalogData catalog, int bytes) {
  var models = 0;
  var reasoningOptions = 0;
  var contextLimits = 0;
  var costs = 0;
  for (final provider in catalog.providers.values) {
    for (final model in provider.models.values) {
      models++;
      if (model.reasoningOptions.isNotEmpty) {
        reasoningOptions++;
      }
      if (model.contextLimit != null) {
        contextLimits++;
      }
      if (model.costInput != null ||
          model.costOutput != null ||
          model.costCacheRead != null ||
          model.costCacheWrite != null) {
        costs++;
      }
    }
  }
  stdout.writeln('providers: ${catalog.providers.length}');
  stdout.writeln('models: $models');
  stdout.writeln('bytes: $bytes');
  stdout.writeln('reasoning_options: $reasoningOptions');
  stdout.writeln('limit.context: $contextLimits');
  stdout.writeln('cost: $costs');
}
