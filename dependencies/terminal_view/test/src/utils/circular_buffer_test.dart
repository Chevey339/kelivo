import 'package:flutter_test/flutter_test.dart';
import 'package:terminal_view/src/utils/circular_buffer.dart';

class IndexedValue<T> with IndexedItem {
  T value;

  IndexedValue(this.value);

  @override
  int get hashCode => value.hashCode;

  @override
  bool operator ==(Object other) {
    if (other is IndexedValue) {
      return other.value == value;
    }
    if (other is T) {
      return other == value;
    }
    return false;
  }

  @override
  String toString() {
    return 'IndexedValue($value), index: ${attached ? index : null}}';
  }
}

extension ToIndexedValue<T> on T {
  IndexedValue<T> get indexed => IndexedValue(this);
}

void main() {
  group("IndexAwareCircularBuffer", () {
    test("normal creation test", () {
      final cl = IndexAwareCircularBuffer<IndexedValue<int>>(1000);

      expect(cl, isNotNull);
      expect(cl.maxLength, 1000);
    });

    test("change max value", () {
      final cl = IndexAwareCircularBuffer<IndexedValue<int>>(2000);
      expect(cl.maxLength, 2000);
      cl.maxLength = 3000;
      expect(cl.maxLength, 3000);
    });

    test("circle works", () {
      final cl = IndexAwareCircularBuffer<IndexedValue<int>>(10);
      expect(cl.maxLength, 10);
      cl.pushAll(
        List<int>.generate(10, (index) => index).map(IndexedValue.new),
      );

      expect(cl.length, 10);
      expect(cl[0], 0.indexed);
      expect(cl[9], 9.indexed);

      cl.push(IndexedValue(10));

      expect(cl.length, 10);
      expect(cl[0], 1.indexed);
      expect(cl[9], 10.indexed);
    });

    test("change max value after circle", () {
      final cl = IndexAwareCircularBuffer<IndexedValue<int>>(10);
      cl.pushAll(
        List<int>.generate(15, (index) => index).map(IndexedValue.new),
      );

      expect(cl.length, 10);
      expect(cl[0], 5.indexed);
      expect(cl[9], 14.indexed);

      cl.maxLength = 20;

      expect(cl.length, 10);
      expect(cl[0], 5.indexed);
      expect(cl[9], 14.indexed);

      cl.pushAll(
        List<int>.generate(5, (index) => 15 + index).map(IndexedValue.new),
      );

      expect(cl[0], 5.indexed);
      expect(cl[9], 14.indexed);
      expect(cl[14], 19.indexed);
    });

    // test("setting the length erases trail", () {
    //   final cl = CircularList<Box<int>>(10);
    //   cl.pushAll(List<int>.generate(10, (index) => index).map(Box.new));

    //   expect(cl.length, 10);
    //   expect(cl[0], 0.box);
    //   expect(cl[9], 9.box);

    //   cl.length = 5;

    //   expect(cl.length, 5);
    //   expect(cl[0], 0.box);
    //   expect(() => cl[5], throwsRangeError);
    // });

    test("foreach works", () {
      final cl = IndexAwareCircularBuffer<IndexedValue<int>>(10);
      cl.pushAll(
        List<int>.generate(10, (index) => index).map(IndexedValue.new),
      );

      final collectedItems = List<int>.empty(growable: true);

      cl.forEach((item) {
        collectedItems.add(item.value);
      });

      expect(collectedItems.length, 10);
      expect(collectedItems[0], 0);
      expect(collectedItems[9], 9);
    });

    test("index operator set works", () {
      final cl = IndexAwareCircularBuffer<IndexedValue<int>>(10);
      cl.pushAll(
        List<int>.generate(10, (index) => index).map(IndexedValue.new),
      );

      expect(cl.length, 10);
      expect(cl[5], 5.indexed);

      cl[5] = IndexedValue(50);

      expect(cl[5], 50.indexed);
    });

    test("clear works", () {
      final cl = IndexAwareCircularBuffer<IndexedValue<int>>(10);
      cl.pushAll(
        List<int>.generate(10, (index) => index).map(IndexedValue.new),
      );
      expect(cl[5], 5.indexed);

      cl.clear();

      expect(cl.length, 0);
      expect(() => cl[5], throwsRangeError);
    });

    test("pop works", () {
      final cl = IndexAwareCircularBuffer<IndexedValue<int>>(10);
      cl.pushAll(
        List<int>.generate(10, (index) => index).map(IndexedValue.new),
      );
      expect(cl.length, 10);
      expect(cl[9], 9.indexed);

      final val = cl.pop();

      expect(val, 9.indexed);
      expect(cl.length, 9);
      expect(() => cl[9], throwsRangeError);
      expect(cl[8], 8.indexed);
    });

    test("pop on empty throws", () {
      final cl = IndexAwareCircularBuffer<IndexedValue<int>>(10);
      expect(() => cl.pop(), throwsA(anything));
    });

    test("remove one works", () {
      final cl = IndexAwareCircularBuffer<IndexedValue<int>>(10);
      cl.pushAll(
        List<int>.generate(10, (index) => index).map(IndexedValue.new),
      );
      expect(cl.length, 10);
      expect(cl[5], 5.indexed);

      cl.remove(5);

      expect(cl.length, 9);
      expect(cl[5], 6.indexed);
    });

    test("remove multiple works", () {
      final cl = IndexAwareCircularBuffer<IndexedValue<int>>(10);
      cl.pushAll(
        List<int>.generate(10, (index) => index).map(IndexedValue.new),
      );
      expect(cl.length, 10);
      expect(cl[5], 5.indexed);

      cl.remove(5, 3);

      expect(cl.length, 7);
      expect(cl[5], 8.indexed);
    });

    test("remove circle works", () {
      final cl = IndexAwareCircularBuffer<IndexedValue<int>>(10);
      cl.pushAll(
        List<int>.generate(15, (index) => index).map(IndexedValue.new),
      );
      expect(cl.length, 10);
      expect(cl[0], 5.indexed);

      cl.remove(0, 9);

      expect(cl.length, 1);
      expect(cl[0], 14.indexed);
    });

    test("remove too much works", () {
      final cl = IndexAwareCircularBuffer<IndexedValue<int>>(10);
      cl.pushAll(
        List<int>.generate(10, (index) => index).map(IndexedValue.new),
      );
      expect(cl.length, 10);
      expect(cl[5], 5.indexed);

      cl.remove(5, 10);

      expect(cl.length, 5);
      expect(cl[0], 0.indexed);
    });

    test("insert works", () {
      final cl = IndexAwareCircularBuffer<IndexedValue<int>>(10);
      cl.pushAll(
        List<int>.generate(5, (index) => index).map(IndexedValue.new),
      );
      expect(cl.length, 5);
      expect(cl[0], 0.indexed);
      cl.insert(0, IndexedValue(100));

      expect(cl.length, 6);
      expect(cl[0], 100.indexed);
      expect(cl[1], 0.indexed);
    });

    test("insert circular works", () {
      final cl = IndexAwareCircularBuffer<IndexedValue<int>>(10);
      cl.pushAll(
        List<int>.generate(10, (index) => index).map(IndexedValue.new),
      );
      expect(cl.length, 10);
      expect(cl[0], 0.indexed);
      expect(cl[1], 1.indexed);
      expect(cl[9], 9.indexed);

      cl.insert(1, IndexedValue(100));

      expect(cl.length, 10);
      expect(cl[0], 100.indexed); //circle leads to 100 moving one index down
      expect(cl[1], 1.indexed);
    });

    test("insert circular immediately remove works", () {
      final cl = IndexAwareCircularBuffer<IndexedValue<int>>(10);
      cl.pushAll(
        List<int>.generate(10, (index) => index).map(IndexedValue.new),
      );
      expect(cl.length, 10);
      expect(cl[0], 0.indexed);
      expect(cl[1], 1.indexed);
      expect(cl[9], 9.indexed);

      cl.insert(0, IndexedValue(100));

      expect(cl.length, 10);
      expect(cl[0], 0.indexed); //the inserted 100 fell over immediately
      expect(cl[1], 1.indexed);
    });

    test("insert all works", () {
      final cl = IndexAwareCircularBuffer<IndexedValue<int>>(10);
      cl.pushAll(
        List<int>.generate(10, (index) => index).map(IndexedValue.new),
      );
      expect(cl.length, 10);
      expect(cl[0], 0.indexed);
      expect(cl[1], 1.indexed);
      expect(cl[9], 9.indexed);

      cl.insertAll(
        2,
        List<int>.generate(2, (index) => 20 + index)
            .map(IndexedValue.new)
            .toList(),
      );

      expect(cl.length, 10);
      expect(cl[0], 20.indexed);
      expect(cl[1], 21.indexed);
      expect(cl[3], 3.indexed);
      expect(cl[9], 9.indexed);
    });

    test("trim start works", () {
      final cl = IndexAwareCircularBuffer<IndexedValue<int>>(10);
      cl.pushAll(
        List<int>.generate(10, (index) => index).map(IndexedValue.new),
      );
      expect(cl.length, 10);
      expect(cl[0], 0.indexed);
      expect(cl[1], 1.indexed);
      expect(cl[9], 9.indexed);

      cl.trimStart(5);

      expect(cl.length, 5);
      expect(cl[0], 5.indexed);
      expect(cl[1], 6.indexed);
      expect(cl[4], 9.indexed);
    });

    test("trim start with more than length works", () {
      final cl = IndexAwareCircularBuffer<IndexedValue<int>>(10);
      cl.pushAll(
        List<int>.generate(10, (index) => index).map(IndexedValue.new),
      );
      expect(cl.length, 10);
      expect(cl[0], 0.indexed);
      expect(cl[1], 1.indexed);
      expect(cl[9], 9.indexed);

      cl.trimStart(15);

      expect(cl.length, 0);
    });

    test('can track index of items', () {
      final cl = IndexAwareCircularBuffer<IndexedValue<int>>(3);
      final item0 = IndexedValue(0);
      final item1 = IndexedValue(1);
      final item2 = IndexedValue(2);

      cl.pushAll([item0, item1, item2]);

      expect(item0.index, 0);
      expect(item1.index, 1);
      expect(item2.index, 2);

      final item3 = IndexedValue(3);
      cl.push(item3);

      expect(item0.attached, false);
      expect(item1.index, 0);
      expect(item2.index, 1);
      expect(item3.index, 2);

      final item11 = IndexedValue(4);
      cl.insert(1, item11);

      expect(item0.attached, false);
      expect(item1.attached, false);
      expect(item11.index, 0);
      expect(item2.index, 1);
      expect(item3.index, 2);

      cl.remove(0, 2);

      print(cl.debugDump());

      expect(item11.attached, false);
      expect(item2.attached, false);
      expect(item3.index, 0);
    });
  });
}
