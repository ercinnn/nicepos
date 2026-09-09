-- NicePOS - "Aktif Ürün" takibi (Stok sayfası)
--
-- Amaç: 8000+ ürünlük katalogda, kullanıcının GERÇEKTEN kullandığı (en az bir
-- kez sattığı VEYA etiketini bastığı) ürün sayısını/listesini bulmak.
-- Aktiflik üç kaynaktan derlenir:
--   - Satış: sale_items.product_id (zaten var, geriye dönük tam veri).
--   - Havuz: label_pool_items.barcode (zaten var, kalıcı geçmiş, 0032).
--   - Diğer etiket sekmeleri (Raf/Tel/Geniş/Poster/Ürün/İndirim): şimdiye
--     kadar HİÇ kaydedilmiyordu — bu migration'la eklenen `label_scan_activity`
--     tablosu, `labels_screen.dart`'ın PAYLAŞILAN `_resolveBarcode()`'undan
--     bundan sonraki her başarılı taramayı işaretler (ürün başına TEK satır —
--     log değil, "en az bir kez oldu mu" bayrağı).
--
-- Uygulama: DDL anon key ile çalıştırılamaz → Supabase SQL Editor'da uygulanır.

create table if not exists label_scan_activity (
  product_id uuid primary key references products(id) on delete cascade,
  barcode text not null,
  created_at timestamptz not null default now()
);

alter table label_scan_activity enable row level security;

create policy "authenticated full access" on label_scan_activity
  for all using (auth.role() = 'authenticated') with check (auth.role() = 'authenticated');

-- label_pool_items.barcode üzerinden EXISTS join'i (aşağıdaki search_products
-- ve count_active_products) barkod'a göre arıyor — mevcut index yalnız
-- (label_type, kontrol, created_at) üzerinde, barkod aramasını hızlandırmaz.
create index if not exists idx_label_pool_items_barcode on label_pool_items (barcode);

-- ─── search_products: p_active_only parametresi ────────────────────────────
-- Yeni parametre eklemek imza (tip listesi) değiştirir → CREATE OR REPLACE
-- yeni bir overload yaratır (0020'de yaşanan "function name is not unique"
-- hatasının AYNISI). Önce TÜM overload'lar DROP edilir (0020 deseni).
do $$
declare
  r record;
begin
  for r in
    select p.oid::regprocedure as signature
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where p.proname = 'search_products' and n.nspname = 'public'
  loop
    execute format('drop function %s', r.signature);
  end loop;
end $$;

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
  p_sort_column text default 'name',
  p_sort_ascending boolean default true,
  p_active_only boolean default false,
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
  with weekly_sales as materialized (
    select
      si.product_id,
      width_bucket(
        extract(epoch from (now() - s.sale_date)) / 86400.0,
        0, 28, 4
      ) as week_bucket,
      sum(si.quantity) as qty
    from sale_items si
    join sales s on s.id = si.sale_id
    where si.product_id is not null
      and s.sale_date >= now() - interval '28 days'
      and s.sale_date < now()
    group by 1, 2
  ),
  cok_satan as materialized (
    select product_id
    from weekly_sales
    where qty >= 1
    group by product_id
    having count(distinct week_bucket) = 4
  )
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
  left join cok_satan cs on p_status is not null and cs.product_id = p.id
  where
    (p_query is null or p_query = '' or
      p.name ilike '%'||p_query||'%' or
      p.barcode ilike '%'||p_query||'%' or
      p.stock_code ilike '%'||p_query||'%')
    and (p_group_id is null or p.group_id = p_group_id)
    and (
      p_status is null
      or (p_status = 'cok_satan' and cs.product_id is not null)
      or (p_status = 'tukendi' and cs.product_id is null and p.stock_quantity <= 0)
      or (p_status = 'pasif' and cs.product_id is null and p.stock_quantity > 0
          and p.updated_at < now() - interval '1 year')
      or (p_status = 'bos' and cs.product_id is null and p.stock_quantity > 0
          and p.updated_at >= now() - interval '1 year')
    )
    -- Barkod: BİREBİR eşleşme (eskiden ilike '%...%' idi).
    and (p_barcode is null or p.barcode = p_barcode)
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
    -- Aktif Ürün (Stok sayfası, 0034): satış geçmişi VEYA en az bir kez
    -- etiket sekmesinden okutulmuş (label_scan_activity) VEYA Havuz'a
    -- eklenmiş (label_pool_items, barkod eşleşmesi) ürünler.
    and (
      not p_active_only
      or exists (select 1 from sale_items si2 where si2.product_id = p.id)
      or exists (select 1 from label_scan_activity lsa where lsa.product_id = p.id)
      or (p.barcode is not null and p.barcode <> '' and exists (
            select 1 from label_pool_items lpi where lpi.barcode = p.barcode))
    )
  order by
    case when p_sort_column = 'name' and p_sort_ascending then p.name end asc nulls last,
    case when p_sort_column = 'name' and not p_sort_ascending then p.name end desc nulls last,
    case when p_sort_column = 'barcode' and p_sort_ascending then p.barcode end asc nulls last,
    case when p_sort_column = 'barcode' and not p_sort_ascending then p.barcode end desc nulls last,
    case when p_sort_column = 'stock_quantity' and p_sort_ascending then p.stock_quantity end asc nulls last,
    case when p_sort_column = 'stock_quantity' and not p_sort_ascending then p.stock_quantity end desc nulls last,
    case when p_sort_column = 'critical_stock' and p_sort_ascending then p.critical_stock end asc nulls last,
    case when p_sort_column = 'critical_stock' and not p_sort_ascending then p.critical_stock end desc nulls last,
    case when p_sort_column = 'vat_rate' and p_sort_ascending then p.vat_rate end asc nulls last,
    case when p_sort_column = 'vat_rate' and not p_sort_ascending then p.vat_rate end desc nulls last,
    case when p_sort_column = 'purchase_price' and p_sort_ascending then p.purchase_price end asc nulls last,
    case when p_sort_column = 'purchase_price' and not p_sort_ascending then p.purchase_price end desc nulls last,
    case when p_sort_column = 'price1' and p_sort_ascending then p.price1 end asc nulls last,
    case when p_sort_column = 'price1' and not p_sort_ascending then p.price1 end desc nulls last,
    case when p_sort_column = 'price2' and p_sort_ascending then p.price2 end asc nulls last,
    case when p_sort_column = 'price2' and not p_sort_ascending then p.price2 end desc nulls last,
    p.name asc
  limit p_limit offset p_offset;
$$;

-- Bu noktada `public` şemasında `search_products` adında TEK fonksiyon var
-- (yukarıdaki DO bloğu tüm eski overload'ları temizledi) — imza belirtmeden
-- GRANT güvenle çalışır.
grant execute on function search_products to anon, authenticated;

-- ─── Sayaç RPC'leri (Stok sayfası başlık rozeti) ───────────────────────────
create or replace function count_active_products()
returns bigint
language sql
stable
security invoker
as $$
  select count(*)
  from products p
  where exists (select 1 from sale_items si where si.product_id = p.id)
     or exists (select 1 from label_scan_activity lsa where lsa.product_id = p.id)
     or (p.barcode is not null and p.barcode <> '' and exists (
           select 1 from label_pool_items lpi where lpi.barcode = p.barcode));
$$;

create or replace function count_all_products()
returns bigint
language sql
stable
security invoker
as $$
  select count(*) from products;
$$;

grant execute on function count_active_products to authenticated;
grant execute on function count_all_products to authenticated;
