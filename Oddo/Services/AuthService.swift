import Foundation
import LocalAuthentication

class AuthService {
    static let shared = AuthService()
    private let keychainKey = "OddoJWT"
    
    var baseURL: URL {
        let urlString = Bundle.main.object(forInfoDictionaryKey: "API_BASE_URL") as? String ?? ""
        guard let url = URL(string: urlString), !urlString.isEmpty else {
            fatalError("API_BASE_URL mal configuré ou non présente dans Info.plist")
        }
        return url
    }
    
    private var loginUrl: URL {
        baseURL.appendingPathComponent("login")
    }

    func login(user: String, pass: String) async throws {
        var req = URLRequest(url: loginUrl)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body = ["user": user, "pass": pass]
        req.httpBody = try JSONEncoder().encode(body)
        
        let (data, response) = try await URLSession.shared.data(for: req)
        
        // Vérifier la réponse HTTP
        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            print("❌ Login failed with status: \(httpResponse.statusCode)")
            if let responseString = String(data: data, encoding: .utf8) {
                print("❌ Response: \(responseString)")
            }
            throw URLError(.userAuthenticationRequired)
        }
        
        let resp = try JSONDecoder().decode([String:String].self, from: data)
        guard let jwt = resp["jwt"] else {
            throw NSError(domain: "Auth", code: 0, userInfo: [NSLocalizedDescriptionKey: "JWT token missing"])
        }
        
        try saveJWT(jwt)
        print("✅ Login successful, JWT saved")
    }

    private func saveJWT(_ jwt: String) throws {
        let data = Data(jwt.utf8)
        
        // Supprimer l'ancien token s'il existe
        deleteJWT()
        
        let query: [String:Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: keychainKey,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlocked
        ]
        
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            print("❌ Failed to save JWT to keychain: \(status)")
            throw NSError(domain: "Keychain", code: Int(status), userInfo: [NSLocalizedDescriptionKey: "Failed to save JWT"])
        }
        
        print("✅ JWT saved to keychain")
    }

    func retrieveJWT() -> String? {
        let query: [String:Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: keychainKey,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess else {
            print("❌ Failed to retrieve JWT: \(status)")
            return nil
        }
        
        if let data = result as? Data {
            let jwt = String(data: data, encoding: .utf8)
            print("✅ JWT retrieved from keychain")
            return jwt
        }
        return nil
    }
    
    func deleteJWT() {
        let query: [String:Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: keychainKey
        ]
        
        SecItemDelete(query as CFDictionary)
    }
    
    func logout() {
        deleteJWT()
        print("✅ User logged out")
    }
}
