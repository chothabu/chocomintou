import CoreLocation
import Foundation

@MainActor
@Observable
final class ProductDetailViewModel {
    var product: Product?
    var userState = ProductUserState()
    var reviews: [Review] = []
    var nearby: [NearbyStoreProduct] = []

    var isLoading = true
    var errorMessage: String?
    /// レビューの取得に失敗した状態。0 件と区別しないと「レビューなし」と嘘の表示になる。
    var reviewsFailed = false
    /// 操作結果の一時表示（「食べたに追加しました」など）。
    var toast: String?
    /// 「食べた」を押した直後にレビューを促すダイアログ。
    var isPromptingReview = false

    func load(
        productId: UUID,
        services: AppServices,
        userId: UUID?,
        coordinate: CLLocationCoordinate2D?
    ) async {
        isLoading = product == nil
        errorMessage = nil

        do {
            if let fetched = try await services.products.product(id: productId) {
                product = fetched
            } else if product == nil {
                errorMessage = "この商品は見つかりませんでした。"
                isLoading = false
                return
            }
        } catch {
            // 一覧から渡された商品があるなら、それを表示したまま続行する。
            if product == nil {
                errorMessage = (error as? LocalizedError)?.errorDescription ?? "読み込みに失敗しました。"
                isLoading = false
                return
            }
        }

        await refreshRelated(productId: productId, services: services, userId: userId, coordinate: coordinate)
        isLoading = false
    }

    func refreshRelated(
        productId: UUID,
        services: AppServices,
        userId: UUID?,
        coordinate: CLLocationCoordinate2D?
    ) async {
        async let reviewsTask: [Review]? = try? await services.reviews.reviews(
            productId: productId, sort: .mostHelpful, limit: 3
        )
        async let nearbyTask: [NearbyStoreProduct] = {
            guard let coordinate else { return [] }
            return (try? await services.stores.nearby(
                coordinate: coordinate, radiusMeters: 5000, productId: productId, onSaleOnly: false
            )) ?? []
        }()
        async let stateTask: ProductUserState = {
            guard let userId else { return ProductUserState() }
            return (try? await services.library.state(productId: productId, userId: userId))
                ?? ProductUserState()
        }()

        if var fetchedReviews = await reviewsTask {
            // ブロック中のユーザーのレビューは表示しない。
            if let userId, let blocked = try? await services.reviews.blockedUserIds(of: userId) {
                fetchedReviews = fetchedReviews.filter { !blocked.contains($0.userId) }
            }
            reviews = fetchedReviews
            reviewsFailed = false
        } else {
            reviews = []
            reviewsFailed = true
        }
        nearby = await nearbyTask
        userState = await stateTask
    }

    func toggleTasted(services: AppServices, userId: UUID) async {
        guard let product else { return }
        let newValue = !userState.isTasted
        userState.isTasted = newValue
        do {
            try await services.library.setTasted(newValue, productId: product.id, userId: userId)
            if newValue {
                toast = "「食べた」に追加しました"
                // レビューは任意。登録だけで完結してよい（設計 §11）。
                if !userState.hasReviewed { isPromptingReview = true }
            } else {
                toast = "「食べた」から外しました"
            }
        } catch {
            userState.isTasted = !newValue
            toast = "保存できませんでした"
        }
    }

    func toggleWishlisted(services: AppServices, userId: UUID) async {
        guard let product else { return }
        let newValue = !userState.isWishlisted
        userState.isWishlisted = newValue
        do {
            try await services.library.setWishlisted(newValue, productId: product.id, userId: userId)
            toast = newValue ? "「食べたい」に追加しました" : "「食べたい」から外しました"
        } catch {
            userState.isWishlisted = !newValue
            toast = "保存できませんでした"
        }
    }
}
