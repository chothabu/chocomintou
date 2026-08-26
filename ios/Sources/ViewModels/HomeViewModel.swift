import CoreLocation
import Foundation

/// ホーム画面。5 つのセクションを同時に取りに行き、失敗したものだけ空にする。
/// 1 つのセクションの失敗で画面全体を落とさないための作り。
@MainActor
@Observable
final class HomeViewModel {
    var newProducts: [Product] = []
    var ranking: [Product] = []
    var sightings: [SightingEntry] = []
    var news: [NewsArticle] = []

    var isLoading = false
    var errorMessage: String?
    /// 通信に失敗してキャッシュを表示している状態。
    var isShowingCache = false

    private var hasLoaded = false

    func loadIfNeeded(services: AppServices, cache: CacheStore?) async {
        guard !hasLoaded else { return }
        await load(services: services, cache: cache)
    }

    /// 近くの店はマップで見られるので、ホームでは位置情報を使わない。
    func load(services: AppServices, cache: CacheStore?) async {
        isLoading = true
        errorMessage = nil
        isShowingCache = false
        defer { isLoading = false; hasLoaded = true }

        async let newTask = (try? await services.products.newProducts(limit: 10)) ?? []
        async let rankingTask = (try? await services.products.ranking(days: 30, limit: 10)) ?? []
        async let sightingsTask = (try? await services.sightings.recent(limit: 8)) ?? []
        async let newsTask = (try? await services.news.articles(limit: 3)) ?? []

        newProducts = await newTask
        ranking = await rankingTask
        sightings = await sightingsTask
        news = await newsTask

        // すべて空なら通信が落ちている可能性が高い。キャッシュに切り替える。
        let everythingEmpty = newProducts.isEmpty && ranking.isEmpty && sightings.isEmpty && news.isEmpty
        if everythingEmpty, let cache {
            restore(from: cache)
        } else if let cache {
            store(to: cache)
        }
    }

    private func restore(from cache: CacheStore) {
        newProducts = cache.load(CacheStore.Key.homeNewProducts, as: [Product].self) ?? []
        ranking = cache.load(CacheStore.Key.homeRanking, as: [Product].self) ?? []
        sightings = cache.load(CacheStore.Key.homeSightings, as: [SightingEntry].self) ?? []
        news = cache.load(CacheStore.Key.news, as: [NewsArticle].self) ?? []
        isShowingCache = !(newProducts.isEmpty && ranking.isEmpty && sightings.isEmpty && news.isEmpty)
        if !isShowingCache {
            errorMessage = "情報を読み込めませんでした。通信環境を確認してください。"
        }
    }

    private func store(to cache: CacheStore) {
        cache.save(newProducts, for: CacheStore.Key.homeNewProducts)
        cache.save(ranking, for: CacheStore.Key.homeRanking)
        cache.save(sightings, for: CacheStore.Key.homeSightings)
        cache.save(news, for: CacheStore.Key.news)
    }
}
