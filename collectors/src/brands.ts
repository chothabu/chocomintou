/**
 * 巡回するブランド公式サイト。
 *
 * 「全飲食店のメニューを集める」のではなく「チョコミントを出している店だけ見つける」
 * ための一覧。チェーンの公式ページはメーカー自身の告知なので、事実として扱える。
 *
 * 追加するときの基準:
 *   - そのブランドの商品一覧・新商品ページで、静的な HTML に商品名が出ること
 *     （JavaScript で描画されるページは取得しても中身が入っていない）
 *   - robots.txt で全体が Disallow になっていないこと
 */
export type Brand = {
  /** 表示名。検出結果をそのまま運営に見せる */
  name: string
  /** そのチェーンの店舗が stores.chain_name として存在する場合に対応づける */
  chainName?: string
  urls: string[]
}

export const BRANDS: Brand[] = [
  {
    name: 'サーティワンアイスクリーム',
    urls: [
      'https://www.31ice.co.jp/contents/flavor/',
      'https://www.31ice.co.jp/',
    ],
  },
  {
    name: 'セブン-イレブン',
    chainName: 'seven_eleven',
    urls: ['https://www.sej.co.jp/products/a/thisweek/'],
  },
  {
    name: 'ファミリーマート',
    chainName: 'familymart',
    urls: ['https://www.family.co.jp/goods/newgoods.html'],
  },
  {
    name: 'ローソン',
    chainName: 'lawson',
    urls: ['https://www.lawson.co.jp/recommend/original/'],
  },
  {
    name: 'ミニストップ',
    chainName: 'ministop',
    urls: ['https://www.ministop.co.jp/products/'],
  },
  { name: 'スターバックス コーヒー', urls: ['https://product.starbucks.co.jp/beverage/'] },
  { name: 'コメダ珈琲店', urls: ['https://www.komeda.co.jp/menu/'] },
  { name: 'ミスタードーナツ', urls: ['https://www.misterdonut.jp/m_menu/'] },
  { name: 'ドトールコーヒー', urls: ['https://www.doutor.co.jp/dcs/menu/'] },
  { name: 'シャトレーゼ', urls: ['https://www.chateraise.co.jp/ec/category/ice'] },
  { name: 'ゴディバ', urls: ['https://www.godiva.co.jp/'] },
  { name: '赤城乳業', urls: ['https://www.akagi.com/products/'] },
  { name: 'ロッテ アイス', urls: ['https://www.lotte.co.jp/products/brand/'] },
  { name: '明治 エッセル', urls: ['https://www.meiji.co.jp/products/frozen/'] },
  { name: '森永乳業 アイス', urls: ['https://www.morinagamilk.co.jp/products/ice/'] },
  { name: 'ハーゲンダッツ', urls: ['https://www.haagen-dazs.co.jp/products/'] },
  { name: '井村屋', urls: ['https://www.imuraya.co.jp/products/'] },
  { name: '不二家', urls: ['https://www.fujiya-peko.co.jp/products/'] },
  { name: '江崎グリコ', urls: ['https://www.glico.com/jp/product/'] },
  { name: 'サンマルクカフェ', urls: ['https://www.saint-marc-hd.com/saintmarc/menu/'] },
]
