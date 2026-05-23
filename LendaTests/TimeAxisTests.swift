import XCTest
@testable import Lenda

/// Interface-level tests for `TimeAxis`. Exercises `build(from:)` under representative
/// event distributions and asserts public-API properties of the resulting mapping,
/// rather than poking at internal segment merging.
final class TimeAxisTests: XCTestCase {

    // MARK: - Boundary invariants

    func test_emptyInput_mapsZeroToZeroAndEndToWidth() {
        let axis = TimeAxis.build(from: [])
        XCTAssertEqual(axis.x(forMinute: 0, totalWidth: 1000), 0, accuracy: 0.001)
        XCTAssertEqual(axis.x(forMinute: 1440, totalWidth: 1000), 1000, accuracy: 0.001)
    }

    func test_anyInput_mapsZeroToZeroAndEndToWidth() {
        let axis = TimeAxis.build(from: [(9 * 60, 10 * 60), (14 * 60, 15 * 60)])
        XCTAssertEqual(axis.x(forMinute: 0, totalWidth: 800), 0, accuracy: 0.001)
        XCTAssertEqual(axis.x(forMinute: 1440, totalWidth: 800), 800, accuracy: 0.001)
    }

    func test_mappingIsMonotonicNonDecreasing() {
        let axis = TimeAxis.build(from: [(8 * 60, 10 * 60), (13 * 60, 14 * 60), (20 * 60, 22 * 60)])
        var last: CGFloat = -1
        for m in stride(from: 0, through: 1440, by: 15) {
            let x = axis.x(forMinute: m, totalWidth: 500)
            XCTAssertGreaterThanOrEqual(x, last, "x not monotonic at minute \(m)")
            last = x
        }
    }

    func test_clampingForOutOfRangeMinutes() {
        let axis = TimeAxis.build(from: [(10 * 60, 11 * 60)])
        XCTAssertEqual(axis.x(forMinute: -120, totalWidth: 500),
                       axis.x(forMinute: 0, totalWidth: 500), accuracy: 0.001)
        XCTAssertEqual(axis.x(forMinute: 1800, totalWidth: 500),
                       axis.x(forMinute: 1440, totalWidth: 500), accuracy: 0.001)
    }

    // MARK: - Compression behavior (the headline feature)

    func test_singleMorningEvent_compressesNightAndEvening() {
        let axis = TimeAxis.build(from: [(9 * 60, 11 * 60)])
        let ranges = axis.compressedRanges(totalWidth: 1000)
        XCTAssertFalse(ranges.isEmpty, "an isolated 9-11 event should yield compressed flanks")
        let totalCompressedWidth = ranges.reduce(0) { $0 + ($1.endX - $1.startX) }
        XCTAssertLessThan(totalCompressedWidth, 200,
                          "all-day silence should be visually compressed below ~20% of width")
    }

    func test_eventsAllDay_yieldNoCompression() {
        // Events every 30 minutes — no >=90 min gap anywhere.
        let intervals: [(Int, Int)] = stride(from: 0, to: 1440, by: 30).map { ($0, $0 + 30) }
        let axis = TimeAxis.build(from: intervals)
        XCTAssertTrue(axis.compressedRanges(totalWidth: 1000).isEmpty,
                      "wall-to-wall events should leave no compressed ranges")
    }

    func test_smallGap_isNotCompressed() {
        // Two events with a 30-minute gap (below the 90-min threshold).
        let axis = TimeAxis.build(from: [(10 * 60, 11 * 60), (11 * 60 + 30, 12 * 60 + 30)])
        let ranges = axis.compressedRanges(totalWidth: 1000)
        // No range should fall between 11:00 and 11:30.
        for r in ranges {
            let overlapsSmallGap = r.startMinute < 11 * 60 + 30 && r.endMinute > 11 * 60
            XCTAssertFalse(overlapsSmallGap, "30-min gap should remain dense, got compressed range \(r)")
        }
    }

    func test_largeGap_isCompressed() {
        // Two events with a 5-hour gap.
        let axis = TimeAxis.build(from: [(8 * 60, 9 * 60), (14 * 60, 15 * 60)])
        let ranges = axis.compressedRanges(totalWidth: 1000)
        let coversBigGap = ranges.contains { r in
            r.startMinute <= 10 * 60 && r.endMinute >= 13 * 60
        }
        XCTAssertTrue(coversBigGap, "5-hour gap should produce a compressed range covering its middle")
    }

    // MARK: - Hour ticks

    func test_hourTicks_areOrderedAndUnique() {
        let axis = TimeAxis.build(from: [(8 * 60, 10 * 60), (16 * 60, 18 * 60)])
        let ticks = axis.hourTicks(totalWidth: 1000)
        let minutes = ticks.map(\.minute)
        XCTAssertEqual(minutes, minutes.sorted(), "ticks must be in chronological order")
        XCTAssertEqual(Set(minutes).count, minutes.count, "ticks must be unique")
    }

    func test_hourTicks_markCompressedBoundaries() {
        let axis = TimeAxis.build(from: [(9 * 60, 10 * 60)])
        let ticks = axis.hourTicks(totalWidth: 1000)
        XCTAssertTrue(ticks.contains { $0.isCompressedBoundary },
                      "an isolated event should produce at least one compressed boundary tick")
    }

    // MARK: - Determinism

    func test_buildIsDeterministic_givenSameInput() {
        let intervals = [(9 * 60, 10 * 60), (14 * 60, 16 * 60)]
        let a = TimeAxis.build(from: intervals)
        let b = TimeAxis.build(from: intervals)
        XCTAssertEqual(a, b)
    }

    func test_inputOrder_doesNotAffectResult() {
        let a = TimeAxis.build(from: [(9 * 60, 10 * 60), (14 * 60, 15 * 60)])
        let b = TimeAxis.build(from: [(14 * 60, 15 * 60), (9 * 60, 10 * 60)])
        XCTAssertEqual(a, b)
    }

    // MARK: - Hour labels (public formatting helper)

    func test_hourLabelsForKeyMinutes() {
        XCTAssertEqual(TimeAxis.hourLabel(0), "12a")
        XCTAssertEqual(TimeAxis.hourLabel(60), "1a")
        XCTAssertEqual(TimeAxis.hourLabel(11 * 60), "11a")
        XCTAssertEqual(TimeAxis.hourLabel(12 * 60), "12p")
        XCTAssertEqual(TimeAxis.hourLabel(13 * 60), "1p")
        XCTAssertEqual(TimeAxis.hourLabel(1440), "12a")
    }
}
