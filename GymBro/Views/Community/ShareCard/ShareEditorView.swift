//
//  ShareEditorView.swift
//  GymBro
//
//  v1 share generator editor. Replaces ShareSessionView. Single sheet:
//  live preview card on top, background swatches / stat pills / exercise
//  toggles below, share rail (Community + external) at the bottom.
//

import SwiftUI

struct ShareEditorView: View {
    let data: CompletedWorkoutShareData
    var onShare: (CommunityPost) -> Void
    var onSkip: () -> Void

    @State private var config: ShareConfig
    @State private var caption: String = ""
    @FocusState private var captionFocused: Bool
    @State private var visibility: String = "global"
    @State private var isSharing: Bool = false
    @State private var errorMessage: String?
    @State private var pendingActivityItems: [Any]? = nil
    @State private var showActivity: Bool = false
    @State private var showBackgroundPhotoPicker: Bool = false
    @State private var authorHandle: String?
    @State private var toastMessage: ToastMessage?

    @EnvironmentObject private var appDataState: AppDataState
    @State private var isUploadingBackgroundPhoto: Bool = false

    @Environment(\.dismiss) private var dismiss

    private let networkService: NetworkServiceProtocol = DependencyContainer.shared.resolve(NetworkServiceProtocol.self)
    private let analytics: AnalyticsTrackingServiceProtocol = DependencyContainer.shared.resolve(AnalyticsTrackingServiceProtocol.self)

    private var workout: WorkoutSnapshot {
        WorkoutSnapshot.from(data, authorHandle: authorHandle)
    }

