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

        // Give SwiftUI's dismiss animation a moment to complete, then re-trigger.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            sender.terminate(nil)
        }
        return .terminateCancel
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
        }
    }
}
