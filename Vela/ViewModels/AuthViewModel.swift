import Foundation
import Combine

@MainActor
class AuthViewModel: ObservableObject {
    @Published var isShowingAddProvider = false

    // Form fields for adding a new provider
    @Published var newProviderName: String   = ""
    @Published var newServerURL: String      = ""
    @Published var newUsername: String       = ""
    @Published var newPassword: String       = ""
    @Published var isLoading: Bool           = false
    @Published var errorMessage: String?     = nil

    private let service     = XtreamCodesService.shared
    let persistence         = PersistenceService.shared

    var hasProviders: Bool { !persistence.providers.isEmpty }

    func addProvider() async {
        errorMessage = nil
        isLoading = true
        defer { isLoading = false }

        let creds = XtreamCredentials(
            serverURL: newServerURL,
            username: newUsername,
            password: newPassword
        )
        do {
            _ = try await service.authenticate(credentials: creds)
            let name  = newProviderName.trimmingCharacters(in: .whitespaces)
            let label = name.isEmpty ? "Provider \(persistence.providers.count + 1)" : name
            let provider = Provider(
                name: label,
                serverURL: newServerURL,
                username: newUsername,
                password: newPassword
            )
            persistence.addProvider(provider)
            resetForm()
            isShowingAddProvider = false
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func removeProvider(_ provider: Provider) {
        persistence.removeProvider(provider)
    }

    func selectProvider(_ provider: Provider) {
        persistence.setActiveProvider(provider)
    }

    func resetForm() {
        newProviderName = ""
        newServerURL    = ""
        newUsername     = ""
        newPassword     = ""
        errorMessage    = nil
    }
}
