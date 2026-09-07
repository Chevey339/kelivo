import 'dart:io';

import 'package:path/path.dart' as p;

import 'workspace_runtime.dart';

/// Thrown when a model path contains NUL or `..` escapes a zone.
class PathResolutionException implements Exception {
  const PathResolutionException(this.message);

  final String message;

  @override
  String toString() => 'PathResolutionException: $message';
}

class ResolvedPath {
  const ResolvedPath({
    required this.hostPath,
    required this.modelPath,
    required this.zone,
  });

  final String hostPath;

  /// Normalized path in the runtime's model vocabulary.
  final String modelPath;
  final WorkspaceZone zone;
}

/// Maps model-visible paths to host directories in sandboxed or native mode.
class WorkspacePaths {
  WorkspacePaths.sandboxed({
    required String workspaceHostRoot,
    required String sessionHostDir,
    required String skillsHostDir,
    List<Mount> externalMounts = const [],
    this.loadExternalMounts,
  }) : _externalMounts = List.unmodifiable(externalMounts),
       sandboxed = true,
       workspaceHostRoot = _canonHost(workspaceHostRoot),
       sessionHostDir = _canonHost(sessionHostDir),
       skillsHostDir = _canonHost(skillsHostDir),
       tmpHostRoot = _canonHost(Directory.systemTemp.path);

  WorkspacePaths.native({
    required String workspaceHostRoot,
    required String sessionHostDir,
    required String skillsHostDir,
  }) : _externalMounts = const [],
       loadExternalMounts = null,
       sandboxed = false,
       workspaceHostRoot = _canonHost(workspaceHostRoot),
       sessionHostDir = _canonHost(sessionHostDir),
       skillsHostDir = _canonHost(skillsHostDir),
       tmpHostRoot = _canonHost(Directory.systemTemp.path);

  final bool sandboxed;
  final String workspaceHostRoot;
  final String sessionHostDir;
  final String skillsHostDir;
  final String tmpHostRoot;
  List<Mount> _externalMounts;
  final Future<List<Mount>> Function()? loadExternalMounts;
  List<Mount> get externalMounts => List.unmodifiable(_externalMounts);

  Future<void> refreshExternalMounts() async {
    if (loadExternalMounts != null) {
      _externalMounts = await loadExternalMounts!();
    }
  }

  bool isReadOnlyPath(String hostPath) => _externalMounts.any(
    (mount) => mount.readOnly && _hostInside(mount.host, hostPath),
  );

  static const String guestWorkspace = '/workspace';
  static const String guestChat = '/chat';
  static const String guestSkills = '/skills';
  static const String guestTmp = '/tmp';

  String get modelRoot => sandboxed ? guestWorkspace : workspaceHostRoot;

  String get modelSessionDir => sandboxed ? guestChat : sessionHostDir;

  String get modelSkillsDir => sandboxed ? guestSkills : skillsHostDir;

  List<Mount> get mounts {
    if (!sandboxed) return const <Mount>[];
    return [
      Mount(host: workspaceHostRoot, guest: guestWorkspace),
      Mount(host: sessionHostDir, guest: guestChat),
      Mount(host: skillsHostDir, guest: guestSkills),
      ..._externalMounts,
    ];
  }

  static bool isWritableZone(WorkspaceZone zone) {
    switch (zone) {
      case WorkspaceZone.workspace:
      case WorkspaceZone.chat:
      case WorkspaceZone.tmp:
      case WorkspaceZone.external:
        return true;
      case WorkspaceZone.skills:
      case WorkspaceZone.outside:
        return false;
    }
  }

  /// Default [modelRoot]. Result always stays inside a zone (falls back).
  String normalizeCwd(String? cwd) {
    return _normalizeCwd(cwd);
  }

  ResolvedPath resolve(String modelPath, {required String cwd}) {
    return _resolveWithBase(modelPath, _normalizeCwd(cwd));
  }

  /// Like [resolve], then follows symlinks and re-classifies the real path.
  Future<ResolvedPath> resolveReal(
    String modelPath, {
    required String cwd,
  }) async {
    final lexical = resolve(modelPath, cwd: cwd);
    final realHost = await resolveHostPath(lexical.hostPath);
    final zone = _classifyHost(realHost);
    if (sandboxed) {
      return ResolvedPath(
        hostPath: realHost,
        modelPath: toModelPath(realHost),
        zone: zone,
      );
    }
    return ResolvedPath(hostPath: realHost, modelPath: realHost, zone: zone);
  }

