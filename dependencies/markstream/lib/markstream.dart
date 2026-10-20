/// Markdown parsing and rendering for streaming Flutter applications.
library;

export 'markstream_core.dart';
export 'src/flutter/selection/selectable_span_adapter.dart';
export 'src/flutter/selection/selectable_rich_text.dart';
export 'src/flutter/selection/stable_selection_container.dart';
export 'src/flutter/render/inline_code_capsule.dart';
export 'src/flutter/render/optical_baseline.dart';
export 'src/flutter/selection/code_selection.dart';
export 'src/flutter/selection/table_selection.dart';
export 'src/flutter/theme/markstream_theme.dart';
export 'src/flutter/interfaces/renderers.dart';
export 'src/flutter/extensions/registry.dart';
export 'src/flutter/render/block_list.dart' show BlockList;
export 'src/flutter/render/streaming_text.dart';
export 'src/flutter/markstream_view.dart';
export 'src/flutter/render/chrome.dart';
export 'src/flutter/render/blocks/code_content.dart' show MarkstreamCodeContent;
export 'src/flutter/selection/document_selection.dart'
    show DocumentSelectionDelegate;
export 'src/flutter/selection/selection_controller.dart'
    show
        MarkstreamSelection,
        MarkstreamSelectionController,
        MarkstreamSelectionScope,
        MarkstreamSelectionFragment;
export 'src/flutter/performance_limits.dart';
export 'src/flutter/render/blocks/code_block.dart' show MarkstreamCodeBlock;
export 'src/flutter/render/blocks/directive_card.dart'
    show MarkstreamDirectiveCard;

export 'src/flutter/render/blocks/table_block.dart' show MarkstreamTableBlock;
export 'src/flutter/render/blocks/details_block.dart'
    show MarkstreamDetailsBlock;
