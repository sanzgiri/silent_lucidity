import HealthKit
import Combine

class SessionManager: NSObject, ObservableObject {
    let healthStore = HKHealthStore()
    var session: HKWorkoutSession?
    var builder: HKLiveWorkoutBuilder?
    
    @Published var state: HKWorkoutSessionState = .notStarted
    
    func startOvernightSession() {
        let config = HKWorkoutConfiguration()
        config.activityType = .mindAndBody
        config.locationType = .indoor
        
        do {
            session = try HKWorkoutSession(healthStore: healthStore, configuration: config)
            builder = session?.associatedWorkoutBuilder()
            builder?.dataSource = HKLiveWorkoutDataSource(healthStore: healthStore, workoutConfiguration: config)
            
            session?.delegate = self
            builder?.delegate = self
            
            session?.startActivity(with: Date())
            builder?.beginCollection(withStart: Date()) { (success, error) in
                if success {
                    print("Session started successfully")
                } else {
                    print("Failed to begin collection: \(String(describing: error))")
                }
            }
        } catch {
            print("Failed to start session: \(error)")
        }
    }
    
    func stopSession() {
        session?.end()
        builder?.endCollection(withEnd: Date()) { (success, error) in
            self.builder?.finishWorkout { (workout, error) in
                print("Workout finished")
            }
        }
    }
    
    func requestAuthorization() {
        let typesToShare: Set = [
            HKQuantityType.workoutType()
        ]
        
        let typesToRead: Set = [
            HKQuantityType.quantityType(forIdentifier: .heartRate)!,
            HKObjectType.activitySummaryType()
        ]
        
        healthStore.requestAuthorization(toShare: typesToShare, read: typesToRead) { (success, error) in
            if !success {
                print("Authorization failed")
            }
        }
    }
}

extension SessionManager: HKWorkoutSessionDelegate {
    func workoutSession(_ workoutSession: HKWorkoutSession, didChangeTo toState: HKWorkoutSessionState, from fromState: HKWorkoutSessionState, date: Date) {
        DispatchQueue.main.async {
            self.state = toState
        }
    }
    
    func workoutSession(_ workoutSession: HKWorkoutSession, didFailWithError error: Error) {
        print("Workout session failed: \(error)")
    }
}

extension SessionManager: HKLiveWorkoutBuilderDelegate {
    var onHeartRateUpdate: ((Double, Date) -> Void)?
    
    func workoutBuilder(_ workoutBuilder: HKLiveWorkoutBuilder, didCollectDataOf collectedTypes: Set<HKSampleType>) {
        for type in collectedTypes {
            guard let quantityType = type as? HKQuantityType, quantityType == HKQuantityType.quantityType(forIdentifier: .heartRate) else { continue }
            
            guard let statistics = workoutBuilder.statistics(for: quantityType) else { continue }
            
            // Get the most recent heart rate
            let unit = HKUnit.count().unitDivided(by: HKUnit.minute())
            if let quantity = statistics.mostRecentQuantity() {
                let bpm = quantity.doubleValue(for: unit)
                let date = statistics.endDate
                
                DispatchQueue.main.async {
                    self.onHeartRateUpdate?(bpm, date)
                }
            }
        }
    }
    
    func workoutBuilderDidCollectEvent(_ workoutBuilder: HKLiveWorkoutBuilder) {
    }
}
