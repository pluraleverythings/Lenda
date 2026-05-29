import Foundation
import CoreGraphics

/// A horizontal mapping where each hour's width is proportional to how much activity
/// happens at that hour across the loaded window. Empty hours collapse to a baseline
/// sliver; busy hours expand. At a glance the axis stretches around when your events
/// actually happen.
struct TimeAxis: Equatable {
    /// Width weights for hours 0…23. Larger = wider on screen.
    let hourWeights: [Double]
    let baseWeight: Double
    /// Prefix sums of `hourWeights`; `cumulativeWeights[h] == sum(hourWeights[0..<h])`.
    /// Size 25. Lets `x(forMinute:)` run in O(1).
    let cumulativeWeights: [Double]

    struct HourTick: Identifiable, Equatable {
        let id: Int
        let minute: Int     // multiple of 60 (0…1440)
        let x: CGFloat      // left edge of this hour in the totalWidth
        let width: CGFloat  // width allocated to this hour (0 at the closing 1440 tick)
        let isEmpty: Bool   // true if this hour received only baseWeight
    }

    /// Build an axis from a per-hour event count (24 entries, index = hour-of-day).
    /// `baseWeight` keeps zero-event hours visible but tiny; `countScale` controls how
    /// aggressively busy hours expand relative to empty ones.
    static func build(
        from hourEventCounts: [Int],
        baseWeight: Double = 0.15,
        countScale: Double = 1.0
    ) -> TimeAxis {
        let counts = hourEventCounts.count == 24
            ? hourEventCounts
            : Array(repeating: 0, count: 24)
        let weights = counts.map { baseWeight + countScale * Double($0) }
        var cumulative: [Double] = []
        cumulative.reserveCapacity(25)
        cumulative.append(0)
        var running: Double = 0
        for w in weights {
            running += w
            cumulative.append(running)
        }
        return TimeAxis(hourWeights: weights, baseWeight: baseWeight, cumulativeWeights: cumulative)
    }

    var totalWeight: Double { cumulativeWeights.last ?? 0 }

    func x(forMinute minute: Int, totalWidth: CGFloat) -> CGFloat {
        let m = max(0, min(1440, minute))
        let h = min(23, m / 60)
        let within = m - h * 60
        let total = max(0.0001, totalWeight)
        let unit = Double(totalWidth) / total
        let used = cumulativeWeights[h] + hourWeights[h] * Double(within) / 60.0
        return CGFloat(used * unit)
    }

    /// 25 ticks: one for each hour boundary 0…23 plus a closing tick at minute 1440.
    func hourTicks(totalWidth: CGFloat) -> [HourTick] {
        let total = max(0.0001, totalWeight)
        let unit = Double(totalWidth) / total
        var ticks: [HourTick] = []
        ticks.reserveCapacity(25)
        for h in 0..<24 {
            let xv = CGFloat(cumulativeWeights[h] * unit)
            let width = CGFloat(hourWeights[h] * unit)
            let isEmpty = abs(hourWeights[h] - baseWeight) < 0.0001
            ticks.append(HourTick(
                id: h * 60, minute: h * 60, x: xv, width: width, isEmpty: isEmpty
            ))
        }
        ticks.append(HourTick(
            id: 1440, minute: 1440, x: CGFloat(totalWeight * unit), width: 0, isEmpty: false
        ))
        return ticks
    }

    static func hourLabel(_ minute: Int) -> String {
        let m = max(0, min(1440, minute))
        let h = m / 60
        switch h {
        case 0, 24: return "12a"
        case 12: return "12p"
        case 1..<12: return "\(h)a"
        default: return "\(h - 12)p"
        }
    }
}

/// Pre-computed positions for a given width. Holding one of these in the parent avoids
/// each row recomputing the same tick layout in its body.
struct AxisLayout: Equatable {
    let axis: TimeAxis
    let width: CGFloat
    let hourTicks: [TimeAxis.HourTick]
    /// Pre-filtered subset of `hourTicks` that the LazyVStack background shades.
    /// Cached so the filter doesn't run on every body evaluation during scroll.
    let emptyHourTicks: [TimeAxis.HourTick]

    init(axis: TimeAxis, width: CGFloat) {
        self.axis = axis
        self.width = width
        let ticks = axis.hourTicks(totalWidth: width)
        self.hourTicks = ticks
        self.emptyHourTicks = ticks.filter { $0.isEmpty && $0.width > 0 }
    }

    func x(forMinute m: Int) -> CGFloat { axis.x(forMinute: m, totalWidth: width) }
}
