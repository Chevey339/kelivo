import XCTest

/// Only the isolated acceptance bundle; never launches or inspects the user's
/// installed Kelivo. The Dart test independently verifies trusted activation.
final class GenUiGestureTests: XCTestCase {
  func testNativeWebGestures() {
    continueAfterFailure = false
    let app = XCUIApplication(bundleIdentifier: "psyche.kelivo.genuiacceptance")
    app.activate()
    for name in ["link", "popup", "download", "file", "protocol"] {
      let button = app.buttons["Run gesture-\(name)"]
      XCTAssertTrue(button.waitForExistence(timeout: 90), "Missing \(name) fixture")
      // Each fixture is one viewport-filling button. Confirm its identity
      // before tapping in the app's native coordinate space.
      print("GENUI_UI_FRAME \(name) button=\(button.frame) app=\(app.frame)")
      app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
      XCTAssertTrue(button.waitForNonExistence(timeout: 20), "\(name) did not finish")
    }
  }
}
