/**
 * 巡回するブランド公式サイト。
 *
 * 「全飲食店のメニューを集める」のではなく「チョコミントを出している店だけ見つける」
 * ための一覧（設計 §外部データ源の調査）。チェーンの公式ページはその会社自身の
 * 告知なので、事実として扱える。
 *
 * `paths` を空にすると、トップページと sitemap.xml から候補ページを自動で探す。
 * 決め打ちの URL はサイト改装で 404 になるため、分かっている場合だけ書く。
 */
export type Brand = {
  name: string
  /** https:// を除いたホスト名 */
  domain: string
  /** そのチェーンの店舗が stores.chain_name として存在する場合に対応づける */
  chainName?: string
  /** 商品一覧・新商品ページ。分かっているものだけ。空なら自動探索 */
  paths?: string[]
}

export const BRANDS: Brand[] = [
  // ---- コンビニ ----
  { name: 'セブン-イレブン', domain: 'www.sej.co.jp', chainName: 'seven_eleven', paths: ['/products/a/thisweek/', '/products/a/'] },
  { name: 'ファミリーマート', domain: 'www.family.co.jp', chainName: 'familymart', paths: ['/goods/newgoods.html', '/goods.html'] },
  { name: 'ローソン', domain: 'www.lawson.co.jp', chainName: 'lawson', paths: ['/recommend/original/', '/recommend/'] },
  { name: 'ミニストップ', domain: 'www.ministop.co.jp', chainName: 'ministop' },
  { name: 'デイリーヤマザキ', domain: 'www.daily-yamazaki.jp', chainName: 'daily_yamazaki' },
  { name: 'セイコーマート', domain: 'www.seicomart.co.jp', chainName: 'seicomart' },

  // ---- スーパー・量販 ----
  { name: 'イオン（トップバリュ）', domain: 'www.topvalu.net' },
  { name: 'イトーヨーカドー', domain: 'www.itoyokado.co.jp' },
  { name: 'ライフ', domain: 'www.lifecorp.jp' },
  { name: '西友', domain: 'www.seiyu.co.jp' },
  { name: '業務スーパー', domain: 'www.gyomusuper.jp' },
  { name: 'サミット', domain: 'www.summitstore.co.jp' },
  { name: 'ヤオコー', domain: 'www.yaoko-net.com' },
  { name: 'オーケー', domain: 'ok-corporation.jp' },
  { name: 'カルディコーヒーファーム', domain: 'www.kaldi.co.jp' },
  { name: '成城石井', domain: 'www.seijoishii.com' },
  { name: 'ドン・キホーテ', domain: 'www.donki.com' },

  // ---- アイス・氷菓メーカー ----
  { name: '赤城乳業', domain: 'www.akagi.com', paths: ['/products/'] },
  { name: 'ロッテ', domain: 'www.lotte.co.jp' },
  { name: '明治', domain: 'www.meiji.co.jp' },
  { name: '森永乳業', domain: 'www.morinagamilk.co.jp' },
  { name: '森永製菓', domain: 'www.morinaga.co.jp' },
  { name: '江崎グリコ', domain: 'www.glico.com' },
  { name: '井村屋', domain: 'www.imuraya.co.jp' },
  { name: '丸永製菓', domain: 'www.marunaga.com' },
  { name: 'オハヨー乳業', domain: 'www.ohayo-milk.co.jp' },
  { name: '雪印メグミルク', domain: 'www.meg-snow.com' },
  { name: 'シャトレーゼ', domain: 'www.chateraise.co.jp' },
  { name: 'サーティワンアイスクリーム', domain: 'www.31ice.co.jp', paths: ['/contents/flavor/', '/contents/news/'] },
  { name: 'ブルーシール', domain: 'www.blueseal.co.jp' },

  // ---- 菓子メーカー ----
  { name: '不二家', domain: 'www.fujiya-peko.co.jp' },
  { name: 'ブルボン', domain: 'www.bourbon.co.jp' },
  { name: 'カバヤ食品', domain: 'www.kabaya.co.jp' },
  { name: 'チロルチョコ', domain: 'www.tirol-choco.com' },
  { name: '有楽製菓（ブラックサンダー）', domain: 'www.yurakuseika.co.jp' },
  { name: '亀田製菓', domain: 'www.kamedaseika.co.jp' },
  { name: '湖池屋', domain: 'koikeya.co.jp' },
  { name: 'カルビー', domain: 'www.calbee.co.jp' },
  { name: 'UHA味覚糖', domain: 'www.uha-mikakuto.co.jp' },
  { name: 'カンロ', domain: 'www.kanro.co.jp' },
  { name: '春日井製菓', domain: 'www.kasugai.co.jp' },
  { name: 'ゴディバ', domain: 'www.godiva.co.jp' },
  { name: 'リンツ', domain: 'www.lindt.jp' },
  { name: 'メリーチョコレート', domain: 'www.mary.co.jp' },
  { name: 'ロイズ', domain: 'www.royce.com' },

  // ---- パン ----
  { name: '山崎製パン', domain: 'www.yamazakipan.co.jp' },
  { name: 'フジパン', domain: 'www.fujipan.co.jp' },
  { name: '敷島製パン（Pasco）', domain: 'www.pasconet.co.jp' },
  { name: '神戸屋', domain: 'www.kobeya.co.jp' },
  { name: 'ヴィ・ド・フランス', domain: 'www.vdf.co.jp' },
  { name: 'ドンク', domain: 'www.donq.co.jp' },
  { name: 'アンデルセン', domain: 'www.andersen.co.jp' },

  // ---- カフェ ----
  { name: 'スターバックス コーヒー', domain: 'product.starbucks.co.jp' },
  { name: 'ドトールコーヒー', domain: 'www.doutor.co.jp' },
  { name: 'タリーズコーヒー', domain: 'www.tullys.co.jp' },
  { name: 'コメダ珈琲店', domain: 'www.komeda.co.jp' },
  { name: '星乃珈琲店', domain: 'www.hoshinocoffee.com' },
  { name: 'サンマルクカフェ', domain: 'www.saint-marc-hd.com' },
  { name: 'プロント', domain: 'www.pronto.co.jp' },
  { name: '珈琲館', domain: 'www.kohikan.jp' },
  { name: '銀座ルノアール', domain: 'www.ginza-renoir.co.jp' },
  { name: '上島珈琲店', domain: 'www.ueshima-coffee-ten.jp' },

  // ---- ファストフード ----
  { name: 'マクドナルド', domain: 'www.mcdonalds.co.jp' },
  { name: 'モスバーガー', domain: 'www.mos.jp' },
  { name: 'ロッテリア', domain: 'www.lotteria.jp' },
  { name: 'フレッシュネスバーガー', domain: 'www.freshnessburger.co.jp' },
  { name: 'バーガーキング', domain: 'www.burgerking.co.jp' },
  { name: 'ケンタッキーフライドチキン', domain: 'www.kfc.co.jp' },
  { name: 'ファーストキッチン', domain: 'www.first-kitchen.co.jp' },
  { name: 'ミスタードーナツ', domain: 'www.misterdonut.jp' },
  { name: 'クリスピー・クリーム・ドーナツ', domain: 'krispykreme.jp' },

  // ---- ファミレス・外食 ----
  { name: 'ガスト（すかいらーく）', domain: 'www.skylark.co.jp' },
  { name: 'サイゼリヤ', domain: 'www.saizeriya.co.jp' },
  { name: 'デニーズ', domain: 'www.dennys.jp' },
  { name: 'ロイヤルホスト', domain: 'www.royalhost.jp' },
  { name: 'ココス', domain: 'www.cocos-jpn.co.jp' },
  { name: 'びっくりドンキー', domain: 'www.bikkuri-donkey.com' },

  // ---- 回転寿司・その他チェーン ----
  { name: 'かっぱ寿司', domain: 'www.kappasushi.jp' },
  { name: 'スシロー', domain: 'www.akindo-sushiro.co.jp' },
  { name: 'くら寿司', domain: 'www.kurasushi.co.jp' },
  { name: 'はま寿司', domain: 'www.hamazushi.com' },

  // ---- スイーツ専門 ----
  { name: '銀座コージーコーナー', domain: 'www.cozycorner.co.jp' },
  { name: 'ビアードパパ', domain: 'www.beardpapa.jp' },
  { name: 'PABLO', domain: 'www.pablo3.com' },
  { name: 'ロールアイスクリームファクトリー', domain: 'rollicecreamfactory.com' },
]
