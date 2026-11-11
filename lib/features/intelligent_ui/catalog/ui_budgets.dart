/// Inclusive implementation limits, shared by the parser and runtime.
abstract final class UiBudgets {
  static const sourceBytes = 256 * 1024;
  static const declarationBytes = 128 * 1024;
  static const blocksPerMessage = 3;
  static const webBlocksPerMessage = 3;
  static const components = 256;
  static const inputs = 64;
  static const declarations = 512;
  static const componentDepth = 16;
  static const expressionDepth = 32;
  static const operationsPerBatch = 50000;
  static const sampleMin = 2;
  static const sampleMax = 501;
  static const chartSeries = 4;
  static const chartPoints = 2000;
  static const pieItems = 12;
  static const tableRows = 1000;
  static const tableColumns = 8;
  static const tableFilterCodeUnits = 256;
  static const stateBytes = 32 * 1024;
  static const modelContentBytes = 4 * 1024;
  static const searchTextBytes = 16 * 1024;
  static const copyBytes = 64 * 1024;
  static const exportPixels = 16000000;
}
