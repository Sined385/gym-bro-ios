//
//  NewPostView.swift
//  GymBro
//
//  Created by Claude Code on 2026-03-19.
//

import SwiftUI

struct NewPostView: View {
    @StateObject private var viewModel: NewPostViewModel = DependencyContainer.shared.resolve(NewPostViewModel.self)
    @Environment(\.dismiss) private var dismiss
    @State private var showImageSourcePicker = false
    let onPostCreated: (CommunityPost) -> Void

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Text input
                TextEditor(text: $viewModel.content)
                    .font(.system(size: 16))
                    .foregroundColor(.gymBroTextPrimary)
                    .scrollContentBackground(.hidden)
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .frame(minHeight: 150)
                    .overlay(alignment: .topLeading) {
                        if viewModel.content.isEmpty {
                            Text("What's on your mind?")
                                .font(.system(size: 16))
                                .foregroundColor(.gymBroNeutral400)
                                .padding(.horizontal, 21)
                                .padding(.top, 20)
                                .allowsHitTesting(false)
                        }
                    }

                // Photo section
                photoSection
                    .padding(.horizontal, 20)
                    .padding(.top, 12)

                Spacer()

                // Error message
                if let error = viewModel.errorMessage {
                    Text(error)
                        .font(.system(size: 13))
                        .foregroundColor(.red)
                        .padding(.horizontal, 20)
                }

                // Post button
                Button {
                    Task {
                        if let post = await viewModel.createPost() {
                            onPostCreated(post)
                            dismiss()
                        }
                    }
                } label: {
                    ZStack {
                        if viewModel.isPosting {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        } else {
                            Text("Post")
                                .font(.system(size: 17, weight: .bold))
                                .foregroundColor(.white)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(Color.gymBroPrimaryGradient)
                    .cornerRadius(16)
                }
                .disabled(!viewModel.canPost)
                .opacity(viewModel.canPost ? 1.0 : 0.5)
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
            .background(Color.gymBroBackground.ignoresSafeArea())
            .navigationTitle("New Post")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.gymBroTextSecondary)
                }
            }
            .imageSourcePicker(isPresented: $showImageSourcePicker) { data in
                Task { await viewModel.handleImageData(data) }
            }
        }
    }

    // MARK: - Photo Section

    private var photoSection: some View {
        VStack(spacing: 10) {
            // Photo preview
            if let photoPreview = viewModel.photoPreview {
                ZStack(alignment: .topTrailing) {
                    photoPreview
                        .resizable()
                        .scaledToFill()
                        .frame(maxHeight: 160)
                        .clipped()
                        .clipShape(RoundedRectangle(cornerRadius: 12))

                    Button {
                        viewModel.removePhoto()
                    } label: {
                        ZStack {
                            Circle()
                                .fill(Color.black.opacity(0.6))
                                .frame(width: 28, height: 28)
                            Image(systemName: "xmark")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.white)
                        }
                    }
                    .buttonStyle(.plain)
                    .padding(8)
                }
            }

            // Attach photo button
            Button {
                showImageSourcePicker = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "photo.badge.plus")
                        .font(.system(size: 16))
                    Text("Attach Photo")
                        .font(.system(size: 14, weight: .medium))
                }
                .foregroundColor(.gymBroTextSecondary)
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .background(Color.clear)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(style: StrokeStyle(lineWidth: 1.5, dash: [6, 4]))
                        .foregroundColor(.gymBroNeutral200)
                )
            }
            .buttonStyle(.plain)

            if viewModel.isUploadingPhoto {
                HStack(spacing: 6) {
                    ProgressView()
                        .scaleEffect(0.7)
                    Text("Uploading photo...")
                        .font(.system(size: 12))
                        .foregroundColor(.gymBroTextSecondary)
                }
            }
        }
    }
}
