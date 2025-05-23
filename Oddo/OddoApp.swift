import SwiftUI
import SwiftData

@main
struct OddoAppApp: App {
    var body: some Scene {
        WindowGroup {
            LoginView()
        }
        .modelContainer(for: [Account.self, Snapshot.self])
    }
}
