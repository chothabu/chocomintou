import SwiftUI

/// 商品のレビュー一覧。並び替えは新しい順 / 高評価 / 参考になった順（設計 §13）。
struct ReviewListView: View {
    let product: Product

    @Environment(SessionStore.self) private var session
    @State private var sort: ReviewSort = .mostHelpful
    @State private var reviews: [Review] = []
    @State private var isLoading = true
    @State private var errorMessage: String?

    var body: some View {
        List {
            Section {
                Picker("並び替え", selection: $sort) {
                    ForEach(ReviewSort.allCases) { option in
                        Text(option.displayName).tag(option)
                    }
                }
                .pickerStyle(.segmented)
                .listRowInsets(EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12))
            }

            if let errorMessage {
                Section {
                    ErrorStateView(message: errorMessage) { Task { await load() } }
                }
            } else if reviews.isEmpty && !isLoading {
                Section {
                    EmptyStateView(symbol: "text.bubble", title: "まだレビューがありません")
                }
            } else {
                Section {
                    ForEach(reviews) { review in
                        ReviewRow(review: review) { Task { await load() } }
                            .padding(.vertical, 4)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("レビュー \(product.reviewCount)件")
        .navigationBarTitleDisplayMode(.inline)
        .overlay {
            if isLoading && reviews.isEmpty { ProgressView() }
        }
        .task(id: sort) { await load() }
        .refreshable { await load() }
    }

    private func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            var fetched = try await session.services.reviews.reviews(
                productId: product.id, sort: sort, limit: 100
            )
            if let userId = session.userId,
               let blocked = try? await session.services.reviews.blockedUserIds(of: userId) {
                fetched = fetched.filter { !blocked.contains($0.userId) }
            }
            reviews = fetched
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? "読み込みに失敗しました。"
        }
    }
}
