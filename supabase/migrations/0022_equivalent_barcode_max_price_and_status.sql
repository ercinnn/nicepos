-- =============================================================================
-- 0022: Eşlenik Barkod — "esas" fiyat kuralı EN YÜKSEK price1'e çevrilir,
-- Tükendi durumu grup TOPLAM stoğuna göre hesaplanır
-- =============================================================================
-- Önkoşul: 0021_equivalent_barcodes.sql (product_equivalent_aggregate view'ını
-- ve products.equivalent_group_id sütununu oluşturur).
--
-- Kullanıcı isteği (KARAR):
--   1. Fiyat: bir eşlenik grubunda barkodlar farklı fiyatla kayıtlıysa artık
--      "en son güncellenen" DEĞİL, EN YÜKSEK price1'e sahip satır grup için
--      "esas" kabul edilir (ör. 34 TL ve 36 TL varsa ikisi de 36 TL gösterilir).
--      Eşitlik durumunda ikincil sıralama yine `updated_at desc` (0021'deki
--      önceki davranışla tutarlı tie-break).
--   2. Durum/Tükendi: bir ürünün KENDİ stoğu 0 olsa bile, eşlenik grubundaki
--      DİĞER barkodların toplam stoğu pozitifse "Tükendi" YAZILMAMALI — Durum
--      hesabı artık grubun TOPLAM stoğuna (`product_equivalent_aggregate.
--      total_stock`) bakar, gruplanmamış ürünlerde eskisi gibi kendi ham
--      `stock_quantity`'sine düşer (coalesce). "Çok Satan" (satış geçmişi) ve
--      "Pasif" (updated_at yaşı) mantığı DEĞİŞMEDİ — hâlâ satırın kendi verisine
--      bakar.
--
-- Bu migration yeni tablo/sütun EKLEMEZ — yalnızca iki mevcut view'ı
-- `create or replace view` ile yeniden tanımlar. Kolon adları/şekilleri
-- (product_equivalent_aggregate: product_id, equivalent_group_id, total_stock,
-- member_count, latest_product_id, group_price1, group_price2,
-- group_purchase_price, group_vat_rate) AYNI kalır — Dart modeli
-- (EquivalentAggregate) bu adları okuyor.
--
-- RLS: security_invoker = true (0016/0021 ile aynı desen).
-- Uygulama: DDL anon key ile çalıştırılamaz → Supabase SQL Editor'da uygulanır.

-- ── product_equivalent_aggregate: "esas" satır artık en yüksek price1 ────────
-- `grp_latest` → `grp_best_price` (isim, sıralama kuralını yansıtır).
create or replace view product_equivalent_aggregate
with (security_invoker = true) as
with grp_stock as materialized (
  select
    equivalent_group_id,
    sum(stock_quantity) as total_stock,
    count(*) as member_count
  from products
  where equivalent_group_id is not null
  group by equivalent_group_id
),
grp_best_price as materialized (
  select distinct on (equivalent_group_id)
    equivalent_group_id,
    id as latest_product_id,
    price1,
    price2,
    purchase_price,
    vat_rate
  from products
  where equivalent_group_id is not null
  order by equivalent_group_id, price1 desc, updated_at desc, id
)
select
  p.id as product_id,
  p.equivalent_group_id,
  gs.total_stock,
  gs.member_count,
  gl.latest_product_id,
  gl.price1 as group_price1,
  gl.price2 as group_price2,
  gl.purchase_price as group_purchase_price,
  gl.vat_rate as group_vat_rate
from products p
join grp_stock gs on gs.equivalent_group_id = p.equivalent_group_id
join grp_best_price gl on gl.equivalent_group_id = p.equivalent_group_id;

grant select on product_equivalent_aggregate to anon, authenticated;

-- ── product_status: Tükendi kontrolü grup TOPLAM stoğuna göre ────────────────
-- weekly_sales/cok_satan CTE'leri (Çok Satan hesaplaması) AYNEN kalır, dokunulmadı.
create or replace view product_status
with (security_invoker = true) as
with weekly_sales as (
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
cok_satan as (
  select product_id
  from weekly_sales
  where qty >= 1
  group by product_id
  having count(distinct week_bucket) = 4
)
select
  p.id as product_id,
  case
    when cs.product_id is not null then 'cok_satan'
    when coalesce(agg.total_stock, p.stock_quantity) <= 0 then 'tukendi'
    when p.updated_at < now() - interval '1 year' then 'pasif'
    else null
  end as status
from products p
left join cok_satan cs on cs.product_id = p.id
left join product_equivalent_aggregate agg on agg.product_id = p.id;

grant select on product_status to anon, authenticated;

-- Uygulama: DDL anon key ile çalıştırılamaz → Supabase SQL Editor'da uygulanır.
