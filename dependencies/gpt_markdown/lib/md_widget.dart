part of 'gpt_markdown.dart';

/// It creates a markdown widget closed to each other.
class MdWidget extends StatefulWidget {
  const MdWidget(
    this.context,
    this.exp,
    this.includeGlobalComponents, {
    super.key,
    required this.config,
  });

  /// The expression to be displayed.
  final String exp;
  final BuildContext context;

  /// Whether to include global components.
  final bool includeGlobalComponents;

  /// The configuration of the markdown widget.
  final GptMarkdownConfig config;

  @override
  State<MdWidget> createState() => _MdWidgetState();
}

class _MdWidgetState extends State<MdWidget> {
  List<InlineSpan> list = [];
  @override
  void initState() {
    super.initState();
    list = MarkdownComponent.generate(
      widget.context,
      widget.exp,
      widget.config,
      widget.includeGlobalComponents,
    );
  }

  @override
  void didUpdateWidget(covariant MdWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.exp != widget.exp ||
        !oldWidget.config.isSame(widget.config)) {
      list = MarkdownComponent.generate(
        context,
        widget.exp,
        widget.config,
        widget.includeGlobalComponents,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // List<InlineSpan> list = MarkdownComponent.generate(
    //   context,
    //   widget.exp,
    //   widget.config,
    //   widget.includeGlobalComponents,
    // );
    return widget.config.getRich(
      TextSpan(children: list, style: widget.config.style?.copyWith()),
    );
  }
}

/// A custom table column width.
class CustomTableColumnWidth extends TableColumnWidth {
  @override
  double maxIntrinsicWidth(Iterable<RenderBox> cells, double containerWidth) {
    double width = 50;
    for (var each in cells) {
      each.layout(const BoxConstraints(), parentUsesSize: true);
      width = max(width, each.size.width);
    }
    return min(containerWidth, width);
  }

  @override
  double minIntrinsicWidth(Iterable<RenderBox> cells, double containerWidth) {
    return 50;
  }
}
