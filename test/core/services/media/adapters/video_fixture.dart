import 'dart:convert';

import 'package:Kelivo/core/models/media_creation.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/core/services/media/media_adapter.dart';
import 'package:Kelivo/core/services/media/media_request.dart';
import 'package:dio/dio.dart';
import 'package:http/http.dart' as http;

MediaContext videoContext(ProviderConfig provider, http.Client client) =>
    MediaContext(
      provider: provider,
      client: client,
      apiKey: 'fixture-key',
      cancelToken: CancelToken(),
      requestId: 'fixture',
      delay: (_) async {},
    );

ProviderConfig videoProvider(String base, String model) => ProviderConfig(
  id: 'video-fixture',
  name: 'Video fixture',
  enabled: true,
  apiKey: 'fixture-key',
  baseUrl: base,
  models: [model],
);

http.Response videoJson(Map<String, dynamic> data, [int status = 200]) =>
    http.Response(jsonEncode(data), status);

MediaRequest videoRequest(
  String model, {
  List<MediaReference> frames = const [],
  Map<String, dynamic> parameters = const {},
}) => MediaRequest(
  modelId: model,
  mode: MediaMode.video,
  prompt: 'Sunlight on a garden',
  durationSec: 8,
  resolution: '720p',
  aspectRatio: '16:9',
  references: frames,
  parameters: parameters,
);
