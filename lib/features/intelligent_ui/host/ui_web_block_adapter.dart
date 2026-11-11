import 'package:flutter/foundation.dart' show defaultTargetPlatform;
import 'package:flutter/widgets.dart';
import 'package:markstream/markstream.dart';
import 'package:Kelivo/features/chat/widgets/message_export_sheet.dart';
import '../runtime/ui_surface_controller.dart';
import '../widgets/genui_theme.dart';
import '../widgets/genui_web_card.dart';
import 'ui_host_scope.dart';
import 'ui_source_map.dart';
import 'ui_web_controller.dart';
import 'ui_web_document.dart';
import 'ui_web_preview.dart';

class UiWebBlockAdapter extends StatefulWidget {
  const UiWebBlockAdapter({
    super.key,
    required this.host,
    required this.fence,
    required this.theme,
  });
  final UiHostScope host;
  final UiSourceFence fence;
  final MarkstreamTheme theme;
  @override
  State<UiWebBlockAdapter> createState() => _UiWebBlockAdapterState();
}

class _UiWebBlockAdapterState extends State<UiWebBlockAdapter> {
  late UiWebDocument _document;
  String? _source;
  bool? _closed;
  UiGenerationStatus? _generation;
  void _update() {
    final source = widget.fence.body;
    final closed = widget.fence.node.closed;
    final generation = widget.host.binding.generation;
    if (_source == source && _closed == closed && _generation == generation) {
      return;
    }
    _source = source;
    _closed = closed;
    _generation = generation;
    _document = UiWebDocument.parse(
      source,
      closed: closed,
      generation: generation,
    );
  }

  @override
  void initState() {
    super.initState();
    _update();
  }

  @override
  void didUpdateWidget(UiWebBlockAdapter oldWidget) {
    super.didUpdateWidget(oldWidget);
    _update();
  }

  @override
  Widget build(BuildContext context) => GenUiThemeScope(
    markdownTheme: widget.theme,
    opaque: widget.host.exporting,
    child: GenUiWebCard(
      document: _document,
      exporting: widget.host.exporting,
      supported: uiWebPreviewSupported(defaultTargetPlatform),
      onOpen: (document) => showUiWebPreview(context, document),
      onExportHtml: (document) => saveExportTextWithPicker(
        context,
        filename: 'kelivo-web-${DateTime.now().microsecondsSinceEpoch}.html',
        content: document.html,
        allowedExtensions: const ['html'],
      ),
    ),
  );
}
