import SwiftUI

@main
struct ClockApp: App {
    @StateObject private var store = EventStore()
    @StateObject private var locationService = LocationService()
    @StateObject private var calendarService = CalendarService()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
                .environmentObject(locationService)
                .environmentObject(calendarService)
        }
    }
}
