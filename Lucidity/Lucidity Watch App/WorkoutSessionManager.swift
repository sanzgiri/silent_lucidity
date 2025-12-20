import Foundation
import HealthKit
import WatchKit

@preconcurrency
final class WorkoutSessionManager: NSObject, HKWorkoutSessionDelegate, HKLiveWorkoutBuilderDelegate {
    static let shared = WorkoutSessionManager()

    private let healthStore = HKHealthStore()
    private var session: HKWorkoutSession?
    private var builder: HKLiveWorkoutBuilder?

    func startOvernightSession() {
        let typesToShare: Set = [HKObjectType.workoutType()]
        let typesToRead: Set = [HKObjectType.quantityType(forIdentifier: .heartRate)!]

        healthStore.requestAuthorization(toShare: typesToShare, read: typesToRead) { [weak self] success, error in
            guard success, let self = self else { return }

            let configuration = HKWorkoutConfiguration()
            configuration.activityType = .mindAndBody
            configuration.locationType = .indoor

            do {
                self.session = try HKWorkoutSession(healthStore: self.healthStore, configuration: configuration)
                self.builder = self.session?.associatedWorkoutBuilder()
                self.session?.delegate = self
                self.builder?.delegate = self
                self.builder?.dataSource = HKLiveWorkoutDataSource(healthStore: self.healthStore, workoutConfiguration: configuration)

                self.session?.startActivity(with: Date())
                self.builder?.beginCollection(withStart: Date()) { success, error in }
            } catch {
                // Handle errors if needed
            }
        }
    }

    func stopSession() {
        session?.end()
        builder?.endCollection(withEnd: Date()) { [weak self] success, error in
            self?.builder?.finishWorkout(completion: { _, _ in })









        }
    }

    // MARK: - HKWorkoutSessionDelegate

    nonisolated func workoutSession(_ workoutSession: HKWorkoutSession, didChangeTo toState: HKWorkoutSessionState, from fromState: HKWorkoutSessionState, date: Date) {
        // Minimal stub
    }

    nonisolated func workoutSession(_ workoutSession: HKWorkoutSession, didFailWithError error: Error) {
        // Minimal stub
    }

    // MARK: - HKLiveWorkoutBuilderDelegate

    nonisolated func workoutBuilderDidCollectEvent(_ workoutBuilder: HKLiveWorkoutBuilder) {
        // Minimal stub
    }

    nonisolated func workoutBuilder(_ workoutBuilder: HKLiveWorkoutBuilder, didCollectDataOf types: Set<HKSampleType>) {
        // Minimal stub
    }
}
