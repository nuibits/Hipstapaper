//
//  FrameworkExtensions.swift
//  Hipstapaper
//
//  Created by Jeffrey Bergier on 12/18/16.
//  Copyright © 2016 Jeffrey Bergier. All rights reserved.
//

import Foundation

enum CheckboxState: Int {
    case mixed = -1
    case off = 0
    case on = 1
    
    var boolValue: Bool {
        switch self {
        case .on, .mixed:
            return true
        case .off:
            return false
        }
    }
}



public extension String {
    public init(urlStringFromRawString rawString: String) {
        var components = URLComponents(string: rawString)
        if components?.host == nil {
            // if the host is nil, then it probably couldn't parse the URL
            // adding http:// to it and then generating new components sometimes helps this.
            components = URLComponents(string: "http://" + rawString)
        }
        self = components?.url?.absoluteString ?? rawString
    }
}
