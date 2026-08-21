import Foundation

/// ユーザーのレビュー集計値。`user_taste_stats` RPC の戻り値。
struct TasteStats: Codable, Hashable, Sendable {
    var reviewCount: Int
    var tastedCount: Int
    var avgMint: Double?
    var avgChocolate: Double?
    var avgSweetness: Double?
    var avgFreshness: Double?
    var avgOverall: Double?

    static let empty = TasteStats(reviewCount: 0, tastedCount: 0)

    init(
        reviewCount: Int,
        tastedCount: Int,
        avgMint: Double? = nil,
        avgChocolate: Double? = nil,
        avgSweetness: Double? = nil,
        avgFreshness: Double? = nil,
        avgOverall: Double? = nil
    ) {
        self.reviewCount = reviewCount
        self.tastedCount = tastedCount
        self.avgMint = avgMint
        self.avgChocolate = avgChocolate
        self.avgSweetness = avgSweetness
        self.avgFreshness = avgFreshness
        self.avgOverall = avgOverall
    }
}

/// チョコミン党タイプ（設計 §36-37）。
/// レビューの集計値からルールベースで判定する。AI は使わない。
enum MintPartyType: String, CaseIterable, Sendable, Identifiable {
    case beginner
    case chocolateFirst
    case refreshing
    case strongMint
    case balanced
    case master

    var id: String { rawValue }

    var emoji: String {
        switch self {
        case .beginner: "🌱"
        case .chocolateFirst: "🍫"
        case .refreshing: "🍃"
        case .strongMint: "🧊"
        case .balanced: "🍀"
        case .master: "👑"
        }
    }

    var displayName: String {
        switch self {
        case .beginner: "チョコミント初心者"
        case .chocolateFirst: "チョコ重視派"
        case .refreshing: "爽快ミント派"
        case .strongMint: "強ミント派"
        case .balanced: "バランス派"
        case .master: "チョコミントマスター"
        }
    }

    var summary: String {
        switch self {
        case .beginner: "まだ始まったばかり。レビューを 5 件書くとタイプが判定されます。"
        case .chocolateFirst: "ミントよりチョコの満足感を重く見るタイプ。"
        case .refreshing: "後味の爽やかさを最重視するタイプ。"
        case .strongMint: "とにかくミントが強いものを高く評価するタイプ。"
        case .balanced: "ミントとチョコの均衡を見るタイプ。"
        case .master: "食べた数もレビュー数も突き抜けた領域。"
        }
    }

    /// 判定ルール。上から順に評価し、最初に当てはまったものを採用する。
    ///
    /// 判定の重みづけは意図的に単純にしてある。ユーザーが自分の結果を見て
    /// 「なぜそうなったか」を推測できることを、分類の精度より優先している。
    static func evaluate(_ stats: TasteStats) -> MintPartyType {
        // レビューが少ないうちは傾向と呼べるものが出ないので判定しない
        guard stats.reviewCount >= 5 else { return .beginner }

        if stats.tastedCount >= 50 && stats.reviewCount >= 30 { return .master }

        let mint = stats.avgMint ?? 0
        let chocolate = stats.avgChocolate ?? 0
        let freshness = stats.avgFreshness ?? 0

        if mint >= 4.3 { return .strongMint }
        if chocolate >= 4.0 && chocolate > mint { return .chocolateFirst }
        if freshness >= 4.3 { return .refreshing }
        return .balanced
    }
}
