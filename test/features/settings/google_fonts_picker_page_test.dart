import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:Kelivo/core/services/fonts/google_fonts_service.dart';
import 'package:Kelivo/features/settings/pages/google_fonts_picker_page.dart';
import 'package:Kelivo/l10n/app_localizations.dart';

class _MemoryFontFile implements File {
  _MemoryFontFile(this.bytes, {this.fail = false});
  final Uint8List bytes;
  final bool fail;
  int reads = 0;
  @override
  Future<Uint8List> readAsBytes() async {
    reads++;
    if (fail) throw const FileSystemException('Unreadable font');
    return bytes;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Download extends DownloadedGoogleFont {
  _Download(Uint8List bytes, {bool fail = false})
    : super(
        file: _MemoryFontFile(bytes, fail: fail),
        license: 'Example font license',
      );
  int get reads => (file as _MemoryFontFile).reads;
  bool disposed = false;
  @override
  Future<void> dispose() async => disposed = true;
}

class _Service extends GoogleFontsService {
  bool closed = false;
  bool fail = false;
  int requests = 0;
  Completer<DownloadedGoogleFont>? pending;
  final fonts = [
    GoogleFontEntry(
      family: 'Abel',
      url: Uri.parse('https://fonts.gstatic.com/a.ttf'),
      subsets: ['latin'],
    ),
    GoogleFontEntry(
      family: 'Noto Sans SC',
      url: Uri.parse('https://fonts.gstatic.com/b.ttf'),
      subsets: ['chinese-simplified'],
    ),
  ];
  @override
  Future<List<GoogleFontEntry>> loadCatalog({bool refresh = false}) async {
    if (fail) throw const FormatException('offline');
    return fonts;
  }

  @override
  Future<DownloadedGoogleFont> download(
    GoogleFontEntry font, {
    void Function(int received, int? total)? onProgress,
  }) {
    requests++;
    onProgress?.call(1, 2);
    return pending!.future;
  }

  @override
  void close() {
    closed = true;
    super.close();
  }
}

Future<void> _openPicker(
  WidgetTester tester,
  _Service service, {
  Future<bool> Function(DownloadedGoogleFont)? onApply,
  bool desktop = false,
  ThemeData? theme,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: theme,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('en'),
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () {
              final page = GoogleFontsPickerPage(
                service: service,
                onApply: onApply ?? (_) async => true,
              );
              if (desktop) {
                showDialog<void>(
                  context: context,
                  builder: (_) => Dialog(
                    child: SizedBox(width: 640, height: 720, child: page),
                  ),
                );
              } else {
                Navigator.of(
                  context,
                ).push(MaterialPageRoute<void>(builder: (_) => page));
              }
            },
            child: const Text('Open'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Open'));
  await tester.pumpAndSettle();
}

void main() {
  late Uint8List bytes;
  setUpAll(() async {
    bytes = await File(
      'dependencies/gpt_markdown/lib/fonts/JetBrainsMono-Regular.ttf',
    ).readAsBytes();
    final loader = FontLoader('GoogleFontsTestUi')
      ..addFont(Future.value(bytes.buffer.asByteData()));
    await loader.load();
  });

  testWidgets(
    'search filters names and languages without downloading previews',
    (tester) async {
      final service = _Service();
      await _openPicker(tester, service);
      expect(find.text('Abel'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'chinese');
      await tester.pump();
      expect(find.text('Abel'), findsNothing);
      expect(find.text('Noto Sans SC'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'absent');
      await tester.pump();
      expect(find.text('No matching fonts'), findsOneWidget);
      expect(service.requests, 0);
      await tester.pumpWidget(const SizedBox());
      expect(service.closed, isTrue);
    },
  );

  testWidgets('catalog error can be retried with refresh', (tester) async {
    final service = _Service()..fail = true;
    await _openPicker(tester, service);
    expect(find.textContaining('Could not load'), findsOneWidget);
    service.fail = false;
    await tester.tap(find.byTooltip('Refresh font list'));
    await tester.pumpAndSettle();
    expect(find.text('Abel'), findsOneWidget);
    expect(find.textContaining('Could not load'), findsNothing);
  });

  testWidgets(
    'closing pending download cancels client and cleans late completion without applying',
    (tester) async {
      final service = _Service()..pending = Completer<DownloadedGoogleFont>();
      var applied = false;
      await _openPicker(
        tester,
        service,
        onApply: (_) async {
          applied = true;
          return true;
        },
      );
      await tester.tap(find.text('Abel'));
      await tester.pump();
      expect(find.text('Downloading font…'), findsOneWidget);
      await tester.tap(find.byTooltip('Close'));
      await tester.pumpAndSettle();
      expect(service.closed, isTrue);
      final download = _Download(bytes);
      service.pending!.complete(download);
      await tester.pumpAndSettle();
      expect(download.disposed, isTrue);
      expect(applied, isFalse);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('small screen remains searchable with keyboard after preview', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewInsets);
    final service = _Service();
    service.pending = Completer<DownloadedGoogleFont>()
      ..complete(_Download(bytes));
    await _openPicker(tester, service);
    await tester.tap(find.text('Abel'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    await tester.enterText(find.byType(TextField), 'noto');
    await tester.pumpAndSettle();
    expect(find.text('Noto Sans SC'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('pending import disables close and repeated apply', (
    tester,
  ) async {
    final service = _Service();
    final download = _Download(bytes);
    service.pending = Completer<DownloadedGoogleFont>()..complete(download);
    final applied = Completer<bool>();
    var attempts = 0;
    await _openPicker(
      tester,
      service,
      onApply: (_) {
        attempts++;
        return applied.future;
      },
    );
    await tester.tap(find.text('Abel'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Apply'));
    await tester.pump();
    await tester.tap(find.byTooltip('Close'));
    await tester.tap(find.text('Apply'));
    await tester.pump();
    expect(attempts, 1);
    expect(download.disposed, isFalse);
    applied.complete(true);
    await tester.pumpAndSettle();
    expect(download.disposed, isTrue);
  });

  testWidgets(
    'preview registrations survive reselection and reopening the page',
    (tester) async {
      final font = GoogleFontEntry(
        family: 'Abel',
        url: Uri.parse('https://fonts.gstatic.com/registration-v1.ttf'),
        subsets: ['latin'],
      );
      final service = _Service();
      service.fonts[0] = font;
      final first = _Download(bytes);
      service.pending = Completer<DownloadedGoogleFont>()..complete(first);
      await _openPicker(tester, service);
      final row = find.widgetWithText(ListTile, 'Abel');
      await tester.tap(row);
      await tester.pumpAndSettle();
      String? family() => tester
          .widget<Text>(find.text('The quick brown fox 0123456789 · 字体预览'))
          .style!
          .fontFamily;
      final firstFamily = family();
      expect(first.reads, 1);
      await tester.tap(row);
      await tester.pumpAndSettle();
      expect(service.requests, 1);

      service.pending = Completer<DownloadedGoogleFont>()
        ..complete(_Download(bytes));
      await tester.tap(find.widgetWithText(ListTile, 'Noto Sans SC'));
      await tester.pumpAndSettle();
      final repeated = _Download(bytes);
      service.pending = Completer<DownloadedGoogleFont>()..complete(repeated);
      await tester.tap(row);
      await tester.pumpAndSettle();
      expect(family(), firstFamily);
      expect(repeated.reads, 0);
      expect(first.disposed, isTrue);
      await tester.tap(find.byTooltip('Close'));
      await tester.pumpAndSettle();

      final reopened = _Service();
      reopened.fonts[0] = font;
      final downloadedAgain = _Download(bytes);
      reopened.pending = Completer<DownloadedGoogleFont>()
        ..complete(downloadedAgain);
      await _openPicker(tester, reopened);
      await tester.tap(row);
      await tester.pumpAndSettle();
      expect(family(), firstFamily);
      expect(downloadedAgain.reads, 0);
    },
  );

  testWidgets(
    'failed preview can retry and a new font URL gets a new registration',
    (tester) async {
      final service = _Service();
      service.fonts[0] = GoogleFontEntry(
        family: 'Abel',
        url: Uri.parse('https://fonts.gstatic.com/retry-v1.ttf'),
        subsets: ['latin'],
      );
      final failed = _Download(bytes, fail: true);
      service.pending = Completer<DownloadedGoogleFont>()..complete(failed);
      await _openPicker(tester, service);
      final row = find.widgetWithText(ListTile, 'Abel');
      await tester.tap(row);
      await tester.pumpAndSettle();
      expect(find.textContaining('Could not load'), findsOneWidget);
      expect(failed.disposed, isTrue);
      final retry = _Download(bytes);
      service.pending = Completer<DownloadedGoogleFont>()..complete(retry);
      await tester.tap(row);
      await tester.pumpAndSettle();
      expect(find.textContaining('Could not load'), findsNothing);
      expect(retry.reads, 1);
      final firstFamily = tester
          .widget<Text>(find.text('The quick brown fox 0123456789 · 字体预览'))
          .style!
          .fontFamily;
      service.fonts[0] = GoogleFontEntry(
        family: 'Abel',
        url: Uri.parse('https://fonts.gstatic.com/retry-v2.ttf'),
        subsets: ['latin'],
      );
      await tester.tap(find.byTooltip('Refresh font list'));
      await tester.pumpAndSettle();
      final newVersion = _Download(bytes);
      service.pending = Completer<DownloadedGoogleFont>()..complete(newVersion);
      await tester.tap(row);
      await tester.pumpAndSettle();
      expect(newVersion.reads, 1);
      expect(
        tester
            .widget<Text>(find.text('The quick brown fox 0123456789 · 字体预览'))
            .style!
            .fontFamily,
        isNot(firstFamily),
      );
    },
  );

  testWidgets(
    'large text on a small screen can scroll to and apply the preview',
    (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final service = _Service();
      service.pending = Completer<DownloadedGoogleFont>()
        ..complete(_Download(bytes));
      var applied = false;
      await _openPicker(
        tester,
        service,
        theme: ThemeData(fontFamily: 'GoogleFontsTestUi'),
        onApply: (_) async {
          applied = true;
          return true;
        },
      );
      final row = find.widgetWithText(ListTile, 'Abel');
      await tester.ensureVisible(row);
      await tester.pumpAndSettle();
      await tester.tap(row);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.text('Apply'));
      await tester.pumpAndSettle();
      expect(find.text('Apply').hitTestable(), findsOneWidget);
      await tester.tap(find.text('Apply'));
      await tester.pumpAndSettle();
      expect(applied, isTrue);
      expect(find.byType(GoogleFontsPickerPage), findsNothing);
    },
  );

  for (final desktop in [false, true]) {
    testWidgets(
      'preview requires explicit apply and survives import failure (${desktop ? 'desktop' : 'mobile'})',
      (tester) async {
        tester.view.physicalSize = desktop
            ? const Size(1200, 900)
            : const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final download = _Download(bytes);
        final service = _Service();
        service.pending = Completer<DownloadedGoogleFont>()..complete(download);
        var attempts = 0;
        await _openPicker(
          tester,
          service,
          desktop: desktop,
          onApply: (_) async => ++attempts > 1,
        );
        await tester.tap(find.text('Abel'));
        await tester.pumpAndSettle();
        expect(attempts, 0);
        expect(find.text('Apply'), findsOneWidget);
        await tester.tap(find.text('Font license'));
        await tester.pumpAndSettle();
        expect(find.text('Example font license'), findsOneWidget);
        await tester.tap(find.text('Close'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Apply'));
        await tester.pumpAndSettle();
        expect(attempts, 1);
        expect(find.textContaining('Could not load'), findsOneWidget);
        await tester.tap(find.text('Apply'));
        await tester.pumpAndSettle();
        expect(attempts, 2);
        expect(find.byType(GoogleFontsPickerPage), findsNothing);
        expect(download.disposed, isTrue);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
