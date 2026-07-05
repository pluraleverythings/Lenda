import SwiftUI

/// Root timeline. Vertical list of day rows, today at the top on first appearance,
/// free-scrolling in both directions (no snap — expansion is tap-driven, so row
/// heights never change mid-gesture and the scroll feels like any native list).
/// A horizontal month bar at the top tracks/jumps to whichever day is at the top
/// of the viewport. The hour-axis labels live inside the focused row — see DayRowView.
struct CalendarTimelineView: View {
    @EnvironmentObject var store: CalendarStore
    @State private var topDayID: Date?
    @State private var focusedDayID: Date?
    @State private var didAnchorOnToday = false
    @State private var pendingJump: Date?

    private static let scrollSpaceName = "lendaScroll"
    /// Heights the offset → day math assumes. Must match DayRowView's layout:
    /// compact = 84pt content + separator hairline; focused adds 2x content and
    /// the embedded hours bar (header + 4pt top / 2pt bottom padding).
    private static let compactRowHeight = DR.dayRowHeight + DR.hairline
    private static let focusedRowHeight =
        DR.dayRowHeight * 3 + DR.timeHeaderHeight + 6 + DR.hairline

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
                                    isFocused: day.id == focusedDayID,
                                    onToggleFocus: {
                                        withAnimation(.easeOut(duration: 0.2)) {
                                            focusedDayID = focusedDayID == day.id ? nil : day.id
                                        }
                                    }
                                )
                                .id(day.id)
                            }
                        }
                        // One-way scroll tracking: read the offset, derive the top
                        // day ourselves. Nothing writes the scroll position during a
                        // gesture, so nothing can re-anchor it out from under the
                        // user's finger.
                        .background(
                            GeometryReader { gr in
                                Color.clear.preference(
                                    key: ScrollOffsetPreferenceKey.self,
                                    value: -gr.frame(in: .named(Self.scrollSpaceName)).minY
                                )
                            }
                        )
                        .background(alignment: .topLeading) {
                            TimelineGridBackground(layout: layout, leftInset: leftInset)
                        }
                    }
                    .coordinateSpace(name: Self.scrollSpaceName)
                    .onPreferenceChange(ScrollOffsetPreferenceKey.self) { offset in
                        handleScrollOffset(offset)
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
                            // Defer the nil reset so we don't write to pendingJump
                            // inside its own onChange frame.
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

    /// React to scroll movement: derive the top day and prefetch events around it.
    /// The store's `ensureLoaded` never changes `days.count`, so this can't shift
    /// the layout — it only fills events into already-laid-out rows.
    private func handleScrollOffset(_ offset: CGFloat) {
        let newTop = dayID(at: offset)
        guard newTop != topDayID else { return }
        topDayID = newTop
        if let newTop {
            DispatchQueue.main.async { store.ensureLoaded(around: newTop) }
        }
    }

    /// O(1) offset → day mapping. Every row is compact except the (known) focused
    /// one, so the content y-coordinate decomposes into simple arithmetic.
    private func dayID(at offset: CGFloat) -> Date? {
        let days = store.days
        guard !days.isEmpty else { return nil }
        let compact = Self.compactRowHeight
        let safe = max(0, offset)
        if let fid = focusedDayID, let fIdx = store.dayIndex(for: fid) {
            let fStart = CGFloat(fIdx) * compact
            let fEnd = fStart + Self.focusedRowHeight
            if safe < fStart {
                return days[min(Int(safe / compact), days.count - 1)].id
            }
            if safe < fEnd {
                return days[fIdx].id
            }
            let idx = fIdx + 1 + Int((safe - fEnd) / compact)
            return days[min(idx, days.count - 1)].id
        }
        return days[min(Int(safe / compact), days.count - 1)].id
    }
}

private struct ScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
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
