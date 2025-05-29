// Oddo/Views/AccountsListView.swift - FICHIER COMPLET AVEC FIX NAVIGATION SEULEMENT

import SwiftUI
import SwiftData

struct AccountsListView: View {
    @StateObject private var vm = AccountsListViewModel()
    @Environment(\.modelContext) private var context
    @State private var showingCacheSheet = false
    @State private var selectedAccount: Account? // AJOUTÉ pour fix navigation

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
                            
                            // Indicateur de fraîcheur des données avec performance
                            VStack(alignment: .trailing) {
                                HStack {
                                    Image(systemName: vm.isDataFresh ? "checkmark.circle.fill" : "clock.circle.fill")
                                        .foregroundColor(vm.isDataFresh ? .green : .orange)
                                    Text(vm.isDataFresh ? "Fresh" : "Cached")
                                        .font(.caption)
                                        .fontWeight(.medium)
                                }
                                
                                // Afficher la performance du portefeuille si disponible
                                if let portfolio = vm.portfolioStats {
                                    Text(portfolio.formatted.weightedPerformance)
                                        .font(.caption)
                                        .fontWeight(.semibold)
                                        .foregroundColor(portfolio.formatted.performanceColor == "green" ? .green : .red)
                                }
                                
                                Text(vm.combinedCacheStatus)
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                    .lineLimit(2)
                                    .multilineTextAlignment(.trailing)
                            }
                        }
                        .padding(.horizontal)
                        
                        // Statistiques du portefeuille si disponibles
                        if let portfolio = vm.portfolioStats {
                            PortfolioSummaryBanner(portfolio: portfolio)
                        }
                        
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
                    
                    // NAVIGATION CORRIGÉE: Liste des comptes
                    if !vm.accounts.isEmpty {
                        List(vm.accounts) { account in
                            Button(action: {
                                // Gestion de navigation avec délai pour éviter les conflits
                                DispatchQueue.main.async {
                                    selectedAccount = account
                                }
                            }) {
                                AccountRowView(account: account)
                                    .contentShape(Rectangle()) // Pour que toute la zone soit tappable
                            }
                            .buttonStyle(PlainButtonStyle()) // Évite le style bouton par défaut
                        }
                        .navigationDestination(item: $selectedAccount) { account in
                            AccountDetailView(account: account)
                        }
                    }
                }
            }
            .navigationTitle("Portfolio")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button("🔄 Refresh Data") {
                            Task {
                                await vm.loadFromAuthService(context: context, forceRefresh: true)
                            }
                        }
                        .disabled(vm.isLoading)
                        
                        Button("🚀 Force Server Refresh") {
                            Task {
                                await vm.forceServerCacheRefresh(context: context)
                            }
                        }
                        .disabled(vm.isLoading)
                        
                        Button("🗑️ Clear All Caches") {
                            Task {
                                await vm.invalidateAllCaches(context: context)
                            }
                        }
                        .disabled(vm.isLoading)
                        
                        Divider()
                        
                        Button("📊 Cache Info") {
                            showingCacheSheet = true
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
                await vm.loadFromAuthService(context: context, forceRefresh: false)
            }
            .refreshable {
                print("🔄 Pull-to-refresh - Force API refresh")
                await vm.loadFromAuthService(context: context, forceRefresh: true)
            }
            .onAppear {
                print("👁️ AccountsListView appeared - Accounts: \(vm.accounts.count), Total: \(vm.totalValue)€")
            }
            .sheet(isPresented: $showingCacheSheet) {
                CacheInfoSheet(viewModel: vm, context: context)
            }
        }
        // AJOUTÉ: Animations contrôlées pour éviter les mises à jour multiples
        .animation(.easeInOut(duration: 0.3), value: vm.accounts.count)
        .animation(.easeInOut(duration: 0.3), value: vm.isLoading)
    }
}

// MARK: - Portfolio Summary Banner

struct PortfolioSummaryBanner: View {
    let portfolio: PortfolioStats
    
    var body: some View {
        HStack {
            // Performance globale
            VStack(alignment: .leading, spacing: 2) {
                Text("Performance")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                HStack {
                    Image(systemName: portfolio.weightedPerformance >= 0 ? "arrow.up.right" : "arrow.down.right")
                        .font(.caption2)
                    Text(portfolio.formatted.weightedPerformance)
                        .font(.caption)
                        .fontWeight(.semibold)
                }
                .foregroundColor(portfolio.formatted.performanceColor == "green" ? .green : .red)
            }
            
            Spacer()
            
            // P&L
            VStack(alignment: .center, spacing: 2) {
                Text("P&L")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Text(portfolio.formatted.totalPMVL)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(portfolio.formatted.pmvlColor == "green" ? .green : .red)
            }
            
            Spacer()
            
            // Nombre de positions
            VStack(alignment: .trailing, spacing: 2) {
                Text("Positions")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Text("\(portfolio.positionsCount)")
                    .font(.caption)
                    .fontWeight(.semibold)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(.systemGray6))
        .cornerRadius(8)
        .padding(.horizontal)
    }
}

// MARK: - Cache Info Sheet

struct CacheInfoSheet: View {
    @ObservedObject var viewModel: AccountsListViewModel
    let context: ModelContext
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                LazyVStack(spacing: 16) {
                    // Local Cache Section
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "iphone")
                                .foregroundColor(.blue)
                            Text("Local Cache (iOS)")
                                .font(.headline)
                        }
                        
