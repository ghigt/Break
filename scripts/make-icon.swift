// Generates Resources/AppIcon.icns. Usage: swift scripts/make-icon.swift <output.icns>
import AppKit

let output = CommandLine.arguments.dropFirst().first ?? "Resources/AppIcon.icns"
let iconset = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("AppIcon.iconset")
try? FileManager.default.removeItem(at: iconset)
try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)

func render(_ pixels: Int) -> Data {
    let size = CGFloat(pixels)
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels,
                               bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                               colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

    // macOS icon grid: 824/1024 body with rounded corners.
    let inset = size * 100 / 1024
    let body = NSRect(x: inset, y: inset, width: size - 2 * inset, height: size - 2 * inset)
    let path = NSBezierPath(roundedRect: body, xRadius: body.width * 0.225, yRadius: body.width * 0.225)
    NSGradient(colors: [NSColor(red: 0.17, green: 0.23, blue: 0.40, alpha: 1),
                        NSColor(red: 0.48, green: 0.29, blue: 0.42, alpha: 1)])!
        .draw(in: path, angle: -60)

    // Cup with steam, same drawing as the menu bar icon, in white.
    // Drawn on a 24×24 grid with y pointing down, centered on the icon.
    let unit = body.width * 0.62 / 16
    let transform = NSAffineTransform()
    transform.translateX(by: size / 2, yBy: size / 2)
    transform.scaleX(by: unit, yBy: -unit)
    transform.translateX(by: -12.35, yBy: -9.3)
    transform.concat()

    let cup = NSBezierPath(ovalIn: NSRect(x: 4.5, y: 5.9, width: 13, height: 3.2))
    cup.move(to: NSPoint(x: 4.5, y: 7.5))
    cup.curve(to: NSPoint(x: 11, y: 16.3), controlPoint1: NSPoint(x: 4.5, y: 13), controlPoint2: NSPoint(x: 7, y: 16.3))
    cup.curve(to: NSPoint(x: 17.5, y: 7.5), controlPoint1: NSPoint(x: 15, y: 16.3), controlPoint2: NSPoint(x: 17.5, y: 13))
    cup.move(to: NSPoint(x: 17.1, y: 9.3))
    cup.curve(to: NSPoint(x: 20.2, y: 11.1), controlPoint1: NSPoint(x: 19.5, y: 8.8), controlPoint2: NSPoint(x: 20.5, y: 9.8))
    cup.curve(to: NSPoint(x: 16.3, y: 13.4), controlPoint1: NSPoint(x: 19.9, y: 12.4), controlPoint2: NSPoint(x: 18.5, y: 13.1))
    for x: CGFloat in [8.5, 11, 13.5] {
        cup.move(to: NSPoint(x: x, y: 1))
        cup.curve(to: NSPoint(x: x, y: 4.2), controlPoint1: NSPoint(x: x - 1, y: 2), controlPoint2: NSPoint(x: x + 1, y: 3.1))
    }
    cup.lineWidth = 1.5
    cup.lineCapStyle = .round
    cup.lineJoinStyle = .round
    NSColor.white.setStroke()
    cup.stroke()

    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

for points in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let name = scale == 1 ? "icon_\(points)x\(points).png" : "icon_\(points)x\(points)@2x.png"
        try render(points * scale).write(to: iconset.appendingPathComponent(name))
    }
}

let iconutil = Process()
iconutil.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
iconutil.arguments = ["-c", "icns", iconset.path, "-o", output]
try iconutil.run()
iconutil.waitUntilExit()
exit(iconutil.terminationStatus)
