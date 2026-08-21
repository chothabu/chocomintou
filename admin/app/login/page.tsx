import { cookies } from 'next/headers'
import { redirect } from 'next/navigation'
import { SESSION_COOKIE, expectedToken, verifyPassword } from '@/lib/auth'

export const dynamic = 'force-dynamic'

async function signIn(formData: FormData) {
  'use server'
  const password = String(formData.get('password') ?? '')
  if (!verifyPassword(password)) {
    redirect('/login?error=1')
  }
  const store = await cookies()
  store.set(SESSION_COOKIE, expectedToken(), {
    httpOnly: true,
    sameSite: 'lax',
    secure: process.env.NODE_ENV === 'production',
    path: '/',
    maxAge: 60 * 60 * 12,
  })
  redirect('/')
}

export default async function LoginPage({
  searchParams,
}: {
  searchParams: Promise<{ error?: string }>
}) {
  const { error } = await searchParams

  return (
    <div className="card" style={{ maxWidth: 380, margin: '48px auto' }}>
      <h1>管理画面にログイン</h1>
      <p className="lead">運営者のみが使用します。</p>
      <form action={signIn}>
        <label>
          <span>パスワード</span>
          <input type="password" name="password" autoFocus required />
        </label>
        {error && <p className="error">パスワードが違います。</p>}
        <button className="primary" type="submit">
          ログイン
        </button>
      </form>
    </div>
  )
}
