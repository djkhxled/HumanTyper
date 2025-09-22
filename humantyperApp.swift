import SwiftUI

@main
struct humantyperApp: App {
    @StateObject private var engine = HumanTyperEngine()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(engine)
        }
    }
}
