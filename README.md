# チョコミン党

全国のチョコミントを収集していく **図鑑 + レーダー** のアプリ。

- **図鑑** = 何が存在するか（Product）
- **レーダー** = 今どこで見つかるか（Sighting → Store）

商品と店舗は別データとして管理し、その間をユーザーの目撃情報でつなぐ。
これにより「チョコミント商品が存在する」だけでなく「今この辺で食べられる可能性がある」を提供する。

設計の詳細は [`docs/DESIGN.md`](docs/DESIGN.md)、DB は [`supabase/migrations/`](supabase/migrations/)。

## 構成

```
ios/         iOS アプリ（Swift 6 / SwiftUI / MapKit / SwiftData）
admin/       運営用 Web 管理画面（Next.js / Supabase service_role）
collectors/  ニュース・商品候補の収集バッチ（Node / TypeScript）
supabase/    マイグレーションとローカル開発用シード
db/          スキーマの検証・適用スクリプト
docs/        設計書
```

## 実データを入れる

このアプリのデータは 3 種類あり、入り口がそれぞれ違う。

| データ | 入れ方 | 必要なもの |
|---|---|---|
| 商品 | 管理画面で登録、または楽天から候補収集 → 承認 | 楽天のアプリ ID + アクセスキー |
| ニュース | 収集元フィードを登録 → 収集バッチ | 利用条件を確認したフィード |
| 店舗・目撃情報 | アプリの目撃報告フロー | 現地での報告 |

店舗と目撃情報は外部から持ってこられない。運営が現地で報告して最初の密度を作る（設計 §9）。

```bash
cd collectors
cp .env.example .env    # 値を埋める
npm install
```

| コマンド | 何を集めるか | 頻度 |
|---|---|---|
| `npm run collect:news` | ニュース記事（登録した RSS から） | 毎日 |
| `npm run collect:products` | 楽天の市販品・通販の取扱店 | 週次 |
| `npm run collect:prtimes` | **チョコミントを出した実績のある店**（プレスリリース） | 週次 |
| `npm run watch:brands` | チェーン公式サイトの取扱商品（85 ブランド） | 週次 |
| `npm run prune` | 収集済み候補に現在のフィルタをかけ直す | 随時 |

`--save` を付けると候補として登録し、付けなければ結果を表示するだけです。
`watch:brands` は `--brand 明治` で 1 社だけ試せます。

定期実行は [`.github/workflows/collect.yml`](.github/workflows/collect.yml) にあります。
Supabase をクラウドに移し、リポジトリの Secrets に接続情報を入れると動きます。

収集した商品候補は公開されない。管理画面の「商品候補」で内容を確認し、承認 → 公開したものだけが
アプリに出る（設計 §26 / §28）。承認時に商品画像と商品ページの URL も引き継がれる。

**楽天の設定について。** アプリ登録時に Application type を「API/Backend Service」にすると、
実行元のグローバル IP を Allowed IP addresses に登録する必要がある。
IP が変わると収集が 403 で止まるので、そのときは `curl -s https://api.ipify.org` で
現在の IP を調べて楽天側を更新する（収集バッチはこの旨をエラーメッセージに出す）。

**ニュースの収集元について。** どのフィードを使うかは、その利用条件を確認したうえで
管理画面の「収集元」から登録する。コードにフィード URL は書いていない。
Google ニュースの RSS は、フィード自身が個人の非商用利用以外を明示的に禁じているため使えない。

## iOS アプリ

### 必要なもの

