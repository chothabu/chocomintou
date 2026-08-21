import { cookies } from 'next/headers'

export const SESSION_COOKIE = 'chocomint_admin'

/**
 * 最小限のパスワードゲート。
 *
 * 運営者が数人しかいない前提の暫定実装。実運用では Vercel Authentication や
 * SSO の後ろに置くこと。ここだけで守り切る設計にはしていない。
 */
export function expectedToken(): string {
  const secret = process.env.ADMIN_SESSION_SECRET
  if (!secret) throw new Error('ADMIN_SESSION_SECRET を設定してください')
  return secret
}

export function verifyPassword(input: string): boolean {
  const password = process.env.ADMIN_PASSWORD
  if (!password) throw new Error('ADMIN_PASSWORD を設定してください')
  // 長さが違えば即不一致。時間差での推測を避けるため全文字を比較する。
  if (input.length !== password.length) return false
  let diff = 0
  for (let i = 0; i < password.length; i += 1) {
    diff |= input.charCodeAt(i) ^ password.charCodeAt(i)
  }
  return diff === 0
}

export async function isSignedIn(): Promise<boolean> {
  const store = await cookies()
  return store.get(SESSION_COOKIE)?.value === expectedToken()
}
