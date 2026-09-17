-- =============================================================================
-- 0065: e-Fatura/e-Arşiv ön hazırlığı — satış anı KDV donması
-- =============================================================================
-- Amaç: `products.vat_rate` ürün üzerinde duruyor ve sonradan değişebilir —
-- bir satış kalemi için fatura kesileceğinde SATIŞ ANINDAKİ oranın donmuş
-- halde saklanması gerekir (aksi halde geçmiş bir satışın gerçek KDV'si
-- geriye dönük bulunamaz). Detay: notes/e-fatura-entegrasyonu.md
--
-- `vat_amount` fiyatların KDV DAHİL olduğu varsayımıyla (`unit_price`/`total`
-- mevcut satış akışında hep KDV dahil girilir) satır toplamından geriye doğru
-- ayrıştırılır: vat_amount = total - total / (1 + vat_rate/100). EDM'nin
-- gerçek beklediği yuvarlama/format farklı çıkarsa bu formül `edm_client.py`
-- tarafında değil, BURADA (tek kaynak) güncellenir.
--
-- Geriye dönük satırlar (bu migration'dan ÖNCEKİ satışlar) NULL kalır — fatura
-- özelliği yalnız bundan sonraki satışlarda kullanılabilir.
--
-- `complete_sale`/`complete_sale_offline` parametre imzası/dönüş tipi
-- DEĞİŞMİYOR (yalnız gövde içi insert genişliyor) — CLAUDE.md'nin "önce DROP
-- FUNCTION" dersi burada geçerli değil, `CREATE OR REPLACE FUNCTION` yeterli.
--
-- Uygulama: DDL anon key ile çalıştırılamaz → Supabase SQL Editor'da uygulanır.
-- Idempotenttir (add column if not exists, create or replace function).
-- =============================================================================

alter table sale_items
  add column if not exists vat_rate numeric,
  add column if not exists vat_amount numeric;

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
  v_product_id uuid;
  v_vat_rate numeric;
  v_total numeric;
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
    v_product_id := nullif(item->>'product_id', '')::uuid;
    v_total := (item->>'total')::numeric;
    v_vat_rate := null;
    if v_product_id is not null then
      select vat_rate into v_vat_rate from products where id = v_product_id;
    end if;

    insert into sale_items (
      sale_id, product_id, product_name, quantity, unit_price, discount_value, total,
      vat_rate, vat_amount
    )
    values (
      v_sale_id,
      v_product_id,
      item->>'product_name',
      (item->>'quantity')::numeric,
      (item->>'unit_price')::numeric,
      (item->>'discount_value')::numeric,
      v_total,
      v_vat_rate,
      case when v_vat_rate is not null then round(v_total - v_total / (1 + v_vat_rate / 100), 2) else null end
    );

    if v_product_id is not null then
      update products
      set stock_quantity = stock_quantity - (item->>'quantity')::numeric,
          updated_at = now()
      where id = v_product_id;
    end if;
  end loop;

  if p_customer_id is not null and p_remaining_debt > 0 then
    insert into customer_payments (customer_id, sale_id, type, amount, note, payment_date)
    values (p_customer_id, v_sale_id, 'borc', p_remaining_debt, 'Satış: ' || v_sale_code, now());
  end if;

  return v_sale_code;
end;
$$ language plpgsql security definer;

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
  v_product_id uuid;
  v_vat_rate numeric;
  v_total numeric;
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
    v_product_id := nullif(item->>'product_id', '')::uuid;
    v_total := (item->>'total')::numeric;
    v_vat_rate := null;
    if v_product_id is not null then
      select vat_rate into v_vat_rate from products where id = v_product_id;
    end if;

    insert into sale_items (
      sale_id, product_id, product_name, quantity, unit_price, discount_value, total,
      vat_rate, vat_amount
    )
    values (
      p_id,
      v_product_id,
      item->>'product_name',
      (item->>'quantity')::numeric,
      (item->>'unit_price')::numeric,
      (item->>'discount_value')::numeric,
      v_total,
      v_vat_rate,
      case when v_vat_rate is not null then round(v_total - v_total / (1 + v_vat_rate / 100), 2) else null end
    );

    if v_product_id is not null then
      update products
      set stock_quantity = stock_quantity - (item->>'quantity')::numeric,
          updated_at = now()
      where id = v_product_id;
    end if;
  end loop;
end;
$$ language plpgsql security definer;
