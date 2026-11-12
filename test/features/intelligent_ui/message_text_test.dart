import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:Kelivo/core/database/generation_run.dart';
import 'package:Kelivo/core/models/chat_message.dart';
import 'package:Kelivo/core/models/message_part.dart';
import 'package:Kelivo/core/services/tts/tts_text_selection.dart';
import 'package:Kelivo/features/intelligent_ui/catalog/ui_catalog.dart';
import 'package:Kelivo/features/intelligent_ui/catalog/ui_budgets.dart';
import 'package:Kelivo/features/intelligent_ui/host/ui_message_projection.dart';
import 'package:Kelivo/features/intelligent_ui/runtime/ui_surface_controller.dart';
import 'package:Kelivo/features/intelligent_ui/runtime/ui_surface_state.dart';
import 'package:Kelivo/features/intelligent_ui/text/ui_text_projection.dart';
import '../../support/genui_projection_fixture.dart';

const _body = r'''ui 1 catalog "kelivo.native/1"
$a: number = 2
root = Column(children=[input,result])
input = Slider(label="Slope",bind=$a,min=-10,max=10)
result = Metric(label="Double",value=$a*2,unit="km")
''';
const _source = '**Conclusion**\n\n```kelivo-ui\n$_body```\n\nAfter';
ChatMessage _message(
  String text, {
  String role = 'assistant',
  List<MessagePart>? parts,
  GenerationRunState? state = GenerationRunState.completed,
}) {
  final message = ChatMessage(
    id: 'r',
    conversationId: 'c',
    role: role,
    content: text,
    parts: parts,
  );
  message.hydrateGenerationState(state);
  return message;
}

UiSurfaceController _controller(String source) {
  final controller = UiSurfaceController(
    owner: const UiSurfaceOwner(revisionId: 'r', surfaceKey: '0:0'),
  );
  controller.updateSource(
    source,
    closed: true,
    generation: UiGenerationStatus.complete,
  );
  addTearDown(controller.dispose);
  return controller;
}

void main() {
  for (final spec in UiCatalog.components.values) {
    for (final mode in UiTextMode.values) {
      test('${spec.name} projects $mode without source code', () {
        final controller = _controller(spec.example);
        final text = testUiProjection.text(
          controller.captureRead(),
          mode: mode,
        );
        expect(text, isNotEmpty);
        expect(text, isNot(contains(UiCatalog.header)));
        expect(
          utf8.encode(text).length,
          lessThanOrEqualTo(
            mode == UiTextMode.search
                ? UiBudgets.searchTextBytes
                : UiBudgets.copyBytes,
          ),
        );
      });
    }
  }
  test('whole message copy and speech use one frozen accepted batch', () async {
    final controller = _controller(_body);
    controller.setInputs({'a': -3.5}, token: controller.token);
    final snapshot = controller.captureSnapshot();
    final pending = projectUiMessageText(
      _message(_source),
      projection: testUiProjection,
      snapshots: [snapshot],
      blockLimit: 'Too many blocks',
    );
    controller.setInputs({'a': 9}, token: controller.token);
    final result = await pending;
    expect(result.copyText, 'Conclusion\nSlope: -3.5\nDouble: -7 km\nAfter');
    expect(
      result.speech(TtsTextSelectionMode.fullText),
      contains('Double: -7 km'),
    );
    expect(
      result.speech(TtsTextSelectionMode.fullText),
      isNot(contains('root =')),
    );
    expect(result.source, _source);
  });
  test(
    'literal UI punctuation survives selection and both speech cleanups',
    () async {
      const value =
          '-3 `kept` [label](https://example.invalid) *multiply* _unit_';
      final source =
          '${UiCatalog.header}\nroot = Text(text=${jsonEncode(value)})\n';
      final message = _message(
        '**Normal** `removed`\n\n```kelivo-ui\n$source```',
      );
      final result = await projectUiMessageText(
        message,
        projection: testUiProjection,
        blockLimit: 'Too many blocks',
      );
      final speech = result.speech(TtsTextSelectionMode.fullText);
      expect(speech, 'Normal $value');
      expect(result.copyText, contains(value));
    },
  );
  test(
    'invalid and interrupted blocks have diagnostics, never narrated DSL',
    () async {
      for (final item in [
        _message('Before\n```kelivo-ui\nui 99 catalog "wrong"\n```\nAfter'),
        _message(
          '```kelivo-ui\n${UiCatalog.header}\nroot = Column(children=[future])\n',
          state: GenerationRunState.interrupted,
        ),
      ]) {
        final result = await projectUiMessageText(
          item,
          projection: testUiProjection,
          blockLimit: 'Too many blocks',
        );
        expect(result.hasUi, isTrue);
        expect(result.copyText, isNot(contains('root =')));
        expect(result.copyText, isNot(contains('catalog')));
        expect(result.copyText, anyOf(contains('Error:'), contains('Waiting')));
      }
    },
  );
  test('only original eligible assistant fences are projected', () async {
    for (final item in [
      _message(_source, role: 'user'),
      _message(_source, role: 'tool'),
      _message('> ```kelivo-ui\n> $_body\n> ```'),
      _message('<think>\n```kelivo-ui\n$_body```\n</think>'),
      _message(
        '',
        parts: const [
          TextPart('```kelivo-'),
          ImagePart(uri: 'boundary.png'),
          TextPart('ui\n$_body```'),
        ],
      ),
    ]) {
      final result = await projectUiMessageText(
        item,
        projection: testUiProjection,
        blockLimit: 'Too many blocks',
      );
      expect(result.hasUi, isFalse);
      expect(result.copyText, item.content);
    }
  });
  test('adjacent text parts retain original surface identity', () async {
    final item = _message(
      '',
      parts: const [TextPart('```kelivo-'), TextPart('ui\n$_body```')],
    );
    final controller = _controller(_body);
    controller.setInputs({'a': 4}, token: controller.token);
    final result = await projectUiMessageText(
      item,
      projection: testUiProjection,
      snapshots: [controller.captureSnapshot()],
      blockLimit: 'Too many blocks',
    );
    expect(result.copyText, contains('Double: 8 km'));
  });
  test('copy has a 64 KiB aggregate UTF8 limit and visible omission', () async {
    final body =
        '${UiCatalog.header}\nroot = Text(text=${jsonEncode('界' * 18000)})\n';
    final item = _message(
      List.filled(4, '```kelivo-ui\n$body```').join('\n\n'),
    );
    final result = await projectUiMessageText(
      item,
      projection: testUiProjection,
      blockLimit: 'Too many blocks',
    );
    expect(
      utf8.encode(result.copyText).length,
      lessThanOrEqualTo(UiBudgets.copyBytes),
    );
    expect(
      utf8.encode(result.speech(TtsTextSelectionMode.fullText)).length,
      lessThanOrEqualTo(UiBudgets.copyBytes),
    );
    expect(result.copyText, contains('Some fields omitted'));
    expect(result.copyText, contains('Too many blocks'));
  });
}
