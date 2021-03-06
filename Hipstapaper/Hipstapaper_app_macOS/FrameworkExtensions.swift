//
//  FrameworkExtensions.swift
//  Hipstapaper
//
//  Created by Jeffrey Bergier on 1/2/17.
//  Copyright © 2017 Jeffrey Bergier. All rights reserved.
//

import Common
import AppKit

extension NSWindow: KVOCapable {}
extension NSSplitViewItem: KVOCapable {}

extension NSSearchField {
    var searchString: String? {
        get {
            let trimmed = self.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed == "" { return nil } else { return trimmed }
        }
        set {
            if let newValue = newValue {
                self.objectValue = newValue
                self.becomeFirstResponder()
            } else {
                self.objectValue = nil
                self.resignFirstResponder()
            }
        }
    }
}

extension NSToolbarItem {
    
    // Load some types from the run time. We will use these to compare the type of toolbar item we are later
    // if we can't load these types from the runtime, then just set them to a class that a toolbar could never be (NSSet)
    static let flexibleSpaceClass: AnyObject.Type = NSClassFromString("NSToolbarFlexibleSpaceItem") ?? NSSet.self
    static let fixedSpaceClass: AnyObject.Type = NSClassFromString("NSToolbarSpaceItem") ?? NSSet.self
    static let setTrackedSplitViewSelector = Selector("setTrackedSplitView:")
    static let validateToolbarItemSelector = Selector("validateToolbarItem:")
    
    func resizeIfNeeded() {
        if
            self.isKind(of: type(of: self).flexibleSpaceClass) == false &&
            self.isKind(of: type(of: self).fixedSpaceClass) == false &&
            self.itemIdentifier != .flexibleSpace &&
            self.itemIdentifier != .space &&
            self.itemIdentifier.rawValue.contains("NORESIZE-") == false
        {
            self.minSize = NSSize(width: 56, height: 34)
            self.maxSize = NSSize(width: 56, height: 34)
        } else {
            let width = self.maxSize.width
            self.minSize = NSSize(width: width, height: 34)
            self.maxSize = NSSize(width: width, height: 34)
        }
    }
    
    func isValid(for object: NSObject?) -> Bool {
        // returns NSAtom when returning Bool.true
        if object?.perform(type(of: self).validateToolbarItemSelector, with: self)?.takeUnretainedValue() != nil { // as? NSAtom
            return true
        } else {
            return false // returns nil when selector returns Bool.false
        }
    }
}

extension NSTextField {
    enum Kind: Int {
        case backgroundStyleAdaptable = 756
    }
}

extension NSToolbarItem {
    enum Kind: Int {
        case unarchive = 544, archive = 555, tag = 222, share = 233, jsToggle = 766, quickLook = 764
    }
}

extension NSMenuItem {
    enum Kind: Int {
        case open = 999, openInBrowser = 998, copy = 444, archive = 555, unarchive = 544, delete = 666, share = 898, shareSubmenu = 897, javascript = 433, showMainWindow = 374, tags = 909, quickLook = 764
    }
}

extension NSMenu {
    convenience init(shareMenuWithItems items: [URL]) {
        self.init()
        let compatibleServices = NSSharingService.sharingServices(forItems: items)
        compatibleServices.forEach { service in
            let title = service.title
            let image = service.image
            let newMenuItem = NSMenuItem(title: title, action: #selector(ContentListViewController.shareMenu(_:)), keyEquivalent: "")
            newMenuItem.image = image
            newMenuItem.representedObject = service
            newMenuItem.tag = NSMenuItem.Kind.shareSubmenu.rawValue
            self.addItem(newMenuItem)
        }
    }
}

// MARK: Autochanging Text Field Colors in TableViews

// The purpose of this is to change color when the selection changes on the tableview. There are some hacks in here.
// Normally NSTableCellView forwards the setBackgroundStyle message to all subviews.
// However, it doesn't do this recursiely.
// Since the labels are wthin a stackview they don't get the message.
// Below there is an NSView extension that always forwards the message on to all subviews

extension NSView {
    @available(*, deprecated, message:"Only useful for macOS 10.10 to 10.13. Has no effect on 10.14 and higher.")
    func setBackgroundStyleOnSubviews(_ newValue: NSView.BackgroundStyle) {

        // return if on 10.14 where the system handles dark mode for us
        if #available(macOS 10.14, *) {
            return
        }

        for view in self.subviews {
            view.setBackgroundStyleOnSubviews(newValue)
        }
        guard let textField = self as? NSTextField else { return }
        textField.setBackgroundStlyeIfNeeded(newValue)
    }
}

extension NSTextField {
    fileprivate func setBackgroundStlyeIfNeeded(_ newValue: NSView.BackgroundStyle) {
        guard let kind = Kind(rawValue: self.tag) else { return }
        switch kind {
        case .backgroundStyleAdaptable:
            print(newValue)
            switch newValue {
            case .dark:
                self.textColor = NSColor.controlLightHighlightColor
            case .light:
                self.textColor = NSColor.controlTextColor
            case .lowered, .raised, .emphasized, .normal:
                fallthrough
            @unknown default:
                assertionFailure()
                self.textColor = NSColor.controlTextColor
            }
        }
    }
}

extension NSView {
    
    private static let actionButtonClass: AnyObject.Type = NSClassFromString("NSTableViewActionButton") ?? NSSet.self
    
    var tableViewActionButtons: [NSView] {
        let aType: AnyObject.Type = type(of: self).actionButtonClass
        let matches = self.subviews(matchingType: aType)
        return matches
    }
    
    private func subviews(matchingType type: AnyClass) -> [NSView] {
        var matches = [NSView]()
        if self.classForCoder == type {
            matches.append(self)
        }
        for subview in self.subviews {
            matches += subview.subviews(matchingType: type)
        }
        return matches
    }
}

/*
extension NSView.BackgroundStyle: CustomStringConvertible {
    public var description: String {
        switch self {
        case .dark:
            return ".dark"
        case .light:
            return ".light"
        case .lowered:
            return ".lowered"
        case .raised:
            return ".raised"
        case .normal:
            return ".normal"
        case .emphasized:
            return ".emphasized"
        }
    }
}
*/
