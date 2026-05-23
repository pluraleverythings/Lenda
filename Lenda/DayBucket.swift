import Foundation

/// One calendar day, with its events projected to a day-relative minute axis.
struct DayBucket: Identifiable, Equatable {
    let id: Date           // start-of-day timestamp; stable across reloads
    let date: Date
    let events: [DayEvent]
    let isToday: Bool

    var allDayEvents: [DayEvent] { events.filter { $0.isAllDay } }
    var timedEvents: [DayEvent] { events.filter { !$0.isAllDay } }
}
