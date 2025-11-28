import SwiftUI
import HealthKit

struct ContentView: View {
    @EnvironmentObject var sessionManager: SessionManager
    @EnvironmentObject var detector: DreamDetector
    
    var body: some View {
        VStack {
            Text("Lucid Dreamer")
                .font(.headline)
                .padding()
            
            if sessionManager.state == .running {
                Text("Session Active")
                    .foregroundColor(.green)
                    .padding(.bottom, 5)
                
                if detector.isMonitoring {
                    Text("Monitoring...")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                
                if detector.isDreamingCandidate {
                    Text("REALITY CHECK")
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(.purple)
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color.purple.opacity(0.2))
                        )
                        .transition(.scale)
                }
                
                Text(detector.debugLog)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                    .padding()
                    .lineLimit(3)
                
                Button(action: {
                    sessionManager.stopSession()
                    detector.stopMonitoring()
                }) {
                    Text("Stop Session")
                        .foregroundColor(.red)
                }
            } else {
                Text("Ready to Sleep")
                    .foregroundColor(.gray)
                    .padding(.bottom, 10)
                
                Button(action: {
                    sessionManager.requestAuthorization()
                    sessionManager.startOvernightSession()
                    detector.startMonitoring()
                }) {
                    Text("Start Sleep Session")
                        .foregroundColor(.blue)
                }
                
                NavigationLink(destination: SettingsView()) {
                    Text("Settings")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                .padding(.top, 10)
            }
        }
        .padding()
    }
}
