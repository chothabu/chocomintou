'use server'

import { revalidatePath } from 'next/cache'
import { redirect } from 'next/navigation'
import { supabaseAdmin } from '@/lib/supabase'

function text(formData: FormData, key: string): string | null {
  const value = String(formData.get(key) ?? '').trim()
  return value === '' ? null : value
}

function number(formData: FormData, key: string): number | null {
  const value = text(formData, key)
  if (value === null) return null
  const parsed = Number(value)
  return Number.isFinite(parsed) ? parsed : null
}

function productPayload(formData: FormData) {
  return {
    name: String(formData.get('name') ?? '').trim(),
    manufacturer: text(formData, 'manufacturer'),
    description: text(formData, 'description'),
    category: String(formData.get('category') ?? 'other'),
    image_url: text(formData, 'image_url'),
    price: number(formData, 'price'),
    release_date: text(formData, 'release_date'),
    end_date: text(formData, 'end_date'),
    sale_status: String(formData.get('sale_status') ?? 'on_sale'),
    is_limited: formData.get('is_limited') === 'on',
    sales_channel_text: text(formData, 'sales_channel_text'),
    official_url: text(formData, 'official_url'),
    is_published: formData.get('is_published') === 'on',
  }
}

/** 取り扱いチェーンは総入れ替えで保存する。差分を追うほどの件数ではない。 */
async function replaceChannels(productId: string, chains: string[]) {
  const supabase = supabaseAdmin()
  await supabase.from('product_channels').delete().eq('product_id', productId)
  if (chains.length === 0) return
  await supabase
    .from('product_channels')
    .insert(chains.map((chain) => ({ product_id: productId, chain_name: chain })))
}

export async function createProduct(formData: FormData) {
  const payload = productPayload(formData)
  if (!payload.name) throw new Error('商品名は必須です')

  const supabase = supabaseAdmin()
  const { data, error } = await supabase.from('products').insert(payload).select('id').single()
  if (error) throw new Error(error.message)

  await replaceChannels(data.id, formData.getAll('chains').map(String))
  revalidatePath('/products')
  redirect(`/products/${data.id}`)
}

export async function updateProduct(formData: FormData) {
  const id = String(formData.get('id'))
  const payload = productPayload(formData)
  if (!payload.name) throw new Error('商品名は必須です')

  const supabase = supabaseAdmin()
  const { error } = await supabase
    .from('products')
    .update({ ...payload, updated_at: new Date().toISOString() })
    .eq('id', id)
  if (error) throw new Error(error.message)

  await replaceChannels(id, formData.getAll('chains').map(String))
  revalidatePath('/products')
  revalidatePath(`/products/${id}`)
}

export async function setPublished(formData: FormData) {
  const id = String(formData.get('id'))
  const published = formData.get('published') === 'true'
  const supabase = supabaseAdmin()
  await supabase.from('products').update({ is_published: published }).eq('id', id)
  revalidatePath('/products')
}

export async function deleteProduct(formData: FormData) {
  const id = String(formData.get('id'))
  const supabase = supabaseAdmin()
  // レビュー・目撃・図鑑の記録も ON DELETE CASCADE で消える。
  await supabase.from('products').delete().eq('id', id)
  revalidatePath('/products')
  redirect('/products')
}
