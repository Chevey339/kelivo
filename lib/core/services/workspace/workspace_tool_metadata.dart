import 'output_buffer.dart';

/// Chat-UI metadata for a workspace tool result.
///
/// Persisted on the tool part and shown in the UI. Never sent to the model.
class WorkspaceToolMetadata {
  static const int previewMaxChars = 4096;

  const WorkspaceToolMetadata({
    required this.tool,
    required this.status,
    this.code,
    this.path,
    this.link,
    this.command,
    this.exitCode,
    this.durationMs,
    this.timedOut,
    this.cancelled,
    this.interrupted,
    this.stdoutPreview,
    this.stderrPreview,
    this.outputLink,
    this.changedFiles,
    this.changedLinks,
    this.diff,
    this.added,
    this.removed,
    this.diffTruncated,
    this.strategy,
    this.created,
    this.bytes,
    this.count,
    this.truncated,
  });

  final String tool;
  final String status;
  final String? code;
  final String? path;
  final String? link;
  final String? command;
  final int? exitCode;
  final int? durationMs;
  final bool? timedOut;
  final bool? cancelled;
  final bool? interrupted;
  final String? stdoutPreview;
  final String? stderrPreview;
  final String? outputLink;
  final List<String>? changedFiles;
  final List<String>? changedLinks;
  final String? diff;
  final int? added;
  final int? removed;
  final bool? diffTruncated;
  final String? strategy;
  final bool? created;
  final int? bytes;
  final int? count;
  final bool? truncated;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'workspace': <String, dynamic>{
        'tool': tool,
        'status': status,
        'code': code,
        'path': path,
        'link': link,
        'command': command,
        'exitCode': exitCode,
        'durationMs': durationMs,
        'timedOut': timedOut,
        'cancelled': cancelled,
        'interrupted': interrupted,
        'stdoutPreview': capPreview(stdoutPreview),
        'stderrPreview': capPreview(stderrPreview),
        'outputLink': outputLink,
        'changedFiles': changedFiles,
        'changedLinks': changedLinks,
        'diff': diff,
        'added': added,
        'removed': removed,
        'diffTruncated': diffTruncated,
        'strategy': strategy,
        'created': created,
        'bytes': bytes,
        'count': count,
        'truncated': truncated,
      },
    };
  }

  factory WorkspaceToolMetadata.fromJson(Map<String, dynamic> json) {
    final raw = json['workspace'];
    final map = raw is Map
        ? Map<String, dynamic>.from(raw)
        : Map<String, dynamic>.from(json);
    return WorkspaceToolMetadata(
      tool: map['tool'] as String? ?? '',
      status: map['status'] as String? ?? 'ok',
      code: map['code'] as String?,
      path: map['path'] as String?,
      link: map['link'] as String?,
      command: map['command'] as String?,
      exitCode: _asInt(map['exitCode']),
      durationMs: _asInt(map['durationMs']),
      timedOut: map['timedOut'] as bool?,
      cancelled: map['cancelled'] as bool?,
      interrupted: map['interrupted'] as bool?,
      stdoutPreview: capPreview(map['stdoutPreview'] as String?),
      stderrPreview: capPreview(map['stderrPreview'] as String?),
      outputLink: map['outputLink'] as String?,
      changedFiles: _asStringList(map['changedFiles']),
      changedLinks: _asStringList(map['changedLinks']),
      diff: map['diff'] as String?,
      added: _asInt(map['added']),
      removed: _asInt(map['removed']),
      diffTruncated: map['diffTruncated'] as bool?,
      strategy: map['strategy'] as String?,
      created: map['created'] as bool?,
      bytes: _asInt(map['bytes']),
      count: _asInt(map['count']),
      truncated: map['truncated'] as bool?,
    );
  }

  static String? capPreview(String? value) {
    if (value == null) return null;
    return utf16SafeCut(value, previewMaxChars, keepTail: true);
  }

  static int? _asInt(Object? value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString());
  }

  static List<String>? _asStringList(Object? value) {
    if (value is! List) return null;
    return [for (final item in value) item.toString()];
  }
}
