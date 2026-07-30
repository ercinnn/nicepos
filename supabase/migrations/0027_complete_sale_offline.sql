-- NicePOS - Mobil offline satış senkronu: TEK atomik RPC ile satış tamamlama
--
-- Amaç: `SaleSyncService` bekleyen (offline tamamlanmış) Nakit/POS satışlarını
-- senkronize ederken `sales` insert + `sale_items` insert + stok düşürme gibi
-- AYRI ayrı istemci-taraflı adımlara BÖLÜNMEZ (online `completeSale()`'in
-- aksine) — bağlantı senkron ORTASINDA tekrar koparsa (nadir ama mümkün:
-- reachability probe geçmiş olsa bile) kısmi yazım (ör. sales satırı var ama
-- sale_items yok, veya stok iki kez düşmüş) riski TAMAMEN ortadan kalksın diye
-- her şey TEK bir PL/pgSQL fonksiyon gövdesinde (dolayısıyla tek transaction'da)
-- yapılır. `p_id` bazlı idempotency kontrolü retry'ı güvenli kılar: satır zaten
-- varsa (önceki deneme aslında sunucuda başarılı olmuş ama istemci yanıtı
-- alamamışsa) fonksiyon no-op döner, tekrar denemek zararsızdır.
--
-- Yalnız İSTEMCİ id'sini AÇIKÇA kabul eder (`products.createWithId` deseniyle
-- aynı gerekçe: `sales.id uuid default gen_random_uuid()` olduğundan açık id
-- insert'i başka bir migration gerektirmez).
--
-- Uygulama: DDL anon key ile çalıştırılamaz → Supabase SQL Editor'da uygulanır.

create or replace function complete_sale_offline(
  p_id uuid,
  p_sale_code text,
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
  p_sale_date timestamptz,
  p_items jsonb
) returns void as $$
declare
  item jsonb;
begin
  if exists (select 1 from sales where id = p_id) then
    return;
  end if;

  insert into sales (
    id, sale_code, customer_id, total_amount, discount_percent, discount_amount,
    discount_type, paid_amount, payment_type, cash_amount, card_amount,
    remaining_debt, personnel, note, sale_date
  ) values (
    p_id, p_sale_code, p_customer_id, p_total_amount, p_discount_percent, p_discount_amount,
    'percent', p_paid_amount, p_payment_type, p_cash_amount, p_card_amount,
    p_remaining_debt, coalesce(p_personnel, 'Yönetici'), p_note, p_sale_date
  );

  for item in select * from jsonb_array_elements(p_items)
  loop
    insert into sale_items (sale_id, product_id, product_name, quantity, unit_price, discount_value, total)
    values (
      p_id,
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
end;
$$ language plpgsql security definer;
