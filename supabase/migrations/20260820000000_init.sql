-- チョコミントアプリ スキーマ v1.1 (Supabase / PostgreSQL)
--
-- 設計の中核: products と stores は直接リレーションを持たない。
--             両者をつなぐのは sightings（ユーザーの目撃イベント）だけ。
--             store_products は sightings から導出される集計キャッシュであり、事実ではない。
--
-- 適用: supabase db push / psql で先頭から実行

create extension if not exists postgis with schema extensions;
set search_path = public, extensions;


-- ============================================================
-- ユーザー
-- ============================================================

-- 認証は auth.users（Sign in with Apple）。ここは公開プロフィールのみ。
-- 本名・住所・性別・メールは保持しない。
create table users (
  id           uuid primary key references auth.users (id) on delete cascade,
  display_name text not null check (char_length(display_name) between 1 and 30),
  is_suspended boolean not null default false,
  created_at   timestamptz not null default now()
);


-- ============================================================
-- 商品（店舗情報を一切持たない）
-- ============================================================

create table products (
  id                 uuid primary key default gen_random_uuid(),
  name               text not null,
  manufacturer       text,
  description        text,

  category           text not null
                     check (category in ('ice','snack','cake','parfait','drink','bread','other')),
  image_url          text,
  price              integer check (price >= 0),          -- null = 価格不明（UI 非表示）

  release_date       date,
  end_date           date,                                -- 販売終了予定
  sale_status        text not null default 'on_sale'
                     check (sale_status in ('on_sale','upcoming','ended')),
  is_limited         boolean not null default false,      -- 期間限定 / 通年

  -- メーカー公式告知に基づく表示用テキスト。実在店舗とは結合しない。
  -- 例: 「全国のファミリーマート」
  sales_channel_text text,
  official_url       text,

  is_published       boolean not null default false,      -- 運営承認フラグ

  -- レビュー集計の非正規化。reviews のトリガで更新する（後述）。
  -- アプリは商品一覧を 1 クエリで取れる必要があるため、ビューではなく列として持つ。
  review_count       integer not null default 0,
  avg_overall        numeric(3,2),
  avg_mint           numeric(3,2),
  avg_chocolate      numeric(3,2),
  avg_sweetness      numeric(3,2),
  avg_freshness      numeric(3,2),
  mint_level         smallint check (mint_level between 1 and 5),

  created_at         timestamptz not null default now(),
  updated_at         timestamptz not null default now()
);

create index products_published_idx on products (is_published, sale_status);
create index products_release_idx   on products (release_date desc);
-- 商品名 / メーカーの部分一致検索用（日本語は形態素解析なしのため trigram を使う）
create extension if not exists pg_trgm with schema extensions;
create index products_name_trgm_idx on products using gin (name extensions.gin_trgm_ops);


-- 商品 × 販売チェーン。
-- 主用途は検索フィルタの「チェーン」絞り込み。
-- マップの候補ピン（v1.1 以降）の材料にもなる。
create table product_channels (
  id         uuid primary key default gen_random_uuid(),
  product_id uuid not null references products (id) on delete cascade,
  chain_name text not null,          -- stores.chain_name と同じ語彙を使う
  area       text,                   -- null = 全国
  unique (product_id, chain_name, area)
);

create index product_channels_chain_idx on product_channels (chain_name);


-- ============================================================
-- 店舗（商品情報を一切持たない）
-- ============================================================

-- コンビニも個人経営のカフェも同じテーブルに入れる。
-- 事前に全国分を用意せず、目撃報告フローの中で必要になった店舗だけを登録する。
create table stores (
  id                uuid primary key default gen_random_uuid(),
  name              text not null,
  chain_name        text,            -- 正規化済み。個人店は null
                                     -- 正準値: seven_eleven / familymart / lawson /
                                     --         ministop / daily_yamazaki / seicomart / other

  latitude          double precision not null check (latitude between -90 and 90),
  longitude         double precision not null check (longitude between -180 and 180),
  geog              extensions.geography(Point, 4326)
                    generated always as
                    (extensions.st_setsrid(extensions.st_makepoint(longitude, latitude), 4326)::extensions.geography)
                    stored,
  address           text,

  -- 後からソースを差し替え・重複統合できるよう必ず記録する
  external_source   text not null default 'user'
                    check (external_source in ('mapkit','osm','gnavi','user','admin')),
  external_store_id text,

  created_at        timestamptz not null default now(),
  unique (external_source, external_store_id)
);

