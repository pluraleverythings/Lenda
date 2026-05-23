import Foundation
import SwiftUI

/// A `SourceEvent` projected onto a single day's minute axis (0...1440).
/// Multi-day events become one `DayEvent` per day they touch, with start/end clamped
/// to that day.
struct DayEvent: Identifiable, Equatable {
    let id: String
    let title: String
    let start: Date
    let end: Date
    let color: Color
    let isAllDay: Bool
    let location: String?
    let startMinute: Int
    let endMinute: Int

    /// Project a `SourceEvent` onto a day window. Returns nil if the event doesn't
    /// intersect the window.
    static func project(_ source: SourceEvent, into dayStart: Date, dayEnd: Date) -> DayEvent? {
        guard source.start < dayEnd, source.end > dayStart else { return nil }
        let clampedStart = max(source.start, dayStart)
        let clampedEnd = min(source.end, dayEnd)
        let dayLengthMinutes = Int(dayEnd.timeIntervalSince(dayStart) / 60)
        let rawStart = Int(clampedStart.timeIntervalSince(dayStart) / 60)
        let rawEnd = Int(clampedEnd.timeIntervalSince(dayStart) / 60)
        let s = max(0, min(dayLengthMinutes, rawStart))
        let e = max(s + 5, min(dayLengthMinutes, rawEnd))
        let color: Color = source.cgColor.map(Color.init(cgColor:)) ?? Color.gray
        return DayEvent(
            id: "\(source.id)#\(Int(dayStart.timeIntervalSince1970))",
            title: source.title,
            start: clampedStart,
            end: clampedEnd,
            color: color,
            isAllDay: source.isAllDay,
            location: source.location,
            startMinute: s,
            endMinute: e
        )
    }
}
