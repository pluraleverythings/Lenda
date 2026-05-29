import SwiftUI

/// Root timeline. Vertical list of day rows, today at the top on first appearance,
/// scrollable in both directions. A horizontal month bar at the top tracks/jumps to
/// whichever day is at the top of the viewport. The hour-axis labels live inside the
/// focused (top) row — see DayRowView.
struct CalendarTimelineView: View {
    @EnvironmentObject var store: CalendarStore
    @State private var topDayID: Date?
    @State private var focusedDayID: Date?
    @State private var didAnchorOnToday = false
    /// Debounce timer for promoting `topDayID` to `focusedDayID` after the scroll
    /// settles. Stored as a cancellable work item so we don't pile up pending
    /// asyncAfter closures during fast scrolling.
    @State private var focusWorkItem: DispatchWorkItem?

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
                    onSelect: jump(to:),
                    onReachStart: { month in store.ensureLoaded(around: extendBy(months: -3, from: month)) },
                    onReachEnd: { month in store.ensureLoaded(around: extendBy(months: 3, from: month)) }
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
                                DayRowView(
                                    day: day,
                                    layout: layout,
                                    isFocused: day.id == focusedDayID
                                )
                                .id(day.id)
                            }
                        }
                        .scrollTargetLayout()
                        // Shading and gridlines live in the LazyVStack background so the
                        // focused row's opaque surface (and the embedded hour bar) cover
                        // them. Below the focused row, they form a continuous grid the
                        // eye can follow top-to-bottom.
                        .background(alignment: .topLeading) {
                            TimelineGridBackground(layout: layout, leftInset: leftInset)
                        }
                    }
                    .scrollTargetBehavior(.viewAligned(limitBehavior: .always))
                    .contentMargins(.top, 0, for: .scrollContent)
                    .scrollPosition(id: $topDayID, anchor: .top)
                    .onChange(of: topDayID) { _, newTop in
                        if let newTop { store.ensureLoaded(around: newTop) }
                        // Debounce the focus expansion: only after the user stops
                        // scrolling for 250ms do we animate the new top day into the
                        // expanded card view. During the scroll itself every row stays
                        // compact, which keeps the LazyVStack geometry stable so snap
                        // aligns cleanly to row boundaries.
                        focusWorkItem?.cancel()
                        let item = DispatchWorkItem { focusedDayID = newTop }
                        focusWorkItem = item
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25, execute: item)
                    }
                    .onAppear {
                        if !didAnchorOnToday {
                            didAnchorOnToday = true
                            DispatchQueue.main.async {
                                scroller.scrollTo(store.today, anchor: .top)
                                topDayID = store.today
                                focusedDayID = store.today
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

    private func extendBy(months: Int, from date: Date) -> Date {
        Calendar.current.date(byAdding: .month, value: months, to: date) ?? date
    }
}

/// The shared timeline grid (empty-hour shading + hour gridlines) drawn once behind
/// the LazyVStack. Extracted into its own Equatable view so SwiftUI can skip
/// re-evaluating these dozens of Rectangles every time `topDayID` changes during a
/// scroll — the inputs (layout, leftInset) stay the same.
private struct TimelineGridBackground: View, Equatable {
    let layout: AxisLayout
    let leftInset: CGFloat

    var body: some View {
        ZStack(alignment: .topLeading) {
            ForEach(layout.emptyHourTicks) { tick in
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
