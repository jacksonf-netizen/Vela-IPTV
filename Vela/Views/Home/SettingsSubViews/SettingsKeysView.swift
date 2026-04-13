import SwiftUI

struct SettingsKeysView: View {
    @ObservedObject private var persistence = PersistenceService.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            SettingsGroup(title: "Keyboard Shortcuts") {
                VStack(spacing: 0) {
                    SettingsRow(title: "↑ / ↓  Arrow Keys", subtitle: "Action for Up or Down arrows.") {
                        Picker("", selection: $persistence.settings.upDownAction) {
                            ForEach(KeyAction.allCases) { action in
                                Text(action.rawValue).tag(action)
                            }
                        }
                        .pickerStyle(.menu)
                        .frame(width: 200)
                    }
                    
                    Divider().background(Color.white.opacity(0.06))
                    
                    SettingsRow(title: "← / →  Arrow Keys", subtitle: "Action for Left or Right arrows.") {
                        Picker("", selection: $persistence.settings.leftRightAction) {
                            ForEach(KeyAction.allCases) { action in
                                Text(action.rawValue).tag(action)
                            }
                        }
                        .pickerStyle(.menu)
                        .frame(width: 200)
                    }
                    
                    Divider().background(Color.white.opacity(0.06))
                    
                    SettingsRow(title: "⏎  Return / Enter", subtitle: "Action for return key.") {
                        Picker("", selection: $persistence.settings.enterAction) {
                            ForEach(KeyAction.allCases) { action in
                                Text(action.rawValue).tag(action)
                            }
                        }
                        .pickerStyle(.menu)
                        .frame(width: 200)
                    }
                }
            }
            
            SettingsGroup(title: "Reference") {
                VStack(alignment: .leading, spacing: 10) {
                    keyRow(key: "Space", description: "Play / Pause")
                    keyRow(key: "⌘F", description: "Toggle Fullscreen")
                    keyRow(key: "Escape", description: "Exit Player / Go Back")
                    keyRow(key: "⌘,", description: "Open Settings")
                    keyRow(key: "F", description: "Toggle Favorite")
                    keyRow(key: "G", description: "Toggle TV Guide")
                }
                .padding(.vertical, 4)
            }
        }
    }
    
    private func keyRow(key: String, description: String) -> some View {
        HStack {
            Text(key)
                .font(.system(size: 13, weight: .bold, design: .monospaced))
                .foregroundColor(Color.appAccent)
                .frame(width: 60, alignment: .leading)
            Text(description)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(Color.appTextPrimary)
            Spacer()
        }
    }
}
