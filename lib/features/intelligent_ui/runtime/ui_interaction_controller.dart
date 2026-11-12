import 'package:Kelivo/features/intelligent_ui/catalog/ui_budgets.dart';
import 'package:Kelivo/features/intelligent_ui/protocol/ui_ir.dart';
import 'package:Kelivo/features/intelligent_ui/runtime/ui_form_validation.dart';
import 'package:Kelivo/features/intelligent_ui/runtime/ui_resolved_node.dart';
import 'package:Kelivo/features/intelligent_ui/runtime/ui_surface_controller.dart';
import 'package:Kelivo/features/intelligent_ui/runtime/ui_surface_state.dart';

/// A local, frozen observation. Producing this value does not send a message or
/// change a composer; only an explicitly connected host may consume it.
final class UiAskIntent {
  const UiAskIntent({
    required this.owner,
    required this.sourceHash,
    required this.node,
    required this.text,
    required this.context,
    required this.read,
    required this.snapshot,
  });
  final UiSurfaceOwner owner;
  final String sourceHash, node, text;
  final Map<String, Object?> context;
  final UiSurfaceRead read;
  final UiSurfaceSnapshot snapshot;
}

/// A coherent snapshot captured by an explicit host Attach action.
final class UiAttachIntent {
  const UiAttachIntent({required this.read, required this.snapshot});
  final UiSurfaceRead read;
  final UiSurfaceSnapshot snapshot;
}

enum UiActionBlock { stale, readOnly, unavailable, disabled, dependency, form }

final class UiActionResult {
  const UiActionResult({this.intent, this.attachment, this.block, this.form});
  final UiAskIntent? intent;
  final UiAttachIntent? attachment;
  final UiActionBlock? block;
  final UiFormCheck? form;
  bool get accepted => block == null;
}

/// Ephemeral interaction state, separate from normalized persisted inputs.
/// A host can move this owner between the inline and expanded control tree.
final class UiInteractionController {
  UiInteractionController(this.surface) {
    _source = surface.parsed;
    _epoch = surface.token.epoch;
    _subscriptions.add(surface.listenNode('root', _sourceChanged));
    _subscriptions.add(surface.listenReset(_reset));
    _subscribeNodes();
  }
  final UiSurfaceController surface;
  final _subscriptions = <void Function()>[];
  final _nodeSubscriptions = <void Function()>[];
  final _listeners = <String, Map<Object, void Function()>>{};
  final _drafts = <String, ({UiFieldDraft draft, Object? base})>{};
  final _tableFilters = <String, ({String text, String base, bool failed})>{};

  ({String text, bool failed})? tableFilterDraft(String id, String committed) {
    final pending = _tableFilters[id];
    if (pending == null) return null;
    if (pending.base != committed) {
      _tableFilters.remove(id);
      return null;
    }
    return (text: pending.text, failed: pending.failed);
  }

  void rememberTableFilter(
    String id,
    String text, {
    required String committed,
    required bool failed,
    required UiRuntimeToken token,
  }) {
    if (_disposed || !surface.accepts(token)) return;
    if (text == committed) {
      _tableFilters.remove(id);
      return;
    }
    _tableFilters[id] = (text: text, base: committed, failed: failed);
  }

  final _touched = <String>{};
  final _submitted = <String>{};
  final _editing = <String>{};
  Object? _source;
  int _epoch = 0;
  int _treeSequence = -1;
  UiControlTree? _tree;
  bool _disposed = false;

  UiControlTree get tree {
    if (_tree == null || _treeSequence != surface.sequence) {
      _tree = UiControlTree(surface.nodes);
      _treeSequence = surface.sequence;
    }
    return _tree!;
  }

