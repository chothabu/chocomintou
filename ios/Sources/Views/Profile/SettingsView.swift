import SwiftData
import SwiftUI

struct SettingsView: View {
    @Environment(SessionStore.self) private var session
    @Environment(\.modelContext) private var modelContext

    @State private var displayName = ""
    @State private var isEditingName = false
    @State private var isConfirmingSignOut = false
    @State private var isConfirmingDelete = false

    var body: some View {
        List {
            if session.isSignedIn {
                Section("アカウント") {
                    HStack {
                        Text("表示名")
                        Spacer()
                        Text(session.currentUser?.displayName ?? "—")
                            .foregroundStyle(.secondary)
                    }
                    Button("表示名を変更") {
                        displayName = session.currentUser?.displayName ?? ""
                        isEditingName = true
                    }
                }
            }

            Section {
                Label("位置情報は「アプリ使用中のみ」利用します", systemImage: "location")
                    .font(.subheadline)
                Label("目撃情報はユーザーの報告であり、在庫を保証しません", systemImage: "eye")
                    .font(.subheadline)
                Label("レビュー写真の投稿は行えません", systemImage: "photo")
                    .font(.subheadline)
            } header: {
                Text("このアプリについて")
            } footer: {
                Text("収集するのは表示名だけです。本名・住所・性別・メールアドレスは保存しません。")
            }

            Section {
                Button("キャッシュを削除") {
                    CacheStore(context: modelContext).clearAll()
                }
            } footer: {
                Text("オフライン表示用に保存している直近のデータを消します。")
            }

            if session.isSignedIn {
                Section {
                    Button("ログアウト") { isConfirmingSignOut = true }
                    Button("アカウントを削除", role: .destructive) { isConfirmingDelete = true }
                } footer: {
                    Text("アカウントを削除すると、食べた記録・レビュー・目撃報告もすべて削除されます。")
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("設定")
        .navigationBarTitleDisplayMode(.inline)
        .alert("表示名を変更", isPresented: $isEditingName) {
            TextField("表示名", text: $displayName)
            Button("キャンセル", role: .cancel) {}
            Button("保存") {
                Task { await session.updateDisplayName(displayName) }
            }
        }
        .confirmationDialog("ログアウトしますか？", isPresented: $isConfirmingSignOut) {
            Button("ログアウト", role: .destructive) { Task { await session.signOut() } }
        }
        .confirmationDialog(
            "アカウントを削除しますか？この操作は取り消せません。",
            isPresented: $isConfirmingDelete,
            titleVisibility: .visible
        ) {
            Button("削除する", role: .destructive) { Task { await session.deleteAccount() } }
        }
    }
}
