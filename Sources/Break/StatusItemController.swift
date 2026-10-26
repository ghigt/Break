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
    private lazy var pauseItem = item("", #selector(togglePause))
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
            pauseItem,
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

    // MARK: - Updates

    private func observe() {
        withObservationTracking {
            _ = controller.phase
            _ = controller.now
        } onChange: {
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
        case .paused:
            icon = IconState(progress: steps(progress), cupFilled: false, dimmed: true)
            status = String(localized: "Timer paused (\(time) left)")
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

    /// Redraw only when the ring visibly changes.
    private static let progressSteps = 200

    private func steps(_ progress: Double) -> Int {
        Int((min(max(progress, 0), 1) * Double(Self.progressSteps)).rounded())
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        let blocking = controller.isBlocking
        breakNowItem.isEnabled = !blocking
        pauseItem.isEnabled = !blocking
        pauseItem.title = controller.isPaused ? String(localized: "Resume timer") : String(localized: "Pause timer")
        restartItem.isEnabled = !blocking
        restartItem.title = String(localized: "Restart \(Preferences.workMinutes) min")
        update()
    }

    // MARK: - Actions

    @objc private func breakNow() { controller.breakNow() }
    @objc private func togglePause() { controller.togglePause() }
    @objc private func restart() { controller.startWork() }
    @objc private func openPreferences() { PreferencesWindowController.shared.show() }
    @objc private func quit() { NSApp.terminate(nil) }
}
