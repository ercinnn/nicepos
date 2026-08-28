-- =============================================================================
-- 0040: security definer RPC'lerin kiracı-farkında hale getirilmesi — Faz A / Adım 5
-- =============================================================================
-- Önkoşul: 0037-0039 uygulanmış olmalı.
--
-- 0039 tüm RLS politikalarını kiracı-bazlı yaptı, AMA `security definer` olarak
-- tanımlı fonksiyonlar RLS'i by-pass eder (bu onların VAR OLMA amacı — tek
-- transaction'da atomik iş yapmak). Bu yüzden her biri elle denetlenip
-- kiracı kontrolü koda GÖMÜLMELİ:
--   - complete_sale / complete_sale_offline: yeni satırlar `current_tenant_id()`
--     ile açıkça damgalanır (DEFAULT'a güvenmek yerine — çağıran kiracısız ise
--     NOT NULL hatası yerine anlamlı bir `raise exception` alır).
--   - delete_sale: yalnız KENDİ kiracısındaki bir satışı silebilir (aksi halde
--     bir kullanıcı başka bir kiracının sale id'sini bilirse/tahmin ederse
--     onu silebilirdi).
--   - decrement_product_stock / increment_product_stock: yalnız KENDİ
--     kiracısının ürününü güncelleyebilir (aynı çapraz-kiracı riski).
--   - create_online_order: `anon` çağırdığından `current_tenant_id()` HER ZAMAN
--     NULL döner (memberships satırı yok) — kiracı, sepetteki ürünün kendi
--     `tenant_id`'sinden çözümlenir. v1'de tek kiracı olduğundan yeterlidir;
--     gerçek çoklu-kiracı storefront yönlendirmesi (slug/subdomain → tenant_id)
--     Faz F'nin kapsamındadır. Bu haliyle bile karışık-kiracı sepeti güvenle
--     reddeder (farklı kiracının ürünü `tenant_id = v_tenant_id` filtresine
--     takılıp "ürün bulunamadı" hatası verir).
--
-- Fonksiyon İMZALARI (parametre listeleri) DEĞİŞMEDİ — yalnız gövdeler
-- güncellendi, bu yüzden 0020/0035'teki "overload temizliği" DO bloğuna gerek
-- yok (CREATE OR REPLACE aynı imzayı değiştirir, yeni overload yaratmaz).
--
-- Uygulama: DDL anon key ile çalıştırılamaz → Supabase SQL Editor'da uygulanır.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- decrement_product_stock / increment_product_stock
-- -----------------------------------------------------------------------------
create or replace function decrement_product_stock(p_product_id uuid, p_quantity numeric)
returns void as $$
begin
  update products
  set stock_quantity = stock_quantity - p_quantity,
      updated_at = now()
  where id = p_product_id
    and tenant_id = current_tenant_id();
end;
$$ language plpgsql security definer;

create or replace function increment_product_stock(p_product_id uuid, p_quantity numeric)
returns void as $$
begin
  update products
  set stock_quantity = stock_quantity + p_quantity,
      updated_at = now()
  where id = p_product_id
    and tenant_id = current_tenant_id();
end;
$$ language plpgsql security definer;

