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
    
    // MARK: - Get Accounts (exemple)
    func fetchAccounts(jwt: String) async throws -> [AccountDTO] {
        var req = URLRequest(url: accountsURL)
        req.httpMethod = "GET"
        req.setValue("Bearer \(jwt)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await URLSession.shared.data(for: req)
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw URLError(.badServerResponse)
        }
        return try JSONDecoder().decode([AccountDTO].self, from: data)
    }
    
    // MARK: - Get Positions (exemple)
    func fetchPositions(accountNumber: String) async throws -> [PositionDTO] {
        guard let jwt = AuthService.shared.retrieveJWT() else {
            throw NSError(domain: "Auth", code: 1, userInfo: [NSLocalizedDescriptionKey: "Missing JWT"])
        }
        var req = URLRequest(url: baseURL.appendingPathComponent("accounts/positions"))
        req.httpMethod = "POST"
        req.setValue("Bearer \(jwt)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONEncoder().encode(["accountNumber": accountNumber])
        let (data, response) = try await URLSession.shared.data(for: req)
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw URLError(.badServerResponse)
        }
        return try JSONDecoder().decode([PositionDTO].self, from: data)
    }
}
