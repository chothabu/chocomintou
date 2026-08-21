import Foundation

enum BackendError: LocalizedError, Sendable, Equatable {
    /// 接続先が設定されていない（サンプルデータ動作時に書き込みを試みた場合など）。
    case notConfigured
    /// ログインが必要な操作をログインせずに実行した。
    case authenticationRequired
    case http(status: Int, message: String)
    case decoding(String)
    case network(String)
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            "サーバーに接続できません。設定を確認してください。"
        case .authenticationRequired:
            "この操作にはログインが必要です。"
        case let .http(status, message):
            message.isEmpty ? "通信に失敗しました（\(status)）" : message
        case let .decoding(detail):
            "データを読み込めませんでした。\(detail)"
        case let .network(detail):
            "ネットワークに接続できませんでした。\(detail)"
        case .invalidResponse:
            "サーバーからの応答を解釈できませんでした。"
        }
    }

    /// キャッシュを表示してよいかの判定に使う（通信エラーなら直近データを出す）。
    var isNetworkFailure: Bool {
        if case .network = self { return true }
        return false
    }
}
