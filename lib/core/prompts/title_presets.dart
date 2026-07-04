import 'constants/title_prompts.dart';
import 'prompt_preset.dart';

class TitlePresets {
  static final List<PromptPreset> all = [
    const PromptPreset(id: 'standard', prompt: defaultTitlePrompt),
    const PromptPreset(id: 'emoji', prompt: emojiTitlePrompt),
  ];

  static String? detect(String text) {
    final norm = text.trim();
    for (final p in all) {
      if (norm == p.prompt.trim()) return p.id;
    }
    return null;
  }

  static PromptPreset? byId(String id) {
    for (final p in all) {
      if (p.id == id) return p;
    }
    return null;
  }
}
