import AppKit

let outputDir = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    .appendingPathComponent("assets/images")

try? FileManager.default.createDirectory(
    at: outputDir,
    withIntermediateDirectories: true
)

func saveImage(_ image: NSImage, to url: URL, quality: CGFloat = 0.92) throws {
    guard
        let tiff = image.tiffRepresentation,
        let bitmap = NSBitmapImageRep(data: tiff),
        let data = bitmap.representation(using: .jpeg, properties: [.compressionFactor: quality])
    else {
        throw NSError(domain: "imagegen", code: 1)
    }
    try data.write(to: url)
}

func drawBackground() -> NSImage {
    let size = NSSize(width: 1080, height: 1920)
    let image = NSImage(size: size)
    image.lockFocus()

    let rect = NSRect(origin: .zero, size: size)
    let bg = NSGradient(colors: [
        NSColor(calibratedRed: 0.03, green: 0.05, blue: 0.10, alpha: 1),
        NSColor(calibratedRed: 0.05, green: 0.09, blue: 0.16, alpha: 1),
        NSColor(calibratedRed: 0.10, green: 0.13, blue: 0.21, alpha: 1),
    ])!
    bg.draw(in: rect, angle: -90)

    let referenceURL = outputDir.appendingPathComponent("title_background.jpg")
    if let referenceImage = NSImage(contentsOf: referenceURL) {
        let sourceSize = referenceImage.size
        let scale = max(size.width / sourceSize.width, size.height / sourceSize.height)
        let drawSize = NSSize(width: sourceSize.width * scale, height: sourceSize.height * scale)
        let drawRect = NSRect(
            x: (size.width - drawSize.width) / 2,
            y: (size.height - drawSize.height) / 2,
            width: drawSize.width,
            height: drawSize.height
        )
        referenceImage.draw(in: drawRect, from: .zero, operation: .sourceOver, fraction: 0.56)
    }

    let haze = NSGradient(colors: [
        NSColor(calibratedRed: 0.02, green: 0.04, blue: 0.08, alpha: 0.18),
        NSColor(calibratedRed: 0.02, green: 0.04, blue: 0.08, alpha: 0.48),
        NSColor(calibratedRed: 0.01, green: 0.02, blue: 0.04, alpha: 0.70),
    ])!
    haze.draw(in: rect, angle: -90)

    let glowColors: [NSColor] = [
        NSColor(calibratedRed: 0.16, green: 0.74, blue: 0.95, alpha: 0.28),
        NSColor(calibratedRed: 0.97, green: 0.47, blue: 0.22, alpha: 0.18),
        NSColor(calibratedRed: 0.34, green: 0.56, blue: 0.98, alpha: 0.16),
        NSColor(calibratedRed: 0.98, green: 0.78, blue: 0.34, alpha: 0.14),
    ]
    let glowRects = [
        NSRect(x: -200, y: 1260, width: 760, height: 760),
        NSRect(x: 650, y: 910, width: 520, height: 520),
        NSRect(x: 120, y: 180, width: 780, height: 780),
        NSRect(x: 580, y: 1520, width: 360, height: 360),
    ]

    for (index, glowRect) in glowRects.enumerated() {
        let path = NSBezierPath(ovalIn: glowRect)
        glowColors[index].setFill()
        path.fill()
    }

    NSColor(calibratedWhite: 1, alpha: 0.08).setStroke()
    for i in 0..<7 {
        let inset = CGFloat(i) * 20
        let frame = NSRect(x: 38 + inset, y: 86 + inset, width: 1004 - inset * 2, height: 1748 - inset * 2)
        let path = NSBezierPath(roundedRect: frame, xRadius: 50, yRadius: 50)
        path.lineWidth = i == 0 ? 3.8 : 1.1
        path.stroke()
    }

    let lineColor = NSColor(calibratedRed: 0.54, green: 0.77, blue: 1.0, alpha: 0.14)
    lineColor.setStroke()
    for y in stride(from: 240.0, through: 1740.0, by: 120.0) {
        let path = NSBezierPath()
        path.move(to: NSPoint(x: 88, y: y))
        path.curve(
            to: NSPoint(x: 992, y: y + 28),
            controlPoint1: NSPoint(x: 280, y: y + 54),
            controlPoint2: NSPoint(x: 740, y: y - 52)
        )
        path.lineWidth = 1.1
        path.stroke()
    }

    let cardFrames: [(NSRect, NSColor)] = [
        (NSRect(x: 94, y: 1170, width: 250, height: 360), NSColor(calibratedRed: 0.20, green: 0.83, blue: 0.98, alpha: 0.10)),
        (NSRect(x: 736, y: 1110, width: 250, height: 360), NSColor(calibratedRed: 1.00, green: 0.50, blue: 0.30, alpha: 0.10)),
        (NSRect(x: 720, y: 310, width: 220, height: 320), NSColor(calibratedRed: 0.95, green: 0.78, blue: 0.30, alpha: 0.08)),
    ]

    for (cardRect, tint) in cardFrames {
        let card = NSBezierPath(roundedRect: cardRect, xRadius: 24, yRadius: 24)
        tint.setFill()
        card.fill()
        NSColor(calibratedWhite: 1, alpha: 0.12).setStroke()
        card.lineWidth = 2.0
        card.stroke()

        let inner = cardRect.insetBy(dx: 16, dy: 16)
        let innerPath = NSBezierPath(roundedRect: inner, xRadius: 16, yRadius: 16)
        NSColor(calibratedWhite: 1, alpha: 0.08).setStroke()
        innerPath.lineWidth = 1.2
        innerPath.stroke()
    }

    let sigilStroke = NSColor(calibratedRed: 0.84, green: 0.93, blue: 1.0, alpha: 0.26)
    sigilStroke.setStroke()
    let sigil = NSBezierPath()
    sigil.move(to: NSPoint(x: 540, y: 1030))
    sigil.line(to: NSPoint(x: 640, y: 880))
    sigil.line(to: NSPoint(x: 540, y: 720))
    sigil.line(to: NSPoint(x: 440, y: 880))
    sigil.close()
    sigil.lineWidth = 3
    sigil.stroke()

    let ring = NSBezierPath(ovalIn: NSRect(x: 370, y: 700, width: 340, height: 340))
    ring.lineWidth = 2
    ring.stroke()

    let bottomMist = NSGradient(colors: [
        NSColor(calibratedWhite: 1.0, alpha: 0.00),
        NSColor(calibratedRed: 0.16, green: 0.32, blue: 0.62, alpha: 0.12),
        NSColor(calibratedRed: 0.02, green: 0.04, blue: 0.08, alpha: 0.58),
    ])!
    bottomMist.draw(in: NSRect(x: 0, y: 0, width: 1080, height: 760), angle: -90)

    let vignette = NSGradient(colors: [
        NSColor(calibratedWhite: 0.0, alpha: 0.46),
        NSColor(calibratedWhite: 0.0, alpha: 0.02),
        NSColor(calibratedWhite: 0.0, alpha: 0.48),
    ])!
    vignette.draw(in: rect, relativeCenterPosition: NSPoint(x: 0, y: 0))

    let title = "AR CARD BATTLE"
    let subtitle = "Scan. Summon. Clash."
    let titleStyle = NSMutableParagraphStyle()
    titleStyle.alignment = .center
    let titleAttrs: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: 78, weight: .black),
        .foregroundColor: NSColor(calibratedWhite: 1, alpha: 0.95),
        .kern: 6.0,
        .paragraphStyle: titleStyle,
    ]
    let subtitleAttrs: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: 28, weight: .semibold),
        .foregroundColor: NSColor(calibratedRed: 0.70, green: 0.84, blue: 0.98, alpha: 0.82),
        .kern: 2.4,
        .paragraphStyle: titleStyle,
    ]
    title.draw(in: NSRect(x: 120, y: 1460, width: 840, height: 120), withAttributes: titleAttrs)
    subtitle.draw(in: NSRect(x: 180, y: 1398, width: 720, height: 48), withAttributes: subtitleAttrs)

    image.unlockFocus()
    return image
}

