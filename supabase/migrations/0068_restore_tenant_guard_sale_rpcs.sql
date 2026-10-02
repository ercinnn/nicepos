-- =============================================================================
-- 0068: complete_sale / complete_sale_offline — kiracı korumasının geri gelmesi
-- =============================================================================
-- YAŞANMIŞ HATA: 0065 (satış anı KDV donması) bu iki fonksiyonu 0040'ın
-- kiracı-farkında sürümü yerine ESKİ 0030/0027 gövdesinin üzerine yazdı.
-- `security definer` fonksiyonlarda RLS devre dışı olduğundan 0040'ın eklediği
-- korumalar kayboldu (2026-10-02'de canlıda `pg_get_functiondef` ile doğrulandı):
--   - `current_tenant_id()` NULL kontrolü ("Kiracı bulunamadı") yok,
--   - stok düşümü `where id = ...` ile — ürünün BU kiracıya ait olduğu
--     denetlenmiyor (başka kiracının ürün id'si gelirse onun stoğu düşerdi),
--   - KDV oranı okuması da kiracı süzgeçsiz.
-- Satışlar yine doğru kiracıya yazılıyordu (`tenant_id` sütun varsayılanı
-- `current_tenant_id()`), yani mevcut veride bozulma YOK — açık yalnız
-- kiracılar arası izolasyondaydı.
--
-- Bu migration = 0040'ın gövdesi + 0065'in `vat_rate`/`vat_amount` kaydı.
-- Parametre imzası/dönüş tipi DEĞİŞMİYOR → `create or replace` yeterli
-- (DROP FUNCTION gerekmez, istemci kodu değişmez).
--
-- Uygulama: Supabase SQL Editor'da çalıştırılır. Idempotenttir.
-- Doğrulama (uyguladıktan sonra iki satır da true dönmeli):
--   select p.proname,
--          pg_get_functiondef(p.oid) like '%v_tenant_id%' as kiraci_korumasi,
--          pg_get_functiondef(p.oid) like '%vat_rate%'    as kdv_kaydi
--     from pg_proc p join pg_namespace n on n.oid = p.pronamespace
--    where n.nspname = 'public' and p.proname in ('complete_sale', 'complete_sale_offline');
-- =============================================================================

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
  v_tenant_id uuid := current_tenant_id();
  v_sale_id uuid;
  v_sale_code text;
  item jsonb;
  v_product_id uuid;
  v_vat_rate numeric;
  v_total numeric;
begin
  if v_tenant_id is null then
    raise exception 'Kiracı bulunamadı (current_tenant_id).';
  end if;

  v_sale_code := generate_sale_code();

  insert into sales (
    tenant_id, sale_code, customer_id, total_amount, discount_percent, discount_amount,
    discount_type, paid_amount, payment_type, cash_amount, card_amount,
    remaining_debt, personnel, note, sale_date
  ) values (
    v_tenant_id, v_sale_code, p_customer_id, p_total_amount, p_discount_percent, p_discount_amount,
    'percent', p_paid_amount, p_payment_type, p_cash_amount, p_card_amount,
    p_remaining_debt, coalesce(p_personnel, 'Yönetici'), p_note, now()
  ) returning id into v_sale_id;

  for item in select * from jsonb_array_elements(p_items)
  loop
    v_product_id := nullif(item->>'product_id', '')::uuid;
    v_total := (item->>'total')::numeric;
    v_vat_rate := null;
    if v_product_id is not null then
      select vat_rate into v_vat_rate
        from products
       where id = v_product_id and tenant_id = v_tenant_id;
    end if;

    insert into sale_items (
      tenant_id, sale_id, product_id, product_name, quantity, unit_price, discount_value, total,
      vat_rate, vat_amount
    )
    values (
      v_tenant_id,
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
      where id = v_product_id
        and tenant_id = v_tenant_id;
    end if;
  end loop;

  if p_customer_id is not null and p_remaining_debt > 0 then
    insert into customer_payments (tenant_id, customer_id, sale_id, type, amount, note, payment_date)
    values (v_tenant_id, p_customer_id, v_sale_id, 'borc', p_remaining_debt, 'Satış: ' || v_sale_code, now());
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
  v_tenant_id uuid := current_tenant_id();
  item jsonb;
  v_product_id uuid;
  v_vat_rate numeric;
  v_total numeric;
begin
  if v_tenant_id is null then
    raise exception 'Kiracı bulunamadı (current_tenant_id).';
  end if;

  -- idempotency: satır zaten varsa (önceki deneme sunucuda başarılı olmuş
  -- ama istemci yanıtı alamamışsa) no-op — retry her zaman güvenlidir.
  if exists (select 1 from sales where id = p_id) then
    return;
  end if;

  insert into sales (
    id, tenant_id, sale_code, customer_id, total_amount, discount_percent, discount_amount,
    discount_type, paid_amount, payment_type, cash_amount, card_amount,
    remaining_debt, personnel, note, sale_date
  ) values (
    p_id, v_tenant_id, p_sale_code, p_customer_id, p_total_amount, p_discount_percent, p_discount_amount,
    'percent', p_paid_amount, p_payment_type, p_cash_amount, p_card_amount,
    p_remaining_debt, coalesce(p_personnel, 'Yönetici'), p_note, p_sale_date
  );

  for item in select * from jsonb_array_elements(p_items)
  loop
    v_product_id := nullif(item->>'product_id', '')::uuid;
    v_total := (item->>'total')::numeric;
    v_vat_rate := null;
    if v_product_id is not null then
      select vat_rate into v_vat_rate
        from products
       where id = v_product_id and tenant_id = v_tenant_id;
    end if;

    insert into sale_items (
      tenant_id, sale_id, product_id, product_name, quantity, unit_price, discount_value, total,
      vat_rate, vat_amount
    )
    values (
      v_tenant_id,
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
      where id = v_product_id
        and tenant_id = v_tenant_id;
    end if;
  end loop;
end;
$$ language plpgsql security definer;
