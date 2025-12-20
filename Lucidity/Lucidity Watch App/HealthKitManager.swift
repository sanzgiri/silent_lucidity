import Foundation
import HealthKit

@available(watchOS 11, *)
/// HealthKitManager is a singleton ObservableObject designed for use on watchOS to monitor sleep and heart rate data.
/// It requests authorization to read sleep analysis and heart rate data, monitors relevant changes, and attempts to approximate probable REM sleep windows.
/// 
/// IMPORTANT:
/// - This implementation uses heuristics and limited HealthKit data to estimate REM windows.
/// - It is intended for wellness and general awareness only, NOT for medical diagnosis or treatment.
/// - Sleep stage data available from HealthKit is limited; detailed sleep staging (like polysomnography) is not available.
/// - Heart rate variability (HRV) data is not incorporated here; HRV would improve REM detection.
/// - Changes to published properties are dispatched to the main thread for UI safety.
/// - NotificationCenter posts "REMWindowDidChange" notifications with ["isREM": Bool] in userInfo whenever REM evaluation updates.
final class HealthKitManager: ObservableObject {
    
    static let shared = HealthKitManager()
    
    let healthStore = HKHealthStore()
    
    /// Indicates whether the app is authorized to read sleep analysis and heart rate data.
    @Published private(set) var isAuthorized: Bool = false
    
    /// A descriptive string representing the last detected sleep window suspected to be REM.
    @Published private(set) var lastSleepWindowDescription: String = "No REM window detected"
    
    /// The most recent heart rate sample value in beats per minute.
    @Published private(set) var lastHeartRate: Double? = nil
    
    private var sleepObserverQuery: HKObserverQuery?
    private var heartRateAnchoredQuery: HKAnchoredObjectQuery?
    private var heartRateAnchor: HKQueryAnchor?
    
    private var latestSleepSamples: [HKCategorySample] = []
    private var latestHeartRateSamples: [HKQuantitySample] = []
    
    private let notificationName = Notification.Name("REMWindowDidChange")
    
    private init() {}
    
