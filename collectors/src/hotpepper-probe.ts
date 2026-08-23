import { log } from './db.js'

/**
 * ホットペッパー グルメ API に、チョコミントを出す飲食店がどれだけ載っているかを測る。
 *
 * 実装する前に「使い物になるか」を確かめるための調査用スクリプト。
 * 結果は保存せず、件数と例を表示するだけ。
 *
 *   RECRUIT_API_KEY=xxxx npm run probe:hotpepper
 *
 * 注意: keyword は店名・住所・駅名・ジャンル・店舗のフリーワードを対象にした部分一致で、
 * メニュー 1 品ごとの検索ではない。「チョコミントを出す店」が確実に引けるわけではないので、
 * 実際のヒット数を見てから採否を決める。
 */

const ENDPOINT = 'https://webservice.recruit.co.jp/hotpepper/gourmet/v1/'

type Shop = {
  name: string
  address: string
  lat: number
  lng: number
  genre?: { name: string }
  catch?: string
  shop_detail_memo?: string
  urls?: { pc: string }
}

async function search(key: string, params: Record<string, string>): Promise<{
  available: number
  shops: Shop[]
}> {
  const url = new URL(ENDPOINT)
  url.searchParams.set('key', key)
  url.searchParams.set('format', 'json')
  url.searchParams.set('count', '20')
  for (const [k, v] of Object.entries(params)) url.searchParams.set(k, v)

  const response = await fetch(url, { signal: AbortSignal.timeout(20_000) })
  if (!response.ok) {
    throw new Error(`HTTP ${response.status}: ${(await response.text()).slice(0, 200)}`)
  }
  const json = (await response.json()) as {
    results?: { results_available?: number; shop?: Shop[]; error?: { message: string }[] }
  }
  if (json.results?.error) {
    throw new Error(json.results.error.map((e) => e.message).join(' / '))
  }
  return {
    available: json.results?.results_available ?? 0,
    shops: json.results?.shop ?? [],
  }
}

async function main() {
  const key = process.env.RECRUIT_API_KEY
  if (!key) {
    log('RECRUIT_API_KEY が未設定です。')
    log('https://webservice.recruit.co.jp/register/ で無料登録するとキーを発行できます。')
    process.exit(1)
  }

  // 全国 → 東京 → 渋谷周辺 と絞りながら、どの粒度で使えるかを見る
  const queries: [string, Record<string, string>][] = [
    ['全国 / チョコミント', { keyword: 'チョコミント' }],
    ['全国 / ミントチョコ', { keyword: 'ミントチョコ' }],
    ['東京 / チョコミント', { keyword: 'チョコミント', large_area: 'Z011' }],
    // 渋谷駅から半径 3km
    ['渋谷3km / チョコミント', { keyword: 'チョコミント', lat: '35.6595', lng: '139.7005', range: '5' }],
    ['渋谷3km / パフェ（比較用）', { keyword: 'パフェ', lat: '35.6595', lng: '139.7005', range: '5' }],
  ]

  for (const [label, params] of queries) {
    try {
      const { available, shops } = await search(key, params)
      log(`${label}: ${available}件`)
      for (const shop of shops.slice(0, 3)) {
        const note = [shop.catch, shop.shop_detail_memo]
          .filter(Boolean)
          .join(' ')
          .replace(/\s+/g, ' ')
        const hit = /チョコミント|ミントチョコ/.test(note) ? '★本文に一致' : ''
        log(`    ${shop.name}（${shop.genre?.name ?? '-'}）${hit}`)
        if (note) log(`      ${note.slice(0, 90)}`)
      }
    } catch (cause) {
      log(`${label}: 失敗 — ${cause instanceof Error ? cause.message : String(cause)}`)
    }
    await new Promise((resolve) => setTimeout(resolve, 1200))
  }

  log('')
  log('件数が十分なら実装に進む。少なければ、メニュー単位の検索ではないため見送る。')
}

main().catch((error) => {
  console.error(error)
  process.exit(1)
})
