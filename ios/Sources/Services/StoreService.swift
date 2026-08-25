import CoreLocation
import Foundation

struct SupabaseStoreService: StoreServing {
    let client: SupabaseClient

    /// `geog` 列は PostGIS のバイナリ表現がそのまま載ってくるので取得しない。
    static let storeColumns = "id,name,chain_name,latitude,longitude,address,external_source,external_store_id,created_at"

    func nearby(
        coordinate: CLLocationCoordinate2D,
        radiusMeters: Double,
        productId: UUID?,
        onSaleOnly: Bool
    ) async throws -> [NearbyStoreProduct] {
        try await client.rpc(
            "stores_nearby",
            params: [
                "p_lat": .double(coordinate.latitude),
                "p_lng": .double(coordinate.longitude),
                "p_radius_m": .int(Int(radiusMeters)),
                "p_product_id": JSONValue(productId),
                "p_fresh_days": .int(30),
                "p_on_sale_only": .bool(onSaleOnly),
            ],
            as: [NearbyStoreProduct].self
        )
    }

    /// 距離で絞らず、最近見つかった順に返す。
    /// `stores_nearby` は半径で絞るため、全国を一覧するにはこちらを使う。
    func recentlySeen(
        coordinate: CLLocationCoordinate2D?,
        limit: Int
    ) async throws -> [NearbyStoreProduct] {
        let cutoff = PostgresDate.iso8601.string(from: Date().addingTimeInterval(-60 * 60 * 24 * 30))
        let query = PostgRESTQuery("store_products")
            .select("last_seen_at,store:stores(\(Self.storeColumns)),product:products(*)")
            .gte("last_seen_at", cutoff)
            .appending(URLQueryItem(name: "order", value: "last_seen_at.desc"))
            .limit(limit)

        let rows = try await client.fetch(query, as: [SeenRow].self)
        return rows.compactMap { row in
            // 未公開の商品は RLS で除外され、埋め込みが null になる
            guard let store = row.store, let product = row.product else { return nil }
            guard product.saleStatus != .ended else { return nil }
            let freshness = SightingFreshness.from(lastSeenAt: row.lastSeenAt)
            guard freshness.isVisible else { return nil }
            return NearbyStoreProduct(
                storeId: store.id,
                storeName: store.name,
                chainName: store.chainName,
                latitude: store.latitude,
                longitude: store.longitude,
                distanceM: coordinate.map { store.distance(from: $0) },
                productId: product.id,
                productName: product.name,
                imageUrl: product.imageUrl,
                lastSeenAt: row.lastSeenAt,
                freshness: freshness
            )
        }
    }

    /// `store_products` に店舗と商品を埋め込んだ行。
    private struct SeenRow: Decodable, Sendable {
        let lastSeenAt: Date
        let store: Store?
        let product: Product?
    }

    /// 店内で飲食できるチェーンと、そこで食べられる商品。
    ///
    /// 小売のみのチェーンは含めない。「店舗」タブはそこで食べられる店を並べる場所で、
    /// 買うだけの商品は「商品」タブで足りるため。
    func chainOfferings() async throws -> [ChainOffering] {
        async let channelsTask = client.fetch(
            PostgRESTQuery("product_channels").select("chain_name,product:products(*)"),
            as: [ChannelRow].self
        )
        async let chainsTask = client.fetch(
            PostgRESTQuery("chains").select("name,brand_color").isTrue("is_eat_in"),
            as: [ChainRow].self
        )
        let (channels, chains) = try await (channelsTask, chainsTask)
        let colors = Dictionary(uniqueKeysWithValues: chains.map { ($0.name, $0.brandColor) })

        var grouped: [String: [Product]] = [:]
        for row in channels {
            // 店内飲食できるチェーンだけを対象にする
            guard colors.keys.contains(row.chainName) else { continue }
            // 未公開の商品は RLS で除外され、埋め込みが null になる
            guard let product = row.product, product.saleStatus != .ended else { continue }
            grouped[row.chainName, default: []].append(product)
        }
        return grouped
            .map { ChainOffering(chainName: $0.key, brandColor: colors[$0.key] ?? nil, products: $0.value) }
            .sorted { $0.chainName < $1.chainName }
    }

    private struct ChannelRow: Decodable, Sendable {
        let chainName: String
        let product: Product?
    }

    private struct ChainRow: Decodable, Sendable {
        let name: String
        let brandColor: String?
    }

    func store(id: UUID) async throws -> Store? {
        try await client.fetchOne(
            PostgRESTQuery("stores").select(Self.storeColumns).eq("id", id),
            as: Store.self
        )
    }

    func products(atStore storeId: UUID) async throws -> [StoreProductEntry] {
        let cutoff = PostgresDate.iso8601.string(from: Date().addingTimeInterval(-60 * 60 * 24 * 30))
        let query = PostgRESTQuery("store_products")
            .select("first_seen_at,last_seen_at,sighting_count,product:products(*)")
            .eq("store_id", storeId)
            .gte("last_seen_at", cutoff)
            .appending(URLQueryItem(name: "order", value: "last_seen_at.desc"))
        return try await client.fetch(query, as: [StoreProductEntry].self)
    }
}
