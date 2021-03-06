//
//  XPViewController.swift
//  Pods
//
//  Created by Jeffrey Bergier on 2/2/17.
//
//

import Foundation

#if os(OSX)
    import AppKit
    public typealias XPViewController = NSViewController
    internal typealias XPLabel = NSTextField
    internal typealias XPView = NSView
    internal typealias XPActivityIndicatorView = NSProgressIndicator
    internal typealias XPImage = NSImage
#else
    import UIKit
    public typealias XPViewController = UIViewController
    internal typealias XPLabel = UILabel
    internal typealias XPView = UIView
    internal typealias XPActivityIndicatorView = UIActivityIndicatorView
    internal typealias XPImage = UIImage
#endif

#if os(OSX)
    extension NSValue {
        convenience init(xpSizeWidth: CGFloat, xpSizeHeight: CGFloat) {
            self.init(size: NSSize(width: xpSizeWidth, height: xpSizeHeight))
        }
    }
    extension XPView {
        var xpLayer: CALayer? {
            return self.layer
        }
    }
#else
    extension NSValue {
        convenience init(xpSizeWidth: CGFloat, xpSizeHeight: CGFloat) {
            self.init(cgSize: CGSize(width: 512, height: 512))
        }
    }
    extension XPView {
        var xpLayer: CALayer? { return self.layer }
        var isFlipped: Bool { return true }
    }
#endif

// swiftlint:disable operator_usage_whitespace
public enum Color {
    #if os(OSX)
    public static let tintColor = NSColor(red: 0, green: 204/255.0, blue: 197/255.0, alpha: 1)
    public static let iconColor = NSColor(red: 136/255.0, green: 255/255.0, blue: 226/255.0, alpha: 1)
    #else
    public static let tintColor = UIColor(red: 0, green: 204/255.0, blue: 197/255.0, alpha: 1)
    public static let iconColor = UIColor(red: 136/255.0, green: 255/255.0, blue: 226/255.0, alpha: 1)
    #endif
}
// swiftlint:enable operator_usage_whitespace
