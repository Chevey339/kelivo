enum TerminalRuntimeStatus {
  notInstalled,
  installing,
  installed,
  updateAvailable,
  repairRequired,
  failed,
}

enum TerminalRuntimeIntegrationStatus {
  missingSource,
  missingBuildTools,
  notLinked,
  linked,
}

class TerminalRuntimeState {
  const TerminalRuntimeState({
    required this.status,
    this.integrationStatus = TerminalRuntimeIntegrationStatus.notLinked,
    this.runtimeId,
    this.version,
    this.integrationReference,
    this.packageSource,
    this.rootfsBytes = 0,
    this.homeBytes = 0,
    this.cacheBytes = 0,
    this.backupBytes = 0,
    this.lastInstallOrUpdateTime,
    this.lastError,
  });

  final TerminalRuntimeStatus status;
  final TerminalRuntimeIntegrationStatus integrationStatus;
  final String? runtimeId;
  final String? version;
  final String? integrationReference;
  final String? packageSource;
  final int rootfsBytes;
  final int homeBytes;
  final int cacheBytes;
  final int backupBytes;
  final DateTime? lastInstallOrUpdateTime;
  final String? lastError;

  int get totalBytes => rootfsBytes + homeBytes + cacheBytes + backupBytes;

  bool get canOpenSession =>
      status == TerminalRuntimeStatus.installed ||
      status == TerminalRuntimeStatus.updateAvailable;

  bool get canInstall =>
      status == TerminalRuntimeStatus.notInstalled ||
      status == TerminalRuntimeStatus.failed ||
      status == TerminalRuntimeStatus.repairRequired;

  factory TerminalRuntimeState.fromMap(Map<Object?, Object?> map) {
    return TerminalRuntimeState(
      status: _parseStatus(map['status']),
      integrationStatus: _parseIntegrationStatus(map['integrationStatus']),
      runtimeId: _stringOrNull(map['runtimeId']),
      version: _stringOrNull(map['version']),
      integrationReference: _stringOrNull(map['integrationReference']),
      packageSource: _stringOrNull(map['packageSource']),
      rootfsBytes: _intOrZero(map['rootfsBytes']),
      homeBytes: _intOrZero(map['homeBytes']),
      cacheBytes: _intOrZero(map['cacheBytes']),
      backupBytes: _intOrZero(map['backupBytes']),
      lastInstallOrUpdateTime: _dateOrNull(map['lastInstallOrUpdateTime']),
      lastError: _stringOrNull(map['lastError']),
    );
  }

  static TerminalRuntimeStatus _parseStatus(Object? value) {
    final raw = _stringOrNull(value);
    switch (raw) {
      case 'notInstalled':
        return TerminalRuntimeStatus.notInstalled;
      case 'installing':
        return TerminalRuntimeStatus.installing;
      case 'installed':
        return TerminalRuntimeStatus.installed;
      case 'updateAvailable':
        return TerminalRuntimeStatus.updateAvailable;
      case 'repairRequired':
        return TerminalRuntimeStatus.repairRequired;
      case 'failed':
        return TerminalRuntimeStatus.failed;
    }
    throw FormatException('Unknown terminal runtime status: $raw');
  }

  static TerminalRuntimeIntegrationStatus _parseIntegrationStatus(
    Object? value,
  ) {
    final raw = _stringOrNull(value);
    switch (raw) {
      case null:
      case 'notLinked':
        return TerminalRuntimeIntegrationStatus.notLinked;
      case 'missingSource':
        return TerminalRuntimeIntegrationStatus.missingSource;
      case 'missingBuildTools':
        return TerminalRuntimeIntegrationStatus.missingBuildTools;
      case 'linked':
        return TerminalRuntimeIntegrationStatus.linked;
    }
    throw FormatException('Unknown terminal integration status: $raw');
  }

  static String? _stringOrNull(Object? value) {
    if (value == null) return null;
    final text = value.toString();
    return text.isEmpty ? null : text;
  }

  static int _intOrZero(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  static DateTime? _dateOrNull(Object? value) {
    final text = _stringOrNull(value);
    if (text == null) return null;
    return DateTime.tryParse(text);
  }
}
