import SwiftUI

/// マイページ（設計 §38）。
struct ProfileView: View {
    @Environment(SessionStore.self) private var session
    @State private var model = ProfileViewModel()

    var body: some View {
        NavigationStack {
            List {
                if session.isSignedIn {
                    profileHeader
                    countsSection
                    collectionSection
                    tasteSection
                    menuSection
                } else {
                    signInPrompt
                    Section {
                        NavigationLink(value: AppRoute.settings) {
                            Label("設定", systemImage: "gearshape")
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("マイページ")
            .appNavigationDestinations()
            .task { await model.load(services: session.services, userId: session.userId) }
            .refreshable { await model.load(services: session.services, userId: session.userId) }
        }
    }

    // MARK: - ヘッダー

    private var profileHeader: some View {
        Section {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(Palette.paleMint)
                        .frame(width: 62, height: 62)
                    Text(model.partyType.emoji)
                        .font(.system(size: 30))
                }
                VStack(alignment: .leading, spacing: 5) {
                    Text(session.currentUser?.displayName ?? "—")
                        .font(.headline)
                    HStack(spacing: 5) {
                        Text(model.partyType.emoji)
                        Text(model.partyType.displayName)
                            .font(.subheadline.weight(.medium))
                    }
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4)
                    .background(Palette.paleMint, in: Capsule())
                    .foregroundStyle(Palette.chocolate)
                }
                Spacer()
            }
            .padding(.vertical, 6)
        }
    }

    private var countsSection: some View {
        Section {
            HStack(spacing: 0) {
                countItem("食べた", value: model.stats.tastedCount, route: .tasted)
                Divider().frame(height: 34)
                countItem("食べたい", value: model.wishlistCount, route: .wishlist)
                Divider().frame(height: 34)
                countItem("レビュー", value: model.stats.reviewCount, route: .myReviews)
            }
            .padding(.vertical, 4)
        }
    }

    private func countItem(_ title: String, value: Int, route: AppRoute) -> some View {
        NavigationLink(value: route) {
            VStack(spacing: 3) {
                Text("\(value)")
                    .font(.title3.weight(.bold).monospacedDigit())
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }

    // MARK: - 図鑑

    @ViewBuilder
    private var collectionSection: some View {
        if let progress = model.currentYearProgress {
            Section {
                NavigationLink(value: AppRoute.collection(year: progress.year)) {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("\(progress.year) チョコミント図鑑")
                                .font(.subheadline.weight(.semibold))
                            Spacer()
                            Text("\(progress.tastedCount) / \(progress.totalCount)")
                                .font(.subheadline.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                        ProgressView(value: progress.ratio)
                            .tint(Palette.deepMint)
                        Text(progress.percentText)
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }
            }
        }
    }

    // MARK: - 味覚傾向

    @ViewBuilder
    private var tasteSection: some View {
        if model.stats.reviewCount > 0 {
            Section {
                RatingDotsView(title: "ミント強度の平均", value: model.stats.avgMint)
                RatingDotsView(title: "チョコ強度の平均", value: model.stats.avgChocolate)
                RatingDotsView(title: "甘さの平均", value: model.stats.avgSweetness)
                RatingDotsView(title: "爽快感の平均", value: model.stats.avgFreshness)
            } header: {
                Text("あなたの評価傾向")
            } footer: {
                Text(model.partyType.summary)
            }
        }
    }

    private var menuSection: some View {
        Section {
            NavigationLink(value: AppRoute.collection(year: Calendar.japanese.component(.year, from: Date()))) {
                Label("チョコミント図鑑", systemImage: "square.grid.3x3")
            }
            NavigationLink(value: AppRoute.tasted) {
                Label("食べた商品", systemImage: "checkmark.circle")
            }
            NavigationLink(value: AppRoute.wishlist) {
                Label("食べたい商品", systemImage: "heart")
            }
            NavigationLink(value: AppRoute.myReviews) {
                Label("自分のレビュー", systemImage: "text.bubble")
            }
            NavigationLink(value: AppRoute.sightingHistory) {
                Label("目撃履歴", systemImage: "mappin.and.ellipse")
            }
            NavigationLink(value: AppRoute.settings) {
                Label("設定", systemImage: "gearshape")
            }
        }
    }

    // MARK: - 未ログイン

    private var signInPrompt: some View {
        Section {
            VStack(spacing: 12) {
                Text("🌿")
                    .font(.system(size: 44))
                Text("ログインすると記録が残ります")
                    .font(.subheadline.weight(.semibold))
                Text("食べた記録・レビュー・図鑑・目撃報告はログインが必要です。\n見るだけならログイン不要のまま使えます。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                Button("ログイン") {
                    session.requireSignIn {}
                }
                .buttonStyle(.borderedProminent)
                .padding(.top, 2)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
        }
    }
}
