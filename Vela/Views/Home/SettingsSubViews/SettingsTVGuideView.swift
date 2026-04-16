import SwiftUI

struct SettingsTVGuideView: View {
    @ObservedObject var channelVM: ChannelViewModel
    @ObservedObject private var persistence = PersistenceService.shared
    @ObservedObject private var epgVM = EPGViewModel.shared
    @State private var showRefreshConfirmation = false
    @State private var showPlaylistRefreshConfirmation = false
    @State private var isFetchingPlaylist = false
    
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
                        } label: {
                            HStack(spacing: 8) {
                                if epgVM.isFetching {
                                    VelaIPTVSpinner(size: 14, lineWidth: 2)
                                    Text("Updating Guide...")
                                } else {
                                    Image(systemName: showRefreshConfirmation ? "checkmark.circle.fill" : "arrow.clockwise")
                                    Text(showRefreshConfirmation ? "Cleared!" : "Clear & Update")
                                }
                            }
                            .frame(minWidth: 120)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .tint(showRefreshConfirmation ? .green : (epgVM.isFetching ? .gray : Color.appAccent))
                        .disabled(epgVM.isFetching)
                        .animation(.easeInOut, value: showRefreshConfirmation || epgVM.isFetching)
                        .onChange(of: epgVM.isFetching) { oldVal, newVal in
                            if oldVal == true && newVal == false {
                                // Just finished fetching
                                withAnimation { showRefreshConfirmation = true }
                                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                                    withAnimation { showRefreshConfirmation = false }
                                }
                            }
                        }
                    }
                    
                    Divider().background(Color.white.opacity(0.06))
                    
                    SettingsRow(title: "Force Update Playlist", subtitle: "Refresh categories and channels from your provider.") {
                        Button {
                            Task {
                                isFetchingPlaylist = true
                                if let pid = persistence.activeProviderId {
                                    // Refresh categories and Live stream lists
                                    await channelVM.loadCategories(for: pid)
                                    if let selected = channelVM.selectedCategory {
                                        await channelVM.selectCategory(selected, providerId: pid)
                                    }
                                }
                                isFetchingPlaylist = false
                            }
                        } label: {
                            HStack(spacing: 8) {
                                if isFetchingPlaylist {
                                    VelaIPTVSpinner(size: 14, lineWidth: 2)
                                    Text("Updating Playlist...")
                                } else {
                                    Image(systemName: showPlaylistRefreshConfirmation ? "checkmark.circle.fill" : "arrow.clockwise")
                                    Text(showPlaylistRefreshConfirmation ? "Updated!" : "Update Playlist")
                                }
                            }
                            .frame(minWidth: 120)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .tint(showPlaylistRefreshConfirmation ? .green : (isFetchingPlaylist ? .gray : Color.appAccent))
                        .disabled(isFetchingPlaylist)
                        .animation(.easeInOut, value: showPlaylistRefreshConfirmation || isFetchingPlaylist)
                        .onChange(of: isFetchingPlaylist) { oldVal, newVal in
                            if oldVal == true && newVal == false {
                                // Just finished fetching
                                withAnimation { showPlaylistRefreshConfirmation = true }
                                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                                    withAnimation { showPlaylistRefreshConfirmation = false }
                                }
                            }
                        }
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
