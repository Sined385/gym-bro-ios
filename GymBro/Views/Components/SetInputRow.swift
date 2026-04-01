import SwiftUI

struct SetInputRow: View {
    let setNumber: Int
    let previousWeight: Double?
    let previousReps: Int?
    let previousWeightUnit: String
    @Binding var weight: String
    @Binding var reps: String
    let isCompleted: Bool
    var onComplete: () -> Void

    private let coralAccent = Color(hex: "E86A75")

    var body: some View {
        HStack(spacing: 6) {
            // Set label + prev
            VStack(alignment: .leading, spacing: 2) {
                Text("SET \(setNumber)")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(isCompleted ? coralAccent : .gymBroNeutral400)

                if let prevWeight = previousWeight, let prevReps = previousReps {
                    Text("Prev: \(prevWeight.truncatingRemainder(dividingBy: 1) == 0 ? "\(Int(prevWeight))" : String(format: "%.1f", prevWeight))\(previousWeightUnit) \u{00D7} \(prevReps)")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.gymBroNeutral400)
                        .lineLimit(1)
                } else {
                    Text("Prev: --")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.gymBroNeutral400)
                }
            }

            Spacer(minLength: 4)

            if isCompleted {
                // Display-only weight
                Text(weight.isEmpty ? "--" : weight)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.gymBroNeutral900)
                    .frame(minWidth: 44, maxWidth: 56, minHeight: 36)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(Color.gymBroNeutral200, lineWidth: 1)
                    )

                // Display-only reps
                Text(reps.isEmpty ? "--" : reps)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.gymBroNeutral900)
                    .frame(minWidth: 44, maxWidth: 56, minHeight: 36)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(Color.gymBroNeutral200, lineWidth: 1)
                    )
            } else {
                // Editable weight field
                ZStack(alignment: .trailing) {
                    TextField("", text: $weight)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.gymBroNeutral900)
                        .multilineTextAlignment(.center)
                        .keyboardType(.decimalPad)
                        .frame(minWidth: 44, maxWidth: 56, minHeight: 36)
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(Color.gymBroNeutral200, lineWidth: 1)
                        )

                    if weight.isEmpty {
                        Text("kg")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.gymBroNeutral400)
                            .padding(.trailing, 8)
                            .allowsHitTesting(false)
                    }
                }

                // Editable reps field
                TextField("", text: $reps)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.gymBroNeutral900)
                    .multilineTextAlignment(.center)
                    .keyboardType(.numberPad)
                    .frame(minWidth: 44, maxWidth: 56, minHeight: 36)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(Color.gymBroNeutral200, lineWidth: 1)
                    )
            }

            // Checkmark button
            Button(action: onComplete) {
                ZStack {
                    if isCompleted {
                        RoundedRectangle(cornerRadius: 14)
                            .fill(coralAccent)
                            .frame(width: 34, height: 34)
                            .shadow(color: coralAccent.opacity(0.3), radius: 3, y: 2)
                    } else {
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(Color.gymBroNeutral200, lineWidth: 1)
                            .frame(width: 34, height: 34)
                    }
                    Image(systemName: "checkmark")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(isCompleted ? .white : .gymBroNeutral200)
                }
            }
            .buttonStyle(.plain)
            .disabled(isCompleted)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 8)
        .background(
            isCompleted
                ? coralAccent.opacity(0.05)
                : Color(hex: "FAFAFA")
        )
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(
                    isCompleted ? coralAccent.opacity(0.2) : Color.gymBroNeutral100,
                    lineWidth: 1
                )
        )
    }
}
