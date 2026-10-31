import 'package:Kelivo/features/chat/widgets/viewport_block_list.dart';
import 'package:Kelivo/shared/widgets/export_capture_scope.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'export capture materializes the full source inside a scrollable',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: ExportCaptureScope(
                enabled: true,
                child: ViewportBlockList(
                  itemCount: 100,
                  structureToken: 100,
                  itemKey: (i) => i,
                  estimateExtent: (i, width) => 40,
                  itemBuilder: (context, i) =>
                      SizedBox(height: 40, child: Text('export-$i')),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('export-0'), findsOneWidget);
      expect(find.text('export-99'), findsOneWidget);
      expect(find.byType(Text), findsNWidgets(100));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    '5000 blocks share one scrollable and mount only the viewport range',
    (tester) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);
      var mounted = 0;
      var peak = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              controller: controller,
              child: ViewportBlockList(
                itemCount: 5000,
                structureToken: 5000,
                itemKey: (i) => i,
                estimateExtent: (i, width) => 40,
                keepAlive: (i) => i == 0,
                itemBuilder: (context, i) => _Probe(
                  key: ValueKey('block-$i'),
                  onMount: () {
                    mounted++;
                    if (mounted > peak) peak = mounted;
                  },
                  onDispose: () => mounted--,
                  label: '$i',
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(Scrollable), findsOneWidget);
      expect(mounted, lessThan(100));
      expect(find.text('0'), findsOneWidget);
      controller.jumpTo(120000);
      await tester.pumpAndSettle();
      expect(find.text('3000'), findsOneWidget);
      expect(find.text('0'), findsOneWidget); // active input is retained
      expect(find.text('1'), findsNothing);
      expect(mounted, lessThan(100));
      controller.jumpTo(controller.position.maxScrollExtent);
      await tester.pumpAndSettle();
      expect(find.text('4999'), findsOneWidget);
      controller.jumpTo(0);
      await tester.pumpAndSettle();
      expect(find.text('1'), findsOneWidget);
      expect(peak, lessThan(150));
      expect(tester.takeException(), isNull);
    },
  );
}

class _Probe extends StatefulWidget {
  const _Probe({
    super.key,
    required this.onMount,
    required this.onDispose,
    required this.label,
  });
  final VoidCallback onMount, onDispose;
  final String label;
  @override
  State<_Probe> createState() => _ProbeState();
}

class _ProbeState extends State<_Probe> {
  @override
  void initState() {
    super.initState();
    widget.onMount();
  }

  @override
  void dispose() {
    widget.onDispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      SizedBox(height: 40, child: Text(widget.label));
}
