import 'skill_models.dart';

/// Result of parsing a `SKILL.md` file.
///
/// On success, [meta] is non-null and [body] contains the markdown content
/// after the YAML frontmatter. On failure, [meta] is null, [body] is empty,
/// and [error] contains a human-readable error message.
class SkillParseResult {
  const SkillParseResult({required this.meta, required this.body, this.error});

  factory SkillParseResult.error(String message) =>
      SkillParseResult(meta: null, body: '', error: message);

  /// Parsed metadata. Null when [isError] is true.
  final SkillMeta? meta;

  /// Markdown body after the frontmatter. Empty on error.
  final String body;

  /// Human-readable error message. Null on success.
  final String? error;

  /// True when parsing failed.
  bool get isError => error != null;
}

/// Parser for the Agent Skills `SKILL.md` format (https://agentskills.io).
///
/// Supports a minimal hand-written YAML subset covering the fields used by
/// the standard `SKILL.md` frontmatter:
///
///  * top-level `key: value` (scalar string; optional single/double quotes)
///  * top-level `key:` followed by indented `sub: value` lines, parsed into a
///    `Map<String, dynamic>` (used for `metadata`)
///  * top-level `key: value1 value2 value3` (whitespace-separated list of
///    tool names, used for `allowed-tools`)
///
/// Limitations (intentional, to avoid pulling in a YAML dependency):
///  * No block lists (`- item`).
///  * No inline comments after values.
///  * No multi-line scalar strings (folded `>` or literal `|`).
///  * Only one level of nesting under a top-level map key.
class SkillParser {
  SkillParser._();

  /// Separates YAML frontmatter from the markdown body.
  /// Matches the leading `---\n`, the frontmatter, the closing `\n---\n`,
  /// and the rest of the file as the body. Input is line-ending-normalized
  /// before matching, so this regex only needs to handle `\n`.
  static final RegExp _frontmatterPattern = RegExp(
    r'^---\n([\s\S]*?)\n---\n([\s\S]*)$',
  );

  /// Validates the skill `name` per the open standard.
  static final RegExp _namePattern = RegExp(r'^[a-z0-9]+(-[a-z0-9]+)*$');

  static const int _maxNameLength = 64;
  static const int _maxDescriptionLength = 1024;
  static const int _maxCompatibilityLength = 500;

  /// Parses [content] as a `SKILL.md` file located at [directoryPath].
  ///
  /// [now] is the import timestamp; defaults to [DateTime.now] when null.
  /// Returns a [SkillParseResult] containing either a valid [SkillMeta] and
  /// the markdown body, or a human-readable error message.
  static SkillParseResult parseSkillMd(
    String content, {
    required String directoryPath,
    DateTime? now,
  }) {
    if (content.isEmpty) {
      return SkillParseResult.error('SKILL.md content is empty.');
    }

    // Normalize CRLF / CR to LF so the frontmatter regex and YAML splitter
    // can use a single line-ending convention.
    final normalized = content.replaceAll('\r\n', '\n').replaceAll('\r', '\n');

    final match = _frontmatterPattern.firstMatch(normalized);
    if (match == null) {
      return SkillParseResult.error(
        'Missing YAML frontmatter. Expected leading "---\\n...\\n---\\n".',
      );
    }

    final frontmatter = match.group(1)!;
    final body = match.group(2)!;

    final parsed = _parseFrontmatter(frontmatter);
    if (parsed.error != null) {
      return SkillParseResult.error(parsed.error!);
    }

    final validation = _validate(parsed.values);
    if (validation != null) {
      return SkillParseResult.error(validation);
    }

    final meta = SkillMeta(
      name: parsed.values['name']! as String,
      description: parsed.values['description']! as String,
      version: parsed.values['version'] as String?,
      license: parsed.values['license'] as String?,
      compatibility: parsed.values['compatibility'] as String?,
      metadata: parsed.values['metadata'] as Map<String, dynamic>?,
      allowedTools: parsed.values['allowed-tools'] as List<String>?,
      directoryPath: directoryPath,
      globalEnabled: false,
      createdAt: now ?? DateTime.now(),
    );

    return SkillParseResult(meta: meta, body: body);
  }

  /// Parses the YAML frontmatter block (without the surrounding `---`).
  static _FrontmatterOutcome _parseFrontmatter(String frontmatter) {
    final values = <String, dynamic>{};
    final lines = frontmatter.split('\n');

    Map<String, dynamic>? currentMap;

    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];

      // Skip blank lines and full-line comments.
      if (line.trim().isEmpty) continue;
      if (line.trimLeft().startsWith('#')) continue;

      final isIndented = line.startsWith(' ') || line.startsWith('\t');