    /// Requests authorization from the user to read sleep analysis and heart rate data.
    /// - Throws an error if authorization request fails.
    func requestAuthorization() async throws {
        guard HKHealthStore.isHealthDataAvailable() else {
            DispatchQueue.main.async {
                self.isAuthorized = false
            }
            return
        }
        
        let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!
        let heartRateType = HKObjectType.quantityType(forIdentifier: .heartRate)!
        
        let readTypes: Set<HKObjectType> = [sleepType, heartRateType]
        let writeTypes: Set<HKSampleType> = []
        
        try await withCheckedThrowingContinuation { continuation in
            healthStore.requestAuthorization(toShare: writeTypes, read: readTypes) { success, error in
                DispatchQueue.main.async {
                    self.isAuthorized = success
                }
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: ())
                }
            }
        }
    }
    
    /// Starts monitoring sleep and heart rate data.
    /// Sets up an observer query for sleep analysis and an anchored object query for heart rate, updating the published properties accordingly.
    func startSleepMonitoring() {
        guard isAuthorized else { return }
        
        let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!
        let heartRateType = HKObjectType.quantityType(forIdentifier: .heartRate)!
        
        // Sleep observer query to get notified on sleep data changes
        sleepObserverQuery = HKObserverQuery(sampleType: sleepType, predicate: nil) { [weak self] _, completionHandler, error in
            guard let self = self else {
                completionHandler()
                return
            }
            if error != nil {
                completionHandler()
                return
            }
            Task {
                await self.fetchLatestSleepSamples()
                await self.evaluateAndPublish()
                completionHandler()
            }
        }
        
        if let sleepObserverQuery = sleepObserverQuery {
            healthStore.execute(sleepObserverQuery)
        }
        
        // Heart rate anchored query for updates with 1-minute interval on recent samples (last 8 hours)
        let eightHoursAgo = Date().addingTimeInterval(-8 * 60 * 60)
        let predicate = HKQuery.predicateForSamples(withStart: eightHoursAgo, end: Date(), options: .strictStartDate)
        
        // Initial anchor is nil to get all existing samples initially
        heartRateAnchoredQuery = HKAnchoredObjectQuery(type: heartRateType, predicate: predicate, anchor: heartRateAnchor, limit: HKObjectQueryNoLimit) { [weak self] _, samplesOrNil, deletedObjectsOrNil, newAnchor, errorOrNil in
            guard let self = self else { return }
            if let error = errorOrNil {
                // Ignore error, but could handle if needed
                return
            }
            
            if let samples = samplesOrNil as? [HKQuantitySample] {
                self.latestHeartRateSamples.append(contentsOf: samples)
                self.latestHeartRateSamples.sort(by: { $0.startDate < $1.startDate })
                
                self.heartRateAnchor = newAnchor
                Task {
                    await self.evaluateAndPublish()
                }
            }
        }
        
        if let heartRateAnchoredQuery = heartRateAnchoredQuery {
            heartRateAnchoredQuery.updateHandler = { [weak self] _, samplesOrNil, deletedObjectsOrNil, newAnchor, errorOrNil in
                guard let self = self else { return }
                if let error = errorOrNil {
                    return
                }
                if let samples = samplesOrNil as? [HKQuantitySample] {
                    self.latestHeartRateSamples.append(contentsOf: samples)
                    self.latestHeartRateSamples.sort(by: { $0.startDate < $1.startDate })
                    self.heartRateAnchor = newAnchor
                    Task {
                        await self.evaluateAndPublish()
                    }
                }
            }
            healthStore.execute(heartRateAnchoredQuery)
        }
        
        // Initial fetch trigger
        Task {
            await fetchLatestSleepSamples()
            await evaluateAndPublish()
        }
    }
    
    /// Stops monitoring sleep and heart rate data by invalidating queries.
    func stopSleepMonitoring() {
        if let sleepObserverQuery = sleepObserverQuery {
            healthStore.stop(sleepObserverQuery)
            self.sleepObserverQuery = nil
        }
        if let heartRateAnchoredQuery = heartRateAnchoredQuery {
            healthStore.stop(heartRateAnchoredQuery)
            self.heartRateAnchoredQuery = nil
            self.heartRateAnchor = nil
        }
        
        DispatchQueue.main.async {
            self.lastSleepWindowDescription = "No REM window detected"
            self.lastHeartRate = nil
        }
    }
    
    /// Convenience function to fetch the most recent sleep sample start date of "inBed" or "asleep".
    /// Returns nil if no suitable samples found.
    func latestSleepStartDate() async -> Date? {
        let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
        let predicate = HKQuery.predicateForSamples(withStart: nil, end: Date(), options: .strictEndDate)
        
        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(sampleType: sleepType, predicate: predicate, limit: 100, sortDescriptors: [sortDescriptor]) { _, samplesOrNil, errorOrNil in
                defer { continuation.resume(returning: nil) }
                guard errorOrNil == nil,
                      let samples = samplesOrNil as? [HKCategorySample], !samples.isEmpty else {
                    return
                }
                // Look for recent sample with value inBed or asleep
                for sample in samples {
                    if sample.value == HKCategoryValueSleepAnalysis.inBed.rawValue ||
                        sample.value == HKCategoryValueSleepAnalysis.asleep.rawValue {
                        continuation.resume(returning: sample.startDate)
                        return
                    }
                }
            }
            healthStore.execute(query)
        }
    }
    
    // MARK: - Private methods
    
    private func fetchLatestSleepSamples() async {
        let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!
        let eightHoursAgo = Date().addingTimeInterval(-8 * 60 * 60)
        let predicate = HKQuery.predicateForSamples(withStart: eightHoursAgo, end: Date(), options: .strictStartDate)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)
        
        await withCheckedContinuation { continuation in
            let query = HKSampleQuery(sampleType: sleepType, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: [sortDescriptor]) { [weak self] _, samplesOrNil, errorOrNil in
                guard let self = self else {
                    continuation.resume()
                    return
                }
                if let error = errorOrNil {
                    // On error, clear cached samples
                    self.latestSleepSamples = []
                    continuation.resume()
                    return
                }
                if let samples = samplesOrNil as? [HKCategorySample] {
                    self.latestSleepSamples = samples
                } else {
                    self.latestSleepSamples = []
                }
                continuation.resume()
            }
            healthStore.execute(query)
        }
    }
    
    /// Evaluates probable REM sleep window based on sleep samples and heart rate samples.
    ///
    /// Heuristic used:
    /// - If detailed sleep stages with .asleepREM available, use that.
    /// - Else assume typical sleep cycles ~90 minutes from sleep start.
    /// - Detect heart rate between 45 and 70 bpm as potential REM indication.
    /// 
    /// Returns tuple of (isREM: Bool, description: String) for the last probable REM window.
    private func evaluateProbableREM(using sleepSamples: [HKCategorySample], and heartRateSamples: [HKQuantitySample]) -> (Bool, String) {
        // 1. Find the last sleep start date of inBed or asleep
        guard let sleepStartSample = sleepSamples.first(where: {
            $0.value == HKCategoryValueSleepAnalysis.inBed.rawValue ||
            $0.value == HKCategoryValueSleepAnalysis.asleep.rawValue
        }) else {
            return (false, "No sleep start detected")
        }
        let sleepStartDate = sleepStartSample.startDate
        
        // 2. Look for REM sleep samples if available
        if let remSample = sleepSamples.last(where: { $0.value == HKCategoryValueSleepAnalysis.asleepREM.rawValue }) {
            // We have explicit REM sample - check recent heart rate near REM sample time
            let remStart = remSample.startDate
            let remEnd = remSample.endDate
            
            // Find heart rate samples overlapping with REM window
            let hrSamplesDuringREM = heartRateSamples.filter { sample in
                sample.startDate <= remEnd && sample.endDate >= remStart
            }
            // Check if any heart rate during REM window is between 45 and 70 bpm
            let isHeartRateInREMRange = hrSamplesDuringREM.contains { sample in
                let bpm = sample.quantity.doubleValue(for: HKUnit.count().unitDivided(by: HKUnit.minute()))
                return bpm >= 45 && bpm <= 70
            }
            if isHeartRateInREMRange {
                let formatter = DateIntervalFormatter()
                formatter.dateStyle = .none
                formatter.timeStyle = .short
                let intervalString = formatter.string(from: remStart, to: remEnd)
                return (true, "Detected REM window: \(intervalString)")
            } else {
                return (false, "REM stage detected but heart rate not in REM range")
            }
        }
        
        // 3. If no explicit REM samples, approximate cycles every ~90 minutes from sleep start date.
        // We'll check the last cycle window and heart rate in that window.
        let now = Date()
        let interval: TimeInterval = 90 * 60
        
        let elapsedTime = now.timeIntervalSince(sleepStartDate)
        guard elapsedTime > 0 else {
            return (false, "Sleep start in future or no elapsed time")
        }
        
        // Number of full cycles elapsed
        let cyclesElapsed = Int(elapsedTime / interval)
        // Last cycle start
        let lastCycleStart = sleepStartDate.addingTimeInterval(TimeInterval(cyclesElapsed) * interval)
        // Assume REM in last 20 minutes of cycle
        let remWindowStart = lastCycleStart.addingTimeInterval(interval - 20 * 60)
        let remWindowEnd = lastCycleStart.addingTimeInterval(interval)
        
        // Check heart rate samples in this window
        let hrSamplesInWindow = heartRateSamples.filter { sample in
            sample.startDate >= remWindowStart && sample.endDate <= remWindowEnd
        }
        
        let isHeartRateInREMRange = hrSamplesInWindow.contains { sample in
            let bpm = sample.quantity.doubleValue(for: HKUnit.count().unitDivided(by: HKUnit.minute()))
            return bpm >= 45 && bpm <= 70
        }
        
        let formatter = DateIntervalFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        let intervalString = formatter.string(from: remWindowStart, to: remWindowEnd)
        
        if isHeartRateInREMRange {
            return (true, "Approximated REM window: \(intervalString)")
        } else {
            return (false, "No REM detected in approximated window: \(intervalString)")
        }
    }
    
    /// Fetches latest samples and evaluates REM windows, updating published properties and posting notifications.
    private func evaluateAndPublish() async {
        let (isREM, description) = evaluateProbableREM(using: latestSleepSamples, and: latestHeartRateSamples)
        
        // Last heart rate sample for UI
        let lastHRBPM: Double? = latestHeartRateSamples.last.map {
            $0.quantity.doubleValue(for: HKUnit.count().unitDivided(by: HKUnit.minute()))
        }
        
        DispatchQueue.main.async {
            self.lastSleepWindowDescription = description
            self.lastHeartRate = lastHRBPM
        }
        
        NotificationCenter.default.post(name: notificationName, object: nil, userInfo: ["isREM": isREM])
    }
}
