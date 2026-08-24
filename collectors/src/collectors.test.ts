import assert from 'node:assert/strict'
import { test } from 'node:test'
import { parseFeed } from './feed.js'
import { dedupeKey, guessCategory, shouldCollect } from './keywords.js'

const RSS2 = `<?xml version="1.0"?>
<rss version="2.0" xmlns:media="http://search.yahoo.com/mrss/">
  <channel>
    <title>テストニュース</title>
    <item>
      <title>チョコミント新商品が今夏も登場</title>
      <link>https://example.com/a</link>
      <pubDate>Tue, 18 Aug 2026 02:00:00 GMT</pubDate>
      <media:content url="https://example.com/a.jpg"/>
    </item>
    <item>
      <title>まったく関係のないニュース</title>
      <link>https://example.com/b</link>
      <pubDate>Tue, 18 Aug 2026 03:00:00 GMT</pubDate>
    </item>
  </channel>
</rss>`

const RDF = `<?xml version="1.0"?>
<rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#" xmlns:dc="http://purl.org/dc/elements/1.1/">
  <item rdf:about="https://example.com/c">
    <title>ミントチョコのアイスが復活</title>
    <link>https://example.com/c</link>
    <dc:date>2026-08-19T10:00:00+09:00</dc:date>
  </item>
</rdf:RDF>`

const ATOM = `<?xml version="1.0"?>
<feed xmlns="http://www.w3.org/2005/Atom">
  <entry>
    <title>チョコミントフラペチーノ発売</title>
    <link rel="alternate" href="https://example.com/d"/>
    <published>2026-08-20T01:00:00Z</published>
  </entry>
</feed>`

test('RSS 2.0 を解釈できる', () => {
  const items = parseFeed(RSS2)
  assert.equal(items.length, 2)
  assert.equal(items[0].title, 'チョコミント新商品が今夏も登場')
  assert.equal(items[0].link, 'https://example.com/a')
  assert.equal(items[0].thumbnailUrl, 'https://example.com/a.jpg')
  assert.equal(items[0].publishedAt.toISOString(), '2026-08-18T02:00:00.000Z')
})

test('RDF (RSS 1.0) を解釈できる', () => {
  const items = parseFeed(RDF)
  assert.equal(items.length, 1)
  assert.equal(items[0].title, 'ミントチョコのアイスが復活')
  assert.equal(items[0].publishedAt.toISOString(), '2026-08-19T01:00:00.000Z')
})

test('Atom を解釈できる', () => {
  const items = parseFeed(ATOM)
  assert.equal(items.length, 1)
  assert.equal(items[0].link, 'https://example.com/d')
})

test('日付が壊れていても落ちない', () => {
  const items = parseFeed(`<rss><channel><item>
    <title>チョコミント</title><link>https://example.com/e</link><pubDate>めちゃくちゃ</pubDate>
  </item></channel></rss>`)
  assert.equal(items.length, 1)
  assert.ok(!Number.isNaN(items[0].publishedAt.getTime()))
})

test('タイトルかリンクが無い項目は捨てる', () => {
  const items = parseFeed(`<rss><channel>
    <item><title>タイトルだけ</title></item>
    <item><link>https://example.com/f</link></item>
  </channel></rss>`)
  assert.equal(items.length, 0)
})

test('チョコミント関連だけを拾う', () => {
  assert.ok(shouldCollect('チョコミントアイス'))
  assert.ok(shouldCollect('ミントチョコクッキー'))
  assert.ok(shouldCollect('チョコ・ミント のパフェ'), '区切り記号があっても拾う')
  assert.ok(shouldCollect('Chocolate Mint Ice Cream'))
  assert.ok(!shouldCollect('いちごミルク'))
})

test('食品でないものを除外する', () => {
  assert.ok(!shouldCollect('チョコミント味 歯磨き粉'))
  assert.ok(!shouldCollect('チョコミントの香り 入浴剤'))
  assert.ok(!shouldCollect('チョコミント柄 iPhoneケース'))
  assert.ok(!shouldCollect('ミントチョコ風味 プロテイン'))
})

// 実際に楽天から混ざってきたもの。「チョコミント」は
// 作者名・柄の名前・のぼりの文言としても使われる。
test('食品でない物販や書籍を除外する', () => {
  assert.ok(!shouldCollect('鬼畜極道、ヤバすぎる溺愛。 第48話 【電子書籍】[ チョコミント ]'))
  assert.ok(!shouldCollect('のぼり旗 チョコミントカステラ・レトロ風のぼり'))
  assert.ok(!shouldCollect('翠銅鉱チョコミントケーキ PUレザーハンドバッグ ユニセックス'))
  assert.ok(!shouldCollect('ラネージュ リップスリーピングマスク チョコミント'))
})

// コンビニの新商品ページには食品とキャラクターグッズが並ぶ
test('キャラクターグッズを除外する', () => {
  assert.ok(!shouldCollect('アニメ『魔入りました！入間くん』トレーディングアクリルスタンド アクドル×チョコミントver.'))
  assert.ok(!shouldCollect('チョコミントver. 缶バッジ'))
})

test('製菓材料は除外する（完成した商品ではない）', () => {
  assert.ok(!shouldCollect('フレッシュミント FDパウダー（スイーツ・ドリンク・チョコミント）'))
})

test('ふつうの商品は除外しない', () => {
  assert.ok(shouldCollect('ロッテ 小さなアイス屋さん チョコミント 1L'))
  assert.ok(shouldCollect('赤城乳業 セルフチョコレートクラッシュ チョコミント'))
  assert.ok(shouldCollect('北海道銘菓 雪花青 チョコミント ホワイトチョコクッキー'))
  assert.ok(shouldCollect('チョコミントバー 1袋6本入 あいす おやつ 夏 冷凍'))
})

test('同じ商品の別出品をまとめる', () => {
  // 実際に楽天から重複して取れたもの（片方に寸法が付いている）
  assert.equal(
    dedupeKey('無印良品 牛乳でつくる チョコミントラテ ・104g 84905629'),
    dedupeKey('無印良品 牛乳でつくる チョコミントラテ ・104g 84905629 11.5 cm x 2.4 cm x 17.4 cm'),
  )
  // 販促文句・送料表記の違いを無視する
  assert.equal(
    dedupeKey('【送料無料】ロッテ チョコミントアイス 1L 冷凍'),
    dedupeKey('ロッテ チョコミントアイス 1L'),
  )
  // 容量違いは同じ商品として扱う
  assert.equal(
    dedupeKey('赤城乳業 チョコミントバー 6本入'),
    dedupeKey('赤城乳業 チョコミントバー 12本入'),
  )
})

test('別の商品はまとめない', () => {
  assert.notEqual(
    dedupeKey('ロッテ チョコミントアイス'),
    dedupeKey('赤城乳業 チョコミントアイス'),
  )
  assert.notEqual(
    dedupeKey('チョコミントクッキー'),
    dedupeKey('チョコミントケーキ'),
  )
})

test('商品名からカテゴリを推定する', () => {
  assert.equal(guessCategory('チョコミントアイスバー'), 'ice')
  assert.equal(guessCategory('チョコミントパフェ'), 'parfait')
  assert.equal(guessCategory('チョコミントロールケーキ'), 'cake')
  assert.equal(guessCategory('チョコミントラテ'), 'drink')
  assert.equal(guessCategory('チョコミントメロンパン'), 'bread')
  assert.equal(guessCategory('チョコミントクッキー'), 'snack')
  assert.equal(guessCategory('チョコミントなにか'), 'other')
})
