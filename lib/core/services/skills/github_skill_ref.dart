import 'package:path/path.dart' as p;

/// Parsed GitHub location of a skill (repo, optional ref, optional subdir).
class GitHubSkillRef {
  const GitHubSkillRef({
    required this.owner,
    required this.repo,
    this.ref,
    this.subdir,
  });

  final String owner;
  final String repo;
  final String? ref;
  final String? subdir;

  static GitHubSkillRef parse(String raw) {
    final parsed = tryParse(raw);
    if (parsed == null) {
      throw FormatException('Not a GitHub skill URL: $raw');
    }
    return parsed;
  }

  static GitHubSkillRef? tryParse(String raw) {
    var text = raw.trim();
    if (text.isEmpty) return null;
    if (!text.contains('://')) text = 'https://$text';
    final uri = Uri.tryParse(text);
    if (uri == null) return null;
    final host = uri.host.toLowerCase();
    final parts = [
      for (final segment in uri.pathSegments)
        if (segment.isNotEmpty) segment,
    ];
    if (host == 'raw.githubusercontent.com') {
      if (parts.length < 3) return null;
      return GitHubSkillRef(
        owner: parts[0],
        repo: _stripGitSuffix(parts[1]),
        ref: parts[2],
        subdir: _subdirFromFilePath(parts.skip(3).join('/')),
      );
    }
    if (host != 'github.com' && host != 'www.github.com') return null;
    if (parts.length < 2) return null;
    final owner = parts[0];
    final repo = _stripGitSuffix(parts[1]);
    if (parts.length == 2) {
      return GitHubSkillRef(owner: owner, repo: repo);
    }
    final kind = parts[2];
    if (kind != 'tree' && kind != 'blob' && kind != 'raw') {
      return GitHubSkillRef(owner: owner, repo: repo);
    }
    if (parts.length < 4) {
      return GitHubSkillRef(owner: owner, repo: repo);
    }
    final ref = parts[3];
    final rest = parts.skip(4).join('/');
    if (kind == 'tree') {
      return GitHubSkillRef(
        owner: owner,
        repo: repo,
        ref: ref,
        subdir: rest.isEmpty ? null : rest,
      );
    }
    return GitHubSkillRef(
      owner: owner,
      repo: repo,
      ref: ref,
      subdir: _subdirFromFilePath(rest),
    );
  }
}

String _stripGitSuffix(String repo) {
  return repo.endsWith('.git') ? repo.substring(0, repo.length - 4) : repo;
}

String? _subdirFromFilePath(String filePath) {
  if (filePath.isEmpty) return null;
  final posix = filePath.replaceAll('\\', '/');
  final dir = p.posix.dirname(posix);
  if (dir == '.' || dir == '/') return null;
  return dir;
}
