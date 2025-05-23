import Foundation
import LocalAuthentication

class AuthService {
    static let shared = AuthService()
    private let keychainKey = "OddoJWT"
    var baseURL: URL {
        let urlString = Bundle.main.object(forInfoDictionaryKey: "API_BASE_URL") as? String ?? "https://fallback.url"
        return URL(string: urlString)!
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
        let (data, _) = try await URLSession.shared.data(for: req)
        let resp = try JSONDecoder().decode([String:String].self, from: data)
        guard let jwt = resp["jwt"] else { throw NSError() }
        try saveJWT(jwt)
    }

    private func saveJWT(_ jwt: String) throws {
        let data = Data(jwt.utf8)
        let query: [String:Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: keychainKey,
            kSecValueData as String: data
        ]
        SecItemAdd(query as CFDictionary, nil)
    }

    func retrieveJWT() -> String? {
        let query: [String:Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: keychainKey,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: AnyObject?
        SecItemCopyMatching(query as CFDictionary, &result)
        if let data = result as? Data {
            return String(data: data, encoding: .utf8)
        }
        return nil
    }
}
