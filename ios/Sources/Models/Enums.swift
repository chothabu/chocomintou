import Foundation

// DB の raw 値と 1:1 で対応させる。サーバ側で値が増えても落ちないよう、
// 未知の値は .other / .unknown に倒す（アプリを更新しないと表示できないだけで済む）。

/// 商品カテゴリ。`products.category`
enum ProductCategory: String, Codable, CaseIterable, Sendable, Identifiable {
    case ice, snack, cake, parfait, drink, bread, other

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .ice: "アイス"
        case .snack: "お菓子"
        case .cake: "ケーキ"
        case .parfait: "パフェ"
        case .drink: "ドリンク"
        case .bread: "パン"
        case .other: "その他"
        }
    }

    var symbolName: String {
        switch self {
        case .ice: "snowflake"
        case .snack: "bag.fill"
        case .cake: "birthday.cake"
        case .parfait: "cup.and.saucer.fill"
        case .drink: "mug.fill"
        case .bread: "fork.knife"
        case .other: "sparkles"
        }
    }

    init(from decoder: any Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = ProductCategory(rawValue: raw) ?? .other
    }
}

/// 販売状況。`products.sale_status`
enum SaleStatus: String, Codable, CaseIterable, Sendable, Identifiable {
    case onSale = "on_sale"
    case upcoming
    case ended

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .onSale: "販売中"
        case .upcoming: "発売予定"
        case .ended: "販売終了"
        }
    }

    init(from decoder: any Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = SaleStatus(rawValue: raw) ?? .onSale
    }
}

/// 販売チェーン。`stores.chain_name` / `product_channels.chain_name`
enum ChainName: String, Codable, CaseIterable, Sendable, Identifiable {
    case sevenEleven = "seven_eleven"
    case familymart
    case lawson
    case ministop
    case dailyYamazaki = "daily_yamazaki"
    case seicomart
    case other

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .sevenEleven: "セブン-イレブン"
        case .familymart: "ファミリーマート"
        case .lawson: "ローソン"
        case .ministop: "ミニストップ"
        case .dailyYamazaki: "デイリーヤマザキ"
        case .seicomart: "セイコーマート"
        case .other: "その他"
        }
    }

    /// 絞り込み UI に出すのは主要チェーンのみ。
    static var filterable: [ChainName] {
        [.sevenEleven, .familymart, .lawson, .ministop, .other]
    }

    /// 店舗名から推定する。MKLocalSearch の結果にはチェーン識別子が無いため。
    static func infer(from storeName: String) -> ChainName? {
        let name = storeName.lowercased()
        if name.contains("セブン") || name.contains("seven") { return .sevenEleven }
        if name.contains("ファミリーマート") || name.contains("ファミマ")
            || name.contains("familymart") || name.contains("family mart") { return .familymart }
        if name.contains("ローソン") || name.contains("lawson") { return .lawson }
        if name.contains("ミニストップ") || name.contains("ministop") { return .ministop }
        if name.contains("デイリーヤマザキ") { return .dailyYamazaki }
        if name.contains("セイコーマート") || name.contains("セコマ") { return .seicomart }
        return nil
    }

    init(from decoder: any Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = ChainName(rawValue: raw) ?? .other
    }
}

/// 販売場所の区分。絞り込み専用（DB 列ではなくチェーンとカテゴリから導く）。
enum SalesPlace: String, CaseIterable, Sendable, Identifiable {
    case convenience, supermarket, restaurant, cafe, onlineShop, other

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .convenience: "コンビニ"
        case .supermarket: "スーパー"
        case .restaurant: "飲食店"
        case .cafe: "カフェ"
        case .onlineShop: "通販"
        case .other: "その他"
        }
    }
}

/// チョコミントレベル。レビューのミント強度平均から算出する（`products.mint_level`）。
enum MintLevel: Int, Codable, CaseIterable, Sendable, Identifiable {
    case lv1 = 1, lv2, lv3, lv4, lv5

    var id: Int { rawValue }
    var label: String { "Lv\(rawValue)" }

    var description: String {
        switch self {
        case .lv1: "ほんのり"
        case .lv2: "控えめ"
        case .lv3: "ふつう"
        case .lv4: "かなり強め"
        case .lv5: "極ミント"
        }
    }

    /// 判定基準は設計 §9 のとおり。DB の `sync_product_stats()` と同じ境界値にする。
    static func from(averageMintIntensity average: Double?) -> MintLevel? {
        guard let average else { return nil }
        switch average {
        case ..<1.5: return .lv1
        case ..<2.5: return .lv2
        case ..<3.5: return .lv3
        case ..<4.5: return .lv4
        default: return .lv5
        }
    }
}

/// 目撃情報の鮮度。「在庫あり」ではなく「見つかりました」表現に統一するための区分。
enum SightingFreshness: String, Codable, Sendable, Hashable {
    case today, recent, past, stale
    case unknown = "none"

    /// 最終目撃からの経過で判定する。DB の `sighting_freshness()` と同じ境界値。
    static func from(lastSeenAt: Date?, now: Date = .now) -> SightingFreshness {
        guard let lastSeenAt else { return .unknown }
        let elapsed = now.timeIntervalSince(lastSeenAt)
        switch elapsed {
        case ..<(60 * 60 * 24): return .today
        case ..<(60 * 60 * 24 * 7): return .recent
        case ..<(60 * 60 * 24 * 30): return .past
        default: return .stale
        }
    }

    /// 30 日を超えたものは表示しない。
    var isVisible: Bool {
        switch self {
        case .today, .recent, .past: true
        case .stale, .unknown: false
        }
    }

    var indicator: String {
        switch self {
        case .today: "🟢"
        case .recent: "🟡"
        case .past: "⚪"
        case .stale, .unknown: "　"
        }
    }

    var label: String {
        switch self {
        case .today: "今日見つかっています"
        case .recent: "最近見つかっています"
        case .past: "過去に見つかっています"
        case .stale: "しばらく見つかっていません"
        case .unknown: "情報がありません"
        }
    }

    init(from decoder: any Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = SightingFreshness(rawValue: raw) ?? .unknown
    }
}

/// レビュー一覧の並び替え。
enum ReviewSort: String, CaseIterable, Sendable, Identifiable {
    case newest, highestRated, mostHelpful

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .newest: "新しい順"
        case .highestRated: "高評価"
        case .mostHelpful: "参考になった順"
        }
    }
}

/// レビュー通報の理由。`review_reports.reason`
enum ReportReason: String, CaseIterable, Sendable, Identifiable {
    case spam, offensive, irrelevant, falseInfo = "false_info", other

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .spam: "スパム・宣伝"
        case .offensive: "不適切な表現"
        case .irrelevant: "商品と関係がない"
        case .falseInfo: "事実と異なる"
        case .other: "その他"
        }
    }
}
