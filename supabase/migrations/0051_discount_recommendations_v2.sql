-- =============================================================================
-- 0051: İndirim Önerileri v2 — kapsam genişletme (0050'nin canlı denemesinde
-- yalnız 4-5 ürün eşikleri geçiyordu; kullanıcı kararıyla üç yönde genişletildi)
-- =============================================================================
-- 0050'ye göre üç değişiklik:
--
-- (1) Eşikler gevşetildi: p_min_samples 8→5, p_min_price_points 3→2,
--     p_min_r2 0.25→0.15. Yalnız GÜVEN eşikleridir — b < -1 (esnek talep)
--     şartı GEVŞETİLMEDİ, çünkü bu istatistiksel bir güven eşiği değil,
--     modelin "indirim ciroyu artırır" iddiasının matematiksel ön koşulu
--     (b ≥ -1 olan bir üründe indirim modele göre ciroyu DÜŞÜRÜR — bunu
--     gevşetmek yanlış öneri üretir).
--
-- (2) Ürün grubuna göre destekleme (partial pooling): kendi geçmişi eşiği
--     geçemeyen bir ürün için, AYNI product_groups üyesi diğer ürünlerin
--     TÜMÜNÜN sale_items'ından tek bir "grup esnekliği" fit edilir — ürün
--     kendi tek başına yetersiz veriye sahipse kategorisinin genel fiyat
--     duyarlılığını ödünç alır. Grup kaynaklı tahmin daha az kesin olduğundan
--     iki katı örnek sayısı ister (`p_min_samples * 2`) ve her zaman "düşük
--     güven" rozetiyle işaretlenir — istemci UI'da hangi kaynağın
--     kullanıldığı (`source`) her zaman görünür kalır, gizlenmez.
--
-- (3) Eşiği hiç geçemeyen ürünler artık tamamen ELENMİYOR — `status` alanıyla
--     etiketlenip yine döner ('insufficient_data' / 'not_beneficial' /
--     'no_safe_discount'), istemci bunları ayrı bir "Diğer Ürünler" bölümünde
--     gerekçesiyle gösterebilir. p_limit artık varsayılan NULL (Postgres'te
--     `LIMIT NULL` = sınırsız) — tüm analiz edilebilir ürünler (en az bir kez
--     satılmış) tek çağrıda döner.
--
-- Durum makinesi (`status`):
--   'recommended'       → b < -1 VE (kendi veya grup) eşiği geçti VE tarihte
--                          gözlenmiş fiyat aralığı içinde güvenli bir aday
--                          indirim bulundu (bkz. 0050'deki ×0.9 taban kuralı)
--   'no_safe_discount'   → b < -1 VE eşik geçildi AMA ürün geçmişte hiç
--                          price1*0.9'un altında satılmadığından hiçbir aday
--                          indirim taban kuralını geçemedi
--   'not_beneficial'     → yeterli veri var AMA b ≥ -1 (talep yeterince
--                          esnek değil) — indirim modele göre ciroyu artırmaz
--   'insufficient_data'  → ne kendi ne de grup verisi eşikleri geçiyor
--
-- `source` ('own'|'group'|null) ve `confidence` ('yuksek'|'orta'|'dusuk'|null)
-- yalnız status='recommended' dışındaki durumlarda da (not_beneficial hariç
-- source/confidence anlamlı olabilir) bilgi amaçlı doldurulabilir; istemci
-- yalnız 'recommended' satırları ana listede, gerisini ikincil bölümde
-- gösterir.
--
-- Diğer her şey (log-log regresyon, iade/negatif satış hariç tutma, eşlenik
-- barkod gruplama, ×0.9 taban kuralı) 0050 ile AYNI — bkz. o migration'ın
-- metodoloji notu.
--
-- ⚠️ Dönüş tipi (3 yeni kolon: status/source/confidence) değiştiğinden
-- CREATE OR REPLACE yetmez (CLAUDE.md "RPC migration dersi") — önce DROP.
--
-- Uygulama: DDL anon key ile çalıştırılamaz → Supabase SQL Editor'da uygulanır.

drop function if exists discount_recommendations(integer, integer, integer, numeric, integer);

create or replace function discount_recommendations(
  p_lookback_days integer default 365,
  p_min_samples integer default 5,
  p_min_price_points integer default 2,
  p_min_r2 numeric default 0.15,
  p_limit integer default null
)
returns table (
  product_id uuid,
  equivalent_group_id uuid,
  barcode text,
  name text,
  price1 numeric,
  status text,
  source text,
  confidence text,
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
      id as product_id, equivalent_group_id, barcode, name, price1, group_id
    from products
    order by coalesce(equivalent_group_id::text, id::text), updated_at desc, id
  ),
  rows_ as materialized (
    select
      coalesce(pr.equivalent_group_id::text, pr.id::text) as sales_key,
      pr.group_id,
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
  own_stats as materialized (
    select
      sales_key,
      count(*) as sample_count,
      count(distinct round(eff_price, 2)) as price_points,
      regr_slope(ln(qty), ln(eff_price)) as elasticity,
      regr_r2(ln(qty), ln(eff_price)) as r_squared,
      min(eff_price) as min_price,
      max(eff_price) as max_price,
      sum(qty) as total_qty,
      -- Çok az örnekli ürünlerde (span_days doğal olarak küçük/0) günlük
      -- hız tahmini abartmasın diye taban 7 gün (0050'de tabandı 1 gündü).
      greatest(extract(epoch from (max(sale_date) - min(sale_date))) / 86400.0, 7) as span_days
    from rows_
    group by sales_key
  ),
  group_stats as materialized (
    select
      group_id,
      count(*) as sample_count,
      count(distinct round(eff_price, 2)) as price_points,
      regr_slope(ln(qty), ln(eff_price)) as elasticity,
      regr_r2(ln(qty), ln(eff_price)) as r_squared
    from rows_
    where group_id is not null
    group by group_id
  ),
  decided as (
    select
      gl.product_id, gl.equivalent_group_id, gl.barcode, gl.name, gl.price1,
      os.sample_count, os.price_points,
      round((os.total_qty / os.span_days)::numeric, 3) as avg_daily_quantity,
      round(os.min_price::numeric, 2) as historical_min_price,
      round(os.max_price::numeric, 2) as historical_max_price,
      round(os.elasticity::numeric, 3) as own_elasticity,
      round(os.r_squared::numeric, 3) as own_r2,
      round(gs.elasticity::numeric, 3) as grp_elasticity,
      round(gs.r_squared::numeric, 3) as grp_r2,
      case
        when os.sample_count >= p_min_samples
         and os.price_points >= p_min_price_points
         and os.r_squared >= p_min_r2
        then 'own'
        when gl.group_id is not null
         and gs.sample_count >= p_min_samples * 2
         and gs.price_points >= p_min_price_points
         and gs.r_squared >= p_min_r2
        then 'group'
        else null
      end as source
    from own_stats os
    join grp_latest gl on gl.sales_key = os.sales_key
    left join group_stats gs on gs.group_id = gl.group_id
  ),
  resolved as (
    select
      d.*,
      case d.source when 'own' then d.own_elasticity when 'group' then d.grp_elasticity end as elasticity,
      case d.source when 'own' then d.own_r2 when 'group' then d.grp_r2 end as r_squared,
      case
        when d.source is null then 'insufficient_data'
        when (case d.source when 'own' then d.own_elasticity when 'group' then d.grp_elasticity end) >= -1
          then 'not_beneficial'
        else 'pending'
      end as status0,
      case
        when d.source = 'own' and d.own_r2 >= 0.5 and d.sample_count >= 20 then 'yuksek'
        when d.source = 'own' then 'orta'
        when d.source = 'group' then 'dusuk'
        else null
      end as confidence
    from decided d
  )
  select
    r.product_id, r.equivalent_group_id, r.barcode, r.name, r.price1,
    case
      when r.status0 <> 'pending' then r.status0
      when best.discount_percent is not null then 'recommended'
      else 'no_safe_discount'
    end as status,
    r.source, r.confidence,
    r.sample_count, r.price_points, r.r_squared, r.elasticity, r.avg_daily_quantity,
    r.historical_min_price, r.historical_max_price,
    best.discount_percent as recommended_discount_percent,
    round((r.price1 * (1 - best.discount_percent / 100.0))::numeric, 2) as recommended_price,
    round((r.avg_daily_quantity * r.price1)::numeric, 2) as current_est_daily_revenue,
    round((r.avg_daily_quantity * r.price1 * best.revenue_ratio)::numeric, 2) as recommended_est_daily_revenue,
    round(((best.revenue_ratio - 1) * 100)::numeric, 2) as revenue_increase_percent
  from resolved r
  left join lateral (
    select
      d.discount_percent,
      power(
        (1 - d.discount_percent / 100.0)::double precision,
        (r.elasticity + 1)::double precision
      )::numeric as revenue_ratio
    from (values (5), (10), (15), (20), (25), (30), (35), (40)) as d(discount_percent)
    where r.status0 = 'pending'
      and r.price1 * (1 - d.discount_percent / 100.0) >= r.historical_min_price * 0.9
    order by power(
      (1 - d.discount_percent / 100.0)::double precision,
      (r.elasticity + 1)::double precision
    ) desc
    limit 1
  ) best on true
  order by
    case when r.status0 = 'pending' and best.discount_percent is not null then 0 else 1 end,
    coalesce(round(((best.revenue_ratio - 1) * 100)::numeric, 2), -999) desc
  limit p_limit;
$$;

grant execute on function discount_recommendations to authenticated;
