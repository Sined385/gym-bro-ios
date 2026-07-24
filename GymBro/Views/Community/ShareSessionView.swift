//
//  ShareSessionView.swift
//  GymBro
//
//  Created by Claude Code on 2026-03-20.
//

import SwiftUI
import Supabase

struct ShareSessionView: View {
    let data: CompletedWorkoutShareData
    var onShare: (CommunityPost) -> Void
    var onSkip: () -> Void

    // Convenience accessors so the rest of the view reads naturally.
    private var sessionDurationMinutes: Int? { data.durationMinutes }
    private var exercises: [ActiveSessionExercise] { data.exercises }
    private var effortLevel: Int { data.effortLevel }
    private var energyLevel: Int { data.energyLevel }
    private var sessionId: String { data.sessionId }

    @State private var postContent: String = ""
    @State private var visibility: String = "global"
    @State private var isSharing: Bool = false
    @State private var errorMessage: String?
    @State private var showImageSourcePicker: Bool = false

    // Photo
    @State private var photoData: Data?
    @State private var photoPreview: Image?
    @State private var uploadedPhotoUrl: String?
    @State private var isUploadingPhoto: Bool = false

    @Environment(\.dismiss) private var dismiss

    private let networkService: NetworkServiceProtocol = DependencyContainer.shared.resolve(NetworkServiceProtocol.self)
    private let analytics: AnalyticsTrackingServiceProtocol = DependencyContainer.shared.resolve(AnalyticsTrackingServiceProtocol.self)

    var body: some View {
        NavigationStack {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 20) {
                    // Workout summary card
                    workoutSummaryCard

                    // User info row
                    userInfoRow

                    // Text editor
                    textEditorSection

                    // Photo attachment
                    photoSection

                    // Bottom buttons
                    actionButtons
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 40)
                .padding(.top, 8)
            }
            .background(Color.gymBroBackground.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Share Your Victory \u{1F389}")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.gymBroNeutral900)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        onSkip()
                        dismiss()
                    } label: {
                        ZStack {
                            Circle()
                                .fill(Color.white)
                                .frame(width: 32, height: 32)
                                .shadow(color: .black.opacity(0.1), radius: 4, y: 2)
                            Image(systemName: "xmark")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.gymBroNeutral900)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .imageSourcePicker(isPresented: $showImageSourcePicker) { data in
            Task { await handleImageData(data) }
        }
    }

    // MARK: - Workout Summary Card

    private var workoutSummaryCard: some View {
        VStack(spacing: 14) {
            // Header
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color(hex: "30C08D"), Color(hex: "28A677")],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 40, height: 40)
                    Image(systemName: "dumbbell.fill")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Workout Complete")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.gymBroNeutral900)

