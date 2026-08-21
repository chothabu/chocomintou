import XCTest
@testable import ChocoMint

/// 判定ロジックは DB 側にも同じ境界値の実装があるため、ここでズレを検出する。
final class MintLevelTests: XCTestCase {
    func testBoundaries() {
        XCTAssertEqual(MintLevel.from(averageMintIntensity: 0.0), .lv1)
        XCTAssertEqual(MintLevel.from(averageMintIntensity: 1.49), .lv1)
        XCTAssertEqual(MintLevel.from(averageMintIntensity: 1.5), .lv2)
        XCTAssertEqual(MintLevel.from(averageMintIntensity: 2.5), .lv3)
        XCTAssertEqual(MintLevel.from(averageMintIntensity: 3.5), .lv4)
        XCTAssertEqual(MintLevel.from(averageMintIntensity: 4.5), .lv5)
        XCTAssertEqual(MintLevel.from(averageMintIntensity: 5.0), .lv5)
    }

    func testNilWhenNoReviews() {
        XCTAssertNil(MintLevel.from(averageMintIntensity: nil))
    }
}

final class SightingFreshnessTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    private func hoursAgo(_ hours: Double) -> Date {
        now.addingTimeInterval(-hours * 3600)
    }

    func testClassification() {
        XCTAssertEqual(SightingFreshness.from(lastSeenAt: hoursAgo(1), now: now), .today)
        XCTAssertEqual(SightingFreshness.from(lastSeenAt: hoursAgo(23), now: now), .today)
        XCTAssertEqual(SightingFreshness.from(lastSeenAt: hoursAgo(25), now: now), .recent)
        XCTAssertEqual(SightingFreshness.from(lastSeenAt: hoursAgo(24 * 6), now: now), .recent)
        XCTAssertEqual(SightingFreshness.from(lastSeenAt: hoursAgo(24 * 10), now: now), .past)
        XCTAssertEqual(SightingFreshness.from(lastSeenAt: hoursAgo(24 * 40), now: now), .stale)
        XCTAssertEqual(SightingFreshness.from(lastSeenAt: nil, now: now), .unknown)
    }

    /// 30 日を超えたものは地図にも一覧にも出さない。
    func testVisibility() {
        XCTAssertTrue(SightingFreshness.today.isVisible)
        XCTAssertTrue(SightingFreshness.recent.isVisible)
        XCTAssertTrue(SightingFreshness.past.isVisible)
        XCTAssertFalse(SightingFreshness.stale.isVisible)
        XCTAssertFalse(SightingFreshness.unknown.isVisible)
    }
}

final class MintPartyTypeTests: XCTestCase {
    func testBeginnerUntilFiveReviews() {
        let stats = TasteStats(reviewCount: 4, tastedCount: 20, avgMint: 5, avgChocolate: 5, avgFreshness: 5)
        XCTAssertEqual(MintPartyType.evaluate(stats), .beginner)
    }

    func testStrongMint() {
        let stats = TasteStats(reviewCount: 10, tastedCount: 10, avgMint: 4.6, avgChocolate: 3.0, avgFreshness: 4.0)
        XCTAssertEqual(MintPartyType.evaluate(stats), .strongMint)
    }

    func testChocolateFirst() {
        let stats = TasteStats(reviewCount: 10, tastedCount: 10, avgMint: 2.8, avgChocolate: 4.4, avgFreshness: 3.0)
        XCTAssertEqual(MintPartyType.evaluate(stats), .chocolateFirst)
    }

    func testRefreshing() {
        let stats = TasteStats(reviewCount: 10, tastedCount: 10, avgMint: 3.5, avgChocolate: 3.0, avgFreshness: 4.5)
        XCTAssertEqual(MintPartyType.evaluate(stats), .refreshing)
    }

    func testMasterTakesPriorityOverTendency() {
        let stats = TasteStats(reviewCount: 30, tastedCount: 50, avgMint: 4.9, avgChocolate: 3.0, avgFreshness: 4.0)
        XCTAssertEqual(MintPartyType.evaluate(stats), .master)
    }

    func testBalancedFallback() {
        let stats = TasteStats(reviewCount: 8, tastedCount: 8, avgMint: 3.2, avgChocolate: 3.4, avgFreshness: 3.1)
        XCTAssertEqual(MintPartyType.evaluate(stats), .balanced)
    }
}

final class ProductFilterTests: XCTestCase {
    func testActiveCount() {
        var filter = ProductFilter()
        XCTAssertTrue(filter.isEmpty)
        filter.categories.insert(.ice)
        filter.chains.insert(.sevenEleven)
        filter.limitedOnly = true
        XCTAssertEqual(filter.activeCount, 3)
        XCTAssertFalse(filter.isEmpty)
    }

