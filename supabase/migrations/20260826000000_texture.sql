-- レビューに「食感」を足す。
--
-- チョコチップのザクザク感やアイスの口どけは、チョコミントの評価で
-- ミント感・甘さと並んで語られる要素なのに、評価軸が無かった。

alter table reviews add column texture smallint check (texture between 1 and 5);
alter table products add column avg_texture numeric(3,2);

comment on column reviews.texture is 'ザクザク感・口どけなどの食感。1〜5。任意入力';

-- 集計を食感まで含めて計算し直す
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
    avg_texture   = (select avg(texture)             from reviews where product_id = v_product and not is_hidden),
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

-- 既存のレビューぶんを反映する
update reviews set updated_at = updated_at where id in (select id from reviews limit 1);
