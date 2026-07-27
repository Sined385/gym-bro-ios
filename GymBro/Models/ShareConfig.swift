//
//  ShareConfig.swift
//  GymBro
//
//  v1 share generator: a single struct describes everything the share card
//  needs to render. The editor mutates it; the rasterizer + carousel slides
//  both read from it. See Views/Community/ShareCard/* for consumers.
//

import SwiftUI

// MARK: - Stat keys

enum StatKey: String, CaseIterable, Identifiable, Codable {
    case time, volume, sets, calories, avgHR

    var id: String { rawValue }

    /// Pill label / card label (already title-cased).
    var label: String {
        switch self {
        case .time:     return String(localized: "Time")
        case .volume:   return String(localized: "Volume")
        case .sets:     return String(localized: "Sets")
        case .calories: return String(localized: "Calories")
        case .avgHR:    return String(localized: "Avg HR")
        }
    }

    var shortLabel: String {
        switch self {
        case .time:     return String(localized: "TIME")
        case .volume:   return String(localized: "VOLUME")
        case .sets:     return String(localized: "SETS")
        case .calories: return String(localized: "CALORIES")
        case .avgHR:    return String(localized: "AVG HR")
        }
    }
}

// MARK: - Background presets

enum ShareBackgroundPreset: String, CaseIterable, Identifiable, Codable {
    case paper             // neutral card-on-canvas — the default
    case purpleSolid
    case inkCoral
    case ink
    case coralGradient
    case amberCoral
    case greenGradient

    var id: String { rawValue }

