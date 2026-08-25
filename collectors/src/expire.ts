import { client, log } from './db.js'

/**
 * 販売終了日を過ぎた商品を「販売終了」にする。
 *
 * 期間限定の商品は end_date を持つが、日付が過ぎても状態が変わらないと
 * 「今買える」として表示され続ける。目撃情報を 30 日で隠すのと同じで、
 * 事実でなくなった情報は出さない。
 *
 * 行の更新契機が無くても時間の経過だけで状態が変わるため、
 * トリガーではなく毎日のバッチで処理する。
 *
 *   npm run expire
 */
async function main() {
  const supabase = client()
  const { data, error } = await supabase.rpc('expire_products')
  if (error) throw new Error(error.message)
  log(`販売終了にした商品: ${data ?? 0}件`)
}

main().catch((error) => {
  console.error(error)
  process.exit(1)
})
