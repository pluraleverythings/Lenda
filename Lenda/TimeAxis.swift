import Foundation
import CoreGraphics

/// A piecewise-linear mapping from time-of-day (minutes 0...1440) to a horizontal x
/// coordinate. Hour ranges with no events in the entire visible window collapse to a
/// fixed small weight; busy hours expand to fill the rest of the width.
struct TimeAxis: Equatable {
    struct Segment: Equatable {
        let startMinute: Int
        let endMinute: Int
        let isDense: Bool

        var minuteSpan: Int { endMinute - startMinute }
    }

    struct HourTick: Identifiable, Equatable {
        let id: Int           // minute-of-day, doubles as a stable identity
        let minute: Int
        let x: CGFloat
        let isCompressedBoundary: Bool
    }

    struct CompressedRange: Identifiable, Equatable {
        let id: Int
        let startMinute: Int
        let endMinute: Int
        let startX: CGFloat
        let endX: CGFloat
        var label: String {
            "\(TimeAxis.hourLabel(startMinute)) – \(TimeAxis.hourLabel(endMinute))"
        }
    }

    let segments: [Segment]
    let compressedSegmentWeight: Int
    let paddingMinutes: Int

    // MARK: - Construction

    /// Build an axis from the union of all timed events in the visible window.
    /// `intervals` is `(startMinute, endMinute)` per event, each clamped to one day.
    static func build(
        from intervals: [(Int, Int)],
        paddingMinutes: Int = 30,
        minGapForCompression: Int = 90,
        compressedSegmentWeight: Int = 30
    ) -> TimeAxis {
        let padded = intervals
            .filter { $0.1 > $0.0 }
            .map { (max(0, $0.0 - paddingMinutes), min(1440, $0.1 + paddingMinutes)) }
            .sorted { $0.0 < $1.0 }

        var merged: [(Int, Int)] = []
        for iv in padded {
            if let last = merged.last, last.1 >= iv.0 {
                merged[merged.count - 1] = (last.0, max(last.1, iv.1))
            } else {
                merged.append(iv)
            }
        }

        var segs: [Segment] = []
        var cursor = 0
        for (s, e) in merged {
            if s > cursor {
                let dense = (s - cursor) < minGapForCompression
                segs.append(Segment(startMinute: cursor, endMinute: s, isDense: dense))
            }
            segs.append(Segment(startMinute: s, endMinute: e, isDense: true))
            cursor = e
        }
        if cursor < 1440 {
            let dense = (1440 - cursor) < minGapForCompression
            segs.append(Segment(startMinute: cursor, endMinute: 1440, isDense: dense))
        }

        // Collapse adjacent segments of the same density.
        var collapsed: [Segment] = []
        for s in segs {
            if let last = collapsed.last,
               last.isDense == s.isDense,
               last.endMinute == s.startMinute {
                collapsed[collapsed.count - 1] = Segment(
                    startMinute: last.startMinute,
                    endMinute: s.endMinute,
                    isDense: last.isDense
                )
            } else {
                collapsed.append(s)
            }
        }

        return TimeAxis(
            segments: collapsed,
            compressedSegmentWeight: compressedSegmentWeight,
            paddingMinutes: paddingMinutes
        )
    }

    // MARK: - Mapping

    var totalWeight: Int {
        segments.reduce(0) { acc, s in
            acc + (s.isDense ? s.minuteSpan : compressedSegmentWeight)
        }
    }

    func x(forMinute minute: Int, totalWidth: CGFloat) -> CGFloat {
        let m = max(0, min(1440, minute))
        let total = max(1, totalWeight)
        let unit = totalWidth / CGFloat(total)
        var used = 0
        for s in segments {
            if m <= s.endMinute {
                let segWeight = s.isDense ? s.minuteSpan : compressedSegmentWeight
                let fraction: CGFloat = s.minuteSpan == 0
                    ? 0
                    : CGFloat(m - s.startMinute) / CGFloat(s.minuteSpan)
                return (CGFloat(used) + fraction * CGFloat(segWeight)) * unit
            }
            used += s.isDense ? s.minuteSpan : compressedSegmentWeight
        }
        return totalWidth
    }

    /// Hour-boundary tick positions across all dense segments, plus the start/end of each
    /// compressed segment so the user can read where the skip starts and ends.
    func hourTicks(totalWidth: CGFloat) -> [HourTick] {
        var raw: [(Int, CGFloat, Bool)] = []
        for s in segments {
            if s.isDense {
                let firstHour = (s.startMinute + 59) / 60
                let lastHour = s.endMinute / 60
                if firstHour <= lastHour {
                    for h in firstHour...lastHour {
                        let m = h * 60
                        raw.append((m, x(forMinute: m, totalWidth: totalWidth), false))
                    }
                }
            } else {
                raw.append((s.startMinute, x(forMinute: s.startMinute, totalWidth: totalWidth), true))
                raw.append((s.endMinute, x(forMinute: s.endMinute, totalWidth: totalWidth), true))
            }
        }
        var out: [HourTick] = []
        for (m, xv, comp) in raw {
            if out.last?.minute == m { continue }
            out.append(HourTick(id: m, minute: m, x: xv, isCompressedBoundary: comp))
        }
        return out
    }

    func compressedRanges(totalWidth: CGFloat) -> [CompressedRange] {
        segments
            .filter { !$0.isDense }
            .map { s in
                CompressedRange(
                    id: s.startMinute,
                    startMinute: s.startMinute,
                    endMinute: s.endMinute,
                    startX: x(forMinute: s.startMinute, totalWidth: totalWidth),
                    endX: x(forMinute: s.endMinute, totalWidth: totalWidth)
                )
            }
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

/// Pre-computed positions for a given width. Holding one of these in the parent view
/// avoids each row recomputing the same tick layout in its body.
struct AxisLayout: Equatable {
    let axis: TimeAxis
    let width: CGFloat
    let hourTicks: [TimeAxis.HourTick]
    let compressedRanges: [TimeAxis.CompressedRange]

    init(axis: TimeAxis, width: CGFloat) {
        self.axis = axis
        self.width = width
        self.hourTicks = axis.hourTicks(totalWidth: width)
        self.compressedRanges = axis.compressedRanges(totalWidth: width)
    }

    func x(forMinute m: Int) -> CGFloat { axis.x(forMinute: m, totalWidth: width) }
}
