import MapKit
import SwiftUI

/// 店舗詳細（設計 §18）。
struct StoreDetailView: View {
    let storeId: UUID

    @Environment(SessionStore.self) private var session
    @State private var store: Store?
    @State private var entries: [StoreProductEntry] = []
    @State private var isLoading = true
    @State private var errorMessage: String?

    var body: some View {
        ScrollView {
            if let store {
                VStack(alignment: .leading, spacing: 24) {
                    mapSnippet(store)
                    header(store)
                    productsSection
                }
                .padding(16)
            } else if isLoading {
                ProgressView().padding(.top, 80)
            } else {
                ErrorStateView(message: errorMessage ?? "店舗が見つかりませんでした。") {
                    Task { await load() }
                }
                .padding(.top, 60)
            }
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(store?.name ?? "店舗")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
        .refreshable { await load() }
    }

    private func mapSnippet(_ store: Store) -> some View {
        Map(initialPosition: .region(MKCoordinateRegion(
            center: store.coordinate, latitudinalMeters: 400, longitudinalMeters: 400
        ))) {
            Marker(store.name, systemImage: "storefront", coordinate: store.coordinate)
                .tint(Palette.deepMint)
        }
        .frame(height: 160)
        .clipShape(RoundedRectangle(cornerRadius: Metrics.cardCorner, style: .continuous))
        .allowsHitTesting(false)
    }

    private func header(_ store: Store) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(store.name)
                .font(.title3.weight(.bold))
            if let chain = store.chainName {
                Text(chain.displayName)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Palette.paleMint, in: Capsule())
                    .foregroundStyle(Palette.deepMint)
            }
            if let address = store.address {
                Label(address, systemImage: "mappin.circle")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Button {
                openInMaps(store)
            } label: {
                Label("マップアプリで開く", systemImage: "arrow.triangle.turn.up.right.circle")
                    .font(.subheadline)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
    }

    private var productsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader("この店舗で見つかった商品")

            if entries.isEmpty {
                EmptyStateView(
                    symbol: "eye.slash",
                    title: "最近の目撃情報はありません",
                    message: "30 日以内に報告された商品がここに並びます。"
                )
                .cardBackground()
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(entries.enumerated()), id: \.element.id) { index, entry in
                        NavigationLink(value: AppRoute.product(entry.product)) {
                            row(entry)
                        }
                        .buttonStyle(.plain)
                        if index < entries.count - 1 {
                            Divider().padding(.leading, 12)
                        }
                    }
                }
                .cardBackground()

                Text("目撃情報はユーザーの報告です。在庫を保証するものではありません。")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
    }

    private func row(_ entry: StoreProductEntry) -> some View {
        HStack(spacing: 12) {
            ProductThumbnail(product: entry.product, size: 48)
            VStack(alignment: .leading, spacing: 4) {
                Text(entry.product.name)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(2)
                HStack(spacing: 6) {
                    FreshnessBadge(freshness: entry.freshness, showsLabel: false)
                    Text(Formatters.sightingTime(entry.lastSeenAt))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if entry.sightingCount > 1 {
                        Text("報告 \(entry.sightingCount)件")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
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

    private func openInMaps(_ store: Store) {
        let placemark = MKPlacemark(coordinate: store.coordinate)
        let item = MKMapItem(placemark: placemark)
        item.name = store.name
        item.openInMaps()
    }

    private func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            async let storeTask = session.services.stores.store(id: storeId)
            async let entriesTask = session.services.stores.products(atStore: storeId)
            store = try await storeTask
            entries = try await entriesTask
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? "読み込みに失敗しました。"
        }
    }
}
