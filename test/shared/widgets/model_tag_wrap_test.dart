import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:Kelivo/core/models/model_spec.dart';
import 'package:Kelivo/icons/lucide_adapter.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:Kelivo/shared/widgets/model_tag_wrap.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> pumpWrap(WidgetTester tester, ModelSpec spec) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        home: Scaffold(body: ModelTagWrap(model: spec)),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('image type uses the image label', (tester) async {
    await pumpWrap(
      tester,
      ModelSpec(id: 'img', displayName: 'Img', type: ModelType.image),
    );
    expect(find.text('Image'), findsOneWidget);
    expect(find.text('Chat'), findsNothing);
  });

  testWidgets('context window capsule uses compact token text', (tester) async {
    await pumpWrap(
      tester,
      ModelSpec(id: 'ctx', displayName: 'Ctx', contextWindow: 128000),
    );
    expect(find.text('128k'), findsOneWidget);
  });

  testWidgets('audio input icon is present', (tester) async {
    await pumpWrap(
      tester,
      ModelSpec(
        id: 'audio',
        displayName: 'Audio',
        input: const [Modality.text, Modality.audio],
      ),
    );
    expect(find.byIcon(Lucide.AudioLines), findsOneWidget);
  });
}
