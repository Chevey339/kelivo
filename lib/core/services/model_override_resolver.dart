import 'dart:collection';

import 'package:flutter/foundation.dart';

import '../models/model_types.dart';
import '../services/logging/flutter_logger.dart';

/// Shared utilities for parsing and applying per-model override maps.
class ModelOverrideResolver {
  static const Set<String> _embeddingTypeStrings = {'embedding', 'embeddings'};
  static const Set<String> _chatTypeStrings = {'chat'};
  static bool _platformLogEnabled = true;
  static bool _unknownValueLoggingEnabled = kDebugMode;

  static void setPlatformLoggingEnabled(bool enabled) {
    _platformLogEnabled = enabled;
  }

  static void setUnknownValueLoggingEnabled(bool enabled) {
    _unknownValueLoggingEnabled = enabled;
  }

  static String _norm(dynamic v) {
    return (v == null ? '' : v.toString()).trim().toLowerCase();
  }

  static ModelType? parseModelTypeOverride(Map ov) {
    final t = _norm(ov['type'] ?? ov['t'] ?? '');
    if (_embeddingTypeStrings.contains(t)) return ModelType.embedding;
    if (_chatTypeStrings.contains(t)) return ModelType.chat;
    return null;
  }

  static List<Modality>? parseModalities(dynamic raw) {
    if (raw is! List) return null;
    if (raw.isEmpty) return const <Modality>[];
    final out = <Modality>[];
    for (final e in raw) {
      final s = _norm(e);
      if (s == 'text') {
        out.add(Modality.text);
      } else if (s == 'image') {
        out.add(Modality.image);
      } else if (s.isNotEmpty) {
        _logUnknown('modality', s);
      }
    }
    if (out.isEmpty) return null;
    return LinkedHashSet<Modality>.from(out).toList(growable: false);
  }

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
      } else if (s.isNotEmpty) {
        _logUnknown('ability', s);
      }
    }
    if (out.isEmpty) return null;
    return LinkedHashSet<ModelAbility>.from(out).toList(growable: false);
  }

  static void _logUnknown(String kind, String value) {
    if (!_unknownValueLoggingEnabled) return;
    if (kDebugMode) {
      debugPrint('[ModelOverride] Unknown $kind value: $value');
    }
    if (_platformLogEnabled) {
      FlutterLogger.log(
        '[ModelOverride] Unknown $kind value: $value',
        tag: 'ModelOverride',
      );
    }
  }

  static String? _parseName(Map ov) {
    final n = ov['name'];
    if (n == null) return null;
    final s = n.toString().trim();
    return s.isEmpty ? null : s;
  }

  static List<Modality> _nonEmptyMods(List<Modality> mods) {
    return mods.isEmpty ? const [Modality.text] : mods;
  }

  /// Apply a per-model override map onto a base [ModelInfo].
  static ModelInfo applyModelOverride(
    ModelInfo base,
    Map ov, {
    bool applyDisplayName = false,
  }) {
    final type = parseModelTypeOverride(ov);
    final effectiveType = type ?? base.type;

    final nameOv = applyDisplayName ? _parseName(ov) : null;
    final displayName = nameOv ?? base.displayName;

    final inputOv = parseModalities(ov['input']);
    final outputOv = (effectiveType == ModelType.embedding)
        ? null
        : parseModalities(ov['output']);
    final abilitiesOv = (effectiveType == ModelType.embedding)
        ? null
        : parseAbilities(ov['abilities']);

    final hasOverrides =
        (type != null && type != base.type) ||
        (nameOv != null && nameOv != base.displayName) ||
        inputOv != null ||
        outputOv != null ||
        abilitiesOv != null;
    if (!hasOverrides) return base;

    if (effectiveType == ModelType.embedding) {
      final inMods = _nonEmptyMods(
        (inputOv ?? base.input).toList(growable: false),
      );
      return base.copyWith(
        displayName: displayName,
        type: ModelType.embedding,
        input: inMods,
        output: const [Modality.text],
        abilities: const <ModelAbility>[],
      );
    }

    final inMods = _nonEmptyMods(
      (inputOv ?? base.input).toList(growable: false),
    );
    final outMods = _nonEmptyMods(
      (outputOv ?? base.output).toList(growable: false),
    );

    return base.copyWith(
      displayName: displayName,
      type: effectiveType,
      input: inMods,
      output: outMods,
      abilities: abilitiesOv ?? base.abilities,
    );
  }
}
