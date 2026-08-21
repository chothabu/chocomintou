import Link from 'next/link'
import { CATEGORIES, SALE_STATUSES, supabaseAdmin, type Product } from '@/lib/supabase'
import { setPublished } from './actions'

export const dynamic = 'force-dynamic'

const categoryLabel = (value: string) =>
  CATEGORIES.find((item) => item.value === value)?.label ?? value
const statusLabel = (value: string) =>
  SALE_STATUSES.find((item) => item.value === value)?.label ?? value

export default async function ProductsPage({
  searchParams,
}: {
  searchParams: Promise<{ filter?: string; q?: string }>
}) {
  const { filter, q } = await searchParams
  const supabase = supabaseAdmin()

  let query = supabase.from('products').select('*').order('created_at', { ascending: false }).limit(200)
  if (filter === 'unpublished') query = query.eq('is_published', false)
  if (filter === 'published') query = query.eq('is_published', true)
  if (q) query = query.ilike('name', `%${q}%`)

  const { data, error } = await query
  const products = (data ?? []) as Product[]

  return (
    <>
      <h1>商品</h1>
      <p className="lead">
        公開にすると iOS アプリに出ます。未公開のままなら誰にも見えません。
      </p>

      <div className="card" style={{ display: 'flex', gap: 12, alignItems: 'center', flexWrap: 'wrap' }}>
        <form style={{ display: 'flex', gap: 8, flex: 1 }}>
          <input type="text" name="q" defaultValue={q ?? ''} placeholder="商品名で検索" />
          <button type="submit">検索</button>
        </form>
        <div className="row-actions">
          <Link className="button" href="/products">
            すべて
          </Link>
          <Link className="button" href="/products?filter=unpublished">
            未公開
          </Link>
          <Link className="button" href="/products?filter=published">
            公開中
          </Link>
          <Link className="button" href="/products/new">
            ＋ 商品を追加
          </Link>
        </div>
      </div>

      {error && <p className="error">読み込みに失敗しました: {error.message}</p>}

      {products.length === 0 ? (
        <div className="card empty">該当する商品がありません。</div>
      ) : (
        <table>
          <thead>
            <tr>
              <th>商品名</th>
              <th>カテゴリ</th>
              <th>販売状況</th>
              <th>レビュー</th>
              <th>状態</th>
              <th />
            </tr>
          </thead>
          <tbody>
            {products.map((product) => (
              <tr key={product.id}>
                <td>
                  <Link href={`/products/${product.id}`}>{product.name}</Link>
                  <div style={{ color: 'var(--muted)', fontSize: 12 }}>
                    {product.manufacturer ?? 'メーカー未設定'}
                  </div>
                </td>
                <td>{categoryLabel(product.category)}</td>
                <td>
                  {statusLabel(product.sale_status)}
                  {product.is_limited && <span className="badge" style={{ marginLeft: 6 }}>期間限定</span>}
                </td>
                <td>
                  {product.review_count > 0
                    ? `${product.avg_overall?.toFixed(1) ?? '-'} (${product.review_count})`
                    : '—'}
                  {product.mint_level && (
                    <span className="badge" style={{ marginLeft: 6 }}>Lv{product.mint_level}</span>
                  )}
                </td>
                <td>
                  <span className={product.is_published ? 'badge' : 'badge grey'}>
                    {product.is_published ? '公開中' : '未公開'}
                  </span>
                </td>
                <td>
                  <form action={setPublished}>
                    <input type="hidden" name="id" value={product.id} />
                    <input type="hidden" name="published" value={String(!product.is_published)} />
                    <button type="submit" className={product.is_published ? '' : 'primary'}>
                      {product.is_published ? '非公開にする' : '公開する'}
                    </button>
                  </form>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      )}
    </>
  )
}
