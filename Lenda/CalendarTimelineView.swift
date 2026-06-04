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
    /// Short debounce timer for committing `focusedDayID` after scroll settles.
    /// Cancellable so fast scrolls don't pile up pending closures.
    @State private var focusWorkItem: DispatchWorkItem?

    private static let scrollSpaceName = "lendaScroll"

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
                    },
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
                        // One-way scroll-offset tracker. A GeometryReader in the
                        // background reports the LazyVStack's frame in the scroll
                        // coordinate space; we derive topDayID from the offset and
                        // known row heights ourselves. Replaces .scrollPosition,
                        // which had a two-way binding that kept re-anchoring the
                        // scroll whenever the focused row's height changed.
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
                    .scrollTargetBehavior(ThresholdViewSnap(
                        rowHeight: DR.dayRowHeight + DR.hairline,
                        focusedRowOffset: focusedRowOffset(in: store.days),
                        focusedRowHeight: Self.focusedRowTotalHeight
                    ))
                    .contentMargins(.top, 0, for: .scrollContent)
                    .onPreferenceChange(ScrollOffsetPreferenceKey.self) { offset in
                        handleScrollOffset(offset, scroller: scroller)
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
                }
            }
        }
        .background(DR.surface.ignoresSafeArea())
    }

    /// Total height a focused row occupies in the LazyVStack: the 3x day-row content,
    /// the embedded hours bar (header + its 4pt top / 2pt bottom padding), and the
    /// trailing separator hairline. Must match what DayRowView actually lays out so
    /// the offset → day math stays accurate.
    private static let focusedRowTotalHeight: CGFloat =
        DR.dayRowHeight * 3 + DR.timeHeaderHeight + 6 + DR.hairline

    private var currentMonth: Date? {
        let cal = Calendar.current
        let day = topDayID ?? store.today
        return cal.dateInterval(of: .month, for: day)?.start
    }

    private func extendBy(months: Int, from date: Date) -> Date {
        Calendar.current.date(byAdding: .month, value: months, to: date) ?? date
    }

    /// y-offset of the currently focused row inside the LazyVStack, assuming every
    /// other row is at its compact height. Used by the snap behavior and the
    /// offset → day computation below.
    private func focusedRowOffset(in days: [DayBucket]) -> CGFloat? {
        guard let id = focusedDayID,
              let idx = days.firstIndex(where: { $0.id == id })
        else { return nil }
        return CGFloat(idx) * (DR.dayRowHeight + DR.hairline)
    }

    /// Compute which day is currently at the viewport top from the LazyVStack's
    /// scroll offset. O(1): we know the layout exactly — every row is compact
    /// (84.5pt) except the focused one, which is `focusedRowTotalHeight`.
    private func computeTopDayID(at offset: CGFloat) -> Date? {
        let days = store.days
        guard !days.isEmpty else { return nil }
        let rowHeight = DR.dayRowHeight + DR.hairline
        let focusedHeight = Self.focusedRowTotalHeight
        let focusedIdx = focusedDayID.flatMap { id in days.firstIndex(where: { $0.id == id }) }
        let safe = max(0, offset)
        if let focusedIdx {
            let focusedStart = CGFloat(focusedIdx) * rowHeight
            let focusedEnd = focusedStart + focusedHeight
            if safe < focusedStart {
                let idx = min(Int(safe / rowHeight), days.count - 1)
                return days[max(0, idx)].id
            } else if safe < focusedEnd {
                return days[focusedIdx].id
            } else {
                let yAdj = safe - focusedEnd
                let idx = focusedIdx + 1 + Int(yAdj / rowHeight)
                return days[min(idx, days.count - 1)].id
            }
        } else {
            let idx = min(Int(safe / rowHeight), days.count - 1)
            return days[max(0, idx)].id
        }
    }

    /// Called every frame the scroll offset changes. We only react when the top day
    /// actually changes; a 150ms debounce then commits the focused-row expansion
    /// (and re-aligns the viewport to keep the new focused day's top at the viewport
    /// top, since the height swap shifts content positions).
    private func handleScrollOffset(_ offset: CGFloat, scroller: ScrollViewProxy) {
        let newTop = computeTopDayID(at: offset)
        guard newTop != topDayID else { return }
        topDayID = newTop
        if let newTop { store.ensureLoaded(around: newTop) }
        focusWorkItem?.cancel()
        let item = DispatchWorkItem {
            guard let target = topDayID, target != focusedDayID else { return }
            withAnimation(.easeOut(duration: 0.2)) {
                focusedDayID = target
                scroller.scrollTo(target, anchor: .top)
            }
        }
        focusWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15, execute: item)
    }
}

private struct ScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
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
        // Before the focused row (or no row is focused): uniform compact heights.
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
