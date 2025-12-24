import SwiftUI

struct HelpView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                sectionTitle("Overview")
                Text("Lucidity estimates REM windows using sleep stages, heart rate, optional HRV and respiratory rate, and motion stillness. It is a heuristic, not medical guidance.")
                Text("When sleep stages arrive after waking, the app falls back to session start or stillness onset and uses historical REM timing to estimate windows.")

                sectionTitle("Monitoring")
                Text("- Low Power reduces cue cadence, slows motion updates, and skips workout sessions to save battery.")
                Text("- Require Stillness gates detection until you are motionless for the configured minutes.")
                Text("- Auto Mode chooses how sessions auto-start/stop (Motion, Hybrid, or HealthKit only).")

                sectionTitle("Detection Strictness")
                Text("- Lenient: trust explicit REM stages; inferred REM may pass with HR range or support signals.")
                Text("- Balanced: uses HR range and/or support signals when available; default choice.")
                Text("- Strict: requires HR range plus support signals when available; inferred REM needs support availability.")

                sectionTitle("Cues")
                Text("- Cue Interval sets how often cues can fire during REM.")
                Text("- Pulse Count and Interval control cue length and spacing.")
                Text("- Haptic Type selects click, start, or click+start. Test Haptic uses the same pattern.")

                sectionTitle("Signals")
                Text("- HRV and Respiratory toggles add support signals; disabling them can increase cues but may reduce accuracy.")

                sectionTitle("Display")
                Text("- Sleep Screen background is configurable; static options save the most battery.")
                Text("- Breathing Glow animates slowly and uses more energy than static backgrounds.")

                sectionTitle("History")
                Text("- History logs session start/stop, REM start/end windows, and cue deliveries.")
            }
            .font(.caption2)
            .foregroundColor(.secondary)
            .padding(8)
        }
        .navigationTitle("Help")
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(.caption)
            .bold()
            .foregroundColor(.primary)
    }
}

#Preview {
    NavigationStack {
        HelpView()
    }
}
