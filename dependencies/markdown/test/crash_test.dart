// Copyright (c) 2022, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:http/http.dart' as http;
import 'package:http/retry.dart' as http;
import 'package:markdown/markdown.dart';
import 'package:pool/pool.dart';
import 'package:tar/tar.dart';
import 'package:test/test.dart';

// ignore_for_file: avoid_dynamic_calls

const extensions = [
  '.md',
  '.mkd',
  '.mdwn',
  '.mdown',
  '.mdtxt',
  '.mdtext',
  '.markdown',
  'README',
  'CHANGELOG',
];

void main() async {
  // This test is a really dumb and very slow crash-test.
  // It downloads the latest package version for each package on pub.dev
  // and tries to parse all `*.md` files in the package, counting the number
  // of times where the parser throws.
  //
  // Needless to say, this test is very slow and running it eats a lot of CPU.
  // But it's a fairly good way to try a lot of real-world markdown text to see
  // if any of the poorly formatted markdown causes the parser to crash.
  test(
    'crash test',
    () async {
      final started = DateTime.now();
      var lastStatus = DateTime(0);
      void status(String Function() message) {
        if (DateTime.now().difference(lastStatus) >
            const Duration(seconds: 5)) {
          lastStatus = DateTime.now();
          print(message());
        }
      }

      final c = http.RetryClient(http.Client());
      Future<Map<String, dynamic>?> getJson(String url) async {
        final u = Uri.tryParse(url);
        if (u == null) {
          return null;
        }
        try {
          final data = await c.read(u);
          try {
            return jsonDecode(data) as Map<String, dynamic>;
          } on FormatException {
            return null;
          }
        } on http.ClientException {
          return null;
        } on IOException {
          return null;
        }
      }

      final packages =
          ((await getJson('https://pub.dev/api/package-names'))!['packages']
                  as List)
              .cast<String>();
      //.take(3).toList(); // useful when testing
      print('## Found ${packages.length} packages to scan');

      var count = 0;
      final pool = Pool(50);
      final packageVersions = <PackageVersion>[];
      await Future.wait(
        packages.map((package) async {
          await pool.withResource(() async {
            final response = await getJson(
              'https://pub.dev/api/packages/$package',
            );
            final entry = response?['latest'] as Map?;
            if (entry != null) {
              packageVersions.add(
                PackageVersion(
                  package: package,
                  version: entry['version'] as String,
                  archiveUrl: entry['archive_url'] as String,
                ),
              );
            }
            count++;
            status(
              () => 'Listed versions for $count / ${packages.length} packages',
            );
          });
        }),
      );

      print('## Found ${packageVersions.length} package versions to scan');

      count = 0;
      final errors = <String>[];
      var skipped = 0;
      await Future.wait(
        packageVersions.map((pv) async {
          await pool.withResource(() async {
            final archiveUrl = Uri.tryParse(pv.archiveUrl);
            if (archiveUrl == null) {
              skipped++;
              return;
            }
            late List<int> archive;
            try {
              archive = await c.readBytes(archiveUrl);
            } on http.ClientException {
              skipped++;
              return;
            } on IOException {
              skipped++;
              return;
            }

            final result = await _findMarkdownIssues(
              pv.package,
              pv.version,
              archive,
            );

            // If tar decoding fails.
            if (result == null) {
              skipped++;
              return;
            }

            errors.addAll(result);
            result.forEach(print);
          });
          count++;
          status(
            () =>
                'Scanned $count / ${packageVersions.length} (skipped $skipped),'
                ' found ${errors.length} issues',
          );
        }),
      );

      await pool.close();
      c.close();

      print('## Finished scanning');
      print(
        'Scanned ${packageVersions.length} package versions in '
        '${DateTime.now().difference(started)}',
      );

      if (errors.isNotEmpty) {
        print('Found issues:');
        errors.forEach(print);
        fail('Found ${errors.length} cases where markdownToHtml threw!');
      }
    },
    timeout: const Timeout(Duration(hours: 5)),
    tags: 'crash_test', // skipped by default, see: dart_test.yaml
  );
}

class PackageVersion {
  final String package;
  final String version;
  final String archiveUrl;

  PackageVersion({
    required this.package,
    required this.version,
    required this.archiveUrl,
  });
}

/// Scans [gzippedArchive] for markdown files and tries to parse them all.
///
/// Creates a list of issues that arose when parsing markdown files. The
/// [package] and [version] strings are used to construct nice issues.
/// An issue string may be multi-line, but should be printable.
///
/// Returns a list of issues, or `null` if decoding and parsing [gzippedArchive]
/// failed.
Future<List<String>?> _findMarkdownIssues(
  String package,
  String version,
  List<int> gzippedArchive,
) async {
  return Isolate.run<List<String>?>(() async {
    try {
      final archive = gzip.decode(gzippedArchive);
      final issues = <String>[];
      await TarReader.forEach(Stream.value(archive), (entry) async {
        if (extensions.any((ext) => entry.name.endsWith(ext))) {
          late String contents;
          try {
            final bytes = await http.ByteStream(entry.contents).toBytes();
            contents = utf8.decode(bytes);
          } on FormatException {
            return; // ignore invalid utf8
          }
          final start = DateTime.now();
          try {
            markdownToHtml(contents, extensionSet: ExtensionSet.gitHubWeb);
          } catch (err, st) {
            issues.add(
              'package:$package-$version/${entry.name}, throws: $err\n$st',
            );
          }
          final time = DateTime.now().difference(start);
          if (time.inSeconds > 30) {
            issues.add(
              'package:$package-$version/${entry.name} took $time to process',
            );
          }
        }
      });
      return issues;
    } on FormatException {
      return null;
    }
  }).timeout(
    const Duration(minutes: 2),
    onTimeout: () {
      return ['package:$package-$version failed to be processed in 2 minutes'];
    },
  );
}
