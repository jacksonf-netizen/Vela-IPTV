import SwiftUI
import Network
import Combine
import VLCKit

struct PlayerView: View {
    let channels: [Channel]
    @ObservedObject var authVM: AuthViewModel
    let categories: [StreamCategory]
    @Binding var isPresented: Bool

    @State private var currentChannel: Channel
    @StateObject private var vm = PlayerViewModel()
    @ObservedObject private var persistence = PersistenceService.shared
    @State private var showControls = true
    @State private var isFavorite = false
    @State private var currentEPG: EPGEntry? = nil
    @State private var controlsTimer: Timer? = nil

    init(initialChannel: Channel, channels: [Channel], authVM: AuthViewModel, categories: [StreamCategory], isPresented: Binding<Bool>) {
        self.channels = channels
        self.authVM = authVM
        self.categories = categories
        self._isPresented = isPresented
        self._currentChannel = State(initialValue: initialChannel)
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            switch vm.state {
            case .loading:
                VStack(spacing: 20) {
                    VelaIPTVSpinner()
                        .frame(width: 40, height: 40)
                    Text("Connecting to stream…")
                        .foregroundColor(Color(hex: "8E8EA0"))
                        .font(.system(size: 14, weight: .medium))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            case .playing(let mediaPlayer):
                ZStack {
                    // Wrap player in GeometryReader to prevent its intrinsic video size from pushing bounds outwards
                    GeometryReader { proxy in
                        VLCPlayerView(player: mediaPlayer)
                            .frame(width: proxy.size.width, height: proxy.size.height)
                    }
                    .ignoresSafeArea()
                    
                    // transparent layer to catch hover and clicks over the AVPlayerView reliably
                    Color.white.opacity(0.001)
                        .ignoresSafeArea()
                        .onHover { if $0 { startControlsTimer() } }
                        .onTapGesture { toggleControls() }
                    
                    if vm.isBuffering {
                        VStack(spacing: 0) {
                            VelaIPTVSpinner(size: 32, lineWidth: 3)
                        }
                        .padding(24)
                        .background(VisualEffectView(material: .hudWindow, blendingMode: .withinWindow).cornerRadius(12))
                    }

                }

            case .error(let msg):
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 40))
                        .foregroundColor(Color(hex: "FF9F0A"))
                    Text("Stream unavailable")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                    Text(msg)
                        .font(.system(size: 13))
                        .foregroundColor(Color(hex: "8E8EA0"))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                    Button("Close") { isPresented = false }
                        .buttonStyle(.plain)
                        .foregroundColor(Color(hex: "6C3DE8"))
                        .font(.system(size: 14, weight: .semibold))
                        .padding(.top, 8)
                }
            }

            // Overlay
            if showControls || vm.state == .loading {
                Group {
                    if case .playing(let player) = vm.state {
                        PlayerOverlayView(
                            channel: currentChannel,
                            epgEntry: currentEPG,
                            mediaPlayer: player,
                            streamStats: vm.streamStats,
                            isFavorite: $isFavorite,
                            isPresented: $isPresented,
                            authVM: authVM,
                            categories: categories,
                            onFavoriteToggle: {
                                persistence.toggleFavorite(currentChannel)
                                isFavorite = persistence.isFavorite(currentChannel)
                            },
                            onNext: { changeChannel(offset: 1) },
                            onPrev: { changeChannel(offset: -1) }
                        )
                    } else {
                        PlayerOverlayView(
                            channel: currentChannel,
                            epgEntry: currentEPG,
                            mediaPlayer: nil,
                            streamStats: nil,
                            isFavorite: $isFavorite,
                            isPresented: $isPresented,
                            authVM: authVM,
                            categories: categories,
                            onFavoriteToggle: {
                                persistence.toggleFavorite(currentChannel)
                                isFavorite = persistence.isFavorite(currentChannel)
                            },
                            onNext: { changeChannel(offset: 1) },
                            onPrev: { changeChannel(offset: -1) }
                        )
                    }
                }
                .transition(.opacity)
            }
        }
        .onAppear {
            isFavorite = persistence.isFavorite(currentChannel)
            persistence.addRecent(currentChannel)
            let provider = persistence.providers.first { $0.id == currentChannel.providerId } ?? persistence.activeProvider
            guard let creds = provider?.credentials else {
                vm.state = .error("No provider configured. Please add a provider in Settings.")
                return
            }
            vm.load(url: creds.streamURL(for: currentChannel), channel: currentChannel)
            startControlsTimer()
            Task {
                currentEPG = try? await XtreamCodesService.shared.getEPG(credentials: creds, streamId: currentChannel.streamId).first
            }
        }
        .onChange(of: currentChannel) { _, newChannel in
            vm.stop()
            isFavorite = persistence.isFavorite(newChannel)
            persistence.addRecent(newChannel)
            let provider = persistence.providers.first { $0.id == newChannel.providerId } ?? persistence.activeProvider
            guard let creds = provider?.credentials else {
                vm.state = .error("No provider configured. Please add a provider in Settings.")
                return
            }
            vm.load(url: creds.streamURL(for: newChannel), channel: newChannel)
            Task { currentEPG = try? await XtreamCodesService.shared.getEPG(credentials: creds, streamId: newChannel.streamId).first }
        }
        .onDisappear { vm.stop() }
        .onHover { if $0 { startControlsTimer() } }
        .onExitCommand { isPresented = false } // Close on ESC
        .animation(.easeInOut(duration: 0.2), value: showControls)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.ignoresSafeArea())
    }

    private func toggleControls() {
        withAnimation { showControls.toggle() }
        if showControls { startControlsTimer() }
    }
    
    private func changeChannel(offset: Int) {
        if channels.isEmpty { return }
        if let idx = channels.firstIndex(where: { $0.id == currentChannel.id }) {
            var newIdx = (idx + offset) % channels.count
            if newIdx < 0 { newIdx = channels.count - 1 }
            currentChannel = channels[newIdx]
            startControlsTimer()
        }
    }

    private func startControlsTimer() {
        withAnimation { showControls = true }
        controlsTimer?.invalidate()
        controlsTimer = Timer.scheduledTimer(withTimeInterval: 4.0, repeats: false) { _ in
            withAnimation { self.showControls = false }
        }
    }
}

