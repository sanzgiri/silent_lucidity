# Lucid Dreaming Induction App Plan

Here is the comprehensive implementation plan for building a Lucid Dreaming induction app for Apple Watch (watchOS) and Amazfit (Zepp OS), synthesized from the Council's analysis.

## Executive Summary

**Is it possible?** Yes, but with a critical technical caveat. Neither watchOS nor Zepp OS exposes their native "REM Sleep" stage labels to third-party developers in real-time. Their systems calculate sleep stages in batches or after the sleep session concludes.

**The Solution:** You cannot simply "listen" for a system event like `UserEnteredREM`. Instead, you must build a custom **Real-Time Heuristic Engine**. Your app must run continuously in the background, read raw sensor data (Heart Rate + Accelerometer), and estimate when REM is likely occurring based on biological markers (Time + Stillness + Heart Rate Variability).

**Platform Recommendation:** Start with **Apple Watch (watchOS)**. While battery life is lower, the developer ecosystem (Xcode/Swift), sensor accuracy, and documentation for keeping apps alive in the background are far superior to Zepp OS.

---

## Part 1: The Core Algorithm (Platform Agnostic)

Since you must detect REM manually, you will implement a probabilistic logic flow. REM sleep typically exhibits **Sleep Atonia** (muscle paralysis) combined with **Autonomic Activation** (elevated/variable heart rate and breathing).

### The Logic Flow

1.  **Sleep Onset Detection:** Monitor for >15 minutes of very low movement.
2.  **Time Gating:** REM cycles typically begin ~80–100 minutes after sleep onset. Your app should ignore the first 60–90 minutes to avoid waking the user during Deep Sleep.
3.  **The "REM Candidate" Window:** Open detection windows at 90-minute intervals (e.g., at 1.5h, 3h, 4.5h, 6h).
4.  **Real-Time Trigger Conditions:** Inside a window, trigger haptics if:
    *   Motion is near zero (User is paralyzed/atonia).
    *   Heart Rate is variable (HRV increases or HR rises slightly above resting baseline).
5.  **Cool-down:** After a trigger, wait 15–30 minutes before triggering again to prevent repeatedly waking the user.

---

## Part 2: Apple Watch Implementation Plan

This is the recommended path. You will use Swift and SwiftUI.

### 1. Project Setup & Permissions
*   **Capabilities:** In Xcode, enable HealthKit (for Heart Rate) and Background Modes (specifically Workout Processing).
*   **Privacy IDs:** Add `NSHealthShareUsageDescription` and `NSHealthUpdateUsageDescription` to your `Info.plist`.

### 2. The "Keep-Alive" Mechanism
The biggest technical hurdle is iOS killing your app to save battery. To prevent this, you must run an `HKWorkoutSession`. This tells the watch, "I am tracking a workout," which keeps the CPU and sensors active overnight.

```swift
import HealthKit

class SessionManager: NSObject, ObservableObject {
    let healthStore = HKHealthStore()
    var session: HKWorkoutSession?
    var builder: HKLiveWorkoutBuilder?

    func startOvernightSession() {
        let config = HKWorkoutConfiguration()
        config.activityType = .mindAndBody // Low conceptual intensity, keeps sensors on
        config.locationType = .indoor

        do {
            session = try HKWorkoutSession(healthStore: healthStore, configuration: config)
            builder = session?.associatedWorkoutBuilder()
            builder?.dataSource = HKLiveWorkoutDataSource(healthStore: healthStore, workoutConfiguration: config)
            
            session?.startActivity(with: Date())
            builder?.beginCollection(withStart: Date()) { (success, error) in
                // App is now running in high-priority background mode
            }
        } catch {
            print("Failed to start session: \(error)")
        }
    }
}
```

### 3. Data Ingestion (sensors)
You need two streams: Motion (CoreMotion) and Heart Rate (HealthKit).

*   **Motion:** Use `CMMotionManager`. Set a low update interval (e.g., 1.0 second) to save battery.
*   **Heart Rate:** Configure your `HKLiveWorkoutBuilder` to collect `HKQuantityType.heartRate`.

