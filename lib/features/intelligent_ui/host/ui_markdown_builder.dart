import 'package:flutter/widgets.dart';
import 'package:markstream/markstream.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import '../widgets/genui_theme.dart';
import 'ui_block_adapter.dart';
import 'ui_web_block_adapter.dart';
import 'ui_host_scope.dart';
import 'ui_runtime_registry.dart';

/// BlockList caches completed widget instances. Read host dependencies inside
/// this element so status/source changes reach a cached completed prefix too.
class UiMarkdownBlock extends StatelessWidget {
  const UiMarkdownBlock({
    super.key,
    required this.node,
    required this.rendering,
    required this.sourceBuilder,
    this.linkHandler,
  });
  final CodeBlockNode node;
  final MarkstreamRenderContext rendering;
  final WidgetBuilder sourceBuilder;
  final LinkHandler? linkHandler;
  @override
  Widget build(BuildContext context) => buildGenUiBlock(
    context,
    node,
    rendering,
    sourceBuilder: sourceBuilder,
    linkHandler: linkHandler,
  );
}

Widget buildGenUiBlock(
  BuildContext context,
  CodeBlockNode node,
  MarkstreamRenderContext rendering, {
  required WidgetBuilder sourceBuilder,
  LinkHandler? linkHandler,
}) {
  final host = UiHostScope.trustedOf(context);
  final registry = UiRuntimeScope.maybeOf(context);
  final fence = host?.binding.source.resolve(rendering.document, node);
  final ordinal = fence == null
      ? null
      : host!.binding.source.messageOrdinalOf(fence);
  if (host == null || fence == null || ordinal == null) {
    return sourceBuilder(context);
  }
  if (ordinal >= 3) {
    return GenUiThemeScope(
      markdownTheme: rendering.theme,
      child: Builder(
        builder: (context) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              fence.isWeb
                  ? AppLocalizations.of(context)!.genuiWebBlockLimit
                  : AppLocalizations.of(context)!.genuiBlockLimit,
              style: GenUiTheme.of(context).caption,
            ),
            SizedBox(height: GenUiTheme.of(context).xs),
            sourceBuilder(context),
          ],
        ),
      ),
    );
  }
  if (fence.isWeb) {
    return UiWebBlockAdapter(
      key: ValueKey((host.binding.revisionId, fence.surfaceKey)),
      host: host,
      fence: fence,
      theme: rendering.theme,
    );
  }
  if (registry == null) return sourceBuilder(context);
  return UiBlockAdapter(
    key: ValueKey((host.binding.revisionId, fence.surfaceKey)),
    host: host,
    registry: registry,
    fence: fence,
    theme: rendering.theme,
    selectionNode: node,
    linkHandler: linkHandler,
  );
}
