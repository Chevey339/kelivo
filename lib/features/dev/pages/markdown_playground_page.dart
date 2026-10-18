import 'package:flutter/material.dart';
import 'package:markstream/markstream.dart';
import 'package:provider/provider.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/shared/markdown/markdown_with_code_highlight.dart';
import 'package:Kelivo/shared/markdown/kelivo_markdown_extensions.dart';

import 'package:Kelivo/icons/lucide_adapter.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:Kelivo/shared/responsive/screen_type_helper.dart';
import 'package:Kelivo/shared/widgets/app_selection_area.dart';
import 'package:Kelivo/shared/widgets/ios_tactile.dart';
import 'package:Kelivo/shared/widgets/ios_switch.dart';
import 'package:Kelivo/shared/widgets/section_card.dart';
import '../models/markdown_playground_model.dart';
import '../widgets/markdown_ast_view.dart';
import '../widgets/markdown_playground_layouts.dart';

const _sample = r'''# Markdown Playground

编辑源码，检查 AST，并尝试跨段落选择文本。

**Bold**, _emphasis_, `inline code`, [link](https://example.com) plain [1] and citations [cite:demo,other].

- [x] Native selection
- [ ] Streaming input

| Name | Value |
| :--- | ---: |
| Alpha | 42 |
| Beta | 3.14 |

```dart
void main() {
  print('Hello, Markdown');
}
```

Inline math: $x^2 + y^2$.

<details>
<summary>Details</summary>

A hidden paragraph appears when expanded.

</details>
''';

class MarkdownPlaygroundPage extends StatefulWidget {
  const MarkdownPlaygroundPage({super.key});
  @override
  State<MarkdownPlaygroundPage> createState() => _MarkdownPlaygroundPageState();
}

