import SwiftUI
import WatchKit

struct WatchSettingsView: View {
    @AppStorage(AppSettingsKeys.lowPowerMode) private var lowPowerMode: Bool = false
    @AppStorage(AppSettingsKeys.requireStillness) private var requireStillness: Bool = true
    @AppStorage(AppSettingsKeys.stillnessMinutes) private var stillnessMinutes: Double = AppSettings.defaultStillnessMinutes
    @AppStorage(AppSettingsKeys.cueIntervalSeconds) private var cueIntervalSeconds: Double = AppSettings.defaultCueIntervalSeconds
    @AppStorage(AppSettingsKeys.useHRV) private var useHRV: Bool = true
    @AppStorage(AppSettingsKeys.useRespiratoryRate) private var useRespiratoryRate: Bool = true

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
                Button {
                    let device = WKInterfaceDevice.current()
                    device.play(.click)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                        device.play(.start)
                    }
                    Task { @MainActor in
                        HistoryStore.shared.log(note: "Test haptic")
                    }
                } label: {
                    Text("Test Haptic").font(.caption2)
                }
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
    }
}

#Preview {
    NavigationStack {
        WatchSettingsView()
    }
}
