import AppKit

let sourcePath = "/Users/zambo/Desktop/button.png"
let outputPath = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    .appendingPathComponent("assets/images/title_button_start.png")

guard let sourceImage = NSImage(contentsOfFile: sourcePath) else {
    fputs("Could not load source image at \(sourcePath)\n", stderr)
    exit(1)
}

let cropRect = NSRect(x: 80, y: 40, width: 3500, height: 1000)
let outputSize = NSSize(width: cropRect.width, height: cropRect.height)
let outputImage = NSImage(size: outputSize)

outputImage.lockFocus()
NSColor.clear.setFill()
NSRect(origin: .zero, size: outputSize).fill()

let clipPath = NSBezierPath(
    roundedRect: NSRect(x: 0, y: 0, width: outputSize.width, height: outputSize.height),
    xRadius: 150,
    yRadius: 150
)
clipPath.addClip()

sourceImage.draw(
    in: NSRect(origin: .zero, size: outputSize),
    from: cropRect,
    operation: .sourceOver,
    fraction: 1.0
)

outputImage.unlockFocus()

guard
    let tiff = outputImage.tiffRepresentation,
    let bitmap = NSBitmapImageRep(data: tiff),
    let png = bitmap.representation(using: .png, properties: [:])
else {
    fputs("Could not render output image.\n", stderr)
    exit(1)
}

try png.write(to: outputPath)
