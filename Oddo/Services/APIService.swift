// Oddo/Services/APIService.swift

import Foundation

final class APIService {
    static let shared = APIService()
    
    /// Propriété calculée pour la base URL, crash explicite si mauvaise config
    var baseURL: URL {
        guard let urlString = Bundle.main.object(forInfoDictionaryKey: "API_BASE_URL") as? String,
              let url = URL(string: urlString) else {
            fatalError("API_BASE_URL mal configuré ou non présent dans Info.plist")
        }
        return url
    }
    
    var loginURL: URL { baseURL.appendingPathComponent("login") }
    var accountsURL: URL { baseURL.appendingPathComponent("accounts") }
    // Ajoute d'autres endpoints si besoin, exemple :
    // var positionsURL: URL { baseURL.appendingPathComponent("accounts/positions") }

    // MARK: - Login
    func login(user: String, pass: String) async throws -> String {
        var req = URLRequest(url: loginURL)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body = ["user": user, "pass": pass]
        req.httpBody = try JSONEncoder().encode(body)
        
        let (data, response) = try await URLSession.shared.data(for: req)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        guard (200...299).contains(httpResponse.statusCode) else {
            throw URLError(.badServerResponse)
        }
        // Adapter le parsing selon la réponse réelle de ton API
        let resp = try JSONDecoder().decode([String:String].self, from: data)
        guard let jwt = resp["jwt"] else {
            throw NSError(domain: "Auth", code: 0, userInfo: [NSLocalizedDescriptionKey: "JWT token missing"])
        }
        return jwt
    }
    
    func fetchAccounts(jwt: String) async throws -> [AccountDTO] {
        var req = URLRequest(url: accountsURL)
        req.httpMethod = "GET"
        req.setValue("Bearer \(jwt)", forHTTPHeaderField: "Authorization")
        
        print("→ Requesting accounts from: \(accountsURL)")
        
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
        
        // Vérifiez le JSON avant de décoder
        if let jsonString = String(data: data, encoding: .utf8) {
            print("→ JSON Response: \(jsonString)")
        }
        
        do {
            let accounts = try JSONDecoder().decode([AccountDTO].self, from: data)
            print("→ Successfully decoded \(accounts.count) accounts")
            return accounts
        } catch {
            print("❌ JSON Decoding error: \(error)")
            throw error
        }
    }
    
    // MARK: - Get Positions (exemple)
    func fetchPositions(for accountNumber: String, jwt: String) async throws -> [PositionDTO] {
        // Votre URL pour les positions
        let positionsURL = URL(string: "https://oddo.fleurette.me/positions/\(accountNumber)")!
        
        var req = URLRequest(url: positionsURL)
        req.httpMethod = "GET"
        req.setValue("Bearer \(jwt)", forHTTPHeaderField: "Authorization")
        
        print("→ Requesting positions from: \(positionsURL)")
        
        let (data, response) = try await URLSession.shared.data(for: req)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            print("❌ Response is not HTTPURLResponse")
            throw URLError(.badServerResponse)
        }
        
        print("→ Positions HTTP Status: \(httpResponse.statusCode)")
        print("→ Positions Response headers: \(httpResponse.allHeaderFields)")
        
        guard (200...299).contains(httpResponse.statusCode) else {
            print("❌ Bad status code: \(httpResponse.statusCode)")
            if let responseString = String(data: data, encoding: .utf8) {
                print("❌ Response body: \(responseString)")
            }
            throw URLError(.badServerResponse)
        }
        return try JSONDecoder().decode([PositionDTO].self, from: data)
    }
}
