import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
// ignore: depend_on_referenced_packages
import 'package:flutter_inappwebview_android/flutter_inappwebview_android.dart';

class _Events implements PlatformPathHandlerEvents {
  @override
  Future<WebResourceResponse?> handle(String path) async => null;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('workspace Android path channels can release their event handler', () {
    final handler = AndroidCustomPathHandler(
      PlatformCustomPathHandlerCreationParams(
        const PlatformPathHandlerCreationParams(path: '/'),
      ),
    )..eventHandler = _Events();
    handler.dispose();
    expect(handler.eventHandler, isNull);
    handler.dispose();
  });
}
