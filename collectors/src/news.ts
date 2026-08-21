import { client, log } from './db.js'
import { parseFeed } from './feed.js'
import { shouldCollect } from './keywords.js'

/**
 * ニュース記事の収集。
 *
 * 巡回先は news_sources テーブルから読む。どのフィードを使うかは、その利用条件を
 * 確認したうえで運営が管理画面で決める（設計 §24）。ここにフィード URL は書かない。
 *
 * 保存するのはタイトル・リンク・媒体名・日時だけで、本文は保存しない。
 * アプリはカードを表示し、タップしたら元記事をブラウザで開く。
 */
/**
 * 実行オプション。収集元を追加したときの動作確認に使う。
 *
 *   --dry-run    保存せず、拾えた記事を表示するだけ
 *   --no-filter  キーワードで絞らない（フィード自体が読めているかの確認用）
 *   --limit N    収集元 1 件あたりの保存上限
 */
type Options = { dryRun: boolean; noFilter: boolean; limit: number }

function parseOptions(argv: string[]): Options {
  const limitIndex = argv.indexOf('--limit')
  return {
    dryRun: argv.includes('--dry-run'),
    noFilter: argv.includes('--no-filter'),
    limit: limitIndex >= 0 ? Number(argv[limitIndex + 1]) || Infinity : Infinity,
  }
}

async function main() {
  const options = parseOptions(process.argv.slice(2))
  const supabase = client()

  const { data: sources, error } = await supabase
    .from('news_sources')
    .select('id, name, feed_url')
    .eq('is_enabled', true)

  if (error) throw new Error(`収集元を読み込めません: ${error.message}`)
  if (!sources || sources.length === 0) {
    log('有効な収集元がありません。管理画面の「ニュース > 収集元」で追加してください。')
    return
  }

  let inserted = 0
  let duplicated = 0
  for (const source of sources) {
    try {
      const response = await fetch(source.feed_url, {
        headers: { 'user-agent': 'chocomint-collector/1.0' },
        signal: AbortSignal.timeout(20_000),
      })
      if (!response.ok) throw new Error(`HTTP ${response.status}`)

      const items = parseFeed(await response.text())
      const filtered = options.noFilter ? items : items.filter((item) => shouldCollect(item.title))
      const matched = filtered.slice(0, options.limit)
      log(`${source.name}: ${items.length}件中 ${filtered.length}件がチョコミント関連`)

      if (options.dryRun) {
        for (const item of matched) log(`  [dry-run] ${item.title}`)
        continue
      }

      for (const item of matched) {
        // article_url が UNIQUE。同じ記事を再取得しても増えない。
        // 実際に増えた件数を数えたいので select() で戻り行を見る
        // （ignoreDuplicates では重複時に行が返らない）。
        const { data: saved, error: upsertError } = await supabase
          .from('news_articles')
          .upsert(
            {
              title: item.title,
              source_name: source.name,
              article_url: item.link,
              thumbnail_url: item.thumbnailUrl,
              published_at: item.publishedAt.toISOString(),
              source_id: source.id,
            },
            { onConflict: 'article_url', ignoreDuplicates: true },
          )
          .select('id')

        if (upsertError) {
          log(`  保存に失敗: ${item.title} — ${upsertError.message}`)
        } else if (saved && saved.length > 0) {
          inserted += 1
        } else {
          duplicated += 1
        }
      }

      await supabase
        .from('news_sources')
        .update({ last_fetched_at: new Date().toISOString(), last_error: null })
        .eq('id', source.id)
    } catch (cause) {
      const message = cause instanceof Error ? cause.message : String(cause)
      log(`${source.name}: 取得に失敗 — ${message}`)
      // 失敗しても他の収集元は続ける。原因は管理画面から見えるようにしておく。
      await supabase
        .from('news_sources')
        .update({ last_fetched_at: new Date().toISOString(), last_error: message })
        .eq('id', source.id)
    }
  }

  log(`完了。新規 ${inserted}件を保存、既出 ${duplicated}件をスキップしました。`)
}

main().catch((error) => {
  console.error(error)
  process.exit(1)
})
