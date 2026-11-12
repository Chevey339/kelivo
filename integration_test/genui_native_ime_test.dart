import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:Kelivo/features/intelligent_ui/widgets/genui_surface.dart';
import 'package:Kelivo/features/intelligent_ui/widgets/genui_text_input.dart';
import 'package:Kelivo/shared/widgets/ios_tactile.dart';
import '../test/support/genui_scenario_host.dart';
import '../test/support/message_test_services.dart';

/// Manual native keyboard acceptance. A host operator/UI driver uses the real
/// keyboard after each identified READY line. No TestTextInput or app bridge.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.shouldPropagateDevicePointerEvents = true;
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;
  testWidgets(
    'real bilingual IME in a native generated form',
    (tester) async {
      final directory = await Directory.systemTemp.createTemp(
        'genui-native-ime-',
      );
      final session = await GenUiScenarioSession.open(
        File('${directory.path}/ime.sqlite'),
      );
      final services = await MessageTestServices.open();
      final key = GlobalKey<GenUiScenarioHostState>();
      final phases = <String>[];
      var externalPreeditObserved = false;
      var receivedComposingRange = false;
      var englishComposingRange = false;
      var externalPreeditConfirmedAfterAppearance = false;
      bool keyboardPhaseSignal(KeyEvent event) {
        if (event is KeyDownEvent &&
            event.logicalKey == LogicalKeyboardKey.f8) {
          externalPreeditObserved = true;
          return true;
        }
        return false;
      }

      HardwareKeyboard.instance.addHandler(keyboardPhaseSignal);
      Future<void> until(bool Function() ready, String reason) async {
        final limit = DateTime.now().add(const Duration(minutes: 5));
        while (!ready() && DateTime.now().isBefore(limit)) {
          await tester.pump(const Duration(milliseconds: 100));
        }
        expect(ready(), isTrue, reason: reason);
      }

      Finder field(String id) => find.descendant(
        of: find.byWidgetPredicate((w) => w is GenUiTextInput && w.id == id),
        matching: find.byType(TextField),
      );
      void ready(String phase, String instructions) {
        // ignore: avoid_print
        print(
          'GENUI_IME_READY ${jsonEncode({'phase': phase, 'instructions': instructions, 'platform': Platform.operatingSystem})}',
        );
      }

      try {
        await until(() => !tester.view.physicalSize.isEmpty, 'Native viewport');
        await tester.pumpWidget(
          GenUiScenarioHost(
            key: key,
            session: session,
            services: services,
            scene: 'S5',
          ),
        );
        await tester.pumpAndSettle();
        final expand = find.byWidgetPredicate(
          (w) => w is IosIconButton && w.tooltip == 'Expand',
        );
        await tester.ensureVisible(expand);
        await tester.tap(expand);
        await tester.pumpAndSettle();
        final surface = tester
            .widget<GenUiSurface>(find.byType(GenUiSurface))
            .controller;
        await tester.tap(field('nameInput'));
        await tester.pump(const Duration(seconds: 1));
        final editing = tester
            .widget<TextField>(field('nameInput'))
            .controller!;
        ready(
          'compose',
          'Type ni in the real Chinese Pinyin keyboard without committing. If this IME keeps preedit only in its candidate bar, visually verify it and press native F8 to acknowledge that separate observation.',
        );
        await until(
          () =>
              (editing.value.composing.isValid &&
                  !editing.value.composing.isCollapsed) ||
              externalPreeditObserved,
          'Real IME composition did not arrive',
        );
        expect(surface.captureRead().inputs['name'], '');
        receivedComposingRange =
            editing.value.composing.isValid &&
            !editing.value.composing.isCollapsed;
        if (!receivedComposingRange) expect(editing.text, isEmpty);
        final composing = editing.value;
        await tester.pumpWidget(
          GenUiScenarioHost(
            key: key,
            session: session,
            services: services,
            scene: 'S5',
            dark: true,
            scale: 1.3,
          ),
        );
        await tester.pumpAndSettle();
        expect(
          tester.widget<TextField>(field('nameInput')).controller,
          same(editing),
        );
        expect(editing.value, composing);
        expect(surface.captureRead().inputs['name'], '');
        expect(
          Theme.of(tester.element(field('nameInput'))).brightness,
          Brightness.dark,
        );
        expect(
          MediaQuery.textScalerOf(tester.element(field('nameInput'))).scale(1),
          1.3,
        );
        if (!receivedComposingRange) {
          externalPreeditObserved = false;
          ready(
            'confirm_external_preedit',
            'Verify ni is still in the native candidate bar after the appearance change. Do not retype. Press native F8 only if it is still present; otherwise fail this acceptance.',
          );
          await until(
            () => externalPreeditObserved,
            'External preedit was not confirmed after the appearance change',
          );
          externalPreeditConfirmedAfterAppearance = true;
        }
        phases.add(
          receivedComposingRange
              ? 'composing-range-survives-theme-and-scale'
              : 'external-candidate-preedit-survives-theme-and-scale',
        );

        ready(
          'commit',
          receivedComposingRange
              ? 'Finish typing ni if needed, then select the native candidate 你.'
              : 'Select the existing native candidate 你 without retyping ni.',
        );
        await until(
          () => surface.captureRead().inputs['name'] == '你',
          'Chinese candidate was not committed',
        );
        expect(editing.value.composing.isCollapsed, isTrue);
        expect(key.currentState!.requests, 0);
        phases.add('chinese-commit');

        ready(
          'english',
          'Switch the real keyboard to English and type abc after 你. Leave any underlined candidate uncommitted for the appearance-preservation check.',
        );
        await until(
          () => editing.text == '你abc',
          'Real English text did not arrive',
        );
        if (editing.value.composing.isValid &&
            !editing.value.composing.isCollapsed) {
          englishComposingRange = true;
          expect(surface.captureRead().inputs['name'], '你');
          final composingEnglish = editing.value;
          await tester.pumpWidget(
            GenUiScenarioHost(
              key: key,
              session: session,
              services: services,
              scene: 'S5',
            ),
          );
          await tester.pumpAndSettle();
          expect(
            tester.widget<TextField>(field('nameInput')).controller,
            same(editing),
          );
          expect(editing.value, composingEnglish);
          expect(surface.captureRead().inputs['name'], '你');
          expect(
            Theme.of(tester.element(field('nameInput'))).brightness,
            Brightness.light,
          );
          expect(
            MediaQuery.textScalerOf(
              tester.element(field('nameInput')),
            ).scale(1),
            1,
          );
          phases.add('english-composing-range-survives-theme-and-scale');
        }
        ready(
          'english_commit',
          'Choose the literal abc candidate, if still underlined, without submitting the form.',
        );
        await until(
          () => surface.captureRead().inputs['name'] == '你abc',
          'English input was not committed',
        );
        phases.add('english-commit');
        ready(
          'select_all',
          'Use the native text selection menu or keyboard to select all four characters.',
        );
        await until(
          () =>
              editing.selection.start == 0 &&
              editing.selection.end == editing.text.length &&
              !editing.selection.isCollapsed,
          'Native select-all did not reach the field',
        );
        phases.add('native-selection');
        ready(
          'replace',
          'Type kelivo with the real English keyboard to replace the selection.',
        );
        await until(
          () => surface.captureRead().inputs['name'] == 'kelivo',
          'Native replacement did not preserve selection semantics',
        );
        phases.add('native-replacement');

        await tester.tap(find.text('Company invoice'));
        await tester.pumpAndSettle();
        surface.setInputs({'detail': ''}, token: surface.token);
        await tester.pump();
        await tester.ensureVisible(field('detailInput'));
        await tester.tap(field('detailInput'));
        await tester.pump(const Duration(seconds: 1));
        ready('multiline', 'In the real keyboard type a, Return, then b.');
        await until(
          () => surface.captureRead().inputs['detail'] == 'a\nb',
          'Multiline Return did not insert a newline',
        );
        expect(key.currentState!.requests, 0);
        phases.add('multiline-newline-no-submit');
        final report = {
          'platform': Platform.operatingSystem,
          'os': Platform.operatingSystemVersion,
          'phases': phases,
          'input': 'Real native keyboard; no TestTextInput',
          'receivedComposingRange': receivedComposingRange,
          'englishComposingRange': englishComposingRange,
          'externalPreeditObservation': externalPreeditObserved,
          'externalPreeditConfirmedAfterAppearance':
              externalPreeditConfirmedAfterAppearance,
        };
        binding.reportData = report;
        // ignore: avoid_print
        print('GENUI_IME_RESULT ${jsonEncode(report)}');
      } finally {
        HardwareKeyboard.instance.removeHandler(keyboardPhaseSignal);
        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
        await session.close();
        await services.close();
        await directory.delete(recursive: true);
      }
    },
    // Follow the operating system's accessibility state. The widget-test default
    // creates a Dart-only semantics handle before the native bridge exists; a
    // later macOS AX client can then receive an incremental tree as its first
    // snapshot. This does not disable native semantics or screen-reader access.
    semanticsEnabled: false,
    timeout: const Timeout(Duration(minutes: 15)),
  );
}
