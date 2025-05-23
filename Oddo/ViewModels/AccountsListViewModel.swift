import SwiftUI

class AccountsListViewModel: ObservableObject {
    @Published var accounts: [Account] = []
    @Published var totalValue: Double = 0

    func load() async {
        do {
            let dtos = try await APIService.shared.fetchAccounts(jwt: jwt)
            var models: [Account] = []
            for dto in dtos {
                let posDTOs = try await APIService.shared.fetchPositions(accountNumber: dto.accountNumber)
                let positions = posDTOs.map { Position(dto: $0) }
                let acc = Account(accountNumber: dto.accountNumber, label: dto.label, value: dto.value, positions: positions)
                models.append(acc)
                Snapshot(account: acc)
            }
            DispatchQueue.main.async {
                self.accounts = models
                self.totalValue = models.reduce(0) { $0 + $1.value }
            }
        } catch {
            print("Error loading accounts: \(error)")
        }
    }
}