    init(data: CompletedWorkoutShareData, onShare: @escaping (CommunityPost) -> Void, onSkip: @escaping () -> Void) {
        self.data = data
        self.onShare = onShare
        self.onSkip = onSkip
        // Compute the default config from a temporary snapshot — we can't
        // call the computed property in init.
        let snapshot = WorkoutSnapshot.from(data)
        _config = State(initialValue: ShareConfig.defaultConfig(for: snapshot))
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                topBar
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 18) {
                        preview
                        titleField
                        backgroundSection
                        statsSection
                        exercisesSection
                        captionField
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 24)
                }
                .scrollDismissesKeyboard(.interactively)
                shareRail
            }
            .background(Color.gymBroBackground.ignoresSafeArea())
            .navigationBarHidden(true)
            .alert("Couldn't share", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage ?? "")
            }
            .sheet(isPresented: $showActivity) {
                if let items = pendingActivityItems {
                    ActivityViewControllerWrapper(items: items)
                }
            }
            .imageSourcePicker(isPresented: $showBackgroundPhotoPicker) { data in
                Task { await uploadBackgroundPhoto(data: data) }
            }
            .task { await loadAuthorHandle() }
            .overlay(alignment: .top) {
                if let toast = toastMessage {
                    ToastBanner(message: toast)
                        .padding(.top, 60)
                        .padding(.horizontal, 20)
                        .zIndex(10)
                }
            }
            .animation(.spring(response: 0.35, dampingFraction: 0.85), value: toastMessage)
        }
    }

    /// Pulls the signed-in user's @handle so the card footer shows it on
    /// rasterized output (Save / Stories / Link). Without this, the editor
    /// renders the card with no handle even though the live feed card has it.
    private func loadAuthorHandle() async {
        guard authorHandle == nil else { return }
        do {
            let profile = try await networkService.request(
                CommunityRouter.myProfile.endpoint,
                responseType: MyProfileResponse.self
            )
            authorHandle = profile.user.username
        } catch {
            // Non-fatal — card just renders without the handle line.
            print("[ShareEditor] couldn't load profile for @handle: \(error.localizedDescription)")
        }
    }

    // MARK: Top bar

    private var topBar: some View {
        HStack(alignment: .center) {
            Button {
                onSkip()
                dismiss()
            } label: {
                Text("Cancel")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.gymBroTextSecondary)
            }
            .buttonStyle(.plain)
            Spacer()
            Text("Share workout")
                .font(.system(size: 16, weight: .heavy))
                .foregroundColor(.gymBroNeutral900)
            Spacer()
            // Symmetric spacing — Cancel sits at the leading edge, so reserve
            // an equivalent invisible spacer on the trailing side to keep the
            // title centered now that the top-right Share pill is gone
            // (it was redundant with the Community rail button below).
            Text("Cancel")
                .font(.system(size: 15, weight: .semibold))
                .opacity(0)
                .accessibilityHidden(true)
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
        .padding(.bottom, 12)
        .background(Color.gymBroBackground)
    }

    // MARK: Preview

    private var preview: some View {
        ShareCardView(config: config, workout: workout)
            .frame(width: 220)
            .shadow(color: .black.opacity(0.18), radius: 24, x: 0, y: 16)
            .padding(.vertical, 4)
            .frame(maxWidth: .infinity)
    }

    // MARK: Background section

    private var backgroundSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionLabel("BACKGROUND")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    photoUploadTile
                    ForEach(ShareBackgroundPreset.allCases) { preset in
                        bgPresetTile(preset)
                    }
                }
                // Outer padding gives the selection ring + glow room so it
                // doesn't get clipped at the top / bottom of the ScrollView.
                .padding(.vertical, 6)
                .padding(.horizontal, 2)
            }
        }
    }

    private var photoUploadTile: some View {
        let isPhoto = { if case .photo = config.background { return true } else { return false } }()
        return Button {
            showBackgroundPhotoPicker = true
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white)
                    .frame(width: 46, height: 46)
                if let url = config.background.photoURL {
                    CachedAsyncImage(url: url) { image in
                        image.resizable().scaledToFill()
                    } placeholder: {
                        Color.gymBroNeutral100
                    } failure: {
                        Color.gymBroNeutral100
                    }
                    .frame(width: 46, height: 46)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                } else if isUploadingBackgroundPhoto {
                    ProgressView()
                        .scaleEffect(0.7)
                        .tint(.gymBroNeutral600)
                } else {
                    Image(systemName: "photo.on.rectangle")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.gymBroNeutral600)
                }
            }
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isPhoto ? Color.gymBroPrimary : Color(hex: "D4D4D4"),
                            style: StrokeStyle(lineWidth: isPhoto ? 2 : 1.5, dash: isPhoto ? [] : [4, 3]))
            )
            .overlay {
                if isPhoto {
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color.gymBroPrimary.opacity(0.18), lineWidth: 3)
                        .padding(-2)
                }
            }
        }
        .buttonStyle(.plain)
        .disabled(isUploadingBackgroundPhoto)
    }

    private func bgPresetTile(_ preset: ShareBackgroundPreset) -> some View {
        let isSelected = config.background == .preset(preset)
        return Button {
            config.background = .preset(preset)
        } label: {
            RoundedRectangle(cornerRadius: 12)
                .fill(preset.gradient)
                .frame(width: 46, height: 46)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(isSelected ? Color.gymBroPrimary : Color(hex: "ECECF0"), lineWidth: isSelected ? 2 : 1)
                )
                .overlay {
                    if isSelected {
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(Color.gymBroPrimary.opacity(0.18), lineWidth: 3)
                            .padding(-2)
                    }
                }
        }
        .buttonStyle(.plain)
    }

    // MARK: Stats section

    private var statsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionLabel("STATS · TAP TO TOGGLE")
            // Left-packed wrap: each chip is its natural width, rows flow
            // left-to-right, partial selections compress to the left with
            // no orphan whitespace on the right.
            WrapHStackLeading(spacing: 8, lineSpacing: 8) {
                ForEach(StatKey.allCases) { stat in
                    statChip(stat)
                }
            }
        }
    }

    @ViewBuilder
    private func statChip(_ stat: StatKey) -> some View {
        let isOn = config.selectedStatKeys.contains(stat)
        Button {
            if isOn { config.selectedStatKeys.remove(stat) }
            else    { config.selectedStatKeys.insert(stat) }
        } label: {
            HStack(spacing: 6) {
                if isOn {
                    Image(systemName: "checkmark")
                        .font(.system(size: 9, weight: .heavy))
                        .foregroundColor(.white)
                }
                Text(stat.label)
                    .font(.system(size: 13, weight: .heavy))
                    .foregroundColor(isOn ? .white : .gymBroNeutral900)
                Text(workout.value(for: stat))
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(isOn ? .white.opacity(0.7) : .gymBroNeutral400)
                    .monospacedDigit()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            // minWidth so short labels (PRs, Sets) line up column-style with
            // longer ones (Volume, Avg HR), but content can still grow past
            // it. Removes the "row 2 chips don't align with row 1" visual.
            .frame(minWidth: 100, alignment: .leading)
            .background(isOn ? Color(hex: "2D3240") : Color.white)
            .clipShape(Capsule())
            .overlay(
                Capsule().stroke(isOn ? Color.clear : Color(hex: "ECECF0"), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: Exercises section

    private var exercisesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                sectionLabel("EXERCISES · \(config.selectedExerciseIds.count) OF \(workout.exercises.count)")
                Spacer()
                Button {
                    if config.selectedExerciseIds.count == workout.exercises.count {
                        config.selectedExerciseIds.removeAll()
                    } else {
                        config.selectedExerciseIds = Set(workout.exercises.map(\.id))
                    }
                } label: {
                    Text(config.selectedExerciseIds.count == workout.exercises.count ? "Clear" : "Select all")
                        .font(.system(size: 11, weight: .heavy))
                        .foregroundColor(.gymBroPrimary)
                }
                .buttonStyle(.plain)
            }
            VStack(spacing: 6) {
                ForEach(workout.exercises) { ex in
                    exerciseRow(ex)
                }
            }
        }
    }

    private func exerciseRow(_ ex: WorkoutSnapshotExercise) -> some View {
        let isOn = config.selectedExerciseIds.contains(ex.id)
        let accent = Color(hex: ex.accentColorHex)
        return Button {
            if isOn { config.selectedExerciseIds.remove(ex.id) }
            else    { config.selectedExerciseIds.insert(ex.id) }
        } label: {
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(isOn ? Color.gymBroPrimary : Color.white)
                    if isOn {
                        Image(systemName: "checkmark")
                            .font(.system(size: 11, weight: .heavy))
                            .foregroundColor(.white)
                    }
                }
                .frame(width: 24, height: 24)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(isOn ? Color.clear : Color(hex: "ECECF0"), lineWidth: 1.5)
                )

                VStack(alignment: .leading, spacing: 1) {
                    HStack(spacing: 5) {
                        Text(ex.name)
                            .font(.system(size: 13, weight: .heavy))
                            .foregroundColor(.gymBroNeutral900)
                            .lineLimit(1)
                        if ex.isPR {
                            Text("PR")
                                .font(.system(size: 8, weight: .heavy))
                                .foregroundColor(.white)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 1)
                                .background(Color.gymBroPrimary)
                                .clipShape(RoundedRectangle(cornerRadius: 3))
                        }
                    }
                    if let mg = ex.muscleGroup, !mg.isEmpty {
                        // Cardio shows time + distance instead of "N SETS".
                        Text(ex.isCardio ? mg.uppercased() : "\(mg.uppercased()) · \(ex.setChips.count) SETS")
                            .font(.system(size: 9, weight: .heavy))
                            .tracking(0.4)
                            .foregroundColor(.gymBroTextSecondary)
                    }
                }
                Spacer(minLength: 4)
                if ex.isCardio {
                    Text(ex.bestSetLine)
                        .font(.system(size: 10, weight: .heavy))
                        .foregroundColor(accent)
                        .monospacedDigit()
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(accent.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                } else {
                    HStack(spacing: 3) {
                        ForEach(Array(ex.setChips.prefix(4).enumerated()), id: \.offset) { _, chip in
                            Text(chip)
                                .font(.system(size: 9, weight: .heavy))
                                .foregroundColor(accent)
                                .monospacedDigit()
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .background(accent.opacity(0.12))
                                .clipShape(RoundedRectangle(cornerRadius: 4))
                        }
                    }
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 9)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isOn ? Color.gymBroPrimary.opacity(0.5) : Color(hex: "ECECF0"), lineWidth: isOn ? 1.5 : 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: Title

    private var titleField: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionLabel("TITLE")
            TextField("Workout title", text: $config.title)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.gymBroNeutral900)
                .padding(12)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color(hex: "ECECF0"), lineWidth: 1)
                )
                .submitLabel(.done)
        }
    }

    // MARK: Caption

    private var captionField: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionLabel("CAPTION")
            TextField("Say something about this workout…", text: $caption, axis: .vertical)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.gymBroNeutral900)
                .focused($captionFocused)
                .padding(12)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color(hex: "ECECF0"), lineWidth: 1)
                )
                .lineLimit(3...6)
                .toolbar {
                    // The vertical TextField turns Return into a newline, so
                    // give the keyboard an explicit Done to dismiss it.
                    ToolbarItemGroup(placement: .keyboard) {
                        Spacer()
                        Button("Done") { captionFocused = false }
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.gymBroPrimary)
                    }
                }
        }
    }

    // MARK: Share rail

    private var shareRail: some View {
        HStack(spacing: 0) {
            railButton(
                label: "Community",
                background: AnyShapeStyle(LinearGradient(
                    colors: [.gymBroPrimary, .gymBroPrimary],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                )),
                labelColor: .gymBroPrimary,
                shadow: Color.gymBroPrimary.opacity(0.35)
            ) {
                Image(systemName: "person.2.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)
            } action: {
                Task { await postToCommunity() }
            }

            railButton(
                label: "Stories",
                background: AnyShapeStyle(LinearGradient(
                    // Instagram brand gradient (yellow → orange → pink → purple).
                    colors: [Color(hex: "FEDA77"), Color(hex: "F58529"),
                             Color(hex: "DD2A7B"), Color(hex: "8134AF"),
                             Color(hex: "515BD4")],
                    startPoint: .bottomLeading, endPoint: .topTrailing
                )),
                labelColor: .gymBroNeutral600
            ) {
                instagramGlyph
            } action: {
                Task { await shareToStories() }
            }

            railButton(
                label: "Save",
                background: AnyShapeStyle(Color.gymBroNeutral100),
                labelColor: .gymBroNeutral600
            ) {
                Image(systemName: "square.and.arrow.down")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.gymBroNeutral900)
            } action: {
                Task { await saveCardToPhotos() }
            }

            railButton(
                label: "Link",
                background: AnyShapeStyle(Color.gymBroNeutral100),
                labelColor: .gymBroNeutral600
            ) {
                Image(systemName: "link")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.gymBroNeutral900)
            } action: {
                Task { await shareLink() }
            }
        }
        .padding(.horizontal, 12)
        .padding(.top, 12)
        .padding(.bottom, 24)
        .background(Color.white)
        .overlay(
            Rectangle()
                .fill(Color(hex: "ECECF0"))
                .frame(height: 1),
            alignment: .top
        )
    }

    /// Hand-drawn Instagram camera glyph (rounded square + center circle +
    /// upper-right indicator dot). Avoids needing a bundled brand asset.
    private var instagramGlyph: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 6)
                .stroke(Color.white, lineWidth: 2)
                .frame(width: 22, height: 22)
            Circle()
                .stroke(Color.white, lineWidth: 2)
                .frame(width: 10, height: 10)
            Circle()
                .fill(Color.white)
                .frame(width: 3, height: 3)
                .offset(x: 6, y: -6)
        }
        .frame(width: 24, height: 24)
    }

    private func railButton<Icon: View>(
        label: String,
        background: AnyShapeStyle,
        labelColor: Color,
        shadow: Color = .clear,
        @ViewBuilder icon: () -> Icon,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 5) {
                ZStack {
                    Circle()
                        .fill(background)
                        .frame(width: 46, height: 46)
                    icon()
                }
                .shadow(color: shadow, radius: 8, x: 0, y: 4)
                Text(label)
                    .font(.system(size: 10, weight: .heavy))
                    .foregroundColor(labelColor)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }

    // MARK: Actions

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .heavy))
            .tracking(0.7)
            .foregroundColor(.gymBroNeutral600)
            .padding(.horizontal, 4)
    }

    /// Instagram Stories hand-off. IG requires `source_application` (a Facebook
    /// App ID registered in the FB Developer console — IG rejects the share
    /// with "this app doesn't support Stories sharing" without it). The FB App
    /// ID is read from Info.plist's `FacebookAppID`; if it's missing or still
    /// the placeholder, we fall back to the system share sheet so the user
    /// can at least send the image manually.
    private func shareToStories() async {
        guard let image = await renderedCardImage(), let png = image.pngData() else { return }
        let scheme = URL(string: "instagram-stories://share")!
        let fbAppID = (Bundle.main.object(forInfoDictionaryKey: "FacebookAppID") as? String) ?? ""
        let canHandIG = UIApplication.shared.canOpenURL(scheme)
            && !fbAppID.isEmpty
            && fbAppID != "$(FACEBOOK_APP_ID)"
            && !fbAppID.contains("REPLACE_ME")

        if canHandIG, let igURL = URL(string: "instagram-stories://share?source_application=\(fbAppID)") {
            UIPasteboard.general.setItems(
                [["com.instagram.sharedSticker.backgroundImage": png]],
                options: [.expirationDate: Date().addingTimeInterval(60 * 5)]
            )
            _ = await UIApplication.shared.open(igURL)
            analytics.track("share_card_exported", properties: ["session_id": data.sessionId, "target": "stories"])
        } else {
            // No FB App ID configured → IG would reject. Use system share sheet.
            pendingActivityItems = [image]
            showActivity = true
        }
    }

    /// Save directly to Photos via UIImageWriteToSavedPhotosAlbum (Photos
    /// add-only permission via Info.plist's NSPhotoLibraryAddUsageDescription).
    /// Fires a success-style haptic and a small toast on completion so the user
    /// gets immediate native-style confirmation that the image hit the album.
    private func saveCardToPhotos() async {
        guard let image = await renderedCardImage() else { return }
        UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        showToast(text: "Saved to Photos", systemImage: "checkmark.circle.fill")
        analytics.track("share_card_exported", properties: ["session_id": data.sessionId, "target": "save"])
    }

    private func showToast(text: String, systemImage: String) {
        toastMessage = ToastMessage(text: text, systemImage: systemImage)
        Task {
            try? await Task.sleep(nanoseconds: 1_800_000_000)
            await MainActor.run {
                if toastMessage?.text == text { toastMessage = nil }
            }
        }
    }

    private func renderedCardImage() async -> UIImage? {
        if let image = await ShareCardRasterizer.render(config: config, workout: workout) {
            return image
        }
        errorMessage = "Couldn't render the share card."
        return nil
    }

    private func uploadBackgroundPhoto(data imageData: Data) async {
        isUploadingBackgroundPhoto = true
        defer { isUploadingBackgroundPhoto = false }
        do {
            let url = try await PostCardUploadService.uploadRawImageData(imageData)
            config.background = .photo(url: url)
        } catch {
            errorMessage = "Couldn't upload that photo: \(error.localizedDescription)"
        }
    }

    /// Decoupled from posts: uploads the rasterized card to Storage, creates a
    /// SharedCard row on the backend (no community post), and hands off the
    /// resulting gyymjaam.com/c/{id} URL to the system share sheet. iMessage /
    /// Slack / Twitter unfurl the link via the og:image set by /c/:shareId.
    private func shareLink() async {
        guard !isSharing else { return }
        isSharing = true
        defer { isSharing = false }
        let cardImageUrl: String
        do {
            cardImageUrl = try await PostCardUploadService.uploadCardImage(
                config: config,
                workout: workout
            )
        } catch {
            errorMessage = "Couldn't upload the share image: \(error.localizedDescription)"
            return
        }
        let response: SharedCardResponse
        do {
            response = try await networkService.request(
                ShareRouter.createSharedCard(
                    cardImageUrl: cardImageUrl,
                    shareConfig: config.toDictionary(),
                    workoutSessionId: data.sessionId
                ).endpoint,
                responseType: SharedCardResponse.self
            )
        } catch {
            errorMessage = "Couldn't create share link: \(error.localizedDescription)"
            return
        }
        guard let url = URL(string: response.shareUrl) else {
            errorMessage = "Couldn't build share link."
            return
        }
        pendingActivityItems = [url]
        showActivity = true
        analytics.track("share_card_exported", properties: ["session_id": data.sessionId, "target": "link"])
    }

    private func postToCommunity() async {
        guard !isSharing else { return }
        isSharing = true

        let trimmed = caption.trimmingCharacters(in: .whitespacesAndNewlines)
        let content = trimmed.isEmpty
            ? "Just finished a \(data.durationMinutes ?? 0) minute workout! \u{1F4AA}"
            : trimmed

        // Best-effort: rasterize and upload the share card. Failure is non-fatal
        // — the post still goes through with share_config alone; only link
        // unfurls degrade to the legacy fallback.
        var cardImageUrl: String? = nil
        do {
            cardImageUrl = try await PostCardUploadService.uploadCardImage(
                config: config,
                workout: workout
            )
        } catch {
            print("[ShareEditor] card upload failed: \(error.localizedDescription)")
        }

        do {
            let post = try await networkService.request(
                CommunityRouter.createPost(
                    content: content,
                    visibility: visibility,
                    workoutSessionId: data.sessionId,
                    photoUrl: nil,
                    shareConfig: config.toDictionary(),
                    cardImageUrl: cardImageUrl
                ).endpoint,
                responseType: CommunityPost.self
            )
            analytics.track("post_shared_after_workout", properties: ["session_id": data.sessionId])
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            isSharing = false
            // Set the redirect signal BEFORE dismissing so MainTabView sees it
            // when the sheet closes. Feed will switch tabs + prepend the post.
            appDataState.pendingFeedPost = post
            onShare(post)
            dismiss()
        } catch {
            errorMessage = "Failed to share: \(error.localizedDescription)"
            isSharing = false
        }
    }
}

