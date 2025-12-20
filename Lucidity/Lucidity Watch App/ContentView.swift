//
//  ContentView.swift
//  Lucidity Watch App
//
//  Created by Ashutosh Sanzgiri on 11/28/25.
//

import SwiftUI
import HealthKit
import Combine

struct ContentView: View {
    @StateObject private var health = HealthKitManager.shared
    @StateObject private var haptics = HapticCueManager()

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                Text("Lucidity")
                    .font(.title2)
                    .bold()
                
                Text("Last sleep window: \(formattedSleepWindow())\nLast heart rate: \(formattedHeartRate())")
                    .multilineTextAlignment(.center)
                    .font(.body)
                
                HStack(spacing: 20) {
                    Button("Start Night") {
                        if !health.isAuthorized {
                            health.requestAuthorization { success, error in
                                health.startMonitoring()
                                haptics.startCueing()
                                WorkoutSessionManager.shared.startOvernightSession()
                            }
                        } else {
                            health.startMonitoring()
                            haptics.startCueing()
                            WorkoutSessionManager.shared.startOvernightSession()
                        }
                    }
                    Button("Stop") {
                        health.stopMonitoring()
                        haptics.stopCueing()
                        WorkoutSessionManager.shared.stopSession()
                    }
                }
                .buttonStyle(.bordered)
                
                NavigationLink("View History") {
                    HistoryView()
                }
                .font(.footnote)
                
                Text("Disclaimer: This app is for informational purposes only.")
                    .font(.footnote)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
                    .padding(.top, 8)
            }
        }
        .padding()
        .onAppear {
            if !health.isAuthorized {
                health.requestAuthorization { success, error in
                    health.fetchLatestSleepData()
                }
            } else {
                health.fetchLatestSleepData()
            }
        }
    }
    
    private func formattedSleepWindow() -> String {
        if let start = health.latestSleepStart, let end = health.latestSleepEnd {
            let formatter = DateFormatter()
            formatter.timeStyle = .short
            formatter.dateStyle = .short
            return "\(formatter.string(from: start)) - \(formatter.string(from: end))"
        } else {
            return "No data"
        }
    }
    
    private func formattedHeartRate() -> String {
        if let hr = health.latestHeartRate {
            return String(format: "%.0f bpm", hr)
        } else {
            return "No data"
        }
    }
}

#Preview {
    ContentView()
}
