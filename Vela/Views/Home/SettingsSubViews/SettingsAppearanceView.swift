import SwiftUI

struct SettingsAppearanceView: View {
    @ObservedObject private var persistence = PersistenceService.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            SettingsGroup(title: "Theme") {
                SettingsRow(title: "App Theme", subtitle: "Switch between Light, Dark, or System appearances.") {
                    Picker("", selection: $persistence.settings.themeMode) {
                        ForEach(ThemeMode.allCases) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(width: 120)
                }
            }
            
            SettingsGroup(title: "Interface") {
                VStack(spacing: 0) {
                    SettingsRow(title: "Global Font Size", subtitle: "Affects TV Guide and Channel Lists.") {
                        Picker("", selection: $persistence.settings.fontSize) {
                            ForEach(FontSizeScale.allCases) { scale in
                                Text(scale.rawValue).tag(scale)
                            }
                        }
                        .pickerStyle(.menu)
                        .frame(width: 140)
                    }
                    
                    Divider().background(Color.white.opacity(0.06))
                    
                    SettingsRow(title: "Show Channel Logos", subtitle: "If disabled, falls back to text names to save space.") {
                        Toggle("", isOn: $persistence.settings.showLogos)
                            .toggleStyle(.switch)
                    }
                }
            }
            
        }
    }
}