  UiFieldDraft? draft(String id) => _drafts[id]?.draft;
  Map<String, UiFieldDraft> get drafts =>
      Map.unmodifiable(_drafts.map((key, value) => MapEntry(key, value.draft)));
  bool submitted(String form) => _submitted.contains(form);
  UiFormCheck checkForm(String id) =>
      validateUiForm(id, surface.parsed.program, tree, drafts: drafts);
  UiFieldIssue? issue(String id) {
    final form = tree.forms[id];
    if (!_touched.contains(id) &&
        (form == null || !_submitted.contains(form))) {
      return null;
    }
    final node = surface.nodes[id];
    if (node?.valid != true ||
        tree.visible[id] != true ||
        tree.enabled[id] != true) {
      return null;
    }
    final result = validateUiField(
      node!,
      surface.parsed.program,
      draft: draft(id),
    );
    // Composition is an editing state, not a red error while typing.
    return result?.error == UiFieldError.composing ? null : result;
  }

  void _sourceChanged() {
    if (identical(_source, surface.parsed)) return;
    _source = surface.parsed;
    _tree = null;
    if (_epoch != surface.token.epoch) {
      _epoch = surface.token.epoch;
      _reset();
    }
    _subscribeNodes();
  }

  void _subscribeNodes() {
    for (final stop in _nodeSubscriptions) {
      stop();
    }
    _nodeSubscriptions.clear();
    for (final id in surface.nodes.keys) {
      _nodeSubscriptions.add(
        surface.listenNode(id, () {
          final pending = _drafts[id];
          if (!_editing.contains(id) &&
              pending != null &&
              pending.base != surface.nodes[id]?.properties['bind']) {
            _drafts.remove(id);
          }
          _notify(id);
          _notifyFormsFor(id);
        }),
      );
    }
  }

  void _reset() {
    final affected = {
      ..._drafts.keys,
      ..._tableFilters.keys,
      ..._touched,
      ..._submitted,
    };
    _tableFilters.clear();
    _drafts.clear();
    _touched.clear();
    _submitted.clear();
    for (final id in affected) {
      _notify(id);
    }
  }

  bool _canEdit(String id, UiRuntimeToken token) =>
      !_disposed &&
      surface.accepts(token) &&
      !surface.readOnly &&
      tree.visible[id] == true &&
      tree.enabled[id] == true;

  UiMutationResult editText(
    String id,
    UiFieldDraft draft, {
    required UiRuntimeToken token,
    bool finish = false,
  }) {
    if (!surface.accepts(token) || _disposed) return UiMutationResult.stale;
    if (!_canEdit(id, token)) {
      final pending = _drafts[id];
      // Disabling a focused field ends the platform composition. Retain that
      // same text as a finished draft, without mutating a disabled input. A
      // later explicit submit validates and commits it if the field is active.
      if (finish &&
          !surface.readOnly &&
          pending != null &&
          pending.draft.composing &&
          !draft.composing &&
          pending.draft.text == draft.text) {
        _drafts[id] = (draft: draft, base: pending.base);
        _notify(id);
        _notifyFormsFor(id);
        return UiMutationResult.unchanged;
      }
      return UiMutationResult.readOnly;
    }
    final node = surface.nodes[id]!;
    final kind = node.declaration.component;
    final binding = node.declaration.arguments['bind'];
    if ((kind != 'TextField' && kind != 'NumberField') ||
        binding is! UiInputBinding) {
      return UiMutationResult.invalid;
    }
    surface.noteInteraction(token: token);
    _drafts[id] = (draft: draft, base: node.properties['bind']);
    // A binding has one current user draft. Starting an edit (including IME or
    // an incomplete number) supersedes drafts in other controls for that same
    // input, just as a committed edit does. Hidden aliases do not own a second
    // independent value and cannot later overwrite the newer interaction.
    _supersedeDrafts(binding.name, except: id);
    if (finish) _touched.add(id);
    var result = UiMutationResult.unchanged;
    if (!draft.composing) {
      final validation = validateUiField(
        node,
        surface.parsed.program,
        draft: draft,
      );
      final canCommit =
          kind == 'TextField' ||
          (validation == null && (draft.text.trim().isNotEmpty || finish));
      if (canCommit) {
        final Object? value = kind == 'TextField'
            ? draft.text
            : parseUiNumber(draft.text);
        _editing.add(id);
        try {
          result = surface.setInputs({binding.name: value}, token: token);
        } finally {
          _editing.remove(id);
        }
        if (result == UiMutationResult.accepted ||
            result == UiMutationResult.unchanged) {
          _supersedeDrafts(binding.name, except: id);
        }
        _drafts[id] = (
          draft: UiFieldDraft(
            draft.text,
            rejected: result == UiMutationResult.invalid,
          ),
          base: surface.nodes[id]?.properties['bind'],
        );
      }
    }
    _notify(id);
    _notifyFormsFor(id);
    if (finish) surface.flushQuietly();
    return result;
  }

