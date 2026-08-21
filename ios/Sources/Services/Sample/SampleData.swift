import Foundation

/// サンプルデータ。実在の商品・店舗ではない。
/// バックエンド未接続でも画面と導線を確認できるようにするためのもの。
enum SampleData {
    static func id(_ number: Int) -> UUID {
        UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", number))!
    }

    static let currentUserId = id(900)

    private static func daysAgo(_ days: Double) -> Date {
        Date().addingTimeInterval(-days * 24 * 60 * 60)
    }

    private static func hoursAgo(_ hours: Double) -> Date {
        Date().addingTimeInterval(-hours * 60 * 60)
    }

    private static func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        Calendar.japanese.date(from: DateComponents(year: year, month: month, day: day)) ?? Date()
    }

    // MARK: - 商品

    static let products: [Product] = [
        Product(
            id: id(1), name: "極ミントアイスバー", manufacturer: "氷菓ラボ",
            description: "ミント感を限界まで高めたアイスバー。カカオ 70% のチョコでコーティング。",
            category: .ice, imageUrl: nil, price: 238,
            releaseDate: date(2026, 8, 20), endDate: date(2026, 9, 30),
            saleStatus: .onSale, isLimited: true,
            salesChannelText: "全国のコンビニエンスストア", officialUrl: nil,
            reviewCount: 126, avgOverall: 4.4, avgMint: 4.7, avgChocolate: 3.2,
            avgSweetness: 4.0, avgFreshness: 4.3, mintLevel: .lv5,
            createdAt: daysAgo(30), updatedAt: daysAgo(1)
        ),
        Product(
            id: id(2), name: "チョコミントサンドクッキー", manufacturer: "みどり製菓",
            description: "さっくりしたクッキーでミントクリームをサンド。",
            category: .snack, imageUrl: nil, price: 198,
            releaseDate: date(2026, 7, 15), endDate: nil,
            saleStatus: .onSale, isLimited: false,
            salesChannelText: "全国のスーパー・コンビニ", officialUrl: nil,
            reviewCount: 84, avgOverall: 4.1, avgMint: 3.4, avgChocolate: 4.1,
            avgSweetness: 3.8, avgFreshness: 3.2, mintLevel: .lv4,
            createdAt: daysAgo(60), updatedAt: daysAgo(3)
        ),
        Product(
            id: id(3), name: "ミントショコラパフェ", manufacturer: "カフェ ミントリーフ",
            description: "自家製ミントジェラートとチョコソースを重ねた季節限定パフェ。",
            category: .parfait, imageUrl: nil, price: 780,
            releaseDate: date(2026, 6, 1), endDate: date(2026, 9, 15),
            saleStatus: .onSale, isLimited: true,
            salesChannelText: "カフェ ミントリーフ 各店", officialUrl: nil,
            reviewCount: 31, avgOverall: 4.6, avgMint: 3.9, avgChocolate: 4.4,
            avgSweetness: 4.2, avgFreshness: 4.0, mintLevel: .lv4,
            createdAt: daysAgo(90), updatedAt: daysAgo(5)
        ),
        Product(
            id: id(4), name: "チョコミントラテ", manufacturer: "銀嶺珈琲",
            description: "ミントシロップとチョコソースのカフェラテ。",
            category: .drink, imageUrl: nil, price: 460,
            releaseDate: date(2026, 8, 5), endDate: nil,
            saleStatus: .onSale, isLimited: false,
            salesChannelText: "銀嶺珈琲 全店", officialUrl: nil,
            reviewCount: 47, avgOverall: 3.8, avgMint: 2.6, avgChocolate: 3.9,
            avgSweetness: 4.4, avgFreshness: 2.8, mintLevel: .lv3,
            createdAt: daysAgo(20), updatedAt: daysAgo(2)
        ),
        Product(
            id: id(5), name: "ダブルミントチョコバー", manufacturer: "氷菓ラボ",
            description: "ミントアイスとミントチョコの二層構造。",
            category: .ice, imageUrl: nil, price: 168,
            releaseDate: date(2026, 5, 12), endDate: nil,
            saleStatus: .onSale, isLimited: false,
            salesChannelText: "全国のコンビニエンスストア", officialUrl: nil,
            reviewCount: 203, avgOverall: 4.2, avgMint: 4.2, avgChocolate: 3.6,
            avgSweetness: 3.5, avgFreshness: 4.1, mintLevel: .lv4,
            createdAt: daysAgo(120), updatedAt: daysAgo(1)
        ),
        Product(
            id: id(6), name: "ミントチョコメロンパン", manufacturer: "青空ベーカリー",
            description: "クッキー生地にミントチョコチップを練り込んだメロンパン。",
            category: .bread, imageUrl: nil, price: 210,
            releaseDate: date(2026, 8, 12), endDate: date(2026, 10, 31),
            saleStatus: .onSale, isLimited: true,
            salesChannelText: "全国のスーパー", officialUrl: nil,
            reviewCount: 12, avgOverall: 3.5, avgMint: 2.1, avgChocolate: 3.3,
            avgSweetness: 4.1, avgFreshness: 2.2, mintLevel: .lv2,
            createdAt: daysAgo(14), updatedAt: daysAgo(1)
        ),
        Product(
            id: id(7), name: "チョコミントロールケーキ", manufacturer: "みどり製菓",
            description: "ミントクリームをチョコスポンジで巻いたロールケーキ。",
            category: .cake, imageUrl: nil, price: 380,
            releaseDate: date(2026, 7, 28), endDate: nil,
            saleStatus: .onSale, isLimited: false,
            salesChannelText: "全国のコンビニエンスストア", officialUrl: nil,
            reviewCount: 58, avgOverall: 4.0, avgMint: 3.1, avgChocolate: 4.2,
            avgSweetness: 4.3, avgFreshness: 3.0, mintLevel: .lv3,
            createdAt: daysAgo(40), updatedAt: daysAgo(4)
        ),
        Product(
            id: id(8), name: "ひんやりミントもなか", manufacturer: "和洋堂",
            description: "もなか皮にミントアイスとチョコを詰めた和洋折衷。",
            category: .ice, imageUrl: nil, price: 150,
            releaseDate: date(2025, 6, 10), endDate: date(2025, 9, 30),
            saleStatus: .ended, isLimited: true,
            salesChannelText: "全国のスーパー", officialUrl: nil,
            reviewCount: 96, avgOverall: 4.3, avgMint: 3.6, avgChocolate: 3.8,
            avgSweetness: 3.9, avgFreshness: 3.7, mintLevel: .lv4,
            createdAt: daysAgo(420), updatedAt: daysAgo(300)
        ),
        Product(
            id: id(9), name: "ミントチョコチップアイス 大容量", manufacturer: "氷菓ラボ",
            description: "家庭用 480ml カップ。チョコチップたっぷり。",
            category: .ice, imageUrl: nil, price: 598,
            releaseDate: date(2025, 4, 1), endDate: nil,
            saleStatus: .onSale, isLimited: false,
            salesChannelText: "全国のスーパー", officialUrl: nil,
            reviewCount: 311, avgOverall: 4.5, avgMint: 3.8, avgChocolate: 4.5,
            avgSweetness: 3.6, avgFreshness: 3.9, mintLevel: .lv4,
            createdAt: daysAgo(500), updatedAt: daysAgo(2)
        ),
        Product(
            id: id(10), name: "チョコミントソーダ", manufacturer: "銀嶺珈琲",
            description: "ミントシロップとチョコビターを合わせた炭酸飲料。",
            category: .drink, imageUrl: nil, price: 180,
            releaseDate: date(2026, 9, 1), endDate: nil,
            saleStatus: .upcoming, isLimited: true,
            salesChannelText: "全国のコンビニエンスストア", officialUrl: nil,
            reviewCount: 0, avgOverall: nil, avgMint: nil, avgChocolate: nil,
            avgSweetness: nil, avgFreshness: nil, mintLevel: nil,
            createdAt: daysAgo(5), updatedAt: daysAgo(5)
        ),
    ]

    /// 商品 × 販売チェーン。検索フィルタの動作確認用。
    static let channels: [UUID: [ChainName]] = [
        id(1): [.sevenEleven, .familymart, .lawson],
        id(2): [.familymart, .lawson],
        id(4): [.other],
        id(5): [.sevenEleven, .ministop],
        id(6): [.other],
        id(7): [.lawson],
        id(9): [.other],
        id(10): [.familymart],
    ]

    // MARK: - 店舗

    static let stores: [Store] = [
        Store(id: id(101), name: "セブン-イレブン 渋谷道玄坂店", chainName: .sevenEleven,
              latitude: 35.6580, longitude: 139.6975, address: "東京都渋谷区道玄坂",
              externalSource: "admin", externalStoreId: "sample-101", createdAt: daysAgo(200)),
        Store(id: id(102), name: "ファミリーマート 渋谷神南店", chainName: .familymart,
              latitude: 35.6620, longitude: 139.6990, address: "東京都渋谷区神南",
              externalSource: "admin", externalStoreId: "sample-102", createdAt: daysAgo(200)),
        Store(id: id(103), name: "ローソン 渋谷公園通り店", chainName: .lawson,
              latitude: 35.6635, longitude: 139.6985, address: "東京都渋谷区宇田川町",
              externalSource: "admin", externalStoreId: "sample-103", createdAt: daysAgo(150)),
        Store(id: id(104), name: "ミニストップ 渋谷桜丘店", chainName: .ministop,
              latitude: 35.6565, longitude: 139.6990, address: "東京都渋谷区桜丘町",
              externalSource: "admin", externalStoreId: "sample-104", createdAt: daysAgo(150)),
        Store(id: id(105), name: "カフェ ミントリーフ 渋谷店", chainName: nil,
              latitude: 35.6600, longitude: 139.7030, address: "東京都渋谷区渋谷",
              externalSource: "admin", externalStoreId: "sample-105", createdAt: daysAgo(100)),
        Store(id: id(106), name: "フレッシュストア 渋谷東", chainName: .other,
              latitude: 35.6560, longitude: 139.7040, address: "東京都渋谷区東",
              externalSource: "admin", externalStoreId: "sample-106", createdAt: daysAgo(80)),
    ]

    // MARK: - 目撃情報

    static let sightings: [Sighting] = [
        Sighting(id: id(201), productId: id(1), storeId: id(102), userId: id(901),
                 foundAt: hoursAgo(0.2), isOfficial: false, createdAt: hoursAgo(0.2)),
        Sighting(id: id(202), productId: id(5), storeId: id(101), userId: id(902),
                 foundAt: hoursAgo(0.6), isOfficial: false, createdAt: hoursAgo(0.6)),
        Sighting(id: id(203), productId: id(1), storeId: id(101), userId: id(903),
                 foundAt: hoursAgo(4), isOfficial: true, createdAt: hoursAgo(4)),
        Sighting(id: id(204), productId: id(2), storeId: id(103), userId: id(901),
                 foundAt: hoursAgo(20), isOfficial: false, createdAt: hoursAgo(20)),
        Sighting(id: id(205), productId: id(3), storeId: id(105), userId: id(902),
                 foundAt: daysAgo(2), isOfficial: false, createdAt: daysAgo(2)),
        Sighting(id: id(206), productId: id(9), storeId: id(106), userId: id(903),
                 foundAt: daysAgo(4), isOfficial: false, createdAt: daysAgo(4)),
        Sighting(id: id(207), productId: id(7), storeId: id(103), userId: id(901),
                 foundAt: daysAgo(9), isOfficial: false, createdAt: daysAgo(9)),
        Sighting(id: id(208), productId: id(6), storeId: id(106), userId: id(902),
                 foundAt: daysAgo(15), isOfficial: false, createdAt: daysAgo(15)),
        Sighting(id: id(209), productId: id(5), storeId: id(104), userId: id(903),
                 foundAt: daysAgo(26), isOfficial: false, createdAt: daysAgo(26)),
        Sighting(id: id(210), productId: id(4), storeId: id(105), userId: id(901),
                 foundAt: daysAgo(1), isOfficial: false, createdAt: daysAgo(1)),
    ]

    // MARK: - レビュー

    static let reviews: [Review] = [
        Review(id: id(301), userId: id(901), productId: id(1), overallRating: 5,
               mintIntensity: 5, chocolateIntensity: 3, sweetness: 4, freshness: 5,
               comment: "かなりミント強い。個人的には今年一番。歯磨き粉とか言わせない。",
               helpfulCount: 12, createdAt: daysAgo(3), updatedAt: daysAgo(3),
               author: Review.ReviewAuthor(id: id(901), displayName: "つよめのチョコミン党")),
        Review(id: id(302), userId: id(902), productId: id(1), overallRating: 4,
               mintIntensity: 4, chocolateIntensity: 4, sweetness: 4, freshness: 4,
               comment: "ミントもチョコもしっかり。ただ溶けるのが早い。",
               helpfulCount: 5, createdAt: daysAgo(6), updatedAt: nil,
               author: Review.ReviewAuthor(id: id(902), displayName: "みどりのミント好き")),
        Review(id: id(303), userId: id(903), productId: id(1), overallRating: 3,
               mintIntensity: 5, chocolateIntensity: 2, sweetness: 3, freshness: 5,
               comment: "ミントが勝ちすぎてチョコを感じない。強ミント派には刺さると思う。",
               helpfulCount: 21, createdAt: daysAgo(10), updatedAt: nil,
               author: Review.ReviewAuthor(id: id(903), displayName: "ひんやりチョコミンター")),
        Review(id: id(304), userId: id(901), productId: id(5), overallRating: 4,
               mintIntensity: 4, chocolateIntensity: 4, sweetness: 3, freshness: 4,
               comment: "定番。安定しておいしい。",
               helpfulCount: 3, createdAt: daysAgo(12), updatedAt: nil,
               author: Review.ReviewAuthor(id: id(901), displayName: "つよめのチョコミン党")),
        Review(id: id(305), userId: id(902), productId: id(9), overallRating: 5,
               mintIntensity: 4, chocolateIntensity: 5, sweetness: 3, freshness: 4,
               comment: "チョコチップの量が正義。家に常備している。",
               helpfulCount: 34, createdAt: daysAgo(20), updatedAt: nil,
               author: Review.ReviewAuthor(id: id(902), displayName: "みどりのミント好き")),
        Review(id: id(306), userId: id(903), productId: id(4), overallRating: 3,
               mintIntensity: 2, chocolateIntensity: 4, sweetness: 5, freshness: 2,
               comment: "甘い。ミントはほんのり。デザート寄り。",
               helpfulCount: 8, createdAt: daysAgo(8), updatedAt: nil,
               author: Review.ReviewAuthor(id: id(903), displayName: "ひんやりチョコミンター")),
    ]

    // MARK: - ニュース

    static let news: [NewsArticle] = [
        NewsArticle(id: id(401), title: "氷菓ラボから新作チョコミント登場、ミント感を過去最高に",
                    sourceName: "サンプルフードニュース",
                    articleUrl: URL(string: "https://example.com/news/1")!,
                    thumbnailUrl: nil, publishedAt: hoursAgo(2)),
        NewsArticle(id: id(402), title: "コンビニ限定チョコミントスイーツが今夏も拡大",
                    sourceName: "サンプル流通新聞",
                    articleUrl: URL(string: "https://example.com/news/2")!,
                    thumbnailUrl: nil, publishedAt: hoursAgo(26)),
        NewsArticle(id: id(403), title: "チョコミント市場、5 年連続で拡大の見通し",
                    sourceName: "サンプル経済オンライン",
                    articleUrl: URL(string: "https://example.com/news/3")!,
                    thumbnailUrl: nil, publishedAt: daysAgo(3)),
        NewsArticle(id: id(404), title: "「ミントは薬味じゃない」チョコミント愛好家の座談会",
                    sourceName: "サンプルカルチャー",
                    articleUrl: URL(string: "https://example.com/news/4")!,
                    thumbnailUrl: nil, publishedAt: daysAgo(6)),
    ]

    static let initiallyTastedProductIds: Set<UUID> = [id(1), id(2), id(5), id(9)]
    static let initiallyWishlistedProductIds: Set<UUID> = [id(3), id(10)]
}