// MARK: - Player ViewModel

enum PlayerState: Equatable {
    case loading
    case playing(VLCMediaPlayer)
    case error(String)

    static func == (lhs: PlayerState, rhs: PlayerState) -> Bool {
        switch (lhs, rhs) {
        case (.loading, .loading): return true
        case (.error(let a), .error(let b)): return a == b
        case (.playing, .playing): return true
        default: return false
        }
    }
}

@MainActor
class PlayerViewModel: NSObject, ObservableObject, @preconcurrency VLCMediaPlayerDelegate {
    @Published var state: PlayerState = .loading
    @Published var isBuffering: Bool = false
    @Published var streamStats: String? = nil
    
    // PHASE 39/40: Track current channel for architectural reloads & VLC recovery
    private var currentChannel: Channel?
    private var currentURL: URL?
    private var cancellables = Set<AnyCancellable>()
    
    // PHASE 40: VLC-only recovery state
    private var retryCount: Int = 0
    private let maxRetries: Int = 5
    
    // PHASE 33: Grace Period Logic
    private var sessionStartTime: Date = Date()
    
    private var mediaPlayer: VLCMediaPlayer?
    private var stallMonitorTask: Task<Void, Never>?
    
    // Buffering debounce - only show spinner after sustained buffering
    private var bufferingTask: Task<Void, Never>?
    private var hasStartedPlaying: Bool = false
    private var forceDismissTask: Task<Void, Never>?
    
