import SwiftUI

/// 画面遷移先。タブをまたいで同じ遷移を使い回せるよう 1 か所にまとめる。
enum AppRoute: Hashable {
    case product(Product)
    case productId(UUID)
    case store(UUID)
    case reviews(Product)
    case collection(year: Int)
    case tasted
    case wishlist
    case myReviews
    case sightingHistory
    case settings
}

extension View {
    /// NavigationStack の中身に付ける。全画面で同じ遷移先を解決できるようにする。
    func appNavigationDestinations() -> some View {
        navigationDestination(for: AppRoute.self) { route in
            switch route {
            case let .product(product):
                ProductDetailView(product: product)
            case let .productId(id):
                ProductDetailView(productId: id)
            case let .store(id):
                StoreDetailView(storeId: id)
            case let .reviews(product):
                ReviewListView(product: product)
            case let .collection(year):
                CollectionView(year: year)
            case .tasted:
                TastedView()
            case .wishlist:
                WishlistView()
            case .myReviews:
                MyReviewsView()
            case .sightingHistory:
                SightingHistoryView()
            case .settings:
                SettingsView()
            }
        }
    }
}
