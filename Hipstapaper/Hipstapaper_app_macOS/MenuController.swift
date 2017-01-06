//
//  MenuController.swift
//  Hipstapaper
//
//  Created by Jeffrey Bergier on 1/4/17.
//  Copyright © 2017 Jeffrey Bergier. All rights reserved.
//

import AppKit

class MenuController: NSObject {
    
    @IBOutlet private weak var copyMenuItem: NSMenuItem?
    
    override func awakeFromNib() {
        super.awakeFromNib()
        NotificationCenter.default.addObserver(self, selector: #selector(self.keyWindowChanged(_:)), name: .NSWindowDidBecomeKey, object: .none)
    }
    
    @objc private func keyWindowChanged(_ notification: Notification?) {
        let window = notification?.object as? NSWindow
        guard let controller = window?.nextResponder else { self.defaultMenu(); return; }
        switch controller {
        case is URLItemWebViewWindowController:
            self.urlItemWebViewWindowControllerMenu()
        default:
            self.defaultMenu()
        }
    }
    
    private func defaultMenu() {
        self.copyMenuItem?.title = "Copy Link"
    }
    
    private func urlItemWebViewWindowControllerMenu() {
        self.copyMenuItem?.title = "Copy"
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
}