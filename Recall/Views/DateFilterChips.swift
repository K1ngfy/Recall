import SwiftUI

/// 6.4 date-range filter chips: All / Today / Week / Month
struct DateFilterChips: View {
    @Binding var selection: ListViewModel.DateRange
    @Namespace private var ns

    private let options: [ListViewModel.DateRange] = [.anytime, .today, .week, .month]

    var body: some View {
        HStack(spacing: 3) {
            ForEach(options) { opt in
                chipButton(opt)
            }
        }
        .padding(3)
        .background(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(Color.primary.opacity(0.04))
        )
    }

    @ViewBuilder
    private func chipButton(_ opt: ListViewModel.DateRange) -> some View {
        let isSelected = (opt == selection)
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                selection = opt
            }
        } label: {
            Text(opt.displayName)
                .font(.system(size: 10, weight: isSelected ? .semibold : .medium))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .frame(minHeight: 22)
                .contentShape(Rectangle())
                .foregroundStyle(isSelected ? Color.accentColor : .secondary)
                .background(
                    Group {
                        if isSelected {
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(Color.accentColor.opacity(0.18))
                                .matchedGeometryEffect(id: "dateIndicator", in: ns)
                        }
                    }
                )
        }
        .buttonStyle(.plain)
    }
}
