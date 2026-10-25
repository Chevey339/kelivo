import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:markstream/markstream.dart';

import 'markstream_view_test.dart' show host;

class _Links implements LinkHandler {
  final opened = <String>[];
  @override
  void open(BuildContext context, LinkNode node) =>
      opened.add(node.destination);
}

class _Images implements ImageBuilder {
  var opened = 0;
  @override
  Widget build(BuildContext context, ImageNode image, MarkstreamTheme theme) =>
      GestureDetector(
        onTap: () => opened++,
        child: const SizedBox(
          key: ValueKey('image'),
          width: 60,
          height: 40,
          child: ColoredBox(color: Colors.blue),
        ),
      );
}

void main() {
  testWidgets(
    'linked image opens its enclosing URL and keeps source selection',
    (tester) async {
      final links = _Links(), images = _Images();
      String? selected;
      await tester.pumpWidget(
        host(
          MarkstreamView(
            source: 'Before [![alt](image.png)](https://target.test) After',
            imageBuilder: images,
            linkHandler: links,
          ),
          selectable: true,
          onSelection: (value) => selected = value?.plainText,
        ),
      );
      await tester.pumpAndSettle();
      // The image's own recognizer is deliberately ignored inside a link.
      await tester.tapAt(tester.getCenter(find.byKey(const ValueKey('image'))));
      await tester.pumpAndSettle();
      expect(links.opened, ['https://target.test']);
      expect(images.opened, 0);
      tester
          .state<SelectableRegionState>(find.byType(SelectableRegion))
          .selectAll(SelectionChangedCause.keyboard);
      await tester.pumpAndSettle();
      expect(selected, 'Before alt After');
    },
  );
  testWidgets(
    'code and image links expose the click cursor inside a selection area',
    (tester) async {
      final links = _Links();
      await tester.pumpWidget(
        host(
          MarkstreamView(
            source: '[`code`](https://code.test) [![alt](image.png)](https://image.test)',
            imageBuilder: _Images(),
            linkHandler: links,
          ),
          selectable: true,
        ),
      );
      await tester.pumpAndSettle();
      final mouse = await tester.createGesture(
        kind: ui.PointerDeviceKind.mouse,
      );
      await mouse.addPointer(location: Offset.zero);
      for (final target in [
        find.byType(InlineCodeCapsule),
        find.byKey(const ValueKey('image')),
      ]) {
        await mouse.moveTo(tester.getCenter(target));
        await tester.pump();
        expect(
          RendererBinding.instance.mouseTracker.debugDeviceActiveCursor(
            1, // TestGesture mouse device ID.
          ),
          SystemMouseCursors.click,
        );
      }
      await mouse.removePointer();
    },
  );
}
