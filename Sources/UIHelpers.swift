// Mac Folderator — small helpers to build the windows by code
import AppKit
import QuartzCore

// Brings the app to the front (the old call is deprecated from macOS 14).
func bringToFront() {
    if #available(macOS 14.0, *) {
        NSApp.activate()
    } else {
        NSApp.activate(ignoringOtherApps: true)
    }
}

final class FlippedView: NSView {
    override var isFlipped: Bool { return true }
}

enum UI {
    static let background = NSColor(srgbRed: 0.05, green: 0.07, blue: 0.11, alpha: 1.0)
    static let panel = NSColor(srgbRed: 0.09, green: 0.12, blue: 0.17, alpha: 1.0)
    static let magenta = NSColor(srgbRed: 1.0, green: 0.08, blue: 0.69, alpha: 1.0)

    static func label(_ text: String, _ frame: NSRect, size: CGFloat, bold: Bool, color: NSColor) -> NSTextField {
        let l = NSTextField(labelWithString: text)
        l.frame = frame
        l.font = bold ? NSFont.boldSystemFont(ofSize: size) : NSFont.systemFont(ofSize: size)
        l.textColor = color
        l.lineBreakMode = NSLineBreakMode.byTruncatingMiddle
        return l
    }

    static func wrapping(_ text: String, _ frame: NSRect, size: CGFloat, color: NSColor) -> NSTextField {
        let l = NSTextField(wrappingLabelWithString: text)
        l.frame = frame
        l.font = NSFont.systemFont(ofSize: size)
        l.textColor = color
        return l
    }

    // A window with a dark, flipped content view and the retrowave banner on top.
    static func makeWindow(width: CGFloat, height: CGFloat, title: String, subtitle: String) -> (NSWindow, FlippedView) {
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: width, height: height),
                              styleMask: [NSWindow.StyleMask.titled, NSWindow.StyleMask.closable, NSWindow.StyleMask.miniaturizable],
                              backing: NSWindow.BackingStoreType.buffered, defer: false)
        window.title = "Mac Folderator"
        window.appearance = NSAppearance(named: NSAppearance.Name.darkAqua)
        window.isReleasedWhenClosed = false
        window.center()

        let content = FlippedView(frame: NSRect(x: 0, y: 0, width: width, height: height))
        content.wantsLayer = true
        content.layer?.backgroundColor = background.cgColor
        window.contentView = content

        let banner = FlippedView(frame: NSRect(x: 0, y: 0, width: width, height: 78))
        banner.wantsLayer = true
        let grad = CAGradientLayer()
        grad.frame = banner.bounds
        grad.colors = [
            NSColor(srgbRed: 1.00, green: 0.08, blue: 0.69, alpha: 1).cgColor,
            NSColor(srgbRed: 0.45, green: 0.15, blue: 0.85, alpha: 1).cgColor,
            NSColor(srgbRed: 1.00, green: 0.53, blue: 0.17, alpha: 1).cgColor
        ]
        grad.startPoint = CGPoint(x: 0, y: 0.5)
        grad.endPoint = CGPoint(x: 1, y: 0.5)
        banner.layer?.addSublayer(grad)
        content.addSubview(banner)
        content.addSubview(label(title, NSRect(x: 24, y: 14, width: width - 48, height: 34),
                                 size: 28, bold: true, color: NSColor.white))
        content.addSubview(label(subtitle, NSRect(x: 26, y: 50, width: width - 52, height: 18),
                                 size: 12, bold: false, color: NSColor.white.withAlphaComponent(0.9)))
        return (window, content)
    }

    static func swatch(index: Int, frame: NSRect, target: AnyObject, action: Selector) -> NSButton {
        let b = NSButton(frame: frame)
        b.title = ""
        b.isBordered = false
        b.wantsLayer = true
        b.layer?.backgroundColor = palette[index].color.cgColor
        b.layer?.cornerRadius = frame.width / 2
        b.tag = index
        b.target = target
        b.action = action
        b.toolTip = palette[index].name
        return b
    }

    static func markSwatches(_ buttons: [NSButton], selected: Int, dimmed: Bool) {
        for (i, b) in buttons.enumerated() {
            b.alphaValue = dimmed ? 0.35 : 1.0
            if i == selected && !dimmed {
                b.layer?.borderWidth = 3
                b.layer?.borderColor = NSColor.white.cgColor
            } else {
                b.layer?.borderWidth = 0
            }
        }
    }

    // Text color readable on top of a given background color.
    static func textColor(on c: NSColor) -> NSColor {
        return luminance(c) > 0.62 ? NSColor(srgbRed: 0.07, green: 0.08, blue: 0.11, alpha: 1) : NSColor.white
    }

    static func alert(_ title: String, _ text: String, window: NSWindow?) {
        let a = NSAlert()
        a.messageText = title
        a.informativeText = text
        a.addButton(withTitle: "OK")
        if let w = window {
            a.beginSheetModal(for: w, completionHandler: nil)
        } else {
            a.runModal()
        }
    }
}
