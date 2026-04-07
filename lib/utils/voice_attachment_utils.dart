import 'package:path/path.dart' as p;

import '../core/models/chat_input_data.dart';
import '../l10n/app_localizations.dart';

final RegExp _voiceAttachmentNameRe = RegExp(r'^voice_(\d+)_(\d+)ms\.wav$');

bool isVoiceRecordingAttachment(DocumentAttachment attachment) {
  return isVoiceRecordingFileName(attachment.fileName);
}

bool isVoiceRecordingFileName(String fileName) {
  return _voiceAttachmentNameRe.hasMatch(p.basename(fileName));
}

String buildVoiceRecordingFileName(DateTime startedAt, Duration duration) {
  final ms = duration.inMilliseconds.clamp(0, 24 * 60 * 60 * 1000);
  return 'voice_${startedAt.microsecondsSinceEpoch}_${ms}ms.wav';
}

Duration? tryParseVoiceRecordingDuration(String fileName) {
  final match = _voiceAttachmentNameRe.firstMatch(p.basename(fileName));
  if (match == null) return null;
  final ms = int.tryParse(match.group(2) ?? '');
  if (ms == null || ms < 0) return null;
  return Duration(milliseconds: ms);
}

String formatVoiceRecordingDuration(Duration duration) {
  final totalSeconds = duration.inSeconds;
  final minutes = totalSeconds ~/ 60;
  final seconds = totalSeconds % 60;
  return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
}

String voiceRecordingDisplayLabelForDuration(
  AppLocalizations l10n,
  Duration duration,
) {
  return l10n.voiceRecordingDisplayLabel(
    formatVoiceRecordingDuration(duration),
  );
}

String voiceRecordingDisplayLabel(AppLocalizations l10n, String fileName) {
  final duration = tryParseVoiceRecordingDuration(fileName) ?? Duration.zero;
  return voiceRecordingDisplayLabelForDuration(l10n, duration);
}
