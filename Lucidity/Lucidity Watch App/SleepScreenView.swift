import SwiftUI

struct SleepScreenView: View {
    @Environment(\.isLuminanceReduced) private var isLuminanceReduced
    let onStop: () -> Void

    @State private var breathe = false

    var body: some View {
        ZStack {
            backgroundView()
            VStack(spacing: 6) {
                Text("Monitoring")
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.8))
                Button("Stop") {
                    onStop()
                }
                .font(.caption2)
                .buttonStyle(.bordered)
                .tint(.red)
            }
        }
        .ignoresSafeArea()
        .onAppear {
            if AppSettings.sleepBackgroundStyle == .breathingGlow && !isLuminanceReduced {
                withAnimation(.easeInOut(duration: 50).repeatForever(autoreverses: true)) {
                    breathe = true
                }
            }
        }
        .onChange(of: isLuminanceReduced) { _, reduced in
            if reduced {
                breathe = false
            }
        }
    }

    @ViewBuilder
    private func backgroundView() -> some View {
        switch AppSettings.sleepBackgroundStyle {
        case .radialGlow:
            radialGlow()
        case .moonRings:
            moonRings()
        case .starfield:
            starfield()
        case .breathingGlow:
            breathingGlow()
        }
    }

    private func radialGlow() -> some View {
        RadialGradient(colors: [
            Color(red: 0.05, green: 0.12, blue: 0.14).opacity(0.9),
            Color.black
        ], center: .center, startRadius: 5, endRadius: 120)
    }

    private func moonRings() -> some View {
        ZStack {
            Color.black
            Circle()
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
                .frame(width: 140, height: 140)
            Circle()
                .stroke(Color.white.opacity(0.05), lineWidth: 1)
                .frame(width: 200, height: 200)
            Circle()
                .stroke(Color.white.opacity(0.03), lineWidth: 1)
                .frame(width: 260, height: 260)
        }
    }

    private func starfield() -> some View {
        ZStack {
            Color.black
            ForEach(Self.stars) { star in
                Circle()
                    .fill(Color.white.opacity(star.opacity))
                    .frame(width: star.size, height: star.size)
                    .position(x: star.x, y: star.y)
            }
        }
    }

    private func breathingGlow() -> some View {
        let base = RadialGradient(colors: [
            Color(red: 0.06, green: 0.14, blue: 0.18),
            Color.black
        ], center: .center, startRadius: 5, endRadius: 140)
        return base
            .opacity(breathe ? 0.55 : 0.35)
    }

    private struct Star: Identifiable {
        let id = UUID()
        let x: CGFloat
        let y: CGFloat
        let size: CGFloat
        let opacity: Double
    }

    private static let stars: [Star] = [
        Star(x: 30, y: 25, size: 2, opacity: 0.5),
        Star(x: 120, y: 35, size: 1.5, opacity: 0.4),
        Star(x: 70, y: 65, size: 2, opacity: 0.35),
        Star(x: 160, y: 80, size: 1.8, opacity: 0.45),
        Star(x: 45, y: 120, size: 1.4, opacity: 0.3),
        Star(x: 130, y: 130, size: 2.2, opacity: 0.35),
        Star(x: 90, y: 170, size: 1.6, opacity: 0.4),
        Star(x: 170, y: 190, size: 1.2, opacity: 0.3),
        Star(x: 25, y: 200, size: 1.8, opacity: 0.35),
        Star(x: 155, y: 210, size: 1.4, opacity: 0.32)
    ]
}

#Preview {
    SleepScreenView(onStop: {})
}
