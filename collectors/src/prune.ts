import { client, log } from './db.js'
import { dedupeKey, shouldCollect } from './keywords.js'

/**
 * 収集済みの未処理候補に、現在のフィルタを適用し直す（出所を問わない）。
 *
 * ノイズ判定を強化したときに使う。すでに承認・却下したものは触らない。
 * 判断を書き換えるのではなく、運営が確認する前の山を掃除するのが目的。
 *
 *   npm run prune            消す対象を表示するだけ
 *   npm run prune -- --apply 実際に消す
 */
async function main() {
  const apply = process.argv.includes('--apply')
  const supabase = client()

  const { data, error } = await supabase
    .from('product_submissions')
    .select('id, name, manufacturer')
    .eq('status', 'pending')
  if (error) throw new Error(error.message)

  const rows = (data ?? []) as { id: string; name: string; manufacturer: string | null }[]
  const noise: { id: string; name: string }[] = []
  const duplicated: { id: string; name: string }[] = []
  const seen = new Set<string>()

  for (const row of rows) {
    if (!shouldCollect(row.name)) {
      noise.push(row)
      continue
    }
    // メーカーごとに突き合わせる。ブランドが違えば同じ商品名でも別物
    // （サーティワンの「チョコミント」と赤城乳業の「チョコミント」は別商品）。
    const key = `${row.manufacturer ?? ''}|${dedupeKey(row.name)}`
    if (seen.has(key)) {
      duplicated.push(row)
      continue
    }
    seen.add(key)
  }

  for (const row of noise) log(`  [ノイズ] ${row.name.slice(0, 60)}`)
  for (const row of duplicated) log(`  [重複]   ${row.name.slice(0, 60)}`)

  const targets = [...noise, ...duplicated].map((row) => row.id)
  log(`${rows.length}件中 ${noise.length}件がノイズ、${duplicated.length}件が重複。`)

  if (!apply) {
    log('--apply を付けると実際に削除します。')
    return
  }
  if (targets.length === 0) return

  // in() は URL 長の制限に当たるので分割して消す
  for (let i = 0; i < targets.length; i += 100) {
    const chunk = targets.slice(i, i + 100)
    const { error: deleteError } = await supabase
      .from('product_submissions')
      .delete()
      .in('id', chunk)
    if (deleteError) throw new Error(deleteError.message)
  }
  log(`${targets.length}件を削除しました。`)
}

main().catch((error) => {
  console.error(error)
  process.exit(1)
})
