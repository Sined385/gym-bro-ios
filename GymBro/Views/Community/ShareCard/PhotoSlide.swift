//
//  PhotoSlide.swift
//  GymBro
//
//  Carousel slide #2: the post's photo, full-bleed. Tap to expand handled
//  by the host (PostCardView).
//

import SwiftUI

struct PhotoSlide: View {
    let url: URL

    var body: some View {
        CachedAsyncImage(url: url) { image in
            image
                .resizable()
                .aspectRatio(contentMode: .fill)
        } placeholder: {
            ShimmerView()
        } failure: {
            ZStack {
                Color.gymBroNeutral100
                Image(systemName: "photo")
                    .font(.system(size: 32))
                    .foregroundColor(.gymBroNeutral400)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
    }
}
