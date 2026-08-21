import SwiftUI

/// ユーザーによる商品報告（設計 §29-30）。
/// 投稿後は「確認中」となり、運営が承認してから公開される。
struct ProductSubmissionView: View {
    @Environment(SessionStore.self) private var session
    @Environment(\.dismiss) private var dismiss

    @State private var draft = ProductSubmissionDraft()
    @State private var hasReleaseDate = false
    @State private var releaseDate = Date()
    @State private var isSubmitting = false
    @State private var isDone = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                if isDone {
                    Section {
                        VStack(spacing: 10) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 40))
                                .foregroundStyle(Palette.deepMint)
                            Text("報告を受け付けました")
                                .font(.headline)
                            Text("運営が確認してから図鑑に追加されます。ありがとうございます。")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                    }
                } else {
                    Section {
                        TextField("チョコミント◯◯", text: $draft.name)
                    } header: {
                        Text("商品名（必須）")
                    }

                    Section("わかる範囲で") {
                        TextField("メーカー", text: $draft.manufacturer)
                        Picker("カテゴリ", selection: $draft.category) {
                            ForEach(ProductCategory.allCases) { category in
                                Text(category.displayName).tag(category)
                            }
                        }
                        TextField("価格（数字のみ）", text: $draft.price)
                            .keyboardType(.numberPad)
                        TextField("購入した場所", text: $draft.purchasePlace)
                        Toggle("発売日がわかる", isOn: $hasReleaseDate)
                        if hasReleaseDate {
                            DatePicker("発売日", selection: $releaseDate, displayedComponents: .date)
                        }
                    }

                    Section {
                        TextField("備考", text: $draft.note, axis: .vertical)
                            .lineLimit(3...6)
                    } footer: {
                        Text("商品画像は運営が用意します。写真の投稿はできません。")
                    }

                    if let errorMessage {
                        Section {
                            Text(errorMessage)
                                .font(.caption)
                                .foregroundStyle(.red)
                        }
                    }
                }
            }
            .navigationTitle("新しいチョコミントを報告")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(isDone ? "閉じる" : "キャンセル") { dismiss() }
                }
                if !isDone {
                    ToolbarItem(placement: .primaryAction) {
                        Button("送信") { submit() }
                            .fontWeight(.semibold)
                            .disabled(!draft.isValid || isSubmitting)
                    }
                }
            }
        }
    }

    private func submit() {
        session.requireSignIn {
            Task { await performSubmit() }
        }
    }

    private func performSubmit() async {
        guard let userId = session.userId else { return }
        isSubmitting = true
        errorMessage = nil
        defer { isSubmitting = false }

        draft.releaseDate = hasReleaseDate ? releaseDate : nil
        do {
            try await session.services.products.submitProduct(draft, userId: userId)
            isDone = true
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? "送信できませんでした。"
        }
    }
}
