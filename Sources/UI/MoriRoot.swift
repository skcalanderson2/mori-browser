import SwiftUI
import AppKit

/// Bridge object the ObjC++ AppDelegate calls to build and own the SwiftUI
/// chrome. Holds the single shared BrowserStore for the window.
@objc(MoriRoot)
final class MoriRoot: NSObject {
    /// Retained for the app lifetime so the store/tabs aren't deallocated.
    private static var shared: MoriRoot?

    let store = BrowserStore()

    @objc static func makeRootViewController() -> NSViewController {
        let root = MoriRoot()
        shared = root

        let hosting = NSHostingController(rootView: RootView(store: root.store))
        hosting.view.frame = NSRect(x: 0, y: 0, width: 1280, height: 820)
        return hosting
    }

    @objc static func prepareForTermination() {
        shared?.store.prepareForTermination()
    }

    @objc static func handleShortcutEvent(_ event: NSEvent) -> Bool {
        guard let store = shared?.store else { return false }
        return MoriCommands.handle(event, store: store)
    }

    // Menu-driven actions (called from the AppKit menu bar).
    // ⌘T / File ▸ New Tab opens the launcher (command palette) rather than
    // silently spawning a blank tab.
    @objc static func newTab() { shared?.store.presentLauncher() }
    @objc static func closeCurrentTab() {
        if let id = shared?.store.selectedTabID { shared?.store.closeTab(id) }
    }
    @objc static func reopenClosedTab() { shared?.store.reopenClosedTab() }
    @objc static func reload() { shared?.store.reload() }
    @objc static func forceReload() { shared?.store.reloadIgnoringCache() }
    @objc static func stop() { shared?.store.stop() }
    @objc static func goBack() { shared?.store.goBack() }
    @objc static func goForward() { shared?.store.goForward() }
    @objc static func goHome() { shared?.store.goHome() }
    @objc static func toggleSidebar() { shared?.store.toggleSidebar() }
    @objc static func toggleAIPanel() { shared?.store.toggleAIPanel() }
    @objc static func openSettings() { shared?.store.settingsVisible = true }
    @objc static func focusOmnibox() {
        NotificationCenter.default.post(name: .moriFocusOmnibox, object: nil)
    }
    @objc static func zoomIn() { shared?.store.zoomIn() }
    @objc static func zoomOut() { shared?.store.zoomOut() }
    @objc static func resetZoom() { shared?.store.resetZoom() }
    @objc static func toggleFindBar() { shared?.store.toggleFindBar() }
    @objc static func findNext() { shared?.store.findNext(forward: true) }
    @objc static func findPrevious() { shared?.store.findNext(forward: false) }
    @objc static func toggleDevTools() { shared?.store.toggleDevTools() }
    @objc static func printPage() { shared?.store.printPage() }
    @objc static func selectNextTab() { shared?.store.selectNextTab() }
    @objc static func selectPreviousTab() { shared?.store.selectPreviousTab() }

    @objc static func handleExtensionTabs(_ method: String,
                                          args: NSDictionary) -> NSDictionary {
        guard let store = shared?.store else {
            return ["error": "Browser store is not ready."]
        }
        return store.handleExtensionTabs(method: method, args: args)
    }

    @objc static func handleExtensionWindows(_ method: String,
                                             args: NSDictionary) -> NSDictionary {
        guard let store = shared?.store else {
            return ["error": "Browser store is not ready."]
        }
        return store.handleExtensionWindows(method: method, args: args)
    }

    @objc static func handleExtensionDownloads(_ method: String,
                                                args: NSDictionary) -> NSDictionary {
        guard let store = shared?.store else {
            return ["error": "Browser store is not ready."]
        }
        return store.handleExtensionDownloads(method: method, args: args)
    }

    @objc static func handleExtensionSessions(_ method: String,
                                              args: NSDictionary) -> NSDictionary {
        guard let store = shared?.store else {
            return ["error": "Browser store is not ready."]
        }
        return store.handleExtensionSessions(method: method, args: args)
    }

