//
//  Created by Jeffrey Bergier on 2021/01/01.
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
import Stylize

struct DetailToolbar_iOS: ViewModifier {
    
    @ObservedObject var controller: WebsiteController
    @Binding var presentation: DetailToolbarPresentation.Wrap
    @Binding var popoverAlignment: Alignment
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    
    private var isCompact: Bool {
        switch self.horizontalSizeClass ?? .compact {
        case .regular:
            return false
        case .compact:
            fallthrough
        @unknown default:
            return true
        }
    }
    
    func body(content: Content) -> some View {
        return self.isCompact
        ? AnyView(Text(""))
        : AnyView(
            content
                .modifier(DetailToolbar_Regular_iOS(controller: self.controller,
                                                    presentation: self.$presentation,
                                                    popoverAlignment: self.$popoverAlignment))
        )
    }
}

fileprivate struct DetailToolbar_Regular_iOS: ViewModifier {
    
    @ObservedObject var controller: WebsiteController
    @Binding var presentation: DetailToolbarPresentation.Wrap
    @Binding var popoverAlignment: Alignment
    
    @Environment(\.openURL) var openURL
    @EnvironmentObject var windowManager: WindowManager
    
    func body(content: Content) -> some View {
        content.toolbar(id: "Detail_iOS_Regular") {
            //
            // Bottom Buttons
            //
            ToolbarItem(id: "Detail_iOS_Regular.Share", placement: .bottomBar) {
                DT.Share(isDisabled: self.controller.selectedWebsites.isEmpty)
                {
                    self.popoverAlignment = .bottomLeading
                    self.presentation.value = .share
                }
            }
            ToolbarItem(id: "Detail_iOS_Regular.Tag", placement: .bottomBar) {
                DT.Tag(isDisabled: self.controller.selectedWebsites.isEmpty)
                {
                    self.popoverAlignment = .bottomLeading
                    self.presentation.value = .tagApply
                }
            }
            ToolbarItem(id: "Detail_iOS_Regular.Archive", placement: .bottomBar) {
                DT.Unarchive(isDisabled: self.controller.selectedWebsites.filter { !$0.value.isArchived }.isEmpty)
                {
                    // Archive
                    let selected = self.controller.selectedWebsites
                    self.controller.selectedWebsites = []
                    try! self.controller.controller.update(selected, .init(isArchived: true)).get()
                }
            }
            ToolbarItem(id: "Detail_iOS_Regular.Unarchive", placement: .bottomBar) {
                DT.Unarchive(isDisabled: self.controller.selectedWebsites.filter { $0.value.isArchived }.isEmpty)
                {
                    // Unarchive
                    let selected = self.controller.selectedWebsites
                    self.controller.selectedWebsites = []
                    try! self.controller.controller.update(selected, .init(isArchived: false)).get()
                }
            }
            ToolbarItem(id: "Detail_iOS_Regular.OpenInApp", placement: .bottomBar) {
                DT.OpenInApp(selectionCount: self.controller.selectedWebsites.count) {
                    guard self.windowManager.features.contains([.multipleWindows, .bulkActivation])
                    else { self.presentation.value = .browser; return }
                    let urls = self.controller.selectedWebsites.compactMap
                    { $0.value.resolvedURL ?? $0.value.originalURL }
                    self.windowManager.show(urls) {
                        // TODO: Do something with this error
                        print($0)
                    }
                }
            }
            ToolbarItem(id: "Detail_iOS_Regular.OpenExternal", placement: .bottomBar) {
                DT.OpenExternal(selectionCount: self.controller.selectedWebsites.count) {
                    let urls = self.controller.selectedWebsites
                        .compactMap { $0.value.resolvedURL ?? $0.value.originalURL }
                    urls.forEach { self.openURL($0) }
                }
            }
            
            //
            // Top Bar Items
            //
            
            ToolbarItem(id: "Detail_iOS_Regular.Filter", placement: .automatic) {
                DT.Filter(filter: self.controller.query.isArchived) {
                    self.popoverAlignment = .topTrailing
                    self.controller.query.isArchived.toggle()
                }
            }
            ToolbarItem(id: "Detail_iOS_Regular.Sort", placement: .automatic) {
                ButtonToolbarSort {
                    self.popoverAlignment = .topTrailing
                    self.presentation.value = .sort
                }
            }
            ToolbarItem(id: "Detail_iOS_Regular.Search", placement: .primaryAction) {
                DT.Search {
                    self.popoverAlignment = .topTrailing
                    self.presentation.value = .search
                }
            }
        }
    }
}

