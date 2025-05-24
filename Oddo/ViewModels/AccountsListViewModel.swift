import SwiftUI
import SwiftData

extension String {
    func base64Decoded() -> Data? {
        var base64 = self
        // Ajouter le padding si nécessaire
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

    /// Charge les comptes avec le JWT fourni.
    func load(jwt: String, context: ModelContext) async {
        print("🔄 Starting load with JWT: \(jwt.prefix(20))...")
        isLoading = true
        errorMessage = nil
        
        do {
            print("→ Tentative de chargement des comptes")
            let dtos = try await APIService.shared.fetchAccounts(jwt: jwt)
            print("→ Comptes reçus: \(dtos.count)")
            
            // Debug: afficher les DTOs reçus
            for (index, dto) in dtos.enumerated() {
                print("   DTO[\(index)]: \(dto.accountNumber) - \(dto.label) - Value: \(dto.value) - Positions: \(dto.positions.count)")
            }
            
            var models: [Account] = []
            for dto in dtos {
                print("→ Traitement du compte: \(dto.accountNumber)")
                print("   ↳ Label: '\(dto.label)'")
                print("   ↳ Value: \(dto.value)")
                print("   ↳ Positions incluses: \(dto.positions.count)")
                
                // Créer le compte d'abord
                let acc = Account(accountNumber: dto.accountNumber, label: dto.label, value: dto.value, positions: [])
                
                // Créer les positions et les associer au compte
                let positions = dto.positions.map { posDTO in
                    print("     Position: \(posDTO.libInstrument) - Value: \(posDTO.valeurMarcheDeviseSecurite)")
                    return Position(dto: posDTO, account: acc)
                }
                acc.positions = positions
                
                print("   ↳ Account créé avec \(acc.positions.count) positions")
                
                // Sauvegarder en base
                context.insert(acc)
                for position in positions {
                    context.insert(position)
                }
                
                // Créer un snapshot
                let snapshot = Snapshot(account: acc)
                context.insert(snapshot)
                
                models.append(acc)
                print("   ↳ Account ajouté aux models. Total models: \(models.count)")
            }
            
            // Sauvegarder le contexte
            do {
                try context.save()
                print("✅ Context saved successfully")
            } catch {
                print("❌ Failed to save context: \(error)")
                throw error
            }
            
            // Debug: vérifier les models avant assignation
            print("📊 Models créés:")
            for (index, model) in models.enumerated() {
                print("   Model[\(index)]: \(model.accountNumber) - Value: \(model.value)")
            }
            
            let calculatedTotal = models.reduce(0) { $0 + $1.value }
            print("📊 Total calculé: \(calculatedTotal)")
            
            // Assignation sur le main thread
            self.accounts = models
            self.totalValue = calculatedTotal
            print("✅ UI Updated - Accounts: \(self.accounts.count), Total: \(self.totalValue)")
            
        } catch {
            print("⚠️ Error loading accounts: \(error.localizedDescription)")
            self.errorMessage = "Failed to load accounts: \(error.localizedDescription)"
            dump(error)
        }
        
        self.isLoading = false
        print("🏁 Loading finished. Final state - Accounts: \(self.accounts.count), Total: \(self.totalValue)")
    }

    /// Variante : charge automatiquement le JWT depuis le service d'authentification.
    func loadFromAuthService(context: ModelContext) async {
        guard let jwt = AuthService.shared.retrieveJWT() else {
            print("❌ JWT manquant, authentification requise.")
            self.errorMessage = "Authentication required"
            return
        }
        
        // Debug: vérifier l'âge du JWT (version simplifiée)
        let jwtParts = jwt.split(separator: ".")
        if jwtParts.count == 3 {
            let payload = String(jwtParts[1])
            if let payloadData = payload.base64Decoded(),
               let jwtJson = try? JSONSerialization.jsonObject(with: payloadData, options: []) as? [String: Any],
               let exp = jwtJson["exp"] as? TimeInterval {
                let expirationDate = Date(timeIntervalSince1970: exp)
                let now = Date()
                print("🕐 JWT expires at: \(expirationDate)")
                print("🕐 Current time: \(now)")
                print("🕐 JWT expired: \(expirationDate < now)")
                
                if expirationDate < now {
                    print("⚠️ JWT is expired, should re-login")
                    self.errorMessage = "Token expired, please re-login"
                    return
                }
            }
        }
        
        await load(jwt: jwt, context: context)
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
}
