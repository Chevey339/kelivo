import 'dart:convert';

import '../../../providers/settings_provider.dart';
import '../../api/providers/google_vertex.dart';
import '../../../utils/provider_url.dart';
import '../../api/chat_api_helpers.dart' show mimeFromPath;
import '../media_adapter.dart';
import '../media_polling.dart';
import '../media_request.dart';

class GoogleMediaRoute {
  const GoogleMediaRoute(this.base, this.auth);

  final String base;
  final Map<String, String> auth;

  static bool globalAvailable(ProviderConfig provider) {
    final region = (provider.location ?? '').trim();
    return provider.vertexAI != true || region.isEmpty || region == 'global';
  }

  static final segment = RegExp(r'^[A-Za-z0-9_][A-Za-z0-9_.-]*$');

  static Future<GoogleMediaRoute> resolve(
    MediaContext context, {
    String? apiBase,
    bool interactions = false,
    bool globalByDefault = false,
  }) async {
    final provider = context.provider;
    if (provider.vertexAI != true) {
      return GoogleMediaRoute(apiBase ?? provider.baseUrl, {
        'x-goog-api-key': context.apiKey,
      });
    }
    final project = _project(provider);
    final location = (provider.location ?? '').trim();
    final region = location.isEmpty
        ? (interactions || globalByDefault ? 'global' : 'us-central1')
        : location;
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
    final origin = providerVertexOrigin(provider, region);
    final parent = '$origin/v1/projects/$project/locations/$region';
    return GoogleMediaRoute(
      interactions ? parent : '$parent/publishers/google',
      {'Authorization': 'Bearer $token'},
    );
  }

  Uri? resultUri(Object? value) {
    if (value is! String) return null;
    final gs = Uri.tryParse(value);
    if (gs != null &&
        gs.scheme == 'gs' &&
        gs.host.isNotEmpty &&
        gs.path.length > 1) {
      return Uri(
        scheme: 'https',
        host: 'storage.googleapis.com',
        pathSegments: [
          'storage',
          'v1',
          'b',
          gs.host,
          'o',
          gs.pathSegments.join('/'),
        ],
        queryParameters: {'alt': 'media'},
      );
    }
    final uri = mediaResultUri(value);
    if (uri == null) return null;
    if (uri.origin == Uri.parse(base).origin &&
        RegExp(r'/v1(?:beta)?/files/[^/:]+$').hasMatch(uri.path)) {
      return uri.replace(
        path: '${uri.path}:download',
        queryParameters: {...uri.queryParameters, 'alt': 'media'},
      );
    }
    return uri;
  }

  Map<String, String> resultHeaders(
    Uri url, {
    required bool vertex,
    required Map<String, String> headers,
  }) {
    final api = Uri.parse(base);
    if (url.origin == api.origin) return headers;
    return vertex &&
            shouldAttachVertexMediaAuth(api) &&
            shouldAttachVertexMediaAuth(url)
        ? auth
        : const {};
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
  return (
    mime: mimeFromPath(reference.path),
    base64: await mediaReferenceBase64(reference),
  );
}
