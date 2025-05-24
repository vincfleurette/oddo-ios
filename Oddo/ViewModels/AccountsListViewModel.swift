import SwiftUI
import SwiftData

extension String {
    func base64Decoded() -> Data? {
        var base64 = self
        let remainder = base64.count % 4
        if remainder > 0 {
            base64 = base64.padding(toLength: base64.count + 4 - remainder, withPad: "=", startingAt: 0)
        }
        return Data(base64Encoded: base64)
    }
}

@MainActor
class AccountsListViewModel: ObservableObject {
    @Published var accounts: [Account] = []
    @Published var totalValue: Double = 0
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private var lastRefreshDate: Date?
    private let cacheValidityDuration: TimeInterval = 6 * 3600 // 6 heures (données mises à jour toutes les 12h)
    
    // Calcul des heures de mise à jour (supposons 9h et 21h par exemple)
    private let dataUpdateHours: [Int] = [9, 21] // 9h00 et 21h00

    /// Charge les comptes en utilisant le cache intelligent pour données financières
    func loadAccountsSmartly(context: ModelContext, forceRefresh: Bool = false) async {
        // 1. Si force refresh, aller directement à l'API
        if forceRefresh {
            print("🔄 Force refresh requested")
            await loadFromAPI(context: context)
            return
        }
        
        // 2. Vérifier si on a des données récentes en cache
        if await loadFromLocalCache(context: context) {
            print("✅ Using cached data (financial data updates every 12h)")
            return
        }
        
        // 3. Sinon, charger depuis l'API
        print("📡 Cache expired or empty, loading from API")
        await loadFromAPI(context: context)
    }
    
    /// Charge depuis le cache local avec logique adaptée aux données financières
    private func loadFromLocalCache(context: ModelContext) async -> Bool {
        do {
            let descriptor = FetchDescriptor<Account>(sortBy: [SortDescriptor(\.accountNumber)])
            let cachedAccounts = try context.fetch(descriptor)
            
            guard !cachedAccounts.isEmpty else {
                print("🔍 No cached accounts found")
                return false
            }
            
            // Vérifier la fraîcheur via les snapshots
            let snapshotDescriptor = FetchDescriptor<Snapshot>(
                sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
            )
            let recentSnapshots = try context.fetch(snapshotDescriptor)
            
            if let lastSnapshot = recentSnapshots.first {
                let timeSinceLastUpdate = Date().timeIntervalSince(lastSnapshot.timestamp)
                let hoursAgo = timeSinceLastUpdate / 3600
                
                // Si les données ont moins de 6 heures, les utiliser
                if timeSinceLastUpdate < cacheValidityDuration {
                    self.accounts = cachedAccounts
                    self.totalValue = cachedAccounts.reduce(0) { $0 + $1.value }
                    self.lastRefreshDate = lastSnapshot.timestamp
                    
                    print("✅ Using cache from \(String(format: "%.1f", hoursAgo))h ago")
                    return true
                } else {
                    print("🕐 Cache expired (\(String(format: "%.1f", hoursAgo))h ago, validity: 6h)")
                    return false
                }
            }
            
            // Pas de snapshot récent
            print("❌ No recent snapshot found")
            return false
            
        } catch {
            print("❌ Failed to load from cache: \(error)")
            return false
        }
    }
    
    /// Charge depuis l'API et met à jour le cache
    private func loadFromAPI(context: ModelContext) async {
        guard let jwt = AuthService.shared.retrieveJWT() else {
            print("❌ JWT missing, authentication required")
            self.errorMessage = "Authentication required"
            return
        }
        
        // Vérifier l'expiration du JWT
        if isJWTExpired(jwt) {
            self.errorMessage = "Token expired, please re-login"
            return
        }
        
        await load(jwt: jwt, context: context)
    }
    
    /// Vérification d'expiration du JWT
    private func isJWTExpired(_ jwt: String) -> Bool {
        let jwtParts = jwt.split(separator: ".")
        guard jwtParts.count == 3 else { return true }
        
        let payload = String(jwtParts[1])
        guard let payloadData = payload.base64Decoded(),
              let jwtJson = try? JSONSerialization.jsonObject(with: payloadData, options: []) as? [String: Any],
              let exp = jwtJson["exp"] as? TimeInterval else {
            return true
        }
        
        let expirationDate = Date(timeIntervalSince1970: exp)
        let isExpired = expirationDate < Date()
        
        if isExpired {
            print("⚠️ JWT expired")
        }
        
        return isExpired
    }

