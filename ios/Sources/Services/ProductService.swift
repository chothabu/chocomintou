import Foundation

struct SupabaseProductService: ProductServing {
    let client: SupabaseClient

    func products(filter: ProductFilter, limit: Int, offset: Int) async throws -> [Product] {
        // チェーン絞り込みは product_channels との内部結合で行う。
        // 結合しない場合に `!inner` を付けると、チェーン情報が未登録の商品が消えてしまう。
        let needsChannelJoin = !filter.chains.isEmpty
        var query = PostgRESTQuery("products")
            .select(needsChannelJoin ? "*,product_channels!inner(chain_name)" : "*")
            .isTrue("is_published")

        let keyword = filter.keyword.trimmingCharacters(in: .whitespacesAndNewlines)
        if !keyword.isEmpty {
            query = query.orILike(["name", "manufacturer", "description"], contains: keyword)
        }
        if !filter.categories.isEmpty {
            query = query.inList("category", filter.categories.map(\.rawValue))
        }
        if !filter.saleStatuses.isEmpty {
            query = query.inList("sale_status", filter.saleStatuses.map(\.rawValue))
        }
        if filter.limitedOnly {
            query = query.isTrue("is_limited")
        }
        if !filter.mintLevels.isEmpty {
            query = query.inList("mint_level", filter.mintLevels.map { String($0.rawValue) })
        }
        if needsChannelJoin {
            query = query.inList("product_channels.chain_name", filter.chains.map(\.rawValue))
        }

        query = query
            .appending(URLQueryItem(name: "order", value: "release_date.desc.nullslast,name.asc"))
            .limit(limit)
            .offset(offset)

        return try await client.fetch(query, as: [Product].self)
    }

    func product(id: UUID) async throws -> Product? {
        try await client.fetchOne(
            PostgRESTQuery("products").select().eq("id", id).isTrue("is_published"),
            as: Product.self
        )
    }

    func newProducts(limit: Int) async throws -> [Product] {
        let query = PostgRESTQuery("products")
            .select()
            .isTrue("is_published")
            .not("sale_status", "eq", SaleStatus.ended.rawValue)
            .not("release_date", "is", "null")
            .appending(URLQueryItem(name: "order", value: "release_date.desc"))
            .limit(limit)
        return try await client.fetch(query, as: [Product].self)
    }

    func ranking(days: Int, limit: Int) async throws -> [Product] {
        try await client.rpc(
            "products_ranking",
            params: ["p_days": .int(days), "p_limit": .int(limit)],
            as: [Product].self
        )
    }

    func submitProduct(_ draft: ProductSubmissionDraft, userId: UUID) async throws {
        let payload = SubmissionPayload(
            userId: userId,
            name: draft.name.trimmingCharacters(in: .whitespacesAndNewlines),
            manufacturer: draft.manufacturer.nilIfBlank,
            category: draft.category.rawValue,
            price: Int(draft.price),
            releaseDate: draft.releaseDate.map(PostgresDate.dateOnlyString(from:)),
            purchasePlace: draft.purchasePlace.nilIfBlank,
            note: draft.note.nilIfBlank
        )
        try await client.insertIgnoringResult(into: "product_submissions", body: payload)
    }

    private struct SubmissionPayload: Encodable, Sendable {
        let userId: UUID
        let name: String
        let manufacturer: String?
        let category: String
        let price: Int?
        let releaseDate: String?
        let purchasePlace: String?
        let note: String?
    }
}

extension String {
    /// 空白だけの入力を null として送るための変換。
    var nilIfBlank: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
