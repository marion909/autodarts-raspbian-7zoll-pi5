// Erzeugt aus den Autodarts-SVGs (assets/brand/) alle Bildressourcen:
//   assets/boot-splash.png, assets/wallpaper.jpg, assets/brand/readme-banner.png,
//   mac-app/Resources/{MenuBarIcon.png, MenuBarIcon@2x.png, Logo.png} und das AppIcon.iconset
// Aufruf: make-brand-assets <brand-dir> <repo-root> <iconset-dir>   (siehe tools/make-brand-assets.sh)
import AppKit

let args = CommandLine.arguments
guard args.count == 4 else {
    print("usage: make-brand-assets <brand-dir> <repo-root> <iconset-dir>")
    exit(2)
}
let brandDir = args[1]
let root = args[2]
let iconsetDir = args[3]

let background = NSColor(srgbRed: 1 / 255, green: 4 / 255, blue: 11 / 255, alpha: 1) // #01040b (Autodarts-Hintergrund)

func loadSVG(_ name: String) -> NSImage {
    guard let image = NSImage(contentsOf: URL(fileURLWithPath: brandDir + "/" + name)) else {
        fatalError("SVG nicht lesbar: \(name)")
    }
    return image
}

let logo = loadSVG("autodarts-logo.svg") // Symbol + Schriftzug
let mark = loadSVG("autodarts-mark.svg") // nur das Symbol (512x512, mit Rand)

func makeBitmap(_ width: Int, _ height: Int, draw: (NSRect) -> Void) -> NSBitmapImageRep {
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: width, pixelsHigh: height,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
    )!
    rep.size = NSSize(width: width, height: height)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    NSGraphicsContext.current?.imageInterpolation = .high
    draw(NSRect(x: 0, y: 0, width: width, height: height))
    NSGraphicsContext.restoreGraphicsState()
    return rep
}

/// Zeichnet das Bild proportional und zentriert in das Rechteck
func drawFit(_ image: NSImage, in rect: NSRect, alpha: CGFloat = 1) {
    let scale = min(rect.width / image.size.width, rect.height / image.size.height)
    let width = image.size.width * scale
    let height = image.size.height * scale
    let target = NSRect(x: rect.midX - width / 2, y: rect.midY - height / 2, width: width, height: height)
    image.draw(in: target, from: .zero, operation: .sourceOver, fraction: alpha)
}

func write(_ rep: NSBitmapImageRep, _ path: String, type: NSBitmapImageRep.FileType, properties: [NSBitmapImageRep.PropertyKey: Any] = [:]) {
    guard let data = rep.representation(using: type, properties: properties) else { fatalError("Kodierung fehlgeschlagen: \(path)") }
    try! FileManager.default.createDirectory(atPath: (path as NSString).deletingLastPathComponent, withIntermediateDirectories: true)
    try! data.write(to: URL(fileURLWithPath: path))
    print("geschrieben: \(path)")
}

// MARK: - Bootscreen (1920x1080)

let splash = makeBitmap(1920, 1080) { rect in
    background.setFill()
    rect.fill()
    drawFit(logo, in: NSRect(x: 460, y: 390, width: 1000, height: 300))
}
write(splash, root + "/assets/boot-splash.png", type: .png)

// MARK: - Wallpaper (1920x1080): dunkler Verlauf, grosses Symbol als Wasserzeichen, Logo mittig

let wallpaper = makeBitmap(1920, 1080) { rect in
    background.setFill()
    rect.fill()
    let glow = NSGradient(
        starting: NSColor(srgbRed: 0.02, green: 0.16, blue: 0.30, alpha: 1),
        ending: background
    )!
    glow.draw(fromCenter: NSPoint(x: 1450, y: 760), radius: 0, toCenter: NSPoint(x: 1450, y: 760), radius: 1000, options: [])
    drawFit(mark, in: NSRect(x: 820, y: -260, width: 1500, height: 1500), alpha: 0.07)
    drawFit(logo, in: NSRect(x: 510, y: 400, width: 900, height: 280))
}
write(wallpaper, root + "/assets/wallpaper.jpg", type: .jpeg, properties: [.compressionFactor: 0.92])

// MARK: - README-Banner (1600x420): funktioniert auf hellem und dunklem GitHub-Hintergrund

let banner = makeBitmap(1600, 420) { rect in
    background.setFill()
    rect.fill()
    let glow = NSGradient(
        starting: NSColor(srgbRed: 0.02, green: 0.16, blue: 0.30, alpha: 1),
        ending: background
    )!
    glow.draw(fromCenter: NSPoint(x: 1250, y: 330), radius: 0, toCenter: NSPoint(x: 1250, y: 330), radius: 800, options: [])
    drawFit(mark, in: NSRect(x: 1000, y: -230, width: 900, height: 900), alpha: 0.07)
    drawFit(logo, in: NSRect(x: 380, y: 110, width: 840, height: 200))
}
write(banner, root + "/assets/brand/readme-banner.png", type: .png)

