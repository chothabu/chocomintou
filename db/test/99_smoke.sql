-- schema.sql のロジック検証。
-- トリガーによる集計、目撃報告 RPC、鮮度判定、RLS を実際に動かして確かめる。
-- 失敗すると ASSERT が例外を投げてスクリプトが止まる。

\set ON_ERROR_STOP on

-- ------------------------------------------------------------
-- 準備
-- ------------------------------------------------------------

insert into auth.users (id) values
  ('00000000-0000-0000-0000-000000000901'),
  ('00000000-0000-0000-0000-000000000902');

insert into users (id, display_name) values
  ('00000000-0000-0000-0000-000000000901', 'テスト太郎'),
  ('00000000-0000-0000-0000-000000000902', 'テスト花子');

insert into products (id, name, manufacturer, category, price, release_date, sale_status, is_published)
values
  ('00000000-0000-0000-0000-000000000001', '極ミントアイスバー', '氷菓ラボ', 'ice', 238,
   current_date - 10, 'on_sale', true),
  ('00000000-0000-0000-0000-000000000002', '未公開のチョコミント', 'テスト', 'snack', 100,
   current_date - 5, 'on_sale', false);

insert into product_channels (product_id, chain_name)
values ('00000000-0000-0000-0000-000000000001', 'familymart');

\echo '=== 1. 目撃報告 RPC（店舗のオンデマンド生成） ==='

select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000901', false);

do $$
declare
  v_sighting uuid;
begin
  v_sighting := report_sighting(
    '00000000-0000-0000-0000-000000000001',
    'ファミリーマート 渋谷神南店',
    35.6620, 139.6990,
    '東京都渋谷区神南', 'familymart', 'mapkit', 'store-a'
  );
  assert v_sighting is not null, '目撃を記録できていない';
  assert (select count(*) from stores) = 1, '店舗が 1 件生成されていない';
  assert (select count(*) from sightings where not is_deleted) = 1, '目撃が 1 件でない';
  assert (select sighting_count from store_products) = 1, 'store_products の集計が合わない';
  assert (select distinct_user_count from store_products) = 1, '報告者数が合わない';
end
$$;

\echo '=== 2. 同じ日の重複報告は弾かれる ==='

do $$
declare
  v_sighting uuid;
begin
  v_sighting := report_sighting(
    '00000000-0000-0000-0000-000000000001',
    'ファミリーマート 渋谷神南店',
    35.6620, 139.6990, null, 'familymart', 'mapkit', 'store-a'
  );
  assert v_sighting is null, '1 日 1 件の制限が効いていない';
  assert (select count(*) from sightings where not is_deleted) = 1, '目撃が増えてしまった';
end
$$;

\echo '=== 3. 別ユーザーの報告は店舗を再利用して加算される ==='

select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000902', false);

do $$
declare
  v_sighting uuid;
begin
  -- 外部 ID が違っても、同名かつ 50m 以内なら同じ店舗として扱う
  v_sighting := report_sighting(
    '00000000-0000-0000-0000-000000000001',
    'ファミリーマート 渋谷神南店',
    35.66205, 139.69903, null, 'familymart', 'osm', 'other-source-id'
  );
  assert v_sighting is not null, '2 人目の報告が記録されていない';
  assert (select count(*) from stores) = 1,
    format('店舗が重複して作られた: %s件', (select count(*) from stores));
  assert (select sighting_count from store_products) = 2, '目撃数が加算されていない';
  assert (select distinct_user_count from store_products) = 2, '報告者数が加算されていない';
end
$$;

\echo '=== 4. 目撃の論理削除で集計が戻る ==='

do $$
begin
  update sightings set is_deleted = true
   where user_id = '00000000-0000-0000-0000-000000000902';
  assert (select sighting_count from store_products) = 1, '論理削除が集計に反映されていない';
  assert (select distinct_user_count from store_products) = 1, '報告者数が戻っていない';

  update sightings set is_deleted = false
   where user_id = '00000000-0000-0000-0000-000000000902';
  assert (select sighting_count from store_products) = 2, '復活が集計に反映されていない';
end
$$;

\echo '=== 5. レビューの集計とミントレベル ==='

do $$
declare
  v_product products%rowtype;
