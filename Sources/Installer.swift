// Mac Folderator — installs / removes the Finder "Color Folder" quick action, retires the old watcher, self-install from the disk image
import AppKit

enum Installer {
    // Older versions installed a background watcher with one of these labels; it is retired on launch.
    static let legacyAgentLabels = ["it.macfolderator.watch", "it.macfolderator.folderwatch"]
    static let commandMarker = "mf-v2"
    static let bundleID = "it.macfolderator.app"

    static var servicesDir: String { return NSHomeDirectory() + "/Library/Services" }
    static let workflowNames = ["Colora cartella.workflow", "Color Folder.workflow"]

    @discardableResult
    static func run(_ launchPath: String, _ args: [String]) -> Int32 {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: launchPath)
        p.arguments = args
        p.standardOutput = FileHandle.nullDevice
        p.standardError = FileHandle.nullDevice
        do {
            try p.run()
        } catch {
            return -1
        }
        p.waitUntilExit()
        return p.terminationStatus
    }

    // MARK: retire the background watcher of older versions

    static func removeAgent() {
        let uid = String(getuid())
        for label in legacyAgentLabels {
            let plist = NSHomeDirectory() + "/Library/LaunchAgents/" + label + ".plist"
            if FileManager.default.fileExists(atPath: plist) {
                run("/bin/launchctl", ["bootout", "gui/" + uid + "/" + label])
                try? FileManager.default.removeItem(atPath: plist)
            }
        }
    }

    // MARK: Finder quick action (right-click > Quick Actions > Color Folder)

    static func installQuickAction() -> Bool {
        let name = tr("Colora cartella", "Color Folder")
        let wf = servicesDir + "/" + name + ".workflow"
        let contents = wf + "/Contents"
        let service1 = "$HOME/Library/Services/Colora cartella.workflow"
        let service2 = "$HOME/Library/Services/Color Folder.workflow"
        let command = "if ! /usr/bin/open -n -b \(bundleID) --args \"$@\"; then rm -rf \"\(service1)\" \"\(service2)\"; fi # \(commandMarker)"
        let info = """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0"><dict>
        <key>NSServices</key>
        <array><dict>
        <key>NSMenuItem</key><dict><key>default</key><string>\(name)</string></dict>
        <key>NSMessage</key><string>runWorkflowAsService</string>
        <key>NSRequiredContext</key><dict><key>NSApplicationIdentifier</key><string>com.apple.finder</string></dict>
        <key>NSSendFileTypes</key><array><string>public.folder</string></array>
        </dict></array>
        </dict></plist>
        """
        let wflow = """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0"><dict>
        <key>AMApplicationBuild</key><string>523</string>
        <key>AMApplicationVersion</key><string>2.10</string>
        <key>AMDocumentVersion</key><string>2</string>
        <key>actions</key>
        <array><dict>
        <key>action</key>
        <dict>
        <key>AMAccepts</key><dict><key>Container</key><string>List</string><key>Optional</key><true/><key>Types</key><array><string>com.apple.cocoa.path</string></array></dict>
        <key>AMActionVersion</key><string>2.0.3</string>
        <key>AMApplication</key><array><string>Automator</string></array>
        <key>AMParameterProperties</key><dict><key>COMMAND_STRING</key><dict/><key>CheckedForUserDefaultShell</key><dict/><key>inputMethod</key><dict/><key>shell</key><dict/><key>source</key><dict/></dict>
        <key>AMProvides</key><dict><key>Container</key><string>List</string><key>Types</key><array><string>com.apple.cocoa.string</string></array></dict>
        <key>ActionBundlePath</key><string>/System/Library/Automator/Run Shell Script.action</string>
        <key>ActionName</key><string>Run Shell Script</string>
        <key>ActionParameters</key>
        <dict>
        <key>COMMAND_STRING</key><string>\(command)</string>
        <key>CheckedForUserDefaultShell</key><true/>
        <key>inputMethod</key><integer>1</integer>
        <key>shell</key><string>/bin/bash</string>
        <key>source</key><string></string>
        </dict>
        <key>BundleIdentifier</key><string>com.apple.RunShellScript</string>
        <key>CFBundleVersion</key><string>2.0.3</string>
        <key>CanShowSelectedItemsWhenRun</key><false/>
        <key>CanShowWhenRun</key><true/>
        <key>Category</key><array><string>AMCategoryUtilities</string></array>
        <key>Class Name</key><string>RunShellScriptAction</string>
        <key>InputUUID</key><string>3F7A1C2E-0000-4000-8000-0000000000A1</string>
        <key>Keywords</key><array><string>Shell</string><string>Script</string></array>
        <key>OutputUUID</key><string>3F7A1C2E-0000-4000-8000-0000000000A2</string>
        <key>UUID</key><string>3F7A1C2E-0000-4000-8000-0000000000A3</string>
        <key>UnlocalizedApplications</key><array><string>Automator</string></array>
        <key>arguments</key><dict/>
        <key>isViewVisible</key><true/>
        <key>location</key><string>309.000000:305.000000</string>
        <key>nibPath</key><string>/System/Library/Automator/Run Shell Script.action/Contents/Resources/Base.lproj/main.nib</string>
        </dict>
        <key>isViewVisible</key><true/>
        </dict></array>
        <key>connectors</key><dict/>
        <key>workflowMetaData</key>
        <dict>
        <key>serviceInputTypeIdentifier</key><string>com.apple.Automator.fileSystemObject</string>
        <key>serviceOutputTypeIdentifier</key><string>com.apple.Automator.nothing</string>
        <key>serviceProcessesInput</key><integer>0</integer>
        <key>workflowTypeIdentifier</key><string>com.apple.Automator.servicesMenu</string>
        </dict>
        </dict></plist>
        """
        removeQuickAction()
        do {
            try FileManager.default.createDirectory(atPath: contents, withIntermediateDirectories: true, attributes: nil)
            try info.write(toFile: contents + "/Info.plist", atomically: true, encoding: String.Encoding.utf8)
            try wflow.write(toFile: contents + "/document.wflow", atomically: true, encoding: String.Encoding.utf8)
        } catch {
            return false
        }
        run("/System/Library/CoreServices/pbs", ["-update"])
        return true
    }

    // Installs the Quick Action if it is missing or comes from an older version.
    static func ensureQuickAction() {
        let name = tr("Colora cartella", "Color Folder")
        let file = servicesDir + "/" + name + ".workflow/Contents/document.wflow"
        if let text = try? String(contentsOfFile: file, encoding: String.Encoding.utf8), text.contains(commandMarker) { return }
        _ = installQuickAction()
    }

    static func removeQuickAction() {
        for n in workflowNames {
            try? FileManager.default.removeItem(atPath: servicesDir + "/" + n)
        }
    }

    // MARK: uninstall (does NOT touch wallpaper, appearance, Dock or any other app)

    @discardableResult
    static func uninstall(resetIcons: Bool) -> Int {
        removeAgent()
        removeQuickAction()
        var reset = 0
        if resetIcons {
            for f in Registry.coloredFolders() {
                if FileManager.default.fileExists(atPath: f) {
                    if NSWorkspace.shared.setIcon(nil, forFile: f, options: []) { reset += 1 }
                }
            }
        }
        try? FileManager.default.removeItem(atPath: Registry.state)
        run("/System/Library/CoreServices/pbs", ["-update"])
        return reset
    }

    // MARK: running from the disk image: install a copy in Applications

    static var isRunningFromDiskImage: Bool {
        let p = Bundle.main.bundlePath
        return p.hasPrefix("/Volumes/") || p.contains("/AppTranslocation/")
    }

    // Copies this app to /Applications (or ~/Applications) and returns the new path.
    static func copySelfToApplications() -> String? {
        let src = Bundle.main.bundlePath
        let fm = FileManager.default
        let dirs = ["/Applications", NSHomeDirectory() + "/Applications"]
        for dir in dirs {
            try? fm.createDirectory(atPath: dir, withIntermediateDirectories: true, attributes: nil)
            let dest = dir + "/Mac Folderator.app"
            try? fm.removeItem(atPath: dest)
            do {
                try fm.copyItem(atPath: src, toPath: dest)
                run("/usr/bin/xattr", ["-dr", "com.apple.quarantine", dest])
                return dest
            } catch {
                continue
            }
        }
        return nil
    }

    // Ejects the disk image a few seconds after this process has quit.
    static func ejectDiskLater() {
        let p = Bundle.main.bundlePath
        if !p.hasPrefix("/Volumes/") { return }
        let comps = p.components(separatedBy: "/")
        if comps.count < 3 { return }
        let volume = "/Volumes/" + comps[2]
        let pr = Process()
        pr.executableURL = URL(fileURLWithPath: "/bin/sh")
        pr.arguments = ["-c", "sleep 3; /usr/bin/hdiutil detach \"$1\" >/dev/null 2>&1 || /usr/bin/hdiutil detach \"$1\" -force >/dev/null 2>&1", "sh", volume]
        pr.standardOutput = FileHandle.nullDevice
        pr.standardError = FileHandle.nullDevice
        try? pr.run()
    }

    // Every installed copy of the app: Applications, ~/Applications, or wherever Launch Services finds one
    // (copies on a disk image, in the Trash or in a translocated location are ignored).
    static func installedCopyPaths() -> [String] {
        let fm = FileManager.default
        var found: [String] = []
        func add(_ p: String) {
            if !fm.fileExists(atPath: p) { return }
            if p.hasPrefix("/Volumes/") || p.contains("/AppTranslocation/") || p.contains("/.Trash/") { return }
            // build outputs (…/dist/Mac Folderator.app) are not installed copies: leave them alone
            if ((p as NSString).deletingLastPathComponent as NSString).lastPathComponent == "dist" { return }
            let std = (p as NSString).standardizingPath
            if !found.contains(std) { found.append(std) }
        }
        add("/Applications/Mac Folderator.app")
        add(NSHomeDirectory() + "/Applications/Mac Folderator.app")
        for url in NSWorkspace.shared.urlsForApplications(withBundleIdentifier: bundleID) { add(url.path) }
        return found
    }

    // "1.0 (build 202610181505)" for the app at a path.
    static func version(ofAppAt path: String) -> String {
        guard let info = NSDictionary(contentsOfFile: path + "/Contents/Info.plist") else { return "?" }
        let v = (info["CFBundleShortVersionString"] as? String) ?? "?"
        let b = (info["CFBundleVersion"] as? String) ?? "?"
        return "\(v) (build \(b))"
    }

    static func installedCopyPath() -> String? {
        return installedCopyPaths().first
    }

    // Quits any other running copy of the app (for example the installed one, when uninstalling from the disk image).
    static func quitOtherInstances() {
        let me = ProcessInfo.processInfo.processIdentifier
        let others = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).filter { $0.processIdentifier != me }
        for a in others { _ = a.terminate() }
        if others.isEmpty { return }
        Thread.sleep(forTimeInterval: 0.8)
        for a in others where !a.isTerminated { _ = a.forceTerminate() }
    }

    // MARK: uninstall = run the removal script in Terminal

    // Terminal is allowed to delete apps and can ask for the password, so the removal runs there:
    // the script (bundled in the app) is copied to /tmp and opened as a .command file.
    static var hasUninstallScript: Bool {
        return Bundle.main.path(forResource: "uninstall", ofType: "sh") != nil
    }

    static func launchUninstallScript(keepColors: Bool) -> Bool {
        guard let src = Bundle.main.path(forResource: "uninstall", ofType: "sh") else {
            log("uninstall script NOT found inside the app (rebuild with the latest build.sh)")
            return false
        }
        log("uninstall script found: \(src)")
        let fm = FileManager.default
        let scriptPath = "/tmp/mac-folderator-uninstall.sh"
        let commandPath = "/tmp/Uninstall Mac Folderator.command"
        try? fm.removeItem(atPath: scriptPath)
        try? fm.removeItem(atPath: commandPath)
        do {
            try fm.copyItem(atPath: src, toPath: scriptPath)
        } catch {
            return false
        }
        let arg: String = keepColors ? " --keep-colors" : ""
        let wait: String = tr("Premi Invio per chiudere questa finestra", "Press Return to close this window")
        // After Return the window closes itself (Terminal would otherwise keep it open showing "Process completed").
        let closeWindow = "( osascript -e 'tell application \"Terminal\"' -e 'repeat with w in windows' -e 'try' -e \"if (tty of selected tab of w) is \\\"$TTY_NAME\\\" then close w\" -e 'end try' -e 'end repeat' -e 'end tell' >/dev/null 2>&1 & )"
        let shellLines: [String] = [
            "#!/bin/bash",
            "bash \"\(scriptPath)\"\(arg)",
            "echo",
            "read -r -p \"\(wait) \" _",
            "TTY_NAME=\"$(tty)\"",
            closeWindow,
            "exit 0"
        ]
        let text = shellLines.joined(separator: "\n") + "\n"
        do {
            try text.write(toFile: commandPath, atomically: true, encoding: String.Encoding.utf8)
        } catch {
            return false
        }
        let perms: [FileAttributeKey: Any] = [FileAttributeKey.posixPermissions: 0o755]
        try? fm.setAttributes(perms, ofItemAtPath: scriptPath)
        try? fm.setAttributes(perms, ofItemAtPath: commandPath)
        // 1) open the .command file with Terminal explicitly
        let rc = run("/usr/bin/open", ["-a", "Terminal", commandPath])
        log("open -a Terminal -> exit code \(rc)")
        if rc == 0 { return true }
        // 2) ask Terminal to run the script (macOS may ask to let Mac Folderator control Terminal)
        let cmd = "bash '\(scriptPath)'\(arg)"
        let out = Finder.runOSAScript("tell application \"Terminal\"\nactivate\ndo script \"\(cmd)\"\nend tell")
        log("Terminal do script -> \(out)")
        return !out.lowercased().contains("error")
    }

    // MARK: removing the installed app (with a log, so a failure can be understood)

    static let logPath = "/tmp/macfolderator-uninstall.log"

    static func log(_ text: String) {
        let line = "\(Date())  \(text)\n"
        guard let data = line.data(using: String.Encoding.utf8) else { return }
        if let h = FileHandle(forWritingAtPath: logPath) {
            _ = try? h.seekToEnd()
            try? h.write(contentsOf: data)
            try? h.close()
        } else {
            FileManager.default.createFile(atPath: logPath, contents: data, attributes: nil)
        }
    }

    enum RemoveResult {
        case deleted
        case trashed
        case failed
    }

    // Removes an app in three steps: delete it; else move it to the Trash; else ask the Finder to move it to the Trash
    // (the Finder is always allowed to). Every step is logged and the result is checked.
    static func removeApp(at path: String) -> RemoveResult {
        let fm = FileManager.default
        log("remove: \(path)")
        do {
            try fm.removeItem(atPath: path)
        } catch {
            log("  removeItem failed: \(error.localizedDescription)")
        }
        if !fm.fileExists(atPath: path) {
            log("  deleted")
            return RemoveResult.deleted
        }
        do {
            var trashedURL: NSURL?
            try fm.trashItem(at: URL(fileURLWithPath: path), resultingItemURL: &trashedURL)
            log("  moved to the Trash")
        } catch {
            log("  trashItem failed: \(error.localizedDescription)")
        }
        if !fm.fileExists(atPath: path) { return RemoveResult.trashed }
        let esc = Finder.appleScriptEscape(path)
        let out = Finder.runOSAScript("tell application \"Finder\" to delete (POSIX file \"\(esc)\" as alias)")
        log("  Finder says: \(out)")
        if !fm.fileExists(atPath: path) { return RemoveResult.trashed }
        log("  still there")
        return RemoveResult.failed
    }

    // Removes every installed copy (and this one, unless it runs from the disk image).
    static func removeInstalledApps() -> (deleted: [String], trashed: [String], failed: [String]) {
        log("uninstall started, running from: \(Bundle.main.bundlePath)")
        quitOtherInstances()
        var targets = installedCopyPaths()
        let me = Bundle.main.bundlePath
        if me.hasSuffix(".app") && !isRunningFromDiskImage {
            let std = (me as NSString).standardizingPath
            if !targets.contains(std) { targets.append(std) }
        }
        log("copies found: \(targets)")
        var deleted: [String] = []
        var trashed: [String] = []
        var failed: [String] = []
        for t in targets {
            switch removeApp(at: t) {
            case RemoveResult.deleted: deleted.append(t)
            case RemoveResult.trashed: trashed.append(t)
            case RemoveResult.failed: failed.append(t)
            }
        }
        return (deleted, trashed, failed)
    }
}
