import Foundation

struct SupabaseSightingService: SightingServing {
    let client: SupabaseClient

    private static var columns: String {
        "id,found_at,is_official,product:products(*),store:stores(\(SupabaseStoreService.storeColumns))"
    }

    func recent(limit: Int) async throws -> [SightingEntry] {
        let query = PostgRESTQuery("sightings")
            .select(Self.columns)
            .isFalse("is_deleted")
            .appending(URLQueryItem(name: "order", value: "found_at.desc"))
            .limit(limit)
        return try await client.fetch(query, as: [SightingEntry].self)
    }

    func history(userId: UUID, limit: Int) async throws -> [SightingEntry] {
        let query = PostgRESTQuery("sightings")
            .select(Self.columns)
            .eq("user_id", userId)
            .isFalse("is_deleted")
            .appending(URLQueryItem(name: "order", value: "found_at.desc"))
            .limit(limit)
        return try await client.fetch(query, as: [SightingEntry].self)
    }

    /// 店舗の登録と目撃の記録を 1 回の RPC で行う。
    /// 戻り値が nil のときは 1 日 1 件制限に当たっている（重複投稿）。
    func report(_ report: SightingReport) async throws -> SightingReportResult {
        let candidate = report.candidate
        let sightingId = try await client.rpcOptionalUUID(
            "report_sighting",
            params: [
                "p_product_id": JSONValue(report.productId),
                "p_store_name": .string(candidate.name),
                "p_latitude": .double(candidate.latitude),
                "p_longitude": .double(candidate.longitude),
                "p_address": JSONValue(candidate.address),
                "p_chain_name": JSONValue(candidate.chainName?.rawValue),
                "p_external_source": .string(candidate.externalSource),
                "p_external_store_id": JSONValue(candidate.externalStoreId),
            ]
        )
        guard let sightingId else { return .alreadyReportedToday }
        return .recorded(sightingId: sightingId)
    }
}