- Xcode 26 以降（iOS 17.0 以降が対象）
- [XcodeGen](https://github.com/yonaskolb/XcodeGen)（`brew install xcodegen`）

`.xcodeproj` は生成物なのでコミットしていない。

```bash
cd ios
xcodegen generate
open ChocoMint.xcodeproj
```

### ローカルの Supabase につないで動かす

実際のバックエンドを手元で立てて、そこに向けて動かせる。

```bash
npx supabase start          # API: http://127.0.0.1:54421
```

マイグレーションと `supabase/seed.sql`（動作確認用データ）が自動で適用される。
`ios/Config/Supabase.xcconfig` のローカル用 2 行のコメントを外すと、アプリがそちらを見る。

停止は `npx supabase stop`、DB を作り直すときは `npx supabase db reset`。

### バックエンドなしで動かす

Supabase の接続先が未設定のときは、**サンプルデータで全画面が動く**。
バックエンドを立てる前に画面と導線を確認できる。

そのまま `⌘R` で起動すれば、渋谷周辺の架空の商品・店舗・目撃情報が入った状態で触れる。
シミュレータの位置情報は Features → Location → Custom Location から
`35.6595, 139.7005`（渋谷）に設定すると、近くのチョコミントとマップにデータが出る。

サンプル動作時のログインは Apple の認証基盤を使えないため、
ログイン画面に「サンプルユーザーでログイン」ボタンが出る。

### Supabase につなぐ

1. Supabase プロジェクトを作り、スキーマを適用する。

   ```bash
   # 接続文字列は Project Settings → Database → Connection string (URI) からコピー
   DATABASE_URL='postgresql://postgres.xxxx:PASSWORD@aws-0-....pooler.supabase.com:5432/postgres' \
     ./db/apply.sh
   ```

   psql は Docker 経由で動くので、ローカルにインストールする必要はない。
   `supabase/migrations/20260820000000_init.sql` は**初回適用専用**（冪等ではない）で、適用済みの DB に流そうとすると
   スクリプトが手前で止める。以降の変更は差分の SQL を別途書くこと。

2. Authentication → Providers で **Apple** を有効にする。
3. Xcode の Build Settings（または `.xcconfig`）に次を設定する。

   | 設定名 | 値 |
   |---|---|
   | `SUPABASE_URL` | `https://xxxx.supabase.co` |
   | `SUPABASE_ANON_KEY` | anon（public）キー |

   `Info.plist` がこの 2 つを読む。**service_role キーは絶対に入れないこと。**

4. Signing & Capabilities で開発チームを設定する（Sign in with Apple に有償アカウントが要る）。

anon key は公開前提の識別子で、実際のアクセス制御は RLS が行う。
外部 API は iPhone から直接叩かず、収集バッチ（`collectors/`）側に置く。

## スキーマの検証

`supabase/migrations/20260820000000_init.sql` は Docker 上のローカル PostgreSQL で通しで検証できる。
Supabase 公式の Postgres イメージを使うので、拡張とロール構成は本番に近い。

```bash
./db/verify.sh
```

スキーマの適用に加えて、トリガーによる集計、目撃報告 RPC の店舗名寄せ、
鮮度判定の境界値、RLS（未ログインでの投稿拒否・他人の行への書き込み拒否）まで実際に動かして確かめる。

## テスト

### iOS

```bash
cd ios
xcodebuild -project ChocoMint.xcodeproj -scheme ChocoMint \
  -destination 'platform=iOS Simulator,name=iPhone 17,OS=latest' \
  CODE_SIGNING_ALLOWED=NO test
```

- `Tests/` — ミントレベル・目撃鮮度・チョコミン党タイプなど、DB 側と境界値を揃える必要があるロジック
- `UITests/` — 5 タブが開くか、商品詳細に遷移できるか、未ログインでログインが要求されるか

`UITests/ScreenshotTests.swift` は各画面のスクリーンショットをテスト結果に添付する。

```bash
xcodebuild ... -only-testing:ChocoMintUITests/ScreenshotTests -resultBundlePath /tmp/r.xcresult test
xcrun xcresulttool export attachments --path /tmp/r.xcresult --output-path /tmp/shots
```

## 管理画面

商品の登録・公開、ユーザー申請の承認、レビュー報告の対応、ニュースの整理を行う。
iOS アプリ側には管理機能を作らない。

```bash
cd admin
cp .env.example .env.local   # 値を埋める
npm install
npm run dev                  # http://localhost:3000
```

ログインは `ADMIN_PASSWORD` による最小限のパスワードゲート。
実運用では Vercel Authentication などの後ろに置くこと。

## 初期データの入れ方

コールドスタートは運営が足で集めたデータで埋める。専用の投入ツールは作らない。

1. 管理画面で商品を登録し、公開にする
2. 現地で iOS アプリの「この商品を見つけた」から目撃報告する

店舗マスタは報告時にオンデマンドで作られるので、事前に用意する必要はない。
運営自身が本番の投稿フローを通ることになるので、リリース前の検証も兼ねる。

## 実装状況

| Phase | 内容 | 状態 |
|---|---|---|
| 1 | 商品 DB / 一覧 / 詳細 / 検索・絞り込み | 実装済み |
| 2 | Sign in with Apple / 食べた / 食べたい | 実装済み |
| 3 | 店舗 / 目撃報告 / MapKit / 店舗詳細 | 実装済み |
| 4 | レビュー投稿・表示・通報・ブロック | 実装済み |
| 5 | ニュース画面 | 実装済み |
| 6 | 図鑑 / プロフィール / ランキング | 実装済み（通知は未実装） |
| — | ニュース・商品候補の収集バッチ（`collectors/`） | 実装済み |

未実装として残しているもの:

- 新商品のプッシュ通知
- 収集バッチの定期実行設定（cron / GitHub Actions などに載せる）

## v1.0 でやらないこと

DM / フォロー / SNS 機能 / コメント返信 / ユーザーランキング / AI おすすめ / AI レビュー要約 /
動画投稿 / レビュー写真投稿 / EC 機能 / 店舗予約。

レビュー写真を許可するとストレージ・モデレーション・権利関係が一気に増えるため、
商品画像は運営管理のみとする。
