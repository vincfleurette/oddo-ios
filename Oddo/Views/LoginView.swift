import SwiftUI

struct LoginView: View {
    @StateObject private var vm = LoginViewModel()

    var body: some View {
        if vm.isLoggedIn {
            AccountsListView()
        } else {
            VStack(spacing: 16) {
                Text(NSLocalizedString("LoginTitle", comment: ""))
                    .font(.largeTitle)
                TextField(NSLocalizedString("UsernamePlaceholder", comment: ""), text: $vm.username)
                    .textFieldStyle(.roundedBorder)
                    .textInputAutocapitalization(.never) // Désactive la capitalisation auto (préféré)
                    .autocorrectionDisabled(true)         // Désactive la correction auto
                SecureField(NSLocalizedString("PasswordPlaceholder", comment: ""), text: $vm.password)
                    .textFieldStyle(.roundedBorder)
                    .textInputAutocapitalization(.never) // Désactive la capitalisation auto (préféré)
                    .autocorrectionDisabled(true)         // Désactive la correction auto
                if let _ = vm.errorMessage {
                    Text(NSLocalizedString("LoginError", comment: ""))
                        .foregroundColor(.red)
                }
                Button(NSLocalizedString("LoginButton", comment: "")) {
                    Task { await vm.login() }
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
        }
    }
}
