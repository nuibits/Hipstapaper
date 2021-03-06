//
//  URLItemExtras.swift
//  Hipstapaper
//
//  Created by Jeffrey Bergier on 12/21/16.
//  Copyright © 2016 Jeffrey Bergier. All rights reserved.
//

import RealmSwift

final public class URLItemExtras: Object {
    
    @objc public internal(set) dynamic var pageTitle: String?
    @objc public internal(set) dynamic var imageData: Data?
        
    public convenience init(title: String?, imageData: Data?) {
        self.init()
        self.pageTitle = title
        self.imageData = imageData
    }
    
    override public class func ignoredProperties() -> [String] {
        return ["image"]
    }
}

#if os(OSX)
    import AppKit
    
    extension URLItemExtras {
        
        public convenience init(title: String?, image: NSImage?) {
            self.init()
            self.pageTitle = title
            self.image = image
        }
        
        // @objc dynamic required for AppKit bindings
        @objc dynamic public internal(set) var image: NSImage? {
            get {
                guard let data = self.imageData else { return nil }
                if data.count > XPImageProcessor.maxFileSize {
                    NSLog("Image Data Size: \(Double(data.count) / 1000) kb Exceeds Max Site: \(Double(XPImageProcessor.maxFileSize) / 1000) kb")
                }
                let image = NSImage(data: data)
                return image
            }
            set {
                guard let image = newValue else { self.imageData = nil; return }
                let data = XPImageProcessor.compressedJPEGImageData(from: image)
                self.imageData = data
            }
        }
    }
#else
    import UIKit
    
    extension URLItemExtras {
        
        public convenience init(title: String?, image: UIImage?) {
            self.init()
            self.pageTitle = title
            self.image = image
        }
        
        public internal(set) var image: UIImage? {
            get {
                guard let data = self.imageData else { return nil }
                if data.count > XPImageProcessor.maxFileSize {
                    NSLog("Image Data Size: \(Double(data.count) / 1000) kb Exceeds Max Site: \(Double(XPImageProcessor.maxFileSize) / 1000) kb")
                }
                let image = UIImage(data: data)
                return image
            }
            set {
                guard let image = newValue else { self.imageData = nil; return; }
                let data = XPImageProcessor.compressedJPEGImageData(from: image)
                self.imageData = data
            }
        }
    }
#endif
