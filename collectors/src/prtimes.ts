import { client, log } from './db.js'
import { dedupeKey, shouldCollect } from './keywords.js'

/**
 * PR TIMES のキーワードページから、チョコミント商品を出した実績を集める。
 *
 * 「今どの店にあるか」は取れないが、「**どの店が過去にチョコミントを出したか**」は
 * プレスリリースに残っている。ホテルのアフタヌーンティー、カフェの季節パフェなど、
 * 実店舗のメニューがここで発表されるため、外部 API では取れなかった
 * 「店舗 × チョコミント」に最も近い情報源になる（設計 §外部データ源の調査）。
 *
 * 毎年出している店は翌年も出す可能性が高いので、実績そのものが手掛かりになる。
 *
 * 取り出すのはタイトル・発表日・発表企業・URL だけで、本文は複製しない。
 * robots.txt は Allow: /（2026-08-24 確認）。
 *
 *   npm run collect:prtimes            結果を表示するだけ
 *   npm run collect:prtimes -- --save  候補として登録
 */

/**
 * キーワードページにページ送りは無く、1 語あたり 20 件が上限。
 * 月別アーカイブも企業別の一覧も静的には取れなかった（2026-08-24 確認）。
 * そこで語を増やして網を広げる。同じ発表が複数の語から拾えるので取りこぼしが減る
 * （重複は URL で除く）。
 *
 * 語を足すときは、実際にチョコミント関連が返るか確かめてから入れること。
 * 「チョコミントフェア」「チョコミント味」「ミントアイス」などは
 * ページ自体は存在しても該当 0 件だった。
 */
const KEYWORDS = [
  // 表記ゆれ
  'チョコミント',
  'ミントチョコ',
  'チョコミン党',
  'ミントチョコレート',
  'チョコレートミント',
  // 商品の形態
  'チョコミントアイス',
  'チョコミントパフェ',
  'チョコミントドリンク',
  'チョコミントケーキ',
  'チョコミントフラペチーノ',
  'チョコミントスイーツ',
  'チョコミントシェイク',
  // 周辺語（チョコミント以外も混ざるが shouldCollect で落とす）
  'ミント',
  'ペパーミント',
  'ミントスイーツ',
  'ミントグリーン',
]

type Release = {
  title: string
  url: string
  company: string | null
  companyId: string | null
  publishedAt: Date | null
}

function sleep(ms: number): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, ms))
}

function decode(text: string): string {
  return text
    .replace(/&amp;/g, '&')
    .replace(/&lt;/g, '<')
    .replace(/&gt;/g, '>')
    .replace(/&quot;/g, '"')
    .replace(/&#0?39;/g, "'")
    .replace(/&nbsp;/g, ' ')
}

function parse(html: string): Release[] {
  const articles = html.match(/<article[^>]*class="item[^"]*"[\s\S]*?<\/article>/g) ?? []
  const releases: Release[] = []

  for (const article of articles) {
    const href = article.match(/href="(\/main\/html\/rd\/p\/[^"]+)"/)?.[1]
    // タイトルは title 属性が最も欠けにくい
    const rawTitle =
      article.match(/title="([^"]{8,})"/)?.[1] ??
      article.match(/class="[^"]*title-item[^"]*"[^>]*>([^<]{8,})</)?.[1]
    if (!href || !rawTitle) continue

    const datetime = article.match(/<time[^>]*datetime="([^"]+)"/)?.[1]
    const company = article.match(/class="[^"]*company[^"]*"[^>]*>\s*([^<]{2,60})</)?.[1]
    const companyId = article.match(/\/searchrlp\/company_id\/(\d+)/)?.[1]
    const published = datetime ? new Date(datetime) : null

    releases.push({
      title: decode(rawTitle).replace(/\s+/g, ' ').trim(),
      url: `https://prtimes.jp${href}`,
      company: company ? decode(company).trim() : null,
      companyId: companyId ?? null,
      publishedAt: published && !Number.isNaN(published.getTime()) ? published : null,
    })
  }
  return releases
}

async function fetchKeyword(keyword: string): Promise<Release[]> {
  const url = `https://prtimes.jp/topics/keywords/${encodeURIComponent(keyword)}`
  const response = await fetch(url, {
    headers: { 'user-agent': 'chocomint-collector/1.0' },
    signal: AbortSignal.timeout(25_000),
  })
  if (!response.ok) throw new Error(`HTTP ${response.status}`)
  return parse(await response.text())
}

async function main() {
  const save = process.argv.includes('--save')

  const collected = new Map<string, Release>()
  for (const keyword of KEYWORDS) {
    try {
      const releases = await fetchKeyword(keyword)
      const matched = releases.filter((r) => shouldCollect(r.title))
      log(`「${keyword}」: ${releases.length}件中 ${matched.length}件がチョコミント関連`)
      for (const release of matched) collected.set(release.url, release)
    } catch (cause) {
      log(`「${keyword}」の取得に失敗: ${cause instanceof Error ? cause.message : String(cause)}`)
    }
    await sleep(1500)
  }

  const releases = [...collected.values()].sort(
    (a, b) => (b.publishedAt?.getTime() ?? 0) - (a.publishedAt?.getTime() ?? 0),
  )

  log(`重複を除いて ${releases.length}件`)
  for (const release of releases) {
    const date = release.publishedAt?.toISOString().slice(0, 10) ?? '日付不明'
    log(`  ${date}  ${release.company ?? '企業不明'}`)
    log(`      ${release.title.slice(0, 70)}`)
  }

  if (!save) {
    log('')
    log('--save を付けると候補として登録します（公開はされません）。')
    return
  }

  const supabase = client()

  // 既に取り込んだものと突き合わせる
  const { data: existing } = await supabase
    .from('product_submissions')
    .select('name')
    .eq('source', 'admin')
  const seen = new Set((existing ?? []).map((row) => dedupeKey(row.name)))

  let saved = 0
  for (const release of releases) {
    if (seen.has(dedupeKey(release.title))) continue
    seen.add(dedupeKey(release.title))

    const { data, error } = await supabase
      .from('product_submissions')
      .upsert(
        {
          source: 'admin',
          external_id: `prtimes:${release.url}`,
          external_url: release.url,
          name: release.title.slice(0, 200),
          manufacturer: release.company,
          purchase_place: release.company,
          release_date: release.publishedAt?.toISOString().slice(0, 10) ?? null,
          note: 'PR TIMES で発表を検出。店舗・商品名・提供期間は発表内容を確認して登録すること。',
          status: 'pending',
        },
        { onConflict: 'source,external_id', ignoreDuplicates: true },
      )
      .select('id')

    if (error) {
      log(`  保存に失敗: ${release.title.slice(0, 40)} — ${error.message}`)
    } else if (data && data.length > 0) {
      saved += 1
    }
  }
  log(`新規 ${saved}件を候補として登録しました。管理画面で確認してください。`)
}

main().catch((error) => {
  console.error(error)
  process.exit(1)
})
