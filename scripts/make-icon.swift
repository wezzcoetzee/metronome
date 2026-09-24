// Renders Resources/AppIcon.icns: a white metronome on a true black squircle.
// Run: swift scripts/make-icon.swift
import AppKit

func render(size: CGFloat) -> Data {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(size), pixelsHigh: Int(size), bitsPerSample: 8,
                               samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let s = size / 1024

    // macOS icon grid: 824pt body inset in a 1024 canvas.
    let body = NSRect(x: 100 * s, y: 100 * s, width: 824 * s, height: 824 * s)
    NSColor.black.setFill()
    NSBezierPath(roundedRect: body, xRadius: 185 * s, yRadius: 185 * s).fill()
    NSColor(white: 0.18, alpha: 1).setStroke()
    let rim = NSBezierPath(roundedRect: body.insetBy(dx: 2 * s, dy: 2 * s), xRadius: 183 * s, yRadius: 183 * s)
    rim.lineWidth = 4 * s
    rim.stroke()

    // Metronome body: a trapezoid outline.
    let outline = NSBezierPath()
    outline.move(to: NSPoint(x: 300 * s, y: 250 * s))
    outline.line(to: NSPoint(x: 724 * s, y: 250 * s))
    outline.line(to: NSPoint(x: 590 * s, y: 780 * s))
    outline.line(to: NSPoint(x: 434 * s, y: 780 * s))
    outline.close()
    outline.lineWidth = 44 * s
    outline.lineJoinStyle = .round
    NSColor.white.setStroke()
    outline.stroke()

    // Base line and tilted pendulum with its weight.
    let base = NSBezierPath()
    base.move(to: NSPoint(x: 330 * s, y: 360 * s))
    base.line(to: NSPoint(x: 694 * s, y: 360 * s))
    base.lineWidth = 36 * s
    base.stroke()

    let pivot = NSPoint(x: 512 * s, y: 360 * s)
    let tip = NSPoint(x: 555 * s, y: 690 * s)
    let arm = NSBezierPath()
    arm.move(to: pivot)
    arm.line(to: tip)
    arm.lineWidth = 36 * s
    arm.lineCapStyle = .round
    arm.stroke()

    let weight = NSPoint(x: pivot.x + (tip.x - pivot.x) * 0.62, y: pivot.y + (tip.y - pivot.y) * 0.62)
    NSColor.white.setFill()
    NSBezierPath(roundedRect: NSRect(x: weight.x - 48 * s, y: weight.y - 30 * s, width: 96 * s, height: 60 * s), xRadius: 12 * s, yRadius: 12 * s).fill()

    NSGraphicsContext.current = nil
    return rep.representation(using: .png, properties: [:])!
}

let fm = FileManager.default
let iconset = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("AppIcon.iconset")
try? fm.removeItem(at: iconset)
try fm.createDirectory(at: iconset, withIntermediateDirectories: true)
for points in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let name = scale == 1 ? "icon_\(points)x\(points).png" : "icon_\(points)x\(points)@2x.png"
        try render(size: CGFloat(points * scale)).write(to: iconset.appendingPathComponent(name))
    }
}
try render(size: 1024).write(to: URL(fileURLWithPath: "Resources/AppIcon.png"))

let task = Process()
task.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
task.arguments = ["-c", "icns", iconset.path, "-o", "Resources/AppIcon.icns"]
try task.run()
task.waitUntilExit()
print("Wrote Resources/AppIcon.icns")
