import SwiftUI

// Static formatter — avoids recreating on every render pass
private let epgTimeFormatter: DateFormatter = {
    let f = DateFormatter()
    f.timeStyle = .short
    return f
}()

private let epgRefreshFormatter: DateFormatter = {
    let f = DateFormatter()
    f.dateStyle = .none
    f.timeStyle = .medium
    return f
}()

struct EPGGridView: View {
    let channels: [Channel]
    @Binding var searchQuery: String
    let isLoading: Bool
    let sectionTitle: String
    let onSelect: (Channel) -> Void
    
    @StateObject private var epgVM = EPGViewModel()
    @ObservedObject private var persistence = PersistenceService.shared
    
    // Layout reads from user settings
    private var hourWidth: CGFloat { CGFloat(persistence.settings.timelineHourScale) }
    private let rowHeight: CGFloat = 70
    private let channelColumnWidth: CGFloat = 200
    private let timelineDurationHours: TimeInterval = 6
    
    @State private var currentTimeLine: Date = Date()
    private let timer = Timer.publish(every: 60, on: .main, in: .common).autoconnect()
    
    private var timelineStart: Date {
        let components = Calendar.current.dateComponents([.year, .month, .day, .hour], from: currentTimeLine)
        return Calendar.current.date(from: components) ?? currentTimeLine
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // MARK: – EPG Toolbar
            epgToolbar
            
            if isLoading {
                Spacer()
                VelaSpinner(size: 40, lineWidth: 3)
                Spacer()
            } else if channels.isEmpty {
                Spacer()
                Text("No channels available.")
                    .foregroundColor(Color.appTextSecondary)
                Spacer()
            } else {
                epgGrid
            }
        }
        .background(Color.appBackground)
        .onAppear {
            fetchVisibleEPG()
        }
        .onChange(of: channels) { _, _ in
            fetchVisibleEPG()
        }
        .onReceive(timer) { time in
            currentTimeLine = time
        }
        .onReceive(NotificationCenter.default.publisher(for: .velaForceEPGRefresh)) { _ in
            guard let creds = persistence.activeProvider?.credentials else { return }
            epgVM.clearAndRefresh(for: Array(channels.prefix(200)), credentials: creds)
        }
        .onDisappear {
            epgVM.cancel()
        }
    }
    
    // MARK: – Toolbar with Refresh
    
    private var epgToolbar: some View {
        HStack(spacing: 12) {
            // Loading indicator
            if epgVM.isFetching {
                HStack(spacing: 8) {
                    VelaSpinner(size: 14, lineWidth: 2)
                    Text("Loading EPG…")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(Color.appTextSecondary)
                }
            } else if let lastRefresh = epgVM.lastRefreshed {
                Text("Updated \(epgRefreshFormatter.string(from: lastRefresh))")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(Color.appTextSecondary)
            }

            Spacer()
            
            // Manual Refresh
            Button {
                guard let creds = persistence.activeProvider?.credentials else { return }
                epgVM.clearAndRefresh(for: Array(channels.prefix(200)), credentials: creds)
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 12, weight: .bold))
                    Text("Refresh EPG")
                        .font(.system(size: 12, weight: .semibold))
                }
                .foregroundColor(Color.appAccent)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color.appAccent.opacity(0.12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .stroke(Color.appAccent.opacity(0.2), lineWidth: 1)
                        )
                )
            }
            .buttonStyle(.plain)
            .disabled(epgVM.isFetching)
            .opacity(epgVM.isFetching ? 0.5 : 1.0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color.appBackground.opacity(0.6))
    }
    
    // MARK: – Grid
    
    private var epgGrid: some View {
        ScrollView([.horizontal, .vertical], showsIndicators: true) {
            VStack(alignment: .leading, spacing: 0) {
                // Time Header Row
                HStack(spacing: 0) {
                    Color.appBackground
                        .frame(width: channelColumnWidth, height: 40)
                    
                    timeHeaders
                }
                .background(Color.appBackground.opacity(0.95))
                
                // Channels and EPG Rows
                LazyVStack(spacing: 0) {
                    ForEach(channels) { channel in
                        HStack(spacing: 0) {
                            channelCell(for: channel)
                                .frame(width: channelColumnWidth, height: rowHeight)
                                .background(Color.appBackground)
                            
                            epgRow(for: channel)
                                .frame(width: hourWidth * CGFloat(timelineDurationHours), height: rowHeight)
                        }
                    }
                }
            }
        }
    }
    
    private var timeHeaders: some View {
        HStack(spacing: 0) {
            ForEach(0..<Int(timelineDurationHours), id: \.self) { hourOffset in
                let time = timelineStart.addingTimeInterval(TimeInterval(hourOffset * 3600))
                Text(epgTimeFormatter.string(from: time))
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(Color.appTextSecondary)
                    .frame(width: hourWidth, alignment: .leading)
                    .padding(.leading, 8)
            }
        }
        .frame(height: 40)
    }
    
    private func channelCell(for channel: Channel) -> some View {
        Button {
            onSelect(channel)
        } label: {
            HStack(spacing: 12) {
                if persistence.settings.showLogos,
                   let icon = channel.streamIcon, let url = URL(string: icon) {
                    AsyncImage(url: url) { phase in
                        if let image = phase.image {
                            image.resizable().aspectRatio(contentMode: .fit)
                        } else {
                            Image(systemName: "tv").foregroundColor(Color.appTextSecondary)
                        }
                    }
                    .frame(width: 40, height: 40)
                    .cornerRadius(4)
                } else if !persistence.settings.showLogos {
                    // No logos mode — just a compact indicator
                    RoundedRectangle(cornerRadius: 4).fill(Color.white.opacity(0.06))
                        .frame(width: 6, height: 40)
                } else {
                    RoundedRectangle(cornerRadius: 4).fill(Color.white.opacity(0.1))
                        .frame(width: 40, height: 40)
                        .overlay(Image(systemName: "tv").foregroundColor(Color.appTextSecondary))
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    if let num = channel.num {
                        Text("\(num)").font(.system(size: 10, weight: .bold)).foregroundColor(Color.appAccent)
                    }
                    Text(channel.name)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white)
                        .lineLimit(2)
                }
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
            .background(Color.white.opacity(0.02))
        }
        .buttonStyle(.plain)
        .overlay(Rectangle().frame(width: 1, alignment: .trailing).foregroundColor(Color.white.opacity(0.1)), alignment: .trailing)
        .overlay(Rectangle().frame(height: 1, alignment: .bottom).foregroundColor(Color.white.opacity(0.1)), alignment: .bottom)
    }
    
    private func epgRow(for channel: Channel) -> some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                // Background grid lines
                HStack(spacing: 0) {
                    ForEach(0..<Int(timelineDurationHours), id: \.self) { _ in
                        Rectangle()
                            .fill(Color.white.opacity(0.05))
                            .frame(width: 1)
                        Spacer()
                    }
                }
                
                // Programs
                if let entries = epgVM.epgDict[channel.streamId] {
                    ForEach(entries) { entry in
                        programBlock(for: entry, channel: channel)
                    }
                } else {
                    // Shimmer placeholder while loading
                    if epgVM.isFetching {
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(Color.white.opacity(0.03))
                            .padding(.vertical, 8)
                            .padding(.horizontal, 4)
                    }
                }
                
                // Current Time Line
                let secondsFromStart = currentTimeLine.timeIntervalSince(timelineStart)
                if secondsFromStart > 0 && secondsFromStart < (timelineDurationHours * 3600) {
                    let offset = (secondsFromStart / 3600.0) * Double(hourWidth)
                    Rectangle()
                        .fill(Color.appAccent)
                        .frame(width: 2)
                        .offset(x: offset)
                        .zIndex(10)
                }
            }
        }
        .background(Color.appBackground.opacity(0.5))
        .overlay(Rectangle().frame(height: 1, alignment: .bottom).foregroundColor(Color.white.opacity(0.1)), alignment: .bottom)
        .clipped()
    }
    
    private func programBlock(for entry: EPGEntry, channel: Channel) -> some View {
        guard let startDouble = Double(entry.startTimestamp ?? ""),
              let stopDouble = Double(entry.stopTimestamp ?? "") else { return AnyView(EmptyView()) }
        
        let programStart = Date(timeIntervalSince1970: startDouble)
        let programEnd = Date(timeIntervalSince1970: stopDouble)
        
        let startOffset = max(0, programStart.timeIntervalSince(timelineStart))
        let endOffset = min(timelineDurationHours * 3600, programEnd.timeIntervalSince(timelineStart))
        
        guard programEnd > timelineStart && programStart < timelineStart.addingTimeInterval(timelineDurationHours * 3600) else {
            return AnyView(EmptyView())
        }
        guard endOffset > startOffset else { return AnyView(EmptyView()) }
        
        let pxStart = (startOffset / 3600.0) * Double(hourWidth)
        let pxWidth = ((endOffset - startOffset) / 3600.0) * Double(hourWidth)
        
        let isLive = currentTimeLine >= programStart && currentTimeLine <= programEnd
        
        return AnyView(
            Button {
                onSelect(channel)
            } label: {
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(isLive ? Color.appAccent.opacity(0.25) : Color.white.opacity(0.08))
                        .overlay(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .stroke(isLive ? Color.appAccent.opacity(0.5) : Color.white.opacity(0.05), lineWidth: 1)
                        )
                    
                    VStack(alignment: .leading, spacing: 3) {
                        Text(entry.title)
                            .font(.system(size: 13, weight: isLive ? .bold : .medium))
                            .foregroundColor(isLive ? .white : Color.appTextPrimary)
                            .lineLimit(1)
                        
                        if let desc = entry.description, !desc.isEmpty {
                            Text(desc)
                                .font(.system(size: 11))
                                .foregroundColor(Color.appTextSecondary)
                                .lineLimit(1)
                        }
                    }
                    .padding(.horizontal, 10)
                }
            }
            .buttonStyle(.plain)
            .padding(.vertical, 4)
            .padding(.horizontal, 2)
            .frame(width: pxWidth, height: rowHeight)
            .offset(x: pxStart)
        )
    }
    
    private func fetchVisibleEPG() {
        guard let provider = persistence.activeProvider else { return }
        epgVM.fetchEPG(for: Array(channels.prefix(500)), credentials: provider.credentials)
    }
}
