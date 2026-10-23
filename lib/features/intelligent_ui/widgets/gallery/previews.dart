import 'package:flutter/material.dart';
import 'package:flutter/widget_previews.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:Kelivo/theme/theme_factory.dart';
import '../genui_theme.dart';
import 'content_gallery.dart';

@Preview(name: 'Content · light', group: 'IntelligentUI', size: Size(390, 800))
Widget genUiLightPreview() => _preview(false);

@Preview(name: 'Content · dark', group: 'IntelligentUI', size: Size(390, 800))
Widget genUiDarkPreview() => _preview(true);

Widget _preview(bool dark) => MaterialApp(
  theme: dark ? buildDarkTheme(null) : buildLightTheme(null),
  locale: const Locale('en'),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: const Scaffold(
    body: SingleChildScrollView(
      child: SelectionArea(
        child: GenUiThemeScope(child: GenUiContentGallery()),
      ),
    ),
  ),
);
