
//
//  Created by Jeffrey Bergier on 2020/12/05.
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
import WebKit

struct WebView: View {
    
    struct Input {
        var shouldLoad: Bool = false
        var originalURLString: String = ""
        var maxThumbSize: Int = 100_000
        var snapConfig: WKSnapshotConfiguration = {
            let config = WKSnapshotConfiguration()
            config.afterScreenUpdates = true
            config.snapshotWidth = NSNumber(value: 300.0)
            return config
        }()
    }
    
    class Output: ObservableObject {
        @Published var isLoading: Bool = false
        @Published var resolvedURLString: String = ""
        @Published var title: String = ""
        @Published var thumbnail: Result<Data, Error>?
        var kvo = [NSKeyValueObservation]()
    }

    
    @Binding var input: Input
    var output: Output
    
    init(input: Binding<Input>, output: Output) {
        _input = input
        self.output = output
    }
    
    private func update(_ wv: WKWebView, context: Context) {
        guard self.input.shouldLoad else {
            wv.stopLoading()
            return
        }
        guard let originalURL = URL(string: self.input.originalURLString) else { return }
        let request = URLRequest(url: originalURL)
        wv.load(request)
    }
    
    private func makeWebView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        let wv = WKWebView(frame: .zero, configuration: config)
        let token1 = wv.observe(\.isLoading) { _, _ in
            if wv.isLoading == false {
                wv.snap_takeSnapshot(with: self.input) { self.output.thumbnail = $0 }
            }
            self.output.isLoading = wv.isLoading
        }
        let token2 = wv.observe(\.url) { _, _ in
            self.output.resolvedURLString = wv.url?.absoluteString ?? ""
        }
        let token3 = wv.observe(\.title) { _, _ in
            self.output.title = wv.title ?? ""
        }
        self.output.kvo = [token1, token2, token3]
        return wv
    }
}

#if canImport(AppKit)

import AppKit

extension WebView: NSViewRepresentable {
    func updateNSView(_ wv: WKWebView, context: Context) {
        self.update(wv, context: context)
    }
    
    func makeNSView(context: Context) -> WKWebView {
        let wv = self.makeWebView(context: context)
        wv.pageZoom = 0.7
        return wv
    }
}

extension WKWebView {
    fileprivate func snap_takeSnapshot(with input: WebView.Input,
                                       completion: @escaping (Result<Data, Error>) -> Void)
    {
        self.takeSnapshot(with: input.snapConfig) { image, error in
            if let error = error {
                completion(.failure(.take(error)))
                return
            }
            guard
                let tiff = image?.tiffRepresentation,
                let rep = NSBitmapImageRep(data: tiff),
                let data = rep.representation(using: NSBitmapImageRep.FileType.png, properties: [:])
            else {
                completion(.failure(.convert))
                return
            }
            guard data.count <= input.maxThumbSize else {
                completion(.failure(.size(data.count)))
                return
            }
            completion(.success(data))
        }
    }
}
#endif

#if canImport(UIKit)

import UIKit

extension WebView: UIViewRepresentable {
    func updateUIView(_ wv: WKWebView, context: Context) {
        self.update(wv, context: context)
    }
    
    func makeUIView(context: Context) -> WKWebView {
        let wv = self.makeWebView(context: context)
        wv.transform = .init(scaleX: 0.7, y: 0.7)
        wv.isUserInteractionEnabled = false
        return wv
    }
}

extension WKWebView {
    fileprivate func snap_takeSnapshot(with input: WebView.Input,
                                       completion: @escaping (Result<Data, Error>) -> Void)
    {
        self.takeSnapshot(with: input.snapConfig) { image, error in
            if let error = error {
                completion(.failure(.take(error)))
                return
            }
            guard let data = image?.pngData() else {
                completion(.failure(.convert))
                return
            }
            guard data.count <= input.maxThumbSize else {
                completion(.failure(.size(data.count)))
                return
            }
            completion(.success(data))
        }
    }
}
#endif
