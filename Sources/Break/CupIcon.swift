import AppKit

/// Menu bar icon: a small cup inside a ring of five segments that light up as
/// the break approaches. Drawn on a 24×24 grid (y pointing down), scaled to
/// the menu bar size.
enum CupIcon {
    private static let size: CGFloat = 19

    // Ring
    private static let ringRadius: CGFloat = 10.6
    private static let segments = 5
    private static let segmentGap: CGFloat = 2.2 // arc length
    private static let trackWidth: CGFloat = 1.3
    private static let progressWidth: CGFloat = 1.8

    // Cup, drawn at full scale then shrunk into the ring.
    private static let cupScale: CGFloat = 0.62
    private static let cupCenter = NSPoint(x: 11.8, y: 11.6)
    private static let cupLineWidth: CGFloat = 1.3 / cupScale

    /// - Parameters:
    ///   - progress: 0 (cycle start) to 1 (break time).
    ///   - cupFilled: draws the cup full of coffee.
    ///   - dimmed: draws the icon faded, e.g. while breaks are disabled.
    static func image(progress: Double, cupFilled: Bool, dimmed: Bool = false) -> NSImage {
        let progress = CGFloat(min(max(progress, 0), 1))
        let image = NSImage(size: NSSize(width: size, height: size), flipped: true) { _ in
            guard let context = NSGraphicsContext.current?.cgContext else { return false }
            context.scaleBy(x: size / 24, y: size / 24)
            if dimmed {
                // One layer so overlapping strokes and fill fade evenly.
                context.setAlpha(0.45)
                context.beginTransparencyLayer(auxiliaryInfo: nil)
            }
            defer { if dimmed { context.endTransparencyLayer() } }

            drawRing(progress: progress)

            NSGraphicsContext.saveGraphicsState()
            let transform = NSAffineTransform()
            transform.translateX(by: 12, yBy: 12.3)
            transform.scale(by: cupScale)
            transform.translateX(by: -cupCenter.x, yBy: -cupCenter.y)
            transform.concat()
            drawCup(filled: cupFilled)
            NSGraphicsContext.restoreGraphicsState()
            return true
        }
        image.isTemplate = true
        image.accessibilityDescription = "Break"
        return image
    }

    // MARK: - Ring

    private static func drawRing(progress: CGFloat) {
        let center = NSPoint(x: 12, y: 12)
        let gap = segmentGap / ringRadius * 180 / .pi
        let span = 360 / CGFloat(segments)

        for i in 0..<segments {
            // Clockwise from the top (angles grow clockwise with y pointing down).
            let start = -90 + span * CGFloat(i)
            let length = span - gap

            let track = NSBezierPath()
            track.appendArc(withCenter: center, radius: ringRadius, startAngle: start, endAngle: start + length)
            track.lineWidth = trackWidth
            NSColor.black.withAlphaComponent(0.3).setStroke()
            track.stroke()

            let fill = min(max(progress * CGFloat(segments) - CGFloat(i), 0), 1)
            if fill > 0 {
                let arc = NSBezierPath()
                arc.appendArc(withCenter: center, radius: ringRadius, startAngle: start, endAngle: start + length * fill)
                arc.lineWidth = progressWidth
                NSColor.black.setStroke()
                arc.stroke()
            }
        }
    }

    // MARK: - Cup

    private static func drawCup(filled: Bool) {
        NSColor.black.set()
        if filled {
            let inside = bowlPath()
            inside.close()
            inside.fill()
            rimPath().fill()
        }
        for path in [rimPath(), bowlPath(), handlePath()] {
            path.lineWidth = cupLineWidth
            path.lineCapStyle = .round
            path.lineJoinStyle = .round
            path.stroke()
        }
    }

    /// Rim seen slightly from above.
    private static func rimPath() -> NSBezierPath {
        NSBezierPath(ovalIn: NSRect(x: 4.5, y: 5.9, width: 13, height: 3.2))
    }

    private static func bowlPath() -> NSBezierPath {
        let path = NSBezierPath()
        path.move(to: NSPoint(x: 4.5, y: 7.5))
        path.curve(to: NSPoint(x: 11, y: 16.3),
                   controlPoint1: NSPoint(x: 4.5, y: 13),
                   controlPoint2: NSPoint(x: 7, y: 16.3))
        path.curve(to: NSPoint(x: 17.5, y: 7.5),
                   controlPoint1: NSPoint(x: 15, y: 16.3),
                   controlPoint2: NSPoint(x: 17.5, y: 13))
        return path
    }

    private static func handlePath() -> NSBezierPath {
        let path = NSBezierPath()
        path.move(to: NSPoint(x: 17.1, y: 9.3))
        path.curve(to: NSPoint(x: 20.2, y: 11.1),
                   controlPoint1: NSPoint(x: 19.5, y: 8.8),
                   controlPoint2: NSPoint(x: 20.5, y: 9.8))
        path.curve(to: NSPoint(x: 16.3, y: 13.4),
                   controlPoint1: NSPoint(x: 19.9, y: 12.4),
                   controlPoint2: NSPoint(x: 18.5, y: 13.1))
        return path
    }
}
