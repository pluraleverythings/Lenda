import Foundation
@testable import Lenda

final class FakeCalendarSource: CalendarSource {
    enum AccessOutcome {
        case grant
        case deny
        case throwError(Error)
    }

    var accessOutcome: AccessOutcome = .grant
    var events: [SourceEvent] = []

    private(set) var requestAccessCallCount = 0
    private(set) var lastQueryWindow: (Date, Date)?
    private(set) var queryCount = 0

    func requestAccess() async throws -> Bool {
        requestAccessCallCount += 1
        switch accessOutcome {
        case .grant: return true
        case .deny: return false
        case .throwError(let e): throw e
        }
    }

    func events(from start: Date, to end: Date) -> [SourceEvent] {
        queryCount += 1
        lastQueryWindow = (start, end)
        return events.filter { $0.start < end && $0.end > start }
    }
}

extension SourceEvent {
    /// Convenience builder used by tests.
    static func make(
        id: String = UUID().uuidString,
        title: String = "Event",
        start: Date,
        end: Date,
        isAllDay: Bool = false,
        location: String? = nil
    ) -> SourceEvent {
        SourceEvent(
            id: id,
            title: title,
            start: start,
            end: end,
            isAllDay: isAllDay,
            location: location,
            cgColor: nil
        )
    }
}

enum TestDate {
    static let calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        return c
    }()

    /// `2025-03-10 09:00:00 UTC` — a known wall-clock Monday for stability.
    static let referenceToday: Date = {
        var comps = DateComponents()
        comps.year = 2025; comps.month = 3; comps.day = 10
        comps.hour = 9; comps.minute = 0
        return calendar.date(from: comps)!
    }()

    static func date(year: Int = 2025, month: Int = 3, day: Int = 10,
                     hour: Int = 0, minute: Int = 0) -> Date {
        var comps = DateComponents()
        comps.year = year; comps.month = month; comps.day = day
        comps.hour = hour; comps.minute = minute
        return calendar.date(from: comps)!
    }
}
