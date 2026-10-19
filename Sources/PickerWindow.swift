// Mac Folderator — the "Color Folder" window (colors, icons, live preview, subfolders)
import AppKit

final class PickerController: NSObject {
    var paths: [String]
    var window: NSWindow!
    var colorIndex = 0
    var glyphIndex = 0
    var glyphMode = 0
    var busy = false

    var summaryLabel: NSTextField!
    var previewView: NSImageView!
    var chip: FlippedView!
    var chipName: NSTextField!
    var chipHex: NSTextField!
    var glyphTitle: NSTextField!
    var subBox: NSButton!
    var infoBox: NSButton!
    var statusLabel: NSTextField!
    var applyButton: NSButton!
    var resetButton: NSButton!
    var chooseButton: NSButton!
    var swatches: [NSButton] = []
    var glyphButtons: [NSButton] = []

    init(paths: [String]) {
        self.paths = paths
        super.init()
        build()
        refresh()
        updateSummary()
        updateEnabled()
    }

    func show() {
        window.makeKeyAndOrderFront(nil)
    }

    // MARK: - build

    func build() {
        let W: CGFloat = 720
        let H: CGFloat = 790
        let made = UI.makeWindow(width: W, height: H, title: "MAC FOLDERATOR",
                                 subtitle: tr("Scegli colore e icona della cartella", "Pick a color and an icon for your folder"))
        window = made.0
        let content = made.1

        summaryLabel = UI.label("", NSRect(x: 24, y: 90, width: 672, height: 18),
                                size: 12, bold: false, color: NSColor.secondaryLabelColor)
        content.addSubview(summaryLabel)

        // left column: preview
        previewView = NSImageView(frame: NSRect(x: 24, y: 124, width: 260, height: 260))
        previewView.imageScaling = NSImageScaling.scaleProportionallyUpOrDown
        previewView.wantsLayer = true
        previewView.layer?.backgroundColor = UI.panel.cgColor
        previewView.layer?.cornerRadius = 18
        content.addSubview(previewView)

        chip = FlippedView(frame: NSRect(x: 24, y: 396, width: 260, height: 56))
        chip.wantsLayer = true
        chip.layer?.cornerRadius = 12
        content.addSubview(chip)
        chipName = UI.label("", NSRect(x: 12, y: 8, width: 236, height: 22), size: 16, bold: true, color: NSColor.white)
        chipHex = UI.label("", NSRect(x: 12, y: 31, width: 236, height: 18), size: 12, bold: false, color: NSColor.white)
        chip.addSubview(chipName)
        chip.addSubview(chipHex)

        content.addSubview(UI.label(tr("Colore dell'icona", "Icon color"), NSRect(x: 24, y: 470, width: 260, height: 18),
                                    size: 13, bold: true, color: NSColor.white))
        let seg = NSSegmentedControl(labels: [tr("Auto", "Auto"), tr("Bianco", "White"), tr("Nero", "Black")],
                                     trackingMode: NSSegmentedControl.SwitchTracking.selectOne,
                                     target: self, action: #selector(modeChanged(_:)))
        seg.frame = NSRect(x: 24, y: 494, width: 260, height: 26)
        seg.selectedSegment = 0
        content.addSubview(seg)
        content.addSubview(UI.wrapping(tr("Auto: bianco sui colori scuri, nero sui colori chiari, così l'icona resta sempre leggibile.",
                                          "Auto: white on dark colors, black on light colors, so the icon is always readable."),
                                       NSRect(x: 24, y: 530, width: 260, height: 48), size: 11, color: NSColor.secondaryLabelColor))

        subBox = NSButton(checkboxWithTitle: tr("Applica anche a tutte le sottocartelle", "Also apply to all subfolders"),
                          target: nil, action: nil)
        subBox.frame = NSRect(x: 24, y: 590, width: 270, height: 22)
        subBox.state = NSControl.StateValue.on
        content.addSubview(subBox)

        infoBox = NSButton(checkboxWithTitle: tr("Apri «Ottieni informazioni» dopo aver applicato", "Open «Get Info» after applying"),
                           target: nil, action: nil)
        infoBox.frame = NSRect(x: 24, y: 618, width: 280, height: 22)
        infoBox.state = NSControl.StateValue.on
        content.addSubview(infoBox)

        chooseButton = NSButton(title: tr("Scegli cartelle…", "Choose folders…"), target: self, action: #selector(chooseTapped))
        chooseButton.frame = NSRect(x: 24, y: 652, width: 260, height: 28)
        chooseButton.bezelStyle = NSButton.BezelStyle.rounded
        content.addSubview(chooseButton)

        let fromFinder = NSButton(title: tr("Usa la selezione del Finder", "Use the Finder selection"), target: self, action: #selector(useFinderSelectionTapped))
        fromFinder.frame = NSRect(x: 24, y: 686, width: 260, height: 28)
        fromFinder.bezelStyle = NSButton.BezelStyle.rounded
        content.addSubview(fromFinder)

        // right column: colors
        content.addSubview(UI.label(tr("Colore", "Color"), NSRect(x: 316, y: 124, width: 200, height: 18),
                                    size: 13, bold: true, color: NSColor.white))
        for i in 0..<palette.count {
            let col = i % 5
            let row = i / 5
            let frame = NSRect(x: 316 + CGFloat(col) * 76, y: 150 + CGFloat(row) * 62, width: 48, height: 48)
            let b = UI.swatch(index: i, frame: frame, target: self, action: #selector(pickColor(_:)))
            content.addSubview(b)
            swatches.append(b)
        }

        // right column: icons
        glyphTitle = UI.label(tr("Icona", "Icon"), NSRect(x: 316, y: 404, width: 380, height: 18),
                              size: 13, bold: true, color: NSColor.white)
        content.addSubview(glyphTitle)
        for i in 0..<glyphs.count {
            let col = i % 5
            let row = i / 5
            let frame = NSRect(x: 316 + CGFloat(col) * 80, y: 430 + CGFloat(row) * 66, width: 56, height: 56)
            let b = NSButton(frame: frame)
            b.title = ""
            b.isBordered = false
            b.imagePosition = NSControl.ImagePosition.imageOnly
            let symbolName = glyphs[i].symbol ?? "nosign"
            if let img = NSImage(systemSymbolName: symbolName, accessibilityDescription: glyphs[i].name) {
                let cfg = NSImage.SymbolConfiguration(pointSize: 24, weight: NSFont.Weight.medium)
                let configured = img.withSymbolConfiguration(cfg) ?? img
                configured.isTemplate = true
                b.image = configured
            } else {
                b.title = glyphs[i].symbol == nil ? "-" : "?"
            }
            b.contentTintColor = NSColor.white
            b.wantsLayer = true
            b.layer?.cornerRadius = 12
            b.tag = i
            b.target = self
            b.action = #selector(pickGlyph(_:))
            b.toolTip = glyphs[i].name
            content.addSubview(b)
            glyphButtons.append(b)
        }

        // buttons
        resetButton = NSButton(title: tr("Colore originale", "Original color"), target: self, action: #selector(resetTapped))
        resetButton.frame = NSRect(x: 24, y: 746, width: 160, height: 30)
        resetButton.bezelStyle = NSButton.BezelStyle.rounded
        content.addSubview(resetButton)

        statusLabel = UI.label("", NSRect(x: 196, y: 752, width: 270, height: 18), size: 12, bold: true, color: NSColor.systemGreen)
        content.addSubview(statusLabel)

        let close = NSButton(title: tr("Chiudi", "Close"), target: self, action: #selector(closeTapped))
        close.frame = NSRect(x: 470, y: 746, width: 100, height: 30)
        close.bezelStyle = NSButton.BezelStyle.rounded
        close.keyEquivalent = "\u{1b}"
        content.addSubview(close)

        applyButton = NSButton(title: tr("Applica", "Apply"), target: self, action: #selector(applyTapped))
        applyButton.frame = NSRect(x: 580, y: 746, width: 116, height: 30)
        applyButton.bezelStyle = NSButton.BezelStyle.rounded
        applyButton.keyEquivalent = "\r"
        content.addSubview(applyButton)
    }

    func updateSummary() {
        if paths.isEmpty {
            summaryLabel.stringValue = tr("Nessuna cartella selezionata: sceglile con i pulsanti a sinistra.",
                                          "No folder selected: choose some with the buttons on the left.")
            summaryLabel.textColor = NSColor.systemOrange
            chooseButton.title = tr("Scegli cartelle…", "Choose folders…")
            return
        }
        let names = paths.map { ($0 as NSString).lastPathComponent }
        summaryLabel.textColor = NSColor.secondaryLabelColor
        if paths.count == 1 {
            summaryLabel.stringValue = tr("Cartella: ", "Folder: ") + names[0]
        } else {
            summaryLabel.stringValue = "\(paths.count)" + tr(" cartelle: ", " folders: ") + names.joined(separator: ", ")
        }
        chooseButton.title = tr("Scegli altre cartelle…", "Choose other folders…")
    }

    // Apply / Original color / the folder options only work when at least one folder is selected.
    func updateEnabled() {
        let ready = !paths.isEmpty && !busy
        applyButton.isEnabled = ready
        resetButton.isEnabled = ready
        subBox.isEnabled = !paths.isEmpty
        infoBox.isEnabled = !paths.isEmpty
    }

    // Replaces the selected folders (used by the buttons and by the app menu).
    func setPaths(_ chosen: [String]) {
        if chosen.isEmpty { return }
        paths = chosen
        updateSummary()
        updateEnabled()
        statusLabel.stringValue = ""
    }

    // MARK: - refresh preview

    func refresh() {
        let c = palette[colorIndex]
        let g = glyphs[glyphIndex]
        previewView.image = renderFolder(color: c, glyph: g, glyphMode: glyphMode, size: 512)

        chip.layer?.backgroundColor = c.color.cgColor
        let text = UI.textColor(on: c.color)
        chipName.stringValue = c.name
        chipName.textColor = text
        chipHex.stringValue = "\(c.hex)   RGB \(c.r), \(c.g), \(c.b)"
        chipHex.textColor = text

        glyphTitle.stringValue = tr("Icona: ", "Icon: ") + g.name
        UI.markSwatches(swatches, selected: colorIndex, dimmed: false)
        for (i, b) in glyphButtons.enumerated() {
            if i == glyphIndex {
                b.layer?.backgroundColor = UI.magenta.withAlphaComponent(0.35).cgColor
                b.layer?.borderWidth = 2
                b.layer?.borderColor = UI.magenta.cgColor
            } else {
                b.layer?.backgroundColor = NSColor.white.withAlphaComponent(0.07).cgColor
                b.layer?.borderWidth = 0
            }
        }
    }

    // MARK: - actions

    @objc func pickColor(_ sender: NSButton) {
        if sender.tag < 0 || sender.tag >= palette.count { return }
        colorIndex = sender.tag
        refresh()
    }

    @objc func pickGlyph(_ sender: NSButton) {
        if sender.tag < 0 || sender.tag >= glyphs.count { return }
        glyphIndex = sender.tag
        refresh()
    }

    @objc func modeChanged(_ sender: NSSegmentedControl) {
        glyphMode = sender.selectedSegment
        refresh()
    }

    @objc func closeTapped() {
        window.close()
    }

    // Pick folders without closing the window.
    @objc func chooseTapped() {
        let panel = NSOpenPanel()
        panel.title = tr("Scegli le cartelle da colorare", "Choose the folders to color")
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = true
        if panel.runModal() == NSApplication.ModalResponse.OK {
            setPaths(panel.urls.map { Finder.clean($0.path) })
        }
    }

    @objc func useFinderSelectionTapped() {
        let selected = Finder.selection()
        if selected.isEmpty {
            UI.alert(tr("Nessuna cartella selezionata nel Finder", "No folder is selected in the Finder"),
                     tr("Seleziona una o più cartelle nel Finder e riprova, oppure usa «Scegli cartelle…».",
                        "Select one or more folders in the Finder and try again, or use “Choose folders…”."),
                     window: window)
            return
        }
        setPaths(selected)
    }

    @objc func applyTapped() {
        let image = renderFolder(color: palette[colorIndex], glyph: glyphs[glyphIndex], glyphMode: glyphMode, size: 1024)
        runChange(image: image, applied: true)
    }

    @objc func resetTapped() {
        runChange(image: nil, applied: false)
    }

    // The chosen folders and (if the box is ticked) all their subfolders get the icon (or lose it).
    // The window stays open. Folders under iCloud: "Get Info" is opened and closed for each one (up to 40),
    // which makes the new icon show up. A single folder elsewhere: Get Info is opened and left open (if ticked).
    func runChange(image: NSImage?, applied: Bool) {
        if busy || paths.isEmpty { return }
        busy = true
        updateEnabled()
        statusLabel.stringValue = tr("Lavoro…", "Working…")
        statusLabel.textColor = NSColor.systemOrange
        let roots = paths
        let withSub = (subBox.state == NSControl.StateValue.on)
        let single = (roots.count == 1)
        let keepInfo = (infoBox.state == NSControl.StateValue.on)
        DispatchQueue.global(qos: DispatchQoS.QoSClass.userInitiated).async {
            let all = Applier.collect(roots: roots, includeSubfolders: withSub)
            let result = Applier.apply(image: image, to: all)
            if applied { Registry.markColored(result.done) } else { Registry.markOriginal(result.done) }
            for r in roots { NSWorkspace.shared.noteFileSystemChanged(r) }
            let cloud = Array(result.done.filter { Rules.isICloud($0) }.prefix(40))
            for p in cloud { Finder.refreshViaInfo(p) }
            let openInfo: [String] = (single && keepInfo && cloud.isEmpty && !result.done.isEmpty) ? [roots[0]] : []
            DispatchQueue.main.async {
                if !openInfo.isEmpty { Finder.showInfo(openInfo) }
                let head: String = applied ? tr("✓ Colore applicato a ", "✓ Color applied to ")
                                           : tr("✓ Colore originale su ", "✓ Original color on ")
                let unit: String = tr(" cartelle", " folders")
                self.statusLabel.stringValue = head + "\(result.done.count)" + unit
                self.statusLabel.textColor = NSColor.systemGreen
                self.busy = false
                self.updateEnabled()
                if !result.failed.isEmpty { self.showFailure(result.failed) }
            }
        }
    }

    func showFailure(_ failed: [String]) {
        let head = tr("Non sono riuscito a modificare ", "Could not change ") + "\(failed.count)" + tr(" cartella/e", " folder(s)")
        let body = tr("Di solito manca un permesso: apri Impostazioni di Sistema → Privacy e sicurezza → Accesso completo al disco e abilita Mac Folderator.",
                      "Usually a permission is missing: open System Settings → Privacy & Security → Full Disk Access and enable Mac Folderator.")
            + "\n\n" + failed.prefix(5).joined(separator: "\n")
        UI.alert(head, body, window: window)
    }
}
