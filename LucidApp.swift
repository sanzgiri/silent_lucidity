import SwiftUI

@main
struct LucidApp: App {
    @StateObject private var sessionManager = SessionManager()
    @StateObject private var detector = DreamDetector()
    
    var body: some Scene {
        WindowGroup {
            NavigationView {
                ContentView()
            }
            .environmentObject(sessionManager)
            .environmentObject(detector)
                .onAppear {
                    // Connect SessionManager HR updates to DreamDetector
                    sessionManager.onHeartRateUpdate = { bpm, date in
                        detector.processHeartRate(bpm: bpm, date: date)
                    }
                }
        }
    }
}
