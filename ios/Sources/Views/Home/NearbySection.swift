import SwiftUI

/// 「近くのチョコミント」。現在地から近い順に、目撃実績のある店舗 × 商品を出す。
struct NearbySection: View {
    let items: [NearbyStoreProduct]
    let isLocationDenied: Bool
    let onRequestLocation: () -> Void

    private var visible: [NearbyStoreProduct] {
        Array(items.prefix(4))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "近くのチョコミント") {
                if !items.isEmpty {
                    Text("\(items.count)件")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if isLocationDenied {
                EmptyStateView(
                    symbol: "location.slash",
                    title: "位置情報がオフになっています",
                    message: "近くのチョコミントを表示するには、設定で位置情報の利用を許可してください。",
                    actionTitle: "設定を開く",
                    action: openSettings
                )
                .cardBackground()
            } else if items.isEmpty {
                EmptyStateView(
                    symbol: "mappin.slash",
                    title: "この辺りの目撃情報はまだありません",
                    message: "近くのお店で見つけたら報告してください。最初の 1 件があなたの街の地図を作ります。"
                )
                .cardBackground()
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(visible.enumerated()), id: \.element.id) { index, item in
                        NavigationLink(value: AppRoute.store(item.storeId)) {
                            row(item)
                        }
                        .buttonStyle(.plain)
                        if index < visible.count - 1 {
                            Divider().padding(.leading, 12)
                        }
                    }
                }
                .cardBackground()
            }
        }
    }

    private func row(_ item: NearbyStoreProduct) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(item.productName)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                Text(item.storeName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                FreshnessBadge(freshness: item.freshness)
            }
            Spacer(minLength: 0)
            VStack(alignment: .trailing, spacing: 4) {
                Text(Formatters.distance(item.distanceM))
                    .font(.footnote.weight(.medium).monospacedDigit())
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(12)
        .contentShape(Rectangle())
    }

    private func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
}
