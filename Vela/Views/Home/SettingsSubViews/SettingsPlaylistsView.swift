import SwiftUI

struct SettingsPlaylistsView: View {
    @ObservedObject private var persistence = PersistenceService.shared
    @ObservedObject var authVM: AuthViewModel
    
    @State private var selectedProviderId: UUID?
    
    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            // MARK: – Provider Sidebar
            VStack(alignment: .leading, spacing: 8) {
                Text("ACCOUNTS")
                    .font(.system(size: 10, weight: .black))
                    .foregroundColor(Color.appTextSecondary)
                    .tracking(1.0)
                    .padding(.horizontal, 12)
                    .padding(.bottom, 4)

                ForEach(persistence.providers) { provider in
                    Button {
                        selectedProviderId = provider.id
                    } label: {
                        HStack(spacing: 10) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(selectedProviderId == provider.id ? Color.appAccent : Color.white.opacity(0.1))
                                    .frame(width: 26, height: 26)
                                
                                Image(systemName: "antenna.radiowaves.left.and.right")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(selectedProviderId == provider.id ? .white : Color.appTextSecondary)
                            }
                            
                            Text(provider.name)
                                .font(.system(size: 13, weight: selectedProviderId == provider.id ? .bold : .medium))
                                .foregroundColor(selectedProviderId == provider.id ? .white : Color.appTextPrimary)
                                .lineLimit(1)
                            
                            Spacer()
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(selectedProviderId == provider.id ? Color.white.opacity(0.08) : Color.clear)
                        )
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 4)
                }

                Button {
                    authVM.isShowingAddProvider = true
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "plus.circle.fill")
                        Text("Add Provider")
                    }
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(Color.appAccent)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                }
                .buttonStyle(.plain)

                Spacer()
            }
            .frame(width: 180)
            
            Divider()
                .background(Color.white.opacity(0.08))
                .padding(.vertical, 8)

            // MARK: – Provider Detail
            if let providerId = selectedProviderId,
               let provider = persistence.providers.first(where: { $0.id == providerId }) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        SettingsGroup(title: "Account Management") {
                            VStack(spacing: 0) {
                                infoRow(label: "Username", value: provider.credentials.username)
                                Divider().background(Color.white.opacity(0.06))
                                infoRow(label: "Server", value: provider.serverURL)
                                
                                Divider().background(Color.white.opacity(0.06))
                                
                                SettingsRow(title: "Auto-Update Playlist", subtitle: "Keep your channel list fresh.") {
                                    Picker("", selection: $persistence.settings.autoUpdatePlaylists) {
                                        ForEach(UpdateInterval.allCases) { interval in
                                            Text(interval.rawValue).tag(interval)
                                        }
                                    }
                                    .pickerStyle(.menu)
                                    .frame(width: 160)
                                }
                            }
                        }

                        Button {
                            authVM.removeProvider(provider)
                            selectedProviderId = persistence.providers.first?.id
                            if persistence.providers.isEmpty {
                                persistence.logout()
                            }
                        } label: {
                            Text("Remove Provider")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.red)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(Color.red.opacity(0.08))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .stroke(Color.red.opacity(0.2), lineWidth: 1)
                                )
                                .cornerRadius(8)
                        }
                        .buttonStyle(.plain)
                        .padding(.top, 8)
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 4)
                    .padding(.bottom, 20)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            } else {
                VStack {
                    Spacer()
                    Image(systemName: "antenna.radiowaves.left.and.right.slash")
                        .font(.system(size: 28))
                        .foregroundColor(Color.white.opacity(0.08))
                        .padding(.bottom, 6)
                    Text("Select a provider")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(Color.appTextSecondary)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            }
        }
        .onAppear {
            if selectedProviderId == nil {
                selectedProviderId = persistence.providers.first?.id
            }
        }
    }
    
    private func infoRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.white)
            Spacer()
            Text(value)
                .font(.system(size: 13, weight: .regular))
                .foregroundColor(Color.appTextSecondary)
                .lineLimit(1)
        }
        .padding(.vertical, 8)
    }
}
