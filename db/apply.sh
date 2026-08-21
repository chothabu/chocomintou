#!/usr/bin/env bash
# supabase/migrations/20260820000000_init.sql を実際の Supabase プロジェクトに適用する。
#
#   DATABASE_URL='postgresql://postgres.xxxx:PASSWORD@aws-0-....pooler.supabase.com:5432/postgres' \
#     ./db/apply.sh
#
# 接続文字列は Supabase ダッシュボードの Project Settings → Database → Connection string
# （URI / Session pooler）からコピーする。
#
# psql は Docker 経由で動かすので、ローカルにインストールする必要はない。
set -euo pipefail

IMAGE=supabase/postgres:15.8.1.060
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if [ -z "${DATABASE_URL:-}" ]; then
  echo "DATABASE_URL を設定してください（このファイル冒頭のコメント参照）" >&2
  exit 1
fi

echo "▶ 接続を確認しています…"
# パスワードがプロセス一覧に出ないよう、環境変数で渡す。
docker run --rm -e PGURL="$DATABASE_URL" "$IMAGE" \
  bash -c 'psql "$PGURL" -tAc "select current_database()"'

# schema.sql は初回適用専用（冪等ではない）。既に入っている DB に流すと途中で失敗し、
# どこまで適用されたか分からない状態になるので、その前に止める。
already=$(docker run --rm -e PGURL="$DATABASE_URL" "$IMAGE" \
  bash -c 'psql "$PGURL" -tAc "select to_regclass('"'"'public.products'"'"') is not null"' | tr -d '[:space:]')
if [ "$already" = "t" ]; then
  echo "" >&2
  echo "この DB には既にスキーマが適用されています。" >&2
  echo "schema.sql は初回適用専用です。変更を加える場合は差分の SQL を別途書いて流してください。" >&2
  exit 1
fi

echo "▶ supabase/migrations/20260820000000_init.sql を適用しています…"
docker run --rm -i -e PGURL="$DATABASE_URL" "$IMAGE" \
  bash -c 'psql "$PGURL" -v ON_ERROR_STOP=1 -q' < "$ROOT/supabase/migrations/20260820000000_init.sql"

echo "▶ 適用結果:"
docker run --rm -e PGURL="$DATABASE_URL" "$IMAGE" bash -c '
  psql "$PGURL" -tAc "
    select
      (select count(*) from pg_tables where schemaname = '"'"'public'"'"') || '"'"' テーブル, '"'"' ||
      (select count(*) from pg_proc p join pg_namespace n on n.oid = p.pronamespace
        where n.nspname = '"'"'public'"'"') || '"'"' 関数'"'"'"'

echo "完了しました。次は Authentication → Providers で Apple を有効にしてください。"
