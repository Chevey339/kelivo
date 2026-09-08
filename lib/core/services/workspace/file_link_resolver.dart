import 'dart:io';

import 'package:path/path.dart' as p;

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
        command = Uri.splitQueryString(query.substring(1))['cmd'] ?? '';
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
        root = Directory.systemTemp.path;
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
