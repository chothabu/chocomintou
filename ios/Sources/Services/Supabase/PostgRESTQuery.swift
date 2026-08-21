import Foundation

/// PostgREST のクエリ文字列を組み立てる。
/// 演算子の綴りを各サービスに散らかさないための薄いビルダー。
struct PostgRESTQuery: Sendable {
    let table: String
    private(set) var items: [URLQueryItem] = []

    init(_ table: String) { self.table = table }

    func select(_ columns: String = "*") -> Self {
        appending(URLQueryItem(name: "select", value: columns))
    }

    func eq(_ column: String, _ value: String) -> Self {
        appending(URLQueryItem(name: column, value: "eq.\(value)"))
    }

    func eq(_ column: String, _ value: UUID) -> Self {
        eq(column, value.uuidString.lowercased())
    }

    func isTrue(_ column: String) -> Self {
        appending(URLQueryItem(name: column, value: "is.true"))
    }

    func isFalse(_ column: String) -> Self {
        appending(URLQueryItem(name: column, value: "is.false"))
    }

    func not(_ column: String, _ op: String, _ value: String) -> Self {
        appending(URLQueryItem(name: column, value: "not.\(op).\(value)"))
    }

    func gte(_ column: String, _ value: String) -> Self {
        appending(URLQueryItem(name: column, value: "gte.\(value)"))
    }

    func lte(_ column: String, _ value: String) -> Self {
        appending(URLQueryItem(name: column, value: "lte.\(value)"))
    }

    /// 空配列のときは条件を付けない（「絞り込みなし」を意味させる）。
    func inList(_ column: String, _ values: [String]) -> Self {
        guard !values.isEmpty else { return self }
        return appending(URLQueryItem(name: column, value: "in.(\(values.joined(separator: ","))"  + ")"))
    }

    /// 部分一致（大文字小文字を無視）。
    func ilike(_ column: String, contains keyword: String) -> Self {
        appending(URLQueryItem(name: column, value: "ilike.*\(escape(keyword))*"))
    }

    /// 複数列の OR 検索。`or=(name.ilike.*x*,manufacturer.ilike.*x*)`
    func orILike(_ columns: [String], contains keyword: String) -> Self {
        guard !columns.isEmpty else { return self }
        let escaped = escape(keyword)
        let conditions = columns.map { "\($0).ilike.*\(escaped)*" }
        return appending(URLQueryItem(name: "or", value: "(\(conditions.joined(separator: ",")))"))
    }

    func order(_ column: String, ascending: Bool = true, nullsLast: Bool = true) -> Self {
        var value = "\(column).\(ascending ? "asc" : "desc")"
        if nullsLast { value += ".nullslast" }
        return appending(URLQueryItem(name: "order", value: value))
    }

    func limit(_ count: Int) -> Self {
        appending(URLQueryItem(name: "limit", value: String(count)))
    }

    func offset(_ count: Int) -> Self {
        appending(URLQueryItem(name: "offset", value: String(count)))
    }

    func appending(_ item: URLQueryItem) -> Self {
        var copy = self
        copy.items.append(item)
        return copy
    }

    /// PostgREST の値では `,` `.` `(` `)` が区切り文字なので、
    /// 含む可能性のある検索語はダブルクォートで囲う。
    private func escape(_ value: String) -> String {
        value.replacingOccurrences(of: "\"", with: "")
            .replacingOccurrences(of: ",", with: " ")
            .replacingOccurrences(of: "(", with: " ")
            .replacingOccurrences(of: ")", with: " ")
    }
}
