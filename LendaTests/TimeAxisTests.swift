import XCTest
@testable import Lenda

/// Interface tests for the per-hour-weighted `TimeAxis`. Exercises `build(from:)`
/// with representative event-density distributions and asserts public-API properties.
final class TimeAxisTests: XCTestCase {

    private let allZero = Array(repeating: 0, count: 24)
    private let allOne = Array(repeating: 1, count: 24)

    // MARK: - Boundary invariants

    func test_emptyCounts_mapsZeroToZeroAndEndToWidth() {
        let axis = TimeAxis.build(from: allZero)
        XCTAssertEqual(axis.x(forMinute: 0, totalWidth: 1000), 0, accuracy: 0.001)
        XCTAssertEqual(axis.x(forMinute: 1440, totalWidth: 1000), 1000, accuracy: 0.001)
    }

    func test_anyCounts_mapsZeroToZeroAndEndToWidth() {
        var counts = allZero
        counts[9] = 3; counts[14] = 5
        let axis = TimeAxis.build(from: counts)
        XCTAssertEqual(axis.x(forMinute: 0, totalWidth: 800), 0, accuracy: 0.001)
        XCTAssertEqual(axis.x(forMinute: 1440, totalWidth: 800), 800, accuracy: 0.001)
    }

    func test_mappingIsMonotonicNonDecreasing() {
        var counts = allZero
        counts[8] = 2; counts[13] = 4; counts[20] = 1
        let axis = TimeAxis.build(from: counts)
        var last: CGFloat = -1
        for m in stride(from: 0, through: 1440, by: 15) {
            let x = axis.x(forMinute: m, totalWidth: 500)
            XCTAssertGreaterThanOrEqual(x, last, "x not monotonic at minute \(m)")
            last = x
        }
    }

    func test_clampingForOutOfRangeMinutes() {
        let axis = TimeAxis.build(from: allOne)
        XCTAssertEqual(axis.x(forMinute: -120, totalWidth: 500),
                       axis.x(forMinute: 0, totalWidth: 500), accuracy: 0.001)
        XCTAssertEqual(axis.x(forMinute: 1800, totalWidth: 500),
                       axis.x(forMinute: 1440, totalWidth: 500), accuracy: 0.001)
    }

    // MARK: - Density-driven width (the headline feature)

    func test_uniformCounts_yieldUniformHourWidths() {
        let axis = TimeAxis.build(from: allOne)
        let ticks = axis.hourTicks(totalWidth: 2400)
        for h in 0..<24 {
            XCTAssertEqual(ticks[h].width, 100, accuracy: 0.01)
        }
    }

    func test_busierHourGetsMoreWidth_thanLessBusyHour() {
        var counts = allZero
        counts[11] = 15
        counts[12] = 20
        let axis = TimeAxis.build(from: counts)
        let ticks = axis.hourTicks(totalWidth: 1000)
        XCTAssertGreaterThan(ticks[12].width, ticks[11].width,
                             "hour with more events must be wider")
    }

    func test_zeroEventHoursCollapseToTinyBaseline() {
        var counts = allZero
        counts[12] = 20
        let axis = TimeAxis.build(from: counts)
        let ticks = axis.hourTicks(totalWidth: 1000)
        XCTAssertTrue(ticks[2].isEmpty, "0-event hour should be marked empty")
        XCTAssertFalse(ticks[12].isEmpty, "busy hour should not be marked empty")
        XCTAssertLessThan(ticks[2].width, ticks[12].width / 10,
                          "empty hour width must be a small fraction of a busy hour's")
    }

    // MARK: - Hour ticks

    func test_hourTicks_areAtEveryHourBoundary_andOrdered() {
        let axis = TimeAxis.build(from: allOne)
        let ticks = axis.hourTicks(totalWidth: 1000)
        XCTAssertEqual(ticks.map(\.minute),
                       Array(stride(from: 0, through: 1440, by: 60)))
    }

    func test_widthsSumToTotalWidth() {
        var counts = allZero
        counts[7] = 4; counts[8] = 6; counts[19] = 2
        let axis = TimeAxis.build(from: counts)
        let ticks = axis.hourTicks(totalWidth: 1000)
        let sum = ticks.reduce(0) { $0 + $1.width }
        XCTAssertEqual(sum, 1000, accuracy: 0.01)
    }

    // MARK: - Determinism

    func test_buildIsDeterministic_givenSameInput() {
        var counts = allZero
        counts[9] = 4; counts[14] = 7
        let a = TimeAxis.build(from: counts)
        let b = TimeAxis.build(from: counts)
        XCTAssertEqual(a, b)
    }

    // MARK: - Hour labels

    func test_hourLabelsForKeyMinutes() {
        XCTAssertEqual(TimeAxis.hourLabel(0), "12a")
        XCTAssertEqual(TimeAxis.hourLabel(60), "1a")
        XCTAssertEqual(TimeAxis.hourLabel(11 * 60), "11a")
        XCTAssertEqual(TimeAxis.hourLabel(12 * 60), "12p")
        XCTAssertEqual(TimeAxis.hourLabel(13 * 60), "1p")
        XCTAssertEqual(TimeAxis.hourLabel(1440), "12a")
    }
}
