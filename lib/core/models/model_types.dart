import 'package:flutter/foundation.dart';

enum ModelType { chat, embedding }

enum Modality { text, image }

enum ModelAbility { tool, reasoning }

@immutable
class ModelInfo {
  final String id;
  final String displayName;
  final ModelType type;
  final List<Modality> input;
  final List<Modality> output;
  final List<ModelAbility> abilities;

  ModelInfo({
    required this.id,
    required this.displayName,
    this.type = ModelType.chat,
    this.input = const [Modality.text],
    this.output = const [Modality.text],
    this.abilities = const [],
  });

  ModelInfo copyWith({
    String? id,
    String? displayName,
    ModelType? type,
    List<Modality>? input,
    List<Modality>? output,
    List<ModelAbility>? abilities,
  }) {
    return ModelInfo(
      id: id ?? this.id,
      displayName: displayName ?? this.displayName,
      type: type ?? this.type,
      input: input ?? this.input,
      output: output ?? this.output,
      abilities: abilities ?? this.abilities,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other is ModelInfo &&
            runtimeType == other.runtimeType &&
            id == other.id &&
            displayName == other.displayName &&
            type == other.type &&
            listEquals(input, other.input) &&
            listEquals(output, other.output) &&
            listEquals(abilities, other.abilities));
  }

  @override
  int get hashCode => Object.hash(
        id,
        displayName,
        type,
        Object.hashAll(input),
        Object.hashAll(output),
        Object.hashAll(abilities),
      );
}