                        InfoRow(label: "Status", value: viewModel.isDataFresh ? "Fresh" : "Expired")
                        InfoRow(label: "Last Update", value: viewModel.localCacheInfo)
                        InfoRow(label: "Accounts", value: "\(viewModel.accounts.count)")
                        InfoRow(label: "Total Value", value: String(format: "%.2f €", viewModel.totalValue))
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    
                    // Server Cache Section
                    if let serverCache = viewModel.serverCacheInfo {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Image(systemName: "server.rack")
                                    .foregroundColor(.green)
                                Text("Server Cache")
                                    .font(.headline)
                            }
                            
                            InfoRow(label: "Status", value: serverCache.statusDescription)
                            InfoRow(label: "Created", value: formatDate(serverCache.cacheTimestamp))
                            InfoRow(label: "Age", value: serverCache.cacheAgeHuman ?? "N/A")
                            InfoRow(label: "Expires In", value: serverCache.expiresInHuman ?? "N/A")
                            InfoRow(label: "TTL", value: serverCache.cacheTtlHuman ?? "N/A")
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                    }
                    
                    // Portfolio Stats Section (si disponible)
                    if let portfolio = viewModel.portfolioStats {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Image(systemName: "chart.pie.fill")
                                    .foregroundColor(.purple)
                                Text("Portfolio Statistics")
                                    .font(.headline)
                            }
                            
                            InfoRow(label: "Performance", value: portfolio.formatted.weightedPerformance)
                            InfoRow(label: "Unrealized P&L", value: portfolio.formatted.totalPMVL)
                            InfoRow(label: "Positions", value: "\(portfolio.positionsCount)")
                            InfoRow(label: "Asset Classes", value: "\(portfolio.performanceByAssetClass.count)")
                            
                            if !portfolio.topPerformers.isEmpty {
                                InfoRow(label: "Top Performer", value: portfolio.topPerformers[0].libInstrument)
                            }
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                    }
                    
                    // Actions Section
                    VStack(spacing: 12) {
                        Text("Cache Actions")
                            .font(.headline)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        
                        Button("🔄 Refresh Local Cache") {
                            Task {
                                await viewModel.loadFromAuthService(context: context, forceRefresh: true)
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(viewModel.isLoading)
                        
                        Button("🚀 Force Server Cache Refresh") {
                            Task {
                                await viewModel.forceServerCacheRefresh(context: context)
                            }
                        }
                        .buttonStyle(.bordered)
                        .disabled(viewModel.isLoading)
                        
                        Button("🗑️ Clear All Caches") {
                            Task {
                                await viewModel.invalidateAllCaches(context: context)
                            }
                        }
                        .buttonStyle(.bordered)
                        .disabled(viewModel.isLoading)
                        
                        if viewModel.isLoading {
                            ProgressView("Processing...")
                                .padding()
                        }
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                }
                .padding()
            }
            .navigationTitle("Cache Management")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    // Gestion des optionals pour formatDate
    private func formatDate(_ dateString: String?) -> String {
        guard let dateString = dateString, !dateString.isEmpty else {
            return "N/A"
        }
        
        let formatter = ISO8601DateFormatter()
        if let date = formatter.date(from: dateString) {
            let displayFormatter = DateFormatter()
            displayFormatter.dateStyle = .medium
            displayFormatter.timeStyle = .short
            displayFormatter.locale = Locale.current
            return displayFormatter.string(from: date)
        }
        
        return dateString
    }
}

// MARK: - Helper Views

struct InfoRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.medium)
        }
    }
}

// MARK: - Account Row View (CORRIGÉE pour navigation)

struct AccountRowView: View {
    let account: Account
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                VStack(alignment: .leading) {
                    Text(account.label.isEmpty ? account.accountNumber : account.label)
                        .font(.headline)
                        .lineLimit(2)
                        .foregroundColor(.primary) // AJOUTÉ pour le style bouton
                    
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
            
            // Barre de progression visuelle
            if account.value > 0 {
                ProgressView(value: account.value, total: 200000)
                    .progressViewStyle(LinearProgressViewStyle(tint: .blue))
                    .scaleEffect(y: 0.5)
            }
        }
        .padding(.vertical, 4)
    }
}
