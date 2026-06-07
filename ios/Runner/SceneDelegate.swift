import Flutter
import UIKit

// Subclass of FlutterSceneDelegate so Flutter manages the window, root
// FlutterViewController, and scene lifecycle forwarding to plugins.
//
// We override sceneDidBecomeActive because UIKit no longer calls
// AppDelegate.applicationDidBecomeActive once the UIScene lifecycle is adopted.
// The finished Live Activity dismissal previously triggered there now runs here.
class SceneDelegate: FlutterSceneDelegate {
  override func sceneDidBecomeActive(_ scene: UIScene) {
    super.sceneDidBecomeActive(scene)
    if let appDelegate = UIApplication.shared.delegate as? AppDelegate {
      appDelegate.handleSceneDidBecomeActive()
    }
  }
}