  /// Inverse of [resolve] for a host path that sits under a known root.
  String toModelPath(String hostPath) {
    if (!sandboxed) return _canonHost(hostPath);
    for (final mount in _externalMounts) {
      final rel = _relativeToRoot(mount.host, hostPath);
      if (rel != null) return _guestJoin(mount.guest, rel);
    }
    final workspaceRel = _relativeToRoot(workspaceHostRoot, hostPath);
    if (workspaceRel != null) {
      return _guestJoin(guestWorkspace, workspaceRel);
    }
    final chatRel = _relativeToRoot(sessionHostDir, hostPath);
    if (chatRel != null) {
      return _guestJoin(guestChat, chatRel);
    }
    final skillsRel = _relativeToRoot(skillsHostDir, hostPath);
    if (skillsRel != null) {
      return _guestJoin(guestSkills, skillsRel);
    }
    final tmpRel = _relativeToRoot(tmpHostRoot, hostPath);
    if (tmpRel != null) {
      return _guestJoin(guestTmp, tmpRel);
    }
    return _canonHost(hostPath);
  }

  String _normalizeCwd(String? cwd) {
    if (cwd == null || cwd.isEmpty) return modelRoot;
    try {
      final resolved = _resolveWithBase(cwd, modelRoot);
      if (resolved.zone == WorkspaceZone.outside) return modelRoot;
      return resolved.modelPath;
    } on PathResolutionException {
      return modelRoot;
    }
  }

  ResolvedPath _resolveWithBase(String modelPath, String base) {
    _rejectNul(modelPath);
    _rejectNul(base);
    if (sandboxed) {
      return _resolveSandboxed(modelPath, base);
    }
    return _resolveNative(modelPath, base);
  }

  ResolvedPath _resolveSandboxed(String modelPath, String base) {
    final raw = p.posix.isAbsolute(modelPath)
        ? modelPath
        : p.posix.join(base, modelPath);
    final intended = _classifyGuest(_lexicalAnchor(raw, posix: true));
    final normalized = p.posix.normalize(raw);
    final mapped = _mapGuest(normalized);
    // Each mount is its own path boundary, including sibling mounts.
    for (final mount in _externalMounts) {
      if (_guestRelative(_lexicalAnchor(raw, posix: true), mount.guest) !=
              null &&
          _guestRelative(normalized, mount.guest) == null) {
        throw PathResolutionException(
          'path escapes external mount: $modelPath',
        );
      }
    }
    if (mapped == null || !_hostInsideZone(intended, mapped.hostPath)) {
      throw PathResolutionException(
        'path escapes a workspace zone: $modelPath',
      );
    }
    return mapped;
  }

  ResolvedPath _resolveNative(String modelPath, String base) {
    final raw = p.isAbsolute(modelPath) ? modelPath : p.join(base, modelPath);
    final intended = _classifyHost(
      _canonHost(_lexicalAnchor(raw, posix: false)),
    );
    final canonical = _canonHost(raw);
    final zone = _classifyHost(canonical);
    if (intended == WorkspaceZone.outside) {
      if (_usesDotDot(modelPath, raw) || zone != WorkspaceZone.outside) {
        throw PathResolutionException(
          'path escapes a workspace zone: $modelPath',
        );
      }
    } else if (!_hostInsideZone(intended, canonical)) {
      throw PathResolutionException(
        'path escapes a workspace zone: $modelPath',
      );
    }
    return ResolvedPath(hostPath: canonical, modelPath: canonical, zone: zone);
  }

  /// Directory the path starts in: everything before the first `..` segment.
  static String _lexicalAnchor(String path, {required bool posix}) {
    final ctx = posix ? p.posix : p.context;
    final kept = <String>[];
    for (final part in ctx.split(path)) {
      if (part == '..') break;
      kept.add(part);
    }
    if (kept.isEmpty) return posix ? '/' : ctx.current;
    final joined = ctx.joinAll(kept);
    if (posix && joined.isEmpty) return '/';
    return joined;
  }

  WorkspaceZone _classifyGuest(String path) {
    return _mapGuest(p.posix.normalize(path))?.zone ?? WorkspaceZone.outside;
  }

  bool _hostInsideZone(WorkspaceZone zone, String hostPath) {
    switch (zone) {
      case WorkspaceZone.workspace:
        return _hostInside(workspaceHostRoot, hostPath);
      case WorkspaceZone.chat:
        return _hostInside(sessionHostDir, hostPath);
      case WorkspaceZone.skills:
        return _hostInside(skillsHostDir, hostPath);
      case WorkspaceZone.tmp:
        return _hostInside(tmpHostRoot, hostPath);
      case WorkspaceZone.external:
        return _externalMounts.any(
          (mount) => _hostInside(mount.host, hostPath),
        );
      case WorkspaceZone.outside:
        return false;
    }
  }

