import 'dart:io';

import 'package:path/path.dart' as p;

import '../../models/workspace_binding.dart';
import '../../providers/workspace_provider.dart';
import '../../../utils/app_directories.dart';

enum KelivoLinkKind {
  workspaceFile,
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
    this.terminalCommand,
  });

  final KelivoLinkKind kind;
  final String relativePath;
  final String? conversationId;
  final String? terminalCommand;

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
    if (segments == null || segments.isEmpty) return null;

    switch (host) {
      case 'workspace':
        return KelivoLink(
          kind: KelivoLinkKind.workspaceFile,
          relativePath: segments.join('/'),
        );
      case 'chat':
        if (segments.length < 2) return null;
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
        if (segments.length < 2) return null;
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
    if (rawPath == null || rawPath.isEmpty || rawPath == '/') return null;
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

class FileLinkResolver {
  FileLinkResolver({required this.workspaces});

  final WorkspaceProvider workspaces;

  Future<File?> resolveToHostFile(
    KelivoLink link, {
    required String conversationId,
    required WorkspaceBinding binding,
  }) async {
    if (link.kind == KelivoLinkKind.terminal) return null;
    if (!_isSafeRelativePath(link.relativePath)) return null;
    final sessionId =
        (link.conversationId != null && link.conversationId!.isNotEmpty)
        ? link.conversationId!
        : conversationId;

    switch (link.kind) {
      case KelivoLinkKind.workspaceFile:
        if (!binding.isBound) return null;
        await workspaces.loaded;
        final workspace = workspaces.byId(binding.workspaceId!);
        if (workspace == null) return null;
        final root = await workspaces.hostRootFor(workspace);
        return _fileUnderRoot(root, link.relativePath);
      case KelivoLinkKind.chatAttachment:
        final session = await AppDirectories.sessionDir(sessionId);
        return _fileUnderRoot(
          p.join(session.path, 'attachments'),
          link.relativePath,
        );
      case KelivoLinkKind.chatOutput:
        final session = await AppDirectories.sessionDir(sessionId);
        return _fileUnderRoot(
          p.join(session.path, 'outputs'),
          link.relativePath,
        );
      case KelivoLinkKind.skillFile:
        final parts = link.relativePath.split('/');
        if (parts.length < 2) return null;
        final skillId = parts.first;
        if (!KelivoLink._isSafeSegment(skillId)) return null;
        final rel = parts.sublist(1).join('/');
        if (!_isSafeRelativePath(rel)) return null;
        final skillRoot = await AppDirectories.skillDir(skillId);
        return _fileUnderRoot(skillRoot.path, rel);
      case KelivoLinkKind.terminal:
        return null;
    }
  }

  static bool _isSafeRelativePath(String relativePath) {
    if (relativePath.isEmpty) return false;
    if (relativePath.startsWith('/') || relativePath.startsWith(r'\')) {
      return false;
    }
    if (RegExp(r'^[a-zA-Z]:').hasMatch(relativePath)) return false;
    for (final part in relativePath.split('/')) {
      if (!KelivoLink._isSafeSegment(part)) return false;
    }
    return true;
  }

  static File? _fileUnderRoot(String root, String relativePath) {
    if (!_isSafeRelativePath(relativePath)) return null;
    try {
      final canonicalRoot = p.canonicalize(root);
      final joined = p.join(canonicalRoot, relativePath);
      final canonical = p.canonicalize(joined);
      if (!p.isWithin(canonicalRoot, canonical)) return null;
      if (!FileSystemEntity.isFileSync(canonical)) return null;
      return File(canonical);
    } on FileSystemException {
      return null;
    }
  }
}
