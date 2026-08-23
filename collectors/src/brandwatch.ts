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
 *   npm run watch:brands            検出結果を表示
 *   npm run watch:brands -- --save  候補として product_submissions に登録
 */

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

async function fetchPage(url: string): Promise<string | null> {
  try {
    const response = await fetch(url, {
      headers: { 'user-agent': 'chocomint-brandwatch/1.0' },
      signal: AbortSignal.timeout(25_000),
    })
    if (!response.ok) return null
    return await response.text()
  } catch {
    return null
  }
}

type Hit = { brand: Brand; url: string; snippets: string[] }

async function main() {
  const save = process.argv.includes('--save')
  const hits: Hit[] = []
  let checked = 0
  let unreachable = 0

  for (const brand of BRANDS) {
    for (const url of brand.urls) {
      const html = await fetchPage(url)
      checked += 1
      if (html === null) {
        unreachable += 1
        log(`  取得できず: ${brand.name} ${url}`)
        continue
      }
      const snippets = extractSnippets(html)
      if (snippets.length > 0) hits.push({ brand, url, snippets })
      // 相手のサーバーに負荷をかけない
      await new Promise((resolve) => setTimeout(resolve, 1500))
    }
  }

  log(`${checked}ページを確認（うち ${unreachable} ページは取得できず）`)
  log(`チョコミントへの言及: ${hits.length}ページ`)
  for (const hit of hits) {
    log(`  ★ ${hit.brand.name}`)
    for (const snippet of hit.snippets.slice(0, 5)) log(`      ${snippet}`)
    log(`      ${hit.url}`)
  }

  if (!save) {
    log('')
    log('--save を付けると候補として登録します（公開はされません）。')
    return
  }

  const supabase = client()
  let saved = 0
  for (const hit of hits) {
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
