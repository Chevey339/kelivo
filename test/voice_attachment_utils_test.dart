import 'package:flutter_test/flutter_test.dart';
import 'package:Kelivo/utils/voice_attachment_utils.dart';

void main() {
  group('voice attachment utils', () {
    test('builds and parses voice recording file names', () {
      final startedAt = DateTime.fromMillisecondsSinceEpoch(1700000000000);
      final fileName = buildVoiceRecordingFileName(
        startedAt,
        const Duration(seconds: 37),
      );

      expect(isVoiceRecordingFileName(fileName), isTrue);
      expect(
        tryParseVoiceRecordingDuration(fileName),
        const Duration(seconds: 37),
      );
    });

    test('formats durations as mm:ss', () {
      expect(formatVoiceRecordingDuration(const Duration(seconds: 5)), '00:05');
      expect(
        formatVoiceRecordingDuration(const Duration(minutes: 1, seconds: 3)),
        '01:03',
      );
    });
  });
}
