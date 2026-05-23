import SwiftUI

struct PermissionView: View {
    @EnvironmentObject var store: CalendarStore

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Calendar access")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(DR.ink)

            Text("Lenda needs to read your iCloud and other calendars to display them in a smarter week view. Events stay on this device.")
                .font(.system(size: 14))
                .foregroundStyle(DR.inkSecondary)

            Button {
                Task { await store.requestAccessAndLoad() }
            } label: {
                Text("Grant access")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(DR.accent)
            }
            .buttonStyle(.plain)

            if let err = store.lastError {
                Text(err)
                    .font(.footnote)
                    .foregroundStyle(.red)
            }

            Text("If you've denied before, enable it in Settings → Privacy & Security → Calendars → Lenda.")
                .font(.caption2)
                .foregroundStyle(DR.inkTertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(.horizontal, DR.horizontalPadding)
        .padding(.top, 24)
        .background(DR.surface)
    }
}
