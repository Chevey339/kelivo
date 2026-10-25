import Flutter
import UIKit

/// Presents only the menu. Flutter retains selection, focus and edit commands.
@available(iOS 26.0, *)
final class IosSelectionMenuHandler: NSObject, UIEditMenuInteractionDelegate {
  private struct Item: Equatable {
    let title: String
    let enabled: Bool
  }

  private struct Menu {
    let session: Int
    var revision: Int
    var rect: CGRect
    var items: [Item]
  }

  private weak var view: UIView?
  private let channel: FlutterMethodChannel
  private lazy var interaction = UIEditMenuInteraction(delegate: self)
  private var attached = false
  private var menu: Menu?

  init(view: UIView, channel: FlutterMethodChannel) {
    self.view = view
    self.channel = channel
    super.init()
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "isAvailable":
      result(true)
    case "show":
      result(show(call.arguments))
    case "hide":
      if let args = call.arguments as? [String: Any],
         let session = args["session"] as? Int, menu?.session == session {
        // Clear first so programmatic dismissal cannot retire a newer menu.
        menu = nil
        interaction.dismissMenu()
      }
      result(nil)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func show(_ arguments: Any?) -> Bool {
    guard let view, view.window != nil,
          let args = arguments as? [String: Any],
          let session = args["session"] as? Int,
          let revision = args["revision"] as? Int,
          let coordinates = args["rect"] as? [Double], coordinates.count == 4,
          coordinates.allSatisfy({ $0.isFinite }),
          coordinates[2] > 0, coordinates[3] > 0,
          let encodedItems = args["items"] as? [[String: Any]], !encodedItems.isEmpty else {
      return false
    }
    let items = encodedItems.compactMap { value -> Item? in
      guard let title = value["title"] as? String,
            let enabled = value["enabled"] as? Bool else { return nil }
      return Item(title: title, enabled: enabled)
    }
    guard items.count == encodedItems.count else { return false }
    // Flutter global logical coordinates are relative to this Flutter view.
    // Clip to the current window so partially offscreen selections still anchor.
    let rect = CGRect(x: coordinates[0], y: coordinates[1],
                      width: coordinates[2], height: coordinates[3]).intersection(view.bounds)
    guard !rect.isNull, !rect.isEmpty else { return false }
    if !attached {
      view.addInteraction(interaction)
      attached = true
    }
    if let previous = menu, previous.session == session {
      guard revision >= previous.revision else { return false }
      menu = Menu(session: session, revision: revision, rect: rect, items: items)
      if previous.items != items || previous.revision != revision {
        interaction.reloadVisibleMenu()
      }
      if previous.rect != rect {
        interaction.updateVisibleMenuPosition(animated: false)
      }
    } else {
      menu = Menu(session: session, revision: revision, rect: rect, items: items)
      let configuration = UIEditMenuConfiguration(
        identifier: NSNumber(value: session), sourcePoint: CGPoint(x: rect.midX, y: rect.midY)
      )
      interaction.presentEditMenu(with: configuration)
    }
    return true
  }

  func editMenuInteraction(_ interaction: UIEditMenuInteraction,
                          menuFor configuration: UIEditMenuConfiguration,
                          suggestedActions: [UIMenuElement]) -> UIMenu? {
    guard let menu, (configuration.identifier as? NSNumber)?.intValue == menu.session else {
      return UIMenu(children: [])
    }
    // Do not use responder-chain edit actions: their target could be the draft
    // input while the user is selecting a read-only message above it.
    let actions = menu.items.enumerated().map { index, item in
      UIAction(title: item.title, attributes: item.enabled ? [] : [.disabled]) { [weak self] _ in
        guard let self, self.menu?.session == menu.session,
              self.menu?.revision == menu.revision else { return }
        self.channel.invokeMethod("action", arguments: [
          "session": menu.session, "revision": menu.revision, "index": index,
        ])
      }
    }
    return UIMenu(children: actions)
  }

  func editMenuInteraction(_ interaction: UIEditMenuInteraction,
                          targetRectFor configuration: UIEditMenuConfiguration) -> CGRect {
    guard let menu, (configuration.identifier as? NSNumber)?.intValue == menu.session else {
      return .null
    }
    return menu.rect
  }

  func editMenuInteraction(_ interaction: UIEditMenuInteraction,
                          willDismissMenuFor configuration: UIEditMenuConfiguration,
                          animator: any UIEditMenuInteractionAnimating) {
    guard let session = (configuration.identifier as? NSNumber)?.intValue else { return }
    // UIKit may begin dismissal before invoking the selected UIAction. Wait
    // until completion so the Dart action is delivered before owner cleanup.
    animator.addCompletion { [weak self] in
      guard let self, self.menu?.session == session else { return }
      self.menu = nil
      self.channel.invokeMethod("dismissed", arguments: ["session": session])
    }
  }
}
