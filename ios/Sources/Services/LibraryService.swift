import Foundation

struct SupabaseLibraryService: LibraryServing {
    let client: SupabaseClient

    func tasted(userId: UUID) async throws -> [TastedEntry] {
        let query = PostgRESTQuery("tasted_products")
            .select("tasted_at,tasted_count,product:products(*)")
            .eq("user_id", userId)
            .appending(URLQueryItem(name: "order", value: "tasted_at.desc"))
        return try await client.fetch(query, as: [TastedEntry].self)
    }

    func wishlist(userId: UUID) async throws -> [WishlistEntry] {
        let query = PostgRESTQuery("wishlists")
            .select("created_at,product:products(*)")
            .eq("user_id", userId)
            .appending(URLQueryItem(name: "order", value: "created_at.desc"))
        return try await client.fetch(query, as: [WishlistEntry].self)
    }

    func setTasted(_ tasted: Bool, productId: UUID, userId: UUID) async throws {
        if tasted {
            try await client.insertIgnoringResult(
                into: "tasted_products",
                body: TastedPayload(userId: userId, productId: productId),
                onConflict: "user_id,product_id",
                ignoreDuplicates: true
            )
        } else {
            try await client.delete(
                from: "tasted_products",
                matching: PostgRESTQuery("tasted_products")
                    .eq("user_id", userId)
                    .eq("product_id", productId)
            )
        }
    }

    func setWishlisted(_ wishlisted: Bool, productId: UUID, userId: UUID) async throws {
        if wishlisted {
            try await client.insertIgnoringResult(
                into: "wishlists",
                body: WishlistPayload(userId: userId, productId: productId),
                onConflict: "user_id,product_id",
                ignoreDuplicates: true
            )
        } else {
            try await client.delete(
                from: "wishlists",
                matching: PostgRESTQuery("wishlists")
                    .eq("user_id", userId)
                    .eq("product_id", productId)
            )
        }
    }

    /// 商品詳細のボタン状態。3 つの問い合わせは互いに独立なので同時に投げる。
    func state(productId: UUID, userId: UUID) async throws -> ProductUserState {
        async let tastedRows = client.fetch(
            PostgRESTQuery("tasted_products")
                .select("product_id").eq("user_id", userId).eq("product_id", productId),
            as: [IdRow].self
        )
        async let wishRows = client.fetch(
            PostgRESTQuery("wishlists")
                .select("product_id").eq("user_id", userId).eq("product_id", productId),
            as: [IdRow].self
        )
        async let review = client.fetchOne(
            PostgRESTQuery("reviews")
                .select(SupabaseReviewService.columns)
                .eq("user_id", userId).eq("product_id", productId),
            as: Review.self
        )
        return try await ProductUserState(
            isTasted: !tastedRows.isEmpty,
            isWishlisted: !wishRows.isEmpty,
            myReview: review
        )
    }

    func tasteStats(userId: UUID) async throws -> TasteStats {
        let rows: [TasteStats] = try await client.rpc(
            "user_taste_stats",
            params: ["p_user_id": JSONValue(userId)],
            as: [TasteStats].self
        )
        return rows.first ?? .empty
    }

    func collectionProgress(userId: UUID) async throws -> [CollectionProgress] {
        try await client.rpc(
            "collection_progress",
            params: ["p_user_id": JSONValue(userId)],
            as: [CollectionProgress].self
        )
    }

    /// 指定した発売年の商品全部に、自分が食べたかどうかを重ねて返す。
    func collectionSlots(userId: UUID, year: Int) async throws -> [CollectionSlot] {
        let query = PostgRESTQuery("products")
            .select()
            .isTrue("is_published")
            .gte("release_date", "\(year)-01-01")
            .lte("release_date", "\(year)-12-31")
            .appending(URLQueryItem(name: "order", value: "release_date.asc"))
        async let products = client.fetch(query, as: [Product].self)
        async let tastedRows = client.fetch(
            PostgRESTQuery("tasted_products").select("product_id").eq("user_id", userId),
            as: [IdRow].self
        )
        let tastedIds = Set(try await tastedRows.map(\.productId))
        return try await products.map { CollectionSlot(product: $0, isTasted: tastedIds.contains($0.id)) }
    }

    private struct TastedPayload: Encodable, Sendable {
        let userId: UUID
        let productId: UUID
    }

    private struct WishlistPayload: Encodable, Sendable {
        let userId: UUID
        let productId: UUID
    }

    private struct IdRow: Decodable, Sendable {
        let productId: UUID
    }
}
