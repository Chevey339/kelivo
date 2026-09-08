import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'package:Kelivo/core/models/environment_state.dart';
import 'package:Kelivo/core/services/sandbox/mirror_service.dart';
import 'package:Kelivo/core/services/sandbox/mirror_speed_test.dart';
import 'package:Kelivo/core/services/sandbox/rootfs_catalog.dart';
import 'package:Kelivo/core/services/workspace/workspace_runtime.dart';
import 'package:Kelivo/icons/lucide_adapter.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:Kelivo/shared/utils/format_bytes.dart';

bool workspaceEnvIsDesktopTarget() {
  return defaultTargetPlatform == TargetPlatform.macOS ||
      defaultTargetPlatform == TargetPlatform.windows ||
      defaultTargetPlatform == TargetPlatform.linux;
}

bool workspaceEnvIsAlpine({
  required EnvironmentState state,
  RuntimeStatus? status,
}) {
  final engine = status?.engine;
  return engine == 'ish' || state.distro == 'alpine';
}

bool workspaceEnvIsUbuntu({
  required EnvironmentState state,
  RuntimeStatus? status,
}) {
  final engine = status?.engine;
  return (engine == 'proot' && state.distro == null) ||
      state.distro == 'ubuntu';
}

IconData workspaceEnvEngineIcon({
  required EnvironmentState state,
  RuntimeStatus? status,
  bool desktopNative = false,
}) {
  if (desktopNative || workspaceEnvIsDesktopTarget()) {
    return Lucide.SquareTerminal;
  }
  if (status?.engine == 'proot' ||
      workspaceEnvIsUbuntu(state: state, status: status) ||
      workspaceEnvIsAlpine(state: state, status: status)) {
    return Lucide.Package;
  }
  return Lucide.SquareTerminal;
}

/// Turns a stored distro version into the short display form.
///
/// `alpine-3.21.3-r4` → `3.21.3`, `24.04.3` → `24.04.3`, `3.21` → `3.21`.
String formatDistroVersion(String? raw) {
  if (raw == null) return '';
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return '';
  var value = trimmed.replaceFirst(RegExp(r'^[A-Za-z]+-'), '');
  value = value.replaceFirst(RegExp(r'-r\d+$'), '');
  return value;
}

String workspaceEnvDisplayVersion(String? raw, {required String fallback}) {
  final formatted = formatDistroVersion(raw);
  return formatted.isEmpty ? fallback : formatted;
}

String workspaceEnvEngineLabel({
  required AppLocalizations l10n,
  required EnvironmentState state,
  RuntimeStatus? status,
}) {
  if (workspaceEnvIsDesktopTarget()) {
    return l10n.workspaceEnvEngineLocalShell;
  }
  if ((status?.engine == 'proot' ||
          defaultTargetPlatform == TargetPlatform.android) &&
      state.distro != null &&
      state.distro != 'ubuntu') {
    final name = state.distro == 'alpine'
        ? 'Alpine'
        : state.distro == 'debian'
        ? 'Debian'
        : state.distro!;
    return '$name ${formatDistroVersion(state.version)} (PRoot)'.trim();
  }
  if (workspaceEnvIsUbuntu(state: state, status: status)) {
    return l10n.workspaceEnvEngineUbuntu(
      workspaceEnvDisplayVersion(
        state.version,
        fallback: RootfsCatalog.defaultImage.version,
      ),
    );
  }
  if (workspaceEnvIsAlpine(state: state, status: status)) {
    return l10n.workspaceEnvEngineAlpine(
      workspaceEnvDisplayVersion(state.version, fallback: '3.21'),
    );
  }
  final engine = status?.engine;
  if (engine == 'process' || engine == 'none' || engine == null) {
    return l10n.workspaceEnvEngineLocalShell;
  }
  if (state.version != null && state.version!.isNotEmpty) {
    return l10n.workspaceEnvEngineUbuntu(
      workspaceEnvDisplayVersion(state.version, fallback: state.version!),
    );
  }
  return l10n.workspaceEnvEngineLocalShell;
}

/// Diagnostic text for the Info card copy action. Includes the raw version
/// and host path even when those are hidden in the UI.
String workspaceEnvInfoCopyText({
  required AppLocalizations l10n,
  required EnvironmentState state,
  RuntimeStatus? status,
  String? rootfsPath,
  int? diskUsageBytes,
}) {
  final lines = <String>[
    workspaceEnvEngineLabel(l10n: l10n, state: state, status: status),
    if (state.version != null && state.version!.isNotEmpty) state.version!,
    if (state.arch != null && state.arch!.isNotEmpty)
      l10n.workspaceEnvArchVersion(
        state.arch!,
        workspaceEnvDisplayVersion(
          state.version,
          fallback: state.version ?? '',
        ),
      ),
    if (rootfsPath != null && rootfsPath.isNotEmpty)
      '${l10n.workspaceEnvPathLabel}: $rootfsPath',
    if (diskUsageBytes != null)
      '${l10n.workspaceEnvSizeLabel}: ${formatBytes(diskUsageBytes)}',
  ];
  return lines.join('\n');
}

