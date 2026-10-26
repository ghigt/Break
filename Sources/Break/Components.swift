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

/// A button that fires only after being held down for `duration` seconds.
struct HoldToConfirmButton: View {
    var title: String
    var duration: TimeInterval = 3
    var action: () -> Void

    @State private var progress: CGFloat = 0
    @State private var holdTask: Task<Void, Never>?

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
                            .frame(width: geo.size.width * progress)
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
            .help("Hold for \(Int(duration)) seconds")
    }

    private func beginHold() {
        guard holdTask == nil else { return }
        withAnimation(.linear(duration: duration)) { progress = 1 }
        holdTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(duration))
            guard !Task.isCancelled else { return }
            holdTask = nil
            progress = 0
            action()
        }
    }

    private func cancelHold() {
        holdTask?.cancel()
        holdTask = nil
        withAnimation(.easeOut(duration: 0.25)) { progress = 0 }
    }
}
