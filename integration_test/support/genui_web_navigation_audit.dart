import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:webview_flutter_platform_interface/webview_flutter_platform_interface.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';

/// Records real engine requests and the production callback's exact decision.
/// No request is added, removed, allowed or blocked by this test-only decorator.
class GenUiAuditedWebKit extends WebKitWebViewPlatform {
  GenUiAuditedWebKit(this.events);
  final List<Map<String, Object?>> events;
  @override
  WebKitNavigationDelegate createPlatformNavigationDelegate(
    PlatformNavigationDelegateCreationParams params,
  ) => _WebKitDelegate(params, events);
}

class _WebKitDelegate extends WebKitNavigationDelegate {
  _WebKitDelegate(super.params, this.events);
  final List<Map<String, Object?>> events;
  @override
  Future<void> setOnNavigationRequest(NavigationRequestCallback callback) =>
      super.setOnNavigationRequest((request) async {
        final decision = await callback(request);
        events.add({
          'url': request.url,
          'main': request.isMainFrame,
          'decision': decision.name,
        });
        return decision;
      });
}

class GenUiAuditedAndroid extends AndroidWebViewPlatform {
  GenUiAuditedAndroid(this.events);
  final List<Map<String, Object?>> events;
  @override
  AndroidNavigationDelegate createPlatformNavigationDelegate(
    PlatformNavigationDelegateCreationParams params,
  ) => _AndroidDelegate(params, events);
}

class _AndroidDelegate extends AndroidNavigationDelegate {
  _AndroidDelegate(super.params, this.events);
  final List<Map<String, Object?>> events;
  @override
  Future<void> setOnNavigationRequest(NavigationRequestCallback callback) =>
      super.setOnNavigationRequest((request) async {
        final decision = await callback(request);
        events.add({
          'url': request.url,
          'main': request.isMainFrame,
          'decision': decision.name,
        });
        return decision;
      });
}
