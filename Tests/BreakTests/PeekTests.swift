import Foundation
import Testing
@testable import Break

extension ControllerTests {
    @MainActor
    struct PeekTests {
        let controller = BreakController.shared

        init() {
            Preferences.registerDefaults()
            controller.startWork()
        }

        @Test func peekPausesTheBreak() {
            controller.breakNow()
            guard case .onBreak(_, let endsAt) = controller.phase else {
                Issue.record("expected onBreak, got \(controller.phase)")
                return
            }
            controller.peek()
            guard case .peeking(_, let pausedEndsAt, _) = controller.phase else {
                Issue.record("expected peeking, got \(controller.phase)")
                return
            }
            #expect(controller.isBlocking)
            #expect(pausedEndsAt == endsAt.addingTimeInterval(Preferences.peekDuration))
            let remaining = controller.remaining(at: Date()) ?? 0
            #expect(remaining > Preferences.peekDuration - 2 && remaining <= Preferences.peekDuration)
        }

        @Test func endingPeekEarlyGivesTimeBack() {
            controller.breakNow()
            guard case .onBreak(_, let endsAt) = controller.phase else {
                Issue.record("expected onBreak, got \(controller.phase)")
                return
            }
            controller.peek()
            controller.endPeek()
            guard case .onBreak(_, let newEndsAt) = controller.phase else {
                Issue.record("expected onBreak, got \(controller.phase)")
                return
            }
            #expect(abs(newEndsAt.timeIntervalSince(endsAt)) < 1)
        }

        @Test func peekOnlyDuringBreak() {
            controller.peek()
            guard case .working = controller.phase else {
                Issue.record("expected working, got \(controller.phase)")
                return
            }
        }
    }
}
