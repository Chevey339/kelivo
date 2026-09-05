enum TerminalMouseButton {
  left(id: 0),

  middle(id: 1),

  right(id: 2),

  wheelUp(id: 64 + 0, isWheel: true),

  wheelDown(id: 64 + 1, isWheel: true),

  wheelLeft(id: 64 + 2, isWheel: true),

  wheelRight(id: 64 + 3, isWheel: true),
  ;

  /// The id that is used to report a button press or release to the terminal.
  ///
  /// Buttons 4..7 are the wheel: bit 6 (64) marks them as such and the low two
  /// bits carry `button - 4`, so wheel up is 64 and wheel down is 65. Setting
  /// the low bits to 4 and 5 instead would raise bit 2, which applications
  /// read as the shift modifier.
  final int id;

  /// Whether this button is a mouse wheel button.
  final bool isWheel;

  const TerminalMouseButton({required this.id, this.isWheel = false});
}
