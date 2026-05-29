import SwiftUI

/// Horizontal strip of month labels. Tap a month → jump there. The currently-visible
/// month auto-scrolls into view as the user scrolls the timeline.
struct MonthBar: View {
    let months: [Date]
    let currentMonth: Date?
    let onSelect: (Date) -> Void
    var onReachStart: ((Date) -> Void)? = nil
    var onReachEnd: ((Date) -> Void)? = nil

    @State private var seenMonths: Set<Date> = []

    private static let monthFmt: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMM"
        return f
    }()
    private static let monthYearFmt: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMM yy"
        return f
    }()

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 20) {
                    ForEach(months, id: \.self) { month in
                        let active = isCurrent(month)
                        Button {
                            onSelect(month)
                        } label: {
                            Text(label(for: month))
                                .font(active ? DR.TypeStyle.monthActive : DR.TypeStyle.monthInactive)
                                .foregroundStyle(active ? DR.ink : DR.inkSecondary)
                                .padding(.vertical, 10)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .id(month)
                        .onAppear { handleAppear(month) }
                    }
                }
                .padding(.horizontal, DR.horizontalPadding)
            }
            .onChange(of: currentMonth) { _, newValue in
                guard let m = newValue else { return }
                withAnimation(.easeInOut(duration: 0.25)) {
                    proxy.scrollTo(m, anchor: .center)
                }
            }
            .onAppear {
                guard let m = currentMonth else { return }
                proxy.scrollTo(m, anchor: .center)
            }
        }
    }

    /// Fire the edge callbacks when the first/last month of the loaded range scrolls
    /// back into view, but never on its very first appearance — otherwise the initial
    /// render would expand the range before the user has scrolled at all.
    private func handleAppear(_ month: Date) {
        guard seenMonths.contains(month) else {
            seenMonths.insert(month)
            return
        }
        if month == months.first { onReachStart?(month) }
        if month == months.last { onReachEnd?(month) }
    }

    private func isCurrent(_ month: Date) -> Bool {
        guard let current = currentMonth else { return false }
        return Calendar.current.isDate(month, equalTo: current, toGranularity: .month)
    }

    private func label(for month: Date) -> String {
        let cal = Calendar.current
        let monthNum = cal.component(.month, from: month)
        let isJanuary = monthNum == 1
        let isFirst = months.first.map { cal.isDate($0, equalTo: month, toGranularity: .month) } ?? false
        let fmt = (isJanuary || isFirst) ? Self.monthYearFmt : Self.monthFmt
        return fmt.string(from: month).uppercased()
    }
}
