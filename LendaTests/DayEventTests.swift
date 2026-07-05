import XCTest
@testable import Lenda

/// Tests for `DayEvent.project(_:into:dayEnd:)` — the single place a raw
/// `SourceEvent` becomes a day-relative renderable event.
final class DayEventTests: XCTestCase {

    private func day(_ d: Int) -> Date { TestDate.date(day: d) }

    func test_project_returnsNilWhenEventDoesNotTouchTheDay() {
        let ev = SourceEvent.make(
            start: TestDate.date(day: 9, hour: 10),
            end: TestDate.date(day: 9, hour: 11)
        )
        XCTAssertNil(DayEvent.project(ev, into: day(10), dayEnd: day(11)))
    }

    func test_project_eventEndingExactlyAtDayStart_isExcluded() {
        // `end == dayStart` means the event finished at midnight — it belongs to
        // the previous day only.
        let ev = SourceEvent.make(
            start: TestDate.date(day: 9, hour: 23),
            end: day(10)
        )
        XCTAssertNil(DayEvent.project(ev, into: day(10), dayEnd: day(11)))
    }

    func test_project_clampsMultiDayEventToDayBounds() {
        let ev = SourceEvent.make(
            start: TestDate.date(day: 9, hour: 22),
            end: TestDate.date(day: 10, hour: 3)
        )
        let projected = DayEvent.project(ev, into: day(10), dayEnd: day(11))
        XCTAssertEqual(projected?.startMinute, 0)
        XCTAssertEqual(projected?.endMinute, 3 * 60)
    }

    func test_project_enforcesMinimumVisualWidth() {
        // A 2-minute event still renders at least 5 minutes wide so it stays
        // visible and tappable on the timeline.
        let ev = SourceEvent.make(
            start: TestDate.date(day: 10, hour: 9),
            end: TestDate.date(day: 10, hour: 9, minute: 2)
        )
        let projected = DayEvent.project(ev, into: day(10), dayEnd: day(11))
        XCTAssertNotNil(projected)
        XCTAssertGreaterThanOrEqual(projected!.endMinute - projected!.startMinute, 5)
    }

    func test_project_idIsUniquePerDay_forMultiDayEvents() {
        let ev = SourceEvent.make(
            id: "trip",
            start: TestDate.date(day: 10, hour: 22),
            end: TestDate.date(day: 11, hour: 2)
        )
        let onDay10 = DayEvent.project(ev, into: day(10), dayEnd: day(11))
        let onDay11 = DayEvent.project(ev, into: day(11), dayEnd: day(12))
        XCTAssertNotNil(onDay10)
        XCTAssertNotNil(onDay11)
        XCTAssertNotEqual(onDay10?.id, onDay11?.id,
                          "same source event on two days must yield distinct row identities")
    }

    func test_project_preservesTitleLocationAndAllDayFlag() {
        let ev = SourceEvent.make(
            title: "Dentist",
            start: day(11),
            end: day(12),
            isAllDay: true,
            location: "12 High St"
        )
        let projected = DayEvent.project(ev, into: day(11), dayEnd: day(12))
        XCTAssertEqual(projected?.title, "Dentist")
        XCTAssertEqual(projected?.location, "12 High St")
        XCTAssertEqual(projected?.isAllDay, true)
    }
}
