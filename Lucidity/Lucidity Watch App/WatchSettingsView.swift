import SwiftUI

struct WatchSettingsView: View {
    @AppStorage(AppSettingsKeys.lowPowerMode) private var lowPowerMode: Bool = false
    @AppStorage(AppSettingsKeys.requireStillness) private var requireStillness: Bool = true
    @AppStorage(AppSettingsKeys.stillnessMinutes) private var stillnessMinutes: Double = AppSettings.defaultStillnessMinutes
    @AppStorage(AppSettingsKeys.cueIntervalSeconds) private var cueIntervalSeconds: Double = AppSettings.defaultCueIntervalSeconds
    @AppStorage(AppSettingsKeys.useHRV) private var useHRV: Bool = true
    @AppStorage(AppSettingsKeys.useRespiratoryRate) private var useRespiratoryRate: Bool = true

    var body: some View {
        Form {
            Section(header: Text("Monitoring"), footer: Text("Low Power reduces cue cadence and skips workout sessions, which may delay heart rate updates.")) {
                Toggle("Low Power", isOn: $lowPowerMode)
                Toggle("Require Stillness", isOn: $requireStillness)
                Stepper("Stillness: \(Int(stillnessMinutes)) min", value: $stillnessMinutes, in: 5...30)
            }

            Section(header: Text("Cues")) {
                Stepper("Cue Interval: \(Int(cueIntervalSeconds))s", value: $cueIntervalSeconds, in: 30...180, step: 15)
                Button("Test Haptic") {
                    HapticCueManager.shared.deliverGentleCue()
                }
            }

            Section(header: Text("Signals")) {
                Toggle("Use HRV", isOn: $useHRV)
                Toggle("Use Respiratory", isOn: $useRespiratoryRate)
            }
        }
        .navigationTitle("Settings")
    }
}

#Preview {
    NavigationStack {
        WatchSettingsView()
    }
}
