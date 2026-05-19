# Share Post Builder — Plan & Resume Context

Work-in-progress for the new share-card composition flow. Parked on branch
**`share-post-builder`** while we work on something else. This doc is the
hand-off so we can pick the work back up without re-reading the whole arc.

To resume: `git checkout share-post-builder`.

---

## What's already built (on `share-post-builder`)

### iOS — new files
- `GymBro/Models/ShareConfig.swift` — `Codable` struct that drives every
  card surface: `background: ShareBackground` (enum: `.preset(...)` or
  `.photo(url:)`), `selectedStatKeys: Set<StatKey>`, `selectedExerciseIds:
  Set<String>`, `title`, `category`. Wire format `{kind, preset|url}` is
  forward-tolerant. Adapter `WorkoutSnapshot.from(...)` works from either
  `CompletedWorkoutShareData` (post-completion) or `WorkoutAttachment`
  (feed read-back).
- `GymBro/Views/Community/ShareCard/ShareCardView.swift` — 9:16 share
  card. Scales every internal dimension off `geo.size.width / 360` so the
  same view renders sharp at 220pt (editor preview), ~360pt (feed card),
  and 1080pt (ImageRenderer). Photo background is applied via
  `.background()` modifier so the image can't push the layout out of 9:16.
  Header shows GYMJAM + `Image("AppLogo")` from the new
  `Resources/Assets.xcassets/AppLogo.imageset/` (cloned from the AppIcon).
- `GymBro/Views/Community/ShareCard/ShareEditorView.swift` — the editor
  sheet. Top bar (Cancel · "Share workout" · Share pill), live
  `ShareCardView` preview at 220pt, BACKGROUND row (photo-upload tile +
  preset swatches), STATS row (`WrapHStackLeading` left-packed chips with
  `minWidth: 100` for column alignment), EXERCISES rows with PR badges +
  set chips, caption, sticky share rail.
- `GymBro/Views/Community/ShareCard/ExerciseListSlide.swift`,
  `PhotoSlide.swift` — leftover from the earlier carousel design. Not
  used by the current single-card layout but kept around in case we
  re-enable multi-slide in a future iteration.
- `GymBro/Core/Extensions/ImageRenderer+ShareCard.swift` —
  `ShareCardRasterizer.render(config:workout:) -> UIImage?` at 1080×1920.
- `GymBro/Services/PostCardUploadService.swift` —
  `uploadCardImage(config:workout:)` (rasterizes + uploads to
  `post-cards/{userId}/card-{uuid}.jpg`) and `uploadRawImageData(_:)`
  (used by the photo-bg picker for `bg-{uuid}.jpg`).

### iOS — edited
- `GymBro/Models/CommunityModels.swift` — `CommunityPost` gains
  `shareConfig: ShareConfig?` + `cardImageUrl: String?` with
  `decodeIfPresent`.
- `GymBro/Services/Networking/APIRouter.swift` —
  `CommunityRouter.createPost` takes two extra params: `shareConfig:
  [String: Any]?` + `cardImageUrl: String?` (serialized into the JSON body).
  All 4 callsites updated.
- `GymBro/Views/MainTabView.swift` — sheet now presents `ShareEditorView`
  instead of `ShareSessionView` (legacy file kept on disk; not deleted).
- `GymBro/Views/Community/PostCardView.swift` — workout posts render a
  single `ShareCardView` (no carousel) from
  `post.shareConfig ?? .defaultConfig(for: snapshot)`. Photo, if any,
  renders as a separate block below.
- `GymBro/Views/Home/SessionHistorySection.swift` — collapsed the two
  share buttons ("Post" + deep-link "Share") into one "Share" button that
  opens the builder pre-loaded from `SessionHistory` via a local
  `shareData(from:)` adapter.
- `Info.plist` — `NSPhotoLibraryAddUsageDescription` (for
  `UIImageWriteToSavedPhotosAlbum`) + `LSApplicationQueriesSchemes`
  (`instagram-stories`, `whatsapp`).

### Backend (already shipped via API repo — separate commits)
- `posts.share_config JSONB`, `posts.card_image_url TEXT`
  (migration `20260518180000_add_post_share_config`)
- `post-cards` Storage bucket (public read, authenticated write to own
  folder) — migration `20260518180100_add_post_cards_bucket`
- `CreatePostDto` accepts both new fields; `community.service.ts`
  persists + echoes them in feed/single-post responses.
- `share.controller.ts` `/p/:postId` HTML uses `card_image_url` (falling
  back to `photo_url`) as `og:image` with `width=1080`/`height=1920`/
  `summary_large_image`.
- `user.service.ts` `deleteAccount` cleans `post-cards/{userId}/*`
  best-effort.

### Share rail behavior
- **Community** — `POST /api/v1/community/posts` with `share_config` +
  `card_image_url` populated (rasterized + uploaded first; failure
  non-fatal — post still goes through with `card_image_url = NULL`).
- **Stories** — `instagram-stories://share` + pasteboard payload
  (`com.instagram.sharedSticker.backgroundImage`). Falls back to system
  share sheet if IG isn't installed.
- **WhatsApp** — system share sheet (system surfaces WhatsApp when
  installed; `whatsapp://send` doesn't accept arbitrary images).
- **Save** — `UIImageWriteToSavedPhotosAlbum`.
- **More** — generic `UIActivityViewController`.

---

## Known issues to address when we resume

1. **Photo bg in editor preview** — last fix moves the image into a
   `.background()` modifier so it can't escape the 9:16 frame. Need to
   re-test in the simulator — the previous attempt with
   `frame(maxWidth/maxHeight: .infinity)` on the image as a ZStack sibling
   was insufficient.
2. **Stat chip alignment** — most recent iteration uses
   `WrapHStackLeading` + per-chip `minWidth: 100, alignment: .leading`.
   Confirm columns visually align across rows under partial selection.
3. **Deep-link 404 for `/p/:postId`** — user flagged this as known. The
   iOS app generates `https://gyymjaam.com/p/{id}` (`gyymjaam.com` is the
   Cloudflare worker for the privacy site, which doesn't proxy `/p/*` to
   the Railway API). Fix is on the worker side, not in this branch.
4. **`+ New Post` in feed → Attach workout option** — the user picked
   "Keep generic compose (NewPostView) AND add workout option" but the
   implementation isn't in this branch yet. Plan: add an "Attach workout"
   chip inside `NewPostView` → workout-picker sheet → opens
   `ShareEditorView`.
5. **`ShareSessionView.swift`** is dead code (replaced by
   `ShareEditorView`). Safe to delete on cleanup pass.

---

## Resume checklist

1. `git checkout share-post-builder`
2. Pull latest from main if main has moved (`git rebase main` or
   `git merge main` — there shouldn't be conflicts since the touched
   files are mostly community-share specific).
3. Address open items above in this order:
   1. Verify photo-bg layout in simulator → fix if still wrong.
   2. Verify stat chip alignment → tweak `minWidth` if needed.
   3. Build "Attach workout" path in `NewPostView`.
   4. (Optional) Delete `ShareSessionView.swift`.
4. Clean build (`xcodebuild ... clean build`) — should report `1 error
   total, all in GymJamWatch` (pre-existing WatchKit/iphonesimulator
   scheme issue, unrelated).
5. Push the branch + open PR against `main`.

---

## Why this is on a side branch

The user paused here to switch to a different task. The work is
non-trivial and visually-tied, so rather than carry a 17-file dirty tree
across unrelated work, we parked it on `share-post-builder`. `main` is
clean and the backend changes are independently shippable.
