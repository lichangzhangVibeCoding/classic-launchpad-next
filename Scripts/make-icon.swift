import AppKit

let canvas: CGFloat = 1024
let image = NSImage(size: NSSize(width: canvas, height: canvas))
image.lockFocus()

let iconRect = NSRect(x: 0, y: 0, width: canvas, height: canvas)
let squircle = NSBezierPath(roundedRect: iconRect, xRadius: 230, yRadius: 230)
squircle.addClip()

let background = NSGradient(colors: [
    NSColor(calibratedRed: 0.99, green: 0.99, blue: 1.0, alpha: 1),
    NSColor(calibratedRed: 0.93, green: 0.94, blue: 0.96, alpha: 1)
])
background?.draw(in: iconRect, angle: -90)

NSColor.white.withAlphaComponent(0.55).setStroke()
let edge = NSBezierPath(roundedRect: iconRect.insetBy(dx: 1, dy: 1), xRadius: 229, yRadius: 229)
edge.lineWidth = 2
edge.stroke()

func pill(_ rect: NSRect, radius: CGFloat) -> NSBezierPath {
    NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)
}

let search = NSRect(x: (canvas - 590) / 2, y: 690, width: 590, height: 112)
let searchPath = pill(search, radius: 56)
let searchFill = NSGradient(colors: [
    NSColor(calibratedWhite: 0.78, alpha: 1),
    NSColor(calibratedWhite: 0.68, alpha: 1)
])
NSGraphicsContext.saveGraphicsState()
let searchShadow = NSShadow()
searchShadow.shadowColor = NSColor.black.withAlphaComponent(0.08)
searchShadow.shadowBlurRadius = 10
searchShadow.shadowOffset = NSSize(width: 0, height: -3)
searchShadow.set()
searchFill?.draw(in: searchPath, angle: -90)
NSGraphicsContext.restoreGraphicsState()

let glass = NSColor(calibratedWhite: 0.42, alpha: 1)
glass.setStroke()
let ring = NSBezierPath(ovalIn: NSRect(x: search.minX + 36, y: search.midY - 16, width: 34, height: 34))
ring.lineWidth = 6
ring.stroke()
let handle = NSBezierPath()
handle.move(to: NSPoint(x: search.minX + 66, y: search.midY - 12))
handle.line(to: NSPoint(x: search.minX + 80, y: search.midY - 26))
handle.lineWidth = 6
handle.lineCapStyle = .round
handle.stroke()

let colors: [NSColor] = [
    NSColor(calibratedRed: 1.00, green: 0.62, blue: 0.04, alpha: 1),
    NSColor(calibratedRed: 1.00, green: 0.22, blue: 0.38, alpha: 1),
    NSColor(calibratedRed: 0.18, green: 0.82, blue: 0.42, alpha: 1),
    NSColor(calibratedRed: 0.04, green: 0.52, blue: 1.00, alpha: 1),
    NSColor(calibratedRed: 0.35, green: 0.82, blue: 1.00, alpha: 1),
    NSColor(calibratedRed: 1.00, green: 0.78, blue: 0.08, alpha: 1)
]
let tile: CGFloat = 168
let gap: CGFloat = 30
let gridWidth = tile * 3 + gap * 2
let originX = (canvas - gridWidth) / 2
let rowY: [CGFloat] = [496, 298]

for index in colors.indices {
    let column = index % 3
    let row = index / 3
    let rect = NSRect(x: originX + CGFloat(column) * (tile + gap), y: rowY[row], width: tile, height: tile)
    let path = NSBezierPath(roundedRect: rect, xRadius: 40, yRadius: 40)
    let base = colors[index]
    let lifted = base.blended(withFraction: 0.34, of: .white) ?? base
    NSGraphicsContext.saveGraphicsState()
    let glow = NSShadow()
    glow.shadowColor = base.withAlphaComponent(0.42)
    glow.shadowBlurRadius = 16
    glow.shadowOffset = NSSize(width: 0, height: -1)
    glow.set()
    NSGradient(colors: [lifted, base])?.draw(in: path, angle: -90)
    NSGraphicsContext.restoreGraphicsState()
}

image.unlockFocus()

let out = URL(fileURLWithPath: CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "/tmp/launchpad-icon.png")
guard let tiff = image.tiffRepresentation,
      let rep = NSBitmapImageRep(data: tiff),
      let png = rep.representation(using: .png, properties: [:]) else {
    fputs("failed to encode icon\n", stderr)
    exit(1)
}
try png.write(to: out)
print(out.path)
