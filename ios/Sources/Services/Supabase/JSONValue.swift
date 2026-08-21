import Foundation

/// RPC の引数など、型がその場ごとに変わる JSON を組み立てるための最小限の表現。
/// RPC ごとに Encodable な struct を定義すると数が増えすぎるため、これ 1 つで済ませる。
enum JSONValue: Encodable, Sendable, Equatable {
    case string(String)
    case int(Int)
    case double(Double)
    case bool(Bool)
    case array([JSONValue])
    case object([String: JSONValue])
    case null

    func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case let .string(value): try container.encode(value)
        case let .int(value): try container.encode(value)
        case let .double(value): try container.encode(value)
        case let .bool(value): try container.encode(value)
        case let .array(value): try container.encode(value)
        case let .object(value): try container.encode(value)
        case .null: try container.encodeNil()
        }
    }

    init(_ value: String?) { self = value.map(JSONValue.string) ?? .null }
    init(_ value: Int?) { self = value.map(JSONValue.int) ?? .null }
    init(_ value: Double?) { self = value.map(JSONValue.double) ?? .null }
    init(_ value: Bool?) { self = value.map(JSONValue.bool) ?? .null }
    init(_ value: UUID?) { self = value.map { .string($0.uuidString.lowercased()) } ?? .null }
}
