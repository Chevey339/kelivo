import 'package:Kelivo/core/database/generation_run.dart';
import 'package:Kelivo/core/models/chat_message.dart';
import '../runtime/ui_surface_controller.dart';

/// A real fence closer is only half the gate. Reuse the host's authoritative
/// run state; a missing historical outcome cannot unlock an interactive card.
UiGenerationStatus uiGenerationStatus(ChatMessage message) =>
    switch (message.generationState) {
      GenerationRunState.completed => UiGenerationStatus.complete,
      GenerationRunState.failed ||
      GenerationRunState.cancelled ||
      GenerationRunState.interrupted => UiGenerationStatus.interrupted,
      GenerationRunState.preparing ||
      GenerationRunState.requesting ||
      GenerationRunState.streaming ||
      GenerationRunState.waitingTool => UiGenerationStatus.generating,
      null =>
        message.isStreaming
            ? UiGenerationStatus.generating
            : UiGenerationStatus.interrupted,
    };
