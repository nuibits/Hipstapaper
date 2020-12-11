//
//  Created by Jeffrey Bergier on 2020/12/11.
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

extension TextField where Label == Text {

    public static func URL(_ binding: Binding<String>) -> some View {
        return SwiftUI.TextField("Website URL", text: binding)
            .disableAutocorrection(true)
            .keyboardType(.URL)
            .textFieldStyle(RoundedBorderTextFieldStyle())
    }
    
    public static func WebsiteTitle(_ binding: Binding<String>) -> some View {
        return SwiftUI.TextField("Website Title", text: binding)
            .keyboardType(.default)
            .textFieldStyle(RoundedBorderTextFieldStyle())
    }

}
