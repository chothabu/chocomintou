import SafariServices
import SwiftUI
import SwiftData

/// ニュース。新商品（アプリの商品 DB）と、外部記事の 2 本立て（設計 §23）。
struct NewsView: View {
    @Environment(SessionStore.self) private var session
    @Environment(\.modelContext) private var modelContext

    @State private var tab: NewsTab = .newProducts
    @State private var newProducts: [Product] = []
    @State private var articles: [NewsArticle] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var openedArticle: NewsArticle?

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("種類", selection: $tab) {
                    ForEach(NewsTab.allCases) { item in
                        Text(item.displayName).tag(item)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 16)
                .padding(.bottom, 8)

                if tab == .newProducts {
                    newProductList
                } else {
                    articleList
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("ニュース")
            .appNavigationDestinations()
            .task { await load() }
            .refreshable { await load() }
            .sheet(item: $openedArticle) { article in
                SafariView(url: article.articleUrl)
                    .ignoresSafeArea()
            }
        }
    }

    private var newProductList: some View {
        List {
            ForEach(newProducts) { product in
                NavigationLink(value: AppRoute.product(product)) {
                    VStack(alignment: .leading, spacing: 8) {
                        if let releaseDate = product.releaseDate {
                            HStack(spacing: 6) {
                                Text(product.saleStatus == .upcoming ? "発売予定" : "発売中")
                                    .font(.caption2.weight(.semibold))
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(
                                        product.saleStatus == .upcoming ? Palette.paleMint : Color(.tertiarySystemFill),
                                        in: Capsule()
                                    )
                                Text(Formatters.fullDate(releaseDate))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        ProductRow(product: product)
                    }
                    .padding(.vertical, 2)
                }
            }
        }
        .listStyle(.insetGrouped)
        .overlay {
            if newProducts.isEmpty && !isLoading {
                EmptyStateView(symbol: "sparkles", title: "新商品の情報がありません")
            }
        }
    }

    private var articleList: some View {
        List {
            if let errorMessage {
                Section { ErrorStateView(message: errorMessage) { Task { await load() } } }
            }
            ForEach(articles) { article in
                Button {
                    openedArticle = article
                } label: {
                    NewsRow(article: article)
                }
                .buttonStyle(.plain)
            }
        }
        .listStyle(.insetGrouped)
        .overlay {
            if articles.isEmpty && !isLoading && errorMessage == nil {
                EmptyStateView(symbol: "newspaper", title: "記事がありません")
            }
        }
    }

    private func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        let cache = CacheStore(context: modelContext)
        async let productsTask = (try? await session.services.products.newProducts(limit: 30)) ?? []
        async let articlesTask = (try? await session.services.news.articles(limit: 50)) ?? []

        newProducts = await productsTask
        articles = await articlesTask

        if articles.isEmpty, let cached: [NewsArticle] = cache.load(CacheStore.Key.news, as: [NewsArticle].self) {
            articles = cached
        } else if !articles.isEmpty {
            cache.save(articles, for: CacheStore.Key.news)
        }
    }
}

/// ニュース 1 件。本文は持たず、タップで元記事を開く。
struct NewsRow: View {
    let article: NewsArticle

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 5) {
                Text(article.title)
                    .font(.subheadline.weight(.medium))
                    .multilineTextAlignment(.leading)
                    .lineLimit(3)
                HStack(spacing: 6) {
                    if let source = article.sourceName {
                        Text(source)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    Text(Formatters.relative(article.publishedAt))
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
            Spacer(minLength: 0)
            if let thumbnail = article.thumbnailUrl {
                AsyncImage(url: thumbnail) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    Rectangle().fill(Color(.tertiarySystemFill))
                }
                .frame(width: 64, height: 64)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
            Image(systemName: "arrow.up.right")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(12)
        .contentShape(Rectangle())
    }
}

/// 元記事は SFSafariViewController で開く（設計 §25）。
struct SafariView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> SFSafariViewController {
        SFSafariViewController(url: url)
    }

    func updateUIViewController(_ controller: SFSafariViewController, context: Context) {}
}
