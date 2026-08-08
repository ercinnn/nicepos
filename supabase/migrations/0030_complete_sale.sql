-- NicePOS - Online satış tamamlama: TEK atomik RPC ile satış kapatma
--
-- Amaç: `SalesRepository.completeSale()` `sales` insert + `sale_items` insert +
-- sepetteki HER kalem için ayrı `decrement_product_stock` RPC + (varsa) borç
-- hareketi insert olmak üzere sıralı ayrı ayrı istemci-taraflı gidiş-dönüşlerden
-- oluşuyordu (N+3 round-trip ağ şelalesi) — 5+ kalemli bir sepette satış kapatma
-- 3-4 saniye sürüyordu. `complete_sale_offline` (0027) ile aynı desen: her şey
-- TEK PL/pgSQL fonksiyon gövdesinde (tek transaction, tek round-trip) yapılır.
-- Offline'ın aksine `p_id` İSTEMCİDEN alınmaz (idempotency/retry ihtiyacı yok,
-- her başarısız deneme yeni bir satır üretir) ve `sale_code` fonksiyon içinde
-- `generate_sale_code()` ile üretilip dönüş değeri olarak verilir.
--
-- Uygulama: DDL anon key ile çalıştırılamaz → Supabase SQL Editor'da uygulanır.

create or replace function complete_sale(
  p_customer_id uuid,
  p_total_amount numeric,
  p_discount_percent numeric,
  p_discount_amount numeric,
  p_paid_amount numeric,
  p_payment_type text,
  p_cash_amount numeric,
  p_card_amount numeric,
  p_remaining_debt numeric,
  p_personnel text,
  p_note text,
  p_items jsonb
) returns text as $$
declare
  v_sale_id uuid;
  v_sale_code text;
  item jsonb;
begin
  v_sale_code := generate_sale_code();

  insert into sales (
    sale_code, customer_id, total_amount, discount_percent, discount_amount,
    discount_type, paid_amount, payment_type, cash_amount, card_amount,
    remaining_debt, personnel, note, sale_date
  ) values (
    v_sale_code, p_customer_id, p_total_amount, p_discount_percent, p_discount_amount,
    'percent', p_paid_amount, p_payment_type, p_cash_amount, p_card_amount,
    p_remaining_debt, coalesce(p_personnel, 'Yönetici'), p_note, now()
  ) returning id into v_sale_id;

  for item in select * from jsonb_array_elements(p_items)
  loop
    insert into sale_items (sale_id, product_id, product_name, quantity, unit_price, discount_value, total)
    values (
      v_sale_id,
      nullif(item->>'product_id', '')::uuid,
      item->>'product_name',
      (item->>'quantity')::numeric,
      (item->>'unit_price')::numeric,
      (item->>'discount_value')::numeric,
      (item->>'total')::numeric
    );

    if nullif(item->>'product_id', '') is not null then
      update products
      set stock_quantity = stock_quantity - (item->>'quantity')::numeric,
          updated_at = now()
      where id = (item->>'product_id')::uuid;
    end if;
  end loop;

  if p_customer_id is not null and p_remaining_debt > 0 then
    insert into customer_payments (customer_id, sale_id, type, amount, note, payment_date)
    values (p_customer_id, v_sale_id, 'borc', p_remaining_debt, 'Satış: ' || v_sale_code, now());
  end if;

  return v_sale_code;
end;
$$ language plpgsql security definer;
