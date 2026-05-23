import SwiftUI

struct ContentView: View {
    @EnvironmentObject var store: CalendarStore

    private static let titleFmt: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMM d"
        return f
    }()

    var body: some View {
        NavigationStack {
            WeekView()
                .navigationTitle(weekTitle)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            store.reload()
                        } label: {
                            Image(systemName: "arrow.clockwise")
                        }
                        .disabled(store.access != .granted)
                    }
                }
        }
    }

    private var weekTitle: String {
        guard let first = store.days.first?.date,
              let last = store.days.last?.date else { return "This Week" }
        return "\(Self.titleFmt.string(from: first)) – \(Self.titleFmt.string(from: last))"
    }
}
