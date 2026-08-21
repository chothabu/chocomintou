import Foundation

struct SupabaseNewsService: NewsServing {
    let client: SupabaseClient

    /// 記事の収集はバックエンドのバッチが行う。アプリは保存済みのものを読むだけ（設計 §24）。
    func articles(limit: Int) async throws -> [NewsArticle] {
        let query = PostgRESTQuery("news_articles")
            .select("id,title,source_name,article_url,thumbnail_url,published_at")
            .isFalse("is_hidden")
            .appending(URLQueryItem(name: "order", value: "published_at.desc"))
            .limit(limit)
        return try await client.fetch(query, as: [NewsArticle].self)
    }
}
