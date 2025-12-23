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
    @AppStorage(AppSettingsKeys.autoMode) private var autoMode: String = AppSettings.defaultAutoMode.rawValue
    @State private var isMonitoring = false
    @State private var statusMessage = ""
    @State private var showSleepScreen = false

    var body: some View {
        ScrollView {
            VStack(spacing: 6) {
                Text("Lucidity")
                    .font(.caption)
                    .bold()

                if !statusMessage.isEmpty {
                    Text(statusMessage)
                        .font(.caption2)
                        .foregroundColor(.orange)
                        .multilineTextAlignment(.center)
                        .padding(.vertical, 4)
                }

                VStack(spacing: 6) {
                    Button(action: {
                        startMonitoring(reason: "Manual start")
                    }) {
                        Text(isMonitoring ? "Monitoring..." : "Start Night")
                            .font(.caption)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 4)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isMonitoring)

                    Button(action: {
                        stopMonitoring(reason: "Manual stop")
                    }) {
                        Text("Stop")
                            .font(.caption)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 4)
                    }
                    .buttonStyle(.bordered)
                    .tint(.red)

                    NavigationLink {
                        SummaryView(health: health,
                                    haptics: haptics,
                                    motion: motion,
                                    requireStillness: requireStillness)
                    } label: {
                        Text("Summary")
                            .font(.caption)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 4)
                    }
                    .buttonStyle(.bordered)
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

                NavigationLink("Help") {
                    HelpView()
                }
                .font(.caption2)
            }
            .padding(6)
        }
        .fullScreenCover(isPresented: $showSleepScreen) {
            SleepScreenView {
                stopMonitoring(reason: "Stop from sleep screen")
            }
            .interactiveDismissDisabled()
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
        .onChange(of: motion.isStillForSleep) { _, still in
            guard !isMonitoring else { return }
            guard autoModeValue != .healthKitOnly else { return }
            if still {
                startMonitoring(reason: "Auto start (motion)")
            }
        }
        .onChange(of: motion.movingMinutes) { _, movingMinutes in
            guard isMonitoring else { return }
            guard autoModeValue != .healthKitOnly else { return }
            if movingMinutes >= 5 {
                stopMonitoring(reason: "Auto stop (motion)")
            }
        }
        .onChange(of: health.latestSleepStart) { _, start in
            guard !isMonitoring else { return }
            guard autoModeValue != .motionOnly else { return }
            guard let start = start else { return }
            if Date().timeIntervalSince(start) < 3 * 60 * 60 {
                startMonitoring(reason: "Auto start (HealthKit)")
            }
        }
        .onChange(of: health.latestSleepEnd) { _, end in
            guard isMonitoring else { return }
            guard autoModeValue != .motionOnly else { return }
            guard let end = end else { return }
            if Date().timeIntervalSince(end) > 5 * 60 {
                stopMonitoring(reason: "Auto stop (HealthKit)")
            }
        }
    }
    
    private var autoModeValue: AutoMode {
        AutoMode(rawValue: autoMode) ?? AppSettings.defaultAutoMode
    }

    private func startMonitoring(reason: String) {
        guard !isMonitoring else { return }
        Task { @MainActor in
            statusMessage = "Requesting permissions..."
            isMonitoring = true

            health.requestAuthorization { success, error in
                Task { @MainActor in
                    if success {
                        statusMessage = "Starting..."
                        if requireStillness || autoModeValue != .healthKitOnly {
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
                        HistoryStore.shared.log(note: reason)
                        NotificationCenter.default.post(name: .sessionDidStart, object: nil)
                        showSleepScreen = true

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
    }

    private func stopMonitoring(reason: String) {
        Task { @MainActor in
            isMonitoring = false
            statusMessage = "Stopped"
            showSleepScreen = false
            motion.stop()
            health.stopMonitoring()
            haptics.stopCueing()
            WorkoutSessionManager.shared.stopSession()
            HistoryStore.shared.log(note: "Session stopped")
            HistoryStore.shared.log(note: reason)
            NotificationCenter.default.post(name: .sessionDidStop, object: nil)

            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                statusMessage = ""
            }
        }
    }
}

struct SummaryView: View {
    @ObservedObject var health: HealthKitManager
    @ObservedObject var haptics: HapticCueManager
    @ObservedObject var motion: MotionSleepMonitor
    let requireStillness: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
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
        .padding(8)
        .navigationTitle("Summary")
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
        String(format: "%.0f min", motion.stillnessMinutes)
    }
}

#Preview {
    ContentView()
}
