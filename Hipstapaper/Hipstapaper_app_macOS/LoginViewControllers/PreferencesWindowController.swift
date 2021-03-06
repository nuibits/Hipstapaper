//
//  PreferencesWindowController.swift
//  Hipstapaper
//
//  Created by Jeffrey Bergier on 12/25/16.
//  Copyright © 2016 Jeffrey Bergier. All rights reserved.
//

import Common
import AppKit

class PreferencesWindowController: NSWindowController, RealmControllable {
    
    @IBOutlet private weak var tabView: NSTabView?
    
    private lazy var appearanceSwitcher = AppleInterfaceStyleWindowAppearanceSwitcher(window: self.window!)
    
    private var allTabViewItems = [NSTabViewItem]()
    
    var realmController: RealmController? {
        get {
            return self.delegate?.realmController
        }
        set {
            self.delegate?.realmController = newValue
        }
    }
    
    weak var delegate: RealmControllable?
    
    convenience init() {
        self.init(windowNibName: "PreferencesWindowController")
    }
    
    override func windowDidLoad() {
        super.windowDidLoad()
        self.allTabViewItems = self.tabView?.tabViewItems ?? []
        _ = self.appearanceSwitcher
    }
    
    override func showWindow(_ sender: Any?) {
        super.showWindow(sender)
        
        self.tabView?.tabViewItems.forEach() { item in
            self.tabView?.removeTabViewItem(item)
        }
        
        let items: [NSTabViewItem]
        if self.realmController != nil {
            items = self.allTabViewItems.filter({ ($0.identifier as? String) == "loggedin" })
        } else {
            items = self.allTabViewItems.filter({
                ($0.identifier as? String) == "login" || ($0.identifier as? String) == "create" || ($0.identifier as? String) == "local"
            })
        }
        
        items.enumerated().forEach() { index, item in
            self.tabView?.insertTabViewItem(item, at: index)
        }
    }
}
