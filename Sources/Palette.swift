// Mac Folderator — palette (20 colors), glyphs (SF Symbols), language helper, color utilities
import AppKit

// MARK: - Language (Italian if the system language is Italian, English otherwise)

enum AppLanguage {
    static let isItalian: Bool = (Locale.preferredLanguages.first ?? "en").hasPrefix("it")
}

func tr(_ it: String, _ en: String) -> String {
    return AppLanguage.isItalian ? it : en
}

// MARK: - Palette

struct FolderColor {
    let slug: String
    let it: String
    let en: String
    let r: Int
    let g: Int
    let b: Int

    var name: String { return tr(it, en) }
    var color: NSColor {
        return NSColor(srgbRed: CGFloat(r) / 255.0, green: CGFloat(g) / 255.0, blue: CGFloat(b) / 255.0, alpha: 1.0)
    }
    var hex: String { return String(format: "#%02X%02X%02X", r, g, b) }
}

let palette: [FolderColor] = [
    FolderColor(slug: "rosso", it: "Rosso", en: "Red", r: 255, g: 0, b: 55),
    FolderColor(slug: "corallo", it: "Corallo", en: "Coral", r: 255, g: 98, b: 92),
    FolderColor(slug: "arancio", it: "Arancio", en: "Orange", r: 255, g: 135, b: 43),
    FolderColor(slug: "oro", it: "Oro", en: "Gold", r: 255, g: 196, b: 41),
    FolderColor(slug: "giallo", it: "Giallo", en: "Yellow", r: 241, g: 255, b: 43),
    FolderColor(slug: "lime", it: "Lime", en: "Lime", r: 163, g: 230, b: 53),
    FolderColor(slug: "verde", it: "Verde", en: "Green", r: 28, g: 196, b: 106),
    FolderColor(slug: "menta", it: "Menta", en: "Mint", r: 92, g: 235, b: 190),
    FolderColor(slug: "turchese", it: "Turchese", en: "Teal", r: 0, g: 176, b: 176),
    FolderColor(slug: "ciano", it: "Ciano", en: "Cyan", r: 24, g: 214, b: 255),
    FolderColor(slug: "azzurro", it: "Azzurro", en: "Sky Blue", r: 62, g: 146, b: 255),
    FolderColor(slug: "blu", it: "Blu", en: "Blue", r: 24, g: 71, b: 242),
    FolderColor(slug: "indaco", it: "Indaco", en: "Indigo", r: 86, g: 66, b: 235),
    FolderColor(slug: "viola", it: "Viola", en: "Purple", r: 150, g: 60, b: 255),
    FolderColor(slug: "fucsia", it: "Fucsia", en: "Fuchsia", r: 255, g: 20, b: 175),
    FolderColor(slug: "rosa", it: "Rosa", en: "Pink", r: 255, g: 128, b: 190),
    FolderColor(slug: "argento", it: "Argento", en: "Silver", r: 214, g: 222, b: 232),
    FolderColor(slug: "ardesia", it: "Ardesia", en: "Slate", r: 96, g: 118, b: 142),
    FolderColor(slug: "grafite", it: "Grafite", en: "Graphite", r: 52, g: 62, b: 78),
    FolderColor(slug: "nero", it: "Nero", en: "Black", r: 30, g: 35, b: 46)
]

func paletteIndex(forSlug slug: String) -> Int? {
    for (i, c) in palette.enumerated() where c.slug == slug { return i }
    return nil
}

// MARK: - Glyphs (system symbols)

struct Glyph {
    let it: String
    let en: String
    let symbol: String?
    var name: String { return tr(it, en) }
}

let glyphs: [Glyph] = [
    Glyph(it: "Nessuna icona", en: "No icon", symbol: nil),
    Glyph(it: "Ingranaggi (impostazioni, progetti tecnici)", en: "Gears (settings, technical projects)", symbol: "gearshape.2.fill"),
    Glyph(it: "Libro aperto (studio, manuali, ebook)", en: "Open book (study, manuals, ebooks)", symbol: "book.fill"),
    Glyph(it: "Stella (preferiti)", en: "Star (favorites)", symbol: "star.fill"),
    Glyph(it: "Cuore (personale)", en: "Heart (personal)", symbol: "heart.fill"),
    Glyph(it: "Valigetta (lavoro, clienti)", en: "Briefcase (work, clients)", symbol: "briefcase.fill"),
    Glyph(it: "Casa (famiglia, casa)", en: "House (family, home)", symbol: "house.fill"),
    Glyph(it: "Codice (sviluppo)", en: "Code (development)", symbol: "chevron.left.forwardslash.chevron.right"),
    Glyph(it: "Nota musicale (musica, audio)", en: "Music note (music, audio)", symbol: "music.note"),
    Glyph(it: "Foto (immagini, grafica)", en: "Photo (images, graphics)", symbol: "photo.fill"),
    Glyph(it: "Video (film, registrazioni)", en: "Video (movies, recordings)", symbol: "play.rectangle.fill"),
    Glyph(it: "Documento (testi, contratti)", en: "Document (texts, contracts)", symbol: "doc.text.fill"),
    Glyph(it: "Download", en: "Download", symbol: "arrow.down.circle.fill"),
    Glyph(it: "Cloud (sincronizzate, backup online)", en: "Cloud (synced, online backups)", symbol: "cloud.fill"),
    Glyph(it: "Lucchetto (privato, riservato)", en: "Padlock (private, confidential)", symbol: "lock.fill"),
    Glyph(it: "Fiamma (urgente, importante)", en: "Flame (urgent, important)", symbol: "flame.fill"),
    Glyph(it: "Spunta (completato)", en: "Checkmark (done)", symbol: "checkmark.circle.fill"),
    Glyph(it: "Archivio (vecchi progetti)", en: "Archive (old projects)", symbol: "archivebox.fill"),
    Glyph(it: "Globo (web, siti)", en: "Globe (web, sites)", symbol: "globe"),
    Glyph(it: "Cappello da laurea (università, corsi)", en: "Graduation cap (university, courses)", symbol: "graduationcap.fill")
]

// MARK: - Color utilities

func mixColor(_ a: NSColor, _ b: NSColor, _ k: CGFloat) -> NSColor {
    let ca = a.usingColorSpace(NSColorSpace.sRGB) ?? a
    let cb = b.usingColorSpace(NSColorSpace.sRGB) ?? b
    return NSColor(srgbRed: ca.redComponent * (1 - k) + cb.redComponent * k,
                   green: ca.greenComponent * (1 - k) + cb.greenComponent * k,
                   blue: ca.blueComponent * (1 - k) + cb.blueComponent * k,
                   alpha: 1.0)
}

func luminance(_ c: NSColor) -> CGFloat {
    let s = c.usingColorSpace(NSColorSpace.sRGB) ?? c
    return 0.299 * s.redComponent + 0.587 * s.greenComponent + 0.114 * s.blueComponent
}

func tinted(_ img: NSImage, _ color: NSColor) -> NSImage {
    let size = img.size
    return NSImage(size: size, flipped: false, drawingHandler: { (rect: NSRect) -> Bool in
        img.draw(in: rect)
        color.set()
        rect.fill(using: NSCompositingOperation.sourceAtop)
        return true
    })
}
