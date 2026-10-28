import Foundation
import Testing
@testable import Break

/// Every suite drives the shared controller, so they must not run in parallel.
@MainActor
@Suite(.serialized)
enum ControllerTests {}

extension ControllerTests {
    @MainActor
    struct DisableTests {
        let controller = BreakController.shared

        init() {
            Preferences.registerDefaults()
            controller.startWork()
        }

        @Test func disableForDuration() {
            controller.disable(for: 60)
            #expect(controller.isDisabled)
            let remaining = controller.remaining(at: Date()) ?? 0
            #expect(remaining > 58 && remaining <= 60)
        }

        @Test func disableUntilTurnedBackOn() {
            controller.disable(for: nil)
            #expect(controller.phase == .disabled(until: nil))
            #expect(controller.remaining(at: Date()) == nil)
        }

        @Test func enableStartsFreshCycle() {
            controller.disable(for: nil)
            controller.enable()
            guard case .working(let endsAt) = controller.phase else {
                Issue.record("expected working, got \(controller.phase)")
                return
            }
            #expect(abs(endsAt.timeIntervalSinceNow - Preferences.workDuration) < 2)
        }

        @Test func expiredDisableResumesWork() {
            controller.disable(for: -1)
            controller.tick()
            guard case .working = controller.phase else {
                Issue.record("expected working, got \(controller.phase)")
                return
            }
        }

        @Test func disableUntilTomorrowEndsAtMidnight() {
            controller.disableUntilTomorrow()
            guard case .disabled(let until?) = controller.phase else {
                Issue.record("expected disabled until a date, got \(controller.phase)")
                return
            }
            let calendar = Calendar.current
            #expect(calendar.isDateInTomorrow(until))
            #expect(calendar.startOfDay(for: until) == until)
        }
    }
}
