import 'dart:typed_data';

import 'package:Kelivo/core/services/proactive_care_alarm_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

void main() {
  group('ProactiveCareAlarmService.alarmIdFor', () {
    test('returns the same id for the same assistant id (stable)', () {
      const assistantId = 'a3a4cdcf-9b63-44b1-8d4e-2b1f7e2f9c01';
      final first = ProactiveCareAlarmService.alarmIdFor(assistantId);
      final second = ProactiveCareAlarmService.alarmIdFor(assistantId);
      expect(first, second);
    });

    test('matches known FNV-1a derived values (cross-run stability)', () {
      // 31-bit FNV-1a values precomputed for these inputs; failing here means
      // the hash changed and pending alarms could no longer be cancelled.
      // FNV-1a 32-bit: '' -> 0x811C9DC5, 'a' -> 0xE40C292C; masked to 31 bits.
      expect(ProactiveCareAlarmService.alarmIdFor(''), 0x011C9DC5);
      expect(ProactiveCareAlarmService.alarmIdFor('a'), 0x640C292C);
    });

    test('always returns a 31-bit positive int', () {
      final inputs = <String>[
        '',
        'a',
        'assistant-1',
        '00000000-0000-0000-0000-000000000000',
        // Long id boundary
        'x' * 1024,
        // Non-ASCII id
        '助手-默认-中文标识',
      ];
      for (final input in inputs) {
        final id = ProactiveCareAlarmService.alarmIdFor(input);
        expect(id, greaterThanOrEqualTo(0), reason: 'input: $input');
        expect(id, lessThan(1 << 31), reason: 'input: $input');
        expect(id.bitLength, lessThan(32), reason: 'input: $input');
      }
    });

    test('distinct assistant ids map to distinct alarm ids (typical set)', () {
      const inputs = <String>[
        'a3a4cdcf-9b63-44b1-8d4e-2b1f7e2f9c01',
        'a3a4cdcf-9b63-44b1-8d4e-2b1f7e2f9c02',
        'b7e2f9c0-1a3a-4cdc-9b63-44b18d4e2b1f',
        'assistant-default',
      ];
      final ids = inputs.map(ProactiveCareAlarmService.alarmIdFor).toSet();
      expect(ids.length, inputs.length);
    });
  });

  group('cropAvatarForNotification', () {
    Uint8List pngOf(int width, int height) {
      final image = img.Image(width: width, height: height);
      img.fill(image, color: img.ColorRgb8(200, 80, 40));
      return img.encodePng(image);
    }

    test('center-crops a landscape image to a square PNG', () {
      final out = cropAvatarForNotification(pngOf(400, 200));
      expect(out, isNotNull);
      final decoded = img.decodePng(out!);
      expect(decoded, isNotNull);
      expect(decoded!.width, decoded.height);
      expect(decoded.width, 200);
    });

    test('center-crops a portrait image to a square PNG', () {
      final out = cropAvatarForNotification(pngOf(120, 300));
      final decoded = img.decodePng(out!);
      expect(decoded!.width, decoded.height);
      expect(decoded.width, 120);
    });

    test('downscales large images to maxSize without stretching', () {
      final out = cropAvatarForNotification(pngOf(1024, 768), maxSize: 256);
      final decoded = img.decodePng(out!);
      expect(decoded!.width, 256);
      expect(decoded.height, 256);
    });

    test('applies a circular mask (transparent corners, opaque center)', () {
      final out = cropAvatarForNotification(pngOf(100, 100));
      final decoded = img.decodePng(out!)!;
      expect(decoded.getPixel(0, 0).a, 0);
      expect(decoded.getPixel(decoded.width ~/ 2, decoded.height ~/ 2).a, 255);
    });

    test('returns null for undecodable bytes', () {
      final out = cropAvatarForNotification(
        Uint8List.fromList(<int>[1, 2, 3, 4, 5]),
      );
      expect(out, isNull);
    });
  });
}
