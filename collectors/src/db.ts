import { createClient, type SupabaseClient } from '@supabase/supabase-js'

/**
 * 収集バッチ用のクライアント。service_role キーで RLS を素通りする。
 * サーバー上（cron / Edge Functions）でだけ実行すること。
 */
export function client(): SupabaseClient {
  const url = process.env.SUPABASE_URL
  const key = process.env.SUPABASE_SERVICE_ROLE_KEY
  if (!url || !key) {
    throw new Error('SUPABASE_URL と SUPABASE_SERVICE_ROLE_KEY を設定してください（.env.example 参照）')
  }
  return createClient(url, key, { auth: { persistSession: false } })
}

export function log(message: string): void {
  console.log(`[${new Date().toISOString()}] ${message}`)
}
