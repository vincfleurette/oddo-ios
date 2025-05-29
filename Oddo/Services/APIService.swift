// Oddo/Services/APIService.swift

import Foundation

final class APIService {
    static let shared = APIService()
    
    // JSONDecoder configuré pour gérer les dates de votre API
    private lazy var jsonDecoder: JSONDecoder = {
        let decoder = JSONDecoder()
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        dateFormatter.timeZone = TimeZone(secondsFromGMT: 0) // UTC
        decoder.dateDecodingStrategy = .formatted(dateFormatter)
        return decoder
    }()
    
    /// Propriété calculée pour la base URL, crash explicite si mauvaise config
    var baseURL: URL {
        guard let urlString = Bundle.main.object(forInfoDictionaryKey: "API_BASE_URL") as? String,
              let url = URL(string: urlString) else {
            fatalError("API_BASE_URL mal configuré ou non présent dans Info.plist")
        }
        return url
    }
    
    var accountsURL: URL { baseURL.appendingPathComponent("accounts") }

    /// Récupère les comptes avec statistiques de performance
    func fetchAccountsWithStats(jwt: String) async throws -> AccountsResponse {
        var req = URLRequest(url: accountsURL)
        req.httpMethod = "GET"
        req.setValue("Bearer \(jwt)", forHTTPHeaderField: "Authorization")
        
        print("→ Requesting accounts with stats from: \(accountsURL)")
        
        let (data, response) = try await URLSession.shared.data(for: req)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            print("❌ Response is not HTTPURLResponse")
            throw URLError(.badServerResponse)
        }
        
        print("→ HTTP Status: \(httpResponse.statusCode)")
        print("→ Response headers: \(httpResponse.allHeaderFields)")
        
        guard (200...299).contains(httpResponse.statusCode) else {
            print("❌ Bad status code: \(httpResponse.statusCode)")
            if let responseString = String(data: data, encoding: .utf8) {
                print("❌ Response body: \(responseString)")
            }
            throw URLError(.badServerResponse)
        }
        
        print("→ Response data size: \(data.count) bytes")
        
        // Log du JSON complet pour debug
        if let jsonString = String(data: data, encoding: .utf8) {
            print("→ JSON Response preview: \(jsonString.prefix(500))...")
        }
        
        // Si la réponse est vide, on va debug l'autorisation
        if data.count <= 10 {
            print("⚠️ Response trop petite, possible problème d'autorisation")
            print("→ JWT utilisé: \(jwt.prefix(50))...")
        }
        
        do {
            // Utiliser le decoder configuré avec le DateFormatter
            let accountsResponse = try jsonDecoder.decode(AccountsResponse.self, from: data)
            print("→ Successfully decoded \(accountsResponse.accounts.count) accounts with portfolio stats")
            
            // Log des statistiques pour vérification
            let portfolio = accountsResponse.portfolio
            print("   Portfolio total: \(portfolio.formatted.totalValue)")
            print("   Portfolio performance: \(portfolio.formatted.weightedPerformance)")
            print("   Top performer: \(portfolio.topPerformers.first?.libInstrument ?? "N/A")")
            
            return accountsResponse
        } catch {
            print("❌ JSON Decoding error: \(error)")
            
            // Plus de détails sur l'erreur de décodage
            if let decodingError = error as? DecodingError {
                switch decodingError {
                case .typeMismatch(let type, let context):
                    print("❌ Type mismatch: expected \(type), context: \(context)")
                case .valueNotFound(let type, let context):
                    print("❌ Value not found: \(type), context: \(context)")
                case .keyNotFound(let key, let context):
                    print("❌ Key not found: \(key), context: \(context)")
                case .dataCorrupted(let context):
                    print("❌ Data corrupted: \(context)")
                @unknown default:
                    print("❌ Unknown decoding error: \(error)")
                }
            }
            
            throw error
        }
    }
    
    /// Méthode legacy pour compatibilité (retourne juste les comptes)
    func fetchAccounts(jwt: String) async throws -> [AccountDTO] {
        let response = try await fetchAccountsWithStats(jwt: jwt)
        return response.accounts
    }
}
