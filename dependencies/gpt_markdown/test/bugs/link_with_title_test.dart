// Regression test for: Link with title attribute
// GitHub Issue: (to be filed)
//
// BUG CONFIRMED: Links with title attributes in the format [text](url "title")
// are NOT parsed as links. The entire markdown syntax is rendered as plain text.
//
// Input: [Link Text](/path/to/page "Link Title")
// Expected: Link should render with text "Link Text" pointing to URL
// Actual: Renders as literal text "[Link Text](/path/to/page "Link Title")"
//
// Root cause: The ATagMd regex in markdown_component.dart does not account
// for the optional title attribute in link syntax.

import 'package:flutter_test/flutter_test.dart';
import '../utils/test_helpers.dart';

void main() {
  group('Link with title attribute', () {
    testWidgets(
      'link with quoted title is parsed correctly '
      '[BUG: ATagMd regex does not support title attribute]',
      skip: true,
      (tester) async {
        await pumpMarkdown(tester, '[Link Text](/path/to/page "Link Title")');
        final output = getSerializedOutput(tester);

        // The link should be recognized and rendered
        expect(output, contains('LINK'));
        expect(output, contains('Link Text'));
      },
    );

    testWidgets(
      'link with title in sentence context '
      '[BUG: ATagMd regex does not support title attribute]',
      skip: true,
      (tester) async {
        await pumpMarkdown(
          tester,
          'Check out [Projects](/page/projects "Project Overview") for more info.',
        );
        final output = getSerializedOutput(tester);

        // The link should be recognized
        expect(output, contains('LINK'));
        expect(output, contains('Projects'));
        // Surrounding text should be present
        expect(output, contains('Check out'));
        expect(output, contains('for more info'));
      },
    );

    testWidgets(
      'link with title containing special characters '
      '[BUG: ATagMd regex does not support title attribute]',
      skip: true,
      (tester) async {
        await pumpMarkdown(
          tester,
          '[Features](/features "App Features: Overview")',
        );
        final output = getSerializedOutput(tester);

        expect(output, contains('LINK'));
        expect(output, contains('Features'));
      },
    );

    testWidgets(
      'multiple links with titles '
      '[BUG: ATagMd regex does not support title attribute]',
      skip: true,
      (tester) async {
        await pumpMarkdown(
          tester,
          '[First](/a "Title A") and [Second](/b "Title B")',
        );
        final output = getSerializedOutput(tester);

        // Both links should be recognized
        expect(output, contains('LINK'));
        expect(output, contains('and'));
      },
    );
  });
}