  void blur(String id, {required UiRuntimeToken token}) {
    final pending = draft(id);
    if (pending != null) {
      editText(id, pending, token: token, finish: true);
    } else if (_canEdit(id, token)) {
      _touched.add(id);
      _notify(id);
      surface.flushQuietly();
    }
  }

  /// A platform editor was removed. This is metadata only, even if the DSL
  /// field is still active (for example after viewport eviction). A late
  /// disposal must not finish a newer editor's composition.
  void endComposition(
    String id,
    UiFieldDraft expected, {
    required UiRuntimeToken token,
  }) {
    if (_disposed || !surface.accepts(token)) return;
    final pending = _drafts[id];
    if (pending == null ||
        !identical(pending.draft, expected) ||
        !expected.composing) {
      return;
    }
    _drafts[id] = (
      draft: UiFieldDraft(expected.text, rejected: expected.rejected),
      base: pending.base,
    );
    _notify(id);
    _notifyFormsFor(id);
  }

  UiMutationResult setValue(
    String id,
    Object? value, {
    required UiRuntimeToken token,
    bool flush = true,
  }) {
    if (!surface.accepts(token) || _disposed) return UiMutationResult.stale;
    if (!_canEdit(id, token)) return UiMutationResult.readOnly;
    final binding = surface.nodes[id]!.declaration.arguments['bind'];
    if (binding is! UiInputBinding) return UiMutationResult.invalid;
    final node = surface.nodes[id]!;
    final issue = validateUiField(
      UiResolvedNode(
        declaration: node.declaration,
        properties: {...node.properties, 'bind': value},
        diagnostics: const [],
        gaps: node.gaps,
      ),
      surface.parsed.program,
    );
    if (const {
      UiFieldError.number,
      UiFieldError.range,
      UiFieldError.option,
    }.contains(issue?.error)) {
      return UiMutationResult.invalid;
    }
    _touched.add(id);
    final result = surface.setInputs({binding.name: value}, token: token);
    if (result == UiMutationResult.accepted ||
        result == UiMutationResult.unchanged) {
      _supersedeDrafts(binding.name);
    }
    _notify(id);
    if (flush) surface.flushQuietly();
    return result;
  }

  void _supersedeDrafts(String binding, {String? except}) {
    for (final id in _drafts.keys.toList()) {
      final slot = surface.nodes[id]?.declaration.arguments['bind'];
      if (id != except && slot is UiInputBinding && slot.name == binding) {
        _drafts.remove(id);
        _notify(id);
        _notifyFormsFor(id);
      }
    }
  }

