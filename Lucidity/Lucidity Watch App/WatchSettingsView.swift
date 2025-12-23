import SwiftUI
import WatchKit

struct WatchSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage(AppSettingsKeys.lowPowerMode) private var lowPowerMode: Bool = false
    @AppStorage(AppSettingsKeys.requireStillness) private var requireStillness: Bool = true
    @AppStorage(AppSettingsKeys.stillnessMinutes) private var stillnessMinutes: Double = AppSettings.defaultStillnessMinutes
    @AppStorage(AppSettingsKeys.cueIntervalSeconds) private var cueIntervalSeconds: Double = AppSettings.defaultCueIntervalSeconds
    @AppStorage(AppSettingsKeys.useHRV) private var useHRV: Bool = true
    @AppStorage(AppSettingsKeys.useRespiratoryRate) private var useRespiratoryRate: Bool = true
    @AppStorage(AppSettingsKeys.hapticPulseCount) private var hapticPulseCount: Int = AppSettings.defaultHapticPulseCount
    @AppStorage(AppSettingsKeys.hapticPulseInterval) private var hapticPulseInterval: Double = AppSettings.defaultHapticPulseInterval
    @AppStorage(AppSettingsKeys.hapticPatternType) private var hapticPatternType: String = AppSettings.defaultHapticPatternType.rawValue
    @AppStorage(AppSettingsKeys.detectionStrictness) private var detectionStrictness: String = AppSettings.defaultDetectionStrictness.rawValue
    @AppStorage(AppSettingsKeys.autoMode) private var autoMode: String = AppSettings.defaultAutoMode.rawValue
    @AppStorage(AppSettingsKeys.sleepBackgroundStyle) private var sleepBackgroundStyle: String = AppSettings.defaultSleepBackgroundStyle.rawValue

    var body: some View {
        Form {
            Section(header: Text("Monitoring").font(.caption2),
                    footer: Text("Low Power reduces cue cadence and skips workout sessions, which may delay heart rate updates.").font(.caption2)) {
                Toggle(isOn: $lowPowerMode) {
                    Text("Low Power").font(.caption2)
                }
                Toggle(isOn: $requireStillness) {
                    Text("Require Stillness").font(.caption2)
                }
                Stepper(value: $stillnessMinutes, in: 5...30) {
                    Text("Stillness: \(Int(stillnessMinutes)) min").font(.caption2)
                }
            }

            Section(header: Text("Cues").font(.caption2)) {
                Stepper(value: $cueIntervalSeconds, in: 30...180, step: 15) {
                    Text("Cue Interval: \(Int(cueIntervalSeconds))s").font(.caption2)
                }
                Stepper(value: $hapticPulseCount, in: 3...15) {
                    Text("Pulse Count: \(hapticPulseCount)").font(.caption2)
                }
                Stepper(value: $hapticPulseInterval, in: 0.2...0.4, step: 0.05) {
                    Text("Pulse Interval: \(formattedPulseInterval())s").font(.caption2)
                }
                Picker("Haptic Type", selection: $hapticPatternType) {
                    ForEach(HapticPatternType.allCases) { pattern in
                        Text(pattern.label).tag(pattern.rawValue)
                    }
                }
                .font(.caption2)
                Button {
                    HapticCueManager.shared.deliverGentleCue(note: "Test haptic")
                } label: {
                    Text("Test Haptic").font(.caption2)
                }
            }

            Section(header: Text("Detection").font(.caption2)) {
                Picker("Strictness", selection: $detectionStrictness) {
                    ForEach(DetectionStrictness.allCases) { strictness in
                        Text(strictness.label).tag(strictness.rawValue)
                    }
                }
                .font(.caption2)
            }

            Section(header: Text("Automation").font(.caption2)) {
                Picker("Auto Mode", selection: $autoMode) {
                    ForEach(AutoMode.allCases) { mode in
                        Text(mode.label).tag(mode.rawValue)
                    }
                }
                .font(.caption2)
            }

            Section(header: Text("Display").font(.caption2)) {
                Picker("Sleep Screen", selection: $sleepBackgroundStyle) {
                    ForEach(SleepBackgroundStyle.allCases) { style in
                        Text(style.label).tag(style.rawValue)
                    }
                }
                .font(.caption2)
            }

            Section(header: Text("Signals").font(.caption2)) {
                Toggle(isOn: $useHRV) {
                    Text("Use HRV").font(.caption2)
                }
                Toggle(isOn: $useRespiratoryRate) {
                    Text("Use Respiratory").font(.caption2)
                }
            }
        }
        .navigationTitle("Settings")
        .onReceive(NotificationCenter.default.publisher(for: .sessionDidStart)) { _ in
            dismiss()
        }
    }

    private func formattedPulseInterval() -> String {
        String(format: "%.2f", hapticPulseInterval)
    }
}

#Preview {
    NavigationStack {
        WatchSettingsView()
    }
}
