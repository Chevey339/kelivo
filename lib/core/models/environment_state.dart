enum EnvironmentPhase {
  notInstalled,
  downloading,
  verifying,
  extracting,
  patching,
  ready,
  error,
  needsRestart,
}

class EnvironmentState {
  final EnvironmentPhase phase;
  final String? distro;
  final String? version;
  final String? arch;
  final DateTime? installedAt;
  final String? errorMessage;
  final double? progress;
  final String? availableVersion;
  final int? bytesDownloaded;
  final int? bytesTotal;
  final String? lastMirrorBase;
  final String? rootfsDir;

  const EnvironmentState({
    this.phase = EnvironmentPhase.notInstalled,
    this.distro,
    this.version,
    this.arch,
    this.installedAt,
    this.errorMessage,
    this.progress,
    this.availableVersion,
    this.bytesDownloaded,
    this.bytesTotal,
    this.lastMirrorBase,
    this.rootfsDir,
  });

  EnvironmentState copyWith({
    EnvironmentPhase? phase,
    String? distro,
    String? version,
    String? arch,
    DateTime? installedAt,
    String? errorMessage,
    double? progress,
    String? availableVersion,
    int? bytesDownloaded,
    int? bytesTotal,
    String? lastMirrorBase,
    String? rootfsDir,
    bool clearDistro = false,
    bool clearVersion = false,
    bool clearArch = false,
    bool clearInstalledAt = false,
    bool clearErrorMessage = false,
    bool clearProgress = false,
    bool clearAvailableVersion = false,
    bool clearBytesDownloaded = false,
    bool clearBytesTotal = false,
    bool clearLastMirrorBase = false,
    bool clearRootfsDir = false,
  }) {
    return EnvironmentState(
      phase: phase ?? this.phase,
      distro: clearDistro ? null : (distro ?? this.distro),
      version: clearVersion ? null : (version ?? this.version),
      arch: clearArch ? null : (arch ?? this.arch),
      installedAt: clearInstalledAt ? null : (installedAt ?? this.installedAt),
      errorMessage: clearErrorMessage
          ? null
          : (errorMessage ?? this.errorMessage),
      progress: clearProgress ? null : (progress ?? this.progress),
      availableVersion: clearAvailableVersion
          ? null
          : (availableVersion ?? this.availableVersion),
      bytesDownloaded: clearBytesDownloaded
          ? null
          : (bytesDownloaded ?? this.bytesDownloaded),
      bytesTotal: clearBytesTotal ? null : (bytesTotal ?? this.bytesTotal),
      lastMirrorBase: clearLastMirrorBase
          ? null
          : (lastMirrorBase ?? this.lastMirrorBase),
      rootfsDir: clearRootfsDir ? null : (rootfsDir ?? this.rootfsDir),
    );
  }

  Map<String, dynamic> toJson() => {
    'phase': phase.name,
    'distro': distro,
    'version': version,
    'arch': arch,
    'installedAt': installedAt?.toIso8601String(),
    'errorMessage': errorMessage,
    'progress': progress,
    'availableVersion': availableVersion,
    'bytesDownloaded': bytesDownloaded,
    'bytesTotal': bytesTotal,
    'lastMirrorBase': lastMirrorBase,
    'rootfsDir': rootfsDir,
  };

  factory EnvironmentState.fromJson(Map<String, dynamic> json) {
    return EnvironmentState(
      phase: environmentPhaseFromString(json['phase'] as String?),
      distro: json['distro'] as String?,
      version: json['version'] as String?,
      arch: json['arch'] as String?,
      installedAt: json['installedAt'] == null
          ? null
          : DateTime.parse(json['installedAt'] as String),
      errorMessage: json['errorMessage'] as String?,
      progress: (json['progress'] as num?)?.toDouble(),
      availableVersion: json['availableVersion'] as String?,
      bytesDownloaded: (json['bytesDownloaded'] as num?)?.toInt(),
      bytesTotal: (json['bytesTotal'] as num?)?.toInt(),
      lastMirrorBase: json['lastMirrorBase'] as String?,
      rootfsDir: json['rootfsDir'] as String?,
    );
  }

  static EnvironmentPhase environmentPhaseFromString(String? value) {
    switch (value) {
      case 'downloading':
        return EnvironmentPhase.downloading;
      case 'verifying':
        return EnvironmentPhase.verifying;
      case 'extracting':
        return EnvironmentPhase.extracting;
      case 'patching':
        return EnvironmentPhase.patching;
      case 'ready':
        return EnvironmentPhase.ready;
      case 'error':
        return EnvironmentPhase.error;
      case 'needsRestart':
        return EnvironmentPhase.needsRestart;
      case 'notInstalled':
      default:
        return EnvironmentPhase.notInstalled;
    }
  }
}

enum MirrorCategory { apt, apk, pip, npm }

class MirrorSelection {
  final String? selectedBaseUrl;
  final bool useMirror;
  final String? mirrorId;
  final String? displayName;
  final bool manual;

  const MirrorSelection({
    this.selectedBaseUrl,
    this.useMirror = false,
    this.mirrorId,
    this.displayName,
    this.manual = false,
  });

  bool get hasManualPick => manual;

  MirrorSelection copyWith({
    String? selectedBaseUrl,
    bool? useMirror,
    String? mirrorId,
    String? displayName,
    bool? manual,
    bool clearSelectedBaseUrl = false,
    bool clearMirrorId = false,
    bool clearDisplayName = false,
  }) {
    return MirrorSelection(
      selectedBaseUrl: clearSelectedBaseUrl
          ? null
          : (selectedBaseUrl ?? this.selectedBaseUrl),
      useMirror: useMirror ?? this.useMirror,
      mirrorId: clearMirrorId ? null : (mirrorId ?? this.mirrorId),
      displayName: clearDisplayName ? null : (displayName ?? this.displayName),
      manual: manual ?? this.manual,
    );
  }

  Map<String, dynamic> toJson() => {
    'selectedBaseUrl': selectedBaseUrl,
    'useMirror': useMirror,
    'mirrorId': mirrorId,
    'displayName': displayName,
    'manual': manual,
  };

  factory MirrorSelection.fromJson(Map<String, dynamic> json) {
    return MirrorSelection(
      selectedBaseUrl: json['selectedBaseUrl'] as String?,
      useMirror: json['useMirror'] as bool? ?? false,
      mirrorId: json['mirrorId'] as String?,
      displayName: json['displayName'] as String?,
      manual: json['manual'] as bool? ?? false,
    );
  }

  static MirrorCategory categoryFromString(String? value) {
    switch (value) {
      case 'apk':
        return MirrorCategory.apk;
      case 'pip':
        return MirrorCategory.pip;
      case 'npm':
        return MirrorCategory.npm;
      case 'apt':
      default:
        return MirrorCategory.apt;
    }
  }
}