      if (!isIndented) {
        // Top-level key.
        currentMap = null;
        final colonIdx = line.indexOf(':');
        if (colonIdx <= 0) {
          return (
            values: const <String, dynamic>{},
            error:
                'Invalid YAML on line ${i + 1}: expected "key: value", '
                'got "${_preview(line)}".',
          );
        }
        final key = line.substring(0, colonIdx).trim();
        final rawValue = line.substring(colonIdx + 1).trim();

        if (rawValue.isEmpty) {
          // Start of an indented map block (e.g. metadata).
          currentMap = <String, dynamic>{};
          values[key] = currentMap;
        } else {
          values[key] = _parseScalar(rawValue);
        }
      } else {
        // Indented continuation - must belong to a map block.
        if (currentMap == null) {
          return (
            values: const <String, dynamic>{},
            error:
                'Unexpected indented line ${i + 1}: '
                '"${_preview(line)}".',
          );
        }
        final trimmed = line.trim();
        final colonIdx = trimmed.indexOf(':');
        if (colonIdx <= 0) {
          return (
            values: const <String, dynamic>{},
            error:
                'Invalid YAML on line ${i + 1}: expected "sub: value", '
                'got "${_preview(line)}".',
          );
        }
        final subKey = trimmed.substring(0, colonIdx).trim();
        final rawSubValue = trimmed.substring(colonIdx + 1).trim();
        currentMap[subKey] = _parseScalar(rawSubValue);
      }
    }

    _normalizeCollections(values);

    return (values: values, error: null);
  }

  /// Converts `allowed-tools` (whitespace-separated string) to `List<String>`
  /// and drops empty map placeholders for keys with no children.
  static void _normalizeCollections(Map<String, dynamic> values) {
    final tools = values['allowed-tools'];
    if (tools is String) {
      values['allowed-tools'] = tools
          .split(RegExp(r'\s+'))
          .where((e) => e.isNotEmpty)
          .toList(growable: false);
    } else if (tools is Map) {
      // `allowed-tools:` with no inline value - treat as absent.
      values.remove('allowed-tools');
    }

    final metadata = values['metadata'];
    if (metadata is Map<String, dynamic> && metadata.isEmpty) {
      values.remove('metadata');
    }
  }

  /// Parses a scalar value: strips quotes and attempts bool/int/double/null.
  static dynamic _parseScalar(String raw) {
    final s = raw.trim();
    if (s.isEmpty) return '';

    // Quoted strings (single or double).
    if (s.length >= 2) {
      final first = s[0];
      final last = s[s.length - 1];
      if ((first == '"' && last == '"') || (first == "'" && last == "'")) {
        return s.substring(1, s.length - 1);
      }
    }

    switch (s) {
      case 'true':
        return true;
      case 'false':
        return false;
      case 'null':
      case '~':
        return null;
    }

    final i = int.tryParse(s);
    if (i != null) return i;
    final d = double.tryParse(s);
    if (d != null) return d;

    return s;
  }

  /// Validates parsed fields against the open standard constraints.
  /// Returns null on success, or an error message on failure.
  static String? _validate(Map<String, dynamic> values) {
    final name = values['name'];
    if (name is! String || name.isEmpty) {
      return 'Field "name" is required and must be a non-empty string.';
    }
    if (name.length > _maxNameLength) {
      return 'Field "name" must be ≤$_maxNameLength characters '
          '(got ${name.length}).';
    }
    if (!_namePattern.hasMatch(name)) {
      return 'Field "name" must match ${_namePattern.pattern} '
          '(lowercase letters and digits separated by single hyphens; '
          'no leading, trailing, or consecutive hyphens).';
    }

    final description = values['description'];
    if (description is! String || description.isEmpty) {
      return 'Field "description" is required and must be a non-empty string.';
    }
    if (description.length > _maxDescriptionLength) {
      return 'Field "description" must be ≤$_maxDescriptionLength characters '
          '(got ${description.length}).';
    }

    final compatibility = values['compatibility'];
    if (compatibility is String &&
        compatibility.length > _maxCompatibilityLength) {
      return 'Field "compatibility" must be ≤$_maxCompatibilityLength '
          'characters (got ${compatibility.length}).';
    }

    final version = values['version'];
    if (version != null && version is! String) {
      return 'Field "version" must be a string.';
    }

    final license = values['license'];
    if (license != null && license is! String) {
      return 'Field "license" must be a string.';
    }

    final allowedTools = values['allowed-tools'];
    if (allowedTools != null && allowedTools is! List<String>) {
      return 'Field "allowed-tools" must be a whitespace-separated string.';
    }

    final metadata = values['metadata'];
    if (metadata != null && metadata is! Map<String, dynamic>) {
      return 'Field "metadata" must be a YAML map.';
    }

    return null;
  }

  /// Trims a line for inclusion in error messages.
  static String _preview(String line) {
    final trimmed = line.trim();
    if (trimmed.length <= 40) return trimmed;
    return '${trimmed.substring(0, 37)}...';
  }
}

/// Internal frontmatter parse outcome.
typedef _FrontmatterOutcome = ({Map<String, dynamic> values, String? error});
