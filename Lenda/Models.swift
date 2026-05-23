import Foundation
import SwiftUI

struct DayEvent: Identifiable, Equatable {
    let id: String
    let title: String
    let start: Date
    let end: Date
    let calendarColor: Color
    let isAllDay: Bool
    let location: String?

    let startMinutes: Int
    let endMinutes: Int

    static func make(id: String,
                     title: String,
                     start: Date,
                     end: Date,
                     calendarColor: Color,
                     isAllDay: Bool,
                     location: String?,
                     dayStart: Date) -> DayEvent {
        let s = Int(max(0, start.timeIntervalSince(dayStart) / 60))
        let e = Int(min(1440, end.timeIntervalSince(dayStart) / 60))
        return DayEvent(
            id: id,
            title: title,
            start: start,
            end: end,
            calendarColor: calendarColor,
            isAllDay: isAllDay,
            location: location,
            startMinutes: max(0, min(1440, s)),
            endMinutes: max(0, min(1440, max(s + 5, e)))
        )
    }
}

struct DayBucket: Identifiable {
    let id: Date
    let date: Date
    let events: [DayEvent]
    let isToday: Bool

    var allDayEvents: [DayEvent] { events.filter { $0.isAllDay } }
    var timedEvents: [DayEvent] { events.filter { !$0.isAllDay } }
}
