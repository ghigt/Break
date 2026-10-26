import AppKit
import ServiceManagement
import SwiftUI

@MainActor
final class PreferencesWindowController {
    static let shared = PreferencesWindowController()

    private var window: NSWindow?

    func show() {
        if window == nil {
            let window = NSWindow(contentViewController: NSHostingController(rootView: PreferencesView()))
            window.title = String(localized: "Break Settings")
            window.styleMask = [.titled, .closable]
            window.isReleasedWhenClosed = false
            window.center()
            self.window = window
        }
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }
}

struct PreferencesView: View {
    @AppStorage(Preferences.Key.workMinutes) private var workMinutes = Preferences.Default.workMinutes
    @AppStorage(Preferences.Key.breakMinutes) private var breakMinutes = Preferences.Default.breakMinutes
    @AppStorage(Preferences.Key.warningMinutes) private var warningMinutes = Preferences.Default.warningMinutes
    @AppStorage(Preferences.Key.snoozeMinutes) private var snoozeMinutes = Preferences.Default.snoozeMinutes
    @AppStorage(Preferences.Key.soundsEnabled) private var soundsEnabled = Preferences.Default.soundsEnabled

    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    @State private var loginError: String?

    var body: some View {
        Form {
            Section {
                stepper("Work", value: $workMinutes, range: 5...120, step: 5)
                stepper("Break", value: $breakMinutes, range: 1...30)
                stepper("Warning", value: $warningMinutes, range: 1...5)
                stepper("Snooze", value: $snoozeMinutes, range: 1...15)
            } header: {
                Text("Durations")
            } footer: {
                Text("New durations apply from the next cycle.")
                    .foregroundStyle(.secondary)
            }

            Section("Options") {
                Toggle("Play sounds", isOn: $soundsEnabled)
                Toggle("Open Break at login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, enabled in setLaunchAtLogin(enabled) }
                if let loginError {
                    Text(loginError).font(.caption).foregroundStyle(.red)
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 380)
        .fixedSize(horizontal: false, vertical: true)
    }

    private func stepper(_ title: LocalizedStringKey, value: Binding<Int>, range: ClosedRange<Int>, step: Int = 1) -> some View {
        Stepper(value: value, in: range, step: step) {
            LabeledContent(title, value: String(localized: "\(value.wrappedValue) min"))
        }
    }

    private func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            loginError = nil
        } catch {
            loginError = error.localizedDescription
            launchAtLogin = SMAppService.mainApp.status == .enabled
        }
    }
}