-- -----------------------------------------------------------------------------
-- complete_sale — online satış tamamlama (bkz. 0030)
-- -----------------------------------------------------------------------------
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
    insert into sale_items (tenant_id, sale_id, product_id, product_name, quantity, unit_price, discount_value, total)
    values (
      v_tenant_id,
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
      where id = (item->>'product_id')::uuid
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

-- -----------------------------------------------------------------------------
-- complete_sale_offline — mobil offline satış senkronu (bkz. 0027)
-- -----------------------------------------------------------------------------
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
    insert into sale_items (tenant_id, sale_id, product_id, product_name, quantity, unit_price, discount_value, total)
    values (
      v_tenant_id,
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
      where id = (item->>'product_id')::uuid
        and tenant_id = v_tenant_id;
    end if;
  end loop;
end;
$$ language plpgsql security definer;

-- -----------------------------------------------------------------------------
-- delete_sale — satış silme (bkz. 0031)
-- -----------------------------------------------------------------------------
create or replace function delete_sale(p_sale_id uuid) returns void as $$
declare
  v_tenant_id uuid := current_tenant_id();
  item record;
begin
  if v_tenant_id is null then
    raise exception 'Kiracı bulunamadı (current_tenant_id).';
  end if;

  if not exists (select 1 from sales where id = p_sale_id and tenant_id = v_tenant_id) then
    raise exception 'Satış bulunamadı.';
  end if;

  for item in
    select product_id, quantity from sale_items
    where sale_id = p_sale_id and tenant_id = v_tenant_id
  loop
    if item.product_id is not null then
      update products
      set stock_quantity = stock_quantity + item.quantity,
          updated_at = now()
      where id = item.product_id
        and tenant_id = v_tenant_id;
    end if;
  end loop;

  delete from customer_payments where sale_id = p_sale_id and tenant_id = v_tenant_id;
  delete from kasa_reconciliations where sale_id = p_sale_id and tenant_id = v_tenant_id;
  delete from sale_items where sale_id = p_sale_id and tenant_id = v_tenant_id;
  delete from sales where id = p_sale_id and tenant_id = v_tenant_id;
end;
$$ language plpgsql security definer;

-- -----------------------------------------------------------------------------
-- online_products — storefront'un okuduğu public view'a tenant_id eklenir
-- (Faz F'nin storefront filtrelemesi için önkoşul; v1'de tek kiracı olduğundan
-- şimdilik davranış değişmez).
-- -----------------------------------------------------------------------------
-- ⚠️ tenant_id EN SONA eklenir: `CREATE OR REPLACE VIEW` mevcut sütunların
-- pozisyonunu/adını değiştirmeye izin vermez (42P16 hatası) — yalnız sona yeni
-- sütun EKLEMEK güvenlidir, araya sıkıştırmak sonraki sütunları "yeniden
-- adlandırma" gibi yorumlanır.
create or replace view online_products as
select
  id,
  name,
  barcode,
  stock_code,
  unit,
  price1 as price,
  vat_rate,
  image_url,
  description,
  weight,
  group_id,
  (stock_quantity > 0) as in_stock,
  tenant_id
from products
where is_online_active = true;

grant select on online_products to anon, authenticated;

-- -----------------------------------------------------------------------------
-- create_online_order — misafir sipariş (bkz. 0028)
-- -----------------------------------------------------------------------------
-- anon çağırdığı için current_tenant_id() NULL döner (memberships satırı yok)
-- — kiracı, sepetteki İLK ürünün tenant_id'sinden çözümlenir; sonraki her
-- kalem AYNI kiracıya ait olmak zorundadır (farklı kiracının ürünü bu filtreye
-- takılıp "ürün bulunamadı" hatası alır — karışık-kiracı sepeti güvenle
-- reddedilir).
create or replace function create_online_order(
  p_customer_name text,
  p_customer_phone text,
  p_customer_email text,
  p_shipping_address text,
  p_customer_note text,
  p_items jsonb
) returns online_orders as $$
declare
  item jsonb;
  v_order online_orders;
  v_product products;
  v_quantity numeric;
  v_total numeric := 0;
  v_line_total numeric;
  v_tenant_id uuid;
begin
  if p_items is null or jsonb_array_length(p_items) = 0 then
    raise exception 'Sepet boş olamaz';
  end if;

  select tenant_id into v_tenant_id
  from products
  where id = nullif(p_items->0->>'product_id', '')::uuid;

  if v_tenant_id is null then
    raise exception 'Ürün bulunamadı: %', p_items->0->>'product_id';
  end if;

  insert into online_orders (
    tenant_id, order_code, customer_name, customer_phone, customer_email,
    shipping_address, customer_note
  ) values (
    v_tenant_id, generate_online_order_code(), p_customer_name, p_customer_phone, p_customer_email,
    p_shipping_address, p_customer_note
  ) returning * into v_order;

  for item in select * from jsonb_array_elements(p_items)
  loop
    select * into v_product from products
    where id = (item->>'product_id')::uuid
      and is_online_active = true
      and tenant_id = v_tenant_id
    for update;

    if not found then
      raise exception 'Ürün bulunamadı veya online satışta değil: %', item->>'product_id';
    end if;

    v_quantity := (item->>'quantity')::numeric;
    if v_quantity <= 0 then
      raise exception 'Geçersiz miktar';
    end if;
    if v_product.stock_quantity < v_quantity then
      raise exception 'Yetersiz stok: %', v_product.name;
    end if;

    v_line_total := v_product.price1 * v_quantity;
    v_total := v_total + v_line_total;

    insert into online_order_items (tenant_id, order_id, product_id, product_name, quantity, unit_price, total)
    values (v_tenant_id, v_order.id, v_product.id, v_product.name, v_quantity, v_product.price1, v_line_total);

    update products
    set stock_quantity = stock_quantity - v_quantity,
        updated_at = now()
    where id = v_product.id
      and tenant_id = v_tenant_id;
  end loop;

  update online_orders set total_amount = v_total, updated_at = now()
  where id = v_order.id
  returning * into v_order;

  return v_order;
end;
$$ language plpgsql security definer;

grant execute on function create_online_order(text, text, text, text, text, jsonb) to anon, authenticated;
