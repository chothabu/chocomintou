import CryptoKit
import Foundation

/// Sign in with Apple のリプレイ攻撃対策に使う nonce。
///
/// Apple には SHA256 でハッシュした値を渡し、Supabase には元の値を渡す。
/// Supabase 側が ID トークン内のハッシュと突き合わせて検証する。
enum AppleSignInNonce {
    struct Pair: Sendable {
        /// Supabase に渡す元の値。
        let raw: String
        /// Apple のリクエストに渡すハッシュ値。
        let hashed: String
    }

    static func make(length: Int = 32) -> Pair {
        let raw = randomString(length: length)
        return Pair(raw: raw, hashed: sha256(raw))
    }

    private static func randomString(length: Int) -> String {
        let charset = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        for _ in 0..<length {
            var byte: UInt8 = 0
            _ = withUnsafeMutableBytes(of: &byte) { SecRandomCopyBytes(kSecRandomDefault, 1, $0.baseAddress!) }
            result.append(charset[Int(byte) % charset.count])
        }
        return result
    }

    private static func sha256(_ input: String) -> String {
        SHA256.hash(data: Data(input.utf8))
            .map { String(format: "%02x", $0) }
            .joined()
    }
}
