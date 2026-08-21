import { XMLParser } from 'fast-xml-parser'

export type FeedItem = {
  title: string
  link: string
  publishedAt: Date
  thumbnailUrl: string | null
}

const parser = new XMLParser({
  ignoreAttributes: false,
  attributeNamePrefix: '@_',
  // CDATA も含めてテキストとして取り出す
  processEntities: true,
  trimValues: true,
})

function asArray<T>(value: T | T[] | undefined | null): T[] {
  if (value === undefined || value === null) return []
  return Array.isArray(value) ? value : [value]
}

function text(value: unknown): string {
  if (typeof value === 'string') return value
  if (typeof value === 'number') return String(value)
  if (value && typeof value === 'object' && '#text' in value) {
    return String((value as Record<string, unknown>)['#text'] ?? '')
  }
  return ''
}

/** Atom の link は rel="alternate" が本文へのリンク。 */
function atomLink(entry: Record<string, unknown>): string {
  const links = asArray(entry.link as unknown)
  for (const link of links) {
    if (typeof link === 'string') return link
    const record = link as Record<string, unknown>
    const rel = record['@_rel']
    if (rel === undefined || rel === 'alternate') return String(record['@_href'] ?? '')
  }
  return ''
}

function thumbnail(item: Record<string, unknown>): string | null {
  const media = item['media:content'] ?? item['media:thumbnail']
  for (const entry of asArray(media)) {
    const url = (entry as Record<string, unknown>)?.['@_url']
    if (url) return String(url)
  }
  const enclosure = asArray(item.enclosure)[0] as Record<string, unknown> | undefined
  if (enclosure?.['@_url']) return String(enclosure['@_url'])
  return null
}

/**
 * RSS 2.0 / RDF (RSS 1.0) / Atom のどれで来ても同じ形に均す。
 * 日本のニュースサイトは 3 形式が入り混じっているため、どれか 1 つに決め打ちできない。
 */
export function parseFeed(xml: string): FeedItem[] {
  const parsed = parser.parse(xml) as Record<string, any>

  const rawItems: Record<string, unknown>[] =
    asArray(parsed?.rss?.channel?.item) as Record<string, unknown>[]
  const rdfItems = asArray(parsed?.['rdf:RDF']?.item) as Record<string, unknown>[]
  const atomEntries = asArray(parsed?.feed?.entry) as Record<string, unknown>[]

  const source = rawItems.length > 0 ? rawItems : rdfItems.length > 0 ? rdfItems : atomEntries
  const isAtom = source === atomEntries

  return source
    .map((item): FeedItem | null => {
      const title = text(item.title).trim()
      const link = isAtom ? atomLink(item) : text(item.link).trim()
      if (!title || !link) return null

      const rawDate =
        text(item.pubDate) || text(item['dc:date']) || text(item.published) || text(item.updated)
      const published = rawDate ? new Date(rawDate) : new Date()

      return {
        title,
        link,
        // 日付が壊れているフィードもあるので、取得時刻で代替する
        publishedAt: Number.isNaN(published.getTime()) ? new Date() : published,
        thumbnailUrl: thumbnail(item),
      }
    })
    .filter((item): item is FeedItem => item !== null)
}
