import SwiftUI
import AppKit

class AppDelegate: NSObject, NSApplicationDelegate {
    private var terminationRequested = false
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }
    
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        // If we already handled sheets on a previous pass, allow termination immediately
        if terminationRequested {
            return .terminateNow
        }
        
        // Force-dismiss any open sheets (e.g. Settings) so Sparkle's quit event isn't blocked
        var hadSheet = false
        for window in sender.windows {
            if let sheet = window.attachedSheet {
                window.endSheet(sheet)
                hadSheet = true
            }
        }
        
        if hadSheet {
            terminationRequested = true
            // Give the sheet animation a moment to finish, then re-send terminate
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                sender.terminate(nil)
            }
            return .terminateCancel  // Cancel THIS attempt; the re-sent one will succeed
        }
        
        return .terminateNow
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
