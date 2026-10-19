/// Shared rendering budgets. These are fixed policy, not user settings.
abstract final class PerformanceLimits {
  static const streamingTableRows = 30;
  static const highlightLines = 300;
  static const highlightCharacters = 12000;
  static const virtualCodeLines = 1000;
  static const codeChunkLines = 200;
  static const initialTableRows = 40;
  static const tablePageRows = 100;
  static const coalescingCharacters = 8000;
  static const coalescingInterval = Duration(milliseconds: 50);
  static const streamingNativeCharacters = 512;
  static const staticNativeCharacters = 2048;
  static const paragraphRunCharacters = 4096;
  static const nativeParagraphPaintCount = 8;
  static const tableImagePixels = 64000000;
  static const tableImageDimension = 32767;
}