begin
  insert into reviews (user_id, product_id, overall_rating, mint_intensity, chocolate_intensity,
                       sweetness, freshness, comment)
  values ('00000000-0000-0000-0000-000000000901', '00000000-0000-0000-0000-000000000001',
          5, 5, 3, 4, 5, 'かなりミント強い');

  select * into v_product from products where id = '00000000-0000-0000-0000-000000000001';
  assert v_product.review_count = 1, 'レビュー数が反映されていない';
  assert v_product.avg_mint = 5.00, format('ミント平均が違う: %s', v_product.avg_mint);
  assert v_product.mint_level = 5, format('ミントレベルが違う: %s', v_product.mint_level);

  -- 2 件目でミント平均が 3.5 → Lv4 に下がる
  insert into reviews (user_id, product_id, overall_rating, mint_intensity)
  values ('00000000-0000-0000-0000-000000000902', '00000000-0000-0000-0000-000000000001', 3, 2);

  select * into v_product from products where id = '00000000-0000-0000-0000-000000000001';
  assert v_product.review_count = 2, 'レビュー数が 2 になっていない';
  assert v_product.avg_mint = 3.50, format('ミント平均が違う: %s', v_product.avg_mint);
  assert v_product.mint_level = 4, format('境界値 3.5 は Lv4 のはず: %s', v_product.mint_level);
  assert v_product.avg_overall = 4.00, format('総合平均が違う: %s', v_product.avg_overall);

  -- 非表示にしたレビューは集計から外れる
  update reviews set is_hidden = true where user_id = '00000000-0000-0000-0000-000000000902';
  select * into v_product from products where id = '00000000-0000-0000-0000-000000000001';
  assert v_product.review_count = 1, '非表示レビューが集計に残っている';
  assert v_product.mint_level = 5, '非表示反映後のミントレベルが違う';
  update reviews set is_hidden = false where user_id = '00000000-0000-0000-0000-000000000902';
end
$$;

\echo '=== 6. 参考になった数 ==='

do $$
declare
  v_review uuid;
begin
  select id into v_review from reviews where user_id = '00000000-0000-0000-0000-000000000901';
  insert into review_helpfuls (review_id, user_id)
  values (v_review, '00000000-0000-0000-0000-000000000902');
  assert (select helpful_count from reviews where id = v_review) = 1, '参考になった数が増えない';

  delete from review_helpfuls where review_id = v_review;
  assert (select helpful_count from reviews where id = v_review) = 0, '参考になった数が減らない';
end
$$;

\echo '=== 7. 鮮度判定の境界値 ==='

do $$
begin
  assert sighting_freshness(now() - interval '1 hour') = 'today', '24 時間以内は today';
  assert sighting_freshness(now() - interval '25 hours') = 'recent', '1〜7 日は recent';
  assert sighting_freshness(now() - interval '10 days') = 'past', '8〜30 日は past';
  assert sighting_freshness(now() - interval '40 days') = 'stale', '30 日超は stale';
  assert sighting_freshness(null) = 'none', 'null は none';
end
$$;

\echo '=== 8. 近隣検索 ==='

do $$
declare
  v_row record;
begin
  select * into v_row
    from stores_nearby(35.6595, 139.7005, 3000, null, 30, false);
  assert found, '近隣検索が 1 件も返さない';
  assert v_row.freshness = 'today', format('鮮度が today でない: %s', v_row.freshness);
  assert v_row.distance_m between 100 and 1000,
    format('距離の計算がおかしい: %s m', round(v_row.distance_m));

  -- 未公開商品は出さない
  assert (select count(*) from stores_nearby(35.6595, 139.7005, 3000,
            '00000000-0000-0000-0000-000000000002', 30, false)) = 0,
    '未公開商品が近隣検索に出ている';

  -- 30 日より古い目撃は落とす
  update sightings set found_at = now() - interval '40 days';
  assert (select count(*) from stores_nearby(35.6595, 139.7005, 3000, null, 30, false)) = 0,
    '30 日を超えた目撃が表示されている';
  update sightings set found_at = now();
end
$$;

\echo '=== 9. ランキングと集計 RPC ==='

do $$
declare
  v_stats record;
  v_progress record;
begin
  assert (select count(*) from products_ranking(30, 1, 20)) = 1, 'ランキングが返らない';
  assert (select count(*) from products_ranking(30, 5, 20)) = 0,
    'レビュー件数の下限が効いていない';

  insert into tasted_products (user_id, product_id)
  values ('00000000-0000-0000-0000-000000000901', '00000000-0000-0000-0000-000000000001');

  select * into v_stats from user_taste_stats('00000000-0000-0000-0000-000000000901');
  assert v_stats.review_count = 1, 'レビュー数が違う';
  assert v_stats.tasted_count = 1, '食べた数が違う';
  assert v_stats.avg_mint = 5.0, format('ミント平均が違う: %s', v_stats.avg_mint);

  select * into v_progress
    from collection_progress('00000000-0000-0000-0000-000000000901')
   where year = extract(year from current_date)::integer;
  assert v_progress.tasted_count = 1, '図鑑の取得数が違う';
  assert v_progress.total_count = 1, '図鑑の総数に未公開商品が混ざっている';
end
$$;

\echo '=== 10. 集計キャッシュの再構築 ==='

