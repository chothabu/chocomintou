import Foundation

/// 商品。**店舗情報を一切持たない**（設計 §2）。
/// 店舗との関係は Sighting を介してのみ表現される。
///
/// プロパティ名は `JSONCoding` の `.convertFromSnakeCase` が生成する形に合わせている
/// （`image_url` → `imageUrl`）。DB の列名との対応を目で追えるようにするための割り切り。
struct Product: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    var name: String
    var manufacturer: String?
    var description: String?

    var category: ProductCategory
    var imageUrl: URL?
    var price: Int?

    var releaseDate: Date?
    var endDate: Date?
    var saleStatus: SaleStatus
    var isLimited: Bool

    /// メーカー公式告知に基づく表示用テキスト。実在店舗とは結合しない（例:「全国のファミリーマート」）。
    var salesChannelText: String?
    var officialUrl: URL?

    // レビュー集計（DB トリガで更新される非正規化列）
    var reviewCount: Int
    var avgOverall: Double?
    var avgMint: Double?
    var avgChocolate: Double?
    var avgSweetness: Double?
    var avgFreshness: Double?
    var mintLevel: MintLevel?

    var createdAt: Date?
    var updatedAt: Date?

    /// 発売年。図鑑の年別分類に使う。
    var releaseYear: Int? {
        guard let releaseDate else { return nil }
        return Calendar.japanese.component(.year, from: releaseDate)
    }

    var isRatingAvailable: Bool { reviewCount > 0 && avgOverall != nil }

    /// 「期間限定」「販売中」などのバッジ表示用。
    var badges: [String] {
        var result: [String] = [saleStatus.displayName]
        if isLimited { result.append("期間限定") }
        return result
    }
}

/// 商品 × 販売チェーン。検索フィルタの「チェーン」絞り込みに使う。
struct ProductChannel: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    var productId: UUID
    var chainName: ChainName
    var area: String?
}

/// 商品検索の絞り込み条件（設計 §7）。
struct ProductFilter: Equatable, Sendable {
    var keyword: String = ""
    var saleStatuses: Set<SaleStatus> = []
    var limitedOnly: Bool = false
    var mintLevels: Set<MintLevel> = []
    var categories: Set<ProductCategory> = []
    var chains: Set<ChainName> = []

    var isEmpty: Bool {
        saleStatuses.isEmpty && !limitedOnly && mintLevels.isEmpty
            && categories.isEmpty && chains.isEmpty
    }

    /// 絞り込みバッジに出す件数。
    var activeCount: Int {
        saleStatuses.count + mintLevels.count + categories.count + chains.count
            + (limitedOnly ? 1 : 0)
    }

    mutating func reset() { self = ProductFilter(keyword: keyword) }
}

extension Calendar {
    /// 図鑑の年区切りは日本時間で判定する。
    static let japanese: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Tokyo") ?? .current
        calendar.locale = Locale(identifier: "ja_JP")
        return calendar
    }()
}