                    HStack(spacing: 4) {
                        if let duration = sessionDurationMinutes {
                            Text("\(duration) MIN")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.gymBroTextSecondary)
                        }
                        Text("\u{2022}")
                            .font(.system(size: 12))
                            .foregroundColor(.gymBroTextSecondary)
                        Text("\(exercises.count) EXERCISES-caps")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.gymBroTextSecondary)
                    }
                }
                Spacer()
            }

            // Stat pills
            HStack(spacing: 8) {
                // Effort
                statPill(
                    label: "Effort",
                    value: "\(effortLevel)/10",
                    color: .gymBroPrimary
                )

                // Energy
                statPill(
                    label: "Energy",
                    value: energyEmoji(for: energyLevel),
                    color: Color(hex: "F5A623")
                )

                // Status
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 12))
                        .foregroundColor(Color(hex: "30C08D"))
                    Text("Done")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(Color(hex: "30C08D"))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color(hex: "30C08D").opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            // Exercises
            if !exercises.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("EXERCISES")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.gymBroTextSecondary)
                        .tracking(0.5)

                    ForEach(shareExerciseGroups, id: \.id) { group in
                        switch group {
                        case .standalone(let exercise):
                            shareExerciseRow(exercise)
                        case .superset(let exercises, _):
                            shareSupersetContainer(exercises)
                        }
                    }
                }
            }
        }
        .padding(16)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(
                    LinearGradient(
                        colors: [Color(hex: "30C08D").opacity(0.5), Color(hex: "28A677").opacity(0.3)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 2
                )
        )
        .gymBroCardShadow()
    }

    // MARK: - User Info Row

    private var userInfoRow: some View {
        HStack(spacing: 10) {
            // We don't have direct access to the current user here, so use a placeholder
            Image(systemName: "person.circle.fill")
                .font(.system(size: 32))
                .foregroundColor(.gymBroPrimary)

            VStack(alignment: .leading, spacing: 2) {
                Text("Your Post")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.gymBroNeutral900)

                Button {
                    visibility = visibility == "global" ? "followers" : "global"
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: visibility == "global" ? "globe" : "lock.fill")
                            .font(.system(size: 10))
                        Text("Sharing to \(visibility == "global" ? String(localized: "Global Feed") : String(localized: "Followers"))")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundColor(.gymBroTextSecondary)
                }
                .buttonStyle(.plain)
            }
            Spacer()
        }
    }

    // MARK: - Text Editor

    private var textEditorSection: some View {
        ZStack(alignment: .topLeading) {
            TextEditor(text: $postContent)
                .font(.system(size: 15))
                .foregroundColor(.gymBroNeutral900)
                .frame(height: 128)
                .padding(8)
                .scrollContentBackground(.hidden)
                .background(Color.gymBroNeutral100)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.gymBroNeutral200, lineWidth: 1)
                )

            if postContent.isEmpty {
                Text("Share your experience... (optional)")
                    .font(.system(size: 15))
                    .foregroundColor(.gymBroNeutral400)
                    .padding(.horizontal, 13)
                    .padding(.vertical, 16)
                    .allowsHitTesting(false)
            }
        }
    }

    // MARK: - Photo Section

    private var photoSection: some View {
        VStack(spacing: 10) {
            // Photo preview
            if let photoPreview {
                ZStack(alignment: .topTrailing) {
                    photoPreview
                        .resizable()
                        .scaledToFill()
                        .frame(maxHeight: 160)
                        .clipped()
                        .clipShape(RoundedRectangle(cornerRadius: 12))

                    Button {
                        self.photoData = nil
                        self.photoPreview = nil
                        self.uploadedPhotoUrl = nil
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

            if isUploadingPhoto {
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

    // MARK: - Action Buttons

    private var actionButtons: some View {
        VStack(spacing: 12) {
            if let error = errorMessage {
                Text(error)
                    .font(.system(size: 13))
                    .foregroundColor(.gymBroPrimary)
            }

            HStack(spacing: 12) {
                // Skip button
                Button {
                    onSkip()
                    dismiss()
                } label: {
                    Text("Skip for Now")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.gymBroTextSecondary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Color.gymBroNeutral100)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                }
                .buttonStyle(.plain)

                // Share button
                Button {
                    Task { await sharePost() }
                } label: {
                    HStack(spacing: 6) {
                        if isSharing {
                            ProgressView()
                                .tint(.white)
                                .scaleEffect(0.8)
                        }
                        Text("Share to Community")
                            .font(.system(size: 15, weight: .bold))
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(
                        LinearGradient(
                            colors: [Color(hex: "30C08D"), Color(hex: "28A677")],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                }
                .buttonStyle(.plain)
                .disabled(isSharing || isUploadingPhoto)
            }
        }
    }

    // MARK: - Actions

    private func sharePost() async {
        isSharing = true
        errorMessage = nil

        // If there's photo data but not yet uploaded, upload first
        if photoData != nil && uploadedPhotoUrl == nil {
            await uploadPhoto()
        }

        let content = postContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? "Just completed a \(sessionDurationMinutes ?? 0) minute workout! \u{1F4AA}"
            : postContent.trimmingCharacters(in: .whitespacesAndNewlines)

        do {
            let post = try await networkService.request(
                CommunityRouter.createPost(
                    content: content,
                    visibility: visibility,
                    workoutSessionId: sessionId,
                    photoUrl: uploadedPhotoUrl,
                    shareConfig: nil,
                    cardImageUrl: nil
                ).endpoint,
                responseType: CommunityPost.self
            )
            analytics.track("post_shared_after_workout", properties: ["session_id": sessionId])
            isSharing = false
            onShare(post)
            dismiss()
        } catch {
            print("❌ Share post failed: \(error)")
            errorMessage = "Failed to share: \(error.localizedDescription)"
            isSharing = false
        }
    }

    private func handleImageData(_ data: Data) async {
        photoData = data
        if let uiImage = UIImage(data: data) {
            photoPreview = Image(uiImage: uiImage)
        }
        await uploadPhoto()
    }

    private func uploadPhoto() async {
        guard let data = photoData else { return }
        guard let jpegData = UIImage(data: data)?.jpegData(compressionQuality: 0.7) else { return }

        isUploadingPhoto = true

        do {
            let session = try await SupabaseConfig.client.auth.session
            let userId = session.user.id.uuidString.lowercased()
            let fileName = "\(userId)/\(UUID().uuidString.lowercased()).jpg"

            _ = try await SupabaseConfig.client.storage
                .from("post-photos")
                .upload(fileName, data: jpegData, options: .init(contentType: "image/jpeg"))

            let publicUrl = try SupabaseConfig.client.storage
                .from("post-photos")
                .getPublicURL(path: fileName)

            uploadedPhotoUrl = publicUrl.absoluteString
        } catch {
            errorMessage = "Photo upload failed."
        }

        isUploadingPhoto = false
    }

    // MARK: - Share Exercise Grouping

    private enum ShareExerciseGroup: Identifiable {
        case standalone(exercise: ActiveSessionExercise)
        case superset(exercises: [ActiveSessionExercise], groupId: String)

        var id: String {
            switch self {
            case .standalone(let exercise): return "standalone-\(exercise.id)"
            case .superset(_, let groupId): return "superset-\(groupId)"
            }
        }
    }

    private var shareExerciseGroups: [ShareExerciseGroup] {
        var groups: [ShareExerciseGroup] = []
        var supersetMap: [String: [ActiveSessionExercise]] = [:]
        var emitted: Set<String> = []

        for exercise in exercises {
            if let groupId = exercise.supersetGroupId {
                if supersetMap[groupId] == nil {
                    supersetMap[groupId] = []
                }
                supersetMap[groupId]?.append(exercise)
            }
        }

        for exercise in exercises {
            if let groupId = exercise.supersetGroupId {
                if !emitted.contains(groupId) {
                    emitted.insert(groupId)
                    if let members = supersetMap[groupId], members.count > 1 {
                        groups.append(.superset(exercises: members, groupId: groupId))
                    } else {
                        groups.append(.standalone(exercise: exercise))
                    }
                }
            } else {
                groups.append(.standalone(exercise: exercise))
            }
        }

        return groups
    }

    private func shareExerciseRow(_ exercise: ActiveSessionExercise, orderLabel: String? = nil) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color(hex: exercise.accentColor))
                    .frame(width: 4, height: 32)

                if let orderLabel {
                    Text(orderLabel)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(Color(hex: "7A82F6"))
                        .frame(width: 18)
                }

                // Exercise image
                if let imageUrl = exercise.imageUrl, let url = URL(string: imageUrl) {
                    CachedAsyncImage(url: url) { image in
                        image.resizable().aspectRatio(contentMode: .fill)
                    } placeholder: {
                        shareExercisePlaceholder
                    } failure: {
                        shareExercisePlaceholder
                    }
                    .frame(width: 36, height: 36)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                } else {
                    shareExercisePlaceholder
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(exercise.name)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.gymBroNeutral900)
                        .lineLimit(1)

                    if !exercise.muscleGroup.isEmpty {
                        Text((MuscleGroup(rawValue: exercise.muscleGroup)?.displayName ?? exercise.muscleGroup).uppercased())
                            .font(.system(size: 10, weight: .semibold))
                            .tracking(0.4)
                            .foregroundColor(.gymBroTextSecondary)
                    }
                }

                Spacer()
            }

            // Per-set chips
            shareSetChips(for: exercise)
                .padding(.leading, 12)
        }
    }

    @ViewBuilder
    private func shareSetChips(for exercise: ActiveSessionExercise) -> some View {
        let completedSets = exercise.sets.filter { $0.isCompleted }
        if !completedSets.isEmpty {
            HStack(spacing: 4) {
                ForEach(completedSets) { set in
                    let text = SetDisplay.line(
                        weight: set.weight,
                        weightUnit: set.weightUnit,
                        reps: set.reps,
                        isBodyweight: set.isBodyweight
                    )
                    Text(text)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(Color(hex: "737373"))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color(hex: "F5F5F5"))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }
            }
        }
    }

    private func shareSupersetContainer(_ exercises: [ActiveSessionExercise]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "square.stack.fill")
                    .font(.system(size: 10, weight: .bold))
                Text("SUPERSET")
                    .font(.system(size: 10, weight: .bold))
                    .tracking(0.6)
            }
            .foregroundColor(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Color(hex: "7A82F6"))
            .clipShape(Capsule())

            ForEach(Array(exercises.enumerated()), id: \.element.id) { i, exercise in
                shareExerciseRow(
                    exercise,
                    orderLabel: exercise.supersetOrder ?? String(Character(UnicodeScalar(65 + i)!))
                )
            }
        }
        .padding(10)
        .background(Color(hex: "7A82F6").opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color(hex: "7A82F6").opacity(0.15), lineWidth: 1)
        )
    }

    private var shareExercisePlaceholder: some View {
        RoundedRectangle(cornerRadius: 10)
            .fill(Color(hex: "F5F5F5"))
            .frame(width: 36, height: 36)
            .overlay(
                Image(systemName: "dumbbell.fill")
                    .font(.system(size: 14))
                    .foregroundColor(Color(hex: "D4D4D4"))
            )
    }

    // MARK: - Helpers

    private func energyEmoji(for level: Int) -> String {
        switch level {
        case 1: return "\u{1F629}"
        case 2: return "\u{1F62E}\u{200D}\u{1F4A8}"
        case 3: return "\u{1F610}"
        case 4: return "\u{1F642}"
        case 5: return "\u{1F929}"
        default: return "\u{2753}"
        }
    }

    private func statPill(label: String, value: String, color: Color) -> some View {
        HStack(spacing: 4) {
            Text(value)
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(color)
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.gymBroTextSecondary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(color.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}
