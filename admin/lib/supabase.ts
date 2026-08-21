import { createClient, type SupabaseClient } from '@supabase/supabase-js'

/**
 * 管理操作用のクライアント。service_role キーを使うので RLS を素通りする。
 * サーバー側でしか呼ばないこと（このファイルは 'server-only' 前提）。
 */
export function supabaseAdmin(): SupabaseClient {
  const url = process.env.SUPABASE_URL
  const key = process.env.SUPABASE_SERVICE_ROLE_KEY
  if (!url || !key) {
    throw new Error(
      'SUPABASE_URL と SUPABASE_SERVICE_ROLE_KEY を設定してください（.env.example 参照）',
    )
  }
  return createClient(url, key, { auth: { persistSession: false } })
}

export const CATEGORIES = [
  { value: 'ice', label: 'アイス' },
  { value: 'snack', label: 'お菓子' },
  { value: 'cake', label: 'ケーキ' },
  { value: 'parfait', label: 'パフェ' },
  { value: 'drink', label: 'ドリンク' },
  { value: 'bread', label: 'パン' },
  { value: 'other', label: 'その他' },
] as const

export const SALE_STATUSES = [
  { value: 'on_sale', label: '販売中' },
  { value: 'upcoming', label: '発売予定' },
  { value: 'ended', label: '販売終了' },
] as const

export const CHAINS = [
  { value: 'seven_eleven', label: 'セブン-イレブン' },
  { value: 'familymart', label: 'ファミリーマート' },
  { value: 'lawson', label: 'ローソン' },
  { value: 'ministop', label: 'ミニストップ' },
  { value: 'daily_yamazaki', label: 'デイリーヤマザキ' },
  { value: 'seicomart', label: 'セイコーマート' },
  { value: 'other', label: 'その他' },
] as const

export type Product = {
  id: string
  name: string
  manufacturer: string | null
  description: string | null
  category: string
  image_url: string | null
  price: number | null
  release_date: string | null
  end_date: string | null
  sale_status: string
  is_limited: boolean
  sales_channel_text: string | null
  official_url: string | null
  is_published: boolean
  review_count: number
  avg_overall: number | null
  mint_level: number | null
  created_at: string
}

export type Submission = {
  id: string
  name: string
  manufacturer: string | null
  category: string | null
  price: number | null
  release_date: string | null
  purchase_place: string | null
  note: string | null
  status: string
  created_at: string
  /** 'user' = ユーザーからの報告 / 'rakuten' = 収集バッチが集めた候補 */
  source: string
  external_url: string | null
  image_url: string | null
}

export const SOURCE_LABELS: Record<string, string> = {
  user: 'ユーザー報告',
  rakuten: '楽天から収集',
  admin: '運営',
}

export type ReviewReport = {
  id: string
  review_id: string
  reason: string
  detail: string | null
  status: string
  created_at: string
  review: {
    id: string
    comment: string | null
    overall_rating: number
    user_id: string
    is_hidden: boolean
    product: { id: string; name: string } | null
    author: { id: string; display_name: string; is_suspended: boolean } | null
  } | null
}

export type NewsArticle = {
  id: string
  title: string
  source_name: string | null
  article_url: string
  published_at: string
  is_hidden: boolean
}

export const REASON_LABELS: Record<string, string> = {
  spam: 'スパム・宣伝',
  offensive: '不適切な表現',
  irrelevant: '商品と関係がない',
  false_info: '事実と異なる',
  other: 'その他',
}
