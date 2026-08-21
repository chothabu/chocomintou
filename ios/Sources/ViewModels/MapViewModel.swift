import CoreLocation
import Foundation

@MainActor
@Observable
final class MapViewModel {
    var pins: [StorePin] = []
    var selectedPin: StorePin?
    var onSaleOnly = true
    var isLoading = false
    var errorMessage: String?
    /// 地図を動かしたあと、まだ再検索していない状態。
    var needsResearch = false

    private var lastSearchedCenter: CLLocationCoordinate2D?

    func search(
        services: AppServices,
        center: CLLocationCoordinate2D,
        radiusMeters: Double
    ) async {
        isLoading = true
        errorMessage = nil
        needsResearch = false
        defer { isLoading = false }

        do {
            let rows = try await services.stores.nearby(
                coordinate: center,
                radiusMeters: max(500, min(radiusMeters, 20000)),
                productId: nil,
                onSaleOnly: onSaleOnly
            )
            pins = StorePin.group(rows)
            lastSearchedCenter = center
            // 選択中のピンが結果から消えたら閉じる
            if let selected = selectedPin, !pins.contains(where: { $0.storeId == selected.storeId }) {
                selectedPin = nil
            }
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? "地図の情報を取得できませんでした。"
        }
    }

    /// 前回の検索地点から十分離れたら「このエリアで検索」を出す。
    func cameraMoved(to center: CLLocationCoordinate2D) {
        guard let last = lastSearchedCenter else {
            needsResearch = false
            return
        }
        let distance = CLLocation(latitude: last.latitude, longitude: last.longitude)
            .distance(from: CLLocation(latitude: center.latitude, longitude: center.longitude))
        needsResearch = distance > 800
    }
}
