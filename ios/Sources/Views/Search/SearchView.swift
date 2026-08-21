import SwiftUI

/// 「探す」。上部に検索バー、その下に商品／店舗の切り替え（設計 §5-6）。
struct SearchView: View {
    @Environment(SessionStore.self) private var session
    @Environment(LocationService.self) private var location

    @State private var model = SearchViewModel()
    @State private var isPresentingFilter = false
    @State private var isPresentingSubmission = false

    var body: some View {
        @Bindable var model = model

        NavigationStack {
            VStack(spacing: 0) {
                Picker("表示", selection: $model.mode) {
                    ForEach(SearchViewModel.Mode.allCases) { mode in
                        Text(mode.displayName).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 16)
                .padding(.bottom, 8)

                if model.mode == .products {
                    filterBar
                }

                content
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("探す")
            .searchable(
                text: $model.filter.keyword,
                placement: .navigationBarDrawer(displayMode: .always),
                prompt: "商品・お店を検索"
            )
            .onChange(of: model.filter.keyword) { _, _ in scheduleSearch() }
            .onChange(of: model.mode) { _, _ in runSearch() }
            .appNavigationDestinations()
            .task { runSearch() }
            .sheet(isPresented: $isPresentingFilter) {
                FilterView(filter: $model.filter) { runSearch() }
            }
            .sheet(isPresented: $isPresentingSubmission) {
                ProductSubmissionView()
            }
        }
    }

    private var filterBar: some View {
        HStack {
            Button {
                isPresentingFilter = true
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "line.3.horizontal.decrease.circle")
                    Text("絞り込み")
                    if model.filter.activeCount > 0 {
                        Text("\(model.filter.activeCount)")
                            .font(.caption2.weight(.bold))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(Palette.deepMint, in: Capsule())
                            .foregroundStyle(.white)
                    }
                }
                .font(.subheadline)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)

            if model.filter.activeCount > 0 {
                Button("クリア") {
                    model.filter.reset()
                    runSearch()
                }
                .font(.caption)
            }

            Spacer()

            if !model.products.isEmpty {
                Text("\(model.products.count)件")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }

    @ViewBuilder
    private var content: some View {
        if model.isLoading && model.products.isEmpty && model.stores.isEmpty {
            Spacer()
            ProgressView()
            Spacer()
        } else if let message = model.errorMessage {
            Spacer()
            ErrorStateView(message: message) { runSearch() }
            Spacer()
        } else if model.mode == .products {
            productList
        } else {
            storeList
        }
    }

    private var productList: some View {
        List {
            ForEach(model.products) { product in
                NavigationLink(value: AppRoute.product(product)) {
                    ProductRow(product: product)
                }
            }

            // 見つからなかったときの受け皿（設計 §29）。
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text("お探しの商品がありませんか？")
                        .font(.subheadline.weight(.medium))
                    Text("見つからなかったチョコミントを教えてください。運営が確認して図鑑に追加します。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Button {
                        isPresentingSubmission = true
                    } label: {
                        Label("新しいチョコミントを報告", systemImage: "plus")
                            .font(.subheadline)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .padding(.top, 2)
                }
                .padding(.vertical, 6)
            }
        }
        .listStyle(.insetGrouped)
        .overlay {
            if model.products.isEmpty && model.hasSearched {
                EmptyStateView(
                    symbol: "magnifyingglass",
                    title: "該当する商品が見つかりません",
                    message: "キーワードや絞り込みを変えてみてください。"
                )
            }
        }
    }

    private var storeList: some View {
        List {
            ForEach(model.stores) { pin in
                NavigationLink(value: AppRoute.store(pin.storeId)) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text(pin.storeName)
                            .font(.subheadline.weight(.semibold))
                        Text(pin.items.map(\.productName).joined(separator: "、"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                        HStack(spacing: 8) {
                            FreshnessBadge(freshness: pin.freshness)
                            Text(Formatters.distance(pin.distanceM))
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        }
        .listStyle(.insetGrouped)
        .overlay {
            if model.stores.isEmpty && model.hasSearched {
                EmptyStateView(
                    symbol: "storefront",
                    title: "近くに目撃情報のあるお店がありません",
                    message: "チョコミントを見つけたら報告してください。"
                )
            }
        }
    }

    private func runSearch() {
        Task { await model.search(services: session.services, coordinate: location.coordinate) }
    }

    private func scheduleSearch() {
        model.scheduleSearch(services: session.services, coordinate: location.coordinate)
    }
}
