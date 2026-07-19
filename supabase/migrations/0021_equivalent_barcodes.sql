-- =============================================================================
-- 0021: Eşlenik Barkod — tedarikçiden farklı barkodla gelen AYNI ürünü
-- gruplayıp stok/fiyatı okuma anında toplama
-- =============================================================================
-- Problem: bazı ürünler tedarikçilerden farklı barkodlarla stoğa giriyor (aynı
-- fiziksel ürün — ör. bir kepçe — hem barkod A hem barkod B ile). Bugün bunlar
-- `products` tablosunda İKİ AYRI satır (her biri kendi stok/fiyatıyla). Kullanıcı
-- bu satırları "eşlenik" işaretleyebilsin istiyoruz; sonuçta hangi barkod
-- okutulursa okutulsun stok = grup toplamı, fiyat = grubun en son güncellenen
-- satırının fiyatı olarak görünsün.
--
-- Depolama modeli (KARAR): ham `products` sütunları (`stock_quantity`, `price1`
-- vb.) HİÇ değiştirilmez/senkronize edilmez — her satır DB'de olduğu gibi kalır
-- (tedarikçi/parti takibi bozulmasın). Toplamlar SADECE okuma anında bu view ile
-- hesaplanır. `products.equivalent_group_id` yalnızca "hangi satırlar aynı
-- grupta" bilgisini tutar; grup id'si paylaşan satırlar aynı fiziksel ürünün
-- eşlenikleridir.
--
-- Fiyat çakışması (KARAR): iki barkodun fiyatı farklıysa, `updated_at`'i EN SON
-- olan satırın price1/price2/purchase_price/vat_rate değerleri grup için "esas"
-- kabul edilir. Otomatik, ekstra "ana barkod seç" UI'ı YOK.
--
-- RLS: security_invoker = true (diğer view'lerle aynı desen, bkz. 0016).
-- Uygulama: DDL anon key ile çalıştırılamaz → Supabase SQL Editor'da uygulanır.

alter table products add column if not exists equivalent_group_id uuid;

-- Kısmi index — yalnız grubu olan satırlar için (çoğu ürün eşlenik değildir).
create index if not exists idx_products_equivalent_group_id
  on products(equivalent_group_id)
  where equivalent_group_id is not null;

-- `grp_stock`/`grp_latest` MATERIALIZED CTE — 0018_search_products_perf_fix.sql
-- dersiyle aynı: bu view büyük bir sorguya JOIN edildiğinde planlayıcının
-- agregasyonu satır başına yeniden hesaplamasını (statement timeout riski)
-- önlemek için MATERIALIZED işaretlenir.
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
grp_latest as materialized (
  select distinct on (equivalent_group_id)
    equivalent_group_id,
    id as latest_product_id,
    price1,
    price2,
    purchase_price,
    vat_rate
  from products
  where equivalent_group_id is not null
  order by equivalent_group_id, updated_at desc, id
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
join grp_latest gl on gl.equivalent_group_id = p.equivalent_group_id;

grant select on product_equivalent_aggregate to anon, authenticated;

-- Uygulama: DDL anon key ile çalıştırılamaz → Supabase SQL Editor'da uygulanır.
