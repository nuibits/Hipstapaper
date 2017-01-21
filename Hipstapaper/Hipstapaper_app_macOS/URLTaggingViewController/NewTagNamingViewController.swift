//
//  NewTagNamingViewController.swift
//  Hipstapaper
//
//  Created by Jeffrey Bergier on 12/23/16.
//  Copyright © 2016 Jeffrey Bergier. All rights reserved.
//

import Cocoa

class NewTagNamingViewController: NSViewController {
    
    private lazy var appearanceSwitcher: AppleInterfaceStyleWindowAppearanceSwitcher = AppleInterfaceStyleWindowAppearanceSwitcher(window: self.view.window!)
    
    typealias ConfirmTuple = (newName: String, sender: NSObject?, presentedVC: NSViewController)
    var confirm: ((ConfirmTuple) -> Void)?

    @IBOutlet private weak var nameTextField: NSTextField?
    
    @IBAction private func addTagButtonClicked(_ sender: NSObject?) {
        let newTagName = self.nameTextField?.stringValue ?? ""
        self.confirm?((newName: newTagName, sender: sender, presentedVC: self))
    }
    
    override func viewDidAppear() {
        super.viewDidAppear()
        let _ = self.appearanceSwitcher
    }
    
}
