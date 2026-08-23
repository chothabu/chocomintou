import SwiftUI

/// 商品詳細。このアプリの中心画面（設計 §8）。
struct ProductDetailView: View {
    @Environment(SessionStore.self) private var session
    @Environment(LocationService.self) private var location

    @State private var model = ProductDetailViewModel()
    @State private var isPresentingReviewEditor = false
    @State private var isPresentingSightingReport = false

    private let productId: UUID
    private let initialProduct: Product?

    init(product: Product) {
        productId = product.id
        initialProduct = product
    }

    init(productId: UUID) {
        self.productId = productId
        initialProduct = nil
    }

    var body: some View {
        ScrollView {
            if let product = model.product {
                VStack(alignment: .leading, spacing: 24) {
                    header(product)
                    actionButtons(product)
                    ratingSection(product)
                    whereToBuySection(product)
                    infoSection(product)
                    reviewSection(product)
                }
                .padding(16)
            } else if model.isLoading {
                ProgressView().padding(.top, 80)
            } else if let message = model.errorMessage {
                ErrorStateView(message: message) { Task { await load() } }
                    .padding(.top, 60)
            }
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(model.product?.name ?? "商品")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            if model.product == nil { model.product = initialProduct }
            await load()
        }
        .refreshable { await load() }
        .sheet(isPresented: $isPresentingReviewEditor) {
            if let product = model.product {
                ReviewCreateView(product: product, existing: model.userState.myReview) {
                    Task { await load() }
                }
            }
        }
        .sheet(isPresented: $isPresentingSightingReport) {
            if let product = model.product {
                SightingReportView(product: product) {
                    Task { await load() }
                }
            }
        }
        .alert("レビューしますか？", isPresented: $model.isPromptingReview) {
            Button("あとで", role: .cancel) {}
            Button("レビューを書く") { requireSignIn { isPresentingReviewEditor = true } }
        } message: {
            Text("「食べた」の登録はもう完了しています。レビューは任意です。")
        }
        .overlay(alignment: .bottom) { toast }
    }

    // MARK: - ヘッダー

    private func header(_ product: Product) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            ProductThumbnail(product: product, size: 160)
                .frame(maxWidth: .infinity)

            VStack(alignment: .leading, spacing: 6) {
                Text(product.name)
                    .font(.title2.weight(.bold))
                if let manufacturer = product.manufacturer {
                    Text(manufacturer)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            HStack(spacing: 10) {
                if let average = product.avgOverall, product.reviewCount > 0 {
                    StarRatingView(rating: average, size: 15)
                    Text(String(format: "%.1f", average))
                        .font(.headline.monospacedDigit())
                    Text("レビュー \(product.reviewCount)件")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text("まだレビューがありません")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            HStack(spacing: 6) {
                ForEach(product.badges, id: \.self) { badge in
                    Text(badge)
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color(.tertiarySystemFill), in: Capsule())
                }
            }

            if let description = product.description {
                Text(description)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(.top, 2)
            }
        }
    }

    // MARK: - 操作ボタン

    private func actionButtons(_ product: Product) -> some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                Button {
                    requireSignIn {
                        Task {
                            guard let userId = session.userId else { return }
                            await model.toggleWishlisted(services: session.services, userId: userId)
                        }
                    }
                } label: {
                    Label("食べたい", systemImage: model.userState.isWishlisted ? "heart.fill" : "heart")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                }
                .buttonStyle(.bordered)
                .tint(model.userState.isWishlisted ? .pink : .secondary)

                Button {
                    requireSignIn {
                        Task {
                            guard let userId = session.userId else { return }
                            await model.toggleTasted(services: session.services, userId: userId)
                        }
                    }
                } label: {
                    Label("食べた", systemImage: model.userState.isTasted ? "checkmark.circle.fill" : "checkmark.circle")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                }
                .buttonStyle(.borderedProminent)
                .tint(model.userState.isTasted ? Palette.deepMint : Palette.mint)
            }

