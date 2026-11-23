import 'dart:convert';

import '../../../providers/settings_provider.dart';
import '../../api/providers/google_vertex.dart';
import '../media_adapter.dart';
import '../media_request.dart';

class GoogleMediaRoute {
  const GoogleMediaRoute(this.base, this.auth);

  final String base;
  final Map<String, String> auth;

  static final segment = RegExp(r'^[A-Za-z0-9_][A-Za-z0-9_.-]*$');

  static Future<GoogleMediaRoute> resolve(MediaContext context) async {
    final provider = context.provider;
    if (provider.vertexAI != true) {
      return GoogleMediaRoute(provider.baseUrl, {
        'x-goog-api-key': context.apiKey,
      });
    }
    final project = _project(provider);
    final location = (provider.location ?? '').trim();
    final region = location.isEmpty ? 'us-central1' : location;
    if (!segment.hasMatch(project) || !segment.hasMatch(region)) {
      throw const MediaFailure(
        MediaFailureKind.parameters,
        'Vertex AI needs a project and region',
      );
    }
    final token = (provider.serviceAccountJson ?? '').trim().isEmpty
        ? context.apiKey
        : await maybeVertexAccessToken(
            provider,
          ).timeout(const Duration(seconds: 45));
    if (token == null || token.isEmpty) {
      throw const MediaFailure(
        MediaFailureKind.login,
        'Vertex AI credentials unavailable',
      );
    }
    final host = region == 'global'
        ? 'aiplatform.googleapis.com'
        : '$region-aiplatform.googleapis.com';
    return GoogleMediaRoute(
      'https://$host/v1/projects/$project/locations/$region/publishers/google',
      {'Authorization': 'Bearer $token'},
    );
  }

  static String _project(ProviderConfig provider) {
    final project = (provider.projectId ?? '').trim();
    if (project.isNotEmpty) return project;
    try {
      if (jsonDecode(provider.serviceAccountJson ?? '') case {
        'project_id': final String id,
      }) {
        return id.trim();
      }
    } on FormatException {
      // An explicit provider project can be used with an access token.
    }
    return '';
  }
}

Future<({String mime, String base64})> googleImageInput(
  MediaReference reference,
) async {
  final dataUri = await mediaReferenceDataUri(reference);
  return (
    mime: dataUri.substring(5, dataUri.indexOf(';')),
    base64: dataUri.substring(dataUri.indexOf(',') + 1),
  );
}
