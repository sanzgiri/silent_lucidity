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
    @ObservedObject private var haptics = HapticCueManager.shared
    @ObservedObject private var motion = MotionSleepMonitor.shared
    @AppStorage(AppSettingsKeys.lowPowerMode) private var lowPowerMode: Bool = false
    @AppStorage(AppSettingsKeys.requireStillness) private var requireStillness: Bool = true
    @State private var isMonitoring = false
    @State private var statusMessage = ""

    var body: some View {
        ScrollView {
            VStack(spacing: 6) {
                Text("Lucidity")
                    .font(.caption)
                    .bold()

                VStack(spacing: 2) {
                    Text("HR: \(formattedHeartRate())")
                    Text("Last: \(formattedSleepWindow())")
                        .lineLimit(1)
                    Text("REM: \(health.lastSleepWindowDescription)")
                        .lineLimit(1)
                    Text("Cue: \(formattedLastCue())")
                        .lineLimit(1)
                    if requireStillness {
                        Text("Still: \(formattedStillness())")
                    }
                }
                .font(.caption2)
                .minimumScaleFactor(0.8)
                .foregroundColor(.secondary)

                if !statusMessage.isEmpty {
                    Text(statusMessage)
                        .font(.caption2)
                        .foregroundColor(.orange)
                        .multilineTextAlignment(.center)
                        .padding(.vertical, 4)
                }

                VStack(spacing: 6) {
                    Button(action: {
                        Task { @MainActor in
                            statusMessage = "Requesting permissions..."
                            isMonitoring = true

                            health.requestAuthorization { success, error in
                                Task { @MainActor in
                                    if success {
                                        statusMessage = "Starting..."
                                        if requireStillness {
                                            motion.start()
                                        } else {
                                            motion.stop()
                                        }
                                        health.startMonitoring()
                                        haptics.startCueing()
                                        if !lowPowerMode {
                                            WorkoutSessionManager.shared.startOvernightSession()
                                        }
                                        HistoryStore.shared.log(note: lowPowerMode ? "Session started (low power)" : "Session started")

                                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                            statusMessage = lowPowerMode ? "Monitoring active (low power)" : "Monitoring active"
                                        }
                                    } else {
                                        if let nsError = error as NSError? {
                                            if nsError.domain == HKErrorDomain, let hkCode = HKError.Code(rawValue: nsError.code) {
                                                switch hkCode {
                                                case .errorAuthorizationDenied:
                                                    statusMessage = "Permission denied"
                                                case .errorHealthDataUnavailable:
                                                    statusMessage = "Health data unavailable"
                                                default:
                                                    statusMessage = nsError.localizedDescription
                                                }
                                            } else {
                                                statusMessage = nsError.localizedDescription
                                            }
                                        } else {
                                            statusMessage = "Permission denied"
                                        }
                                        isMonitoring = false
                                    }
                                }
                            }
                        }
                    }) {
                        Text(isMonitoring ? "Monitoring..." : "Start Night")
                            .font(.caption)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 4)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isMonitoring)

                    Button(action: {
                        Task { @MainActor in
                            isMonitoring = false
                            statusMessage = "Stopped"
                            motion.stop()
                            health.stopMonitoring()
                            haptics.stopCueing()
                            WorkoutSessionManager.shared.stopSession()
                            HistoryStore.shared.log(note: "Session stopped")

                            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                statusMessage = ""
                            }
                        }
                    }) {
                        Text("Stop")
                            .font(.caption)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 4)
                    }
                    .buttonStyle(.bordered)
                    .tint(.red)
                }

                NavigationLink("History") {
                    HistoryView()
                }
                .font(.caption2)
                .padding(.top, 2)

                NavigationLink("Settings") {
                    WatchSettingsView()
                }
                .font(.caption2)
            }
            .padding(6)
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

    private func formattedLastCue() -> String {
        guard let date = haptics.lastCueDate else { return "None" }
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private func formattedStillness() -> String {
        return String(format: "%.0f min", motion.stillnessMinutes)
    }
}

#Preview {
    ContentView()
}
