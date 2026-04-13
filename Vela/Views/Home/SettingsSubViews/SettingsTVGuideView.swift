import SwiftUI

struct SettingsTVGuideView: View {
    @ObservedObject private var persistence = PersistenceService.shared
    @State private var showRefreshConfirmation = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            SettingsGroup(title: "Update Frequency") {
                VStack(spacing: 0) {
                    SettingsRow(title: "EPG Update Interval", subtitle: "How often the TV guide should refresh in the background.") {
                        Picker("", selection: $persistence.settings.epgUpdateInterval) {
                            ForEach(UpdateInterval.allCases) { interval in
                                Text(interval.rawValue).tag(interval)
                            }
                        }
                        .pickerStyle(.menu)
                        .frame(width: 160)
                    }
                    
                    Divider().background(Color.white.opacity(0.06))
                    
                    SettingsRow(title: "Force Update EPG", subtitle: "Clear all cached schedule data and start fresh.") {
                        Button {
                            NotificationCenter.default.post(name: .velaForceEPGRefresh, object: nil)
                            showRefreshConfirmation = true
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                showRefreshConfirmation = false
                            }
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: showRefreshConfirmation ? "checkmark.circle.fill" : "arrow.clockwise")
                                Text(showRefreshConfirmation ? "Cleared!" : "Clear & Update")
                            }
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .tint(showRefreshConfirmation ? .green : Color.appAccent)
                        .animation(.easeInOut, value: showRefreshConfirmation)
                    }
                }
            }
            
            SettingsGroup(title: "Timeline Interface") {
                VStack(spacing: 0) {
                    SettingsRow(title: "Past Programs (Days)", subtitle: "Number of days to keep history for Catch-up TV.") {
                        HStack(spacing: 12) {
                            Slider(value: Binding(
                                get: { Double(persistence.settings.epgHistoryDays) },
                                set: { persistence.settings.epgHistoryDays = Int($0) }
                            ), in: 0...7, step: 1)
                            .frame(width: 140)
                            .tint(Color.appAccent)
                            
                            Text("\(persistence.settings.epgHistoryDays) Days")
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                                .frame(width: 55, alignment: .trailing)
                        }
                    }
                    
                    Divider().background(Color.white.opacity(0.06))
                    
                    SettingsRow(title: "Timeline Zoom Scale", subtitle: "Adjust how wide a 1-hour block is on the guide grid.") {
                        HStack(spacing: 12) {
                            Slider(value: $persistence.settings.timelineHourScale, in: 100...600, step: 50)
                                .frame(width: 140)
                                .tint(Color.appAccent)
                            
                            Text("\(Int(persistence.settings.timelineHourScale))px")
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                                .frame(width: 55, alignment: .trailing)
                        }
                    }
                }
            }
        }
    }
}

// MARK: – Notification for cross-component EPG refresh
extension Notification.Name {
    static let velaForceEPGRefresh = Notification.Name("velaForceEPGRefresh")
}
