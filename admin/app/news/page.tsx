import { revalidatePath } from 'next/cache'
import { supabaseAdmin, type NewsArticle } from '@/lib/supabase'

export const dynamic = 'force-dynamic'

async function setHidden(formData: FormData) {
  'use server'
  const id = String(formData.get('id'))
  const hidden = formData.get('hidden') === 'true'
  const supabase = supabaseAdmin()
  await supabase.from('news_articles').update({ is_hidden: hidden }).eq('id', id)
  revalidatePath('/news')
}

async function remove(formData: FormData) {
  'use server'
  const id = String(formData.get('id'))
  const supabase = supabaseAdmin()
  await supabase.from('news_articles').delete().eq('id', id)
  revalidatePath('/news')
}

/**
 * 同じ記事が複数の媒体から重複して入ることがあるため、タイトルが完全一致するものを
 * 1 件だけ残して消す。URL は違っても内容が同じケースを想定している。
 */
async function removeDuplicates() {
  'use server'
  const supabase = supabaseAdmin()
  const { data } = await supabase
    .from('news_articles')
    .select('id, title, published_at')
    .order('published_at', { ascending: false })
    .limit(1000)

  const seen = new Set<string>()
  const duplicates: string[] = []
  for (const row of data ?? []) {
    const key = row.title.trim()
    if (seen.has(key)) duplicates.push(row.id)
    else seen.add(key)
  }
  if (duplicates.length > 0) {
    await supabase.from('news_articles').delete().in('id', duplicates)
  }
  revalidatePath('/news')
}

export default async function NewsPage() {
  const supabase = supabaseAdmin()
  const { data } = await supabase
    .from('news_articles')
    .select('id, title, source_name, article_url, published_at, is_hidden')
    .order('published_at', { ascending: false })
    .limit(200)

  const articles = (data ?? []) as NewsArticle[]

  return (
    <>
      <h1>ニュース</h1>
      <p className="lead">
        記事の収集はバックエンドのバッチが行います。ここでは不要な記事を消すだけです。
      </p>

      <div className="card">
        <form action={removeDuplicates}>
          <button type="submit">タイトルが重複した記事を削除</button>
        </form>
      </div>

      {articles.length === 0 ? (
        <div className="card empty">記事がありません。収集バッチが動いているか確認してください。</div>
      ) : (
        <table>
          <thead>
            <tr>
              <th>タイトル</th>
              <th>media</th>
              <th>公開日</th>
              <th>状態</th>
              <th />
            </tr>
          </thead>
          <tbody>
            {articles.map((article) => (
              <tr key={article.id}>
                <td>
                  <a href={article.article_url} target="_blank" rel="noreferrer">
                    {article.title}
                  </a>
                </td>
                <td>{article.source_name ?? '—'}</td>
                <td>{new Date(article.published_at).toLocaleDateString('ja-JP')}</td>
                <td>
                  <span className={article.is_hidden ? 'badge grey' : 'badge'}>
                    {article.is_hidden ? '非表示' : '公開中'}
                  </span>
                </td>
                <td>
                  <div className="row-actions">
                    <form action={setHidden}>
                      <input type="hidden" name="id" value={article.id} />
                      <input type="hidden" name="hidden" value={String(!article.is_hidden)} />
                      <button type="submit">{article.is_hidden ? '公開に戻す' : '非表示にする'}</button>
                    </form>
                    <form action={remove}>
                      <input type="hidden" name="id" value={article.id} />
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
    </>
  )
}
