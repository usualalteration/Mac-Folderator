// Mac Folderator — entry point
//
//   (no option)                 open the "Color Folder" window (choose the folders inside it)
//   <folder> [<folder> ...]     the same, for the given folders (this is what the Finder Quick Action does)
//   --diagnose <folder>         explain the state of a folder (terminal)
//   --reset <folders...>        restore the original icon of the folders and their subfolders (terminal)
//                               add --no-subfolders to leave the subfolders alone
//   --uninstall [--keep-icons]  remove the Quick Action, the settings and the app (terminal)
//   --welcome                   (used after installing from the disk image)
import AppKit

enum Finder {
    static func clean(_ p: String) -> String {
        var c = p
        while c.count > 1 && c.hasSuffix("/") { c.removeLast() }
        return c
    }

    // Folders currently selected in the Finder.
    static func selection() -> [String] {
        let source = "tell application \"Finder\"\nset out to \"\"\nrepeat with i in (selection as alias list)\nset out to out & POSIX path of i & linefeed\nend repeat\nreturn out\nend tell"
        var result: [String] = []
        if let script = NSAppleScript(source: source) {
            let desc = script.executeAndReturnError(nil)
            if let s = desc.stringValue {
                for line in s.components(separatedBy: "\n") where !line.isEmpty {
                    if Rules.isDirectory(line) { result.append(clean(line)) }
                }
            }
        }
        return result
    }

    static func askForFolders() -> [String] {
        bringToFront()
        let panel = NSOpenPanel()
        panel.title = tr("Scegli le cartelle da colorare", "Choose the folders to color")
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = true
        if panel.runModal() == NSApplication.ModalResponse.OK {
            return panel.urls.map { clean($0.path) }
        }
        return []
    }

