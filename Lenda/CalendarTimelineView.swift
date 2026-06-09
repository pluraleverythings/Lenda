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
                    .scrollTargetBehavior(ThresholdViewSnap(
                        rowHeight: DR.dayRowHeight + DR.hairline,
                        focusedRowOffset: focusedRowOffset(in: store.days),
                        focusedRowHeight: Self.focusedRowTotalHeight
                    ))
                    .contentMargins(.top, 0, for: .scrollContent)
                    .scrollPosition(id: $topDayID, anchor: .top)
                    .onChange(of: topDayID) { _, newTop in
                        if let newTop { store.ensureLoaded(around: newTop) }
                        // Keep the focused row expanded during the scroll itself;
                        // commit the new focus after 1s of stillness so the height
                        // change happens once, not on every gesture.
                        focusWorkItem?.cancel()
                        let item = DispatchWorkItem { focusedDayID = newTop }
                        focusWorkItem = item
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0, execute: item)
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
                            pendingJump = nil
                        }
                    }
                    .onChange(of: store.jumpToTodayTrigger) { _, _ in
                        store.ensureLoaded(around: store.today)
                        pendingJump = store.today
                    }
                }
            }
        }
        .background(DR.surface.ignoresSafeArea())
    }

    /// Total height a focused row occupies in the LazyVStack: the 3x day-row content,
    /// the embedded hours bar (header + its 4pt top / 2pt bottom padding), and the
    /// trailing separator hairline.
    private static let focusedRowTotalHeight: CGFloat =
        DR.dayRowHeight * 3 + DR.timeHeaderHeight + 6 + DR.hairline

    private var currentMonth: Date? {
        let cal = Calendar.current
        let day = topDayID ?? store.today
        return cal.dateInterval(of: .month, for: day)?.start
    }

    private func focusedRowOffset(in days: [DayBucket]) -> CGFloat? {
        guard let id = focusedDayID,
              let idx = days.firstIndex(where: { $0.id == id })
        else { return nil }
        return CGFloat(idx) * (DR.dayRowHeight + DR.hairline)
    }
}

/// Snaps to row boundaries with a 75% threshold. A swipe only advances to the next
/// row once the projected scroll target has crossed `threshold` of the current
/// row's height; smaller flicks rubber-band back to the day still partially at the
/// top. Accounts for the focused row being ~3x taller than the others when present.
private struct ThresholdViewSnap: ScrollTargetBehavior {
    let rowHeight: CGFloat
    let focusedRowOffset: CGFloat?
    let focusedRowHeight: CGFloat
    var threshold: CGFloat = 0.75

    func updateTarget(_ target: inout ScrollTarget, context: ScrollTargetBehaviorContext) {
        let y = target.rect.minY
        guard y > 0 else {
            target.rect.origin.y = 0
            return
        }
        if let focusedOffset = focusedRowOffset {
            let focusedBottom = focusedOffset + focusedRowHeight
            if y >= focusedOffset && y < focusedBottom {
                let progress = (y - focusedOffset) / focusedRowHeight
                target.rect.origin.y = progress >= threshold ? focusedBottom : focusedOffset
                return
            }
            if y >= focusedBottom {
                let yAdj = y - focusedBottom
                let rowFloat = yAdj / rowHeight
                let rowIndex = floor(rowFloat)
                let progress = rowFloat - rowIndex
                let finalIndex = progress >= threshold ? rowIndex + 1 : rowIndex
                target.rect.origin.y = focusedBottom + finalIndex * rowHeight
                return
            }
        }
        let rowFloat = y / rowHeight
        let rowIndex = floor(rowFloat)
        let progress = rowFloat - rowIndex
        let finalIndex = progress >= threshold ? rowIndex + 1 : rowIndex
        target.rect.origin.y = finalIndex * rowHeight
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
