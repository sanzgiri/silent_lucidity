import SwiftUI

struct SettingsView: View {
    @AppStorage("hapticIntensity") private var hapticIntensity: String = "Medium"
    @AppStorage("hapticRepeats") private var hapticRepeats: Int = 2
    
    let intensities = ["Low", "Medium", "High"]
    
    var body: some View {
        Form {
            Section(header: Text("Haptic Cue")) {
                Picker("Intensity", selection: $hapticIntensity) {
                    ForEach(intensities, id: \.self) { intensity in
                        Text(intensity)
                    }
                }
                
                Stepper("Repeats: \(hapticRepeats)", value: $hapticRepeats, in: 1...10)
                
                Text("Estimated Duration: ~\(String(format: "%.1f", Double(hapticRepeats) * 1.5)) sec")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            
            Section(footer: Text("Low: Click\nMedium: Thump + Click\nHigh: Heavy Thump\n\nIncrease repeats if you are a deep sleeper.")) {
                EmptyView()
            }
        }
        .navigationTitle("Settings")
    }
}
