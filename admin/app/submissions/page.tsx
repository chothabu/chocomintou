import { revalidatePath } from 'next/cache'
import { redirect } from 'next/navigation'
import { CATEGORIES, SOURCE_LABELS, supabaseAdmin, type Submission } from '@/lib/supabase'

export const dynamic = 'force-dynamic'

/** 承認すると products に行を作り、申請と紐付ける。公開は担当者が内容を確認してから行う。 */
async function approve(formData: FormData) {
  'use server'
  const id = String(formData.get('id'))
  const supabase = supabaseAdmin()

  const { data: submission } = await supabase
    .from('product_submissions')
    .select('*')
    .eq('id', id)
    .maybeSingle()
  if (!submission) return

  const { data: product, error } = await supabase
    .from('products')
    .insert({
      name: submission.name,
      manufacturer: submission.manufacturer,
      category: submission.category ?? 'other',
      price: submission.price,
      release_date: submission.release_date,
      sales_channel_text: submission.purchase_place,
      description: submission.note,
      // 収集元の画像とページはそのまま引き継ぐ（差し替えは編集画面で行う）
      image_url: submission.image_url,
      official_url: submission.external_url,
      // 内容を確認してから公開するため、この時点では未公開のまま。
      is_published: false,
    })
    .select('id')
    .single()
  if (error) throw new Error(error.message)

  await supabase
    .from('product_submissions')
    .update({ status: 'approved', product_id: product.id })
    .eq('id', id)

  revalidatePath('/submissions')
  redirect(`/products/${product.id}`)
}

async function reject(formData: FormData) {
  'use server'
  const id = String(formData.get('id'))
  const supabase = supabaseAdmin()
  await supabase.from('product_submissions').update({ status: 'rejected' }).eq('id', id)
  revalidatePath('/submissions')
}

const categoryLabel = (value: string | null) =>
  CATEGORIES.find((item) => item.value === value)?.label ?? '未設定'

export default async function SubmissionsPage({
  searchParams,
}: {
  searchParams: Promise<{ status?: string; source?: string }>
}) {
  const { status = 'pending', source } = await searchParams
  const supabase = supabaseAdmin()
  let query = supabase
    .from('product_submissions')
    .select('*')
    .eq('status', status)
    .order('created_at', { ascending: false })
    .limit(200)
  if (source) query = query.eq('source', source)

  const { data } = await query
  const submissions = (data ?? []) as Submission[]

  return (
    <>
      <h1>商品候補</h1>
      <p className="lead">
        ユーザーからの報告と、収集バッチが集めた候補が並びます。
        承認すると未公開の商品として登録されるので、内容を確認してから公開してください。
      </p>

      <div className="card row-actions">
        <a className="button" href="/submissions?status=pending">
          未処理
        </a>
        <a className="button" href="/submissions?status=approved">
          承認済み
        </a>
        <a className="button" href="/submissions?status=rejected">
          却下
        </a>
        <span style={{ flex: 1 }} />
        <a className="button" href="/submissions?status=pending&source=user">
          ユーザー報告のみ
        </a>
        <a className="button" href="/submissions?status=pending&source=rakuten">
          収集分のみ
        </a>
      </div>

      {submissions.length === 0 ? (
        <div className="card empty">該当する申請はありません。</div>
      ) : (
        <table>
          <thead>
            <tr>
              <th>商品名</th>
              <th>メーカー / カテゴリ</th>
              <th>購入場所・備考</th>
              <th>申請日</th>
              <th />
            </tr>
          </thead>
          <tbody>
            {submissions.map((submission) => (
              <tr key={submission.id}>
                <td style={{ maxWidth: 320 }}>
                  <div style={{ display: 'flex', gap: 10 }}>
                    {submission.image_url && (
                      // 収集元の画像はドメインが多岐にわたるため next/image は使わない
                      // eslint-disable-next-line @next/next/no-img-element
                      <img
                        src={submission.image_url}
                        alt=""
                        width={56}
                        height={56}
                        style={{ objectFit: 'cover', borderRadius: 6, flexShrink: 0 }}
                      />
                    )}
                    <div>
                      <strong>{submission.name}</strong>
                      <div style={{ marginTop: 3 }}>
                        <span className={submission.source === 'user' ? 'badge' : 'badge grey'}>
                          {SOURCE_LABELS[submission.source] ?? submission.source}
                        </span>
                        {submission.price !== null && (
                          <span style={{ color: 'var(--muted)', fontSize: 12, marginLeft: 6 }}>
                            {submission.price}円
                          </span>
                        )}
                      </div>
                      {submission.external_url && (
                        <a
                          href={submission.external_url}
                          target="_blank"
                          rel="noreferrer"
                          style={{ fontSize: 12 }}
                        >
                          元ページを開く
                        </a>
                      )}
                    </div>
                  </div>
                </td>
                <td>
                  {submission.manufacturer ?? '—'}
                  <div style={{ color: 'var(--muted)', fontSize: 12 }}>
                    {categoryLabel(submission.category)}
                  </div>
                </td>
                <td style={{ maxWidth: 280 }}>
                  {submission.purchase_place ?? '—'}
                  {submission.note && (
                    <div style={{ color: 'var(--muted)', fontSize: 12 }}>{submission.note}</div>
                  )}
                </td>
                <td>{new Date(submission.created_at).toLocaleDateString('ja-JP')}</td>
                <td>
                  {status === 'pending' && (
                    <div className="row-actions">
                      <form action={approve}>
                        <input type="hidden" name="id" value={submission.id} />
                        <button className="primary" type="submit">
                          承認
                        </button>
                      </form>
                      <form action={reject}>
                        <input type="hidden" name="id" value={submission.id} />
                        <button type="submit">却下</button>
                      </form>
                    </div>
                  )}
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      )}
    </>
  )
}
