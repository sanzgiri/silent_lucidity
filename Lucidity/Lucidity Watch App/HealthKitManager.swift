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
/// - Heart rate variability (HRV) and respiratory rate are used when available to improve REM detection.
/// - Motion stillness is used as a sleep gate when enabled.
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

    /// The most recent heart rate variability (SDNN) in milliseconds.
    @Published private(set) var latestHRV: Double? = nil

    /// The most recent respiratory rate in breaths per minute.
    @Published private(set) var latestRespiratoryRate: Double? = nil
    
    /// The most recent sleep window description for REM detection.
    @Published private(set) var lastSleepWindowDescription: String = "No REM window detected"

    private var sleepObserverQuery: HKObserverQuery?
    private var heartRateAnchoredQuery: HKAnchoredObjectQuery?
    private var heartRateAnchor: HKQueryAnchor?
    private var hrvAnchoredQuery: HKAnchoredObjectQuery?
    private var hrvAnchor: HKQueryAnchor?
    private var respiratoryAnchoredQuery: HKAnchoredObjectQuery?
    private var respiratoryAnchor: HKQueryAnchor?
    
    private var latestSleepSamples: [HKCategorySample] = []
    private var latestHeartRateSamples: [HKQuantitySample] = []
    private var latestHRVDate: Date? = nil
    private var latestRespiratoryRateDate: Date? = nil
    private var lastREMState: Bool? = nil
    private var lastREMWindowStart: Date? = nil
    private var lastREMWindowEnd: Date? = nil
    private var lastREMWindowDescription: String? = nil
    
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
        var toRead: Set<HKObjectType> = [
            sleepType,
            heartRateType
        ]
        if let hrvType = HKObjectType.quantityType(forIdentifier: .heartRateVariabilitySDNN) {
            toRead.insert(hrvType)
        }
        if let respiratoryType = HKObjectType.quantityType(forIdentifier: .respiratoryRate) {
            toRead.insert(respiratoryType)
        }
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

        if let hrvType = HKObjectType.quantityType(forIdentifier: .heartRateVariabilitySDNN) {
            let hrvPredicate = predicate
            hrvAnchoredQuery = HKAnchoredObjectQuery(type: hrvType, predicate: hrvPredicate, anchor: hrvAnchor, limit: HKObjectQueryNoLimit) { [weak self] _, samplesOrNil, _, newAnchor, errorOrNil in
                guard let self = self else { return }
                if let error = errorOrNil {
                    print("Error in HRV query: \(error)")
                    return
                }
                Task { @MainActor in
                    self.updateLatestHRV(from: samplesOrNil)
                    self.hrvAnchor = newAnchor
                    await self.evaluateAndPublish()
                }
            }
            if let hrvAnchoredQuery = hrvAnchoredQuery {
                hrvAnchoredQuery.updateHandler = { [weak self] _, samplesOrNil, _, newAnchor, errorOrNil in
                    guard let self = self else { return }
                    if let error = errorOrNil {
                        print("Error in HRV update: \(error)")
                        return
                    }
                    Task { @MainActor in
                        self.updateLatestHRV(from: samplesOrNil)
                        self.hrvAnchor = newAnchor
                        await self.evaluateAndPublish()
                    }
                }
                healthStore.execute(hrvAnchoredQuery)
                print("HRV anchored query started")
            }
        }

        if let respiratoryType = HKObjectType.quantityType(forIdentifier: .respiratoryRate) {
            let respiratoryPredicate = predicate
            respiratoryAnchoredQuery = HKAnchoredObjectQuery(type: respiratoryType, predicate: respiratoryPredicate, anchor: respiratoryAnchor, limit: HKObjectQueryNoLimit) { [weak self] _, samplesOrNil, _, newAnchor, errorOrNil in
                guard let self = self else { return }
                if let error = errorOrNil {
                    print("Error in respiratory rate query: \(error)")
                    return
                }
                Task { @MainActor in
                    self.updateLatestRespiratoryRate(from: samplesOrNil)
                    self.respiratoryAnchor = newAnchor
                    await self.evaluateAndPublish()
                }
            }
            if let respiratoryAnchoredQuery = respiratoryAnchoredQuery {
                respiratoryAnchoredQuery.updateHandler = { [weak self] _, samplesOrNil, _, newAnchor, errorOrNil in
                    guard let self = self else { return }
                    if let error = errorOrNil {
                        print("Error in respiratory rate update: \(error)")
                        return
                    }
                    Task { @MainActor in
                        self.updateLatestRespiratoryRate(from: samplesOrNil)
                        self.respiratoryAnchor = newAnchor
                        await self.evaluateAndPublish()
                    }
                }
                healthStore.execute(respiratoryAnchoredQuery)
                print("Respiratory rate anchored query started")
            }
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
        if let hrvAnchoredQuery = hrvAnchoredQuery {
            healthStore.stop(hrvAnchoredQuery)
            self.hrvAnchoredQuery = nil
            self.hrvAnchor = nil
        }
        if let respiratoryAnchoredQuery = respiratoryAnchoredQuery {
            healthStore.stop(respiratoryAnchoredQuery)
            self.respiratoryAnchoredQuery = nil
            self.respiratoryAnchor = nil
        }
        
        // Clear cached data
        self.latestSleepSamples.removeAll()
        self.latestHeartRateSamples.removeAll()
        
        self.lastSleepWindowDescription = "No REM window detected"
        self.latestHeartRate = nil
        self.latestHRV = nil
        self.latestRespiratoryRate = nil
        self.latestHRVDate = nil
        self.latestRespiratoryRateDate = nil
        self.lastREMState = nil
        self.lastREMWindowStart = nil
        self.lastREMWindowEnd = nil
        self.lastREMWindowDescription = nil
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
                        self.latestSleepStart = nil
                        self.latestSleepEnd = nil
                        continuation.resume()
                    }
                    return
                }
                Task { @MainActor in
                    if let samples = samplesOrNil as? [HKCategorySample] {
                        self.latestSleepSamples = samples
                        if let window = self.sleepSessionWindow(from: samples) {
                            self.latestSleepStart = window.start
                            self.latestSleepEnd = window.end
                        } else {
                            self.latestSleepStart = nil
                            self.latestSleepEnd = nil
                        }
                    } else {
                        self.latestSleepSamples = []
                        self.latestSleepStart = nil
                        self.latestSleepEnd = nil
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
    private func evaluateProbableREM(using sleepSamples: [HKCategorySample], and heartRateSamples: [HKQuantitySample]) -> REMResult {
        let now = Date()

        // 1. Find the most recent sleep session window
        guard let sleepWindow = sleepSessionWindow(from: sleepSamples) else {
            return REMResult(isREM: false, description: "No sleep start detected", windowStart: nil, windowEnd: nil)
        }

        let requireStillness = AppSettings.requireStillness
        let motionMonitor = MotionSleepMonitor.shared
        let isStillEnough = !requireStillness || !motionMonitor.isMonitoring || motionMonitor.isStillForSleep
        if !isStillEnough {
            return REMResult(isREM: false, description: "Not still enough for sleep", windowStart: nil, windowEnd: nil)
        }

        let hrRange = heartRateRange(from: heartRateSamples, sleepWindow: sleepWindow, now: now)
        let support = supportSignals(now: now)
        let supportAvailable = support.hrvAvailable || support.respAvailable
        let supportOK = support.hrvSupport || support.respSupport
        let strictness = AppSettings.detectionStrictness

        // 2. Look for REM sleep samples if available and current
        if let remSample = sleepSamples.last(where: { isREMValue($0.value) && $0.endDate >= sleepWindow.start && $0.startDate <= sleepWindow.end }) {
            let remStart = remSample.startDate
            let remEnd = remSample.endDate
            let isCurrent = now <= remEnd.addingTimeInterval(remSampleGracePeriod)
            if isCurrent {
                let hrSamplesDuringREM = overlappingSamples(in: heartRateSamples, start: remStart, end: remEnd)
                let isHeartRateInREMRange = hrSamplesDuringREM.contains { sample in
                    let bpm = sample.quantity.doubleValue(for: HKUnit.count().unitDivided(by: HKUnit.minute()))
                    return hrRange.contains(bpm)
                }
                if explicitGatePasses(hrInRange: isHeartRateInREMRange,
                                      supportAvailable: supportAvailable,
                                      supportOK: supportOK,
                                      strictness: strictness) {
                    let formatter = DateIntervalFormatter()
                    formatter.dateStyle = .none
                    formatter.timeStyle = .short
                    let intervalString = formatter.string(from: remStart, to: remEnd)
                    return REMResult(isREM: true, description: "Detected REM window: \(intervalString)", windowStart: remStart, windowEnd: remEnd)
                }
                return REMResult(isREM: false, description: "REM stage detected but signals not supportive", windowStart: remStart, windowEnd: remEnd)
            }
        }

        // 3. If no explicit REM samples, approximate cycles every ~90 minutes from sleep start date.
        let elapsedTime = now.timeIntervalSince(sleepWindow.start)
        guard elapsedTime > 0 else {
            return REMResult(isREM: false, description: "Sleep start in future or no elapsed time", windowStart: nil, windowEnd: nil)
        }

        let inferredWindow = inferredRemWindow(sleepStartDate: sleepWindow.start, now: now)
        if now < inferredWindow.start {
            return REMResult(isREM: false, description: "No REM window yet", windowStart: inferredWindow.start, windowEnd: inferredWindow.end)
        }

        let hrSamplesInWindow = overlappingSamples(in: heartRateSamples, start: inferredWindow.start, end: inferredWindow.end)
        let isHeartRateInREMRange = hrSamplesInWindow.contains { sample in
            let bpm = sample.quantity.doubleValue(for: HKUnit.count().unitDivided(by: HKUnit.minute()))
            return hrRange.contains(bpm)
        }

        let formatter = DateIntervalFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        let intervalString = formatter.string(from: inferredWindow.start, to: inferredWindow.end)

        if fallbackGatePasses(hrInRange: isHeartRateInREMRange,
                              supportAvailable: supportAvailable,
                              supportOK: supportOK,
                              strictness: strictness) {
            return REMResult(isREM: true, description: "Approximated REM window: \(intervalString)", windowStart: inferredWindow.start, windowEnd: inferredWindow.end)
        }
        return REMResult(isREM: false, description: "No REM detected in approximated window: \(intervalString)", windowStart: inferredWindow.start, windowEnd: inferredWindow.end)
    }

    /// Fetches latest samples and evaluates REM windows, updating published properties and posting notifications.
    @MainActor
    private func evaluateAndPublish() async {
        let result = evaluateProbableREM(using: latestSleepSamples, and: latestHeartRateSamples)
        
        // Last heart rate sample for UI
        let lastHRBPM: Double? = latestHeartRateSamples.last.map {
            $0.quantity.doubleValue(for: HKUnit.count().unitDivided(by: HKUnit.minute()))
        }
        
        self.lastSleepWindowDescription = result.description
        self.latestHeartRate = lastHRBPM

        logREMTransitionIfNeeded(result: result)
        
        NotificationCenter.default.post(name: HealthKitManager.remWindowDidChangeNotification,
                                        object: nil,
                                        userInfo: ["isREM": result.isREM,
                                                   "description": result.description,
                                                   "windowStart": result.windowStart as Any,
                                                   "windowEnd": result.windowEnd as Any])
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
    private let remCycleInterval: TimeInterval = 90 * 60
    private let remWindowDuration: TimeInterval = 20 * 60
    private let remSampleGracePeriod: TimeInterval = 10 * 60
    private let heartRateRangeLookback: TimeInterval = 2 * 60 * 60
    private let supportSignalRecency: TimeInterval = 30 * 60

    private struct SupportSignalSummary {
        let hrvAvailable: Bool
        let hrvSupport: Bool
        let respAvailable: Bool
        let respSupport: Bool
    }

    private struct REMResult {
        let isREM: Bool
        let description: String
        let windowStart: Date?
        let windowEnd: Date?
    }

    private func updateLatestHRV(from samplesOrNil: [HKSample]?) {
        guard let samples = samplesOrNil as? [HKQuantitySample],
              let last = samples.max(by: { $0.endDate < $1.endDate }) else {
            return
        }
        let unit = HKUnit.secondUnit(with: .milli)
        latestHRV = last.quantity.doubleValue(for: unit)
        latestHRVDate = last.endDate
    }

    private func updateLatestRespiratoryRate(from samplesOrNil: [HKSample]?) {
        guard let samples = samplesOrNil as? [HKQuantitySample],
              let last = samples.max(by: { $0.endDate < $1.endDate }) else {
            return
        }
        let unit = HKUnit.count().unitDivided(by: HKUnit.minute())
        latestRespiratoryRate = last.quantity.doubleValue(for: unit)
        latestRespiratoryRateDate = last.endDate
    }

    private func supportSignals(now: Date) -> SupportSignalSummary {
        let useHRV = AppSettings.useHRV
        let useRespiratory = AppSettings.useRespiratoryRate

        let hrvAvailable = useHRV && isSampleRecent(latestHRVDate, now: now, within: supportSignalRecency)
        let respAvailable = useRespiratory && isSampleRecent(latestRespiratoryRateDate, now: now, within: supportSignalRecency)

        let hrvSupport = hrvAvailable && isHRVSupportive()
        let respSupport = respAvailable && isRespiratorySupportive()

        return SupportSignalSummary(hrvAvailable: hrvAvailable,
                                    hrvSupport: hrvSupport,
                                    respAvailable: respAvailable,
                                    respSupport: respSupport)
    }

    private func explicitGatePasses(hrInRange: Bool,
                                    supportAvailable: Bool,
                                    supportOK: Bool,
                                    strictness: DetectionStrictness) -> Bool {
        switch strictness {
        case .lenient:
            return true
        case .balanced:
            if supportAvailable {
                return hrInRange || supportOK
            }
            return true
        case .strict:
            if supportAvailable {
                return hrInRange && supportOK
            }
            return hrInRange
        }
    }

    private func fallbackGatePasses(hrInRange: Bool,
                                    supportAvailable: Bool,
                                    supportOK: Bool,
                                    strictness: DetectionStrictness) -> Bool {
        switch strictness {
        case .lenient:
            if supportAvailable {
                return hrInRange || supportOK
            }
            return hrInRange
        case .balanced:
            if supportAvailable {
                return hrInRange && supportOK
            }
            return hrInRange
        case .strict:
            return hrInRange && supportAvailable && supportOK
        }
    }

    private func isSampleRecent(_ date: Date?, now: Date, within interval: TimeInterval) -> Bool {
        guard let date = date else { return false }
        return now.timeIntervalSince(date) <= interval
    }

    private func isHRVSupportive() -> Bool {
        guard let hrv = latestHRV else { return false }
        return hrv >= 20 && hrv <= 120
    }

    private func isRespiratorySupportive() -> Bool {
        guard let rate = latestRespiratoryRate else { return false }
        return rate >= 8 && rate <= 20
    }

    private func inferredRemWindow(sleepStartDate: Date, now: Date) -> (start: Date, end: Date) {
        let elapsedTime = now.timeIntervalSince(sleepStartDate)
        let cyclesElapsed = max(0, Int(elapsedTime / remCycleInterval))
        let currentCycleStart = sleepStartDate.addingTimeInterval(TimeInterval(cyclesElapsed) * remCycleInterval)
        let currentRemStart = currentCycleStart.addingTimeInterval(remCycleInterval - remWindowDuration)
        let currentRemEnd = currentCycleStart.addingTimeInterval(remCycleInterval)

        if now < currentRemStart, cyclesElapsed > 0 {
            let previousCycleStart = currentCycleStart.addingTimeInterval(-remCycleInterval)
            let previousRemStart = previousCycleStart.addingTimeInterval(remCycleInterval - remWindowDuration)
            let previousRemEnd = previousCycleStart.addingTimeInterval(remCycleInterval)
            return (previousRemStart, previousRemEnd)
        }

        return (currentRemStart, currentRemEnd)
    }

    private func overlappingSamples(in samples: [HKQuantitySample], start: Date, end: Date) -> [HKQuantitySample] {
        samples.filter { $0.startDate <= end && $0.endDate >= start }
    }

    private func heartRateRange(from samples: [HKQuantitySample], sleepWindow: (start: Date, end: Date), now: Date) -> ClosedRange<Double> {
        let rangeStart = max(sleepWindow.start, now.addingTimeInterval(-heartRateRangeLookback))
        let rangeEnd = min(sleepWindow.end, now)
        let windowSamples = overlappingSamples(in: samples, start: rangeStart, end: rangeEnd)

        guard windowSamples.count >= 10 else {
            return 45...70
        }

        let unit = HKUnit.count().unitDivided(by: HKUnit.minute())
        let sortedValues = windowSamples
            .map { $0.quantity.doubleValue(for: unit) }
            .sorted()

        let count = sortedValues.count
        let mid = count / 2
        let median: Double
        if count % 2 == 0 {
            median = (sortedValues[mid - 1] + sortedValues[mid]) / 2
        } else {
            median = sortedValues[mid]
        }

        let lower = max(40, median - 10)
        let upper = min(90, median + 15)
        return lower...upper
    }

    private func logREMTransitionIfNeeded(result: REMResult) {
        defer {
            lastREMState = result.isREM
            if result.isREM {
                lastREMWindowStart = result.windowStart
                lastREMWindowEnd = result.windowEnd
                lastREMWindowDescription = result.description
            }
        }

        guard let lastState = lastREMState, lastState != result.isREM else {
            return
        }

        if result.isREM {
            let intervalText = formattedInterval(start: result.windowStart, end: result.windowEnd)
            let note = intervalText.map { "REM detected: \($0)" } ?? "REM detected"
            HistoryStore.shared.log(note: note)
            return
        }

        if let lastStart = lastREMWindowStart, let lastEnd = lastREMWindowEnd,
           let intervalText = formattedInterval(start: lastStart, end: lastEnd) {
            HistoryStore.shared.log(note: "REM ended: \(intervalText)")
        } else if let lastDescription = lastREMWindowDescription {
            HistoryStore.shared.log(note: "REM ended: \(lastDescription)")
        } else {
            HistoryStore.shared.log(note: "REM ended")
        }
    }

    private func formattedInterval(start: Date?, end: Date?) -> String? {
        guard let start = start, let end = end else { return nil }
        let formatter = DateIntervalFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter.string(from: start, to: end)
    }

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