    @objc static func handleExtensionScripting(_ method: String,
                                               args: NSDictionary) -> NSDictionary {
        guard let store = shared?.store else {
            return ["error": "Browser store is not ready."]
        }
        return store.handleExtensionScripting(method: method, args: args)
    }

    @objc static func handleExtensionAction(_ method: String,
                                            args: NSDictionary) -> NSDictionary {
        guard let extensionID = args["extensionId"] as? String, !extensionID.isEmpty else {
            return ["error": "Missing extension id."]
        }
        return ExtensionStore.shared.handleAction(method: method,
                                                 args: args,
                                                 extensionID: extensionID)
    }

    @objc static func handleExtensionManagement(_ method: String,
                                                args: NSDictionary) -> NSDictionary {
        guard let extensionID = args["extensionId"] as? String, !extensionID.isEmpty else {
            return ["error": "Missing extension id."]
        }
        return ExtensionStore.shared.handleManagement(method: method,
                                                     args: args,
                                                     extensionID: extensionID)
    }

    @objc static func handleExtensionBookmarks(_ method: String,
                                               args: NSDictionary) -> NSDictionary {
        BookmarkStore.shared.handleExtensionBookmarks(method: method, args: args)
    }

    @objc static func handleExtensionHistory(_ method: String,
                                             args: NSDictionary) -> NSDictionary {
        HistoryStore.shared.handleExtensionHistory(method: method, args: args)
    }

    @objc static func handleExtensionBrowsingData(_ method: String,
                                                  args: NSDictionary) -> NSDictionary {
        guard let store = shared?.store else {
            return ["error": "Browser store is not ready."]
        }
        return store.handleExtensionBrowsingData(method: method, args: args)
    }

    @objc static func handleExtensionRuntime(_ method: String,
                                             args: NSDictionary) -> NSDictionary {
        guard let store = shared?.store else {
            return ["error": "Browser store is not ready."]
        }
        return store.handleExtensionRuntime(method: method, args: args)
    }
}

/// The single source of truth for every browser keyboard shortcut.
///
/// `handle(_:store:)` is reached from two interception points, chosen by where
/// keyboard focus currently sits:
///   • `MoriApplication.sendEvent:` — catches shortcuts when focus is on the
///     native chrome (omnibox, launcher, sidebar), before the responder chain.
///   • `BrowserClient::OnPreKeyEvent` — catches shortcuts when focus is on CEF
///     web content. The OS key event reaches the browser process on the CEF UI
///     thread *before* the renderer sees it; on macOS that `os_event` is the very
///     same `NSEvent`, so it routes straight through `handle`.
///
/// Whichever path matches a combo consumes the event (returns true), so the
/// shortcut fires on the *first* press regardless of focus. The two paths are
/// mutually exclusive — a consumed event never reaches the other — so there is
/// no double-dispatch. (A previous local `addLocalMonitorForEvents` monitor was
/// removed: it duplicated `sendEvent:` for native focus and, like it, could be
/// beaten by a focused web view, which is exactly the "press twice" flakiness
/// `OnPreKeyEvent` now eliminates.)
///
/// The shortcuts are *also* declared on the AppKit menu bar (in AppDelegate) so
/// they stay discoverable and show their key equivalents.
///
/// We intentionally do NOT intercept the standard text-editing combos
/// (Cmd-Z/X/C/V/A and Cmd-Shift-Z): those must reach the focused web view / text
/// field, so they fall through unchanged.
enum MoriCommands {
    private static let shortcutModifierMask: NSEvent.ModifierFlags = [
        .command, .shift, .option, .control
    ]

