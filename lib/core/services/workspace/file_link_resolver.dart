import 'dart:io';

import 'package:path/path.dart' as p;

import '../../models/workspace.dart';
import '../../models/workspace_binding.dart';
import '../../providers/workspace_provider.dart';
import '../../providers/external_mounts_provider.dart';
import '../../../utils/app_directories.dart';
import 'workspace_paths.dart';

enum KelivoLinkKind {
  workspaceFile,
  chatFile,
  externalFile,
  temporaryFile,
  chatAttachment,
  chatOutput,
  skillFile,
  terminal,
}

class KelivoLink {
  const KelivoLink({
    required this.kind,
    required this.relativePath,
    this.conversationId,
    this.mountId,
    this.terminalCommand,
  });

  final KelivoLinkKind kind;
  final String relativePath;
  final String? conversationId;
  final String? mountId;
  final String? terminalCommand;

  /// Absolute guest path for the referenced entry in its owning mount/session.
  String? guestPath({String? mountRoot}) {
    final root = switch (kind) {
      KelivoLinkKind.workspaceFile => WorkspacePaths.guestWorkspace,
      KelivoLinkKind.chatFile => WorkspacePaths.guestChat,
      KelivoLinkKind.chatAttachment =>
        '${WorkspacePaths.guestChat}/attachments',
      KelivoLinkKind.chatOutput => '${WorkspacePaths.guestChat}/outputs',
      KelivoLinkKind.skillFile => WorkspacePaths.guestSkills,
      KelivoLinkKind.temporaryFile => WorkspacePaths.guestTmp,
      KelivoLinkKind.externalFile => mountRoot,
      KelivoLinkKind.terminal => null,
    };
    return root == null ? null : p.posix.join(root, relativePath);
  }

  static const String scheme = 'kelivo';

