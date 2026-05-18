import AppKit
import Foundation

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let resources = root.appendingPathComponent("Resources", isDirectory: true)
let iconset = resources.appendingPathComponent("AppIcon.iconset", isDirectory: true)
try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)

let renditions: [(base: Int, scale: Int, name: String)] = [
    (16, 1, "icon_16x16.png"),
    (16, 2, "icon_16x16@2x.png"),
    (32, 1, "icon_32x32.png"),
    (32, 2, "icon_32x32@2x.png"),
    (128, 1, "icon_128x128.png"),
    (128, 2, "icon_128x128@2x.png"),
    (256, 1, "icon_256x256.png"),
    (256, 2, "icon_256x256@2x.png"),
    (512, 1, "icon_512x512.png"),
    (512, 2, "icon_512x512@2x.png")
]

func drawIcon(size: CGFloat) -> NSImage {
    let image = NSImage(size: NSSize(width: size, height: size))
    image.lockFocus()
    defer { image.unlockFocus() }

    NSGraphicsContext.current?.imageInterpolation = .high
    NSColor.clear.setFill()
    NSRect(x: 0, y: 0, width: size, height: size).fill()

    let inset = size * 0.055
    let outer = NSRect(x: inset, y: inset, width: size - inset * 2, height: size - inset * 2)
    let outerPath = NSBezierPath(roundedRect: outer, xRadius: size * 0.22, yRadius: size * 0.22)
    NSGradient(colors: [
        NSColor(calibratedRed: 0.08, green: 0.13, blue: 0.22, alpha: 1),
        NSColor(calibratedRed: 0.07, green: 0.34, blue: 0.28, alpha: 1)
    ])?.draw(in: outerPath, angle: -38)

    NSColor(calibratedWhite: 1, alpha: 0.13).setStroke()
    outerPath.lineWidth = max(1, size * 0.018)
    outerPath.stroke()

    let card = outer.insetBy(dx: size * 0.13, dy: size * 0.16)
    let cardPath = NSBezierPath(roundedRect: card, xRadius: size * 0.06, yRadius: size * 0.06)
    NSColor(calibratedWhite: 0.04, alpha: 0.50).setFill()
    cardPath.fill()

    let trackRect = NSRect(x: card.minX + size * 0.08, y: card.maxY - size * 0.21, width: card.width - size * 0.16, height: size * 0.035)
    let track = NSBezierPath(roundedRect: trackRect, xRadius: trackRect.height / 2, yRadius: trackRect.height / 2)
    NSColor(calibratedWhite: 1, alpha: 0.18).setFill()
    track.fill()

    let progressRect = NSRect(x: trackRect.minX, y: trackRect.minY, width: trackRect.width * 0.68, height: trackRect.height)
    let progress = NSBezierPath(roundedRect: progressRect, xRadius: progressRect.height / 2, yRadius: progressRect.height / 2)
    NSColor(calibratedRed: 0.08, green: 0.80, blue: 0.40, alpha: 1).setFill()
    progress.fill()

    let lineColor = NSColor(calibratedWhite: 1, alpha: 0.86)
    let mutedLineColor = NSColor(calibratedWhite: 1, alpha: 0.35)
    let rowY = [card.midY + size * 0.06, card.midY - size * 0.055, card.midY - size * 0.17]
    for (index, y) in rowY.enumerated() {
        let boxSize = size * 0.075
        let box = NSRect(x: card.minX + size * 0.08, y: y - boxSize / 2, width: boxSize, height: boxSize)
        let boxPath = NSBezierPath(roundedRect: box, xRadius: size * 0.014, yRadius: size * 0.014)
        (index < 2 ? NSColor(calibratedRed: 0.08, green: 0.80, blue: 0.40, alpha: 1) : NSColor.clear).setFill()
        boxPath.fill()
        (index < 2 ? NSColor(calibratedRed: 0.08, green: 0.80, blue: 0.40, alpha: 1) : mutedLineColor).setStroke()
        boxPath.lineWidth = max(1, size * 0.012)
        boxPath.stroke()

        let line = NSBezierPath()
        line.move(to: NSPoint(x: box.maxX + size * 0.045, y: y))
        line.line(to: NSPoint(x: card.maxX - size * 0.08, y: y))
        (index < 2 ? lineColor : mutedLineColor).setStroke()
        line.lineWidth = max(1.5, size * 0.022)
        line.lineCapStyle = .round
        line.stroke()
    }

    return image
}

func writePNG(_ image: NSImage, to url: URL) throws {
    guard let tiff = image.tiffRepresentation,
          let rep = NSBitmapImageRep(data: tiff),
          let png = rep.representation(using: .png, properties: [:]) else {
        throw CocoaError(.fileWriteUnknown)
    }
    try png.write(to: url, options: [.atomic])
}

for rendition in renditions {
    let pixelSize = CGFloat(rendition.base * rendition.scale)
    try writePNG(drawIcon(size: pixelSize), to: iconset.appendingPathComponent(rendition.name))
}

let process = Process()
process.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
process.arguments = [
    "-c", "icns",
    iconset.path,
    "-o", resources.appendingPathComponent("AppIcon.icns").path
]
try process.run()
process.waitUntilExit()
guard process.terminationStatus == 0 else {
    throw CocoaError(.fileWriteUnknown)
}

print("Generated \(resources.appendingPathComponent("AppIcon.icns").path)")
