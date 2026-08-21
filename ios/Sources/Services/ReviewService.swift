import Foundation

struct SupabaseReviewService: ReviewServing {
    let client: SupabaseClient

    /// `users` へは reviews.user_id 経由と review_helpfuls 経由の 2 通りがあり、
    /// 関係名を指定しないと PostgREST が特定できずエラーになる（PGRST201）。
    static let columns = "*,author:users!reviews_user_id_fkey(id,display_name)"

    func reviews(productId: UUID, sort: ReviewSort, limit: Int) async throws -> [Review] {
        let order = switch sort {
        case .newest: "created_at.desc"
        case .highestRated: "overall_rating.desc,created_at.desc"
        case .mostHelpful: "helpful_count.desc,created_at.desc"
        }
        let query = PostgRESTQuery("reviews")
            .select(Self.columns)
            .eq("product_id", productId)
            .isFalse("is_hidden")
            .appending(URLQueryItem(name: "order", value: order))
            .limit(limit)
        return try await client.fetch(query, as: [Review].self)
    }

    func myReview(productId: UUID, userId: UUID) async throws -> Review? {
        try await client.fetchOne(
            PostgRESTQuery("reviews")
                .select(Self.columns)
                .eq("product_id", productId)
                .eq("user_id", userId),
            as: Review.self
        )
    }

    func myReviews(userId: UUID) async throws -> [Review] {
        let query = PostgRESTQuery("reviews")
            .select(Self.columns)
            .eq("user_id", userId)
            .appending(URLQueryItem(name: "order", value: "created_at.desc"))
        return try await client.fetch(query, as: [Review].self)
    }

    /// 1 ユーザー 1 商品 1 レビューなので、投稿も編集も UPSERT で扱う。
    func submit(productId: UUID, draft: ReviewDraft, userId: UUID) async throws {
        let payload = ReviewPayload(
            userId: userId,
            productId: productId,
            overallRating: draft.overallRating,
            mintIntensity: draft.optionalValue(draft.mintIntensity),
            chocolateIntensity: draft.optionalValue(draft.chocolateIntensity),
            sweetness: draft.optionalValue(draft.sweetness),
            freshness: draft.optionalValue(draft.freshness),
            comment: draft.comment.nilIfBlank,
            updatedAt: PostgresDate.iso8601.string(from: Date())
        )
        try await client.insertIgnoringResult(
            into: "reviews",
            body: payload,
            onConflict: "user_id,product_id"
        )
    }

    func delete(reviewId: UUID) async throws {
        try await client.delete(from: "reviews", matching: PostgRESTQuery("reviews").eq("id", reviewId))
    }

    func setHelpful(_ helpful: Bool, reviewId: UUID, userId: UUID) async throws {
        if helpful {
            try await client.insertIgnoringResult(
                into: "review_helpfuls",
                body: HelpfulPayload(reviewId: reviewId, userId: userId),
                onConflict: "review_id,user_id",
                ignoreDuplicates: true
            )
        } else {
            try await client.delete(
                from: "review_helpfuls",
                matching: PostgRESTQuery("review_helpfuls")
                    .eq("review_id", reviewId)
                    .eq("user_id", userId)
            )
        }
    }

    func report(reviewId: UUID, draft: ReviewReportDraft, userId: UUID) async throws {
        try await client.insertIgnoringResult(
            into: "review_reports",
            body: ReportPayload(
                reviewId: reviewId,
                reporterId: userId,
                reason: draft.reason.rawValue,
                detail: draft.detail.nilIfBlank
            ),
            onConflict: "review_id,reporter_id",
            ignoreDuplicates: true
        )
    }

    func block(_ blockedId: UUID, by userId: UUID) async throws {
        try await client.insertIgnoringResult(
            into: "blocked_users",
            body: BlockPayload(blockerId: userId, blockedId: blockedId),
            onConflict: "blocker_id,blocked_id",
            ignoreDuplicates: true
        )
    }

    /// ブロック済みユーザーの除外はクエリ側で行う（設計 §schema の注記）。
    func blockedUserIds(of userId: UUID) async throws -> Set<UUID> {
        let rows: [BlockedRow] = try await client.fetch(
            PostgRESTQuery("blocked_users").select("blocked_id").eq("blocker_id", userId),
            as: [BlockedRow].self
        )
        return Set(rows.map(\.blockedId))
    }

    private struct ReviewPayload: Encodable, Sendable {
        let userId: UUID
        let productId: UUID
        let overallRating: Int
        let mintIntensity: Int?
        let chocolateIntensity: Int?
        let sweetness: Int?
        let freshness: Int?
        let comment: String?
        let updatedAt: String
    }

    private struct HelpfulPayload: Encodable, Sendable {
        let reviewId: UUID
        let userId: UUID
    }

    private struct ReportPayload: Encodable, Sendable {
        let reviewId: UUID
        let reporterId: UUID
        let reason: String
        let detail: String?
    }

    private struct BlockPayload: Encodable, Sendable {
        let blockerId: UUID
        let blockedId: UUID
    }

    private struct BlockedRow: Decodable, Sendable {
        let blockedId: UUID
    }
}
