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

    /// 目撃情報がまだ無い、周辺のお店。
    ///
    /// 「ここで売っている」という情報ではない。目撃報告がゼロの地域で地図が
    /// 真っ白になるのを避け、報告先を選べるようにするためだけに出す。
    /// 在庫の主張と取り違えられないよう、表示は目撃ピンとはっきり分ける。
    var reportableStores: [StoreCandidate] = []
    var showsReportableStores = true
    var selectedReportable: StoreCandidate?

    private var lastSearchedCenter: CLLocationCoordinate2D?
    private let storeSearch = StoreSearchService()

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

        await loadReportableStores(around: center, radiusMeters: radiusMeters)
    }

    /// 周辺のお店を取り直す。目撃済みの店舗は重複するので除く。
    private func loadReportableStores(
        around center: CLLocationCoordinate2D,
        radiusMeters: Double
    ) async {
        guard showsReportableStores else {
            reportableStores = []
            return
        }
        // 広域では数が多すぎて地図が埋まるので、近距離のときだけ出す。
        guard radiusMeters <= 2000 else {
            reportableStores = []
            return
        }

        let found = (try? await storeSearch.nearbyStores(
            around: center, radiusMeters: min(radiusMeters, 800)
        )) ?? []

        // 密集地では同じ場所に重なって団子になるので、近い順に少しだけ出す。
        let sighted = Set(pins.map(\.storeName))
        reportableStores = found
            .filter { !sighted.contains($0.name) }
            .prefix(8)
            .map { $0 }
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
