import 'dart:convert';

import 'package:collection/collection.dart';
import 'package:http/http.dart' as http;

import '../../models/media_creation.dart';
import 'media_request.dart';

/// The two media catalogs expose different schemas from the chat model list.
/// Keep only fields consumed by the creation composer.
class OpenRouterMediaModel {
  const OpenRouterMediaModel(this.mode, this.fields);
  final MediaMode mode;
  final Map<String, dynamic> fields;

  static bool isHost(String? host) => host == 'openrouter.ai';

  factory OpenRouterMediaModel.fromRow(MediaMode mode, Map row) {
    final params = row['supported_parameters'];
    final image = params is Map ? params : const {};
    List<String> strings(Object? values) =>
        values is List ? values.whereType<String>().toList() : [];
    List<String> choices(String key) =>
        strings(image[key] is Map ? image[key]['values'] : null);
    int limit(String key, int fallback, int maximum) {
      final field = image[key];
      final number = field is Map ? field['max'] : null;
      return number is int ? number.clamp(0, maximum) : fallback;
    }

    final formats = choices('output_format');
    const rasterFormats = {'png', 'jpeg', 'webp'};
    return OpenRouterMediaModel(
      mode,
      mode == MediaMode.image
          ? {
              'ratios': choices('aspect_ratio'),
              'sizes': choices('resolution'),
              'formats': formats.where(rasterFormats.contains).toList(),
              'raster': formats.isEmpty || formats.any(rasterFormats.contains),
              'qualities': choices('quality'),
              'count': limit('n', 1, 10).clamp(1, 10),
              'references': limit('input_references', 0, 16),
              'requiredReference': switch (image['input_references']) {
                {'min': final num value} => value > 0,
                _ => false,
              },
              'transparent': choices('background').contains('transparent'),
              'seed': image.containsKey('seed'),
            }
          : {
              'ratios': strings(row['supported_aspect_ratios']),
              'resolutions': strings(row['supported_resolutions']),
              'durations': [
                if (row['supported_durations'] case final List values) ...[
                  ...values.whereType<int>().where((value) => value > 0),
                  if (values.contains(-1)) -1,
                ],
              ],
              'frames': strings(row['supported_frame_images']),
              'seed': row['seed'] == true,
              'audio': row['generate_audio'] == true,
            },
    );
  }

  static OpenRouterMediaModel? fromJson(Object? data) {
    if (data is! Map || data['fields'] is! Map<String, dynamic>) return null;
    final mode = MediaMode.values.asNameMap()[data['mode']];
    return mode == null
        ? null
        : OpenRouterMediaModel(mode, data['fields'] as Map<String, dynamic>);
  }

  Map<String, Object?> toJson() => {'mode': mode.name, 'fields': fields};

  MediaCapabilities get capabilities {
    List<T> list<T>(String key) => switch (fields[key]) {
      final List values => values.whereType<T>().toList(),
      _ => [],
    };
    final frames = list<String>('frames');
    final roles = [
      if (frames.contains('first_frame')) MediaReferenceRole.firstFrame,
      if (frames.contains('first_frame') && frames.contains('last_frame'))
        MediaReferenceRole.lastFrame,
    ];
    return MediaCapabilities(
      aspectRatios: [
        'auto',
        ...list<String>('ratios').where((r) => r != 'auto'),
      ],
      maxPerRequest: switch (fields['count']) {
        final int n => n.clamp(1, 10),
        _ => 1,
      },
      maxReferences: switch (fields['references']) {
        final int n => n.clamp(0, 16),
        _ => roles.length,
      },
      requiresReference: fields['requiredReference'] == true,
      sizes: list<String>('sizes'),
      qualities: list<String>('qualities'),
      formats: list<String>('formats'),
      resolutions: list<String>('resolutions'),
      durations: list<int>('durations'),
      frameRoles: roles,
      supportsTransparent: fields['transparent'] == true,
      supportsSeed: fields['seed'] == true,
      platformOptions: [
        if (fields['audio'] == true)
          const MediaParameter(
            'generate_audio',
            MediaParameterType.boolean,
            defaultValue: true,
          ),
      ],
    );
  }

  // These catalog entries require a source video, avatar or audio input. The
  // ordinary video composer supports text and keyframes.
  bool get supportsComposer => mode == MediaMode.image
      ? fields['raster'] != false
      : fields['durations'] is List &&
                (fields['durations'] as List).isNotEmpty ||
            fields['frames'] is List && (fields['frames'] as List).isNotEmpty;

  @override
  bool operator ==(Object other) =>
      other is OpenRouterMediaModel &&
      mode == other.mode &&
      const DeepCollectionEquality().equals(fields, other.fields);
  @override
  int get hashCode =>
      Object.hash(mode, const DeepCollectionEquality().hash(fields));
}

Future<Map<String, OpenRouterMediaModel>?> fetchOpenRouterMediaModels(
  http.Client client,
  Uri base,
  Map<String, String> headers,
  MediaMode mode,
) async {
  final segment = mode == MediaMode.video ? 'videos' : 'images';
  final url = base.replace(
    path: '${base.path.replaceFirst(RegExp(r'/+$'), '')}/$segment/models',
  );
  try {
    final response = await client
        .get(url, headers: headers)
        .timeout(const Duration(seconds: 12));
    if (response.statusCode != 200) return null;
    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    if (decoded is! Map || decoded['data'] is! List) return null;
    final rows = decoded['data'] as List;
    return {
      for (final row in rows.whereType<Map>())
        if (row['id'] case final String id)
          id: OpenRouterMediaModel.fromRow(mode, row),
    };
  } on Exception {
    // The chat catalog remains usable if a media catalog is unavailable.
    return null;
  }
}

Future<void> mergeOpenRouterMediaCatalogs(
  http.Client client,
  Uri base,
  Map<String, String> headers,
  Map<String, Map> models, {
  required Map<String, OpenRouterMediaModel> Function(MediaMode) cached,
}) async {
  final catalogs = await Future.wait([
    for (final mode in MediaMode.values)
      fetchOpenRouterMediaModels(client, base, headers, mode),
  ]);
  for (final (i, mode) in MediaMode.values.indexed) {
    final media = catalogs[i] ?? cached(mode);
    for (final entry in media.entries) {
      final row = models[entry.key];
      final architecture = row?['architecture'];
      final outputs = architecture is Map
          ? architecture['output_modalities']
          : null;
      final inputs = architecture is Map
          ? architecture['input_modalities']
          : null;
      final descriptor = OpenRouterMediaModel(mode, {
        ...entry.value.fields,
        if (outputs is List) 'chat': outputs.contains('text'),
        if (inputs is List) 'chatInputs': inputs.whereType<String>().toList(),
        if (outputs is List)
          'chatOutputs': outputs.whereType<String>().toList(),
      });
      models[entry.key] = {
        ...?row,
        'id': entry.key,
        'openrouter_media': descriptor.toJson(),
      };
    }
  }
}
