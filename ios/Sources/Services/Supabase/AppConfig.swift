import Foundation

/// アプリの接続設定。Info.plist のビルド設定展開から読む。
///
/// Supabase の接続先が空のときはサンプルデータで動く。バックエンドを立てる前でも
/// 画面と導線を通しで確認できるようにするため（README 参照）。
struct AppConfig: Sendable {
    var supabaseURL: URL?
    var supabaseAnonKey: String?

    var usesSampleData: Bool {
        supabaseURL == nil || (supabaseAnonKey ?? "").isEmpty
    }

    init(supabaseURL: URL? = nil, supabaseAnonKey: String? = nil) {
        self.supabaseURL = supabaseURL
        self.supabaseAnonKey = supabaseAnonKey
    }

    init(bundle: Bundle) {
        let urlString = (bundle.object(forInfoDictionaryKey: "SupabaseURL") as? String) ?? ""
        let key = (bundle.object(forInfoDictionaryKey: "SupabaseAnonKey") as? String) ?? ""
        let trimmedURL = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        supabaseURL = trimmedURL.isEmpty ? nil : URL(string: trimmedURL)
        supabaseAnonKey = key.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static let current = AppConfig(bundle: .main)
}
