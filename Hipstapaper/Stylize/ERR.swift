//
//  Created by Jeffrey Bergier on 2021/01/10.
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
import Localize

extension STZ {
    public enum ERR {
        public struct Modifier: ViewModifier {
            @Binding public var isPresented: Bool
            public let dismissAction: Action?
            public let content: () -> LocalizedError
            public func body(content: Content) -> some View {
                return content.alert(isPresented: self.$isPresented,
                                     content: { Alert(error: self.content(), dismissAction: self.dismissAction) })
            }
            public init(isPresented: Binding<Bool>, dismissAction: Action?, content: @escaping () -> LocalizedError) {
                _isPresented = isPresented
                self.content = content
                self.dismissAction = dismissAction
            }
        }
    }
}

extension STZ.ERR {
    public class Q: ObservableObject {
        @Published public var isPresented = false
        @Published private var errors: [LocalizedError] = [] {
            didSet {
                self.isPresented = !self.errors.isEmpty
            }
        }
        public init() {}
        public func append(_ error: LocalizedError) {
            self.errors.append(error)
        }
        public func next() -> (LocalizedError, Action)? {
            guard let first = self.errors.first else { return nil }
            let closure = {
                DispatchQueue.main.async {
                    self.errors = Array(self.errors.dropFirst())
                }
            }
            return (first, closure)
        }
    }

    public struct QPresenter: ViewModifier {
        @ObservedObject private var queue: Q
        public init(_ queue: Q) {
            _queue = .init(initialValue: queue)
        }
        public func body(content: Content) -> some View {
            content.alert(isPresented: self.$queue.isPresented) {
                let next = self.queue.next()!
                return Alert(error: next.0, dismissAction: next.1)
            }
        }
    }
}

extension Alert {
    fileprivate init(error: LocalizedError, dismissAction: Action?) {
        self.init(title: STZ.VIEW.TXT(Noun.Error),
                  message: STZ.VIEW.TXT(error.errorDescription!),
                  dismissButton: .default(STZ.VIEW.TXT(Verb.Dismiss),
                                          action: { dismissAction?() }))
    }
    fileprivate init(error: LocalizedError, dismissAction: STZ.ERR.Legacy.Action?) {
        self.init(title: STZ.VIEW.TXT(Noun.Error),
                  message: STZ.VIEW.TXT(error.errorDescription!),
                  dismissButton: .default(STZ.VIEW.TXT(Verb.Dismiss),
                                          action: { dismissAction?(error) }))
    }
}

extension STZ.ERR {
    public enum Legacy {
        public typealias Action = (Error) -> Void
        /// Set an error here to present an Alert when using with
        /// Presenter / Modifier
        public class ViewModel: ObservableObject {
            @Published public var error: LocalizedError? {
                didSet {
                    let shouldBe = self.error != nil
                    guard shouldBe != self.isPresented else { return }
                    self.isPresented = shouldBe
                }
            }
            @Published internal var isPresented = false {
                didSet {
                    guard self.isPresented == false else { return }
                    self.error = nil
                }
            }
            /// Closure is called when alert is dismissed
            public var dismissAction: Action?
            internal var alert: Alert? {
                guard let error = self.error else { return nil }
                return Alert(error: error, dismissAction: self.dismissAction)
            }
            public init() {}
        }
        
        /// If the ViewModel contains an Error, this presents an Alert,
        /// otherwise is transparent view.
        /// Use when needing to present SwiftUI alert from UIKit
        public struct Presenter: View {
            @ObservedObject public var viewModel: ViewModel
            public var body: some View {
                Color.clear.alert(isPresented: self.$viewModel.isPresented,
                                  content: { self.viewModel.alert! })
            }
            public init(_ viewModel: ViewModel) {
                _viewModel = .init(wrappedValue: viewModel)
            }
        }
        
        public struct _LocalizedError: LocalizedError {
            /// A localized message describing what error occurred.
            public var errorDescription: String?

            /// A localized message describing the reason for the failure.
            public var failureReason: String?

            /// A localized message providing "help" text if the user requests help.
            public var helpAnchor: String?
            
            public init(error: NSError) {
                self.errorDescription = error.localizedDescription
                self.failureReason = error.localizedFailureReason
                self.helpAnchor = error.helpAnchor
            }
        }
    }
}
