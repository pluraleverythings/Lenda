import SwiftUI

/// Root timeline. Vertical list of day rows, today at the top on first appearance,
/// scrollable in both directions. A horizontal month bar at the top tracks/jumps to
/// whichever day is at the top of the viewport.
struct CalendarTimelineView: View {
    @EnvironmentObject var store: CalendarStore
    @State private var topDayID: Date?
    @State private var didAnchorOnToday = false

    var body: some View {
        switch store.access {
        case .unknown:
            ProgressView()
                .controlSize(.large)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .denied:
            PermissionView()
        case .granted:
            content
        }
    }

    @ViewBuilder
    private var content: some View {
        GeometryReader { proxy in
            let trackWidth = max(1, proxy.size.width - DR.dayLabelWidth - DR.horizontalPadding * 2 - 8)
            let layout = AxisLayout(axis: store.timeAxis, width: trackWidth)

            VStack(spacing: 0) {
                MonthBar(
                    months: store.monthsInRange,
                    currentMonth: currentMonth,
                    onSelect: jump(to:)
                )
                .frame(height: DR.monthBarHeight)

                Rectangle()
                    .fill(DR.rule)
                    .frame(height: DR.hairline)

                HStack(alignment: .top, spacing: 8) {
                    Spacer().frame(width: DR.dayLabelWidth)
                    TimeAxisHeader(layout: layout)
                        .frame(height: DR.timeHeaderHeight)
                }
                .padding(.horizontal, DR.horizontalPadding)
                .padding(.top, 4)
                .padding(.bottom, 2)

                Rectangle()
                    .fill(DR.rule)
                    .frame(height: DR.hairline)

                ScrollViewReader { scroller in
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(store.days) { day in
                                DayRowView(day: day, layout: layout)
                                    .id(day.id)
                                    .onAppear { store.ensureLoaded(around: day.date) }
                                Rectangle()
                                    .fill(DR.rule)
                                    .frame(height: DR.hairline)
                            }
                        }
                        .scrollTargetLayout()
                    }
                    .scrollPosition(id: $topDayID, anchor: .top)
                    .onAppear {
                        if !didAnchorOnToday {
                            didAnchorOnToday = true
                            DispatchQueue.main.async {
                                scroller.scrollTo(store.today, anchor: .top)
                                topDayID = store.today
                            }
                        }
                    }
                }
            }
        }
        .background(DR.surface.ignoresSafeArea())
    }

    private var currentMonth: Date? {
        let cal = Calendar.current
        let day = topDayID ?? store.today
        return cal.dateInterval(of: .month, for: day)?.start
    }

    private func jump(to month: Date) {
        store.ensureLoaded(around: month)
        topDayID = month
    }
}
