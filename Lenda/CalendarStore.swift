import Foundation
import SwiftUI

/// View-facing calendar state. Talks to any `CalendarSource`.
///
/// Layout stability contract: `days` is built ONCE per grant as a fixed-length window
/// around today and never changes length afterwards. Scrolling loads *events* into
/// existing buckets (constant row heights, stable scroll geometry) instead of growing
/// the array — appending/prepending rows mid-gesture is what used to make the scroll
/// jump.
@MainActor
final class CalendarStore: ObservableObject {
    enum AccessState: Equatable {
        case unknown
        case granted
        case denied
    }

    @Published private(set) var access: AccessState = .unknown
    @Published private(set) var days: [DayBucket] = []
    @Published private(set) var timeAxis: TimeAxis = TimeAxis.build(from: [])
    @Published var lastError: String?
    /// Bumped whenever something asks the timeline to scroll back to today (e.g.,
    /// the Today toolbar button). The view watches this with onChange.
    @Published var jumpToTodayTrigger: UUID = UUID()

    let today: Date
    /// Fixed day window covered by `days`. Set at init, never mutated.
    private(set) var windowStart: Date
    private(set) var windowEnd: Date       // exclusive

    /// Contiguous sub-range of the window whose *events* have been fetched.
    private(set) var rangeStart: Date
    private(set) var rangeEnd: Date        // exclusive

    private let source: CalendarSource
    private let calendar: Calendar
    private let expansionPadDays: Int
    private let axisPadDays: Int

    /// Every event fetched so far. Keyed by id + start time so occurrences of a
    /// recurring event (which share an identifier) don't collapse into one.
    private var loadedEvents: [String: SourceEvent] = [:]

    init(source: CalendarSource = EventKitCalendarSource(),
         calendar: Calendar = .current,
         today: Date = Date(),
         windowPastDays: Int = 366 * 3,
         windowFutureDays: Int = 366 * 3,
         initialPastDays: Int = 60,
         initialFutureDays: Int = 90,
         expansionPadDays: Int = 60,
         axisPadDays: Int = 90) {
        self.source = source
        self.calendar = calendar
        let startOfToday = calendar.startOfDay(for: today)
        self.today = startOfToday
        self.expansionPadDays = expansionPadDays
        self.axisPadDays = axisPadDays
        let wStart = calendar.date(byAdding: .day, value: -windowPastDays, to: startOfToday)
            ?? startOfToday
        let wEnd = calendar.date(byAdding: .day, value: windowFutureDays, to: startOfToday)
            ?? startOfToday
        self.windowStart = wStart
        self.windowEnd = wEnd
        self.rangeStart = max(
            wStart,
            calendar.date(byAdding: .day, value: -initialPastDays, to: startOfToday) ?? startOfToday
        )
        self.rangeEnd = min(
            wEnd,
            calendar.date(byAdding: .day, value: initialFutureDays, to: startOfToday) ?? startOfToday
        )
    }

    // MARK: - Lifecycle

    func requestAccessAndLoad() async {
        do {
            let granted = try await source.requestAccess()
            self.access = granted ? .granted : .denied
            if granted { initialLoad() }
        } catch {
            self.access = .denied
            self.lastError = error.localizedDescription
        }
    }

    /// For tests and a manual refresh control. Skips the access prompt; assumes granted.
    func loadAssumingAccess() {
        self.access = .granted
        initialLoad()
    }

    /// Re-fetch events for the already-loaded range. Keeps `days` length unchanged.
    func reload() {
        guard access == .granted, !days.isEmpty else { return }
        loadedEvents.removeAll()
        fetchAndMerge(from: rangeStart, to: rangeEnd)
        rebuildBuckets(from: rangeStart, to: rangeEnd)
        rebuildAxis()
    }

    private func initialLoad() {
        buildSkeleton()
        fetchAndMerge(from: rangeStart, to: rangeEnd)
        rebuildBuckets(from: rangeStart, to: rangeEnd)
        rebuildAxis()
    }

    /// Build the fixed-length day array once. Buckets start with no events; event
    /// loading fills them in without ever changing the array's length.
    private func buildSkeleton() {
        var buckets: [DayBucket] = []
        var cursor = windowStart
        while cursor < windowEnd {
            let next = calendar.date(byAdding: .day, value: 1, to: cursor)
                ?? cursor.addingTimeInterval(86_400)
            buckets.append(DayBucket(id: cursor, date: cursor, events: [], isToday: cursor == today))
            cursor = next
        }
        self.days = buckets
    }

    // MARK: - Incremental event loading

