import Foundation
import SwiftUI
import Combine

struct SessionSummary: Codable {
    let sessionStart: Date
    let sessionEnd: Date?
    let lastSleepStart: Date?
    let lastSleepEnd: Date?
    let lastREMWindowStart: Date?
    let lastREMWindowEnd: Date?
    let lastREMDescription: String
    let lowPowerMode: Bool
    let requireStillness: Bool
    let stillnessMinutes: Double
    let cueIntervalSeconds: Double
    let hapticPulseCount: Int
    let hapticPulseInterval: Double
    let hapticPatternType: String
    let detectionStrictness: String
    let autoMode: String
    let sleepBackgroundStyle: String
    let useHRV: Bool
    let useRespiratoryRate: Bool

    var detectionStrictnessLabel: String {
        DetectionStrictness(rawValue: detectionStrictness)?.label ?? detectionStrictness
    }

    var autoModeLabel: String {
        AutoMode(rawValue: autoMode)?.label ?? autoMode
    }

    var hapticPatternLabel: String {
        HapticPatternType(rawValue: hapticPatternType)?.label ?? hapticPatternType
    }

    var sleepBackgroundLabel: String {
        SleepBackgroundStyle(rawValue: sleepBackgroundStyle)?.label ?? sleepBackgroundStyle
    }
}

@MainActor
final class SessionSummaryStore: ObservableObject {
    static let shared = SessionSummaryStore()

    @Published private(set) var lastSummary: SessionSummary? = nil
    @Published private(set) var activeSummary: SessionSummary? = nil

    private let summaryKey = "LucidityLastSessionSummary"

    private init() {
        loadSummary()
    }

    func startSession(startDate: Date = Date()) {
        let summary = SessionSummary(sessionStart: startDate,
                                     sessionEnd: nil,
                                     lastSleepStart: nil,
                                     lastSleepEnd: nil,
                                     lastREMWindowStart: nil,
                                     lastREMWindowEnd: nil,
                                     lastREMDescription: "No REM window detected",
                                     lowPowerMode: AppSettings.lowPowerMode,
                                     requireStillness: AppSettings.requireStillness,
                                     stillnessMinutes: AppSettings.stillnessMinutes,
                                     cueIntervalSeconds: AppSettings.cueIntervalSeconds,
                                     hapticPulseCount: AppSettings.hapticPulseCount,
                                     hapticPulseInterval: AppSettings.hapticPulseInterval,
                                     hapticPatternType: AppSettings.hapticPatternType.rawValue,
                                     detectionStrictness: AppSettings.detectionStrictness.rawValue,
                                     autoMode: AppSettings.autoMode.rawValue,
                                     sleepBackgroundStyle: AppSettings.sleepBackgroundStyle.rawValue,
                                     useHRV: AppSettings.useHRV,
                                     useRespiratoryRate: AppSettings.useRespiratoryRate)
        activeSummary = summary
    }

    func endSession(endDate: Date,
                    lastSleepStart: Date?,
                    lastSleepEnd: Date?,
                    lastREMWindowStart: Date?,
                    lastREMWindowEnd: Date?,
                    lastREMDescription: String) {
        let base = activeSummary ?? SessionSummary(sessionStart: endDate,
                                                   sessionEnd: nil,
                                                   lastSleepStart: nil,
                                                   lastSleepEnd: nil,
                                                   lastREMWindowStart: nil,
                                                   lastREMWindowEnd: nil,
                                                   lastREMDescription: "No REM window detected",
                                                   lowPowerMode: AppSettings.lowPowerMode,
                                                   requireStillness: AppSettings.requireStillness,
                                                   stillnessMinutes: AppSettings.stillnessMinutes,
                                                   cueIntervalSeconds: AppSettings.cueIntervalSeconds,
                                                   hapticPulseCount: AppSettings.hapticPulseCount,
                                                   hapticPulseInterval: AppSettings.hapticPulseInterval,
                                                   hapticPatternType: AppSettings.hapticPatternType.rawValue,
                                                   detectionStrictness: AppSettings.detectionStrictness.rawValue,
                                                   autoMode: AppSettings.autoMode.rawValue,
                                                   sleepBackgroundStyle: AppSettings.sleepBackgroundStyle.rawValue,
                                                   useHRV: AppSettings.useHRV,
                                                   useRespiratoryRate: AppSettings.useRespiratoryRate)

        let summary = SessionSummary(sessionStart: base.sessionStart,
                                     sessionEnd: endDate,
                                     lastSleepStart: lastSleepStart,
                                     lastSleepEnd: lastSleepEnd,
                                     lastREMWindowStart: lastREMWindowStart,
                                     lastREMWindowEnd: lastREMWindowEnd,
                                     lastREMDescription: lastREMDescription,
                                     lowPowerMode: base.lowPowerMode,
                                     requireStillness: base.requireStillness,
                                     stillnessMinutes: base.stillnessMinutes,
                                     cueIntervalSeconds: base.cueIntervalSeconds,
                                     hapticPulseCount: base.hapticPulseCount,
                                     hapticPulseInterval: base.hapticPulseInterval,
                                     hapticPatternType: base.hapticPatternType,
                                     detectionStrictness: base.detectionStrictness,
                                     autoMode: base.autoMode,
                                     sleepBackgroundStyle: base.sleepBackgroundStyle,
                                     useHRV: base.useHRV,
                                     useRespiratoryRate: base.useRespiratoryRate)

        lastSummary = summary
        activeSummary = nil
        saveSummary(summary)
    }

    private func saveSummary(_ summary: SessionSummary) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        if let data = try? encoder.encode(summary) {
            UserDefaults.standard.set(data, forKey: summaryKey)
        }
    }

    private func loadSummary() {
        guard let data = UserDefaults.standard.data(forKey: summaryKey) else { return }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        if let summary = try? decoder.decode(SessionSummary.self, from: data) {
            lastSummary = summary
        }
    }
}
