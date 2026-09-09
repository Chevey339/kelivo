import 'package:flutter_test/flutter_test.dart';
import 'package:terminal_view/src/core/tabs.dart';

void main() {
  group('TabStops', () {
    test('has default tab stops after created', () {
      final tabStops = TabStops();

      expect(tabStops.isSetAt(0), true);
      expect(tabStops.isSetAt(1), false);
      expect(tabStops.isSetAt(7), false);
      expect(tabStops.isSetAt(8), true);
      expect(tabStops.isSetAt(9), false);
      expect(tabStops.isSetAt(15), false);
      expect(tabStops.isSetAt(16), true);
    });
  });

  group('TabStops.find()', () {
    test('includes start', () {
      final tabStops = TabStops();
      expect(tabStops.find(0, 10), 0);
    });

    test('excludes end', () {
      final tabStops = TabStops();
      expect(tabStops.find(0, 8), 0);
      expect(tabStops.find(1, 9), 8);
    });
  });
}
