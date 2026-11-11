// Local SVG resource budget for Kelivo.
// Distributed under the BSD-style license in this package's LICENSE file.

/// Shared by all resolution paths of one SVG, including referenced clip paths.
class GeometryBudget {
  int _remaining = 65536;

  void consume([int units = 1]) {
    _remaining -= units;
    if (_remaining < 0) {
      throw StateError('SVG geometry work limit exceeded');
    }
  }
}