  UiActionResult activate(String id, {required UiRuntimeToken token}) {
    if (_disposed || !surface.accepts(token)) {
      return const UiActionResult(block: UiActionBlock.stale);
    }
    if (surface.readOnly) {
      return const UiActionResult(block: UiActionBlock.readOnly);
    }
    final node = surface.nodes[id];
    if (node == null || node.declaration.component != 'Button') {
      return const UiActionResult(block: UiActionBlock.unavailable);
    }
    if (!node.valid) {
      return const UiActionResult(block: UiActionBlock.dependency);
    }
    if (tree.visible[id] != true || tree.enabled[id] != true) {
      return const UiActionResult(block: UiActionBlock.disabled);
    }
    final action = node.declaration.arguments['action'];
    if (action is UiReset) {
      surface.reset(token: token);
      surface.flushQuietly();
      return const UiActionResult();
    }
    if (action is! UiAsk || node.askText == null || node.askContext == null) {
      return const UiActionResult(block: UiActionBlock.unavailable);
    }
    final form = node.properties['form'] as String?;
    if (form != null) {
      if (tree.visible[form] != true || tree.enabled[form] != true) {
        return const UiActionResult(block: UiActionBlock.disabled);
      }
      _submitted.add(form);
    }
    final failure = _settleDrafts(token: token, action: id, form: form);
    if (failure != null) return failure;
    if (!surface.accepts(token)) {
      return const UiActionResult(block: UiActionBlock.stale);
    }
    final ready = surface.nodes[id]!;
    if (!ready.valid) {
      return const UiActionResult(block: UiActionBlock.dependency);
    }
    if (tree.visible[id] != true || tree.enabled[id] != true) {
      return const UiActionResult(block: UiActionBlock.disabled);
    }
    // The semantic projector selects complete fields under the model-content
    // budget and explicitly reports omissions. Never truncate serialized JSON.
    surface.flushQuietly();
    // Everything below comes from one synchronous completed batch.
    final read = surface.captureRead();
    final current = read.nodes[id]!;
    return UiActionResult(
      intent: UiAskIntent(
        owner: surface.owner,
        sourceHash: surface.sourceHash!,
        node: id,
        text: current.askText!,
        context: current.askContext!,
        read: read,
        snapshot: surface.captureSnapshot(),
      ),
    );
  }

  /// Explicit host attachment settles the visible field drafts, but does not
  /// require untouched incomplete forms to become valid before describing them.
  UiActionResult captureForAttach({required UiRuntimeToken token}) {
    if (_disposed || !surface.accepts(token)) {
      return const UiActionResult(block: UiActionBlock.stale);
    }
    if (surface.readOnly) {
      return const UiActionResult(block: UiActionBlock.readOnly);
    }
    final failure = _settleDrafts(token: token);
    if (failure != null) return failure;
    if (!surface.accepts(token)) {
      return const UiActionResult(block: UiActionBlock.stale);
    }
    if (!surface.canSnapshot || surface.readOnly) {
      return const UiActionResult(block: UiActionBlock.readOnly);
    }
    surface.flushQuietly();
    return UiActionResult(
      attachment: UiAttachIntent(
        read: surface.captureRead(),
        snapshot: surface.captureSnapshot(),
      ),
    );
  }

