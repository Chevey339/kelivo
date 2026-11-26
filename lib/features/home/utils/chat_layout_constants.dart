/// Shared layout constants for the Home chat UI (desktop/tablet).
class ChatLayoutConstants {
  /// Max width of the chat content and composer in the standard layout.
  static const double maxContentWidth = 860.0;

  /// How long a deleted message fades out and collapses before its slot is
  /// actually removed from the timeline. The controller waits this long
  /// between flagging the slot and performing the deletion, so the widget
  /// animation and the data mutation stay in lockstep.
  static const Duration slotRemovalAnimationDuration = Duration(
    milliseconds: 240,
  );
}
