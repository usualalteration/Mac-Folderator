// Mac Folderator — remembers which folders it colored (~/.macfolderator/manifest.tsv), so they can be restored
import AppKit

enum Registry {
    static let state: String = NSHomeDirectory() + "/.macfolderator"
    static var manifest: String { return state + "/manifest.tsv" }

    static func ensureDir() {
        try? FileManager.default.createDirectory(atPath: state, withIntermediateDirectories: true, attributes: nil)
    }

    static func lines(_ path: String) -> [String] {
        guard let text = try? String(contentsOfFile: path, encoding: String.Encoding.utf8) else { return [] }
        return text.components(separatedBy: "\n").filter { !$0.isEmpty }
    }

    static func write(_ path: String, _ ls: [String]) {
        ensureDir()
        let text = ls.isEmpty ? "" : ls.joined(separator: "\n") + "\n"
        try? text.write(toFile: path, atomically: true, encoding: String.Encoding.utf8)
    }

    static func append(_ text: String, to path: String) {
        ensureDir()
        guard let data = (text + "\n").data(using: String.Encoding.utf8) else { return }
        if let h = FileHandle(forWritingAtPath: path) {
            do {
                _ = try h.seekToEnd()
                try h.write(contentsOf: data)
                try h.close()
            } catch {
                // ignore: the registry is best-effort and must never crash the app
            }
        } else {
            FileManager.default.createFile(atPath: path, contents: data, attributes: nil)
        }
    }

    // Folders that just got a color (one write, however many folders).
    static func markColored(_ folders: [String]) {
        if folders.isEmpty { return }
        append(folders.map { "FOLDER\t" + $0 }.joined(separator: "\n"), to: manifest)
    }

    // Folders that went back to the original icon.
    static func markOriginal(_ folders: [String]) {
        if folders.isEmpty { return }
        let gone = Set(folders)
        let kept = lines(manifest).filter { line in
            let parts = line.components(separatedBy: "\t")
            return !(parts.count == 2 && gone.contains(parts[1]))
        }
        write(manifest, kept)
    }

    // Every folder Mac Folderator colored (also reads the entries of older versions).
    static func coloredFolders() -> [String] {
        var out: [String] = []
        var seen = Set<String>()
        for l in lines(manifest) {
            let parts = l.components(separatedBy: "\t")
            if parts.count == 2 && (parts[0] == "FOLDER" || parts[0] == "AUTO") && !seen.contains(parts[1]) {
                seen.insert(parts[1])
                out.append(parts[1])
            }
        }
        return out
    }
}
