import 'dart:io';

import 'package:Kelivo/utils/kelivo_file_uri.dart';
import 'package:Kelivo/utils/sandbox_path_resolver.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  tearDown(() {
    SandboxPathResolver.debugSetDirs(docsDir: null, supportDir: null);
  });

  group('SandboxPathResolver.fix kelivo-file', () {
    test('resolves canonical URI to absolute path without FS probe', () {
      const docs = '/tmp/kelivo_docs_does_not_need_to_exist';
      SandboxPathResolver.debugSetDirs(docsDir: docs);

      const uri = 'kelivo-file:///upload/missing_no_fs_probe.png';
      final fixed = SandboxPathResolver.fix(uri);

      expect(fixed, p.join(docs, 'upload', 'missing_no_fs_probe.png'));
      expect(File(fixed).existsSync(), isFalse);
    });

    test('returns kelivo-file URI unchanged when docsDir is null', () {
      SandboxPathResolver.debugSetDirs(docsDir: null);
      const uri = 'kelivo-file:///images/photo.png';
      expect(SandboxPathResolver.fix(uri), uri);
    });

    test(
      'returns invalid kelivo-file URI unchanged (no strip/file fallback)',
      () {
        const docs = '/tmp/kelivo_docs';
        SandboxPathResolver.debugSetDirs(docsDir: docs);
        const uri = 'kelivo-file:not-a-valid-structure';
        expect(SandboxPathResolver.fix(uri), uri);
      },
    );
  });

  group('SandboxPathResolver.fix legacy absolute paths', () {
    test('maps old Documents absolute path when file exists under docs', () {
      final temp = Directory.systemTemp.createTempSync('sandbox_fix_');
      addTearDown(() {
        if (temp.existsSync()) temp.deleteSync(recursive: true);
      });

      final uploadDir = Directory(p.join(temp.path, 'upload'))..createSync();
      final file = File(p.join(uploadDir.path, 'legacy.png'))
        ..writeAsStringSync('ok');

      SandboxPathResolver.debugSetDirs(docsDir: temp.path);

      const oldPath =
          '/var/mobile/Containers/Data/Application/OLDUUID/Documents/upload/legacy.png';
      expect(SandboxPathResolver.fix(oldPath), file.path);
    });
  });

  group('SandboxPathResolver.dedupeKey', () {
    test('matches kelivo-file URI and absolute path of the same file', () {
      final temp = Directory.systemTemp.createTempSync('sandbox_dedupe_');
      addTearDown(() {
        if (temp.existsSync()) temp.deleteSync(recursive: true);
      });
      Directory(p.join(temp.path, 'upload')).createSync();
      final file = File(p.join(temp.path, 'upload', 'draft-0.png'))
        ..writeAsStringSync('ok');
      SandboxPathResolver.debugSetDirs(docsDir: temp.path);

      expect(
        SandboxPathResolver.dedupeKey('kelivo-file:///upload/draft-0.png'),
        SandboxPathResolver.dedupeKey(file.path),
      );
    });

    test('leaves http and data URIs unchanged', () {
      const http = 'https://example.com/a.png';
      const data = 'data:image/png;base64,AAAA';
      expect(SandboxPathResolver.dedupeKey(http), http);
      expect(SandboxPathResolver.dedupeKey(data), data);
    });
  });

  group('SandboxPathResolver.fix http/data pass-through', () {
    test('leaves http(s) and data URIs unchanged', () {
      SandboxPathResolver.debugSetDirs(docsDir: '/tmp/kelivo_docs');

      expect(
        SandboxPathResolver.fix('https://cdn.example.com/a.png'),
        'https://cdn.example.com/a.png',
      );
      expect(
        SandboxPathResolver.fix('http://example.com/b.png'),
        'http://example.com/b.png',
      );
      expect(
        SandboxPathResolver.fix('data:image/png;base64,abc'),
        'data:image/png;base64,abc',
      );
    });
  });

  group('SandboxPathResolver.canonicalize', () {
    test('passes through remote / data / already-canonical URIs', () {
      SandboxPathResolver.debugSetDirs(docsDir: '/tmp/kelivo_docs');

      expect(SandboxPathResolver.canonicalize(''), '');
      expect(
        SandboxPathResolver.canonicalize('https://cdn.example.com/a.png'),
        'https://cdn.example.com/a.png',
      );
      expect(
        SandboxPathResolver.canonicalize('http://example.com/b.png'),
        'http://example.com/b.png',
      );
      expect(
        SandboxPathResolver.canonicalize('data:image/png;base64,abc'),
        'data:image/png;base64,abc',
      );
      expect(
        SandboxPathResolver.canonicalize('kelivo-file:///upload/a.png'),
        'kelivo-file:///upload/a.png',
      );
      // Cheap prefix: illegal structure still passes through.
      expect(
        SandboxPathResolver.canonicalize('kelivo-file:garbage'),
        'kelivo-file:garbage',
      );
    });

    test('encodes managed absolute path under docsDir', () {
      const docs = '/tmp/kelivo_docs';
      SandboxPathResolver.debugSetDirs(docsDir: docs);

      final abs = p.join(docs, 'upload', 'a.png');
      expect(
        SandboxPathResolver.canonicalize(abs),
        'kelivo-file:///upload/a.png',
      );
      expect(
        SandboxPathResolver.canonicalize('file://$abs'),
        'kelivo-file:///upload/a.png',
      );
    });

    test('encodes legacy absolute path via marker heuristics', () {
      SandboxPathResolver.debugSetDirs(docsDir: null);
      const legacy =
          '/var/mobile/Containers/Data/Application/A1B2C3D4-E5F6-7890-ABCD-EF1234567890/Documents/images/pic.png';
      expect(
        SandboxPathResolver.canonicalize(legacy),
        'kelivo-file:///images/pic.png',
      );
    });

    test('returns external absolute path unchanged', () {
      SandboxPathResolver.debugSetDirs(docsDir: '/tmp/kelivo_docs');
      const external = '/usr/local/share/photo.png';
      expect(SandboxPathResolver.canonicalize(external), external);
      expect(SandboxPathResolver.canonicalize('file://$external'), external);
    });

    test('does not guess external /images/ paths into kelivo-file', () {
      SandboxPathResolver.debugSetDirs(docsDir: '/tmp/kelivo_docs');
      const external = '/mnt/archive/images/photo.jpg';
      expect(SandboxPathResolver.canonicalize(external), external);
    });

    test('decodes file:// percent-escapes before encoding', () {
      const docs = '/tmp/kelivo_docs';
      SandboxPathResolver.debugSetDirs(docsDir: docs);
      const fileUri = 'file:///tmp/kelivo_docs/upload/My%20Photo.png';
      expect(
        SandboxPathResolver.canonicalize(fileUri),
        'kelivo-file:///upload/My%20Photo.png',
      );
    });

    test('passes through uppercase HTTPS without local guessing', () {
      SandboxPathResolver.debugSetDirs(docsDir: '/tmp/kelivo_docs');
      const remote = 'HTTPS://cdn.example.com/images/a.png';
      expect(SandboxPathResolver.canonicalize(remote), remote);
    });

    test('with docsDir set still encodes structured legacy UUID paths', () {
      SandboxPathResolver.debugSetDirs(docsDir: '/tmp/kelivo_docs_current');
      const legacy =
          '/var/mobile/Containers/Data/Application/A1B2C3D4-E5F6-7890-ABCD-EF1234567890/Documents/images/pic.png';
      expect(
        SandboxPathResolver.canonicalize(legacy),
        'kelivo-file:///images/pic.png',
      );
      // Generic /images/ outside structured markers still not guessed.
      expect(
        SandboxPathResolver.canonicalize('/mnt/archive/images/photo.jpg'),
        '/mnt/archive/images/photo.jpg',
      );
    });

    test('leaves non-local file: URIs unchanged', () {
      SandboxPathResolver.debugSetDirs(docsDir: '/tmp/kelivo_docs');
      const unc = 'file://attacker/share/a.png';
      expect(SandboxPathResolver.canonicalize(unc), unc);
    });
    test('round-trips with encodeFromAbsolute helper', () {
      const docs = '/data/app';
      SandboxPathResolver.debugSetDirs(docsDir: docs);
      final abs = p.join(docs, 'avatars', 'me.png');
      final uri = SandboxPathResolver.canonicalize(abs);
      expect(uri, KelivoFileUri.encodeFromAbsolute(abs, root: docs));
      expect(SandboxPathResolver.fix(uri), abs);
    });
  });

  group('SandboxPathResolver.tryDecodeLocalFileUri', () {
    test('decodes local file URIs and rejects UNC/SMB hosts', () {
      final local = Uri.parse(
        'file:///tmp/kelivo_docs/upload/a.png',
      ).toFilePath();
      expect(
        SandboxPathResolver.tryDecodeLocalFileUri(
          'file:///tmp/kelivo_docs/upload/a.png',
        ),
        local,
      );
      expect(
        SandboxPathResolver.tryDecodeLocalFileUri(
          'file://localhost/tmp/kelivo_docs/upload/a.png',
        ),
        local,
      );
      expect(
        SandboxPathResolver.tryDecodeLocalFileUri(
          'file://attacker/share/a.png',
        ),
        isNull,
      );
      expect(
        SandboxPathResolver.tryDecodeLocalFileUri(
          'file:////attacker/share/a.png',
        ),
        isNull,
      );
    });
  });

  group('SandboxPathResolver.localFileExists / resolveForIo', () {
    test('does not alias missing external /images/ onto managed file', () {
      final temp = Directory.systemTemp.createTempSync('sandbox_io_');
      addTearDown(() {
        if (temp.existsSync()) temp.deleteSync(recursive: true);
      });
      final images = Directory(p.join(temp.path, 'images'))..createSync();
      File(p.join(images.path, 'photo.jpg')).writeAsStringSync('managed');
      SandboxPathResolver.debugSetDirs(docsDir: temp.path);

      const external = '/mnt/archive/images/photo.jpg';
      expect(File(external).existsSync(), isFalse);
      // fix() may still alias via generic/basename; IO helpers must not.
      expect(SandboxPathResolver.localFileExists(external), isFalse);
      expect(SandboxPathResolver.resolveForIo(external), external);
    });

    test('remaps structured legacy Documents paths when target exists', () {
      final temp = Directory.systemTemp.createTempSync('sandbox_io_legacy_');
      addTearDown(() {
        if (temp.existsSync()) temp.deleteSync(recursive: true);
      });
      final upload = Directory(p.join(temp.path, 'upload'))..createSync();
      final file = File(p.join(upload.path, 'legacy.png'))
        ..writeAsStringSync('ok');
      SandboxPathResolver.debugSetDirs(docsDir: temp.path);

      const oldPath =
          '/var/mobile/Containers/Data/Application/A1B2C3D4-E5F6-7890-ABCD-EF1234567890/Documents/upload/legacy.png';
      expect(SandboxPathResolver.localFileExists(oldPath), isTrue);
      expect(SandboxPathResolver.resolveForIo(oldPath), file.path);
    });
  });

  group('SandboxPathResolver.resolveForIo UNC rejection', () {
    test('rejects //, \\, and remote file: before any existence probe', () {
      SandboxPathResolver.debugSetDirs(docsDir: '/tmp/kelivo_docs');
      expect(
        SandboxPathResolver.resolveForIo('//attacker/share/a.png'),
        isNull,
      );
      expect(
        SandboxPathResolver.resolveForIo(r'\\attacker\share\a.png'),
        isNull,
      );
      expect(
        SandboxPathResolver.resolveForIo('file://attacker/share/a.png'),
        isNull,
      );
      expect(
        SandboxPathResolver.localFileExists('//attacker/share/a.png'),
        isFalse,
      );
    });
  });

  group('SandboxPathResolver.fix backslash handling', () {
    test('keeps POSIX backslash filenames unchanged when unmatched', () {
      SandboxPathResolver.debugSetDirs(docsDir: '/tmp/docs');
      const posix = r'/tmp/other/upload/a\b.png';
      expect(SandboxPathResolver.fix(posix), posix);
    });

    test('matches Windows drive paths with backslashes via Kelivo marker', () {
      final temp = Directory.systemTemp.createTempSync('sandbox_win_');
      addTearDown(() {
        if (temp.existsSync()) temp.deleteSync(recursive: true);
      });
      final images = Directory(p.join(temp.path, 'images'))..createSync();
      final file = File(p.join(images.path, 'x.png'))..writeAsStringSync('x');
      SandboxPathResolver.debugSetDirs(docsDir: temp.path);
      // Use forward-slash Windows-like legacy form (lexical); ensure Kelivo
      // case variants canonicalize even with generic fallback disabled.
      expect(
        SandboxPathResolver.canonicalize(
          r'C:\Users\me\AppData\Local\Kelivo\images\x.png',
        ),
        'kelivo-file:///images/x.png',
      );
      expect(file.existsSync(), isTrue);
    });
  });

  group('SandboxPathResolver.canonicalize ordinary Documents', () {
    test('does not encode ~/Documents/images as managed', () {
      SandboxPathResolver.debugSetDirs(docsDir: '/tmp/kelivo_docs');
      const external = '/Users/alice/Documents/images/report.png';
      expect(SandboxPathResolver.canonicalize(external), external);
    });
  });

  group('SandboxPathResolver.resolveForIo prefers existing external file', () {
    test('does not alias onto same-named managed file', () {
      final temp = Directory.systemTemp.createTempSync('sandbox_alias_');
      addTearDown(() {
        if (temp.existsSync()) temp.deleteSync(recursive: true);
      });
      final managedDir = Directory(p.join(temp.path, 'images'))..createSync();
      File(p.join(managedDir.path, 'photo.jpg')).writeAsStringSync('managed');
      final externalDir = Directory(p.join(temp.path, 'external', 'images'))
        ..createSync(recursive: true);
      final external = File(p.join(externalDir.path, 'photo.jpg'))
        ..writeAsStringSync('external-bytes');
      SandboxPathResolver.debugSetDirs(docsDir: temp.path);

      expect(SandboxPathResolver.resolveForIo(external.path), external.path);
      expect(
        File(
          SandboxPathResolver.resolveForIo(external.path)!,
        ).readAsStringSync(),
        'external-bytes',
      );
    });
  });

  group('SandboxPathResolver.tryRemapRestoredManagedAbsolute', () {
    test('maps old Windows company/product root when restored file exists', () {
      final temp = Directory.systemTemp.createTempSync('sandbox_restore_win_');
      addTearDown(() {
        if (temp.existsSync()) temp.deleteSync(recursive: true);
      });
      final upload = Directory(p.join(temp.path, 'upload'))..createSync();
      File(p.join(upload.path, 'legacy.pdf')).writeAsStringSync('restored');
      SandboxPathResolver.debugSetDirs(docsDir: temp.path);

      expect(
        SandboxPathResolver.tryRemapRestoredManagedAbsolute(
          r'C:\Users\old-user\AppData\Roaming\com.psyche\kelivo\upload\legacy.pdf',
        ),
        'kelivo-file:///upload/legacy.pdf',
      );
    });

    test('maps old mac absolute root only when restored file exists', () {
      final temp = Directory.systemTemp.createTempSync('sandbox_restore_');
      addTearDown(() {
        if (temp.existsSync()) temp.deleteSync(recursive: true);
      });
      final images = Directory(p.join(temp.path, 'images'))..createSync();
      File(p.join(images.path, 'a.png')).writeAsStringSync('restored');
      SandboxPathResolver.debugSetDirs(docsDir: temp.path);

      const oldMac =
          '/Users/alice/Library/Application Support/com.psyche.kelivo/images/a.png';
      expect(
        SandboxPathResolver.tryRemapRestoredManagedAbsolute(oldMac),
        'kelivo-file:///images/a.png',
      );
      // Missing relative must not remap.
      expect(
        SandboxPathResolver.tryRemapRestoredManagedAbsolute(
          '/Users/alice/Library/Application Support/com.psyche.kelivo/images/missing.png',
        ),
        isNull,
      );
      // Ordinary external /images/ without restored file stays null.
      expect(
        SandboxPathResolver.tryRemapRestoredManagedAbsolute(
          '/mnt/archive/images/a.png',
        ),
        isNull,
      );
    });

    test('portable iOS file: URI canonicalizes on any host separators', () {
      SandboxPathResolver.debugSetDirs(docsDir: '/tmp/kelivo_docs');
      expect(
        SandboxPathResolver.canonicalize(
          'file:///var/mobile/Containers/Data/Application/A1B2C3D4-E5F6-7890-ABCD-EF1234567890/Documents/images/pic.png',
        ),
        'kelivo-file:///images/pic.png',
      );
    });
  });
}