    override init() {
        super.init()
        // PHASE 39: Observe format changes to trigger instant architectural shifts
        PersistenceService.shared.$preferredStreamFormat
            .dropFirst()
            .removeDuplicates()
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                guard let self = self, let channel = self.currentChannel else { return }
                // Re-build URL with new format and reload
                let provider = PersistenceService.shared.providers.first { $0.id == channel.providerId } ?? PersistenceService.shared.activeProvider
                if let creds = provider?.credentials {
                    let newURL = creds.streamURL(for: channel)
                    #if DEBUG
                    print("[Phase 39] Format changed - Reloading with new architecture...")
                    #endif
                    self.load(url: newURL, channel: channel)
                }
            }
            .store(in: &cancellables)
    }
       // Target state for recovery persistence
    private var targetMuted: Bool = false
    private var targetVolume: Float = 1.0
    
    // PHASE 15/16: Network path monitoring for stability awareness
    private let networkMonitor = NWPathMonitor()
    private let networkQueue = DispatchQueue(label: "com.vela.network-monitor", qos: .utility)
    private var currentPathQuality: NWPath.Status = .satisfied
    private var isExpensivePath: Bool = false
    private var isConstrainedPath: Bool = false

    func load(url: URL?, channel: Channel) {
        self.currentChannel = channel
        self.currentURL = url
        
        // PHASE 40: VLC-specific cleanup
        stop()
        
        // Reset playback state
        hasStartedPlaying = false
        
        // Start network monitoring (idempotent)
        // startNetworkMonitor() // Removed to simplify
        
        guard let url = url else {
            state = .error("Could not build stream URL.")
            return
        }
        
        state = .loading
        self.sessionStartTime = Date()
        self.retryCount = 0  // Reset retry count on new load
        
        // PHASE 40: VLC Performance Options (The Buffer-Buster)
        let options: [String] = [
            "--network-caching=3000",
            "--live-caching=1500",
            "--clock-jitter=0",
            "--clock-synchro=0",
            "--http-reconnect",
            "--http-continuous",
            "--skip-frames",
            "--videotoolbox",
            "--no-osd"
        ]
        
        let media = VLCMedia(url: url)
        // VLCKit expects options as a dictionary with empty string values
        let optionsDict = options.reduce(into: [String: String]()) { $0[$1] = "" }
        media.addOptions(optionsDict)

        let player = VLCMediaPlayer()
        player.media = media
        player.delegate = self
        
        // Sync target state
        player.audio?.isMuted = targetMuted
        player.audio?.volume = Int32(targetVolume * 100)
        
        self.mediaPlayer = player
        
        // Register for VLC notifications
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(mediaPlayerStateChanged(_:)),
            name: NSNotification.Name(rawValue: "VLCMediaPlayerStateChanged"),
            object: player
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(mediaPlayerTimeChanged(_:)),
            name: NSNotification.Name(rawValue: "VLCMediaPlayerTimeChanged"),
            object: player
        )
        
        DispatchQueue.main.async {
            player.play()
        }
        
        // PHASE 45: Aggressive State Recovery & Safety Timer
        forceDismissTask?.cancel()
        forceDismissTask = Task {
            // Check state frequently for the first 5 seconds
            for _ in 1...25 { // 5 seconds at 200ms intervals
                try? await Task.sleep(nanoseconds: 200_000_000)
                if Task.isCancelled { return }
                
                checkPlayerState()
                
                // If we've transitioned to playing, we can stop the aggressive polling
                if case .playing = self.state {
                    #if DEBUG
                    print("[Phase 45] Playback confirmed, stopping recovery polling.")
                    #endif
                    return
                }
            }
            
            // Final Safety Force-Dismiss: If after 5s we are still in .loading but player says isPlaying
            if case .loading = self.state, let player = self.mediaPlayer, player.isPlaying {
                #if DEBUG
                print("[Phase 45] SAFETY TRIGGER: Force-dismissing loading screen after 5s timeout.")
                #endif
                self.state = .playing(player)
                self.isBuffering = false
                self.hasStartedPlaying = true
            }
        }
    }
    
    @MainActor
    private func checkPlayerState() {
        guard let player = mediaPlayer else { return }
        
        // If we're still in loading state but player is playing, update
        if case .loading = state, player.isPlaying {
            #if DEBUG
            print("[Phase 44] Proactive state update - Player is playing")
            #endif
            state = .playing(player)
            isBuffering = false
            hasStartedPlaying = true
        }
    }
    
    @objc func mediaPlayerStateChanged(_ aNotification: Notification) {
        guard let player = mediaPlayer else { return }
        
        Task { @MainActor in
            #if DEBUG
            print("[Phase 44] VLC State Change: \(player.state.rawValue)")
            #endif
            
            switch player.state {
            case .playing:
                self.state = .playing(player)
                self.hasStartedPlaying = true
                // Immediately hide buffering and cancel any pending buffering tasks
                self.isBuffering = false
                self.bufferingTask?.cancel()
                self.bufferingTask = nil
                self.retryCount = 0
                #if DEBUG
                print("[Phase 44] ✅ Playing - Buffering cleared")
                #endif
                
            case .buffering:
                // Only show buffering if we've been playing for at least 2 seconds
                // This prevents the initial buffering flash
                if self.hasStartedPlaying, 
                   case .playing = self.state,
                   Date().timeIntervalSince(self.sessionStartTime) > 2.0 {
                    
                    guard self.bufferingTask == nil else { return }
                    
                    #if DEBUG
                    print("[Phase 44] 🔄 Buffering detected (debouncing...)")
                    #endif
                    self.bufferingTask = Task { @MainActor in
                        do {
                            // Wait 1.5 seconds before showing spinner
                            try await Task.sleep(nanoseconds: 1_500_000_000)
                            
                            // Triple-check: still buffering, not cancelled, and still playing state
                            if !Task.isCancelled, 
                               let currentPlayer = self.mediaPlayer, 
                               currentPlayer.state == .buffering,
                               case .playing = self.state {
                                self.isBuffering = true
                                #if DEBUG
                                print("[Phase 44] ⏳ Showing buffering spinner")
                                #endif
                            }
                        } catch {
                            // Task cancelled
                        }
                        self.bufferingTask = nil
                    }
                }
                
            case .paused, .stopped, .ended, .error:
                self.isBuffering = false
                self.bufferingTask?.cancel()
                self.bufferingTask = nil
                
                if player.state == .error || player.state == .ended {
                    self.reconnect()
                }
                
            case .opening, .esAdded:
                // Initial load or stream metadata arrival, keep current state
                #if DEBUG
                print("[Phase 44] Opening stream / ES added...")
                #endif
                
            default:
                break
            }
        }
    }
    
    @objc func mediaPlayerTimeChanged(_: Notification) {
        // If time is advancing, we are definitely NOT loading or buffering
        if case .loading = state {
            #if DEBUG
            print("[Phase 51] Safety: Time advancing - Force-clearing loading state.")
            #endif
            if let player = mediaPlayer {
                self.state = .playing(player)
            }
            self.isBuffering = false
            self.hasStartedPlaying = true
        }
        
        if isBuffering {
            #if DEBUG
            print("[Phase 51] Safety: Time advancing - Force-clearing buffering state.")
            #endif
            self.isBuffering = false
            self.bufferingTask?.cancel()
        }
        
        updateStreamStats()
    }
    private func updateStreamStats() {
        guard let player = mediaPlayer else { return }
        let size = abs(player.videoSize.width) > 0 ? player.videoSize : .zero
        if size.width > 0 {
            self.streamStats = "\(Int(size.width))x\(Int(size.height)) • VLC Engine"
        }
    }

    private func reconnect() {
        guard retryCount < maxRetries, let url = currentURL, let channel = currentChannel else {
            if retryCount >= maxRetries {
                state = .error("Stream connection lost. Please check your provider.")
            }
            return
        }
        
        let delay = pow(2.0, Double(retryCount))
        #if DEBUG
        print("[Phase 40] Reconnecting in \(Int(delay))s (Attempt \(retryCount + 1)/\(maxRetries))")
        #endif
        
        retryCount += 1
        
        Task {
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            load(url: url, channel: channel)
        }
    }

    func stop() {
        stallMonitorTask?.cancel()
        stallMonitorTask = nil

        bufferingTask?.cancel()
        bufferingTask = nil

        hasStartedPlaying = false
        isBuffering = false

        forceDismissTask?.cancel()
        forceDismissTask = nil

        // Nil mediaPlayer BEFORE removing observers so any in-flight notification
        // handlers hit `guard let player = mediaPlayer else { return }` and exit early,
        // preventing stale players from being stored in state after stop() returns.
        let player = mediaPlayer
        mediaPlayer = nil

        if let player = player {
            NotificationCenter.default.removeObserver(self, name: NSNotification.Name(rawValue: "VLCMediaPlayerStateChanged"), object: player)
            NotificationCenter.default.removeObserver(self, name: NSNotification.Name(rawValue: "VLCMediaPlayerTimeChanged"), object: player)
            player.stop()
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}


// MARK: - VLCPlayerView wrapper (Core migration from AVPlayerView)

struct VLCPlayerView: NSViewRepresentable {
    let player: VLCMediaPlayer

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.black.cgColor
        player.drawable = view
        return view
    }

    func updateNSView(_ view: NSView, context: Context) {
        // Only reassign if the drawable has changed — avoid redundant VLC resets on each layout pass
        if player.drawable as? NSView !== view {
            player.drawable = view
        }
    }
}

