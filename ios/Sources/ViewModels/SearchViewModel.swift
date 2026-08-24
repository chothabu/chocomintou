import CoreLocation
import Foundation

/// 「探す」画面。商品と店舗を切り替える（設計 §5）。
@MainActor
@Observable
final class SearchViewModel {
    enum Mode: String, CaseIterable, Identifiable {
        case products, stores
        var id: String { rawValue }
        var displayName: String {
            switch self {
            case .products: "商品"
            case .stores: "店舗"
            }
        }
    }

    var mode: Mode = .products
    var filter = ProductFilter()
    var products: [Product] = []
    var stores: [StorePin] = []
    var isLoading = false
    var errorMessage: String?
    /// 検索したが 0 件だった状態。初期表示と区別する。
    var hasSearched = false

    private var searchTask: Task<Void, Never>?
    private static let pageSize = 40

    /// 入力のたびに投げると通信が増えるので、少し待ってからまとめて実行する。
    func scheduleSearch(services: AppServices, coordinate: CLLocationCoordinate2D?) {
        searchTask?.cancel()
        searchTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }
            await self?.search(services: services, coordinate: coordinate)
        }
    }

    func search(services: AppServices, coordinate: CLLocationCoordinate2D?) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false; hasSearched = true }

        do {
            switch mode {
            case .products:
                products = try await services.products.products(
                    filter: filter, limit: Self.pageSize, offset: 0
                )
            case .stores:
                // 距離では絞らない。目撃情報のある店は全国どこでも一覧する
                // （現在地が分かれば距離を添えて近い順に並べ替える）。
                let rows = try await services.stores.recentlySeen(
                    coordinate: coordinate, limit: Self.pageSize
                )
                let keyword = filter.keyword.trimmingCharacters(in: .whitespacesAndNewlines)
                // 店名でも商品名でも引けるようにする
                let matched = keyword.isEmpty
                    ? rows
                    : rows.filter {
                        $0.storeName.localizedCaseInsensitiveContains(keyword)
                            || $0.productName.localizedCaseInsensitiveContains(keyword)
                    }
                stores = StorePin.group(matched)
            }
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? "検索に失敗しました。"
        }
    }
}
