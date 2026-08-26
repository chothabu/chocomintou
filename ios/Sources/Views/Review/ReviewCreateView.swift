import SwiftUI

/// レビュー投稿（設計 §12）。必須は総合評価のみ。写真投稿は v1.0 では扱わない。
struct ReviewCreateView: View {
    let product: Product
    let existing: Review?
    let onSaved: () -> Void

    @Environment(SessionStore.self) private var session
    @Environment(\.dismiss) private var dismiss

    @State private var draft = ReviewDraft()
    @State private var isSubmitting = false
    @State private var errorMessage: String?
    @State private var isConfirmingDelete = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack(spacing: 12) {
                        ProductThumbnail(product: product, size: 48)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(product.name)
                                .font(.subheadline.weight(.semibold))
                            if let manufacturer = product.manufacturer {
                                Text(manufacturer)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }

                Section {
                    RatingPicker(title: "総合評価", value: $draft.overallRating, isRequired: true)
                }

                Section {
                    RatingPicker(title: "ミント強度", value: $draft.mintIntensity)
                    RatingPicker(title: "チョコ強度", value: $draft.chocolateIntensity)
                    RatingPicker(title: "甘さ", value: $draft.sweetness)
                    RatingPicker(title: "爽快感", value: $draft.freshness)
                    RatingPicker(title: "食感", value: $draft.texture)
                } header: {
                    Text("詳しい評価")
                } footer: {
                    Text("入力すると、この商品のミントレベルの精度が上がります。すべて任意です。")
                }

                Section {
                    TextField("ミント強めだけど甘さもしっかり。チョコチップが多くて好き。",
                              text: $draft.comment, axis: .vertical)
                        .lineLimit(4...10)
                    HStack {
                        Spacer()
                        Text("\(draft.comment.count) / \(ReviewDraft.commentLimit)")
                            .font(.caption2.monospacedDigit())
                            .foregroundStyle(draft.comment.count > ReviewDraft.commentLimit
                                ? AnyShapeStyle(Color.red) : AnyShapeStyle(.tertiary))
                    }
                } header: {
                    Text("コメント（任意）")
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }

                if existing != nil {
                    Section {
                        Button("このレビューを削除", role: .destructive) {
                            isConfirmingDelete = true
                        }
                    }
                }
            }
            .navigationTitle(existing == nil ? "レビューを書く" : "レビューを編集")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button("投稿") { Task { await submit() } }
                        .fontWeight(.semibold)
                        .disabled(!draft.isValid || isSubmitting)
                }
            }
            .onAppear {
                if let existing { draft = ReviewDraft(review: existing) }
            }
            .confirmationDialog("レビューを削除しますか？", isPresented: $isConfirmingDelete) {
                Button("削除する", role: .destructive) { Task { await deleteReview() } }
            }
        }
    }

    private func submit() async {
        guard let userId = session.userId else { return }
        isSubmitting = true
        errorMessage = nil
        defer { isSubmitting = false }
        do {
            try await session.services.reviews.submit(
                productId: product.id, draft: draft, userId: userId
            )
            onSaved()
            dismiss()
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? "投稿できませんでした。"
        }
    }

    private func deleteReview() async {
        guard let existing else { return }
        isSubmitting = true
        defer { isSubmitting = false }
        try? await session.services.reviews.delete(reviewId: existing.id)
        onSaved()
        dismiss()
    }
}