// MARK: - Overlay

struct PlayerOverlayView: View {
    let channel: Channel
    let epgEntry: EPGEntry?
    let mediaPlayer: VLCMediaPlayer?
    let streamStats: String?
    @Binding var isFavorite: Bool
    @Binding var isPresented: Bool
    @ObservedObject var authVM: AuthViewModel
    let categories: [StreamCategory]
    let onFavoriteToggle: () -> Void
    let onNext: () -> Void
    let onPrev: () -> Void

    @State private var isHoveringFav = false
    @State private var isHoveringClose = false
    @State private var isHoveringSettings = false
    @State private var isShowingSettings = false
    @State private var volume: Double = 1.0
    @State private var isMuted = false
    @State private var isPlaying = true
    @State private var isPulseActive = false

    var body: some View {
        ZStack {
            // Enhanced Vignette for focus
            LinearGradient(
                stops: [
                    .init(color: .black.opacity(0.6), location: 0.0),
                    .init(color: .clear, location: 0.25),
                    .init(color: .clear, location: 0.75),
                    .init(color: .black.opacity(0.6), location: 1.0)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            .allowsHitTesting(false)

            VStack(spacing: 0) {
                // MARK: – Top Status Bar (Glassmorphic)
                HStack(alignment: .center, spacing: 16) {
                    HStack(spacing: 12) {
                        if let iconUrl = channel.streamIcon, let url = URL(string: iconUrl) {
                            AsyncImage(url: url) { phase in
                                if case .success(let img) = phase {
                                    img.resizable().aspectRatio(contentMode: .fit)
                                } else {
                                    Image(systemName: "tv.fill")
                                        .foregroundColor(Color.appAccent)
                                }
                            }
                            .frame(width: 40, height: 40)
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                            .background(Color.white.opacity(0.1).clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous)))
                        } else {
                            ZStack {
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(Color.appAccent.opacity(0.2))
                                    .frame(width: 40, height: 40)
                                Text(channel.name.prefix(1))
                                    .font(.system(size: 20, weight: .bold, design: .rounded))
                                    .foregroundColor(Color.appAccent)
                            }
                        }

                        VStack(alignment: .leading, spacing: 1) {
                            Text(channel.name)
                                .font(.system(size: 16, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                            
                            if let epg = epgEntry {
                                Text(epg.title)
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(Color.appTextSecondary)
                                    .lineLimit(1)
                            } else {
                                HStack(spacing: 5) {
                                    Circle()
                                        .fill(Color.appLiveRed)
                                        .frame(width: 6, height: 6)
                                        .opacity(isPulseActive ? 1.0 : 0.4)
                                    Text("LIVE STREAM")
                                        .font(.system(size: 10, weight: .black))
                                        .foregroundColor(Color.appLiveRed)
                                        .tracking(1.0)
                                }
                                .onAppear { withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) { isPulseActive = true } }
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading) // Prevents text from pushing buttons out

                    Spacer(minLength: 16)

                    // Action Buttons (Apple standard style)
                    HStack(spacing: 14) {
                        if let stats = streamStats {
                            Text(stats)
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(Color.appAccent)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(Color.appAccent.opacity(0.15))
                                .clipShape(Capsule())
                        }

                        Button { isShowingSettings.toggle() } label: {
                            Image(systemName: "slider.horizontal.3")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.white)
                                .frame(width: 40, height: 40)
                                .background(isHoveringSettings ? Color.white.opacity(0.15) : Color.white.opacity(0.08))
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain)
                        .onHover { isHoveringSettings = $0 }
                        .popover(isPresented: $isShowingSettings, arrowEdge: .bottom) {
                            PlaybackSettingsView()
                        }

                        Button(action: onFavoriteToggle) {
                            Image(systemName: isFavorite ? "heart.fill" : "heart")
                                .font(.system(size: 18))
                                .foregroundColor(isFavorite ? Color.appFavoriteRed : .white)
                                .frame(width: 40, height: 40)
                                .background(isHoveringFav ? Color.white.opacity(0.15) : Color.white.opacity(0.08))
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain)
                        .onHover { isHoveringFav = $0 }
                        .animation(.spring(response: 0.3, dampingFraction: 0.5), value: isFavorite)

                        Button { isPresented = false } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.white)
                                .frame(width: 40, height: 40)
                                .background(isHoveringClose ? Color.white.opacity(0.15) : Color.white.opacity(0.08))
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain)
                        .onHover { isHoveringClose = $0 }
                    }
                }
                .padding(.horizontal, 32)
                .padding(.top, 16) // Safe area is now respected, only need visual breathing room
                .padding(.bottom, 24)

                Spacer()

                // MARK: – Bottom Control HUD (Native Style Pod)
                HStack(spacing: 0) {
                    Spacer()
                    
                    HStack(spacing: 24) {
                        // Volume Section
                        HStack(spacing: 8) {
                            Button {
                                isMuted.toggle()
                                mediaPlayer?.audio?.isMuted = isMuted
                            } label: {
                                Image(systemName: isMuted || volume == 0 ? "speaker.slash.fill" : (volume < 0.5 ? "speaker.wave.1.fill" : "speaker.wave.3.fill"))
                                    .font(.system(size: 12))
                                    .foregroundColor(.white.opacity(0.7))
                                    .frame(width: 18)
                            }
                            .buttonStyle(.plain)

                            Slider(value: $volume, in: 0...1)
                                .frame(minWidth: 40, maxWidth: 100)
                                .tint(Color.appAccent)
                                .scaleEffect(0.9)
                                .onChange(of: volume) { _, newValue in
                                    let clamped = min(max(newValue, 0.0), 1.0)
                                    mediaPlayer?.audio?.volume = Int32(clamped * 100)
                                    if clamped > 0 { isMuted = false; mediaPlayer?.audio?.isMuted = false }
                                }
                        }

                        // Central Transport
                        HStack(spacing: 20) {
                            Button(action: onPrev) {
                                Image(systemName: "backward.fill")
                                    .font(.system(size: 14))
                                    .foregroundColor(.white.opacity(0.9))
                            }
                            .buttonStyle(.plain)

                            Button {
                                if isPlaying { mediaPlayer?.pause() } else { mediaPlayer?.play() }
                                isPlaying.toggle()
                            } label: {
                                Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                                    .font(.system(size: 36))
                                    .foregroundColor(.white)
                                    .shadow(color: Color.appAccent.opacity(0.3), radius: 6)
                            }
                            .buttonStyle(.plain)

                            Button(action: onNext) {
                                Image(systemName: "forward.fill")
                                    .font(.system(size: 14))
                                    .foregroundColor(.white.opacity(0.9))
                            }
                            .buttonStyle(.plain)
                        }

                        // Fullscreen
                        Button {
                            if let window = NSApplication.shared.windows.first(where: { $0.isKeyWindow }) {
                                window.toggleFullScreen(nil)
                            }
                        } label: {
                            Image(systemName: "arrow.up.left.and.arrow.down.right")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.white.opacity(0.8))
                                .frame(width: 30, height: 30)
                                .background(Color.white.opacity(0.08))
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(
                        VisualEffectView(material: .hudWindow, blendingMode: .withinWindow)
                            .clipShape(Capsule())
                            .overlay(Capsule().stroke(Color.white.opacity(0.1), lineWidth: 0.5))
                            .shadow(color: .black.opacity(0.4), radius: 25, x: 0, y: 12)
                    )
                    .frame(maxWidth: 580)
                    .frame(minWidth: 320)
                    
                    Spacer()
                }
                .padding(.horizontal, 40)
                .padding(.bottom, 32)
            }
        }
        .onAppear {
            if let player = mediaPlayer {
                volume = Double(player.audio?.volume ?? 0) / 100.0
                isMuted = player.audio?.isMuted ?? false
            }
        }
    }
}

// MARK: - Stream Mode Settings (Improved Apple-style)

struct PlaybackSettingsView: View {
    @ObservedObject private var persistence = PersistenceService.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Text("Playback Settings")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                Spacer()
                Image(systemName: "tv.badge.wifi.fill")
                    .symbolRenderingMode(.hierarchical)
                    .foregroundColor(Color.appAccent)
            }
            .padding(.bottom, 8)
            
