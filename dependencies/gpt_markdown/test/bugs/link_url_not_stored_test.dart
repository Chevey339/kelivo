/// BUG: LinkButton.url property is not populated when links are created
///
/// The LinkButton widget has a `url` property, but it is never set when
/// creating LinkButton instances in markdown_component.dart. The URL is
/// only captured in the onPressed closure, making it inaccessible for
/// inspection or testing.
///
/// Location: lib/markdown_component.dart, ATagMd.build() method
/// The LinkButton constructor call is missing: url: url
library;

import 'package:flutter_test/flutter_test.dart';
import '../utils/test_helpers.dart';

void main() {
  group('Regression: Link URL not stored in LinkButton widget', () {
    testWidgets(
      'link URL should be accessible in serialized output '
      '[BUG: LinkButton.url not populated in ATagMd.build()]',
      skip: true,
      (tester) async {
        await pumpMarkdown(tester, '[click here](https://example.com)');
        final output = getSerializedOutput(tester);

        // BUG: This test fails because the URL is not passed to LinkButton
        // Expected: LINK("click here", url="https://example.com")
        // Actual: LINK("click here")
        expect(
          output,
          contains('LINK("click here", url="https://example.com")'),
        );
      },
    );

    testWidgets(
      'link with path should include full URL '
      '[BUG: LinkButton.url not populated in ATagMd.build()]',
      skip: true,
      (tester) async {
        await pumpMarkdown(tester, '[docs](https://example.com/docs/page)');
        final output = getSerializedOutput(tester);

        // BUG: URL is not included in the output
        expect(
          output,
          contains('LINK("docs", url="https://example.com/docs/page")'),
        );
      },
    );
  });
}
