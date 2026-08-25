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

  // ---- 地方チェーン ----
  // 北海道
  { name: '六花亭', domain: 'www.rokkatei.co.jp' },
  { name: '柳月', domain: 'www.ryugetsu.co.jp' },
  { name: 'きのとや', domain: 'www.kinotoya.com' },
  { name: '北菓楼', domain: 'www.kitakaro.com' },
  { name: 'ラッキーピエロ', domain: 'luckypierrot.jp' },
  // 東北
  { name: '菓匠三全', domain: 'www.sanzen.co.jp' },
  { name: 'ヨークベニマル', domain: 'www.yorkbenimaru.com' },
  // 関東
  { name: 'ベルク', domain: 'www.belc.jp' },
  { name: 'カスミ', domain: 'www.kasumi.co.jp' },
  { name: 'いなげや', domain: 'www.inageya.co.jp' },
  { name: 'ロピア', domain: 'www.lopia.jp' },
  { name: '崎陽軒', domain: 'kiyoken.com' },
  { name: '舟和', domain: 'funawa.jp' },
  { name: 'ポンパドウル', domain: 'www.pompadour.co.jp' },
  { name: '木村屋總本店', domain: 'www.kimuraya-sohonten.co.jp' },
  // 中部
  { name: '平和堂', domain: 'www.heiwado.jp' },
  { name: '春華堂', domain: 'www.shunkado.co.jp' },
  { name: 'バロー', domain: 'www.valor.co.jp' },
  // 関西
  { name: '万代', domain: 'www.mandai-net.co.jp' },
  { name: '関西スーパー', domain: 'www.kansaisuper.co.jp' },
  { name: '551蓬莱', domain: 'www.551horai.co.jp' },
  { name: '進々堂', domain: 'www.shinshindo.jp' },
  { name: 'マールブランシュ', domain: 'www.malebranche.co.jp' },
  { name: 'モロゾフ', domain: 'www.morozoff.co.jp' },
  { name: 'ゴンチャロフ', domain: 'www.goncharoff.co.jp' },
  { name: 'ユーハイム', domain: 'www.juchheim.co.jp' },
  { name: 'アンリ・シャルパンティエ', domain: 'www.henri-charpentier.com' },
  // 中国四国
  { name: 'ハローズ', domain: 'www.halows.com' },
  { name: 'フジ', domain: 'www.fuji.co.jp' },
  { name: 'イズミ（ゆめタウン）', domain: 'www.izumi.co.jp' },
  { name: '八天堂', domain: 'hattendo.jp' },
  { name: '一六本舗', domain: 'www.itm-gr.co.jp' },
  // 九州
  { name: 'トライアル', domain: 'www.trial-net.co.jp' },
  { name: 'ハローデイ', domain: 'www.halloday.co.jp' },
  { name: 'ジョイフル', domain: 'www.joyfull.co.jp' },
  { name: 'リンガーハット', domain: 'www.ringerhut.jp' },
  { name: '石村萬盛堂', domain: 'www.ishimura.co.jp' },
  { name: '竹下製菓', domain: 'takeshita-seika.jp' },
  { name: 'セイカ食品', domain: 'www.seikafoods.jp' },
  // 沖縄
  { name: 'サンエー', domain: 'www.san-a.co.jp' },
  // 全国
  { name: '日世', domain: 'www.nissei-com.co.jp' },

  // ---- ロケスマのカフェ / バーガー / スイーツから追加（店舗数 30 以上）----
  { name: 'ディッピンドッツ', domain: 'www.dippindots.jp' },  // スイーツ/お菓子 600+店
  { name: 'サブウェイ', domain: 'www.subway.co.jp' },  // バーガー 200+店
  { name: 'ZETTERIA', domain: 'www.zetteria.jp' },  // バーガー 200+店
  { name: 'ヨックモック', domain: 'www.yokumoku.co.jp' },  // スイーツ/お菓子 200+店
  { name: 'もち吉', domain: 'www.mochikichi.co.jp' },  // スイーツ/お菓子 200+店
  { name: 'おかしのまちおか', domain: 'www.machioka.co.jp' },  // スイーツ/お菓子 200+店
  { name: 'あじまん', domain: 'www.ajiman.co.jp' },  // スイーツ/お菓子 200+店
  { name: '赤福', domain: 'www.akafuku.co.jp' },  // スイーツ/お菓子 100+店
  { name: '福砂屋', domain: 'www.fukusaya.co.jp' },  // スイーツ/お菓子 100+店
  { name: '源 吉兆庵', domain: 'www.kitchoan.co.jp' },  // スイーツ/お菓子 100+店
  { name: '桂新堂', domain: 'www.keishindo.co.jp' },  // スイーツ/お菓子 100+店
  { name: '文明堂総本店', domain: 'www.bunmeido.co.jp' },  // スイーツ/お菓子 100+店
  { name: '坂角総本舗', domain: 'www.bankaku.co.jp' },  // スイーツ/お菓子 100+店
  { name: 'フロプレステージュ', domain: 'www.flo-prestige.com' },  // スイーツ/お菓子 100+店
  { name: 'ディッパーダン', domain: 'www.dipperdan.jp' },  // スイーツ/お菓子 100+店
  { name: 'ホリーズカフェ', domain: 'www.hollys.jp' },  // カフェ 100+店
  { name: 'ベローチェ', domain: 'www.veloce.co.jp' },  // カフェ 100+店
  { name: 'ブールミッシュ', domain: 'www.boulmich.co.jp' },  // スイーツ/お菓子 90+店
  { name: 'クリスピークリーム', domain: 'www.krispykreme.jp' },  // カフェ 90+店
  { name: '神戸風月堂', domain: 'www.kobefugetsudo.com' },  // スイーツ/お菓子 80+店
  { name: '御座候', domain: 'www.gozasoro.co.jp' },  // スイーツ/お菓子 80+店
  { name: 'とらや', domain: 'www.toraya-group.co.jp' },  // スイーツ/お菓子 80+店
  { name: 'イタトマ', domain: 'www.italiantomato.co.jp' },  // カフェ 80+店
  { name: 'アフタヌーンティー', domain: 'www.afternoon-tea.com' },  // カフェ 80+店
  { name: 'ウェンディーズ', domain: 'www.wendys.com' },  // バーガー 70+店
  { name: '銀座あけぼの', domain: 'www.ginza-akebono.co.jp' },  // スイーツ/お菓子 70+店
]
