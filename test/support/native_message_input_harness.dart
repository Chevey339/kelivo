import 'package:Kelivo/shared/text_input/compact_edit.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Models accepted Android revisions separately from their Dart delivery.
/// This lets real consumer widgets save/switch/dispose with an event in flight.
class NativeMessageInputHarness {
  NativeMessageInputHarness(this.tester) {
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      channel,
      _handle,
    );
  }
  final WidgetTester tester;
  static const channel = MethodChannel('kelivo/native_message_input');
  static const codec = StandardMethodCodec();
  final documents = <String, _NativeDocument>{};
  final pendingEvents = <ByteData>[];
  final methods = <String>[];
  String? session;
  bool holdDelivery = false;
  TextEditingValue get value => documents[session]!.value;

  Future<Object?> _handle(MethodCall call) async {
    methods.add(call.method);
    final args = Map<Object?, Object?>.from(call.arguments as Map);
    final id = args['session'] as String;
    if (call.method == 'open') {
      session = id;
      documents[id] = _NativeDocument(
        TextEditingValue(
          text: args['text'] as String,
          selection: TextSelection(
            baseOffset: args['base'] as int,
            extentOffset: args['extent'] as int,
          ),
        ),
      );
      return null;
    }
    final document = documents[id];
    if (call.method == 'flush' || call.method == 'close') {
      return {'revision': document!.revision};
    }
    if (call.method == 'command') {
      await deliver(codec.encodeMethodCall(MethodCall('command', args)));
    } else if (call.method == 'edit') {
      if (args['revision'] != document!.revision) {
        return {'applied': false, 'revision': document.revision};
      }
      final patches = args['patches'] as List;
      final edit = CompactEdit.coalesce(document.value.text, patches);
      final selected = args['selection'] as List;
      final composing = args['composing'] as List;
      await _emit(
        id,
        document.value.copyWith(
          text: edit == null
              ? document.value.text
              : document.value.text.replaceRange(
                  edit.start,
                  edit.end,
                  edit.text,
                ),
          selection: TextSelection(
            baseOffset: selected[0] as int,
            extentOffset: selected[1] as int,
          ),
          composing: TextRange(
            start: composing[0] as int,
            end: composing[1] as int,
          ),
        ),
        patches,
        request: args['request'] as int,
      );
      return {'applied': true, 'revision': document.revision};
    }
    return null;
  }

  Future<void> commit(String text) =>
      _emit(session!, value.replaced(value.selection, text), [
        [value.selection.start, value.selection.end, text],
      ]);

  Future<void> _emit(
    String id,
    TextEditingValue next,
    List patches, {
    int? request,
  }) async {
    final document = documents[id]!;
    final event = {
      'session': id,
      'from': document.revision,
      'to': ++document.revision,
      'patches': patches,
      'selection': [next.selection.baseOffset, next.selection.extentOffset],
      'composing': [next.composing.start, next.composing.end],
      if (request != null) 'appRequest': request,
    };
    document.value = next;
    final message = codec.encodeMethodCall(MethodCall('event', event));
    if (holdDelivery) {
      pendingEvents.add(message);
    } else {
      await deliver(message);
    }
  }

  Future<void> deliver(ByteData message) => tester
      .binding
      .defaultBinaryMessenger
      .handlePlatformMessage(channel.name, message, (_) {});

  Future<void> release() async {
    holdDelivery = false;
    final events = List.of(pendingEvents);
    pendingEvents.clear();
    for (final event in events) {
      await deliver(event);
    }
    await tester.idle();
  }

  void dispose() => tester.binding.defaultBinaryMessenger
      .setMockMethodCallHandler(channel, null);
}

class _NativeDocument {
  _NativeDocument(this.value);
  TextEditingValue value;
  int revision = 0;
}
