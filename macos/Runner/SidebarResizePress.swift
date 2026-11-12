/// Binds an asynchronous Flutter capture request to the actual AppKit press.
/// An old completion can never release a newer press in the same window.
struct SidebarResizePress {
  private(set) var timestampMicros: Int64?
  private(set) var isPressed = false

  mutating func begin(timestampMicros: Int64) {
    self.timestampMicros = timestampMicros
    isPressed = true
  }

  func matches(_ timestampMicros: Int64) -> Bool {
    self.timestampMicros == timestampMicros
  }

  func canCapture(_ timestampMicros: Int64) -> Bool {
    matches(timestampMicros) && isPressed
  }

  @discardableResult
  mutating func end(ifMatches timestampMicros: Int64) -> Bool {
    guard matches(timestampMicros), isPressed else { return false }
    isPressed = false
    return true
  }
}
