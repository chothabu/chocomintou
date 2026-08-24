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
    /// 近くにある、取り扱いチェーンの店舗。目撃情報とは別枠で出す。
    var chainStores: [ChainStore] = []
    var isLoading = false
    var errorMessage: String?
    /// 検索したが 0 件だった状態。初期表示と区別する。
    var hasSearched = false

    private var searchTask: Task<Void, Never>?
    private let storeSearch = StoreSearchService()
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
                await loadChainStores(services: services, coordinate: coordinate, keyword: keyword)
            }
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? "検索に失敗しました。"
        }
    }

    /// 近くの店舗のうち、公式サイトで取り扱いを確認できたチェーンのものを拾う。
    ///
    /// 「そのチェーンで売っている」という事実と「その店に今ある」は別なので、
    /// 目撃情報の一覧とは混ぜずに分けて持つ。
    private func loadChainStores(
        services: AppServices,
        coordinate: CLLocationCoordinate2D?,
        keyword: String
    ) async {
        guard let coordinate else {
            chainStores = []
            return
        }
        guard let offerings = try? await services.stores.chainOfferings(), !offerings.isEmpty else {
            chainStores = []
            return
        }
        let nearby = (try? await storeSearch.nearbyStores(around: coordinate, radiusMeters: 3000)) ?? []

        // 目撃情報として既に出ている店舗は重複させない
        let alreadyListed = Set(stores.map(\.storeName))

        var matched: [ChainStore] = []
        for candidate in nearby where !alreadyListed.contains(candidate.name) {
            guard let offering = offerings.first(where: { Self.matches(candidate.name, chain: $0.chainName) })
            else { continue }
            if !keyword.isEmpty {
                let hit = candidate.name.localizedCaseInsensitiveContains(keyword)
                    || offering.products.contains { $0.name.localizedCaseInsensitiveContains(keyword) }
                guard hit else { continue }
            }
            matched.append(ChainStore(candidate: candidate, offering: offering))
        }
        chainStores = matched
    }

    /// 店名がそのチェーンのものか。
    ///
    /// 地図から返る店名は「ローソン 渋谷○○店」のように支店名が付くので、
    /// チェーン名を含むかで判定する。表記ゆれを吸収するため空白と中黒は落とす。
    static func matches(_ storeName: String, chain: String) -> Bool {
        func normalize(_ text: String) -> String {
            text.replacingOccurrences(of: " ", with: "")
                .replacingOccurrences(of: "　", with: "")
                .replacingOccurrences(of: "・", with: "")
                .replacingOccurrences(of: "-", with: "")
                .lowercased()
        }
        return normalize(storeName).contains(normalize(chain))
    }
}
