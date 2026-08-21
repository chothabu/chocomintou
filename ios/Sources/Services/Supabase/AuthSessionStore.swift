import Foundation
import Security

/// Supabase の認証セッション。
struct AuthSession: Codable, Sendable, Equatable {
    var accessToken: String
    var refreshToken: String
    var expiresAt: Date
    var userId: UUID

    var isExpired: Bool { expiresAt <= Date().addingTimeInterval(60) }
}

/// セッションの保持と永続化。
/// アクセストークンは資格情報なので UserDefaults ではなく Keychain に置く。
actor AuthSessionStore {
    private var session: AuthSession?
    private let keychainKey = "app.chocomint.auth.session"

    init() {
        session = Self.load(key: keychainKey)
    }

    func current() -> AuthSession? { session }

    func accessToken() -> String? {
        guard let session, !session.isExpired else { return nil }
        return session.accessToken
    }

    /// 期限切れでも refresh のために保持している値を返す。
    func refreshToken() -> String? { session?.refreshToken }

    func userId() -> UUID? { session?.userId }

    func update(_ newSession: AuthSession) {
        session = newSession
        Self.save(newSession, key: keychainKey)
    }

    func clear() {
        session = nil
        Self.delete(key: keychainKey)
    }

    // MARK: - Keychain

    private static func save(_ session: AuthSession, key: String) {
        guard let data = try? JSONEncoder().encode(session) else { return }
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
        ]
        SecItemDelete(query as CFDictionary)
        var attributes = query
        attributes[kSecValueData as String] = data
        attributes[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        SecItemAdd(attributes as CFDictionary, nil)
    }

    private static func load(key: String) -> AuthSession? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data
        else { return nil }
        return try? JSONDecoder().decode(AuthSession.self, from: data)
    }

    private static func delete(key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
        ]
        SecItemDelete(query as CFDictionary)
    }
}
