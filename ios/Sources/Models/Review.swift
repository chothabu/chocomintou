import Foundation

/// レビュー。1 ユーザー 1 商品につき 1 件。
struct Review: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    var userId: UUID
    var productId: UUID

    /// 必須。1〜5。
    var overallRating: Int

    // 以下は任意入力
    var mintIntensity: Int?
    var chocolateIntensity: Int?
    var sweetness: Int?
    var freshness: Int?
    /// ザクザク感・口どけなどの食感
    var texture: Int?
    var comment: String?

    var helpfulCount: Int
    var createdAt: Date
    var updatedAt: Date?

    /// `users` を埋め込んで取得した投稿者。
    var author: ReviewAuthor?

    /// レビュー投稿者の公開情報。本名・住所などは保持しない。
    struct ReviewAuthor: Codable, Hashable, Sendable {
        var id: UUID
        var displayName: String
    }

    var authorName: String { author?.displayName ?? "名無しのチョコミン党" }
}

/// レビューの入力内容。総合評価のみ必須。
struct ReviewDraft: Equatable, Sendable {
    var overallRating: Int = 0
    var mintIntensity: Int = 0
    var chocolateIntensity: Int = 0
    var sweetness: Int = 0
    var freshness: Int = 0
    var texture: Int = 0
    var comment: String = ""

    static let commentLimit = 500

    var isValid: Bool {
        (1...5).contains(overallRating) && comment.count <= Self.commentLimit
    }

    init() {}

    /// 編集時は既存のレビューから初期化する。
    init(review: Review) {
        overallRating = review.overallRating
        mintIntensity = review.mintIntensity ?? 0
        chocolateIntensity = review.chocolateIntensity ?? 0
        sweetness = review.sweetness ?? 0
        freshness = review.freshness ?? 0
        texture = review.texture ?? 0
        comment = review.comment ?? ""
    }

    /// 0 は「未入力」を表すので null に落とす。
    func optionalValue(_ value: Int) -> Int? { value == 0 ? nil : value }
}

/// レビューの通報。
struct ReviewReportDraft: Equatable, Sendable {
    var reason: ReportReason = .spam
    var detail: String = ""
}
