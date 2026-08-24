import { BRANDS, type Brand } from './brands.js'
import { client, log } from './db.js'
import { isChocomint } from './keywords.js'

/**
 * ブランド公式サイトを巡回し、チョコミントへの言及を検出する。
 *
 * グルメサイトの転載ができない以上、「どのチェーンがチョコミントを出しているか」は
 * そのチェーン自身の告知から取るのが唯一の正攻法（設計 §外部データ源の調査）。
 *
 * 保存するのは「検出した」という事実と、その場の抜粋・出典 URL だけ。
 * ページ本文の複製はしない。商品として公開するかは運営が確認して決める。
 *
 *   npm run watch:brands                  検出結果を表示
 *   npm run watch:brands -- --save        候補として product_submissions に登録
 *   npm run watch:brands -- --brand 明治  1 ブランドだけ試す
 */

/** 1 ブランドあたりに取得するページ数の上限。相手のサーバーに負担をかけない。 */
const MAX_PAGES_PER_BRAND = 12
/** 取得間隔 */
const DELAY_MS = 1200

/** 商品・新商品らしい URL を選ぶための手掛かり */
const PATH_HINTS = [
  'product', 'goods', 'item', 'menu', 'news', 'release', 'information',
  'topics', 'lineup', 'brand', 'sweets', 'ice', 'dessert', 'flavor', 'whatsnew',
]

function sleep(ms: number): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, ms))
}

async function fetchText(url: string): Promise<string | null> {
  try {
    const response = await fetch(url, {
      headers: { 'user-agent': 'chocomint-brandwatch/1.0' },
      signal: AbortSignal.timeout(20_000),
    })
    if (!response.ok) return null
    const type = response.headers.get('content-type') ?? ''
    if (!/text|xml|html/i.test(type)) return null
    return await response.text()
  } catch {
    return null
  }
}

/** robots.txt がサイト全体を拒否している場合は巡回しない。 */
async function isCrawlAllowed(domain: string): Promise<boolean> {
  const robots = await fetchText(`https://${domain}/robots.txt`)
  if (robots === null) return true // robots.txt が無いのは許可と解釈する

  // User-agent: * のブロックだけを見る
  const blocks = robots.split(/^user-agent:/im).slice(1)
  for (const block of blocks) {
    const [agent, ...rest] = block.split('\n')
    if (agent.trim() !== '*') continue
    for (const line of rest) {
      if (/^\s*user-agent:/i.test(line)) break
      if (/^\s*disallow:\s*\/\s*$/i.test(line)) return false
    }
  }
  return true
}

/** sitemap.xml から、商品・新商品らしいページを拾う。 */
async function discoverFromSitemap(domain: string): Promise<string[]> {
  const found: string[] = []
  const roots = [`https://${domain}/sitemap.xml`, `https://${domain}/sitemap_index.xml`]

  for (const root of roots) {
    const xml = await fetchText(root)
    if (!xml) continue

    const locs = [...xml.matchAll(/<loc>([^<]+)<\/loc>/g)].map((m) => m[1].trim())

    // sitemap インデックスなら 1 段だけ辿る
    const children = locs.filter((u) => /sitemap.*\.xml/i.test(u)).slice(0, 3)
    for (const child of children) {
      const childXml = await fetchText(child)
      if (childXml) {
        locs.push(...[...childXml.matchAll(/<loc>([^<]+)<\/loc>/g)].map((m) => m[1].trim()))
      }
      await sleep(DELAY_MS)
    }

    for (const url of locs) {
      if (/\.(xml|jpg|jpeg|png|gif|pdf|css|js)(\?|$)/i.test(url)) continue
      const lower = url.toLowerCase()
      if (PATH_HINTS.some((hint) => lower.includes(hint))) found.push(url)
    }
    if (found.length > 0) break
  }
  return [...new Set(found)]
}