    /// Charge les comptes avec le JWT fourni
    func load(jwt: String, context: ModelContext) async {
        print("🔄 Loading accounts from API...")
        isLoading = true
        errorMessage = nil
        
        do {
            let dtos = try await APIService.shared.fetchAccounts(jwt: jwt)
            print("→ Received \(dtos.count) accounts from API")
            
            // Supprimer les anciens comptes pour éviter les doublons
            await clearOldAccounts(context: context)
            
            var models: [Account] = []
            for dto in dtos {
                let acc = Account(accountNumber: dto.accountNumber, label: dto.label, value: dto.value, positions: [])
                let positions = dto.positions.map { Position(dto: $0, account: acc) }
                acc.positions = positions
                
                context.insert(acc)
                for position in positions {
                    context.insert(position)
                }
                
                let snapshot = Snapshot(account: acc)
                context.insert(snapshot)
                
                models.append(acc)
            }
            
            try context.save()
            
            self.accounts = models
            self.totalValue = models.reduce(0) { $0 + $1.value }
            self.lastRefreshDate = Date()
            
            print("✅ Successfully loaded \(models.count) accounts, total: \(String(format: "%.2f", totalValue))€")
            
        } catch {
            print("⚠️ Error loading accounts: \(error.localizedDescription)")
            self.errorMessage = "Failed to load accounts: \(error.localizedDescription)"
            
            // En cas d'erreur, essayer de charger depuis le cache même expiré
            await loadFromExpiredCache(context: context)
        }
        
        self.isLoading = false
    }
    
    /// En cas d'erreur API, charger depuis le cache même si expiré
    private func loadFromExpiredCache(context: ModelContext) async {
        do {
            let descriptor = FetchDescriptor<Account>(sortBy: [SortDescriptor(\.accountNumber)])
            let cachedAccounts = try context.fetch(descriptor)
            
            if !cachedAccounts.isEmpty {
                self.accounts = cachedAccounts
                self.totalValue = cachedAccounts.reduce(0) { $0 + $1.value }
                
                // Trouver la date du dernier snapshot
                let snapshotDescriptor = FetchDescriptor<Snapshot>(
                    sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
                )
                let snapshots = try context.fetch(snapshotDescriptor)
                if let lastSnapshot = snapshots.first {
                    self.lastRefreshDate = lastSnapshot.timestamp
                    let hoursAgo = Date().timeIntervalSince(lastSnapshot.timestamp) / 3600
                    print("📱 Using expired cache from \(String(format: "%.1f", hoursAgo))h ago (offline mode)")
                }
            }
        } catch {
            print("❌ Failed to load expired cache: \(error)")
        }
    }
    
    /// Supprime les anciens comptes pour éviter les doublons
    private func clearOldAccounts(context: ModelContext) async {
        do {
            // Supprimer les anciens comptes
            let accountDescriptor = FetchDescriptor<Account>()
            let oldAccounts = try context.fetch(accountDescriptor)
            for account in oldAccounts {
                context.delete(account)
            }
            
            // Supprimer les anciennes positions
            let positionDescriptor = FetchDescriptor<Position>()
            let oldPositions = try context.fetch(positionDescriptor)
            for position in oldPositions {
                context.delete(position)
            }
            
            // Garder seulement les 20 derniers snapshots (environ 10 jours d'historique à 2 mises à jour/jour)
            let snapshotDescriptor = FetchDescriptor<Snapshot>(
                sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
            )
            let allSnapshots = try context.fetch(snapshotDescriptor)
            if allSnapshots.count > 20 {
                for snapshot in allSnapshots.dropFirst(20) {
                    context.delete(snapshot)
                }
            }
            
        } catch {
            print("❌ Failed to clear old data: \(error)")
        }
    }

    /// Point d'entrée principal
    func loadFromAuthService(context: ModelContext, forceRefresh: Bool = false) async {
        await loadAccountsSmartly(context: context, forceRefresh: forceRefresh)
    }
    
    /// Force un nouveau login et reload
    func forceRelogin(username: String, password: String, context: ModelContext) async {
        print("🔄 Force relogin started")
        do {
            try await AuthService.shared.login(user: username, pass: password)
            guard let newJWT = AuthService.shared.retrieveJWT() else {
                throw NSError(domain: "Auth", code: 0, userInfo: [NSLocalizedDescriptionKey: "Failed to retrieve new JWT"])
            }
            print("✅ New JWT obtained")
            await load(jwt: newJWT, context: context)
        } catch {
            print("❌ Force relogin failed: \(error)")
            self.errorMessage = "Relogin failed: \(error.localizedDescription)"
        }
    }
    
    /// Informations sur le cache adaptées aux données financières
    var cacheInfo: String {
        if let lastRefresh = lastRefreshDate {
            let hoursAgo = Date().timeIntervalSince(lastRefresh) / 3600
            if hoursAgo < 1 {
                let minutesAgo = Int(Date().timeIntervalSince(lastRefresh) / 60)
                return "Updated \(minutesAgo)min ago"
            } else {
                return "Updated \(String(format: "%.1f", hoursAgo))h ago"
            }
        }
        return "No update data"
    }
    
    /// Indique si les données sont probablement à jour
    var isDataFresh: Bool {
        guard let lastRefresh = lastRefreshDate else { return false }
        let hoursAgo = Date().timeIntervalSince(lastRefresh) / 3600
        return hoursAgo < 6 // Considéré frais si < 6h
    }
}g