// MARK: - Toast

/// Small native-feeling confirmation banner. Holds the text + SF Symbol for the
/// glyph; the editor's `.overlay` renders + auto-dismisses it after ~1.8s.
struct ToastMessage: Equatable {
    let text: String
    let systemImage: String
}

struct ToastBanner: View {
    let message: ToastMessage

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: message.systemImage)
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(Color(hex: "30C08D"))
            Text(message.text)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.black.opacity(0.82))
        )
        .shadow(color: .black.opacity(0.18), radius: 12, x: 0, y: 6)
        .transition(.move(edge: .top).combined(with: .opacity))
    }
}

// MARK: - Left-packed wrap layout

/// Lays children left-to-right, wrapping to a new line when the next child
/// would overflow the proposed width. Each child gets its intrinsic size —
/// no stretching. iOS 16+ Layout protocol.
private struct WrapHStackLeading: Layout {
    var spacing: CGFloat = 8
    var lineSpacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        let rows = rows(for: subviews, maxWidth: maxWidth)
        let height = rows.reduce(0) { $0 + $1.height } + CGFloat(max(0, rows.count - 1)) * lineSpacing
        let width = proposal.width ?? (rows.map(\.width).max() ?? 0)
        return CGSize(width: width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let rows = rows(for: subviews, maxWidth: bounds.width)
        var y = bounds.minY
        for row in rows {
            var x = bounds.minX
            for index in row.indices {
                let size = subviews[index].sizeThatFits(.unspecified)
                subviews[index].place(at: CGPoint(x: x, y: y), anchor: .topLeading, proposal: ProposedViewSize(size))
                x += size.width + spacing
            }
            y += row.height + lineSpacing
        }
    }

    private struct Row {
        var indices: [Int]
        var width: CGFloat
        var height: CGFloat
    }

    private func rows(for subviews: Subviews, maxWidth: CGFloat) -> [Row] {
        var result: [Row] = []
        var current = Row(indices: [], width: 0, height: 0)
        for (i, sub) in subviews.enumerated() {
            let size = sub.sizeThatFits(.unspecified)
            let projected = current.indices.isEmpty ? size.width : current.width + spacing + size.width
            if projected > maxWidth && !current.indices.isEmpty {
                result.append(current)
                current = Row(indices: [i], width: size.width, height: size.height)
            } else {
                current.indices.append(i)
                current.width = projected
                current.height = max(current.height, size.height)
            }
        }
        if !current.indices.isEmpty { result.append(current) }
        return result
    }
}

// MARK: - UIActivityViewController wrapper

private struct ActivityViewControllerWrapper: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
