import SwiftUI

/// Root timeline. Vertical list of day rows, today at the top on first appearance,
/// scrollable in both directions. A horizontal month bar at the top tracks/jumps to
/// whichever day is at the top of the viewport. The hour-axis labels live inside the
/// focused (top) row — see DayRowView.
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

                ScrollViewReader { scroller in
                    let leftInset = DR.horizontalPadding + DR.dayLabelWidth + 8
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(store.days) { day in
                                VStack(spacing: 0) {
                                    DayRowView(
                                        day: day,
                                        layout: layout,
                                        isFocused: day.id == topDayID
                                    )
                                    Rectangle()
                                        .fill(DR.rule)
                                        .frame(height: DR.hairline)
                                }
                                .id(day.id)
                            }
                        }
                        .scrollTargetLayout()
                        // Shading and gridlines live in the LazyVStack background so the
                        // focused row's opaque surface (and the embedded hour bar) cover
                        // them. Below the focused row, they form a continuous grid the
                        // eye can follow top-to-bottom.
                        .background(alignment: .topLeading) {
                            ZStack(alignment: .topLeading) {
                                ForEach(layout.hourTicks.filter { $0.isEmpty && $0.width > 0 }) { tick in
                                    Rectangle()
                                        .fill(DR.surfaceCompressed)
                                        .frame(width: tick.width)
                                        .offset(x: leftInset + tick.x)
                                }
                                ForEach(layout.hourTicks) { tick in
                                    Rectangle()
                                        .fill(DR.rule)
                                        .frame(width: DR.hairline)
                                        .offset(x: leftInset + tick.x)
                                }
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                            .allowsHitTesting(false)
                        }
                    }
                    .scrollTargetBehavior(.viewAligned)
                    .scrollPosition(id: $topDayID, anchor: .top)
                    .onChange(of: topDayID) { _, newTop in
                        if let newTop { store.ensureLoaded(around: newTop) }
                    }
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
