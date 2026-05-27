import 'package:flutter_test/flutter_test.dart';

import 'package:Kelivo/core/services/model_override_payload_parser.dart';

void main() {
  group('ModelOverridePayloadParser.customHeaders', () {
    test('parses map-style headers from imported provider configs', () {
      final headers = ModelOverridePayloadParser.customHeaders(
        const <String, dynamic>{
          'headers': <String, String>{
            'User-Agent':
                'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) CherryStudio/1.7.13 Chrome/140.0.7339.249 Electron/38.7.0 Safari/537.36',
          },
        },
      );

      expect(headers, containsPair('User-Agent', startsWith('Mozilla/5.0')));
      expect(headers['User-Agent'], contains('CherryStudio/1.7.13'));
    });

    test('keeps supporting list-style headers from the app editor', () {
      final headers = ModelOverridePayloadParser.customHeaders(
        const <String, dynamic>{
          'headers': <Map<String, String>>[
            {'name': 'X-Test', 'value': 'ok'},
          ],
        },
      );

      expect(headers, {'X-Test': 'ok'});
    });
  });
}
