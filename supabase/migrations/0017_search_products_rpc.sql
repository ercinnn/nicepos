-- =============================================================================
-- 0017: Ürünler "Durum" filtresi için sunucu taraflı arama RPC'si
-- =============================================================================
-- Ürünler ekranındaki sütun filtreleri (bkz. products_list_screen.dart) sunucu
-- tarafında PostgREST sorgu zinciriyle uygulanıyordu. Ancak "Durum" (Çok
-- Satan/Tükendi/Pasif/Boş) `products` tablosunda gerçek bir sütun DEĞİL —
-- `product_status` view'ından hesaplanıyor (bkz. 0016_product_status.sql) ve bu
-- view'ın `products`'a tanımlı bir FK'si olmadığından PostgREST embed filtresi
-- desteklemiyor. Önceki çözüm önce eşleşen id'leri ayrı bir sorguyla çekip
-- `id=in.(...)` ile ana sorguya ekliyordu — "Pasif" gibi çok sayıda ürünü
-- kapsayan bir durumda bu id listesi URL'yi aşırı uzatıp "Bad Request (400)"
-- hatası veriyordu (canlıda gözlemlendi).
--
-- Çözüm: Durum filtresi aktifken TÜM sorgu (arama + grup + sütun filtreleri +
-- durum + sayfalama) tek bir RPC çağrısında, sunucuda birleştirilir — eşleşen
-- id listesi asla istemciye/URL'ye geri dönmez (RPC parametreleri POST
-- gövdesinde gider, URL uzunluğu sorunu oluşmaz). Durum filtresi YOKSA
-- repository eski (daha basit, iyi test edilmiş) PostgREST sorgu zincirini
-- kullanmaya devam eder — bu RPC yalnız durum filtresi aktifken devreye girer
-- (bkz. ProductRepository.fetchPaged/fetchAll).
--
-- RLS: SECURITY INVOKER (varsayılan) — diğer RPC'lerle aynı desen
-- (bkz. 0015_sales_revenue_rpc.sql).
-- Uygulama: DDL anon key ile çalıştırılamaz → Supabase SQL Editor'da uygulanır.

create or replace function search_products(
  p_query text default null,
  p_group_id uuid default null,
  p_status text default null,
  p_barcode text default null,
  p_stock_code text default null,
  p_unit text default null,
  p_group_name text default null,
  p_parent_group_name text default null,
  p_stock_min numeric default null,
  p_stock_max numeric default null,
  p_critical_stock_min numeric default null,
  p_critical_stock_max numeric default null,
  p_vat_min numeric default null,
  p_vat_max numeric default null,
  p_purchase_min numeric default null,
  p_purchase_max numeric default null,
  p_price1_min numeric default null,
  p_price1_max numeric default null,
  p_price2_min numeric default null,
  p_price2_max numeric default null,
  p_limit int default 50,
  p_offset int default 0
)
returns table (
  id uuid,
  barcode text,
  name text,
  stock_code text,
  group_id uuid,
  unit text,
  origin_country text,
  stock_quantity numeric,
  critical_stock numeric,
  purchase_price numeric,
  purchase_price_vat_included boolean,
  price1 numeric,
  price1_vat_included boolean,
  price2 numeric,
  price2_vat_included boolean,
  vat_rate numeric,
  weight numeric,
  description text,
  image_url text,
  quick_list_order integer,
  is_online_active boolean,
  updated_at timestamptz,
  group_name text,
  parent_group_name text
)
language sql
stable
security invoker
as $$
  select
    p.id, p.barcode, p.name, p.stock_code, p.group_id, p.unit, p.origin_country,
    p.stock_quantity, p.critical_stock, p.purchase_price, p.purchase_price_vat_included,
    p.price1, p.price1_vat_included, p.price2, p.price2_vat_included, p.vat_rate,
    p.weight, p.description, p.image_url, p.quick_list_order, p.is_online_active,
    p.updated_at,
    pg.name as group_name,
    parent_pg.name as parent_group_name
  from products p
  left join product_groups pg on pg.id = p.group_id
  left join product_groups parent_pg on parent_pg.id = pg.parent_group_id
  left join product_status ps on ps.product_id = p.id
  where
    (p_query is null or p_query = '' or
      p.name ilike '%'||p_query||'%' or
      p.barcode ilike '%'||p_query||'%' or
      p.stock_code ilike '%'||p_query||'%')
    and (p_group_id is null or p.group_id = p_group_id)
    and (
      p_status is null
      or (p_status = 'bos' and ps.status is null)
      or ps.status = p_status
    )
    and (p_barcode is null or p.barcode ilike '%'||p_barcode||'%')
    and (p_stock_code is null or p.stock_code ilike '%'||p_stock_code||'%')
    and (p_unit is null or p.unit ilike '%'||p_unit||'%')
    and (p_group_name is null or pg.name ilike '%'||p_group_name||'%')
    and (p_parent_group_name is null or parent_pg.name ilike '%'||p_parent_group_name||'%')
    and (p_stock_min is null or p.stock_quantity >= p_stock_min)
    and (p_stock_max is null or p.stock_quantity <= p_stock_max)
    and (p_critical_stock_min is null or p.critical_stock >= p_critical_stock_min)
    and (p_critical_stock_max is null or p.critical_stock <= p_critical_stock_max)
    and (p_vat_min is null or p.vat_rate >= p_vat_min)
    and (p_vat_max is null or p.vat_rate <= p_vat_max)
    and (p_purchase_min is null or p.purchase_price >= p_purchase_min)
    and (p_purchase_max is null or p.purchase_price <= p_purchase_max)
    and (p_price1_min is null or p.price1 >= p_price1_min)
    and (p_price1_max is null or p.price1 <= p_price1_max)
    and (p_price2_min is null or p.price2 >= p_price2_min)
    and (p_price2_max is null or p.price2 <= p_price2_max)
  order by p.name
  limit p_limit offset p_offset;
$$;

grant execute on function search_products to anon, authenticated;
