import SwiftUI

struct CategoryFilterChips: View {
    let categories: [String]
    @Binding var selectedCategory: String?
    var allowDeselect: Bool = true

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(categories, id: \.self) { category in
                    chipButton(category)
                }
            }
            .padding(.horizontal, 20)
        }
    }

    private func chipButton(_ category: String) -> some View {
        let isSelected = selectedCategory == category

        return Button {
            if isSelected && allowDeselect {
                selectedCategory = nil
            } else {
                selectedCategory = category
            }
        } label: {
            Text(String(localized: String.LocalizationValue(category)))
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(isSelected ? .white : .gymBroNeutral900)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(isSelected ? Color(hex: "2D3240") : Color.clear)
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .stroke(isSelected ? Color.clear : Color.gymBroNeutral200, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
}

// Version for MuscleGroup enum
struct MuscleGroupFilterChips: View {
    @Binding var selectedGroup: MuscleGroup?
    var allowDeselect: Bool = true

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(MuscleGroup.allCases) { group in
                    chipButton(group)
                }
            }
            .padding(.horizontal, 20)
        }
    }

    private func chipButton(_ group: MuscleGroup) -> some View {
        let isSelected = selectedGroup == group

        return Button {
            if isSelected && allowDeselect {
                selectedGroup = nil
            } else {
                selectedGroup = group
            }
        } label: {
            Text(group.displayName)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(isSelected ? .white : .gymBroNeutral900)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(isSelected ? Color(hex: "2D3240") : Color.clear)
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .stroke(isSelected ? Color.clear : Color.gymBroNeutral200, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
}

// Version for EquipmentType enum
struct EquipmentFilterChips: View {
    @Binding var selectedEquipment: EquipmentType?
    var allowDeselect: Bool = true

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(EquipmentType.allCases) { equipment in
                    chipButton(equipment)
                }
            }
            .padding(.horizontal, 20)
        }
    }

    private func chipButton(_ equipment: EquipmentType) -> some View {
        let isSelected = selectedEquipment == equipment

        return Button {
            if isSelected && allowDeselect {
                selectedEquipment = nil
            } else {
                selectedEquipment = equipment
            }
        } label: {
            Text(equipment.displayName)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(isSelected ? .white : .gymBroNeutral900)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(isSelected ? Color(hex: "2D3240") : Color.clear)
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .stroke(isSelected ? Color.clear : Color.gymBroNeutral200, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    VStack(spacing: 20) {
        CategoryFilterChips(
            categories: ["Chest", "Back", "Legs", "Shoulders", "Arms"],
            selectedCategory: .constant("Chest")
        )
        MuscleGroupFilterChips(selectedGroup: .constant(.chest))
    }
}
