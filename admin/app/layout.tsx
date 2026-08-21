import type { Metadata } from 'next'
import Link from 'next/link'
import './globals.css'

export const metadata: Metadata = {
  title: 'チョコミン党 管理画面',
  description: '商品・ユーザー申請・レビュー報告・ニュースの管理',
}

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="ja">
      <body>
        <header className="site">
          <strong>🌿 チョコミン党 管理</strong>
          <nav>
            <Link href="/">ダッシュボード</Link>
            <Link href="/products">商品</Link>
            <Link href="/submissions">商品候補</Link>
            <Link href="/reports">レビュー報告</Link>
            <Link href="/news">ニュース</Link>
            <Link href="/news/sources">収集元</Link>
          </nav>
        </header>
        <main>{children}</main>
      </body>
    </html>
  )
}