    /// Make sure events around `date` are loaded. Fetches only the missing slice of
    /// the range (with hysteresis so scrolling doesn't fire a query per row) and
    /// rebuilds only the affected buckets. Never changes `days.count` and never
    /// touches the axis — scroll geometry stays stable.
    func ensureLoaded(around date: Date) {
        guard access == .granted, !days.isEmpty else { return }
        let target = calendar.startOfDay(for: date)
        let wantStart = max(windowStart, dayOffset(target, -expansionPadDays))
        let wantEnd = min(windowEnd, dayOffset(target, expansionPadDays + 1))

        if wantStart < rangeStart {
            // Overshoot by another pad so the next backward trigger is ~pad days away.
            let fetchStart = max(windowStart, dayOffset(target, -expansionPadDays * 2))
            fetchAndMerge(from: fetchStart, to: rangeStart)
            let oldStart = rangeStart
            rangeStart = fetchStart
            rebuildBuckets(from: fetchStart, to: oldStart)
        }
        if wantEnd > rangeEnd {
            let fetchEnd = min(windowEnd, dayOffset(target, expansionPadDays * 2 + 1))
            fetchAndMerge(from: rangeEnd, to: fetchEnd)
            let oldEnd = rangeEnd
            rangeEnd = fetchEnd
            rebuildBuckets(from: oldEnd, to: fetchEnd)
        }
    }

    private func fetchAndMerge(from start: Date, to end: Date) {
        guard start < end else { return }
        for event in source.events(from: start, to: end) {
            loadedEvents["\(event.id)#\(event.start.timeIntervalSince1970)"] = event
        }
    }

    /// Re-project loaded events into the buckets covering [start, end).
    private func rebuildBuckets(from start: Date, to end: Date) {
        guard let firstIdx = dayIndex(for: start) else { return }
        let relevant = loadedEvents.values.filter { $0.start < end && $0.end > start }
        var idx = firstIdx
        var cursor = start
        while cursor < end, idx < days.count {
            let next = calendar.date(byAdding: .day, value: 1, to: cursor)
                ?? cursor.addingTimeInterval(86_400)
            let projected = relevant.compactMap { DayEvent.project($0, into: cursor, dayEnd: next) }
            days[idx] = DayBucket(id: cursor, date: cursor, events: projected, isToday: cursor == today)
            cursor = next
            idx += 1
        }
    }

    // MARK: - Axis (stable per load, never rebuilt by scrolling)

    /// Hour-density axis derived from a FIXED window around today (±axisPadDays),
    /// not from everything ever loaded — so gridline positions don't shift as the
    /// user scrolls and more events stream in.
    private func rebuildAxis() {
        let axisStart = max(windowStart, dayOffset(today, -axisPadDays))
        let axisEnd = min(windowEnd, dayOffset(today, axisPadDays))
        var counts = Array(repeating: 0, count: 24)
        // Walk buckets from axisStart until we reach axisEnd. Deliberately not
        // `dayIndex(for: axisEnd)`: axisEnd can equal windowEnd (exclusive), which
        // has no bucket index — resolving it would nil out and skip every event.
        if let startIdx = dayIndex(for: axisStart) {
            var i = startIdx
            while i < days.count, days[i].date < axisEnd {
                for event in days[i].timedEvents {
                    let s = max(0, min(1440, event.startMinute))
                    let e = max(s + 1, min(1440, event.endMinute))
                    for h in min(23, s / 60)...min(23, (e - 1) / 60) { counts[h] += 1 }
                }
                i += 1
            }
        }
        // An empty calendar gets a business-hours bias so the axis is still meaningful.
        if !counts.contains(where: { $0 > 0 }) {
            for h in 7..<22 { counts[h] = 1 }
        }
        self.timeAxis = TimeAxis.build(from: counts)
    }

    // MARK: - Lookups for the view layer

    /// O(1) index of the bucket containing `date`, or nil outside the window.
    func dayIndex(for date: Date) -> Int? {
        let day = calendar.startOfDay(for: date)
        guard let offset = calendar.dateComponents([.day], from: windowStart, to: day).day,
              offset >= 0, offset < days.count
        else { return nil }
        return offset
    }

    func dayBucket(for date: Date) -> DayBucket? {
        dayIndex(for: date).map { days[$0] }
    }

    /// First-day-of-month dates spanning the fixed window. Drives the month bar —
    /// every month in the bar is reachable because `days` covers the same window.
    var monthsInRange: [Date] {
        guard !days.isEmpty else { return [] }
        var months: [Date] = []
        var cursor = calendar.dateInterval(of: .month, for: windowStart)?.start ?? windowStart
        let endMonth = calendar.dateInterval(of: .month, for: windowEnd)?.start ?? windowEnd
        while cursor < endMonth {
            months.append(cursor)
            guard let next = calendar.date(byAdding: .month, value: 1, to: cursor) else { break }
            cursor = next
        }
        return months
    }

    /// Signal the view to scroll back to today.
    func jumpToToday() {
        jumpToTodayTrigger = UUID()
    }

    private func dayOffset(_ date: Date, _ delta: Int) -> Date {
        calendar.date(byAdding: .day, value: delta, to: date) ?? date
    }
}
