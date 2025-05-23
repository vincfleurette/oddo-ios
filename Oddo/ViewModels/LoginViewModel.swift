import SwiftUI

@MainActor
class LoginViewModel: ObservableObject {
    @Published var username = ""
    @Published var password = ""
    @Published var isLoggedIn = false
    @Published var errorMessage: String?

    func login() async {
        do {
            try await AuthService.shared.login(user: username, pass: password)
            DispatchQueue.main.async { self.isLoggedIn = true }
        } catch {
            DispatchQueue.main.async { self.errorMessage = error.localizedDescription }
        }
    }
}
