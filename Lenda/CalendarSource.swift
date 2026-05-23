import Foundation
import CoreGraphics

/// Plain-data event from any calendar provider. Decoupled from EventKit so the rest of
/// the app — and tests — never import EventKit.
struct SourceEvent: Equatable {
    let id: String
    let title: String
    let start: Date
    let end: Date
    let isAllDay: Bool
    let location: String?
    let cgColor: CGColor?
}

/// A read-only view of "the user's calendar". The production implementation lives in
/// `EventKitCalendarSource`; tests pass a fake.
protocol CalendarSource: AnyObject {
    func requestAccess() async throws -> Bool
    func events(from start: Date, to end: Date) -> [SourceEvent]
}
