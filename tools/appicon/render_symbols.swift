import AppKit
import Foundation

let names = [
    "figure.strengthtraining.functional",
    "figure.strengthtraining.traditional",
    "figure.core.training",
    "figure.cooldown",
    "figure.mind.and.body",
]

let outDir = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "."
let canvas = 1024

func render(_ symbolName: String, to path: String) -> Bool {
    guard let base = NSImage(systemSymbolName: symbolName, accessibilityDescription: nil) else {
        return false
    }
    let config = NSImage.SymbolConfiguration(pointSize: 700, weight: .semibold)
    guard let symbol = base.withSymbolConfiguration(config) else { return false }

    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: canvas,
        pixelsHigh: canvas,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    )!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    NSColor.clear.setFill()
    NSRect(x: 0, y: 0, width: canvas, height: canvas).fill()

    let size = symbol.size
    let scale = min(Double(canvas) * 0.86 / size.width, Double(canvas) * 0.86 / size.height)
    let drawSize = NSSize(width: size.width * scale, height: size.height * scale)
    let rect = NSRect(
        x: (Double(canvas) - drawSize.width) / 2,
        y: (Double(canvas) - drawSize.height) / 2,
        width: drawSize.width,
        height: drawSize.height
    )
    symbol.draw(in: rect, from: .zero, operation: .sourceOver, fraction: 1.0)
    NSGraphicsContext.restoreGraphicsState()

    guard let data = rep.representation(using: .png, properties: [:]) else { return false }
    try? data.write(to: URL(fileURLWithPath: path))
    return true
}

for name in names {
    let path = (outDir as NSString).appendingPathComponent("symbol-\(name).png")
    let ok = render(name, to: path)
    print("\(ok ? "ok  " : "FAIL") \(name)")
}
