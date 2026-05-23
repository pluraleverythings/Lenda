import SwiftUI

/// Rams-style event block: pale tinted fill, thin saturated edge bar in the calendar's
/// colour, dark text. Color is functional (identifies the source) — not decorative.
struct EventBlock: View {
    let event: DayEvent

    var body: some View {
        HStack(spacing: 0) {
            Rectangle()
                .fill(event.color)
                .frame(width: 2)
            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(event.color.opacity(0.18))
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
