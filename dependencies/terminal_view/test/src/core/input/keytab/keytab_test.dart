import 'package:test/test.dart';
import 'package:terminal_view/src/core/input/keys.dart';
import 'package:terminal_view/src/core/input/keytab/keytab.dart';

void main() {
  group('Keytab.find()', () {
    test('can match keyPad', () {
      final keytab = Keytab.parse(r'key Home +KeyPad : "TEST"');
      final record = keytab.find(TerminalKey.home, keyPad: true);
      expect(record!.action.unescapedValue(), 'TEST');

      final record1 = keytab.find(TerminalKey.home);
      expect(record1, isNull);
    });
  });
}
