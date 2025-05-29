// Fix: Oddo/Services/CacheService.swift - MODÈLE FLEXIBLE POUR VOTRE API

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
    
    /// Récupère les informations du cache serveur avec debug
    func getCacheInfo(jwt: String) async throws -> CacheInfo {
        var req = URLRequest(url: baseURL.appendingPathComponent("cache/info"))
        req.httpMethod = "GET"
        req.setValue("Bearer \(jwt)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        
        let (data, response) = try await URLSession.shared.data(for: req)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            print("❌ Cache info HTTP status: \(httpResponse.statusCode)")
            throw URLError(.badServerResponse)
        }
        
        // DEBUG: Voir la réponse JSON brute
        if let jsonString = String(data: data, encoding: .utf8) {
            print("🔍 Raw cache info response: \(jsonString)")
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
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        
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
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        
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

// MARK: - Models (ADAPTÉS À VOTRE API ACTUELLE)

struct CacheInfo: Codable {
    let key: String?
    let timestamp: String?
    let age: Int?
    let ageHuman: String?
    let ttl: Int?
    let isExpired: Bool?
    let expiresIn: Int?
    let expiresInHuman: String?
    let size: Int?
    let message: String?
    
    // Propriétés calculées pour compatibilité avec l'interface
    var cachePath: String? {
        return key ?? "cache_info"
    }
    
    var cacheExists: Bool {
        return timestamp != nil && !timestamp!.isEmpty
    }
    
    var cacheTtl: Int? {
        return ttl ?? 21600
    }
    
    var cacheTtlHuman: String? {
        let ttlValue = ttl ?? 21600
        let hours = ttlValue / 3600
        let minutes = (ttlValue % 3600) / 60
        return "\(hours)h \(minutes)m"
    }
    
    var cacheTimestamp: String? {
        return timestamp
    }
    
    var cacheAge: Int? {
        return age
    }
    
    var cacheAgeHuman: String? {
        return ageHuman
    }
    
    var accountsCount: Int? {
        // Cette info n'est pas disponible dans la réponse actuelle
        return nil
    }
    
    var fileSizeBytes: Int? {
        return size
    }
    
    var fileSizeHuman: String? {
        guard let bytes = size else { return nil }
        return formatFileSize(bytes)
    }
    
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
    
    // Helper pour formater la taille des fichiers
    private func formatFileSize(_ bytes: Int) -> String {
        let units = ["B", "KB", "MB", "GB"]
        var value = Double(bytes)
        var unitIndex = 0
        
        while value >= 1024 && unitIndex < units.count - 1 {
            value /= 1024
            unitIndex += 1
        }
        
        return String(format: "%.1f %@", value, units[unitIndex])
    }
}

struct CacheOperationResult: Codable {
    let success: Bool
    let message: String
    let cachePath: String?
    let timestamp: String
    let accountsCount: Int?
    let userId: String?
}