/** トップページのリンクから、商品・新商品らしいページを拾う。 */
function discoverFromLinks(html: string, domain: string): string[] {
  const found: string[] = []
  for (const m of html.matchAll(/href="([^"#]+)"/g)) {
    const href = m[1]
    if (/^(mailto:|tel:|javascript:)/i.test(href)) continue
    let url: string
    try {
      url = new URL(href, `https://${domain}/`).toString()
    } catch {
      continue
    }
    if (!url.startsWith(`https://${domain}`)) continue
    if (/\.(jpg|jpeg|png|gif|pdf|css|js)(\?|$)/i.test(url)) continue
    const lower = url.toLowerCase()
    if (PATH_HINTS.some((hint) => lower.includes(hint))) found.push(url)
  }
  return [...new Set(found)]
}

/** 商品名になりうる長さの抜粋を取り出す。前後の文脈で運営が判断できる程度に留める。 */
function extractSnippets(html: string): string[] {
  const text = html
    .replace(/<script[\s\S]*?<\/script>/gi, ' ')
    .replace(/<style[\s\S]*?<\/style>/gi, ' ')
    .replace(/<[^>]+>/g, '|')
    .replace(/&nbsp;/g, ' ')
    .replace(/&amp;/g, '&')
    .replace(/\|+/g, '|')

  const found = new Set<string>()
  for (const chunk of text.split('|')) {
    const trimmed = chunk.replace(/\s+/g, ' ').trim()
    // 商品名の想定される長さに収まるものだけ。長い本文は拾わない。
    if (trimmed.length > 0 && trimmed.length <= 60 && isChocomint(trimmed)) {
      found.add(trimmed)
    }
  }
  return [...found]
}

type Hit = { brand: Brand; url: string; snippets: string[] }

async function crawlBrand(brand: Brand): Promise<{ hits: Hit[]; pages: number }> {
  const hits: Hit[] = []

  if (!(await isCrawlAllowed(brand.domain))) {
    log(`  ${brand.name}: robots.txt が全体を拒否しているため巡回しない`)
    return { hits, pages: 0 }
  }

  const targets: string[] = []
  const top = `https://${brand.domain}/`

  // 分かっている URL を最優先
  for (const path of brand.paths ?? []) targets.push(`https://${brand.domain}${path}`)
  targets.push(top)

  const topHtml = await fetchText(top)
  await sleep(DELAY_MS)
  if (topHtml) targets.push(...discoverFromLinks(topHtml, brand.domain))
  if (targets.length < MAX_PAGES_PER_BRAND) {
    targets.push(...(await discoverFromSitemap(brand.domain)))
  }

  const unique = [...new Set(targets)].slice(0, MAX_PAGES_PER_BRAND)
  let pages = 0
  for (const url of unique) {
    const html = url === top ? topHtml : await fetchText(url)
    if (url !== top) await sleep(DELAY_MS)
    if (!html) continue
    pages += 1
    const snippets = extractSnippets(html)
    if (snippets.length > 0) hits.push({ brand, url, snippets })
  }
  return { hits, pages }
}

async function main() {
  const save = process.argv.includes('--save')
  const only = process.argv[process.argv.indexOf('--brand') + 1]
  // 追加したぶんだけ回したいときに使う（例: --from 85 で 86 番目以降）
  const fromIndex = process.argv.includes('--from')
    ? Number(process.argv[process.argv.indexOf('--from') + 1]) || 0
    : 0
  const brands =
    process.argv.includes('--brand') && only
      ? BRANDS.filter((b) => b.name.includes(only))
      : BRANDS.slice(fromIndex)

  log(`${brands.length}ブランドを巡回します`)
  const allHits: Hit[] = []
  let totalPages = 0

  for (const [index, brand] of brands.entries()) {
    const { hits, pages } = await crawlBrand(brand)
    totalPages += pages
    if (hits.length > 0) {
      log(`  ★ ${brand.name}（${pages}ページ中 ${hits.length}ページで検出）`)
      for (const hit of hits) {
        for (const snippet of hit.snippets.slice(0, 4)) log(`      ${snippet}`)
        log(`      ${hit.url}`)
      }
      allHits.push(...hits)
    } else if (pages === 0) {
      log(`  － ${brand.name}: ページを取得できず`)
    }
    if ((index + 1) % 20 === 0) log(`  …${index + 1}/${brands.length} ブランド完了`)
  }

  log('')
  log(`${totalPages}ページを確認、${allHits.length}ページでチョコミントを検出`)

  if (!save) {
    log('--save を付けると候補として登録します（公開はされません）。')
    return
  }

  const supabase = client()
  let saved = 0
  for (const hit of allHits) {
    for (const snippet of hit.snippets) {
      const { data, error } = await supabase
        .from('product_submissions')
        .upsert(
          {
            source: 'admin',
            // 同じページの同じ表記を何度も積まない
            external_id: `brand:${hit.brand.name}:${snippet}`,
            external_url: hit.url,
            name: snippet,
            manufacturer: hit.brand.name,
            purchase_place: hit.brand.name,
            note: `公式サイトで検出（${hit.url}）`,
            status: 'pending',
          },
          { onConflict: 'source,external_id', ignoreDuplicates: true },
        )
        .select('id')
      if (error) {
        log(`  保存に失敗: ${snippet} — ${error.message}`)
      } else if (data && data.length > 0) {
        saved += 1
      }
    }
  }
  log(`新規 ${saved}件を候補として登録しました。管理画面で確認してください。`)
}

main().catch((error) => {
  console.error(error)
  process.exit(1)
})
