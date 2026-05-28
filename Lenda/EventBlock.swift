import SwiftUI

/// Pale tinted fill with a saturated colour edge. The title only renders when the
/// parent decides there's room inside the block.
struct EventBlock: View {
    let event: DayEvent
    var showLabel: Bool = true

    var body: some View {
        HStack(spacing: 0) {
            Rectangle()
                .fill(event.color)
                .frame(width: 2)
            ZStack(alignment: .leading) {
                Rectangle().fill(event.color.opacity(0.18))
                if showLabel {
                    Text(event.title)
                        .font(DR.TypeStyle.eventTitle)
                        .foregroundStyle(DR.ink)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .padding(.horizontal, 4)
                }
            }
        }
    }
}
