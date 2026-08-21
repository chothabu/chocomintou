import CoreLocation
import Foundation
import MapKit

/// 目撃報告フローで、現在地周辺の店舗候補を出す。
///
/// 事前に全国の店舗マスタを持たず、報告のたびに周辺を検索して、選ばれた店舗だけを
/// サーバに登録する（設計 §6 のオンデマンド生成）。
///
/// 検索結果は自前 DB に保存する。将来 OpenStreetMap などに乗り換える余地を残すため、
/// `externalSource` に情報源を記録しておく。
struct StoreSearchService: Sendable {
    /// チョコミントが置かれうる業態に絞る。
    nonisolated(unsafe) private static let poiFilter = MKPointOfInterestFilter(including: [
        .store, .foodMarket, .bakery, .cafe, .restaurant,
    ])

    func nearbyStores(
        around coordinate: CLLocationCoordinate2D,
        radiusMeters: Double = 500
    ) async throws -> [StoreCandidate] {
        let request = MKLocalPointsOfInterestRequest(center: coordinate, radius: radiusMeters)
        request.pointOfInterestFilter = Self.poiFilter
        return try await run(request: MKLocalSearch(request: request), origin: coordinate)
    }

    /// 名前で絞り込む場合（候補に出てこない店を探すとき）。
    func searchStores(
        matching keyword: String,
        around coordinate: CLLocationCoordinate2D,
        radiusMeters: Double = 3000
    ) async throws -> [StoreCandidate] {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = keyword
        request.region = MKCoordinateRegion(
            center: coordinate,
            latitudinalMeters: radiusMeters * 2,
            longitudinalMeters: radiusMeters * 2
        )
        request.pointOfInterestFilter = Self.poiFilter
        return try await run(request: MKLocalSearch(request: request), origin: coordinate)
    }

    private func run(request search: MKLocalSearch, origin: CLLocationCoordinate2D) async throws -> [StoreCandidate] {
        let response = try await search.start()
        let originLocation = CLLocation(latitude: origin.latitude, longitude: origin.longitude)

        return response.mapItems.compactMap { item -> StoreCandidate? in
            guard let name = item.name else { return nil }
            let coordinate = item.placemark.coordinate
            let distance = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
                .distance(from: originLocation)
            let identifier = Self.identifier(for: item, name: name, coordinate: coordinate)
            return StoreCandidate(
                id: identifier,
                name: name,
                address: Self.address(from: item.placemark),
                latitude: coordinate.latitude,
                longitude: coordinate.longitude,
                chainName: ChainName.infer(from: name),
                externalSource: "mapkit",
                externalStoreId: identifier,
                distance: distance
            )
        }
        .sorted { ($0.distance ?? .greatestFiniteMagnitude) < ($1.distance ?? .greatestFiniteMagnitude) }
    }

    /// 店舗を一意に識別する値。
    ///
    /// iOS 18 以降は MapKit が安定した POI 識別子を返すので、それをそのまま使う。
    /// 取れない場合（iOS 17）だけ名前と座標から組み立てるが、この値は店舗の座標が
    /// わずかに変わるだけで別物になってしまう。
    ///
    /// 端末によって採番が混ざることになるが、サーバ側の `report_sighting` が
    /// 「同名かつ 50m 以内」でも名寄せするため、同じ店舗が重複登録されることはない。
    private static func identifier(
        for item: MKMapItem,
        name: String,
        coordinate: CLLocationCoordinate2D
    ) -> String {
        if #available(iOS 18.0, *), let identifier = item.identifier?.rawValue {
            return identifier
        }
        let lat = String(format: "%.5f", coordinate.latitude)
        let lng = String(format: "%.5f", coordinate.longitude)
        return "\(name)@\(lat),\(lng)"
    }

    private static func address(from placemark: MKPlacemark) -> String? {
        let parts = [
            placemark.administrativeArea,
            placemark.locality,
            placemark.subLocality,
            placemark.thoroughfare,
            placemark.subThoroughfare,
        ].compactMap { $0 }
        return parts.isEmpty ? nil : parts.joined()
    }
}
