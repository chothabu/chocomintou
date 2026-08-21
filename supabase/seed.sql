-- ローカル開発用のシードデータ。
--
-- `supabase db reset` のときだけ自動で流れる。本番には入らない。
-- 目的は「アプリとバックエンドが正しくつながっているか」を確かめることなので、
-- 商品名は実在のものではなく、動作確認用と分かる名前にしてある。
--
-- 実際の商品データは、管理画面での登録か収集バッチ（collectors/）から入れる。

-- 収集元の例。利用条件を確認したうえで管理画面から有効にする。
insert into news_sources (name, feed_url, is_enabled)
values ('PR TIMES', 'https://prtimes.jp/index.rdf', false);

-- ---- 動作確認用ユーザー ----
insert into auth.users (id, email, aud, role)
values ('00000000-0000-0000-0000-0000000000a1', 'dev@example.com', 'authenticated', 'authenticated');

insert into users (id, display_name)
values ('00000000-0000-0000-0000-0000000000a1', '動作確認ユーザー');

-- ---- 動作確認用の商品 ----
insert into products (id, name, manufacturer, description, category, price,
                      release_date, sale_status, is_limited, sales_channel_text, is_published)
values
  ('00000000-0000-0000-0000-0000000000b1', '【動作確認】チョコミントアイス', '確認用メーカー',
   'ローカル動作確認のためのデータです。', 'ice', 238, current_date - 7, 'on_sale', true,
   '動作確認用', true),
  ('00000000-0000-0000-0000-0000000000b2', '【動作確認】ミントチョコクッキー', '確認用メーカー',
   'ローカル動作確認のためのデータです。', 'snack', 198, current_date - 30, 'on_sale', false,
   '動作確認用', true),
  ('00000000-0000-0000-0000-0000000000b3', '【動作確認】未公開の商品', '確認用メーカー',
   'is_published = false。アプリから見えないことの確認用。', 'other', null, current_date, 'on_sale', false,
   null, false);

insert into product_channels (product_id, chain_name)
values ('00000000-0000-0000-0000-0000000000b1', 'familymart');

-- ---- 目撃情報（渋谷駅周辺） ----
-- report_sighting は auth.uid() を見るので、シードでは直接 insert する。
insert into stores (id, name, chain_name, latitude, longitude, address, external_source, external_store_id)
values ('00000000-0000-0000-0000-0000000000c1', '【動作確認】渋谷の店舗', 'familymart',
        35.6620, 139.6990, '東京都渋谷区', 'admin', 'seed-c1');

insert into sightings (product_id, store_id, user_id, found_at)
values
  ('00000000-0000-0000-0000-0000000000b1', '00000000-0000-0000-0000-0000000000c1',
   '00000000-0000-0000-0000-0000000000a1', now() - interval '2 hours'),
  ('00000000-0000-0000-0000-0000000000b2', '00000000-0000-0000-0000-0000000000c1',
   '00000000-0000-0000-0000-0000000000a1', now() - interval '3 days');

-- ---- レビュー（集計トリガーとミントレベルの確認用） ----
insert into reviews (user_id, product_id, overall_rating, mint_intensity, chocolate_intensity,
                     sweetness, freshness, comment)
values ('00000000-0000-0000-0000-0000000000a1', '00000000-0000-0000-0000-0000000000b1',
        5, 5, 3, 4, 5, 'アプリとバックエンドがつながっていれば、このレビューが表示されます。');
