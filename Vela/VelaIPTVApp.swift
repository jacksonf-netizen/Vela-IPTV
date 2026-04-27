import SwiftUI
import AppKit

extension Notification.Name {
    /// Posted by AppDelegate when the app is about to terminate.
    /// SwiftUI views that own sheets should observe this and set their
    /// isPresented bindings to false so the app can exit cleanly.
    static let velaWillTerminate = Notification.Name("velaWillTerminate")
}

class AppDelegate: NSObject, NSApplicationDelegate {
    private var terminationRequested = false

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        // Second pass: all sheets have had time to dismiss, allow termination.
        if terminationRequested {
            return .terminateNow
        }
        terminationRequested = true

        // Tell SwiftUI views to dismiss their sheets through their own bindings.
        // This is more reliable than AppKit's window.attachedSheet, which doesn't
        // always reflect SwiftUI-managed sheets on macOS 13+.
        NotificationCenter.default.post(name: .velaWillTerminate, object: nil)

        // Also force-close any currently attached AppKit sheets.
        for window in NSApp.windows {
            if let sheet = window.attachedSheet {
                window.endSheet(sheet)
            }
        }

        // Use .terminateLater so Sparkle (and other callers) know we will
        // confirm termination rather than treating this as a cancellation.
        // Reply once sheets are actually gone (or after a short timeout).
        waitForSheetDismissalAndReply()
        return .terminateLater
    }

    private func waitForSheetDismissalAndReply(attempt: Int = 0) {
        let hasAttachedSheets = NSApp.windows.contains { $0.attachedSheet != nil }
        if !hasAttachedSheets || attempt >= 20 {
            NSApp.reply(toApplicationShouldTerminate: true)
            return
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.waitForSheetDismissalAndReply(attempt: attempt + 1)
        }
    }
}

@main
struct VelaIPTVApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            RootView()
                .frame(minWidth: 850, minHeight: 550)
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentMinSize)
        .defaultSize(width: 1100, height: 700)
        .commands {
            CommandGroup(replacing: .newItem) {}
            CommandGroup(after: .appInfo) {
                Button("Check for Updates…") {
                    UpdaterViewModel.shared.checkForUpdates()
                }
            }
        }
    }
}
