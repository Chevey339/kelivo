import Cocoa
import FlutterMacOS
import XCTest

class RunnerTests: XCTestCase {

  @MainActor
  func testFlutterContentDoesNotMoveTheWindow() throws {
    let window = try XCTUnwrap(
      NSApp.windows.first { $0.contentViewController is FlutterViewController }
    )
    XCTAssertFalse(window.isMovableByWindowBackground)
    XCTAssertTrue(window.isMovable)
  }

}
