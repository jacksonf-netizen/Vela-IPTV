import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject private var persistence = PersistenceService.shared
    @ObservedObject var authVM: AuthViewModel
    @ObservedObject var channelVM: ChannelViewModel
    
    @State private var selectedProviderId: UUID?
    
    @State private var selectedTab: SettingsTab = .general
    
    enum SettingsTab: String, CaseIterable, Identifiable {
        var id: String { self.rawValue }
        case general = "General"
        case appearance = "Appearance"
        case playlists = "Playlists"
        case categories = "Categories"
        case tvGuide = "TV Guide"
        case playback = "Playback"
        
        var icon: String {
            switch self {
            case .general: return "gearshape.fill"
            case .appearance: return "paintbrush.fill"
            case .playlists: return "person.crop.circle.fill"
            case .categories: return "square.grid.2x2.fill"
            case .tvGuide: return "calendar.badge.clock"
            case .playback: return "play.circle.fill"
            }
        }
    }

    @State private var groupedCategories: [String: [StreamCategory]] = [:]
    @State private var sortedRegions: [String] = []
    @State private var isGrouping = false

    var body: some View {
        HStack(spacing: 0) {
            // MARK: – Settings Sidebar
            VStack(alignment: .leading, spacing: 5) {
                // Header (Mac Style)
                Text("Settings")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(Color.appTextSecondary)
                    .padding(.horizontal, 16)
                    .padding(.top, 40)
                    .padding(.bottom, 12)

                ForEach(SettingsTab.allCases) { tab in
                    SettingsSidebarItem(
                        icon: tab.icon,
                        title: tab.rawValue,
                        isSelected: selectedTab == tab,
                        action: { selectedTab = tab }
                    )
                }
                
                Spacer()
                
                // Done Button (Native feel)
                Button("Done") { dismiss() }
                    .buttonStyle(.bordered)
                    .controlSize(.regular)
                    .tint(Color.appAccent)
                    .padding(16)
                    .frame(maxWidth: .infinity)
            }
            .frame(width: 200)
            .background(VisualEffectView(material: .sidebar, blendingMode: .withinWindow))
            
            Divider().background(Color.white.opacity(0.1))
            
            // MARK: – Settings Content
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text(selectedTab.rawValue)
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    Spacer()
                }
                .padding(.horizontal, 40)
                .padding(.top, 40)
                .padding(.bottom, 24)

                // Content area – tabs with internal sidebars get no extra padding;
                // simple scroll tabs get capped width + uniform padding.
                Group {
                    switch selectedTab {
                    case .general:
                        settingsScrollPane { SettingsGeneralView() }
                    case .appearance:
                        settingsScrollPane { SettingsAppearanceView() }
                    case .playlists:
                        SettingsPlaylistsView(authVM: authVM)
                            .padding(.horizontal, 24)
                            .padding(.bottom, 20)
                    case .categories:
                        categorySettings
                            .padding(.horizontal, 24)
                            .padding(.bottom, 20)
                    case .tvGuide:
                        settingsScrollPane { SettingsTVGuideView(channelVM: channelVM) }
                    case .playback:
                        settingsScrollPane { SettingsPlaybackView() }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.appBackground)
        }
        .frame(minWidth: 780, idealWidth: 900, maxWidth: 1100, minHeight: 540, idealHeight: 660, maxHeight: 900)
        .background(VisualEffectView(material: .underWindowBackground, blendingMode: .withinWindow))
        .task {
            // Initialize selectedProviderId if not set
            if selectedProviderId == nil {
                selectedProviderId = persistence.activeProviderId ?? persistence.providers.first?.id
            }
            await refreshCategories()
        }
        .onChange(of: selectedProviderId) { _, _ in
            Task { await refreshCategories() }
        }
    }

    /// Consistent wrapper for simple scroll-based settings tabs.
    /// Caps content width so it doesn't stretch across ultra-wide windows,
    /// and ensures vertical alignment stays pinned to the top.
    private func settingsScrollPane<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        ScrollView(.vertical, showsIndicators: true) {
            content()
                .frame(maxWidth: 580, alignment: .leading)
                .padding(.horizontal, 40)
                .padding(.bottom, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func refreshCategories() async {
        guard let pid = selectedProviderId,
              let provider = persistence.providers.first(where: { $0.id == pid }) else { return }
        
        isGrouping = true
        // Ensure categories are loaded for this provider
        if channelVM.categoriesByProvider[pid] == nil {
            await channelVM.loadCategories(for: pid, credentials: provider.credentials)
        }
        
        let cats = channelVM.categoriesByProvider[pid] ?? []
        let grouped = Dictionary(grouping: cats) { parseRegion(from: $0.categoryName) }
        let sorted = grouped.keys.sorted()
        
        await MainActor.run {
            self.groupedCategories = grouped
            self.sortedRegions = sorted
            self.isGrouping = false
        }
    }



    private var categorySettings: some View {
        HStack(alignment: .top, spacing: 0) {
            // MARK: – Provider Vertical Sidebar
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
                        HStack(spacing: 12) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(selectedProviderId == provider.id ? Color.appAccent : Color.white.opacity(0.1))
                                    .frame(width: 28, height: 28)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
                                    )
                                
                                Image(systemName: "antenna.radiowaves.left.and.right")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(selectedProviderId == provider.id ? .white : Color.appTextSecondary)
                            }
                            
                            VStack(alignment: .leading, spacing: 1) {
                                Text(provider.name)
                                    .font(.system(size: 13, weight: selectedProviderId == provider.id ? .bold : .medium))
                                    .foregroundColor(selectedProviderId == provider.id ? .white : Color.appTextPrimary)
                                    .lineLimit(1)
                                
                                Text(provider.serverURL)
                                    .font(.system(size: 10))
                                    .foregroundColor(Color.appTextSecondary)
                                    .lineLimit(1)
                            }
                            
                            Spacer()
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(selectedProviderId == provider.id ? Color.white.opacity(0.08) : Color.clear)
                        )
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 6)
                }
                
                Spacer()
            }
            .frame(width: 160)
            .padding(.top, 4)
            
            Divider()
                .background(Color.white.opacity(0.1))
                .padding(.horizontal, 20)

            // MARK: – Categories List
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    SettingsGroup(title: "Behavior") {
                        SettingsRow(title: "Auto-Hide New Groups", subtitle: "When your provider adds new categories, keep them hidden by default.") {
                            Toggle("", isOn: Binding(
                                get: { persistence.autoHideNewCategories },
                                set: { persistence.setAutoHideNewCategories($0) }
                            ))
                            .toggleStyle(.switch)
                        }
                    }
                    .padding(.top, 4)

                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Channel Visibility")
                                .font(.system(size: 18, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                            Text("Hiding groups improves app performance.")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(Color.appTextSecondary)
                        }
                        
                        Spacer()
                        
                        HStack(spacing: 12) {
                            Button("Show All") { 
                                if let pid = selectedProviderId {
                                    persistence.setCategoriesHidden([], forProviderId: pid)
                                }
                            }
                            .buttonStyle(.plain)
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(Color.appAccent)
                            
                            Button("Hide All") { 
                                if let pid = selectedProviderId, let cats = channelVM.categoriesByProvider[pid] {
                                    persistence.setCategoriesHidden(Set(cats.map { $0.categoryId }), forProviderId: pid)
                                }
                            }
                            .buttonStyle(.plain)
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(Color.appAccent)
                        }
                    }
                    .padding(.bottom, 8)

                    if isGrouping {
                        HStack(spacing: 10) {
                            VelaIPTVSpinner(size: 20, lineWidth: 2)
                            Text("Organizing categories…")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(Color.appTextSecondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 40)
                    } else {
                        LazyVStack(alignment: .leading, spacing: 20) {
                            ForEach(sortedRegions, id: \.self) { region in
                                VStack(alignment: .leading, spacing: 10) {
                                    HStack {
                                        Text(region)
                                            .font(.system(size: 14, weight: .bold, design: .rounded))
                                            .foregroundColor(Color.appAccent)
                                        
                                        Spacer()
                                        
                                        Button(persistence.isRegionVisible(region, in: groupedCategories[region] ?? [], forProviderId: selectedProviderId) ? "Hide Region" : "Show Region") {
                                            if let pid = selectedProviderId {
                                                persistence.toggleRegionVisibility(region, in: groupedCategories[region] ?? [], forProviderId: pid)
                                            }
                                        }
                                        .buttonStyle(.plain)
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundColor(Color.appTextSecondary)
                                    }
                                    
                                    ForEach(groupedCategories[region] ?? []) { cat in
                                        HStack {
                                            Text(cat.categoryName)
                                                .font(.system(size: 13, weight: .medium))
                                                .foregroundColor(persistence.isCategoryHidden(cat.categoryId, providerId: selectedProviderId) ? Color.appTextSecondary.opacity(0.5) : .white)
                                            Spacer()
                                            Toggle("", isOn: Binding(
                                                get: { !persistence.isCategoryHidden(cat.categoryId, providerId: selectedProviderId) },
                                                set: { _ in 
                                                    if let pid = selectedProviderId {
                                                        persistence.toggleCategoryHidden(cat.categoryId, forProviderId: pid)
                                                    }
                                                }
                                            ))
                                            .toggleStyle(.switch)
                                            .scaleEffect(0.8)
                                        }
                                        .padding(.leading, 12)
                                        .padding(.vertical, 4)
                                    }
                                }
                                .padding(16)
                                .background(Color.white.opacity(0.03))
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            }
                        }
                    }
                }
                .padding(.trailing, 4) // Space for scrollbar
            }
        }
    }



    private func parseRegion(from name: String) -> String {
        var raw = name.trimmingCharacters(in: .whitespaces)
        if let first = raw.first, first.isNumber {
            let components = raw.components(separatedBy: CharacterSet.decimalDigits).filter { !$0.isEmpty }
            if let firstNonNumeric = components.first {
                raw = firstNonNumeric.trimmingCharacters(in: CharacterSet.whitespaces.union(CharacterSet(charactersIn: "-_. ")))
            }
        }
        var region = ""
        let separators = ["[", "]", "|", ":", " - ", " / ", "•", "*", "~", ">>", "—"]
        if raw.contains("[") && raw.contains("]") {
            let start = raw.firstIndex(of: "[")!
            let end = raw.firstIndex(of: "]")!
            region = String(raw[raw.index(after: start)..<end]).trimmingCharacters(in: .whitespaces)
        } else if raw.contains("(") && raw.contains(")") {
            let start = raw.firstIndex(of: "(")!
            let end = raw.firstIndex(of: ")")!
            region = String(raw[raw.index(after: start)..<end]).trimmingCharacters(in: .whitespaces)
        } else {
            for sep in separators {
                if raw.contains(sep) {
                    region = raw.components(separatedBy: sep)[0].trimmingCharacters(in: .whitespaces)
                    if !region.isEmpty { break }
                }
            }
        }
        if region.isEmpty {
            let words = raw.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
            region = words.first ?? "Miscellaneous"
        }
        let upperRegion = region.uppercased().replacingOccurrences(of: ".", with: "")
        if upperRegion == "US" || upperRegion == "NA" || upperRegion == "USA" || upperRegion == "UNITED STATES" { return "USA" }
        if upperRegion == "UK" || upperRegion == "GB" || upperRegion == "ENGLAND" { return "UK" }
        return region
    }
}

