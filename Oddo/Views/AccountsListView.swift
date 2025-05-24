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
                    // Header avec solde total et statut
                    VStack(spacing: 8) {
                        HStack {
                            VStack(alignment: .leading) {
                                Text(NSLocalizedString("TotalBalance", comment: ""))
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                Text("\(vm.totalValue, specifier: "%.2f") €")
                                    .font(.title2)
                                    .fontWeight(.bold)
                            }
                            
                            Spacer()
                            
                            // Indicateur de fraîcheur des données
                            VStack(alignment: .trailing) {
                                HStack {
                                    Image(systemName: vm.isDataFresh ? "checkmark.circle.fill" : "clock.circle.fill")
                                        .foregroundColor(vm.isDataFresh ? .green : .orange)
                                    Text(vm.isDataFresh ? "Fresh" : "Cached")
                                        .font(.caption)
                                        .fontWeight(.medium)
                                }
                                Text(vm.cacheInfo)
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.horizontal)
                        
                        // Barre de séparation
                        Divider()
                    }
                    
                    // Messages d'erreur
                    if let errorMessage = vm.errorMessage {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.orange)
                            Text(errorMessage)
                                .foregroundColor(.orange)
                        }
                        .padding()
                        .background(Color.orange.opacity(0.1))
                        .cornerRadius(8)
                        .padding(.horizontal)
                    }
                    
                    // Debug info (seulement si pas de comptes)
                    if vm.accounts.isEmpty && vm.errorMessage == nil && !vm.isLoading {
                        VStack(spacing: 16) {
                            Image(systemName: "chart.line.uptrend.xyaxis")
                                .font(.system(size: 50))
                                .foregroundColor(.gray)
                            
                            Text("No Financial Data")
                                .font(.title2)
                                .fontWeight(.semibold)
                            
                            Text("Unable to load your accounts and positions")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                            
                            VStack(spacing: 12) {
                                Button("🔄 Refresh Data") {
                                    Task {
                                        await vm.loadFromAuthService(context: context, forceRefresh: true)
                                    }
                                }
                                .buttonStyle(.borderedProminent)
                                .disabled(vm.isLoading)
                                
                                Button("🔐 Re-authenticate") {
                                    Task {
                                        await vm.forceRelogin(username: "vfleurette", password: "43699702", context: context)
                                    }
                                }
                                .buttonStyle(.bordered)
                                .disabled(vm.isLoading)
                            }
                        }
                        .padding()
                    }
                    
                    // Liste des comptes
                    if !vm.accounts.isEmpty {
                        List(vm.accounts) { account in
                            NavigationLink(value: account) {
                                AccountRowView(account: account)
                            }
                        }
                        .navigationDestination(for: Account.self) { acc in
                            AccountDetailView(account: acc)
                        }
                    }
                }
            }
            .navigationTitle("Portfolio")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button("Refresh Now") {
                            Task {
                                await vm.loadFromAuthService(context: context, forceRefresh: true)
                            }
                        }
                        .disabled(vm.isLoading)
                        
                        Button("Clear Cache") {
                            // TODO: Implémenter si nécessaire
                        }
                        
                        Divider()
                        
                        Label("Data updates every 12h", systemImage: "info.circle")
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                    .disabled(vm.isLoading)
                }
            }
            .task {
                print("🎬 AccountsListView task started - Financial data mode")
                // Charge intelligemment (cache en priorité)
                await vm.loadFromAuthService(context: context, forceRefresh: false)
            }
            .refreshable {
                print("🔄 Pull-to-refresh - Force API refresh")
                // Pull-to-refresh force un rechargement depuis l'API
                await vm.loadFromAuthService(context: context, forceRefresh: true)
            }
            .onAppear {
                print("👁️ AccountsListView appeared - Accounts: \(vm.accounts.count), Total: \(vm.totalValue)€")
            }
        }
    }
}

// Vue de ligne de compte optimisée
struct AccountRowView: View {
    let account: Account
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                VStack(alignment: .leading) {
                    Text(account.label.isEmpty ? account.accountNumber : account.label)
                        .font(.headline)
                        .lineLimit(2)
                    
                    Text(account.accountNumber)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing) {
                    Text("\(account.value, specifier: "%.2f") €")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    
                    Text("\(account.positions.count) positions")
                        .font(.caption2)
                        .foregroundColor(.blue)
                }
            }
            
            // Barre de progression visuelle (optionnelle)
            if account.value > 0 {
                ProgressView(value: account.value, total: 200000) // Ajustez selon vos besoins
                    .progressViewStyle(LinearProgressViewStyle(tint: .blue))
                    .scaleEffect(y: 0.5)
            }
        }
        .padding(.vertical, 4)
    }
}
