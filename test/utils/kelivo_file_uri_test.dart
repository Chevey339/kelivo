import 'package:Kelivo/utils/kelivo_file_uri.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('recognizes private iOS data paths across container changes', () {
    const id = 'A1B2C3D4-E5F6-7890-ABCD-EF1234567890';
    for (final root in [
      '/var/mobile/Containers/Data/Application/$id/Library/Application Support/kelivo-data',
      '/Users/alice/Library/Developer/CoreSimulator/Devices/$id/data/Containers/Data/Application/$id/Library/Application Support/kelivo-data',
    ]) {
      expect(
        KelivoFileUri.tryEncodeLegacyAbsolutePath(
          '$root/upload/file.txt',
          allowGenericFallback: false,
        ),
        'kelivo-file:///upload/file.txt',
      );
    }
    expect(
      KelivoFileUri.tryEncodeLegacyAbsolutePath(
        '/var/mobile/Containers/Data/Application/$id/Library/Application Support/unrelated/upload/file.txt',
        allowGenericFallback: false,
      ),
      isNull,
    );
  });

  group('KelivoFileUri encode/decode roundtrip', () {
    test('handles spaces, #, %, and Unicode filenames', () {
      const cases = <String>[
        'hello world.png',
        'hash#tag.png',
        'percent%20done.png',
        '写真_😀.png',
        'nested/dir/file name (1).png',
      ];

      for (final name in cases) {
        final abs = '/data/app/upload/$name';
        final uri = KelivoFileUri.encodeFromAbsolute(abs, root: '/data/app');
        expect(uri, isNotNull, reason: name);
        expect(KelivoFileUri.isKelivoFileUri(uri!), isTrue);

        final segments = KelivoFileUri.decodeToSegments(uri);
        expect(segments, isNotNull, reason: name);
        expect(segments!.first, 'upload');
        expect(segments.skip(1).join('/'), name);

        final again = KelivoFileUri.encodeFromAbsolute(
          KelivoFileUri.resolveToAbsolute(uri, root: '/data/app')!,
          root: '/data/app',
        );
        expect(again, uri);
      }
    });
  });

  group('KelivoFileUri.decodeToSegments rejects invalid URIs', () {
    test(
      'rejects path traversal, unknown managed root, host, query/fragment',
      () {
        const invalid = <String>[
          'kelivo-file:///../secret',
          'kelivo-file:///unknown/a.png',
          'kelivo-file://host/upload/a.png',
          'kelivo-file:///upload/a.png?x=1',
          'kelivo-file:///upload/a.png#frag',
          'kelivo-file:///upload//a.png',
          'kelivo-file:///upload/',
          'kelivo-file:///upload',
          'kelivo-file:///',
          'kelivo-file:',
          'file:///upload/a.png',
        ];

        for (final uri in invalid) {
          expect(KelivoFileUri.decodeToSegments(uri), isNull, reason: uri);
        }
      },
    );

    test('rejects empty path segments and dot segments', () {
      expect(
        KelivoFileUri.decodeToSegments('kelivo-file:///images/a//b.png'),
        isNull,
      );
      expect(
        KelivoFileUri.decodeToSegments('kelivo-file:///images/./a.png'),
        isNull,
      );
      expect(
        KelivoFileUri.decodeToSegments('kelivo-file:///images/foo/../a.png'),
        isNull,
      );
    });

    test('returns null for malformed percent encoding', () {
      for (final uri in const [
        'kelivo-file:///upload/%ZZ.pdf',
        'kelivo-file:///upload/%.pdf',
        'kelivo-file:///upload/%FF.pdf',
      ]) {
        expect(KelivoFileUri.decodeToSegments(uri), isNull, reason: uri);
      }
    });
  });

  group('KelivoFileUri.resolveToAbsolute', () {
    test('joins under POSIX root without existence checks', () {
      final abs = KelivoFileUri.resolveToAbsolute(
        'kelivo-file:///upload/nested/a.png',
        root: '/var/mobile/Documents',
      );
      expect(abs, '/var/mobile/Documents/upload/nested/a.png');
    });

    test('joins under Windows-style root', () {
      final abs = KelivoFileUri.resolveToAbsolute(
        'kelivo-file:///images/photo.png',
        root: r'C:\Users\me\AppData\Local\Kelivo',
      );
      expect(abs, r'C:\Users\me\AppData\Local\Kelivo\images\photo.png');
    });

    test('returns null for invalid URI', () {
      expect(
        KelivoFileUri.resolveToAbsolute(
          'kelivo-file:///unknown/a.png',
          root: '/tmp/root',
        ),
        isNull,
      );
    });
  });

  group('KelivoFileUri.tryEncodeLegacyAbsolutePath', () {
    test('encodes iOS Documents style paths even when file is missing', () {
      expect(
        KelivoFileUri.tryEncodeLegacyAbsolutePath(
          '/var/mobile/Containers/Data/Application/A1B2C3D4-E5F6-7890-ABCD-EF1234567890/Documents/upload/x.png',
        ),
        'kelivo-file:///upload/x.png',
      );
    });

    test('encodes Windows AppData kelivo style paths case-insensitively', () {
      for (final folder in ['kelivo', 'Kelivo', 'KELIVO']) {
        expect(
          KelivoFileUri.tryEncodeLegacyAbsolutePath(
            'C:/Users/me/AppData/Local/$folder/images/Pic.PNG',
            allowGenericFallback: false,
          ),
          'kelivo-file:///images/Pic.PNG',
          reason: folder,
        );
      }
      expect(
        KelivoFileUri.tryEncodeLegacyAbsolutePath(
          'C:/Users/me/AppData/Roaming/kelivo/avatars/a.png',
          allowGenericFallback: false,
        ),
        'kelivo-file:///avatars/a.png',
      );
      expect(
        KelivoFileUri.tryEncodeLegacyAbsolutePath(
          r'C:\Users\old-user\AppData\Roaming\com.psyche\kelivo\upload\legacy.pdf',
          allowGenericFallback: false,
        ),
        'kelivo-file:///upload/legacy.pdf',
      );
      // Bare .../Kelivo/images without AppData must not match.
      expect(
        KelivoFileUri.tryEncodeLegacyAbsolutePath(
          'C:/Users/me/Projects/Kelivo/images/x.png',
          allowGenericFallback: false,
        ),
        isNull,
      );
      // Suffix / prefix folder names must not match.
      expect(
        KelivoFileUri.tryEncodeLegacyAbsolutePath(
          'C:/Users/me/AppData/Local/KelivoNotes/images/x.png',
          allowGenericFallback: false,
        ),
        isNull,
      );
    });

    test(
      'encodes Android package-private app_flutter and files style paths',
      () {
        expect(
          KelivoFileUri.tryEncodeLegacyAbsolutePath(
            '/data/user/0/com.psyche.kelivo/app_flutter/fonts/a.ttf',
            allowGenericFallback: false,
          ),
          'kelivo-file:///fonts/a.ttf',
        );
        expect(
          KelivoFileUri.tryEncodeLegacyAbsolutePath(
            '/data/user/0/com.psyche.kelivo/files/upload/doc.pdf',
            allowGenericFallback: false,
          ),
          'kelivo-file:///upload/doc.pdf',
        );
        // Non-kelivo package must not be claimed without generic fallback.
        expect(
          KelivoFileUri.tryEncodeLegacyAbsolutePath(
            '/data/user/0/com.example/app_flutter/fonts/a.ttf',
            allowGenericFallback: false,
          ),
          isNull,
        );
      },
    );

    test('rejects lookalike bundles, fake UUIDs, and nested archives', () {
      // Ordinary paths / substring Kelivo.
      expect(
        KelivoFileUri.tryEncodeLegacyAbsolutePath(
          '/Users/alice/Documents/images/report.png',
          allowGenericFallback: false,
        ),
        isNull,
      );
      expect(
        KelivoFileUri.tryEncodeLegacyAbsolutePath(
          '/Users/alice/Projects/Kelivo/images/x.png',
          allowGenericFallback: false,
        ),
        isNull,
      );
      // Similar-but-not-whitelist bundles/packages.
      expect(
        KelivoFileUri.tryEncodeLegacyAbsolutePath(
          '/Users/alice/Library/Containers/com.other.kelivo.notes/Data/Documents/images/x.png',
          allowGenericFallback: false,
        ),
        isNull,
      );
      expect(
        KelivoFileUri.tryEncodeLegacyAbsolutePath(
          '/Users/alice/Library/Application Support/com.other.kelivo.notes/images/x.png',
          allowGenericFallback: false,
        ),
        isNull,
      );
      expect(
        KelivoFileUri.tryEncodeLegacyAbsolutePath(
          '/data/user/0/com.other.kelivo.notes/app_flutter/images/x.png',
          allowGenericFallback: false,
        ),
        isNull,
      );
      expect(
        KelivoFileUri.tryEncodeLegacyAbsolutePath(
          'C:/Users/me/AppData/Local/KelivoNotes/images/x.png',
          allowGenericFallback: false,
        ),
        isNull,
      );
      // Fake / short UUID under real iOS root.
      expect(
        KelivoFileUri.tryEncodeLegacyAbsolutePath(
          '/var/mobile/Containers/Data/Application/ABC/Documents/upload/x.png',
          allowGenericFallback: false,
        ),
        isNull,
      );
      // Nested archives: prefixing a valid sandbox path must not claim it.
      for (final nested in const [
        '/tmp/archive/var/mobile/Containers/Data/Application/A1B2C3D4-E5F6-7890-ABCD-EF1234567890/Documents/images/x.png',
        '/tmp/archive/Users/alice/Library/Developer/CoreSimulator/Devices/A1B2C3D4-E5F6-7890-ABCD-EF1234567890/data/Containers/Data/Application/A1B2C3D4-E5F6-7890-ABCD-EF1234567890/Documents/images/sim.png',
        '/tmp/archive/Users/alice/Library/Application Support/com.psyche.kelivo/images/a.png',
        '/tmp/archive/Users/alice/Library/Containers/com.psyche.kelivo/Data/Documents/upload/x.png',
        '/tmp/archive/C:/Users/me/AppData/Local/Kelivo/images/Pic.PNG',
        '/tmp/archive/data/user/0/com.psyche.kelivo/app_flutter/fonts/a.ttf',
      ]) {
        expect(
          KelivoFileUri.tryEncodeLegacyAbsolutePath(
            nested,
            allowGenericFallback: false,
          ),
          isNull,
          reason: nested,
        );
      }
      expect(
        KelivoFileUri.tryEncodeLegacyAbsolutePath(
          '/tmp/playground/app_flutter/images/x.png',
          allowGenericFallback: false,
        ),
        isNull,
      );
      expect(
        KelivoFileUri.tryEncodeLegacyAbsolutePath(
          '//server/share/images/a.png',
          allowGenericFallback: false,
        ),
        isNull,
      );
    });

    test('encodes iOS Simulator CoreSimulator UUID Documents paths', () {
      expect(
        KelivoFileUri.tryEncodeLegacyAbsolutePath(
          '/Users/alice/Library/Developer/CoreSimulator/Devices/A1B2C3D4-E5F6-7890-ABCD-EF1234567890/data/Containers/Data/Application/A1B2C3D4-E5F6-7890-ABCD-EF1234567890/Documents/images/sim.png',
          allowGenericFallback: false,
        ),
        'kelivo-file:///images/sim.png',
      );
    });

    test('encodes iOS file: URI via portable slash path', () {
      expect(
        KelivoFileUri.tryEncodeLegacyAbsolutePath(
          'file:///var/mobile/Containers/Data/Application/A1B2C3D4-E5F6-7890-ABCD-EF1234567890/Documents/images/pic.png',
          allowGenericFallback: false,
        ),
        'kelivo-file:///images/pic.png',
      );
    });

    test('normalizes Windows managed root Images casing under AppData', () {
      expect(
        KelivoFileUri.tryEncodeLegacyAbsolutePath(
          r'C:\Users\me\AppData\Local\Kelivo\Images\x.png',
          allowGenericFallback: false,
        ),
        'kelivo-file:///images/x.png',
      );
    });

    test('encodes macOS Application Support kelivo bundle paths', () {
      expect(
        KelivoFileUri.tryEncodeLegacyAbsolutePath(
          '/Users/alice/Library/Application Support/com.psyche.kelivo/images/a.png',
          allowGenericFallback: false,
        ),
        'kelivo-file:///images/a.png',
      );
    });

    test('uses generic managed-subdir fallback', () {
      expect(
        KelivoFileUri.tryEncodeLegacyAbsolutePath(
          '/some/random/place/images/nested/file.png',
        ),
        'kelivo-file:///images/nested/file.png',
      );
    });

    test('rejects POSIX backslash filenames instead of splitting path', () {
      expect(
        KelivoFileUri.tryEncodeLegacyAbsolutePath(
          r'/var/mobile/Containers/Data/Application/A1B2C3D4-E5F6-7890-ABCD-EF1234567890/Documents/images/a\b.png',
        ),
        isNull,
      );
      expect(
        KelivoFileUri.tryEncodeLegacyAbsolutePath(
          r'/some/random/place/images/a\b.png',
        ),
        isNull,
      );
    });

    test('returns null when managed root/filename requirements fail', () {
      expect(
        KelivoFileUri.tryEncodeLegacyAbsolutePath(
          '/var/mobile/Documents/cache/x.png',
        ),
        isNull,
      );
      expect(
        KelivoFileUri.tryEncodeLegacyAbsolutePath(
          '/var/mobile/Documents/upload',
        ),
        isNull,
      );
      expect(
        KelivoFileUri.tryEncodeLegacyAbsolutePath(
          '/var/mobile/Documents/upload/',
        ),
        isNull,
      );
      expect(
        KelivoFileUri.tryEncodeLegacyAbsolutePath('/tmp/only-file.png'),
        isNull,
      );
    });
  });

  group('KelivoFileUri.isKelivoFileUri', () {
    test('is a cheap prefix check', () {
      expect(
        KelivoFileUri.isKelivoFileUri('kelivo-file:///upload/a.png'),
        isTrue,
      );
      expect(KelivoFileUri.isKelivoFileUri('kelivo-file:anything'), isTrue);
      expect(KelivoFileUri.isKelivoFileUri('file:///upload/a.png'), isFalse);
      expect(
        KelivoFileUri.isKelivoFileUri('Kelivo-file:///upload/a.png'),
        isFalse,
      );
      expect(KelivoFileUri.isKelivoFileUri(''), isFalse);
    });
  });

  group('KelivoFileUri.encodeFromAbsolute', () {
    test('encodes only paths under root/<managed>/', () {
      expect(
        KelivoFileUri.encodeFromAbsolute(
          '/data/app/upload/a.png',
          root: '/data/app',
        ),
        'kelivo-file:///upload/a.png',
      );
      expect(
        KelivoFileUri.encodeFromAbsolute(
          '/data/app/images/nested/b.png',
          root: '/data/app',
        ),
        'kelivo-file:///images/nested/b.png',
      );
    });

    test('returns null for external or unmanaged paths', () {
      expect(
        KelivoFileUri.encodeFromAbsolute(
          '/other/place/upload/a.png',
          root: '/data/app',
        ),
        isNull,
      );
      expect(
        KelivoFileUri.encodeFromAbsolute(
          '/data/app/cache/a.png',
          root: '/data/app',
        ),
        isNull,
      );
      expect(
        KelivoFileUri.encodeFromAbsolute('/data/app/upload', root: '/data/app'),
        isNull,
      );
    });

    test('encodes Windows-style absolute paths under root', () {
      expect(
        KelivoFileUri.encodeFromAbsolute(
          r'C:\Users\me\AppData\Local\Kelivo\upload\a.png',
          root: r'C:\Users\me\AppData\Local\Kelivo',
        ),
        'kelivo-file:///upload/a.png',
      );
    });

    test('rejects backslash in filename segments', () {
      expect(
        KelivoFileUri.encodeFromAbsolute(
          r'/data/app/upload/a\b.png',
          root: '/data/app',
        ),
        isNull,
      );
      expect(
        KelivoFileUri.decodeToSegments('kelivo-file:///upload/a%5Cb.png'),
        isNull,
      );
    });
    test('percent-encodes special characters in filenames', () {
      expect(
        KelivoFileUri.encodeFromAbsolute(
          '/data/app/upload/report final.pdf',
          root: '/data/app',
        ),
        'kelivo-file:///upload/report%20final.pdf',
      );
      expect(
        KelivoFileUri.encodeFromAbsolute(
          '/data/app/upload/a#b.png',
          root: '/data/app',
        ),
        'kelivo-file:///upload/a%23b.png',
      );
    });
  });
}
