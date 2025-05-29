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
    @Published var serverCacheInfo: CacheInfo?
    @Published var portfolioStats: PortfolioStats?
    
    private var lastRefreshDate: Date?
    private let cacheValidityDuration: TimeInterval = 6 * 3600 // 6 heures

    /// Charge les informations du cache serveur
    func loadServerCacheInfo() async {
        guard let jwt = AuthService.shared.retrieveJWT() else { return }
        
        do {
            let info = try await CacheService.shared.getCacheInfo(jwt: jwt)
            self.serverCacheInfo = info
            print("📊 Server cache info loaded successfully")
            if let path = info.cachePath {
                print("   Cache path: \(path)")
            }
            print("   Status: \(info.statusDescription)")
            if let count = info.accountsCount {
                print("   Accounts: \(count)")
            }
        } catch {
            print("❌ Failed to load server cache info: \(error)")
            
            // Créer une info de cache par défaut pour éviter le crash
            self.serverCacheInfo = createDefaultCacheInfo()
            
            // Log détaillé de l'erreur pour debug
            if let decodingError = error as? DecodingError {
                switch decodingError {
                case .keyNotFound(let key, let context):
                    print("❌ Missing key '\(key.stringValue)' in server response")
                    print("❌ Context: \(context)")
                case .dataCorrupted(let context):
                    print("❌ Data corrupted: \(context)")
                default:
                    print("❌ Other decoding error: \(decodingError)")
                }
            }
        }
    }

    /// Crée une info de cache par défaut en cas d'erreur serveur
    private func createDefaultCacheInfo() -> CacheInfo? {
        // Utiliser un dictionnaire simple qui sera converti en CacheInfo
        let defaultData: [String: Any] = [
            "cacheExists": false,
            "cacheTtl": 21600,
            "cacheTtlHuman": "6h 0m",
            "accountsCount": 0,
            "fileSizeBytes": 0,
            "fileSizeHuman": "0 B",
            "message": "Server cache info unavailable"
        ]
        
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: defaultData)
            let decoder = JSONDecoder()
            return try decoder.decode(CacheInfo.self, from: jsonData)
        } catch {
            print("❌ Failed to create default cache info: \(error)")
            return nil
        }
    }

    /// Version robuste de invalidateAllCaches avec fallback
    func invalidateAllCaches(context: ModelContext) async {
        guard let jwt = AuthService.shared.retrieveJWT() else {
            self.errorMessage = "Authentication required"
            return
        }
        
        isLoading = true
        
        do {
            let result = try await CacheService.shared.invalidateCache(jwt: jwt)
            print("🗑️ Server cache invalidation: \(result.message)")
            
            await clearLocalCache(context: context)
            await load(jwt: jwt, context: context)
            
            print("✅ All caches invalidated and data refreshed")
            
        } catch {
            print("❌ Server cache invalidation failed: \(error)")
            
            // Même si le cache serveur échoue, on peut continuer avec le local
            await clearLocalCache(context: context)
            await load(jwt: jwt, context: context)
            
            // Ne pas afficher l'erreur de cache comme critique
            if self.accounts.count > 0 {
                print("✅ Data refreshed despite server cache error")
            } else {
                self.errorMessage = "Failed to refresh data: \(error.localizedDescription)"
            }
        }
        
        isLoading = false
    }
    
    /// Force le refresh du cache serveur
    func forceServerCacheRefresh(context: ModelContext) async {
        guard let jwt = AuthService.shared.retrieveJWT() else {
            self.errorMessage = "Authentication required"
            return
        }
        
        isLoading = true
        
        do {
            let result = try await CacheService.shared.refreshCache(jwt: jwt)
            print("🔄 Server cache refresh: \(result.message)")
            
            await clearLocalCache(context: context)
            await load(jwt: jwt, context: context)
            
            print("✅ Server cache refreshed and data reloaded")
            
        } catch {
            print("❌ Server cache refresh failed: \(error)")
            self.errorMessage = "Failed to refresh server cache: \(error.localizedDescription)"
        }
        
        isLoading = false
    }

    /// Charge les comptes en utilisant le cache intelligent pour données financières
    func loadAccountsSmartly(context: ModelContext, forceRefresh: Bool = false) async {
        await loadServerCacheInfo()
        
        if forceRefresh {
            print("🔄 Force refresh requested")
            await loadFromAPI(context: context)
            return
        }
        
        if await loadFromLocalCache(context: context) {
            print("✅ Using cached data (financial data updates every 12h)")
            return
        }
        
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
            
            let snapshotDescriptor = FetchDescriptor<Snapshot>(
                sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
            )
            let recentSnapshots = try context.fetch(snapshotDescriptor)
            
            if let lastSnapshot = recentSnapshots.first {
                let timeSinceLastUpdate = Date().timeIntervalSince(lastSnapshot.timestamp)
                let hoursAgo = timeSinceLastUpdate / 3600
                
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
            // Essayer d'abord la nouvelle méthode avec stats
            if let accountsResponse = try? await APIService.shared.fetchAccountsWithStats(jwt: jwt) {
                print("→ Received \(accountsResponse.accounts.count) accounts with portfolio stats")
                
                // Stocker les statistiques du portefeuille
                self.portfolioStats = accountsResponse.portfolio
                
                await clearLocalCache(context: context)
                
                var models: [Account] = []
                for dto in accountsResponse.accounts {
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
                
                await loadServerCacheInfo()
                
                print("✅ Successfully loaded \(models.count) accounts with stats, total: \(String(format: "%.2f", totalValue))€")
                print("📊 Portfolio performance: \(accountsResponse.portfolio.formatted.weightedPerformance)")
                
            } else {
                // Fallback vers l'ancienne méthode
                print("→ Using fallback method without stats")
                let dtos = try await APIService.shared.fetchAccounts(jwt: jwt)
                print("→ Received \(dtos.count) accounts (legacy mode)")
                
                await clearLocalCache(context: context)
                
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
                
                await loadServerCacheInfo()
                
                print("✅ Successfully loaded \(models.count) accounts (legacy), total: \(String(format: "%.2f", totalValue))€")
            }
            
        } catch {
            print("⚠️ Error loading accounts: \(error.localizedDescription)")
            self.errorMessage = "Failed to load accounts: \(error.localizedDescription)"
            
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
    
    /// Vide le cache local
    private func clearLocalCache(context: ModelContext) async {
        do {
            let accountDescriptor = FetchDescriptor<Account>()
            let oldAccounts = try context.fetch(accountDescriptor)
            for account in oldAccounts {
                context.delete(account)
            }
            
            let positionDescriptor = FetchDescriptor<Position>()
            let oldPositions = try context.fetch(positionDescriptor)
            for position in oldPositions {
                context.delete(position)
            }
            
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
            print("❌ Failed to clear local cache: \(error)")
        }
    }

    func loadFromAuthService(context: ModelContext, forceRefresh: Bool = false) async {
        await loadAccountsSmartly(context: context, forceRefresh: forceRefresh)
    }
    
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
    
    var localCacheInfo: String {
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
    
    var isDataFresh: Bool {
        guard let lastRefresh = lastRefreshDate else { return false }
        let hoursAgo = Date().timeIntervalSince(lastRefresh) / 3600
        return hoursAgo < 6
    }
    
    var combinedCacheStatus: String {
        let localStatus = localCacheInfo
        
        if let serverCache = serverCacheInfo {
            let serverStatus = serverCache.statusDescription
            return "\(localStatus) • Server: \(serverStatus)"
        }
        
        return localStatus
    }
}
