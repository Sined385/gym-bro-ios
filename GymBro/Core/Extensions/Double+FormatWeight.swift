import Foundation

extension Double {
    /// Formats weight: "72" for whole numbers, "72.5" for decimals
    var formattedWeight: String {
        truncatingRemainder(dividingBy: 1) == 0 ? "\(Int(self))" : String(format: "%.1f", self)
    }
}
