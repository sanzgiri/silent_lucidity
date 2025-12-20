import WatchKit
import Foundation
import SwiftUI

/// Manages haptic cues related to REM window changes.
/// 
/// - Important:
///   - This class throttles haptic cues to no more than one every 20 seconds.
///   - Cues are suppressed when the app is active (i.e., display is awake and user is interacting).
///   - Use the shared singleton instance to access and control cueing.
final class HapticCueManager: ObservableObject {
    static let shared = HapticCueManager()

    @Published var isCueing: Bool = false
    @Published var lastCueDate: Date?

    private var timer: Timer?
    private var isREM: Bool = false

    private init() {}

    /// Starts observing REM window changes and begins cueing when REM is true.
    func startCueing() {
        guard !isCueing else { return }
        isCueing = true
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(remWindowDidChange(_:)),
                                               name: Notification.Name("REMWindowDidChange"),
                                               object: nil)
    }

    /// Stops all cueing and removes observers.
    func stopCueing() {
        isCueing = false
        NotificationCenter.default.removeObserver(self, name: Notification.Name("REMWindowDidChange"), object: nil)
        cancelTimer()
        isREM = false
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
        // Schedule a timer that fires every 30 seconds on the main run loop.
        DispatchQueue.main.async {
            self.timer?.invalidate()
            self.timer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
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
            if Date().timeIntervalSince(last) < 20 {
                return
            }
        }
        deliverGentleCue()
        lastCueDate = Date()
    }

    /// Plays a gentle haptic cue to the user.
    /// Uses a `.click` haptic and optionally `.start` for subtlety.
    func deliverGentleCue() {
        let device = WKInterfaceDevice.current()
        device.play(.click)
        // Optionally add a subtle secondary haptic for minimal intrusiveness
        if #available(watchOS 6.0, *) {
            device.play(.start)
        }
    }
}
