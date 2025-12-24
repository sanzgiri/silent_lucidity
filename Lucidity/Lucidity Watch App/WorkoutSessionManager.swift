import Foundation
import HealthKit
import WatchKit
import Combine

@preconcurrency
final class WorkoutSessionManager: NSObject, ObservableObject, HKWorkoutSessionDelegate, HKLiveWorkoutBuilderDelegate {
    static let shared = WorkoutSessionManager()

    enum WorkoutState: String {
        case idle
        case requesting
        case running
        case failed
    }

    @Published private(set) var workoutState: WorkoutState = .idle
    @Published private(set) var workoutErrorDescription: String? = nil
    @Published private(set) var workoutStartDate: Date? = nil

    private let healthStore = HKHealthStore()
    private var session: HKWorkoutSession?
    private var builder: HKLiveWorkoutBuilder?

    func startOvernightSession() {
        Task { @MainActor in
            self.updateState(.requesting, errorDescription: nil, startDate: nil)
        }
        let typesToShare: Set = [HKObjectType.workoutType()]
        let typesToRead: Set = [HKObjectType.quantityType(forIdentifier: .heartRate)!]

        healthStore.requestAuthorization(toShare: typesToShare, read: typesToRead) { [weak self] success, error in
            guard let self = self else { return }
            guard success else {
                Task { @MainActor in
                    self.reportFailure(error, message: "Workout authorization denied")
                }
                return
            }

            let configuration = HKWorkoutConfiguration()
            configuration.activityType = .mindAndBody
            configuration.locationType = .indoor

            do {
                self.session = try HKWorkoutSession(healthStore: self.healthStore, configuration: configuration)
                self.builder = self.session?.associatedWorkoutBuilder()
                self.session?.delegate = self
                self.builder?.delegate = self
                self.builder?.dataSource = HKLiveWorkoutDataSource(healthStore: self.healthStore, workoutConfiguration: configuration)

                let startDate = Date()
                self.session?.startActivity(with: startDate)
                self.builder?.beginCollection(withStart: startDate) { _, _ in }
                Task { @MainActor in
                    self.updateState(.running, errorDescription: nil, startDate: startDate)
                }
            } catch {
                Task { @MainActor in
                    self.reportFailure(error, message: "Workout session failed to start")
                }
            }
        }
    }

    func stopSession() {
        session?.end()
        builder?.endCollection(withEnd: Date()) { [weak self] _, _ in
            self?.builder?.finishWorkout(completion: { _, _ in })
            Task { @MainActor in
                self?.updateState(.idle, errorDescription: nil, startDate: nil)
            }
        }
    }

    // MARK: - HKWorkoutSessionDelegate

    nonisolated func workoutSession(_ workoutSession: HKWorkoutSession, didChangeTo toState: HKWorkoutSessionState, from fromState: HKWorkoutSessionState, date: Date) {
        switch toState {
        case .running:
            Task { @MainActor in
                self.updateState(.running, errorDescription: nil, startDate: date)
            }
        case .ended, .stopped:
            Task { @MainActor in
                self.updateState(.idle, errorDescription: nil, startDate: nil)
            }
        default:
            break
        }
    }

    nonisolated func workoutSession(_ workoutSession: HKWorkoutSession, didFailWithError error: Error) {
        Task { @MainActor in
            self.reportFailure(error, message: "Workout session failed")
        }
    }

    // MARK: - HKLiveWorkoutBuilderDelegate

    nonisolated func workoutBuilderDidCollectEvent(_ workoutBuilder: HKLiveWorkoutBuilder) {
        // Minimal stub
    }

    nonisolated func workoutBuilder(_ workoutBuilder: HKLiveWorkoutBuilder, didCollectDataOf types: Set<HKSampleType>) {
        // Minimal stub
    }

    @MainActor
    private func updateState(_ state: WorkoutState, errorDescription: String?, startDate: Date?) {
        workoutState = state
        workoutErrorDescription = errorDescription
        workoutStartDate = startDate
    }

    @MainActor
    private func reportFailure(_ error: Error?, message: String) {
        let errorText = error?.localizedDescription
        let description = errorText == nil ? message : "\(message): \(errorText!)"
        updateState(.failed, errorDescription: description, startDate: nil)
        HistoryStore.shared.log(note: "Workout failed: \(description)")
    }
}
