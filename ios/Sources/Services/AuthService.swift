import Foundation

struct SupabaseAuthService: AuthServing {
    let client: SupabaseClient

    func restore() async -> UserProfile? {
        guard (try? await client.refreshSessionIfNeeded()) != nil,
              let userId = await client.currentUserId()
        else { return nil }
        return try? await profile(userId: userId)
    }

    /// Apple の ID トークンを Supabase のセッションに交換し、公開プロフィール行を用意する。
    func signInWithApple(idToken: String, nonce: String, suggestedName: String?) async throws -> UserProfile {
        let session = try await client.signInWithAppleIDToken(idToken, nonce: nonce)

        // Apple は初回サインイン時にしか名前を返さない。既存行がある場合は上書きしない。
        if let existing = try? await profile(userId: session.userId) {
            return existing
        }
        let name = suggestedName?.nilIfBlank ?? Self.randomName()
        return try await client.insert(
            into: "users",
            body: ProfilePayload(id: session.userId, displayName: name),
            returning: [UserProfile].self,
            onConflict: "id"
        )
        .first ?? UserProfile(id: session.userId, displayName: name, createdAt: Date())
    }

    func signOut() async {
        await client.signOut()
    }

    func updateDisplayName(_ name: String, userId: UUID) async throws -> UserProfile {
        try await client.update(
            table: "users",
            matching: PostgRESTQuery("users").eq("id", userId),
            body: NamePayload(displayName: name)
        )
        return try await profile(userId: userId) ?? UserProfile(id: userId, displayName: name, createdAt: nil)
    }

    /// auth.users を消せば public.users は ON DELETE CASCADE で消える。
    /// ただし anon key では auth スキーマを触れないため、Edge Function 側の受け口が必要。
    func deleteAccount(userId: UUID) async throws {
        try await client.rpcIgnoringResult("delete_own_account")
        await client.signOut()
    }

    private func profile(userId: UUID) async throws -> UserProfile? {
        try await client.fetchOne(
            PostgRESTQuery("users").select("id,display_name,created_at").eq("id", userId),
            as: UserProfile.self
        )
    }

    /// 表示名の初期値。本名を出さずに済ませるための自動生成。
    static func randomName() -> String {
        let adjectives = ["さわやかな", "つめたい", "みどりの", "ひんやり", "きらめく", "つよめの"]
        let nouns = ["チョコミン党", "ミント好き", "ミントラバー", "チョコミンター"]
        let adjective = adjectives.randomElement() ?? "さわやかな"
        let noun = nouns.randomElement() ?? "チョコミン党"
        return "\(adjective)\(noun)"
    }

    private struct ProfilePayload: Encodable, Sendable {
        let id: UUID
        let displayName: String
    }

    private struct NamePayload: Encodable, Sendable {
        let displayName: String
    }
}
