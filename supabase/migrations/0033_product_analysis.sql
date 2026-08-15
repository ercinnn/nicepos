-- =============================================================================
-- 0033: Ürün Analizi — ciro/satış hızı + durağan ürün tespiti (Raporlar 5. sekme)
-- =============================================================================
-- Her ürünü (eşlenik barkod grubu TEK birim — 0021/0023 ile AYNI
-- coalesce(equivalent_group_id, id) deseni) seçili tarih aralığındaki cirosu +
-- satış hızıyla, ve TÜM ZAMANLARIN son satış tarihiyle (aralıktan BAĞIMSIZ —
-- "kaç gündür satılmadı" aralık dışına taşsa da bilinsin) birlikte döndürür.
-- "Satmaktan vazgeçmeliyiz" sıralaması istemci tarafında durağanlık + kalan
-- stok değeri (stock_quantity × purchase_price) ile hesaplanır — kâr marjı
-- KULLANILMAZ (çoğu üründe purchase_price=0/girilmemiş, marj güvenilmez).
--
-- Performans: `sale_items.product_id` üzerinde index YOKTU — eklenir. Her
-- agregasyon CTE'si MATERIALIZED (0018 dersi / CLAUDE.md "Sorgu planlayıcı
-- dersi" — büyük JOIN'e gömülünce planlayıcı satır başına yeniden hesaplayıp
-- statement timeout verebilir).
--
-- Kapsam: yalnızca stock_quantity > 0 OLAN veya EN AZ BİR KEZ satılmış ürün
-- grupları döner (hiç stoğu olmayan + hiç satılmamış satırlar gürültü).
--
-- Uygulama: DDL anon key ile çalıştırılamaz → Supabase SQL Editor'da uygulanır.

create index if not exists idx_sale_items_product_id on sale_items (product_id);

create or replace function product_analysis(p_start timestamptz, p_end timestamptz)
returns table (
  product_id uuid,
  equivalent_group_id uuid,
  member_count int,
  barcode text,
  name text,
  unit text,
  stock_quantity numeric,
  purchase_price numeric,
  price1 numeric,
  revenue_in_period numeric,
  quantity_sold_in_period numeric,
  last_sale_date timestamptz
)
language sql
stable
security invoker
as $$
  with grp_stock as materialized (
    select
      coalesce(equivalent_group_id::text, id::text) as sales_key,
      sum(stock_quantity) as stock_quantity,
      count(*) as member_count
    from products
    group by 1
  ),
  grp_latest as materialized (
    select distinct on (coalesce(equivalent_group_id::text, id::text))
      coalesce(equivalent_group_id::text, id::text) as sales_key,
      id as product_id,
      equivalent_group_id,
      barcode,
      name,
      unit,
      purchase_price,
      price1
    from products
    order by coalesce(equivalent_group_id::text, id::text), updated_at desc, id
  ),
  period_agg as materialized (
    select
      coalesce(pr.equivalent_group_id::text, pr.id::text) as sales_key,
      sum(si.total) as revenue,
      sum(si.quantity) as qty
    from sale_items si
    join sales s on s.id = si.sale_id
    join products pr on pr.id = si.product_id
    where si.product_id is not null
      and s.sale_date >= p_start
      and s.sale_date < p_end
    group by 1
  ),
  last_sale as materialized (
    select
      coalesce(pr.equivalent_group_id::text, pr.id::text) as sales_key,
      max(s.sale_date) as last_sale_date
    from sale_items si
    join sales s on s.id = si.sale_id
    join products pr on pr.id = si.product_id
    where si.product_id is not null
    group by 1
  )
  select
    gl.product_id, gl.equivalent_group_id, gs.member_count,
    gl.barcode, gl.name, gl.unit,
    gs.stock_quantity, gl.purchase_price, gl.price1,
    coalesce(pa.revenue, 0) as revenue_in_period,
    coalesce(pa.qty, 0) as quantity_sold_in_period,
    ls.last_sale_date
  from grp_latest gl
  join grp_stock gs on gs.sales_key = gl.sales_key
  left join period_agg pa on pa.sales_key = gl.sales_key
  left join last_sale ls on ls.sales_key = gl.sales_key
  where gs.stock_quantity > 0 or ls.last_sale_date is not null;
$$;

grant execute on function product_analysis to anon, authenticated;

-- Uygulama: DDL anon key ile çalıştırılamaz → Supabase SQL Editor'da uygulanır.