class _MarkdownPlaygroundPageState extends State<MarkdownPlaygroundPage>
    with TickerProviderStateMixin {
  final _source = TextEditingController(text: _sample);
  final _model = MarkdownPlaygroundModel(_sample);
  final _selection = MarkstreamSelectionController();
  late final _mobileTabs = TabController(length: 3, vsync: this);
  late final _desktopTabs = TabController(length: 2, vsync: this);
  bool? _dark;
  double _width = 390;
  @override
  void initState() {
    super.initState();
    _source.addListener(_sourceChanged);
    _model.addListener(_changed);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _model.setParserOptions(
      markdownParserOptions(Provider.of<SettingsProvider>(context)),
    );
  }

  void _sourceChanged() {
    if (_source.text != _model.source) _model.setSource(_source.text);
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _source.dispose();
    _model.dispose();
    _selection.dispose();
    _mobileTabs.dispose();
    _desktopTabs.dispose();
    super.dispose();
  }

  Widget _pane(String title, Widget child) => SectionCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
          child: Text(title, style: Theme.of(context).textTheme.titleSmall),
        ),
        Expanded(child: child),
      ],
    ),
  );
  Widget _editor(AppLocalizations l10n) => _pane(
    l10n.markdownPlaygroundSource,
    TextField(
      key: const ValueKey('markdown-playground-editor'),
      controller: _source,
      expands: true,
      maxLines: null,
      keyboardType: TextInputType.multiline,
      autocorrect: false,
      enableSuggestions: false,
      smartDashesType: SmartDashesType.disabled,
      smartQuotesType: SmartQuotesType.disabled,
      style: const TextStyle(
        fontFamily: 'monospace',
        fontSize: 13,
        height: 1.5,
      ),
      decoration: InputDecoration(
        border: InputBorder.none,
        contentPadding: const EdgeInsets.all(12),
        hintText: l10n.markdownPlaygroundEmpty,
      ),
    ),
  );
  Widget _preview(AppLocalizations l10n, bool dark) {
    final scheme = ColorScheme.fromSeed(
      seedColor: Theme.of(context).colorScheme.primary,
      brightness: dark ? Brightness.dark : Brightness.light,
    );
    return Theme(
      data: ThemeData(colorScheme: scheme, useMaterial3: true),
      child: ColoredBox(
        color: scheme.surface,
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: _width,
              height: constraints.maxHeight,
              child: SingleChildScrollView(
                primary: false,
                padding: const EdgeInsets.all(16),
                child: DefaultTextStyle(
                  style: TextStyle(
                    color: scheme.onSurface,
                    fontSize: 15.5,
                    height: 1.55,
                  ),
                  child: MarkstreamSelectionScope(
                    controller: _selection,
                    child: AppSelectionArea(
                      child: MarkdownWithCodeHighlight(
                        text: _model.displayed,
                        citationIndexResolver: (id) => id == 'demo' ? '1' : '2',
                        streaming: _model.streaming,
                      ),
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

  Widget _selected(AppLocalizations l10n) => ListenableBuilder(
    listenable: _selection,
    builder: (context, _) {
      final selected = _selection.hasSelection;
      return SectionCard(
        child: ListView(
          primary: false,
          padding: const EdgeInsets.all(10),
          children: [
            Text(
              l10n.markdownPlaygroundPlain,
              style: Theme.of(context).textTheme.labelLarge,
            ),
            Text(
              selected
                  ? _selection.selectedPlainText
                  : l10n.markdownPlaygroundSelectionHint,
              key: const ValueKey('markdown-playground-selected-plain'),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
            Text(
              l10n.markdownPlaygroundMarkdown,
              style: Theme.of(context).textTheme.labelLarge,
            ),
            Text(
              selected ? _selection.selectedMarkdown : '',
              key: const ValueKey('markdown-playground-selected-markdown'),
              style: const TextStyle(fontFamily: 'monospace'),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      );
    },
  );
  Widget _controls(AppLocalizations l10n, bool dark) => Column(
    children: [
      Wrap(
        spacing: 12,
        runSpacing: 4,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          TextButton.icon(
            key: const ValueKey('markdown-playground-play'),
            onPressed: _model.source.isEmpty
                ? null
                : () {
                    if (_model.playing) {
                      _model.pause();
                    } else {
                      FocusScope.of(context).unfocus();
                      _mobileTabs.animateTo(1);
                      _desktopTabs.animateTo(0);
                      _model.play();
                    }
                  },
            icon: Icon(_model.playing ? Lucide.Pause : Lucide.Play, size: 18),
            label: Text(
              _model.playing
                  ? l10n.markdownPlaygroundPause
                  : _model.streaming
                  ? l10n.markdownPlaygroundResume
                  : l10n.markdownPlaygroundPlay,
            ),
          ),
          TextButton.icon(
            key: const ValueKey('markdown-playground-show-all'),
            onPressed: _model.streaming ? _model.showAll : null,
            icon: const Icon(Lucide.RotateCcw, size: 18),
            label: Text(l10n.markdownPlaygroundShowAll),
          ),
          Text(l10n.markdownPlaygroundProgress(_model.shown, _model.total)),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(l10n.markdownPlaygroundTheme),
              const SizedBox(width: 8),
              IosSwitch(
                key: const ValueKey('markdown-playground-theme'),
                value: dark,
                onChanged: (value) => setState(() => _dark = value),
              ),
            ],
          ),
        ],
      ),
      Row(
        children: [
          Text(l10n.markdownPlaygroundWidth),
          Expanded(
            child: Slider(
              key: const ValueKey('markdown-playground-width'),
              min: 280,
              max: 960,
              divisions: 68,
              value: _width,
              onChanged: (value) => setState(() => _width = value),
            ),
          ),
          SizedBox(
            width: 54,
            child: Text(
              '${_width.round()} px',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    ],
  );
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final dark = _dark ?? Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          l10n.markdownPlaygroundTitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        leading: IosIconButton(
          icon: Lucide.ArrowLeft,
          onTap: () => Navigator.of(context).maybePop(),
          tooltip: l10n.settingsPageBackButton,
        ),
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, bounds) => Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: (bounds.maxHeight * .35).clamp(0, 200),
                  ),
                  child: SingleChildScrollView(
                    primary: false,
                    child: _controls(l10n, dark),
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final editor = _editor(l10n),
                          preview = _preview(l10n, dark),
                          ast = _pane(
                            l10n.markdownPlaygroundAst,
                            MarkdownAstView(document: _model.document),
                          ),
                          selection = _selected(l10n);
                      return !ResponsiveHelper.isMobile(context) &&
                              constraints.maxWidth >= 880
                          ? DesktopMarkdownPlaygroundLayout(
                              editor: editor,
                              preview: preview,
                              ast: ast,
                              selection: selection,
                              tabs: _desktopTabs,
                              tabLabels: [
                                l10n.markdownPlaygroundPreview,
                                l10n.markdownPlaygroundAst,
                              ],
                            )
                          : MobileMarkdownPlaygroundLayout(
                              editor: editor,
                              preview: preview,
                              ast: ast,
                              selection: selection,
                              tabs: _mobileTabs,
                              tabLabels: [
                                l10n.markdownPlaygroundSource,
                                l10n.markdownPlaygroundPreview,
                                l10n.markdownPlaygroundAst,
                              ],
                            );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