create index stores_geog_idx  on stores using gist (geog);
create index stores_chain_idx on stores (chain_name);


-- ============================================================
-- 目撃情報（このアプリの中核。追記のみのイベントログ）
-- ============================================================

create table sightings (
  id          uuid primary key default gen_random_uuid(),
  product_id  uuid not null references products (id) on delete cascade,
  store_id    uuid not null references stores (id)   on delete cascade,
  user_id     uuid not null references users (id)    on delete cascade,

  found_at    timestamptz not null default now(),
  is_official boolean not null default false,   -- 運営によるシード投入
  is_deleted  boolean not null default false,   -- 取り消し / 運営削除（物理削除はしない）
  created_at  timestamptz not null default now()
);

create index sightings_pair_idx on sightings (store_id, product_id) where not is_deleted;
create index sightings_user_idx on sightings (user_id, created_at desc);

-- 連投による水増し防止: 同一 (user, product, store) は 1 日 1 件。
-- timezone(text, timestamptz) は IMMUTABLE なのでインデックス式に使える。
-- （found_at::date は TimeZone GUC に依存する STABLE なので式インデックスには使えない）
create unique index sightings_one_per_day_idx
  on sightings (user_id, product_id, store_id, ((timezone('Asia/Tokyo', found_at))::date))
  where not is_deleted;


-- ============================================================
-- 集計キャッシュ（sightings から再構築可能な導出データ）
-- ============================================================

create table store_products (
  store_id            uuid not null references stores (id)   on delete cascade,
  product_id          uuid not null references products (id) on delete cascade,
  first_seen_at       timestamptz not null,
  last_seen_at        timestamptz not null,
  sighting_count      integer not null,
  distinct_user_count integer not null,
  primary key (store_id, product_id)
);

create index store_products_fresh_idx   on store_products (last_seen_at desc);
create index store_products_product_idx on store_products (product_id, last_seen_at desc);


-- 該当ペアを sightings から丸ごと再計算する。
-- insert / 論理削除 / 復活 のすべてを同じ経路で正しく扱えるようにするため、
-- 差分更新ではなく delete + 再集計にしている。
create or replace function sync_store_product()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_store   uuid := coalesce(new.store_id,   old.store_id);
  v_product uuid := coalesce(new.product_id, old.product_id);
begin
  delete from store_products
   where store_id = v_store and product_id = v_product;

  insert into store_products
    (store_id, product_id, first_seen_at, last_seen_at, sighting_count, distinct_user_count)
  select v_store, v_product, min(found_at), max(found_at), count(*), count(distinct user_id)
    from sightings
   where store_id = v_store and product_id = v_product and not is_deleted
  having count(*) > 0;

  return null;
end;
$$;

create trigger sightings_sync_store_product
  after insert or update or delete on sightings
  for each row execute function sync_store_product();


-- 集計が壊れたときの全件再構築。運用で手動実行する。
create or replace function rebuild_store_products()
returns void
language sql
security definer
set search_path = public
as $$
  delete from store_products;
  insert into store_products
    (store_id, product_id, first_seen_at, last_seen_at, sighting_count, distinct_user_count)
  select store_id, product_id, min(found_at), max(found_at), count(*), count(distinct user_id)
    from sightings
   where not is_deleted
   group by store_id, product_id;
$$;


