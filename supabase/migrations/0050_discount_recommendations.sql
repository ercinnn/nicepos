-- =============================================================================
-- 0050: İndirim Önerileri — veri-temelli fiyat esnekliği (Analiz sayfası 2. sekme)
-- =============================================================================
-- Her ürünün GEÇMİŞ satış kalemlerinden (sale_items.total/quantity = o satırda
-- fiilen ödenen birim fiyat; row-level iskonto/"Fiyat1 yap" ile zaten yansımış
-- — sepet-geneli iskonto bu satıra dağıtılmadığından KASITLI OLARAK dışarıda
-- bırakılır, satır fiyatı tek başına yeterli bir yaklaşıklık) log-log talep
-- eğrisi (ln(adet) = a + b·ln(fiyat)) fit eder — Postgres'in yerleşik
-- regr_slope/regr_r2 agregasyonlarıyla, istemci tarafında ürün başına ayrı
-- sorgu YOK (tüm ürünler TEK sorguda).
--
-- b (elasticity) fiyat esnekliğidir. Sabit-esneklik modelinde ciro oranı
-- yalnızca (yeniFiyat/eskiFiyat)^(b+1)'dir — regresyonun kesişim terimi
-- (intercept) SADELEŞİR, ihtiyaç yok. b < -1 ise (esnek talep) indirim ciroyu
-- ARTIRIR — yalnız bu durumda öneri üretilir; b >= -1 (inelastik) ürünlerde
-- indirim modele göre ciroyu düşürür, bu yüzden hiç önerilmez.
--
-- Güven sınırı: aday indirim, ürünün TARİHTE GERÇEKTEN gözlenen en düşük fiyatın
-- biraz altına (×0.9) inemez — model bu aralığın dışında ekstrapolasyon
-- yapmaz, yalnızca gözlenen fiyat davranışı içinde enterpolasyon yapar.
--
-- Filtre eşikleri (p_min_*) çağıran tarafından ayarlanabilir — az örnek/az
-- fiyat çeşitliliği/düşük R² olan ürünler "yetersiz veri" sayılıp hiç
-- döndürülmez (regresyon gürültüden ürer, yanıltıcı olur).
--
-- İade satışları (sales.total_amount < 0, bkz. `completeReturn`) hariç
-- tutulur — negatif ciro satırları fiyat/adet ilişkisini bozar.
--
-- Eşlenik Barkod grupları (`product_analysis` ile AYNI desen) TEK ürün gibi
-- ele alınır — aynı fiziksel ürünün farklı barkodlu satırları ayrı ayrı
-- öneri üretmesin diye.
--
-- Uygulama: DDL anon key ile çalıştırılamaz → Supabase SQL Editor'da uygulanır.

create or replace function discount_recommendations(
  p_lookback_days integer default 365,
  p_min_samples integer default 8,
  p_min_price_points integer default 3,
  p_min_r2 numeric default 0.25,
  p_limit integer default 50
)
returns table (
  product_id uuid,
  equivalent_group_id uuid,
  barcode text,
  name text,
  price1 numeric,
  sample_count bigint,
  price_points bigint,
  r_squared numeric,
  elasticity numeric,
  avg_daily_quantity numeric,
  historical_min_price numeric,
  historical_max_price numeric,
  recommended_discount_percent int,
  recommended_price numeric,
  current_est_daily_revenue numeric,
  recommended_est_daily_revenue numeric,
  revenue_increase_percent numeric
)
language sql
stable
security invoker
as $$
  with grp_latest as materialized (
    select distinct on (coalesce(equivalent_group_id::text, id::text))
      coalesce(equivalent_group_id::text, id::text) as sales_key,
      id as product_id, equivalent_group_id, barcode, name, price1
    from products
    order by coalesce(equivalent_group_id::text, id::text), updated_at desc, id
  ),
  rows_ as materialized (
    select
      coalesce(pr.equivalent_group_id::text, pr.id::text) as sales_key,
      si.quantity as qty,
      (si.total / nullif(si.quantity, 0))::numeric as eff_price,
      s.sale_date
    from sale_items si
    join sales s on s.id = si.sale_id
    join products pr on pr.id = si.product_id
    where si.product_id is not null
      and si.quantity > 0
      and si.total > 0
      and s.total_amount > 0
      and s.sale_date >= now() - (p_lookback_days || ' days')::interval
  ),
  stats as materialized (
    select
      sales_key,
      count(*) as sample_count,
      count(distinct round(eff_price, 2)) as price_points,
      regr_slope(ln(qty), ln(eff_price)) as elasticity,
      regr_r2(ln(qty), ln(eff_price)) as r_squared,
      min(eff_price) as min_price,
      max(eff_price) as max_price,
      sum(qty) as total_qty,
      greatest(extract(epoch from (max(sale_date) - min(sale_date))) / 86400.0, 1) as span_days
    from rows_
    group by sales_key
  ),
  qualified as (
    select
      gl.product_id, gl.equivalent_group_id, gl.barcode, gl.name, gl.price1,
      st.sample_count, st.price_points,
      round(st.r_squared::numeric, 3) as r_squared,
      round(st.elasticity::numeric, 3) as elasticity,
      round((st.total_qty / st.span_days)::numeric, 3) as avg_daily_quantity,
      round(st.min_price::numeric, 2) as historical_min_price,
      round(st.max_price::numeric, 2) as historical_max_price
    from stats st
    join grp_latest gl on gl.sales_key = st.sales_key
    where st.sample_count >= p_min_samples
      and st.price_points >= p_min_price_points
      and st.r_squared >= p_min_r2
      and st.elasticity < -1
      and gl.price1 > 0
  )
  select
    q.product_id, q.equivalent_group_id, q.barcode, q.name, q.price1,
    q.sample_count, q.price_points, q.r_squared, q.elasticity, q.avg_daily_quantity,
    q.historical_min_price, q.historical_max_price,
    cand.discount_percent as recommended_discount_percent,
    round((q.price1 * (1 - cand.discount_percent / 100.0))::numeric, 2) as recommended_price,
    round((q.avg_daily_quantity * q.price1)::numeric, 2) as current_est_daily_revenue,
    round((q.avg_daily_quantity * q.price1 * cand.revenue_ratio)::numeric, 2) as recommended_est_daily_revenue,
    round(((cand.revenue_ratio - 1) * 100)::numeric, 2) as revenue_increase_percent
  from qualified q
  join lateral (
    select
      d.discount_percent,
      power(
        (1 - d.discount_percent / 100.0)::double precision,
        (q.elasticity + 1)::double precision
      )::numeric as revenue_ratio
    from (values (5), (10), (15), (20), (25), (30), (35), (40)) as d(discount_percent)
    where q.price1 * (1 - d.discount_percent / 100.0) >= q.historical_min_price * 0.9
    order by power(
      (1 - d.discount_percent / 100.0)::double precision,
      (q.elasticity + 1)::double precision
    ) desc
    limit 1
  ) cand on true
  order by revenue_increase_percent desc
  limit p_limit;
$$;

grant execute on function discount_recommendations to authenticated;
