//
//  Created by Jeffrey Bergier on 2020/12/03.
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

import SwiftUI
import Datum
import Localize
import Stylize
import Browse

struct DetailToolbar: ViewModifier {
    
    @ObservedObject var controller: WebsiteController
    
    func body(content: Content) -> some View {
        #if os(macOS)
        return content.modifier(DetailToolbar_macOS(controller: self.controller))
        #else
        return content.modifier(DetailToolbar_iOS(controller: self.controller))
        #endif
    }
}

struct OpenWebsiteDisabler: ViewModifier {
    
    let selectedWebsites: Set<AnyElement<AnyWebsite>>
    @EnvironmentObject var windowManager: WindowManager
    
    func body(content: Content) -> some View {
        if self.windowManager.features.contains(.bulkActivation) {
            return content.disabled(self.selectedWebsites.isEmpty)
        } else {
            return content.disabled(self.selectedWebsites.count != 1)
        }
    }
}
