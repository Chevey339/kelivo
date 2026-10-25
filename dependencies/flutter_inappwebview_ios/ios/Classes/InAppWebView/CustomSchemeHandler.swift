//
//  CustomSchemeHandler.swift
//  flutter_inappwebview
//
//  Created by Lorenzo Pichilli on 25/10/2019.
//

import Flutter
import Foundation
import WebKit

@available(iOS 11.0, *)
public class CustomSchemeHandler: NSObject, WKURLSchemeHandler {
    var schemeHandlers: [Int: WKURLSchemeTask] = [:]
    
    public func webView(_ webView: WKWebView, start urlSchemeTask: WKURLSchemeTask) {
        schemeHandlers[urlSchemeTask.hash] = urlSchemeTask
        let inAppWebView = webView as! InAppWebView
        let request = WebResourceRequest.init(fromURLRequest: urlSchemeTask.request)
        let callback = WebViewChannelDelegate.LoadResourceWithCustomSchemeCallback()
        callback.nonNullSuccess = { (response: CustomSchemeResponse) in
            if (self.schemeHandlers[urlSchemeTask.hash] != nil) {
                // A URLResponse produces fetch status 0 in WebKit. Local resources
                // need an HTTP-shaped response for modules and fetch().ok.
                let urlResponse = HTTPURLResponse(url: request.url, statusCode: 200,
                    httpVersion: "HTTP/1.1", headerFields: [
                        "Content-Type": response.contentType + "; charset=" + response.contentEncoding,
                        "Content-Length": String(response.data.count),
                        "Cache-Control": "no-store",
                        "X-Content-Type-Options": "nosniff"
                    ])!
                urlSchemeTask.didReceive(urlResponse)
                urlSchemeTask.didReceive(response.data)
                urlSchemeTask.didFinish()
                self.schemeHandlers.removeValue(forKey: urlSchemeTask.hash)
            }
            return false
        }
        let fail = {
            guard self.schemeHandlers.removeValue(forKey: urlSchemeTask.hash) != nil else { return }
            urlSchemeTask.didFailWithError(URLError(.fileDoesNotExist))
        }
        callback.defaultBehaviour = { _ in fail() }
        callback.error = { _, _, _ in fail() }
        
        if let channelDelegate = inAppWebView.channelDelegate {
            channelDelegate.onLoadResourceWithCustomScheme(request: request, callback: callback)
        } else {
            callback.defaultBehaviour(nil)
        }
    }
    
    public func webView(_ webView: WKWebView, stop urlSchemeTask: WKURLSchemeTask) {
        schemeHandlers.removeValue(forKey: urlSchemeTask.hash)
    }
}
