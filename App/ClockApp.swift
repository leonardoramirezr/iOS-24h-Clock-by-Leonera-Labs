import SwiftUI

@main
struct ClockApp: App {
    @StateObject private var store = EventStore()
    @StateObject private var locationService = LocationService()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
                .environmentObject(locationService)
        }
    }
}
