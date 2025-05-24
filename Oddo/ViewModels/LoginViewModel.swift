import SwiftUI

@MainActor
class LoginViewModel: ObservableObject {
    @Published var username = ""
    @Published var password = ""
    @Published var isLoggedIn = false
    @Published var errorMessage: String?
    @Published var isLoading = false

    init() {
        // Vérifier si l'utilisateur est déjà connecté au démarrage
        checkExistingLogin()
    }
    
    private func checkExistingLogin() {
        if AuthService.shared.retrieveJWT() != nil {
            isLoggedIn = true
            print("✅ User already logged in")
        }
    }

    func login() async {
        isLoading = true
        errorMessage = nil
        
        guard !username.isEmpty && !password.isEmpty else {
            errorMessage = "Username and password are required"
            isLoading = false
            return
        }
        
        do {
            try await AuthService.shared.login(user: username, pass: password)
            print("✅ Login successful in ViewModel")
            isLoggedIn = true
            isLoading = false
        } catch {
            print("❌ Login error: \(error)")
            errorMessage = "Login failed: \(error.localizedDescription)"
            isLoading = false
        }
    }
    
    func logout() {
        AuthService.shared.logout()
        isLoggedIn = false
        username = ""
        password = ""
        errorMessage = nil
    }
}