### 4. The Detection Loop
This logic runs every time you get new sensor data (e.g., every minute).

```swift
import CoreMotion

class DreamDetector {
    let motionManager = CMMotionManager()
    var lastMovementTime: Date = Date()
    var sleepOnsetTime: Date?
    
    // Configurable Thresholds
    let movementThreshold = 0.03
    let remOnsetMinMinutes: Double = 90
    
    func startMonitoring() {
        motionManager.deviceMotionUpdateInterval = 1.0
        motionManager.startDeviceMotionUpdates(to: .main) { [weak self] (data, error) in
            guard let self = self, let data = data else { return }
            self.analyze(motion: data)
        }
    }
    
    func analyze(motion: CMDeviceMotion) {
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
            if stillnessDuration > 15 * 60 && sleepOnsetTime == nil {
                sleepOnsetTime = Date()
            }
            
            // Check if we are in a REM timing window
            if let onset = sleepOnsetTime {
                let minutesAsleep = Date().timeIntervalSince(onset) / 60
                
                // Simple heuristic: Are we deep into the night?
                if minutesAsleep > remOnsetMinMinutes {
                    // Refine this with HR data: IF HR > Resting + 5bpm THEN Fire
                    triggerRealityCheck()
                }
            }
        }
    }
    
    func triggerRealityCheck() {
        // Debounce logic required here to prevent rapid-firing
        WKInterfaceDevice.current().play(.click) // Subtle 'toc' haptic
    }
}
```

---

## Part 3: Zepp OS (Amazfit) Implementation Plan

Development for Zepp OS is done using JavaScript/TypeScript. The ecosystem is more restrictive regarding long-running background tasks.

*   **Environment:** Set up the Zepp OS CLI and simulator.
*   **App Type:** You must configure your app in `app.json` to have permission to run in the background. Look for the "page" config vs "service" config.
*   **Sensor Access:** Use the `@zeppos/sensor` library.

```javascript
import { HeartRate, Accelerometer } from '@zeppos/sensor'

const hr = new HeartRate()
const acc = new Accelerometer()

// Start sensors
hr.start()
acc.start()

// Polling Logic
setInterval(() => {
   const hrValue = hr.getCurrent()
   const accValue = acc.getCurrent() // Check x, y, z
   
   // Implement same heuristic logic as Apple Watch above
   // Zepp uses a standard magnitude check for motion
   if (isStill && timeIsRight) {
       triggerVibration()
   }
}, 60000) // Check every minute
```

**Haptics:** Use the Vibrator module (`@zeppos/sensor`) to trigger custom patterns. Note that stringent battery management on Amazfit devices may kill your app if it consumes too many resources.

---

## Part 4: Testing & Iteration Strategy

Since you are building an estimation engine, you will need to "tune" it to your body.

### Data Collection Phase (Weeks 1-2):
1.  Build the app to log only. Do not vibrate.
2.  Log timestamps of when your algorithm would have fired.
3.  Compare these timestamps the next morning against the native Sleep Analytics (Apple Health) to see if your predictions aligned with actual REM stages.

### Tuning:
*   If you are triggering during Deep Sleep (early night), increase your `remOnsetMinMinutes`.
*   If you find you are waking up, reduce haptic intensity.

### Deployment:
On Apple Watch, you can run the app on your own device indefinitely with a paid Developer Account ($99/yr). With a free account, you must reinstall every 7 days.

---

## Summary Checklist

- [ ] Select Platform: Apple Watch Series 10.
- [ ] Create App: Xcode -> WatchOS App.
- [ ] Permissions: Enable HealthKit & Background Processing.
- [ ] Keep Alive: Implement HKWorkoutSession.
- [ ] Algorithm: Implement Stillness + Time Gating heuristic.
- [ ] Feedback: Implement WKInterfaceDevice haptics.
- [ ] Validate: Compare logs with Apple Health sleep stages.
