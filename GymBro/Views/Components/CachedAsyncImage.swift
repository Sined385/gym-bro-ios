//
//  CachedAsyncImage.swift
//  GymBro
//
//  Created by Claude Code on 2026-04-02.
//

import SwiftUI
import SDWebImageSwiftUI

struct CachedAsyncImage<Content: View, Placeholder: View, Failure: View>: View {
    let url: URL?
    let content: (Image) -> Content
    let placeholder: () -> Placeholder
    let failure: () -> Failure

    init(
        url: URL?,
        @ViewBuilder content: @escaping (Image) -> Content,
        @ViewBuilder placeholder: @escaping () -> Placeholder,
        @ViewBuilder failure: @escaping () -> Failure
    ) {
        self.url = url
        self.content = content
        self.placeholder = placeholder
        self.failure = failure
    }

    var body: some View {
        WebImage(url: url) { phase in
            switch phase {
            case .success(let image):
                let _ = print("[CachedAsyncImage] ✅ Loaded: \(url?.absoluteString ?? "nil")")
                content(image)
            case .failure(let error):
                let _ = print("[CachedAsyncImage] ❌ Failed: \(url?.absoluteString ?? "nil") — \(error)")
                failure()
            case .empty:
                let _ = print("[CachedAsyncImage] ⏳ Loading: \(url?.absoluteString ?? "nil")")
                placeholder()
            }
        }
    }
}
