import SwiftUI

/// 「新発売」。横スクロール。
struct NewProductsSection: View {
    let products: [Product]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader("新発売")

            if products.isEmpty {
                EmptyStateView(symbol: "sparkles", title: "新商品の情報がありません")
                    .cardBackground()
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .top, spacing: 14) {
                        ForEach(products) { product in
                            NavigationLink(value: AppRoute.product(product)) {
                                ProductCard(product: product, caption: caption(for: product))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 2)
                }
                .scrollClipDisabled()
            }
        }
    }

    private func caption(for product: Product) -> String? {
        guard let releaseDate = product.releaseDate else { return nil }
        let prefix = product.saleStatus == .upcoming ? "発売予定 " : ""
        return "\(prefix)\(Formatters.monthDay(releaseDate))"
    }
}
