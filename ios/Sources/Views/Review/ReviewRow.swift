import SwiftUI

/// レビュー 1 件（設計 §13）。
/// UGC なので、各行から通報とブロックができる（設計 §14 / App Review Guideline 1.2）。
struct ReviewRow: View {
    let review: Review
    var onChanged: () -> Void

    @Environment(SessionStore.self) private var session
    @State private var isPresentingReport = false
    @State private var helpfulDelta = 0
    @State private var hasMarkedHelpful = false
    @State private var isHidden = false

    var body: some View {
        if isHidden {
            // ブロック直後に行が消えたことを伝える。再読み込みで完全に消える。
            Text("このユーザーのレビューは非表示にしました。")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            content
        }
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    StarRatingView(rating: Double(review.overallRating), size: 13)
                    if let mint = review.mintIntensity {
                        Text("ミント強度 \(mint)")
                            .font(.caption)
                            .foregroundStyle(Palette.deepMint)
                    }
                }
                Spacer()
                Menu {
                    Button("報告する", systemImage: "flag") {
                        session.requireSignIn { isPresentingReport = true }
                    }
                    Button("このユーザーをブロック", systemImage: "hand.raised", role: .destructive) {
                        session.requireSignIn { Task { await block() } }
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(width: 32, height: 24, alignment: .trailing)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel("このレビューの操作")
            }

            if let comment = review.comment, !comment.isEmpty {
                Text(comment)
                    .font(.subheadline)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack {
                Text(review.authorName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(Formatters.relative(review.createdAt))
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                Spacer()
                Button {
                    session.requireSignIn { Task { await toggleHelpful() } }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: hasMarkedHelpful ? "hand.thumbsup.fill" : "hand.thumbsup")
                        Text("\(review.helpfulCount + helpfulDelta)")
                            .monospacedDigit()
                    }
                    .font(.caption)
                }
                .buttonStyle(.plain)
                .foregroundStyle(hasMarkedHelpful ? Palette.deepMint : .secondary)
            }
        }
        .sheet(isPresented: $isPresentingReport) {
            ReviewReportView(review: review)
        }
    }

    private func toggleHelpful() async {
        guard let userId = session.userId else { return }
        let next = !hasMarkedHelpful
        hasMarkedHelpful = next
        helpfulDelta += next ? 1 : -1
        do {
            try await session.services.reviews.setHelpful(next, reviewId: review.id, userId: userId)
        } catch {
            hasMarkedHelpful = !next
            helpfulDelta += next ? -1 : 1
        }
    }

    private func block() async {
        guard let userId = session.userId else { return }
        try? await session.services.reviews.block(review.userId, by: userId)
        isHidden = true
        onChanged()
    }
}

/// 通報の理由を選ばせる。
struct ReviewReportView: View {
    let review: Review

    @Environment(SessionStore.self) private var session
    @Environment(\.dismiss) private var dismiss
    @State private var draft = ReviewReportDraft()
    @State private var isSubmitting = false
    @State private var isDone = false

    var body: some View {
        NavigationStack {
            Form {
                if isDone {
                    Section {
                        Label("報告を受け付けました。運営が確認します。", systemImage: "checkmark.circle")
                            .foregroundStyle(Palette.deepMint)
                    }
                } else {
                    Section("理由") {
                        Picker("理由", selection: $draft.reason) {
                            ForEach(ReportReason.allCases) { reason in
                                Text(reason.displayName).tag(reason)
                            }
                        }
                        .pickerStyle(.inline)
                        .labelsHidden()
                    }

                    Section("詳細（任意）") {
                        TextField("補足があれば記入してください", text: $draft.detail, axis: .vertical)
                            .lineLimit(3...6)
                    }
                }
            }
            .navigationTitle("レビューを報告")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(isDone ? "閉じる" : "キャンセル") { dismiss() }
                }
                if !isDone {
                    ToolbarItem(placement: .primaryAction) {
                        Button("送信") { Task { await submit() } }
                            .disabled(isSubmitting)
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }

    private func submit() async {
        guard let userId = session.userId else { return }
        isSubmitting = true
        defer { isSubmitting = false }
        try? await session.services.reviews.report(reviewId: review.id, draft: draft, userId: userId)
        isDone = true
    }
}
