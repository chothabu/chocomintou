import SwiftUI

/// 「今人気のチョコミント」。対象期間は直近 30 日（設計 §4）。
struct RankingSection: View {
    let products: [Product]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "今人気のチョコミント") {
                Text("直近30日")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if products.isEmpty {
                EmptyStateView(
                    symbol: "chart.bar",
                    title: "まだランキングを出せません",
                    message: "レビューが集まると表示されます。"
                )
                .cardBackground()
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(products.prefix(5).enumerated()), id: \.element.id) { index, product in
                        NavigationLink(value: AppRoute.product(product)) {
                            row(rank: index + 1, product: product)
                        }
                        .buttonStyle(.plain)
                        if index < min(products.count, 5) - 1 {
                            Divider().padding(.leading, 52)
                        }
                    }
                }
                .cardBackground()
            }
        }
    }

    private func row(rank: Int, product: Product) -> some View {
        HStack(spacing: 12) {
            Text("\(rank)")
                .font(.headline.monospacedDigit())
                .foregroundStyle(rank <= 3 ? Palette.deepMint : Color.secondary)
                .frame(width: 24)

            ProductThumbnail(product: product, size: 44)

            VStack(alignment: .leading, spacing: 3) {
                Text(product.name)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(1)
                HStack(spacing: 5) {
                    if let average = product.avgOverall {
                        StarRatingView(rating: average, size: 11)
                        Text(String(format: "%.1f", average))
                            .font(.caption.monospacedDigit())
                    }
                    Text("(\(product.reviewCount))")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(12)
        .contentShape(Rectangle())
    }
}
