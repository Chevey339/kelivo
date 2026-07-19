/// Synthesize task types for multi-AI conversation synthesis.
enum SynthesizeTaskType { summarize, fuse, comment }

/// A synthesis task descriptor.
///
/// [labelKey], [descriptionKey], and [defaultPromptKey] are ARB keys
/// resolved at the UI layer via [AppLocalizations].
class SynthesizeTask {
  final SynthesizeTaskType type;
  final String labelKey;
  final String descriptionKey;
  final String defaultPromptKey;

  const SynthesizeTask({
    required this.type,
    required this.labelKey,
    required this.descriptionKey,
    required this.defaultPromptKey,
  });
}

/// All available synthesis tasks.
const synthesizeTasks = [
  SynthesizeTask(
    type: SynthesizeTaskType.summarize,
    labelKey: 'multiAISynthesizeTaskSummarize',
    descriptionKey: 'multiAISynthesizeTaskSummarizeDesc',
    defaultPromptKey: 'multiAISynthesizeSummarizePrompt',
  ),
  SynthesizeTask(
    type: SynthesizeTaskType.fuse,
    labelKey: 'multiAISynthesizeTaskFuse',
    descriptionKey: 'multiAISynthesizeTaskFuseDesc',
    defaultPromptKey: 'multiAISynthesizeFusePrompt',
  ),
  SynthesizeTask(
    type: SynthesizeTaskType.comment,
    labelKey: 'multiAISynthesizeTaskComment',
    descriptionKey: 'multiAISynthesizeTaskCommentDesc',
    defaultPromptKey: 'multiAISynthesizeCommentPrompt',
  ),
];