// MARK: – Helper Components
struct SettingsSidebarItem: View {
    let icon: String
    let title: String
    let isSelected: Bool
    let action: () -> Void
    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .symbolRenderingMode(.hierarchical)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(isSelected ? .white : Color.appAccent)
                    .frame(width: 20)

                Text(title)
                    .font(.system(size: 13, weight: isSelected ? .bold : .medium))
                    .foregroundColor(isSelected ? .white : Color.appTextPrimary)
                
                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(isSelected ? Color.appAccent : (isHovering ? Color.white.opacity(0.08) : Color.clear))
            )
            .padding(.horizontal, 12)
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isHovering || isSelected)
    }
}

struct SettingsGroup<Content: View>: View {
    let title: String
    let content: Content
    
    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(title)
                .font(.system(size: 12, weight: .black))
                .foregroundColor(Color.appTextSecondary)
                .tracking(1.0)
            
            VStack(spacing: 0) {
                content
            }
            .padding(20)
            .background(Color.white.opacity(0.04))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Color.white.opacity(0.06), lineWidth: 1))
        }
    }
}

struct SettingsRow<Content: View>: View {
    let title: String
    let subtitle: String
    let content: Content
    
    init(title: String, subtitle: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.subtitle = subtitle
        self.content = content()
    }
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white)
                Text(subtitle)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(Color.appTextSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 16)
            content
                .layoutPriority(1)
        }
        .padding(.vertical, 10)
    }
}

