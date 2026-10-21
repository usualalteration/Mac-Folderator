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

// The colorful banner: a gradient that stretches with the window.
final class GradientView: NSView {
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        wantsLayer = true
    }

    override var isFlipped: Bool { return true }

    override func makeBackingLayer() -> CALayer {
        let grad = CAGradientLayer()
        grad.colors = [
            NSColor(srgbRed: 1.00, green: 0.08, blue: 0.69, alpha: 1).cgColor,
            NSColor(srgbRed: 0.45, green: 0.15, blue: 0.85, alpha: 1).cgColor,
            NSColor(srgbRed: 1.00, green: 0.53, blue: 0.17, alpha: 1).cgColor
        ]
        grad.startPoint = CGPoint(x: 0, y: 0.5)
        grad.endPoint = CGPoint(x: 1, y: 0.5)
        return grad
    }
}

// Keeps the fixed-size content centered when the window is wider than the content.
final class CenteringView: NSView {
    weak var inner: NSView?

    override var isFlipped: Bool { return true }

    override func resizeSubviews(withOldSize oldSize: NSSize) {
        super.resizeSubviews(withOldSize: oldSize)
        recenter()
    }

    func recenter() {
        guard let v = inner else { return }
        var f = v.frame
        f.origin.x = max(0, (bounds.width - f.width) / 2)
        v.frame = f
    }
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
    // A resizable window with a fixed-size content (width x height) inside a scroll view:
    // on small screens the window opens as tall as the screen allows and the content scrolls;
    // on big windows the content stays centered.
    static func makeWindow(width: CGFloat, height: CGFloat, title: String, subtitle: String) -> (NSWindow, FlippedView) {
        let screen: NSRect = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1280, height: 720)
        let winW = min(width, max(520, screen.width - 24))
        let winH = min(height, max(420, screen.height - 56))     // room for the title bar and the menu bar

        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: winW, height: winH),
                              styleMask: [NSWindow.StyleMask.titled, NSWindow.StyleMask.closable,
                                          NSWindow.StyleMask.miniaturizable, NSWindow.StyleMask.resizable],
                              backing: NSWindow.BackingStoreType.buffered, defer: false)
        window.title = "Mac Folderator"
        window.appearance = NSAppearance(named: NSAppearance.Name.darkAqua)
        window.isReleasedWhenClosed = false
        window.contentMinSize = NSSize(width: min(width, winW), height: 380)

        let scroll = NSScrollView(frame: NSRect(x: 0, y: 0, width: winW, height: winH))
        scroll.hasVerticalScroller = true
        scroll.hasHorizontalScroller = true
        scroll.autohidesScrollers = true
        scroll.borderType = NSBorderType.noBorder
        scroll.drawsBackground = true
        scroll.backgroundColor = background
        scroll.autoresizingMask = [NSView.AutoresizingMask.width, NSView.AutoresizingMask.height]

        let doc = CenteringView(frame: NSRect(x: 0, y: 0, width: max(width, winW), height: height))
        doc.autoresizingMask = [NSView.AutoresizingMask.width]
        doc.wantsLayer = true
        doc.layer?.backgroundColor = background.cgColor

        let banner = GradientView(frame: NSRect(x: 0, y: 0, width: max(width, winW), height: 78))
        banner.autoresizingMask = [NSView.AutoresizingMask.width]
        doc.addSubview(banner)

        let content = FlippedView(frame: NSRect(x: 0, y: 0, width: width, height: height))
        doc.addSubview(content)
        doc.inner = content
        doc.recenter()

        scroll.documentView = doc
        window.contentView = scroll
        window.center()

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