  ResolvedPath? _mapGuest(String normalized) {
    for (final mount in _externalMounts) {
      final rel = _guestRelative(normalized, mount.guest);
      if (rel != null) {
        return ResolvedPath(
          hostPath: _joinHost(mount.host, rel),
          modelPath: normalized,
          zone: WorkspaceZone.external,
        );
      }
    }
    final workspace = _guestRelative(normalized, guestWorkspace);
    if (workspace != null) {
      return ResolvedPath(
        hostPath: _joinHost(workspaceHostRoot, workspace),
        modelPath: normalized,
        zone: WorkspaceZone.workspace,
      );
    }
    final chat = _guestRelative(normalized, guestChat);
    if (chat != null) {
      return ResolvedPath(
        hostPath: _joinHost(sessionHostDir, chat),
        modelPath: normalized,
        zone: WorkspaceZone.chat,
      );
    }
    final skills = _guestRelative(normalized, guestSkills);
    if (skills != null) {
      return ResolvedPath(
        hostPath: _joinHost(skillsHostDir, skills),
        modelPath: normalized,
        zone: WorkspaceZone.skills,
      );
    }
    final tmp = _guestRelative(normalized, guestTmp);
    if (tmp != null) {
      return ResolvedPath(
        hostPath: _joinHost(tmpHostRoot, tmp),
        modelPath: normalized,
        zone: WorkspaceZone.tmp,
      );
    }
    return null;
  }

  WorkspaceZone _classifyHost(String hostPath) {
    if (_externalMounts.any((mount) => _hostInside(mount.host, hostPath))) {
      return WorkspaceZone.external;
    }
    if (_hostInside(workspaceHostRoot, hostPath)) {
      return WorkspaceZone.workspace;
    }
    if (_hostInside(sessionHostDir, hostPath)) return WorkspaceZone.chat;
    if (_hostInside(skillsHostDir, hostPath)) return WorkspaceZone.skills;
    if (_hostInside(tmpHostRoot, hostPath)) return WorkspaceZone.tmp;
    return WorkspaceZone.outside;
  }

  static void _rejectNul(String value) {
    if (value.contains('\u0000')) {
      throw const PathResolutionException('path contains NUL');
    }
  }

  static bool _usesDotDot(String a, String b) {
    return a.contains('..') || b.contains('..');
  }

  static String _canonHost(String path) => p.canonicalize(path);

  static String _joinHost(String root, String relative) {
    if (relative.isEmpty || relative == '.') return root;
    final posixRel = relative.replaceAll('\\', '/');
    return _canonHost(p.normalize(p.join(root, posixRel)));
  }

  static String _guestJoin(String guestRoot, String relative) {
    if (relative.isEmpty || relative == '.') return guestRoot;
    final posixRel = relative.replaceAll('\\', '/');
    return p.posix.normalize(p.posix.join(guestRoot, posixRel));
  }

  /// Relative posix path under [prefix], or null if [path] is not inside it.
  static String? _guestRelative(String path, String prefix) {
    if (path == prefix) return '';
    if (p.posix.isWithin(prefix, path)) {
      return p.posix.relative(path, from: prefix);
    }
    return null;
  }

  bool _hostInside(String root, String candidate) {
    for (final alias in _rootVariants(root)) {
      for (final cand in _rootVariants(candidate)) {
        if (p.equals(alias, cand) || p.isWithin(alias, cand)) return true;
      }
    }
    return false;
  }

  String? _relativeToRoot(String root, String hostPath) {
    for (final alias in _rootVariants(root)) {
      for (final cand in _rootVariants(hostPath)) {
        if (p.equals(alias, cand)) return '';
        if (p.isWithin(alias, cand)) {
          return p.relative(cand, from: alias);
        }
      }
    }
    return null;
  }

  static List<String> _rootVariants(String path) {
    final aliases = <String>{_canonHost(path)};
    try {
      aliases.add(p.canonicalize(File(path).resolveSymbolicLinksSync()));
    } on FileSystemException {
      try {
        aliases.add(p.canonicalize(Directory(path).resolveSymbolicLinksSync()));
      } on FileSystemException {
        // Path does not exist yet; lexical form is enough.
      }
    }
    return aliases.toList();
  }

  /// Follows existing symlinks, including parents of a not-yet-created file.
  static Future<String> resolveHostPath(String hostPath) async {
    try {
      if (await FileSystemEntity.isLink(hostPath)) {
        return p.canonicalize(await Link(hostPath).resolveSymbolicLinks());
      }
    } on FileSystemException {
      // Fall through to file/dir/parent walk.
    }
    try {
      if (await File(hostPath).exists()) {
        return p.canonicalize(await File(hostPath).resolveSymbolicLinks());
      }
    } on FileSystemException {
      // Continue.
    }
    try {
      if (await Directory(hostPath).exists()) {
        return p.canonicalize(await Directory(hostPath).resolveSymbolicLinks());
      }
    } on FileSystemException {
      // Continue.
    }

    final parts = <String>[];
    var current = p.normalize(hostPath);
    while (true) {
      parts.add(p.basename(current));
      final parent = p.dirname(current);
      if (parent == current) return _canonHost(hostPath);
      try {
        final realParent = await Directory(parent).resolveSymbolicLinks();
        return p.canonicalize(p.join(realParent, p.joinAll(parts.reversed)));
      } on FileSystemException {
        current = parent;
      }
    }
  }
}
