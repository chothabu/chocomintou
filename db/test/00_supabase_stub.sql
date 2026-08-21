-- ローカル検証用のスタブ。
--
-- Supabase 本番では auth スキーマと auth.uid() を GoTrue が用意するが、
-- 素の PostgreSQL には無いので、schema.sql を検証できるだけの最小限を作る。
-- 本番には適用しないこと。

-- Supabase が用意するロール（イメージによっては既にある）
do $$
begin
  if not exists (select 1 from pg_roles where rolname = 'anon') then
    create role anon nologin noinherit;
  end if;
  if not exists (select 1 from pg_roles where rolname = 'authenticated') then
    create role authenticated nologin noinherit;
  end if;
  if not exists (select 1 from pg_roles where rolname = 'service_role') then
    create role service_role nologin noinherit bypassrls;
  end if;
end
$$;

create schema if not exists auth;
create schema if not exists extensions;

create table if not exists auth.users (
  id         uuid primary key default gen_random_uuid(),
  email      text,
  created_at timestamptz not null default now()
);

-- 本番の auth.uid() は JWT のクレームから取り出す。
-- テストでは set_config('request.jwt.claim.sub', ...) で差し替えられるようにする。
create or replace function auth.uid()
returns uuid
language sql
stable
as $$
  select nullif(current_setting('request.jwt.claim.sub', true), '')::uuid;
$$;

grant usage on schema auth to anon, authenticated, service_role;
