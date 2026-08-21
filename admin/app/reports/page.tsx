import { revalidatePath } from 'next/cache'
import { REASON_LABELS, supabaseAdmin, type ReviewReport } from '@/lib/supabase'

export const dynamic = 'force-dynamic'

/** レビューを非表示にして、報告を処理済みにする。 */
async function hideReview(formData: FormData) {
  'use server'
  const reportId = String(formData.get('report_id'))
  const reviewId = String(formData.get('review_id'))
  const supabase = supabaseAdmin()
  await supabase.from('reviews').update({ is_hidden: true }).eq('id', reviewId)
  await supabase.from('review_reports').update({ status: 'actioned' }).eq('id', reportId)
  revalidatePath('/reports')
}

async function dismiss(formData: FormData) {
  'use server'
  const reportId = String(formData.get('report_id'))
  const supabase = supabaseAdmin()
  await supabase.from('review_reports').update({ status: 'dismissed' }).eq('id', reportId)
  revalidatePath('/reports')
}

/** 投稿者を停止する。RLS 側で停止ユーザーの投稿を弾く運用にする。 */
async function suspendUser(formData: FormData) {
  'use server'
  const reportId = String(formData.get('report_id'))
  const userId = String(formData.get('user_id'))
  const supabase = supabaseAdmin()
  await supabase.from('users').update({ is_suspended: true }).eq('id', userId)
  await supabase.from('review_reports').update({ status: 'actioned' }).eq('id', reportId)
  revalidatePath('/reports')
}

export default async function ReportsPage({
  searchParams,
}: {
  searchParams: Promise<{ status?: string }>
}) {
  const { status = 'pending' } = await searchParams
  const supabase = supabaseAdmin()

  const { data, error } = await supabase
    .from('review_reports')
    .select(
      `id, review_id, reason, detail, status, created_at,
       review:reviews(id, comment, overall_rating, user_id, is_hidden,
                      product:products(id, name),
                      author:users(id, display_name, is_suspended))`,
    )
    .eq('status', status)
    .order('created_at', { ascending: false })
    .limit(200)

  const reports = (data ?? []) as unknown as ReviewReport[]

  return (
    <>
      <h1>レビュー報告</h1>
      <p className="lead">
        ユーザーから通報されたレビューです。非表示にするとアプリから見えなくなります。
      </p>

      <div className="card row-actions">
        <a className="button" href="/reports?status=pending">
          未処理
        </a>
        <a className="button" href="/reports?status=actioned">
          対応済み
        </a>
        <a className="button" href="/reports?status=dismissed">
          却下
        </a>
      </div>

      {error && <p className="error">読み込みに失敗しました: {error.message}</p>}

      {reports.length === 0 ? (
        <div className="card empty">該当する報告はありません。</div>
      ) : (
        reports.map((report) => (
          <div className="card" key={report.id}>
            <div style={{ display: 'flex', gap: 10, alignItems: 'center', flexWrap: 'wrap' }}>
              <span className="badge">{REASON_LABELS[report.reason] ?? report.reason}</span>
              <span style={{ color: 'var(--muted)', fontSize: 12 }}>
                {new Date(report.created_at).toLocaleString('ja-JP')}
              </span>
              {report.review?.is_hidden && <span className="badge grey">非表示済み</span>}
              {report.review?.author?.is_suspended && <span className="badge grey">停止中</span>}
            </div>

            {report.detail && <p style={{ marginBottom: 4 }}>通報者のコメント: {report.detail}</p>}

            <div
              style={{
                background: 'var(--bg)',
                border: '1px solid var(--border)',
                borderRadius: 8,
                padding: 12,
                margin: '12px 0',
              }}
            >
              <div style={{ fontSize: 12, color: 'var(--muted)' }}>
                {report.review?.product?.name ?? '（商品不明）'} / 評価 {report.review?.overall_rating}
                {' / '}
                {report.review?.author?.display_name ?? '（投稿者不明）'}
              </div>
              <p style={{ margin: '6px 0 0' }}>{report.review?.comment ?? '（コメントなし）'}</p>
            </div>

            {status === 'pending' && report.review && (
              <div className="row-actions">
                <form action={hideReview}>
                  <input type="hidden" name="report_id" value={report.id} />
                  <input type="hidden" name="review_id" value={report.review.id} />
                  <button className="primary" type="submit">
                    レビューを非表示にする
                  </button>
                </form>
                <form action={suspendUser}>
                  <input type="hidden" name="report_id" value={report.id} />
                  <input type="hidden" name="user_id" value={report.review.user_id} />
                  <button className="danger" type="submit">
                    投稿者を停止する
                  </button>
                </form>
                <form action={dismiss}>
                  <input type="hidden" name="report_id" value={report.id} />
                  <button type="submit">問題なし（却下）</button>
                </form>
              </div>
            )}
          </div>
        ))
      )}
    </>
  )
}
