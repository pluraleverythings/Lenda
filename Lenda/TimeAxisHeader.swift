import SwiftUI

struct TimeAxisHeader: View {
    let layout: AxisLayout

    var body: some View {
        ZStack(alignment: .topLeading) {
            ForEach(visibleTicks) { tick in
                Text(TimeAxis.hourLabel(tick.minute))
                    .font(tick.isCompressedBoundary
                          ? DR.TypeStyle.hourTickEmphasis
                          : DR.TypeStyle.hourTick)
                    .foregroundStyle(tick.isCompressedBoundary ? DR.ink : DR.inkSecondary)
                    .fixedSize()
                    .offset(x: tick.x - 9, y: 2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Thin out labels so they never collide. The regular hourly ticks are the primary
    /// scale and are placed first (some drop out on very narrow widths); compressed-region
    /// boundary labels are added only where they still fit. Without this, the boundary
    /// labels in the tiny pre-dawn / late-night slivers overlap the adjacent hour labels.
    private var visibleTicks: [TimeAxis.HourTick] {
        let minSpacing: CGFloat = 16
        var placed: [TimeAxis.HourTick] = []
        func fits(_ tick: TimeAxis.HourTick) -> Bool {
            placed.allSatisfy { abs($0.x - tick.x) >= minSpacing }
        }
        for tick in layout.hourTicks where !tick.isCompressedBoundary {
            if fits(tick) { placed.append(tick) }
        }
        for tick in layout.hourTicks where tick.isCompressedBoundary {
            if fits(tick) { placed.append(tick) }
        }
        return placed.sorted { $0.x < $1.x }
    }
}
