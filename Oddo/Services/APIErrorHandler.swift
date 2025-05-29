// Fix 2: Oddo/Services/APIErrorHandler.swift (CORRECTED)
import Foundation

struct APIError: LocalizedError {
    let code: APIErrorCode
    let message: String
    let underlyingError: Error?
    
    enum APIErrorCode {
        case networkError
        case authenticationFailed
        case serverError
        case dataCorrupted
        case cacheExpired
        case noData
    }
    
    init(_ code: APIErrorCode, _ message: String, underlyingError: Error? = nil) {
        self.code = code
        self.message = message
        self.underlyingError = underlyingError
    }
    
    var errorDescription: String? {
        switch code {
        case .networkError:
            return "Erreur de connexion. Vérifiez votre connexion internet."
        case .authenticationFailed:
            return "Authentification échouée. Veuillez vous reconnecter."
        case .serverError:
            return "Erreur serveur: \(message)"
        case .dataCorrupted:
            return "Données corrompues. Veuillez rafraîchir."
        case .cacheExpired:
            return "Cache expiré. Rafraîchissement en cours..."
        case .noData:
            return "Aucune donnée disponible."
        }
    }
    
    static func from(_ error: Error) -> APIError {
        if let urlError = error as? URLError {
            switch urlError.code {
            case .notConnectedToInternet, .networkConnectionLost:
                return APIError(.networkError, "Pas de connexion internet", underlyingError: error)
            case .userAuthenticationRequired:
                return APIError(.authenticationFailed, "Authentification requise", underlyingError: error)
            default:
                return APIError(.networkError, urlError.localizedDescription, underlyingError: error)
            }
        }
        
        if let apiError = error as? APIError {
            return apiError
        }
        
        return APIError(.serverError, error.localizedDescription, underlyingError: error)
    }
}
