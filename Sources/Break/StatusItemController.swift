import AppKit
import Observation

/// Menu bar icon and menu. Built with AppKit so the open menu is updated in
/// place rather than rebuilt every second.
@MainActor
final class StatusItemController: NSObject, NSMenuDelegate {
    private let controller = BreakController.shared
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let menu = NSMenu()

    private let statusLine = NSMenuItem(title: "", action: nil, keyEquivalent: "")
    private lazy var breakNowItem = item(String(localized: "Break now"), #selector(breakNow))
    private lazy var disableItem = disableMenuItem()
    private lazy var enableItem = item(String(localized: "Turn Break back on"), #selector(enable))
    private lazy var restartItem = item("", #selector(restart))

    private var lastIcon: IconState?

    private struct IconState: Equatable {
        var progress: Int
        var cupFilled: Bool
        var dimmed: Bool
    }

    override init() {
        super.init()
        statusLine.isEnabled = false

        menu.autoenablesItems = false
        menu.delegate = self
        menu.items = [
            statusLine,
            .separator(),
            breakNowItem,
            disableItem,
            enableItem,
            restartItem,
            .separator(),
            item(String(localized: "Settings…"), #selector(openPreferences), key: ","),
            item(String(localized: "Quit Break"), #selector(quit), key: "q"),
        ]
        statusItem.menu = menu

        update()
        observe()
    }

    private func item(_ title: String, _ action: Selector, key: String = "") -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        item.target = self
        return item
    }

    private func disableMenuItem() -> NSMenuItem {
        let minute = Preferences.secondsPerMinute
        let choices: [(String, TimeInterval?)] = [
            (String(localized: "For 30 minutes"), 30 * minute),
            (String(localized: "For 1 hour"), 60 * minute),
            (String(localized: "For 2 hours"), 120 * minute),
        ]
        let submenu = NSMenu()
        for (title, duration) in choices {
            let choice = item(title, #selector(disableFor(_:)))
            choice.representedObject = duration
            submenu.addItem(choice)
        }
        submenu.addItem(item(String(localized: "Until tomorrow"), #selector(disableUntilTomorrow)))
        submenu.addItem(.separator())
        submenu.addItem(item(String(localized: "Until I turn it back on"), #selector(disableFor(_:))))

        let disable = NSMenuItem(title: String(localized: "Disable"), action: nil, keyEquivalent: "")
        disable.submenu = submenu
        return disable
    }

    // MARK: - Updates

    private func observe() {
        withObservationTracking {
            _ = controller.phase
            _ = controller.now
        } onChange: { [weak self] in
            Task { @MainActor [weak self] in
                self?.update()
                self?.observe()
            }
        }
    }

    private func update() {
        let remaining = controller.remaining(at: controller.now)
        let time = remaining?.clockString ?? ""
        // The ring fills up over the work period.
        let progress = 1 - (remaining ?? 0) / Preferences.workDuration
        let icon: IconState
        let status: String
        switch controller.phase {
        case .working:
            icon = IconState(progress: steps(progress), cupFilled: false, dimmed: false)
            status = String(localized: "Next break in \(time)")
        case .warning:
            // Full ring, blinking cup.
            let blink = Int(controller.now.timeIntervalSinceReferenceDate) % 2 == 0
            icon = IconState(progress: Self.progressSteps, cupFilled: blink, dimmed: false)
            status = String(localized: "Break in \(time)")
        case .disabled(let until):
            icon = IconState(progress: 0, cupFilled: false, dimmed: true)
            status = Self.disabledStatus(until: until)
        case .onBreak, .finished:
            icon = IconState(progress: Self.progressSteps, cupFilled: true, dimmed: false)
            status = String(localized: "On break")
        }

        if icon != lastIcon, let button = statusItem.button {
            button.image = CupIcon.image(
                progress: Double(icon.progress) / Double(Self.progressSteps),
                cupFilled: icon.cupFilled,
                dimmed: icon.dimmed
            )
            lastIcon = icon
        }

        if statusLine.title != status { statusLine.title = status }
    }

    private static func disabledStatus(until: Date?) -> String {
        guard let until else { return String(localized: "Disabled") }
        if Calendar.current.startOfDay(for: until) == until, !Calendar.current.isDateInToday(until) {
            return String(localized: "Disabled until tomorrow")
        }
        let time = until.formatted(date: .omitted, time: .shortened)
        return String(localized: "Disabled until \(time)")
    }

    /// Redraw only when the ring visibly changes.
    private static let progressSteps = 200

    private func steps(_ progress: Double) -> Int {
        Int((min(max(progress, 0), 1) * Double(Self.progressSteps)).rounded())
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        let blocking = controller.isBlocking
        breakNowItem.isEnabled = !blocking
        disableItem.isEnabled = !blocking
        disableItem.isHidden = controller.isDisabled
        enableItem.isHidden = !controller.isDisabled
        restartItem.isEnabled = !blocking
        restartItem.title = String(localized: "Restart \(Preferences.workMinutes) min")
        update()
    }

    // MARK: - Actions

    @objc private func breakNow() { controller.breakNow() }
    @objc private func disableFor(_ sender: NSMenuItem) { controller.disable(for: sender.representedObject as? TimeInterval) }
    @objc private func disableUntilTomorrow() { controller.disableUntilTomorrow() }
    @objc private func enable() { controller.enable() }
    @objc private func restart() { controller.startWork() }
    @objc private func openPreferences() { PreferencesWindowController.shared.show() }
    @objc private func quit() { NSApp.terminate(nil) }
}
