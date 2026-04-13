import SwiftUI

struct SettingsPlaybackView: View {
    @ObservedObject private var persistence = PersistenceService.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            SettingsGroup(title: "Playback Performance") {
                VStack(spacing: 0) {
                    SettingsRow(title: "Buffer Profile", subtitle: "Optimize stream loading for your net speed.") {
                        Picker("", selection: Binding(
                            get: { persistence.bufferProfile },
                            set: { persistence.setBufferProfile($0) }
                        )) {
                            ForEach(BufferProfile.allCases, id: \.self) { profile in
                                Text(profile.rawValue).tag(profile)
                            }
                        }
                        .pickerStyle(.menu)
                        .frame(width: 140)
                    }
                    
                    Text(persistence.bufferProfile.description)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(Color.appAccent)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.leading, 4)
                        .padding(.vertical, 4)

                    Divider().background(Color.white.opacity(0.06))

                    SettingsRow(title: "Initial Delay", subtitle: "Time spent buffering before video starts.") {
                        HStack(spacing: 12) {
                            Slider(value: Binding(
                                get: { persistence.startupBufferDelay },
                                set: { persistence.setStartupBufferDelay($0) }
                            ), in: 0...10, step: 1)
                            .frame(width: 140)
                            .tint(Color.appAccent)
                            
                            Text("\(Int(persistence.startupBufferDelay))s")
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                                .frame(width: 30, alignment: .trailing)
                        }
                    }
                }
            }

            SettingsGroup(title: "Network Protocol") {
                SettingsRow(title: "Preferred Format", subtitle: "HLS is adaptive; TS is faster for live content.") {
                    Picker("", selection: Binding(
                        get: { persistence.preferredStreamFormat },
                        set: { persistence.setStreamFormat($0) }
                    )) {
                        ForEach(StreamFormat.allCases, id: \.self) { format in
                            Text(format.rawValue).tag(format)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(width: 140)
                }
            }
            
            SettingsGroup(title: "Advanced") {
                VStack(spacing: 0) {
                    SettingsRow(title: "Hardware Decoding", subtitle: "Use VideoToolbox for GPU-accelerated playback.") {
                        Toggle("", isOn: $persistence.settings.hardwareDecoding)
                            .toggleStyle(.switch)
                    }
                    
                    Divider().background(Color.white.opacity(0.06))
                    
                    SettingsRow(title: "Auto Frame Rate", subtitle: "Match display refresh rate to stream content.") {
                        Toggle("", isOn: $persistence.settings.autoFrameRate)
                            .toggleStyle(.switch)
                    }
                    
                    Divider().background(Color.white.opacity(0.06))
                    
                    SettingsRow(title: "Default Channel Click", subtitle: "Action when selecting a channel.") {
                        Picker("", selection: $persistence.settings.defaultClickAction) {
                            ForEach(ClickAction.allCases) { action in
                                Text(action.rawValue).tag(action)
                            }
                        }
                        .pickerStyle(.menu)
                        .frame(width: 160)
                    }
                }
            }
        }
    }
}
