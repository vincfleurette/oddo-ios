import SwiftUI
import SwiftData

@MainActor
class AccountDetailViewModel: ObservableObject {
    @Published var positions: [Position] = []
    @Published var snapshots: [Snapshot] = []

    func load(account: Account, context: ModelContext) async {
        positions = account.positions

        let accNumber = account.accountNumber
        let descriptor = FetchDescriptor<Snapshot>(
            predicate: #Predicate { $0.accountNumber == accNumber },
            sortBy: [SortDescriptor(\.timestamp)]
        )
        do {
            snapshots = try context.fetch(descriptor)
        } catch {
            snapshots = []
        }
    }
    
    
}
