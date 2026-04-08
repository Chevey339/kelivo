import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';

import '../../../core/models/chat_input_data.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/snackbar.dart';
import '../../../utils/app_directories.dart';
import '../../../utils/platform_utils.dart';
import '../../../utils/voice_attachment_utils.dart';

const List<String> linuxVoiceInputDependencyCommands = <String>[
  'parecord',
  'ffmpeg',
];

List<String> missingLinuxVoiceInputDependencies(
  Map<String, bool> commandAvailability,
) {
  return <String>[
    for (final command in linuxVoiceInputDependencyCommands)
      if (!(commandAvailability[command] ?? false)) command,
  ];
}

class VoiceInputService {
  VoiceInputService({
    required BuildContext Function() getContext,
    Future<bool> Function(String command)? isCommandAvailable,
  }) : _getContext = getContext,
       _isCommandAvailable =
           isCommandAvailable ?? VoiceInputService._defaultIsCommandAvailable;

  static const Duration maxRecordingDuration = Duration(minutes: 1);
  static const int recordingSampleRate = 16000;

  final BuildContext Function() _getContext;
  final Future<bool> Function(String command) _isCommandAvailable;
  final AudioRecorder _recorder = AudioRecorder();

  String? _currentRecordingPath;
  DateTime? _recordingStartedAt;

  Future<bool> startRecording() async {
    if (!(PlatformUtils.isMobileTarget ||
        PlatformUtils.isMacOS ||
        PlatformUtils.isWindows ||
        PlatformUtils.isLinux)) {
      return false;
    }
    if (_contextIfMounted() == null) return false;

    try {
      final hasPermission = await _requestMicrophonePermission();
      if (!hasPermission) {
        _showPermissionDenied();
        return false;
      }

      final missingLinuxDependencies =
          await _missingLinuxVoiceInputDependencies();
      if (missingLinuxDependencies.isNotEmpty) {
        _showLinuxDependencyMissing(missingLinuxDependencies);
        return false;
      }

      final dir = await AppDirectories.getUploadDirectory();
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }

      final fileName =
          'voice_${DateTime.now().microsecondsSinceEpoch.toString()}.wav';
      final path = p.join(dir.path, fileName);
      _currentRecordingPath = path;
      _recordingStartedAt = DateTime.now();

      await _recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.wav,
          sampleRate: recordingSampleRate,
          numChannels: 1,
        ),
        path: path,
      );
      return true;
    } catch (_) {
      _currentRecordingPath = null;
      _recordingStartedAt = null;
      final missingLinuxDependencies =
          await _missingLinuxVoiceInputDependencies();
      if (missingLinuxDependencies.isNotEmpty) {
        _showLinuxDependencyMissing(missingLinuxDependencies);
        return false;
      }
      _showStartFailed();
      return false;
    }
  }

  Future<bool> _requestMicrophonePermission() async {
    if (PlatformUtils.isMacOS) {
      // macOS uses the record plugin for permission checks; permission_handler
      // is not registered on macOS in this app.
      return _recorder.hasPermission(request: true);
    }

    if (PlatformUtils.isLinux) {
      return true;
    }

    var status = await Permission.microphone.status;
    if (status.isDenied || status.isRestricted) {
      status = await Permission.microphone.request();
    }
    return status.isGranted;
  }

  Future<List<String>> _missingLinuxVoiceInputDependencies() async {
    if (!PlatformUtils.isLinux) return const <String>[];

    final availability = <String, bool>{};
    for (final command in linuxVoiceInputDependencyCommands) {
      availability[command] = await _isCommandAvailable(command);
    }
    return missingLinuxVoiceInputDependencies(availability);
  }

  Future<DocumentAttachment?> stopRecording() async {
    if (_contextIfMounted() == null) return null;

    try {
      final path = await _recorder.stop();
      final resolvedPath = path?.trim() ?? _currentRecordingPath ?? '';
      final recordingStartedAt = _recordingStartedAt;
      _currentRecordingPath = null;
      _recordingStartedAt = null;
      if (resolvedPath.isEmpty) return null;

      final file = File(resolvedPath);
      if (!await file.exists()) {
        _showStopFailed();
        return null;
      }
      final stat = await file.stat();
      if (stat.size <= 0) {
        try {
          await file.delete();
        } catch (_) {}
        _showStopFailed();
        return null;
      }

      final duration = recordingStartedAt == null
          ? Duration.zero
          : DateTime.now().difference(recordingStartedAt);
      final renamedFileName = buildVoiceRecordingFileName(
        recordingStartedAt ?? DateTime.now(),
        duration > maxRecordingDuration ? maxRecordingDuration : duration,
      );
      final renamedPath = p.join(file.parent.path, renamedFileName);
      final finalFile = p.basename(resolvedPath) == renamedFileName
          ? file
          : await file.rename(renamedPath);

      return DocumentAttachment(
        path: finalFile.path,
        fileName: p.basename(finalFile.path),
        mime: 'audio/wav',
      );
    } catch (_) {
      _currentRecordingPath = null;
      _recordingStartedAt = null;
      _showStopFailed();
      return null;
    }
  }

  Future<void> cancelRecording() async {
    final path = _currentRecordingPath;
    _currentRecordingPath = null;
    _recordingStartedAt = null;
    try {
      await _recorder.stop();
    } catch (_) {}

    if (path == null || path.isEmpty) return;
    try {
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {}
  }

  Future<void> dispose() async {
    try {
      await _recorder.dispose();
    } catch (_) {}
  }

  void _showPermissionDenied() {
    final context = _contextIfMounted();
    if (context == null) return;
    final l10n = AppLocalizations.of(context)!;
    showAppSnackBar(
      context,
      message: l10n.voiceInputPermissionDeniedMessage,
      type: NotificationType.error,
      duration: const Duration(seconds: 4),
      actionLabel: l10n.openSystemSettings,
      onAction: () {
        unawaited(_openSystemSettings());
      },
    );
  }

  Future<void> _openSystemSettings() async {
    try {
      if (PlatformUtils.isMacOS) {
        await Process.run('open', const [
          'x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone',
        ]);
        return;
      }
      await openAppSettings();
    } catch (_) {}
  }

  void _showStartFailed() {
    final context = _contextIfMounted();
    if (context == null) return;
    _showError(
      context,
      AppLocalizations.of(context)!.voiceRecordingStartFailed,
    );
  }

  void _showLinuxDependencyMissing(List<String> missingDependencies) {
    final context = _contextIfMounted();
    if (context == null) return;
    _showError(
      context,
      AppLocalizations.of(
        context,
      )!.voiceRecordingLinuxDependencyMissing(missingDependencies.join(', ')),
    );
  }

  void _showStopFailed() {
    final context = _contextIfMounted();
    if (context == null) return;
    _showError(context, AppLocalizations.of(context)!.voiceRecordingStopFailed);
  }

  void _showError(BuildContext context, String message) {
    showAppSnackBar(
      context,
      message: message,
      type: NotificationType.error,
      duration: const Duration(seconds: 3),
    );
  }

  BuildContext? _contextIfMounted() {
    final context = _getContext();
    if (!context.mounted) return null;
    return context;
  }

  static Future<bool> _defaultIsCommandAvailable(String command) async {
    try {
      final result = await Process.run('which', <String>[command]);
      return result.exitCode == 0;
    } catch (_) {
      return false;
    }
  }
}
