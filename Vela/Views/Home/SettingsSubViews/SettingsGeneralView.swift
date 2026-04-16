import SwiftUI

struct SettingsGeneralView: View {
    @ObservedObject private var persistence = PersistenceService.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            SettingsGroup(title: "App Startup") {
                VStack(spacing: 0) {
                    SettingsRow(title: "Startup Screen", subtitle: "What you see when the app opens in Live TV mode.") {
                        Picker("", selection: $persistence.settings.startupScreen) {
                            ForEach(StartupScreen.allCases) { screen in
                                Text(screen.rawValue).tag(screen)
                            }
                        }
                        .pickerStyle(.menu)
                        .frame(width: 180)
                    }

                    Divider().opacity(0.1).padding(.horizontal, 16)

                    SettingsRow(title: "Default Tab", subtitle: "Which tab opens when the app launches.") {
                        Picker("", selection: $persistence.settings.defaultTab) {
                            ForEach(DefaultTab.allCases) { tab in
                                Text(tab.rawValue).tag(tab)
                            }
                        }
                        .pickerStyle(.menu)
                        .frame(width: 180)
                    }
                    .opacity(persistence.settings.showVOD ? 1.0 : 0.4)
                    .disabled(!persistence.settings.showVOD)
                }
            }

            SettingsGroup(title: "Content") {
                VStack(spacing: 0) {
                    SettingsRow(title: "Show Movies (VOD)", subtitle: "Enable the Movies tab for Video on Demand content.") {
                        Toggle("", isOn: $persistence.settings.showVOD)
                            .toggleStyle(.switch)
                    }
                }
            }

            SettingsGroup(title: "Maintenance") {
                VStack(spacing: 0) {
                    SettingsRow(title: "Software Update", subtitle: "Check for newer versions of Vela IPTV.") {
                        Button {
                            UpdaterViewModel.shared.checkForUpdates()
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
