import SwiftUI
import SwiftData

struct AccountDetailView: View {
    let account: Account
    @Environment(\.modelContext) private var context
    @StateObject private var vm = AccountDetailViewModel()

    var body: some View {
        List {
            ForEach(vm.positions) { pos in
                HStack {
                    VStack(alignment: .leading) {
                        Text(pos.libInstrument).font(.headline)
                        Text(pos.isinCode).font(.caption)
                    }
                    Spacer()
                    Text("\(pos.valeurMarcheDeviseSecurite, specifier: "%.2f") €")
                }
            }
        }
        .navigationTitle(account.label)
        .toolbar {
            NavigationLink(NSLocalizedString("HistoryTitle", comment: "")) {
                HistoryChartView(snapshots: vm.snapshots)
            }
        }
        .task {
            await vm.load(account: account, context: context)
        }
    }
}
