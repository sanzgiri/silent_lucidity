import CoreMotion
import HealthKit
import WatchKit

class DreamDetector: ObservableObject {
    private let motionManager = CMMotionManager()
    
    @Published var isDreamingCandidate = false
    @Published var lastTriggerTime: Date?
    @Published var debugLog: String = "Ready"
    @Published var isMonitoring = false
    @Published var currentHR: Double = 0.0
    @Published var hrVolatility: Double = 0.0
    
    private var lastMovementTime: Date = Date()
    private var sleepOnsetTime: Date?
    
    // Heart Rate Buffer for Volatility (last 5 mins)
    private var heartRateBuffer: [(bpm: Double, time: Date)] = []
    private let bufferWindow: TimeInterval = 5 * 60
    
    // Configurable Thresholds
    private let movementThreshold = 0.03
    private let remOnsetMinMinutes: Double = 80 // Start checking earlier
    private let cooldownMinutes: Double = 20
    private let wakefulnessHRThreshold: Double = 85.0 // Abort if HR > 85 (likely awake)
    private let volatilityThreshold: Double = 5.0 // Standard Deviation > 5.0 indicates variability
    
    func startMonitoring() {
        guard motionManager.isDeviceMotionAvailable else {
            debugLog = "Motion not available"
            return
        }
        
        isMonitoring = true
        motionManager.deviceMotionUpdateInterval = 1.0
        motionManager.startDeviceMotionUpdates(to: .main) { [weak self] (data, error) in
            guard let self = self, let data = data else { return }
            self.analyzeMotion(motion: data)
        }
        debugLog = "Monitoring started"
    }
    
    func stopMonitoring() {
        motionManager.stopDeviceMotionUpdates()
        isMonitoring = false
        debugLog = "Monitoring stopped"
    }
    
    // Called by SessionManager
    func processHeartRate(bpm: Double, date: Date) {
        currentHR = bpm
        
        // Add to buffer
        heartRateBuffer.append((bpm, date))
        
        // Prune old samples
        let cutoff = Date().addingTimeInterval(-bufferWindow)
        heartRateBuffer = heartRateBuffer.filter { $0.time > cutoff }
        
        // Calculate Volatility (Standard Deviation)
        calculateVolatility()
    }
    
    private func calculateVolatility() {
        guard heartRateBuffer.count > 10 else {
            hrVolatility = 0.0
            return
        }
        
        let bpms = heartRateBuffer.map { $0.bpm }
        let mean = bpms.reduce(0, +) / Double(bpms.count)
        let sumOfSquaredDiffs = bpms.map { pow($0 - mean, 2) }.reduce(0, +)
        hrVolatility = sqrt(sumOfSquaredDiffs / Double(bpms.count))
    }
    
    private func analyzeMotion(motion: CMDeviceMotion) {
        // Calculate magnitude of acceleration
        let magnitude = abs(motion.userAcceleration.x) +
                        abs(motion.userAcceleration.y) +
                        abs(motion.userAcceleration.z)
        
        if magnitude > movementThreshold {
            // User moved; reset stillness timer
            lastMovementTime = Date()
        } else {
            // User is still. Check duration.
            let stillnessDuration = Date().timeIntervalSince(lastMovementTime)
            
            // If still for > 15m, assume asleep
            if stillnessDuration > 15 * 60 {
                if sleepOnsetTime == nil {
                    sleepOnsetTime = Date()
                    debugLog = "Sleep Onset Detected"
                }
                
                checkREM()
            }
        }
    }
    
    private func checkREM() {
        guard let onset = sleepOnsetTime else { return }
        
        let minutesAsleep = Date().timeIntervalSince(onset) / 60
        
        // 1. Time Gating: Are we in a likely REM window?
        // REM cycles are approx every 90 mins: ~90, ~180, ~270, ~360
        // We open a 20-minute window around these peaks.
        let cycleDuration = 90.0
        let windowWidth = 20.0
        let cyclePosition = minutesAsleep.truncatingRemainder(dividingBy: cycleDuration)
        
        // Check if we are close to a multiple of 90 (e.g., within +/- 10 mins of 90, 180...)
        // Actually, REM gets longer as night goes on.
        // Simplified Logic: Check if we are past the first deep sleep (80m)
        if minutesAsleep < remOnsetMinMinutes { return }
        
        // 2. Wakefulness Guard
        if currentHR > wakefulnessHRThreshold {
            // Likely awake or restless
            return
        }
        
        // 3. Cooldown Check
        if let last = lastTriggerTime, Date().timeIntervalSince(last) < cooldownMinutes * 60 {
            return
        }
        
        // 4. Volatility Check (The Core Heuristic)
        // High Volatility + Stillness = REM
        if hrVolatility > volatilityThreshold {
             triggerRealityCheck()
        }
    }
    
    private func triggerRealityCheck() {
        // Read settings (using UserDefaults directly since we are not in a View)
        let intensity = UserDefaults.standard.string(forKey: "hapticIntensity") ?? "Medium"
        let repeats = UserDefaults.standard.integer(forKey: "hapticRepeats")
        let actualRepeats = repeats == 0 ? 2 : repeats // Default to 2 if not set
        
        let device = WKInterfaceDevice.current()
        
        debugLog = "Triggering: \(intensity) x\(actualRepeats)"
        
        // Define the "Tap" based on intensity
        let playTap = {
            switch intensity {
            case "Low":
                device.play(.click)
            case "High":
                device.play(.start)
            default: // Medium
                device.play(.directionUp) // A tactile "nudge"
            }
        }
        
        // Recursive function to play the pattern
        func playPattern(count: Int) {
            guard count > 0 else {
                // Done
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    self.isDreamingCandidate = false
                }
                return
            }
            
            // Double Tap
            playTap()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                playTap()
                
                // Wait before next pair
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    playPattern(count: count - 1)
                }
            }
        }
        
        lastTriggerTime = Date()
        isDreamingCandidate = true
        
        // Start the sequence
        playPattern(count: actualRepeats)
    }
}
