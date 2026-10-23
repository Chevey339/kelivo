import 'package:flutter/widgets.dart';
import 'package:markstream/markstream.dart';
import '../runtime/ui_surface_controller.dart';
import '../widgets/genui_interactions.dart';
import 'ui_source_map.dart';

/// An explicit host action sink. The production composer is connected in C16;
/// development entries can observe frozen intents without making requests.
class UiActionsScope extends InheritedWidget {
  const UiActionsScope({super.key, required this.onAsk, required super.child});
  final GenUiAskHandler onAsk;
  static GenUiAskHandler? askOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<UiActionsScope>()?.onAsk;
  @override
  bool updateShouldNotify(UiActionsScope oldWidget) => onAsk != oldWidget.onAsk;
}

/// Only the assistant's original main-text projection may create this binding.
/// It carries authority independently of material/Markdown theme scopes.
final class UiHostBinding {
  const UiHostBinding({
    required this.conversationId,
    required this.revisionId,
    required this.source,
    required this.generation,
    this.onAsk,
  });
  final String conversationId, revisionId;
  final UiTextSlice source;
  final UiGenerationStatus generation;
  final GenUiAskHandler? onAsk;
}

class UiHostScope extends InheritedWidget {
  const UiHostScope({
    super.key,
    required this.binding,
    required this.renderOwner,
    required this.exporting,
    required super.child,
  });
  final UiHostBinding binding;
  final MarkstreamView renderOwner;
  final bool exporting;

  static UiHostScope? trustedOf(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<UiHostScope>();
    // Identical source in a nested Markdown renderer is not the same authority.
    return scope != null &&
            identical(
              context.findAncestorWidgetOfExactType<MarkstreamView>(),
              scope.renderOwner,
            )
        ? scope
        : null;
  }

  @override
  bool updateShouldNotify(UiHostScope oldWidget) =>
      binding != oldWidget.binding ||
      renderOwner != oldWidget.renderOwner ||
      child != oldWidget.child ||
      exporting != oldWidget.exporting;
}
