import { revalidatePath } from 'next/cache'
import { supabaseAdmin } from '@/lib/supabase'

export const dynamic = 'force-dynamic'

type NewsSource = {
  id: string
  name: string
  feed_url: string
  is_enabled: boolean
  last_fetched_at: string | null
  last_error: string | null
}

async function addSource(formData: FormData) {
  'use server'
  const name = String(formData.get('name') ?? '').trim()
  const feedUrl = String(formData.get('feed_url') ?? '').trim()
  if (!name || !feedUrl) return

  const supabase = supabaseAdmin()
  await supabase.from('news_sources').insert({ name, feed_url: feedUrl, is_enabled: false })
  revalidatePath('/news/sources')
}

async function setEnabled(formData: FormData) {
  'use server'
  const id = String(formData.get('id'))
  const enabled = formData.get('enabled') === 'true'
  const supabase = supabaseAdmin()
  await supabase.from('news_sources').update({ is_enabled: enabled }).eq('id', id)
  revalidatePath('/news/sources')
}

async function removeSource(formData: FormData) {
  'use server'
  const id = String(formData.get('id'))
  const supabase = supabaseAdmin()
  await supabase.from('news_sources').delete().eq('id', id)
  revalidatePath('/news/sources')
}

export default async function NewsSourcesPage() {
  const supabase = supabaseAdmin()
  const { data } = await supabase
    .from('news_sources')
    .select('id, name, feed_url, is_enabled, last_fetched_at, last_error')
    .order('created_at', { ascending: true })

  const sources = (data ?? []) as NewsSource[]

  return (
    <>
      <h1>ニュースの収集元</h1>
      <p className="lead">
        収集バッチはここで「有効」にしたフィードだけを巡回します。
      </p>

      <div className="notice">
        <strong>フィードを追加する前に、その配信元の利用条件を確認してください。</strong>
        <br />
        取得した内容を自前のサービスで再配信することを禁じているフィードがあります。
        たとえば Google ニュースの RSS は、フィード自身が「個人の非商用利用以外は明示的に禁止」と
        定めているため、このアプリでは使えません。
      </div>

      <div className="card">
        <form action={addSource}>
          <div className="grid-2">
            <label>
              <span>表示名（記事の媒体名として保存されます）</span>
              <input type="text" name="name" placeholder="◯◯ニュース" required />
            </label>
            <label>
              <span>フィード URL（RSS / RDF / Atom）</span>
              <input type="url" name="feed_url" placeholder="https://example.com/feed" required />
            </label>
          </div>
          <button className="primary" type="submit">
            追加する（初期状態は無効）
          </button>
        </form>
      </div>

      {sources.length === 0 ? (
        <div className="card empty">収集元がまだありません。</div>
      ) : (
        <table>
          <thead>
            <tr>
              <th>表示名</th>
              <th>フィード URL</th>
              <th>最終取得</th>
              <th>状態</th>
              <th />
            </tr>
          </thead>
          <tbody>
            {sources.map((source) => (
              <tr key={source.id}>
                <td>{source.name}</td>
                <td style={{ maxWidth: 300, wordBreak: 'break-all' }}>
                  <a href={source.feed_url} target="_blank" rel="noreferrer">
                    {source.feed_url}
                  </a>
                </td>
                <td>
                  {source.last_fetched_at
                    ? new Date(source.last_fetched_at).toLocaleString('ja-JP')
                    : '—'}
                  {source.last_error && (
                    <div className="error" style={{ fontSize: 12 }}>
                      {source.last_error}
                    </div>
                  )}
                </td>
                <td>
                  <span className={source.is_enabled ? 'badge' : 'badge grey'}>
                    {source.is_enabled ? '有効' : '無効'}
                  </span>
                </td>
                <td>
                  <div className="row-actions">
                    <form action={setEnabled}>
                      <input type="hidden" name="id" value={source.id} />
                      <input type="hidden" name="enabled" value={String(!source.is_enabled)} />
                      <button type="submit" className={source.is_enabled ? '' : 'primary'}>
                        {source.is_enabled ? '無効にする' : '有効にする'}
                      </button>
                    </form>
                    <form action={removeSource}>
                      <input type="hidden" name="id" value={source.id} />
                      <button className="danger" type="submit">
                        削除
                      </button>
                    </form>
                  </div>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      )}

      <h2>収集の実行</h2>
      <div className="card">
        <p style={{ marginTop: 0 }}>
          収集はアプリからではなくバッチで行います（設計 §24）。
        </p>
        <pre style={{ background: 'var(--bg)', padding: 12, borderRadius: 8, overflowX: 'auto' }}>
          {`cd collectors
npm run collect:news                       # 収集して保存
npm run collect:news -- --dry-run          # 保存せず結果だけ確認
npm run collect:news -- --no-filter --dry-run   # フィードが読めているかの確認`}
        </pre>
      </div>
    </>
  )
}
