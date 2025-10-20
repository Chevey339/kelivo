import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)
    ICloudSyncHandler.shared.register(with: flutterViewController)

    let channel = FlutterMethodChannel(name: "app.clipboard", binaryMessenger: flutterViewController.engine.binaryMessenger)
    channel.setMethodCallHandler { (call: FlutterMethodCall, result: @escaping FlutterResult) in
      if call.method == "getClipboardImages" {
        var paths: [String] = []
        let pb = NSPasteboard.general
        if let items = pb.pasteboardItems {
          for item in items {
            if let data = item.data(forType: .png) ?? item.data(forType: .tiff) {
              var outData: Data? = data
              if item.data(forType: .png) == nil {
                if let rep = NSBitmapImageRep(data: data) {
                  outData = rep.representation(using: .png, properties: [:])
                }
              }
              if let out = outData {
                let tmp = NSTemporaryDirectory()
                let filename = "pasted_\(Int(Date().timeIntervalSince1970 * 1000)).png"
                let url = URL(fileURLWithPath: tmp).appendingPathComponent(filename)
                do {
                  try out.write(to: url)
                  paths.append(url.path)
                } catch {
                  // ignore
                }
              }
            }
          }
        }
        result(paths)
      } else {
        result(FlutterMethodNotImplemented)
      }
    }

    super.awakeFromNib()
  }
}
