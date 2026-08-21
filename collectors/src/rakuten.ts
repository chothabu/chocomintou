import { client, log } from './db.js'
import { guessCategory, shouldCollect } from './keywords.js'

/**
 * 楽天市場の商品検索から、チョコミント商品の「候補」を集める（設計 §26）。
 *
 * 集めた結果をそのまま公開はしない。product_submissions に候補として積み、
 * 運営が管理画面で確認・承認したものだけが products になる。
 *
 *   楽天市場 → 候補 → 重複・ノイズ除去 → 運営確認 → Product DB
 */

const ENDPOINT = 'https://app.rakuten.co.jp/services/api/IchibaItem/Search/20220601'
const KEYWORDS = ['チョコミント', 'ミントチョコ']
const HITS_PER_PAGE = 30
const MAX_PAGES = 3

type RakutenItem = {
  itemCode: string
  itemName: string
  itemPrice: number
  itemUrl: string
  shopName: string
  mediumImageUrls?: { imageUrl: string }[]
}

async function search(applicationId: string, keyword: string, page: number): Promise<RakutenItem[]> {
  const url = new URL(ENDPOINT)
  url.searchParams.set('applicationId', applicationId)
  url.searchParams.set('keyword', keyword)
  url.searchParams.set('hits', String(HITS_PER_PAGE))
  url.searchParams.set('page', String(page))
  // 食品ジャンルに寄せる（雑貨・日用品のノイズを減らす）
  url.searchParams.set('genreId', '100227')
  url.searchParams.set('formatVersion', '2')

  const response = await fetch(url, { signal: AbortSignal.timeout(20_000) })
  if (!response.ok) {
    throw new Error(`楽天 API が ${response.status} を返しました: ${await response.text()}`)
  }
  const json = (await response.json()) as { Items?: RakutenItem[] }
  return json.Items ?? []
}

async function main() {
  const applicationId = process.env.RAKUTEN_APP_ID
  if (!applicationId) {
    log('RAKUTEN_APP_ID が未設定のため、商品候補の収集をスキップします。')
    log('https://webservice.rakuten.co.jp/ で無料登録するとアプリ ID を発行できます。')
    return
  }

  const supabase = client()
  const seen = new Set<string>()
  let collected = 0
  let skipped = 0

  for (const keyword of KEYWORDS) {
    for (let page = 1; page <= MAX_PAGES; page += 1) {
      const items = await search(applicationId, keyword, page)
      if (items.length === 0) break

      for (const item of items) {
        // 同一実行内の重複（キーワード違いで同じ商品が出る）
        if (seen.has(item.itemCode)) continue
        seen.add(item.itemCode)

        if (!shouldCollect(item.itemName)) {
          skipped += 1
          continue
        }

        const { error } = await supabase.from('product_submissions').upsert(
          {
            source: 'rakuten',
            external_id: item.itemCode,
            external_url: item.itemUrl,
            image_url: item.mediumImageUrls?.[0]?.imageUrl ?? null,
            name: item.itemName.slice(0, 200),
            manufacturer: null,
            category: guessCategory(item.itemName),
            price: Number.isFinite(item.itemPrice) ? item.itemPrice : null,
            purchase_place: item.shopName,
            note: '楽天市場の検索結果から自動収集',
            status: 'pending',
          },
          // 一度却下した候補を再び pending に戻さないため、既存行は触らない。
          { onConflict: 'source,external_id', ignoreDuplicates: true },
        )
        if (error) {
          log(`  保存に失敗: ${item.itemName.slice(0, 40)} — ${error.message}`)
        } else {
          collected += 1
        }
      }

      // 連続アクセスを避ける
      await new Promise((resolve) => setTimeout(resolve, 1000))
    }
  }

  log(`完了。候補 ${collected}件を登録、${skipped}件をノイズとして除外しました。`)
  log('管理画面の「ユーザー申請」から内容を確認して承認してください。')
}

main().catch((error) => {
  console.error(error)
  process.exit(1)
})
