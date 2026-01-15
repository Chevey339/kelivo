import 'dart:collection';

import '../models/model_types.dart';

/// Shared utilities for parsing and applying per-model override maps.
///
/// Goals:
/// - Robust parsing: trim + lowercase; ignore unknown values (do not coerce).
/// - Enforce embedding invariants: text-only output + no abilities.
/// - Keep behavior consistent across UI and config resolution.
class ModelOverrideResolver {
  static const Set<String> _embeddingTypeStrings = {'embedding', 'embeddings'};
  static const Set<String> _chatTypeStrings = {'chat'};

  static String _norm(dynamic v) => (v == null ? '' : v.toString()).trim().toLowerCase();

  /// Parse model type override.
  ///
  /// Back-compat: supports both `type` and legacy short key `t`.
  static ModelType? parseModelTypeOverride(Map ov) {
    final t = _norm(ov['type'] ?? ov['t'] ?? '');
    if (_embeddingTypeStrings.contains(t)) return ModelType.embedding;
    if (_chatTypeStrings.contains(t)) return ModelType.chat;
    return null;
  }

  /// Parse modality list override.
  ///
  /// Returns null only when the raw input is not a List.
  /// Returns an empty list when the list is empty or contains no valid values.
  static List<Modality>? parseModalities(dynamic raw) {
    if (raw is! List) return null;
    // Explicit empty list => clear to default text (handled by _nonEmptyMods).
    if (raw.isEmpty) return const <Modality>[];
    final out = <Modality>[];
    for (final e in raw) {
      final s = _norm(e);
      if (s == 'text') {
        out.add(Modality.text);
      } else if (s == 'image') {
        out.add(Modality.image);
      }
    }
    if (out.isEmpty) return const <Modality>[];
    // Dedupe while preserving order. Lists are typically tiny, so this is fine.
    return LinkedHashSet<Modality>.from(out).toList(growable: false);
  }

  /// Parse model ability list override.
  ///
  /// Returns null only when the raw input is not a List.
  /// Returns an empty list when the list is empty or contains no valid values.
  static List<ModelAbility>? parseAbilities(dynamic raw) {
    if (raw is! List) return null;
    if (raw.isEmpty) return const <ModelAbility>[];
    final out = <ModelAbility>[];
    for (final e in raw) {
      final s = _norm(e);
      if (s == 'tool') {
        out.add(ModelAbility.tool);
      } else if (s == 'reasoning') {
        out.add(ModelAbility.reasoning);
      }
    }
    if (out.isEmpty) return const <ModelAbility>[];
    // Dedupe while preserving order. Lists are typically tiny, so this is fine.
    return LinkedHashSet<ModelAbility>.from(out).toList(growable: false);
  }

  static String? _parseName(Map ov) {
    final n = ov['name'];
    if (n == null) return null;
    final s = n.toString().trim();
    return s.isEmpty ? null : s;
  }

  static List<Modality> _nonEmptyMods(List<Modality> mods) => mods.isEmpty ? const [Modality.text] : mods;

  /// Apply a per-model override map onto a base [ModelInfo].
  ///
  /// - Type: override -> base fallback
  /// - Embedding: forces text-only output and clears abilities
  /// - Chat: input/output default to base then `[text]` when empty
  static ModelInfo applyModelOverride(ModelInfo base, Map ov, {bool applyDisplayName = false}) {
    final type = parseModelTypeOverride(ov);
    final effectiveType = type ?? base.type;

    final nameOv = applyDisplayName ? _parseName(ov) : null;
    final displayName = nameOv ?? base.displayName;

    final inputOv = parseModalities(ov['input']);
    final outputOv = (effectiveType == ModelType.embedding) ? null : parseModalities(ov['output']);
    final abilitiesOv = (effectiveType == ModelType.embedding) ? null : parseAbilities(ov['abilities']);

    final hasOverrides = (type != null && type != base.type) ||
        (nameOv != null && nameOv != base.displayName) ||
        inputOv != null ||
        outputOv != null ||
        abilitiesOv != null;
    if (!hasOverrides) return base;

    if (effectiveType == ModelType.embedding) {
      final inMods = _nonEmptyMods((inputOv ?? base.input).toList(growable: false));
      return base.copyWith(
        displayName: displayName,
        type: ModelType.embedding,
        input: inMods,
        output: const [Modality.text],
        abilities: const <ModelAbility>[],
      );
    }

    final inMods = _nonEmptyMods((inputOv ?? base.input).toList(growable: false));
    final outMods = _nonEmptyMods((outputOv ?? base.output).toList(growable: false));

    return base.copyWith(
      displayName: displayName,
      type: effectiveType,
      input: inMods,
      output: outMods,
      abilities: abilitiesOv ?? base.abilities,
    );
  }
}

