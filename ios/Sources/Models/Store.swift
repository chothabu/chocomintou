import CoreLocation
import Foundation

/// 店舗。**商品情報を一切持たない**（設計 §2）。
/// コンビニも個人経営のカフェも同じ型で扱う。
struct Store: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    var name: String
    var chainName: ChainName?
    var latitude: Double
    var longitude: Double
    var address: String?

    /// 後からソースを差し替え・重複統合できるよう必ず記録する。
    var externalSource: String
    var externalStoreId: String?
    var createdAt: Date?

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    func distance(from coordinate: CLLocationCoordinate2D) -> CLLocationDistance {
        CLLocation(latitude: latitude, longitude: longitude)
            .distance(from: CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude))
    }
}

/// 目撃報告フローで選ぶ店舗候補。MKLocalSearch の結果、または既存の Store から作る。
/// この時点ではまだ DB に登録されていない（報告時に `report_sighting` がまとめて登録する）。
struct StoreCandidate: Identifiable, Hashable, Sendable {
    var id: String
    var name: String
    var address: String?
    var latitude: Double
    var longitude: Double
    var chainName: ChainName?
    var externalSource: String
    var externalStoreId: String?
    var distance: CLLocationDistance?

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

/// 店舗詳細の「この店舗で見つかった商品」1 行分。
/// `store_products`（sightings の集計キャッシュ）に商品を埋め込んだもの。
struct StoreProductEntry: Identifiable, Codable, Hashable, Sendable {
    var product: Product
    var firstSeenAt: Date
    var lastSeenAt: Date
    var sightingCount: Int

    var id: UUID { product.id }
    var freshness: SightingFreshness { .from(lastSeenAt: lastSeenAt) }
}

/// マップと「近くのチョコミント」で使う、店舗 × 商品の 1 行。
/// `stores_nearby` RPC の戻り値。
struct NearbyStoreProduct: Identifiable, Codable, Hashable, Sendable {
    var storeId: UUID
    var storeName: String
    var chainName: ChainName?
    var latitude: Double
    var longitude: Double
    var distanceM: Double
    var productId: UUID
    var productName: String
    var imageUrl: URL?
    var lastSeenAt: Date
    var freshness: SightingFreshness

    var id: String { "\(storeId.uuidString)-\(productId.uuidString)" }

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

/// マップのピン 1 本 = 1 店舗。同じ店舗の複数商品をまとめる。
struct StorePin: Identifiable, Hashable, Sendable {
    var storeId: UUID
    var storeName: String
    var chainName: ChainName?
    var latitude: Double
    var longitude: Double
    var distanceM: Double
    var items: [NearbyStoreProduct]

    var id: UUID { storeId }

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    /// 店舗内で最も新しい目撃の鮮度をピンの色に使う。
    var freshness: SightingFreshness {
        items.map(\.freshness).min(by: { rank($0) < rank($1) }) ?? .unknown
    }

    private func rank(_ freshness: SightingFreshness) -> Int {
        switch freshness {
        case .today: 0
        case .recent: 1
        case .past: 2
        case .stale: 3
        case .unknown: 4
        }
    }

    static func group(_ rows: [NearbyStoreProduct]) -> [StorePin] {
        let grouped = Dictionary(grouping: rows, by: \.storeId)
        return grouped.compactMap { _, items -> StorePin? in
            guard let first = items.first else { return nil }
            return StorePin(
                storeId: first.storeId,
                storeName: first.storeName,
                chainName: first.chainName,
                latitude: first.latitude,
                longitude: first.longitude,
                distanceM: first.distanceM,
                items: items.sorted { $0.lastSeenAt > $1.lastSeenAt }
            )
        }
        .sorted { $0.distanceM < $1.distanceM }
    }
}