do $$
begin
  delete from store_products;
  perform rebuild_store_products();
  assert (select count(*) from store_products) = 1, '再構築で行が戻らない';
  assert (select sighting_count from store_products) = 2, '再構築後の件数が合わない';
end
$$;

\echo '=== 11. RLS: 未ログイン（anon） ==='

select set_config('request.jwt.claim.sub', '', false);
set role anon;

do $$
begin
  -- 公開商品だけ見える
  assert (select count(*) from products) = 1,
    format('anon に見える商品数が違う: %s', (select count(*) from products));
  -- 目撃情報は読めるが書けない
  assert (select count(*) from sightings) = 2, 'anon が目撃情報を読めない';
end
$$;

do $$
begin
  begin
    insert into sightings (product_id, store_id, user_id)
    values ('00000000-0000-0000-0000-000000000001',
            (select id from stores limit 1),
            '00000000-0000-0000-0000-000000000901');
    raise exception 'anon が目撃を投稿できてしまった';
  exception
    when insufficient_privilege then null;  -- 期待どおり拒否された
  end;
end
$$;

reset role;

\echo '=== 12. RLS: ログイン中は本人の行だけ書ける ==='

select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000901', false);
set role authenticated;

do $$
begin
  insert into wishlists (user_id, product_id)
  values ('00000000-0000-0000-0000-000000000901', '00000000-0000-0000-0000-000000000001');
  assert (select count(*) from wishlists) = 1, '本人の食べたい登録ができない';

  begin
    insert into wishlists (user_id, product_id)
    values ('00000000-0000-0000-0000-000000000902', '00000000-0000-0000-0000-000000000001');
    raise exception '他人の食べたいを登録できてしまった';
  exception
    when insufficient_privilege then null;  -- RLS の WITH CHECK が弾いた
  end;
end
$$;

reset role;

\echo '=== 13. アプリが実際に行う読み書きが権限で弾かれないこと ==='

-- RLS ポリシーを書いても GRANT を忘れると permission denied になる。
-- 逆に GRANT だけあって UPDATE 権限が無いと「2 回目の UPSERT だけ失敗する」形で表面化する。
-- アプリが使う操作をここで一通り通しておく。

select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000901', false);
set role authenticated;

do $$
declare
  v_user    uuid := '00000000-0000-0000-0000-000000000901';
  v_other   uuid := '00000000-0000-0000-0000-000000000902';
  v_product uuid := '00000000-0000-0000-0000-000000000001';
  v_review  uuid;
  v_table   text;
begin
  -- 読み取り
  foreach v_table in array array[
    'users','products','product_channels','stores','store_products','sightings',
    'reviews','review_helpfuls','news_articles','tasted_products','wishlists',
    'blocked_users','review_reports','product_submissions'
  ] loop
    execute format('select 1 from %I limit 1', v_table);
  end loop;

  select id into v_review from reviews where user_id = v_user limit 1;

  -- 「登録済みなら現状のままでよい」操作。アプリは ignore-duplicates で送るので
  -- 2 回実行しても失敗しないこと（UPDATE ポリシーに依存しないこと）を確かめる。
  for i in 1..2 loop
    insert into tasted_products (user_id, product_id) values (v_user, v_product)
      on conflict (user_id, product_id) do nothing;
    insert into wishlists (user_id, product_id) values (v_user, v_product)
      on conflict (user_id, product_id) do nothing;
    insert into review_helpfuls (review_id, user_id) values (v_review, v_user)
      on conflict (review_id, user_id) do nothing;
    insert into blocked_users (blocker_id, blocked_id) values (v_user, v_other)
      on conflict (blocker_id, blocked_id) do nothing;
    insert into review_reports (review_id, reporter_id, reason)
      values (v_review, v_user, 'spam')
      on conflict (review_id, reporter_id) do nothing;
    insert into product_submissions (user_id, name) values (v_user, 'テスト申請');
  end loop;

  -- レビューだけは編集できる必要があるので、上書きする UPSERT が通ること。
  insert into reviews (user_id, product_id, overall_rating) values (v_user, v_product, 4)
    on conflict (user_id, product_id)
    do update set overall_rating = excluded.overall_rating, updated_at = now();

  -- 自分のプロフィール行の作成と更新（初回サインインで通る経路）
  insert into users (id, display_name) values (v_user, 'テスト太郎')
    on conflict (id) do update set display_name = excluded.display_name;
  update users set display_name = 'テスト太郎2' where id = v_user;

  -- 後片付け
  delete from tasted_products where user_id = v_user;
  delete from wishlists where user_id = v_user;
  delete from review_helpfuls where user_id = v_user;
  delete from blocked_users where blocker_id = v_user;
end
$$;

reset role;

\echo ''
\echo '*** すべての検証を通過しました ***'
