import AuthenticationServices
import SwiftUI

/// ログイン。方法は Sign in with Apple のみ（設計 §39）。
struct SignInView: View {
    @Environment(SessionStore.self) private var session
    @Environment(\.dismiss) private var dismiss
    @State private var nonce = AppleSignInNonce.make()
    @State private var isWorking = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()

                VStack(spacing: 12) {
                    Text("🌿")
                        .font(.system(size: 56))
                    Text("チョコミントを記録しよう")
                        .font(.title3.weight(.bold))
                    Text("見るだけならログインは不要です。\n「食べた」「レビュー」「目撃報告」を使うときだけ必要になります。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                Spacer()

                if let message = session.signInErrorMessage {
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                }

                if session.services.usesSampleData {
                    // サンプルデータ動作時は Apple の認証基盤に接続できないため、
                    // 同じ導線を確認できるダミーのログインを用意する。
                    Button {
                        Task { await signInAsSampleUser() }
                    } label: {
                        Label("サンプルユーザーでログイン", systemImage: "person.fill")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isWorking)

                    Text("Supabase の接続先が未設定のため、サンプルデータで動作しています。")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .multilineTextAlignment(.center)
                } else {
                    SignInWithAppleButton(.signIn) { request in
                        request.requestedScopes = [.fullName]
                        request.nonce = nonce.hashed
                    } onCompletion: { result in
                        Task { await handle(result) }
                    }
                    .signInWithAppleButtonStyle(.black)
                    .frame(height: 50)
                    .disabled(isWorking)
                }

                Text("収集するのは表示名だけです。本名・住所・性別は保存しません。")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
            }
            .padding(24)
            .navigationTitle("ログイン")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") {
                        session.cancelSignIn()
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .interactiveDismissDisabled(isWorking)
    }

    private func signInAsSampleUser() async {
        isWorking = true
        await session.signIn(idToken: "sample", nonce: "sample", suggestedName: nil)
        isWorking = false
        if session.isSignedIn { dismiss() }
    }

    private func handle(_ result: Result<ASAuthorization, any Error>) async {
        isWorking = true
        defer { isWorking = false }

        switch result {
        case let .success(authorization):
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
                  let tokenData = credential.identityToken,
                  let idToken = String(data: tokenData, encoding: .utf8)
            else {
                session.signInErrorMessage = "Apple から認証情報を取得できませんでした。"
                return
            }
            // 名前は初回サインイン時にしか返らない。取れたときだけ表示名の候補にする。
            let suggestedName = credential.fullName.flatMap { components in
                PersonNameComponentsFormatter.localizedString(from: components, style: .default)
            }
            await session.signIn(idToken: idToken, nonce: nonce.raw, suggestedName: suggestedName)
            // 使い回しを防ぐため、成否にかかわらず nonce を作り直す。
            nonce = AppleSignInNonce.make()
            if session.isSignedIn { dismiss() }

        case let .failure(error):
            if (error as? ASAuthorizationError)?.code == .canceled { return }
            session.signInErrorMessage = error.localizedDescription
        }
    }
}