    /// LinearGradient used as the card's base fill.
    var gradient: LinearGradient {
        switch self {
        case .paper:
            return LinearGradient(
                colors: [Color(hex: "7A82F6").opacity(0.06), Color(hex: "FCFCFA")],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
        case .purpleSolid:
            return LinearGradient(
                colors: [Color(hex: "7A82F6"), Color(hex: "5A63D8")],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
        case .inkCoral:
            return LinearGradient(
                colors: [Color(hex: "1a1d28"), Color(hex: "2D3240"), Color(hex: "E86A75")],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
        case .ink:
            return LinearGradient(colors: [Color(hex: "2D3240")], startPoint: .top, endPoint: .bottom)
        case .coralGradient:
            return LinearGradient(
                colors: [Color(hex: "E86A75"), Color(hex: "D65D68")],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
        case .amberCoral:
            return LinearGradient(
                colors: [Color(hex: "F5B565"), Color(hex: "E86A75")],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
        case .greenGradient:
            return LinearGradient(
                colors: [Color(hex: "30C08D"), Color(hex: "1e8160")],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
        }
    }

    /// Whether the gradient is dark enough that on-card text should flip to white.
    var prefersDarkContent: Bool {
        switch self {
        case .paper: return true   // text stays ink-dark
        default:     return false  // text goes white on colored backgrounds
        }
    }
}

enum ShareBackground: Equatable, Codable {
    case preset(ShareBackgroundPreset)
    /// Public URL of an uploaded image. The card composes the photo at the
    /// back with the same content layer on top; palette flips to white text
    /// so titles read against any image.
    case photo(url: String)

    var gradient: LinearGradient {
        switch self {
        case .preset(let p): return p.gradient
        case .photo:
            // Photo-backed cards render the image separately; a dark scrim
            // gradient ensures content legibility regardless of image content.
            return LinearGradient(
                colors: [Color.black.opacity(0.45), Color.black.opacity(0.15), Color.black.opacity(0.55)],
                startPoint: .top, endPoint: .bottom
            )
        }
    }

    var photoURL: URL? {
        if case .photo(let url) = self { return URL(string: url) }
        return nil
    }

    var prefersDarkContent: Bool {
        switch self {
        case .preset(let p): return p.prefersDarkContent
        case .photo:         return false   // always white text on photos
        }
    }

    // Wire format:
    //   { "kind": "preset", "preset": "paper" }
    //   { "kind": "photo", "url": "https://..." }
    // Tolerant decoder so a future ".custom(hex:)" added on a newer client
    // round-trips back as the default preset on older clients without crashing.
    private enum CodingKeys: String, CodingKey { case kind, preset, url }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let kind = try c.decodeIfPresent(String.self, forKey: .kind) ?? "preset"
        switch kind {
        case "preset":
            let raw = try c.decodeIfPresent(String.self, forKey: .preset) ?? "paper"
            self = .preset(ShareBackgroundPreset(rawValue: raw) ?? .paper)
        case "photo":
            let url = try c.decodeIfPresent(String.self, forKey: .url) ?? ""
            self = .photo(url: url)
        default:
            self = .preset(.paper)
        }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .preset(let p):
            try c.encode("preset", forKey: .kind)
            try c.encode(p.rawValue, forKey: .preset)
        case .photo(let url):
            try c.encode("photo", forKey: .kind)
            try c.encode(url, forKey: .url)
        }
    }
}

// MARK: - ShareConfig

struct ShareConfig: Equatable, Codable {
    var background: ShareBackground
    var selectedStatKeys: Set<StatKey>
    var selectedExerciseIds: Set<String>
    var title: String
    var category: String?

    static func defaultConfig(for workout: WorkoutSnapshot) -> ShareConfig {
        ShareConfig(
            background: .preset(.paper),
            // Always-on baseline: Time, Volume, Sets.
            selectedStatKeys: [.time, .volume, .sets],
            selectedExerciseIds: Set(workout.exercises.map(\.id)),
            title: workout.title,
            category: workout.category
        )
    }

    private enum CodingKeys: String, CodingKey {
        case background
        case selectedStatKeys
        case selectedExerciseIds
        case title
        case category
    }

    init(
        background: ShareBackground,
        selectedStatKeys: Set<StatKey>,
        selectedExerciseIds: Set<String>,
        title: String,
        category: String?
    ) {
        self.background = background
        self.selectedStatKeys = selectedStatKeys
        self.selectedExerciseIds = selectedExerciseIds
        self.title = title
        self.category = category
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        // Tolerant decoder: missing fields fall back to safe defaults so
        // payloads from a newer client (with extra keys) or an older client
        // (missing keys) both round-trip.
        self.background = (try? c.decode(ShareBackground.self, forKey: .background)) ?? .preset(.paper)
        self.selectedStatKeys = (try? c.decode(Set<StatKey>.self, forKey: .selectedStatKeys)) ?? [.time, .volume, .sets]
        self.selectedExerciseIds = (try? c.decode(Set<String>.self, forKey: .selectedExerciseIds)) ?? []
        self.title = (try? c.decode(String.self, forKey: .title)) ?? ""
        self.category = try? c.decodeIfPresent(String.self, forKey: .category)
    }

    /// JSON dict for `CommunityRouter.createPost` body. Round-trips via the
    /// `Codable` impl so the wire shape always matches `init(from:)`.
    func toDictionary() -> [String: Any] {
        guard let data = try? JSONEncoder().encode(self),
              let obj = try? JSONSerialization.jsonObject(with: data),
              let dict = obj as? [String: Any]
        else { return [:] }
        return dict
    }
}

// MARK: - WorkoutSnapshot

/// Read-only view of a completed workout, used by every share-card surface.
/// Both `CompletedWorkoutShareData` (post-completion editor input) and
/// `WorkoutAttachment` (feed post payload) adapt into this shape so the card
/// renders identically in either context.
struct WorkoutSnapshot: Equatable {
    let sessionId: String
    let title: String
    let category: String?
    let durationMinutes: Int?
    let totalVolumeKg: Double
    let totalSets: Int
    let calories: Int?
    let avgHeartRate: Int?
    let exercises: [WorkoutSnapshotExercise]
    let authorHandle: String?

    /// "18.4k", "240", "0".
    var formattedVolume: String {
        let kg = totalVolumeKg
        if kg >= 1000 {
            let k = kg / 1000
            return k.truncatingRemainder(dividingBy: 1) == 0 ? "\(Int(k))k" : String(format: "%.1fk", k)
        }
        return "\(Int(kg))"
    }

    /// "52:18" from durationMinutes.
    var formattedDuration: String {
        guard let m = durationMinutes else { return "—" }
        let h = m / 60
        let mm = m % 60
        if h > 0 { return String(format: "%d:%02d", h, mm) }
        return String(format: "0:%02d", mm)
    }

    func value(for stat: StatKey) -> String {
        switch stat {
        case .time:     return formattedDuration
        case .volume:   return formattedVolume
        case .sets:     return "\(totalSets)"
        case .calories: return calories.map { "\($0)" } ?? "—"
        case .avgHR:    return avgHeartRate.map { "\($0)" } ?? "—"
        }
    }
}

struct WorkoutSnapshotExercise: Equatable, Identifiable {
    let id: String
    let name: String
    /// For display-time name localization; id/name stay canonical
    /// English (id round-trips through share_config).
    var externalId: String? = nil
    let muscleGroup: String?
    let accentColorHex: String
    /// Compact display chips for the card — e.g. ["60", "70", "80", "85"].
    /// Empty for cardio (no weight chips).
    let setChips: [String]
    /// Full "best set" line used in carousel slide 3 — e.g. "85kg × 6",
    /// or for cardio the duration + distance, e.g. "20:00 · 2.5 km".
    let bestSetLine: String
    /// Cardio is duration-based — views render `bestSetLine` (time +
    /// distance) and skip the "N sets × reps" weight presentation.
    var isCardio: Bool = false
}

extension WorkoutSnapshotExercise {
    /// "20:00 · 2.5 km" / "20:00" (no distance). Time-only when distance
    /// wasn't logged.
    static func cardioLine(seconds: Int, meters: Int) -> String {
        let s = max(0, seconds)
        let h = s / 3600, m = (s % 3600) / 60, sec = s % 60
        let time = h > 0
            ? String(format: "%d:%02d:%02d", h, m, sec)
            : String(format: "%d:%02d", m, sec)
        guard meters > 0 else { return time }
        let km = Double(meters) / 1000.0
        let dist = String(format: km >= 10 ? "%.1f km" : "%.2f km", km)
        return "\(time) · \(dist)"
    }
}

// MARK: - Adapters

extension WorkoutSnapshot {
    /// From a just-completed workout (the editor's input).
    static func from(_ data: CompletedWorkoutShareData, authorHandle: String? = nil) -> WorkoutSnapshot {
        let allSets = data.exercises.flatMap { ex in
            ex.sets.filter(\.isCompleted)
        }
        let volume = allSets.reduce(0.0) { acc, s in
            acc + (s.isBodyweight ? 0 : (s.weight ?? 0)) * Double(s.reps ?? 0)
        }
        return WorkoutSnapshot(
            sessionId: data.sessionId,
            title: data.sessionTitle,
            category: nil,
            durationMinutes: data.durationMinutes,
            totalVolumeKg: volume,
            totalSets: allSets.count,
            calories: data.calories,
            avgHeartRate: data.avgHeartRate,
            exercises: data.exercises.map { WorkoutSnapshotExercise.from($0) },
            authorHandle: authorHandle
        )
    }

    /// From a feed post's workout attachment (read-only).
    static func from(_ attachment: WorkoutAttachment, authorHandle: String? = nil) -> WorkoutSnapshot {
        let exList = attachment.exercises ?? []
        let totalSets = exList.reduce(0) { $0 + $1.totalSets }
        let volume = exList.reduce(0.0) { acc, ex in
            let exVol = (ex.sets ?? []).reduce(0.0) { setAcc, s in
                setAcc + (s.isBodyweight ? 0 : (s.weight ?? 0)) * Double(s.reps)
            }
            return acc + exVol
        }
        return WorkoutSnapshot(
            sessionId: attachment.sessionId,
            title: attachment.title,
            category: nil,
            durationMinutes: attachment.durationMinutes,
            totalVolumeKg: volume,
            totalSets: totalSets,
            calories: attachment.calories,
            avgHeartRate: attachment.avgHeartRate,
            exercises: exList.map { WorkoutSnapshotExercise.from($0) },
            authorHandle: authorHandle
        )
    }
}

extension WorkoutSnapshotExercise {
    static func from(_ ex: ActiveSessionExercise) -> WorkoutSnapshotExercise {
        let completed = ex.sets.filter(\.isCompleted)

        // Cardio is duration-based — show time + distance, not "1 set × 0".
        let isCardio = ex.muscleGroup.caseInsensitiveCompare("Cardio") == .orderedSame
            || completed.contains { $0.durationSeconds != nil }
        if isCardio {
            let secs = completed.reduce(0) { $0 + ($1.durationSeconds ?? 0) }
            let meters = completed.reduce(0) { $0 + ($1.distanceMeters ?? 0) }
            return WorkoutSnapshotExercise(
                id: ex.name,
                name: ex.name,
                externalId: ex.externalId,
                muscleGroup: ex.muscleGroup,
                accentColorHex: ex.accentColor,
                setChips: [],
                bestSetLine: cardioLine(seconds: secs, meters: meters),
                isCardio: true
            )
        }

        // Best set = heaviest weight (reps as tiebreaker). For bodyweight,
        // most reps wins. The previous "weight × reps" picked highest
        // volume, which surfaced warmups like 50kg × 10 (500 vol) over a
        // 85kg × 5 working set (425 vol) — not what lifters mean by
        // "best set."
        let best = completed.max(by: { lhs, rhs in
            let lw = lhs.isBodyweight ? 0 : (lhs.weight ?? 0)
            let rw = rhs.isBodyweight ? 0 : (rhs.weight ?? 0)
            if lw != rw { return lw < rw }
            return (lhs.reps ?? 0) < (rhs.reps ?? 0)
        })
        let bestLine = best.map {
            SetDisplay.line(weight: $0.weight, weightUnit: $0.weightUnit, reps: $0.reps, isBodyweight: $0.isBodyweight)
        } ?? "—"
        let chips = completed.map { s -> String in
            if s.isBodyweight { return "BW" }
            return s.weight.map { $0.formattedWeight } ?? "—"
        }
        return WorkoutSnapshotExercise(
            // Use the exercise name as the snapshot identifier so the editor's
            // `selectedExerciseIds` (which gets serialized into share_config)
            // round-trips through the feed renderer, where the backend's
            // AttachmentExercise.id is also derived from `name`. Local
            // ActiveSessionExercise.id is a per-device UUID and would never
            // match what the feed sees.
            id: ex.name,
            name: ex.name,
                externalId: ex.externalId,
            muscleGroup: ex.muscleGroup,
            accentColorHex: ex.accentColor,
            setChips: chips,
            bestSetLine: bestLine
        )
    }

    static func from(_ ex: AttachmentExercise) -> WorkoutSnapshotExercise {
        let sets = ex.sets ?? []

        // Cardio is duration-based — show time + distance. Prefer the
        // logged per-set duration/distance; fall back to the AI's
        // sets_display ("20 min") when the attachment predates those
        // fields, never "× 0".
        let isCardio = (ex.muscleGroup?.caseInsensitiveCompare("Cardio") == .orderedSame)
            || sets.contains { $0.durationSeconds != nil }
        if isCardio {
            let secs = sets.reduce(0) { $0 + ($1.durationSeconds ?? 0) }
            let meters = sets.reduce(0) { $0 + ($1.distanceMeters ?? 0) }
            let line = secs > 0 ? cardioLine(seconds: secs, meters: meters) : (ex.setsDisplay ?? "—")
            return WorkoutSnapshotExercise(
                id: ex.name,
                name: ex.name,
                externalId: ex.externalId,
                muscleGroup: ex.muscleGroup,
                accentColorHex: ex.accentColor ?? "#E86A75",
                setChips: [],
                bestSetLine: line,
                isCardio: true
            )
        }

        // Best = heaviest weight (reps as tiebreaker). See the comment on
        // the ActiveSessionExercise overload for why volume-based picks
        // mis-rank warmups as "best."
        let best = sets.max(by: { lhs, rhs in
            let lw = lhs.isBodyweight ? 0 : (lhs.weight ?? 0)
            let rw = rhs.isBodyweight ? 0 : (rhs.weight ?? 0)
            if lw != rw { return lw < rw }
            return lhs.reps < rhs.reps
        })
        let bestLine = best.map {
            SetDisplay.line(weight: $0.weight, weightUnit: $0.weightUnit, reps: $0.reps, isBodyweight: $0.isBodyweight)
        } ?? (ex.setsDisplay ?? "—")
        let chips = sets.map { s -> String in
            if s.isBodyweight { return "BW" }
            return s.weight.map { $0.formattedWeight } ?? "\(s.reps)"
        }
        return WorkoutSnapshotExercise(
            id: ex.name,
            name: ex.name,
                externalId: ex.externalId,
            muscleGroup: ex.muscleGroup,
            accentColorHex: ex.accentColor ?? "#E86A75",
            setChips: chips,
            bestSetLine: bestLine
        )
    }
}
