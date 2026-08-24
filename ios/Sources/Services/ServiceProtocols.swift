import CoreLocation
import Foundation

/// 商品まわり。
protocol ProductServing: Sendable {
    func products(filter: ProductFilter, limit: Int, offset: Int) async throws -> [Product]
    func product(id: UUID) async throws -> Product?
    /// 新発売・発売予定。発売日の新しい順。
    func newProducts(limit: Int) async throws -> [Product]
    /// 人気ランキング。直近 `days` 日のレビューを対象にする。
    func ranking(days: Int, limit: Int) async throws -> [Product]
    /// ユーザーによる商品報告。運営承認後に公開される。
    func submitProduct(_ draft: ProductSubmissionDraft, userId: UUID) async throws
}

/// 店舗まわり。
protocol StoreServing: Sendable {
    /// 目撃実績のある店舗 × 商品を近い順に返す。
    func nearby(
        coordinate: CLLocationCoordinate2D,
        radiusMeters: Double,
        productId: UUID?,
        onSaleOnly: Bool
    ) async throws -> [NearbyStoreProduct]
    /// 目撃実績のある店舗を、距離で絞らずに新しい順で返す。
    /// 現在地が分かれば距離も入れる（分からなければ nil）。
    func recentlySeen(
        coordinate: CLLocationCoordinate2D?,
        limit: Int
    ) async throws -> [NearbyStoreProduct]

    /// 公式サイトで取り扱いを確認できたチェーンと、その商品。
    func chainOfferings() async throws -> [ChainOffering]

    func store(id: UUID) async throws -> Store?
    /// この店舗で見つかった商品。鮮度 30 日以内のみ。
    func products(atStore storeId: UUID) async throws -> [StoreProductEntry]
}

/// 目撃情報まわり。
protocol SightingServing: Sendable {
    func recent(limit: Int) async throws -> [SightingEntry]
    func report(_ report: SightingReport) async throws -> SightingReportResult
    func history(userId: UUID, limit: Int) async throws -> [SightingEntry]
}

/// レビューまわり（通報・ブロックを含む）。
protocol ReviewServing: Sendable {
    func reviews(productId: UUID, sort: ReviewSort, limit: Int) async throws -> [Review]
    func myReview(productId: UUID, userId: UUID) async throws -> Review?
    func myReviews(userId: UUID) async throws -> [Review]
    func submit(productId: UUID, draft: ReviewDraft, userId: UUID) async throws
    func delete(reviewId: UUID) async throws
    func setHelpful(_ helpful: Bool, reviewId: UUID, userId: UUID) async throws
    func report(reviewId: UUID, draft: ReviewReportDraft, userId: UUID) async throws
    func block(_ blockedId: UUID, by userId: UUID) async throws
    func blockedUserIds(of userId: UUID) async throws -> Set<UUID>
}

/// ニュース。
protocol NewsServing: Sendable {
    func articles(limit: Int) async throws -> [NewsArticle]
}

/// 「食べた」「食べたい」「図鑑」「味覚傾向」。
protocol LibraryServing: Sendable {
    func tasted(userId: UUID) async throws -> [TastedEntry]
    func wishlist(userId: UUID) async throws -> [WishlistEntry]
    func setTasted(_ tasted: Bool, productId: UUID, userId: UUID) async throws
    func setWishlisted(_ wishlisted: Bool, productId: UUID, userId: UUID) async throws
    func state(productId: UUID, userId: UUID) async throws -> ProductUserState
    func tasteStats(userId: UUID) async throws -> TasteStats
    func collectionProgress(userId: UUID) async throws -> [CollectionProgress]
    func collectionSlots(userId: UUID, year: Int) async throws -> [CollectionSlot]
}

/// 認証。閲覧はログイン不要なので、必要になった操作の直前にだけ呼ぶ。
protocol AuthServing: Sendable {
    /// 起動時にキーチェーンのセッションを復元する。
    func restore() async -> UserProfile?
    /// Sign in with Apple の ID トークンを渡してログインする。
    func signInWithApple(idToken: String, nonce: String, suggestedName: String?) async throws -> UserProfile
    func signOut() async
    func updateDisplayName(_ name: String, userId: UUID) async throws -> UserProfile
    /// アカウント削除（App Store の要件）。
    func deleteAccount(userId: UUID) async throws
}

/// アプリ全体で使うサービス一式。接続設定に応じて実装を差し替える。
struct AppServices: Sendable {
    var products: any ProductServing
    var stores: any StoreServing
    var sightings: any SightingServing
    var reviews: any ReviewServing
    var news: any NewsServing
    var library: any LibraryServing
    var auth: any AuthServing
    var usesSampleData: Bool

    /// 設定に Supabase の接続先があればそちら、無ければサンプルデータで動かす。
    static func make(config: AppConfig = .current) -> AppServices {
        guard let url = config.supabaseURL, let key = config.supabaseAnonKey, !key.isEmpty else {
            let sample = SampleBackend()
            return AppServices(
                products: sample, stores: sample, sightings: sample, reviews: sample,
                news: sample, library: sample, auth: sample, usesSampleData: true
            )
        }
        let client = SupabaseClient(baseURL: url, anonKey: key, sessionStore: AuthSessionStore())
        return AppServices(
            products: SupabaseProductService(client: client),
            stores: SupabaseStoreService(client: client),
            sightings: SupabaseSightingService(client: client),
            reviews: SupabaseReviewService(client: client),
            news: SupabaseNewsService(client: client),
            library: SupabaseLibraryService(client: client),
            auth: SupabaseAuthService(client: client),
            usesSampleData: false
        )
    }
}
