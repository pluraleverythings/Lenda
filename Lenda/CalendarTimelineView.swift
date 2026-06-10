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
    @State private var pendingJump: Date?
    /// Debounce timer for promoting `topDayID` to `focusedDayID` after the scroll
    /// settles. Cancellable so fast scrolls don't pile up pending closures.
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
                    onSelect: { month in
                        store.ensureLoaded(around: month)
                        pendingJump = month
                    }
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
                        .background(alignment: .topLeading) {
                            TimelineGridBackground(layout: layout, leftInset: leftInset)
                        }
                    }
                    .scrollTargetBehavior(.viewAligned)
                    .contentMargins(.top, 0, for: .scrollContent)
                    .scrollPosition(id: $topDayID, anchor: .top)
                    .onChange(of: topDayID) { _, newTop in
                        // Defer the store mutation so its cascade (days change →
                        // layout change → .scrollPosition re-anchor → topDayID
                        // change) doesn't land inside this same onChange's frame.
                        if let newTop {
                            DispatchQueue.main.async {
                                store.ensureLoaded(around: newTop)
                            }
                        }
                        focusWorkItem?.cancel()
                        let item = DispatchWorkItem { focusedDayID = newTop }
                        focusWorkItem = item
                        // 200ms is a compromise: still feels near-immediate when the
                        // wheel lands, but long enough that a brief direction-reverse
                        // doesn't commit a focus mid-flick and shift the layout under
                        // the user's finger.
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2, execute: item)
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
                    .onChange(of: pendingJump) { _, target in
                        if let target {
                            withAnimation(.easeInOut(duration: 0.25)) {
                                scroller.scrollTo(target, anchor: .top)
                            }
                            // Defer the nil reset to the next runloop so we don't
                            // write to pendingJump inside its own onChange — SwiftUI
                            // would otherwise log "tried to update multiple times
                            // per frame".
                            DispatchQueue.main.async { pendingJump = nil }
                        }
                    }
                    .onChange(of: store.jumpToTodayTrigger) { _, _ in
                        DispatchQueue.main.async {
                            store.ensureLoaded(around: store.today)
                            pendingJump = store.today
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
