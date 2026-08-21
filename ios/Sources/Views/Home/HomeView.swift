import SwiftUI
import SwiftData

/// ホーム。「今何があるのか」を見る場所（設計 §4）。
struct HomeView: View {
    @Environment(SessionStore.self) private var session
    @Environment(LocationService.self) private var location
    @Environment(\.modelContext) private var modelContext

    @State private var model = HomeViewModel()
    @State private var path = NavigationPath()
    @State private var openedArticle: NewsArticle?

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: Metrics.sectionSpacing) {
                    if model.isShowingCache {
                        cacheNotice
                    }

                    NearbySection(items: model.nearby, isLocationDenied: location.isDenied) {
                        location.requestAuthorization()
                    }

                    NewProductsSection(products: model.newProducts)

                    RankingSection(products: model.ranking)

                    recentSightingsSection

                    newsSection
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("チョコミン党")
            .refreshable { await reload() }
            .appNavigationDestinations()
            .task {
                await model.loadIfNeeded(
                    services: session.services,
                    coordinate: location.coordinate,
                    cache: CacheStore(context: modelContext)
                )
            }
            // 位置情報が後から許可されたら、近くのセクションだけ取り直す。
            .onChange(of: location.coordinate?.latitude) { _, _ in
                Task { await reload() }
            }
            .sheet(item: $openedArticle) { article in
                SafariView(url: article.articleUrl)
                    .ignoresSafeArea()
            }
        }
    }

    private var cacheNotice: some View {
        Label("通信できないため、前回取得した内容を表示しています。", systemImage: "wifi.slash")
            .font(.caption)
            .foregroundStyle(.secondary)
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .cardBackground()
    }

    // MARK: - 最近の目撃情報

    private var recentSightingsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader("最近見つかったチョコミント")

            if model.sightings.isEmpty {
                EmptyStateView(
                    symbol: "eye",
                    title: "まだ目撃情報がありません",
                    message: "お店でチョコミントを見つけたら、商品ページから報告できます。"
                )
                .cardBackground()
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(model.sightings.enumerated()), id: \.element.id) { index, entry in
                        NavigationLink(value: AppRoute.store(entry.store.id)) {
                            sightingRow(entry)
                        }
                        .buttonStyle(.plain)
                        if index < model.sightings.count - 1 {
                            Divider().padding(.leading, 12)
                        }
                    }
                }
                .cardBackground()
            }
        }
    }

    private func sightingRow(_ entry: SightingEntry) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(Formatters.relative(entry.foundAt))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if entry.isOfficial {
                        Text("運営が確認")
                            .font(.caption2)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(Palette.paleMint, in: Capsule())
                            .foregroundStyle(Palette.deepMint)
                    }
                }
                Text(entry.store.name)
                    .font(.subheadline.weight(.medium))
                Text("「\(entry.product.name)」")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
            ProductThumbnail(product: entry.product, size: 44)
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(12)
        .contentShape(Rectangle())
    }

    // MARK: - ニュース

    private var newsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader("チョコミントニュース")

            if model.news.isEmpty {
                EmptyStateView(symbol: "newspaper", title: "ニュースがありません")
                    .cardBackground()
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(model.news.enumerated()), id: \.element.id) { index, article in
                        Button {
                            openedArticle = article
                        } label: {
                            NewsRow(article: article)
                        }
                        .buttonStyle(.plain)
                        if index < model.news.count - 1 {
                            Divider().padding(.leading, 12)
                        }
                    }
                }
                .cardBackground()
            }
        }
    }

    private func reload() async {
        await model.load(
            services: session.services,
            coordinate: location.coordinate,
            cache: CacheStore(context: modelContext)
        )
    }
}
