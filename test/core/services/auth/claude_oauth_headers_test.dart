import 'package:Kelivo/core/services/auth/claude_oauth_request.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

void main() {
  test('replaces all header casing variants in an ordinary map', () {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Anthropic-Beta': 'old-beta',
      'ANTHROPIC-BETA': 'another-beta',
    };

    setClaudeOAuthHeader(headers, 'anthropic-beta', 'new-beta');

    expect(headers, {
      'Content-Type': 'application/json',
      'anthropic-beta': 'new-beta',
    });
  });

  test('repeatedly replaces request headers without corrupting the map', () {
    final request = http.Request('POST', Uri.parse('https://example.com'));
    request.headers.addAll({
      'Content-Type': 'application/json',
      'Anthropic-Beta': 'old-beta',
    });

    for (final value in ['new-beta', 'retry-beta']) {
      setClaudeOAuthHeader(request.headers, 'anthropic-beta', value);

      expect(request.headers['ANTHROPIC-BETA'], value);
      expect(request.headers['content-type'], 'application/json');
      expect(request.headers.keys, ['Content-Type', 'anthropic-beta']);
    }
  });
}
