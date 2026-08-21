import Foundation

@MainActor
@Observable
final class ProfileViewModel {
    var stats: TasteStats = .empty
    var progress: [CollectionProgress] = []
    var wishlistCount = 0
    var isLoading = false

    var partyType: MintPartyType { MintPartyType.evaluate(stats) }

    /// 今年の図鑑進捗。無ければ最新年のもの。
    var currentYearProgress: CollectionProgress? {
        let thisYear = Calendar.japanese.component(.year, from: Date())
        return progress.first { $0.year == thisYear } ?? progress.first
    }

    func load(services: AppServices, userId: UUID?) async {
        guard let userId else {
            stats = .empty
            progress = []
            wishlistCount = 0
            return
        }
        isLoading = true
        defer { isLoading = false }

        async let statsTask = (try? await services.library.tasteStats(userId: userId)) ?? .empty
        async let progressTask = (try? await services.library.collectionProgress(userId: userId)) ?? []
        async let wishlistTask = (try? await services.library.wishlist(userId: userId)) ?? []

        stats = await statsTask
        progress = await progressTask
        wishlistCount = await wishlistTask.count
    }
}
