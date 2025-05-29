// Fix 1: Oddo/Services/APIService.swift (CORRECTED - Remove APIError enum)

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
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        
        print("→ Requesting accounts with stats from: \(accountsURL)")
        
        let (data, response) = try await URLSession.shared.data(for: req)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            print("❌ Response is not HTTPURLResponse")
            throw URLError(.badServerResponse)
        }
        
        print("→ HTTP Status: \(httpResponse.statusCode)")
        
        guard (200...299).contains(httpResponse.statusCode) else {
            print("❌ Bad status code: \(httpResponse.statusCode)")
            if let responseString = String(data: data, encoding: .utf8) {
                print("❌ Response body: \(responseString)")
            }
            throw URLError(.badServerResponse)
        }
        
        // NOUVELLE VÉRIFICATION: Détecter si on reçoit du HTML au lieu de JSON
        if let responseString = String(data: data, encoding: .utf8) {
            if responseString.contains("<br />") || responseString.contains("<b>Warning</b>") || responseString.hasPrefix("<!DOCTYPE") {
                print("❌ Server returned HTML instead of JSON")
                print("❌ HTML Response: \(responseString.prefix(500))")
                throw APIError(.serverError, "Server configuration error - check storage permissions")
            }
            
            // Log seulement un aperçu du JSON valide
            if responseString.hasPrefix("{") || responseString.hasPrefix("[") {
                print("→ JSON Response preview: \(responseString.prefix(200))...")
            }
        }
        
        print("→ Response data size: \(data.count) bytes")
        
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
                    // Si les données sont corrompues, c'est probablement du HTML
                    if let responseString = String(data: data, encoding: .utf8) {
                        if responseString.contains("<br />") {
                            throw APIError(.serverError, "Server error - check logs")
                        }
                    }
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
