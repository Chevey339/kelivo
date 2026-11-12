// Run from the repository root after `flutter build macos --debug --no-pub`:
//   find_frameworks="$PWD/build/macos/Build/Products/Debug"
//   xcrun swiftc test/native/browser_find_interaction_test.swift \
//     -F "$find_frameworks" -F "$find_frameworks/OrderedSet" \
//     -F "$find_frameworks/flutter_inappwebview_macos" \
//     -framework AppKit -framework WebKit -framework FlutterMacOS \
//     -framework OrderedSet -framework flutter_inappwebview_macos \
//     -Xlinker -rpath -Xlinker "$find_frameworks" \
//     -Xlinker -rpath -Xlinker "$find_frameworks/OrderedSet" \
//     -Xlinker -rpath -Xlinker "$find_frameworks/flutter_inappwebview_macos" \
//     -o /tmp/browser-find-interaction-test
//   /tmp/browser-find-interaction-test
// Exercises the actual plugin and WebKit without launching the app or a window.
import AppKit
import FlutterMacOS
import WebKit
@testable import flutter_inappwebview_macos

func require(_ value: @autoclosure () -> Bool, _ message: String) {
    if !value() {
        fputs("FAIL: \(message)\n", stderr)
        exit(1)
    }
}

func completed(_ label: String, _ operation: (@escaping (Any?, Error?) -> Void) -> Void) -> Any? {
    var done = false
    var output: Any?
    var failure: Error?
    operation { value, error in
        require(!done, "\(label) completed more than once")
        output = value
        failure = error
        done = true
    }
    let deadline = Date().addingTimeInterval(5)
    while !done && Date() < deadline {
        RunLoop.current.run(until: Date().addingTimeInterval(0.01))
    }
    require(done, "\(label) never completed")
    require(failure == nil, "\(label): \(String(describing: failure))")
    return output
}

final class Navigation: NSObject, WKNavigationDelegate {
    var loaded = false
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        loaded = true
    }
}

let app = NSApplication.shared
app.setActivationPolicy(.prohibited)
// Only the registrar is needed. Never run the application's Dart entrypoint.
let flutter = FlutterEngine(name: "find-regression", project: nil, allowHeadlessExecution: true)
let plugin = InAppWebViewFlutterPlugin(with: flutter.registrar(forPlugin: "find-regression"))
let configuration = WKWebViewConfiguration()
configuration.websiteDataStore = .nonPersistent()
let webView = InAppWebView(id: nil, plugin: nil, frame: NSRect(x: 0, y: 0, width: 640, height: 480), configuration: configuration)
webView.settings = InAppWebViewSettings()
webView.prepare()
let finder = FindInteractionController(plugin: plugin, id: "find-regression", webView: webView, settings: nil)
// No Dart listener is needed; inspect the actual document's match state.
finder.channelDelegate?.dispose()
finder.channelDelegate = nil
webView.findInteractionController = finder
let navigation = Navigation()
webView.navigationDelegate = navigation

let queries = [
    "大师打",
    "da'shi'da",
    "O'Reilly",
    #"a\b"#,
    "line\nbreak",
    "double\"quote",
    "emoji 😀",
    "'); window.__findInjected = true; //",
]
func html(_ value: String) -> String {
    value.replacingOccurrences(of: "&", with: "&amp;")
        .replacingOccurrences(of: "<", with: "&lt;")
        .replacingOccurrences(of: ">", with: "&gt;")
}
let body = queries.map { "<p>\(html($0))</p>" }.joined()
webView.loadHTMLString("<html><body>\(body)<p>Android Android</p></body></html>", baseURL: nil)
let deadline = Date().addingTimeInterval(10)
while !navigation.loaded && Date() < deadline {
    RunLoop.current.run(until: Date().addingTimeInterval(0.01))
}
require(navigation.loaded, "fixture did not load")

func evaluate(_ source: String) -> Any? {
    completed("evaluate") { webView.evaluateJavaScript(source, completionHandler: $0) }
}
func search(_ query: String) {
    _ = completed("find \(query.debugDescription)") { finder.findAll(find: query, completionHandler: $0) }
}

for query in queries {
    search(query)
    let matches = evaluate("Array.from(document.querySelectorAll('.flutter_inappwebview_Highlight'), node => node.textContent)") as? [String]
    require(matches == [query], "search must preserve the literal query: \(query.debugDescription)")
}
require(evaluate("typeof window.__findInjected") as? String == "undefined", "query executed as JavaScript")
search("no such match")
require(evaluate("window.flutter_inappwebview._searchResultCount") as? Int == 0, "no-match search failed")
search("Android")
_ = completed("next") { finder.findNext(forward: true, completionHandler: $0) }
require(evaluate("window.flutter_inappwebview._currentHighlight") as? Int == 1, "next match failed")
_ = completed("previous") { finder.findNext(forward: false, completionHandler: $0) }
require(evaluate("window.flutter_inappwebview._currentHighlight") as? Int == 0, "previous match failed")
search("")
require(evaluate("document.querySelectorAll('.flutter_inappwebview_Highlight').length") as? Int == 0, "empty search did not clear highlights")
webView.dispose()
print("Native macOS find regression passed: literal queries, no matches, traversal and empty completion.")