-- 鮮度判定。「在庫あり」ではなく「見つかりました」表現に統一するための区分。
create or replace function sighting_freshness(p_last_seen_at timestamptz)
returns text
language sql
stable                                   -- now() を参照するため immutable にはできない
as $$
  select case
    when p_last_seen_at is null                       then 'none'    -- 情報なし
    when p_last_seen_at > now() - interval '1 day'    then 'today'   -- 🟢 今日見つかっています
    when p_last_seen_at > now() - interval '7 days'   then 'recent'  -- 🟡 最近見つかっています
    when p_last_seen_at > now() - interval '30 days'  then 'past'    -- ⚪ 過去に見つかっています
    else 'stale'                                                     -- 非表示
  end;
$$;


-- ============================================================
-- レビュー
-- ============================================================

create table reviews (
  id                   uuid primary key default gen_random_uuid(),
  user_id              uuid not null references users (id)    on delete cascade,
  product_id           uuid not null references products (id) on delete cascade,

  overall_rating       smallint not null check (overall_rating between 1 and 5),
  -- 以下は任意入力
  mint_intensity       smallint check (mint_intensity       between 1 and 5),
  chocolate_intensity  smallint check (chocolate_intensity  between 1 and 5),
  sweetness            smallint check (sweetness            between 1 and 5),
  freshness            smallint check (freshness            between 1 and 5),

  comment              text check (char_length(comment) <= 500),
  helpful_count        integer not null default 0,
  is_hidden            boolean not null default false,   -- 運営による非表示

  created_at           timestamptz not null default now(),
  updated_at           timestamptz not null default now(),
  unique (user_id, product_id)                           -- 1 商品 1 レビュー
);

create index reviews_product_idx on reviews (product_id, created_at desc) where not is_hidden;
create index reviews_helpful_idx on reviews (product_id, helpful_count desc) where not is_hidden;

-- 「参考になった」の二重投票防止
create table review_helpfuls (
  review_id  uuid not null references reviews (id) on delete cascade,
  user_id    uuid not null references users (id)   on delete cascade,
  created_at timestamptz not null default now(),
  primary key (review_id, user_id)
);


-- レビュー集計を products に反映する。
-- ミントレベル (Lv1〜Lv5) は mint_intensity の平均から算出する。
create or replace function sync_product_stats()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_product uuid := coalesce(new.product_id, old.product_id);
  v_mint    numeric;
begin
  select avg(mint_intensity) into v_mint
    from reviews where product_id = v_product and not is_hidden;

  update products p set
    review_count  = (select count(*) from reviews where product_id = v_product and not is_hidden),
    avg_overall   = (select avg(overall_rating)      from reviews where product_id = v_product and not is_hidden),
    avg_mint      = v_mint,
    avg_chocolate = (select avg(chocolate_intensity) from reviews where product_id = v_product and not is_hidden),
    avg_sweetness = (select avg(sweetness)           from reviews where product_id = v_product and not is_hidden),
    avg_freshness = (select avg(freshness)           from reviews where product_id = v_product and not is_hidden),
    mint_level    = case
                      when v_mint is null then null
                      when v_mint < 1.5 then 1
                      when v_mint < 2.5 then 2
                      when v_mint < 3.5 then 3
                      when v_mint < 4.5 then 4
                      else 5
                    end,
    updated_at    = now()
  where p.id = v_product;

  return null;
end;
$$;

create trigger reviews_sync_product_stats
  after insert or update or delete on reviews
  for each row execute function sync_product_stats();


-- 「参考になった」数の同期
create or replace function sync_review_helpful_count()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_review uuid := coalesce(new.review_id, old.review_id);
begin
  update reviews set helpful_count = (select count(*) from review_helpfuls where review_id = v_review)
   where id = v_review;
  return null;
end;
$$;

create trigger review_helpfuls_sync_count
  after insert or delete on review_helpfuls
  for each row execute function sync_review_helpful_count();


-- ============================================================
-- ユーザー行動
-- ============================================================

create table tasted_products (
  user_id      uuid not null references users (id)    on delete cascade,
  product_id   uuid not null references products (id) on delete cascade,
  tasted_at    timestamptz not null default now(),    -- 初回。図鑑の年別分類に使う
  tasted_count integer not null default 1,            -- 複数回食べても図鑑は 1 カウント
  primary key (user_id, product_id)
);

