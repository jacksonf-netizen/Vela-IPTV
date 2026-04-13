import SwiftUI

struct SettingsGeneralView: View {
    @ObservedObject private var persistence = PersistenceService.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            SettingsGroup(title: "App Startup") {
                VStack(spacing: 0) {
                    SettingsRow(title: "Startup Screen", subtitle: "What you see when the app opens.") {
                        Picker("", selection: $persistence.settings.startupScreen) {
                            ForEach(StartupScreen.allCases) { screen in
                                Text(screen.rawValue).tag(screen)
                            }
                        }
                        .pickerStyle(.menu)
                        .frame(width: 180)
                    }
                    
                }
            }
            
            SettingsGroup(title: "Maintenance") {
                VStack(spacing: 0) {
                    SettingsRow(title: "Software Update", subtitle: "Check for newer versions of Vela IPTV.") {
                        Button {
                            UpdaterViewModel().checkForUpdates()
                        } label: {
                            Text("Check for Updates...")
                                .font(.system(size: 12, weight: .semibold))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.white.opacity(0.1))
                                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                                .overlay(RoundedRectangle(cornerRadius: 6, style: .continuous).stroke(Color.white.opacity(0.1), lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
}