func drawButton(primary: NSColor, secondary: NSColor, edge: NSColor) -> NSImage {
    let size = NSSize(width: 880, height: 180)
    let image = NSImage(size: size)
    image.lockFocus()

    let shadow = NSShadow()
    shadow.shadowBlurRadius = 24
    shadow.shadowColor = primary.withAlphaComponent(0.45)
    shadow.shadowOffset = NSSize(width: 0, height: -10)
    shadow.set()

    let outer = NSBezierPath(roundedRect: NSRect(x: 8, y: 14, width: 864, height: 144), xRadius: 34, yRadius: 34)
    let fill = NSGradient(colors: [primary, secondary])!
    fill.draw(in: outer, angle: 0)

    NSGraphicsContext.current?.saveGraphicsState()
    let clip = NSBezierPath(roundedRect: NSRect(x: 8, y: 14, width: 864, height: 144), xRadius: 34, yRadius: 34)
    clip.addClip()
    let gloss = NSGradient(colors: [
        NSColor(calibratedWhite: 1.0, alpha: 0.22),
        NSColor(calibratedWhite: 1.0, alpha: 0.02),
    ])!
    gloss.draw(in: NSRect(x: 8, y: 82, width: 864, height: 76), angle: -90)
    NSGraphicsContext.current?.restoreGraphicsState()

    edge.setStroke()
    outer.lineWidth = 3
    outer.stroke()

    let inner = NSBezierPath(roundedRect: NSRect(x: 24, y: 30, width: 832, height: 112), xRadius: 28, yRadius: 28)
    NSColor(calibratedWhite: 1, alpha: 0.14).setStroke()
    inner.lineWidth = 1.5
    inner.stroke()

    let pulse = NSBezierPath(ovalIn: NSRect(x: 42, y: 34, width: 110, height: 110))
    NSColor(calibratedWhite: 0.0, alpha: 0.18).setFill()
    pulse.fill()
    NSColor(calibratedWhite: 1, alpha: 0.18).setStroke()
    pulse.lineWidth = 2
    pulse.stroke()

    image.unlockFocus()
    return image
}

let background = drawBackground()
let startButton = drawButton(
    primary: NSColor(calibratedRed: 0.02, green: 0.76, blue: 0.98, alpha: 1),
    secondary: NSColor(calibratedRed: 0.15, green: 0.40, blue: 0.98, alpha: 1),
    edge: NSColor(calibratedRed: 0.86, green: 0.97, blue: 1.0, alpha: 0.46)
)
let exitButton = drawButton(
    primary: NSColor(calibratedRed: 0.99, green: 0.45, blue: 0.24, alpha: 1),
    secondary: NSColor(calibratedRed: 0.80, green: 0.06, blue: 0.11, alpha: 1),
    edge: NSColor(calibratedRed: 1.0, green: 0.91, blue: 0.85, alpha: 0.38)
)

try saveImage(background, to: outputDir.appendingPathComponent("title_background_generated.jpg"))
try saveImage(startButton, to: outputDir.appendingPathComponent("title_button_start.jpg"))
try saveImage(exitButton, to: outputDir.appendingPathComponent("title_button_exit.jpg"))