String workspaceEnvPhaseLabel(AppLocalizations l10n, EnvironmentPhase phase) {
  switch (phase) {
    case EnvironmentPhase.notInstalled:
      return l10n.workspaceEnvPhaseNotInstalled;
    case EnvironmentPhase.downloading:
      return l10n.workspaceEnvPhaseDownloading;
    case EnvironmentPhase.verifying:
      return l10n.workspaceEnvPhaseVerifying;
    case EnvironmentPhase.extracting:
      return l10n.workspaceEnvPhaseExtracting;
    case EnvironmentPhase.patching:
      return l10n.workspaceEnvPhasePatching;
    case EnvironmentPhase.ready:
      return l10n.workspaceEnvPhaseReady;
    case EnvironmentPhase.error:
      return l10n.workspaceEnvPhaseError;
    case EnvironmentPhase.needsRestart:
      return l10n.workspaceEnvPhaseNeedsRestart;
  }
}

String workspaceEnvErrorMessage(AppLocalizations l10n, String? code) {
  switch (code) {
    case 'unsupported_abi':
      return l10n.workspaceEnvErrorUnsupportedAbi;
    case 'architecture_mismatch':
      return l10n.workspaceEnvErrorArchitectureMismatch;
    case 'proot_missing':
      return l10n.workspaceEnvErrorProotMissing;
    case 'insufficient_disk':
      return l10n.workspaceEnvErrorInsufficientDisk;
    case 'network':
      return l10n.workspaceEnvErrorNetwork;
    case 'checksum_mismatch':
      return l10n.workspaceEnvErrorChecksumMismatch;
    case 'extract_failed':
      return l10n.workspaceEnvErrorExtractFailed;
    case 'patch_failed':
      return l10n.workspaceEnvErrorPatchFailed;
    case 'cancelled':
      return l10n.workspaceEnvErrorCancelled;
    case 'invalid_rootfs':
      return l10n.workspaceEnvInvalidImage;
    default:
      return l10n.workspaceEnvErrorGeneric;
  }
}

bool workspaceEnvIsInsufficientDisk(String? code) {
  return code == 'insufficient_disk';
}

String workspaceEnvCategoryLabel(
  AppLocalizations l10n,
  MirrorCategory category,
) {
  switch (category) {
    case MirrorCategory.apt:
      return l10n.workspaceEnvCategoryApt;
    case MirrorCategory.apk:
      return l10n.workspaceEnvCategoryApk;
    case MirrorCategory.pip:
      return l10n.workspaceEnvCategoryPip;
    case MirrorCategory.npm:
      return l10n.workspaceEnvCategoryNpm;
  }
}

String workspaceEnvRegionLabel(AppLocalizations l10n, MirrorRegion region) {
  switch (region) {
    case MirrorRegion.global:
      return l10n.workspaceEnvRegionGlobal;
    case MirrorRegion.china:
      return l10n.workspaceEnvRegionChina;
    case MirrorRegion.europe:
      return l10n.workspaceEnvRegionEurope;
    case MirrorRegion.asia:
      return l10n.workspaceEnvRegionAsia;
  }
}

String workspaceEnvMirrorDisplayName(AppLocalizations l10n, MirrorEntry entry) {
  switch (entry.id) {
    case 'alpine.official':
      return l10n.workspaceEnvMirrorNameOfficialCdn;
    case 'pip.official':
      return l10n.workspaceEnvMirrorNameOfficialPypi;
    case 'npm.official':
      return l10n.workspaceEnvMirrorNameOfficialNpm;
    case 'apt.official':
      return l10n.workspaceEnvMirrorNameOfficial;
    case 'alpine.tuna':
    case 'apt.tuna':
    case 'pip.tuna':
      return l10n.workspaceEnvMirrorNameTuna;
    case 'alpine.aliyun':
    case 'apt.aliyun':
    case 'pip.aliyun':
      return l10n.workspaceEnvMirrorNameAlibaba;
    case 'alpine.ustc':
    case 'apt.ustc':
    case 'pip.ustc':
      return l10n.workspaceEnvMirrorNameUstc;
    case 'alpine.huawei':
    case 'apt.huawei':
    case 'pip.huawei':
    case 'npm.huawei':
      return l10n.workspaceEnvMirrorNameHuawei;
    case 'alpine.tencent':
    case 'apt.tencent':
    case 'pip.tencent':
    case 'npm.tencent':
      return l10n.workspaceEnvMirrorNameTencent;
    case 'apt.netease':
      return l10n.workspaceEnvMirrorNameNetease;
    case 'alpine.leaseweb':
      return l10n.workspaceEnvMirrorNameLeaseweb;
    case 'alpine.rwth':
      return l10n.workspaceEnvMirrorNameRwth;
    case 'alpine.jaist':
      return l10n.workspaceEnvMirrorNameJaist;
    case 'alpine.kakao':
      return l10n.workspaceEnvMirrorNameKakao;
    case 'npm.npmmirror':
      return l10n.workspaceEnvMirrorNameNpmmirror;
    default:
      return entry.name;
  }
}

