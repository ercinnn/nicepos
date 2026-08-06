-- NicePOS - Online Satış modülü: sipariş tabloları + public ürün view'ı
--
-- Tasarım kararı: v1'de online müşteri GİRİŞİ (Supabase Auth hesabı) YOK —
-- yalnız misafir (guest) sipariş. Gerekçe: mevcut RLS modeli tek mağaza/tek
-- kullanıcı varsayımıyla `auth.role() = 'authenticated'` olan HERKESE tüm
-- tablolarda (sales, customers, kasa...) tam CRUD veriyor (bkz. 0002_rls.sql).
-- Online müşteriler aynı Supabase Auth havuzunda hesap açarsa bu blanket
-- politika onlara da POS'un tamamına erişim verirdi. Gerçek müşteri hesabı
-- istenirse önce TÜM mevcut RLS politikalarının "authenticated" yerine bir
-- staff-allowlist kontrolüne geçmesi gerekir — kapsam dışı, ayrı bir iş.
--
-- anon (storefront) yalnız iki şeyi yapabilir: `online_products` view'ından
-- oku, `create_online_order()` RPC'sini çağır. online_orders/online_order_items
-- tablolarına DOĞRUDAN insert/select politikası anon'a VERİLMEZ — RPC
-- SECURITY DEFINER olduğundan atomik ve tek giriş noktasıdır (complete_sale_offline
-- ile aynı desen, bkz. 0027).

-- ─────────────────────────────────────────────────────────────────────────
-- Public ürün kataloğu (yalnız müşteriye güvenle gösterilecek sütunlar).
-- Alım fiyatı / price2 / kritik stok gibi iç veriler DIŞARIDA bırakılır.
-- View postgres sahipliğinde olduğundan `products` tablosundaki RLS'i
-- (authenticated-only) bypass eder — filtre burada elle uygulanır.
-- ─────────────────────────────────────────────────────────────────────────
create view online_products as
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
  (stock_quantity > 0) as in_stock
from products
where is_online_active = true;

grant select on online_products to anon, authenticated;

-- ─────────────────────────────────────────────────────────────────────────
-- Sipariş başlığı + kalemleri
-- ─────────────────────────────────────────────────────────────────────────
create table online_orders (
  id uuid primary key default gen_random_uuid(),
  order_code text unique not null,
  customer_name text not null,
  customer_phone text not null,
  customer_email text,
  shipping_address text not null,
  customer_note text,
  status text not null default 'yeni'
    check (status in ('yeni','onaylandi','hazirlaniyor','kargoda','tamamlandi','iptal')),
  total_amount numeric not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index on online_orders (status);
create index on online_orders (created_at);

create table online_order_items (
  id uuid primary key default gen_random_uuid(),
  order_id uuid references online_orders(id) on delete cascade,
  product_id uuid references products(id),
  product_name text not null,
  quantity numeric not null default 1,
  unit_price numeric not null default 0,
  total numeric not null default 0
);
create index on online_order_items (order_id);

-- Sipariş kodu üretimi: WEB + YYMMDD + günlük sıra + rastgele 2 harf
-- (POS'un generate_sale_code'undan görsel olarak ayrışsın diye WEB önekli).
create sequence online_order_code_seq;

create or replace function generate_online_order_code() returns text as $$
declare
  date_part text := to_char(now(), 'YYMMDD');
  seq_part text := lpad((nextval('online_order_code_seq') % 10000)::text, 4, '0');
  rand_part text := upper(substr(md5(random()::text), 1, 2));
begin
  return 'WEB' || date_part || seq_part || '-' || rand_part;
end;
$$ language plpgsql;

-- ─────────────────────────────────────────────────────────────────────────
-- RLS: staff (mevcut blanket "authenticated" deseni) tam erişim; anon HİÇ
-- doğrudan tablo erişimi almaz — yalnız aşağıdaki RPC üzerinden yazar.
-- ─────────────────────────────────────────────────────────────────────────
alter table online_orders enable row level security;
alter table online_order_items enable row level security;

create policy "authenticated full access" on online_orders
  for all using (auth.role() = 'authenticated') with check (auth.role() = 'authenticated');

create policy "authenticated full access" on online_order_items
  for all using (auth.role() = 'authenticated') with check (auth.role() = 'authenticated');

-- ─────────────────────────────────────────────────────────────────────────
-- Sipariş oluşturma: TEK atomik RPC (complete_sale_offline ile aynı desen —
-- 0027'deki gerekçe birebir geçerli). anon bunu çağırabilir; ürünün gerçekten
-- `is_online_active` olduğunu VE stok yeterliliğini burada, sunucu tarafında
-- doğrular (istemci tarafı fiyat/aktiflik bilgisine güvenilmez).
-- p_items: [{"product_id": "...", "quantity": 2}, ...] — fiyat İSTEMCİDEN
-- alınmaz, sunucuda products.price1'den anlık okunur (fiyat manipülasyonu
-- önlenir).
-- ─────────────────────────────────────────────────────────────────────────
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
begin
  if p_items is null or jsonb_array_length(p_items) = 0 then
    raise exception 'Sepet boş olamaz';
  end if;

  insert into online_orders (
    order_code, customer_name, customer_phone, customer_email,
    shipping_address, customer_note
  ) values (
    generate_online_order_code(), p_customer_name, p_customer_phone, p_customer_email,
    p_shipping_address, p_customer_note
  ) returning * into v_order;

  for item in select * from jsonb_array_elements(p_items)
  loop
    select * into v_product from products
    where id = (item->>'product_id')::uuid and is_online_active = true
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

    insert into online_order_items (order_id, product_id, product_name, quantity, unit_price, total)
    values (v_order.id, v_product.id, v_product.name, v_quantity, v_product.price1, v_line_total);

    update products
    set stock_quantity = stock_quantity - v_quantity,
        updated_at = now()
    where id = v_product.id;
  end loop;

  update online_orders set total_amount = v_total, updated_at = now()
  where id = v_order.id
  returning * into v_order;

  return v_order;
end;
$$ language plpgsql security definer;

grant execute on function create_online_order(text, text, text, text, text, jsonb) to anon, authenticated;
