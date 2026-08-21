import SwiftUI

/// 配色。チョコミントそのものを基調にする。
/// ミント = 主役、チョコ = 文字とアクセント、クリーム = 背景。
enum Palette {
    static let mint = Color(red: 0.318, green: 0.812, blue: 0.729)
    static let deepMint = Color(red: 0.145, green: 0.612, blue: 0.541)
    static let paleMint = Color(red: 0.878, green: 0.965, blue: 0.949)
    static let chocolate = Color(red: 0.290, green: 0.180, blue: 0.130)
    static let cocoa = Color(red: 0.478, green: 0.353, blue: 0.294)
    static let cream = Color(red: 0.988, green: 0.976, blue: 0.957)

    static let today = Color(red: 0.204, green: 0.706, blue: 0.376)
    static let recent = Color(red: 0.918, green: 0.702, blue: 0.145)
    // マップのピンにも使う色なので、地図の上で黒い塊にならない明度にしている。
    static let past = Color(red: 0.639, green: 0.663, blue: 0.671)
}

enum Metrics {
    static let cardCorner: CGFloat = 14
    static let sectionSpacing: CGFloat = 28
    static let cardWidth: CGFloat = 150
}

extension SightingFreshness {
    var color: Color {
        switch self {
        case .today: Palette.today
        case .recent: Palette.recent
        case .past, .stale, .unknown: Palette.past
        }
    }
}

/// 非同期に読み込む画面の状態。
enum LoadState<Value: Sendable>: Sendable {
    case loading
    case loaded(Value)
    case failed(String)

    var value: Value? {
        if case let .loaded(value) = self { return value }
        return nil
    }

    var isLoading: Bool {
        if case .loading = self { return true }
        return false
    }
}

extension View {
    /// カード風の背景。
    func cardBackground() -> some View {
        background(
            RoundedRectangle(cornerRadius: Metrics.cardCorner, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
    }
}
