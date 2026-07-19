-- =============================================================================
-- 0023: Eşlenik Barkod — "Çok Satan" ve "Pasif" durumları da grup bazlı
-- =============================================================================
-- Önkoşul: 0021_equivalent_barcodes.sql (products.equivalent_group_id sütunu +
-- product_equivalent_aggregate view'ı) ve 0022_equivalent_barcode_max_price_
-- and_status.sql (product_status'un "Tükendi" dalını grup TOPLAM stoğuna
-- bağlayan güncel hâli).
--
-- Kullanıcı isteği (KARAR): 0022'de yalnızca "Tükendi" grup bazlı hale
-- getirilmişti. Bir ürünün eşlenik barkodlarından biri satılıyorsa veya
-- güncelleniyorsa (stok girişi, fiyat düzenleme vb.) grubun DİĞER üyeleri de
-- bunu yansıtmalı — hangi barkod okutulursa okutulsun aynı fiziksel ürün söz
-- konusu. Bu migration "Çok Satan" ve "Pasif" dallarını da grup bazlı yapar:
--   1. Çok Satan: `weekly_sales` artık `si.product_id` yerine
--      `coalesce(pr.equivalent_group_id, si.product_id)` üzerinden gruplanır
--      — grubun TÜM üyelerinin satışları toplanır; son 4 haftanın (rolling
--      7'şer gün, width_bucket mantığı AYNEN) HER birinde grup genelinde
--      TOPLAM ≥1 adet satılmışsa grubun TÜM üyeleri "Çok Satan" sayılır.
--      Gruplanmamış ürünlerde davranış DEĞİŞMEDİ (coalesce kendi id'sine düşer).
--   2. Pasif: `grp_activity` (materialized) CTE'siyle grup içindeki EN YENİ
--      `updated_at` bulunur; bir üye son 1 yıl içinde güncellenmişse (satış/
--      stok/fiyat) grubun TÜM üyeleri "Pasif" sayılmaz. Gruplanmamış ürünlerde
--      davranış DEĞİŞMEDİ (coalesce kendi updated_at'ine düşer).
-- "Tükendi" dalı (product_equivalent_aggregate.total_stock) DOKUNULMADI.
--
-- Bu migration yalnızca `product_status` view'ını `create or replace` ile
-- yeniden tanımlar; `product_equivalent_aggregate` DEĞİŞMEDİ.
--
-- RLS: security_invoker = true (0016/0021/0022 ile aynı desen).
-- Uygulama: DDL anon key ile çalıştırılamaz → Supabase SQL Editor'da uygulanır.

create or replace view product_status
with (security_invoker = true) as
with weekly_sales as (
  select
    coalesce(pr.equivalent_group_id::text, si.product_id::text) as sales_key,
    width_bucket(
      extract(epoch from (now() - s.sale_date)) / 86400.0,
      0, 28, 4
    ) as week_bucket,
    sum(si.quantity) as qty
  from sale_items si
  join sales s on s.id = si.sale_id
  join products pr on pr.id = si.product_id
  where si.product_id is not null
    and s.sale_date >= now() - interval '28 days'
    and s.sale_date < now()
  group by 1, 2
),
cok_satan as (
  select sales_key
  from weekly_sales
  where qty >= 1
  group by sales_key
  having count(distinct week_bucket) = 4
),
grp_activity as materialized (
  select equivalent_group_id, max(updated_at) as latest_updated_at
  from products
  where equivalent_group_id is not null
  group by equivalent_group_id
)
select
  p.id as product_id,
  case
    when cs.sales_key is not null then 'cok_satan'
    when coalesce(agg.total_stock, p.stock_quantity) <= 0 then 'tukendi'
    when coalesce(ga.latest_updated_at, p.updated_at) < now() - interval '1 year' then 'pasif'
    else null
  end as status
from products p
left join cok_satan cs on cs.sales_key = coalesce(p.equivalent_group_id::text, p.id::text)
left join product_equivalent_aggregate agg on agg.product_id = p.id
left join grp_activity ga on ga.equivalent_group_id = p.equivalent_group_id;

grant select on product_status to anon, authenticated;

-- Uygulama: DDL anon key ile çalıştırılamaz → Supabase SQL Editor'da uygulanır.
