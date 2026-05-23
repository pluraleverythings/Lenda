import SwiftUI

struct WeekView: View {
    @EnvironmentObject var store: CalendarStore

    private static let dayLabelWidth: CGFloat = 56

    var body: some View {
        switch store.access {
        case .unknown:
            ProgressView().controlSize(.large)
        case .denied:
            PermissionView()
        case .granted:
            content
        }
    }

    @ViewBuilder
    private var content: some View {
        let axis = makeAxis()
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 8) {
                Spacer().frame(width: Self.dayLabelWidth)
                TimeAxisHeader(axis: axis)
                    .frame(height: 28)
                    .padding(.trailing, 8)
            }
            .padding(.horizontal, 8)
            .padding(.top, 4)

            Divider().padding(.horizontal, 8)

            ScrollView {
                LazyVStack(spacing: 6) {
                    ForEach(store.days) { day in
                        DayRowView(day: day, axis: axis, dayLabelWidth: Self.dayLabelWidth)
                    }
                }
                .padding(.vertical, 8)
            }
            .refreshable { store.reload() }
        }
    }

    private func makeAxis() -> TimeAxis {
        let intervals: [(Int, Int)] = store.days.flatMap { day in
            day.timedEvents.map { ($0.startMinutes, $0.endMinutes) }
        }
        if intervals.isEmpty {
            return TimeAxis.build(from: [(7 * 60, 22 * 60)])
        }
        return TimeAxis.build(from: intervals)
    }
}

private struct PermissionView: View {
    @EnvironmentObject var store: CalendarStore

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "calendar.badge.exclamationmark")
                .font(.system(size: 44))
                .foregroundStyle(.tint)
            Text("Lenda needs calendar access")
                .font(.title3.weight(.semibold))
            Text("Lenda shows your iCloud and other calendars in a smarter week view. We never send your events anywhere.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("Grant access") {
                Task { await store.requestAccessAndLoad() }
            }
            .buttonStyle(.borderedProminent)
            if let err = store.lastError {
                Text(err).font(.caption).foregroundStyle(.red)
            }
            Text("If you've denied access before, enable it in Settings → Privacy & Security → Calendars → Lenda.")
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .padding(28)
    }
}
