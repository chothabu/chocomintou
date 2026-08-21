import { ProductForm } from '../ProductForm'
import { createProduct } from '../actions'

export const dynamic = 'force-dynamic'

export default function NewProductPage() {
  return (
    <>
      <h1>商品を追加</h1>
      <p className="lead">
        「公開する」にチェックを入れるまで、iOS アプリには表示されません。
      </p>
      <ProductForm action={createProduct} submitLabel="登録する" />
    </>
  )
}
