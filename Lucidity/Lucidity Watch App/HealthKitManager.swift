import Foundation
import HealthKit
import Combine

@MainActor
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
    @Published var isAuthorized: Bool = false
    
    /// Latest detected sleep start date (inBed or asleep)
    @Published var latestSleepStart: Date? = nil
    
    /// Latest detected sleep end date (inBed or asleep)
    @Published var latestSleepEnd: Date? = nil
    
    /// The most recent heart rate sample value in beats per minute.
    @Published var latestHeartRate: Double? = nil
    
    /// The most recent sleep window description for REM detection.
    @Published private(set) var lastSleepWindowDescription: String = "No REM window detected"

    private var sleepObserverQuery: HKObserverQuery?
    private var heartRateAnchoredQuery: HKAnchoredObjectQuery?
    private var heartRateAnchor: HKQueryAnchor?
    
    private var latestSleepSamples: [HKCategorySample] = []
    private var latestHeartRateSamples: [HKQuantitySample] = []
    
    static let remWindowDidChangeNotification = Notification.Name("REMWindowDidChange")

    // Public default initializer as requested
    init() {}

    /// Completion-style requestAuthorization method to match ContentView usage
    func requestAuthorization(completion: @escaping (Bool, Error?) -> Void) {
        print("Requesting HealthKit authorization...")
        guard HKHealthStore.isHealthDataAvailable() else {
            print("HealthKit not available on this device")
            let error = NSError(domain: HKErrorDomain,
                                code: HKError.Code.errorHealthDataUnavailable.rawValue,
                                userInfo: [NSLocalizedDescriptionKey: "Health data is not available on this device."])
            Task { @MainActor in
                self.isAuthorized = false
                completion(false, error)
            }
            return
        }
        let toShare: Set<HKSampleType> = []
        guard let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis),
              let heartRateType = HKObjectType.quantityType(forIdentifier: .heartRate) else {
            print("Failed to create HealthKit object types")
            Task { @MainActor in
                self.isAuthorized = false
                completion(false, nil)
            }
            return
        }
        let toRead: Set<HKObjectType> = [
            sleepType,
            heartRateType
        ]
        healthStore.requestAuthorization(toShare: toShare, read: toRead) { [weak self] success, error in
            print("HealthKit authorization result: success=\(success), error=\(String(describing: error))")
            Task { @MainActor in
                self?.isAuthorized = success
                completion(success, error)
            }
        }
    }
    
    @available(*, deprecated, message: "Use requestAuthorization(completion:) with (Bool, Error?)")
    func requestAuthorization(_ completion: @escaping () -> Void) {
        self.requestAuthorization { _, _ in
            completion()
        }
    }
    
    @available(*, deprecated, message: "Use requestAuthorization(completion:) with (Bool, Error?)")
    func requestAuthorization(_ completion: @escaping (Bool) -> Void) {
        self.requestAuthorization { success, _ in
            completion(success)
        }
    }

    /// Starts monitoring sleep and heart rate data.
    /// Sets up an observer query for sleep analysis and an anchored object query for heart rate, updating the published properties accordingly.
    func startSleepMonitoring() {
        print("Starting sleep monitoring - authorized: \(isAuthorized)")
        guard isAuthorized else { 
            print("HealthKit not authorized, cannot start monitoring")
            return 
        }
        
        guard let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else { 
            print("Unable to create sleep analysis type")
            return 
        }
        guard let heartRateType = HKObjectType.quantityType(forIdentifier: .heartRate) else { 
            print("Unable to create heart rate type")
            return 
        }
        
        print("Starting sleep monitoring with proper authorization...")
        
        // Sleep observer query to get notified on sleep data changes
        sleepObserverQuery = HKObserverQuery(sampleType: sleepType, predicate: nil) { [weak self] _, completionHandler, error in
            guard let self = self else {
                completionHandler()
                return
            }
            if let error = error {
                print("Error in sleep observer query: \(error)")
                completionHandler()
                return
            }
            print("Sleep observer query triggered")
            Task {
                await self.fetchLatestSleepSamples()
                await self.evaluateAndPublish()
                completionHandler()
            }
        }
        
        if let sleepObserverQuery = sleepObserverQuery {
            healthStore.execute(sleepObserverQuery)
            print("Sleep observer query started")
        }
        
        // Heart rate anchored query for updates with 1-minute interval on recent samples (last 8 hours)
        let eightHoursAgo = Date().addingTimeInterval(-8 * 60 * 60)
        let predicate = HKQuery.predicateForSamples(withStart: eightHoursAgo, end: nil, options: .strictStartDate)
        
        // Initial anchor is nil to get all existing samples initially
        heartRateAnchoredQuery = HKAnchoredObjectQuery(type: heartRateType, predicate: predicate, anchor: heartRateAnchor, limit: HKObjectQueryNoLimit) { [weak self] _, samplesOrNil, _, newAnchor, errorOrNil in
            guard let self = self else { return }
            if let error = errorOrNil {
                print("Error in heart rate query: \(error)")
                return
            }
            
            if let samples = samplesOrNil as? [HKQuantitySample] {
                print("Received \(samples.count) heart rate samples")
                Task { @MainActor in
                    self.latestHeartRateSamples.append(contentsOf: samples)
                    self.latestHeartRateSamples.sort(by: { $0.startDate < $1.startDate })
                    
                    // Keep only last 8 hours of samples to prevent unbounded growth
                    let eightHoursAgo = Date().addingTimeInterval(-8 * 60 * 60)
                    self.latestHeartRateSamples = self.latestHeartRateSamples.filter { $0.startDate >= eightHoursAgo }
                    
                    self.heartRateAnchor = newAnchor
                    await self.evaluateAndPublish()
                }
            }
        }
        
        if let heartRateAnchoredQuery = heartRateAnchoredQuery {
            heartRateAnchoredQuery.updateHandler = { [weak self] _, samplesOrNil, _, newAnchor, errorOrNil in
                guard let self = self else { return }
                if let error = errorOrNil {
                    print("Error in heart rate update: \(error)")
                    return
                }
                if let samples = samplesOrNil as? [HKQuantitySample] {
                    print("Heart rate update: \(samples.count) new samples")
                    Task { @MainActor in
                        self.latestHeartRateSamples.append(contentsOf: samples)
                        self.latestHeartRateSamples.sort(by: { $0.startDate < $1.startDate })
                        
                        // Keep only last 8 hours of samples to prevent unbounded growth
                        let eightHoursAgo = Date().addingTimeInterval(-8 * 60 * 60)
                        self.latestHeartRateSamples = self.latestHeartRateSamples.filter { $0.startDate >= eightHoursAgo }
                        
                        self.heartRateAnchor = newAnchor
                        await self.evaluateAndPublish()
                    }
                }
            }
            healthStore.execute(heartRateAnchoredQuery)
            print("Heart rate anchored query started")
        }
        
        // Initial fetch trigger
        Task {
            print("Starting initial data fetch...")
            await fetchLatestSleepSamples()
            await evaluateAndPublish()
            print("Initial data fetch completed")
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
        
        // Clear cached data
        self.latestSleepSamples.removeAll()
        self.latestHeartRateSamples.removeAll()
        
        self.lastSleepWindowDescription = "No REM window detected"
        self.latestHeartRate = nil
    }

    /// Convenience function to fetch the most recent sleep sample start date of "inBed" or "asleep".
    /// Returns nil if no suitable samples found.
    func latestSleepStartDate() async -> Date? {
        guard let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else { return nil }
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)
        let lookbackStart = Date().addingTimeInterval(-sleepSampleLookback)
        let predicate = HKQuery.predicateForSamples(withStart: lookbackStart, end: Date(), options: .strictStartDate)
        
        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(sampleType: sleepType, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: [sortDescriptor]) { [weak self] _, samplesOrNil, errorOrNil in
                guard let self = self else {
                    continuation.resume(returning: nil)
                    return
                }
                if let error = errorOrNil {
                    print("Error fetching sleep start date: \(error)")
                    continuation.resume(returning: nil)
                    return
                }
                guard let samples = samplesOrNil as? [HKCategorySample], !samples.isEmpty else {
                    continuation.resume(returning: nil)
                    return
                }
                Task { @MainActor in
                    let window = self.sleepSessionWindow(from: samples)
                    continuation.resume(returning: window?.start)
                }
            }
            healthStore.execute(query)
        }
    }
    
    /// Convenience function to fetch the most recent sleep sample end date of "inBed" or "asleep".
    /// Returns nil if no suitable samples found.
    func latestSleepEndDate() async -> Date? {
        guard let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else { return nil }
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)
        let lookbackStart = Date().addingTimeInterval(-sleepSampleLookback)
        let predicate = HKQuery.predicateForSamples(withStart: lookbackStart, end: Date(), options: .strictStartDate)
        
        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(sampleType: sleepType, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: [sortDescriptor]) { [weak self] _, samplesOrNil, errorOrNil in
                guard let self = self else {
                    continuation.resume(returning: nil)
                    return
                }
                if let error = errorOrNil {
                    print("Error fetching sleep end date: \(error)")
                    continuation.resume(returning: nil)
                    return
                }
                guard let samples = samplesOrNil as? [HKCategorySample], !samples.isEmpty else {
                    continuation.resume(returning: nil)
                    return
                }
                Task { @MainActor in
                    let window = self.sleepSessionWindow(from: samples)
                    continuation.resume(returning: window?.end)
                }
            }
            healthStore.execute(query)
        }
    }

    /// Fetch the latest sleep start date and update published property
    func fetchLatestSleepStart() {
        Task {
            let startDate = await latestSleepStartDate()
            await MainActor.run {
                self.latestSleepStart = startDate
            }
        }
    }
    
    /// Fetch the latest sleep start and end dates and update published properties
    func fetchLatestSleepData() {
        Task {
            let startDate = await latestSleepStartDate()
            let endDate = await latestSleepEndDate()
            await MainActor.run {
                self.latestSleepStart = startDate 
                self.latestSleepEnd = endDate
            }
        }
    }

    // MARK: - Private methods

    private func fetchLatestSleepSamples() async {
        guard let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else { return }
        let lookbackStart = Date().addingTimeInterval(-sleepSampleLookback)
        let predicate = HKQuery.predicateForSamples(withStart: lookbackStart, end: Date(), options: .strictStartDate)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)
        
        await withCheckedContinuation { continuation in
            let query = HKSampleQuery(sampleType: sleepType, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: [sortDescriptor]) { [weak self] _, samplesOrNil, errorOrNil in
                guard let self = self else {
                    continuation.resume()
                    return
                }
                if let error = errorOrNil {
                    print("Error fetching sleep samples: \(error)")
                    Task { @MainActor in
                        self.latestSleepSamples = []
                        continuation.resume()
                    }
                    return
                }
                Task { @MainActor in
                    if let samples = samplesOrNil as? [HKCategorySample] {
                        self.latestSleepSamples = samples
                    } else {
                        self.latestSleepSamples = []
                    }
                    continuation.resume()
                }
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
        // 1. Find the most recent sleep session window
        guard let sleepWindow = sleepSessionWindow(from: sleepSamples) else {
            return (false, "No sleep start detected")
        }
        let sleepStartDate = sleepWindow.start
        
        // 2. Look for REM sleep samples if available
        if let remSample = sleepSamples.last(where: { isREMValue($0.value) && $0.endDate >= sleepWindow.start && $0.startDate <= sleepWindow.end }) {
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
    @MainActor
    private func evaluateAndPublish() async {
        let (isREM, description) = evaluateProbableREM(using: latestSleepSamples, and: latestHeartRateSamples)
        
        // Last heart rate sample for UI
        let lastHRBPM: Double? = latestHeartRateSamples.last.map {
            $0.quantity.doubleValue(for: HKUnit.count().unitDivided(by: HKUnit.minute()))
        }
        
        self.lastSleepWindowDescription = description
        self.latestHeartRate = lastHRBPM
        
        NotificationCenter.default.post(name: HealthKitManager.remWindowDidChangeNotification, object: nil, userInfo: ["isREM": isREM])
    }
    
    /// Starts the monitoring of health data (stub or reuse existing startSleepMonitoring)
    func startMonitoring() {
        if !isAuthorized { return }
        startSleepMonitoring()
    }
    
    /// Stops monitoring of health data (stub or reuse existing stopSleepMonitoring)
    func stopMonitoring() {
        stopSleepMonitoring()
    }

    // MARK: - Sleep sample helpers

    private let sleepSampleLookback: TimeInterval = 12 * 60 * 60
    private let sleepSessionGap: TimeInterval = 30 * 60

    private func isSleepValue(_ value: Int) -> Bool {
        if value == HKCategoryValueSleepAnalysis.inBed.rawValue ||
            value == HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue {
            return true
        }
        if #available(watchOS 9.0, *) {
            return value == HKCategoryValueSleepAnalysis.asleepCore.rawValue ||
                value == HKCategoryValueSleepAnalysis.asleepDeep.rawValue ||
                value == HKCategoryValueSleepAnalysis.asleepREM.rawValue
        }
        return false
    }

    private func isREMValue(_ value: Int) -> Bool {
        if #available(watchOS 9.0, *) {
            return value == HKCategoryValueSleepAnalysis.asleepREM.rawValue
        }
        return false
    }

    private func sleepSessionWindow(from samples: [HKCategorySample]) -> (start: Date, end: Date)? {
        let sleepSamples = samples.filter { isSleepValue($0.value) }.sorted(by: { $0.startDate < $1.startDate })
        guard let first = sleepSamples.first else { return nil }

        var sessionStart = first.startDate
        var sessionEnd = first.endDate

        for sample in sleepSamples.dropFirst() {
            if sample.startDate.timeIntervalSince(sessionEnd) > sleepSessionGap {
                sessionStart = sample.startDate
                sessionEnd = sample.endDate
                continue
            }
            if sample.endDate > sessionEnd {
                sessionEnd = sample.endDate
            }
        }

        return (sessionStart, sessionEnd)
    }
}
