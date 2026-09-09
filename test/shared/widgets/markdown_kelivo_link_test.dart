import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:Kelivo/shared/widgets/markdown_with_highlight.dart';
import 'package:Kelivo/shared/widgets/snackbar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
// ignore: depend_on_referenced_packages
import 'package:url_launcher_platform_interface/link.dart';
// ignore: depend_on_referenced_packages
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';

import '../../support/business_test_harness.dart';

const _kelivoLink = '[daily_sign.py](kelivo://workspace/shenyu/daily_sign.py)';

class _FakeUrlLauncher extends UrlLauncherPlatform {
  final List<String> launched = <String>[];

  @override
  LinkDelegate? get linkDelegate => null;

  @override
  Future<bool> canLaunch(String url) async => true;

  @override
  Future<bool> launch(
    String url, {
    required bool useSafariVC,
    required bool useWebView,
    required bool enableJavaScript,
    required bool enableDomStorage,
    required bool universalLinksOnly,
    required Map<String, String> headers,
    String? webOnlyWindowName,
  }) async {
    launched.add(url);
    return true;
  }

  @override
  Future<bool> launchUrl(String url, LaunchOptions options) async {
    launched.add(url);
    return true;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late UrlLauncherPlatform previous;
  late _FakeUrlLauncher launcher;

  setUp(() {
    previous = UrlLauncherPlatform.instance;
    launcher = _FakeUrlLauncher();
    UrlLauncherPlatform.instance = launcher;
  });

  tearDown(() {
    UrlLauncherPlatform.instance = previous;
  });

  Future<AppLocalizations> pumpMarkdown(
    WidgetTester tester,
    String text,
  ) async {
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => SettingsProvider(createBusinessTestPreferences()),
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: AppSnackBarOverlay(
            child: Scaffold(
              body: SingleChildScrollView(
                child: MarkdownWithCodeHighlight(text: text),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    return AppLocalizations.of(tester.element(find.byType(Scaffold)))!;
  }

  Future<void> tapKelivoLinksAndExpectInApp(
    WidgetTester tester,
    AppLocalizations l10n,
  ) async {
    final labels = find.text('daily_sign.py');
    expect(labels, findsWidgets);
    for (var i = 0; i < labels.evaluate().length; i++) {
      await tester.tap(labels.at(i));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(launcher.launched, isEmpty);
    expect(find.text(l10n.workspaceFileNotAvailable), findsWidgets);
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
  }

  testWidgets('kelivo link with underscore stays in-app in every context', (
    tester,
  ) async {
    final contexts = <String, String>{
      'paragraph': _kelivoLink,
      'list': '- $_kelivoLink',
      'bold': '**$_kelivoLink**',
      'two on one line': '$_kelivoLink $_kelivoLink',
      'table': '| file |\n| --- |\n| $_kelivoLink |',
      'chinese no space': '查看$_kelivoLink',
    };

    for (final entry in contexts.entries) {
      launcher.launched.clear();
      final l10n = await pumpMarkdown(tester, entry.value);
      await tapKelivoLinksAndExpectInApp(tester, l10n);
    }
  });
}
