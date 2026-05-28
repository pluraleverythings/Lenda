import SwiftUI

struct TimeAxisHeader: View {
    let layout: AxisLayout

    var body: some View {
        ZStack(alignment: .topLeading) {
            ForEach(visibleTicks) { tick in
                Text(TimeAxis.hourLabel(tick.minute))
                    .font(DR.TypeStyle.hourTick)
                    .foregroundStyle(DR.inkSecondary)
                    .fixedSize()
                    .offset(x: tick.x - 9, y: 2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Thin out labels so they never collide. The axis hands out hour-on-the-hour
    /// positions in order; skip any that would land within ~16 pt of one already
    /// placed. On narrow widths or under non-uniform weighting some labels drop out.
    private var visibleTicks: [TimeAxis.HourTick] {
        let minSpacing: CGFloat = 16
        var placed: [TimeAxis.HourTick] = []
        for tick in layout.hourTicks {
            if placed.allSatisfy({ abs($0.x - tick.x) >= minSpacing }) {
                placed.append(tick)
            }
        }
        return placed
    }
}
