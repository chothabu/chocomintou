import { CATEGORIES, CHAINS, SALE_STATUSES, type Product } from '@/lib/supabase'

/**
 * 商品の作成・編集フォーム。作成と編集で項目がずれないよう 1 つにまとめている。
 */
export function ProductForm({
  action,
  product,
  chains = [],
  submitLabel,
}: {
  action: (formData: FormData) => void
  product?: Product
  chains?: string[]
  submitLabel: string
}) {
  return (
    <form action={action} className="card">
      {product && <input type="hidden" name="id" value={product.id} />}

      <label>
        <span>商品名（必須）</span>
        <input type="text" name="name" defaultValue={product?.name ?? ''} required />
      </label>

      <div className="grid-2">
        <label>
          <span>メーカー</span>
          <input type="text" name="manufacturer" defaultValue={product?.manufacturer ?? ''} />
        </label>
        <label>
          <span>カテゴリ</span>
          <select name="category" defaultValue={product?.category ?? 'ice'}>
            {CATEGORIES.map((item) => (
              <option key={item.value} value={item.value}>
                {item.label}
              </option>
            ))}
          </select>
        </label>
      </div>

      <label>
        <span>説明</span>
        <textarea name="description" rows={3} defaultValue={product?.description ?? ''} />
      </label>

      <div className="grid-2">
        <label>
          <span>価格（円・不明なら空欄）</span>
          <input type="number" name="price" min={0} defaultValue={product?.price ?? ''} />
        </label>
        <label>
          <span>販売状況</span>
          <select name="sale_status" defaultValue={product?.sale_status ?? 'on_sale'}>
            {SALE_STATUSES.map((item) => (
              <option key={item.value} value={item.value}>
                {item.label}
              </option>
            ))}
          </select>
        </label>
      </div>

      <div className="grid-2">
        <label>
          <span>発売日</span>
          <input type="date" name="release_date" defaultValue={product?.release_date ?? ''} />
        </label>
        <label>
          <span>販売終了予定</span>
          <input type="date" name="end_date" defaultValue={product?.end_date ?? ''} />
        </label>
      </div>

      <label>
        <span>販売場所（表示用テキスト。例: 全国のファミリーマート）</span>
        <input
          type="text"
          name="sales_channel_text"
          defaultValue={product?.sales_channel_text ?? ''}
        />
      </label>

      <div className="grid-2">
        <label>
          <span>商品画像 URL</span>
          <input type="url" name="image_url" defaultValue={product?.image_url ?? ''} />
        </label>
        <label>
          <span>公式サイト URL</span>
          <input type="url" name="official_url" defaultValue={product?.official_url ?? ''} />
        </label>
      </div>

      <label>
        <span>取り扱いチェーン（アプリの絞り込みに使う）</span>
        <div className="checks">
          {CHAINS.map((chain) => (
            <label key={chain.value}>
              <input
                type="checkbox"
                name="chains"
                value={chain.value}
                defaultChecked={chains.includes(chain.value)}
              />
              {chain.label}
            </label>
          ))}
        </div>
      </label>

      <div className="checks" style={{ margin: '16px 0' }}>
        <label>
          <input type="checkbox" name="is_limited" defaultChecked={product?.is_limited ?? false} />
          期間限定
        </label>
        <label>
          <input type="checkbox" name="is_published" defaultChecked={product?.is_published ?? false} />
          公開する
        </label>
      </div>

      <button className="primary" type="submit">
        {submitLabel}
      </button>
    </form>
  )
}
