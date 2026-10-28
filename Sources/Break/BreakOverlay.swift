import AppKit
import SwiftUI

/// Full-screen windows covering every display during the break, plus kiosk
/// presentation options so the user cannot switch away.
@MainActor
final class BreakOverlayController {
    private var windows: [NSWindow] = []
    private var observers: [(NotificationCenter, NSObjectProtocol)] = []
    private var guardTimer: Timer?
    private var tip = ""
    /// The app in front before the overlay appeared, brought back when it goes away.
    private var previousApp: NSRunningApplication?
    private let hold = HoldProgress()
    private let hint = HoverHint()

    private static let tips = [
        String(localized: "Stand up, drink some water, look into the distance."),
        String(localized: "Stretch your shoulders and back."),
        String(localized: "Close your eyes and breathe deeply."),
        String(localized: "Walk around, open a window."),
        String(localized: "Look at something 20 feet away for 20 seconds."),
    ]

    private static let kioskOptions: NSApplication.PresentationOptions = [
        .hideDock,
        .hideMenuBar,
        .disableProcessSwitching,
        .disableForceQuit,
        .disableSessionTermination,
        .disableHideApplication,
        .disableAppleMenu,
    ]

    /// `newBreak` picks a new tip; otherwise the previous one is kept (after a peek).
    func show(newBreak: Bool) {
        guard windows.isEmpty else { return }
        if newBreak || tip.isEmpty { tip = Self.tips.randomElement() ?? "" }
        let frontmost = NSWorkspace.shared.frontmostApplication
        previousApp = frontmost == NSRunningApplication.current ? nil : frontmost
        buildWindows()
        enforce()
        observe()

        // Covers cases the notifications miss (e.g. a Spaces swipe).
        let timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.enforce() }
        }
        RunLoop.main.add(timer, forMode: .common)
        guardTimer = timer
    }

    func hide() {
        guard !windows.isEmpty else { return }
        guardTimer?.invalidate()
        guardTimer = nil
        observers.forEach { center, token in center.removeObserver(token) }
        observers = []
        windows.forEach { $0.orderOut(nil) }
        windows = []
        NSApp.presentationOptions = []
        previousApp?.activate()
        previousApp = nil
    }

    private func buildWindows() {
        windows.forEach { $0.orderOut(nil) }
        windows = NSScreen.screens.map { screen in
            let window = OverlayWindow(
                contentRect: screen.frame,
                styleMask: [.borderless],
                backing: .buffered,
                defer: false
            )
            window.setFrame(screen.frame, display: false)
            window.contentView = NSHostingView(rootView: OverlayView(tip: tip, hold: hold, hint: hint))
            window.isOpaque = false
            window.backgroundColor = .clear
            window.level = .screenSaver
            window.isReleasedWhenClosed = false
            window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
            return window
        }
    }

    private func enforce() {
        if !NSApp.isActive {
            NSApp.activate(ignoringOtherApps: true)
        }
        if NSApp.presentationOptions != Self.kioskOptions {
            NSApp.presentationOptions = Self.kioskOptions
        }
        let main = NSScreen.main ?? NSScreen.screens.first
        for window in windows {
            if window.frame == main?.frame, !window.isKeyWindow {
                window.makeKeyAndOrderFront(nil)
            } else {
                window.orderFrontRegardless()
            }
        }
    }

    private func observe() {
        let app = NotificationCenter.default
        let workspace = NSWorkspace.shared.notificationCenter
        add(app, NSApplication.didResignActiveNotification) { $0.enforce() }
        add(workspace, NSWorkspace.activeSpaceDidChangeNotification) { $0.enforce() }
        add(app, NSApplication.didChangeScreenParametersNotification) {
            $0.buildWindows()
            $0.enforce()
        }
    }

    private func add(_ center: NotificationCenter, _ name: Notification.Name, _ handler: @escaping (BreakOverlayController) -> Void) {
        let token = center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated {
                if let self { handler(self) }
            }
        }
        observers.append((center, token))
    }
}

private final class OverlayWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

