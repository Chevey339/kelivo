/// Provider artifact kind under which a Gemini turn's thought signatures are
/// stored against the assistant message that produced them.
const String geminiThoughtSignatureArtifactKind = 'gemini_thought_signature';

/// Internal message key carrying the stored signatures into the next request.
/// Stripped before anything reaches the wire, like the other `_kelivo_` keys.
const String multimodalInternalGeminiThoughtSignatureKey =
    '_kelivo_gemini_thought_signature';
