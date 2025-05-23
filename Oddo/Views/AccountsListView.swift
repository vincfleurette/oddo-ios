import SwiftUI

struct AccountsListView: View {
    @StateObject private var vm = AccountsListViewModel()

    var body: some View {
        NavigationStack {
            VStack {
                HStack {
                    Text(NSLocalizedString("TotalBalance", comment: ""))
                    Spacer()
                    Text("\(vm.totalValue, specifier: "%.2f") €").bold()
                }
                .padding()
                List(vm.accounts) { account in
                    NavigationLink(account.label, value: account)
                }
                .navigationDestination(for: Account.self) { acc in
                    AccountDetailView(account: acc)
                }
            }
            .task { await vm.load() }
        }
    }
}
