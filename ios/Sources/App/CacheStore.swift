import Foundation
import SwiftData

/// SwiftData に置く汎用の JSON キャッシュ。
///
/// 商品・ニュース・図鑑などを型ごとに `@Model` 化すると、サーバ側のスキーマ変更に
/// 追随する箇所が二重になる。ここではキー付きの JSON として持ち、
/// 復元時に本来のモデルへデコードする。
@Model
final class CachedPayload {
    @Attribute(.unique) var key: String
    var data: Data
    var updatedAt: Date

    init(key: String, data: Data, updatedAt: Date = .now) {
        self.key = key
        self.data = data
        self.updatedAt = updatedAt
    }
}

/// キャッシュの読み書き。通信できないときに直近の内容を表示するために使う。
@MainActor
struct CacheStore {
    let context: ModelContext

    enum Key {
        static let homeNearby = "home.nearby"
        static let homeNewProducts = "home.newProducts"
        static let homeRanking = "home.ranking"
        static let homeSightings = "home.sightings"
        static let news = "news.articles"
        static let tasted = "library.tasted"
        static let wishlist = "library.wishlist"
        static func productList(_ signature: String) -> String { "products.\(signature)" }
    }

    func load<T: Decodable>(_ key: String, as type: T.Type) -> T? {
        let descriptor = FetchDescriptor<CachedPayload>(
            predicate: #Predicate { $0.key == key }
        )
        guard let payload = try? context.fetch(descriptor).first else { return nil }
        return try? JSONCoding.decoder.decode(T.self, from: payload.data)
    }

    func save(_ value: some Encodable, for key: String) {
        guard let data = try? JSONCoding.encoder.encode(value) else { return }
        let descriptor = FetchDescriptor<CachedPayload>(
            predicate: #Predicate { $0.key == key }
        )
        if let existing = try? context.fetch(descriptor).first {
            existing.data = data
            existing.updatedAt = .now
        } else {
            context.insert(CachedPayload(key: key, data: data))
        }
        try? context.save()
    }

    func clearAll() {
        try? context.delete(model: CachedPayload.self)
        try? context.save()
    }
}
