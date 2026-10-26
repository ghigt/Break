import AppKit
import Observation

enum Phase: Equatable {
    /// Focused work; the warning appears `warningDuration` before `endsAt`.
    case working(endsAt: Date)
    /// The pre-break warning panel is visible.
    case warning(breakAt: Date)
    /// The screen is locked.
    case onBreak(startedAt: Date, endsAt: Date)
    /// The break is over; the screen stays locked until the user resumes.
    case finished
    /// The work timer is suspended from the menu.
    case paused(remaining: TimeInterval)
}

/// Owns the work/break cycle and drives the warning panel and the lock overlay.
@MainActor
@Observable
final class BreakController {
    static let shared = BreakController()

    private(set) var phase: Phase = .paused(remaining: 0) {
        didSet { phaseDidChange(from: oldValue) }
    }
    /// Refreshed every second so views showing remaining time stay current.
    private(set) var now = Date()

    @ObservationIgnored private var timer: Timer?
    @ObservationIgnored private let warningPanel = WarningPanelController()
    @ObservationIgnored private let overlay = BreakOverlayController()

    // Time spent away (screen locked or Mac asleep) counts as a break.
    @ObservationIgnored private var awaySince: Date?
    @ObservationIgnored private var isScreenLocked = false
    @ObservationIgnored private var isAsleep = false

    private init() {}

    func start() {
        observeSession()
        startWork()
        let timer = Timer(timeInterval: 1, repeats: true) { _ in
            MainActor.assumeIsolated { BreakController.shared.tick() }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    // MARK: - Actions

    func startWork() {
        phase = .working(endsAt: Date().addingTimeInterval(Preferences.workDuration))
    }

    func breakNow() {
        let now = Date()
        phase = .onBreak(startedAt: now, endsAt: now.addingTimeInterval(Preferences.breakDuration))
    }

    /// Hides the warning; it comes back after the snooze delay.
    func snooze() {
        guard case .warning = phase else { return }
        let delay = Preferences.snoozeDuration + Preferences.warningDuration
        phase = .working(endsAt: Date().addingTimeInterval(delay))
    }

    func skipBreak() {
        guard case .onBreak = phase else { return }
        startWork()
    }

    func resume() {
        guard case .finished = phase else { return }
        startWork()
    }

    func togglePause() {
        let now = Date()
        switch phase {
        case .working(let endsAt):
            phase = .paused(remaining: endsAt.timeIntervalSince(now))
        case .warning(let breakAt):
            phase = .paused(remaining: breakAt.timeIntervalSince(now))
        case .paused(let remaining):
            phase = .working(endsAt: now.addingTimeInterval(remaining))
        case .onBreak, .finished:
            break
        }
    }

    // MARK: - State

    var isBlocking: Bool {
        switch phase {
        case .onBreak, .finished: true
        default: false
        }
    }

    var isPaused: Bool {
        if case .paused = phase { return true }
        return false
    }

    /// Seconds left in the current phase, if it is timed.
    func remaining(at date: Date) -> TimeInterval? {
        switch phase {
        case .working(let endsAt): max(0, endsAt.timeIntervalSince(date))
        case .warning(let breakAt): max(0, breakAt.timeIntervalSince(date))
        case .onBreak(_, let endsAt): max(0, endsAt.timeIntervalSince(date))
        case .paused(let remaining): max(0, remaining)
        case .finished: nil
        }
    }

    // MARK: - Ticking

    private func tick() {
        let current = Date()
        now = current

        if awaySince != nil {
            // Nothing new starts while the user is away; a running break may still end.
            if case .onBreak(_, let endsAt) = phase, current >= endsAt { phase = .finished }
            return
        }

        switch phase {
        case .working(let endsAt):
            let warning = Preferences.warningDuration
            if current >= endsAt.addingTimeInterval(-warning) {
                // After a late tick, still give a full warning.
                phase = .warning(breakAt: max(endsAt, current.addingTimeInterval(warning)))
            }
        case .warning(let breakAt):
            if current >= breakAt { breakNow() }
        case .onBreak(_, let endsAt):
            if current >= endsAt { phase = .finished }
        case .finished, .paused:
            break
        }
    }

    private func phaseDidChange(from old: Phase) {
        now = Date()
        if ProcessInfo.processInfo.environment["BREAK_DEBUG"] != nil {
            NSLog("[Break] %@ → %@", "\(old)", "\(phase)")
        }

        if case .warning = phase {
            if case .warning = old {} else {
                warningPanel.show()
                Sounds.warning()
            }
        } else {
            warningPanel.hide()
        }

        switch phase {
        case .onBreak:
            if case .onBreak = old {} else { Sounds.breakStarted() }
            overlay.show()
        case .finished:
            if old != .finished { Sounds.breakFinished() }
            overlay.show()
        default:
            overlay.hide()
        }
    }

    // MARK: - Lock & sleep

    private func observeSession() {
        let distributed = DistributedNotificationCenter.default()
        distributed.addObserver(forName: .init("com.apple.screenIsLocked"), object: nil, queue: .main) { _ in
            MainActor.assumeIsolated { BreakController.shared.userLeft { $0.isScreenLocked = true } }
        }
        distributed.addObserver(forName: .init("com.apple.screenIsUnlocked"), object: nil, queue: .main) { _ in
            MainActor.assumeIsolated { BreakController.shared.userCameBack { $0.isScreenLocked = false } }
        }

        let workspace = NSWorkspace.shared.notificationCenter
        workspace.addObserver(forName: NSWorkspace.willSleepNotification, object: nil, queue: .main) { _ in
            MainActor.assumeIsolated { BreakController.shared.userLeft { $0.isAsleep = true } }
        }
        workspace.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { _ in
            MainActor.assumeIsolated { BreakController.shared.userCameBack { $0.isAsleep = false } }
        }
    }

    private func userLeft(_ update: (BreakController) -> Void) {
        update(self)
        if awaySince == nil { awaySince = Date() }
        // Show the warning again in full when the user returns.
        if case .warning = phase {
            phase = .working(endsAt: Date().addingTimeInterval(Preferences.warningDuration))
        }
    }

    private func userCameBack(_ update: (BreakController) -> Void) {
        update(self)
        guard !isScreenLocked, !isAsleep, let since = awaySince else { return }
        awaySince = nil

        let away = Date().timeIntervalSince(since)
        guard away >= Preferences.breakDuration else { return }
        switch phase {
        case .working, .warning:
            startWork()
        case .onBreak, .finished, .paused:
            break
        }
    }
}

extension TimeInterval {
    /// "18:42", or "1:02:05" for an hour or more.
    var clockString: String {
        let total = Int(self.rounded(.up))
        let h = total / 3600, m = (total % 3600) / 60, s = total % 60
        return h > 0 ? String(format: "%d:%02d:%02d", h, m, s) : String(format: "%d:%02d", m, s)
    }
}
