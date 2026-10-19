// Mac Folderator — draws the folder icon (same drawing for the preview and for the real icon)
import AppKit

// glyphMode: 0 = automatic (white on dark colors, black on light colors), 1 = white, 2 = black
func renderFolder(color: FolderColor, glyph: Glyph, glyphMode: Int, size: CGFloat) -> NSImage {
    let S = size
    let px = Int(size)
    let empty = NSImage(size: NSSize(width: S, height: S))
    guard let cs = CGColorSpace(name: CGColorSpace.sRGB) else { return empty }
    guard let cg = CGContext(data: nil, width: px, height: px, bitsPerComponent: 8, bytesPerRow: 0,
                             space: cs, bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue) else { return empty }
    cg.translateBy(x: 0, y: S)
    cg.scaleBy(x: 1, y: -1)
    // The drawing is scaled up around its center so the folder fills the icon like the original macOS folder does.
    cg.translateBy(x: S * 0.5, y: S * 0.53)
    cg.scaleBy(x: 1.10, y: 1.10)
    cg.translateBy(x: -S * 0.5, y: -S * 0.49)
    let ctx = NSGraphicsContext(cgContext: cg, flipped: true)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = ctx

    func R(_ x0: CGFloat, _ y0: CGFloat, _ x1: CGFloat, _ y1: CGFloat) -> NSRect {
        return NSRect(x: x0 * S, y: y0 * S, width: (x1 - x0) * S, height: (y1 - y0) * S)
    }
    func rounded(_ rect: NSRect, _ r: CGFloat) -> NSBezierPath {
        return NSBezierPath(roundedRect: rect, xRadius: r * S, yRadius: r * S)
    }

    let base = color.color
    let backColor = mixColor(base, NSColor.black, 0.22)
    let topColor = mixColor(base, NSColor.white, 0.32)
    let rimColor = mixColor(base, NSColor.white, 0.50)
    let rw = 0.007 * S

    // soft shadow
    NSGraphicsContext.saveGraphicsState()
    let shadow = NSShadow()
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.45)
    shadow.shadowBlurRadius = 0.035 * S
    shadow.shadowOffset = NSSize(width: 0, height: 0)
    shadow.set()
    backColor.setFill()
    rounded(R(0.10, 0.30, 0.90, 0.84), 0.05).fill()
    NSGraphicsContext.restoreGraphicsState()

    // back panel (body + tab) with a bright rim
    let bodyRect = R(0.10, 0.20, 0.90, 0.78)
    let tabRect = R(0.10, 0.14, 0.44, 0.34)
    rimColor.setFill()
    rounded(bodyRect, 0.05).fill()
    rounded(tabRect, 0.05).fill()
    backColor.setFill()
    rounded(bodyRect.insetBy(dx: rw, dy: rw), 0.05 - 0.007).fill()
    rounded(tabRect.insetBy(dx: rw, dy: rw), 0.05 - 0.007).fill()

    // front panel with a vertical gradient
    let front = rounded(R(0.10, 0.30, 0.90, 0.84), 0.05)
    NSGraphicsContext.saveGraphicsState()
    front.addClip()
    if let grad = NSGradient(starting: topColor, ending: base) {
        grad.draw(from: NSPoint(x: 0, y: 0.30 * S), to: NSPoint(x: 0, y: 0.84 * S), options: [])
    }
    NSGraphicsContext.restoreGraphicsState()
    rimColor.withAlphaComponent(0.8).setStroke()
    front.lineWidth = rw
    front.stroke()

    // glyph on the front panel
    if let symbolName = glyph.symbol {
        let useWhite: Bool
        if glyphMode == 1 {
            useWhite = true
        } else if glyphMode == 2 {
            useWhite = false
        } else {
            useWhite = luminance(mixColor(topColor, base, 0.5)) < 0.60
        }
        let glyphColor: NSColor = useWhite
            ? NSColor.white
            : NSColor(srgbRed: 0.07, green: 0.08, blue: 0.11, alpha: 1.0)
        if let raw = NSImage(systemSymbolName: symbolName, accessibilityDescription: nil) {
            let cfg = NSImage.SymbolConfiguration(pointSize: 400, weight: NSFont.Weight.semibold)
            let sym = raw.withSymbolConfiguration(cfg) ?? raw
            let colored = tinted(sym, glyphColor)
            let box = R(0.33, 0.40, 0.67, 0.74)
            let ratio = colored.size.width / max(colored.size.height, 1)
            var gw = box.width
            var gh = gw / ratio
            if gh > box.height {
                gh = box.height
                gw = gh * ratio
            }
            let dest = NSRect(x: box.midX - gw / 2, y: box.midY - gh / 2, width: gw, height: gh)
            NSGraphicsContext.saveGraphicsState()
            let gs = NSShadow()
            gs.shadowColor = (useWhite ? NSColor.black : NSColor.white).withAlphaComponent(0.30)
            gs.shadowBlurRadius = 0.012 * S
            gs.shadowOffset = NSSize(width: 0, height: 0)
            gs.set()
            colored.draw(in: dest, from: NSRect.zero, operation: NSCompositingOperation.sourceOver,
                         fraction: 0.96, respectFlipped: true, hints: nil)
            NSGraphicsContext.restoreGraphicsState()
        }
    }

    NSGraphicsContext.restoreGraphicsState()
    guard let cgImage = cg.makeImage() else { return empty }
    return NSImage(cgImage: cgImage, size: NSSize(width: S, height: S))
}
