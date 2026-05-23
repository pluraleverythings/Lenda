import SwiftUI

struct TimeAxisHeader: View {
    let axis: TimeAxis

    var body: some View {
        GeometryReader { proxy in
            let w = proxy.size.width
            ZStack(alignment: .topLeading) {
                ForEach(axis.compressedRanges(totalWidth: w)) { range in
                    let mid = (range.startX + range.endX) / 2
                    Image(systemName: "arrow.left.and.right.text.vertical")
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                        .offset(x: mid - 6, y: 14)
                }

                ForEach(axis.hourTicks(totalWidth: w)) { tick in
                    Text(TimeAxis.hourLabel(tick.minute))
                        .font(.system(size: 9, weight: tick.isCompressedBoundary ? .semibold : .regular))
                        .foregroundStyle(tick.isCompressedBoundary ? Color.accentColor : Color.secondary)
                        .fixedSize()
                        .offset(x: tick.x - 9, y: 0)
                }
            }
        }
    }
}
