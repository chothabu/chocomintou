-- 販売終了日を過ぎた商品を自動で「販売終了」にする。
--
-- 期間限定の商品は end_date を持つが、日付が過ぎても sale_status が on_sale のままだと
-- 「今買える」として表示され続けてしまう。目撃情報を 30 日で隠すのと同じ理由で、
-- 事実でなくなった情報は出さない。
--
-- 収集バッチから毎日呼ぶ。トリガーにしないのは、行の更新契機が無くても
-- 時間の経過だけで状態が変わるため。

create or replace function expire_products()
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  v_count integer;
begin
  update products
     set sale_status = 'ended',
         updated_at = now()
   where end_date is not null
     and end_date < (timezone('Asia/Tokyo', now()))::date
     and sale_status <> 'ended';
  get diagnostics v_count = row_count;
  return v_count;
end;
$$;

comment on function expire_products() is
  '販売終了日を過ぎた商品を販売終了にする。収集バッチから毎日呼ぶ。';

revoke all on function expire_products() from public;
grant execute on function expire_products() to service_role;
