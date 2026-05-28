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
        return TimeAxis(hourWeights: weights, baseWeight: baseWeight)
    }

    var totalWeight: Double { hourWeights.reduce(0, +) }

    func x(forMinute minute: Int, totalWidth: CGFloat) -> CGFloat {
        let m = max(0, min(1440, minute))
        let h = min(23, m / 60)
        let within = m - h * 60
        let total = max(0.0001, totalWeight)
        let unit = Double(totalWidth) / total
        var used: Double = 0
        for i in 0..<h { used += hourWeights[i] }
        used += hourWeights[h] * Double(within) / 60.0
        return CGFloat(used * unit)
    }

    /// 25 ticks: one for each hour boundary 0…23 plus a closing tick at minute 1440.
    func hourTicks(totalWidth: CGFloat) -> [HourTick] {
        let total = max(0.0001, totalWeight)
        let unit = Double(totalWidth) / total
        var ticks: [HourTick] = []
        var used: Double = 0
        for h in 0..<24 {
            let xv = CGFloat(used * unit)
            let width = CGFloat(hourWeights[h] * unit)
            let isEmpty = abs(hourWeights[h] - baseWeight) < 0.0001
            ticks.append(HourTick(
                id: h * 60, minute: h * 60, x: xv, width: width, isEmpty: isEmpty
            ))
            used += hourWeights[h]
        }
        ticks.append(HourTick(
            id: 1440, minute: 1440, x: CGFloat(used * unit), width: 0, isEmpty: false
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

    init(axis: TimeAxis, width: CGFloat) {
        self.axis = axis
        self.width = width
        self.hourTicks = axis.hourTicks(totalWidth: width)
    }

    func x(forMinute m: Int) -> CGFloat { axis.x(forMinute: m, totalWidth: width) }
}
