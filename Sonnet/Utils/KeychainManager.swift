import Foundation
import Security

enum KeychainManager {
    private static let service = "com.sonnet.bookkeeping"

    // MARK: - 通用 Keychain 操作

    static func save(_ data: Data, key: String) throws {
        let query: [String: Any] = [
            kSecClass as String:       kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecValueData as String:   data
        ]
        SecItemDelete(query as CFDictionary)
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainError.saveFailed(status)
        }
    }

    static func load(key: String) throws -> Data {
        let query: [String: Any] = [
            kSecClass as String:       kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String:  true,
            kSecMatchLimit as String:  kSecMatchLimitOne
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else {
            throw KeychainError.loadFailed(status)
        }
        return data
    }

    static func delete(key: String) {
        let query: [String: Any] = [
            kSecClass as String:       kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]
        SecItemDelete(query as CFDictionary)
    }

    static func exists(key: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String:       kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String:  false,
            kSecMatchLimit as String:  kSecMatchLimitOne
        ]
        return SecItemCopyMatching(query as CFDictionary, nil) == errSecSuccess
    }

    // MARK: - UserProfile

    static func saveUserProfile(_ profile: UserProfile) throws {
        let data = try JSONEncoder().encode(profile)
        try save(data, key: "user_profile")
    }

    static func loadUserProfile() throws -> UserProfile {
        let data = try load(key: "user_profile")
        return try JSONDecoder().decode(UserProfile.self, from: data)
    }

    static func deleteUserProfile() {
        delete(key: "user_profile")
    }

    // MARK: - OpenRouter API Key

    private static let apiKeyKeychainKey = "openrouter_api_key"

    /// 保存用户自定义 API Key 到 Keychain
    static func saveAPIKey(_ key: String) throws {
        guard let data = key.data(using: .utf8) else {
            throw KeychainError.saveFailed(errSecParam)
        }
        try save(data, key: apiKeyKeychainKey)
    }

    /// 读取 API Key：优先 Keychain 用户自定义，fallback 到 Secrets.plist
    static func loadAPIKey() -> String {
        // 1. 用户自定义 Key（Keychain）
        if let data = try? load(key: apiKeyKeychainKey),
           let key = String(data: data, encoding: .utf8), !key.isEmpty {
            return key
        }
        // 2. Secrets.plist 内置 Key
        if let path = Bundle.main.path(forResource: "Secrets", ofType: "plist"),
           let dict = NSDictionary(contentsOfFile: path),
           let key = dict["OPENROUTER_API_KEY"] as? String, !key.isEmpty {
            return key
        }
        return ""
    }

    /// 删除用户自定义 API Key
    static func deleteAPIKey() {
        delete(key: apiKeyKeychainKey)
    }

    /// 是否已设置用户自定义 Key
    static func hasCustomAPIKey() -> Bool {
        exists(key: apiKeyKeychainKey)
    }
}

enum KeychainError: Error, LocalizedError {
    case saveFailed(OSStatus)
    case loadFailed(OSStatus)

    var errorDescription: String? {
        switch self {
        case .saveFailed(let s): return "Keychain 保存失败 (OSStatus: \(s))"
        case .loadFailed(let s): return "Keychain 读取失败 (OSStatus: \(s))"
        }
    }
}
