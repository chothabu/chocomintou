import Foundation

/// Supabase (PostgREST + GoTrue) への薄いクライアント。
///
/// サードパーティの SDK を入れずに URLSession で直接叩いている。
/// このアプリが必要とするのは「テーブルの読み書き」「RPC」「Apple ID トークンの交換」の 3 つだけで、
/// 依存を足すほどの範囲ではないため。
actor SupabaseClient {
    private let baseURL: URL
    private let anonKey: String
    private let session: URLSession
    private let sessionStore: AuthSessionStore

    init(baseURL: URL, anonKey: String, sessionStore: AuthSessionStore, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.anonKey = anonKey
        self.sessionStore = sessionStore
        self.session = session
    }

    // MARK: - PostgREST

    func fetch<T: Decodable & Sendable>(_ query: PostgRESTQuery, as type: T.Type = T.self) async throws -> T {
        let request = try await makeRequest(
            path: "/rest/v1/\(query.table)",
            queryItems: query.items,
            method: "GET"
        )
        return try await send(request, as: T.self)
    }

    /// 1 件だけ取得する。見つからなければ nil。
    func fetchOne<T: Decodable & Sendable>(_ query: PostgRESTQuery, as type: T.Type = T.self) async throws -> T? {
        let rows: [T] = try await fetch(query.limit(1), as: [T].self)
        return rows.first
    }

    /// `onConflict` に列名（カンマ区切り）を渡すと UPSERT になる。
    @discardableResult
    func insert<Body: Encodable & Sendable, T: Decodable & Sendable>(
        into table: String,
        body: Body,
        returning: T.Type,
        onConflict: String? = nil
    ) async throws -> T {
        var request = try await makeRequest(
            path: "/rest/v1/\(table)",
            queryItems: Self.conflictItems(onConflict),
            method: "POST"
        )
        var preferences = ["return=representation"]
        if onConflict != nil { preferences.append("resolution=merge-duplicates") }
        request.setValue(preferences.joined(separator: ","), forHTTPHeaderField: "Prefer")
        request.httpBody = try JSONCoding.encoder.encode(body)
        return try await send(request, as: T.self)
    }

    /// `ignoreDuplicates` が true なら、既存行があっても何もしない（UPDATE しない）。
    ///
    /// 「登録済みなら現状のままでよい」操作はこちらを使う。UPDATE を伴わないので
    /// RLS の UPDATE ポリシーも UPDATE 権限も要らず、意図しない上書きも起きない。
    func insertIgnoringResult(
        into table: String,
        body: some Encodable & Sendable,
        onConflict: String? = nil,
        ignoreDuplicates: Bool = false
    ) async throws {
        var request = try await makeRequest(
            path: "/rest/v1/\(table)",
            queryItems: Self.conflictItems(onConflict),
            method: "POST"
        )
        var preferences = ["return=minimal"]
        if onConflict != nil {
            preferences.append(ignoreDuplicates ? "resolution=ignore-duplicates" : "resolution=merge-duplicates")
        }
        request.setValue(preferences.joined(separator: ","), forHTTPHeaderField: "Prefer")
        request.httpBody = try JSONCoding.encoder.encode(body)
        _ = try await sendRaw(request)
    }

    private static func conflictItems(_ onConflict: String?) -> [URLQueryItem] {
        guard let onConflict else { return [] }
        return [URLQueryItem(name: "on_conflict", value: onConflict)]
    }

    func update(table: String, matching query: PostgRESTQuery, body: some Encodable & Sendable) async throws {
        var request = try await makeRequest(path: "/rest/v1/\(table)", queryItems: query.items, method: "PATCH")
        request.setValue("return=minimal", forHTTPHeaderField: "Prefer")
        request.httpBody = try JSONCoding.encoder.encode(body)
        _ = try await sendRaw(request)
    }

    func delete(from table: String, matching query: PostgRESTQuery) async throws {
        var request = try await makeRequest(path: "/rest/v1/\(table)", queryItems: query.items, method: "DELETE")
        request.setValue("return=minimal", forHTTPHeaderField: "Prefer")
        _ = try await sendRaw(request)
    }

    // MARK: - RPC

    func rpc<T: Decodable & Sendable>(
        _ function: String,
        params: [String: JSONValue] = [:],
        as type: T.Type = T.self
    ) async throws -> T {
        var request = try await makeRequest(path: "/rest/v1/rpc/\(function)", queryItems: [], method: "POST")
        request.httpBody = try JSONCoding.encoder.encode(params)
        return try await send(request, as: T.self)
    }

    /// 戻り値を使わない RPC 用。
    func rpcIgnoringResult(_ function: String, params: [String: JSONValue] = [:]) async throws {
        var request = try await makeRequest(path: "/rest/v1/rpc/\(function)", queryItems: [], method: "POST")
        request.httpBody = try JSONCoding.encoder.encode(params)
        _ = try await sendRaw(request)
    }

    /// スカラーを返す RPC で、結果が null になりうるもの用。
    func rpcOptionalUUID(_ function: String, params: [String: JSONValue] = [:]) async throws -> UUID? {
        var request = try await makeRequest(path: "/rest/v1/rpc/\(function)", queryItems: [], method: "POST")
        request.httpBody = try JSONCoding.encoder.encode(params)
        let data = try await sendRaw(request)
        let raw = String(data: data, encoding: .utf8)?
            .trimmingCharacters(in: CharacterSet(charactersIn: "\"\n "))
        guard let raw, raw != "null", !raw.isEmpty else { return nil }
        return UUID(uuidString: raw)
    }

    // MARK: - Auth (GoTrue)

    /// Sign in with Apple の ID トークンを Supabase のセッションに交換する。
    func signInWithAppleIDToken(_ idToken: String, nonce: String) async throws -> AuthSession {
        var request = URLRequest(url: baseURL.appending(path: "/auth/v1/token"))
        request.url = request.url?.appending(queryItems: [URLQueryItem(name: "grant_type", value: "id_token")])
        request.httpMethod = "POST"
        request.setValue(anonKey, forHTTPHeaderField: "apikey")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "provider": "apple",
            "id_token": idToken,
            "nonce": nonce,
        ])

        let data = try await sendRaw(request)
        let response = try decodeTokenResponse(data)
        await sessionStore.update(response)
        return response
    }

    /// 期限切れのアクセストークンを更新する。失敗したらセッションを破棄する。
    @discardableResult
    func refreshSessionIfNeeded() async throws -> AuthSession? {
        guard let existing = await sessionStore.current() else { return nil }
        guard existing.isExpired else { return existing }
        guard let refreshToken = await sessionStore.refreshToken() else {
            await sessionStore.clear()
            return nil
        }

        var request = URLRequest(url: baseURL.appending(path: "/auth/v1/token"))
        request.url = request.url?.appending(queryItems: [URLQueryItem(name: "grant_type", value: "refresh_token")])
        request.httpMethod = "POST"
        request.setValue(anonKey, forHTTPHeaderField: "apikey")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: ["refresh_token": refreshToken])

        do {
            let data = try await sendRaw(request)
            let session = try decodeTokenResponse(data)
            await sessionStore.update(session)
            return session
        } catch {
            await sessionStore.clear()
            return nil
        }
    }

    func signOut() async {
        if let token = await sessionStore.accessToken() {
            var request = URLRequest(url: baseURL.appending(path: "/auth/v1/logout"))
            request.httpMethod = "POST"
            request.setValue(anonKey, forHTTPHeaderField: "apikey")
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            _ = try? await sendRaw(request)
        }
        await sessionStore.clear()
    }

    func currentUserId() async -> UUID? {
        await sessionStore.userId()
    }

    // MARK: - 内部

    private func decodeTokenResponse(_ data: Data) throws -> AuthSession {
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let accessToken = json["access_token"] as? String,
              let refreshToken = json["refresh_token"] as? String,
              let user = json["user"] as? [String: Any],
              let userIdString = user["id"] as? String,
              let userId = UUID(uuidString: userIdString)
        else { throw BackendError.invalidResponse }

        let expiresIn = (json["expires_in"] as? Double) ?? 3600
        return AuthSession(
            accessToken: accessToken,
            refreshToken: refreshToken,
            expiresAt: Date().addingTimeInterval(expiresIn),
            userId: userId
        )
    }

    private func makeRequest(path: String, queryItems: [URLQueryItem], method: String) async throws -> URLRequest {
        var components = URLComponents(
            url: baseURL.appending(path: path),
            resolvingAgainstBaseURL: false
        )
        if !queryItems.isEmpty { components?.queryItems = queryItems }
        guard let url = components?.url else { throw BackendError.notConfigured }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue(anonKey, forHTTPHeaderField: "apikey")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // ログイン中ならユーザーの JWT を送る。RLS はこれを見て本人判定する。
        _ = try? await refreshSessionIfNeeded()
        let token = await sessionStore.accessToken() ?? anonKey
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        return request
    }

    private func send<T: Decodable & Sendable>(_ request: URLRequest, as type: T.Type) async throws -> T {
        let data = try await sendRaw(request)
        do {
            return try JSONCoding.decoder.decode(T.self, from: data)
        } catch {
            throw BackendError.decoding(String(describing: error))
        }
    }

    private func sendRaw(_ request: URLRequest) async throws -> Data {
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw BackendError.network(error.localizedDescription)
        }

        guard let http = response as? HTTPURLResponse else { throw BackendError.invalidResponse }
        guard (200..<300).contains(http.statusCode) else {
            if http.statusCode == 401 || http.statusCode == 403 {
                throw BackendError.authenticationRequired
            }
            throw BackendError.http(status: http.statusCode, message: Self.errorMessage(from: data))
        }
        return data
    }

    /// PostgREST のエラーは `{"message": "...", "hint": "..."}` で返る。
    private static func errorMessage(from data: Data) -> String {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return "" }
        return (json["message"] as? String) ?? (json["error_description"] as? String) ?? ""
    }
}
