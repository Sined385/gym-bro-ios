//
//  ExerciseImageCarousel.swift
//  GymBro
//
//  Created by Claude Code on 2026-06-17.
//

import SwiftUI

struct ExerciseImageCarousel: View {
    let imageURLs: [URL]

    // Expanded gallery viewer
    @State private var showExpandedGallery: Bool = false
    @State private var expandedGalleryUrls: [URL] = []
    @State private var expandedGalleryIndex: Int = 0

    var body: some View {
        TabView {
            ForEach(imageURLs, id: \.absoluteString) { imgUrl in
                CachedAsyncImage(url: imgUrl) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(height: 200)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .contentShape(Rectangle())
                        .onTapGesture {
                            expandedGalleryUrls = imageURLs
                            expandedGalleryIndex = imageURLs.firstIndex(of: imgUrl) ?? 0
                            showExpandedGallery = true
                        }
                } placeholder: {
                    ShimmerView()
                        .frame(height: 200)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                } failure: {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.gymBroNeutral100)
                        .frame(height: 200)
                        .overlay(
                            Image(systemName: "photo")
                                .font(.system(size: 32))
                                .foregroundColor(.gymBroNeutral400)
                        )
                }
                .padding(.horizontal, 4)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: imageURLs.count > 1 ? .automatic : .never))
        .frame(height: 220)
        .background(
            ExpandedGalleryView(
                urls: expandedGalleryUrls,
                initialIndex: expandedGalleryIndex,
                isPresented: $showExpandedGallery
            )
            .frame(width: 0, height: 0)
        )
    }
}
