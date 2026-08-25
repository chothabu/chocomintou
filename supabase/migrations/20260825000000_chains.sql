-- チェーンを独立したテーブルにする。
--
-- これまで product_channels に chain_name をテキストで持たせていたが、
-- 「店内で食べられるか」「ブランド色」といったチェーン自身の属性を置く場所が無かった。
--
-- 店内飲食できるかを持つのは、アプリの「店舗」タブがそこで食べられる店を
-- 並べる場所だから（小売チェーンは商品タブで足りる）。

create table chains (
  name        text primary key,
  -- 店内で飲食できるか。カフェ・ファストフード・アイスパーラーなど。
  is_eat_in   boolean not null default false,
  official_url text,
  -- ロゴは商標なので持たない。頭文字を並べるときの背景色だけを持つ（#RRGGBB）。
  brand_color text check (brand_color is null or brand_color ~ '^#[0-9A-Fa-f]{6}$'),
  created_at  timestamptz not null default now()
);

comment on table chains is
  'チョコミントを扱うチェーン。ロゴ画像は商標のため保持せず、色と名前だけを持つ。';

alter table chains enable row level security;
create policy read_all on chains for select using (true);
grant select on chains to anon, authenticated;
grant all privileges on chains to service_role;

-- 既に product_channels にあるチェーンを取り込む
insert into chains (name)
select distinct chain_name from product_channels
on conflict (name) do nothing;
