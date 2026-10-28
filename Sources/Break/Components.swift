import Observation
import SwiftUI

/// Circular progress indicator; `progress` goes from 1 (full) to 0 (empty).
struct ProgressRing<Label: View>: View {
    var progress: Double
    var color: Color
    var lineWidth: CGFloat
    @ViewBuilder var label: Label

    var body: some View {
        ZStack {
            Circle().stroke(Color.white.opacity(0.12), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: min(max(progress, 0), 1))
                .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
            label
        }
    }
}

/// Progress of a press-and-hold. Kept outside the view instead of in `@State`:
/// SwiftUI's macros are missing from some Command Line Tools installs.
@MainActor
@Observable
final class HoldProgress {
    fileprivate(set) var progress: CGFloat = 0
    @ObservationIgnored fileprivate var task: Task<Void, Never>?
}

/// Text describing the hovered control. System tooltips open below the break
/// screen's window level, so they would never show there.
@MainActor
@Observable
final class HoverHint {
    var text: String?
}

/// A button that fires only after being held down for `duration` seconds.
struct HoldToConfirmButton: View {
    var title: String
    static let defaultDuration: TimeInterval = 2
    var duration: TimeInterval = defaultDuration
    let hold: HoldProgress
    var action: () -> Void

    var body: some View {
        Text(title)
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(.white.opacity(0.75))
            .padding(.horizontal, 18)
            .padding(.vertical, 9)
            .background {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.white.opacity(0.08))
                        Capsule().fill(Color.white.opacity(0.22))
                            .frame(width: geo.size.width * hold.progress)
                    }
                }
            }
            .overlay(Capsule().stroke(Color.white.opacity(0.2), lineWidth: 1))
            .clipShape(Capsule())
            .contentShape(Capsule())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in beginHold() }
                    .onEnded { _ in cancelHold() }
            )
    }

    private func beginHold() {
        guard hold.task == nil else { return }
        withAnimation(.linear(duration: duration)) { hold.progress = 1 }
        hold.task = Task { @MainActor [hold, duration, action] in
            try? await Task.sleep(for: .seconds(duration))
            guard !Task.isCancelled else { return }
            hold.task = nil
            hold.progress = 0
            action()
        }
    }

    private func cancelHold() {
        hold.task?.cancel()
        hold.task = nil
        withAnimation(.easeOut(duration: 0.25)) { hold.progress = 0 }
    }
}
