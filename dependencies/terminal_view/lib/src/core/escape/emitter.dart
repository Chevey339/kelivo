class EscapeEmitter {
  const EscapeEmitter();

  String primaryDeviceAttributes() {
    return '\x1b[?62;22c';
  }

  String secondaryDeviceAttributes() {
    const model = 0;
    const version = 0;
    return '\x1b[>$model;$version;0c';
  }

  String tertiaryDeviceAttributes() {
    return '\x1bP!|00000000\x1b\\';
  }

  String operatingStatus() {
    return '\x1b[0n';
  }

  String cursorPosition(int x, int y) {
    return '\x1b[${y + 1};${x + 1}R';
  }

  String reportMode(int mode, int value, {required bool isDec}) {
    final prefix = isDec ? '?' : '';
    return '\x1b[$prefix$mode;$value\$y';
  }

  String bracketedPaste(String text) {
    return '\x1b[200~$text\x1b[201~';
  }

  String size(int rows, int cols) {
    return '\x1b[8;$rows;${cols}t';
  }
}
