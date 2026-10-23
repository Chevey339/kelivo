import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:path/path.dart' as p;

/// Check the SDK and the pure evaluator's resolved dependency versions. The
/// application intentionally ignores pubspec.lock, so Git guards alone cannot
/// establish which hosted packages the running CLI actually imported.
Future<void> verifyEvaluationRuntime(
  String root,
  Map<String, dynamic> expected,
) async {
  if (Platform.version.split(' ').first != expected['dart']) {
    throw const FormatException(
      'Evaluation Dart SDK differs from the frozen configuration',
    );
  }
  final uri = await Isolate.packageConfig;
  if (uri == null ||
      uri.scheme != 'file' ||
      await File.fromUri(uri).resolveSymbolicLinks() !=
          p.join(root, '.dart_tool', 'package_config.json')) {
    throw const FormatException('Use the repository package resolution');
  }
  final configuration =
      jsonDecode(await File.fromUri(uri).readAsString())
          as Map<String, dynamic>;
  final packages = {
    for (final package
        in (configuration['packages'] as List).cast<Map<String, dynamic>>())
      package['name'] as String: package,
  };
  for (final local in {
    'Kelivo': root,
    'markstream': p.join(root, 'dependencies', 'markstream'),
  }.entries) {
    final package = packages[local.key];
    if (package == null ||
        await Directory.fromUri(
              uri.resolve(package['rootUri'] as String),
            ).resolveSymbolicLinks() !=
            local.value) {
      throw const FormatException(
        'Local package resolves outside the tested checkout',
      );
    }
    await _verifyLibrary(local.key, local.value, package);
  }
  final versions = (expected['packages'] as Map<String, dynamic>)
      .cast<String, String>();
  final lock = await File(p.join(root, 'pubspec.lock')).readAsLines();
  for (final entry in versions.entries) {
    final package = packages[entry.key];
    if (package == null) {
      throw const FormatException('Missing evaluation dependency');
    }
    final directory = Directory.fromUri(
      uri.resolve(package['rootUri'] as String),
    );
    final packageRoot = await directory.resolveSymbolicLinks();
    if (p.basename(packageRoot) != '${entry.key}-${entry.value}' ||
        p.basename(p.dirname(packageRoot)) != 'pub.dev' ||
        p.basename(p.dirname(p.dirname(packageRoot))) != 'hosted') {
      throw const FormatException(
        'Evaluation dependencies must resolve to the public hosted cache',
      );
    }
    await _verifyLibrary(entry.key, packageRoot, package);
    final pubspec = await File(
      p.join(directory.path, 'pubspec.yaml'),
    ).readAsString();
    final actual = RegExp(
      r'^version:\s*["\x27]?([^\s"\x27]+)',
      multiLine: true,
    ).firstMatch(pubspec)?.group(1);
    String? locked;
    String? source;
    String? hostedUrl;
    var inPackage = false;
    for (final line in lock) {
      if (line == '  ${entry.key}:') {
        inPackage = true;
      } else if (inPackage && RegExp(r'^  [^ ]').hasMatch(line)) {
        break;
      } else if (inPackage) {
        locked =
            RegExp(r'^    version: "([^"]+)"$').firstMatch(line)?.group(1) ??
            locked;
        source =
            RegExp(r'^    source: (\w+)$').firstMatch(line)?.group(1) ?? source;
        hostedUrl =
            RegExp(r'^      url: "([^"]+)"$').firstMatch(line)?.group(1) ??
            hostedUrl;
      }
    }
    if (actual != entry.value ||
        locked != entry.value ||
        source != 'hosted' ||
        hostedUrl != 'https://pub.dev') {
      throw FormatException(
        'Evaluation dependency version differs: ${entry.key}',
      );
    }
  }
}

Future<void> _verifyLibrary(
  String name,
  String root,
  Map<String, dynamic> package,
) async {
  final actual = await Isolate.resolvePackageUri(Uri.parse('package:$name/'));
  if (package['packageUri'] != 'lib/' ||
      actual == null ||
      actual.scheme != 'file' ||
      await Directory.fromUri(actual).resolveSymbolicLinks() !=
          p.join(root, 'lib')) {
    throw const FormatException(
      'Imported library differs from the checked package root',
    );
  }
}
