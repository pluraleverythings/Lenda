import SwiftUI

struct ContentView: View {
    @EnvironmentObject var store: CalendarStore

    var body: some View {
        NavigationStack {
            CalendarTimelineView()
                .navigationTitle("Lenda")
                .navigationBarTitleDisplayMode(.inline)
                .toolbarBackground(DR.surface, for: .navigationBar)
                .toolbarBackground(.visible, for: .navigationBar)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button {
                            store.jumpToToday()
                        } label: {
                            Text("Today")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(DR.ink)
                        }
                        .disabled(store.access != .granted)
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            store.reload()
                        } label: {
                            Image(systemName: "arrow.clockwise")
                                .foregroundStyle(DR.ink)
                        }
                        .disabled(store.access != .granted)
                    }
                }
        }
        .tint(DR.accent)
    }
}
