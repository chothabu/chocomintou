import { notFound } from 'next/navigation'
import { supabaseAdmin, type Product } from '@/lib/supabase'
import { ProductForm } from '../ProductForm'
import { deleteProduct, updateProduct } from '../actions'

export const dynamic = 'force-dynamic'

export default async function EditProductPage({ params }: { params: Promise<{ id: string }> }) {
  const { id } = await params
  const supabase = supabaseAdmin()

  const [{ data: product }, { data: channels }, { count: sightingCount }] = await Promise.all([
    supabase.from('products').select('*').eq('id', id).maybeSingle(),
    supabase.from('product_channels').select('chain_name').eq('product_id', id),
    supabase
      .from('sightings')
      .select('*', { count: 'exact', head: true })
      .eq('product_id', id)
      .eq('is_deleted', false),
  ])

  if (!product) notFound()

  return (
    <>
      <h1>{(product as Product).name}</h1>
      <p className="lead">
        レビュー {(product as Product).review_count}件 / 目撃報告 {sightingCount ?? 0}件
      </p>

      <ProductForm
        action={updateProduct}
        product={product as Product}
        chains={(channels ?? []).map((row: { chain_name: string }) => row.chain_name)}
        submitLabel="保存する"
      />

      <h2>削除</h2>
      <div className="card">
        <p style={{ marginTop: 0 }}>
          削除すると、この商品に紐づくレビュー・目撃情報・図鑑の記録もすべて消えます。
          販売が終わっただけなら、販売状況を「販売終了」にしてください。
        </p>
        <form action={deleteProduct}>
          <input type="hidden" name="id" value={id} />
          <button className="danger" type="submit">
            この商品を削除する
          </button>
        </form>
      </div>
    </>
  )
}
