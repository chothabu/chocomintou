import { client, log } from './db.js'
import { dedupeKey, guessCategory, shouldCollect } from './keywords.js'

/**
 * 楽天市場の商品検索から、チョコミント商品の「候補」を集める（設計 §26）。
 *
 * 集めた結果をそのまま公開はしない。product_submissions に候補として積み、
 * 運営が管理画面で確認・承認したものだけが products になる。
 *
 *   楽天市場 → 候補 → 重複・ノイズ除去 → 運営確認 → Product DB
 */

// 認証はアプリ ID とアクセスキーの 2 つが要る。
// 旧ホスト（app.rakuten.co.jp/services/api/...）はアクセスキーを受け付けない。
const ENDPOINT = 'https://openapi.rakuten.co.jp/ichibams/api/IchibaItem/Search/20260701'
const KEYWORDS = ['チョコミント', 'ミントチョコ']
const HITS_PER_PAGE = 30
const MAX_PAGES = 3

type RakutenItem = {
  itemCode: string
  itemName: string
  itemPrice: number
  itemUrl: string
  affiliateUrl?: string
  shopName: string
  mediumImageUrls?: (string | { imageUrl: string })[]
}

type Credentials = {
  applicationId: string
  accessKey: string
  affiliateId?: string
}

async function search(
  credentials: Credentials,
  keyword: string,
  page: number,
): Promise<RakutenItem[]> {
  const url = new URL(ENDPOINT)
  url.searchParams.set('applicationId', credentials.applicationId)
  url.searchParams.set('keyword', keyword)
  url.searchParams.set('hits', String(HITS_PER_PAGE))
  url.searchParams.set('page', String(page))
  // 食品ジャンルに寄せる（雑貨・日用品のノイズを減らす）
  url.searchParams.set('genreId', '100227')
  url.searchParams.set('formatVersion', '2')
  if (credentials.affiliateId) {
    url.searchParams.set('affiliateId', credentials.affiliateId)
  }

  // アクセスキーは資格情報なので、URL ではなくヘッダーで送る
  // （URL はログやリファラに残りうるため）。
  const response = await fetch(url, {
    headers: { accessKey: credentials.accessKey },
    signal: AbortSignal.timeout(20_000),
  })

  if (response.status === 401 || response.status === 403) {
    throw new Error(
      `楽天 API に拒否されました（${response.status}）。` +
        'アクセスキーが正しいか、送信元 IP がアプリの Allowed IP addresses に登録されているか確認してください。' +
        `現在の送信元 IP は \`curl -s https://api.ipify.org\` で確認できます。`,
    )
  }
  if (!response.ok) {
    throw new Error(`楽天 API が ${response.status} を返しました: ${await response.text()}`)
  }

  const json = (await response.json()) as { Items?: RakutenItem[] }
  return json.Items ?? []
}

/** 画像 URL は形式が版によって変わるため、どちらでも読めるようにする。 */
function imageUrl(item: RakutenItem): string | null {
  const first = item.mediumImageUrls?.[0]
  if (!first) return null
  return typeof first === 'string' ? first : first.imageUrl
}

async function main() {
  const applicationId = process.env.RAKUTEN_APP_ID
  const accessKey = process.env.RAKUTEN_ACCESS_KEY
  if (!applicationId || !accessKey) {
    log('RAKUTEN_APP_ID / RAKUTEN_ACCESS_KEY が未設定のため、商品候補の収集をスキップします。')
    log('https://webservice.rakuten.co.jp/ で無料登録すると発行できます。')
    return
  }
  const credentials: Credentials = {
    applicationId,
    accessKey,
    affiliateId: process.env.RAKUTEN_AFFILIATE_ID || undefined,
  }

  const supabase = client()
  const seen = new Set<string>()
  const seenNames = new Set<string>()
  let collected = 0
  let skipped = 0
  let duplicated = 0

  // 前回までに取り込んだ商品名も突き合わせる。
  // そうしないと、実行のたびに同じ商品が別の出品として積み上がる。
  const { data: existing } = await supabase
    .from('product_submissions')
    .select('name')
    .eq('source', 'rakuten')
  for (const row of existing ?? []) seenNames.add(dedupeKey(row.name))

  for (const keyword of KEYWORDS) {
    for (let page = 1; page <= MAX_PAGES; page += 1) {
      const items = await search(credentials, keyword, page)
      if (items.length === 0) break

      for (const item of items) {
        // 同一実行内の重複（キーワード違いで同じ商品が出る）
        if (seen.has(item.itemCode)) continue
        seen.add(item.itemCode)

        if (!shouldCollect(item.itemName)) {
          skipped += 1
          continue
        }

        // 同じ商品の別出品・容量違いをまとめる
        const key = dedupeKey(item.itemName)
        if (seenNames.has(key)) {
          duplicated += 1
          continue
        }
        seenNames.add(key)

        const { error } = await supabase.from('product_submissions').upsert(
          {
            source: 'rakuten',
            external_id: item.itemCode,
            // アフィリエイト ID を設定していれば、そちらの URL が返る
            external_url: item.affiliateUrl || item.itemUrl,
            image_url: imageUrl(item),
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

  log(
    `完了。候補 ${collected}件を登録、` +
      `${skipped}件をノイズとして除外、${duplicated}件を既出として除外しました。`,
  )
  log('管理画面の「商品候補」から内容を確認して承認してください。')
}

main().catch((error) => {
  console.error(error)
  process.exit(1)
})
