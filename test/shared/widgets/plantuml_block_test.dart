import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:Kelivo/shared/widgets/plantuml_block.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

const _plantUmlCode = '''
@startuml
Alice -> Bob: hello
@enduml
''';

const _svg = '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 20 20">
  <rect x="2" y="2" width="16" height="16"/>
</svg>
''';

Widget _plantUmlHarness({double? width}) {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: width == null
          ? const PlantUMLBlock(code: _plantUmlCode)
          : Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: width,
                child: const PlantUMLBlock(code: _plantUmlCode),
              ),
            ),
    ),
  );
}

Future<void> _runWithSvgHttpClient(Future<void> Function() body) {
  return http.runWithClient(
    body,
    () => MockClient((request) async {
      return http.Response(
        _svg,
        200,
        headers: const {'content-type': 'image/svg+xml'},
      );
    }),
  );
}

void main() {
  testWidgets('PlantUMLBlock frames image in Mermaid-style preview shell', (
    tester,
  ) async {
    await _runWithSvgHttpClient(() async {
      await tester.pumpWidget(_plantUmlHarness());
      await tester.pump();

      expect(find.text('Image'), findsOneWidget);
      expect(find.text('Code'), findsOneWidget);
      expect(find.text('Copy'), findsNothing);
      expect(find.text('Open Preview'), findsNothing);
      expect(find.byTooltip('Copy'), findsOneWidget);
      expect(find.byTooltip('Open Preview'), findsOneWidget);
      expect(
        tester
            .getSize(find.byKey(const ValueKey('preview-body')))
            .height,
        406,
      );
      expect(find.textContaining('@startuml'), findsNothing);
    });
  });

  testWidgets('PlantUMLBlock pins actions to trailing edge on wide layouts', (
    tester,
  ) async {
    await _runWithSvgHttpClient(() async {
      await tester.pumpWidget(_plantUmlHarness(width: 800));
      await tester.pump();

      final bodyRight = tester
          .getTopRight(find.byKey(const ValueKey('preview-body')))
          .dx;
      final openRight = tester.getTopRight(find.byTooltip('Open Preview')).dx;

      expect(bodyRight - openRight, lessThanOrEqualTo(14));
    });
  });

  testWidgets('PlantUMLBlock toggles image and code tabs', (tester) async {
    await _runWithSvgHttpClient(() async {
      await tester.pumpWidget(_plantUmlHarness());
      await tester.pump();

      await tester.tap(find.text('Code'));
      await tester.pump(const Duration(milliseconds: 220));

      expect(find.textContaining('@startuml'), findsOneWidget);

      await tester.tap(find.text('Image'));
      await tester.pump(const Duration(milliseconds: 220));

      expect(find.textContaining('@startuml'), findsNothing);
    });
  });
}
