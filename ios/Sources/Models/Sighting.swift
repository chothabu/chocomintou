import Foundation

/// 目撃情報。商品と店舗をつなぐ唯一の事実であり、このアプリの中核（設計 §2）。
/// 追記のみのイベントログとして扱い、取り消しは論理削除で行う。
struct Sighting: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    var productId: UUID
    var storeId: UUID
    var userId: UUID
    var foundAt: Date
    var isOfficial: Bool
    var createdAt: Date?
}

/// ホームの「最近の目撃情報」・マイページの「目撃履歴」で使う表示用の 1 行。
/// 商品と店舗を埋め込んで取得する。
struct SightingEntry: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    var foundAt: Date
    var isOfficial: Bool
    var product: Product
    var store: Store
}

/// 目撃報告の入力。`report_sighting` RPC にそのまま渡す。
struct SightingReport: Hashable, Sendable {
    var productId: UUID
    var candidate: StoreCandidate
}

/// 目撃報告の結果。
enum SightingReportResult: Sendable {
    /// 記録できた。
    case recorded(sightingId: UUID)
    /// 同じ店舗・同じ商品を今日すでに報告済み（1 日 1 件制限）。
    case alreadyReportedToday

    var message: String {
        switch self {
        case .recorded: "ありがとうございます！みんなに共有されました"
        case .alreadyReportedToday: "この商品は今日すでに報告済みです"
        }
    }
}