// MARK: - macOS-App-Icon (abgerundetes Quadrat nach Apple-Raster, Symbol mittig)

func appIcon(pixels: Int) -> NSBitmapImageRep {
    makeBitmap(pixels, pixels) { rect in
        let s = CGFloat(pixels) / 1024
        let tile = NSRect(x: 100 * s, y: 100 * s, width: 824 * s, height: 824 * s)
        let path = NSBezierPath(roundedRect: tile, xRadius: 185 * s, yRadius: 185 * s)

        NSGraphicsContext.saveGraphicsState()
        let shadow = NSShadow()
        shadow.shadowColor = NSColor.black.withAlphaComponent(0.45)
        shadow.shadowBlurRadius = 18 * s
        shadow.shadowOffset = NSSize(width: 0, height: -10 * s)
        shadow.set()
        background.setFill()
        path.fill()
        NSGraphicsContext.restoreGraphicsState()

        NSGraphicsContext.saveGraphicsState()
        path.addClip()
        NSGradient(
            starting: NSColor(srgbRed: 0.03, green: 0.14, blue: 0.27, alpha: 1),
            ending: background
        )!.draw(in: tile, angle: -90)
        NSGraphicsContext.restoreGraphicsState()

        NSColor.white.withAlphaComponent(0.08).setStroke()
        path.lineWidth = 2 * s
        path.stroke()

        // Das Symbol hat im SVG ca. 13 % Rand: Box so waehlen, dass es ca. 57 % der Kachel fuellt
        let box = 780 * s
        drawFit(mark, in: NSRect(x: (CGFloat(pixels) - box) / 2, y: (CGFloat(pixels) - box) / 2, width: box, height: box))
    }
}

let iconFiles: [(String, Int)] = [
    ("icon_16x16.png", 16), ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32), ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128), ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256), ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512), ("icon_512x512@2x.png", 1024),
]
for (name, pixels) in iconFiles {
    write(appIcon(pixels: pixels), iconsetDir + "/" + name, type: .png)
}

// MARK: - Menueleisten-Symbol (Template-Bild: nur Alpha, macOS faerbt es passend ein)

/// Kleinster Rahmen um alle nicht transparenten Pixel (in Pixelkoordinaten, Ursprung oben links)
func alphaBounds(_ rep: NSBitmapImageRep) -> CGRect {
    var minX = rep.pixelsWide, minY = rep.pixelsHigh, maxX = -1, maxY = -1
    for y in 0 ..< rep.pixelsHigh {
        for x in 0 ..< rep.pixelsWide where (rep.colorAt(x: x, y: y)?.alphaComponent ?? 0) > 0.05 {
            minX = min(minX, x); maxX = max(maxX, x); minY = min(minY, y); maxY = max(maxY, y)
        }
    }
    return CGRect(x: minX, y: minY, width: maxX - minX + 1, height: maxY - minY + 1)
}

let big = makeBitmap(1024, 1024) { rect in drawFit(mark, in: rect) }
let bounds = alphaBounds(big)
let cropped = big.cgImage!.cropping(to: bounds)!
let croppedImage = NSImage(cgImage: cropped, size: NSSize(width: bounds.width, height: bounds.height))

func menuBarIcon(pixels: Int) -> NSBitmapImageRep {
    let rep = makeBitmap(pixels, pixels) { rect in
        drawFit(croppedImage, in: rect.insetBy(dx: CGFloat(pixels) * 0.06, dy: CGFloat(pixels) * 0.06))
    }
    // Farbe entfernen, Transparenz behalten
    if let data = rep.bitmapData {
        for y in 0 ..< rep.pixelsHigh {
            for x in 0 ..< rep.pixelsWide {
                let i = y * rep.bytesPerRow + x * 4
                data[i] = 0; data[i + 1] = 0; data[i + 2] = 0
            }
        }
    }
    return rep
}
write(menuBarIcon(pixels: 18), root + "/mac-app/Resources/MenuBarIcon.png", type: .png)
write(menuBarIcon(pixels: 36), root + "/mac-app/Resources/MenuBarIcon@2x.png", type: .png)

// MARK: - Logo fuer die Oberflaeche der App (Symbol, transparent)

write(makeBitmap(256, 256) { rect in drawFit(croppedImage, in: rect.insetBy(dx: 12, dy: 12)) },
      root + "/mac-app/Resources/Logo.png", type: .png)
