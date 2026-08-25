import CoreLocation
import Foundation

/// Supabase の接続先が未設定のときに使うインメモリ実装。
///
/// バックエンドを立てる前でも全画面を通しで触れるようにするためのもの。
/// 本番用の実装（`Supabase*Service`）と同じプロトコルを満たすので、設定を入れるだけで差し替わる。
actor SampleBackend: ProductServing, StoreServing, SightingServing, ReviewServing,
                     NewsServing, LibraryServing, AuthServing {
    private var products: [Product] = SampleData.products
    private var stores: [Store] = SampleData.stores
    private var sightingRows: [Sighting] = SampleData.sightings
    private var reviewRows: [Review] = SampleData.reviews
    private var newsRows: [NewsArticle] = SampleData.news

    private var tastedIds: Set<UUID> = SampleData.initiallyTastedProductIds
    private var wishlistIds: Set<UUID> = SampleData.initiallyWishlistedProductIds
    private var helpfulReviewIds: Set<UUID> = []
    private var blockedIds: Set<UUID> = []
    private var currentUser: UserProfile?

    // MARK: - ProductServing

    func products(filter: ProductFilter, limit: Int, offset: Int) async throws -> [Product] {
        let keyword = filter.keyword.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let filtered = products.filter { product in
            if !keyword.isEmpty {
                let haystack = [product.name, product.manufacturer ?? "", product.description ?? ""]
                    .joined(separator: " ").lowercased()
                guard haystack.contains(keyword) else { return false }
            }
            if !filter.categories.isEmpty, !filter.categories.contains(product.category) { return false }
            if !filter.saleStatuses.isEmpty, !filter.saleStatuses.contains(product.saleStatus) { return false }
            if filter.limitedOnly, !product.isLimited { return false }
            if !filter.mintLevels.isEmpty {
                guard let level = product.mintLevel, filter.mintLevels.contains(level) else { return false }
            }
            if !filter.chains.isEmpty {
                let channels = SampleData.channels[product.id] ?? []
                guard !filter.chains.isDisjoint(with: Set(channels)) else { return false }
            }
            return true
        }
        .sorted { ($0.releaseDate ?? .distantPast) > ($1.releaseDate ?? .distantPast) }

        return Array(filtered.dropFirst(offset).prefix(limit))
    }

    func product(id: UUID) async throws -> Product? {
        products.first { $0.id == id }
    }

    func newProducts(limit: Int) async throws -> [Product] {
        products
            .filter { $0.saleStatus != .ended && $0.releaseDate != nil }
            .sorted { ($0.releaseDate ?? .distantPast) > ($1.releaseDate ?? .distantPast) }
            .prefix(limit)
            .map { $0 }
    }

    func ranking(days: Int, limit: Int) async throws -> [Product] {
        products
            .filter { $0.reviewCount > 0 }
            .sorted { ($0.avgOverall ?? 0, $0.reviewCount) > ($1.avgOverall ?? 0, $1.reviewCount) }
            .prefix(limit)
            .map { $0 }
    }

    func submitProduct(_ draft: ProductSubmissionDraft, userId: UUID) async throws {
        // 実運用では運営承認まで公開されない。サンプルでは受け付けたことにするだけ。
    }

    // MARK: - StoreServing

    func nearby(
        coordinate: CLLocationCoordinate2D,
        radiusMeters: Double,
        productId: UUID?,
        onSaleOnly: Bool
    ) async throws -> [NearbyStoreProduct] {
        let origin = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        var rows: [NearbyStoreProduct] = []

        for (storeId, productIds) in storeProductIndex() {
            guard let store = stores.first(where: { $0.id == storeId }) else { continue }
            let distance = CLLocation(latitude: store.latitude, longitude: store.longitude).distance(from: origin)
            guard distance <= radiusMeters else { continue }

            for pid in productIds {
                guard let product = products.first(where: { $0.id == pid }) else { continue }
                if let productId, product.id != productId { continue }
                if onSaleOnly, product.saleStatus != .onSale { continue }
                if product.saleStatus == .ended { continue }
                guard let lastSeen = lastSeenAt(storeId: storeId, productId: pid) else { continue }
                let freshness = SightingFreshness.from(lastSeenAt: lastSeen)
                guard freshness.isVisible else { continue }

                rows.append(NearbyStoreProduct(
                    storeId: store.id,
                    storeName: store.name,
                    chainName: store.chainName,
                    latitude: store.latitude,
                    longitude: store.longitude,
                    distanceM: distance,
                    productId: product.id,
                    productName: product.name,
                    imageUrl: product.imageUrl,
                    lastSeenAt: lastSeen,
                    freshness: freshness
                ))
            }
        }
        return rows.sorted { ($0.distanceM ?? 0) < ($1.distanceM ?? 0) }
    }

    func recentlySeen(
        coordinate: CLLocationCoordinate2D?,
        limit: Int
    ) async throws -> [NearbyStoreProduct] {
        let origin = coordinate.map { CLLocation(latitude: $0.latitude, longitude: $0.longitude) }
        var rows: [NearbyStoreProduct] = []

        for (storeId, productIds) in storeProductIndex() {
            guard let store = stores.first(where: { $0.id == storeId }) else { continue }
            for pid in productIds {
                guard let product = products.first(where: { $0.id == pid }),
                      product.saleStatus != .ended,
                      let lastSeen = lastSeenAt(storeId: storeId, productId: pid)
                else { continue }
                let freshness = SightingFreshness.from(lastSeenAt: lastSeen)
                guard freshness.isVisible else { continue }
                rows.append(NearbyStoreProduct(
                    storeId: store.id,
                    storeName: store.name,
                    chainName: store.chainName,
                    latitude: store.latitude,
                    longitude: store.longitude,
                    distanceM: origin.map {
                        CLLocation(latitude: store.latitude, longitude: store.longitude).distance(from: $0)
                    },
                    productId: product.id,
                    productName: product.name,
                    imageUrl: product.imageUrl,
                    lastSeenAt: lastSeen,
                    freshness: freshness
                ))
            }
        }
        return rows.sorted { $0.lastSeenAt > $1.lastSeenAt }.prefix(limit).map { $0 }
    }

    func chainOfferings() async throws -> [ChainOffering] {
        var grouped: [String: [Product]] = [:]
        for (productId, chains) in SampleData.channels {
            guard let product = products.first(where: { $0.id == productId }),
                  product.saleStatus != .ended else { continue }
            for chain in chains {
                grouped[chain.displayName, default: []].append(product)
            }
        }
        return grouped
            .map { ChainOffering(chainName: $0.key, brandColor: nil, products: $0.value) }
            .sorted { $0.chainName < $1.chainName }
    }

    func store(id: UUID) async throws -> Store? {
        stores.first { $0.id == id }
    }

    func products(atStore storeId: UUID) async throws -> [StoreProductEntry] {
        let rows = sightingRows.filter { $0.storeId == storeId }
        let grouped = Dictionary(grouping: rows, by: \.productId)
        return grouped.compactMap { productId, sightings -> StoreProductEntry? in
            guard let product = products.first(where: { $0.id == productId }),
                  let last = sightings.map(\.foundAt).max(),
                  let first = sightings.map(\.foundAt).min(),
                  SightingFreshness.from(lastSeenAt: last).isVisible
            else { return nil }
            return StoreProductEntry(
                product: product,
                firstSeenAt: first,
                lastSeenAt: last,
                sightingCount: sightings.count
            )
        }
        .sorted { $0.lastSeenAt > $1.lastSeenAt }
    }

    // MARK: - SightingServing

    func recent(limit: Int) async throws -> [SightingEntry] {
        entries(from: sightingRows, limit: limit)
    }

    func history(userId: UUID, limit: Int) async throws -> [SightingEntry] {
        entries(from: sightingRows.filter { $0.userId == userId }, limit: limit)
    }

    func report(_ report: SightingReport) async throws -> SightingReportResult {
        guard let user = currentUser else { throw BackendError.authenticationRequired }
        let candidate = report.candidate

        // サーバ側 `report_sighting` と同じ順序で店舗を名寄せする。
        var storeId = stores.first { store in
            store.externalStoreId == candidate.externalStoreId && candidate.externalStoreId != nil
        }?.id
        if storeId == nil {
            storeId = stores.first { store in
                store.name == candidate.name && store.distance(from: candidate.coordinate) <= 50
            }?.id
        }
        if storeId == nil {
            let store = Store(
                id: UUID(),
                name: candidate.name,
                chainName: candidate.chainName,
                latitude: candidate.latitude,
                longitude: candidate.longitude,
                address: candidate.address,
                externalSource: candidate.externalSource,
                externalStoreId: candidate.externalStoreId,
                createdAt: Date()
            )
            stores.append(store)
            storeId = store.id
        }
        guard let storeId else { return .alreadyReportedToday }

        // 1 日 1 件制限
        let alreadyToday = sightingRows.contains {
            $0.userId == user.id && $0.productId == report.productId && $0.storeId == storeId
                && Calendar.japanese.isDateInToday($0.foundAt)
        }
        if alreadyToday { return .alreadyReportedToday }

        let sighting = Sighting(
            id: UUID(),
            productId: report.productId,
            storeId: storeId,
            userId: user.id,
            foundAt: Date(),
            isOfficial: false,
            createdAt: Date()
        )
        sightingRows.append(sighting)
        return .recorded(sightingId: sighting.id)
    }

    // MARK: - ReviewServing

    func reviews(productId: UUID, sort: ReviewSort, limit: Int) async throws -> [Review] {
        let filtered = reviewRows.filter { $0.productId == productId && !blockedIds.contains($0.userId) }
        let sorted: [Review] = switch sort {
        case .newest: filtered.sorted { $0.createdAt > $1.createdAt }
        case .highestRated: filtered.sorted { ($0.overallRating, $0.createdAt) > ($1.overallRating, $1.createdAt) }
        case .mostHelpful: filtered.sorted { ($0.helpfulCount, $0.createdAt) > ($1.helpfulCount, $1.createdAt) }
        }
        return Array(sorted.prefix(limit))
    }

    func myReview(productId: UUID, userId: UUID) async throws -> Review? {
        reviewRows.first { $0.productId == productId && $0.userId == userId }
    }

    func myReviews(userId: UUID) async throws -> [Review] {
        reviewRows.filter { $0.userId == userId }.sorted { $0.createdAt > $1.createdAt }
    }

    func submit(productId: UUID, draft: ReviewDraft, userId: UUID) async throws {
        let author = Review.ReviewAuthor(
            id: userId,
            displayName: currentUser?.displayName ?? "あなた"
        )
        let review = Review(
            id: reviewRows.first { $0.productId == productId && $0.userId == userId }?.id ?? UUID(),
            userId: userId,
            productId: productId,
            overallRating: draft.overallRating,
            mintIntensity: draft.optionalValue(draft.mintIntensity),
            chocolateIntensity: draft.optionalValue(draft.chocolateIntensity),
            sweetness: draft.optionalValue(draft.sweetness),
            freshness: draft.optionalValue(draft.freshness),
            comment: draft.comment.nilIfBlank,
            helpfulCount: 0,
            createdAt: Date(),
            updatedAt: Date(),
            author: author
        )
        reviewRows.removeAll { $0.productId == productId && $0.userId == userId }
        reviewRows.append(review)
        recomputeStats(productId: productId)
    }

    func delete(reviewId: UUID) async throws {
        guard let review = reviewRows.first(where: { $0.id == reviewId }) else { return }
        reviewRows.removeAll { $0.id == reviewId }
        recomputeStats(productId: review.productId)
    }

    func setHelpful(_ helpful: Bool, reviewId: UUID, userId: UUID) async throws {
        guard let index = reviewRows.firstIndex(where: { $0.id == reviewId }) else { return }
        if helpful, !helpfulReviewIds.contains(reviewId) {
            helpfulReviewIds.insert(reviewId)
            reviewRows[index].helpfulCount += 1
        } else if !helpful, helpfulReviewIds.contains(reviewId) {
            helpfulReviewIds.remove(reviewId)
            reviewRows[index].helpfulCount = max(0, reviewRows[index].helpfulCount - 1)
        }
    }

    func report(reviewId: UUID, draft: ReviewReportDraft, userId: UUID) async throws {
        // 実運用では運営が確認する。サンプルでは受け付けたことにするだけ。
    }

    func block(_ blockedId: UUID, by userId: UUID) async throws {
        blockedIds.insert(blockedId)
    }

    func blockedUserIds(of userId: UUID) async throws -> Set<UUID> {
        blockedIds
    }

    // MARK: - NewsServing

    func articles(limit: Int) async throws -> [NewsArticle] {
        newsRows.sorted { $0.publishedAt > $1.publishedAt }.prefix(limit).map { $0 }
    }

    // MARK: - LibraryServing

    func tasted(userId: UUID) async throws -> [TastedEntry] {
        products.filter { tastedIds.contains($0.id) }
            .map { TastedEntry(product: $0, tastedAt: Date(), tastedCount: 1) }
    }

    func wishlist(userId: UUID) async throws -> [WishlistEntry] {
        products.filter { wishlistIds.contains($0.id) }
            .map { WishlistEntry(product: $0, createdAt: Date()) }
    }

    func setTasted(_ tasted: Bool, productId: UUID, userId: UUID) async throws {
        if tasted { tastedIds.insert(productId) } else { tastedIds.remove(productId) }
    }

    func setWishlisted(_ wishlisted: Bool, productId: UUID, userId: UUID) async throws {
        if wishlisted { wishlistIds.insert(productId) } else { wishlistIds.remove(productId) }
    }

    func state(productId: UUID, userId: UUID) async throws -> ProductUserState {
        ProductUserState(
            isTasted: tastedIds.contains(productId),
            isWishlisted: wishlistIds.contains(productId),
            myReview: reviewRows.first { $0.productId == productId && $0.userId == userId }
        )
    }

    func tasteStats(userId: UUID) async throws -> TasteStats {
        let mine = reviewRows.filter { $0.userId == userId }
        func average(_ values: [Int?]) -> Double? {
            let present = values.compactMap { $0 }
            guard !present.isEmpty else { return nil }
            return Double(present.reduce(0, +)) / Double(present.count)
        }
        return TasteStats(
            reviewCount: mine.count,
            tastedCount: tastedIds.count,
            avgMint: average(mine.map(\.mintIntensity)),
            avgChocolate: average(mine.map(\.chocolateIntensity)),
            avgSweetness: average(mine.map(\.sweetness)),
            avgFreshness: average(mine.map(\.freshness)),
            avgOverall: average(mine.map { Optional($0.overallRating) })
        )
    }

    func collectionProgress(userId: UUID) async throws -> [CollectionProgress] {
        let grouped = Dictionary(grouping: products.compactMap { product -> (Int, Product)? in
            guard let year = product.releaseYear else { return nil }
            return (year, product)
        }, by: \.0)

        return grouped.map { year, pairs in
            CollectionProgress(
                year: year,
                tastedCount: pairs.filter { tastedIds.contains($0.1.id) }.count,
                totalCount: pairs.count
            )
        }
        .sorted { $0.year > $1.year }
    }

    func collectionSlots(userId: UUID, year: Int) async throws -> [CollectionSlot] {
        products
            .filter { $0.releaseYear == year }
            .sorted { ($0.releaseDate ?? .distantPast) < ($1.releaseDate ?? .distantPast) }
            .map { CollectionSlot(product: $0, isTasted: tastedIds.contains($0.id)) }
    }

    // MARK: - AuthServing

    func restore() async -> UserProfile? { currentUser }

    func signInWithApple(idToken: String, nonce: String, suggestedName: String?) async throws -> UserProfile {
        let profile = UserProfile(
            id: SampleData.currentUserId,
            displayName: suggestedName?.nilIfBlank ?? "さわやかなチョコミン党",
            createdAt: Date()
        )
        currentUser = profile
        return profile
    }

    func signOut() async { currentUser = nil }

    func updateDisplayName(_ name: String, userId: UUID) async throws -> UserProfile {
        let profile = UserProfile(id: userId, displayName: name, createdAt: currentUser?.createdAt)
        currentUser = profile
        return profile
    }

    func deleteAccount(userId: UUID) async throws {
        currentUser = nil
        tastedIds.removeAll()
        wishlistIds.removeAll()
        reviewRows.removeAll { $0.userId == userId }
    }

    // MARK: - 内部

    private func storeProductIndex() -> [UUID: Set<UUID>] {
        var index: [UUID: Set<UUID>] = [:]
        for sighting in sightingRows {
            index[sighting.storeId, default: []].insert(sighting.productId)
        }
        return index
    }

    private func lastSeenAt(storeId: UUID, productId: UUID) -> Date? {
        sightingRows
            .filter { $0.storeId == storeId && $0.productId == productId }
            .map(\.foundAt)
            .max()
    }

    private func entries(from rows: [Sighting], limit: Int) -> [SightingEntry] {
        rows.sorted { $0.foundAt > $1.foundAt }
            .prefix(limit)
            .compactMap { sighting in
                guard let product = products.first(where: { $0.id == sighting.productId }),
                      let store = stores.first(where: { $0.id == sighting.storeId })
                else { return nil }
                return SightingEntry(
                    id: sighting.id,
                    foundAt: sighting.foundAt,
                    isOfficial: sighting.isOfficial,
                    product: product,
                    store: store
                )
            }
    }

    /// レビュー投稿後に商品の集計値を更新する。本番では DB トリガが同じことをする。
    private func recomputeStats(productId: UUID) {
        guard let index = products.firstIndex(where: { $0.id == productId }) else { return }
        let rows = reviewRows.filter { $0.productId == productId }
        func average(_ values: [Int?]) -> Double? {
            let present = values.compactMap { $0 }
            guard !present.isEmpty else { return nil }
            return Double(present.reduce(0, +)) / Double(present.count)
        }
        products[index].reviewCount = rows.count
        products[index].avgOverall = average(rows.map { Optional($0.overallRating) })
        products[index].avgMint = average(rows.map(\.mintIntensity))
        products[index].avgChocolate = average(rows.map(\.chocolateIntensity))
        products[index].avgSweetness = average(rows.map(\.sweetness))
        products[index].avgFreshness = average(rows.map(\.freshness))
        products[index].mintLevel = MintLevel.from(averageMintIntensity: products[index].avgMint)
    }
}
