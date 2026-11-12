import 'package:Kelivo/core/services/browser/browser_store.dart';
import 'package:Kelivo/features/side_panel/desktop_side_panel_controller.dart';
import 'package:Kelivo/features/side_panel/widgets/desktop_side_panel.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

class SidePanelMemoryStore extends BrowserStore {
  SidePanelMemoryStore([this.state = const {}]);
  Map<String, dynamic> state;
  @override
  Future<Map<String, dynamic>> read() async => state;
  @override
  Future<void> write(Map<String, Object?> value) async =>
      state = Map<String, dynamic>.from(value);
}

Widget sidePanelHarness(
  DesktopSidePanelController controller, {
  String? conversationId = 'a',
  bool topicsOnRight = false,
  Brightness brightness = Brightness.light,
  Widget? child,
  WidgetBuilder? webBuilder,
  WidgetBuilder? filesBuilder,
  VoidCallback? onFocusChat,
}) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  locale: const Locale('en'),
  theme: ThemeData(brightness: brightness, platform: TargetPlatform.macOS),
  home: DesktopSidePanel(
    controller: controller,
    conversationId: conversationId,
    topicsOnRight: topicsOnRight,
    topicsBuilder: (_, _) => const ColoredBox(
      key: ValueKey('topicsBody'),
      color: Colors.white,
      child: Center(child: Text('Topics')),
    ),
    filesBuilder:
        filesBuilder ??
        (_) => const ColoredBox(
          key: ValueKey('filesBody'),
          color: Colors.white,
          child: Center(child: Text('Files')),
        ),
    webBuilder: webBuilder,
    previewBuilder: (_, tab) => ColoredBox(
      color: Colors.white,
      child: Center(child: Text(tab.path)),
    ),
    onFocusChat: onFocusChat,
    child:
        child ??
        const ColoredBox(
          key: ValueKey('chatBody'),
          color: Colors.white,
          child: SizedBox.expand(),
        ),
  ),
);