    // Escapes a path for use inside an AppleScript string.
    static func appleScriptEscape(_ p: String) -> String {
        return p.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"")
    }

    // Runs an AppleScript through /usr/bin/osascript (safe to call from a background thread) and returns its output.
    @discardableResult
    static func runOSAScript(_ source: String) -> String {
        let pr = Process()
        pr.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        pr.arguments = ["-e", source]
        let pipe = Pipe()
        pr.standardOutput = pipe
        pr.standardError = pipe
        do {
            try pr.run()
        } catch {
            return "could not start osascript"
        }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        pr.waitUntilExit()
        return (String(data: data, encoding: String.Encoding.utf8) ?? "").trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
    }

    // Folders under iCloud: open the Finder's "Get Info" window and close it again, which makes macOS apply the new icon.
    static func refreshViaInfo(_ path: String) {
        let esc = appleScriptEscape(path)
        let lines: [String] = [
            "tell application \"Finder\"",
            "try",
            "set f to (POSIX file \"\(esc)\") as alias",
            "open information window of f",
            "delay 0.8",
            "try",
            "close information window of f",
            "on error",
            "try",
            "if (class of window 1) is information window then close window 1",
            "end try",
            "end try",
            "end try",
            "end tell"
        ]
        runOSAScript(lines.joined(separator: "\n"))
    }

    // Opens the Finder's "Get Info" window of the folders and leaves it open.
    static func showInfo(_ paths: [String]) {
        for p in paths.prefix(3) {
            let esc = appleScriptEscape(p)
            let src = "tell application \"Finder\"\nopen information window of (POSIX file \"\(esc)\" as alias)\nend tell"
            if let script = NSAppleScript(source: src) {
                _ = script.executeAndReturnError(nil)
            }
        }
        if let finder = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.finder").first {
            if #available(macOS 14.0, *) {
                finder.activate()
            } else {
                finder.activate(options: [NSApplication.ActivationOptions.activateIgnoringOtherApps])
            }
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    var paths: [String] = []
    var showWelcome = false
    var controllers: [AnyObject] = []

    func applicationDidFinishLaunching(_ notification: Notification) {
        if Installer.isRunningFromDiskImage {
            offerSelfInstall()
            return
        }
        Installer.removeAgent()          // older versions installed a background watcher: retire it
        Installer.ensureQuickAction()    // right-click > Quick Actions > Color Folder
        buildMenu()
        bringToFront()
        if showWelcome { welcome() }
        // The window always opens; the folders can be chosen from inside it (or come from the Quick Action).
        openPicker(paths)
    }

    // The app stays open as long as a window is open: it quits when the last window is closed.
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }

    func application(_ sender: NSApplication, openFiles filenames: [String]) {
        var added: [String] = []
        for f in filenames where Rules.isDirectory(f) {
            let c = Finder.clean(f)
            if !paths.contains(c) { paths.append(c) }
            added.append(c)
        }
        // before the window exists the folders wait in `paths`; afterwards they go straight into the open window
        if !controllers.isEmpty && !added.isEmpty { addToOpenWindow(added) }
        sender.reply(toOpenOrPrint: NSApplication.DelegateReply.success)
    }

    func openPicker(_ chosen: [String]) {
        let c = PickerController(paths: chosen)
        controllers.append(c)
        c.show()
        bringToFront()
    }

    // Folders passed while the app is already running (Quick Action, drag on the icon): reuse the open window.
    func addToOpenWindow(_ chosen: [String]) {
        if let c = controllers.last as? PickerController {
            c.setPaths(chosen)
            c.show()
            bringToFront()
        } else {
            openPicker(chosen)
        }
    }

    func welcome() {
        let a = NSAlert()
        a.messageText = tr("Mac Folderator è installato", "Mac Folderator is installed")
        a.informativeText = tr("Per colorare una cartella: tasto destro → Azioni rapide → Colora cartella. Qui scegli subito le cartelle da colorare; l'app colora la cartella scelta e le sue sottocartelle.",
                               "To color a folder: right-click → Quick Actions → Color Folder. Choose the folders to color right now; the app colors the chosen folder and its subfolders.")
        a.addButton(withTitle: "OK")
        a.runModal()
    }

    func buildMenu() {
        let mainMenu = NSMenu()
        let appItem = NSMenuItem()
        mainMenu.addItem(appItem)
        let appMenu = NSMenu()
        let choose = NSMenuItem(title: tr("Scegli cartelle…", "Choose folders…"), action: #selector(chooseFolders), keyEquivalent: "o")
        choose.target = self
        appMenu.addItem(choose)
        let uninstall = NSMenuItem(title: tr("Disinstalla Mac Folderator…", "Uninstall Mac Folderator…"),
                                   action: #selector(uninstallFlow), keyEquivalent: "")
        uninstall.target = self
        appMenu.addItem(uninstall)
        appMenu.addItem(NSMenuItem.separator())
        appMenu.addItem(NSMenuItem(title: tr("Esci da Mac Folderator", "Quit Mac Folderator"),
                                   action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        appItem.submenu = appMenu
        NSApp.mainMenu = mainMenu
    }

    @objc func chooseFolders() {
        if let c = controllers.last as? PickerController {
            c.chooseTapped()
            return
        }
        let chosen = Finder.askForFolders()
        openPicker(chosen)
    }

    // Launched straight from the disk image: install a copy in Applications, open it, eject the disk.
    // If Mac Folderator is already installed, the same double-click also offers to uninstall it.
    func offerSelfInstall() {
        bringToFront()
        let installed = Installer.installedCopyPath()
        let a = NSAlert()
        if installed == nil {
            a.messageText = tr("Installare Mac Folderator?", "Install Mac Folderator?")
            a.informativeText = tr("Verrà copiato nella cartella Applicazioni e aperto da lì; poi il disco verrà espulso.",
                                   "It will be copied to the Applications folder and opened from there; then the disk will be ejected.")
                + "\n\n" + tr("Versione di questo disco: ", "Version on this disk: ") + Installer.version(ofAppAt: Bundle.main.bundlePath)
            a.addButton(withTitle: tr("Installa", "Install"))
            a.addButton(withTitle: tr("Annulla", "Cancel"))
        } else {
            a.messageText = tr("Mac Folderator è già installato", "Mac Folderator is already installed")
            a.informativeText = tr("Vuoi aggiornarlo con questa versione o disinstallarlo?",
                                   "Do you want to update it with this version, or uninstall it?")
                + "\n\n" + tr("Installata: ", "Installed: ") + Installer.version(ofAppAt: installed ?? "")
                + "\n" + tr("Su questo disco: ", "On this disk: ") + Installer.version(ofAppAt: Bundle.main.bundlePath)
                + "\n" + tr("Script di rimozione nell'app: ", "Removal script in the app: ") + (Installer.hasUninstallScript ? "✓" : "✗ (rebuild)")
            a.addButton(withTitle: tr("Aggiorna", "Update"))
            a.addButton(withTitle: tr("Disinstalla…", "Uninstall…"))
            a.addButton(withTitle: tr("Annulla", "Cancel"))
        }
        let answer = a.runModal()
        if installed != nil && answer == NSApplication.ModalResponse.alertSecondButtonReturn {
            uninstallFlow()
            return
        }
        if answer != NSApplication.ModalResponse.alertFirstButtonReturn {
            NSApp.terminate(nil)
            return
        }
        guard let dest = Installer.copySelfToApplications() else {
            let f = NSAlert()
            f.messageText = tr("Installazione non riuscita", "Installation failed")
            f.informativeText = tr("Trascina Mac Folderator nella cartella Applicazioni a mano.",
                                   "Please drag Mac Folderator to the Applications folder by hand.")
            f.addButton(withTitle: "OK")
            f.runModal()
            NSApp.terminate(nil)
            return
        }
        Installer.run("/usr/bin/open", ["-n", dest, "--args", "--welcome"])
        Installer.ejectDiskLater()
        NSApp.terminate(nil)
    }

    @objc func uninstallFlow() {
        let alert = NSAlert()
        alert.messageText = tr("Disinstallare Mac Folderator?", "Uninstall Mac Folderator?")
        alert.informativeText = tr("Si aprirà il Terminale per completare la disinstallazione (può chiedere la password del Mac): verranno rimossi l'azione rapida del Finder, le impostazioni e l'app. Sfondo, tema, Dock e altre app non vengono toccati.",
                                   "Terminal will open to finish the uninstall (it may ask for your Mac password): the Finder quick action, the settings and the app will be removed. Your wallpaper, theme, Dock and other apps are not touched.")
        let box = NSButton(checkboxWithTitle: tr("Ripristina anche le icone originali delle cartelle colorate",
                                                 "Also restore the original icons of the colored folders"),
                           target: nil, action: nil)
        box.state = NSControl.StateValue.on
        box.sizeToFit()
        alert.accessoryView = box
        alert.alertStyle = NSAlert.Style.warning
        alert.addButton(withTitle: tr("Disinstalla", "Uninstall"))
        alert.addButton(withTitle: tr("Annulla", "Cancel"))
        bringToFront()
        if alert.runModal() != NSApplication.ModalResponse.alertFirstButtonReturn {
            if Installer.isRunningFromDiskImage { NSApp.terminate(nil) }
            return
        }
        // The removal runs in Terminal (it can delete apps and ask for the password): the app just hands over and quits.
        if Installer.launchUninstallScript(keepColors: box.state != NSControl.StateValue.on) {
            NSApp.terminate(nil)
            return
        }
        // Fallback (the script is not inside the app, or Terminal could not be opened): remove from here and say so.
        Installer.log("falling back to in-app removal")
        let reset = Installer.uninstall(resetIcons: box.state == NSControl.StateValue.on)
        let removal = Installer.removeInstalledApps()
        Installer.ejectDiskLater()
        let done = NSAlert()
        if !removal.failed.isEmpty {
            done.messageText = tr("Quasi fatto: l'app è ancora presente", "Almost done: the app is still there")
            done.informativeText = tr("Azione rapida e impostazioni sono state rimosse, ma macOS non mi ha lasciato eliminare l'app. La mostro nel Finder: trascinala nel Cestino. Per evitare il problema abilita Mac Folderator in Impostazioni di Sistema → Privacy e sicurezza → Gestione app.",
                                      "The Quick Action and settings were removed, but macOS did not let me delete the app. I am showing it in the Finder: drag it to the Trash. To avoid this, enable Mac Folderator in System Settings → Privacy & Security → App Management.")
                + "\n\n" + removal.failed.joined(separator: "\n")
                + "\n\n" + tr("Dettagli: ", "Details: ") + Installer.logPath
            NSWorkspace.shared.activateFileViewerSelecting(removal.failed.map { URL(fileURLWithPath: $0) })
        } else if !removal.trashed.isEmpty {
            done.messageText = tr("Mac Folderator è stato disinstallato", "Mac Folderator has been uninstalled")
            done.informativeText = tr("L'app è stata spostata nel Cestino: svuota il Cestino per eliminarla del tutto. Icone ripristinate: ",
                                      "The app was moved to the Trash: empty the Trash to delete it for good. Icons restored: ") + "\(reset)"
        } else if removal.deleted.isEmpty {
            done.messageText = tr("Impostazioni rimosse, ma non ho trovato nessuna copia installata dell'app",
                                  "Settings removed, but I did not find any installed copy of the app")
            done.informativeText = tr("Se Mac Folderator è ancora da qualche parte, trascinalo nel Cestino. Icone ripristinate: ",
                                      "If Mac Folderator is still somewhere, drag it to the Trash. Icons restored: ") + "\(reset)"
                + "\n\n" + tr("Dettagli: ", "Details: ") + Installer.logPath
        } else {
            done.messageText = tr("Mac Folderator è stato disinstallato", "Mac Folderator has been uninstalled")
            done.informativeText = tr("Icone ripristinate: ", "Icons restored: ") + "\(reset)"
        }
        done.addButton(withTitle: "OK")
        done.runModal()
        NSApp.terminate(nil)
    }
}

// MARK: - command line (headless) modes

func printHelp() {
    print("""
    Mac Folderator

      MacFolderator                       choose folders and open the 'Color Folder' window
      MacFolderator <folder> ...          open the window for the given folders
      MacFolderator --diagnose <folder>   explain the state of a folder
      MacFolderator --reset <folders...>  restore the original icon of the folders and their subfolders
                                          (add --no-subfolders to leave the subfolders alone)
      MacFolderator --uninstall           remove the Quick Action, the settings and the app (--keep-icons keeps the colors)
    """)
}

// If anything ever goes wrong, leave a readable trace in ~/.macfolderator/crash.log
NSSetUncaughtExceptionHandler { (exception: NSException) in
    let text = "\(Date())  \(exception.name.rawValue): \(exception.reason ?? "")\n"
        + exception.callStackSymbols.joined(separator: "\n") + "\n"
    try? FileManager.default.createDirectory(atPath: Registry.state, withIntermediateDirectories: true, attributes: nil)
    try? text.write(toFile: Registry.state + "/crash.log", atomically: true, encoding: String.Encoding.utf8)
}

let rawArgs = Array(CommandLine.arguments.dropFirst())
let application = NSApplication.shared
let appDelegate = AppDelegate()

if rawArgs.contains("--help") || rawArgs.contains("-h") {
    printHelp()
    exit(0)
}

if let i = rawArgs.firstIndex(of: "--diagnose") {
    let target = rawArgs.count > i + 1 ? rawArgs[i + 1] : ""
    for line in Diagnose.report(target) { print(line) }
    exit(0)
}

if let i = rawArgs.firstIndex(of: "--reset") {
    let given = Array(rawArgs[(i + 1)...]).filter { !$0.hasPrefix("--") }.map { Finder.clean($0) }
    let all = Applier.collect(roots: given, includeSubfolders: !rawArgs.contains("--no-subfolders"))
    let result = Applier.apply(image: nil, to: all)
    Registry.markOriginal(result.done)
    for r in given { NSWorkspace.shared.noteFileSystemChanged(r) }
    print("Folders restored: \(result.done.count)" + (result.failed.isEmpty ? "" : " | failed: \(result.failed.count)"))
    exit(0)
}

if rawArgs.contains("--uninstall") {
    let n = Installer.uninstall(resetIcons: !rawArgs.contains("--keep-icons"))
    print("Uninstalled. Icons restored: \(n)")
    exit(0)
}

// GUI
application.setActivationPolicy(NSApplication.ActivationPolicy.regular)
appDelegate.showWelcome = rawArgs.contains("--welcome")
for arg in rawArgs where !arg.hasPrefix("-") {
    if Rules.isDirectory(arg) {
        let c = Finder.clean(arg)
        if !appDelegate.paths.contains(c) { appDelegate.paths.append(c) }
    }
}
application.delegate = appDelegate
application.run()
