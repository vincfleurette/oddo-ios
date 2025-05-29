// Oddo/Services/CacheService.swift

import Foundation

final class CacheService {
    static let shared = CacheService()
    
    private var baseURL: URL {
        guard let urlString = Bundle.main.object(forInfoDictionaryKey: "API_BASE_URL") as? String,
              let url = URL(string: urlString) else {
            fatalError("API_BASE_URL mal configuré ou non présent dans Info.plist")
        }
        return url
    }
    
    // MARK: - Cache Info
    
    /// Récupère les informations du cache serveur
    func getCacheInfo(jwt: String) async throws -> CacheInfo {
        var req = URLRequest(url: baseURL.appendingPathComponent("cache/info"))
        req.httpMethod = "GET"
        req.setValue("Bearer \(jwt)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await URLSession.shared.data(for: req)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            throw URLError(.badServerResponse)
        }
        
        let decoder = JSONDecoder()
        return try decoder.decode(CacheInfo.self, from: data)
    }
    
    // MARK: - Cache Invalidation
    
    /// Invalide le cache sur le serveur
    func invalidateCache(jwt: String) async throws -> CacheOperationResult {
        var req = URLRequest(url: baseURL.appendingPathComponent("cache"))
        req.httpMethod = "DELETE"
        req.setValue("Bearer \(jwt)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await URLSession.shared.data(for: req)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            throw URLError(.badServerResponse)
        }
        
        let decoder = JSONDecoder()
        return try decoder.decode(CacheOperationResult.self, from: data)
    }
    
    // MARK: - Cache Refresh
    
    /// Force le refresh du cache sur le serveur
    func refreshCache(jwt: String) async throws -> CacheOperationResult {
        var req = URLRequest(url: baseURL.appendingPathComponent("cache/refresh"))
        req.httpMethod = "POST"
        req.setValue("Bearer \(jwt)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await URLSession.shared.data(for: req)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            throw URLError(.badServerResponse)
        }
        
        let decoder = JSONDecoder()
        return try decoder.decode(CacheOperationResult.self, from: data)
    }
}

// MARK: - Models

struct CacheInfo: Codable {
    let cachePath: String
    let cacheExists: Bool
    let cacheTtl: Int
    let cacheTtlHuman: String
    let cacheTimestamp: String?
    let cacheAge: Int?
    let cacheAgeHuman: String?
    let isExpired: Bool?
    let expiresIn: Int?
    let expiresInHuman: String?
    let accountsCount: Int?
    let fileSizeBytes: Int?
    let fileSizeHuman: String?
    
    var isValid: Bool {
        guard let isExpired = isExpired else { return false }
        return !isExpired && cacheExists
    }
    
    var statusDescription: String {
        if !cacheExists {
            return "No cache"
        } else if let isExpired = isExpired {
            return isExpired ? "Expired" : "Valid"
        } else {
            return "Unknown"
        }
    }
}

struct CacheOperationResult: Codable {
    let success: Bool
    let message: String
    let cachePath: String?
    let timestamp: String
    let accountsCount: Int?
}
