import '../../../core/models/assistant.dart';

/// Applies Health Data mutations to the latest [Assistant], one write at a time.
///
/// Callers must not close over a build-time assistant. Each [apply] re-reads
/// via [readAssistant] after prior writes finish, so overlapping taps cannot
/// restore a stale `localToolIds` / type list.
class HealthDataSettingsWriter {
  HealthDataSettingsWriter({
    required this.readAssistant,
    required this.updateAssistant,
  });

  final Assistant? Function() readAssistant;
  final Future<void> Function(Assistant next) updateAssistant;

  Future<void> _writeInFlight = Future<void>.value();

  /// Reads the current assistant, runs [mutate], then persists.
  ///
  /// [mutate] may return `null` to skip the write (permission denied, no-op).
  Future<void> apply(Future<Assistant?> Function(Assistant current) mutate) {
    final op = _writeInFlight.then((_) async {
      final current = readAssistant();
      if (current == null) return;
      final next = await mutate(current);
      if (next == null) return;
      await updateAssistant(next);
    });
    _writeInFlight = op.catchError((_) {});
    return op;
  }
}
