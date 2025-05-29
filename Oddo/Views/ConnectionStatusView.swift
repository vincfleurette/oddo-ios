//
//  ConnectionStatusView.swift
//  Oddo
//
//  Created by Vincent Fleurette on 29/05/2025.
//

import SwiftUI

struct ConnectionStatusView: View {
    @StateObject private var networkMonitor = NetworkMonitor()
    
    var body: some View {
        if !networkMonitor.isConnected {
            HStack {
                Image(systemName: "wifi.slash")
                    .foregroundColor(.red)
                Text("Pas de connexion")
                    .font(.caption)
                    .foregroundColor(.red)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.red.opacity(0.1))
            .cornerRadius(8)
        }
    }
}

// Moniteur de réseau
class NetworkMonitor: ObservableObject {
    @Published var isConnected = true
    
    init() {
        // Implémentation basique - vous pouvez utiliser Network framework pour plus de précision
        startMonitoring()
    }
    
    private func startMonitoring() {
        Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { _ in
            // Test simple de connectivité
            Task {
                do {
                    let url = URL(string: "https://www.google.com")!
                    let (_, response) = try await URLSession.shared.data(from: url)
                    if let httpResponse = response as? HTTPURLResponse {
                        await MainActor.run {
                            self.isConnected = httpResponse.statusCode == 200
                        }
                    }
                } catch {
                    await MainActor.run {
                        self.isConnected = false
                    }
                }
            }
        }
    }
}