struct OverlayView: View {
    var tip: String
    let hold: HoldProgress
    let hint: HoverHint
    private let controller = BreakController.shared

    var body: some View {
        ZStack {
            Rectangle().fill(.ultraThinMaterial)
            Color.black.opacity(0.55)

            switch controller.phase {
            case .onBreak(let startedAt, let endsAt):
                BreakInProgressView(startedAt: startedAt, endsAt: endsAt, tip: tip, hold: hold, hint: hint)
            default:
                BreakFinishedView()
            }
        }
        .ignoresSafeArea()
        .environment(\.colorScheme, .dark)
    }
}

private struct BreakInProgressView: View {
    var startedAt: Date
    var endsAt: Date
    var tip: String
    let hold: HoldProgress
    let hint: HoverHint

    var body: some View {
        VStack(spacing: 0) {
            TimelineView(.animation(minimumInterval: 1.0 / 30)) { context in
                let total = endsAt.timeIntervalSince(startedAt)
                let remaining = max(0, endsAt.timeIntervalSince(context.date))
                ProgressRing(progress: remaining / total, color: .green, lineWidth: 8) {
                    VStack(spacing: 2) {
                        Text("BREAK")
                            .font(.system(size: 13, weight: .medium))
                            .tracking(2)
                            .foregroundStyle(.white.opacity(0.55))
                        Text(remaining.clockString)
                            .font(.system(size: 64, weight: .ultraLight).monospacedDigit())
                    }
                }
                .frame(width: 260, height: 260)
            }
            .padding(.bottom, 28)

            Text(tip)
                .font(.system(size: 17))
                .foregroundStyle(.white.opacity(0.75))
                .padding(.bottom, 40)

            HStack(spacing: 12) {
                Button {
                    BreakController.shared.peek()
                } label: {
                    Label("Quick unlock", systemImage: "lock.open.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color(red: 0.45, green: 0.92, blue: 0.68))
                        .padding(.horizontal, 18)
                        .padding(.vertical, 9)
                        .background(Capsule().fill(Color.green.opacity(0.16)))
                        .overlay(Capsule().stroke(Color.green.opacity(0.45), lineWidth: 1))
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .onHover { hovering in
                    showHint(hovering, String(localized: "Pauses the break for \(Preferences.peekSeconds) seconds"))
                }

                HoldToConfirmButton(title: String(localized: "Skip the break"), hold: hold) {
                    BreakController.shared.skipBreak()
                }
                .onHover { hovering in
                    showHint(hovering, String(localized: "Hold for \(Int(HoldToConfirmButton.defaultDuration)) seconds"))
                }
            }

            Text(hint.text ?? " ")
                .font(.system(size: 12))
                .foregroundStyle(.white.opacity(0.5))
                .padding(.top, 12)
        }
        .foregroundStyle(.white)
    }

    private func showHint(_ hovering: Bool, _ text: String) {
        if hovering {
            hint.text = text
        } else if hint.text == text {
            hint.text = nil
        }
    }
}

private struct BreakFinishedView: View {
    var body: some View {
        VStack(spacing: 0) {
            Image(systemName: "checkmark")
                .font(.system(size: 40, weight: .semibold))
                .foregroundStyle(.green)
                .frame(width: 96, height: 96)
                .background(Circle().fill(Color.green.opacity(0.18)))
                .padding(.bottom, 24)

            Text("Break over")
                .font(.system(size: 34, weight: .medium))
                .padding(.bottom, 8)
            Text("Ready for \(Preferences.workMinutes) minutes of focus?")
                .font(.system(size: 17))
                .foregroundStyle(.white.opacity(0.7))
                .padding(.bottom, 32)

            Button {
                BreakController.shared.resume()
            } label: {
                Text("Resume  ↩︎")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Color(red: 0.02, green: 0.25, blue: 0.12))
                    .padding(.horizontal, 36)
                    .padding(.vertical, 12)
                    .background(Capsule().fill(Color(red: 0.24, green: 0.81, blue: 0.56)))
            }
            .buttonStyle(.plain)
            .keyboardShortcut(.defaultAction)
        }
        .foregroundStyle(.white)
    }
}