            // Buffer Profile Section
            VStack(alignment: .leading, spacing: 10) {
                Label("Buffer Capacity", systemImage: "bolt.horizontal.fill")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(Color.appTextSecondary)
                
                Picker("", selection: Binding(
                    get: { persistence.bufferProfile },
                    set: { persistence.setBufferProfile($0) }
                )) {
                    ForEach(BufferProfile.allCases, id: \.self) { profile in
                        Text(profile.rawValue).tag(profile)
                    }
                }
                .pickerStyle(.menu)
                .frame(maxWidth: .infinity, alignment: .trailing)
                
                Text(persistence.bufferProfile.description)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(Color.appAccent)
                    .padding(.top, 2)
            }
            
            Rectangle().fill(Color.white.opacity(0.08)).frame(height: 1)
            
            // Startup Delay
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Label("Initial Buffering", systemImage: "clock.fill")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(Color.appTextSecondary)
                    Spacer()
                    Text("\(Int(persistence.startupBufferDelay))s")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundColor(Color.appAccent)
                }
                
                Slider(value: Binding(
                    get: { persistence.startupBufferDelay },
                    set: { persistence.setStartupBufferDelay($0) }
                ), in: 0...10, step: 1)
                .tint(Color.appAccent)
            }
            
            Rectangle().fill(Color.white.opacity(0.08)).frame(height: 1)
            
            // Stream Format
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Label("Protocol Format", systemImage: "network")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(Color.appTextSecondary)
                    Spacer()
                    Picker("", selection: Binding(
                        get: { persistence.preferredStreamFormat },
                        set: { persistence.setStreamFormat($0) }
                    )) {
                        ForEach(StreamFormat.allCases, id: \.self) { format in
                            Text(format.rawValue).tag(format)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(width: 120)
                }
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Note: HLS is generally more stable on poor connections.")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(Color.appTextSecondary)
                    .italic()
            }
        }
        .padding(24)
        .frame(width: 300)
        .background(
            VisualEffectView(material: .sidebar, blendingMode: .withinWindow)
                .overlay(Color.black.opacity(0.2))
        )
    }
}
