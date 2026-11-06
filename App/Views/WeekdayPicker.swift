import SwiftUI

/// Seven toggle buttons, one per weekday, in the order of the user's calendar.
struct WeekdayPicker: View {
    @Binding var selection: Set<Int>

    var body: some View {
        let calendar = Calendar.current
        let symbols = calendar.veryShortStandaloneWeekdaySymbols
        let names = calendar.standaloneWeekdaySymbols
        HStack(spacing: 6) {
            ForEach(WeekdayOrder.ordered(calendar: calendar), id: \.self) { weekday in
                let isSelected = selection.contains(weekday)
                Button {
                    if isSelected {
                        selection.remove(weekday)
                    } else {
                        selection.insert(weekday)
                    }
                } label: {
                    Text(verbatim: symbols[weekday - 1])
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity, minHeight: 34)
                        .background {
                            Circle().fill(isSelected ? Color.accentColor : Color.secondary.opacity(0.15))
                        }
                        .foregroundStyle(isSelected ? Color.white : Color.primary)
                }
                .buttonStyle(.borderless)
                .accessibilityLabel(Text(verbatim: names[weekday - 1]))
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
        .padding(.vertical, 4)
    }
}
