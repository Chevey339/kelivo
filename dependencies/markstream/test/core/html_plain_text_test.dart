import 'package:flutter_test/flutter_test.dart';
import 'package:markstream/markstream_core.dart';

void main() {
  test(
    'HTML structural plain text separates flow, lists and rectangular cells',
    () {
      final doc = const MarkdownParser().parse(
        '<div><p>One</p><p>Two</p><ol start="4"><li>A</li><li>B</li></ol><table><tr><td></td><td>X</td><td></td></tr><tr><td></td><td></td><td></td></tr></table></div>',
      );
      expect(toPlainText(doc), 'One\n\nTwo\n\n4. A\n5. B\n\n\tX\t\n\t\t');
    },
  );
}
