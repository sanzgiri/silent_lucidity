import WatchKit
import Foundation
import SwiftUI
import Combine

/// Manages haptic cues related to REM window changes.
/// 
/// - Important:
///   - This class throttles haptic cues using the configured interval settings.
///   - Cues are suppressed when the app is active (i.e., display is awake and user is interacting).
///   - Use the shared singleton instance to access and control cueing.
final class HapticCueManager: ObservableObject {
    static let shared = HapticCueManager()

    @Published var isCueing: Bool = false
    @Published var lastCueDate: Date?

    private var timer: Timer?
    private var isREM: Bool = false
    private var settingsObserver: NSObjectProtocol?

    public init() {}

    /// Starts observing REM window changes and begins cueing when REM is true.
    func startCueing() {
        guard !isCueing else { return }
        isCueing = true
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(remWindowDidChange(_:)),
                                               name: HealthKitManager.remWindowDidChangeNotification,
                                               object: nil)
        settingsObserver = NotificationCenter.default.addObserver(forName: UserDefaults.didChangeNotification,
                                                                  object: nil,
                                                                  queue: .main) { [weak self] _ in
            self?.settingsDidChange()
        }
    }

    /// Stops all cueing and removes observers.
    func stopCueing() {
        isCueing = false
        NotificationCenter.default.removeObserver(self, name: HealthKitManager.remWindowDidChangeNotification, object: nil)
        if let settingsObserver = settingsObserver {
            NotificationCenter.default.removeObserver(settingsObserver)
            self.settingsObserver = nil
        }
        cancelTimer()
        isREM = false
    }

    private func settingsDidChange() {
        guard isREM else { return }
        startTimer()
    }

    @objc private func remWindowDidChange(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let rem = userInfo["isREM"] as? Bool else {
            return
        }
        updateREM(rem)
    }

    private func updateREM(_ rem: Bool) {
        if rem && !isREM {
            isREM = true
            startTimer()
        } else if !rem && isREM {
            isREM = false
            cancelTimer()
        }
    }

    private func startTimer() {
        // Schedule a timer that fires on the configured interval on the main run loop.
        DispatchQueue.main.async {
            self.timer?.invalidate()
            let interval = AppSettings.cueIntervalSeconds
            self.timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
                self?.tryDeliverCue()
            }
            // Fire immediately on start for responsiveness
            self.tryDeliverCue()
        }
    }

    private func cancelTimer() {
        DispatchQueue.main.async {
            self.timer?.invalidate()
            self.timer = nil
        }
    }

    private func tryDeliverCue() {
        // Suppress if app is active (display awake + user interacting)
        guard WKApplication.shared().applicationState != .active else { return }

        // Throttle: no cue more often than every 20 seconds
        if let last = lastCueDate {
            if Date().timeIntervalSince(last) < AppSettings.minCueIntervalSeconds {
                return
            }
        }
        deliverGentleCue()
        lastCueDate = Date()
    }

    /// Plays a gentle haptic cue to the user.
    /// Uses the configured pattern for pulse count, interval, and type.
    func deliverGentleCue(note: String? = "Cue delivered") {
        let device = WKInterfaceDevice.current()
        let pulseCount = AppSettings.hapticPulseCount
        let pulseInterval = AppSettings.hapticPulseInterval
        let secondaryDelay = min(0.12, pulseInterval * 0.5)
        let pattern = AppSettings.hapticPatternType

        for index in 0..<pulseCount {
            let delay = TimeInterval(index) * pulseInterval
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                switch pattern {
                case .clickOnly:
                    device.play(.click)
                case .startOnly:
                    device.play(.start)
                case .clickAndStart:
                    device.play(.click)
                    DispatchQueue.main.asyncAfter(deadline: .now() + secondaryDelay) {
                        device.play(.start)
                    }
                }
            }
        }

        if let note = note {
            Task { @MainActor in
                HistoryStore.shared.log(note: note)
            }
        }
    }
}
