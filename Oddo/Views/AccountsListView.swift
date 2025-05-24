import SwiftUI
import SwiftData

struct AccountsListView: View {
    @StateObject private var vm = AccountsListViewModel()
    @Environment(\.modelContext) private var context

    var body: some View {
        NavigationStack {
            VStack {
                if vm.isLoading {
                    HStack {
                        ProgressView()
                        Text("Loading accounts...")
                    }
                    .padding()
                } else {
                    HStack {
                        Text(NSLocalizedString("TotalBalance", comment: ""))
                        Spacer()
                        Text("\(vm.totalValue, specifier: "%.2f") €").bold()
                    }
                    .padding()
                    
                    // Debug info
                    if vm.accounts.isEmpty && vm.errorMessage == nil && !vm.isLoading {
                        VStack {
                            Text("🔍 Debug: No accounts loaded")
                                .foregroundColor(.orange)
                                .padding()
                            
                            Button("🔄 Force Re-login (vfleurette)") {
                                Task {
                                    await vm.forceRelogin(username: "vfleurette", password: "43699702", context: context)
                                }
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(vm.isLoading)
                            .padding()
                            
                            // Bouton de test direct de l'API
                            Button("🧪 Test API Direct") {
                                Task {
                                    await testAPIDirectly()
                                }
                            }
                            .buttonStyle(.bordered)
                            .padding()
                        }
                    }
                    
                    if let errorMessage = vm.errorMessage {
                        Text(errorMessage)
                            .foregroundColor(.red)
                            .padding()
                    }
                    
                    if vm.accounts.isEmpty {
                        Text("No accounts found")
                            .foregroundColor(.gray)
                            .padding()
                    } else {
                        List(vm.accounts) { account in
                            NavigationLink(value: account) {
                                VStack(alignment: .leading) {
                                    Text(account.label.isEmpty ? account.accountNumber : account.label)
                                        .font(.headline)
                                    HStack {
                                        Text(account.accountNumber)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                        Spacer()
                                        Text("\(account.value, specifier: "%.2f") €")
                                            .font(.subheadline)
                                            .fontWeight(.medium)
                                    }
                                    // Debug: afficher le nombre de positions
                                    Text("\(account.positions.count) positions")
                                        .font(.caption2)
                                        .foregroundColor(.blue)
                                }
                            }
                        }
                        .navigationDestination(for: Account.self) { acc in
                            AccountDetailView(account: acc)
                        }
                    }
                }
            }
            .navigationTitle("Accounts (\(vm.accounts.count))")
            .task {
                print("🎬 AccountsListView task started")
                await vm.loadFromAuthService(context: context)
            }
            .refreshable {
                print("🔄 AccountsListView refresh triggered")
                await vm.loadFromAuthService(context: context)
            }
            .onAppear {
                print("👁️ AccountsListView appeared - Accounts: \(vm.accounts.count), Total: \(vm.totalValue)")
            }
        }
    }
    
    // Fonction de test API direct
    private func testAPIDirectly() async {
        print("🧪 Testing API directly...")
        
        do {
            // Login direct
            print("→ Direct login...")
            var loginReq = URLRequest(url: URL(string: "https://oddo.fleurette.me/login")!)
            loginReq.httpMethod = "POST"
            loginReq.setValue("application/json", forHTTPHeaderField: "Content-Type")
            let loginBody = ["user": "vfleurette", "pass": "43699702"]
            loginReq.httpBody = try JSONEncoder().encode(loginBody)
            
            let (loginData, loginResponse) = try await URLSession.shared.data(for: loginReq)
            
            guard let httpResponse = loginResponse as? HTTPURLResponse else {
                print("❌ Bad login response")
                return
            }
            
            print("→ Login status: \(httpResponse.statusCode)")
            
            if let loginString = String(data: loginData, encoding: .utf8) {
                print("→ Login response: \(loginString)")
            }
            
            guard (200...299).contains(httpResponse.statusCode) else {
                print("❌ Login failed")
                return
            }
            
            let loginResp = try JSONDecoder().decode([String: String].self, from: loginData)
            guard let jwt = loginResp["jwt"] else {
                print("❌ No JWT in response")
                return
            }
            
            print("✅ Got JWT: \(jwt.prefix(50))...")
            
            // Test accounts direct
            print("→ Testing accounts endpoint...")
            var accountsReq = URLRequest(url: URL(string: "https://oddo.fleurette.me/accounts")!)
            accountsReq.httpMethod = "GET"
            accountsReq.setValue("Bearer \(jwt)", forHTTPHeaderField: "Authorization")
            
            let (accountsData, accountsResponse) = try await URLSession.shared.data(for: accountsReq)
            
            guard let accountsHttpResponse = accountsResponse as? HTTPURLResponse else {
                print("❌ Bad accounts response")
                return
            }
            
            print("→ Accounts status: \(accountsHttpResponse.statusCode)")
            print("→ Accounts headers: \(accountsHttpResponse.allHeaderFields)")
            
            if let accountsString = String(data: accountsData, encoding: .utf8) {
                print("→ Accounts response: \(accountsString)")
            }
            
        } catch {
            print("❌ Direct API test failed: \(error)")
        }
    }
}
