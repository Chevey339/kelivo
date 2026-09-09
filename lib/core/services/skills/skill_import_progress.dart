enum SkillImportPhase { resolving, downloading, extracting, installing }

class SkillImportProgress {
  const SkillImportProgress(
    this.phase, {
    this.receivedBytes = 0,
    this.totalBytes,
  });

  final SkillImportPhase phase;
  final int receivedBytes;
  final int? totalBytes;

  double? get fraction {
    final total = totalBytes;
    if (phase != SkillImportPhase.downloading || total == null || total <= 0) {
      return null;
    }
    return (receivedBytes / total).clamp(0.0, 1.0);
  }
}
