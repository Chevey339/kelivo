import 'package:Kelivo/shared/text_input/message_editing_controller.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:Kelivo/shared/widgets/long_message_editor.dart';
import 'controlled_native_message_input.dart';
import 'package:Kelivo/shared/text_input/compact_edit.dart';

class MirrorHarness {
  MirrorHarness(this.tester);
  final WidgetTester tester;
  final bridge = MirrorInputControl();
  late TextEditingController text;
  late TextEditingValue native;
  String session = '';
  int nativeRevision = 0;
  int changes = 0;
  int incomingBytes = 0;
  bool holdAppCommands = false;
  final _held = <_HeldAppCommand>[];
  List<Map<Object?, Object?>> get heldAppCommands =>
      _held.map((e) => e.arguments).toList();
  final commands = <MethodCall>[];
  static const codec = StandardMethodCodec();

  Future<void> mount(
    String source,
    int caret, {
    Widget? otherInput,
    MessageEditingController? document,
  }) async {
    tester.view.physicalSize = const Size(390, 800);
    tester.view.devicePixelRatio = 1;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      bridge.channel,
      (call) async {
        commands.add(call);
        final args = Map<Object?, Object?>.from(call.arguments as Map);
        if (call.method == 'open') {
          session = args['session'] as String;
          nativeRevision = 0;
          native = TextEditingValue(
            text: args['text'] as String,
            selection: TextSelection(
              baseOffset: args['base'] as int,
              extentOffset: args['extent'] as int,
            ),
          );
        } else if (call.method == 'flush' || call.method == 'close') {
          return {'revision': nativeRevision};
        } else if (call.method == 'command' && document != null) {
          await dispatch(codec.encodeMethodCall(MethodCall('command', args)));
        } else if (call.method == 'edit') {
          if (holdAppCommands) {
            final command = _HeldAppCommand(args);
            _held.add(command);
            return command.result.future;
          }
          return applyAppCommand(args);
        }
        return null;
      },
    );
    text = document ?? TextEditingController();
    text.value = TextEditingValue(
      text: source,
      selection: TextSelection.collapsed(offset: caret),
    );
    if (document == null) bridge.bindDocument(text);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) {
              final editor = LongMessageEditor(
                controller: text,
                autofocus: true,
                decoration: const InputDecoration(),
                inputConnectionFactory: document == null
                    ? bridge.openConnection
                    : null,
                onInputModeExit: document == null
                    ? () async {
                        await bridge.close();
                        bridge.bindDocument(text);
                      }
                    : null,
                onChanged: (_) => changes++,
              );
              return otherInput == null
                  ? editor
                  : Column(
                      children: [
                        Expanded(child: editor),
                        otherInput,
                      ],
                    );
            },
          ),
        ),
      ),
    );
    await tester.pump(Duration.zero);
  }

  Future<Map<String, Object>> applyAppCommand(
    Map<Object?, Object?> args,
  ) async {
    if (args['revision'] != nativeRevision) {
      return {'applied': false, 'revision': nativeRevision};
    }
    final patches = args['patches'] as List;
    final change = CompactEdit.coalesce(native.text, patches);
    final selection = args['selection'] as List;
    final composing = args['composing'] as List;
    await send(
      native.copyWith(
        text: change == null
            ? native.text
            : native.text.replaceRange(change.start, change.end, change.text),
        selection: TextSelection(
          baseOffset: selection[0] as int,
          extentOffset: selection[1] as int,
        ),
        composing: TextRange(
          start: composing[0] as int,
          end: composing[1] as int,
        ),
      ),
      patches.map((p) => List<Object>.from(p as List)).toList(),
      appRequest: args['request'] as int,
    );
    return {'applied': true, 'revision': nativeRevision};
  }

  Future<void> releaseNextAppCommand() async {
    final command = _held.removeAt(0);
    command.result.complete(await applyAppCommand(command.arguments));
    await tester.idle();
  }

  Future<void> releaseAllAppCommands() async {
    var count = 0;
    while (_held.isNotEmpty) {
      if (++count > 100) throw StateError('App edit retry did not converge');
      await releaseNextAppCommand();
    }
    await tester.pump();
  }

  Map<String, Object> event(TextEditingValue next, List<List<Object>> patches) {
    final result = <String, Object>{
      'session': session,
      'from': nativeRevision,
      'to': ++nativeRevision,
      'patches': patches,
      'selection': [next.selection.baseOffset, next.selection.extentOffset],
      'composing': [next.composing.start, next.composing.end],
    };
    native = next;
    return result;
  }

  ByteData prepare(TextEditingValue next, List<List<Object>> patches) =>
      codec.encodeMethodCall(MethodCall('event', event(next, patches)));
  Future<void> dispatch(ByteData message) {
    incomingBytes += message.lengthInBytes;
    return tester.binding.defaultBinaryMessenger.handlePlatformMessage(
      'kelivo/native_message_input',
      message,
      (_) {},
    );
  }

  Future<void> send(
    TextEditingValue next,
    List<List<Object>> patches, {
    int? appRequest,
  }) {
    final value = event(next, patches);
    if (appRequest != null) value['appRequest'] = appRequest;
    return dispatch(codec.encodeMethodCall(MethodCall('event', value)));
  }

  Future<void> replace(
    int start,
    int end,
    String inserted, {
    TextRange composing = TextRange.empty,
  }) => send(
    TextEditingValue(
      text: native.text.replaceRange(start, end, inserted),
      selection: TextSelection.collapsed(offset: start + inserted.length),
      composing: composing,
    ),
    [
      [start, end, inserted],
    ],
  );
  Future<void> dispose() async {
    // Simulate an owner that saves/flushed the document before disposing it.
    if (text is MessageEditingController) {
      await (text as MessageEditingController).retireInput();
    } else if (bridge.failures.isEmpty) {
      await bridge.close();
    }
    bridge.unbindDocument();
    await tester.pumpWidget(const SizedBox());
    text.dispose();
    tester.view.reset();
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      bridge.channel,
      null,
    );
  }
}

class _HeldAppCommand {
  _HeldAppCommand(this.arguments);
  final Map<Object?, Object?> arguments;
  final result = Completer<Map<String, Object>>();
}
