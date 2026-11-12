// xcrun swiftc macos/Runner/SidebarResizePress.swift \
//   test/native/sidebar_resize_press_test.swift -o /tmp/sidebar-resize-press-test
// /tmp/sidebar-resize-press-test
@main
struct SidebarResizePressTest {
  static func main() {
    var press = SidebarResizePress()
    precondition(!press.canCapture(100))
    press.begin(timestampMicros: 100)
    precondition(press.canCapture(100))
    precondition(!press.canCapture(99))
    precondition(press.end(ifMatches: 100))
    precondition(!press.canCapture(100))
    precondition(!press.end(ifMatches: 100))

    // A's channel begin/end arrive after B's real AppKit down.
    press.begin(timestampMicros: 200)
    precondition(!press.canCapture(100))
    precondition(!press.end(ifMatches: 100))
    precondition(press.canCapture(200))

    // Focus loss/disposal/hover can still cancel their own held press, and
    // a late begin cannot resurrect the cancelled sequence.
    precondition(press.end(ifMatches: 200))
    precondition(!press.canCapture(200))
    press.begin(timestampMicros: 300)
    precondition(!press.end(ifMatches: 200))
    precondition(press.canCapture(300))
    precondition(press.end(ifMatches: 300))
    print("Sidebar resize press ordering passed")
  }
}
