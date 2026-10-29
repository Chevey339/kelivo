import 'package:flutter/material.dart';
import 'package:flutter/widget_previews.dart';
import '../../core/models/quote_ref.dart';
import '../../l10n/app_localizations.dart';
import 'widgets/quote_chip.dart';
import 'widgets/selection_quick_toolbar.dart';

@Preview(
  name: 'Selection actions · light',
  group: 'Chat selection',
  size: Size(460, 220),
)
Widget selectionActionsLightPreview() => _preview(Brightness.light);

@Preview(
  name: 'Selection actions · dark',
  group: 'Chat selection',
  size: Size(460, 220),
)
Widget selectionActionsDarkPreview() => _preview(Brightness.dark);

Widget _preview(Brightness brightness) => MaterialApp(
  theme: ThemeData(
    colorScheme: ColorScheme.fromSeed(
      seedColor: const Color(0xff626a9a),
      brightness: brightness,
    ),
  ),
  locale: const Locale('zh'),
  supportedLocales: AppLocalizations.supportedLocales,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  home: Scaffold(
    body: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SelectionQuickToolbar(onQuote: _noop, onTranslate: _noop),
          const SizedBox(height: 28),
          Text.rich(
            TextSpan(
              style: const TextStyle(fontSize: 14),
              children: [
                const TextSpan(text: '看 '),
                WidgetSpan(
                  alignment: PlaceholderAlignment.baseline,
                  baseline: TextBaseline.alphabetic,
                  child: QuoteChip(
                    quote: QuoteRef(
                      id: 'preview',
                      messageId: 'source',
                      start: 0,
                      end: 14,
                      text: '缓存需要在业务数据变更后主动失效。',
                      model: 'Model',
                      createdAt: DateTime(2026, 10, 28),
                    ),
                    onRemove: _noop,
                  ),
                ),
                const TextSpan(text: ' 这里应该如何实现？'),
              ],
            ),
          ),
        ],
      ),
    ),
  ),
);
void _noop() {}
