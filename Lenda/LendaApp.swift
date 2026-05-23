import SwiftUI

@main
struct LendaApp: App {
    @StateObject private var store = CalendarStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
                .task { await store.requestAccessAndLoad() }
        }
    }
}
