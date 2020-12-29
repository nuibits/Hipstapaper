//
//  Created by Jeffrey Bergier on 2020/12/25.
//
//  Copyright © 2020 Saturday Apps.
//
//  This file is part of Hipstapaper.
//
//  Hipstapaper is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  Hipstapaper is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with Hipstapaper.  If not, see <http://www.gnu.org/licenses/>.
//

import AppKit
import Browse
import SwiftUI

class BrowserWindowController: NSWindowController {
    
    let url: URL
    private lazy var memoryLeak = { self }
    
    init(url: URL) {
        self.url = url
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 768, height: 768),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered, defer: false)
        window.titlebarAppearsTransparent = true // as stated
        window.titleVisibility = .hidden         // no title - all in content
        window.contentView = NSHostingView(rootView: Browser(url: url, done: {}))
        window.center()
//        window.contentViewController = NSHostingController(rootView: Browser(url: url, done: {}))
        super.init(window: window)
        self.windowFrameAutosaveName = url.absoluteString
        _ = self.memoryLeak
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
}