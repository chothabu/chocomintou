import CoreLocation
import SwiftUI

/// 目撃報告（設計 §19）。
///
/// 位置情報から周辺店舗を出す → 店舗を選ぶ → 確認して報告。
/// 店舗マスタを事前に用意せず、選ばれた店舗だけがサーバに登録される。
struct SightingReportView: View {
    let product: Product
    let onReported: () -> Void

    @Environment(SessionStore.self) private var session
    @Environment(LocationService.self) private var location
    @Environment(\.dismiss) private var dismiss

    @State private var candidates: [StoreCandidate] = []
    @State private var keyword = ""
    @State private var selected: StoreCandidate?
    @State private var isLoading = true
    @State private var isSubmitting = false
    @State private var errorMessage: String?
    @State private var result: SightingReportResult?

    private let searchService = StoreSearchService()

    var body: some View {
        NavigationStack {
            Group {
                if let result {
                    resultView(result)
                } else if let selected {
                    confirmView(selected)
                } else {
                    candidateList
                }
            }
            .navigationTitle(selected == nil ? "どこで見つけましたか？" : "確認")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    if result == nil, selected != nil {
                        Button("戻る") { selected = nil }
                    } else {
                        Button("閉じる") { dismiss() }
                    }
                }
            }
            .task { await loadCandidates() }
        }
    }

    // MARK: - 店舗候補

    private var candidateList: some View {
        List {
            Section {
                HStack(spacing: 12) {
                    ProductThumbnail(product: product, size: 44)
                    Text(product.name)
                        .font(.subheadline.weight(.medium))
                }
            }

            if location.isDenied {
                Section {
                    EmptyStateView(
                        symbol: "location.slash",
                        title: "位置情報が必要です",
                        message: "近くのお店を出すために、設定で位置情報の利用を許可してください。"
                    )
                }
            } else if isLoading {
                Section {
                    HStack {
                        ProgressView()
                        Text("近くのお店を探しています…")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            } else if candidates.isEmpty {
                Section {
                    EmptyStateView(
                        symbol: "storefront",
                        title: "近くにお店が見つかりません",
                        message: "店名で検索してみてください。"
                    )
                }
            } else {
                Section("近くのお店") {
                    ForEach(candidates) { candidate in
                        Button {
                            selected = candidate
                        } label: {
                            row(candidate)
                        }
                    }
                }
            }

            if let errorMessage {
                Section {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }
        }
        .searchable(text: $keyword, prompt: "店名で検索")
        .onSubmit(of: .search) { Task { await searchByKeyword() } }
    }

    private func row(_ candidate: StoreCandidate) -> some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 3) {
                Text(candidate.name)
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                if let address = candidate.address {
                    Text(address)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 4)
            if let distance = candidate.distance {
                Text(Formatters.distance(distance))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - 確認

    private func confirmView(_ candidate: StoreCandidate) -> some View {
        VStack(spacing: 24) {
            Spacer()

            VStack(spacing: 12) {
                ProductThumbnail(product: product, size: 88)
                Text(product.name)
                    .font(.headline)
                    .multilineTextAlignment(.center)
            }

            VStack(spacing: 6) {
                Text("この店舗で見つけましたか？")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text(candidate.name)
                    .font(.title3.weight(.bold))
                    .multilineTextAlignment(.center)
                if let address = candidate.address {
                    Text(address)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            if let errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
            }

            Button {
                Task { await submit(candidate) }
            } label: {
                Text("見つけた！")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
            }
            .buttonStyle(.borderedProminent)
            .tint(Palette.deepMint)
            .disabled(isSubmitting)

            Text("報告した内容はほかのユーザーにも表示されます。")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(24)
    }

    // MARK: - 結果

    private func resultView(_ result: SightingReportResult) -> some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: isRecorded(result) ? "checkmark.circle.fill" : "clock.badge.checkmark")
                .font(.system(size: 56))
                .foregroundStyle(Palette.deepMint)
            Text(result.message)
                .font(.headline)
                .multilineTextAlignment(.center)
            if isRecorded(result) {
                Text("この店舗のピンが今日の色になりました。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button("閉じる") { dismiss() }
                .buttonStyle(.borderedProminent)
                .frame(maxWidth: .infinity)
        }
        .padding(24)
    }

    private func isRecorded(_ result: SightingReportResult) -> Bool {
        if case .recorded = result { return true }
        return false
    }

    // MARK: - 処理

    private func loadCandidates() async {
        guard !location.isDenied else {
            isLoading = false
            return
        }
        isLoading = true
        defer { isLoading = false }
        do {
            candidates = try await searchService.nearbyStores(
                around: location.effectiveCoordinate, radiusMeters: 500
            )
        } catch {
            errorMessage = "周辺のお店を取得できませんでした。"
        }
    }

    private func searchByKeyword() async {
        let trimmed = keyword.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            await loadCandidates()
            return
        }
        isLoading = true
        defer { isLoading = false }
        do {
            candidates = try await searchService.searchStores(
                matching: trimmed, around: location.effectiveCoordinate
            )
        } catch {
            errorMessage = "検索できませんでした。"
        }
    }

    private func submit(_ candidate: StoreCandidate) async {
        isSubmitting = true
        errorMessage = nil
        defer { isSubmitting = false }
        do {
            result = try await session.services.sightings.report(
                SightingReport(productId: product.id, candidate: candidate)
            )
            onReported()
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? "報告できませんでした。"
        }
    }
}
