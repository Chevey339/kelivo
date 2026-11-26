import 'dart:convert';

/// A fal submission can produce multiple files for each requested generation.
/// Keep its download cursor beside the request snapshot, without storing media,
/// credentials, or signed download URLs.
class FalBatchState {
  const FalBatchState({
    required this.submission,
    required this.model,
    this.completed = 0,
    this.pending,
    this.draftId,
  });
  final Uri submission;
  final String model;
  FalBatchState advance(int generations) => FalBatchState(
    model: model,
    submission: submission,
    completed: generations,
    draftId: draftId,
  );
  static const key = '_falBatch';
  final int completed;
  final FalPendingResult? pending;
  final String? draftId;

  static FalBatchState? fromParameters(String json) {
    final params = jsonDecode(json);
    if (params is! Map) {
      throw const FormatException('Invalid creation parameters');
    }
    final raw = params[key];
    if (raw == null) return null;
    if (raw is! Map ||
        raw['model'] is! String ||
        raw['submission'] is! String ||
        raw['completed'] is! int ||
        raw['completed'] < 0 ||
        raw['draftId'] != null && raw['draftId'] is! String) {
      throw const FormatException('Invalid fal generation progress');
    }
    return FalBatchState(
      completed: raw['completed'] as int,
      model: raw['model'] as String,
      submission: Uri.parse(raw['submission'] as String),
      pending: raw['pending'] == null
          ? null
          : FalPendingResult.fromJson(raw['pending']),
      draftId: raw['draftId'] as String?,
    );
  }

  static String? draftIdForMenu(String parameters) {
    try {
      return fromParameters(parameters)?.draftId;
    } on FormatException {
      return null;
    }
  }

  Map<String, Object?> get json => {
    'completed': completed,
    'model': model,
    'submission': FalResultLocation.address(submission),
    if (pending != null) 'pending': pending!.json,
    if (draftId != null) 'draftId': draftId,
  };
}

/// Only queue locations are retained. Media download links and URL credentials
/// are never written to the batch.
class FalResultLocation {
  const FalResultLocation({
    required this.model,
    required this.submission,
    required this.result,
    required this.limit,
    required this.lastFrame,
  });
  final String model;
  final Uri submission, result;
  final int? limit;
  final bool lastFrame;

  static String address(Uri uri) => '${uri.origin}${uri.path}';
}

class FalPendingResult {
  const FalPendingResult({
    required this.location,
    required this.count,
    required this.first,
    this.files,
  });
  final FalResultLocation location;
  final int count, first;
  final int? files;

  factory FalPendingResult.fromJson(Object? raw) {
    if (raw
        case {
          'endpoint': final String model,
          'submission': final String submission,
          'url': final String url,
          'count': final int count,
          'first': final int first,
          'lastFrame': final bool lastFrame,
        }
        when count > 0 &&
            count <= 16 &&
            first >= 0 &&
            (raw['files'] == null ||
                raw['files'] is int && (raw['files'] as int) > 0) &&
            (raw['limit'] == null ||
                raw['limit'] is int && (raw['limit'] as int) > 0)) {
      return FalPendingResult(
        location: FalResultLocation(
          model: model,
          submission: Uri.parse(submission),
          result: Uri.parse(url),
          limit: raw['limit'] as int?,
          lastFrame: lastFrame,
        ),
        count: count,
        first: first,
        files: raw['files'] as int?,
      );
    }
    throw const FormatException('Invalid fal result cursor');
  }

  Map<String, Object?> get json => {
    'endpoint': location.model,
    'submission': FalResultLocation.address(location.submission),
    'url': FalResultLocation.address(location.result),
    'count': count,
    'first': first,
    if (files != null) 'files': files,
    if (location.limit != null) 'limit': location.limit,
    'lastFrame': location.lastFrame,
  };
}
