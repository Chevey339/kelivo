import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

class AndroidSelectionMenuMock {
  AndroidSelectionMenuMock() {
    _messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      final session = (call.arguments as Map)['session'];
      if (call.method == 'show' && shown) {
        _visibleSession = session;
      } else if (call.method == 'hide' && session == _visibleSession) {
        _visibleSession = null;
      }
      return call.method == 'show' ? shown : null;
    });
  }

  static const channel = MethodChannel('app.android_selection_menu');
  final _messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final calls = <MethodCall>[];
  bool shown = true;
  Object? _visibleSession;

  bool get isShown => _visibleSession != null;

  Map<dynamic, dynamic> get menu =>
      calls.lastWhere((call) => call.method == 'show').arguments as Map;

  List<Map<dynamic, dynamic>> get items => (menu['items'] as List).cast<Map>();
  List<String> get labels => [
    for (final item in items) item['title'] as String,
  ];

  Future<void> event(
    String method,
    Map<dynamic, dynamic> source, {
    int? index,
  }) => _messenger.handlePlatformMessage(
    channel.name,
    const StandardMethodCodec().encodeMethodCall(
      MethodCall(method, {
        'session': source['session'],
        'revision': source['revision'],
        'index': index,
      }),
    ),
    (_) {},
  );

  Future<void> press(String label) async {
    final index = labels.indexOf(label);
    expect(
      index,
      greaterThanOrEqualTo(0),
      reason: 'Missing native action $label',
    );
    if (items[index]['enabled'] == true && items[index]['keepOpen'] != true) {
      _visibleSession = null;
    }
    await event('action', menu, index: index);
  }

  void dispose() => _messenger.setMockMethodCallHandler(channel, null);
}
