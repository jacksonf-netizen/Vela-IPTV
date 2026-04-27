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

        }
    }
}
