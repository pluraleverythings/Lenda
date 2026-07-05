import XCTest
@testable import Lenda

/// Interface tests for `LanePacker.pack(_:)`. Treats it as a black box: given event
/// time ranges, the returned items must be lane-assigned without overlap on any lane,
/// and `totalLanes` must equal the actual minimum required.
final class LanePackerTests: XCTestCase {

    func test_empty_returnsEmpty() {
        XCTAssertTrue(LanePacker.pack([]).isEmpty)
    }

    func test_singleEvent_oneLane() {
        let items = LanePacker.pack([fakeEvent(id: "a", start: 60, end: 120)])
        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(items[0].lane, 0)
        XCTAssertEqual(items[0].totalLanes, 1)
    }

    func test_nonOverlappingEvents_shareOneLane() {
        let items = LanePacker.pack([
            fakeEvent(id: "a", start: 60, end: 120),
            fakeEvent(id: "b", start: 180, end: 240)
        ])
        XCTAssertEqual(Set(items.map(\.lane)), Set([0]))
        XCTAssertTrue(items.allSatisfy { $0.totalLanes == 1 })
    }

    func test_overlappingEvents_useDistinctLanes() {
        let items = LanePacker.pack([
            fakeEvent(id: "a", start: 60, end: 180),
            fakeEvent(id: "b", start: 90, end: 150)
        ])
        XCTAssertEqual(items.count, 2)
        XCTAssertEqual(Set(items.map(\.lane)), Set([0, 1]))
        XCTAssertTrue(items.allSatisfy { $0.totalLanes == 2 })
    }

    func test_threewayOverlap_yieldsThreeLanes() {
        let items = LanePacker.pack([
            fakeEvent(id: "a", start: 60, end: 200),
            fakeEvent(id: "b", start: 80, end: 220),
            fakeEvent(id: "c", start: 100, end: 240)
        ])
        XCTAssertEqual(Set(items.map(\.lane)), Set([0, 1, 2]))
        XCTAssertTrue(items.allSatisfy { $0.totalLanes == 3 })
    }

    func test_lanesAreReusedAfterClusterEnds() {
        // Two overlapping pairs separated in time should each use only 2 lanes total.
        let items = LanePacker.pack([
            fakeEvent(id: "a", start: 60, end: 120),
            fakeEvent(id: "b", start: 90, end: 150),    // overlaps with a
            fakeEvent(id: "c", start: 300, end: 360),   // clear of everything else
            fakeEvent(id: "d", start: 320, end: 380)    // overlaps with c
        ])
        XCTAssertTrue(items.allSatisfy { $0.totalLanes == 2 })
        // c should land back on lane 0 since a/b's lanes have freed up by minute 300.
        let cItem = items.first(where: { $0.event.id == "c" })!
        XCTAssertEqual(cItem.lane, 0)
    }

    func test_assignedLanes_haveNoOverlap_onEachLane() {
        let items = LanePacker.pack([
            fakeEvent(id: "a", start: 60, end: 150),
            fakeEvent(id: "b", start: 80, end: 200),
            fakeEvent(id: "c", start: 150, end: 250),
            fakeEvent(id: "d", start: 220, end: 300)
        ])
        let byLane = Dictionary(grouping: items, by: \.lane)
        for (lane, group) in byLane {
            let sorted = group.sorted { $0.event.startMinute < $1.event.startMinute }
            for i in 1..<sorted.count {
                XCTAssertGreaterThanOrEqual(
                    sorted[i].event.startMinute,
                    sorted[i - 1].event.endMinute,
                    "events overlap on lane \(lane): \(sorted[i - 1]) and \(sorted[i])"
                )
            }
        }
    }

    func test_identicalIntervals_getDistinctLanes() {
        let items = LanePacker.pack([
            fakeEvent(id: "a", start: 60, end: 120),
            fakeEvent(id: "b", start: 60, end: 120),
            fakeEvent(id: "c", start: 60, end: 120)
        ])
        XCTAssertEqual(Set(items.map(\.lane)), Set([0, 1, 2]))
        XCTAssertTrue(items.allSatisfy { $0.totalLanes == 3 })
    }

    func test_resultIsSortedByStartTime() {
        let items = LanePacker.pack([
            fakeEvent(id: "late", start: 200, end: 260),
            fakeEvent(id: "early", start: 60, end: 120),
            fakeEvent(id: "mid", start: 100, end: 160)
        ])
        XCTAssertEqual(items.map(\.event.id), ["early", "mid", "late"])
    }

    // MARK: - Helpers

    private func fakeEvent(id: String, start: Int, end: Int) -> DayEvent {
        DayEvent(
            id: id,
            title: id,
            start: Date(timeIntervalSince1970: TimeInterval(start * 60)),
            end: Date(timeIntervalSince1970: TimeInterval(end * 60)),
            color: .gray,
            isAllDay: false,
            location: nil,
            startMinute: start,
            endMinute: end
        )
    }
}
