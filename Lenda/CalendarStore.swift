import Foundation
import EventKit
import SwiftUI

@MainActor
final class CalendarStore: ObservableObject {
    enum AccessState {
        case unknown
        case granted
        case denied
    }

    private let store = EKEventStore()

    @Published var days: [DayBucket] = []
    @Published var access: AccessState = .unknown
    @Published var lastError: String?

    func requestAccessAndLoad() async {
        do {
            let granted: Bool
            if #available(iOS 17.0, *) {
                granted = try await store.requestFullAccessToEvents()
            } else {
                granted = try await store.requestAccess(to: .event)
            }
            self.access = granted ? .granted : .denied
            if granted { load() }
        } catch {
            self.access = .denied
            self.lastError = error.localizedDescription
        }
    }

    func reload() {
        guard access == .granted else { return }
        load()
    }

    private func load() {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        guard let weekEnd = cal.date(byAdding: .day, value: 7, to: today) else { return }

        let predicate = store.predicateForEvents(withStart: today, end: weekEnd, calendars: nil)
        let ekEvents = store.events(matching: predicate)

        var buckets: [DayBucket] = []
        for offset in 0..<7 {
            guard let dayStart = cal.date(byAdding: .day, value: offset, to: today) else { continue }
            let dayEnd = cal.date(byAdding: .day, value: 1, to: dayStart) ?? dayStart.addingTimeInterval(86400)
            let dayEvents = ekEvents
                .filter { $0.startDate < dayEnd && $0.endDate > dayStart }
                .map { ekEvent in
                    let s = max(ekEvent.startDate, dayStart)
                    let e = min(ekEvent.endDate, dayEnd)
                    let color: Color
                    if let cg = ekEvent.calendar?.cgColor {
                        color = Color(cgColor: cg)
                    } else {
                        color = .blue
                    }
                    let baseId = ekEvent.eventIdentifier ?? UUID().uuidString
                    return DayEvent.make(
                        id: "\(baseId)#\(Int(s.timeIntervalSince1970))",
                        title: ekEvent.title ?? "(No title)",
                        start: s,
                        end: e,
                        calendarColor: color,
                        isAllDay: ekEvent.isAllDay,
                        location: ekEvent.location,
                        dayStart: dayStart
                    )
                }
            buckets.append(DayBucket(id: dayStart, date: dayStart, events: dayEvents, isToday: offset == 0))
        }
        self.days = buckets
    }
}
