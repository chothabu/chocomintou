import SwiftUI

/// ★ の評価表示。
struct StarRatingView: View {
    let rating: Double
    var size: CGFloat = 13

    var body: some View {
        HStack(spacing: 1) {
            ForEach(1...5, id: \.self) { index in
                Image(systemName: symbol(for: index))
                    .font(.system(size: size))
                    .foregroundStyle(Palette.recent)
            }
        }
        .accessibilityLabel("5段階中 \(String(format: "%.1f", rating))")
    }

    private func symbol(for index: Int) -> String {
        let value = rating - Double(index) + 1
        if value >= 0.75 { return "star.fill" }
        if value >= 0.25 { return "star.leadinghalf.filled" }
        return "star"
    }
}

/// ●●●●○ の 5 段階バー。ミント強度・チョコ強度などに使う。
struct RatingDotsView: View {
    let title: String
    let value: Double?

    var body: some View {
        HStack {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
            if let value {
                HStack(spacing: 3) {
                    ForEach(1...5, id: \.self) { index in
                        Circle()
                            .fill(Double(index) <= value.rounded() ? Palette.deepMint : Color(.systemGray5))
                            .frame(width: 9, height: 9)
                    }
                }
                Text(String(format: "%.1f", value))
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.primary)
                    .frame(width: 34, alignment: .trailing)
            } else {
                Text("—")
                    .font(.subheadline)
                    .foregroundStyle(.tertiary)
            }
        }
    }
}

/// 🌿 ミントレベル Lv4 / かなり強め
struct MintLevelBadge: View {
    let level: MintLevel
    var compact = false

    var body: some View {
        HStack(spacing: 6) {
            Text("🌿")
            Text(compact ? level.label : "ミントレベル \(level.label)")
                .font(.subheadline.weight(.semibold))
            if !compact {
                Text(level.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Palette.paleMint, in: Capsule())
        .foregroundStyle(Palette.chocolate)
    }
}

/// 🟢 今日見つかっています
struct FreshnessBadge: View {
    let freshness: SightingFreshness
    var showsLabel = true

    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(freshness.color)
                .frame(width: 8, height: 8)
            if showsLabel {
                Text(freshness.label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

/// 商品画像。運営管理の画像のみを出す。未設定ならカテゴリのシンボルで代替する。
struct ProductThumbnail: View {
    let product: Product
    var size: CGFloat = 64

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size / 6, style: .continuous)
                .fill(Palette.paleMint)
            if let url = product.imageUrl {
                AsyncImage(url: url) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    placeholderSymbol
                }
            } else {
                placeholderSymbol
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: size / 6, style: .continuous))
    }

    private var placeholderSymbol: some View {
        // 名前の無いシンボルは何も描画されず、四角が空のまま残ってしまう。
        // OS のバージョン差でシンボルが欠けても穴が空かないよう、存在を確認してから使う。
        let name = product.category.symbolName
        let resolved = UIImage(systemName: name) != nil ? name : "sparkles"
        return Image(systemName: resolved)
            .font(.system(size: size * 0.36))
            .foregroundStyle(Palette.deepMint)
    }
}

/// 一覧の 1 行。
struct ProductRow: View {
    let product: Product

    var body: some View {
        HStack(spacing: 12) {
            ProductThumbnail(product: product, size: 60)
            VStack(alignment: .leading, spacing: 4) {
                Text(product.name)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(2)
                if let manufacturer = product.manufacturer {
                    Text(manufacturer)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                HStack(spacing: 6) {
                    if let average = product.avgOverall, product.reviewCount > 0 {
                        StarRatingView(rating: average, size: 11)
                        Text(String(format: "%.1f", average))
                            .font(.caption.monospacedDigit())
                    } else {
                        Text("レビューなし")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                    if let level = product.mintLevel {
                        Text("🌿\(level.label)")
                            .font(.caption2)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(Palette.paleMint, in: Capsule())
                    }
                }
            }
            Spacer(minLength: 0)
        }
        .contentShape(Rectangle())
    }
}

/// 横スクロール用のカード。
struct ProductCard: View {
    let product: Product
    var caption: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ProductThumbnail(product: product, size: Metrics.cardWidth)
            Text(product.name)
                .font(.footnote.weight(.semibold))
                .lineLimit(2)
                .multilineTextAlignment(.leading)
            if let caption {
                Text(caption)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: Metrics.cardWidth, alignment: .leading)
        .contentShape(Rectangle())
    }
}

/// セクション見出し（「近くのチョコミント」など）。
struct SectionHeader<Trailing: View>: View {
    let title: String
    @ViewBuilder var trailing: Trailing

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.headline)
            Spacer()
            trailing
        }
    }
}

extension SectionHeader where Trailing == EmptyView {
    init(_ title: String) {
        self.init(title: title) { EmptyView() }
    }
}

/// 空状態。何をすれば埋まるのかまで書く。
struct EmptyStateView: View {
    let symbol: String
    let title: String
    var message: String?
    var actionTitle: String?
    var action: (() -> Void)?

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: symbol)
                .font(.system(size: 34))
                .foregroundStyle(Palette.mint)
            Text(title)
                .font(.subheadline.weight(.semibold))
                .multilineTextAlignment(.center)
            if let message {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .padding(.top, 2)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
        .padding(.horizontal, 24)
    }
}

/// 読み込み失敗。再試行できるようにする。
struct ErrorStateView: View {
    let message: String
    var retry: (() -> Void)?

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 28))
                .foregroundStyle(.orange)
            Text(message)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            if let retry {
                Button("再読み込み", action: retry)
                    .buttonStyle(.bordered)
                    .controlSize(.small)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }
}

/// 1〜5 を選ばせる評価入力。
struct RatingPicker: View {
    let title: String
    @Binding var value: Int
    var isRequired = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                Text(title)
                    .font(.subheadline.weight(.medium))
                if isRequired {
                    Text("必須")
                        .font(.caption2)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(Palette.paleMint, in: Capsule())
                        .foregroundStyle(Palette.deepMint)
                } else {
                    Text("任意")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                Spacer()
                if value > 0 {
                    Button("クリア") { value = 0 }
                        .font(.caption2)
                }
            }
            HStack(spacing: 8) {
                ForEach(1...5, id: \.self) { score in
                    Button {
                        value = score
                    } label: {
                        Image(systemName: score <= value ? "star.fill" : "star")
                            .font(.title3)
                            .foregroundStyle(score <= value ? Palette.recent : Color(.systemGray3))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(title) \(score)")
                }
            }
        }
    }
}
