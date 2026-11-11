import 'dart:convert';

import 'package:Kelivo/features/intelligent_ui/catalog/ui_budgets.dart';
import 'package:Kelivo/features/intelligent_ui/protocol/ui_ir.dart';
import 'package:Kelivo/features/intelligent_ui/protocol/ui_validation.dart';

/// Durable identity. A controller instance and its epoch are deliberately absent.
final class UiSurfaceOwner {
  const UiSurfaceOwner({required this.revisionId, required this.surfaceKey});
  final String revisionId;
  final String surfaceKey;

  @override
  bool operator ==(Object other) =>
      other is UiSurfaceOwner &&
      revisionId == other.revisionId &&
      surfaceKey == other.surfaceKey;

  @override
  int get hashCode => Object.hash(revisionId, surfaceKey);
}

/// Version 1 contains scalar overrides and a closed set of local view settings.
/// All callers (save, restore and merge fingerprints) use this normalization.
final class UiSurfaceState {
  UiSurfaceState._(this.inputs, this.view, this.json);
  static const version = 1;
  final Map<String, Object?> inputs;
  final Map<String, Map<String, Object?>> view;
  final String json;
  bool get isDefault => inputs.isEmpty && view.isEmpty;

  factory UiSurfaceState.normalize(
    UiValidationResult program, {
    Map<String, Object?> inputs = const {},
    Map<String, Map<String, Object?>> view = const {},
  }) {
    final normalizedInputs = <String, Object?>{};
    for (final name in inputs.keys.toList()..sort()) {
      final state = program.declarations[name];
      if (state is! UiStateDeclaration ||
          program.failedSymbols.contains(name)) {
        throw const FormatException('Unknown or invalid input');
      }
      final raw = inputs[name];
      if (!(raw == null
          ? state.nullable
          : switch (state.type) {
              UiScalarType.number => raw is num && raw.isFinite,
              UiScalarType.string => raw is String,
              UiScalarType.boolean => raw is bool,
            })) {
        throw const FormatException('Invalid input type');
      }
      final value = raw is num ? (raw == 0 ? 0.0 : raw.toDouble()) : raw;
      if (value != state.initialValue) normalizedInputs[name] = value;
    }
    final normalizedView = <String, Map<String, Object?>>{};
    for (final name in view.keys.toList()..sort()) {
      final node = program.declarations[name];
      if (node is! UiNodeDeclaration ||
          !const {'DataTable', 'Chart'}.contains(node.component) ||
          program.failedSymbols.contains(name)) {
        throw const FormatException('Unknown or invalid view');
      }
      final settings = _normalizeView(node, view[name]!);
      if (settings.isNotEmpty) {
        normalizedView[name] = Map.unmodifiable(settings);
      }
    }
    final json = jsonEncode({
      'inputs': normalizedInputs,
      'view': normalizedView,
    });
    if (utf8.encode(json).length > UiBudgets.stateBytes) {
      throw const FormatException('State exceeds byte budget');
    }
    return UiSurfaceState._(
      Map.unmodifiable(normalizedInputs),
      Map.unmodifiable(normalizedView),
      json,
    );
  }

  factory UiSurfaceState.decode(
    UiValidationResult program,
    String json, {
    required int stateVersion,
  }) {
    if (stateVersion != version ||
        json.length > UiBudgets.stateBytes ||
        utf8.encode(json).length > UiBudgets.stateBytes) {
      throw const FormatException('Unsupported state format or size');
    }
    final raw = jsonDecode(json);
    if (raw is! Map<String, dynamic> ||
        raw.length != 2 ||
        raw['inputs'] is! Map<String, dynamic> ||
        raw['view'] is! Map<String, dynamic>) {
      throw const FormatException('Invalid state object');
    }
    final views = <String, Map<String, Object?>>{};
    for (final entry in (raw['view'] as Map<String, dynamic>).entries) {
      if (entry.value is! Map<String, dynamic>) {
        throw const FormatException('Invalid view object');
      }
      views[entry.key] = entry.value as Map<String, dynamic>;
    }
    return UiSurfaceState.normalize(
      program,
      inputs: raw['inputs'] as Map<String, dynamic>,
      view: views,
    );
  }

  static Map<String, Object?> _normalizeView(
    UiNodeDeclaration node,
    Map<String, Object?> raw,
  ) {
    final result = <String, Object?>{};
    final allowed = {
      'sortKey',
      'descending',
      'filter',
      'page',
      'pageSize',
      if (node.component == 'Chart') ...['dataView', 'hiddenSeries'],
    };
    if (raw.keys.any((key) => !allowed.contains(key))) {
      throw const FormatException('Unknown view setting');
    }
    for (final key in raw.keys.toList()..sort()) {
      final value = raw[key];
      switch (key) {
        case 'dataView' || 'descending':
          if (value is! bool) throw const FormatException('Expected boolean');
          if (value) result[key] = value;
        case 'hiddenSeries':
          if (value is! List || value.length > UiBudgets.pieItems) {
            throw const FormatException('Invalid hidden series');
          }
          final indices = <int>{};
          for (final item in value) {
            if (item is! num ||
                !item.isFinite ||
                item < 0 ||
                item >= UiBudgets.pieItems ||
                item != item.truncateToDouble()) {
              throw const FormatException('Invalid series index');
            }
            indices.add(item.toInt());
          }
          if (indices.isNotEmpty) {
            result[key] = List<int>.unmodifiable(indices.toList()..sort());
          }
        case 'sortKey':
          if (value != null &&
              (value is! String || value.isEmpty || value.length > 128)) {
            throw const FormatException('Invalid sort key');
          }
          if (value != null) result[key] = value;
        case 'filter':
          if (value is! String ||
              value.length > UiBudgets.tableFilterCodeUnits) {
            throw const FormatException('Invalid filter');
          }
          if (value.isNotEmpty) result[key] = value;
        case 'page':
          if (value is! num ||
              !value.isFinite ||
              value < 0 ||
              value >= UiBudgets.tableRows ||
              value != value.truncateToDouble()) {
            throw const FormatException('Invalid page');
          }
          if (value != 0) result[key] = value.toInt();
        case 'pageSize':
          if (value is! num || (value != 10 && value != 20)) {
            throw const FormatException('Invalid page size');
          }
          final declared = node.arguments['pageSize'];
          final defaultValue = declared == null
              ? 10
              : declared is UiLiteral
              ? declared.value
              : null;
          // A dynamic source default can change with inputs. An explicit
          // choice pins the page size until Reset; literal defaults normalize.
          if (value != defaultValue) result[key] = value.toInt();
      }
    }
    if (!result.containsKey('sortKey')) {
      result.remove('descending');
    }
    return result;
  }
}

final class UiSurfaceSnapshot {
  const UiSurfaceSnapshot({
    required this.owner,
    required this.sourceHash,
    required this.state,
  });
  final UiSurfaceOwner owner;
  final String sourceHash;
  final UiSurfaceState state;
  int get stateVersion => UiSurfaceState.version;
}
