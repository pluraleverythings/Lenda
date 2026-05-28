import Foundation
import SwiftUI

/// View-facing calendar state. Talks to any `CalendarSource`. Holds a contiguous range
/// of `DayBucket`s; the range expands outward as the user scrolls past its edges or
/// jumps to a month outside it.
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

    let today: Date
    private(set) var rangeStart: Date
    private(set) var rangeEnd: Date    // exclusive

    private let source: CalendarSource
    private let calendar: Calendar
    private let initialPastDays: Int
    private let initialFutureDays: Int
    private let expansionPadDays: Int

    /// Hard bounds on how far the loaded range may extend from `today`. A safety net so a
    /// stray expansion can never run the range off to absurd dates and build tens of
    /// thousands of day buckets (which wedges the main thread).
    private let maxPastDays = 366 * 2
    private let maxFutureDays = 366 * 2

    init(source: CalendarSource = EventKitCalendarSource(),
         calendar: Calendar = .current,
         today: Date = Date(),
         initialPastDays: Int = 30,
         initialFutureDays: Int = 60,
         expansionPadDays: Int = 30) {
        self.source = source
        self.calendar = calendar
        let startOfToday = calendar.startOfDay(for: today)
        self.today = startOfToday
        self.initialPastDays = initialPastDays
        self.initialFutureDays = initialFutureDays
        self.expansionPadDays = expansionPadDays
        self.rangeStart = calendar.date(byAdding: .day, value: -initialPastDays, to: startOfToday)
            ?? startOfToday
        self.rangeEnd = calendar.date(byAdding: .day, value: initialFutureDays, to: startOfToday)
            ?? startOfToday
    }

    // MARK: - Lifecycle

    func requestAccessAndLoad() async {
        do {
            let granted = try await source.requestAccess()
            self.access = granted ? .granted : .denied
            if granted { reload() }
        } catch {
            self.access = .denied
            self.lastError = error.localizedDescription
        }
    }

    /// For tests and a manual refresh control. Skips the access prompt; assumes granted.
    func loadAssumingAccess() {
        self.access = .granted
        reload()
    }

    func reload() {
        guard access == .granted else { return }
        load(from: rangeStart, to: rangeEnd)
    }

    // MARK: - Range expansion

    /// Ensure the loaded range covers `date` and a padding window on either side. No-op
    /// if the date is already comfortably inside the range.
    func ensureLoaded(around date: Date) {
        guard access == .granted else { return }
        let target = calendar.startOfDay(for: date)
        let rawStart = calendar.date(byAdding: .day, value: -expansionPadDays, to: target) ?? target
        let rawEnd = calendar.date(byAdding: .day, value: expansionPadDays + 1, to: target) ?? target

        let floor = calendar.date(byAdding: .day, value: -maxPastDays, to: today) ?? today
        let ceiling = calendar.date(byAdding: .day, value: maxFutureDays, to: today) ?? today
        let wantStart = max(rawStart, floor)
        let wantEnd = min(rawEnd, ceiling)

        var changed = false
        if wantStart < rangeStart { rangeStart = wantStart; changed = true }
        if wantEnd > rangeEnd { rangeEnd = wantEnd; changed = true }
        if changed { reload() }
    }

    // MARK: - Lookups for the view layer

    func dayBucket(for date: Date) -> DayBucket? {
        let startOfDay = calendar.startOfDay(for: date)
        return days.first(where: { $0.id == startOfDay })
    }

    /// First-day-of-month dates spanning the loaded range, in order. Drives the month bar.
    var monthsInRange: [Date] {
        guard !days.isEmpty else { return [] }
        var months: [Date] = []
        var cursor = calendar.dateInterval(of: .month, for: rangeStart)?.start ?? rangeStart
        let endMonth = calendar.dateInterval(of: .month, for: rangeEnd)?.start ?? rangeEnd
        while cursor < endMonth {
            months.append(cursor)
            guard let next = calendar.date(byAdding: .month, value: 1, to: cursor) else { break }
            cursor = next
        }
        return months
    }

    // MARK: - Loading

    private func load(from start: Date, to end: Date) {
        let raw = source.events(from: start, to: end)
        var buckets: [DayBucket] = []
        var cursor = start
        while cursor < end {
            let next = calendar.date(byAdding: .day, value: 1, to: cursor)
                ?? cursor.addingTimeInterval(86_400)
            let projected = raw.compactMap { DayEvent.project($0, into: cursor, dayEnd: next) }
            buckets.append(DayBucket(
                id: cursor,
                date: cursor,
                events: projected,
                isToday: cursor == today
            ))
            cursor = next
        }
        self.days = buckets
        self.timeAxis = buildAxis(from: buckets)
    }

    private func buildAxis(from buckets: [DayBucket]) -> TimeAxis {
        var counts = Array(repeating: 0, count: 24)
        for bucket in buckets {
            for event in bucket.timedEvents {
                let s = max(0, min(1440, event.startMinute))
                let e = max(s + 1, min(1440, event.endMinute))
                let startHour = min(23, s / 60)
                let endHour = min(23, (e - 1) / 60)
                for h in startHour...endHour { counts[h] += 1 }
            }
        }
        // An empty calendar gets a business-hours bias so the axis is still meaningful.
        if !counts.contains(where: { $0 > 0 }) {
            for h in 7..<22 { counts[h] = 1 }
        }
        return TimeAxis.build(from: counts)
    }
}
