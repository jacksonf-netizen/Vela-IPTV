import SwiftUI

struct RootView: View {
    @StateObject private var authVM = AuthViewModel()
    @ObservedObject private var persistence = PersistenceService.shared

    private var colorScheme: ColorScheme? {
        switch persistence.settings.themeMode {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }

    var body: some View {
        Group {
            if persistence.providers.isEmpty {
                // No providers yet — show Add Provider full-screen
                AddProviderView(authVM: authVM, isSheet: false)
                    .transition(.opacity)
            } else if persistence.activeProvider != nil {
                HomeView(authVM: authVM)
                    .transition(.opacity)
            } else {
                // Shouldn't happen, but fallback
                AddProviderView(authVM: authVM, isSheet: false)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: persistence.providers.isEmpty)
        .preferredColorScheme(colorScheme)
    }
}
