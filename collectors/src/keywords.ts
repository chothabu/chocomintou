/**
 * チョコミントとして拾う語。
 *
 * normalize() が空白と区切り記号を落とすので、「チョコ・ミント」「choco mint」なども
 * ここに並べる必要はない。
 */
const POSITIVE = [
  'チョコミント',
  'チョコミン', // 「チョコミン党」を含む
  'ミントチョコ',
  'chocomint',
  'chocolatemint',
  'mintchocolate',
  'mintchoco',
]

/**
 * 「チョコミント」を含んでいても商品として扱わないもの。
 *
 * 楽天の検索結果には歯磨き粉・アロマ・雑貨がかなり混ざる（設計 §26 のノイズ除去）。
 * 判定を誤っても運営確認で弾けるので、迷ったら通す側に倒している。
 */
const NEGATIVE = [
  '歯磨き',
  'はみがき',
  '歯みがき',
  'ハミガキ',
  'マウスウォッシュ',
  'デンタル',
  'シャンプー',
  'リンス',
  'ボディソープ',
  '入浴剤',
  'バスソルト',
  'アロマ',
  '香水',
  'フレグランス',
  'ハンドクリーム',
  'リップクリーム',
  '芳香剤',
  '消臭',
  'タバコ',
  'たばこ',
  '電子タバコ',
  'リキッド',
  'ケース',
  'カバー',
  'ステッカー',
  'キーホルダー',
  'ぬいぐるみ',
  'Tシャツ',
  'スマホ',
  'iPhone',
  'ネイル',
  'サプリ',
  'プロテイン',
  'リップ',
  'マスク',
  'コスメ',
  'ボディクリーム',
  // 食品でない物販。「チョコミント」は商品名・作者名・柄の名前としても使われる
  'のぼり旗',
  'のぼり',
  '電子書籍',
  'コミック',
  '書籍',
  '文庫',
  'ハンドバッグ',
  'バッグ',
  'ポーチ',
  'エプロン',
  'タオル',
  'マグカップ',
  'クッション',
  'カーテン',
  'レザー',
  'アクセサリー',
  'ピアス',
  'ネックレス',
  // 食材・製菓材料。完成した商品ではないので図鑑には載せない
  'パウダー',
  '製菓材料',
  '香料',
  'エッセンス',
  'シロップ用',
]

function normalize(text: string): string {
  return text
    .toLowerCase()
    // 全角英数を半角に寄せる
    .replace(/[Ａ-Ｚａ-ｚ０-９]/g, (c) => String.fromCharCode(c.charCodeAt(0) - 0xfee0))
    // 区切り記号は無視して「チョコ ミント」も拾う
    .replace(/[\s　・×・\-−ー_]/g, '')
}

const NORMALIZED_POSITIVE = POSITIVE.map(normalize)
const NORMALIZED_NEGATIVE = NEGATIVE.map(normalize)

/** チョコミント関連か。 */
export function isChocomint(text: string): boolean {
  const target = normalize(text)
  return NORMALIZED_POSITIVE.some((word) => target.includes(word))
}

/** 食べ物ではなさそうなものを弾く。 */
export function looksLikeNoise(text: string): boolean {
  const target = normalize(text)
  return NORMALIZED_NEGATIVE.some((word) => target.includes(word))
}

/** 収集対象として採用するか。 */
export function shouldCollect(text: string): boolean {
  return isChocomint(text) && !looksLikeNoise(text)
}

/**
 * 同一商品の判定に使うキー。
 *
 * 楽天には同じ商品が複数の店から、あるいは同じ店から容量違い・価格違いで出品される。
 * itemCode は出品単位なので重複を防げない。商品名から販促文句と数量表記を落として
 * 突き合わせることで、運営が同じ商品を何度も確認せずに済むようにする。
 *
 * 完全な名寄せは狙わない。取りこぼしても運営確認で弾けるので、
 * 明らかに同じものだけをまとめる。
 */
export function dedupeKey(name: string): string {
  // normalize() の時点で空白と一部の区切り記号は落ちている。
  const UNIT = '(?:ml|l|g|kg|cm|mm|本|個|袋|枚|入|セット|パック)?'
  // 数量・容量・型番・寸法。「11.5cm x 2.4cm x 17.4cm」のように x でつながる場合が
  // あるので、連なり全体をひとまとまりとして落とす。
  const QUANTITY = new RegExp(`\\d+(?:\\.\\d+)?${UNIT}(?:[x×]\\d+(?:\\.\\d+)?${UNIT})*`, 'g')

  return normalize(name)
    // 【】［］（）で囲まれた販促文句
    .replace(/[【［(（\[].*?[】］)）\]]/g, '')
    .replace(QUANTITY, '')
    // 送料・配送まわりの決まり文句
    .replace(/送料無料|クール便|直送品|冷凍|返品不可|ポイント\w*/g, '')
    // 記号と、寸法表記の名残の x を落とす
    .replace(/[^\p{L}\p{N}]/gu, '')
    .replace(/x+/g, '')
    .slice(0, 60)
}

/** 商品名からカテゴリを推定する。外れても運営が直せるので、確実なものだけ拾う。 */
export function guessCategory(name: string): string {
  const target = normalize(name)
  const rules: [string[], string][] = [
    [['アイス', 'ソフトクリーム', 'ジェラート', 'かき氷', 'モナカ', 'もなか', 'バー'], 'ice'],
    [['パフェ', 'サンデー'], 'parfait'],
    [['ケーキ', 'ロール', 'タルト', 'シュー', 'プリン'], 'cake'],
    [['ドリンク', 'ラテ', 'オレ', 'ソーダ', 'ジュース', '飲料', 'フラペ', 'スムージー'], 'drink'],
    [['パン', 'メロンパン', 'サンド'], 'bread'],
    [['クッキー', 'チョコレート', 'ビスケット', 'キャンディ', 'グミ', 'ポッキー', '菓子'], 'snack'],
  ]
  for (const [words, category] of rules) {
    if (words.some((word) => target.includes(normalize(word)))) return category
  }
  return 'other'
}
