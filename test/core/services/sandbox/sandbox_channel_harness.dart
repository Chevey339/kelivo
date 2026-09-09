import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:Kelivo/core/services/sandbox/workspace_channel.dart';

/// Fake messenger + [WorkspaceChannel] for sandbox unit tests.
class SandboxChannelHarness {
  SandboxChannelHarness() {
    messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    methodChannel = const MethodChannel(kWorkspaceMethodChannel);
    eventChannel = const EventChannel(kWorkspaceEventChannel);
    channel = WorkspaceChannel(
      methodChannel: methodChannel,
      eventChannel: eventChannel,
    );
  }

  late final TestDefaultBinaryMessenger messenger;
  late final MethodChannel methodChannel;
  late final EventChannel eventChannel;
  late final WorkspaceChannel channel;

  MockStreamHandlerEventSink? sink;
  final List<MethodCall> calls = <MethodCall>[];

  Map<String, Object?> probeResult = <String, Object?>{
    'supported': true,
    'abi': 'arm64-v8a',
  };
  Object? Function(MethodCall call)? handler;

  void install() {
    messenger.setMockStreamHandler(
      eventChannel,
      MockStreamHandler.inline(
        onListen: (args, eventSink) {
          sink = eventSink;
        },
        onCancel: (args) {
          sink = null;
        },
      ),
    );
    messenger.setMockMethodCallHandler(methodChannel, (call) async {
      calls.add(call);
      if (handler != null) return handler!(call);
      return _default(call);
    });
  }

  void emit(Map<String, Object?> event) {
    sink?.success(event);
  }

  Map<String, Object?>? argsOf(String method) {
    for (final call in calls) {
      if (call.method == method && call.arguments is Map) {
        return Map<String, Object?>.from(call.arguments as Map);
      }
    }
    return null;
  }

  List<String> get methods => [for (final call in calls) call.method];

  Object? _default(MethodCall call) {
    switch (call.method) {
      case 'probe':
        return probeResult;
      case 'exec':
      case 'beginBackgroundTask':
      case 'endBackgroundTask':
      case 'ptyWrite':
      case 'ptyResize':
      case 'ptyClose':
      case 'boot':
      case 'keepScreenOn':
        return null;
      case 'cancel':
        return true;
      case 'ptyOpen':
        return <String, Object?>{'pid': 42};
      case 'installRootfs':
        return <String, Object?>{'ok': true};
      case 'resetRootfs':
        return <String, Object?>{'ok': true, 'needsRestart': false};
      default:
        return null;
    }
  }

  void dispose() {
    messenger.setMockMethodCallHandler(methodChannel, null);
    messenger.setMockStreamHandler(eventChannel, null);
  }
}