    /// クリアしてもキーワードは残す（検索語を打ち直させないため）。
    func testResetKeepsKeyword() {
        var filter = ProductFilter(keyword: "ミント")
        filter.categories.insert(.ice)
        filter.reset()
        XCTAssertEqual(filter.keyword, "ミント")
        XCTAssertTrue(filter.isEmpty)
    }
}

final class StorePinTests: XCTestCase {
    private func row(store: Int, product: Int, hoursAgo: Double) -> NearbyStoreProduct {
        NearbyStoreProduct(
            storeId: SampleData.id(store),
            storeName: "店舗\(store)",
            chainName: .sevenEleven,
            latitude: 35.66,
            longitude: 139.70,
            distanceM: Double(store) * 100,
            productId: SampleData.id(product),
            productName: "商品\(product)",
            imageUrl: nil,
            lastSeenAt: Date().addingTimeInterval(-hoursAgo * 3600),
            freshness: SightingFreshness.from(lastSeenAt: Date().addingTimeInterval(-hoursAgo * 3600))
        )
    }

    /// 同じ店舗の複数商品は 1 本のピンにまとまる。
    func testGrouping() {
        let pins = StorePin.group([
            row(store: 1, product: 10, hoursAgo: 1),
            row(store: 1, product: 11, hoursAgo: 100),
            row(store: 2, product: 10, hoursAgo: 5),
        ])
        XCTAssertEqual(pins.count, 2)
        XCTAssertEqual(pins.first?.items.count, 2)
    }

    /// ピンの色は店舗内で最も新しい目撃に合わせる。
    func testFreshnessUsesNewestSighting() {
        let pin = StorePin.group([
            row(store: 1, product: 10, hoursAgo: 24 * 10),
            row(store: 1, product: 11, hoursAgo: 2),
        ]).first
        XCTAssertEqual(pin?.freshness, .today)
    }

    func testSortedByDistance() {
        let pins = StorePin.group([
            row(store: 3, product: 10, hoursAgo: 1),
            row(store: 1, product: 10, hoursAgo: 1),
        ])
        XCTAssertEqual(pins.map(\.distanceM), [100, 300])
    }
}

final class SampleBackendTests: XCTestCase {
    /// 目撃報告 → 店舗の商品一覧に反映されるところまで。
    func testReportSightingFlow() async throws {
        let backend = SampleBackend()
        _ = try await backend.signInWithApple(idToken: "t", nonce: "n", suggestedName: "テスト")

        let newProducts = try await backend.newProducts(limit: 1)
        let product = try XCTUnwrap(newProducts.first)
        let candidate = StoreCandidate(
            id: "test-store",
            name: "テストストア",
            address: "東京都渋谷区",
            latitude: 35.6600,
            longitude: 139.7000,
            chainName: .familymart,
            externalSource: "mapkit",
            externalStoreId: "test-store",
            distance: 100
        )

        let result = try await backend.report(SightingReport(productId: product.id, candidate: candidate))
        guard case .recorded = result else {
            return XCTFail("報告が記録されなかった: \(result)")
        }

        // 同じ日に同じ組み合わせをもう一度報告しても増えない
        let second = try await backend.report(SightingReport(productId: product.id, candidate: candidate))
        XCTAssertEqual(second, .alreadyReportedToday)
    }

    func testReportRequiresSignIn() async {
        let backend = SampleBackend()
        let candidate = StoreCandidate(
            id: "x", name: "店", address: nil, latitude: 35.0, longitude: 139.0,
            chainName: nil, externalSource: "mapkit", externalStoreId: "x", distance: nil
        )
        do {
            _ = try await backend.report(SightingReport(productId: SampleData.id(1), candidate: candidate))
            XCTFail("未ログインでも報告できてしまった")
        } catch {
            XCTAssertEqual(error as? BackendError, .authenticationRequired)
        }
    }

    /// レビューを投稿すると商品のミントレベルが再計算される。
    func testReviewUpdatesMintLevel() async throws {
        let backend = SampleBackend()
        let user = try await backend.signInWithApple(idToken: "t", nonce: "n", suggestedName: nil)
        let productId = SampleData.id(10)  // レビュー 0 件の商品

        var draft = ReviewDraft()
        draft.overallRating = 5
        draft.mintIntensity = 5
        try await backend.submit(productId: productId, draft: draft, userId: user.id)

        let updated = try await backend.product(id: productId)
        XCTAssertEqual(updated?.reviewCount, 1)
        XCTAssertEqual(updated?.mintLevel, .lv5)
    }
}

extension SightingReportResult: @retroactive Equatable {
    public static func == (lhs: SightingReportResult, rhs: SightingReportResult) -> Bool {
        switch (lhs, rhs) {
        case let (.recorded(a), .recorded(b)): a == b
        case (.alreadyReportedToday, .alreadyReportedToday): true
        default: false
        }
    }
}