    static func handle(_ event: NSEvent, store: BrowserStore) -> Bool {
        guard event.type == .keyDown else { return false }
        let flags = event.modifierFlags.intersection(shortcutModifierMask)
        let key = normalizedKey(for: event)
        let keyCode = event.keyCode

        // Esc dismisses the launcher / find bar when open (otherwise pass
        // through so it keeps its normal meaning, e.g. exiting full screen).
        if keyCode == 53, store.launcherVisible {
            store.dismissLauncher(); return true
        }
        if keyCode == 53, store.findBarVisible {
            store.hideFindBar(); return true
        }

        // Cmd-Opt-I → Developer Tools.
        if flags == [.command, .option], key == "i" {
            store.toggleDevTools(); return true
        }

        // Opt-A → toggle the AI sidebar. Matched by key code (0 == "A") rather
        // than character, because Option rewrites the glyph (A → "å").
        if flags == .option, keyCode == 0 {
            store.toggleAIPanel(); return true
        }

        // Cmd-Shift-... combos. Normalize shifted characters so the first
        // press works whether AppKit reports "T" or "t", "}" or "]", etc.
        if flags == [.command, .shift] {
            switch key {
            case "]": store.selectNextTab(); return true
            case "[": store.selectPreviousTab(); return true
            case "t": store.reopenClosedTab(); return true
            case "r": store.reloadIgnoringCache(); return true
            case "g": store.findNext(forward: false); return true
            case "h": store.goHome(); return true
            case "=", "+": store.zoomIn(); return true
            default: break
            }
        }

        // The README advertises Ctrl-S for the sidebar; keep Cmd-S below
        // as the menu-discoverable shortcut.
        if flags == .control, key == "s" {
            store.toggleSidebar(); return true
        }

        // Plain Cmd-... combos.
        if flags == .command {
            // Cmd-1...Cmd-9 -> jump to that tab (9 = last tab), like Safari/Chrome.
            if let digit = key.first, let ordinal = digit.wholeNumberValue,
               (1...9).contains(ordinal) {
                store.selectTab(atOrdinal: ordinal); return true
            }
            switch key {
            case "t": store.toggleLauncher(); return true
            case "w":
                if let id = store.selectedTabID { store.closeTab(id) }
                return true
            case "l":
                NotificationCenter.default.post(name: .moriFocusOmnibox, object: nil)
                return true
            case "r": store.reload(); return true
            case "p": store.printPage(); return true
            case "f": store.toggleFindBar(); return true
            case "g": store.findNext(forward: true); return true
            case "s": store.toggleSidebar(); return true
            case "k": store.toggleAIPanel(); return true
            case ".": store.stop(); return true
            case "=": store.zoomIn(); return true
            case "-": store.zoomOut(); return true
            case "0": store.resetZoom(); return true
            case "[": store.goBack(); return true
            case "]": store.goForward(); return true
            case ",": store.settingsVisible = true; return true
            case "h": NSApp.hide(nil); return true
            case "m":
                (NSApp.keyWindow ?? NSApp.mainWindow)?.performMiniaturize(nil)
                return true
            case "q": NSApp.terminate(nil); return true
            default: break
            }
        }

        if isTextEditingShortcut(flags: flags, key: key) {
            return false
        }

        // Extension manifest `commands` shortcuts. These are owned by
        // Mori's chrome layer and dispatched into the extension contexts,
        // but Mori's built-in browser/app shortcuts take precedence.
        if let command = ExtensionStore.shared.command(matching: event) {
            store.activateExtensionCommand(command)
            return true
        }

        return false
    }

    private static func isTextEditingShortcut(flags: NSEvent.ModifierFlags,
                                              key: String) -> Bool {
        if flags == .command {
            return ["a", "c", "v", "x", "z"].contains(key)
        }
        if flags == [.command, .shift], key == "z" {
            return true
        }
        return false
    }

    private static func normalizedKey(for event: NSEvent) -> String {
        switch event.keyCode {
        case 123: return "left"
        case 124: return "right"
        case 125: return "down"
        case 126: return "up"
        case 53: return "escape"
        default:
            break
        }

        guard let chars = event.charactersIgnoringModifiers, !chars.isEmpty else {
            return ""
        }

        switch chars {
        case "{": return "["
        case "}": return "]"
        case "\u{F700}": return "up"
        case "\u{F701}": return "down"
        case "\u{F702}": return "left"
        case "\u{F703}": return "right"
        default: return chars.lowercased()
        }
    }
}

extension Notification.Name {
    static let moriFocusOmnibox = Notification.Name("MoriFocusOmnibox")
    static let moriOpenExtensionPopup = Notification.Name("MoriOpenExtensionPopup")
    static let moriOpenExtensionUninstallURL = Notification.Name("MoriOpenExtensionUninstallURL")
}
