import Foundation
import SwiftUI

/// ログイン状態と、アプリ全体で共有するサービス一式を持つ。
///
/// 閲覧はログイン不要なので、ログインが要る操作の直前にだけ `requireSignIn()` を通す（設計 §39）。
@MainActor
@Observable
final class SessionStore {
    let services: AppServices

    private(set) var currentUser: UserProfile?
    private(set) var isRestoring = true

    /// ログインが必要な操作を試みたときに立てる。RootView がシートを出す。
    var isPresentingSignIn = false
    var signInErrorMessage: String?

    /// ログイン後に実行したい操作。ログイン成功時に呼ばれる。
    private var pendingAction: (@MainActor () -> Void)?

    init(services: AppServices) {
        self.services = services
    }

    var isSignedIn: Bool { currentUser != nil }
    var userId: UUID? { currentUser?.id }

    func restore() async {
        currentUser = await services.auth.restore()
        isRestoring = false
    }

    /// ログイン済みなら `action` をそのまま実行し、未ログインならログインシートを出して保留する。
    func requireSignIn(then action: @escaping @MainActor () -> Void) {
        if currentUser != nil {
            action()
        } else {
            pendingAction = action
            isPresentingSignIn = true
        }
    }

    func signIn(idToken: String, nonce: String, suggestedName: String?) async {
        signInErrorMessage = nil
        do {
            currentUser = try await services.auth.signInWithApple(
                idToken: idToken, nonce: nonce, suggestedName: suggestedName
            )
            isPresentingSignIn = false
            let action = pendingAction
            pendingAction = nil
            action?()
        } catch {
            signInErrorMessage = (error as? LocalizedError)?.errorDescription
                ?? "ログインに失敗しました。時間をおいて試してください。"
        }
    }

    func cancelSignIn() {
        pendingAction = nil
        isPresentingSignIn = false
        signInErrorMessage = nil
    }

    func signOut() async {
        await services.auth.signOut()
        currentUser = nil
    }

    func updateDisplayName(_ name: String) async {
        guard let userId else { return }
        currentUser = try? await services.auth.updateDisplayName(name, userId: userId)
    }

    func deleteAccount() async {
        guard let userId else { return }
        try? await services.auth.deleteAccount(userId: userId)
        currentUser = nil
    }
}
