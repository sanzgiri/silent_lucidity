import Foundation

enum AppSettingsKeys {
    static let lowPowerMode = "lowPowerMode"
    static let requireStillness = "requireStillness"
    static let stillnessMinutes = "stillnessMinutes"
    static let cueIntervalSeconds = "cueIntervalSeconds"
    static let hapticPulseCount = "hapticPulseCount"
    static let hapticPulseInterval = "hapticPulseInterval"
    static let hapticPatternType = "hapticPatternType"
    static let detectionStrictness = "detectionStrictness"
    static let autoMode = "autoMode"
    static let sleepBackgroundStyle = "sleepBackgroundStyle"
    static let useHRV = "useHRV"
    static let useRespiratoryRate = "useRespiratoryRate"
}

enum HapticPatternType: String, CaseIterable, Identifiable {
    case clickOnly = "clickOnly"
    case clickAndStart = "clickAndStart"
    case startOnly = "startOnly"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .clickOnly:
            return "Click Only"
        case .clickAndStart:
            return "Click + Start"
        case .startOnly:
            return "Start Only"
        }
    }
}

enum DetectionStrictness: String, CaseIterable, Identifiable {
    case lenient = "lenient"
    case balanced = "balanced"
    case strict = "strict"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .lenient:
            return "Lenient"
        case .balanced:
            return "Balanced"
        case .strict:
            return "Strict"
        }
    }
}

enum AutoMode: String, CaseIterable, Identifiable {
    case motionOnly = "motionOnly"
    case hybrid = "hybrid"
    case healthKitOnly = "healthKitOnly"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .motionOnly:
            return "Motion Only"
        case .hybrid:
            return "Hybrid"
        case .healthKitOnly:
            return "HealthKit Only"
        }
    }
}

enum SleepBackgroundStyle: String, CaseIterable, Identifiable {
    case radialGlow = "radialGlow"
    case moonRings = "moonRings"
    case starfield = "starfield"
    case breathingGlow = "breathingGlow"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .radialGlow:
            return "Radial Glow"
        case .moonRings:
            return "Moon Rings"
        case .starfield:
            return "Starfield"
        case .breathingGlow:
            return "Breathing Glow"
        }
    }
}

enum AppSettings {
    static let defaultStillnessMinutes: Double = 10
    static let defaultCueIntervalSeconds: Double = 30
    static let defaultHapticPulseCount: Int = 4
    static let defaultHapticPulseInterval: Double = 0.3
    static let defaultHapticPatternType: HapticPatternType = .clickAndStart
    static let defaultDetectionStrictness: DetectionStrictness = .balanced
    static let defaultAutoMode: AutoMode = .motionOnly
    static let defaultSleepBackgroundStyle: SleepBackgroundStyle = .radialGlow
    static let defaultMinCueIntervalSeconds: Double = 20
    static let defaultLowPowerCueIntervalSeconds: Double = 90
    static let defaultLowPowerMinCueIntervalSeconds: Double = 60
    static let defaultMotionUpdateIntervalSeconds: Double = 1
    static let defaultLowPowerMotionUpdateIntervalSeconds: Double = 2

    static func bool(forKey key: String, default defaultValue: Bool) -> Bool {
        guard UserDefaults.standard.object(forKey: key) != nil else {
            return defaultValue
        }
        return UserDefaults.standard.bool(forKey: key)
    }

    static func double(forKey key: String, default defaultValue: Double) -> Double {
        guard UserDefaults.standard.object(forKey: key) != nil else {
            return defaultValue
        }
        return UserDefaults.standard.double(forKey: key)
    }

    static func int(forKey key: String, default defaultValue: Int) -> Int {
        guard UserDefaults.standard.object(forKey: key) != nil else {
            return defaultValue
        }
        return UserDefaults.standard.integer(forKey: key)
    }

    static var lowPowerMode: Bool {
        bool(forKey: AppSettingsKeys.lowPowerMode, default: false)
    }

    static var requireStillness: Bool {
        bool(forKey: AppSettingsKeys.requireStillness, default: true)
    }

    static var stillnessMinutes: Double {
        max(1, double(forKey: AppSettingsKeys.stillnessMinutes, default: defaultStillnessMinutes))
    }

    static var cueIntervalSeconds: TimeInterval {
        let base = max(15, double(forKey: AppSettingsKeys.cueIntervalSeconds, default: defaultCueIntervalSeconds))
        if lowPowerMode {
            return max(base, defaultLowPowerCueIntervalSeconds)
        }
        return base
    }

    static var minCueIntervalSeconds: TimeInterval {
        if lowPowerMode {
            return defaultLowPowerMinCueIntervalSeconds
        }
        return defaultMinCueIntervalSeconds
    }

    static var motionUpdateIntervalSeconds: TimeInterval {
        lowPowerMode ? defaultLowPowerMotionUpdateIntervalSeconds : defaultMotionUpdateIntervalSeconds
    }

    static var hapticPulseCount: Int {
        let raw = int(forKey: AppSettingsKeys.hapticPulseCount, default: defaultHapticPulseCount)
        return min(15, max(3, raw))
    }

    static var hapticPulseInterval: TimeInterval {
        let raw = double(forKey: AppSettingsKeys.hapticPulseInterval, default: defaultHapticPulseInterval)
        return min(0.4, max(0.2, raw))
    }

    static var hapticPatternType: HapticPatternType {
        let raw = UserDefaults.standard.string(forKey: AppSettingsKeys.hapticPatternType) ?? defaultHapticPatternType.rawValue
        return HapticPatternType(rawValue: raw) ?? defaultHapticPatternType
    }

    static var detectionStrictness: DetectionStrictness {
        let raw = UserDefaults.standard.string(forKey: AppSettingsKeys.detectionStrictness) ?? defaultDetectionStrictness.rawValue
        return DetectionStrictness(rawValue: raw) ?? defaultDetectionStrictness
    }

    static var autoMode: AutoMode {
        let raw = UserDefaults.standard.string(forKey: AppSettingsKeys.autoMode) ?? defaultAutoMode.rawValue
        return AutoMode(rawValue: raw) ?? defaultAutoMode
    }

    static var sleepBackgroundStyle: SleepBackgroundStyle {
        let raw = UserDefaults.standard.string(forKey: AppSettingsKeys.sleepBackgroundStyle) ?? defaultSleepBackgroundStyle.rawValue
        return SleepBackgroundStyle(rawValue: raw) ?? defaultSleepBackgroundStyle
    }

    static var useHRV: Bool {
        bool(forKey: AppSettingsKeys.useHRV, default: true)
    }

    static var useRespiratoryRate: Bool {
        bool(forKey: AppSettingsKeys.useRespiratoryRate, default: true)
    }
}