            Button {
                requireSignIn { isPresentingSightingReport = true }
            } label: {
                Label("この商品を見つけた", systemImage: "mappin.and.ellipse")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.bordered)
        }
    }

    // MARK: - 評価

    private func ratingSection(_ product: Product) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader("評価")

            VStack(spacing: 12) {
                if let level = product.mintLevel {
                    HStack {
                        MintLevelBadge(level: level)
                        Spacer()
                    }
                }

                if product.reviewCount > 0 {
                    RatingDotsView(title: "総合評価", value: product.avgOverall)
                    Divider()
                    RatingDotsView(title: "ミント強度", value: product.avgMint)
                    RatingDotsView(title: "チョコ強度", value: product.avgChocolate)
                    RatingDotsView(title: "甘さ", value: product.avgSweetness)
                    RatingDotsView(title: "爽快感", value: product.avgFreshness)
                } else {
                    Text("レビューが投稿されると、ミント強度やチョコ強度の平均が表示されます。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(14)
            .cardBackground()
        }
    }

    // MARK: - どこで買えるか

    private func whereToBuySection(_ product: Product) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader("どこで買える？")

            VStack(alignment: .leading, spacing: 14) {
                if let channel = product.salesChannelText {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("公式情報")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Text(channel)
                            .font(.subheadline)
                    }
                    Divider()
                }

                // 通販の取扱店。出品が実在することは確認できているので、
                // 実店舗の目撃情報とは別枠で、事実として出す。
                if let shop = product.onlineShopName, let url = product.officialUrl {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("通販で買える")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Link(destination: url) {
                            HStack(spacing: 6) {
                                Image(systemName: "bag")
                                    .font(.caption)
                                Text(shop)
                                    .font(.subheadline)
                                    .lineLimit(1)
                                Image(systemName: "arrow.up.right")
                                    .font(.caption2)
                            }
                        }
                    }
                    Divider()
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("近くで見つかっています")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)

                    if model.nearby.isEmpty {
                        Text("この辺りではまだ見つかっていません。見つけたら報告してください。")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    } else {
                        ForEach(model.nearby.prefix(3)) { item in
                            NavigationLink(value: AppRoute.store(item.storeId)) {
                                HStack(spacing: 8) {
                                    Circle().fill(item.freshness.color).frame(width: 8, height: 8)
                                    Text(item.storeName)
                                        .font(.subheadline)
                                        .lineLimit(1)
                                    Spacer(minLength: 4)
                                    Text(Formatters.distance(item.distanceM))
                                        .font(.caption.monospacedDigit())
                                        .foregroundStyle(.secondary)
                                    Text(Formatters.sightingTime(item.lastSeenAt))
                                        .font(.caption2)
                                        .foregroundStyle(.tertiary)
                                }
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                Text("目撃情報はユーザーの報告です。在庫を保証するものではありません。")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .padding(14)
            .cardBackground()
        }
    }

    // MARK: - 商品情報

    private func infoSection(_ product: Product) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader("商品情報")

            VStack(spacing: 0) {
                // 価格不明の場合は行ごと出さない（設計 §10）。
                if let price = product.price {
                    infoRow("価格", Formatters.price(price))
                }
                if let releaseDate = product.releaseDate {
                    infoRow("発売日", Formatters.fullDate(releaseDate))
                }
                if let endDate = product.endDate {
                    infoRow("販売終了予定", Formatters.fullDate(endDate))
                }
                if let manufacturer = product.manufacturer {
                    infoRow("メーカー", manufacturer)
                }
                infoRow("カテゴリ", product.category.displayName)
                if let url = product.officialUrl {
                    Link(destination: url) {
                        HStack {
                            // メーカー公式とは限らず、通販の商品ページのこともある。
                            Text("商品ページ")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Image(systemName: "arrow.up.right.square")
                        }
                        .padding(.vertical, 10)
                        .padding(.horizontal, 14)
                    }
                }
            }
            .cardBackground()
        }
    }

    private func infoRow(_ title: String, _ value: String) -> some View {
        VStack(spacing: 0) {
            HStack(alignment: .top) {
                Text(title)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer(minLength: 16)
                Text(value)
                    .font(.subheadline)
                    .multilineTextAlignment(.trailing)
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 14)
        }
    }

    // MARK: - レビュー

    private func reviewSection(_ product: Product) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "みんなのレビュー") {
                if product.reviewCount > 0 {
                    NavigationLink(value: AppRoute.reviews(product)) {
                        Text("すべて見る")
                            .font(.caption)
                    }
                }
            }

            if model.reviewsFailed {
                // 取得に失敗しているのに「レビューなし」と出すと事実と違う表示になる。
                ErrorStateView(message: "レビューを読み込めませんでした。") {
                    Task { await load() }
                }
                .cardBackground()
            } else if model.reviews.isEmpty {
                EmptyStateView(
                    symbol: "text.bubble",
                    title: "まだレビューがありません",
                    message: "最初のレビューを書いてみませんか。",
                    actionTitle: "レビューを書く",
                    action: { requireSignIn { isPresentingReviewEditor = true } }
                )
                .cardBackground()
            } else {
                VStack(spacing: 10) {
                    ForEach(model.reviews) { review in
                        ReviewRow(review: review, onChanged: { Task { await load() } })
                            .padding(14)
                            .cardBackground()
                    }
                }

                Button {
                    requireSignIn { isPresentingReviewEditor = true }
                } label: {
                    Label(
                        model.userState.hasReviewed ? "自分のレビューを編集" : "レビューを書く",
                        systemImage: "square.and.pencil"
                    )
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                }
                .buttonStyle(.bordered)
            }
        }
    }

    // MARK: - その他

    @ViewBuilder
    private var toast: some View {
        if let message = model.toast {
            Text(message)
                .font(.footnote.weight(.medium))
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(.ultraThinMaterial, in: Capsule())
                .padding(.bottom, 16)
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .task {
                    try? await Task.sleep(for: .seconds(2))
                    model.toast = nil
                }
        }
    }

    private func requireSignIn(_ action: @escaping @MainActor () -> Void) {
        session.requireSignIn(then: action)
    }

    private func load() async {
        await model.load(
            productId: productId,
            services: session.services,
            userId: session.userId,
            coordinate: location.coordinate
        )
    }
}
