import Foundation

/// ニュース記事。本文は保存しない（設計 §25）。
/// タップしたら SFSafariViewController で元記事を開く。
struct NewsArticle: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    var title: String
    var sourceName: String?
    var articleUrl: URL
    var thumbnailUrl: URL?
    var publishedAt: Date
}

/// ニュース画面のタブ（設計 §23）。
enum NewsTab: String, CaseIterable, Sendable, Identifiable {
    /// アプリ側の商品 DB から出す新商品。
    case newProducts
    /// バックエンドが収集した外部記事。
    case articles

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .newProducts: "新商品"
        case .articles: "ニュース"
        }
    }
}
