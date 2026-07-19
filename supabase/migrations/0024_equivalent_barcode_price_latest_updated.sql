-- =============================================================================
-- 0024: Eşlenik Barkod — "esas" fiyat kuralı TEKRAR en son güncellenen satıra
-- çevrilir (0022'deki "en yüksek fiyat" kuralı GERİ ALINIYOR)
-- =============================================================================
-- Önkoşul: 0021_equivalent_barcodes.sql (product_equivalent_aggregate view'ını
-- ve products.equivalent_group_id sütununu oluşturur), 0022_equivalent_barcode_
-- max_price_and_status.sql (fiyat kuralını "en yüksek price1"e çevirmişti),
-- 0023_equivalent_barcode_status_full.sql (Çok Satan/Pasif'i grup bazlı yaptı).
--
-- Kullanıcı isteği (KARAR): 0022 ile esas fiyat kuralı "en yüksek price1"
-- yapılmıştı — kullanıcı bunu istemiyor, kuralın ORİJİNAL (0021'deki) haline
-- dönmesini istiyor: bir eşlenik grubunda barkodların fiyatı farklıysa, grup
-- için "esas" kabul edilen price1/price2/purchase_price/vat_rate değerleri
-- yeniden `updated_at`'i EN SON olan satırdan alınır (price1 DESC kriteri
-- KALDIRILIR).
--
-- Bu migration yalnızca `product_equivalent_aggregate` view'ını
-- `create or replace` ile yeniden tanımlar. `product_status` view'ı (Tükendi/
-- Çok Satan/Pasif grup-bazlı mantığı, 0022/0023) BU MİGRATION'DA DEĞİŞMEDİ —
-- `grp_stock` (total_stock/member_count) hesaplaması da AYNEN kalır.
--
-- RLS: security_invoker = true (0016/0021/0022/0023 ile aynı desen).
-- Uygulama: DDL anon key ile çalıştırılamaz → Supabase SQL Editor'da uygulanır.

-- `grp_best_price` (0022) → `grp_latest` (0021'deki isme geri dönüş).
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
