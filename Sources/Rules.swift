// Mac Folderator — which folders are touched, how a folder tree is collected and applied, diagnostics
import AppKit

enum Rules {
    static let skippedExtensions: Set<String> = [
        "app", "bundle", "framework", "photoslibrary", "xcodeproj", "xcworkspace", "rtfd",
        "pages", "numbers", "key", "playground", "musiclibrary", "tvlibrary", "fcpbundle", "logicx"
    ]
    static let skippedNames: Set<String> = ["node_modules", "__pycache__", "venv", "dist", "build", "target"]

    // True for hidden folders, packages and build/dependency folders (skipped INSIDE a chosen tree).
    static func shouldSkipName(_ path: String) -> Bool {
        let name = (path as NSString).lastPathComponent
        if name.hasPrefix(".") { return true }
        if skippedNames.contains(name) { return true }
        let ext = (name as NSString).pathExtension.lowercased()
        if !ext.isEmpty && skippedExtensions.contains(ext) { return true }
        return false
    }

    static func isDirectory(_ path: String) -> Bool {
        var isDir: ObjCBool = false
        return FileManager.default.fileExists(atPath: path, isDirectory: &isDir) && isDir.boolValue
    }

    static func isSymlink(_ path: String) -> Bool {
        return (try? FileManager.default.destinationOfSymbolicLink(atPath: path)) != nil
    }

    static func hasCustomIcon(_ path: String) -> Bool {
        return FileManager.default.fileExists(atPath: path + "/Icon\r")
    }

    // True for folders under iCloud (iCloud Drive, "Desktop & Documents" sync, CloudStorage providers).
    static func isICloud(_ path: String) -> Bool {
        if path.contains("/Library/Mobile Documents/") || path.contains("/Library/CloudStorage/") { return true }
        let url = URL(fileURLWithPath: path)
        if let v = try? url.resourceValues(forKeys: [URLResourceKey.isUbiquitousItemKey]), v.isUbiquitousItem == true {
            return true
        }
        let home = NSHomeDirectory()
        if let finder = UserDefaults(suiteName: "com.apple.finder") {
            if finder.bool(forKey: "FXICloudDriveDesktop") && isUnder(path, root: home + "/Desktop") { return true }
            if finder.bool(forKey: "FXICloudDriveDocuments") && isUnder(path, root: home + "/Documents") { return true }
        }
        return false
    }

    static func isUnder(_ path: String, root: String) -> Bool {
        let r = root.hasSuffix("/") ? String(root.dropLast()) : root
        return path == r || path.hasPrefix(r + "/")
    }
}

enum Applier {
    // The chosen folders, plus (optionally) every subfolder at any depth.
    // Inside the tree, hidden folders, packages, dependency/build folders and symbolic links are skipped.
    static func collect(roots: [String], includeSubfolders: Bool) -> [String] {
        var out: [String] = []
        var seen = Set<String>()
        let fm = FileManager.default
        for root in roots {
            if !Rules.isDirectory(root) { continue }
            if seen.insert(root).inserted { out.append(root) }
            if !includeSubfolders { continue }
            let keys: [URLResourceKey] = [URLResourceKey.isDirectoryKey, URLResourceKey.isSymbolicLinkKey]
            guard let en = fm.enumerator(at: URL(fileURLWithPath: root), includingPropertiesForKeys: keys,
                                         options: [FileManager.DirectoryEnumerationOptions.skipsHiddenFiles,
                                                   FileManager.DirectoryEnumerationOptions.skipsPackageDescendants]) else { continue }
            while let obj = en.nextObject() {
                guard let url = obj as? URL else { continue }
                let vals = try? url.resourceValues(forKeys: Set(keys))
                if vals?.isSymbolicLink == true { continue }
                if vals?.isDirectory != true { continue }
                let path = url.path
                if Rules.shouldSkipName(path) {
                    en.skipDescendants()
                    continue
                }
                if seen.insert(path).inserted { out.append(path) }
            }
        }
        return out
    }

    // Sets (or, with image == nil, removes) the icon of every folder. Returns the folders that worked and the ones that did not.
    static func apply(image: NSImage?, to folders: [String]) -> (done: [String], failed: [String]) {
        var done: [String] = []
        var failed: [String] = []
        for p in folders {
            if NSWorkspace.shared.setIcon(image, forFile: p, options: []) {
                done.append(p)
            } else {
                failed.append(p)
            }
        }
        return (done, failed)
    }
}

enum Diagnose {
    // Prints (to the terminal) what is going on with a folder.
    static func report(_ pathIn: String) -> [String] {
        var out: [String] = []
        var path = pathIn
        while path.count > 1 && path.hasSuffix("/") { path.removeLast() }
        out.append("Folder: " + path)
        if !Rules.isDirectory(path) { out.append("x not found, or not a folder"); return out }
        if Rules.isSymlink(path) { out.append("- it is a symbolic link") }
        if Rules.hasCustomIcon(path) {
            let mine = Registry.coloredFolders().contains(path)
            out.append(mine ? "ok it has a Mac Folderator color (if it looks wrong, run: killall Finder)"
                            : "- it has a custom icon that was not set by Mac Folderator")
        } else {
            out.append("- it has the original icon")
        }
        if Rules.shouldSkipName(path) { out.append("- its name is one that is skipped INSIDE a tree (hidden, package, node_modules, build folders)") }
        if Rules.isICloud(path) { out.append("- it is under iCloud: after coloring, Get Info is opened and closed once to make the icon show") }
        return out
    }
}