  UiActionResult? _settleDrafts({
    required UiRuntimeToken token,
    String? action,
    String? form,
  }) {
    UiActionResult? failure(UiFormCheck result) {
      if (form != null) _notify(form);
      for (final issue in result.issues) {
        _touched.add(issue.node);
        _notify(issue.node);
      }
      return result.valid
          ? null
          : UiActionResult(block: UiActionBlock.form, form: result);
    }

    // Committing a draft can reveal another field. Reach a bounded fixed point
    // before capture; each accepted pass settles at least one pending binding.
    for (var pass = 0; pass <= UiBudgets.inputs; pass++) {
      if (form != null &&
          (tree.visible[form] != true || tree.enabled[form] != true)) {
        return const UiActionResult(block: UiActionBlock.disabled);
      }
      final draftIds = action == null
          ? [
              for (final id in tree.order)
                if (_drafts.containsKey(id) &&
                    tree.visible[id] == true &&
                    tree.enabled[id] == true)
                  id,
            ]
          : _actionDraftIds(action, form);
      final formCheck = form == null
          ? UiFormCheck(const [], const [])
          : checkForm(form);
      final checked = failure(
        UiFormCheck([
          ...formCheck.issues,
          for (final field in draftIds)
            if (form == null || !tree.belongsTo(field, form))
              if (validateUiField(
                    surface.nodes[field]!,
                    surface.parsed.program,
                    draft: draft(field),
                  )
                  case final issue?)
                issue,
        ], formCheck.unavailable),
      );
      if (checked != null) return checked;
      final changes = <String, Object?>{};
      final commitIds = <String>[];
      for (final field in draftIds) {
        final fieldNode = surface.nodes[field]!;
        final pending = draft(field)!;
        final value = fieldNode.declaration.component == 'TextField'
            ? pending.text
            : parseUiNumber(pending.text);
        if (fieldNode.properties['bind'] != value) {
          final binding =
              fieldNode.declaration.arguments['bind'] as UiInputBinding;
          changes[binding.name] = value;
          commitIds.add(field);
        }
      }
      if (changes.isEmpty) break;
      if (pass == UiBudgets.inputs) {
        return const UiActionResult(block: UiActionBlock.dependency);
      }
      _editing.addAll(commitIds);
      UiMutationResult result;
      try {
        result = surface.setInputs(changes, token: token);
      } finally {
        _editing.removeAll(commitIds);
      }
      if (result == UiMutationResult.stale ||
          result == UiMutationResult.readOnly) {
        return UiActionResult(
          block: result == UiMutationResult.stale
              ? UiActionBlock.stale
              : UiActionBlock.readOnly,
        );
      }
      if (result == UiMutationResult.invalid) {
        return failure(
          UiFormCheck([
            for (final field in draftIds)
              UiFieldIssue(field, UiFieldError.stateBudget),
          ], const []),
        )!;
      }
      for (final field in commitIds) {
        final pending = _drafts[field];
        if (pending != null) {
          _drafts[field] = (
            draft: pending.draft,
            base: surface.nodes[field]?.properties['bind'],
          );
        }
      }
    }
    return null;
  }

  List<String> _actionDraftIds(String action, String? form) {
    final dependencies = <String>{};
    final pending = [action];
    while (pending.isNotEmpty) {
      final id = pending.removeLast();
      if (dependencies.add(id)) {
        pending.addAll(surface.parsed.program.dependencies[id] ?? const {});
      }
    }
    return [
      for (final id in tree.order)
        if (_drafts.containsKey(id) &&
            tree.visible[id] == true &&
            tree.enabled[id] == true &&
            ((form != null && tree.belongsTo(id, form)) ||
                (surface.nodes[id]?.declaration.arguments['bind']
                        is UiInputBinding &&
                    dependencies.contains(
                      (surface.nodes[id]!.declaration.arguments['bind']
                              as UiInputBinding)
                          .name,
                    ))))
          id,
    ];
  }

  String? submitButtonFor(String field) {
    final form = tree.forms[field];
    if (form == null) return null;
    for (final id in tree.order) {
      final node = surface.nodes[id];
      if (node?.declaration.arguments['action'] is UiAsk &&
          node?.properties['form'] == form &&
          tree.visible[id] == true &&
          tree.enabled[id] == true) {
        return id;
      }
    }
    return null;
  }

  void Function() listen(String id, void Function() listener) {
    if (_disposed) throw StateError('Disposed interaction owner');
    final key = Object();
    _listeners.putIfAbsent(id, () => {})[key] = listener;
    return () => _listeners[id]?.remove(key);
  }

  void _notifyFormsFor(String id) {
    for (final form in _listeners.keys.toList()) {
      if (form != id &&
          surface.nodes[form]?.declaration.component == 'Form' &&
          tree.belongsTo(id, form)) {
        _notify(form);
      }
    }
  }

  void _notify(String id) {
    final listeners = _listeners[id];
    if (listeners == null) return;
    for (final entry in listeners.entries.toList()) {
      if (listeners.containsKey(entry.key)) entry.value();
    }
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    for (final stop in [..._subscriptions, ..._nodeSubscriptions]) {
      stop();
    }
    _listeners.clear();
    _drafts.clear();
  }
}
