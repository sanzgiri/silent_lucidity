import Foundation

enum AppSettingsKeys {
    static let lowPowerMode = "lowPowerMode"
    static let requireStillness = "requireStillness"
    static let stillnessMinutes = "stillnessMinutes"
    static let cueIntervalSeconds = "cueIntervalSeconds"
    static let useHRV = "useHRV"
    static let useRespiratoryRate = "useRespiratoryRate"
}

enum AppSettings {
    static let defaultStillnessMinutes: Double = 10
    static let defaultCueIntervalSeconds: Double = 30
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

    static var useHRV: Bool {
        bool(forKey: AppSettingsKeys.useHRV, default: true)
    }

    static var useRespiratoryRate: Bool {
        bool(forKey: AppSettingsKeys.useRespiratoryRate, default: true)
    }
}