struct ProviderManagementCard: View {
    @ObservedObject private var persistence = PersistenceService.shared
    let provider: Provider
    
    @State private var isEditing = false
    @State private var editedName: String
    @State private var editedURL: String
    @State private var editedUsername: String
    @State private var editedPassword: String
    @State private var showPassword = false
    
    init(provider: Provider) {
        self.provider = provider
        _editedName = State(initialValue: provider.name)
        _editedURL = State(initialValue: provider.serverURL)
        _editedUsername = State(initialValue: provider.username)
        _editedPassword = State(initialValue: provider.password)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                // Provider Glyph
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.appAccent.opacity(0.1))
                        .frame(width: 32, height: 32)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(Color.appAccent.opacity(0.2), lineWidth: 1)
                        )
                    
                    Image(systemName: "antenna.radiowaves.left.and.right")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(Color.appAccent)
                }
                
                VStack(alignment: .leading, spacing: 1) {
                    if isEditing {
                        TextField("Display Name", text: $editedName)
                            .textFieldStyle(.plain)
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                    } else {
                        Text(provider.name)
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                    }
                    
                    Text(provider.serverURL)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(Color.appTextSecondary)
                        .lineLimit(1)
                }
                
                Spacer()
                
                if isEditing {
                    HStack(spacing: 8) {
                        Button("Cancel") {
                            resetFields()
                            isEditing = false
                        }
                        .buttonStyle(.plain)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(Color.appTextSecondary)
                        
                        Button("Save") {
                            saveChanges()
                            isEditing = false
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                        .tint(Color.appAccent)
                    }
                } else {
                    Button(action: { isEditing = true }) {
                        Text("Edit")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(Color.appAccent)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.appAccent.opacity(0.1))
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            
            if isEditing {
                VStack(spacing: 12) {
                    Divider().background(Color.white.opacity(0.1))
                    
                    SettingsEditRow(title: "Server URL", text: $editedURL, placeholder: "http://example.com:8080")
                    SettingsEditRow(title: "Username", text: $editedUsername, placeholder: "Username")
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Password")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(Color.appTextSecondary)
                        
                        HStack {
                            if showPassword {
                                TextField("Password", text: $editedPassword)
                            } else {
                                SecureField("Password", text: $editedPassword)
                            }
                            
                            Button { showPassword.toggle() } label: {
                                Image(systemName: showPassword ? "eye.slash.fill" : "eye.fill")
                                    .font(.system(size: 12))
                                    .foregroundColor(Color.appTextSecondary)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(10)
                        .background(Color.white.opacity(0.05))
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }
                    
                    Divider().background(Color.white.opacity(0.1))
                    
                    HStack {
                        Spacer()
                        
                        Button(role: .destructive) {
                            persistence.removeProvider(provider)
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "trash.fill")
                                Text("Remove")
                            }
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.red.opacity(0.8))
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.top, 4)
                }
                .padding(.top, 4)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(4)
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: isEditing)
    }
    
    private func resetFields() {
        editedName = provider.name
        editedURL = provider.serverURL
        editedUsername = provider.username
        editedPassword = provider.password
    }
    
    private func saveChanges() {
        var updated = provider
        updated.name = editedName
        updated.serverURL = editedURL
        updated.username = editedUsername
        updated.password = editedPassword
        persistence.updateProvider(updated)
    }
}

struct SettingsEditRow: View {
    let title: String
    @Binding var text: String
    let placeholder: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(Color.appTextSecondary)
            
            TextField(placeholder, text: $text)
                .textFieldStyle(.plain)
                .padding(10)
                .background(Color.white.opacity(0.05))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
    }
}
