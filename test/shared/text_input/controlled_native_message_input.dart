import 'package:Kelivo/shared/text_input/native_message_input.dart';
import 'package:flutter/services.dart';

/// Holds native event delivery in tests without shipping probe controls.
class MirrorInputControl extends NativeMessageInput {
  MirrorInputControl({super.channel});

  bool paused = false;
  final queued = <Map<Object?, Object?>>[];

  @override
  void receive(Map<Object?, Object?> event) {
    if (paused) {
      queued.add(event);
    } else {
      super.receive(event);
    }
  }

  void resume() {
    paused = false;
    final events = List.of(queued);
    queued.clear();
    for (final event in events) {
      super.receive(event);
    }
  }

  @override
  Future<TextEditingValue> flush() {
    resume();
    return super.flush();
  }

  @override
  Future<TextEditingValue> close() {
    final closing = super.close();
    resume();
    return closing;
  }
}
