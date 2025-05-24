import SwiftUI

@MainActor
class AccountsListViewModel: ObservableObject {
    @Published var accounts: [Account] = []
    @Published var totalValue: Double = 0

    /// Charge les comptes avec le JWT fourni.
    func load(jwt: String) async {
        do {
            print("→ Tentative de chargement des comptes")
            let dtos = try await APIService.shared.fetchAccounts(jwt: jwt)
            print("→ Comptes reçus: \(dtos.count)")
            var models: [Account] = []
            for dto in dtos {
                print("→ Chargement des positions pour account: \(dto.accountNumber)")
                let posDTOs = try await APIService.shared.fetchPositions(for: dto.accountNumber, jwt: jwt)
                print("   ↳ Positions reçues: \(posDTOs.count)")
                let positions = posDTOs.map { Position(dto: $0) }
                let acc = Account(accountNumber: dto.accountNumber, label: dto.label, value: dto.value, positions: positions)
                models.append(acc)
                _ = Snapshot(account: acc)
            }
            self.accounts = models
            self.totalValue = models.reduce(0) { $0 + $1.value }
            print("→ Succès, comptes chargés : \(models.count)")
        } catch {
            print("⚠️ Error loading accounts: \(error.localizedDescription)")
            // Optionnel : affiche tout l’erreur
            dump(error)
        }
    }

    /// Variante : charge automatiquement le JWT depuis le service d’authentification.
    func loadFromAuthService() async {
        guard let jwt = AuthService.shared.retrieveJWT() else {
            print("JWT manquant, authentification requise.")
            return
        }
        await load(jwt: jwt)
    }
}
