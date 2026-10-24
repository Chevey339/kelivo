import 'expansion_gallery.dart';
import 'context_gallery.dart';
import 'package:flutter/material.dart';
import 'package:Kelivo/features/intelligent_ui/catalog/ui_catalog.dart';
import 'package:Kelivo/features/intelligent_ui/runtime/ui_surface_controller.dart';
import 'package:Kelivo/features/intelligent_ui/runtime/ui_surface_state.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:Kelivo/shared/widgets/ios_text_button.dart';
import 'package:Kelivo/theme/theme_factory.dart';
import '../genui_layout.dart';
import '../genui_surface.dart';
import '../genui_theme.dart';
import 'content_gallery.dart';
import 'input_gallery.dart';
import 'chart_gallery.dart';
import 'table_gallery.dart';

/// Development entry point: flutter run -d macos -t
/// lib/features/intelligent_ui/widgets/gallery/main.dart
/// The production app never imports or enables this gallery.
void main() => runApp(const GenUiGalleryApp());

class GenUiGalleryApp extends StatefulWidget {
  const GenUiGalleryApp({super.key});
  @override
  State<GenUiGalleryApp> createState() => _GenUiGalleryAppState();
}

class _GenUiGalleryAppState extends State<GenUiGalleryApp> {
  bool _dark = false, _rtl = false, _large = false;
  final _controllers = <UiSurfaceController>[];
  @override
  void initState() {
    super.initState();
    for (var i = 0; i < 5; i++) {
      final c = UiSurfaceController(
        owner: UiSurfaceOwner(revisionId: 'gallery', surfaceKey: '0:$i'),
      );
      c.updateSource(
        '${UiCatalog.header}\n${switch (i) {
          1 => 'root = Column(children=[good,bad])\ngood = Metric(label="Valid result", value=42)\nbad = Gauge(value=3)\n',
          3 => 'root = Text(text="Incomplete header")\n',
          _ => 'root = Metric(label="Local result", value=42, unit="km")\n',
        }}',
        closed: i != 0 && i != 2,
        generation: i == 0
            ? UiGenerationStatus.generating
            : i == 2
            ? UiGenerationStatus.interrupted
            : UiGenerationStatus.complete,
      );
      if (i == 3) {
        c.updateSource(
          'ui 9 catalog "kelivo.native/1"\n',
          closed: true,
          generation: UiGenerationStatus.complete,
        );
      }
      if (i == 4) c.setSaveFailed(true, token: c.token, sequence: c.sequence);
      _controllers.add(c);
    }
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    theme: _dark ? buildDarkTheme(null) : buildLightTheme(null),
    locale: const Locale('en'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Builder(
      builder: (context) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(_large ? 1.3 : 1)),
        child: Directionality(
          textDirection: _rtl ? TextDirection.rtl : TextDirection.ltr,
          child: Scaffold(
            body: SafeArea(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 720),
                  child: Column(
                    children: [
                      Wrap(
                        children: [
                          IosTextButton(
                            label: _dark ? 'Dark' : 'Light',
                            onPressed: () => setState(() => _dark = !_dark),
                          ),
                          IosTextButton(
                            label: _rtl ? 'RTL' : 'LTR',
                            onPressed: () => setState(() => _rtl = !_rtl),
                          ),
                          IosTextButton(
                            label: _large ? 'Text 1.3×' : 'Text 1.0×',
                            onPressed: () => setState(() => _large = !_large),
                          ),
                        ],
                      ),
                      Expanded(
                        child: SingleChildScrollView(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: SelectionArea(
                              child: GenUiThemeScope(
                                child: GenUiColumn(
                                  children: [
                                    const GenUiExpansionGallery(),
                                    const GenUiContextGallery(),
                                    const GenUiTableGallery(),
                                    const GenUiChartGallery(),
                                    const GenUiInputGallery(),
                                    const GenUiContentGallery(),
                                    for (
                                      var i = 0;
                                      i < _controllers.length;
                                      i++
                                    )
                                      GenUiSurface(
                                        controller: _controllers[i],
                                        title: 'Surface ${i + 1}',
                                        onRetrySave: i == 4
                                            ? () =>
                                                  _controllers[i].setSaveFailed(
                                                    false,
                                                    token:
                                                        _controllers[i].token,
                                                    sequence: _controllers[i]
                                                        .sequence,
                                                  )
                                            : null,
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
