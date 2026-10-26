import AppKit
import SwiftUI

/// Floating panel shown in the top-right corner during the pre-break warning.
/// It never activates the app, so typing elsewhere is not interrupted.
@MainActor
final class WarningPanelController {
    private var panel: NSPanel?

    func show() {
        guard panel == nil else { return }

        let hosting = NSHostingView(rootView: WarningView())
        let size = hosting.fittingSize
        let panel = WarningPanel(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.contentView = hosting
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.level = .statusBar
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]

        // The first screen is the one with the menu bar.
        if let screen = NSScreen.screens.first {
            let frame = screen.visibleFrame
            panel.setFrameOrigin(NSPoint(x: frame.maxX - size.width - 12, y: frame.maxY - size.height - 12))
        }
        panel.alphaValue = 0
        panel.orderFrontRegardless()
        NSAnimationContext.runAnimationGroup { $0.duration = 0.25; panel.animator().alphaValue = 1 }
        self.panel = panel
    }

    func hide() {
        panel?.orderOut(nil)
        panel = nil
    }
}

private final class WarningPanel: NSPanel {
    override var canBecomeKey: Bool { true }
}

struct WarningView: View {
    private let controller = BreakController.shared

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30)) { context in
            let remaining = controller.remaining(at: context.date) ?? 0
            HStack(spacing: 14) {
                ProgressRing(progress: remaining / Preferences.warningDuration, color: .orange, lineWidth: 5) {
                    Text(remaining.clockString)
                        .font(.system(size: 14, weight: .semibold).monospacedDigit())
                }
                .frame(width: 58, height: 58)

                VStack(alignment: .leading, spacing: 3) {
                    Text("Break starting soon")
                        .font(.system(size: 13, weight: .semibold))
                    Text("Finish your sentence, save your work.")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                    HStack(spacing: 6) {
                        Button("Snooze \(Preferences.snoozeMinutes) min") { controller.snooze() }
                        Button("Break now") { controller.breakNow() }
                            .buttonStyle(.borderedProminent)
                    }
                    .controlSize(.small)
                    .padding(.top, 6)
                }
            }
            .padding(14)
            .frame(width: 350, alignment: .leading)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(.white.opacity(0.12)))
        }
        .environment(\.colorScheme, .dark)
    }
}
