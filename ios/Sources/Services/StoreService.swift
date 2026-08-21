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
