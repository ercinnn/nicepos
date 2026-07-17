-- NicePOS - Ürün "Durum" göstergesi (Ürünler tablosu yeni sütun)
--
-- Amaç: Ürünler listesinde her ürünün "Çok Satan / Tükendi / Pasif" durumunu
-- sunucuda hesaplayan bir view. İstemci binlerce `sale_items` satırını çekip
-- Dart'ta hesaplamak yerine, görüntülenen sayfadaki ürün id'leri için tek
-- sorguyla (`product_status` view, `product_id` ile filtreli) durumu okur —
-- dashboard'daki ciro RPC'leriyle AYNI "sunucuda hesapla" deseni
-- (bkz. 0015_sales_revenue_rpc.sql).
--
-- Öncelik sırası (KARAR): Çok Satan > Tükendi > Pasif > (boş).
--   - Çok Satan: son 4 haftanın HER birinde en az 1 adet satılmış (rolling
--     7 günlük 4 pencere — takvim haftası DEĞİL, "son 365 gün" gibi bugüne
--     göre kayan pencere; bu projedeki diğer "son N gün" metrikleriyle aynı
--     yaklaşım).
--   - Tükendi: stock_quantity <= 0.
--   - Pasif: `products.updated_at` 1 yıldan eskiyse. Stok satışla (RPC
--     `decrement_product_stock`/`increment_product_stock`) VEYA elle
--     düzenlemeyle (ürün formu / tablo içi "Güncelle") değiştiğinde HER
--     ikisi de `updated_at`'i günceller (bkz. 0005_functions.sql,
--     0007_increment_stock.sql, `Product.toInsertMap()`) — yani tek bu alan
--     "stok düzenleme + satış + fiyat değişikliği"nin hepsini kapsar, ayrı
--     bir "son satış" sorgusuna gerek yok.
--
-- RLS: security_invoker = true (diğer view'lerle aynı desen).
-- Uygulama: DDL anon key ile çalıştırılamaz → Supabase SQL Editor'da uygulanır.

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
    when p.stock_quantity <= 0 then 'tukendi'
    when p.updated_at < now() - interval '1 year' then 'pasif'
    else null
  end as status
from products p
left join cok_satan cs on cs.product_id = p.id;

grant select on product_status to anon, authenticated;
