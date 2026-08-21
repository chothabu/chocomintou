import Foundation

/// PostgREST とやり取りする JSON のエンコーダ / デコーダ。
///
/// 列名は snake_case、Swift 側は camelCase なので変換戦略に任せる。
/// その代わり、プロパティ名は変換結果に合わせる必要がある（`image_url` → `imageUrl`）。
enum JSONCoding {
    static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .custom { decoder in
            let raw = try decoder.singleValueContainer().decode(String.self)
            guard let date = PostgresDate.parse(raw) else {
                throw DecodingError.dataCorrupted(
                    .init(codingPath: decoder.codingPath,
                          debugDescription: "日付として解釈できません: \(raw)")
                )
            }
            return date
        }
        return decoder
    }()

    static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        encoder.dateEncodingStrategy = .custom { date, encoder in
            var container = encoder.singleValueContainer()
            try container.encode(PostgresDate.iso8601.string(from: date))
        }
        return encoder
    }()
}

/// Postgres が返す日付表現を解釈する。
///
/// `timestamptz` は小数秒の有無が値によって変わり（`.123456` が付いたり付かなかったり）、
/// `date` 列は `2026-08-20` の形で返る。ISO8601DateFormatter 1 つでは全部を受けられないので、
/// 順に試す。
enum PostgresDate {
    // ISO8601DateFormatter は Sendable ではないが、生成後に設定を変えなければ
    // フォーマット/パース自体はスレッドセーフ。使い回しのコストのほうが大きいので共有する。
    nonisolated(unsafe) static let iso8601: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    nonisolated(unsafe) private static let iso8601NoFraction: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    private static let dateOnly: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "Asia/Tokyo")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    static func parse(_ raw: String) -> Date? {
        if let date = iso8601.date(from: raw) { return date }
        if let date = iso8601NoFraction.date(from: raw) { return date }
        if let date = dateOnly.date(from: raw) { return date }
        return nil
    }

    /// `date` 型の列に送る文字列。
    static func dateOnlyString(from date: Date) -> String { dateOnly.string(from: date) }
}
