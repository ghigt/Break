import Foundation

/// User settings, stored in UserDefaults. Durations are expressed in minutes.
enum Preferences {
    enum Key {
        static let workMinutes = "workMinutes"
        static let breakMinutes = "breakMinutes"
        static let warningMinutes = "warningMinutes"
        static let snoozeMinutes = "snoozeMinutes"
        static let soundsEnabled = "soundsEnabled"
    }

    enum Default {
        static let workMinutes = 25
        static let breakMinutes = 5
        static let warningMinutes = 1
        static let snoozeMinutes = 3
        static let soundsEnabled = true
    }

    private static var defaults: UserDefaults { .standard }

    static func registerDefaults() {
        defaults.register(defaults: [
            Key.workMinutes: Default.workMinutes,
            Key.breakMinutes: Default.breakMinutes,
            Key.warningMinutes: Default.warningMinutes,
            Key.snoozeMinutes: Default.snoozeMinutes,
            Key.soundsEnabled: Default.soundsEnabled,
        ])
    }

    /// Seconds in a "minute". Set `BREAK_SECONDS_PER_MINUTE=1` to test full cycles quickly.
    static let secondsPerMinute: TimeInterval = {
        if let raw = ProcessInfo.processInfo.environment["BREAK_SECONDS_PER_MINUTE"],
           let value = TimeInterval(raw), value > 0 {
            return value
        }
        return 60
    }()

    static var workMinutes: Int { defaults.integer(forKey: Key.workMinutes) }
    static var breakMinutes: Int { defaults.integer(forKey: Key.breakMinutes) }

    static var workDuration: TimeInterval { minutes(Key.workMinutes) }
    static var breakDuration: TimeInterval { minutes(Key.breakMinutes) }
    static var warningDuration: TimeInterval { minutes(Key.warningMinutes) }
    static var snoozeDuration: TimeInterval { minutes(Key.snoozeMinutes) }
    static var snoozeMinutes: Int { defaults.integer(forKey: Key.snoozeMinutes) }
    static var soundsEnabled: Bool { defaults.bool(forKey: Key.soundsEnabled) }

    /// How long the break screen can be lifted, e.g. to pause a video.
    static let peekSeconds = 20
    static var peekDuration: TimeInterval { TimeInterval(peekSeconds) }

    private static func minutes(_ key: String) -> TimeInterval {
        TimeInterval(max(1, defaults.integer(forKey: key))) * secondsPerMinute
    }
}
