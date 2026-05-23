import SwiftUI

struct TimeAxisHeader: View {
    let layout: AxisLayout

    var body: some View {
        ZStack(alignment: .topLeading) {
            ForEach(layout.hourTicks) { tick in
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
}
