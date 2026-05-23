import SwiftUI

struct EventBlock: View {
    let event: DayEvent
    let compact: Bool

    var body: some View {
        ZStack(alignment: .leading) {
            RoundedRectangle(cornerRadius: 5)
                .fill(event.calendarColor.opacity(0.88))
            HStack(spacing: 3) {
                Rectangle()
                    .fill(Color.white.opacity(0.5))
                    .frame(width: 2)
                    .padding(.vertical, 2)
                Text(event.title)
                    .font(.system(size: compact ? 9 : 10, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            .padding(.horizontal, 3)
        }
    }
}
