#!/usr/bin/env bash
# supabase/migrations/20260820000000_init.sql をローカルの PostgreSQL に流して、ロジックまで検証する。
#
#   ./db/verify.sh
#
# Supabase 公式の Postgres イメージを使うので、拡張（PostGIS / pg_trgm）と
# ロール構成は本番に近い。auth スキーマだけ GoTrue が作るものなので stub で補う。
set -euo pipefail

CONTAINER=chocomint-pg-verify
IMAGE=supabase/postgres:15.8.1.060
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

cleanup() {
  docker rm -f "$CONTAINER" >/dev/null 2>&1 || true
}
trap cleanup EXIT

cleanup
echo "▶ PostgreSQL を起動しています…"
docker run -d --name "$CONTAINER" -e POSTGRES_PASSWORD=postgres "$IMAGE" >/dev/null

# 初期化スクリプトの実行中にも pg_isready は通ってしまい、その後サーバーが再起動する。
# 接続が続けて成功することを確かめてから先に進む。
stable=0
for _ in $(seq 1 90); do
  if docker exec "$CONTAINER" psql -U postgres -tAc 'select 1' >/dev/null 2>&1; then
    stable=$((stable + 1))
    [ "$stable" -ge 4 ] && break
  else
    stable=0
  fi
  sleep 2
done
if [ "$stable" -lt 4 ]; then
  echo "PostgreSQL が起動しませんでした" >&2
  exit 1
fi

run() {
  docker exec -i "$CONTAINER" psql -U postgres -v ON_ERROR_STOP=1 -q < "$1"
}

echo "▶ auth スキーマの stub を作成…"
run "$ROOT/db/test/00_supabase_stub.sql"

echo "▶ supabase/migrations/20260820000000_init.sql を適用…"
run "$ROOT/supabase/migrations/20260820000000_init.sql"

echo "▶ ロジックを検証…"
docker exec -i "$CONTAINER" psql -U postgres -v ON_ERROR_STOP=1 < "$ROOT/db/test/99_smoke.sql"
