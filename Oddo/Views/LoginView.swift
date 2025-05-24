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
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled(true)
                    .disabled(vm.isLoading)
                
                SecureField(NSLocalizedString("PasswordPlaceholder", comment: ""), text: $vm.password)
                    .textFieldStyle(.roundedBorder)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled(true)
                    .disabled(vm.isLoading)
                
                if let errorMessage = vm.errorMessage {
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .font(.caption)
                        .multilineTextAlignment(.center)
                }
                
                Button(action: {
                    Task { await vm.login() }
                }) {
                    if vm.isLoading {
                        HStack {
                            ProgressView()
                                .scaleEffect(0.8)
                            Text("Connecting...")
                        }
                    } else {
                        Text(NSLocalizedString("LoginButton", comment: ""))
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(vm.isLoading || vm.username.isEmpty || vm.password.isEmpty)
            }
            .padding()
        }
    }
}
