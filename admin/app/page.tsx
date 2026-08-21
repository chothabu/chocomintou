import Link from 'next/link'
import { supabaseAdmin } from '@/lib/supabase'

export const dynamic = 'force-dynamic'

async function count(table: string, filter?: (query: any) => any): Promise<number> {
  const supabase = supabaseAdmin()
  let query = supabase.from(table).select('*', { count: 'exact', head: true })
  if (filter) query = filter(query)
  const { count: result } = await query
  return result ?? 0
}

export default async function DashboardPage() {
  const [published, unpublished, submissions, reports, sightings, stores] = await Promise.all([
    count('products', (q) => q.eq('is_published', true)),
    count('products', (q) => q.eq('is_published', false)),
    count('product_submissions', (q) => q.eq('status', 'pending')),
    count('review_reports', (q) => q.eq('status', 'pending')),
    count('sightings', (q) => q.eq('is_deleted', false)),
    count('stores'),
  ])

  return (
    <>
      <h1>ダッシュボード</h1>
      <p className="lead">対応が必要なものが上に出ます。</p>

      {(submissions > 0 || reports > 0 || unpublished > 0) && (
        <div className="notice">
          対応待ち:{' '}
          {unpublished > 0 && <Link href="/products?filter=unpublished">未公開の商品 {unpublished}件</Link>}
          {unpublished > 0 && (submissions > 0 || reports > 0) && ' / '}
          {submissions > 0 && <Link href="/submissions">ユーザー申請 {submissions}件</Link>}
          {submissions > 0 && reports > 0 && ' / '}
          {reports > 0 && <Link href="/reports">レビュー報告 {reports}件</Link>}
        </div>
      )}

      <div className="stats">
        <div className="stat">
          <div className="value">{published}</div>
          <div className="label">公開中の商品</div>
        </div>
        <div className="stat">
          <div className="value">{unpublished}</div>
          <div className="label">未公開の商品</div>
        </div>
        <div className="stat">
          <div className="value">{submissions}</div>
          <div className="label">未処理のユーザー申請</div>
        </div>
        <div className="stat">
          <div className="value">{reports}</div>
          <div className="label">未処理のレビュー報告</div>
        </div>
        <div className="stat">
          <div className="value">{sightings}</div>
          <div className="label">目撃情報</div>
        </div>
        <div className="stat">
          <div className="value">{stores}</div>
          <div className="label">登録された店舗</div>
        </div>
      </div>

      <h2>初期データの入れ方</h2>
      <div className="card">
        <p style={{ margin: 0 }}>
          商品は <Link href="/products/new">商品を追加</Link> から登録し、公開にします。
          店舗と目撃情報は運営者が現地で iOS アプリの目撃報告フローを使って入れてください
          （店舗マスタは報告時に自動生成されます）。
        </p>
      </div>
    </>
  )
}
