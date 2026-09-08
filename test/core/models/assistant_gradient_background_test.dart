import 'package:Kelivo/core/models/assistant.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('gradient setting persists and toggling preserves the wallpaper', () {
    const assistant = Assistant(
      id: 'a',
      name: 'A',
      background: '/wallpaper.png',
    );
    final enabled = Assistant.fromJson(
      assistant.copyWith(useGradientBackground: true).toJson(),
    );
    expect(enabled.useGradientBackground, isTrue);
    expect(enabled.copyWith(name: 'B').useGradientBackground, isTrue);
    final disabled = Assistant.fromJson(
      enabled.copyWith(useGradientBackground: false).toJson(),
    );
    expect(disabled.useGradientBackground, isFalse);
    expect(disabled.background, assistant.background);
    expect(Assistant.fromJson({'id': 'a'}).useGradientBackground, isFalse);
  });
  test('static position survives serialization and assistant copies', () {
    final assistant = const Assistant(id: 'a', name: 'A').copyWith(
      useGradientBackground: true,
      gradientBackgroundAnimated: false,
      gradientBackgroundPhase: 7.25,
      gradientBackgroundOffsetX: -0.4,
      gradientBackgroundOffsetY: 0.7,
    );
    final restored = Assistant.fromJson(assistant.toJson()).copyWith(id: 'b');
    expect(restored.gradientBackgroundAnimated, isFalse);
    expect(restored.gradientBackgroundPhase, 7.25);
    expect(restored.gradientBackgroundOffsetX, -0.4);
    expect(restored.gradientBackgroundOffsetY, 0.7);
    expect(
      Assistant.fromJson({
        'id': 'c',
        'gradientBackgroundOffsetX': 5,
      }).gradientBackgroundOffsetX,
      1,
    );
  });
}
