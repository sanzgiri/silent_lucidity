import CoreMotion
import Foundation
import Combine

@MainActor
final class MotionSleepMonitor: ObservableObject {
    static let shared = MotionSleepMonitor()

    @Published private(set) var isMonitoring: Bool = false
    @Published private(set) var isStillForSleep: Bool = false
    @Published private(set) var stillnessMinutes: Double = 0

    private let motionManager = CMMotionManager()
    private var lastMovementTime = Date()
    private let movementThreshold = 0.03
    private var settingsObserver: NSObjectProtocol?

    func start() {
        guard motionManager.isDeviceMotionAvailable else {
            isMonitoring = false
            resetState()
            return
        }

        resetState()
        isMonitoring = true
        motionManager.deviceMotionUpdateInterval = AppSettings.motionUpdateIntervalSeconds
        motionManager.startDeviceMotionUpdates(to: .main) { [weak self] data, _ in
            guard let self = self, let data = data else { return }
            self.handleMotion(data)
        }
        if settingsObserver == nil {
            settingsObserver = NotificationCenter.default.addObserver(forName: UserDefaults.didChangeNotification,
                                                                      object: nil,
                                                                      queue: .main) { [weak self] _ in
                Task { @MainActor in
                    self?.settingsDidChange()
                }
            }
        }
    }

    func stop() {
        motionManager.stopDeviceMotionUpdates()
        isMonitoring = false
        resetState()
        if let settingsObserver = settingsObserver {
            NotificationCenter.default.removeObserver(settingsObserver)
            self.settingsObserver = nil
        }
    }

    private func settingsDidChange() {
        guard isMonitoring else { return }
        motionManager.stopDeviceMotionUpdates()
        motionManager.deviceMotionUpdateInterval = AppSettings.motionUpdateIntervalSeconds
        motionManager.startDeviceMotionUpdates(to: .main) { [weak self] data, _ in
            guard let self = self, let data = data else { return }
            self.handleMotion(data)
        }
    }

    private func handleMotion(_ motion: CMDeviceMotion) {
        let magnitude = abs(motion.userAcceleration.x) +
            abs(motion.userAcceleration.y) +
            abs(motion.userAcceleration.z)

        if magnitude > movementThreshold {
            lastMovementTime = Date()
        }

        let stillnessDuration = Date().timeIntervalSince(lastMovementTime)
        stillnessMinutes = stillnessDuration / 60
        isStillForSleep = stillnessDuration >= AppSettings.stillnessMinutes * 60
    }

    private func resetState() {
        lastMovementTime = Date()
        stillnessMinutes = 0
        isStillForSleep = false
    }
}
