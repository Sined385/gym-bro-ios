import SwiftUI

struct SetInputRow: View {
    let setNumber: Int
    let previousWeight: Double?
    let previousReps: Int?
    let previousWeightUnit: String
    let previousIsBodyweight: Bool
    @Binding var weight: String
    @Binding var reps: String
    @Binding var isBodyweight: Bool
    let isCompleted: Bool
    var onComplete: () -> Void
    var onTapCompleted: (() -> Void)? = nil

    private let coralAccent = Color(hex: "E86A75")

    var body: some View {
        HStack(spacing: 6) {
            // Set label + prev
            VStack(alignment: .leading, spacing: 2) {
                Text("SET \(setNumber)")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(isCompleted ? coralAccent : .gymBroNeutral400)

                if previousIsBodyweight, let prevReps = previousReps {
                    Text("Prev: BW \u{00D7} \(prevReps)")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.gymBroNeutral400)
                        .lineLimit(1)
                } else if let prevWeight = previousWeight, let prevReps = previousReps {
                    Text("Prev: \(prevWeight.formattedWeight)\(previousWeightUnit) \u{00D7} \(prevReps)")
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

            // Bodyweight toggle (always visible). When ON, the weight TextField
            // below is replaced with a static "BW" pill.
            Button {
                isBodyweight.toggle()
                if isBodyweight { weight = "" }
            } label: {
                Image(systemName: isBodyweight ? "figure.strengthtraining.functional" : "scalemass")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(isBodyweight ? .white : .gymBroNeutral400)
                    .frame(width: 34, height: 36)
                    .background(isBodyweight ? coralAccent : Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(isBodyweight ? coralAccent : Color.gymBroNeutral200, lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
            .disabled(isCompleted)

            if isCompleted {
                // Display-only weight (BW chip for bodyweight sets)
                Text(isBodyweight ? "BW" : (weight.isEmpty ? "--" : weight))
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(isBodyweight ? coralAccent : .gymBroNeutral900)
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
            } else if isBodyweight {
                // Disabled weight slot — shows "BW" instead of an editable field.
                Text("BW")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(coralAccent)
                    .frame(minWidth: 44, maxWidth: 56, minHeight: 36)
                    .background(coralAccent.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(coralAccent.opacity(0.3), lineWidth: 1)
                    )

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
        .contentShape(Rectangle())
        .onTapGesture {
            if isCompleted {
                onTapCompleted?()
            }
        }
    }
}
