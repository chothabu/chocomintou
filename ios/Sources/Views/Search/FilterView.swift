import SwiftUI

/// 絞り込み（設計 §7）。
struct FilterView: View {
    @Binding var filter: ProductFilter
    let onApply: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var draft = ProductFilter()

    var body: some View {
        NavigationStack {
            Form {
                Section("販売状況") {
                    ForEach(SaleStatus.allCases) { status in
                        toggleRow(status.displayName, isOn: draft.saleStatuses.contains(status)) {
                            toggle(status, in: &draft.saleStatuses)
                        }
                    }
                    Toggle("期間限定のみ", isOn: $draft.limitedOnly)
                }

                Section {
                    ForEach(MintLevel.allCases) { level in
                        toggleRow(
                            "\(level.label)　\(level.description)",
                            isOn: draft.mintLevels.contains(level)
                        ) {
                            toggle(level, in: &draft.mintLevels)
                        }
                    }
                } header: {
                    Text("ミントレベル")
                } footer: {
                    Text("レビューのミント強度の平均から自動で決まります。レビューがまだ無い商品は該当しません。")
                }

                Section("商品カテゴリ") {
                    ForEach(ProductCategory.allCases) { category in
                        toggleRow(category.displayName, isOn: draft.categories.contains(category)) {
                            toggle(category, in: &draft.categories)
                        }
                    }
                }

                Section {
                    ForEach(ChainName.filterable) { chain in
                        toggleRow(chain.displayName, isOn: draft.chains.contains(chain)) {
                            toggle(chain, in: &draft.chains)
                        }
                    }
                } header: {
                    Text("チェーン")
                } footer: {
                    Text("メーカーが公表している取り扱いチェーンです。実際に置いてあるかは目撃情報を確認してください。")
                }
            }
            .navigationTitle("絞り込み")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button("適用") {
                        filter = draft
                        onApply()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
                ToolbarItem(placement: .bottomBar) {
                    Button("すべてクリア") { draft.reset() }
                        .disabled(draft.isEmpty)
                }
            }
            .onAppear { draft = filter }
        }
    }

    private func toggleRow(_ title: String, isOn: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Text(title)
                    .foregroundStyle(.primary)
                Spacer()
                if isOn {
                    Image(systemName: "checkmark")
                        .foregroundStyle(Palette.deepMint)
                        .fontWeight(.semibold)
                }
            }
        }
    }

    private func toggle<T: Hashable>(_ value: T, in set: inout Set<T>) {
        if set.contains(value) { set.remove(value) } else { set.insert(value) }
    }
}
