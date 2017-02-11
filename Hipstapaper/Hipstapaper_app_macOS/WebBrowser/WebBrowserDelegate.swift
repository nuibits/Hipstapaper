//
//  WebBrowserDelegate.swift
//  Hipstapaper
//
//  Created by Jeffrey Bergier on 2/3/17.
//  Copyright © 2017 Jeffrey Bergier. All rights reserved.
//

import WebKit

fileprivate extension NSAlert {
    fileprivate static func showAlert(forWebView webView: WKWebView, withError error: Error?) {
        // we need a window to show this in
        guard let window = webView.window else { return }
        
        // create the alert from the error
        // if there is no error, create a generic alert
        let alert: NSAlert
        if let error = error {
            alert = NSAlert(error: error)
        } else {
            alert = NSAlert()
            alert.messageText = "Page Error"
            alert.informativeText = "This page tried to do someting Hipstapaper can't do."
        }
        
        // add buttons
        alert.addButton(withTitle: "Dismiss")
        // only add other buttons if we have a valid URL
        if let _ = webView.url {
            alert.addButton(withTitle: "Copy URL")
            alert.addButton(withTitle: "Open in Browser")
        }
        
        // show the sheet and handle the user action
        alert.beginSheetModal(for: window) { response in
            switch response {
            case 1001: // copy url
                guard let url = webView.url else { break }
                NSPasteboard.general().declareTypes([NSStringPboardType], owner: self)
                NSPasteboard.general().setString(url.absoluteString, forType: NSStringPboardType)
            case 1002: // open in browser
                guard let url = webView.url else { break }
                NSWorkspace.shared().open(url)
            default: // do nothing
                break
            }
        }
    }
}

class WebBrowserDelegate: NSObject { }

extension WebBrowserDelegate: WKUIDelegate {

    func webView(_ webView: WKWebView, runJavaScriptAlertPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping () -> Swift.Void) {
        completionHandler()
        NSAlert.showAlert(forWebView: webView, withError: .none)
    }
    
    func webView(_ webView: WKWebView, runJavaScriptConfirmPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (Bool) -> Swift.Void) {
        completionHandler(false)
        NSAlert.showAlert(forWebView: webView, withError: .none)
    }
    
    func webView(_ webView: WKWebView, runJavaScriptTextInputPanelWithPrompt prompt: String, defaultText: String?, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (String?) -> Swift.Void) {
        completionHandler(.none)
        NSAlert.showAlert(forWebView: webView, withError: .none)
    }
    
    @available(OSX 10.12, *)
    func webView(_ webView: WKWebView, runOpenPanelWith parameters: WKOpenPanelParameters, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping ([URL]?) -> Swift.Void) {
        completionHandler(.none)
        NSAlert.showAlert(forWebView: webView, withError: .none)
    }
}

extension WebBrowserDelegate: WKNavigationDelegate {
    
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        NSAlert.showAlert(forWebView: webView, withError: error)
    }
    
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        NSAlert.showAlert(forWebView: webView, withError: error)
    }
    
}