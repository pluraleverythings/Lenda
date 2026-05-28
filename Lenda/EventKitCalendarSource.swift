import Foundation
import EventKit

final class EventKitCalendarSource: CalendarSource {
    private let store = EKEventStore()

    func requestAccess() async throws -> Bool {
        if #available(iOS 17.0, *) {
            return try await store.requestFullAccessToEvents()
        } else {
            return try await store.requestAccess(to: .event)
        }
    }

    func events(from start: Date, to end: Date) -> [SourceEvent] {
        // Force the store to pick up newly-added accounts / recently-synced
        // calendars; without this a CalDAV/iCloud account added after launch is
        // silently absent from queries.
        store.refreshSourcesIfNecessary()

        // `calendars: nil` is documented as "all calendars" but in practice
        // quietly skips some subscribed/remote calendars in mixed setups.
        // Enumerate every event-type calendar the app has access to and pass
        // the explicit list so nothing gets dropped.
        let calendars = store.calendars(for: .event)
        guard !calendars.isEmpty else { return [] }

        let predicate = store.predicateForEvents(withStart: start, end: end, calendars: calendars)
        return store.events(matching: predicate).map { ek in
            SourceEvent(
                id: ek.eventIdentifier ?? UUID().uuidString,
                title: ek.title ?? "(No title)",
                start: ek.startDate,
                end: ek.endDate,
                isAllDay: ek.isAllDay,
                location: ek.location,
                cgColor: ek.calendar?.cgColor
            )
        }
    }
}
