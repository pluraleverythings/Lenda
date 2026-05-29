import SwiftUI

/// Pale tinted fill with a saturated colour edge. The title only renders when the
/// parent decides there's room inside the block; it wraps to as many lines as fit
/// the block's height.
struct EventBlock: View {
    let event: DayEvent
    var showLabel: Bool = true

    var body: some View {
        HStack(spacing: 0) {
            Rectangle()
                .fill(event.color)
                .frame(width: 2)
            ZStack(alignment: .topLeading) {
                Rectangle().fill(event.color.opacity(0.18))
                if showLabel {
                    Text(event.title)
                        .font(DR.TypeStyle.eventTitle)
                        .foregroundStyle(DR.ink)
                        .lineLimit(4)
                        .truncationMode(.tail)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 2)
                }
            }
        }
    }
}
