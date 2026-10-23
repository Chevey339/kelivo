import 'package:Kelivo/features/intelligent_ui/catalog/ui_catalog.dart';
import 'package:Kelivo/features/intelligent_ui/protocol/ui_ir.dart';
import 'package:Kelivo/features/intelligent_ui/protocol/ui_validation.dart';
import 'package:Kelivo/features/intelligent_ui/runtime/ui_resolved_node.dart';

enum UiFieldError {
  required,
  tooShort,
  tooLong,
  number,
  range,
  option,
  composing,
  stateBudget,
}

final class UiFieldIssue {
  const UiFieldIssue(this.node, this.error, {this.min, this.max});
  final String node;
  final UiFieldError error;
  final num? min, max;
}

/// Transient text is deliberately absent from persisted inputs and model data.
/// A composing or incomplete number cannot silently submit the last valid value.
final class UiFieldDraft {
  const UiFieldDraft(
    this.text, {
    this.composing = false,
    this.rejected = false,
  });
  final String text;
  final bool composing;
  final bool rejected;
}

/// Parent visibility/enabling is inherited. Traversal follows visual child order,
/// not declaration order; malformed cycles still have a finite visit bound.
final class UiControlTree {
  UiControlTree(this.nodes) {
    _visit('root', visible: true, enabled: true);
  }
  final Map<String, UiResolvedNode> nodes;
  final order = <String>[];
  final visible = <String, bool>{};
  final enabled = <String, bool>{};
  final parents = <String, String>{};
  final forms = <String, String>{};

  void _visit(
    String id, {
    required bool visible,
    required bool enabled,
    String? form,
  }) {
    if (this.visible.containsKey(id)) return;
    final node = nodes[id];
    final show = visible && (node?.visible ?? true);
    final active = enabled && (node?.enabled ?? false);
    this.visible[id] = show;
    this.enabled[id] = active;
    order.add(id);
    if (node?.declaration.component == 'Form') form = id;
    if (form != null) forms[id] = form;
    final children = node?.declaration.arguments['children'];
    if (children is UiChildRefs) {
      for (final child in children.names) {
        parents.putIfAbsent(child, () => id);
        _visit(child, visible: show, enabled: active, form: form);
      }
    }
  }

  bool belongsTo(String id, String ancestor) {
    final visited = <String>{};
    String? next = id;
    while (next != null && visited.add(next)) {
      if (next == ancestor) return true;
      next = parents[next];
    }
    return false;
  }
}

final class UiFormCheck {
  UiFormCheck(Iterable<UiFieldIssue> issues, Iterable<String> unavailable)
    : issues = List.unmodifiable(issues),
      unavailable = List.unmodifiable(unavailable);
  final List<UiFieldIssue> issues;
  final List<String> unavailable;
  bool get valid => issues.isEmpty && unavailable.isEmpty;
  String? get firstField => issues.firstOrNull?.node;
}

UiFormCheck validateUiForm(
  String form,
  UiValidationResult program,
  UiControlTree tree, {
  Map<String, UiFieldDraft> drafts = const {},
}) {
  if (tree.nodes[form]?.declaration.component != 'Form' ||
      tree.visible[form] != true) {
    return UiFormCheck(const [], [form]);
  }
  final issues = <UiFieldIssue>[];
  final unavailable = <String>[];
  for (final id in tree.order) {
    if (!tree.belongsTo(id, form) || tree.visible[id] != true) continue;
    final node = tree.nodes[id];
    if (node?.valid != true) {
      unavailable.add(id);
      continue;
    }
    if (tree.enabled[id] != true ||
        UiCatalog.components[node!.declaration.component]?.textPolicy !=
            UiTextPolicy.input) {
      continue;
    }
    final issue = validateUiField(node, program, draft: drafts[id]);
    if (issue != null) issues.add(issue);
  }
  return UiFormCheck(issues, unavailable);
}

final _completeNumber = RegExp(
  r'^[+-]?(?:\d+(?:\.\d+)?|\.\d+)(?:[eE][+-]?\d+)?$',
);
double? parseUiNumber(String text) {
  if (!_completeNumber.hasMatch(text.trim())) return null;
  final value = double.tryParse(text.trim());
  return value?.isFinite == true ? value : null;
}

UiFieldIssue? validateUiField(
  UiResolvedNode node,
  UiValidationResult program, {
  UiFieldDraft? draft,
}) {
  final id = node.declaration.name;
  final props = node.properties;
  final component = node.declaration.component;
  final required = props['required'] == true;
  var value = props['bind'];
  if (draft?.composing == true) return UiFieldIssue(id, UiFieldError.composing);
  if (draft?.rejected == true) {
    return UiFieldIssue(id, UiFieldError.stateBudget);
  }
  if (draft != null && component == 'TextField') value = draft.text;
  if (component == 'NumberField' && draft != null) {
    final text = draft.text.trim();
    if (text.isEmpty) {
      if (required) return UiFieldIssue(id, UiFieldError.required);
      final binding = node.declaration.arguments['bind'];
      final state = binding is UiInputBinding
          ? program.declarations[binding.name]
          : null;
      if (state is! UiStateDeclaration || !state.nullable) {
        return UiFieldIssue(id, UiFieldError.number);
      }
      value = null;
    } else {
      value = parseUiNumber(text);
      if (value == null) return UiFieldIssue(id, UiFieldError.number);
    }
  }
  final empty = value == null || (value is String && value.trim().isEmpty);
  if (required && (empty || (component == 'Checkbox' && value == false))) {
    return UiFieldIssue(id, UiFieldError.required);
  }
  if (empty) return null;
  if (component == 'TextField' && value is String) {
    final length = value.runes.length;
    final min = props['minLength'] as num?;
    final max = props['maxLength'] as num?;
    if (min != null && length < min) {
      return UiFieldIssue(id, UiFieldError.tooShort, min: min);
    }
    if (max != null && length > max) {
      return UiFieldIssue(id, UiFieldError.tooLong, max: max);
    }
  }
  if ((component == 'NumberField' || component == 'Slider') && value is num) {
    final min = props['min'] as num?;
    final max = props['max'] as num?;
    if (!value.isFinite) return UiFieldIssue(id, UiFieldError.number);
    if ((min != null && value < min) || (max != null && value > max)) {
      return UiFieldIssue(id, UiFieldError.range, min: min, max: max);
    }
  }
  if (component == 'Select' || component == 'RadioGroup') {
    final options = props['options'];
    if (options is! List ||
        !options.every((o) => o is Map) ||
        !options.cast<Map>().any((option) => option['value'] == value)) {
      return UiFieldIssue(id, UiFieldError.option);
    }
  }
  return null;
}