String workspaceEnvSelectionLabel(
  AppLocalizations l10n,
  MirrorSelection? selection, {
  MirrorCategory? category,
}) {
  if (selection == null ||
      !selection.useMirror ||
      selection.selectedBaseUrl == null ||
      selection.selectedBaseUrl!.isEmpty) {
    return l10n.workspaceEnvOfficial;
  }
  final entry = category == null
      ? null
      : MirrorService.findEntry(
          category,
          id: selection.mirrorId,
          url: selection.selectedBaseUrl,
        );
  final name = entry != null
      ? workspaceEnvMirrorDisplayName(l10n, entry)
      : selection.displayName;
  if (name != null && name.isNotEmpty) {
    final region = workspaceEnvRegionLabel(
      l10n,
      entry?.region ?? MirrorRegion.global,
    );
    return l10n.workspaceEnvSelectionNamed(name, region);
  }
  return Uri.tryParse(selection.selectedBaseUrl!)?.host ??
      selection.selectedBaseUrl!;
}

String workspaceEnvRelativeTime(AppLocalizations l10n, DateTime at) {
  final delta = DateTime.now().difference(at.toLocal());
  if (delta.inSeconds < 60) return l10n.workspaceEnvRelativeJustNow;
  if (delta.inMinutes < 60) {
    return l10n.workspaceEnvRelativeMinutesAgo(delta.inMinutes);
  }
  if (delta.inHours < 24) {
    return l10n.workspaceEnvRelativeHoursAgo(delta.inHours);
  }
  return l10n.workspaceEnvRelativeDaysAgo(delta.inDays);
}

String workspaceEnvMiddleTruncate(String text, {int maxChars = 28}) {
  if (text.length <= maxChars) return text;
  final keep = maxChars - 1;
  final head = (keep / 2).ceil();
  final tail = keep - head;
  return '${text.substring(0, head)}…${text.substring(text.length - tail)}';
}

int? workspaceEnvInstallPercent(EnvironmentState state) {
  final total = state.bytesTotal;
  final downloaded = state.bytesDownloaded;
  if (downloaded != null && total != null && total > 0) {
    return ((downloaded / total) * 100).round();
  }
  final progress = state.progress;
  if (progress != null) {
    return (progress * 100).round().clamp(0, 100);
  }
  return null;
}

double? workspaceEnvProgressFraction(EnvironmentState state) {
  final total = state.bytesTotal;
  final downloaded = state.bytesDownloaded;
  if (downloaded != null && total != null && total > 0) {
    return (downloaded / total).clamp(0.0, 1.0);
  }
  final progress = state.progress;
  if (progress != null) {
    return progress.clamp(0.0, 1.0);
  }
  return null;
}

String workspaceEnvMb(int bytes) {
  return (bytes / (1024 * 1024)).toStringAsFixed(1);
}

String workspaceEnvNativeShellPath() {
  if (defaultTargetPlatform == TargetPlatform.windows) {
    final shell = Platform.environment['SHELL'];
    if (shell != null && shell.isNotEmpty) return shell;
    final comspec = Platform.environment['COMSPEC'];
    if (comspec != null && comspec.isNotEmpty) return comspec;
    return 'PowerShell';
  }
  final shell = Platform.environment['SHELL'];
  if (shell != null && shell.isNotEmpty) return shell;
  return '/bin/sh';
}

List<MirrorProbe> workspaceEnvSortedProbes(List<MirrorProbe> probes) {
  final copy = List<MirrorProbe>.from(probes);
  copy.sort((a, b) {
    if (a.ok && b.ok) {
      return a.latency!.compareTo(b.latency!);
    }
    if (a.ok) return -1;
    if (b.ok) return 1;
    return 0;
  });
  return copy;
}

String workspaceEnvGuestPath(String hostPath, String rootPath) {
  final normalizedHost = hostPath.replaceAll('\\', '/');
  final normalizedRoot = rootPath
      .replaceAll('\\', '/')
      .replaceAll(RegExp(r'/+$'), '');
  if (normalizedHost == normalizedRoot) return '/';
  final prefix = '$normalizedRoot/';
  if (normalizedHost.startsWith(prefix)) {
    return '/${normalizedHost.substring(prefix.length)}';
  }
  return normalizedHost;
}