create table wishlists (
  user_id    uuid not null references users (id)    on delete cascade,
  product_id uuid not null references products (id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (user_id, product_id)
);


-- ============================================================
-- UGC モデレーション (App Review Guideline 1.2)
-- ============================================================

create table review_reports (
  id          uuid primary key default gen_random_uuid(),
  review_id   uuid not null references reviews (id) on delete cascade,
  reporter_id uuid not null references users (id)   on delete cascade,
  reason      text not null
              check (reason in ('spam','offensive','irrelevant','false_info','other')),
  detail      text check (char_length(detail) <= 500),
  status      text not null default 'pending'
              check (status in ('pending','actioned','dismissed')),
  created_at  timestamptz not null default now(),
  unique (review_id, reporter_id)
);

create table blocked_users (
  blocker_id uuid not null references users (id) on delete cascade,
  blocked_id uuid not null references users (id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (blocker_id, blocked_id),
  check (blocker_id <> blocked_id)
);


-- ============================================================
-- ニュース / ユーザー投稿
-- ============================================================

-- 記事の収集元フィード。運営が管理画面から登録し、有効にしたものだけ巡回する。
--
-- どのフィードを使うかは、そのフィードの利用条件を確認したうえで運営が決める。
-- ここをハードコードしないのは、条件が変わったときにコードを触らず止められるようにするため。
-- （Google News RSS はフィード自身が個人の非商用利用以外を明示的に禁止しているので使えない）
create table news_sources (
  id           uuid primary key default gen_random_uuid(),
  name         text not null,
  feed_url     text not null unique,
  is_enabled   boolean not null default false,
  last_fetched_at timestamptz,
  last_error   text,
  created_at   timestamptz not null default now()
);


-- 本文は保存しない。カードをタップしたら SFSafariViewController で元記事を開く。
-- 収集はバックエンドのバッチのみ（iPhone から外部サイトを直接叩かない）。
create table news_articles (
  id            uuid primary key default gen_random_uuid(),
  title         text not null,
  source_name   text,
  article_url   text not null unique,
  thumbnail_url text,
  published_at  timestamptz not null,
  is_hidden     boolean not null default false,
  source_id     uuid references news_sources (id) on delete set null,
  created_at    timestamptz not null default now()
);

create index news_published_idx on news_articles (published_at desc) where not is_hidden;


-- 商品の候補。運営が承認すると products へ昇格する。
--
-- 出所は 2 つある。ユーザーからの報告（設計 §30）と、外部サービスから機械的に集めた候補（§26）。
-- どちらも「候補 → 運営確認 → 公開」という同じ流れを通るので 1 つのテーブルで扱う。
create table product_submissions (
  id             uuid primary key default gen_random_uuid(),
  -- 機械的に集めた候補には投稿者がいないので null 可。
  user_id        uuid references users (id) on delete cascade,
  source         text not null default 'user'
                 check (source in ('user','rakuten','admin')),
  -- 外部サービス側の ID。同じ商品を何度も取り込まないための鍵。
  external_id    text,
  external_url   text,
  image_url      text,

  name           text not null,
  manufacturer   text,
  category       text,
  price          integer,
  release_date   date,
  purchase_place text,
  note           text,
  status         text not null default 'pending'
                 check (status in ('pending','approved','rejected')),
  product_id     uuid references products (id) on delete set null,  -- 承認後の紐付け
  created_at     timestamptz not null default now(),

  -- ユーザー投稿には投稿者が必要
  constraint product_submissions_user_required
    check (source <> 'user' or user_id is not null),
  unique (source, external_id)
);

create index product_submissions_status_idx on product_submissions (status, created_at desc);


-- ============================================================
-- 近隣検索
-- ============================================================

-- マップ・商品詳細の「近くで見つかっています」用。
-- v1.0 では目撃実績のある店舗だけを返す（候補ピンは出さない）。
create or replace function stores_nearby(
  p_lat          double precision,
  p_lng          double precision,
  p_radius_m     integer default 3000,
  p_product_id   uuid    default null,
  p_fresh_days   integer default 30,
  p_on_sale_only boolean default false
)
returns table (
  store_id      uuid,
  store_name    text,
  chain_name    text,
  latitude      double precision,
  longitude     double precision,
  distance_m    double precision,
  product_id    uuid,
  product_name  text,
  image_url     text,
  last_seen_at  timestamptz,
  freshness     text
)
language sql
stable
set search_path = public, extensions
as $$
  with origin as (
    select extensions.st_setsrid(extensions.st_makepoint(p_lng, p_lat), 4326)::extensions.geography as g
  )
  select s.id, s.name, s.chain_name, s.latitude, s.longitude,
         extensions.st_distance(s.geog, o.g) as distance_m,
         p.id, p.name, p.image_url,
         sp.last_seen_at,
         sighting_freshness(sp.last_seen_at)
    from store_products sp
    join stores   s on s.id = sp.store_id
    join products p on p.id = sp.product_id
   cross join origin o
   where extensions.st_dwithin(s.geog, o.g, p_radius_m)
     and sp.last_seen_at > now() - make_interval(days => p_fresh_days)
     and p.is_published
     and p.sale_status <> 'ended'
     and (not p_on_sale_only or p.sale_status = 'on_sale')
     and (p_product_id is null or p.id = p_product_id)
   order by distance_m;
$$;


-- ============================================================
-- RPC
-- ============================================================

-- 人気ランキング。直近 N 日のレビューだけを対象にする（デフォルト 30 日）。
-- 非正規化列 avg_overall は全期間の平均なので、期間指定のランキングには使えない。
create or replace function products_ranking(
  p_days      integer default 30,
  p_min_count integer default 3,
  p_limit     integer default 20
)
returns setof products
language sql
stable
set search_path = public
as $$
  select p.*
    from products p
    join (
      select product_id, avg(overall_rating) as a, count(*) as c
        from reviews
       where not is_hidden
         and created_at > now() - make_interval(days => p_days)
       group by product_id
      having count(*) >= p_min_count
    ) r on r.product_id = p.id
   where p.is_published
   order by r.a desc, r.c desc
   limit p_limit;
$$;


-- 目撃報告。店舗の登録と目撃の記録を 1 トランザクションで行う。
-- アプリから stores の insert → sightings の insert と 2 回に分けると、
-- 途中で失敗したときに「商品の紐付いていない店舗」がゴミとして残るため RPC にまとめる。
--
-- 戻り値が null = 同一店舗・同一商品を今日すでに報告済み（1 日 1 件制限）。
create or replace function report_sighting(
  p_product_id        uuid,
  p_store_name        text,
  p_latitude          double precision,
  p_longitude         double precision,
  p_address           text default null,
  p_chain_name        text default null,
  p_external_source   text default 'mapkit',
  p_external_store_id text default null
)
returns uuid
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_user  uuid := auth.uid();
  v_store uuid;
  v_id    uuid;
  v_point extensions.geography := extensions.st_setsrid(
            extensions.st_makepoint(p_longitude, p_latitude), 4326)::extensions.geography;
begin
  if v_user is null then
    raise exception 'authentication required' using errcode = '42501';
  end if;

  -- 1. 外部 ID が一致する店舗
  if p_external_store_id is not null then
    select id into v_store from stores
     where external_source = p_external_source
       and external_store_id = p_external_store_id;
  end if;

  -- 2. 外部 ID が無い / 一致しない場合は、同名かつ 50m 以内の既存店舗を再利用する。
  --    情報源が違っても同じ店は 1 レコードにまとめたいため。
  if v_store is null then
    select id into v_store from stores
     where name = p_store_name
       and extensions.st_dwithin(geog, v_point, 50)
     limit 1;
  end if;

  -- 3. それでも無ければ新規登録（オンデマンド生成）
  if v_store is null then
    insert into stores (name, chain_name, latitude, longitude, address,
                        external_source, external_store_id)
    values (p_store_name, p_chain_name, p_latitude, p_longitude, p_address,
            p_external_source, p_external_store_id)
    returning id into v_store;
  end if;

  insert into sightings (product_id, store_id, user_id)
  values (p_product_id, v_store, v_user)
  on conflict do nothing            -- 1 日 1 件の部分 UNIQUE インデックスに当たる
  returning id into v_id;

  return v_id;
end;
$$;


-- ユーザーの味覚傾向（チョコミン党プロフィール）。判定自体はアプリ側のルールで行う。
create or replace function user_taste_stats(p_user_id uuid)
returns table (
  review_count  bigint,
  tasted_count  bigint,
  avg_mint      numeric,
  avg_chocolate numeric,
  avg_sweetness numeric,
  avg_freshness numeric,
  avg_overall   numeric
)
language sql
stable
set search_path = public
as $$
  select (select count(*) from reviews where user_id = p_user_id and not is_hidden),
         (select count(*) from tasted_products where user_id = p_user_id),
         avg(r.mint_intensity), avg(r.chocolate_intensity),
         avg(r.sweetness), avg(r.freshness), avg(r.overall_rating)
    from reviews r
   where r.user_id = p_user_id and not r.is_hidden;
$$;


-- アカウント削除（App Store の要件）。
-- anon key では auth スキーマを触れないため、所有者権限で実行する関数を用意する。
-- auth.users を消せば public.users 以下は ON DELETE CASCADE で連鎖削除される。
create or replace function delete_own_account()
returns void
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  v_user uuid := auth.uid();
begin
  if v_user is null then
    raise exception 'authentication required' using errcode = '42501';
  end if;
  delete from auth.users where id = v_user;
end;
$$;

revoke all on function delete_own_account() from public;
grant execute on function delete_own_account() to authenticated;


-- 図鑑の進捗。発売年ごとの「食べた数 / 公開されている商品数」。
create or replace function collection_progress(p_user_id uuid)
returns table (year integer, tasted_count bigint, total_count bigint)
language sql
stable
set search_path = public
as $$
  select extract(year from p.release_date)::integer as year,
         count(*) filter (where t.user_id is not null) as tasted_count,
         count(*) as total_count
    from products p
    left join tasted_products t on t.product_id = p.id and t.user_id = p_user_id
   where p.is_published and p.release_date is not null
   group by 1
   order by 1 desc;
$$;


-- ============================================================
-- RLS
-- ============================================================
-- 閲覧はログイン不要。書き込みは本人のみ。
-- 運営操作（商品の作成・公開、レビュー非表示、ユーザー停止）は service_role 経由の
-- Web 管理画面から行うため、ここではポリシーを与えない。

alter table users               enable row level security;
alter table products            enable row level security;
alter table product_channels    enable row level security;
alter table stores              enable row level security;
alter table sightings           enable row level security;
alter table store_products      enable row level security;
alter table reviews             enable row level security;
alter table review_helpfuls     enable row level security;
alter table tasted_products     enable row level security;
alter table wishlists           enable row level security;
alter table review_reports      enable row level security;
alter table blocked_users       enable row level security;
alter table news_articles       enable row level security;
alter table product_submissions enable row level security;
-- news_sources はポリシーを一切与えない = 運営（service_role）以外は読み書きできない。
alter table news_sources        enable row level security;

-- 公開読み取り
create policy read_all  on users            for select using (true);
create policy read_pub  on products         for select using (is_published);
create policy read_all  on product_channels for select using (true);
create policy read_all  on stores           for select using (true);
create policy read_all  on store_products   for select using (true);
create policy read_live on sightings        for select using (not is_deleted);
create policy read_live on reviews          for select using (not is_hidden);
create policy read_all  on review_helpfuls  for select using (true);
create policy read_live on news_articles    for select using (not is_hidden);

-- 本人のみ書き込み
-- 初回サインイン時に自分のプロフィール行を作るため INSERT も要る。
create policy own_create   on users        for insert with check (auth.uid() = id);
create policy own_profile  on users        for update using (auth.uid() = id)
                                           with check (auth.uid() = id);

create policy own_insert   on stores       for insert with check (auth.uid() is not null);

create policy own_insert   on sightings    for insert with check (auth.uid() = user_id);
-- 取り消し（is_deleted）だけを想定。他人の報告は触れない。
create policy own_update   on sightings    for update using (auth.uid() = user_id)
                                           with check (auth.uid() = user_id);

create policy own_write    on reviews      for all using (auth.uid() = user_id)
                                           with check (auth.uid() = user_id);
create policy own_write    on review_helpfuls for all using (auth.uid() = user_id)
                                           with check (auth.uid() = user_id);
create policy own_write    on tasted_products for all using (auth.uid() = user_id)
                                           with check (auth.uid() = user_id);
create policy own_write    on wishlists    for all using (auth.uid() = user_id)
                                           with check (auth.uid() = user_id);
create policy own_write    on blocked_users for all using (auth.uid() = blocker_id)
                                           with check (auth.uid() = blocker_id);

create policy own_insert   on review_reports for insert with check (auth.uid() = reporter_id);
create policy own_read     on review_reports for select using (auth.uid() = reporter_id);

create policy own_insert   on product_submissions for insert with check (auth.uid() = user_id);
create policy own_read     on product_submissions for select using (auth.uid() = user_id);

-- ブロックしたユーザーのレビュー非表示は RLS ではなくクエリ側で行う。
-- RLS に入れると全レビュー参照に毎回 blocked_users の相関サブクエリが乗るため。


-- ============================================================
-- 権限
-- ============================================================
-- Supabase は public スキーマに対する anon / authenticated の権限を自動で付与するが、
-- 「どのロールが何を触れるか」を明示しておく。実際の行単位の制御は上の RLS が行う。

grant usage on schema public to anon, authenticated, service_role;

-- 運営ツール（Web 管理画面・収集バッチ）は service_role で動く。
-- このロールは RLS を素通りするが、テーブルへの権限は別に必要で、
-- 付け忘れると管理画面の全操作が "permission denied" で落ちる。
grant all privileges on all tables    in schema public to service_role;
grant all privileges on all sequences in schema public to service_role;
grant execute        on all functions in schema public to service_role;

-- 誰でも読めるもの（見える行は RLS が絞る）
grant select on
  users, products, product_channels, stores, store_products,
  sightings, reviews, review_helpfuls, news_articles
  to anon, authenticated;

-- 本人だけが読めるもの。anon には渡さない。
grant select on
  tasted_products, wishlists, blocked_users, review_reports, product_submissions
  to authenticated;

-- 書き込み。
-- アプリは重複登録を避けるため UPSERT を使う箇所が多く、UPSERT は INSERT だけでなく
-- UPDATE 権限も要る。付け忘れると「2 回目の操作だけ失敗する」形で表面化する。
grant insert, update         on users             to authenticated;
grant insert, update         on sightings         to authenticated;
grant insert, update, delete on reviews           to authenticated;
grant insert, update, delete on review_helpfuls   to authenticated;
grant insert, update         on review_reports    to authenticated;
grant insert, update, delete on tasted_products   to authenticated;
grant insert, update, delete on wishlists         to authenticated;
grant insert, update, delete on blocked_users     to authenticated;
grant insert                 on product_submissions to authenticated;
-- 目撃報告フローで新しい店舗が登録されるため
grant insert on stores to authenticated;

-- クライアントから呼ぶ RPC のみ実行を許可する。
-- sync_* / rebuild_* はトリガーと運用専用なので渡さない。
grant execute on function sighting_freshness(timestamptz) to anon, authenticated;
grant execute on function stores_nearby(double precision, double precision, integer, uuid, integer, boolean)
  to anon, authenticated;
grant execute on function products_ranking(integer, integer, integer) to anon, authenticated;
grant execute on function user_taste_stats(uuid) to authenticated;
grant execute on function collection_progress(uuid) to authenticated;
grant execute on function report_sighting(uuid, text, double precision, double precision, text, text, text, text)
  to authenticated;
