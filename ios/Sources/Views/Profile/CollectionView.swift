import SwiftUI

/// チョコミント図鑑（設計 §33-35）。年別のグリッド。未取得はシルエット。
struct CollectionView: View {
    let year: Int

    @Environment(SessionStore.self) private var session
    @State private var selectedYear: Int
    @State private var slots: [CollectionSlot] = []
    @State private var progress: [CollectionProgress] = []
    @State private var isLoading = true

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 3)

    init(year: Int) {
        self.year = year
        _selectedYear = State(initialValue: year)
    }

    private var currentProgress: CollectionProgress? {
        progress.first { $0.year == selectedYear }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                yearPicker
                progressHeader
                grid
            }
            .padding(16)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("チョコミント図鑑")
        .navigationBarTitleDisplayMode(.inline)
        .task(id: selectedYear) { await load() }
        .overlay {
            if isLoading && slots.isEmpty { ProgressView() }
        }
    }

    @ViewBuilder
    private var yearPicker: some View {
        if progress.count > 1 {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(progress) { item in
                        Button {
                            selectedYear = item.year
                        } label: {
                            Text("\(String(item.year))")
                                .font(.subheadline.weight(.medium))
                                .padding(.horizontal, 14)
                                .padding(.vertical, 7)
                                .background(
                                    item.year == selectedYear ? Palette.deepMint : Color(.secondarySystemGroupedBackground),
                                    in: Capsule()
                                )
                                .foregroundStyle(item.year == selectedYear ? .white : .primary)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var progressHeader: some View {
        if let currentProgress {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline) {
                    Text("\(String(selectedYear)) チョコミント図鑑")
                        .font(.headline)
                    Spacer()
                    Text("\(currentProgress.tastedCount) / \(currentProgress.totalCount)")
                        .font(.headline.monospacedDigit())
                        .foregroundStyle(Palette.deepMint)
                }
                ProgressView(value: currentProgress.ratio)
                    .tint(Palette.deepMint)
                Text(currentProgress.percentText)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            .padding(14)
            .cardBackground()
        }
    }

    private var grid: some View {
        LazyVGrid(columns: columns, spacing: 14) {
            ForEach(slots) { slot in
                NavigationLink(value: AppRoute.product(slot.product)) {
                    cell(slot)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func cell(_ slot: CollectionSlot) -> some View {
        VStack(spacing: 6) {
            ZStack(alignment: .bottomTrailing) {
                ProductThumbnail(product: slot.product, size: 96)
                    .saturation(slot.isTasted ? 1 : 0)
                    .opacity(slot.isTasted ? 1 : 0.35)
                    .overlay {
                        if !slot.isTasted {
                            Text("?")
                                .font(.title.weight(.bold))
                                .foregroundStyle(.secondary)
                        }
                    }
                if slot.isTasted {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(Palette.deepMint, .white)
                        .offset(x: 4, y: 4)
                }
            }
            Text(slot.isTasted ? slot.product.name : "？？？")
                .font(.caption2)
                .foregroundStyle(slot.isTasted ? .primary : .secondary)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .frame(height: 28, alignment: .top)
        }
    }

    private func load() async {
        guard let userId = session.userId else {
            isLoading = false
            return
        }
        isLoading = true
        defer { isLoading = false }
        async let slotsTask = (try? await session.services.library.collectionSlots(
            userId: userId, year: selectedYear
        )) ?? []
        async let progressTask = (try? await session.services.library.collectionProgress(
            userId: userId
        )) ?? []
        slots = await slotsTask
        progress = await progressTask
    }
}
