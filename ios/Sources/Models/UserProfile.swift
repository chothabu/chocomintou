import Foundation

/// ユーザーの公開プロフィール。本名・住所・性別・メールは保持しない（設計 §45）。
struct UserProfile: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    var displayName: String
    var createdAt: Date?
}

/// 「食べた」1 件。図鑑としては複数回食べても 1 商品としてカウントする。
struct TastedEntry: Identifiable, Codable, Hashable, Sendable {
    var product: Product
    var tastedAt: Date
    var tastedCount: Int

    var id: UUID { product.id }
}

/// 「食べたい」1 件。
struct WishlistEntry: Identifiable, Codable, Hashable, Sendable {
    var product: Product
    var createdAt: Date

    var id: UUID { product.id }
}

/// 商品に対する自分の状態。商品詳細のボタン表示に使う。
struct ProductUserState: Equatable, Sendable {
    var isTasted: Bool = false
    var isWishlisted: Bool = false
    var myReview: Review?

    var hasReviewed: Bool { myReview != nil }
}

/// 図鑑の年別進捗（`collection_progress` RPC）。
struct CollectionProgress: Identifiable, Codable, Hashable, Sendable {
    var year: Int
    var tastedCount: Int
    var totalCount: Int

    var id: Int { year }

    var ratio: Double {
        guard totalCount > 0 else { return 0 }
        return Double(tastedCount) / Double(totalCount)
    }

    var percentText: String { "\(Int((ratio * 100).rounded()))%" }
}

/// 図鑑のマス 1 つ。未取得の商品はシルエット表示にする。
struct CollectionSlot: Identifiable, Hashable, Sendable {
    var product: Product
    var isTasted: Bool

    var id: UUID { product.id }
}

/// ユーザー投稿による商品報告（設計 §30）。
struct ProductSubmissionDraft: Equatable, Sendable {
    var name: String = ""
    var manufacturer: String = ""
    var category: ProductCategory = .ice
    var price: String = ""
    var releaseDate: Date?
    var purchasePlace: String = ""
    var note: String = ""

    /// 商品名のみ必須。
    var isValid: Bool { !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
}
