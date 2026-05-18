import Foundation

extension Double {
    /// Formats weight: "72" for whole numbers, "72.5" for decimals
    var formattedWeight: String {
        truncatingRemainder(dividingBy: 1) == 0 ? "\(Int(self))" : String(format: "%.1f", self)
    }
}

/// Central formatters for rendering a logged set across the app. Bodyweight
/// sets render as "Bodyweight" / "BW" with no weight or unit; everything else
/// renders as "60kg × 8" / "60kg" using `formattedWeight`. Centralizing this
/// keeps the bodyweight rule in one place — any future tweak to spacing,
/// punctuation, or the "Bodyweight" wording is a single edit.
enum SetDisplay {
    /// Full "weight × reps" line. Returns:
    /// - "Bodyweight × 8" when `isBodyweight`
    /// - "60kg × 8" when both weight and reps are present
    /// - "— × 8" when reps known but weight missing
    /// - "60kg" / "8 reps" / "—" when one half is missing
    static func line(
        weight: Double?,
        weightUnit: String?,
        reps: Int?,
        isBodyweight: Bool
    ) -> String {
        let weightPart = weightChunk(weight: weight, weightUnit: weightUnit, isBodyweight: isBodyweight)
        if let reps {
            return "\(weightPart) \u{00D7} \(reps)"
        }
        return weightPart
    }

    /// Just the leading weight chunk: "60kg", "Bodyweight", or "—".
    static func weightChunk(
        weight: Double?,
        weightUnit: String?,
        isBodyweight: Bool
    ) -> String {
        if isBodyweight { return "Bodyweight" }
        guard let weight, weight > 0 else { return "\u{2014}" }
        let unit = weightUnit ?? "kg"
        return "\(weight.formattedWeight)\(unit)"
    }

    /// Compact "weight" chunk for tight UIs (set input chips). "BW" instead of "Bodyweight".
    static func compactWeightChunk(
        weight: Double?,
        weightUnit: String?,
        isBodyweight: Bool
    ) -> String {
        if isBodyweight { return "BW" }
        guard let weight, weight > 0 else { return "\u{2014}" }
        return weight.formattedWeight
    }
}
