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
    @State private var isMonitoring = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 8) {
                Text("Lucidity")
                    .font(.headline)
                    .bold()

                VStack(spacing: 4) {
                    Text("HR: \(formattedHeartRate())")
                        .font(.caption)
                    Text("Sleep: \(formattedSleepWindow())")
                        .font(.caption2)
                        .lineLimit(1)
                }
                .foregroundColor(.secondary)

                VStack(spacing: 8) {
                    Button(action: {
                        Task { @MainActor in
                            isMonitoring = true
                            if !health.isAuthorized {
                                health.requestAuthorization { success, error in
                                    Task { @MainActor in
                                        health.startMonitoring()
                                        haptics.startCueing()
                                        WorkoutSessionManager.shared.startOvernightSession()
                                    }
                                }
                            } else {
                                health.startMonitoring()
                                haptics.startCueing()
                                WorkoutSessionManager.shared.startOvernightSession()
                            }
                        }
                    }) {
                        Text("Start Night")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isMonitoring)

                    Button(action: {
                        Task { @MainActor in
                            isMonitoring = false
                            health.stopMonitoring()
                            haptics.stopCueing()
                            WorkoutSessionManager.shared.stopSession()
                        }
                    }) {
                        Text("Stop")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .tint(.red)
                }

                NavigationLink("History") {
                    HistoryView()
                }
                .font(.caption)
                .padding(.top, 4)

                Text("For wellness only")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .padding(.top, 4)
            }
            .padding(.horizontal, 8)
        }
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
        if let start = health.latestSleepStart {
            let formatter = DateFormatter()
            formatter.timeStyle = .short
            return formatter.string(from: start)
        }
        return "None"
    }

    private func formattedHeartRate() -> String {
        if let hr = health.latestHeartRate {
            return String(format: "%.0f", hr)
        }
        return "--"
    }
}

#Preview {
    ContentView()
}
