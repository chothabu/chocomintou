/** チョコミントとして拾う語。表記ゆれを吸収する。 */
const POSITIVE = [
  'チョコミント',
  'チョコミン',
  'ミントチョコ',
  'チョコ×ミント',
  'チョコ・ミント',
  'chocomint',
  'choco mint',
  'chocolate mint',
  'mint chocolate',
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
