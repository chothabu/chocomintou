import SwiftUI

/// 食べた商品の一覧。
struct TastedView: View {
    @Environment(SessionStore.self) private var session
    @State private var entries: [TastedEntry] = []
    @State private var isLoading = true

    var body: some View {
        List {
            ForEach(entries) { entry in
                NavigationLink(value: AppRoute.product(entry.product)) {
                    ProductRow(product: entry.product)
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("食べた商品")
        .navigationBarTitleDisplayMode(.inline)
        .overlay {
            if isLoading && entries.isEmpty {
                ProgressView()
            } else if entries.isEmpty {
                EmptyStateView(
                    symbol: "checkmark.circle",
                    title: "まだ記録がありません",
                    message: "商品ページの「食べた」を押すとここに並びます。"
                )
            }
        }
        .task { await load() }
        .refreshable { await load() }
    }

    private func load() async {
        guard let userId = session.userId else {
            isLoading = false
            return
        }
        isLoading = true
        defer { isLoading = false }
        entries = (try? await session.services.library.tasted(userId: userId)) ?? []
    }
}

/// 食べたい商品の一覧。
struct WishlistView: View {
    @Environment(SessionStore.self) private var session
    @State private var entries: [WishlistEntry] = []
    @State private var isLoading = true

    var body: some View {
        List {
            ForEach(entries) { entry in
                NavigationLink(value: AppRoute.product(entry.product)) {
                    ProductRow(product: entry.product)
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("食べたい商品")
        .navigationBarTitleDisplayMode(.inline)
        .overlay {
            if isLoading && entries.isEmpty {
                ProgressView()
            } else if entries.isEmpty {
                EmptyStateView(
                    symbol: "heart",
                    title: "まだありません",
                    message: "気になる商品に「食べたい」を付けておくと、ここにまとまります。"
                )
            }
        }
        .task { await load() }
        .refreshable { await load() }
    }

    private func load() async {
        guard let userId = session.userId else {
            isLoading = false
            return
        }
        isLoading = true
        defer { isLoading = false }
        entries = (try? await session.services.library.wishlist(userId: userId)) ?? []
    }
}

/// 自分が書いたレビューの一覧。
struct MyReviewsView: View {
    @Environment(SessionStore.self) private var session
    @State private var reviews: [Review] = []
    @State private var isLoading = true

    var body: some View {
        List {
            ForEach(reviews) { review in
                NavigationLink(value: AppRoute.productId(review.productId)) {
                    VStack(alignment: .leading, spacing: 6) {
                        StarRatingView(rating: Double(review.overallRating))
                        if let comment = review.comment {
                            Text(comment)
                                .font(.subheadline)
                                .lineLimit(3)
                        }
                        Text(Formatters.relative(review.createdAt))
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                    .padding(.vertical, 2)
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("自分のレビュー")
        .navigationBarTitleDisplayMode(.inline)
        .overlay {
            if isLoading && reviews.isEmpty {
                ProgressView()
            } else if reviews.isEmpty {
                EmptyStateView(symbol: "text.bubble", title: "まだレビューがありません")
            }
        }
        .task { await load() }
        .refreshable { await load() }
    }

    private func load() async {
        guard let userId = session.userId else {
            isLoading = false
            return
        }
        isLoading = true
        defer { isLoading = false }
        reviews = (try? await session.services.reviews.myReviews(userId: userId)) ?? []
    }
}

/// 自分が報告した目撃情報の履歴。
struct SightingHistoryView: View {
    @Environment(SessionStore.self) private var session
    @State private var entries: [SightingEntry] = []
    @State private var isLoading = true

    var body: some View {
        List {
            ForEach(entries) { entry in
                NavigationLink(value: AppRoute.store(entry.store.id)) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(entry.product.name)
                            .font(.subheadline.weight(.medium))
                        Text(entry.store.name)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(Formatters.sightingTime(entry.foundAt))
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                    .padding(.vertical, 2)
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("目撃履歴")
        .navigationBarTitleDisplayMode(.inline)
        .overlay {
            if isLoading && entries.isEmpty {
                ProgressView()
            } else if entries.isEmpty {
                EmptyStateView(
                    symbol: "mappin.and.ellipse",
                    title: "まだ報告がありません",
                    message: "お店でチョコミントを見つけたら、商品ページから報告できます。"
                )
            }
        }
        .task { await load() }
        .refreshable { await load() }
    }

    private func load() async {
        guard let userId = session.userId else {
            isLoading = false
            return
        }
        isLoading = true
        defer { isLoading = false }
        entries = (try? await session.services.sightings.history(userId: userId, limit: 100)) ?? []
    }
}