  /// Percent-encodes each path segment with [Uri.encodeComponent].
  /// Builders and the model prompt share this rule; [tryParse] decodes
  /// per segment and also accepts raw UTF-8.
  static String encodePath(String relativePath) {
    final parts = relativePath.replaceAll(r'\', '/').split('/');
    final encoded = <String>[];
    for (final part in parts) {
      if (part.isEmpty) continue;
      encoded.add(Uri.encodeComponent(part));
    }
    return encoded.join('/');
  }

  static KelivoLink? tryParse(String url) {
    final raw = url.trim();
    if (raw.isEmpty) return null;
    // Manual split: a case-insensitive regex `[^/?#]` does not match
    // non-ASCII (Dart ignoreCase + negated class), so model-emitted
    // `kelivo://workspace/员工表.csv` never parsed. Do not use [Uri]
    // either — it would normalize `%2e%2e` / `..` away.
    const scheme = 'kelivo://';
    if (raw.length < scheme.length) return null;
    if (raw.substring(0, scheme.length).toLowerCase() != scheme) {
      return null;
    }
    final rest = raw.substring(scheme.length);
    final hash = rest.indexOf('#');
    final withoutFragment = hash < 0 ? rest : rest.substring(0, hash);
    final q = withoutFragment.indexOf('?');
    final query = q < 0 ? null : withoutFragment.substring(q);
    final authorityAndPath = q < 0
        ? withoutFragment
        : withoutFragment.substring(0, q);
    final slash = authorityAndPath.indexOf('/');
    final host =
        (slash < 0 ? authorityAndPath : authorityAndPath.substring(0, slash))
            .toLowerCase();
    final rawPath = slash < 0 ? null : authorityAndPath.substring(slash);
    if (host.isEmpty) return null;

    if (host == 'terminal') {
      var command = '';
      if (query != null && query.length > 1) {
        try {
          command = Uri.splitQueryString(query.substring(1))['cmd'] ?? '';
        } on ArgumentError {
          return null;
        } on FormatException {
          return null;
        }
      }
      return KelivoLink(
        kind: KelivoLinkKind.terminal,
        relativePath: '',
        terminalCommand: command,
      );
    }

    final segments = _decodedRelativeSegments(rawPath);
    if (segments == null) return null;

    switch (host) {
      case 'session':
        return KelivoLink(
          kind: KelivoLinkKind.chatFile,
          relativePath: segments.join('/'),
        );
      case 'tmp':
        return KelivoLink(
          kind: KelivoLinkKind.temporaryFile,
          relativePath: segments.join('/'),
        );
      case 'mounts':
        if (segments.isEmpty) return null;
        return KelivoLink(
          kind: KelivoLinkKind.externalFile,
          mountId: segments.first,
          relativePath: segments.skip(1).join('/'),
        );
      case 'workspace':
        return KelivoLink(
          kind: KelivoLinkKind.workspaceFile,
          relativePath: segments.join('/'),
        );
      case 'chat':
        if (segments.isEmpty) return null;
        final folder = segments.first;
        final rest = segments.sublist(1);
        if (folder == 'attachments') {
          return KelivoLink(
            kind: KelivoLinkKind.chatAttachment,
            relativePath: rest.join('/'),
          );
        }
        if (folder == 'outputs') {
          return KelivoLink(
            kind: KelivoLinkKind.chatOutput,
            relativePath: rest.join('/'),
          );
        }
        if (rest.isEmpty) return null;
        // kelivo://chat/<conversationId>/… — model-emitted or explicit id.
        if (!_isSafeSegment(folder)) return null;
        if (rest.first == 'attachments' || rest.first == 'outputs') {
          if (rest.length < 2) return null;
          return KelivoLink(
            kind: rest.first == 'attachments'
                ? KelivoLinkKind.chatAttachment
                : KelivoLinkKind.chatOutput,
            relativePath: rest.sublist(1).join('/'),
            conversationId: folder,
          );
        }
        return KelivoLink(
          kind: KelivoLinkKind.chatOutput,
          relativePath: rest.join('/'),
          conversationId: folder,
        );
      case 'skills':
        return KelivoLink(
          kind: KelivoLinkKind.skillFile,
          relativePath: segments.join('/'),
        );
      default:
        return null;
    }
  }

  static String _stripInvisibleAndTrim(String url) =>
      url.replaceAll(RegExp(r'[\u200B\u200C\u200D\uFEFF]'), '').trim();

  static String? _unwrapLocalFileUri(String raw) {
    if (raw.length < 5 || raw.substring(0, 5).toLowerCase() != 'file:') {
      return raw;
    }
    final rest = raw.substring(5);
    if (rest.startsWith('///')) {
      return rest.substring(2);
    }
    if (rest.length >= 12 &&
        rest.substring(0, 12).toLowerCase() == '//localhost/') {
      return rest.substring(11);
    }
    return null;
  }

  static String _stripQueryAndFragment(String raw) {
    final hash = raw.indexOf('#');
    final withoutFragment = hash < 0 ? raw : raw.substring(0, hash);
    final q = withoutFragment.indexOf('?');
    return q < 0 ? withoutFragment : withoutFragment.substring(0, q);
  }

  /// True for UNC network paths (`//...`, `\\...`) and non-local `file:` URIs.
  static bool isDisallowedLocalUriOrUnc(String url) {
    final raw = _stripInvisibleAndTrim(url);
    if (raw.isEmpty) return false;
    if (raw.startsWith('//') || raw.startsWith(r'\\')) return true;
    if (raw.length >= 5 && raw.substring(0, 5).toLowerCase() == 'file:') {
      final unwrapped = _unwrapLocalFileUri(raw);
      if (unwrapped == null) return true;
      if (unwrapped.startsWith('//') || unwrapped.startsWith(r'\\')) {
        return true;
      }
    }
    return false;
  }

  /// True when [url] (or a local `file:` URI wrapping it) targets one of the
  /// sandbox virtual prefixes (`/workspace`, `/chat`, `/skills`, `/tmp`).
  static bool hasVirtualSandboxPrefix(String url) {
    final cleaned = _stripInvisibleAndTrim(url);
    if (cleaned.isEmpty) return false;
    final unwrapped = _unwrapLocalFileUri(cleaned);
    if (unwrapped == null) return false;
    if (unwrapped.startsWith('//') || unwrapped.startsWith(r'\\')) {
      return false;
    }
    final path = _stripQueryAndFragment(unwrapped);
    const prefixes = [
      WorkspacePaths.guestWorkspace,
      WorkspacePaths.guestChat,
      WorkspacePaths.guestSkills,
      WorkspacePaths.guestTmp,
    ];
    for (final prefix in prefixes) {
      if (path == prefix ||
          path.startsWith('$prefix/') ||
          path.startsWith('$prefix\\')) {
        return true;
      }
    }
    return false;
  }

  /// Parses sandbox virtual paths such as `/workspace/...`, `/chat/...`,
  /// `/skills/...`, `/tmp/...`, and local `file:///workspace/...` URIs.
  static KelivoLink? tryParseVirtualPath(String url) {
    final cleaned = _stripInvisibleAndTrim(url);
    if (cleaned.isEmpty) return null;
    final unwrapped = _unwrapLocalFileUri(cleaned);
    if (unwrapped == null) return null;
    if (unwrapped.startsWith('//') || unwrapped.startsWith(r'\\')) {
      return null;
    }
    final path = _stripQueryAndFragment(unwrapped);
    if (path.contains(r'\') || path.contains('\x00')) return null;

    const routes = [
      (
        '${WorkspacePaths.guestChat}/attachments',
        KelivoLinkKind.chatAttachment,
      ),
      ('${WorkspacePaths.guestChat}/outputs', KelivoLinkKind.chatOutput),
      (WorkspacePaths.guestChat, KelivoLinkKind.chatFile),
      (WorkspacePaths.guestWorkspace, KelivoLinkKind.workspaceFile),
      (WorkspacePaths.guestSkills, KelivoLinkKind.skillFile),
      (WorkspacePaths.guestTmp, KelivoLinkKind.temporaryFile),
    ];

    for (final (prefix, kind) in routes) {
      final String? tail;
      if (path == prefix) {
        tail = null;
      } else if (path.startsWith('$prefix/')) {
        tail = path.substring(prefix.length);
      } else {
        continue;
      }
      final segments = _decodedRelativeSegments(tail);
      if (segments == null) return null;
      return KelivoLink(kind: kind, relativePath: segments.join('/'));
    }
    return null;
  }

  /// Decodes path segments and rejects `..`, `.`, empties, separators, and
  /// absolute-host / drive paths. [rawPath] is the `/...` portion before
  /// query/fragment, not a normalized [Uri.path].
  static List<String>? _decodedRelativeSegments(String? rawPath) {
    if (rawPath == null || rawPath.isEmpty || rawPath == '/') return const [];
    if (!rawPath.startsWith('/')) return null;
    var path = rawPath.substring(1);
    if (path.startsWith('/') || path.startsWith(r'\')) return null;
    if (RegExp(r'^[a-zA-Z]:').hasMatch(path)) return null;
    if (path.isEmpty) return null;

    final rawParts = path.split('/');
    final decoded = <String>[];
    for (final raw in rawParts) {
      if (raw.isEmpty) return null;
      final part = _decodePathSegment(raw);
      if (part == null || !_isSafeSegment(part)) return null;
      decoded.add(part);
    }
    return decoded;
  }

  /// Percent-decode one path segment. [Uri.decodeComponent] throws
  /// `ArgumentError: Illegal percent encoding` on any code unit > 127, so
  /// raw UTF-8 names (`员工表.csv`) must be passed through. Mixed segments
  /// (`报告%20终稿.csv`) are normalized then decoded.
  static String? _decodePathSegment(String raw) {
    if (!raw.contains('%')) return raw;
    final normalized = StringBuffer();
    for (final rune in raw.runes) {
      if (rune > 127) {
        normalized.write(Uri.encodeComponent(String.fromCharCode(rune)));
      } else {
        normalized.writeCharCode(rune);
      }
    }
    try {
      return Uri.decodeComponent(normalized.toString());
    } on ArgumentError {
      return null;
    } on FormatException {
      return null;
    }
  }

  static bool _isSafeSegment(String part) {
    if (part.isEmpty || part == '.' || part == '..') return false;
    if (part.contains('/') || part.contains(r'\')) return false;
    if (part.contains('\x00')) return false;
    return true;
  }
}

enum FileLinkFailure { missing, mountUnavailable }

class FileLinkException implements Exception {
  const FileLinkException(this.reason);
  final FileLinkFailure reason;
}

class FileLinkResolver {
  FileLinkResolver({required this.workspaces, this.externalMounts});

  final WorkspaceProvider workspaces;
  final ExternalMountsProvider? externalMounts;

  Future<File?> resolveToHostFile(
    KelivoLink link, {
    required String conversationId,
    required WorkspaceBinding binding,
  }) async {
    try {
      final entry = await resolveToHostEntry(
        link,
        conversationId: conversationId,
        binding: binding,
      );
      return entry is File ? entry : null;
    } on FileLinkException {
      return null;
    }
  }

  Future<Workspace?> findOwningWorkspace(String filePath) async {
    await workspaces.loaded;
    final canonicalFile = _canonicalizeExistingOrLexical(filePath);
    Workspace? bestMatch;
    var bestLength = -1;
    for (final workspace in workspaces.workspaces) {
      final String hostRoot;
      try {
        hostRoot = await workspaces.hostRootFor(workspace);
      } catch (_) {
        continue;
      }
      if (hostRoot.isEmpty) continue;
      final canonicalRoot = _canonicalizeExistingDirOrLexical(hostRoot);
      if (p.equals(canonicalRoot, canonicalFile) ||
          p.isWithin(canonicalRoot, canonicalFile)) {
        if (canonicalRoot.length > bestLength) {
          bestLength = canonicalRoot.length;
          bestMatch = workspace;
        }
      }
    }
    return bestMatch;
  }

  Future<FileSystemEntity?> resolveToHostEntryInWorkspace(
    KelivoLink link, {
    required String workspaceId,
  }) async {
    if (link.kind != KelivoLinkKind.workspaceFile) return null;
    if (!_isSafeRelativePath(link.relativePath)) return null;
    await workspaces.loaded;
    final workspace = workspaces.byId(workspaceId);
    if (workspace == null) return null;
    final String root;
    try {
      root = await workspaces.hostRootFor(workspace);
    } catch (_) {
      return null;
    }
    return _entryUnderRoot(root, link.relativePath);
  }

  Future<File?> resolveToHostFileInWorkspace(
    KelivoLink link, {
    required String workspaceId,
  }) async {
    try {
      final entry = await resolveToHostEntryInWorkspace(
        link,
        workspaceId: workspaceId,
      );
      return entry is File ? entry : null;
    } on FileLinkException {
      return null;
    }
  }

  static Future<File?> resolveSkillFile(KelivoLink link) async {
    if (link.kind != KelivoLinkKind.skillFile) return null;
    if (!_isSafeRelativePath(link.relativePath)) return null;
    try {
      final root = (await AppDirectories.getSkillsDirectory()).path;
      final entry = _entryUnderRoot(root, link.relativePath);
      return entry is File ? entry : null;
    } on FileLinkException {
      return null;
    }
  }

  static final RegExp _schemeOrDrivePrefix = RegExp(
    r'^[a-zA-Z][a-zA-Z0-9+.-]*:',
  );

  /// True when [url] is a relative file reference (not empty, not rooted with
  /// `/` or `\`, not a URI scheme or Windows drive prefix, and no NUL bytes).
  static bool isRelativeFileRef(String url) {
    final raw = KelivoLink._stripInvisibleAndTrim(url);
    if (raw.isEmpty) return false;
    if (raw.startsWith('/') || raw.startsWith(r'\')) return false;
    if (raw.contains('\x00')) return false;
    if (_schemeOrDrivePrefix.hasMatch(raw)) return false;
    final path = KelivoLink._stripQueryAndFragment(raw);
    return path.isNotEmpty;
  }

  /// Resolves a relative reference against [baseFilePath]'s parent directory,
  /// confining both the base directory and the symlink-resolved target strictly
  /// inside [boundaryRoot] (or `File(baseFilePath).parent` when omitted).
  static File? resolveRelativeToFile(
    String rawRef, {
    required String baseFilePath,
    String? boundaryRoot,
  }) {
    if (!isRelativeFileRef(rawRef)) return null;
    final raw = KelivoLink._stripQueryAndFragment(
      KelivoLink._stripInvisibleAndTrim(rawRef),
    );
    if (raw.isEmpty) return null;

    final normalizedRef = raw.replaceAll(r'\', '/');
    final rawParts = normalizedRef.split('/');
    final decodedSegments = <String>[];
    for (final rawPart in rawParts) {
      if (rawPart.isEmpty) return null;
      final part = KelivoLink._decodePathSegment(rawPart);
      if (part == null ||
          part.isEmpty ||
          part.contains('/') ||
          part.contains(r'\') ||
          part.contains('\x00')) {
        return null;
      }
      decodedSegments.add(part);
    }
    if (decodedSegments.isEmpty) return null;

    try {
      final baseDir = File(baseFilePath).parent;
      if (!baseDir.existsSync()) return null;
      final canonicalBaseDir = p.canonicalize(
        baseDir.resolveSymbolicLinksSync(),
      );
      final effectiveBoundary = boundaryRoot ?? baseDir.path;
      if (!Directory(effectiveBoundary).existsSync()) return null;
      final canonicalBoundary = p.canonicalize(
        Directory(effectiveBoundary).resolveSymbolicLinksSync(),
      );
      if (!p.equals(canonicalBoundary, canonicalBaseDir) &&
          !p.isWithin(canonicalBoundary, canonicalBaseDir)) {
        return null;
      }

      final joined = p.canonicalize(
        p.joinAll([baseDir.path, ...decodedSegments]),
      );
      final type = FileSystemEntity.typeSync(joined);
      if (type != FileSystemEntityType.file) return null;
      final canonicalTarget = p.canonicalize(
        File(joined).resolveSymbolicLinksSync(),
      );
      if (!p.equals(canonicalBoundary, canonicalTarget) &&
          !p.isWithin(canonicalBoundary, canonicalTarget)) {
        return null;
      }
      return File(joined);
    } on FileSystemException {
      return null;
    }
  }

  static String _canonicalizeExistingOrLexical(String path) {
    try {
      if (File(path).existsSync()) {
        return p.canonicalize(File(path).resolveSymbolicLinksSync());
      }
      if (Directory(path).existsSync()) {
        return p.canonicalize(Directory(path).resolveSymbolicLinksSync());
      }
      final parent = Directory(p.dirname(path));
      if (parent.existsSync()) {
        return p.canonicalize(
          p.join(parent.resolveSymbolicLinksSync(), p.basename(path)),
        );
      }
    } on FileSystemException {
      // Fall back to lexical canonicalization when target/parent is unreachable.
    }
    return p.canonicalize(path);
  }

  static String _canonicalizeExistingDirOrLexical(String path) {
    try {
      if (Directory(path).existsSync()) {
        return p.canonicalize(Directory(path).resolveSymbolicLinksSync());
      }
    } on FileSystemException {
      // Fall back to lexical canonicalization when directory is unreachable.
    }
    return p.canonicalize(path);
  }

  Future<FileSystemEntity?> resolveToHostEntry(
    KelivoLink link, {
    required String conversationId,
    required WorkspaceBinding binding,
  }) async {
    if (link.kind == KelivoLinkKind.terminal) return null;
    if (!_isSafeRelativePath(link.relativePath)) return null;
    final sessionId = link.conversationId ?? conversationId;
    late final String root;
    switch (link.kind) {
      case KelivoLinkKind.workspaceFile:
        if (!binding.isBound) return null;
        await workspaces.loaded;
        final workspace = workspaces.byId(binding.workspaceId!);
        if (workspace == null) return null;
        root = await workspaces.hostRootFor(workspace);
      case KelivoLinkKind.chatAttachment:
        root = p.join(
          (await AppDirectories.sessionDir(sessionId)).path,
          'attachments',
        );
      case KelivoLinkKind.chatOutput:
        root = p.join(
          (await AppDirectories.sessionDir(sessionId)).path,
          'outputs',
        );
      case KelivoLinkKind.chatFile:
        root = (await AppDirectories.sessionDir(sessionId)).path;
      case KelivoLinkKind.skillFile:
        root = (await AppDirectories.getSkillsDirectory()).path;
      case KelivoLinkKind.temporaryFile:
        root = p.join((await AppDirectories.sessionDir(sessionId)).path, 'tmp');
      case KelivoLinkKind.externalFile:
        final provider = externalMounts;
        if (provider == null) {
          throw const FileLinkException(FileLinkFailure.mountUnavailable);
        }
        try {
          final mounts = await provider.resolveMounts();
          final mount = mounts
              .where((m) => m.externalId == link.mountId)
              .firstOrNull;
          if (mount == null) {
            throw const FileLinkException(FileLinkFailure.mountUnavailable);
          }
          root = mount.host;
        } catch (_) {
          throw const FileLinkException(FileLinkFailure.mountUnavailable);
        }
      case KelivoLinkKind.terminal:
        return null;
    }
    return _entryUnderRoot(root, link.relativePath);
  }

  static bool _isSafeRelativePath(String relativePath) {
    if (relativePath.isEmpty) return true;
    if (relativePath.startsWith('/') || relativePath.startsWith(r'\')) {
      return false;
    }
    if (RegExp(r'^[a-zA-Z]:').hasMatch(relativePath)) return false;
    return relativePath.split('/').every(KelivoLink._isSafeSegment);
  }

  static FileSystemEntity? _entryUnderRoot(String root, String relativePath) {
    try {
      final canonicalRoot = Directory(root).resolveSymbolicLinksSync();
      final joined = p.join(p.canonicalize(root), relativePath);
      final type = FileSystemEntity.typeSync(joined);
      if (type == FileSystemEntityType.notFound) {
        throw const FileLinkException(FileLinkFailure.missing);
      }
      final canonical = type == FileSystemEntityType.directory
          ? Directory(joined).resolveSymbolicLinksSync()
          : File(joined).resolveSymbolicLinksSync();
      if (!p.equals(canonicalRoot, canonical) &&
          !p.isWithin(canonicalRoot, canonical)) {
        return null;
      }
      if (type == FileSystemEntityType.file) return File(joined);
      if (type == FileSystemEntityType.directory) return Directory(joined);
      return null;
    } on FileSystemException {
      throw const FileLinkException(FileLinkFailure.missing);
    }
  }
}
