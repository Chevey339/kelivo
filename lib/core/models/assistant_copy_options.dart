/// Defaults match the existing assistant copy behavior. A null memory ID set
/// selects all of that assistant's memories; an empty set selects none.
class AssistantCopyOptions {
  const AssistantCopyOptions({
    this.memories = false,
    this.memoryIds,
    this.legacyMemoryIds,
    this.quickPhrases = false,
    this.regexRules = true,
    this.worldBooks = false,
    this.instructionInjections = false,
    this.skills = true,
    this.mcp = true,
    this.tools = true,
    this.workspace = true,
  });

  const AssistantCopyOptions.all()
    : this(
        memories: true,
        quickPhrases: true,
        worldBooks: true,
        instructionInjections: true,
      );

  final bool memories;
  final Set<String>? memoryIds;
  final Set<int>? legacyMemoryIds;
  final bool quickPhrases;
  final bool regexRules;
  final bool worldBooks;
  final bool instructionInjections;
  final bool skills;
  final bool mcp;
  final bool tools;
  final bool workspace;
}
